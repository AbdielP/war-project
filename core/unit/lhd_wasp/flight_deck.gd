extends Node2D
class_name FlightDeck

## La cubierta de vuelo: saca aparatos y los recoge, y hace las dos cosas a la vez
## siempre que sean en sitios distintos.
##
## **Lo que se turna es un sitio, no el barco.** Hay cuatro plazas y dos
## ascensores, y ponerle un candado a la cubierta entera era cobrar por todo el
## buque un estorbo que ocupa un rincón: un helicóptero posándose a popa no tiene
## nada que ver con un avión que sale por proa. Lo que se pregunta, en cada
## costura y donde se sabe, es **quién le estorba a quién**:
##
## - La carrera de despegue va de la plaza a la proa por `x=-22`, así que le
##   estorba lo que caiga en esa franja —lo que ya está encima, y también el que
##   viene de camino a una plaza de más adelante—. Lo que quede a popa, no.
## - El que entra cruza la cubierta por el través de **su** plaza, así que sólo
##   se pisa con el taxi que vaya a esa plaza o la atraviese.
## - El ascensor es de uno en uno, y por eso las entradas se conceden **una por
##   ascensor**: dos a la vez, cada una por su banda.
##
## Donde hay conflicto de verdad, **cede el de cubierta**: al que vuela se le
## acaba el combustible y al que está posado no.
##
## **Se sale por proa y se entra por popa** (`-Y` y `+Y` en coordenadas de la
## cubierta), así que los dos flujos no se cruzan ni en el aire.
##
## El sí o no a una entrada **se contesta antes de la aproximación, no antes de
## posarse**. Al despegar, si la cubierta está ocupada simplemente no se empieza
## y no hay nada comprometido; al recoger es al revés, y negarle la plaza a uno
## que ya está entrando lo deja sin sitio a donde ir. Por eso la plaza se reserva
## al conceder la entrada y cubre la secuencia entera, ascensor incluido: quien
## reserva sólo el punto de toma acaba con un aparato posado y sin salida, que es
## un estorbo que ya no puede quitar nadie.

## Qué está haciendo la cubierta. Es lo que se enseña en el HUD, y **la
## obligación de enseñarlo es lo que lo hace correcto**: si no se puede escribir
## el rótulo, no hay un estado sino una combinación de banderas.
enum Mode { IDLE, LAUNCHING, RECOVERING }

## Cambió lo que está haciendo.
signal mode_changed(mode: Mode)

@export var taxi_speed: float = 30.0
## Lo que gira sobre el sitio mientras rueda, en grados por segundo. Un aparato
## en cubierta se mueve hacia donde mira: encara el tramo y luego avanza.
@export var taxi_turn_speed_deg: float = 90.0
@export var elevator_cycle_time: float = 2.0
@export var launch_delay: float = 2.0
@export var post_bow_distance: float = 80.0
@export var climb_duration: float = 2.5

## Escala a la que sale el avión de cubierta; sube hasta 1.0 al despegar para
## simular que gana altura. En 1.0 el efecto queda apagado.
##
## Ojo con los valores fraccionarios: rompen el pixel art de los detalles
## finos (el cuerpo de un AIM-9 mide 1px, a 0.7 no se puede dibujar y el
## motor lo reparte entre dos columnas). Por eso está en 1.0 por defecto,
## en línea con la regla de escala entera del proyecto.
@export var spawn_scale: float = 1.0

## Cuánto tiene que apartarse del eje de la pista una aeronave para dejar de
## estorbar a la que va a correr, en píxeles.
@export var runway_clearance: float = 30.0
## Cada cuánto se vuelve a mirar si la pista quedó despejada, en segundos. Sólo
## se usa mientras lo que estorba está volando: ver [method _retry_later].
@export var retry_delay: float = 0.5

@export_group("Recuperación")
## Cuánto se aparta del eje de pista el tramo de arrimada, en píxeles de
## cubierta. Negativo es por babor, que es el costado por el que la pista queda
## más cerca del borde.
##
## El que entra se pone **al costado y fuera** del buque, sube paralelo hasta la
## altura de su plaza y sólo entonces cruza de lado. Así ni sobrevuela la
## cubierta de punta a punta ni se cruza con lo que esté saliendo por proa.
@export var abeam_offset: float = -70.0
## A cuánto se da por hecho un tramo de la aproximación, en píxeles. Los dos
## primeros son de viaje y no piden puntería; el que la pide es el último, y ése
## lo remata el propio piloto con su radio de llegada.
@export var leg_radius: float = 10.0
## Cuánto más a popa queda el punto de espera inicial.
##
## **Lo fija el radio de giro del que entra, no el gusto.** Un avión que llega al
## punto de espera navegando hacia popa tiene que dar media vuelta, y con 130 px
## de radio eso son 260 px de través más lo que tarde en enderezarse. Corto, se
## planta en la cubierta todavía virando.
@export var pattern_leg: float = 380.0
## A qué distancia del punto de entrada aguarda el primero de la cola.
##
## Suelo de un circuito de avión: por debajo de unas dos veces y media su radio
## de viraje, cada punto del círculo le cae dentro del propio giro y no puede
## rodear nada.
@export var hold_radius: float = 330.0
## Cuánto se separa cada puesto de espera del anterior. Es lo que impide que los
## que aguardan se dibujen unos encima de otros.
@export var hold_spacing: float = 90.0

@export_group("Circuito de aterrizaje")
## Cuánto se separa del eje de cubierta el tramo paralelo del circuito.
##
## **Es el doble del radio de viraje del avión y no es un número estético.** Con
## esa separación exacta, el viraje de media vuelta que lo mete en final termina
## encima del eje por pura geometría: no hay que perseguir la línea ni corregir
## nada después. Es lo que hace que todas las tomas salgan iguales.
@export var pattern_offset: float = 260.0
## Cuánta agua por detrás de la popa se le deja al salir del viraje.
##
## **Es la recta final, y corta no perdona.** Con 120 px, al que salía del viraje
## unos metros descolocado no le daba tiempo a centrarse antes de la popa, y se
## iba a repetir la pasada una y otra vez. Con el doble, el que sale bien no lo
## nota y el que sale algo torcido tiene sitio para arreglarlo.
@export var pattern_turn_margin: float = 230.0
## Cuánto más abierto vuela cada uno de los que esperan.
##
## Son circunferencias **concéntricas**: dos nunca se cortan, así que el que
## espera no se topa con el que aterriza ni con los otros que esperan. Y al irse
## el de delante, todos se cierran un puesto, que es lo que los deja ya en camino.
@export var pattern_hold_step: float = 80.0
## Cuánto por delante de la proa está la puerta del circuito.
##
## **Se entra siempre por ahí, vengan de donde vengan.** Dejar que se metieran
## por donde les pillara era lo que producía las entradas raras: uno que se
## incorporaba a mitad del tramo paralelo llegaba a la popa con cualquier rumbo,
## y de ahí no sale una toma buena.
@export var pattern_entry_lead: float = 60.0
## Con cuánto margen se da por pasado el punto de salida de la espera.
@export var release_radius: float = 60.0
## Y con cuánto desvío de morro. Estrecho: la gracia es salir ya enfilado.
@export var release_cone_deg: float = 30.0
## A qué distancia por detrás de la popa se engancha la recta de entrada.
##
## **Es lo único que queda del circuito.** Ni tramos paralelos ni virajes
## dibujados: se va a un punto detrás del barco y desde ahí se sigue la línea de
## cubierta, que al perseguirla con un ángulo de corte acotado traza sola la
## curva de entrada. Corto para que nadie se vaya lejos, largo para que la curva
## quepa.
@export var approach_gate_len: float = 700.0

## El grupo al que se apunta todo lo que vuela. Es lo único que puede estar
## encima de la cubierta, así que es lo único que hay que mirar.
const _AIR_GROUP := &"unit_air"

# Elevator1 → TP2 primero, luego TP1. Elevator2 → TP4 primero, luego TP3.
const _ELEVATOR_SLOTS: Array = [[1, 0], [3, 2]]
# Waypoint intermedio por slot: TP2 pasa por TP1, TP4 pasa por TP3. -1 = directo.
const _SLOT_WAYPOINTS: Array = [-1, 0, -1, 2]

## En qué trozos se parte la cubierta.
##
## **Todo movimiento —despegar, rodar, bajar por el ascensor, posarse— es una
## ruta: una lista de estos trozos.** Un movimiento arranca cuando puede
## reservarlos todos y los va soltando según los deja atrás. Ésa es la única
## regla de coordinación que hay aquí.
##
## Antes eran banderas, una por caso: «no lances si alguien entra por delante»,
## «no ruedes si tu plaza de paso está ocupada». Cada regla contestaba a una
## situación y era ciega a la siguiente, así que cada situación nueva pedía otra
## regla. Con los trozos las situaciones salen solas: cuatro se posan a la vez
## porque hay cuatro plazas y cuatro carriles paralelos, van a sus ascensores sin
## pisarse porque salir de la plaza de dentro pide la de fuera, y el quinto
## espera porque no queda plaza que reservar.
##
## **No hay trozos para el eje entre plazas**, y no hacen falta: toda ruta que
## recorra un tramo de eje pide también las plazas de sus dos extremos, así que
## pedir las plazas ya impide el cruce.
enum Seg {
	SPOT_0, SPOT_1, SPOT_2, SPOT_3,
	ELEV_0, ELEV_1,
	## El través de estribor, de la plaza de popa a su ascensor.
	LANE_0,
	## El través de babor, del centro a su ascensor. **Es también el carril por
	## el que entra el que se va a posar ahí**: es el mismo trozo de cubierta, y
	## por eso no son dos.
	LANE_1,
	## Los carriles de entrada de las otras tres plazas, por babor.
	CROSS_0, CROSS_1, CROSS_3,
	## La subida por el costado de babor. La comparten todos los que entran por
	## ahí, y por eso se entra de uno en uno aunque se posen a la vez: cada cual
	## la suelta al torcer hacia su plaza.
	APPROACH,
	## La entrada rodada por el eje desde popa, la del Harrier que viene cargado.
	AXIS,
}

