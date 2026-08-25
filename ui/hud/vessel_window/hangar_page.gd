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
const _CARD := preload("res://ui/hud/vessel_window/weapon_card.tscn")

## Cuánto sitio pide la página. Lo escucha la ventana, que es la única que sabe
## cuánto marco hay que añadirle por fuera.
##
## `width` es lo que hace falta **de más**: 0 significa "con lo que ya mides me
## vale". La página no conoce su propio mínimo —eso lo dice la escena de la
## ventana— y pedirlo cada vez la obligaría a saber cuánto ocupa la ficha del
## avión, que no es asunto suyo.
##
## Va el tiempo en la señal y no como constante de la ventana porque el que sabe
## cuánto dura el gesto es el que lo empieza: aquí se decide si el armamento sale
## despacio o de golpe, y el marco tiene que ir al mismo paso o se despega del
## contenido a media animación.
signal size_wanted(width: float, height: float, seconds: float)

## El jugador quiere elegir a dónde va la salida antes de lanzarla. La página no
## abre el mapa: no lo conoce y no tiene por qué. Avisa, y quien lleva el HUD
## —que sí sabe qué pantallas hay— lo abre y devuelve el punto por [method
## launch].
signal target_requested

## Salió una aeronave. Lo escucha quien tenga que enterarse; aquí sólo se cuenta.
signal launched(entry: Dictionary, count: int)

## Lo que tarda el bloque de armamento en desplegarse y en plegarse.
##
## Corto a propósito: no es una animación, es quitarle el golpe seco a una
## ventana que cambia de tamaño. Más largo y el jugador espera a la UI.
const _ANIM_TIME := 0.12

## Qué dice el hueco del armamento cuando no hay armas que enseñar. Los tres
## casos son distintos de verdad y no un mismo aviso con más o menos texto: falta
## elegir, no hay nada que elegir, o lo elegido no lleva nada colgado. Decir "no
## hay" cuando lo que pasa es "elige" enseña al jugador a no mirar el panel.
##
## El primero va partido en dos renglones a mano, y el corte no es por el ancho:
## la segunda línea es la que lleva el cursor, y "CONTINUE ▪" tiene que quedar
## junto. Los otros dos no piden nada al jugador, así que van de una pieza y sin
## cursor — un cursor donde no hay nada que pulsar es una promesa falsa.
const _PROMPT_PICK := ["SELECT A LOADOUT TO", "CONTINUE"]
const _PROMPT_NONE := ["NO LOADOUTS AVAILABLE", ""]
const _PROMPT_UNARMED := ["NO WEAPONS FITTED", ""]

## El cuadrado macizo de la fuente, en `U+00AA`. Va por el código de escape y no
## por el carácter suelto para que no dependa de con qué se guarde el archivo:
## un `ª` mal codificado se convierte en dos símbolos raros y no se ve venir.
const _CURSOR := "ª"

## Lo que dura cada mitad del parpadeo. Medio segundo es el ritmo de un cursor de
## terminal: más rápido molesta al leer el aviso que hay al lado, y más lento
## deja de leerse como "te toca a ti" y parece un adorno.
const _BLINK := 0.5

## Aire entre el último botón de armamento y el borde de abajo del panel cuando
## todavía no hay nada elegido.
const _LOADOUT_PAD := 6.0

