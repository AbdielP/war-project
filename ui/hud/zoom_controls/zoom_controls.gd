extends VBoxContainer

## Dos botones para acercar y alejar la cámara.
##
## Sólo piden el cambio: cuántos niveles hay y cuánto acerca cada uno es cosa
## de `PanCamera`. La barra ni siquiera sabe cuál está puesto — le dicen hasta
## dónde se puede seguir y con eso apaga el botón que ya no lleva a ninguna
## parte, mismo criterio que `WeaponBar` con las armas agotadas.

## +1 acerca, −1 aleja. Quien lo escuche decide qué significa eso.
signal zoom_change_requested(step: int)

const _COLOR_TEXT   := Color(0.6705882, 0.5803922, 0.4784314)
const _COLOR_ACCENT := Color(0.56078434, 0.827451, 1.0)
const _COLOR_BG     := Color(0.19215686, 0.21176471, 0.21960784)

## Cuánto se apaga el botón que ya no puede ir más lejos.
const _DISABLED_ALPHA := 0.3

@onready var _in_btn: Button = $ZoomIn
@onready var _out_btn: Button = $ZoomOut


func _ready() -> void:
	_in_btn.pressed.connect(func() -> void: zoom_change_requested.emit(1))
	_out_btn.pressed.connect(func() -> void: zoom_change_requested.emit(-1))
	_restyle()


## Dónde está la cámara y cuántos escalones tiene. La fuente de verdad es ella;
## esto sólo refleja si queda cuerda hacia arriba o hacia abajo.
func set_state(level: int, count: int) -> void:
	_in_btn.disabled = level >= count - 1
	_out_btn.disabled = level <= 0
	_restyle()


func _restyle() -> void:
	_style(_in_btn)
	_style(_out_btn)


func _style(btn: Button) -> void:
	var alpha := _DISABLED_ALPHA if btn.disabled else 1.0
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(_COLOR_BG, alpha)
		box.set_border_width_all(1)
		box.border_color = Color(_COLOR_ACCENT, alpha * 0.6)
		box.set_content_margin_all(0)
		btn.add_theme_stylebox_override(state, box)
	btn.add_theme_color_override("font_color", Color(_COLOR_TEXT, alpha))
	btn.add_theme_color_override("font_disabled_color", Color(_COLOR_TEXT, alpha))
	btn.add_theme_color_override("font_hover_color", _COLOR_ACCENT)
	btn.add_theme_color_override("font_pressed_color", _COLOR_ACCENT)
