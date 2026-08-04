extends Projectile
class_name GuidedMissile

## Misil guiado contra un blanco ya designado: el que el jugador eligió al dar
## la orden de ataque. Dispara y olvida — una vez fuera, el avión no lo maneja.
##
## El vuelo tiene fases, y el orden importa para que se lea como un misil y no
## como una bala teledirigida:
##   1. Separación — cae del ala sin motor, arrastrado por la inercia del avión.
##   2. Ignición — enciende y acelera hasta la velocidad de crucero.
##   3. Crucero guiado — corrige el rumbo mientras le quede combustible.
##   4. Sin combustible — sigue recto perdiendo velocidad. Aquí es donde falla
##      un tiro hecho desde demasiado lejos.
##
## El giro está limitado por RADIO, no por grados por segundo. Es la diferencia
## entre un misil y un misil invencible: cuanto más rápido va, más ancho vira,
## así que existe una geometría en la que no llega. En grados por segundo
## pasaría lo contrario — a más velocidad, giros más cerrados — y no habría
## forma de escapársele.

## Encendió el motor. Enganche para el sprite de fuego y la estela de humo.
signal motor_ignited
## Se quedó sin empuje: a partir de aquí planea. La estela se apaga.
signal fuel_spent

@export_group("Separación")
## Cuánto tarda en encender tras soltarse del ala. Durante este rato no guía
## ni empuja: por eso disparar demasiado cerca no sirve.
@export var separation_time: float = 0.25
## Velocidad propia al salir, sumada a la que llevaba el avión.
@export var launch_speed: float = 40.0
## Cuánto frena mientras cae del ala.
@export var separation_drag: float = 1.2

@export_group("Vuelo")
@export var cruise_speed: float = 300.0
@export var acceleration: float = 400.0
## Cuánto tarda en alcanzar la velocidad de crucero tras encender.
@export var boost_time: float = 0.8
## Radio de giro mínimo en px. Más bajo = más maniobrable. A velocidad de
## crucero es lo que decide si puede cerrar sobre un blanco que se le cruza.
@export var min_turn_radius: float = 90.0
## Ganancia del guiado proporcional. 3 a 5. Más alto = intercepta más plano,
## apuntando a donde el blanco VA a estar en vez de a donde está.
@export var nav_gain: float = 3.5
## Segundos de motor desde la ignición. Agotado, sigue recto y se va frenando.
@export var fuel_time: float = 2.5
## Cuánto frena al planear sin motor.
@export var coast_drag: float = 120.0
## Se autodestruye pasado esto aunque no haya llegado. Sin esto, un misil que
## falló se queda vagando por el mapa para siempre.
@export var max_lifetime: float = 8.0

@export_group("Estabilización")
## Serpenteo de los primeros instantes, mientras las aletas agarran aire. Se
## apaga solo — es puramente visual, pero es lo que evita que salga clavado
## como un láser.
@export var wobble_amount_deg: float = 12.0
@export var wobble_hz: float = 7.0
@export var wobble_decay: float = 4.0

@export_group("Espoleta")
## Explota al pasar a menos de esto del blanco, aunque no lo toque.
@export var proximity_radius: float = 12.0

@export_group("Arte")
## Grados a sumar al rumbo para orientar el sprite, igual que en el avión.
@export var sprite_offset_deg: float = -90.0

var _velocity: Vector2 = Vector2.ZERO
var _heading: float = 0.0
var _speed: float = 0.0
## Velocidad con la que arrancó el motor: la rampa de empuje parte de ahí y no
## de cero, porque el misil ya venía volando con la inercia del avión.
var _ignition_speed: float = 0.0
var _t: float = 0.0
var _ignited := false
var _spent := false
var _last_los: float = 0.0
var _has_los := false
var _last_distance: float = INF


func _ready() -> void:
	set_physics_process(false)


## Mientras cae del ala todavía no tiene velocidad propia: la que cuenta es la
## que heredó del avión.
func get_speed() -> float:
	return _velocity.length()


