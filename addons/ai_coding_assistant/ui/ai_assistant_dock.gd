@tool
extends Control

var api_manager
var editor_integration
var plugin_editor_interface: EditorInterface
var chat_history: RichTextLabel
var input_field: LineEdit
var send_button: Button
var provider_option: OptionButton
var model_option: OptionButton
var api_key_field: LineEdit
# Provider-specific controls containers
var provider_specific_container: VBoxContainer
var ollama_controls: VBoxContainer
var openai_controls: VBoxContainer
var gemini_controls: VBoxContainer
var anthropic_controls: VBoxContainer
var groq_controls: VBoxContainer

# Ollama-specific controls
var ollama_url_field: LineEdit
var ollama_streaming_check: CheckBox
var ollama_temperature_slider: HSlider
var ollama_pull_button: Button
var ollama_quick_actions: Array = []

# OpenAI-specific controls
var openai_api_key_field: LineEdit
var openai_org_field: LineEdit
var openai_temperature_slider: HSlider
var openai_max_tokens_field: SpinBox

# Gemini-specific controls
var gemini_api_key_field: LineEdit
var gemini_safety_settings: OptionButton
var gemini_temperature_slider: HSlider

# Anthropic-specific controls
var anthropic_api_key_field: LineEdit
var anthropic_max_tokens_field: SpinBox
var anthropic_temperature_slider: HSlider

# Groq-specific controls
var groq_api_key_field: LineEdit
var groq_temperature_slider: HSlider
var editor_context_menu: PopupMenu
var code_output: TextEdit
var apply_button: Button
var explain_button: Button
var improve_button: Button

# Modern UI containers
var main_splitter: VSplitContainer
var header_container: HBoxContainer
var status_panel: Panel
var ai_status_label: Label
var connection_indicator: Panel
var model_info_label: Label
var settings_toggle_button: Button
var settings_container: VBoxContainer
var settings_content: VBoxContainer
var chat_container: VBoxContainer
var code_container: VBoxContainer
var quick_actions_container: VBoxContainer
var progress_bar: ProgressBar
var typing_indicator: Label

# AI Agent Components
var agent_brain: AgentBrain
var terminal_integration: TerminalIntegration
var task_manager: TaskManager
var agent_memory: AgentMemory
var auto_error_fixer: AutoErrorFixer
var quick_content: VBoxContainer

# Context menus and enhanced features
var chat_context_menu: PopupMenu
var code_context_menu: PopupMenu
var chat_clear_button: Button
var code_copy_button: Button
var code_save_button: Button

# Enhanced view options
var chat_word_wrap_button: Button
var code_line_numbers_button: Button
var chat_word_wrap_enabled: bool = true
var code_line_numbers_enabled: bool = false

# Collapsible sections
var settings_collapsed: bool = false
var quick_actions_collapsed: bool = false

var current_generated_code: String = ""
var settings_dialog: Window
var setup_guide: Window

func _init():
	name = "AI Assistant"

func set_editor_interface(editor_interface: EditorInterface):
	"""Set the EditorInterface from the plugin"""
	plugin_editor_interface = editor_interface

func _ready():
	"""Initialize the dock when it's ready"""
	# Enhanced flexible sizing for better screen adaptation
	custom_minimum_size = Vector2(200, 250)  # Reduced minimum for smaller screens
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Enable automatic resizing and anchoring
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Connect to viewport size changes for responsive design (deferred)
	call_deferred("_connect_viewport_signals")

	# Create and add API manager as a child node
	var APIManagerClass = load("res://addons/ai_coding_assistant/ai/ai_api_manager.gd")
	if APIManagerClass:
		api_manager = APIManagerClass.new()
		add_child(api_manager)
		if api_manager.has_signal("response_received"):
			api_manager.response_received.connect(_on_response_received)
		if api_manager.has_signal("error_occurred"):
			api_manager.error_occurred.connect(_on_error_occurred)
	else:
		print("Warning: Could not load AI API Manager")

	# Initialize editor integration if EditorInterface is available
	if plugin_editor_interface:
		editor_integration = preload("res://addons/ai_coding_assistant/utils/editor_integration.gd").new(plugin_editor_interface)
		editor_integration.code_inserted.connect(_on_code_inserted)
		editor_integration.code_replaced.connect(_on_code_replaced)
		editor_integration.selection_changed.connect(_on_selection_changed)

	# Agent components will be set by the plugin
	agent_brain = null
	terminal_integration = null
	task_manager = null
	agent_memory = null
	auto_error_fixer = null

	# Set default provider to Ollama after UI is ready
	call_deferred("_set_default_provider")

func set_agent_components(brain: AgentBrain, terminal: TerminalIntegration, tasks: TaskManager, memory: AgentMemory, fixer: AutoErrorFixer):
	"""Set and connect AI agent components"""
	agent_brain = brain
	terminal_integration = terminal
	task_manager = tasks
	agent_memory = memory
	auto_error_fixer = fixer

	# Connect agent signals
	if terminal_integration:
		terminal_integration.error_detected.connect(_on_agent_error_detected)
		terminal_integration.warning_detected.connect(_on_agent_warning_detected)
		terminal_integration.command_executed.connect(_on_agent_command_executed)

	if agent_brain:
		agent_brain.task_started.connect(_on_agent_task_started)
		agent_brain.task_completed.connect(_on_agent_task_completed)
		agent_brain.goal_set.connect(_on_agent_goal_set)

	if auto_error_fixer:
		auto_error_fixer.error_fix_started.connect(_on_error_fix_started)
		auto_error_fixer.error_fix_completed.connect(_on_error_fix_completed)

	print("AI Agent components connected to dock")



func _initialize_provider_settings():
	"""Initialize provider settings and show appropriate panels"""
	# Force set to Ollama first
	if provider_option:
		var providers = ["gemini", "huggingface", "cohere", "openai", "anthropic", "groq", "ollama"]
		var ollama_index = providers.find("ollama")
		if ollama_index >= 0:
			provider_option.selected = ollama_index

	# Load saved settings (but keep Ollama as default)
	_load_settings()

	# Ensure Ollama is selected
	if api_manager:
		api_manager.set_provider("ollama")

	# Show Ollama controls by default
	if provider_specific_container and ollama_controls:
		_show_provider_specific_settings("ollama")

	# Update status
	_update_provider_status("ollama")

	# Preload utility classes for better performance
	# Note: These are used in template generation functions

	_setup_ui()
	_load_settings()
	_setup_keyboard_shortcuts()

	# Set default provider to Ollama after UI is ready
	call_deferred("_set_default_provider")

func _set_default_provider():
	"""Set default provider to Ollama and trigger provider change"""
	if provider_option:
		provider_option.selected = 6  # Ollama is at index 6
		_on_provider_changed(6)  # Trigger provider change
		print("Default provider set to Ollama")

func _setup_ui():
	# Create main container with enhanced flexible sizing
	var main_container = VBoxContainer.new()
	main_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(main_container)

	# Create modern header section
	_create_modern_header(main_container)

	# Create settings section (collapsible)
	_create_settings_section(main_container)

	# Add separator with flexible spacing
	var separator1 = HSeparator.new()
	separator1.add_theme_constant_override("separation", 2)
	main_container.add_child(separator1)

	# Create main splitter for chat and code sections with enhanced flexibility
	main_splitter = VSplitContainer.new()
	main_splitter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_splitter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_splitter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Dynamic split position based on screen size (deferred)
	main_splitter.split_offset = 200  # Default value, will be updated by responsive design
	main_container.add_child(main_splitter)

	# Create chat section
	_create_chat_section(main_splitter)

	# Create code section
	_create_code_section(main_splitter)

	# Add separator with flexible spacing
	var separator2 = HSeparator.new()
	separator2.add_theme_constant_override("separation", 2)
	main_container.add_child(separator2)

	# Create quick actions section (collapsible)
	_create_quick_actions_section(main_container)

	# Initialize provider settings after UI is created
	call_deferred("_initialize_provider_settings")

func _create_modern_header(parent: Container):
	"""Create a modern, professional header with AI status and controls"""
	header_container = HBoxContainer.new()
	header_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Create status panel with modern styling
	status_panel = Panel.new()
	status_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_panel.custom_minimum_size = Vector2(0, 45)

	# Add gradient background style
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.15, 0.15, 0.2, 0.9)  # Dark blue-gray
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.3, 0.6, 1.0, 0.8)  # Blue accent
	status_panel.add_theme_stylebox_override("panel", style_box)

	# Create header content container
	var header_content = HBoxContainer.new()
	header_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header_content.add_theme_constant_override("separation", 10)

	# AI Agent title with icon
	var title_container = HBoxContainer.new()
	var ai_icon = Label.new()
	ai_icon.text = "🤖"
	ai_icon.add_theme_font_size_override("font_size", 20)
	title_container.add_child(ai_icon)

	var title_label = Label.new()
	title_label.text = "AI Agent"
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_container.add_child(title_label)

	header_content.add_child(title_container)

	# Connection status indicator
	connection_indicator = Panel.new()
	connection_indicator.custom_minimum_size = Vector2(12, 12)
	var indicator_style = StyleBoxFlat.new()
	indicator_style.bg_color = Color.RED  # Will change based on connection
	indicator_style.corner_radius_top_left = 6
	indicator_style.corner_radius_top_right = 6
	indicator_style.corner_radius_bottom_left = 6
	indicator_style.corner_radius_bottom_right = 6
	connection_indicator.add_theme_stylebox_override("panel", indicator_style)
	header_content.add_child(connection_indicator)

	# AI status label
	ai_status_label = Label.new()
	ai_status_label.text = "Initializing..."
	ai_status_label.add_theme_font_size_override("font_size", 12)
	ai_status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	header_content.add_child(ai_status_label)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_content.add_child(spacer)

	# Provider quick switch buttons
	var quick_switch_container = HBoxContainer.new()
	quick_switch_container.add_theme_constant_override("separation", 2)

	# Ollama quick switch
	var ollama_button = Button.new()
	ollama_button.text = "🦙"
	ollama_button.tooltip_text = "Switch to Ollama"
	ollama_button.custom_minimum_size = Vector2(24, 24)
	ollama_button.flat = true
	ollama_button.add_theme_font_size_override("font_size", 12)
	ollama_button.pressed.connect(func(): _quick_switch_provider("ollama"))
	quick_switch_container.add_child(ollama_button)

	# OpenAI quick switch
	var openai_button = Button.new()
	openai_button.text = "🧠"
	openai_button.tooltip_text = "Switch to OpenAI"
	openai_button.custom_minimum_size = Vector2(24, 24)
	openai_button.flat = true
	openai_button.add_theme_font_size_override("font_size", 12)
	openai_button.pressed.connect(func(): _quick_switch_provider("openai"))
	quick_switch_container.add_child(openai_button)

	# Gemini quick switch
	var gemini_button = Button.new()
	gemini_button.text = "🤖"
	gemini_button.tooltip_text = "Switch to Gemini"
	gemini_button.custom_minimum_size = Vector2(24, 24)
	gemini_button.flat = true
	gemini_button.add_theme_font_size_override("font_size", 12)
	gemini_button.pressed.connect(func(): _quick_switch_provider("gemini"))
	quick_switch_container.add_child(gemini_button)

	header_content.add_child(quick_switch_container)

	# Model info label
	model_info_label = Label.new()
	model_info_label.text = "No Model"
	model_info_label.add_theme_font_size_override("font_size", 11)
	model_info_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	header_content.add_child(model_info_label)

	# Settings toggle button
	settings_toggle_button = Button.new()
	settings_toggle_button.text = "⚙️"
	settings_toggle_button.custom_minimum_size = Vector2(30, 30)
	settings_toggle_button.flat = true
	settings_toggle_button.add_theme_font_size_override("font_size", 14)
	settings_toggle_button.pressed.connect(_on_settings_toggle)
	header_content.add_child(settings_toggle_button)

	status_panel.add_child(header_content)
	header_container.add_child(status_panel)

	parent.add_child(header_container)

	# Add progress bar for AI operations
	progress_bar = ProgressBar.new()
	progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_bar.custom_minimum_size = Vector2(0, 4)
	progress_bar.visible = false
	progress_bar.modulate = Color(0.3, 0.6, 1.0)
	parent.add_child(progress_bar)

func _quick_switch_provider(provider_name: String):
	"""Quick switch to a specific provider"""
	var providers = ["gemini", "huggingface", "cohere", "openai", "anthropic", "groq", "ollama"]
	var index = providers.find(provider_name)
	if index >= 0 and provider_option:
		provider_option.selected = index
		_on_provider_changed(index)
		print("Quick switched to provider: ", provider_name)

func _on_settings_toggle():
	"""Toggle settings panel visibility"""
	print("Settings toggle button pressed!")
	if settings_container:
		settings_container.visible = !settings_container.visible
		settings_toggle_button.text = "⚙️" if not settings_container.visible else "✖️"
		print("Settings panel visibility: ", settings_container.visible)
	else:
		print("Settings container not found!")

