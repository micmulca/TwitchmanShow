extends Node
class_name StatusComponent

# StatusComponent - Comprehensive character status management system
# Replaces NeedsComponent and implements all need types for non-conversation actions
# Implements the Character Status Management System from design_document.md

# Core signals for need changes
signal needs_updated(npc_id: String, needs: Dictionary)
signal need_changed(npc_id: String, need_type: String, old_value: float, new_value: float)
signal critical_need_alert(npc_id: String, need_type: String, value: float)
signal action_drive_changed(npc_id: String, old_drive: float, new_drive: float)

# NPC identifier
@export var npc_id: String = ""

# Need categories and their current values
var needs: Dictionary = {
	"physical": {
		"energy": {"current": 0.8, "decay_rate": 0.02, "recovery_rate": 0.05, "min": 0.0, "max": 1.0},
		"hunger": {"current": 0.3, "decay_rate": 0.01, "recovery_rate": 0.1, "min": 0.0, "max": 1.0},
		"thirst": {"current": 0.4, "decay_rate": 0.015, "recovery_rate": 0.12, "min": 0.0, "max": 1.0},
		"health": {"current": 1.0, "decay_rate": 0.001, "recovery_rate": 0.02, "min": 0.0, "max": 1.0}
	},
	"comfort": {
		"temp_comfort": {"current": 0.0, "decay_rate": 0.02, "recovery_rate": 0.03, "min": -1.0, "max": 1.0},
		"cleanliness": {"current": 0.7, "decay_rate": 0.008, "recovery_rate": 0.15, "min": 0.0, "max": 1.0},
		"comfort": {"current": 0.6, "decay_rate": 0.01, "recovery_rate": 0.08, "min": 0.0, "max": 1.0}
	},
	"activity": {
		"boredom": {"current": 0.4, "decay_rate": 0.005, "recovery_rate": 0.1, "min": 0.0, "max": 1.0},
		"curiosity": {"current": 0.6, "decay_rate": 0.003, "recovery_rate": 0.05, "min": 0.0, "max": 1.0},
		"achievement_need": {"current": 0.5, "decay_rate": 0.002, "recovery_rate": 0.08, "min": 0.0, "max": 1.0}
	},
	"economic": {
		"wealth_satisfaction": {"current": 0.5, "decay_rate": 0.001, "recovery_rate": 0.01, "min": 0.0, "max": 1.0},
		"material_need": {"current": 0.3, "decay_rate": 0.001, "recovery_rate": 0.05, "min": 0.0, "max": 1.0},
		"security_need": {"current": 0.2, "decay_rate": 0.001, "recovery_rate": 0.02, "min": 0.0, "max": 1.0}
	},
	"social": {
		"social_need": {"current": 0.5, "decay_rate": 0.01, "recovery_rate": 0.08, "min": 0.0, "max": 1.0},
		"social_fatigue": {"current": 0.0, "decay_rate": 0.02, "recovery_rate": 0.05, "min": 0.0, "max": 1.0}
	}
}

# Personality traits (Big Five model)
var personality: Dictionary = {
	"big_five": {
		"openness": 0.5,
		"conscientiousness": 0.5,
		"extraversion": 0.5,
		"agreeableness": 0.5,
		"neuroticism": 0.5
	},
	"traits": {
		"risk_tolerance": 0.5,
		"work_ethic": 0.5,
		"creativity": 0.5,
		"patience": 0.5
	}
}

# Current state tracking
var current_action: Dictionary = {}
var location: String = "home"
var last_update_time: float = 0.0
var update_interval: float = 0.1  # Update every 100ms

# Action drive calculation
var action_drive: float = 0.0
var need_priorities: Array[String] = []

# Critical need thresholds
var critical_thresholds: Dictionary = {
	"energy": 0.1,
	"hunger": 0.9,
	"thirst": 0.9,
	"health": 0.2,
	"temp_comfort": 0.8,  # Absolute value
	"cleanliness": 0.1,
	"comfort": 0.1,
	"security_need": 0.8
}

func _ready():
	if npc_id.is_empty():
		npc_id = get_parent().name if get_parent() else "unknown"
	
	last_update_time = _get_current_time_seconds()
	print("[StatusComponent] Initialized for NPC: ", npc_id)
	
	# Calculate initial action drive
	_calculate_action_drive()

func _process(delta: float):
	var current_time = _get_current_time_seconds()
	if current_time - last_update_time >= update_interval:
		_update_needs(delta)
		_check_critical_needs()
		_calculate_action_drive()
		last_update_time = current_time

