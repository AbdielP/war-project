extends TextureButton
class_name AircraftSlot

## Una casilla del hangar: una aeronave de las que lleva el buque, con cuántas
## quedan sin desplegar.
##
## El dibujo que sale dentro es **el icono del tipo de unidad**, prestado del
## panel de desplegadas. No es la miniatura definitiva —esa está por dibujar—,
## sólo lo que hay hasta que exista: cambiar la textura no toca este código.

signal picked(entry: Dictionary)

## Las dos caras de la casilla. Van las dos por el inspector y no con un
## `preload` dentro del script: si sólo estuviera la que se ve al arrancar, la
## escena mentiría sobre lo que va a dibujar el código.
@export var art_idle: Texture2D
@export var art_selected: Texture2D

@onready var _icon: TextureRect = $Icon
@onready var _count: Label = $Count

## La entrada de la flota que representa. Vacía mientras nadie la haya llenado.
var entry: Dictionary = {}


func _ready() -> void:
	pressed.connect(func() -> void:
		if not entry.is_empty():
			picked.emit(entry))


func show_aircraft(shown: Dictionary, icon: Texture2D) -> void:
	entry = shown
	_icon.texture = icon
	_center_icon()
	tooltip_text = str(shown.get("display_name", ""))
	set_selected(false)
	refresh()


## Centra la miniatura a mano en vez de dejárselo a `KEEP_CENTERED`.
##
## Aquél reparte el sobrante a partes iguales, y cuando el dibujo y la casilla
## no tienen la misma paridad —13 px dentro de 32— deja medio píxel de desvío
## que corre el dibujo entero contra la rejilla. Redondeando aquí cae siempre
## en píxel entero, y además vale para miniaturas de cualquier medida: la del
## Harrier son 13×13 y la prestada del Cobra 20×20.
func _center_icon() -> void:
	if _icon.texture == null:
		return
	var art: Vector2 = _icon.texture.get_size()
	var box: Vector2 = texture_normal.get_size() if texture_normal != null else size
	_icon.size = art
	_icon.position = ((box - art) * 0.5).floor()


## Vuelve a leer cuántas quedan. Aparte de `show_aircraft` porque el número
## cambia al despegar y al volver, sin que la casilla cambie de aeronave.
func refresh() -> void:
	var total: int = int(entry.get("total", 0))
	var left: int = total - int(entry.get("deployed", 0))
	_count.text = "%d/%d" % [left, total]
	disabled = left <= 0


func set_selected(on: bool) -> void:
	var art: Texture2D = art_selected if on else art_idle
	texture_normal = art
	texture_pressed = art
	texture_hover = art
