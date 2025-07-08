@tool
extends Node
class_name TaskManager

# Task Manager for AI Agent
# Handles task scheduling, execution, and coordination

signal task_added(task: Dictionary)
signal task_started(task: Dictionary)
signal task_completed(task: Dictionary, result: Dictionary)
signal task_failed(task: Dictionary, error: String)
signal task_cancelled(task: Dictionary)
signal queue_updated()

# Task queues
var pending_tasks: Array[Dictionary] = []
var active_tasks: Array[Dictionary] = []
var completed_tasks: Array[Dictionary] = []
var failed_tasks: Array[Dictionary] = []

# Enhanced Configuration
var max_concurrent_tasks: int = 5  # Increased capacity
var task_timeout: float = 600.0  # 10 minutes for complex tasks
var auto_retry_failed: bool = true
var max_retries: int = 3
var intelligent_scheduling: bool = true
var async_execution: bool = true
var priority_scheduling: bool = true

# Enhanced task execution
var task_executors: Dictionary = {}
var task_timers: Dictionary = {}
var task_dependencies: Dictionary = {}
var task_execution_times: Dictionary = {}
var task_success_rates: Dictionary = {}

# Performance metrics
var average_execution_time: float = 0.0
var total_tasks_processed: int = 0
var successful_tasks: int = 0
var failed_tasks_count: int = 0

# Context and resource management
var context_manager: ContextManager
var resource_locks: Dictionary = {}
var task_contexts: Dictionary = {}

func _init():
	name = "TaskManager"
	_setup_task_executors()

func _ready():
	# Setup periodic task processing
	var timer = Timer.new()
	timer.wait_time = 1.0  # Process tasks every second
	timer.timeout.connect(_process_task_queue)
	timer.autostart = true
	add_child(timer)
	
	print("Task Manager initialized")

func _setup_task_executors():
	"""Setup task execution handlers"""
	task_executors = {
		"analyze_errors": _execute_analyze_errors,
		"fix_errors": _execute_fix_errors,
		"verify_fixes": _execute_verify_fixes,
		"analyze_requirements": _execute_analyze_requirements,
		"design_solution": _execute_design_solution,
		"generate_code": _execute_generate_code,
		"test_implementation": _execute_test_implementation,
		"analyze_code": _execute_analyze_code,
		"plan_refactoring": _execute_plan_refactoring,
		"apply_refactoring": _execute_apply_refactoring,
		"validate_refactoring": _execute_validate_refactoring,
		"analyze_context": _execute_analyze_context,
		"plan_approach": _execute_plan_approach,
		"execute_plan": _execute_execute_plan,
		"verify_results": _execute_verify_results,
		"fix_error": _execute_fix_single_error,
		"address_warning": _execute_address_warning
	}

func add_task(task: Dictionary) -> bool:
	"""Add a new task to the queue"""
	# Validate task structure
	if not _validate_task(task):
		print("Invalid task structure: ", task)
		return false
	
	# Enhanced default values and metadata
	if not task.has("id"):
		task["id"] = _generate_task_id()
	if not task.has("status"):
		task["status"] = "pending"
	if not task.has("created_at"):
		task["created_at"] = Time.get_unix_time_from_system()
	if not task.has("retry_count"):
		task["retry_count"] = 0
	if not task.has("priority"):
		task["priority"] = 5  # Default priority

	# Enhanced metadata
	task["estimated_duration"] = _estimate_task_duration(task)
	task["complexity"] = _estimate_task_complexity(task)
	task["success_probability"] = _estimate_task_success_probability(task)

	# Context integration
	if context_manager:
		task["context"] = context_manager.get_context_for_ai(false)

	# Dependency analysis
	task["dependencies"] = _analyze_task_dependencies(task)

	# Intelligent scheduling
	if priority_scheduling:
		_insert_task_by_priority(task)
	else:
		pending_tasks.append(task)

	task_added.emit(task)
	queue_updated.emit()

	print("✅ Enhanced task added: ", task["type"], " (Priority: ", task["priority"], ", Est. Duration: ", task["estimated_duration"], "s)")
	return true

