extends VBoxContainer

## Dos botones para acercar y alejar la cámara.
##
## Sólo piden el cambio: cuántos niveles hay y cuánto acerca cada uno es cosa
## de `PanCamera`. La barra ni siquiera sabe cuál está puesto — le dicen hasta
## dónde se puede seguir y con eso apaga el botón que ya no lleva a ninguna
## parte, mismo criterio que `WeaponBar` con las armas agotadas.

## +1 acerca, −1 aleja. Quien lo escuche decide qué significa eso.
signal zoom_change_requested(step: int)

## Cuánto se apaga el botón que ya no puede ir más lejos. El icono no trae
## una versión "agotado" propia, así que se simula atenuando el `modulate`.
const _DISABLED_ALPHA := 0.3

@onready var _in_btn: TextureButton = $ZoomIn
@onready var _out_btn: TextureButton = $ZoomOut


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


func _style(btn: TextureButton) -> void:
	btn.modulate.a = _DISABLED_ALPHA if btn.disabled else 1.0
