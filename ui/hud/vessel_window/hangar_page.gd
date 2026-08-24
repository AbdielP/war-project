extends Control

## La página del hangar: aeronaves de ataque o de transporte.
##
## Por ahora sólo están las dos solapas y el marco donde irá su contenido. La
## rejilla de aparatos, la ficha de la derecha y el bloque de armamento vienen
## después, dentro de ese marco.

## Las dos caras de una solapa.
##
## La activa es **1 px más alta** que la otra, y ese píxel es todo el truco: le
## hace tapar la línea superior del marco de abajo y fundirse con él, mientras
## que a la inactiva la línea le pasa por debajo y queda separada. Van por el
## inspector y no con un `preload` dentro del script: si sólo estuviera puesta
## la que se ve al arrancar, la escena mentiría sobre lo que dibuja el código.
@export var tab_idle: StyleBox
@export var tab_active: StyleBox

const _SLOT := preload("res://ui/hud/vessel_window/aircraft_slot.tscn")

## Qué solapa enseña qué. Hoy no hay dónde mirarlo: la lista de la flota no dice
## si una aeronave es de ataque o de transporte, y las dos que hay —Harrier y
## SuperCobra— son de ataque. Así que transporte sale vacío hasta que el dato
## exista, en vez de repartir a ojo lo que nadie ha clasificado.
enum Kind { ATTACK, TRANSPORT }

## Blanco para la solapa abierta y el gris azulado de la paleta para la otra.
## El arte ya las distingue —una lleva borde y la otra no—, pero apagar también
## el texto es lo que hace que se vea cuál manda sin tener que fijarse.
const _TEXT_ON := Color(1.0, 1.0, 1.0)
const _TEXT_OFF := Color(0.60784316, 0.67058825, 0.69803923)

@onready var _tabs: Control = $SubTabs
@onready var _slots: GridContainer = $Content/Slots

var _buttons: Array[Button] = []
var _kind: int = -1
var _ship: Node2D = null
var _chosen: AircraftSlot = null


func _ready() -> void:
	for child in _tabs.get_children():
		var tab := child as Button
		if tab == null:
			continue
		var index := _buttons.size()
		tab.pressed.connect(func() -> void: show_kind(index))
		_buttons.append(tab)
	show_kind(0)


## Cambia entre aeronaves de ataque y de transporte.
func show_kind(index: int) -> void:
	if index == _kind or index < 0 or index >= _buttons.size():
		return
	_kind = index
	for i in _buttons.size():
		var tab := _buttons[i]
		var lit := i == index
		var art: StyleBox = tab_active if lit else tab_idle
		for state in [&"normal", &"hover", &"pressed", &"focus"]:
			tab.add_theme_stylebox_override(state, art)
		var color := _TEXT_ON if lit else _TEXT_OFF
		tab.add_theme_color_override(&"font_color", color)
		tab.add_theme_color_override(&"font_hover_color", color)
		tab.add_theme_color_override(&"font_pressed_color", color)
		# El alto se le pregunta al arte y no se escribe aquí: es esa diferencia
		# de 1 px la que decide si la solapa toca la línea o se queda encima.
		var box := art as StyleBoxTexture
		if box != null and box.texture != null:
			tab.size.y = box.texture.get_height()
	_fill_slots()


## Qué buque se está mirando. Se lo dice la ventana al abrirse.
func show_for(vessel: Node2D) -> void:
	_ship = vessel
	_fill_slots()


func _fill_slots() -> void:
	for child in _slots.get_children():
		child.queue_free()
	_chosen = null
	if _ship == null or _kind != Kind.ATTACK:
		return
	for entry: Dictionary in PlayerFleet.get_loadout(_ship.unit_name):
		var slot: AircraftSlot = _SLOT.instantiate()
		_slots.add_child(slot)
		slot.show_aircraft(entry, _icon_of(entry))
		slot.picked.connect(_on_slot_picked.bind(slot))


## El dibujo de la aeronave sale de su propio `UnitType`, que es donde ya vive
## para el panel de desplegadas. Hay que abrir la escena para leerlo porque la
## lista de la flota guarda el `PackedScene` y no el tipo; se instancia y se
## suelta en el acto, sin llegar a entrar en el árbol, así que no corre ningún
## `_ready` ni queda nada colgando.
func _icon_of(entry: Dictionary) -> Texture2D:
	var scene: PackedScene = entry.get("scene")
	if scene == null:
		return null
	var unit := scene.instantiate()
	var icon: Texture2D = null
	if unit.unit_type != null:
		# La miniatura del hangar si la tiene; si no, la silueta del panel de
		# desplegadas como relleno. Hoy sólo el Harrier tiene la suya.
		icon = unit.unit_type.hangar_icon
		if icon == null:
			icon = unit.unit_type.portrait_icon
	unit.free()
	return icon


## Sólo una casilla puede estar elegida. Se apaga la anterior en vez de repasar
## todas: son dos ahora, pero la lista crece con la flota.
func _on_slot_picked(_entry: Dictionary, slot: AircraftSlot) -> void:
	if is_instance_valid(_chosen):
		_chosen.set_selected(false)
	_chosen = slot
	slot.set_selected(true)