func _create_settings_section(parent: Container):
	# Modern settings panel - initially hidden
	settings_container = VBoxContainer.new()
	settings_container.visible = false  # Hidden by default, controlled by header toggle

	# Modern settings panel with styling
	var settings_panel = Panel.new()
	settings_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Style the settings panel
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.12, 0.18, 0.95)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.3, 0.6, 1.0, 0.3)
	settings_panel.add_theme_stylebox_override("panel", panel_style)

	var settings_content_container = VBoxContainer.new()
	settings_content_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_content_container.add_theme_constant_override("margin_left", 12)
	settings_content_container.add_theme_constant_override("margin_right", 12)
	settings_content_container.add_theme_constant_override("margin_top", 12)
	settings_content_container.add_theme_constant_override("margin_bottom", 12)
	settings_content_container.add_theme_constant_override("separation", 8)

	# Modern settings header
	var settings_header = Panel.new()
	settings_header.custom_minimum_size = Vector2(0, 35)

	var header_style = StyleBoxFlat.new()
	header_style.bg_color = Color(0.15, 0.2, 0.3, 0.9)
	header_style.corner_radius_top_left = 6
	header_style.corner_radius_top_right = 6
	settings_header.add_theme_stylebox_override("panel", header_style)

	var header_content = HBoxContainer.new()
	header_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header_content.add_theme_constant_override("margin_left", 10)
	header_content.add_theme_constant_override("margin_right", 10)

	var settings_icon = Label.new()
	settings_icon.text = "⚙️"
	settings_icon.add_theme_font_size_override("font_size", 16)
	header_content.add_child(settings_icon)

	var settings_label = Label.new()
	settings_label.text = "AI Configuration"
	settings_label.add_theme_font_size_override("font_size", 13)
	settings_label.add_theme_color_override("font_color", Color.WHITE)
	settings_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_content.add_child(settings_label)

	var help_button = Button.new()
	help_button.text = "❓"
	help_button.custom_minimum_size = Vector2(28, 28)
	help_button.flat = true
	help_button.add_theme_font_size_override("font_size", 12)
	help_button.pressed.connect(_on_help_pressed)
	header_content.add_child(help_button)

	settings_header.add_child(header_content)
	settings_content_container.add_child(settings_header)

	# Modern settings content
	settings_content = VBoxContainer.new()
	settings_content.add_theme_constant_override("separation", 10)

	# Provider selection section
	var provider_section = VBoxContainer.new()
	var provider_title = Label.new()
	provider_title.text = "🌐 AI Provider"
	provider_title.add_theme_font_size_override("font_size", 12)
	provider_title.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	provider_section.add_child(provider_title)

	provider_option = OptionButton.new()
	provider_option.add_item("🤖 Gemini (Free)")
	provider_option.add_item("🤗 Hugging Face (Free)")
	provider_option.add_item("🔮 Cohere")
	provider_option.add_item("🧠 OpenAI")
	provider_option.add_item("🎭 Anthropic")
	provider_option.add_item("⚡ Groq")
	provider_option.add_item("🏠 Ollama (Local)")
	provider_option.selected = 6  # Default to Ollama
	provider_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	provider_option.custom_minimum_size = Vector2(0, 32)
	provider_option.item_selected.connect(_on_provider_changed)

	# Style the provider option
	var provider_style = StyleBoxFlat.new()
	provider_style.bg_color = Color(0.08, 0.1, 0.15, 0.9)
	provider_style.corner_radius_top_left = 6
	provider_style.corner_radius_top_right = 6
	provider_style.corner_radius_bottom_left = 6
	provider_style.corner_radius_bottom_right = 6
	provider_style.border_width_left = 1
	provider_style.border_width_right = 1
	provider_style.border_width_top = 1
	provider_style.border_width_bottom = 1
	provider_style.border_color = Color(0.3, 0.6, 1.0, 0.5)
	provider_option.add_theme_stylebox_override("normal", provider_style)

	provider_section.add_child(provider_option)
	settings_content.add_child(provider_section)

	# API Key section
	var key_section = VBoxContainer.new()
	var key_title = Label.new()
	key_title.text = "🔑 Authentication"
	key_title.add_theme_font_size_override("font_size", 12)
	key_title.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	key_section.add_child(key_title)

	api_key_field = LineEdit.new()
	api_key_field.placeholder_text = "🔐 Enter your API key (not needed for Ollama)"
	api_key_field.secret = true
	api_key_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	api_key_field.custom_minimum_size = Vector2(0, 32)
	api_key_field.text_changed.connect(_on_api_key_changed)

	# Style the API key field
	var key_style = StyleBoxFlat.new()
	key_style.bg_color = Color(0.08, 0.1, 0.15, 0.9)
	key_style.corner_radius_top_left = 6
	key_style.corner_radius_top_right = 6
	key_style.corner_radius_bottom_left = 6
	key_style.corner_radius_bottom_right = 6
	key_style.border_width_left = 1
	key_style.border_width_right = 1
	key_style.border_width_top = 1
	key_style.border_width_bottom = 1
	key_style.border_color = Color(0.6, 0.3, 1.0, 0.5)
	api_key_field.add_theme_stylebox_override("normal", key_style)

	key_section.add_child(api_key_field)
	settings_content.add_child(key_section)

	# Model selection section
	var model_section = VBoxContainer.new()
	var model_title = Label.new()
	model_title.text = "🧠 AI Model"
	model_title.add_theme_font_size_override("font_size", 12)
	model_title.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	model_section.add_child(model_title)

	model_option = OptionButton.new()
	model_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	model_option.custom_minimum_size = Vector2(0, 32)
	model_option.item_selected.connect(_on_model_changed)

	# Style the model option
	var model_style = StyleBoxFlat.new()
	model_style.bg_color = Color(0.08, 0.1, 0.15, 0.9)
	model_style.corner_radius_top_left = 6
	model_style.corner_radius_top_right = 6
	model_style.corner_radius_bottom_left = 6
	model_style.corner_radius_bottom_right = 6
	model_style.border_width_left = 1
	model_style.border_width_right = 1
	model_style.border_width_top = 1
	model_style.border_width_bottom = 1
	model_style.border_color = Color(1.0, 0.6, 0.3, 0.5)
	model_option.add_theme_stylebox_override("normal", model_style)

	model_section.add_child(model_option)
	settings_content.add_child(model_section)

	# Initialize model dropdown
	_update_model_dropdown()

	# Create provider-specific settings container
	provider_specific_container = VBoxContainer.new()
	provider_specific_container.add_theme_constant_override("separation", 8)
	settings_content.add_child(provider_specific_container)

	# Create all provider-specific controls
	_create_ollama_controls()
	_create_openai_controls()
	_create_gemini_controls()
	_create_anthropic_controls()
	_create_groq_controls()

	settings_content_container.add_child(settings_content)
	settings_panel.add_child(settings_content_container)
	settings_container.add_child(settings_panel)
	parent.add_child(settings_container)

func _create_chat_section(parent: Container):
	chat_container = VBoxContainer.new()
	chat_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_container.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Modern chat header with gradient background
	var chat_header = Panel.new()
	chat_header.custom_minimum_size = Vector2(0, 35)

	# Style the header
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = Color(0.2, 0.25, 0.3, 0.95)
	header_style.corner_radius_top_left = 6
	header_style.corner_radius_top_right = 6
	header_style.border_width_bottom = 1
	header_style.border_color = Color(0.4, 0.4, 0.5, 0.8)
	chat_header.add_theme_stylebox_override("panel", header_style)

	# Header content
	var header_content = HBoxContainer.new()
	header_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header_content.add_theme_constant_override("separation", 8)

	# Chat icon and title
	var chat_icon = Label.new()
	chat_icon.text = "💬"
	chat_icon.add_theme_font_size_override("font_size", 16)
	header_content.add_child(chat_icon)

	var chat_label = Label.new()
	chat_label.text = "AI Conversation"
	chat_label.add_theme_font_size_override("font_size", 13)
	chat_label.add_theme_color_override("font_color", Color.WHITE)
	chat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_content.add_child(chat_label)

	# Typing indicator
	typing_indicator = Label.new()
	typing_indicator.text = "AI is typing..."
	typing_indicator.add_theme_font_size_override("font_size", 10)
	typing_indicator.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	typing_indicator.visible = false
	header_content.add_child(typing_indicator)

	# Modern action buttons
	chat_word_wrap_button = Button.new()
	chat_word_wrap_button.text = "↩"
	chat_word_wrap_button.tooltip_text = "Toggle word wrap"
	chat_word_wrap_button.custom_minimum_size = Vector2(28, 28)
	chat_word_wrap_button.flat = true
	chat_word_wrap_button.add_theme_font_size_override("font_size", 12)
	chat_word_wrap_button.pressed.connect(_on_toggle_chat_word_wrap)
	header_content.add_child(chat_word_wrap_button)

	chat_clear_button = Button.new()
	chat_clear_button.text = "🗑"
	chat_clear_button.tooltip_text = "Clear chat history"
	chat_clear_button.custom_minimum_size = Vector2(28, 28)
	chat_clear_button.flat = true
	chat_clear_button.add_theme_font_size_override("font_size", 12)
	chat_clear_button.pressed.connect(_on_clear_chat)
	header_content.add_child(chat_clear_button)

	chat_header.add_child(header_content)
	chat_container.add_child(chat_header)

	# Create modern chat area with custom styling
	var chat_area = Panel.new()
	chat_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_area.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Style the chat area
	var chat_style = StyleBoxFlat.new()
	chat_style.bg_color = Color(0.08, 0.08, 0.12, 0.95)  # Dark background
	chat_style.corner_radius_bottom_left = 6
	chat_style.corner_radius_bottom_right = 6
	chat_style.border_width_left = 1
	chat_style.border_width_right = 1
	chat_style.border_width_bottom = 1
	chat_style.border_color = Color(0.3, 0.3, 0.4, 0.6)
	chat_area.add_theme_stylebox_override("panel", chat_style)

	# Create scrollable container for chat history
	var chat_scroll = ScrollContainer.new()
	chat_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chat_scroll.add_theme_constant_override("margin_left", 8)
	chat_scroll.add_theme_constant_override("margin_right", 8)
	chat_scroll.add_theme_constant_override("margin_top", 8)
	chat_scroll.add_theme_constant_override("margin_bottom", 8)

	# Enable scrolling with custom scrollbar styling
	chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	chat_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	chat_scroll.follow_focus = true

	# Modern chat history with enhanced styling
	chat_history = RichTextLabel.new()
	chat_history.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_history.bbcode_enabled = true
	chat_history.scroll_following = true
	chat_history.selection_enabled = true
	chat_history.context_menu_enabled = true
	chat_history.fit_content = true
	chat_history.scroll_active = true
	chat_history.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Enhanced chat styling
	_setup_modern_chat_styling()

	# Create context menu for chat
	_create_chat_context_menu()
	chat_history.gui_input.connect(_on_chat_gui_input)

	# Add chat history to scroll container
	chat_scroll.add_child(chat_history)
	chat_area.add_child(chat_scroll)
	chat_container.add_child(chat_area)

	# Modern input section
	var input_panel = Panel.new()
	input_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_panel.custom_minimum_size = Vector2(0, 50)

	# Style the input panel
	var input_style = StyleBoxFlat.new()
	input_style.bg_color = Color(0.15, 0.18, 0.22, 0.95)
	input_style.corner_radius_bottom_left = 6
	input_style.corner_radius_bottom_right = 6
	input_style.border_width_top = 1
	input_style.border_color = Color(0.4, 0.4, 0.5, 0.8)
	input_panel.add_theme_stylebox_override("panel", input_style)

	var input_container = HBoxContainer.new()
	input_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	input_container.add_theme_constant_override("margin_left", 10)
	input_container.add_theme_constant_override("margin_right", 10)
	input_container.add_theme_constant_override("margin_top", 8)
	input_container.add_theme_constant_override("margin_bottom", 8)
	input_container.add_theme_constant_override("separation", 8)

	# Modern input field
	input_field = LineEdit.new()
	input_field.placeholder_text = "💭 Ask me anything about coding..."
	input_field.editable = true
	input_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_field.custom_minimum_size = Vector2(0, 34)
	input_field.text_submitted.connect(_on_send_message)

	# Style the input field
	var input_field_style = StyleBoxFlat.new()
	input_field_style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	input_field_style.corner_radius_top_left = 17
	input_field_style.corner_radius_top_right = 17
	input_field_style.corner_radius_bottom_left = 17
	input_field_style.corner_radius_bottom_right = 17
	input_field_style.border_width_left = 1
	input_field_style.border_width_right = 1
	input_field_style.border_width_top = 1
	input_field_style.border_width_bottom = 1
	input_field_style.border_color = Color(0.3, 0.6, 1.0, 0.6)
	input_field.add_theme_stylebox_override("normal", input_field_style)
	input_field.add_theme_stylebox_override("focus", input_field_style)

	# Modern send button
	send_button = Button.new()
	send_button.text = "🚀"
	send_button.custom_minimum_size = Vector2(40, 34)
	send_button.pressed.connect(_on_send_pressed)

	# Style the send button
	var send_style = StyleBoxFlat.new()
	send_style.bg_color = Color(0.2, 0.6, 1.0, 0.9)
	send_style.corner_radius_top_left = 17
	send_style.corner_radius_top_right = 17
	send_style.corner_radius_bottom_left = 17
	send_style.corner_radius_bottom_right = 17
	send_button.add_theme_stylebox_override("normal", send_style)
	send_button.add_theme_stylebox_override("hover", send_style)
	send_button.add_theme_stylebox_override("pressed", send_style)
	send_button.add_theme_font_size_override("font_size", 14)

	input_container.add_child(input_field)
	input_container.add_child(send_button)
	input_panel.add_child(input_container)
	chat_container.add_child(input_panel)

	parent.add_child(chat_container)

func _setup_modern_chat_styling():
	"""Setup modern styling for chat history"""
	# Set background color
	chat_history.add_theme_color_override("default_color", Color(0.9, 0.9, 0.95))
	chat_history.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.3))

	# Custom font sizes for different elements
	chat_history.add_theme_font_size_override("normal_font_size", 13)
	chat_history.add_theme_font_size_override("bold_font_size", 14)
	chat_history.add_theme_font_size_override("mono_font_size", 12)

func _update_ai_status(status: String, color: Color = Color.WHITE):
	"""Update AI status in the header"""
	if ai_status_label:
		ai_status_label.text = status
		ai_status_label.add_theme_color_override("font_color", color)

func _update_connection_status(connected: bool):
	"""Update connection indicator"""
	if connection_indicator:
		var indicator_style = StyleBoxFlat.new()
		indicator_style.bg_color = Color.GREEN if connected else Color.RED
		indicator_style.corner_radius_top_left = 6
		indicator_style.corner_radius_top_right = 6
		indicator_style.corner_radius_bottom_left = 6
		indicator_style.corner_radius_bottom_right = 6
		connection_indicator.add_theme_stylebox_override("panel", indicator_style)

func _update_model_info(model_name: String):
	"""Update model information display"""
	if model_info_label:
		model_info_label.text = model_name if not model_name.is_empty() else "No Model"

func _show_typing_indicator(show: bool = true):
	"""Show/hide typing indicator"""
	if typing_indicator:
		typing_indicator.visible = show

func _show_progress(show: bool = true, value: float = 0.0):
	"""Show/hide progress bar with optional value"""
	if progress_bar:
		progress_bar.visible = show
		if show:
			progress_bar.value = value

func _create_code_section(parent: Container):
	code_container = VBoxContainer.new()
	code_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_container.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Code header with action buttons
	var code_header = HBoxContainer.new()
	var code_label = Label.new()
	code_label.text = "Generated Code"
	code_label.add_theme_font_size_override("font_size", 14)
	code_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Line numbers toggle button
	code_line_numbers_button = Button.new()
	code_line_numbers_button.text = "#" if code_line_numbers_enabled else "∅"
	code_line_numbers_button.tooltip_text = "Toggle line numbers"
	code_line_numbers_button.set_custom_minimum_size(Vector2(25, 25))
	code_line_numbers_button.pressed.connect(_on_toggle_code_line_numbers)

	# Copy code button
	code_copy_button = Button.new()
	code_copy_button.text = "📋"
	code_copy_button.tooltip_text = "Copy code to clipboard"
	code_copy_button.set_custom_minimum_size(Vector2(25, 25))
	code_copy_button.pressed.connect(_on_copy_code)

	# Save code button
	code_save_button = Button.new()
	code_save_button.text = "💾"
	code_save_button.tooltip_text = "Save code to file"
	code_save_button.custom_minimum_size = Vector2(25, 25)
	code_save_button.pressed.connect(_on_save_code)

	code_header.add_child(code_label)
	code_header.add_child(code_line_numbers_button)
	code_header.add_child(code_copy_button)
	code_header.add_child(code_save_button)
	code_container.add_child(code_header)

	# Create scrollable container for code output
	var code_scroll = ScrollContainer.new()
	code_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	code_scroll.custom_minimum_size = Vector2(0, 120)  # Default minimum height

	# Enable scrolling for code
	code_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	code_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	code_scroll.follow_focus = true

	# Enhanced code output with flexible sizing and better editing capabilities
	code_output = TextEdit.new()
	code_output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	code_output.placeholder_text = "Generated code will appear here...\nThis area is fully editable - you can modify code before applying it."
	code_output.editable = true  # Allow editing

	# Enhanced code editing features
	code_output.wrap_mode = TextEdit.LINE_WRAPPING_NONE  # No wrapping for code
	code_output.scroll_horizontal = true  # Correct property name for Godot 4.x
	code_output.context_menu_enabled = true  # Enable built-in context menu
	code_output.selecting_enabled = true
	code_output.deselect_on_focus_loss_enabled = false
	code_output.drag_and_drop_selection_enabled = true
	code_output.virtual_keyboard_enabled = false  # Better for code editing

	# Better code styling
	_setup_code_styling()

	# Create context menu for code
	_create_code_context_menu()
	code_output.gui_input.connect(_on_code_gui_input)

	# Add code output to scroll container
	code_scroll.add_child(code_output)
	code_container.add_child(code_scroll)

	# Action buttons with better layout
	var button_hbox = HBoxContainer.new()
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	apply_button = Button.new()
	apply_button.text = "Apply to Script"
	apply_button.pressed.connect(_on_apply_code)
	apply_button.disabled = true
	apply_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	explain_button = Button.new()
	explain_button.text = "Explain"
	explain_button.pressed.connect(_on_explain_code)
	explain_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	improve_button = Button.new()
	improve_button.text = "Improve"
	improve_button.pressed.connect(_on_improve_code)
	improve_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	button_hbox.add_child(apply_button)
	button_hbox.add_child(explain_button)
	button_hbox.add_child(improve_button)
	code_container.add_child(button_hbox)

	parent.add_child(code_container)

