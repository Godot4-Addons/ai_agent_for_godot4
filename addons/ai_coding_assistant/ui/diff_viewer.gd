@tool
extends Window

signal changes_accepted(new_code: String)
signal changes_rejected()

var original_text: TextEdit
var modified_text: TextEdit
var diff_display: RichTextLabel
var accept_button: Button
var reject_button: Button

var original_code: String = ""
var new_code: String = ""

func _init():
	title = "Code Diff Viewer"
	size = Vector2(800, 600)
	_setup_ui()

func _setup_ui():
	var vbox = VBoxContainer.new()
	add_child(vbox)

	# Header
	var header = Label.new()
	header.text = "Review AI Generated Changes"
	header.add_theme_font_size_override("font_size", 16)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	# Split container for side-by-side view
	var hsplit = HSplitContainer.new()
	hsplit.custom_minimum_size = Vector2(0, 400)
	vbox.add_child(hsplit)

	# Original code panel
	var original_panel = VBoxContainer.new()
	var original_label = Label.new()
	original_label.text = "Original Code"
	original_label.add_theme_font_size_override("font_size", 14)
	original_panel.add_child(original_label)

	original_text = TextEdit.new()
	original_text.editable = false
	original_text.placeholder_text = "Original code will appear here..."
	original_panel.add_child(original_text)
	hsplit.add_child(original_panel)

	# Modified code panel
	var modified_panel = VBoxContainer.new()
	var modified_label = Label.new()
	modified_label.text = "AI Generated Code"
	modified_label.add_theme_font_size_override("font_size", 14)
	modified_panel.add_child(modified_label)

	modified_text = TextEdit.new()
	modified_text.editable = true
	modified_text.placeholder_text = "Modified code will appear here..."
	modified_panel.add_child(modified_text)
	hsplit.add_child(modified_panel)

	# Diff display
	var diff_label = Label.new()
	diff_label.text = "Changes Summary"
	diff_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(diff_label)

	diff_display = RichTextLabel.new()
	diff_display.custom_minimum_size = Vector2(0, 150)
	diff_display.bbcode_enabled = true
	vbox.add_child(diff_display)

	# Buttons
	var button_hbox = HBoxContainer.new()
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	accept_button = Button.new()
	accept_button.text = "Accept Changes"
	accept_button.pressed.connect(_on_accept_pressed)

	reject_button = Button.new()
	reject_button.text = "Reject Changes"
	reject_button.pressed.connect(_on_reject_pressed)

	var edit_button = Button.new()
	edit_button.text = "Edit & Accept"
	edit_button.pressed.connect(_on_edit_accept_pressed)

	button_hbox.add_child(reject_button)
	button_hbox.add_child(edit_button)
	button_hbox.add_child(accept_button)
	vbox.add_child(button_hbox)

func show_diff(original: String, modified: String):
	original_code = original
	new_code = modified

	original_text.text = original
	modified_text.text = modified

	_generate_diff_display()
	popup_centered()

func _generate_diff_display():
	diff_display.clear()

	var original_lines = original_code.split("\n")
	var modified_lines = new_code.split("\n")

	var diff_result = _compute_diff(original_lines, modified_lines)

	diff_display.append_text("[b]Changes Summary:[/b]\n\n")

	var additions = 0
	var deletions = 0
	var modifications = 0

	for change in diff_result:
		match change.type:
			"add":
				additions += 1
				diff_display.append_text("[color=green]+ " + change.text + "[/color]\n")
			"remove":
				deletions += 1
				diff_display.append_text("[color=red]- " + change.text + "[/color]\n")
			"modify":
				modifications += 1
				diff_display.append_text("[color=yellow]~ " + change.text + "[/color]\n")

	diff_display.append_text("\n[b]Statistics:[/b]\n")
	diff_display.append_text("[color=green]Additions: " + str(additions) + "[/color]\n")
	diff_display.append_text("[color=red]Deletions: " + str(deletions) + "[/color]\n")
	diff_display.append_text("[color=yellow]Modifications: " + str(modifications) + "[/color]\n")

func _compute_diff(original_lines: PackedStringArray, modified_lines: PackedStringArray) -> Array:
	var diff_result = []

	# Simple line-by-line diff algorithm
	var i = 0  # original index
	var j = 0  # modified index

	while i < original_lines.size() or j < modified_lines.size():
		if i >= original_lines.size():
			# Remaining lines are additions
			diff_result.append({"type": "add", "text": modified_lines[j]})
			j += 1
		elif j >= modified_lines.size():
			# Remaining lines are deletions
			diff_result.append({"type": "remove", "text": original_lines[i]})
			i += 1
		elif original_lines[i] == modified_lines[j]:
			# Lines are the same, skip
			i += 1
			j += 1
		else:
			# Lines are different, determine if it's a modification, addition, or deletion
			var found_match = false

			# Look ahead to see if this line appears later in modified
			for k in range(j + 1, min(j + 5, modified_lines.size())):
				if original_lines[i] == modified_lines[k]:
					# This line was moved or there were insertions
					for l in range(j, k):
						diff_result.append({"type": "add", "text": modified_lines[l]})
					j = k
					found_match = true
					break

			if not found_match:
				# Look ahead to see if the modified line appears later in original
				var found_in_original = false
				for k in range(i + 1, min(i + 5, original_lines.size())):
					if modified_lines[j] == original_lines[k]:
						# This line was moved or there were deletions
						for l in range(i, k):
							diff_result.append({"type": "remove", "text": original_lines[l]})
						i = k
						found_in_original = true
						break

				if not found_in_original:
					# This is a modification
					diff_result.append({"type": "modify", "text": "'" + original_lines[i] + "' -> '" + modified_lines[j] + "'"})
					i += 1
					j += 1

	return diff_result

func _on_accept_pressed():
	changes_accepted.emit(modified_text.text)
	hide()

func _on_reject_pressed():
	changes_rejected.emit()
	hide()

func _on_edit_accept_pressed():
	# Allow user to edit the modified code before accepting
	modified_text.editable = true
	modified_text.grab_focus()

	# Update the diff when text changes
	modified_text.text_changed.connect(_on_modified_text_changed)

func _on_modified_text_changed():
	new_code = modified_text.text
	_generate_diff_display()
