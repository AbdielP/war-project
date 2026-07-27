extends CanvasLayer
class_name HUD

@onready var _selection_panel: PanelContainer = $SelectionPanel
@onready var _actions_panel: PanelContainer = $ActionsPanel
@onready var _hangar_window: PanelContainer = $HangarWindow

var _current_unit: Unit = null


func _ready() -> void:
	_actions_panel.action_pressed.connect(_on_action_pressed)


func show_selected_unit(unit: Unit) -> void:
	_current_unit = unit
	_selection_panel.show_unit(unit.get_display_name())
	_actions_panel.show_actions(unit.get_actions())


func clear_selected_unit() -> void:
	_current_unit = null
	_selection_panel.clear()
	_actions_panel.clear()


func _on_action_pressed(action_name: String) -> void:
	match action_name.to_lower():
		"hangar":
			_hangar_window.open(_current_unit)
