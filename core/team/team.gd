extends RefCounted
class_name Team

## A qué bando pertenece una unidad, y qué significa eso.
##
## Es sólo identidad de bando: quién es de quién y de qué color se pinta. No
## decide quién puede atacar a quién en combate ni quién manda a las unidades
## — eso lo consultan el HUD y la IA a través de aquí, pero lo aplican ellos.
##
## El bando va en la instancia (`Unit.team`), no en el `UnitType`: el mismo
## T-14 puede ser enemigo en una misión y aliado en otra.

enum Side {
	PLAYER,  ## Las manda el jugador.
	ALLY,    ## Del lado del jugador, pero las mueve la IA.
	ENEMY,
}

## Colores identificativos (Resurrect64). El azul del jugador es el mismo
## accent que ya usa todo el HUD.
const _COLORS := {
	Side.PLAYER: Color(0.56078434, 0.827451, 1.0),      # #8fd3ff
	Side.ALLY:   Color(0.65882355, 0.7921569, 0.345098),# #a8ca58
	Side.ENEMY:  Color(0.9098039, 0.23137255, 0.23137255), # #e83b3b
}


## Las firmas usan `Team.Side` y no `Side` a secas: dentro del propio archivo
## GDScript trata el enum local como un tipo distinto del que ven los demás, y
## las llamadas de fuera no compilan.
static func color(side: Team.Side) -> Color:
	return _COLORS.get(side, _COLORS[Side.PLAYER])


## ¿Se disparan entre sí? Hoy hay un solo bando hostil, así que basta con que
## uno de los dos sea enemigo. El día que haya varias facciones enfrentadas
## entre ellas, este es el único sitio que cambia.
static func are_hostile(a: Team.Side, b: Team.Side) -> bool:
	return (a == Side.ENEMY) != (b == Side.ENEMY)
