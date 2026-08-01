extends Unit

signal order_fulfilled
signal taking_self_control

@export var patrol_radius: float = 120.0
@export var turn_rate: float = 2.0
@export var patrol_speed: float = 120.0

enum _State { FLYING_TO, ORBITING }

var _patrol_active: bool = false
var _patrol_center: Vector2 = Vector2.ZERO
var _patrol_angle: float = 0.0
var _heading: float = 0.0
var _state: _State = _State.ORBITING


func _ready() -> void:
	super._ready()
	add_to_group("unit_air")


func _process(delta: float) -> void:
	if not _patrol_active:
		return
	match _state:
		_State.FLYING_TO:
			_process_fly_to(delta)
		_State.ORBITING:
			_process_orbit(delta)


func _process_fly_to(delta: float) -> void:
	var to_target: Vector2 = _patrol_center - global_position
	var dist: float = to_target.length()
	if dist < 30.0:
		# El punto de entrada al círculo queda adelante en la dirección que ya trae el avión
		_patrol_angle = _heading
		_state = _State.ORBITING
		order_fulfilled.emit()
		return
	var desired_heading: float = atan2(to_target.y, to_target.x)
	var diff: float = wrapf(desired_heading - _heading, -PI, PI)
	_heading += clampf(diff, -turn_rate * delta, turn_rate * delta)
	var move_dir: Vector2 = Vector2(cos(_heading), sin(_heading))
	global_position += move_dir * patrol_speed * delta
	global_rotation = atan2(-move_dir.x, move_dir.y)


func _process_orbit(delta: float) -> void:
	# Siempre CCW en pantalla (ángulo decreciente)
	_patrol_angle -= (patrol_speed / maxf(patrol_radius, 1.0)) * delta
	var angle: float = _patrol_angle
	var target_pos: Vector2 = _patrol_center + Vector2(patrol_radius * cos(angle), patrol_radius * sin(angle))
	var tangent: Vector2 = Vector2(sin(angle), -cos(angle))
	var to_target: Vector2 = target_pos - global_position
	var dist: float = to_target.length()
	var desired: Vector2
	if dist < 1.0:
		desired = tangent
	else:
		var blend: float = clampf(dist / 120.0, 0.0, 0.4)
		desired = tangent.lerp(to_target.normalized(), blend).normalized()
	var desired_heading: float = atan2(desired.y, desired.x)
	var diff: float = wrapf(desired_heading - _heading, -PI, PI)
	_heading += clampf(diff, -turn_rate * delta, turn_rate * delta)
	var move_dir: Vector2 = Vector2(cos(_heading), sin(_heading))
	global_position += move_dir * patrol_speed * delta
	global_rotation = atan2(-move_dir.x, move_dir.y)


func receive_move_order(target: Vector2) -> void:
	var fwd: Vector2 = global_transform.y
	_heading = atan2(fwd.y, fwd.x)
	_patrol_center = target
	_patrol_active = true
	_state = _State.FLYING_TO
	taking_self_control.emit()
