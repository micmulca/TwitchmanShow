extends Node

class_name MemoryStore

# MemoryStore - Ring buffers + long-term summaries for enhanced memory management
# Enhances existing MemoryComponent with compression and RAG-lite retrieval
# Provides efficient memory storage and retrieval for the agent system

signal memory_compressed(character_id: String, summary: Dictionary)
signal memory_retrieved(character_id: String, memory_count: int)
signal compression_completed(character_id: String, compression_ratio: float)

# Ring buffer for short-term memories (enhances existing MemoryComponent)
var short_term_buffer: Dictionary = {}  # character_id -> Array of recent memories
var max_short_term: int = 100

# Long-term compressed memories (enhances existing MemoryComponent)
var long_term_summaries: Dictionary = {}  # character_id -> compressed summaries
var compression_interval: float = 60.0  # Compress every minute

# Compression settings
var compression_threshold: int = 50  # Start compression when buffer reaches this size
var max_summary_length: int = 500   # Maximum characters in compressed summary
var compression_quality: float = 0.8  # Target compression quality (0.0-1.0)

# Performance tracking
var compression_stats: Dictionary = {}  # character_id -> compression statistics
var retrieval_stats: Dictionary = {}    # character_id -> retrieval statistics

# Timer for periodic compression
var compression_timer: Timer

func _ready():
    # Set up compression timer
    compression_timer = Timer.new()
    add_child(compression_timer)
    compression_timer.wait_time = compression_interval
    compression_timer.timeout.connect(_on_compression_timer_timeout)
    compression_timer.start()
    
    print("[MemoryStore] Initialized with compression interval: ", compression_interval, " seconds")

func _on_compression_timer_timeout():
    """Periodic compression of memories for all characters"""
    for character_id in short_term_buffer.keys():
        if short_term_buffer[character_id].size() >= compression_threshold:
            compress_memories(character_id)

func add_memory(character_id: String, memory: Dictionary):
    """Add a new memory to the short-term buffer"""
    if not short_term_buffer.has(character_id):
        short_term_buffer[character_id] = []
    
    # Add timestamp if not present
    if not memory.has("timestamp"):
        memory.timestamp = Time.get_time()
    
    # Add to short-term buffer
    short_term_buffer[character_id].append(memory)
    
    # Maintain buffer size
    if short_term_buffer[character_id].size() > max_short_term:
        # Remove oldest memories (FIFO)
        short_term_buffer[character_id].pop_front()
    
    # Check if compression is needed
    if short_term_buffer[character_id].size() >= compression_threshold:
        compress_memories(character_id)

func add_action_memory(character_id: String, action_memory: Dictionary):
    """Add action-specific memory with enhanced categorization"""
    # Categorize by action outcome for better compression
    var outcome = action_memory.get("action_outcome", "average")
    var category = action_memory.get("action_category", "General")
    
    # Add outcome and category tags for better retrieval
    if not action_memory.has("tags"):
        action_memory["tags"] = []
    
    action_memory["tags"].append("outcome_" + outcome)
    action_memory["tags"].append("category_" + category.to_lower().replace(" ", "_"))
    
    # Add to short-term buffer
    add_memory(character_id, action_memory)
    
    # Trigger immediate compression for high-impact actions
    if action_memory.get("social_significance", 0.0) > 0.5:
        compress_memories(character_id)

func compress_memories(character_id: String):
    """Compress recent memories into a long-term summary"""
    if not short_term_buffer.has(character_id) or short_term_buffer[character_id].is_empty():
        return
    
    var memories_to_compress = short_term_buffer[character_id].slice(0, compression_threshold)
    var summary = _create_memory_summary(character_id, memories_to_compress)
    
    # Store the summary
    if not long_term_summaries.has(character_id):
        long_term_summaries[character_id] = []
    
    long_term_summaries[character_id].append(summary)
    
    # Remove compressed memories from short-term buffer
    short_term_buffer[character_id] = short_term_buffer[character_id].slice(compression_threshold)
    
    # Update compression statistics
    _update_compression_stats(character_id, memories_to_compress.size(), summary)
    
    # Emit signal
    memory_compressed.emit(character_id, summary)
    
    print("[MemoryStore] Compressed ", memories_to_compress.size(), " memories for ", character_id, " into summary")

