@tool
extends Node
class_name AgentMemory

# Agent Memory System
# Stores and manages agent's knowledge, experiences, and context

signal memory_updated(category: String, data: Dictionary)
signal pattern_learned(pattern: Dictionary)

# Memory categories
var errors_memory: Array[Dictionary] = []
var warnings_memory: Array[Dictionary] = []
var commands_memory: Array[Dictionary] = []
var code_patterns: Array[Dictionary] = []
var solutions_memory: Array[Dictionary] = []
var project_context: Dictionary = {}
var user_preferences: Dictionary = {}
var learned_patterns: Array[Dictionary] = []

# Memory limits
var max_errors_memory: int = 1000
var max_warnings_memory: int = 500
var max_commands_memory: int = 2000
var max_patterns_memory: int = 100
var max_solutions_memory: int = 500

# Learning configuration
var learning_enabled: bool = true
var pattern_recognition_threshold: float = 0.7
var memory_persistence_enabled: bool = true

# File paths for persistence
var memory_file_path: String = "user://agent_memory.dat"
var patterns_file_path: String = "user://learned_patterns.dat"

func _init():
	name = "AgentMemory"

func _ready():
	if memory_persistence_enabled:
		load_memory_from_disk()
	print("Agent Memory initialized")

func store_error(error_info: Dictionary):
	"""Store error information in memory"""
	var memory_entry = {
		"timestamp": Time.get_unix_time_from_system(),
		"error": error_info,
		"context": _get_current_context(),
		"resolved": false,
		"solution": {}
	}
	
	errors_memory.append(memory_entry)
	_trim_memory_category(errors_memory, max_errors_memory)
	
	# Learn from error patterns
	if learning_enabled:
		_analyze_error_patterns(error_info)
	
	memory_updated.emit("errors", memory_entry)

func store_warning(warning_info: Dictionary):
	"""Store warning information in memory"""
	var memory_entry = {
		"timestamp": Time.get_unix_time_from_system(),
		"warning": warning_info,
		"context": _get_current_context(),
		"addressed": false
	}
	
	warnings_memory.append(memory_entry)
	_trim_memory_category(warnings_memory, max_warnings_memory)
	
	memory_updated.emit("warnings", memory_entry)

func store_command_execution(execution_info: Dictionary):
	"""Store command execution information"""
	var memory_entry = {
		"timestamp": Time.get_unix_time_from_system(),
		"execution": execution_info,
		"context": _get_current_context(),
		"success": execution_info["exit_code"] == 0
	}
	
	commands_memory.append(memory_entry)
	_trim_memory_category(commands_memory, max_commands_memory)
	
	# Learn from command patterns
	if learning_enabled:
		_analyze_command_patterns(execution_info)
	
	memory_updated.emit("commands", memory_entry)

func store_solution(problem: Dictionary, solution: Dictionary, effectiveness: float):
	"""Store a solution for future reference"""
	var memory_entry = {
		"timestamp": Time.get_unix_time_from_system(),
		"problem": problem,
		"solution": solution,
		"effectiveness": effectiveness,
		"usage_count": 1,
		"context": _get_current_context()
	}
	
	solutions_memory.append(memory_entry)
	_trim_memory_category(solutions_memory, max_solutions_memory)
	
	memory_updated.emit("solutions", memory_entry)

func store_code_pattern(pattern: Dictionary):
	"""Store a recognized code pattern"""
	var memory_entry = {
		"timestamp": Time.get_unix_time_from_system(),
		"pattern": pattern,
		"frequency": 1,
		"context": _get_current_context()
	}
	
	code_patterns.append(memory_entry)
	_trim_memory_category(code_patterns, max_patterns_memory)
	
	memory_updated.emit("patterns", memory_entry)

func update_project_context(context: Dictionary):
	"""Update the current project context"""
	project_context.merge(context, true)
	memory_updated.emit("project_context", project_context)

