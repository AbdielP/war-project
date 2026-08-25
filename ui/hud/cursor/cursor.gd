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

## Qué píxel del dibujo es "la punta", el que va justo donde está el ratón. En
## esta flecha es la esquina de arriba a la izquierda.
@export var hotspot: Vector2i = Vector2i.ZERO

@onready var _art: TextureRect = $Art


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
	_follow()


## Se sigue el ratón cada fotograma en vez de al recibir su evento: el ratón
## avisa cuando se mueve él, pero el cursor también se descoloca cuando lo que se
## mueve es lo de debajo —la cámara, una ventana—, y de eso no avisa nadie.
func _process(_delta: float) -> void:
	_follow()


## Redondeado hacia abajo a píxel entero **del juego**, no de la pantalla.
##
## Con la ventana al doble, un píxel de pantalla es medio píxel de juego: la
## posición del ratón llega con decimales y el dibujo saldría a media rejilla,
## borroso y temblando contra el resto de la UI. El precio es que el cursor
## avanza de dos en dos píxeles de pantalla, que es exactamente lo que hace todo
## lo demás que se ve.
func _follow() -> void:
	_art.position = (get_viewport().get_mouse_position()).floor() - Vector2(hotspot)