func _create_memory_summary(character_id: String, memories: Array) -> Dictionary:
    """Create a compressed summary of memories using LLM or fallback"""
    var summary = {
        "character_id": character_id,
        "timestamp": Time.get_time(),
        "memory_count": memories.size(),
        "time_range": {
            "start": memories[0].get("timestamp", 0),
            "end": memories[-1].get("timestamp", 0)
        },
        "topics": _extract_topics(memories),
        "participants": _extract_participants(memories),
        "emotional_tone": _extract_emotional_tone(memories),
        "summary_text": _generate_summary_text(memories),
        "tags": _extract_tags(memories)
    }
    
    return summary

func _extract_topics(memories: Array) -> Array:
    """Extract common topics from memories"""
    var topic_counts = {}
    
    for memory in memories:
        if memory.has("tags"):
            for tag in memory.tags:
                if tag in topic_counts:
                    topic_counts[tag] += 1
                else:
                    topic_counts[tag] = 1
    
    # Return top 5 topics by frequency
    var sorted_topics = topic_counts.keys()
    sorted_topics.sort_custom(func(a, b): return topic_counts[a] > topic_counts[b])
    
    return sorted_topics.slice(0, 5)

func _extract_participants(memories: Array) -> Array:
    """Extract participants mentioned in memories"""
    var participants = {}
    
    for memory in memories:
        if memory.has("related_characters"):
            for char_id in memory.related_characters:
                if char_id in participants:
                    participants[char_id] += 1
                else:
                    participants[char_id] = 1
    
    # Return top 5 participants by frequency
    var sorted_participants = participants.keys()
    sorted_participants.sort_custom(func(a, b): return participants[a] > participants[b])
    
    return sorted_participants.slice(0, 5)

func _extract_emotional_tone(memories: Array) -> Dictionary:
    """Extract overall emotional tone from memories"""
    var total_emotional_impact = 0.0
    var memory_count = memories.size()
    
    for memory in memories:
        if memory.has("emotional_impact"):
            total_emotional_impact += memory.emotional_impact
    
    var average_emotional_impact = total_emotional_impact / memory_count if memory_count > 0 else 0.0
    
    return {
        "average_impact": average_emotional_impact,
        "overall_tone": _classify_emotional_tone(average_emotional_impact),
        "intensity": abs(average_emotional_impact)
    }

func _classify_emotional_tone(impact: float) -> String:
    """Classify emotional tone based on impact value"""
    if impact > 0.6:
        return "very_positive"
    elif impact > 0.2:
        return "positive"
    elif impact > -0.2:
        return "neutral"
    elif impact > -0.6:
        return "negative"
    else:
        return "very_negative"

func _generate_summary_text(memories: Array) -> String:
    """Generate summary text using LLM or fallback method"""
    # Try to use LLM for summarization if available
    if LLMClient and LLMClient.is_healthy:
        return _generate_llm_summary(memories)
    else:
        return _generate_fallback_summary(memories)

func _generate_llm_summary(memories: Array) -> String:
    """Generate summary using LLM"""
    var memory_texts = []
    
    for memory in memories:
        var memory_text = memory.get("title", "") + ": " + memory.get("description", "")
        memory_texts.append(memory_text)
    
    var combined_text = "\n".join(memory_texts)
    
    # Truncate if too long for LLM context
    if combined_text.length() > 2000:
        combined_text = combined_text.substr(0, 2000) + "..."
    
    # Create summarization prompt
    var prompt = "Summarize these memories in 2-3 sentences, focusing on key events and emotional themes:\n\n" + combined_text
    
    # For now, return a simple fallback (in production, this would call LLM)
    return _generate_fallback_summary(memories)

func _generate_fallback_summary(memories: Array) -> String:
    """Generate summary using fallback method when LLM unavailable"""
    var summary_parts = []
    var topics = _extract_topics(memories)
    var participants = _extract_participants(memories)
    var emotional_tone = _extract_emotional_tone(memories)
    
    # Build summary from extracted information
    if topics.size() > 0:
        summary_parts.append("Key topics: " + ", ".join(topics.slice(0, 3)))
    
    if participants.size() > 0:
        summary_parts.append("Involved characters: " + ", ".join(participants.slice(0, 3)))
    
    summary_parts.append("Overall emotional tone: " + emotional_tone.overall_tone)
    
    var summary = ". ".join(summary_parts) + "."
    
    # Ensure summary is within length limit
    if summary.length() > max_summary_length:
        summary = summary.substr(0, max_summary_length - 3) + "..."
    
    return summary

