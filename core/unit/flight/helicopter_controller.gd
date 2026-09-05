extends Node
class_name HelicopterController

## Piloto de helicóptero. Decide CÓMO se mueve el aparato; a dónde va lo decide
## quien llame a `set_target()`. Mueve al nodo padre.
##
## **No es un avión y por eso no reusa `PlaneController`.** Aquél está construido
## sobre el radio de giro: no puede parar, no puede ir despacio y todo lo que
## hace sale de un círculo mínimo. Un helicóptero no tiene círculo mínimo — va a
## donde le mandes, se planta ahí y se queda.
##
## [b]El aparato se mueve en sus propios ejes, y obedece.[/b]
##
## Un helicóptero de juego se lleva con dos manos separadas: W/S y A/D lo mueven
## [i]en sus propios ejes[/i] y las flechas lo rotan aparte. Eso es lo que hay
## aquí dentro —un mando virtual, `_stick` y `_pedal`— y de ahí salen las dos
## cosas que lo distinguen de un avión:
##
## - **Los ejes no valen lo mismo.** Adelante corre, atrás es lento y feo, de
##   costado va a medias. Si todo fuese la misma velocidad, esto sería un icono
##   deslizándose hacia un punto.
## - **Girar no es consecuencia de moverse.** Encara si el sitio está lejos; si
##   está a un palmo entra de lado sin molestarse en girar, como haría cualquiera.
##
## [b]Y el mando se mueve con precisión, a propósito.[/b] Hubo una versión con un
## piloto torpe dentro: soltaba tarde, se pasaba del punto, corregía, dejaba el
## morro desviado. La idea venía de los juegos donde pilotas tú, y ahí funciona
## —el error es tuyo y lo sientes—. Aquí no: en un juego de órdenes, una unidad
## imprecisa no parece un piloto humano, parece que no te ha hecho caso. Se fue
## entera.
##
## El carácter está en el **peso**: lo que cuesta arrancar y parar, lo que tarda
## la cola en girar, lo torpe que es de costado. No en el error.
##
## [b]Y en combate los dos mandos se separan del todo.[/b]
##
## Fuera de combate el rumbo sale de la marcha: se encara a donde se va. Con
## blanco puesto —`attack()`— el pedal deja de mirar el destino y clava el morro
## en el objetivo, mientras el cíclico se ocupa sólo de la distancia. De ahí sale
## el gesto del helicóptero artillado: entra de costado mientras la cola todavía
## viene girando, y se planta apuntando.
##
## El blanco y el destino **no conviven**: dar uno suelta el otro. Un aparato que
## siguiera encarando a un enemigo mientras el jugador lo manda a otro sitio
## estaría obedeciendo a medias, y esto es un juego de órdenes.
##
## Anuncia en qué fase está —`state_changed`— y no toca ningún sprite. Las
## animaciones de hélice, vuelo y despegue se cuelgan de esa señal cuando las
## haya, sin volver a tocar el vuelo.

signal target_reached
signal state_changed(state: int)
## Dejó la cubierta. Lo escucha el barco para dar la plaza por libre.
signal took_off
## Se posó del todo y paró. Espejo de [signal took_off].
signal landed

## En qué anda. Es lo que mira la animación para saber qué dibujar.
enum State {
	GROUNDED,  ## Posado. Ni se mueve ni obedece hasta que se le ordene salir.
	LIFTING,   ## Subiendo en vertical. Todavía en su sitio, ya no en cubierta.
	FLYING,    ## De camino a un punto.
	HOVER,     ## Llegó, y ahí se queda.
	## Bajando en vertical sobre el sitio. Ya no obedece: la maniobra terminó y
	## lo que queda es tocar. **Va al final del enum a propósito**, que el valor
	## viaja en `state_changed` y colarlo en medio le cambiaría el estado a todo
	## el que lo escuche.
	LANDING,
}

@export_group("Ejes de marcha")
## Lo que corre de morro, con el mando a fondo. Es el único eje rápido.
@export var forward_speed: float = 85.0
## Marcha atrás. Lenta a propósito: un helicóptero de espaldas va incómodo y se
## nota, y es lo que empuja a girar en vez de recular medio mapa.
@export var back_speed: float = 28.0
## De costado, sin girar. A medias entre los otros dos: sirve para colocarse,
## no para viajar.
@export var strafe_speed: float = 38.0
## Lo que gana por segundo al empujar el mando.
@export var acceleration: float = 60.0
## Lo que suelta por segundo al soltarlo. También decide cuándo el piloto deja
## de empujar, porque suelta cuando calcula que con esto le llega.
@export var deceleration: float = 55.0

