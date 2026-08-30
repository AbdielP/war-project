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

## El jugador pulsó el mapa, con lo que hubiera debajo. **El mapa no decide qué
## significa**: eso depende de qué haya seleccionado, y de eso sabe quien manda
## las órdenes. Aquí sólo se cuenta el gesto, igual que con la cámara.
signal clicked(world_position: Vector2, unit: Unit)
## Click derecho. Mismo trato.
signal context_requested(world_position: Vector2, unit: Unit)
signal opened
signal closed
## El jugador pidió ver u ocultar el registro de eventos. **El mapa no lo toca**:
## el registro es del HUD, vive fuera de aquí y sigue existiendo con el mapa
## cerrado. Aquí sólo hay un botón que cuenta lo que se pulsó.
signal log_visibility_requested(shown: bool)

## Tecla que lo abre y lo cierra. `KEY_NONE` la desactiva. Mismo trato que el
## atajo de pausa: se atiende la tecla a mano en vez de inventar un `Shortcut`.
@export var shortcut_key: Key = KEY_M

@onready var _view: MapView = $Map
@onready var _hint: Label = $Hint
@onready var _detail: UnitDetail = $Detail
@onready var _objectives: ObjectivesPanel = $Objectives
@onready var _log_button: TextureButton = $LogButton
@onready var _objectives_button: TextureButton = $ObjectivesButton

## Quién está seleccionado ahora mismo. **Sólo para el rótulo.** El mapa no lo
## usa para decidir nada: el mismo click significa una cosa u otra según esto, y
## esa decisión es de quien lleva las órdenes, no de una vista.
var _selected: Unit = null

## Un rótulo puesto desde fuera, para cuando el mapa se abre a hacer otra cosa
## —señalar el blanco de una salida del hangar— y el de siempre mentiría. Vacío =
## manda la selección, que es lo normal.
var _override_hint := ""


func _ready() -> void:
	hide()
	_view.map_clicked.connect(_on_map_clicked)
	_view.map_context_requested.connect(_on_map_context_requested)
	# El atajo de teclado no existe en móvil: sin este botón no habría forma de
	# salir del mapa.
	$CloseButton.pressed.connect(close)
	_log_button.toggled.connect(func(on: bool) -> void: log_visibility_requested.emit(on))
	_objectives_button.toggled.connect(_objectives.set_visible)
	_objectives.visible = _objectives_button.button_pressed
	_update_hint()


func open() -> void:
	# El mapa se hace al abrirlo, no al arrancar: el terreno cambia por misión y
	# así no hay que acordarse de avisar a nadie cuando se carga otro.
	_view.refresh()
	show()
	opened.emit()


func close() -> void:
	# Se llama también desde fuera, y a veces con el mapa ya cerrado: cerrar dos
	# veces no debe contarse como que el jugador lo cerró dos veces.
	if not visible:
		return
	hide()
	closed.emit()


## Se lo dice el HUD al cambiar la selección. Con el mapa cerrado da igual, pero
## así el rótulo ya está puesto cuando se abre.
func set_selected_unit(unit: Unit) -> void:
	_selected = unit
	if _view != null:
		_view.set_selected_unit(unit)
	_show_detail(unit)
	_update_hint()


## De quién se está enseñando la ficha. **No es lo mismo que la selección del
## jugador**: en el mapa se pulsa un enemigo para mirarlo, y eso ni lo selecciona
## ni le da una orden. Escriben aquí los dos —la selección al cambiar y el click
## al mirar—, y manda el último, que es lo que el jugador acaba de hacer.
func _show_detail(unit: Unit) -> void:
	if _detail == null:
		return
	_detail.show_unit(unit, _view)
	# Los corchetes salen del color del bando, así que el mapa tiene que saber a
	# quién se está mirando aunque no sea de los nuestros.
	if unit != null:
		_view.set_selected_unit(unit)


## Dónde cae el punto de una unidad en la pantalla. Lo pregunta el HUD para
## poner el menú sobre el punto pulsado: con el mapa abierto la unidad puede
## estar lejísimos de la cámara y el menú saldría en cualquier parte.
func marker_position(unit: Unit) -> Vector2:
	return _view.global_position + _view.world_to_local(unit.global_position)


func toggle() -> void:
	if visible:
		close()
	else:
		open()


## El rótulo dice **qué va a hacer el siguiente click**, que es lo que cambia
## según la selección. Sin él, el mismo gesto haría dos cosas distintas sin
## avisar de cuál toca.
## Cambia el rótulo mientras el mapa sirva para otra cosa. Cadena vacía lo
## devuelve a lo que diga la selección.
func set_hint_override(text: String) -> void:
	_override_hint = text
	_update_hint()


func _update_hint() -> void:
	if _hint == null:
		return
	if _override_hint != "":
		_hint.text = _override_hint
	elif is_instance_valid(_selected) and _selected.is_player_controlled():
		_hint.text = "%s — pulsa un punto para dirigirla" % _selected.get_display_name()
	elif is_instance_valid(_selected):
		_hint.text = "%s — pulsa un punto para mirar" % _selected.get_display_name()
	else:
		_hint.text = "Pulsa un punto para mirar"


## **Pulsar no cierra el mapa.** Se dirige a la unidad, se ataca o se mira sin
## salir de él: el destino aparece marcado en el propio mapa y el recuadro de
## cámara enseña a dónde se fue la vista. Cerrar es cosa de la tecla.
func _on_map_clicked(world_position: Vector2, unit: Unit) -> void:
	# Pulsar un contacto abre su ficha antes que nada, sea de quien sea. Lo que
	# además signifique el click —una orden— lo decide quien escucha la señal.
	if unit != null:
		_show_detail(unit)
	clicked.emit(world_position, unit)


func _on_map_context_requested(world_position: Vector2, unit: Unit) -> void:
	context_requested.emit(world_position, unit)


func set_order_marker(world_position: Vector2) -> void:
	_view.set_order_marker(world_position)


func clear_order_marker() -> void:
	_view.clear_order_marker()


func _unhandled_key_input(event: InputEvent) -> void:
	if shortcut_key == KEY_NONE:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == shortcut_key:
		toggle()
		get_viewport().set_input_as_handled()
