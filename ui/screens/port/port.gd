extends Screen

## El puerto: donde se gasta el dinero entre misiones.
##
## **Dos menús y no tres.** La munición no es una tienda aparte porque no es un
## objeto que se compra y se guarda: es un número que vive dentro de un barco, y
## comprarla en un sitio para asignarla en otro obliga a viajar entre dos
## pantallas para tomar una sola decisión. Y una mejora se aplica a *una* unidad
## concreta, así que hay que estar mirándola: vive en su ficha, no en un árbol
## aparte que sería una pantalla entera para dos aeronaves.
##
##   - **Arsenal** — lo que NO tienes: vehículos y armas, con su precio.
##   - **Flota** — lo que SÍ tienes: qué lleva cada barco y en qué estado.
##
## Los dos se abren **encima** del muelle y no lo sustituyen: con los dos
## cerrados se ve el puerto entero, que es de lo que va la pantalla.
##
## No es un destino: se llega desde la campaña y desde el briefing, así que se
## sale con [method Screens.back] y no hacia una pantalla fija elegida de
## antemano. Abierto con F6 no tiene a quién volver y el botón sale apagado.

## Los diez dibujos de la barra de potencia, uno por valor. El número **es** el
## fotograma: ver [member UnitType.power].
const _POWER_STEPS := 10
const _POWER_BAR_H := 5.0
## El hueco del icono de la ficha. **La medida es del hueco y el zoom se adapta a
## ella**, no al revés: los iconos de unidad son de 20 px y los de arma de 32, y
## no hay caja que sirva a los dos a 1:1. Ver la regla de escala entera.
const _ICON_BOX := Vector2(40.0, 40.0)

const _TAN := Color(0.6705882, 0.5803922, 0.4784314)
## Lo que no se puede pagar. Rojo y **además** el botón apagado: el color solo no
## vale contra un fondo que cambia.
const _SHORT := Color(0.9098039, 0.23137255, 0.23137255)
## El fondo de la fila elegida. Lo que se escriba encima tiene que cambiar a
## esto: el rótulo del precio es un hijo aparte y no lo alcanza el color de
## "pulsado" del botón.
const _INK := Color(0.14901961, 0.16470588, 0.17254902)

@export_group("Arsenal")
## Lo que está a la venta. Va en el inspector y no escrito en el código para
## poder mover el catálogo sin tocar nada. **El precio no está aquí**: es de cada
## recurso — ver [member UnitType.price]. Una lista de precios en paralelo daría
## dos sitios donde mirar y uno se quedaría viejo.
@export var vehicles_for_sale: Array[UnitType] = []
@export var weapons_for_sale: Array[WeaponType] = []

@onready var _funds: Label = $TopBar/Funds
@onready var _open_arsenal: Button = $BottomBar/Arsenal
@onready var _open_fleet: Button = $BottomBar/Fleet
@onready var _back: Button = $BottomBar/Back

@onready var _arsenal: Control = $Arsenal
@onready var _tab_vehicles: Button = $Arsenal/Tabs/Vehicles
@onready var _tab_weapons: Button = $Arsenal/Tabs/Weapons
@onready var _a_rows: VBoxContainer = $Arsenal/List/Rows
@onready var _a_row: Button = $Arsenal/List/Rows/Row
@onready var _a_detail: Control = $Arsenal/Detail
@onready var _a_prompt: Label = $Arsenal/Prompt
@onready var _a_icon: TextureRect = $Arsenal/Detail/Icon
@onready var _a_name: Label = $Arsenal/Detail/Name
@onready var _a_kind: Label = $Arsenal/Detail/Kind
@onready var _a_stats: VBoxContainer = $Arsenal/Detail/Stats
@onready var _a_stat: Control = $Arsenal/Detail/Stats/Stat
@onready var _a_power: Control = $Arsenal/Detail/Stats/Power
@onready var _a_bar: TextureRect = $Arsenal/Detail/Stats/Power/Bar
@onready var _a_price: Label = $Arsenal/Detail/Price
@onready var _a_buy: Button = $Arsenal/Detail/Buy

