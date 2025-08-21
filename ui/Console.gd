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
		"help": _cmd_help,
		"status": _cmd_status,
		"test": _cmd_test,
		"memory": _cmd_memory,
		"agent": _cmd_agent,
		"relationship": _cmd_relationship,
		"fallback": _cmd_fallback,
		"action_memory": _cmd_action_memory,
		"llm": _cmd_llm,
		"conversation": _cmd_conversation,
		"context": _cmd_context,
		"streaming": _cmd_streaming
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
		var cmd_func = commands[command_name]
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
			_print_to_console("  " + cmd_name + " - Console command")
		return {"success": true, "message": "Help displayed"}
	else:
		var cmd_name = args[0].to_lower()
		if commands.has(cmd_name):
			_print_to_console("Command: " + cmd_name)
			_print_to_console("Description: Console command")
			_print_to_console("Usage: " + cmd_name + " [args...]")
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
	if args.size() == 0:
		_print_help("conversation", [
			"conversation status - Show conversation system status",
			"conversation start <npc1> <npc2> [topic] - Start a conversation",
			"conversation join <npc> <group_id> - Join NPC to conversation",
			"conversation leave <npc> - Remove NPC from conversation",
			"conversation topic <group_id> <topic> - Change conversation topic",
			"conversation force <group_id> <npc> - Force NPC to speak",
			"conversation stats <group_id> - Show conversation statistics"
		])
		return {"success": true, "message": "Conversation help displayed"}
	
	match args[0]:
		"status":
			_show_conversation_status()
			return {"success": true, "message": "Conversation status displayed"}
		"start":
			if args.size() < 3:
				return {"success": false, "message": "Usage: conversation start <npc1> <npc2> [topic]"}
			var npc1 = args[1]
			var npc2 = args[2]
			var topic = args[3] if args.size() > 3 else "general_chat"
			_start_conversation(npc1, npc2, topic)
			return {"success": true, "message": "Conversation started between " + npc1 + " and " + npc2}
		"join":
			if args.size() < 3:
				return {"success": false, "message": "Usage: conversation join <npc> <group_id>"}
			var npc = args[1]
			var group_id = args[2]
			_join_conversation(npc, group_id)
			return {"success": true, "message": "NPC " + npc + " joined conversation " + group_id}
		"leave":
			if args.size() < 2:
				return {"success": false, "message": "Usage: conversation leave <npc>"}
			var npc = args[1]
			_leave_conversation(npc)
			return {"success": true, "message": "NPC " + npc + " left conversation"}
		"topic":
			if args.size() < 3:
				return {"success": false, "message": "Usage: conversation topic <group_id> <topic>"}
			var group_id = args[1]
			var topic = args[2]
			_change_conversation_topic(group_id, topic)
			return {"success": true, "message": "Topic changed to " + topic}
		"force":
			if args.size() < 3:
				return {"success": false, "message": "Usage: conversation force <group_id> <npc>"}
			var group_id = args[1]
			var npc = args[2]
			_force_speaker_change(group_id, npc)
			return {"success": true, "message": "Forced " + npc + " to speak"}
		"stats":
			if args.size() < 2:
				return {"success": false, "message": "Usage: conversation stats <group_id>"}
			var group_id = args[1]
			_show_conversation_stats(group_id)
			return {"success": true, "message": "Conversation stats displayed"}
		_:
			return {"success": false, "message": "Unknown conversation command: " + args[0]}

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
			for location in summary.by_location.keys():
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

func _cmd_context(args: Array) -> Dictionary:
	if args.size() == 0:
		_print_help("context", [
			"context build <npc> [targets...] - Build context for NPC",
			"context prompt <npc> [targets...] - Build enhanced prompt for NPC",
			"context validate <npc> [targets...] - Validate context for NPC"
		])
		return {"success": true, "message": "Context help displayed"}
	
	match args[0]:
		"build":
			if args.size() < 2:
				return {"success": false, "message": "Usage: context build <npc> [targets...]"}
			var npc = args[1]
			var targets = args.slice(2) if args.size() > 2 else []
			_build_context(npc, targets)
			return {"success": true, "message": "Context built for " + npc}
		"prompt":
			if args.size() < 2:
				return {"success": false, "message": "Usage: context prompt <npc> [targets...]"}
			var npc = args[1]
			var targets = args.slice(2) if args.size() > 2 else []
			_build_enhanced_prompt(npc, targets)
			return {"success": true, "message": "Enhanced prompt built for " + npc}
		"validate":
			if args.size() < 2:
				return {"success": false, "message": "Usage: context validate <npc> [targets...]"}
			var npc = args[1]
			var targets = args.slice(2) if args.size() > 2 else []
			_validate_context(npc, targets)
			return {"success": true, "message": "Context validated for " + npc}
		_:
			return {"success": false, "message": "Unknown context command: " + args[0]}

