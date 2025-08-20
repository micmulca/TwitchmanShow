extends Node

class_name Agent

# Agent - Per-NPC agent system with persona, traits, and constraints
# Integrates with existing MemoryComponent, StatusComponent, and EnvironmentalSensor
# Provides context building, memory selection, and response post-processing

signal agent_initialized(agent_id: String)
signal personality_updated(agent_id: String, trait: String, value: float)
signal context_built(agent_id: String, context: Dictionary)

# Core agent properties
var agent_id: String = ""
var persona: Dictionary = {}  # system + style + few-shot
var traits: Dictionary = {}   # sliders -> decoding knobs
var constraints: Dictionary = {}  # max_tokens, stops, banned words

# Integration with existing components
var memory_component: Node = null  # Reference to existing MemoryComponent
var status_component: Node = null  # Reference to existing StatusComponent
var environmental_sensor: Node = null  # Reference to existing EnvironmentalSensor

# Agent state
var is_initialized: bool = false
var personality_consistency_score: float = 1.0
var last_response_time: float = 0.0
var response_count: int = 0

# Default trait values (Big Five + additional traits)
var default_traits: Dictionary = {
    "openness": 0.5,
    "extraversion": 0.5,
    "agreeableness": 0.5,
    "conscientiousness": 0.5,
    "neuroticism": 0.5,
    "risk_tolerance": 0.5,
    "work_ethic": 0.5,
    "creativity": 0.5,
    "patience": 0.5
}

# Default constraints
var default_constraints: Dictionary = {
    "max_tokens": 60,
    "stop_sequences": [],
    "banned_words": [],
    "response_style": "casual",
    "temperature": 0.7,
    "top_p": 0.9,
    "frequency_penalty": 0.0
}

func _ready():
    # Agent will be initialized by CharacterManager
    pass

func initialize(character_data: Dictionary, memory_comp: Node, status_comp: Node, env_sensor: Node):
    """Initialize the agent with character data and component references"""
    agent_id = character_data.get("character_id", "")
    
    # Set up component references
    memory_component = memory_comp
    status_component = status_comp
    environmental_sensor = env_sensor
    
    # Load persona from character data
    if character_data.has("agent_profile") and character_data.agent_profile.has("persona"):
        persona = character_data.agent_profile.persona
    else:
        # Create default persona based on character data
        persona = _create_default_persona(character_data)
    
    # Load traits from character data
    if character_data.has("agent_profile") and character_data.agent_profile.has("traits"):
        traits = character_data.agent_profile.traits
    else:
        # Use existing personality data from character
        traits = _extract_traits_from_character(character_data)
    
    # Load constraints from character data
    if character_data.has("agent_profile") and character_data.agent_profile.has("constraints"):
        constraints = character_data.agent_profile.constraints
    else:
        constraints = default_constraints.duplicate()
    
    # Apply trait-based constraint adjustments
    _apply_trait_constraints()
    
    is_initialized = true
    agent_initialized.emit(agent_id)
    print("[Agent] Initialized agent for character: ", agent_id)

func _create_default_persona(character_data: Dictionary) -> Dictionary:
    """Create a default persona based on character data"""
    var name = character_data.get("name", "Unknown")
    var description = character_data.get("description", "")
    
    return {
        "system_prompt": "You are " + name + ". " + description + " Respond naturally in conversation.",
        "style_rules": [
            "Stay in character as " + name,
            "Respond conversationally and naturally",
            "Show personality through your responses"
        ],
        "few_shot_examples": [
            "When greeting: 'Hello there!'",
            "When agreeing: 'That sounds good to me.'",
            "When disagreeing: 'I'm not so sure about that.'"
        ],
        "voice_characteristics": [
            "Conversational",
            "Personality-driven",
            "Context-aware"
        ]
    }

