extends Node
class_name EnvironmentalSensor

# EnvironmentalSensor - Provides environmental context for character behavior
# Integrates with StatusComponent, ActionPlanner, and existing systems

signal location_changed(character_id: String, old_location: String, new_location: String)
signal weather_changed(old_weather: Dictionary, new_weather: Dictionary)
signal time_period_changed(old_period: String, new_period: String)
signal resource_availability_changed(location: String, resources: Array)
signal environmental_modifier_applied(character_id: String, need_type: String, modifier: float, reason: String)
signal context_behavior_triggered(character_id: String, behavior_type: String, context: Dictionary)
signal seasonal_action_modifier(season: String, action_id: String, modifier: float)

# Character reference
var character_id: String = ""
var current_location: String = "home"
var previous_location: String = ""

# Weather system
var current_weather: Dictionary = {
	"type": "clear",
	"intensity": "mild",
	"temperature": 20.0,  # Celsius
	"humidity": 0.5,
	"wind_speed": 5.0,
	"precipitation": 0.0,
	"visibility": 1.0
}

var weather_patterns: Dictionary = {
	"clear": {"temperature_mod": 0.0, "comfort_mod": 0.0, "movement_mod": 0.0},
	"sunny": {"temperature_mod": 5.0, "comfort_mod": 0.1, "movement_mod": 0.1},
	"cloudy": {"temperature_mod": -2.0, "comfort_mod": 0.0, "movement_mod": 0.0},
	"rain": {"temperature_mod": -3.0, "comfort_mod": -0.2, "movement_mod": -0.3},
	"storm": {"temperature_mod": -5.0, "comfort_mod": -0.4, "movement_mod": -0.5},
	"fog": {"temperature_mod": -1.0, "comfort_mod": -0.1, "movement_mod": -0.2},
	"windy": {"temperature_mod": -2.0, "comfort_mod": -0.1, "movement_mod": -0.1}
}

# Time of day system
var current_time: Dictionary = {}
var time_periods: Dictionary = {
	"dawn": {"start": 5, "end": 7, "energy_mod": 0.1, "mood_mod": 0.05},
	"morning": {"start": 7, "end": 12, "energy_mod": 0.2, "mood_mod": 0.1},
	"afternoon": {"start": 12, "end": 17, "energy_mod": 0.0, "mood_mod": 0.0},
	"evening": {"start": 17, "end": 21, "energy_mod": -0.1, "mood_mod": -0.05},
	"night": {"start": 21, "end": 5, "energy_mod": -0.2, "mood_mod": -0.1}
}

var current_period: String = "afternoon"

# Enhanced location effects system with context-aware behaviors
var location_effects: Dictionary = {
	"home": {
		"comfort": 0.02,
		"cleanliness": 0.01,
		"energy": 0.01,
		"security": 0.05,
		"social_fatigue": -0.02
	},
	"workplace": {
		"achievement_need": 0.01,
		"energy": -0.005,
		"social_need": 0.005,
		"wealth_satisfaction": 0.002
	},
	"outdoors": {
		"temp_comfort": 0.0,  # Will be modified by weather
		"cleanliness": -0.002,
		"curiosity": 0.003,
		"energy": -0.001
	},
	"kitchen": {
		"hunger": -0.01,
		"thirst": -0.01,
		"comfort": 0.01
	},
	"bedroom": {
		"energy": 0.02,
		"comfort": 0.03,
		"sleep_quality": 0.05
	},
	"workshop": {
		"achievement_need": 0.015,
		"energy": -0.008,
		"curiosity": 0.002
	},
	"fishing_docks": {
		"achievement_need": 0.01,
		"curiosity": 0.005,
		"temp_comfort": -0.001  # Near water
	},
	"whispering_woods": {
		"curiosity": 0.008,
		"comfort": -0.001,
		"temp_comfort": -0.002  # Shaded
	},
	"stone_circle": {
		"curiosity": 0.01,
		"comfort": 0.02,
		"spirituality": 0.005
	},
	"lighthouse": {
		"achievement_need": 0.012,
		"curiosity": 0.006,
		"temp_comfort": -0.003  # Exposed
	}
}