func launch(shooter: Unit, muzzle: Node2D, at: Unit, weapon: WeaponType,
		aim_offset: Vector2 = Vector2.ZERO) -> void:
	super(shooter, muzzle, at, weapon, aim_offset)
	_heading = shooter.get_facing()
	# Se lleva la velocidad del avión: un misil soltado a 150 px/s no arranca
	# parado, sale ya volando hacia donde iba el que lo tiró.
	_velocity = shooter.get_velocity() + Vector2.RIGHT.rotated(_heading) * launch_speed
	rotation = _heading + deg_to_rad(sprite_offset_deg)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= max_lifetime:
		# Se acabó el vuelo sin dar con nada: cae y explota donde esté.
		detonate()
		return

	if _t < separation_time:
		_fall_off_the_wing(delta)
	else:
		if not _ignited:
			_ignite()
		_fly(delta)

	global_position += _velocity * delta
	if _velocity.length() > 1.0:
		rotation = _velocity.angle() + deg_to_rad(sprite_offset_deg)


## Aún colgando de la inercia del avión: sin motor y sin guiado.
func _fall_off_the_wing(delta: float) -> void:
	_velocity = _velocity.lerp(Vector2.ZERO, minf(1.0, separation_drag * delta))


func _ignite() -> void:
	_ignited = true
	# El rumbo pasa de ser un vector heredado a ser el del misil: a partir de
	# aquí vuela él, no la inercia con la que salió.
	_heading = _velocity.angle()
	_speed = _velocity.length()
	_ignition_speed = _speed
	motor_ignited.emit()


func _fly(delta: float) -> void:
	var powered := _t < separation_time + fuel_time
	if not powered and not _spent:
		_spent = true
		fuel_spent.emit()

	_heading = wrapf(_heading + _steer(delta, powered) * delta, -PI, PI)

	if powered:
		# Acelera despacio al principio y fuerte después: se ve como un cohete
		# arrancando y no como algo lanzado ya a máxima velocidad.
		var ramp := clampf((_t - separation_time) / maxf(0.01, boost_time), 0.0, 1.0)
		_speed = move_toward(_speed, lerpf(_ignition_speed, cruise_speed, ramp * ramp),
				acceleration * delta)
	else:
		_speed = move_toward(_speed, 0.0, coast_drag * delta)

	_velocity = Vector2.RIGHT.rotated(_heading) * _speed

	if _check_fuze():
		detonate()


## Cuánto girar este frame. Guiado proporcional: mide cuánto ROTA la línea
## misil-blanco y vira en proporción, que es lo que lleva al punto de
## intercepción en vez de ir siempre por detrás persiguiéndolo.
##
## Sin combustible no guía: las aletas ya no tienen con qué maniobrar.
func _steer(delta: float, powered: bool) -> float:
	var cmd := 0.0
	if powered:
		if is_instance_valid(target):
			_aim_point = target.global_position + _aim_offset
		var los := (_aim_point - global_position).angle()
		if _has_los:
			cmd = nav_gain * (angle_difference(_last_los, los) / delta)
		_last_los = los
		_has_los = true

	# Serpenteo inicial, se apaga solo.
	var amplitude := deg_to_rad(wobble_amount_deg) \
		* exp(-wobble_decay * (_t - separation_time))
	cmd += amplitude * sin(_t * wobble_hz * TAU) * wobble_hz

	var omega_max := _speed / maxf(min_turn_radius, 1.0)
	return clampf(cmd, -omega_max, omega_max)


## ¿Toca explotar? Aparte del impacto directo, explota en el punto de máximo
## acercamiento: cuando la distancia deja de bajar y empieza a subir, ya no se
## va a acercar más. Así existen los roces — pasar a 20 px y no hacer nada —
## en vez de matar siempre que llegue cerca.
func _check_fuze() -> bool:
	var distance := global_position.distance_to(_aim_point)
	if distance <= direct_hit_radius:
		return true
	var passing := distance > _last_distance and distance <= proximity_radius
	_last_distance = distance
	return passing
