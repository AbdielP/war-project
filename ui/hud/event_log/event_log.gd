extends PanelContainer
class_name EventLog

## El parte de lo que va pasando, con la coordenada del mapa para poder situarlo.
##
## Se engancha él solo a cada unidad según aparece —igual que el mapa saca sus
## puntos del grupo—, así que nadie tiene que acordarse de avisarle cuando nace
## o muere una. Lo único que le llega de fuera son las órdenes, porque esas no
## las emite nadie: las da el jugador.

## El jugador pulsó una coordenada del parte: quiere ver qué pasa ahí. Se
## reenvía, igual que el resto del HUD — aquí no se conoce la cámara.
signal look_requested(world_position: Vector2)

const MAX_LINES := 6
const TEXT_COLOR := Color(0.6705882, 0.5803922, 0.4784314)
const ACCENT_COLOR := Color(0.56078434, 0.827451, 1.0)
const _FONT_SIZE := 8

## De dónde salen las coordenadas. Apunta al [MapView] **del mapa táctico**, que
## es la rejilla que el jugador lee. No vale el del minimapa: ahí las zonas se
## agrupan hasta caber en 87 px y el mapa entero sale como dos o tres
## coordenadas, así que el parte diría `A1` de todo.
@export var map_path: NodePath

@onready var lines: VBoxContainer = $Lines

var _map: MapView = null


func _ready() -> void:
	_map = get_node_or_null(map_path) as MapView
	get_tree().node_added.connect(_watch)
	# El repaso inicial va diferido a propósito: en `_ready()` sólo existen las
	# unidades que van antes que el HUD en la escena —las de después todavía no
	# se han metido en el grupo—, y `node_added` no las coge porque ya estaban
	# en el árbol cuando nos conectamos. Sin esto, media flota no se registraba.
	_sweep.call_deferred()


func _sweep() -> void:
	for node in get_tree().get_nodes_in_group(Unit.GROUP):
		_watch(node)


## El texto admite BBCode: es lo que hace pulsables las coordenadas. Ver
## [method _zone], que es quien las envuelve.
func add_event(text: String) -> void:
	var line := RichTextLabel.new()
	line.bbcode_enabled = true
	line.fit_content = true
	line.scroll_active = false
	line.autowrap_mode = TextServer.AUTOWRAP_OFF
	line.clip_contents = true
	line.add_theme_color_override("default_color", TEXT_COLOR)
	line.add_theme_font_size_override("normal_font_size", _FONT_SIZE)
	line.meta_clicked.connect(_on_coordinate_clicked)
	line.text = text
	lines.add_child(line)
	if lines.get_child_count() > MAX_LINES:
		lines.get_child(0).queue_free()


## La coordenada lleva pegado el punto exacto del mundo, no la letra: la zona es
## para leerla, pero la cámara va al sitio de verdad donde pasó la cosa.
func _on_coordinate_clicked(meta: Variant) -> void:
	var parts := str(meta).split(",")
	if parts.size() != 2:
		return
	look_requested.emit(Vector2(float(parts[0]), float(parts[1])))


## "Harrier → G5". Lo llama quien da la orden, que es el único que sabe que ha
## habido una.
func report_move_order(unit: Unit, where: Vector2) -> void:
	add_event("%s → %s" % [unit.get_display_name(), _zone(where)])


func _watch(node: Node) -> void:
	var unit := node as Unit
	if unit == null or unit.died.is_connected(_on_died):
		return
	unit.died.connect(_on_died)
	unit.attack_target_changed.connect(_on_target_changed.bind(unit))
	unit.ammo_changed.connect(_on_ammo_changed.bind(unit))


func _on_died(unit: Unit) -> void:
	add_event("Splash! %s %s" % [unit.get_display_name(), _zone(unit.global_position)])


func _on_target_changed(target: Unit, unit: Unit) -> void:
	# Perder el objetivo también emite, con `null`. Que deje de atacar no es
	# noticia; que empiece, sí.
	if not is_instance_valid(target):
		return
	add_event("%s ataca %s %s" % [unit.get_display_name(), target.get_display_name(),
			_zone(target.global_position)])


## Se cuelga del gasto de munición y no de un "disparó" propio porque es la
## misma cosa: una menos es un arma que salió del ala.
func _on_ammo_changed(weapon: WeaponType, _remaining: int, unit: Unit) -> void:
	var code: String = " (%s!)" % weapon.brevity_code if weapon.brevity_code != "" else ""
	add_event("%s: %s%s" % [unit.get_display_name(), weapon.get_short_name(), code])


## La coordenada, envuelta para poder pulsarla. Sin mapa a la vista no hay
## coordenada que dar, y entonces la línea se queda sin ella en vez de mentir.
func _zone(world: Vector2) -> String:
	if _map == null:
		return ""
	var label := _map.zone_label_at(world)
	if label == "":
		return ""
	return "[url=%f,%f][color=#%s]%s[/color][/url]" % [
			world.x, world.y, ACCENT_COLOR.to_html(false), label]
