extends Unit

## Qué ES el Harrier: identidad, categoría y cómo recibe órdenes.
## No pilota — de eso se encarga PlaneController, y de a dónde ir,
## OrbitBehavior o ChaseBehavior. Todos cuelgan de esta misma escena.
##
## Aquí sólo se arbitra cuál de los dos comportamientos manda: los dos le dan
## puntos al mismo piloto y no pueden correr a la vez.

signal order_fulfilled

@onready var pilot: PlaneController = $PlaneController
@onready var orbit: OrbitBehavior = $OrbitBehavior
@onready var chase: ChaseBehavior = $ChaseBehavior


func _ready() -> void:
	super._ready()
	add_to_group("unit_air")
	orbit.center_reached.connect(func() -> void: order_fulfilled.emit())
	chase.target_lost.connect(_on_target_lost)


## El portaaviones cede el control cuando el avión ya está en el aire.
func start_flight(orbit_center: Node2D, initial_speed: float = -1.0) -> void:
	pilot.enable(initial_speed)
	_orbit_around(orbit_center)


func receive_move_order(target: Vector2) -> void:
	super.receive_move_order(target)
	chase.stop()
	orbit.orbit_at(target)


func receive_attack_order(target: Unit) -> void:
	super.receive_attack_order(target)
	orbit.stop()
	chase.pursue(target)


## Se quedó sin objetivo en pleno viaje. Un avión no puede pararse: orbita
## donde llegó, no donde estaba el enemigo — seguir volando hasta un punto
## vacío parecería que no se enteró.
func _on_target_lost() -> void:
	set_attack_target(null)
	orbit.orbit_at(global_position)


func _orbit_around(center: Node2D) -> void:
	chase.stop()
	orbit.orbit_around(center)
