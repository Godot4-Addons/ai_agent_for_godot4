@tool
extends RefCounted
class_name AdvancedCodeAnalyzer

# Advanced Code Analyzer for AI Agent
# Provides deep codebase analysis, dependency tracking, and project understanding

signal analysis_completed(analysis: Dictionary)
signal dependency_graph_updated(graph: Dictionary)
signal pattern_detected(pattern: Dictionary)

# Analysis cache
static var analysis_cache: Dictionary = {}
static var dependency_graph: Dictionary = {}
static var project_structure: Dictionary = {}
static var code_metrics: Dictionary = {}

# Configuration
static var cache_enabled: bool = true
static var deep_analysis_enabled: bool = true
static var pattern_detection_enabled: bool = true
static var performance_analysis_enabled: bool = true

static func analyze_project(project_path: String = "res://") -> Dictionary:
	"""Perform comprehensive project analysis"""
	print("Starting comprehensive project analysis...")
	
	var analysis = {
		"timestamp": Time.get_unix_time_from_system(),
		"project_path": project_path,
		"structure": {},
		"dependencies": {},
		"metrics": {},
		"patterns": [],
		"issues": [],
		"recommendations": []
	}
	
	# Analyze project structure
	analysis["structure"] = _analyze_project_structure(project_path)
	
	# Build dependency graph
	analysis["dependencies"] = _build_dependency_graph(project_path)
	
	# Calculate code metrics
	analysis["metrics"] = _calculate_code_metrics(project_path)
	
	# Detect patterns
	if pattern_detection_enabled:
		analysis["patterns"] = _detect_code_patterns(project_path)
	
	# Identify issues
	analysis["issues"] = _identify_code_issues(project_path)
	
	# Generate recommendations
	analysis["recommendations"] = _generate_recommendations(analysis)
	
	# Cache results
	if cache_enabled:
		analysis_cache[project_path] = analysis
	
	print("Project analysis completed")
	return analysis

static func analyze_file(file_path: String) -> Dictionary:
	"""Perform detailed analysis of a single file"""
	if not FileAccess.file_exists(file_path):
		return {"error": "File not found: " + file_path}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {"error": "Cannot open file: " + file_path}
	
	var content = file.get_as_text()
	file.close()
	
	var analysis = {
		"file_path": file_path,
		"timestamp": Time.get_unix_time_from_system(),
		"content_length": content.length(),
		"line_count": content.split("\n").size(),
		"structure": {},
		"dependencies": [],
		"metrics": {},
		"issues": [],
		"suggestions": []
	}
	
	# Parse file structure
	analysis["structure"] = _parse_file_structure(content, file_path)
	
	# Extract dependencies
	analysis["dependencies"] = _extract_file_dependencies(content)
	
	# Calculate file metrics
	analysis["metrics"] = _calculate_file_metrics(content)
	
	# Identify issues
	analysis["issues"] = _identify_file_issues(content, file_path)
	
	# Generate suggestions
	analysis["suggestions"] = _generate_file_suggestions(analysis)
	
	return analysis

static func _analyze_project_structure(project_path: String) -> Dictionary:
	"""Analyze the overall project structure"""
	var structure = {
		"total_files": 0,
		"gdscript_files": 0,
		"scene_files": 0,
		"resource_files": 0,
		"directories": [],
		"file_tree": {},
		"main_scenes": [],
		"autoloads": [],
		"plugins": []
	}
	
	var dir = DirAccess.open(project_path)
	if dir:
		structure["file_tree"] = _build_file_tree(dir, project_path)
		structure = _count_files_by_type(structure, structure["file_tree"])
	
	# Analyze project.godot for autoloads and main scenes
	var project_file_path = project_path + "/project.godot"
	if FileAccess.file_exists(project_file_path):
		structure = _analyze_project_config(structure, project_file_path)
	
	return structure

static func _build_file_tree(dir: DirAccess, path: String) -> Dictionary:
	"""Build a tree structure of all files and directories"""
	var tree = {}
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = path + "/" + file_name
		
		if dir.current_is_dir() and not file_name.begins_with("."):
			var sub_dir = DirAccess.open(full_path)
			if sub_dir:
				tree[file_name] = {
					"type": "directory",
					"children": _build_file_tree(sub_dir, full_path)
				}
		else:
			tree[file_name] = {
				"type": "file",
				"extension": file_name.get_extension(),
				"size": FileAccess.get_file_as_bytes(full_path).size()
			}
		
		file_name = dir.get_next()
	
	return tree

