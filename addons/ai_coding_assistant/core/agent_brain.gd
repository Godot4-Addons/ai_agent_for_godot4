@tool
extends Node
class_name AgentBrain

# Core AI Agent Brain - Decision making and task coordination center
# This is the central intelligence that coordinates all agent activities

signal task_started(task: Dictionary)
signal task_completed(task: Dictionary, result: Dictionary)
signal task_failed(task: Dictionary, error: String)
signal decision_made(decision: Dictionary)
signal goal_set(goal: Dictionary)
signal goal_achieved(goal: Dictionary)

# Core components
var task_manager: TaskManager
var memory: AgentMemory
var terminal_integration: TerminalIntegration
var auto_error_fixer: AutoErrorFixer
var api_manager: AIApiManager

# Agent state
var current_goal: Dictionary = {}
var active_tasks: Array[Dictionary] = []
var agent_mode: String = "idle"  # idle, working, monitoring, learning
var decision_history: Array[Dictionary] = []
var performance_metrics: Dictionary = {}

# Enhanced Configuration
var max_concurrent_tasks: int = 5  # Increased capacity
var decision_confidence_threshold: float = 0.6  # More proactive
var auto_mode_enabled: bool = true  # Enable by default
var learning_enabled: bool = true
var context_awareness_enabled: bool = true
var adaptive_learning: bool = true
var async_processing: bool = true

# Advanced decision making
var decision_weights: Dictionary = {
	"urgency": 0.3,
	"complexity": 0.2,
	"success_probability": 0.25,
	"learning_value": 0.15,
	"user_preference": 0.1
}

# Context and memory integration
var context_manager: ContextManager
var short_term_memory: Array[Dictionary] = []
var pattern_recognition: Dictionary = {}
var success_patterns: Dictionary = {}
var failure_patterns: Dictionary = {}

# Agent capabilities
var capabilities: Dictionary = {
	"code_analysis": true,
	"code_generation": true,
	"error_fixing": true,
	"terminal_operations": true,
	"file_operations": true,
	"project_management": true,
	"testing": true,
	"refactoring": true
}

func _init():
	name = "AgentBrain"
	_initialize_performance_metrics()

func _ready():
	_setup_components()
	_connect_signals()
	print("Agent Brain initialized - Ready for autonomous operation")

func _setup_components():
	"""Initialize all agent components"""
	# Get existing components from parent
	var parent = get_parent()
	
	task_manager = parent.get_node_or_null("TaskManager")
	memory = parent.get_node_or_null("AgentMemory")
	terminal_integration = parent.get_node_or_null("TerminalIntegration")
	auto_error_fixer = parent.get_node_or_null("AutoErrorFixer")
	api_manager = parent.get_node_or_null("AIApiManager")

func _connect_signals():
	"""Connect signals from various components"""
	if terminal_integration:
		terminal_integration.error_detected.connect(_on_error_detected)
		terminal_integration.warning_detected.connect(_on_warning_detected)
		terminal_integration.command_executed.connect(_on_command_executed)
	
	if task_manager:
		task_manager.task_completed.connect(_on_task_completed)
		task_manager.task_failed.connect(_on_task_failed)

func _initialize_performance_metrics():
	"""Initialize performance tracking metrics"""
	performance_metrics = {
		"tasks_completed": 0,
		"tasks_failed": 0,
		"errors_fixed": 0,
		"code_generated_lines": 0,
		"decisions_made": 0,
		"success_rate": 0.0,
		"average_task_time": 0.0,
		"uptime": 0.0,
		"start_time": Time.get_unix_time_from_system()
	}

func set_goal(goal_description: String, priority: int = 5, deadline: float = -1, context: Dictionary = {}) -> Dictionary:
	"""Enhanced goal setting with context awareness and intelligent analysis"""
	var goal = {
		"id": _generate_id(),
		"description": goal_description,
		"priority": priority,
		"deadline": deadline,
		"created_at": Time.get_unix_time_from_system(),
		"status": "active",
		"progress": 0.0,
		"subtasks": [],
		"context": context,
		"complexity": _estimate_complexity(goal_description),
		"success_probability": _estimate_success_probability(goal_description, context),
		"learning_value": _estimate_learning_value(goal_description),
		"async_enabled": async_processing
	}

	current_goal = goal
	goal_set.emit(goal)

	# Enhanced goal decomposition
	if async_processing:
		_decompose_goal_async(goal)
	else:
		_decompose_goal_into_tasks(goal)

	# Auto-start if conditions are met
	if auto_mode_enabled and goal["success_probability"] > decision_confidence_threshold:
		_start_autonomous_execution(goal)

	print("Enhanced goal set: ", goal_description, " (Complexity: ", goal["complexity"], ", Success Prob: ", goal["success_probability"], ")")
	return goal