@export_group("Giro")
## Lo que gira sobre sí mismo con el pedal a fondo, en grados por segundo. Aquí
## sí son grados y no un radio: un helicóptero pivota parado, así que su giro no
## depende de lo rápido que vaya.
@export var yaw_speed_deg: float = 100.0
## Lo que tarda el giro en llegar a tope desde quieto, y lo mismo en pararse.
## Bajo = aparato pesado de cola.
@export var yaw_ramp_time: float = 0.45
## Desvío de rumbo por debajo del cual se deja de tocar el pedal. Pequeño: está
## para no pelearse con el último grado, no para dejar el morro torcido.
@export var yaw_deadzone_deg: float = 1.5

@export_group("Mando")
## Lo que tarda en meter cíclico después de meter morro. **Es lo único que se
## hace esperar**, y no es imprecisión: es el gesto de un helicóptero que primero
## se encara y luego sale. Pasa siempre igual, así que se lee como arranque y no
## como desobediencia.
@export var stick_delay: float = 0.25
## Por debajo de esta distancia no gira para encarar: se acerca de lado o de
## espaldas. Girar para dos palmos es lo que delata a un robot.
@export var face_range: float = 70.0
## Desvío por eje por debajo del cual se suelta ese eje. Mismo papel que la zona
## muerta del pedal, pero para el cíclico.
@export var axis_deadzone: float = 1.5

@export_group("Navegación")
## Distancia a la que se da por llegado.
@export var arrive_radius: float = 3.0
## Y a qué velocidad como mucho. Las dos condiciones, no una: pasar por encima
## del punto a toda velocidad no es llegar. Con la frenada bien calculada no
## debería hacer falta, pero si algún día se le manda un punto en marcha y lo
## cruza de paso, esto es lo que impide que cante victoria y se quede veinte
## píxeles más allá.
@export var settle_speed: float = 12.0
## Grados a sumar al rumbo para orientar el sprite. El arte apunta hacia abajo
## (+Y local), por eso -90.
@export var sprite_offset_deg: float = -90.0

@export_group("Combate")
## Margen del anillo de tiro, en píxeles. Dentro de él se da por colocado y deja
## de meter cíclico: sin holgura corregiría eternamente el último píxel contra un
## blanco que también se mueve.
@export var hold_band: float = 8.0

@export_group("Despegue")
## Lo que tarda en despegar en vertical antes de salir hacia el primer destino.
## Ahora mismo es sólo una espera —no hay nada que dibujar todavía—, pero es el
## hueco donde entra la animación de despegue.
@export var lift_time: float = 1.6
## Lo que tarda en posarse desde que se queda quieto sobre el sitio. Igual que
## `lift_time`, hoy es sólo una espera: es el hueco donde entra la animación de
## posada y la parada de rotor.
@export var land_time: float = 1.6

var heading: float = 0.0
var velocity: Vector2 = Vector2.ZERO
var target: Vector2 = Vector2.ZERO
var has_target: bool = false

## A quién le apunta el morro, o `null` si a nadie. Mientras haya alguien, el
## rumbo deja de salir de la marcha y sale del blanco: es la postura de tiro de
## un helicóptero artillado, y lo que hace que se le vea entrar de costado.
var aim: Node2D = null
## A qué distancia del blanco se planta a disparar. La decide quien da la orden
## —que es quien sabe con qué arma va—, no el piloto.
var hold_distance: float = 0.0

## Rumbo impuesto, en radianes, o `NAN` si el morro sale de la marcha.
##
## Es la tercera forma de gobernar el morro, junto al destino y al blanco, y hace
## falta para **colocarse paralelo a algo**: un helicóptero que se arrima a un
## barco no mira a donde va, mira a donde mira el barco. Sin esto, el tramo de
## cruce lateral sobre la cubierta lo haría girando hacia su destino, que es
## justo lo que la maniobra evita.
var locked_heading: float = NAN

var _body: Node2D
var _state: State = State.GROUNDED

## El mando, en ejes del propio aparato: x adelante/atrás, y a los costados. De
## -1 a 1, analógico: el tramo intermedio es lo que permite plantarse justo en el
## punto en vez de llegar a tirones.
var _stick: Vector2 = Vector2.ZERO
## El pedal, de -1 a 1.
var _pedal: float = 0.0
var _yaw_rate: float = 0.0
var _wanted_heading: float = 0.0
## Cuánto queda de morro antes de poder tocar el cíclico. Ver `stick_delay`.
var _hold: float = 0.0
var _lifting_for: float = 0.0
var _landing_for: float = 0.0


