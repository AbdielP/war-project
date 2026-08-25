extends RefCounted

## Configuraciones de armamento del AH-1W. Viven junto al helicóptero por lo
## mismo que las del Harrier: qué puede colgar de cada ala es propio del modelo.
##
## El cañón no entra aquí: es fijo, va siempre y no ocupa estación (ver
## `UnitType.cannon` en `ah1w_supercobra_type.tres`), igual que el GAU-12 del
## Harrier tampoco aparece en su catálogo de configuraciones.
##
## Estaciones reales del Cobra (ver los Marker2D de `ah1w_supercobra.tscn`):
##   L1 / R1  punta de ala — riel de autodefensa. Siempre el AIM-9.
##   L2 / R2  pilón exterior — carga pesada.
##   L3 / R3  pilón interior — carga pesada.

## Apoyo aéreo cercano: pegado a lo que haya en tierra.
const CAS := "CLOSE AIR SUP"
## Escolta armada: acompañar a lo que se mueva y responder a lo que aparezca.
const ESCORT := "ESCORT"
## Antiblindaje: contra vehículos, que es para lo que se hizo este aparato.
const ANTI_ARMOR := "ANTI ARMOR"

const _AIM9    := preload("res://core/weapon/aim9_sidewinder.tres")
const _HELLFIRE := preload("res://core/weapon/agm114_hellfire.tres")
const _HYDRA70  := preload("res://core/weapon/hydra70.tres")
const _ZUNI     := preload("res://core/weapon/zuni.tres")


## Las configuraciones que el jugador puede armar. La firma es la misma que la
## del Harrier —recibe las armas disponibles— para que el hangar no tenga que
## saber de qué modelo está hablando.
static func build(available_weapons: Array) -> Array[WeaponLoadout]:
	var wingtips := PackedStringArray(["L1", "R1"])
	var outer := PackedStringArray(["L2", "R2"])
	var inner := PackedStringArray(["L3", "R3"])
	var catalog: Array[WeaponLoadout] = [
		# La única que lleva cuatro armas, y por eso la única que sube el AIM-9
		# junto al cañón: con las cuatro en fila la ventana tenía que ensancharse.
		WeaponLoadout.new(CAS, [
			WeaponMount.new(_HELLFIRE, ["L3"], 4),
			WeaponMount.new(_HYDRA70, ["L2"], 19),
			WeaponMount.new(_ZUNI, ["R2"], 4),
			WeaponMount.new(_AIM9, wingtips),
		], null, _AIM9),
		WeaponLoadout.new(ESCORT, [
			WeaponMount.new(_HYDRA70, outer, 19),
			WeaponMount.new(_HELLFIRE, ["L3"], 4),
			WeaponMount.new(_AIM9, wingtips),
		]),
		WeaponLoadout.new(ANTI_ARMOR, [
			WeaponMount.new(_HELLFIRE, inner, 4),
			WeaponMount.new(_AIM9, wingtips),
		]),
	]

	var loadouts: Array[WeaponLoadout] = []
	for loadout in catalog:
		if loadout.can_arm_with(available_weapons):
			loadouts.append(loadout)
	return loadouts
