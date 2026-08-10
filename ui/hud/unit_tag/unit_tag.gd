extends Node2D
class_name UnitTag

## La etiqueta que sale al seleccionar una unidad: una línea que se despliega y
## el nombre encima.
##
## **Vive en el HUD, no colgada de la unidad**, y ahí está todo el asunto. Una
## etiqueta colgada del avión es parte del mundo: la cámara la escala al hacer
## zoom, y a 0,5x el texto se vuelve ilegible mientras el resto del HUD se
## queda quieto. Lo que el jugador espera es lo contrario — que la etiqueta
## mida siempre lo mismo y sólo se mueva de sitio.
##
## Así que se hace al revés: la etiqueta se queda en la capa del HUD, en píxeles
## de pantalla, y cada frame se le pregunta a la unidad dónde cae ahora mismo
## (`get_global_transform_with_canvas()`, lo mismo que hace la cuenta atrás de
## impacto). El zoom mueve la etiqueta; no la deforma.
##
## No conoce ningún tipo de unidad concreto: le pasan una `Unit` y muestra su
## nombre. Sirve igual para un avión, un barco o un tanque.

@export_group("Entrada")
## Cuánto tarda la línea en desplegarse antes de que aparezca el nombre. El
## nombre entra cuando la línea ya casi terminó, como si la trajera ella.
@export var name_delay: float = 0.28
@export var name_fade_time: float = 0.25
## Desde cuántos píxeles más abajo entra el nombre, deslizándose hasta su sitio.
@export var name_rise_px: float = 4.0

@onready var _line: AnimatedSprite2D = $Line
@onready var _name: Label = $Name
## El dibujo de la unidad, ahí sólo para poder colocar la línea y el nombre a
## ojo contra algo real en vez de contra el vacío. Se apaga al empezar la
## partida: es una regla de carpintero, no parte del HUD. Misma treta que
## `MuzzleFlash`, que también se coloca a mano sobre el arte.
@onready var _editor_guide: Sprite2D = $EditorGuide

var _unit: Unit = null
var _tween: Tween = null
## Lo que le falta al nombre para llegar a su sitio durante la entrada. Va
## aparte de su sitio de reposo porque la posición real se reescribe cada frame
## siguiendo a la unidad: animar la posición directamente se pisaría con eso.
var _rise: float = 0.0
## Dónde quedaron colocados en la escena, respecto al centro de la unidad. **El
## ajuste fino se hace arrastrando los nodos en el editor**, no escribiendo
## números: se ven contra la guía y se guardan solos. Aquí sólo se recuerda esa
## colocación, porque a partir del primer frame la posición pasa a ser la de
## pantalla y se sobreescribe entera.
var _line_home: Vector2 = Vector2.ZERO
var _name_home: Vector2 = Vector2.ZERO


func _ready() -> void:
	_line_home = _line.position
	_name_home = _name.position
	_editor_guide.hide()
	hide()
	set_process(false)


## Engancha la etiqueta a una unidad y la despliega. Volver a llamarla con la
## misma unidad reinicia la animación: cada clic del jugador merece su
## respuesta, no un adorno que ya estaba puesto.
func show_for(unit: Unit) -> void:
	if not is_instance_valid(unit):
		clear()
		return
	_unit = unit
	_name.text = unit.get_display_name()
	# Colocada antes de mostrarse: si no, se dibuja un frame en el sitio de la
	# unidad anterior antes de que `_process` la corrija.
	_follow_unit()
	show()
	set_process(true)
	_line.play(&"deploy")
	_start_name_entrance()


func clear() -> void:
	_unit = null
	if _tween != null:
		_tween.kill()
		_tween = null
	hide()
	set_process(false)


## La unidad puede morir con la etiqueta puesta — un avión derribado mientras
## lo mirabas —, así que se comprueba aquí y no sólo al engancharla.
func _process(_delta: float) -> void:
	if not is_instance_valid(_unit):
		clear()
		return
	_follow_unit()


func _follow_unit() -> void:
	var on_screen: Vector2 = _unit.get_global_transform_with_canvas().origin
	_line.position = on_screen + _line_home
	_name.position = on_screen + _name_home + Vector2(0.0, _rise)


func _start_name_entrance() -> void:
	_name.modulate.a = 0.0
	_rise = name_rise_px
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_name, ^"modulate:a", 1.0, name_fade_time).set_delay(name_delay)
	_tween.tween_method(_set_rise, name_rise_px, 0.0, name_fade_time + 0.05) \
		.set_delay(name_delay)


func _set_rise(value: float) -> void:
	_rise = value
