extends Control
class_name UnitModel

## El aparato tal y como se ve en el mapa, quieto, dentro de un hueco del HUD.
##
## No es un dibujo aparte: son **los mismos `Sprite2D` de la escena de la
## unidad**, copiados. Así no hay una segunda versión del modelo que mantener al
## día, y una unidad nueva sale aquí el día que exista sin tocar este archivo.
##
## La escena se instancia y se suelta en el acto sin llegar a entrar en el árbol,
## que es lo que evita que corra ningún `_ready`: la unidad no se entera de que
## la miraron, no se registra en ningún sitio y no queda nada colgando. De ella
## sólo se copia lo que dibuja; los controladores, las armas y el cuerpo físico
## se van con el original.

## A cuánto se le ponen las palas de un helicóptero para el retrato.
##
## El rotor está dibujado como una barra recta porque en el juego **gira**, y
## quieto a 0° cae justo encima del fuselaje: parece un mástil, no unas palas.
## Ladeándolo se ven las dos y se lee lo que es. Es una postura para la ficha, no
## un cambio en la unidad — el original ni se toca.
const _ROTOR_POSE := PI * 0.25

## Hasta dónde se puede achicar un modelo que no quepa. Sólo potencias de dos,
## por la regla de escala entera del proyecto: a media rejilla el pixel art se
## ensucia. Hoy no lo usa nadie —los dos aparatos entran a 1:1—, pero un modelo
## que no quepa se sale del hueco sin avisar, y eso no se ve hasta que pasa.
const _MIN_ZOOM := 0.125

@onready var _pivot: Node2D = $Pivot


## Enseña el modelo de una escena de unidad. `null` la deja vacía.
func show_scene(scene: PackedScene) -> void:
	for child in _pivot.get_children():
		_pivot.remove_child(child)
		child.queue_free()
	if scene == null:
		return
	var source := scene.instantiate()
	var parts: Array[Dictionary] = []
	_collect(source, Transform2D.IDENTITY, parts)
	var bounds := Rect2()
	var started := false
	for part in parts:
		var box: Rect2 = _bounds_of(part["sprite"], part["xform"])
		bounds = box if not started else bounds.merge(box)
		started = true
		_pivot.add_child(_copy_of(part["sprite"], part["xform"]))
	source.free()
	if not started:
		return
	_fit(bounds)


## Recorre la unidad quedándose con lo que dibuja, arrastrando la transformación
## de cada padre para que una pieza colgada de otra caiga donde le toca.
func _collect(node: Node, xform: Transform2D, into: Array[Dictionary]) -> void:
	for child in node.get_children():
		var item := child as Node2D
		if item == null:
			continue
		var here := xform * item.transform
		var sprite := item as Sprite2D
		if sprite != null and sprite.texture != null and sprite.visible:
			if sprite is Rotor:
				here = here.rotated_local(_ROTOR_POSE)
			into.append({"sprite": sprite, "xform": here})
		_collect(item, here, into)


func _copy_of(sprite: Sprite2D, xform: Transform2D) -> Sprite2D:
	var copy := Sprite2D.new()
	copy.texture = sprite.texture
	copy.centered = sprite.centered
	copy.offset = sprite.offset
	copy.flip_h = sprite.flip_h
	copy.flip_v = sprite.flip_v
	copy.modulate = sprite.modulate
	# Relativo, que es como viene de fábrica: así el orden entre las piezas del
	# aparato se respeta sin que ninguna se cuele por encima del resto del HUD.
	copy.z_index = sprite.z_index
	copy.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	copy.transform = xform
	return copy


## Lo que ocupa una pieza ya colocada. Se miden las **cuatro esquinas giradas** y
## no el ancho por el alto: con el rotor ladeado, la caja derecha es mucho mayor
## que la del dibujo, y midiendo de la otra forma se sale del hueco.
func _bounds_of(sprite: Sprite2D, xform: Transform2D) -> Rect2:
	var art: Vector2 = sprite.texture.get_size()
	var corner := sprite.offset
	if sprite.centered:
		corner -= art * 0.5
	var local := Rect2(corner, art)
	var box := Rect2(xform * local.position, Vector2.ZERO)
	box = box.expand(xform * Vector2(local.end.x, local.position.y))
	box = box.expand(xform * local.end)
	box = box.expand(xform * Vector2(local.position.x, local.end.y))
	return box


## Centra el modelo en el hueco, achicándolo por mitades sólo si no cabe.
##
## La posición se redondea a píxel entero: el modelo está quieto, así que aquí sí
## conviene cuadrarlo a la rejilla — media posición decimal descuadra el dibujo
## contra el resto del panel.
func _fit(bounds: Rect2) -> void:
	var zoom := 1.0
	while zoom > _MIN_ZOOM and (bounds.size.x * zoom > size.x or bounds.size.y * zoom > size.y):
		zoom *= 0.5
	_pivot.scale = Vector2(zoom, zoom)
	_pivot.position = (size * 0.5 - bounds.get_center() * zoom).round()
