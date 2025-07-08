@tool
extends RefCounted
class_name ContextManager

# Enhanced Context Manager for AI Agent
# Manages conversation context, memory, and intelligent context compression

signal context_updated(context_info: Dictionary)
signal context_compressed(original_size: int, compressed_size: int)
signal memory_threshold_reached(current_size: int, max_size: int)

# Context storage
var conversation_history: Array = []
var system_context: String = ""
var project_context: Dictionary = {}
var code_context: Dictionary = {}

# Context limits and management
var max_context_tokens: int = 8000
var max_history_messages: int = 50
var compression_threshold: float = 0.8  # Compress when 80% full
var smart_pruning_enabled: bool = true
var context_summarization_enabled: bool = true

# Context types and priorities
var context_priorities: Dictionary = {
	"system": 10,
	"error": 9,
	"code": 8,
	"user": 7,
	"assistant": 6,
	"context": 5,
	"summary": 4
}

# Memory and learning
var important_patterns: Array = []
var frequent_topics: Dictionary = {}
var user_preferences: Dictionary = {}

func _init():
	_setup_default_context()

func _setup_default_context():
	"""Setup default system context for the AI agent"""
	system_context = """You are an advanced AI coding agent for Godot 4. You have the following capabilities:

CORE ABILITIES:
- Autonomous error detection and fixing
- Real-time terminal monitoring
- Intelligent task management
- Advanced codebase analysis
- Learning from experience

GODOT EXPERTISE:
- GDScript 2.0 syntax and best practices
- Godot 4.x API and node system
- Game development patterns
- Performance optimization
- Scene management and signals

AGENT BEHAVIOR:
- Be proactive in identifying and solving problems
- Provide clear, actionable solutions
- Learn from user feedback and patterns
- Maintain context across conversations
- Focus on code quality and best practices

Always provide practical, working solutions with proper GDScript syntax."""

func add_message(role: String, content: String, message_type: String = "text", metadata: Dictionary = {}) -> Dictionary:
	"""Add a message to conversation history with intelligent management"""
	var message = {
		"role": role,
		"content": content,
		"type": message_type,
		"timestamp": Time.get_unix_time_from_system(),
		"tokens": _estimate_tokens(content),
		"priority": context_priorities.get(message_type, 5),
		"metadata": metadata
	}
	
	conversation_history.append(message)
	
	# Update topic frequency
	_update_topic_frequency(content)
	
	# Check if context management is needed
	if _should_manage_context():
		_manage_context()
	
	context_updated.emit(_get_context_info())
	return message

func get_context_for_ai(include_system: bool = true) -> Array:
	"""Get optimized context for AI API calls"""
	var context = []
	
	# Add system context if requested
	if include_system and not system_context.is_empty():
		context.append({
			"role": "system",
			"content": _build_enhanced_system_context()
		})
	
	# Add conversation history (already optimized)
	for message in conversation_history:
		context.append({
			"role": message["role"],
			"content": message["content"]
		})
	
	return context

func _build_enhanced_system_context() -> String:
	"""Build enhanced system context with project and code information"""
	var enhanced_context = system_context
	
	# Add project context
	if not project_context.is_empty():
		enhanced_context += "\n\nPROJECT CONTEXT:\n"
		if project_context.has("name"):
			enhanced_context += "- Project: " + str(project_context["name"]) + "\n"
		if project_context.has("type"):
			enhanced_context += "- Type: " + str(project_context["type"]) + "\n"
		if project_context.has("current_file"):
			enhanced_context += "- Current file: " + str(project_context["current_file"]) + "\n"
	
	# Add code context
	if not code_context.is_empty():
		enhanced_context += "\nCODE CONTEXT:\n"
		if code_context.has("current_function"):
			enhanced_context += "- Current function: " + str(code_context["current_function"]) + "\n"
		if code_context.has("selected_code"):
			enhanced_context += "- Selected code: " + str(code_context["selected_code"]) + "\n"
		if code_context.has("recent_errors"):
			enhanced_context += "- Recent errors: " + str(code_context["recent_errors"]) + "\n"
	
	# Add user preferences
	if not user_preferences.is_empty():
		enhanced_context += "\nUSER PREFERENCES:\n"
		for key in user_preferences:
			enhanced_context += "- " + str(key) + ": " + str(user_preferences[key]) + "\n"
	
	return enhanced_context

func update_project_context(context: Dictionary):
	"""Update project-specific context"""
	project_context.merge(context, true)
	context_updated.emit(_get_context_info())

func update_code_context(context: Dictionary):
	"""Update code-specific context"""
	code_context.merge(context, true)
	context_updated.emit(_get_context_info())

func update_user_preferences(preferences: Dictionary):
	"""Update user preferences"""
	user_preferences.merge(preferences, true)
	context_updated.emit(_get_context_info())

func _should_manage_context() -> bool:
	"""Check if context management is needed"""
	var current_tokens = _calculate_total_tokens()
	var threshold = max_context_tokens * compression_threshold
	
	return current_tokens > threshold or conversation_history.size() > max_history_messages

func _manage_context():
	"""Intelligently manage context size"""
	var original_size = conversation_history.size()
	
	if smart_pruning_enabled:
		_smart_prune_context()
	else:
		_simple_prune_context()
	
	if context_summarization_enabled:
		_summarize_old_context()
	
	var new_size = conversation_history.size()
	if new_size < original_size:
		context_compressed.emit(original_size, new_size)

