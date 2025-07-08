@tool
extends RefCounted
class_name ChatMessage

# Chat Message Data Model
# Represents a single message in the AI assistant chat

var sender: String = ""
var content: String = ""
var timestamp: float = 0.0
var message_type: String = "text"  # text, code, system, error
var color: Color = Color.WHITE
var metadata: Dictionary = {}

func _init(p_sender: String = "", p_content: String = "", p_color: Color = Color.WHITE, p_type: String = "text"):
	sender = p_sender
	content = p_content
	color = p_color
	message_type = p_type
	timestamp = Time.get_unix_time_from_system()

func to_dict() -> Dictionary:
	"""Convert message to dictionary for serialization"""
	return {
		"sender": sender,
		"content": content,
		"timestamp": timestamp,
		"message_type": message_type,
		"color": {
			"r": color.r,
			"g": color.g,
			"b": color.b,
			"a": color.a
		},
		"metadata": metadata
	}

static func from_dict(data: Dictionary) -> ChatMessage:
	"""Create message from dictionary"""
	var message = ChatMessage.new()
	message.sender = data.get("sender", "")
	message.content = data.get("content", "")
	message.timestamp = data.get("timestamp", 0.0)
	message.message_type = data.get("message_type", "text")
	
	var color_data = data.get("color", {})
	message.color = Color(
		color_data.get("r", 1.0),
		color_data.get("g", 1.0),
		color_data.get("b", 1.0),
		color_data.get("a", 1.0)
	)
	
	message.metadata = data.get("metadata", {})
	return message

func get_formatted_timestamp() -> String:
	"""Get formatted timestamp string"""
	var datetime = Time.get_datetime_dict_from_unix_time(timestamp)
	return "%02d:%02d:%02d" % [datetime.hour, datetime.minute, datetime.second]

func is_code_message() -> bool:
	"""Check if this is a code message"""
	return message_type == "code" or content.begins_with("```")

func is_system_message() -> bool:
	"""Check if this is a system message"""
	return message_type == "system" or sender == "System"

func is_error_message() -> bool:
	"""Check if this is an error message"""
	return message_type == "error" or color == Color.RED

func get_display_text() -> String:
	"""Get text for display in chat"""
	var time_str = get_formatted_timestamp()
	return "[%s] %s: %s" % [time_str, sender, content]
