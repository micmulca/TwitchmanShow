extends Node

# ConversationGroup - Manages a single conversation with multiple participants
# Enhanced for Phase 3: Integrates with Agent system, enhanced memory, and dialogue tracking
# Handles join/leave logic, topic management, and conversation memory

signal participant_joined(npc_id: String, group_id: String)
signal participant_left(npc_id: String, group_id: String, reason: String)
signal topic_changed(old_topic: String, new_topic: String, reason: String)
signal conversation_ended(group_id: String, reason: String, summary: String)
signal dialogue_added(speaker_id: String, dialogue: String, turn: int)

# Group identification
var group_id: String
var is_active: bool = true
var created_at: Dictionary
var last_activity: Dictionary

# Participants
var participants: Array[String] = []
var participant_data: Dictionary = {}  # Additional data per participant
var max_participants: int = 4

# Conversation state
var current_topic: String = "general_chat"
var topic_history: Array[Dictionary] = []
var conversation_memory: Array[Dictionary] = []
var max_memory_size: int = 50

# Dialogue tracking
var dialogue_history: Array[Dictionary] = []  # New: Track all dialogue entries
var max_dialogue_history: int = 100

# Social dynamics
var group_mood: Dictionary = {"valence": 0.0, "arousal": 0.0}
var conversation_intensity: float = 0.5
var social_cohesion: float = 0.7

# Performance tracking
var turn_count: int = 0
var last_speaker: String = ""
var speaking_queue: Array[String] = []

func _ready():
	# Generate unique group ID
	group_id = "group_" + str(Time.get_time_dict_from_system().unix_time) + "_" + str(randi())
	created_at = Time.get_time_dict_from_system()
	last_activity = created_at
	
	print("[ConversationGroup] Created group: ", group_id)

func add_participant(npc_id: String, data: Dictionary = {}) -> bool:
	# Add a participant to the conversation
	if participants.size() >= max_participants:
		print("[ConversationGroup] Group ", group_id, " is full")
		return false
	
	if npc_id in participants:
		print("[ConversationGroup] NPC ", npc_id, " is already in group ", group_id)
		return false
	
	# Check participation invariant (one conversation per NPC)
	if not _check_participation_invariant(npc_id):
		print("[ConversationGroup] NPC ", npc_id, " is already in another conversation")
		return false
	
	# Add participant
	participants.append(npc_id)
	participant_data[npc_id] = data.duplicate(true)
	
	# Update activity
	_update_activity()
	
	# Emit signal
	participant_joined.emit(npc_id, group_id)
	
	print("[ConversationGroup] Added participant ", npc_id, " to group ", group_id)
	return true

func remove_participant(npc_id: String, reason: String = "left") -> bool:
	# Remove a participant from the conversation
	if npc_id not in participants:
		print("[ConversationGroup] NPC ", npc_id, " is not in group ", group_id)
		return false
	
	# Remove from all arrays
	participants.erase(npc_id)
	participant_data.erase(npc_id)
	speaking_queue.erase(npc_id)
	
	# Update activity
	_update_activity()
	
	# Emit signal
	participant_left.emit(npc_id, group_id, reason)
	
	print("[ConversationGroup] Removed participant ", npc_id, " from group ", group_id, " (", reason, ")")
	
	# Check if group should end
	_check_group_viability()
	
	return true

func change_topic(new_topic: String, reason: String = "natural_progression") -> bool:
	# Change the conversation topic
	if new_topic == current_topic:
		return false
	
	var old_topic = current_topic
	
	# Add to topic history
	topic_history.append({
		"topic": old_topic,
		"duration": _calculate_topic_duration(),
		"participants": participants.duplicate(),
		"reason": reason,
		"turn": turn_count
	})
	
	# Update current topic
	current_topic = new_topic
	
	# Update activity
	_update_activity()
	
	# Emit signal
	topic_changed.emit(old_topic, new_topic, reason)
	
	print("[ConversationGroup] Group ", group_id, " changed topic from '", old_topic, "' to '", new_topic, "'")
	return true

