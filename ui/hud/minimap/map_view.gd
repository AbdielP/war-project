extends Control
class_name MapView

## Dibuja el mapa: terreno, rejilla, coordenadas y el recuadro de lo que se está
## viendo en pantalla. **Se usa dos veces** —el minimapa de la esquina y el mapa
## táctico a pantalla completa— con la misma imagen a distinta escala. Lo único
## que cambia entre uno y otro es qué se enciende de aquí abajo.
##
## La escala no se configura: se calcula. El mapa mide lo que mida la misión y
## el panel mide lo que mida, así que se coge **el mayor número entero de
## píxeles por celda que quepa**, y si ni uno cabe se resume el mapa en la
## propia imagen. Nunca hay una escala fraccionaria, que con filtro Nearest es
## lo que hace hervir los píxeles al mover la cámara.

## Emitida al pulsar sobre el mapa, con el punto del mundo que se pulsó y la
## unidad cuyo punto estaba debajo, o `null` si era terreno. El mapa resuelve
## qué hay debajo porque nadie más puede: a esta escala un píxel son decenas de
## píxeles de mundo y una consulta de física no acertaría a nadie nunca.
signal map_clicked(world_position: Vector2, unit: Unit)
## Lo mismo con el botón derecho.
signal map_context_requested(world_position: Vector2, unit: Unit)

## Rejilla de zonas de coordenadas. **No dibuja las celdas de terreno**: eran
## casi 2900 cuadritos de 7 px, y el tamaño del tile no le dice nada a nadie.
@export var show_grid: bool = false
## Letras arriba y abajo, números a los lados.
@export var show_labels: bool = false
## Cuántas celdas mide el lado de una zona de coordenadas. Con celdas de 32 px,
## 8 son zonas de 256 px de mundo. **Es el número a mover si las coordenadas
## salen demasiado gruesas o demasiado finas.** Es una petición, no una orden:
## ver [method _zone_side].
@export var zone_cells: int = 8
## El recuadro de lo que se ve en pantalla ahora mismo. Sin él, el mapa a
## pantalla completa es un cuadro bonito en el que no sabes dónde estabas.
@export var show_viewport_rect: bool = true
## Un punto por unidad, del color de su bando ([Team]).
@export var show_units: bool = true
## Lado del punto de una unidad, en píxeles de pantalla. **No escala con el
## mapa**: es un icono, no terreno — a 1 px por celda un punto a escala sería
## invisible, y en el mapa grande sería una mancha.
@export var marker_px: int = 2

const _COLOR_TEXT := Color(0.6705882, 0.5803922, 0.4784314)
const _COLOR_ACCENT := Color(0.56078434, 0.827451, 1.0)
## Filo oscuro alrededor de cada punto. No es adorno: el azul del jugador y el
## azul del agua se parecen demasiado, y un punto de 2 px sin borde desaparece.
const _COLOR_MARKER_EDGE := Color(0.19215686, 0.21176471, 0.21960784)
const _FONT_SIZE := 8
## Sitio que se reserva fuera del mapa para las coordenadas.
const _LABEL_MARGIN := 10
## Lo mínimo que puede medir una zona en pantalla. Por debajo, las zonas se
## agrupan: una coordenada más pequeña que esto no se lee y sus líneas se leen
## como rayado, no como cuadrícula.
const _MIN_ZONE_PX := 24.0
## Cuánto se agranda el punto de una unidad para poder pulsarlo. El punto se
## dibuja del tamaño en que se lee bien, no del tamaño en que se acierta: 4 px
## con el ratón ya cuesta, y con el dedo es imposible.
const _PICK_GROW := 3.0

var _terrain: MapTerrain = null
var _scale: int = 1
var _origin: Vector2 = Vector2.ZERO
var _last_transform := Transform2D()
## Dónde se mandó ir a la unidad. Es el mismo marcador que se planta en el
## mundo, dibujado aquí: con el mapa abierto, el del mundo no se ve.
var _order: Vector2 = Vector2.ZERO
var _has_order: bool = false
## A quién se le pinta el recuadro de seleccionada. Mientras haya una, **el
## recuadro de cámara se calla**: con la cámara siguiéndola, sería un cuadro
## enorme persiguiendo al mismo punto que ya está resaltado.
var _selected: Unit = null
## Mantener pulsado equivale al click derecho, igual que en el mundo. Sin esto,
## en móvil no habría forma de abrir el menú de una unidad desde el mapa.
var _press := LongPress.new()


