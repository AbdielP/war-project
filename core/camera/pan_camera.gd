extends Camera2D
class_name PanCamera

signal clicked(world_position: Vector2)
## Pulsación mantenida sin arrastrar. Es el equivalente táctil del click
## derecho: en móvil no hay segundo botón, y un menú a un tap de distancia se
## comería el gesto de atacar, que es el que importa.
signal long_pressed(world_position: Vector2)

@export var pan_button: MouseButton = MOUSE_BUTTON_LEFT
@export var click_threshold_px: float = 6.0
## Cuánto hay que mantener pulsado para que cuente como pulsación larga.
@export var long_press_time: float = 0.5

var follow_target: Node2D = null

var _dragging := false
var _drag_started := false
var _long_fired := false
var _press_time := 0.0
var _press_position := Vector2.ZERO
var _last_position := Vector2.ZERO


func _ready() -> void:
	enabled = true
	_fit_limits_to_map()


func _process(delta: float) -> void:
	_tick_long_press(delta)
	if follow_target == null:
		return
	if not is_instance_valid(follow_target):
		follow_target = null
		return
	position = follow_target.global_position


## Se dispara sin soltar el botón, como en cualquier menú contextual táctil:
## el aviso llega mientras el dedo sigue apoyado, no al levantarlo.
func _tick_long_press(delta: float) -> void:
	if not _dragging or _drag_started or _long_fired:
		return
	_press_time += delta
	if _press_time >= long_press_time:
		_long_fired = true
		long_pressed.emit(get_global_mouse_position())


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
			_long_fired = false
			_press_time = 0.0
			_press_position = event.position
			_last_position = event.position
		else:
			_dragging = false
			# Si ya se atendió como pulsación larga, soltar no es un click:
			# si no, el menú se abriría y acto seguido llegaría la orden.
			if not _drag_started and not _long_fired:
				clicked.emit(get_global_mouse_position())
	elif event is InputEventMouseMotion and _dragging:
		if not _drag_started and event.position.distance_to(_press_position) >= click_threshold_px:
			_drag_started = true
			follow_target = null
		if _drag_started:
			position -= (event.position - _last_position) / zoom
		_last_position = event.position
