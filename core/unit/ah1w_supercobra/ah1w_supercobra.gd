extends Unit

## Qué ES el SuperCobra: identidad y cómo recibe órdenes. No pilota — de eso se
## encarga `HelicopterController`.
##
## Es mucho más corto que el Harrier y no por estar a medias: **un helicóptero no
## necesita comportamientos**. El avión los tiene porque no puede parar, así que
## hay que inventarle qué hacer cuando no hay nada que hacer —dar vueltas— y cómo
## acercarse a un blanco sin poder frenar —la pasada—. Aquí no: se le manda un
## punto, va, y se queda. Ir y esperar son lo mismo.
##
## Sin patrón de espera a propósito. Un helicóptero en su sitio ya está
## esperando.

signal order_fulfilled
## Dejó la cubierta. Lo reemite el piloto; se anuncia desde aquí porque quien
## escucha es el barco, y el barco habla con la unidad, no con sus tripas.
signal took_off

@onready var pilot: HelicopterController = $HelicopterController


func _ready() -> void:
	super._ready()
	add_to_group("unit_air")
	pilot.target_reached.connect(func() -> void: order_fulfilled.emit())
	pilot.took_off.connect(func() -> void: took_off.emit())


## El rumbo real, no la rotación del nodo: el arte apunta a +Y, así que la
## rotación lleva un desfase que el armamento no debe heredar.
func get_facing() -> float:
	return pilot.heading


func get_velocity() -> Vector2:
	return pilot.velocity


## A dónde va. Cuando llega deja de ir a ninguna parte: quedarse en el sitio no
## es una maniobra, es el reposo de este aparato.
func get_move_destination() -> Variant:
	return pilot.target if pilot.has_target else null


## El barco le cede el control **con el aparato todavía en cubierta**, al
## contrario que el avión, al que suelta ya volando. Aquí el despegue es suyo:
## sale cuando el jugador le dé un sitio a donde ir.
##
## `orbit_center` se ignora — no hay circuito de espera que montar alrededor del
## barco. Se acepta el argumento porque es lo que la cubierta llama a todo lo que
## despega, y no tiene por qué saber qué está soltando.
func start_flight(_orbit_center: Node2D) -> void:
	pilot.enable()


func receive_move_order(target: Vector2) -> void:
	super.receive_move_order(target)
	pilot.set_target(target)