func _create_quick_actions_section(parent: Container):
	# Modern quick actions panel
	var actions_panel = Panel.new()
	actions_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Style the actions panel
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.15, 0.2, 0.95)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.3, 0.6, 1.0, 0.4)
	actions_panel.add_theme_stylebox_override("panel", panel_style)

	quick_actions_container = VBoxContainer.new()
	quick_actions_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	quick_actions_container.add_theme_constant_override("margin_left", 8)
	quick_actions_container.add_theme_constant_override("margin_right", 8)
	quick_actions_container.add_theme_constant_override("margin_top", 8)
	quick_actions_container.add_theme_constant_override("margin_bottom", 8)

	# Modern header with gradient
	var quick_header = Panel.new()
	quick_header.custom_minimum_size = Vector2(0, 32)

	var header_style = StyleBoxFlat.new()
	header_style.bg_color = Color(0.2, 0.25, 0.35, 0.9)
	header_style.corner_radius_top_left = 6
	header_style.corner_radius_top_right = 6
	quick_header.add_theme_stylebox_override("panel", header_style)

	var header_content = HBoxContainer.new()
	header_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header_content.add_theme_constant_override("margin_left", 8)
	header_content.add_theme_constant_override("margin_right", 8)

	var quick_icon = Label.new()
	quick_icon.text = "⚡"
	quick_icon.add_theme_font_size_override("font_size", 16)
	header_content.add_child(quick_icon)

	var quick_label = Label.new()
	quick_label.text = "Quick Actions"
	quick_label.add_theme_font_size_override("font_size", 13)
	quick_label.add_theme_color_override("font_color", Color.WHITE)
	quick_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_content.add_child(quick_label)

	var collapse_button = Button.new()
	collapse_button.text = "▼" if not quick_actions_collapsed else "▶"
	collapse_button.custom_minimum_size = Vector2(24, 24)
	collapse_button.flat = true
	collapse_button.add_theme_font_size_override("font_size", 10)
	collapse_button.pressed.connect(_toggle_quick_actions_collapse)
	header_content.add_child(collapse_button)

	quick_header.add_child(header_content)
	quick_actions_container.add_child(quick_header)

	# Modern quick actions content (collapsible)
	quick_content = VBoxContainer.new()
	quick_content.visible = not quick_actions_collapsed
	quick_content.add_theme_constant_override("separation", 4)

	# Create action buttons in a grid layout
	var actions_grid = GridContainer.new()
	actions_grid.columns = 2
	actions_grid.add_theme_constant_override("h_separation", 6)
	actions_grid.add_theme_constant_override("v_separation", 6)

	# Define action buttons with modern styling
	var actions = [
		{"text": "🏃 Player", "callback": "_on_generate_class", "color": Color(0.2, 0.8, 0.4)},
		{"text": "⚙️ Singleton", "callback": "_on_generate_singleton", "color": Color(0.8, 0.4, 0.2)},
		{"text": "🖥️ UI System", "callback": "_on_generate_ui", "color": Color(0.4, 0.6, 0.9)},
		{"text": "💾 Save Data", "callback": "_on_generate_save_system", "color": Color(0.9, 0.6, 0.2)},
		{"text": "🔊 Audio", "callback": "_on_generate_audio_manager", "color": Color(0.8, 0.2, 0.8)},
		{"text": "🔄 State", "callback": "_on_generate_state_machine", "color": Color(0.2, 0.8, 0.8)}
	]

	for action in actions:
		var btn = Button.new()
		btn.text = action.text
		btn.custom_minimum_size = Vector2(0, 32)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(Callable(self, action.callback))

		# Modern button styling
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = action.color
		btn_style.corner_radius_top_left = 6
		btn_style.corner_radius_top_right = 6
		btn_style.corner_radius_bottom_left = 6
		btn_style.corner_radius_bottom_right = 6
		btn.add_theme_stylebox_override("normal", btn_style)

		var btn_hover_style = StyleBoxFlat.new()
		btn_hover_style.bg_color = action.color * 1.2
		btn_hover_style.corner_radius_top_left = 6
		btn_hover_style.corner_radius_top_right = 6
		btn_hover_style.corner_radius_bottom_left = 6
		btn_hover_style.corner_radius_bottom_right = 6
		btn.add_theme_stylebox_override("hover", btn_hover_style)

		btn.add_theme_font_size_override("font_size", 11)
		btn.add_theme_color_override("font_color", Color.WHITE)

		actions_grid.add_child(btn)

	quick_content.add_child(actions_grid)

	# Ollama-specific quick actions (initially hidden)
	_create_ollama_quick_actions()

	# Editor integration quick actions
	_create_editor_quick_actions()

	quick_actions_container.add_child(quick_content)
	actions_panel.add_child(quick_actions_container)
	parent.add_child(actions_panel)

# Styling setup functions
func _setup_chat_styling():
	# Enhanced chat styling for better readability and markdown support
	if chat_history:
		# Set better margins for text
		chat_history.add_theme_constant_override("margin_left", 12)
		chat_history.add_theme_constant_override("margin_right", 12)
		chat_history.add_theme_constant_override("margin_top", 8)
		chat_history.add_theme_constant_override("margin_bottom", 8)

		# Better line spacing for enhanced readability
		chat_history.add_theme_constant_override("line_separation", 4)

		# Enhanced table styling for code blocks
		chat_history.add_theme_constant_override("table_h_separation", 0)
		chat_history.add_theme_constant_override("table_v_separation", 2)

		# Better text rendering
		chat_history.add_theme_constant_override("outline_size", 0)

		# Enable advanced text features
		chat_history.threaded = true
		chat_history.meta_underlined = false

# Helper function for connecting viewport signals
func _connect_viewport_signals():
	if get_viewport():
		get_viewport().size_changed.connect(_on_viewport_size_changed)

# Responsive design functions
func _calculate_initial_split_position():
	# Calculate initial split position based on screen size
	if not main_splitter:
		return

	var viewport_size = get_viewport().get_visible_rect().size if get_viewport() else Vector2(800, 600)
	var dock_height = viewport_size.y * 0.8  # Assume dock takes 80% of screen height

	# Set split position to give more space to chat on larger screens
	if dock_height > 600:
		main_splitter.split_offset = int(dock_height * 0.4)  # 40% for chat
	elif dock_height > 400:
		main_splitter.split_offset = int(dock_height * 0.35)  # 35% for chat
	else:
		main_splitter.split_offset = int(dock_height * 0.3)  # 30% for chat on small screens

func _calculate_dynamic_min_height(section: String) -> int:
	# Calculate dynamic minimum heights based on screen size
	var viewport_size = get_viewport().get_visible_rect().size if get_viewport() else Vector2(800, 600)
	var screen_height = viewport_size.y

	match section:
		"chat":
			if screen_height > 1000:
				return 200  # Large screens
			elif screen_height > 600:
				return 150  # Medium screens
			else:
				return 100  # Small screens
		"code":
			if screen_height > 1000:
				return 180  # Large screens
			elif screen_height > 600:
				return 120  # Medium screens
			else:
				return 80   # Small screens
		_:
			return 100

func _on_viewport_size_changed():
	# Handle viewport size changes for responsive design
	call_deferred("_apply_responsive_design")

func _apply_responsive_design():
	# Apply responsive design based on current screen size
	if not is_inside_tree():
		return

	var viewport_size = get_viewport().get_visible_rect().size if get_viewport() else Vector2(800, 600)
	var screen_width = viewport_size.x
	var screen_height = viewport_size.y

	# Adjust minimum sizes based on screen size
	if chat_container:
		var min_chat_height = _calculate_dynamic_min_height("chat")
		# Find the scroll container and set its minimum size
		for child in chat_container.get_children():
			if child is ScrollContainer:
				child.custom_minimum_size = Vector2(0, min_chat_height)
				break

	if code_container:
		var min_code_height = _calculate_dynamic_min_height("code")
		# Find the scroll container and set its minimum size
		for child in code_container.get_children():
			if child is ScrollContainer:
				child.custom_minimum_size = Vector2(0, min_code_height)
				break

	# Adjust dock minimum size based on screen
	if screen_width < 400:
		custom_minimum_size = Vector2(180, 200)  # Very small screens
	elif screen_width < 800:
		custom_minimum_size = Vector2(200, 250)  # Small screens
	else:
		custom_minimum_size = Vector2(250, 300)  # Normal screens

	# Auto-collapse sections on very small screens
	if screen_height < 500:
		if not settings_collapsed:
			_toggle_settings_collapse()
		if not quick_actions_collapsed:
			_toggle_quick_actions_collapse()

	# Recalculate split position if needed
	if main_splitter and main_splitter.split_offset == 200:  # Only if still at default
		_calculate_initial_split_position()

func _setup_code_styling():
	# Enhanced code styling for better editing
	if code_output:
		# Set monospace font for code
		var code_font = ThemeDB.fallback_font
		if code_font:
			code_output.add_theme_font_override("font", code_font)

		# Better margins and spacing
		code_output.add_theme_constant_override("line_spacing", 2)

		# Set tab size for better code formatting
		code_output.set_tab_size(4)

		# Enable some helpful features
		code_output.caret_blink = true
		code_output.caret_multiple = true

# Context menu creation functions
func _create_chat_context_menu():
	chat_context_menu = PopupMenu.new()
	chat_context_menu.add_item("Copy Selected Text", 0)
	chat_context_menu.add_item("Copy All Chat", 1)
	chat_context_menu.add_separator()
	chat_context_menu.add_item("Save Chat History", 2)
	chat_context_menu.add_item("Clear Chat", 3)
	chat_context_menu.id_pressed.connect(_on_chat_context_menu_pressed)
	add_child(chat_context_menu)

func _create_code_context_menu():
	code_context_menu = PopupMenu.new()
	code_context_menu.add_item("Copy", 0)
	code_context_menu.add_item("Cut", 1)
	code_context_menu.add_item("Paste", 2)
	code_context_menu.add_separator()
	code_context_menu.add_item("Select All", 3)
	code_context_menu.add_separator()
	code_context_menu.add_item("Save to File", 4)
	code_context_menu.add_item("Clear Code", 5)
	code_context_menu.id_pressed.connect(_on_code_context_menu_pressed)
	add_child(code_context_menu)

# GUI input handlers for context menus
func _on_chat_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			chat_context_menu.position = get_global_mouse_position()
			chat_context_menu.popup()

func _on_code_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			code_context_menu.position = get_global_mouse_position()
			code_context_menu.popup()

# Collapse toggle functions
func _toggle_settings_collapse():
	settings_collapsed = not settings_collapsed
	_refresh_settings_section()

func _toggle_quick_actions_collapse():
	quick_actions_collapsed = not quick_actions_collapsed
	_refresh_quick_actions_section()

func _refresh_settings_section():
	if settings_container:
		var header = settings_container.get_child(0) as HBoxContainer
		var collapse_button = header.get_child(0) as Button
		collapse_button.text = "▼" if not settings_collapsed else "▶"

		var content = settings_container.get_child(1)
		content.visible = not settings_collapsed

func _refresh_quick_actions_section():
	if quick_actions_container:
		# Find the collapse button in the header structure
		var header_panel = quick_actions_container.get_child(0) as Panel
		if header_panel:
			var header_content = header_panel.get_child(0) as HBoxContainer
			if header_content and header_content.get_child_count() > 2:
				var collapse_button = header_content.get_child(2) as Button
				if collapse_button:
					collapse_button.text = "▼" if not quick_actions_collapsed else "▶"

		# Toggle content visibility
		if quick_actions_container.get_child_count() > 1:
			var content = quick_actions_container.get_child(1)
			content.visible = not quick_actions_collapsed

# Context menu action handlers
func _on_chat_context_menu_pressed(id: int):
	match id:
		0: # Copy Selected Text
			var selected_text = chat_history.get_selected_text()
			if not selected_text.is_empty():
				DisplayServer.clipboard_set(selected_text)
				_add_to_chat("System", "Selected text copied to clipboard", Color.YELLOW)
		1: # Copy All Chat
			var all_text = chat_history.get_parsed_text()
			DisplayServer.clipboard_set(all_text)
			_add_to_chat("System", "All chat history copied to clipboard", Color.YELLOW)
		2: # Save Chat History
			_save_chat_history()
		3: # Clear Chat
			_on_clear_chat()

func _on_code_context_menu_pressed(id: int):
	match id:
		0: # Copy
			var selected_text = code_output.get_selected_text()
			if selected_text.is_empty():
				selected_text = code_output.text
			DisplayServer.clipboard_set(selected_text)
		1: # Cut
			var selected_text = code_output.get_selected_text()
			if not selected_text.is_empty():
				DisplayServer.clipboard_set(selected_text)
				code_output.delete_selection()
		2: # Paste
			var clipboard_text = DisplayServer.clipboard_get()
			code_output.insert_text_at_caret(clipboard_text)
		3: # Select All
			code_output.select_all()
		4: # Save to File
			_on_save_code()
		5: # Clear Code
			code_output.clear()
			current_generated_code = ""
			apply_button.disabled = true

# New action button handlers
func _on_clear_chat():
	chat_history.clear()
	_add_to_chat("System", "Chat history cleared", Color.YELLOW)

func _on_copy_code():
	if not code_output.text.is_empty():
		DisplayServer.clipboard_set(code_output.text)
		_add_to_chat("System", "Code copied to clipboard", Color.YELLOW)

func _on_save_code():
	if code_output.text.is_empty():
		_add_to_chat("System", "No code to save", Color.YELLOW)
		return

	# Create a simple file dialog
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.add_filter("*.gd", "GDScript Files")
	file_dialog.add_filter("*.txt", "Text Files")
	file_dialog.current_file = "generated_code.gd"
	file_dialog.file_selected.connect(_on_code_file_selected)
	get_viewport().add_child(file_dialog)
	file_dialog.popup_centered(Vector2i(800, 600))

func _on_code_file_selected(path: String):
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(code_output.text)
		file.close()
		_add_to_chat("System", "Code saved to: " + path, Color.YELLOW)
	else:
		_add_to_chat("Error", "Failed to save code to file", Color.RED)

func _save_chat_history():
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.add_filter("*.txt", "Text Files")
	file_dialog.add_filter("*.md", "Markdown Files")
	file_dialog.current_file = "chat_history.txt"
	file_dialog.file_selected.connect(_on_chat_file_selected)
	get_viewport().add_child(file_dialog)
	file_dialog.popup_centered(Vector2i(800, 600))

func _on_chat_file_selected(path: String):
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		var chat_text = chat_history.get_parsed_text()
		file.store_string(chat_text)
		file.close()
		_add_to_chat("System", "Chat history saved to: " + path, Color.YELLOW)
	else:
		_add_to_chat("Error", "Failed to save chat history", Color.RED)

# View toggle functions
func _on_toggle_chat_word_wrap():
	chat_word_wrap_enabled = not chat_word_wrap_enabled
	if chat_history:
		chat_history.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if chat_word_wrap_enabled else TextServer.AUTOWRAP_OFF

	# Update button appearance
	if chat_word_wrap_button:
		chat_word_wrap_button.text = "↩" if chat_word_wrap_enabled else "→"
		chat_word_wrap_button.tooltip_text = "Word wrap: " + ("ON" if chat_word_wrap_enabled else "OFF")

