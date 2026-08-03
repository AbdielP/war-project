extends PanelContainer

## Menú contextual sobre una unidad ajena: se abre con click derecho (PC) o
## pulsación mantenida (táctil). El click izquierdo se deja libre para atacar,
## que es la acción frecuente; un menú a un click de distancia mataría el ritmo.
##
## Sólo ofrece opciones y avisa cuál se eligió. No ataca ni consulta nada.

signal attack_requested(target: Unit)
signal info_requested(target: Unit)

const _COLOR_TEXT   := Color(0.6705882, 0.5803922, 0.4784314)
const _COLOR_ACCENT := Color(0.56078434, 0.827451, 1.0)
const _COLOR_BG     := Color(0.19215686, 0.21176471, 0.21960784)

## Separación entre el menú y la unidad, para que no la tape.
const _OFFSET := Vector2(10, -6)
const _MARGIN := 2.0
const _FONT_SIZE := 8

var _target: Unit = null

@onready var _items: VBoxContainer = $Items


func _ready() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = _COLOR_BG
	box.set_border_width_all(1)
	box.border_color = Color(_COLOR_ACCENT, 0.5)
	box.set_content_margin_all(2)
	add_theme_stylebox_override("panel", box)
	hide()


## `can_attack` lo decide quien abre el menú: aquí no se sabe si hay una unidad
## propia seleccionada ni si es hostil.
func open(target: Unit, screen_position: Vector2, can_attack: bool) -> void:
	if not is_instance_valid(target):
		return
	_target = target
	for child in _items.get_children():
		_items.remove_child(child)
		child.queue_free()

	if can_attack:
		_items.add_child(_make_item("Atacar", func() -> void:
			attack_requested.emit(_target)
			close()))
	_items.add_child(_make_item("Información", func() -> void:
		info_requested.emit(_target)
		close()))
	_items.add_child(_make_item("Cerrar", close))

	show()
	# El tamaño no es fiable hasta que el contenedor se recoloca.
	await get_tree().process_frame
	if visible:
		_place_at(screen_position)


func close() -> void:
	_target = null
	hide()


func current_target() -> Unit:
	return _target


## Junto a la unidad, pero siempre dentro de la pantalla: pegado a un borde el
## menú se saldría y quedarían opciones inalcanzables.
func _place_at(screen_position: Vector2) -> void:
	var screen: Vector2 = get_viewport_rect().size
	var pos: Vector2 = screen_position + _OFFSET
	pos.x = clampf(pos.x, _MARGIN, screen.x - size.x - _MARGIN)
	pos.y = clampf(pos.y, _MARGIN, screen.y - size.y - _MARGIN)
	position = pos


func _make_item(label: String, on_pressed: Callable) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", _FONT_SIZE)
	btn.add_theme_color_override("font_color", _COLOR_TEXT)
	btn.add_theme_color_override("font_hover_color", _COLOR_ACCENT)
	btn.add_theme_color_override("font_pressed_color", _COLOR_ACCENT)
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, empty)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(_COLOR_ACCENT, 0.15)
	hover.set_content_margin_all(0)
	for state in ["hover", "pressed"]:
		btn.add_theme_stylebox_override(state, hover)
	btn.pressed.connect(on_pressed)
	return btn
