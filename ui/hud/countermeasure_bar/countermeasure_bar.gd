@tool
extends HBoxContainer
class_name CountermeasureBar

## Chaff y bengalas de la unidad seleccionada, con lo que le queda de cada una.
##
## Barra aparte de la de armas a propósito: **una contramedida no es un arma**.
## No se elige, no apunta y no hace daño, así que no debe leerse como una opción
## más de la rotación de armas ni ocupar sitio en esa fila.
##
## **No se pueden pulsar todavía, y es a propósito**: hoy el avión se defiende
## solo y el jugador no pilota. Están porque son parte de lo que lleva encima —
## saber que le quedan tres bengalas cambia si mandás ese avión o no—, y el día
## que haya pilotaje manual el botón ya está en su sitio.
##
## Es `@tool` y todo lo que se ve está exportado: la barra se coloca y se
## dimensiona **en el editor**, arrastrando, sin tocar código.

const _COLOR_TEXT   := Color(0.6705882, 0.5803922, 0.4784314)
const _COLOR_ACCENT := Color(0.56078434, 0.827451, 1.0)
const _COLOR_BG     := Color(0.19215686, 0.21176471, 0.21960784)
## Cuánto se apaga un botón normal. Igual que en la barra de armas, para que las
## dos filas se lean como parte del mismo panel.
const _DIM_ALPHA := 0.45
## Y cuánto el de una carga agotada.
const _EMPTY_ALPHA := 0.22

@export var button_size: Vector2 = Vector2(28, 22):
	set(value):
		button_size = value
		_rebuild()
@export_range(4, 16, 1) var font_size: int = 6:
	set(value):
		font_size = value
		_rebuild()
## Lo que se ve escrito en cada botón. Vacío = se usa el nombre de siempre.
@export var chaff_label: String = "":
	set(value):
		chaff_label = value
		_rebuild()
@export var flare_label: String = "":
	set(value):
		flare_label = value
		_rebuild()

var _pod: Countermeasures = null


func _ready() -> void:
	if Engine.is_editor_hint():
		# En el editor no hay unidad seleccionada, así que se enseñan botones de
		# muestra: si no, la barra sería un rectángulo vacío imposible de colocar.
		_rebuild()
		return
	hide()


## Enseña lo que lleva esa unidad, o se esconde si no lleva nada.
func show_for(unit: Unit) -> void:
	_pod = _countermeasures_of(unit)
	if _pod != null and not _pod.spent.is_connected(_on_spent):
		_pod.spent.connect(_on_spent)
	_rebuild()
	visible = _pod != null


func clear() -> void:
	_pod = null
	_rebuild()
	hide()


func _on_spent(_kind: Countermeasures.Kind, _left: int) -> void:
	_rebuild()


## El dispensador de la unidad, si lo lleva. Se busca entre los hijos igual que
## `Unit` busca su `HardpointRack`: la barra no tiene por qué saber dónde cuelga.
func _countermeasures_of(unit: Unit) -> Countermeasures:
	if unit == null:
		return null
	for child in unit.get_children():
		var pod := child as Countermeasures
		if pod != null:
			return pod
	return null


func _rebuild() -> void:
	if not is_node_ready():
		return
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for kind in [Countermeasures.Kind.CHAFF, Countermeasures.Kind.FLARES]:
		add_child(_make_button(kind))


func _label_for(kind: Countermeasures.Kind) -> String:
	var custom := chaff_label if kind == Countermeasures.Kind.CHAFF else flare_label
	return custom if custom != "" else Countermeasures.label_of(kind)


## Lo que queda de ese tipo. En el editor no hay unidad, así que se enseña la
## carga por defecto para poder ver cómo queda la barra llena.
func _left_of(kind: Countermeasures.Kind) -> int:
	if _pod != null:
		return _pod.remaining(kind)
	return 30 if Engine.is_editor_hint() else 0


func _make_button(kind: Countermeasures.Kind) -> Button:
	var left := _left_of(kind)
	var btn := Button.new()
	btn.text = _label_for(kind)
	btn.custom_minimum_size = button_size
	btn.add_theme_font_size_override("font_size", font_size)
	btn.tooltip_text = "%s: %d" % [_label_for(kind), left]
	# Agotada se apaga y deja de responder, igual que un arma sin munición.
	btn.disabled = left <= 0

	var count := Label.new()
	count.text = str(left)
	count.add_theme_font_size_override("font_size", maxi(font_size - 1, 4))
	count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	count.grow_vertical = Control.GROW_DIRECTION_BEGIN
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Que no se coma los clicks destinados al botón que lo contiene.
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(count)

	_style(btn, count, left <= 0)
	return btn


func _style(btn: Button, count: Label, empty: bool) -> void:
	var alpha := _EMPTY_ALPHA if empty else _DIM_ALPHA
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(_COLOR_BG, alpha)
		box.set_border_width_all(1)
		box.border_color = Color(_COLOR_ACCENT, alpha * 0.6)
		box.set_content_margin_all(1)
		btn.add_theme_stylebox_override(state, box)
	btn.add_theme_color_override("font_color", Color(_COLOR_TEXT, alpha))
	btn.add_theme_color_override("font_disabled_color", Color(_COLOR_TEXT, alpha))
	count.add_theme_color_override("font_color", Color(_COLOR_TEXT, alpha))