const _SPOT_SEG: Array = [Seg.SPOT_0, Seg.SPOT_1, Seg.SPOT_2, Seg.SPOT_3]
const _ELEV_SEG: Array = [Seg.ELEV_0, Seg.ELEV_1]
const _LANE_SEG: Array = [Seg.LANE_0, Seg.LANE_1]
## El carril de entrada de cada plaza. El de la 2 **es** el través de su
## ascensor, no una copia.
const _CROSS_SEG: Array = [Seg.CROSS_0, Seg.CROSS_1, Seg.LANE_1, Seg.CROSS_3]

@onready var _elevators: Array[Marker2D] = [$Elevator1, $Elevator2]
@onready var _takeoff_points: Array[Marker2D] = [
	$TakeoffPoint1, $TakeoffPoint2, $TakeoffPoint3, $TakeoffPoint4
]
@onready var _launch_point: Marker2D = $LaunchPoint
## Por donde se entra: por detrás del buque. El que llega y no cabe espera aquí,
## y el que sí cabe arranca desde aquí su arrimada.
@onready var _recovery_join: Marker2D = $RecoveryJoin
## Donde toca el que entra rodando: el extremo de popa de la línea de cubierta.
## Medido sobre el propio dibujo — la raya amarilla llega hasta ahí — y puesto
## como marcador para poder cuadrarlo a ojo en el editor.
@onready var _recovery_ramp: Marker2D = $RecoveryRamp
## El centro del circuito de espera.
##
## **Está puesto para que el círculo roce la línea de la pista**, por detrás y a
## babor. Eso es lo que hace que salir de la espera no sea una maniobra: el que
## da vueltas ahí pasa, una vez por vuelta, justo encima del eje y apuntando a la
## popa, así que sólo tiene que dejar de girar.
##
## Antes el círculo era una figura distinta de la entrada, y todo lo feo que se
## veía —subir a la proa, virar cerrado pegado al casco— era el trozo que hacía
## falta para pasar de una a la otra. Siendo la misma figura, ese trozo no existe.
@onready var _hold_center: Marker2D = $HoldCenter

## Quién está aparcado en cada plaza. Es inventario, no reserva: lo que dice si
## se puede pasar por ahí es [member _held].
var _units: Array        = [null, null, null, null]
var _elevator_idx := 0
var _taxi_queues: Array  = [[], []]

## Quién tiene reservado cada trozo, `Seg -> id`.
##
## El id es el de instancia del aparato, o un **vale negativo** mientras todavía
## no existe: entre pedirlo en el hangar y verlo salir del ascensor hay una cola,
## y su plaza tiene que estar guardada desde que se pide, o dos peticiones
## seguidas eligen la misma.
##
## Un aparato aparcado tiene reservada su plaza y nada más, así que no hace falta
## una lista de plazas ocupadas: es la misma pregunta.
var _held: Dictionary = {}
## De quién es cada plaza **como destino**, o 0. Es distinto de tenerla
## reservada: por una plaza se pasa de camino a otra, y quien sólo pasa no la
## está ocupando. Sin separarlo, pedir un tercer aparato al hangar contestaba que
## no había sitio porque el primero estaba rodando por encima de su plaza.
var _dest: Array[int] = [0, 0, 0, 0]
var _next_token := 0
## Hay una pasada de repaso en marcha. Ver [method _deck_freed].
var _sweeping := false
var _sweep_again := false
## Cuántos movimientos hay en marcha. Es para el rótulo y no para coordinar: lo
## que coordina es [member _held], que además dice **dónde**.
var _moving := 0
## Los que están posados esperando a bajar, por ascensor. Entradas
## `{"unit": Node2D, "slot": int}`.
var _stow_queues: Array = [[], []]
var _launching := false

## Las entradas concedidas, `plaza -> id de instancia`.
##
## **Va por plaza y no por cubierta**, que era el error: una entrada no ocupa el
## barco entero, ocupa un sitio. Con un solo id, un helicóptero posándose a popa
## dejaba parada una cubierta que tiene dos ascensores y cuatro plazas, y con
## ellos se puede recoger por un lado mientras se lanza por el otro.
##
## Es un id y no un `bool` porque hay que poder decir si el que viene a preguntar
## es el mismo al que se le concedió.
var _recovering: Dictionary = {}
## Los que pidieron entrar y esperan turno, por id y en orden de llegada.
##
## Un portero que dice "ahora no" tiene que decir también "ya puedes": sin esta
## lista la petición se pierde y no hay error que lo delate, sólo un aparato
## dando vueltas para siempre.
var _inbound: Array[int] = []
var _mode: Mode = Mode.IDLE

## A quién se le ha cedido ya el control, por id de instancia. Al sitio donde se
## cede se llega por dos caminos —al aparcar, si no usa pista, o al llegarle el
## turno en la tanda— y `start_flight` no está escrito para llamarse dos veces.
var _handed: Dictionary = {}

## Hay una segunda mirada pendiente. Ver [method _retry_later].
var _retry_pending := false


## Órdenes dadas **antes** de que el aparato exista, por id de instancia.
##
## El hangar decide a dónde va antes de pulsar despegar, pero entre eso y el
## aparato hay un ascensor, un taxi y una carrera de pista: la unidad se crea
## mucho después. Se guardan aquí en vez de dárselas al avión al aparecer porque
## dárselas antes de tiempo es peor que no dárselas — mientras la cubierta lo
## lleva a su sitio, el avión no se pilota, y una orden de movimiento pelearía
## contra el propio taxi.
var _standing: Dictionary = {}


## Suelta el aparato: a partir de aquí se pilota solo.
##
## La orden se le da **antes** de soltarlo, y ese orden es todo el asunto. Los dos
## aparatos están escritos para recibirla en cubierta: `start_flight` del Harrier
## mira si ya tiene blanco y sólo monta el circuito de espera cuando no lo tiene,
## y el piloto del Cobra arranca la subida si le dieron sitio mientras el barco
## lo colocaba. Dándosela después, `start_flight` ya lo mandó a dar vueltas y
## apuntar el blanco a posteriori sólo cambia el rótulo: el avión se queda
## orbitando el barco mientras el HUD dice que está atacando.
func _hand_over_control(unit: Node2D) -> void:
	var salido := unit as Unit
	if salido != null:
		salido.taking_off = false
	if not is_instance_valid(unit):
		return
	var id := unit.get_instance_id()
	if _handed.has(id):
		return
	_handed[id] = true
	_obey_standing_order(unit)
	if unit.has_method("start_flight"):
		unit.start_flight(get_parent())


## Le da la orden que se eligió en el hangar. Se consume: sólo vale una vez, la
## de esta salida.
func _obey_standing_order(unit: Node2D) -> void:
	var id := unit.get_instance_id()
	var order: Dictionary = _standing.get(id, {})
	if order.is_empty():
		return
	_standing.erase(id)
	var target: Unit = order.get("target")
	if is_instance_valid(target):
		# `set_attack_target` y no `receive_attack_order`: aquí sólo se anota a
		# quién, porque el aparato todavía no vuela. La maniobra la monta él al
		# arrancar, que es cuando tiene piloto con el que hacerla.
		unit.set_attack_target(target)
	elif order.has("where"):
		unit.receive_move_order(order["where"])


## Saca un aparato a cubierta.
##
## `fleet_entry` viaja hasta aquí porque **lo que sale tiene que poder volver**:
## es la casilla del pañol de la que se descontó, y sin ella no hay forma de
## devolverlo al recogerlo. Se le pone a la unidad al crearla, igual que hace el
## dique con una lancha.
func request_deploy(scene: PackedScene, squad: Squad = null,
		weapon_loadout: WeaponLoadout = null,
		standing_order: Dictionary = {},
		fleet_entry: Dictionary = {}) -> bool:
	# **Con alguien volviendo no se saca nada.** Aceptar el encargo descontaba el
	# aparato del pañol y luego no salía, porque la pista está guardada para el
	# que entra: el jugador veía «lanzando aeronave» sin que apareciera nadie.
	if recovery_pending():
		return false
	var elev_idx: int = _elevator_idx % _elevators.size()
	var slot := _next_slot_for_elevator(elev_idx)
	if slot == -1:
		return false

	var elevator: Marker2D = _elevators[elev_idx]
	_elevator_idx += 1
	# Su plaza queda guardada desde ya, con un vale: el aparato no existe hasta
	# que le toque el ascensor, y hasta entonces alguien tiene que tener su sitio
	# o dos peticiones seguidas eligen el mismo.
	_next_token -= 1
	var token := _next_token
	# El vale **apunta el destino y no reserva cubierta**. Lo que está en una cola
	# todavía no existe, así que no le estorba a nadie; el trozo se pide cuando
	# el aparato sale de verdad del ascensor.
	_dest[slot] = token

	# En coordenadas de la cubierta, no del mundo. Entre pedir el aparato y
	# sacarlo hay una cola, y para entonces el barco ya no está donde estaba.
	_taxi_queues[elev_idx].append({
		"scene": scene,
		"slot": slot,
		"token": token,
		"spawn_pos": elevator.position,
		"spawn_rot": elevator.rotation,
		"squad": squad,
		"weapon_loadout": weapon_loadout,
		"order": standing_order,
		"entry": fleet_entry,
	})
	_process_queue(elev_idx)
	return true


