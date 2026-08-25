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
##
## **De las cinco formas, tres las averigua él solo.** Si el ratón está sobre un
## botón, si ese botón está pulsado y con qué mano dibujarlo son preguntas de
## interfaz y se contestan mirando la interfaz. Las otras dos le llegan de fuera
## porque no puede saberlas: si hay un enemigo a tiro debajo (lo sabe la
## selección) y si se está arrastrando una ventana (lo sabe la ventana).

## Qué está diciendo el cursor ahora mismo, de más urgente a menos: ver
## [method _pick].
enum Shape {
	POINTER,  ## Señalar y nada más.
	AIM,      ## Debajo hay algo a lo que este jugador puede disparar.
	HOVER,    ## Debajo hay algo que se puede pulsar.
	PRESS,    ## La mano cerrándose: o está pulsando un botón, o está encima
	          ## de algo que se puede agarrar. Es la misma idea, y por eso es
	          ## el mismo dibujo — lo que cambia es sobre qué.
	DRAG,     ## Agarrado y moviéndose.
}

## Cada forma con su dibujo y su punto activo. Los dos van juntos porque **el
## punto activo no se deduce del dibujo**: en la flecha es la punta y en la mira
## el centro. Y las tres manos se anclan por la **muñeca**, no por el dedo: al
## cerrarse, lo que un puño hace es curvar los dedos hacia la palma con la
## muñeca quieta. Ancladas por el dedo, la mano pegaría un salto al pulsar.
@export_group("Flecha")
@export var art_pointer: Texture2D
@export var hotspot_pointer: Vector2i = Vector2i.ZERO
@export_group("Mira")
@export var art_aim: Texture2D
@export var hotspot_aim: Vector2i = Vector2i(9, 9)
@export_group("Mano que señala")
@export var art_hover: Texture2D
@export var hotspot_hover: Vector2i = Vector2i(1, 0)
@export_group("Mano pulsando")
@export var art_press: Texture2D
@export var hotspot_press: Vector2i = Vector2i(1, -3)
@export_group("Mano arrastrando")
@export var art_drag: Texture2D
@export var hotspot_drag: Vector2i = Vector2i(1, -3)

@onready var _art: TextureRect = $Art

## Lo que le cuentan desde fuera. Ver [method set_aiming] y [method set_dragging].
var _aiming := false
var _dragging := false

var _shape: Shape = Shape.POINTER
var _hotspot: Vector2i = Vector2i.ZERO
## Forma -> [dibujo, punto activo]. Se arma una vez para que elegir sea una
## consulta y no una escalera de condiciones que crece con cada mano nueva.
var _looks: Dictionary = {}


func _ready() -> void:
	_looks = {
		Shape.POINTER: [art_pointer, hotspot_pointer],
		Shape.AIM: [art_aim, hotspot_aim],
		Shape.HOVER: [art_hover, hotspot_hover],
		Shape.PRESS: [art_press, hotspot_press],
		Shape.DRAG: [art_drag, hotspot_drag],
	}
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


## Hay algo a tiro debajo del ratón. Lo dice `SelectionManager`, que es el único
## que sabe qué está seleccionado y con qué puede disparar.
func set_aiming(value: bool) -> void:
	_aiming = value


## Se está arrastrando una ventana. Lo dicen las ventanas: desde fuera no se
## distingue de tener el botón pulsado sobre cualquier otra cosa.
func set_dragging(value: bool) -> void:
	_dragging = value


func _process(_delta: float) -> void:
	_wear(_pick())
	_follow()


## Qué forma toca. El orden **es** la regla, y va de lo más concreto a lo más
## general: arrastrar gana a todo, luego manda lo que diga el panel de debajo,
## después la regla de los botones, y la mira sólo entra cuando no hay
## interfaz de por medio.
##
## Las manos son cosa **de la interfaz y sólo de ella**. Sobre el mundo el cursor
## no cambia: ahí ya hablan la mira y las marcas de las unidades, y una mano
## encima sería un tercer mensaje diciendo lo mismo.
##
## **Se le pregunta al panel antes de mirar de qué clase es**, porque hay
## paneles partidos por dentro: el minimapa se estira por la franja de arriba
## y se pulsa por abajo, y "de qué clase eres" no puede contestar eso. Quien
## conoce sus zonas es él; aquí sólo se le hace la pregunta.
func _pick() -> Shape:
	if _dragging:
		return Shape.DRAG
	var under := get_viewport().gui_get_hovered_control()
	if under == null:
		return Shape.AIM if _aiming else Shape.POINTER
	if under.has_method(&"cursor_shape_at"):
		var asked: int = under.cursor_shape_at(under.get_local_mouse_position())
		return asked as Shape
	var button := under as BaseButton
	if button != null and not button.disabled:
		# Se pregunta por el botón físico del ratón y no por el estado del
		# `BaseButton`: ese estado es la casilla de los botones conmutados, y un
		# día que alguien ponga uno el cursor se quedaría con el puño puesto.
		return Shape.PRESS if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
				else Shape.HOVER
	return Shape.AIM if _aiming else Shape.POINTER


## Cambia de dibujo. Se sale pronto si ya lo llevaba puesto porque esto se
## pregunta cada fotograma: reasignar la textura y el tamaño sesenta veces por
## segundo para dejarlos igual no cuesta nada visible, pero tampoco hace nada.
func _wear(shape: Shape) -> void:
	if shape == _shape and _art.texture != null:
		return
	_shape = shape
	var look: Array = _looks.get(shape, _looks[Shape.POINTER])
	_art.texture = look[0]
	_hotspot = look[1]
	if _art.texture != null:
		_art.size = _art.texture.get_size()


## Redondeado hacia abajo a píxel entero **del juego**, no de la pantalla.
##
## Con la ventana al doble, un píxel de pantalla es medio píxel de juego: la
## posición del ratón llega con decimales y el dibujo saldría a media rejilla,
## borroso y temblando contra el resto de la UI. El precio es que el cursor
## avanza de dos en dos píxeles de pantalla, que es exactamente lo que hace todo
## lo demás que se ve.
func _follow() -> void:
	_art.position = get_viewport().get_mouse_position().floor() - Vector2(_hotspot)