## La tira de la barra de potencia: diez dibujos de 5 px de alto, del vacío al
## lleno, apilados. No es una barra que se estire ni un relleno de color — cada
## paso está dibujado, incluidas las mitades, así que aquí sólo se elige cuál se
## enseña.
const _POWER_STEPS := 10
const _POWER_BAR_HEIGHT := 5.0

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
@onready var _power: TextureRect = $Content/Detail/Stats/PowerBar
@onready var _ecm: Label = $Content/Detail/Stats/EcmValue
@onready var _squad_count: Label = $Content/Detail/Stats/Count
@onready var _squad_max: Label = $Content/Detail/Stats/Max
@onready var _squad_less: Button = $Content/Detail/Stats/Less
@onready var _squad_more: Button = $Content/Detail/Stats/More
@onready var _clip: Control = $LoadoutClip
@onready var _loadout: NinePatchRect = $LoadoutClip/Loadout
@onready var _options: VBoxContainer = $LoadoutClip/Loadout/Options
@onready var _marker: TextureRect = $LoadoutClip/Loadout/Marker
@onready var _weapons: Control = $LoadoutClip/Loadout/Weapons
@onready var _actions: HBoxContainer = $LoadoutClip/Loadout/Actions
@onready var _take_off: Button = $LoadoutClip/Loadout/Actions/TakeOff
@onready var _targeted_take_off: Button = $LoadoutClip/Loadout/Actions/TargetedTakeOff
@onready var _column: VBoxContainer = $LoadoutClip/Loadout/Weapons/Column
@onready var _fixed: HBoxContainer = $LoadoutClip/Loadout/Weapons/Column/Fixed
@onready var _cannon: WeaponCard = $LoadoutClip/Loadout/Weapons/Column/Fixed/Cannon
@onready var _self_defense: WeaponCard = $LoadoutClip/Loadout/Weapons/Column/Fixed/SelfDefense
@onready var _cards: HBoxContainer = $LoadoutClip/Loadout/Weapons/Column/Cards
@onready var _loadout_prompt: VBoxContainer = $LoadoutClip/Loadout/Weapons/Prompt
@onready var _prompt_line1: Label = $LoadoutClip/Loadout/Weapons/Prompt/Line1
@onready var _prompt_line2: HBoxContainer = $LoadoutClip/Loadout/Weapons/Prompt/Line2
@onready var _prompt_text: Label = $LoadoutClip/Loadout/Weapons/Prompt/Line2/Text
@onready var _cursor: Label = $LoadoutClip/Loadout/Weapons/Prompt/Line2/Cursor

var _buttons: Array[Button] = []
var _kind: int = -1
var _ship: Node2D = null
var _chosen: AircraftSlot = null
var _fold: Tween = null

## Cuántos aparatos de los elegidos van a salir, y cuántos hay para salir. El
## primero lo mueve el jugador con las flechas; el segundo es cuántos quedan sin
## desplegar, que es el tope de verdad y no un número escrito en ningún sitio.
var squad: int = 1
var _squad_available: int = 0

## Qué armamento se ha elegido, y con qué botón. El primero es lo que se llevará
## el avión al despegar; el segundo sólo existe para poder apagarlo cuando se
## elija otro.
var chosen_loadout: WeaponLoadout = null
var _chosen_option: LoadoutOption = null

## El tipo de la aeronave elegida. Se guarda al enseñar su ficha porque el
## armamento lo vuelve a necesitar —el cañón sale de aquí— y sacarlo otra vez
## costaría abrir su escena de nuevo.
var _chosen_type: UnitType = null

## Lo pequeño que se queda el bloque de armamento antes de elegir carga: llega
## hasta el último botón. Se mide de la escena en vez de escribirlo aquí, para
## que mover una pieza en el editor mande sobre el número. El tamaño grande no
## es fijo — ver [method _full_height].
var _loadout_compact: float = 0.0

## Cuánto reservan los botones de despegue por debajo del área de armas.
var _actions_room: float = 0.0