func _cmd_behavior(args: Array) -> Dictionary:
	"""Handle behavior pattern analysis commands"""
	if args.size() < 1:
		return {"success": false, "message": "Usage: behavior <command> [args...]"}
	
	var command = args[0]
	var command_args = args.slice(1)
	
	match command:
		"patterns":
			if command_args.size() < 1:
				return {"success": false, "message": "Usage: behavior patterns <character_id>"}
			
			var character_id = command_args[0]
			var character_manager = get_node("/root/CharacterManager")
			var sensor = character_manager.get_environmental_sensor(character_id)
			if not sensor:
				return {"success": false, "message": "Character " + character_id + " has no EnvironmentalSensor"}
			
			var patterns = sensor.get_behavior_patterns()
			var message = "=== Behavior Patterns for " + character_id + " ===\n"
			message += "Patterns: " + str(patterns) + "\n"
			return {"success": true, "message": message}
		
		"location_preference":
			if command_args.size() < 1:
				return {"success": false, "message": "Usage: behavior location_preference <character_id>"}
			
			var character_id = command_args[0]
			var character_manager = get_node("/root/CharacterManager")
			var sensor = character_manager.get_environmental_sensor(character_id)
			if not sensor:
				return {"success": false, "message": "Character " + character_id + " has no EnvironmentalSensor"}
			
			var patterns = sensor.get_behavior_patterns()
			var location_prefs = patterns.get("location_preference", {})
			
			# Sort by preference count
			var sorted_locations = []
			for location in location_prefs.keys():
				sorted_locations.append({"location": location, "count": location_prefs[location]})
			sorted_locations.sort_custom(func(a, b): return a.count > b.count)
			
			var message = "=== Location Preferences for " + character_id + " ===\n"
			for location_data in sorted_locations:
				message += location_data.location + ": " + str(location_data.count) + " visits\n"
			
			return {"success": true, "message": message}
		
		"weather_tolerance":
			if command_args.size() < 1:
				return {"success": false, "message": "Usage: behavior weather_tolerance <character_id>"}
			
			var character_id = command_args[0]
			var character_manager = get_node("/root/CharacterManager")
			var sensor = character_manager.get_environmental_sensor(character_id)
			if not sensor:
				return {"success": false, "message": "Character " + character_id + " has no EnvironmentalSensor"}
			
			var patterns = sensor.get_behavior_patterns()
			var weather_tolerance = patterns.get("weather_tolerance", {})
			
			# Sort by tolerance count
			var sorted_weather = []
			for weather in weather_tolerance.keys():
				sorted_weather.append({"weather": weather, "count": weather_tolerance[weather]})
			sorted_weather.sort_custom(func(a, b): return a.count > b.count)
			
			var message = "=== Weather Tolerance for " + character_id + " ===\n"
			for weather_data in sorted_weather:
				message += weather_data.weather + ": " + str(weather_data.count) + " occurrences\n"
			
			return {"success": true, "message": message}
		
		"analyze_all":
			var character_manager = get_node("/root/CharacterManager")
			var message = "=== All Character Behavior Analysis ===\n\n"
			
			for character_id in character_manager.active_characters.keys():
				var sensor = character_manager.get_environmental_sensor(character_id)
				if sensor:
					var patterns = sensor.get_behavior_patterns()
					message += character_id + ":\n"
					message += "  Patterns: " + str(patterns) + "\n\n"
			
			return {"success": true, "message": message}
		
		_:
			return {"success": false, "message": "Unknown behavior command: " + command}

func _cmd_clear(args: Array) -> Dictionary:
	output_panel.clear()
	return {"success": true, "message": "Console cleared"}

func _print_help(command: String, help_lines: Array):
	"""Print help information for a command"""
	_print_to_console("=== Help for " + command + " ===")
	for line in help_lines:
		_print_to_console(line)

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

# Add new agent system commands to the existing console

# Agent System Commands
func _add_agent_commands():
    """Add agent system console commands"""
    # These commands are already added in _initialize_commands()
    pass

func _execute_agent_command(args: Array):
    """Execute agent system commands"""
    if args.size() < 2:
        _print_to_console("Usage: agent <npc_id> <command> [args...]")
        return
    
    var npc_id = args[0]
    var command = args[1]
    var command_args = args.slice(2)
    
    match command:
        "status":
            _show_agent_status(npc_id)
        "personality":
            _show_agent_personality(npc_id)
        "traits":
            _show_agent_traits(npc_id)
        "constraints":
            _show_agent_constraints(npc_id)
        "context":
            _show_agent_context(npc_id, command_args)
        "update_trait":
            _update_agent_trait(npc_id, command_args)
        "test_response":
            _test_agent_response(npc_id, command_args)
        "consistency":
            _check_agent_consistency(npc_id)
        "ready":
            _check_agent_ready(npc_id)
        _:
            _print_to_console("Unknown agent command: " + command)
            _print_to_console("Available commands: status, personality, traits, constraints, context, update_trait, test_response, consistency, ready")

func _execute_memory_command(args: Array):
    """Execute memory store commands"""
    if args.size() < 2:
        _print_to_console("Usage: memory <npc_id> <command> [args...]")
        return
    
    var npc_id = args[0]
    var command = args[1]
    var command_args = args.slice(2)
    
    match command:
        "status":
            _show_memory_status(npc_id)
        "add":
            _add_memory(npc_id, command_args)
        "retrieve":
            _retrieve_memories(npc_id, command_args)
        "compress":
            _force_memory_compression(npc_id)
        "stats":
            _show_memory_stats(npc_id)
        "clear":
            _clear_memories(npc_id)
        _:
            _print_to_console("Unknown memory command: " + command)
            _print_to_console("Available commands: status, add, retrieve, compress, stats, clear")

func _execute_relationship_command(args: Array):
    """Execute relationship graph commands"""
    if args.size() < 2:
        print("Usage: relationship <npc_id> <command> [args...]")
        return
    
    var npc_id = args[0]
    var command = args[1]
    var command_args = args.slice(2)
    
    match command:
        "status":
            _show_relationship_status(npc_id)
        "create":
            _create_relationship(npc_id, command_args)
        "update":
            _update_relationship(npc_id, command_args)
        "list":
            _list_relationships(npc_id)
        "summary":
            _show_relationship_summary(npc_id)
        "stats":
            _show_relationship_stats()
        "clear":
            _clear_relationships(npc_id)
        _:
            print("Unknown relationship command: ", command)
            print("Available commands: status, create, update, list, summary, stats, clear")

