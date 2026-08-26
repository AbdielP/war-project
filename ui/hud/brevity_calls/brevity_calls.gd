@tool
extends Node2D
class_name BrevityCalls

## Las llamadas de radio que salen sobre un avión al disparar: `Fox Three!`,
## `Rifle!`, `Pickle!`.
##
## Sale sobre **cualquier unidad propia**, esté seleccionada o no. Es la
## diferencia con [UnitTag], que acompaña a una sola: aquí lo interesante es
## justamente enterarte de lo que hacen los aviones que no estás mirando.
##
## Vive en el HUD y en píxeles de pantalla, por lo mismo que la etiqueta: colgado
## de la unidad, la cámara lo escalaría y a 0,5x sería ilegible. Cada frame se le
## pregunta a la unidad dónde cae ahora (`get_global_transform_with_canvas()`).
##
## Se engancha él solo a las unidades según aparecen, igual que el parte de
## eventos: nadie tiene que acordarse de avisarle.
##
## **El código sale del arma** (`brevity_code`), no está escrito aquí. Un arma
## nueva trae su llamada puesta.
##
## Y la frase también (`radio_call`), para las armas que no tienen llamada propia
## de radio: el cañón y los cohetes. Su código —`Guns`, `Rockets`— es lo que el
## parte de eventos escribe entre paréntesis, pero cantado encima del aparato se
## dice entero. El mismo dato en dos sitios distintos, no dos datos.

## Cuánto se ve entera antes de empezar a irse.
@export var hold_time: float = 1.8
## Y cuánto tarda en desvanecerse.
@export var fade_time: float = 1.0
## Desde cuántos píxeles más abajo entra, deslizándose hasta su sitio. Igual que
## el nombre en [UnitTag], para que las dos cosas se muevan parecido.
@export var rise_px: float = 3.0
## Dónde sale respecto al centro de la unidad, en píxeles de pantalla. **Debajo
## del nombre**, que está en `(30, −43)`.
@export var offset: Vector2 = Vector2(30, -28)

@export_group("Texto")
@export var font: Font
@export_range(6, 32, 1) var font_size: int = 16
@export var color: Color = Color(1.0, 0.85, 0.4)
@export_group("Agrupado")
## Dos disparos del mismo avión y la misma arma dentro de esta ventana cuentan
## como uno. Es lo que hace que una ristra de seis Mk-82 cante **un** `Pickle!`
## y no seis encima del mismo avión.
@export var same_call_window: float = 2.8
## Y la de un arma de chorro continuo, que es mucho más larga.
##
## Un cañón no dispara una vez: **sigue disparando**, cortado en ráfagas. Con la
## ventana corta, cada ráfaga que cae fuera de ella saca otro cartel, y un
## helicóptero parado tirándole a algo los sacaba para siempre. La ventana tiene
## que ser más larga que el hueco entre ráfagas para que la andanada entera
## cuente como una sola cosa, que es lo que es.
@export var sustained_call_window: float = 6.0

## Lo dicho hace poco, para no repetirlo: `"idUnidad:arma" -> cuándo`.
var _said: Dictionary = {}


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	get_tree().node_added.connect(_watch)
	# Diferido por lo mismo que en el parte de eventos: en `_ready()` sólo
	# existen las unidades que van antes que el HUD en la escena.
	_sweep.call_deferred()


func _sweep() -> void:
	for node in get_tree().get_nodes_in_group(Unit.GROUP):
		_watch(node)


func _watch(node: Node) -> void:
	var unit := node as Unit
	if unit == null or unit.ammo_changed.is_connected(_on_ammo_changed):
		return
	unit.ammo_changed.connect(_on_ammo_changed.bind(unit))
	# El cañón no gasta munición contada, así que no pasa por `ammo_changed`:
	# hay que escuchar cuándo abre fuego.
	for child in unit.get_children():
		var weapons := child as WeaponSystem
		if weapons != null:
			weapons.firing_started.connect(_on_firing_started.bind(unit))


## Soltó un arma de las que se cuentan: misil o bomba.
func _on_ammo_changed(weapon: WeaponType, _remaining: int, unit: Unit) -> void:
	_call_out(unit, weapon)


## Abrió fuego con un arma sostenida. Se pregunta cuál es en el momento porque
## esta señal no la lleva: el sistema de armas avisa de que sale fuego, no de con
## qué — los efectos que la escuchan tampoco lo necesitan.
func _on_firing_started(unit: Unit) -> void:
	_call_out(unit, unit.active_weapon)


func _call_out(unit: Unit, weapon: WeaponType) -> void:
	if weapon == null or not unit.is_player_controlled():
		return
	if weapon.brevity_code == "":
		return
	if not _is_new_call(unit, weapon):
		return
	# Un avión canta de una en una. La ventana de agrupado sólo tapa repeticiones
	# **de la misma arma**; cambiar de arma —soltar un misil y acto seguido abrir
	# con el cañón— sacaría dos carteles en el mismo sitio, uno encima del otro.
	_hush(unit)
	add_child(_make_label(unit, _text_for(weapon)))


## Retira la llamada que ese avión tuviera en el aire. No se borra de golpe: se
## la manda a desvanecerse, así que la nueva entra mientras la vieja se va en vez
## de haber un parpadeo.
func _hush(unit: Unit) -> void:
	for child in get_children():
		var call := child as BrevityCall
		if call != null and call.belongs_to(unit):
			call.dismiss()


## ¿Es una llamada nueva, o la misma andanada cantando otra vez? Una ristra de
## bombas gasta munición seis veces en medio segundo y sería seis carteles
## encima del mismo avión.
func _is_new_call(unit: Unit, weapon: WeaponType) -> bool:
	var key := "%d:%d" % [unit.get_instance_id(), weapon.get_instance_id()]
	var now := Time.get_ticks_msec() / 1000.0
	var window := sustained_call_window \
		if weapon.fire_mode == WeaponType.FireMode.SUSTAINED \
		else same_call_window
	var recent: bool = _said.has(key) and now - float(_said[key]) < window
	# La hora se apunta **también cuando no se canta**, y ahí está la diferencia
	# entre "hace mucho que no lo digo" y "hace mucho que no pasa". Sin esto, un
	# cañón que no para de tirar volvía a cantar cada vez que se cumplía la
	# ventana: la cuenta arrancaba en la última llamada en vez de en el último
	# disparo. Así la andanada calla mientras dure, y vuelve a cantar cuando de
	# verdad se ha estado callado.
	_said[key] = now
	return not recent


## Lo que sale escrito. La frase del arma si la trae y su código si no: el código
## siempre existe, la frase sólo en las armas que no tienen llamada de radio.
func _text_for(weapon: WeaponType) -> String:
	var said := weapon.radio_call if weapon.radio_call != "" else weapon.brevity_code
	return "%s!" % said


## Cada llamada es un `Label` suyo que nace, sigue a la unidad y se borra solo.
## Sueltos y no uno reutilizado porque pueden coincidir varios a la vez — dos
## aviones disparando, o el mismo soltando cosas distintas.
func _make_label(unit: Unit, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	if font != null:
		label.add_theme_font_override("font", font)
	label.set_script(preload("res://ui/hud/brevity_calls/brevity_call.gd"))
	label.call(&"follow", unit, offset, hold_time, fade_time, rise_px)
	return label
