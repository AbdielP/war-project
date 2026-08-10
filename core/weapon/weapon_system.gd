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
##
## **Un arma sostenida nunca la emite**, y ahí está toda la diferencia de vuelo
## entre pegar un tiro y hacer una pasada de ametrallamiento: con el cañón no
## hay nada en camino que esperar, así que el avión sigue metiéndose y rompe
## cuando la distancia le obliga, no cuando aprieta el gatillo.
signal fired(weapon: WeaponType)

## Abrió fuego sostenido. Lo escuchan los efectos — fogonazo, humo, trazadora —,
## que no saben de armas ni de blancos: sólo de que ahora sale fuego.
signal firing_started
## Alto el fuego.
signal firing_stopped

@export_group("Enlace")
@export var rack_path: NodePath = ^"../Hardpoints"

var _unit: Unit
var _rack: HardpointRack
var _cooldown: float = 0.0
## Lo que este sistema tiene volando ahora mismo. Se vacía solo: los
## proyectiles se liberan al explotar.
var _in_flight: Array[Node] = []
## ¿Está el gatillo apretado? Sólo con armas sostenidas.
var _firing := false
## ¿Hay permiso para tirar? Lo quita quien lleva el vuelo mientras el avión no
## está en la pasada. Arranca en `true`: una unidad que no hace pasadas — un
## tanque, un barco — dispara cuando puede y no espera permiso de nadie.
var _cleared_to_fire := true
## Lo que queda de la ráfaga en curso y del silencio que la sigue. A 0 los dos
## con un arma sin ráfagas: no se usan.
var _burst_left: float = 0.0
var _pause_left: float = 0.0
## Ristra en curso: armas que quedan por soltar de la andanada, y cuánto falta
## para la siguiente. Una andanada escalonada no son N disparos sueltos — es un
## solo disparo que dura, y se termina aunque cambien las condiciones a mitad.
var _stick_left: int = 0
var _stick_timer: float = 0.0
var _stick_launched: int = 0
var _stick_weapon: WeaponType = null
var _stick_target: Unit = null


func _ready() -> void:
	_unit = get_parent() as Unit
	_rack = get_node_or_null(rack_path) as HardpointRack


## Encender o apagar el armamento. Arranca encendido — lo normal es que una
## unidad pueda defenderse —, pero las que tienen un estado en el que no
## combaten lo apagan: un avión en cubierta no dispara aunque tenga la orden.
func set_active(value: bool) -> void:
	set_physics_process(value)
	if not value:
		# Apagar el armamento con el gatillo apretado dejaría el cañón
		# escupiendo fuego para siempre: nadie va a volver a pasar por aquí.
		_release_trigger()
		# Y una ristra a medias se quedaría esperando un frame que ya no llega.
		# Aquí sí se corta: el avión aterrizó o murió, no hay pasada que acabar.
		_stick_left = 0
		_stick_launched = 0
		_stick_weapon = null
		_stick_target = null


## Autoriza o corta el fuego sin apagar el armamento. Es lo que separa APUNTAR de
## PODER TIRAR: el avión enfila la pasada, y sólo mientras dura esa pasada tiene
## permiso. En cuanto rompe y se va virando, el morro le va barriendo el paisaje
## y cruza el blanco de refilón una y otra vez — con permiso, soltaría un tiro en
## cada barrido y la pasada parecería un baile en vez de un ametrallamiento.
func set_cleared_to_fire(value: bool) -> void:
	if _cleared_to_fire == value:
		return
	_cleared_to_fire = value
	if not value:
		_release_trigger()


## A qué distancia se está tirando ahora mismo, o 0 si no hay a quién. Lo usan
## los efectos que necesitan saber dónde acaba el tiro y no sólo que lo hay.
func get_firing_distance() -> float:
	if _unit == null or not is_instance_valid(_unit.attack_target):
		return 0.0
	return _unit.global_position.distance_to(_unit.attack_target.global_position)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_forget_spent_shots()
	if _unit == null:
		return

	# Una ristra empezada se termina. Ni el permiso de tiro ni que el blanco
	# muera la interrumpen: las bombas ya están saliendo del avión, y cortarla a
	# medias dejaría media carga colgada del ala sin que nadie pueda soltarla.
	if _stick_left > 0:
		_work_the_stick(delta)
		return

	var weapon := _unit.active_weapon
	# A `null` en cuanto deja de existir, y no sólo "ya se comprobará luego": una
	# referencia liberada NO es `null` y sigue teniendo tipo, así que pasarla a
	# una función que espera `Unit` revienta al entrar, antes de que nadie pueda
	# comprobar nada. Pasa de verdad: el blanco puede morir entre dos frames y
	# quien lo apuntaba tarda en enterarse.
	var target: Unit = _unit.attack_target if is_instance_valid(_unit.attack_target) else null

	if weapon != null and weapon.fire_mode == WeaponType.FireMode.SUSTAINED:
		_work_the_trigger(weapon, target, delta)
		return

	# Cambió a un arma que se lanza: lo que hubiera abierto se cierra aquí, o el
	# fogonazo se quedaría encendido al cambiar de cañón a misil disparando.
	_release_trigger()

	if _cooldown > 0.0 or not _in_flight.is_empty():
		return
	if not is_instance_valid(target) or not target.is_alive():
		return
	if can_fire_at(target):
		_fire_salvo(target)


