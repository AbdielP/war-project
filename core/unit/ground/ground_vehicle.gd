extends Unit
class_name GroundVehicle

## Un vehículo que va por el suelo y obedece órdenes de movimiento. Del cómo se
## conduce se encarga [TankController]; esto es lo que sabe **de sí mismo**:
## dónde puede pisar y cuándo dar una orden por terminada.
##
## Va aquí y no en la escena del Abrams porque la pregunta es la misma para el
## LAV, para el Amtrac y para el T-14: lo único que cambia entre ellos son los
## números del conductor, que están en el inspector. Un carro nuevo se monta
## poniendo esta escena y ajustando dos casillas, no escribiendo otro script.
##
## **Pisa tierra y arena, y nada más.** La regla va atada al terreno y no al
## destino, igual que la de la lancha que descarga por estar en la arena: así
## sobrevive a que el jugador cambie de idea a mitad de camino. Mandarlo al otro
## lado del agua no es un error que haya que rechazar — el carro avanza hasta la
## orilla y se para, que es exactamente lo que haría.

## Terminó lo que se le mandó, haya llegado o se haya quedado en la orilla. Es lo
## que el HUD escucha para retirar el aviso de la orden en curso.
signal order_fulfilled

## Por dónde puede circular. Es del vehículo y no del terreno: el día que haya
## uno con ruedas que no suba a la arena, se le quita "arena" aquí y ya está.
@export var drivable: PackedStringArray = PackedStringArray([
	MapTerrain.LAND_KIND, MapTerrain.BEACH_KIND,
])

@onready var pilot: TankController = $TankController

var _layer: TileMapLayer = null
## Ya se buscó la capa. Existe para **no volver a buscarla si no aparece**:
## encontrarla cuesta un recorrido del árbol entero, y esto se pregunta en cada
## paso de cada vehículo. Sin esta bandera, una escena de prueba sin mapa acaba
## barriendo el árbol sesenta veces por segundo y por carro.
var _layer_checked: bool = false


func _ready() -> void:
	super._ready()
	pilot.can_drive = _can_drive
	pilot.target_reached.connect(_on_order_done)
	pilot.blocked.connect(_on_order_done)
	# Se toma el mando aquí porque un vehículo de tierra nace ya colocado: lo
	# pone el mapa o lo suelta la lancha, y en los dos casos su sitio y su rumbo
	# están puestos antes de entrar en el árbol. Un aparato embarcado no puede
	# hacer esto —mientras está dentro es carga del buque—, y por eso la lancha
	# y los aviones encienden su piloto en el momento en que los sueltan.
	pilot.enable()


func get_facing() -> float:
	return pilot.heading


func get_velocity() -> Vector2:
	return pilot.velocity


func get_move_destination() -> Variant:
	return pilot.destination() if pilot.has_target() else null


func receive_move_order(target: Vector2) -> void:
	super.receive_move_order(target)
	# Un punto, no una lista, porque hoy no hay nada que rodear. El conductor
	# guarda lista de todas formas: ver [member TankController.route].
	pilot.set_target(target)


func _on_order_done() -> void:
	order_fulfilled.emit()


## Si el carro puede pisar ahí.
##
## Sin capa de tiles a la que preguntar dice que sí, como hace la lancha: una
## escena de prueba abierta con F6 no tiene mapa, y negarse por eso dejaría el
## vehículo clavado justo en lo que se quiere mirar.
func _can_drive(world: Vector2) -> bool:
	if not _layer_checked:
		_layer_checked = true
		_layer = MapTerrain.find_layer(get_tree())
	if _layer == null:
		return true
	return MapTerrain.kind_under(_layer, world) in drivable
