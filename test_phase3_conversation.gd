extends Node

# Test script for Phase 3: Context & Conversation Updates
# Demonstrates enhanced conversation system, streaming, and context building

func _ready():
	print("=== Phase 3 Test: Context & Conversation Updates ===")
	print("Starting comprehensive test of Phase 3 features...")
	
	# Wait a moment for systems to initialize
	await get_tree().create_timer(1.0).timeout
	
	# Run tests
	_test_enhanced_context_system()
	await get_tree().create_timer(2.0).timeout
	
	_test_conversation_system()
	await get_tree().create_timer(2.0).timeout
	
	_test_streaming_integration()
	await get_tree().create_timer(2.0).timeout
	
	_test_agent_integration()
	await get_tree().create_timer(2.0).timeout
	
	print("=== Phase 3 Test Complete ===")

func _test_enhanced_context_system():
	print("\n--- Testing Enhanced Context System ---")
	
	# Test context building for different NPCs
	var test_npcs = ["agatha_barrow", "anya_carden", "bram_wynn"]
	var test_targets = ["elias_thorn", "fen_barrow"]
	
	for npc in test_npcs:
		print("Building context for ", npc)
		var context = ContextPacker.build_context_for_npc(npc, test_targets)
		
		# Validate context
		var is_valid = ContextPacker.validate_context(context)
		print("  Context valid: ", is_valid)
		print("  Persona: ", context.persona.name, " (", context.persona.occupation, ")")
		print("  Mood: ", context.mood.description)
		print("  Relationships: ", context.relationships.size(), " targets")
		print("  Memory context: ", context.memory_context.recent_memories.size(), " memories")
		print("  Action context: ", context.action_context.recent_actions.size(), " actions")
		
		# Test enhanced prompt building
		var prompt = ContextPacker.build_enhanced_prompt(npc, context)
		print("  Enhanced prompt length: ", prompt.length(), " characters")
	
	print("Enhanced Context System test complete")

func _test_conversation_system():
	print("\n--- Testing Enhanced Conversation System ---")
	
	# Test conversation creation
	var participants = ["agatha_barrow", "anya_carden"]
	var group_id = ConversationController.start_conversation(participants, "community_news")
	
	if group_id != "":
		print("Created conversation group: ", group_id)
		
		# Test adding participant
		var success = ConversationController.add_participant_to_group(group_id, "bram_wynn")
		print("Added Bram to conversation: ", success)
		
		# Test topic injection
		var topic_success = ConversationController.inject_topic_into_group(group_id, "local_events", "test_injection")
		print("Injected topic 'local_events': ", topic_success)
		
		# Get conversation stats
		var stats = ConversationController.get_conversation_stats()
		print("Conversation stats: ", stats.active_groups, " active groups")
		
		# Test conversation group functionality
		var active_groups = ConversationController.get_active_groups()
		var group = active_groups.get(group_id)
		if group:
			var group_stats = group.get_conversation_stats()
			print("Group stats: ", group_stats.participant_count, " participants, ", group_stats.turn_count, " turns")
			
			var dialogue_stats = group.get_dialogue_stats()
			print("Dialogue stats: ", dialogue_stats.total_dialogue_entries, " entries, ", dialogue_stats.total_words, " words")
		
		# Clean up
		ConversationController.remove_participant_from_group(group_id, "bram_wynn", "test_complete")
		ConversationController.remove_participant_from_group(group_id, "anya_carden", "test_complete")
		ConversationController.remove_participant_from_group(group_id, "agatha_barrow", "test_complete")
	else:
		print("Failed to create conversation group")
	
	print("Enhanced Conversation System test complete")

func _test_streaming_integration():
	print("\n--- Testing Streaming Integration ---")
	
	# Create a test conversation
	var participants = ["elias_thorn", "fen_barrow"]
	var group_id = ConversationController.start_conversation(participants, "weather")
	
	if group_id != "":
		print("Created test conversation for streaming: ", group_id)
		
		# Test streaming dialogue generation
		var success = ConversationController.force_dialogue_generation("elias_thorn", group_id)
		print("Started streaming dialogue for Elias: ", success)
		
		# Check streaming status
		var streaming_status = ConversationController.get_streaming_status(group_id)
		if streaming_status.size() > 0:
			print("Streaming active for: ", streaming_status.speaker_id)
			print("Chunks received: ", streaming_status.chunks.size())
		else:
			print("No active streaming")
		
		# Wait for streaming to complete or timeout
		await get_tree().create_timer(5.0).timeout
		
		# Check final status
		streaming_status = ConversationController.get_streaming_status(group_id)
		if streaming_status.size() == 0:
			print("Streaming completed")
		else:
			print("Streaming still active")
		
		# Clean up
		ConversationController.remove_participant_from_group(group_id, "fen_barrow", "test_complete")
		ConversationController.remove_participant_from_group(group_id, "elias_thorn", "test_complete")
	else:
		print("Failed to create test conversation for streaming")
	
	print("Streaming Integration test complete")

