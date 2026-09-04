extends Button
class_name UnitPortrait

## Un cuadrito del panel de desplegadas: marco, silueta y barra de vida.
##
## Marco suelto y marco seleccionado son **dos texturas dibujadas**, no un tinte
## sobre la misma: la versión seleccionada cambia el color del borde entero y le
## añade una marca de esquina, y eso no sale de ningún `modulate`.
##
## El marco mide 32×35 y no es una caja: lleva una pestaña que **asoma por
## arriba y por la izquierda**, así que el cuadro útil son sus 28 px centrales
## (x 4..31) y la ventana interior 22×20, con el borde gastando 3 px por lado.
## Las siluetas se dibujan centradas en esa ventana a su tamaño nativo, sin
## escalar: cada una viene ya dibujada a la medida en que se ve, y las de 32
## reducidas perderían tres de cada cuatro píxeles.
##
## **La barra de vida va debajo del marco, no dentro.** Mide 28, que es
## exactamente el ancho del cuadro, y por eso se alinea con su borde izquierdo
## —4 px dentro de la textura— y no con el de la pestaña. La franja azul que el
## marco lleva dibujada en su parte baja es del dibujo; no es la barra.
##
## Ese ancho de 28 es también lo que decide la altura total: el nombre son tres
## caracteres de 8 px, o sea 24, y cabe centrado de sobra.

## Lo pulsó el jugador. Quien escucha decide qué es "seleccionar": el panel sólo
## sabe que este cuadrito representa a esa unidad.
signal picked(unit: Unit)

const _FRAME := preload("res://assets/art/UI/portrait_frame.png")
const _FRAME_ON := preload("res://assets/art/UI/portrait_frame_selected.png")

## Cuánto se apaga el cuadrito de una unidad perdida. No desaparece: sigue en su
## sitio, en gris, como recuento de lo que costó la operación.
const _LOST_TINT := Color(0.45, 0.45, 0.5, 0.7)

@onready var _frame: TextureRect = $Frame
@onready var _mark: TextureRect = $Mark
@onready var _health: TextureProgressBar = $Health
@onready var _name: Label = $Name

## A quién representa, o `null` si es una baja.
var unit: Unit = null


func _ready() -> void:
	pressed.connect(func() -> void:
		if is_instance_valid(unit):
			picked.emit(unit))


## La unidad que va en el cuadrito. Se engancha a su vida en vez de mirarla cada
## frame: la barra sólo tiene que moverse cuando le pegan.
func show_unit(shown: Unit, count: int = 1) -> void:
	unit = shown
	modulate = Color.WHITE
	disabled = false
	_mark.texture = shown.unit_type.portrait_icon if shown.unit_type != null else null
	_name.text = UnitType.short_label(shown.get_display_name(), shown.unit_type)
	tooltip_text = shown.get_display_name() if count < 2 \
		else "%s (%d)" % [shown.get_display_name(), count]
	_health.show()
	_refresh_health(shown.health, shown.get_max_health())
	if not shown.health_changed.is_connected(_refresh_health):
		shown.health_changed.connect(_refresh_health)
	set_selected(false)


## Una baja. Conserva la silueta —de ahí que se guarde el tipo y no sólo el
## nombre: la unidad ya no existe— y pierde la barra, porque no queda vida que
## contar. No responde al ratón: no hay a dónde llevar la cámara.
func show_lost(display_name: String, type: UnitType) -> void:
	unit = null
	_mark.texture = type.portrait_icon if type != null else null
	_name.text = UnitType.short_label(display_name, type)
	tooltip_text = "%s (perdido)" % display_name
	modulate = _LOST_TINT
	disabled = true
	_health.hide()
	set_selected(false)


func set_selected(on: bool) -> void:
	_frame.texture = _FRAME_ON if on else _FRAME


func _refresh_health(current: float, maximum: float) -> void:
	_health.max_value = maxf(1.0, maximum)
	_health.value = current
