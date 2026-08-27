extends Node

## La misión, envuelta para que la carcasa pueda tratarla como una pantalla más.
## La escena de juego de dentro **no sabe nada de esto** y se sigue abriendo
## sola con F6 igual que siempre.
##
## No hereda de [Screen] porque el juego es un [Node2D] y las pantallas son
## [Control]. Lo único que la carcasa le pide a un inquilino es existir.

## Salida provisional. Mientras no haya condiciones de victoria hace falta
## alguna forma de llegar al debriefing para poder recorrer el juego entero.
## **Esto se va el día que la misión sepa terminarse sola** — no es una tecla de
## diseño, es un andamio.
@export var debug_end_key: Key = KEY_F10


func _unhandled_key_input(event: InputEvent) -> void:
	if debug_end_key == KEY_NONE:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != debug_end_key:
		return
	get_viewport().set_input_as_handled()
	# Salir con la partida congelada dejaría el árbol pausado y el menú muerto:
	# `paused` es estado del árbol, no de la misión.
	get_tree().paused = false
	Screens.go_to(Screens.Id.DEBRIEFING, {"won": true, "reward": 0})
