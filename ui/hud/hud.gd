extends CanvasLayer
class_name HUD

signal deselect_requested

@onready var _selection_panel: PanelContainer = $SelectionPanel
@onready var _actions_panel: PanelContainer = $ActionsPanel
@onready var _hangar_window: PanelContainer = $HangarWindow
@onready var _desel_btn: Button = $DeselButton

var _current_unit: Unit = null


func _ready() -> void:
	_actions_panel.action_pressed.connect(_on_action_pressed)
	_desel_btn.add_theme_color_override("font_color", Color(0.6705882, 0.5803922, 0.4784314))
	_desel_btn.add_theme_color_override("font_hover_color", Color(0.56078434, 0.827451, 1.0))
	_desel_btn.add_theme_color_override("font_pressed_color", Color(0.56078434, 0.827451, 1.0))
	_desel_btn.pressed.connect(func() -> void: deselect_requested.emit())


func show_selected_unit(unit: Unit) -> void:
	_current_unit = unit
	_selection_panel.show_unit(unit.get_display_name())
	_actions_panel.show_actions(unit.get_actions())
	_desel_btn.show()


func clear_selected_unit() -> void:
	_current_unit = null
	_selection_panel.clear()
	_actions_panel.clear()
	_desel_btn.hide()


func _on_action_pressed(action_name: String) -> void:
	match action_name.to_lower():
		"hangar":
			_hangar_window.open(_current_unit)
