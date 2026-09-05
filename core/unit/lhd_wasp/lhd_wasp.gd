extends Unit

@onready var flight_deck: FlightDeck = $FlightDeck
## Por donde sale la fuerza de desembarco. Es el gemelo de `flight_deck` por
## popa: uno saca lo que vuela y el otro lo que flota.
@onready var well_deck: WellDeck = $WellDeck


func _ready() -> void:
	super._ready()
	add_to_group("unit_maritime")


## Por dónde recoge a los suyos. **Contesta el buque y no quien pregunta**: el
## que quiere volver sabe volar o navegar, no qué muelles tiene este barco, y un
## día habrá barcos con uno solo.
##
## Lo decide el medio por el que llega, que es la única diferencia que importa.
## Qué está haciendo su cubierta de vuelo. **Aquí se dice el hecho y el HUD lo
## pone en palabras**, como con todo lo demás que cuenta una unidad.
func get_deck_mode() -> FlightDeck.Mode:
	var deck := flight_deck as FlightDeck
	return deck.mode() if is_instance_valid(deck) else FlightDeck.Mode.IDLE


func deck_for(unit: Unit) -> Node:
	if unit == null:
		return null
	if unit.get_domain() == UnitType.Domain.AIR:
		return flight_deck
	return well_deck
