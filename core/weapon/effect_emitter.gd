extends Node2D
class_name EffectEmitter

## Base de los efectos que van SOLTANDO cosas por el mundo mientras algo dura:
## el humo de un motor, el humo de boca de un cañón, las trazadoras de una
## ráfaga. Todos hacen lo mismo salvo en un punto.
##
## Lo común, que está aquí:
##   - Engancharse por nombre de señal a quien los enciende y los apaga, sin
##     que ese alguien tenga que conocerlos.
##   - Averiguar cuál es "el mundo" y parir allí, no colgado de quien emite.
##   - Encenderse y apagarse.
##
## Lo que cambia, que va en cada subclase: **cuándo toca soltar la siguiente**.
## El humo siembra por distancia recorrida —para que la densidad no dependa de
## los fps ni de la velocidad— y una ráfaga por cadencia, porque un cañón dispara
## a su ritmo aunque el avión vaya frenando. Es la única diferencia real entre
## los dos, y por eso es lo único que se hereda.
##
## Lo que se suelta **cuelga del mundo, no de quien lo soltó**. Colgado del
## emisor viajaría con él, que es justo lo contrario de un rastro; y así el
## rastro sobrevive a su dueño y termina de deshacerse solo cuando el misil ya
## explotó o el avión ya se fue.

## Qué se suelta. Es lo que distingue un humo de otro y un humo de una
## trazadora: la misma mecánica con otro dibujo y otra vida.
@export var spawn_scene: PackedScene

@export_group("Enganche")
## Quién enciende y apaga esto. Por defecto el padre; se apunta a otro nodo
## cuando quien manda no es de quien cuelga — los efectos del cañón cuelgan del
## avión pero los manda su `WeaponSystem`.
@export var source_path: NodePath = ^".."
## Señal de esa fuente que lo enciende. Vacío = no se engancha a nada y hay que
## llamar a `start()` a mano.
@export var start_signal: StringName = &""
## Señal que lo apaga.
@export var stop_signal: StringName = &""

var _world: Node = null


func _ready() -> void:
	set_physics_process(false)
	hook_up(self, source_path, start_signal, stop_signal, start, stop)


## Engancha dos métodos a dos señales de otro nodo, si es que las tiene. Está
## aquí y es estática porque no todos los efectos pueden heredar de este nodo —
## un fogonazo es un `AnimatedSprite2D` — pero todos se enganchan igual.
##
## Que la señal no exista no es un error: así se puede colocar y probar un
## efecto antes de que exista quien lo dispare.
static func hook_up(node: Node, path: NodePath, on_signal: StringName,
		off_signal: StringName, on_start: Callable, on_stop: Callable) -> void:
	var source: Node = node.get_node_or_null(path)
	if source == null:
		return
	if on_signal != &"" and source.has_signal(on_signal):
		source.connect(on_signal, on_start)
	if off_signal != &"" and source.has_signal(off_signal):
		source.connect(off_signal, on_stop)


## Empieza a soltar desde donde esté ahora.
func start() -> void:
	_world = get_parent().get_parent()
	if _world == null or spawn_scene == null:
		return
	_begin()
	set_physics_process(true)


## Deja de soltar. Lo que ya salió termina su animación y se borra solo.
func stop() -> void:
	set_physics_process(false)


## Punto de partida de la cuenta que lleve la subclase. El portero es
## `set_physics_process()`, no una bandera aparte.
func _begin() -> void:
	pass


## El rumbo REAL de quien emite, no la rotación de este nodo.
##
## No son lo mismo y confundirlos se paga caro: el arte del avión apunta a +Y,
## así que su rotación lleva −90 de desfase. Heredarla mandaba las trazadoras
## perpendiculares al morro. Mismo motivo por el que `Projectile` pregunta
## `get_facing()` en vez de leer la rotación del que dispara.
##
## Si de quien cuelga no es una unidad — el humo de un misil cuelga del misil —
## no hay a quién preguntar y vale la rotación, que es lo que había.
func _emit_heading() -> float:
	var shooter := get_parent() as Unit
	return shooter.get_facing() if shooter != null else global_rotation


func _spawn(at: Vector2, angle: float) -> Node2D:
	var thing := spawn_scene.instantiate() as Node2D
	if thing == null:
		return null
	_world.add_child(thing)
	thing.global_position = at
	thing.global_rotation = angle
	return thing
