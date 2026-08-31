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
## Se recalculó la escala. Lo escucha quien quiera ajustar su hueco al dibujo:
## como la escala es entera, el dibujo casi nunca llena un panel de tamaño
## arbitrario, y lo que sobra se ve como borde muerto.
signal refitted

## Rejilla de zonas de coordenadas. **No dibuja las celdas de terreno**: eran
## casi 2900 cuadritos de 7 px, y el tamaño del tile no le dice nada a nadie.
@export var show_grid: bool = false
## La coordenada de cada zona, escrita **entera y de una pieza** en su esquina
## superior izquierda: `C4`.
##
## Partida —la letra por un lado y el número por otro— no se lee: hay que
## juntar dos signos que están en sitios distintos para sacar un nombre que
## nadie ha escrito. Y es además la forma en la que el resto del HUD ya la dice
## —"MOVIÉNDOSE A: F6"—, así que lo que se ve en el mapa y lo que se lee en la
## ficha son ahora el mismo texto. Ver [method MapTerrain.label_at].
@export var show_labels: bool = false
## Con qué se escriben las coordenadas. Sin ponerla sale la del tema, que en
## este proyecto es la de Godot: enorme y suavizada. Ver [member contact_font].
@export var label_font: Font = null
## Color de las coordenadas. Van encima del terreno y compiten con él, así que
## se dejan a mano: sobre selva y sobre mar no hace falta el mismo tono.
@export var label_color := Color(1.0, 1.0, 1.0, 1.0)
## El borde de la coordenada, un píxel alrededor de la letra. Alfa 0 lo apaga.
##
## No hay un tono que valga para todo el mapa: el que se lee sobre el mar se
## pierde sobre la selva. El borde despega la letra de lo que tenga debajo sea
## lo que sea.
##
## **Va a media tinta a propósito:** la coordenada es una referencia que se
## busca cuando hace falta, no un aviso, y con el borde a plena tinta se comía
## el mapa. El que se apaga es el borde y no la letra: el borde queda **debajo**
## de ella, así que una letra translúcida se mezcla con su propio borde y sale
## gris. Si hace falta apagarla también, se hace por color —un blanco sucio— y
## no por alfa.
##
## Ojo al bajar este número: el borde son ocho copias corridas y donde se
## solapan la transparencia se acumula, así que el anillo sale moteado. A 0.55
## el moteado no se ve a tamaño real; más abajo empieza a notarse.
@export var label_outline := Color(0.0, 0.0, 0.0, 0.55)
## Cuántas celdas mide el lado de una zona de coordenadas. Con celdas de 32 px,
## 8 son zonas de 256 px de mundo. **Es el número a mover si las coordenadas
## salen demasiado gruesas o demasiado finas.** Es una petición, no una orden:
## ver [method _zone_side].
@export var zone_cells: int = 8
## La celda de rejilla dibujada, repetida una vez por zona de coordenadas. Debe
## medir el lado de una zona **a escala 1x** y llevar la línea sólo en dos de sus
## bordes, o al repetirla se duplican. Sin textura se dibuja a mano — ver
## [method _draw_grid].
@export var grid_texture: Texture2D = null
## Color de la rejilla dibujada a mano, sacado del dibujo del panel. Va
## translúcida: la rejilla es una guía, no debe competir con el terreno ni con
## los puntos de las unidades.
@export var grid_color := Color(0.1764706, 0.22745098, 0.2901961, 0.5)
## Largo del trazo y del hueco, en píxeles de pantalla. **No escalan con el
## mapa**: la rejilla es una guía dibujada encima, no terreno, así que el
## punteado tiene que verse igual de fino con el minimapa a 1x que estirado.
@export_range(1, 16, 1) var grid_dash: int = 4
@export_range(0, 16, 1) var grid_gap: int = 3
## El recuadro alrededor del mapa. Sobra cuando el panel ya trae marco dibujado.
@export var grid_border: bool = true
## Llenar el panel entero en vez de que quepa el mapa completo.
##
## La escala es entera y el mapa casi nunca tiene la proporción de la pantalla,
## así que **una de las dos cosas hay que perder**: o sobra fondo muerto
## alrededor, o se sale por dos lados y se recorta. A pantalla completa manda lo
## segundo; en un panel pequeño, donde lo que importa es ver el mapa entero,
## manda lo primero. Requiere `clip_contents` en el nodo.
@export var fill_panel: bool = false
## El recuadro de lo que se ve en pantalla ahora mismo. Sin él, el mapa a
## pantalla completa es un cuadro bonito en el que no sabes dónde estabas.
@export var show_viewport_rect: bool = true
## Un punto por unidad, del color de su bando ([Team]).
@export var show_units: bool = true
## Cada cuánto se refresca la posición de los contactos, en segundos. A cero,
## en directo.
##
## Un mapa no es una cámara: lo que enseña es **la última vez que se miró**, no
## lo que está pasando ahora. Congelando la foto entre barridos los contactos
## saltan en vez de deslizarse, y el salto es el dato: dice cuánto se movió cada
## uno desde la vuelta anterior.
##
## Congela **todo lo que se sabe por mirar** —posición y rumbo— y también qué
## se puede pulsar: si el símbolo está donde estaba, el click tiene que acertarle
## ahí y no en el sitio de verdad, que no se ve. Ver [method unit_at].
@export_range(0.0, 4.0, 0.1, "suffix:s") var sweep_interval: float = 0.0
## Lado del punto de una unidad, en píxeles de pantalla. **No escala con el
## mapa**: es un icono, no terreno — a 1 px por celda un punto a escala sería
## invisible, y en el mapa grande sería una mancha.
##
## Sólo se usa cuando no hay símbolo puesto: es el cuadradito de siempre, que
## queda de reserva para que un mapa sin arte asignado siga diciendo dónde hay
## alguien en vez de salir vacío.
@export var marker_px: int = 2

