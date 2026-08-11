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
## Cuánto puede tardar la siguiente arma de una andanada en salir para que
## cuente como la misma. La ristra de Mk-82 va a una décima entre bombas; esto
## deja margen de sobra sin llegar a juntar dos ataques distintos.
const SALVO_WINDOW := 2.0
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
## La última línea escrita, para poder reescribirla si la andanada sigue.
var _last_line: RichTextLabel = null
## De qué andanada va esa línea: arma, de quién y cuántas van.
var _salvo_weapon: WeaponType = null
var _salvo_unit: int = 0
var _salvo_count: int = 0
var _salvo_at: float = 0.0
## El borde de abajo se queda quieto y el parte crece hacia arriba, como una
## consola: lo último dicho queda siempre a la misma altura.
var _bottom: float = 0.0


func _ready() -> void:
	_bottom = position.y + size.y
	hide()
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
	# El panel es estrecho a propósito, así que las líneas parten en vez de
	# cortarse: perder la coordenada del final sería perder lo pulsable.
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Hay que decirle el ancho a mano. Con `fit_content`, si no lo sabe calcula
	# su alto mínimo suponiendo ancho cero — una línea pedía 300 px de alto.
	line.custom_minimum_size.x = size.x - _panel_padding()
	line.add_theme_color_override("default_color", TEXT_COLOR)
	line.add_theme_font_size_override("normal_font_size", _FONT_SIZE)
	line.meta_clicked.connect(_on_coordinate_clicked)
	line.text = text
	lines.add_child(line)
	_last_line = line
	if lines.get_child_count() > MAX_LINES:
		lines.get_child(0).queue_free()
	show()
	# Diferido: la línea que se acaba de tirar no desaparece del recuento hasta
	# el final del frame, y hasta entonces el alto mínimo sale de más.
	_hug_content.call_deferred()


## El panel mide lo que midan sus líneas. Vacío no se dibuja: un recuadro negro
## sin nada dentro ocupa sitio y no dice nada.
## Dónde acaba el parte por abajo. Lo mueve el HUD cuando el minimapa cambia de
## tamaño: los dos viven en la misma columna y el minimapa manda, porque es el
## que el jugador estira a mano.
func set_bottom(y: float) -> void:
	_bottom = y
	_hug_content()


func _hug_content() -> void:
	size.y = get_combined_minimum_size().y
	position.y = _bottom - size.y


func _panel_padding() -> float:
	var box := get_theme_stylebox("panel")
	return box.get_margin(SIDE_LEFT) + box.get_margin(SIDE_RIGHT)


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
	unit.tracked_by.connect(_on_tracked.bind(unit))
	unit.fired_upon_by.connect(_on_fired_upon.bind(unit))
	unit.missile_inbound.connect(_on_missile_inbound.bind(unit))
	for child in unit.get_children():
		var pod := child as Countermeasures
		if pod != null:
			pod.dispensing_started.connect(_on_defending.bind(unit))


## Caer no es lo mismo según de quién sea lo que cayó, y el parte tiene que
## sonar distinto: **"Splash!" es lo que se canta al derribar algo**, no lo que
## se dice al perder a uno de los tuyos.
func _on_died(unit: Unit) -> void:
	if not unit.is_player_controlled():
		add_event("Splash! %s %s" % [unit.get_display_name(),
				_zone(unit.global_position)])
		return
	var by := ""
	if is_instance_valid(unit.killed_by):
		by = ", derribado por %s" % unit.killed_by.get_display_name()
	add_event("UNIT LOST — %s%s %s" % [unit.get_display_name(), by,
			_zone(unit.global_position)])


func _on_target_changed(target: Unit, unit: Unit) -> void:
	# Perder el objetivo también emite, con `null`. Que deje de atacar no es
	# noticia; que empiece, sí.
	if not is_instance_valid(target) or not unit.is_player_controlled():
		return
	add_event("%s ataca %s %s" % [unit.get_display_name(), target.get_display_name(),
			_zone(target.global_position)])


## "Harrier: MUD SPIKE — 2S6 Tunguska B4". Un radar de superficie la tiene
## enganchada, y **todavía no le disparan**: es el aviso que llega a tiempo.
##
## Se da la coordenada de LA AMENAZA, no la del avión: lo que el jugador necesita
## saber es de dónde viene, para decidir por dónde sale.
func _on_tracked(threat: Unit, unit: Unit) -> void:
	if not _is_worth_reporting(unit, threat):
		return
	add_event("%s: MUD SPIKE — %s %s" % [unit.get_display_name(),
			threat.get_display_name(), _zone(threat.global_position)])


