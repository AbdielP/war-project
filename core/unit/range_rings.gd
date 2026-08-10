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


## El radio de la zona muerta la última vez que se dibujó. Sirve para notar que
## el arma cambió mientras se edita, ya que ese número no es un export de aquí y
## nadie avisa cuando se toca.
var _drawn_dead_zone: float = -1.0


func _draw() -> void:
	if not visible_rings:
		return
	# De fuera hacia dentro: los de dentro se dibujan encima y ganan donde se
	# toquen, que es el orden en que importan.
	_ring(detection_radius, detection_color)
	_ring(engagement_radius, engagement_color)
	_drawn_dead_zone = dead_zone_radius()
	_ring(_drawn_dead_zone, dead_zone_color)


## Dentro de esto el cañón ya no llega. **No es un export**: sale del `min_range`
## del arma, que es quien lo decide de verdad. Apuntarlo también aquí daría dos
## verdades sobre lo mismo y el círculo acabaría mintiendo.
##
## 0 = la unidad no tiene cañón, o su cañón no tiene zona muerta.
func dead_zone_radius() -> float:
	var unit := get_parent() as Unit
	if unit == null or unit.unit_type == null or unit.unit_type.cannon == null:
		return 0.0
	return unit.unit_type.cannon.min_range


func _process(_delta: float) -> void:
	# Sólo en el editor y sólo si cambió: el radio de dentro viene del arma, así
	# que tocar el `.tres` no dispara ningún setter de aquí y el círculo se
	# quedaría con el valor viejo hasta recargar la escena.
	if Engine.is_editor_hint() and not is_equal_approx(_drawn_dead_zone, dead_zone_radius()):
		queue_redraw()


func _ring(radius: float, color: Color) -> void:
	if radius <= 0.0:
		return
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, segments, color, line_width)
