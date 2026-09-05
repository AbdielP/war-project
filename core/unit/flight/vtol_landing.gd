extends Node
class_name VtolLanding

## El tramo final de un V/STOL: **bajar de vuelo sustentado por el ala a vuelo
## sustentado por el motor**, y desde ahí colocarse y posarse.
##
## [b]Existe porque un avión no puede pararse.[/b] Ese es el cimiento de
## [PlaneController] —de él salen el radio de giro, el circuito de espera y la
## pasada de ataque— y no se toca: un Harrier que pudiera quedarse quieto
## volando dejaría de comportarse como un avión en todo lo demás. Lo que hace un
## Harrier de verdad es dejar de ser un avión durante los últimos metros, y eso
## es exactamente lo que hay aquí.
##
## [b]Tampoco es el piloto del helicóptero.[/b] Se parece —los dos se quedan
## quietos en el aire— y por eso tienta reusarlo, pero un Harrier en sustentación
## no es un Cobra: no pivota, no viaja de costado y aguanta ahí segundos, no
## minutos. Reusando aquel piloto saldría un vehículo que se mueve como el que no
## es, que es la razón de que en este proyecto los pilotos no se compartan.
##
## [b]Lo único que sabe hacer es llegar a un punto y pararse en él.[/b] La
## diferencia entre las dos entradas del Harrier no está aquí dentro: son los
## mismos dos ajustes y otra lista de puntos. Entrando por el eje de la cubierta
## frena a lo largo de ella y toca rodando; entrando por el costado se planta al
## través y cruza de lado. Ver `av8b_harrier.gd`.
##
## No decide nada: a dónde ir y cuándo posarse se lo dice quien lleva la
## maniobra, que es el único que sabe si hay cubierta debajo.

## Se posó del todo y paró. Espejo de `HelicopterController.landed`.
signal landed

## En qué anda. Es lo que mira la animación para saber qué dibujar: la de aire
## caliente y polvo contra la cubierta va colgada de aquí, y **no del aterrizaje
## entero**, porque las dos entradas no se ven igual.
enum State {
	OFF,       ## Sin control. El avión lo lleva su piloto.
	SLOWING,   ## Ya no vuela por el ala: soltando velocidad hacia el punto.
	SETTLING,  ## Quieto sobre el sitio, bajando.
	DOWN,      ## Posado.
}

signal state_changed(state: State)

@export_group("Sustentación")
## Lo que suelta por segundo al frenar, en px/s².
##
## **Es lo que decide cuánta cubierta gasta la entrada rodada**, y por eso es el
## número que se toca para ajustarla: la distancia de frenada es `v²/2a`, así que
## a 70 px/s de aproximación y con 18 aquí salen los 136 px que hay del punto de
## entrada a la plaza de popa. Subirlo la acorta.
@export var deceleration: float = 18.0
## Lo que gana por segundo. Bajo a propósito: en sustentación el empuje va a
## sostener el avión, no a moverlo.
@export var acceleration: float = 20.0
## A lo que se coloca una vez frenado. No es la velocidad de vuelo: es la de
## alguien buscando su sitio con el aparato colgado del motor.
@export var creep_speed: float = 22.0
## Lo que gira sobre sí mismo, en grados por segundo. Muy por debajo de un
## helicóptero: un Harrier en sustentación se orienta con los toberines y va
## sobrado de todo menos de tiempo.
@export var yaw_speed_deg: float = 45.0

@export_group("Llegada")
## Distancia a la que se da por colocado.
@export var arrive_radius: float = 3.0
## Y a qué velocidad como mucho. Las dos condiciones, igual que en los demás
## pilotos: cruzar el sitio a toda velocidad no es haber llegado.
@export var settle_speed: float = 5.0
## Lo que tarda en posarse una vez quieto. Hoy es sólo una espera, igual que
## `lift_time` en el helicóptero: es el hueco donde entran la animación de
## posada y los efectos de tobera.
@export var land_time: float = 1.4
## Grados a sumar al rumbo para orientar el sprite. El arte apunta a +Y.
@export var sprite_offset_deg: float = -90.0