func _test_agent_integration():
	print("\n--- Testing Agent Integration ---")
	
	# Test agent-aware topic management
	var topic_manager = get_node_or_null("/root/TopicManager")
	if topic_manager:
		# Test personalized topic suggestions
		var npc = "agatha_barrow"
		var personalized_topics = topic_manager.suggest_personalized_topics(npc, "")
		print("Personalized topics for ", npc, ": ", personalized_topics.size(), " suggestions")
		
		for topic_data in personalized_topics:
			print("  ", topic_data.topic, " (relevance: ", topic_data.relevance, ", agent affinity: ", topic_data.agent_affinity, ")")
		
		# Test agent topic preferences
		var preferences = topic_manager.get_agent_topic_preferences(npc)
		print("Topic preferences for ", npc, ": ", preferences.size(), " preferences")
		
		# Test topic agent affinity calculation
		var test_topic = "community_news"
		var affinity = topic_manager.calculate_topic_agent_affinity(test_topic, npc)
		print("Agent affinity for '", test_topic, "': ", affinity)
	else:
		print("TopicManager not available")
	
	# Test agent-aware turn management
	var active_groups = ConversationController.get_active_groups()
	if active_groups.size() > 0:
		var group_id = active_groups.keys()[0]
		var group = active_groups[group_id]
		var floor_manager = group.get_node_or_null("FloorManager")
		
		if floor_manager:
			print("FloorManager agent integration:")
			print("  Dynamic ordering: ", floor_manager.dynamic_speaking_order)
			print("  Agent preferences: ", floor_manager.agent_turn_preferences.size(), " tracked")
			
			# Test agent turn preferences
			for npc_id in group.participants:
				var preferences = floor_manager.get_agent_turn_preferences(npc_id)
				if preferences.size() > 0:
					print("  ", npc_id, " turn count: ", preferences.get("turn_count", 0))
		else:
			print("FloorManager not available")
	
	print("Agent Integration test complete")

func _test_enhanced_memory_integration():
	print("\n--- Testing Enhanced Memory Integration ---")
	
	# Test memory context building
	var npc = "anya_carden"
	var context = ContextPacker.build_context_for_npc(npc, [])
	
	print("Memory context for ", npc, ":")
	print("  Recent memories: ", context.memory_context.recent_memories.size())
	print("  Relevant memories: ", context.memory_context.relevant_memories.size())
	print("  Emotional memories: ", context.memory_context.emotional_memories.size())
	print("  Action memories: ", context.memory_context.action_memories.size())
	
	# Test action context building
	print("Action context for ", npc, ":")
	print("  Recent actions: ", context.action_context.recent_actions.size())
	print("  Action patterns: ", context.action_context.action_patterns.size())
	print("  Failed actions: ", context.action_context.failed_actions.size())
	print("  Action preferences: ", context.action_context.action_preferences.size())
	
	print("Enhanced Memory Integration test complete")

func _test_relationship_integration():
	print("\n--- Testing Relationship Integration ---")
	
	# Test relationship context building
	var npc = "bram_wynn"
	var targets = ["elias_thorn", "fen_barrow"]
	var context = ContextPacker.build_context_for_npc(npc, targets)
	
	print("Relationship context for ", npc, ":")
	for target_id in context.relationships.keys():
		var rel = context.relationships[target_id]
		print("  ", target_id, ": ", rel.relationship_type, " (trust: ", rel.trust, ", strength: ", rel.strength, ")")
		print("    Recent interactions: ", rel.recent_interactions.size())
		print("    Shared interests: ", rel.shared_interests.size())
		print("    Emotional bonds: ", rel.emotional_bonds.size())
	
	print("Relationship Integration test complete")
