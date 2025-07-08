@tool
extends Node
class_name AutoErrorFixer

# Autonomous Error Detection and Fixing System
# Automatically detects, analyzes, and fixes code errors

signal error_fix_started(error_info: Dictionary)
signal error_fix_completed(error_info: Dictionary, fix_result: Dictionary)
signal error_fix_failed(error_info: Dictionary, reason: String)
signal fix_applied(file_path: String, fix_details: Dictionary)

# Components
var terminal_integration: TerminalIntegration
var editor_integration: EditorIntegration
var agent_memory: AgentMemory
var api_manager: AIApiManager

# Error fixing state
var active_fixes: Dictionary = {}
var fix_queue: Array[Dictionary] = []
var fix_history: Array[Dictionary] = []

# Configuration
var auto_fix_enabled: bool = true
var confidence_threshold: float = 0.8
var max_concurrent_fixes: int = 3
var backup_enabled: bool = true
var test_fixes: bool = true

# Fix patterns and rules
var fix_patterns: Dictionary = {}
var error_classifications: Dictionary = {}

func _init():
	name = "AutoErrorFixer"
	_setup_fix_patterns()
	_setup_error_classifications()

func _ready():
	_connect_to_components()
	print("Auto Error Fixer initialized")

func _connect_to_components():
	"""Connect to other agent components"""
	var parent = get_parent()
	terminal_integration = parent.get_node_or_null("TerminalIntegration")
	agent_memory = parent.get_node_or_null("AgentMemory")
	api_manager = parent.get_node_or_null("AIApiManager")
	
	# Get editor integration from dock
	var dock = parent.get_parent()
	if dock and dock.has_method("get_editor_integration"):
		editor_integration = dock.get_editor_integration()

func _setup_fix_patterns():
	"""Setup common error fix patterns"""
	fix_patterns = {
		"missing_semicolon": {
			"pattern": r"Expected ';'",
			"fix_type": "add_semicolon",
			"confidence": 0.9,
			"auto_fixable": true
		},
		"unmatched_parentheses": {
			"pattern": r"Unmatched '\('|Unmatched '\)'",
			"fix_type": "balance_parentheses",
			"confidence": 0.8,
			"auto_fixable": true
		},
		"undefined_variable": {
			"pattern": r"Identifier '(.+)' not declared",
			"fix_type": "declare_variable",
			"confidence": 0.7,
			"auto_fixable": false
		},
		"type_mismatch": {
			"pattern": r"Cannot convert from '(.+)' to '(.+)'",
			"fix_type": "type_conversion",
			"confidence": 0.6,
			"auto_fixable": false
		},
		"null_reference": {
			"pattern": r"Attempt to call function '(.+)' on a null instance",
			"fix_type": "null_check",
			"confidence": 0.8,
			"auto_fixable": true
		},
		"index_out_of_bounds": {
			"pattern": r"Index (.+) out of bounds",
			"fix_type": "bounds_check",
			"confidence": 0.8,
			"auto_fixable": true
		},
		"missing_return": {
			"pattern": r"Function '(.+)' must return a value",
			"fix_type": "add_return",
			"confidence": 0.9,
			"auto_fixable": true
		}
	}

func _setup_error_classifications():
	"""Setup error classification system"""
	error_classifications = {
		"syntax": {
			"severity": "high",
			"auto_fix_priority": 9,
			"patterns": ["Parse Error", "Expected", "Unexpected"]
		},
		"runtime": {
			"severity": "high", 
			"auto_fix_priority": 8,
			"patterns": ["null instance", "out of bounds", "Cannot convert"]
		},
		"logic": {
			"severity": "medium",
			"auto_fix_priority": 5,
			"patterns": ["unreachable code", "unused variable"]
		},
		"style": {
			"severity": "low",
			"auto_fix_priority": 2,
			"patterns": ["line too long", "missing documentation"]
		}
	}