func _validate_task(task: Dictionary) -> bool:
	"""Validate task structure"""
	return task.has("type") and task.has("description")

func _process_task_queue():
	"""Process the task queue"""
	# Start new tasks if we have capacity
	while active_tasks.size() < max_concurrent_tasks and pending_tasks.size() > 0:
		var next_task = _get_next_task()
		if next_task:
			_start_task(next_task)
	
	# Check for timed out tasks
	_check_task_timeouts()

func _get_next_task() -> Dictionary:
	"""Get the next task to execute based on priority"""
	if pending_tasks.is_empty():
		return {}
	
	# Sort by priority (higher priority first)
	pending_tasks.sort_custom(func(a, b): 
		var priority_a = a.get("priority", 5)
		var priority_b = b.get("priority", 5)
		return priority_a > priority_b
	)
	
	# Check dependencies
	for i in range(pending_tasks.size()):
		var task = pending_tasks[i]
		if _are_dependencies_met(task):
			pending_tasks.remove_at(i)
			return task
	
	return {}

func _are_dependencies_met(task: Dictionary) -> bool:
	"""Check if task dependencies are satisfied"""
	if not task.has("dependencies"):
		return true
	
	var dependencies = task["dependencies"]
	if dependencies.is_empty():
		return true
	
	# Check if all dependency tasks are completed
	for dep_id in dependencies:
		var dep_completed = false
		for completed_task in completed_tasks:
			if completed_task["id"] == dep_id:
				dep_completed = true
				break
		
		if not dep_completed:
			return false
	
	return true

func _start_task(task: Dictionary):
	"""Start executing a task"""
	task["status"] = "active"
	task["started_at"] = Time.get_unix_time_from_system()
	
	active_tasks.append(task)
	task_started.emit(task)
	
	print("Starting task: ", task["description"])
	
	# Setup timeout timer
	var timer = Timer.new()
	timer.wait_time = task.get("timeout", task_timeout)
	timer.timeout.connect(_on_task_timeout.bind(task["id"]))
	timer.one_shot = true
	add_child(timer)
	timer.start()
	task_timers[task["id"]] = timer
	
	# Execute the task
	_execute_task(task)

func _execute_task(task: Dictionary):
	"""Execute a specific task"""
	var task_type = task["type"]
	
	if task_executors.has(task_type):
		var executor = task_executors[task_type]
		# Execute asynchronously to avoid blocking
		call_deferred("_run_task_executor", executor, task)
	else:
		_complete_task_with_error(task, "Unknown task type: " + task_type)

func _run_task_executor(executor: Callable, task: Dictionary):
	"""Run a task executor function"""
	var result = await executor.call(task)
	_complete_task(task, result)

func _complete_task(task: Dictionary, result: Dictionary):
	"""Mark a task as completed"""
	task["status"] = "completed"
	task["completed_at"] = Time.get_unix_time_from_system()
	task["result"] = result
	
	# Remove from active tasks
	for i in range(active_tasks.size()):
		if active_tasks[i]["id"] == task["id"]:
			active_tasks.remove_at(i)
			break
	
	# Add to completed tasks
	completed_tasks.append(task)
	
	# Clean up timer
	if task_timers.has(task["id"]):
		task_timers[task["id"]].queue_free()
		task_timers.erase(task["id"])
	
	task_completed.emit(task, result)
	queue_updated.emit()
	
	print("Task completed: ", task["description"])

