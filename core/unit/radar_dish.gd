extends Node2D
class_name RadarDish

## La antena de vigilancia: da vueltas y no para nunca.
##
## No busca a nadie ni sigue a nadie, y es a propósito. Un radar de vigilancia
## **barre todo el cielo continuamente** — si se parase a mirar a un avión
## dejaría de vigilar el resto, que es justo lo contrario de para lo que está.
## Quien engancha y no suelta es la puntería de la torreta, y eso vive allí.
##
## Así que esto es decoración honesta: gira porque el trasto de verdad gira.

## Grados por segundo. Una vuelta entera cada 360/este número de segundos.
@export var scan_speed_deg: float = 120.0


func _physics_process(delta: float) -> void:
	rotation += deg_to_rad(scan_speed_deg) * delta
