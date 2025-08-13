extends Node

# Test script to verify basic functionality
# Run this in Godot to test the core systems

func _ready():
	print("=== Testing TwitchMan Autonomous World Systems ===")
	
	# Test EventBus
	test_event_bus()
	
	# Test LLMClient
	test_llm_client()
	
	# Test Console commands
	test_console_commands()
	
	print("=== Basic functionality tests completed ===")

func test_event_bus():
	print("\n--- Testing EventBus ---")
	
	# Test basic event emission
	EventBus.emit_world_event("test_event", {"message": "Hello World"})
	EventBus.emit_npc_action("test_npc", "test_action", "test_target", {"data": "test"})
	
	# Check event history
	var history = EventBus.get_event_history()
	print("Event history size: ", history.size())
	
	# Check event stats
	var stats = EventBus.get_event_stats()
	print("Event stats: ", stats)

func test_llm_client():
	print("\n--- Testing LLMClient ---")
	
	# Check health status
	var is_healthy = LLMClient.is_available()
	print("LLM health: ", "Healthy" if is_healthy else "Unhealthy")
	
	# Check pending requests
	var pending = LLMClient.get_pending_request_count()
	print("Pending requests: ", pending)

func test_console_commands():
	print("\n--- Testing Console Commands ---")
	
	# Test help command
	var help_result = EventBus.emit_world_event("console_test", {"command": "help"})
	print("Help command test: ", help_result)
	
	# Test event command
	var event_result = EventBus.emit_world_event("console_test", {"command": "event", "type": "weather", "data": "rain"})
	print("Event command test: ", event_result)

# Run tests when script is executed
func _enter_tree():
	# Wait a frame for autoloads to be ready
	await get_tree().process_frame
	_ready()