## "Harrier: AAA, bajo fuego B4". Esto ya no es un aviso.
func _on_fired_upon(threat: Unit, unit: Unit) -> void:
	if not _is_worth_reporting(unit, threat):
		return
	add_event("%s: AAA, bajo fuego %s" % [unit.get_display_name(),
			_zone(threat.global_position)])


## "Harrier: SAM LAUNCH — 2S6 Tunguska B4". El aviso urgente: hay algo en el aire
## viniendo a por ella.
##
## El código va del arma (`brevity_code`) y no escrito aquí, porque lo que te
## tiran cambia lo que sirve para engañarlo: contra radar, chaff; contra calor,
## bengalas. El parte tiene que decir cuál es.
func _on_missile_inbound(threat: Unit, weapon: WeaponType, _missile: Node2D, unit: Unit) -> void:
	if not _is_worth_reporting(unit, threat):
		return
	var code := weapon.brevity_code if weapon.brevity_code != "" else "MISSILE"
	add_event("%s: %s LAUNCH — %s %s" % [unit.get_display_name(), code,
			threat.get_display_name(), _zone(threat.global_position)])


## "Harrier: DEFENDING". La respuesta al aviso anterior: está soltando señuelos y
## maniobrando. Va sin coordenada — lo que importa no es dónde, es que está en
## ello y que el jugador no tiene que hacer nada.
func _on_defending(_threat: Unit, unit: Unit) -> void:
	if not unit.is_player_controlled():
		return
	add_event("%s: DEFENDING" % unit.get_display_name())


## El parte es del jugador: que a un enemigo lo enganche otro enemigo no es
## noticia suya. Morir sí se cuenta de todos —saber que algo cayó importa venga
## de donde venga—, pero las alarmas son de los suyos.
func _is_worth_reporting(unit: Unit, threat: Unit) -> bool:
	return unit.is_player_controlled() and is_instance_valid(threat)


## Se cuelga del gasto de munición y no de un "disparó" propio porque es la
## misma cosa: una menos es un arma que salió del ala.
##
## **Una ristra es una línea, no seis.** Soltar seis Mk-82 gasta munición seis
## veces con una décima entre medias, y sin agrupar el parte no diría más que
## "Mk-82" repetido hasta llenarse. Es un solo gesto del piloto y se cuenta como
## uno, con la cantidad al lado.
func _on_ammo_changed(weapon: WeaponType, _remaining: int, unit: Unit) -> void:
	if not unit.is_player_controlled():
		return
	if _grew_the_salvo(weapon, unit):
		return
	_salvo_weapon = weapon
	_salvo_unit = unit.get_instance_id()
	_salvo_count = 1
	_salvo_at = Time.get_ticks_msec() / 1000.0
	add_event(_salvo_text(weapon, unit, 1))


## ¿Esto es otra arma de la misma andanada? Entonces se reescribe la línea que ya
## está en vez de añadir otra.
##
## Tiene que ser **la última línea**: si entre dos bombas se coló otro suceso,
## agrupar hacia atrás dejaría el parte contando cosas en desorden.
func _grew_the_salvo(weapon: WeaponType, unit: Unit) -> bool:
	if weapon != _salvo_weapon or unit.get_instance_id() != _salvo_unit:
		return false
	if Time.get_ticks_msec() / 1000.0 - _salvo_at > SALVO_WINDOW:
		return false
	if _last_line == null or not is_instance_valid(_last_line) \
			or lines.get_child_count() == 0 or lines.get_child(-1) != _last_line:
		return false
	_salvo_count += 1
	_salvo_at = Time.get_ticks_msec() / 1000.0
	_last_line.text = _salvo_text(weapon, unit, _salvo_count)
	return true


func _salvo_text(weapon: WeaponType, unit: Unit, count: int) -> String:
	var code: String = " (%s!)" % weapon.brevity_code if weapon.brevity_code != "" else ""
	var many := " x%d" % count if count > 1 else ""
	return "%s: %s%s%s" % [unit.get_display_name(), weapon.get_short_name(), many, code]


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
