extends Node2D

@export var taxi_speed: float = 30.0
@export var elevator_cycle_time: float = 2.0
@export var launch_delay: float = 2.0
@export var takeoff_speed: float = 120.0
@export var post_bow_distance: float = 80.0
@export var climb_duration: float = 2.5
@export var patrol_semi_x: float = 200.0  # semi-eje horizontal del óvalo
@export var patrol_semi_y: float = 280.0  # semi-eje vertical (a lo largo del barco)
@export var turn_rate: float = 2.0        # rad/s — velocidad de giro del avión en patrulla

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
var _patrol_planes: Array = []  # [{unit, angle, heading}]


func _process(delta: float) -> void:
	if _patrol_planes.is_empty():
		return
	var ship_pos: Vector2 = get_parent().global_position
	for i in range(_patrol_planes.size() - 1, -1, -1):
		var entry: Dictionary = _patrol_planes[i]
		var unit: Node2D = entry["unit"]
		if not is_instance_valid(unit):
			_patrol_planes.remove_at(i)
			continue

		# Avanza el ángulo de la elipse a velocidad lineal constante
		var angle: float = entry["angle"]
		var ds: float = sqrt(
			pow(patrol_semi_x * sin(angle), 2.0) +
			pow(patrol_semi_y * cos(angle), 2.0)
		)
		_patrol_planes[i]["angle"] -= (takeoff_speed / maxf(ds, 1.0)) * delta
		angle = _patrol_planes[i]["angle"]

		# Punto objetivo en la elipse y su tangente
		var ellipse_pos: Vector2 = ship_pos + Vector2(patrol_semi_x * cos(angle), patrol_semi_y * sin(angle))
		var tangent: Vector2 = Vector2(patrol_semi_x * sin(angle), -patrol_semi_y * cos(angle)).normalized()

		# Dirección deseada: mezcla tangente (en elipse) con corrección (fuera de ella)
		var to_ellipse: Vector2 = ellipse_pos - unit.global_position
		var dist: float = to_ellipse.length()
		var blend: float = clampf(dist / 150.0, 0.0, 0.85)
		var desired: Vector2 = tangent.lerp(to_ellipse.normalized(), blend).normalized()
		var desired_heading: float = atan2(desired.y, desired.x)

		# Giro con tasa máxima — no puede girar más rápido de turn_rate rad/s
		var current_heading: float = entry["heading"]
		var diff: float = wrapf(desired_heading - current_heading, -PI, PI)
		_patrol_planes[i]["heading"] = current_heading + clampf(diff, -turn_rate * delta, turn_rate * delta)

		var heading: float = _patrol_planes[i]["heading"]
		var move_dir: Vector2 = Vector2(cos(heading), sin(heading))

		# Posición y rotación derivadas del heading real — sin snaps
		unit.global_position += move_dir * takeoff_speed * delta
		unit.global_rotation = atan2(-move_dir.x, move_dir.y)


func _start_patrol(unit: Node2D) -> void:
	var ship_pos: Vector2 = get_parent().global_position
	var rel: Vector2 = unit.global_position - ship_pos
	var init_angle: float = atan2(
		rel.y / maxf(patrol_semi_y, 1.0),
		rel.x / maxf(patrol_semi_x, 1.0)
	)
	var fwd: Vector2 = unit.global_transform.y
	_patrol_planes.append({"unit": unit, "angle": init_angle, "heading": atan2(fwd.y, fwd.x)})
	# Si la unidad puede tomar control propio (ej. al recibir una orden), se retira del óvalo
	if unit.has_signal("taking_self_control"):
		unit.taking_self_control.connect(func() -> void:
			for i in range(_patrol_planes.size() - 1, -1, -1):
				if _patrol_planes[i]["unit"] == unit:
					_patrol_planes.remove_at(i)
					break
		, CONNECT_ONE_SHOT)


func request_deploy(scene: PackedScene, squad: Squad = null) -> bool:
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
	unit.scale = Vector2(0.7, 0.7)
	var slot: int = job["slot"]
	var squad: Squad = job["squad"]
	if squad != null:
		var u := unit as Unit
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

	_units[slot] = null
	_occupied[slot] = false

	var runway_dist: float = unit.global_position.distance_to(_launch_point.global_position)
	var runway_dur: float = 2.0 * runway_dist / maxf(takeoff_speed, 1.0)
	var post_duration: float = post_bow_distance / maxf(takeoff_speed, 1.0)

	var tw := unit.create_tween()
	tw.tween_property(unit, "global_position", _launch_point.global_position, runway_dur) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	tw.finished.connect(func() -> void:
		var direction: Vector2 = unit.global_transform.y
		var end_pos: Vector2 = unit.global_position + direction * post_bow_distance
		var fly_tw := unit.create_tween()
		fly_tw.tween_property(unit, "global_position", end_pos, post_duration)
		fly_tw.finished.connect(func() -> void: _start_patrol(unit))
		_scale_climb(unit)
		_launch_next(order)
	)


func _scale_climb(unit: Node2D) -> void:
	var steps: Array[float] = [0.8, 0.9, 1.0]
	var interval: float = climb_duration / float(steps.size())
	var tw := unit.create_tween()
	for s: float in steps:
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
