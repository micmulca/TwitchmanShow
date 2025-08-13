extends Node
class_name NeedsComponent

# NeedsComponent - Manages NPC social needs, fatigue, and extroversion
# Implements the social simulation model from the design document

signal needs_updated(npc_id: String, needs: Dictionary)
signal social_fatigue_changed(npc_id: String, old_fatigue: float, new_fatigue: float)
signal social_need_changed(npc_id: String, old_need: float, new_need: float)

# NPC identifier
@export var npc_id: String = ""

# Social simulation variables
@export var social_need: float = 0.5  # 0.0 = no social need, 1.0 = high social need
@export var social_fatigue: float = 0.0  # 0.0 = no fatigue, 1.0 = exhausted
@export var extroversion: float = 0.5  # 0.0 = introvert, 1.0 = extrovert

# Configuration
@export var need_recovery_rate: float = 0.1  # per second
@export var fatigue_decay_rate: float = 0.05  # per second
@export var speaking_fatigue_gain: float = 0.02  # per second of speaking
@export var listening_fatigue_gain: float = 0.01  # per second of listening
@export var group_size_fatigue_multiplier: float = 1.2  # fatigue multiplier per additional participant
@export var solitude_need_gain: float = 0.15  # per second when alone
@export var social_exposure_need_decay: float = 0.08  # per second when socializing

# Extroversion modifiers
@export var extroversion_need_modifier: float = 0.3  # how much extroversion affects need baseline
@export var extroversion_fatigue_modifier: float = 0.2  # how much extroversion affects fatigue resistance

# Current state
var is_speaking: bool = false
var is_listening: bool = false
var current_group_size: int = 0
var last_update_time: float = 0.0
var update_interval: float = 0.1  # Update every 100ms

# Social drive calculation
var social_drive: float = 0.0

func _ready():
	if npc_id.is_empty():
		npc_id = get_parent().name if get_parent() else "unknown"
	
	last_update_time = Time.get_time()
	print("[NeedsComponent] Initialized for NPC: ", npc_id)

func _process(delta: float):
	var current_time = Time.get_time()
	if current_time - last_update_time >= update_interval:
		_update_needs(delta)
		last_update_time = current_time

func _update_needs(delta: float):
	var old_need = social_need
	var old_fatigue = social_fatigue
	
	# Update social need based on current state
	if current_group_size == 0:
		# Alone - need increases
		social_need += solitude_need_gain * delta
	else:
		# Socializing - need decreases
		social_need -= social_exposure_need_decay * delta
	
	# Update social fatigue based on current activities
	if is_speaking:
		var speaking_fatigue = speaking_fatigue_gain * delta
		if current_group_size > 1:
			speaking_fatigue *= (1.0 + (current_group_size - 1) * group_size_fatigue_multiplier)
		social_fatigue += speaking_fatigue
	
	if is_listening:
		var listening_fatigue = listening_fatigue_gain * delta
		if current_group_size > 1:
			listening_fatigue *= (1.0 + (current_group_size - 1) * group_size_fatigue_multiplier)
		social_fatigue += listening_fatigue
	
	# Apply extroversion modifiers
	var extroversion_need_bonus = (extroversion - 0.5) * extroversion_need_modifier
	var extroversion_fatigue_resistance = (extroversion - 0.5) * extroversion_fatigue_modifier
	
	social_need += extroversion_need_bonus * delta
	social_fatigue -= extroversion_fatigue_resistance * delta
	
	# Natural recovery/decay
	social_need += need_recovery_rate * delta
	social_fatigue -= fatigue_decay_rate * delta
	
	# Clamp values
	social_need = clamp(social_need, 0.0, 1.0)
	social_fatigue = clamp(social_fatigue, 0.0, 1.0)
	
	# Calculate social drive
	_update_social_drive()
	
	# Emit signals if values changed significantly
	if abs(social_need - old_need) > 0.01:
		social_need_changed.emit(npc_id, old_need, social_need)
	
	if abs(social_fatigue - old_fatigue) > 0.01:
		social_fatigue_changed.emit(npc_id, old_fatigue, social_fatigue)
	
	# Emit general needs update
	needs_updated.emit(npc_id, get_needs_state())

