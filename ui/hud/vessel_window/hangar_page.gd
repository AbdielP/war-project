extends Control
class_name HangarPage

## La página del hangar: aeronaves de ataque o de transporte.
##
## Dos bloques, uno debajo del otro. Arriba la rejilla de aparatos; abajo el
## armamento, que **no existe hasta que hay una aeronave elegida** — sin aparato
## no hay nada que cargar, y un panel de botones muertos esperando no dice eso.
##
## Y no existir es no ocupar sitio: la ventana **mide lo que mide su contenido**
## y crece al desplegarse el armamento. Dejar el hueco reservado y esconder lo de
## dentro sale peor que enseñarlo — un tercio de ventana vacío se lee como que
## algo se rompió, no como que falta elegir.

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
const _OPTION := preload("res://ui/hud/vessel_window/loadout_option.tscn")

## Cuánto alto pide la página. Lo escucha la ventana, que es la única que sabe
## cuánto marco hay que añadirle por fuera.
##
## Va el tiempo en la señal y no como constante de la ventana porque el que sabe
## cuánto dura el gesto es el que lo empieza: aquí se decide si el armamento sale
## despacio o de golpe, y el marco tiene que ir al mismo paso o se despega del
## contenido a media animación.
signal height_wanted(height: float, seconds: float)

## Lo que tarda el bloque de armamento en desplegarse y en plegarse.
##
## Corto a propósito: no es una animación, es quitarle el golpe seco a una
## ventana que cambia de tamaño. Más largo y el jugador espera a la UI.
const _ANIM_TIME := 0.12

## Qué dice la columna de la derecha del armamento. Los dos casos son distintos
## de verdad y no un mismo aviso con más o menos texto: en uno faltan datos del
## juego —el Cobra no tiene armamento definido todavía— y en el otro falta que
## el jugador elija. Decir "no hay" cuando lo que pasa es "elige" enseña al
## jugador a no mirar el panel.
const _PROMPT_PICK := "SELECT A LOADOUT TO CONTINUE"
const _PROMPT_NONE := "NO LOADOUTS AVAILABLE"

## Dónde empieza el aviso de la derecha. Cuando hay botones, deja libre la
## columna que ocupan; cuando no hay ninguno, se queda con el panel entero — un
## aviso arrinconado a la derecha con medio panel vacío al lado se lee como que
## falta algo por cargar, y lo que pasa es justo lo contrario.
const _PROMPT_LEFT := 74.0
const _PROMPT_LEFT_ALONE := 3.0

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
@onready var _content: NinePatchRect = $Content
@onready var _slots: GridContainer = $Content/Slots
@onready var _prompt: Label = $Content/Prompt
@onready var _detail: Control = $Content/Detail
@onready var _detail_name: Label = $Content/Detail/Name
@onready var _model: UnitModel = $Content/Detail/Model
@onready var _ecm: Label = $Content/Detail/Stats/Ecm
@onready var _clip: Control = $LoadoutClip
@onready var _loadout: NinePatchRect = $LoadoutClip/Loadout
@onready var _options: VBoxContainer = $LoadoutClip/Loadout/Options
@onready var _loadout_prompt: Label = $LoadoutClip/Loadout/Prompt

var _buttons: Array[Button] = []
var _kind: int = -1
var _ship: Node2D = null
var _chosen: AircraftSlot = null
var _fold: Tween = null


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
##
## El armamento se esconde **de golpe** y no con el fundido: la ventana entera
## acaba de aparecer, y desvanecer un trozo de algo que el jugador todavía no ha
## visto no suaviza nada, sólo enseña un panel que se va solo.
func show_for(vessel: Node2D) -> void:
	_ship = vessel
	_fill_slots()
	_hide_loadout(true)


func _fill_slots() -> void:
	for child in _slots.get_children():
		child.queue_free()
	_chosen = null
	# Cambiar de solapa o de buque deja sin elegir lo que estuviera elegido, así
	# que ni la ficha ni el armamento son ya de nadie y se van con ello.
	_hide_detail()
	_hide_loadout()
	if _ship == null or _kind != Kind.ATTACK:
		return
	for entry: Dictionary in PlayerFleet.get_loadout(_ship.unit_name):
		var slot: AircraftSlot = _SLOT.instantiate()
		_slots.add_child(slot)
		slot.show_aircraft(entry, _icon_of(entry))
		slot.picked.connect(_on_slot_picked.bind(slot))


## El `UnitType` de una entrada de la flota. Hay que abrir la escena para leerlo
## porque la lista guarda el `PackedScene` y no el tipo; se instancia y se suelta
## en el acto, sin llegar a entrar en el árbol, así que no corre ningún `_ready`
## ni queda nada colgando. El recurso sobrevive a la unidad: va por referencia.
func _type_of(entry: Dictionary) -> UnitType:
	var scene: PackedScene = entry.get("scene")
	if scene == null:
		return null
	var unit := scene.instantiate()
	var type: UnitType = unit.unit_type
	unit.free()
	return type


