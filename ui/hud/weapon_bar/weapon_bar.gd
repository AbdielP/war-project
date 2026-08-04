extends HBoxContainer

## Barra de armas de la unidad seleccionada: un botón cuadrado por arma
## disponible, para elegir con cuál se ataca. El cañón va siempre.
##
## Cada botón lleva en la esquina lo que queda de esa arma, y se apaga y deja
## de poder pulsarse cuando se agota — elegir un arma que ya no está sería
## armar un ataque que nunca sale.
##
## Sólo muestra y elige. Quién dispara y qué pasa al disparar no es asunto
## suyo — emite `weapon_selected` y se olvida.

signal weapon_selected(weapon: WeaponType)

const _COLOR_TEXT   := Color(0.6705882, 0.5803922, 0.4784314)
const _COLOR_ACCENT := Color(0.56078434, 0.827451, 1.0)
const _COLOR_BG     := Color(0.19215686, 0.21176471, 0.21960784)

## Cuánto se apagan las armas que no están activas.
const _DIM_ALPHA := 0.45
## Y cuánto las que ya no quedan: por debajo de las anteriores, para que se
## distinga de un vistazo "no seleccionada" de "no disponible".
const _EMPTY_ALPHA := 0.22
## Medido: a font_size 7 el nombre más ancho ("AGM-65") ocupa 27 px, y aquí
## quedan 30 útiles descontando borde y margen. A font_size 8 ocupaba 31 y se
## cortaba la última letra.
const _BUTTON_SIZE := Vector2(34, 34)
const _FONT_SIZE := 7
## La cuenta va más pequeña que el nombre: es un dato secundario y así cabe en
## la esquina sin pelearse con el texto del botón.
const _COUNT_FONT_SIZE := 6
## Munición ilimitada (el cañón): no se muestra número.
const _UNLIMITED := -1

var _unit: Unit = null
var _buttons: Dictionary = {}  # WeaponType -> Button
var _counts: Dictionary = {}   # WeaponType -> Label


func show_weapons(unit: Unit) -> void:
	_clear_buttons()
	_unit = unit
	if unit == null:
		hide()
		return
	var weapons := unit.get_weapons()
	for weapon in weapons:
		var btn := _make_button(weapon)
		_buttons[weapon] = btn
		add_child(btn)
	_refresh(unit.active_weapon)
	visible = not weapons.is_empty()


func clear() -> void:
	_clear_buttons()
	_unit = null
	hide()


## Repinta sin reconstruir: la unidad cambió de arma activa por su cuenta.
func set_active(weapon: WeaponType) -> void:
	_refresh(weapon)


## Se gastó munición. Sólo cambia el arma afectada, pero repintar la barra
## entera cuesta lo mismo y evita que se desincronice.
func refresh_ammo() -> void:
	if _unit != null:
		_refresh(_unit.active_weapon)


func _clear_buttons() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_buttons.clear()
	_counts.clear()


func _make_button(weapon: WeaponType) -> Button:
	var btn := Button.new()
	btn.text = tr(weapon.get_short_name())
	btn.custom_minimum_size = _BUTTON_SIZE
	# Sin clip_text a propósito: si un nombre no cabe, el botón se ensancha.
	# Cortarlo en silencio es peor — ya pasó con "AGM-65" y nadie se enteró
	# hasta verlo en pantalla.
	btn.add_theme_font_size_override("font_size", _FONT_SIZE)
	btn.pressed.connect(func() -> void: weapon_selected.emit(weapon))
	var count := _make_count_label()
	_counts[weapon] = count
	btn.add_child(count)
	return btn


## La cuenta se cuelga del propio botón, abajo a la derecha. Va por dentro y
## no en el texto porque el nombre ya ocupa el ancho entero.
func _make_count_label() -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", _COUNT_FONT_SIZE)
	label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Que no se coma los clicks destinados al botón que lo contiene.
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _refresh(active: WeaponType) -> void:
	for weapon: WeaponType in _buttons:
		var btn: Button = _buttons[weapon]
		var left: int = _unit.get_ammo(weapon) if _unit != null else _UNLIMITED
		var empty := left == 0
		# Un arma agotada no se puede elegir: dejarla pulsable armaría un
		# ataque que no llegaría a salir nunca.
		btn.disabled = empty
		var count: Label = _counts[weapon]
		count.text = "" if left == _UNLIMITED else str(left)
		_style_button(btn, count, weapon == active, empty)


func _style_button(btn: Button, count: Label, selected: bool, empty: bool) -> void:
	var alpha := _EMPTY_ALPHA if empty else (1.0 if selected else _DIM_ALPHA)
	var accent := _COLOR_ACCENT if selected and not empty else _COLOR_TEXT
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(_COLOR_BG, alpha)
		box.set_border_width_all(1)
		box.border_color = Color(
			_COLOR_ACCENT, alpha if selected else alpha * 0.6)
		box.set_content_margin_all(1)
		btn.add_theme_stylebox_override(state, box)
	btn.add_theme_color_override("font_color", Color(accent, alpha))
	btn.add_theme_color_override("font_disabled_color", Color(_COLOR_TEXT, alpha))
	btn.add_theme_color_override("font_hover_color", _COLOR_ACCENT)
	btn.add_theme_color_override("font_pressed_color", _COLOR_ACCENT)
	count.add_theme_color_override("font_color", Color(accent, alpha))