func has_free_slot() -> bool:
	for i in _SPOT_SEG.size():
		if not _spot_claimed(i):
			return true
	return false
func _process_queue(elev_idx: int) -> void:
	# **Por orden estricto, sin adelantar a nadie.** Aquí el orden es la regla que
	# llena primero la plaza de dentro: dejar pasar al de fuera porque el de
	# dentro espera acaba con alguien aparcado en la de fuera y el camino a la de
	# dentro cortado para siempre.
	if _taxi_queues[elev_idx].is_empty():
		return
	var job: Dictionary = _taxi_queues[elev_idx][0]
	var slot: int = job["slot"]
	var token: int = job["token"]
	var route := _taxi_route(slot, elev_idx)
	if not _route_free(route, 0):
		return
	_taxi_queues[elev_idx].pop_front()

	# **Nace colgado de la cubierta, no del mundo.** Mientras esté aquí no vuela:
	# es carga, y la carga viaja con el barco. Colgado del mundo, el día que el
	# buque se mueva el aparato se queda clavado en el mar mientras la cubierta se
	# le escapa por debajo — y todo lo que hay debajo (ascensor, taxi, carrera)
	# apunta a puntos capturados al empezar, que dejarían de ser su sitio.
	#
	# Nada más se entera del cambio: el HUD, la selección, el armamento y los dos
	# mapas buscan a las unidades por grupo, no por quién es su padre.
	var unit: Node2D = job["scene"].instantiate()
	add_child(unit)
	unit.position = job["spawn_pos"]
	unit.rotation = job["spawn_rot"]
	unit.scale = Vector2.ONE * spawn_scale
	var unit_id := unit.get_instance_id()
	# El vale ya no hace falta: el aparato existe y toma la ruta por su cuenta.
	_dest[slot] = unit_id
	_hold(route, unit_id)
	_movement_started()

	var order: Dictionary = job.get("order", {})
	if not order.is_empty():
		_standing[unit_id] = order
	var u := unit as Unit
	if u != null:
		u.taking_off = true
		u.set_weapon_loadout(job["weapon_loadout"])
		u.fleet_entry = job.get("entry", {})
		# De aquí salió y aquí vuelve. Es lo que hace que "regresar" sea una
		# orden sin destino que dar, igual que con la lancha.
		#
		# Se pregunta por si **sabe volver** y no por el modelo: la cubierta no
		# tiene por qué conocer qué aparatos existen, y el que todavía no sepa
		# recogerse simplemente no lleva el dato.
		if u.has_method("recovery_granted"):
			u.set("home_deck", self)
		var squad: Squad = job["squad"]
		if squad != null:
			u.squad = squad
			squad.add(u, slot)
	# Se murió en cubierta. Va por `died` y no por `tree_exited` porque soltarlo
	# al mundo al despegar es también salir de este árbol, y con `tree_exited`
	# no hay forma de distinguir las dos cosas.
	if u != null:
		u.died.connect(func(_unit: Unit) -> void:
			_units[slot] = null
			if _dest[slot] == unit_id:
				_dest[slot] = 0
			_handed.erase(unit_id)
			_standing.erase(unit_id)
			_release_all(unit_id)
		)
	_free_slot_when_airborne(slot, unit)

	# El ascensor se suelta por tiempo y el resto de la ruta al acabar de rodar.
	# Son dos cosas distintas: la rampa vuelve a estar libre mucho antes de que
	# el aparato llegue a su sitio.
	get_tree().create_timer(elevator_cycle_time).timeout.connect(func() -> void:
		_release([_ELEV_SEG[elev_idx]], unit_id)
	)

	var target: Marker2D = _takeoff_points[slot]
	var waypoint_idx: int = _SLOT_WAYPOINTS[slot]

	# Todo el rodaje va en `position` —coordenadas de la cubierta— y no en
	# `global_position`. Un tween apunta a un valor fijo capturado al empezar: en
	# mundo, ese valor deja de ser el punto de despegue en cuanto el barco avanza,
	# y el aparato rueda hacia donde la cubierta estaba. En local el punto no se
	# mueve nunca, porque está pintado en la propia cubierta.
	var tw := unit.create_tween()
	var desde: Vector2 = unit.position
	var rot: float = unit.rotation
	if waypoint_idx >= 0:
		var wp: Marker2D = _takeoff_points[waypoint_idx]
		rot = _face_and_roll(tw, unit, desde, wp.position, rot)
		desde = wp.position
	_face_and_roll(tw, unit, desde, target.position, rot)

	tw.finished.connect(func() -> void:
		unit.rotation = target.rotation
		_units[slot] = unit
		_dest[slot] = 0
		_movement_ended()
		# Ya está aparcado: suelta el través y la plaza por la que pasó, y se
		# queda con la suya, que es donde está.
		var sobra: Array = [_LANE_SEG[elev_idx]]
		if waypoint_idx >= 0:
			sobra.append(_SPOT_SEG[waypoint_idx])
		# Lo que no usa pista ya está donde tiene que estar: aparcar **es** su
		# despegue terminado, y el control es suyo desde este momento. Esperar a
		# que le llegue el turno de la tanda lo dejaba posado y sordo a las
		# órdenes mientras otro corría por la pista — y como el que ordena
		# sacarlo es el jugador, sin control no había forma de desatascarlo.
		if _launch_speed_of(unit) <= 1.0:
			_hand_over_control(unit)
		_release(sobra, unit_id)
	)
## ¿Está la cubierta lista para soltar la tanda?
##
## No mira si hay alguien entrando: eso lo contesta cada carrera por su cuenta,
## con su ruta. Aquí sólo se comprueba que **haya alguien a quien de verdad se
## pueda soltar**, porque montar una tanda para no soltar a nadie deja un
## temporizador latiendo para siempre.
func _check_ready_to_launch() -> void:
	if _launching or recovery_pending():
		return
	# Con aparatos todavía saliendo o entrando por un ascensor se espera: la
	# tanda se arma de una vez y con la lista de los que hay, así que soltarla a
	# medio llenar deja fuera al que estaba a punto de aparcar.
	if not _taxi_queues[0].is_empty() or not _taxi_queues[1].is_empty():
		return
	if not _stow_queues[0].is_empty() or not _stow_queues[1].is_empty():
		return
	# Y con alguien **de camino a su plaza** —rodando o entrando a posarse— se
	# espera, porque la lista de a quién soltar se hace de una vez: armarla ahora
	# dejaría fuera al que está a punto de aparcar. Plaza pedida y nadie encima
	# es justo eso.
	for i in _units.size():
		if _units[i] == null and not _spot_free(i):
			return
	var hay_quien_pueda := false
	var estorbo_en_el_aire := false
	for i in _units.size():
		# **El que acaba de entrar no es candidato a salir.** Está posado en su
		# plaza y con el control cedido, así que por fuera no se distingue de uno
		# recién sacado del hangar; pero la cubierta todavía lo está llevando al
		# ascensor. Sin esto se montaba una tanda con él dentro y el aparato
		# recibía a la vez la carrera de despegue y el rodaje de vuelta: dos
		# tirones opuestos, y el resultado era verlo ir de reversa por la pista.
		if _recovering.has(i):
			continue
		var unidad: Node2D = _units[i]
		if not is_instance_valid(unidad) or _handed.has(unidad.get_instance_id()):
			continue
		if _launch_speed_of(unidad) <= 1.0:
			hay_quien_pueda = true
			break
		if not _route_free(_launch_route(i), unidad.get_instance_id()):
			continue
		# Y lo que vuela por encima de la pista sin deberle nada a la cubierta:
		# un helicóptero que acaba de despegar y sigue subiendo ahí no tiene
		# ninguna reserva puesta, así que hay que mirarlo aparte.
		var estorbo := _runway_blocker_from(i)
		if estorbo != null:
			if not _units.has(estorbo):
				estorbo_en_el_aire = true
			continue
		hay_quien_pueda = true
		break
	if not hay_quien_pueda:
		# Si lo que estorba está posado o reservado, ya avisará al soltarlo. Si
		# está **volando** por encima de la pista no es de la cubierta y no tiene
		# por qué decirle nada a nadie: hay que volver a mirar por cuenta propia.
		if estorbo_en_el_aire:
			_retry_later()
		return
	_launching = true
	get_tree().create_timer(launch_delay).timeout.connect(_start_launch_sequence)
func _start_launch_sequence() -> void:
	var order: Array = []
	for i in range(_units.size() - 1, -1, -1):
		if is_instance_valid(_units[i]):
			order.append(i)
	_launch_next(order)