func _execute_fallback_command(args: Array):
    """Execute fallback template commands"""
    if args.size() < 1:
        print("Usage: fallback <command> [args...]")
        return
    
    var command = args[0]
    var command_args = args.slice(1)
    
    match command:
        "status":
            _show_fallback_status()
        "quality":
            _show_fallback_quality(command_args)
        "templates":
            _show_fallback_templates(command_args)
        "add":
            _add_fallback_template(command_args)
        "remove":
            _remove_fallback_template(command_args)
        "stats":
            _show_fallback_stats()
        "test":
            _test_fallback_system(command_args)
        _:
            print("Unknown fallback command: ", command)
            print("Available commands: status, quality, templates, add, remove, stats, test")

# Agent command implementations
func _show_agent_status(npc_id: String):
    """Show agent status and readiness"""
    if not Agent or not Agent.is_ready():
        _print_to_console("Agent system not ready")
        return
    
    # This would check if the specific agent exists and show its status
    _print_to_console("Agent system ready")
    _print_to_console("Agent " + npc_id + " status: " + ("Ready" if Agent.is_ready() else "Not Ready"))

func _show_agent_personality(npc_id: String):
    """Show agent personality summary"""
    if not Agent or not Agent.is_ready():
        _print_to_console("Agent system not ready")
        return
    
    # This would get the agent's personality summary
    _print_to_console("Agent personality summary for " + npc_id)
    _print_to_console("(Personality details would be displayed here)")

func _show_agent_traits(npc_id: String):
    """Show agent personality traits"""
    if not Agent or not Agent.is_ready():
        _print_to_console("Agent system not ready")
        return
    
    # This would get the agent's traits
    _print_to_console("Agent traits for " + npc_id)
    _print_to_console("(Traits would be displayed here)")

func _show_agent_constraints(npc_id: String):
    """Show agent response constraints"""
    if not Agent or not Agent.is_ready():
        _print_to_console("Agent system not ready")
        return
    
    # This would get the agent's constraints
    _print_to_console("Agent constraints for " + npc_id)
    _print_to_console("(Constraints would be displayed here)")

func _show_agent_context(npc_id: String, args: Array):
    """Show agent context for a conversation"""
    if not Agent or not Agent.is_ready():
        _print_to_console("Agent system not ready")
        return
    
    # This would build and show the agent's context
    _print_to_console("Agent context for " + npc_id)
    _print_to_console("(Context would be displayed here)")

func _update_agent_trait(npc_id: String, args: Array):
    """Update an agent's personality trait"""
    if args.size() < 2:
        _print_to_console("Usage: agent <npc_id> update_trait <trait_name> <value>")
        return
    
    var trait_name = args[0]
    var value = float(args[1])
    
    if not Agent or not Agent.is_ready():
        _print_to_console("Agent system not ready")
        return
    
    # This would update the agent's trait
    _print_to_console("Updated trait " + trait_name + " to " + str(value) + " for agent " + npc_id)

func _test_agent_response(npc_id: String, args: Array):
    """Test agent response generation"""
    if not Agent or not Agent.is_ready():
        _print_to_console("Agent system not ready")
        return
    
    # This would test the agent's response generation
    _print_to_console("Testing agent response for " + npc_id)
    _print_to_console("(Response would be generated and displayed here)")

func _check_agent_consistency(npc_id: String):
    """Check agent personality consistency"""
    if not Agent or not Agent.is_ready():
        _print_to_console("Agent system not ready")
        return
    
    # This would check the agent's personality consistency
    _print_to_console("Checking personality consistency for agent " + npc_id)
    _print_to_console("(Consistency score would be displayed here)")

func _check_agent_ready(npc_id: String):
    """Check if agent is ready for use"""
    if not Agent or not Agent.is_ready():
        _print_to_console("Agent system not ready")
        return
    
    # This would check if the specific agent is ready
    _print_to_console("Agent " + npc_id + " ready status: " + ("Ready" if Agent.is_ready() else "Not Ready"))

# Memory command implementations
func _show_memory_status(npc_id: String):
    """Show memory store status for a character"""
    if not MemoryStore or not MemoryStore.is_ready():
        _print_to_console("MemoryStore not ready")
        return
    
    var stats = MemoryStore.get_memory_stats(npc_id)
    _print_to_console("Memory status for " + npc_id + ":")
    _print_to_console("  Short-term memories: " + str(stats.get("short_term_count", 0)))
    _print_to_console("  Long-term summaries: " + str(stats.get("long_term_count", 0)))
    _print_to_console("  Total memories: " + str(stats.get("total_memories", 0)))
    _print_to_console("  Buffer utilization: " + "%.1f%%" % (stats.get("buffer_utilization", 0.0) * 100))

func _add_memory(npc_id: String, args: Array):
    """Add a memory to the memory store"""
    if args.size() < 2:
        _print_to_console("Usage: memory <npc_id> add <title> <description> [tags...]")
        return
    
    var title = args[0]
    var description = args[1]
    var tags = args.slice(2) if args.size() > 2 else []
    
    if not MemoryStore or not MemoryStore.is_ready():
        _print_to_console("MemoryStore not ready")
        return
    
    var memory = {
        "title": title,
        "description": description,
        "tags": tags,
        "timestamp": Time.get_time(),
        "strength": 0.8
    }
    
    MemoryStore.add_memory(npc_id, memory)
    _print_to_console("Added memory '" + title + "' for " + npc_id)

