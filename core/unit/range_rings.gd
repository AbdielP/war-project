@tool
extends Node2D
class_name RangeRings

## Los dos círculos de una unidad antiaérea, dibujados en el suelo.
##
## Son dos y no uno porque **ver y poder disparar no son lo mismo**: el radar
## alcanza mucho más lejos que las armas, así que hay una corona exterior en la
## que la unidad ya sabe que estás pero todavía no te llega. Ese hueco es la
## ventana en la que el jugador puede reaccionar, y por eso conviene poder verlo.
##
## Esto SÓLO dibuja. No detecta a nadie, no apunta y no dispara: cuando llegue
## esa parte, quien la haga debe leer los radios de aquí en vez de apuntarse los
## suyos, o habrá dos verdades distintas sobre hasta dónde llega la misma unidad.
##
## Es `@tool` para que los círculos se vean en el editor sin ejecutar el juego,
## que es lo que hace que ajustarlos sea cuestión de arrastrar un número.
##
## **No le pongas un `z_index` negativo.** El terreno es un `TileMapLayer` en 0,
## así que cualquier cosa por debajo queda tapada por el suelo y no se ve nada.
## En 0 basta: el mapa se dibuja antes por orden de árbol, y el vehículo va en 1,
## así que los círculos quedan sobre la hierba y bajo la unidad, que es donde
## tienen que estar.

## Hasta dónde ve. Fuera de este círculo la unidad no sabe que existes.
##
## Ojo al elegirlo: la pantalla son 640×384, así que a zoom 1x sólo se ven 320
## px alrededor del centro. Un radio mayor que eso existe, pero cae fuera de
## cuadro — para verlo entero hay que alejar la cámara.
@export var detection_radius: float = 260.0:
	set(value):
		detection_radius = maxf(value, 0.0)
		queue_redraw()

## Hasta dónde dispara. Siempre por dentro del anterior: un arma que llega más
## lejos de lo que el radar ve no serviría de nada.
@export var engagement_radius: float = 150.0:
	set(value):
		engagement_radius = maxf(value, 0.0)
		queue_redraw()

@export_group("Dibujo")
## Apagarlo deja los radios puestos y quita los círculos de la pantalla. Es lo
## que se usa cuando ya están ajustados y sólo estorban.
@export var visible_rings: bool = true:
	set(value):
		visible_rings = value
		queue_redraw()

@export var detection_color: Color = Color(0.98, 0.76, 0.29, 0.75):
	set(value):
		detection_color = value
		queue_redraw()

@export var engagement_color: Color = Color(0.9, 0.29, 0.31, 0.9):
	set(value):
		engagement_color = value
		queue_redraw()

## El alcance del misil: el círculo de tiro de fuera. Rojo como el del cañón,
## porque las dos cosas dicen lo mismo —desde aquí te disparan—, pero más claro
## para poder distinguirlos.
@export var missile_color: Color = Color(1.0, 0.45, 0.45, 0.9):
	set(value):
		missile_color = value
		queue_redraw()

## La zona muerta: el círculo de dentro, donde el cañón ya no puede tirar.
@export var dead_zone_color: Color = Color(0.4, 0.68, 0.42, 0.8):
	set(value):
		dead_zone_color = value
		queue_redraw()

## Grosor de la línea, en píxeles de mundo. A 1 se ve de un píxel a escala 1x,
## que es lo que pide el pixel art.
@export var line_width: float = 1.0:
	set(value):
		line_width = maxf(value, 0.1)
		queue_redraw()

## En cuántos tramos se parte cada círculo. Pocos y se ve un polígono; muchos y
## se gasta de más en un círculo enorme que apenas cambia.
@export_range(16, 256, 4) var segments: int = 96:
	set(value):
		segments = value
		queue_redraw()


## Los radios que no son exports, la última vez que se dibujaron. Sirven para
## notar que el armamento cambió mientras se edita: esos números salen de las
## armas y nadie avisa aquí cuando se tocan.
var _drawn_dead_zone: float = -1.0
var _drawn_missile: float = -1.0


func _draw() -> void:
	if not visible_rings:
		return
	# De fuera hacia dentro: los de dentro se dibujan encima y ganan donde se
	# toquen, que es el orden en que importan.
	_ring(detection_radius, detection_color)
	_drawn_missile = missile_radius()
	_ring(_drawn_missile, missile_color)
	_ring(engagement_radius, engagement_color)
	_drawn_dead_zone = dead_zone_radius()
	_ring(_drawn_dead_zone, dead_zone_color)


## Dentro de esto el cañón ya no llega. **No es un export**: sale del `min_range`
## del arma, que es quien lo decide de verdad. Apuntarlo también aquí daría dos
## verdades sobre lo mismo y el círculo acabaría mintiendo.
##
## 0 = la unidad no tiene cañón, o su cañón no tiene zona muerta.
func dead_zone_radius() -> float:
	var type := _property(&"unit_type") as UnitType
	if type == null or type.cannon == null:
		return 0.0
	return type.cannon.min_range


## Un arma que la unidad lleve apuntada en una propiedad suya.
func _weapon_of(property: StringName) -> WeaponType:
	return _property(property) as WeaponType


## Lee una propiedad del padre **sin llamarle a ningún método**.
##
## Es la diferencia entre verse en el editor y no verse: un script que no es
## `@tool` no se ejecuta ahí, así que preguntarle nada devolvería vacío y los
## círculos que salen del armamento no se dibujarían hasta arrancar el juego. Los
## valores exportados, en cambio, están puestos en el nodo y se leen igual.
func _property(name: StringName) -> Variant:
	var unit := get_parent()
	return unit.get(name) if unit != null else null


## Hasta dónde llega el arma de más alcance que lleve, si es que llega más lejos
## que el cañón. Es el anillo del misil.
##
## Tampoco es un export, por lo mismo que la zona muerta: el número ya está en el
## arma. Se mira **el armamento entero** y no un misil concreto para que valga
## igual el día que una batería lleve otra cosa.
##
## 0 = no lleva nada de más alcance que el cañón, y entonces no hay anillo que
## dibujar: sería el mismo círculo dos veces.
func missile_radius() -> float:
	var weapon := _weapon_of(&"missile")
	return weapon.max_range if weapon != null and weapon.max_range > engagement_radius \
		else 0.0


func _process(_delta: float) -> void:
	# Sólo en el editor y sólo si cambió: estos radios vienen de las armas, así
	# que tocar un `.tres` no dispara ningún setter de aquí y los círculos se
	# quedarían con el valor viejo hasta recargar la escena.
	if not Engine.is_editor_hint():
		return
	if not is_equal_approx(_drawn_dead_zone, dead_zone_radius()) \
			or not is_equal_approx(_drawn_missile, missile_radius()):
		queue_redraw()


func _ring(radius: float, color: Color) -> void:
	if radius <= 0.0:
		return
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, segments, color, line_width)
