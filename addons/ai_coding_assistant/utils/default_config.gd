@tool
extends RefCounted

# Default configuration for AI Coding Assistant

static func get_default_settings() -> Dictionary:
	return {
		"api_key": "",
		"provider": "gemini",
		"temperature": 0.7,
		"max_tokens": 2048,
		"auto_suggest": false,
		"save_history": true,
		"show_setup_guide": true,
		"enable_code_analysis": true,
		"enable_syntax_highlighting": true,
		"auto_format_code": true,
		"show_line_numbers": false,
		"word_wrap_chat": true,
		"chat_font_size": 12,
		"code_font_size": 12,
		"theme": "default"
	}

static func get_default_ui_state() -> Dictionary:
	return {
		"settings_collapsed": false,
		"quick_actions_collapsed": false,
		"chat_word_wrap_enabled": true,
		"code_line_numbers_enabled": false,
		"splitter_offset": 200,
		"dock_size": Vector2(250, 300),
		"window_position": Vector2(100, 100)
	}

static func get_provider_configs() -> Dictionary:
	return {
		"gemini": {
			"name": "Google Gemini",
			"base_url": "https://generativelanguage.googleapis.com/v1beta/models/",
			"models": [
				"gemini-1.5-flash",
				"gemini-1.5-pro",
				"gemini-pro"
			],
			"default_model": "gemini-1.5-flash",
			"supports_streaming": false,
			"max_tokens": 8192,
			"rate_limit": {
				"requests_per_minute": 60,
				"requests_per_day": 1500
			},
			"api_key_url": "https://makersuite.google.com/app/apikey",
			"documentation": "https://ai.google.dev/docs"
		},
		"huggingface": {
			"name": "Hugging Face",
			"base_url": "https://api-inference.huggingface.co/models/",
			"models": [
				"microsoft/DialoGPT-medium",
				"microsoft/CodeBERT-base",
				"codeparrot/codeparrot-small"
			],
			"default_model": "microsoft/DialoGPT-medium",
			"supports_streaming": false,
			"max_tokens": 1024,
			"rate_limit": {
				"requests_per_minute": 30,
				"requests_per_day": 1000
			},
			"api_key_url": "https://huggingface.co/settings/tokens",
			"documentation": "https://huggingface.co/docs/api-inference"
		},
		"cohere": {
			"name": "Cohere",
			"base_url": "https://api.cohere.ai/v1/",
			"models": [
				"command",
				"command-light",
				"command-nightly"
			],
			"default_model": "command",
			"supports_streaming": true,
			"max_tokens": 4096,
			"rate_limit": {
				"requests_per_minute": 20,
				"requests_per_day": 100
			},
			"api_key_url": "https://dashboard.cohere.ai/api-keys",
			"documentation": "https://docs.cohere.ai/"
		}
	}

static func get_quick_actions() -> Array[Dictionary]:
	return [
		{
			"name": "Player Movement",
			"description": "Generate 2D player movement script",
			"prompt": "Create a 2D player movement script for Godot with WASD controls, jumping, and physics",
			"icon": "🏃",
			"category": "gameplay"
		},
		{
			"name": "UI Controller",
			"description": "Generate UI management script",
			"prompt": "Create a UI controller script for managing menus and UI interactions in Godot",
			"icon": "🖥️",
			"category": "ui"
		},
		{
			"name": "Save System",
			"description": "Generate save/load functionality",
			"prompt": "Create a save and load system for Godot using JSON files",
			"icon": "💾",
			"category": "system"
		},
		{
			"name": "Audio Manager",
			"description": "Generate audio management script",
			"prompt": "Create an audio manager for Godot with music and sound effects control",
			"icon": "🔊",
			"category": "system"
		},
		{
			"name": "State Machine",
			"description": "Generate state machine implementation",
			"prompt": "Create a generic state machine implementation for Godot",
			"icon": "⚙️",
			"category": "system"
		},
		{
			"name": "Inventory System",
			"description": "Generate inventory management",
			"prompt": "Create an inventory system for items in Godot",
			"icon": "🎒",
			"category": "gameplay"
		}
	]

static func get_code_snippets() -> Dictionary:
	return {
		"signal_declaration": "signal signal_name(parameter: Type)",
		"export_variable": "@export var variable_name: Type = default_value",
		"onready_variable": "@onready var node_ref: Node = $NodePath",
		"function_declaration": "func function_name(parameter: Type) -> ReturnType:",
		"if_statement": "if condition:\n\t# code here",
		"for_loop": "for item in array:\n\t# code here",
		"while_loop": "while condition:\n\t# code here",
		"match_statement": "match variable:\n\tvalue1:\n\t\t# code\n\tvalue2:\n\t\t# code\n\t_:\n\t\t# default",
		"class_declaration": "class_name ClassName\nextends BaseClass",
		"enum_declaration": "enum EnumName {\n\tVALUE1,\n\tVALUE2,\n\tVALUE3\n}"
	}

static func get_common_prompts() -> Array[String]:
	return [
		"Explain this code",
		"Optimize this function",
		"Add error handling",
		"Convert to Godot 4 syntax",
		"Add documentation comments",
		"Refactor for better readability",
		"Add type hints",
		"Create unit tests",
		"Fix potential bugs",
		"Improve performance"
	]

static func get_file_templates() -> Dictionary:
	return {
		"scene_script": {
			"extension": ".gd",
			"template": "extends Node\n\n# Scene script for {scene_name}\n\nfunc _ready():\n\t# Initialize scene\n\tpass\n"
		},
		"singleton_script": {
			"extension": ".gd", 
			"template": "extends Node\n\n# Singleton: {singleton_name}\n# Add to Project Settings > Autoload\n\nfunc _ready():\n\t# Initialize singleton\n\tpass\n"
		},
		"custom_resource": {
			"extension": ".gd",
			"template": "extends Resource\n\nclass_name {resource_name}\n\n# Custom resource for {description}\n\n@export var property_name: Type\n"
		}
	}

static func get_keyboard_shortcuts() -> Dictionary:
	return {
		"send_message": "Enter",
		"new_line_in_input": "Shift+Enter", 
		"clear_chat": "Ctrl+L",
		"copy_code": "Ctrl+C",
		"apply_code": "Ctrl+Enter",
		"toggle_settings": "Ctrl+,",
		"focus_input": "Ctrl+I",
		"explain_selection": "Ctrl+E",
		"improve_selection": "Ctrl+R"
	}

static func validate_config(config: Dictionary) -> Dictionary:
	"""Validate and fix configuration"""
	var default_config = get_default_settings()
	var validated_config = {}
	
	# Ensure all required keys exist with proper types
	for key in default_config:
		if config.has(key):
			validated_config[key] = config[key]
		else:
			validated_config[key] = default_config[key]
	
	# Validate specific values
	if validated_config["temperature"] < 0.0 or validated_config["temperature"] > 1.0:
		validated_config["temperature"] = 0.7
	
	if validated_config["max_tokens"] < 100 or validated_config["max_tokens"] > 8192:
		validated_config["max_tokens"] = 2048
	
	var valid_providers = get_provider_configs().keys()
	if not validated_config["provider"] in valid_providers:
		validated_config["provider"] = "gemini"
	
	return validated_config