func _ready() -> void:
	for child in _tabs.get_children():
		var tab := child as Button
		if tab == null:
			continue
		var index := _buttons.size()
		tab.pressed.connect(func() -> void: show_kind(index))
		_buttons.append(tab)
	_squad_less.pressed.connect(func() -> void: _set_squad(squad - 1))
	_squad_more.pressed.connect(func() -> void: _set_squad(squad + 1))
	# La ficha y el armamento se guardan **puestos** en la escena, con datos de
	# muestra, porque si no en el editor no hay nada que colocar: son huecos
	# vacíos hasta que corre el juego. Quien manda sobre si se ven es esto, no la
	# casilla del inspector — así se pueden dejar a la vista para diseñarlos sin
	# que la partida arranque con la ventana abierta de par en par.
	_loadout_compact = _loadout.offset_top + _options.offset_bottom + _LOADOUT_PAD
	_actions_room = -_actions.offset_top
	_take_off.pressed.connect(launch)
	_targeted_take_off.pressed.connect(target_requested.emit)
	_cursor.text = _CURSOR
	_start_blink()
	_hide_detail()
	_hide_loadout(true)
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
	# Fuera del contenedor antes de encolarlos para borrar, igual que en la
	# columna de armamento: `queue_free` sólo los quita al final del fotograma, y
	# hasta entonces la rejilla cuenta los viejos y los nuevos a la vez.
	for child in _slots.get_children():
		_slots.remove_child(child)
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
	_chosen_type = type
	# En mayúsculas porque la fuente **no tiene minúsculas**: dejar el nombre tal
	# cual manda a Godot a buscar los glifos que faltan en una fuente del sistema
	# y ahí se va el alto de línea del renglón entero.
	_detail_name.text = type.display_name.to_upper()
	# El valor **es** el fotograma: la tira lleva un dibujo por cada nota, así que
	# aquí no hay escala que convertir, sólo mover la ventana del atlas.
	var frame: int = clampi(type.power, 0, _POWER_STEPS - 1)
	var atlas := _power.texture as AtlasTexture
	if atlas != null:
		atlas.region = Rect2(0.0, frame * _POWER_BAR_HEIGHT,
				atlas.region.size.x, _POWER_BAR_HEIGHT)
	# Se enseña aunque el juego lo use por dentro y no lo explique: este número
	# decide si un misil antiaéreo acierta o se va, así que el jugador tiene que
	# poder compararlo entre aparatos antes de mandar uno a una zona defendida.
	_ecm.text = "%d%%" % roundi(type.ecm_evasion * 100.0)
	_squad_available = maxi(int(entry.get("total", 0)) - int(entry.get("deployed", 0)), 0)
	_squad_max.text = "MAX %d" % _squad_available
	_set_squad(1)
	_prompt.hide()
	_detail.show()
	# El modelo, el último: se centra contra el tamaño del hueco, y así se mide
	# sobre una ficha que ya está puesta en pantalla.
	_model.show_scene(entry.get("scene"))


## Cuántos van a salir. Se apaga la flecha que ya no lleva a ningún sitio en vez
## de dejarla pulsable sin efecto: una flecha que no hace nada se lee como que la
## ventana se colgó.
func _set_squad(count: int) -> void:
	squad = clampi(count, 1, maxi(_squad_available, 1))
	_squad_count.text = str(squad)
	_squad_less.disabled = squad <= 1
	_squad_more.disabled = squad >= _squad_available
	# Apagada además de desactivada. El botón no tiene fondo que cambie de cara al
	# desactivarse —es la flecha y nada más—, así que sin atenuarla se ve igual de
	# viva que la otra y el jugador la sigue pulsando.
	_squad_less.modulate.a = 0.4 if _squad_less.disabled else 1.0
	_squad_more.modulate.a = 0.4 if _squad_more.disabled else 1.0
	_refresh_actions()


func _hide_detail() -> void:
	_chosen_type = null
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
	_clear(_options)
	# La lista sale de `PlayerFleet` y no del tipo de unidad: ahí las
	# configuraciones vienen **ya filtradas por las armas que el jugador tiene**,
	# así que lo que no se puede armar no aparece. Repetir la lista en el
	# `UnitType` daría dos sitios donde mirar y uno de los dos acabaría viejo.
	var offered: Array = entry.get("weapon_loadouts", [])
	for item in offered:
		var loadout := item as WeaponLoadout
		if loadout == null:
			continue
		var option: LoadoutOption = _OPTION.instantiate()
		option.text = loadout.display_name.to_upper()
		_options.add_child(option)
		option.set_selected(false)
		option.pressed.connect(_on_loadout_picked.bind(loadout, option))
	_clear_weapons(_PROMPT_PICK if not offered.is_empty() else _PROMPT_NONE)
	_open_loadout(false, _ANIM_TIME)


## Se ha elegido un armamento: se enciende su botón y sale lo que lleva colgado.
func _on_loadout_picked(loadout: WeaponLoadout, option: LoadoutOption) -> void:
	if is_instance_valid(_chosen_option):
		_chosen_option.set_selected(false)
	_chosen_option = option
	chosen_loadout = loadout
	option.set_selected(true)
	_refresh_actions()
	_point_marker_at(option)
	_show_weapons(loadout)