static func _count_files_by_type(structure: Dictionary, tree: Dictionary) -> Dictionary:
	"""Count files by type from the file tree"""
	for item_name in tree:
		var item = tree[item_name]
		
		if item["type"] == "directory":
			structure = _count_files_by_type(structure, item["children"])
		else:
			structure["total_files"] += 1
			
			match item["extension"]:
				"gd":
					structure["gdscript_files"] += 1
				"tscn":
					structure["scene_files"] += 1
				"tres", "res":
					structure["resource_files"] += 1
	
	return structure

static func _analyze_project_config(structure: Dictionary, config_path: String) -> Dictionary:
	"""Analyze project.godot configuration"""
	var file = FileAccess.open(config_path, FileAccess.READ)
	if not file:
		return structure
	
	var content = file.get_as_text()
	file.close()
	
	var lines = content.split("\n")
	var current_section = ""
	
	for line in lines:
		line = line.strip_edges()
		
		if line.begins_with("[") and line.ends_with("]"):
			current_section = line.substr(1, line.length() - 2)
		elif current_section == "autoload" and "=" in line:
			var parts = line.split("=")
			if parts.size() >= 2:
				structure["autoloads"].append(parts[0].strip_edges())
		elif current_section == "application" and line.begins_with("run/main_scene"):
			var parts = line.split("=")
			if parts.size() >= 2:
				structure["main_scenes"].append(parts[1].strip_edges().trim_prefix("\"").trim_suffix("\""))
	
	return structure

static func _build_dependency_graph(project_path: String) -> Dictionary:
	"""Build a comprehensive dependency graph"""
	var graph = {
		"nodes": {},
		"edges": [],
		"cycles": [],
		"orphans": [],
		"entry_points": []
	}
	
	# Find all GDScript files
	var gdscript_files = _find_gdscript_files(project_path)
	
	# Analyze each file for dependencies
	for file_path in gdscript_files:
		var file_deps = _extract_file_dependencies_from_file(file_path)
		graph["nodes"][file_path] = {
			"dependencies": file_deps,
			"dependents": [],
			"type": _classify_file_type(file_path)
		}
	
	# Build edges and reverse dependencies
	for file_path in graph["nodes"]:
		var node = graph["nodes"][file_path]
		for dep in node["dependencies"]:
			graph["edges"].append({"from": file_path, "to": dep})
			
			if graph["nodes"].has(dep):
				graph["nodes"][dep]["dependents"].append(file_path)
	
	# Detect cycles
	graph["cycles"] = _detect_dependency_cycles(graph)
	
	# Find orphans (files with no dependencies or dependents)
	graph["orphans"] = _find_orphan_files(graph)
	
	# Identify entry points
	graph["entry_points"] = _find_entry_points(graph)
	
	return graph

static func _find_gdscript_files(path: String) -> Array[String]:
	"""Find all GDScript files in the project"""
	var files = []
	var dir = DirAccess.open(path)
	
	if dir:
		_find_files_recursive(dir, path, files, ["gd"])
	
	return files

static func _find_files_recursive(dir: DirAccess, path: String, files: Array, extensions: Array):
	"""Recursively find files with specific extensions"""
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = path + "/" + file_name
		
		if dir.current_is_dir() and not file_name.begins_with("."):
			var sub_dir = DirAccess.open(full_path)
			if sub_dir:
				_find_files_recursive(sub_dir, full_path, files, extensions)
		else:
			var extension = file_name.get_extension()
			if extension in extensions:
				files.append(full_path)
		
		file_name = dir.get_next()

static func _extract_file_dependencies_from_file(file_path: String) -> Array[String]:
	"""Extract dependencies from a specific file"""
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return []
	
	var content = file.get_as_text()
	file.close()
	
	return _extract_file_dependencies(content)

static func _extract_file_dependencies(content: String) -> Array[String]:
	"""Extract dependencies from file content"""
	var dependencies = []
	var lines = content.split("\n")
	
	for line in lines:
		line = line.strip_edges()
		
		# Check for preload statements
		if line.begins_with("const") and "preload(" in line:
			var dep = _extract_path_from_preload(line)
			if dep != "":
				dependencies.append(dep)
		
		# Check for load statements
		elif "load(" in line:
			var dep = _extract_path_from_load(line)
			if dep != "":
				dependencies.append(dep)
		
		# Check for extends statements
		elif line.begins_with("extends ") and "res://" in line:
			var dep = _extract_path_from_extends(line)
			if dep != "":
				dependencies.append(dep)
	
	return dependencies

