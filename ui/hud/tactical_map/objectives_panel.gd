extends Control
class_name ObjectivesPanel

## Qué hay que hacer en esta misión y qué ya está hecho.
##
## **Los objetivos vienen por `@export` porque todavía no hay quien los mande.**
## No existe un sistema de misiones: el briefing sólo lleva un párrafo de texto
## y nadie apunta condiciones ni las da por cumplidas. Puesto así, el panel es
## de verdad —se abre, se cierra, se lee— y el hueco que falta está declarado en
## un sitio, no repartido por el código. El día que haya misiones, quien las
## lleve llama a [method set_objectives] y estos valores se quedan de muestra
## para poder seguir componiendo la pantalla con F6.
##
## **Va suelto encima del terreno, sin marco.** El precio es que el texto
## compite con el mapa: sin fondo ni borde, lo único que lo despega es el
## color, y el mapa lleva de todo debajo. Si algún día no se lee, se arregla
## por color —no acortando la línea ni poniéndole contorno a la fuente—.

## Lo que hay que hacer, en el orden en que se enseña. Se numeran solas.
@export var objectives: PackedStringArray = []
## Lo que ya está hecho. Va en su propia lista y no marcado dentro de la de
## arriba porque son **dos listas que crecen por separado**: una la escribe la
## misión y la otra la partida.
@export var completed: PackedStringArray = []

## Cada lista tiene su propia caja y su propia plantilla dentro. Así el orden lo
## lleva la escena y no hay que calcular en qué posición cae cada fila clonada.
@onready var _rows: VBoxContainer = $Rows
@onready var _pending_box: VBoxContainer = $Rows/Pending
@onready var _pending_row: Label = $Rows/Pending/Row
@onready var _rule: Control = $Rows/Rule
@onready var _done_head: Label = $Rows/DoneHead
@onready var _done_box: VBoxContainer = $Rows/Done
@onready var _done_row: Label = $Rows/Done/Row


func _ready() -> void:
	_pending_row.hide()
	_done_row.hide()
	# Un rótulo que se parte en dos renglones no sabe cuánto ocupa hasta que la
	# caja le ha dado un ancho, y eso pasa un fotograma después. En vez de
	# adivinarlo, se vuelve a medir cuando el contenido diga que cambió.
	_rows.minimum_size_changed.connect(_fit)
	_refill()


## Cambia las dos listas de golpe. Van juntas porque completar un objetivo
## cambia las dos: sale de una y entra en la otra.
func set_objectives(pending: PackedStringArray, done: PackedStringArray) -> void:
	objectives = pending
	completed = done
	if is_node_ready():
		_refill()


func _refill() -> void:
	_fill(_pending_box, _pending_row, objectives, true)
	_fill(_done_box, _done_row, completed, false)
	# La raya y el rótulo de completados sólo salen si hay algo debajo: una
	# cabecera con nada es un hueco disfrazado de dato.
	var any_done := not completed.is_empty()
	_rule.visible = any_done
	_done_head.visible = any_done
	_done_box.visible = any_done
	_fit()


## Crece hacia arriba desde su borde de abajo, que es el que está clavado: la
## lista se alarga conforme aparecen objetivos y lo que no debe moverse es el
## botón que la abre. Las medidas salen de los `offset` de la escena.
func _fit() -> void:
	var tall := _rows.get_combined_minimum_size().y
	offset_top = offset_bottom - (tall + _rows.offset_top - _rows.offset_bottom)


func _fill(box: VBoxContainer, template: Label, lines: PackedStringArray,
		numbered: bool) -> void:
	for child in box.get_children():
		if child == template:
			continue
		# Desenganchar antes de liberar: hasta el final del fotograma la columna
		# repartiría entre las viejas y las nuevas a la vez.
		box.remove_child(child)
		child.queue_free()
	for i in lines.size():
		var row := template.duplicate() as Label
		# En mayúsculas: la fuente del mapa no tiene minúsculas y lo que le falte
		# lo sacaría Godot de una del sistema, rompiendo el alto de línea.
		var linea := lines[i].to_upper()
		row.text = ("%d. %s" % [i + 1, linea]) if numbered else ("- " + linea)
		row.show()
		box.add_child(row)
