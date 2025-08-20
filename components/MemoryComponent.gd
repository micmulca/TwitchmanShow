extends Node
class_name MemoryComponent

# Memory Component - Core memory management system for characters
# Handles memory creation, storage, retrieval, decay, and emotional impact
# Integrates with StatusComponent, ActionExecutor, and ConversationController

signal memory_created(memory_data: Dictionary)
signal memory_recalled(memory_id: String, character_id: String)
signal memory_decayed(memory_id: String, character_id: String, new_strength: float)
signal memory_deleted(memory_id: String, character_id: String)

# Memory storage
var memories: Dictionary = {}
var memory_counter: int = 0

# Memory configuration
var max_memories: int = 1000
var decay_interval: float = 1.0  # Decay check every second
var decay_timer: Timer

# Memory types
enum MemoryType {
	EPISODIC,    # Specific events with time, place, participants
	SEMANTIC,    # General knowledge, facts, learned information
	EMOTIONAL,   # Feelings, moods, emotional states
	RELATIONSHIP # Social bonds, trust, conflicts, alliances
}

# Memory strength categories
enum MemoryStrength {
	VERY_WEAK = 0,    # 0.0 - 0.2
	WEAK = 1,         # 0.2 - 0.4
	MODERATE = 2,     # 0.4 - 0.6
	STRONG = 3,       # 0.6 - 0.8
	VERY_STRONG = 4   # 0.8 - 1.0
}

# Decay rates (per second)
var decay_rates: Dictionary = {
	MemoryStrength.VERY_WEAK: 0.0005,    # Very fast decay
	MemoryStrength.WEAK: 0.0002,         # Fast decay
	MemoryStrength.MODERATE: 0.0001,     # Medium decay
	MemoryStrength.STRONG: 0.00005,      # Slow decay
	MemoryStrength.VERY_STRONG: 0.00002  # Very slow decay
}

# Dependencies
var status_component: StatusComponent
var character_id: String = ""

func _ready():
	# Initialize decay timer
	decay_timer = Timer.new()
	decay_timer.wait_time = decay_interval
	decay_timer.timeout.connect(_on_decay_timer_timeout)
	decay_timer.autostart = true
	add_child(decay_timer)

func initialize(character_identifier: String, status_comp: StatusComponent):
	character_id = character_identifier
	status_component = status_comp
	print("✅ MemoryComponent initialized for character: " + character_id)

# Memory Creation Methods

func create_memory(memory_data: Dictionary) -> Dictionary:
	"""Create a new memory with the given data"""
	if memories.size() >= max_memories:
		_cleanup_old_memories()
	
	var memory_id = "memory_" + str(memory_counter)
	memory_counter += 1
	
	# Set default values
	var memory = {
		"memory_id": memory_id,
		"character_id": character_id,
		"memory_type": memory_data.get("memory_type", MemoryType.EPISODIC),
		"title": memory_data.get("title", "Untitled Memory"),
		"description": memory_data.get("description", ""),
		"participants": memory_data.get("participants", []),
		"location": memory_data.get("location", ""),
		"timestamp": Time.get_time_dict_from_system()["unix"],
		"last_recalled": Time.get_time_dict_from_system()["unix"],
		"strength": memory_data.get("strength", 0.8),
		"decay_rate": _calculate_decay_rate(memory_data.get("strength", 0.8)),
		"is_permanent": memory_data.get("is_permanent", false),
		"tags": memory_data.get("tags", []),
		"emotional_impact": memory_data.get("emotional_impact", {}),
		"relationship_changes": memory_data.get("relationship_changes", {}),
		"economic_impact": memory_data.get("economic_impact", 0),
		"social_significance": memory_data.get("social_significance", 0.0),
		"source_type": memory_data.get("source_type", "manual"),  # action, conversation, environmental
		"source_id": memory_data.get("source_id", "")
	}
	
	memories[memory_id] = memory
	
	# Apply emotional impact to character
	_apply_emotional_impact(memory)
	
	# Emit signal
	memory_created.emit(memory)
	
	print("✅ Memory created: " + memory["title"] + " (ID: " + memory_id + ")")
	return memory

