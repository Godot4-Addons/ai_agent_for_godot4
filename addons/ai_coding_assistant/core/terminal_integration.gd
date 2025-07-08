@tool
extends Node
class_name TerminalIntegration

# Terminal Integration Module for AI Agent
# Provides real-time terminal monitoring, command execution, and error detection

signal command_executed(command: String, output: String, exit_code: int)
signal error_detected(error_info: Dictionary)
signal warning_detected(warning_info: Dictionary)
signal output_received(output: String)

# Terminal state
var is_monitoring: bool = false
var current_process: int = -1
var output_buffer: String = ""
var error_patterns: Array[RegEx] = []
var warning_patterns: Array[RegEx] = []

# Configuration
var auto_detect_errors: bool = true
var auto_detect_warnings: bool = true
var buffer_size_limit: int = 10000
var command_timeout: float = 30.0

# Internal components
var timer: Timer

func _init():
	name = "TerminalIntegration"
	_setup_error_patterns()
	_setup_warning_patterns()

func _ready():
	# Setup timer for periodic monitoring
	timer = Timer.new()
	timer.wait_time = 0.5  # Check every 500ms
	timer.timeout.connect(_monitor_terminal)
	add_child(timer)
	
	print("Terminal Integration initialized")

func _setup_error_patterns():
	"""Setup regex patterns for common error detection"""
	error_patterns.clear()
	
	var patterns = [
		# GDScript errors
		r"ERROR.*?at.*?line\s+(\d+)",
		r"Parse Error.*?line\s+(\d+)",
		r"Invalid.*?identifier.*?line\s+(\d+)",
		r"Expected.*?line\s+(\d+)",
		r"Unexpected.*?line\s+(\d+)",
		
		# Godot engine errors
		r"ERROR.*?res://.*?:(\d+)",
		r"SCRIPT ERROR.*?res://.*?:(\d+)",
		r"RUNTIME ERROR.*?res://.*?:(\d+)",
		
		# Build errors
		r"error C\d+:",
		r"fatal error:",
		r"compilation terminated",
		
		# General errors
		r"Error:",
		r"ERROR:",
		r"Failed to",
		r"Cannot",
		r"Unable to"
	]
	
	for pattern in patterns:
		var regex = RegEx.new()
		if regex.compile(pattern) == OK:
			error_patterns.append(regex)

func _setup_warning_patterns():
	"""Setup regex patterns for common warning detection"""
	warning_patterns.clear()
	
	var patterns = [
		# GDScript warnings
		r"WARNING.*?line\s+(\d+)",
		r"DEPRECATED.*?line\s+(\d+)",
		r"Unused.*?line\s+(\d+)",
		
		# Godot warnings
		r"WARNING.*?res://.*?:(\d+)",
		r"DEPRECATED.*?res://.*?:(\d+)",
		
		# General warnings
		r"Warning:",
		r"WARNING:",
		r"Deprecated:",
		r"DEPRECATED:"
	]
	
	for pattern in patterns:
		var regex = RegEx.new()
		if regex.compile(pattern) == OK:
			warning_patterns.append(regex)

func start_monitoring():
	"""Start monitoring terminal output"""
	if not is_monitoring:
		is_monitoring = true
		timer.start()
		print("Terminal monitoring started")

func stop_monitoring():
	"""Stop monitoring terminal output"""
	if is_monitoring:
		is_monitoring = false
		timer.stop()
		print("Terminal monitoring stopped")

func execute_command(command: String, working_dir: String = "") -> Dictionary:
	"""Execute a command and return the result"""
	print("Executing command: ", command)
	
	var result = {
		"success": false,
		"output": "",
		"error": "",
		"exit_code": -1,
		"command": command
	}
	
	# Use OS.execute for synchronous execution
	var output = []
	var exit_code = OS.execute("bash", ["-c", command], output, true, true)
	
	result["exit_code"] = exit_code
	result["success"] = exit_code == 0
	result["output"] = "\n".join(output) if output.size() > 0 else ""
	
	# Emit signal
	command_executed.emit(command, result["output"], exit_code)
	
	# Check for errors and warnings in output
	if auto_detect_errors or auto_detect_warnings:
		_analyze_output(result["output"], command)
	
	return result

