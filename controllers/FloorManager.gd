extends Node

# FloorManager - Manages speaking order and turn-taking in conversations
# Handles interrupts, speaking time limits, and natural conversation flow

signal speaker_changed(previous_speaker: String, new_speaker: String, reason: String)
signal turn_timeout(speaker: String, group_id: String)
signal interrupt_requested(interrupter: String, current_speaker: String, reason: String)

# Turn management
var current_speaker: String = ""
var turn_start_time: float = 0.0
var turn_duration: float = 0.0
var max_turn_duration: float = 30.0  # Maximum time per turn
var min_turn_duration: float = 3.0   # Minimum time per turn

# Interrupt system
var interrupt_queue: Array[Dictionary] = []
var interrupt_cooldown: float = 5.0  # Time before interrupts are allowed again
var last_interrupt_time: float = 0.0

# Speaking order
var speaking_order: Array[String] = []
var speaking_index: int = 0
var round_robin_enabled: bool = true

# Conversation group reference
var conversation_group: Node = null

func _ready():
	# Initialize timing
	turn_start_time = Time.get_time()
	last_interrupt_time = -interrupt_cooldown

func set_conversation_group(group: Node) -> void:
	# Set the conversation group this floor manager is managing
	conversation_group = group
	
	if conversation_group:
		# Connect to group signals
		conversation_group.participant_joined.connect(_on_participant_joined)
		conversation_group.participant_left.connect(_on_participant_left)
		conversation_group.topic_changed.connect(_on_topic_changed)
		
		# Initialize speaking order
		_update_speaking_order()

func start_turn(speaker: String, topic: String = "") -> bool:
	# Start a new speaking turn
	if not conversation_group or not conversation_group.is_participant(speaker):
		print("[FloorManager] Cannot start turn for non-participant: ", speaker)
		return false
	
	# End previous turn if any
	if current_speaker != "":
		end_turn("new_speaker")
	
	# Start new turn
	current_speaker = speaker
	turn_start_time = Time.get_time()
	turn_duration = 0.0
	
	# Emit signal
	speaker_changed.emit("", speaker, "turn_started")
	
	print("[FloorManager] Turn started for ", speaker, " on topic: ", topic)
	return true

func end_turn(reason: String = "natural_end") -> void:
	# End the current speaking turn
	if current_speaker == "":
		return
	
	var speaker = current_speaker
	var duration = Time.get_time() - turn_start_time
	
	# Update turn duration
	turn_duration = duration
	
	# Emit signal
	speaker_changed.emit(speaker, "", reason)
	
	print("[FloorManager] Turn ended for ", speaker, " after ", round(duration), "s (", reason, ")")
	
	# Clear current speaker
	current_speaker = ""
	turn_start_time = 0.0
	turn_duration = 0.0
	
	# Advance to next speaker if round-robin is enabled
	if round_robin_enabled and reason == "natural_end":
		advance_to_next_speaker()

func advance_to_next_speaker() -> String:
	# Advance to the next speaker in the round-robin order
	if not conversation_group or speaking_order.is_empty():
		return ""
	
	# Find current speaker index
	var current_index = speaking_order.find(current_speaker)
	if current_index == -1:
		current_index = speaking_index
	
	# Move to next speaker
	speaking_index = (current_index + 1) % speaking_order.size()
	var next_speaker = speaking_order[speaking_index]
	
	# Start turn for next speaker
	if start_turn(next_speaker):
		return next_speaker
	
	return ""

func request_interrupt(interrupter: String, reason: String = "natural_interrupt") -> bool:
	# Request an interrupt from another participant
	if not conversation_group or not conversation_group.is_participant(interrupter):
		print("[FloorManager] Cannot interrupt: ", interrupter, " is not a participant")
		return false
	
	if current_speaker == "":
		print("[FloorManager] No current speaker to interrupt")
		return false
	
	if interrupter == current_speaker:
		print("[FloorManager] Cannot interrupt yourself")
		return false
	
	# Check interrupt cooldown
	var current_time = Time.get_time()
	if current_time - last_interrupt_time < interrupt_cooldown:
		print("[FloorManager] Interrupt cooldown active")
		return false
	
	# Check if interrupt is appropriate
	if not _is_interrupt_appropriate(interrupter, reason):
		print("[FloorManager] Interrupt not appropriate: ", reason)
		return false
	
	# Add to interrupt queue
	interrupt_queue.append({
		"interrupter": interrupter,
		"reason": reason,
		"timestamp": current_time,
		"priority": _calculate_interrupt_priority(interrupter, reason)
	})
	
	# Sort queue by priority
	interrupt_queue.sort_custom(func(a, b): return a.priority > b.priority)
	
	# Emit signal
	interrupt_requested.emit(interrupter, current_speaker, reason)
	
	print("[FloorManager] Interrupt requested by ", interrupter, " (", reason, ")")
	return true

func process_interrupts() -> bool:
	# Process pending interrupts
	if interrupt_queue.is_empty() or current_speaker == "":
		return false
	
	var interrupt = interrupt_queue.pop_front()
	var interrupter = interrupt.interrupter
	var reason = interrupt.reason
	
	# Grant the interrupt
	if grant_interrupt(interrupter, reason):
		last_interrupt_time = Time.get_time()
		return true
	
	return false

