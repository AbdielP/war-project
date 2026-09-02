extends Control
class_name TroopsPage

## La página de tropas: la fuerza de desembarco del buque y la lancha que la
## lleva a la playa.
##
## Es el mismo mueble que el hangar —rejilla a la izquierda, ficha a la derecha—
## y a propósito: son la misma pregunta hecha sobre otra cosa, y dos ventanas
## parecidas pero distintas se leen como dos juegos.
##
## **Lo que cambia es la decisión.** El hangar pregunta *cuántos mando*; aquí se
## pregunta *qué cabe*. Un Abrams gasta la lancha entera y con lo mismo van cuatro
## LAV, así que el panel de abajo no es una lista de opciones sino un reparto de
## plazas — la misma forma que el armamento de una aeronave.
##
## Y hay una unidad que no necesita lancha: el Amtrac nada. Ésa es la elección
## que hace que la pantalla valga la pena — ir solo, lento y expuesto, o
## embarcado, rápido y jugándose toda la carga si hunden la lancha.

## Cuánto sitio pide la página, igual que el hangar: lo escucha la ventana, que
## es la única que sabe cuánto marco hay que añadir por fuera.
signal size_wanted(width: float, height: float, seconds: float)

## Se ha cargado o descargado algo. Por ahora sólo lo escucha esta misma página;
## sale como señal porque el día que exista el dique inundable será él quien
## tenga que enterarse, no ella quien se lo diga.
signal manifest_changed

## El jugador quiere señalar la orilla en el mapa. La página no conoce el mapa
## —ni tiene por qué—: avisa, y quien sabe abrirlo lo abre y vuelve con la
## respuesta por [method land_at].
signal beach_requested

const _SLOT := preload("res://ui/hud/vessel_window/aircraft_slot.tscn")

## Lo que dice el botón de salida antes de haber elegido orilla. Después dice la
## coordenada: el botón **es** el sitio donde vive esa decisión, así que enseñar
## ahí la respuesta ahorra un rótulo y no deja dudas de a qué se refiere.
const _LAND_ASK := "SELECT BEACH"
const _LAND_CHOSEN := "BEACH %s"

## Lo que dice el hueco de la ficha cuando no hay nada elegido.
const _PROMPT_PICK := "SELECT A UNIT"
## Y cuando el buque no lleva tropa embarcada. Son dos cosas distintas: "elige"
## y "no hay nada que elegir".
const _PROMPT_EMPTY := "NO TROOPS EMBARKED"

## Blanco para lo que está lleno y el gris azulado de la paleta para lo vacío,
## que es el mismo par que usan las solapas del hangar.
const _ON := Color(1.0, 1.0, 1.0)
const _OFF := Color(0.60784316, 0.67058825, 0.69803923)
## El amarillo de la paleta, el mismo de los botones al pulsarlos. Marca lo que
## el jugador está a punto de meter: las plazas que ocuparía lo que tiene
## elegido, dibujadas sobre las que ya están llenas.
const _PENDING := Color(0.8352941, 0.87843137, 0.29411766)

## La tira de la barra de potencia, igual que en el hangar: diez dibujos de 5 px
## apilados, del vacío al lleno.
const _POWER_STEPS := 10
const _POWER_BAR_HEIGHT := 5.0

@onready var _content: NinePatchRect = $Content
@onready var _slots: GridContainer = $Content/Slots
@onready var _prompt: Label = $Content/Prompt
@onready var _detail: Control = $Content/Detail
@onready var _detail_name: Label = $Content/Detail/Name
@onready var _model: UnitModel = $Content/Detail/Model
@onready var _power: TextureRect = $Content/Detail/Stats/PowerBar
@onready var _size_value: Label = $Content/Detail/Stats/SizeValue
@onready var _count: Label = $Content/Detail/Stats/Count
@onready var _count_max: Label = $Content/Detail/Stats/Max
@onready var _less: Button = $Content/Detail/Stats/Less
@onready var _more: Button = $Content/Detail/Stats/More

