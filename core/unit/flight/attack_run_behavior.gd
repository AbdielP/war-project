extends Node
class_name AttackRunBehavior

## Decide A DÓNDE va el avión cuando ataca a alguien. Sustituye al viejo
## "perseguir": un avión armado NO se pega al blanco. Hace pasadas.
##
## Quien manda aquí es el ARMA, no el avión. Cada una tiene una envolvente de
## tiro — una distancia mínima y una máxima — y el vuelo se organiza alrededor
## de ella:
##
##   INGRESS  encara el blanco y aguanta hasta que está a punto de meterse por
##            debajo del alcance mínimo.
##   EGRESS   rompe, se aleja en línea recta y vuelve a encarar cuando está de
##            nuevo cerca del alcance máximo.
##
## Eso es lo que conserva la ventaja de un arma de largo alcance: con un misil
## de 1000 px el avión dispara a 1000 y se va, en vez de meterse encima de un
## blanco que puede defenderse. Y romper después de cada disparo es lo que le
## da sitio para recargar y tirar otra vez.
##
## Hermano de `OrbitBehavior` — los dos le dan puntos al mismo piloto, así que
## nunca deben correr a la vez. Quien reciba la orden decide cuál manda.
##
## No dispara ni sabe de armas: recibe la envolvente ya resuelta.

## El objetivo dejó de existir. Quien escuche decide qué hacer con el avión;
## aquí ya se apagó solo.
signal target_lost

enum Phase { INGRESS, EGRESS }

@export_group("Ataque")
## Margen sobre el alcance mínimo del arma al que rompe el ataque. 1.2 = corta
## un 20% antes de quedarse corto, para no entrar en la zona donde el arma ya
## no sirve mientras completa el viraje.
@export var break_off_margin: float = 1.2
## Fracción del alcance máximo a la que vuelve a encarar. Por debajo de 1.0
## para que llegue a la nueva pasada ya dentro de la envolvente y no tenga que
## acercarse otro tanto.
@export_range(0.3, 1.0, 0.05) var reengage_fraction: float = 0.85
## Cuánto tiene que separarse como mínimo al romper, en proporción a la
## distancia a la que rompió. Sin esto, romper justo en el borde del alcance
## no serviría de nada: la condición de volver a encarar ya estaría cumplida
## en el mismo frame y el avión seguiría metiéndose como si nada.
@export var separation_gain: float = 1.15
## Cuánto más allá del punto de reencare apunta al alejarse. El destino de la
## fuga se fija al romper y no se recalcula: así se aleja recto en vez de ir
## girando mientras el blanco se mueve.
@export var egress_overshoot: float = 1.3
## Separación mínima antes de volver a encarar, en radios de giro del avión.
## Es el sitio que necesita para invertir el rumbo y llegar a la pasada
## siguiente ya alineado, en vez de entrar torcido. Por debajo de 2 no le da ni
## para el semicírculo.
@export var turn_around_margin: float = 3.0

@export_group("Enlace")
@export var pilot_path: NodePath = ^"../PlaneController"

var target: Unit = null

var _pilot: PlaneController
var _body: Node2D
var _min_range: float = 0.0
var _max_range: float = 0.0
var _phase: Phase = Phase.INGRESS
var _egress_point: Vector2 = Vector2.ZERO
## Distancia a la que termina la separación actual. Se fija al romper porque
## depende de dónde se rompió, no sólo del alcance del arma.
var _reengage_at: float = 0.0


func _ready() -> void:
	_body = get_parent() as Node2D
	_pilot = get_node_or_null(pilot_path) as PlaneController
	set_process(false)


## Ataca a esa unidad respetando la envolvente del arma. `max_range` a 0 = arma
## sin alcance conocido: se comporta como el viejo perseguir, yendo derecho.
func engage(new_target: Unit, min_range: float, max_range: float) -> void:
	if _pilot == null or not is_instance_valid(new_target):
		return
	target = new_target
	set_envelope(min_range, max_range)
	_start_ingress()
	set_process(true)


## El jugador cambió de arma en pleno ataque: la envolvente es otra y el vuelo
## tiene que ajustarse sin soltar el blanco.
func set_envelope(min_range: float, max_range: float) -> void:
	_min_range = maxf(0.0, min_range)
	_max_range = maxf(0.0, max_range)


## Ya disparó: romper y separarse. Es lo que evita que el avión siga metiéndose
## hacia un blanco al que ya le mandó un arma en camino.
func break_off() -> void:
	if _phase == Phase.INGRESS and is_processing():
		_start_egress()


