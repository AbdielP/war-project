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
##
## `remaining` es lo que queda por tirar. Es estado de UNA salida concreta,
## no del catálogo: por eso los loadouts se clonan antes de colgarlos de un
## avión (ver `WeaponLoadout.clone`).

var weapon: WeaponType
var stations: PackedStringArray
var per_station: int
var remaining: int


func _init(p_weapon: WeaponType, p_stations: PackedStringArray, p_per_station: int = 1) -> void:
	weapon = p_weapon
	stations = p_stations
	per_station = p_per_station
	remaining = total()


## Armas montadas en total, sumando todas las estaciones del grupo.
func total() -> int:
	return stations.size() * per_station


## Gasta una. Devuelve si había.
func spend() -> bool:
	if remaining <= 0:
		return false
	remaining -= 1
	return true


## Copia cargada al completo, para un avión que sale nuevo.
func clone() -> WeaponMount:
	return WeaponMount.new(weapon, stations, per_station)