func _extract_tags(memories: Array) -> Array:
    """Extract common tags from memories"""
    var tag_counts = {}
    
    for memory in memories:
        if memory.has("tags"):
            for tag in memory.tags:
                if tag in tag_counts:
                    tag_counts[tag] += 1
                else:
                    tag_counts[tag] = 1
    
    # Return top 10 tags by frequency
    var sorted_tags = tag_counts.keys()
    sorted_tags.sort_custom(func(a, b): return tag_counts[a] > tag_counts[b])
    
    return sorted_tags.slice(0, 10)

func retrieve_memories(character_id: String, tags: Array, max_memories: int = 10) -> Array:
    """RAG-lite retrieval by tags and relevance"""
    var all_memories = []
    
    # Get relevant short-term memories
    var short_term = _get_relevant_short_term(character_id, tags)
    all_memories.append_array(short_term)
    
    # Get relevant long-term summaries
    var long_term = _get_relevant_long_term(character_id, tags)
    all_memories.append_array(long_term)
    
    # Rank by relevance and return top results
    var ranked_memories = _rank_memories_by_relevance(all_memories, tags)
    var result = ranked_memories.slice(0, max_memories)
    
    # Update retrieval statistics
    _update_retrieval_stats(character_id, result.size())
    
    # Emit signal
    memory_retrieved.emit(character_id, result.size())
    
    return result

func _get_relevant_short_term(character_id: String, tags: Array) -> Array:
    """Get relevant short-term memories by tags"""
    if not short_term_buffer.has(character_id):
        return []
    
    var relevant_memories = []
    
    for memory in short_term_buffer[character_id]:
        if _is_memory_relevant(memory, tags):
            relevant_memories.append(memory)
    
    return relevant_memories

func _get_relevant_long_term(character_id: String, tags: Array) -> Array:
    """Get relevant long-term summaries by tags"""
    if not long_term_summaries.has(character_id):
        return []
    
    var relevant_summaries = []
    
    for summary in long_term_summaries[character_id]:
        if _is_memory_relevant(summary, tags):
            relevant_summaries.append(summary)
    
    return relevant_summaries

func _is_memory_relevant(memory: Dictionary, tags: Array) -> bool:
    """Check if memory is relevant to given tags"""
    if not memory.has("tags"):
        return false
    
    for tag in tags:
        if tag in memory.tags:
            return true
    
    return false

func _rank_memories_by_relevance(memories: Array, tags: Array) -> Array:
    """Rank memories by relevance to given tags"""
    var ranked_memories = []
    
    for memory in memories:
        var relevance_score = _calculate_memory_relevance(memory, tags)
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

func _calculate_memory_relevance(memory: Dictionary, tags: Array) -> float:
    """Calculate relevance score for a memory based on tags"""
    var score = 0.0
    
    # Tag matching score
    if memory.has("tags"):
        var matching_tags = 0
        for tag in tags:
            if tag in memory.tags:
                matching_tags += 1
        
        score += (matching_tags / tags.size()) * 0.6
    
    # Recency bonus for short-term memories
    if memory.has("timestamp"):
        var age = Time.get_time() - memory.timestamp
        var recency_bonus = max(0.0, 1.0 - (age / 3600.0))  # Decay over 1 hour
        score += recency_bonus * 0.3
    
    # Memory strength bonus
    if memory.has("strength"):
        score += memory.strength * 0.1
    
    return score

func _update_compression_stats(character_id: String, memory_count: int, summary: Dictionary):
    """Update compression statistics for a character"""
    if not compression_stats.has(character_id):
        compression_stats[character_id] = {
            "total_compressed": 0,
            "compression_ratio": 0.0,
            "last_compression": 0.0
        }
    
    var stats = compression_stats[character_id]
    stats.total_compressed += memory_count
    stats.last_compression = Time.get_time()
    
    # Calculate compression ratio (characters saved)
    var original_size = memory_count * 100  # Estimate 100 chars per memory
    var compressed_size = summary.get("summary_text", "").length()
    stats.compression_ratio = float(original_size - compressed_size) / original_size
    
    # Emit compression completed signal
    compression_completed.emit(character_id, stats.compression_ratio)

func _update_retrieval_stats(character_id: String, memory_count: int):
    """Update retrieval statistics for a character"""
    if not retrieval_stats.has(character_id):
        retrieval_stats[character_id] = {
            "total_retrieved": 0,
            "retrieval_count": 0,
            "last_retrieval": 0.0
        }
    
    var stats = retrieval_stats[character_id]
    stats.total_retrieved += memory_count
    stats.retrieval_count += 1
    stats.last_retrieval = Time.get_time()

