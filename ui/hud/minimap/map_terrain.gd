extends RefCounted
class_name MapTerrain

## El terreno reducido a una imagen: un píxel por celda, o por bloque de celdas
## si el mapa es tan grande que no cabe. Es lo que pintan el minimapa y el mapa
## táctico — la misma imagen a distinta escala, no dos dibujos distintos.
##
## Se construye preguntándole al `TileMapLayer`, nunca de una constante. El
## tamaño del mapa cambia por misión, así que apuntarlo en algún sitio sería
## tener dos verdades y que una se quede vieja. Misma fuente de la que
## `PanCamera` saca sus límites.
##
## **El tipo de cada celda sale del dato, no del color.** El TileSet lleva una
## capa de datos `tipo` que se marca una vez por tile en el editor; el dibujo no
## se mira. Dos tiles que se parezcan pueden ser cosas distintas, y sólo el dato
## lo sabe.

## Capa de datos personalizada del TileSet de la que se lee el terreno.
const DATA_LAYER := "tipo"

## De qué color se pinta cada tipo. **Si añades un tipo al tileset, añádelo
## aquí**; mientras no esté se pinta con [constant UNKNOWN_COLOR], que canta a
## la vista — es mejor que desaparecer en silencio.
const COLORS := {
	"agua": Color("4d9be6"),
	"tierra": Color("91db69"),
	"arena": Color("fbff86"),
}

## Tipo que existe en el mapa pero no en [constant COLORS]. Rojo a propósito.
const UNKNOWN_COLOR := Color("ff0044")

## Un píxel por celda, con el color del terreno. Sin filtrar: se dibuja a escala
## entera y con Nearest, como todo lo demás del juego.
var texture: ImageTexture
## Tamaño del mapa en celdas.
var cells: Vector2i
## Primera celda usada. **No tiene por qué ser (0,0)** — hoy el mapa arranca en
## la fila −6. Todo lo que cuente coordenadas cuenta desde aquí.
var origin_cell: Vector2i
## Tamaño de una celda en píxeles de mundo (32×32 hoy).
var tile_px: Vector2i
## Cuántas celdas resume cada píxel de la imagen. 1 salvo mapas enormes.
var cells_per_px: int = 1
## El mapa en coordenadas de mundo.
var world_rect: Rect2


## Construye la imagen. `cells_per_pixel` mayor que 1 resume bloques de celdas
## en un píxel, que es la única forma de que un mapa más grande que el panel
## siga cayendo en píxeles enteros: encoger la imagen ya hecha daría una escala
## fraccionaria, y con Nearest eso hierve en cuanto algo se mueve.
static func build(layer: TileMapLayer, cells_per_pixel: int = 1) -> MapTerrain:
	if layer == null or layer.tile_set == null:
		return null
	var used: Rect2i = layer.get_used_rect()
	if used.size == Vector2i.ZERO:
		return null

	var map := MapTerrain.new()
	map.cells = used.size
	map.origin_cell = used.position
	map.tile_px = layer.tile_set.tile_size
	map.cells_per_px = maxi(1, cells_per_pixel)
	map.world_rect = Rect2(
		layer.to_global(Vector2(used.position * map.tile_px)),
		Vector2(used.size * map.tile_px))

	var size := Vector2i(
		ceili(float(map.cells.x) / map.cells_per_px),
		ceili(float(map.cells.y) / map.cells_per_px))
	var img := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in range(size.y):
		for x in range(size.x):
			img.set_pixel(x, y, _block_color(layer, used, map.cells_per_px, x, y))
	map.texture = ImageTexture.create_from_image(img)
	return map


## Color de un píxel de la imagen: el tipo más repetido entre las celdas que
## resume. Por mayoría y no por promedio — promediar colores inventa uno que no
## está en la paleta.
static func _block_color(layer: TileMapLayer, used: Rect2i, step: int,
		x: int, y: int) -> Color:
	var tally := {}
	for dy in range(step):
		for dx in range(step):
			var cell := used.position + Vector2i(x * step + dx, y * step + dy)
			if not used.has_point(cell):
				continue
			var data: TileData = layer.get_cell_tile_data(cell)
			if data == null:
				continue
			var kind := str(data.get_custom_data(DATA_LAYER))
			tally[kind] = tally.get(kind, 0) + 1

	var best := ""
	var best_count := 0
	for kind: String in tally:
		if tally[kind] > best_count:
			best_count = tally[kind]
			best = kind
	if best_count == 0:
		# Hueco sin pintar en el mapa: transparente, no negro.
		return Color(0.0, 0.0, 0.0, 0.0)
	return COLORS.get(best, UNKNOWN_COLOR)


## Cuántas zonas de coordenadas entran, a lo ancho y a lo alto.
func zone_count(zone_cells: int) -> Vector2i:
	var n := maxi(1, zone_cells)
	return Vector2i(ceili(float(cells.x) / n), ceili(float(cells.y) / n))


## En qué zona cae un punto del mundo.
func zone_at(world: Vector2, zone_cells: int) -> Vector2i:
	var n := maxi(1, zone_cells)
	var local := world - world_rect.position
	var count := zone_count(n)
	return Vector2i(
		clampi(int(floor(local.x / (tile_px.x * n))), 0, count.x - 1),
		clampi(int(floor(local.y / (tile_px.y * n))), 0, count.y - 1))


## El centro de una zona, en mundo. Es lo que hace falta para que pulsar "F7"
## en el registro de eventos lleve la cámara a algún sitio.
func zone_center(zone: Vector2i, zone_cells: int) -> Vector2:
	var n := maxi(1, zone_cells)
	return world_rect.position + Vector2(
		(zone.x + 0.5) * tile_px.x * n,
		(zone.y + 0.5) * tile_px.y * n)


## La coordenada de un punto del mundo, ya escrita: "F7".
func label_at(world: Vector2, zone_cells: int) -> String:
	var zone := zone_at(world, zone_cells)
	return "%s%d" % [column_label(zone.x), zone.y + 1]


## Letra de una columna. Pasada la Z sigue con AA, AB… porque el tamaño del
## mapa lo pones tú y 26 columnas se acaban enseguida.
static func column_label(index: int) -> String:
	var out := ""
	var n := index
	while n >= 0:
		out = String.chr(65 + n % 26) + out
		n = n / 26 - 1
	return out