func _decompose_goal_into_tasks(goal: Dictionary):
	"""Break down a goal into actionable tasks"""
	var goal_description = goal["description"].to_lower()
	var tasks = []
	
	# Analyze goal and create appropriate tasks
	if "fix" in goal_description and "error" in goal_description:
		tasks.append(_create_task("analyze_errors", "Analyze current errors", 8))
		tasks.append(_create_task("fix_errors", "Fix detected errors", 9))
		tasks.append(_create_task("verify_fixes", "Verify error fixes", 7))
	
	elif "implement" in goal_description or "create" in goal_description:
		tasks.append(_create_task("analyze_requirements", "Analyze implementation requirements", 7))
		tasks.append(_create_task("design_solution", "Design implementation approach", 6))
		tasks.append(_create_task("generate_code", "Generate required code", 8))
		tasks.append(_create_task("test_implementation", "Test implementation", 7))
	
	elif "refactor" in goal_description:
		tasks.append(_create_task("analyze_code", "Analyze code for refactoring", 6))
		tasks.append(_create_task("plan_refactoring", "Plan refactoring approach", 5))
		tasks.append(_create_task("apply_refactoring", "Apply refactoring changes", 7))
		tasks.append(_create_task("validate_refactoring", "Validate refactored code", 6))
	
	else:
		# Generic task breakdown
		tasks.append(_create_task("analyze_context", "Analyze current context", 5))
		tasks.append(_create_task("plan_approach", "Plan implementation approach", 4))
		tasks.append(_create_task("execute_plan", "Execute planned actions", 7))
		tasks.append(_create_task("verify_results", "Verify results", 5))
	
	# Add tasks to goal and task manager
	goal["subtasks"] = tasks
	if task_manager:
		for task in tasks:
			task_manager.add_task(task)

func _create_task(task_type: String, description: String, priority: int) -> Dictionary:
	"""Create a new task dictionary"""
	return {
		"id": _generate_id(),
		"type": task_type,
		"description": description,
		"priority": priority,
		"status": "pending",
		"created_at": Time.get_unix_time_from_system(),
		"estimated_duration": 300.0,  # 5 minutes default
		"dependencies": [],
		"context": {}
	}

func make_decision(context: Dictionary, options: Array) -> Dictionary:
	"""Make an intelligent decision based on context and available options"""
	var decision = {
		"id": _generate_id(),
		"timestamp": Time.get_unix_time_from_system(),
		"context": context,
		"options": options,
		"chosen_option": {},
		"confidence": 0.0,
		"reasoning": ""
	}
	
	# Analyze options and choose the best one
	var best_option = _evaluate_options(context, options)
	decision["chosen_option"] = best_option["option"]
	decision["confidence"] = best_option["confidence"]
	decision["reasoning"] = best_option["reasoning"]
	
	# Store decision in history
	decision_history.append(decision)
	performance_metrics["decisions_made"] += 1
	
	decision_made.emit(decision)
	return decision

func _evaluate_options(context: Dictionary, options: Array) -> Dictionary:
	"""Evaluate available options and return the best one"""
	var best_option = {
		"option": {},
		"confidence": 0.0,
		"reasoning": "No suitable option found"
	}
	
	if options.is_empty():
		return best_option
	
	var scores = []
	
	for option in options:
		var score = _score_option(option, context)
		scores.append({"option": option, "score": score})
	
	# Sort by score (highest first)
	scores.sort_custom(func(a, b): return a["score"] > b["score"])
	
	if scores.size() > 0:
		var top_option = scores[0]
		best_option["option"] = top_option["option"]
		best_option["confidence"] = min(top_option["score"] / 100.0, 1.0)
		best_option["reasoning"] = "Selected based on scoring algorithm"
	
	return best_option

