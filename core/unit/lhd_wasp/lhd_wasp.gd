extends Unit

@onready var flight_deck: Node = $FlightDeck


func _ready() -> void:
	super._ready()
	add_to_group("unit_maritime")