func _extract_traits_from_character(character_data: Dictionary) -> Dictionary:
    """Extract traits from existing character personality data"""
    var extracted_traits = default_traits.duplicate()
    
    if character_data.has("personality") and character_data.personality.has("big_five"):
        var big_five = character_data.personality.big_five
        extracted_traits.openness = big_five.get("openness", 0.5)
        extracted_traits.extraversion = big_five.get("extraversion", 0.5)
        extracted_traits.agreeableness = big_five.get("agreeableness", 0.5)
        extracted_traits.conscientiousness = big_five.get("conscientiousness", 0.5)
        extracted_traits.neuroticism = big_five.get("neuroticism", 0.5)
    
    if character_data.has("personality") and character_data.personality.has("traits"):
        var additional_traits = character_data.personality.traits
        extracted_traits.risk_tolerance = additional_traits.get("risk_tolerance", 0.5)
        extracted_traits.work_ethic = additional_traits.get("work_ethic", 0.5)
        extracted_traits.creativity = additional_traits.get("creativity", 0.5)
        extracted_traits.patience = additional_traits.get("patience", 0.5)
    
    return extracted_traits

func _apply_trait_constraints():
    """Apply trait-based adjustments to constraints"""
    # Adjust temperature based on personality
    if traits.has("extraversion"):
        var extraversion = traits.extraversion
        if extraversion > 0.7:
            constraints.temperature = 0.8  # More creative responses
        elif extraversion < 0.3:
            constraints.temperature = 0.5  # More conservative responses
    
    # Adjust response style based on agreeableness
    if traits.has("agreeableness"):
        var agreeableness = traits.agreeableness
        if agreeableness > 0.7:
            constraints.response_style = "friendly"
        elif agreeableness < 0.3:
            constraints.response_style = "direct"
    
    # Adjust max_tokens based on extraversion and creativity
    if traits.has("extraversion") and traits.has("creativity"):
        var base_tokens = constraints.max_tokens
        var extraversion_factor = traits.extraversion * 0.2
        var creativity_factor = traits.creativity * 0.3
        constraints.max_tokens = int(base_tokens * (1.0 + extraversion_factor + creativity_factor))

func build_context(conversation_group: Dictionary) -> Dictionary:
    """Build comprehensive context for LLM requests"""
    if not is_initialized:
        print("[Agent] Cannot build context - agent not initialized")
        return {}
    
    var context = {
        "persona_block": _build_persona_block(),
        "turn_directives": _build_turn_directives(conversation_group),
        "state_slice": _build_state_slice(),
        "relationship_slice": _build_relationship_slice(conversation_group),
        "memory_slice": _build_memory_slice(conversation_group),
        "conversation_frame": _build_conversation_frame(conversation_group),
        "world_state": _build_world_state()
    }
    
    context_built.emit(agent_id, context)
    return context

func _build_persona_block() -> Dictionary:
    """Build cached persona block for LLM context"""
    return {
        "system_prompt": persona.get("system_prompt", ""),
        "style_rules": persona.get("style_rules", []),
        "voice_characteristics": persona.get("voice_characteristics", []),
        "personality_traits": traits
    }

func _build_turn_directives(conversation_group: Dictionary) -> Dictionary:
    """Build turn-specific directives for the LLM"""
    return {
        "topic_intent": conversation_group.get("current_topic", "general_chat"),
        "constraints": constraints,
        "response_style": constraints.get("response_style", "casual"),
        "max_tokens": constraints.get("max_tokens", 60),
        "is_spotlight": conversation_group.get("is_spotlight", false)
    }

func _build_state_slice() -> Dictionary:
    """Build current character state slice"""
    if not status_component:
        return {}
    
    # Get current needs and status from StatusComponent
    var needs = status_component.get_all_needs()
    var mood = status_component.get_current_mood()
    var location = status_component.get_current_location()
    
    return {
        "needs": needs,
        "mood": mood,
        "location": location,
        "energy_level": needs.get("physical", {}).get("energy", {}).get("current", 0.5),
        "social_fatigue": needs.get("social", {}).get("social_fatigue", {}).get("current", 0.5)
    }

