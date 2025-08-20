extends Node
class_name ActionExecutor

# Action Execution System
# Manages action lifecycle, progress tracking, interruption handling, and completion effects

signal action_started(action_data: Dictionary, npc_id: String)
signal action_progress(action_data: Dictionary, npc_id: String, progress: float)
signal action_completed(action_data: Dictionary, npc_id: String, results: Dictionary)
signal action_interrupted(action_data: Dictionary, npc_id: String, reason: String)
signal action_failed(action_data: Dictionary, npc_id: String, error: String)

# Current action being executed
var current_action: Dictionary = {}
var npc_id: String = ""
var action_start_time: float = 0.0
var action_progress: float = 0.0
var is_executing: bool = false
var is_paused: bool = false
var interruption_reason: String = ""

# Action state management
enum ActionState {
	IDLE,
	PREPARING,
	EXECUTING,
	PAUSED,
	INTERRUPTED,
	COMPLETED,
	FAILED
}

var current_state: ActionState = ActionState.IDLE

# Progress tracking
var progress_timer: Timer
var progress_update_interval: float = 0.1  # Update progress every 100ms

# Interruption handling
var interruption_priority: int = 0  # Higher priority actions can interrupt lower ones
var can_be_interrupted: bool = true
var interruption_cooldown: float = 0.0

# Completion effects tracking
var need_satisfaction_cache: Dictionary = {}
var skill_gain_cache: Dictionary = {}
var inventory_changes_cache: Dictionary = {}

# Dependencies
var status_component: StatusComponent
var action_planner: ActionPlanner
var action_randomizer: ActionRandomizer
var memory_component: MemoryComponent

func _ready():
	# Initialize progress timer
	progress_timer = Timer.new()
	progress_timer.wait_time = progress_update_interval
	progress_timer.timeout.connect(_on_progress_timer_timeout)
	progress_timer.autostart = false
	add_child(progress_timer)
	
	# Get dependencies
	status_component = get_parent().get_node_or_null("StatusComponent")
	action_planner = get_parent().get_node_or_null("ActionPlanner")
	action_randomizer = get_parent().get_node_or_null("ActionRandomizer")
	memory_component = get_parent().get_node_or_null("MemoryComponent")
	
	# Connect memory signals
	_connect_memory_signals()

# Start executing an action
func start_action(action_data: Dictionary, npc_identifier: String) -> Dictionary:
	if is_executing:
		return {"success": false, "message": "Already executing an action"}
	
	if not _validate_action(action_data):
		return {"success": false, "message": "Invalid action data"}
	
	# Set up action execution
	current_action = action_data.duplicate()
	npc_id = npc_identifier
	action_start_time = Time.get_time_dict_from_system()["unix"]
	action_progress = 0.0
	is_executing = true
	is_paused = false
	interruption_reason = ""
	
	# Initialize caches
	need_satisfaction_cache.clear()
	skill_gain_cache.clear()
	inventory_changes_cache.clear()
	
	# Change state
	_change_state(ActionState.PREPARING)
	
	# Emit start signal
	action_started.emit(current_action, npc_id)
	
	# Start progress tracking
	progress_timer.start()
	
	# Apply initial costs
	_apply_action_costs()
	
	# Change to executing state
	_change_state(ActionState.EXECUTING)
	
	return {"success": true, "message": "Action started: " + current_action.get("name", "Unknown")}

# Pause current action
func pause_action() -> Dictionary:
	if not is_executing:
		return {"success": false, "message": "No action to pause"}
	
	if is_paused:
		return {"success": false, "message": "Action already paused"}
	
	is_paused = true
	progress_timer.stop()
	_change_state(ActionState.PAUSED)
	
	return {"success": true, "message": "Action paused"}

# Resume paused action
func resume_action() -> Dictionary:
	if not is_executing:
		return {"success": false, "message": "No action to resume"}
	
	if not is_paused:
		return {"success": false, "message": "Action not paused"}
	
	is_paused = false
	progress_timer.start()
	_change_state(ActionState.EXECUTING)
	
	return {"success": true, "message": "Action resumed"}