func add_conversation_memory(memory_entry: Dictionary) -> void:
	# Add a memory entry to the conversation
	memory_entry["timestamp"] = Time.get_time_dict_from_system()
	memory_entry["turn"] = turn_count
	
	conversation_memory.append(memory_entry)
	
	# Trim memory if it gets too long
	if conversation_memory.size() > max_memory_size:
		conversation_memory.pop_front()
	
	# Update group mood based on memory
	_update_group_mood(memory_entry)

func add_dialogue_entry(speaker_id: String, dialogue: String, source: String = "llm_generated") -> void:
	# Add a dialogue entry to the conversation history
	var dialogue_entry = {
		"speaker_id": speaker_id,
		"dialogue": dialogue,
		"source": source,
		"timestamp": Time.get_time_dict_from_system(),
		"turn": turn_count,
		"topic": current_topic,
		"participants": participants.duplicate()
	}
	
	dialogue_history.append(dialogue_entry)
	
	# Trim history if it gets too long
	if dialogue_history.size() > max_dialogue_history:
		dialogue_history.pop_front()
	
	# Create conversation memory from dialogue
	var memory_entry = {
		"type": "dialogue",
		"speaker_id": speaker_id,
		"content": dialogue,
		"topic": current_topic,
		"mood_shift": _calculate_dialogue_mood_shift(dialogue, speaker_id),
		"relationship_effects": _calculate_dialogue_relationship_effects(dialogue, speaker_id),
		"summary_note": _generate_dialogue_summary(dialogue, speaker_id)
	}
	
	add_conversation_memory(memory_entry)
	
	# Update last speaker
	last_speaker = speaker_id
	
	# Emit signal
	dialogue_added.emit(speaker_id, dialogue, turn_count)
	
	print("[ConversationGroup] Added dialogue from ", speaker_id, " in group ", group_id)

func get_next_speaker() -> String:
	# Get the next speaker from the queue
	if speaking_queue.is_empty():
		# Refill queue with all participants
		speaking_queue = participants.duplicate()
		speaking_queue.shuffle()
	
	if speaking_queue.size() > 0:
		var next_speaker = speaking_queue.pop_front()
		last_speaker = next_speaker
		return next_speaker
	
	return ""

func advance_turn() -> void:
	# Advance the conversation turn
	turn_count += 1
	_update_activity()
	
	# Check for natural conversation end
	_check_natural_end()

func get_conversation_summary() -> Dictionary:
	# Generate a summary of the conversation
	var summary = {
		"group_id": group_id,
		"participants": participants.duplicate(),
		"topics_discussed": topic_history.size(),
		"current_topic": current_topic,
		"turn_count": turn_count,
		"dialogue_count": dialogue_history.size(),
		"group_mood": group_mood.duplicate(),
		"social_cohesion": social_cohesion,
		"duration": _calculate_conversation_duration(),
		"key_moments": _extract_key_moments()
	}
	
	return summary

func get_conversation_history() -> Array:
	# Get the conversation history for context building
	var history = []
	
	for entry in dialogue_history:
		history.append({
			"speaker": entry.speaker_id,
			"text": entry.dialogue,
			"turn": entry.turn,
			"topic": entry.topic
		})
	
	return history

func end_conversation(reason: String = "natural_end") -> void:
	# End the conversation
	if not is_active:
		return
	
	is_active = false
	
	var summary = get_conversation_summary()
	var summary_text = _generate_summary_text(summary)
	
	# Create final conversation memory
	var final_memory = {
		"type": "conversation_end",
		"reason": reason,
		"summary": summary_text,
		"participants": participants.duplicate(),
		"duration": _calculate_conversation_duration(),
		"topics_discussed": topic_history.size(),
		"dialogue_count": dialogue_history.size()
	}
	
	# Add to all participants' memories
	for participant_id in participants:
		MemoryStore.add_memory(participant_id, final_memory)
	
	# Emit signal
	conversation_ended.emit(group_id, reason, summary_text)
	
	print("[ConversationGroup] Group ", group_id, " ended (", reason, "): ", summary_text)
	
	# Clean up
	queue_free()

