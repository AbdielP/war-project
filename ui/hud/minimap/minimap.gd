extends PanelContainer
class_name Minimap

## El mapa pequeño de la esquina. No es un mando de navegación: es el terreno de
## un vistazo, el recuadro de dónde estás mirando, y un botón para abrir el mapa
## grande. Todo el dibujo lo hace [MapView]; esto lleva el tamaño y el click.
##
## **El panel se ajusta al dibujo, no al revés.** La escala del mapa es entera y
## el mapa casi nunca tiene la proporción del marco, así que en un panel de
## tamaño fijo siempre sobra un borde muerto — franjas de fondo arriba y abajo
## que se leen como un fallo. Aquí se hace al contrario: se mira lo que ocupa el
## mapa y el panel se recorta a esa medida.
##
## Por eso el marco va como nine-patch: **el sprite es una muestra, no una
## medida**. Su tamaño en el PNG no manda sobre el panel; lo que manda son sus
## bordes y sus esquinas, que se conservan al píxel a cualquier medida.

## El jugador quiere el mapa a pantalla completa.
signal expand_requested

## Se ha empezado o terminado a estirar el panel por su agarre. Lo mismo que
## avisan las ventanas al arrastrarse, y por lo mismo: desde fuera, estirar no se
## distingue de tener el botón pulsado sobre cualquier otra cosa.
signal dragging_changed(active: bool)

## Franja de arriba que sirve de agarre para estirar. Fuera de ella, pulsar abre
## el mapa grande. Es la barra de título del dibujo —donde están las rayitas—:
## más allá empieza el mapa, y agarrar ahí sería robarle el click.
const GRIP_PX := 8.0
## Hasta dónde puede crecer. Más allá tapa el registro de eventos y deja de ser
## un mapa "de un vistazo".
const MAX_HEIGHT := 220.0
## Cuánto tarda el panel en asentar al soltar. Sólo se usa ahí: al soltar, el
## marco casi siempre encoge un poco —el mapa de dentro no llegó a alcanzar la
## fracción a la que había llegado el arrastre— y de golpe se leía como que el
## arrastre se deshacía. Animado se lee como que asienta.
const SETTLE_TIME := 0.12

@onready var _view: MapView = $MapView

## El borde de abajo no se mueve nunca: el minimapa vive pegado a la esquina, y
## crecer hacia arriba es lo único que tiene sentido ahí.
var _bottom: float = 0.0
var _resizing: bool = false
var _fitting: bool = false
var _wanted_height: float = 0.0
var _settle_tween: Tween = null


func _ready() -> void:
	_bottom = position.y + size.y
	_view.refitted.connect(_fit_to_drawing)
	_fit_to_drawing()


## Recorta el panel a lo que mide el dibujo. Se llama cada vez que el mapa
## recalcula su escala, así que estirar el panel salta de una escala entera a la
## siguiente en vez de dejar franjas negras por el camino.
##
## **Se calla mientras se arrastra.** `MapView` avisa por `refitted` en cuanto
## su propio tamaño cambia, y durante el arrastre eso pasa cada frame — sin
## este freno, el reencaje exacto pisaba el tamaño continuo de `_apply_height`
## en el mismo frame en que se ponía, y el arrastre volvía a saltar por
## escalones. Quien deja el panel exacto al soltar es `_gui_input`, llamando
## aquí a mano.
func _fit_to_drawing() -> void:
	if _resizing:
		return
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


