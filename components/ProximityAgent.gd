extends Node2D
class_name ProximityAgent

# ProximityAgent - Detects nearby NPCs and manages proximity-based social interactions
# Implements the proximity detection and invitation system from the design document

signal proximity_detected(npc_id: String, nearby_npcs: Array)
signal npc_entered_proximity(npc_id: String, target_id: String, distance: float)
signal npc_left_proximity(npc_id: String, target_id: String)
signal invitation_sent(npc_id: String, target_id: String, conversation_id: String)
signal invitation_received(npc_id: String, from_id: String, conversation_id: String)

# NPC identifier
@export var npc_id: String = ""

# Proximity detection settings
@export var detection_radius: float = 150.0  # Pixels
@export var conversation_radius: float = 100.0  # Pixels for starting conversations
@export var eavesdrop_radius: float = 200.0  # Pixels for listening without joining
@export var update_interval: float = 0.5  # Update every 500ms

# Social interaction settings
@export var auto_invite_threshold: float = 0.6  # Social drive threshold for auto-inviting
@export var invitation_cooldown: float = 10.0  # Seconds between invitations to same NPC
@export var max_invitations_per_tick: int = 2  # Maximum invitations sent per update

# Current state
var nearby_npcs: Array[Dictionary] = []
var invited_npcs: Dictionary = {}  # npc_id -> last_invitation_time
var received_invitations: Array[Dictionary] = []
var last_update_time: float = 0.0

# References
var needs_component: NeedsComponent
var conversation_controller: Node

func _ready():
	if npc_id.is_empty():
		npc_id = get_parent().name if get_parent() else "unknown"
	
	# Find needs component
	needs_component = get_parent().get_node_or_null("NeedsComponent")
	if not needs_component:
		print("[ProximityAgent] Warning: No NeedsComponent found for ", npc_id)
	
	# Find conversation controller
	conversation_controller = get_node_or_null("/root/ConversationController")
	if not conversation_controller:
		print("[ProximityAgent] Warning: No ConversationController found")
	
	last_update_time = _get_current_time_seconds()
	print("[ProximityAgent] Initialized for NPC: ", npc_id)

func _process(delta: float):
	var current_time = _get_current_time_seconds()
	if current_time - last_update_time >= update_interval:
		_update_proximity()
		_process_social_interactions()
		last_update_time = current_time

func _update_proximity():
	var old_nearby = nearby_npcs.duplicate()
	nearby_npcs.clear()
	
	# Get all NPCs in the scene
	var all_npcs = _get_all_npcs()
	
	for npc in all_npcs:
		if npc.id == npc_id:
			continue  # Skip self
		
		var distance = global_position.distance_to(npc.global_position)
		
		if distance <= detection_radius:
			var npc_data = {
				"id": npc.id,
				"distance": distance,
				"position": npc.global_position,
				"in_conversation": _is_npc_in_conversation(npc.id),
				"social_drive": _get_npc_social_drive(npc.id),
				"last_seen": _get_current_time_seconds()
			}
			
			nearby_npcs.append(npc_data)
			
			# Check if this is a new NPC entering proximity
			var was_nearby = false
			for old_npc in old_nearby:
				if old_npc.id == npc.id:
					was_nearby = true
					break
			
			if not was_nearby:
				npc_entered_proximity.emit(npc_id, npc.id, distance)
		
		# Check if NPC left proximity
		var still_nearby = false
		for new_npc in nearby_npcs:
			if new_npc.id == npc.id:
				still_nearby = true
				break
		
		if not still_nearby:
			for old_npc in old_nearby:
				if old_npc.id == npc.id:
					npc_left_proximity.emit(npc_id, old_npc.id)
					break
	
	# Emit proximity update
	if nearby_npcs.size() > 0:
		proximity_detected.emit(npc_id, nearby_npcs)

func _process_social_interactions():
	if not needs_component or not conversation_controller:
		return
	
	var social_drive = needs_component.get_social_drive()
	var invitations_sent = 0
	
	# Process received invitations
	_process_received_invitations()
	
	# Auto-invite nearby NPCs if social drive is high enough
	if social_drive > auto_invite_threshold and invitations_sent < max_invitations_per_tick:
		for npc_data in nearby_npcs:
			if invitations_sent >= max_invitations_per_tick:
				break
			
			if _should_invite_npc(npc_data):
				if _send_invitation(npc_data.id):
					invitations_sent += 1

func _process_received_invitations():
	var current_time = _get_current_time_seconds()
	var processed_invitations: Array[int] = []
	
	for i in range(received_invitations.size()):
		var invitation = received_invitations[i]
		
		# Check if invitation is still valid
		if current_time - invitation.timestamp > invitation_cooldown:
			processed_invitations.append(i)
			continue
		
		# Process invitation based on current needs
		if _should_accept_invitation(invitation):
			_accept_invitation(invitation)
			processed_invitations.append(i)
		elif _should_decline_invitation(invitation):
			_decline_invitation(invitation)
			processed_invitations.append(i)
	
	# Remove processed invitations
	for i in range(processed_invitations.size() - 1, -1, -1):
		received_invitations.remove_at(processed_invitations[i])

func _should_invite_npc(npc_data: Dictionary) -> bool:
	if npc_data.in_conversation:
		return false  # Don't invite NPCs already in conversation
	
	if npc_data.distance > conversation_radius:
		return false  # Too far to start conversation
	
	# Check invitation cooldown
	var current_time = _get_current_time_seconds()
	if invited_npcs.has(npc_data.id):
		if current_time - invited_npcs[npc_data.id] < invitation_cooldown:
			return false
	
	# Check if NPC has high social drive
	if npc_data.social_drive < 0.3:
		return false  # NPC not interested in socializing
	
	return true