@export_group("Símbolos de contacto")
## El marco de cada bando. **Van los cuatro por separado y no uno teñido**:
## `modulate` multiplica, y el filo oscuro que despega el símbolo del terreno se
## perdería. Vacíos = se dibuja el cuadradito de `marker_px`.
##
## Los cuatro caben en la misma caja —11×11 en el mapa grande, 7×7 en el
## minimapa— aunque cada uno tenga su forma: el rombo la llena entera, el
## rectángulo mide 11×7 y el cuadrado 9×9. Eso es lo que hace que la marca de
## dominio caiga siempre en el mismo sitio sea cual sea el bando.
@export var contact_player: Texture2D
@export var contact_ally: Texture2D
@export var contact_enemy: Texture2D
@export var contact_neutral: Texture2D

@export_subgroup("Dominio")
## La barra que dice en qué medio se mueve el contacto. **Es la misma pieza
## arriba y abajo**: encima del marco significa que vuela y debajo que navega.
## No lleva color de bando — eso ya lo dice el marco.
@export var domain_bar: Texture2D
## Y la T invertida, sólo debajo: bajo el agua. Puesta y sin usar todavía —
## `UnitType.Domain` distingue aire de superficie y nada más, así que aún no hay
## quien conteste "esto es un submarino".
@export var domain_subsurface: Texture2D
## Cuánto aire queda entre la marca y el marco, en píxeles.
##
## **Separadas, no pegadas.** Solapándolas la barra se comía la punta del rombo y
## el símbolo dejaba de leerse como un rombo; y a cero, el filo oscuro de las dos
## piezas se toca y parecen una sola forma rara. Con un par de píxeles de hueco
## se leen como lo que son: un contacto y encima el dato de en qué medio va.
@export_range(0, 6, 1) var domain_gap: int = 2

@export_subgroup("Rumbo")
## La flecha que dice hacia dónde mira el contacto. **Ésta sí gira**, al revés
## que el resto de lo que acompaña al símbolo: una marca girada deja de leerse
## como marca, pero esto *es* el rumbo y girarlo es lo único que puede
## significar. El dibujo apunta al norte; se rota desde ahí.
##
## Cuatro dibujos y no uno teñido, por lo mismo que los marcos.
@export var heading_player: Texture2D
@export var heading_ally: Texture2D
@export var heading_enemy: Texture2D
@export var heading_neutral: Texture2D
## Cuánto se aparta la cola de la flecha del centro del contacto.
##
## Del **centro** y no del borde del símbolo: así la flecha sale igual de larga
## mire a donde mire, y el trozo de cola que cae dentro del símbolo queda
## tapado por él —que se dibuja después—, igual que en el boceto. Midiendo
## contra el borde, la flecha se alejaba y se acercaba según el rumbo y parecía
## que cambiaba de tamaño.
@export_range(0, 6, 1) var heading_gap: int = 0

@export_subgroup("Selección")
## Las cuatro esquinas alrededor del contacto seleccionado. Van en la caja común
## de los símbolos —16×15— y no ajustadas a cada forma: si cada bando midiera lo
## suyo, el corchete bailaría al cambiar de contacto.
##
## Los cuatro colores existen porque **se puede seleccionar a cualquiera**: en el
## mapa se pulsa un enemigo para mirarlo, y el corchete tiene que decir de quién
## es lo que se está mirando.
@export var bracket_player: Texture2D
@export var bracket_ally: Texture2D
@export var bracket_enemy: Texture2D
@export var bracket_neutral: Texture2D

@export_subgroup("Destino")
## La punta con el aspa que remata la línea de destino. **Cuelga encima del
## punto, no encima de sí mismo**: plantada justo en el destino taparía el
## terreno que se está señalando.
@export var destination_mark: Texture2D
## Cuánto aire queda entre el aspa y la punta de la línea.
@export_range(0, 6, 1) var destination_gap: int = 1