@onready var _fleet: Control = $Fleet
@onready var _f_rows: VBoxContainer = $Fleet/List/Rows
@onready var _f_row: Button = $Fleet/List/Rows/Row
@onready var _f_detail: Control = $Fleet/Detail
@onready var _f_name: Label = $Fleet/Detail/Name
@onready var _f_lines: VBoxContainer = $Fleet/Detail/Lines
@onready var _f_head: Label = $Fleet/Detail/Lines/Head
@onready var _f_line: Control = $Fleet/Detail/Lines/Line

## El panel abierto, o `null` si se está viendo el muelle. Uno o ninguno: los dos
## ocupan el mismo hueco.
var _panel: Control = null
## Lo que se está mirando en el arsenal: un [UnitType] o un [WeaponType].
var _item: Resource = null
var _ship: String = ""
## Dónde vive el hueco del icono. Se apunta al nacer porque colocar el dibujo
## dentro le mueve la posición al nodo.
var _icon_home: Vector2 = Vector2.ZERO


func enter() -> void:
	# Las plantillas viven **puestas** en la escena, con datos de muestra, para
	# poder colocarlas en el editor; la autoridad sobre su visibilidad es esto.
	for template: CanvasItem in [_a_row, _a_stat, _f_row, _f_head, _f_line]:
		template.hide()

	_open_arsenal.pressed.connect(_toggle.bind(_arsenal))
	_open_fleet.pressed.connect(_toggle.bind(_fleet))
	_back.pressed.connect(func() -> void: Screens.back())
	_back.disabled = not Screens.has_previous()

	# `toggled` y no `pressed`: con dos botones en grupo, `pressed` no dice cuál
	# quedó puesto — el que se apaga también avisa.
	_tab_vehicles.toggled.connect(_on_tab_toggled)
	_tab_weapons.toggled.connect(_on_tab_toggled)
	_a_buy.pressed.connect(_on_buy)

	_icon_home = _a_icon.position
	Campaign.changed.connect(_on_campaign_changed)
	_refresh_funds()
	_fill_arsenal()
	_fill_fleet()
	_show(null)


# --- Navegación entre los dos paneles -----------------------------------------

func _toggle(panel: Control) -> void:
	_show(null if _panel == panel else panel)


func _show(panel: Control) -> void:
	_panel = panel
	_arsenal.visible = panel == _arsenal
	_fleet.visible = panel == _fleet
	# El botón se queda hundido mientras su panel está abierto: es lo único que
	# dice de dónde salió lo que se está viendo.
	_open_arsenal.button_pressed = panel == _arsenal
	_open_fleet.button_pressed = panel == _fleet


# --- Dinero -------------------------------------------------------------------

func _on_campaign_changed() -> void:
	_refresh_funds()
	# Una compra cambia lo que se puede pagar y lo que ya está comprado, así que
	# la lista y la ficha dejan de ser ciertas en el mismo instante.
	_fill_arsenal()


func _refresh_funds() -> void:
	_funds.text = _money(Campaign.money)


## Separador de millares. A mano y no con formato del sistema: el idioma de la
## interfaz lo elige el juego, no la máquina donde corra.
func _money(amount: int) -> String:
	var digits := str(absi(amount))
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += "."
		out += digits[i]
	return ("-" if amount < 0 else "") + out


func _on_tab_toggled(on: bool) -> void:
	if on:
		_fill_arsenal()


# --- Arsenal ------------------------------------------------------------------

func _catalogue() -> Array:
	var out: Array = []
	if _tab_weapons.button_pressed:
		out.assign(weapons_for_sale)
	else:
		out.assign(vehicles_for_sale)
	return out


func _fill_arsenal() -> void:
	_clear(_a_rows, [_a_row])
	var still_listed := false
	for item: Resource in _catalogue():
		if item == null:
			continue
		var owned: bool = Campaign.owns(_id_of(item))
		var price: int = item.price
		var row := _spawn(_a_row, _a_rows) as Button
		row.text = str(item.display_name)
		var tag := row.get_node(^"Price") as Label
		tag.text = "EN FLOTA" if owned else _money(price)
		# El color se cambia por `font_color` y no tiñendo con `self_modulate`:
		# el segundo multiplica sobre el tan del tema y ensucia los dos casos.
		var tint := _TAN if owned or price <= Campaign.money else _SHORT
		tag.add_theme_color_override("font_color", tint)
		tag.set_meta(&"tint", tint)
		row.toggled.connect(_tint_price.bind(tag))
		row.button_pressed = item == _item
		# `self_modulate` y no `modulate`: lo comprado se apaga pero su rótulo
		# tiene que seguir leyéndose, que es justo lo que informa.
		row.self_modulate.a = 0.45 if owned else 1.0
		row.pressed.connect(_select.bind(item))
		still_listed = still_listed or item == _item
	# Cambiar de pestaña deja fuera lo que se estaba mirando: la ficha se queda
	# hablando de algo que ya no está en la lista.
	_select(_item if still_listed else null)