func get_similar_errors(error_info: Dictionary, limit: int = 5) -> Array[Dictionary]:
	"""Find similar errors from memory"""
	var similar_errors = []
	var error_message = error_info.get("message", "").to_lower()
	
	for memory_entry in errors_memory:
		var stored_error = memory_entry["error"]
		var stored_message = stored_error.get("message", "").to_lower()
		
		var similarity = _calculate_text_similarity(error_message, stored_message)
		if similarity > 0.5:  # 50% similarity threshold
			memory_entry["similarity"] = similarity
			similar_errors.append(memory_entry)
	
	# Sort by similarity (highest first)
	similar_errors.sort_custom(func(a, b): return a["similarity"] > b["similarity"])
	
	return similar_errors.slice(0, limit)

func get_successful_solutions(problem_type: String, limit: int = 3) -> Array[Dictionary]:
	"""Get successful solutions for a problem type"""
	var successful_solutions = []
	
	for memory_entry in solutions_memory:
		var problem = memory_entry["problem"]
		if problem.get("type", "") == problem_type and memory_entry["effectiveness"] > 0.7:
			successful_solutions.append(memory_entry)
	
	# Sort by effectiveness (highest first)
	successful_solutions.sort_custom(func(a, b): return a["effectiveness"] > b["effectiveness"])
	
	return successful_solutions.slice(0, limit)

func get_command_history(command_pattern: String = "", limit: int = 10) -> Array[Dictionary]:
	"""Get command execution history"""
	var filtered_commands = []
	
	for memory_entry in commands_memory:
		var command = memory_entry["execution"]["command"]
		if command_pattern.is_empty() or command_pattern in command:
			filtered_commands.append(memory_entry)
	
	# Sort by timestamp (most recent first)
	filtered_commands.sort_custom(func(a, b): return a["timestamp"] > b["timestamp"])
	
	return filtered_commands.slice(0, limit)

func mark_error_resolved(error_id: String, solution: Dictionary):
	"""Mark an error as resolved with its solution"""
	for memory_entry in errors_memory:
		var error = memory_entry["error"]
		if error.get("id", "") == error_id:
			memory_entry["resolved"] = true
			memory_entry["solution"] = solution
			memory_entry["resolved_at"] = Time.get_unix_time_from_system()
			break

func _get_current_context() -> Dictionary:
	"""Get current context information"""
	return {
		"timestamp": Time.get_unix_time_from_system(),
		"project": project_context.get("project_name", ""),
		"current_file": project_context.get("current_file", ""),
		"current_function": project_context.get("current_function", ""),
		"editor_state": project_context.get("editor_state", {})
	}

func _trim_memory_category(memory_array: Array, max_size: int):
	"""Trim memory array to maximum size"""
	while memory_array.size() > max_size:
		memory_array.remove_at(0)  # Remove oldest entries

func _analyze_error_patterns(error_info: Dictionary):
	"""Analyze error patterns for learning"""
	var error_type = error_info.get("type", "unknown")
	var error_message = error_info.get("message", "")
	
	# Look for recurring patterns
	var similar_count = 0
	for memory_entry in errors_memory:
		var stored_error = memory_entry["error"]
		if stored_error.get("type", "") == error_type:
			similar_count += 1
	
	# If we see this error type frequently, create a pattern
	if similar_count >= 3:
		var pattern = {
			"type": "error_pattern",
			"error_type": error_type,
			"frequency": similar_count,
			"common_causes": _extract_common_causes(error_type),
			"suggested_solutions": _extract_common_solutions(error_type)
		}
		
		_store_learned_pattern(pattern)

func _analyze_command_patterns(execution_info: Dictionary):
	"""Analyze command execution patterns"""
	var command = execution_info["command"]
	var success = execution_info["exit_code"] == 0
	
	# Track command success rates
	var command_base = command.split(" ")[0] if " " in command else command
	var pattern_found = false
	
	for pattern in learned_patterns:
		if pattern.get("type") == "command_pattern" and pattern.get("command_base") == command_base:
			pattern["total_executions"] += 1
			if success:
				pattern["successful_executions"] += 1
			pattern["success_rate"] = float(pattern["successful_executions"]) / pattern["total_executions"]
			pattern_found = true
			break
	
	if not pattern_found:
		var pattern = {
			"type": "command_pattern",
			"command_base": command_base,
			"total_executions": 1,
			"successful_executions": 1 if success else 0,
			"success_rate": 1.0 if success else 0.0,
			"first_seen": Time.get_unix_time_from_system()
		}
		_store_learned_pattern(pattern)