func _build_relationship_slice(conversation_group: Dictionary) -> Dictionary:
    """Build relationship context for conversation participants"""
    var participants = conversation_group.get("participants", [])
    var relationships = {}
    
    # This will be enhanced when RelationshipGraph is implemented
    for participant_id in participants:
        if participant_id != agent_id:
            relationships[participant_id] = {
                "relationship_type": "acquaintance",  # Placeholder
                "strength": 0.5,  # Placeholder
                "recent_interactions": 0  # Placeholder
            }
    
    return relationships

func _build_memory_slice(conversation_group: Dictionary) -> Dictionary:
    """Select and format relevant memories for context"""
    if not memory_component:
        return {"recent_memories": [], "relevant_memories": []}
    
    var topic = conversation_group.get("current_topic", "general_chat")
    var participants = conversation_group.get("participants", [])
    
    # Get recent memories from MemoryComponent
    var recent_memories = memory_component.get_recent_memories(10)
    
    # Get topic-relevant memories
    var relevant_memories = memory_component.search_memories_by_tags([topic])
    
    # Get participant-related memories
    var participant_memories = []
    for participant_id in participants:
        if participant_id != agent_id:
            var participant_memories_result = memory_component.search_memories_by_tags([participant_id])
            participant_memories.append_array(participant_memories_result)
    
    return {
        "recent_memories": recent_memories.slice(0, 5),  # Last 5 memories
        "relevant_memories": relevant_memories.slice(0, 3),  # Top 3 relevant
        "participant_memories": participant_memories.slice(0, 3)  # Top 3 participant-related
    }

func _build_conversation_frame(conversation_group: Dictionary) -> Dictionary:
    """Build current conversation frame context"""
    return {
        "conversation_id": conversation_group.get("group_id", ""),
        "current_topic": conversation_group.get("current_topic", "general_chat"),
        "participants": conversation_group.get("participants", []),
        "turn_number": conversation_group.get("turn_number", 0),
        "conversation_history": conversation_group.get("recent_turns", []),
        "speaker_order": conversation_group.get("speaker_order", [])
    }

func _build_world_state() -> Dictionary:
    """Build current world state context"""
    if not environmental_sensor:
        return {}
    
    # Get environmental context from EnvironmentalSensor
    var current_weather = environmental_sensor.get_current_weather()
    var current_time = environmental_sensor.get_current_time_period()
    var current_season = environmental_sensor.get_current_season()
    var current_location = environmental_sensor.get_current_location()
    
    return {
        "weather": current_weather,
        "time_period": current_time,
        "season": current_season,
        "location": current_location,
        "environmental_mood": environmental_sensor.get_environmental_mood()
    }

func select_memories(context: Dictionary) -> Array:
    """RAG-lite retrieval from existing memory system"""
    if not memory_component:
        return []
    
    var topic = context.get("topic", "general_chat")
    var participants = context.get("participants", [])
    var max_memories = context.get("max_memories", 5)
    
    # Get relevant memories by topic
    var topic_memories = memory_component.search_memories_by_tags([topic])
    
    # Get participant-related memories
    var participant_memories = []
    for participant_id in participants:
        if participant_id != agent_id:
            var participant_memories_result = memory_component.search_memories_by_tags([participant_id])
            participant_memories.append_array(participant_memories_result)
    
    # Combine and rank memories by relevance
    var all_memories = topic_memories + participant_memories
    var ranked_memories = _rank_memories_by_relevance(all_memories, context)
    
    return ranked_memories.slice(0, max_memories)