# Context-aware need interaction modifiers
var need_interaction_modifiers: Dictionary = {
	"kitchen": {
		"hunger_thirst": 0.8,  # Hunger and thirst interact more strongly
		"comfort_energy": 1.2   # Comfort and energy boost each other
	},
	"bedroom": {
		"energy_sleep_quality": 1.5,  # Energy and sleep quality strongly linked
		"comfort_energy": 1.3          # Comfort enhances energy recovery
	},
	"workshop": {
		"achievement_need_energy": 0.7,  # Achievement need drains energy faster
		"curiosity_energy": 1.1          # Curiosity slightly boosts energy
	},
	"outdoors": {
		"temp_comfort_energy": 0.6,     # Temperature discomfort drains energy
		"curiosity_energy": 1.2,        # Curiosity boosts energy outdoors
		"cleanliness_comfort": 0.8      # Dirt reduces comfort more outdoors
	}
}

# Resource availability system
var resource_availability: Dictionary = {
	"kitchen": ["food", "water", "cooking_tools"],
	"workshop": ["materials", "tools", "workbench"],
	"outdoors": ["natural_resources", "space", "fresh_air"],
	"fishing_docks": ["fishing_gear", "boat_access", "fish"],
	"whispering_woods": ["herbs", "wood", "wildlife"],
	"farm": ["crops", "soil", "farming_tools"],
	"trade_post": ["goods", "money", "social_contact"],
	"inn_common_room": ["social_contact", "entertainment", "comfort"]
}

# Enhanced seasonal effects with action availability
var current_season: String = "summer"
var seasons: Dictionary = {
	"spring": {
		"temperature_mod": -5.0, 
		"growth_mod": 0.2, 
		"mood_mod": 0.1,
		"action_modifiers": {
			"farming": 1.3,      # Better farming in spring
			"outdoor_activities": 1.2,  # Pleasant outdoor conditions
			"fishing": 1.1,      # Fish are more active
			"indoor_crafts": 0.9  # Less time spent indoors
		}
	},
	"summer": {
		"temperature_mod": 5.0, 
		"growth_mod": 0.0, 
		"mood_mod": 0.0,
		"action_modifiers": {
			"outdoor_activities": 1.0,  # Normal outdoor conditions
			"fishing": 1.0,      # Normal fishing
			"indoor_crafts": 1.0, # Normal indoor activities
			"farming": 1.0       # Normal farming
		}
	},
	"autumn": {
		"temperature_mod": -2.0, 
		"growth_mod": -0.1, 
		"mood_mod": -0.05,
		"action_modifiers": {
			"harvesting": 1.4,   # Harvest season
			"indoor_crafts": 1.2, # More time indoors
			"outdoor_activities": 0.8, # Cooler weather
			"fishing": 0.9       # Fish less active
		}
	},
	"winter": {
		"temperature_mod": -10.0, 
		"growth_mod": -0.3, 
		"mood_mod": -0.1,
		"action_modifiers": {
			"indoor_crafts": 1.3, # Much more time indoors
			"outdoor_activities": 0.5, # Harsh outdoor conditions
			"fishing": 0.6,      # Ice fishing only
			"farming": 0.3       # Minimal farming
		}
	}
}

# Context-aware behavior triggers
var behavior_triggers: Dictionary = {
	"weather": {
		"rain": {
			"indoor_preference": 1.5,    # Prefer indoor activities
			"movement_speed": 0.7,       # Move slower in rain
			"social_need": 0.8           # Less social in bad weather
		},
		"storm": {
			"indoor_preference": 2.0,    # Strongly prefer indoor activities
			"movement_speed": 0.5,       # Move much slower
			"security_need": 1.3         # Feel less secure
		},
		"sunny": {
			"outdoor_preference": 1.4,   # Prefer outdoor activities
			"energy": 1.2,               # More energetic
			"social_need": 1.1           # More social in good weather
		}
	},
	"time": {
		"dawn": {
			"energy": 0.8,               # Lower energy at dawn
			"indoor_preference": 1.2,    # Prefer indoor activities
			"social_need": 0.7           # Less social early
		},
		"night": {
			"energy": 0.6,               # Much lower energy at night
			"indoor_preference": 2.0,    # Strongly prefer indoor activities
			"security_need": 1.2         # Feel less secure at night
		}
	},
	"location": {
		"workshop": {
			"achievement_focus": 1.3,    # More focused on achievement
			"social_need": 0.8,          # Less social in workshop
			"energy_efficiency": 1.2     # More efficient energy use
		},
		"outdoors": {
			"curiosity": 1.4,            # More curious outdoors
			"energy_drain": 1.1,         # Energy drains faster
			"comfort_sensitivity": 1.3   # More sensitive to comfort
		}
	}
}

