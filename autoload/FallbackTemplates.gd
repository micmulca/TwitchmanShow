extends Node

class_name FallbackTemplates

# FallbackTemplates - Rule-based fallback responses for conversation continuity
# Provides character-appropriate responses when LLM is unavailable
# Ensures natural conversation flow even during system issues

signal fallback_response_generated(agent_id: String, response: String, reason: String)
signal fallback_template_loaded(template_count: int)
signal fallback_quality_updated(agent_id: String, quality_score: float)

# Fallback response templates by character personality
var character_templates: Dictionary = {}
var default_templates: Dictionary = {}

# Response quality tracking
var response_quality: Dictionary = {}  # agent_id -> quality scores
var quality_threshold: float = 0.7  # Minimum quality for template selection

# Template categories
var template_categories: Array = [
    "greeting",
    "agreement",
    "disagreement",
    "question",
    "statement",
    "reaction",
    "transition",
    "farewell"
]

# Personality-based response modifiers
var personality_modifiers: Dictionary = {
    "extraversion": {
        "high": {"energy": 1.3, "enthusiasm": 1.2, "social_initiative": 1.4},
        "low": {"energy": 0.7, "enthusiasm": 0.8, "social_initiative": 0.6}
    },
    "agreeableness": {
        "high": {"positivity": 1.3, "conflict_avoidance": 1.4, "supportiveness": 1.3},
        "low": {"positivity": 0.7, "conflict_avoidance": 0.6, "supportiveness": 0.7}
    },
    "openness": {
        "high": {"creativity": 1.3, "curiosity": 1.4, "complexity": 1.2},
        "low": {"creativity": 0.7, "curiosity": 0.6, "complexity": 0.8}
    }
}

func _ready():
    # Load default templates
    _load_default_templates()
    
    # Load character-specific templates
    _load_character_templates()
    
    print("[FallbackTemplates] Initialized with ", default_templates.size(), " default templates")

