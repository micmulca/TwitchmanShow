extends Node

# ContextPacker - Builds JSON context per turn for LLM requests
# Includes persona, mood, health, relationships, recent topics, goals, location, and event hints

# Context structure for LLM requests
var context_schema: Dictionary = {
	"persona": {},
	"mood": {},
	"health": {},
	"relationships": {},
	"recent_topics": [],
	"goals": [],
	"location": {},
	"event_hints": [],
	"conversation_context": {},
	"world_state": {}
}

# Event topic mappings for conversation hooks
var event_topics: Dictionary = {}
var event_decay_rates: Dictionary = {}

func _ready():
	# Load event topic mappings
	_load_event_topics()

func _load_event_topics():
	# Load event topics from JSON file
	var file = FileAccess.open("res://data/dialogue/event_topics.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			event_topics = json.data
			print("[ContextPacker] Loaded event topics: ", event_topics.size(), " mappings")
		else:
			print("[ContextPacker] Failed to parse event topics JSON")
	else:
		print("[ContextPacker] Event topics file not found, using defaults")
		_setup_default_event_topics()

func _setup_default_event_topics():
	# Default event topic mappings
	event_topics = {
		"weather": {
			"rain": ["weather", "mood", "activities"],
			"sunny": ["weather", "mood", "outdoor_activities"],
			"storm": ["weather", "safety", "indoor_activities"]
		},
		"economy": {
			"prosperity": ["business", "opportunities", "future_plans"],
			"recession": ["concerns", "budget", "community_support"]
		},
		"social": {
			"festival": ["celebration", "community", "traditions"],
			"gossip": ["relationships", "news", "social_dynamics"]
		}
	}
	
	# Default decay rates (events lose relevance over time)
	event_decay_rates = {
		"weather": 0.1,      # Weather changes quickly
		"economy": 0.05,     # Economic changes are slower
		"social": 0.08       # Social events moderate decay
	}

func build_context_for_npc(npc_id: String, target_ids: Array = [], conversation_id: String = "") -> Dictionary:
	# Build comprehensive context for an NPC's LLM request
	var context = context_schema.duplicate(true)
	
	# Get NPC data from EventBus or NPC system
	var npc_data = _get_npc_data(npc_id)
	if npc_data.is_empty():
		print("[ContextPacker] No data found for NPC: ", npc_id)
		return context
	
	# Fill in context fields
	context.persona = _build_persona_context(npc_data)
	context.mood = _build_mood_context(npc_data)
	context.health = _build_health_context(npc_data)
	context.relationships = _build_relationships_context(npc_id, target_ids)
	context.recent_topics = _get_recent_topics(npc_id, conversation_id)
	context.goals = _get_current_goals(npc_id)
	context.location = _get_location_context(npc_id)
	context.event_hints = _get_relevant_event_hints(npc_id)
	context.conversation_context = _get_conversation_context(conversation_id)
	context.world_state = _get_world_state()
	
	return context

func _build_persona_context(npc_data: Dictionary) -> Dictionary:
	# Build persona information for the NPC
	return {
		"name": npc_data.get("name", "Unknown"),
		"age": npc_data.get("age", 25),
		"occupation": npc_data.get("occupation", "Citizen"),
		"personality_traits": npc_data.get("personality_traits", []),
		"interests": npc_data.get("interests", []),
		"background": npc_data.get("background", ""),
		"speaking_style": npc_data.get("speaking_style", "neutral")
	}

func _build_mood_context(npc_data: Dictionary) -> Dictionary:
	# Build current mood information
	var mood = npc_data.get("mood", {})
	return {
		"valence": mood.get("valence", 0.0),      # -1.0 to 1.0 (negative to positive)
		"arousal": mood.get("arousal", 0.0),     # 0.0 to 1.0 (calm to excited)
		"energy": mood.get("energy", 0.5),       # 0.0 to 1.0 (tired to energetic)
		"stress": mood.get("stress", 0.0),       # 0.0 to 1.0 (relaxed to stressed)
		"description": _describe_mood(mood)
	}

func _describe_mood(mood: Dictionary) -> String:
	# Convert mood values to descriptive text
	var valence = mood.get("valence", 0.0)
	var arousal = mood.get("arousal", 0.0)
	var energy = mood.get("energy", 0.5)
	var stress = mood.get("stress", 0.0)
	
	var descriptions = []
	
	if valence > 0.5:
		descriptions.append("happy")
	elif valence < -0.5:
		descriptions.append("sad")
	
	if arousal > 0.7:
		descriptions.append("excited")
	elif arousal < 0.3:
		descriptions.append("calm")
	
	if energy > 0.7:
		descriptions.append("energetic")
	elif energy < 0.3:
		descriptions.append("tired")
	
	if stress > 0.7:
		descriptions.append("stressed")
	
	if descriptions.is_empty():
		descriptions.append("neutral")
	
	return ", ".join(descriptions)

func _build_health_context(npc_data: Dictionary) -> Dictionary:
	# Build health and physical state information
	var health = npc_data.get("health", {})
	return {
		"status": health.get("status", "healthy"),
		"energy": health.get("energy", 100.0),
		"hunger": health.get("hunger", 0.0),
		"thirst": health.get("thirst", 0.0),
		"comfort": health.get("comfort", 1.0)
	}

func _build_relationships_context(npc_id: String, target_ids: Array) -> Dictionary:
	# Build relationship information with conversation targets
	var relationships = {}
	
	for target_id in target_ids:
		var relationship = _get_relationship_data(npc_id, target_id)
		relationships[target_id] = {
			"strength": relationship.get("strength", 0.0),
			"trust": relationship.get("trust", 0.0),
			"familiarity": relationship.get("familiarity", 0.0),
			"relationship_type": relationship.get("type", "acquaintance"),
			"recent_interactions": relationship.get("recent_interactions", []),
			"shared_interests": relationship.get("shared_interests", [])
		}
	
	return relationships

func _get_recent_topics(npc_id: String, conversation_id: String) -> Array:
	# Get recent conversation topics for this NPC
	var recent_topics = []
	
	# Get conversation history from EventBus
	var event_history = EventBus.get_event_history(EventBus.EventCategory.CONVERSATION, 10)
	
	for event in event_history:
		var data = event.get("data", {})
		if data.has("participants") and npc_id in data.participants:
			if data.has("topic") and data.topic != "":
				recent_topics.append({
					"topic": data.topic,
					"timestamp": event.get("timestamp", {}),
					"participants": data.participants
				})
	
	# Limit to most recent topics
	if recent_topics.size() > 5:
		recent_topics = recent_topics.slice(-5)
	
	return recent_topics

func _get_current_goals(npc_id: String) -> Array:
	# Get current goals and motivations for the NPC
	# This would come from a goal system - for now, return defaults
	return [
		"maintain_social_connections",
		"fulfill_daily_routines",
		"explore_opportunities"
	]

func _get_location_context(npc_id: String) -> Dictionary:
	# Get current location and environmental context
	# This would come from the world system - for now, return defaults
	return {
		"name": "Town Square",
		"type": "public_space",
		"atmosphere": "busy",
		"nearby_objects": ["fountain", "benches", "market_stalls"],
		"time_of_day": "afternoon",
		"weather": "sunny"
	}

func _get_relevant_event_hints(npc_id: String) -> Array:
	# Get relevant world events that might influence conversation
	var relevant_events = []
	var world_events = EventBus.get_event_history(EventBus.EventCategory.WORLD_EVENT, 20)
	
	for event in world_events:
		var event_type = event.get("data", {}).get("type", "")
		var event_data = event.get("data", {}).get("data", {})
		
		if event_topics.has(event_type):
			var topics = event_topics[event_type]
			var decay_rate = event_decay_rates.get(event_type, 0.1)
			
			# Calculate relevance based on time and decay
			var time_since_event = _calculate_time_since(event.get("timestamp", {}))
			var relevance = max(0.0, 1.0 - (time_since_event * decay_rate))
			
			if relevance > 0.3:  # Only include relevant events
				relevant_events.append({
					"type": event_type,
					"data": event_data,
					"relevance": relevance,
					"suggested_topics": topics
				})
	
	return relevant_events

func _get_conversation_context(conversation_id: String) -> Dictionary:
	# Get current conversation context if this is part of an ongoing conversation
	if conversation_id.is_empty():
		return {}
	
	# This would come from ConversationController - for now, return basic info
	return {
		"conversation_id": conversation_id,
		"current_topic": "general_chat",
		"conversation_mood": "friendly",
		"participant_count": 2
	}

func _get_world_state() -> Dictionary:
	# Get current world state information
	return {
		"time": Time.get_time_dict_from_system(),
		"weather": "sunny",
		"season": "summer",
		"day_of_week": "Wednesday",
		"special_events": ["market_day", "community_gathering"]
	}

# Helper functions
func _get_npc_data(npc_id: String) -> Dictionary:
	# Get NPC data from the system
	# This would come from an NPC manager - for now, return mock data
	return {
		"name": npc_id.capitalize(),
		"age": 30,
		"occupation": "Merchant",
		"personality_traits": ["friendly", "curious", "helpful"],
		"interests": ["trade", "community", "stories"],
		"background": "Local merchant who knows everyone in town",
		"speaking_style": "warm",
		"mood": {
			"valence": 0.3,
			"arousal": 0.4,
			"energy": 0.7,
			"stress": 0.2
		},
		"health": {
			"status": "healthy",
			"energy": 85.0,
			"hunger": 0.3,
			"thirst": 0.1,
			"comfort": 0.9
		}
	}

func _get_relationship_data(npc_id: String, target_id: String) -> Dictionary:
	# Get relationship data between two NPCs
	# This would come from a relationship system - for now, return defaults
	return {
		"strength": 0.6,
		"trust": 0.7,
		"familiarity": 0.8,
		"type": "friend",
		"recent_interactions": ["greeting", "small_talk"],
		"shared_interests": ["community", "trade"]
	}

func _calculate_time_since(timestamp: Dictionary) -> float:
	# Calculate time since an event in minutes
	var current_time = Time.get_time_dict_from_system()
	
	# Simple time calculation - in a real system, you'd use proper time math
	var current_minutes = current_time.hour * 60 + current_time.minute
	var event_minutes = timestamp.get("hour", 0) * 60 + timestamp.get("minute", 0)
	
	return abs(current_minutes - event_minutes)

# Utility functions for external systems
func get_context_summary(context: Dictionary) -> String:
	# Create a human-readable summary of the context
	var summary = "Context for " + context.persona.get("name", "Unknown") + ":\n"
	summary += "- Mood: " + context.mood.get("description", "neutral") + "\n"
	summary += "- Location: " + context.location.get("name", "unknown") + "\n"
	summary += "- Recent topics: " + str(context.recent_topics.size()) + "\n"
	summary += "- Event hints: " + str(context.event_hints.size())
	
	return summary

func validate_context(context: Dictionary) -> bool:
	# Validate that a context has all required fields
	var required_fields = ["persona", "mood", "health", "relationships", "recent_topics", "goals", "location", "event_hints"]
	
	for field in required_fields:
		if not context.has(field):
			print("[ContextPacker] Missing required field: ", field)
			return false
	
	return true
