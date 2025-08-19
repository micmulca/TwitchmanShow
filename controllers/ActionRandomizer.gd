extends Node
class_name ActionRandomizer

# Action Randomizer - Generates varied action results based on character traits,
# environmental factors, and random chance. Creates memories from action outcomes.
# Integrates with ActionExecutor, MemoryComponent, and EnvironmentalSensor

signal action_result_generated(action_id: String, character_id: String, result: Dictionary)
signal exceptional_result_achieved(action_id: String, character_id: String, result: Dictionary)
signal critical_failure_occurred(action_id: String, character_id: String, result: Dictionary)

# Result types and quality levels
enum ResultType {
	EXCELLENT,  # Exceptional success with bonuses
	GOOD,       # Above average success
	AVERAGE,    # Standard success
	POOR,       # Below average success
	FAILURE     # Complete failure
}

enum QualityLevel {
	MASTERPIECE,    # Exceptional quality
	HIGH_QUALITY,   # Above average quality
	STANDARD,       # Normal quality
	FLAWED,         # Below average quality
	BROKEN          # Poor quality
}

# Character trait influence weights
var trait_weights: Dictionary = {
	"conscientiousness": 0.3,  # Affects work quality and reliability
	"openness": 0.2,           # Affects creativity and innovation
	"extraversion": 0.15,      # Affects social actions and teamwork
	"agreeableness": 0.15,     # Affects cooperation and relationship building
	"neuroticism": -0.2,       # Negative impact on stress-prone actions
	"work_ethic": 0.25,        # Custom trait for work-related actions
	"creativity": 0.2,         # Custom trait for artistic actions
	"patience": 0.15,          # Custom trait for long-term actions
	"risk_tolerance": 0.1      # Custom trait for risky actions
}

# Environmental modifier weights
var environmental_weights: Dictionary = {
	"weather": 0.3,      # Weather conditions
	"season": 0.2,       # Seasonal effects
	"time": 0.1,         # Time of day
	"location": 0.15,    # Location-specific bonuses
	"crowding": 0.1,     # Number of people in area
	"resources": 0.15    # Resource availability
}

# Luck factor ranges
var luck_ranges: Dictionary = {
	ResultType.EXCELLENT: [-0.1, 0.2],   # Excellent results need good luck
	ResultType.GOOD: [-0.15, 0.15],      # Good results with moderate luck
	ResultType.AVERAGE: [-0.2, 0.2],     # Average results with wide luck range
	ResultType.POOR: [-0.2, 0.1],        # Poor results with bad luck
	ResultType.FAILURE: [-0.3, 0.0]      # Failures with very bad luck
}

# Dependencies
var character_manager: CharacterManager
var environmental_sensor: EnvironmentalSensor
var memory_component: MemoryComponent

func _ready():
	# Get dependencies
	character_manager = get_parent().get_node_or_null("CharacterManager")
	environmental_sensor = get_parent().get_node_or_null("EnvironmentalSensor")

func initialize(memory_comp: MemoryComponent):
	memory_component = memory_comp
	print("✅ ActionRandomizer initialized")

# Main Result Generation

func generate_action_result(action_data: Dictionary, character_id: String, participants: Array = []) -> Dictionary:
	"""Generate a randomized result for an action based on character traits and environment"""
	
	# Get character data
	var character_data = character_manager.get_character_data(character_id) if character_manager else {}
	if character_data.is_empty():
		return _generate_default_result(action_data)
	
	# Calculate base success probability
	var base_success = action_data.get("base_score", 80) / 100.0
	
	# Apply character trait modifiers
	var character_modifier = _calculate_character_modifier(character_data, action_data)
	
	# Apply environmental modifiers
	var environmental_modifier = _calculate_environmental_modifier(action_data)
	
	# Calculate final success probability
	var final_success = base_success + character_modifier + environmental_modifier
	final_success = clamp(final_success, 0.0, 1.0)
	
	# Determine result type based on success probability
	var result_type = _determine_result_type(final_success)
	
	# Generate result details
	var result = _generate_result_details(action_data, result_type, character_data)
	
	# Add metadata
	result["action_id"] = action_data.get("id", "")
	result["character_id"] = character_id
	result["participants"] = participants
	result["timestamp"] = Time.get_time_dict_from_system()["unix"]
	result["success_probability"] = final_success
	result["character_modifier"] = character_modifier
	result["environmental_modifier"] = environmental_modifier
	
	# Create memory from result
	if memory_component:
		memory_component.create_action_memory(action_data, result, participants)
	
	# Emit signals for exceptional results
	if result_type == ResultType.EXCELLENT:
		exceptional_result_achieved.emit(action_data.get("id", ""), character_id, result)
	elif result_type == ResultType.FAILURE:
		critical_failure_occurred.emit(action_data.get("id", ""), character_id, result)
	
	action_result_generated.emit(action_data.get("id", ""), character_id, result)
	
	return result

