extends Control

## La caja de la unidad seleccionada: cámara en vivo arriba y nombre abajo.
##
## El hueco de arriba **no es un retrato, es una cámara**: un [SubViewport] que
## comparte el `World2D` de la partida y apunta a la unidad elegida. Se la ve
## moverse, girar y disparar en directo, con sus efectos, porque es literalmente
## la misma unidad que está en el mapa vista desde otro sitio.
##
## **Cómo se queda sola en el cuadro.** No se oculta el terreno ni las demás una
## por una — sería una lista interminable y cada cosa nueva habría que acordarse
## de añadirla. Se hace al revés: la miniatura mira **una capa vacía**
## ([constant _FEED_LAYER], vía `canvas_cull_mask`) donde por omisión no hay
## nada, y al seleccionar se le presta esa capa a la unidad y a todo lo que
## cuelgue de ella. Todo lo demás —mar, tierra, aliados, enemigos— queda fuera
## por no estar invitado, no por haberlo excluido. Al soltarla se le retira.
##
## El detalle que cuesta descubrir está en [method _lend_layer]: el filtro corta
## **ramas**, no nodos, así que la capa hay que prestársela también a los padres
## de la unidad o no llega a dibujarse nada.
##
## La unidad sigue viéndose con normalidad en el mapa: se le **añade** la capa,
## no se le cambia, así que queda en las dos a la vez.
##
## Lo que entra gratis son los hijos suyos —fogonazo, humo, casquillos,
## trazadoras—, porque se recorre la rama entera. Lo que **no** entra es lo que
## se despega al dispararse y pasa a colgar del mundo: un misil o una bomba se
## ven salir y desaparecen del cuadro en cuanto se independizan.
##
## `mouse_filter` en `IGNORE` en todos: la caja flota sobre el mapa y sin eso se
## comería los clics de sus 110×113 px, tenga dibujo o no. Es la misma trampa
## que costó las órdenes bajo el registro de eventos.
##
## **El fondo son dos piezas, no una.** La cámara y el nombre no comparten
## panel: cada uno tiene su propio [NinePatchRect] (`ThumbBg`, `NameBg`), y van
## pegados sin hueco entre ellos.
##
## Las dos texturas se **recomponen** del kit de UI, donde vienen como rejilla
## de tiles de 16×16 separados por 1 px transparente. Ese hueco es una guía para
## distinguir las piezas, no parte del dibujo: al montarlas hay que quitarlo y
## dejar los tiles pegados, o el panel sale con rayas por dentro. Los cortes del
## nine-patch son por eso 16 en los cuatro lados — el tamaño del tile.

## Cuánto se aprieta el espaciado entre letras cuando un nombre no entra.
##
## **Sólo se aplica al que se pasa, y eso es el punto.** Apretar la fuente
## siempre —que fue el primer intento— pega las letras unas a otras y deja los
## seis nombres peor para arreglar uno: `AH-1W` se leía como un borrón. Con el
## espaciado natural entran cinco de los seis con aire de sobra; el sexto
## (`AH-1W SuperCobra`, 95 px contra los 85 del hueco) se aprieta y pasa a 80.
##
## Es un remiendo consciente: la salida limpia es ensanchar la banda del nombre
## unos 10 px en el PNG, y entonces esto deja de dispararse solo.
const _TIGHT_SPACING := -1

## La capa de dibujo que sólo mira la miniatura. Es el bit 2 (valor 2) porque el
## 1 lo usa todo lo demás sin que nadie lo haya tenido que poner: es el valor de
## fábrica de `visibility_layer`. Así el mundo se sigue viendo entero en la
## partida y esta capa nace vacía, que es justo lo que la hace útil.
##
## Tiene que coincidir con el `canvas_cull_mask` del `SubViewport` en la escena.
const _FEED_LAYER := 2

## Grupo de los nodos que **no** salen en la miniatura aunque cuelguen de la
## unidad. Se marca en la escena, no aquí, para que añadir uno nuevo no obligue a
## tocar este script.
const _NO_FEED := &"sin_miniatura"

@onready var _name: Label = $Name
@onready var _feed: SubViewport = $Thumbnail/Feed
@onready var _lens: Camera2D = $Thumbnail/Feed/Lens

## A quién apunta la cámara. Se guarda para poder devolverle su capa cuando se
## deje de mirarla, y para seguirla cada frame.
var _watched: Unit = null

## Dónde está el centro del **dibujo** de la unidad mirada, en coordenadas suyas.
## Ver [method _visual_offset].
var _aim: Vector2 = Vector2.ZERO

## Lo medido de cada textura —centro de su tinta y radio que barre al girar—
## para no repetir el barrido. Es `static` porque no depende de la instancia: la
## misma textura da lo mismo siempre, así que dos Harrier la miden una vez entre
## los dos. Ver [method _measure_ink].
static var _centers: Dictionary = {}

## La fuente apretada se fabrica una vez y se reutiliza. Se construye sobre la
## que tenga el Label en la escena, así que cambiarla en el editor sigue
## mandando sobre las dos versiones.
var _tight_font: FontVariation
var _wide_font: Font


