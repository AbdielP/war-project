extends Node2D

@export var camera_path: NodePath
@export var hud_path: NodePath

@export_group("Ventana del buque")
## Cuánto se aparta el buque del centro al abrir su ventana, en píxeles de
## pantalla: un cuarto de los 640 de ancho de diseño, para dejarle sitio al
## panel del otro lado.
@export var vessel_focus_offset: Vector2 = Vector2(160.0, 0.0)
## Lo que tarda en apartarse al abrir.
@export var vessel_focus_time: float = 0.6
## Lo que tarda en volver al centro al cerrar. Más lento que la ida a propósito:
## al abrir aparece el panel y se lleva la atención, así que la cámara puede ir
## deprisa; al cerrar no hay nada nuevo que mirar y el tirón se nota.
@export var vessel_return_time: float = 0.9

var _camera: PanCamera
var _hud: HUD
var _selected_unit: Unit
var _order_unit: Unit
var _move_marker: MoveMarker
## A quién se le está pintando el recuadro de objetivo. Es el objetivo de la
## unidad seleccionada y nada más: se apaga al deseleccionar y vuelve al
## seleccionarla otra vez, igual que el resto de la UI.
var _marked_target: Unit

const _MOVE_MARKER = preload("res://core/selection/move_marker.tscn")


func _ready() -> void:
	_camera = get_node(camera_path) as PanCamera
	_hud = get_node(hud_path) as HUD
	_camera.clicked.connect(_on_camera_clicked)
	_camera.long_pressed.connect(_on_context_requested)
	_hud.deselect_requested.connect(func() -> void: _select(null))
	_hud.unit_focus_requested.connect(func(unit: Unit) -> void: _select(unit))
	_hud.attack_requested.connect(_issue_attack_order)
	_hud.return_requested.connect(_issue_return_order)
	_hud.zoom_change_requested.connect(_camera.step_zoom)
	_hud.map_clicked.connect(_on_map_clicked)
	_hud.map_context_requested.connect(_on_map_context_requested)
	_hud.look_requested.connect(_look_at)
	_hud.vessel_opened.connect(func(_unit: Unit) -> void:
			_camera.pan_focus(vessel_focus_offset, vessel_focus_time))
	_hud.vessel_closed.connect(func(instant: bool) -> void:
			_camera.pan_focus(Vector2.ZERO, 0.0 if instant else vessel_return_time))
	_camera.zoom_changed.connect(_hud.set_zoom_state)
	# La cámara ya fijó su nivel en su propio _ready(), antes de que hubiera
	# nadie escuchando: hay que pedirle el estado inicial a mano o los botones
	# arrancan sin saber si queda cuerda.
	_hud.set_zoom_state(_camera.zoom_level(), _camera.zoom_level_count())
	_move_marker = _MOVE_MARKER.instantiate()
	_move_marker.hide()
	# Diferido: en _ready() la escena todavía se está montando y Godot
	# rechaza el add_child (el marcador nunca llegaba a existir).
	get_tree().current_scene.add_child.call_deferred(_move_marker)


## Llevar la mirada a un punto del mapa. Suelta a quien estuviera siguiendo: si
## no, la cámara volvería a la unidad al frame siguiente y el mapa parecería roto.
func _look_at(world_position: Vector2) -> void:
	_camera.follow_target = null
	_camera.position = world_position


## Pulsar el mapa táctico es el mismo gesto que pulsar el mundo, y significa lo
## mismo: lo que haya debajo manda. Sólo cambia cómo se averigua qué hay debajo
## —el mapa lo resuelve contra los puntos que dibuja— y una excepción: sin nada
## propio que dirigir, pulsar terreno lleva la mirada allí, que es para lo que se
## abre el mapa.
func _on_map_clicked(world_position: Vector2, unit: Unit) -> void:
	_release_camera()
	if unit == null and not _has_own_selection():
		_look_at(world_position)
		return
	_handle_click(world_position, unit)


func _on_map_context_requested(world_position: Vector2, unit: Unit) -> void:
	_release_camera()
	_handle_context(world_position, unit)


## Tocar el mapa suelta la cámara de quien estuviera siguiendo. Si no, ordenar
## desde el mapa deja la vista pegada a la unidad y el recuadro de cámara se va
## de paseo con ella por todo el mapa mientras lo miras. Si el click acaba
## seleccionando a alguien, [method _select] vuelve a engancharla — eso sí se
## quiere.
func _release_camera() -> void:
	_camera.follow_target = null


func _has_own_selection() -> bool:
	return is_instance_valid(_selected_unit) and _selected_unit.is_player_controlled()


## La mira se decide aquí y no en el HUD porque son tres datos que sólo tiene
## este nodo: qué hay seleccionado, con qué puede disparar y qué hay debajo del
## ratón. Se mira cada fotograma porque nadie avisa de un cambio: el ratón se
## mueve, pero la unidad de debajo también, y la selección cambia por su cuenta.
func _process(_delta: float) -> void:
	_hud.aim_cursor(_can_shoot_whats_under_the_mouse())
	# Las cuatro esquinas del blanco se cierran contra el impacto, y ese dato lo
	# tiene el atacante, no él. Este nodo es el único sitio donde los dos están
	# emparejados, así que el recado lo pasa de aquí.
	if is_instance_valid(_marked_target) and is_instance_valid(_selected_unit):
		_marked_target.set_impact_eta(_selected_unit.get_time_to_impact())


