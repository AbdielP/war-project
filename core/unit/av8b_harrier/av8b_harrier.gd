extends Unit

## Qué ES el Harrier: identidad, categoría y cómo recibe órdenes.
## No pilota — de eso se encarga PlaneController, y de a dónde ir,
## OrbitBehavior. Ambos cuelgan de esta misma escena.

signal order_fulfilled

@onready var pilot: PlaneController = $PlaneController
@onready var orbit: OrbitBehavior = $OrbitBehavior


func _ready() -> void:
	super._ready()
	add_to_group("unit_air")
	orbit.center_reached.connect(func() -> void: order_fulfilled.emit())


## El portaaviones cede el control cuando el avión ya está en el aire.
func start_flight(orbit_center: Node2D, initial_speed: float = -1.0) -> void:
	pilot.enable(initial_speed)
	orbit.orbit_around(orbit_center)


func receive_move_order(target: Vector2) -> void:
	orbit.orbit_at(target)