func _send_invitation(target_id: String) -> bool:
	if not conversation_controller:
		return false
	
	# Check if we can start a conversation
	if not needs_component.should_join_conversation():
		return false
	
	# Start conversation
	var participants = [npc_id, target_id]
	var conversation_id = conversation_controller.start_conversation(participants, "proximity_chat")
	
	if not conversation_id.is_empty():
		# Record invitation
		invited_npcs[target_id] = _get_current_time_seconds()
		
		# Emit signal
		invitation_sent.emit(npc_id, target_id, conversation_id)
		
		# Send invitation to target NPC
		var target_proximity_agent = _get_npc_proximity_agent(target_id)
		if target_proximity_agent:
			target_proximity_agent._receive_invitation(npc_id, conversation_id)
		
		print("[ProximityAgent] ", npc_id, " invited ", target_id, " to conversation")
		return true
	
	return false

func _receive_invitation(from_id: String, conversation_id: String):
	var invitation = {
		"from_id": from_id,
		"conversation_id": conversation_id,
		"timestamp": _get_current_time_seconds(),
		"type": "proximity_invitation"
	}
	
	received_invitations.append(invitation)
	invitation_received.emit(npc_id, from_id, conversation_id)
	print("[ProximityAgent] ", npc_id, " received invitation from ", from_id)

func _should_accept_invitation(invitation: Dictionary) -> bool:
	if not needs_component:
		return false
	
	# Check if we're already in a conversation
	if _is_npc_in_conversation(npc_id):
		return false
	
	# Check if we want to socialize
	return needs_component.should_join_conversation()

func _should_decline_invitation(invitation: Dictionary) -> bool:
	if not needs_component:
		return true
	
	# Decline if we don't want to socialize
	return not needs_component.should_join_conversation()

func _accept_invitation(invitation: Dictionary):
	if not conversation_controller:
		return
	
	# Join the conversation
	var success = conversation_controller.add_participant_to_group(invitation.conversation_id, npc_id)
	if success:
		print("[ProximityAgent] ", npc_id, " accepted invitation from ", invitation.from_id)
	else:
		print("[ProximityAgent] ", npc_id, " failed to join conversation from ", invitation.from_id)

func _decline_invitation(invitation: Dictionary):
	print("[ProximityAgent] ", npc_id, " declined invitation from ", invitation.from_id)

# Utility functions
func _get_all_npcs() -> Array:
	var npcs = []
	var npc_nodes = get_tree().get_nodes_in_group("npc")
	
	for npc_node in npc_nodes:
		if npc_node.has_method("get_npc_id"):
			npcs.append({
				"id": npc_node.get_npc_id(),
				"global_position": npc_node.global_position
			})
		else:
			npcs.append({
				"id": npc_node.name,
				"global_position": npc_node.global_position
			})
	
	return npcs

func _is_npc_in_conversation(npc_id: String) -> bool:
	if not conversation_controller:
		return false
	
	var active_groups = conversation_controller.get_active_groups()
	for group in active_groups.values():
		if group.is_participant(npc_id):
			return true
	
	return false

func _get_npc_social_drive(npc_id: String) -> float:
	var npc_node = get_tree().get_node_or_null("//" + npc_id)
	if npc_node and npc_node.has_node("NeedsComponent"):
		var needs = npc_node.get_node("NeedsComponent")
		if needs.has_method("get_social_drive"):
			return needs.get_social_drive()
	
	return 0.5  # Default neutral social drive

func _get_npc_proximity_agent(npc_id: String) -> ProximityAgent:
	var npc_node = get_tree().get_node_or_null("//" + npc_id)
	if npc_node and npc_node.has_node("ProximityAgent"):
		return npc_node.get_node("ProximityAgent")
	
	return null

# Public API
func get_nearby_npcs() -> Array[Dictionary]:
	return nearby_npcs.duplicate()

func get_npcs_in_conversation_range() -> Array[Dictionary]:
	var in_range = []
	for npc_data in nearby_npcs:
		if npc_data.distance <= conversation_radius:
			in_range.append(npc_data)
	return in_range

func get_npcs_in_eavesdrop_range() -> Array[Dictionary]:
	var in_range = []
	for npc_data in nearby_npcs:
		if npc_data.distance <= eavesdrop_radius:
			in_range.append(npc_data)
	return in_range

func force_invitation(target_id: String) -> bool:
	# Console command to force an invitation
	return _send_invitation(target_id)

# Console commands for debugging
func console_command(command: String, args: Array) -> Dictionary:
	match command:
		"nearby":
			var npcs = get_nearby_npcs()
			var message = "Nearby NPCs (" + str(npcs.size()) + "): "
			for npc in npcs:
				message += npc.id + "(" + str(round(npc.distance)) + "px) "
			return {"success": true, "message": message}
		
		"invite":
			if args.size() >= 1:
				var target_id = args[0]
				if force_invitation(target_id):
					return {"success": true, "message": "Invited " + target_id}
				else:
					return {"success": false, "message": "Failed to invite " + target_id}
			return {"success": false, "message": "Usage: invite <npc_id>"}
		
		"status":
			var message = "Proximity status for " + npc_id + ":\n"
			message += "Detection radius: " + str(detection_radius) + "px\n"
			message += "Conversation radius: " + str(conversation_radius) + "px\n"
			message += "Nearby NPCs: " + str(nearby_npcs.size()) + "\n"
			message += "Pending invitations: " + str(received_invitations.size())
			return {"success": true, "message": message}
		
		_:
			return {"success": false, "message": "Unknown command: " + command}


# Helper function to get current time in seconds
func _get_current_time_seconds() -> float:
	var time_dict = Time.get_time_dict_from_system()
	return time_dict.hour * 3600 + time_dict.minute * 60 + time_dict.second
