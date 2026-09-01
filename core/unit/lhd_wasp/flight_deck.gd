extends Node2D

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

var _occupied: Array[bool] = [false, false, false, false]
var _units: Array        = [null, null, null, null]
var _elevator_idx := 0
var _taxi_queues: Array  = [[], []]
var _taxiing: Array[bool] = [false, false]
var _launching := false

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


func request_deploy(scene: PackedScene, squad: Squad = null,
		weapon_loadout: WeaponLoadout = null,
		standing_order: Dictionary = {}) -> bool:
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
		_process_queue(elev_idx)
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
		_check_ready_to_launch()
	)


## ¿Está la cubierta lista para soltar la tanda?
##
## De las tres puertas de salida, **dos se vuelven a abrir solas** —el que sigue
## rodando llamará aquí al aparcar— y la de `_launching` no: mientras se suelta
## una tanda no hay nadie esperando a que termine. Por eso el final de la tanda
## vuelve a preguntar; ver [method _launch_next].
func _check_ready_to_launch() -> void:
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
		for i in _taxi_queues.size():
			_process_queue(i)
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
