extends Node2D
class_name FlightDeck

## La cubierta de vuelo: saca aparatos y los recoge. Nunca las dos cosas a la vez.
##
## **Lanzar y recuperar se turnan**, y lo que se turna es el aparato en curso y
## no la cola entera: el que corre la pista termina su carrera, la recuperación
## toma la cubierta, y la cola sigue después donde estaba. Manda el que está en
## el aire, porque a él se le acaba el combustible y al de cubierta no.
##
## **Se sale por proa y se entra por popa** (`-Y` y `+Y` en coordenadas de la
## cubierta), así que los dos flujos no se cruzan ni en el aire. Es lo que hace
## que turnarse baste y no haga falta más arbitraje.
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

## El grupo al que se apunta todo lo que vuela. Es lo único que puede estar
## encima de la cubierta, así que es lo único que hay que mirar.
const _AIR_GROUP := &"unit_air"

# Elevator1 → TP2 primero, luego TP1. Elevator2 → TP4 primero, luego TP3.
const _ELEVATOR_SLOTS: Array = [[1, 0], [3, 2]]
# Waypoint intermedio por slot: TP2 pasa por TP1, TP4 pasa por TP3. -1 = directo.
const _SLOT_WAYPOINTS: Array = [-1, 0, -1, 2]

@onready var _elevators: Array[Marker2D] = [$Elevator1, $Elevator2]
@onready var _takeoff_points: Array[Marker2D] = [
	$TakeoffPoint1, $TakeoffPoint2, $TakeoffPoint3, $TakeoffPoint4
]
@onready var _launch_point: Marker2D = $LaunchPoint
## Por donde se entra: por detrás del buque. El que llega y no cabe espera aquí,
## y el que sí cabe arranca desde aquí su arrimada.
@onready var _recovery_join: Marker2D = $RecoveryJoin

var _occupied: Array[bool] = [false, false, false, false]
var _units: Array        = [null, null, null, null]
var _elevator_idx := 0
var _taxi_queues: Array  = [[], []]
var _taxiing: Array[bool] = [false, false]
var _launching := false

## A quién se le ha concedido la cubierta para entrar, por id de instancia, o 0.
##
## **Es el compromiso, y por eso es un id y no un `bool`**: hay que poder decir
## si el que viene a preguntar es el mismo al que se le concedió. Mientras valga
## algo, el lado del despegue está cerrado.
var _recovering: int = 0
## La plaza que se le guardó a ése.
var _recovery_slot: int = -1
## Los que pidieron entrar y esperan turno, por id y en orden de llegada.
##
## Un portero que dice "ahora no" tiene que decir también "ya puedes": sin esta
## lista la petición se pierde y no hay error que lo delate, sólo un aparato
## dando vueltas para siempre.
var _inbound: Array[int] = []
## La tanda que se quedó a medias al conceder una entrada. Se retoma al terminar
## la recuperación, y por eso se guarda: la lista de a quién soltar se hizo al
## empezar y no se puede reconstruir.
var _deferred: Array = []
var _mode: Mode = Mode.IDLE
## Hay una tanda a medias esperando a que termine la entrada. Va aparte de
## [member _deferred] porque **la lista puede estar vacía y aun así haber tanda
## que cerrar**: es la misma trampa de siempre, un `bool` que dura una cosa no
## puede contestar por otra.
var _batch_deferred := false

