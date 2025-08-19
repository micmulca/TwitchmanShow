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
	"""Create a memory from an action result"""
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
		"source_id": action_data.get("id", "")
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
	var action_name = action_data.get("name", "Unknown Action")
	var result_type = action_result.get("result_type", "unknown")
	var quality = action_result.get("quality", "standard")
	
	match result_type:
		"excellent":
			return "Successfully completed " + action_name + " with exceptional results. The quality was " + quality + " and everything went perfectly."
		"good":
			return "Successfully completed " + action_name + " with good results. The quality was " + quality + " and the work was satisfying."
		"average":
			return "Completed " + action_name + " with average results. The quality was " + quality + " and the work was adequate."
		"poor":
			return "Struggled with " + action_name + " and got poor results. The quality was " + quality + " and the work was disappointing."
		"failure":
			return "Failed to complete " + action_name + " properly. The attempt resulted in " + quality + " and was a setback."
		_:
			return "Completed " + action_name + " with " + quality + " results."

func _calculate_action_memory_strength(action_result: Dictionary) -> float:
	"""Calculate memory strength based on action result"""
	var result_type = action_result.get("result_type", "average")
	var base_strength = 0.5
	
	match result_type:
		"excellent":
			return base_strength + 0.3
		"good":
			return base_strength + 0.2
		"average":
			return base_strength
		"poor":
			return base_strength + 0.1
		"failure":
			return base_strength + 0.2  # Failures are memorable
		_:
			return base_strength

func _generate_action_memory_tags(action_data: Dictionary, action_result: Dictionary) -> Array:
	"""Generate tags for action-based memories"""
	var tags = []
	
	# Add action category
	tags.append(action_data.get("category", "unknown").to_lower())
	
	# Add result type
	tags.append(action_result.get("result_type", "unknown"))
	
	# Add quality
	tags.append(action_result.get("quality", "standard"))
	
	# Add location if available
	if action_data.has("location_tags") and action_data["location_tags"].size() > 0:
		tags.append(action_data["location_tags"][0])
	
	return tags

func _calculate_action_emotional_impact(action_result: Dictionary) -> Dictionary:
	"""Calculate emotional impact of action result"""
	var result_type = action_result.get("result_type", "average")
	var emotional_impact = {}
	
	match result_type:
		"excellent":
			emotional_impact = {"happiness": 0.4, "excitement": 0.3, "achievement": 0.5}
		"good":
			emotional_impact = {"happiness": 0.3, "satisfaction": 0.4}
		"average":
			emotional_impact = {"contentment": 0.2}
		"poor":
			emotional_impact = {"disappointment": 0.3, "frustration": 0.2}
		"failure":
			emotional_impact = {"frustration": 0.4, "disappointment": 0.3, "fear": 0.2}
	
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