func create_action_memory(action_data: Dictionary, action_result: Dictionary, participants: Array = []) -> Dictionary:
	"""Create a comprehensive memory from an action result"""
	var memory_data = {
		"memory_type": MemoryType.EPISODIC,
		"title": "Action: " + action_data.get("name", "Unknown Action"),
		"description": _generate_action_memory_description(action_data, action_result),
		"participants": participants,
		"location": action_data.get("location_tags", [""])[0] if action_data.get("location_tags", []).size() > 0 else "",
		"strength": _calculate_action_memory_strength(action_result),
		"tags": _generate_action_memory_tags(action_data, action_result),
		"emotional_impact": _calculate_action_emotional_impact(action_result),
		"relationship_changes": {},
		"economic_impact": action_result.get("wealth_change", 0),
		"social_significance": _calculate_action_social_significance(action_data, action_result),
		"source_type": "action",
		"source_id": action_data.get("id", ""),
		
		# Enhanced action-specific data
		"action_outcome": action_result.get("result_type", "average"),
		"action_quality": action_result.get("quality", "standard"),
		"need_satisfaction": action_result.get("needs_satisfied", {}),
		"failure_reason": action_result.get("failure_reason", ""),
		"interruption_progress": action_result.get("interruption_progress", 0.0),
		"action_duration": action_data.get("duration", 1.0),
		"action_category": action_data.get("category", "General"),
		"action_difficulty": action_data.get("difficulty", 1.0)
	}
	
	return create_memory(memory_data)

func create_action_failure_memory(action_data: Dictionary, failure_data: Dictionary, participants: Array = []) -> Dictionary:
	"""Create a memory specifically for action failures"""
	var memory_data = {
		"memory_type": MemoryType.EPISODIC,
		"title": "Failed Action: " + action_data.get("name", "Unknown Action"),
		"description": _generate_failure_memory_description(action_data, failure_data),
		"participants": participants,
		"location": action_data.get("location_tags", [""])[0] if action_data.get("location_tags", []).size() > 0 else "",
		"strength": _calculate_failure_memory_strength(failure_data),
		"tags": _generate_failure_memory_tags(action_data, failure_data),
		"emotional_impact": _calculate_failure_emotional_impact(failure_data),
		"relationship_changes": {},
		"economic_impact": failure_data.get("economic_penalty", 0),
		"social_significance": _calculate_failure_social_significance(action_data, failure_data),
		"source_type": "action_failure",
		"source_id": action_data.get("id", ""),
		
		# Failure-specific data
		"failure_type": failure_data.get("failure_type", "general"),
		"failure_reason": failure_data.get("reason", "Unknown failure"),
		"failure_severity": failure_data.get("severity", "minor"),
		"need_penalties": failure_data.get("need_penalties", {}),
		"recovery_suggestions": failure_data.get("recovery_suggestions", [])
	}
	
	return create_memory(memory_data)

func create_action_pattern_memory(action_data: Dictionary, pattern_data: Dictionary) -> Dictionary:
	"""Create a memory for learning action patterns and strategies"""
	var memory_data = {
		"memory_type": MemoryType.SEMANTIC,
		"title": "Action Strategy: " + action_data.get("name", "Unknown Action"),
		"description": _generate_pattern_memory_description(action_data, pattern_data),
		"participants": [character_id],  # Self-learning
		"location": action_data.get("location_tags", [""])[0] if action_data.get("location_tags", []).size() > 0 else "",
		"strength": _calculate_pattern_memory_strength(pattern_data),
		"tags": _generate_pattern_memory_tags(action_data, pattern_data),
		"emotional_impact": {"confidence": 0.2, "satisfaction": 0.1},
		"relationship_changes": {},
		"economic_impact": 0,
		"social_significance": 0.1,
		"source_type": "action_pattern",
		"source_id": action_data.get("id", ""),
		
		# Pattern-specific data
		"pattern_type": pattern_data.get("pattern_type", "efficiency"),
		"success_rate": pattern_data.get("success_rate", 0.0),
		"optimal_conditions": pattern_data.get("optimal_conditions", []),
		"avoid_conditions": pattern_data.get("avoid_conditions", []),
		"need_balance": pattern_data.get("need_balance", {}),
		"time_of_day_preference": pattern_data.get("time_of_day_preference", ""),
		"seasonal_effectiveness": pattern_data.get("seasonal_effectiveness", {})
	}
	
	return create_memory(memory_data)

