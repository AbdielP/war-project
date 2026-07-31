extends Camera2D
class_name PanCamera

signal clicked(world_position: Vector2)

@export var pan_button: MouseButton = MOUSE_BUTTON_LEFT
@export var click_threshold_px: float = 6.0

var follow_target: Node2D = null

var _dragging := false
var _drag_started := false
var _press_position := Vector2.ZERO
var _last_position := Vector2.ZERO


func _ready() -> void:
	enabled = true
	_fit_limits_to_map()


func _process(_delta: float) -> void:
	if follow_target == null:
		return
	if not is_instance_valid(follow_target):
		follow_target = null
		return
	position = follow_target.global_position


func _fit_limits_to_map() -> void:
	var layers := get_tree().root.find_children("*", "TileMapLayer", true, false)
	var bounds := Rect2()
	var has_bounds := false
	for layer: TileMapLayer in layers:
		var used: Rect2i = layer.get_used_rect()
		if used.size == Vector2i.ZERO:
			continue
		var tile_size := Vector2(layer.tile_set.tile_size)
		var world_rect := Rect2(
			layer.to_global(Vector2(used.position) * tile_size),
			Vector2(used.size) * tile_size
		)
		bounds = world_rect if not has_bounds else bounds.merge(world_rect)
		has_bounds = true
	if has_bounds:
		limit_left = int(bounds.position.x)
		limit_top = int(bounds.position.y)
		limit_right = int(bounds.position.x + bounds.size.x)
		limit_bottom = int(bounds.position.y + bounds.size.y)
		position = bounds.get_center()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == pan_button:
		if event.pressed:
			_dragging = true
			_drag_started = false
			_press_position = event.position
			_last_position = event.position
		else:
			_dragging = false
			if not _drag_started:
				clicked.emit(get_global_mouse_position())
	elif event is InputEventMouseMotion and _dragging:
		if not _drag_started and event.position.distance_to(_press_position) >= click_threshold_px:
			_drag_started = true
			follow_target = null
		if _drag_started:
			position -= (event.position - _last_position) / zoom
		_last_position = event.position
