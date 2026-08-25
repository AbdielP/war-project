@tool
extends Node2D
class_name TargetMarker

## Cuatro esquinas cerrándose sobre lo que se ha mandado atacar.
##
## Dice tres cosas seguidas con el mismo dibujo. Al darle la orden, un destello
## en rojo oscuro: **la pulsación llegó**. Luego un latido lento entre las dos
## aperturas más anchas mientras la unidad se acerca: **sigue en ello**. Y
## cuando hay algo en el aire con impacto previsto, las esquinas gastan lo que
## les queda para llegar cerradas justo cuando llega el arma.
##
## Las esquinas **no son un dibujo de tamaño fijo**: son cuatro piezas de 8×8 que
## se colocan una a una contra la caja de la unidad. En el sheet la animación
## está dibujada sobre un cuadro de 32 que se cierra hasta 22, pero eso es la
## **holgura**, no la medida — entre el tanque y el buque hay un factor de cinco
## y ningún cuadro fijo vale para los dos.

## Cuántas aperturas hay dibujadas. La holgura extra va de `_STEPS - 1` a 0, un
## píxel por fotograma, que es como está dibujada la tira.
const _STEPS := 6

## Lado de cada esquina dentro del PNG, que trae las cuatro en dos filas.
const _PIECE := 8.0

## Los dos primeros fotogramas son el bucle de espera; del tercero en adelante,
## el cierre.
const _WAITING := 2

## Las cuatro esquinas en un solo PNG de 16×16 —arriba TL y TR, abajo BL y BR—
## en vez de ocho archivos sueltos. Las de abajo **no son las de arriba del
## revés**: llevan su propio remate, así que espejarlas saldría mal.
@export var art: Texture2D:
	set(value):
		art = value
		queue_redraw()

## Las mismas, en rojo oscuro. Es el acuse de la pulsación, y está dibujado a la
## apertura del **segundo** fotograma, no del primero: se pone donde va a seguir
## la animación para que el relevo no dé un salto.
@export var art_pressed: Texture2D:
	set(value):
		art_pressed = value
		queue_redraw()

## Aire entre la caja de la unidad y las esquinas ya cerradas. No baja a cero: un
## corchete pegado al casco se lee como parte del dibujo de la unidad.
@export var margin: float = 3.0

## Lo que dura cada apertura del latido de espera.
@export var beat: float = 0.35

## Lo que dura el destello de la pulsación.
@export var press_time: float = 0.12

## Cuánto antes del impacto empieza a cerrarse. Es el reparto de los cuatro
## fotogramas que quedan: más largo y se cierra despacio desde lejos, más corto
## y da un tirón al final.
@export var close_time: float = 1.0

## Segundos que faltan para el impacto, o negativo si no hay nada en el aire —el
## cañón, una bomba tonta, o el hueco entre dos disparos—. Lo pone quien conoce
## al atacante: esto vive en el **blanco**, y un blanco no sabe quién le apunta.
var impact_eta: float = -1.0

## Cuánto lleva puesta. De aquí salen el destello y el latido, y por eso se pone
## a cero cada vez que aparece: la orden es nueva aunque el nodo sea el mismo.
var _age: float = 0.0


func _ready() -> void:
	set_process(visible or Engine.is_editor_hint())


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_node_ready():
		set_process(visible or Engine.is_editor_hint())
		if visible:
			_age = 0.0
			impact_eta = -1.0
		queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


## Qué apertura toca ahora, de 0 (la más abierta) a `_STEPS - 1` (cerrada).
##
## El orden de las tres preguntas importa: el destello manda sobre todo lo demás
## —dura un pestañeo y es la respuesta a un gesto del jugador—, el cierre manda
## sobre el latido, y el latido es lo que queda cuando no hay nada en el aire.
func _step() -> int:
	if _age < press_time:
		return 1
	if impact_eta >= 0.0 and impact_eta <= close_time:
		var done := 1.0 - impact_eta / close_time
		return clampi(_WAITING + int(done * float(_STEPS - _WAITING)), _WAITING, _STEPS - 1)
	return int(fmod((_age - press_time) / beat, float(_WAITING)))


## Las esquinas van **cuadradas con la pantalla**, no giradas con la unidad: son
## un corchete de HUD, y girado dejaría de leerse como tal. Así que se mide lo
## que ocupa la caja **ya girada** —igual que hace la flecha— y las cuatro piezas
## se ponen en las esquinas de eso.
func _draw() -> void:
	var box := _box()
	if box == null:
		return
	var texture: Texture2D = art_pressed if _age < press_time else art
	if texture == null:
		return
	var unit := get_parent() as Node2D
	var turn: float = unit.global_rotation if unit != null else 0.0
	var across := absf(cos(turn))
	var down := absf(sin(turn))
	var half := Vector2(
			(across * box.size.x + down * box.size.y) * 0.5,
			(down * box.size.x + across * box.size.y) * 0.5)
	var reach := half + Vector2.ONE * (margin + float(_STEPS - 1 - _step()))
	draw_set_transform(box.center, -turn)
	for i in 4:
		var right := i % 2 == 1
		var low := i >= 2
		var at := Vector2(
				reach.x - _PIECE if right else -reach.x,
				reach.y - _PIECE if low else -reach.y)
		var from := Vector2(_PIECE if right else 0.0, _PIECE if low else 0.0)
		draw_texture_rect_region(texture,
				Rect2(at, Vector2(_PIECE, _PIECE)),
				Rect2(from, Vector2(_PIECE, _PIECE)))


## La caja de la unidad se le pide a la flecha de selección en vez de repetirla
## aquí. Es el mismo dato —lo que ocupa el dibujo y dónde cae su centro—, medido
## y ajustado ya en las seis escenas; copiado, el día que alguien retoque una se
## quedaría vieja la otra y nadie se enteraría hasta verlo torcido.
func _box() -> SelectionIndicator:
	var unit := get_parent()
	return unit.get_node_or_null(^"SelectionIndicator") as SelectionIndicator if unit != null else null
