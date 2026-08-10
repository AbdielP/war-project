extends RefCounted
class_name ThreatPulses

## Lleva la cuenta de los contactos que hay que señalar en un mapa: quién nos
## enganchó, desde dónde y hace cuánto.
##
## **Sólo lleva la cuenta; no dibuja.** El dibujo es de cada mapa, que sabe su
## escala y su tamaño — el minimapa y el mapa grande pintan el mismo contacto de
## formas muy distintas. Aquí está lo que comparten, que es *qué* señalar.
##
## Se engancha él solo a las unidades según aparecen, igual que el parte de
## eventos: nadie tiene que acordarse de avisarle.
##
## Cada mapa tiene la suya. Parece desperdicio y no lo es: **el mapa grande está
## oculto casi siempre, pero sigue apuntando lo que pasa**, así que al abrirlo se
## ven los contactos que siguen vivos en vez de una pantalla en blanco. Es justo
## lo que se espera al abrir el mapa porque algo sonó.

## Qué clase de contacto es. Cambia el color, no la forma.
enum Kind { TRACKED, FIRED_UPON }

## Segundos que dura un contacto en el mapa. Pasado eso deja de pintarse. Va en
## el mismo orden de magnitud que el silencio entre alarmas de `Unit`: más largo
## y los pulsos se solaparían consigo mismos.
const LIFETIME := 5.0

var _pulses: Array[Dictionary] = []


## Empieza a escuchar. Se le pasa un nodo del árbol porque esto no es un nodo y
## no tiene `get_tree()` propio.
func attach(node: Node) -> void:
	var tree := node.get_tree()
	if tree == null:
		return
	tree.node_added.connect(_watch)
	# El repaso inicial va diferido por lo mismo que en el parte de eventos: las
	# unidades que van después del HUD en la escena todavía no están en el grupo,
	# y `node_added` no las coge porque ya estaban en el árbol al conectarnos.
	_sweep.bind(tree).call_deferred()


func _sweep(tree: SceneTree) -> void:
	for node in tree.get_nodes_in_group(Unit.GROUP):
		_watch(node)


func _watch(node: Node) -> void:
	var unit := node as Unit
	if unit == null or unit.tracked_by.is_connected(_on_tracked):
		return
	unit.tracked_by.connect(_on_tracked.bind(unit))
	unit.fired_upon_by.connect(_on_fired_upon.bind(unit))


func _on_tracked(threat: Unit, unit: Unit) -> void:
	_add(threat, unit, Kind.TRACKED)


func _on_fired_upon(threat: Unit, unit: Unit) -> void:
	_add(threat, unit, Kind.FIRED_UPON)


## El mapa es del jugador: que a un enemigo lo apunte otro enemigo no le importa.
##
## Se guarda **dónde estaba la amenaza**, no dónde estaba el avión: lo que hay
## que señalar es de dónde vino el fuego. Y se guarda la posición, no la unidad,
## porque el contacto es un sitio y un momento — sigue valiendo aunque quien
## disparó se mueva o deje de existir.
func _add(threat: Unit, unit: Unit, kind: Kind) -> void:
	if not unit.is_player_controlled() or not is_instance_valid(threat):
		return
	_pulses.append({
		"where": threat.global_position,
		"born": Time.get_ticks_msec() / 1000.0,
		"kind": kind,
	})


## Los contactos que siguen vigentes, cada uno con lo que lleva encendido en
## segundos. De paso tira los caducados: no hace falta limpiarlos por otro lado
## si esto se pregunta cada vez que se dibuja.
##
## Devuelve `[{where, age, kind}]`, ya en orden de aparición.
func active() -> Array[Dictionary]:
	var now := Time.get_ticks_msec() / 1000.0
	var live: Array[Dictionary] = []
	for i in range(_pulses.size() - 1, -1, -1):
		var age: float = now - float(_pulses[i]["born"])
		if age > LIFETIME:
			_pulses.remove_at(i)
			continue
		live.append({
			"where": _pulses[i]["where"],
			"age": age,
			"kind": _pulses[i]["kind"],
		})
	live.reverse()
	return live


## ¿Hay algo que señalar ahora mismo? Lo usa quien quiera llamar la atención
## sobre el mapa entero —el propio minimapa parpadeando, por ejemplo— sin
## importarle los contactos uno a uno.
func any_active() -> bool:
	return not active().is_empty()