func _launch_next(order: Array) -> void:
	if order.is_empty():
		_launching = false
		# La lista de a quién soltar se hizo al empezar la tanda, y soltarla lleva
		# su tiempo: lo que haya aparcado por el camino no está en ella y su aviso
		# —el final de su taxi— se topó con `_launching` puesto. Sin volver a
		# preguntar aquí se queda en cubierta sin control, sordo a las órdenes,
		# hasta que otra salida vuelva a abrir la puerta y lo arrastre de paso.
		#
		# Y lo mismo con los que esperan para rodar: la pista queda libre justo
		# ahora, así que este es el sitio donde se les deja salir. Primero ellos
		# y después la pregunta, porque uno que empieza a rodar es motivo para
		# **no** lanzar todavía.
		for i in _taxi_queues.size():
			_process_queue(i)
		_check_ready_to_launch()
		return
	var slot: int = order.pop_front()
	# La lista se hizo al empezar la tanda y desde entonces puede haber entrado
	# alguien en esa plaza. Al que está volviendo no se le lanza.
	if _recovering.has(slot):
		_launch_next(order)
		return
	var unit: Node2D = _units[slot]
	if not is_instance_valid(unit):
		_launch_next(order)
		return

	# Lo que no despega por pista se queda donde está. Un helicóptero llega a su
	# sitio en cubierta y ahí espera: no tiene carrera que hacer ni proa que
	# rebasar, así que meterlo en esta secuencia lo mandaría deslizándose hacia
	# adelante como si fuera un avión.
	#
	# Se sabe preguntándole a él —`get_takeoff_speed()` a 0— y no con una lista
	# de modelos: la cubierta no tiene por qué conocer qué aparatos existen.
	if _launch_speed_of(unit) <= 1.0:
		# Se le cede el control igual —ya es suyo—, pero **posado**: despega
		# cuando su piloto quiera y no cuando el barco diga. Normalmente ya lo
		# tiene desde que aparcó, y esta llamada no hace nada; está por si algún
		# día llega aquí algo que no pasó por el taxi.
		#
		# **La tanda no se para por él.** Pararla era pagar con toda la cubierta
		# un estorbo que sólo afecta a quien tenga detrás, y eso se pregunta
		# aparte — ver [method _runway_blocker_from].
		_hand_over_control(unit)
		_launch_next(order)
		return

	# La carrera pide su plaza y todas las de delante, porque les pasa justo por
	# encima. Si alguna está pedida —hay alguien aparcado, alguien rodando hacia
	# ella o alguien entrando a posarse— éste se queda donde está y sale cuando se
	# suelte, que es lo que hace [method _deck_freed]. Se le espera a él y no al
	# revés: al que vuela se le acaba el combustible.
	var unit_id := unit.get_instance_id()
	var route := _launch_route(slot)
	if not _route_free(route, unit_id):
		_launch_next(order)
		return

	# Y lo que vuela por encima de la pista sin deberle nada a la cubierta: un
	# helicóptero que acaba de despegar sigue un buen rato suspendido ahí, y no
	# tiene ninguna reserva puesta. Si lo que estorba está volando no va a avisar
	# al quitarse, así que hay que volver a mirar — ver [method _retry_later].
	if _runway_blocker_from(slot) != null:
		_launch_next(order)
		return

	_hold(route, unit_id)
	_movement_started()
	_units[slot] = null

	var launch_speed := _launch_speed_of(unit)
	var runway_dist: float = unit.position.distance_to(_launch_point.position)
	# Arranca parado y acelera. Con un ease-in cuadrático, recorrer `runway_dist`
	# en este tiempo deja al avión yendo exactamente a `launch_speed` al llegar
	# a la proa: el factor 2 es la media de una aceleración constante, no un
	# número puesto a ojo. De ahí en adelante ya vuela a esa velocidad, que es
	# la misma con la que el piloto recoge el control.
	var runway_dur: float = 2.0 * runway_dist / launch_speed
	var post_duration: float = post_bow_distance / launch_speed

	# La carrera también en coordenadas de cubierta: el avión rueda **sobre** el
	# barco, así que si el barco avanza durante la carrera el avión avanza con él.
	var tw := unit.create_tween()
	tw.tween_property(unit, "position", _launch_point.position, runway_dur) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	var seguir := _seguir_una_vez(unit, order)
	tw.finished.connect(func() -> void:
		# Rebasada la proa ya está en el aire y deja de ser carga del barco: se
		# suelta al mundo antes del último tramo, o seguiría pegado a él.
		_detach(unit)
		var direction: Vector2 = unit.global_transform.y
		var end_pos: Vector2 = unit.global_position + direction * post_bow_distance
		var fly_tw := unit.create_tween()
		fly_tw.tween_property(unit, "global_position", end_pos, post_duration)
		fly_tw.finished.connect(func() -> void:
			_hand_over_control(unit)
			# El siguiente arranca al **rebasar** la proa, no al llegar a ella:
			# hasta entonces el avión sigue sobre la pista.
			seguir.call())
		_scale_climb(unit)
	)


## Sigue con la tanda, y **una sola vez**.
##
## Un despegue por vez mientras compartan pista: la carrera reserva su plaza y
## todas las de delante, así que el de detrás no arranca hasta que ésta se
## suelte. Y se suelta al **rebasar** la proa, no al llegar a ella.
##
## Va guardada porque a la continuación se llega por dos sitios —se fue, o se
## murió por el camino— y llamar dos veces se saltaría un aparato de la lista.
func _seguir_una_vez(unit: Node2D, order: Array) -> Callable:
	var unit_id := unit.get_instance_id()
	var hecho := [false]
	var seguir := func() -> void:
		if hecho[0]:
			return
		hecho[0] = true
		_movement_ended()
		# Aquí queda libre la pista entera, y con ella se pueden desatascar tanto
		# los que esperan entrar como los que esperan rodar.
		_release_all(unit_id)
		_launch_next(order)
	# Por `died` y no por `tree_exited`: al rebasar la proa el aparato se suelta
	# al mundo, y eso también es salir de este árbol. Con `tree_exited` la tanda
	# arrancaba al **llegar** a la proa en vez de al rebasarla.
	var u := unit as Unit
	if u != null:
		u.died.connect(func(_dead: Unit) -> void: seguir.call(), CONNECT_ONE_SHOT)
	return seguir
## La plaza de lo que despega en vertical **no queda libre al soltarlo**: se
## queda posado en ella hasta que se le ordene ir a algún sitio, y hasta entonces
## sigue ocupando cubierta. Sin esto, el siguiente aparato taxiaría hasta el
## mismo punto y se le montaría encima.
##
## Cuándo se va lo dice él, que es el único que lo sabe: puede tirarse ahí lo que
## el jugador tarde en darle una orden. Se engancha al crearlo y no al soltarlo,
## porque la orden puede llegar antes: al aparato se le puede mandar a un sitio
## mientras el barco todavía lo está colocando.
##
## Suelta **sólo su plaza** y no todo lo que tenga reservado. El que sale por
## pista también despega en algún punto de la carrera, y soltarle ahí la pista
## entera dejaría arrancar al de detrás mientras el primero todavía la recorre.
func _free_slot_when_airborne(slot: int, unit: Node2D) -> void:
	if not unit.has_signal("took_off"):
		return
	var unit_id := unit.get_instance_id()
	unit.took_off.connect(func() -> void:
		_units[slot] = null
		# Se despegó del suelo: ya no es carga del barco. Se suelta al mundo aquí
		# y no al cederle el control, porque entre una cosa y la otra puede
		# pasarse la partida entera posado en cubierta, y ahí sí viaja con él.
		_detach(unit)
		_release([_SPOT_SEG[slot]], unit_id)
	, CONNECT_ONE_SHOT)
func _detach(unit: Node2D) -> void:
	if not is_instance_valid(unit) or unit.get_parent() != self:
		return
	var world: Node = get_parent().get_parent()
	if world == null:
		world = get_tree().current_scene
	unit.reparent(world, true)


## Quién estorba la carrera del de esta plaza, o `null` si está despejada.
##
## **Se pregunta por quién está encima de la pista, no por qué plazas están
## ocupadas**, y ahí estaba el fallo: un helicóptero que acaba de despegar deja
## su plaza libre en el acto y se queda un buen rato suspendido justo encima,
## mientras sube. Contando plazas, el avión de detrás arrancaba y le pasaba por
## dentro — medido: 0,2 px de separación entre los dos.
##
## La pista es la franja que va de su punto de despegue a la proa: sólo cuenta
## lo que tenga **delante**, porque lo que quede a popa no lo va a alcanzar. Y
## sólo mira aeronaves: por la cubierta no se pasea nada más.
##
## No se incluye el tramo de más allá de la proa. Ahí el avión ya está subiendo y
## despejando, y contarlo dejaría el barco sin lanzar cada vez que un helicóptero
## se para a la salida.
func _runway_blocker_from(slot: int) -> Node2D:
	var from: Vector2 = _takeoff_points[slot].position
	var bow: Vector2 = _launch_point.position
	var lo: float = minf(from.y, bow.y)
	var hi: float = maxf(from.y, bow.y)
	var launcher: Node2D = _units[slot]
	for node in get_tree().get_nodes_in_group(_AIR_GROUP):
		var other := node as Node2D
		if other == null or other == launcher or not is_instance_valid(other):
			continue
		var p: Vector2 = to_local(other.global_position)
		if absf(p.x - bow.x) > runway_clearance:
			continue
		if p.y < lo or p.y > hi:
			continue
		return other
	return null


