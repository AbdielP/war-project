extends TextureButton

## Congela la partida. Un solo botón que alterna, y **enseña la acción que hace,
## no el estado en que está**: corriendo se ve el icono de pausa (púlsame para
## pausar) y pausado se ve el de play (púlsame para seguir). Es lo que hace
## cualquier reproductor y lo que la gente espera; enseñar el estado obliga a
## pensar cuál de los dos significa qué.
##
## No hay cableado con nadie: `paused` es estado del árbol, no de otro nodo, así
## que no hay a quién pedírselo ni a quién avisar. Lo que tiene que seguir vivo
## con la partida congelada —HUD, cámara y selección— lo declara cada uno con su
## `process_mode`, que es donde se ve de un vistazo.

## Emitida al cambiar, por si algo quiere reaccionar (un aviso en el registro,
## un velo sobre la pantalla). Hoy no la escucha nadie.
signal pause_toggled(paused: bool)

## Los cuatro iconos van exportados y no en `preload`: el botón cambia de arte
## según el estado, así que las dos parejas tienen que poder cambiarse desde el
## inspector como cualquier otra textura de la escena. Con `preload` sólo se
## veía la que tocase en ese momento y no había forma de tocarlas sin editar
## código.
@export_group("Iconos")
@export var texture_pause: Texture2D
@export var texture_pause_held: Texture2D
@export var texture_play: Texture2D
@export var texture_play_held: Texture2D

## Tecla que hace lo mismo desde el teclado. `KEY_NONE` la desactiva. En PC se
## espera poder pausar sin ir al ratón; en táctil y mando manda el botón.
@export var shortcut_key: Key = KEY_SPACE


func _ready() -> void:
	pressed.connect(_toggle)
	_refresh()


## `_unhandled_key_input` y no el `shortcut` de `Button`: el atajo se maneja
## igual que el ESC de `SelectionManager`, sin inventar un recurso `Shortcut`
## para una sola tecla.
func _unhandled_key_input(event: InputEvent) -> void:
	if shortcut_key == KEY_NONE:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == shortcut_key:
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	var tree := get_tree()
	tree.paused = not tree.paused
	_refresh()
	pause_toggled.emit(tree.paused)


## Pausado, el botón enseña el icono de play; corriendo, el de pausa. La
## versión oscura de cada uno queda de `texture_pressed`, que Godot ya
## enseña solo mientras se mantiene el clic.
func _refresh() -> void:
	if get_tree().paused:
		texture_normal = texture_play
		texture_pressed = texture_play_held
	else:
		texture_normal = texture_pause
		texture_pressed = texture_pause_held
