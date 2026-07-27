extends PanelContainer

const _COLOR_TEXT := Color(0.6705882, 0.5803922, 0.4784314)
const _COLOR_ACCENT := Color(0.56078434, 0.827451, 1.0)

var _dragging := false
var _drag_offset := Vector2.ZERO
var _ship: Node2D = null

@onready var _title_bar: HBoxContainer = $VBoxContainer/TitleBar
@onready var _close_btn: Button = $VBoxContainer/TitleBar/CloseButton
@onready var _content: VBoxContainer = $VBoxContainer/Content


func _ready() -> void:
	_title_bar.gui_input.connect(_on_title_bar_input)
	_close_btn.pressed.connect(close)
	_style_button(_close_btn)


func open(ship: Node2D) -> void:
	_ship = ship
	_refresh()
	show()
	move_to_front()


func close() -> void:
	hide()


func _refresh() -> void:
	for child in _content.get_children():
		child.queue_free()
	if _ship == null:
		return
	var loadout := PlayerFleet.get_loadout(_ship.unit_name)
	for entry in loadout:
		_content.add_child(_make_entry(entry))


func _make_entry(entry: Dictionary) -> HBoxContainer:
	var available: int = entry["total"] - entry["deployed"]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var lbl := Label.new()
	lbl.text = "%s  %d/%d" % [entry["display_name"], available, entry["total"]]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_color_override("font_color", _COLOR_TEXT)
	row.add_child(lbl)

	var btn := Button.new()
	btn.text = "▶"
	btn.disabled = available <= 0
	_style_button(btn)
	btn.pressed.connect(_on_deploy.bind(entry, lbl))
	row.add_child(btn)

	return row


func _on_deploy(entry: Dictionary, lbl: Label) -> void:
	if not PlayerFleet.try_deploy(entry):
		return
	var instance: Node2D = entry["scene"].instantiate()
	get_tree().current_scene.add_child(instance)
	instance.global_position = _ship.global_position
	var available: int = entry["total"] - entry["deployed"]
	lbl.text = "%s  %d/%d" % [entry["display_name"], available, entry["total"]]


func _style_button(btn: Button) -> void:
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, empty)
	btn.add_theme_color_override("font_color", _COLOR_TEXT)
	btn.add_theme_color_override("font_hover_color", _COLOR_ACCENT)
	btn.add_theme_color_override("font_pressed_color", _COLOR_ACCENT)
	btn.add_theme_color_override("font_disabled_color", Color(_COLOR_TEXT, 0.4))


func _on_title_bar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if _dragging:
			_drag_offset = get_global_mouse_position() - global_position
	elif event is InputEventMouseMotion and _dragging:
		global_position = get_global_mouse_position() - _drag_offset
