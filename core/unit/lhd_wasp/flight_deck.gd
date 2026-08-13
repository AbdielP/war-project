extends Node2D

@export var taxi_speed: float = 30.0
@export var elevator_cycle_time: float = 2.0
@export var launch_delay: float = 2.0
@export var post_bow_distance: float = 80.0
@export var climb_duration: float = 2.5

## Escala a la que sale el avión de cubierta; sube hasta 1.0 al despegar para
## simular que gana altura. En 1.0 el efecto queda apagado.
##
## Ojo con los valores fraccionarios: rompen el pixel art de los detalles
## finos (el cuerpo de un AIM-9 mide 1px, a 0.7 no se puede dibujar y el
## motor lo reparte entre dos columnas). Por eso está en 1.0 por defecto,
## en línea con la regla de escala entera del proyecto.
@export var spawn_scale: float = 1.0

# Elevator1 → TP2 primero, luego TP1. Elevator2 → TP4 primero, luego TP3.
const _ELEVATOR_SLOTS: Array = [[1, 0], [3, 2]]
# Waypoint intermedio por slot: TP2 pasa por TP1, TP4 pasa por TP3. -1 = directo.
const _SLOT_WAYPOINTS: Array = [-1, 0, -1, 2]

@onready var _elevators: Array[Marker2D] = [$Elevator1, $Elevator2]
@onready var _takeoff_points: Array[Marker2D] = [
	$TakeoffPoint1, $TakeoffPoint2, $TakeoffPoint3, $TakeoffPoint4
]
@onready var _launch_point: Marker2D = $LaunchPoint

var _occupied: Array[bool] = [false, false, false, false]
var _units: Array        = [null, null, null, null]
var _elevator_idx := 0
var _taxi_queues: Array  = [[], []]
var _taxiing: Array[bool] = [false, false]
var _launching := false


## Suelta el avión: a partir de aquí se pilota solo. La cubierta no vuelve
## a tocarlo.
func _hand_over_control(unit: Node2D) -> void:
	if not is_instance_valid(unit):
		return
	if unit.has_method("start_flight"):
		unit.start_flight(get_parent())


func request_deploy(scene: PackedScene, squad: Squad = null,
		weapon_loadout: WeaponLoadout = null) -> bool:
	var elev_idx: int = _elevator_idx % _elevators.size()
	var slot := _next_slot_for_elevator(elev_idx)
	if slot == -1:
		return false

	var elevator: Marker2D = _elevators[elev_idx]
	_elevator_idx += 1
	_occupied[slot] = true

	_taxi_queues[elev_idx].append({
		"scene": scene,
		"slot": slot,
		"spawn_pos": elevator.global_position,
		"spawn_rot": elevator.global_rotation,
		"squad": squad,
		"weapon_loadout": weapon_loadout,
	})
	_process_queue(elev_idx)
	return true


func has_free_slot() -> bool:
	for i in _occupied.size():
		if not _occupied[i]:
			return true
	return false


func _process_queue(elev_idx: int) -> void:
	if _taxiing[elev_idx] or _taxi_queues[elev_idx].is_empty():
		return
	var job: Dictionary = _taxi_queues[elev_idx].pop_front()

	_taxiing[elev_idx] = true

	var unit: Node2D = job["scene"].instantiate()
	get_tree().current_scene.add_child(unit)
	unit.global_position = job["spawn_pos"]
	unit.global_rotation = job["spawn_rot"]
	unit.scale = Vector2.ONE * spawn_scale
	var slot: int = job["slot"]
	var u := unit as Unit
	if u != null:
		u.set_weapon_loadout(job["weapon_loadout"])
		var squad: Squad = job["squad"]
		if squad != null:
			u.squad = squad
			squad.add(u, slot)
	unit.tree_exited.connect(func() -> void:
		_occupied[slot] = false
		_units[slot] = null
	)

	get_tree().create_timer(elevator_cycle_time).timeout.connect(func() -> void:
		_taxiing[elev_idx] = false
		_process_queue(elev_idx)
	)

	var target: Marker2D = _takeoff_points[slot]
	var waypoint_idx: int = _SLOT_WAYPOINTS[slot]

	var tw := unit.create_tween()

	if waypoint_idx >= 0:
		var wp: Marker2D = _takeoff_points[waypoint_idx]
		var d1 := unit.global_position.distance_to(wp.global_position)
		tw.tween_property(unit, "global_position", wp.global_position,
				d1 / taxi_speed if taxi_speed > 0.0 else 0.01)
		tw.tween_callback(func() -> void: unit.global_rotation = wp.global_rotation)
		var d2 := wp.global_position.distance_to(target.global_position)
		tw.tween_property(unit, "global_position", target.global_position,
				d2 / taxi_speed if taxi_speed > 0.0 else 0.01)
	else:
		var d := unit.global_position.distance_to(target.global_position)
		tw.tween_property(unit, "global_position", target.global_position,
				d / taxi_speed if taxi_speed > 0.0 else 0.01)

	tw.finished.connect(func() -> void:
		unit.global_rotation = target.global_rotation
		_units[slot] = unit
		_check_ready_to_launch()
	)


