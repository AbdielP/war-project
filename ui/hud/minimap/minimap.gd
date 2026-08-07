extends PanelContainer
class_name Minimap

## El mapa pequeño de la esquina. No es un mando de navegación: es el terreno de
## un vistazo, el recuadro de dónde estás mirando, y un botón para abrir el mapa
## grande. A 87 px de panel toca 1 píxel por celda, así que aquí no cabe una
## coordenada ni tendría sentido pulsar un sitio concreto.
##
## Todo el dibujo lo hace [MapView]; esto sólo recoge el click.

## El jugador quiere el mapa a pantalla completa.
signal expand_requested

@onready var _view: MapView = $MapView


func _ready() -> void:
	# Pulsar el terreno y pulsar el marco del panel hacen lo mismo: el minimapa
	# entero es el botón, no sólo la parte pintada.
	_view.map_clicked.connect(
			func(_world: Vector2, _unit: Unit) -> void: expand_requested.emit())


func set_order_marker(world_position: Vector2) -> void:
	_view.set_order_marker(world_position)


func clear_order_marker() -> void:
	_view.clear_order_marker()


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		expand_requested.emit()
		accept_event()
