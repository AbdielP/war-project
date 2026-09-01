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

# La fuerza de desembarco embarcada, con la misma forma que `_loadouts` — el
# panel de tropas es el mismo mueble que el del hangar y lee lo mismo. Lo que no
# lleva es `weapon_loadouts`: un carro sale con lo que tiene puesto y no se le
# cuelga nada.
#
# **Cuántas plazas ocupa cada uno no está aquí**, está en su `UnitType`
# (`deck_slots`): es propiedad del modelo, no de este buque, y teniéndolo en el
# tipo no hay un segundo sitio que se quede viejo.
#
# Provisional, igual que el resto de este archivo: lo llenará el puerto.
var _troops: Dictionary = {
	"LHD Wasp": [
		{
			"display_name": "M1A1 Abrams",
			"scene": preload("res://core/unit/m1a1_abrams/m1a1_abrams.tscn"),
			"total": 2,
			"deployed": 0,
		},
		{
			"display_name": "LAV-25",
			"scene": preload("res://core/unit/lav25/lav25.tscn"),
			"total": 6,
			"deployed": 0,
		},
		{
			"display_name": "AAV-7 Amtrac",
			"scene": preload("res://core/unit/aav7_amtrac/aav7_amtrac.tscn"),
			"total": 4,
			"deployed": 0,
		},
	]
}

# Las lanchas de desembarco de cada buque. Van aparte de las tropas porque no son
# tropa: son el vehículo que las lleva, y la pantalla las trata distinto — no se
# eligen de la rejilla, se llenan.
var _craft: Dictionary = {
	"LHD Wasp": [
		{
			"display_name": "LCAC",
			"scene": preload("res://core/unit/lcac/lcac.tscn"),
			"total": 2,
			"deployed": 0,
		},
	]
}


## El armamento que el jugador tiene hoy. Lo lee el puerto para enseñar el pañol;
## el hangar sigue filtrando configuraciones por su cuenta con la misma lista.
func available_weapons() -> Array:
	return _available_weapons


## Lo que ese buque lleva embarcado para desembarcar.
func get_troops(ship_name: String) -> Array:
	return _troops.get(ship_name, [])


## Las lanchas de desembarco de ese buque.
func get_craft(ship_name: String) -> Array:
	return _craft.get(ship_name, [])


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
