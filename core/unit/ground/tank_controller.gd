extends Node
class_name TankController

## Conductor de un vehículo de cadenas. Decide CÓMO se mueve; a dónde va lo dice
## quien llame a [method set_route]. Mueve al nodo padre.
##
## **No reusa a [BoatController] aunque los dos vayan por un plano**, por lo
## mismo que ninguno de los pilotos del proyecto reusa a otro: cada uno está
## construido sobre lo que su vehículo *no* puede hacer. La lancha no vira sin
## arrancada, y de ese suelo sale su curva de salida. Las cadenas son justo lo
## contrario: giran a velocidad cero, así que pueden ponerse de cara antes de
## salir. Copiar el modelo de la lancha con otros números daría un carro que
## traza curvas como un coche, que es exactamente lo que no es.
##
## De ahí sale su gesto, y tampoco está programado: **encara y luego avanza**. Un
## carro no llega de lado a ningún sitio, y ponerse de frente antes de moverse es
## lo que hace de verdad — el blindaje bueno está delante y nadie avanza dando el
## costado.

## Recorrió la lista entera. Lo escucha la unidad para dar la orden por cumplida.
signal target_reached
## No puede seguir: el paso siguiente cae en terreno que no pisa. Es un final de
## orden como el otro y no un error — el HUD tiene que dejar de decir que va a
## algún sitio.
signal blocked

@export_group("Marcha")
## Lo que corre de frente y encarado.
@export var forward_speed: float = 34.0
## Y marcha atrás. Menos, como en cualquier vehículo: ciar es para salir de un
## sitio, no para viajar.
@export var reverse_speed: float = 18.0
## Lo que gana por segundo. Baja = arrancada pesada, que es lo que pesa un carro.
@export var acceleration: float = 26.0
## Lo que suelta por segundo. **También decide cuándo empieza a frenar**: la
## distancia de parada sale de aquí (`v²/2a`), así no hay dos números que se
## despeguen en cuanto se toque uno.
@export var deceleration: float = 45.0

@export_group("Gobierno")
## Lo que gira por segundo, en grados. **A cualquier velocidad, incluida cero.**
@export var turn_speed_deg: float = 55.0
## Desvío por debajo del cual se deja de corregir, para no pelearse con el último
## grado.
@export var turn_deadzone_deg: float = 2.0
## Desvío a partir del cual se para a girar en vez de corregir rodando.
##
## **El umbral es lo que hace que esto se vea bien, y no es un adorno.** Girando
## siempre antes de avanzar, el carro se clava en seco cada vez que el rumbo se
## desvía un grado y el avance sale a tirones. Sin umbral ninguno, describe
## curvas y deja de leerse como un carro. Grande gira sobre el sitio, pequeño se
## corrige de camino.
@export var pivot_threshold_deg: float = 30.0
## Desvío a partir del cual se plantea ir marcha atrás en vez de darse la vuelta.
@export var reverse_angle_deg: float = 120.0
## Y hasta qué distancia. Más allá compensa girarse: la marcha atrás es lenta.
@export var reverse_distance: float = 90.0

@export_group("Navegación")
## Distancia a la que se da por llegado a un punto de la lista.
@export var arrive_radius: float = 5.0
## Y a qué velocidad como mucho. Las dos condiciones y no una: pasar por encima
## del punto lanzado no es llegar.
@export var settle_speed: float = 8.0
## Grados a sumar al rumbo para orientar el sprite. El arte del proyecto apunta
## hacia abajo (+Y local), por eso −90.
@export var sprite_offset_deg: float = -90.0

## El rumbo de verdad, no la rotación del nodo. Ver [member sprite_offset_deg].
var heading: float = 0.0
var velocity: Vector2 = Vector2.ZERO
## Los puntos que le quedan por recorrer, en orden.
##
## **Es una lista aunque hoy siempre traiga uno.** Con dos islas y nada que
## rodear, la línea recta sobra; el día que haya que esquivar algo, quien dé la
## orden rellena la lista y aquí no se toca nada. Guardando un punto suelto, ese
## día habría que abrir el conductor entero — y lo que cambia no es cómo se
## conduce, es quién decide por dónde.
var route: PackedVector2Array = PackedVector2Array()

## Si puede pisar un punto del mundo. Se la pone quien sepa mirar el terreno.
##
## **El conductor no sabe de tiles**, igual que el de la lancha no sabe si está
## varada: se lo dicen. Así esto sigue valiendo el día que lo que frene al carro
## no sea el agua sino un muro, un campo de minas o un puente cortado.
var can_drive: Callable = Callable()

