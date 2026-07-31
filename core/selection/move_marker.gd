extends Node2D

const _COLOR := Color(0.56078434, 0.827451, 1.0, 0.85)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		queue_redraw()


func _draw() -> void:
	draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 24, _COLOR, 1.0)
	draw_line(Vector2(-5, 0), Vector2(5, 0), _COLOR, 1.0)
	draw_line(Vector2(0, -5), Vector2(0, 5), _COLOR, 1.0)