func _score_option(option: Dictionary, context: Dictionary) -> float:
	"""Score an option based on various factors"""
	var score = 0.0
	
	# Base score from priority if available
	if option.has("priority"):
		score += option["priority"] * 10
	
	# Consider urgency
	if option.has("urgent") and option["urgent"]:
		score += 25
	
	# Consider complexity (lower complexity = higher score)
	if option.has("complexity"):
		score += (10 - option["complexity"]) * 5
	
	# Consider success probability
	if option.has("success_probability"):
		score += option["success_probability"] * 30
	
	# Consider resource requirements (lower = better)
	if option.has("resource_cost"):
		score -= option["resource_cost"] * 2
	
	# Context-specific scoring
	if context.has("error_severity"):
		if option.has("fixes_errors") and option["fixes_errors"]:
			score += context["error_severity"] * 15
	
	return score

func _on_error_detected(error_info: Dictionary):
	"""Handle detected errors"""
	print("Agent Brain: Error detected - ", error_info["message"])
	
	# Store error in memory
	if memory:
		memory.store_error(error_info)
	
	# If auto mode is enabled, create a task to fix the error
	if auto_mode_enabled and task_manager:
		var fix_task = _create_task("fix_error", "Fix detected error: " + error_info["message"], 9)
		fix_task["context"]["error_info"] = error_info
		task_manager.add_task(fix_task)

func _on_warning_detected(warning_info: Dictionary):
	"""Handle detected warnings"""
	print("Agent Brain: Warning detected - ", warning_info["message"])
	
	# Store warning in memory
	if memory:
		memory.store_warning(warning_info)
	
	# Create lower priority task to address warning if auto mode enabled
	if auto_mode_enabled and task_manager:
		var warning_task = _create_task("address_warning", "Address warning: " + warning_info["message"], 4)
		warning_task["context"]["warning_info"] = warning_info
		task_manager.add_task(warning_task)

