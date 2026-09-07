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
	## Los cuatro tramos del circuito del que entra rodando. Es el de un
	## portaaviones de verdad: se pasa por el costado en paralelo al buque, media
	## vuelta, se vuelve por el tramo paralelo, y al llegar a la altura de la popa
	## otra media vuelta que **termina ya alineado con la cubierta**.
	##
	## La alineación no se busca: sale de la geometría. El tramo paralelo va
	## separado el doble del radio de viraje, así que media vuelta de ese radio
	## acaba justo encima del eje. Ver `FlightDeck.pattern_offset`.
	ENTRY,      ## Entrando al circuito, hacia el tramo paralelo.
	DOWNWIND,   ## Por el tramo paralelo, en sentido contrario al buque.
	BASE,       ## El viraje que lo mete en final.
	FINAL,      ## Ya sobre el eje, hacia la popa.
}

@export_group("Vuelta a bordo")
## A cuánto se da por hecho un tramo de avión. Grande a propósito: un avión no
## llega a un punto, lo pasa cerca. Es el mismo criterio con el que navega.
@export var join_radius: float = 45.0
## Con cuánto margen se da por alcanzada la cabeza del tramo paralelo. Ancho,
## porque un avión no llega a un punto: pasa cerca.
@export var entry_radius: float = 70.0
## El radio del circuito de espera. Es el mínimo al que un avión puede dar
## vueltas: por debajo, cada punto del círculo le cae dentro de su propio giro.
@export var hold_radius: float = 330.0
## Cuánta recta de tramo paralelo necesita por delante para incorporarse a media
## altura, en vez de subir hasta la puerta. Es lo que le da agilidad sin
## estropearle el viraje.
## Cuánta recta de tramo paralelo necesita por delante para incorporarse a media
## altura, en vez de subir hasta la cabeza.
@export var min_downwind: float = 260.0
## A qué distancia del punto de entrada suelta gas. Con la aceleración del
## Harrier, pasar de crucero a mínima cuesta unos 80 px; el resto es margen.
@export var throttle_back_at: float = 180.0
## A qué distancia por delante persigue la línea de cubierta al entrar rodando.
## Es un suelo: si viene muy separado, el punto se aleja solo para no cortar la
## raya de través.
@export var approach_lookahead: float = 250.0
## Con qué ángulo corta la línea como mucho. **Es lo que quita el zigzag** sin
## tocar cómo gira el avión: cuanto más cerrado, más largo entra.
@export var intercept_deg: float = 30.0
## Cuánto puede llevar el morro desviado y aun así darse por encarado al buque
## para empezar la entrada. Ancho a propósito: sólo hace falta que venga hacia
## acá, porque enderezarlo ya lo hace la propia línea durante la aproximación.
@export var join_cone_deg: float = 60.0
## Y cuánto puede estar separado de la línea para arrancar la aproximación.
## Ancho: enderezarse es trabajo de la aproximación, no requisito para empezarla.
## Estrecharlo aquí lo dejaba dando vueltas al punto sin llegar a cumplirlo nunca.
@export var join_width: float = 600.0
## Lo que se le admite al cruzar la popa para dejarle tocar. Si llega más ancho o
## más torcido **no aterriza: repite la pasada**. Es lo que hace que todas las
## tomas sean iguales, en vez de aceptar la que salga y arreglarla luego.
@export var touchdown_width: float = 20.0
@export var touchdown_cone_deg: float = 25.0

var _recovery: Recovery = Recovery.NONE
var _recovery_deck: FlightDeck = null
var _recovery_slot: int = -1
## Qué puesto ocupa en la cola de los que esperan entrar. De él sale el radio de
## su circuito: cada uno espera en el suyo y así no se dibujan unos sobre otros.
var _hold_index: int = 0
## Cómo va a entrar esta vez. **Se decide una vez, al pedir sitio, y no se vuelve
## a preguntar.** La cubierta le reserva una ruta u otra según la respuesta, así
## que si a mitad de aproximación soltara la última bomba y cambiara de idea,
## volaría un patrón distinto del que tiene reservado.
var _along_deck: bool = false
## Le dieron entrada, pero todavía no está en el sitio del circuito por donde se
## entra. **No se sale del circuito de espera en cualquier punto**: el que estaba
## dando la vuelta por el costado de estribor cuando le tocó cruzaba el barco de
## través y llegaba al tramo paralelo de cualquier manera — y de ahí no había
## aproximación que saliera derecha. Se espera a pasar por el lado bueno.
var _cleared: bool = false
## Salió del viraje por detrás de la popa, que es de donde hay que llegar.
var _final_from_astern: bool = false
## Cuántas pasadas lleva falladas en esta vuelta a bordo.
var _go_arounds: int = 0
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
	_along_deck = not comes_in_light()
	_go_arounds = 0
	var slot := deck.request_recovery(self)
	_recovery_slot = slot
	if slot >= 0:
		_start_the_pattern()
	else:
		_recovery = Recovery.WAITING
		_start_holding()