func _ready() -> void:
	resized.connect(_refit)
	_refit()


## Rehace la imagen del terreno. Público porque el mapa cambia por misión: quien
## cargue un mapa nuevo llama aquí y no hay que reconstruir la escena.
func refresh() -> void:
	_terrain = null
	_refit()


func terrain() -> MapTerrain:
	return _terrain


func set_order_marker(world_position: Vector2) -> void:
	_order = world_position
	_has_order = true
	queue_redraw()


func clear_order_marker() -> void:
	_has_order = false
	queue_redraw()


func set_selected_unit(unit: Unit) -> void:
	_selected = unit
	queue_redraw()


## Píxeles de pantalla por celda de terreno, ya contando el resumen. Sale
## fraccionario sólo cuando la imagen resume varias celdas por píxel.
func cell_px() -> float:
	if _terrain == null:
		return float(_scale)
	return float(_scale) / _terrain.cells_per_px


## Celdas por lado de zona **de verdad**. `zone_cells` es lo que se pide; si el
## mapa crece o la vista encoge, las zonas se agrupan de dos en dos hasta que la
## coordenada se puede leer. Sin esto, un mapa del doble de grande volvería a
## llenar la pantalla de rayas y habría que ir retocando el exportado a mano por
## cada misión.
func _zone_side() -> int:
	var side := maxi(zone_cells, 1)
	var px := cell_px()
	if px <= 0.0:
		return side
	while px * side < _MIN_ZONE_PX:
		side *= 2
	return side


## La coordenada de un punto del mundo ("F7"), con el tamaño de zona que se está
## dibujando de verdad. Lo pedirá el registro de eventos: si preguntase con
## `zone_cells` a secas, el texto y el dibujo podrían no coincidir.
func zone_label_at(world: Vector2) -> String:
	return _terrain.label_at(world, _zone_side()) if _terrain != null else ""


func world_to_local(world: Vector2) -> Vector2:
	if _terrain == null:
		return Vector2.ZERO
	return _origin + (world - _terrain.world_rect.position) * _world_scale()


func local_to_world(local: Vector2) -> Vector2:
	if _terrain == null:
		return Vector2.ZERO
	return _terrain.world_rect.position + (local - _origin) / _world_scale()


## Píxeles de pantalla por píxel de mundo.
func _world_scale() -> float:
	return cell_px() / float(_terrain.tile_px.x)


func _drawn_size() -> Vector2:
	return Vector2(_terrain.texture.get_size()) * _scale


## Decide escala y resumen a partir del sitio que hay. Se llama al arrancar y
## cada vez que el panel cambia de tamaño.
func _refit() -> void:
	# Dentro de un contenedor, el tamaño real no llega hasta que se resuelve la
	# distribución, un frame después de `_ready()`. Sin esto se construiría una
	# imagen de 1×1 para tirarla acto seguido.
	if size.x < 4.0 or size.y < 4.0:
		return
	var layer := _find_layer()
	if layer == null:
		return
	var used: Rect2i = layer.get_used_rect()
	if used.size == Vector2i.ZERO:
		return

	var margin := _LABEL_MARGIN * 2 if show_labels else 0
	var space := Vector2i(maxi(int(size.x) - margin, 1), maxi(int(size.y) - margin, 1))
	var fit: int = mini(space.x / used.size.x, space.y / used.size.y)

	var reduction := 1
	if fit >= 1:
		_scale = fit
	else:
		# El mapa no cabe ni a un píxel por celda: se resume en la imagen, que
		# es lo que deja seguir dibujando a escala 1 y sin decimales.
		_scale = 1
		reduction = maxi(
			ceili(float(used.size.x) / space.x),
			ceili(float(used.size.y) / space.y))

	if _terrain == null or _terrain.cells_per_px != reduction \
			or _terrain.cells != used.size or _terrain.origin_cell != used.position:
		_terrain = MapTerrain.build(layer, reduction)
	if _terrain == null:
		return
	_origin = ((size - _drawn_size()) * 0.5).floor()
	queue_redraw()