# Update intervals
var update_interval: float = 1.0  # Update every second
var last_update_time: float = 0.0

# Integration with other systems
var status_component: StatusComponent = null
var character_manager: CharacterManager = null

# Context tracking for behavior analysis
var context_history: Array = []
var max_context_history: int = 100
var behavior_patterns: Dictionary = {}

func _ready():
	if character_id.is_empty():
		character_id = get_parent().name if get_parent() else "unknown"
	
	# Get current time
	_update_time()
	
	# Initialize weather
	_initialize_weather()
	
	print("[EnvironmentalSensor] Initialized for character: ", character_id)

func _process(delta: float):
	var current_time = _get_current_time_seconds()
	if current_time - last_update_time >= update_interval:
		_update_environment(delta)
		last_update_time = current_time

func _update_environment(delta: float):
	# Update time-based effects
	_update_time()
	
	# Update weather (simplified - could be more complex)
	_update_weather(delta)
	
	# Apply environmental modifiers to character needs
	if status_component:
		_apply_environmental_modifiers(delta)
	
	# Update context history
	_update_context_history()
	
	# Check for behavior triggers
	_check_behavior_triggers()

func _update_time():
	current_time = Time.get_time_dict_from_system()
	var hour = current_time.hour
	
	# Determine current time period
	var new_period = "afternoon"  # Default
	for period in time_periods.keys():
		var period_data = time_periods[period]
		var start_hour = period_data.start
		var end_hour = period_data.end
		
		if start_hour <= end_hour:
			# Normal period (e.g., 7-12)
			if hour >= start_hour and hour < end_hour:
				new_period = period
				break
		else:
			# Wrapping period (e.g., 21-5)
			if hour >= start_hour or hour < end_hour:
				new_period = period
				break
	
	# Emit signal if period changed
	if new_period != current_period:
		var old_period = current_period
		current_period = new_period
		time_period_changed.emit(old_period, new_period)

func _update_weather(delta: float):
	# Simple weather simulation - could be much more complex
	var weather_change_chance = 0.001 * delta  # 0.1% chance per second
	
	if randf() < weather_change_chance:
		var weather_types = weather_patterns.keys()
		var new_weather_type = weather_types[randi() % weather_types.size()]
		
		if new_weather_type != current_weather.type:
			var old_weather = current_weather.duplicate()
			current_weather.type = new_weather_type
			
			# Adjust weather parameters based on type
			var pattern = weather_patterns[new_weather_type]
			current_weather.temperature += pattern.temperature_mod
			current_weather.temperature = clamp(current_weather.temperature, -10.0, 40.0)
			
			# Emit weather change signal
			weather_changed.emit(old_weather, current_weather.duplicate())

func _initialize_weather():
	# Set initial weather based on season
	var season_data = seasons.get(current_season, {})
	current_weather.temperature = 20.0 + season_data.get("temperature_mod", 0.0)
	
	# Randomize initial weather type
	var weather_types = weather_patterns.keys()
	current_weather.type = weather_types[randi() % weather_types.size()]

func set_location(new_location: String):
	if new_location != current_location:
		previous_location = current_location
		current_location = new_location
		
		# Emit location change signal
		location_changed.emit(character_id, previous_location, current_location)
		
		# Check for resource availability changes
		_check_resource_availability()
		
		# Check for location-specific behavior triggers
		_check_location_behavior_triggers()

func _check_resource_availability():
	var available_resources = resource_availability.get(current_location, [])
	resource_availability_changed.emit(current_location, available_resources)