func create_conversation_memory(conversation_data: Dictionary, participants: Array, topics: Array, emotional_tone: String) -> Dictionary:
	"""Create a memory from a conversation"""
	var memory_data = {
		"memory_type": MemoryType.RELATIONSHIP,
		"title": "Conversation: " + topics[0] if topics.size() > 0 else "Conversation",
		"description": _generate_conversation_memory_description(conversation_data, topics, emotional_tone),
		"participants": participants,
		"location": conversation_data.get("location", ""),
		"strength": _calculate_conversation_memory_strength(emotional_tone, participants.size()),
		"tags": _generate_conversation_memory_tags(topics, emotional_tone),
		"emotional_impact": _calculate_conversation_emotional_impact(emotional_tone),
		"relationship_changes": _calculate_conversation_relationship_changes(participants, emotional_tone),
		"economic_impact": 0,
		"social_significance": _calculate_conversation_social_significance(participants.size(), topics),
		"source_type": "conversation",
		"source_id": conversation_data.get("conversation_id", "")
	}
	
	return create_memory(memory_data)

# Memory Retrieval Methods

func get_memories(filter_criteria: Dictionary = {}) -> Array:
	"""Get memories based on filter criteria"""
	var filtered_memories = []
	
	for memory_id in memories:
		var memory = memories[memory_id]
		if _matches_filter(memory, filter_criteria):
			filtered_memories.append(memory)
	
	# Sort by strength (strongest first)
	filtered_memories.sort_custom(func(a, b): return a["strength"] > b["strength"])
	
	return filtered_memories

func get_memory_by_id(memory_id: String) -> Dictionary:
	"""Get a specific memory by ID"""
	return memories.get(memory_id, {})

func get_recent_memories(count: int = 10) -> Array:
	"""Get the most recent memories"""
	var sorted_memories = []
	for memory_id in memories:
		sorted_memories.append(memories[memory_id])
	
	sorted_memories.sort_custom(func(a, b): return a["timestamp"] > b["timestamp"])
	return sorted_memories.slice(0, count)

func get_memories_by_participant(participant_id: String) -> Array:
	"""Get memories involving a specific participant"""
	return get_memories({"participants": participant_id})

func get_memories_by_location(location_id: String) -> Array:
	"""Get memories from a specific location"""
	return get_memories({"location": location_id})

func get_memories_by_tag(tag: String) -> Array:
	"""Get memories with a specific tag"""
	return get_memories({"tags": tag})

# Enhanced Action Memory Retrieval Methods

func get_action_memories(action_id: String = "", outcome_filter: String = "") -> Array:
	"""Get memories related to specific actions or outcomes"""
	var filter_criteria = {"source_type": "action"}
	
	if action_id != "":
		filter_criteria["source_id"] = action_id
	
	if outcome_filter != "":
		filter_criteria["action_outcome"] = outcome_filter
	
	return get_memories(filter_criteria)

func get_failure_memories(action_category: String = "") -> Array:
	"""Get memories of action failures for learning"""
	var filter_criteria = {"source_type": "action_failure"}
	
	if action_category != "":
		filter_criteria["action_category"] = action_category
	
	return get_memories(filter_criteria)

func get_success_patterns(action_category: String = "") -> Array:
	"""Get successful action patterns for strategy learning"""
	var filter_criteria = {"source_type": "action_pattern"}
	
	if action_category != "":
		filter_criteria["action_category"] = action_category
	
	return get_memories(filter_criteria)

func get_memories_by_action_category(category: String) -> Array:
	"""Get all memories related to a specific action category"""
	var filter_criteria = {"action_category": category}
	return get_memories(filter_criteria)

func get_memories_by_outcome(outcome: String) -> Array:
	"""Get all memories with a specific action outcome"""
	var filter_criteria = {"action_outcome": outcome}
	return get_memories(filter_criteria)

func get_memories_by_failure_severity(severity: String) -> Array:
	"""Get failure memories by severity level"""
	var filter_criteria = {"failure_severity": severity}
	return get_memories(filter_criteria)

# Memory Recall and Reinforcement

