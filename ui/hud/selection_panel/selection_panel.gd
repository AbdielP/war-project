extends PanelContainer

@onready var _label: Label = $Label


func show_unit(unit_name: String) -> void:
	_label.text = unit_name
	show()


func clear() -> void:
	hide()
