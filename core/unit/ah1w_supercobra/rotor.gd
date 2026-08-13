extends Sprite2D
class_name Rotor

## Las palas de un helicóptero: arrancan cuando el aparato ya está colocado y van
## cogiendo vueltas hasta el régimen de vuelo.
##
## **Provisional**, hasta que haya animación de hélice. Girar un dibujo de palas
## rectas se lee bien de lejos, pero no es lo mismo que el disco borroso de un
## rotor a régimen.
##
## Sabe cuándo arrancar **mirando si el aparato se mueve**, no porque nadie se lo
## diga: mientras la cubierta lo lleva del elevador a su sitio está rodando, y en
## cuanto se queda quieto es que ya llegó. Así no hace falta que el barco conozca
## qué saca ni que el helicóptero le avise.
##
## Y una vez arrancado **no se para**: un rotor no se apaga porque el aparato
## empiece a moverse, que es justo lo contrario de lo que pasa.

## Vueltas por segundo a régimen, en grados. Un rotor real da unas 5 vueltas por
## segundo; aquí manda que se lea, no el dato.
@export var max_speed_deg: float = 1400.0
## Lo que tarda en llegar a ese régimen desde parado. Lo lento del arranque es
## medio efecto: un rotor que aparece ya girando se ve como un adorno pegado.
@export var spin_up_time: float = 4.0
## Cuánto tiene que llevar quieto el aparato para dar por hecho que ya está
## colocado. Corto, pero no cero: entre dos tramos del taxi hay frames en los que
## apenas se mueve.
@export var settle_time: float = 0.5
## Por debajo de esto se considera quieto, en píxeles por segundo.
@export var still_speed: float = 2.0

var _speed: float = 0.0
var _spinning := false
var _still_for: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO
var _has_last := false


func _physics_process(delta: float) -> void:
	if not _spinning:
		_watch_for_stillness(delta)
		if not _spinning:
			return
	# Sube al régimen y se queda ahí. `spin_up_time` es lo que tarda de 0 a tope,
	# así que la aceleración sale de dividir uno por otro.
	_speed = move_toward(_speed, max_speed_deg,
		max_speed_deg / maxf(spin_up_time, 0.01) * delta)
	rotation += deg_to_rad(_speed) * delta


## ¿Ya se quedó quieto? Se mide el movimiento del propio nodo en el mundo, que
## es lo que la cubierta va cambiando mientras lo lleva a su sitio.
func _watch_for_stillness(delta: float) -> void:
	var here := global_position
	if not _has_last:
		_last_pos = here
		_has_last = true
		return
	var moved := here.distance_to(_last_pos) / maxf(delta, 0.0001)
	_last_pos = here
	if moved > still_speed:
		_still_for = 0.0
		return
	_still_for += delta
	if _still_for >= settle_time:
		_spinning = true