func grant_interrupt(interrupter: String, reason: String) -> bool:
	# Grant an interrupt to a participant
	if not conversation_group or not conversation_group.is_participant(interrupter):
		return false
	
	# End current turn
	end_turn("interrupted")
	
	# Start turn for interrupter
	if start_turn(interrupter):
		print("[FloorManager] Interrupt granted to ", interrupter, " (", reason, ")")
		return true
	
	return false

func force_speaker_change(new_speaker: String, reason: String = "forced_change") -> bool:
	# Force a change of speaker (for console commands or system events)
	if not conversation_group or not conversation_group.is_participant(new_speaker):
		return false
	
	# End current turn
	end_turn(reason)
	
	# Start turn for new speaker
	if start_turn(new_speaker):
		print("[FloorManager] Forced speaker change to ", new_speaker, " (", reason, ")")
		return true
	
	return false

func _update_speaking_order() -> void:
	# Update the speaking order based on current participants
	if not conversation_group:
		return
	
	speaking_order = conversation_group.participants.duplicate()
	speaking_index = 0
	
	# Shuffle for natural variation
	speaking_order.shuffle()
	
	print("[FloorManager] Updated speaking order: ", speaking_order)

func _is_interrupt_appropriate(interrupter: String, reason: String) -> bool:
	# Determine if an interrupt is appropriate
	var current_time = Time.get_time()
	var turn_elapsed = current_time - turn_start_time
	
	# Don't allow interrupts too early in a turn
	if turn_elapsed < min_turn_duration:
		return false
	
	# Allow urgent interrupts
	var urgent_reasons = ["emergency", "important_news", "clarification_needed"]
	if reason in urgent_reasons:
		return true
	
	# Allow natural conversation flow interrupts
	var natural_reasons = ["agreement", "disagreement", "related_story", "question"]
	if reason in natural_reasons and turn_elapsed > min_turn_duration * 2:
		return true
	
	return false

func _calculate_interrupt_priority(interrupter: String, reason: String) -> float:
	# Calculate interrupt priority (higher = more important)
	var priority = 0.0
	
	# Base priority by reason
	match reason:
		"emergency":
			priority = 10.0
		"important_news":
			priority = 8.0
		"clarification_needed":
			priority = 6.0
		"agreement":
			priority = 4.0
		"disagreement":
			priority = 5.0
		"related_story":
			priority = 3.0
		"question":
			priority = 4.0
		_:
			priority = 1.0
	
	# Adjust by participant relationship (if available)
	if conversation_group:
		var participant_data = conversation_group.get_participant_data(interrupter)
		var relationship_strength = participant_data.get("relationship_strength", 0.5)
		priority += relationship_strength * 2.0
	
	return priority

func _on_participant_joined(npc_id: String, group_id: String) -> void:
	# Handle participant joining
	_update_speaking_order()
	
	# If no current speaker, start with the new participant
	if current_speaker == "" and round_robin_enabled:
		start_turn(npc_id)

func _on_participant_left(npc_id: String, group_id: String, reason: String) -> void:
	# Handle participant leaving
	_update_speaking_order()
	
	# If the leaving participant was speaking, end their turn
	if current_speaker == npc_id:
		end_turn("participant_left")
	
	# Remove from interrupt queue
	interrupt_queue = interrupt_queue.filter(func(interrupt): return interrupt.interrupter != npc_id)

func _on_topic_changed(old_topic: String, new_topic: String, reason: String) -> void:
	# Handle topic changes
	# Reset speaking order for new topic
	_update_speaking_order()
	
	# If there's a current speaker, consider ending their turn
	if current_speaker != "" and reason == "forced_change":
		end_turn("topic_change")

func _process(delta: float) -> void:
	# Process floor management logic
	if not conversation_group or not conversation_group.is_active:
		return
	
	# Check for turn timeout
	if current_speaker != "":
		var current_time = Time.get_time()
		var turn_elapsed = current_time - turn_start_time
		
		if turn_elapsed > max_turn_duration:
			# Turn timeout
			turn_timeout.emit(current_speaker, conversation_group.group_id)
			end_turn("timeout")
	
	# Process interrupts
	process_interrupts()

# Utility functions
func get_current_speaker() -> String:
	return current_speaker

func get_turn_elapsed() -> float:
	if current_speaker == "":
		return 0.0
	return Time.get_time() - turn_start_time

func get_speaking_order() -> Array[String]:
	return speaking_order.duplicate()

func get_interrupt_queue() -> Array[Dictionary]:
	return interrupt_queue.duplicate()

func is_speaking(npc_id: String) -> bool:
	return current_speaker == npc_id

func can_interrupt(npc_id: String) -> bool:
	if current_speaker == "" or npc_id == current_speaker:
		return false
	
	var current_time = Time.get_time()
	return current_time - last_interrupt_time >= interrupt_cooldown

func get_floor_stats() -> Dictionary:
	return {
		"current_speaker": current_speaker,
		"turn_elapsed": get_turn_elapsed(),
		"speaking_order": speaking_order.duplicate(),
		"interrupt_queue_size": interrupt_queue.size(),
		"round_robin_enabled": round_robin_enabled
	}
