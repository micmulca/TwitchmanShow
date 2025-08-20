extends Node

# Test script for Enhanced LLM System (Phase 2)
# Demonstrates hybrid inference, streaming, and persona caching

func _ready():
	print("=== Enhanced LLM System Test ===")
	print("Testing Phase 2 features...")
	
	# Wait a frame for autoloads to be ready
	await get_tree().process_frame
	
	# Test 1: Show LLM status
	_test_llm_status()
	
	# Test 2: Test hybrid inference
	_test_hybrid_inference()
	
	# Test 3: Test persona caching
	_test_persona_caching()
	
	# Test 4: Test streaming
	_test_streaming()
	
	print("=== Enhanced LLM System Test Complete ===")

func _test_llm_status():
	"""Test LLM status display"""
	print("\n--- Testing LLM Status ---")
	
	if not LLMClient:
		print("❌ LLMClient not available")
		return
	
	var status = {
		"hybrid_inference": LLMClient.use_hybrid_inference,
		"streaming_enabled": LLMClient.streaming_enabled,
		"local_health": LLMClient.is_healthy,
		"cloud_configured": not LLMClient.cloud_api_key.is_empty(),
		"pending_requests": LLMClient.get_pending_request_count(),
		"persona_cache_size": LLMClient.persona_cache.size()
	}
	
	print("✅ LLM Status:")
	for key in status.keys():
		print("  " + key + ": " + str(status[key]))

func _test_hybrid_inference():
	"""Test hybrid inference model selection"""
	print("\n--- Testing Hybrid Inference ---")
	
	if not LLMClient:
		print("❌ LLMClient not available")
		return
	
	# Test simple context
	var simple_context = {
		"prompt": "Hello",
		"is_spotlight": false,
		"conversation_history": [],
		"participants": ["npc1"],
		"topic_complexity": 0.1
	}
	
	# Test complex context
	var complex_context = {
		"prompt": "Discuss the philosophical implications of quantum mechanics",
		"is_spotlight": true,
		"conversation_history": ["long", "complex", "discussion"] * 10,
		"participants": ["npc1", "npc2", "npc3", "npc4", "npc5"],
		"topic_complexity": 0.9,
		"memory_context": ["memory1", "memory2", "memory3", "memory4", "memory5", "memory6"]
	}
	
	var simple_strategy = LLMClient.select_model_strategy(simple_context)
	var complex_strategy = LLMClient.select_model_strategy(complex_context)
	
	var simple_complexity = LLMClient._assess_prompt_complexity(simple_context)
	var complex_complexity = LLMClient._assess_prompt_complexity(complex_context)
	
	print("✅ Model Selection Results:")
	print("  Simple context: " + simple_strategy + " (complexity: " + str(simple_complexity) + ")")
	print("  Complex context: " + complex_strategy + " (complexity: " + str(complex_complexity) + ")")

func _test_persona_caching():
	"""Test persona block caching"""
	print("\n--- Testing Persona Caching ---")
	
	if not LLMClient:
		print("❌ LLMClient not available")
		return
	
	var agent_id = "test_wizard"
	var test_persona = {
		"system_prompt": "You are a wise old wizard who speaks in riddles",
		"style_rules": ["Use archaic language", "Include magical references", "Be mysterious"],
		"voice_characteristics": ["Deep voice", "Slow speech", "Wise tone"],
		"few_shot_examples": [
			"Ah, young seeker, the path you tread is fraught with peril and promise...",
			"The stars whisper secrets to those who listen with their hearts..."
		]
	}
	
	# Get cached persona block
	var persona_block = LLMClient.get_cached_persona_block(agent_id, test_persona)
	
	# Test context building
	var test_context = {
		"agent_id": agent_id,
		"agent_persona": test_persona,
		"prompt": "Greet a traveler"
	}
	
	var system_prompt = LLMClient._build_system_prompt(test_context)
	
	print("✅ Persona Caching Results:")
	print("  Agent ID: " + agent_id)
	print("  Persona block length: " + str(persona_block.length()))
	print("  System prompt length: " + str(system_prompt.length()))
	print("  Cache size: " + str(LLMClient.persona_cache.size()))
	print("  Persona block preview: " + persona_block.substr(0, 100) + "...")

func _test_streaming():
	"""Test streaming functionality"""
	print("\n--- Testing Streaming ---")
	
	if not LLMClient:
		print("❌ LLMClient not available")
		return
	
	# Enable streaming
	LLMClient.set_streaming_enabled(true)
	
	# Test streaming request
	var test_context = {
		"prompt": "Tell me a short story about a brave knight",
		"temperature": 0.8,
		"stream": true,
		"max_tokens": 100
	}
	
	print("✅ Streaming enabled: " + str(LLMClient.streaming_enabled))
	print("✅ Streaming configuration:")
	print("  Chunk size: " + str(LLMClient.agent_config.streaming.chunk_size))
	print("  Update rate: " + str(LLMClient.agent_config.streaming.update_rate))
	
	# Note: Actual streaming test would require LLM response
	print("ℹ️  Streaming test requires active LLM connection")

func _test_async_generation():
	"""Test async generation with timeout"""
	print("\n--- Testing Async Generation ---")
	
	if not LLMClient:
		print("❌ LLMClient not available")
		return
	
	var test_context = {
		"prompt": "Say hello in a friendly way",
		"temperature": 0.7,
		"stream": false
	}
	
	# Test async generation
	var request_id = LLMClient.generate_async(test_context, func(response): 
		print("✅ Async response received: " + str(response))
	)
	
	print("✅ Async generation test:")
	print("  Request ID: " + request_id)
	print("  Context: " + str(test_context))
	print("  Callback registered for response handling")

func _test_performance_tracking():
	"""Test performance metrics"""
	print("\n--- Testing Performance Tracking ---")
	
	if not LLMClient:
		print("❌ LLMClient not available")
		return
	
	var performance = LLMClient.get_model_performance()
	
	print("✅ Performance Metrics:")
	for model in performance.keys():
		var metrics = performance[model]
		print("  " + model + ":")
		print("    Success rate: " + str(metrics.success_rate))
		print("    Error count: " + str(metrics.error_count))
		print("    Avg response time: " + str(metrics.avg_response_time))
