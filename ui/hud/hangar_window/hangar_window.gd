extends PanelContainer

const _COLOR_TEXT   := Color(0.6705882, 0.5803922, 0.4784314)
const _COLOR_ACCENT := Color(0.56078434, 0.827451, 1.0)
const _COLOR_MUTED  := Color(0.6705882, 0.5803922, 0.4784314, 0.4)
const _COLOR_BG     := Color(0.19215686, 0.21176471, 0.21960784)
const _MISSIONS     := ["SEAD", "CAP", "CAS"]

var _dragging          := false
var _drag_offset       := Vector2.ZERO
var _ship              : Node2D   = null
var _selected_entry    : Dictionary = {}
var _selected_unit_btn : Button   = null
var _quantity          := 1
var _selected_mission  := ""
var _mission_buttons   : Array[Button] = []

@onready var _title_bar   : HBoxContainer = $VBoxContainer/TitleBar
@onready var _close_btn   : Button        = $VBoxContainer/TitleBar/CloseButton
@onready var _unit_list   : HBoxContainer = $VBoxContainer/UnitList
@onready var _minus_btn   : Button        = $VBoxContainer/QuantityRow/MinusBtn
@onready var _count_lbl   : Label         = $VBoxContainer/QuantityRow/CountLabel
@onready var _plus_btn    : Button        = $VBoxContainer/QuantityRow/PlusBtn
@onready var _mission_row : HBoxContainer = $VBoxContainer/MissionRow
@onready var _deploy_btn  : Button        = $VBoxContainer/DeployBtn


func _ready() -> void:
	_title_bar.gui_input.connect(_on_title_bar_input)
	_close_btn.pressed.connect(close)
	_minus_btn.pressed.connect(_on_minus)
	_plus_btn.pressed.connect(_on_plus)
	_deploy_btn.pressed.connect(_on_deploy)
	_style_flat(_close_btn)
	_style_flat(_minus_btn)
	_style_flat(_plus_btn)
	_style_flat(_deploy_btn)
	_deploy_btn.add_theme_color_override("font_color", _COLOR_ACCENT)
	_build_mission_buttons()


func open(ship: Node2D) -> void:
	_ship = ship
	_selected_entry    = {}
	_selected_unit_btn = null
	_quantity          = 1
	_selected_mission  = ""
	_count_lbl.text    = "1"
	_minus_btn.disabled = true
	_plus_btn.disabled  = false
	_update_mission_display()
	_refresh_unit_list()
	show()
	move_to_front()


func close() -> void:
	hide()


# ── unidades ─────────────────────────────────────────────────────────────────

func _refresh_unit_list() -> void:
	for child in _unit_list.get_children():
		child.queue_free()
	_selected_unit_btn = null
	for entry in PlayerFleet.get_loadout(_ship.unit_name):
		_unit_list.add_child(_make_unit_btn(entry))


func _make_unit_btn(entry: Dictionary) -> Button:
	var available: int = entry["total"] - entry["deployed"]
	var btn := Button.new()
	btn.text = "%s\n%d/%d" % [entry["display_name"], available, entry["total"]]
	btn.disabled = available <= 0
	_style_unit_btn(btn, false)
	btn.pressed.connect(_on_unit_selected.bind(entry, btn))
	return btn


func _on_unit_selected(entry: Dictionary, btn: Button) -> void:
	if _selected_unit_btn:
		_style_unit_btn(_selected_unit_btn, false)
	_selected_unit_btn = btn
	_style_unit_btn(btn, true)
	_selected_entry = entry
	_quantity = 1
	_update_quantity()


# ── cantidad ─────────────────────────────────────────────────────────────────

func _on_minus() -> void:
	_quantity = max(1, _quantity - 1)
	_update_quantity()


func _on_plus() -> void:
	var avail: int = _selected_entry.get("total", 1) - _selected_entry.get("deployed", 0)
	_quantity = min(avail, _quantity + 1)
	_update_quantity()


func _update_quantity() -> void:
	_count_lbl.text = str(_quantity)
	var avail: int = _selected_entry.get("total", 0) - _selected_entry.get("deployed", 0)
	_minus_btn.disabled = _quantity <= 1
	_plus_btn.disabled  = _quantity >= avail or avail <= 0


# ── misión ───────────────────────────────────────────────────────────────────

func _build_mission_buttons() -> void:
	for mission in _MISSIONS:
		var btn := Button.new()
		btn.text = mission
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_flat(btn)
		btn.pressed.connect(_on_mission_pressed.bind(mission))
		_mission_row.add_child(btn)
		_mission_buttons.append(btn)


func _on_mission_pressed(mission: String) -> void:
	_selected_mission = mission
	_update_mission_display()


func _update_mission_display() -> void:
	for btn in _mission_buttons:
		var c := _COLOR_ACCENT if btn.text == _selected_mission else _COLOR_TEXT
		btn.add_theme_color_override("font_color", c)


# ── despliegue ───────────────────────────────────────────────────────────────

func _on_deploy() -> void:
	if _selected_entry.is_empty() or _selected_mission.is_empty():
		return
	for i in _quantity:
		if not PlayerFleet.try_deploy(_selected_entry):
			break
		var instance: Node2D = _selected_entry["scene"].instantiate()
		get_tree().current_scene.add_child(instance)
		instance.global_position = _ship.global_position
	_selected_entry    = {}
	_selected_unit_btn = null
	_quantity          = 1
	_update_quantity()
	_refresh_unit_list()


# ── drag ─────────────────────────────────────────────────────────────────────

func _on_title_bar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if _dragging:
			_drag_offset = get_global_mouse_position() - global_position
	elif event is InputEventMouseMotion and _dragging:
		global_position = get_global_mouse_position() - _drag_offset


# ── estilos ──────────────────────────────────────────────────────────────────

func _style_unit_btn(btn: Button, selected: bool) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = _COLOR_BG
		box.set_border_width_all(1)
		box.border_color = Color(_COLOR_ACCENT, 1.0 if (selected or state in ["hover","pressed"]) else 0.35)
		box.set_content_margin_all(4)
		btn.add_theme_stylebox_override(state, box)
	var dis := StyleBoxFlat.new()
	dis.bg_color = Color(_COLOR_BG, 0.5)
	dis.set_border_width_all(1)
	dis.border_color = Color(_COLOR_ACCENT, 0.15)
	dis.set_content_margin_all(4)
	btn.add_theme_stylebox_override("disabled", dis)
	btn.add_theme_color_override("font_color", _COLOR_ACCENT if selected else _COLOR_TEXT)
	btn.add_theme_color_override("font_hover_color", _COLOR_ACCENT)
	btn.add_theme_color_override("font_pressed_color", _COLOR_ACCENT)
	btn.add_theme_color_override("font_disabled_color", _COLOR_MUTED)


func _style_flat(btn: Button) -> void:
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, empty)
	btn.add_theme_color_override("font_color", _COLOR_TEXT)
	btn.add_theme_color_override("font_hover_color", _COLOR_ACCENT)
	btn.add_theme_color_override("font_pressed_color", _COLOR_ACCENT)
	btn.add_theme_color_override("font_disabled_color", _COLOR_MUTED)
