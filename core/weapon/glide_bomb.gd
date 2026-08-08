extends Projectile
class_name GlideBomb

## Bomba planeadora guiada — la GBU-54 y las que vengan detrás. Se suelta y
## cae. No tiene motor y nunca lo tuvo: no hay nada que encender, ni fuego, ni
## estela de humo. Cae en silencio.
##
## Lo que la convierte en un arma de largo alcance no es empuje, es ALTURA. Se
## suelta alta y lejos, y mientras baja va ganando velocidad y corrigiendo el
## rumbo con las aletas de cola. Por eso el avión no tiene que pasar por encima
## de nada: suelta desde el borde de su alcance y se va.
##
## El vuelo tiene dos partes:
##   1. Suelta — cae del pilón sin control, arrastrada por la inercia del avión.
##   2. Planeo guiado — pica, acelera y corrige hasta tocar suelo.
##
## Y toca suelo de una de dos maneras, que son sus dos únicos finales:
##   - Llegó al blanco. Impacto.
##   - Se le acabó la caída antes de llegar: `fall_time` es su altura, y una
##     bomba no puede quedarse arriba esperando a nada. Cae corta y falla.
##
## Ese segundo final es lo que le da sentido al `max_range` del arma. No es una
## regla ni un muro: es hasta dónde llega picando. Soltarla más lejos no es que
## "no esté permitido" — es que no llega, igual que el misil que se queda sin
## combustible. El fallo sale de la simulación, no de un dado.
##
## A diferencia del misil, guía hasta el final: unas aletas no necesitan
## combustible. Lo que se le acaba es el sitio para maniobrar, no el mando.

@export_group("Suelta")
## Cuánto tarda en estabilizarse tras salir del pilón. Mientras, no guía — por
## eso soltarla demasiado cerca no sirve: no le da tiempo a corregir nada.
@export var separation_time: float = 0.35
## Cuánto frena mientras cae pegada al avión, antes de empezar a picar.
@export var separation_drag: float = 0.9

@export_group("Planeo")
## Velocidad que alcanza picando. Una bomba no empuja: gana velocidad cayendo,
## así que acaba yendo bastante más rápido de lo que salió.
@export var terminal_speed: float = 280.0
## Cuánto gana por segundo mientras pica. Bastante más suave que el arranque de
## un cohete: la bomba tarda un par de segundos en coger su velocidad, no un
## suspiro. Subirlo también alarga el alcance — llega antes a picar de verdad.
@export var dive_acceleration: float = 90.0
## Radio de giro mínimo en px. Muy por encima del de un misil: unas aletas de
## cola corrigen deriva, no hacen virajes. Es lo que obliga a soltarla ya
## encarada en vez de tirarla de cualquier manera y que ella se apañe.
@export var min_turn_radius: float = 220.0
## Ganancia del guiado proporcional.
@export var nav_gain: float = 3.0
## Segundos desde la suelta hasta tocar suelo. ESTA es su altura, y de aquí
## sale el alcance: lo que recorra picando durante este rato es hasta dónde
## llega. Subirlo la suelta más lejos; bajarlo la acerca.
@export var fall_time: float = 5.5

@export_group("Estabilización")
## Cabeceo de los primeros instantes, hasta que las aletas agarran aire. Más
## suave que el del misil: una bomba no sale disparada, se desprende.
@export var wobble_amount_deg: float = 8.0
@export var wobble_hz: float = 5.0
@export var wobble_decay: float = 3.0

@export_group("Espoleta")
## Estalla al pasar a menos de esto del punto de impacto, aunque no lo toque.
@export var proximity_radius: float = 10.0

@export_group("Arte")
## Grados a sumar al rumbo para orientar el sprite, igual que en el avión.
@export var sprite_offset_deg: float = -90.0

var _velocity: Vector2 = Vector2.ZERO
var _heading: float = 0.0
var _speed: float = 0.0
var _t: float = 0.0
var _last_los: float = 0.0
var _has_los := false
var _last_distance: float = INF


func _ready() -> void:
	set_physics_process(false)


func get_speed() -> float:
	return _velocity.length()


