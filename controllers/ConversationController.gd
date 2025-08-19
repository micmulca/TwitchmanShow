extends Node

# Class references - will be loaded at runtime to avoid circular dependencies
var TopicManager: GDScript
var ContextPacker: GDScript
var ConversationGroup: GDScript
var FloorManager: GDScript

# ConversationController - Orchestrates all conversation groups and manages the conversation system
# Enforces participation invariant, manages group lifecycle, and coordinates conversation flow

signal conversation_started(group_id: String, participants: Array, topic: String)
signal conversation_ended(group_id: String, reason: String, summary: String)
signal participant_moved(group_id: String, npc_id: String, reason: String)
signal group_merged(group1_id: String, group2_id: String, new_group_id: String)

# Active conversation groups
var active_groups: Dictionary = {}  # group_id -> ConversationGroup
var max_active_groups: int = 5
var max_participants_per_group: int = 4

# Participation tracking (enforces one conversation per NPC)
var participant_index: Dictionary = {}  # npc_id -> group_id
var npc_conversation_data: Dictionary = {}  # npc_id -> conversation data

# System components
var topic_manager: Node = null
var context_packer: Node = null

# Performance and scheduling
var conversation_tick_rate: float = 0.5  # Process conversations every 0.5 seconds
var last_tick_time: float = 0.0
var group_cooldowns: Dictionary = {}  # group_id -> last_activity_time
var group_cooldown_duration: float = 30.0  # Seconds between group activities

func _ready():
	# Initialize system components
	_initialize_components()
	
	# Connect to EventBus signals
	EventBus.world_event_triggered.connect(_on_world_event)
	EventBus.npc_action_performed.connect(_on_npc_action)
	
	print("[ConversationController] Initialized with max ", max_active_groups, " groups")

func _initialize_components():
	# Load required classes at runtime
	TopicManager = load("res://controllers/TopicManager.gd")
	ContextPacker = load("res://controllers/ContextPacker.gd")
	ConversationGroup = load("res://controllers/ConversationGroup.gd")
	FloorManager = load("res://controllers/FloorManager.gd")
	
	# Initialize TopicManager
	topic_manager = TopicManager.new()
	add_child(topic_manager)
	
	# Initialize ContextPacker
	context_packer = ContextPacker.new()
	add_child(context_packer)
	
	print("[ConversationController] Components initialized")

func _process(delta: float):
	# Process conversation system at regular intervals
	last_tick_time += delta
	if last_tick_time >= conversation_tick_rate:
		last_tick_time = 0.0
		_process_conversations()

func _process_conversations():
	# Process all active conversations
	for group_id in active_groups.keys():
		var group = active_groups[group_id]
		if not group or not group.is_active:
			_cleanup_group(group_id)
			continue
		
		# Check if group should be active
		if _should_group_continue(group):
			_process_group_turn(group)
		else:
			_end_group(group, "natural_end")

func start_conversation(participants: Array[String], initial_topic: String = "general_chat") -> String:
	# Start a new conversation with the given participants
	if participants.size() < 2:
		print("[ConversationController] Need at least 2 participants to start conversation")
		return ""
	
	if participants.size() > max_participants_per_group:
		print("[ConversationController] Too many participants: ", participants.size())
		return ""
	
	# Check if any participants are already in conversations
	var available_participants = []
	for npc_id in participants:
		if not participant_index.has(npc_id):
			available_participants.append(npc_id)
		else:
			print("[ConversationController] NPC ", npc_id, " is already in conversation ", participant_index[npc_id])
	
	if available_participants.size() < 2:
		print("[ConversationController] Not enough available participants")
		return ""
	
	# Check if we can create a new group
	if active_groups.size() >= max_active_groups:
		print("[ConversationController] Maximum active groups reached")
		return ""
	
	# Create new conversation group
	var group = ConversationGroup.new()
	add_child(group)
	
	# Set up floor manager
	var floor_manager = FloorManager.new()
	floor_manager.set_conversation_group(group)
	group.add_child(floor_manager)
	
	# Add participants
	for npc_id in available_participants:
		var npc_data = _get_npc_conversation_data(npc_id)
		group.add_participant(npc_id, npc_data)
		participant_index[npc_id] = group.group_id
	
	# Set initial topic
	group.change_topic(initial_topic, "conversation_start")
	
	# Store group
	active_groups[group.group_id] = group
	
	# Connect to group signals
	group.participant_joined.connect(_on_participant_joined)
	group.participant_left.connect(_on_participant_left)
	group.topic_changed.connect(_on_topic_changed)
	group.conversation_ended.connect(_on_conversation_ended)
	
	# Emit signal
	conversation_started.emit(group.group_id, available_participants, initial_topic)
	
	print("[ConversationController] Started conversation ", group.group_id, " with ", available_participants.size(), " participants")
	return group.group_id

