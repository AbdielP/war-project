extends PanelContainer
class_name Minimap

## El mapa pequeño de la esquina. No es un mando de navegación: es el terreno de
## un vistazo, el recuadro de dónde estás mirando, y un botón para abrir el mapa
## grande. Todo el dibujo lo hace [MapView]; esto lleva el tamaño y el click.
##
## **El panel se ajusta al dibujo, no al revés.** La escala del mapa es entera,
## así que en un panel de tamaño cualquiera siempre sobra un borde muerto. Aquí
## se hace al contrario: se mira lo que ocupa el dibujo y el panel se recorta a
## esa medida.

## El jugador quiere el mapa a pantalla completa.
signal expand_requested

## Franja de arriba que sirve de agarre para estirar. Fuera de ella, pulsar abre
## el mapa grande.
const GRIP_PX := 6.0
## Hasta dónde puede crecer. Más allá tapa el registro de eventos y deja de ser
## un mapa "de un vistazo".
const MAX_HEIGHT := 220.0

@onready var _view: MapView = $MapView

## El borde de abajo no se mueve nunca: el minimapa vive pegado a la esquina, y
## crecer hacia arriba es lo único que tiene sentido ahí.
var _bottom: float = 0.0
var _resizing: bool = false
var _fitting: bool = false
var _wanted_height: float = 0.0


func _ready() -> void:
	_bottom = position.y + size.y
	_view.refitted.connect(_fit_to_drawing)
	_fit_to_drawing()


## Recorta el panel a lo que mide el dibujo. Se llama cada vez que el mapa
## recalcula su escala, así que estirar el panel salta de una escala entera a la
## siguiente en vez de dejar franjas negras por el camino.
func _fit_to_drawing() -> void:
	var drawing := _view.drawn_size()
	if drawing == Vector2.ZERO or _fitting:
		return
	_resize_to(drawing + _pad())


func _pad() -> Vector2:
	var box := get_theme_stylebox("panel")
	return Vector2(
			box.get_margin(SIDE_LEFT) + box.get_margin(SIDE_RIGHT),
			box.get_margin(SIDE_TOP) + box.get_margin(SIDE_BOTTOM))


func _resize_to(wanted: Vector2) -> void:
	if wanted.is_equal_approx(size):
		return
	# El vallado evita el ida y vuelta: cambiar el tamaño hace refitar la vista,
	# que vuelve a avisar aquí.
	_fitting = true
	# La posición primero: cambiar el tamaño avisa a quien escuche `resized`, y
	# si se hiciera después leerían el sitio viejo. El registro de eventos se
	# coloca justo encima, así que se le quedaría el hueco descuadrado.
	position.y = _bottom - wanted.y
	size = wanted
	_fitting = false


## Estirar no elige píxeles, elige **escala**. El alto que pide el ratón se
## traduce a la escala entera que quepa en él, y el panel se pone del tamaño
## exacto que ocupa el dibujo a esa escala — de ahí que salte de golpe entre 1x,
## 2x y 3x en vez de arrastrar franjas negras. Estirar sólo a lo alto no serviría
## de nada: el ancho también manda sobre la escala, así que crecen los dos.
func _apply_height(height: float) -> void:
	var unit := _view.size_for_scale(1)
	if unit == Vector2.ZERO or unit.y <= 0.0:
		return
	var pad := _pad()
	var scale := int(floor((height - pad.y) / unit.y))
	_resize_to(unit * clampi(scale, 1, _max_scale(unit, pad)) + pad)


func _max_scale(unit: Vector2, pad: Vector2) -> int:
	return maxi(int(floor((MAX_HEIGHT - pad.y) / unit.y)), 1)


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_resizing = button.position.y <= GRIP_PX
			_wanted_height = size.y
			# Pulsar el mapa —no el agarre— abre el grande. Se atiende al
			# pulsar y no al soltar porque aquí no hay más gestos que competir.
			if not _resizing:
				expand_requested.emit()
		else:
			_resizing = false
		accept_event()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _resizing:
		# El alto pedido se acumula aparte del real: el panel salta por escalas
		# enteras, así que si se leyera de `size` el arrastre se quedaría
		# atascado en el escalón en vez de seguir al ratón.
		_wanted_height = clampf(_wanted_height - motion.relative.y, 0.0, MAX_HEIGHT)
		_apply_height(_wanted_height)
		accept_event()


## Dos rayas en el borde de arriba: sin ellas nadie adivina que se puede
## estirar. Caben ahí porque ese borde es más grueso justo para esto — dentro
## las taparía el mapa, que se dibuja después.
func _draw() -> void:
	var mid := size.x * 0.5
	for i in 2:
		var y := 2.0 + i * 2.0
		draw_line(Vector2(mid - 6.0, y), Vector2(mid + 6.0, y),
				Color(0.19215686, 0.21176471, 0.21960784), 1.0)


func set_order_marker(world_position: Vector2) -> void:
	_view.set_order_marker(world_position)


func clear_order_marker() -> void:
	_view.clear_order_marker()