func _on_toggle_code_line_numbers():
	code_line_numbers_enabled = not code_line_numbers_enabled
	if code_output:
		code_output.gutters_draw_line_numbers = code_line_numbers_enabled  # Correct property name for Godot 4.x

	# Update button appearance
	if code_line_numbers_button:
		code_line_numbers_button.text = "#" if code_line_numbers_enabled else "∅"
		code_line_numbers_button.tooltip_text = "Line numbers: " + ("ON" if code_line_numbers_enabled else "OFF")

func _on_provider_changed(index: int):
	var providers = ["gemini", "huggingface", "cohere", "openai", "anthropic", "groq", "ollama"]
	if index < providers.size():
		var provider = providers[index]
		print("Switching to provider: ", provider)

		# Set provider in API manager
		if api_manager and api_manager.has_method("set_provider"):
			api_manager.set_provider(provider)

		# Update UI elements
		_update_provider_info(provider)
		_update_model_dropdown()
		_show_provider_specific_settings(provider)
		_update_provider_status(provider)

		# Save provider preference
		_save_provider_preference(provider)

func _show_provider_specific_settings(provider: String):
	"""Show/hide provider-specific settings based on selected provider"""
	if not provider_specific_container:
		return

	# Hide all provider-specific controls
	if ollama_controls:
		ollama_controls.visible = false
	if openai_controls:
		openai_controls.visible = false
	if gemini_controls:
		gemini_controls.visible = false
	if anthropic_controls:
		anthropic_controls.visible = false
	if groq_controls:
		groq_controls.visible = false

	# Show relevant provider controls
	match provider:
		"ollama":
			if ollama_controls:
				ollama_controls.visible = true
				_check_ollama_status()
		"openai":
			if openai_controls:
				openai_controls.visible = true
		"gemini":
			if gemini_controls:
				gemini_controls.visible = true
		"anthropic":
			if anthropic_controls:
				anthropic_controls.visible = true
		"groq":
			if groq_controls:
				groq_controls.visible = true

func _update_provider_status(provider: String):
	"""Update status indicators based on provider"""
	match provider:
		"ollama":
			_update_ai_status("Connecting to Ollama...", Color.YELLOW)
			_update_connection_status(false)  # Will be updated by status check
		"openai":
			var has_key = openai_api_key_field and not openai_api_key_field.text.is_empty()
			_update_ai_status("OpenAI " + ("Ready" if has_key else "API Key Required"), Color.GREEN if has_key else Color.YELLOW)
			_update_connection_status(has_key)
		"gemini":
			var has_key = gemini_api_key_field and not gemini_api_key_field.text.is_empty()
			_update_ai_status("Gemini " + ("Ready" if has_key else "API Key Required"), Color.GREEN if has_key else Color.YELLOW)
			_update_connection_status(has_key)
		"anthropic":
			var has_key = anthropic_api_key_field and not anthropic_api_key_field.text.is_empty()
			_update_ai_status("Anthropic " + ("Ready" if has_key else "API Key Required"), Color.GREEN if has_key else Color.YELLOW)
			_update_connection_status(has_key)
		"groq":
			var has_key = groq_api_key_field and not groq_api_key_field.text.is_empty()
			_update_ai_status("Groq " + ("Ready" if has_key else "API Key Required"), Color.GREEN if has_key else Color.YELLOW)
			_update_connection_status(has_key)
		_:
			_update_ai_status("Ready", Color.GREEN)
			_update_connection_status(true)

func _save_provider_preference(provider: String):
	"""Save provider preference to settings"""
	var settings = _load_settings_data()
	settings["provider"] = provider
	_save_settings(settings)

func _load_settings_data() -> Dictionary:
	"""Load settings data from config file"""
	var config = ConfigFile.new()
	var settings = {}
	var err = config.load("user://ai_assistant_settings.cfg")
	if err == OK:
		# Load all settings from ai_assistant section
		var keys = config.get_section_keys("ai_assistant")
		for key in keys:
			settings[key] = config.get_value("ai_assistant", key)
	return settings

func _update_provider_info(provider: String):
	"""Update UI based on selected provider"""
	var info_text = ""
	match provider:
		"gemini":
			info_text = "Free tier: 60 req/min, 1500/day"
		"huggingface":
			info_text = "Free inference API available"
		"cohere":
			info_text = "Free tier: 20 req/min, 100/day"
		"openai":
			info_text = "Requires paid API key"
		"anthropic":
			info_text = "Requires paid API key"
		"groq":
			info_text = "Free tier available"
		"ollama":
			info_text = "Local models - no API key needed"

	# Update API key field placeholder
	if api_key_field:
		if provider == "ollama":
			api_key_field.placeholder_text = "No API key needed for local Ollama"
			api_key_field.editable = false
		else:
			api_key_field.placeholder_text = "Enter your " + provider.capitalize() + " API key"
			api_key_field.editable = true

	# Show/hide Ollama-specific controls
	if ollama_controls:
		ollama_controls.visible = (provider == "ollama")
		if provider == "ollama":
			_add_to_chat("System", "🏠 Ollama selected - Advanced local AI features available", Color.CYAN)
			_check_ollama_status()

	# Show/hide Ollama quick actions
	for action in ollama_quick_actions:
		if action:
			action.visible = (provider == "ollama")

func _check_ollama_status():
	"""Check if Ollama is running and available"""
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_ollama_status_checked)

	var url = "http://localhost:11434/api/tags"
	var headers = ["Content-Type: application/json"]
	var error = http_request.request(url, headers, HTTPClient.METHOD_GET)

	if error != OK:
		_add_to_chat("System", "❌ Failed to check Ollama status", Color.RED)
		http_request.queue_free()

func _on_ollama_status_checked(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	var http_request = get_children().filter(func(child): return child is HTTPRequest).back()
	if http_request:
		http_request.queue_free()

	if response_code == 200:
		var json = JSON.new()
		var parse_result = json.parse(body.get_string_from_utf8())
		if parse_result == OK:
			var data = json.data
			if data.has("models") and data.models.size() > 0:
				var model_count = data.models.size()
				_add_to_chat("System", "✅ Ollama is running with " + str(model_count) + " model(s) available", Color.GREEN)
				_update_model_dropdown()
				_update_connection_status(true)
				_update_ai_status("Connected to Ollama", Color.GREEN)
			else:
				_add_to_chat("System", "⚠️ Ollama is running but no models are installed", Color.YELLOW)
				_update_connection_status(true)
				_update_ai_status("No models available", Color.YELLOW)
		else:
			_add_to_chat("System", "⚠️ Ollama is running but returned invalid data", Color.YELLOW)
			_update_connection_status(false)
			_update_ai_status("Connection error", Color.YELLOW)
	else:
		_add_to_chat("System", "❌ Ollama is not available (Error: " + str(response_code) + ")", Color.RED)
		_update_connection_status(false)
		_update_ai_status("Disconnected", Color.RED)

func _update_model_dropdown():
	"""Update model dropdown based on current provider"""
	if not model_option:
		return

	model_option.clear()
	var models = []
	if api_manager and api_manager.has_method("get_available_models"):
		models = api_manager.get_available_models()
		for model in models:
			model_option.add_item(model)
	else:
		# Add default models if API manager not available
		models = ["llama3.2", "qwen2.5-coder"]
		for model in models:
			model_option.add_item(model)

	if models.size() > 0:
		model_option.selected = 0
		_update_model_info(models[0])

func _on_model_changed(index: int):
	"""Handle model selection change"""
	api_manager.set_model_index(index)
	var models = api_manager.get_available_models() if api_manager else []
	if index < models.size():
		_update_model_info(models[index])

func _create_ollama_controls():
	"""Create modern Ollama-specific controls"""
	ollama_controls = VBoxContainer.new()
	ollama_controls.visible = false  # Hidden by default
	ollama_controls.add_theme_constant_override("separation", 8)

	# Ollama configuration section
	var ollama_section = VBoxContainer.new()
	var ollama_title = Label.new()
	ollama_title.text = "🦙 Ollama Configuration"
	ollama_title.add_theme_font_size_override("font_size", 12)
	ollama_title.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	ollama_section.add_child(ollama_title)

	# Server URL with modern styling
	var url_label = Label.new()
	url_label.text = "Server URL:"
	url_label.add_theme_font_size_override("font_size", 10)
	url_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	ollama_section.add_child(url_label)

	ollama_url_field = LineEdit.new()
	ollama_url_field.text = "http://localhost:11434"
	ollama_url_field.placeholder_text = "🌐 Ollama server URL"
	ollama_url_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ollama_url_field.custom_minimum_size = Vector2(0, 28)
	ollama_url_field.text_changed.connect(_on_ollama_url_changed)

	# Style the URL field
	var url_style = StyleBoxFlat.new()
	url_style.bg_color = Color(0.05, 0.08, 0.12, 0.9)
	url_style.corner_radius_top_left = 4
	url_style.corner_radius_top_right = 4
	url_style.corner_radius_bottom_left = 4
	url_style.corner_radius_bottom_right = 4
	url_style.border_width_left = 1
	url_style.border_width_right = 1
	url_style.border_width_top = 1
	url_style.border_width_bottom = 1
	url_style.border_color = Color(0.3, 0.8, 0.6, 0.5)
	ollama_url_field.add_theme_stylebox_override("normal", url_style)

	ollama_section.add_child(ollama_url_field)
	ollama_controls.add_child(ollama_section)

	# Advanced settings section
	var advanced_section = VBoxContainer.new()
	var advanced_title = Label.new()
	advanced_title.text = "⚙️ Advanced Settings"
	advanced_title.add_theme_font_size_override("font_size", 12)
	advanced_title.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	advanced_section.add_child(advanced_title)

	# Streaming toggle with modern styling
	ollama_streaming_check = CheckBox.new()
	ollama_streaming_check.text = "🌊 Enable Streaming Responses"
	ollama_streaming_check.button_pressed = true
	ollama_streaming_check.add_theme_font_size_override("font_size", 11)
	ollama_streaming_check.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	ollama_streaming_check.toggled.connect(_on_ollama_streaming_toggled)
	advanced_section.add_child(ollama_streaming_check)

	# Temperature control with modern design
	var temp_container = VBoxContainer.new()
	var temp_header = HBoxContainer.new()
	var temp_label = Label.new()
	temp_label.text = "🌡️ Temperature:"
	temp_label.add_theme_font_size_override("font_size", 10)
	temp_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	temp_header.add_child(temp_label)

	var temp_value_label = Label.new()
	temp_value_label.text = "0.7"
	temp_value_label.add_theme_font_size_override("font_size", 10)
	temp_value_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	temp_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	temp_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	temp_header.add_child(temp_value_label)
	temp_container.add_child(temp_header)

	ollama_temperature_slider = HSlider.new()
	ollama_temperature_slider.min_value = 0.0
	ollama_temperature_slider.max_value = 1.0
	ollama_temperature_slider.step = 0.1
	ollama_temperature_slider.value = 0.7
	ollama_temperature_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ollama_temperature_slider.custom_minimum_size = Vector2(0, 20)
	ollama_temperature_slider.value_changed.connect(_on_ollama_temperature_changed)
	ollama_temperature_slider.value_changed.connect(func(value): temp_value_label.text = "%.1f" % value)
	temp_container.add_child(ollama_temperature_slider)

	advanced_section.add_child(temp_container)
	ollama_controls.add_child(advanced_section)

	# Model management section
	var mgmt_section = VBoxContainer.new()
	var mgmt_title = Label.new()
	mgmt_title.text = "📦 Model Management"
	mgmt_title.add_theme_font_size_override("font_size", 12)
	mgmt_title.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	mgmt_section.add_child(mgmt_title)

	var model_mgmt_grid = GridContainer.new()
	model_mgmt_grid.columns = 2
	model_mgmt_grid.add_theme_constant_override("h_separation", 6)
	model_mgmt_grid.add_theme_constant_override("v_separation", 4)

	# Pull model button
	ollama_pull_button = Button.new()
	ollama_pull_button.text = "📥 Pull Model"
	ollama_pull_button.custom_minimum_size = Vector2(0, 28)
	ollama_pull_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ollama_pull_button.pressed.connect(_on_ollama_pull_model)

	# Style pull button
	var pull_style = StyleBoxFlat.new()
	pull_style.bg_color = Color(0.2, 0.6, 0.8, 0.9)
	pull_style.corner_radius_top_left = 4
	pull_style.corner_radius_top_right = 4
	pull_style.corner_radius_bottom_left = 4
	pull_style.corner_radius_bottom_right = 4
	ollama_pull_button.add_theme_stylebox_override("normal", pull_style)

	# Refresh models button
	var refresh_button = Button.new()
	refresh_button.text = "🔄 Refresh"
	refresh_button.custom_minimum_size = Vector2(0, 28)
	refresh_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	refresh_button.pressed.connect(_on_ollama_refresh_models)

	# Style refresh button
	var refresh_style = StyleBoxFlat.new()
	refresh_style.bg_color = Color(0.6, 0.8, 0.2, 0.9)
	refresh_style.corner_radius_top_left = 4
	refresh_style.corner_radius_top_right = 4
	refresh_style.corner_radius_bottom_left = 4
	refresh_style.corner_radius_bottom_right = 4
	refresh_button.add_theme_stylebox_override("normal", refresh_style)

	model_mgmt_grid.add_child(ollama_pull_button)
	model_mgmt_grid.add_child(refresh_button)
	mgmt_section.add_child(model_mgmt_grid)
	ollama_controls.add_child(mgmt_section)

	# Add to provider-specific container
	provider_specific_container.add_child(ollama_controls)

func _create_openai_controls():
	"""Create OpenAI-specific controls"""
	openai_controls = VBoxContainer.new()
	openai_controls.visible = false
	openai_controls.add_theme_constant_override("separation", 8)

	# OpenAI configuration section
	var openai_section = VBoxContainer.new()
	var openai_title = Label.new()
	openai_title.text = "🧠 OpenAI Configuration"
	openai_title.add_theme_font_size_override("font_size", 12)
	openai_title.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	openai_section.add_child(openai_title)

	# API Key
	var api_key_label = Label.new()
	api_key_label.text = "API Key:"
	api_key_label.add_theme_font_size_override("font_size", 10)
	api_key_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	openai_section.add_child(api_key_label)

	openai_api_key_field = LineEdit.new()
	openai_api_key_field.placeholder_text = "🔑 Enter OpenAI API key"
	openai_api_key_field.secret = true
	openai_api_key_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	openai_api_key_field.custom_minimum_size = Vector2(0, 28)
	openai_api_key_field.text_changed.connect(_on_openai_api_key_changed)
	_style_input_field(openai_api_key_field, Color(0.2, 0.6, 1.0, 0.5))
	openai_section.add_child(openai_api_key_field)

	# Organization ID (optional)
	var org_label = Label.new()
	org_label.text = "Organization ID (Optional):"
	org_label.add_theme_font_size_override("font_size", 10)
	org_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	openai_section.add_child(org_label)

	openai_org_field = LineEdit.new()
	openai_org_field.placeholder_text = "🏢 Organization ID"
	openai_org_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	openai_org_field.custom_minimum_size = Vector2(0, 28)
	openai_org_field.text_changed.connect(_on_openai_org_changed)
	_style_input_field(openai_org_field, Color(0.6, 0.4, 1.0, 0.5))
	openai_section.add_child(openai_org_field)

	openai_controls.add_child(openai_section)

	# Advanced settings
	var advanced_section = VBoxContainer.new()
	var advanced_title = Label.new()
	advanced_title.text = "⚙️ Advanced Settings"
	advanced_title.add_theme_font_size_override("font_size", 12)
	advanced_title.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	advanced_section.add_child(advanced_title)

	# Temperature control
	var temp_container = VBoxContainer.new()
	var temp_header = HBoxContainer.new()
	var temp_label = Label.new()
	temp_label.text = "🌡️ Temperature:"
	temp_label.add_theme_font_size_override("font_size", 10)
	temp_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	temp_header.add_child(temp_label)

	var temp_value_label = Label.new()
	temp_value_label.text = "0.7"
	temp_value_label.add_theme_font_size_override("font_size", 10)
	temp_value_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	temp_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	temp_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	temp_header.add_child(temp_value_label)
	temp_container.add_child(temp_header)

	openai_temperature_slider = HSlider.new()
	openai_temperature_slider.min_value = 0.0
	openai_temperature_slider.max_value = 2.0
	openai_temperature_slider.step = 0.1
	openai_temperature_slider.value = 0.7
	openai_temperature_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	openai_temperature_slider.custom_minimum_size = Vector2(0, 20)
	openai_temperature_slider.value_changed.connect(_on_openai_temperature_changed)
	openai_temperature_slider.value_changed.connect(func(value): temp_value_label.text = "%.1f" % value)
	temp_container.add_child(openai_temperature_slider)
	advanced_section.add_child(temp_container)

	# Max tokens
	var tokens_container = HBoxContainer.new()
	var tokens_label = Label.new()
	tokens_label.text = "📝 Max Tokens:"
	tokens_label.add_theme_font_size_override("font_size", 10)
	tokens_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	tokens_label.custom_minimum_size = Vector2(80, 0)
	tokens_container.add_child(tokens_label)

	openai_max_tokens_field = SpinBox.new()
	openai_max_tokens_field.min_value = 1
	openai_max_tokens_field.max_value = 4096
	openai_max_tokens_field.value = 1000
	openai_max_tokens_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	openai_max_tokens_field.value_changed.connect(_on_openai_max_tokens_changed)
	tokens_container.add_child(openai_max_tokens_field)
	advanced_section.add_child(tokens_container)

	openai_controls.add_child(advanced_section)
	provider_specific_container.add_child(openai_controls)

func _style_input_field(field: LineEdit, border_color: Color):
	"""Apply consistent styling to input fields"""
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.15, 0.9)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = border_color
	field.add_theme_stylebox_override("normal", style)
	field.add_theme_stylebox_override("focus", style)