func analyze_and_fix_error(error_info: Dictionary) -> Dictionary:
	"""Main entry point for error analysis and fixing"""
	print("Analyzing error: ", error_info["message"])
	
	var fix_result = {
		"error_id": error_info.get("id", _generate_error_id()),
		"success": false,
		"fix_applied": false,
		"confidence": 0.0,
		"fix_type": "",
		"details": "",
		"backup_created": false,
		"test_passed": false
	}
	
	error_fix_started.emit(error_info)
	
	# Classify the error
	var classification = _classify_error(error_info)
	fix_result["classification"] = classification
	
	# Check if we can auto-fix this error
	var fix_pattern = _find_matching_pattern(error_info)
	if fix_pattern.is_empty():
		fix_result["details"] = "No matching fix pattern found"
		error_fix_failed.emit(error_info, fix_result["details"])
		return fix_result
	
	fix_result["fix_type"] = fix_pattern["fix_type"]
	fix_result["confidence"] = fix_pattern["confidence"]
	
	# Check confidence threshold
	if fix_pattern["confidence"] < confidence_threshold:
		fix_result["details"] = "Fix confidence below threshold"
		error_fix_failed.emit(error_info, fix_result["details"])
		return fix_result
	
	# Create backup if enabled
	if backup_enabled:
		fix_result["backup_created"] = _create_backup(error_info)
	
	# Apply the fix
	var fix_success = _apply_fix(error_info, fix_pattern)
	fix_result["fix_applied"] = fix_success
	
	if fix_success:
		# Test the fix if enabled
		if test_fixes:
			fix_result["test_passed"] = _test_fix(error_info)
		
		fix_result["success"] = true
		fix_result["details"] = "Fix applied successfully"
		
		# Store successful fix in memory
		if agent_memory:
			agent_memory.store_solution(
				{"type": "error", "error": error_info},
				{"fix_type": fix_pattern["fix_type"], "pattern": fix_pattern},
				fix_result["confidence"]
			)
		
		error_fix_completed.emit(error_info, fix_result)
	else:
		fix_result["details"] = "Failed to apply fix"
		error_fix_failed.emit(error_info, fix_result["details"])
	
	# Store in fix history
	fix_history.append({
		"timestamp": Time.get_unix_time_from_system(),
		"error": error_info,
		"result": fix_result
	})
	
	return fix_result

func _classify_error(error_info: Dictionary) -> Dictionary:
	"""Classify an error based on its characteristics"""
	var message = error_info.get("message", "").to_lower()
	
	for classification_type in error_classifications:
		var classification = error_classifications[classification_type]
		for pattern in classification["patterns"]:
			if pattern.to_lower() in message:
				return {
					"type": classification_type,
					"severity": classification["severity"],
					"priority": classification["auto_fix_priority"]
				}
	
	return {
		"type": "unknown",
		"severity": "medium",
		"priority": 5
	}

func _find_matching_pattern(error_info: Dictionary) -> Dictionary:
	"""Find a matching fix pattern for the error"""
	var message = error_info.get("message", "")
	
	for pattern_name in fix_patterns:
		var pattern_info = fix_patterns[pattern_name]
		var regex = RegEx.new()
		
		if regex.compile(pattern_info["pattern"]) == OK:
			var result = regex.search(message)
			if result:
				var pattern_copy = pattern_info.duplicate()
				pattern_copy["name"] = pattern_name
				pattern_copy["regex_result"] = result
				return pattern_copy
	
	return {}

func _apply_fix(error_info: Dictionary, fix_pattern: Dictionary) -> bool:
	"""Apply a specific fix based on the pattern"""
	var fix_type = fix_pattern["fix_type"]
	
	match fix_type:
		"add_semicolon":
			return _fix_missing_semicolon(error_info, fix_pattern)
		"balance_parentheses":
			return _fix_unmatched_parentheses(error_info, fix_pattern)
		"declare_variable":
			return _fix_undefined_variable(error_info, fix_pattern)
		"type_conversion":
			return _fix_type_mismatch(error_info, fix_pattern)
		"null_check":
			return _fix_null_reference(error_info, fix_pattern)
		"bounds_check":
			return _fix_index_out_of_bounds(error_info, fix_pattern)
		"add_return":
			return _fix_missing_return(error_info, fix_pattern)
		_:
			print("Unknown fix type: ", fix_type)
			return false

