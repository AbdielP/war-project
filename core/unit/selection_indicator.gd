extends Node2D

@export var size: Vector2 = Vector2(32, 32)

## Color del contorno. Lo pone `Unit` según su bando; el valor de aquí es sólo
## el que se ve en el editor antes de que la unidad arranque.
@export var color: Color = Color(0.5607843, 0.827451, 1, 1):
	set(value):
		color = value
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-size / 2.0, size), color, false, 1.0)