func _check_ready_to_launch() -> void:
	if _launching:
		return
	if not _taxi_queues[0].is_empty() or not _taxi_queues[1].is_empty():
		return
	for i in _occupied.size():
		if _occupied[i] and _units[i] == null:
			return
	_launching = true
	get_tree().create_timer(launch_delay).timeout.connect(_start_launch_sequence)


func _start_launch_sequence() -> void:
	var order: Array = []
	for i in range(_units.size() - 1, -1, -1):
		if is_instance_valid(_units[i]):
			order.append(i)
	_launch_next(order)


func _launch_next(order: Array) -> void:
	if order.is_empty():
		_launching = false
		return
	var slot: int = order.pop_front()
	var unit: Node2D = _units[slot]
	if not is_instance_valid(unit):
		_launch_next(order)
		return

	# Lo que no despega por pista se queda donde está. Un helicóptero llega a su
	# sitio en cubierta y ahí espera: no tiene carrera que hacer ni proa que
	# rebasar, así que meterlo en esta secuencia lo mandaría deslizándose hacia
	# adelante como si fuera un avión.
	#
	# Se sabe preguntándole a él —`get_takeoff_speed()` a 0— y no con una lista
	# de modelos: la cubierta no tiene por qué conocer qué aparatos existen.
	if _launch_speed_of(unit) <= 1.0:
		_launch_next(order)
		return

	_units[slot] = null
	_occupied[slot] = false

	var launch_speed := _launch_speed_of(unit)
	var runway_dist: float = unit.global_position.distance_to(_launch_point.global_position)
	# Arranca parado y acelera. Con un ease-in cuadrático, recorrer `runway_dist`
	# en este tiempo deja al avión yendo exactamente a `launch_speed` al llegar
	# a la proa: el factor 2 es la media de una aceleración constante, no un
	# número puesto a ojo. De ahí en adelante ya vuela a esa velocidad, que es
	# la misma con la que el piloto recoge el control.
	var runway_dur: float = 2.0 * runway_dist / launch_speed
	var post_duration: float = post_bow_distance / launch_speed

	var tw := unit.create_tween()
	tw.tween_property(unit, "global_position", _launch_point.global_position, runway_dur) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	tw.finished.connect(func() -> void:
		var direction: Vector2 = unit.global_transform.y
		var end_pos: Vector2 = unit.global_position + direction * post_bow_distance
		var fly_tw := unit.create_tween()
		fly_tw.tween_property(unit, "global_position", end_pos, post_duration)
		fly_tw.finished.connect(func() -> void: _hand_over_control(unit))
		_scale_climb(unit)
		_launch_next(order)
	)


## A qué velocidad sale de cubierta este avión. Se lo pregunta a él: cada
## modelo tiene la suya y es la misma con la que el piloto recoge el control.
##
## La cubierta no tiene velocidad de despegue propia, y tenerla era justo el
## problema: lanzaba a 120 a un avión que como mucho vuela a 90, así que el
## piloto lo recortaba en silencio y el avión "frenaba" al soltar amarras.
func _launch_speed_of(unit: Node2D) -> float:
	var speed := 0.0
	if unit.has_method("get_takeoff_speed"):
		speed = float(unit.get_takeoff_speed())
	return maxf(speed, 1.0)


## Sube la escala de `spawn_scale` a 1.0 en tres saltos. Si el avión ya sale
## a 1.0 no hay nada que animar.
func _scale_climb(unit: Node2D) -> void:
	if is_equal_approx(spawn_scale, 1.0):
		return
	const STEPS := 3
	var interval: float = climb_duration / float(STEPS)
	var tw := unit.create_tween()
	for i in STEPS:
		var s: float = lerpf(spawn_scale, 1.0, float(i + 1) / float(STEPS))
		tw.tween_interval(interval)
		tw.tween_callback(func() -> void:
			if is_instance_valid(unit):
				unit.scale = Vector2(s, s)
		)


func _next_slot_for_elevator(elev_idx: int) -> int:
	var priority: Array = _ELEVATOR_SLOTS[elev_idx % _ELEVATOR_SLOTS.size()]
	for slot in priority:
		if not _occupied[slot]:
			return slot
	return -1
