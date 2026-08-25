extends RefCounted

## Configuraciones de armamento del AH-1W. Viven junto al helicóptero por lo
## mismo que las del Harrier: qué puede colgar de cada ala es propio del modelo.
##
## El cañón no entra aquí: es fijo, va siempre y no ocupa estación (ver
## `UnitType.cannon` en `ah1w_supercobra_type.tres`), igual que el GAU-12 del
## Harrier tampoco aparece en su catálogo de configuraciones.
##
## Las estaciones ("H1", "H2", "R1", "R2", "W1", "W2") son provisionales: el
## Cobra todavía no tiene `Hardpoints` ni `HardpointRack` en su escena, así que
## hoy son sólo la cuenta de munición de cada configuración. El día que se monte
## el armazón de vuelo del Cobra, estos ids son los que tienen que llevar los
## `Marker2D`.

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
	var wingtips := PackedStringArray(["W1", "W2"])
	var catalog: Array[WeaponLoadout] = [
		WeaponLoadout.new(CAS, [
			WeaponMount.new(_HELLFIRE, ["H1"], 4),
			WeaponMount.new(_HYDRA70, ["R1"], 19),
			WeaponMount.new(_ZUNI, ["R2"], 4),
			WeaponMount.new(_AIM9, wingtips),
		]),
		WeaponLoadout.new(ESCORT, [
			WeaponMount.new(_HYDRA70, ["R1", "R2"], 19),
			WeaponMount.new(_HELLFIRE, ["H1"], 4),
			WeaponMount.new(_AIM9, wingtips),
		]),
		WeaponLoadout.new(ANTI_ARMOR, [
			WeaponMount.new(_HELLFIRE, ["H1", "H2"], 4),
			WeaponMount.new(_AIM9, wingtips),
		]),
	]

	var loadouts: Array[WeaponLoadout] = []
	for loadout in catalog:
		if loadout.can_arm_with(available_weapons):
			loadouts.append(loadout)
	return loadouts
