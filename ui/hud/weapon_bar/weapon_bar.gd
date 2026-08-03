extends HBoxContainer

## Barra de armas de la unidad seleccionada: un botón cuadrado por arma
## disponible, para elegir con cuál se ataca. El cañón va siempre.
##
## Sólo muestra y elige. Quién dispara y qué pasa al disparar no es asunto
## suyo — emite `weapon_selected` y se olvida.

signal weapon_selected(weapon: WeaponType)

const _COLOR_TEXT   := Color(0.6705882, 0.5803922, 0.4784314)
const _COLOR_ACCENT := Color(0.56078434, 0.827451, 1.0)
const _COLOR_BG     := Color(0.19215686, 0.21176471, 0.21960784)

## Cuánto se apagan las armas que no están activas.
const _DIM_ALPHA := 0.45
## Medido: a font_size 7 el nombre más ancho ("AGM-65") ocupa 27 px, y aquí
## quedan 30 útiles descontando borde y margen. A font_size 8 ocupaba 31 y se
## cortaba la última letra.
const _BUTTON_SIZE := Vector2(34, 34)
const _FONT_SIZE := 7

var _buttons: Dictionary = {}  # WeaponType -> Button


func show_weapons(unit: Unit) -> void:
	_clear_buttons()
	if unit == null:
		hide()
		return
	var weapons := unit.get_weapons()
	for weapon in weapons:
		var btn := _make_button(weapon)
		_buttons[weapon] = btn
		add_child(btn)
	_highlight(unit.active_weapon)
	visible = not weapons.is_empty()


func clear() -> void:
	_clear_buttons()
	hide()


## Repinta sin reconstruir: la unidad cambió de arma activa por su cuenta.
func set_active(weapon: WeaponType) -> void:
	_highlight(weapon)


func _clear_buttons() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_buttons.clear()


func _make_button(weapon: WeaponType) -> Button:
	var btn := Button.new()
	btn.text = tr(weapon.get_short_name())
	btn.custom_minimum_size = _BUTTON_SIZE
	# Sin clip_text a propósito: si un nombre no cabe, el botón se ensancha.
	# Cortarlo en silencio es peor — ya pasó con "AGM-65" y nadie se enteró
	# hasta verlo en pantalla.
	btn.add_theme_font_size_override("font_size", _FONT_SIZE)
	btn.pressed.connect(func() -> void: weapon_selected.emit(weapon))
	return btn


func _highlight(active: WeaponType) -> void:
	for weapon: WeaponType in _buttons:
		var btn: Button = _buttons[weapon]
		_style_button(btn, weapon == active)


func _style_button(btn: Button, selected: bool) -> void:
	var alpha := 1.0 if selected else _DIM_ALPHA
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(_COLOR_BG, alpha)
		box.set_border_width_all(1)
		box.border_color = Color(_COLOR_ACCENT, alpha if selected else alpha * 0.6)
		box.set_content_margin_all(1)
		btn.add_theme_stylebox_override(state, box)
	btn.add_theme_color_override(
		"font_color", Color(_COLOR_ACCENT if selected else _COLOR_TEXT, alpha))
	btn.add_theme_color_override("font_hover_color", _COLOR_ACCENT)
	btn.add_theme_color_override("font_pressed_color", _COLOR_ACCENT)