static func _extract_path_from_preload(line: String) -> String:
	"""Extract file path from preload statement"""
	var start = line.find("\"res://")
	if start == -1:
		start = line.find("'res://")
	if start == -1:
		return ""
	
	var quote_char = line[start]
	var end = line.find(quote_char, start + 1)
	if end == -1:
		return ""
	
	return line.substr(start + 1, end - start - 1)

static func _extract_path_from_load(line: String) -> String:
	"""Extract file path from load statement"""
	return _extract_path_from_preload(line)  # Same logic

static func _extract_path_from_extends(line: String) -> String:
	"""Extract file path from extends statement"""
	var parts = line.split(" ")
	for part in parts:
		if part.begins_with("\"res://") or part.begins_with("'res://"):
			return part.strip_edges().trim_prefix("\"").trim_suffix("\"").trim_prefix("'").trim_suffix("'")
	return ""

static func _classify_file_type(file_path: String) -> String:
	"""Classify the type of a file based on its content and location"""
	if "autoload" in file_path.to_lower():
		return "autoload"
	elif "singleton" in file_path.to_lower():
		return "singleton"
	elif "manager" in file_path.to_lower():
		return "manager"
	elif "controller" in file_path.to_lower():
		return "controller"
	elif "ui" in file_path.to_lower() or "menu" in file_path.to_lower():
		return "ui"
	elif "player" in file_path.to_lower():
		return "player"
	else:
		return "script"

static func _detect_dependency_cycles(graph: Dictionary) -> Array:
	"""Detect circular dependencies in the graph"""
	var cycles = []
	var visited = {}
	var rec_stack = {}
	
	for node in graph["nodes"]:
		if not visited.get(node, false):
			var cycle = _dfs_cycle_detection(node, graph, visited, rec_stack, [])
			if not cycle.is_empty():
				cycles.append(cycle)
	
	return cycles

static func _dfs_cycle_detection(node: String, graph: Dictionary, visited: Dictionary, rec_stack: Dictionary, path: Array) -> Array:
	"""DFS-based cycle detection"""
	visited[node] = true
	rec_stack[node] = true
	path.append(node)
	
	if graph["nodes"].has(node):
		for dep in graph["nodes"][node]["dependencies"]:
			if not visited.get(dep, false):
				var cycle = _dfs_cycle_detection(dep, graph, visited, rec_stack, path)
				if not cycle.is_empty():
					return cycle
			elif rec_stack.get(dep, false):
				# Found a cycle
				var cycle_start = path.find(dep)
				return path.slice(cycle_start)
	
	rec_stack[node] = false
	path.pop_back()
	return []

static func _find_orphan_files(graph: Dictionary) -> Array[String]:
	"""Find files with no dependencies or dependents"""
	var orphans = []
	
	for file_path in graph["nodes"]:
		var node = graph["nodes"][file_path]
		if node["dependencies"].is_empty() and node["dependents"].is_empty():
			orphans.append(file_path)
	
	return orphans

static func _find_entry_points(graph: Dictionary) -> Array[String]:
	"""Find entry point files (no dependencies but have dependents)"""
	var entry_points = []
	
	for file_path in graph["nodes"]:
		var node = graph["nodes"][file_path]
		if node["dependencies"].is_empty() and not node["dependents"].is_empty():
			entry_points.append(file_path)
	
	return entry_points

static func _calculate_code_metrics(project_path: String) -> Dictionary:
	"""Calculate comprehensive code metrics"""
	var metrics = {
		"total_lines": 0,
		"code_lines": 0,
		"comment_lines": 0,
		"blank_lines": 0,
		"function_count": 0,
		"class_count": 0,
		"complexity_score": 0.0,
		"maintainability_index": 0.0,
		"test_coverage": 0.0
	}
	
	var gdscript_files = _find_gdscript_files(project_path)
	
	for file_path in gdscript_files:
		var file_metrics = _calculate_file_metrics_from_file(file_path)
		metrics["total_lines"] += file_metrics["total_lines"]
		metrics["code_lines"] += file_metrics["code_lines"]
		metrics["comment_lines"] += file_metrics["comment_lines"]
		metrics["blank_lines"] += file_metrics["blank_lines"]
		metrics["function_count"] += file_metrics["function_count"]
		metrics["class_count"] += file_metrics["class_count"]
		metrics["complexity_score"] += file_metrics["complexity_score"]
	
	# Calculate averages and indices
	var file_count = gdscript_files.size()
	if file_count > 0:
		metrics["complexity_score"] /= file_count
		metrics["maintainability_index"] = _calculate_maintainability_index(metrics)
	
	return metrics

