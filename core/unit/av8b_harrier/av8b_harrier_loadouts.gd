extends RefCounted

## Configuraciones de armamento del AV-8B. Viven junto al avión porque las
## estaciones y qué puede colgar de cada una son propias de este modelo.
##
## Estaciones reales del Harrier II (ver los Marker2D de av8b_harrier.tscn):
##   L1 / R1  externa — riel LAU-7, 1 arma. Siempre el AIM-9.
##   L2 / R2  central — estación pesada, hasta 3 armas con rack triple.
##   L3 / R3  interna — estación pesada, hasta 3 armas con rack triple.

const _AIM9   := preload("res://core/weapon/aim9_sidewinder.tres")
const _AIM120 := preload("res://core/weapon/aim120_amraam.tres")
const _AGM65  := preload("res://core/weapon/agm65_maverick.tres")
const _MK82   := preload("res://core/weapon/mk82.tres")
const _GBU54  := preload("res://core/weapon/gbu54.tres")


## Devuelve sólo las configuraciones que el jugador puede armar con las armas
## que tiene. Este archivo define qué configuraciones existen para el modelo;
## quién tiene qué armas es asunto de `PlayerFleet`.
static func build(available_weapons: Array) -> Array[WeaponLoadout]:
	var outboard := PackedStringArray(["L1", "R1"])
	var center := PackedStringArray(["L2", "R2"])
	var inboard := PackedStringArray(["L3", "R3"])

	var catalog: Array[WeaponLoadout] = [
		WeaponLoadout.new("CAS / Antitanque", [
			WeaponMount.new(_AGM65, center),
			WeaponMount.new(_GBU54, inboard),
			WeaponMount.new(_AIM9, outboard),
		]),
		WeaponLoadout.new("Bombardeo", [
			WeaponMount.new(_MK82, center, 3),
			WeaponMount.new(_AIM9, outboard),
		]),
		WeaponLoadout.new("Caza / Interceptor", [
			WeaponMount.new(_AIM120, center),
			WeaponMount.new(_AIM120, inboard),
			WeaponMount.new(_AIM9, outboard),
		]),
	]

	var loadouts: Array[WeaponLoadout] = []
	for loadout in catalog:
		if loadout.can_arm_with(available_weapons):
			loadouts.append(loadout)
	return loadouts
