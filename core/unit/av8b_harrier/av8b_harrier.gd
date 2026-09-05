extends Unit

## Qué ES el Harrier: identidad, categoría y cómo recibe órdenes.
## No pilota — de eso se encarga PlaneController, y de a dónde ir,
## OrbitBehavior o AttackRunBehavior. Todos cuelgan de esta misma escena.
##
## Aquí sólo se arbitra cuál de los dos comportamientos manda: los dos le dan
## puntos al mismo piloto y no pueden correr a la vez. Y aquí se traduce el
## arma activa a la envolvente de tiro que el vuelo tiene que respetar — el
## comportamiento no sabe de armas y el arma no sabe de vuelo.
##
## **No esquiva por su cuenta.** Suelta señuelos —de eso se encarga
## `Countermeasures`, que se engancha solo al aviso de misil— y sigue con lo
## suyo. Sacarlo de una zona batida es del jugador: un avión que maniobra solo
## acaba desobedeciendo, y el aviso llega con tiempo de sobra para decidir.

signal order_fulfilled

@onready var pilot: PlaneController = $PlaneController
@onready var orbit: OrbitBehavior = $OrbitBehavior
@onready var attack: AttackRunBehavior = $AttackRun
@onready var dogfight: DogfightBehavior = $Dogfight
@onready var weapons: WeaponSystem = $WeaponSystem
## El tramo final, cuando ya no vuela por el ala. Ver [VtolLanding].
@onready var vtol: VtolLanding = $VtolLanding


func _ready() -> void:
	super._ready()
	add_to_group("unit_air")
	orbit.center_reached.connect(func() -> void: order_fulfilled.emit())
	attack.target_lost.connect(_on_target_lost)
	dogfight.target_lost.connect(_on_target_lost)
	# Sólo se tira dentro de la pasada. Fuera de ella el avión está maniobrando
	# y el blanco le cruza el morro de refilón cada vez que vira: sin esto, cada
	# uno de esos cruces sería un tiro, y el ataque se vería como un baile.
	attack.attack_run_started.connect(weapons.set_cleared_to_fire.bind(true))
	attack.attack_run_ended.connect(weapons.set_cleared_to_fire.bind(false))
	# Disparar y romper el ataque son la misma maniobra **contra tierra**: en
	# cuanto sale el arma el avión deja de meterse hacia un blanco que no le va a
	# perseguir. En un duelo aéreo romper sería regalar la iniciativa, así que
	# `dogfight` no escucha esto y sigue maniobrando después de tirar.
	weapons.fired.connect(func(_weapon: WeaponType) -> void: attack.break_off())
	# Cambiar de arma en pleno ataque cambia a qué distancia hay que volar.
	active_weapon_changed.connect(_on_active_weapon_changed)
	vtol.landed.connect(_on_landed)
	# En cubierta no se dispara, aunque ya tenga objetivo asignado.
	weapons.set_active(false)


## El rumbo real de vuelo, no la rotación del nodo: el arte apunta a +Y, así
## que la rotación lleva un desfase que el armamento no debe heredar — saldría
## disparado de lado.
## **Contesta el que está al mando ahora mismo.** En el tramo final el avión ya
## no lo lleva su piloto, y publicar el rumbo del que soltó el mando dejaría al
## armamento y a la flecha del mapa apuntando a donde venía.
func get_facing() -> float:
	return vtol.heading if vtol.is_active() else pilot.heading


func get_velocity() -> Vector2:
	return vtol.velocity if vtol.is_active() else pilot.velocity


## A dónde va, si va a algún sitio ordenado. Sólo cuenta mientras **se acerca**:
## una vez llegado, el avión da vueltas ahí y eso ya no es ir a ninguna parte,
## es esperar.
func get_move_destination() -> Variant:
	return orbit.get_destination() if orbit.has_pending_order() else null


