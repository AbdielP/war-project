extends Node2D
class_name WellDeck

## El dique inundable: por donde sale la fuerza de desembarco.
##
## Hace por popa lo que [FlightDeck] hace por proa, y comparte con él las tres
## lecciones que costaron aquella cubierta:
##
## - **Mientras está dentro, la lancha es carga.** Todo su recorrido va en
##   coordenadas del buque, no del mundo: un tween apunta a un valor fijo
##   capturado al empezar, así que en coordenadas de mundo el punto de salida
##   deja de ser su sitio en cuanto el barco avanza.
## - **Se reserva el camino, no la plaza.** Que no haya nadie aparcado en la
##   rampa no significa que la franja de agua de detrás esté libre.
## - **Un portero que dice "ahora no" tiene que decir también "ya puedes".**
##   Si la salida se aplaza, alguien tiene que volver a intentarla, o la orden
##   se pierde sin que nadie se entere.
##
## **Y la geometría es la de la pista al revés, que es lo que la hace peor.** Un
## avión despega hacia proa y se separa del buque solo; una lancha sale hacia
## popa, por el agua que el barco acaba de cruzar. Con el buque avanzando eso
## juega a favor —la popa se aleja—, pero ciando y virando juega en contra, y por
## eso la franja se comprueba de verdad en vez de darla por buena.

## La lancha ya está en el agua y navegando por su cuenta.
signal launched(craft: Node2D)
## Una lancha ha vuelto a bordo y se ha devuelto al pañol.
signal recovered(craft: Node2D)

## Lo que tarda en recorrer la rampa, en píxeles por segundo. Lento a propósito:
## es una maniobra de puerto, no una salida.
@export var exit_speed: float = 25.0
## Cuánto tiene que apartarse del eje de la rampa algo para dejar de estorbar la
## salida, en píxeles.
@export var stern_clearance: float = 40.0
## Cada cuánto se vuelve a mirar si la popa quedó despejada, en segundos.
@export var retry_delay: float = 0.5
## A qué distancia del punto de salida se recoge una lancha que se ha parado
## ahí, en píxeles. Generoso: el jugador señala un punto a ojo sobre el mapa, no
## atraca a mano.
@export var recover_radius: float = 16.0
## Con qué orden de dibujo va la lancha **mientras está estibada**.
##
## Por debajo del casco, que es donde está: el dique es un hueco dentro del
## barco. Con su orden normal se la veía deslizándose por encima de la cubierta
## de vuelo, como si navegara sobre el buque, tanto al salir como al entrar. Se
## le devuelve el suyo al soltarla, y no se escribe aquí cuál es: se lee de la
## escena de la lancha, que es donde se decide.
@export var stowed_z_index: int = -1

## Lo único que puede estorbar la salida es otra cosa que flote. Lo que vuela
## pasa por encima y lo que rueda no está en el agua.
const _SEA_GROUP := &"unit_maritime"

@onready var _ramp: Marker2D = $Ramp
@onready var _exit: Marker2D = $ExitPoint
@onready var _approach: Marker2D = $ApproachPoint

## Hay una lancha **recorriendo la rampa** ahora mismo. Igual que la carrera de
## pista, dura unos segundos y termina siempre: no se confunde con "hay un
## desembarco en marcha", que dura lo que dure la travesía.
var _running := false
## La salida que espera a que se despeje la popa. Sólo una: el buque tiene un
## dique y la pantalla manda una lancha cada vez.
var _pending: Dictionary = {}
var _retry_pending := false
## El orden de dibujo que trae la lancha en su escena, para devolvérselo al
## soltarla. Se guarda al crearla en vez de escribirlo aquí: quién va encima de
## quién en el agua lo decide la lancha, no el hueco del que sale.
var _sailing_z := 0


## Manda una lancha a la playa. Devuelve si se aceptó el encargo — que no es lo
## mismo que si ya salió: con la popa ocupada se guarda y sale en cuanto se
## despeje, igual que el hangar guarda una salida hasta que hay ascensor.
## Se le pasa la **casilla de la flota** y no la escena a secas: de ahí sale la
## escena, y además es lo que la lancha necesita guardarse para poder devolverse
## sola al atracar.
func launch(craft_entry: Dictionary, cargo: Array, beach: Vector2) -> bool:
	if craft_entry.is_empty() or craft_entry.get("scene") == null or cargo.is_empty():
		return false
	if not _pending.is_empty():
		return false
	_pending = {"entry": craft_entry, "cargo": cargo, "beach": beach}
	_try_launch()
	return true


