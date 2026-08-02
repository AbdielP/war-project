extends Node
class_name OrbitBehavior

## Decide A DÓNDE va el avión cuando no tiene otra orden: da vueltas
## alrededor de un centro.
##
## El óvalo no es un riel. Se le pone al avión un punto de referencia sobre
## la elipse siempre un poco por delante de donde está, y el avión lo
## persigue. La curva que se ve la produce el piloto al volarla, con su
## inercia y su radio de giro reales — nadie le impone la posición.

## Llegó al punto que ordenó el jugador. A partir de aquí orbita ahí.
signal center_reached

@export_group("Óvalo")
## Semi-eje horizontal, en píxeles.
@export var semi_x: float = 200.0
## Semi-eje vertical, en píxeles.
@export var semi_y: float = 280.0
## Cuánto por delante se pone el punto de referencia, en grados de recorrido.
## Poco = el avión ciñe el óvalo pero va nervioso. Mucho = vuelo suelto y
## suave que corta las curvas.
@export_range(5.0, 170.0, 1.0) var lead_deg: float = 35.0
## Sentido de giro visto en pantalla.
@export var clockwise: bool = false

@export_group("Avanzado")
## Por debajo de esta fracción del óvalo, la posición del avión no dice hacia
## dónde va el circuito: en el centro exacto el ángulo es indeterminado y
## saltaría 180° de un frame a otro. Ahí manda el rumbo del avión.
@export_range(0.05, 0.9, 0.01) var center_deadzone: float = 0.25
## Con qué rapidez el punto de referencia se engancha a dónde está el avión.
@export var sync_rate: float = 2.5

@export_group("Enlace")
@export var pilot_path: NodePath = ^"../PlaneController"

var _pilot: PlaneController
var _body: Node2D
var _center_node: Node2D = null
var _center_pos: Vector2 = Vector2.ZERO
var _phase: float = 0.0
var _approaching: bool = false
var _running: bool = false


func _ready() -> void:
	_body = get_parent() as Node2D
	_pilot = get_node_or_null(pilot_path) as PlaneController
	if _pilot != null:
		_pilot.target_reached.connect(_on_target_reached)
	set_process(false)


## Orbita alrededor de un nodo que puede moverse (el portaaviones).
func orbit_around(node: Node2D) -> void:
	if _pilot == null:
		return
	_center_node = node
	_center_pos = node.global_position
	_approaching = false
	_running = true
	_reset_phase()
	_pilot.set_target(_point_at(_phase))
	set_process(true)


## Va al punto indicado y, al llegar, orbita ahí. Es la orden del jugador.
func orbit_at(pos: Vector2) -> void:
	if _pilot == null:
		return
	_center_node = null
	_center_pos = pos
	_approaching = true
	_running = true
	_pilot.set_target(pos)
	set_process(true)


func stop() -> void:
	_running = false
	set_process(false)
	if _pilot != null:
		_pilot.clear_target()


func _process(delta: float) -> void:
	if not _running or _approaching:
		return
	if is_instance_valid(_center_node):
		_center_pos = _center_node.global_position

	# La fase avanza sola, al ritmo al que vuela el avión. Nunca da saltos.
	_phase += _step() * (_pilot.speed / maxf(_arc_scale(_phase), 1.0)) * delta

	# Y se engancha a dónde está el avión de verdad — pero sólo si está lo
	# bastante lejos del centro para que su posición signifique algo.
	var off: float = _off_center()
	if off > center_deadzone:
		var want: float = _phase_of_body() + deg_to_rad(lead_deg) * _step()
		_phase += angle_difference(_phase, want) * clampf(sync_rate * delta, 0.0, 1.0)

	# Corrige el punto sin replantear el viraje que ya tiene comprometido.
	_pilot.update_target(_point_at(_phase))


func _on_target_reached() -> void:
	# Sólo importa durante la aproximación: en órbita el punto se desliza
	# solo y nunca hay que "llegar" a nada.
	if _running and _approaching:
		_approaching = false
		center_reached.emit()
		_reset_phase()
		_pilot.set_target(_point_at(_phase))


## Engancha el circuito. Si el avión está sobre el óvalo, por donde está; si
## está en el centro (recién llegado a un punto ordenado), por delante del
## morro — ahí su posición no define ningún ángulo.
func _reset_phase() -> void:
	if _off_center() > center_deadzone:
		_phase = _phase_of_body() + deg_to_rad(lead_deg) * _step()
	else:
		var h: float = _pilot.heading
		_phase = atan2(semi_x * sin(h), semi_y * cos(h))


func _point_at(a: float) -> Vector2:
	return _center_pos + Vector2(semi_x * cos(a), semi_y * sin(a))


## Fase de la elipse que corresponde a la posición actual del avión.
func _phase_of_body() -> float:
	var rel: Vector2 = _body.global_position - _center_pos
	return atan2(rel.y / maxf(semi_y, 1.0), rel.x / maxf(semi_x, 1.0))


## Cuán lejos del centro está el avión, en fracciones del óvalo (1.0 = encima).
func _off_center() -> float:
	var rel: Vector2 = _body.global_position - _center_pos
	return sqrt(
		pow(rel.x / maxf(semi_x, 1.0), 2.0) + pow(rel.y / maxf(semi_y, 1.0), 2.0))


## Cuánto avanza el punto por radián de fase: la elipse no es un círculo, así
## que la velocidad angular tiene que variar para que la lineal sea constante.
func _arc_scale(a: float) -> float:
	return sqrt(pow(semi_x * sin(a), 2.0) + pow(semi_y * cos(a), 2.0))


func _step() -> float:
	return 1.0 if clockwise else -1.0
