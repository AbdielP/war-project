extends Node
class_name PlaneController

## Piloto. Decide CÓMO vuela el avión: velocidad, viraje, inercia.
## No sabe a dónde va — eso lo decide quien llame a set_target().
## Mueve al nodo padre. Arranca inactivo: el portaaviones le cede el
## control con enable() cuando el avión ya está en el aire.

signal target_reached
signal committed(side: int)

@export_group("Velocidad")
## Velocidad de pérdida, y también la de crucero cuando no hay nada que hacer:
## el avión nunca baja de aquí, y es a lo que vuela mientras espera. Es la
## velocidad a la que deja la cubierta al despegar.
@export var min_speed: float = 70.0
## A lo que vuela cuando tiene una orden que cumplir: ir a un sitio o entrar
## contra un blanco. Nunca se usa sin motivo.
@export var max_speed: float = 150.0
## Cuánto gana o pierde por segundo al pasar de una a otra. Es lo único que
## separa un cambio de régimen creíble de un tirón: bajo = el avión tarda en
## coger y en soltar velocidad, que es lo que hace un avión.
@export var acceleration: float = 90.0
## Suelta gas al maniobrar: vira más cerrado a costa de velocidad. Sólo tiene
## efecto yendo a máxima — a mínima ya no hay gas que soltar.
@export var brake_in_turns: bool = true

@export_group("Giro")
## Ancho del círculo que traza el avión virando a tope, en px. ESTE es el
## parámetro del viraje y de aquí sale todo lo demás: un avión no elige cuántos
## grados gira por segundo, elige cuánto se inclina, y eso le da un círculo de
## un ancho fijo que recorre más despacio si va más lento.
##
## Antes estaba al revés — el parámetro eran los grados por segundo y el radio
## salía de dividir — y eso hacía que volar más lento cerrara el viraje, que es
## justo lo contrario de lo que pasa de verdad. Un avión al ralentí no pivota:
## tarda lo mismo en cruzar el mismo círculo, sólo que más despacio.
@export var turn_radius: float = 130.0
## Ganancia de la corrección fina cuando ya va casi alineado.
@export var fine_gain: float = 2.0
## Cuánto tarda en meterse en el viraje. No se alabea de golpe: hay un momento
## de entrada antes de que el giro sea el pedido, y otro de salida al nivelar.
## Bajo = avión pesado, tarda en tumbarse.
@export var turn_inertia: float = 2.0
## Retraso del vector de velocidad frente al morro: da sensación de derrape.
@export var velocity_align: float = 4.5

@export_group("Compromiso de viraje")
## Una vez decidido el lado del viraje, no se replantea hasta bajar de este
## error. Es lo que evita que el avión amague a un lado y al otro.
@export var release_deg: float = 22.0
## Sólo elige lado de nuevo si el error supera esto.
@export var reengage_deg: float = 45.0
## Margen del círculo muerto: si el destino cae dentro del radio de giro,
## ese lado es imposible y se toma el contrario.
@export var dead_circle_hysteresis: float = 1.12

@export_group("Navegación")
## Distancia a la que se da por alcanzado un destino.
@export var arrive_radius: float = 40.0
## Da por alcanzado el destino si ya lo rebasó estando dentro de su radio de
## giro. Sin esto el avión, que no puede frenar, da un bucle completo para
## volver a un punto que ya dejó atrás.
@export var flyby_capture: bool = true
## Grados a sumar al rumbo para orientar el sprite. El arte del Harrier
## apunta hacia abajo (+Y local), por eso -90.
@export var sprite_offset_deg: float = -90.0

@export_group("Alabeo")
## AnimatedSprite2D opcional con 5 frames: 0 = alabeo fuerte a la izquierda,
## 2 = nivelado, 4 = alabeo fuerte a la derecha. Vacío = sin alabeo.
@export var bank_sprite_path: NodePath

var heading: float = 0.0
var speed: float = 0.0
var turn_rate: float = 0.0
var velocity: Vector2 = Vector2.ZERO
var target: Vector2 = Vector2.ZERO
var has_target: bool = false
## ¿Está metiendo gas? Lo pone quien manda al avión, no el piloto: aquí sólo se
## obedece. Es un interruptor y no un número porque sólo hay dos regímenes —
## `min_speed` y `max_speed` — y el avión ya sabe cuáles son los suyos. Antes
## esto era un techo en px/s que cada comportamiento fijaba a mano, y acabó
## como tenía que acabar: alguien puso el "despacio" del ataque en el mismo
## valor que la máxima y el avión nunca frenó.
##
## Empieza apagado. Lo normal en un avión sin órdenes es ir despacio.
var cruising: bool = false

var _body: Node2D
var _bank_sprite: AnimatedSprite2D
var _lock: int = 0  # 0 libre, -1 izquierda, +1 derecha


func _ready() -> void:
	_body = get_parent() as Node2D
	if not bank_sprite_path.is_empty():
		_bank_sprite = get_node_or_null(bank_sprite_path) as AnimatedSprite2D
	set_physics_process(false)


