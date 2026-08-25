extends CanvasLayer
class_name HUD

signal deselect_requested
signal unit_focus_requested(unit: Unit)
## El jugador eligió "Atacar" en el menú de una unidad ajena.
signal attack_requested(target: Unit)
## Pidió acercar (+1) o alejar (−1). El HUD no conoce la cámara: reenvía y ya.
signal zoom_change_requested(step: int)
## Pulsó el mapa táctico, con la unidad que hubiera bajo el punto o `null`.
## Mismo trato que el zoom: se reenvía a quien sepa qué hacer con ello.
signal map_clicked(world_position: Vector2, unit: Unit)
## Lo mismo con el botón derecho.
signal map_context_requested(world_position: Vector2, unit: Unit)
## Pulsó una coordenada del registro de eventos: llevar la mirada allí.
signal look_requested(world_position: Vector2)
## Se abrió la ventana de un buque: quien tenga la cámara puede apartarla hacia
## un lado para dejarle sitio al panel.
signal vessel_opened(unit: Unit)
## Se cerró: la cámara puede volver al centro. Con `instant` no hay que animar
## la vuelta — la vista ya está saltando a otra unidad.
signal vessel_closed(instant: bool)

@onready var _event_log: EventLog = $EventLog
@onready var _selection_panel: Control = $SelectionPanel
@onready var _actions_panel: PanelContainer = $ActionsPanel
@onready var _hangar_window: PanelContainer = $HangarWindow
@onready var _vessel_window: VesselWindow = $VesselWindow
@onready var _desel_btn: Button = $DeselButton
@onready var _deployed_panel: PanelContainer = $DeployedPanel
@onready var _weapon_bar: Control = $WeaponBar
@onready var _countermeasure_bar: CountermeasureBar = $CountermeasureBar
@onready var _target_menu: PanelContainer = $TargetMenu
@onready var _attack_label: Label = $AttackLabel
@onready var _impact_timer: Label = $ImpactTimer
@onready var _zoom_controls: VBoxContainer = $ZoomControls
@onready var _minimap: Minimap = $Minimap
@onready var _tactical_map: TacticalMap = $TacticalMap
@onready var _unit_tag: UnitTag = $UnitTag
@onready var _cursor: MouseCursor = $Cursor

## Dónde se pone la cuenta atrás respecto al objetivo, en píxeles de pantalla:
## arriba y un poco a la derecha, para no taparlo ni pisar su recuadro.
const _IMPACT_OFFSET := Vector2(10.0, -14.0)

## Lo que dice el mapa mientras se elige a dónde mandar una salida del hangar.
const _LAUNCH_HINT := "Pulsa un blanco o un punto — la salida despegará con esa orden"

var _current_unit: Unit = null

## El mapa está abierto para señalar el blanco de una salida del hangar, no para
## dar órdenes. El siguiente click significa otra cosa mientras esto esté puesto.
var _picking_launch_target := false


func _ready() -> void:
	_actions_panel.action_pressed.connect(_on_action_pressed)
	_weapon_bar.weapon_selected.connect(_on_weapon_selected)
	_target_menu.attack_requested.connect(func(t: Unit) -> void: attack_requested.emit(t))
	# "Información" es, por ahora, seleccionarla: es lo único que hay que ver
	# de una unidad. Cuando exista una ficha de verdad, cambia aquí.
	_target_menu.info_requested.connect(func(t: Unit) -> void: unit_focus_requested.emit(t))
	_deployed_panel.unit_selected.connect(func(unit: Unit) -> void: unit_focus_requested.emit(unit))
	_desel_btn.add_theme_color_override("font_color", Color(0.6705882, 0.5803922, 0.4784314))
	_desel_btn.add_theme_color_override("font_hover_color", Color(0.56078434, 0.827451, 1.0))
	_desel_btn.add_theme_color_override("font_pressed_color", Color(0.56078434, 0.827451, 1.0))
	_desel_btn.pressed.connect(func() -> void: deselect_requested.emit())
	_zoom_controls.zoom_change_requested.connect(
			func(step: int) -> void: zoom_change_requested.emit(step))
	_event_log.look_requested.connect(
			func(where: Vector2) -> void: look_requested.emit(where))
	# "Comandar" abre la pantalla del buque. La etiqueta no sabe cuál es: sólo
	# dice que quieren entrar, y aquí se decide qué se abre.
	_unit_tag.boarding_requested.connect(func(unit: Unit) -> void:
		_vessel_window.open(unit)
		vessel_opened.emit(unit))
	_vessel_window.closed.connect(
			func(instant: bool) -> void: vessel_closed.emit(instant))
	# El minimapa se estira a mano y crece hacia arriba, justo hacia donde está
	# el registro. Que se aparte él, que es el que no lo pidió.
	_minimap.resized.connect(_push_event_log_above_minimap)
	_push_event_log_above_minimap()
	_minimap.expand_requested.connect(_tactical_map.open)
	_vessel_window.target_requested.connect(_on_launch_target_requested)
	_tactical_map.clicked.connect(_on_tactical_map_clicked)
	_tactical_map.context_requested.connect(
			func(where: Vector2, unit: Unit) -> void: map_context_requested.emit(where, unit))
	# La barra de armas es lo único que sobra con el mapa abierto: cae justo
	# encima del terreno y ahí no se dispara nada. El resto del HUD se queda.
	_tactical_map.opened.connect(_refresh_weapon_bar)
	_tactical_map.closed.connect(_refresh_weapon_bar)
	# Cerrar el mapa sin pulsar nada cancela la elección de blanco. Sin esto, el
	# siguiente click en el mapa —hecho para otra cosa— lanzaría la salida.
	_tactical_map.closed.connect(func() -> void:
		_picking_launch_target = false
		_tactical_map.set_hint_override(""))