func _store_learned_pattern(pattern: Dictionary):
	"""Store a learned pattern"""
	learned_patterns.append(pattern)
	pattern_learned.emit(pattern)
	
	# Persist to disk if enabled
	if memory_persistence_enabled:
		save_patterns_to_disk()

func _extract_common_causes(error_type: String) -> Array[String]:
	"""Extract common causes for an error type"""
	var causes = []
	
	match error_type:
		"parse_error":
			causes = ["Missing semicolon", "Unmatched brackets", "Invalid syntax"]
		"runtime_error":
			causes = ["Null reference", "Index out of bounds", "Type mismatch"]
		"compilation_error":
			causes = ["Missing dependencies", "Invalid function call", "Type errors"]
	
	return causes

func _extract_common_solutions(error_type: String) -> Array[String]:
	"""Extract common solutions for an error type"""
	var solutions = []
	
	match error_type:
		"parse_error":
			solutions = ["Check syntax", "Validate brackets", "Review line structure"]
		"runtime_error":
			solutions = ["Add null checks", "Validate array bounds", "Check variable types"]
		"compilation_error":
			solutions = ["Check imports", "Verify function signatures", "Review type declarations"]
	
	return solutions

func _calculate_text_similarity(text1: String, text2: String) -> float:
	"""Calculate similarity between two text strings"""
	if text1.is_empty() or text2.is_empty():
		return 0.0
	
	# Simple word-based similarity
	var words1 = text1.split(" ")
	var words2 = text2.split(" ")
	var common_words = 0
	
	for word in words1:
		if word in words2:
			common_words += 1
	
	var total_words = max(words1.size(), words2.size())
	return float(common_words) / total_words if total_words > 0 else 0.0

func save_memory_to_disk():
	"""Save memory to disk for persistence"""
	var memory_data = {
		"errors": errors_memory,
		"warnings": warnings_memory,
		"commands": commands_memory,
		"solutions": solutions_memory,
		"project_context": project_context,
		"user_preferences": user_preferences,
		"version": "1.0"
	}
	
	var file = FileAccess.open(memory_file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(memory_data))
		file.close()
		print("Memory saved to disk")

func load_memory_from_disk():
	"""Load memory from disk"""
	if not FileAccess.file_exists(memory_file_path):
		return
	
	var file = FileAccess.open(memory_file_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			var memory_data = json.data
			errors_memory = memory_data.get("errors", [])
			warnings_memory = memory_data.get("warnings", [])
			commands_memory = memory_data.get("commands", [])
			solutions_memory = memory_data.get("solutions", [])
			project_context = memory_data.get("project_context", {})
			user_preferences = memory_data.get("user_preferences", {})
			print("Memory loaded from disk")

func save_patterns_to_disk():
	"""Save learned patterns to disk"""
	var file = FileAccess.open(patterns_file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(learned_patterns))
		file.close()

func load_patterns_from_disk():
	"""Load learned patterns from disk"""
	if not FileAccess.file_exists(patterns_file_path):
		return
	
	var file = FileAccess.open(patterns_file_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			learned_patterns = json.data

func clear_memory_category(category: String):
	"""Clear a specific memory category"""
	match category:
		"errors":
			errors_memory.clear()
		"warnings":
			warnings_memory.clear()
		"commands":
			commands_memory.clear()
		"solutions":
			solutions_memory.clear()
		"patterns":
			code_patterns.clear()
		"learned_patterns":
			learned_patterns.clear()

func get_memory_stats() -> Dictionary:
	"""Get memory usage statistics"""
	return {
		"errors": errors_memory.size(),
		"warnings": warnings_memory.size(),
		"commands": commands_memory.size(),
		"solutions": solutions_memory.size(),
		"patterns": code_patterns.size(),
		"learned_patterns": learned_patterns.size(),
		"total_entries": errors_memory.size() + warnings_memory.size() + commands_memory.size() + solutions_memory.size()
	}
