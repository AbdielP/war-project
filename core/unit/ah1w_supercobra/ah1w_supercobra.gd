extends Unit

## Qué ES el SuperCobra: identidad y cómo recibe órdenes. No pilota — de eso se
## encarga `HelicopterController`.
##
## Es mucho más corto que el Harrier y no por estar a medias: **un helicóptero no
## necesita comportamientos**. El avión los tiene porque no puede parar, así que
## hay que inventarle qué hacer cuando no hay nada que hacer —dar vueltas— y cómo
## acercarse a un blanco sin poder frenar —la pasada—. Aquí no: se le manda un
## punto, va, y se queda. Ir y esperar son lo mismo.
##
## Sin patrón de espera a propósito. Un helicóptero en su sitio ya está
## esperando.
##
## **Atacar tampoco es un comportamiento**, por lo mismo. El avión necesita la
## pasada porque no puede parar; aquí la maniobra de tiro es plantarse a la
## distancia que pida el arma con el morro puesto, y eso es un destino más. Lo
## único que hay que decidir aquí es **cuál** es esa distancia, porque depende
## del arma y el piloto no sabe de armas.

signal order_fulfilled
## Dejó la cubierta. Lo reemite el piloto; se anuncia desde aquí porque quien
## escucha es el barco, y el barco habla con la unidad, no con sus tripas.
signal took_off

## Qué fracción del alcance del arma se deja como distancia de tiro.
##
## No se pega al máximo: ahí la puntería del cañón está en su peor momento y
## cualquier movimiento del blanco lo saca de alcance. Tampoco se mete encima —
## acercarse más no mejora lo bastante como para pagar el fuego que se come.
@export_range(0.1, 1.0, 0.05) var standoff_fraction: float = 0.8

@onready var pilot: HelicopterController = $HelicopterController
@onready var weapons: WeaponSystem = $WeaponSystem


func _ready() -> void:
	super._ready()
	add_to_group("unit_air")
	# Volviendo a bordo, cada tramo de la maniobra es una llegada más y ninguna
	# es la orden del jugador: la orden es volver, y no está cumplida hasta que
	# el aparato está abajo.
	pilot.target_reached.connect(func() -> void:
		if _recovery == Recovery.NONE:
			order_fulfilled.emit())
	pilot.took_off.connect(_on_took_off)
	pilot.landed.connect(_on_landed)
	# Un solo sitio donde se traduce "a quién ataco" a maniobra, venga de una
	# orden, de una orden de movimiento que la cancela o de que el blanco murió.
	attack_target_changed.connect(_on_attack_target_changed)
	# El arma manda sobre la colocación: cambiarla en pleno ataque cambia a qué
	# distancia hay que quedarse.
	active_weapon_changed.connect(_on_active_weapon_changed)
	# En cubierta no se dispara, aunque ya venga con el blanco apuntado desde el
	# hangar.
	weapons.set_active(false)


## Se despega del suelo. Aquí es donde entra en combate y no en `start_flight`:
## el barco le cede el control **con el aparato todavía posado**, y un cañón
## abriendo fuego desde la cubierta le tiraría a la superestructura.
func _on_took_off() -> void:
	weapons.set_active(true)
	took_off.emit()


## El rumbo real, no la rotación del nodo: el arte apunta a +Y, así que la
## rotación lleva un desfase que el armamento no debe heredar.
func get_facing() -> float:
	return pilot.heading


func get_velocity() -> Vector2:
	return pilot.velocity


## Cuánto falta para que llegue lo que tenga en el aire. Se pregunta **acotado a
## su blanco**: con un misil todavía volando, cambiar de objetivo le pasaría al
## nuevo la cuenta atrás del anterior, y su marca se cerraría contra un impacto
## que va a ocurrir en otro sitio.
func get_time_to_impact() -> float:
	return weapons.time_to_impact(attack_target)


## A dónde va. Cuando llega deja de ir a ninguna parte: quedarse en el sitio no
## es una maniobra, es el reposo de este aparato.
func get_move_destination() -> Variant:
	return pilot.target if pilot.has_target else null


