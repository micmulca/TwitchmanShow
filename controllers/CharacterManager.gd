extends Node
class_name CharacterManager

## CharacterManager - Central character management system for TwitchMan Autonomous World
## Handles character creation, loading, saving, and lifecycle management
## Integrates with StatusComponent, ActionPlanner, and existing conversation systems

signal character_loaded(character_id: String, character_data: Dictionary)
signal character_saved(character_id: String, character_data: Dictionary)
signal character_created(character_id: String, character_data: Dictionary)
signal character_deleted(character_id: String)
signal population_updated(character_count: int)

# Configuration
const CHARACTER_TEMPLATE_PATH = "res://data/characters/character_template.json"
const CHARACTERS_DIR_PATH = "res://data/characters/"
const SAVE_DIR_PATH = "user://characters/"

# Character registry - active characters in memory
var active_characters: Dictionary = {}
var character_templates: Dictionary = {}
var base_template: Dictionary = {}

# Component references
var status_components: Dictionary = {}
var action_planners: Dictionary = {}
var environmental_sensors: Dictionary = {}

# Population management
var max_population: int = 50
var population_count: int = 0

func _ready():
	# Ensure save directory exists
	DirAccess.make_dir_recursive_absolute(SAVE_DIR_PATH)
	
	# Load base template
	load_base_template()
	
	# Load character templates
	load_character_templates()
	
	# Initialize population from saved characters
	initialize_population()