## El hangar pide que el jugador señale a dónde va la salida.
##
## El mapa sube al frente porque la ventana del buque se puso encima al abrirse,
## y un mapa a pantalla completa por debajo de una ventana no se puede pulsar.
func _on_launch_target_requested() -> void:
	_picking_launch_target = true
	_tactical_map.set_hint_override(_LAUNCH_HINT)
	_tactical_map.open()
	_tactical_map.move_to_front()


## Un click en el mapa. Casi siempre es una orden para lo que esté seleccionado
## —y de eso sabe quien lleva la selección, no el HUD—, pero mientras se está
## eligiendo el blanco de una salida significa otra cosa y no debe salir de aquí.
func _on_tactical_map_clicked(where: Vector2, unit: Unit) -> void:
	if _picking_launch_target:
		_picking_launch_target = false
		_tactical_map.set_hint_override("")
		_tactical_map.close()
		_vessel_window.launch_at(where, unit)
		return
	map_clicked.emit(where, unit)


## Hasta dónde puede seguir acercándose o alejándose. Se lo dice quien tiene la
## cámara delante — el HUD no la conoce.
func set_zoom_state(level: int, count: int) -> void:
	_zoom_controls.set_state(level, count)


## La cuenta atrás vive con la selección, igual que el recuadro del objetivo:
## es lo que está disparando la unidad que miras, no un adorno del mapa. Si
## deseleccionas, desaparece; al volver a seleccionarla, vuelve.
func _process(_delta: float) -> void:
	var target := _current_unit.attack_target if is_instance_valid(_current_unit) else null
	if not is_instance_valid(target) or not _counts_down_to_impact(target):
		_impact_timer.hide()
		return
	var eta := _current_unit.get_time_to_impact()
	if eta < 0.0:
		# No hay nada en el aire: entre disparo y disparo no se cuenta nada.
		_impact_timer.hide()
		return
	_impact_timer.text = "%.1f" % eta
	_impact_timer.position = target.get_global_transform_with_canvas().origin \
		+ _IMPACT_OFFSET
	_impact_timer.show()


## ¿Tiene sentido contar cuánto falta para el impacto?
##
## Sólo con un arma que **persigue** a un blanco de tierra, que es cuando la
## cuenta significa algo: soltaste algo desde lejos y hay una espera real hasta
## saber si acertaste.
##
## Fuera de eso estorba:
##   - **En combate aéreo** todo pasa en segundos y el número no da tiempo ni a
##     leerse; además el duelo se resuelve por posición, no esperando.
##   - **Con el cañón** no hay nada en el aire que esperar: el daño es inmediato.
##
## El tercer caso —**la bomba tonta**, que cae donde cae y no promete impacto—
## no se decide aquí: lo dice el propio proyectil con `guides()`, y por eso
## `get_time_to_impact()` ya devuelve -1 con ellas.
func _counts_down_to_impact(target: Unit) -> bool:
	var weapon: WeaponType = _current_unit.active_weapon
	if weapon == null or target.get_domain() == UnitType.Domain.AIR:
		return false
	return weapon.fire_mode == WeaponType.FireMode.LAUNCHER


func show_selected_unit(unit: Unit) -> void:
	_disconnect_current()
	_current_unit = unit
	# Cambiar de unidad se lleva por delante la ventana del buque: enseñaba el
	# interior de la anterior. Y sin animar la vuelta al centro, porque la vista
	# ya está saltando a otro sitio.
	_vessel_window.close(true)
	# La unidad entera y no sólo su nombre: la caja lleva una cámara en vivo
	# apuntándola, así que necesita a quién mirar.
	_selection_panel.show_unit(unit)
	_actions_panel.show_actions(unit.get_actions() if unit.is_player_controlled() else [])
	_refresh_weapon_bar()
	# El objetivo puede cambiar sin tocar la selección — si muere, por ejemplo —,
	# así que el aviso se engancha a la unidad en vez de refrescarse a mano.
	unit.attack_target_changed.connect(_on_attack_target_changed)
	unit.ammo_changed.connect(_on_ammo_changed)
	_on_attack_target_changed(unit.attack_target)
	_desel_btn.show()
	_unit_tag.show_for(unit)
	_tactical_map.set_selected_unit(unit)
	# El cuadrito del panel se marca desde aquí y no desde el propio panel: da
	# igual cómo se haya elegido la unidad —clic en el mapa, en el panel, o la
	# tecla— porque todas acaban pasando por esta llamada.
	_deployed_panel.set_selected(unit)


