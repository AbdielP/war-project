extends RefCounted
class_name WeaponMount

## Un tipo de arma montado sobre un grupo de estaciones simétricas.
##
## `stations` guarda ids de estación ("L2", "R2"), no nombres de marker: el
## HardpointRack resuelve qué markers pertenecen a cada estación.
##
## `per_station` es cuántas armas lleva realmente cada estación — es dato de
## munición, no de dibujo. Una estación con 3 Mk-82 sigue llevando 3 aunque
## en pantalla quepa una sola.

var weapon: WeaponType
var stations: PackedStringArray
var per_station: int


func _init(p_weapon: WeaponType, p_stations: PackedStringArray, p_per_station: int = 1) -> void:
	weapon = p_weapon
	stations = p_stations
	per_station = p_per_station


## Armas montadas en total, sumando todas las estaciones del grupo.
func total() -> int:
	return stations.size() * per_station