@onready var _craft: NinePatchRect = $Craft
@onready var _craft_name: Label = $Craft/Name
@onready var _craft_left: Label = $Craft/Left
@onready var _pips: HBoxContainer = $Craft/Pips
@onready var _cargo: Label = $Craft/Cargo
@onready var _manifest: VBoxContainer = $Craft/Manifest
@onready var _manifest_row: Label = $Craft/Manifest/Row
@onready var _load_btn: Button = $Craft/Actions/Load
@onready var _clear_btn: Button = $Craft/Actions/Clear
@onready var _land_btn: Button = $Craft/Actions/Land

var _ship: Node2D = null
var _chosen: AircraftSlot = null
## Cuántos de lo elegido se van a embarcar de una vez.
var _amount: int = 1
## Lo que va dentro de la lancha: `[{entry, count}]`. Se guarda la entrada de la
## flota y no el tipo, porque al descargar hay que devolvérselos a ella.
var _cargo_manifest: Array = []
## La entrada de la lancha en uso. Hoy sólo hay una clase; el día que haya LCU
## esto pasa a ser una elección más.
var _craft_entry: Dictionary = {}
## La orilla elegida, o `null`. Se guarda el punto **y** su coordenada escrita:
## el punto es para la lancha y el texto para el botón, y volver a deducir el
## segundo del primero daría dos formas de nombrar el mismo sitio.
var _beach: Variant = null
var _beach_label: String = ""
## Si en este mapa hay alguna playa a la que llegar. Lo dice el HUD al abrir la
## ventana; arranca en `true` para que la página abierta a pelo con F6 —sin mapa
## que la prepare— enseñe el botón vivo y se pueda ajustar en el editor.
var _can_land := true


func _ready() -> void:
	# La fila de muestra vive en la escena para poder colocarla en el editor, y
	# se apaga aquí: es el molde del que salen las de verdad.
	_manifest_row.hide()
	_less.pressed.connect(func() -> void: _set_amount(_amount - 1))
	_more.pressed.connect(func() -> void: _set_amount(_amount + 1))
	_load_btn.pressed.connect(_on_load)
	_clear_btn.pressed.connect(_on_clear)
	_land_btn.pressed.connect(beach_requested.emit)
	# El inventario ya no cambia sólo cuando se pulsa aquí: una lancha que atraca
	# devuelve su plaza sin que la interfaz haya hecho nada, y con la ventana
	# abierta el panel se quedaba enseñando el número de antes.
	PlayerFleet.changed.connect(_on_fleet_changed)
	_hide_detail()


## Algo salió o volvió. Se repintan las casillas y el panel de la lancha, no se
## rehace la rejilla: reconstruirla soltaría la unidad que el jugador tiene
## elegida en mitad de estar mirándola.
func _on_fleet_changed() -> void:
	if _ship == null:
		return
	for child in _slots.get_children():
		var slot := child as AircraftSlot
		if slot != null:
			slot.refresh()
	_refresh_craft()


func show_for(vessel: Node2D) -> void:
	_ship = vessel
	_craft_entry = {}
	var craft: Array = PlayerFleet.get_craft(_ship.unit_name) if _ship != null else []
	if not craft.is_empty():
		_craft_entry = craft[0]
	_cargo_manifest.clear()
	_beach = null
	_beach_label = ""
	_fill_slots()
	_refresh_craft()


func _fill_slots() -> void:
	# Fuera del contenedor antes de encolarlos para borrar: `queue_free` sólo los
	# quita al final del fotograma, y hasta entonces la rejilla reparte entre los
	# viejos y los nuevos a la vez.
	for child in _slots.get_children():
		_slots.remove_child(child)
		child.queue_free()
	_chosen = null
	_hide_detail()
	if _ship == null:
		return
	for entry: Dictionary in PlayerFleet.get_troops(_ship.unit_name):
		var slot: AircraftSlot = _SLOT.instantiate()
		_slots.add_child(slot)
		slot.show_aircraft(entry, _icon_of(entry))
		slot.picked.connect(_on_slot_picked.bind(slot))


## El `UnitType` de una entrada. Hay que abrir la escena porque la lista guarda
## el `PackedScene`; se instancia y se suelta en el acto, sin entrar en el árbol.
func _type_of(entry: Dictionary) -> UnitType:
	var scene: PackedScene = entry.get("scene")
	if scene == null:
		return null
	var unit := scene.instantiate()
	var type: UnitType = unit.unit_type
	unit.free()
	return type


