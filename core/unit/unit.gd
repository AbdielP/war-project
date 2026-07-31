extends Area2D
class_name Unit

@export var unit_type: UnitType
@export var unit_name: String = ""

@onready var _selection_indicator: Node2D = $SelectionIndicator


func _ready() -> void:
	_selection_indicator.visible = false


func set_selected(value: bool) -> void:
	_selection_indicator.visible = value


func get_display_name() -> String:
	if unit_name != "":
		return unit_name
	return tr(unit_type.display_name) if unit_type else ""


func get_actions() -> PackedStringArray:
	return unit_type.actions if unit_type else []


func receive_move_order(_target: Vector2) -> void:
	pass