## El precio de la fila elegida, sobre el azul del hundido. Va aquí y no en el
## tema porque el rótulo es hijo del botón, y el color de "pulsado" del botón
## sólo alcanza a su propio texto.
func _tint_price(on: bool, tag: Label) -> void:
	tag.add_theme_color_override("font_color", _INK if on else tag.get_meta(&"tint", _TAN))


func _select(item: Resource) -> void:
	_item = item
	_a_detail.visible = item != null
	_a_prompt.visible = item == null
	if item == null:
		return
	var unit := item as UnitType
	var weapon := item as WeaponType
	_a_name.text = str(item.display_name)
	_place_icon(unit.portrait_icon if unit != null else weapon.ui_icon)
	_a_kind.text = _kind_of(item)
	# Sin nota de potencia no se enseña la barra: a cero diría "es malísimo", y lo
	# que pasa es que a un buque nadie le ha puesto nota. Ver [member UnitType.power].
	_a_power.visible = unit != null and unit.power > 0
	if unit != null:
		_fill_unit_stats(unit)
	else:
		_fill_weapon_stats(weapon)

	var owned: bool = Campaign.owns(_id_of(item))
	var price: int = item.price
	_a_price.text = "EN FLOTA" if owned else _money(price)
	_a_price.add_theme_color_override("font_color",
			_TAN if owned or price <= Campaign.money else _SHORT)
	_a_buy.disabled = owned or price > Campaign.money
	_a_buy.text = "COMPRADO" if owned else "COMPRAR"


## Coloca el icono a **zoom entero** y centrado en su hueco. Remuestrear pixel
## art a un tamaño común lo ensucia, así que lo que se ajusta es el aumento.
func _place_icon(art: Texture2D) -> void:
	_a_icon.texture = art
	if art == null:
		return
	var zoom := maxi(1, int(floorf(minf(
			_ICON_BOX.x / float(art.get_width()),
			_ICON_BOX.y / float(art.get_height())))))
	var used := Vector2(art.get_size()) * float(zoom)
	_a_icon.size = used
	_a_icon.position = (_icon_home + (_ICON_BOX - used) * 0.5).floor()


func _fill_unit_stats(unit: UnitType) -> void:
	_clear(_a_stats, [_a_stat, _a_power])
	_stat("BLINDAJE", str(int(unit.max_health)))
	var cannon: WeaponType = unit.cannon
	_stat("ARMA FIJA", "NINGUNA" if cannon == null else _cannon_text(unit, cannon))
	_stat("EVASION", "%d%%" % int(round(unit.ecm_evasion * 100.0)))
	# La potencia va la última de la columna: el contenedor reparte por orden de
	# hijo, y la plantilla nace antes que las filas que se le cuelgan encima.
	_a_stats.move_child(_a_power, -1)
	var bar := _a_bar.texture as AtlasTexture
	if bar != null:
		var frame: int = clampi(unit.power, 0, _POWER_STEPS - 1)
		bar.region = Rect2(0.0, frame * _POWER_BAR_H, bar.region.size.x, _POWER_BAR_H)


func _cannon_text(unit: UnitType, cannon: WeaponType) -> String:
	var label := str(cannon.short_name if cannon.short_name != "" else cannon.display_name)
	return label if unit.cannon_rounds <= 0 else "%s  x%d" % [label, unit.cannon_rounds]


func _fill_weapon_stats(weapon: WeaponType) -> void:
	_clear(_a_stats, [_a_stat, _a_power])
	_stat("BLANCOS", _targets_of(weapon))
	_stat("ALCANCE", "%d / %d" % [int(weapon.min_range), int(weapon.max_range)])
	_stat("IMPACTO", str(int(weapon.damage)))
	_stat("GUIA", ["NINGUNA", "RADAR", "CALOR"][int(weapon.seeker)])
	if weapon.salvo_size != 1:
		_stat("SALVA", "TODA" if weapon.salvo_size <= 0 else str(weapon.salvo_size))