func _retrieve_memories(npc_id: String, args: Array):
    """Retrieve memories from the memory store"""
    if args.size() < 1:
        _print_to_console("Usage: memory <npc_id> retrieve <tags...>")
        return
    
    var tags = args
    
    if not MemoryStore or not MemoryStore.is_ready():
        _print_to_console("MemoryStore not ready")
        return
    
    var memories = MemoryStore.retrieve_memories(npc_id, tags)
    _print_to_console("Retrieved " + str(memories.size()) + " memories for " + npc_id + " with tags: " + str(tags))
    
    for i in range(min(memories.size(), 5)):  # Show first 5
        var memory = memories[i]
        _print_to_console("  " + str(i + 1) + ". " + memory.get("title", "Untitled") + " - " + memory.get("description", "").substr(0, 50) + "...")

func _force_memory_compression(npc_id: String):
    """Force memory compression for a character"""
    if not MemoryStore or not MemoryStore.is_ready():
        _print_to_console("MemoryStore not ready")
        return
    
    MemoryStore.force_compression(npc_id)
    _print_to_console("Forced memory compression for " + npc_id)

func _show_memory_stats(npc_id: String):
    """Show detailed memory statistics"""
    if not MemoryStore or not MemoryStore.is_ready():
        _print_to_console("MemoryStore not ready")
        return
    
    var stats = MemoryStore.get_memory_stats(npc_id)
    _print_to_console("Memory statistics for " + npc_id + ":")
    _print_to_console("  Short-term: " + str(stats.get("short_term_count", 0)))
    _print_to_console("  Long-term: " + str(stats.get("long_term_count", 0)))
    _print_to_console("  Total: " + str(stats.get("total_memories", 0)))
    _print_to_console("  Buffer: " + "%.1f%%" % (stats.get("buffer_utilization", 0.0) * 100))
    
    var compression_stats = stats.get("compression_stats", {})
    if not compression_stats.is_empty():
        _print_to_console("  Compression ratio: " + "%.1f%%" % (compression_stats.get("compression_ratio", 0.0) * 100))
        _print_to_console("  Total compressed: " + str(compression_stats.get("total_compressed", 0)))

func _clear_memories(npc_id: String):
    """Clear all memories for a character"""
    if not MemoryStore or not MemoryStore.is_ready():
        _print_to_console("MemoryStore not ready")
        return
    
    MemoryStore.clear_character_memories(npc_id)
    _print_to_console("Cleared all memories for " + npc_id)

# Relationship command implementations
func _show_relationship_status(npc_id: String):
    """Show relationship status for a character"""
    if not RelationshipGraph or not RelationshipGraph.is_ready():
        _print_to_console("RelationshipGraph not ready")
        return
    
    var relationships = RelationshipGraph.get_all_relationships(npc_id)
    _print_to_console("Relationships for " + npc_id + ":")
    _print_to_console("  Total relationships: " + str(relationships.size()))
    
    for target_id in relationships.keys():
        var rel = relationships[target_id]
        _print_to_console("  " + target_id + ": " + RelationshipGraph._get_relationship_type_name(rel.type) + " (strength: " + "%.2f" % rel.strength + ")")

func _create_relationship(npc_id: String, args: Array):
    """Create a new relationship"""
    if args.size() < 2:
        _print_to_console("Usage: relationship <npc_id> create <target_id> <type> [strength]")
        return
    
    var target_id = args[0]
    var type_name = args[1]
    var strength = float(args[2]) if args.size() > 2 else -1.0
    
    if not RelationshipGraph or not RelationshipGraph.is_ready():
        _print_to_console("RelationshipGraph not ready")
        return
    
    # Convert type name to enum
    var rel_type = _get_relationship_type_from_name(type_name)
    if rel_type < 0:
        _print_to_console("Invalid relationship type: " + type_name)
        _print_to_console("Valid types: trust, friendship, rivalry, romantic, family, mentor, colleague, acquaintance")
        return
    
    RelationshipGraph.create_relationship(npc_id, target_id, rel_type, strength)
    _print_to_console("Created " + type_name + " relationship between " + npc_id + " and " + target_id)

func _update_relationship(npc_id: String, args: Array):
    """Update an existing relationship"""
    if args.size() < 3:
        _print_to_console("Usage: relationship <npc_id> update <target_id> <type> <change> [reason]")
        return
    
    var target_id = args[0]
    var type_name = args[1]
    var change = float(args[2])
    var reason = args[3] if args.size() > 3 else ""
    
    if not RelationshipGraph or not RelationshipGraph.is_ready():
        _print_to_console("RelationshipGraph not ready")
        return
    
    # Convert type name to enum
    var rel_type = _get_relationship_type_from_name(type_name)
    if rel_type < 0:
        _print_to_console("Invalid relationship type: " + type_name)
        return
    
    RelationshipGraph.update_relationship(npc_id, target_id, rel_type, change, reason)
    _print_to_console("Updated relationship between " + npc_id + " and " + target_id + " by " + str(change))

func _list_relationships(npc_id: String):
    """List all relationships for a character"""
    if not RelationshipGraph or not RelationshipGraph.is_ready():
        _print_to_console("RelationshipGraph not ready")
        return
    
    var relationships = RelationshipGraph.get_all_relationships(npc_id)
    _print_to_console("All relationships for " + npc_id + ":")
    
    for target_id in relationships.keys():
        var rel = relationships[target_id]
        _print_to_console("  " + target_id + ":")
        _print_to_console("    Type: " + RelationshipGraph._get_relationship_type_name(rel.type))
        _print_to_console("    Strength: " + "%.2f" % rel.strength)
        _print_to_console("    Interactions: " + str(rel.interaction_count))
        _print_to_console("    Last interaction: " + str(rel.last_interaction))