## Del enemigo se ve qué es, no se le cambia el arma. Y con el mapa táctico
## abierto no se ve ninguna: `show_weapons(null)` esconde la barra, así que las
## tres condiciones caben en una llamada.
func _refresh_weapon_bar() -> void:
	var unit: Unit = _current_unit
	if not is_instance_valid(unit) or not unit.is_player_controlled() or _tactical_map.visible:
		unit = null
	_weapon_bar.show_weapons(unit)
	# Va con las armas y no aparte: las dos cuentan lo que lleva encima y las dos
	# sobran cuando no hay una unidad propia seleccionada.
	_countermeasure_bar.show_for(unit)


## El menú se coloca solo junto a la unidad: convierte su posición del mundo a
## coordenadas de pantalla a través del canvas, que es lo que ve el HUD.
##
## Con el mapa táctico abierto se pone sobre el punto de la unidad en el mapa.
## Es la misma unidad, pero mirándola desde otro sitio: la de verdad puede estar
## a media misión de la cámara y el menú saldría pegado a un borde.
func open_target_menu(target: Unit, can_attack: bool) -> void:
	if not is_instance_valid(target):
		return
	var where: Vector2 = _tactical_map.marker_position(target) if _tactical_map.visible \
		else target.get_global_transform_with_canvas().origin
	_target_menu.open(target, where, can_attack)


func close_target_menu() -> void:
	_target_menu.close()


func clear_selected_unit() -> void:
	_disconnect_current()
	_current_unit = null
	_selection_panel.clear()
	_actions_panel.clear()
	_weapon_bar.clear()
	_countermeasure_bar.clear()
	_attack_label.hide()
	_impact_timer.hide()
	_desel_btn.hide()
	# La ventana del buque se va con la selección: es el interior de *esa*
	# unidad, así que sin unidad no tiene de quién hablar. Cubre las dos formas
	# de soltarla —la tecla de escape y el botón de cerrar— porque las dos
	# acaban aquí. Animada, al revés que al cambiar de unidad: aquí no hay salto
	# que tape la transición, la vista se queda donde está y sólo se recentra.
	_vessel_window.close()
	_unit_tag.clear()
	_tactical_map.set_selected_unit(null)
	_deployed_panel.set_selected(null)


const _COLUMN_GAP := 6.0


func _push_event_log_above_minimap() -> void:
	_event_log.set_bottom(_minimap.position.y - _COLUMN_GAP)


## Una orden dada, para el registro de eventos. Igual que el marcador: lo cuenta
## quien la da, porque nadie más se entera de que ha habido una.
func report_move_order(unit: Unit, where: Vector2) -> void:
	_event_log.report_move_order(unit, where)


## El destino de la orden en curso, para que se vea en los dos mapas. Se lo dice
## quien da las órdenes: el HUD no conoce el mundo.
func show_order_marker(world_position: Vector2) -> void:
	_minimap.set_order_marker(world_position)
	_tactical_map.set_order_marker(world_position)


func clear_order_marker() -> void:
	_minimap.clear_order_marker()
	_tactical_map.clear_order_marker()


func _on_attack_target_changed(target: Unit) -> void:
	if is_instance_valid(target):
		_attack_label.text = "Atacando: %s" % target.get_display_name()
		_attack_label.show()
	else:
		_attack_label.hide()


func _on_ammo_changed(_weapon: WeaponType, _remaining: int) -> void:
	_weapon_bar.refresh_ammo()


func _disconnect_current() -> void:
	if not is_instance_valid(_current_unit):
		return
	if _current_unit.attack_target_changed.is_connected(_on_attack_target_changed):
		_current_unit.attack_target_changed.disconnect(_on_attack_target_changed)
	if _current_unit.ammo_changed.is_connected(_on_ammo_changed):
		_current_unit.ammo_changed.disconnect(_on_ammo_changed)


func _on_action_pressed(action_name: String) -> void:
	match action_name.to_lower():
		"hangar":
			_hangar_window.open(_current_unit)


func _on_weapon_selected(weapon: WeaponType) -> void:
	if _current_unit == null:
		return
	# El jugador acaba de elegir a mano: el que la cambiaba sola se aparta hasta
	# que esa arma se acabe o se cambie de blanco. Si no, el automático le
	# pisaría la elección al primer repaso y la barra sería decorativa.
	for child in _current_unit.get_children():
		var selector := child as WeaponSelector
		if selector != null:
			selector.take_manual_control()
	_current_unit.set_active_weapon(weapon)
	_weapon_bar.set_active(weapon)
## Poner o quitar la mira. Quien decide es `SelectionManager` —es el único que
## sabe qué hay seleccionado y qué hay debajo del ratón—; el HUD sólo le pasa el
## recado al cursor, que ni conoce las unidades ni tiene por qué.
func aim_cursor(aiming: bool) -> void:
	_cursor.set_shape(MouseCursor.Shape.AIM if aiming else MouseCursor.Shape.POINTER)
