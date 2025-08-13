extends Node
class_name EnvironmentalSensor

# EnvironmentalSensor - Provides environmental context for character behavior
# Integrates with StatusComponent, ActionPlanner, and existing systems

signal location_changed(character_id: String, old_location: String, new_location: String)
signal weather_changed(old_weather: Dictionary, new_weather: Dictionary)
signal time_period_changed(old_period: String, new_period: String)
signal resource_availability_changed(location: String, resources: Array)
signal environmental_modifier_applied(character_id: String, need_type: String, modifier: float, reason: String)

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

# Location effects system
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

# Seasonal effects
var current_season: String = "summer"
var seasons: Dictionary = {
	"spring": {"temperature_mod": -5.0, "growth_mod": 0.2, "mood_mod": 0.1},
	"summer": {"temperature_mod": 5.0, "growth_mod": 0.0, "mood_mod": 0.0},
	"autumn": {"temperature_mod": -2.0, "growth_mod": -0.1, "mood_mod": -0.05},
	"winter": {"temperature_mod": -10.0, "growth_mod": -0.3, "mood_mod": -0.1}
}

# Update intervals
var update_interval: float = 1.0  # Update every second
var last_update_time: float = 0.0

# Integration with other systems
var status_component: StatusComponent = null
var character_manager: CharacterManager = null

func _ready():
	if character_id.is_empty():
		character_id = get_parent().name if get_parent() else "unknown"
	
	# Get current time
	_update_time()
	
	# Initialize weather
	_initialize_weather()
	
	print("[EnvironmentalSensor] Initialized for character: ", character_id)

func _process(delta: float):
	var current_time = Time.get_time()
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

func _check_resource_availability():
	var available_resources = resource_availability.get(current_location, [])
	resource_availability_changed.emit(current_location, available_resources)

func _apply_environmental_modifiers(delta: float):
	if not status_component:
		return
	
	# Get location effects
	var location_data = location_effects.get(current_location, {})
	
	# Apply each modifier
	for need_type in location_data.keys():
		var modifier = location_data[need_type] * delta
		
		# Apply the modifier through StatusComponent
		status_component.modify_need(need_type, modifier)
		
		# Emit signal for debugging
		environmental_modifier_applied.emit(character_id, need_type, modifier, "location: " + current_location)
	
	# Apply weather effects
	_apply_weather_modifiers(delta)
	
	# Apply time period effects
	_apply_time_modifiers(delta)
	
	# Apply seasonal effects
	_apply_seasonal_modifiers(delta)

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

# Public API functions
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

func is_location_suitable_for_action(action_id: String) -> bool:
	# Check if current location supports the action
	# This would integrate with the action system
	return true  # Placeholder

func get_environmental_score_for_action(action_id: String) -> float:
	# Calculate how suitable the current environment is for an action
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
	
	return base_score

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

# Console commands for debugging
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