func _ready() -> void:
	_body = get_parent() as Node2D
	set_physics_process(false)


## Recoge el control del aparato tal como esté colocado, **posado**. Sale de
## cubierta cuando se le ordene ir a algún sitio y no antes: un helicóptero
## esperando en el barco es un estado normal, no una avería.
func enable() -> void:
	if _body == null:
		return
	heading = wrapf(_body.global_rotation - deg_to_rad(sprite_offset_deg), -PI, PI)
	_wanted_heading = heading
	velocity = Vector2.ZERO
	_stick = Vector2.ZERO
	_pedal = 0.0
	_yaw_rate = 0.0
	set_physics_process(true)
	# Si le ordenaron algo mientras el barco todavía lo estaba colocando, la orden
	# vale: se sale a cumplirla en cuanto hay control. Resetear a posado sería
	# tragarse una orden que el jugador ya dio y ve marcada en el mapa.
	#
	# **Las dos clases de orden cuentan**, y ahí estaba el fallo: la cubierta le
	# apunta el blanco antes de soltarlo, así que al llegar aquí `aim` ya está
	# puesto y `has_target` no. Mirando sólo el destino, un helicóptero mandado a
	# atacar desde el hangar se quedaba en cubierta con el morro girado hacia el
	# enemigo, y nadie volvía a pasar por aquí a sacarlo: la orden no se repite
	# porque el blanco no ha cambiado.
	if has_target or is_instance_valid(aim):
		_lift_off()
	else:
		_set_state(State.GROUNDED)


func disable() -> void:
	set_physics_process(false)
	has_target = false
	aim = null
	locked_heading = NAN
	velocity = Vector2.ZERO
	_stick = Vector2.ZERO
	_pedal = 0.0


func get_state() -> State:
	return _state


func is_airborne() -> bool:
	return _state == State.FLYING or _state == State.HOVER


## Manda al aparato a un punto. Si todavía está posado, esto es también la orden
## de despegar: sube primero y sale después, con el destino ya guardado.
##
## Toda orden nueva empieza por el morro: se mete pedal y el cíclico espera
## `stick_delay`. Es el gesto que hace reconocible a un helicóptero pilotado.
func set_target(world_pos: Vector2) -> void:
	target = world_pos
	has_target = true
	# Irse a un sitio suelta el blanco. El aparato es del jugador: si le manda
	# marcharse, se marcha — quedarse encarado a un enemigo mientras se va sería
	# obedecer a medias.
	aim = null
	_hold = stick_delay
	if _state == State.GROUNDED:
		# Puede estar todavía sin control —el barco colocándolo en cubierta—, y
		# entonces la subida arranca al recibirlo. Ver [method enable].
		if is_physics_processing():
			_lift_off()
	elif _state == State.HOVER:
		_set_state(State.FLYING)


## Se pone a tirarle a alguien: morro puesto y colocarse a la distancia que pida
## el arma. `distance` no se calcula aquí a propósito — el piloto no sabe de
## alcances ni de munición, y quien da la orden sí.
##
## Es una orden de las que empiezan por el morro, igual que un destino: se mete
## pedal y el cíclico espera `stick_delay`. Y cancela el destino que hubiera,
## porque atacar y viajar compiten por el mismo mando.
func attack(unit: Node2D, distance: float) -> void:
	if not is_instance_valid(unit):
		return
	aim = unit
	hold_distance = maxf(distance, 0.0)
	has_target = false
	_hold = stick_delay
	if _state == State.GROUNDED:
		# Puede estar todavía en cubierta sin control. Ver [method enable].
		if is_physics_processing():
			_lift_off()
	elif _state == State.HOVER:
		_set_state(State.FLYING)


## Corrige el destino **sin volver a empezar la maniobra**. Es la hermana de
## [method set_hold_distance] y existe por lo mismo: la usa quien persigue algo
## que se mueve —un barco al que hay que arrimarse—, donde el punto cambia cada
## fotograma.
##
## Repetir ahí [method set_target] dejaría el aparato clavado: cada llamada
## rearma la espera del cíclico, así que el mando nunca llegaría a moverse y el
## helicóptero se pasaría la vida metiendo morro sin salir del sitio.
func steer_to(world_pos: Vector2) -> void:
	target = world_pos
	has_target = true
	if _state == State.HOVER:
		_set_state(State.FLYING)