## Se pone a esperar en el puesto que le tocó.
##
## Un avión que espera no se queda quieto, da vueltas. Y se las da **al barco** y
## no a un punto del mar, porque el barco se mueve.
func _start_holding() -> void:
	if not is_instance_valid(_recovery_deck):
		return
	# **Esperar es quedarse donde está**, dando vueltas sobre su propio sitio.
	# Mandarlos a anillos alrededor del buque los alejaba del barco, los metía
	# por encima de la cubierta y los dejaba a tiro de lo que hubiera cerca. El
	# que espera no tiene que ir a ningún sitio: ya está donde lo dejó el jugador.
	# **El círculo de espera es el mismo que la entrada**: roza la línea de la
	# pista, así que dar vueltas aquí ya es estar en la aproximación. Al que le
	# toca no le queda maniobra que hacer, sólo dejar de girar.
	orbit.radius = hold_radius
	orbit.orbit_around(_recovery_deck.hold_center())


## Le cambian el puesto en la cola: los de delante entraron y todos se corren
## hacia dentro. **El puesto es lo que separa a los que esperan**; sin él todos
## reciben la misma orden y acaban volando en el mismo círculo.
## Le cambian el puesto en la cola. **No mueve al avión**: esperar es quedarse
## donde está, y el puesto sólo dice a quién le toca después.
func recovery_hold(index: int) -> void:
	_hold_index = index




## ¿Entra rodando por el eje? Viniendo cargado, sí: el motor no lo sostiene
## parado. Es lo que le pregunta la cubierta para saber qué ruta reservarle, y
## está escrito contra [method comes_in_light] para que no haya dos respuestas.
func lands_along_deck() -> bool:
	return _along_deck


## Le tocó el turno. Lo llama la cubierta cuando queda libre.
func recovery_granted(slot: int) -> void:
	if _recovery == Recovery.NONE:
		return
	_recovery_slot = slot
	if _recovery != Recovery.WAITING:
		return
	if _along_deck:
		# Sigue dando vueltas hasta pasar por el punto en que el círculo toca la
		# pista. Lo comprueba [method _work_the_recovery] cada fotograma.
		_cleared = true
	else:
		_start_the_pattern()


func _start_the_pattern() -> void:
	if _along_deck:
		# **No hay maniobra de entrada.** Se mete en el círculo de espera, que ya
		# es el circuito de aterrizaje, y sale de él por donde toca.
		_recovery = Recovery.WAITING
		_cleared = true
		_start_holding()
		return
	orbit.stop()
	_recovery = Recovery.JOIN
	# **Sin gas.** Se vuelve a casa despacio, que es como se entra a un barco:
	# cuanta menos velocidad traiga, menos cubierta gasta frenando y mejor se mete
	# en la línea. Meterle gas al primero de la cola sólo servía para que llegara
	# antes y peor.
	pilot.set_cruising(false)
	pilot.set_target(_recovery_deck.pattern_entry() if _along_deck \
			else _recovery_deck.initial_point(false))


## ¿Está esperando turno para entrar? Lo pregunta el HUD.
func is_holding() -> bool:
	return _recovery == Recovery.WAITING


## ¿Está ya entrando, o sea comprometido con la aproximación? Lo pregunta el HUD.
func is_landing() -> bool:
	return _recovery in [Recovery.FINAL, Recovery.RUNWAY, Recovery.ALONGSIDE,
			Recovery.CROSS, Recovery.SETTLING]


