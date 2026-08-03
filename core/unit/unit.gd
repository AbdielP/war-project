extends Area2D
class_name Unit

@export var unit_type: UnitType
@export var unit_name: String = ""
## Bando. En la instancia y no en el `UnitType` a propósito: el mismo modelo
## puede ser enemigo en una misión y aliado en otra.
@export var team: Team.Side = Team.Side.PLAYER

signal active_weapon_changed(weapon: WeaponType)
signal attack_target_changed(target: Unit)

var squad: Squad = null  # null = unidad suelta, sin escuadrón
var weapon_loadout: WeaponLoadout = null  # null = unidad desarmada
var active_weapon: WeaponType = null  # con qué ataca ahora mismo
var attack_target: Unit = null  # a quién ataca; null = a nadie

@onready var _selection_indicator: Node2D = $SelectionIndicator

var _selected := false
var _targeted := false


func _ready() -> void:
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


func get_display_name() -> String:
	if unit_name != "":
		return unit_name
	return tr(unit_type.display_name) if unit_type else ""


func get_actions() -> PackedStringArray:
	return unit_type.actions if unit_type else []


## Arma la unidad. Las unidades sin HardpointRack lo guardan igual: llevar
## armamento y saber dibujarlo son cosas distintas.
func set_weapon_loadout(value: WeaponLoadout) -> void:
	weapon_loadout = value
	for child in get_children():
		var rack := child as HardpointRack
		if rack != null:
			rack.apply_loadout(value)
	# El arma activa que hubiera puede no estar en el armamento nuevo.
	set_active_weapon(get_default_weapon())


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