var heading: float = 0.0
var velocity: Vector2 = Vector2.ZERO
var target: Vector2 = Vector2.ZERO
## Rumbo impuesto, o `NAN` si el morro sigue a la marcha. Entrando a un barco
## siempre está puesto: se entra **paralelo al buque**, no mirando a donde se va.
var locked_heading: float = NAN

var _body: Node2D
var _state: State = State.OFF
## El techo de velocidad, que decae hasta `creep_speed`. Arranca en la que traía
## el avión: **recogerlo a otra sería un tirón justo en el relevo**, que es lo
## mismo que ya pasaba al soltarlo en el despegue.
var _cap: float = 0.0
var _landing_for: float = 0.0


func _ready() -> void:
	_body = get_parent() as Node2D
	set_physics_process(false)


## Recoge el avión tal como viene volando. El rumbo y la velocidad se heredan;
## de aquí en adelante ya no es un avión.
func take_over(from_heading: float, from_velocity: Vector2) -> void:
	if _body == null:
		return
	heading = from_heading
	velocity = from_velocity
	_cap = maxf(from_velocity.length(), creep_speed)
	locked_heading = NAN
	target = _body.global_position
	_set_state(State.SLOWING)
	set_physics_process(true)


func release() -> void:
	set_physics_process(false)
	locked_heading = NAN
	_set_state(State.OFF)


func get_state() -> State:
	return _state


func is_active() -> bool:
	return _state != State.OFF


## A dónde colocarse ahora. Se llama cada fotograma contra un punto vivo: el
## barco se mueve, y un punto capturado al empezar deja de ser su sitio.
func steer_to(world_pos: Vector2) -> void:
	target = world_pos


## Si ya está sobre el sitio y quieto.
func is_settled() -> bool:
	return _body != null \
			and _body.global_position.distance_to(target) <= arrive_radius \
			and velocity.length() <= settle_speed


## Se posa. Cuándo se puede lo decide quien lleva la maniobra.
func land() -> void:
	velocity = Vector2.ZERO
	_landing_for = 0.0
	_set_state(State.SETTLING)


func _physics_process(delta: float) -> void:
	match _state:
		State.SETTLING:
			# Nada de mover aquí: bajando ya está colgado del barco, y escribirle
			# la posición pelearía con la cubierta, que lo lleva colocado.
			_landing_for += delta
			if _landing_for >= land_time:
				_set_state(State.DOWN)
				set_physics_process(false)
				landed.emit()
			return
		State.SLOWING:
			_glide(delta)
		_:
			return


func _glide(delta: float) -> void:
	# El techo baja al ritmo del frenado hasta quedarse en la velocidad de
	# colocación. Esto es lo que se **ve**: el avión llega volando y va soltando.
	_cap = move_toward(_cap, creep_speed, deceleration * delta)

	var to_target := target - _body.global_position
	var dist := to_target.length()
	var wanted := Vector2.ZERO
	if dist > 0.01:
		# Lo que permite pararse en lo que falta, `v² = 2·a·d`. Es la misma
		# cuenta que usa el helicóptero por eje, y es lo que hace que se plante
		# en el punto en vez de pasarse y volver.
		var allowed := sqrt(2.0 * deceleration * dist)
		wanted = to_target / dist * minf(allowed, _cap)

	var rate := acceleration if wanted.length() > velocity.length() else deceleration
	velocity = velocity.move_toward(wanted, rate * delta)

	# El morro va por su lado. Sin rumbo impuesto sigue a la marcha, pero
	# entrando a un barco siempre lo hay.
	var want_heading := heading
	if not is_nan(locked_heading):
		want_heading = locked_heading
	elif velocity.length() > 1.0:
		want_heading = velocity.angle()
	var step := deg_to_rad(yaw_speed_deg) * delta
	heading = wrapf(heading + clampf(angle_difference(heading, want_heading), -step, step),
			-PI, PI)

	_body.global_position += velocity * delta
	_body.global_rotation = heading + deg_to_rad(sprite_offset_deg)


func _set_state(value: State) -> void:
	if _state == value:
		return
	_state = value
	state_changed.emit(value)