## Mueve la marca a la altura del botón elegido.
##
## Se lee la posición del botón en vez de contarla por su número de orden: el
## reparto de la columna lo hace el `VBoxContainer`, y si mañana cambia la
## separación o el alto de un botón, contar cuadraría mal. Aquí siempre se puede
## preguntar, porque esto sólo pasa al pulsar — mucho después de que el
## contenedor haya colocado a sus hijos.
func _point_marker_at(option: Control) -> void:
	_marker.show()
	_marker.position.y = roundf(_options.position.y + option.position.y
			+ (option.size.y - _marker.size.y) * 0.5)


## Las armas de una configuración, una ficha por tipo.
##
## Se **agrupan por arma y no por estación**: el Harrier lleva AIM-120 en la
## central y en la interna, y son dos montajes de dos, pero al jugador lo que le
## importa es que van cuatro. Cuántas hay lo dice el propio `WeaponLoadout`, que
## es de donde saca el avión las suyas — así el número del hangar y el del vuelo
## no pueden discrepar.
##
## Una carga puede sacar **una** de sus armas de la fila y subirla arriba, al
## lado del cañón: lo pide ella por su `self_defense`, no el arma. Sólo lo usa la
## que se queda estrecha —el Cobra en apoyo cercano, con cuatro—; en el resto el
## AIM-9 va en la fila como una más, igual que siempre.
##
## Arriba caben las dos porque esas fichas llevan el texto **debajo** del icono y
## miden 40: con el texto al lado son 63 y 75 —"SIDEWINDER" gasta 39 px él solo—
## y las dos juntas no entran en los 126 px de la fila.
func _show_weapons(loadout: WeaponLoadout) -> void:
	_clear(_cards)
	var seen: Array[WeaponType] = []
	var ordnance := 0
	for mount in loadout.mounts:
		if mount.weapon == null or seen.has(mount.weapon):
			continue
		seen.append(mount.weapon)
		if mount.weapon == loadout.self_defense:
			continue
		ordnance += 1
		var card: WeaponCard = _CARD.instantiate()
		_cards.add_child(card)
		card.show_weapon(mount.weapon, loadout.ammo_of(mount.weapon))
	# El cañón va aparte y encima, no en la fila: es del aparato y no de lo
	# elegido, así que no cambia al cambiar de armamento y no debe leerse como
	# una opción más.
	var cannon: WeaponType = _chosen_type.cannon if _chosen_type != null else null
	var rounds: int = _chosen_type.cannon_rounds if _chosen_type != null else 0
	_cannon.show_weapon(cannon, rounds)
	var guard := loadout.self_defense
	_self_defense.show_weapon(guard,
			loadout.ammo_of(guard) if guard != null else 0)
	# La fila de arriba se va entera cuando no tiene nada que enseñar: dejarla
	# puesta reservaría su alto y el panel se abriría con un hueco vacío encima.
	_fixed.visible = cannon != null or guard != null
	var empty := ordnance == 0 and cannon == null
	_cards.visible = not empty
	_loadout_prompt.visible = empty
	if empty:
		_say(_PROMPT_UNARMED)
	# Se abre del todo aunque no haya armas que enseñar: lo que hay abajo son los
	# botones de despegue, y un armamento sin nada colgado sigue siendo un
	# armamento elegido con el que se puede salir. Dejarlo cerrado escondería la
	# única forma de lanzar al Cobra.
	_open_loadout(true, _ANIM_TIME)


