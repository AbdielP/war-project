extends PanelContainer

const MAX_LINES = 4
const TEXT_COLOR = Color(0.6705882, 0.5803922, 0.4784314, 1)

@onready var lines: VBoxContainer = $Lines


func add_event(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", TEXT_COLOR)
	lines.add_child(label)
	if lines.get_child_count() > MAX_LINES:
		lines.get_child(0).queue_free()
