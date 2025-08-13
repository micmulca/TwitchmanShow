extends Node

# Test script for Action Execution System
# Tests action lifecycle, progress tracking, interruption handling, and completion effects

func _ready():
	print("=== Testing Action Execution System ===")
	
	# Test 1: Basic initialization
	test_initialization()
	
	# Test 2: Action lifecycle
	test_action_lifecycle()
	
	# Test 3: Progress tracking
	test_progress_tracking()
	
	# Test 4: Interruption handling
	test_interruption_handling()
	
	# Test 5: Completion effects
	test_completion_effects()
	
	# Test 6: Console commands
	test_console_commands()
	
	print("=== Action Execution System Tests Complete ===")

func test_initialization():
	print("\n--- Test 1: Initialization ---")
	
	# Create test ActionExecutor
	var executor = ActionExecutor.new()
	add_child(executor)
	
	# Test initial state
	var status = executor.get_action_status()
	assert(status.is_executing == false, "Should start in idle state")
	assert(status.state == "IDLE", "Should start in IDLE state")
	assert(status.progress == 0.0, "Should start with 0 progress")
	
	print("✅ Initialization test passed")
	
	# Cleanup
	executor.queue_free()

func test_action_lifecycle():
	print("\n--- Test 2: Action Lifecycle ---")
	
	var executor = ActionExecutor.new()
	add_child(executor)
	
	# Create test action data
	var test_action = {
		"id": "test_action",
		"name": "Test Action",
		"description": "A test action for testing",
		"duration": 5.0,
		"satisfies_needs": {"energy": 20},
		"costs": {"hunger": 10},

		"inventory_changes": {"test_item": 1},
		"failure_penalties": {"energy": -5}
	}
	
	# Test starting action
	var result = executor.start_action(test_action, "test_npc")
	assert(result.success == true, "Should start action successfully")
	assert(executor.is_executing == true, "Should be executing after start")
	
	# Test pausing
	result = executor.pause_action()
	assert(result.success == true, "Should pause action successfully")
	assert(executor.is_paused == true, "Should be paused")
	
	# Test resuming
	result = executor.resume_action()
	assert(result.success == true, "Should resume action successfully")
	assert(executor.is_paused == false, "Should not be paused")
	
	# Test completing
	result = executor.complete_action()
	assert(result.success == true, "Should complete action successfully")
	assert(executor.is_executing == false, "Should not be executing after completion")
	
	print("✅ Action lifecycle test passed")
	
	# Cleanup
	executor.queue_free()

func test_progress_tracking():
	print("\n--- Test 3: Progress Tracking ---")
	
	var executor = ActionExecutor.new()
	add_child(executor)
	
	# Create short duration action for testing
	var test_action = {
		"id": "quick_action",
		"name": "Quick Action",
		"description": "A quick test action",
		"duration": 0.5  # 500ms for quick testing
	}
	
	# Start action
	executor.start_action(test_action, "test_npc")
	
	# Wait a bit for progress
	await get_tree().create_timer(0.3).timeout
	
	# Check progress
	var progress = executor.get_progress()
	assert(progress > 0.0, "Progress should increase over time")
	assert(progress < 1.0, "Progress should not be complete yet")
	
	# Wait for completion
	await get_tree().create_timer(0.3).timeout
	
	# Check final progress
	progress = executor.get_progress()
	assert(progress >= 1.0, "Progress should be complete")
	
	print("✅ Progress tracking test passed")
	
	# Cleanup
	executor.queue_free()

func test_interruption_handling():
	print("\n--- Test 4: Interruption Handling ---")
	
	var executor = ActionExecutor.new()
	add_child(executor)
	
	# Create test action
	var test_action = {
		"id": "interruptible_action",
		"name": "Interruptible Action",
		"description": "An action that can be interrupted",
		"duration": 10.0
	}
	
	# Start action
	executor.start_action(test_action, "test_npc")
	
	# Test interruption with insufficient priority
	var result = executor.interrupt_action("Low priority", 50)
	assert(result.success == false, "Should not interrupt with low priority")
	assert(executor.is_executing == true, "Should still be executing")
	
	# Test interruption with sufficient priority
	result = executor.interrupt_action("High priority", 150)
	assert(result.success == true, "Should interrupt with high priority")
	assert(executor.is_executing == false, "Should not be executing after interruption")
	
	# Test interruption settings
	executor.set_interruption_settings(false, 200)
	assert(executor.can_interrupt(300) == false, "Should not be interruptible when disabled")
	
	print("✅ Interruption handling test passed")
	
	# Cleanup
	executor.queue_free()

func test_completion_effects():
	print("\n--- Test 4: Completion Effects ---")
	
	var executor = ActionExecutor.new()
	add_child(executor)
	
	# Create test action with effects
	var test_action = {
		"id": "effectful_action",
		"name": "Effectful Action",
		"description": "An action with various effects",
		"duration": 1.0,
		"satisfies_needs": {"energy": 25, "hunger": 15},

		"inventory_changes": {"test_item": 2},
		"effects": {"special_effect": true}
	}
	
	# Start and complete action
	executor.start_action(test_action, "test_npc")
	var result = executor.complete_action()
	
	# Check completion results
	assert(result.success == true, "Should complete successfully")
	assert(result.has("results"), "Should have results")
	
	var results = result.results
	assert(results.has("needs_satisfied"), "Should have needs satisfied")
	
	assert(results.has("inventory_changes"), "Should have inventory changes")
	assert(results.has("other_effects"), "Should have other effects")
	
	print("✅ Completion effects test passed")
	
	# Cleanup
	executor.queue_free()

func test_console_commands():
	print("\n--- Test 6: Console Commands ---")
	
	var executor = ActionExecutor.new()
	add_child(executor)
	
	# Test status command
	var result = executor.console_command("status", [])
	assert(result.success == true, "Status command should succeed")
	assert(result.has("data"), "Status command should return data")
	
	# Test progress command
	result = executor.console_command("progress", [])
	assert(result.success == true, "Progress command should succeed")
	assert(result.has("data"), "Progress command should return data")
	
	# Test unknown command
	result = executor.console_command("unknown", [])
	assert(result.success == false, "Unknown command should fail")
	
	print("✅ Console commands test passed")
	
	# Cleanup
	executor.queue_free()

# Helper function to create a mock StatusComponent for testing
func create_mock_status_component():
	var mock_status = Node.new()
	mock_status.name = "StatusComponent"
	
	# Add mock methods
	mock_status.modify_need = func(need_type: String, amount: float):
		print("Mock: Modified ", need_type, " by ", amount)
		return true
	
	return mock_status
