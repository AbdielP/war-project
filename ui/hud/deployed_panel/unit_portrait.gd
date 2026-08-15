extends Button
class_name UnitPortrait

## Un cuadrito del panel de desplegadas: marco, silueta y barra de vida.
##
## Marco suelto y marco seleccionado son **dos texturas dibujadas**, no un tinte
## sobre la misma: la versión seleccionada cambia el color del borde entero y le
## añade una marca de esquina, y eso no sale de ningún `modulate`.
##
## El marco mide 22 y su ventana interior 16, que es justo lo que miden las
## siluetas: entran al píxel y no hay que escalar nada. Las dos medidas salen de
## achicar el arte original a la mitad —silueta de 32 a 16, marco de 38 a 22—,
## y el marco no baja a 19 porque entonces la ventana quedaría en 14 y habría
## que estropear la silueta con un achicado que no es 2:1.
##
## La barra de vida es color plano y no textura: un rectángulo verde basta y así
## se estira al ancho que haga falta sin romper ningún borde.

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
@onready var _health: ProgressBar = $Health
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
	_name.text = _short(shown.get_display_name(), shown.unit_type)
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
	_name.text = _short(display_name, type)
	tooltip_text = "%s (perdido)" % display_name
	modulate = _LOST_TINT
	disabled = true
	_health.hide()
	set_selected(false)


func set_selected(on: bool) -> void:
	_frame.texture = _FRAME_ON if on else _FRAME


## Lo que cabe en el cuadrito: tres caracteres, porque la fuente gasta 8 px por
## letra y el cuadrito mide 24. Manda `UnitType.short_name` cuando está puesto;
## sin él se recorta el primer token del nombre —el modelo, que es lo que
## distingue una unidad de otra de un vistazo— quitándole los separadores, que
## sólo gastan sitio: "AH-1W SuperCobra" acaba en "AH1".
func _short(full: String, type: UnitType) -> String:
	if type != null and not type.short_name.is_empty():
		return type.short_name
	var cut := full.find(" ")
	var model := full if cut < 1 else full.substr(0, cut)
	model = model.replace("-", "").replace(".", "").to_upper()
	return model.substr(0, 3)


func _refresh_health(current: float, maximum: float) -> void:
	_health.max_value = maxf(1.0, maximum)
	_health.value = current
