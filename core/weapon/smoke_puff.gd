extends AnimatedSprite2D
class_name SmokePuff

## Una bocanada de humo suelta. No sabe nada del misil que la escupió: nace en
## un sitio del mundo con un rumbo congelado, se deshace y se borra.
##
## Vive fuera del misil a propósito. Colgada de él, la estela viajaría con el
## misil en vez de quedarse atrás, que es justo lo contrario de una estela.

## Cuánto vive la bocanada decide cuánto mide la cola: a 300 px/s de crucero,
## 1,46 s de vida son ~440 px de estela.
##
## No todos los frames duran lo mismo, y no es un capricho. Los 9 primeros —la
## bocanada formándose— van a 24 fps limpios, porque ahí el dibujo cambia mucho
## de un frame al otro y a menos velocidad se vería a saltos. Los 14 de la
## disipación se alargan poco a poco hasta 2,6 veces, que es como se llega a los
## 440 px sin bajar los fps. La rampa va al final a posta: cada unidad de
## duración son 12,5 px de estela enseñando el mismo dibujo, así que estirar sale
## caro en bandas repetidas y solo es barato donde el alfa ya está por el 11 %.
## Está todo en `missile_smoke_frames.tres`, por frame.
@export var puff_anim: StringName = &"puff"

## Cuántos frames puede saltarse al nacer, como mucho. Es lo que evita que la
## estela se lea como un sello repetido: sin esto, las bocanadas salen a
## intervalos exactos y las que están cerca enseñan el mismo dibujo a la vez —
## a velocidad de crucero cada frame dura tres bocanadas, así que se ven bandas
## de tres iguales avanzando en bloque.
##
## Aparte del frame entero, siempre se le mete un desfase de menos de un frame.
## Eso solo no cambia el dibujo, pero descoloca el momento en que cada una pasa
## al siguiente: dejan de escalonar a la vez, que es lo que se notaba.
@export var start_jitter_frames: int = 1


func _ready() -> void:
	animation_finished.connect(queue_free)
	# El humo no tiene derecha ni izquierda: espejarlo sale gratis y duplica los
	# dibujos que ve el jugador. De paso mueve el píxel de nacimiento de la
	# columna 7 a la 8 — las dos son cola del misil, así que sigue pegado.
	flip_h = randi() % 2 == 0
	play(puff_anim)
	set_frame_and_progress(randi() % maxi(1, start_jitter_frames + 1), randf())