func recall_memory(memory_id: String) -> Dictionary:
	"""Recall a memory, potentially strengthening it"""
	var memory = memories.get(memory_id, {})
	if memory.is_empty():
		return {"success": false, "message": "Memory not found"}
	
	# Update last recalled time
	memory["last_recalled"] = Time.get_time_dict_from_system()
	
	# Slight strength boost from recall (if not permanent)
	if not memory.get("is_permanent", false):
		var strength_boost = 0.01
		memory["strength"] = min(memory["strength"] + strength_boost, 1.0)
		memory["decay_rate"] = _calculate_decay_rate(memory["strength"])
	
	# Apply emotional impact
	_apply_emotional_impact(memory)
	
	# Emit signal
	memory_recalled.emit(memory_id, character_id)
	
	return {"success": true, "memory": memory}

# Memory Decay and Management

func _on_decay_timer_timeout():
	"""Process memory decay for all memories"""
	for memory_id in memories:
		var memory = memories[memory_id]
		if not memory.get("is_permanent", false):
			_decay_memory(memory_id)

func _decay_memory(memory_id: String):
	"""Decay a specific memory"""
	var memory = memories[memory_id]
	var decay_amount = memory["decay_rate"] * decay_interval
	
	memory["strength"] = max(memory["strength"] - decay_amount, 0.0)
	
	# Update decay rate based on new strength
	memory["decay_rate"] = _calculate_decay_rate(memory["strength"])
	
	# Emit decay signal
	memory_decayed.emit(memory_id, character_id, memory["strength"])
	
	# Remove very weak memories
	if memory["strength"] <= 0.05:
		delete_memory(memory_id)

func delete_memory(memory_id: String) -> bool:
	"""Delete a memory"""
	if memories.has(memory_id):
		var memory = memories[memory_id]
		memories.erase(memory_id)
		memory_deleted.emit(memory_id, character_id)
		print("🗑️ Memory deleted: " + memory["title"] + " (ID: " + memory_id + ")")
		return true
	return false

func _cleanup_old_memories():
	"""Remove old, weak memories when at capacity"""
	var sorted_memories = []
	for memory_id in memories:
		sorted_memories.append({"id": memory_id, "strength": memories[memory_id]["strength"]})
	
	sorted_memories.sort_custom(func(a, b): return a["strength"] < b["strength"])
	
	# Remove weakest 10% of memories
	var remove_count = max(1, memories.size() / 10)
	for i in range(remove_count):
		if i < sorted_memories.size():
			delete_memory(sorted_memories[i]["id"])

# Utility Methods

func _calculate_decay_rate(strength: float) -> float:
	"""Calculate decay rate based on memory strength"""
	if strength >= 0.8:
		return decay_rates[MemoryStrength.VERY_STRONG]
	elif strength >= 0.6:
		return decay_rates[MemoryStrength.STRONG]
	elif strength >= 0.4:
		return decay_rates[MemoryStrength.MODERATE]
	elif strength >= 0.2:
		return decay_rates[MemoryStrength.WEAK]
	else:
		return decay_rates[MemoryStrength.VERY_WEAK]

func _matches_filter(memory: Dictionary, filter_criteria: Dictionary) -> bool:
	"""Check if memory matches filter criteria"""
	for key in filter_criteria:
		var value = filter_criteria[key]
		if key == "participants" and value in memory.get("participants", []):
			continue
		elif key == "tags" and value in memory.get("tags", []):
			continue
		elif key == "location" and memory.get("location", "") == value:
			continue
		elif key == "memory_type" and memory.get("memory_type", -1) == value:
			continue
		elif key == "strength_min" and memory.get("strength", 0) >= value:
			continue
		elif key == "strength_max" and memory.get("strength", 0) <= value:
			continue
		else:
			return false
	return true

func _apply_emotional_impact(memory: Dictionary):
	"""Apply memory's emotional impact to character status"""
	if not status_component:
		return
	
	var emotional_impact = memory.get("emotional_impact", {})
	for emotion in emotional_impact:
		var impact_value = emotional_impact[emotion]
		# Convert emotion to need modification
		# This is a simplified mapping - could be more sophisticated
		match emotion:
			"happiness":
				status_component.modify_need("comfort", impact_value * 0.1)
			"trust":
				status_component.modify_need("security_need", impact_value * 0.1)
			"fear":
				status_component.modify_need("security_need", -impact_value * 0.1)
			"excitement":
				status_component.modify_need("curiosity", impact_value * 0.1)

# Action Memory Generation

