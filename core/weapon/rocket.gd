extends Projectile
class_name Rocket

## Cohete sin guía. Sale del contenedor apuntado a un sitio y va derecho hasta
## él; lo que pase por el camino le da igual y lo que se mueva se le escapa.
##
## **No es un misil sin buscador ni una bomba con motor**, y por eso no hereda de
## ninguno de los dos. El misil corrige durante todo el vuelo — la mitad de su
## código es guiado proporcional y radio de giro, y aquí nada de eso existe. La
## bomba no tiene motor y cae por inercia, y todo su vuelo sale de cuánto frena.
## Un cohete empuja recto y ya está: es el más simple de los tres y meterlo en
## cualquiera de los otros sería arrastrar maquinaria que no usa jamás.
##
## [b]De dónde sale que falle.[/b] No de una tirada. El punto al que va se lo
## desvía quien lo lanza (`WeaponType.salvo_spread`), así que cada cohete de la
## andanada apunta a un sitio distinto alrededor del blanco y el conjunto bate un
## área. Un blanco quieto en el centro se come casi todos; uno que se movió
## mientras volaban, casi ninguno. Eso es exactamente lo que significa "sin
## guía", y es lo que distingue una andanada de cohetes de un misil.
##
## Por eso tampoco tiene cuenta atrás de impacto: `guides()` sigue diciendo que
## no. Un número prometería una puntería que este arma no tiene.

## Encendió. Lo escucha la estela de humo. Sale en el disparo y no más tarde: un
## cohete no se separa antes de arrancar, sale del tubo ya empujando.
signal motor_ignited
## Se acabó el grano. La estela se apaga y a partir de aquí sólo va frenando.
signal fuel_spent

@export_group("Vuelo")
## Velocidad a la que sale del tubo, antes de que el grano tire de él.
@export var launch_speed: float = 90.0
@export var cruise_speed: float = 340.0
## Lo que tarda en llegar a crucero. Corto: un cohete acelera de golpe, y ese
## tirón inicial es medio carácter del arma.
@export var boost_time: float = 0.35
## Segundos de motor. Agotado sigue recto perdiendo velocidad, que es cuando un
## tiro hecho desde demasiado lejos se queda corto.
@export var fuel_time: float = 1.1
## Cuánto frena por segundo sin motor.
@export var coast_drag: float = 150.0
## Se borra pasado esto aunque no haya llegado a ninguna parte. Sin esto, un
## cohete tirado contra nada se va del mapa y no vuelve.
@export var max_lifetime: float = 3.0

@export_group("Espoleta")
## Revienta al pasar a menos de esto de su punto de apuntado. No mira si hay
## alguien: el daño lo reparte la explosión, y de eso ya sabe `Projectile`.
@export var arm_radius: float = 5.0

@export_group("Arte")
## Grados a sumar al rumbo para orientar el sprite, igual que en todo lo demás
## que vuela: el arte apunta a +Y.
@export var sprite_offset_deg: float = -90.0

var _heading: float = 0.0
var _speed: float = 0.0
var _burning: float = 0.0
var _alive: float = 0.0
var _motor := true


func launch(shooter: Unit, muzzle: Node2D, at: Unit, weapon: WeaponType,
		aim_offset: Vector2 = Vector2.ZERO) -> void:
	super(shooter, muzzle, at, weapon, aim_offset)
	# El rumbo se fija AQUÍ y no se vuelve a tocar. Es lo único que hay que
	# entender de esta clase: a partir de esta línea el cohete ya no sabe dónde
	# está el blanco, sólo hacia dónde va.
	_heading = (_aim_point - global_position).angle()
	global_rotation = _heading + deg_to_rad(sprite_offset_deg)
	_speed = launch_speed
	motor_ignited.emit()


func get_speed() -> float:
	return _speed


func _physics_process(delta: float) -> void:
	_alive += delta
	if _alive >= max_lifetime:
		# Se apagó lejos de todo. No explota: reventar en mitad del mar dejaría
		# un fogonazo que no significa nada.
		queue_free()
		return

	if _motor:
		_burning += delta
		# La rampa de empuje se reparte en `boost_time` y después mantiene. Con
		# el grano agotado deja de empujar y empieza a frenar.
		var ramp := (cruise_speed - launch_speed) / maxf(boost_time, 0.01)
		_speed = minf(_speed + ramp * delta, cruise_speed)
		if _burning >= fuel_time:
			_motor = false
			fuel_spent.emit()
	else:
		_speed = maxf(_speed - coast_drag * delta, 0.0)

	var step := Vector2.RIGHT.rotated(_heading) * _speed * delta
	# El punto de apuntado puede quedar entre este frame y el siguiente: mirando
	# sólo dónde acaba el paso, un cohete rápido lo cruza sin enterarse y sigue
	# de largo. Se comprueba el tramo entero.
	if _crosses_the_aim_point(step):
		global_position = _aim_point
		detonate()
		return
	global_position += step


## ¿Pasa por su punto de apuntado durante este paso? Distancia del punto al
## segmento que recorre, no a sus extremos.
func _crosses_the_aim_point(step: Vector2) -> bool:
	if global_position.distance_to(_aim_point) <= arm_radius:
		return true
	var length := step.length()
	if length <= 0.0:
		return false
	var along := (_aim_point - global_position).dot(step) / length
	if along < 0.0 or along > length:
		return false
	var nearest := global_position + step.normalized() * along
	return nearest.distance_to(_aim_point) <= arm_radius