## ¿Está volviendo a bordo? Lo pregunta el HUD para decirlo con todas las letras
## en vez de contar que se está moviendo a un sitio: es lo mismo por fuera y no
## es lo mismo para el jugador.
func is_returning() -> bool:
	return _recovery != Recovery.NONE


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
	var por_el_eje := _along_deck
	match _recovery:
		Recovery.JOIN:
			return _recovery_deck.initial_point(por_el_eje)
		Recovery.APPROACH:
			# Entrando por el eje **se persigue la propia línea**, no un punto:
			# un sitio de la raya que va corriendo por delante del avión. Eso es
			# lo que lo mete encima de ella venga como venga. Mirando a un punto
			# fijo llegaba cruzado y a un costado, y ochenta píxeles fuera.
			if por_el_eje:
				return _recovery_deck.axis_lookahead(global_position,
						approach_lookahead, intercept_deg)
			return _recovery_deck.join_point()
		Recovery.ENTRY:
			return _recovery_deck.pattern_entry()
		Recovery.DOWNWIND:
			return _recovery_deck.downwind_lookahead(global_position,
					approach_lookahead, intercept_deg)
		Recovery.BASE:
			return _recovery_deck.pattern_rollout()
		Recovery.FINAL:
			return _recovery_deck.axis_lookahead(global_position,
					approach_lookahead, intercept_deg)
		Recovery.RUNWAY:
			# Para **antes** del ascensor, no encima de la plaza.
			return _recovery_deck.rollout_point(_recovery_slot)
		Recovery.ALONGSIDE:
			return _recovery_deck.abeam_point(_recovery_slot)
		_:
			return _recovery_deck.spot_point(_recovery_slot)


## Lleva la maniobra, un tramo por fotograma.
##
## Los tramos se cierran con **pestillo**: una condición viva se cumple de camino
## y el avión se re-apuntaría a un destino que ya tiene al lado.
func _work_the_recovery() -> void:
	if _recovery == Recovery.NONE:
		return
	if _recovery == Recovery.WAITING:
		# Le dieron entrada: se sale del circuito de espera al pasar por el
		# costado bueno, no en el punto en que estuviera.
		# Se sale del circuito de espera **por delante de la proa**, que es por
		# donde se entra al de aterrizaje. Saliendo por donde tocara, el avión
		# cruzaba el buque y se incorporaba a mitad del tramo, con cualquier
		# rumbo.
		if _cleared and is_instance_valid(_recovery_deck) 				and _recovery_deck.at_release_point(global_position, get_facing()):
			_cleared = false
			_roll_out_of_the_turn()
		return
	if not is_instance_valid(_recovery_deck):
		_abort_recovery()
		return
	var here := global_position
	var point := _leg_point()
	var por_el_eje := _along_deck
	match _recovery:
		Recovery.JOIN:
			# Todavía es un avión: no puede pararse, así que el punto se corrige
			# sin replantearle el viraje en curso.
			pilot.update_target(point)
			# La entrada rodada no espera a **llegar** al punto de espera: espera
			# a estar lo bastante a popa y viniendo hacia el barco. Exigirle
			# tocar el punto lo hacía fallarlo, dar la vuelta y empezar la
			# aproximación de espaldas, que es de donde salía el viraje feo.
			if por_el_eje:
				if _recovery_deck.astern_of_pattern(here, join_width) 						and _facing_the_ship():
					_recovery = Recovery.APPROACH
					pilot.set_target(_leg_point())
			elif here.distance_to(point) <= join_radius:
				_recovery = Recovery.APPROACH
				pilot.set_target(_leg_point())
		Recovery.APPROACH:
			pilot.update_target(point)
			# **Entrando por el eje la puerta es cruzar la popa, no acercarse a un
			# punto.** Es la diferencia entre una línea y un radio: apuntar lejos
			# alinea al avión pero le hace pasar de largo de cualquier punto
			# intermedio, y con una puerta de radio la transición no se abría nunca
			# — probado, 90 s dando vueltas. Con la línea sí se puede mirar lejos,
			# que es lo único que endereza la entrada.
			#
			# El gas se suelta contra la popa en los dos casos: es el sitio al que
			# de verdad hay que llegar despacio.
			pilot.set_cruising(false)
			if por_el_eje:
				if _recovery_deck.past_ramp(here):
					if _lined_up_to_land():
						_go_jet_borne()
					else:
						_go_around()
			elif here.distance_to(point) <= join_radius:
				_go_jet_borne()
		Recovery.ENTRY:
			# Se pone en cabeza del tramo paralelo, al costado y a la altura de la
			# proa. Con gas, que esto todavía es transitar.
			pilot.set_cruising(true)
			pilot.update_target(point)
			# Y si ya viene por el costado bueno y hacia popa con recta por
			# delante, se incorpora ahí mismo en vez de subir hasta la cabeza.
			if here.distance_to(point) <= entry_radius 					or _recovery_deck.can_join_downwind(here, get_facing(),
							min_downwind):
				_recovery = Recovery.DOWNWIND
				pilot.set_target(_leg_point())
		Recovery.DOWNWIND:
			pilot.set_cruising(true)
			pilot.update_target(point)
			if _recovery_deck.past_turn_y(here):
				_recovery = Recovery.BASE
				# El viraje ya es aproximación: se suelta gas y es cuando el
				# buque lo canta.
				pilot.set_cruising(false)
				pilot.set_target(_leg_point())
		Recovery.BASE:
			pilot.update_target(point)
			# **La curva la traza el avión.** El tramo paralelo va separado el
			# doble de su radio de viraje, así que media vuelta acaba encima del
			# eje sola. Aquí sólo se mira cuándo ha salido de ella.
			if _recovery_deck.on_centreline(here, join_radius):
				_recovery = Recovery.FINAL
				_final_from_astern = not _recovery_deck.past_ramp(here)
				pilot.set_target(_leg_point())
		Recovery.FINAL:
			pilot.update_target(point)
			# Si sale del viraje ya por encima del barco es que la ha errado: no
			# hay final que volar, así que se vuelve a la puerta. Sin esto se
			# quedaba dando tumbos sobre la cubierta sin llegar a posarse nunca.
			if _recovery_deck.past_ramp(here) and not _final_from_astern:
				_go_around()
			elif _recovery_deck.past_ramp(here):
				if _lined_up_to_land():
					_go_jet_borne()
				else:
					_go_around()
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
				# Ya tuerce hacia su plaza: la subida por el costado queda libre
				# para el siguiente. Es lo que permite que entren de uno en uno
				# por la línea y aun así se posen varios a la vez.
				_recovery_deck.begin_cross_in(self)
		Recovery.CROSS:
			vtol.locked_heading = _recovery_deck.bow_heading()
			vtol.steer_to(point)
			if vtol.is_settled():
				_touch_down()
		_:
			pass