func _update_needs(delta: float):
	var old_needs = _get_needs_summary()
	
	# Update each need category
	for category in needs.keys():
		for need_type in needs[category].keys():
			var need_data = needs[category][need_type]
			var old_value = need_data.current
			
			# Apply natural decay/recovery
			if need_type in ["energy", "hunger", "thirst"]:
				# These needs naturally decay over time
				need_data.current -= need_data.decay_rate * delta
			elif need_type in ["boredom", "curiosity", "achievement_need"]:
				# These needs naturally increase over time
				need_data.current += need_data.decay_rate * delta
			elif need_type in ["cleanliness", "comfort"]:
				# These needs naturally decay slowly
				need_data.current -= need_data.decay_rate * delta
			
			# Apply natural recovery for some needs
			if need_type in ["health", "social_fatigue"]:
				need_data.current += need_data.recovery_rate * delta
			
			# Apply personality modifiers
			_apply_personality_modifiers(need_type, delta)
			
			# Apply environmental modifiers
			_apply_environmental_modifiers(need_type, delta)
			
			# Clamp values to min/max range
			need_data.current = clamp(need_data.current, need_data.min, need_data.max)
			
			# Emit signal if value changed significantly
			if abs(need_data.current - old_value) > 0.01:
				need_changed.emit(npc_id, need_type, old_value, need_data.current)
	
	# Emit general needs update
	var new_needs = _get_needs_summary()
	needs_updated.emit(npc_id, new_needs)

func _apply_personality_modifiers(need_type: String, delta: float):
	var big_five = personality.big_five
	var traits = personality.traits
	
	match need_type:
		"energy":
			# Conscientious people maintain energy better
			var modifier = (big_five.conscientiousness - 0.5) * 0.1
			needs.physical.energy.current += modifier * delta
		"achievement_need":
			# High conscientiousness increases achievement drive
			var modifier = (big_five.conscientiousness - 0.5) * 0.05
			needs.activity.achievement_need.current += modifier * delta
		"social_need":
			# Extraversion affects social need
			var modifier = (big_five.extraversion - 0.5) * 0.08
			needs.social.social_need.current += modifier * delta
		"curiosity":
			# Openness affects curiosity
			var modifier = (big_five.openness - 0.5) * 0.03
			needs.activity.curiosity.current += modifier * delta
		"work_ethic":
			# Work ethic affects achievement and energy
			var modifier = (traits.work_ethic - 0.5) * 0.02
			needs.activity.achievement_need.current += modifier * delta
			needs.physical.energy.current += modifier * delta

func _apply_environmental_modifiers(need_type: String, delta: float):
	# Basic location effects (fallback when EnvironmentalSensor not available)
	match location:
		"home":
			# Home provides comfort and cleanliness recovery
			if need_type == "comfort":
				needs.comfort.comfort.current += 0.02 * delta
			elif need_type == "cleanliness":
				needs.comfort.cleanliness.current += 0.01 * delta
		"work":
			# Work increases achievement need and energy decay
			if need_type == "achievement_need":
				needs.activity.achievement_need.current += 0.01 * delta
			elif need_type == "energy":
				needs.physical.energy.current -= 0.005 * delta
		"outdoors":
			# Outdoors affects temperature comfort and cleanliness
			if need_type == "temp_comfort":
				# Simulate weather effects (placeholder)
				needs.comfort.temp_comfort.current += (randf() - 0.5) * 0.01 * delta
			elif need_type == "cleanliness":
				needs.comfort.cleanliness.current -= 0.002 * delta

func _check_critical_needs():
	for category in needs.keys():
		for need_type in needs[category].keys():
			var need_data = needs[category][need_type]
			var threshold = critical_thresholds.get(need_type, 0.9)
			
			var is_critical = false
			if need_type == "temp_comfort":
				# Temperature comfort is critical when too hot or too cold
				is_critical = abs(need_data.current) > threshold
			else:
				# Other needs are critical when too low (except hunger/thirst which are critical when high)
				if need_type in ["hunger", "thirst", "security_need"]:
					is_critical = need_data.current > threshold
				else:
					is_critical = need_data.current < threshold
			
			if is_critical:
				critical_need_alert.emit(npc_id, need_type, need_data.current)