# Character Trait Calculations

func _calculate_character_modifier(character_data: Dictionary, action_data: Dictionary) -> float:
	"""Calculate how character traits affect action success"""
	var modifier = 0.0
	var personality = character_data.get("personality", {})
	var big_five = personality.get("big_five", {})
	var custom_traits = personality.get("traits", {})
	
	# Apply Big Five personality traits
	for trait in big_five:
		if trait in trait_weights:
			var trait_value = big_five[trait]
			var weight = trait_weights[trait]
			modifier += (trait_value - 0.5) * weight * 2.0  # Center around 0.5
	
	# Apply custom traits
	for trait in custom_traits:
		if trait in trait_weights:
			var trait_value = custom_traits[trait]
			var weight = trait_weights[trait]
			modifier += (trait_value - 0.5) * weight * 2.0
	
	# Apply action-specific trait bonuses
	modifier += _calculate_action_specific_traits(character_data, action_data)
	
	return clamp(modifier, -0.3, 0.3)

func _calculate_action_specific_traits(character_data: Dictionary, action_data: Dictionary) -> float:
	"""Calculate trait bonuses specific to certain action types"""
	var modifier = 0.0
	var skills = character_data.get("skills", {})
	var action_category = action_data.get("category", "")
	var action_id = action_data.get("id", "")
	
	# Crafting actions benefit from creativity and patience
	if action_category == "Crafting" or action_id in ["make_pottery", "weave_cloth", "build_boat"]:
		var creativity = character_data.get("personality", {}).get("traits", {}).get("creativity", 0.5)
		var patience = character_data.get("personality", {}).get("traits", {}).get("patience", 0.5)
		modifier += (creativity - 0.5) * 0.15
		modifier += (patience - 0.5) * 0.1
	
	# Social actions benefit from extraversion and agreeableness
	elif action_category == "Social" or action_id in ["socialize", "cook_for_guests", "serve_guests"]:
		var extraversion = character_data.get("personality", {}).get("big_five", {}).get("extraversion", 0.5)
		var agreeableness = character_data.get("personality", {}).get("big_five", {}).get("agreeableness", 0.5)
		modifier += (extraversion - 0.5) * 0.2
		modifier += (agreeableness - 0.5) * 0.15
	
	# Work actions benefit from conscientiousness and work ethic
	elif action_category == "Economic" or action_id in ["work_job", "farm_work", "blacksmith_work"]:
		var conscientiousness = character_data.get("personality", {}).get("big_five", {}).get("conscientiousness", 0.5)
		var work_ethic = character_data.get("personality", {}).get("traits", {}).get("work_ethic", 0.5)
		modifier += (conscientiousness - 0.5) * 0.2
		modifier += (work_ethic - 0.5) * 0.15
	
	# Exploration actions benefit from openness and curiosity
	elif action_id in ["explore_island", "visit_stone_circle", "gather_herbs"]:
		var openness = character_data.get("personality", {}).get("big_five", {}).get("openness", 0.5)
		modifier += (openness - 0.5) * 0.2
	
	return modifier

# Environmental Modifier Calculations

func _calculate_environmental_modifier(action_data: Dictionary) -> float:
	"""Calculate how environmental factors affect action success"""
	if not environmental_sensor:
		return 0.0
	
	var modifier = 0.0
	var location_tags = action_data.get("location_tags", [])
	var action_category = action_data.get("category", "")
	
	# Weather effects
	var weather = environmental_sensor.get_current_weather()
	modifier += _calculate_weather_modifier(weather, action_category, location_tags)
	
	# Seasonal effects
	var season = environmental_sensor.get_current_season()
	modifier += _calculate_seasonal_modifier(season, action_category)
	
	# Time of day effects
	var time_period = environmental_sensor.get_current_time_period()
	modifier += _calculate_time_modifier(time_period, action_category)
	
	# Location-specific effects
	modifier += _calculate_location_modifier(location_tags, action_category)
	
	return clamp(modifier, -0.4, 0.4)