func _load_default_templates():
    """Load default fallback templates for all personality types"""
    default_templates = {
        "greeting": {
            "casual": [
                "Hey there!",
                "Hello!",
                "Hi!",
                "Good to see you!",
                "Hey, how's it going?"
            ],
            "formal": [
                "Good day to you.",
                "Hello there.",
                "Greetings.",
                "Good to see you.",
                "Hello, how are you?"
            ],
            "friendly": [
                "Hi there! 😊",
                "Hello! How are you doing?",
                "Hey! Great to see you!",
                "Hi! It's wonderful to meet you!",
                "Hello! How's your day going?"
            ]
        },
        "agreement": {
            "casual": [
                "Yeah, I agree.",
                "That makes sense.",
                "You're right about that.",
                "I think so too.",
                "Sounds good to me."
            ],
            "formal": [
                "I concur with your assessment.",
                "That is indeed correct.",
                "You are absolutely right.",
                "I agree with your point.",
                "That is a valid observation."
            ],
            "friendly": [
                "Absolutely! That's a great point!",
                "I totally agree with you!",
                "You're absolutely right! 😊",
                "That makes perfect sense!",
                "I love that idea!"
            ]
        },
        "disagreement": {
            "casual": [
                "I'm not so sure about that.",
                "I see it differently.",
                "I don't think I agree.",
                "That's not quite right.",
                "I have to disagree."
            ],
            "formal": [
                "I must respectfully disagree.",
                "I see the situation differently.",
                "I cannot agree with that assessment.",
                "That is not entirely accurate.",
                "I must take issue with that point."
            ],
            "friendly": [
                "Hmm, I'm not sure I see it that way.",
                "I think I might disagree, but I'd love to hear more!",
                "That's interesting, but I see it differently.",
                "I'm not quite convinced, but I'm open to discussion!",
                "I think we might have different perspectives on this."
            ]
        },
        "question": {
            "casual": [
                "What do you think?",
                "How about you?",
                "What's your take on this?",
                "Any thoughts?",
                "What's your opinion?"
            ],
            "formal": [
                "What is your perspective on this matter?",
                "How do you view this situation?",
                "What are your thoughts regarding this?",
                "What is your assessment?",
                "How do you interpret this?"
            ],
            "friendly": [
                "What do you think about this? 😊",
                "I'd love to hear your thoughts!",
                "What's your perspective on this?",
                "How do you feel about it?",
                "What's your take on the situation?"
            ]
        },
        "statement": {
            "casual": [
                "That's interesting.",
                "I see what you mean.",
                "That makes sense.",
                "I understand.",
                "Got it."
            ],
            "formal": [
                "That is quite interesting.",
                "I understand your point.",
                "That is a valid observation.",
                "I comprehend your meaning.",
                "I see your perspective."
            ],
            "friendly": [
                "That's really interesting!",
                "I totally understand what you mean!",
                "That makes perfect sense! 😊",
                "I get it!",
                "That's a great point!"
            ]
        },
        "reaction": {
            "casual": [
                "Wow!",
                "Really?",
                "No way!",
                "That's amazing!",
                "Incredible!"
            ],
            "formal": [
                "That is remarkable.",
                "How extraordinary.",
                "That is quite impressive.",
                "Most interesting.",
                "Fascinating."
            ],
            "friendly": [
                "Wow, that's amazing! 😊",
                "Really? That's incredible!",
                "No way! That's fantastic!",
                "That's absolutely wonderful!",
                "Incredible! I love it!"
            ]
        },
        "transition": {
            "casual": [
                "Anyway...",
                "So...",
                "Well...",
                "Moving on...",
                "By the way..."
            ],
            "formal": [
                "In any case...",
                "Furthermore...",
                "Additionally...",
                "Moreover...",
                "On another note..."
            ],
            "friendly": [
                "Anyway, on a different note... 😊",
                "So, changing the subject a bit...",
                "Well, speaking of other things...",
                "By the way, I was thinking...",
                "Oh, that reminds me..."
            ]
        },
        "farewell": {
            "casual": [
                "See you later!",
                "Take care!",
                "Catch you later!",
                "Bye!",
                "See you around!"
            ],
            "formal": [
                "Goodbye.",
                "Farewell.",
                "Until we meet again.",
                "Take care.",
                "Good day."
            ],
            "friendly": [
                "See you later! It was great talking with you! 😊",
                "Take care! Hope to chat again soon!",
                "Bye! Have a wonderful day!",
                "See you around! Stay awesome!",
                "Farewell! Looking forward to next time!"
            ]
        }
    }

func _load_character_templates():
    """Load character-specific templates based on personality"""
    # This would typically load from character data files
    # For now, we'll create templates dynamically based on personality
    
    print("[FallbackTemplates] Character templates will be generated dynamically")

func generate_fallback_response(agent: Agent, context: Dictionary) -> String:
    """Generate a fallback response appropriate for the agent and context"""
    if not agent or not agent.is_ready():
        return _get_generic_fallback()
    
    var agent_id = agent.agent_id
    var traits = agent.traits
    var constraints = agent.constraints
    
    # Determine response category based on context
    var category = _determine_response_category(context)
    var style = constraints.get("response_style", "casual")
    
    # Get base template
    var base_template = _get_base_template(category, style)
    if base_template.is_empty():
        base_template = _get_generic_fallback()
    
    # Apply personality modifications
    var modified_response = _apply_personality_modifications(base_template, traits, style)
    
    # Apply context-specific modifications
    var final_response = _apply_context_modifications(modified_response, context)
    
    # Track response quality
    _track_response_quality(agent_id, final_response, context)
    
    # Emit signal
    fallback_response_generated.emit(agent_id, final_response, "llm_unavailable")
    
    print("[FallbackTemplates] Generated fallback response for ", agent_id, ": ", final_response)
    
    return final_response

