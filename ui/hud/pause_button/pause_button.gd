extends Button

## Congela la partida. Un solo botón que alterna, y **enseña la acción que hace,
## no el estado en que está**: corriendo se ve `||` (púlsame para pausar) y
## pausado se ve `>` (púlsame para seguir). Es lo que hace cualquier reproductor
## y lo que la gente espera; enseñar el estado obliga a pensar cuál de los dos
## significa qué.
##
## No hay cableado con nadie: `paused` es estado del árbol, no de otro nodo, así
## que no hay a quién pedírselo ni a quién avisar. Lo que tiene que seguir vivo
## con la partida congelada —HUD, cámara y selección— lo declara cada uno con su
## `process_mode`, que es donde se ve de un vistazo.

## Emitida al cambiar, por si algo quiere reaccionar (un aviso en el registro,
## un velo sobre la pantalla). Hoy no la escucha nadie.
signal pause_toggled(paused: bool)

const _COLOR_TEXT   := Color(0.6705882, 0.5803922, 0.4784314)
const _COLOR_ACCENT := Color(0.56078434, 0.827451, 1.0)
const _COLOR_BG     := Color(0.19215686, 0.21176471, 0.21960784)

const _LABEL_RUNNING := "||"
const _LABEL_PAUSED := ">"

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


## Pausado, el botón se pinta en color de acento: con la partida congelada no
## hay movimiento en pantalla que delate el estado, así que tiene que decirlo él.
func _refresh() -> void:
	var paused := get_tree().paused
	text = _LABEL_PAUSED if paused else _LABEL_RUNNING
	var fg := _COLOR_ACCENT if paused else _COLOR_TEXT
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = _COLOR_BG
		box.set_border_width_all(1)
		box.border_color = Color(_COLOR_ACCENT, 1.0 if paused else 0.6)
		box.set_content_margin_all(0)
		add_theme_stylebox_override(state, box)
	add_theme_color_override("font_color", fg)
	add_theme_color_override("font_hover_color", _COLOR_ACCENT)
	add_theme_color_override("font_pressed_color", _COLOR_ACCENT)
