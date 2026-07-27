extends Node2D

@export var camera_path: NodePath
@export var hud_path: NodePath

var _camera: PanCamera
var _hud: HUD
var _selected_unit: Unit


func _ready() -> void:
	_camera = get_node(camera_path) as PanCamera
	_hud = get_node(hud_path) as HUD
	_camera.clicked.connect(_on_camera_clicked)


func _on_camera_clicked(world_position: Vector2) -> void:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world_position
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var results := get_world_2d().direct_space_state.intersect_point(query, 1)
	_select(results[0].collider as Unit if not results.is_empty() else null)


func _select(unit: Unit) -> void:
	if _selected_unit == unit:
		return
	if _selected_unit:
		_selected_unit.set_selected(false)
	_selected_unit = unit
	if _selected_unit:
		_selected_unit.set_selected(true)
		_hud.show_selected_unit(_selected_unit)
	else:
		_hud.clear_selected_unit()