## Misma búsqueda que hace `PanCamera` para sus límites: el mapa no se le pasa a
## nadie por el inspector, se encuentra.
func _find_layer() -> TileMapLayer:
	var found := get_tree().root.find_children("*", "TileMapLayer", true, false)
	return found[0] as TileMapLayer if not found.is_empty() else null


## El recuadro de la cámara y las unidades se mueven sin que nadie avise, así
## que hay que mirarlo. Con unidades no queda otra que redibujar siempre — son
## un puñado de rectángulos y el mapa oculto ni se dibuja. Sin ellas basta con
## comparar la transformación, y parado no cuesta nada.
func _process(delta: float) -> void:
	if _press.tick(delta):
		_emit_at(_press.origin(), true)
	var current := get_viewport().get_canvas_transform()
	if show_units or current != _last_transform:
		_last_transform = current
		queue_redraw()


func _draw() -> void:
	if _terrain == null:
		return
	var drawn := _drawn_size()
	draw_texture_rect(_terrain.texture, Rect2(_origin, drawn), false)
	if show_grid:
		_draw_grid(drawn)
	if show_labels:
		_draw_labels(drawn)
	if show_viewport_rect and not is_instance_valid(_selected):
		_draw_viewport_rect()
	if _has_order:
		_draw_order_marker(drawn)
	if show_units:
		_draw_units(drawn)


## El destino de la orden en curso: la misma cruz dentro de un círculo que se
## planta en el mundo, al mismo tamaño en los dos mapas. Es un icono, no
## terreno — si escalara, en el minimapa no se vería.
func _draw_order_marker(drawn: Vector2) -> void:
	var center := world_to_local(_order)
	if not Rect2(_origin, drawn).has_point(center):
		return
	draw_arc(center, 4.0, 0.0, TAU, 16, _COLOR_ACCENT, 1.0)
	draw_line(center + Vector2(-2, 0), center + Vector2(3, 0), _COLOR_ACCENT, 1.0)
	draw_line(center + Vector2(0, -2), center + Vector2(0, 3), _COLOR_ACCENT, 1.0)


## Una sola rejilla: la de las zonas que llevan coordenada. La de celdas de
## terreno se quitó — 64×45 cuadritos de 7 px no son una cuadrícula, son un
## rayado, y el tamaño del tile no es información de juego.
func _draw_grid(drawn: Vector2) -> void:
	_draw_lines(drawn, cell_px() * _zone_side(), Color(_COLOR_ACCENT, 0.3))


func _draw_lines(drawn: Vector2, step: float, color: Color) -> void:
	if step < 1.0:
		return
	var x := step
	while x < drawn.x:
		draw_line(_origin + Vector2(x, 0.0), _origin + Vector2(x, drawn.y), color, 1.0)
		x += step
	var y := step
	while y < drawn.y:
		draw_line(_origin + Vector2(0.0, y), _origin + Vector2(drawn.x, y), color, 1.0)
		y += step
	draw_rect(Rect2(_origin, drawn), color, false, 1.0)


## Las coordenadas van FUERA del mapa, no encima: dentro no caben y taparían el
## terreno. Letras arriba y abajo, números a los lados, repetidas en los dos
## bordes para no tener que seguir la fila con el dedo hasta el otro extremo.
func _draw_labels(drawn: Vector2) -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	var side := _zone_side()
	var zones := _terrain.zone_count(side)
	var step := cell_px() * side

	for i in range(zones.x):
		var text := MapTerrain.column_label(i)
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _FONT_SIZE).x
		var x := _origin.x + step * (i + 0.5) - width * 0.5
		draw_string(font, Vector2(x, _origin.y - 2.0), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, _FONT_SIZE, _COLOR_TEXT)
		draw_string(font, Vector2(x, _origin.y + drawn.y + _FONT_SIZE + 1.0), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, _FONT_SIZE, _COLOR_TEXT)

	for j in range(zones.y):
		var text := str(j + 1)
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _FONT_SIZE).x
		var y := _origin.y + step * (j + 0.5) + _FONT_SIZE * 0.5
		draw_string(font, Vector2(_origin.x - width - 2.0, y), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, _FONT_SIZE, _COLOR_TEXT)
		draw_string(font, Vector2(_origin.x + drawn.x + 2.0, y), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, _FONT_SIZE, _COLOR_TEXT)


