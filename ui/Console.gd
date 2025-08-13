extends Control

# Console - Provides interface for console commands to influence the autonomous world
# Supports conversation, event, and action commands

signal command_executed(command: String, args: Array, result: Dictionary)

# UI references
@onready var output_panel: TextEdit = $VBoxContainer/OutputPanel
@onready var command_input: LineEdit = $VBoxContainer/InputPanel/CommandInput
@onready var send_button: Button = $VBoxContainer/InputPanel/SendButton
@onready var clear_button: Button = $VBoxContainer/InputPanel/ClearButton
@onready var help_button: Button = $VBoxContainer/InputPanel/HelpButton

# Command history
var command_history: Array[String] = []
var history_index: int = -1

# Available commands
var commands: Dictionary = {}

func _ready():
	# Connect button signals
	send_button.pressed.connect(_on_send_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	help_button.pressed.connect(_on_help_pressed)
	command_input.text_submitted.connect(_on_command_submitted)
	
	# Setup command input
	command_input.grab_focus()
	
	# Initialize available commands
	_initialize_commands()
	
	# Display welcome message
	_print_to_console("=== TwitchMan Autonomous World Console ===")
	_print_to_console("Type 'help' or click Help button for available commands")
	_print_to_console("")

func _initialize_commands():
	commands = {
		"help": {
			"description": "Show available commands",
			"usage": "help [command_name]",
			"function": _cmd_help
		},
		"event": {
			"description": "Trigger a world event",
			"usage": "event <type> [data]",
			"function": _cmd_event
		},
		"topic": {
			"description": "Change conversation topic",
			"usage": "topic <topic_name> [reason]",
			"function": _cmd_topic
		},
		"move": {
			"description": "Move NPC to position",
			"usage": "move <npc_id> <x> <y>",
			"function": _cmd_move
		},
		"emote": {
			"description": "Make NPC perform emotion/gesture",
			"usage": "emote <npc_id> <emotion>",
			"function": _cmd_emote
		},
		"merge": {
			"description": "Merge conversation groups",
			"usage": "merge <group1_id> <group2_id>",
			"function": _cmd_merge
		},
		"inject": {
			"description": "Inject topic into conversation",
			"usage": "inject <conversation_id> <topic>",
			"function": _cmd_inject
		},
		"mute": {
			"description": "Mute/unmute NPC",
			"usage": "mute <npc_id> [true/false]",
			"function": _cmd_mute
		},
		"conversation": {
			"description": "Start a conversation between NPCs",
			"usage": "conversation <npc1> <npc2> [topic]",
			"function": _cmd_conversation
		},
		"status": {
			"description": "Show system status",
			"usage": "status [detail_level]",
			"function": _cmd_status
		},
		"needs": {
			"description": "Manage NPC social needs",
			"usage": "needs <npc_id> <command> [args...]",
			"function": _cmd_needs
		},
		"proximity": {
			"description": "Manage NPC proximity and invitations",
			"usage": "proximity <npc_id> <command> [args...]",
			"function": _cmd_proximity
		},
		"environment": {
			"description": "Manage environmental conditions and effects",
			"usage": "environment <command> [args...]",
			"function": _cmd_environment
		},
		"weather": {
			"description": "Control weather conditions",
			"usage": "weather <command> [args...]",
			"function": _cmd_weather
		},
		"time": {
			"description": "Control time of day and seasons",
			"usage": "time <command> [args...]",
			"function": _cmd_time
		},
		"status_component": {
			"description": "Manage NPC status and needs",
			"usage": "status_component <npc_id> <command> [args...]",
			"function": _cmd_status_component
		},
		"character": {
			"description": "Character management and manipulation",
			"usage": "character <npc_id> <command> [args...]",
			"function": _cmd_character
		},
			"action": {
		"description": "Manage NPC actions and planning",
		"usage": "action <npc_id> <command> [args...]",
		"function": _cmd_action
	},
			"execute": {
		"description": "Manage NPC action execution",
		"usage": "execute <npc_id> <command> [args...]",
		"function": _cmd_execute
	},
		"population": {
		"description": "Manage character population and templates",
		"usage": "population <command> [args...]",
		"function": _cmd_population
	},
		"character_manager": {
		"description": "Character management system commands",
		"usage": "character_manager <command> [args...]",
		"function": _cmd_character_manager
	},
		"clear": {
			"description": "Clear console output",
			"usage": "clear",
			"function": _cmd_clear
		}
	}

func _on_send_pressed():
	_execute_command(command_input.text)

func _on_command_submitted(command: String):
	_execute_command(command)

func _on_clear_pressed():
	output_panel.clear()

func _on_help_pressed():
	_cmd_help()

func _execute_command(command_text: String):
	if command_text.strip_edges().is_empty():
		return
	
	# Add to history
	_add_to_history(command_text)
	
	# Parse command
	var parts = command_text.split(" ", false)
	var command_name = parts[0].to_lower()
	var args = parts.slice(1)
	
	# Display command
	_print_to_console("> " + command_text)
	
	# Execute command
	var result = {"success": false, "message": "Unknown command"}
	
	if commands.has(command_name):
		var cmd_func = commands[command_name].function
		result = cmd_func.call(args)
	else:
		result = {"success": false, "message": "Unknown command: " + command_name}
	
	# Display result
	if result.has("message"):
		var status = "✓" if result.success else "✗"
		_print_to_console(status + " " + result.message)
	
	# Emit signal
	command_executed.emit(command_name, args, result)
	
	# Clear input
	command_input.clear()

func _add_to_history(command: String):
	command_history.append(command)
	if command_history.size() > 100:
		command_history.pop_front()
	history_index = -1

func _print_to_console(text: String):
	output_panel.append_text(text + "\n")
	# Auto-scroll to bottom
	output_panel.scroll_vertical = output_panel.get_line_count()

# Command implementations
func _cmd_help(args: Array) -> Dictionary:
	if args.is_empty():
		_print_to_console("Available commands:")
		for cmd_name in commands.keys():
			var cmd = commands[cmd_name]
			_print_to_console("  " + cmd_name + " - " + cmd.description)
		return {"success": true, "message": "Help displayed"}
	else:
		var cmd_name = args[0].to_lower()
		if commands.has(cmd_name):
			var cmd = commands[cmd_name]
			_print_to_console("Command: " + cmd_name)
			_print_to_console("Description: " + cmd.description)
			_print_to_console("Usage: " + cmd.usage)
			return {"success": true, "message": "Help for " + cmd_name + " displayed"}
		else:
			return {"success": false, "message": "Unknown command: " + cmd_name}

func _cmd_event(args: Array) -> Dictionary:
	if args.is_empty():
		return {"success": false, "message": "Usage: event <type> [data]"}
	
	var event_type = args[0]
	var event_data = {}
	
	if args.size() > 1:
		# Parse additional data (simple key=value format)
		for i in range(1, args.size()):
			var arg = args[i]
			if "=" in arg:
				var key_value = arg.split("=", false)
				if key_value.size() == 2:
					event_data[key_value[0]] = key_value[1]
	
	# Emit world event
	EventBus.emit_world_event(event_type, event_data)
	
	return {"success": true, "message": "Event '" + event_type + "' triggered"}

func _cmd_topic(args: Array) -> Dictionary:
	if args.is_empty():
		return {"success": false, "message": "Usage: topic <topic_name> [reason]"}
	
	var topic = args[0]
	var reason = args[1] if args.size() > 1 else "Console command"
	
	# Use ConversationController to inject topic into active conversations
	var active_groups = ConversationController.get_active_groups()
	if active_groups.is_empty():
		return {"success": false, "message": "No active conversations to change topic"}
	
	# Inject topic into first active group
	var first_group_id = active_groups.keys()[0]
	if ConversationController.inject_topic_into_group(first_group_id, topic, reason):
		return {"success": true, "message": "Topic changed to '" + topic + "' in group " + first_group_id}
	else:
		return {"success": false, "message": "Failed to change topic"}

func _cmd_move(args: Array) -> Dictionary:
	if args.size() < 3:
		return {"success": false, "message": "Usage: move <npc_id> <x> <y>"}
	
	var npc_id = args[0]
	var x = args[1].to_float()
	var y = args[2].to_float()
	
	# This would interact with NPC movement system
	EventBus.emit_npc_action(npc_id, "move", "", {"position": Vector2(x, y)})
	
	return {"success": true, "message": "Moving " + npc_id + " to (" + str(x) + ", " + str(y) + ")"}

func _cmd_emote(args: Array) -> Dictionary:
	if args.size() < 2:
		return {"success": false, "message": "Usage: emote <npc_id> <emotion>"}
	
	var npc_id = args[0]
	var emotion = args[1]
	
	# This would interact with NPC animation system
	EventBus.emit_npc_action(npc_id, "emote", "", {"emotion": emotion})
	
	return {"success": true, "message": npc_id + " performing emotion: " + emotion}

func _cmd_merge(args: Array) -> Dictionary:
	if args.size() < 2:
		return {"success": false, "message": "Usage: merge <group1_id> <group2_id>"}
	
	var group1 = args[0]
	var group2 = args[1]
	
	# Use ConversationController to merge groups
	var merged_group_id = ConversationController.merge_groups(group1, group2)
	if not merged_group_id.is_empty():
		return {"success": true, "message": "Merged groups " + group1 + " and " + group2 + " into " + merged_group_id}
	else:
		return {"success": false, "message": "Failed to merge groups"}

func _cmd_inject(args: Array) -> Dictionary:
	if args.size() < 2:
		return {"success": false, "message": "Usage: inject <conversation_id> <topic>"}
	
	var conv_id = args[0]
	var topic = args[1]
	
	# Use ConversationController to inject topic
	if ConversationController.inject_topic_into_group(conv_id, topic, "console_injection"):
		return {"success": true, "message": "Injected topic '" + topic + "' into conversation " + conv_id}
	else:
		return {"success": false, "message": "Failed to inject topic"}

func _cmd_mute(args: Array) -> Dictionary:
	if args.is_empty():
		return {"success": false, "message": "Usage: mute <npc_id> [true/false]"}
	
	var npc_id = args[0]
	var muted = args[1].to_lower() == "true" if args.size() > 1 else true
	
	# This would interact with NPC system
	EventBus.emit_npc_action(npc_id, "mute", "", {"muted": muted})
	
	return {"success": true, "message": npc_id + " " + ("muted" if muted else "unmuted")}

func _cmd_conversation(args: Array) -> Dictionary:
	if args.size() < 2:
		return {"success": false, "message": "Usage: conversation <npc1> <npc2> [topic]"}
	
	var npc1 = args[0]
	var npc2 = args[1]
	var topic = args[2] if args.size() > 2 else "general_chat"
	
	# Start conversation using ConversationController
	var participants = [npc1, npc2]
	var group_id = ConversationController.start_conversation(participants, topic)
	
	if not group_id.is_empty():
		return {"success": true, "message": "Started conversation between " + npc1 + " and " + npc2 + " on topic: " + topic}
	else:
		return {"success": false, "message": "Failed to start conversation"}

func _cmd_status(args: Array) -> Dictionary:
	var detail_level = args[0] if args.size() > 0 else "basic"
	
	var status_info = {
		"llm_healthy": LLMClient.is_available(),
		"pending_requests": LLMClient.get_pending_request_count(),
		"event_count": EventBus.get_event_history().size(),
		"conversation_stats": ConversationController.get_conversation_stats()
	}
	
	if detail_level == "detailed":
		var event_stats = EventBus.get_event_stats()
		status_info["event_stats"] = event_stats
	
	_print_to_console("System Status:")
	_print_to_console("  LLM: " + ("✓ Healthy" if status_info.llm_healthy else "✗ Unhealthy"))
	_print_to_console("  Pending Requests: " + str(status_info.pending_requests))
	_print_to_console("  Total Events: " + str(status_info.event_count))
	_print_to_console("  Active Conversations: " + str(status_info.conversation_stats.active_groups))
	_print_to_console("  Total Participants: " + str(status_info.conversation_stats.total_participants))
	
	if detail_level == "detailed":
		if status_info.has("event_stats"):
			_print_to_console("  Event Breakdown:")
			for event_type in status_info.event_stats:
				_print_to_console("    " + event_type + ": " + str(status_info.event_stats[event_type]))
		
		_print_to_console("  Conversation Details:")
		for group_id in status_info.conversation_stats.group_details:
			var group = status_info.conversation_stats.group_details[group_id]
			_print_to_console("    " + group_id + ": " + str(group.participant_count) + " participants, " + str(group.turn_count) + " turns")
	
	return {"success": true, "message": "Status displayed"}

func _cmd_needs(args: Array) -> Dictionary:
	if args.size() < 2:
		return {"success": false, "message": "Usage: needs <npc_id> <command> [args...]"}
	
	var npc_id = args[0]
	var command = args[1]
	var command_args = args.slice(2)
	
	# Find NPC and their NeedsComponent
	var npc_node = get_tree().get_node_or_null("//" + npc_id)
	if not npc_node:
		return {"success": false, "message": "NPC not found: " + npc_id}
	
	var needs_component = npc_node.get_node_or_null("NeedsComponent")
	if not needs_component:
		return {"success": false, "message": "NeedsComponent not found for NPC: " + npc_id}
	
	# Execute needs command
	if needs_component.has_method("console_command"):
		return needs_component.console_command(command, command_args)
	else:
		return {"success": false, "message": "NeedsComponent does not support console commands"}

func _cmd_proximity(args: Array) -> Dictionary:
	if args.size() < 2:
		return {"success": false, "message": "Usage: proximity <npc_id> <command> [args...]"}
	
	var npc_id = args[0]
	var command = args[1]
	var command_args = args.slice(2)
	
	# Find NPC and their ProximityAgent
	var npc_node = get_tree().get_node_or_null("//" + npc_id)
	if not npc_node:
		return {"success": false, "message": "NPC not found: " + npc_id}
	
	var proximity_agent = npc_node.get_node_or_null("ProximityAgent")
	if not proximity_agent:
		return {"success": false, "message": "ProximityAgent not found for NPC: " + npc_id}
	
	# Execute proximity command
	if proximity_agent.has_method("console_command"):
		return proximity_agent.console_command(command, command_args)
	else:
		return {"success": false, "message": "ProximityAgent does not support console commands"}

func _cmd_status_component(args: Array) -> Dictionary:
	if args.size() < 2:
		return {"success": false, "message": "Usage: status_component <npc_id> <command> [args...]"}
	
	var npc_id = args[0]
	var command = args[1]
	var command_args = args.slice(2)
	
	# Find NPC and their StatusComponent
	var npc_node = get_tree().get_node_or_null("//" + npc_id)
	if not npc_node:
		return {"success": false, "message": "NPC not found: " + npc_id}
	
	var status_component = npc_node.get_node_or_null("StatusComponent")
	if not status_component:
		return {"success": false, "message": "StatusComponent not found for NPC: " + npc_id}
	
	# Execute status component command
	if status_component.has_method("console_command"):
		return status_component.console_command(command, command_args)
	else:
		return {"success": false, "message": "StatusComponent does not support console commands"}

func _cmd_character(args: Array) -> Dictionary:
	if args.size() < 2:
		return {"success": false, "message": "Usage: character <npc_id> <command> [args...]"}
	
	var npc_id = args[0]
	var command = args[1]
	var command_args = args.slice(2)
	
	# Find NPC and their StatusComponent
	var npc_node = get_tree().get_node_or_null("//" + npc_id)
	if not npc_node:
		return {"success": false, "message": "NPC not found: " + npc_id}
	
	var status_component = npc_node.get_node_or_null("StatusComponent")
	if not status_component:
		return {"success": false, "message": "StatusComponent not found for NPC: " + npc_id}
	
	# Execute character command
	match command:
		"status":
			var full_status = status_component.get_full_status()
			var message = "Character Status for " + npc_id + ":\n"
			message += "  Name: " + full_status.name + "\n"
			message += "  Location: " + full_status.location + "\n"
			message += "  Action Drive: " + str(round(full_status.action_drive * 100)) + "%\n"
			message += "  Critical Needs: " + str(full_status.critical_needs.size()) + "\n"
			message += "  Top Priority: " + (full_status.need_priorities[0] if full_status.need_priorities.size() > 0 else "none")
			return {"success": true, "message": message}
		
		"needs":
			var needs_summary = status_component.get_needs_summary()
			var message = "Needs for " + npc_id + ":\n"
			for category in needs_summary.keys():
				message += "  " + category.capitalize() + ":\n"
				for need_type in needs_summary[category].keys():
					var value = needs_summary[category][need_type]
					message += "    " + need_type + ": " + str(round(value * 100)) + "%\n"
			return {"success": true, "message": message}
		
		"personality":
			var personality = status_component.personality
			var message = "Personality for " + npc_id + ":\n"
			message += "  Big Five:\n"
			for trait in personality.big_five.keys():
				var value = personality.big_five[trait]
				message += "    " + trait + ": " + str(round(value * 100)) + "%\n"
			message += "  Traits:\n"
			for trait in personality.traits.keys():
				var value = personality.traits[trait]
				message += "    " + trait + ": " + str(round(value * 100)) + "%\n"
			return {"success": true, "message": message}
		
		"set_location":
			if command_args.size() >= 1:
				var new_location = command_args[0]
				status_component.set_location(new_location)
				return {"success": true, "message": "Set " + npc_id + " location to " + new_location}
			return {"success": false, "message": "Usage: character <npc_id> set_location <location>"}
		
		"set_personality":
			if command_args.size() >= 3:
				var category = command_args[0]
				var trait = command_args[1]
				var value = float(command_args[2])
				status_component.set_personality_trait(category, trait, value)
				return {"success": true, "message": "Set " + category + "." + trait + " to " + str(value)}
			return {"success": false, "message": "Usage: character <npc_id> set_personality <category> <trait> <value>"}
		
		_:
			return {"success": false, "message": "Unknown character command: " + command}

func _cmd_action(args: Array) -> Dictionary:
	if args.size() < 2:
		return {"success": false, "message": "Usage: action <npc_id> <command> [args...]"}
	
	var npc_id = args[0]
	var command = args[1]
	var command_args = args.slice(2)
	
	# Find NPC and their ActionPlanner
	var npc_node = get_tree().get_node_or_null("//" + npc_id)
	if not npc_node:
		return {"success": false, "message": "NPC not found: " + npc_id}
	
	var action_planner = npc_node.get_node_or_null("ActionPlanner")
	if not action_planner:
		return {"success": false, "message": "ActionPlanner not found for NPC: " + npc_id}
	
	# Execute action command
	return action_planner.console_command(command, command_args)

func _cmd_execute(args: Array) -> Dictionary:
	if args.size() < 2:
		return {"success": false, "message": "Usage: execute <npc_id> <command> [args...]"}
	
	var npc_id = args[0]
	var command = args[1]
	var command_args = args.slice(2)
	
	# Find NPC and their ActionExecutor
	var npc_node = get_tree().get_node_or_null("//" + npc_id)
	if not npc_node:
		return {"success": false, "message": "NPC not found: " + npc_id}
	
	var action_executor = npc_node.get_node_or_null("ActionExecutor")
	if not action_executor:
		return {"success": false, "message": "ActionExecutor not found for NPC: " + npc_id}
	
	# Execute action execution command
	return action_executor.console_command(command, command_args)

func _cmd_population(args: Array) -> Dictionary:
	if args.is_empty():
		return {"success": false, "message": "Usage: population <command> [args...]"}
	
	var command = args[0]
	var command_args = args.slice(1)
	
	# Get CharacterManager reference
	var character_manager = get_node_or_null("/root/CharacterManager")
	if not character_manager:
		return {"success": false, "message": "CharacterManager not found"}
	
	match command:
		"count":
			var count = character_manager.get_character_count()
			return {"success": true, "message": "Population count: " + str(count)}
		
		"summary":
			var summary = character_manager.get_population_summary()
			var message = "Population Summary:\n"
			message += "Total: " + str(summary.total_count) + "\n"
			message += "By Location:\n"
			for location in summary.by_location:
				message += "  " + location + ": " + str(summary.by_location[location]) + "\n"
			message += "Urgent Needs:\n"
			message += "  Physical: " + str(summary.by_need_status.urgent_physical) + "\n"
			message += "  Social: " + str(summary.by_need_status.urgent_social) + "\n"
			message += "  Economic: " + str(summary.by_need_status.urgent_economic) + "\n"
			return {"success": true, "message": message}
		
		"export":
			var export_data = character_manager.export_population_data()
			var message = "Population exported at " + export_data.export_timestamp + "\n"
			message += "Characters: " + str(export_data.population_count)
			return {"success": true, "message": message}
		
		_:
			return {"success": false, "message": "Unknown population command: " + command}

func _cmd_character_manager(args: Array) -> Dictionary:
	if args.is_empty():
		return {"success": false, "message": "Usage: character_manager <command> [args...]"}
	
	var command = args[0]
	var command_args = args.slice(1)
	
	# Get CharacterManager reference
	var character_manager = get_node_or_null("/root/CharacterManager")
	if not character_manager:
		return {"success": false, "message": "CharacterManager not found"}
	
	match command:
		"list":
			var characters = character_manager.get_all_characters()
			var message = "Active Characters (" + str(characters.size()) + "):\n"
			for character_id in characters:
				var char = characters[character_id]
				message += "  " + character_id + " - " + char.name + " (" + char.occupation + ")\n"
			return {"success": true, "message": message}
		
		"get":
			if command_args.size() < 1:
				return {"success": false, "message": "Usage: character_manager get <character_id>"}
			var character_id = command_args[0]
			var character = character_manager.get_character(character_id)
			if character.is_empty():
				return {"success": false, "message": "Character not found: " + character_id}
			
			var message = "Character: " + character.name + "\n"
			message += "Occupation: " + character.occupation + "\n"
			message += "Location: " + character.get("location", "unknown") + "\n"
			message += "Drama Hook: " + character.drama_hook + "\n"
			return {"success": true, "message": message}
		
		"save":
			if command_args.size() < 1:
				return {"success": false, "message": "Usage: character_manager save <character_id>"}
			var character_id = command_args[0]
			var success = character_manager.save_character(character_id)
			if success:
				return {"success": true, "message": "Character saved: " + character_id}
			else:
				return {"success": false, "message": "Failed to save character: " + character_id}
		
		"save_all":
			character_manager.save_all_characters()
			return {"success": true, "message": "All characters saved"}
		
		"create":
			if command_args.size() < 1:
				return {"success": false, "message": "Usage: character_manager create <character_id>"}
			var character_id = command_args[0]
			var character = character_manager.create_character_from_template(character_id)
			if not character.is_empty():
				return {"success": true, "message": "Character created: " + character_id}
			else:
				return {"success": false, "message": "Failed to create character: " + character_id}
		
		"delete":
			if command_args.size() < 1:
				return {"success": false, "message": "Usage: character_manager delete <character_id>"}
			var character_id = command_args[0]
			var success = character_manager.delete_character(character_id)
			if success:
				return {"success": true, "message": "Character deleted: " + character_id}
			else:
				return {"success": false, "message": "Failed to delete character: " + character_id}
		
		"by_location":
			if command_args.size() < 1:
				return {"success": false, "message": "Usage: character_manager by_location <location>"}
			var location = command_args[0]
			var characters = character_manager.get_characters_by_location(location)
			var message = "Characters at " + location + " (" + str(characters.size()) + "):\n"
			for character_id in characters:
				message += "  " + character_id + "\n"
			return {"success": true, "message": message}
		

		
		"by_need":
			if command_args.size() < 3:
				return {"success": false, "message": "Usage: character_manager by_need <category> <need_name> [threshold]"}
			var category = command_args[0]
			var need_name = command_args[1]
			var threshold = 0.3
			if command_args.size() >= 3:
				threshold = float(command_args[2])
			var characters = character_manager.get_characters_by_need(category, need_name, threshold)
			var message = "Characters with " + category + "." + need_name + " <= " + str(threshold) + " (" + str(characters.size()) + "):\n"
			for character_id in characters:
				message += "  " + character_id + "\n"
			return {"success": true, "message": message}
		
		_:
			return {"success": false, "message": "Unknown character_manager command: " + command}

func _cmd_environment(args: Array) -> Dictionary:
	"""Handle environment commands"""
	if args.size() < 1:
		return {"success": false, "message": "Usage: environment <command> [args...]"}
	
	var command = args[0]
	var command_args = args.slice(1)
	
	match command:
		"status":
			# Show overall environmental status
			var message = "=== Environmental Status ===\n"
			message += "Current time: " + Time.get_datetime_string_from_system() + "\n"
			message += "Season: Summer (default)\n"
			message += "Weather: Clear (default)\n"
			message += "Global temperature: 20°C\n"
			return {"success": true, "message": message}
		
		"locations":
			# Show available locations and their effects
			var message = "=== Available Locations ===\n"
			var locations = [
				"home", "workplace", "outdoors", "kitchen", "bedroom", 
				"workshop", "fishing_docks", "whispering_woods", 
				"stone_circle", "lighthouse"
			]
			for location in locations:
				message += "  " + location + "\n"
			return {"success": true, "message": message}
		
		"effects":
			# Show environmental effects on a specific character
			if command_args.size() < 1:
				return {"success": false, "message": "Usage: environment effects <character_id>"}
			var character_id = command_args[0]
			
			# Get character's environmental sensor
			var character_manager = get_node("/root/CharacterManager")
			var sensor = character_manager.get_environmental_sensor(character_id)
			
			if sensor:
				var location_effects = sensor.get_location_effects()
				var weather_info = sensor.get_weather_info()
				var time_period = sensor.get_time_period()
				var season = sensor.get_season()
				
				var message = "=== Environmental Effects for " + character_id + " ===\n"
				message += "Location: " + sensor.current_location + "\n"
				message += "Location Effects: " + str(location_effects) + "\n"
				message += "Weather: " + weather_info.type + " (" + str(weather_info.temperature) + "°C)\n"
				message += "Time Period: " + time_period + "\n"
				message += "Season: " + season + "\n"
				return {"success": true, "message": message}
			else:
				return {"success": false, "message": "No environmental sensor found for character: " + character_id}
		
		_:
			return {"success": false, "message": "Unknown environment command: " + command}

func _cmd_weather(args: Array) -> Dictionary:
	"""Handle weather commands"""
	if args.size() < 1:
		return {"success": false, "message": "Usage: weather <command> [args...]"}
	
	var command = args[0]
	var command_args = args.slice(1)
	
	match command:
		"status":
			# Show current weather status
			var message = "=== Weather Status ===\n"
			message += "Type: Clear (default)\n"
			message += "Temperature: 20°C\n"
			message += "Humidity: 50%\n"
			message += "Wind: 5 km/h\n"
			message += "Precipitation: 0%\n"
			return {"success": true, "message": "Weather status displayed"}
		
		"set":
			if command_args.size() < 1:
				return {"success": false, "message": "Usage: weather set <type>"}
			var weather_type = command_args[0]
			
			# Set weather for all characters (global weather)
			var character_manager = get_node("/root/CharacterManager")
			var message = "Setting weather to: " + weather_type + "\n"
			
			# Update all environmental sensors
			for character_id in character_manager.active_characters:
				var sensor = character_manager.get_environmental_sensor(character_id)
				if sensor:
					var result = sensor.console_command("set_weather", [weather_type])
					if result.success:
						message += "  " + character_id + ": " + result.message + "\n"
					else:
						message += "  " + character_id + ": " + result.error + "\n"
			
			return {"success": true, "message": message}
		
		"types":
			# Show available weather types
			var message = "=== Available Weather Types ===\n"
			var types = ["clear", "sunny", "cloudy", "rain", "storm", "fog", "windy"]
			for type_name in types:
				message += "  " + type_name + "\n"
			return {"success": true, "message": message}
		
		_:
			return {"success": false, "message": "Unknown weather command: " + command}

func _cmd_time(args: Array) -> Dictionary:
	"""Handle time commands"""
	if args.size() < 1:
		return {"success": false, "message": "Usage: time <command> [args...]"}
	
	var command = args[0]
	var command_args = args.slice(1)
	
	match command:
		"status":
			# Show current time status
			var current_time = Time.get_time_dict_from_system()
			var message = "=== Time Status ===\n"
			message += "Current time: " + str(current_time.hour) + ":" + str(current_time.minute) + "\n"
			message += "Period: Afternoon (default)\n"
			message += "Season: Summer (default)\n"
			return {"success": true, "message": message}
		
		"set_season":
			if command_args.size() < 1:
				return {"success": false, "message": "Usage: time set_season <season>"}
			var season = command_args[0]
			
			# Set season for all characters
			var character_manager = get_node("/root/CharacterManager")
			var message = "Setting season to: " + season + "\n"
			
			# Update all environmental sensors
			for character_id in character_manager.active_characters:
				var sensor = character_manager.get_environmental_sensor(character_id)
				if sensor:
					var result = sensor.console_command("set_season", [season])
					if result.success:
						message += "  " + character_id + ": " + result.message + "\n"
					else:
						message += "  " + character_id + ": " + result.message + "\n"
			
			return {"success": true, "message": message}
		
		"seasons":
			# Show available seasons
			var message = "=== Available Seasons ===\n"
			var seasons = ["spring", "summer", "autumn", "winter"]
			for season_name in seasons:
				message += "  " + season_name + "\n"
			return {"success": true, "message": "Available seasons displayed"}
		
		_:
			return {"success": false, "message": "Unknown time command: " + command}

func _cmd_clear(args: Array) -> Dictionary:
	output_panel.clear()
	return {"success": true, "message": "Console cleared"}

# Input handling for command history
func _input(event):
	if event.is_action_pressed("ui_up") and command_input.has_focus():
		_navigate_history(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down") and command_input.has_focus():
		_navigate_history(1)
		get_viewport().set_input_as_handled()

func _navigate_history(direction: int):
	if command_history.is_empty():
		return
	
	history_index += direction
	
	if history_index >= command_history.size():
		history_index = command_history.size() - 1
	elif history_index < -1:
		history_index = -1
	
	if history_index == -1:
		command_input.clear()
	else:
		command_input.text = command_history[command_history.size() - 1 - history_index]
		command_input.caret_column = command_input.text.length()