func _generate_action_memory_description(action_data: Dictionary, action_result: Dictionary) -> String:
	"""Generate a description for an action-based memory"""
	var action_name = action_data.get("name", "an action")
	var result_type = action_result.get("result_type", "average")
	var quality = action_result.get("quality", "standard")
	
	var description = "Performed " + action_name + " with " + result_type + " results. "
	
	match result_type:
		"excellent":
			description += "The outcome was exceptional and highly satisfying."
		"good":
			description += "The outcome was good and met expectations."
		"average":
			description += "The outcome was satisfactory and adequate."
		"poor":
			description += "The outcome was disappointing but not disastrous."
		"failure":
			description += "The action failed completely and was frustrating."
	
	return description

func _calculate_action_memory_strength(action_result: Dictionary) -> float:
	"""Calculate memory strength for action memories"""
	var base_strength = 0.6
	
	# Result type affects strength
	var result_type = action_result.get("result_type", "average")
	match result_type:
		"excellent":
			base_strength += 0.3
		"good":
			base_strength += 0.2
		"average":
			base_strength += 0.0
		"poor":
			base_strength += 0.1
		"failure":
			base_strength += 0.2  # Failures are memorable
	
	# Quality affects strength
	var quality = action_result.get("quality", "standard")
	match quality:
		"exceptional":
			base_strength += 0.1
		"high":
			base_strength += 0.05
	
	return min(base_strength, 1.0)

func _generate_action_memory_tags(action_data: Dictionary, action_result: Dictionary) -> Array:
	"""Generate tags for action memories"""
	var tags = ["action", action_result.get("result_type", "average")]
	
	# Add action category tag
	var category = action_data.get("category", "General")
	tags.append("category_" + category.to_lower().replace(" ", "_"))
	
	# Add quality tag
	var quality = action_result.get("quality", "standard")
	tags.append("quality_" + quality.to_lower().replace(" ", "_"))
	
	# Add location tags
	var location_tags = action_data.get("location_tags", [])
	for location in location_tags:
		tags.append("location_" + location.to_lower().replace(" ", "_"))
	
	return tags

func _calculate_action_emotional_impact(action_result: Dictionary) -> Dictionary:
	"""Calculate emotional impact of action result"""
	var emotional_impact = {}
	
	var result_type = action_result.get("result_type", "average")
	match result_type:
		"excellent":
			emotional_impact = {"happiness": 0.4, "satisfaction": 0.3, "confidence": 0.2}
		"good":
			emotional_impact = {"happiness": 0.3, "satisfaction": 0.2}
		"average":
			emotional_impact = {"contentment": 0.1}
		"poor":
			emotional_impact = {"disappointment": 0.2, "frustration": 0.1}
		"failure":
			emotional_impact = {"frustration": 0.3, "disappointment": 0.2, "anger": 0.1}
	
	return emotional_impact

func _calculate_action_social_significance(action_data: Dictionary, action_result: Dictionary) -> float:
	"""Calculate social significance of action result"""
	var base_significance = 0.1
	
	# Increase significance for exceptional or poor results
	var result_type = action_result.get("result_type", "average")
	match result_type:
		"excellent":
			base_significance += 0.3
		"failure":
			base_significance += 0.2
	
	# Increase significance for social actions
	if action_data.get("category") == "Social":
		base_significance += 0.2
	
	return min(base_significance, 1.0)

# Action Failure Memory Generation

func _generate_failure_memory_description(action_data: Dictionary, failure_data: Dictionary) -> String:
	"""Generate a description for an action failure memory"""
	var action_name = action_data.get("name", "an action")
	var failure_reason = failure_data.get("reason", "unknown reasons")
	var severity = failure_data.get("severity", "minor")
	
	var description = "Failed to complete " + action_name + " due to " + failure_reason + ". "
	
	match severity:
		"minor":
			description += "The failure was minor and easily recoverable."
		"moderate":
			description += "The failure was significant but not catastrophic."
		"major":
			description += "The failure was major and had serious consequences."
		"catastrophic":
			description += "The failure was catastrophic and caused major setbacks."
	
	return description

func _calculate_failure_memory_strength(failure_data: Dictionary) -> float:
	"""Calculate memory strength for failure memories"""
	var base_strength = 0.7  # Failures are more memorable
	
	# Severity affects strength
	var severity = failure_data.get("severity", "minor")
	match severity:
		"minor":
			base_strength += 0.1
		"moderate":
			base_strength += 0.2
		"major":
			base_strength += 0.3
		"catastrophic":
			base_strength += 0.4
	
	return min(base_strength, 1.0)