@export_group("Etiquetas de contacto")
## La clase de cada contacto al lado de su símbolo: `[PLANE]`, `[SHIP]`,
## `[TANK]`.
##
## **La clase y no el modelo.** Con doce contactos en pantalla lo que hace falta
## de un vistazo es qué clase de cosa hay dónde; el nombre del que estás mirando
## sale aparte, ver [member show_selected_name]. Los corchetes no son adorno: el
## texto va encima del terreno y la forma es la segunda vía de lectura cuando el
## color falla.
@export var show_contact_names: bool = false
## La de las etiquetas cortas: monoespaciada, trazo de 2 px y legible sobre
## cualquier terreno. Vacía = la del tema.
@export var contact_font: Font
@export var contact_font_size: int = 8
## Aire entre el símbolo y la primera letra.
@export_range(0, 8, 1) var contact_name_gap: int = 3
## El nombre completo del contacto seleccionado, debajo de su símbolo. Sale sólo
## de ése: escrito en todos, doce nombres largos taparían el mapa.
@export var show_selected_name: bool = true
## La misma que las etiquetas: "AV-8B HARRIER II" gasta 57 px con ella. Vacía =
## la del tema.
@export var selected_name_font: Font
@export var selected_name_font_size: int = 8
## Aire entre lo que dibuja el contacto y el nombre de abajo.
@export_range(0, 8, 1) var selected_name_gap: int = 3
## Ondas donde nos han enganchado o nos están disparando. Ver [ThreatPulses].
@export var show_alerts: bool = true
## Hasta dónde se abre cada onda, en píxeles de pantalla. **No escala con el
## mapa**, igual que los puntos: en el minimapa un anillo a escala real sería de
## dos píxeles y no se vería. Aquí sí conviene subirlo en el mapa grande, donde
## hay sitio de sobra.
@export var alert_radius_px: float = 12.0
## Cuántas ondas salen por contacto, repartidas en lo que dura. Varias y no una
## porque **una sola se pierde si el jugador estaba mirando a otro lado**.
@export_range(1, 6, 1) var alert_rings: int = 3

const _COLOR_TEXT := Color(0.6705882, 0.5803922, 0.4784314)
## Nos siguen con el radar, pero todavía no disparan.
const _COLOR_TRACKED := Color(0.98, 0.76, 0.29)
## Nos están disparando.
const _COLOR_FIRED_UPON := Color(0.9, 0.29, 0.31)
## Hay un misil en el aire viniendo a por nosotros. Casi blanco: es el aviso más
## urgente de los tres y tiene que ganarle a los otros dos de un vistazo.
const _COLOR_MISSILE := Color(1.0, 0.94, 0.9)
const _COLOR_ACCENT := Color(0.56078434, 0.827451, 1.0)
## Filo oscuro alrededor de cada punto. No es adorno: el azul del jugador y el
## azul del agua se parecen demasiado, y un punto de 2 px sin borde desaparece.
const _COLOR_MARKER_EDGE := Color(0.19215686, 0.21176471, 0.21960784)
## La línea que va del contacto a su destino. Es el azul apagado del propio
## dibujo de la marca, no el acento del HUD: la línea cruza medio mapa y con el
## azul vivo competiría con los símbolos, que es lo que hay que mirar.
const _COLOR_DESTINATION := Color(0.24705882, 0.38039216, 0.5411765)
## El nombre corto va en blanco y no del color del bando. El bando ya lo dicen la
## forma y el color del símbolo; lo que necesita el texto es leerse sobre el mar,
## sobre la selva y sobre la arena, y para eso el blanco con filo oscuro es lo
## único que no falla en ningún terreno.
const _COLOR_CONTACT_NAME := Color(1.0, 1.0, 1.0)
const _FONT_SIZE := 8
## Lo que mide de alto una mayúscula o un dígito de la fuente del mapa a
## [constant _FONT_SIZE]. Medido rasterizando, no leído de la ficha: el alto de
## línea es mayor que el de la letra y un plato dibujado contra él saldría
## desplazado hacia arriba.
const _LABEL_INK := 5.0
## El aire entre la coordenada y las dos líneas de rejilla de su esquina.
const _LABEL_INSET := 2.0
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
## La foto del último barrido. Vacías = se va en directo. Ver [member
## sweep_interval].
var _sweep_at: Dictionary[Unit, Vector2] = {}
var _sweep_facing: Dictionary[Unit, float] = {}
## Empieza en infinito para que el primer fotograma ya barra: si no, el mapa
## recién abierto se queda con el dibujo de [method _refit] hasta que pase el
## primer intervalo entero.
var _since_sweep: float = INF
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
## Los contactos que hay que señalar. Cada mapa lleva los suyos: el grande está
## oculto casi siempre pero sigue apuntándolos, así que al abrirlo se ve lo que
## está pasando en vez de nada.
var _alerts := ThreatPulses.new()