var _body: Node2D
var _speed: float = 0.0
## Yendo marcha atrás. Es un pestillo y no una comparación por fotograma: la
## condición que lo enciende —el destino queda detrás— deja de cumplirse en
## cuanto empieza a retroceder, y sin pestillo el carro alternaría entre darse la
## vuelta y ciar en cada fotograma.
var _backwards: bool = false


func _ready() -> void:
	_body = get_parent() as Node2D
	set_physics_process(false)


## Recoge el mando del vehículo tal como esté colocado.
##
## Se llama cuando ya está puesto en su sitio, no al instanciarlo: el rumbo se
## lee del cuerpo, y leerlo antes de que quien lo saca lo haya orientado deja al
## carro creyendo que mira al este.
func enable() -> void:
	if _body == null:
		return
	heading = wrapf(_body.global_rotation - deg_to_rad(sprite_offset_deg), -PI, PI)
	velocity = Vector2.ZERO
	_speed = 0.0
	set_physics_process(true)


func disable() -> void:
	route.clear()
	velocity = Vector2.ZERO
	_speed = 0.0
	set_physics_process(false)


## Si tiene el mando. Mientras no lo tenga, lo mueve otro: va embarcado.
func under_way() -> bool:
	return is_physics_processing()


func has_target() -> bool:
	return not route.is_empty()


## El final del camino, que es lo que el jugador pidió.
func destination() -> Vector2:
	return route[route.size() - 1] if not route.is_empty() else Vector2.ZERO


func set_route(points: PackedVector2Array) -> void:
	route = points.duplicate()
	_backwards = false


func set_target(where: Vector2) -> void:
	set_route(PackedVector2Array([where]))


## Deja de ir a ningún sitio, **frenando**. No se le clava la velocidad a cero:
## sesenta toneladas parándose en un fotograma se leen como un fallo de dibujo.
func stop() -> void:
	route.clear()
	_backwards = false


func _physics_process(delta: float) -> void:
	if _body == null:
		return
	if route.is_empty():
		_speed = maxf(_speed - deceleration * delta, 0.0)
	else:
		_drive(delta)
	_body.rotation = heading + deg_to_rad(sprite_offset_deg)
	var forward := Vector2.from_angle(heading)
	velocity = forward * (-_speed if _backwards else _speed)
	if velocity == Vector2.ZERO:
		return
	var step: Vector2 = velocity * delta
	# Se pregunta por el sitio al que se va a pisar, no por el que se pisa: un
	# carro que comprueba dónde está ya se ha metido en el agua cuando contesta.
	if can_drive.is_valid() and not can_drive.call(_body.global_position + step):
		var iba: bool = not route.is_empty()
		_speed = 0.0
		velocity = Vector2.ZERO
		route.clear()
		_backwards = false
		if iba:
			blocked.emit()
		return
	_body.global_position += step


func _drive(delta: float) -> void:
	var to_target: Vector2 = route[0] - _body.global_position
	var distance := to_target.length()
	if distance <= arrive_radius and _speed <= settle_speed:
		route.remove_at(0)
		if route.is_empty():
			_speed = 0.0
			velocity = Vector2.ZERO
			_backwards = false
			target_reached.emit()
		return

	# Marcha atrás sólo para lo de aquí al lado y a la espalda. Girarse entero
	# para recorrer medio casco es lo que hace que un carro parezca un coche de
	# juguete; ciar es lo que hace de verdad, y sale gratis porque el rumbo al
	# que hay que apuntar es sencillamente el contrario.
	var directo := angle_difference(heading, to_target.angle())
	if not _backwards:
		_backwards = absf(directo) > deg_to_rad(reverse_angle_deg) \
				and distance <= reverse_distance
	var aim: float = to_target.angle() + (PI if _backwards else 0.0)
	var error := angle_difference(heading, aim)

	if absf(error) > deg_to_rad(turn_deadzone_deg):
		var giro := deg_to_rad(turn_speed_deg) * delta
		heading = wrapf(heading + clampf(error, -giro, giro), -PI, PI)
		error = angle_difference(heading, aim)

	# `v²/2a` es lo que cuesta parar desde una velocidad; al revés, es la
	# velocidad máxima desde la que todavía se puede parar en lo que queda.
	var frenada := sqrt(maxf(2.0 * deceleration * distance, 0.0))
	var tope: float = reverse_speed if _backwards else forward_speed
	var quiere: float = 0.0 if absf(error) > deg_to_rad(pivot_threshold_deg) \
			else minf(tope, frenada)

	if _speed < quiere:
		_speed = minf(_speed + acceleration * delta, quiere)
	else:
		_speed = maxf(_speed - deceleration * delta, quiere)