func _generate_failure_memory_tags(action_data: Dictionary, failure_data: Dictionary) -> Array:
	"""Generate tags for failure memories"""
	var tags = ["action_failure", failure_data.get("failure_type", "general"), failure_data.get("severity", "minor")]
	
	# Add action category tag
	var category = action_data.get("category", "General")
	tags.append("category_" + category.to_lower().replace(" ", "_"))
	
	# Add failure type tag
	var failure_type = failure_data.get("failure_type", "general")
	tags.append("failure_" + failure_type.to_lower().replace(" ", "_"))
	
	return tags

func _calculate_failure_emotional_impact(failure_data: Dictionary) -> Dictionary:
	"""Calculate emotional impact of action failure"""
	var emotional_impact = {}
	
	var severity = failure_data.get("severity", "minor")
	match severity:
		"minor":
			emotional_impact = {"frustration": 0.2, "disappointment": 0.1}
		"moderate":
			emotional_impact = {"frustration": 0.3, "disappointment": 0.2, "worry": 0.1}
		"major":
			emotional_impact = {"frustration": 0.4, "disappointment": 0.3, "worry": 0.2, "anger": 0.1}
		"catastrophic":
			emotional_impact = {"frustration": 0.5, "disappointment": 0.4, "worry": 0.3, "anger": 0.2, "fear": 0.1}
	
	return emotional_impact

func _calculate_failure_social_significance(action_data: Dictionary, failure_data: Dictionary) -> float:
	"""Calculate social significance of action failure"""
	var base_significance = 0.2  # Failures have higher social impact
	
	# Severity affects significance
	var severity = failure_data.get("severity", "minor")
	match severity:
		"minor":
			base_significance += 0.1
		"moderate":
			base_significance += 0.2
		"major":
			base_significance += 0.3
		"catastrophic":
			base_significance += 0.4
	
	# Social actions have higher failure significance
	if action_data.get("category") == "Social":
		base_significance += 0.2
	
	return min(base_significance, 1.0)

# Action Pattern Memory Generation

func _generate_pattern_memory_description(action_data: Dictionary, pattern_data: Dictionary) -> String:
	"""Generate a description for an action pattern memory"""
	var action_name = action_data.get("name", "an action")
	var pattern_type = pattern_data.get("pattern_type", "efficiency")
	var success_rate = pattern_data.get("success_rate", 0.0)
	
	var description = "Learned " + pattern_type + " strategy for " + action_name + ". "
	
	if success_rate > 0.8:
		description += "This approach has proven highly effective."
	elif success_rate > 0.6:
		description += "This approach has proven effective."
	elif success_rate > 0.4:
		description += "This approach has mixed results."
	else:
		description += "This approach needs refinement."
	
	return description

func _calculate_pattern_memory_strength(pattern_data: Dictionary) -> float:
	"""Calculate memory strength for pattern memories"""
	var base_strength = 0.5
	
	# Success rate affects strength
	var success_rate = pattern_data.get("success_rate", 0.0)
	if success_rate > 0.8:
		base_strength += 0.3
	elif success_rate > 0.6:
		base_strength += 0.2
	elif success_rate > 0.4:
		base_strength += 0.1
	
	return min(base_strength, 1.0)

func _generate_pattern_memory_tags(action_data: Dictionary, pattern_data: Dictionary) -> Array:
	"""Generate tags for pattern memories"""
	var tags = ["action_pattern", pattern_data.get("pattern_type", "efficiency")]
	
	# Add action category tag
	var category = action_data.get("category", "General")
	tags.append("category_" + category.to_lower().replace(" ", "_"))
	
	# Add pattern type tag
	var pattern_type = pattern_data.get("pattern_type", "efficiency")
	tags.append("pattern_" + pattern_type.to_lower().replace(" ", "_"))
	
	# Add success rate tag
	var success_rate = pattern_data.get("success_rate", 0.0)
	if success_rate > 0.8:
		tags.append("high_success")
	elif success_rate > 0.6:
		tags.append("good_success")
	elif success_rate > 0.4:
		tags.append("mixed_success")
	else:
		tags.append("low_success")
	
	return tags