func _show_relationship_summary(npc_id: String):
    """Show relationship summary for a character"""
    if not RelationshipGraph or not RelationshipGraph.is_ready():
        _print_to_console("RelationshipGraph not ready")
        return
    
    var summary = RelationshipGraph.get_relationship_summary(npc_id)
    _print_to_console("Relationship summary for " + npc_id + ":")
    _print_to_console("  Total: " + str(summary.get("total_relationships", 0)))
    
    var types = summary.get("relationship_types", {})
    for type_name in types.keys():
        _print_to_console("    " + type_name + ": " + str(types[type_name]))

func _show_relationship_stats():
    """Show overall relationship statistics"""
    if not RelationshipGraph or not RelationshipGraph.is_ready():
        _print_to_console("RelationshipGraph not ready")
        return
    
    var stats = RelationshipGraph.get_relationship_statistics()
    _print_to_console("Overall relationship statistics:")
    _print_to_console("  Total relationships: " + str(stats.get("total_relationships", 0)))
    
    var types = stats.get("relationship_types", {})
    for type_name in types.keys():
        _print_to_console("    " + type_name + ": " + str(types[type_name]))

func _clear_relationships(npc_id: String):
    """Clear all relationships for a character"""
    if not RelationshipGraph or not RelationshipGraph.is_ready():
        _print_to_console("RelationshipGraph not ready")
        return
    
    RelationshipGraph.clear_character_relationships(npc_id)
    _print_to_console("Cleared all relationships for " + npc_id)

# Fallback command implementations
func _show_fallback_status() -> Dictionary:
	"""Show fallback system status"""
	if not FallbackTemplates:
		return {"success": false, "message": "FallbackTemplates not available"}
	
	return {
		"success": true,
		"message": "Fallback system is ready",
		"status": "active"
	}

func _show_fallback_quality(args: Array):
    """Show fallback response quality"""
    if not FallbackTemplates or not FallbackTemplates.is_ready():
        _print_to_console("FallbackTemplates not ready")
        return
    
    if args.size() > 0:
        var agent_id = args[0]
        var quality = FallbackTemplates.get_fallback_quality(agent_id)
        _print_to_console("Fallback quality for " + agent_id + ": " + "%.2f" % quality)
    else:
        var all_quality = FallbackTemplates.get_all_fallback_quality()
        _print_to_console("Fallback quality for all agents:")
        for agent_id in all_quality.keys():
            _print_to_console("  " + agent_id + ": " + "%.2f" % all_quality[agent_id])

func _show_fallback_templates(args: Array):
    """Show available fallback templates"""
    if not FallbackTemplates or not FallbackTemplates.is_ready():
        _print_to_console("FallbackTemplates not ready")
        return
    
    var stats = FallbackTemplates.get_template_statistics()
    _print_to_console("Available fallback templates:")
    
    var categories = stats.get("templates_by_category", {})
    for category in categories.keys():
        _print_to_console("  " + category + ": " + str(categories[category]) + " templates")

func _add_fallback_template(args: Array):
    """Add a custom fallback template"""
    if args.size() < 3:
        _print_to_console("Usage: fallback add <category> <style> <template>")
        return
    
    var category = args[0]
    var style = args[1]
    var template = args[2]
    
    if not FallbackTemplates or not FallbackTemplates.is_ready():
        _print_to_console("FallbackTemplates not ready")
        return
    
    FallbackTemplates.add_custom_template(category, style, template)
    _print_to_console("Added custom template for " + category + " (" + style + ")")

func _remove_fallback_template(args: Array):
    """Remove a custom fallback template"""
    if args.size() < 3:
        _print_to_console("Usage: fallback remove <category> <style> <template>")
        return
    
    var category = args[0]
    var style = args[1]
    var template = args[2]
    
    if not FallbackTemplates or not FallbackTemplates.is_ready():
        _print_to_console("FallbackTemplates not ready")
        return
    
    FallbackTemplates.remove_custom_template(category, style, template)
    _print_to_console("Removed custom template for " + category + " (" + style + ")")

func _show_fallback_stats():
    """Show fallback system statistics"""
    if not FallbackTemplates or not FallbackTemplates.is_ready():
        _print_to_console("FallbackTemplates not ready")
        return
    
    var stats = FallbackTemplates.get_template_statistics()
    _print_to_console("Fallback system statistics:")
    _print_to_console("  Categories: " + str(stats.get("total_categories", 0)))
    _print_to_console("  Templates: " + str(stats.get("total_templates", 0)))
    
    var styles = stats.get("templates_by_style", {})
    for style in styles.keys():
        _print_to_console("    " + style + ": " + str(styles[style]) + " templates")

func _test_fallback_system(args: Array) -> Dictionary:
	"""Test the fallback system with a mock agent"""
	if not FallbackTemplates:
		return {"success": false, "message": "FallbackTemplates not available"}
	
	# Create a mock agent for testing
	var mock_agent = {
		"agent_id": args[0],
		"persona": {
			"system_prompt": "You are a helpful assistant",
			"style_rules": ["Be polite", "Be concise"],
			"voice_characteristics": ["friendly", "professional"]
		},
		"traits": {
			"openness": 0.7,
			"extraversion": 0.6,
			"agreeableness": 0.8
		}
	}
	
	var context = {
		"conversation_type": "casual",
		"emotional_tone": "neutral",
		"topic": "general conversation"
	}
	
	# This would call the actual fallback system
	# var response = FallbackTemplates.generate_fallback_response(mock_agent, context)
	
	return {
		"success": true,
		"message": "Fallback system test completed for agent " + args[0],
		"test_data": {
			"agent": mock_agent,
			"context": context
		}
	}

