extends Node
class_name DogfightBehavior

## Decide A DÓNDE va el avión cuando pelea contra otro avión. Hermano de
## `AttackRunBehavior` y de `OrbitBehavior`: los tres le dan puntos al mismo
## piloto y **nunca corren a la vez**.
##
## Existe aparte porque el combate aéreo no es una pasada de ataque, y meterlos
## en el mismo sitio fue un error que se pagó: contra tierra el avión suelta el
## arma y **rompe**, porque un tanque no le persigue y quedarse encima no aporta.
## Contra un avión, romper es regalarle la iniciativa. Aquí no se rompe nunca: se
## dispara y se sigue maniobrando.
##
## **Lo que manda no es la distancia, es el ángulo.** En un duelo lo único que
## importa es quién está detrás de quién:
##
##   - Detrás de él, disparas tú.
##   - De frente, os cruzáis los dos.
##   - Delante de él, estás muerto.
##
## Y a dónde hay que ir lo dice **el arma que se lleva puesta**, no una regla
## fija. Un misil de radar entra por donde sea, así que con él se vuela derecho y
## se dispara mientras se cierra. Uno de calor o el cañón necesitan ver la
## tobera, y entonces el destino deja de ser el avión enemigo y pasa a ser **el
## punto que te pone en su cola**. Como ese punto se mueve con él, perseguirlo
## produce solo las persecuciones circulares de un dogfight — sin programar
## ninguna maniobra.
##
## De ahí sale también quién gana: el avión que vira más cerrado cierra el
## círculo por dentro y se mete detrás. El radio de giro, que ya era el parámetro
## maestro del vuelo, decide también el combate aéreo.

## El objetivo dejó de existir. Igual que en `AttackRunBehavior`, aquí ya se
## apagó solo y quien escuche decide qué hacer con el avión.
signal target_lost

@export_group("Duelo")
## A qué distancia por detrás del enemigo se pone el punto que hay que alcanzar.
## Es la posición de tiro: lo bastante cerca para disparar, lo bastante lejos
## para no chocar ni pasársele.
@export var saddle_distance: float = 120.0
## Cuánto se adelanta al movimiento del enemigo al perseguirlo, en segundos de su
## velocidad. Apuntar a donde está lo deja siempre por detrás; apuntar a donde va
## a estar es lo que permite cerrar.
@export var lead_time: float = 0.6
## Por debajo de esta distancia deja de cerrar y mantiene, para no írsele encima
## y acabar delante. Pasarse de largo es perder la posición ganada.
@export var overshoot_guard: float = 70.0

@export_group("Enlace")
@export var pilot_path: NodePath = ^"../PlaneController"

var target: Unit = null

var _pilot: PlaneController
var _body: Node2D
var _weapon: WeaponType = null


func _ready() -> void:
	_body = get_parent() as Node2D
	_pilot = get_node_or_null(pilot_path) as PlaneController
	set_physics_process(false)


## Empieza el duelo contra ese avión, con el arma que se lleve puesta.
func engage(new_target: Unit, weapon: WeaponType) -> void:
	if _pilot == null or not is_instance_valid(new_target):
		return
	target = new_target
	_weapon = weapon
	_pilot.set_target(_wanted_point())
	set_physics_process(true)


## Cambió el arma en pleno duelo: puede que ahora haga falta otra posición.
func set_weapon(weapon: WeaponType) -> void:
	_weapon = weapon


func stop() -> void:
	target = null
	set_process(false)
	set_physics_process(false)
	if _pilot != null:
		_pilot.set_cruising(false)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(target):
		target = null
		set_physics_process(false)
		_pilot.set_cruising(false)
		target_lost.emit()
		return

	# `update_target` y no `set_target`: el punto se mueve con el enemigo y hay
	# que corregir constantemente, pero replantear el viraje desde cero cada
	# frame dejaría al avión dudando en mitad del giro.
	_pilot.update_target(_wanted_point())
	# Gas siempre: en un duelo la energía es la mitad de la posición, y frenar
	# para apuntar —que es lo que se hace contra tierra— aquí es regalar el
	# ángulo. Ninguna de las armas de caza pide frenar.
	_pilot.set_cruising(true)


## A dónde hay que volar, que depende del arma:
##
##   - **Si entra por donde sea** (un misil de radar): al punto de intercepción.
##     Se vuela derecho y se dispara mientras se cierra, sin dar rodeos.
##   - **Si necesita la tobera** (calor o cañón): a la cola del enemigo.
func _wanted_point() -> Vector2:
	var lead := target.global_position + target.get_velocity() * lead_time
	if _weapon == null or not _weapon.needs_rear_aspect():
		return lead
	var tail := Vector2.RIGHT.rotated(target.get_facing() + PI) * saddle_distance
	var saddle := lead + tail
	# Ya está encima: se mantiene el rumbo del enemigo en vez de seguir cerrando,
	# o se le pasa de largo y hay que rehacer el ángulo desde cero.
	if _body.global_position.distance_to(saddle) < overshoot_guard:
		return saddle + Vector2.RIGHT.rotated(target.get_facing()) * saddle_distance
	return saddle
