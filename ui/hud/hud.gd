extends CanvasLayer
class_name HUD

@onready var _selection_panel: PanelContainer = $SelectionPanel


func show_selected_unit(unit_name: String) -> void:
	_selection_panel.show_unit(unit_name)


func clear_selected_unit() -> void:
	_selection_panel.clear()
