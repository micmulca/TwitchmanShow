extends Node

# LLMClient - Enhanced LLM integration with hybrid inference, streaming, and async generation
# Includes local (LM Studio) + cloud (OpenAI) model selection, streaming responses, and performance optimization

signal llm_response_received(request_id: String, response: Dictionary)
signal llm_request_failed(request_id: String, error: String)
signal llm_health_changed(is_healthy: bool)
# NEW: Streaming signals
signal llm_stream_started(request_id: String)
signal llm_stream_chunk(request_id: String, chunk: String, is_complete: bool)
signal llm_stream_completed(request_id: String, full_response: Dictionary)

# Configuration
var lm_studio_url: String = "http://localhost:1234"
var lm_studio_port: int = 1234
var request_timeout: float = 30.0
var max_retries: int = 3
var retry_delay: float = 1.0

# NEW: Enhanced configuration for hybrid inference
var cloud_api_key: String = ""
var use_hybrid_inference: bool = true
var local_model: String = "TheBloke/OpenHermes-2.5-Mistral-7B-GGUF"
var cloud_model: String = "gpt-4o-mini"
var streaming_enabled: bool = true

# NEW: Performance and streaming configuration
var agent_config: Dictionary = {
	"reply_length": {"min": 40, "max": 70},  # tokens
	"prompt_budget": {"min": 300, "max": 600},  # tokens
	"timeouts": {
		"local": 1.5,    # seconds
		"cloud": 4.0     # seconds
	},
	"streaming": {
		"enabled": true,
		"chunk_size": 10,  # tokens per chunk
		"update_rate": 0.1  # seconds between updates
	},
	"fallback": {
		"enabled": true,
		"response_time": 0.5  # seconds
	}
}

# State
var is_healthy: bool = false
var pending_requests: Dictionary = {}
var request_counter: int = 0

# NEW: Enhanced state tracking
var streaming_requests: Dictionary = {}
var persona_cache: Dictionary = {}  # Cache for persona blocks
var model_performance: Dictionary = {
	"local": {"success_rate": 0.0, "avg_response_time": 0.0, "error_count": 0},
	"cloud": {"success_rate": 0.0, "avg_response_time": 0.0, "error_count": 0}
}

# HTTP client for API calls
var http_client: HTTPRequest

func _ready():
	http_client = HTTPRequest.new()
	add_child(http_client)
	http_client.request_completed.connect(_on_request_completed)
	
	# Check health at startup
	check_health()
	
	# NEW: Initialize streaming timer
	if streaming_enabled:
		var streaming_timer = Timer.new()
		add_child(streaming_timer)
		streaming_timer.wait_time = agent_config.streaming.update_rate
		streaming_timer.timeout.connect(_process_streaming_updates)
		streaming_timer.start()

# NEW: Model selection strategy
func select_model_strategy(context: Dictionary) -> String:
	"""Choose local vs cloud based on context and performance"""
	if not use_hybrid_inference:
		return "local"
	
	# Use cloud for "spotlight" moments or complex contexts
	if context.get("is_spotlight", false):
		return "cloud"
	
	# Use cloud if local model has poor performance
	if model_performance.local.success_rate < 0.7:
		return "cloud"
	
	# Use cloud for complex prompts that exceed local model capabilities
	var prompt_complexity = _assess_prompt_complexity(context)
	if prompt_complexity > 0.8:
		return "cloud"
	
	return "local"

# NEW: Prompt complexity assessment
func _assess_prompt_complexity(context: Dictionary) -> float:
	"""Assess how complex a prompt is (0.0 = simple, 1.0 = very complex)"""
	var complexity = 0.0
	
	# Factor in conversation length
	if context.has("conversation_history"):
		var history_length = context.conversation_history.size()
		complexity += min(history_length / 20.0, 0.3)  # Max 0.3 for history
	
	# Factor in number of participants
	if context.has("participants"):
		var participant_count = context.participants.size()
		complexity += min(participant_count / 10.0, 0.2)  # Max 0.2 for participants
	
	# Factor in topic complexity
	if context.has("topic_complexity"):
		complexity += context.topic_complexity * 0.3
	
	# Factor in memory context
	if context.has("memory_context") and context.memory_context.size() > 5:
		complexity += 0.2
	
	return min(complexity, 1.0)

