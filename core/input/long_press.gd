extends RefCounted
class_name LongPress

## Detector de pulsación mantenida sin arrastrar: el equivalente táctil del
## click derecho, porque en móvil no hay segundo botón.
##
## No conoce eventos ni nodos — se le van contando las cosas que pasan y él
## responde qué significan. Así lo usan igual la cámara, que trabaja en
## coordenadas de pantalla dentro de `_unhandled_input`, y una vista de UI, que
## trabaja en locales dentro de `_gui_input`.

## Cuánto hay que aguantar para que cuente como mantenida.
var hold_time: float = 0.5
## A partir de cuánto movimiento deja de ser una pulsación y pasa a ser arrastre.
var move_threshold_px: float = 6.0

var _pressed: bool = false
var _dragging: bool = false
var _fired: bool = false
var _elapsed: float = 0.0
var _origin: Vector2 = Vector2.ZERO


func press(position: Vector2) -> void:
	_pressed = true
	_dragging = false
	_fired = false
	_elapsed = 0.0
	_origin = position


## Devuelve `true` la primera vez que el movimiento pasa de umbral, para que
## quien lo use pueda reaccionar al comienzo del arrastre.
func moved(position: Vector2) -> bool:
	if not _pressed or _dragging:
		return false
	if position.distance_to(_origin) < move_threshold_px:
		return false
	_dragging = true
	return true


## `true` si soltar cuenta como click limpio. No lo es si se arrastró, ni si ya
## se atendió como mantenida: entonces el menú se abriría y acto seguido llegaría
## la orden.
func release() -> bool:
	var was_click := _pressed and not _dragging and not _fired
	_pressed = false
	return was_click


## `true` exactamente una vez, al cumplirse el tiempo. Se dispara **sin soltar**,
## como en cualquier menú contextual táctil: el aviso llega mientras el dedo
## sigue apoyado.
func tick(delta: float) -> bool:
	if not _pressed or _dragging or _fired:
		return false
	_elapsed += delta
	if _elapsed < hold_time:
		return false
	_fired = true
	return true


func origin() -> Vector2:
	return _origin


func is_pressed() -> bool:
	return _pressed


func is_dragging() -> bool:
	return _dragging