func _rank_memories_by_relevance(memories: Array, context: Dictionary) -> Array:
    """Rank memories by relevance to current context"""
    var ranked_memories = []
    
    for memory in memories:
        var relevance_score = _calculate_memory_relevance(memory, context)
        ranked_memories.append({
            "memory": memory,
            "relevance_score": relevance_score
        })
    
    # Sort by relevance score (highest first)
    ranked_memories.sort_custom(func(a, b): return a.relevance_score > b.relevance_score)
    
    # Return just the memory objects
    var result = []
    for ranked_memory in ranked_memories:
        result.append(ranked_memory.memory)
    
    return result

func _calculate_memory_relevance(memory: Dictionary, context: Dictionary) -> float:
    """Calculate relevance score for a memory in current context"""
    var score = 0.0
    
    # Topic relevance
    var topic = context.get("topic", "")
    if memory.has("tags") and topic in memory.tags:
        score += 0.5
    
    # Participant relevance
    var participants = context.get("participants", [])
    if memory.has("related_characters") and participants.has(memory.related_characters):
        score += 0.3
    
    # Recency bonus
    if memory.has("timestamp"):
        var age = Time.get_time_dict_from_system().hour - memory.timestamp
        var recency_bonus = max(0.0, 1.0 - (age / 24.0))  # Decay over 24 hours
        score += recency_bonus * 0.2
    
    # Memory strength bonus
    if memory.has("strength"):
        score += memory.strength * 0.1
    
    return score

func post_process(response: String) -> String:
    """Post-process LLM response to enforce persona, style, and safety"""
    if response.is_empty():
        return response
    
    var processed_response = response
    
    # Enforce response style
    processed_response = _enforce_response_style(processed_response)
    
    # Apply banned words filter
    processed_response = _apply_banned_words_filter(processed_response)
    
    # Enforce persona consistency
    processed_response = _enforce_persona_consistency(processed_response)
    
    # Update response tracking
    _update_response_tracking()
    
    return processed_response

func _enforce_response_style(response: String) -> String:
    """Enforce the specified response style"""
    var style = constraints.get("response_style", "casual")
    
    match style:
        "casual":
            # Ensure casual, conversational tone
            if response.begins_with("I would like to"):
                response = response.replace("I would like to", "I'd like to")
            if response.begins_with("I am going to"):
                response = response.replace("I am going to", "I'm going to")
        
        "formal":
            # Ensure formal, professional tone
            if response.begins_with("I'm"):
                response = response.replace("I'm", "I am")
            if response.begins_with("I'd"):
                response = response.replace("I'd", "I would")
        
        "friendly":
            # Ensure warm, friendly tone
            if not response.contains("!") and not response.contains("😊"):
                response = response.replace(".", "! 😊")
    
    return response

func _apply_banned_words_filter(response: String) -> String:
    """Apply banned words filter"""
    var banned_words = constraints.get("banned_words", [])
    
    for banned_word in banned_words:
        if response.contains(banned_word):
            # Replace with appropriate alternative
            var alternatives = {
                "bad_word": "inappropriate word",
                "curse": "strong language",
                "offensive": "inappropriate"
            }
            var replacement = alternatives.get(banned_word, "[redacted]")
            response = response.replace(banned_word, replacement)
    
    return response

func _enforce_persona_consistency(response: String) -> String:
    """Enforce persona consistency based on character traits"""
    # Check for personality drift
    var consistency_check = _check_personality_consistency(response)
    
    if consistency_check.consistency_score < 0.7:
        # Apply personality correction
        response = _apply_personality_correction(response, consistency_check.issues)
        personality_consistency_score = consistency_check.consistency_score
    
    return response