# NEW: Async generation with streaming
func generate_async(context: Dictionary, callback: Callable, timeout: float = -1.0) -> String:
	"""Generate response asynchronously with optional streaming"""
	var request_id = "req_" + str(request_counter)
	request_counter += 1
	
	var model_strategy = select_model_strategy(context)
	var model_timeout = timeout if timeout > 0 else agent_config.timeouts[model_strategy]
	
	# Build the request payload
	var request_data = _build_request_payload(context, model_strategy)
	
	# Store pending request
	pending_requests[request_id] = {
		"data": request_data,
		"context": context,
		"retry_count": 0,
		"timestamp": Time.get_time_dict_from_system(),
		"model_strategy": model_strategy,
		"callback": callback,
		"timeout": model_timeout,
		"is_streaming": request_data.get("stream", false)
	}
	
	# Set timeout
	if model_timeout > 0:
		var timer = get_tree().create_timer(model_timeout)
		timer.timeout.connect(func(): _handle_timeout(request_id))
	
	# Send request
	_send_http_request(request_id, request_data)
	
	return request_id

# NEW: Build request payload based on model strategy
func _build_request_payload(context: Dictionary, model_strategy: String) -> Dictionary:
	var base_payload = {
		"messages": [
			{
				"role": "system",
				"content": _build_system_prompt(context)
			},
			{
				"role": "user",
				"content": context.get("prompt", "Continue the conversation naturally.")
			}
		],
		"temperature": context.get("temperature", 0.7),
		"max_tokens": context.get("max_tokens", agent_config.reply_length.max),
		"stream": context.get("stream", streaming_enabled)
	}
	
	if model_strategy == "local":
		base_payload["model"] = local_model
		base_payload["max_tokens"] = min(base_payload.max_tokens, 100)  # Local models have lower limits
	else:  # cloud
		base_payload["model"] = cloud_model
		base_payload["max_tokens"] = min(base_payload.max_tokens, 150)  # Cloud models can handle more
	
	return base_payload

# NEW: Handle request timeout
func _handle_timeout(request_id: String):
	if not pending_requests.has(request_id):
		return
	
	var request_info = pending_requests[request_id]
	print("[LLMClient] Request ", request_id, " timed out after ", request_info.timeout, " seconds")
	
	# Use fallback response
	_handle_fallback_response(request_id, request_info.data)
	
	# Update performance metrics
	var model_strategy = request_info.get("model_strategy", "local")
	model_performance[model_strategy].error_count += 1

# NEW: Process streaming updates
func _process_streaming_updates():
	"""Process streaming responses and emit chunk signals"""
	for request_id in streaming_requests.keys():
		var stream_info = streaming_requests[request_id]
		if stream_info.has("is_complete") and stream_info.is_complete:
			continue
		
		# Emit streaming chunk if available
		if stream_info.has("current_chunk") and not stream_info.current_chunk.is_empty():
			llm_stream_chunk.emit(request_id, stream_info.current_chunk, false)
			stream_info.current_chunk = ""  # Clear chunk after emitting

# NEW: Enhanced request sending with model strategy
func _send_http_request(request_id: String, request_data: Dictionary):
	var request_info = pending_requests.get(request_id)
	if not request_info:
		return
	
	var model_strategy = request_info.get("model_strategy", "local")
	
	if not is_healthy and model_strategy == "local":
		# Use fallback if local LLM is unhealthy
		_handle_fallback_response(request_id, request_data)
		return
	
	var headers = ["Content-Type: application/json"]
	
	# Add cloud API key if using cloud
	if model_strategy == "cloud" and not cloud_api_key.is_empty():
		headers.append("Authorization: Bearer " + cloud_api_key)
	
	var json_string = JSON.stringify(request_data)
	var url = _get_api_url(model_strategy)
	
	var result = http_client.request(url, headers, HTTPClient.METHOD_POST, json_string)
	
	if result != OK:
		_handle_request_error(request_id, "Failed to send HTTP request: " + str(result))