func _calculate_weather_modifier(weather: String, action_category: String, location_tags: Array) -> float:
	"""Calculate weather impact on actions"""
	var modifier = 0.0
	
	match weather:
		"clear":
			if "outdoors" in location_tags:
				modifier += 0.1
		"sunny":
			if "outdoors" in location_tags:
				modifier += 0.15
			elif action_category == "Physical":
				modifier += 0.05
		"rain":
			if "outdoors" in location_tags:
				modifier -= 0.2
			elif "indoor" in location_tags:
				modifier += 0.05  # Prefer indoor activities
		"storm":
			if "outdoors" in location_tags:
				modifier -= 0.3
			elif "indoor" in location_tags:
				modifier += 0.1
		"fog":
			if "outdoors" in location_tags:
				modifier -= 0.15
		"windy":
			if "outdoors" in location_tags:
				modifier -= 0.1
	
	return modifier

func _calculate_seasonal_modifier(season: String, action_category: String) -> float:
	"""Calculate seasonal impact on actions"""
	var modifier = 0.0
	
	match season:
		"spring":
			if action_category == "Economic" or action_category == "Physical":
				modifier += 0.2  # Farming and outdoor work
		"summer":
			if action_category == "Physical":
				modifier += 0.1  # Good weather for outdoor activities
		"autumn":
			if action_category == "Economic":
				modifier += 0.15  # Harvest season
		"winter":
			if "outdoors" in action_category:
				modifier -= 0.2  # Cold weather hinders outdoor work
			elif action_category == "Crafting":
				modifier += 0.1  # More time for indoor crafts
	
	return modifier

func _calculate_time_modifier(time_period: String, action_category: String) -> float:
	"""Calculate time of day impact on actions"""
	var modifier = 0.0
	
	match time_period:
		"dawn":
			if action_category == "Physical":
				modifier += 0.1  # Fresh start
		"morning":
			if action_category == "Economic" or action_category == "Physical":
				modifier += 0.15  # Peak productivity
		"afternoon":
			if action_category == "Economic":
				modifier += 0.05  # Steady work
		"evening":
			if action_category == "Social":
				modifier += 0.1  # Social time
		"night":
			if action_category == "Physical":
				modifier -= 0.2  # Tired
			elif action_category == "Social":
				modifier -= 0.1  # Less social at night
	
	return modifier

func _calculate_location_modifier(location_tags: Array, action_category: String) -> float:
	"""Calculate location-specific bonuses"""
	var modifier = 0.0
	
	# Workshop locations boost crafting
	if "workshop" in location_tags and action_category == "Crafting":
		modifier += 0.1
	
	# Kitchen locations boost cooking
	if "kitchen" in location_tags and action_category == "Physical":
		modifier += 0.05
	
	# Outdoor locations boost exploration
	if "outdoors" in location_tags and action_category == "Activity":
		modifier += 0.05
	
	# Specialized locations
	if "blacksmith" in location_tags and action_category == "Crafting":
		modifier += 0.1
	elif "fishing_docks" in location_tags and action_category == "Economic":
		modifier += 0.1
	elif "whispering_woods" in location_tags and action_category == "Activity":
		modifier += 0.1
	
	return modifier

# Result Type Determination

func _determine_result_type(success_probability: float) -> ResultType:
	"""Determine result type based on success probability and random chance"""
	var random_value = randf()
	var adjusted_probability = success_probability + (random_value - 0.5) * 0.2
	
	if adjusted_probability >= 0.9:
		return ResultType.EXCELLENT
	elif adjusted_probability >= 0.75:
		return ResultType.GOOD
	elif adjusted_probability >= 0.4:
		return ResultType.AVERAGE
	elif adjusted_probability >= 0.2:
		return ResultType.POOR
	else:
		return ResultType.FAILURE

# Result Detail Generation