## El barco le cede el control **con el aparato todavía en cubierta**, al
## contrario que el avión, al que suelta ya volando. Aquí el despegue es suyo:
## sale cuando el jugador le dé un sitio a donde ir.
##
## `orbit_center` se ignora — no hay circuito de espera que montar alrededor del
## barco. Se acepta el argumento porque es lo que la cubierta llama a todo lo que
## despega, y no tiene por qué saber qué está soltando.
func start_flight(_orbit_center: Node2D) -> void:
	pilot.enable()
	# Si le apuntaron un blanco mientras el barco lo colocaba, la orden vale:
	# aquí es donde se convierte en maniobra, que es cuando ya hay piloto con el
	# que hacerla. Anotarla antes y montarla ahora es el orden que pide la
	# cubierta.
	if is_instance_valid(attack_target):
		receive_attack_order(attack_target)


## Mandarlo a un sitio cancela la vuelta a bordo, y con ella la plaza reservada.
## Si no, seguiría persiguiendo al buque cada fotograma y el punto que acaba de
## pedir el jugador no duraría ni un frame: el aparato parecería no haber hecho
## caso.
func receive_move_order(target: Vector2) -> void:
	_abort_recovery()
	super.receive_move_order(target)
	pilot.set_target(target)


## Cambió a quién le tira, y aquí es donde eso se convierte en maniobra. No hay
## `receive_attack_order` que sobrescribir: la orden sólo anota a quién, y por
## este mismo aviso pasan también el ataque que termina porque el blanco murió y
## el que se cancela porque el jugador mandó al aparato a otro sitio.
func _on_attack_target_changed(target: Unit) -> void:
	if not is_instance_valid(target):
		pilot.stop_attack()
		return
	# Un blanco nuevo es una orden nueva y suelta la vuelta. Sin esto, el piloto
	# recibiría a la vez la maniobra de tiro y la corrección de la aproximación,
	# y ganaría la última que se escribiera.
	_abort_recovery()
	pilot.attack(target, _firing_distance(target))


func _on_active_weapon_changed(_weapon: WeaponType) -> void:
	if is_instance_valid(attack_target):
		pilot.set_hold_distance(_firing_distance(attack_target))


## A qué distancia se planta a tirarle. Sale del arma que lleve puesta, que es
## lo que quería decir "se acerca según con qué vaya armado".
##
## **Sin nada con lo que dispararle se queda donde está**, con el morro puesto:
## meterse en el alcance de algo a lo que no puedes hacer nada es sólo ponerse a
## tiro. No es negarse a la orden —el blanco queda marcado y el HUD lo dice—,
## es no gastar el aparato en un viaje que no sirve.
func _firing_distance(target: Unit) -> float:
	var weapon := active_weapon
	var here := global_position.distance_to(target.global_position)
	if weapon == null or not has_ammo(weapon):
		return here
	var domain := target.get_domain()
	if not weapon.can_engage_domain(domain):
		return here
	var reach := weapon.max_range_against(domain)
	# El mínimo del arma no es una preferencia sino física: por dentro de él no
	# se puede tirar, así que manda sobre la fracción.
	return maxf(weapon.min_range_against(domain), reach * standoff_fraction)


## Se quedó sin objetivo porque murió. Nadie más lo vigila: el piloto suelta la
## referencia para no apuntar a un fantasma, pero `attack_target` es de la unidad
## y hay que soltarlo aquí, o el HUD seguiría diciendo que está atacando.
func _physics_process(_delta: float) -> void:
	_work_the_recovery()
	if attack_target == null:
		return
	if not is_instance_valid(attack_target) or not attack_target.is_alive():
		set_attack_target(null)


