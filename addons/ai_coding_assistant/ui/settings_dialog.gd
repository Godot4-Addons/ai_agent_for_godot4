@tool
extends AcceptDialog

signal settings_changed(settings: Dictionary)

var api_key_input: LineEdit
var provider_option: OptionButton
var temperature_slider: HSlider
var max_tokens_input: SpinBox
var auto_suggest_check: CheckBox
var save_history_check: CheckBox

var current_settings: Dictionary = {
	"api_key": "",
	"provider": "gemini",
	"temperature": 0.7,
	"max_tokens": 2048,
	"auto_suggest": false,
	"save_history": true
}

func _init():
	title = "AI Assistant Settings"
	size = Vector2(400, 300)
	_setup_ui()

func _setup_ui():
	var vbox = VBoxContainer.new()
	add_child(vbox)

	# API Settings
	var api_group = VBoxContainer.new()
	var api_label = Label.new()
	api_label.text = "API Configuration"
	api_label.add_theme_font_size_override("font_size", 16)
	api_group.add_child(api_label)

	# Provider
	var provider_hbox = HBoxContainer.new()
	var provider_label = Label.new()
	provider_label.text = "Provider:"
	provider_label.custom_minimum_size = Vector2(100, 0)
	provider_option = OptionButton.new()
	provider_option.add_item("Google Gemini")
	provider_option.add_item("Hugging Face")
	provider_option.add_item("Cohere")
	provider_hbox.add_child(provider_label)
	provider_hbox.add_child(provider_option)
	api_group.add_child(provider_hbox)

	# API Key
	var key_hbox = HBoxContainer.new()
	var key_label = Label.new()
	key_label.text = "API Key:"
	key_label.custom_minimum_size = Vector2(100, 0)
	api_key_input = LineEdit.new()
	api_key_input.placeholder_text = "Enter your API key"
	api_key_input.secret = true
	key_hbox.add_child(key_label)
	key_hbox.add_child(api_key_input)
	api_group.add_child(key_hbox)

	vbox.add_child(api_group)
	vbox.add_child(HSeparator.new())

	# Generation Settings
	var gen_group = VBoxContainer.new()
	var gen_label = Label.new()
	gen_label.text = "Generation Settings"
	gen_label.add_theme_font_size_override("font_size", 16)
	gen_group.add_child(gen_label)

	# Temperature
	var temp_hbox = HBoxContainer.new()
	var temp_label = Label.new()
	temp_label.text = "Temperature:"
	temp_label.custom_minimum_size = Vector2(100, 0)
	temperature_slider = HSlider.new()
	temperature_slider.min_value = 0.0
	temperature_slider.max_value = 1.0
	temperature_slider.step = 0.1
	temperature_slider.value = 0.7
	var temp_value_label = Label.new()
	temp_value_label.text = "0.7"
	temperature_slider.value_changed.connect(_on_temperature_changed.bind(temp_value_label))
	temp_hbox.add_child(temp_label)
	temp_hbox.add_child(temperature_slider)
	temp_hbox.add_child(temp_value_label)
	gen_group.add_child(temp_hbox)

	# Max Tokens
	var tokens_hbox = HBoxContainer.new()
	var tokens_label = Label.new()
	tokens_label.text = "Max Tokens:"
	tokens_label.custom_minimum_size = Vector2(100, 0)
	max_tokens_input = SpinBox.new()
	max_tokens_input.min_value = 100
	max_tokens_input.max_value = 4096
	max_tokens_input.step = 100
	max_tokens_input.value = 2048
	tokens_hbox.add_child(tokens_label)
	tokens_hbox.add_child(max_tokens_input)
	gen_group.add_child(tokens_hbox)

	vbox.add_child(gen_group)
	vbox.add_child(HSeparator.new())

	# Feature Settings
	var feature_group = VBoxContainer.new()
	var feature_label = Label.new()
	feature_label.text = "Features"
	feature_label.add_theme_font_size_override("font_size", 16)
	feature_group.add_child(feature_label)

	auto_suggest_check = CheckBox.new()
	auto_suggest_check.text = "Enable auto-suggestions while typing"
	feature_group.add_child(auto_suggest_check)

	save_history_check = CheckBox.new()
	save_history_check.text = "Save chat history"
	save_history_check.button_pressed = true
	feature_group.add_child(save_history_check)

	vbox.add_child(feature_group)

	# Buttons
	var button_hbox = HBoxContainer.new()
	var save_button = Button.new()
	save_button.text = "Save"
	save_button.pressed.connect(_on_save_pressed)
	var cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.pressed.connect(_on_cancel_pressed)
	button_hbox.add_child(save_button)
	button_hbox.add_child(cancel_button)
	vbox.add_child(button_hbox)

func load_settings(settings: Dictionary):
	current_settings = settings

	if "api_key" in settings:
		api_key_input.text = settings["api_key"]
	if "provider" in settings:
		var providers = ["gemini", "huggingface", "cohere"]
		var index = providers.find(settings["provider"])
		if index >= 0:
			provider_option.selected = index
	if "temperature" in settings:
		temperature_slider.value = settings["temperature"]
	if "max_tokens" in settings:
		max_tokens_input.value = settings["max_tokens"]
	if "auto_suggest" in settings:
		auto_suggest_check.button_pressed = settings["auto_suggest"]
	if "save_history" in settings:
		save_history_check.button_pressed = settings["save_history"]

func _on_save_pressed():
	var providers = ["gemini", "huggingface", "cohere"]
	current_settings = {
		"api_key": api_key_input.text,
		"provider": providers[provider_option.selected],
		"temperature": temperature_slider.value,
		"max_tokens": int(max_tokens_input.value),
		"auto_suggest": auto_suggest_check.button_pressed,
		"save_history": save_history_check.button_pressed
	}

	settings_changed.emit(current_settings)
	hide()

func _on_cancel_pressed():
	hide()

func _on_temperature_changed(value, label):
	label.text = str(value)