func _determine_response_category(context: Dictionary) -> String:
    """Determine the appropriate response category based on context"""
    var conversation_context = context.get("conversation_frame", {})
    var current_topic = conversation_context.get("current_topic", "general_chat")
    var turn_number = conversation_context.get("turn_number", 0)
    var participants = conversation_context.get("participants", [])
    
    # First turn in conversation
    if turn_number == 0:
        return "greeting"
    
    # Last turn in conversation
    if turn_number >= 18:  # Near end of 20-turn conversation
        return "farewell"
    
    # Topic change
    if context.has("topic_changed") and context.topic_changed:
        return "transition"
    
    # Question asked
    if context.has("question_asked") and context.question_asked:
        return "question"
    
    # Agreement/disagreement context
    if context.has("agreement_context"):
        if context.agreement_context > 0.6:
            return "agreement"
        elif context.agreement_context < 0.4:
            return "disagreement"
    
    # Default to statement
    return "statement"

func _get_base_template(category: String, style: String) -> String:
    """Get a base template for the given category and style"""
    if not default_templates.has(category):
        return _get_generic_fallback()
    
    var style_templates = default_templates[category]
    if not style_templates.has(style):
        # Fall back to casual if style not found
        style = "casual"
    
    var templates = style_templates[style]
    if templates.is_empty():
        return _get_generic_fallback()
    
    # Return random template from the category
    return templates[randi() % templates.size()]

func _get_generic_fallback() -> String:
    """Get a generic fallback response when no specific template is available"""
    var generic_responses = [
        "I understand.",
        "That's interesting.",
        "I see what you mean.",
        "Tell me more.",
        "That makes sense."
    ]
    
    return generic_responses[randi() % generic_responses.size()]

func _apply_personality_modifications(template: String, traits: Dictionary, style: String) -> String:
    """Apply personality-based modifications to the template"""
    var modified_response = template
    
    # Apply extraversion modifications
    if traits.has("extraversion"):
        var extraversion = traits.extraversion
        if extraversion > 0.7:
            # High extraversion - more energetic
            if not modified_response.ends_with("!"):
                modified_response += "!"
            if style == "casual":
                modified_response = modified_response.replace(".", "! 😊")
        elif extraversion < 0.3:
            # Low extraversion - more reserved
            if modified_response.ends_with("!"):
                modified_response = modified_response.rstrip("!")
            if modified_response.ends_with("😊"):
                modified_response = modified_response.rstrip("😊")
    
    # Apply agreeableness modifications
    if traits.has("agreeableness"):
        var agreeableness = traits.agreeableness
        if agreeableness > 0.7:
            # High agreeableness - more positive
            if not modified_response.contains("😊") and not modified_response.contains("!"):
                modified_response = modified_response.replace(".", "! 😊")
        elif agreeableness < 0.3:
            # Low agreeableness - more direct
            if modified_response.contains("😊"):
                modified_response = modified_response.replace("😊", "")
    
    # Apply openness modifications
    if traits.has("openness"):
        var openness = traits.openness
        if openness > 0.7:
            # High openness - more curious
            if not modified_response.contains("?"):
                modified_response += " What do you think?"
        elif openness < 0.3:
            # Low openness - more conservative
            if modified_response.contains("?"):
                modified_response = modified_response.replace(" What do you think?", "")
    
    return modified_response

func _apply_context_modifications(response: String, context: Dictionary) -> String:
    """Apply context-specific modifications to the response"""
    var modified_response = response
    
    # Add topic-specific elements
    var topic = context.get("topic", "general_chat")
    if topic != "general_chat":
        modified_response += " Speaking of " + topic.replace("_", " ") + "..."
    
    # Add participant awareness
    var participants = context.get("participants", [])
    if participants.size() > 2:
        modified_response += " What do the rest of you think?"
    
    # Add emotional context
    var emotional_tone = context.get("emotional_tone", "neutral")
    if emotional_tone == "positive":
        modified_response += " This is really uplifting!"
    elif emotional_tone == "negative":
        modified_response += " I hope things get better."
    
    return modified_response

