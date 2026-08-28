extends Node

const _HarrierLoadouts := preload("res://core/unit/av8b_harrier/av8b_harrier_loadouts.gd")
const _CobraLoadouts := preload("res://core/unit/ah1w_supercobra/ah1w_supercobra_loadouts.gd")

# Armamento que el jugador tiene disponible. Por ahora hardcodeado, igual que
# el inventario de aeronaves: el día que exista compra/desbloqueo cambia quién
# llena esta lista, no quién la lee.
#
# Una configuración de armamento sólo se ofrece si TODAS sus armas están aquí
# (ver `WeaponLoadout.can_arm_with`). Quitar un arma de esta lista hace
# desaparecer del hangar las misiones que la necesitan — sin avisos ni botones
# deshabilitados: lo que no se tiene, no se ve.
#
# Se declara antes que `_loadouts` a propósito: los inicializadores de miembro
# corren en orden de declaración y `_loadouts` lee esta lista.
var _available_weapons: Array = [
	preload("res://core/weapon/aim9_sidewinder.tres"),
	preload("res://core/weapon/aim120_amraam.tres"),
	preload("res://core/weapon/agm65_maverick.tres"),
	preload("res://core/weapon/mk82.tres"),
	preload("res://core/weapon/gbu54.tres"),
	preload("res://core/weapon/agm114_hellfire.tres"),
	preload("res://core/weapon/hydra70.tres"),
	preload("res://core/weapon/zuni.tres"),
]

# Inventario de misión: qué unidades tiene cargadas cada barco.
# Por ahora hardcodeado. El puerto lo llenará cuando exista.
# `weapon_loadouts` son las configuraciones de armamento que ofrece esa
# aeronave; las define cada modelo en su propia carpeta, ya filtradas por lo
# que el jugador tiene.
var _loadouts: Dictionary = {
	"LHD Wasp": [
		{
			"display_name": "AV-8B Harrier II",
			"scene": preload("res://core/unit/av8b_harrier/av8b_harrier.tscn"),
			"total": 6,
			"deployed": 0,
			"weapon_loadouts": _HarrierLoadouts.build(_available_weapons),
		},
		{
			"display_name": "AH-1W SuperCobra",
			"scene": preload("res://core/unit/ah1w_supercobra/ah1w_supercobra.tscn"),
			"total": 4,
			"deployed": 0,
			"weapon_loadouts": _CobraLoadouts.build(_available_weapons),
		}
	]
}

## El armamento que el jugador tiene hoy. Lo lee el puerto para enseñar el pañol;
## el hangar sigue filtrando configuraciones por su cuenta con la misma lista.
func available_weapons() -> Array:
	return _available_weapons


## Los barcos de la flota, por nombre. Sale de las claves del inventario y no de
## una segunda lista: el día que se compre un barco crece solo.
func ships() -> Array:
	return _loadouts.keys()


func get_loadout(ship_name: String) -> Array:
	return _loadouts.get(ship_name, [])


func try_deploy(entry: Dictionary) -> bool:
	if entry["deployed"] >= entry["total"]:
		return false
	entry["deployed"] += 1
	return true


func recall(entry: Dictionary) -> void:
	entry["deployed"] = max(0, entry["deployed"] - 1)
