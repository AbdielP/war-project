extends Unit

@onready var flight_deck: Node = $FlightDeck
## Por donde sale la fuerza de desembarco. Es el gemelo de `flight_deck` por
## popa: uno saca lo que vuela y el otro lo que flota.
@onready var well_deck: WellDeck = $WellDeck


func _ready() -> void:
	super._ready()
	add_to_group("unit_maritime")