## En qué tramo de la vuelta a bordo anda.
##
## **Se entra por popa**, nunca por proa: por proa es por donde sale lo que
## despega. Desde ahí se sube por el costado, fuera del buque, hasta la altura de
## la plaza asignada, y sólo entonces se cruza de lado sobre la cubierta. Es como
## se hace de verdad, y de paso es lo que hace que la maniobra sea programable:
## al arrimarse, el aparato queda quieto **respecto al barco**, que es justo la
## condición para colgarlo de él y medir el resto en coordenadas de cubierta.
##
## Y hay un regalo: el tramo más mirado de todos, el cruce, se hace **sin girar
## el sprite**, con el aparato paralelo al buque. Girar pixel art lo destruye, así
## que la maniobra esquiva sola la peor debilidad del proyecto.
enum Recovery {
	NONE,       ## No vuelve a bordo.
	WAITING,    ## Pidió entrar y la cubierta está ocupada. Espera por popa.
	JOIN,       ## Yendo al punto de entrada, por detrás del buque.
	ALONGSIDE,  ## Subiendo por el costado hasta la altura de su plaza.
	CROSS,      ## Cruzando de lado sobre la cubierta, hasta encima de la plaza.
	SETTLING,   ## Ya es carga del barco: bajando sobre su plaza.
}

## A qué velocidad como mucho se da por colocado sobre la plaza. Las dos
## condiciones, distancia y velocidad, igual que el piloto para llegar a un
## punto: pasar por encima del sitio a toda velocidad no es haber llegado, y aquí
## además hay un barco debajo.
@export var touchdown_speed: float = 6.0

var _recovery: Recovery = Recovery.NONE
var _recovery_deck: FlightDeck = null
var _recovery_slot: int = -1
## De qué cubierta salió. Es a donde vuelve cuando se le da la orden sin decirle
## a cuál, que es el caso normal porque hay un buque. Se la pone la cubierta al
## crearlo.
var home_deck: FlightDeck = null


## Vuelve a la cubierta de la que salió. Es lo que pide el botón: el aparato ya
## sabe cuál es su casa y no hay que decírselo.
func return_home() -> void:
	return_to(home_deck)


## Vuelve a bordo de una cubierta concreta. Pulsando un buque sí se dice cuál,
## porque el jugador lo está señalando.
##
## **El sí o no se contesta aquí, antes de la aproximación.** Si la cubierta está
## ocupada no es que no se pueda volver: es que se espera por popa hasta que le
## toque, y quien avisa es ella con [method recovery_granted]. Preguntar más
## tarde sería comprometer al aparato antes de saber si hay sitio.
func return_to(deck: FlightDeck) -> void:
	if deck == null or not is_instance_valid(deck) or not pilot.is_airborne():
		return
	# Volver cancela lo que estuviera haciendo. Es una orden como las demás.
	set_attack_target(null)
	_recovery_deck = deck
	var slot := deck.request_recovery(self)
	_recovery_slot = slot
	_recovery = Recovery.JOIN if slot >= 0 else Recovery.WAITING
	# La primera es la que empieza la maniobra —mete morro y sale—; de la segunda
	# en adelante se corrige el rumbo sin volver a empezar. Ver `steer_to`.
	pilot.set_target(_leg_point())


## Le tocó el turno. Lo llama la cubierta cuando queda libre.
func recovery_granted(slot: int) -> void:
	if _recovery == Recovery.NONE:
		return
	_recovery_slot = slot
	if _recovery == Recovery.WAITING:
		_recovery = Recovery.JOIN


## Si está volviendo a esa cubierta. Lo pregunta el HUD para contarlo.
func is_recovering_to(deck: FlightDeck) -> bool:
	return _recovery != Recovery.NONE and _recovery_deck == deck


## Deja de volver. Suelta la plaza que tuviera reservada: sin esto, un aparato al
## que el jugador desvía a mitad de vuelta deja su reserva puesta y la cubierta
## se va llenando de plazas que no ocupa nadie.
func _abort_recovery() -> void:
	if _recovery == Recovery.NONE:
		return
	_recovery = Recovery.NONE
	_recovery_slot = -1
	pilot.locked_heading = NAN
	if is_instance_valid(_recovery_deck):
		_recovery_deck.cancel_recovery(get_instance_id())
	_recovery_deck = null


