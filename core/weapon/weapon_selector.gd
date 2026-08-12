extends Node
class_name WeaponSelector

## Elige con qué arma se ataca, según a qué distancia está el blanco.
##
## Va colgado de la unidad y se apaga solo cuando el jugador toca la barra de
## armas: **mandar es suyo**. Vuelve a mandar cuando el arma que eligió se acaba
## o cuando cambia de blanco, que es cuando su elección ha dejado de significar
## algo.
##
## El orden lo da `Unit.get_weapons()` — cañón primero y después el armamento
## colgado, en el orden del `WeaponLoadout`. Aquí se recorre **de más alcance a
## menos**, que es como se pelea: se gasta primero lo que llega más lejos,
## porque lo que llega más cerca va a seguir sirviendo después y al revés no.
##
## Y hay una regla que no es preferencia sino física: **el alcance mínimo manda**.
## Un AMRAAM no se arma a bocajarro por mucho que sea lo único que quede; ahí
## sólo te sirve el cañón. Eso es lo que hace que el cañón importe.

## Cada cuánto se replantea, en segundos. No hace falta cada frame: entre dos
## revisiones un avión no cruza una banda entera, y así la barra de armas no
## parpadea con cada píxel.
@export var interval: float = 0.2

## ¿Manda esto, o eligió el jugador? Se apaga en cuanto toca un botón.
var automatic := true

var _unit: Unit
var _until_check: float = 0.0
## Contra qué blanco se hizo la última elección manual. `null` = se eligió sin
## tener ninguno, y entonces vale para el primero que llegue.
var _manual_target: Unit = null
## ¿La elección manual está todavía esperando blanco? Ver [method take_manual_control].
var _manual_pending := false


func _ready() -> void:
	_unit = get_parent() as Unit
	if _unit == null:
		return
	_unit.attack_target_changed.connect(_on_target_changed)
	_unit.ammo_changed.connect(_on_ammo_changed)


## El jugador eligió a mano: a partir de aquí no se le toca el arma.
##
## Si todavía no hay blanco, la elección queda **esperando** al que venga. Es el
## orden normal de las cosas —se elige el arma y después se pulsa al enemigo—, y
## darla por caducada al llegar el blanco era pisarle el arma justo al atacar.
func take_manual_control() -> void:
	automatic = false
	_manual_target = _unit.attack_target if _unit != null else null
	_manual_pending = not is_instance_valid(_manual_target)


func _on_target_changed(target: Unit) -> void:
	_until_check = 0.0
	if not automatic:
		if _manual_pending:
			# Éste es el blanco al que iba dirigida la elección. Deja de esperar y
			# se queda con él.
			_manual_target = target
			_manual_pending = false
			return
		if target == _manual_target:
			return
		# Otro blanco distinto: lo que se eligió era para el anterior.
		automatic = true
	_rearm_for(target)


## Blanco nuevo y manda el automático: hay que empezar con un arma que sirva
## contra **esto**, no con la que quedó puesta de lo anterior.
##
## Sin esto, salir de un duelo aéreo con el cañón activo y mandar al avión contra
## un blanco de tierra lo dejaba ametrallando en vez de bombardeando: el ataque a
## tierra no reelige arma —lo eliges tú— así que nadie deshacía lo que el combate
## aéreo había dejado a medias.
func _rearm_for(target: Unit) -> void:
	if not is_instance_valid(target) or _unit == null:
		return
	var pick := best_for(target)
	if pick == null:
		# Todavía fuera de alcance de todo: al menos, lo que el armamento tenga
		# por principal. Es con lo que la unidad salió armada.
		pick = _unit.get_default_weapon()
	if pick != null and pick.can_engage_domain(target.get_domain()):
		_unit.set_active_weapon(pick)


## Se acabó lo que el jugador había elegido: vuelve a mandar el automático, o el
## avión se quedaría con un arma vacía sin disparar.
func _on_ammo_changed(weapon: WeaponType, remaining: int) -> void:
	if remaining == 0 and weapon == _unit.active_weapon:
		automatic = true


