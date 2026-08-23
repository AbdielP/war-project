extends Camera2D
class_name PanCamera

signal clicked(world_position: Vector2)
## Pulsación mantenida sin arrastrar. Es el equivalente táctil del click
## derecho: en móvil no hay segundo botón, y un menú a un tap de distancia se
## comería el gesto de atacar, que es el que importa.
signal long_pressed(world_position: Vector2)
## Cambió el nivel de acercamiento. Lo escucha quien dibuje los botones, para
## saber cuándo ya no se puede seguir acercando o alejando.
signal zoom_changed(level: int, count: int)

@export var pan_button: MouseButton = MOUSE_BUTTON_LEFT
@export var click_threshold_px: float = 6.0
## Cuánto hay que mantener pulsado para que cuente como pulsación larga.
@export var long_press_time: float = 0.5

@export_group("Acercamiento")
## Niveles disponibles, del más lejano al más cercano. **Potencias de dos a
## propósito:** el juego es de escala entera y filtro Nearest, así que un 0,5
## descarta exactamente uno de cada dos píxeles del mundo. Un 0,75 dejaría un
## patrón irregular de píxeles descartados que hierve en cuanto la cámara se
## mueve. Alejarse más allá de 0,5 es trabajo del mapa táctico, no de esto.
@export var zoom_levels: PackedFloat32Array = [0.5, 1.0, 2.0]
## Con cuál arranca la partida. Índice dentro de `zoom_levels`.
@export var default_zoom_level: int = 1

var follow_target: Node2D = null

## Cuánto se aparta el objetivo seguido del centro de la pantalla, en píxeles
## de **pantalla** y no del mundo: así el barco se queda en el mismo sitio
## visual aunque el jugador acerque o aleje mientras dura el desvío.
var focus_offset: Vector2 = Vector2.ZERO

var _zoom_level: int = -1

var _press := LongPress.new()
var _last_position := Vector2.ZERO
var _focus_tween: Tween = null


func _ready() -> void:
	enabled = true
	_press.hold_time = long_press_time
	_press.move_threshold_px = click_threshold_px
	_fit_limits_to_map()
	set_zoom_level(default_zoom_level)


## Qué nivel está puesto y cuántos hay. Lo pregunta quien dibuje los botones al
## arrancar: la cámara emite `zoom_changed` en `_ready()`, y para entonces
## todavía no hay nadie conectado.
func zoom_level() -> int:
	return _zoom_level


func zoom_level_count() -> int:
	return zoom_levels.size()


## Sube o baja un escalón. Se queda en el extremo en vez de dar la vuelta: que
## el botón de acercar aleje del todo sería una trampa.
func step_zoom(step: int) -> void:
	set_zoom_level(_zoom_level + step)


func set_zoom_level(level: int) -> void:
	if zoom_levels.is_empty():
		return
	var clamped: int = clampi(level, 0, zoom_levels.size() - 1)
	if clamped == _zoom_level:
		return
	_zoom_level = clamped
	zoom = Vector2.ONE * zoom_levels[clamped]
	zoom_changed.emit(_zoom_level, zoom_levels.size())


## Desliza el objetivo seguido a un lado de la pantalla —a la izquierda con
## `screen_offset.x` positivo, porque eso mueve el *centro* de cámara hacia la
## derecha— para dejar sitio a un panel en el otro lado. `Vector2.ZERO` lo
## devuelve al centro. No hace nada sin un `follow_target`: sin objetivo no hay
## de qué apartarse.
func pan_focus(screen_offset: Vector2, duration: float = 0.6) -> void:
	if _focus_tween != null:
		_focus_tween.kill()
	_focus_tween = create_tween()
	_focus_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_focus_tween.tween_property(self, "focus_offset", screen_offset, duration)


func _process(delta: float) -> void:
	if _press.tick(delta):
		long_pressed.emit(get_global_mouse_position())
	if follow_target == null:
		return
	if not is_instance_valid(follow_target):
		follow_target = null
		return
	position = follow_target.global_position + focus_offset / zoom.x


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
			_press.press(event.position)
			_last_position = event.position
		elif _press.release():
			clicked.emit(get_global_mouse_position())
	elif event is InputEventMouseMotion and _press.is_pressed():
		if _press.moved(event.position):
			follow_target = null
		if _press.is_dragging():
			position -= (event.position - _last_position) / zoom
		_last_position = event.position