func _create_gemini_controls():
	"""Create Gemini-specific controls"""
	gemini_controls = VBoxContainer.new()
	gemini_controls.visible = false
	gemini_controls.add_theme_constant_override("separation", 8)

	# Gemini configuration section
	var gemini_section = VBoxContainer.new()
	var gemini_title = Label.new()
	gemini_title.text = "🤖 Gemini Configuration"
	gemini_title.add_theme_font_size_override("font_size", 12)
	gemini_title.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	gemini_section.add_child(gemini_title)

	# API Key
	var api_key_label = Label.new()
	api_key_label.text = "API Key:"
	api_key_label.add_theme_font_size_override("font_size", 10)
	api_key_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	gemini_section.add_child(api_key_label)

	gemini_api_key_field = LineEdit.new()
	gemini_api_key_field.placeholder_text = "🔑 Enter Gemini API key (Free tier available)"
	gemini_api_key_field.secret = true
	gemini_api_key_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gemini_api_key_field.custom_minimum_size = Vector2(0, 28)
	gemini_api_key_field.text_changed.connect(_on_gemini_api_key_changed)
	_style_input_field(gemini_api_key_field, Color(0.4, 0.8, 0.4, 0.5))
	gemini_section.add_child(gemini_api_key_field)

	gemini_controls.add_child(gemini_section)

	# Advanced settings
	var advanced_section = VBoxContainer.new()
	var advanced_title = Label.new()
	advanced_title.text = "⚙️ Advanced Settings"
	advanced_title.add_theme_font_size_override("font_size", 12)
	advanced_title.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	advanced_section.add_child(advanced_title)

	# Safety settings
	var safety_container = VBoxContainer.new()
	var safety_label = Label.new()
	safety_label.text = "🛡️ Safety Settings:"
	safety_label.add_theme_font_size_override("font_size", 10)
	safety_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	safety_container.add_child(safety_label)

	gemini_safety_settings = OptionButton.new()
	gemini_safety_settings.add_item("🔒 High Safety (Default)")
	gemini_safety_settings.add_item("⚖️ Medium Safety")
	gemini_safety_settings.add_item("⚠️ Low Safety")
	gemini_safety_settings.selected = 0
	gemini_safety_settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gemini_safety_settings.custom_minimum_size = Vector2(0, 28)
	gemini_safety_settings.item_selected.connect(_on_gemini_safety_changed)
	safety_container.add_child(gemini_safety_settings)
	advanced_section.add_child(safety_container)

	# Temperature control
	var temp_container = VBoxContainer.new()
	var temp_header = HBoxContainer.new()
	var temp_label = Label.new()
	temp_label.text = "🌡️ Temperature:"
	temp_label.add_theme_font_size_override("font_size", 10)
	temp_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	temp_header.add_child(temp_label)

	var temp_value_label = Label.new()
	temp_value_label.text = "0.7"
	temp_value_label.add_theme_font_size_override("font_size", 10)
	temp_value_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	temp_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	temp_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	temp_header.add_child(temp_value_label)
	temp_container.add_child(temp_header)

	gemini_temperature_slider = HSlider.new()
	gemini_temperature_slider.min_value = 0.0
	gemini_temperature_slider.max_value = 1.0
	gemini_temperature_slider.step = 0.1
	gemini_temperature_slider.value = 0.7
	gemini_temperature_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gemini_temperature_slider.custom_minimum_size = Vector2(0, 20)
	gemini_temperature_slider.value_changed.connect(_on_gemini_temperature_changed)
	gemini_temperature_slider.value_changed.connect(func(value): temp_value_label.text = "%.1f" % value)
	temp_container.add_child(gemini_temperature_slider)
	advanced_section.add_child(temp_container)

	gemini_controls.add_child(advanced_section)
	provider_specific_container.add_child(gemini_controls)

func _create_anthropic_controls():
	"""Create Anthropic-specific controls"""
	anthropic_controls = VBoxContainer.new()
	anthropic_controls.visible = false
	anthropic_controls.add_theme_constant_override("separation", 8)

	# Anthropic configuration section
	var anthropic_section = VBoxContainer.new()
	var anthropic_title = Label.new()
	anthropic_title.text = "🎭 Anthropic Configuration"
	anthropic_title.add_theme_font_size_override("font_size", 12)
	anthropic_title.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	anthropic_section.add_child(anthropic_title)

	# API Key
	var api_key_label = Label.new()
	api_key_label.text = "API Key:"
	api_key_label.add_theme_font_size_override("font_size", 10)
	api_key_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	anthropic_section.add_child(api_key_label)

	anthropic_api_key_field = LineEdit.new()
	anthropic_api_key_field.placeholder_text = "🔑 Enter Anthropic API key"
	anthropic_api_key_field.secret = true
	anthropic_api_key_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	anthropic_api_key_field.custom_minimum_size = Vector2(0, 28)
	anthropic_api_key_field.text_changed.connect(_on_anthropic_api_key_changed)
	_style_input_field(anthropic_api_key_field, Color(0.8, 0.4, 0.8, 0.5))
	anthropic_section.add_child(anthropic_api_key_field)

	anthropic_controls.add_child(anthropic_section)
	provider_specific_container.add_child(anthropic_controls)

func _create_groq_controls():
	"""Create Groq-specific controls"""
	groq_controls = VBoxContainer.new()
	groq_controls.visible = false
	groq_controls.add_theme_constant_override("separation", 8)

	# Groq configuration section
	var groq_section = VBoxContainer.new()
	var groq_title = Label.new()
	groq_title.text = "⚡ Groq Configuration"
	groq_title.add_theme_font_size_override("font_size", 12)
	groq_title.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	groq_section.add_child(groq_title)

	# API Key
	var api_key_label = Label.new()
	api_key_label.text = "API Key:"
	api_key_label.add_theme_font_size_override("font_size", 10)
	api_key_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	groq_section.add_child(api_key_label)

	groq_api_key_field = LineEdit.new()
	groq_api_key_field.placeholder_text = "🔑 Enter Groq API key (Free tier available)"
	groq_api_key_field.secret = true
	groq_api_key_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	groq_api_key_field.custom_minimum_size = Vector2(0, 28)
	groq_api_key_field.text_changed.connect(_on_groq_api_key_changed)
	_style_input_field(groq_api_key_field, Color(1.0, 0.6, 0.2, 0.5))
	groq_section.add_child(groq_api_key_field)

	groq_controls.add_child(groq_section)
	provider_specific_container.add_child(groq_controls)

# Provider-specific event handlers
func _on_openai_api_key_changed(new_key: String):
	"""Handle OpenAI API key change"""
	if api_manager:
		api_manager.set_api_key(new_key)
	_update_provider_status("openai")

func _on_openai_org_changed(new_org: String):
	"""Handle OpenAI organization change"""
	# Store organization ID for OpenAI requests
	pass

func _on_openai_temperature_changed(value: float):
	"""Handle OpenAI temperature change"""
	if api_manager:
		api_manager.set_temperature(value)

func _on_openai_max_tokens_changed(value: float):
	"""Handle OpenAI max tokens change"""
	if api_manager:
		api_manager.set_max_tokens(int(value))

func _on_gemini_api_key_changed(new_key: String):
	"""Handle Gemini API key change"""
	if api_manager:
		api_manager.set_api_key(new_key)
	_update_provider_status("gemini")

func _on_gemini_safety_changed(index: int):
	"""Handle Gemini safety settings change"""
	# Store safety settings for Gemini requests
	pass

func _on_gemini_temperature_changed(value: float):
	"""Handle Gemini temperature change"""
	if api_manager:
		api_manager.set_temperature(value)

func _on_anthropic_api_key_changed(new_key: String):
	"""Handle Anthropic API key change"""
	if api_manager:
		api_manager.set_api_key(new_key)
	_update_provider_status("anthropic")

func _on_groq_api_key_changed(new_key: String):
	"""Handle Groq API key change"""
	if api_manager:
		api_manager.set_api_key(new_key)
	_update_provider_status("groq")

func _on_ollama_url_changed(new_url: String):
	"""Handle Ollama URL change"""
	var ollama_handler = api_manager.get_ollama_handler()
	if ollama_handler:
		ollama_handler.set_base_url(new_url)

func _on_ollama_streaming_toggled(enabled: bool):
	"""Handle streaming toggle"""
	var ollama_handler = api_manager.get_ollama_handler()
	if ollama_handler:
		ollama_handler.enable_streaming(enabled)

func _on_ollama_temperature_changed(value: float):
	"""Handle temperature change"""
	var ollama_handler = api_manager.get_ollama_handler()
	if ollama_handler:
		ollama_handler.set_temperature(value)

func _on_ollama_pull_model():
	"""Handle model pull request"""
	var model_name = model_option.get_item_text(model_option.selected) if model_option.selected >= 0 else "llama3.2"
	var ollama_handler = api_manager.get_ollama_handler()
	if ollama_handler:
		_add_to_chat("System", "Pulling model: " + model_name + " (this may take a while...)", Color.YELLOW)
		ollama_handler.pull_model(model_name)

func _on_ollama_refresh_models():
	"""Handle model list refresh"""
	var ollama_handler = api_manager.get_ollama_handler()
	if ollama_handler:
		_add_to_chat("System", "Refreshing Ollama model list...", Color.YELLOW)
		ollama_handler.refresh_model_list()

func _create_ollama_quick_actions():
	"""Create Ollama-specific quick action buttons"""
	var separator = HSeparator.new()
	separator.visible = false
	quick_content.add_child(separator)

	var ollama_label = Label.new()
	ollama_label.text = "🏠 Ollama Features:"
	ollama_label.visible = false
	quick_content.add_child(ollama_label)

	var explain_btn = Button.new()
	explain_btn.text = "🔍 Explain Code"
	explain_btn.pressed.connect(_on_ollama_explain_code)
	explain_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	explain_btn.visible = false
	quick_content.add_child(explain_btn)

	var improve_btn = Button.new()
	improve_btn.text = "⚡ Improve Code"
	improve_btn.pressed.connect(_on_ollama_improve_code)
	improve_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	improve_btn.visible = false
	quick_content.add_child(improve_btn)

	var code_gen_btn = Button.new()
	code_gen_btn.text = "🎯 Generate Code"
	code_gen_btn.pressed.connect(_on_ollama_generate_code)
	code_gen_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_gen_btn.visible = false
	quick_content.add_child(code_gen_btn)

	# Store references for visibility control
	ollama_quick_actions = [separator, ollama_label, explain_btn, improve_btn, code_gen_btn]

func _on_ollama_explain_code():
	"""Explain selected code using Ollama"""
	var selected_text = _get_selected_text_from_editor()
	if selected_text.is_empty():
		_add_to_chat("System", "Please select some code to explain", Color.ORANGE)
		return

	var ollama_handler = api_manager.get_ollama_handler()
	if ollama_handler:
		_add_to_chat("User", "Explain this code: " + selected_text.substr(0, 100) + "...", Color.WHITE)
		ollama_handler.explain_code(selected_text)

func _on_ollama_improve_code():
	"""Improve selected code using Ollama"""
	var selected_text = _get_selected_text_from_editor()
	if selected_text.is_empty():
		_add_to_chat("System", "Please select some code to improve", Color.ORANGE)
		return

	var ollama_handler = api_manager.get_ollama_handler()
	if ollama_handler:
		_add_to_chat("User", "Improve this code: " + selected_text.substr(0, 100) + "...", Color.WHITE)
		ollama_handler.improve_code(selected_text)

func _on_ollama_generate_code():
	"""Generate code using Ollama with specialized models"""
	var prompt = input_field.text.strip_edges()
	if prompt.is_empty():
		_add_to_chat("System", "Please enter a code generation request", Color.ORANGE)
		return

	var ollama_handler = api_manager.get_ollama_handler()
	if ollama_handler:
		_add_to_chat("User", "Generate: " + prompt, Color.WHITE)
		ollama_handler.generate_code(prompt, "gdscript")
		input_field.clear()

func _get_selected_text_from_editor() -> String:
	"""Get selected text from the current script editor"""
	if not editor_integration:
		return ""
	return editor_integration.get_selected_text()

func _create_editor_quick_actions():
	"""Create editor integration quick action buttons"""
	var separator = HSeparator.new()
	quick_content.add_child(separator)

	var editor_label = Label.new()
	editor_label.text = "📝 Editor Actions:"
	quick_content.add_child(editor_label)

	# Editor status indicator
	var status_label = Label.new()
	status_label.text = _get_editor_status()
	status_label.add_theme_color_override("font_color", Color.GRAY)
	quick_content.add_child(status_label)

	# Update status periodically
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.timeout.connect(func(): status_label.text = _get_editor_status())
	timer.autostart = true
	add_child(timer)

	var read_file_btn = Button.new()
	read_file_btn.text = "📖 Read Current File"
	read_file_btn.pressed.connect(_on_read_current_file)
	read_file_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quick_content.add_child(read_file_btn)

	var analyze_selection_btn = Button.new()
	analyze_selection_btn.text = "🔍 Analyze Selection"
	analyze_selection_btn.pressed.connect(_on_analyze_selection)
	analyze_selection_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quick_content.add_child(analyze_selection_btn)

	var improve_function_btn = Button.new()
	improve_function_btn.text = "⚡ Improve Function"
	improve_function_btn.pressed.connect(_on_improve_current_function)
	improve_function_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quick_content.add_child(improve_function_btn)

	var add_comments_btn = Button.new()
	add_comments_btn.text = "💬 Add Comments"
	add_comments_btn.pressed.connect(_on_add_comments)
	add_comments_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quick_content.add_child(add_comments_btn)

	var refactor_btn = Button.new()
	refactor_btn.text = "🔧 Refactor Code"
	refactor_btn.pressed.connect(_on_refactor_code)
	refactor_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quick_content.add_child(refactor_btn)

	var insert_at_cursor_btn = Button.new()
	insert_at_cursor_btn.text = "➕ Insert at Cursor"
	insert_at_cursor_btn.pressed.connect(_on_insert_at_cursor)
	insert_at_cursor_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quick_content.add_child(insert_at_cursor_btn)

	# Editor context menu button
	var editor_menu_btn = Button.new()
	editor_menu_btn.text = "📋 Editor Menu"
	editor_menu_btn.pressed.connect(_show_editor_context_menu)
	editor_menu_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quick_content.add_child(editor_menu_btn)

	# Create editor context menu
	_create_editor_context_menu()

