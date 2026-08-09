extends AnimatedSprite2D
class_name Tracer

## Un trazo de una ráfaga. Nace en la boca del arma con el rumbo que llevaba el
## avión, sale disparado hacia adelante y se apaga solo.
##
## No es una bala: **no hace daño y no comprueba nada**. El daño de la ráfaga lo
## reparte el arma, que sabe cuántos proyectiles ha soltado y cuántos entran.
## Esto es lo que se ve, y sólo eso. Un cañón de rotación suelta ~60 balas por
## segundo: dibujar una por bala no se sostiene, así que se dibuja una de cada
## tantas — que es exactamente lo que es una trazadora de verdad.
##
## Vive tres tiempos, y los tres salen de la misma tira de dibujos:
##
##   MUZZLE   la bala saliendo del arma, formándose. Frames cortos, y son los
##            primeros palmos del recorrido: no el viaje entero.
##   STREAK   el trazo entero, quieto. Es el grueso del camino.
##   APAGADO  los mismos frames cortos, pero al revés: el trazo se consume hasta
##            desaparecer. Es lo que evita que la trazadora cruce el blanco y
##            siga de largo — se acaba DONDE está el blanco, no donde le tocaba
##            por alcance.
##
## Vive en el mundo y no colgada del avión, igual que las bocanadas de humo: una
## vez sale por la boca ya no le pertenece, y si el avión se va o muere, lo que
## disparó sigue su camino.

## Píxeles por segundo. Muy por encima de la velocidad del avión, o los trazos
## se quedarían pegados al morro en vez de marcharse.
@export var speed: float = 900.0
## Hasta dónde llega si nadie le dice otra cosa. Lo normal es que el arma le pase
## la distancia real al blanco en `launch()`; esto es sólo el respaldo para
## cuando se dispara sin blanco.
@export var range_px: float = 420.0
## Cuánto se alarga o se acorta el recorrido de cada trazo, en tanto por uno. No
## todas las balas de una ráfaga caen en el mismo sitio: **algunas tienen que
## pasarse y otras quedarse cortas**, o la ráfaga entera parece una regla.
@export_range(0.0, 0.5, 0.01) var reach_spread: float = 0.12
## En cuántos píxeles se consume el trazo al final. Es el tramo en el que se van
## poniendo los frames cortos, al revés, hasta que no queda nada.
@export var burn_out_px: float = 90.0
## Grados a sumar al rumbo para orientar el dibujo, igual que en el avión y en
## el misil. El trazo está dibujado apuntando a +Y, de ahí el −90.
@export var sprite_offset_deg: float = -90.0

## Cómo sale del arma. También son los frames que se usan al apagarse, porque son
## los mismos trazos cortos: al derecho la bala se forma, al revés se consume.
const MUZZLE := &"muzzle"
## El trazo entero.
const STREAK := &"streak"

## El rumbo con el que nació, aparte de la rotación del nodo: el dibujo lleva un
## desfase y si se volase por la rotación, el trazo saldría de lado.
var _heading: float = 0.0
var _travelled: float = 0.0
## Hasta dónde llega este trazo en concreto. Se fija al nacer.
var _reach: float = 0.0
var _burning_out := false


func _ready() -> void:
	# Encadenadas y no sueltas: la tira no es un ciclo, es una bala saliendo y
	# luego la trazadora ya formada. Ninguno de los dos vale sin el otro.
	animation_finished.connect(_settle)
	play(MUZZLE)


## Terminó de salir: a partir de aquí es un trazo y ya no cambia hasta que se
## consuma. **No se borra al acabar el dibujo** — quien decide cuándo termina es
## la distancia, que es lo que de verdad limita hasta dónde llega una bala.
func _settle() -> void:
	if not _burning_out:
		play(STREAK)


## Le da el rumbo con el que sale y hasta dónde tiene que llegar. Va aparte de
## `_ready()` a propósito: el nodo se mete en el árbol antes de que se le
## coloque, así que en `_ready()` todavía no sabe hacia dónde mira — leerlo ahí
## lo mandaba siempre hacia +X y de lado.
##
## `reach` es la distancia al blanco en el momento del disparo. Con eso el trazo
## se apaga encima de lo que se está ametrallando en vez de seguir hasta agotar
## el alcance del arma, que es lo que hacía que las balas se pasaran de largo.
## A 0 o menos — fuego sin blanco — se queda con su alcance de siempre.
##
## Es lo mismo que hace `Projectile.launch()`: nacer y salir disparado son dos
## momentos distintos.
func launch(heading: float, reach: float = 0.0) -> void:
	_heading = heading
	rotation = _heading + deg_to_rad(sprite_offset_deg)
	var wanted := reach if reach > 0.0 else range_px
	_reach = maxf(wanted * (1.0 + randf_range(-reach_spread, reach_spread)), 1.0)


func _physics_process(delta: float) -> void:
	var step := speed * delta
	# El rumbo es el del arma al nacer y no se toca: una bala no persigue nada.
	global_position += Vector2.RIGHT.rotated(_heading) * step
	_travelled += step

	var left := _reach - _travelled
	if left <= 0.0:
		queue_free()
		return
	if left <= burn_out_px:
		_burn_out(left)


## Va poniendo trazos cada vez más cortos según se acaba el recorrido. Se maneja
## el frame a mano en vez de reproducir la animación al revés porque lo que manda
## aquí es la distancia que queda, no un reloj: así el trazo se consume al ritmo
## al que llega, aunque vaya más rápido o más lento.
func _burn_out(left: float) -> void:
	if not _burning_out:
		_burning_out = true
		stop()
		animation = MUZZLE
	var last := sprite_frames.get_frame_count(MUZZLE) - 1
	frame = clampi(int(left / burn_out_px * (last + 1)), 0, last)