## Vuelve a mirar dentro de un momento, y sólo una espera a la vez. Es para el
## estorbo que no avisa al quitarse: lo que vuela por encima de la pista no es de
## la cubierta y no le debe ningún aviso.
func _retry_later() -> void:
	if _retry_pending:
		return
	_retry_pending = true
	get_tree().create_timer(retry_delay).timeout.connect(func() -> void:
		_retry_pending = false
		_check_ready_to_launch()
	)


## A qué velocidad sale de cubierta este avión. Se lo pregunta a él: cada
## modelo tiene la suya y es la misma con la que el piloto recoge el control.
##
## La cubierta no tiene velocidad de despegue propia, y tenerla era justo el
## problema: lanzaba a 120 a un avión que como mucho vuela a 90, así que el
## piloto lo recortaba en silencio y el avión "frenaba" al soltar amarras.
func _launch_speed_of(unit: Node2D) -> float:
	var speed := 0.0
	if unit.has_method("get_takeoff_speed"):
		speed = float(unit.get_takeoff_speed())
	return maxf(speed, 1.0)


## Sube la escala de `spawn_scale` a 1.0 en tres saltos. Si el avión ya sale
## a 1.0 no hay nada que animar.
func _scale_climb(unit: Node2D) -> void:
	if is_equal_approx(spawn_scale, 1.0):
		return
	const STEPS := 3
	var interval: float = climb_duration / float(STEPS)
	var tw := unit.create_tween()
	for i in STEPS:
		var s: float = lerpf(spawn_scale, 1.0, float(i + 1) / float(STEPS))
		tw.tween_interval(interval)
		tw.tween_callback(func() -> void:
			if is_instance_valid(unit):
				unit.scale = Vector2(s, s)
		)


## A qué plaza de ese ascensor va el siguiente, o −1 si no cabe.
##
## Se salta la plaza de dentro cuando la de fuera tiene a alguien aparcado que no
## se va a mover solo: para llegar hay que rodarle por encima, y no se puede.
## **Decirlo aquí es lo que evita el fallo caro**: aceptar el encargo, descontar
## el aparato del pañol y que no llegue a existir nunca.
func _next_slot_for_elevator(elev_idx: int) -> int:
	var priority: Array = _ELEVATOR_SLOTS[elev_idx % _ELEVATOR_SLOTS.size()]
	for slot in priority:
		if _spot_claimed(slot):
			continue
		var wp: int = _gate_of(elev_idx)
		if wp != slot and _units[wp] != null and not _leaving_soon(wp):
			continue
		return slot
	return -1
## ¿Están libres todos los trozos de esta ruta para este dueño?
##
## Los que ya son suyos cuentan como libres: un aparato aparcado tiene reservada
## su plaza, y no puede estorbarse a sí mismo al salir de ella.
func _route_free(route: Array, owner: int) -> bool:
	for seg in route:
		var quien: int = _held.get(seg, 0)
		if quien != 0 and quien != owner:
			return false
	return true


## Reserva la ruta entera. Se llama después de comprobarla, nunca en su lugar.
func _hold(route: Array, owner: int) -> void:
	for seg in route:
		_held[seg] = owner


## Suelta los trozos indicados, si eran suyos.
func _release(route: Array, owner: int) -> void:
	for seg in route:
		if _held.get(seg, 0) == owner:
			_held.erase(seg)
	_deck_freed()


## Suelta todo lo que tuviera reservado.
func _release_all(owner: int) -> void:
	for seg in _held.keys():
		if _held[seg] == owner:
			_held.erase(seg)
	_deck_freed()


func _deck_freed() -> void:
	if _sweeping:
		_sweep_again = true
		return
	_sweeping = true
	_sweep_again = true
	while _sweep_again:
		_sweep_again = false
		# **Primero los que se van.** El orden no es un detalle: el que está
		# posado y quiere bajar necesita rodar por encima de la plaza de fuera, y
		# si se atiende antes al que llega, éste se queda con esa plaza y el de
		# dentro no sale nunca. Medido: con seis entrando en fila, cuatro se
		# quedaron clavados en cubierta para siempre.
		for i in _ELEV_SEG.size():
			_process_stow(i)
		_offer_recovery()
		for i in _ELEV_SEG.size():
			_process_queue(i)
		_check_ready_to_launch()
	_sweeping = false
	_refresh_mode()


## La carrera de despegue: su plaza y **todas las que tiene por delante**, porque
## la pista pasa justo por encima de ellas. Lo que quede a popa no se pide, y eso
## es lo que deja despegar por proa mientras se recoge por popa.
func _launch_route(slot: int) -> Array:
	var r: Array = []
	for i in range(slot, _SPOT_SEG.size()):
		r.append(_SPOT_SEG[i])
	return r


## El rodaje entre un ascensor y una plaza. Vale para los dos sentidos: se sale y
## se vuelve por el mismo sitio.
func _taxi_route(slot: int, elev_idx: int) -> Array:
	var r: Array = [_ELEV_SEG[elev_idx], _LANE_SEG[elev_idx]]
	var puerta := _gate_of(elev_idx)
	for i in range(mini(slot, puerta), maxi(slot, puerta) + 1):
		r.append(_SPOT_SEG[i])
	return r


## La plaza que queda a la altura de ese ascensor: por ahí se entra y se sale de
## él. Sale de los marcadores y no de una tabla, así que mover un ascensor en el
## editor mueve con él su acceso.
func _gate_of(elev_idx: int) -> int:
	var y: float = _elevators[elev_idx].position.y
	var mejor := 0
	var dist := INF
	for i in _takeoff_points.size():
		var d := absf(_takeoff_points[i].position.y - y)
		if d < dist:
			dist = d
			mejor = i
	return mejor


## Por qué ascensor baja el que está en esa plaza: **el que le quede más cerca
## rodando**.
##
## No es la misma pregunta que por cuál sale a cubierta, y contestar las dos con
## la misma tabla era el fallo. Aquélla reparte plazas al **sacar** aparatos;
## ésta mide el camino de vuelta. Desde la plaza intermedia el ascensor central
## queda a 42 px y el de popa a 67, y la tabla mandaba al de popa: el avión se
## recorría la pista al revés para llegar al más lejano de los dos.
func _stow_elevator_of(slot: int) -> int:
	var mejor := 0
	var dist := INF
	var aqui: Vector2 = _takeoff_points[slot].position
	for e in _elevators.size():
		var puerta: Vector2 = _takeoff_points[_gate_of(e)].position
		var largo := absf(aqui.y - puerta.y) \
				+ puerta.distance_to(_elevators[e].position)
		if largo < dist:
			dist = largo
			mejor = e
	return mejor


## La entrada. Hay dos formas de entrar y por eso hay dos rutas: por el costado
## de babor, la de todo el que puede pararse en el aire, y rodada por el eje
## desde popa, la del Harrier cargado — que por eso pide además las plazas que va
## a sobrevolar mientras frena.
func _recovery_route(slot: int, along_deck: bool) -> Array:
	if along_deck:
		var r: Array = [Seg.AXIS]
		for i in range(0, slot + 1):
			r.append(_SPOT_SEG[i])
		return r
	return [Seg.APPROACH, _CROSS_SEG[slot], _SPOT_SEG[slot]]


## ¿Está esa plaza sin reservar por nadie?
func _spot_free(slot: int) -> bool:
	return not _held.has(_SPOT_SEG[slot])


## ¿Hay alguien aparcado ahí, o de camino a aparcar ahí? Es la pregunta del
## hangar y de la recuperación: quién se va a quedar en esa plaza, no quién le
## pasa por encima.
func _spot_claimed(slot: int) -> bool:
	return _units[slot] != null or _recovering.has(slot) or _dest[slot] != 0


## Empieza un movimiento: algo se mueve por la cubierta desde ahora.
func _movement_started() -> void:
	_moving += 1
	_refresh_mode()


func _movement_ended() -> void:
	_moving = maxi(_moving - 1, 0)
	_refresh_mode()


## ¿Entra rodando por el eje? Lo contesta el aparato, que es el único que sabe
## con cuánto peso viene. El que no sepa contestar entra por el costado, que es
## lo que hace todo lo que puede quedarse quieto en el aire.
func _lands_along_deck(unit: Node2D) -> bool:
	if unit != null and unit.has_method("lands_along_deck"):
		return bool(unit.call("lands_along_deck"))
	return false


## Lo que la cubierta está haciendo, para contarlo.
##
## **No es la misma pregunta que [method _busy_on_deck]**: aquí interesa la tanda
## entera —que puede durar lo que el jugador tarde en mover un helicóptero
## posado— y allí sólo si hay algo moviéndose ahora mismo. Un rótulo que
## parpadeara entre cada aparato de la misma tanda contaría algo que no pasa.
##
## Y ninguna de las dos coordina nada. Coordinar es saber **dónde**, y eso sólo
## lo contesta la tabla de trozos.
func mode() -> Mode:
	if recovery_pending():
		return Mode.RECOVERING
	if _launching or _busy_on_deck():
		return Mode.LAUNCHING
	for cola in _taxi_queues:
		if not cola.is_empty():
			return Mode.LAUNCHING
	return Mode.IDLE


## ¿Hay alguna aeronave volviendo, esté donde esté?
##
## **Cuentan también las que esperan turno.** Todas las que están en el circuito
## van a aterrizar, así que la cubierta está ocupada recogiendo de principio a
## fin. Diciendo «en espera» entre un aterrizaje y el siguiente, el jugador pedía
## un despegue, el buque lo aceptaba, no salía nadie —la pista está guardada para
## el que entra— y el rótulo saltaba a «recuperando» dos segundos después.
func recovery_pending() -> bool:
	return not _recovering.is_empty() or not _inbound.is_empty()


