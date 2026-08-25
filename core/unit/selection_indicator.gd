@tool
extends Node2D
class_name SelectionIndicator

## La marca de que una unidad está señalada: una flecha flotando encima de ella.
##
## Antes era un rectángulo alrededor del casco, y con una unidad grande envolvía
## media pantalla. Una flecha no envuelve nada: dice cuál sin tapar lo que la
## rodea, y ocupa lo mismo sobre el Harrier que sobre el buque.
##
## El color sigue siendo el del bando —azul propio, verde aliado, rojo enemigo—,
## pero ahora no se tiñe, se cambia de dibujo. Teñir multiplica, y multiplicar el
## borde casi negro de la flecha por un rojo lo deja casi igual de negro: se
## perdería el filo claro que la despega del terreno, y los tonos de en medio se
## irían fuera de la paleta.

## Lo que ocupa el dibujo de la unidad. **No es el tamaño de la flecha**: es la
## caja de la unidad, y cada escena trae la suya.
##
## Se conserva de cuando esto pintaba un recuadro porque el dato es el mismo y ya
## estaba medido en las seis unidades; lo que cambió es para qué se usa.
@export var size: Vector2 = Vector2(32, 32):
	set(value):
		size = value
		queue_redraw()

## Dónde cae el centro de ese dibujo respecto al origen de la unidad.
##
## Casi siempre es cero y no hay que tocarlo. Lo necesita el buque: su PNG mide
## 160×304 pero el casco sólo ocupa 106×222 dentro, corrido 25 px hacia abajo, y
## contando desde el centro de la imagen la flecha se le quedaba a 66 px de la
## proa, flotando en el mar. **La medida se saca de la tinta del sprite, no del
## tamaño del archivo**: son cosas distintas en cuanto el dibujo no llena su PNG.
@export var center: Vector2 = Vector2.ZERO:
	set(value):
		center = value
		queue_redraw()

## Aire entre la punta de la flecha y el borde de la unidad.
@export var gap: float = 2.0:
	set(value):
		gap = value
		queue_redraw()

## Las cuatro caras, una por bando. Van las cuatro por el inspector aunque sólo
## se vea una: con un `preload` dentro del script la escena enseñaría un dibujo
## que el código va a sustituir en cuanto la unidad arranque.
@export_group("Arte")
@export var art_player: Texture2D:
	set(value):
		art_player = value
		_refresh()
@export var art_ally: Texture2D:
	set(value):
		art_ally = value
		_refresh()
@export var art_enemy: Texture2D:
	set(value):
		art_enemy = value
		_refresh()
@export var art_neutral: Texture2D:
	set(value):
		art_neutral = value
		_refresh()

## De qué bando es quien lleva la flecha. Lo pone `Unit` al arrancar.
var side: Team.Side = Team.Side.PLAYER:
	set(value):
		side = value
		_refresh()

var _art: Texture2D


func _ready() -> void:
	_refresh()
	# Una unidad que no está señalada no tiene nada que redibujar, y en el mapa
	# hay muchas más apagadas que encendidas. En el editor sí interesa siempre:
	# es donde se cuadra la flecha contra el dibujo.
	set_process(visible or Engine.is_editor_hint())


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_node_ready():
		set_process(visible or Engine.is_editor_hint())
		queue_redraw()


## La unidad gira y la flecha no, así que lo dibujado depende de un dato que
## cambia por fuera de este nodo. No hay aviso de "mi padre giró": se repinta
## mientras esté a la vista, que es sólo cuando alguien la está mirando.
func _process(_delta: float) -> void:
	queue_redraw()


## La flecha **no se mueve, se dibuja movida**.
##
## Colocarla cambiándole la posición al nodo obligaría a escribirle encima cada
## fotograma, y con `@tool` el editor guardaría ese trasteo dentro de las seis
## escenas de unidad. Dibujándola, el nodo se queda quieto en el origen y lo que
## se ajusta es el trazo.
##
## La altura no es media caja: la unidad **gira**, y un helicóptero de 23×48 pasa
## a medir 48 de ancho y 23 de alto al ponerse de perfil. Se calcula lo que
## sobresale la caja ya girada, así la flecha va pegada a ella en todo momento en
## vez de quedarse flotando en el aire media vuelta de cada dos.
##
## Y la flecha apunta hacia abajo siempre, gire lo que gire la unidad: girándola
## con ella dejaría de ser una marca y pasaría a leerse como un indicador de
## rumbo. Por eso se deshace el giro del padre —en su espacio, "arriba" no es
## arriba— tanto en el desplazamiento como en el trazo.
func _draw() -> void:
	if _art == null:
		return
	var unit := get_parent() as Node2D
	var turn: float = unit.global_rotation if unit != null else 0.0
	var reach := (absf(sin(turn)) * size.x + absf(cos(turn)) * size.y) * 0.5
	var up := Vector2(0.0, -(reach + gap)).rotated(-turn)
	draw_set_transform(center + up, -turn)
	# La punta de la flecha cae en ese punto, no su centro: lo que hay que
	# colocar contra el borde de la unidad es la punta.
	draw_texture(_art, Vector2(-_art.get_width() * 0.5, -_art.get_height()))


func _refresh() -> void:
	_art = _art_for(side)
	queue_redraw()


func _art_for(which: Team.Side) -> Texture2D:
	match which:
		Team.Side.ALLY:
			return art_ally
		Team.Side.ENEMY:
			return art_enemy
		Team.Side.NEUTRAL:
			return art_neutral
		_:
			return art_player
