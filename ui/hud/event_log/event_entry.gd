extends Control
class_name EventEntry

## Una línea del parte: sólo su texto.
##
## Va a **posición libre**, no dentro de un contenedor: en Godot un contenedor
## decide dónde van sus hijos y el editor no te deja moverlos. Aquí se arrastra
## a mano, que es de lo que se trata — abrí la escena y ponelo donde quieras.
##
## **Lo que separa una entrada de la siguiente es el aire, no una raya.** Hubo un
## filete de 1 px y se quitó: no había ancho que le cuadrara —el texto de cada
## línea mide una cosa distinta— y encima se apagaba junto con la entrada, así
## que dejaba un hilo mal medido y medio invisible. El hueco de arriba y el de
## abajo valen lo mismo, y con eso basta para leer el parte como una lista.
##
## Tampoco hay ícono. La clase de suceso la dice una **marca de un carácter** que
## compone [EventLog]: entra en el flujo del texto, así que no hay columna que
## alinear ni PNG que mantener.
##
## Lo único que no puede quedar suelto es el alto: cuando el texto no cabe en una
## línea parte en dos, y la entrada tiene que crecer o la siguiente se le monta
## encima. De eso se encarga [method _fit], y es la razón de que este script
## exista.

## El jugador pulsó la coordenada. Se reenvía hacia arriba porque aquí no se
## conoce ni la cámara ni el mapa.
signal coordinate_clicked(meta: Variant)

## Aire por debajo del texto, antes de la siguiente entrada. El de arriba se
## consigue moviendo el texto en la escena; éste no, porque la entrada mide
## justo lo que ocupa su contenido y sin esto la de abajo vendría pegada.
##
## Vale **lo mismo que el `offset_top` del texto**: los dos huecos iguales dejan
## el renglón centrado en su fila. Si se cambia uno hay que cambiar el otro.
##
## Ojo con subirlo: **el aire que se ve entre dos renglones no es este número,
## es `offset_top + padding_bottom + 4`**. Los 4 salen de la caja de la fuente —
## en M5X7 a 16 la caja mide 13 px y una mayúscula ocupa las filas 3 a 12, así
## que sobran 3 arriba y 1 abajo aunque el padding sea cero. Con 3 y 3 el hueco
## salía de 10 px para letras de 9, que es el doble de lo que parece al leer el
## número. Por debajo de 1 y 1 la `g` de un renglón toca la tilde del siguiente:
## los descendentes bajan hasta la fila 14 y se salen de la caja.
@export_range(0, 16, 1) var padding_bottom: int = 1

## Cuánto se queda a plena vista antes de empezar a apagarse.
@export var fade_after: float = 6.0
## Lo que tarda en apagarse, una vez empieza.
@export var fade_time: float = 1.5
## Hasta dónde baja. **No llega a cero a propósito**: la entrada no desaparece,
## se transparenta. Sigue leyéndose y su coordenada sigue siendo pulsable —
## el parte no pierde historia, sólo deja de robar la vista.
@export_range(0.05, 1.0, 0.05) var faded_alpha: float = 0.35

@onready var label: RichTextLabel = $Text

var _fade: Tween = null


func _ready() -> void:
	label.meta_clicked.connect(func(meta: Variant) -> void:
		coordinate_clicked.emit(meta))
	# El parte flota encima del mapa, así que **sólo la coordenada se queda el
	# clic**; el resto del renglón lo deja pasar para que la orden llegue al
	# terreno de debajo. `Lines` y `EventEntry` van en IGNORE por eso mismo: lo
	# que estorbaba no era el texto —que ya iba en PASS— sino esos dos, que se
	# habían quedado con el STOP que Godot pone por defecto y se comían el clic
	# en los 200 px de ancho de la fila, texto o no.
	label.meta_hover_started.connect(func(_meta: Variant) -> void:
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		# Vuelve a plena vista mientras se apunta: una coordenada que se va a
		# pulsar no puede estar a medio apagar.
		if _fade != null and _fade.is_valid():
			_fade.kill()
		modulate.a = 1.0)
	label.meta_hover_ended.connect(func(_meta: Variant) -> void:
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		label.mouse_default_cursor_shape = Control.CURSOR_ARROW
		_restart_fade())
	# El ancho lo manda el panel y cambia con él; el alto se recalcula cada vez
	# que el texto se recompone, que es cuando puede pasar de una línea a dos.
	resized.connect(_fit)
	label.finished.connect(_fit)
	_fit()


## Qué dice la entrada. Hay que llamarlo **después** de colgarla del árbol: los
## `@onready` no están resueltos antes.
##
func setup(text: String) -> void:
	label.text = text
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


## El alto de la entrada es el del texto, contando desde donde lo hayas puesto en
## el editor. Crece solo cuando una línea larga parte en dos.
func _fit() -> void:
	if label == null:
		return
	# Se mueve el borde de abajo y no `size`: el texto va anclado al lado
	# derecho del panel para seguirle el ancho, y a un nodo anclado el tamaño se
	# le recalcula solo —tocarlo directamente no sirve de nada y avisa por
	# consola—. El offset sí manda.
	label.offset_bottom = label.offset_top + label.get_content_height()
	custom_minimum_size.y = ceilf(label.offset_bottom) + padding_bottom