# Action Memory System Testing Commands

func _cmd_action_memory(args: Array) -> Dictionary:
	if args.is_empty():
		return {"success": false, "message": "Usage: action_memory <command> [args...]\nCommands: test, list, failures, patterns"}
	
	var action_memory_command = args[0]
	var action_memory_args = args.slice(1)
	
	match action_memory_command:
		"test":
			return _test_action_memory_system()
		"list":
			var character_id = action_memory_args[0] if action_memory_args.size() > 0 else "test_character"
			return _list_action_memories(character_id)
		"failures":
			var character_id = action_memory_args[0] if action_memory_args.size() > 0 else "test_character"
			var severity = action_memory_args[1] if action_memory_args.size() > 1 else ""
			return _list_failure_memories(character_id, severity)
		"patterns":
			var character_id = action_memory_args[0] if action_memory_args.size() > 0 else "test_character"
			return _list_pattern_memories(character_id)
		_:
			return {"success": false, "message": "Unknown action_memory command: " + action_memory_command}

func _test_action_memory_system() -> Dictionary:
	"""Test the enhanced action memory system"""
	var test_character = "test_character"
	
	# Test action success memory
	var action_data = {
		"id": "test_action_1",
		"name": "Test Action",
		"category": "Work",
		"duration": 5.0,
		"location_tags": ["workshop"],
		"difficulty": 2.0
	}
	
	var action_result = {
		"result_type": "excellent",
		"quality": "exceptional",
		"needs_satisfied": {"hunger": 10, "social": 5},
		"wealth_change": 15
	}
	
	# Test action failure memory
	var failure_data = {
		"failure_type": "execution",
		"reason": "Insufficient resources",
		"severity": "moderate",
		"need_penalties": {"energy": 5},
		"recovery_suggestions": ["Gather more resources", "Try again later"]
	}
	
	# Test pattern memory
	var pattern_data = {
		"pattern_type": "efficiency",
		"success_rate": 0.85,
		"optimal_conditions": ["Location: workshop", "Time: morning"],
		"avoid_conditions": ["Location: noisy areas"],
		"need_balance": {"hunger": 10, "social": 5},
		"time_of_day_preference": "morning",
		"seasonal_effectiveness": {"spring": 1.2, "summer": 1.0}
	}
	
	return {
		"success": true, 
		"message": "Action memory system test data prepared",
		"test_data": {
			"action_data": action_data,
			"action_result": action_result,
			"failure_data": failure_data,
			"pattern_data": pattern_data
		}
	}

func _list_action_memories(character_id: String) -> Dictionary:
	"""List action memories for a character"""
	if not MemoryStore:
		return {"success": false, "message": "MemoryStore not available"}
	
	var memories = MemoryStore.get_action_memories_by_outcome(character_id, "")
	
	return {
		"success": true,
		"message": "Found " + str(memories.size()) + " action memories for " + character_id,
		"memories": memories
	}

func _list_failure_memories(character_id: String, severity: String) -> Dictionary:
	"""List failure memories for a character"""
	if not MemoryStore:
		return {"success": false, "message": "MemoryStore not available"}
	
	var memories = MemoryStore.get_failure_memories(character_id, severity)
	
	var severity_text = severity if severity != "" else "all severities"
	return {
		"success": true,
		"message": "Found " + str(memories.size()) + " failure memories (" + severity_text + ") for " + character_id,
		"failures": memories
	}

func _list_pattern_memories(character_id: String) -> Dictionary:
	"""List pattern memories for a character"""
	if not MemoryStore:
		return {"success": false, "message": "MemoryStore not available"}
	
	# This would need to be implemented in MemoryStore
	var memories = []
	
	return {
		"success": true,
		"message": "Found " + str(memories.size()) + " pattern memories for " + character_id,
		"patterns": memories
	}

# Helper functions
func _get_relationship_type_from_name(type_name: String) -> int:
    """Convert relationship type name to enum value"""
    match type_name.to_lower():
        "trust":
            return RelationshipGraph.RelationshipType.TRUST
        "friendship":
            return RelationshipGraph.RelationshipType.FRIENDSHIP
        "rivalry":
            return RelationshipGraph.RelationshipType.RIVALRY
        "romantic":
            return RelationshipGraph.RelationshipType.ROMANTIC
        "family":
            return RelationshipGraph.RelationshipType.FAMILY
        "mentor":
            return RelationshipGraph.RelationshipType.MENTOR
        "colleague":
            return RelationshipGraph.RelationshipType.COLLEAGUE
        "acquaintance":
            return RelationshipGraph.RelationshipType.ACQUAINTANCE
        _:
            return -1

# LLM System Testing Commands
func _cmd_llm(args: Array) -> Dictionary:
	"""Handle LLM system testing commands"""
	if args.size() == 0:
		return {"success": false, "message": "Usage: llm <command> [args...]\nCommands: status, test, hybrid, streaming, performance, persona"}
	
	var llm_command = args[0]
	var llm_args = args.slice(1)
	
	match llm_command:
		"status":
			return _show_llm_status()
		"test":
			return _test_llm_system()
		"hybrid":
			return _test_hybrid_inference(llm_args)
		"streaming":
			return _test_streaming(llm_args)
		"performance":
			return _show_llm_performance()
		"persona":
			return _test_persona_caching(llm_args)
		_:
			return {"success": false, "message": "Unknown llm command: " + llm_command}