# Interrupt current action
func interrupt_action(reason: String, priority: int = 0) -> Dictionary:
	if not is_executing:
		return {"success": false, "message": "No action to interrupt"}
	
	if not can_be_interrupted:
		return {"success": false, "message": "Action cannot be interrupted"}
	
	if priority < interruption_priority:
		return {"success": false, "message": "Insufficient priority to interrupt"}
	
	# Stop execution
	progress_timer.stop()
	is_executing = false
	is_paused = false
	interruption_reason = reason
	
	# Change state
	_change_state(ActionState.INTERRUPTED)
	
	# Emit interruption signal
	action_interrupted.emit(current_action, npc_id, reason)
	
	# Apply interruption effects
	_apply_interruption_effects()
	
	return {"success": true, "message": "Action interrupted: " + reason}

# Complete current action
func complete_action() -> Dictionary:
	if not is_executing:
		return {"success": false, "message": "No action to complete"}
	
	# Stop progress tracking
	progress_timer.stop()
	is_executing = false
	is_paused = false
	
	# Set progress to 100%
	action_progress = 1.0
	
	# Change state
	_change_state(ActionState.COMPLETED)
	
	# Apply completion effects
	var results = _apply_completion_effects()
	
	# Emit completion signal
	action_completed.emit(current_action, npc_id, results)
	
	# Reset state
	_reset_state()
	
	return {"success": true, "message": "Action completed", "results": results}

# Fail current action
func fail_action(error: String) -> Dictionary:
	if not is_executing:
		return {"success": false, "message": "No action to fail"}
	
	# Stop progress tracking
	progress_timer.stop()
	is_executing = false
	is_paused = false
	
	# Change state
	_change_state(ActionState.FAILED)
	
	# Emit failure signal
	action_failed.emit(current_action, npc_id, error)
	
	# Apply failure effects
	_apply_failure_effects()
	
	# Reset state
	_reset_state()
	
	return {"success": true, "message": "Action failed: " + error}

# Get current action status
func get_action_status() -> Dictionary:
	return {
		"is_executing": is_executing,
		"is_paused": is_paused,
		"current_action": current_action,
		"npc_id": npc_id,
		"progress": action_progress,
		"state": ActionState.keys()[current_state],
		"start_time": action_start_time,
		"elapsed_time": Time.get_time_dict_from_system()["unix"] - action_start_time if action_start_time > 0 else 0.0,
		"interruption_reason": interruption_reason
	}

# Get action progress
func get_progress() -> float:
	return action_progress

# Check if action can be interrupted
func can_interrupt(priority: int) -> bool:
	return can_be_interrupted and priority >= interruption_priority

# Set interruption settings
func set_interruption_settings(can_interrupt: bool, priority: int = 0):
	can_be_interrupted = can_interrupt
	interruption_priority = priority

# Console command interface
func console_command(command: String, args: Array) -> Dictionary:
	match command:
		"start":
			if args.size() < 1:
				return {"success": false, "message": "Usage: start <action_id> [npc_id]"}
			var action_id = args[0]
			var npc_identifier = args[1] if args.size() > 1 else npc_id
			
			# Get action data from ActionPlanner
			if action_planner:
				var action_data = action_planner.get_action_by_id(action_id)
				if action_data.is_empty():
					return {"success": false, "message": "Action not found: " + action_id}
				return start_action(action_data, npc_identifier)
			else:
				return {"success": false, "message": "ActionPlanner not available"}
		
		"pause":
			return pause_action()
		
		"resume":
			return resume_action()
		
		"interrupt":
			var reason = args[0] if args.size() > 0 else "Manual interruption"
			var priority = int(args[1]) if args.size() > 1 else 100
			return interrupt_action(reason, priority)
		
		"complete":
			return complete_action()
		
		"fail":
			var error = args[0] if args.size() > 0 else "Manual failure"
			return fail_action(error)
		
		"status":
			return {"success": true, "data": get_action_status()}
		
		"progress":
			return {"success": true, "data": {"progress": action_progress}}
		
		"memory":
			if not memory_component:
				return {"success": false, "message": "MemoryComponent not available"}
			
			if args.size() < 1:
				return {"success": false, "message": "Usage: memory <command> [args...]"}
			
			var memory_command = args[0]
			var memory_args = args.slice(1)
			return memory_component.console_command(memory_command, memory_args)
		
		"randomize":
			if not action_randomizer:
				return {"success": false, "message": "ActionRandomizer not available"}
			
			if args.size() < 1:
				return {"success": false, "message": "Usage: randomize <command> [args...]"}
			
			var randomize_command = args[0]
			var randomize_args = args.slice(1)
			return action_randomizer.console_command(randomize_command, randomize_args)
		
		_:
			return {"success": false, "message": "Unknown command: " + command}

