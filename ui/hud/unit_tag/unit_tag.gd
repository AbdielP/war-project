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

## Pulsaron "A bordo": hay que abrir el interior de esa unidad. La etiqueta no
## sabe qué hay dentro ni quién lo enseña — avisa y ya.
signal boarding_requested(unit: Unit)

@export_group("Entrada")
## Cuánto tarda la línea en desplegarse antes de que aparezca el nombre. El
## nombre entra cuando la línea ya casi terminó, como si la trajera ella.
@export var name_delay: float = 0.28
@export var name_fade_time: float = 0.25
## Desde cuántos píxeles más abajo entra el nombre, deslizándose hasta su sitio.
@export var name_rise_px: float = 4.0
## A qué ritmo se sigue alargando la línea cuando la animación dibujada se
## acaba, en píxeles por segundo. **Sale de medir la tira**: el trazo avanza
## 4 px por fotograma y la animación corre a 24, o sea 96 px/s. Es el mismo
## ritmo al que venía creciendo, y por eso el empalme no se ve. Cambiarlo lo
## delata.
@export var line_speed_px: float = 96.0

@export_group("Estado")
## De dónde salen las coordenadas del destino. Apunta al [MapView] del **mapa
## táctico**, igual que el parte de eventos: el del minimapa agrupa las zonas
## hasta caber en 87 px y diría lo mismo de medio mapa.
@export var map_path: NodePath
@export var status_idle: String = "En espera"
@export var status_moving: String = "Moviéndose a "
@export var status_attacking: String = "Atacando a "

@onready var _line: AnimatedSprite2D = $Line
## La prolongación de la línea, que es lo que la hace llegar hasta el final del
## nombre. **No es la animación estirada**: la tira dibujada acaba a los 36 px y
## de sus 36 sólo los 10 primeros son dibujo —la diagonal—; las 26 columnas
## restantes son idénticas entre sí. Así que este trozo repite una de esas
## columnas tantas veces como haga falta (`axis_stretch_horizontal` en modo
## mosaico) y el resultado es píxel por píxel el mismo trazo, mida lo que mida.
## Estirar la textura habría engordado el trazo de 1 px a 3 en cuanto el nombre
## fuera largo.
##
## Cuelga de `Line` a propósito: así se coloca respecto a ella en el editor y
## seguirla cada frame es gratis.
@onready var _tail: NinePatchRect = $Line/Tail
@onready var _name: Label = $Name
## El rótulo fijo. Su texto —"Status:"— se edita en la escena como cualquier
## otro, porque es un letrero, no un dato.
@onready var _status: Label = $Status
## Lo que cambia. Cuelga del rótulo, así que se coloca **respecto a él**: mover
## el "Status:" se lleva el valor detrás sin tocar nada más.
@onready var _status_value: Label = $Status/Value
## La puerta al interior del buque —hangar, pañol, tropas—. Sale **sólo en las
## unidades que lo tienen** ([member UnitType.has_interior]) y sólo si son del
## jugador: al enemigo se le mira, no se le abre la bodega.
@onready var _boarding: Button = $Boarding
@onready var _boarding_icon: TextureRect = $Boarding/Icon
@onready var _boarding_label: Label = $Boarding/Label
## El dibujo de la unidad, ahí sólo para poder colocar la línea y el nombre a
## ojo contra algo real en vez de contra el vacío. Se apaga al empezar la
## partida: es una regla de carpintero, no parte del HUD. Misma treta que
## `MuzzleFlash`, que también se coloca a mano sobre el arte.
@onready var _editor_guide: Sprite2D = $EditorGuide

## El ancla en reposo: blanca, a juego con el texto. `StyleBoxTexture` ya
## cambia solo el fondo del botón al presionar; el ícono y el color del texto
## no vienen gratis con eso y hay que apagarlos a mano en
## [method _set_boarding_pressed].
const _ICON_ANCHOR := preload("res://ui/hud/unit_tag/board_anchor.png")
## Versión apagada, para cuando el botón está presionado.
const _ICON_ANCHOR_PRESSED := preload("res://ui/hud/unit_tag/board_anchor_pressed.png")
const _LABEL_COLOR := Color(1, 1, 1, 1)
## El mismo tono apagado que el ícono presionado, para que el texto cambie
## junto con él y no se lea como dos cosas por separado.
const _LABEL_COLOR_PRESSED := Color(0.78039217, 0.8627451, 0.8156863, 1)

var _unit: Unit = null
var _tween: Tween = null
## El del alargamiento va aparte del de la entrada del nombre: duran cosas
## distintas —uno depende de lo largo que sea el nombre— y reiniciar la etiqueta
## tiene que poder cortar los dos.
var _line_tween: Tween = null
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
var _status_home: Vector2 = Vector2.ZERO
var _boarding_home: Vector2 = Vector2.ZERO
## Lo que la unidad mirada añade a esas colocaciones. Ver
## [member UnitType.tag_offset]: la etiqueta está puesta contra un avión y sobre
## un buque de 160 px de manga caería dentro del casco.
var _offset: Vector2 = Vector2.ZERO
var _map: MapView = null


func _ready() -> void:
	_line_home = _line.position
	_name_home = _name.position
	_status_home = _status.position
	_boarding_home = _boarding.position
	_boarding.pressed.connect(func() -> void:
		if is_instance_valid(_unit):
			boarding_requested.emit(_unit))
	_boarding.button_down.connect(_set_boarding_pressed.bind(true))
	_boarding.button_up.connect(_set_boarding_pressed.bind(false))
	_map = get_node_or_null(map_path) as MapView
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
	_offset = unit.unit_type.tag_offset if unit.unit_type != null else Vector2.ZERO
	_boarding.visible = unit.is_player_controlled() \
			and unit.unit_type != null and unit.unit_type.has_interior
	# Colocada antes de mostrarse: si no, se dibuja un frame en el sitio de la
	# unidad anterior antes de que `_process` la corrija.
	_follow_unit()
	show()
	set_process(true)
	_line.play(&"deploy")
	_grow_line()
	_start_name_entrance()


