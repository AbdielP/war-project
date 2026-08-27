extends Screen

## El puerto base de la campaña: donde vuelves entre misión y misión. Al menú
## principal se entra una vez; aquí es donde se vive.
##
## Es el único sitio desde el que se guarda, y eso no es una decisión de la
## interfaz sino la forma del guardado: se guarda **entre** misiones, con la
## campaña quieta. Ver [Campaign].

## Las misiones de la campaña. Provisional: el día que exista un recurso de
## misión, esta lista sale de ahí y no de un texto escrito a mano.
@export var missions: PackedStringArray = [
	"01   GOLFO DE ADEN",
	"02   ESTRECHO",
	"03   DESEMBARCO",
]

@onready var _list: VBoxContainer = $Panel/List
@onready var _funds: Label = $Funds
@onready var _port: Button = $Buttons/Port
@onready var _start: Button = $Buttons/Start
@onready var _save: Button = $Buttons/Save
@onready var _exit: Button = $Buttons/Exit
## La fila de muestra. Vive puesta en la escena para poder colocarla en el
## editor y la apaga el código: un nodo que nace oculto es un rectángulo
## invisible que no se puede ajustar.
@onready var _row: Label = $Panel/List/Row

const _DONE := Color(0.56078434, 0.827451, 1.0)
const _NEXT := Color(0.9019608, 0.9019608, 0.9019608)
const _LOCKED := Color(0.6705882, 0.5803922, 0.4784314, 0.35)


func enter() -> void:
	_port.pressed.connect(func() -> void: Screens.push(Screens.Id.PORT))
	_start.pressed.connect(_on_start)
	_save.pressed.connect(_on_save)
	_exit.pressed.connect(func() -> void: Screens.go_to(Screens.Id.MAIN_MENU))
	Campaign.changed.connect(_refresh)
	_refresh()


func _on_start() -> void:
	Screens.go_to(Screens.Id.BRIEFING, {"mission": Campaign.progress})


func _on_save() -> void:
	# El aviso se da en el propio botón y no en un cartel aparte: es la única
	# acción de esta pantalla que no lleva a ningún sitio, así que sin respuesta
	# no se sabe si hizo algo.
	_save.text = "GUARDADO" if Campaign.save() else "ERROR"
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(_save):
		_save.text = "GUARDAR"


func _refresh() -> void:
	_funds.text = "FONDOS  %d" % Campaign.money
	_start.disabled = Campaign.progress >= missions.size()
	# `remove_child` antes de `queue_free`: el segundo sólo desengancha al final
	# del fotograma, y hasta entonces el contenedor reparte entre las filas
	# viejas y las nuevas a la vez.
	for child in _list.get_children():
		if child == _row:
			continue
		_list.remove_child(child)
		child.queue_free()
	_row.hide()
	for i in missions.size():
		var row: Label = _row.duplicate()
		row.text = missions[i]
		row.add_theme_color_override("font_color", _color_for(i))
		row.show()
		_list.add_child(row)


func _color_for(index: int) -> Color:
	if index < Campaign.progress:
		return _DONE
	return _NEXT if index == Campaign.progress else _LOCKED
