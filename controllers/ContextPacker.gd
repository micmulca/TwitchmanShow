extends Node

# ContextPacker - Builds JSON context per turn for LLM requests
# Enhanced for Phase 3: Integrates with Agent system, MemoryStore, RelationshipGraph, and EnvironmentalSensor
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
	"world_state": {},
	"memory_context": {},
	"action_context": {}
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
	
	# Get NPC data from Agent system
	var npc_data = _get_npc_data(npc_id)
	if npc_data.is_empty():
		print("[ContextPacker] No data found for NPC: ", npc_id)
		return context
	
	# Fill in context fields
	context.persona = _build_persona_context(npc_id, npc_data)
	context.mood = _build_mood_context(npc_id, npc_data)
	context.health = _build_health_context(npc_id, npc_data)
	context.relationships = _build_relationships_context(npc_id, target_ids)
	context.recent_topics = _get_recent_topics(npc_id, conversation_id)
	context.goals = _get_current_goals(npc_id)
	context.location = _get_location_context(npc_id)
	context.event_hints = _get_relevant_event_hints(npc_id)
	context.conversation_context = _get_conversation_context(conversation_id)
	context.world_state = _get_world_state()
	context.memory_context = _build_memory_context(npc_id, target_ids)
	context.action_context = _build_action_context(npc_id)
	
	return context

func _build_persona_context(npc_id: String, npc_data: Dictionary) -> Dictionary:
	# Build persona information for the NPC using Agent system
	var agent = Agent.get_agent(npc_id)
	if agent:
		return {
			"name": agent.persona.get("name", npc_id.capitalize()),
			"age": agent.persona.get("age", 25),
			"occupation": agent.persona.get("occupation", "Citizen"),
			"personality_traits": agent.persona.get("personality_traits", []),
			"interests": agent.persona.get("interests", []),
			"background": agent.persona.get("background", ""),
			"speaking_style": agent.persona.get("speaking_style", "neutral"),
			"persona_prompt": agent.persona.get("system_prompt", ""),
			"style_rules": agent.persona.get("style_rules", []),
			"few_shot_examples": agent.persona.get("few_shot_examples", [])
		}
	
	# Fallback to basic data
	return {
		"name": npc_data.get("name", npc_id.capitalize()),
		"age": npc_data.get("age", 25),
		"occupation": npc_data.get("occupation", "Citizen"),
		"personality_traits": npc_data.get("personality_traits", []),
		"interests": npc_data.get("interests", []),
		"background": npc_data.get("background", ""),
		"speaking_style": npc_data.get("speaking_style", "neutral")
	}