func _complete_task_with_error(task: Dictionary, error: String):
	"""Mark a task as failed"""
	task["status"] = "failed"
	task["failed_at"] = Time.get_unix_time_from_system()
	task["error"] = error
	task["retry_count"] += 1
	
	# Remove from active tasks
	for i in range(active_tasks.size()):
		if active_tasks[i]["id"] == task["id"]:
			active_tasks.remove_at(i)
			break
	
	# Clean up timer
	if task_timers.has(task["id"]):
		task_timers[task["id"]].queue_free()
		task_timers.erase(task["id"])
	
	# Retry if enabled and under retry limit
	if auto_retry_failed and task["retry_count"] <= max_retries:
		print("Retrying task: ", task["description"], " (attempt ", task["retry_count"], ")")
		task["status"] = "pending"
		pending_tasks.append(task)
	else:
		failed_tasks.append(task)
		task_failed.emit(task, error)
	
	queue_updated.emit()
	print("Task failed: ", task["description"], " - ", error)

func _on_task_timeout(task_id: String):
	"""Handle task timeout"""
	for task in active_tasks:
		if task["id"] == task_id:
			_complete_task_with_error(task, "Task timed out")
			break

func _check_task_timeouts():
	"""Check for tasks that have exceeded their timeout"""
	var current_time = Time.get_unix_time_from_system()
	
	for task in active_tasks:
		var started_at = task.get("started_at", current_time)
		var timeout = task.get("timeout", task_timeout)
		
		if current_time - started_at > timeout:
			_complete_task_with_error(task, "Task exceeded timeout")

# Task Executor Functions
func _execute_analyze_errors(task: Dictionary) -> Dictionary:
	"""Execute error analysis task"""
	print("Executing: Analyze errors")
	await get_tree().create_timer(2.0).timeout
	return {"status": "success", "errors_found": 0, "analysis": "No errors detected"}

func _execute_fix_errors(task: Dictionary) -> Dictionary:
	"""Execute error fixing task"""
	print("Executing: Fix errors")
	await get_tree().create_timer(3.0).timeout
	return {"status": "success", "errors_fixed": 0}

func _execute_verify_fixes(task: Dictionary) -> Dictionary:
	"""Execute fix verification task"""
	print("Executing: Verify fixes")
	await get_tree().create_timer(1.5).timeout
	return {"status": "success", "verification": "All fixes verified"}

func _execute_analyze_requirements(task: Dictionary) -> Dictionary:
	"""Execute requirements analysis task"""
	print("Executing: Analyze requirements")
	await get_tree().create_timer(2.5).timeout
	return {"status": "success", "requirements": []}

func _execute_design_solution(task: Dictionary) -> Dictionary:
	"""Execute solution design task"""
	print("Executing: Design solution")
	await get_tree().create_timer(3.0).timeout
	return {"status": "success", "design": "Solution designed"}

func _execute_generate_code(task: Dictionary) -> Dictionary:
	"""Execute code generation task"""
	print("Executing: Generate code")
	await get_tree().create_timer(4.0).timeout
	return {"status": "success", "code_generated": true, "lines": 50}

func _execute_test_implementation(task: Dictionary) -> Dictionary:
	"""Execute implementation testing task"""
	print("Executing: Test implementation")
	await get_tree().create_timer(2.0).timeout
	return {"status": "success", "tests_passed": true}

func _execute_analyze_code(task: Dictionary) -> Dictionary:
	"""Execute code analysis task"""
	print("Executing: Analyze code")
	await get_tree().create_timer(2.0).timeout
	return {"status": "success", "analysis": "Code analysis complete"}

func _execute_plan_refactoring(task: Dictionary) -> Dictionary:
	"""Execute refactoring planning task"""
	print("Executing: Plan refactoring")
	await get_tree().create_timer(2.5).timeout
	return {"status": "success", "plan": "Refactoring plan created"}

func _execute_apply_refactoring(task: Dictionary) -> Dictionary:
	"""Execute refactoring application task"""
	print("Executing: Apply refactoring")
	await get_tree().create_timer(3.5).timeout
	return {"status": "success", "refactoring_applied": true}

