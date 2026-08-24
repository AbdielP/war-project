extends Control
class_name WeaponCard

## Un arma del armamento elegido: qué es, cómo se llama y cuántas van.
##
## El texto sale **partido del nombre completo del arma**, no de dos campos
## sueltos: "AIM-120 AMRAAM" da designación arriba y nombre abajo. Así un arma
## nueva se presenta sola el día que exista, sin que nadie tenga que acordarse de
## rellenar aquí nada — y las dos líneas no pueden discrepar entre sí porque son
## la misma cadena.

@onready var _icon: TextureRect = $Icon
@onready var _designation: Label = $Designation
@onready var _name: Label = $Name
@onready var _count: Label = $Count


## `count` de 0 esconde la cuenta en vez de escribir "x0": esta ficha sale antes
## de despegar, cuando el avión va cargado del todo, así que un cero aquí no es
## "se acabó" sino "esto no se cuenta" — el cañón de un aparato sin munición
## definida, por ejemplo.
func show_weapon(weapon: WeaponType, count: int) -> void:
	if weapon == null:
		hide()
		return
	show()
	_icon.texture = weapon.ui_icon
	var parts := _split_name(weapon.display_name)
	_designation.text = parts[0]
	_name.text = parts[1]
	# La equis va en mayúscula porque la fuente **no tiene minúsculas**: con "x300"
	# el multiplicador desaparecía y quedaba un "300" suelto sin decir de qué.
	_count.text = "X%d" % count if count > 0 else ""


## Parte el nombre en designación y modelo por el primer espacio: lo de delante
## es lo que identifica al arma —"AIM-120", "Mk-82"— y lo de detrás cómo se
## llama. En mayúsculas porque la fuente no tiene minúsculas y un glifo que falta
## se lo pide Godot al sistema, rompiendo el alto del renglón entero.
func _split_name(full: String) -> PackedStringArray:
	var clean := full.strip_edges().to_upper()
	var cut := clean.find(" ")
	if cut < 0:
		return PackedStringArray([clean, ""])
	return PackedStringArray([clean.substr(0, cut), clean.substr(cut + 1)])