func _icon_of(entry: Dictionary) -> Texture2D:
	var type := _type_of(entry)
	if type == null:
		return null
	return type.hangar_icon if type.hangar_icon != null else type.portrait_icon


func _on_slot_picked(entry: Dictionary, slot: AircraftSlot) -> void:
	if is_instance_valid(_chosen):
		_chosen.set_selected(false)
	_chosen = slot
	slot.set_selected(true)
	_show_detail(entry)


## La ficha de la unidad elegida. Ocupa el mismo hueco que el aviso de "elige
## una", así que se turnan: los dos dicen qué hay ahí, desde lados opuestos.
func _show_detail(entry: Dictionary) -> void:
	var type := _type_of(entry)
	if type == null:
		_hide_detail()
		return
	_prompt.hide()
	_detail.show()
	_detail_name.text = type.display_name.to_upper()
	_model.show_scene(entry.get("scene"))
	_show_power(type.power)
	# El Amtrac no gasta plazas porque no las necesita: se dice con la palabra y
	# no con un cero, que se leería como "no ocupa nada dentro de la lancha".
	_size_value.text = "SWIMS" if type.amphibious else "%d" % type.deck_slots
	_size_value.add_theme_color_override(&"font_color",
			_PENDING if type.amphibious else _ON)
	_set_amount(1)


func _hide_detail() -> void:
	_detail.hide()
	_prompt.show()
	var vacio: bool = _ship == null or PlayerFleet.get_troops(_ship.unit_name).is_empty()
	_prompt.text = _PROMPT_EMPTY if vacio else _PROMPT_PICK
	_refresh_pips()
	_refresh_actions()


## La barra de potencia: no se estira ni se rellena de color, cada paso está
## dibujado. Aquí sólo se elige cuál de los diez se enseña.
func _show_power(value: int) -> void:
	var atlas := _power.texture as AtlasTexture
	if atlas == null:
		return
	var step: int = clampi(value, 0, _POWER_STEPS - 1)
	var r := atlas.region
	atlas.region = Rect2(r.position.x, step * _POWER_BAR_HEIGHT, r.size.x, _POWER_BAR_HEIGHT)


## Cuántos se embarcan de una vez. El tope es lo que quede sin desplegar **y** lo
## que quepa en la lancha: pasarse de cualquiera de los dos no es una cantidad
## válida, así que el botón no deja llegar.
func _set_amount(value: int) -> void:
	var tope := _max_amount()
	# Con la lancha llena el tope es cero, y entonces la cantidad también. Dejarla
	# en 1 al lado de un "MAX 0" es el panel contradiciéndose: dice que va a meter
	# uno y a la vez que no cabe ninguno.
	_amount = 0 if tope <= 0 else clampi(value, 1, tope)
	_count.text = "%d" % _amount
	_count_max.text = "MAX %d" % tope
	_less.disabled = _amount <= 1
	_more.disabled = _amount >= tope
	_refresh_pips()
	_refresh_actions()


## Lo máximo que se puede embarcar de lo elegido ahora mismo.
func _max_amount() -> int:
	if not is_instance_valid(_chosen) or _chosen.entry.is_empty():
		return 0
	var entry: Dictionary = _chosen.entry
	var quedan: int = int(entry.get("total", 0)) - int(entry.get("deployed", 0))
	var type := _type_of(entry)
	if type == null:
		return 0
	# Lo que nada no ocupa plaza, así que sólo lo limita el inventario.
	if type.amphibious:
		return quedan
	if type.deck_slots <= 0:
		return 0
	return mini(quedan, int(_free_slots() / float(type.deck_slots)))


func _capacity() -> int:
	var type := _type_of(_craft_entry) if not _craft_entry.is_empty() else null
	return type.cargo_slots if type != null else 0


func _used_slots() -> int:
	var used := 0
	for line: Dictionary in _cargo_manifest:
		used += int(line["slots"]) * int(line["count"])
	return used


func _free_slots() -> int:
	return maxi(_capacity() - _used_slots(), 0)