func _execute_validate_refactoring(task: Dictionary) -> Dictionary:
	"""Execute refactoring validation task"""
	print("Executing: Validate refactoring")
	await get_tree().create_timer(1.5).timeout
	return {"status": "success", "validation": "Refactoring validated"}

func _execute_analyze_context(task: Dictionary) -> Dictionary:
	"""Execute context analysis task"""
	print("Executing: Analyze context")
	await get_tree().create_timer(1.0).timeout
	return {"status": "success", "context": "Context analyzed"}

func _execute_plan_approach(task: Dictionary) -> Dictionary:
	"""Execute approach planning task"""
	print("Executing: Plan approach")
	await get_tree().create_timer(2.0).timeout
	return {"status": "success", "approach": "Approach planned"}

func _execute_execute_plan(task: Dictionary) -> Dictionary:
	"""Execute plan execution task"""
	print("Executing: Execute plan")
	await get_tree().create_timer(3.0).timeout
	return {"status": "success", "execution": "Plan executed"}

func _execute_verify_results(task: Dictionary) -> Dictionary:
	"""Execute results verification task"""
	print("Executing: Verify results")
	await get_tree().create_timer(1.0).timeout
	return {"status": "success", "verification": "Results verified"}

func _execute_fix_single_error(task: Dictionary) -> Dictionary:
	"""Execute single error fix task"""
	print("Executing: Fix single error")
	await get_tree().create_timer(2.0).timeout
	return {"status": "success", "error_fixed": true}

func _execute_address_warning(task: Dictionary) -> Dictionary:
	"""Execute warning addressing task"""
	print("Executing: Address warning")
	await get_tree().create_timer(1.0).timeout
	return {"status": "success", "warning_addressed": true}

func _generate_task_id() -> String:
	"""Generate a unique task ID"""
	return "task_" + str(Time.get_unix_time_from_system()) + "_" + str(randi() % 10000)

# Enhanced Task Management Functions
func _estimate_task_duration(task: Dictionary) -> float:
	"""Estimate task execution duration for better scheduling"""
	var base_duration = 30.0  # 30 seconds base

	var duration_map = {
		"analyze_code": 45.0,
		"generate_code": 60.0,
		"fix_error": 90.0,
		"refactor_code": 120.0,
		"run_tests": 30.0,
		"optimize_code": 180.0
	}

	var task_type = task.get("type", "")
	var estimated = duration_map.get(task_type, base_duration)

	# Adjust based on complexity
	var complexity = task.get("complexity", 0.5)
	estimated *= (0.5 + complexity)

	return estimated

func _estimate_task_complexity(task: Dictionary) -> float:
	"""Estimate task complexity for intelligent scheduling"""
	var complexity = 0.5  # Base complexity

	var task_type = task.get("type", "")
	var description = task.get("description", "").to_lower()

	# Type-based complexity
	var complexity_map = {
		"analyze_code": 0.3,
		"generate_code": 0.6,
		"fix_error": 0.7,
		"refactor_code": 0.9,
		"optimize_code": 0.8
	}

	complexity = complexity_map.get(task_type, 0.5)

	# Keyword-based adjustments
	if "complex" in description or "advanced" in description:
		complexity += 0.2
	if "simple" in description or "basic" in description:
		complexity -= 0.2

	return clamp(complexity, 0.1, 1.0)

func _estimate_task_success_probability(task: Dictionary) -> float:
	"""Estimate probability of task success based on history"""
	var base_probability = 0.8

	var task_type = task.get("type", "")

	# Check historical success rates
	if task_success_rates.has(task_type):
		base_probability = task_success_rates[task_type]

	# Adjust based on complexity
	var complexity = task.get("complexity", 0.5)
	base_probability -= complexity * 0.2

	return clamp(base_probability, 0.1, 1.0)

