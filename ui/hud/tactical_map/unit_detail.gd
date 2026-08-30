extends Control
class_name UnitDetail

## La ficha del contacto que se está mirando en el mapa táctico.
##
## **No es la ventana del buque.** De aquélla toma prestados los dibujos —el
## marco, el marco interior, el de contenido— y nada más: aquélla es un sitio
## donde se dan órdenes, con hangar y pañol, y sólo vale para lo propio. Ésta
## sólo mira, y mira **a quien sea**: se pulsa un enemigo en el mapa y sale su
## ficha igual que la de un aliado. Por eso los corchetes del mapa vienen en
## cuatro colores.
##
## Lo que enseña sale de la unidad y de nadie más. Un dato que ella no conteste
## —munición de una unidad sin armamento— no aparece: ver [method _fill_weapons].

## Alto que ocupa el modelo dentro del marco. Sale de los [code]offset[/code] de
## la escena, así que mover el hueco en el editor no obliga a tocar el código.
@onready var _frame: NinePatchRect = $Frame
@onready var _model: UnitModel = $Frame/Portrait/Model
@onready var _content: NinePatchRect = $Frame/Content
@onready var _rows: VBoxContainer = $Frame/Content/Rows
@onready var _name: Label = $Frame/Content/Rows/UnitName
@onready var _team: Label = $Frame/Content/Rows/Team
@onready var _heading: Label = $Frame/Content/Rows/Heading
@onready var _damage: Label = $Frame/Content/Rows/Damage
@onready var _health: TextureProgressBar = $Frame/Content/Rows/Health
@onready var _status_head: Label = $Frame/Content/Rows/StatusHead
@onready var _status: Label = $Frame/Content/Rows/Status
@onready var _arms_head: Label = $Frame/Content/Rows/ArmsHead
## La fila de un arma. Se queda **puesta** en la escena, con datos de muestra,
## para poder colocar la columna en el editor; el código la esconde al arrancar
## y clona una por arma.
@onready var _arm: Label = $Frame/Content/Rows/Arm

## A quién se está mirando. `null` = la ficha está guardada.
var _unit: Unit = null
## De dónde salen las coordenadas del estado ("Moviéndose a F6"). Lo pasa el
## mapa, que es quien las sabe traducir.
var _map: MapView = null
## Las filas de armamento clonadas, para poder quitarlas antes de rehacerlas.
var _arms: Array[Label] = []


func _ready() -> void:
	_arm.hide()
	hide()
	set_process(false)


## Enseña la ficha de una unidad. `null` la guarda.
func show_unit(unit: Unit, map: MapView) -> void:
	_map = map
	if not is_instance_valid(unit):
		_unit = null
		_model.show_scene(null)
		hide()
		set_process(false)
		return
	_unit = unit
	_name.text = unit.get_display_name().to_upper()
	_team.text = UnitWords.team_of(unit)
	# El retrato son los sprites de la propia unidad, copiados: no hay un dibujo
	# aparte que mantener al día y una unidad nueva sale aquí el día que exista.
	_model.show_scene(load(unit.scene_file_path) if unit.scene_file_path != "" else null)
	_fill_weapons(unit)
	_refresh()
	show()
	set_process(true)


func clear() -> void:
	show_unit(null, _map)


## Rumbo, daño y estado cambian solos mientras se mira: el contacto sigue
## volando con la ficha abierta. Nombre, bando y armamento no, y por eso se
## ponen una vez.
func _process(_delta: float) -> void:
	if not is_instance_valid(_unit):
		clear()
		return
	_refresh()


func _refresh() -> void:
	_heading.text = "RUMBO: " + UnitWords.heading(_unit)
	var maximum := maxf(1.0, _unit.get_max_health())
	# Se enseña el daño y la barra cuenta la vida, que es lo que queda. Son el
	# mismo dato por los dos lados y por eso van juntos: el número dice cuánto
	# le han hecho y la barra, cuánto aguanta.
	_damage.text = "DA\u00d1O: %d%%" % roundi((1.0 - _unit.health / maximum) * 100.0)
	_health.max_value = maximum
	_health.value = _unit.health
	_status.text = " " + UnitWords.status(
			_unit, _map, "EN ESPERA", "MOVI\u00c9NDOSE A ", "ATACANDO A ").to_upper()
	_fit()


## Una fila por arma, con lo que le queda.
##
## Una unidad desarmada **no enseña el rótulo tampoco**: un "ARMAMENTO:" con
## nada debajo es un hueco disfrazado de dato. Y la ventana encoge, porque mide
## lo que mide su contenido.
func _fill_weapons(unit: Unit) -> void:
	for row in _arms:
		# Desenganchar antes de liberar: `queue_free` no lo saca de la columna
		# hasta el final del fotograma, y hasta entonces la caja reparte entre
		# las viejas y las nuevas a la vez.
		_rows.remove_child(row)
		row.queue_free()
	_arms.clear()
	var weapons := unit.get_weapons()
	_arms_head.visible = not weapons.is_empty()
	for weapon in weapons:
		var row := _arm.duplicate() as Label
		# El cañón devuelve −1 porque todavía no gasta munición. Eso no es una
		# cantidad: es que nadie la lleva, y escribir "x−1" sería inventarse un
		# dato. Sale el arma sola hasta que el número exista.
		var left := unit.get_ammo(weapon)
		row.text = " %s" % weapon.get_short_name() if left < 0 \
				else " x%d %s" % [left, weapon.get_short_name()]
		row.show()
		_rows.add_child(row)
		_arms.append(row)


## La ventana mide lo que mide su contenido, y las medidas salen de los
## `offset` de la escena: mover el hueco del retrato o apretar el margen del
## panel interior sigue dando la altura correcta sin tocar una línea de aquí.
func _fit() -> void:
	var tall := 0.0
	var shown := 0
	for child in _rows.get_children():
		var row := child as Control
		if row == null or not row.visible:
			continue
		tall += row.get_combined_minimum_size().y
		shown += 1
	if shown > 1:
		tall += _rows.get_theme_constant(&"separation") * (shown - 1)
	size.y = _content.offset_top + _rows.offset_top + tall \
			- _rows.offset_bottom - _content.offset_bottom
