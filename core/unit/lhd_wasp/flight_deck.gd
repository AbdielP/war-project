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

	_taxi_queues[elev_idx].append({
		"scene": scene,
		"slot": slot,
		"spawn_pos": elevator.global_position,
		"spawn_rot": elevator.global_rotation,
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
## **Nadie pisa la pista hasta que el anterior ha despegado.** El taxi recorre
## el mismo eje (`x=-22`) que la carrera de despegue, así que sacar a uno
## mientras otro se lanza es meterlo en la pista. La cola espera; se reanuda al
## terminar la tanda, desde el mismo sitio que vuelve a mirar si hay que lanzar
## — ver [method _launch_next].
func _process_queue(elev_idx: int) -> void:
	if _launching:
		return
	if _taxiing[elev_idx] or _taxi_queues[elev_idx].is_empty():
		return
	var job: Dictionary = _taxi_queues[elev_idx].pop_front()

	_taxiing[elev_idx] = true

	var unit: Node2D = job["scene"].instantiate()
	get_tree().current_scene.add_child(unit)
	unit.global_position = job["spawn_pos"]
	unit.global_rotation = job["spawn_rot"]
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
	unit.tree_exited.connect(func() -> void:
		_occupied[slot] = false
		_units[slot] = null
	)
	_free_slot_when_airborne(slot, unit)

	get_tree().create_timer(elevator_cycle_time).timeout.connect(func() -> void:
		_taxiing[elev_idx] = false
		_process_queue(elev_idx)
	)

	var target: Marker2D = _takeoff_points[slot]
	var waypoint_idx: int = _SLOT_WAYPOINTS[slot]

	var tw := unit.create_tween()

	if waypoint_idx >= 0:
		var wp: Marker2D = _takeoff_points[waypoint_idx]
		var d1 := unit.global_position.distance_to(wp.global_position)
		tw.tween_property(unit, "global_position", wp.global_position,
				d1 / taxi_speed if taxi_speed > 0.0 else 0.01)
		tw.tween_callback(func() -> void: unit.global_rotation = wp.global_rotation)
		var d2 := wp.global_position.distance_to(target.global_position)
		tw.tween_property(unit, "global_position", target.global_position,
				d2 / taxi_speed if taxi_speed > 0.0 else 0.01)
	else:
		var d := unit.global_position.distance_to(target.global_position)
		tw.tween_property(unit, "global_position", target.global_position,
				d / taxi_speed if taxi_speed > 0.0 else 0.01)

	tw.finished.connect(func() -> void:
		unit.global_rotation = target.global_rotation
		_units[slot] = unit
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
	# Y que haya alguien a quien soltar. Sin esto, la repregunta del final de la
	# tanda se contestaría a sí misma con la cubierta vacía y montaría una
	# secuencia cada `launch_delay` para siempre.
	var hay_alguien := false
	for unidad in _units:
		if is_instance_valid(unidad):
			hay_alguien = true
			break
	if not hay_alguien:
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
		# cuando su piloto quiera y no cuando el barco diga.
		#
		# Y hasta que se despegue **sigue en medio de la pista**, así que la
		# tanda espera. Se engancha ANTES de cederle el control: si traía orden
		# de cubierta, la subida arranca dentro de `_hand_over_control` y la
		# señal saldría sin nadie escuchando.
		var seguir := _seguir_una_vez(unit, order)
		if unit.has_signal("took_off"):
			unit.took_off.connect(seguir, CONNECT_ONE_SHOT)
			_hand_over_control(unit)
		else:
			_hand_over_control(unit)
			seguir.call()
		return

	_units[slot] = null
	_occupied[slot] = false

	var launch_speed := _launch_speed_of(unit)
	var runway_dist: float = unit.global_position.distance_to(_launch_point.global_position)
	# Arranca parado y acelera. Con un ease-in cuadrático, recorrer `runway_dist`
	# en este tiempo deja al avión yendo exactamente a `launch_speed` al llegar
	# a la proa: el factor 2 es la media de una aceleración constante, no un
	# número puesto a ojo. De ahí en adelante ya vuela a esa velocidad, que es
	# la misma con la que el piloto recoge el control.
	var runway_dur: float = 2.0 * runway_dist / launch_speed
	var post_duration: float = post_bow_distance / launch_speed

	var tw := unit.create_tween()
	tw.tween_property(unit, "global_position", _launch_point.global_position, runway_dur) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	var seguir := _seguir_una_vez(unit, order)
	tw.finished.connect(func() -> void:
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
## Se acepta que un helicóptero sin orden **pare la cola**: sigue en medio de la
## pista y la cubierta está ocupada de verdad. En cuanto el jugador le dice a
## dónde ir, la tanda continúa sola.
func _seguir_una_vez(unit: Node2D, order: Array) -> Callable:
	var hecho := [false]
	var seguir := func() -> void:
		if hecho[0]:
			return
		hecho[0] = true
		_launch_next(order)
	if is_instance_valid(unit):
		unit.tree_exited.connect(seguir, CONNECT_ONE_SHOT)
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
	, CONNECT_ONE_SHOT)


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