func _ready() -> void:
	resized.connect(_refit)
	_refit()
	if show_alerts:
		_alerts.attach(self)


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


## Lo que ocupa el dibujo, que no es lo mismo que lo que ocupa el control.
func drawn_size() -> Vector2:
	return _drawn_size() if _terrain != null else Vector2.ZERO


## Lo que ocuparía a una escala dada. Lo usa el minimapa para medirse por
## escalas enteras en vez de por píxeles sueltos: pedir "un poco más alto" no
## significa nada cuando el dibujo sólo existe a 1x, 2x, 3x…
func size_for_scale(scale: int) -> Vector2:
	if _terrain == null:
		return Vector2.ZERO
	return Vector2(_terrain.texture.get_size()) * maxi(scale, 1)


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

	var margin := 0 if fill_panel or not show_labels else _LABEL_MARGIN * 2
	var space := Vector2i(maxi(int(size.x) - margin, 1), maxi(int(size.y) - margin, 1))
	# Cubrir pide la escala más pequeña que tapa los dos lados; caber, la más
	# grande que no se sale por ninguno.
	var fit: int = maxi(
			ceili(float(space.x) / used.size.x),
			ceili(float(space.y) / used.size.y)) if fill_panel 			else mini(space.x / used.size.x, space.y / used.size.y)

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
	refitted.emit()


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
	# Con barrido, los contactos sólo cambian de sitio cuando toca: repintar
	# cada fotograma sobra, se repinta en el barrido y ya.
	var live := show_units and sweep_interval <= 0.0
	var swept := false
	if show_units and sweep_interval > 0.0:
		_since_sweep += delta
		if _since_sweep >= sweep_interval:
			_since_sweep = 0.0
			_sweep()
			swept = true
	elif not _sweep_at.is_empty():
		# Se apagó el barrido en marcha: hay que soltar la foto o los contactos
		# se quedan clavados donde estaban para siempre.
		_sweep_at.clear()
		_sweep_facing.clear()
		_since_sweep = INF
	var current := get_viewport().get_canvas_transform()
	# Las ondas se mueven solas, así que hay que repintar mientras haya alguna
	# viva aunque no se mueva nada más. Con los puntos en directo ya se repinta
	# cada frame de todos modos.
	if live or swept or current != _last_transform \
			or (show_alerts and _alerts.any_active()):
		_last_transform = current
		queue_redraw()


## Toma la foto de la vuelta: dónde está y hacia dónde mira cada contacto.
##
## Se rehace entera en vez de ir remendándola, y así los que murieron se caen
## solos sin que nadie tenga que avisar. Misma razón por la que los contactos
## se sacan del grupo y no de una lista propia —ver [method _draw_units].
func _sweep() -> void:
	_sweep_at.clear()
	_sweep_facing.clear()
	for node in get_tree().get_nodes_in_group(Unit.GROUP):
		var unit := node as Unit
		if unit == null:
			continue
		_sweep_at[unit] = unit.global_position
		_sweep_facing[unit] = unit.get_facing()


## Dónde está el contacto **para el mapa**: donde lo dejó el último barrido, o
## donde está de verdad si se va en directo. Uno que nació entre dos barridos
## sale en directo hasta el siguiente: aparecer tarde se leería como que el
## juego se lo tragó.
func _seen_at(unit: Unit) -> Vector2:
	return _sweep_at.get(unit, unit.global_position)


## Hacia dónde miraba en el último barrido. Va con la posición: una flecha que
## gira sobre un símbolo quieto delata que la foto está vieja.
func _seen_facing(unit: Unit) -> float:
	return _sweep_facing.get(unit, unit.get_facing())


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
	# Antes que los símbolos, para que la línea salga de detrás del contacto en
	# vez de cruzarle el dibujo por encima.
	var routed := _draw_destination(drawn)
	if _has_order and not routed:
		_draw_order_marker(drawn)
	if show_units:
		_draw_units(drawn)
	# Al final del todo: es lo más urgente que hay en el mapa, así que se dibuja
	# encima de las unidades y no debajo.
	if show_alerts:
		_draw_alerts(drawn)


## Las ondas de los contactos. Cada una nace en el punto y se abre hacia afuera
## desvaneciéndose, y se repiten mientras el contacto siga vigente.
##
## El anillo es de **píxeles de pantalla y no de mundo**: lo que dice es "mirá
## acá", y eso tiene que medir lo mismo en el minimapa que en el mapa grande. Un
## radio a escala real sería de dos píxeles en el minimapa.
func _draw_alerts(drawn: Vector2) -> void:
	var inside := Rect2(_origin, drawn)
	for pulse in _alerts.active():
		var center := world_to_local(pulse["where"])
		if not inside.has_point(center):
			continue
		_draw_rings(center, float(pulse["age"]), _alert_color(pulse["kind"]))


