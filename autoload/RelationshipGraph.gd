extends Node

class_name RelationshipGraph

# RelationshipGraph - Typed relationship edges for character social dynamics
# Manages trust, friendship, rivalry, and other relationship types
# Provides relationship context for LLM requests and social simulation

signal relationship_updated(character_id: String, target_id: String, type: RelationshipType, new_strength: float)
signal relationship_formed(character_id: String, target_id: String, type: RelationshipType)
signal relationship_broken(character_id: String, target_id: String, type: RelationshipType)

# Relationship types enum
enum RelationshipType {
    TRUST,          # Trust and reliability
    FRIENDSHIP,     # Friendship and camaraderie
    RIVALRY,        # Competition and opposition
    ROMANTIC,       # Romantic interest and attraction
    FAMILY,         # Family bonds and kinship
    MENTOR,         # Teacher-student relationship
    COLLEAGUE,      # Work and professional relationship
    ACQUAINTANCE    # Basic social connection
}

# Relationship data structure
var relationships: Dictionary = {}  # character_id -> {target_id -> {type, strength, metadata}}

# Relationship strength ranges
var strength_ranges: Dictionary = {
    RelationshipType.TRUST: {"min": 0.0, "max": 1.0, "neutral": 0.5},
    RelationshipType.FRIENDSHIP: {"min": 0.0, "max": 1.0, "neutral": 0.5},
    RelationshipType.RIVALRY: {"min": 0.0, "max": 1.0, "neutral": 0.5},
    RelationshipType.ROMANTIC: {"min": 0.0, "max": 1.0, "neutral": 0.0},
    RelationshipType.FAMILY: {"min": 0.3, "max": 1.0, "neutral": 0.7},
    RelationshipType.MENTOR: {"min": 0.0, "max": 1.0, "neutral": 0.6},
    RelationshipType.COLLEAGUE: {"min": 0.0, "max": 1.0, "neutral": 0.5},
    RelationshipType.ACQUAINTANCE: {"min": 0.0, "max": 1.0, "neutral": 0.5}
}

# Relationship decay rates (per hour)
var decay_rates: Dictionary = {
    RelationshipType.TRUST: 0.01,           # Trust decays slowly
    RelationshipType.FRIENDSHIP: 0.02,      # Friendship decays moderately
    RelationshipType.RIVALRY: 0.015,        # Rivalry decays slowly
    RelationshipType.ROMANTIC: 0.03,        # Romantic feelings decay faster
    RelationshipType.FAMILY: 0.005,         # Family bonds decay very slowly
    RelationshipType.MENTOR: 0.01,          # Mentor relationships decay slowly
    RelationshipType.COLLEAGUE: 0.02,       # Work relationships decay moderately
    RelationshipType.ACQUAINTANCE: 0.03     # Acquaintances decay faster
}

# Relationship metadata fields
var metadata_fields: Array = [
    "first_interaction",
    "last_interaction",
    "interaction_count",
    "positive_interactions",
    "negative_interactions",
    "shared_experiences",
    "conflicts",
    "gifts_given",
    "gifts_received",
    "time_spent_together"
]

# Performance tracking
var relationship_stats: Dictionary = {}  # character_id -> relationship statistics
var update_timer: Timer

func _ready():
    # Set up relationship update timer (update every 5 minutes)
    update_timer = Timer.new()
    add_child(update_timer)
    update_timer.wait_time = 300.0  # 5 minutes
    update_timer.timeout.connect(_on_update_timer_timeout)
    update_timer.start()
    
    print("[RelationshipGraph] Initialized with update interval: 5 minutes")

func _on_update_timer_timeout():
    """Periodic relationship updates and decay"""
    _update_all_relationships()