func _check_location_behavior_triggers():
	var location_triggers = behavior_triggers.get("location", {}).get(current_location, {})
	
	for behavior_type in location_triggers.keys():
		var modifier = location_triggers[behavior_type]
		context_behavior_triggered.emit(character_id, behavior_type, {
			"location": current_location,
			"modifier": modifier,
			"type": "location"
		})

func _check_behavior_triggers():
	# Check weather-based triggers
	var weather_triggers = behavior_triggers.get("weather", {}).get(current_weather.type, {})
	for behavior_type in weather_triggers.keys():
		var modifier = weather_triggers[behavior_type]
		context_behavior_triggered.emit(character_id, behavior_type, {
			"weather": current_weather.type,
			"modifier": modifier,
			"type": "weather"
		})
	
	# Check time-based triggers
	var time_triggers = behavior_triggers.get("time", {}).get(current_period, {})
	for behavior_type in time_triggers.keys():
		var modifier = time_triggers[behavior_type]
		context_behavior_triggered.emit(character_id, behavior_type, {
			"time_period": current_period,
			"modifier": modifier,
			"type": "time"
		})

func _update_context_history():
	var context_snapshot = {
		"timestamp": _get_current_time_seconds(),
		"location": current_location,
		"weather": current_weather.type,
		"time_period": current_period,
		"season": current_season,
		"temperature": current_weather.temperature
	}
	
	context_history.append(context_snapshot)
	
	# Keep history within limits
	if context_history.size() > max_context_history:
		context_history.pop_front()
	
	# Analyze patterns (simplified)
	_analyze_behavior_patterns()

func _analyze_behavior_patterns():
	# Simple pattern analysis - could be much more sophisticated
	var recent_contexts = context_history.slice(-10)  # Last 10 contexts
	
	# Count location preferences
	var location_counts = {}
	for context in recent_contexts:
		var loc = context.location
		location_counts[loc] = location_counts.get(loc, 0) + 1
	
	# Update behavior patterns
	behavior_patterns["location_preference"] = location_counts
	
	# Weather tolerance analysis
	var weather_counts = {}
	for context in recent_contexts:
		var weather = context.weather
		weather_counts[weather] = weather_counts.get(weather, 0) + 1
	
	behavior_patterns["weather_tolerance"] = weather_counts

func _apply_environmental_modifiers(delta: float):
	if not status_component:
		return
	
	# Get location effects
	var location_data = location_effects.get(current_location, {})
	
	# Apply each modifier with context-aware interactions
	for need_type in location_data.keys():
		var base_modifier = location_data[need_type] * delta
		var final_modifier = _apply_context_modifiers(need_type, base_modifier, delta)
		
		# Apply the modifier through StatusComponent
		status_component.modify_need(need_type, final_modifier)
		
		# Emit signal for debugging
		environmental_modifier_applied.emit(character_id, need_type, final_modifier, "location: " + current_location)
	
	# Apply weather effects
	_apply_weather_modifiers(delta)
	
	# Apply time period effects
	_apply_time_modifiers(delta)
	
	# Apply seasonal effects
	_apply_seasonal_modifiers(delta)

func _apply_context_modifiers(need_type: String, base_modifier: float, delta: float) -> float:
	var final_modifier = base_modifier
	
	# Get need interaction modifiers for current location
	var interaction_data = need_interaction_modifiers.get(current_location, {})
	
	# Apply interaction effects between related needs
	for interaction_key in interaction_data.keys():
		var needs = interaction_key.split("_")
		if need_type in needs:
			var modifier = interaction_data[interaction_key]
			final_modifier *= modifier
	
	# Apply seasonal context modifiers
	var season_data = seasons.get(current_season, {})
	var action_modifiers = season_data.get("action_modifiers", {})
	
	# Check if current location suggests certain activities
	var location_tags = get_location_tags()
	if "outdoors" in location_tags:
		var outdoor_modifier = action_modifiers.get("outdoor_activities", 1.0)
		final_modifier *= outdoor_modifier
	elif "workshop" in location_tags:
		var workshop_modifier = action_modifiers.get("indoor_crafts", 1.0)
		final_modifier *= workshop_modifier
	
	return final_modifier