## Hay algo moviéndose por la cubierta **ahora mismo**. Es para el rótulo: una
## tanda abierta con todo el mundo quieto sigue siendo una tanda, y algo rodando
## sigue siendo movimiento aunque no haya tanda.
func _busy_on_deck() -> bool:
	return _moving > 0


## El centro de los circuitos de espera, por delante de la proa.
func hold_center() -> Node2D:
	return _hold_center


func _refresh_mode() -> void:
	var ahora := mode()
	if ahora == _mode:
		return
	_mode = ahora
	mode_changed.emit(ahora)


## Pide entrar. Devuelve la plaza concedida, o −1 si toca esperar.
##
## Se espera porque **no queda sitio libre por el que meterse**, no porque la
## cubierta esté ocupada haciendo algo. Y esperar no es que le hayan dicho que
## no: queda apuntado, con su puesto en la cola, y se le avisa por
## `recovery_granted` en cuanto haya ruta. Sin esa lista la petición se perdería
## sin un solo error que lo delate.
func request_recovery(unit: Node2D) -> int:
	if not is_instance_valid(unit):
		return -1
	var id := unit.get_instance_id()
	var ya := _recovery_slot_of(id)
	if ya >= 0:
		return ya
	if not _inbound.has(id):
		_inbound.append(id)
		# Se puede morir de camino, y entonces hay que soltarle la plaza. Va por
		# `died` y no por `tree_exited`: al posarse se reparenta a la cubierta,
		# y eso también es salir del árbol del mundo.
		var u := unit as Unit
		if u != null:
			u.died.connect(func(_dead: Unit) -> void: cancel_recovery(id),
					CONNECT_ONE_SHOT)
	_offer_recovery()
	# Los puestos se reparten también **al entrar** en la cola y no sólo al salir
	# de ella. Con sólo lo segundo, el que llega y no cabe se queda con el puesto
	# de fábrica: todos el cero, todos en el mismo sitio, unos encima de otros.
	_refresh_holds()
	_refresh_mode()
	return _recovery_slot_of(id)
## Se retira: el jugador lo mandó a otro sitio, o se murió por el camino.
##
## **Aquí se suelta la ruta entera y no sólo la plaza.** Un aparato al que se
## desvía a mitad de aproximación deja reservado también el carril y la subida
## por el costado, y con eso la cubierta se queda sin poder recoger a nadie más
## sin que nada lo delate.
func cancel_recovery(id: int) -> void:
	var estaba := _inbound.has(id)
	_inbound.erase(id)
	var slot := _recovery_slot_of(id)
	if slot >= 0:
		_recovering.erase(slot)
	_release_all(id)
	if estaba:
		_refresh_holds()
	_refresh_mode()
## Reparte entrada a los que esperan, **por orden de llegada**.
##
## Antes elegía al más cercano, y eso hacía que el último se colara: con todos
## dando vueltas, quién es el más cercano cambia cada segundo según por dónde ande
## cada uno de su círculo. El orden es el de la cola y punto.
func _offer_recovery() -> void:
	var i := 0
	while i < _inbound.size():
		if is_instance_valid(instance_from_id(_inbound[i])):
			i += 1
		else:
			_inbound.remove_at(i)
	var entraron := false
	while not _inbound.is_empty():
		var id: int = _inbound[0]
		var unit := instance_from_id(id) as Node2D
		var along := _lands_along_deck(unit)
		var slot := _free_slot_for_recovery(id, along)
		if slot == -1:
			break
		_inbound.pop_front()
		entraron = true
		_recovering[slot] = id
		_hold(_recovery_route(slot, along), id)
		if along:
			_hold(_taxi_route(slot, recovery_elevator()), id)
		_units[slot] = null
		if unit.has_method("recovery_granted"):
			unit.recovery_granted(slot)
	if entraron:
		_refresh_holds()
func recovery_elevator() -> int:
	var mejor := 0
	for e in _elevators.size():
		var y: float = _takeoff_points[_gate_of(e)].position.y
		if y < _takeoff_points[_gate_of(mejor)].position.y:
			mejor = e
	return mejor


## La plaza donde se posa todo el que entra.
func recovery_slot() -> int:
	return _gate_of(recovery_elevator())


## ¿Se le puede dar entrada ahora? Devuelve la plaza, o −1.
##
## **Son dos reglas distintas porque son dos maniobras distintas.**
##
## El que llega rodando entra de uno en uno y siempre a la misma plaza, la que
## está a la altura del ascensor central: necesita la pista entera para frenar,
## así que repartirle sitios distintos daba una entrada distinta cada vez. Se le
## reserva la secuencia completa, bajada incluida.
##
## El que se posa en vertical no necesita nada de eso: baja de arriba sobre la
## plaza que le den. Coge la libre más a popa, que es la que menos cubierta le
## obliga a cruzar, y pueden entrar varios a la vez porque no comparten pista.
func _free_slot_for_recovery(owner: int, along_deck: bool) -> int:
	if along_deck:
		# Que entre uno cada vez no hace falta escribirlo: **todos van a la misma
		# plaza**, así que la ruta ya lo impone. Y al no escribirlo, el siguiente
		# recibe turno en cuanto el anterior deja la plaza, sin esperar a que
		# acabe de bajar por el ascensor.
		var fija := recovery_slot()
		if _dest[fija] != 0:
			return -1
		if not _route_free(_recovery_route(fija, true), owner):
			return -1
		if not _route_free(_taxi_route(fija, recovery_elevator()), owner):
			return -1
		return fija
	for slot in _SPOT_SEG.size():
		if _dest[slot] != 0:
			continue
		# La bajada desde esa plaza cruza otras, y si en alguna hay alguien
		# aparcado que no se va a mover solo, el que entre ahí se queda encerrado.
		var tapada := false
		var bajada := _taxi_route(slot, _stow_elevator_of(slot))
		for otra in _SPOT_SEG.size():
			if otra == slot or _units[otra] == null or _leaving_soon(otra):
				continue
			if bajada.has(_SPOT_SEG[otra]):
				tapada = true
				break
		if tapada:
			continue
		if _needed_by_stow(slot):
			continue
		if _route_free(_recovery_route(slot, false), owner):
			return slot
	return -1
func _needed_by_stow(slot: int) -> bool:
	var seg: int = _SPOT_SEG[slot]
	for elev_idx in _stow_queues.size():
		for job in _stow_queues[elev_idx]:
			if _taxi_route(job["slot"], elev_idx).has(seg):
				return true
	for k in _recovering:
		if k != slot and _taxi_route(k, _stow_elevator_of(k)).has(seg):
			return true
	return false


func _leaving_soon(slot: int) -> bool:
	var unit: Node2D = _units[slot]
	if unit == null:
		return false
	for cola in _stow_queues:
		for job in cola:
			if job["unit"] == unit:
				return true
	# Ya está rodando hacia el ascensor: su plaza sigue pedida pero es cuestión
	# de segundos.
	return _recovering.has(slot)
func _recovery_slot_of(id: int) -> int:
	for slot in _recovering:
		if _recovering[slot] == id:
			return slot
	return -1
func _end_recovery() -> void:
	_refresh_mode()
func initial_point(on_axis: bool) -> Vector2:
	var entry := final_point() if on_axis else join_point()
	return entry + global_transform.y.normalized() * pattern_leg


## Por donde se entra: por detrás del buque, en coordenadas del mundo.
##
## Es también donde espera el que todavía no tiene plaza. Que sean el mismo punto
## no es ahorro: el que espera ya está colocado para arrancar la arrimada en
## cuanto le den paso.
func join_point() -> Vector2:
	return to_global(Vector2(
			_takeoff_points[0].position.x + abeam_offset,
			_recovery_join.position.y))


## El punto de **entrada por el eje**, en coordenadas del mundo: a la misma
## altura que el de entrada normal pero sobre la línea de la pista.
##
## Es por donde entra lo que toca rodando. Se sale por proa y se entra por popa,
## así que es la misma franja recorrida en el otro sentido y en otro momento.
func final_point() -> Vector2:
	return to_global(Vector2(
			_takeoff_points[0].position.x, _recovery_join.position.y))


## El punto de arrimada de esa plaza: a su altura pero al costado y fuera del
## buque. En coordenadas del mundo.
## Donde toca el que entra rodando. **La frenada empieza aquí y no antes**: con
## el punto de toma metido en el agua, el avión terminaba de frenar antes de
## llegar al barco y la cubierta no pintaba nada. Poniéndolo en la popa, los
## 200 px de cubierta que tiene delante son su pista.
func ramp_point() -> Vector2:
	return to_global(_recovery_ramp.position)


