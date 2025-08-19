extends Node

# TopicManager - Handles topic switching, event injection, and topic relevance
# Maps world events to conversation topics and manages topic transitions

signal topic_suggested(group_id: String, topic: String, relevance: float, source: String)
signal topic_injected(group_id: String, topic: String, reason: String)
signal topic_decayed(topic: String, relevance: float)

# Topic management
var active_topics: Dictionary = {}  # topic -> relevance mapping
var topic_suggestions: Array[Dictionary] = []
var topic_cooldowns: Dictionary = {}  # topic -> last_used_time
var topic_blacklist: Array[String] = []  # Topics to avoid

# Event topic mappings
var event_topic_mappings: Dictionary = {}
var topic_decay_rates: Dictionary = {}

# Configuration
var max_active_topics: int = 10
var topic_suggestion_cooldown: float = 60.0  # Seconds between suggestions
var topic_relevance_threshold: float = 0.3   # Minimum relevance to suggest
var max_topic_duration: float = 600.0        # Maximum time a topic stays relevant

func _ready():
	# Load event topic mappings
	_load_event_topics()
	
	# Initialize default topics
	_initialize_default_topics()

func _load_event_topics():
	# Load event topic mappings from JSON file
	var file = FileAccess.open("res://data/dialogue/event_topics.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			event_topic_mappings = json.data
			print("[TopicManager] Loaded event topics: ", event_topic_mappings.size(), " mappings")
		else:
			print("[TopicManager] Failed to parse event topics JSON")
	else:
		print("[TopicManager] Event topics file not found, using defaults")
		_setup_default_event_topics()

func _setup_default_event_topics():
	# Default event topic mappings
	event_topic_mappings = {
		"weather": {
			"rain": ["weather", "mood", "activities"],
			"sunny": ["weather", "mood", "outdoor_activities"],
			"storm": ["weather", "safety", "indoor_activities"]
		},
		"economy": {
			"prosperity": ["business", "opportunities", "future_plans"],
			"recession": ["concerns", "budget", "community_support"]
		}
	}
	
	# Default decay rates
	topic_decay_rates = {
		"weather": 0.1,
		"economy": 0.05,
		"social": 0.08,
		"civic": 0.06,
		"personal": 0.12,
		"seasonal": 0.03
	}

func _initialize_default_topics():
	# Initialize with some default conversation topics
	var default_topics = [
		"general_chat",
		"community_news",
		"daily_life",
		"shared_interests",
		"weather",
		"local_events"
	]
	
	for topic in default_topics:
		active_topics[topic] = 0.5  # Medium relevance
		topic_cooldowns[topic] = 0.0

func process_world_event(event_type: String, event_data: Dictionary) -> Array[Dictionary]:
	# Process a world event and generate topic suggestions
	var suggestions = []
	
	if not event_topic_mappings.has(event_type):
		return suggestions
	
	var event_subtypes = event_topic_mappings[event_type]
	
	for subtype in event_subtypes.keys():
		if event_subtypes.has(subtype):
			var topics = event_subtypes[subtype]
			var relevance = _calculate_event_relevance(event_type, subtype, event_data)
			
			for topic in topics:
				if relevance > topic_relevance_threshold:
					suggestions.append({
						"topic": topic,
						"relevance": relevance,
						"source": "world_event",
						"event_type": event_type,
						"event_subtype": subtype,
						"event_data": event_data
					})
	
	# Add suggestions to active topics
	for suggestion in suggestions:
		_add_topic_suggestion(suggestion)
	
	return suggestions

func _calculate_event_relevance(event_type: String, subtype: String, event_data: Dictionary) -> float:
	# Calculate how relevant an event is for conversation topics
	var base_relevance = 0.5
	
	# Adjust based on event type
	match event_type:
		"weather":
			base_relevance = 0.8  # Weather is always relevant
		"economy":
			base_relevance = 0.7  # Economy affects everyone
		"social":
			base_relevance = 0.9  # Social events are highly relevant
		"civic":
			base_relevance = 0.6  # Civic events are moderately relevant
		"emergency":
			base_relevance = 1.0  # Emergencies are always relevant
		_:
			base_relevance = 0.5
	
	# Adjust based on event data
	if event_data.has("intensity"):
		var intensity = event_data.intensity
		if intensity == "high":
			base_relevance *= 1.2
		elif intensity == "low":
			base_relevance *= 0.8
	
	# Adjust based on time of day (some topics are more relevant at certain times)
	var current_hour = Time.get_time_dict_from_system().hour
	if event_type == "weather" and (current_hour < 6 or current_hour > 22):
		base_relevance *= 0.7  # Less relevant at night
	
	return clamp(base_relevance, 0.0, 1.0)

func _add_topic_suggestion(suggestion: Dictionary) -> void:
	# Add a topic suggestion to the active topics
	var topic = suggestion.topic
	var relevance = suggestion.relevance
	
	if active_topics.has(topic):
		# Update existing topic relevance
		active_topics[topic] = max(active_topics[topic], relevance)
	else:
		# Add new topic
		active_topics[topic] = relevance
	
	# Add to suggestions list
	topic_suggestions.append(suggestion)
	
	# Trim suggestions if too many
	if topic_suggestions.size() > max_active_topics * 2:
		topic_suggestions.pop_front()
	
	print("[TopicManager] Added topic suggestion: ", topic, " (relevance: ", relevance, ")")

func suggest_topics_for_group(group_id: String, current_topic: String = "", participant_count: int = 2) -> Array[Dictionary]:
	# Suggest relevant topics for a conversation group
	var suggestions = []
	var current_time = _get_current_time_seconds()
	
	for topic in active_topics.keys():
		# Skip current topic
		if topic == current_topic:
			continue
		
		# Check cooldown
		var last_used = topic_cooldowns.get(topic, 0.0)
		if current_time - last_used < topic_suggestion_cooldown:
			continue
		
		# Check if topic is blacklisted
		if topic in topic_blacklist:
			continue
		
		var relevance = active_topics[topic]
		
		# Adjust relevance based on group size
		relevance = _adjust_relevance_for_group_size(relevance, participant_count)
		
		# Adjust relevance based on current topic
		relevance = _adjust_relevance_for_topic_transition(relevance, current_topic, topic)
		
		if relevance > topic_relevance_threshold:
			suggestions.append({
				"topic": topic,
				"relevance": relevance,
				"source": "topic_manager",
				"group_id": group_id
			})
	
	# Sort by relevance
	suggestions.sort_custom(func(a, b): return a.relevance > b.relevance)
	
	# Limit suggestions
	if suggestions.size() > 5:
		suggestions = suggestions.slice(0, 5)
	
	return suggestions

func inject_topic(group_id: String, topic: String, reason: String = "external_injection") -> bool:
	# Inject a topic into a conversation (for console commands or system events)
	if topic in topic_blacklist:
		print("[TopicManager] Cannot inject blacklisted topic: ", topic)
		return false
	
	# Add to active topics with high relevance
	active_topics[topic] = 0.9
	
	# Emit signal
	topic_injected.emit(group_id, topic, reason)
	
	print("[TopicManager] Injected topic '", topic, "' into group ", group_id, " (", reason, ")")
	return true

func change_topic_for_group(group_id: String, new_topic: String, reason: String = "topic_change") -> bool:
	# Change the topic for a specific conversation group
	if new_topic in topic_blacklist:
		print("[TopicManager] Cannot change to blacklisted topic: ", topic)
		return false
	
	# Update topic cooldown
	topic_cooldowns[new_topic] = _get_current_time_seconds()
	
	# Emit signal
	topic_injected.emit(group_id, new_topic, reason)
	
	print("[TopicManager] Changed topic to '", new_topic, "' for group ", group_id, " (", reason, ")")
	return true

func _adjust_relevance_for_group_size(base_relevance: float, participant_count: int) -> float:
	# Adjust topic relevance based on group size
	var adjusted_relevance = base_relevance
	
	match participant_count:
		2:  # Duo conversations
			# Prefer personal topics
			if _is_personal_topic(base_relevance):
				adjusted_relevance *= 1.2
			else:
				adjusted_relevance *= 0.9
		3:  # Small group
			# Balanced relevance
			adjusted_relevance *= 1.0
		4:  # Medium group
			# Prefer general topics
			if _is_general_topic(base_relevance):
				adjusted_relevance *= 1.1
			else:
				adjusted_relevance *= 0.95
		_:  # Large group
			# Prefer broad, inclusive topics
			if _is_broad_topic(base_relevance):
				adjusted_relevance *= 1.15
			else:
				adjusted_relevance *= 0.9
	
	return clamp(adjusted_relevance, 0.0, 1.0)

func _adjust_relevance_for_topic_transition(base_relevance: float, current_topic: String, new_topic: String) -> float:
	# Adjust relevance based on how natural the topic transition would be
	if current_topic.is_empty():
		return base_relevance
	
	# Check if topics are related
	var relatedness = _calculate_topic_relatedness(current_topic, new_topic)
	
	if relatedness > 0.7:
		# Highly related topics get a boost
		base_relevance *= 1.2
	elif relatedness < 0.3:
		# Unrelated topics get a penalty
		base_relevance *= 0.8
	
	return clamp(base_relevance, 0.0, 1.0)

func _calculate_topic_relatedness(topic1: String, topic2: String) -> float:
	# Calculate how related two topics are
	var relatedness = 0.0
	
	# Check if topics share common words
	var words1 = topic1.split("_")
	var words2 = topic2.split("_")
	
	var common_words = 0
	for word in words1:
		if word in words2:
			common_words += 1
	
	if words1.size() > 0 and words2.size() > 0:
		relatedness = float(common_words) / max(words1.size(), words2.size())
	
	# Check predefined topic relationships
	var topic_relationships = {
		"weather": ["mood", "activities", "comfort"],
		"business": ["economy", "opportunities", "community"],
		"family": ["relationships", "personal", "support"],
		"community": ["social", "civic", "relationships"]
	}
	
	for category in topic_relationships.keys():
		if topic1 == category or topic2 == category:
			var related_topics = topic_relationships[category]
			if topic1 in related_topics or topic2 in related_topics:
				relatedness = max(relatedness, 0.6)
	
	return clamp(relatedness, 0.0, 1.0)

func _is_personal_topic(relevance: float) -> bool:
	# Check if a topic is personal in nature
	var personal_topics = ["family", "personal", "relationships", "health", "goals"]
	# This is a simplified check - in a real system, you'd have topic metadata
	return relevance > 0.7  # Assume high relevance topics are more personal

func _is_general_topic(relevance: float) -> bool:
	# Check if a topic is general in nature
	var general_topics = ["weather", "community", "news", "events"]
	# Simplified check
	return relevance < 0.8  # Assume moderate relevance topics are more general

func _is_broad_topic(relevance: float) -> bool:
	# Check if a topic is broad and inclusive
	var broad_topics = ["community", "culture", "traditions", "general_chat"]
	# Simplified check
	return relevance < 0.9  # Assume lower relevance topics are broader

func update_topic_relevance(topic: String, new_relevance: float) -> void:
	# Update the relevance of a topic
	if active_topics.has(topic):
		active_topics[topic] = clamp(new_relevance, 0.0, 1.0)
		print("[TopicManager] Updated topic '", topic, "' relevance to ", new_relevance)

func decay_topics(delta_time: float) -> void:
	# Decay topic relevance over time
	var current_time = _get_current_time_seconds()
	var topics_to_remove = []
	
	for topic in active_topics.keys():
		var relevance = active_topics[topic]
		var decay_rate = topic_decay_rates.get(_get_topic_category(topic), 0.1)
		
		# Apply decay
		var new_relevance = relevance - (decay_rate * delta_time)
		
		if new_relevance <= 0.0:
			topics_to_remove.append(topic)
			topic_decayed.emit(topic, 0.0)
		else:
			active_topics[topic] = new_relevance
			if new_relevance < topic_relevance_threshold:
				topic_decayed.emit(topic, new_relevance)
	
	# Remove decayed topics
	for topic in topics_to_remove:
		active_topics.erase(topic)
		topic_cooldowns.erase(topic)

func _get_topic_category(topic: String) -> String:
	# Get the category of a topic for decay rate lookup
	for category in topic_decay_rates.keys():
		if topic.begins_with(category) or topic in topic_decay_rates[category]:
			return category
	return "general"

func blacklist_topic(topic: String, reason: String = "inappropriate") -> void:
	# Add a topic to the blacklist
	if topic not in topic_blacklist:
		topic_blacklist.append(topic)
		active_topics.erase(topic)
		print("[TopicManager] Blacklisted topic '", topic, "' (", reason, ")")

func unblacklist_topic(topic: String) -> void:
	# Remove a topic from the blacklist
	if topic in topic_blacklist:
		topic_blacklist.erase(topic)
		print("[TopicManager] Unblacklisted topic '", topic, "'")

func get_topic_stats() -> Dictionary:
	# Get statistics about topic management
	return {
		"active_topics": active_topics.size(),
		"topic_suggestions": topic_suggestions.size(),
		"blacklisted_topics": topic_blacklist.size(),
		"max_active_topics": max_active_topics,
		"relevance_threshold": topic_relevance_threshold
	}

func get_active_topics() -> Dictionary:
	return active_topics.duplicate()

func get_topic_suggestions() -> Array[Dictionary]:
	return topic_suggestions.duplicate()

func get_blacklisted_topics() -> Array[String]:
	return topic_blacklist.duplicate()


# Helper function to get current time in seconds
func _get_current_time_seconds() -> float:
	var time_dict = Time.get_time_dict_from_system()
	return time_dict.hour * 3600 + time_dict.minute * 60 + time_dict.second