func _monitor_terminal():
	"""Monitor terminal output for errors and warnings"""
	if not is_monitoring:
		return
	
	# Emit output received signal if we have new output
	if output_buffer.length() > 0:
		output_received.emit(output_buffer)
		
		# Analyze for errors and warnings
		if auto_detect_errors or auto_detect_warnings:
			_analyze_output(output_buffer)
		
		# Clear buffer if it gets too large
		if output_buffer.length() > buffer_size_limit:
			output_buffer = output_buffer.substr(output_buffer.length() - buffer_size_limit/2)

func _analyze_output(output: String, command: String = ""):
	"""Analyze output for errors and warnings"""
	var lines = output.split("\n")
	
	for line_num in range(lines.size()):
		var line = lines[line_num]
		
		# Check for errors
		if auto_detect_errors:
			for error_pattern in error_patterns:
				var result = error_pattern.search(line)
				if result:
					var error_info = _extract_error_info(line, result, line_num, command)
					error_detected.emit(error_info)
		
		# Check for warnings
		if auto_detect_warnings:
			for warning_pattern in warning_patterns:
				var result = warning_pattern.search(line)
				if result:
					var warning_info = _extract_warning_info(line, result, line_num, command)
					warning_detected.emit(warning_info)

func _extract_error_info(line: String, regex_result: RegExMatch, line_num: int, command: String) -> Dictionary:
	"""Extract detailed error information"""
	var error_info = {
		"type": "error",
		"message": line.strip_edges(),
		"line_number": -1,
		"file_path": "",
		"command": command,
		"timestamp": Time.get_unix_time_from_system(),
		"severity": "high"
	}
	
	# Try to extract line number if captured
	if regex_result.get_group_count() > 0:
		var line_str = regex_result.get_string(1)
		if line_str.is_valid_int():
			error_info["line_number"] = line_str.to_int()
	
	# Try to extract file path
	var file_pattern = RegEx.new()
	file_pattern.compile(r"res://[^\s:]+")
	var file_result = file_pattern.search(line)
	if file_result:
		error_info["file_path"] = file_result.get_string()
	
	return error_info

func _extract_warning_info(line: String, regex_result: RegExMatch, line_num: int, command: String) -> Dictionary:
	"""Extract detailed warning information"""
	var warning_info = {
		"type": "warning",
		"message": line.strip_edges(),
		"line_number": -1,
		"file_path": "",
		"command": command,
		"timestamp": Time.get_unix_time_from_system(),
		"severity": "medium"
	}
	
	# Try to extract line number if captured
	if regex_result.get_group_count() > 0:
		var line_str = regex_result.get_string(1)
		if line_str.is_valid_int():
			warning_info["line_number"] = line_str.to_int()
	
	# Try to extract file path
	var file_pattern = RegEx.new()
	file_pattern.compile(r"res://[^\s:]+")
	var file_result = file_pattern.search(line)
	if file_result:
		warning_info["file_path"] = file_result.get_string()
	
	return warning_info

func add_output_to_buffer(output: String):
	"""Add output to the monitoring buffer"""
	output_buffer += output + "\n"

func get_recent_output(lines: int = 50) -> String:
	"""Get recent output from buffer"""
	var buffer_lines = output_buffer.split("\n")
	var start_index = max(0, buffer_lines.size() - lines)
	var recent_lines = buffer_lines.slice(start_index)
	return "\n".join(recent_lines)

func clear_output_buffer():
	"""Clear the output buffer"""
	output_buffer = ""

func set_error_detection(enabled: bool):
	"""Enable or disable automatic error detection"""
	auto_detect_errors = enabled

func set_warning_detection(enabled: bool):
	"""Enable or disable automatic warning detection"""
	auto_detect_warnings = enabled

func get_status() -> Dictionary:
	"""Get current terminal integration status"""
	return {
		"monitoring": is_monitoring,
		"buffer_size": output_buffer.length(),
		"error_detection": auto_detect_errors,
		"warning_detection": auto_detect_warnings,
		"patterns_loaded": {
			"errors": error_patterns.size(),
			"warnings": warning_patterns.size()
		}
	}