func _alert_color(kind: ThreatPulses.Kind) -> Color:
	match kind:
		ThreatPulses.Kind.MISSILE:
			return _COLOR_MISSILE
		ThreatPulses.Kind.FIRED_UPON:
			return _COLOR_FIRED_UPON
		_:
			return _COLOR_TRACKED


func _draw_rings(center: Vector2, age: float, color: Color) -> void:
	var every := ThreatPulses.LIFETIME / float(alert_rings)
	for i in alert_rings:
		# Cada onda arranca más tarde que la anterior. Las que aún no han salido
		# dan negativo y se saltan.
		var t := (age - i * every) / every
		if t < 0.0 or t > 1.0:
			continue
		var faded := color
		faded.a = 1.0 - t
		draw_arc(center, alert_radius_px * t, 0.0, TAU, 24, faded, 1.0)


## La línea que une al contacto seleccionado con el punto al que va, rematada
## por el aspa. Devuelve si la dibujó.
##
## **Sale de dónde está la unidad ahora**, no de dónde estaba al dar la orden:
## así se va acortando sola conforme llega, sin que nadie tenga que refrescarla,
## y desaparece cuando la unidad deja de tener destino. Por eso sustituye al
## marcador suelto de [method set_order_marker], que dice lo mismo peor: un
## punto sin línea no cuenta de quién es la orden.
##
## Se traza, no se pega: una textura estirada de un punto a otro engorda el
## trazo de 1 px a 3 en cuanto la distancia crece. El color es el del dibujo de
## la marca — ver [constant _COLOR_DESTINATION].
func _draw_destination(drawn: Vector2) -> bool:
	# Sólo de lo nuestro. La ficha de un enemigo se abre igual —para eso están
	# los corchetes en cuatro colores—, pero a dónde va no es algo que se sepa
	# por mirarlo: la flecha de rumbo dice hacia dónde apunta ahora y ahí acaba
	# lo que el mapa puede contar de él.
	if destination_mark == null or not is_instance_valid(_selected) \
			or not _selected.is_player_controlled():
		return false
	var going: Variant = _selected.get_move_destination()
	if going == null:
		return false
	var inside := Rect2(_origin, drawn)
	var to := world_to_local(going)
	if not inside.has_point(to):
		return false
	var from := world_to_local(_seen_at(_selected))
	# Ya llegó: una línea de dos píxeles no dice nada y el aspa se le monta
	# encima al propio contacto.
	if from.distance_to(to) < 4.0:
		return false
	draw_line(from.round(), to.round(), _COLOR_DESTINATION, 1.0)
	var size := destination_mark.get_size()
	draw_texture(destination_mark,
			(to - Vector2(size.x * 0.5, size.y + destination_gap)).round())
	return true


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
## Con [member grid_texture] se repite la celda dibujada, una por zona; sin ella
## se trazan las líneas a mano. Lo primero es lo que se quiere cuando la rejilla
## es arte; lo segundo sigue ahí porque el mapa a pantalla completa usa zonas de
## un tamaño que no tiene por qué ser múltiplo de la celda.
func _draw_grid(drawn: Vector2) -> void:
	var paso := cell_px() * _zone_side()
	if not _tiles_cleanly(paso):
		_draw_lines(drawn, paso, grid_color)
		return
	var escala := paso / grid_texture.get_size().x
	var y := 0.0
	while y < drawn.y:
		var x := 0.0
		while x < drawn.x:
			# La última zona de cada lado casi nunca cae entera. Se dibuja sólo
			# el trozo que queda dentro del mapa y se recorta la textura en la
			# misma proporción, para que no se deforme ni se salga del terreno.
			var trozo := Vector2(minf(paso, drawn.x - x), minf(paso, drawn.y - y))
			draw_texture_rect_region(grid_texture,
					Rect2(_origin + Vector2(x, y), trozo),
					Rect2(Vector2.ZERO, trozo / escala))
			x += paso
		y += paso


## ¿La zona mide un número entero de celdas dibujadas? Si no, escalar la textura
## la dejaría a medio píxel y en pixel art eso se ve sucio: mejor las líneas.
func _tiles_cleanly(paso: float) -> bool:
	if grid_texture == null or paso < 1.0:
		return false
	var lado := grid_texture.get_size().x
	if lado <= 0.0:
		return false
	var veces := paso / lado
	return is_equal_approx(veces, roundf(veces)) and veces >= 1.0