func _physics_process(delta: float) -> void:
	if automatic == false or _unit == null:
		return
	_until_check -= delta
	if _until_check > 0.0:
		return
	_until_check = maxf(interval, 0.05)
	# **Sólo contra lo que vuela.** En un duelo aéreo las bandas se suceden en
	# segundos y no hay tiempo de elegir a mano; contra tierra el jugador decide
	# con qué ataca y cambiárselo por su cuenta es quitarle el mando.
	if not is_instance_valid(_unit.attack_target) \
			or _unit.attack_target.get_domain() != UnitType.Domain.AIR:
		return
	var pick := best_for(_unit.attack_target)
	if pick != null:
		_unit.set_active_weapon(pick)


## Qué arma toca para ese blanco, o `null` si ninguna llega. Público para que se
## pueda preguntar sin esperar al siguiente repaso.
##
## Devolver `null` y no cambiar nada es deliberado: si el blanco está fuera de
## todas las envolventes, cambiar de arma no acerca el disparo y sólo haría
## parpadear la barra. Se deja la que hubiera y el vuelo sigue acercándose con su
## envolvente, que es lo que hace falta para llegar a tiro.
func best_for(target: Unit) -> WeaponType:
	if not is_instance_valid(target):
		return null
	var distance := _unit.global_position.distance_to(target.global_position)
	var domain := target.get_domain()
	var against_air := domain == UnitType.Domain.AIR
	var cannon := _unit.unit_type.cannon if _unit.unit_type != null else null
	var best: WeaponType = null
	var fallback: WeaponType = null
	for weapon in _unit.get_weapons():
		if not _usable(weapon, target, distance, against_air):
			continue
		# **El cañón es siempre el último recurso.** Mientras un misil llegue, se
		# tira el misil: contra tierra porque resuelve el blanco de una, y contra
		# un avión porque su alcance en el papel —el mismo con el que ametralla
		# tanques— no es el alcance al que se acierta a algo que se mueve.
		#
		# Y de aquí sale gratis lo que se buscaba: a quemarropa **ningún misil
		# llega** —el AIM-9 se planta a 130— así que el cañón entra solo, sin
		# ninguna regla que diga "usa el cañón cuando estés encima".
		if weapon == cannon:
			fallback = weapon
			continue
		if best == null or _closer_fit(weapon, best, against_air):
			best = weapon
	return best if best != null else fallback


## ¿Se puede tirar esta arma ahora mismo contra ese blanco?
##
## Lo mismo que comprueba el armamento antes de disparar. Se repite aquí porque
## si no, el selector elegiría un arma que luego no va a poder tirar y el avión
## se quedaría enfilando sin apretar nunca el gatillo.
func _usable(weapon: WeaponType, target: Unit, distance: float, against_air: bool) -> bool:
	if not weapon.can_engage_domain(target.get_domain()) or not _unit.has_ammo(weapon):
		return false
	if not weapon.in_range_against(distance, target.get_domain()):
		return false
	# El ángulo sólo cuenta contra algo que vuela: un tanque no tiene cola.
	if not against_air or not weapon.needs_rear_aspect():
		return true
	return WeaponType.aspect_to(_unit.global_position, target) <= weapon.max_aspect_deg


## ¿Encaja mejor `candidate` que `current` para la situación de ahora?
##
##   - **Contra un avión**, la que menos lejos llega: las envolventes están
##     pensadas para no solaparse apenas, así que la de menor alcance es la de
##     esta banda. Es lo que hace que, ya metido en la cola, se use el AIM-9 en
##     vez de quemar un AMRAAM — y el cañón cuando se está encima.
##   - **Contra tierra**, la que más lejos llega: se tira desde fuera del alcance
##     de lo que sea que defienda el blanco, que es de lo que va hacer pasadas.
func _closer_fit(candidate: WeaponType, current: WeaponType, against_air: bool) -> bool:
	# Con el alcance QUE APLICA a este blanco: el cañón llega mucho más lejos
	# contra tierra que contra algo que se mueve, y compararlo por su alcance de
	# tierra lo hacía parecer un arma de media distancia en el aire.
	if against_air:
		return candidate.max_range_against(UnitType.Domain.AIR) \
			< current.max_range_against(UnitType.Domain.AIR)
	return candidate.max_range > current.max_range