func _ready() -> void:
	_wide_font = _name.get_theme_font(&"font")
	_tight_font = FontVariation.new()
	_tight_font.base_font = _wide_font
	_tight_font.spacing_glyph = _TIGHT_SPACING
	# Que la miniatura mire **la misma partida** y no un mundo suyo vacío. No se
	# puede dejar puesto desde el editor: el `World2D` de la partida no existe
	# hasta que corre, así que es aquí o en ningún sitio.
	_feed.world_2d = get_viewport().world_2d
	set_process(false)


## La cámara persigue a la unidad **cada frame y en `_process`**, no atada a ella
## como hija: colgarla de la unidad le heredaría el giro y sería la caja la que
## daría vueltas en vez del avión. Se copia sólo la posición, nunca la rotación.
func _process(_delta: float) -> void:
	if is_instance_valid(_watched):
		# `to_global` y no una suma: el punto de mira está en coordenadas de la
		# unidad, así que cuando ella gira el punto gira con ella y el dibujo
		# sigue centrado en el cuadro en vez de bambolearse.
		#
		# **Sin redondear a píxel entero.** Se probó y es justo lo contrario de
		# lo que parece: aquí la cámara no mira un escenario quieto, mira un
		# objeto que se mueve con ella. Cuadrar la cámara a la rejilla mientras
		# la unidad avanza en decimales deja entre las dos una diferencia que
		# cambia cada frame, y la unidad vibra dentro del cuadro. Pegada a ella
		# sin redondeos, la diferencia es siempre la misma y la imagen se queda
		# clavada, que es lo que se busca.
		_lens.global_position = _watched.to_global(_aim)
	else:
		# Se murió mientras se la miraba. Se deja de seguir en el sitio; quien
		# manda la selección se encarga de cerrar la caja.
		_watched = null
		set_process(false)


func show_unit(unit: Unit) -> void:
	_watch(unit)
	var unit_name := unit.get_display_name()
	_name.text = unit_name
	_fit(unit_name)
	show()


func clear() -> void:
	_watch(null)
	hide()


## Presta la capa de la miniatura a la unidad —y se la quita a la anterior— y
## apunta la cámara con el zoom que declare su tipo.
func _watch(unit: Unit) -> void:
	if _watched == unit:
		return
	if is_instance_valid(_watched):
		_lend_layer(_watched, false)
	_watched = unit
	set_process(unit != null)
	if unit == null:
		return
	_lend_layer(unit, true)
	# El zoom de una [Camera2D] es al revés que el de una lente: 2 acerca. Aquí
	# se quiere lo contrario —0.5 significa "a mitad de tamaño"—, así que entra
	# tal cual y es Godot quien lo interpreta como acercamiento. Un tipo sin
	# declarar deja el 1:1, que es el peor caso pero nunca una unidad invisible.
	var factor := unit.unit_type.thumb_scale() if unit.unit_type != null else 1.0
	_lens.zoom = Vector2.ONE * factor
	_aim = _visual_offset(unit)
	_lens.global_position = unit.to_global(_aim).round()


## Añade o retira [constant _FEED_LAYER] en la unidad, en toda su descendencia
## dibujable **y en sus padres**.
##
## Los hijos, porque `visibility_layer` no se hereda: cada [CanvasItem] lleva la
## suya, así que sin recorrer hacia abajo saldría el casco del avión y no su
## fogonazo.
##
## Los padres, porque el descarte del canvas **no es por nodo, es por rama**: si
## un ancestro no pasa el filtro, se corta ahí y todo lo que cuelga de él se cae
## con él, tenga la capa o no. Comprobado a base de sacar el cuadro vacío — la
## unidad tenía la capa y no se veía, y bastó dársela también al `Node2D` de la
## partida para que apareciera. **Esto no cuela el terreno**: al padre se le da
## permiso de paso, pero el `TileMapLayer` es hermano de la unidad y sigue sin
## tener la capa, así que él se queda fuera por su cuenta.
func _lend_layer(unit: Unit, lend: bool) -> void:
	_lend_branch(unit, lend)
	var parent := unit.get_parent()
	while parent != null:
		_lend_one(parent as CanvasItem, lend)
		parent = parent.get_parent()


## Lo que se apunte a [constant _NO_FEED] se queda fuera del cuadro **con toda
## su rama**. Hoy sólo lo usa el anillo de selección: en el mapa dice cuál es la
## elegida, pero dentro de la miniatura sobra —ahí no hay ninguna otra con la que
## confundirla— y encima el anillo se dibuja a tamaño de mundo, así que a poco
## que se aleje el zoom llena el cuadro de puntos verdes y tapa la unidad.
func _lend_branch(node: Node, lend: bool) -> void:
	if node.is_in_group(_NO_FEED):
		return
	_lend_one(node as CanvasItem, lend)
	for child in node.get_children():
		_lend_branch(child, lend)