func _update_all_relationships():
    """Update all relationships with decay and other effects"""
    var current_time = Time.get_time()
    
    for character_id in relationships.keys():
        for target_id in relationships[character_id].keys():
            var relationship = relationships[character_id][target_id]
            var relationship_type = relationship.type
            var current_strength = relationship.strength
            
            # Apply decay
            var decay_rate = decay_rates.get(relationship_type, 0.02)
            var time_since_update = current_time - relationship.get("last_update", current_time)
            var hours_since_update = time_since_update / 3600.0
            
            var decay_amount = decay_rate * hours_since_update
            var new_strength = current_strength - decay_amount
            
            # Clamp to valid range
            var range_info = strength_ranges.get(relationship_type, {"min": 0.0, "max": 1.0})
            new_strength = clamp(new_strength, range_info.min, range_info.max)
            
            # Update relationship
            if abs(new_strength - current_strength) > 0.01:  # Only update if significant change
                relationship.strength = new_strength
                relationship.last_update = current_time
                
                # Emit signal for significant changes
                if abs(new_strength - current_strength) > 0.05:
                    relationship_updated.emit(character_id, target_id, relationship_type, new_strength)

func create_relationship(character_id: String, target_id: String, type: RelationshipType, initial_strength: float = -1.0):
    """Create a new relationship between two characters"""
    if character_id == target_id:
        print("[RelationshipGraph] Cannot create relationship with self: ", character_id)
        return
    
    # Initialize character relationships if needed
    if not relationships.has(character_id):
        relationships[character_id] = {}
    
    if not relationships.has(target_id):
        relationships[target_id] = {}
    
    # Set default strength if not specified
    if initial_strength < 0:
        var range_info = strength_ranges.get(type, {"neutral": 0.5})
        initial_strength = range_info.neutral
    
    # Clamp to valid range
    var range_info = strength_ranges.get(type, {"min": 0.0, "max": 1.0})
    initial_strength = clamp(initial_strength, range_info.min, range_info.max)
    
    # Create relationship data
    var relationship_data = {
        "type": type,
        "strength": initial_strength,
        "created": Time.get_time(),
        "last_update": Time.get_time(),
        "last_interaction": Time.get_time(),
        "interaction_count": 0,
        "positive_interactions": 0,
        "negative_interactions": 0,
        "shared_experiences": 0,
        "conflicts": 0,
        "gifts_given": 0,
        "gifts_received": 0,
        "time_spent_together": 0.0
    }
    
    # Store relationship (bidirectional)
    relationships[character_id][target_id] = relationship_data
    relationships[target_id][character_id] = relationship_data.duplicate()
    
    # Emit signal
    relationship_formed.emit(character_id, target_id, type)
    
    print("[RelationshipGraph] Created ", _get_relationship_type_name(type), " relationship between ", character_id, " and ", target_id, " (strength: ", initial_strength, ")")

func update_relationship(character_id: String, target_id: String, type: RelationshipType, change: float, reason: String = ""):
    """Update relationship strength with a change value"""
    if not _relationship_exists(character_id, target_id):
        print("[RelationshipGraph] Relationship does not exist between ", character_id, " and ", target_id)
        return
    
    var relationship = relationships[character_id][target_id]
    var current_strength = relationship.strength
    var relationship_type = relationship.type
    
    # Apply change
    var new_strength = current_strength + change
    
    # Clamp to valid range
    var range_info = strength_ranges.get(relationship_type, {"min": 0.0, "max": 1.0})
    new_strength = clamp(new_strength, range_info.min, range_info.max)
    
    # Update relationship
    relationship.strength = new_strength
    relationship.last_update = Time.get_time()
    relationship.last_interaction = Time.get_time()
    relationship.interaction_count += 1
    
    # Track interaction type
    if change > 0:
        relationship.positive_interactions += 1
    elif change < 0:
        relationship.negative_interactions += 1
    
    # Update metadata based on reason
    _update_relationship_metadata(relationship, reason, change)
    
    # Emit signal
    relationship_updated.emit(character_id, target_id, relationship_type, new_strength)
    
    print("[RelationshipGraph] Updated relationship between ", character_id, " and ", target_id, " by ", change, " (new strength: ", new_strength, ")")

func _update_relationship_metadata(relationship: Dictionary, reason: String, change: float):
    """Update relationship metadata based on interaction reason"""
    if reason.contains("gift"):
        if change > 0:
            relationship.gifts_given += 1
        else:
            relationship.gifts_received += 1
    
    if reason.contains("conflict") or reason.contains("argument"):
        relationship.conflicts += 1
    
    if reason.contains("shared") or reason.contains("together"):
        relationship.shared_experiences += 1