# Private methods

func _validate_action(action_data: Dictionary) -> bool:
	var required_fields = ["id", "name", "duration"]
	for field in required_fields:
		if not action_data.has(field):
			return false
	return true

func _change_state(new_state: ActionState):
	current_state = new_state

func _reset_state():
	current_action.clear()
	npc_id = ""
	action_start_time = 0.0
	action_progress = 0.0
	is_executing = false
	is_paused = false
	interruption_reason = ""
	_change_state(ActionState.IDLE)

func _on_progress_timer_timeout():
	if not is_executing or is_paused:
		return
	
	# Calculate progress increment based on action duration
	var duration = current_action.get("duration", 1.0)
	var increment = progress_update_interval / duration
	
	# Update progress
	action_progress = min(action_progress + increment, 1.0)
	
	# Emit progress signal
	action_progress.emit(current_action, npc_id, action_progress)
	
	# Check if action is complete
	if action_progress >= 1.0:
		complete_action()

func _apply_action_costs():
	if not status_component:
		return
	
	var costs = current_action.get("costs", {})
	for need_type in costs:
		var amount = costs[need_type]
		status_component.modify_need(need_type, -amount)

func _apply_completion_effects() -> Dictionary:
	var results = {}
	
	# Generate randomized action result if randomizer is available
	var action_result = {}
	if action_randomizer:
		action_result = action_randomizer.generate_action_result(current_action, npc_id)
		results["action_result"] = action_result
		
		# Apply result-based modifiers
		var need_satisfaction_modifier = action_result.get("need_satisfaction_modifier", 1.0)
		var skill_gain_modifier = action_result.get("skill_gain_modifier", 1.0)
		var duration_modifier = action_result.get("duration_modifier", 1.0)
		
		# Store modifiers for later use
		results["modifiers"] = {
			"need_satisfaction": need_satisfaction_modifier,
			"skill_gain": skill_gain_modifier,
			"duration": duration_modifier
		}
	else:
		# Fallback to default modifiers
		action_result = {"result_type": "average", "quality": "standard"}
		results["action_result"] = action_result
		results["modifiers"] = {"need_satisfaction": 1.0, "skill_gain": 1.0, "duration": 1.0}
	
			# Apply need satisfaction with modifiers
	if status_component:
		var satisfies_needs = current_action.get("satisfies_needs", {})
		for need_type in satisfies_needs:
			var base_amount = satisfies_needs[need_type]
			var modified_amount = int(base_amount * results["modifiers"]["need_satisfaction"])
			status_component.modify_need(need_type, modified_amount)
			need_satisfaction_cache[need_type] = modified_amount
		
		results["needs_satisfied"] = need_satisfaction_cache
	
	# Apply skill gains with modifiers
	var skill_gains = current_action.get("skill_gains", {})
	for skill in skill_gains:
		var base_amount = skill_gains[skill]
		var modified_amount = int(base_amount * results["modifiers"]["skill_gain"])
		skill_gain_cache[skill] = modified_amount
		results["skills_gained"] = skill_gain_cache
	
	# Apply inventory changes
	var inventory_changes = current_action.get("inventory_changes", {})
	for item in inventory_changes:
		var change = inventory_changes[item]
		inventory_changes_cache[item] = change
		results["inventory_changes"] = inventory_changes_cache
	
	# Apply wealth changes from action result
	if action_result.has("wealth_change"):
		results["wealth_change"] = action_result["wealth_change"]
	
	# Apply other effects
	var effects = current_action.get("effects", {})
	results["other_effects"] = effects
	
	return results

func _apply_interruption_effects():
	# Apply partial need satisfaction based on progress
	if status_component and action_progress > 0:
		var satisfies_needs = current_action.get("satisfies_needs", {})
		for need_type in satisfies_needs:
			var amount = satisfies_needs[need_type] * action_progress
			status_component.modify_need(need_type, amount)

func _apply_failure_effects():
	# Apply failure penalties
	if status_component:
		var failure_penalties = current_action.get("failure_penalties", {})
		for need_type in failure_penalties:
			var amount = failure_penalties[need_type]
			status_component.modify_need(need_type, -amount)

