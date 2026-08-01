extends RefCounted
class_name Squad

var leader: Unit = null
var members: Array[Unit] = []
var _leader_slot := -1  # slot de cubierta del líder actual


# "slot" = plaza de cubierta asignada al pedir el despliegue (ver flight_deck.gd).
# El líder es quien tenga el slot más alto del grupo: los slots más altos
# despegan primero (_launch_next), así el líder siempre despega primero.
func add(unit: Unit, slot: int) -> void:
	members.append(unit)
	if slot > _leader_slot:
		_leader_slot = slot
		leader = unit
