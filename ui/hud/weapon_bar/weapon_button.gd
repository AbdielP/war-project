extends TextureButton
class_name WeaponButton

## Un arma de la barra: la cara del botón es arte, el icono va encima y la
## cantidad abajo a la derecha.
##
## **El icono no cabe y no tiene que caber.** Los dibujos de arma son verticales
## y llegan a 33 px; la cara del botón mide 32. Se centran sobre ella y se dejan
## desbordar por arriba y por abajo — recortarlos para que entren le quitaba la
## punta al AIM-120, y una silueta mutilada distingue peor que una que asoma.
##
## **La cantidad tampoco.** Va en M5X7 a 16 —a 8 sus cifras miden 4 px y no se
## leen— y `x300` ocupa 24 px de ancho, así que sobresale por la esquina. Lleva
## borde oscuro porque el HUD flota sobre el mapa: sin él, un número claro se
## pierde en cuanto la barra queda sobre el cielo.
##
## No sabe disparar ni elegir: avisa de que lo pulsaron y lo demás es de quien
## escuche.

signal picked(weapon: WeaponType)

## Cuánto se apaga un arma que no es la activa, y cuánto una agotada. La
## agotada va por debajo para que "no elegida" y "no queda" no se confundan.
const _DIM_ALPHA := 0.5
const _EMPTY_ALPHA := 0.25

## Munición ilimitada: el cañón no lleva cuenta y no se le escribe ninguna.
const _UNLIMITED := -1

@onready var _icon: TextureRect = $Icon
@onready var _count: Label = $Count

var weapon: WeaponType = null


func _ready() -> void:
	pressed.connect(func() -> void:
		if weapon != null:
			picked.emit(weapon))


## Qué arma representa. `left` es lo que queda, o -1 si no se cuenta.
func show_weapon(shown: WeaponType, left: int, active: bool) -> void:
	weapon = shown
	_icon.texture = shown.ui_icon
	tooltip_text = shown.display_name
	set_state(left, active)


## Repinta sin volver a montar: cambió el arma elegida o se gastó munición.
func set_state(left: int, active: bool) -> void:
	_count.text = "" if left == _UNLIMITED else "x%d" % left
	var empty := left == 0
	# Un arma agotada no se puede elegir: dejarla pulsable armaría un ataque
	# que no llegaría a salir nunca.
	disabled = empty
	var apagado := _EMPTY_ALPHA if empty else (1.0 if active else _DIM_ALPHA)
	# `self_modulate` y no `modulate`: el primero afecta sólo al dibujo del
	# propio nodo, el segundo arrastra a los hijos. Apagando el botón entero se
	# apagaba también la cantidad, y ese número es información — tiene que
	# leerse igual de bien en el arma que no está elegida que en la que sí.
	self_modulate = Color(1.0, 1.0, 1.0, apagado)
	_icon.modulate = Color(1.0, 1.0, 1.0, apagado)