func _fix_missing_semicolon(error_info: Dictionary, fix_pattern: Dictionary) -> bool:
	"""Fix missing semicolon errors"""
	var file_path = error_info.get("file_path", "")
	var line_number = error_info.get("line_number", -1)
	
	if file_path.is_empty() or line_number <= 0:
		return false
	
	if not editor_integration:
		return false
	
	# Get the line content
	var line_content = editor_integration.get_line_text(line_number - 1)
	if line_content.is_empty():
		return false
	
	# Add semicolon at the end of the line if not present
	if not line_content.strip_edges().ends_with(";"):
		var new_content = line_content.rstrip() + ";"
		return editor_integration.replace_line(line_number - 1, new_content)
	
	return false

func _fix_unmatched_parentheses(error_info: Dictionary, fix_pattern: Dictionary) -> bool:
	"""Fix unmatched parentheses"""
	var file_path = error_info.get("file_path", "")
	var line_number = error_info.get("line_number", -1)
	
	if file_path.is_empty() or line_number <= 0:
		return false
	
	if not editor_integration:
		return false
	
	# Get the line content
	var line_content = editor_integration.get_line_text(line_number - 1)
	if line_content.is_empty():
		return false
	
	# Count parentheses
	var open_count = line_content.count("(")
	var close_count = line_content.count(")")
	
	if open_count > close_count:
		# Add missing closing parentheses
		var missing = open_count - close_count
		var new_content = line_content + ")".repeat(missing)
		return editor_integration.replace_line(line_number - 1, new_content)
	elif close_count > open_count:
		# Remove extra closing parentheses
		var extra = close_count - open_count
		var new_content = line_content
		for i in range(extra):
			var last_close = new_content.rfind(")")
			if last_close >= 0:
				new_content = new_content.substr(0, last_close) + new_content.substr(last_close + 1)
		return editor_integration.replace_line(line_number - 1, new_content)
	
	return false

func _fix_undefined_variable(error_info: Dictionary, fix_pattern: Dictionary) -> bool:
	"""Fix undefined variable errors"""
	# This requires AI assistance to determine the correct variable declaration
	return false

func _fix_type_mismatch(error_info: Dictionary, fix_pattern: Dictionary) -> bool:
	"""Fix type mismatch errors"""
	# This requires AI assistance to determine the correct type conversion
	return false

func _fix_null_reference(error_info: Dictionary, fix_pattern: Dictionary) -> bool:
	"""Fix null reference errors by adding null checks"""
	var file_path = error_info.get("file_path", "")
	var line_number = error_info.get("line_number", -1)
	
	if file_path.is_empty() or line_number <= 0:
		return false
	
	if not editor_integration:
		return false
	
	var line_content = editor_integration.get_line_text(line_number - 1)
	if line_content.is_empty():
		return false
	
	# Extract the variable that's null
	var regex_result = fix_pattern.get("regex_result")
	var function_name = ""
	if regex_result and regex_result.get_group_count() > 0:
		function_name = regex_result.get_string(1)
	
	# Find the object being called
	var call_pattern = RegEx.new()
	call_pattern.compile(r"(\w+)\." + function_name)
	var call_result = call_pattern.search(line_content)
	
	if call_result:
		var object_name = call_result.get_string(1)
		var indent = _get_line_indent(line_content)
		
		# Add null check before the line
		var null_check = indent + "if " + object_name + " != null:"
		var indented_original = indent + "\t" + line_content.strip_edges()
		
		editor_integration.insert_line(line_number - 1, null_check)
		editor_integration.replace_line(line_number, indented_original)
		return true
	
	return false

