extends RefCounted

## Configuraciones de armamento del AH-1W. Viven junto al helicóptero por lo
## mismo que las del Harrier: qué puede colgar de cada ala es propio del modelo.
##
## **Todavía sin armas.** Los tres papeles existen para poder elegir misión en el
## hangar y sacar aparatos a cubierta; lo que lleven colgado se decide cuando
## haya con qué. Al no pedir ninguna arma, `can_arm_with` las deja pasar siempre
## y las tres salen ofrecidas — que es justo lo que se quiere ahora.

## Apoyo aéreo cercano: pegado a lo que haya en tierra.
const CAS := "CAS / Apoyo cercano"
## Escolta armada: acompañar a lo que se mueva y responder a lo que aparezca.
const ESCORT := "Escolta armada"
## Antiblindaje: contra vehículos, que es para lo que se hizo este aparato.
const ANTI_ARMOR := "Ataque antiblindaje"


## Las configuraciones que el jugador puede armar. La firma es la misma que la
## del Harrier —recibe las armas disponibles— para que el hangar no tenga que
## saber de qué modelo está hablando, aunque hoy no se mire nada.
static func build(_available_weapons: Array) -> Array[WeaponLoadout]:
	var loadouts: Array[WeaponLoadout] = []
	for name in [CAS, ESCORT, ANTI_ARMOR]:
		loadouts.append(WeaponLoadout.new(name, []))
	return loadouts
