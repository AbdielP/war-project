extends RefCounted
class_name UnitWords

## Cómo se cuenta en palabras lo que una unidad está haciendo.
##
## **La unidad expone hechos y el HUD los pone en palabras** —a quién ataca, a
## dónde va—, y hasta ahora esas palabras las componía cada panel por su cuenta.
## Con dos sitios que dicen lo mismo (la etiqueta de selección y la ficha del
## mapa táctico) eso son dos textos que se separan en cuanto se toque uno.
##
## No guarda los rótulos: se los pasa quien llama, porque en la etiqueta son
## exportados y se editan desde el inspector. Lo que vive aquí es **el orden en
## que se decide qué contar**, que es lo que tiene que coincidir.


## En qué anda metida, en una línea.
##
## El orden importa: atacar manda sobre moverse, porque un avión que ataca
## también se está moviendo y lo primero es lo que el jugador quiere saber.
static func status(unit: Unit, map: MapView,
		idle: String, moving: String, attacking: String) -> String:
	if unit == null:
		return ""
	if is_instance_valid(unit.attack_target):
		return attacking + unit.attack_target.get_display_name()
	var going: Variant = unit.get_move_destination()
	if going != null:
		return moving + zone_of(going, map)
	return idle


## La coordenada del mapa ("F6"), o el punto en crudo si todavía no hay mapa que
## la traduzca. Mejor decir dónde de forma fea que no decirlo.
static func zone_of(world: Vector2, map: MapView) -> String:
	if map == null:
		return "%d, %d" % [world.x, world.y]
	var label := map.zone_label_at(world)
	return label if label != "" else "%d, %d" % [world.x, world.y]


## Los ocho rumbos, empezando por el este —que es hacia donde mira el ángulo
## cero— y girando en el sentido de la pantalla, donde la Y crece hacia abajo.
const _COMPASS: PackedStringArray = [
	"ESTE", "SURESTE", "SUR", "SUROESTE",
	"OESTE", "NOROESTE", "NORTE", "NORESTE",
]


## Hacia dónde mira, en punto cardinal.
##
## **Ocho y no los treinta y dos de una rosa de verdad**: el dato sirve para
## saber si viene o si va, y "nornoreste" no se lee más rápido que "norte" ni
## cabe en la ficha. Los grados exactos ya los enseña la flecha del mapa, que no
## redondea.
static func heading(unit: Unit) -> String:
	if unit == null:
		return ""
	var eighth := roundi(unit.get_facing() / (PI * 0.25))
	return _COMPASS[posmod(eighth, _COMPASS.size())]


## El bando, para la ficha. La frase entera y sin rótulo delante: "UNIDAD
## ALIADA" se entiende sola, y un "FILIACIÓN:" delante gasta media línea para
## nombrar algo que el propio valor ya dice.
static func team_of(unit: Unit) -> String:
	if unit == null:
		return ""
	match unit.team:
		Team.Side.PLAYER:
			return "UNIDAD PROPIA"
		Team.Side.ALLY:
			return "UNIDAD ALIADA"
		Team.Side.ENEMY:
			return "UNIDAD ENEMIGA"
		_:
			return "UNIDAD NEUTRAL"