## Saca a cubierta lo elegido: tantos aparatos como diga la escuadrilla, con el
## armamento elegido y, si se dio, con la orden ya puesta.
##
## `order` viaja hasta la cubierta y **no se aplica aquí**: entre pulsar y volar
## hay ascensor, taxi y carrera, y el aparato ni siquiera existe todavía. Es la
## cubierta la que se la da cuando el avión pasa a pilotarse solo.
##
## Se lanza de uno en uno y se para al primer fallo: si la cubierta no tiene
## plaza, lo ya contado como desplegado se devuelve. Sin eso, la flota perdería
## aparatos que nunca llegaron a salir.
func launch(order: Dictionary = {}) -> void:
	if _ship == null or chosen_loadout == null or not is_instance_valid(_chosen):
		return
	var entry := _chosen.entry
	var deck: Node = _ship.get_node_or_null("FlightDeck")
	if deck == null or entry.is_empty():
		return
	# La escuadrilla sólo existe si van varios: uno solo no forma con nadie.
	var formation: Squad = Squad.new() if squad > 1 else null
	var out := 0
	for i in squad:
		if not PlayerFleet.try_deploy(entry):
			break
		if not deck.request_deploy(entry["scene"], formation, chosen_loadout, order):
			PlayerFleet.recall(entry)
			break
		out += 1
	if out <= 0:
		return
	launched.emit(entry, out)
	# La casilla enseña cuántos quedan, y acaban de salir varios. Se vuelve al
	# principio —sin aeronave elegida— porque lo que había elegido ya voló.
	_fill_slots()


## Enciende los botones sólo cuando hay algo que lanzar. Un botón que se deja
## pulsar y no hace nada se lee como que el juego se colgó.
func _refresh_actions() -> void:
	var ready := chosen_loadout != null and _squad_available > 0
	_take_off.disabled = not ready
	_targeted_take_off.disabled = not ready


## Deja el hueco del armamento vacío, con el aviso que toque.
func _clear_weapons(message: Array) -> void:
	_clear(_cards)
	_chosen_option = null
	chosen_loadout = null
	_refresh_actions()
	_marker.hide()
	_fixed.hide()
	_cannon.hide()
	_self_defense.hide()
	_cards.hide()
	_say(message)
	_loadout_prompt.show()


## Pone el aviso. El segundo renglón se va entero cuando no hay nada que poner
## en él, y con él el cursor: el `VBoxContainer` recentra lo que queda solo.
func _say(message: Array) -> void:
	_prompt_line1.text = message[0]
	_prompt_text.text = message[1]
	_prompt_line2.visible = message[1] != ""


## El parpadeo del cursor. Va sobre el alfa y no sobre `visible` porque el cursor
## vive dentro de un `HBoxContainer` centrado: esconderlo encogería la fila y
## "CONTINUE" se movería medio carácter a cada parpadeo.
func _start_blink() -> void:
	var blink := create_tween().set_loops()
	blink.tween_callback(func() -> void: _cursor.modulate.a = 0.0)
	blink.tween_interval(_BLINK)
	blink.tween_callback(func() -> void: _cursor.modulate.a = 1.0)
	blink.tween_interval(_BLINK)


## Vacía un contenedor **de verdad**, no al final del fotograma.
##
## `queue_free` sólo desengancha al terminar el fotograma, y hasta entonces el
## contenedor cuenta a los viejos y a los nuevos a la vez: la columna se desborda
## justo mientras aparece, que es cuando se está mirando.
func _clear(box: Node) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()


## Abre el bloque de armamento a uno de sus dos tamaños.
##
## Son dos pasos y no uno porque el panel guarda **lo que hay ahora**: antes de
## elegir sólo están los tres botones, y reservar el hueco de las armas deja un
## tercio de panel vacío esperando. Al elegir, el panel se estira y la ventana
## con él — el mismo gesto que ya hacía el bloque entero al aparecer.
##
## Crecen a la vez y en el mismo tiempo, y eso importa: el recorte de arriba va
## por el alto de la página, así que si el panel fuera más deprisa se saldría por
## abajo, y si fuera más despacio se vería el fondo de la ventana bajo él.
func _open_loadout(full: bool, seconds: float) -> void:
	_stop_fold()
	# Se enseña **antes** de pedir el alto: el bloque no se desvanece, se descubre
	# — está entero desde el primer fotograma y es el recorte el que lo va dejando
	# ver conforme la ventana crece.
	_loadout.show()
	# Los botones sólo con el panel abierto del todo, que es lo mismo que decir
	# "con un armamento ya elegido": antes de eso no hay nada que lanzar, y un par
	# de botones apagados esperando desde el principio no dicen eso.
	_actions.visible = full
	var bottom: float = _full_height() if full else _loadout_compact
	if is_zero_approx(seconds):
		_loadout.offset_bottom = bottom
	else:
		_fold = create_tween()
		_fold.tween_property(_loadout, ^"offset_bottom", bottom, seconds)
	size_wanted.emit(_width_wanted(), _clip.offset_top + bottom, seconds)