## La rejilla se estira con el mapa porque el paso sale de `cell_px()`, que ya
## va en la escala a la que se está dibujando: al agrandar el minimapa las
## líneas se separan solas y siguen cayendo en los bordes de zona. Lo que **no**
## escala es el punteado — ver [member grid_dash].
func _draw_lines(drawn: Vector2, step: float, color: Color) -> void:
	if step < 1.0:
		return
	var x := step
	while x < drawn.x:
		_dashed(_origin + Vector2(x, 0.0), _origin + Vector2(x, drawn.y), color)
		x += step
	var y := step
	while y < drawn.y:
		_dashed(_origin + Vector2(0.0, y), _origin + Vector2(drawn.x, y), color)
		y += step
	if grid_border:
		draw_rect(Rect2(_origin, drawn), color, false, 1.0)


## Punteado horizontal o vertical. Sólo sirve para eso, que es lo único que
## dibuja la rejilla, y así el reparto de trazos cae en píxeles enteros.
func _dashed(from: Vector2, to: Vector2, color: Color) -> void:
	var largo := (to - from).length()
	var paso := float(grid_dash + grid_gap)
	if grid_gap <= 0 or paso <= 0.0:
		draw_line(from, to, color, 1.0)
		return
	var dir := (to - from).normalized()
	var at := 0.0
	while at < largo:
		var trazo := minf(float(grid_dash), largo - at)
		draw_line(from + dir * at, from + dir * (at + trazo), color, 1.0)
		at += paso


## La coordenada de cada zona, escrita dentro de ella.
##
## Antes iban fuera, en los cuatro márgenes, y eso obligaba a seguir la fila con
## el dedo hasta el borde para saber en qué cuadro estaba un contacto. Puestas
## en cada zona la lectura es directa, y no estorban porque se apoyan en las
## líneas de la rejilla, que es donde no hay nada dibujado.
##
## Se saltan las zonas que caen fuera del panel: a pantalla completa el mapa se
## recorta y escribir contra un borde cortado deja medias letras.
func _draw_labels(drawn: Vector2) -> void:
	var font := label_font if label_font != null else get_theme_default_font()
	if font == null:
		return
	var side := _zone_side()
	var zones := _terrain.zone_count(side)
	var step := cell_px() * side
	if step < _FONT_SIZE * 2.0:
		return
	var panel := Rect2(Vector2.ZERO, size)

	for j in range(zones.y):
		var top := _origin.y + step * j
		var alto := minf(step, _origin.y + drawn.y - top)
		for i in range(zones.x):
			var left := _origin.x + step * i
			var ancho := minf(step, _origin.x + drawn.x - left)
			# Contra el trozo **visible** de la zona y no contra la zona entera: a
			# pantalla completa el mapa se sale por los cuatro lados y las de los
			# bordes tienen la esquina fuera. Ahí la coordenada se apoya en el
			# filo del panel, que es donde el cuadro empieza a verse.
			var visto := Rect2(left, top, ancho, alto).intersection(panel)
			var texto := "%s%d" % [MapTerrain.column_label(i), j + 1]
			var w := font.get_string_size(
				texto, HORIZONTAL_ALIGNMENT_LEFT, -1, _FONT_SIZE).x
			# Si de la zona sólo asoma una tira, no se escribe: media coordenada
			# recortada dice menos que ninguna.
			if visto.size.x < w + _LABEL_INSET * 2.0 \
				or visto.size.y < _LABEL_INK + _LABEL_INSET * 2.0:
				continue
			# La esquina de la tinta, no la de la caja de la fuente: el ascenso es
			# mayor que la letra, así que anclando ahí la coordenada cae unos píxeles
			# más abajo de donde se la colocó. Mayúsculas y dígitos se apoyan en la
			# línea de base, y la línea de base es la tinta más su alto.
			var tinta := (visto.position + Vector2(_LABEL_INSET, _LABEL_INSET)).round()
			_draw_outlined(font, tinta + Vector2(0.0, _LABEL_INK), texto)