## Si el dique puede sacar algo ahora mismo. Lo pregunta la ficha para saber si
## el botón promete algo que se pueda cumplir.
func is_busy() -> bool:
	return _running or not _pending.is_empty()


## El sitio donde se atraca, en mundo. Es donde acaba la vuelta.
func dock_point() -> Vector2:
	return to_global(_exit.position)


## Dónde se pone en franquía antes de entrar: en el eje del dique y bien por
## detrás de la popa. Es el primero de los dos tramos de la vuelta.
##
## Los dos puntos se piden **cada fotograma** y van en coordenadas del buque, así
## que la maniobra entera gira con él: es lo que un punto fijo del agua no hace.
func lineup_point() -> Vector2:
	return to_global(_approach.position)


## Si desde ahí ya se puede entrar derecho, sin pasar antes por el punto de
## franquía: es estar **por detrás de él**, y entonces ir a buscarlo sería
## navegar hacia atrás para volver sobre lo andado.
func is_lined_up(where: Vector2) -> bool:
	return to_local(where).y >= _approach.position.y


## Recoge a la lancha que **venía a atracar** y ya ha llegado.
##
## La condición es que lo haya pedido, no que se haya parado cerca. Con la
## segunda —que fue el primer intento— el jugador tenía que acertarle a un punto
## invisible a 54 px por detrás del casco: pinchar sobre el barco, que es lo
## natural, quedaba fuera de radio y no ocurría nada ni había forma de saber por
## qué. Preguntando por la intención, el radio deja de ser puntería y pasa a ser
## sólo "ya está aquí".
func _process(_delta: float) -> void:
	if _running:
		return
	var craft := _craft_arriving()
	if craft != null:
		_recover(craft)


func _craft_arriving() -> LandingCraft:
	for node in get_tree().get_nodes_in_group(_SEA_GROUP):
		var craft := node as LandingCraft
		if craft == null or not is_instance_valid(craft):
			continue
		# Las de dentro ya están recogidas o saliendo.
		# **Y que venga ya en el tramo final.** Preguntando sólo si vuelve, se la
		# tragaba de paso: yendo a ponerse en franquía cruza cerca del muelle a
		# toda máquina, y la recogía en marcha y de través.
		if craft.get_parent() == self or not craft.is_docking_at(self):
			continue
		if to_local(craft.global_position).distance_to(_exit.position) <= recover_radius:
			return craft
	return null


## Sube la lancha por la rampa y la devuelve al pañol. El recorrido es el de
## salir del revés —y en coordenadas del buque, por lo mismo— con la lancha
## encarando hacia proa, que es como se entra.
func _recover(craft: LandingCraft) -> void:
	_running = true
	craft.pilot.disable()
	craft.reparent(self, true)
	craft.z_index = stowed_z_index
	var distance: float = craft.position.distance_to(_ramp.position)
	var tw := craft.create_tween()
	tw.set_parallel(true)
	tw.tween_property(craft, "position", _ramp.position, distance / exit_speed) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	# **Por el lado corto.** Una lancha que entra de proa llega con la rotación
	# en −π y el rumbo de entrada es +π: son el mismo ángulo, pero un tween
	# interpola el número, no la dirección, y recorría los 360° enteros dando una
	# vuelta de campana justo al atracar. `angle_difference` da el desvío corto.
	var entrada: float = craft.rotation \
			+ angle_difference(craft.rotation, _ramp.rotation + PI)
	tw.tween_property(craft, "rotation", entrada, distance / exit_speed)
	var acabar := _once(craft)
	var unit := craft as Unit
	if unit != null:
		unit.died.connect(func(_dead: Unit) -> void: acabar.call(), CONNECT_ONE_SHOT)
	tw.finished.connect(func() -> void:
		if is_instance_valid(craft):
			craft.return_to_fleet()
			recovered.emit(craft)
			craft.queue_free()
		acabar.call())