func stop() -> void:
	target = null
	set_process(false)
	if _pilot != null:
		# Suelta el gas al soltar el mando: si quien coja el avión ahora quiere
		# que corra, ya lo pedirá. Dejarlo acelerado sería dejar puesta una
		# orden que ya no existe.
		_pilot.set_cruising(false)


func _process(_delta: float) -> void:
	if not is_instance_valid(target):
		# Se apaga antes de avisar: quien escuche puede darle otra orden al
		# avión sin que este nodo se la pise en el frame siguiente.
		target = null
		set_process(false)
		_pilot.set_cruising(false)
		target_lost.emit()
		return

	var distance := _body.global_position.distance_to(target.global_position)
	match _phase:
		Phase.INGRESS:
			# Corrige el punto sin replantear el viraje ya comprometido.
			_pilot.update_target(target.global_position)
			if distance <= _break_off_distance():
				_start_egress()
		Phase.EGRESS:
			if distance >= _reengage_at:
				_start_ingress()

	_set_throttle(distance)


func _start_ingress() -> void:
	_phase = Phase.INGRESS
	# `set_target` y no `update_target`: es un destino nuevo, y el avión tiene
	# que replantear hacia qué lado vira desde cero.
	_pilot.set_target(target.global_position)


func _start_egress() -> void:
	_phase = Phase.EGRESS
	# Romper cerca del alcance mínimo y romper en el borde del máximo son la
	# misma maniobra, pero desde sitios muy distintos: en el primer caso basta
	# con recuperar la distancia de tiro, en el segundo hay que separarse de
	# donde ya se está o la ruptura sería instantánea.
	var distance := _body.global_position.distance_to(target.global_position)
	_reengage_at = maxf(_reengage_distance(), distance * separation_gain)

	var away := (_body.global_position - target.global_position)
	if away.length() < 1.0:
		# Justo encima del blanco: la dirección de huida es indefinida, así que
		# sale por donde ya iba mirando.
		away = Vector2.RIGHT.rotated(_pilot.heading)
	# El punto de fuga va más allá de donde va a reencarar: así el avión
	# siempre tiene destino al que volar cuando llega el momento de virar, en
	# vez de quedarse sin rumbo a mitad de la separación.
	_egress_point = target.global_position \
		+ away.normalized() * (_reengage_at * egress_overshoot)
	_pilot.set_target(_egress_point)


## Gas sí o no. Sólo se vuela despacio en un sitio: metiéndose hacia el blanco
## y ya dentro del alcance del arma, que es cuando hay que alinearse para tirar
## y cada segundo de más en parámetros es otra ocasión de disparar.
##
## Fuera de eso, gas: acercarse hasta la envolvente cuanto antes, y romper
## cuanto antes una vez soltada el arma. No hay ninguna velocidad "de ataque"
## que ajustar — es la mínima del propio avión, que él ya se sabe.
func _set_throttle(distance: float) -> void:
	var lining_up := _phase == Phase.INGRESS \
		and _max_range > 0.0 and distance <= _max_range
	_pilot.set_cruising(not lining_up)


## Distancia a la que corta la pasada. Sin alcance mínimo no hay nada de lo que
## alejarse y el avión entra hasta el final, como hacía antes.
func _break_off_distance() -> float:
	return _min_range * break_off_margin


## A qué distancia vuelve a encarar. Sale del alcance del arma, pero con un
## suelo: **hay que separarse lo bastante para poder darse la vuelta**.
##
## Sin ese suelo, un arma de corto alcance deja al avión atrapado. El cañón tira
## entre 150 y 350 px: rompe a 180, vuelve a encarar a 297 y sólo tiene 117 px
## para invertir el rumbo — con un radio de giro de 130 no le da, así que llega
## a la pasada siguiente ya torcido y rozando el blanco en vez de ametrallarlo.
## Se ve clarísimo midiendo: la primera pasada quita 54 y las siguientes 1 a 4.
##
## Es la misma lección que el suelo del circuito de espera: una distancia fija
## que no sabe nada del viraje del avión se rompe en cuanto el viraje cambia.
## Con un arma de largo alcance el suelo no se nota — el Maverick reencara a
## 850 px y el suelo son 390 —, así que sólo actúa donde hace falta.
func _reengage_distance() -> float:
	var by_weapon := _max_range * reengage_fraction if _max_range > 0.0 else 0.0
	return maxf(by_weapon, turn_around_margin * _pilot.min_turn_radius())
