extends AnimatedSprite2D
class_name Tracer

## Un trazo de una ráfaga. Nace en la boca del arma con el rumbo que llevaba el
## avión, sale disparado hacia adelante y se borra solo.
##
## No es una bala: **no hace daño y no comprueba nada**. El daño de la ráfaga lo
## reparte el arma, que sabe cuántos proyectiles ha soltado y cuántos entran.
## Esto es lo que se ve, y sólo eso. Un cañón de rotación suelta ~60 balas por
## segundo: dibujar una por bala no se sostiene, así que se dibuja una de cada
## tantas — que es exactamente lo que es una trazadora de verdad.
##
## Vive en el mundo y no colgada del avión, igual que las bocanadas de humo: una
## vez sale por la boca ya no le pertenece, y si el avión se va o muere, lo que
## disparó sigue su camino.

## Píxeles por segundo. Muy por encima de la velocidad del avión, o los trazos
## se quedarían pegados al morro en vez de marcharse.
@export var speed: float = 900.0
## Hasta dónde llega antes de borrarse. Debería quedarse en el alcance del arma:
## un trazo que sigue más allá promete un impacto que no va a pasar.
@export var range_px: float = 360.0
## Grados a sumar al rumbo para orientar el dibujo, igual que en el avión y en
## el misil. El trazo está dibujado apuntando a +Y, de ahí el −90.
@export var sprite_offset_deg: float = -90.0

## El rumbo con el que nació, aparte de la rotación del nodo: el dibujo lleva un
## desfase y si se volase por la rotación, el trazo saldría de lado.
var _heading: float = 0.0
var _travelled: float = 0.0


func _ready() -> void:
	# Puede acabar por lo que ocurra antes: agotar el recorrido o terminar el
	# dibujo. Sin lo segundo, un trazo con animación corta se quedaría congelado
	# en su último frame el resto del viaje.
	animation_finished.connect(queue_free)
	play()


## Le da el rumbo con el que sale. Va aparte de `_ready()` a propósito: el nodo
## se mete en el árbol antes de que se le coloque, así que en `_ready()` todavía
## no sabe hacia dónde mira — leerlo ahí lo mandaba siempre hacia +X y de lado.
##
## Es lo mismo que hace `Projectile.launch()`: nacer y salir disparado son dos
## momentos distintos.
func launch(heading: float) -> void:
	_heading = heading
	rotation = _heading + deg_to_rad(sprite_offset_deg)


func _physics_process(delta: float) -> void:
	var step := speed * delta
	# El rumbo es el del arma al nacer y no se toca: una bala no persigue nada.
	global_position += Vector2.RIGHT.rotated(_heading) * step
	_travelled += step
	if _travelled >= range_px:
		queue_free()
