extends Node
class_name BoatController

## Patrón de una embarcación. Decide CÓMO se mueve; a dónde va lo decide quien
## llame a [method set_target]. Mueve al nodo padre.
##
## **No reusa ninguno de los dos pilotos que ya hay**, y la razón es la misma que
## los separa a ellos dos entre sí: cada uno está construido sobre lo que su
## aparato *no* puede hacer. El avión no puede parar, y de ahí sale todo su radio
## de giro; el helicóptero no tiene radio de giro, y de ahí salen sus tres ejes y
## su pedal aparte. Una lancha ni pivota parada ni deja de poder frenar: va de
## proa, gira mientras avanza y se detiene donde le digan.
##
## Es el más simple de los tres y por eso cabe en un archivo corto. **Un solo eje
## de marcha**, a propósito: una lancha no navega de costado, y darle un eje que
## no usa sería copiar al helicóptero por tenerlo escrito.
##
## De aquí sale el gesto que la distingue: como sólo empuja hacia donde mira y
## tarda en girar, sale del barco describiendo una curva en vez de partir en
## línea recta hacia la playa. Eso no está programado — es lo que queda cuando el
## único eje es la proa.

## Llegó a donde se le mandó. Lo escucha la unidad para decidir qué hacer allí.
signal target_reached

@export_group("Marcha")
## Lo que corre a rumbo hecho.
@export var cruise_speed: float = 60.0
## Lo que gana por segundo. Baja = arrancada pesada, que es lo que se espera de
## algo que va cargado.
@export var acceleration: float = 30.0
## Lo que suelta por segundo. **También decide cuándo empieza a frenar**, porque
## la distancia de parada sale de aquí: sin esto habría que elegir un número de
## frenada aparte y las dos cuentas se irían despegando en cuanto se tocara una.
@export var deceleration: float = 40.0

@export_group("Gobierno")
## Lo que gira por segundo, en grados. Es un radio de giro disfrazado: como sólo
## empuja hacia donde mira, girar despacio a velocidad de crucero **es** virar
## ancho, sin tener que calcular ningún radio.
@export var turn_speed_deg: float = 45.0
## Desvío de rumbo por debajo del cual se deja de corregir. Está para no
## pelearse con el último grado.
@export var turn_deadzone_deg: float = 1.0
## Qué fracción de la velocidad de crucero conserva con el rumbo del revés.
##
## **No puede ser cero.** Una embarcación no vira parada: sin arrancada el timón
## no muerde, y con el empuje atado al coseno del desvío la lancha se quedaba
## clavada tres segundos girando sobre sí misma al salir del buque. Con este
## suelo sigue haciendo camino mientras cae a rumbo, y de ahí sale la curva de
## salida en vez de un pivote.
@export_range(0.0, 1.0, 0.05) var steerage_fraction: float = 0.35

@export_group("Navegación")
## Distancia a la que se da por llegada.
@export var arrive_radius: float = 6.0
## Y a qué velocidad como mucho. Las dos condiciones y no una: cruzar el punto a
## toda máquina no es llegar.
@export var settle_speed: float = 10.0
## Grados a sumar al rumbo para orientar el sprite. El arte del proyecto apunta
## hacia abajo (+Y local), por eso −90.
@export var sprite_offset_deg: float = -90.0

## El rumbo de verdad, no la rotación del nodo. Ver [member sprite_offset_deg].
var heading: float = 0.0
var velocity: Vector2 = Vector2.ZERO
var target: Vector2 = Vector2.ZERO
var has_target: bool = false

