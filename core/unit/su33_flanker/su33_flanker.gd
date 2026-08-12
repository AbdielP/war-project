extends Unit

## Qué ES el Su-33: un avión enemigo dando vueltas.
##
## **No tiene IA y no la va a tener por ahora.** Vuela en círculo sobre donde lo
## pongas y ya está: es un blanco aéreo de verdad —se mueve, hay que anticiparlo,
## los misiles tienen que interceptarlo— sin necesidad de decidir todavía nada
## sobre el comportamiento enemigo, que es cosa de cuando haya misiones.
##
## Y no hace falta inventar nada para eso: el circuito de espera es exactamente
## lo que hace el Harrier cuando se queda sin órdenes, así que aquí se reusa
## `PlaneController` + `OrbitBehavior` tal cual. Cuando llegue el momento de
## darle comportamiento, esto será el estado "sin órdenes" y no habrá que
## deshacer nada.

@onready var pilot: PlaneController = $PlaneController
@onready var orbit: OrbitBehavior = $OrbitBehavior


func _ready() -> void:
	super._ready()
	add_to_group("unit_air")
	# Arranca volando: no despega de ninguna parte, ya está en el aire cuando la
	# partida empieza. Orbita donde lo hayan colocado en el mapa.
	pilot.enable()
	orbit.orbit_at(global_position)


## El rumbo real de vuelo, no la rotación del nodo — igual que el Harrier, y con
## el mismo desfase: su arte también apunta a +Y.
func get_facing() -> float:
	return pilot.heading


func get_velocity() -> Vector2:
	return pilot.velocity