## Deja la cubierta a su velocidad mínima de vuelo. Es lo más despacio que
## puede sostenerse en el aire y, por tanto, lo antes que puede irse: no hay
## motivo para gastar más pista de la necesaria. La cubierta lo acelera hasta
## aquí y el piloto lo recoge volando ya a esta velocidad, así que el relevo no
## se nota. Y como es la misma a la que espera en el circuito, tampoco hay un
## acelerón inútil nada más despegar.
func get_takeoff_speed() -> float:
	return pilot.min_speed


func get_time_to_impact() -> float:
	return weapons.time_to_impact(attack_target)


## El portaaviones cede el control cuando el avión ya está en el aire.
##
## El circuito de espera es lo que hace un avión SIN órdenes. Si le dieron una
## mientras estaba en cubierta, al soltarlo hay que cumplirla: mandarlo a dar
## vueltas al barco sería ignorarla.
func start_flight(orbit_center: Node2D) -> void:
	pilot.enable()
	weapons.set_active(true)
	if is_instance_valid(attack_target):
		receive_attack_order(attack_target)
	elif not orbit.has_pending_order():
		# Si ya iba hacia un punto ordenado, el destino sigue puesto en el
		# piloto: basta con no tocarlo, ahora que puede volar.
		_orbit_around(orbit_center)


## Mandarlo a un sitio cancela la vuelta a bordo, y con ella la plaza reservada.
## Si no, seguiría corrigiendo contra el buque cada fotograma y el punto que
## acaba de pedir el jugador no duraría ni un frame.
func receive_move_order(target: Vector2) -> void:
	_abort_recovery()
	super.receive_move_order(target)
	attack.stop()
	dogfight.stop()
	orbit.orbit_at(target)


## Atacar un avión y atacar algo en el suelo son **dos maniobras distintas**, y
## el blanco decide cuál. Contra tierra se hacen pasadas: entrar, soltar y
## romper. Contra un avión se pelea por el ángulo y no se rompe nunca.
##
## Mezclarlos fue el error que dejó al Harrier alejándose cada vez que soltaba un
## AMRAAM: rompía el ataque, que es lo correcto contra un tanque y absurdo contra
## algo que se mueve tan rápido como tú.
func receive_attack_order(target: Unit) -> void:
	# Un blanco nuevo es una orden nueva y suelta la vuelta, igual que un
	# destino: los dos compiten por el mismo avión.
	_abort_recovery()
	super.receive_attack_order(target)
	orbit.stop()
	if target.get_domain() == UnitType.Domain.AIR:
		attack.stop()
		# Sin permisos que retirar: en un duelo se dispara en cuanto se puede, y
		# quien decide si se puede es la envolvente del arma, no una fase de
		# vuelo.
		weapons.set_cleared_to_fire(true)
		dogfight.engage(target, active_weapon)
		return
	dogfight.stop()
	# Se empieza sin permiso: primero se enfila, y el permiso llega con la
	# pasada. Al revés, el avión abriría fuego mientras todavía está buscando la
	# línea de ataque.
	weapons.set_cleared_to_fire(false)
	attack.engage(target, _weapon_min_range(), _weapon_max_range(),
		_weapon_slows_to_aim())


## Se quedó sin objetivo en pleno viaje. Un avión no puede pararse: orbita
## donde llegó, no donde estaba el enemigo — seguir volando hasta un punto
## vacío parecería que no se enteró.
func _on_target_lost() -> void:
	set_attack_target(null)
	orbit.orbit_at(global_position)


## El arma manda sobre el vuelo: si cambia mientras se ataca, el avión tiene
## que rehacer las distancias sin soltar el blanco.
func _on_active_weapon_changed(_weapon: WeaponType) -> void:
	if is_instance_valid(attack_target):
		dogfight.set_weapon(active_weapon)
		attack.set_envelope(_weapon_min_range(), _weapon_max_range(),
			_weapon_slows_to_aim())


func _weapon_min_range() -> float:
	return active_weapon.min_range if active_weapon != null else 0.0