## Los cuadraditos de capacidad: llenos lo que ya va dentro, en amarillo lo que
## se metería si se pulsa cargar ahora, apagados los que sobran.
##
## Enseñar lo pendiente en su propio color es lo que convierte la barra en una
## respuesta: **"¿me cabe esto?"** se contesta mirando, sin restar de cabeza.
func _refresh_pips() -> void:
	var cap := _capacity()
	var used := _used_slots()
	var pending := 0
	if is_instance_valid(_chosen) and not _chosen.entry.is_empty():
		var type := _type_of(_chosen.entry)
		if type != null and not type.amphibious:
			pending = mini(type.deck_slots * _amount, cap - used)
	for i in _pips.get_child_count():
		var pip := _pips.get_child(i) as ColorRect
		if pip == null:
			continue
		pip.visible = i < cap
		if i < used:
			pip.color = _ON
		elif i < used + pending:
			pip.color = _PENDING
		else:
			pip.color = _OFF
	_cargo.text = "CARGO %d/%d" % [used, cap]


## La lista de lo que va dentro. Las filas salen del molde que vive en la escena
## y se recolocan solas; sin nada dentro, la lista no ocupa: un hueco reservado y
## vacío se lee como que algo se rompió.
func _refresh_manifest() -> void:
	for child in _manifest.get_children():
		if child == _manifest_row:
			continue
		_manifest.remove_child(child)
		child.queue_free()
	for line: Dictionary in _cargo_manifest:
		var row: Label = _manifest_row.duplicate()
		row.text = "%s x%d" % [str(line["name"]).to_upper(), int(line["count"])]
		row.show()
		_manifest.add_child(row)


func _refresh_craft() -> void:
	if _craft_entry.is_empty():
		_craft.hide()
		return
	_craft.show()
	var type := _type_of(_craft_entry)
	_craft_name.text = type.display_name.to_upper() if type != null else "?"
	var quedan := _craft_available()
	_craft_left.text = "%d/%d" % [quedan, int(_craft_entry.get("total", 0))]
	_refresh_pips()
	_refresh_manifest()
	_refresh_actions()


func _refresh_actions() -> void:
	_load_btn.disabled = _max_amount() <= 0
	_clear_btn.disabled = _cargo_manifest.is_empty()
	# **Salir es una decisión completa**: se elige carga y destino y la lancha se
	# va. Por eso la puerta es llevar algo dentro — una lancha vacía cruzando el
	# mapa no es una orden, es un paseo—, y también que haya orilla a la que ir:
	# un botón que abre el mapa para elegir algo que no existe promete lo que no
	# puede cumplir.
	# Y que quede lancha: el manifiesto se llena aunque no haya ninguna, porque
	# elegir qué embarcar sigue teniendo sentido con la última en el agua.
	_land_btn.disabled = _cargo_manifest.is_empty() or not _can_land \
			or _craft_available() <= 0
	_land_btn.text = _LAND_ASK if _beach == null \
			else _LAND_CHOSEN % _beach_label


## Embarca lo elegido. Comprobar, descontar y apuntar en una sola llamada, como
## la compra del puerto: repartido en pasos, quien carga puede quedarse a medias
## si falla el de en medio.
func _on_load() -> void:
	if not is_instance_valid(_chosen) or _chosen.entry.is_empty():
		return
	var entry: Dictionary = _chosen.entry
	var type := _type_of(entry)
	if type == null:
		return
	var cuantos := mini(_amount, _max_amount())
	if cuantos <= 0:
		return
	for i in cuantos:
		if not PlayerFleet.try_deploy(entry):
			break
		_add_to_manifest(entry, type)
	_chosen.refresh()
	_set_amount(1)
	_refresh_craft()
	manifest_changed.emit()


## Una línea por modelo, no una por unidad: cuatro LAV son "LAV-25 x4" y no
## cuatro renglones iguales.
func _add_to_manifest(entry: Dictionary, type: UnitType) -> void:
	for line: Dictionary in _cargo_manifest:
		if line["entry"] == entry:
			line["count"] = int(line["count"]) + 1
			return
	_cargo_manifest.append({
		"entry": entry,
		"name": type.display_name,
		"slots": 0 if type.amphibious else type.deck_slots,
		"count": 1,
	})