func _connect_memory_signals():
	"""Connect action signals to memory system"""
	if memory_component:
		action_completed.connect(_on_action_completed_memory)
		action_failed.connect(_on_action_failed_memory)
		action_interrupted.connect(_on_action_interrupted_memory)

func _on_action_completed_memory(action_data: Dictionary, npc_id: String, results: Dictionary):
	"""Create memory when action completes successfully"""
	if memory_component:
		var participants = [npc_id]
		if results.has("other_participants"):
			participants.append_array(results["other_participants"])
		
		# Create comprehensive action memory
		memory_component.create_action_memory(action_data, results, participants)
		
		# Create pattern memory if this was a successful action
		if results.get("result_type") in ["excellent", "good"]:
			var pattern_data = _generate_pattern_data(action_data, results)
			memory_component.create_action_pattern_memory(action_data, pattern_data)

func _on_action_failed_memory(action_data: Dictionary, npc_id: String, error: String):
	"""Create memory when action fails"""
	if memory_component:
		var failure_data = {
			"failure_type": "execution",
			"reason": error,
			"severity": _determine_failure_severity(action_data, error),
			"need_penalties": current_action.get("failure_penalties", {}),
			"recovery_suggestions": _generate_recovery_suggestions(action_data, error)
		}
		
		memory_component.create_action_failure_memory(action_data, failure_data, [npc_id])

func _on_action_interrupted_memory(action_data: Dictionary, npc_id: String, reason: String):
	"""Create memory when action is interrupted"""
	if memory_component:
		var interruption_data = {
			"failure_type": "interruption",
			"reason": reason,
			"severity": "minor",
			"interruption_progress": action_progress,
			"recovery_suggestions": ["Resume action when conditions improve"]
		}
		
		memory_component.create_action_failure_memory(action_data, interruption_data, [npc_id])

func _determine_failure_severity(action_data: Dictionary, error: String) -> String:
	"""Determine the severity of an action failure"""
	# Check if it's a critical action
	if action_data.get("category") == "Critical" or action_data.get("critical", false):
		return "major"
	
	# Check error type for severity
	if "fatal" in error.to_lower() or "critical" in error.to_lower():
		return "catastrophic"
	elif "major" in error.to_lower() or "serious" in error.to_lower():
		return "major"
	elif "minor" in error.to_lower() or "slight" in error.to_lower():
		return "minor"
	else:
		return "moderate"

func _generate_recovery_suggestions(action_data: Dictionary, error: String) -> Array:
	"""Generate recovery suggestions based on action and error"""
	var suggestions = []
	
	# Basic recovery suggestions
	suggestions.append("Wait and try again later")
	suggestions.append("Check if conditions have improved")
	
	# Category-specific suggestions
	var category = action_data.get("category", "")
	match category:
		"Social":
			suggestions.append("Apologize and explain the situation")
			suggestions.append("Try a different approach or location")
		"Work":
			suggestions.append("Gather better tools or resources")
			suggestions.append("Ask for help from others")
		"Physical":
			suggestions.append("Rest and recover strength")
			suggestions.append("Use proper technique next time")
	
	# Error-specific suggestions
	if "interrupted" in error.to_lower():
		suggestions.append("Complete the action when not interrupted")
	elif "failed" in error.to_lower():
		suggestions.append("Learn from the failure and adapt")
	elif "timeout" in error.to_lower():
		suggestions.append("Plan for longer duration next time")
	
	return suggestions

func _generate_pattern_data(action_data: Dictionary, results: Dictionary) -> Dictionary:
	"""Generate pattern data for successful actions"""
	var pattern_data = {
		"pattern_type": "efficiency",
		"success_rate": 0.8,  # High success for excellent/good results
		"optimal_conditions": [],
		"avoid_conditions": [],
		"need_balance": {},
		"time_of_day_preference": "",
		"seasonal_effectiveness": {}
	}
	
	# Analyze optimal conditions based on action data
	if action_data.has("location_tags"):
		pattern_data["optimal_conditions"].append("Location: " + action_data["location_tags"][0])
	
	if action_data.has("time_restrictions"):
		pattern_data["time_of_day_preference"] = action_data["time_restrictions"]
	
	# Analyze need balance from results
	var needs_satisfied = results.get("needs_satisfied", {})
	if needs_satisfied.size() > 0:
		pattern_data["need_balance"] = needs_satisfied
	
	return pattern_data
