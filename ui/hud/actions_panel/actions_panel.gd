extends PanelContainer

signal action_pressed(action_name: String)

@onready var _container: VBoxContainer = $VBoxContainer

const _COLOR_TEXT := Color(0.6705882, 0.5803922, 0.4784314)
const _COLOR_HOVER := Color(0.56078434, 0.827451, 1.0)


func show_actions(actions: PackedStringArray) -> void:
	for child in _container.get_children():
		child.queue_free()
	for action in actions:
		_container.add_child(_make_button(action))
	visible = not actions.is_empty()


func clear() -> void:
	hide()


func _make_button(action: String) -> Button:
	var btn := Button.new()
	btn.text = action
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.add_theme_color_override("font_color", _COLOR_TEXT)
	btn.add_theme_color_override("font_hover_color", _COLOR_HOVER)
	btn.add_theme_color_override("font_pressed_color", _COLOR_HOVER)
	btn.add_theme_color_override("font_focus_color", _COLOR_TEXT)
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, empty)
	btn.pressed.connect(func() -> void: action_pressed.emit(action))
	return btn