## 0 = sin arma con la que atacar. El comportamiento lo entiende como "ve
## derecho", que es lo único sensato cuando no hay envolvente que respetar.
func _weapon_max_range() -> float:
	return active_weapon.max_range if active_weapon != null else 0.0


## Si el arma pide frenar para apuntar. Sin arma da igual: no va a disparar.
func _weapon_slows_to_aim() -> bool:
	return active_weapon.slows_to_aim if active_weapon != null else true


func _physics_process(_delta: float) -> void:
	_work_the_recovery()


func _orbit_around(center: Node2D) -> void:
	attack.stop()
	dogfight.stop()
	orbit.orbit_around(center)



## En qué tramo de la vuelta a bordo anda.
##
## **Se entra por popa**, como todo lo que vuelve, y hay dos caminos según con
## qué peso llegue. Ver [method comes_in_light].
##
## Los dos primeros tramos son de avión y existen por una razón que el
## helicóptero no tiene: **un avión llega a un punto con el rumbo con el que
## venía**. Volando primero a un punto de espera más a popa y desde él al de
## entrada, sale alineado con el buque por construcción, sin tener que
## enderezarse parado — que es justo lo que no puede hacer.
enum Recovery {
	NONE,       ## No vuelve a bordo.
	WAITING,    ## Pidió entrar y la cubierta está ocupada. Da vueltas al barco.
	JOIN,       ## Como avión, al punto de espera de popa.
	APPROACH,   ## Como avión, de ahí al de entrada: es lo que lo alinea.
	RUNWAY,     ## Viene cargado: por el eje de la cubierta, frenando.
	ALONGSIDE,  ## Viene ligero: subiendo por el costado hasta su plaza.
	CROSS,      ## Viene ligero: cruzando de lado sobre la cubierta.
	SETTLING,   ## Ya es carga del barco: bajando.
}

@export_group("Vuelta a bordo")
## A cuánto se da por hecho un tramo de avión. Grande a propósito: un avión no
## llega a un punto, lo pasa cerca. Es el mismo criterio con el que navega.
@export var join_radius: float = 45.0
## A qué distancia del punto de entrada suelta gas. Con la aceleración del
## Harrier, pasar de crucero a mínima cuesta unos 80 px; el resto es margen.
@export var throttle_back_at: float = 180.0

var _recovery: Recovery = Recovery.NONE
var _recovery_deck: FlightDeck = null
var _recovery_slot: int = -1
## De qué cubierta salió. Se la pone ella al crearlo.
var home_deck: FlightDeck = null


## Vuelve a la cubierta de la que salió, que es lo que pide el botón.
func return_home() -> void:
	return_to(home_deck)


## Vuelve a bordo de una cubierta concreta.
##
## El sí o no se contesta **aquí, antes de la aproximación**. Si la cubierta está
## ocupada no es que no se pueda volver: el avión da vueltas al barco hasta que le
## toque, y quien avisa es ella con [method recovery_granted].
func return_to(deck: FlightDeck) -> void:
	if deck == null or not is_instance_valid(deck) or not pilot.is_physics_processing():
		return
	set_attack_target(null)
	attack.stop()
	dogfight.stop()
	_recovery_deck = deck
	var slot := deck.request_recovery(self)
	_recovery_slot = slot
	if slot >= 0:
		_start_the_pattern()
	else:
		_recovery = Recovery.WAITING
		# Un avión que espera no se queda quieto, da vueltas. Y se las da **al
		# barco** y no a un punto del mar, porque el barco se mueve.
		orbit.orbit_around(deck)


## Le tocó el turno. Lo llama la cubierta cuando queda libre.
func recovery_granted(slot: int) -> void:
	if _recovery == Recovery.NONE:
		return
	_recovery_slot = slot
	if _recovery == Recovery.WAITING:
		_start_the_pattern()