func clear() -> void:
	_unit = null
	if _tween != null:
		_tween.kill()
		_tween = null
	if _line_tween != null:
		_line_tween.kill()
		_line_tween = null
	hide()
	set_process(false)


## Ancla y texto se apagan juntos al presionar, como si fueran una sola pieza
## — no el fondo solo, que ya cambia por su cuenta vía StyleBox.
func _set_boarding_pressed(pressed: bool) -> void:
	_boarding_icon.texture = _ICON_ANCHOR_PRESSED if pressed else _ICON_ANCHOR
	_boarding_label.add_theme_color_override(
			&"font_color", _LABEL_COLOR_PRESSED if pressed else _LABEL_COLOR)


## Alarga la línea hasta el final del nombre, arrancando justo cuando la
## animación dibujada se queda sin fotogramas.
##
## El retraso y la velocidad **no son números escritos a mano**: la espera es lo
## que dura la propia animación —fotogramas partidos por su velocidad—, así que
## retocar la tira o su ritmo en el editor no deja esto desincronizado.
func _grow_line() -> void:
	if _line_tween != null:
		_line_tween.kill()
	_tail.size.x = 0.0
	var frames := _line.sprite_frames
	var drawn: float = frames.get_frame_texture(&"deploy", 0).get_width()
	var falta := _line_length() - drawn
	if falta <= 0.0:
		return
	var deploy := frames.get_frame_count(&"deploy") / frames.get_animation_speed(&"deploy")
	_line_tween = create_tween()
	_line_tween.tween_method(_set_tail, 0.0, falta, falta / line_speed_px) \
		.set_delay(deploy)


## El ancho se redondea a píxel entero: el trozo repetido se corta por donde
## acabe, y a media unidad deja una columna a medias que en pixel art se ve como
## suciedad en la punta.
func _set_tail(width: float) -> void:
	_tail.size.x = roundf(width)


## Hasta dónde tiene que llegar la línea, contando desde donde empieza: hasta
## el final del nombre.
##
## Se mide contra **dónde están puestos los nodos en la escena** y contra el
## texto real, no contra números escritos aquí. Mover el nombre o cambiar la
## fuente en el editor sigue dando la medida correcta, y cada unidad se lleva la
## línea que le corresponde — el `2S6` una corta y el `AH-1W SuperCobra` una
## larga.
func _line_length() -> float:
	var font := _name.get_theme_font(&"font")
	var size := _name.get_theme_font_size(&"font_size")
	var text_width := font.get_string_size(
			_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	return (_name_home.x - _line_home.x) + text_width


## La unidad puede morir con la etiqueta puesta — un avión derribado mientras
## lo mirabas —, así que se comprueba aquí y no sólo al engancharla.
func _process(_delta: float) -> void:
	if not is_instance_valid(_unit):
		clear()
		return
	_follow_unit()
	_status_value.text = _status_text()


func _follow_unit() -> void:
	var on_screen: Vector2 = _unit.get_global_transform_with_canvas().origin + _offset
	_line.position = on_screen + _line_home
	_name.position = on_screen + _name_home + Vector2(0.0, _rise)
	_status.position = on_screen + _status_home + Vector2(0.0, _rise)
	# El botón no sube con el resto: el nombre y el estado se deslizan al entrar,
	# pero un botón que se mueve mientras aparece se pulsa mal.
	_boarding.position = on_screen + _boarding_home


## En qué anda metida la unidad, en una línea.
##
## **Se compone aquí y no en la unidad**: ella expone hechos —a quién ataca, a
## dónde va— y el HUD los pone en palabras. Así el mismo dato vale para el parte
## de eventos, que los cuenta distinto.
##
## El orden importa: atacar manda sobre moverse, porque un avión que ataca
## también se está moviendo y lo que el jugador quiere saber es lo primero.
func _status_text() -> String:
	if is_instance_valid(_unit.attack_target):
		return status_attacking + _unit.attack_target.get_display_name()
	var going: Variant = _unit.get_move_destination()
	if going != null:
		return status_moving + _zone_of(going)
	return status_idle


## La coordenada del mapa, o el punto en crudo si todavía no hay mapa que la
## traduzca. Mejor decir dónde de forma fea que no decirlo.
func _zone_of(world: Vector2) -> String:
	if _map == null:
		return "%d, %d" % [world.x, world.y]
	var label := _map.zone_label_at(world)
	return label if label != "" else "%d, %d" % [world.x, world.y]


func _start_name_entrance() -> void:
	_name.modulate.a = 0.0
	# El estado y el botón entran con el nombre, no por su cuenta: son la misma
	# etiqueta y verlos aparecer por separado se leería como cosas distintas.
	_status.modulate.a = 0.0
	_boarding.modulate.a = 0.0
	_status_value.text = _status_text()
	_rise = name_rise_px
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_name, ^"modulate:a", 1.0, name_fade_time).set_delay(name_delay)
	_tween.tween_property(_status, ^"modulate:a", 1.0, name_fade_time).set_delay(name_delay)
	_tween.tween_property(_boarding, ^"modulate:a", 1.0, name_fade_time).set_delay(name_delay)
	_tween.tween_method(_set_rise, name_rise_px, 0.0, name_fade_time + 0.05) \
		.set_delay(name_delay)


func _set_rise(value: float) -> void:
	_rise = value