## Toma el control del avión. El rumbo inicial se deduce de cómo quedó
## orientado tras el despegue, y la velocidad es la mínima: la cubierta lo
## acelera hasta ahí y lo suelta justo a esa velocidad, así que recogerlo a
## cualquier otra sería un tirón en el momento del relevo.
func enable() -> void:
	if _body == null:
		return
	heading = wrapf(_body.global_rotation - deg_to_rad(sprite_offset_deg), -PI, PI)
	speed = min_speed
	velocity = Vector2.RIGHT.rotated(heading) * speed
	turn_rate = 0.0
	_lock = 0
	cruising = false
	set_physics_process(true)


func disable() -> void:
	set_physics_process(false)
	has_target = false
	_lock = 0
	cruising = false


## Meter o soltar gas. No cambia la velocidad de golpe: marca a cuál de las dos
## se dirige, y `acceleration` se encarga de llevarlo allí.
func set_cruising(value: bool) -> void:
	cruising = value


## Destino nuevo: vuelve a decidir el lado del viraje desde cero.
func set_target(world_pos: Vector2) -> void:
	target = world_pos
	has_target = true
	_lock = 0


## Corrige el destino sin replantear el viraje en curso. Para objetivos que
## se mueven (un barco navegando, un líder de formación).
func update_target(world_pos: Vector2) -> void:
	target = world_pos
	has_target = true


func clear_target() -> void:
	has_target = false
	_lock = 0


## El círculo que traza virando a tope. Es un dato fijo del avión: no cambia
## porque vaya más rápido o más lento.
func min_turn_radius() -> float:
	return maxf(turn_radius, 1.0)


## Grados por segundo disponibles ahora mismo. Sale de recorrer el círculo a la
## velocidad que lleve: despacio da la misma vuelta, sólo que tardando más.
func current_turn_rate() -> float:
	return speed / min_turn_radius()


## Virando hacia ese lado el avión describe un círculo. Si el destino cae
## dentro de ese círculo, es inalcanzable por ahí: seguiría dando vueltas
## a su alrededor sin poder cerrar nunca.
func _side_is_blocked(side: int, radius: float) -> bool:
	var center := _body.global_position \
		+ Vector2.RIGHT.rotated(heading + side * PI * 0.5) * radius
	return center.distance_to(target) < radius * dead_circle_hysteresis


func _physics_process(delta: float) -> void:
	var omega := current_turn_rate()
	var cmd := 0.0
	var abs_err := 0.0

	if has_target:
		var to_target := target - _body.global_position
		var dist := to_target.length()
		var reached := dist < arrive_radius
		if not reached and flyby_capture and dist < maxf(arrive_radius, min_turn_radius()):
			# Ya lo dejó atrás: volver costaría un bucle cerrado.
			reached = to_target.dot(Vector2.RIGHT.rotated(heading)) < 0.0
		if reached:
			has_target = false
			_lock = 0
			target_reached.emit()
		else:
			var err := angle_difference(heading, to_target.angle())
			abs_err = absf(err)
			var radius := min_turn_radius()

			var want_side := 1 if err >= 0.0 else -1

			if _side_is_blocked(want_side, radius):
				# El destino cae dentro del círculo de giro: virar hacia él
				# sólo daría vueltas a su alrededor. Nivela y sale recto
				# hasta que la geometría permita enfilarlo.
				_lock = 0
				cmd = 0.0
			else:
				# Elige el lado UNA vez, y sólo si el error es grande.
				if _lock == 0 and abs_err > deg_to_rad(reengage_deg):
					_lock = want_side
					committed.emit(want_side)
				# Suelta el compromiso sólo cuando ya está casi alineado.
				if _lock != 0 and abs_err < deg_to_rad(release_deg):
					_lock = 0
				cmd = float(_lock) * omega if _lock != 0 else clampf(err * fine_gain, -omega, omega)

	turn_rate = lerpf(turn_rate, cmd, minf(1.0, turn_inertia * delta))
	heading = wrapf(heading + turn_rate * delta, -PI, PI)

	# Sin gas se vuela a la mínima. Es el estado normal de un avión sin nada
	# que hacer, no un castigo: la máxima cuesta combustible y sólo se pide
	# cuando hay a dónde ir.
	var wanted := max_speed if cruising else min_speed
	if cruising and brake_in_turns and has_target:
		wanted = lerpf(min_speed, max_speed, clampf(1.0 - abs_err / 2.2, 0.0, 1.0))
	# `move_toward` es lo que impide el tirón: la velocidad no salta al régimen
	# nuevo, se va hacia él a `acceleration` por segundo. Subir ese número es
	# exactamente lo que vuelve brusco el cambio.
	speed = clampf(move_toward(speed, wanted, acceleration * delta), min_speed, max_speed)

	var thrust := Vector2.RIGHT.rotated(heading) * speed
	velocity = velocity.lerp(thrust, minf(1.0, velocity_align * delta))
	_body.global_position += velocity * delta
	_body.global_rotation = heading + deg_to_rad(sprite_offset_deg)

	if _bank_sprite != null:
		_bank_sprite.frame = int(round((clampf(turn_rate / omega, -1.0, 1.0) + 1.0) * 2.0))
