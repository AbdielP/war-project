extends Button
class_name LoadoutOption

## Uno de los armamentos entre los que elige el jugador antes de despegar.
##
## Sólo sabe enseñarse encendido o apagado; quién está elegido lo lleva la
## página, que es la única que puede saber que elegir uno apaga a los demás.

## Las dos caras del botón. Van las dos por el inspector y no con un `preload`
## dentro del script: si sólo estuviera puesta la que se ve al arrancar, la
## escena mentiría sobre lo que va a dibujar el código.
@export var art_idle: StyleBox
@export var art_selected: StyleBox

## El texto también cambia, no sólo el marco: el elegido va en blanco y el resto
## en el gris azulado de la solapa que no manda. Ese color ya significa "esto
## está ahí pero no es lo que estás mirando" en esta ventana, así que apagar la
## letra dice lo mismo que apagar el borde y no hay que fijarse para verlo.
@export var text_idle: Color = Color(0.60784316, 0.67058825, 0.69803923)
@export var text_selected: Color = Color(1.0, 1.0, 1.0)


func set_selected(on: bool) -> void:
	var art: StyleBox = art_selected if on else art_idle
	var color: Color = text_selected if on else text_idle
	for state in [&"normal", &"hover", &"pressed", &"focus"]:
		add_theme_stylebox_override(state, art)
	for slot in [&"font_color", &"font_hover_color", &"font_pressed_color"]:
		add_theme_color_override(slot, color)
