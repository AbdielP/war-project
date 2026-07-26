extends CanvasLayer
class_name HUD

@onready var _selection_panel: PanelContainer = $SelectionPanel
@onready var _actions_panel: PanelContainer = $ActionsPanel
@onready var _hangar_window: PanelContainer = $HangarWindow


func _ready() -> void:
	_actions_panel.action_pressed.connect(_on_action_pressed)


func show_selected_unit(unit_name: String, actions: PackedStringArray) -> void:
	_selection_panel.show_unit(unit_name)
	_actions_panel.show_actions(actions)


func clear_selected_unit() -> void:
	_selection_panel.clear()
	_actions_panel.clear()


func _on_action_pressed(action_name: String) -> void:
	match action_name.to_lower():
		"hangar":
			_hangar_window.open()
