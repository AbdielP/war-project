extends Label
class_name BrevityCall

## Una llamada suelta: el cartelito que sigue a un avión un par de segundos y se
## borra solo. Lo crea [BrevityCalls], que es quien sabe cuándo hay que cantar.
##
## Sigue a la unidad **en píxeles de pantalla**, no colgado de ella: si la
## cámara hace zoom, el cartel cambia de sitio pero no de tamaño.
##
## Y sigue vivo aunque la unidad muera. Ahí está media gracia: si a un avión lo
## derriban justo después de disparar, su última llamada se queda un momento
## donde estaba en vez de desaparecer con él.

var _unit: Unit = null
## Dónde estaba la unidad la última vez que existió. Es lo que permite que la
## llamada termine su desvanecido en el sitio correcto tras un derribo.
var _last_screen: Vector2 = Vector2.ZERO
var _offset: Vector2 = Vector2.ZERO
var _rise: float = 0.0
var _age: float = 0.0
var _hold: float = 0.9
var _fade: float = 0.5


## Empieza a seguir a esa unidad. Se le pasa todo de fuera para que el cartel no
## tenga ajustes propios: los suyos son los de [BrevityCalls], en un solo sitio.
func follow(unit: Unit, offset: Vector2, hold: float, fade: float,
		rise: float) -> void:
	_unit = unit
	_offset = offset
	_hold = hold
	_fade = fade
	_rise = rise
	if is_instance_valid(unit):
		_last_screen = unit.get_global_transform_with_canvas().origin
	_place()


## ¿Es la llamada de ese avión? Lo pregunta [BrevityCalls] para no dejar dos
## carteles del mismo en la misma esquina.
func belongs_to(unit: Unit) -> bool:
	return _unit == unit


## Que empiece a irse ya, sin esperar su turno. Se acorta lo que le quede de
## vida en vez de borrarlo: desaparecer de golpe se ve como un parpadeo.
func dismiss() -> void:
	if _age < _hold:
		_age = _hold


func _process(delta: float) -> void:
	_age += delta
	if _age >= _hold + _fade:
		queue_free()
		return
	# Sube mientras entra y se queda quieto: el mismo gesto que el nombre de
	# `UnitTag`, para que las dos cosas se lean como parte del mismo HUD.
	_rise = move_toward(_rise, 0.0, delta * 12.0)
	if _age > _hold and _fade > 0.0:
		modulate.a = 1.0 - (_age - _hold) / _fade
	_place()


func _place() -> void:
	if is_instance_valid(_unit):
		_last_screen = _unit.get_global_transform_with_canvas().origin
	position = _last_screen + _offset + Vector2(0.0, _rise)