func get_relationship(character_id: String, target_id: String) -> Dictionary:
    """Get relationship data between two characters"""
    if not _relationship_exists(character_id, target_id):
        return {}
    
    return relationships[character_id][target_id]

func get_relationship_strength(character_id: String, target_id: String, type: RelationshipType) -> float:
    """Get relationship strength for a specific type"""
    if not _relationship_exists(character_id, target_id):
        return 0.0
    
    var relationship = relationships[character_id][target_id]
    if relationship.type == type:
        return relationship.strength
    
    return 0.0

func get_all_relationships(character_id: String) -> Dictionary:
    """Get all relationships for a character"""
    if not relationships.has(character_id):
        return {}
    
    return relationships[character_id]

func get_relationship_context(character_id: String, target_ids: Array) -> Dictionary:
    """Build relationship context for LLM requests"""
    var context = {}
    
    for target_id in target_ids:
        if target_id != character_id and _relationship_exists(character_id, target_id):
            var relationship = relationships[character_id][target_id]
            context[target_id] = {
                "type": _get_relationship_type_name(relationship.type),
                "strength": relationship.strength,
                "strength_description": _get_strength_description(relationship.strength),
                "interaction_count": relationship.interaction_count,
                "last_interaction": relationship.last_interaction,
                "recent_activity": _get_recent_activity(relationship),
                "relationship_quality": _calculate_relationship_quality(relationship)
            }
    
    return context

func _get_relationship_type_name(type: RelationshipType) -> String:
    """Convert relationship type enum to string"""
    match type:
        RelationshipType.TRUST:
            return "trust"
        RelationshipType.FRIENDSHIP:
            return "friendship"
        RelationshipType.RIVALRY:
            return "rivalry"
        RelationshipType.ROMANTIC:
            return "romantic"
        RelationshipType.FAMILY:
            return "family"
        RelationshipType.MENTOR:
            return "mentor"
        RelationshipType.COLLEAGUE:
            return "colleague"
        RelationshipType.ACQUAINTANCE:
            return "acquaintance"
        _:
            return "unknown"

func _get_strength_description(strength: float) -> String:
    """Get human-readable description of relationship strength"""
    if strength >= 0.8:
        return "very_strong"
    elif strength >= 0.6:
        return "strong"
    elif strength >= 0.4:
        return "moderate"
    elif strength >= 0.2:
        return "weak"
    else:
        return "very_weak"

func _get_recent_activity(relationship: Dictionary) -> String:
    """Get description of recent relationship activity"""
    var time_since_interaction = Time.get_time() - relationship.last_interaction
    var hours_since = time_since_interaction / 3600.0
    
    if hours_since < 1:
        return "very_recent"
    elif hours_since < 24:
        return "recent"
    elif hours_since < 168:  # 1 week
        return "moderate"
    else:
        return "distant"

func _calculate_relationship_quality(relationship: Dictionary) -> float:
    """Calculate overall relationship quality score"""
    var quality = relationship.strength
    
    # Bonus for positive interactions
    var positive_ratio = 0.0
    if relationship.interaction_count > 0:
        positive_ratio = float(relationship.positive_interactions) / relationship.interaction_count
        quality += positive_ratio * 0.2
    
    # Penalty for conflicts
    var conflict_ratio = 0.0
    if relationship.interaction_count > 0:
        conflict_ratio = float(relationship.conflicts) / relationship.interaction_count
        quality -= conflict_ratio * 0.3
    
    # Bonus for shared experiences
    quality += min(relationship.shared_experiences * 0.05, 0.2)
    
    return clamp(quality, 0.0, 1.0)

