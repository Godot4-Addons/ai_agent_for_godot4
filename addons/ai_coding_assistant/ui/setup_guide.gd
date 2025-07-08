@tool
extends Window

# Setup guide window to help users configure the plugin

var step_label: Label
var instruction_text: RichTextLabel
var next_button: Button
var prev_button: Button
var close_button: Button

var current_step: int = 0
var setup_steps: Array = []

func _init():
	title = "AI Coding Assistant - Setup Guide"
	min_size = Vector2(600, 400)
	_setup_steps()
	_setup_ui()
	_update_step()

func _setup_steps():
	setup_steps = [
		{
			"title": "Welcome to AI Coding Assistant!",
			"content": """[b]Welcome![/b] This guide will help you set up the AI Coding Assistant plugin.

[b]What you'll get:[/b]
• Real-time AI chat for coding help
• Code generation and suggestions
• Code explanation and improvement tips
• Support for multiple AI providers

Click [b]Next[/b] to continue."""
		},
		{
			"title": "Step 1: Choose Your AI Provider",
			"content": """[b]Choose an AI Provider[/b]

We recommend starting with [b]Google Gemini[/b] (free and powerful):

[b]Google Gemini (Recommended):[/b]
• Free tier: 60 requests/minute, 1500/day
• Excellent for code generation and explanations
• Get API key: [url]https://makersuite.google.com/app/apikey[/url]

[b]Alternatives:[/b]
• [b]Hugging Face:[/b] Free inference API
• [b]Cohere:[/b] 100 free requests/month

Click the link above to get your API key, then come back here."""
		},
		{
			"title": "Step 2: Configure the Plugin",
			"content": """[b]Configure Your Settings[/b]

1. Look for the [b]"AI Assistant"[/b] dock on the left side of the editor
2. In the [b]API Settings[/b] section:
   • Select your provider (Gemini recommended)
   • Paste your API key
   • Settings are saved automatically

[b]Can't see the dock?[/b]
• Make sure the plugin is enabled in Project Settings > Plugins
• Restart Godot if necessary"""
		},
		{
			"title": "Step 3: Test Your Setup",
			"content": """[b]Test Your Configuration[/b]

Try these simple tests:

1. [b]Basic Chat:[/b]
   Type: "Hello, can you help me with GDScript?"

2. [b]Code Generation:[/b]
   Type: "Create a simple player movement script"

3. [b]Code Explanation:[/b]
   Open example_script.gd, select some code, click "Explain"

If you get responses, you're all set! 🎉"""
		},
		{
			"title": "Step 4: Tips for Best Results",
			"content": """[b]Pro Tips for Better AI Assistance[/b]

[b]Writing Good Prompts:[/b]
• Be specific: "Create a health system with regeneration"
• Mention Godot/GDScript explicitly
• Provide context about your project

[b]Example Prompts:[/b]
• "Generate a state machine for enemy AI in Godot"
• "How do I optimize this movement code? [paste code]"
• "Create a save/load system for player data"

[b]Features to Explore:[/b]
• Quick Action buttons for templates
• Diff viewer for code changes
• Real-time code suggestions (enable in settings)"""
		},
		{
			"title": "You're Ready to Go!",
			"content": """[b]Setup Complete! 🚀[/b]

You're now ready to use the AI Coding Assistant!

[b]Quick Start:[/b]
• Open the AI Assistant dock
• Start chatting with the AI
• Try the Quick Action buttons
• Experiment with code generation

[b]Need Help?[/b]
• Check the README.md for detailed documentation
• Report issues on GitHub
• Join our community discussions

[b]Happy Coding with AI![/b]

Close this window and start exploring the plugin."""
		}
	]

func _setup_ui():
	var vbox = VBoxContainer.new()
	add_child(vbox)

	# Header
	step_label = Label.new()
	step_label.add_theme_font_size_override("font_size", 18)
	step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(step_label)

	vbox.add_child(HSeparator.new())

	# Content
	instruction_text = RichTextLabel.new()
	instruction_text.bbcode_enabled = true
	instruction_text.fit_content = true
	instruction_text.custom_minimum_size = Vector2(0, 250)
	vbox.add_child(instruction_text)

	# Navigation buttons
	var button_hbox = HBoxContainer.new()
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	prev_button = Button.new()
	prev_button.text = "Previous"
	prev_button.pressed.connect(_on_prev_pressed)

	next_button = Button.new()
	next_button.text = "Next"
	next_button.pressed.connect(_on_next_pressed)

	close_button = Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(_on_close_pressed)

	button_hbox.add_child(prev_button)
	button_hbox.add_child(next_button)
	button_hbox.add_child(close_button)
	vbox.add_child(button_hbox)

func _update_step():
	if current_step < 0 or current_step >= setup_steps.size():
		return

	var step = setup_steps[current_step]
	step_label.text = step["title"]
	instruction_text.text = step["content"]

	# Update button states
	prev_button.disabled = current_step == 0
	next_button.disabled = current_step == setup_steps.size() - 1

	if current_step == setup_steps.size() - 1:
		next_button.text = "Finish"
	else:
		next_button.text = "Next"

func _on_prev_pressed():
	if current_step > 0:
		current_step -= 1
		_update_step()

func _on_next_pressed():
	if current_step < setup_steps.size() - 1:
		current_step += 1
		_update_step()
	else:
		# Finish setup
		hide()

func _on_close_pressed():
	hide()

func show_guide():
	current_step = 0
	_update_step()
	popup_centered()