## Está varada. Se lo dice quien sepa mirar el terreno; el piloto no lo sabe.
##
## Cambia una sola cosa: **en seco no hace falta arrancada para virar**. El suelo
## de [member steerage_fraction] existe porque en el agua el timón no muerde sin
## marcha, y aplicándolo también encallada la lancha salía de la playa trepando
## tierra adentro mientras caía a rumbo — 29 px medidos. Encima de la arena
## pivota, que es lo que hace un aerodeslizador de verdad.
var aground := false
## Tope de velocidad puntual, o 0 para ir a lo que dé el crucero.
##
## **El radio de giro sale de aquí**, porque este piloto sólo empuja hacia donde
## mira: girando a [member turn_speed_deg] y corriendo a `cruise_speed`, la curva
## mide `v / ω`. A 60 px/s y 45°/s son 76 px de radio, y con eso una lancha que
## tiene que dar media vuelta para encarar el dique se abre más de medio buque y
## entra de través. Reduciendo la marcha la curva se cierra sola: no hay que
## tocar el gobierno, hay que llegar despacio.
var speed_limit: float = 0.0

var _body: Node2D
var _speed: float = 0.0


func _ready() -> void:
	_body = get_parent() as Node2D
	set_physics_process(false)


## Recoge el gobierno de la lancha tal como esté colocada.
##
## Se llama **al soltarla al mundo y no antes**: mientras está en el dique es
## carga del buque, viaja en coordenadas de éste, y un piloto empujando contra
## ese recorrido pelearía con él. Es la misma regla que la cubierta de vuelo.
func enable() -> void:
	if _body == null:
		return
	heading = wrapf(_body.global_rotation - deg_to_rad(sprite_offset_deg), -PI, PI)
	velocity = Vector2.ZERO
	_speed = 0.0
	set_physics_process(true)


## Si tiene el gobierno. Mientras no lo tenga, la lancha es carga de otro y no
## se pilota — la mueve el buque.
func under_way() -> bool:
	return is_physics_processing()


func disable() -> void:
	has_target = false
	velocity = Vector2.ZERO
	_speed = 0.0
	set_physics_process(false)


func set_target(where: Vector2) -> void:
	target = where
	has_target = true


## Deja de ir a ningún sitio, **frenando**. No se le clava la velocidad a cero:
## una lancha de 100 toneladas parándose en un fotograma se lee como un fallo de
## dibujo, no como una orden cumplida.
func stop() -> void:
	has_target = false


func _physics_process(delta: float) -> void:
	if _body == null:
		return
	if has_target:
		_steer(delta)
	else:
		_speed = maxf(_speed - deceleration * delta, 0.0)
	_body.rotation = heading + deg_to_rad(sprite_offset_deg)
	velocity = Vector2.from_angle(heading) * _speed
	_body.global_position += velocity * delta


func _steer(delta: float) -> void:
	var to_target: Vector2 = target - _body.global_position
	var distance := to_target.length()
	if distance <= arrive_radius and _speed <= settle_speed:
		has_target = false
		_speed = 0.0
		velocity = Vector2.ZERO
		target_reached.emit()
		return

	# Rumbo primero: cuánto se puede empujar depende de cuánto se está desviado.
	var error := angle_difference(heading, to_target.angle())
	if absf(error) > deg_to_rad(turn_deadzone_deg):
		var giro := deg_to_rad(turn_speed_deg) * delta
		heading = wrapf(heading + clampf(error, -giro, giro), -PI, PI)
		error = angle_difference(heading, to_target.angle())

	# Lo que se puede llevar sin pasarse del punto. `v² / 2a` es la distancia que
	# cuesta parar desde una velocidad: al revés, es la velocidad máxima desde la
	# que todavía se puede parar en lo que queda.
	var frenada := sqrt(maxf(2.0 * deceleration * distance, 0.0))
	# Y con el rumbo torcido no se empuja a fondo: el coseno del desvío es la
	# fracción del empuje que va de verdad hacia el punto. Pero nunca hasta
	# pararse — ver [member steerage_fraction].
	var encarado := maxf(cos(error), 0.0)
	var suelo: float = 0.0 if aground else steerage_fraction
	var tope: float = cruise_speed if speed_limit <= 0.0 \
			else minf(cruise_speed, speed_limit)
	var quiere: float = minf(tope * lerpf(suelo, 1.0, encarado), frenada)

	if _speed < quiere:
		_speed = minf(_speed + acceleration * delta, quiere)
	else:
		_speed = maxf(_speed - deceleration * delta, quiere)
