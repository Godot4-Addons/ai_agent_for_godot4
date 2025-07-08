@tool
extends EditorPlugin

var dock
var agent_brain: AgentBrain
var terminal_integration: TerminalIntegration
var task_manager: TaskManager
var agent_memory: AgentMemory
var auto_error_fixer: AutoErrorFixer

func _enter_tree():
	print("Initializing AI Agent for Godot...")

	# Load and create the dock
	var dock_script = load("res://addons/ai_coding_assistant/ui/ai_assistant_dock.gd")
	dock = dock_script.new()

	# Pass the EditorInterface to the dock
	dock.set_editor_interface(get_editor_interface())

	# Initialize agent components
	_initialize_agent_components()

	add_control_to_dock(DOCK_SLOT_LEFT_UL, dock)

	print("AI Agent for Godot enabled - Ready for autonomous operation!")

func _initialize_agent_components():
	"""Initialize all AI agent components"""
	print("Setting up AI Agent components...")

	# Create terminal integration
	terminal_integration = preload("res://addons/ai_coding_assistant/core/terminal_integration.gd").new()
	dock.add_child(terminal_integration)

	# Create agent memory
	agent_memory = preload("res://addons/ai_coding_assistant/core/agent_memory.gd").new()
	dock.add_child(agent_memory)

	# Create task manager
	task_manager = preload("res://addons/ai_coding_assistant/core/task_manager.gd").new()
	dock.add_child(task_manager)

	# Create auto error fixer
	auto_error_fixer = preload("res://addons/ai_coding_assistant/core/auto_error_fixer.gd").new()
	dock.add_child(auto_error_fixer)

	# Create agent brain (main coordinator)
	agent_brain = preload("res://addons/ai_coding_assistant/core/agent_brain.gd").new()
	dock.add_child(agent_brain)

	# Connect components to dock
	dock.set_agent_components(agent_brain, terminal_integration, task_manager, agent_memory, auto_error_fixer)

	print("AI Agent components initialized successfully")

func _exit_tree():
	# Clean up
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()

	print("AI Agent for Godot disabled")

func get_plugin_name():
	return "AI Agent for Godot"
