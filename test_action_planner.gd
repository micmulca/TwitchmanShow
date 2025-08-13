extends Node

# Test script for ActionPlanner
# Run this to verify the new ActionPlanner works correctly

func _ready():
	print("=== Testing ActionPlanner ===")
	
	# Wait a frame for everything to initialize
	await get_tree().process_frame
	
	test_action_planner()
	test_action_definitions()
	test_integration()
	
	print("\n=== Testing Complete ===")

func test_action_planner():
	print("\n--- Testing ActionPlanner ---")
	
	# Create a test NPC with StatusComponent and ActionPlanner
	var test_npc = Node2D.new()
	test_npc.name = "test_npc"
	test_npc.add_to_group("npc")
	
	# Add StatusComponent
	var status_component = preload("res://components/StatusComponent.gd").new()
	status_component.npc_id = "test_npc"
	test_npc.add_child(status_component)
	
	# Add ActionPlanner
	var action_planner = preload("res://controllers/ActionPlanner.gd").new()
	action_planner.npc_id = "test_npc"
	test_npc.add_child(action_planner)
	
	# Add to scene tree
	get_tree().current_scene.add_child(test_npc)
	
	print("1. Testing ActionPlanner initialization...")
	print("  - NPC ID: ", action_planner.npc_id)
	print("  - StatusComponent found: ", action_planner.status_component != null)
	print("  - Available actions: ", action_planner.available_actions.size())
	
	print("\n2. Testing action loading...")
	var actions = action_planner.get_available_actions()
	print("  - Total actions loaded: ", actions.size())
	
	# Show first few actions
	for i in range(min(actions.size(), 3)):
		var action = actions[i]
		print("    ", i + 1, ". ", action.name, " (", action.category, ")")
	
	print("\n3. Testing need analysis...")
	var need_analysis = action_planner._analyze_needs()
	print("  - Need categories: ", need_analysis.needs.keys().size())
	print("  - Need priorities: ", need_analysis.priorities.size())
	print("  - Critical needs: ", need_analysis.critical.size())
	
	print("\n4. Testing action scoring...")
	var action_scores = action_planner._score_actions(need_analysis)
	print("  - Scored actions: ", action_scores.size())
	
	if action_scores.size() > 0:
		var top_action = action_scores[0]
		print("  - Top action: ", top_action.name, " (score: ", round(top_action.score * 100), "%)")
	
	print("\n5. Testing action planning...")
	action_planner._plan_next_action()
	var current_plan = action_planner.get_current_plan()
	
	if current_plan.has("name"):
		print("  - Current plan: ", current_plan.name)
		print("  - Plan score: ", round(current_plan.score * 100), "%")
		print("  - Plan category: ", current_plan.category)
	else:
		print("  - No current plan")
	
	print("\n6. Testing console commands...")
	var result = action_planner.console_command("plan", [])
	print("  - Plan command: ", result.message)
	
	result = action_planner.console_command("actions", [])
	print("  - Actions command: ", result.message)
	
	result = action_planner.console_command("score", ["rest"])
	print("  - Score command: ", result.message)
	
	# Cleanup
	test_npc.queue_free()

func test_action_definitions():
	print("\n--- Testing Action Definitions ---")
	
	print("1. Testing basic_actions.json...")
	var actions_file = FileAccess.open("res://data/actions/basic_actions.json", FileAccess.READ)
	if actions_file:
		var actions_content = actions_file.get_as_text()
		actions_file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(actions_content)
		
		if parse_result == OK:
			var actions_data = json.data
			print("  - Actions file parsed successfully")
			print("  - Version: ", actions_data.version)
			print("  - Total actions: ", actions_data.actions.size())
			print("  - Location types: ", actions_data.location_types.keys().size())
			print("  - Need categories: ", actions_data.need_categories.keys().size())
			
			# Test a specific action
			var rest_action = null
			for action in actions_data.actions:
				if action.id == "rest":
					rest_action = action
					break
			
			if rest_action:
				print("  - Rest action found:")
				print("    - Name: ", rest_action.name)
				print("    - Category: ", rest_action.category)
				print("    - Satisfies: ", rest_action.satisfies_needs)
				print("    - Costs: ", rest_action.costs)
				print("    - Duration: ", rest_action.duration, " seconds")
				print("    - Location tags: ", rest_action.location_tags)
		else:
			print("  - Actions file parse failed: ", json.get_error_message())
	else:
		print("  - Could not open actions file")

func test_integration():
	print("\n--- Testing Integration ---")
	
	print("1. Testing console integration...")
	var console_node = get_node_or_null("/root/World/Console/ConsoleInstance")
	if console_node:
		print("  - Console found, testing action command...")
		var result = console_node.execute_command("action", [])
		print("  - Action command result: ", result.message)
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
	
	var planner = preload("res://controllers/ActionPlanner.gd").new()
	planner.npc_id = "integration_test_npc"
	test_npc.add_child(planner)
	
	# Connect signals
	planner.action_planned.connect(_on_action_planned)
	planner.action_selected.connect(_on_action_selected)
	planner.planning_failed.connect(_on_planning_failed)
	
	get_tree().current_scene.add_child(test_npc)
	
	# Trigger some planning
	planner._plan_next_action()
	await get_tree().create_timer(0.2).timeout
	
	# Cleanup
	test_npc.queue_free()

func _on_action_planned(npc_id: String, action: Dictionary, score: float):
	print("  - Action planned for ", npc_id, ": ", action.name, " (score: ", round(score * 100), "%)")

func _on_action_selected(npc_id: String, action: Dictionary):
	print("  - Action selected for ", npc_id, ": ", action.name)

func _on_planning_failed(npc_id: String, reason: String):
	print("  - Planning failed for ", npc_id, ": ", reason)