func _calculate_action_drive():
	var old_drive = action_drive
	
	# Calculate overall action drive based on need priorities
	var total_drive = 0.0
	var need_count = 0
	
	for category in needs.keys():
		for need_type in needs[category].keys():
			var need_data = needs[category][need_type]
			var urgency = _calculate_need_urgency(need_type, need_data.current)
			var personality_modifier = _get_personality_modifier(need_type)
			
			total_drive += urgency * personality_modifier
			need_count += 1
	
	if need_count > 0:
		action_drive = total_drive / need_count
		action_drive = clamp(action_drive, -1.0, 1.0)
	
	# Update need priorities
	_update_need_priorities()
	
	# Emit signal if drive changed significantly
	if abs(action_drive - old_drive) > 0.01:
		action_drive_changed.emit(npc_id, old_drive, action_drive)

func _calculate_need_urgency(need_type: String, current_value: float) -> float:
	var need_data = needs[_get_need_category(need_type)][need_type]
	var min_val = need_data.min
	var max_val = need_data.max
	var range_size = max_val - min_val
	
	# Calculate urgency based on need type
	match need_type:
		"energy", "health", "cleanliness", "comfort":
			# These are better when higher, urgent when low
			return 1.0 - ((current_value - min_val) / range_size)
		"hunger", "thirst", "boredom", "security_need":
			# These are better when lower, urgent when high
			return (current_value - min_val) / range_size
		"temp_comfort":
			# Temperature comfort is best at 0, urgent when extreme
			return abs(current_value) / max_val
		"curiosity", "achievement_need":
			# These are better when higher, but not urgent when low
			return 0.5 + ((current_value - min_val) / range_size) * 0.5
		"social_need":
			# Social need is complex - urgent when very low or very high
			var normalized = (current_value - min_val) / range_size
			if normalized < 0.2 or normalized > 0.8:
				return normalized
			else:
				return 0.5
		_:
			return 0.5

func _get_personality_modifier(need_type: String) -> float:
	var big_five = personality.big_five
	var traits = personality.traits
	
	match need_type:
		"energy":
			return 1.0 + (big_five.conscientiousness - 0.5) * 0.3
		"achievement_need":
			return 1.0 + (big_five.conscientiousness - 0.5) * 0.4
		"social_need":
			return 1.0 + (big_five.extraversion - 0.5) * 0.5
		"curiosity":
			return 1.0 + (big_five.openness - 0.5) * 0.4
		"work_ethic":
			return 1.0 + (traits.work_ethic - 0.5) * 0.3
		"risk_tolerance":
			return 1.0 + (traits.risk_tolerance - 0.5) * 0.2
		_:
			return 1.0

func _get_need_category(need_type: String) -> String:
	for category in needs.keys():
		if needs[category].has(need_type):
			return category
	return ""

func _update_need_priorities():
	# Sort needs by urgency to determine priorities
	var need_urgencies: Array[Dictionary] = []
	
	for category in needs.keys():
		for need_type in needs[category].keys():
			var need_data = needs[category][need_type]
			var urgency = _calculate_need_urgency(need_type, need_data.current)
			need_urgencies.append({
				"category": category,
				"type": need_type,
				"urgency": urgency,
				"current": need_data.current
			})
	
	# Sort by urgency (highest first)
	need_urgencies.sort_custom(func(a, b): return a.urgency > b.urgency)
	
	# Extract priority order
	need_priorities.clear()
	for need_info in need_urgencies:
		need_priorities.append(need_info.type)

# Public API for external systems
func get_need_value(need_type: String) -> float:
	var category = _get_need_category(need_type)
	if category.is_empty():
		return 0.0
	return needs[category][need_type].current

func set_need_value(need_type: String, value: float):
	var category = _get_need_category(need_type)
	if category.is_empty():
		return
	
	var need_data = needs[category][need_type]
	var old_value = need_data.current
	need_data.current = clamp(value, need_data.min, need_data.max)
	
	if abs(need_data.current - old_value) > 0.01:
		need_changed.emit(npc_id, need_type, old_value, need_data.current)

func modify_need_value(need_type: String, delta: float):
	var current_value = get_need_value(need_type)
	set_need_value(need_type, current_value + delta)

func get_action_drive() -> float:
	return action_drive

func get_need_priorities() -> Array[String]:
	return need_priorities.duplicate()