func load_base_template():
	"""Load the base character template that all characters inherit from"""
	var file = FileAccess.open(CHARACTER_TEMPLATE_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			base_template = json.data
			print("✅ Base character template loaded successfully")
		else:
			push_error("Failed to parse base character template: " + json.get_error_message())
	else:
		push_error("Failed to open base character template: " + CHARACTER_TEMPLATE_PATH)

func load_character_templates():
	"""Load all character templates from the characters directory"""
	var dir = DirAccess.open(CHARACTERS_DIR_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".json") and file_name != "character_template.json":
				var character_id = file_name.get_basename()
				var template_path = CHARACTERS_DIR_PATH + file_name
				
				var file = FileAccess.open(template_path, FileAccess.READ)
				if file:
					var json_string = file.get_as_text()
					file.close()
					
					var json = JSON.new()
					var parse_result = json.parse(json_string)
					
					if parse_result == OK:
						character_templates[character_id] = json.data
						print("✅ Character template loaded: " + character_id)
					else:
						push_error("Failed to parse character template " + character_id + ": " + json.get_error_message())
			
			file_name = dir.get_next()
		
		dir.list_dir_end()
	else:
		push_error("Failed to open characters directory: " + CHARACTERS_DIR_PATH)

func initialize_population():
	"""Initialize the population from saved character data"""
	# Load saved characters first
	load_saved_characters()
	
	# Create any missing characters from templates
	create_missing_characters()
	
	# Update population count
	population_count = active_characters.size()
	population_updated.emit(population_count)
	
	print("✅ Population initialized: " + str(population_count) + " characters")

func load_saved_characters():
	"""Load all saved character data from user directory"""
	var dir = DirAccess.open(SAVE_DIR_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".json"):
				var character_id = file_name.get_basename()
				var save_path = SAVE_DIR_PATH + file_name
				
				var file = FileAccess.open(save_path, FileAccess.READ)
				if file:
					var json_string = file.get_as_text()
					file.close()
					
					var json = JSON.new()
					var parse_result = json.parse(json_string)
					
					if parse_result == OK:
						active_characters[character_id] = json.data
						create_character_components(character_id, json.data)
						print("✅ Saved character loaded: " + character_id)
					else:
						push_error("Failed to parse saved character " + character_id + ": " + json.get_error_message())
			
			file_name = dir.get_next()
		
		dir.list_dir_end()

func create_missing_characters():
	"""Create any characters that exist in templates but not in saved data"""
	for character_id in character_templates:
		if not active_characters.has(character_id):
			create_character_from_template(character_id)

func create_character_from_template(character_id: String) -> Dictionary:
	"""Create a new character from a template"""
	if not character_templates.has(character_id):
		push_error("Character template not found: " + character_id)
		return {}
	
	var template = character_templates[character_id]
	var new_character = base_template.duplicate(true)
	
	# Merge template data
	for key in template:
		if key == "needs":
			# Deep merge needs to preserve base structure
			merge_needs(new_character.needs, template.needs)
		else:
			new_character[key] = template[key]
	
	# Set unique identifier
	new_character.character_id = character_id
	
	# Initialize current timestamp
	new_character.created_at = Time.get_datetime_string_from_system()
	new_character.last_saved = Time.get_datetime_string_from_system()
	
	# Add to active characters
	active_characters[character_id] = new_character
	
	# Create character components
	create_character_components(character_id, new_character)
	
	# Save the new character
	save_character(character_id)
	
	character_created.emit(character_id, new_character)
	print("✅ Character created from template: " + character_id)
	
	return new_character

func merge_needs(base_needs: Dictionary, template_needs: Dictionary):
	"""Deep merge needs from template into base needs"""
	for category in template_needs:
		if base_needs.has(category):
			for need_name in template_needs[category]:
				if base_needs[category].has(need_name):
					# Merge need properties
					for property in template_needs[category][need_name]:
						base_needs[category][need_name][property] = template_needs[category][need_name][property]

func create_character_components(character_id: String, character_data: Dictionary):
	"""Create and attach necessary components to a character"""
	# This would typically be called when a character node is created
	# For now, we'll just track that components should exist
	status_components[character_id] = null  # Placeholder for StatusComponent reference
	action_planners[character_id] = null    # Placeholder for ActionPlanner reference
	environmental_sensors[character_id] = null  # Placeholder for EnvironmentalSensor reference

func get_character(character_id: String) -> Dictionary:
	"""Get character data by ID"""
	if active_characters.has(character_id):
		return active_characters[character_id]
	return {}

func get_all_characters() -> Dictionary:
	"""Get all active characters"""
	return active_characters.duplicate()

func get_character_count() -> int:
	"""Get current population count"""
	return population_count

func save_character(character_id: String) -> bool:
	"""Save a character to persistent storage"""
	if not active_characters.has(character_id):
		push_error("Cannot save non-existent character: " + character_id)
		return false
	
	var character_data = active_characters[character_id]
	character_data.last_saved = Time.get_datetime_string_from_system()
	
	var save_path = SAVE_DIR_PATH + character_id + ".json"
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	
	if file:
		var json_string = JSON.stringify(character_data, "\t")
		file.store_string(json_string)
		file.close()
		
		character_saved.emit(character_id, character_data)
		print("✅ Character saved: " + character_id)
		return true
	else:
		push_error("Failed to save character: " + character_id)
		return false

func save_all_characters():
	"""Save all active characters"""
	var saved_count = 0
	for character_id in active_characters:
		if save_character(character_id):
			saved_count += 1
	
	print("✅ Saved " + str(saved_count) + " characters")

func update_character(character_id: String, updates: Dictionary) -> bool:
	"""Update character data with new values"""
	if not active_characters.has(character_id):
		push_error("Cannot update non-existent character: " + character_id)
		return false
	
	var character_data = active_characters[character_id]
	
	# Deep merge updates
	for key in updates:
		if key == "needs":
			merge_needs(character_data.needs, updates.needs)
		else:
			character_data[key] = updates[key]
	
	# Update timestamp
	character_data.last_updated = Time.get_datetime_string_from_system()
	
	# Save the updated character
	return save_character(character_id)

func delete_character(character_id: String) -> bool:
	"""Delete a character from the system"""
	if not active_characters.has(character_id):
		push_error("Cannot delete non-existent character: " + character_id)
		return false
	
	# Remove from active characters
	active_characters.erase(character_id)
	
	# Remove components
	status_components.erase(character_id)
	action_planners.erase(character_id)
	environmental_sensors.erase(character_id)
	
	# Delete save file
	var save_path = SAVE_DIR_PATH + character_id + ".json"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	
	# Update population count
	population_count = active_characters.size()
	population_updated.emit(population_count)
	
	character_deleted.emit(character_id)
	print("✅ Character deleted: " + character_id)
	
	return true

func get_characters_by_location(location: String) -> Array:
	"""Get all characters at a specific location"""
	var characters_at_location = []
	
	for character_id in active_characters:
		var character = active_characters[character_id]
		if character.has("location") and character.location == location:
			characters_at_location.append(character_id)
	
	return characters_at_location



func get_characters_by_need(need_category: String, need_name: String, threshold: float = 0.3) -> Array:
	"""Get characters with a specific need below threshold (urgent needs)"""
	var needy_characters = []
	
	for character_id in active_characters:
		var character = active_characters[character_id]
		if character.has("needs") and character.needs.has(need_category):
			if character.needs[need_category].has(need_name):
				var need_value = character.needs[need_category][need_name].current
				if need_value <= threshold:
					needy_characters.append(character_id)
	
	return needy_characters

func get_population_summary() -> Dictionary:
	"""Get a summary of the current population"""
	var summary = {
		"total_count": population_count,
		"by_location": {},
		"by_need_status": {
			"urgent_physical": 0,
			"urgent_social": 0,
			"urgent_economic": 0
		}
	}
	
	# Count by location
	for character_id in active_characters:
		var character = active_characters[character_id]
		var location = character.get("location", "unknown")
		summary.by_location[location] = summary.by_location.get(location, 0) + 1
	

	
	# Count urgent needs
	for character_id in active_characters:
		var character = active_characters[character_id]
		if character.has("needs"):
			# Check physical needs
			if character.needs.has("physical"):
				for need_name in character.needs.physical:
					var need_value = character.needs.physical[need_name].current
					if need_value <= 0.3:
						summary.by_need_status.urgent_physical += 1
						break
			
			# Check social needs
			if character.needs.has("social"):
				var social_need = character.needs.social.get("social_need", {}).get("current", 1.0)
				if social_need <= 0.3:
					summary.by_need_status.urgent_social += 1
	
	return summary

func validate_character_data(character_data: Dictionary) -> Array:
	"""Validate character data and return any errors"""
	var errors = []
	
	# Check required fields
	var required_fields = ["character_id", "name", "needs", "inventory"]
	for field in required_fields:
		if not character_data.has(field):
			errors.append("Missing required field: " + field)
	
	# Check needs structure
	if character_data.has("needs"):
		var need_categories = ["physical", "comfort", "activity", "economic", "social"]
		for category in need_categories:
			if not character_data.needs.has(category):
				errors.append("Missing need category: " + category)
	


	
	return errors

func export_population_data() -> Dictionary:
	"""Export population data for external analysis"""
	var export_data = {
		"export_timestamp": Time.get_datetime_string_from_system(),
		"population_count": population_count,
		"characters": {}
	}
	
	for character_id in active_characters:
		var character = active_characters[character_id]
		export_data.characters[character_id] = {
			"name": character.name,
			"location": character.get("location", "unknown"),
			"needs_summary": {},
	
			"current_action": character.get("current_action", null)
		}
		
		# Add needs summary
		if character.has("needs"):
			for category in character.needs:
				export_data.characters[character_id].needs_summary[category] = {}
				for need_name in character.needs[category]:
					export_data.characters[character_id].needs_summary[category][need_name] = character.needs[category][need_name].current
		

	
	return export_data

func set_environmental_sensor(character_id: String, sensor: EnvironmentalSensor):
	"""Register an EnvironmentalSensor component for a character"""
	if active_characters.has(character_id):
		environmental_sensors[character_id] = sensor
		
		# Set up integration with other components
		if status_components.has(character_id) and status_components[character_id]:
			sensor.set_status_component(status_components[character_id])
		
		sensor.set_character_manager(self)
		
		print("✅ EnvironmentalSensor registered for character: " + character_id)
	else:
		push_error("Cannot register EnvironmentalSensor for non-existent character: " + character_id)

func get_environmental_sensor(character_id: String) -> EnvironmentalSensor:
	"""Get the EnvironmentalSensor component for a character"""
	return environmental_sensors.get(character_id, null)

func _exit_tree():
	"""Save all characters when shutting down"""
	save_all_characters()
	print("✅ CharacterManager shutdown complete - all characters saved")