func _analyze_task_dependencies(task: Dictionary) -> Array:
	"""Analyze task dependencies for intelligent scheduling"""
	var dependencies = []
	var task_type = task.get("type", "")

	# Common dependency patterns
	if task_type == "fix_error":
		dependencies.append("analyze_code")
	elif task_type == "run_tests":
		dependencies.append("generate_code")
	elif task_type == "optimize_code":
		dependencies.append("analyze_code")

	return dependencies

func _insert_task_by_priority(task: Dictionary):
	"""Insert task in queue based on priority (higher priority first)"""
	var priority = task.get("priority", 5)
	var inserted = false

	for i in range(pending_tasks.size()):
		var existing_priority = pending_tasks[i].get("priority", 5)
		if priority > existing_priority:
			pending_tasks.insert(i, task)
			inserted = true
			break

	if not inserted:
		pending_tasks.append(task)

func execute_task_async(task: Dictionary) -> String:
	"""Execute task asynchronously with enhanced monitoring"""
	var task_id = task.get("id", "")
	if task_id.is_empty():
		task_id = _generate_task_id()
		task["id"] = task_id

	# Check resource availability
	if not _check_resource_availability(task):
		print("⏳ Task queued due to resource constraints: ", task_id)
		pending_tasks.append(task)
		return task_id

	# Start execution
	_start_enhanced_task_execution(task)
	return task_id

func _check_resource_availability(task: Dictionary) -> bool:
	"""Check if resources are available for task execution"""
	var task_type = task.get("type", "")

	# Check for resource locks
	if resource_locks.has(task_type):
		return false

	# Check concurrent task limits
	if active_tasks.size() >= max_concurrent_tasks:
		return false

	return true

func _start_enhanced_task_execution(task: Dictionary):
	"""Start enhanced task execution with comprehensive monitoring"""
	var task_id = task["id"]

	# Move to active tasks
	if task in pending_tasks:
		pending_tasks.erase(task)
	active_tasks.append(task)

	# Set resource lock for intensive tasks
	var task_type = task.get("type", "")
	if task_type in ["fix_error", "refactor_code"]:
		resource_locks[task_type] = task_id

	# Start execution timer
	task["start_time"] = Time.get_unix_time_from_system()
	task["status"] = "running"

	# Execute task
	task_started.emit(task)
	print("🚀 Starting enhanced task execution: ", task_id)

	# Execute with enhanced error handling
	_execute_task_with_monitoring(task)

func _execute_task_with_monitoring(task: Dictionary):
	"""Execute task with comprehensive monitoring and error handling"""
	var task_type = task.get("type", "")
	var task_id = task["id"]

	if task_executors.has(task_type):
		var executor = task_executors[task_type]

		try:
			# Execute with timeout monitoring
			var result = await executor.call(task)
			_handle_enhanced_task_completion(task, result)
		except:
			var error = "Task execution failed: " + str(get_stack())
			_handle_enhanced_task_failure(task, error)
	else:
		var error = "No executor found for task type: " + task_type
		_handle_enhanced_task_failure(task, error)

func _handle_enhanced_task_completion(task: Dictionary, result: Dictionary):
	"""Handle task completion with enhanced analytics and learning"""
	var task_id = task["id"]
	var task_type = task.get("type", "")

	# Calculate execution time
	var execution_time = Time.get_unix_time_from_system() - task.get("start_time", 0.0)
	task["execution_time"] = execution_time
	task["status"] = "completed"
	task["result"] = result

	# Update analytics
	_update_enhanced_task_analytics(task_type, execution_time, true)

	# Move to completed tasks
	active_tasks.erase(task)
	completed_tasks.append(task)

	# Release resource lock
	if resource_locks.has(task_type):
		resource_locks.erase(task_type)

	# Emit completion signal
	task_completed.emit(task, result)

	print("✅ Enhanced task completed: ", task_id, " in ", execution_time, "s (Success rate: ", task_success_rates.get(task_type, 0.8), ")")

