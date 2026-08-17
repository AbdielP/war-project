extends Control

## Barra de armas de la unidad seleccionada: un botón por arma disponible, para
## elegir con cuál se ataca. El cañón va siempre.
##
## Los botones **son una escena** ([constant BUTTON]) y no nodos fabricados
## aquí: la cara es arte, el icono se sale del botón a propósito y la cantidad
## asoma por la esquina, y nada de eso se ajusta a ojo sin verlo en el editor.
##
## Cada botón enseña **el dibujo del arma, no su nombre**. La designación se
## queda en el tooltip: `AGM-65` pedía 27 px de texto dentro de 30 útiles y ya
## había obligado a bajar la fuente a 7, que es donde las mayúsculas dejan de
## distinguirse. Una silueta se reconoce sin leerla.
##
## Detrás va la bandeja ([member _tray]), que es lo que hace que los botones se
## vean apoyados en algo en vez de flotando sobre el mar.
##
## Sólo muestra y elige. Quién dispara y qué pasa al disparar no es asunto
## suyo — emite `weapon_selected` y se olvida.

signal weapon_selected(weapon: WeaponType)

const BUTTON := preload("res://ui/hud/weapon_bar/weapon_button.tscn")

## Munición ilimitada (el cañón): no se muestra número.
const _UNLIMITED := -1

## Cuánta bandeja asoma a cada lado de la fila. Es el mismo aire que hay entre
## dos botones, así que el borde no se lee como un hueco de otro tamaño.
const _TRAY_MARGIN := 6.0

## La bandeja de fondo. **Se dimensiona a los botones que haya**, y por eso se
## hace aquí y no se deja puesta en el editor: una unidad con dos armas y otra
## con cinco necesitan bandejas distintas. Da igual que quede más ancha o más
## estrecha entre unidades porque desaparece al deseleccionar — nunca se ven dos
## seguidas para comparar.
##
## Es un nine-patch: las dos tapas se copian tal cual y el tramo de en medio se
## repite en mosaico, así que crece a lo ancho y a lo alto sin deformarse. Baja
## hasta el borde inferior de la pantalla, que es donde el dibujo se corta — no
## tiene borde de abajo porque no se le ve.
@onready var _tray: NinePatchRect = $Tray
@onready var _row: HBoxContainer = $Row

var _unit: Unit = null
var _buttons: Dictionary = {}  # WeaponType -> WeaponButton


func show_weapons(unit: Unit) -> void:
	_clear_buttons()
	_unit = unit
	if unit == null:
		hide()
		return
	var weapons := unit.get_weapons()
	for weapon in weapons:
		var btn: WeaponButton = BUTTON.instantiate()
		_row.add_child(btn)
		btn.picked.connect(func(w: WeaponType) -> void: weapon_selected.emit(w))
		btn.show_weapon(weapon, _ammo_of(weapon), weapon == unit.active_weapon)
		_buttons[weapon] = btn
	_fit_tray(weapons.size())
	visible = not weapons.is_empty()


func clear() -> void:
	_clear_buttons()
	_unit = null
	hide()


## Repinta sin reconstruir: la unidad cambió de arma activa por su cuenta.
func set_active(weapon: WeaponType) -> void:
	_refresh(weapon)


## Se gastó munición. Sólo cambia el arma afectada, pero repintar la barra
## entera cuesta lo mismo y evita que se desincronice.
func refresh_ammo() -> void:
	if _unit != null:
		_refresh(_unit.active_weapon)


## Estira la bandeja hasta cubrir la fila y la centra bajo ella.
##
## Se calcula en vez de preguntarle su tamaño al contenedor porque el
## `HBoxContainer` no lo tiene hecho hasta el siguiente frame, y esperar dejaría
## la bandeja de la unidad anterior visible durante uno.
func _fit_tray(count: int) -> void:
	if count < 1:
		_tray.hide()
		return
	# El ancho del botón se le pregunta a uno de verdad, no se escribe aquí:
	# cambiar el arte del botón en su escena tiene que bastar.
	var button: Control = _row.get_child(0)
	var gap: float = _row.get_theme_constant(&"separation")
	var row_width := count * button.custom_minimum_size.x + (count - 1) * gap
	_tray.size.x = row_width + _TRAY_MARGIN * 2.0
	_tray.position.x = roundf((size.x - _tray.size.x) * 0.5)
	_tray.show()


func _refresh(active: WeaponType) -> void:
	for weapon: WeaponType in _buttons:
		var btn: WeaponButton = _buttons[weapon]
		btn.set_state(_ammo_of(weapon), weapon == active)


func _ammo_of(weapon: WeaponType) -> int:
	return _unit.get_ammo(weapon) if _unit != null else _UNLIMITED


func _clear_buttons() -> void:
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	_buttons.clear()