func _generate_result_details(action_data: Dictionary, result_type: ResultType, character_data: Dictionary) -> Dictionary:
	"""Generate detailed result information based on result type"""
	var result = {
		"result_type": ResultType.keys()[result_type].to_lower(),
		"quality": _determine_quality_level(result_type, character_data),
		"duration_modifier": _calculate_duration_modifier(result_type),
		"resource_efficiency": _calculate_resource_efficiency(result_type),
		"special_events": _generate_special_events(action_data, result_type),
		"need_satisfaction_modifier": _calculate_need_satisfaction_modifier(result_type),
		"skill_gain_modifier": _calculate_skill_gain_modifier(result_type),
		"wealth_change": _calculate_wealth_change(action_data, result_type, character_data)
	}
	
	# Add action-specific details
	result.merge(_generate_action_specific_details(action_data, result_type))
	
	return result

func _determine_quality_level(result_type: ResultType, character_data: Dictionary) -> String:
	"""Determine the quality of the result"""
	var quality_chances = {
		ResultType.EXCELLENT: {"masterpiece": 0.4, "high_quality": 0.4, "standard": 0.2},
		ResultType.GOOD: {"high_quality": 0.5, "standard": 0.4, "flawed": 0.1},
		ResultType.AVERAGE: {"standard": 0.7, "flawed": 0.2, "high_quality": 0.1},
		ResultType.POOR: {"flawed": 0.6, "standard": 0.3, "broken": 0.1},
		ResultType.FAILURE: {"broken": 0.7, "flawed": 0.3}
	}
	
	var chances = quality_chances[result_type]
	var random_value = randf()
	var cumulative = 0.0
	
	for quality in chances:
		cumulative += chances[quality]
		if random_value <= cumulative:
			return quality
	
	return "standard"

func _calculate_duration_modifier(result_type: ResultType) -> float:
	"""Calculate how result affects action duration"""
	match result_type:
		ResultType.EXCELLENT:
			return 0.8  # 20% faster
		ResultType.GOOD:
			return 0.9  # 10% faster
		ResultType.AVERAGE:
			return 1.0  # Normal duration
		ResultType.POOR:
			return 1.2  # 20% slower
		ResultType.FAILURE:
			return 1.5  # 50% slower
		_:
			return 1.0

func _calculate_resource_efficiency(result_type: ResultType) -> float:
	"""Calculate resource efficiency of the result"""
	match result_type:
		ResultType.EXCELLENT:
			return 1.3  # 30% more efficient
		ResultType.GOOD:
			return 1.15  # 15% more efficient
		ResultType.AVERAGE:
			return 1.0  # Normal efficiency
		ResultType.POOR:
			return 0.85  # 15% less efficient
		ResultType.FAILURE:
			return 0.6  # 40% less efficient
		_:
			return 1.0

func _generate_special_events(action_data: Dictionary, result_type: ResultType) -> Array:
	"""Generate special events based on action and result"""
	var events = []
	var action_id = action_data.get("id", "")
	
	# Fishing special events
	if action_id == "go_fishing":
		if result_type == ResultType.EXCELLENT:
			events.append("caught_rare_fish")
			events.append("perfect_weather_conditions")
		elif result_type == ResultType.FAILURE:
			events.append("line_broke")
			events.append("bad_weather")
	
	# Crafting special events
	elif action_id in ["make_pottery", "weave_cloth", "build_boat"]:
		if result_type == ResultType.EXCELLENT:
			events.append("inspiration_struck")
			events.append("perfect_materials")
		elif result_type == ResultType.FAILURE:
			events.append("material_waste")
			events.append("tool_damage")
	
	# Work special events
	elif action_id in ["work_job", "farm_work", "blacksmith_work"]:
		if result_type == ResultType.EXCELLENT:
			events.append("exceptional_productivity")
			events.append("recognition_received")
		elif result_type == ResultType.FAILURE:
			events.append("equipment_malfunction")
			events.append("time_wasted")
	
	return events

func _calculate_need_satisfaction_modifier(result_type: ResultType) -> float:
	"""Calculate how result affects need satisfaction"""
	match result_type:
		ResultType.EXCELLENT:
			return 1.4  # 40% more satisfaction
		ResultType.GOOD:
			return 1.2  # 20% more satisfaction
		ResultType.AVERAGE:
			return 1.0  # Normal satisfaction
		ResultType.POOR:
			return 0.8  # 20% less satisfaction
		ResultType.FAILURE:
			return 0.5  # 50% less satisfaction
		_:
			return 1.0

