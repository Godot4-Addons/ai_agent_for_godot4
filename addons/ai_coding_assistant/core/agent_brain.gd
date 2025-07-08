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

# Configuration
var max_concurrent_tasks: int = 3
var decision_confidence_threshold: float = 0.7
var auto_mode_enabled: bool = false
var learning_enabled: bool = true

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

func set_goal(goal_description: String, priority: int = 5, deadline: float = -1) -> Dictionary:
	"""Set a new goal for the agent"""
	var goal = {
		"id": _generate_id(),
		"description": goal_description,
		"priority": priority,
		"deadline": deadline,
		"created_at": Time.get_unix_time_from_system(),
		"status": "active",
		"progress": 0.0,
		"subtasks": []
	}
	
	current_goal = goal
	goal_set.emit(goal)
	
	# Break down goal into tasks
	_decompose_goal_into_tasks(goal)
	
	print("Goal set: ", goal_description)
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
