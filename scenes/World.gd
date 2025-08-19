extends Node2D

# World - Main scene for the autonomous world simulation
# Coordinates all systems and manages the simulation loop

# UI references
@onready var fps_label: Label = $DebugUI/FPSLabel
@onready var status_label: Label = $DebugUI/StatusLabel

# Simulation state
var simulation_running: bool = true
var current_tick: int = 0
var tick_timer: float = 0.0
var tick_rate: float = 0.1  # 10 ticks per second

# Performance tracking
var frame_times: Array[float] = []
var max_frame_times: int = 60

func _ready():
	# Initialize the world
	print("[World] Initializing autonomous world simulation...")
	
	# Connect to autoload signals
	EventBus.world_event_triggered.connect(_on_world_event)
	LLMClient.llm_health_changed.connect(_on_llm_health_changed)
	
	# Start simulation
	simulation_running = true
	print("[World] Simulation started")

func _process(delta):
	# Track frame time for FPS calculation
	_track_frame_time(delta)
	
	# Update FPS display
	_update_fps_display()
	
	# Simulation tick
	tick_timer += delta
	if tick_timer >= tick_rate:
		tick_timer = 0.0
		_simulation_tick()
		current_tick += 1

func _track_frame_time(delta):
	frame_times.append(delta)
	if frame_times.size() > max_frame_times:
		frame_times.pop_front()

func _update_fps_display():
	if frame_times.is_empty():
		return
	
	var avg_frame_time = 0.0
	for frame_time in frame_times:
		avg_frame_time += frame_time
	
	avg_frame_time /= frame_times.size()
	var fps = 1.0 / avg_frame_time if avg_frame_time > 0 else 0
	
	fps_label.text = "FPS: " + str(round(fps))

func _simulation_tick():
	# This is where the main simulation logic will run
	# For now, just update status
	_update_status_display()
	
	# Emit tick event
	EventBus.emit_world_event("simulation_tick", {
		"tick": current_tick,
		"timestamp": Time.get_time_dict_from_system()
	})

func _update_status_display():
	var llm_status = "Healthy" if LLMClient.is_available() else "Unhealthy"
	var event_count = EventBus.get_event_history(EventBus.EventCategory.CONVERSATION).size()
	var pending_requests = LLMClient.get_pending_request_count()
	
	status_label.text = "LLM: " + llm_status + " | Events: " + str(event_count) + " | Pending: " + str(pending_requests)

func _on_world_event(event_type: String, data: Dictionary):
	# Handle world events
	print("[World] World event: ", event_type, " - ", data)
	
	# Update status display
	_update_status_display()

func _on_llm_health_changed(is_healthy: bool):
	# Handle LLM health changes
	var status = "Healthy" if is_healthy else "Unhealthy"
	print("[World] LLM health changed: ", status)
	
	# Update status display
	_update_status_display()

# Console command handlers
func handle_console_command(command: String, args: Array, result: Dictionary):
	# Handle console commands that affect the world
	print("[World] Console command executed: ", command, " - ", args, " - ", result)
	
	# Update status display
	_update_status_display()

# Utility functions
func get_simulation_stats() -> Dictionary:
	return {
		"tick": current_tick,
		"running": simulation_running,
		"fps": 1.0 / (frame_times[-1] if frame_times.size() > 0 else 0.016),
		"llm_healthy": LLMClient.is_available(),
		"event_count": EventBus.get_event_history(EventBus.EventCategory.CONVERSATION).size()
	}

func pause_simulation():
	simulation_running = false
	print("[World] Simulation paused")

func resume_simulation():
	simulation_running = true
	print("[World] Simulation resumed")

func reset_simulation():
	current_tick = 0
	tick_timer = 0.0
	frame_times.clear()
	print("[World] Simulation reset")
