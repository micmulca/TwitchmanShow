extends Node

# Test script for NeedsComponent and ProximityAgent
# Run this to verify the new components work correctly

func _ready():
	print("=== Testing NeedsComponent and ProximityAgent ===")
	
	# Wait a frame for everything to initialize
	await get_tree().process_frame
	
	test_needs_component()
	test_proximity_agent()
	test_integration()
	
	print("\n=== Testing Complete ===")

func test_needs_component():
	print("\n--- Testing NeedsComponent ---")
	
	# Create a test NPC with NeedsComponent
	var test_npc = Node2D.new()
	test_npc.name = "test_npc"
	test_npc.add_to_group("npc")
	
	var needs_component = preload("res://components/NeedsComponent.gd").new()
	needs_component.npc_id = "test_npc"
	test_npc.add_child(needs_component)
	
	# Add to scene tree
	get_tree().current_scene.add_child(test_npc)
	
	print("1. Testing initial state...")
	var initial_state = needs_component.get_needs_state()
	print("  - Social need: ", initial_state.social_need)
	print("  - Social fatigue: ", initial_state.social_fatigue)
	print("  - Extroversion: ", initial_state.extroversion)
	print("  - Social drive: ", initial_state.social_drive)
	
	print("\n2. Testing social drive calculation...")
	var drive = needs_component.get_social_drive()
	print("  - Social drive: ", drive)
	
	print("\n3. Testing conversation decisions...")
	var should_join = needs_component.should_join_conversation()
	var should_leave = needs_component.should_leave_conversation()
	var should_speak = needs_component.should_start_speaking()
	print("  - Should join: ", should_join)
	print("  - Should leave: ", should_leave)
	print("  - Should speak: ", should_speak)
	
	print("\n4. Testing speaking state changes...")
	needs_component.set_speaking_state(true)
	needs_component.set_group_size(3)
	
	# Wait a bit for needs to update
	await get_tree().create_timer(0.2).timeout
	
	var updated_state = needs_component.get_needs_state()
	print("  - After speaking: need=", round(updated_state.social_need * 100), "%, fatigue=", round(updated_state.social_fatigue * 100), "%")
	
	print("\n5. Testing console commands...")
	var result = needs_component.console_command("status", [])
	print("  - Status command: ", result.message)
	
	result = needs_component.console_command("set_need", ["0.8"])
	print("  - Set need command: ", result.message)
	
	# Cleanup
	test_npc.queue_free()

func test_proximity_agent():
	print("\n--- Testing ProximityAgent ---")
	
	# Create test NPCs
	var npc1 = Node2D.new()
	npc1.name = "npc1"
	npc1.add_to_group("npc")
	npc1.global_position = Vector2(100, 100)
	
	var npc2 = Node2D.new()
	npc2.name = "npc2"
	npc2.add_to_group("npc")
	npc2.global_position = Vector2(200, 100)  # Within detection radius
	
	var npc3 = Node2D.new()
	npc3.name = "npc3"
	npc3.add_to_group("npc")
	npc3.global_position = Vector2(400, 100)  # Outside detection radius
	
	# Add components
	var needs1 = preload("res://components/NeedsComponent.gd").new()
	needs1.npc_id = "npc1"
	needs1.social_need = 0.7
	needs1.extroversion = 0.8
	npc1.add_child(needs1)
	
	var needs2 = preload("res://components/NeedsComponent.gd").new()
	needs2.npc_id = "npc2"
	needs2.social_need = 0.6
	needs2.extroversion = 0.6
	npc2.add_child(needs2)
	
	var needs3 = preload("res://components/NeedsComponent.gd").new()
	needs3.npc_id = "npc3"
	needs3.social_need = 0.5
	needs3.extroversion = 0.4
	npc3.add_child(needs3)
	
	var proximity1 = preload("res://components/ProximityAgent.gd").new()
	proximity1.npc_id = "npc1"
	proximity1.detection_radius = 150.0
	proximity1.conversation_radius = 100.0
	npc1.add_child(proximity1)
	
	var proximity2 = preload("res://components/ProximityAgent.gd").new()
	proximity2.npc_id = "npc2"
	proximity2.detection_radius = 150.0
	proximity2.conversation_radius = 100.0
	npc2.add_child(proximity2)
	
	var proximity3 = preload("res://components/ProximityAgent.gd").new()
	proximity3.npc_id = "npc3"
	proximity3.detection_radius = 150.0
	proximity3.conversation_radius = 100.0
	npc3.add_child(proximity3)
	
	# Add to scene tree
	get_tree().current_scene.add_child(npc1)
	get_tree().current_scene.add_child(npc2)
	get_tree().current_scene.add_child(npc3)
	
	print("1. Testing proximity detection...")
	await get_tree().create_timer(0.6).timeout  # Wait for proximity update
	
	var nearby1 = proximity1.get_nearby_npcs()
	var nearby2 = proximity2.get_nearby_npcs()
	var nearby3 = proximity3.get_nearby_npcs()
	
	print("  - NPC1 nearby: ", nearby1.size(), " NPCs")
	print("  - NPC2 nearby: ", nearby2.size(), " NPCs")
	print("  - NPC3 nearby: ", nearby3.size(), " NPCs")
	
	print("\n2. Testing conversation range...")
	var in_range1 = proximity1.get_npcs_in_conversation_range()
	var in_range2 = proximity2.get_npcs_in_conversation_range()
	
	print("  - NPC1 conversation range: ", in_range1.size(), " NPCs")
	print("  - NPC2 conversation range: ", in_range2.size(), " NPCs")
	
	print("\n3. Testing console commands...")
	var result = proximity1.console_command("nearby", [])
	print("  - Nearby command: ", result.message)
	
	result = proximity1.console_command("status", [])
	print("  - Status command: ", result.message)
	
	# Cleanup
	npc1.queue_free()
	npc2.queue_free()
	npc3.queue_free()

func test_integration():
	print("\n--- Testing Integration ---")
	
	print("1. Testing console integration...")
	var console_node = get_node_or_null("/root/World/Console/ConsoleInstance")
	if console_node:
		print("  - Console found, testing needs command...")
		var result = console_node.execute_command("needs", ["test_npc", "status"])
		print("  - Needs command result: ", result.message)
		
		print("  - Testing proximity command...")
		result = console_node.execute_command("proximity", ["test_npc", "status"])
		print("  - Proximity command result: ", result.message)
	else:
		print("  - Console not found, skipping console integration test")
	
	print("2. Testing EventBus integration...")
	# Test that the new components emit proper signals
	var test_npc = Node2D.new()
	test_npc.name = "integration_test_npc"
	test_npc.add_to_group("npc")
	
	var needs = preload("res://components/NeedsComponent.gd").new()
	needs.npc_id = "integration_test_npc"
	test_npc.add_child(needs)
	
	var proximity = preload("res://components/ProximityAgent.gd").new()
	proximity.npc_id = "integration_test_npc"
	test_npc.add_child(proximity)
	
	# Connect signals
	needs.needs_updated.connect(_on_needs_updated)
	proximity.proximity_detected.connect(_on_proximity_detected)
	
	get_tree().current_scene.add_child(test_npc)
	
	# Trigger some updates
	needs.set_speaking_state(true)
	await get_tree().create_timer(0.2).timeout
	
	# Cleanup
	test_npc.queue_free()

func _on_needs_updated(npc_id: String, needs: Dictionary):
	print("  - Needs updated for ", npc_id, ": ", needs)

func _on_proximity_detected(npc_id: String, nearby_npcs: Array):
	print("  - Proximity detected for ", npc_id, ": ", nearby_npcs.size(), " nearby NPCs")