## Cambia la distancia de tiro sin volver a empezar la maniobra. La usa quien
## cambia de arma en pleno ataque: la envolvente es otra, pero el gesto de
## encarar ya se hizo y repetirlo dejaría el aparato clavado metiendo morro.
func set_hold_distance(distance: float) -> void:
	hold_distance = maxf(distance, 0.0)


## Deja de apuntar. Se queda donde esté: soltar el blanco no es una orden de ir
## a ninguna parte.
func stop_attack() -> void:
	aim = null
	_stick = Vector2.ZERO
	if _state == State.FLYING and not has_target:
		_set_state(State.HOVER)


## Empieza a subir. `took_off` sale de aquí y no de la orden porque lo que le
## importa al barco es que la plaza queda libre, y sólo queda libre cuando el
## aparato de verdad se despega del suelo.
func _lift_off() -> void:
	_lifting_for = 0.0
	_set_state(State.LIFTING)
	took_off.emit()


## Se posa: suelta los mandos y baja. Espejo de [method _lift_off], y como él,
## hoy la bajada es sólo una espera —ver `land_time`—.
##
## No comprueba nada: cuándo se puede posar lo decide quien lleva la maniobra,
## que es el único que sabe si hay cubierta debajo.
func land() -> void:
	has_target = false
	aim = null
	locked_heading = NAN
	velocity = Vector2.ZERO
	_stick = Vector2.ZERO
	_pedal = 0.0
	_yaw_rate = 0.0
	_landing_for = 0.0
	_set_state(State.LANDING)


## Suelta el destino, no el blanco: son dos mandos distintos y el morro sigue
## puesto donde estaba.
func clear_target() -> void:
	has_target = false
	_stick = Vector2.ZERO
	if _state == State.FLYING:
		_set_state(State.HOVER)


func _physics_process(delta: float) -> void:
	match _state:
		State.GROUNDED:
			return
		State.LIFTING:
			_lifting_for += delta
			if _lifting_for >= lift_time:
				_set_state(State.FLYING if has_target else State.HOVER)
			return
		State.LANDING:
			# Nada de `_fly` aquí: mientras baja está reparentado al barco y
			# escribirle la posición del mundo pelearía con la cubierta, que ya
			# lo lleva colocado.
			_landing_for += delta
			if _landing_for >= land_time:
				_set_state(State.GROUNDED)
				set_physics_process(false)
				landed.emit()
			return
		_:
			_fly(delta)


func _fly(delta: float) -> void:
	_hold = maxf(_hold - delta, 0.0)
	_work_the_controls()
	_apply_stick(delta)
	_apply_pedal(delta)

	_body.global_position += velocity * delta
	_body.global_rotation = heading + deg_to_rad(sprite_offset_deg)


## Mira dónde está y dónde tiene que ir, y coloca el mando. Es lo único que sabe
## del destino: de aquí para abajo ya sólo hay mando y física.
func _work_the_controls() -> void:
	# El blanco manda sobre el destino porque no coexisten: dar uno suelta el
	# otro. La comprobación es de validez, no de prioridad — un blanco que murió
	# entre dos frames sigue siendo una referencia con tipo, y hay que soltarla.
	if aim != null:
		if is_instance_valid(aim):
			_work_the_attack()
			return
		aim = null
	if not has_target:
		_stick = Vector2.ZERO
		_pedal = 0.0
		return

	var to_target := target - _body.global_position
	var dist := to_target.length()
	if dist <= arrive_radius and velocity.length() <= settle_speed:
		has_target = false
		_stick = Vector2.ZERO
		_pedal = 0.0
		_set_state(State.HOVER)
		target_reached.emit()
		return

	# Encarar es una decisión aparte de moverse, igual que las flechas son
	# teclas aparte de W/S. Y de cerca ni se plantea: se entra de lado.
	#
	# Con rumbo impuesto no se plantea nunca: el morro va donde le digan y el
	# cíclico se ocupa de llegar. Es el mismo reparto de dos manos que en
	# combate, con el barco en el papel del blanco.
	if not is_nan(locked_heading):
		_wanted_heading = locked_heading
	elif dist > face_range:
		_wanted_heading = to_target.angle()
	_pedal = _pedal_input()

	if _hold > 0.0:
		# Todavía metiendo morro. El cíclico aún no.
		_stick = Vector2.ZERO
		return

	# El vector al destino, visto desde la cabina: x es lo que tiene por delante,
	# y lo que tiene al costado. Esto es exactamente lo que un jugador lee de la
	# pantalla antes de decidir qué tecla aprieta.
	var local := to_target.rotated(-heading)
	_stick = Vector2(
		_axis_input(local.x, forward_speed if local.x > 0.0 else back_speed),
		_axis_input(local.y, strafe_speed))


