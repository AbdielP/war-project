extends Screen

## El logo del estudio. Se salta con cualquier cosa **desde el primer frame**:
## un splash que no se puede saltar es lo primero que molesta a quien ya vio el
## juego una vez.
##
## Durante el desarrollo no se ve nunca — el arranque salta directo a donde
## estés trabajando. Ver [DevBoot].

## Cuánto se queda si nadie toca nada.
@export var hold: float = 2.2
## El logo, para cuando lo dibujes. Vacío enseña sólo el título, que es lo que
## hay hoy: mejor un hueco honesto que un dibujo de relleno que parezca
## definitivo.
@export var logo: Texture2D

@onready var _logo: TextureRect = $Logo

var _left: float = 0.0
var _leaving: bool = false


func enter() -> void:
	_left = hold
	_logo.texture = logo
	_logo.visible = logo != null


func _process(delta: float) -> void:
	if _leaving:
		return
	_left -= delta
	if _left <= 0.0:
		_advance()


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		_advance()
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed:
		_advance()
		return
	var touch := event as InputEventScreenTouch
	if touch != null and touch.pressed:
		_advance()


func _advance() -> void:
	_leaving = true
	Screens.go_to(Screens.Id.MAIN_MENU)
