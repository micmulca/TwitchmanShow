extends Node

# Test script for StatusComponent
# Run this to verify the new StatusComponent works correctly

func _ready():
	print("=== Testing StatusComponent ===")
	
	# Wait a frame for everything to initialize
	await get_tree().process_frame
	
	test_status_component()
	test_json_schema()
	test_integration()
	
	print("\n=== Testing Complete ===")

func test_status_component():
	print("\n--- Testing StatusComponent ---")
	
	# Create a test NPC with StatusComponent
	var test_npc = Node2D.new()
	test_npc.name = "test_npc"
	test_npc.add_to_group("npc")
	
	var status_component = preload("res://components/StatusComponent.gd").new()
	status_component.npc_id = "test_npc"
	test_npc.add_child(status_component)
	
	# Add to scene tree
	get_tree().current_scene.add_child(test_npc)
	
	print("1. Testing initial state...")
	var initial_state = status_component.get_full_status()
	print("  - NPC ID: ", initial_state.npc_id)
	print("  - Action Drive: ", initial_state.action_drive)
	print("  - Location: ", initial_state.location)
	print("  - Need Priorities: ", initial_state.need_priorities.size())
	
	print("\n2. Testing need management...")
	var energy_before = status_component.get_need_value("energy")
	print("  - Energy before: ", energy_before)
	
	status_component.set_need_value("energy", 0.3)
	var energy_after = status_component.get_need_value("energy")
	print("  - Energy after setting to 0.3: ", energy_after)
	
	status_component.modify_need_value("hunger", 0.2)
	var hunger_after = status_component.get_need_value("hunger")
	print("  - Hunger after +0.2: ", hunger_after)
	
	print("\n3. Testing personality modifiers...")
	var old_conscientiousness = status_component.personality.big_five.conscientiousness
	status_component.set_personality_trait("big_five", "conscientiousness", 0.9)
	var new_conscientiousness = status_component.personality.big_five.conscientiousness
	print("  - Conscientiousness changed from ", old_conscientiousness, " to ", new_conscientiousness)
	
	print("\n4. Testing action drive calculation...")
	var drive_before = status_component.get_action_drive()
	print("  - Action drive before: ", drive_before)
	
	# Wait a bit for needs to update
	await get_tree().create_timer(0.2).timeout
	
	var drive_after = status_component.get_action_drive()
	print("  - Action drive after update: ", drive_after)
	
	print("\n5. Testing need priorities...")
	var priorities = status_component.get_need_priorities()
	print("  - Top 3 priorities:")
	for i in range(min(priorities.size(), 3)):
		var need_type = priorities[i]
		var urgency = status_component._calculate_need_urgency(need_type, status_component.get_need_value(need_type))
		print("    ", i + 1, ". ", need_type, " (urgency: ", round(urgency * 100), "%)")
	
	print("\n6. Testing critical needs...")
	var critical_needs = status_component.get_critical_needs()
	print("  - Critical needs: ", critical_needs.size())
	for need in critical_needs:
		print("    - ", need, ": ", status_component.get_need_value(need))
	
	print("\n7. Testing console commands...")
	var result = status_component.console_command("status", [])
	print("  - Status command: ", result.message)
	
	result = status_component.console_command("set_need", ["energy", "0.8"])
	print("  - Set need command: ", result.message)
	
	result = status_component.console_command("set_personality", ["big_five", "openness", "0.8"])
	print("  - Set personality command: ", result.message)
	
	result = status_component.console_command("set_location", ["work"])
	print("  - Set location command: ", result.message)
	
	result = status_component.console_command("priorities", [])
	print("  - Priorities command: ", result.message)
	
	# Cleanup
	test_npc.queue_free()

func test_json_schema():
	print("\n--- Testing JSON Schema ---")
	
	print("1. Testing character template...")
	var template_file = FileAccess.open("res://data/characters/character_template.json", FileAccess.READ)
	if template_file:
		var template_content = template_file.get_as_text()
		template_file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(template_content)
		
		if parse_result == OK:
			print("  - Template JSON parsed successfully")
			var template_data = json.data
			print("  - Character ID: ", template_data.character_id)
			print("  - Need categories: ", template_data.needs.keys().size())
			print("  - Skills: ", template_data.skills.keys().size())
		else:
			print("  - Template JSON parse failed: ", json.get_error_message())
	else:
		print("  - Could not open template file")
	
	print("\n2. Testing Alice character...")
	var alice_file = FileAccess.open("res://data/characters/alice.json", FileAccess.READ)
	if alice_file:
		var alice_content = alice_file.get_as_text()
		alice_file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(alice_content)
		
		if parse_result == OK:
			print("  - Alice JSON parsed successfully")
			var alice_data = json.data
			print("  - Name: ", alice_data.name)
			print("  - Description: ", alice_data.description)
			print("  - Personality - Openness: ", alice_data.personality.big_five.openness)
			print("  - Skills - Cooking: Level ", alice_data.skills.cooking.level)
			print("  - Current Action: ", alice_data.current_action.type if alice_data.current_action else "None")
		else:
			print("  - Alice JSON parse failed: ", json.get_error_message())
	else:
		print("  - Could not open Alice file")

func test_integration():
	print("\n--- Testing Integration ---")
	
	print("1. Testing console integration...")
	var console_node = get_node_or_null("/root/World/Console/ConsoleInstance")
	if console_node:
		print("  - Console found, testing status command...")
		var result = console_node.execute_command("status", [])
		print("  - Status command result: ", result.message)
	else:
		print("  - Console not found, skipping console integration test")
	
	print("2. Testing EventBus integration...")
	# Test that the new component emits proper signals
	var test_npc = Node2D.new()
	test_npc.name = "integration_test_npc"
	test_npc.add_to_group("npc")
	
	var status = preload("res://components/StatusComponent.gd").new()
	status.npc_id = "integration_test_npc"
	test_npc.add_child(status)
	
	# Connect signals
	status.needs_updated.connect(_on_needs_updated)
	status.need_changed.connect(_on_need_changed)
	status.critical_need_alert.connect(_on_critical_need_alert)
	status.action_drive_changed.connect(_on_action_drive_changed)
	
	get_tree().current_scene.add_child(test_npc)
	
	# Trigger some updates
	status.set_need_value("energy", 0.2)
	status.set_location("work")
	await get_tree().create_timer(0.2).timeout
	
	# Cleanup
	test_npc.queue_free()

func _on_needs_updated(npc_id: String, needs: Dictionary):
	print("  - Needs updated for ", npc_id, ": ", needs.keys().size(), " categories")

func _on_need_changed(npc_id: String, need_type: String, old_value: float, new_value: float):
	print("  - Need changed for ", npc_id, " - ", need_type, ": ", old_value, " -> ", new_value)

func _on_critical_need_alert(npc_id: String, need_type: String, value: float):
	print("  - Critical need alert for ", npc_id, " - ", need_type, ": ", value)

func _on_action_drive_changed(npc_id: String, old_drive: float, new_drive: float):
	print("  - Action drive changed for ", npc_id, ": ", old_drive, " -> ", new_drive)