## ¿Viene hacia el buque, aunque sea de refilón? No se le pide puntería: la línea
## de cubierta ya lo endereza durante la aproximación. Lo que se evita es que la
## empiece de espaldas y tenga que dar media vuelta encima del barco.
func _facing_the_ship() -> bool:
	if not is_instance_valid(_recovery_deck):
		return false
	var desvio := angle_difference(get_facing(), _recovery_deck.bow_heading())
	return absf(desvio) <= deg_to_rad(join_cone_deg)


## ¿Llega en condiciones de tocar? Encima de la línea y con el morro derecho.
func _lined_up_to_land() -> bool:
	# **Cada pasada fallida ensancha el margen.** Un avión que no aterriza nunca
	# es mucho peor que uno que aterriza algo torcido: se queda dando vueltas
	# para siempre y de paso deja la cubierta bloqueada para los demás. A la
	# tercera entra seguro.
	var holgura := 1.0 + float(_go_arounds)
	if not _recovery_deck.on_centreline(global_position, touchdown_width * holgura):
		return false
	var desvio := angle_difference(get_facing(), _recovery_deck.bow_heading())
	return absf(desvio) <= deg_to_rad(touchdown_cone_deg * holgura)


## No llegaba bien: **repite la pasada**. Vuelve al punto de espera y entra otra
## vez, en vez de posarse torcido y arreglarlo arrastrándolo por la cubierta.
##
## Es lo que hace que todas las tomas se vean iguales. Y no se puede atascar:
## cada vuelta empieza más a popa, con más recta para centrarse.
## Deja de girar y sigue recto a la pista. Es literalmente todo lo que hace falta:
## el círculo de espera está colocado para que en ese punto ya esté enfilado.
func _roll_out_of_the_turn() -> void:
	orbit.stop()
	_recovery = Recovery.FINAL
	_final_from_astern = true
	pilot.set_cruising(false)
	pilot.set_target(_leg_point())


## No llegó bien: vuelve al círculo y lo intenta en la siguiente vuelta. Sin
## subir a ningún lado ni desviarse: es el mismo círculo de siempre.
func _go_around() -> void:
	_go_arounds += 1
	_recovery = Recovery.WAITING
	_cleared = true
	_start_holding()


func _go_jet_borne() -> void:
	var rumbo := pilot.heading
	var marcha := pilot.velocity
	pilot.disable()
	vtol.take_over(rumbo, marcha)
	# En cubierta no se dispara. Se apaga al entrar en sustentación y no al
	# tocar: de aquí en adelante el avión está sobre el barco.
	weapons.set_active(false)
	_recovery = Recovery.RUNWAY if _along_deck else Recovery.ALONGSIDE
	if _along_deck:
		# Rueda por cubierta: morro paralelo al buque y frenada calculada para
		# pararse donde se le dice. De aquí en adelante no puede ir hacia atrás.
		vtol.locked_heading = _recovery_deck.bow_heading()
		vtol.start_rollout(_recovery_deck.rollout_point(_recovery_slot))


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