func _stat(key: String, value: String) -> void:
	var row := _spawn(_a_stat, _a_stats)
	(row.get_node(^"Key") as Label).text = key
	(row.get_node(^"Value") as Label).text = value


func _kind_of(item: Resource) -> String:
	var unit := item as UnitType
	if unit != null:
		return "AERONAVE" if unit.domain == UnitType.Domain.AIR else "SUPERFICIE"
	var weapon := item as WeaponType
	return "CANON" if weapon.fire_mode == WeaponType.FireMode.SUSTAINED else "LANZABLE"


func _targets_of(weapon: WeaponType) -> String:
	match weapon.targets:
		1: return "AIRE"
		2: return "SUPERFICIE"
		_: return "AIRE / SUPERFICIE"


## Con qué nombre se apunta en el guardado. Por texto y no por ruta de archivo:
## un guardado no puede depender de dónde viva un `.tres` mañana — ver
## [member Campaign.unlocked].
func _id_of(item: Resource) -> String:
	return str(item.display_name)


func _on_buy() -> void:
	if _item == null:
		return
	# Cobrar, apuntar y avisar los hace [method Campaign.buy] de una vez, así que
	# aquí no hay nada que comprobar antes: si no llega, devuelve `false` y no ha
	# tocado nada.
	Campaign.buy(_id_of(_item), _item.price)


# --- Flota --------------------------------------------------------------------

func _fill_fleet() -> void:
	_clear(_f_rows, [_f_row])
	var ships: Array = PlayerFleet.ships()
	var first: Button = null
	for ship: String in ships:
		var row := _spawn(_f_row, _f_rows) as Button
		row.text = ship
		(row.get_node(^"Price") as Label).text = ""
		row.pressed.connect(_select_ship.bind(ship))
		first = row if first == null else first
	if first != null:
		first.button_pressed = true
	_select_ship(str(ships[0]) if not ships.is_empty() else "")


func _select_ship(ship: String) -> void:
	_ship = ship
	_f_detail.visible = ship != ""
	if ship == "":
		return
	_f_name.text = ship.to_upper()
	_clear(_f_lines, [_f_head, _f_line])

	_head("AERONAVES A BORDO")
	for entry: Dictionary in PlayerFleet.get_loadout(ship):
		_line(str(entry.get("display_name", "")),
				"%d / %d" % [int(entry["total"]) - int(entry["deployed"]), int(entry["total"])])

	# El pañol es lo que **desmonta la tienda de municiones**: cuánta cabe lo
	# decide el barco, así que se rellena aquí, mirando el barco, y no en una
	# pantalla aparte donde no se ve contra qué se está gastando.
	_head("PAÑOL")
	for weapon: WeaponType in PlayerFleet.available_weapons():
		if weapon == null:
			continue
		# Contra qué sirve, que es un dato de verdad. La **cantidad** todavía no
		# existe: enseñar un relleno en su sitio sería mentir sobre lo que hay.
		_line(str(weapon.display_name), _targets_of(weapon))


func _head(text: String) -> void:
	var label := _spawn(_f_head, _f_lines) as Label
	label.text = text


func _line(key: String, value: String) -> void:
	var row := _spawn(_f_line, _f_lines)
	(row.get_node(^"Key") as Label).text = key
	(row.get_node(^"Value") as Label).text = value


# --- Plantillas ---------------------------------------------------------------

## Una copia de la plantilla, visible y ya colgada del contenedor.
func _spawn(template: CanvasItem, into: Node) -> CanvasItem:
	var copy := template.duplicate() as CanvasItem
	copy.show()
	into.add_child(copy)
	return copy


## Vacía el contenedor **sin llevarse las plantillas**. `remove_child` antes de
## `queue_free`: el segundo sólo desengancha al final del fotograma, y hasta
## entonces el contenedor reparte sitio entre las filas viejas y las nuevas a la
## vez — justo mientras se está mirando.
func _clear(container: Node, templates: Array) -> void:
	for child in container.get_children():
		if templates.has(child):
			continue
		container.remove_child(child)
		child.queue_free()