# Private helper functions
func _check_participation_invariant(npc_id: String) -> bool:
	# Check if NPC is already in another conversation
	# This would be enforced by ConversationController
	# For now, assume it's valid
	return true

func _check_group_viability() -> void:
	# Check if the group should continue or end
	if participants.size() < 2:
		end_conversation("insufficient_participants")
	elif participants.size() == 2 and _should_duo_end():
		end_conversation("duo_conversation_ended")

func _should_duo_end() -> bool:
	# Check if a duo conversation should naturally end
	# Based on topic exhaustion, mood, or time
	var topic_duration = _calculate_topic_duration()
	var mood_negative = group_mood.valence < -0.3
	
	return topic_duration > 300.0 or mood_negative  # 5 minutes or negative mood

func _check_natural_end() -> void:
	# Check if conversation should end naturally
	var conversation_duration = _calculate_conversation_duration()
	var max_duration = 1800.0  # 30 minutes
	
	if conversation_duration > max_duration:
		end_conversation("time_limit_reached")
	elif _all_participants_fatigued():
		end_conversation("social_fatigue")

func _all_participants_fatigued() -> bool:
	# Check if all participants are socially fatigued
	for npc_id in participants:
		var data = participant_data.get(npc_id, {})
		var social_fatigue = data.get("social_fatigue", 0.0)
		if social_fatigue < 0.8:  # Not fatigued enough
			return false
	return true

func _update_activity() -> void:
	# Update last activity timestamp
	last_activity = Time.get_time_dict_from_system()

func _update_group_mood(memory_entry: Dictionary) -> void:
	# Update group mood based on conversation memory
	var mood_shift = memory_entry.get("mood_shift", {})
	var valence_delta = mood_shift.get("valence", 0.0) * 0.1
	var arousal_delta = mood_shift.get("arousal", 0.0) * 0.1
	
	group_mood.valence = clamp(group_mood.valence + valence_delta, -1.0, 1.0)
	group_mood.arousal = clamp(group_mood.arousal + arousal_delta, 0.0, 1.0)
	
	# Update social cohesion based on mood consistency
	_update_social_cohesion()

func _update_social_cohesion() -> void:
	# Update social cohesion based on group dynamics
	var mood_variance = _calculate_mood_variance()
	var cohesion_delta = (1.0 - mood_variance) * 0.05
	
	social_cohesion = clamp(social_cohesion + cohesion_delta, 0.0, 1.0)

func _calculate_mood_variance() -> float:
	# Calculate variance in participant moods
	if participants.size() < 2:
		return 0.0
	
	var moods = []
	for npc_id in participants:
		var data = participant_data.get(npc_id, {})
		var mood = data.get("mood", {}).get("valence", 0.0)
		moods.append(mood)
	
	var mean_mood = 0.0
	for mood in moods:
		mean_mood += mood
	mean_mood /= moods.size()
	
	var variance = 0.0
	for mood in moods:
		variance += (mood - mean_mood) ** 2
	variance /= moods.size()
	
	return variance

func _calculate_topic_duration() -> float:
	# Calculate how long the current topic has been discussed
	if topic_history.is_empty():
		return 0.0
	
	var current_time = Time.get_time_dict_from_system()
	var topic_start = topic_history[-1].get("timestamp", current_time)
	
	# Simple duration calculation (in seconds)
	var duration = (current_time.hour - topic_start.hour) * 3600 + (current_time.minute - topic_start.minute) * 60
	return abs(duration)

func _calculate_conversation_duration() -> float:
	# Calculate total conversation duration
	var current_time = Time.get_time_dict_from_system()
	var duration = (current_time.hour - created_at.hour) * 3600 + (current_time.minute - created_at.minute) * 60
	return abs(duration)