## Hay un aparato **corriendo por la pista** ahora mismo. No es lo mismo que
## [member _launching], y confundirlos era el problema: una tanda dura lo que
## tarde el jugador en sacar de cubierta a un helicóptero posado —puede ser
## nunca—, mientras que una carrera dura los pocos segundos que se tarda en
## rebasar la proa y termina siempre.
##
## Lo que hay que proteger es la franja de pista mientras alguien la recorre, no
## la cubierta entera mientras haya una tanda abierta. Con lo segundo, un solo
## helicóptero esperando órdenes dejaba el ascensor parado: se pedía un aparato,
## se descontaba de la flota, se reservaba su plaza y **no llegaba a existir**.
var _runway_busy := false

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
	var elev_idx: int = _elevator_idx % _elevators.size()
	var slot := _next_slot_for_elevator(elev_idx)
	if slot == -1:
		return false

	var elevator: Marker2D = _elevators[elev_idx]
	_elevator_idx += 1
	_occupied[slot] = true

	# En coordenadas de la cubierta, no del mundo. Entre pedir el aparato y
	# sacarlo hay una cola, y para entonces el barco ya no está donde estaba.
	_taxi_queues[elev_idx].append({
		"scene": scene,
		"slot": slot,
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
	for i in _occupied.size():
		if not _occupied[i]:
			return true
	return false


## Saca al siguiente de la cola de ese ascensor y lo lleva rodando a su punto.
##
## **Nadie rueda mientras otro corre por la pista.** El taxi acaba metiéndose en
## el mismo eje (`x=-22`) que la carrera de despegue, así que sacar a uno
## mientras otro se lanza es ponerlo delante — medido: con la cola libre durante
## la carrera, el Harrier alcanzaba al que rodaba hacia `y=-17`.
##
## Lo que cierra la puerta es la carrera y no la tanda. Ver [member _runway_busy].
## La cola se reanuda en cuanto la pista queda libre, desde [method _seguir_una_vez].
func _process_queue(elev_idx: int) -> void:
	# Con una entrada concedida no rueda nadie. El que viene cruza la cubierta de
	# costado para posarse, y el taxi la cruza en el otro sentido.
	if _recovering != 0:
		return
	if _runway_busy:
		return
	if _taxiing[elev_idx] or _taxi_queues[elev_idx].is_empty():
		return
	var job: Dictionary = _taxi_queues[elev_idx].pop_front()

	_taxiing[elev_idx] = true

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
	var slot: int = job["slot"]
	var order: Dictionary = job.get("order", {})
	if not order.is_empty():
		_standing[unit.get_instance_id()] = order
	var u := unit as Unit
	if u != null:
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
	var unit_id := unit.get_instance_id()
	if u != null:
		u.died.connect(func(_unit: Unit) -> void:
			_occupied[slot] = false
			_units[slot] = null
			_handed.erase(unit_id)
			_standing.erase(unit_id)
		)
	_free_slot_when_airborne(slot, unit)

	get_tree().create_timer(elevator_cycle_time).timeout.connect(func() -> void:
		_taxiing[elev_idx] = false
		_offer_recovery()
		_process_queue(elev_idx)
		_refresh_mode()
	)

	var target: Marker2D = _takeoff_points[slot]
	var waypoint_idx: int = _SLOT_WAYPOINTS[slot]

	var tw := unit.create_tween()

	# Todo el rodaje va en `position` —coordenadas de la cubierta— y no en
	# `global_position`. Un tween apunta a un valor fijo capturado al empezar: en
	# mundo, ese valor deja de ser el punto de despegue en cuanto el barco avanza,
	# y el aparato rueda hacia donde la cubierta estaba. En local el punto no se
	# mueve nunca, porque está pintado en la propia cubierta.
	if waypoint_idx >= 0:
		var wp: Marker2D = _takeoff_points[waypoint_idx]
		var d1 := unit.position.distance_to(wp.position)
		tw.tween_property(unit, "position", wp.position,
				d1 / taxi_speed if taxi_speed > 0.0 else 0.01)
		tw.tween_callback(func() -> void: unit.rotation = wp.rotation)
		var d2 := wp.position.distance_to(target.position)
		tw.tween_property(unit, "position", target.position,
				d2 / taxi_speed if taxi_speed > 0.0 else 0.01)
	else:
		var d := unit.position.distance_to(target.position)
		tw.tween_property(unit, "position", target.position,
				d / taxi_speed if taxi_speed > 0.0 else 0.01)

	tw.finished.connect(func() -> void:
		unit.rotation = target.rotation
		_units[slot] = unit
		# Lo que no usa pista ya está donde tiene que estar: aparcar **es** su
		# despegue terminado, y el control es suyo desde este momento. Esperar a
		# que le llegue el turno de la tanda lo dejaba posado y sordo a las
		# órdenes mientras otro corría por la pista — y como el que ordena
		# sacarlo es el jugador, sin control no había forma de desatascarlo.
		#
		# Sigue ocupando su plaza y sigue parando a los aviones que tenga detrás:
		# eso no cambia, porque es verdad.
		if _launch_speed_of(unit) <= 1.0:
			_hand_over_control(unit)
		# Otra costura: acaba de dejar de rodar, así que si alguien espera entrar
		# éste es su turno.
		_offer_recovery()
		_check_ready_to_launch()
		_refresh_mode()
	)


## ¿Está la cubierta lista para soltar la tanda?
##
## De las tres puertas de salida, **dos se vuelven a abrir solas** —el que sigue
## rodando llamará aquí al aparcar— y la de `_launching` no: mientras se suelta
## una tanda no hay nadie esperando a que termine. Por eso el final de la tanda
## vuelve a preguntar; ver [method _launch_next].
func _check_ready_to_launch() -> void:
	if _recovering != 0:
		return
	if _launching:
		return
	if not _taxi_queues[0].is_empty() or not _taxi_queues[1].is_empty():
		return
	for i in _occupied.size():
		if _occupied[i] and _units[i] == null:
			return
	# Y que haya alguien a quien **de verdad** se pueda soltar. Sin esto, la
	# repregunta del final de la tanda se contestaría a sí misma y montaría una
	# secuencia cada `launch_delay` para siempre: con la cubierta vacía, y —peor—
	# con un avión esperando detrás de un helicóptero aparcado, que no puede
	# salir por mucho que se le pregunte.
	#
	# No cuenta el que ya tiene el control: o está corriendo, o está posado
	# esperando órdenes del jugador, y en los dos casos la cubierta ya hizo lo
	# suyo con él.
	var hay_quien_pueda := false
	var estorbo_en_el_aire := false
	for i in _units.size():
		var unidad: Node2D = _units[i]
		if not is_instance_valid(unidad) or _handed.has(unidad.get_instance_id()):
			continue
		if _launch_speed_of(unidad) <= 1.0:
			hay_quien_pueda = true
			break
		var estorbo := _runway_blocker_from(i)
		if estorbo == null:
			hay_quien_pueda = true
			break
		if not _units.has(estorbo):
			estorbo_en_el_aire = true
	if not hay_quien_pueda:
		# Si lo que estorba está posado en una plaza, ya avisará al irse con su
		# `took_off`. Si está **volando** por encima de la pista no es de la
		# cubierta y no tiene por qué decirle nada a nadie: hay que volver a
		# mirar por cuenta propia.
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
	# Se concedió una entrada mientras la tanda estaba en marcha. La tanda no se
	# cancela —sigue abierta— pero no suelta a nadie más hasta que el que viene
	# esté abajo. Se guarda por dónde iba: la lista se hizo al empezar y no hay
	# forma de reconstruirla después.
	if _recovering != 0:
		_deferred = order
		_batch_deferred = true
		return
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

	# Nadie corre con otro aparcado delante. El que está posado no se aparta —no
	# tiene por qué, está en su plaza—, así que el que se iba a lanzar se queda
	# también, y saldrá cuando el de delante deje sitio: quien avisa es el
	# `took_off` del que se va, en [method _free_slot_when_airborne]; y si lo que
	# estorba está volando, la segunda mirada de [method _retry_later].
	if _runway_blocker_from(slot) != null:
		_launch_next(order)
		return

	_units[slot] = null
	_occupied[slot] = false

	var launch_speed := _launch_speed_of(unit)
	var runway_dist: float = unit.position.distance_to(_launch_point.position)
	# Arranca parado y acelera. Con un ease-in cuadrático, recorrer `runway_dist`
	# en este tiempo deja al avión yendo exactamente a `launch_speed` al llegar
	# a la proa: el factor 2 es la media de una aceleración constante, no un
	# número puesto a ojo. De ahí en adelante ya vuela a esa velocidad, que es
	# la misma con la que el piloto recoge el control.
	var runway_dur: float = 2.0 * runway_dist / launch_speed
	var post_duration: float = post_bow_distance / launch_speed

	# Desde aquí y hasta rebasar la proa, la pista es suya y nadie más rueda.
	_runway_busy = true

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
## Un despegue por vez: hasta que el aparato no ha dejado la pista, el que
## viene detrás no arranca. Los cuatro puntos de despegue y el de proa están en
## la misma línea (`x=-22`), así que el que corre le pasa por encima al que
## sigue posado — medido: el Harrier cruzaba `y=-17` con el Cobra parado ahí.
##
## Va guardada porque a la continuación se llega por dos sitios —se fue, o se
## murió por el camino— y llamar dos veces se saltaría un aparato de la lista.
##
## Sólo la usa la carrera de pista. Lo que despega en vertical no espera a nadie
## ni hace esperar a la tanda: se le cede el control al aparcar y ahí se queda.
func _seguir_una_vez(unit: Node2D, order: Array) -> Callable:
	var hecho := [false]
	var seguir := func() -> void:
		if hecho[0]:
			return
		hecho[0] = true
		# La pista queda libre aquí —se rebasó la proa, o el que corría se murió
		# por el camino—, así que éste es el sitio donde se deja rodar otra vez.
		# Antes de seguir con la tanda: uno que empieza a rodar es motivo para
		# **no** lanzar todavía, y quien lo comprueba es el final de la tanda.
		_runway_busy = false
		# La pista queda libre justo aquí, así que es la primera costura donde se
		# puede ceder el turno al que espera entrar. Va **antes** que la cola y
		# que la tanda: manda el que está en el aire.
		_offer_recovery()
		if _recovering != 0:
			_deferred = order
			_batch_deferred = true
			_refresh_mode()
			return
		for i in _taxi_queues.size():
			_process_queue(i)
		_launch_next(order)
		_refresh_mode()
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
func _free_slot_when_airborne(slot: int, unit: Node2D) -> void:
	if not unit.has_signal("took_off"):
		return
	unit.took_off.connect(func() -> void:
		_occupied[slot] = false
		_units[slot] = null
		# Se despegó del suelo: ya no es carga del barco. Se suelta al mundo aquí
		# y no al cederle el control, porque entre una cosa y la otra puede
		# pasarse la partida entera posado en cubierta, y ahí sí viaja con él.
		_detach(unit)
		# Y con él se va el estorbo: si había un avión esperando a que la pista
		# quedara despejada, éste es el aviso de que ya puede salir.
		_check_ready_to_launch()
	, CONNECT_ONE_SHOT)


## Suelta el aparato al mundo: deja de ser carga del barco y a partir de aquí
## mover el buque ya no lo mueve a él. Conserva la posición y el rumbo que
## tuviera, así que el relevo no se ve.
##
## El destino es el padre del buque y no `current_scene`: la misión puede estar
## metida dentro de la carcasa de pantallas, y entonces la escena actual es el
## envoltorio y no el mundo.
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


func _next_slot_for_elevator(elev_idx: int) -> int:
	var priority: Array = _ELEVATOR_SLOTS[elev_idx % _ELEVATOR_SLOTS.size()]
	for slot in priority:
		if not _occupied[slot]:
			return slot
	return -1


## Lo que la cubierta está haciendo, para contarlo.
##
## **No es la misma pregunta que [method _busy_on_deck]**, y juntarlas sería
## repetir el fallo que ya costó una vez: aquí interesa la tanda entera —que
## puede durar lo que el jugador tarde en mover un helicóptero posado—, y allí
## sólo si hay algo moviéndose ahora mismo. Un rótulo que parpadeara entre cada
## aparato de la misma tanda contaría una cosa que no está pasando.
func mode() -> Mode:
	if _recovering != 0:
		return Mode.RECOVERING
	if _launching or _busy_on_deck():
		return Mode.LAUNCHING
	for cola in _taxi_queues:
		if not cola.is_empty():
			return Mode.LAUNCHING
	return Mode.IDLE


## Hay algo moviéndose por la cubierta **ahora mismo**: alguien corriendo la
## pista o alguien rodando. Es lo que decide si se puede ceder el turno, y por
## eso no mira `_launching`: una tanda abierta con todo el mundo quieto no
## estorba a nadie que quiera entrar.
func _busy_on_deck() -> bool:
	if _runway_busy:
		return true
	for rodando in _taxiing:
		if rodando:
			return true
	return false


func _refresh_mode() -> void:
	var ahora := mode()
	if ahora == _mode:
		return
	_mode = ahora
	mode_changed.emit(ahora)


## Pide entrar. Devuelve la plaza concedida, o −1 si toca esperar.
##
## Esperar **no es que le hayan dicho que no**: queda apuntado y se le avisa por
## `recovery_granted` en cuanto la cubierta se libere. Sin esa lista la petición
## se perdería sin un solo error que lo delatara, y el síntoma sería el peor de
## todos: funciona sólo cuando vuelvo a pedirlo.
func request_recovery(unit: Node2D) -> int:
	if not is_instance_valid(unit):
		return -1
	var id := unit.get_instance_id()
	if _recovering == id:
		return _recovery_slot
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
	_refresh_mode()
	return _recovery_slot if _recovering == id else -1


## Se retira: el jugador lo mandó a otro sitio, o se murió por el camino.
##
## **La plaza se suelta aquí y no en ningún otro sitio.** Un aparato al que se
## desvía a mitad de vuelta deja su reserva puesta, y la cubierta se va llenando
## de plazas fantasma que no ocupa nadie.
func cancel_recovery(id: int) -> void:
	_inbound.erase(id)
	if _recovering != id:
		_refresh_mode()
		return
	var slot := _recovery_slot
	_recovering = 0
	_recovery_slot = -1
	if slot >= 0 and _units[slot] == null:
		_occupied[slot] = false
	_end_recovery()


## Le concede la cubierta al primero de la cola que siga vivo, si se puede.
func _offer_recovery() -> void:
	if _recovering != 0 or _inbound.is_empty() or _busy_on_deck():
		return
	while not _inbound.is_empty():
		var id: int = _inbound[0]
		var unit := instance_from_id(id) as Node2D
		if not is_instance_valid(unit):
			_inbound.pop_front()
			continue
		var slot := _free_slot_for_recovery()
		if slot == -1:
			return
		_inbound.pop_front()
		_recovering = id
		_recovery_slot = slot
		# La reserva cubre la secuencia entera y no sólo el punto de toma. Ver la
		# cabecera: negarle el ascensor a uno que ya está posado no es una
		# respuesta, es un atasco.
		_occupied[slot] = true
		_units[slot] = null
		if unit.has_method("recovery_granted"):
			unit.recovery_granted(slot)
		return


## La plaza más a popa de las libres. Se prefiere la de atrás para que el que
## entra no tenga que sobrevolar la cubierta entera hasta la proa.
func _free_slot_for_recovery() -> int:
	for slot in _occupied.size():
		if not _occupied[slot]:
			return slot
	return -1


## Terminó una entrada: se ofrece la cubierta al siguiente y, si no hay nadie,
## se reabre el lado del despegue.
##
## Es la otra mitad del portero. Cerrar la puerta sin abrirla después deja la
## cubierta muda: la tanda sigue marcada como abierta y nadie vuelve a preguntar.
func _end_recovery() -> void:
	_offer_recovery()
	if _recovering != 0:
		_refresh_mode()
		return
	if _batch_deferred:
		_batch_deferred = false
		var order: Array = _deferred
		_deferred = []
		_launch_next(order)
	else:
		for i in _taxi_queues.size():
			_process_queue(i)
		_check_ready_to_launch()
	_refresh_mode()


## Por donde se entra: por detrás del buque, en coordenadas del mundo.
##
## Es también donde espera el que todavía no tiene plaza. Que sean el mismo punto
## no es ahorro: el que espera ya está colocado para arrancar la arrimada en
## cuanto le den paso.
func join_point() -> Vector2:
	return to_global(Vector2(
			_takeoff_points[0].position.x + abeam_offset,
			_recovery_join.position.y))


## El punto de arrimada de esa plaza: a su altura pero al costado y fuera del
## buque. En coordenadas del mundo.
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


## Ya está encima de su plaza y quieto respecto al barco: **deja de volar y pasa
## a ser carga**. De aquí en adelante todo se mide en coordenadas de cubierta,
## que es justo lo que compra sincronizar la marcha con la del buque.
##
## Es el espejo de [method _detach], con la misma trampa: para lo que escuchaba
## su muerte, entrar en este árbol no es morirse.
func take_aboard(unit: Node2D, slot: int) -> void:
	if not is_instance_valid(unit) or slot < 0:
		return
	if unit.get_parent() != self:
		unit.reparent(self, true)
	var spot: Marker2D = _takeoff_points[slot]
	unit.position = spot.position
	unit.rotation = spot.rotation
	_units[slot] = unit


## Lo lleva rodando a su ascensor y lo baja. Es el taxi de salida al revés, por
## el mismo camino y con el mismo punto intermedio.
##
## Al final se devuelve a la flota **sin rearmar**: con qué sale la próxima vez
## lo elige el jugador en el hangar, que es donde se elige el armamento.
func stow(unit: Node2D, slot: int) -> void:
	if not is_instance_valid(unit) or slot < 0:
		return
	var elev_idx := _elevator_of(slot)
	_taxiing[elev_idx] = true
	_refresh_mode()
	var elevator: Marker2D = _elevators[elev_idx]
	var wp_idx: int = _SLOT_WAYPOINTS[slot]

	# En coordenadas de cubierta, igual que la salida: el aparato rueda **sobre**
	# el barco, así que si el barco avanza el aparato avanza con él.
	var tw := unit.create_tween()
	var desde: Vector2 = unit.position
	if wp_idx >= 0:
		var wp: Marker2D = _takeoff_points[wp_idx]
		var d1 := desde.distance_to(wp.position)
		tw.tween_property(unit, "position", wp.position,
				d1 / taxi_speed if taxi_speed > 0.0 else 0.01)
		tw.tween_callback(func() -> void: unit.rotation = wp.rotation)
		desde = wp.position
	var d2 := desde.distance_to(elevator.position)
	tw.tween_property(unit, "position", elevator.position,
			d2 / taxi_speed if taxi_speed > 0.0 else 0.01)

	var unit_id := unit.get_instance_id()
	tw.finished.connect(func() -> void:
		if is_instance_valid(unit):
			unit.rotation = elevator.rotation
		# Baja por el ascensor. Hoy es sólo la espera: es el hueco donde entra la
		# animación de la rampa, igual que en la salida.
		get_tree().create_timer(elevator_cycle_time).timeout.connect(func() -> void:
			_taxiing[elev_idx] = false
			_occupied[slot] = false
			_units[slot] = null
			_handed.erase(unit_id)
			_standing.erase(unit_id)
			if _recovering == unit_id:
				_recovering = 0
				_recovery_slot = -1
			if is_instance_valid(unit):
				if unit.has_method("return_to_fleet"):
					unit.return_to_fleet()
				unit.queue_free()
			_end_recovery()
		)
	)


## A qué ascensor pertenece una plaza. Sale de la misma tabla que reparte las
## plazas al salir, y por eso el taxi de vuelta recorre el camino de ida.
func _elevator_of(slot: int) -> int:
	for elev_idx in _ELEVATOR_SLOTS.size():
		if _ELEVATOR_SLOTS[elev_idx].has(slot):
			return elev_idx
	return 0