func _check_personality_consistency(response: String) -> Dictionary:
    """Check if response is consistent with character personality"""
    var issues = []
    var consistency_score = 1.0
    
    # Check extraversion consistency
    if traits.has("extraversion"):
        var extraversion = traits.extraversion
        var exclamation_count = response.count("!")
        var question_count = response.count("?")
        
        if extraversion > 0.7 and exclamation_count == 0:
            issues.append("Low energy response for high extraversion character")
            consistency_score -= 0.2
        elif extraversion < 0.3 and exclamation_count > 2:
            issues.append("High energy response for low extraversion character")
            consistency_score -= 0.2
    
    # Check agreeableness consistency
    if traits.has("agreeableness"):
        var agreeableness = traits.agreeableness
        var negative_words = ["no", "never", "hate", "dislike", "bad"]
        var negative_count = 0
        
        for word in negative_words:
            negative_count += response.count(word)
        
        if agreeableness > 0.7 and negative_count > 1:
            issues.append("Negative response for high agreeableness character")
            consistency_score -= 0.3
        elif agreeableness < 0.3 and negative_count == 0:
            issues.append("Overly positive response for low agreeableness character")
            consistency_score -= 0.2
    
    return {
        "consistency_score": max(0.0, consistency_score),
        "issues": issues
    }

func _apply_personality_correction(response: String, issues: Array) -> String:
    """Apply personality corrections to maintain consistency"""
    var corrected_response = response
    
    for issue in issues:
        if "extraversion" in issue:
            if traits.get("extraversion", 0.5) > 0.7:
                # Make more energetic
                if not corrected_response.ends_with("!"):
                    corrected_response += "!"
            else:
                # Make more reserved
                if corrected_response.ends_with("!"):
                    corrected_response = corrected_response.rstrip("!")
        
        if "agreeableness" in issue:
            if traits.get("agreeableness", 0.5) > 0.7:
                # Make more agreeable
                if corrected_response.contains("no"):
                    corrected_response = corrected_response.replace("no", "well, maybe")
    
    return corrected_response

func _update_response_tracking():
    """Update response tracking metrics"""
    last_response_time = Time.get_time()
    response_count += 1

func get_decoding_knobs() -> Dictionary:
    """Map traits to LLM parameters for optimal generation"""
    var knobs = {
        "temperature": constraints.get("temperature", 0.7),
        "top_p": constraints.get("top_p", 0.9),
        "frequency_penalty": constraints.get("frequency_penalty", 0.0),
        "presence_penalty": 0.0
    }
    
    # Adjust based on personality traits
    if traits.has("creativity"):
        knobs.temperature += traits.creativity * 0.2
    
    if traits.has("neuroticism"):
        knobs.frequency_penalty += traits.neuroticism * 0.1
    
    if traits.has("openness"):
        knobs.top_p += traits.openness * 0.1
    
    # Clamp values to valid ranges
    knobs.temperature = clamp(knobs.temperature, 0.1, 1.0)
    knobs.top_p = clamp(knobs.top_p, 0.1, 1.0)
    knobs.frequency_penalty = clamp(knobs.frequency_penalty, 0.0, 1.0)
    knobs.presence_penalty = clamp(knobs.presence_penalty, 0.0, 1.0)
    
    return knobs

func get_personality_summary() -> Dictionary:
    """Get a summary of the agent's personality for debugging"""
    return {
        "agent_id": agent_id,
        "persona": {
            "system_prompt": persona.get("system_prompt", "").substr(0, 100) + "...",
            "style_rules_count": persona.get("style_rules", []).size(),
            "voice_characteristics": persona.get("voice_characteristics", [])
        },
        "traits": traits,
        "constraints": constraints,
        "consistency_score": personality_consistency_score,
        "response_count": response_count,
        "last_response_time": last_response_time
    }

func update_trait(trait_name: String, new_value: float):
    """Update a personality trait and recalculate constraints"""
    if traits.has(trait_name):
        traits[trait_name] = clamp(new_value, 0.0, 1.0)
        _apply_trait_constraints()
        personality_updated.emit(agent_id, trait_name, new_value)
        print("[Agent] Updated trait ", trait_name, " to ", new_value, " for agent ", agent_id)

func is_ready() -> bool:
    """Check if agent is ready for use"""
    return is_initialized and memory_component != null and status_component != null