# Conversation Memory Generation

func _generate_conversation_memory_description(conversation_data: Dictionary, topics: Array, emotional_tone: String) -> String:
	"""Generate a description for a conversation-based memory"""
	var topic_text = topics[0] if topics.size() > 0 else "various topics"
	var tone_text = emotional_tone.replace("_", " ")
	
	return "Had a " + tone_text + " conversation about " + topic_text + ". The interaction was memorable and meaningful."

func _calculate_conversation_memory_strength(emotional_tone: String, participant_count: int) -> float:
	"""Calculate memory strength for conversation memories"""
	var base_strength = 0.6
	
	# Emotional tone affects strength
	match emotional_tone:
		"very_positive", "very_negative":
			base_strength += 0.2
		"positive", "negative":
			base_strength += 0.1
	
	# More participants = more significant
	if participant_count > 2:
		base_strength += 0.1
	
	return min(base_strength, 1.0)

func _generate_conversation_memory_tags(topics: Array, emotional_tone: String) -> Array:
	"""Generate tags for conversation memories"""
	var tags = ["conversation", emotional_tone]
	
	# Add topic tags
	for topic in topics:
		tags.append(topic.to_lower().replace(" ", "_"))
	
	return tags

func _calculate_conversation_emotional_impact(emotional_tone: String) -> Dictionary:
	"""Calculate emotional impact of conversation"""
	var emotional_impact = {}
	
	match emotional_tone:
		"very_positive":
			emotional_impact = {"happiness": 0.5, "trust": 0.3, "excitement": 0.2}
		"positive":
			emotional_impact = {"happiness": 0.3, "trust": 0.2}
		"neutral":
			emotional_impact = {"contentment": 0.1}
		"negative":
			emotional_impact = {"disappointment": 0.2, "fear": 0.1}
		"very_negative":
			emotional_impact = {"fear": 0.3, "disappointment": 0.3, "anger": 0.2}
	
	return emotional_impact

func _calculate_conversation_relationship_changes(participants: Array, emotional_tone: String) -> Dictionary:
	"""Calculate relationship changes from conversation"""
	var relationship_changes = {}
	
	# Apply relationship changes to all participants
	for participant in participants:
		if participant != character_id:
			var change_value = 0.0
			
			match emotional_tone:
				"very_positive":
					change_value = 0.3
				"positive":
					change_value = 0.2
				"neutral":
					change_value = 0.0
				"negative":
					change_value = -0.2
				"very_negative":
					change_value = -0.3
			
			relationship_changes[participant] = change_value
	
	return relationship_changes

func _calculate_conversation_social_significance(participant_count: int, topics: Array) -> float:
	"""Calculate social significance of conversation"""
	var base_significance = 0.2
	
	# More participants = more significant
	if participant_count > 2:
		base_significance += 0.2
	
	# Important topics increase significance
	var important_topics = ["family", "work", "relationships", "community", "crisis"]
	for topic in topics:
		if topic.to_lower() in important_topics:
			base_significance += 0.2
			break
	
	return min(base_significance, 1.0)

# Console Commands

