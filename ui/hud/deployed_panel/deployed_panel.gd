extends PanelContainer

signal unit_selected(unit: Unit)

const _CATEGORIES: Array = [
	["unit_maritime", "SEA"],
	["unit_air", "AIR"],
	["unit_ground", "GND"],
]

const _COLOR_TEXT   := Color(0.6705882, 0.5803922, 0.4784314)
const _COLOR_ACCENT := Color(0.56078434, 0.827451, 1.0)
const _COLOR_DIM    := Color(0.6705882, 0.5803922, 0.4784314, 0.4)

var _rows: Array = []   # un HBoxContainer por categoría
var _dirty := true


func _ready() -> void:
	_build_layout()
	get_tree().node_added.connect(_on_tree_changed)
	get_tree().node_removed.connect(_on_tree_changed)


func _process(_delta: float) -> void:
	if not _dirty:
		return
	_dirty = false
	_refresh()


func _on_tree_changed(node: Node) -> void:
	if node is Unit:
		_dirty = true


func _build_layout() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.192, 0.212, 0.220, 0.88)
	bg.border_color = Color(0.561, 0.827, 1.0, 0.2)
	bg.set_border_width_all(1)
	bg.content_margin_left = 3.0
	bg.content_margin_right = 3.0
	bg.content_margin_top = 2.0
	bg.content_margin_bottom = 2.0
	add_theme_stylebox_override("panel", bg)

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	add_child(root)

	for i in _CATEGORIES.size():
		if i > 0:
			var sep := VSeparator.new()
			var ss := StyleBoxFlat.new()
			ss.bg_color = Color(0.561, 0.827, 1.0, 0.18)
			sep.add_theme_stylebox_override("separator", ss)
			root.add_child(sep)

		var group_box := HBoxContainer.new()
		group_box.add_theme_constant_override("separation", 3)
		root.add_child(group_box)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		group_box.add_child(row)
		_rows.append(row)


func _refresh() -> void:
	for i in _rows.size():
		var row: HBoxContainer = _rows[i]
		for child in row.get_children():
			child.free()
		var group: String = _CATEGORIES[i][0]
		for node: Node in get_tree().get_nodes_in_group(group):
			if is_instance_valid(node):
				row.add_child(_make_btn(node as Unit))


func _make_btn(unit: Unit) -> Button:
	var btn := Button.new()
	# primer token del nombre como etiqueta compacta
	btn.text = unit.get_display_name().split(" ")[0]
	btn.clip_text = true
	btn.custom_minimum_size = Vector2(30, 14)

	var normal_box := StyleBoxFlat.new()
	normal_box.bg_color = Color(0.192, 0.212, 0.220)
	normal_box.border_color = Color(0.561, 0.827, 1.0, 0.35)
	normal_box.set_border_width_all(1)
	normal_box.set_content_margin_all(2)

	var hover_box := StyleBoxFlat.new()
	hover_box.bg_color = Color(0.192, 0.212, 0.220)
	hover_box.border_color = _COLOR_ACCENT
	hover_box.set_border_width_all(1)
	hover_box.set_content_margin_all(2)

	for state in ["normal", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, normal_box)
	for state in ["hover", "pressed"]:
		btn.add_theme_stylebox_override(state, hover_box)

	btn.add_theme_color_override("font_color", _COLOR_TEXT)
	btn.add_theme_color_override("font_hover_color", _COLOR_ACCENT)
	btn.add_theme_color_override("font_pressed_color", _COLOR_ACCENT)

	btn.pressed.connect(func() -> void:
		if is_instance_valid(unit):
			unit_selected.emit(unit)
	)
	return btn
