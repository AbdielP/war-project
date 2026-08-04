extends Node
class_name WeaponSystem

## Decide CUÁNDO se dispara. Es el tercer hermano de `OrbitBehavior` y
## `AttackRunBehavior`: ellos llevan al avión hasta el blanco, este comprueba
## si desde aquí se puede tirar y tira.
##
## No decide a quién se ataca — eso es la orden, y vive en `Unit` — ni cómo
## vuela lo que dispara — eso es el `Projectile`. Sólo mira si se dan las
## condiciones: arma que sirva contra ese blanco, munición, distancia, ángulo
## y que no haya ya algo suyo en el aire.
##
## Esa última condición es la que hace que un arma de una en una se comporte
## como debe: se lanza un misil, se espera a ver si el blanco muere, y sólo si
## sigue vivo sale el siguiente. Nadie tuvo que programar "reevaluar tras el
## impacto" — sale de no malgastar munición mientras hay algo en camino.

## Acaba de soltar una andanada. Quien lleve el vuelo la usa para romper el
## ataque: seguir metiéndose hacia un blanco al que ya le mandaste un arma en
## camino no aporta nada y tira por la borda la ventaja del alcance.
signal fired(weapon: WeaponType)

@export_group("Enlace")
@export var rack_path: NodePath = ^"../Hardpoints"

var _unit: Unit
var _rack: HardpointRack
var _cooldown: float = 0.0
## Lo que este sistema tiene volando ahora mismo. Se vacía solo: los
## proyectiles se liberan al explotar.
var _in_flight: Array[Node] = []


func _ready() -> void:
	_unit = get_parent() as Unit
	_rack = get_node_or_null(rack_path) as HardpointRack


## Encender o apagar el armamento. Arranca encendido — lo normal es que una
## unidad pueda defenderse —, pero las que tienen un estado en el que no
## combaten lo apagan: un avión en cubierta no dispara aunque tenga la orden.
func set_active(value: bool) -> void:
	set_physics_process(value)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_forget_spent_shots()
	if _unit == null or _cooldown > 0.0 or not _in_flight.is_empty():
		return
	var target := _unit.attack_target
	if not is_instance_valid(target) or not target.is_alive():
		return
	if can_fire_at(target):
		_fire_salvo(target)


## Segundos que falta para que llegue lo que tiene en el aire, o -1 si no hay
## nada volando. Con varias armas en camino manda la primera en llegar: es la
## que decide cuándo se sabrá el resultado.
func time_to_impact() -> float:
	var soonest := -1.0
	for node in _in_flight:
		# La lista se limpia en el proceso de física, pero quien pregunta puede
		# hacerlo antes: entre que un arma explota y aquí se la olvida hay un
		# hueco en el que la referencia sigue en la lista y ya no vale nada.
		if not is_instance_valid(node):
			continue
		var projectile := node as Projectile
		if projectile == null:
			continue
		var eta := projectile.time_to_impact()
		if eta >= 0.0 and (soonest < 0.0 or eta < soonest):
			soonest = eta
	return soonest


## ¿Se dan las condiciones para tirar contra ese blanco ahora mismo? No mira
## munición en vuelo ni recarga: eso es cadencia, no puntería.
func can_fire_at(target: Unit) -> bool:
	var weapon := _unit.active_weapon
	if weapon == null or weapon.projectile_scene == null:
		return false
	if not weapon.can_engage_domain(target.get_domain()):
		return false
	if not _unit.has_ammo(weapon):
		return false
	var to_target := target.global_position - _unit.global_position
	if not weapon.in_range(to_target.length()):
		return false
	# El armamento sale hacia adelante: hay que enfilar antes de soltarlo.
	var off_axis := absf(angle_difference(_unit.get_facing(), to_target.angle()))
	return off_axis <= deg_to_rad(weapon.firing_arc_deg)


## Suelta una andanada entera. Cuántas van es del arma: un misil antitanque
## sale de uno en uno, una carga de bombas sale completa en una pasada.
func _fire_salvo(target: Unit) -> void:
	var weapon := _unit.active_weapon
	var count := weapon.salvo_size
	if count <= 0:
		# 0 = todo lo que quede. Un arma sin límite (el cañón) no puede vaciar
		# nada, así que dispara una.
		count = maxi(1, _unit.get_ammo(weapon))
	var launched := 0
	for _i in count:
		if not _fire_one(target, weapon):
			break
		launched += 1
	_cooldown = weapon.reload_time
	if launched > 0:
		fired.emit(weapon)


func _fire_one(target: Unit, weapon: WeaponType) -> bool:
	if not _unit.spend_ammo(weapon):
		return false
	# Sale de la estación donde estaba colgada. Si el rack ya no tiene sprite
	# que descolgar — porque la estación llevaba más armas de las que caben
	# dibujadas — sale del centro de la unidad antes que no salir.
	var muzzle: Node2D = _rack.release(weapon) if _rack != null else null
	if muzzle == null:
		muzzle = _unit
	var projectile := weapon.projectile_scene.instantiate() as Projectile
	if projectile == null:
		return false
	# Cuelga del mismo sitio que la unidad: una vez fuera del ala ya no
	# pertenece al avión, y si el avión muere el misil sigue su camino.
	_unit.get_parent().add_child(projectile)
	projectile.launch(_unit, muzzle, target, weapon, _dispersion(weapon))
	_in_flight.append(projectile)
	return true


## Desvío del punto de apuntado de cada arma de la andanada. Es lo que hace
## que una tirada de bombas bata un área en vez de clavar todo en el mismo
## píxel; un arma de precisión no dispersa.
func _dispersion(weapon: WeaponType) -> Vector2:
	if weapon.salvo_spread <= 0.0:
		return Vector2.ZERO
	# La raíz reparte los puntos por igual en todo el círculo. Sin ella se
	# amontonarían en el centro, que es justo lo contrario de dispersar.
	var distance := sqrt(randf()) * weapon.salvo_spread
	return Vector2.RIGHT.rotated(randf() * TAU) * distance


func _forget_spent_shots() -> void:
	for i in range(_in_flight.size() - 1, -1, -1):
		if not is_instance_valid(_in_flight[i]):
			_in_flight.remove_at(i)
