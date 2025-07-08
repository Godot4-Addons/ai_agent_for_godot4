@tool
extends RefCounted

# Utility functions for AI operations

static func format_code_for_ai(code: String, language: String = "gdscript") -> String:
	"""Format code with proper context for AI processing"""
	var formatted = "```" + language + "\n"
	formatted += code.strip_edges()
	formatted += "\n```"
	return formatted

static func extract_code_from_response(response: String) -> String:
	"""Extract code blocks from AI response"""
	var code_pattern = RegEx.new()
	code_pattern.compile("```(?:gdscript|gd)?\\s*\\n([\\s\\S]*?)\\n```")
	
	var result = code_pattern.search(response)
	if result:
		return result.get_string(1).strip_edges()
	
	# Fallback: look for code-like content
	var lines = response.split("\n")
	var code_lines = []
	var in_code_block = false
	
	for line in lines:
		if line.strip_edges().begins_with("extends ") or \
		   line.strip_edges().begins_with("func ") or \
		   line.strip_edges().begins_with("var ") or \
		   line.strip_edges().begins_with("class "):
			in_code_block = true
		
		if in_code_block:
			code_lines.append(line)
			
		# Stop if we hit explanatory text
		if in_code_block and (line.strip_edges().begins_with("This ") or \
		   line.strip_edges().begins_with("The ") or \
		   line.strip_edges().begins_with("Here")):
			break
	
	return "\n".join(code_lines).strip_edges()

static func is_code_response(response: String) -> bool:
	"""Check if response contains code"""
	var code_indicators = [
		"```",
		"extends ",
		"func ",
		"var ",
		"class ",
		"@export",
		"signal ",
		"enum "
	]
	
	var lower_response = response.to_lower()
	for indicator in code_indicators:
		if indicator.to_lower() in lower_response:
			return true
	
	return false

static func clean_ai_response(response: String) -> String:
	"""Clean up AI response for better display"""
	var cleaned = response.strip_edges()
	
	# Remove common AI prefixes
	var prefixes_to_remove = [
		"Here's ",
		"Here is ",
		"I'll help you ",
		"I can help you ",
		"Sure! ",
		"Certainly! "
	]
	
	for prefix in prefixes_to_remove:
		if cleaned.begins_with(prefix):
			cleaned = cleaned.substr(prefix.length())
			break
	
	return cleaned

static func generate_context_prompt(context: Dictionary) -> String:
	"""Generate context information for AI prompts"""
	var prompt = "Context information:\n"
	
	if context.has("file_path") and context["file_path"] != "":
		prompt += "- File: " + context["file_path"] + "\n"
	
	if context.has("class_name") and context["class_name"] != "":
		prompt += "- Class: " + context["class_name"] + "\n"
	
	if context.has("current_function") and context["current_function"] != "":
		prompt += "- Current function: " + context["current_function"] + "\n"
	
	if context.has("extends") and context["extends"] != "":
		prompt += "- Extends: " + context["extends"] + "\n"
	
	if context.has("variables") and context["variables"].size() > 0:
		prompt += "- Variables: "
		var var_names = []
		for var_info in context["variables"]:
			if var_info.has("name"):
				var_names.append(var_info["name"])
		prompt += ", ".join(var_names) + "\n"
	
	if context.has("functions") and context["functions"].size() > 0:
		prompt += "- Functions: " + ", ".join(context["functions"]) + "\n"
	
	prompt += "\n"
	return prompt

static func validate_gdscript_syntax(code: String) -> Dictionary:
	"""Basic GDScript syntax validation"""
	var result = {
		"valid": true,
		"errors": [],
		"warnings": []
	}
	
	var lines = code.split("\n")
	var indent_level = 0
	var in_function = false
	
	for i in range(lines.size()):
		var line = lines[i]
		var trimmed = line.strip_edges()
		
		if trimmed.is_empty() or trimmed.begins_with("#"):
			continue
		
		# Check indentation
		var line_indent = 0
		for char in line:
			if char == "\t":
				line_indent += 1
			elif char == " ":
				line_indent += 0.25  # Approximate tab equivalent
			else:
				break
		
		# Basic syntax checks
		if trimmed.begins_with("func "):
			in_function = true
			if not trimmed.ends_with(":"):
				result["errors"].append("Line " + str(i + 1) + ": Function declaration missing colon")
				result["valid"] = false
		
		if trimmed.begins_with("if ") or trimmed.begins_with("elif ") or \
		   trimmed.begins_with("else") or trimmed.begins_with("for ") or \
		   trimmed.begins_with("while "):
			if not trimmed.ends_with(":"):
				result["errors"].append("Line " + str(i + 1) + ": Control statement missing colon")
				result["valid"] = false
		
		# Check for common mistakes
		if "=" in trimmed and not ("==" in trimmed or "!=" in trimmed or ">=" in trimmed or "<=" in trimmed):
			if trimmed.begins_with("if ") or trimmed.begins_with("elif "):
				result["warnings"].append("Line " + str(i + 1) + ": Possible assignment in condition (use == for comparison)")
	
	return result

static func suggest_improvements(code: String) -> Array[String]:
	"""Suggest code improvements"""
	var suggestions = []
	var lines = code.split("\n")
	
	for i in range(lines.size()):
		var line = lines[i].strip_edges()
		
		# Check for magic numbers
		var number_regex = RegEx.new()
		number_regex.compile("\\b\\d+\\b")
		var matches = number_regex.search_all(line)
		if matches.size() > 0 and not line.begins_with("var ") and not line.begins_with("const "):
			suggestions.append("Consider using named constants instead of magic numbers on line " + str(i + 1))
		
		# Check for long lines
		if line.length() > 100:
			suggestions.append("Line " + str(i + 1) + " is quite long, consider breaking it up")
		
		# Check for TODO comments
		if "TODO" in line.to_upper() or "FIXME" in line.to_upper():
			suggestions.append("Don't forget about the TODO/FIXME on line " + str(i + 1))
	
	return suggestions

static func format_error_message(error: String, context: String = "") -> String:
	"""Format error messages for better readability"""
	var formatted = "❌ Error: " + error
	if context != "":
		formatted += "\n📍 Context: " + context
	return formatted

static func format_success_message(message: String) -> String:
	"""Format success messages"""
	return "✅ " + message

static func format_warning_message(message: String) -> String:
	"""Format warning messages"""
	return "⚠️ " + message

static func get_file_extension(file_path: String) -> String:
	"""Get file extension from path"""
	var parts = file_path.split(".")
	if parts.size() > 1:
		return parts[-1].to_lower()
	return ""

static func is_gdscript_file(file_path: String) -> bool:
	"""Check if file is a GDScript file"""
	var ext = get_file_extension(file_path)
	return ext == "gd" or ext == "gdscript"

static func truncate_text(text: String, max_length: int = 100) -> String:
	"""Truncate text with ellipsis"""
	if text.length() <= max_length:
		return text
	return text.substr(0, max_length - 3) + "..."
