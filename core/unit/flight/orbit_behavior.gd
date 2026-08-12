extends Node
class_name OrbitBehavior

## Decide A DÓNDE va el avión cuando no tiene otra orden: da vueltas alrededor
## de un centro. Si ese centro se mueve — el portaaviones navegando — el
## circuito se va con él, porque el punto se recalcula cada frame desde donde
## esté el barco ahora, no desde donde estaba al empezar.
##
## No hay ninguna figura impuesta. Al avión se le señala el sitio del círculo
## que tiene más cerca, corrido un poco hacia adelante en el sentido de giro:
##
##   - Si está por dentro o por fuera, ese sitio le queda hacia el círculo y
##     entra hacia él.
##   - Si ya está encima, le queda por delante y lo va recorriendo.
##
## Así el circuito no le impone una curva que a lo mejor no puede volar: le
## dice dónde tiene que estar, y la vuelta sale de su propio viraje. Por eso
## funciona con cualquier avión, gire como gire.

## Llegó al punto que ordenó el jugador. A partir de aquí orbita ahí.
signal center_reached

@export_group("Circuito")
## A qué distancia del barco esperan, en px.
##
## Tiene un suelo: nunca se usa un círculo más apretado que unas dos veces y
## media el viraje del avión. Por debajo de eso el avión no puede rodear nada
## — cada punto del círculo le cae dentro de su propio giro, así que endereza,
## se abre, y acaba dando vueltas donde no debe. Es lo que rompía el circuito
## viejo. Con el suelo puesto, tocar el viraje del avión ya no lo estropea.
@export var radius: float = 330.0
## Sentido de giro visto en pantalla.
@export var clockwise: bool = false

@export_group("Enlace")
@export var pilot_path: NodePath = ^"../PlaneController"

var _pilot: PlaneController
var _body: Node2D
var _center_node: Node2D = null
var _center_pos: Vector2 = Vector2.ZERO
var _approaching: bool = false
var _running: bool = false


func _ready() -> void:
	_body = get_parent() as Node2D
	_pilot = get_node_or_null(pilot_path) as PlaneController
	if _pilot != null:
		_pilot.target_reached.connect(_on_target_reached)
	set_physics_process(false)


## Orbita alrededor de un nodo que puede moverse (el portaaviones).
func orbit_around(node: Node2D) -> void:
	if _pilot == null:
		return
	_center_node = node
	_center_pos = node.global_position
	_approaching = false
	_running = true
	# Esperar es lo que hace un avión cuando no hay nada que hacer: se va al
	# ralentí. Sin esto daría vueltas a tope de gas sin ir a ningún sitio.
	_pilot.set_cruising(false)
	_pilot.set_target(_aim_point())
	set_physics_process(true)


## Va al punto indicado y, al llegar, orbita ahí. Es la orden del jugador.
func orbit_at(pos: Vector2) -> void:
	if _pilot == null:
		return
	_center_node = null
	_center_pos = pos
	_approaching = true
	_running = true
	# Esto sí es una orden: hay a dónde ir, así que mete gas hasta llegar.
	_pilot.set_cruising(true)
	_pilot.set_target(pos)
	set_physics_process(true)


## ¿Está yendo a un punto que ordenó el jugador? Sirve para que quien suelte al
## avión de cubierta no le pise una orden que ya tenía.
func has_pending_order() -> bool:
	return _running and _approaching


## Hacia dónde va, si es que va a algún sitio. El centro del circuito y el
## destino ordenado son el mismo punto: primero se vuela hasta él y después se
## le dan vueltas.
func get_destination() -> Vector2:
	return _center_node.global_position if is_instance_valid(_center_node) \
		else _center_pos


func stop() -> void:
	_running = false
	set_physics_process(false)
	if _pilot != null:
		_pilot.clear_target()


func _physics_process(_delta: float) -> void:
	if not _running or _approaching:
		return
	if is_instance_valid(_center_node):
		_center_pos = _center_node.global_position
	# Corrige el punto sin replantear el viraje que ya tiene comprometido.
	_pilot.update_target(_aim_point())


func _on_target_reached() -> void:
	# Sólo importa durante la aproximación: en órbita el punto se desliza solo
	# y nunca hay que "llegar" a nada.
	if _running and _approaching:
		_approaching = false
		center_reached.emit()
		# Llegó: se acabó la orden y con ella el gas. De aquí en adelante sólo
		# está esperando, y esperar se hace despacio.
		_pilot.set_cruising(false)
		_pilot.set_target(_aim_point())


## Dónde mandarlo ahora mismo: sobre el círculo, en la dirección en la que el
## avión ya está respecto al barco, adelantado en el sentido de giro.
func _aim_point() -> Vector2:
	var rel: Vector2 = _body.global_position - _center_pos
	# En el centro exacto su posición no señala ninguna dirección — el ángulo
	# saltaría de un frame a otro. Ahí manda hacia dónde apunta el morro.
	var bearing: float = rel.angle() if rel.length() > 1.0 else _pilot.heading
	var r := _ring_radius()
	return _center_pos + Vector2.RIGHT.rotated(bearing + _lead() * _step()) * r


## El círculo que se vuela de verdad: el pedido, o el mínimo que el avión puede
## rodear si le pidieron uno más apretado de la cuenta.
func _ring_radius() -> float:
	return maxf(radius, 2.5 * _pilot.min_turn_radius())


## Cuánto adelantar el punto, en radianes de recorrido. Sale del viraje del
## avión y no de un número fijo: hay que dejarle sitio para llegar girando, y
## ese sitio es más grande cuanto más abierto vira.
func _lead() -> float:
	return clampf(1.5 * _pilot.min_turn_radius() / _ring_radius(), 0.15, 1.4)


func _step() -> float:
	return 1.0 if clockwise else -1.0
