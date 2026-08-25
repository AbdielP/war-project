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
		# Apoyo aéreo cercano: cuatro Hellfire en el externo izquierdo, y un
		# contenedor de cohetes en cada interno — 19 Hydra a la izquierda, 4 Zuni
		# a la derecha. El externo derecho va vacío.
		#
		# Del externo izquierdo cuelga **un** Hellfire aunque lleve cuatro: en 23
		# px de ala no caben cuatro dibujados, y el rack ya sabe colgar sólo los
		# que quepan (ver `HardpointRack._mount_on_station`). Lo mismo vale para
		# los contenedores: uno cuelga y de él salen los 19.
		#
		# Es también la única carga con cuatro armas, y por eso la única que sube
		# el AIM-9 junto al cañón: con las cuatro en fila la ventana se ensancha.
		WeaponLoadout.new(CAS, [
			WeaponMount.new(_HELLFIRE, ["L2"], 4),
			WeaponMount.new(_HYDRA70, ["L3"], 19),
			WeaponMount.new(_ZUNI, ["R3"], 4),
			WeaponMount.new(_AIM9, wingtips),
		], null, _AIM9),
		# Escolta: contenedor de Hydra en los dos internos —19 cada uno, 38— y
		# cuatro Hellfire en el externo izquierdo. El externo derecho va vacío.
		WeaponLoadout.new(ESCORT, [
			WeaponMount.new(_HYDRA70, inner, 19),
			WeaponMount.new(_HELLFIRE, ["L2"], 4),
			WeaponMount.new(_AIM9, wingtips),
		]),
		# Antiblindaje: cuatro Hellfire en cada externo —ocho— y los internos
		# vacíos. Es la carga que va a por vehículos y no lleva nada más.
		WeaponLoadout.new(ANTI_ARMOR, [
			WeaponMount.new(_HELLFIRE, outer, 4),
			WeaponMount.new(_AIM9, wingtips),
		]),
	]

	var loadouts: Array[WeaponLoadout] = []
	for loadout in catalog:
		if loadout.can_arm_with(available_weapons):
			loadouts.append(loadout)
	return loadouts