func _apply_weather_modifiers(delta: float):
	var weather_type = current_weather.type
	var pattern = weather_patterns.get(weather_type, {})
	
	# Temperature effects
	var temp_modifier = (current_weather.temperature - 20.0) * 0.01 * delta
	status_component.modify_need("temp_comfort", temp_modifier)
	
	# Weather-specific effects
	match weather_type:
		"rain", "storm":
			# Rain reduces cleanliness and comfort
			status_component.modify_need("cleanliness", -0.005 * delta)
			status_component.modify_need("comfort", -0.003 * delta)
			status_component.modify_need("temp_comfort", -0.002 * delta)
		"sunny":
			# Sun increases energy but can cause discomfort
			status_component.modify_need("energy", 0.002 * delta)
			if current_weather.temperature > 25.0:
				status_component.modify_need("temp_comfort", 0.003 * delta)
		"fog":
			# Fog reduces visibility and comfort
			status_component.modify_need("comfort", -0.002 * delta)
			status_component.modify_need("security_need", 0.001 * delta)

func _apply_time_modifiers(delta: float):
	var period_data = time_periods.get(current_period, {})
	
	# Energy effects based on time
	var energy_mod = period_data.get("energy_mod", 0.0)
	if energy_mod != 0.0:
		status_component.modify_need("energy", energy_mod * delta)
	
	# Mood effects (could affect social needs)
	var mood_mod = period_data.get("mood_mod", 0.0)
	if mood_mod != 0.0:
		# Apply to social needs
		status_component.modify_need("social_need", mood_mod * delta)

func _apply_seasonal_modifiers(delta: float):
	var season_data = seasons.get(current_season, {})
	
	# Temperature effects
	var temp_mod = season_data.get("temperature_mod", 0.0)
	if temp_mod != 0.0:
		var temp_effect = temp_mod * 0.001 * delta
		status_component.modify_need("temp_comfort", temp_effect)
	
	# Growth effects (affect achievement and curiosity)
	var growth_mod = season_data.get("growth_mod", 0.0)
	if growth_mod != 0.0:
		status_component.modify_need("achievement_need", growth_mod * 0.001 * delta)
		status_component.modify_need("curiosity", growth_mod * 0.001 * delta)
	
	# Mood effects
	var mood_mod = season_data.get("mood_mod", 0.0)
	if mood_mod != 0.0:
		status_component.modify_need("social_need", mood_mod * 0.001 * delta)

# Enhanced public API functions for context system
func get_location_effects() -> Dictionary:
	return location_effects.get(current_location, {})

func get_weather_info() -> Dictionary:
	return current_weather.duplicate()

func get_time_period() -> String:
	return current_period

func get_season() -> String:
	return current_season

func get_available_resources() -> Array:
	return resource_availability.get(current_location, [])

func get_context_score_for_action(action_id: String) -> float:
	"""Calculate how suitable the current context is for an action"""
	var base_score = 1.0
	
	# Weather effects
	var weather_type = current_weather.type
	match weather_type:
		"rain", "storm":
			if "outdoors" in get_location_tags():
				base_score *= 0.5  # Outdoor actions less suitable in bad weather
		"sunny":
			if "outdoors" in get_location_tags():
				base_score *= 1.2  # Outdoor actions more suitable in good weather
	
	# Time effects
	var hour = current_time.hour
	if hour < 6 or hour > 22:
		if "outdoors" in get_location_tags():
			base_score *= 0.7  # Night reduces outdoor action suitability
	
	# Seasonal effects
	var season_data = seasons.get(current_season, {})
	var action_modifiers = season_data.get("action_modifiers", {})
	
	# Check if action has seasonal modifiers
	for action_type in action_modifiers.keys():
		if action_id.contains(action_type) or action_id.contains(action_type.replace("_", "")):
			base_score *= action_modifiers[action_type]
			seasonal_action_modifier.emit(current_season, action_id, action_modifiers[action_type])
	
	# Location-specific effects
	var location_tags = get_location_tags()
	if "indoor" in location_tags and "outdoor" in action_id:
		base_score *= 0.6  # Indoor location for outdoor action
	elif "outdoors" in location_tags and "indoor" in action_id:
		base_score *= 0.8  # Outdoor location for indoor action
	
	return base_score