func _calculate_skill_gain_modifier(result_type: ResultType) -> float:
	"""Calculate how result affects skill gains"""
	match result_type:
		ResultType.EXCELLENT:
			return 1.5  # 50% more skill gain
		ResultType.GOOD:
			return 1.25  # 25% more skill gain
		ResultType.AVERAGE:
			return 1.0  # Normal skill gain
		ResultType.POOR:
			return 0.75  # 25% less skill gain
		ResultType.FAILURE:
			return 0.5  # 50% less skill gain
		_:
			return 1.0

func _calculate_wealth_change(action_data: Dictionary, result_type: ResultType, character_data: Dictionary) -> int:
	"""Calculate wealth change from the action result"""
	var base_wealth = action_data.get("effects", {}).get("income", 0)
	if base_wealth == 0:
		return 0
	
	var wealth_modifier = 1.0
	match result_type:
		ResultType.EXCELLENT:
			wealth_modifier = 1.5
		ResultType.GOOD:
			wealth_modifier = 1.25
		ResultType.AVERAGE:
			wealth_modifier = 1.0
		ResultType.POOR:
			wealth_modifier = 0.75
		ResultType.FAILURE:
			wealth_modifier = 0.0
	
	return int(base_wealth * wealth_modifier)

func _generate_action_specific_details(action_data: Dictionary, result_type: ResultType) -> Dictionary:
	"""Generate details specific to certain action types"""
	var details = {}
	var action_id = action_data.get("id", "")
	
	# Fishing actions
	if action_id == "go_fishing":
		details["catch_count"] = _calculate_fishing_catch_count(result_type)
		details["fish_variety"] = _determine_fish_variety(result_type)
	
	# Crafting actions
	elif action_id in ["make_pottery", "weave_cloth", "build_boat"]:
		details["crafting_quality"] = _determine_crafting_quality(result_type)
		details["material_usage"] = _calculate_material_usage(result_type)
	
	# Work actions
	elif action_id in ["work_job", "farm_work", "blacksmith_work"]:
		details["productivity_level"] = _determine_productivity_level(result_type)
		details["work_efficiency"] = _calculate_work_efficiency(result_type)
	
	return details

# Action-Specific Calculations

func _calculate_fishing_catch_count(result_type: ResultType) -> int:
	"""Calculate number of fish caught based on result"""
	match result_type:
		ResultType.EXCELLENT:
			return randi_range(4, 6)
		ResultType.GOOD:
			return randi_range(3, 4)
		ResultType.AVERAGE:
			return randi_range(2, 3)
		ResultType.POOR:
			return randi_range(1, 2)
		ResultType.FAILURE:
			return 0
		_:
			return 1

func _determine_fish_variety(result_type: ResultType) -> String:
	"""Determine variety of fish caught"""
	var random_value = randf()
	
	if result_type == ResultType.EXCELLENT:
		if random_value < 0.3:
			return "rare_fish"
		else:
			return "common_fish"
	elif result_type == ResultType.GOOD:
		if random_value < 0.1:
			return "rare_fish"
		else:
			return "common_fish"
	else:
		return "common_fish"

func _determine_crafting_quality(result_type: ResultType) -> String:
	"""Determine quality of crafted item"""
	match result_type:
		ResultType.EXCELLENT:
			return "masterpiece"
		ResultType.GOOD:
			return "high_quality"
		ResultType.AVERAGE:
			return "standard"
		ResultType.POOR:
			return "flawed"
		ResultType.FAILURE:
			return "broken"
		_:
			return "standard"

func _calculate_material_usage(result_type: ResultType) -> float:
	"""Calculate material efficiency"""
	match result_type:
		ResultType.EXCELLENT:
			return 0.8  # 20% less materials used
		ResultType.GOOD:
			return 0.9  # 10% less materials used
		ResultType.AVERAGE:
			return 1.0  # Normal material usage
		ResultType.POOR:
			return 1.2  # 20% more materials used
		ResultType.FAILURE:
			return 1.5  # 50% more materials used
		_:
			return 1.0

func _determine_productivity_level(result_type: ResultType) -> String:
	"""Determine productivity level for work actions"""
	match result_type:
		ResultType.EXCELLENT:
			return "exceptional"
		ResultType.GOOD:
			return "above_average"
		ResultType.AVERAGE:
			return "standard"
		ResultType.POOR:
			return "below_average"
		ResultType.FAILURE:
			return "poor"
		_:
			return "standard"