# NEW: Get API URL based on model strategy
func _get_api_url(model_strategy: String) -> String:
	if model_strategy == "local":
		return lm_studio_url + "/v1/chat/completions"
	else:  # cloud
		return "https://api.openai.com/v1/chat/completions"

# NEW: Enhanced response processing with streaming support
func _process_llm_response(request_id: String, response_data: Dictionary):
	var request_info = pending_requests.get(request_id)
	if not request_info:
		return
	
	# Check if this is a health check response
	if request_info.has("is_health_check") and request_info.is_health_check:
		_set_health_status(true)
		pending_requests.erase(request_id)
		print("[LLMClient] Health check successful - LLM is now healthy")
		return
	
	# Handle streaming responses
	if request_info.get("is_streaming", false):
		_process_streaming_response(request_id, response_data)
		return
	
	# Handle regular responses
	var content = ""
	if response_data.has("choices") and response_data.choices.size() > 0:
		var choice = response_data.choices[0]
		if choice.has("message") and choice.message.has("content"):
			content = choice.message.content
	
	# Try to parse as JSON
	var parsed_response = _parse_llm_response(content)
	
	if parsed_response:
		# Valid JSON response
		llm_response_received.emit(request_id, parsed_response)
		_update_performance_metrics(request_info.model_strategy, true)
		pending_requests.erase(request_id)
	else:
		# Invalid response, use fallback
		_handle_fallback_response(request_id, request_info.data)
		_update_performance_metrics(request_info.model_strategy, false)

# NEW: Process streaming responses
func _process_streaming_response(request_id: String, response_data: Dictionary):
	"""Process streaming response data and emit chunk signals"""
	var request_info = pending_requests.get(request_id)
	if not request_info:
		return
	
	# Initialize streaming info if not exists
	if not streaming_requests.has(request_id):
		streaming_requests[request_id] = {
			"full_response": "",
			"current_chunk": "",
			"is_complete": false,
			"model_strategy": request_info.get("model_strategy", "local")
		}
	
	var stream_info = streaming_requests[request_id]
	
	# Check if this is the end of the stream
	if response_data.has("choices") and response_data.choices.size() > 0:
		var choice = response_data.choices[0]
		if choice.has("finish_reason") and choice.finish_reason != null:
			# Stream is complete
			stream_info.is_complete = true
			
			# Parse the complete response
			var parsed_response = _parse_llm_response(stream_info.full_response)
			if parsed_response:
				llm_stream_completed.emit(request_id, parsed_response)
				_update_performance_metrics(stream_info.model_strategy, true)
			else:
				# Use fallback if parsing fails
				_handle_fallback_response(request_id, request_info.data)
				_update_performance_metrics(stream_info.model_strategy, false)
			
			# Clean up
			streaming_requests.erase(request_id)
			pending_requests.erase(request_id)
			return
		
		# Extract content chunk
		if choice.has("delta") and choice.delta.has("content"):
			var chunk = choice.delta.content
			stream_info.full_response += chunk
			stream_info.current_chunk = chunk
			
			# Emit streaming chunk
			llm_stream_chunk.emit(request_id, chunk, false)

# NEW: Update performance metrics
func _update_performance_metrics(model_strategy: String, success: bool):
	"""Update performance tracking for model selection"""
	if not model_performance.has(model_strategy):
		return
	
	var metrics = model_performance[model_strategy]
	var total_requests = metrics.success_rate * 100 + metrics.error_count
	
	if success:
		metrics.success_rate = (metrics.success_rate * total_requests + 1) / (total_requests + 1)
	else:
		metrics.error_count += 1
		metrics.success_rate = metrics.success_rate * total_requests / (total_requests + 1)

# NEW: Persona block caching
func get_cached_persona_block(agent_id: String, persona_data: Dictionary) -> String:
	"""Get or create cached persona block for performance optimization"""
	var cache_key = agent_id + "_" + str(persona_data.hash())
	
	if persona_cache.has(cache_key):
		return persona_cache[cache_key]
	
	# Create new persona block
	var persona_block = _build_persona_block(persona_data)
	persona_cache[cache_key] = persona_block
	
	# Limit cache size
	if persona_cache.size() > 50:
		var oldest_key = persona_cache.keys()[0]
		persona_cache.erase(oldest_key)
	
	return persona_block