## Fuego sostenido: abrir o cerrar el gatillo y, mientras esté abierto, ir
## repartiendo el daño de la ráfaga.
##
## No hay andanadas ni recarga: hay un chorro que dura lo que dure la ocasión de
## tirar. Por eso tampoco se emite `fired` — no hay nada en el aire que esperar.
func _work_the_trigger(weapon: WeaponType, target: Unit, delta: float) -> void:
	if not _should_hold_trigger(weapon, target):
		_release_trigger()
		_burst_left = 0.0
		_pause_left = 0.0
		return
	if not _work_the_burst(weapon, delta):
		return
	if not _firing:
		_firing = true
		firing_started.emit()
	_pour_rounds(weapon, target, delta)


## Corta el chorro en ráfagas, si el arma las pide. Devuelve si toca tirar en
## este momento.
##
## Con `burst_seconds` a 0 no hay nada que cortar y siempre toca: es el cañón del
## avión, cuya ráfaga la delimita la pasada. Con un valor por encima, el arma
## alterna sola entre tirar y callar, y el silencio importa tanto como el fuego —
## es el hueco por el que se cuela el avión.
func _work_the_burst(weapon: WeaponType, delta: float) -> bool:
	if weapon.burst_seconds <= 0.0:
		return true
	if _pause_left > 0.0:
		_pause_left -= delta
		# Se suelta el gatillo al entrar en la pausa, no al salir: los efectos se
		# enteran de que hay que apagar el fogonazo por la misma señal de
		# siempre, sin saber que existen las ráfagas.
		_release_trigger()
		return false
	if _burst_left <= 0.0:
		_burst_left = weapon.burst_seconds
	_burst_left -= delta
	if _burst_left <= 0.0:
		_pause_left = weapon.burst_pause
	return true


func _release_trigger() -> void:
	if not _firing:
		return
	_firing = false
	firing_stopped.emit()


## ¿Hay ocasión de tirar ahora mismo? Igual que `can_fire_at` pero sin exigir
## proyectil — un cañón no tiene — y con el cono ensanchado si ya se está
## disparando, para que la ráfaga no salga a tirones.
func _should_hold_trigger(weapon: WeaponType, target: Unit) -> bool:
	if not _cleared_to_fire:
		return false
	if not is_instance_valid(target) or not target.is_alive():
		return false
	if not _in_parameters(weapon, target):
		return false
	var arc := deg_to_rad(weapon.firing_arc_deg)
	if _firing:
		arc *= maxf(1.0, weapon.arc_hysteresis)
	return _off_axis(target) <= arc


## Reparte lo que ha soltado el arma en este frame. Se cuenta en proyectiles y
## no en "daño por segundo" para que `damage` siga significando lo de siempre:
## lo que hace UNA bala. Cuántas de ellas entran lo dice la geometría.
func _pour_rounds(weapon: WeaponType, target: Unit, delta: float) -> void:
	var rounds := weapon.rounds_per_second * delta
	var hits := rounds * _hit_fraction(weapon, target)
	if hits > 0.0:
		target.take_damage(weapon.damage * hits, _unit)


