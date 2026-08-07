extends Node2D

@export var camera_path: NodePath
@export var hud_path: NodePath

var _camera: PanCamera
var _hud: HUD
var _selected_unit: Unit
var _order_unit: Unit
var _move_marker: Node2D
## A quién se le está pintando el recuadro de objetivo. Es el objetivo de la
## unidad seleccionada y nada más: se apaga al deseleccionar y vuelve al
## seleccionarla otra vez, igual que el resto de la UI.
var _marked_target: Unit

const _MoveMarker = preload("res://core/selection/move_marker.gd")


func _ready() -> void:
	_camera = get_node(camera_path) as PanCamera
	_hud = get_node(hud_path) as HUD
	_camera.clicked.connect(_on_camera_clicked)
	_camera.long_pressed.connect(_on_context_requested)
	_hud.deselect_requested.connect(func() -> void: _select(null))
	_hud.unit_focus_requested.connect(func(unit: Unit) -> void: _select(unit))
	_hud.attack_requested.connect(_issue_attack_order)
	_hud.zoom_change_requested.connect(_camera.step_zoom)
	_hud.camera_move_requested.connect(_look_at)
	_camera.zoom_changed.connect(_hud.set_zoom_state)
	# La cámara ya fijó su nivel en su propio _ready(), antes de que hubiera
	# nadie escuchando: hay que pedirle el estado inicial a mano o los botones
	# arrancan sin saber si queda cuerda.
	_hud.set_zoom_state(_camera.zoom_level(), _camera.zoom_level_count())
	_move_marker = _MoveMarker.new()
	_move_marker.hide()
	# Diferido: en _ready() la escena todavía se está montando y Godot
	# rechaza el add_child (el marcador nunca llegaba a existir).
	get_tree().current_scene.add_child.call_deferred(_move_marker)


## Llevar la mirada a un punto del mapa. Suelta a quien estuviera siguiendo: si
## no, la cámara volvería a la unidad al frame siguiente y el mapa parecería roto.
func _look_at(world_position: Vector2) -> void:
	_camera.follow_target = null
	_camera.position = world_position


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_on_context_requested(get_global_mouse_position())
	elif event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		_hud.close_target_menu()
		_select(null)


## Click izquierdo o tap. Lo que hay debajo decide qué significa — el mismo
## gesto en PC y en táctil, sin gestos distintos por plataforma.
func _on_camera_clicked(world_position: Vector2) -> void:
	_hud.close_target_menu()
	var unit: Unit = _find_unit_at(world_position)
	if unit != null:
		# Con algo propio seleccionado, tocar a un hostil es atacarlo. Atacar
		# es lo frecuente; para mirarlo está la pulsación larga o el click
		# derecho.
		if _can_attack(unit):
			_issue_attack_order(unit)
		elif unit == _selected_unit:
			_select(null)
		else:
			_select(unit)
	elif _selected_unit != null:
		_issue_move_order(world_position)


## Click derecho (PC) o pulsación mantenida (táctil). Sobre una unidad ajena
## abre su menú; sobre el mapa sigue siendo una orden de movimiento.
func _on_context_requested(world_position: Vector2) -> void:
	var unit: Unit = _find_unit_at(world_position)
	if unit != null and not unit.is_player_controlled():
		_hud.open_target_menu(unit, _can_attack(unit))
		return
	_hud.close_target_menu()
	if _selected_unit != null:
		_issue_move_order(world_position)


func _can_attack(target: Unit) -> bool:
	return _selected_unit != null \
		and _selected_unit.is_player_controlled() \
		and _selected_unit.is_hostile_to(target)


func _find_unit_at(world_position: Vector2) -> Unit:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world_position
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var results := get_world_2d().direct_space_state.intersect_point(query, 1)
	if results.is_empty():
		return null
	var unit := results[0].collider as Unit
	# Click en cualquier integrante de un escuadrón selecciona al líder.
	return unit.squad.leader if unit != null and unit.squad != null else unit


func _select(unit: Unit) -> void:
	if _selected_unit != unit:
		if is_instance_valid(_selected_unit):
			_selected_unit.set_selected(false)
			if _selected_unit.attack_target_changed.is_connected(_mark_target):
				_selected_unit.attack_target_changed.disconnect(_mark_target)
		_selected_unit = unit
		if _selected_unit:
			_selected_unit.set_selected(true)
			# El objetivo puede cambiar sin tocar la selección — si muere, por
			# ejemplo —, así que el recuadro se engancha a la unidad.
			_selected_unit.attack_target_changed.connect(_mark_target)
			_hud.show_selected_unit(_selected_unit)
			_mark_target(_selected_unit.attack_target)
		else:
			_hud.clear_selected_unit()
			_mark_target(null)
	_camera.follow_target = _selected_unit


func _mark_target(target: Unit) -> void:
	# Misma trampa que en `Unit.set_attack_target`: comparar sólo sirve entre
	# objetos vivos, porque uno liberado se compara igual a `null`.
	if is_instance_valid(_marked_target) and _marked_target == target:
		return
	if is_instance_valid(_marked_target):
		_marked_target.set_targeted(false)
	_marked_target = target if is_instance_valid(target) else null
	if _marked_target != null:
		_marked_target.set_targeted(true)


func _issue_move_order(target: Vector2) -> void:
	if _selected_unit == null:
		return
	# Único portero de las órdenes: cubre el click derecho y el izquierdo en
	# vacío. Sin esto, ordenar a un enemigo no lo movía pero sí plantaba el
	# marcador, y parecía que había obedecido.
	if not _selected_unit.is_player_controlled():
		return
	_forget_order_unit()
	_order_unit = _selected_unit
	_selected_unit.receive_move_order(target)
	_move_marker.global_position = target
	_move_marker.show()
	if _selected_unit.has_signal("order_fulfilled"):
		_selected_unit.order_fulfilled.connect(_on_order_fulfilled, CONNECT_ONE_SHOT)


## El objetivo puede haber cambiado desde que se abrió el menú (otra unidad
## seleccionada, o ninguna), así que la condición se vuelve a comprobar aquí y
## no sólo al ofrecer la opción.
func _issue_attack_order(target: Unit) -> void:
	if not _can_attack(target):
		return
	_selected_unit.receive_attack_order(target)
	# Atacar cancela la orden de movimiento, así que su marcador ya no señala
	# nada: dejarlo puesto haría creer que el avión sigue yendo a ese punto.
	_clear_move_order()


func _on_order_fulfilled() -> void:
	# El marcador se queda donde está: sirve de referencia para ver dónde
	# se pidió el punto y cómo lo voló el avión.
	_order_unit = null


## Retira la orden de movimiento en curso: el marcador y el aviso de que se
## cumplió. Lo llama quien la sustituye por otra cosa.
func _clear_move_order() -> void:
	_forget_order_unit()
	_order_unit = null
	_move_marker.hide()


func _forget_order_unit() -> void:
	if _order_unit != null and is_instance_valid(_order_unit) \
			and _order_unit.has_signal("order_fulfilled"):
		if _order_unit.order_fulfilled.is_connected(_on_order_fulfilled):
			_order_unit.order_fulfilled.disconnect(_on_order_fulfilled)
