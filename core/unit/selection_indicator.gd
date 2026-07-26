extends Node2D

@export var size: Vector2 = Vector2(32, 32)

const COLOR := Color(0.5607843, 0.827451, 1, 1)


func _draw() -> void:
	draw_rect(Rect2(-size / 2.0, size), COLOR, false, 1.0)