## La coordenada con un píxel de negro alrededor.
##
## Se dibuja ocho veces corrida y una encima, porque
## [method CanvasItem.draw_string_outline] no saca nada con esta fuente: el
## contorno de un grado no llega a generar glífo. Ocho y no cuatro para que
## las esquinas cierren —con las cuatro rectas el borde queda abierto en
## diagonal y la letra se sigue pegando al fondo por ahí.
func _draw_outlined(font: Font, base: Vector2, texto: String) -> void:
	if label_outline.a > 0.0:
		for dx in [-1.0, 0.0, 1.0]:
			for dy in [-1.0, 0.0, 1.0]:
				if dx == 0.0 and dy == 0.0:
					continue
				draw_string(font, base + Vector2(dx, dy), texto,
					HORIZONTAL_ALIGNMENT_LEFT, -1, _FONT_SIZE, label_outline)
	draw_string(font, base, texto,
		HORIZONTAL_ALIGNMENT_LEFT, -1, _FONT_SIZE, label_color)


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
		var center := world_to_local(_seen_at(unit))
		# Una unidad fuera del mapa no se pinta en el borde: se pintaría encima
		# de las coordenadas y mentiría sobre dónde está.
		if not inside.has_point(center):
			continue
		var symbol := _symbol_for(unit.team)
		var rect: Rect2
		# Por dónde acaba TODO lo que dibuja este contacto: contra el borde
		# derecho se coloca la etiqueta de medio y contra el de abajo, el nombre.
		var edge := 0.0
		var bottom := 0.0
		if symbol != null:
			rect = _draw_symbol(symbol, center)
			bottom = _draw_domain(unit, rect)
			edge = _draw_heading(unit, rect)
		else:
			rect = Rect2((center - Vector2(half, half)).round(),
					Vector2(marker_px, marker_px))
			draw_rect(rect.grow(1.0), _COLOR_MARKER_EDGE, true)
			draw_rect(rect, Team.color(unit.team), true)
		# La seleccionada lleva su propio recuadro, separado del punto para que
		# no se coma el color del bando. Esto sustituye al recuadro de cámara.
		edge = maxf(edge, rect.end.x)
		bottom = maxf(bottom, rect.end.y)
		if unit == _selected:
			edge = maxf(edge, _draw_bracket(unit.team, center))
			bottom = maxf(bottom, center.y + _bracket_reach(unit.team))
		if show_contact_names:
			_draw_contact_tag(unit, rect, edge)
		if show_selected_name and unit == _selected:
			_draw_selected_name(unit, center, bottom)


## El marco que le toca a ese bando, o `null` si este mapa no lleva símbolos.
func _symbol_for(team: Team.Side) -> Texture2D:
	return _by_team(team, contact_player, contact_ally, contact_enemy, contact_neutral)


func _heading_for(team: Team.Side) -> Texture2D:
	return _by_team(team, heading_player, heading_ally, heading_enemy, heading_neutral)


func _bracket_for(team: Team.Side) -> Texture2D:
	return _by_team(team, bracket_player, bracket_ally, bracket_enemy, bracket_neutral)


## Los tres juegos de dibujos van por bando y se eligen igual; el reparto se
## escribe una vez. Lo que no se puede es teñir uno solo: ver [member
## contact_player].
func _by_team(team: Team.Side, player: Texture2D, ally: Texture2D,
		enemy: Texture2D, neutral: Texture2D) -> Texture2D:
	match team:
		Team.Side.PLAYER:
			return player
		Team.Side.ALLY:
			return ally
		Team.Side.ENEMY:
			return enemy
		_:
			return neutral


## Planta el marco centrado en el contacto y devuelve el hueco que ocupa.
##
## La posición se redondea a píxel entero: el símbolo es arte, no terreno, y a
## media rejilla el filo oscuro se emborrona contra el mapa.
func _draw_symbol(symbol: Texture2D, center: Vector2) -> Rect2:
	var size := symbol.get_size()
	var at := (center - size * 0.5).round()
	draw_texture(symbol, at)
	return Rect2(at, size)


## La marca de dominio, pegada al marco: arriba si vuela, abajo si navega, y la
## T invertida debajo si va sumergida.
##
## **Lo que va por el suelo no lleva ninguna.** No es un olvido: la marca dice
## en qué medio se mueve el contacto *además* de estar en el mapa, y para algo
## que va por el suelo eso no añade nada. Que no la lleve ya lo distingue de un
## buque, que es el caso con el que se confundía.
func _draw_domain(unit: Unit, frame: Rect2) -> float:
	var domain := unit.get_domain()
	var art := domain_bar
	if domain == UnitType.Domain.SUBMERGED:
		art = domain_subsurface
	elif domain == UnitType.Domain.SURFACE:
		return frame.end.y
	if art == null:
		return frame.end.y
	var size := art.get_size()
	# Centrada a lo ancho del marco y separada por el lado que le toca.
	var top := frame.end.y + float(domain_gap)
	if domain == UnitType.Domain.AIR:
		top = frame.position.y - size.y - float(domain_gap)
	var at := Vector2(frame.position.x + (frame.size.x - size.x) * 0.5, top)
	draw_texture(art, at.round())
	# Por dónde acaba: el nombre del seleccionado va debajo de todo, y con la
	# barra colgando de un buque se le montaba encima.
	return maxf(frame.end.y, top + size.y)