## `instant` es para cuando el panel ni siquiera estaba a la vista todavía —la
## ventana acabando de abrirse—, donde no hay gesto que suavizar.
func _hide_loadout(instant: bool = false) -> void:
	if not _loadout.visible:
		return
	_stop_fold()
	if instant:
		_shut_loadout()
		size_wanted.emit(0.0, _height_for(false), 0.0)
		return
	size_wanted.emit(0.0, _height_for(false), _ANIM_TIME)
	# Sigue visible mientras la ventana se cierra sobre él —el recorte lo va
	# comiendo— y se apaga al final. No es cosmético: un botón fuera del recorte
	# se deja pulsar igual, porque `clip_contents` recorta el dibujo y no el
	# ratón.
	_fold = create_tween()
	_fold.tween_interval(_ANIM_TIME)
	_fold.tween_callback(_shut_loadout)


## Lo apaga y lo deja del tamaño pequeño, que es como tiene que volver a salir.
## Sin esto, un panel que se cerró estirado se encogería a la vista al reabrirse.
func _shut_loadout() -> void:
	_loadout.hide()
	_actions.hide()
	_loadout.offset_bottom = _loadout_compact


## Lo alto que se pone el bloque de armamento desplegado.
##
## No es un número fijo de la escena: la columna de armas cambia de alto con lo
## que lleve la carga elegida — el Cobra en apoyo cercano enseña el AIM-9 encima
## y pide una fila más que los demás. **Crece a lo alto y no a lo ancho** porque
## a lo ancho la ventana tiene mínimo y a lo alto no.
##
## Se mide contra los dos lados del panel: la columna de armas de la derecha y la
## de botones de la izquierda, que sigue necesitando su sitio aunque no haya
## armas que enseñar. Todo sale de los `offset` de la escena, así que mover una
## pieza en el editor sigue mandando sobre el número.
func _full_height() -> float:
	var weapons_side := _weapons.offset_top + _column_height() - _weapons.offset_bottom
	var options_side := _options.offset_bottom + _LOADOUT_PAD + _actions_room
	return _loadout.offset_top + maxf(weapons_side, options_side)


## Lo que suman las filas de armas que están a la vista.
##
## Se cuentan a mano en vez de preguntarle al contenedor su tamaño mínimo: las
## fichas acaban de añadirse y el reparto todavía no ha corrido, así que el
## contenedor aún contesta con lo que medía antes.
func _column_height() -> float:
	var total := 0.0
	var rows := 0
	for child in _column.get_children():
		var part := child as Control
		if part == null or not part.visible:
			continue
		rows += 1
		total += part.custom_minimum_size.y
	if rows > 1:
		total += (rows - 1) * float(_column.get_theme_constant(&"separation"))
	return total


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


## Lo ancha que tiene que ser la página para que quepan las fichas de armas.
##
## Es lo único que pide ancho de más: todo lo demás cabe en la ventana tal y como
## está dibujada. Sale de contar las fichas y no de una tabla de configuraciones
## porque el número de armas es lo que manda, y una configuración nueva con
## cuatro se acomodaría sola.
##
## Sólo mira **la fila de armamento elegido**. La fija —cañón y autodefensa— va
## a propósito del mismo tamaño que una ficha normal (ver `Fixed` en la escena)
## para que quepa siempre dentro del ancho por defecto y nunca sea ella la que
## decida cuánto se ensancha la ventana.
func _width_wanted() -> float:
	var count := _cards.get_child_count()
	if count <= 0 or not _cards.visible:
		return 0.0
	var card := 0.0
	for child in _cards.get_children():
		card = maxf(card, (child as Control).custom_minimum_size.x)
	var gap := float(_cards.get_theme_constant(&"separation"))
	var row := count * card + (count - 1) * gap
	# El hueco empieza donde empieza el envoltorio y acaba donde acaba: sus dos
	# `offset` son el margen izquierdo y el derecho del área de armas.
	return _weapons.offset_left - _weapons.offset_right + row


func _stop_fold() -> void:
	if _fold != null and _fold.is_valid():
		_fold.kill()
	_fold = null
