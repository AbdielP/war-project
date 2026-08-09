extends EffectEmitter
class_name SmokeTrail

## Rastro de humo, de cualquier cosa que eche humo: el motor de un misil, la
## boca de un cañón. No dibuja nada — va soltando bocanadas y son ellas las que
## forman la cola.
##
## Cada bocanada se queda donde nació con el rumbo que llevaba quien la escupió
## en ese instante. Por eso el rastro se dobla solo en las curvas: no hay una
## cola que haya que deformar, hay un reguero de piezas que ya salieron
## apuntando a donde se iba entonces. Vale igual para un misil virando que para
## un avión metido en un giro con el cañón abierto.
##
## Lo suyo, frente a los otros emisores, es que **siembra por distancia y no por
## tiempo**: así la densidad del rastro no depende de los fps ni de lo rápido
## que se vaya. Un misil a 300 px/s y un avión a 90 dejan la misma cola de
## espesa; lo único que cambia es lo deprisa que la van dejando.

## Cada cuántos píxeles recorridos sale una bocanada. Más bajo = rastro más
## denso y más nodos vivos. Conviene tenerlo por debajo del ancho de la bocanada
## recién nacida, o el rastro se lee a trozos en vez de continuo.
@export var spacing_px: float = 4.0

var _last_spawn: Vector2 = Vector2.ZERO
var _last_rotation: float = 0.0


func _begin() -> void:
	_last_spawn = global_position
	_last_rotation = global_rotation


func _physics_process(_delta: float) -> void:
	var here := global_position
	var travelled := _last_spawn.distance_to(here)
	if travelled < spacing_px:
		return

	# Siembra a lo largo del tramo recorrido, no en el punto donde está ahora.
	# A velocidad de crucero un misil avanza 5 px por frame: soltar una sola
	# bocanada por frame dejaría el rastro a trozos y con el espaciado atado a
	# los fps en vez de a la distancia.
	var here_rotation := global_rotation
	var steps := int(travelled / spacing_px)
	for i in range(1, steps + 1):
		var t := (spacing_px * i) / travelled
		_spawn(_last_spawn.lerp(here, t), lerp_angle(_last_rotation, here_rotation, t))

	_last_spawn = _last_spawn.lerp(here, (spacing_px * steps) / travelled)
	_last_rotation = here_rotation