func _start_the_pattern() -> void:
	_recovery = Recovery.JOIN
	orbit.stop()
	# Con gas: volver a casa es una orden que cumplir, no un paseo.
	pilot.set_cruising(true)
	pilot.set_target(_recovery_deck.initial_point(not comes_in_light()))


## Si está volviendo a esa cubierta.
func is_recovering_to(deck: FlightDeck) -> bool:
	return _recovery != Recovery.NONE and _recovery_deck == deck


## **¿Viene ligero?** De la respuesta salen las dos formas de entrar: sin nada
## colgado se posa en vertical, y con armamento todavía en las alas entra rodando
## por la cubierta, que es lo que hace un Harrier de verdad cuando pesa más de lo
## que su motor sostiene parado.
##
## [b]La contesta el avión y no quien lo recoge.[/b] Hoy sólo puede mirar el
## armamento que le quede; el día que exista combustible se suma aquí dentro y
## nadie más se entera. En la cubierta habría dos sitios que tocar.
##
## Y de paso, **la forma de aterrizar delata el estado del aparato antes que el
## HUD**: uno que entra rodando es uno que vuelve con las bombas puestas.
##
## El cañón no cuenta: no cuelga de ninguna estación.
func comes_in_light() -> bool:
	if weapon_loadout == null:
		return true
	for mount in weapon_loadout.mounts:
		if mount.weapon != null and has_ammo(mount.weapon):
			return false
	return true


## Deja de volver y suelta la plaza reservada. Sin esto, un avión al que el
## jugador desvía a mitad de vuelta deja su reserva puesta y la cubierta se va
## llenando de plazas que no ocupa nadie.
func _abort_recovery() -> void:
	if _recovery == Recovery.NONE:
		return
	var estaba := _recovery
	_recovery = Recovery.NONE
	_recovery_slot = -1
	if is_instance_valid(_recovery_deck):
		_recovery_deck.cancel_recovery(get_instance_id())
	_recovery_deck = null
	# Si ya había dejado de ser un avión, hay que devolverle el mando a su
	# piloto: el de sustentación no sabe viajar y lo dejaría flotando.
	if estaba == Recovery.RUNWAY or estaba == Recovery.ALONGSIDE \
			or estaba == Recovery.CROSS:
		_back_to_wing_flight()


## Vuelve a volar por el ala. El relevo va en los dos sentidos y por el mismo
## sitio: el piloto recoge el rumbo del nodo y arranca a su velocidad mínima.
func _back_to_wing_flight() -> void:
	vtol.release()
	pilot.enable()
	weapons.set_active(true)


## El punto del tramo en curso, recalculado contra el buque cada fotograma. Un
## punto capturado al empezar deja de ser su sitio en cuanto el barco avanza; y
## persiguiendo el vivo, el avión iguala su marcha solo.
func _leg_point() -> Vector2:
	var por_el_eje := not comes_in_light()
	match _recovery:
		Recovery.JOIN:
			return _recovery_deck.initial_point(por_el_eje)
		Recovery.APPROACH:
			return _recovery_deck.final_point() if por_el_eje \
					else _recovery_deck.join_point()
		Recovery.ALONGSIDE:
			return _recovery_deck.abeam_point(_recovery_slot)
		_:
			return _recovery_deck.spot_point(_recovery_slot)


