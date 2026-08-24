extends Control
class_name VesselWindow

## La ventana del buque: hangar, tropas y munición, una sección por solapa.
##
## Por ahora sólo existe el armazón —marco, solapas laterales y la pestaña con
## el título—; las tres páginas están vacías. El contenido del hangar se monta
## después, y la ventana crecerá con él: tanto el marco como las pestañas son
## nine-patch, así que el arte sólo pone bordes y esquinas y la medida se
## decide aquí, no en el PNG.

## Se cerró. `instant` distingue las dos formas de que pase: el jugador la
## cierra y el buque sigue seleccionado —hay algo a lo que volver, y se vuelve
## despacio—, o se cambia de unidad y la ventana se va porque enseñaba el
## interior de otra.
signal closed(instant: bool)

## Cómo se llama cada sección en la pestaña de arriba. El orden es el mismo que
## el de las solapas dentro de `SideTabs`.
@export var section_titles: PackedStringArray = ["HANGAR", "TROPAS", "MUNICIÓN"]

## Las dos caras de una solapa lateral. Van las dos por el inspector y no con un
## `preload` dentro del script: si sólo estuviera puesta la que se ve al
## arrancar, la escena mentiría sobre lo que va a dibujar el código.
@export var tab_idle: Texture2D
@export var tab_active: Texture2D

## Aire a cada lado del título dentro de su pestaña.
##
## La pestaña mide **lo mismo en las tres secciones**, y esa medida sale del
## título más largo: si cada una se ajustara a su propio texto, la pestaña
## crecería y menguaría al cambiar de solapa —"MUNICIÓN" ocupa 7 px más que
## "HANGAR"— y parecería que se mueve la ventana entera.
const _TITLE_PADDING := 8.0

@onready var _top_tab: NinePatchRect = $TopTab
@onready var _title: Label = $TopTab/Title
@onready var _pages: Control = $Frame/InnerFrame/Pages
@onready var _side_tabs: Control = $SideTabs
@onready var _hangar: Control = $Frame/InnerFrame/Pages/HangarPage

## El buque cuyo interior se está mirando. Todavía no lo usa nadie: lo guardará
## el hangar cuando exista, para saber a quién le pide los aviones.
var ship: Node2D = null

var _tabs: Array[TextureButton] = []
var _section: int = -1

var _dragging := false
var _grab := Vector2.ZERO


func _ready() -> void:
	for child in _side_tabs.get_children():
		var tab := child as TextureButton
		if tab == null:
			continue
		var index := _tabs.size()
		tab.pressed.connect(func() -> void: show_section(index))
		_tabs.append(tab)
	# Una sola vez: la medida no depende de qué sección esté puesta, sino de la
	# lista entera de títulos.
	_fit_top_tab()
	show_section(0)
	hide()


## Arrastrar la ventana entera.
##
## Se agarra desde **cualquier sitio que no sea un botón**: los bordes del marco,
## la pestaña del título, el fondo de una página. Eso no se decide aquí sino en
## la escena — todo el decorado tiene el ratón en `IGNORE`, así que el clic cae
## hasta esta raíz, mientras que las solapas y las casillas lo paran y se quedan
## con el suyo. Por eso no hace falta una barra de título: la ventana no tiene
## una zona de agarre, tiene una lista de cosas que **no** agarran.
## La posición sale del **propio evento** y no de `get_global_mouse_position()`.
## Ese segundo lee del singleton `Input`, que no siempre va sincronizado con el
## evento que se está atendiendo; el evento sí trae dónde ocurrió.
##
## Y se recalcula contra la posición absoluta del ratón en vez de ir sumando
## desplazamientos: sumando, el redondeo a píxel entero de cada paso se va
## acumulando y la ventana se queda atrás del cursor.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if _dragging:
			_grab = event.global_position - global_position
	elif event is InputEventMouseMotion and _dragging:
		# Redondeado a píxel entero. La ventana es pixel art: media posición
		# decimal descuadra su contenido contra la rejilla y los bordes de 1 px
		# de los marcos se ven a saltos mientras se arrastra.
		global_position = (event.global_position - _grab).round()


func open(vessel: Node2D) -> void:
	ship = vessel
	_hangar.show_for(vessel)
	show_section(0)
	show()
	move_to_front()


## Cerrarla estando ya cerrada no avisa a nadie: quien escucha `closed` devuelve
## la cámara al centro, y no hay por qué mandarla de vuelta cada vez que se
## deselecciona una unidad que nunca abrió esto.
func close(instant: bool = false) -> void:
	if not visible:
		return
	hide()
	closed.emit(instant)


## Cambia de sección. La solapa activa es 4 px más ancha que las demás: ese
## trozo de más se mete por debajo del borde izquierdo de la ventana y, como su
## relleno es del mismo color, las dos quedan pegadas sin línea entre medias.
func show_section(index: int) -> void:
	if index == _section or index < 0 or index >= _tabs.size():
		return
	_section = index
	for i in _tabs.size():
		var tab := _tabs[i]
		var art: Texture2D = tab_active if i == index else tab_idle
		tab.texture_normal = art
		tab.texture_pressed = art
		tab.texture_hover = art
		# El ancho se le pregunta a la textura y no se escribe aquí: son las dos
		# caras las que se diferencian en 4 px, no una medida de la ventana.
		tab.size.x = art.get_width()
	_title.text = section_titles[index] if index < section_titles.size() else ""
	for i in _pages.get_child_count():
		var page := _pages.get_child(i) as Control
		if page != null:
			page.visible = i == index


func _fit_top_tab() -> void:
	var font := _title.get_theme_font(&"font")
	var font_size := _title.get_theme_font_size(&"font_size")
	var widest := 0.0
	for title in section_titles:
		widest = maxf(widest, font.get_string_size(
				title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	_top_tab.size.x = roundf(widest) + _TITLE_PADDING * 2.0
