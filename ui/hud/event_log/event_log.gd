extends PanelContainer
class_name EventLog

## El parte de lo que va pasando, con la coordenada del mapa para poder situarlo.
##
## El panel no tiene fondo y el texto va blanco y sin borde. Eso deja la letra
## limpia, pero también la deja **sin nada que la despegue del terreno**: sobre
## mar, que es azul claro, lo que se escriba en azul —la coordenada, y la marca
## de las órdenes— se pierde, y más aún cuando la entrada se apaga a
## `faded_alpha`. Si algún día hay que arreglarlo, se arregla por uno de esos
## tres sitios (color, fondo o borde); no tocar el texto de los mensajes.
##
## Se engancha él solo a cada unidad según aparece —igual que el mapa saca sus
## puntos del grupo—, así que nadie tiene que acordarse de avisarle cuando nace
## o muere una. Lo único que le llega de fuera son las órdenes, porque esas no
## las emite nadie: las da el jugador.

## El jugador pulsó una coordenada del parte: quiere ver qué pasa ahí. Se
## reenvía, igual que el resto del HUD — aquí no se conoce la cámara.
signal look_requested(world_position: Vector2)

## La plantilla de una línea del parte. Todo lo visual —fuente, tamaño, color y
## el aire de arriba y abajo— se toca abriendo `event_entry.tscn` en el editor,
## que se ve con contenido de muestra.
const ENTRY := preload("res://ui/hud/event_log/event_entry.tscn")

## De qué clase es el suceso. Lo dice una **marca de un carácter con color**, no
## un ícono: al ser texto entra en el flujo del renglón y se centra con él, no
## necesita una columna propia que alinear ni un PNG que mantener, y a 8 px un
## dibujo no daba para distinguir cinco cosas de todos modos.
enum Kind {
	ORDER,   ## el jugador manda algo
	ATTACK,  ## uno de los suyos abre fuego
	ALERT,   ## algo le apunta, le dispara o viene a por él
	LOST,    ## cae uno de los suyos
	KILL,    ## cae uno del otro
}

## La marca de cada clase. **Van en blanco, como todo el parte.** Se probaron con
## color y no sirve: el parte se dibuja encima del terreno, y cualquier color que
## se elija se pierde sobre algún terreno — el azul desaparece sobre el mar, y
## entonces del renglón sólo se lee la mitad. Blanco se lee sobre todo.
const _MARKS: Dictionary = {
	Kind.ORDER: ">",
	Kind.ATTACK: "*",
	Kind.ALERT: "!",
	Kind.LOST: "X",
	Kind.KILL: "+",
}

## De dónde salen las coordenadas. Apunta al [MapView] **del mapa táctico**, que
## es la rejilla que el jugador lee. No vale el del minimapa: ahí las zonas se
## agrupan hasta caber en 87 px y el mapa entero sale como dos o tres
## coordenadas, así que el parte diría `A1` de todo.
@export var map_path: NodePath

## Lo visual de cada línea —fuente, tamaño, color, aire— no está aquí: se toca
## abriendo `event_entry.tscn`, que es la plantilla y se ve en el editor. Aquí
## sólo queda lo que decide el parte en conjunto.

## Cuántas entradas se ven a la vez. Con 6 y alguna partida en dos filas el
## panel se estira por encima de los 160 px del dibujo; con 5 no llega.
@export_range(1, 12, 1) var max_entries: int = 6
## El de las coordenadas pulsables. Vive aquí y no en la plantilla porque el
## resalte se mete como BBCode al componer el texto, en [method _zone].
##
## **Es lo único del parte que no va en blanco**, y el amarillo no es capricho:
## el parte se dibuja encima del terreno, así que el color tiene que contrastar
## con todo lo que haya debajo. El azul de antes se perdía sobre el mar —que es
## azul— y la coordenada desaparecía de la línea. Un amarillo cálido aguanta
## tanto el agua como la tierra.
@export var accent_color := Color(0.99607843, 0.90588236, 0.38039216)

@onready var lines: VBoxContainer = $VBox/Lines

var _map: MapView = null
## La última entrada escrita. Nadie la reescribe hoy, pero es lo que hace falta
## para poder hacerlo sin buscarla en el árbol.
var _last_entry: EventEntry = null
## El borde de abajo se queda quieto y el parte crece hacia arriba, como una
## consola: lo último dicho queda siempre a la misma altura.
var _bottom: float = 0.0


