extends Node

# DialogueComponent - Manages active dialogue lines and speaker state for NPCs
# Displays conversation content and handles dialogue lifecycle

signal dialogue_started(speaker_id: String, text: String, group_id: String)
signal dialogue_ended(speaker_id: String, group_id: String)
signal dialogue_interrupted(speaker_id: String, interrupter_id: String, group_id: String)

# Dialogue state
var current_speaker: String = ""
var current_text: String = ""
var current_group_id: String = ""
var dialogue_start_time: float = 0.0
var dialogue_duration: float = 0.0
var max_dialogue_duration: float = 15.0  # Maximum time to display dialogue

# Dialogue bubble management
var dialogue_bubble: Control = null
var bubble_offset: Vector2 = Vector2(0, -50)  # Offset above NPC
var bubble_fade_time: float = 0.5  # Time to fade in/out

# NPC reference
var npc_id: String = ""
var npc_node: Node2D = null

# Conversation context
var conversation_context: Dictionary = {}
var mood_effects: Dictionary = {}
var relationship_updates: Array[Dictionary] = []

func _ready():
	# Initialize dialogue component
	print("[DialogueComponent] Initialized for NPC: ", npc_id)

func set_npc_reference(npc_id: String, npc_node: Node2D) -> void:
	# Set the NPC this component belongs to
	self.npc_id = npc_id
	self.npc_node = npc_node
	
	# Create dialogue bubble
	_create_dialogue_bubble()

func _create_dialogue_bubble() -> void:
	# Create the dialogue bubble UI
	dialogue_bubble = Control.new()
	dialogue_bubble.name = "DialogueBubble"
	
	# Set up bubble properties
	dialogue_bubble.visible = false
	dialogue_bubble.modulate.a = 0.0
	
	# Add to NPC node
	if npc_node:
		npc_node.add_child(dialogue_bubble)
		_setup_bubble_layout()

func _setup_bubble_layout() -> void:
	# Set up the dialogue bubble layout
	if not dialogue_bubble:
		return
	
	# Create background panel
	var background = Panel.new()
	background.name = "Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	background.offset_bottom = 60
	background.offset_left = -100
	background.offset_right = 100
	
	# Create text label
	var text_label = Label.new()
	text_label.name = "Text"
	text_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	text_label.offset_left = -90
	text_label.offset_right = 90
	text_label.offset_top = 10
	text_label.offset_bottom = 50
	text_label.text = ""
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Add to bubble
	dialogue_bubble.add_child(background)
	dialogue_bubble.add_child(text_label)

func start_dialogue(text: String, group_id: String, context: Dictionary = {}) -> void:
	# Start displaying dialogue
	if current_speaker == npc_id:
		# Already speaking, update text
		update_dialogue_text(text)
		return
	
	# Set dialogue state
	current_speaker = npc_id
	current_text = text
	current_group_id = group_id
	dialogue_start_time = Time.get_time()
	dialogue_duration = 0.0
	conversation_context = context.duplicate(true)
	
	# Show dialogue bubble
	_show_dialogue_bubble()
	
	# Emit signal
	dialogue_started.emit(npc_id, text, group_id)
	
	print("[DialogueComponent] ", npc_id, " started speaking: ", text)

func update_dialogue_text(text: String) -> void:
	# Update the current dialogue text
	current_text = text
	
	if dialogue_bubble:
		var text_label = dialogue_bubble.get_node("Text")
		if text_label:
			text_label.text = text
	
	print("[DialogueComponent] ", npc_id, " updated dialogue: ", text)

func end_dialogue(reason: String = "natural_end") -> void:
	# End the current dialogue
	if current_speaker != npc_id:
		return
	
	# Hide dialogue bubble
	_hide_dialogue_bubble()
	
	# Clear state
	var speaker = current_speaker
	var group_id = current_group_id
	
	current_speaker = ""
	current_text = ""
	current_group_id = ""
	dialogue_start_time = 0.0
	dialogue_duration = 0.0
	
	# Emit signal
	dialogue_ended.emit(speaker, group_id)
	
	print("[DialogueComponent] ", npc_id, " ended dialogue (", reason, ")")

func interrupt_dialogue(interrupter_id: String, reason: String = "interrupted") -> void:
	# Interrupt the current dialogue
	if current_speaker != npc_id:
		return
	
	# Emit signal
	dialogue_interrupted.emit(npc_id, interrupter_id, current_group_id)
	
	# End dialogue
	end_dialogue("interrupted")
	
	print("[DialogueComponent] ", npc_id, " dialogue interrupted by ", interrupter_id)

func _show_dialogue_bubble() -> void:
	# Show the dialogue bubble with fade-in effect
	if not dialogue_bubble:
		return
	
	# Update bubble position
	_update_bubble_position()
	
	# Update text
	var text_label = dialogue_bubble.get_node("Text")
	if text_label:
		text_label.text = current_text
	
	# Show and fade in
	dialogue_bubble.visible = true
	
	# Create fade-in tween
	var tween = create_tween()
	tween.tween_property(dialogue_bubble, "modulate:a", 1.0, bubble_fade_time)