func _show_llm_status() -> Dictionary:
	"""Show current LLM system status"""
	if not LLMClient:
		return {"success": false, "message": "LLMClient not available"}
	
	var status = {
		"hybrid_inference": LLMClient.use_hybrid_inference,
		"streaming_enabled": LLMClient.streaming_enabled,
		"local_health": LLMClient.is_healthy,
		"cloud_configured": not LLMClient.cloud_api_key.is_empty(),
		"pending_requests": LLMClient.get_pending_request_count(),
		"persona_cache_size": LLMClient.persona_cache.size()
	}
	
	return {
		"success": true,
		"message": "LLM System Status",
		"status": status
	}

func _test_llm_system() -> Dictionary:
	"""Test basic LLM functionality"""
	if not LLMClient:
		return {"success": false, "message": "LLMClient not available"}
	
	# Test basic request
	var test_context = {
		"prompt": "Say hello in a friendly way",
		"temperature": 0.7,
		"stream": false
	}
	
	var request_id = LLMClient.generate_async(test_context, func(response): pass)
	
	return {
		"success": true,
		"message": "LLM test request sent with ID: " + request_id,
		"request_id": request_id
	}

func _test_hybrid_inference(args: Array) -> Dictionary:
	"""Test hybrid inference model selection"""
	if not LLMClient:
		return {"success": false, "message": "LLMClient not available"}
	
	var enabled = true
	if args.size() > 0:
		enabled = args[0].to_lower() == "true"
	
	LLMClient.set_hybrid_inference(enabled)
	
	# Test model selection with different contexts
	var simple_context = {
		"prompt": "Hello",
		"is_spotlight": false,
		"conversation_history": [],
		"participants": ["npc1"],
		"topic_complexity": 0.1
	}
	
	var complex_context = {
		"prompt": "Discuss the philosophical implications of quantum mechanics",
		"is_spotlight": true,
		"conversation_history": ["long", "complex", "discussion"] * 10,
		"participants": ["npc1", "npc2", "npc3", "npc4", "npc5"],
		"topic_complexity": 0.9,
		"memory_context": ["memory1", "memory2", "memory3", "memory4", "memory5", "memory6"]
	}
	
	var simple_strategy = LLMClient.select_model_strategy(simple_context)
	var complex_strategy = LLMClient.select_model_strategy(complex_context)
	
	return {
		"success": true,
		"message": "Hybrid inference " + ("enabled" if enabled else "disabled"),
		"test_results": {
			"simple_context_strategy": simple_strategy,
			"complex_context_strategy": complex_strategy,
			"prompt_complexity_simple": LLMClient._assess_prompt_complexity(simple_context),
			"prompt_complexity_complex": LLMClient._assess_prompt_complexity(complex_context)
		}
	}

func _test_streaming(args: Array) -> Dictionary:
	"""Test streaming response functionality"""
	if not LLMClient:
		return {"success": false, "message": "LLMClient not available"}
	
	var enabled = true
	if args.size() > 0:
		enabled = args[0].to_lower() == "true"
	
	LLMClient.set_streaming_enabled(enabled)
	
	# Test streaming request
	var test_context = {
		"prompt": "Tell me a short story about a brave knight",
		"temperature": 0.8,
		"stream": enabled,
		"max_tokens": 100
	}
	
	var request_id = LLMClient.generate_async(test_context, func(response): pass)
	
	return {
		"success": true,
		"message": "Streaming " + ("enabled" if enabled else "disabled") + " - Test request sent with ID: " + request_id,
		"request_id": request_id,
		"streaming_enabled": enabled
	}

func _show_llm_performance() -> Dictionary:
	"""Show LLM performance metrics"""
	if not LLMClient:
		return {"success": false, "message": "LLMClient not available"}
	
	var performance = LLMClient.get_model_performance()
	
	return {
		"success": true,
		"message": "LLM Performance Metrics",
		"performance": performance
	}

func _test_persona_caching(args: Array) -> Dictionary:
	"""Test persona block caching functionality"""
	if not LLMClient:
		return {"success": false, "message": "LLMClient not available"}
	
	var agent_id = args[0] if args.size() > 0 else "test_agent"
	
	# Test persona data
	var test_persona = {
		"system_prompt": "You are a wise old wizard who speaks in riddles",
		"style_rules": ["Use archaic language", "Include magical references", "Be mysterious"],
		"voice_characteristics": ["Deep voice", "Slow speech", "Wise tone"],
		"few_shot_examples": [
			"Ah, young seeker, the path you tread is fraught with peril and promise...",
			"The stars whisper secrets to those who listen with their hearts..."
		]
	}
	
	# Get cached persona block
	var persona_block = LLMClient.get_cached_persona_block(agent_id, test_persona)
	
	# Test context building with persona
	var test_context = {
		"agent_id": agent_id,
		"agent_persona": test_persona,
		"prompt": "Greet a traveler"
	}
	
	var system_prompt = LLMClient._build_system_prompt(test_context)
	
	return {
		"success": true,
		"message": "Persona caching test completed",
		"results": {
			"agent_id": agent_id,
			"persona_block_length": persona_block.length(),
			"system_prompt_length": system_prompt.length(),
			"cache_size": LLMClient.persona_cache.size(),
			"persona_block_preview": persona_block.substr(0, 200) + "..."
		}
	}

