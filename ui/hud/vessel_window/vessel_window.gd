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
@onready var _frame: NinePatchRect = $Frame
@onready var _inner: NinePatchRect = $Frame/InnerFrame
@onready var _pages: Control = $Frame/InnerFrame/Pages
@onready var _side_tabs: Control = $SideTabs
@onready var _hangar: HangarPage = $Frame/InnerFrame/Pages/HangarPage

## El buque cuyo interior se está mirando. Todavía no lo usa nadie: lo guardará
## el hangar cuando exista, para saber a quién le pide los aviones.
var ship: Node2D = null

var _tabs: Array[TextureButton] = []
var _section: int = -1

var _dragging := false
var _grab := Vector2.ZERO

## Lo que el marco añade por fuera del hueco donde vive una página: los bordes
## del marco exterior más los del interior. Se mide una vez de los `offset` de la
## escena en vez de escribirlo aquí, para que mover un borde en el editor no
## deje la ventana midiendo de más.
var _chrome := Vector2.ZERO

## Lo más estrecha que puede quedarse la ventana: **lo que mide dibujada**.
##
## El ancho tiene mínimo y el alto no, y no es una asimetría caprichosa. A lo
## alto la ventana se pliega hasta esconder bloques enteros, así que quedarse por
## debajo de lo dibujado es justo lo que se le pide. A lo ancho no se esconde
## nada: la ficha del avión sigue ahí y necesita su sitio, de modo que lo dibujado
## es el suelo y sólo se crece por encima.
var _min_page_width := 0.0
var _resize: Tween = null


func _ready() -> void:
	for child in _side_tabs.get_children():
		var tab := child as TextureButton
		if tab == null:
			continue
		var index := _tabs.size()
		tab.pressed.connect(func() -> void: show_section(index))
		_tabs.append(tab)
	_chrome = Vector2(
			(_inner.offset_left - _inner.offset_right)
					+ (_pages.offset_left - _pages.offset_right),
			(_inner.offset_top - _inner.offset_bottom)
					+ (_pages.offset_top - _pages.offset_bottom))
	_min_page_width = (_frame.offset_right - _frame.offset_left) - _chrome.x
	# Una sola vez: la medida no depende de qué sección esté puesta, sino de la
	# lista entera de títulos.
	_fit_top_tab()
	show_section(0)
	# El hangar es quien decide la medida, porque es el único que se despliega. Se
	# le pregunta al arrancar y luego avisa él cuando cambia.
	_hangar.size_wanted.connect(_resize_to)
	_resize_to(0.0, _hangar.wanted_height(), 0.0)
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


## Ajusta la ventana al alto que pide la página abierta.
##
## Se anima `size` y no `offset_bottom`: la ventana se arrastra, y arrastrarla
## mueve los dos `offset` a la vez, así que un destino calculado sobre el de
## abajo se queda viejo en cuanto el jugador la mueve a media animación.
##
## El alto de la raíz va detrás del marco y no suelto. La raíz es la zona de
## agarre —todo lo que no sea un botón arrastra la ventana—, y si se queda
## grande cuando el marco se encoge deja un trozo invisible por debajo que
## agarra donde ya no hay ventana.
func _resize_to(width: float, height: float, seconds: float) -> void:
	if _resize != null and _resize.is_valid():
		_resize.kill()
		_resize = null
	var frame_size := Vector2(maxf(width, _min_page_width), height) + _chrome
	# La ventana crece **hacia la derecha y hacia abajo**: el borde de arriba a la
	# izquierda no se mueve, y con él se quedan quietas las solapas, la pestaña del
	# título y la columna de aparatos. Ensanchar por el centro las movería todas a
	# la vez y el cambio se vería mucho más de lo que cuesta.
	var window_size := _frame.position + frame_size
	if is_zero_approx(seconds):
		_frame.size = frame_size
		size = window_size
		return
	_resize = create_tween().set_parallel()
	_resize.tween_property(_frame, ^"size", frame_size, seconds)
	_resize.tween_property(self, ^"size", window_size, seconds)


func _fit_top_tab() -> void:
	var font := _title.get_theme_font(&"font")
	var font_size := _title.get_theme_font_size(&"font_size")
	var widest := 0.0
	for title in section_titles:
		widest = maxf(widest, font.get_string_size(
				title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	_top_tab.size.x = roundf(widest) + _TITLE_PADDING * 2.0