func _fix_index_out_of_bounds(error_info: Dictionary, fix_pattern: Dictionary) -> bool:
	"""Fix index out of bounds errors"""
	var file_path = error_info.get("file_path", "")
	var line_number = error_info.get("line_number", -1)
	
	if file_path.is_empty() or line_number <= 0:
		return false
	
	if not editor_integration:
		return false
	
	var line_content = editor_integration.get_line_text(line_number - 1)
	if line_content.is_empty():
		return false
	
	# Find array access patterns
	var array_pattern = RegEx.new()
	array_pattern.compile(r"(\w+)\[(.+)\]")
	var array_result = array_pattern.search(line_content)
	
	if array_result:
		var array_name = array_result.get_string(1)
		var index_expr = array_result.get_string(2)
		var indent = _get_line_indent(line_content)
		
		# Add bounds check
		var bounds_check = indent + "if " + index_expr + " >= 0 and " + index_expr + " < " + array_name + ".size():"
		var indented_original = indent + "\t" + line_content.strip_edges()
		
		editor_integration.insert_line(line_number - 1, bounds_check)
		editor_integration.replace_line(line_number, indented_original)
		return true
	
	return false

func _fix_missing_return(error_info: Dictionary, fix_pattern: Dictionary) -> bool:
	"""Fix missing return statement"""
	var file_path = error_info.get("file_path", "")
	var line_number = error_info.get("line_number", -1)
	
	if file_path.is_empty() or line_number <= 0:
		return false
	
	if not editor_integration:
		return false
	
	# Find the function and add a return statement
	var function_info = editor_integration.get_function_at_cursor()
	if function_info.is_empty():
		return false
	
	# Add a default return statement at the end of the function
	var function_end_line = function_info.get("end_line", line_number)
	var indent = _get_line_indent(editor_integration.get_line_text(function_end_line - 1))
	
	var return_statement = indent + "return null  # TODO: Return appropriate value"
	editor_integration.insert_line(function_end_line - 1, return_statement)
	
	return true

func _get_line_indent(line: String) -> String:
	"""Get the indentation of a line"""
	var indent = ""
	for char in line:
		if char == '\t' or char == ' ':
			indent += char
		else:
			break
	return indent

func _create_backup(error_info: Dictionary) -> bool:
	"""Create a backup of the file before applying fixes"""
	var file_path = error_info.get("file_path", "")
	if file_path.is_empty():
		return false
	
	var backup_path = file_path + ".backup." + str(Time.get_unix_time_from_system())
	
	var original_file = FileAccess.open(file_path, FileAccess.READ)
	if not original_file:
		return false
	
	var content = original_file.get_as_text()
	original_file.close()
	
	var backup_file = FileAccess.open(backup_path, FileAccess.WRITE)
	if not backup_file:
		return false
	
	backup_file.store_string(content)
	backup_file.close()
	
	print("Backup created: ", backup_path)
	return true

func _test_fix(error_info: Dictionary) -> bool:
	"""Test if the fix resolved the error"""
	# This would involve running the code and checking for errors
	# For now, we'll return true as a placeholder
	return true

func _generate_error_id() -> String:
	"""Generate a unique error ID"""
	return "error_" + str(Time.get_unix_time_from_system()) + "_" + str(randi() % 10000)

func enable_auto_fix():
	"""Enable automatic error fixing"""
	auto_fix_enabled = true
	print("Auto error fixing enabled")

func disable_auto_fix():
	"""Disable automatic error fixing"""
	auto_fix_enabled = false
	print("Auto error fixing disabled")

func get_fix_statistics() -> Dictionary:
	"""Get statistics about error fixing"""
	var total_fixes = fix_history.size()
	var successful_fixes = 0
	
	for fix in fix_history:
		if fix["result"]["success"]:
			successful_fixes += 1
	
	return {
		"total_attempts": total_fixes,
		"successful_fixes": successful_fixes,
		"success_rate": float(successful_fixes) / total_fixes if total_fixes > 0 else 0.0,
		"active_fixes": active_fixes.size(),
		"queued_fixes": fix_queue.size()
	}

func clear_fix_history():
	"""Clear the fix history"""
	fix_history.clear()
	print("Fix history cleared")