func get_behavior_patterns() -> Dictionary:
	"""Get analyzed behavior patterns for this character"""
	return behavior_patterns.duplicate()

func get_context_summary() -> Dictionary:
	"""Get comprehensive context summary for decision making"""
	return {
		"location": current_location,
		"weather": current_weather.type,
		"time_period": current_period,
		"season": current_season,
		"temperature": current_weather.temperature,
		"location_effects": get_location_effects(),
		"available_resources": get_available_resources(),
		"behavior_patterns": get_behavior_patterns(),
		"context_score": get_context_score_for_action("general")
	}

func is_location_suitable_for_action(action_id: String) -> bool:
	# Enhanced location suitability check
	var context_score = get_context_score_for_action(action_id)
	return context_score > 0.5  # Action is suitable if context score > 50%

func get_location_tags() -> Array:
	# Return location tags for the current location
	# This would integrate with the action system's location_types
	var tags = []
	
	# Basic location categorization
	if current_location in ["home", "bedroom", "kitchen", "bathroom"]:
		tags.append("indoor")
		tags.append("comfortable")
		tags.append("safe")
	
	if current_location in ["workshop", "blacksmith", "carpentry_workshop"]:
		tags.append("indoor")
		tags.append("crafting")
		tags.append("materials")
	
	if current_location in ["outdoors", "fishing_docks", "whispering_woods"]:
		tags.append("outdoors")
		tags.append("nature")
	
	return tags

# Enhanced console commands for context system debugging
func console_command(command: String, args: Array) -> Dictionary:
	match command:
		"weather":
			return {"success": true, "data": get_weather_info()}
		"time":
			return {"success": true, "data": {"period": current_period, "hour": current_time.hour}}
		"location":
			return {"success": true, "data": {"current": current_location, "effects": get_location_effects()}}
		"season":
			return {"success": true, "data": {"current": current_season, "effects": seasons.get(current_season, {})}}
		"resources":
			return {"success": true, "data": {"location": current_location, "resources": get_available_resources()}}
		"context":
			return {"success": true, "data": get_context_summary()}
		"patterns":
			return {"success": true, "data": get_behavior_patterns()}
		"action_score":
			if args.size() >= 1:
				var action_id = args[0]
				var score = get_context_score_for_action(action_id)
				return {"success": true, "data": {"action": action_id, "context_score": score}}
			else:
				return {"success": false, "error": "Usage: action_score <action_id>"}
		"set_weather":
			if args.size() >= 1:
				var new_type = args[0]
				if weather_patterns.has(new_type):
					var old_weather = current_weather.duplicate()
					current_weather.type = new_type
					weather_changed.emit(old_weather, current_weather.duplicate())
					return {"success": true, "message": "Weather changed to " + new_type}
				else:
					return {"success": false, "error": "Invalid weather type: " + new_type}
			else:
				return {"success": false, "error": "Usage: set_weather <type>"}
		"set_location":
			if args.size() >= 1:
				set_location(args[0])
				return {"success": true, "message": "Location changed to " + args[0]}
			else:
				return {"success": false, "error": "Usage: set_location <location>"}
		"set_season":
			if args.size() >= 1:
				var new_season = args[0]
				if seasons.has(new_season):
					current_season = new_season
					_initialize_weather()
					return {"success": true, "message": "Season changed to " + new_season}
				else:
					return {"success": false, "error": "Invalid season: " + new_season}
			else:
				return {"success": false, "error": "Usage: set_season <season>"}
		_:
			return {"success": false, "error": "Unknown command: " + command}

# Integration functions
func set_status_component(component: StatusComponent):
	status_component = component

func set_character_manager(manager: CharacterManager):
	character_manager = manager


# Helper function to get current time in seconds
func _get_current_time_seconds() -> float:
	var time_dict = Time.get_time_dict_from_system()
	return time_dict.hour * 3600 + time_dict.minute * 60 + time_dict.second
