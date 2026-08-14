extends PanelContainer

signal unit_selected(unit: Unit)

const PORTRAIT := preload("res://ui/hud/deployed_panel/unit_portrait.tscn")

## Qué grupo va en cada fila de la escena, en orden. El nombre de la fila es el
## del nodo: mover una categoría de sitio es mover el nodo en el editor.
const _CATEGORIES: Array = [
	["unit_maritime", "Sea"],
	["unit_air", "Air"],
	["unit_ground", "Ground"],
]

@onready var _rows_box: HBoxContainer = $Rows

var _rows: Array[HBoxContainer] = []
var _dirty := true
## La que está seleccionada ahora mismo, para volver a marcarla cuando el panel
## se reconstruye. Sin esto, perder o desplegar una unidad apagaría el marco de
## la que el jugador tiene delante.
var _selected: Unit = null
## Las que se perdieron, por categoría: `{índice de fila: [[nombre, tipo], ...]}`.
## Se guarda el nombre **y el tipo** porque la unidad ya no existe y el cuadrito
## sigue necesitando su silueta — el panel es lo único que queda de ella.
##
## Una baja **no desaparece del panel**: se va al final de su fila, apagada. Que
## un cuadrito se esfume sin más deja al jugador dudando de si perdió algo o si
## nunca lo tuvo; verlo ahí, apagado, es el recuento de la operación.
var _lost: Dictionary = {}


func _ready() -> void:
	for pair in _CATEGORIES:
		_rows.append(_rows_box.get_node(pair[1]) as HBoxContainer)
	get_tree().node_added.connect(_on_tree_changed)
	get_tree().node_removed.connect(_on_tree_changed)
	get_tree().node_added.connect(_watch)
	_sweep.call_deferred()


## Se engancha a cada unidad para enterarse de su muerte mientras todavía existe:
## en `node_removed` ya no se le puede preguntar ni el nombre.
func _sweep() -> void:
	for node in get_tree().get_nodes_in_group(Unit.GROUP):
		_watch(node)


func _watch(node: Node) -> void:
	var unit := node as Unit
	if unit == null or unit.died.is_connected(_on_unit_died):
		return
	unit.died.connect(_on_unit_died)


func _on_unit_died(unit: Unit) -> void:
	if not unit.is_player_controlled():
		return
	var row := _row_of(unit)
	if row < 0:
		return
	if not _lost.has(row):
		_lost[row] = []
	_lost[row].append([unit.get_display_name(), unit.unit_type])
	_dirty = true


## En qué fila del panel va, o -1 si no es de ninguna categoría conocida.
func _row_of(unit: Unit) -> int:
	for i in _CATEGORIES.size():
		if unit.is_in_group(_CATEGORIES[i][0]):
			return i
	return -1


func _process(_delta: float) -> void:
	if not _dirty:
		return
	_dirty = false
	_refresh()


func _on_tree_changed(node: Node) -> void:
	if node is Unit:
		_dirty = true


## Cuál lleva el marco de seleccionada. La selección la manda el HUD: el panel no
## decide quién está elegida, sólo la señala.
func set_selected(unit: Unit) -> void:
	_selected = unit
	_apply_selection()


func _apply_selection() -> void:
	for row in _rows:
		for child in row.get_children():
			var portrait := child as UnitPortrait
			if portrait != null:
				portrait.set_selected(portrait.unit != null and portrait.unit == _selected)


func _refresh() -> void:
	for i in _rows.size():
		var row: HBoxContainer = _rows[i]
		for child in row.get_children():
			child.free()
		var group: String = _CATEGORIES[i][0]
		var seen_squads: Array[Squad] = []
		for node: Node in get_tree().get_nodes_in_group(group):
			if not is_instance_valid(node):
				continue
			var unit := node as Unit
			# El panel es el inventario desplegado del jugador. Los grupos
			# dicen de qué tipo es la unidad, no de quién es.
			if not unit.is_player_controlled():
				continue
			if unit.squad != null:
				if unit.squad in seen_squads:
					continue
				seen_squads.append(unit.squad)
				_add_portrait(row).show_unit(unit.squad.leader, unit.squad.members.size())
			else:
				_add_portrait(row).show_unit(unit, 1)
		# Las bajas van detrás de las vivas, siempre. Es el orden de un parte:
		# primero con qué se cuenta, después lo que costó.
		for lost: Array in _lost.get(i, []):
			_add_portrait(row).show_lost(lost[0], lost[1])
	_apply_selection()


## Un cuadrito vacío ya colgado de su fila. Entra en el árbol **antes** de que le
## digan a quién representa: `show_unit` toca nodos `@onready`, y hasta que no
## entra no existen.
func _add_portrait(row: HBoxContainer) -> UnitPortrait:
	var portrait: UnitPortrait = PORTRAIT.instantiate()
	row.add_child(portrait)
	portrait.picked.connect(func(picked: Unit) -> void: unit_selected.emit(picked))
	return portrait