static func _calculate_file_metrics_from_file(file_path: String) -> Dictionary:
	"""Calculate metrics for a specific file"""
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {}
	
	var content = file.get_as_text()
	file.close()
	
	return _calculate_file_metrics(content)

static func _calculate_file_metrics(content: String) -> Dictionary:
	"""Calculate metrics from file content"""
	var metrics = {
		"total_lines": 0,
		"code_lines": 0,
		"comment_lines": 0,
		"blank_lines": 0,
		"function_count": 0,
		"class_count": 0,
		"complexity_score": 0.0
	}
	
	var lines = content.split("\n")
	metrics["total_lines"] = lines.size()
	
	for line in lines:
		var trimmed = line.strip_edges()
		
		if trimmed.is_empty():
			metrics["blank_lines"] += 1
		elif trimmed.begins_with("#"):
			metrics["comment_lines"] += 1
		else:
			metrics["code_lines"] += 1
			
			# Count functions and classes
			if trimmed.begins_with("func "):
				metrics["function_count"] += 1
			elif trimmed.begins_with("class ") or trimmed.begins_with("class_name "):
				metrics["class_count"] += 1
			
			# Calculate complexity (simplified)
			metrics["complexity_score"] += _calculate_line_complexity(trimmed)
	
	return metrics

static func _calculate_line_complexity(line: String) -> float:
	"""Calculate complexity score for a single line"""
	var complexity = 0.0
	
	# Control flow statements increase complexity
	var control_keywords = ["if", "elif", "else", "for", "while", "match", "when"]
	for keyword in control_keywords:
		if (" " + keyword + " ") in (" " + line + " "):
			complexity += 1.0
	
	# Nested structures increase complexity
	var nesting_level = 0
	for char in line:
		if char == '\t':
			nesting_level += 1
	complexity += nesting_level * 0.1
	
	return complexity

static func _calculate_maintainability_index(metrics: Dictionary) -> float:
	"""Calculate maintainability index based on various metrics"""
	var lines_of_code = metrics["code_lines"]
	var complexity = metrics["complexity_score"]
	var comment_ratio = float(metrics["comment_lines"]) / metrics["total_lines"] if metrics["total_lines"] > 0 else 0.0
	
	# Simplified maintainability index calculation
	var mi = 100.0
	mi -= complexity * 2.0  # Complexity penalty
	mi += comment_ratio * 10.0  # Comment bonus
	mi -= (lines_of_code / 1000.0) * 5.0  # Size penalty
	
	return max(0.0, min(100.0, mi))

static func _parse_file_structure(content: String, file_path: String) -> Dictionary:
	"""Parse the structure of a file"""
	var structure = {
		"classes": [],
		"functions": [],
		"variables": [],
		"constants": [],
		"signals": [],
		"enums": []
	}
	
	var lines = content.split("\n")
	var current_class = ""
	
	for i in range(lines.size()):
		var line = lines[i]
		var trimmed = line.strip_edges()
		
		if trimmed.is_empty() or trimmed.begins_with("#"):
			continue
		
		# Calculate indentation
		var line_indent = 0
		for char in line:
			if char == '\t':
				line_indent += 1
			else:
				break
		
		# Parse different elements
		if trimmed.begins_with("class_name "):
			var parsed_class_name = trimmed.substr(11).strip_edges()
			structure["classes"].append({
				"name": parsed_class_name,
				"line": i + 1,
				"type": "class_name"
			})
		elif trimmed.begins_with("class "):
			var parsed_class_name = trimmed.substr(6).split(" ")[0]
			structure["classes"].append({
				"name": parsed_class_name,
				"line": i + 1,
				"type": "class"
			})
		elif trimmed.begins_with("func "):
			var func_name = _extract_function_name(trimmed)
			structure["functions"].append({
				"name": func_name,
				"line": i + 1,
				"indent": line_indent,
				"class": current_class
			})
		elif trimmed.begins_with("var "):
			var var_name = _extract_variable_name(trimmed)
			structure["variables"].append({
				"name": var_name,
				"line": i + 1,
				"type": "variable"
			})
		elif trimmed.begins_with("const "):
			var const_name = _extract_variable_name(trimmed.substr(6))
			structure["constants"].append({
				"name": const_name,
				"line": i + 1,
				"type": "constant"
			})
		elif trimmed.begins_with("signal "):
			var signal_name = _extract_signal_name(trimmed)
			structure["signals"].append({
				"name": signal_name,
				"line": i + 1,
				"type": "signal"
			})
		elif trimmed.begins_with("enum "):
			var enum_name = _extract_enum_name(trimmed)
			structure["enums"].append({
				"name": enum_name,
				"line": i + 1,
				"type": "enum"
			})
	
	return structure

