@tool
extends EditorScript

func _run():
	print("Testing AIOllama class loading...")
	
	var AIOllamaClass = load("res://addons/ai_coding_assistant/ai/ai_ollama.gd")
	if AIOllamaClass:
		print("✅ AIOllama class loaded successfully!")
		var instance = AIOllamaClass.new()
		if instance:
			print("✅ AIOllama instance created successfully!")
			print("Available methods: ", instance.get_method_list())
		else:
			print("❌ Failed to create AIOllama instance")
	else:
		print("❌ Failed to load AIOllama class")
