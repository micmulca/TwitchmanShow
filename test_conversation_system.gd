extends Node

# Test script for the conversation system
# Run this in Godot to test the conversation components

func _ready():
	print("=== Testing TwitchMan Conversation System ===")
	
	# Wait for autoloads to be ready
	await get_tree().process_frame
	
	# Test conversation system
	test_conversation_system()
	
	print("=== Conversation system tests completed ===")

func test_conversation_system():
	print("\n--- Testing Conversation System ---")
	
	# Test 1: Start a conversation
	print("\n1. Starting conversation between Alice and Bob...")
	var group_id = ConversationController.start_conversation(["alice", "bob"], "weather")
	if not group_id.is_empty():
		print("✓ Conversation started: ", group_id)
	else:
		print("✗ Failed to start conversation")
		return
	
	# Test 2: Check conversation stats
	print("\n2. Checking conversation stats...")
	var stats = ConversationController.get_conversation_stats()
	print("Active groups: ", stats.active_groups)
	print("Total participants: ", stats.total_participants)
	
	# Test 3: Add a third participant
	print("\n3. Adding Charlie to conversation...")
	if ConversationController.add_participant_to_group(group_id, "charlie"):
		print("✓ Charlie added to conversation")
	else:
		print("✗ Failed to add Charlie")
	
	# Test 4: Inject a new topic
	print("\n4. Injecting new topic...")
	if ConversationController.inject_topic_into_group(group_id, "local_news", "test_injection"):
		print("✓ Topic injected: local_news")
	else:
		print("✗ Failed to inject topic")
	
	# Test 5: Check updated stats
	print("\n5. Checking updated stats...")
	stats = ConversationController.get_conversation_stats()
	print("Active groups: ", stats.active_groups)
	print("Total participants: ", stats.total_participants)
	
	# Test 6: Start another conversation
	print("\n6. Starting second conversation...")
	var group2_id = ConversationController.start_conversation(["david", "eve"], "business")
	if not group2_id.is_empty():
		print("✓ Second conversation started: ", group2_id)
	else:
		print("✗ Failed to start second conversation")
	
	# Test 7: Test topic manager
	print("\n7. Testing TopicManager...")
	var topic_manager = ConversationController.topic_manager
	if topic_manager:
		var suggestions = topic_manager.suggest_topics_for_group(group_id, "local_news", 3)
		print("Topic suggestions: ", suggestions.size())
		for suggestion in suggestions:
			print("  - ", suggestion.topic, " (relevance: ", suggestion.relevance, ")")
	else:
		print("✗ TopicManager not found")
	
	# Test 8: Test context packer
	print("\n8. Testing ContextPacker...")
	var context_packer = ConversationController.context_packer
	if context_packer:
		var context = context_packer.build_context_for_npc("alice", ["bob", "charlie"], group_id)
		print("Context built for Alice:")
		print("  - Persona: ", context.persona.name)
		print("  - Mood: ", context.mood.description)
		print("  - Location: ", context.location.name)
		print("  - Event hints: ", context.event_hints.size())
	else:
		print("✗ ContextPacker not found")
	
	# Test 9: Test floor manager
	print("\n9. Testing FloorManager...")
	var active_groups = ConversationController.get_active_groups()
	if active_groups.has(group_id):
		var group = active_groups[group_id]
		var floor_manager = group.get_node("FloorManager")
		if floor_manager:
			print("Floor manager found")
			print("  - Current speaker: ", floor_manager.get_current_speaker())
			print("  - Speaking order: ", floor_manager.get_speaking_order())
		else:
			print("✗ FloorManager not found")
	
	# Test 10: Test console commands
	print("\n10. Testing Console Commands...")
	test_console_commands()
	
	# Test 11: Test world events
	print("\n11. Testing World Events...")
	test_world_events()
	
	# Test 12: Cleanup
	print("\n12. Cleaning up...")
	ConversationController._end_group(active_groups[group_id], "test_complete")
	if group2_id in active_groups:
		ConversationController._end_group(active_groups[group2_id], "test_complete")
	
	print("✓ Test cleanup completed")

func test_console_commands():
	print("  Testing conversation command...")
	var result = _cmd_conversation(["frank", "grace", "community"])
	if result.success:
		print("    ✓ Conversation command works")
	else:
		print("    ✗ Conversation command failed: ", result.message)
	
	print("  Testing topic command...")
	var active_groups = ConversationController.get_active_groups()
	if not active_groups.is_empty():
		var first_group = active_groups.keys()[0]
		result = _cmd_topic(["politics", "console_test"])
		if result.success:
			print("    ✓ Topic command works")
		else:
			print("    ✗ Topic command failed: ", result.message)
	else:
		print("    - No active groups to test topic command")

func test_world_events():
	print("  Testing weather event...")
	EventBus.emit_world_event("weather", {"type": "rain", "intensity": "heavy"})
	
	print("  Testing economy event...")
	EventBus.emit_world_event("economy", {"type": "prosperity", "intensity": "high"})
	
	print("  Testing social event...")
	EventBus.emit_world_event("social", {"type": "festival", "intensity": "medium"})

# Console command implementations for testing
func _cmd_conversation(args: Array) -> Dictionary:
	if args.size() < 2:
		return {"success": false, "message": "Usage: conversation <npc1> <npc2> [topic]"}
	
	var npc1 = args[0]
	var npc2 = args[1]
	var topic = args[2] if args.size() > 2 else "general_chat"
	
	var participants = [npc1, npc2]
	var group_id = ConversationController.start_conversation(participants, topic)
	
	if not group_id.is_empty():
		return {"success": true, "message": "Started conversation between " + npc1 + " and " + npc2 + " on topic: " + topic}
	else:
		return {"success": false, "message": "Failed to start conversation"}

func _cmd_topic(args: Array) -> Dictionary:
	if args.is_empty():
		return {"success": false, "message": "Usage: topic <topic_name> [reason]"}
	
	var topic = args[0]
	var reason = args[1] if args.size() > 1 else "Console test"
	
	var active_groups = ConversationController.get_active_groups()
	if active_groups.is_empty():
		return {"success": false, "message": "No active conversations to change topic"}
	
	var first_group_id = active_groups.keys()[0]
	if ConversationController.inject_topic_into_group(first_group_id, topic, reason):
		return {"success": true, "message": "Topic changed to '" + topic + "' in group " + first_group_id}
	else:
		return {"success": false, "message": "Failed to change topic"}

# Run tests when script is executed
func _enter_tree():
	# Wait a frame for autoloads to be ready
	await get_tree().process_frame
	_ready()