## A qué punto de la unidad hay que apuntar para que su dibujo salga centrado.
##
## **No es su origen, y tampoco el centro de su sprite principal.** Dos motivos,
## y el segundo es el que decide cuánto zoom aguanta la unidad:
##
## 1. Un sprite se dibuja centrado en su lienzo, pero el dibujo no tiene por qué
##    estar centrado *dentro* del lienzo: el LHD ocupa 106×222 de un PNG de
##    160×304, así que apuntando al origen el barco sale corrido.
## 2. Una unidad puede ser varias piezas, y la que sobresale no tiene por qué ser
##    la principal. El rotor del Cobra es un sprite aparte de 47 px colgado en
##    `(1,6)`: apuntando al fuselaje, las palas barren un círculo de 59 px que no
##    cabe en los 59 de la ventana y asoman por el borde. Apuntando al centro de
##    *todo el conjunto* el mismo helicóptero barre 56 y entra de sobra.
##
## Así que se calcula el **círculo envolvente más pequeño** que contiene a todas
## las piezas y se apunta a su centro. Cada pieza entra como círculo, no como
## rectángulo, porque aquí todo gira: la unidad entera gira, y el rotor además
## gira por su cuenta.
##
## La diferencia no es cosmética. Centrar bien es lo que decide si una unidad se
## ve a 1:1 o hay que bajarla a la mitad y tirar medio dibujo.
func _visual_offset(unit: Unit) -> Vector2:
	var piezas: Array[Vector3] = []
	_collect(unit, unit.global_transform.affine_inverse(), piezas)
	if piezas.is_empty():
		return Vector2.ZERO
	return _enclosing_center(piezas)


## Recoge cada pieza dibujada como un círculo `(x, y, radio)` en coordenadas de
## la unidad. Se salta lo invisible y lo que no sale en la miniatura.
func _collect(node: Node, to_unit: Transform2D, out: Array[Vector3]) -> void:
	if node.is_in_group(_NO_FEED):
		return
	var sprite := node as Sprite2D
	if sprite != null and sprite.visible and sprite.texture != null:
		var tex := sprite.texture
		if not _centers.has(tex):
			_centers[tex] = _measure_ink(tex)
		var ink: Vector3 = _centers[tex]  # (desvío del centro, media diagonal)
		var local := to_unit * sprite.global_transform
		var centro := local * Vector2(ink.x, ink.y)
		var esc := local.get_scale()
		out.append(Vector3(centro.x, centro.y, ink.z * maxf(absf(esc.x), absf(esc.y))))
	for child in node.get_children():
		_collect(child, to_unit, out)


## Centro del círculo más pequeño que contiene todos los círculos dados.
##
## Se resuelve moviendo el centro hacia el que más sobresale, con pasos cada vez
## más cortos. No hace falta más: son cuatro o cinco piezas y basta con acertar
## al píxel.
static func _enclosing_center(piezas: Array[Vector3]) -> Vector2:
	var c := Vector2.ZERO
	for p in piezas:
		c += Vector2(p.x, p.y)
	c /= piezas.size()
	var paso := 1.0
	for i in 200:
		var peor := 0.0
		var lejos := c
		for p in piezas:
			var pc := Vector2(p.x, p.y)
			var alcance := c.distance_to(pc) + p.z
			if alcance > peor:
				peor = alcance
				lejos = pc
		if lejos.is_equal_approx(c):
			break
		c += (lejos - c).normalized() * paso
		paso *= 0.97
	return c


## Mide una textura: dónde cae el centro de su tinta respecto al centro del
## lienzo, y qué radio barre esa tinta al girar. Se devuelven juntos en un
## [Vector3] `(x, y, radio)` porque se calculan del mismo barrido.
static func _measure_ink(tex: Texture2D) -> Vector3:
	var img := tex.get_image()
	if img == null:
		return Vector3.ZERO
	var x0 := img.get_width()
	var y0 := img.get_height()
	var x1 := -1
	var y1 := -1
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				x0 = mini(x0, x)
				x1 = maxi(x1, x)
				y0 = mini(y0, y)
				y1 = maxi(y1, y)
	if x1 < 0:
		return Vector3.ZERO
	var tinta := Vector2(x1 - x0 + 1, y1 - y0 + 1)
	var centro := Vector2(x0 + x1 + 1, y0 + y1 + 1) * 0.5 \
			- Vector2(img.get_width(), img.get_height()) * 0.5
	return Vector3(centro.x, centro.y, tinta.length() * 0.5)


func _lend_one(item: CanvasItem, lend: bool) -> void:
	if item == null:
		return
	if lend:
		item.visibility_layer |= _FEED_LAYER
	else:
		item.visibility_layer &= ~_FEED_LAYER


## Mide el nombre con la fuente normal y sólo si se sale cambia a la apretada.
## Se mide contra el ancho del propio Label, no contra un número escrito aquí:
## mover el Label en el editor tiene que bastar para que esto siga valiendo.
func _fit(unit_name: String) -> void:
	var size := _name.get_theme_font_size(&"font_size")
	var wide := _wide_font.get_string_size(
			unit_name, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if wide <= _name.size.x:
		_name.add_theme_font_override(&"font", _wide_font)
	else:
		_name.add_theme_font_override(&"font", _tight_font)