func _ready() -> void:
	_bottom = position.y + size.y
	hide()
	_map = get_node_or_null(map_path) as MapView
	# El alto del panel se recalcula cada vez que las entradas cambian de
	# tamaño, no sólo al añadir una: cuando llega, el texto todavía no sabe de
	# qué ancho dispone y pide más alto del que va a necesitar. Sin esto el
	# panel se quedaba con esa primera cuenta, muy pasada.
	lines.minimum_size_changed.connect(_hug_content)
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
##
## [param kind] a `-1` deja el renglón sin marca —lo usa la línea de
## continuación de una baja, que es la misma noticia partida en dos—.
func add_event(text: String, kind: int = -1) -> void:
	var entry: EventEntry = ENTRY.instantiate()
	lines.add_child(entry)
	# Después de colgarla: la escena resuelve sus nodos al entrar en el árbol.
	entry.setup(_compose(text, kind))
	entry.coordinate_clicked.connect(_on_coordinate_clicked)
	_last_entry = entry
	while lines.get_child_count() > max_entries:
		# Se saca del árbol en el acto y no sólo con `queue_free`: si no,
		# seguiría contando como hijo hasta el final del frame y esta vuelta
		# volvería a coger la misma.
		var gone := lines.get_child(0)
		lines.remove_child(gone)
		gone.queue_free()
	show()
	# Diferido: la línea que se acaba de tirar no desaparece del recuento hasta
	# el final del frame, y hasta entonces el alto mínimo sale de más.
	_hug_content.call_deferred()


## El renglón terminado: marca y texto, alineado a la izquierda.
func _compose(text: String, kind: int) -> String:
	if not _MARKS.has(kind):
		return text
	return "%s %s" % [_MARKS[kind], text]


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


## "Harrier moviéndose a G5". Lo llama quien da la orden, que es el único que
## sabe que ha habido una.
func report_move_order(unit: Unit, where: Vector2) -> void:
	# Lo que hace la unidad va **escrito**, no insinuado con un signo. Estuvo
	# como "Harrier > G5" y no se entiende: el jugador no tiene por qué adivinar
	# qué significa la flecha, y si la coordenada no se lee bien la línea se
	# queda en el nombre a secas.
	add_event("%s moviéndose%s" % [_short(unit), _to(where)], Kind.ORDER)


func _watch(node: Node) -> void:
	var unit := node as Unit
	if unit == null or unit.died.is_connected(_on_died):
		return
	unit.died.connect(_on_died)
	unit.attack_target_changed.connect(_on_target_changed.bind(unit))
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
		add_event("Splash! %s%s" % [_short(unit),
				_at(unit.global_position)], Kind.KILL)
		return
	# Quién lo derribó va en su propia línea: metido en la misma, la entrada
	# ocupaba tres filas del parte y desplazaba a todo lo demás. Va sin marca —
	# es la misma noticia partida, no otra.
	add_event("Perdido: %s%s" % [_short(unit),
			_at(unit.global_position)], Kind.LOST)
	if is_instance_valid(unit.killed_by):
		add_event("   por %s" % _short(unit.killed_by))


## "Harrier ataca Su-33 (FOX 2) en B5". El compromiso entero en una línea: quién,
## contra qué, con qué y dónde.
##
## **El arma no tiene parte propio.** Cada disparo emitía la suya, así que un
## ataque llenaba el registro de repeticiones del mismo suceso — y con seis
## unidades a la vez tapaba lo único urgente, que son las alarmas. Empezar a
## atacar y destruir el blanco son las dos noticias; lo de en medio no lo es. El
## gasto de munición se ve en el `weapon_bar`, que es donde toca.
func _on_target_changed(target: Unit, unit: Unit) -> void:
	# Perder el objetivo también emite, con `null`. Que deje de atacar no es
	# noticia; que empiece, sí.
	if not is_instance_valid(target) or not unit.is_player_controlled():
		return
	add_event("%s ataca %s%s%s" % [_short(unit), _short(target),
			_brevity_of(unit, target), _at(target.global_position)], Kind.ATTACK)


## El código de radio del arma con la que va a atacar, entre paréntesis. Se le
## pregunta al selector cuál elegiría para ese blanco, que es la misma decisión
## que va a tomar al disparar.
##
## Vacío si la unidad no tiene selector o si el arma no lleva código: el
## paréntesis es sabor, no dato, y quien no lo tenga no debe dejar un hueco raro
## en la línea.
func _brevity_of(unit: Unit, target: Unit) -> String:
	var selector: WeaponSelector = null
	for child in unit.get_children():
		selector = child as WeaponSelector
		if selector != null:
			break
	if selector == null:
		return ""
	var weapon := selector.best_for(target)
	if weapon == null or weapon.brevity_code == "":
		return ""
	return " (%s)" % weapon.brevity_code