func _calculate_work_efficiency(result_type: ResultType) -> float:
	"""Calculate work efficiency"""
	match result_type:
		ResultType.EXCELLENT:
			return 1.4  # 40% more efficient
		ResultType.GOOD:
			return 1.2  # 20% more efficient
		ResultType.AVERAGE:
			return 1.0  # Normal efficiency
		ResultType.POOR:
			return 0.8  # 20% less efficient
		ResultType.FAILURE:
			return 0.5  # 50% less efficient
		_:
			return 1.0

# Utility Methods

func _generate_default_result(action_data: Dictionary) -> Dictionary:
	"""Generate a default result when character data is unavailable"""
	return {
		"result_type": "average",
		"quality": "standard",
		"duration_modifier": 1.0,
		"resource_efficiency": 1.0,
		"special_events": [],
		"need_satisfaction_modifier": 1.0,
		"skill_gain_modifier": 1.0,
		"wealth_change": action_data.get("effects", {}).get("income", 0),
		"action_id": action_data.get("id", ""),
		"character_id": "",
		"participants": [],
		"timestamp": Time.get_time_dict_from_system()["unix"],
		"success_probability": 0.5,
		"character_modifier": 0.0,
		"environmental_modifier": 0.0
	}

# Console Commands

func console_command(command: String, args: Array) -> Dictionary:
	match command:
		"test":
			if args.size() < 2:
				return {"success": false, "message": "Usage: test <action_id> <character_id>"}
			
			var action_id = args[0]
			var character_id = args[1]
			
			# Get action data from ActionPlanner
			var action_planner = get_parent().get_node_or_null("ActionPlanner")
			if not action_planner:
				return {"success": false, "message": "ActionPlanner not available"}
			
			var action_data = action_planner.get_action_by_id(action_id)
			if action_data.is_empty():
				return {"success": false, "message": "Action not found: " + action_id}
			
			var result = generate_action_result(action_data, character_id)
			return {"success": true, "result": result}
		
		"force_result":
			if args.size() < 3:
				return {"success": false, "message": "Usage: force_result <action_id> <character_id> <result_type>"}
			
			var action_id = args[0]
			var character_id = args[1]
			var result_type_str = args[2].to_upper()
			
			# Validate result type
			if not ResultType.has(result_type_str):
				return {"success": false, "message": "Invalid result type: " + result_type_str}
			
			var result_type = ResultType[result_type_str]
			
			# Get action data
			var action_planner = get_parent().get_node_or_null("ActionPlanner")
			if not action_planner:
				return {"success": false, "message": "ActionPlanner not available"}
			
			var action_data = action_planner.get_action_by_id(action_id)
			if action_data.is_empty():
				return {"success": false, "message": "Action not found: " + action_id}
			
			# Generate forced result
			var result = _generate_result_details(action_data, result_type, {})
			result["action_id"] = action_id
			result["character_id"] = character_id
			result["result_type"] = result_type_str.to_lower()
			result["timestamp"] = Time.get_time_dict_from_system()["unix"]
			
			return {"success": true, "result": result}
		
		"result_stats":
			if args.size() < 1:
				return {"success": false, "message": "Usage: result_stats <action_id>"}
			
			var action_id = args[0]
			
			# Get action data
			var action_planner = get_parent().get_node_or_null("ActionPlanner")
			if not action_planner:
				return {"success": false, "message": "ActionPlanner not available"}
			
			var action_data = action_planner.get_action_by_id(action_id)
			if action_data.is_empty():
				return {"success": false, "message": "Action not found: " + action_id}
			
			# Calculate theoretical result distribution
			var stats = {
				"action_id": action_id,
				"base_success_rate": action_data.get("base_score", 80) / 100.0,
				"result_probabilities": {
					"excellent": 0.1,
					"good": 0.25,
					"average": 0.4,
					"poor": 0.2,
					"failure": 0.05
				},
				"quality_distribution": {
					"masterpiece": 0.05,
					"high_quality": 0.25,
					"standard": 0.5,
					"flawed": 0.15,
					"broken": 0.05
				}
			}
			
			return {"success": true, "stats": stats}
		
		_:
			return {"success": false, "message": "Unknown command: " + command}