func _track_response_quality(agent_id: String, response: String, context: Dictionary):
    """Track the quality of generated fallback responses"""
    if not response_quality.has(agent_id):
        response_quality[agent_id] = []
    
    # Calculate quality score based on response characteristics
    var quality_score = _calculate_response_quality(response, context)
    
    # Store quality score
    response_quality[agent_id].append(quality_score)
    
    # Keep only last 10 scores
    if response_quality[agent_id].size() > 10:
        response_quality[agent_id].pop_front()
    
    # Calculate average quality
    var average_quality = 0.0
    for score in response_quality[agent_id]:
        average_quality += score
    
    average_quality /= response_quality[agent_id].size()
    
    # Emit quality update signal
    fallback_quality_updated.emit(agent_id, average_quality)

func _calculate_response_quality(response: String, context: Dictionary) -> float:
    """Calculate quality score for a fallback response"""
    var score = 0.5  # Base score
    
    # Length appropriateness
    var response_length = response.length()
    if response_length >= 20 and response_length <= 100:
        score += 0.2
    elif response_length > 100:
        score -= 0.1
    
    # Context relevance
    var topic = context.get("topic", "general_chat")
    if topic != "general_chat" and response.contains(topic.replace("_", " ")):
        score += 0.2
    
    # Personality consistency
    if response.contains("😊") or response.contains("!"):
        score += 0.1
    
    # Natural language
    if response.contains("?") or response.contains("..."):
        score += 0.1
    
    # Clamp to valid range
    return clamp(score, 0.0, 1.0)

func get_fallback_quality(agent_id: String) -> float:
    """Get the average fallback response quality for an agent"""
    if not response_quality.has(agent_id) or response_quality[agent_id].is_empty():
        return 0.5
    
    var total_quality = 0.0
    for score in response_quality[agent_id]:
        total_quality += score
    
    return total_quality / response_quality[agent_id].size()

func get_all_fallback_quality() -> Dictionary:
    """Get fallback response quality for all agents"""
    var all_quality = {}
    
    for agent_id in response_quality.keys():
        all_quality[agent_id] = get_fallback_quality(agent_id)
    
    return all_quality

func add_custom_template(category: String, style: String, template: String):
    """Add a custom fallback template"""
    if not default_templates.has(category):
        default_templates[category] = {}
    
    if not default_templates[category].has(style):
        default_templates[category][style] = []
    
    default_templates[category][style].append(template)
    
    print("[FallbackTemplates] Added custom template for ", category, " (", style, "): ", template)

func remove_custom_template(category: String, style: String, template: String):
    """Remove a custom fallback template"""
    if not default_templates.has(category) or not default_templates[category].has(style):
        return
    
    var templates = default_templates[category][style]
    var index = templates.find(template)
    
    if index >= 0:
        templates.remove_at(index)
        print("[FallbackTemplates] Removed custom template: ", template)

func get_template_statistics() -> Dictionary:
    """Get statistics about available fallback templates"""
    var stats = {
        "total_categories": default_templates.size(),
        "total_templates": 0,
        "templates_by_category": {},
        "templates_by_style": {}
    }
    
    # Count templates by category
    for category in default_templates.keys():
        var category_templates = default_templates[category]
        var category_count = 0
        
        for style in category_templates.keys():
            var style_templates = category_templates[style]
            category_count += style_templates.size()
            
            # Count by style
            if style in stats.templates_by_style:
                stats.templates_by_style[style] += style_templates.size()
            else:
                stats.templates_by_style[style] = style_templates.size()
        
        stats.templates_by_category[category] = category_count
        stats.total_templates += category_count
    
    return stats

func clear_quality_tracking(agent_id: String):
    """Clear quality tracking for a specific agent"""
    if response_quality.has(agent_id):
        response_quality[agent_id].clear()
        print("[FallbackTemplates] Cleared quality tracking for agent: ", agent_id)

func clear_all_quality_tracking():
    """Clear quality tracking for all agents"""
    response_quality.clear()
    print("[FallbackTemplates] Cleared all quality tracking")

func is_ready() -> bool:
    """Check if FallbackTemplates is ready for use"""
    return default_templates.size() > 0