## El dibujo de la aeronave: la miniatura del hangar si la tiene; si no, la
## silueta del panel de desplegadas como relleno. Hoy sólo el Harrier tiene la
## suya.
func _icon_of(entry: Dictionary) -> Texture2D:
	var type := _type_of(entry)
	if type == null:
		return null
	return type.hangar_icon if type.hangar_icon != null else type.portrait_icon


## Sólo una casilla puede estar elegida. Se apaga la anterior en vez de repasar
## todas: son dos ahora, pero la lista crece con la flota.
func _on_slot_picked(entry: Dictionary, slot: AircraftSlot) -> void:
	if is_instance_valid(_chosen):
		_chosen.set_selected(false)
	_chosen = slot
	slot.set_selected(true)
	_show_detail(entry)
	_show_loadout(entry)


## La ficha de la aeronave elegida: cómo se llama, cómo es y qué trae.
##
## Ocupa el mismo hueco que el aviso de "elige un aparato" y por eso se turnan:
## los dos dicen lo mismo desde lados distintos —qué hay ahí— y enseñar uno es
## apagar el otro.
func _show_detail(entry: Dictionary) -> void:
	var type := _type_of(entry)
	if type == null:
		_hide_detail()
		return
	# En mayúsculas porque la fuente **no tiene minúsculas**: dejar el nombre tal
	# cual manda a Godot a buscar los glifos que faltan en una fuente del sistema
	# y ahí se va el alto de línea del renglón entero.
	_detail_name.text = type.display_name.to_upper()
	# Sin el signo de porcentaje: la fuente tampoco lo trae. El número es el dato,
	# y un glifo prestado del sistema rompería el renglón igual que las minúsculas.
	_ecm.text = "ECM: %d" % roundi(type.ecm_evasion * 100.0)
	_prompt.hide()
	_detail.show()
	# El modelo, el último: se centra contra el tamaño del hueco, y así se mide
	# sobre una ficha que ya está puesta en pantalla.
	_model.show_scene(entry.get("scene"))


func _hide_detail() -> void:
	_model.show_scene(null)
	_detail.hide()
	_prompt.show()


## Llena el bloque de armamento con lo que ofrezca **esa** aeronave y lo enseña.
##
## Los botones se fabrican aquí en vez de estar puestos en la escena porque la
## lista no es la misma para todos los aparatos, igual que las casillas de
## arriba. Lo que sí está en la escena es cómo se ve uno: `loadout_option.tscn`
## lleva su arte y su fuente, y este código sólo le pone el texto.
func _show_loadout(entry: Dictionary) -> void:
	# Se sacan del contenedor **antes** de encolarlos para borrar: `queue_free`
	# solo los quita al final del fotograma, y hasta entonces la columna cuenta
	# los viejos y los nuevos a la vez y se desborda justo mientras aparece.
	for child in _options.get_children():
		_options.remove_child(child)
		child.queue_free()
	var type := _type_of(entry)
	var names: PackedStringArray = type.loadouts if type != null else PackedStringArray()
	for label in names:
		var option: Button = _OPTION.instantiate()
		option.text = label
		_options.add_child(option)
	var has_any := not names.is_empty()
	_loadout_prompt.text = _PROMPT_PICK if has_any else _PROMPT_NONE
	_loadout_prompt.offset_left = _PROMPT_LEFT if has_any else _PROMPT_LEFT_ALONE
	_stop_fold()
	# Se enseña **antes** de pedir el alto: el bloque no se desvanece, se descubre
	# — está entero desde el primer fotograma y es el recorte de arriba el que lo
	# va dejando ver conforme la ventana crece.
	_loadout.show()
	height_wanted.emit(_height_for(true), _ANIM_TIME)


## `instant` es para cuando el panel ni siquiera estaba a la vista todavía —la
## ventana acabando de abrirse—, donde no hay gesto que suavizar.
func _hide_loadout(instant: bool = false) -> void:
	if not _loadout.visible:
		return
	_stop_fold()
	if instant:
		_loadout.hide()
		height_wanted.emit(_height_for(false), 0.0)
		return
	height_wanted.emit(_height_for(false), _ANIM_TIME)
	# Sigue visible mientras la ventana se cierra sobre él —el recorte lo va
	# comiendo— y se apaga al final. No es cosmético: un botón fuera del recorte
	# se deja pulsar igual, porque `clip_contents` recorta el dibujo y no el
	# ratón.
	_fold = create_tween()
	_fold.tween_interval(_ANIM_TIME)
	_fold.tween_callback(_loadout.hide)


## El alto que pide la página en cada uno de sus dos estados.
##
## Sale de los `offset` de la escena y no de `size`, para que valga desde
## `_ready` —cuando el reparto todavía no ha corrido— y para que mover las
## piezas en el editor siga mandando sobre el número.
func _height_for(expanded: bool) -> float:
	if expanded:
		return _clip.offset_top + _loadout.offset_bottom
	return _content.offset_bottom


## Lo que mide ahora mismo, para que la ventana pregunte al abrirse.
func wanted_height() -> float:
	return _height_for(_loadout.visible)


func _stop_fold() -> void:
	if _fold != null and _fold.is_valid():
		_fold.kill()
	_fold = null