## Lo que le queda para tocar suelo, en px. Lo lee [MissileShadow] como altura.
##
## Son dos cuentas porque son dos finales: lo que le falta para llegar al blanco
## y lo que le queda de caída. Manda la que se agote antes, que es justo la que
## va a acabar el vuelo. Así la sombra se junta con la bomba en el momento del
## impacto tanto si acierta como si se queda corta — que es lo que hace legible
## el fallo: se ve tocar tierra lejos del blanco.
func get_distance_to_aim() -> float:
	var to_aim := global_position.distance_to(_aim_point)
	var left_to_fall := maxf(0.0, fall_time - _t) * maxf(_speed, 1.0)
	return minf(to_aim, left_to_fall)


func launch(shooter: Unit, muzzle: Node2D, at: Unit, weapon: WeaponType,
		aim_offset: Vector2 = Vector2.ZERO) -> void:
	super(shooter, muzzle, at, weapon, aim_offset)
	_heading = shooter.get_facing()
	# No sale con velocidad propia: se desprende y se queda con la del avión.
	# Ahí está la diferencia con el misil, que sí se empuja al salir del riel.
	_velocity = shooter.get_velocity()
	_speed = _velocity.length()
	rotation = _heading + deg_to_rad(sprite_offset_deg)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	_t += delta

	if _t < separation_time:
		_fall_off_the_pylon(delta)
	else:
		_glide(delta)

	global_position += _velocity * delta
	if _velocity.length() > 1.0:
		rotation = _velocity.angle() + deg_to_rad(sprite_offset_deg)

	# Toca suelo por una de dos: llegó al punto de impacto, o se le acabó la
	# caída y aterriza donde esté. Las dos salen aquí y no dentro del planeo,
	# porque una bomba sólo estalla una vez: dos caminos hasta `detonate()` en
	# el mismo frame repartirían el daño dos veces.
	if _t >= fall_time or _check_fuze():
		detonate()


## Todavía colgando de la inercia del avión: sin control y frenando.
func _fall_off_the_pylon(delta: float) -> void:
	_velocity = _velocity.lerp(Vector2.ZERO, minf(1.0, separation_drag * delta))
	_speed = _velocity.length()
	_heading = _velocity.angle() if _speed > 1.0 else _heading


func _glide(delta: float) -> void:
	_heading = wrapf(_heading + _steer(delta) * delta, -PI, PI)
	# Picando se gana velocidad: la altura se cambia por rapidez hasta que el
	# aire no deja más. Es lo contrario del misil, que arranca fuerte y se apaga.
	_speed = move_toward(_speed, terminal_speed, dive_acceleration * delta)
	_velocity = Vector2.RIGHT.rotated(_heading) * _speed


## Cuánto girar este frame. Mismo guiado proporcional que el misil — mide cuánto
## ROTA la línea bomba-blanco y vira en proporción —, pero con un radio de giro
## mucho más ancho. Con eso basta para que se comporte como una bomba y no como
## un misil sin humo: corrige la deriva de la suelta, no persigue nada.
func _steer(delta: float) -> float:
	var cmd := 0.0
	if is_instance_valid(target):
		_aim_point = target.global_position + _aim_offset
	var los := (_aim_point - global_position).angle()
	if _has_los:
		cmd = nav_gain * (angle_difference(_last_los, los) / delta)
	_last_los = los
	_has_los = true

	# Cabeceo inicial, se apaga solo.
	var amplitude := deg_to_rad(wobble_amount_deg) \
		* exp(-wobble_decay * (_t - separation_time))
	cmd += amplitude * sin(_t * wobble_hz * TAU) * wobble_hz

	var omega_max := _speed / maxf(min_turn_radius, 1.0)
	return clampf(cmd, -omega_max, omega_max)


## ¿Tocó ya? Aparte del impacto directo, estalla en el punto de máximo
## acercamiento: cuando la distancia deja de bajar, ya no se va a acercar más.
## Así existen los roces en vez de acertar siempre que pase cerca.
func _check_fuze() -> bool:
	var distance := global_position.distance_to(_aim_point)
	if distance <= direct_hit_radius:
		return true
	var passing := distance > _last_distance and distance <= proximity_radius
	_last_distance = distance
	return passing