func add_participant_to_group(group_id: String, npc_id: String) -> bool:
	# Add a participant to an existing conversation group
	if not active_groups.has(group_id):
		print("[ConversationController] Group ", group_id, " not found")
		return false
	
	var group = active_groups[group_id]
	
	# Check participation invariant
	if participant_index.has(npc_id):
		print("[ConversationController] NPC ", npc_id, " is already in conversation ", participant_index[npc_id])
		return false
	
	# Check group capacity
	if group.get_participant_count() >= max_participants_per_group:
		print("[ConversationController] Group ", group_id, " is full")
		return false
	
	# Add participant
	var npc_data = _get_npc_conversation_data(npc_id)
	if group.add_participant(npc_id, npc_data):
		participant_index[npc_id] = group_id
		return true
	
	return false

func remove_participant_from_group(group_id: String, npc_id: String, reason: String = "left") -> bool:
	# Remove a participant from a conversation group
	if not active_groups.has(group_id):
		return false
	
	var group = active_groups[group_id]
	
	if group.remove_participant(npc_id, reason):
		participant_index.erase(npc_id)
		return true
	
	return false

func merge_groups(group1_id: String, group2_id: String) -> String:
	# Merge two conversation groups
	if not active_groups.has(group1_id) or not active_groups.has(group2_id):
		print("[ConversationController] One or both groups not found")
		return ""
	
	var group1 = active_groups[group1_id]
	var group2 = active_groups[group2_id]
	
	# Check if merge is possible
	var total_participants = group1.get_participant_count() + group2.get_participant_count()
	if total_participants > max_participants_per_group:
		print("[ConversationController] Merged group would exceed participant limit")
		return ""
	
	# Create new merged group
	var merged_participants = group1.participants.duplicate()
	merged_participants.append_array(group2.participants)
	
	var merged_group_id = start_conversation(merged_participants, group1.current_topic)
	if merged_group_id.is_empty():
		return ""
	
	# End original groups
	_end_group(group1, "merged")
	_end_group(group2, "merged")
	
	# Emit signal
	group_merged.emit(group1_id, group2_id, merged_group_id)
	
	print("[ConversationController] Merged groups ", group1_id, " and ", group2_id, " into ", merged_group_id)
	return merged_group_id

func inject_topic_into_group(group_id: String, topic: String, reason: String = "external_injection") -> bool:
	# Inject a topic into a specific conversation group
	if not active_groups.has(group_id):
		return false
	
	var group = active_groups[group_id]
	
	# Use TopicManager to inject topic
	if topic_manager.inject_topic(group_id, topic, reason):
		# Change group topic
		return group.change_topic(topic, reason)
	
	return false

func force_speaker_change(group_id: String, new_speaker: String, reason: String = "forced_change") -> bool:
	# Force a change of speaker in a conversation group
	if not active_groups.has(group_id):
		return false
	
	var group = active_groups[group_id]
	var floor_manager = group.get_node("FloorManager")
	
	if floor_manager:
		return floor_manager.force_speaker_change(new_speaker, reason)
	
	return false

func _process_group_turn(group: Node) -> void:
	# Process a single turn for a conversation group
	var group_id = group.group_id
	
	# Check cooldown
	var current_time = Time.get_time_dict_from_system()
	var current_seconds = current_time.hour * 3600 + current_time.minute * 60 + current_time.second
	var last_activity = group_cooldowns.get(group_id, 0.0)
	if current_seconds - last_activity < group_cooldown_duration:
		return
	
	# Update cooldown
	group_cooldowns[group_id] = current_seconds
	
	# Get next speaker
	var floor_manager = group.get_node("FloorManager")
	if not floor_manager:
		return
	
	var next_speaker = floor_manager.get_next_speaker()
	if next_speaker.is_empty():
		return
	
	# Start turn for next speaker
	if floor_manager.start_turn(next_speaker):
		# Generate dialogue for the speaker
		_generate_dialogue_for_speaker(group, next_speaker)

func _generate_dialogue_for_speaker(group: Node, speaker_id: String) -> void:
	# Generate dialogue for a speaker using LLM
	var group_id = group.group_id
	var participants = group.participants.duplicate()
	participants.erase(speaker_id)  # Remove speaker from targets
	
	# Build context for the speaker
	var context = context_packer.build_context_for_npc(speaker_id, participants, group_id)
	
	# Get current topic
	var current_topic = group.current_topic
	
	# Build prompt
	var prompt = _build_dialogue_prompt(speaker_id, current_topic, participants, context)
	
	# Send to LLM
	var request_id = LLMClient.send_request(prompt, context)
	
	# Store request for response handling
	# In a real implementation, you'd track this request and handle the response
	
	print("[ConversationController] Generated dialogue for ", speaker_id, " in group ", group_id)

func _build_dialogue_prompt(speaker_id: String, topic: String, targets: Array, context: Dictionary) -> String:
	# Build a prompt for dialogue generation
	var prompt = "You are " + speaker_id + " in a conversation about '" + topic + "' with "
	
	if targets.size() == 1:
		prompt += targets[0]
	elif targets.size() == 2:
		prompt += targets[0] + " and " + targets[1]
	else:
		prompt += targets[0] + " and " + str(targets.size() - 1) + " others"
	
	prompt += ". What do you want to say? Consider your mood, relationships, and the current topic."
	
	return prompt

