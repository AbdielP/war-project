extends Node2D
class_name MissileSmokeTrail

## Estela de humo del misil. No dibuja nada: va soltando bocanadas sueltas por
## el mundo mientras el motor esté encendido, y son ellas las que forman la cola.
##
## Cada bocanada se queda donde nació con el rumbo que llevaba el misil en ese
## instante. Por eso la estela se dobla sola en las curvas: no hay una cola que
## haya que deformar, hay un rastro de piezas que ya salieron apuntando a donde
## el misil iba entonces.
##
## Este nodo se coloca en la tobera y escucha al misil. El misil no sabe que
## existe — mismo trato que [MissileExhaust].

@export var puff_scene: PackedScene
## Cada cuántos píxeles recorridos sale una bocanada. Más bajo = estela más
## densa y más nodos vivos. La bocanada recién nacida mide ~6 px de ancho (luego
## se abre hasta 16 al disiparse), así que por debajo de eso las piezas se
## solapan ya desde la tobera y la cola se lee continua de principio a fin.
@export var spacing_px: float = 4.0

var _world: Node = null
var _last_spawn: Vector2 = Vector2.ZERO
var _last_rotation: float = 0.0


func _ready() -> void:
	set_physics_process(false)
	var source: Node = get_parent()
	if source.has_signal(&"motor_ignited"):
		source.connect(&"motor_ignited", _on_motor_ignited)
	if source.has_signal(&"fuel_spent"):
		source.connect(&"fuel_spent", _on_fuel_spent)


func _on_motor_ignited() -> void:
	# Las bocanadas cuelgan de donde cuelga el misil, no del misil: cuando este
	# explote, la cola que dejó tiene que seguir deshaciéndose sola.
	_world = get_parent().get_parent()
	if _world == null or puff_scene == null:
		return
	_last_spawn = global_position
	_last_rotation = global_rotation
	set_physics_process(true)


func _on_fuel_spent() -> void:
	# Sin motor no hay humo nuevo. Las que ya salieron terminan su animación.
	set_physics_process(false)


func _physics_process(_delta: float) -> void:
	var here := global_position
	var travelled := _last_spawn.distance_to(here)
	if travelled < spacing_px:
		return

	# Siembra a lo largo del tramo recorrido, no en el punto donde está ahora.
	# A velocidad de crucero el misil avanza 5 px por frame: soltar una sola
	# bocanada por frame dejaría la estela a trozos y con el espaciado atado a
	# los fps en vez de a la distancia.
	var here_rotation := global_rotation
	var steps := int(travelled / spacing_px)
	for i in range(1, steps + 1):
		var t := (spacing_px * i) / travelled
		_spawn(_last_spawn.lerp(here, t), lerp_angle(_last_rotation, here_rotation, t))

	_last_spawn = _last_spawn.lerp(here, (spacing_px * steps) / travelled)
	_last_rotation = here_rotation


func _spawn(at: Vector2, angle: float) -> void:
	var puff := puff_scene.instantiate() as Node2D
	if puff == null:
		return
	_world.add_child(puff)
	puff.global_position = at
	puff.global_rotation = angle