func remove_relationship(character_id: String, target_id: String, type: RelationshipType):
    """Remove a specific relationship type between characters"""
    if not _relationship_exists(character_id, target_id):
        return
    
    var relationship = relationships[character_id][target_id]
    if relationship.type == type:
        # Remove the relationship
        relationships[character_id].erase(target_id)
        relationships[target_id].erase(character_id)
        
        # Emit signal
        relationship_broken.emit(character_id, target_id, type)
        
        print("[RelationshipGraph] Removed ", _get_relationship_type_name(type), " relationship between ", character_id, " and ", target_id)

func _relationship_exists(character_id: String, target_id: String) -> bool:
    """Check if a relationship exists between two characters"""
    return relationships.has(character_id) and relationships[character_id].has(target_id)

func get_relationship_summary(character_id: String) -> Dictionary:
    """Get a summary of all relationships for a character"""
    if not relationships.has(character_id):
        return {"total_relationships": 0, "relationship_types": {}}
    
    var summary = {
        "total_relationships": relationships[character_id].size(),
        "relationship_types": {},
        "strongest_relationships": [],
        "recent_relationships": []
    }
    
    var type_counts = {}
    var relationship_list = []
    
    for target_id in relationships[character_id].keys():
        var relationship = relationships[character_id][target_id]
        var type_name = _get_relationship_type_name(relationship.type)
        
        # Count relationship types
        if type_name in type_counts:
            type_counts[type_name] += 1
        else:
            type_counts[type_name] = 1
        
        # Add to relationship list for sorting
        relationship_list.append({
            "target_id": target_id,
            "type": type_name,
            "strength": relationship.strength,
            "last_interaction": relationship.last_interaction
        })
    
    summary.relationship_types = type_counts
    
    # Sort by strength for strongest relationships
    relationship_list.sort_custom(func(a, b): return a.strength > b.strength)
    summary.strongest_relationships = relationship_list.slice(0, 5)
    
    # Sort by recency for recent relationships
    relationship_list.sort_custom(func(a, b): return a.last_interaction > b.last_interaction)
    summary.recent_relationships = relationship_list.slice(0, 5)
    
    return summary

func get_relationship_statistics() -> Dictionary:
    """Get overall relationship statistics"""
    var stats = {
        "total_relationships": 0,
        "relationship_types": {},
        "average_strengths": {},
        "most_active_characters": []
    }
    
    var character_activity = {}
    
    for character_id in relationships.keys():
        var char_relationships = relationships[character_id]
        stats.total_relationships += char_relationships.size()
        
        var char_activity = 0
        for target_id in char_relationships.keys():
            var relationship = char_relationships[target_id]
            var type_name = _get_relationship_type_name(relationship.type)
            
            # Count relationship types
            if type_name in stats.relationship_types:
                stats.relationship_types[type_name] += 1
            else:
                stats.relationship_types[type_name] = 1
            
            # Track character activity
            char_activity += relationship.interaction_count
            
            # Track average strengths
            if not stats.average_strengths.has(type_name):
                stats.average_strengths[type_name] = {"total": 0.0, "count": 0}
            
            stats.average_strengths[type_name].total += relationship.strength
            stats.average_strengths[type_name].count += 1
        
        character_activity[character_id] = char_activity
    
    # Calculate average strengths
    for type_name in stats.average_strengths.keys():
        var data = stats.average_strengths[type_name]
        if data.count > 0:
            data.average = data.total / data.count
        else:
            data.average = 0.0
    
    # Find most active characters
    var sorted_activity = character_activity.keys()
    sorted_activity.sort_custom(func(a, b): return character_activity[a] > character_activity[b])
    stats.most_active_characters = sorted_activity.slice(0, 10)
    
    return stats

func clear_character_relationships(character_id: String):
    """Clear all relationships for a specific character"""
    if not relationships.has(character_id):
        return
    
    # Remove all relationships involving this character
    var targets_to_remove = relationships[character_id].keys()
    for target_id in targets_to_remove:
        if relationships.has(target_id):
            relationships[target_id].erase(character_id)
    
    # Remove character's relationship data
    relationships.erase(character_id)
    
    print("[RelationshipGraph] Cleared all relationships for character: ", character_id)

func is_ready() -> bool:
    """Check if RelationshipGraph is ready for use"""
    return update_timer != null and update_timer.is_inside_tree()