## Colocarse para tirar. Dos mandos separados, como siempre en este aparato: el
## pedal clava el morro en el blanco y el cíclico sólo se ocupa de la distancia.
##
## No hay `face_range` que valga aquí — encarar de cerca es justo lo que se
## quiere— ni se llega a "destino": el sitio bueno es un **anillo** alrededor del
## blanco, y dentro de él ya está colocado.
func _work_the_attack() -> void:
	var to_target := aim.global_position - _body.global_position
	_wanted_heading = to_target.angle()
	_pedal = _pedal_input()

	if _hold > 0.0:
		# Todavía metiendo morro. El cíclico aún no.
		_stick = Vector2.ZERO
		return

	# Lo que sobra o falta para el anillo de tiro. El movimiento es radial: se
	# entra de morro y se sale de espaldas —que es el eje lento—, así que el
	# aparato se resiste a retroceder mucho más que a acercarse. Es correcto: un
	# helicóptero que se pasó de cerca preferiría girar, pero girando perdería
	# la puntería, y aquí la puntería es lo que se está sirviendo.
	var closing := to_target.length() - hold_distance
	if absf(closing) <= hold_band:
		_stick = Vector2.ZERO
		_set_state(State.HOVER)
		return
	_set_state(State.FLYING)

	# Mientras la cola todavía está girando, este mismo vector sale con
	# componente lateral y el aparato entra de costado. No está buscado: es lo
	# que pasa cuando el morro va por un lado y el cíclico por otro.
	var local := (to_target.normalized() * closing).rotated(-heading)
	_stick = Vector2(
		_axis_input(local.x, forward_speed if local.x > 0.0 else back_speed),
		_axis_input(local.y, strafe_speed))


## Cuánto mando pide un eje. A tope mientras quede sitio, y se va soltando en el
## último tramo: la velocidad que se pide nunca es mayor que la que permite
## pararse en lo que falta.
##
## Esa cuenta —v² = 2·a·d— es la que hace que se plante en el punto en vez de
## pasarse y volver. Es exacta a propósito. Una unidad a la que ordenas un sitio
## tiene que quedarse en ese sitio; el peso se nota en lo que le cuesta llegar,
## no en fallar el frenazo.
func _axis_input(offset: float, top: float) -> float:
	if absf(offset) < axis_deadzone:
		return 0.0
	var allowed := sqrt(2.0 * deceleration * absf(offset))
	return signf(offset) * minf(1.0, allowed / maxf(top, 1.0))


## Lo mismo con el pedal: a fondo mientras falte rumbo, y soltando al final para
## que la cola no se pase de largo y tenga que volver.
func _pedal_input() -> float:
	var err := angle_difference(heading, _wanted_heading)
	if absf(err) < deg_to_rad(yaw_deadzone_deg):
		return 0.0
	var ramp := deg_to_rad(yaw_speed_deg) / maxf(yaw_ramp_time, 0.01)
	var allowed := sqrt(2.0 * ramp * absf(err))
	return signf(err) * minf(1.0, allowed / deg_to_rad(yaw_speed_deg))


## El mando movido se convierte en velocidad. Cada eje tiene su tope y por eso
## la misma pulsación no vale lo mismo hacia adelante que hacia atrás.
func _apply_stick(delta: float) -> void:
	var top_x := forward_speed if _stick.x > 0.0 else back_speed
	var wanted := Vector2(_stick.x * top_x, _stick.y * strafe_speed)
	# En diagonal las dos teclas suman más que cualquiera de ellas sola, así que
	# se recorta al eje más rápido de los que estén metidos: ir en diagonal no
	# puede salir más rápido que ir de frente.
	wanted = wanted.limit_length(maxf(top_x, strafe_speed))
	wanted = wanted.rotated(heading)
	var rate := acceleration if wanted.length() > velocity.length() else deceleration
	velocity = velocity.move_toward(wanted, rate * delta)


func _apply_pedal(delta: float) -> void:
	var omega := deg_to_rad(yaw_speed_deg)
	var ramp := omega / maxf(yaw_ramp_time, 0.01)
	_yaw_rate = move_toward(_yaw_rate, _pedal * omega, ramp * delta)
	heading = wrapf(heading + _yaw_rate * delta, -PI, PI)


func _set_state(value: State) -> void:
	if _state == value:
		return
	_state = value
	state_changed.emit(value)
