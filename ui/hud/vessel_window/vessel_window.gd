extends Control
class_name VesselWindow

## La ventana del buque: hangar, tropas y munición, una sección por solapa.
##
## Por ahora sólo existe el armazón —marco, solapas laterales y la pestaña con
## el título—; las tres páginas están vacías. El contenido del hangar se monta
## después, y la ventana crecerá con él: tanto el marco como las pestañas son
## nine-patch, así que el arte sólo pone bordes y esquinas y la medida se
## decide aquí, no en el PNG.

signal closed

## Cómo se llama cada sección en la pestaña de arriba. El orden es el mismo que
## el de las solapas dentro de `SideTabs`.
@export var section_titles: PackedStringArray = ["HANGAR", "TROPAS", "MUNICIÓN"]

## Las dos caras de una solapa lateral. Van las dos por el inspector y no con un
## `preload` dentro del script: si sólo estuviera puesta la que se ve al
## arrancar, la escena mentiría sobre lo que va a dibujar el código.
@export var tab_idle: Texture2D
@export var tab_active: Texture2D

## Aire a cada lado del título dentro de su pestaña. La pestaña se estrecha o se
## ensancha con el texto —"MUNICIÓN" ocupa 7 px más que "HANGAR"—, así que su
## ancho se calcula midiendo la cadena y no se deja escrito en la escena.
const _TITLE_PADDING := 8.0

@onready var _top_tab: NinePatchRect = $TopTab
@onready var _title: Label = $TopTab/Title
@onready var _pages: Control = $Frame/Pages
@onready var _side_tabs: Control = $SideTabs

## El buque cuyo interior se está mirando. Todavía no lo usa nadie: lo guardará
## el hangar cuando exista, para saber a quién le pide los aviones.
var ship: Node2D = null

var _tabs: Array[TextureButton] = []
var _section: int = -1


func _ready() -> void:
	for child in _side_tabs.get_children():
		var tab := child as TextureButton
		if tab == null:
			continue
		var index := _tabs.size()
		tab.pressed.connect(func() -> void: show_section(index))
		_tabs.append(tab)
	show_section(0)
	hide()


func open(vessel: Node2D) -> void:
	ship = vessel
	show_section(0)
	show()
	move_to_front()


func close() -> void:
	hide()
	closed.emit()


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
	_fit_top_tab()
	for i in _pages.get_child_count():
		var page := _pages.get_child(i) as Control
		if page != null:
			page.visible = i == index


func _fit_top_tab() -> void:
	var font := _title.get_theme_font(&"font")
	var font_size := _title.get_theme_font_size(&"font_size")
	var text_width: float = font.get_string_size(
			_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_top_tab.size.x = roundf(text_width) + _TITLE_PADDING * 2.0