func _hide_dialogue_bubble() -> void:
	# Hide the dialogue bubble with fade-out effect
	if not dialogue_bubble:
		return
	
	# Create fade-out tween
	var tween = create_tween()
	tween.tween_property(dialogue_bubble, "modulate:a", 0.0, bubble_fade_time)
	tween.tween_callback(func(): dialogue_bubble.visible = false)

func _update_bubble_position() -> void:
	# Update the dialogue bubble position relative to the NPC
	if not dialogue_bubble or not npc_node:
		return
	
	# Get NPC position
	var npc_pos = npc_node.global_position
	
	# Set bubble position with offset
	dialogue_bubble.global_position = npc_pos + bubble_offset

func _process(delta: float) -> void:
	# Process dialogue component logic
	if current_speaker == npc_id:
		# Update dialogue duration
		dialogue_duration = Time.get_time() - dialogue_start_time
		
		# Check for dialogue timeout
		if dialogue_duration > max_dialogue_duration:
			end_dialogue("timeout")
		
		# Update bubble position if NPC is moving
		if dialogue_bubble and dialogue_bubble.visible:
			_update_bubble_position()

func process_llm_response(response: Dictionary) -> void:
	# Process an LLM response for this NPC
	if not response.has("utterance"):
		print("[DialogueComponent] Invalid LLM response for ", npc_id)
		return
	
	var utterance = response.utterance
	var intent = response.get("intent", "continue")
	var summary_note = response.get("summary_note", "")
	var relationship_effects = response.get("relationship_effects", [])
	var mood_shift = response.get("mood_shift", {})
	
	# Start or update dialogue
	if current_speaker == npc_id:
		update_dialogue_text(utterance)
	else:
		start_dialogue(utterance, current_group_id, conversation_context)
	
	# Process effects
	_process_relationship_effects(relationship_effects)
	_process_mood_shift(mood_shift)
	
	# Add to conversation memory
	_add_to_conversation_memory(response)
	
	print("[DialogueComponent] ", npc_id, " processed LLM response: ", intent)

func _process_relationship_effects(effects: Array) -> void:
	# Process relationship effects from dialogue
	for effect in effects:
		var target = effect.get("target", "")
		var delta = effect.get("delta", 0.0)
		var tag = effect.get("tag", "")
		
		if target != "" and delta != 0.0:
			relationship_updates.append({
				"target": target,
				"delta": delta,
				"tag": tag,
				"timestamp": Time.get_time()
			})
			
			# Emit relationship change event
			EventBus.emit_relationship_event(npc_id, target, delta, tag)
			
			print("[DialogueComponent] ", npc_id, " relationship with ", target, " changed by ", delta, " (", tag, ")")

func _process_mood_shift(mood_shift: Dictionary) -> void:
	# Process mood shift from dialogue
	var valence = mood_shift.get("valence", 0.0)
	var arousal = mood_shift.get("arousal", 0.0)
	
	if valence != 0.0 or arousal != 0.0:
		mood_effects = {
			"valence": valence,
			"arousal": arousal,
			"timestamp": Time.get_time()
		}
		
		# Emit mood change event
		EventBus.emit_mood_event(npc_id, {}, mood_effects)
		
		print("[DialogueComponent] ", npc_id, " mood shifted: valence=", valence, ", arousal=", arousal)

func _add_to_conversation_memory(response: Dictionary) -> void:
	# Add dialogue response to conversation memory
	var memory_entry = {
		"speaker": npc_id,
		"utterance": response.get("utterance", ""),
		"intent": response.get("intent", ""),
		"summary_note": response.get("summary_note", ""),
		"timestamp": Time.get_time(),
		"group_id": current_group_id
	}
	
	# This would be stored in the conversation group's memory
	# For now, just log it
	print("[DialogueComponent] Added to memory: ", memory_entry)

func is_speaking() -> bool:
	# Check if this NPC is currently speaking
	return current_speaker == npc_id

func get_current_dialogue() -> Dictionary:
	# Get current dialogue information
	return {
		"speaker": current_speaker,
		"text": current_text,
		"group_id": current_group_id,
		"duration": dialogue_duration,
		"start_time": dialogue_start_time
	}

func get_dialogue_stats() -> Dictionary:
	# Get dialogue component statistics
	return {
		"npc_id": npc_id,
		"is_speaking": is_speaking(),
		"current_dialogue": get_current_dialogue(),
		"relationship_updates": relationship_updates.size(),
		"mood_effects": mood_effects.size(),
		"conversation_context": conversation_context.size()
	}

func clear_conversation_data() -> void:
	# Clear conversation-related data
	conversation_context.clear()
	mood_effects.clear()
	relationship_updates.clear()
	
	print("[DialogueComponent] Cleared conversation data for ", npc_id)

func set_bubble_offset(offset: Vector2) -> void:
	# Set the bubble offset from the NPC
	bubble_offset = offset
	if dialogue_bubble and dialogue_bubble.visible:
		_update_bubble_position()

func set_max_dialogue_duration(duration: float) -> void:
	# Set the maximum dialogue duration
	max_dialogue_duration = duration

func set_bubble_fade_time(fade_time: float) -> void:
	# Set the bubble fade in/out time
	bubble_fade_time = fade_time