func _on_command_executed(command: String, output: String, exit_code: int):
	"""Handle command execution results"""
	var execution_info = {
		"command": command,
		"output": output,
		"exit_code": exit_code,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# Store in memory
	if memory:
		memory.store_command_execution(execution_info)
	
	# Learn from the execution
	if learning_enabled:
		_learn_from_execution(execution_info)

func _on_task_completed(task: Dictionary, result: Dictionary):
	"""Handle task completion"""
	print("Agent Brain: Task completed - ", task["description"])
	performance_metrics["tasks_completed"] += 1
	_update_success_rate()
	task_completed.emit(task, result)

func _on_task_failed(task: Dictionary, error: String):
	"""Handle task failure"""
	print("Agent Brain: Task failed - ", task["description"], " Error: ", error)
	performance_metrics["tasks_failed"] += 1
	_update_success_rate()
	task_failed.emit(task, error)

func _learn_from_execution(execution_info: Dictionary):
	"""Learn from command execution results"""
	# This is a placeholder for machine learning capabilities
	# In a full implementation, this would analyze patterns and improve decision making
	pass

func _update_success_rate():
	"""Update the agent's success rate metric"""
	var total_tasks = performance_metrics["tasks_completed"] + performance_metrics["tasks_failed"]
	if total_tasks > 0:
		performance_metrics["success_rate"] = float(performance_metrics["tasks_completed"]) / total_tasks

func _generate_id() -> String:
	"""Generate a unique ID"""
	return "agent_" + str(Time.get_unix_time_from_system()) + "_" + str(randi() % 10000)

# Enhanced AI Agent Intelligence Functions
func _estimate_complexity(description: String) -> float:
	"""Estimate goal complexity using advanced keyword analysis"""
	var complexity = 0.5  # Base complexity

	var complex_keywords = ["refactor", "optimize", "architecture", "system", "framework", "redesign", "migrate"]
	var medium_keywords = ["implement", "create", "build", "develop", "enhance"]
	var simple_keywords = ["fix", "add", "remove", "update", "change", "modify"]

	var lower_desc = description.to_lower()

	for keyword in complex_keywords:
		if keyword in lower_desc:
			complexity += 0.3

	for keyword in medium_keywords:
		if keyword in lower_desc:
			complexity += 0.1

	for keyword in simple_keywords:
		if keyword in lower_desc:
			complexity -= 0.1

	# Check for multiple components
	if "and" in lower_desc or "," in description:
		complexity += 0.2

	return clamp(complexity, 0.1, 1.0)

func _estimate_success_probability(description: String, context: Dictionary) -> float:
	"""Estimate probability of successful completion using pattern recognition"""
	var base_probability = 0.7

	# Check historical success patterns
	for pattern in success_patterns:
		if _matches_pattern(description, pattern):
			base_probability += 0.15

	# Check failure patterns
	for pattern in failure_patterns:
		if _matches_pattern(description, pattern):
			base_probability -= 0.2

	# Context factors
	if context.has("current_file") and not context["current_file"].is_empty():
		base_probability += 0.1

	if context.has("recent_errors") and context["recent_errors"].size() > 0:
		base_probability -= 0.1

	return clamp(base_probability, 0.1, 1.0)

func _estimate_learning_value(description: String) -> float:
	"""Estimate learning value for continuous improvement"""
	var learning_value = 0.5

	var learning_keywords = ["new", "learn", "explore", "experiment", "research", "innovative"]
	var routine_keywords = ["fix", "update", "change", "modify", "standard"]

	var lower_desc = description.to_lower()

	for keyword in learning_keywords:
		if keyword in lower_desc:
			learning_value += 0.2

	for keyword in routine_keywords:
		if keyword in lower_desc:
			learning_value -= 0.1

	return clamp(learning_value, 0.1, 1.0)

func _matches_pattern(text: String, pattern: Dictionary) -> bool:
	"""Advanced pattern matching for decision making"""
	var keywords = pattern.get("keywords", [])
	var lower_text = text.to_lower()

	var matches = 0
	for keyword in keywords:
		if keyword in lower_text:
			matches += 1

	return float(matches) / keywords.size() > 0.5

func _decompose_goal_async(goal: Dictionary):
	"""Asynchronously decompose goal with AI assistance"""
	if api_manager:
		var prompt = _build_decomposition_prompt(goal)
		var request_id = api_manager.send_chat_request_async(prompt)
		# Response will be handled by signal callback
	else:
		_decompose_goal_into_tasks(goal)

func _build_decomposition_prompt(goal: Dictionary) -> String:
	"""Build intelligent prompt for AI-assisted goal decomposition"""
	var prompt = """As an expert Godot development agent, analyze and decompose this goal:

GOAL: %s
PRIORITY: %d/10
COMPLEXITY: %.2f
CONTEXT: %s

Provide:
1. Goal analysis and approach
2. Step-by-step task breakdown
3. Potential challenges and solutions
4. Success criteria and verification

Focus on actionable tasks for autonomous execution.""" % [
		goal["description"],
		goal["priority"],
		goal["complexity"],
		str(goal.get("context", {}))
	]

	return prompt

func _start_autonomous_execution(goal: Dictionary):
	"""Initiate autonomous goal execution"""
	if not auto_mode_enabled:
		return

	agent_mode = "working"
	print("🤖 Starting autonomous execution: ", goal["description"])

	# Execute tasks autonomously
	for task in goal.get("subtasks", []):
		if task_manager:
			task_manager.execute_task_async(task)

func update_learning_patterns(goal: Dictionary, success: bool):
	"""Update learning patterns based on outcomes"""
	if not learning_enabled:
		return

	var pattern = {
		"keywords": _extract_keywords(goal["description"]),
		"complexity": goal["complexity"],
		"success": success,
		"timestamp": Time.get_unix_time_from_system()
	}

	var pattern_key = str(pattern["keywords"])
	if success:
		success_patterns[pattern_key] = pattern
	else:
		failure_patterns[pattern_key] = pattern

	print("📚 Learning pattern updated: ", pattern_key, " -> ", success)

func _extract_keywords(text: String) -> Array:
	"""Extract meaningful keywords for pattern recognition"""
	var words = text.to_lower().split(" ")
	var keywords = []

	var meaningful_words = ["create", "fix", "optimize", "refactor", "implement", "analyze", "test", "debug"]

	for word in words:
		if word.length() > 3 and (word in meaningful_words or not _is_common_word(word)):
			keywords.append(word)

	return keywords

func _is_common_word(word: String) -> bool:
	"""Filter out common words that don't add meaning"""
	var common_words = ["the", "and", "for", "with", "this", "that", "from", "they", "have", "will"]
	return word in common_words

func get_status() -> Dictionary:
	"""Get current agent status"""
	return {
		"mode": agent_mode,
		"current_goal": current_goal,
		"active_tasks": active_tasks.size(),
		"capabilities": capabilities,
		"performance": performance_metrics,
		"auto_mode": auto_mode_enabled
	}

func enable_auto_mode():
	"""Enable autonomous operation mode"""
	auto_mode_enabled = true
	agent_mode = "monitoring"
	print("Agent Brain: Auto mode enabled - Agent is now autonomous")

func disable_auto_mode():
	"""Disable autonomous operation mode"""
	auto_mode_enabled = false
	agent_mode = "idle"
	print("Agent Brain: Auto mode disabled - Agent is now manual")
