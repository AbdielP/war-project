extends Area2D
class_name Unit

## Grupo al que pertenece toda unidad, del bando que sea. Quien tenga que
## barrer el mapa — una explosión buscando a quién alcanzar — mira aquí en vez
## de recorrer el árbol entero.
const GROUP := &"units"

@export var unit_type: UnitType
@export var unit_name: String = ""
## Bando. En la instancia y no en el `UnitType` a propósito: el mismo modelo
## puede ser enemigo en una misión y aliado en otra.
@export var team: Team.Side = Team.Side.PLAYER

signal active_weapon_changed(weapon: WeaponType)
## Se gastó munición de un arma. `remaining` es lo que queda, -1 si es
## ilimitada. Lo escucha la barra de armas para no tener que preguntar cada
## frame por algo que cambia de tarde en tarde.
signal ammo_changed(weapon: WeaponType, remaining: int)
signal attack_target_changed(target: Unit)
## Se emite antes de quitarla del mapa, para que quien la estuviera siguiendo
## se entere mientras todavía existe.
signal died(unit: Unit)

var squad: Squad = null  # null = unidad suelta, sin escuadrón
var weapon_loadout: WeaponLoadout = null  # null = unidad desarmada
var active_weapon: WeaponType = null  # con qué ataca ahora mismo
var attack_target: Unit = null  # a quién ataca; null = a nadie
var health: float = 0.0

@onready var _selection_indicator: Node2D = $SelectionIndicator

var _selected := false
var _targeted := false


func _ready() -> void:
	add_to_group(GROUP)
	health = get_max_health()
	_selection_indicator.visible = false
	_selection_indicator.color = Team.color(team)
	# Una unidad puesta a mano en el mapa nunca pasa por set_weapon_loadout,
	# pero si tiene cañón ya puede atacar con él.
	if active_weapon == null:
		set_active_weapon(get_default_weapon())


func set_selected(value: bool) -> void:
	_selected = value
	_refresh_indicator()


## Marcarla como el objetivo que se está mostrando. Es una vista de lo que hay
## seleccionado, no un estado de la unidad: quien la marca es `SelectionManager`
## y la apaga al deseleccionar. Se dibuja con el color de su propio bando, así
## que un enemigo apuntado sale en rojo.
func set_targeted(value: bool) -> void:
	_targeted = value
	_refresh_indicator()


func _refresh_indicator() -> void:
	_selection_indicator.visible = _selected or _targeted


## ¿Obedece órdenes del jugador? Las aliadas son de su bando pero las mueve la
## IA, así que tampoco. Seleccionar es otra cosa: cualquier unidad se puede
## seleccionar para ver qué es o para atacarla.
func is_player_controlled() -> bool:
	return team == Team.Side.PLAYER


func is_hostile_to(other: Unit) -> bool:
	return other != null and Team.are_hostile(team, other.team)


## En qué medio se mueve: decide qué armas pueden atacarla.
func get_domain() -> UnitType.Domain:
	return unit_type.domain if unit_type else UnitType.Domain.SURFACE


func get_max_health() -> float:
	return unit_type.max_health if unit_type else 100.0


func is_alive() -> bool:
	return health > 0.0


## Encajar daño. Morir la borra del mapa; quien la tuviera apuntada se entera
## por `died` o porque su referencia deja de ser válida.
func take_damage(amount: float) -> void:
	if amount <= 0.0 or not is_alive():
		return
	health = maxf(0.0, health - amount)
	if health <= 0.0:
		died.emit(self)
		queue_free()


## Hacia dónde mira, en radianes de mundo. Es de dónde sale el armamento y
## hacia dónde apunta al lanzarlo. Por defecto la rotación del nodo; las
## unidades cuyo arte no apunta hacia adelante lo corrigen aquí.
func get_facing() -> float:
	return global_rotation


## Lo que se lleva el armamento al soltarse. Una unidad quieta no le da nada.
func get_velocity() -> Vector2:
	return Vector2.ZERO


## A qué velocidad deja la cubierta al despegar. Lo pregunta el portaaviones
## para acelerarla por la pista hasta ahí y soltarla justo a esa velocidad. Las
## unidades que no vuelan no despegan, así que no tienen ninguna.
func get_takeoff_speed() -> float:
	return 0.0