# NEW: Build persona block
func _build_persona_block(persona_data: Dictionary) -> String:
	"""Build system prompt persona block from agent data"""
	var block = "You are an NPC with the following characteristics:\n\n"
	
	if persona_data.has("system_prompt"):
		block += "Core Identity: " + persona_data.system_prompt + "\n\n"
	
	if persona_data.has("style_rules"):
		block += "Style Rules:\n"
		for rule in persona_data.style_rules:
			block += "- " + rule + "\n"
		block += "\n"
	
	if persona_data.has("voice_characteristics"):
		block += "Voice Characteristics:\n"
		for characteristic in persona_data.voice_characteristics:
			block += "- " + characteristic + "\n"
		block += "\n"
	
	if persona_data.has("few_shot_examples"):
		block += "Example Responses:\n"
		for example in persona_data.few_shot_examples:
			block += example + "\n\n"
	
	return block

# NEW: Enhanced system prompt building with persona caching
func _build_system_prompt(context: Dictionary) -> String:
	"""Build enhanced system prompt with persona caching"""
	var prompt = ""
	
	# Add persona block if available
	if context.has("agent_persona"):
		prompt += get_cached_persona_block(context.get("agent_id", "unknown"), context.agent_persona)
		prompt += "\n\n"
	
	# Add base system instructions
	prompt += """You are an NPC in an autonomous world simulation. Respond with valid JSON in this exact format:

{
  "utterance": "The actual spoken dialogue",
  "intent": "continue|change_topic|ask_question|exit|...",
  "summary_note": "Brief note about the conversation",
  "relationship_effects": [{"target": "npc_id", "delta": 0.1, "tag": "reason"}],
  "mood_shift": {"valence": 1, "arousal": 0}
}

Context: """ + str(context) + """

Keep responses natural and contextually appropriate."""
	
	return prompt

# NEW: Get model performance statistics
func get_model_performance() -> Dictionary:
	"""Get current performance metrics for model selection"""
	return model_performance.duplicate()

# NEW: Set cloud API key
func set_cloud_api_key(key: String):
	"""Set OpenAI API key for cloud inference"""
	cloud_api_key = key
	print("[LLMClient] Cloud API key configured")

# NEW: Toggle hybrid inference
func set_hybrid_inference(enabled: bool):
	"""Enable or disable hybrid inference"""
	use_hybrid_inference = enabled
	print("[LLMClient] Hybrid inference ", "enabled" if enabled else "disabled")

# NEW: Toggle streaming
func set_streaming_enabled(enabled: bool):
	"""Enable or disable streaming responses"""
	streaming_enabled = enabled
	print("[LLMClient] Streaming ", "enabled" if enabled else "disabled")

func check_health():
	# Don't run health check if one is already in progress
	if pending_requests.has("health_check"):
		print("[LLMClient] Health check already in progress, skipping...")
		return
	
	# Simple health check - try to connect to LM Studio
	var test_request = {
		"model": "TheBloke/OpenHermes-2.5-Mistral-7B-GGUF",
		"messages": [{"role": "user", "content": "Hello"}],
		"temperature": 0.1,
		"max_tokens": 10
	}
	
	var headers = ["Content-Type: application/json"]
	var json_string = JSON.stringify(test_request)
	
	# Store health check request with special ID
	var health_request_id = "health_check"
	pending_requests[health_request_id] = {
		"data": test_request,
		"context": {},
		"retry_count": 0,
		"timestamp": Time.get_time_dict_from_system(),
		"is_health_check": true
	}
	
	var result = http_client.request(lm_studio_url + "/v1/chat/completions", headers, HTTPClient.METHOD_POST, json_string)
	
	if result != OK:
		print("[LLMClient] Health check request failed to send: ", result)
		_set_health_status(false)
		# Clean up failed health check
		pending_requests.erase(health_request_id)
		return
	
	# Set a timeout for health check
	var timer = get_tree().create_timer(5.0)
	timer.timeout.connect(func(): 
		if not is_healthy:
			_set_health_status(false)
			# Clean up health check request
			if pending_requests.has(health_request_id):
				pending_requests.erase(health_request_id)
	)

