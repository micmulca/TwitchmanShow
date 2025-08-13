extends Node
class_name ActionPlanner

# ActionPlanner - Intelligent action selection based on character needs and context
# Implements the action planning system from character_action_implementation.md

# Core signals for action planning
signal action_planned(npc_id: String, action: Dictionary, score: float)
signal action_selected(npc_id: String, action: Dictionary)
signal planning_failed(npc_id: String, reason: String)

# NPC identifier
@export var npc_id: String = ""

# Reference to StatusComponent for need analysis
var status_component: StatusComponent = null

# Available actions for this NPC
var available_actions: Array[Dictionary] = []

# Current action plan
var current_plan: Dictionary = {}

# Planning configuration
var planning_interval: float = 1.0  # Plan every second
var last_planning_time: float = 0.0
var min_action_score: float = 0.3  # Minimum score to consider an action

# Action categories for organization
var action_categories: Dictionary = {
	"physical": ["eat", "drink", "sleep", "exercise", "rest"],
	"comfort": ["wash", "dress", "adjust_clothing", "find_shelter"],
	"activity": ["work", "read", "craft", "explore", "socialize"],
	"economic": ["shop", "work", "trade", "save_money"],
	"social": ["talk", "visit", "invite", "join_group"]
}

func _ready():
	if npc_id.is_empty():
		npc_id = get_parent().name if get_parent() else "unknown"
	
	# Find StatusComponent in parent
	status_component = _find_status_component()
	if not status_component:
		push_error("[ActionPlanner] No StatusComponent found for NPC: " + npc_id)
		return
	
	print("[ActionPlanner] Initialized for NPC: ", npc_id)
	
	# Load available actions
	_load_available_actions()

func _process(delta: float):
	var current_time = Time.get_time()
	if current_time - last_planning_time >= planning_interval:
		_plan_next_action()
		last_planning_time = current_time

func _find_status_component() -> StatusComponent:
	var parent = get_parent()
	while parent:
		var status = parent.get_node_or_null("StatusComponent")
		if status and status is StatusComponent:
			return status
		parent = parent.get_parent()
	return null

func _load_available_actions():
	# Load basic actions from JSON
	var actions_file = FileAccess.open("res://data/actions/basic_actions.json", FileAccess.READ)
	if actions_file:
		var actions_content = actions_file.get_as_text()
		actions_file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(actions_content)
		
		if parse_result == OK:
			var actions_data = json.data
			if actions_data.has("actions"):
				available_actions = actions_data.actions
				print("[ActionPlanner] Loaded ", available_actions.size(), " actions for ", npc_id)
			else:
				push_error("[ActionPlanner] Invalid actions file format")
		else:
			push_error("[ActionPlanner] Failed to parse actions file: ", json.get_error_message())
	else:
		push_error("[ActionPlanner] Could not open actions file")
		# Fallback to hardcoded basic actions
		_create_fallback_actions()

func _create_fallback_actions():
	# Fallback actions if JSON loading fails
	available_actions = [
		{
			"id": "rest",
			"name": "Rest",
			"category": "physical",
			"satisfies_needs": ["energy"],
			"costs": ["time"],
			"duration": 300,
			"location_tags": ["home", "indoor", "comfortable"],
			"base_score": 0.5
		},
		{
			"id": "eat",
			"name": "Eat",
			"category": "physical",
			"satisfies_needs": ["hunger"],
			"costs": ["time", "food"],
			"duration": 600,
			"location_tags": ["kitchen", "dining", "food_available"],
			"base_score": 0.5
		},
		{
			"id": "work",
			"name": "Work",
			"category": "activity",
			"satisfies_needs": ["achievement_need", "wealth_satisfaction"],
			"costs": ["energy", "time"],
			"duration": 1800,
			"location_tags": ["workplace", "office"],
			"base_score": 0.6
		}
	]
	print("[ActionPlanner] Created fallback actions for ", npc_id)

func _plan_next_action():
	if not status_component:
		planning_failed.emit(npc_id, "No StatusComponent available")
		return
	
	# Analyze current needs
	var need_analysis = _analyze_needs()
	
	# Score available actions
	var action_scores = _score_actions(need_analysis)
	
	# Select best action
	var best_action = _select_best_action(action_scores)
	
	if best_action:
		current_plan = best_action
		action_selected.emit(npc_id, best_action)
		print("[ActionPlanner] Selected action for ", npc_id, ": ", best_action.name, " (score: ", best_action.score, ")")
	else:
		planning_failed.emit(npc_id, "No suitable action found")