func _should_group_continue(group: Node) -> bool:
	# Determine if a group should continue
	if not group.is_active:
		return false
	
	# Check participant count
	if group.get_participant_count() < 2:
		return false
	
	# Check conversation duration
	var duration = group._calculate_conversation_duration()
	if duration > 1800.0:  # 30 minutes
		return false
	
	# Check group mood
	var group_mood = group.group_mood
	if group_mood.valence < -0.8:  # Very negative mood
		return false
	
	return true

func _end_group(group: Node, reason: String) -> void:
	# End a conversation group
	var group_id = group.group_id
	
	# Remove from active groups
	active_groups.erase(group_id)
	group_cooldowns.erase(group_id)
	
	# Remove participants from index
	for npc_id in group.participants:
		participant_index.erase(npc_id)
	
	# End the group
	group.end_conversation(reason)

func _cleanup_group(group_id: String) -> void:
	# Clean up a group that's no longer active
	active_groups.erase(group_id)
	group_cooldowns.erase(group_id)
	print("[ConversationController] Cleaned up group ", group_id)

func _get_npc_conversation_data(npc_id: String) -> Dictionary:
	# Get conversation-related data for an NPC
	if npc_conversation_data.has(npc_id):
		return npc_conversation_data[npc_id]
	
	# Return default data
	return {
		"social_need": 0.5,
		"social_fatigue": 0.0,
		"extroversion": 0.5,
		"relationship_strength": 0.5,
		"conversation_style": "balanced"
	}

# Event handlers
func _on_world_event(event_type: String, data: Dictionary) -> void:
	# Handle world events
	var topic_suggestions = topic_manager.process_world_event(event_type, data)
	
	# Inject relevant topics into active conversations
	for suggestion in topic_suggestions:
		var relevance = suggestion.get("relevance", 0.0)
		if relevance > 0.7:  # High relevance events
			# Find appropriate groups to inject topics
			for group_id in active_groups.keys():
				var group = active_groups[group_id]
				if group.current_topic != suggestion.topic:
					inject_topic_into_group(group_id, suggestion.topic, "world_event")

func _on_npc_action(npc_id: String, action: String, target: String, data: Dictionary) -> void:
	# Handle NPC actions
	match action:
		"join_conversation":
			var group_id = data.get("group_id", "")
			if group_id.is_empty():
				# Find nearby conversation to join
				_try_join_nearby_conversation(npc_id)
			else:
				add_participant_to_group(group_id, npc_id)
		"leave_conversation":
			var group_id = participant_index.get(npc_id, "")
			if not group_id.is_empty():
				remove_participant_from_group(group_id, npc_id, "left")

func _on_participant_joined(npc_id: String, group_id: String) -> void:
	# Handle participant joining a group
	print("[ConversationController] Participant ", npc_id, " joined group ", group_id)

func _on_participant_left(npc_id: String, group_id: String, reason: String) -> void:
	# Handle participant leaving a group
	print("[ConversationController] Participant ", npc_id, " left group ", group_id, " (", reason, ")")

func _on_topic_changed(old_topic: String, new_topic: String, reason: String) -> void:
	# Handle topic changes
	print("[ConversationController] Topic changed from '", old_topic, "' to '", new_topic, "' (", reason, ")")

func _on_conversation_ended(group_id: String, reason: String, summary: String) -> void:
	# Handle conversation ending
	print("[ConversationController] Conversation ", group_id, " ended (", reason, "): ", summary)
	
	# Clean up
	_cleanup_group(group_id)

func _try_join_nearby_conversation(npc_id: String) -> void:
	# Try to find a nearby conversation for an NPC to join
	# This would use proximity detection - for now, just find any available group
	
	for group_id in active_groups.keys():
		var group = active_groups[group_id]
		if group.get_participant_count() < max_participants_per_group:
			if add_participant_to_group(group_id, npc_id):
				print("[ConversationController] NPC ", npc_id, " joined nearby group ", group_id)
				return
	
	print("[ConversationController] No suitable nearby conversation for NPC ", npc_id)

# Utility functions
func get_active_groups() -> Dictionary:
	return active_groups.duplicate()

func get_participant_location(npc_id: String) -> String:
	# Get which conversation group an NPC is in
	return participant_index.get(npc_id, "")

func get_conversation_stats() -> Dictionary:
	var stats = {
		"active_groups": active_groups.size(),
		"max_active_groups": max_active_groups,
		"total_participants": participant_index.size(),
		"group_details": {}
	}
	
	for group_id in active_groups.keys():
		var group = active_groups[group_id]
		stats.group_details[group_id] = group.get_conversation_stats()
	
	return stats

func set_max_active_groups(max_groups: int) -> void:
	max_active_groups = max_groups
	print("[ConversationController] Max active groups set to ", max_groups)

func set_max_participants_per_group(max_participants: int) -> void:
	max_participants_per_group = max_participants
	print("[ConversationController] Max participants per group set to ", max_participants)