func _on_read_current_file():
	"""Read and analyze the current file"""
	var file_content = editor_integration.get_all_text()
	if file_content.is_empty():
		_add_to_chat("System", "No file is currently open in the editor", Color.ORANGE)
		return

	var file_path = editor_integration.get_current_file_path()
	var class_info = editor_integration.get_class_info()

	var summary = "📖 **Current File Analysis**\n"
	summary += "**File:** " + file_path + "\n"
	summary += "**Lines:** " + str(class_info.get("line_count", 0)) + "\n"
	summary += "**Class:** " + class_info.get("class_name", "N/A") + "\n"
	summary += "**Extends:** " + class_info.get("extends", "N/A") + "\n"
	summary += "**Functions:** " + str(class_info.get("functions", []).size()) + "\n"
	summary += "**Variables:** " + str(class_info.get("variables", []).size()) + "\n\n"

	_add_to_chat("System", summary, Color.CYAN)

	# Ask AI to analyze the code
	var prompt = "Analyze this GDScript code and provide insights about its structure, purpose, and potential improvements:\n\n```gdscript\n" + file_content + "\n```"
	api_manager.send_chat_request(prompt)

func _on_analyze_selection():
	"""Analyze the currently selected code"""
	var selected_text = editor_integration.get_selected_text()
	if selected_text.is_empty():
		_add_to_chat("System", "Please select some code to analyze", Color.ORANGE)
		return

	_add_to_chat("User", "Analyzing selected code: " + selected_text.substr(0, 100) + "...", Color.WHITE)

	var prompt = "Analyze this GDScript code snippet. Explain what it does, identify any issues, and suggest improvements:\n\n```gdscript\n" + selected_text + "\n```"
	api_manager.send_chat_request(prompt)

func _on_improve_current_function():
	"""Improve the function at the cursor position"""
	var func_info = editor_integration.get_function_at_cursor()
	if func_info.is_empty():
		_add_to_chat("System", "No function found at cursor position", Color.ORANGE)
		return

	_add_to_chat("User", "Improving function: " + func_info["name"], Color.WHITE)

	var prompt = "Improve this GDScript function. Make it more efficient, readable, and follow best practices. Return only the improved function code:\n\n```gdscript\n" + func_info["text"] + "\n```"

	# Store function info for replacement
	current_function_to_replace = func_info
	api_manager.send_chat_request(prompt)

func _on_add_comments():
	"""Add comments to selected code or current function"""
	var selected_text = editor_integration.get_selected_text()
	var target_text = ""
	var is_selection = false

	if not selected_text.is_empty():
		target_text = selected_text
		is_selection = true
	else:
		var func_info = editor_integration.get_function_at_cursor()
		if not func_info.is_empty():
			target_text = func_info["text"]
			current_function_to_replace = func_info
		else:
			_add_to_chat("System", "Please select code or place cursor in a function", Color.ORANGE)
			return

	_add_to_chat("User", "Adding comments to code...", Color.WHITE)

	var prompt = "Add comprehensive comments to this GDScript code. Include function documentation, inline comments for complex logic, and parameter descriptions. Return only the commented code:\n\n```gdscript\n" + target_text + "\n```"

	if is_selection:
		replace_selection_with_response = true

	api_manager.send_chat_request(prompt)

func _on_refactor_code():
	"""Refactor selected code or current function"""
	var selected_text = editor_integration.get_selected_text()
	var target_text = ""
	var is_selection = false

	if not selected_text.is_empty():
		target_text = selected_text
		is_selection = true
	else:
		var func_info = editor_integration.get_function_at_cursor()
		if not func_info.is_empty():
			target_text = func_info["text"]
			current_function_to_replace = func_info
		else:
			_add_to_chat("System", "Please select code or place cursor in a function", Color.ORANGE)
			return

	_add_to_chat("User", "Refactoring code...", Color.WHITE)

	var prompt = "Refactor this GDScript code to improve readability, performance, and maintainability. Follow GDScript best practices and conventions. Return only the refactored code:\n\n```gdscript\n" + target_text + "\n```"

	if is_selection:
		replace_selection_with_response = true

	api_manager.send_chat_request(prompt)

func _on_insert_at_cursor():
	"""Insert AI-generated code at cursor position"""
	var prompt = input_field.text.strip_edges()
	if prompt.is_empty():
		_add_to_chat("System", "Please enter a description of the code to generate", Color.ORANGE)
		return

	_add_to_chat("User", "Generating code: " + prompt, Color.WHITE)

	var context = editor_integration.get_lines_around_cursor(3, 3)
	var full_prompt = "Generate GDScript code for: " + prompt + "\n\nContext (cursor is at >>> line):\n" + context + "\n\nReturn only the code to insert:"

	insert_at_cursor_mode = true
	api_manager.send_chat_request(full_prompt)
	input_field.clear()

# State variables for editor operations
var current_function_to_replace: Dictionary = {}
var replace_selection_with_response: bool = false
var insert_at_cursor_mode: bool = false

func _on_code_inserted(text: String):
	"""Handle code insertion event"""
	_add_to_chat("System", "✅ Code inserted: " + text.substr(0, 50) + "...", Color.GREEN)

func _on_code_replaced(old_text: String, new_text: String):
	"""Handle code replacement event"""
	_add_to_chat("System", "✅ Code replaced: " + old_text.substr(0, 30) + "... → " + new_text.substr(0, 30) + "...", Color.GREEN)

func _on_selection_changed(selected_text: String):
	"""Handle selection change event"""
	if not selected_text.is_empty():
		_add_to_chat("System", "📝 Selected: " + selected_text.substr(0, 50) + "...", Color.GRAY)

func _create_editor_context_menu():
	"""Create context menu for editor operations"""
	editor_context_menu = PopupMenu.new()
	add_child(editor_context_menu)

	editor_context_menu.add_item("📖 Read Entire File", 0)
	editor_context_menu.add_item("📝 Get File Info", 1)
	editor_context_menu.add_separator()
	editor_context_menu.add_item("🔍 Analyze Function at Cursor", 2)
	editor_context_menu.add_item("📋 Copy Function to Chat", 3)
	editor_context_menu.add_item("🔧 Refactor Function", 4)
	editor_context_menu.add_separator()
	editor_context_menu.add_item("💬 Add Documentation", 5)
	editor_context_menu.add_item("🐛 Find Bugs", 6)
	editor_context_menu.add_item("⚡ Optimize Performance", 7)
	editor_context_menu.add_separator()
	editor_context_menu.add_item("📊 Generate Unit Tests", 8)
	editor_context_menu.add_item("🎯 Add Type Hints", 9)
	editor_context_menu.add_item("🔄 Convert to Async", 10)

	editor_context_menu.id_pressed.connect(_on_editor_context_menu_pressed)

func _show_editor_context_menu():
	"""Show the editor context menu"""
	if not editor_context_menu:
		return

	var button_pos = get_global_mouse_position()
	editor_context_menu.popup(Rect2i(button_pos, Vector2i(200, 300)))

func _on_editor_context_menu_pressed(id: int):
	"""Handle editor context menu selection"""
	match id:
		0: # Read Entire File
			_on_read_current_file()
		1: # Get File Info
			_show_file_info()
		2: # Analyze Function at Cursor
			_analyze_function_at_cursor()
		3: # Copy Function to Chat
			_copy_function_to_chat()
		4: # Refactor Function
			_on_improve_current_function()
		5: # Add Documentation
			_add_documentation()
		6: # Find Bugs
			_find_bugs()
		7: # Optimize Performance
			_optimize_performance()
		8: # Generate Unit Tests
			_generate_unit_tests()
		9: # Add Type Hints
			_add_type_hints()
		10: # Convert to Async
			_convert_to_async()

func _show_file_info():
	"""Show detailed file information"""
	var editor_info = editor_integration.get_editor_info()
	var class_info = editor_info.get("class_info", {})

	var info_text = "📊 **File Information**\n\n"
	info_text += "**Path:** " + editor_info.get("file_path", "N/A") + "\n"
	info_text += "**Lines:** " + str(editor_info.get("total_lines", 0)) + "\n"
	info_text += "**Cursor:** Line " + str(editor_info.get("cursor_position", Vector2i()).x + 1) + "\n\n"

	info_text += "**Class:** " + class_info.get("class_name", "N/A") + "\n"
	info_text += "**Extends:** " + class_info.get("extends", "N/A") + "\n\n"

	var functions = class_info.get("functions", [])
	info_text += "**Functions (" + str(functions.size()) + "):**\n"
	for func_name in functions:
		info_text += "  • " + func_name + "\n"

	var variables = class_info.get("variables", [])
	info_text += "\n**Variables (" + str(variables.size()) + "):**\n"
	for var_name in variables:
		info_text += "  • " + var_name + "\n"

	_add_to_chat("System", info_text, Color.CYAN)

func _analyze_function_at_cursor():
	"""Analyze the function at cursor position"""
	var func_info = editor_integration.get_function_at_cursor()
	if func_info.is_empty():
		_add_to_chat("System", "No function found at cursor position", Color.ORANGE)
		return

	var prompt = "Analyze this GDScript function in detail. Explain its purpose, parameters, return value, complexity, and suggest any improvements:\n\n```gdscript\n" + func_info["text"] + "\n```"
	api_manager.send_chat_request(prompt)

func _copy_function_to_chat():
	"""Copy function at cursor to chat for discussion"""
	var func_info = editor_integration.get_function_at_cursor()
	if func_info.is_empty():
		_add_to_chat("System", "No function found at cursor position", Color.ORANGE)
		return

	_add_to_chat("User", "Function: " + func_info["name"] + "\n```gdscript\n" + func_info["text"] + "\n```", Color.WHITE)

func _add_documentation():
	"""Add comprehensive documentation to function"""
	var func_info = editor_integration.get_function_at_cursor()
	if func_info.is_empty():
		_add_to_chat("System", "No function found at cursor position", Color.ORANGE)
		return

	current_function_to_replace = func_info
	var prompt = "Add comprehensive GDScript documentation to this function. Include function description, parameter descriptions with types, return value description, and usage examples. Return only the documented function:\n\n```gdscript\n" + func_info["text"] + "\n```"
	api_manager.send_chat_request(prompt)

func _find_bugs():
	"""Find potential bugs in selected code or current function"""
	var target_code = editor_integration.get_selected_text()
	if target_code.is_empty():
		var func_info = editor_integration.get_function_at_cursor()
		if not func_info.is_empty():
			target_code = func_info["text"]
		else:
			target_code = editor_integration.get_all_text()

	var prompt = "Analyze this GDScript code for potential bugs, errors, and issues. Look for:\n1. Logic errors\n2. Null reference issues\n3. Type mismatches\n4. Performance problems\n5. Memory leaks\n6. Threading issues\n\nCode:\n```gdscript\n" + target_code + "\n```"
	api_manager.send_chat_request(prompt)

func _optimize_performance():
	"""Optimize performance of selected code or current function"""
	var target_code = editor_integration.get_selected_text()
	var is_selection = not target_code.is_empty()

	if target_code.is_empty():
		var func_info = editor_integration.get_function_at_cursor()
		if not func_info.is_empty():
			target_code = func_info["text"]
			current_function_to_replace = func_info
		else:
			_add_to_chat("System", "Please select code or place cursor in a function", Color.ORANGE)
			return

	if is_selection:
		replace_selection_with_response = true

	var prompt = "Optimize this GDScript code for better performance. Focus on:\n1. Algorithm efficiency\n2. Memory usage\n3. Godot-specific optimizations\n4. Caching strategies\n5. Loop optimizations\n\nReturn only the optimized code:\n```gdscript\n" + target_code + "\n```"
	api_manager.send_chat_request(prompt)

func _generate_unit_tests():
	"""Generate unit tests for current function"""
	var func_info = editor_integration.get_function_at_cursor()
	if func_info.is_empty():
		_add_to_chat("System", "No function found at cursor position", Color.ORANGE)
		return

	var prompt = "Generate comprehensive unit tests for this GDScript function using Godot's testing framework. Include edge cases, error conditions, and normal usage:\n\n```gdscript\n" + func_info["text"] + "\n```"
	api_manager.send_chat_request(prompt)

func _add_type_hints():
	"""Add type hints to function"""
	var func_info = editor_integration.get_function_at_cursor()
	if func_info.is_empty():
		_add_to_chat("System", "No function found at cursor position", Color.ORANGE)
		return

	current_function_to_replace = func_info
	var prompt = "Add proper type hints to this GDScript function. Include parameter types, return type, and variable types where appropriate. Return only the function with type hints:\n\n```gdscript\n" + func_info["text"] + "\n```"
	api_manager.send_chat_request(prompt)

func _convert_to_async():
	"""Convert function to async if beneficial"""
	var func_info = editor_integration.get_function_at_cursor()
	if func_info.is_empty():
		_add_to_chat("System", "No function found at cursor position", Color.ORANGE)
		return

	current_function_to_replace = func_info
	var prompt = "Analyze this GDScript function and convert it to async if it would benefit from asynchronous execution. Add proper await calls and error handling. If async is not beneficial, explain why and return the original function:\n\n```gdscript\n" + func_info["text"] + "\n```"
	api_manager.send_chat_request(prompt)

func _get_editor_status() -> String:
	"""Get current editor status for display"""
	if not editor_integration:
		return "❌ Editor integration not available"

	var file_path = editor_integration.get_current_file_path()
	if file_path.is_empty():
		return "📄 No file open"

	var file_name = file_path.get_file()
	var cursor_pos = editor_integration.get_cursor_position()
	var selected = editor_integration.get_selected_text()

	var status = "📝 " + file_name + " (Line " + str(cursor_pos.x + 1) + ")"
	if not selected.is_empty():
		status += " | " + str(selected.length()) + " chars selected"

	return status

func _on_api_key_changed(new_text: String):
	api_manager.set_api_key(new_text)

func _on_send_pressed():
	_on_send_message(input_field.text)

func _on_send_message(message: String):
	if message.is_empty():
		return

	_add_to_chat("You", message, Color.CYAN)
	input_field.clear()
	send_button.disabled = true

	# Update UI status
	_show_typing_indicator(true)
	_update_ai_status("Processing...", Color.YELLOW)
	_show_progress(true, 0.0)

	# Check if this is a code generation request
	if "generate" in message.to_lower() or "create" in message.to_lower() or "write" in message.to_lower():
		api_manager.generate_code(message)
	else:
		api_manager.send_chat_request(message)

func _quick_generate(prompt: String):
	_add_to_chat("System", "Generating: " + prompt, Color.YELLOW)
	send_button.disabled = true
	api_manager.generate_code(prompt)