## Vacía la lancha y devuelve todo a la flota. Es lo contrario de cargar y no
## "cancelar": lo que se deshace es el embarque, no la elección.
func _on_clear() -> void:
	for line: Dictionary in _cargo_manifest:
		for i in int(line["count"]):
			PlayerFleet.recall(line["entry"])
	_cargo_manifest.clear()
	# Con la lancha vacía ya no hay salida que hacer, así que la orilla elegida
	# tampoco: dejarla puesta sería el botón anunciando el destino de un viaje
	# que se acaba de deshacer.
	_beach = null
	_beach_label = ""
	for child in _slots.get_children():
		var slot := child as AircraftSlot
		if slot != null:
			slot.refresh()
	_set_amount(1)
	_refresh_craft()
	manifest_changed.emit()


## Si en este mapa hay orilla a la que desembarcar. Se lo dice el HUD, que es
## quien conoce el terreno; la página sólo lo enseña.
func set_landing_possible(value: bool) -> void:
	_can_land = value
	_refresh_actions()


## El jugador señaló la orilla en el mapa: la lancha sale.
##
## **Elegir playa ES la salida**, no apuntar un destino para zarpar después.
## Carga y destino son una sola decisión, igual que en el hangar se le apunta el
## blanco al avión antes de soltarlo; partirlo en dos pasos obligaría a volver a
## esta pantalla para pulsar un segundo botón que no diría nada nuevo.
##
## Quien manda la lancha es el dique, no esta página: aquí sólo se sabe qué se
## eligió. Y la carga sale de la ficha con la escena de cada modelo, porque quien
## la va a crear es el buque y no le toca averiguar de qué eran esas filas.
func land_at(where: Vector2, label: String) -> void:
	_beach = where
	_beach_label = label
	var dique: WellDeck = _well_deck()
	var carga := _cargo_for_launch()
	if dique == null or _craft_scene() == null or carga.is_empty():
		_refresh_actions()
		return
	# Se descuenta la lancha **antes** de mandarla y se devuelve si el dique no
	# la acepta. Al revés —mandarla y descontarla después— una salida rechazada
	# dejaría navegando una lancha que la flota sigue teniendo en el pañol.
	if not PlayerFleet.try_deploy(_craft_entry):
		_refresh_actions()
		return
	if not dique.launch(_craft_entry, carga, where):
		PlayerFleet.recall(_craft_entry)
		_refresh_actions()
		return
	# Ya no está en el buque: el manifiesto se vacía y la ficha vuelve a su
	# estado de partida. Lo que iba dentro se descontó al embarcarlo.
	_cargo_manifest.clear()
	_beach = null
	_beach_label = ""
	_set_amount(1)
	_refresh_craft()
	manifest_changed.emit()


## El dique del buque que se está mirando, o `null` si no tiene. Se pregunta por
## el método y no por la clase: un buque que no sepa desembarcar simplemente no
## lo tiene, y eso no es un error que haya que tratar.
func _well_deck() -> WellDeck:
	if _ship == null:
		return null
	return _ship.get("well_deck") as WellDeck


## Cuántas lanchas quedan en el buque. Es el mismo número que enseña el rótulo
## de arriba a la derecha de su panel.
func _craft_available() -> int:
	if _craft_entry.is_empty():
		return 0
	return int(_craft_entry.get("total", 0)) - int(_craft_entry.get("deployed", 0))


func _craft_scene() -> PackedScene:
	return _craft_entry.get("scene") if not _craft_entry.is_empty() else null


## El manifiesto tal como lo necesita quien va a crear la tropa: la escena de
## cada modelo y cuántos van. Se traduce aquí, en la ficha, porque es donde se
## sabe que una fila del manifiesto guarda la entrada de la flota.
func _cargo_for_launch() -> Array:
	var carga: Array = []
	for line: Dictionary in _cargo_manifest:
		var entry: Dictionary = line["entry"]
		# La casilla de la flota viaja con la carga: si la lancha vuelve sin
		# haber desembarcado, es lo que le permite devolver cada carro a su sitio.
		carga.append({
			"entry": entry,
			"scene": entry.get("scene"),
			"count": int(line["count"]),
		})
	return carga


## Lo que mide la página: hasta donde acaba el panel de la lancha. Sale de los
## `offset` de la escena y no de un número escrito aquí, para que mover las cosas
## en el editor siga mandando.
func wanted_height() -> float:
	if _craft == null or not _craft.visible:
		return _content.offset_bottom
	return _craft.offset_top + _craft.size.y