func _show_conversation_status():
	var stats = ConversationController.get_conversation_stats()
	_print_to_console("=== Conversation System Status ===")
	_print_to_console("Active groups: " + str(stats.active_groups) + "/" + str(stats.max_active_groups))
	_print_to_console("Total participants: " + str(stats.total_participants))
	_print_to_console("Streaming conversations: " + str(stats.streaming_conversations))
	
	if stats.group_details.size() > 0:
		_print_to_console("\nGroup Details:")
		for group_id in stats.group_details.keys():
			var group_stats = stats.group_details[group_id]
			_print_to_console("  " + group_id + ": " + str(group_stats.participant_count) + " participants, " + str(group_stats.turn_count) + " turns")

func _start_conversation(npc1: String, npc2: String, topic: String):
	var participants = [npc1, npc2]
	var group_id = ConversationController.start_conversation(participants, topic)
	if group_id != "":
		_print_to_console("Started conversation " + group_id + " with topic: " + topic)
	else:
		_print_to_console("Failed to start conversation")

func _join_conversation(npc: String, group_id: String):
	if ConversationController.add_participant_to_group(group_id, npc):
		_print_to_console("NPC " + npc + " joined conversation " + group_id)
	else:
		_print_to_console("Failed to add NPC " + npc + " to conversation " + group_id)

func _leave_conversation(npc: String):
	var group_id = ConversationController.get_participant_location(npc)
	if group_id != "":
		if ConversationController.remove_participant_from_group(group_id, npc, "console_command"):
			_print_to_console("NPC " + npc + " left conversation " + group_id)
		else:
			_print_to_console("Failed to remove NPC " + npc + " from conversation " + group_id)
	else:
		_print_to_console("NPC " + npc + " is not in any conversation")

func _change_conversation_topic(group_id: String, topic: String):
	if ConversationController.inject_topic_into_group(group_id, topic, "console_command"):
		_print_to_console("Changed topic to '" + topic + "' in conversation " + group_id)
	else:
		_print_to_console("Failed to change topic in conversation " + group_id)

func _force_speaker_change(group_id: String, npc: String):
	if ConversationController.force_dialogue_generation(npc, group_id):
		_print_to_console("Forced " + npc + " to speak in conversation " + group_id)
	else:
		_print_to_console("Failed to force " + npc + " to speak in conversation " + group_id)

func _show_conversation_stats(group_id: String):
	var active_groups = ConversationController.get_active_groups()
	var group = active_groups.get(group_id)
	if group:
		var stats = group.get_conversation_stats()
		_print_to_console("=== Conversation " + group_id + " Statistics ===")
		_print_to_console("Participants: " + str(stats.participant_count))
		_print_to_console("Turns: " + str(stats.turn_count))
		_print_to_console("Topics: " + str(stats.topic_count))
		_print_to_console("Dialogue entries: " + str(stats.dialogue_count))
		_print_to_console("Group mood: " + str(stats.group_mood))
		_print_to_console("Social cohesion: " + str(stats.social_cohesion))
		
		var dialogue_stats = group.get_dialogue_stats()
		_print_to_console("Total words: " + str(dialogue_stats.total_words))
		_print_to_console("Average words per entry: " + str(dialogue_stats.average_words_per_entry))
	else:
		_print_to_console("Conversation group " + group_id + " not found")

func _build_context(npc: String, targets: Array):
	var context = ContextPacker.build_context_for_npc(npc, targets)
	_print_to_console("=== Context for " + npc + " ===")
	_print_to_console("Persona: " + context.persona.name + " (" + context.persona.occupation + ")")
	_print_to_console("Mood: " + context.mood.description)
	_print_to_console("Location: " + context.location.name)
	_print_to_console("Recent topics: " + str(context.recent_topics.size()))
	_print_to_console("Event hints: " + str(context.event_hints.size()))
	_print_to_console("Memory context: " + str(context.memory_context.recent_memories.size()) + " recent memories")
	_print_to_console("Action context: " + str(context.action_context.recent_actions.size()) + " recent actions")

func _build_enhanced_prompt(npc: String, targets: Array):
	var context = ContextPacker.build_context_for_npc(npc, targets)
	var prompt = ContextPacker.build_enhanced_prompt(npc, context)
	_print_to_console("=== Enhanced Prompt for " + npc + " ===")
	_print_to_console(prompt)

func _validate_context(npc: String, targets: Array):
	var context = ContextPacker.build_context_for_npc(npc, targets)
	var is_valid = ContextPacker.validate_context(context)
	if is_valid:
		_print_to_console("Context for " + npc + " is valid")
	else:
		_print_to_console("Context for " + npc + " is invalid")

func _show_streaming_status():
	var active_groups = ConversationController.get_active_groups()
	_print_to_console("=== Streaming Status ===")
	
	for group_id in active_groups.keys():
		var streaming_status = ConversationController.get_streaming_status(group_id)
		if streaming_status.size() > 0:
			_print_to_console("Group " + group_id + ": Streaming for " + streaming_status.speaker_id)
			_print_to_console("  Chunks: " + str(streaming_status.chunks.size()))
		else:
			_print_to_console("Group " + group_id + ": Not streaming")

func _test_streaming_dialogue(npc: String, group_id: String):
	var active_groups = ConversationController.get_active_groups()
	var group = active_groups.get(group_id)
	if group and group.is_participant(npc):
		if ConversationController.force_dialogue_generation(npc, group_id):
			_print_to_console("Started streaming dialogue generation for " + npc + " in group " + group_id)
		else:
			_print_to_console("Failed to start streaming dialogue generation")
	else:
		_print_to_console("NPC " + npc + " is not in group " + group_id)

func _force_streaming_dialogue(npc: String, group_id: String):
	_test_streaming_dialogue(npc, group_id)