func _on_generate_class():
	_add_to_chat("System", "Generating Player Movement Template", Color.YELLOW)
	var CodeTemplates = preload("res://addons/ai_coding_assistant/utils/code_templates.gd")
	var template = CodeTemplates.get_template("player_movement")
	if template != "":
		code_output.text = template
		apply_button.disabled = false
		_add_to_chat("AI", "Generated player movement template with physics and controls", Color.GREEN)
	else:
		_quick_generate("Create a 2D player movement script with physics, jumping, and WASD controls")

func _on_generate_singleton():
	_add_to_chat("System", "Generating Singleton Template", Color.YELLOW)
	var CodeTemplates = preload("res://addons/ai_coding_assistant/utils/code_templates.gd")
	var template = CodeTemplates.get_template("singleton")
	if template != "":
		code_output.text = template
		apply_button.disabled = false
		_add_to_chat("AI", "Generated singleton/autoload template with game state management", Color.GREEN)
	else:
		_quick_generate("Create a GDScript singleton/autoload script template")

func _on_generate_ui():
	_add_to_chat("System", "Generating UI Controller Template", Color.YELLOW)
	var CodeTemplates = preload("res://addons/ai_coding_assistant/utils/code_templates.gd")
	var template = CodeTemplates.get_template("ui_controller")
	if template != "":
		code_output.text = template
		apply_button.disabled = false
		_add_to_chat("AI", "Generated UI controller template with menu management", Color.GREEN)
	else:
		_quick_generate("Create a GDScript UI controller with common UI interaction methods")

func _on_generate_save_system():
	_add_to_chat("System", "Generating Save System Template", Color.YELLOW)
	var CodeTemplates = preload("res://addons/ai_coding_assistant/utils/code_templates.gd")
	var template = CodeTemplates.get_template("save_system")
	if template != "":
		code_output.text = template
		apply_button.disabled = false
		_add_to_chat("AI", "Generated save/load system template with JSON support", Color.GREEN)
	else:
		_quick_generate("Create a save and load system for Godot using JSON files")

func _on_generate_audio_manager():
	_add_to_chat("System", "Generating Audio Manager Template", Color.YELLOW)
	var CodeTemplates = preload("res://addons/ai_coding_assistant/utils/code_templates.gd")
	var template = CodeTemplates.get_template("audio_manager")
	if template != "":
		code_output.text = template
		apply_button.disabled = false
		_add_to_chat("AI", "Generated audio manager template with music and SFX control", Color.GREEN)
	else:
		_quick_generate("Create an audio manager for Godot with music and sound effects control")

func _on_generate_state_machine():
	_add_to_chat("System", "Generating State Machine Template", Color.YELLOW)
	var CodeTemplates = preload("res://addons/ai_coding_assistant/utils/code_templates.gd")
	var template = CodeTemplates.get_template("state_machine")
	if template != "":
		code_output.text = template
		apply_button.disabled = false
		_add_to_chat("AI", "Generated state machine template with flexible state management", Color.GREEN)
	else:
		_quick_generate("Create a generic state machine implementation for Godot")

func _on_response_received(response: String):
	send_button.disabled = false
	_add_to_chat("AI", response, Color.GREEN)

	# Update UI status
	_show_typing_indicator(false)
	_update_ai_status("Ready", Color.GREEN)
	_show_progress(false)

	# Handle different editor operation modes
	if insert_at_cursor_mode:
		_handle_insert_at_cursor_response(response)
		insert_at_cursor_mode = false
		return

	if replace_selection_with_response:
		_handle_replace_selection_response(response)
		replace_selection_with_response = false
		return

	if not current_function_to_replace.is_empty():
		_handle_function_replacement_response(response)
		current_function_to_replace = {}
		return

	# If response looks like code, put it in the code output
	var AIUtils = preload("res://addons/ai_coding_assistant/ai/ai_utils.gd")
	if AIUtils.is_code_response(response):
		current_generated_code = AIUtils.extract_code_from_response(response)
		code_output.text = current_generated_code
		apply_button.disabled = false

func _handle_insert_at_cursor_response(response: String):
	"""Handle response for insert at cursor operation"""
	var AIUtils = preload("res://addons/ai_coding_assistant/ai/ai_utils.gd")
	var code_to_insert = ""

	if AIUtils.is_code_response(response):
		code_to_insert = AIUtils.extract_code_from_response(response)
	else:
		# If no code blocks found, use the response as-is (might be a simple statement)
		code_to_insert = response.strip_edges()

	if not code_to_insert.is_empty():
		if editor_integration.insert_text_at_cursor(code_to_insert):
			_add_to_chat("System", "✅ Code inserted at cursor position", Color.GREEN)
		else:
			_add_to_chat("System", "❌ Failed to insert code - no active editor", Color.RED)
	else:
		_add_to_chat("System", "❌ No code found in response", Color.RED)

func _handle_replace_selection_response(response: String):
	"""Handle response for replace selection operation"""
	var AIUtils = preload("res://addons/ai_coding_assistant/ai/ai_utils.gd")
	var code_to_replace = ""

	if AIUtils.is_code_response(response):
		code_to_replace = AIUtils.extract_code_from_response(response)
	else:
		code_to_replace = response.strip_edges()

	if not code_to_replace.is_empty():
		if editor_integration.replace_selected_text(code_to_replace):
			_add_to_chat("System", "✅ Selected text replaced", Color.GREEN)
		else:
			_add_to_chat("System", "❌ Failed to replace selection", Color.RED)
	else:
		_add_to_chat("System", "❌ No code found in response", Color.RED)

func _handle_function_replacement_response(response: String):
	"""Handle response for function replacement operation"""
	var AIUtils = preload("res://addons/ai_coding_assistant/ai/ai_utils.gd")
	var new_function_code = ""

	if AIUtils.is_code_response(response):
		new_function_code = AIUtils.extract_code_from_response(response)
	else:
		new_function_code = response.strip_edges()

	if not new_function_code.is_empty():
		if editor_integration.replace_function(current_function_to_replace["name"], new_function_code):
			_add_to_chat("System", "✅ Function '" + current_function_to_replace["name"] + "' replaced", Color.GREEN)
		else:
			_add_to_chat("System", "❌ Failed to replace function", Color.RED)
			# Fallback: put code in output for manual application
			code_output.text = new_function_code
			apply_button.disabled = false
			_add_to_chat("System", "Code available in output panel for manual application", Color.YELLOW)
	else:
		_add_to_chat("System", "❌ No code found in response", Color.RED)

func _on_error_occurred(error: String, request_id: String = ""):
	send_button.disabled = false
	_add_to_chat("Error", error, Color.RED)

	# Update UI status
	_show_typing_indicator(false)
	_update_ai_status("Error", Color.RED)
	_show_progress(false)

func _add_chat_message(message: String, sender: String = "Agent"):
	"""Add a chat message with appropriate color based on sender"""
	var color = Color.WHITE
	match sender.to_lower():
		"agent":
			color = Color.CYAN
		"system":
			color = Color.YELLOW
		"error":
			color = Color.RED
		"success":
			color = Color.GREEN
		_:
			color = Color.WHITE

	_add_to_chat(sender, message, color)

func _add_to_chat(sender: String, message: String, color: Color):
	var color_hex = "#" + color.to_html(false)
	var formatted_message = _format_message_with_markdown(message)

	# Modern message formatting with better visual design
	var datetime_parts = Time.get_datetime_string_from_system().split(" ")
	var timestamp = ""
	if datetime_parts.size() >= 2:
		timestamp = datetime_parts[1].substr(0, 5)  # HH:MM format
	else:
		timestamp = Time.get_time_string_from_system().substr(0, 5)  # Fallback to time only

	# Enhanced sender formatting with icons and modern styling
	var sender_icon = ""
	var sender_color = color_hex
	match sender:
		"You":
			sender_icon = "👤"
			sender_color = "#4FC3F7"  # Light blue
		"AI":
			sender_icon = "🤖"
			sender_color = "#66BB6A"  # Light green
		"System":
			sender_icon = "⚙️"
			sender_color = "#FFA726"  # Orange
		"Error":
			sender_icon = "❌"
			sender_color = "#EF5350"  # Red
		_:
			sender_icon = "💬"

	# Create modern message bubble effect
	var message_header = "[color=" + sender_color + "][b]" + sender_icon + " " + sender + "[/b][/color] [color=#666666][" + timestamp + "][/color]"
	var message_body = "[color=#E0E0E0]" + formatted_message + "[/color]"

	# Add message with modern spacing and visual separation
	chat_history.append_text(message_header + "\n")
	chat_history.append_text(message_body + "\n")
	chat_history.append_text("[color=#333333]────────────────────────────────[/color]\n\n")

func _format_message_with_markdown(message: String) -> String:
	# Enhanced markdown formatting with error handling
	var formatted = message

	# Safety check for empty or null messages
	if formatted.is_empty():
		return formatted

	# Format code blocks with language-specific syntax highlighting
	var regex_code_block = RegEx.new()
	if regex_code_block.compile("```(\\w+)?\\n?([\\s\\S]*?)```") == OK:
		var results = regex_code_block.search_all(formatted)

		for result in results:
			var language = result.get_string(1) if result.get_string(1) != "" else "gdscript"
			var code_content = result.get_string(2)
			var highlighted_code = _apply_syntax_highlighting(code_content, language)
			var full_match = result.get_string(0)

			# Simplified code block styling to prevent display issues
			var styled_code = "[bgcolor=#1e1e1e][color=#d4d4d4][font_size=12]" + \
				"[color=#569cd6][b] " + language.to_upper() + " [/b][/color]\n" + \
				highlighted_code + \
				"[/font_size][/color][/bgcolor]"

			formatted = formatted.replace(full_match, styled_code)

	# Format inline code with simplified styling
	var regex_inline_code = RegEx.new()
	if regex_inline_code.compile("`([^`]+)`") == OK:
		formatted = regex_inline_code.sub(formatted,
			"[color=#ce9178][code]$1[/code][/color]", true)

	# Enhanced text formatting with error handling
	formatted = _format_text_styles(formatted)
	formatted = _format_headers(formatted)
	formatted = _format_lists(formatted)
	formatted = _format_quotes(formatted)
	formatted = _format_links(formatted)

	return formatted

func _apply_syntax_highlighting(code: String, language: String) -> String:
	# Apply language-specific syntax highlighting
	match language.to_lower():
		"gdscript", "gd", _:
			return _highlight_gdscript(code)
		"python", "py":
			return _highlight_python(code)
		"javascript", "js":
			return _highlight_javascript(code)
		"json":
			return _highlight_json(code)

	return code

func _highlight_gdscript(code: String) -> String:
	var highlighted = code

	# GDScript keywords
	var keywords = ["func", "class", "extends", "var", "const", "signal", "enum",
					"if", "elif", "else", "for", "while", "match", "break", "continue",
					"return", "pass", "and", "or", "not", "in", "is", "as", "self",
					"true", "false", "null", "@tool", "@export", "@onready"]

	for keyword in keywords:
		var regex = RegEx.new()
		regex.compile("\\b" + keyword + "\\b")
		highlighted = regex.sub(highlighted, "[color=#569cd6]" + keyword + "[/color]", true)

	# Strings
	var string_regex = RegEx.new()
	string_regex.compile("\"([^\"\\\\]|\\\\.)*\"")
	highlighted = string_regex.sub(highlighted, "[color=#ce9178]$0[/color]", true)

	string_regex.compile("'([^'\\\\]|\\\\.)*'")
	highlighted = string_regex.sub(highlighted, "[color=#ce9178]$0[/color]", true)

	# Numbers
	var number_regex = RegEx.new()
	number_regex.compile("\\b\\d+(\\.\\d+)?\\b")
	highlighted = number_regex.sub(highlighted, "[color=#b5cea8]$0[/color]", true)

	# Comments
	var comment_regex = RegEx.new()
	comment_regex.compile("#.*$")
	highlighted = comment_regex.sub(highlighted, "[color=#6a9955]$0[/color]", true)

	# Function names
	var func_regex = RegEx.new()
	func_regex.compile("func\\s+(\\w+)")
	highlighted = func_regex.sub(highlighted, "func [color=#dcdcaa]$1[/color]", true)

	# Class names
	var class_regex = RegEx.new()
	class_regex.compile("class\\s+(\\w+)")
	highlighted = class_regex.sub(highlighted, "class [color=#4ec9b0]$1[/color]", true)

	return highlighted

func _highlight_python(code: String) -> String:
	var highlighted = code

	# Python keywords
	var keywords = ["def", "class", "import", "from", "if", "elif", "else", "for", "while",
					"try", "except", "finally", "with", "as", "return", "yield", "break",
					"continue", "pass", "and", "or", "not", "in", "is", "True", "False", "None"]

	for keyword in keywords:
		var regex = RegEx.new()
		regex.compile("\\b" + keyword + "\\b")
		highlighted = regex.sub(highlighted, "[color=#569cd6]" + keyword + "[/color]", true)

	# Strings
	var string_regex = RegEx.new()
	string_regex.compile("\"([^\"\\\\]|\\\\.)*\"")
	highlighted = string_regex.sub(highlighted, "[color=#ce9178]$0[/color]", true)

	# Comments
	var comment_regex = RegEx.new()
	comment_regex.compile("#.*$")
	highlighted = comment_regex.sub(highlighted, "[color=#6a9955]$0[/color]", true)

	return highlighted

func _highlight_javascript(code: String) -> String:
	var highlighted = code

	# JavaScript keywords
	var keywords = ["function", "var", "let", "const", "if", "else", "for", "while",
					"do", "switch", "case", "break", "continue", "return", "try", "catch",
					"finally", "throw", "new", "this", "true", "false", "null", "undefined"]

	for keyword in keywords:
		var regex = RegEx.new()
		regex.compile("\\b" + keyword + "\\b")
		highlighted = regex.sub(highlighted, "[color=#569cd6]" + keyword + "[/color]", true)

	# Strings
	var string_regex = RegEx.new()
	string_regex.compile("\"([^\"\\\\]|\\\\.)*\"")
	highlighted = string_regex.sub(highlighted, "[color=#ce9178]$0[/color]", true)

	# Comments
	var comment_regex = RegEx.new()
	comment_regex.compile("//.*$")
	highlighted = comment_regex.sub(highlighted, "[color=#6a9955]$0[/color]", true)

	return highlighted

func _highlight_json(code: String) -> String:
	var highlighted = code

	# JSON strings (keys and values)
	var string_regex = RegEx.new()
	string_regex.compile("\"([^\"\\\\]|\\\\.)*\"")
	highlighted = string_regex.sub(highlighted, "[color=#ce9178]$0[/color]", true)

	# JSON values
	var value_regex = RegEx.new()
	value_regex.compile("\\b(true|false|null)\\b")
	highlighted = value_regex.sub(highlighted, "[color=#569cd6]$0[/color]", true)

	# Numbers
	var number_regex = RegEx.new()
	number_regex.compile("\\b\\d+(\\.\\d+)?\\b")
	highlighted = number_regex.sub(highlighted, "[color=#b5cea8]$0[/color]", true)

	return highlighted

func _format_text_styles(text: String) -> String:
	var formatted = text

	# Bold text with enhanced styling
	var regex_bold = RegEx.new()
	if regex_bold.compile("\\*\\*([^*]+)\\*\\*") == OK:
		formatted = regex_bold.sub(formatted, "[b][color=#ffffff]$1[/color][/b]", true)

	# Italic text
	var regex_italic = RegEx.new()
	if regex_italic.compile("\\*([^*]+)\\*") == OK:
		formatted = regex_italic.sub(formatted, "[i][color=#d7ba7d]$1[/color][/i]", true)

	# Strikethrough
	var regex_strike = RegEx.new()
	if regex_strike.compile("~~([^~]+)~~") == OK:
		formatted = regex_strike.sub(formatted, "[s][color=#808080]$1[/color][/s]", true)

	return formatted

