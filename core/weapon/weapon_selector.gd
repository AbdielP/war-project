extends Node
class_name WeaponSelector

## Elige con qué arma se ataca, según a qué distancia está el blanco.
##
## Va colgado de la unidad y se apaga solo cuando el jugador toca la barra de
## armas: **mandar es suyo**, y no se le devuelve por cambiar de objetivo. Sólo
## vuelve a mandar cuando lo que eligió **no puede dispararse** contra el blanco
## nuevo: se acabó, o no sirve contra ese medio. Que otra arma encaje mejor no
## cuenta — eso es preferencia, y la preferencia es del jugador.
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


func _ready() -> void:
	_unit = get_parent() as Unit
	if _unit == null:
		return
	_unit.attack_target_changed.connect(_on_target_changed)
	_unit.ammo_changed.connect(_on_ammo_changed)


## El jugador eligió a mano: a partir de aquí no se le toca el arma.
##
## No hace falta apuntar para qué blanco se eligió. Antes sí —la elección valía
## para ese objetivo y caducaba con él—, y por eso había que distinguir el caso de
## elegir sin tener ninguno delante: es el orden normal de las cosas, primero el
## arma y después el enemigo. Ahora la pregunta es otra y ese apunte sobra.
func take_manual_control() -> void:
	automatic = false


func _on_target_changed(target: Unit) -> void:
	_until_check = 0.0
	# **Cambiar de blanco NO caduca la elección del jugador.** Antes sí, y era
	# quitarle el mando: elegías Zuni, apuntabas al siguiente tanque y el
	# automático te ponía el Hellfire encima nada más, porque llega más lejos. Con
	# qué se ataca es suyo, y el alcance no es razón para desdecirlo.
	if not automatic:
		if _still_serves(target):
			return
		automatic = true
	_rearm_for(target)


## ¿Sigue valiendo el arma que eligió el jugador contra este blanco?
##
## No se pregunta si es la más adecuada — eso es preferencia, y la preferencia es
## del jugador. Se pregunta si **puede dispararse**, que no lo es: un AIM-9 no le
## hace nada a un tanque, y respetarle la elección hasta ahí sería mandar al
## aparato a un blanco con un arma que no va a salir nunca. Sólo entonces vuelve
## a mandar el automático.
##
## Lo de quedarse sin munición ya lo cubre [method _on_ammo_changed], que devuelve
## el mando en el acto al gastarse la última.
func _still_serves(target: Unit) -> bool:
	var weapon: WeaponType = _unit.active_weapon
	if weapon == null or not is_instance_valid(target):
		return false
	return weapon.can_engage_domain(target.get_domain()) and _unit.has_ammo(weapon)


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
		# Todavía fuera de alcance de todo: hace falta un arma que **guíe el
		# vuelo** hasta ponerse a tiro, aunque desde aquí no se pueda disparar.
		pick = _armed_fallback(target)
	if pick != null and pick.can_engage_domain(target.get_domain()):
		_unit.set_active_weapon(pick)


## Con qué se apunta cuando el blanco está fuera del alcance de todo.
##
## El principal del armamento, que es con lo que la unidad salió armada — **pero
## sólo si le queda**. Sin esa comprobación el avión se acercaba guiado por un
## arma gastada y llegaba a tiro para no disparar: la envolvente era la buena,
## el arma no.
##
## Y el cañón el último, por lo mismo que en [method best_for]: mientras quede un
## misil, el vuelo se organiza alrededor del misil.
func _armed_fallback(target: Unit) -> WeaponType:
	var domain := target.get_domain()
	var main := _unit.get_default_weapon()
	if main != null and _unit.has_ammo(main) and main.can_engage_domain(domain):
		return main
	var cannon: WeaponType = _unit.unit_type.cannon if _unit.unit_type != null else null
	var last_resort: WeaponType = null
	for weapon in _unit.get_weapons():
		if not _unit.has_ammo(weapon) or not weapon.can_engage_domain(domain):
			continue
		if weapon == cannon:
			last_resort = weapon
			continue
		return weapon
	return last_resort


## Se acabó lo que había puesto: vuelve a mandar el automático **y se replantea
## en el acto**.
##
## Devolver el mando no basta, y ahí estaba el fallo: el repaso periódico sólo
## corre contra lo que vuela, así que contra tierra nadie volvía a preguntar
## nunca. El avión seguía dando pasadas con el lanzador vacío —con dos bombas
## colgadas del ala— hasta que el jugador le cambiaba de blanco. Se veía como un
## avión que enfila, no dispara, rompe y vuelve a empezar para siempre.
func _on_ammo_changed(weapon: WeaponType, remaining: int) -> void:
	if remaining > 0 or weapon != _unit.active_weapon:
		return
	automatic = true
	_rearm_for(_unit.attack_target)


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
	if best != null:
		return best
	# Sólo queda el cañón. Antes de conformarse: ¿hay un misil al que sólo le
	# falta **ángulo**? Entonces manda ése, aunque todavía no pueda dispararse.
	#
	# Es lo que rompe el círculo vicioso que se veía jugando: el AIM-9 no engancha
	# de frente, así que el selector ponía el cañón; con el cañón puesto el vuelo
	# va derecho —no necesita la cola— y de frente el AIM-9 no consigue ángulo
	# nunca. El avión acababa metiéndose a los tiros contra un caza.
	#
	# **El arma que guía el vuelo es la mejor que se lleva, no la que ya se puede
	# disparar.** Quien comprueba si se puede tirar es el armamento; esto sólo
	# dice hacia qué se está peleando.
	var wanted := _blocked_only_by_angle(target, distance, against_air)
	return wanted if wanted != null else fallback


## El mejor misil que estaría en parámetros de no ser por el ángulo. `null` si no
## hay ninguno, o si contra este blanco el ángulo ni cuenta.
func _blocked_only_by_angle(target: Unit, distance: float,
		against_air: bool) -> WeaponType:
	if not against_air:
		return null
	var best: WeaponType = null
	for weapon in _unit.get_weapons():
		if not weapon.needs_rear_aspect():
			continue
		if not weapon.can_engage_domain(target.get_domain()) or not _unit.has_ammo(weapon):
			continue
		if not weapon.in_range_against(distance, target.get_domain()):
			continue
		if best == null or _closer_fit(weapon, best, true):
			best = weapon
	return best


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