## El punto del tramo en curso, **recalculado contra el buque cada fotograma**.
##
## Un punto capturado al empezar deja de ser su sitio en cuanto el barco avanza.
## Persiguiendo el punto vivo, el aparato iguala la marcha del buque solo: eso es
## lo que quiere decir sincronizar velocidad, y no hace falta programarlo aparte.
func _leg_point() -> Vector2:
	match _recovery:
		Recovery.WAITING, Recovery.JOIN:
			return _recovery_deck.join_point()
		Recovery.ALONGSIDE:
			return _recovery_deck.abeam_point(_recovery_slot)
		_:
			return _recovery_deck.spot_point(_recovery_slot)


## Lleva la maniobra. Un tramo por fotograma: mira si el de ahora está hecho y
## pasa al siguiente.
##
## Los tramos se cierran con un **pestillo** —una vez pasado, no se vuelve— por
## lo mismo que la lancha al atracar: una condición viva se cumple de camino, y
## el aparato se re-apuntaría a un destino que ya tiene al lado.
func _work_the_recovery() -> void:
	if _recovery == Recovery.NONE:
		return
	if not is_instance_valid(_recovery_deck):
		_abort_recovery()
		return
	var here := global_position
	var point := _leg_point()
	match _recovery:
		Recovery.WAITING:
			# Esperando turno por popa. No hay tramo que cerrar: se queda ahí
			# hasta que la cubierta avise.
			pilot.steer_to(point)
		Recovery.JOIN:
			# Todavía de viaje: el morro va a donde va, como en cualquier
			# desplazamiento.
			pilot.locked_heading = NAN
			pilot.steer_to(point)
			if here.distance_to(point) <= _recovery_deck.leg_radius:
				_recovery = Recovery.ALONGSIDE
		Recovery.ALONGSIDE:
			# Desde aquí y hasta posarse, **paralelo al buque**. Sube por el
			# costado de lado o de morro según le pille, pero mirando a donde
			# mira el barco.
			pilot.locked_heading = _recovery_deck.bow_heading()
			pilot.steer_to(point)
			if here.distance_to(point) <= _recovery_deck.leg_radius:
				_recovery = Recovery.CROSS
		Recovery.CROSS:
			pilot.locked_heading = _recovery_deck.bow_heading()
			pilot.steer_to(point)
			# El único tramo que pide puntería: debajo hay una plaza de cubierta
			# y no un punto del mar. Las dos condiciones, sitio y quietud.
			if here.distance_to(point) <= pilot.arrive_radius \
					and pilot.velocity.length() <= touchdown_speed:
				_touch_down()
		_:
			pass


## Toca cubierta: deja de volar y pasa a ser carga del barco.
##
## El orden importa. Primero se sube a bordo —reparentado y colocado sobre la
## plaza— y después se posa, para que la bajada ocurra ya en coordenadas de
## cubierta. Al revés, el barco se le escaparía por debajo mientras baja.
func _touch_down() -> void:
	_recovery = Recovery.SETTLING
	pilot.locked_heading = NAN
	# En cubierta no se dispara. Es el espejo de [method _on_took_off], y hace
	# falta por lo mismo: un cañón abriendo fuego desde aquí le tira a la
	# superestructura.
	weapons.set_active(false)
	_recovery_deck.take_aboard(self, _recovery_slot)
	pilot.land()


## Ya está posado y parado. A partir de aquí manda la cubierta: lo lleva a su
## ascensor, lo baja y lo devuelve al pañol.
func _on_landed() -> void:
	if _recovery != Recovery.SETTLING or not is_instance_valid(_recovery_deck):
		return
	var deck := _recovery_deck
	var slot := _recovery_slot
	_recovery = Recovery.NONE
	_recovery_deck = null
	_recovery_slot = -1
	deck.stow(self, slot)