## Qué fracción de la ráfaga entra, de 0 a 1. Dos cosas la bajan, y las dos son
## la misma: cuánto se abre el cono de balas para cuando llega al blanco.
##
##   - La DISTANCIA. De cerca la dispersión no ha tenido sitio para abrirse y
##     entra casi todo; en el borde del alcance el grupo es más ancho que el
##     blanco y la mayoría pasa de largo.
##   - La PUNTERÍA. Centrado en el morro entra todo; rozando el borde del cono
##     de tiro, sólo pilla el rabo de la ráfaga.
##
## Fuera del cono da 0: se sigue viendo el fogonazo, pero no acierta nada. Eso
## es lo que pasa de verdad cuando se aguanta el gatillo sin apuntar.
func _hit_fraction(weapon: WeaponType, target: Unit) -> float:
	var distance := _unit.global_position.distance_to(target.global_position)
	var reach := clampf(
		inverse_lerp(weapon.min_range, maxf(weapon.max_range, weapon.min_range + 1.0),
			distance), 0.0, 1.0)
	var by_distance := lerpf(1.0, weapon.long_range_accuracy, reach)

	var arc := deg_to_rad(maxf(weapon.firing_arc_deg, 0.01))
	var by_aim := clampf(1.0 - _off_axis(target) / arc, 0.0, 1.0)

	return by_distance * by_aim


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
	if not _cleared_to_fire:
		return false
	var weapon := _unit.active_weapon
	if weapon == null or weapon.projectile_scene == null:
		return false
	if not _in_parameters(weapon, target):
		return false
	# El armamento sale hacia adelante: hay que enfilar antes de soltarlo.
	return _off_axis(target) <= deg_to_rad(weapon.firing_arc_deg)


## Lo que da igual cómo se dispare: que el arma sirva contra ese medio, que
## quede munición y que la distancia dé. Lo comparten el lanzador y el cañón,
## que sólo se separan en el ángulo y en lo que pasa después.
func _in_parameters(weapon: WeaponType, target: Unit) -> bool:
	if not weapon.can_engage_domain(target.get_domain()):
		return false
	if not _unit.has_ammo(weapon):
		return false
	return weapon.in_range(_unit.global_position.distance_to(target.global_position))


## Cuánto se sale el blanco del morro, en radianes.
func _off_axis(target: Unit) -> float:
	var to_target := target.global_position - _unit.global_position
	return absf(angle_difference(_unit.get_facing(), to_target.angle()))


## Suelta una andanada entera. Cuántas van es del arma: un misil antitanque
## sale de uno en uno, una carga de bombas sale completa en una pasada.
func _fire_salvo(target: Unit) -> void:
	var weapon := _unit.active_weapon
	var count := weapon.salvo_size
	if count <= 0:
		# 0 = todo lo que quede. Un arma sin límite (el cañón) no puede vaciar
		# nada, así que dispara una.
		count = maxi(1, _unit.get_ammo(weapon))
	_cooldown = weapon.reload_time

	if weapon.salvo_interval > 0.0:
		_start_the_stick(weapon, target, count)
		return

	var launched := 0
	for _i in count:
		if not _fire_one(target, weapon):
			break
		launched += 1
	if launched > 0:
		fired.emit(weapon)


## Empieza una ristra: la primera sale ya y el resto van cayendo solas.
func _start_the_stick(weapon: WeaponType, target: Unit, count: int) -> void:
	_stick_weapon = weapon
	_stick_target = target
	_stick_left = count
	_stick_launched = 0
	_stick_timer = 0.0
	# Con el reloj a cero la primera sale en este mismo frame: esperar el
	# intervalo antes de la primera retrasaría la ristra entera medio palmo.
	_work_the_stick(0.0)


## Suelta lo que toque de la ristra. El `while` es por lo mismo que en las
## trazadoras: con intervalos por debajo del frame hay que soltar más de una en
## el mismo tick, y lo que sobra se arrastra al siguiente en vez de perderse.
func _work_the_stick(delta: float) -> void:
	_stick_timer -= delta
	while _stick_left > 0 and _stick_timer <= 0.0:
		if not _fire_one(_stick_target, _stick_weapon):
			# Se acabó la munición a mitad de ristra: lo que quedaba no existe.
			_stick_left = 0
			break
		_stick_left -= 1
		_stick_launched += 1
		_stick_timer += maxf(_stick_weapon.salvo_interval, 0.001)
	if _stick_left <= 0:
		_close_the_stick()


## Se soltó la última. **`fired` se emite aquí y no con la primera**, y de eso
## depende toda la pasada de bombardeo: el vuelo rompe al oírlo, así que
## anunciarlo con la primera pondría al avión a virar con cinco bombas todavía
## colgadas, y saldrían abanicadas hacia donde ya no está el blanco.
func _close_the_stick() -> void:
	var weapon := _stick_weapon
	var launched := _stick_launched
	_stick_left = 0
	_stick_launched = 0
	_stick_weapon = null
	_stick_target = null
	if launched > 0 and weapon != null:
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
