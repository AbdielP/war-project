extends TextureRect

## La caja de la unidad seleccionada: miniatura arriba, nombre abajo.
##
## Hoy sólo pone el nombre. El hueco de arriba (`Thumbnail`) está reservado y
## vacío a propósito — es donde irá la vista en vivo de la unidad, y existe ya
## como nodo para poder colocarlo en el editor antes de que tenga contenido.
##
## `mouse_filter` en `IGNORE` en los tres nodos: la caja flota sobre el mapa y
## sin eso se comería los clics de sus 97×68 px, tenga dibujo o no. Es la misma
## trampa que costó las órdenes bajo el registro de eventos.

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

@onready var _name: Label = $Name

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


func show_unit(unit_name: String) -> void:
	_name.text = unit_name
	_fit(unit_name)
	show()


func clear() -> void:
	hide()


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