## Segundos hasta que impacte lo que tenga disparado, o -1 si no tiene nada en
## el aire. Las unidades armadas lo delegan en su sistema de armas.
func get_time_to_impact() -> float:
	return -1.0


func get_display_name() -> String:
	if unit_name != "":
		return unit_name
	return tr(unit_type.display_name) if unit_type else ""


func get_actions() -> PackedStringArray:
	return unit_type.actions if unit_type else []


## Arma la unidad. Las unidades sin HardpointRack lo guardan igual: llevar
## armamento y saber dibujarlo son cosas distintas.
##
## Se queda con una COPIA: lo que llega es la configuración del catálogo, que
## comparten todas las unidades del mismo modelo. Si no se clonara, gastar un
## misil aquí se lo quitaría a los demás aviones de la flota y no volvería
## nunca. Clonar aquí y no en quien llama es lo que hace que no se pueda
## olvidar.
func set_weapon_loadout(value: WeaponLoadout) -> void:
	weapon_loadout = value.clone() if value != null else null
	for child in get_children():
		var rack := child as HardpointRack
		if rack != null:
			rack.apply_loadout(weapon_loadout)
	# El arma activa que hubiera puede no estar en el armamento nuevo.
	set_active_weapon(get_default_weapon())


## Cuántas quedan de esa arma. El cañón no cuelga de ninguna estación: por
## ahora no se gasta.
func get_ammo(weapon: WeaponType) -> int:
	if weapon == null:
		return 0
	if unit_type != null and weapon == unit_type.cannon:
		return -1  # sin límite
	return weapon_loadout.ammo_of(weapon) if weapon_loadout != null else 0


func has_ammo(weapon: WeaponType) -> bool:
	return get_ammo(weapon) != 0


## Descuenta una. Devuelve si había con qué disparar.
func spend_ammo(weapon: WeaponType) -> bool:
	if get_ammo(weapon) == -1:
		return true
	if weapon_loadout == null or not weapon_loadout.spend(weapon):
		return false
	ammo_changed.emit(weapon, get_ammo(weapon))
	return true


## Con qué arma sale seleccionada la unidad: la principal de su armamento y,
## si va desarmada, el cañón.
func get_default_weapon() -> WeaponType:
	if weapon_loadout != null:
		var main := weapon_loadout.get_default_weapon()
		if main != null:
			return main
	var weapons := get_weapons()
	return weapons[0] if not weapons.is_empty() else null


## Con qué puede atacar esta unidad: el cañón primero — va siempre y no ocupa
## estación — y después un arma por tipo colgado. Un tipo montado en dos
## estaciones es un solo botón, no dos.
func get_weapons() -> Array[WeaponType]:
	var weapons: Array[WeaponType] = []
	if unit_type != null and unit_type.cannon != null:
		weapons.append(unit_type.cannon)
	if weapon_loadout != null:
		for mount in weapon_loadout.mounts:
			if mount.weapon != null and not weapons.has(mount.weapon):
				weapons.append(mount.weapon)
	return weapons


func set_active_weapon(weapon: WeaponType) -> void:
	if active_weapon == weapon:
		return
	active_weapon = weapon
	active_weapon_changed.emit(weapon)


## Moverse a un punto cancela el ataque en curso: son órdenes que compiten por
## el mismo destino. Las subclases que se mueven llaman a `super()` y luego
## resuelven el cómo.
func receive_move_order(_target: Vector2) -> void:
	set_attack_target(null)


## Atacar a otra unidad. Acercarse, apuntar y disparar dependen del arma y del
## tipo de unidad — un tanque y un avión no lo hacen igual —, así que aquí sólo
## se registra a quién. El cómo lo resuelve cada subclase.
func receive_attack_order(target: Unit) -> void:
	set_attack_target(target)


## Único sitio que toca `attack_target`: avisar tiene que pasar siempre, venga
## de una orden o de que el objetivo desapareció.
func set_attack_target(target: Unit) -> void:
	# Un objeto liberado se compara igual a `null`, así que la salida temprana
	# sólo es de fiar entre objetivos vivos: si el anterior murió hay que dejar
	# pasar el cambio aunque los dos "parezcan" nulos, o nadie se entera de que
	# el ataque terminó.
	if is_instance_valid(attack_target) and attack_target == target:
		return
	attack_target = target if is_instance_valid(target) else null
	attack_target_changed.emit(attack_target)
