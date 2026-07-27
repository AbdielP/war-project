extends Node

# Inventario de misión: qué unidades tiene cargadas cada barco.
# Por ahora hardcodeado. El puerto lo llenará cuando exista.
var _loadouts: Dictionary = {
	"LHD Wasp": [
		{
			"display_name": "AV-8B Harrier II",
			"scene": preload("res://core/unit/av8b_harrier/av8b_harrier.tscn"),
			"total": 6,
			"deployed": 0,
		}
	]
}


func get_loadout(ship_name: String) -> Array:
	return _loadouts.get(ship_name, [])


func try_deploy(entry: Dictionary) -> bool:
	if entry["deployed"] >= entry["total"]:
		return false
	entry["deployed"] += 1
	return true


func recall(entry: Dictionary) -> void:
	entry["deployed"] = max(0, entry["deployed"] - 1)