func _repeat_string(text: String, count: int) -> String:
	# Helper function to repeat a string (GDScript doesn't have string.repeat())
	var result = ""
	for i in range(count):
		result += text
	return result

func _format_headers(text: String) -> String:
	var formatted = text

	# Headers with simplified styling to prevent display issues
	var regex_h1 = RegEx.new()
	if regex_h1.compile("^# (.+)$") == OK:
		formatted = regex_h1.sub(formatted,
			"\n[font_size=18][b][color=#4fc1ff]$1[/color][/b][/font_size]\n", true)

	var regex_h2 = RegEx.new()
	if regex_h2.compile("^## (.+)$") == OK:
		formatted = regex_h2.sub(formatted,
			"\n[font_size=16][b][color=#9cdcfe]$1[/color][/b][/font_size]\n", true)

	var regex_h3 = RegEx.new()
	if regex_h3.compile("^### (.+)$") == OK:
		formatted = regex_h3.sub(formatted,
			"\n[font_size=14][b][color=#c586c0]$1[/color][/b][/font_size]\n", true)

	return formatted

func _format_lists(text: String) -> String:
	var formatted = text

	# Bullet points
	var regex_bullet = RegEx.new()
	if regex_bullet.compile("^- (.+)$") == OK:
		formatted = regex_bullet.sub(formatted, "[color=#569cd6]•[/color] $1", true)

	# Numbered lists
	var regex_numbered = RegEx.new()
	if regex_numbered.compile("^(\\d+)\\. (.+)$") == OK:
		formatted = regex_numbered.sub(formatted, "[color=#569cd6]$1.[/color] $2", true)

	return formatted

func _format_quotes(text: String) -> String:
	var formatted = text

	# Block quotes with simplified styling
	var regex_quote = RegEx.new()
	if regex_quote.compile("^> (.+)$") == OK:
		formatted = regex_quote.sub(formatted,
			"[color=#9cdcfe]> [/color][i][color=#d4d4d4]$1[/color][/i]", true)

	return formatted

func _format_links(text: String) -> String:
	var formatted = text

	# Markdown links [text](url)
	var regex_link = RegEx.new()
	if regex_link.compile("\\[([^\\]]+)\\]\\(([^\\)]+)\\)") == OK:
		formatted = regex_link.sub(formatted, "[color=#4fc1ff][u]$1[/u][/color]", true)

	# URLs
	var regex_url = RegEx.new()
	if regex_url.compile("https?://[^\\s]+") == OK:
		formatted = regex_url.sub(formatted, "[color=#4fc1ff][u]$0[/u][/color]", true)

	return formatted

# Code response detection and extraction moved to AIUtils class

func _on_apply_code():
	if current_generated_code.is_empty():
		return

	# Get the current script editor
	var script_editor = EditorInterface.get_script_editor()
	if script_editor:
		var current_editor = script_editor.get_current_editor()
		if current_editor:
			var text_editor = current_editor.get_base_editor()
			if text_editor:
				# Insert code at cursor position
				text_editor.insert_text_at_caret(current_generated_code)
				_add_to_chat("System", "Code applied to current script!", Color.YELLOW)
			else:
				_add_to_chat("Error", "No text editor found", Color.RED)
		else:
			_add_to_chat("Error", "No script editor open", Color.RED)
	else:
		_add_to_chat("Error", "Script editor not available", Color.RED)

func _on_explain_code():
	var selected_text = _get_selected_text()
	if selected_text.is_empty():
		_add_to_chat("System", "Please select some code to explain", Color.YELLOW)
		return

	_add_to_chat("You", "Explain this code: " + selected_text, Color.CYAN)
	send_button.disabled = true
	api_manager.explain_code(selected_text)

func _on_improve_code():
	var selected_text = _get_selected_text()
	if selected_text.is_empty():
		_add_to_chat("System", "Please select some code to improve", Color.YELLOW)
		return

	_add_to_chat("You", "Suggest improvements for: " + selected_text, Color.CYAN)
	send_button.disabled = true
	api_manager.suggest_improvements(selected_text)

func _get_selected_text() -> String:
	var script_editor = EditorInterface.get_script_editor()
	if script_editor:
		var current_editor = script_editor.get_current_editor()
		if current_editor:
			var text_editor = current_editor.get_base_editor()
			if text_editor:
				return text_editor.get_selected_text()
	return ""

func _on_help_pressed():
	if not setup_guide:
		var SetupGuide = load("res://addons/ai_coding_assistant/setup_guide.gd")
		if SetupGuide:
			setup_guide = SetupGuide.new()
			get_viewport().add_child(setup_guide)
		else:
			print("Failed to load setup guide script")
			return
	setup_guide.show_guide()

func _on_settings_pressed():
	if not settings_dialog:
		var AISettingsDialog = load("res://addons/ai_coding_assistant/settings_dialog.gd")
		if AISettingsDialog:
			settings_dialog = AISettingsDialog.new()
			settings_dialog.settings_changed.connect(_on_settings_changed)
			get_viewport().add_child(settings_dialog)
		else:
			print("Failed to load settings dialog script")
			return

	# Load current settings
	var current_settings = {
		"api_key": api_manager.api_key,
		"provider": api_manager.api_provider,
		"temperature": 0.7,
		"max_tokens": 2048,
		"auto_suggest": false,
		"save_history": true
	}
	settings_dialog.load_settings(current_settings)
	settings_dialog.popup_centered()

func _on_settings_changed(settings: Dictionary):
	api_manager.set_api_key(settings.get("api_key", ""))
	api_manager.set_provider(settings.get("provider", "gemini"))

	# Update UI to reflect changes
	var providers = ["gemini", "huggingface", "cohere", "openai", "anthropic", "groq", "ollama"]
	var provider_index = providers.find(settings.get("provider", "ollama"))  # Default to Ollama
	if provider_index >= 0:
		provider_option.selected = provider_index

	api_key_field.text = settings.get("api_key", "")

	# Save settings to file
	_save_settings(settings)

func _save_settings(settings: Dictionary):
	var config = ConfigFile.new()
	for key in settings:
		config.set_value("ai_assistant", key, settings[key])

	# Save provider-specific API keys securely
	_save_provider_api_keys(config)

	# Save UI state
	config.set_value("ui_state", "settings_collapsed", settings_collapsed)
	config.set_value("ui_state", "quick_actions_collapsed", quick_actions_collapsed)
	config.set_value("ui_state", "chat_word_wrap_enabled", chat_word_wrap_enabled)
	config.set_value("ui_state", "code_line_numbers_enabled", code_line_numbers_enabled)
	if main_splitter:
		config.set_value("ui_state", "splitter_offset", main_splitter.split_offset)

	config.save("user://ai_assistant_settings.cfg")

func _save_provider_api_keys(config: ConfigFile):
	"""Save API keys for all providers"""
	if openai_api_key_field and not openai_api_key_field.text.is_empty():
		config.set_value("api_keys", "openai", openai_api_key_field.text)
	if gemini_api_key_field and not gemini_api_key_field.text.is_empty():
		config.set_value("api_keys", "gemini", gemini_api_key_field.text)
	if anthropic_api_key_field and not anthropic_api_key_field.text.is_empty():
		config.set_value("api_keys", "anthropic", anthropic_api_key_field.text)
	if groq_api_key_field and not groq_api_key_field.text.is_empty():
		config.set_value("api_keys", "groq", groq_api_key_field.text)
	if ollama_url_field and not ollama_url_field.text.is_empty():
		config.set_value("api_keys", "ollama_url", ollama_url_field.text)

func _load_settings():
	var config = ConfigFile.new()
	var err = config.load("user://ai_assistant_settings.cfg")
	if err == OK:
		var api_key = config.get_value("ai_assistant", "api_key", "")
		var provider = config.get_value("ai_assistant", "provider", "ollama")  # Default to Ollama

		api_manager.set_api_key(api_key)
		api_manager.set_provider(provider)

		# Load provider-specific API keys
		_load_provider_api_keys(config)

		# Load UI state
		settings_collapsed = config.get_value("ui_state", "settings_collapsed", false)
		quick_actions_collapsed = config.get_value("ui_state", "quick_actions_collapsed", false)
		chat_word_wrap_enabled = config.get_value("ui_state", "chat_word_wrap_enabled", true)
		code_line_numbers_enabled = config.get_value("ui_state", "code_line_numbers_enabled", false)
		var splitter_offset = config.get_value("ui_state", "splitter_offset", 200)

		# Update UI
		if api_key_field:
			api_key_field.text = api_key
		var providers = ["gemini", "huggingface", "cohere", "openai", "anthropic", "groq", "ollama"]
		var provider_index = providers.find(provider)
		if provider_index >= 0 and provider_option:
			provider_option.selected = provider_index

		# Apply UI state after a frame to ensure UI is ready
		call_deferred("_apply_ui_state", splitter_offset)

func _load_provider_api_keys(config: ConfigFile):
	"""Load API keys for all providers"""
	if openai_api_key_field:
		openai_api_key_field.text = config.get_value("api_keys", "openai", "")
	if gemini_api_key_field:
		gemini_api_key_field.text = config.get_value("api_keys", "gemini", "")
	if anthropic_api_key_field:
		anthropic_api_key_field.text = config.get_value("api_keys", "anthropic", "")
	if groq_api_key_field:
		groq_api_key_field.text = config.get_value("api_keys", "groq", "")
	if ollama_url_field:
		ollama_url_field.text = config.get_value("api_keys", "ollama_url", "http://localhost:11434")

func _apply_ui_state(splitter_offset: int):
	if main_splitter:
		main_splitter.split_offset = splitter_offset
	_refresh_settings_section()
	_refresh_quick_actions_section()

	# Apply view preferences
	if chat_history:
		chat_history.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if chat_word_wrap_enabled else TextServer.AUTOWRAP_OFF
	if chat_word_wrap_button:
		chat_word_wrap_button.text = "↩" if chat_word_wrap_enabled else "→"
		chat_word_wrap_button.tooltip_text = "Word wrap: " + ("ON" if chat_word_wrap_enabled else "OFF")

	if code_output:
		code_output.gutters_draw_line_numbers = code_line_numbers_enabled  # Correct property name for Godot 4.x
	if code_line_numbers_button:
		code_line_numbers_button.text = "#" if code_line_numbers_enabled else "∅"
		code_line_numbers_button.tooltip_text = "Line numbers: " + ("ON" if code_line_numbers_enabled else "OFF")

	# Apply responsive design after UI state is loaded
	_apply_responsive_design()

# Keyboard shortcuts setup
func _setup_keyboard_shortcuts():
	# Enable input handling for the dock
	set_process_unhandled_key_input(true)

func _unhandled_key_input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		var key_event = event as InputEventKey

		# Ctrl+C - Copy (when code output has focus)
		if key_event.ctrl_pressed and key_event.keycode == KEY_C:
			if code_output.has_focus():
				_on_copy_code()
				get_viewport().set_input_as_handled()

		# Ctrl+S - Save code (when code output has focus)
		elif key_event.ctrl_pressed and key_event.keycode == KEY_S:
			if code_output.has_focus():
				_on_save_code()
				get_viewport().set_input_as_handled()

		# Ctrl+A - Select all (when code output has focus)
		elif key_event.ctrl_pressed and key_event.keycode == KEY_A:
			if code_output.has_focus():
				code_output.select_all()
				get_viewport().set_input_as_handled()

		# Ctrl+L - Clear chat
		elif key_event.ctrl_pressed and key_event.keycode == KEY_L:
			_on_clear_chat()
			get_viewport().set_input_as_handled()

		# F1 - Help
		elif key_event.keycode == KEY_F1:
			_on_help_pressed()
			get_viewport().set_input_as_handled()

		# Escape - Clear input field
		elif key_event.keycode == KEY_ESCAPE:
			if input_field.has_focus():
				input_field.clear()
				get_viewport().set_input_as_handled()

# AI Agent Signal Handlers
func _on_agent_error_detected(error_info: Dictionary):
	"""Handle error detected by the agent"""
	var message = "🤖 Agent detected error: " + error_info.get("message", "Unknown error")
	_add_chat_message(message, "agent")

	# If auto-fix is enabled, let the agent handle it
	if auto_error_fixer and auto_error_fixer.auto_fix_enabled:
		_add_chat_message("🔧 Agent is attempting to fix the error automatically...", "agent")

func _on_agent_warning_detected(warning_info: Dictionary):
	"""Handle warning detected by the agent"""
	var message = "⚠️ Agent detected warning: " + warning_info.get("message", "Unknown warning")
	_add_chat_message(message, "agent")

func _on_agent_command_executed(command: String, output: String, exit_code: int):
	"""Handle command executed by the agent"""
	var status = "✅" if exit_code == 0 else "❌"
	var message = status + " Agent executed: " + command
	if exit_code != 0:
		message += "\nOutput: " + output
	_add_chat_message(message, "agent")

func _on_agent_task_started(task: Dictionary):
	"""Handle task started by the agent"""
	var message = "🎯 Agent started task: " + task.get("description", "Unknown task")
	_add_chat_message(message, "agent")

func _on_agent_task_completed(task: Dictionary, result: Dictionary):
	"""Handle task completed by the agent"""
	var message = "✅ Agent completed task: " + task.get("description", "Unknown task")
	if result.has("details"):
		message += "\nResult: " + str(result["details"])
	_add_chat_message(message, "agent")

func _on_agent_goal_set(goal: Dictionary):
	"""Handle goal set by the agent"""
	var message = "🎯 Agent goal set: " + goal.get("description", "Unknown goal")
	_add_chat_message(message, "agent")

func _on_error_fix_started(error_info: Dictionary):
	"""Handle error fix started"""
	var message = "🔧 Auto-fixing error: " + error_info.get("message", "Unknown error")
	_add_chat_message(message, "agent")

func _on_error_fix_completed(error_info: Dictionary, fix_result: Dictionary):
	"""Handle error fix completed"""
	var success = fix_result.get("success", false)
	var status = "✅" if success else "❌"
	var message = status + " Error fix " + ("completed" if success else "failed")
	if fix_result.has("details"):
		message += ": " + str(fix_result["details"])
	_add_chat_message(message, "agent")

# Agent Control Methods
func enable_agent_mode():
	"""Enable autonomous agent mode"""
	if agent_brain:
		agent_brain.enable_auto_mode()
		_add_chat_message("🤖 AI Agent autonomous mode enabled", "system")

func disable_agent_mode():
	"""Disable autonomous agent mode"""
	if agent_brain:
		agent_brain.disable_auto_mode()
		_add_chat_message("🤖 AI Agent autonomous mode disabled", "system")

func set_agent_goal(goal_description: String):
	"""Set a goal for the agent"""
	if agent_brain:
		agent_brain.set_goal(goal_description)
		_add_chat_message("🎯 Agent goal set: " + goal_description, "system")

func get_agent_status() -> Dictionary:
	"""Get current agent status"""
	if agent_brain:
		return agent_brain.get_status()
	return {}

func start_terminal_monitoring():
	"""Start terminal monitoring"""
	if terminal_integration:
		terminal_integration.start_monitoring()
		_add_chat_message("📺 Terminal monitoring started", "system")

func stop_terminal_monitoring():
	"""Stop terminal monitoring"""
	if terminal_integration:
		terminal_integration.stop_monitoring()
		_add_chat_message("📺 Terminal monitoring stopped", "system")