func _analyze_needs() -> Dictionary:
	var needs = status_component.get_needs_summary()
	var priorities = status_component.get_need_priorities()
	var critical_needs = status_component.get_critical_needs()
	
	var analysis = {
		"needs": needs,
		"priorities": priorities,
		"critical": critical_needs,
		"urgency_scores": {}
	}
	
	# Calculate urgency scores for each need
	for category in needs.keys():
		for need_type in needs[category].keys():
			var current_value = needs[category][need_type]
			var urgency = status_component._calculate_need_urgency(need_type, current_value)
			analysis.urgency_scores[need_type] = urgency
	
	return analysis

func _score_actions(need_analysis: Dictionary) -> Array[Dictionary]:
	var scored_actions: Array[Dictionary] = []
	
	for action in available_actions:
		var score = _calculate_action_score(action, need_analysis)
		if score >= min_action_score:
			var scored_action = action.duplicate(true)
			scored_action["score"] = score
			scored_action["npc_id"] = npc_id
			scored_actions.append(scored_action)
	
	# Sort by score (highest first)
	scored_actions.sort_custom(func(a, b): return a.score > b.score)
	
	return scored_actions

func _calculate_action_score(action: Dictionary, need_analysis: Dictionary) -> float:
	var base_score = action.get("base_score", 0.5)
	var need_satisfaction_score = 0.0
	var cost_penalty = 0.0
	var location_bonus = 0.0

	
	# Calculate need satisfaction score
	var satisfies_needs = action.get("satisfies_needs", [])
	for need_type in satisfies_needs:
		var urgency = need_analysis.urgency_scores.get(need_type, 0.5)
		need_satisfaction_score += urgency * 0.8  # Weight for need satisfaction
	
	# Calculate cost penalty
	var costs = action.get("costs", [])
	for cost in costs:
		match cost:
			"energy":
				var energy = status_component.get_need_value("energy")
				if energy < 0.3:
					cost_penalty += 0.3
			"time":
				cost_penalty += 0.1  # Small time penalty
			"food":
				# Check if food is available (placeholder)
				cost_penalty += 0.1
	
	# Calculate location bonus
	var current_location = status_component.location
	var location_tags = action.get("location_tags", [])
	if location_tags.has(current_location):
		location_bonus = 0.2
	

	
	# Combine scores
	var final_score = base_score + need_satisfaction_score - cost_penalty + location_bonus
	
	# Clamp to 0.0 - 1.0 range
	return clamp(final_score, 0.0, 1.0)

func _select_best_action(action_scores: Array[Dictionary]) -> Dictionary:
	if action_scores.is_empty():
		return {}
	
	# Return the highest scored action
	return action_scores[0]

# Public API for external systems
func get_current_plan() -> Dictionary:
	return current_plan.duplicate(true)

func force_action(action_id: String) -> bool:
	for action in available_actions:
		if action.id == action_id:
			current_plan = action.duplicate(true)
			current_plan["forced"] = true
			action_selected.emit(npc_id, current_plan)
			return true
	return false

func clear_current_plan():
	current_plan = {}

func get_available_actions() -> Array[Dictionary]:
	return available_actions.duplicate(true)

func add_custom_action(action: Dictionary):
	available_actions.append(action)

# Console commands for debugging
func console_command(command: String, args: Array) -> Dictionary:
	match command:
		"plan":
			_plan_next_action()
			var plan = get_current_plan()
			if plan.has("name"):
				return {"success": true, "message": "Planned action: " + plan.name + " (score: " + str(round(plan.score * 100)) + "%)"}
			else:
				return {"success": true, "message": "No action planned"}
		
		"force":
			if args.size() >= 1:
				var action_id = args[0]
				if force_action(action_id):
					return {"success": true, "message": "Forced action: " + action_id}
				else:
					return {"success": false, "message": "Unknown action: " + action_id}
			return {"success": false, "message": "Usage: force <action_id>"}
		
		"clear":
			clear_current_plan()
			return {"success": true, "message": "Current plan cleared"}
		
		"actions":
			var message = "Available actions for " + npc_id + ":\n"
			for action in available_actions:
				message += "- " + action.name + " (" + action.category + ")\n"
			return {"success": true, "message": message}
		
		"score":
			if args.size() >= 1:
				var action_id = args[0]
				for action in available_actions:
					if action.id == action_id:
						var need_analysis = _analyze_needs()
						var score = _calculate_action_score(action, need_analysis)
						return {"success": true, "message": "Score for " + action.name + ": " + str(round(score * 100)) + "%"}
				return {"success": false, "message": "Unknown action: " + action_id}
			return {"success": false, "message": "Usage: score <action_id>"}
		
		_:
			return {"success": false, "message": "Unknown command: " + command}
