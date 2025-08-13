extends Node

# LLMClient - Handles communication with LM Studio for dynamic dialogue generation
# Includes retry logic, timeouts, and fallback responses when LLM is unavailable

signal llm_response_received(request_id: String, response: Dictionary)
signal llm_request_failed(request_id: String, error: String)
signal llm_health_changed(is_healthy: bool)

# Configuration
var lm_studio_url: String = "http://localhost:1234"
var lm_studio_port: int = 1234
var request_timeout: float = 30.0
var max_retries: int = 3
var retry_delay: float = 1.0

# State
var is_healthy: bool = false
var pending_requests: Dictionary = {}
var request_counter: int = 0

# HTTP client for API calls
var http_client: HTTPRequest

func _ready():
	http_client = HTTPRequest.new()
	add_child(http_client)
	http_client.request_completed.connect(_on_request_completed)
	
	# Check health at startup
	check_health()

func check_health():
	# Simple health check - try to connect to LM Studio
	var test_request = {
		"model": "local-model",
		"messages": [{"role": "user", "content": "Hello"}],
		"temperature": 0.1,
		"max_tokens": 10
	}
	
	var headers = ["Content-Type: application/json"]
	var json_string = JSON.stringify(test_request)
	
	http_client.request(lm_studio_url + "/v1/chat/completions", headers, HTTPClient.METHOD_POST, json_string)
	
	# Set a timeout for health check
	var timer = get_tree().create_timer(5.0)
	timer.timeout.connect(func(): 
		if not is_healthy:
			_set_health_status(false)
	)

func _set_health_status(healthy: bool):
	if is_healthy != healthy:
		is_healthy = healthy
		llm_health_changed.emit(is_healthy)
		print("[LLMClient] Health status changed: ", "Healthy" if is_healthy else "Unhealthy")

func send_request(prompt: String, context: Dictionary, temperature: float = 0.7) -> String:
	var request_id = "req_" + str(request_counter)
	request_counter += 1
	
	# Build the request payload
	var request_data = {
		"model": "local-model",
		"messages": [
			{
				"role": "system",
				"content": _build_system_prompt(context)
			},
			{
				"role": "user",
				"content": prompt
			}
		],
		"temperature": temperature,
		"max_tokens": 500,
		"stream": false
	}
	
	# Store pending request
	pending_requests[request_id] = {
		"data": request_data,
		"context": context,
		"retry_count": 0,
		"timestamp": Time.get_time_dict_from_system()
	}
	
	# Send request
	_send_http_request(request_id, request_data)
	
	return request_id

func _send_http_request(request_id: String, request_data: Dictionary):
	if not is_healthy:
		# Use fallback if LLM is unhealthy
		_handle_fallback_response(request_id, request_data)
		return
	
	var headers = ["Content-Type: application/json"]
	var json_string = JSON.stringify(request_data)
	
	var result = http_client.request(lm_studio_url + "/v1/chat/completions", headers, HTTPClient.METHOD_POST, json_string)
	
	if result != OK:
		_handle_request_error(request_id, "Failed to send HTTP request: " + str(result))

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
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

func _find_request_by_response(response_data: Dictionary) -> String:
	# This is a simplified approach - in a real implementation,
	# you'd want to track request-response mapping more carefully
	for request_id in pending_requests.keys():
		return request_id  # Return first pending request for now
	return ""

func _process_llm_response(request_id: String, response_data: Dictionary):
	var request_info = pending_requests.get(request_id)
	if not request_info:
		return
	
	# Extract the response content
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
		pending_requests.erase(request_id)
	else:
		# Invalid response, use fallback
		_handle_fallback_response(request_id, request_info.data)

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
	var context = original_request.get("context", {})
	
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

func _build_system_prompt(context: Dictionary) -> String:
	# Build a system prompt based on the context
	var prompt = """You are an NPC in an autonomous world simulation. Respond with valid JSON in this exact format:

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