## Lleva la maniobra, un tramo por fotograma.
##
## Los tramos se cierran con **pestillo**: una condición viva se cumple de camino
## y el avión se re-apuntaría a un destino que ya tiene al lado.
func _work_the_recovery() -> void:
	if _recovery == Recovery.NONE or _recovery == Recovery.WAITING:
		return
	if not is_instance_valid(_recovery_deck):
		_abort_recovery()
		return
	var here := global_position
	var point := _leg_point()
	match _recovery:
		Recovery.JOIN:
			# Todavía es un avión: no puede pararse, así que el punto se corrige
			# sin replantearle el viraje en curso.
			pilot.update_target(point)
			if here.distance_to(point) <= join_radius:
				_recovery = Recovery.APPROACH
				pilot.set_target(_leg_point())
		Recovery.APPROACH:
			# **Se apunta al punto de entrada, no más allá.** Apuntando más
			# adelante en la misma línea el avión sale mejor alineado, pero deja
			# de pasar cerca del punto de entrada: converge sobre la línea a lo
			# largo de cientos de píxeles y cruza su altura todavía a un lado.
			# Y entonces la puerta de la transición nunca se abre, el avión da
			# vueltas para siempre y la cubierta se queda en recuperación.
			# Probado: 90 s sin entrar. Lo que endereza la entrada es el tramo
			# inicial largo, no el punto al que se mira.
			pilot.update_target(point)
			# Suelta gas al acercarse. Se entra despacio, y además cuanta menos
			# velocidad traiga menos cubierta gasta frenando.
			pilot.set_cruising(here.distance_to(point) > throttle_back_at)
			if here.distance_to(point) <= join_radius:
				_go_jet_borne()
		Recovery.RUNWAY:
			# Entrando por el eje: morro paralelo al buque y frenada a lo largo
			# de la cubierta. **Esto es lo que se ve** de que viene cargado, no
			# las toberas, que en un sprite de 23 px de ancho miden un píxel.
			vtol.locked_heading = _recovery_deck.bow_heading()
			vtol.steer_to(point)
			if vtol.is_settled():
				_touch_down()
		Recovery.ALONGSIDE:
			vtol.locked_heading = _recovery_deck.bow_heading()
			vtol.steer_to(point)
			if vtol.is_settled():
				_recovery = Recovery.CROSS
		Recovery.CROSS:
			vtol.locked_heading = _recovery_deck.bow_heading()
			vtol.steer_to(point)
			if vtol.is_settled():
				_touch_down()
		_:
			pass


## Deja de volar por el ala. **Aquí el Harrier deja de ser un avión**: el piloto
## suelta el mando y lo recoge el de sustentación, heredando rumbo y velocidad
## para que el relevo no se note — igual que al revés en el despegue.
##
## Y aquí se bifurcan las dos entradas, que es lo único que las separa: la misma
## maniobra con otra lista de puntos.
func _go_jet_borne() -> void:
	var rumbo := pilot.heading
	var marcha := pilot.velocity
	pilot.disable()
	vtol.take_over(rumbo, marcha)
	# En cubierta no se dispara. Se apaga al entrar en sustentación y no al
	# tocar: de aquí en adelante el avión está sobre el barco.
	weapons.set_active(false)
	_recovery = Recovery.ALONGSIDE if comes_in_light() else Recovery.RUNWAY


## Toca cubierta. Primero se sube a bordo y después se posa, para que la bajada
## ocurra ya en coordenadas de cubierta: al revés, el barco se le escaparía por
## debajo mientras baja.
func _touch_down() -> void:
	_recovery = Recovery.SETTLING
	vtol.locked_heading = NAN
	_recovery_deck.take_aboard(self, _recovery_slot)
	vtol.land()


## Ya está posado. A partir de aquí manda la cubierta: lo lleva a su ascensor, lo
## baja y lo devuelve al pañol.
func _on_landed() -> void:
	if _recovery != Recovery.SETTLING or not is_instance_valid(_recovery_deck):
		return
	var deck := _recovery_deck
	var slot := _recovery_slot
	_recovery = Recovery.NONE
	_recovery_deck = null
	_recovery_slot = -1
	# **No se suelta el mando aquí.** Posado, el de sustentación sigue siendo
	# quien contesta el rumbo y la marcha; soltándolo, `get_facing` y
	# `get_velocity` volverían a las del piloto de vuelo, que se quedaron
	# congeladas en el momento del relevo — el HUD diría que un avión aparcado
	# en cubierta va a 75 px/s.
	deck.stow(self, slot)