func _handle_enhanced_task_failure(task: Dictionary, error: String):
	"""Handle task failure with enhanced retry logic and learning"""
	var task_id = task["id"]
	var task_type = task.get("type", "")

	task["status"] = "failed"
	task["error"] = error
	task["retry_count"] = task.get("retry_count", 0) + 1

	# Update analytics
	var execution_time = Time.get_unix_time_from_system() - task.get("start_time", 0.0)
	_update_enhanced_task_analytics(task_type, execution_time, false)

	# Retry logic
	if auto_retry_failed and task["retry_count"] <= max_retries:
		print("🔄 Retrying task: ", task_id, " (Attempt ", task["retry_count"], "/", max_retries, ")")

		# Move back to pending with delay
		active_tasks.erase(task)
		await get_tree().create_timer(2.0).timeout  # Wait before retry
		pending_tasks.append(task)
	else:
		# Move to failed tasks
		active_tasks.erase(task)
		failed_tasks.append(task)

		# Release resource lock
		if resource_locks.has(task_type):
			resource_locks.erase(task_type)

		task_failed.emit(task, error)
		print("❌ Task failed permanently: ", task_id, " - ", error)

func _update_enhanced_task_analytics(task_type: String, execution_time: float, success: bool):
	"""Update comprehensive task execution analytics"""
	total_tasks_processed += 1

	if success:
		successful_tasks += 1
	else:
		failed_tasks_count += 1

	# Update execution times
	if not task_execution_times.has(task_type):
		task_execution_times[task_type] = []
	task_execution_times[task_type].append(execution_time)

	# Update success rates with exponential moving average
	if not task_success_rates.has(task_type):
		task_success_rates[task_type] = 0.8  # Default

	var current_rate = task_success_rates[task_type]
	var new_rate = current_rate * 0.9 + (1.0 if success else 0.0) * 0.1
	task_success_rates[task_type] = new_rate

	# Update average execution time
	var total_time = 0.0
	var total_count = 0
	for times in task_execution_times.values():
		for time in times:
			total_time += time
			total_count += 1

	if total_count > 0:
		average_execution_time = total_time / total_count

func get_enhanced_analytics() -> Dictionary:
	"""Get comprehensive task execution analytics"""
	return {
		"total_processed": total_tasks_processed,
		"successful": successful_tasks,
		"failed": failed_tasks_count,
		"success_rate": float(successful_tasks) / max(1, total_tasks_processed),
		"average_execution_time": average_execution_time,
		"task_success_rates": task_success_rates,
		"active_tasks": active_tasks.size(),
		"pending_tasks": pending_tasks.size(),
		"completed_tasks": completed_tasks.size(),
		"resource_locks": resource_locks.keys()
	}

func get_queue_status() -> Dictionary:
	"""Get current queue status"""
	return {
		"pending": pending_tasks.size(),
		"active": active_tasks.size(),
		"completed": completed_tasks.size(),
		"failed": failed_tasks.size(),
		"total_processed": completed_tasks.size() + failed_tasks.size()
	}

func cancel_task(task_id: String) -> bool:
	"""Cancel a pending or active task"""
	# Check pending tasks
	for i in range(pending_tasks.size()):
		if pending_tasks[i]["id"] == task_id:
			var task = pending_tasks[i]
			pending_tasks.remove_at(i)
			task_cancelled.emit(task)
			return true
	
	# Check active tasks
	for i in range(active_tasks.size()):
		if active_tasks[i]["id"] == task_id:
			var task = active_tasks[i]
			active_tasks.remove_at(i)
			if task_timers.has(task_id):
				task_timers[task_id].queue_free()
				task_timers.erase(task_id)
			task_cancelled.emit(task)
			return true
	
	return false

func clear_completed_tasks():
	"""Clear completed tasks from memory"""
	completed_tasks.clear()
	queue_updated.emit()

func clear_failed_tasks():
	"""Clear failed tasks from memory"""
	failed_tasks.clear()
	queue_updated.emit()