func console_command(command: String, args: Array) -> Dictionary:
	match command:
		"create":
			if args.size() < 3:
				return {"success": false, "message": "Usage: create <type> <title> <description> [strength]"}
			
			var memory_type = MemoryType[args[0].to_upper()]
			var title = args[1]
			var description = args[2]
			var strength = float(args[3]) if args.size() > 3 else 0.8
			
			var memory_data = {
				"memory_type": memory_type,
				"title": title,
				"description": description,
				"strength": strength
			}
			
			var memory = create_memory(memory_data)
			return {"success": true, "memory": memory}
		
		"list":
			var filter_criteria = {}
			if args.size() > 0:
				filter_criteria["memory_type"] = MemoryType[args[0].to_upper()]
			
			var memory_list = get_memories(filter_criteria)
			return {"success": true, "memories": memory_list, "count": memory_list.size()}
		
		"recall":
			if args.size() < 1:
				return {"success": false, "message": "Usage: recall <memory_id>"}
			
			var result = recall_memory(args[0])
			return result
		
		"decay":
			if args.size() < 2:
				return {"success": false, "message": "Usage: decay <memory_id> <amount>"}
			
			var memory_id = args[0]
			var amount = float(args[1])
			
			var memory = memories.get(memory_id, {})
			if memory.is_empty():
				return {"success": false, "message": "Memory not found"}
			
			memory["strength"] = max(memory["strength"] - amount, 0.0)
			memory["decay_rate"] = _calculate_decay_rate(memory["strength"])
			
			return {"success": true, "memory": memory}
		
		"delete":
			if args.size() < 1:
				return {"success": false, "message": "Usage: delete <memory_id>"}
			
			var success = delete_memory(args[0])
			return {"success": success, "message": "Memory deleted" if success else "Memory not found"}
		
		# NEW: Enhanced action memory commands
		"action":
			if args.size() < 1:
				return {"success": false, "message": "Usage: action <command> [args...]"}
			
			var action_command = args[0]
			var action_args = args.slice(1)
			
			match action_command:
				"list":
					var action_id = action_args[0] if action_args.size() > 0 else ""
					var outcome = action_args[1] if action_args.size() > 1 else ""
					var memories = get_action_memories(action_id, outcome)
					return {"success": true, "memories": memories, "count": memories.size()}
				
				"failures":
					var category = action_args[0] if action_args.size() > 0 else ""
					var memories = get_failure_memories(category)
					return {"success": true, "failures": memories, "count": memories.size()}
				
				"patterns":
					var category = action_args[0] if action_args.size() > 0 else ""
					var memories = get_success_patterns(category)
					return {"success": true, "patterns": memories, "count": memories.size()}
				
				"category":
					if action_args.size() < 1:
						return {"success": false, "message": "Usage: action category <category_name>"}
					var memories = get_memories_by_action_category(action_args[0])
					return {"success": true, "memories": memories, "count": memories.size()}
				
				"outcome":
					if action_args.size() < 1:
						return {"success": false, "message": "Usage: action outcome <outcome_type>"}
					var memories = get_memories_by_outcome(action_args[0])
					return {"success": true, "memories": memories, "count": memories.size()}
				
				"severity":
					if action_args.size() < 1:
						return {"success": false, "message": "Usage: action severity <severity_level>"}
					var memories = get_memories_by_failure_severity(action_args[0])
					return {"success": true, "memories": memories, "count": memories.size()}
				
				_:
					return {"success": false, "message": "Unknown action command: " + action_command}
		
		"stats":
			var stats = {
				"total_memories": memories.size(),
				"memory_types": {},
				"strength_distribution": {},
				"oldest_memory": 0,
				"newest_memory": 0
			}
			
			for memory_id in memories:
				var memory = memories[memory_id]
				var type = MemoryType.keys()[memory["memory_type"]]
				var strength = memory["strength"]
				
				stats["memory_types"][type] = stats["memory_types"].get(type, 0) + 1
				
				if strength <= 0.2:
					stats["strength_distribution"]["very_weak"] = stats["strength_distribution"].get("very_weak", 0) + 1
				elif strength <= 0.4:
					stats["strength_distribution"]["weak"] = stats["strength_distribution"].get("weak", 0) + 1
				elif strength <= 0.6:
					stats["strength_distribution"]["moderate"] = stats["strength_distribution"].get("moderate", 0) + 1
				elif strength <= 0.8:
					stats["strength_distribution"]["strong"] = stats["strength_distribution"].get("strong", 0) + 1
				else:
					stats["strength_distribution"]["very_strong"] = stats["strength_distribution"].get("very_strong", 0) + 1
				
				if stats["oldest_memory"] == 0 or memory["timestamp"] < stats["oldest_memory"]:
					stats["oldest_memory"] = memory["timestamp"]
				if memory["timestamp"] > stats["newest_memory"]:
					stats["newest_memory"] = memory["timestamp"]
			
			return {"success": true, "stats": stats}
		
		_:
			return {"success": false, "message": "Unknown command: " + command}

# Save/Load Methods

func save_memories() -> Dictionary:
	"""Save all memories to a serializable format"""
	var save_data = {
		"memories": memories,
		"memory_counter": memory_counter
	}
	return save_data

func load_memories(save_data: Dictionary):
	"""Load memories from saved data"""
	if save_data.has("memories"):
		memories = save_data["memories"]
	if save_data.has("memory_counter"):
		memory_counter = save_data["memory_counter"]
	
	print("✅ Loaded " + str(memories.size()) + " memories for character: " + character_id)