## Un punto **sobre la línea de cubierta**, por delante de donde esté el que
## pregunta y a la distancia que pida.
##
## Es lo que mete a un avión en la raya en vez de hacerle cortar hacia ella. Al
## perseguir un punto que va corriendo por la línea, el rumbo acaba siendo el de
## la línea, porque el punto siempre está encima. Y funciona venga de donde
## venga y mirando a donde mire, que es justo lo que no daba un punto fijo: allí
## se llegaba con el morro donde tocara, y enderezarse costaba media vuelta y
## ochenta píxeles de desvío.
func axis_lookahead(from: Vector2, ahead: float, max_intercept_deg: float) -> Vector2:
	var here := to_local(from)
	var eje: Vector2 = _launch_point.position
	# **El ángulo con que se corta la línea va acotado, y de ahí sale cuánto hay
	# que mirar por delante.** Con una distancia fija, el que llega muy separado
	# apunta casi perpendicular a la raya, la cruza y tiene que volver: es el
	# zigzag de pasarse al otro lado. Alejando el punto en proporción al desvío,
	# el corte nunca pasa de este ángulo y el avión vira y se endereza a la vez,
	# sin cerrar el giro.
	var desvio := absf(here.x - eje.x)
	var pendiente := tan(deg_to_rad(clampf(max_intercept_deg, 5.0, 85.0)))
	var delante := maxf(ahead, desvio / pendiente)
	# **Cuanto más cerca de la popa, más cerca mira.** Con la mirada larga fija,
	# los últimos píxeles de desvío no se corrigen nunca: el ángulo sale tan
	# abierto que el avión llega igual de torcido que empezó. Acortándola al
	# final, lo poco que quede se endereza justo antes de tocar.
	var falta := here.y - _recovery_ramp.position.y
	if falta > 0.0:
		delante = minf(delante, maxf(falta * 0.7, 120.0))
	return to_global(Vector2(eje.x, maxf(here.y - delante, eje.y)))


## ¿Está ya lo bastante a popa para empezar la entrada rodada?
##
## Es una **línea y no un radio**, por lo mismo que la de la popa. Un avión no
## llega a un punto: pasa cerca, y con un radio de 45 px lo normal es fallarlo,
## dar la vuelta y volver a entrar con el morro al revés. Eso era la mitad del
## viraje feo — no venía de cómo gira, venía de tener que darse la vuelta.
func astern_of_pattern(world_pos: Vector2, ancho: float) -> bool:
	var aqui := to_local(world_pos)
	if aqui.y < _recovery_ramp.position.y + pattern_leg:
		return false
	return absf(aqui.x - _launch_point.position.x) <= ancho


## Donde se engancha la recta de entrada: sobre el eje de cubierta y por detrás
## de la popa. Un solo punto, cerca, y se mueve con el barco.
func approach_gate() -> Vector2:
	return to_global(Vector2(_launch_point.position.x,
			_recovery_ramp.position.y + approach_gate_len))


## ¿Está ya por detrás de la popa con sitio para la entrada?
func astern_with_room(world_pos: Vector2, min_room: float) -> bool:
	return to_local(world_pos).y >= _recovery_ramp.position.y + min_room


## El tramo paralelo del circuito, a la altura que se pida.
func pattern_downwind(y: float) -> Vector2:
	return to_global(Vector2(_launch_point.position.x - pattern_offset, y))


## Por dónde se entra al circuito: el tramo paralelo, a la altura de la proa.
func pattern_entry() -> Vector2:
	return pattern_downwind(_launch_point.position.y - pattern_entry_lead)


## Por dónde se sale de la espera: donde el círculo toca la línea de la pista.
func release_point() -> Vector2:
	return to_global(Vector2(_launch_point.position.x, _hold_center.position.y))


## ¿Está ahí y apuntando a la popa, o sea listo para seguir recto?
func at_release_point(world_pos: Vector2, facing: float) -> bool:
	if world_pos.distance_to(release_point()) > release_radius:
		return false
	return absf(angle_difference(facing, bow_heading())) <= deg_to_rad(release_cone_deg)


## ¿Puede meterse ya en el tramo paralelo desde donde está?
##
## **Se le deja entrar a media altura si le queda recta suficiente**, en vez de
## obligarle a subir hasta la puerta. Un avión que ya viene por el costado bueno
## y hacia popa no tiene por qué dar la vuelta entera: eso era media vuelta de
## reloj por aparato. Lo único que se le exige es venir en la línea, ir hacia
## popa, y tener sitio para asentarse antes de virar.
func can_join_downwind(world_pos: Vector2, facing: float, min_left: float) -> bool:
	var aqui := to_local(world_pos)
	var linea: float = _launch_point.position.x - pattern_offset
	if absf(aqui.x - linea) > 50.0:
		return false
	if pattern_turn_y() - aqui.y < min_left:
		return false
	var popa := bow_heading() + PI
	return absf(angle_difference(facing, popa)) <= deg_to_rad(45.0)


## A qué altura se deja el tramo paralelo y se vira a final.
func pattern_turn_y() -> float:
	return _recovery_ramp.position.y + pattern_turn_margin


## Donde acaba el viraje: sobre el eje y a la misma altura en que empezó, que es
## lo que da media vuelta de radio fijo.
func pattern_rollout() -> Vector2:
	return to_global(Vector2(_launch_point.position.x, pattern_turn_y()))


## ¿Está por el costado bueno y yendo hacia popa, o sea en el sitio por donde se
## entra al circuito?
##
## Es la puerta para dejar el circuito de espera. Sin ella, al que le tocaba el
## turno estando por el otro costado cruzaba el buque de través y se metía en el
## tramo paralelo de cualquier manera: de ahí no sale una aproximación derecha ni
## repitiendo la pasada tres veces.
func abeam_to_port(world_pos: Vector2, facing: float) -> bool:
	if to_local(world_pos).x > _launch_point.position.x - pattern_offset * 0.5:
		return false
	var popa := bow_heading() + PI
	return absf(angle_difference(facing, popa)) <= deg_to_rad(70.0)


## ¿Está ya dentro del circuito? Basta con estar del lado bueno y por delante de
## la altura de virar: **es una zona y no un punto**, porque un avión no llega a
## un punto, pasa cerca. Exigirle tocarlo hacía que uno que venía del otro
## costado lo fallara y entrara al tramo paralelo de cualquier manera.
func in_the_pattern(world_pos: Vector2) -> bool:
	var aqui := to_local(world_pos)
	if aqui.y > pattern_turn_y():
		return false
	return aqui.x <= _launch_point.position.x - pattern_offset * 0.5


## ¿Llegó ya a la altura de virar?
func past_turn_y(world_pos: Vector2) -> bool:
	var aqui := to_local(world_pos)
	if aqui.y < pattern_turn_y():
		return false
	# **Y sobre el tramo paralelo, no sólo a su altura.** El viraje sale bien
	# porque la separación es justo el doble del radio; empezándolo desde otra
	# separación, la media vuelta no acaba en el eje y la recta final se queda
	# corta. Si todavía no está en la línea, sigue bajando hasta cogerla.
	var linea: float = _launch_point.position.x - pattern_offset
	return absf(aqui.x - linea) <= 50.0


## Un punto del tramo paralelo por delante de quien pregunta, para seguirlo como
## se sigue el eje. Ver [method axis_lookahead].
func downwind_lookahead(from: Vector2, ahead: float, max_intercept_deg: float) -> Vector2:
	var aqui := to_local(from)
	var x: float = _launch_point.position.x - pattern_offset
	var desvio := absf(aqui.x - x)
	var pendiente := tan(deg_to_rad(clampf(max_intercept_deg, 5.0, 85.0)))
	var delante := maxf(ahead, desvio / pendiente)
	# El punto va siempre por delante, también pasada la altura de virar: si se
	# clava ahí, uno que llegue ancho se queda persiguiendo un punto que tiene
	# detrás en vez de meterse en la línea.
	return to_global(Vector2(x, minf(aqui.y + delante, pattern_turn_y() + 250.0)))


## El radio del circuito de espera de quien hace ese número en la cola. Siempre
## por fuera del circuito de aterrizaje, para no cruzarse con él.
func pattern_hold_radius(index: int) -> float:
	return pattern_offset + pattern_hold_step * float(maxi(index, 0) + 1)


## ¿Está encima de la línea de cubierta, dentro de ese margen?
func on_centreline(world_pos: Vector2, ancho: float) -> bool:
	return absf(to_local(world_pos).x - _launch_point.position.x) <= ancho


## El otro extremo de la misma línea, más allá de la proa.
##
## **Es un punto al que mirar, no un sitio al que ir.** Un avión persiguiendo un
## punto lejano sobre la línea se va poniendo encima de ella; persiguiendo el
## punto de toma se planta ahí con el ángulo que traiga, que es lo que hacía que
## entrase cruzado y a un costado.
func axis_point() -> Vector2:
	return to_global(_launch_point.position)


## ¿Ya cruzó la popa? Es la puerta de la entrada rodada, y es una **línea** y no
## un radio: cruzarla es estar sobre la cubierta, que es la condición de verdad.
func past_ramp(world_pos: Vector2) -> bool:
	return to_local(world_pos).y <= _recovery_ramp.position.y


## Dónde para el que llega rodando: **antes del ascensor, nunca pasado de él**.
##
## A medio camino entre la línea del ascensor y el punto de aterrizaje que tiene
## por detrás. Pararlo justo encima del ascensor obligaba a clavarlo al píxel, y
## lo que sobraba de frenada lo recuperaba yendo hacia atrás. Parándolo antes,
## ese resto se recorre rodando de frente, que es lo que hace un avión.
func rollout_point(slot: int) -> Vector2:
	var puerta := _gate_of(_stow_elevator_of(slot))
	var sitio: Vector2 = _takeoff_points[puerta].position
	var y := sitio.y
	if puerta > 0:
		y = (y + _takeoff_points[puerta - 1].position.y) * 0.5
	return to_global(Vector2(sitio.x, y))


