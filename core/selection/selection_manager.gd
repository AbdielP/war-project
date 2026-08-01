extends Node2D

@export var camera_path: NodePath
@export var hud_path: NodePath

var _camera: PanCamera
var _hud: HUD
var _selected_unit: Unit
var _order_unit: Unit
var _move_marker: Node2D

const _MoveMarker = preload("res://core/selection/move_marker.gd")


func _ready() -> void:
	_camera = get_node(camera_path) as PanCamera
	_hud = get_node(hud_path) as HUD
	_camera.clicked.connect(_on_camera_clicked)
	_hud.deselect_requested.connect(func() -> void: _select(null))
	_hud.unit_focus_requested.connect(func(unit: Unit) -> void: _select(unit))
	_move_marker = _MoveMarker.new()
	get_tree().current_scene.add_child(_move_marker)
	_move_marker.hide()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _selected_unit != null:
			_issue_move_order(get_global_mouse_position())
	elif event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		_select(null)


func _on_camera_clicked(world_position: Vector2) -> void:
	var unit: Unit = _find_unit_at(world_position)
	if unit != null:
		if unit == _selected_unit:
			_select(null)
		else:
			_select(unit)
	elif _selected_unit != null:
		_issue_move_order(world_position)


func _find_unit_at(world_position: Vector2) -> Unit:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world_position
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var results := get_world_2d().direct_space_state.intersect_point(query, 1)
	return results[0].collider as Unit if not results.is_empty() else null


func _select(unit: Unit) -> void:
	if _selected_unit != unit:
		if _selected_unit:
			_selected_unit.set_selected(false)
		_selected_unit = unit
		if _selected_unit:
			_selected_unit.set_selected(true)
			_hud.show_selected_unit(_selected_unit)
		else:
			_hud.clear_selected_unit()
	_camera.follow_target = _selected_unit
	_move_marker.visible = (_selected_unit != null and _selected_unit == _order_unit)


func _issue_move_order(target: Vector2) -> void:
	if _selected_unit == null:
		return
	# Desconectar señal anterior si existía
	if _order_unit != null and is_instance_valid(_order_unit) and _order_unit.has_signal("order_fulfilled"):
		if _order_unit.order_fulfilled.is_connected(_on_order_fulfilled):
			_order_unit.order_fulfilled.disconnect(_on_order_fulfilled)
	_order_unit = _selected_unit
	_selected_unit.receive_move_order(target)
	_move_marker.global_position = target
	_move_marker.show()
	if _selected_unit.has_signal("order_fulfilled"):
		_selected_unit.order_fulfilled.connect(_on_order_fulfilled, CONNECT_ONE_SHOT)


func _on_order_fulfilled() -> void:
	_order_unit = null
	_move_marker.hide()