func _set_health_status(healthy: bool):
	if is_healthy != healthy:
		is_healthy = healthy
		llm_health_changed.emit(is_healthy)
		print("[LLMClient] Health status changed: ", "Healthy" if is_healthy else "Unhealthy")

func send_request(prompt: String, context: Dictionary, temperature: float = 0.7) -> String:
	"""Legacy method for backward compatibility - use generate_async instead"""
	var enhanced_context = context.duplicate()
	enhanced_context["prompt"] = prompt
	enhanced_context["temperature"] = temperature
	enhanced_context["stream"] = false
	
	return generate_async(enhanced_context, func(response): pass)

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	if result != HTTPRequest.RESULT_SUCCESS:
		_handle_request_error("", "HTTP request failed: " + str(result))
		return
	
	if response_code != 200:
		_handle_request_error("", "HTTP response error: " + str(response_code))
		return
	
	# Parse response
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	
	if parse_result != OK:
		_handle_request_error("", "Failed to parse JSON response")
		return
	
	var response_data = json.data
	
	# Find the corresponding request
	var request_id = _find_request_by_response(response_data)
	if request_id.is_empty():
		print("[LLMClient] Could not find request for response")
		return
	
	# Process the response
	_process_llm_response(request_id, response_data)

func _find_request_by_response(_response_data: Dictionary) -> String:
	# This is a simplified approach - in a real implementation,
	# you'd want to track request-response mapping more carefully
	for request_id in pending_requests.keys():
		return request_id  # Return first pending request for now
	return ""

func _parse_llm_response(content: String) -> Dictionary:
	# Try to extract JSON from the response
	var json_start = content.find("{")
	var json_end = content.rfind("}")
	
	if json_start == -1 or json_end == -1:
		return {}
	
	var json_string = content.substr(json_start, json_end - json_start + 1)
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		return {}
	
	var parsed = json.data
	
	# Validate required fields
	var required_fields = ["utterance", "intent", "summary_note", "relationship_effects", "mood_shift"]
	for field in required_fields:
		if not parsed.has(field):
			print("[LLMClient] Missing required field in response: ", field)
			return {}
	
	return parsed

func _handle_fallback_response(request_id: String, original_request: Dictionary):
	var fallback_response = _generate_fallback_response(original_request)
	llm_response_received.emit(request_id, fallback_response)
	pending_requests.erase(request_id)

func _generate_fallback_response(original_request: Dictionary) -> Dictionary:
	# Generate a simple fallback response when LLM is unavailable
	var _context = original_request.get("context", {})
	
	return {
		"utterance": "I'm not feeling very talkative right now.",
		"intent": "continue",
		"summary_note": "NPC gave a brief response due to system limitations.",
		"relationship_effects": [],
		"mood_shift": {"valence": 0, "arousal": 0}
	}

func _handle_request_error(request_id: String, error: String):
	if request_id.is_empty():
		print("[LLMClient] Request error: ", error)
		return
	
	# Emit signal for error handling
	llm_request_failed.emit(request_id, error)
	
	var request_info = pending_requests.get(request_id)
	if not request_info:
		return
	
	# Retry logic
	if request_info.retry_count < max_retries:
		request_info.retry_count += 1
		print("[LLMClient] Retrying request ", request_id, " (attempt ", request_info.retry_count, ")")
		
		# Wait before retry
		var timer = get_tree().create_timer(retry_delay * request_info.retry_count)
		timer.timeout.connect(func(): _send_http_request(request_id, request_info.data))
	else:
		# Max retries reached, use fallback
		print("[LLMClient] Max retries reached for request ", request_id, ", using fallback")
		_handle_fallback_response(request_id, request_info.data)

# Utility functions
func is_available() -> bool:
	return is_healthy

func get_pending_request_count() -> int:
	return pending_requests.size()

func cancel_request(request_id: String) -> bool:
	if pending_requests.has(request_id):
		pending_requests.erase(request_id)
		return true
	return false

func clear_pending_requests():
	pending_requests.clear()
