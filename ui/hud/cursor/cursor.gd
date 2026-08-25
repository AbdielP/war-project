extends CanvasLayer
class_name MouseCursor

## El puntero del ratón, dibujado dentro del juego en vez de por el sistema.
##
## El cursor del sistema se pinta a la resolución de la pantalla, no a la del
## juego: un dibujo de 13×14 saldría del tamaño de una uña al lado de una unidad
## que la ventana está agrandando ×2 o ×3. Dibujado aquí dentro va escalado con
## todo lo demás y con la misma rejilla de píxeles.
##
## Va en su propia capa y no como un hermano más del HUD: media pantalla del HUD
## se llama `move_to_front()` al abrirse —la ventana del buque, el mapa
## táctico—, y eso reordena a los hermanos. La capa lo pone por encima de todos
## sin depender de quién se movió el último.

## Qué está diciendo el cursor ahora mismo.
enum Shape {
	POINTER,  ## Señalar y nada más.
	AIM,      ## Debajo hay algo a lo que este jugador puede disparar.
}

## Los dos dibujos y sus dos puntos activos, por el inspector. El punto activo
## **no se deduce del dibujo**: en la flecha es la punta, arriba a la izquierda,
## y en la mira es su centro. Cambiar de forma sin cambiarlo dejaría la mira
## apuntando 9 px por debajo y a la derecha de donde está el ratón.
@export_group("Flecha")
@export var art_pointer: Texture2D
@export var hotspot_pointer: Vector2i = Vector2i.ZERO
@export_group("Mira")
@export var art_aim: Texture2D
@export var hotspot_aim: Vector2i = Vector2i(9, 9)

@onready var _art: TextureRect = $Art

var _shape: Shape = Shape.POINTER
var _hotspot: Vector2i = Vector2i.ZERO


func _ready() -> void:
	# En un móvil no hay ratón que dibujar, y esconder el del sistema dejaría al
	# jugador sin nada. Se pregunta por el aparato, no por el sistema operativo:
	# un portátil con pantalla táctil tiene las dos cosas.
	if not DisplayServer.has_feature(DisplayServer.FEATURE_MOUSE):
		hide()
		set_process(false)
		return
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	# Fuera de la ventana manda el del sistema otra vez, así que el nuestro sobra:
	# sin esto se queda clavado en el borde por donde salió.
	var window := get_window()
	window.mouse_entered.connect(show)
	window.mouse_exited.connect(hide)
	_wear(Shape.POINTER)


## Cambia de dibujo. Se sale pronto si ya lo llevaba puesto porque esto se
## pregunta cada fotograma: reasignar la textura y el tamaño sesenta veces por
## segundo para dejarlos igual no cuesta nada visible, pero tampoco hace nada.
func set_shape(shape: Shape) -> void:
	if shape != _shape:
		_wear(shape)


## Se sigue el ratón cada fotograma en vez de al recibir su evento: el ratón
## avisa cuando se mueve él, pero el cursor también se descoloca cuando lo que se
## mueve es lo de debajo —la cámara, una ventana—, y de eso no avisa nadie.
func _process(_delta: float) -> void:
	_follow()


func _wear(shape: Shape) -> void:
	_shape = shape
	var aiming := shape == Shape.AIM
	_art.texture = art_aim if aiming else art_pointer
	_hotspot = hotspot_aim if aiming else hotspot_pointer
	if _art.texture != null:
		_art.size = _art.texture.get_size()
	_follow()


## Redondeado hacia abajo a píxel entero **del juego**, no de la pantalla.
##
## Con la ventana al doble, un píxel de pantalla es medio píxel de juego: la
## posición del ratón llega con decimales y el dibujo saldría a media rejilla,
## borroso y temblando contra el resto de la UI. El precio es que el cursor
## avanza de dos en dos píxeles de pantalla, que es exactamente lo que hace todo
## lo demás que se ve.
func _follow() -> void:
	_art.position = get_viewport().get_mouse_position().floor() - Vector2(_hotspot)