static func _extract_function_name(line: String) -> String:
	"""Extract function name from function declaration"""
	var parts = line.split("(")
	if parts.size() > 0:
		var func_part = parts[0].substr(5).strip_edges()  # Remove "func "
		return func_part
	return ""

static func _extract_variable_name(line: String) -> String:
	"""Extract variable name from variable declaration"""
	var parts = line.split(":")
	if parts.size() > 0:
		var var_part = parts[0].split("=")[0].strip_edges()
		if var_part.begins_with("var "):
			var_part = var_part.substr(4)
		return var_part
	return ""

static func _extract_signal_name(line: String) -> String:
	"""Extract signal name from signal declaration"""
	var signal_part = line.substr(7).strip_edges()  # Remove "signal "
	var parts = signal_part.split("(")
	return parts[0].strip_edges()

static func _extract_enum_name(line: String) -> String:
	"""Extract enum name from enum declaration"""
	var enum_part = line.substr(5).strip_edges()  # Remove "enum "
	var parts = enum_part.split(" ")
	return parts[0] if parts.size() > 0 else ""

static func _identify_code_issues(project_path: String) -> Array:
	"""Identify potential issues in the codebase"""
	var issues = []
	
	# This would be expanded with more sophisticated analysis
	# For now, we'll implement basic checks
	
	return issues

static func _identify_file_issues(content: String, file_path: String) -> Array:
	"""Identify issues in a specific file"""
	var issues = []
	
	# Basic issue detection
	var lines = content.split("\n")
	for i in range(lines.size()):
		var line = lines[i]
		var trimmed = line.strip_edges()
		
		# Check for common issues
		if trimmed.length() > 120:
			issues.append({
				"type": "line_too_long",
				"line": i + 1,
				"message": "Line exceeds 120 characters",
				"severity": "warning"
			})
		
		if "print(" in trimmed and not trimmed.begins_with("#"):
			issues.append({
				"type": "debug_print",
				"line": i + 1,
				"message": "Debug print statement found",
				"severity": "info"
			})
	
	return issues

static func _generate_recommendations(analysis: Dictionary) -> Array:
	"""Generate recommendations based on analysis"""
	var recommendations = []
	
	# Analyze metrics and suggest improvements
	var metrics = analysis["metrics"]
	
	if metrics["complexity_score"] > 10.0:
		recommendations.append({
			"type": "complexity",
			"message": "Consider refactoring complex functions to improve maintainability",
			"priority": "high"
		})
	
	if metrics["comment_lines"] < metrics["code_lines"] * 0.1:
		recommendations.append({
			"type": "documentation",
			"message": "Consider adding more comments and documentation",
			"priority": "medium"
		})
	
	# Check dependency issues
	var dependencies = analysis["dependencies"]
	if dependencies["cycles"].size() > 0:
		recommendations.append({
			"type": "circular_dependency",
			"message": "Circular dependencies detected - consider refactoring",
			"priority": "high"
		})
	
	return recommendations

static func _generate_file_suggestions(analysis: Dictionary) -> Array:
	"""Generate suggestions for a specific file"""
	var suggestions = []
	
	var metrics = analysis["metrics"]
	
	if metrics["function_count"] > 20:
		suggestions.append({
			"type": "file_size",
			"message": "Consider splitting this file into smaller modules",
			"priority": "medium"
		})
	
	if metrics["complexity_score"] > 5.0:
		suggestions.append({
			"type": "complexity",
			"message": "Some functions may be too complex - consider refactoring",
			"priority": "medium"
		})
	
	return suggestions

static func _detect_code_patterns(project_path: String) -> Array:
	"""Detect common code patterns in the project"""
	var patterns = []
	
	# This would be expanded with pattern recognition algorithms
	# For now, we'll implement basic pattern detection
	
	return patterns

static func get_cached_analysis(project_path: String) -> Dictionary:
	"""Get cached analysis if available"""
	return analysis_cache.get(project_path, {})

static func clear_cache():
	"""Clear the analysis cache"""
	analysis_cache.clear()
	dependency_graph.clear()
	project_structure.clear()
	code_metrics.clear()
