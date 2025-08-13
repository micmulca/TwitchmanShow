extends Node

# EventBus - Central event system for the autonomous world
# Handles pub/sub events for conversations, world events, and NPC actions

signal conversation_started(participants: Array, topic: String)
signal conversation_ended(participants: Array, summary: String)
signal topic_changed(conversation_id: String, new_topic: String, reason: String)
signal mood_changed(npc_id: String, old_mood: Dictionary, new_mood: Dictionary)
signal relationship_changed(npc_id: String, target_id: String, delta: float, reason: String)
signal world_event_triggered(event_type: String, data: Dictionary)
signal npc_action_performed(npc_id: String, action: String, target: String, data: Dictionary)
signal needs_updated(npc_id: String, needs: Dictionary)
signal proximity_detected(npc_id: String, nearby_npcs: Array)

# Event history for debugging and replay
var event_history: Array[Dictionary] = []
var max_history_size: int = 1000

# Event categories for filtering
enum EventCategory {
	CONVERSATION,
	MOOD,
	RELATIONSHIP,
	WORLD_EVENT,
	NPC_ACTION,
	NEEDS,
	PROXIMITY
}

func _ready():
	# Connect to all signals to log them
	conversation_started.connect(_on_event_logged.bind(EventCategory.CONVERSATION))
	conversation_ended.connect(_on_event_logged.bind(EventCategory.CONVERSATION))
	topic_changed.connect(_on_event_logged.bind(EventCategory.CONVERSATION))
	mood_changed.connect(_on_event_logged.bind(EventCategory.MOOD))
	relationship_changed.connect(_on_event_logged.bind(EventCategory.RELATIONSHIP))
	world_event_triggered.connect(_on_event_logged.bind(EventCategory.WORLD_EVENT))
	npc_action_performed.connect(_on_event_logged.bind(EventCategory.NPC_ACTION))
	needs_updated.connect(_on_event_logged.bind(EventCategory.NEEDS))
	proximity_detected.connect(_on_event_logged.bind(EventCategory.PROXIMITY))

func _on_event_logged(category: EventCategory, data: Dictionary):
	var event_data = {
		"timestamp": Time.get_time_dict_from_system(),
		"category": category,
		"data": data
	}
	
	event_history.append(event_data)
	
	# Trim history if it gets too long
	if event_history.size() > max_history_size:
		event_history.pop_front()
	
	# Log to console for debugging
	print("[EventBus] ", event_data)

# Utility functions for common event patterns
func emit_conversation_event(participants: Array, event_type: String, data: Dictionary = {}):
	var event_data = {
		"participants": participants,
		"event_type": event_type,
		"data": data
	}
	
	match event_type:
		"started":
			conversation_started.emit(participants, data.get("topic", ""))
		"ended":
			conversation_ended.emit(participants, data.get("summary", ""))
		"topic_changed":
			topic_changed.emit(data.get("conversation_id", ""), data.get("new_topic", ""), data.get("reason", ""))

func emit_mood_event(npc_id: String, old_mood: Dictionary, new_mood: Dictionary):
	mood_changed.emit(npc_id, old_mood, new_mood)

func emit_relationship_event(npc_id: String, target_id: String, delta: float, reason: String):
	relationship_changed.emit(npc_id, target_id, delta, reason)

func emit_world_event(event_type: String, data: Dictionary = {}):
	world_event_triggered.emit(event_type, data)

func emit_npc_action(npc_id: String, action: String, target: String = "", data: Dictionary = {}):
	npc_action_performed.emit(npc_id, action, target, data)

func emit_needs_update(npc_id: String, needs: Dictionary):
	needs_updated.emit(npc_id, needs)

func emit_proximity_event(npc_id: String, nearby_npcs: Array):
	proximity_detected.emit(npc_id, nearby_npcs)

# Debug functions
func get_event_history(category: EventCategory = null, limit: int = 50) -> Array:
	var filtered_history = event_history
	
	if category != null:
		filtered_history = event_history.filter(func(event): return event.category == category)
	
	# Return most recent events
	var start_index = max(0, filtered_history.size() - limit)
	return filtered_history.slice(start_index)

func clear_event_history():
	event_history.clear()

func get_event_stats() -> Dictionary:
	var stats = {}
	for category in EventCategory.values():
		stats[EventCategory.keys()[category]] = 0
	
	for event in event_history:
		var category_name = EventCategory.keys()[event.category]
		stats[category_name] = stats.get(category_name, 0) + 1
	
	return stats
