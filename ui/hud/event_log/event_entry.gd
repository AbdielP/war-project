extends Control
class_name EventEntry

## Una línea del parte: el filete que la separa de la anterior, su ícono y su
## texto.
##
## Los tres van a **posición libre**, no dentro de contenedores: en Godot un
## contenedor decide dónde van sus hijos y el editor no te deja moverlos. Aquí
## se arrastran a mano, que es de lo que se trata — abrí la escena y ponelos
## donde quieras.
##
## Lo único que no puede quedar suelto es el alto: cuando el texto no cabe en una
## línea parte en dos, y la entrada tiene que crecer o la siguiente se le monta
## encima. De eso se encarga [method _fit], y es la razón de que este script
## exista.

## El jugador pulsó la coordenada. Se reenvía hacia arriba porque aquí no se
## conoce ni la cámara ni el mapa.
signal coordinate_clicked(meta: Variant)

## Aire por debajo del texto, antes de la siguiente entrada. El de arriba se
## consigue moviendo el texto y el ícono en la escena; éste no, porque la
## entrada mide justo lo que ocupa su contenido y sin esto la de abajo vendría
## pegada.
@export_range(0, 16, 1) var padding_bottom: int = 4

## Cuánto se queda a plena vista antes de empezar a apagarse.
@export var fade_after: float = 6.0
## Lo que tarda en apagarse, una vez empieza.
@export var fade_time: float = 1.5
## Hasta dónde baja. **No llega a cero a propósito**: la entrada no desaparece,
## se transparenta. Sigue leyéndose y su coordenada sigue siendo pulsable —
## el parte no pierde historia, sólo deja de robar la vista.
@export_range(0.05, 1.0, 0.05) var faded_alpha: float = 0.35

@onready var rule: ColorRect = $Rule
@onready var icon: TextureRect = $Icon
@onready var label: RichTextLabel = $Text

var _fade: Tween = null


func _ready() -> void:
	label.meta_clicked.connect(func(meta: Variant) -> void:
		coordinate_clicked.emit(meta))
	# El ancho lo manda el panel y cambia con él; el alto se recalcula cada vez
	# que el texto se recompone, que es cuando puede pasar de una línea a dos.
	resized.connect(_fit)
	label.finished.connect(_fit)
	_fit()


## Qué dice la entrada. Hay que llamarlo **después** de colgarla del árbol: los
## `@onready` no están resueltos antes.
##
## [param mark] a `null` deja el hueco del ícono vacío pero reservado, para que
## el texto de las líneas de continuación siga alineado con el de arriba.
func setup(text: String, mark: Texture2D, with_rule: bool) -> void:
	label.text = text
	icon.texture = mark
	rule.visible = with_rule
	_fit()
	_restart_fade()


## Reescribe el texto sin tocar el resto. Lo usa la agrupación de andanadas,
## que actualiza la cuenta de la última línea en vez de añadir otra.
func set_text(text: String) -> void:
	label.text = text
	_fit()
	# Vuelve a plena vista: si se reescribe es porque acaba de pasar algo más,
	# y una línea que cambia mientras se apaga no se lee.
	_restart_fade()


## Plena vista durante [member fade_after], luego baja a [member faded_alpha] y
## se queda ahí.
func _restart_fade() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	modulate.a = 1.0
	if faded_alpha >= 1.0:
		return
	_fade = create_tween()
	_fade.tween_interval(fade_after)
	_fade.tween_property(self, "modulate:a", faded_alpha, fade_time)


## El alto de la entrada es el de lo que llegue más abajo —el texto o el ícono—,
## contando desde dónde los hayas puesto en el editor.
func _fit() -> void:
	if label == null:
		return
	# Se mueve el borde de abajo y no `size`: el texto va anclado al lado
	# derecho del panel para seguirle el ancho, y a un nodo anclado el tamaño se
	# le recalcula solo —tocarlo directamente no sirve de nada y avisa por
	# consola—. El offset sí manda.
	label.offset_bottom = label.offset_top + label.get_content_height()
	var alto := maxf(label.offset_bottom, icon.position.y + icon.size.y)
	custom_minimum_size.y = ceilf(alto) + padding_bottom