func get_memory_stats(character_id: String) -> Dictionary:
    """Get memory statistics for a character"""
    var short_term_count = short_term_buffer.get(character_id, []).size()
    var long_term_count = long_term_summaries.get(character_id, []).size()
    var compression_stats_char = compression_stats.get(character_id, {})
    var retrieval_stats_char = retrieval_stats.get(character_id, {})
    
    return {
        "short_term_count": short_term_count,
        "long_term_count": long_term_count,
        "total_memories": short_term_count + long_term_count,
        "compression_stats": compression_stats_char,
        "retrieval_stats": retrieval_stats_char,
        "buffer_utilization": float(short_term_count) / max_short_term
    }

func get_all_memory_stats() -> Dictionary:
    """Get memory statistics for all characters"""
    var all_stats = {}
    
    for character_id in short_term_buffer.keys():
        all_stats[character_id] = get_memory_stats(character_id)
    
    return all_stats

func clear_character_memories(character_id: String):
    """Clear all memories for a specific character"""
    if short_term_buffer.has(character_id):
        short_term_buffer[character_id].clear()
    
    if long_term_summaries.has(character_id):
        long_term_summaries[character_id].clear()
    
    if compression_stats.has(character_id):
        compression_stats.erase(character_id)
    
    if retrieval_stats.has(character_id):
        retrieval_stats.erase(character_id)
    
    print("[MemoryStore] Cleared all memories for character: ", character_id)

func set_compression_interval(interval: float):
    """Set the compression interval in seconds"""
    compression_interval = interval
    if compression_timer:
        compression_timer.wait_time = interval
        compression_timer.start()
    
    print("[MemoryStore] Compression interval set to: ", interval, " seconds")

func set_compression_threshold(threshold: int):
    """Set the compression threshold (number of memories before compression)"""
    compression_threshold = threshold
    print("[MemoryStore] Compression threshold set to: ", threshold, " memories")

func force_compression(character_id: String):
    """Force compression for a specific character"""
    if short_term_buffer.has(character_id) and short_term_buffer[character_id].size() > 0:
        compress_memories(character_id)
        print("[MemoryStore] Forced compression for character: ", character_id)
    else:
        print("[MemoryStore] No memories to compress for character: ", character_id)

func is_ready() -> bool:
    """Check if MemoryStore is ready for use"""
    return compression_timer != null and compression_timer.is_inside_tree()

func get_action_memories_by_outcome(character_id: String, outcome: String) -> Array:
    """Retrieve action memories filtered by outcome"""
    var memories = []
    
    # Check short-term buffer
    if short_term_buffer.has(character_id):
        for memory in short_term_buffer[character_id]:
            if memory.get("action_outcome") == outcome:
                memories.append(memory)
    
    # Check long-term summaries
    if long_term_summaries.has(character_id):
        for summary in long_term_summaries[character_id]:
            if summary.get("outcome_distribution", {}).has(outcome):
                memories.append(summary)
    
    return memories

func get_action_memories_by_category(character_id: String, category: String) -> Array:
    """Retrieve action memories filtered by category"""
    var memories = []
    
    # Check short-term buffer
    if short_term_buffer.has(character_id):
        for memory in short_term_buffer[character_id]:
            if memory.get("action_category") == category:
                memories.append(memory)
    
    # Check long-term summaries
    if long_term_summaries.has(character_id):
        for summary in long_term_summaries[character_id]:
            if summary.get("category_distribution", {}).has(category):
                memories.append(summary)
    
    return memories

func get_failure_memories(character_id: String, severity: String = "") -> Array:
    """Retrieve failure memories, optionally filtered by severity"""
    var memories = []
    
    # Check short-term buffer
    if short_term_buffer.has(character_id):
        for memory in short_term_buffer[character_id]:
            if memory.get("source_type") == "action_failure":
                if severity == "" or memory.get("failure_severity") == severity:
                    memories.append(memory)
    
    # Check long-term summaries
    if long_term_summaries.has(character_id):
        for summary in long_term_summaries[character_id]:
            if summary.get("failure_summary", {}).has("failures"):
                var failure_memories = summary["failure_summary"]["failures"]
                for failure in failure_memories:
                    if severity == "" or failure.get("severity") == severity:
                        memories.append(failure)
    
    return memories