func _build_mood_context(npc_id: String, npc_data: Dictionary) -> Dictionary:
	# Build current mood information using Agent system
	var agent = Agent.get_agent(npc_id)
	if agent:
		var mood = agent.get_current_mood()
		return {
			"valence": mood.get("valence", 0.0),      # -1.0 to 1.0 (negative to positive)
			"arousal": mood.get("arousal", 0.0),     # 0.0 to 1.0 (calm to excited)
			"energy": mood.get("energy", 0.5),       # 0.0 to 1.0 (tired to energetic)
			"stress": mood.get("stress", 0.0),       # 0.0 to 1.0 (relaxed to stressed)
			"description": _describe_mood(mood),
			"mood_stability": agent.get_mood_stability(),
			"recent_mood_changes": agent.get_recent_mood_changes()
		}
	
	# Fallback to basic mood data
	var mood = npc_data.get("mood", {})
	return {
		"valence": mood.get("valence", 0.0),
		"arousal": mood.get("arousal", 0.0),
		"energy": mood.get("energy", 0.5),
		"stress": mood.get("stress", 0.0),
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

func _build_health_context(npc_id: String, npc_data: Dictionary) -> Dictionary:
	# Build health and physical state information using Agent system
	var agent = Agent.get_agent(npc_id)
	if agent:
		var health = agent.get_current_health()
		return {
			"status": health.get("status", "healthy"),
			"energy": health.get("energy", 100.0),
			"hunger": health.get("hunger", 0.0),
			"thirst": health.get("thirst", 0.0),
			"comfort": health.get("comfort", 1.0),
			"health_stability": agent.get_health_stability(),
			"recent_health_changes": agent.get_recent_health_changes()
		}
	
	# Fallback to basic health data
	var health = npc_data.get("health", {})
	return {
		"status": health.get("status", "healthy"),
		"energy": health.get("energy", 100.0),
		"hunger": health.get("hunger", 0.0),
		"thirst": health.get("thirst", 0.0),
		"comfort": health.get("comfort", 1.0)
	}

func _build_relationships_context(npc_id: String, target_ids: Array) -> Dictionary:
	# Build relationship information with conversation targets using RelationshipGraph
	var relationships = {}
	
	for target_id in target_ids:
		var relationship = RelationshipGraph.get_relationship(npc_id, target_id)
		if relationship:
			relationships[target_id] = {
				"strength": relationship.get("strength", 0.0),
				"trust": relationship.get("trust", 0.0),
				"familiarity": relationship.get("familiarity", 0.0),
				"relationship_type": relationship.get("type", "acquaintance"),
				"recent_interactions": relationship.get("recent_interactions", []),
				"shared_interests": relationship.get("shared_interests", []),
				"relationship_history": relationship.get("history", []),
				"emotional_bonds": relationship.get("emotional_bonds", {})
			}
		else:
			# Default relationship data
			relationships[target_id] = {
				"strength": 0.5,
				"trust": 0.5,
				"familiarity": 0.3,
				"relationship_type": "stranger",
				"recent_interactions": [],
				"shared_interests": [],
				"relationship_history": [],
				"emotional_bonds": {}
			}
	
	return relationships

func _get_recent_topics(npc_id: String, conversation_id: String) -> Array:
	# Get recent conversation topics for this NPC using MemoryStore
	var recent_topics = []
	
	# Get conversation history from MemoryStore
	var conversation_memories = MemoryStore.get_memories_by_category(npc_id, "conversation", 10)
	
	for memory in conversation_memories:
		if memory.has("topic") and memory.topic != "":
			recent_topics.append({
				"topic": memory.topic,
				"timestamp": memory.get("timestamp", {}),
				"participants": memory.get("participants", []),
				"emotional_impact": memory.get("emotional_impact", 0.0),
				"social_significance": memory.get("social_significance", 0.0)
			})
	
	# Limit to most recent topics
	if recent_topics.size() > 5:
		recent_topics = recent_topics.slice(-5)
	
	return recent_topics

func _get_current_goals(npc_id: String) -> Array:
	# Get current goals and motivations for the NPC using Agent system
	var agent = Agent.get_agent(npc_id)
	if agent:
		return agent.get_current_goals()
	
	# Fallback to default goals
	return [
		"maintain_social_connections",
		"fulfill_daily_routines",
		"explore_opportunities"
	]

func _get_location_context(npc_id: String) -> Dictionary:
	# Get current location and environmental context using EnvironmentalSensor
	var location_context = {}
	
	# Try to get from EnvironmentalSensor if available
	if EnvironmentalSensor:
		location_context = EnvironmentalSensor.get_location_context(npc_id)
	
	# Fallback to default location data
	if location_context.is_empty():
		location_context = {
			"name": "Town Square",
			"type": "public_space",
			"atmosphere": "busy",
			"nearby_objects": ["fountain", "benches", "market_stalls"],
			"time_of_day": "afternoon",
			"weather": "sunny"
		}
	
	return location_context

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
	# Get current world state information using EnvironmentalSensor
	var world_state = {}
	
	# Try to get from EnvironmentalSensor if available
	if EnvironmentalSensor:
		world_state = EnvironmentalSensor.get_world_state()
	
	# Fallback to basic world state
	if world_state.is_empty():
		world_state = {
			"time": Time.get_time_dict_from_system(),
			"weather": "sunny",
			"season": "summer",
			"day_of_week": "Wednesday",
			"special_events": ["market_day", "community_gathering"]
		}
	
	return world_state

func _build_memory_context(npc_id: String, target_ids: Array) -> Dictionary:
	# Build memory context using MemoryStore
	var memory_context = {
		"recent_memories": [],
		"relevant_memories": [],
		"emotional_memories": [],
		"action_memories": []
	}
	
	# Get recent memories
	var recent_memories = MemoryStore.get_recent_memories(npc_id, 5)
	memory_context.recent_memories = recent_memories
	
	# Get memories relevant to conversation targets
	for target_id in target_ids:
		var target_memories = MemoryStore.get_memories_with_participant(npc_id, target_id, 3)
		memory_context.relevant_memories.append_array(target_memories)
	
	# Get emotional memories
	var emotional_memories = MemoryStore.get_memories_by_emotional_impact(npc_id, 0.5, 3)
	memory_context.emotional_memories = emotional_memories
	
	# Get action memories
	var action_memories = MemoryStore.get_action_memories(npc_id, 3)
	memory_context.action_memories = action_memories
	
	return memory_context

func _build_action_context(npc_id: String) -> Dictionary:
	# Build action context using ActionExecutor and Agent system
	var action_context = {
		"recent_actions": [],
		"action_patterns": [],
		"failed_actions": [],
		"action_preferences": {}
	}
	
	# Get recent actions from Agent
	var agent = Agent.get_agent(npc_id)
	if agent:
		action_context.recent_actions = agent.get_recent_actions(5)
		action_context.action_patterns = agent.get_action_patterns()
		action_context.action_preferences = agent.get_action_preferences()
	
	# Get failure memories from MemoryStore
	var failure_memories = MemoryStore.get_failure_memories(npc_id, 3)
	action_context.failed_actions = failure_memories
	
	return action_context

# Helper functions
func _get_npc_data(npc_id: String) -> Dictionary:
	# Get NPC data from the Agent system
	var agent = Agent.get_agent(npc_id)
	if agent:
		return agent.get_basic_info()
	
	# Fallback to mock data
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
	# Get relationship data between two NPCs using RelationshipGraph
	var relationship = RelationshipGraph.get_relationship(npc_id, target_id)
	if relationship:
		return relationship
	
	# Fallback to default relationship data
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
	summary += "- Memory context: " + str(context.memory_context.recent_memories.size()) + " recent memories"
	
	return summary

func validate_context(context: Dictionary) -> bool:
	# Validate that a context has all required fields
	var required_fields = ["persona", "mood", "health", "relationships", "recent_topics", "goals", "location", "event_hints", "memory_context", "action_context"]
	
	for field in required_fields:
		if not context.has(field):
			print("[ContextPacker] Missing required field: ", field)
			return false
	
	return true

func build_enhanced_prompt(npc_id: String, context: Dictionary, conversation_history: Array = []) -> String:
	# Build an enhanced prompt using all context information
	var prompt = "You are " + context.persona.get("name", npc_id) + ".\n\n"
	
	# Add persona information
	if context.persona.has("persona_prompt") and context.persona.persona_prompt != "":
		prompt += context.persona.persona_prompt + "\n\n"
	
	# Add mood and emotional state
	prompt += "Current emotional state: " + context.mood.get("description", "neutral") + "\n"
	prompt += "Energy level: " + str(context.mood.get("energy", 0.5)) + "\n"
	prompt += "Stress level: " + str(context.mood.get("stress", 0.0)) + "\n\n"
	
	# Add relationship context
	if context.relationships.size() > 0:
		prompt += "Conversing with:\n"
		for target_id in context.relationships.keys():
			var rel = context.relationships[target_id]
			prompt += "- " + target_id + " (" + rel.relationship_type + ", trust: " + str(rel.trust) + ")\n"
		prompt += "\n"
	
	# Add recent topics
	if context.recent_topics.size() > 0:
		prompt += "Recent conversation topics:\n"
		for topic in context.recent_topics.slice(-3):  # Last 3 topics
			prompt += "- " + topic.topic + "\n"
		prompt += "\n"
	
	# Add memory context
	if context.memory_context.relevant_memories.size() > 0:
		prompt += "Relevant memories:\n"
		for memory in context.memory_context.relevant_memories.slice(-2):  # Last 2 relevant memories
			prompt += "- " + memory.get("summary_note", "Memory") + "\n"
		prompt += "\n"
	
	# Add conversation history if provided
	if conversation_history.size() > 0:
		prompt += "Recent conversation:\n"
		for entry in conversation_history.slice(-5):  # Last 5 entries
			prompt += entry.get("speaker", "Unknown") + ": " + entry.get("text", "") + "\n"
		prompt += "\n"
	
	prompt += "Respond naturally as your character, considering your current mood, relationships, and the conversation context."
	
	return prompt
