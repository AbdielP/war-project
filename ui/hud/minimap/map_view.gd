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

## Emitida al pulsar sobre el mapa, con el punto del mundo que se pulsó.
signal map_clicked(world_position: Vector2)

## Rejilla fina, una línea por celda de terreno. Se calla sola cuando la celda
## queda tan pequeña que la rejilla sería ruido en vez de referencia.
@export var show_grid: bool = false
## Letras arriba y abajo, números a los lados.
@export var show_labels: bool = false
## Cuántas celdas mide el lado de una zona de coordenadas. Con celdas de 32 px,
## 4 son zonas de 128 px de mundo. **Es el número a mover si las coordenadas
## salen demasiado gruesas o demasiado finas.**
@export var zone_cells: int = 4
## El recuadro de lo que se ve en pantalla ahora mismo. Sin él, el mapa a
## pantalla completa es un cuadro bonito en el que no sabes dónde estabas.
@export var show_viewport_rect: bool = true

const _COLOR_TEXT := Color(0.6705882, 0.5803922, 0.4784314)
const _COLOR_ACCENT := Color(0.56078434, 0.827451, 1.0)
const _FONT_SIZE := 8
## Sitio que se reserva fuera del mapa para las coordenadas.
const _LABEL_MARGIN := 10
## Por debajo de esto la rejilla fina se apaga: líneas más juntas que esto no
## se leen como cuadrícula, se leen como suciedad.
const _MIN_GRID_PX := 4.0

var _terrain: MapTerrain = null
var _scale: int = 1
var _origin: Vector2 = Vector2.ZERO
var _last_transform := Transform2D()


func _ready() -> void:
	resized.connect(_refit)
	_refit()
	set_process(show_viewport_rect)


## Rehace la imagen del terreno. Público porque el mapa cambia por misión: quien
## cargue un mapa nuevo llama aquí y no hay que reconstruir la escena.
func refresh() -> void:
	_terrain = null
	_refit()


func terrain() -> MapTerrain:
	return _terrain


## Píxeles de pantalla por celda de terreno, ya contando el resumen. Sale
## fraccionario sólo cuando la imagen resume varias celdas por píxel.
func cell_px() -> float:
	if _terrain == null:
		return float(_scale)
	return float(_scale) / _terrain.cells_per_px


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


## El recuadro de la cámara se mueve sin que nadie avise, así que hay que
## mirarlo. Se compara la transformación en vez de redibujar siempre: parado no
## cuesta nada.
func _process(_delta: float) -> void:
	var current := get_viewport().get_canvas_transform()
	if current != _last_transform:
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
	if show_viewport_rect:
		_draw_viewport_rect()


## Dos rejillas encima de la misma imagen: la fina son las celdas del terreno
## —la cuadrícula de 32 px de verdad— y la gruesa son las zonas que llevan
## coordenada. La fina desaparece cuando no se puede leer.
func _draw_grid(drawn: Vector2) -> void:
	var step := cell_px()
	if step >= _MIN_GRID_PX and _terrain.cells_per_px == 1:
		_draw_lines(drawn, step, Color(0.0, 0.0, 0.0, 0.25))
	_draw_lines(drawn, step * zone_cells, Color(_COLOR_ACCENT, 0.35))


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
	var zones := _terrain.zone_count(zone_cells)
	var step := cell_px() * zone_cells

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


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if _terrain == null:
		return
	var world := local_to_world(button.position)
	if not _terrain.world_rect.has_point(world):
		return
	map_clicked.emit(world)
	accept_event()