func _smart_prune_context():
	"""Intelligently prune context based on importance and relevance"""
	if conversation_history.size() <= 10:  # Keep minimum context
		return
	
	# Sort messages by importance score
	var scored_messages = []
	for i in range(conversation_history.size()):
		var message = conversation_history[i]
		var score = _calculate_message_importance(message, i)
		scored_messages.append({"message": message, "score": score, "index": i})
	
	# Sort by score (highest first)
	scored_messages.sort_custom(func(a, b): return a["score"] > b["score"])
	
	# Keep top messages within token limit
	var new_history = []
	var token_count = 0
	var target_tokens = max_context_tokens * 0.6  # Use 60% of max tokens
	
	for item in scored_messages:
		var message = item["message"]
		if token_count + message["tokens"] <= target_tokens:
			new_history.append(message)
			token_count += message["tokens"]
	
	# Sort by original order
	new_history.sort_custom(func(a, b): return a["timestamp"] < b["timestamp"])
	conversation_history = new_history

func _simple_prune_context():
	"""Simple context pruning - remove oldest messages"""
	var target_size = max_history_messages * 0.7  # Keep 70% of max
	while conversation_history.size() > target_size:
		conversation_history.remove_at(0)

func _calculate_message_importance(message: Dictionary, index: int) -> float:
	"""Calculate importance score for a message"""
	var score = 0.0
	
	# Base priority from message type
	score += message["priority"] * 10
	
	# Recency bonus (more recent = higher score)
	var recency_factor = float(index) / conversation_history.size()
	score += recency_factor * 20
	
	# Content relevance
	if _contains_code(message["content"]):
		score += 15
	
	if _contains_error_keywords(message["content"]):
		score += 25
	
	# User messages are important
	if message["role"] == "user":
		score += 10
	
	# System messages are very important
	if message["role"] == "system":
		score += 30
	
	return score

func _contains_code(content: String) -> bool:
	"""Check if content contains code"""
	var code_indicators = ["func ", "var ", "class ", "extends ", "signal ", "```"]
	for indicator in code_indicators:
		if indicator in content:
			return true
	return false

func _contains_error_keywords(content: String) -> bool:
	"""Check if content contains error-related keywords"""
	var error_keywords = ["error", "exception", "failed", "bug", "issue", "problem", "fix"]
	var lower_content = content.to_lower()
	for keyword in error_keywords:
		if keyword in lower_content:
			return true
	return false

func _summarize_old_context():
	"""Create summaries of old context to preserve important information"""
	# This would use AI to summarize old conversations
	# For now, we'll create a simple summary
	if conversation_history.size() > 20:
		var old_messages = conversation_history.slice(0, 10)
		var summary = _create_simple_summary(old_messages)
		
		# Replace old messages with summary
		conversation_history = conversation_history.slice(10)
		if not summary.is_empty():
			conversation_history.insert(0, {
				"role": "system",
				"content": "Previous conversation summary: " + summary,
				"type": "summary",
				"timestamp": Time.get_unix_time_from_system(),
				"tokens": _estimate_tokens(summary),
				"priority": context_priorities["summary"],
				"metadata": {"is_summary": true}
			})

func _create_simple_summary(messages: Array) -> String:
	"""Create a simple summary of messages"""
	var topics = []
	var errors = []
	var solutions = []
	
	for message in messages:
		var content = message["content"].to_lower()
		if "error" in content or "problem" in content:
			errors.append(message["content"].substr(0, 100))
		elif "solution" in content or "fix" in content:
			solutions.append(message["content"].substr(0, 100))
	
	var summary = ""
	if not errors.is_empty():
		summary += "Errors discussed: " + ", ".join(errors) + ". "
	if not solutions.is_empty():
		summary += "Solutions provided: " + ", ".join(solutions) + ". "
	
	return summary

func _update_topic_frequency(content: String):
	"""Update frequency tracking for topics"""
	var words = content.to_lower().split(" ")
	for word in words:
		if word.length() > 3:  # Only track meaningful words
			frequent_topics[word] = frequent_topics.get(word, 0) + 1

func _estimate_tokens(text: String) -> int:
	"""Estimate token count for text (rough approximation)"""
	# Rough estimation: 1 token ≈ 4 characters for English text
	return max(1, text.length() / 4)

func _calculate_total_tokens() -> int:
	"""Calculate total tokens in conversation history"""
	var total = 0
	for message in conversation_history:
		total += message["tokens"]
	return total

func _get_context_info() -> Dictionary:
	"""Get current context information"""
	return {
		"message_count": conversation_history.size(),
		"total_tokens": _calculate_total_tokens(),
		"max_tokens": max_context_tokens,
		"utilization": float(_calculate_total_tokens()) / max_context_tokens,
		"project_context": project_context,
		"code_context": code_context,
		"user_preferences": user_preferences
	}

func clear_context():
	"""Clear conversation history while preserving system context"""
	conversation_history.clear()
	context_updated.emit(_get_context_info())

func export_context() -> Dictionary:
	"""Export context for persistence"""
	return {
		"conversation_history": conversation_history,
		"project_context": project_context,
		"code_context": code_context,
		"user_preferences": user_preferences,
		"frequent_topics": frequent_topics
	}

func import_context(data: Dictionary):
	"""Import context from saved data"""
	if data.has("conversation_history"):
		conversation_history = data["conversation_history"]
	if data.has("project_context"):
		project_context = data["project_context"]
	if data.has("code_context"):
		code_context = data["code_context"]
	if data.has("user_preferences"):
		user_preferences = data["user_preferences"]
	if data.has("frequent_topics"):
		frequent_topics = data["frequent_topics"]
	
	context_updated.emit(_get_context_info())