func get_critical_needs() -> Array[String]:
	var critical: Array[String] = []
	
	for category in needs.keys():
		for need_type in needs[category].keys():
			var need_data = needs[category][need_type]
			var threshold = critical_thresholds.get(need_type, 0.9)
			
			var is_critical = false
			if need_type == "temp_comfort":
				is_critical = abs(need_data.current) > threshold
			else:
				if need_type in ["hunger", "thirst", "security_need"]:
					is_critical = need_data.current > threshold
				else:
					is_critical = need_data.current < threshold
			
			if is_critical:
				critical.append(need_type)
	
	return critical

func get_needs_summary() -> Dictionary:
	var summary = {}
	
	for category in needs.keys():
		summary[category] = {}
		for need_type in needs[category].keys():
			var need_data = needs[category][need_type]
			summary[category][need_type] = need_data.current
	
	return summary

func get_full_status() -> Dictionary:
	return {
		"npc_id": npc_id,
		"needs": _get_needs_summary(),
		"personality": personality.duplicate(true),
		"action_drive": action_drive,
		"need_priorities": need_priorities.duplicate(),
		"critical_needs": get_critical_needs(),
		"current_action": current_action.duplicate(true),
		"location": location
	}

func set_personality_trait(category: String, trait: String, value: float):
	if personality.has(category) and personality[category].has(trait):
		personality[category][trait] = clamp(value, 0.0, 1.0)

func set_location(new_location: String):
	location = new_location

func set_current_action(action_data: Dictionary):
	current_action = action_data.duplicate(true)

func modify_need(need_type: String, modifier: float):
	# Allow external systems to modify needs (used by EnvironmentalSensor)
	# Find the need in any category
	for category in needs.keys():
		if needs[category].has(need_type):
			var need_data = needs[category][need_type]
			var old_value = need_data.current
			
			# Apply the modifier
			need_data.current += modifier
			
			# Clamp to min/max range
			need_data.current = clamp(need_data.current, need_data.min, need_data.max)
			
			# Emit signal if value changed significantly
			if abs(need_data.current - old_value) > 0.01:
				need_changed.emit(npc_id, need_type, old_value, need_data.current)
			
			return  # Found and modified the need

# Console commands for debugging
func console_command(command: String, args: Array) -> Dictionary:
	match command:
		"status":
			var status = get_full_status()
			var message = "Status for " + npc_id + ":\n"
			message += "Action Drive: " + str(round(action_drive * 100)) + "%\n"
			message += "Location: " + location + "\n"
			message += "Critical Needs: " + str(get_critical_needs().size()) + "\n"
			message += "Top Priority: " + (need_priorities[0] if need_priorities.size() > 0 else "none")
			return {"success": true, "message": message}
		
		"set_need":
			if args.size() >= 2:
				var need_type = args[0]
				var value = float(args[1])
				set_need_value(need_type, value)
				return {"success": true, "message": "Set " + need_type + " to " + str(value)}
			return {"success": false, "message": "Usage: set_need <need_type> <value>"}
		
		"modify_need":
			if args.size() >= 2:
				var need_type = args[0]
				var delta = float(args[1])
				modify_need_value(need_type, delta)
				return {"success": true, "message": "Modified " + need_type + " by " + str(delta)}
			return {"success": false, "message": "Usage: modify_need <need_type> <delta>"}
		
		"set_personality":
			if args.size() >= 3:
				var category = args[0]
				var trait = args[1]
				var value = float(args[2])
				set_personality_trait(category, trait, value)
				return {"success": true, "message": "Set " + category + "." + trait + " to " + str(value)}
			return {"success": false, "message": "Usage: set_personality <category> <trait> <value>"}
		
		"set_location":
			if args.size() >= 1:
				var new_location = args[0]
				set_location(new_location)
				return {"success": true, "message": "Set location to " + new_location}
			return {"success": false, "message": "Usage: set_location <location>"}
		
		"priorities":
			var message = "Need priorities for " + npc_id + ":\n"
			for i in range(min(need_priorities.size(), 5)):
				var need_type = need_priorities[i]
				var urgency = _calculate_need_urgency(need_type, get_need_value(need_type))
				message += str(i + 1) + ". " + need_type + " (urgency: " + str(round(urgency * 100)) + "%)\n"
			return {"success": true, "message": message}
		
		_:
			return {"success": false, "message": "Unknown command: " + command}


# Helper function to get current time in seconds
func _get_current_time_seconds() -> float:
	var time_dict = Time.get_time_dict_from_system()
	return time_dict.hour * 3600 + time_dict.minute * 60 + time_dict.second
