extends Node2D

@export var taxi_speed: float = 30.0  # px/s — ajustable en el Inspector

# Elevator1 → TP2 primero, luego TP1. Elevator2 → TP4 primero, luego TP3.
const _ELEVATOR_SLOTS: Array = [[1, 0], [3, 2]]
# Waypoint intermedio por slot: TP2 pasa por TP1, TP4 pasa por TP3. -1 = directo.
const _SLOT_WAYPOINTS: Array = [-1, 0, -1, 2]

@onready var _elevators: Array[Marker2D] = [$Elevator1, $Elevator2]
@onready var _takeoff_points: Array[Marker2D] = [
	$TakeoffPoint1, $TakeoffPoint2, $TakeoffPoint3, $TakeoffPoint4
]

var _occupied: Array[bool] = [false, false, false, false]
var _elevator_idx := 0
var _taxi_queues: Array = [[], []]   # una cola por elevador
var _taxiing: Array[bool] = [false, false]


func request_deploy(scene: PackedScene) -> bool:
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
	unit.tree_exited.connect(func() -> void: _occupied[slot] = false)

	var target: Marker2D = _takeoff_points[slot]
	var waypoint_idx: int = _SLOT_WAYPOINTS[slot]

	var tw := unit.create_tween()

	if waypoint_idx >= 0:
		var wp: Marker2D = _takeoff_points[waypoint_idx]
		var d1 := unit.global_position.distance_to(wp.global_position)
		tw.tween_property(unit, "global_position", wp.global_position,
				d1 / taxi_speed if taxi_speed > 0.0 else 0.01)
		# Al llegar al waypoint el avión ya salió del elevador — se libera para el siguiente
		tw.tween_callback(func() -> void:
			unit.global_rotation = wp.global_rotation
			_taxiing[elev_idx] = false
			_process_queue(elev_idx)
		)
		var d2 := wp.global_position.distance_to(target.global_position)
		tw.tween_property(unit, "global_position", target.global_position,
				d2 / taxi_speed if taxi_speed > 0.0 else 0.01)
		tw.finished.connect(func() -> void:
			unit.global_rotation = target.global_rotation
		)
	else:
		var d := unit.global_position.distance_to(target.global_position)
		tw.tween_property(unit, "global_position", target.global_position,
				d / taxi_speed if taxi_speed > 0.0 else 0.01)
		tw.finished.connect(func() -> void:
			unit.global_rotation = target.global_rotation
			_taxiing[elev_idx] = false
			_process_queue(elev_idx)
		)


func _next_slot_for_elevator(elev_idx: int) -> int:
	var priority: Array = _ELEVATOR_SLOTS[elev_idx % _ELEVATOR_SLOTS.size()]
	for slot in priority:
		if not _occupied[slot]:
			return slot
	return -1
