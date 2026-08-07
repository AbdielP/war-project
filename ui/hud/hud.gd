extends CanvasLayer
class_name HUD

signal deselect_requested
signal unit_focus_requested(unit: Unit)
## El jugador eligió "Atacar" en el menú de una unidad ajena.
signal attack_requested(target: Unit)
## Pidió acercar (+1) o alejar (−1). El HUD no conoce la cámara: reenvía y ya.
signal zoom_change_requested(step: int)
## Pulsó un punto del mapa táctico. Mismo trato que el zoom: se reenvía.
signal camera_move_requested(world_position: Vector2)

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
	_minimap.expand_requested.connect(_tactical_map.open)
	_tactical_map.move_requested.connect(
			func(where: Vector2) -> void: camera_move_requested.emit(where))


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
	# Del enemigo se ve qué es, no se le cambia el arma. `show_weapons(null)`
	# esconde la barra, así que no hace falta repetir la condición.
	_weapon_bar.show_weapons(unit if unit.is_player_controlled() else null)
	# El objetivo puede cambiar sin tocar la selección — si muere, por ejemplo —,
	# así que el aviso se engancha a la unidad en vez de refrescarse a mano.
	unit.attack_target_changed.connect(_on_attack_target_changed)
	unit.ammo_changed.connect(_on_ammo_changed)
	_on_attack_target_changed(unit.attack_target)
	_desel_btn.show()


## El menú se coloca solo junto a la unidad: convierte su posición del mundo a
## coordenadas de pantalla a través del canvas, que es lo que ve el HUD.
func open_target_menu(target: Unit, can_attack: bool) -> void:
	if not is_instance_valid(target):
		return
	_target_menu.open(target, target.get_global_transform_with_canvas().origin, can_attack)


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