## Qué trozo del mundo se está viendo. Se saca de la transformación del lienzo y
## no de la cámara a propósito: es una propiedad de lo que hay en pantalla, no
## de un nodo concreto, y así el mapa no necesita conocer a nadie para dibujarlo.
func _draw_viewport_rect() -> void:
	var inverse := get_viewport().get_canvas_transform().affine_inverse()
	var screen := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var world := inverse * screen
	var rect := Rect2(world_to_local(world.position), world.size * _world_scale())
	draw_rect(rect, _COLOR_ACCENT, false, 1.0)


## Un punto por unidad, del color de su bando. Se pintan al final para que
## queden por encima de la rejilla y del recuadro de cámara: son lo que se viene
## a mirar.
##
## Se sacan del grupo de unidades y no de una lista propia. El mapa no se entera
## de quién nace y quién muere, ni hay nada que mantener sincronizado: pregunta
## cada vez que dibuja, que es cuando importa.
func _draw_units(drawn: Vector2) -> void:
	var inside := Rect2(_origin, drawn)
	var half := marker_px * 0.5
	for node in get_tree().get_nodes_in_group(Unit.GROUP):
		var unit := node as Unit
		if unit == null:
			continue
		var center := world_to_local(unit.global_position)
		# Una unidad fuera del mapa no se pinta en el borde: se pintaría encima
		# de las coordenadas y mentiría sobre dónde está.
		if not inside.has_point(center):
			continue
		var rect := Rect2((center - Vector2(half, half)).round(),
				Vector2(marker_px, marker_px))
		draw_rect(rect.grow(1.0), _COLOR_MARKER_EDGE, true)
		draw_rect(rect, Team.color(unit.team), true)
		# La seleccionada lleva su propio recuadro, separado del punto para que
		# no se coma el color del bando. Esto sustituye al recuadro de cámara.
		if unit == _selected:
			draw_rect(rect.grow(3.0), _COLOR_ACCENT, false, 1.0)


## Qué unidad hay bajo un punto del panel, o `null` si sólo hay terreno. Se
## busca contra los puntos dibujados y no contra el mundo: lo que el jugador
## apunta es el punto que ve, no la unidad de tamaño real que hay detrás. Gana
## la más cercana, que es la que cree estar pulsando.
func unit_at(local_position: Vector2) -> Unit:
	if _terrain == null or not show_units:
		return null
	var inside := Rect2(_origin, _drawn_size())
	var reach := marker_px * 0.5 + _PICK_GROW
	var best: Unit = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(Unit.GROUP):
		var unit := node as Unit
		if unit == null:
			continue
		var center := world_to_local(unit.global_position)
		if not inside.has_point(center):
			continue
		var distance := center.distance_to(local_position)
		if distance > reach or distance >= best_distance:
			continue
		best_distance = distance
		best = unit
	# Igual que en el mundo: pulsar a un miembro del escuadrón es pulsar al líder.
	return best.squad.leader if best != null and best.squad != null else best


## El click izquierdo se cuenta **al soltar**, no al pulsar: hasta que el dedo no
## se levanta no se sabe si era un click o el principio de una pulsación
## mantenida. El derecho no espera a nada, que en PC no hay ambigüedad.
func _gui_input(event: InputEvent) -> void:
	if _terrain == null:
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		_press.moved(motion.position)
		return
	var button := event as InputEventMouseButton
	if button == null:
		return
	if button.button_index == MOUSE_BUTTON_RIGHT:
		if button.pressed:
			_emit_at(button.position, true)
		return
	if button.button_index != MOUSE_BUTTON_LEFT:
		return
	if button.pressed:
		_press.press(button.position)
	elif _press.release():
		_emit_at(button.position, false)
	accept_event()


func _emit_at(local_position: Vector2, context: bool) -> void:
	var world := local_to_world(local_position)
	if not _terrain.world_rect.has_point(world):
		return
	var unit := unit_at(local_position)
	if context:
		map_context_requested.emit(world, unit)
	else:
		map_clicked.emit(world, unit)