func _try_launch() -> void:
	if _running or _pending.is_empty():
		return
	# La franja se mira **antes** de crear nada. Creando primero, una salida
	# aplazada dejaría una lancha existiendo dentro del casco durante segundos.
	if _stern_blocker() != null:
		_retry_later()
		return

	var job: Dictionary = _pending
	_pending = {}
	_running = true

	var entry: Dictionary = job["entry"]
	var craft := entry["scene"].instantiate() as Node2D
	_sailing_z = craft.z_index
	# Hija del dique, no del mundo: mientras baja por la rampa viaja con el
	# barco, y sus coordenadas son las de éste.
	add_child(craft)
	craft.z_index = stowed_z_index
	craft.position = _ramp.position
	craft.rotation = _ramp.rotation
	if craft.has_method("load_cargo"):
		craft.load_cargo(job["cargo"])
	var laden := craft as LandingCraft
	if laden != null:
		laden.fleet_entry = entry
		# De aquí salió y aquí vuelve. Es lo que hace que "regresar" sea una
		# orden sin destino que dar: la lancha ya sabe cuál es su casa.
		laden.home_deck = self

	var distance: float = _ramp.position.distance_to(_exit.position)
	var tw := craft.create_tween()
	tw.tween_property(craft, "position", _exit.position, distance / exit_speed) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# **`tree_exited` ya no significa "se hundió"**: soltarla al mar también es
	# salir de este árbol. La muerte tiene su propia señal desde que existe el
	# reparentado, y sin distinguirlas la rampa se quedaría cerrada para siempre
	# la primera vez que hundan una.
	var acabar := _once(craft)
	var unit := craft as Unit
	if unit != null:
		unit.died.connect(func(_dead: Unit) -> void: acabar.call(), CONNECT_ONE_SHOT)
	tw.finished.connect(func() -> void:
		_detach(craft)
		if craft.has_method("start_crossing"):
			craft.start_crossing(job["beach"])
		launched.emit(craft)
		acabar.call())


## Cierra la salida una sola vez, venga por haber terminado o por haberse
## hundido a mitad de rampa, y **vuelve a preguntar**: si había otra esperando,
## éste es el momento en que puede salir. Sin esta repregunta la segunda lancha
## se quedaría en el cajón y no habría error que lo delatara.
func _once(_craft: Node2D) -> Callable:
	var hecho := [false]
	return func() -> void:
		if hecho[0]:
			return
		hecho[0] = true
		_running = false
		_try_launch()


## La suelta al mundo. A partir de aquí deja de viajar con el barco y navega en
## coordenadas de mundo, que es lo que su piloto espera.
func _detach(craft: Node2D) -> void:
	if not is_instance_valid(craft) or craft.get_parent() != self:
		return
	craft.z_index = _sailing_z
	var world: Node = get_parent().get_parent()
	if world == null:
		world = get_tree().current_scene
	craft.reparent(world, true)


## Quién estorba la salida, o `null`. Se pregunta por la **geometría** y no por
## si la rampa está ocupada: son cosas distintas y la diferencia es justo el caso
## malo — una lancha que acaba de salir ya no está en la rampa y sigue metida en
## la franja durante toda su arrancada.
##
## Se mira en coordenadas del buque, así que vale igual con él parado, navegando
## o virando: la franja gira con el barco porque está definida sobre él.
func _stern_blocker() -> Node2D:
	var from: Vector2 = _ramp.position
	var to: Vector2 = _exit.position
	var lo: float = minf(from.y, to.y)
	var hi: float = maxf(from.y, to.y)
	var ship: Node = get_parent()
	for node in get_tree().get_nodes_in_group(_SEA_GROUP):
		var other := node as Node2D
		if other == null or other == ship or not is_instance_valid(other):
			continue
		var p: Vector2 = to_local(other.global_position)
		if absf(p.x - to.x) > stern_clearance:
			continue
		if p.y < lo or p.y > hi:
			continue
		return other
	return null


## Vuelve a mirar dentro de un rato. **Sólo mientras siga habiendo estorbo y una
## salida esperando**: lo que ocupa la popa es del jugador y no le debe ninguna
## señal al barco, así que hay que volver a mirar por cuenta propia — pero una
## espera pendiente como mucho, o se acaba con un temporizador latiendo para
## siempre.
func _retry_later() -> void:
	if _retry_pending or _pending.is_empty():
		return
	_retry_pending = true
	get_tree().create_timer(retry_delay).timeout.connect(func() -> void:
		_retry_pending = false
		_try_launch())