## La mira sale exactamente cuando el clic sería una orden de fuego, ni un caso
## más: es la misma pregunta que se hace [method _handle_click], hecha antes de
## pulsar. Si dijeran cosas distintas, el cursor estaría prometiendo algo que el
## clic no cumple.
##
## Con una salvedad: **encima del HUD no hay mira** aunque debajo del panel haya
## un enemigo, porque ahí el clic se lo queda la interfaz y nunca llega al
## mundo. Se pregunta por el `Control` que hay bajo el ratón y no por una lista
## de paneles, que habría que mantener cada vez que se añade uno.
func _can_shoot_whats_under_the_mouse() -> bool:
	if not _has_own_selection():
		return false
	if get_viewport().gui_get_hovered_control() != null:
		return false
	var under := _find_unit_at(get_global_mouse_position())
	# A ese ya se le dio la orden: lo dicen sus cuatro esquinas, y la mira encima
	# repetiría el mismo dato tapándolas.
	if under != null and under == _selected_unit.attack_target:
		return false
	return _can_shoot(under)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_on_context_requested(get_global_mouse_position())
	elif event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		_hud.close_target_menu()
		_select(null)


## Click izquierdo o tap. Lo que hay debajo decide qué significa — el mismo
## gesto en PC y en táctil, sin gestos distintos por plataforma.
func _on_camera_clicked(world_position: Vector2) -> void:
	_handle_click(world_position, _find_unit_at(world_position))


## Qué significa un click izquierdo. Está aparte de quién lo trae porque el
## mundo y el mapa táctico lo comparten: cambia cómo se averigua qué hay debajo,
## no qué significa pulsarlo.
func _handle_click(world_position: Vector2, unit: Unit) -> void:
	_hud.close_target_menu()
	if unit != null:
		# Con algo propio y **armado** seleccionado, tocar a un hostil es
		# atacarlo. Atacar es lo frecuente; para mirarlo está la pulsación larga
		# o el click derecho. Sin armas no hay orden que dar y el clic vale lo
		# que vale sobre cualquier otra unidad: seleccionarla.
		if _can_shoot(unit):
			_issue_attack_order(unit)
		# Con una lancha seleccionada, pulsar el buque es volver a bordo. Es la
		# misma regla de siempre —lo que hay debajo decide qué significa el
		# click—, y va **antes** de seleccionar porque si no el buque se llevaría
		# el click y la orden no existiría.
		elif _can_board(unit):
			_issue_return_order(_selected_unit, _deck_of(unit))
		elif unit == _selected_unit:
			_select(null)
		else:
			_select(unit)
	elif _selected_unit != null:
		_issue_move_order(world_position)


## Click derecho (PC) o pulsación mantenida (táctil). Sobre una unidad ajena
## abre su menú; sobre el mapa sigue siendo una orden de movimiento.
func _on_context_requested(world_position: Vector2) -> void:
	_handle_context(world_position, _find_unit_at(world_position))


## Igual que [method _handle_click]: el significado del gesto, separado de si
## viene del mundo o del mapa táctico.
func _handle_context(world_position: Vector2, unit: Unit) -> void:
	if unit != null and not unit.is_player_controlled():
		_hud.open_target_menu(unit, _can_attack(unit))
		return
	_hud.close_target_menu()
	if _selected_unit != null:
		_issue_move_order(world_position)


func _can_attack(target: Unit) -> bool:
	return _has_own_selection() and _selected_unit.is_hostile_to(target)


## Si lo seleccionado puede subir a bordo de eso. Son tres condiciones y ninguna
## sobra: que lo nuestro sepa volver, que lo de debajo tenga dique, y que no sea
## de otro bando — abordar el buque enemigo es otra cosa muy distinta.
func _can_board(target: Unit) -> bool:
	if not _has_own_selection() or target == null:
		return false
	if not _selected_unit.has_method("return_to") or _selected_unit == target:
		return false
	if _selected_unit.is_hostile_to(target):
		return false
	return _deck_of(target) != null


## El dique de un buque, o `null` si no tiene. Se pregunta por la propiedad y no
## por la clase: un barco que no sepa recoger lanchas simplemente no lo lleva.
func _deck_of(vessel: Unit) -> WellDeck:
	return vessel.get("well_deck") as WellDeck if vessel != null else null


## Como [method _can_attack] pero además **con qué**.
##
## Son dos preguntas distintas y conviene no juntarlas: "son enemigos" no es
## "esta unidad puede dispararle". El buque no lleva cañón ni armamento —ataca
## con lo que despega, no por sí mismo—, así que un clic encima de un hostil no
## puede ser una orden de fuego suya. El menú del objetivo sigue usando la otra,
## la de sólo enemistad, porque ahí la opción de atacar se queda a la espera de
## que exista mandar una salida contra un blanco.
func _can_shoot(target: Unit) -> bool:
	return _can_attack(target) and not _selected_unit.get_weapons().is_empty()


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
	_move_marker.plant(target)
	_hud.show_order_marker(target)
	_hud.report_move_order(_selected_unit, target)
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


## Vuelve a bordo. `deck` vacío significa "a tu casa", que es lo que pide el
## botón: la lancha ya sabe de qué buque salió y no hay que decírselo. Pulsando
## un barco sí se dice, porque el jugador está señalando cuál.
##
## Cancela la orden de movimiento como hace atacar: su marcador dejaría plantado
## un destino al que la lancha ya no va.
func _issue_return_order(craft: Unit, deck: WellDeck = null) -> void:
	if not is_instance_valid(craft) or not craft.is_player_controlled():
		return
	if deck != null:
		craft.return_to(deck)
	elif craft.has_method("return_home"):
		craft.return_home()
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
	_hud.clear_order_marker()


func _forget_order_unit() -> void:
	if _order_unit != null and is_instance_valid(_order_unit) \
			and _order_unit.has_signal("order_fulfilled"):
		if _order_unit.order_fulfilled.is_connected(_on_order_fulfilled):
			_order_unit.order_fulfilled.disconnect(_on_order_fulfilled)