## La flecha de rumbo, apoyada en el borde del símbolo y apuntando a donde mira
## la unidad.
##
## Se coloca con [method CanvasItem.draw_set_transform] y no rotando un nodo: el
## dibujo es el mismo para todos los contactos y lo único que cambia es el
## ángulo con el que se estampa. La cola queda a [member heading_gap] del borde
## **de la caja medida en esa dirección**, que es lo que hace que un rectángulo
## de 11×7 la lleve igual de separada mirando al norte que al este.
func _draw_heading(unit: Unit, frame: Rect2) -> float:
	var art := _heading_for(unit.team)
	if art == null:
		return frame.end.x
	var size := art.get_size()
	# El giro se hace sobre el **centro del píxel central** del símbolo, que en
	# uno de lado impar cae en un `.5`. Redondearlo lo llevaba a un vértice de la
	# rejilla, y como la flecha se colocaba además medio píxel a la izquierda los
	# dos desvíos se cancelaban **sólo mirando al norte**: en cuanto giraba, ese
	# medio píxel daba la vuelta al vértice y el punto de la cola aterrizaba en
	# un píxel vecino distinto según el cuadrante.
	var center := frame.get_center()
	var facing := _seen_facing(unit)
	# El dibujo apunta al norte y el ángulo cero mira al este: de ahí el cuarto
	# de vuelta.
	draw_set_transform(center, facing + PI * 0.5, Vector2.ONE)
	# Por el **centro** del píxel de la cola, no por su borde: así se queda sobre
	# el eje del giro y no se mueve mida lo que mida la flecha.
	draw_texture(art, Vector2(-(floorf(size.x * 0.5) + 0.5),
			-(float(heading_gap) + size.y) + 0.5))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	# Lo que se le reserva al contacto es **el círculo entero que barre la
	# flecha**, no lo que ocupa con este rumbo. Es la misma regla que hace que
	# todos los símbolos quepan en la misma caja: si cada uno se midiera por su
	# cuenta, el nombre se movería doce píxeles cada vez que la unidad gira, y
	# una formación entera bailaría al virar. Sale más aire del que pide un
	# contacto mirando al norte; a cambio, nada se pisa nunca.
	return ceilf(center.x + float(heading_gap) + size.y)


## Las cuatro esquinas del contacto seleccionado. Devuelve por dónde acaban, que
## es lo que el nombre necesita para no meterse dentro.
##
## Sin dibujo asignado queda el recuadro de siempre, para que un mapa sin arte
## siga diciendo cuál está seleccionada.
func _draw_bracket(team: Team.Side, center: Vector2) -> float:
	var art := _bracket_for(team)
	if art == null:
		var fallback := Rect2(center, Vector2.ZERO).grow(6.0)
		draw_rect(fallback, _COLOR_ACCENT, false, 1.0)
		return fallback.end.x
	var size := art.get_size()
	draw_texture(art, (center - size * 0.5).round())
	return center.x + size.x * 0.5


## La clase del contacto, al lado de su símbolo.
##
## Va blanca y no del color del bando: el bando ya lo dicen la forma y el color
## del símbolo, y el blanco es lo que mejor se despega de todos los terrenos.
func _draw_contact_tag(unit: Unit, frame: Rect2, edge: float) -> void:
	var font := contact_font if contact_font != null else get_theme_default_font()
	if font == null:
		return
	var text := "[%s]" % unit.get_map_tag()
	var ascent := font.get_ascent(contact_font_size)
	var descent := font.get_descent(contact_font_size)
	var at := Vector2(edge + contact_name_gap,
			frame.get_center().y + (ascent - descent) * 0.5).round()
	_draw_plain(font, at, text, contact_font_size)


## El nombre del contacto seleccionado, centrado bajo todo lo que dibuja.
##
## Se centra contra el **centro del contacto** y no contra su caja de texto
## anterior: la caja cambia de ancho con cada nombre y el símbolo no se mueve.
func _draw_selected_name(unit: Unit, center: Vector2, bottom: float) -> void:
	var font := selected_name_font if selected_name_font != null 			else get_theme_default_font()
	if font == null:
		return
	var text := unit.get_display_name().to_upper()
	if text.is_empty():
		return
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			selected_name_font_size)
	var at := Vector2(center.x - size.x * 0.5,
			bottom + selected_name_gap + font.get_ascent(selected_name_font_size)).round()
	_draw_plain(font, at, text, selected_name_font_size)


## Una sola pasada, sin filo. El contorno lo pedía el blanco sobre la selva,
## pero rasterizar dos veces un pixel font es justo lo que no se le hace: engorda
## el trazo de 1 px y deja de ser el dibujo que es.
func _draw_plain(font: Font, at: Vector2, text: String, size: int) -> void:
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			size, _COLOR_CONTACT_NAME)


## Cuánto baja el corchete desde el centro del contacto, para que el nombre no
## se le meta dentro.
func _bracket_reach(team: Team.Side) -> float:
	var art := _bracket_for(team)
	return art.get_size().y * 0.5 if art != null else 0.0


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
		var center := world_to_local(_seen_at(unit))
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