## Como `_fit_to_drawing()`, pero animado — sólo para el instante de soltar el
## arrastre. Ahí el encaje es casi siempre un encogimiento: el marco venía
## siguiendo al ratón en continuo y el mapa de dentro se quedó en la fracción
## de escalón anterior, así que el tamaño real casi nunca coincide con donde
## se soltó. De golpe eso se leía como si el arrastre se deshiciera; en 0,12 s
## se lee como que el panel asienta.
##
## `_fitting` se mantiene en `true` durante todo el tween y no sólo en el
## instante de asignar, con el mismo motivo que en `_resize_to`: cada paso del
## tween cambia `size`, `MapView` refita y avisa por `refitted`, y sin el
## freno `_fit_to_drawing()` pisaría el tween a mitad de camino.
func _settle_to_drawing() -> void:
	var drawing := _view.drawn_size()
	if drawing == Vector2.ZERO or _fitting:
		return
	var target := drawing + _pad()
	if target.is_equal_approx(size):
		return
	if _settle_tween != null and _settle_tween.is_valid():
		_settle_tween.kill()
	_fitting = true
	_settle_tween = create_tween()
	_settle_tween.set_ease(Tween.EASE_OUT)
	_settle_tween.set_trans(Tween.TRANS_CUBIC)
	_settle_tween.set_parallel(true)
	_settle_tween.tween_property(self, "size", target, SETTLE_TIME)
	_settle_tween.tween_property(self, "position:y", _bottom - target.y, SETTLE_TIME)
	_settle_tween.set_parallel(false)
	_settle_tween.tween_callback(func() -> void: _fitting = false)


## El marco sigue al ratón en continuo; lo que se queda pegado a la rejilla es
## el dibujo de dentro, no el panel. **El marco no es pixel art, es una caja**
## — puede medir cualquier fracción sin que se note, porque su nine-patch es
## liso a lo largo del eje que estira (ver `decisions.md`). El mapa sí tiene
## que quedarse en escala entera, pero eso ya lo resuelve `MapView._refit()`
## solo, cada vez que cambia el tamaño que se le da: mientras la fracción no
## alcanza para un escalón más, el dibujo se queda centrado y el margen vacío
## alrededor crece con el arrastre; en cuanto alcanza, salta a llenarlo. Nunca
## se estira ni un píxel del mapa.
func _apply_height(height: float) -> void:
	var unit := _view.size_for_scale(1)
	if unit == Vector2.ZERO or unit.y <= 0.0:
		return
	var pad := _pad()
	var wanted_scale := clampf((height - pad.y) / unit.y, 1.0, _max_scale(unit, pad))
	_resize_to(unit * wanted_scale + pad)


func _max_scale(unit: Vector2, pad: Vector2) -> float:
	return maxf((MAX_HEIGHT - pad.y) / unit.y, 1.0)


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_set_resizing(button.position.y <= GRIP_PX)
			_wanted_height = size.y
			# Pulsar el mapa —no el agarre— abre el grande. Se atiende al
			# pulsar y no al soltar porque aquí no hay más gestos que competir.
			if not _resizing:
				expand_requested.emit()
		else:
			# Al soltar, se limpia la fracción animado (`_settle_to_drawing`),
			# sin el tirón de un salto instantáneo. `_resizing` se apaga ANTES
			# de llamar — `_fit_to_drawing` se calla a sí misma mientras valga
			# `true`, y aquí se usa `_settle_to_drawing` en su lugar.
			var was_resizing := _resizing
			_set_resizing(false)
			if was_resizing:
				_settle_to_drawing()
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


## Cuál está seleccionada. El minimapa no lo averigua por su cuenta —quien lo
## sabe es la selección—, y de este dato cuelgan sus corchetes y la línea hasta
## el destino: sin él los dibuja para nadie.
func set_selected_unit(unit: Unit) -> void:
	_view.set_selected_unit(unit)


func set_order_marker(world_position: Vector2) -> void:
	_view.set_order_marker(world_position)


func clear_order_marker() -> void:
	_view.clear_order_marker()


## Este panel está partido en dos y el cursor no puede adivinarlo: la franja de
## arriba —la de las rayitas— estira el mapa arrastrando, y el resto lo abre a
## pantalla completa al pulsar. Es el mismo reparto que hace [method _gui_input],
## contado con la mano que toca.
func cursor_shape_at(local: Vector2) -> MouseCursor.Shape:
	return MouseCursor.Shape.PRESS if local.y <= GRIP_PX else MouseCursor.Shape.HOVER


## Un solo sitio donde cambia el estado, y avisa **sólo cuando cambia de verdad**:
## pulsar fuera del agarre lo deja en `false` estando ya en `false`, y quien
## escucha no tiene por qué filtrar eso.
func _set_resizing(active: bool) -> void:
	if _resizing == active:
		return
	_resizing = active
	dragging_changed.emit(active)
