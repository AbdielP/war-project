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

@onready var _event_log: EventLog = $EventLog
@onready var _selection_panel: PanelContainer = $SelectionPanel
@onready var _actions_panel: PanelContainer = $ActionsPanel
@onready var _hangar_window: PanelContainer = $HangarWindow
@onready var _desel_btn: Button = $DeselButton
@onready var _deployed_panel: PanelContainer = $DeployedPanel
@onready var _weapon_bar: HBoxContainer = $WeaponBar
@onready var _target_menu: PanelContainer = $TargetMenu
@onready var _attack_label: Label = $AttackLabel
@onready var _impact_timer: Label = $ImpactTimer
@onready var _zoom_controls: VBoxContainer = $ZoomControls
@onready var _minimap: Minimap = $Minimap
@onready var _tactical_map: TacticalMap = $TacticalMap

## Dónde se pone la cuenta atrás respecto al objetivo, en píxeles de pantalla:
## arriba y un poco a la derecha, para no taparlo ni pisar su recuadro.
const _IMPACT_OFFSET := Vector2(10.0, -14.0)

var _current_unit: Unit = null


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
	# El minimapa se estira a mano y crece hacia arriba, justo hacia donde está
	# el registro. Que se aparte él, que es el que no lo pidió.
	_minimap.resized.connect(_push_event_log_above_minimap)
	_push_event_log_above_minimap()
	_minimap.expand_requested.connect(_tactical_map.open)
	_tactical_map.clicked.connect(
			func(where: Vector2, unit: Unit) -> void: map_clicked.emit(where, unit))
	_tactical_map.context_requested.connect(
			func(where: Vector2, unit: Unit) -> void: map_context_requested.emit(where, unit))
	# La barra de armas es lo único que sobra con el mapa abierto: cae justo
	# encima del terreno y ahí no se dispara nada. El resto del HUD se queda.
	_tactical_map.opened.connect(_refresh_weapon_bar)
	_tactical_map.closed.connect(_refresh_weapon_bar)


## Hasta dónde puede seguir acercándose o alejándose. Se lo dice quien tiene la
## cámara delante — el HUD no la conoce.
func set_zoom_state(level: int, count: int) -> void:
	_zoom_controls.set_state(level, count)


## La cuenta atrás vive con la selección, igual que el recuadro del objetivo:
## es lo que está disparando la unidad que miras, no un adorno del mapa. Si
## deseleccionas, desaparece; al volver a seleccionarla, vuelve.
func _process(_delta: float) -> void:
	var target := _current_unit.attack_target if is_instance_valid(_current_unit) else null
	if not is_instance_valid(target):
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


func show_selected_unit(unit: Unit) -> void:
	_disconnect_current()
	_current_unit = unit
	_selection_panel.show_unit(unit.get_display_name())
	_actions_panel.show_actions(unit.get_actions() if unit.is_player_controlled() else [])
	_refresh_weapon_bar()
	# El objetivo puede cambiar sin tocar la selección — si muere, por ejemplo —,
	# así que el aviso se engancha a la unidad en vez de refrescarse a mano.
	unit.attack_target_changed.connect(_on_attack_target_changed)
	unit.ammo_changed.connect(_on_ammo_changed)
	_on_attack_target_changed(unit.attack_target)
	_desel_btn.show()
	_tactical_map.set_selected_unit(unit)


## Del enemigo se ve qué es, no se le cambia el arma. Y con el mapa táctico
## abierto no se ve ninguna: `show_weapons(null)` esconde la barra, así que las
## tres condiciones caben en una llamada.
func _refresh_weapon_bar() -> void:
	var unit: Unit = _current_unit
	if not is_instance_valid(unit) or not unit.is_player_controlled() or _tactical_map.visible:
		unit = null
	_weapon_bar.show_weapons(unit)


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
	_attack_label.hide()
	_impact_timer.hide()
	_desel_btn.hide()
	_tactical_map.set_selected_unit(null)


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
	_current_unit.set_active_weapon(weapon)
	_weapon_bar.set_active(weapon)