func abeam_point(slot: int) -> Vector2:
	var spot: Vector2 = _takeoff_points[slot].position
	return to_global(Vector2(spot.x + abeam_offset, spot.y))


## La plaza en sí, en coordenadas del mundo.
func spot_point(slot: int) -> Vector2:
	return to_global(_takeoff_points[slot].position)


## Hacia donde apunta la proa, en el mundo. Es el rumbo al que se pone el que
## entra: paralelo al buque, no mirando a donde va.
func bow_heading() -> float:
	return (-global_transform.y).angle()


## Lo sube a bordo: deja de ser del mundo y pasa a ser carga del barco, colocado
## sobre su plaza. De aquí en adelante todo su recorrido va en coordenadas de
## cubierta, que es lo que compra sincronizar la marcha con la del buque.
##
## Es el espejo de [method _detach], con la misma trampa: para lo que escuchaba
## su muerte, entrar en este árbol no es morirse.
##
## Y aquí suelta el camino por el que vino —la subida por el costado y su carril,
## o el eje y las plazas que sobrevoló— quedándose sólo con la suya. Ya está
## abajo: lo que usó para llegar puede usarlo el siguiente.
func take_aboard(unit: Node2D, slot: int) -> void:
	if not is_instance_valid(unit) or slot < 0:
		return
	if unit.get_parent() != self:
		unit.reparent(self, true)
	var spot: Marker2D = _takeoff_points[slot]
	# El que baja en vertical se coloca sobre la marca: llega encima de ella y
	# cuadrarlo no se nota. **El que llega rodando se queda donde paró**, porque
	# para unos píxeles antes a propósito y colocarlo sería un salto; ese resto se
	# lo come el rodaje, que va de frente.
	if not _lands_along_deck(unit):
		unit.position = spot.position
	unit.rotation = spot.rotation
	_units[slot] = unit
	var id := unit.get_instance_id()
	_hold([_SPOT_SEG[slot]], id)
	# **Todo de una vez.** Cada suelta vuelve a repartir la cubierta, así que
	# soltando trozo a trozo el reparto ve media verdad y le da al siguiente lo
	# primero que quedó libre. Medido: el segundo Harrier cargado se llevaba la
	# plaza de popa, que es justo la que no sirve para llegar rodando.
	var sueltos: Array = [Seg.APPROACH, Seg.AXIS, _CROSS_SEG[slot]]
	for i in slot:
		sueltos.append(_SPOT_SEG[i])
	_release(sueltos, id)
## Lo lleva rodando a su ascensor y lo baja. Es el taxi de salida al revés, por
## el mismo camino y con el mismo punto intermedio.
##
## Va a una cola porque el ascensor es de uno en uno y ahora pueden posarse
## varios a la vez. Arranca cuando su ruta está libre; ver [method _process_stow].
##
## Al final se devuelve a la flota **sin rearmar**: con qué sale la próxima vez
## lo elige el jugador en el hangar, que es donde se elige el armamento.
func stow(unit: Node2D, slot: int) -> void:
	if not is_instance_valid(unit) or slot < 0:
		return
	var elev_idx := _stow_elevator_of(slot)
	_stow_queues[elev_idx].append({"unit": unit, "slot": slot})
	_refresh_mode()
	_process_stow(elev_idx)
## Baja al siguiente de los que esperan por ese ascensor, si ya se puede.
##
## La condición es la misma que para todo lo demás: que su ruta esté libre. De
## ahí sale solo lo que costaba escribir a mano — que el de la plaza de dentro
## espere a que se vaya el de fuera, porque tiene que rodarle por encima, y que
## nadie baje mientras otro corre la pista, porque los dos caminos de vuelta
## cruzan el mismo eje.
func _process_stow(elev_idx: int) -> void:
	# Igual que en la cola de salida: se busca al primero que pueda. El de la
	# plaza de dentro tiene que rodar por encima de la de fuera, así que mientras
	# la de fuera esté ocupada le toca esperar — y no puede parar por eso a quien
	# tiene delante, que a lo mejor es justo el que la va a dejar libre.
	var idx := -1
	var unit: Node2D = null
	for i in _stow_queues[elev_idx].size():
		var candidato: Dictionary = _stow_queues[elev_idx][i]
		var quien: Node2D = candidato["unit"]
		if not is_instance_valid(quien):
			idx = i
			break
		if _route_free(_taxi_route(candidato["slot"], elev_idx),
				quien.get_instance_id()):
			idx = i
			break
	if idx < 0:
		return
	var job: Dictionary = _stow_queues[elev_idx][idx]
	_stow_queues[elev_idx].remove_at(idx)
	unit = job["unit"]
	var slot: int = job["slot"]
	if not is_instance_valid(unit):
		_process_stow(elev_idx)
		return
	var unit_id := unit.get_instance_id()
	var route := _taxi_route(slot, elev_idx)
	_hold(route, unit_id)
	_movement_started()

	var elevator: Marker2D = _elevators[elev_idx]
	# Rueda por el eje hasta la altura del ascensor y cruza. Esa altura la da el
	# propio ascensor, no una tabla escrita a mano.
	var wp_idx := _gate_of(elev_idx)
	var puerta: Vector2 = _takeoff_points[wp_idx].position

	# En coordenadas de cubierta, igual que al salir: el aparato rueda **sobre**
	# el barco, así que si el barco avanza el aparato avanza con él.
	var tw := unit.create_tween()
	var desde: Vector2 = unit.position
	var rot: float = unit.rotation
	# Primero por el eje hasta la altura del ascensor, y después de través. Se
	# mira **dónde está de verdad** y no de qué plaza es: el que llegó rodando
	# para donde pudo, unos píxeles por detrás de su marca.
	if desde.distance_to(puerta) > 1.0:
		rot = _face_and_roll(tw, unit, desde, puerta, rot)
		desde = puerta
	_face_and_roll(tw, unit, desde, elevator.position, rot)

	tw.finished.connect(func() -> void:
		# Llega al ascensor mirando por donde vino, que es como se paró. Ponerle
		# aquí el rumbo del marcador lo haría girar en redondo: ese rumbo es el
		# de **salir**, y entrar es el camino al revés.
		_movement_ended()
		# Dejó la cubierta atrás: suelta su plaza y la de paso en el acto, sin
		# esperar a que baje la rampa. Ahí ya puede posarse otro.
		var libres: Array = [_SPOT_SEG[slot]]
		if wp_idx >= 0:
			libres.append(_SPOT_SEG[wp_idx])
		_units[slot] = null
		_release(libres, unit_id)
		# Baja por el ascensor. Hoy es sólo la espera: es el hueco donde entra la
		# animación de la rampa, igual que en la salida.
		get_tree().create_timer(elevator_cycle_time).timeout.connect(func() -> void:
			_handed.erase(unit_id)
			_standing.erase(unit_id)
			if _recovering.get(slot, 0) == unit_id:
				_recovering.erase(slot)
			if is_instance_valid(unit):
				if unit.has_method("return_to_fleet"):
					unit.return_to_fleet()
				unit.queue_free()
			_release_all(unit_id)
			_end_recovery()
		)
	)
func _face_and_roll(tw: Tween, unit: Node2D, desde: Vector2, hasta: Vector2,
		rot: float) -> float:
	var tramo := hasta - desde
	var largo := tramo.length()
	if largo < 0.5:
		return rot
	var giro := angle_difference(rot, tramo.angle() - PI * 0.5)
	if absf(giro) > 0.001:
		var vel := deg_to_rad(taxi_turn_speed_deg)
		tw.tween_property(unit, "rotation", rot + giro,
				absf(giro) / vel if vel > 0.0 else 0.01)
	tw.tween_property(unit, "position", hasta,
			largo / taxi_speed if taxi_speed > 0.0 else 0.01)
	return rot + giro


func _refresh_holds() -> void:
	for i in _inbound.size():
		var u := instance_from_id(_inbound[i]) as Node2D
		if u != null and is_instance_valid(u) and u.has_method("recovery_hold"):
			u.call("recovery_hold", i)

## Ya tuerce hacia su plaza: suelta la subida por el costado para que la use el
## siguiente. Es lo que hace que se entre de uno en uno por la línea y aun así se
## posen varios a la vez, cada cual en su carril.
func begin_cross_in(unit: Node2D) -> void:
	if not is_instance_valid(unit):
		return
	_release([Seg.APPROACH], unit.get_instance_id())

## A qué distancia del punto de espera aguarda el que hace ese número en la cola.
##
## Es **un solo número para los dos**: el helicóptero lo usa como distancia por
## popa y el avión como radio de su circuito, así que dos aparatos con puestos
## distintos nunca coinciden aunque esperen de formas distintas.
func holding_distance(index: int) -> float:
	return hold_radius + hold_spacing * float(maxi(index, 0))


## El punto donde aguarda el que hace ese número en la cola: sobre la línea de
## entrada y a su distancia por popa, uno detrás de otro. Se recalcula contra el
## buque como todo lo demás, así que la cola navega con él.
##
## La distancia se cuenta desde el buque y no desde el punto de entrada, para que
## sea la misma que usa el avión como radio de circuito. Contándola desde sitios
## distintos, un helicóptero y un avión con puestos distintos podrían acabar en
## el mismo trozo de mar.
func holding_point(index: int) -> Vector2:
	# `+Y` de la cubierta es popa, la misma convención que usa todo el arte.
	var lateral: float = _takeoff_points[0].position.x + abeam_offset
	return to_global(Vector2(lateral, holding_distance(index)))
