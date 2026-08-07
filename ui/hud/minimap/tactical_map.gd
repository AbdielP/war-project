extends Control
class_name TacticalMap

## El mapa a pantalla completa. Mismo dibujo que el minimapa —el mismo [MapView]
## con otros ajustes— pero con sitio para la rejilla de celdas, las coordenadas
## y para pulsar un punto concreto.
##
## Tapa la pantalla entera y se come los clicks a propósito: con el mapa abierto,
## pulsar no puede colarse hasta el mundo y dar una orden de movimiento sin
## querer.
##
## Funciona con la partida en pausa sin hacer nada, porque cuelga del HUD y el
## HUD ya es `process_mode = Always`. Mirar el mapa congelado es justo para lo
## que sirve un mapa táctico.

## El jugador pulsó un punto: quiere mirar ahí. Se reenvía y ya — el mapa no
## conoce la cámara, igual que el resto del HUD.
signal move_requested(world_position: Vector2)
signal closed

## Tecla que lo abre y lo cierra. `KEY_NONE` la desactiva. Mismo trato que el
## atajo de pausa: se atiende la tecla a mano en vez de inventar un `Shortcut`.
@export var shortcut_key: Key = KEY_M

@onready var _view: MapView = $Map


func _ready() -> void:
	hide()
	_view.map_clicked.connect(_on_map_clicked)


func open() -> void:
	# El mapa se hace al abrirlo, no al arrancar: el terreno cambia por misión y
	# así no hay que acordarse de avisar a nadie cuando se carga otro.
	_view.refresh()
	show()


func close() -> void:
	hide()
	closed.emit()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


## Pulsar lleva la mirada allí y cierra. Cerrar es parte del gesto: se abre el
## mapa para decidir a dónde ir, y una vez decidido estorba.
func _on_map_clicked(world_position: Vector2) -> void:
	move_requested.emit(world_position)
	close()


func _unhandled_key_input(event: InputEvent) -> void:
	if shortcut_key == KEY_NONE:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == shortcut_key:
		toggle()
		get_viewport().set_input_as_handled()
