extends PanelContainer

var _dragging := false
var _drag_offset := Vector2.ZERO

@onready var _title_bar: HBoxContainer = $VBoxContainer/TitleBar
@onready var _close_btn: Button = $VBoxContainer/TitleBar/CloseButton


func _ready() -> void:
	_title_bar.gui_input.connect(_on_title_bar_input)
	_close_btn.pressed.connect(close)
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		_close_btn.add_theme_stylebox_override(state, empty)
	_close_btn.add_theme_color_override("font_color", Color(0.6705882, 0.5803922, 0.4784314))
	_close_btn.add_theme_color_override("font_hover_color", Color(0.56078434, 0.827451, 1.0))


func open() -> void:
	show()
	move_to_front()


func close() -> void:
	hide()


func _on_title_bar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if _dragging:
			_drag_offset = get_global_mouse_position() - global_position
	elif event is InputEventMouseMotion and _dragging:
		global_position = get_global_mouse_position() - _drag_offset
