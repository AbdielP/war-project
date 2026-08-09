extends Node2D
class_name SmokeTrail

## Rastro de humo. No dibuja nada: va soltando bocanadas sueltas por el mundo
## mientras esté encendido, y son ellas las que forman la cola.
##
## Cada bocanada se queda donde nació con el rumbo que llevaba quien la escupió
## en ese instante. Por eso el rastro se dobla solo en las curvas: no hay una
## cola que haya que deformar, hay un reguero de piezas que ya salieron
## apuntando a donde se iba entonces. Vale igual para un misil virando que para
## un avión metido en un giro con el cañón abierto.
##
## Sirve para cualquier cosa que eche humo porque no sabe qué la enciende: se le
## dicen los nombres de las dos señales del padre y él se engancha. El motor de
## un misil (`motor_ignited` / `fuel_spent`) y un cañón disparando son el mismo
## problema — algo empieza, algo termina, y mientras tanto sale humo.
##
## Lo que cambia de un humo a otro es el dibujo y la densidad, y las dos son
## datos: `puff_scene` y `spacing_px`. Nada de esto se hereda ni se copia.

## Qué bocanada se siembra. Es lo que distingue el humo de un misil del de un
## cañón: la misma mecánica con otro dibujo y otra duración.
@export var puff_scene: PackedScene
## Cada cuántos píxeles recorridos sale una bocanada. Más bajo = rastro más
## denso y más nodos vivos. Conviene tenerlo por debajo del ancho de la bocanada
## recién nacida, o el rastro se lee a trozos en vez de continuo.
@export var spacing_px: float = 4.0

@export_group("Enganche")
## Señal del padre que enciende el humo. Vacío = no se engancha a nada y hay que
## llamar a `start()` a mano.
@export var start_signal: StringName = &"motor_ignited"
## Señal del padre que lo apaga.
@export var stop_signal: StringName = &"fuel_spent"

var _world: Node = null
var _last_spawn: Vector2 = Vector2.ZERO
var _last_rotation: float = 0.0


func _ready() -> void:
	set_physics_process(false)
	# Duck-typing, igual que en el resto del proyecto: quien eche humo no tiene
	# que heredar de nada, le basta con emitir estas dos señales. Y si no las
	# emite, tampoco pasa nada — se enciende a mano.
	var source: Node = get_parent()
	if start_signal != &"" and source.has_signal(start_signal):
		source.connect(start_signal, start)
	if stop_signal != &"" and source.has_signal(stop_signal):
		source.connect(stop_signal, stop)


## Empieza a echar humo desde donde esté ahora.
func start() -> void:
	# Las bocanadas cuelgan de donde cuelga quien las echa, no de él: cuando
	# muera, el rastro que dejó tiene que seguir deshaciéndose solo.
	_world = get_parent().get_parent()
	if _world == null or puff_scene == null:
		return
	_last_spawn = global_position
	_last_rotation = global_rotation
	set_physics_process(true)


## Deja de echar humo. Las bocanadas que ya salieron terminan su animación.
func stop() -> void:
	set_physics_process(false)


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


func _spawn(at: Vector2, angle: float) -> void:
	var puff := puff_scene.instantiate() as Node2D
	if puff == null:
		return
	_world.add_child(puff)
	puff.global_position = at
	puff.global_rotation = angle