## "Harrier: MUD SPIKE desde B4". Un radar de superficie la tiene
## enganchada, y **todavía no le disparan**: es el aviso que llega a tiempo.
##
## Se da la coordenada de LA AMENAZA, no la del avión: lo que el jugador necesita
## saber es de dónde viene, para decidir por dónde sale.
func _on_tracked(threat: Unit, unit: Unit) -> void:
	if not _is_worth_reporting(unit, threat):
		return
	add_event("%s: MUD SPIKE%s" % [_short(unit),
			_from(threat.global_position)], Kind.ALERT)


## "Harrier: AAA, bajo fuego desde B4". Esto ya no es un aviso.
func _on_fired_upon(threat: Unit, unit: Unit) -> void:
	if not _is_worth_reporting(unit, threat):
		return
	add_event("%s: AAA, bajo fuego%s" % [_short(unit),
			_from(threat.global_position)], Kind.ALERT)


## "Harrier: SAM LAUNCH desde B4". El aviso urgente: hay algo en el aire
## viniendo a por ella.
##
## El código va del arma (`brevity_code`) y no escrito aquí, porque lo que te
## tiran cambia lo que sirve para engañarlo: contra radar, chaff; contra calor,
## bengalas. El parte tiene que decir cuál es.
func _on_missile_inbound(threat: Unit, weapon: WeaponType, _missile: Node2D, unit: Unit) -> void:
	if not _is_worth_reporting(unit, threat):
		return
	var code := weapon.brevity_code if weapon.brevity_code != "" else "MISSILE"
	add_event("%s: %s LAUNCH%s" % [_short(unit), code,
			_from(threat.global_position)], Kind.ALERT)


## "Harrier: DEFENDING". La respuesta al aviso anterior: está soltando señuelos y
## maniobrando. Va sin coordenada — lo que importa no es dónde, es que está en
## ello y que el jugador no tiene que hacer nada.
func _on_defending(_threat: Unit, unit: Unit) -> void:
	if not unit.is_player_controlled():
		return
	add_event("%s: DEFENDING" % _short(unit), Kind.ALERT)


## El parte es del jugador: que a un enemigo lo enganche otro enemigo no es
## noticia suya. Morir sí se cuenta de todos —saber que algo cayó importa venga
## de donde venga—, pero las alarmas son de los suyos.
func _is_worth_reporting(unit: Unit, threat: Unit) -> bool:
	return unit.is_player_controlled() and is_instance_valid(threat)




## El nombre tal como se canta por radio: sin el modelo largo detrás. En el
## parte cabe "2S6", no "2S6 Tunguska", y el jugador lo reconoce igual porque el
## nombre completo lo tiene en el panel de selección.
func _short(unit: Unit) -> String:
	var name := unit.get_display_name()
	var cut := name.find(" ")
	return name if cut < 1 else name.substr(0, cut)


## La coordenada con la preposición que le da sentido. Una `B4` suelta al final
## de la línea no dice nada —el jugador no tiene por qué saber que eso es una
## casilla del mapa—, y la preposición además distingue **qué** pasa ahí: en un
## ataque o una baja la coordenada es dónde ocurrió la cosa, pero en una alarma
## es de dónde viene la amenaza, no dónde está el que la sufre.
##
## Devuelven cadena vacía si no hay zona que dar, con preposición y todo: mejor
## una línea sin sitio que una que acabe en "en" a secas. Por eso el espacio va
## dentro y los formatos que las usan pegan el `%s` sin separarlo.
func _at(world: Vector2) -> String:
	var zone := _zone(world)
	return "" if zone.is_empty() else " en %s" % zone


func _from(world: Vector2) -> String:
	var zone := _zone(world)
	return "" if zone.is_empty() else " desde %s" % zone


func _to(world: Vector2) -> String:
	var zone := _zone(world)
	return "" if zone.is_empty() else " a %s" % zone


## La coordenada, envuelta para poder pulsarla. Sin mapa a la vista no hay
## coordenada que dar, y entonces la línea se queda sin ella en vez de mentir.
##
## **Va entre corchetes además de en color.** Dos señales y no una porque cada
## una falla por su lado: el color se pierde si algún día se toca la paleta o si
## el terreno de debajo se le parece, y los corchetes se leen igual en blanco y
## negro. Los corchetes se escriben `[lb]` y `[rb]`: escritos a pelo, el BBCode
## se los comería creyendo que abren una etiqueta.
func _zone(world: Vector2) -> String:
	if _map == null:
		return ""
	var label := _map.zone_label_at(world)
	if label == "":
		return ""
	return "[url=%f,%f][color=#%s][lb]%s[rb][/color][/url]" % [
			world.x, world.y, accent_color.to_html(false), label]