func _update_social_drive():
	# Social drive function: (SN - k_fatigue * SF) + k_trait * E
	var k_fatigue = 0.8  # Fatigue penalty coefficient
	var k_trait = 0.4    # Extroversion bonus coefficient
	
	social_drive = (social_need - k_fatigue * social_fatigue) + k_trait * extroversion
	social_drive = clamp(social_drive, -1.0, 1.0)

# Public API for external systems
func set_speaking_state(speaking: bool):
	is_speaking = speaking

func set_listening_state(listening: bool):
	is_listening = listening

func set_group_size(size: int):
	current_group_size = size

func get_social_drive() -> float:
	return social_drive

func get_needs_state() -> Dictionary:
	return {
		"social_need": social_need,
		"social_fatigue": social_fatigue,
		"extroversion": extroversion,
		"social_drive": social_drive,
		"is_speaking": is_speaking,
		"is_listening": is_listening,
		"current_group_size": current_group_size
	}

func should_join_conversation() -> bool:
	# High social drive and low fatigue
	return social_drive > 0.3 and social_fatigue < 0.7

func should_leave_conversation() -> bool:
	# Low social drive or high fatigue
	return social_drive < -0.2 or social_fatigue > 0.8

func should_start_speaking() -> bool:
	# Moderate social drive and not too fatigued
	return social_drive > 0.1 and social_fatigue < 0.6

func get_speaking_duration() -> float:
	# Calculate how long this NPC should speak based on needs
	var base_duration = 2.0  # Base speaking duration in seconds
	var drive_modifier = 1.0 + (social_drive * 0.5)  # Drive affects duration
	var fatigue_modifier = 1.0 - (social_fatigue * 0.3)  # Fatigue reduces duration
	
	return base_duration * drive_modifier * fatigue_modifier

func get_listening_patience() -> float:
	# Calculate how long this NPC will listen before wanting to speak
	var base_patience = 5.0  # Base listening patience in seconds
	var drive_modifier = 1.0 - (social_drive * 0.4)  # High drive reduces patience
	var fatigue_modifier = 1.0 + (social_fatigue * 0.5)  # Fatigue increases patience
	
	return base_patience * drive_modifier * fatigue_modifier

# Console commands for debugging
func console_command(command: String, args: Array) -> Dictionary:
	match command:
		"set_need":
			if args.size() >= 1:
				var value = float(args[0])
				social_need = clamp(value, 0.0, 1.0)
				return {"success": true, "message": "Set social_need to " + str(social_need)}
			return {"success": false, "message": "Usage: set_need <value>"}
		
		"set_fatigue":
			if args.size() >= 1:
				var value = float(args[0])
				social_fatigue = clamp(value, 0.0, 1.0)
				return {"success": true, "message": "Set social_fatigue to " + str(social_fatigue)}
			return {"success": false, "message": "Usage: set_fatigue <value>"}
		
		"set_extroversion":
			if args.size() >= 1:
				var value = float(args[0])
				extroversion = clamp(value, 0.0, 1.0)
				return {"success": true, "message": "Set extroversion to " + str(extroversion)}
			return {"success": false, "message": "Usage: set_extroversion <value>"}
		
		"status":
			var state = get_needs_state()
			return {
				"success": true, 
				"message": "NPC: " + npc_id + 
					" | Need: " + str(round(state.social_need * 100)) + "%" +
					" | Fatigue: " + str(round(state.social_fatigue * 100)) + "%" +
					" | Drive: " + str(round(state.social_drive * 100)) + "%" +
					" | Extroversion: " + str(round(state.extroversion * 100)) + "%"
			}
		
		_:
			return {"success": false, "message": "Unknown command: " + command}