func _extract_key_moments() -> Array:
	# Extract key moments from conversation memory
	var key_moments = []
	
	for memory in conversation_memory:
		var mood_shift = memory.get("mood_shift", {})
		var relationship_effects = memory.get("relationship_effects", [])
		
		# Key moments are significant mood shifts or relationship changes
		if abs(mood_shift.get("valence", 0.0)) > 0.3 or relationship_effects.size() > 0:
			key_moments.append({
				"turn": memory.get("turn", 0),
				"description": memory.get("summary_note", ""),
				"significance": "high" if abs(mood_shift.get("valence", 0.0)) > 0.5 else "medium"
			})
	
	return key_moments

func _generate_summary_text(summary: Dictionary) -> String:
	# Generate a human-readable summary of the conversation
	var text = "Conversation between " + str(summary.participants.size()) + " participants"
	text += " discussing " + str(summary.topics_discussed) + " topics"
	text += " over " + str(round(summary.duration / 60.0)) + " minutes"
	text += ". Final mood: " + _describe_mood(summary.group_mood)
	
	return text

func _describe_mood(mood: Dictionary) -> String:
	# Convert mood values to descriptive text
	var valence = mood.get("valence", 0.0)
	var arousal = mood.get("arousal", 0.0)
	
	if valence > 0.5:
		return "positive"
	elif valence < -0.5:
		return "negative"
	else:
		return "neutral"

func _calculate_dialogue_mood_shift(dialogue: String, speaker_id: String) -> Dictionary:
	# Calculate mood shift from dialogue using Agent system
	var mood_shift = {"valence": 0.0, "arousal": 0.0}
	
	# Try to get from Agent system
	var agent = Agent.get_agent(speaker_id)
	if agent:
		mood_shift = agent.analyze_dialogue_mood_impact(dialogue)
	
	return mood_shift

func _calculate_dialogue_relationship_effects(dialogue: String, speaker_id: String) -> Array:
	# Calculate relationship effects from dialogue
	var effects = []
	
	# Analyze dialogue for relationship implications
	var dialogue_lower = dialogue.to_lower()
	
	# Simple keyword analysis
	if dialogue_lower.contains("thank") or dialogue_lower.contains("appreciate"):
		effects.append({"type": "gratitude", "target": "all", "strength": 0.1})
	elif dialogue_lower.contains("sorry") or dialogue_lower.contains("apologize"):
		effects.append({"type": "apology", "target": "all", "strength": -0.1})
	elif dialogue_lower.contains("agree") or dialogue_lower.contains("yes"):
		effects.append({"type": "agreement", "target": "all", "strength": 0.05})
	elif dialogue_lower.contains("disagree") or dialogue_lower.contains("no"):
		effects.append({"type": "disagreement", "target": "all", "strength": -0.05})
	
	return effects

func _generate_dialogue_summary(dialogue: String, speaker_id: String) -> String:
	# Generate a summary note for the dialogue
	var summary = speaker_id + " said: "
	
	# Truncate long dialogue
	if dialogue.length() > 100:
		summary += dialogue.substr(0, 97) + "..."
	else:
		summary += dialogue
	
	return summary

# Utility functions for external systems
func get_participant_count() -> int:
	return participants.size()

func is_participant(npc_id: String) -> bool:
	return npc_id in participants

func get_participant_data(npc_id: String) -> Dictionary:
	return participant_data.get(npc_id, {})

func get_conversation_stats() -> Dictionary:
	return {
		"group_id": group_id,
		"participant_count": participants.size(),
		"turn_count": turn_count,
		"topic_count": topic_history.size(),
		"memory_size": conversation_memory.size(),
		"dialogue_count": dialogue_history.size(),
		"group_mood": group_mood,
		"social_cohesion": social_cohesion,
		"is_active": is_active
	}

func get_dialogue_stats() -> Dictionary:
	# Get statistics about dialogue in the conversation
	var speaker_counts = {}
	var total_words = 0
	
	for entry in dialogue_history:
		var speaker = entry.speaker_id
		speaker_counts[speaker] = speaker_counts.get(speaker, 0) + 1
		total_words += entry.dialogue.split(" ").size()
	
	return {
		"total_dialogue_entries": dialogue_history.size(),
		"total_words": total_words,
		"speaker_counts": speaker_counts,
		"average_words_per_entry": total_words / max(dialogue_history.size(), 1)
	}
