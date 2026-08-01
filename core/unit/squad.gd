extends RefCounted
class_name Squad

var leader: Unit = null
var members: Array[Unit] = []


func add(unit: Unit) -> void:
	members.append(unit)
	if leader == null:
		leader = unit
