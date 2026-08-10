extends Projectile
class_name BallisticBomb

## Bomba tonta retardada — la Mk-82 y las que vengan detrás. **No guía, no
## corrige y no sabe dónde está el blanco.** Se desprende con la velocidad que
## llevaba el avión, abre el freno de cola, y cae donde la deje la inercia.
##
## Hermana de `GlideBomb`, no subclase suya: comparten el "no tiene motor, se
## desprende y cae", pero la planeadora **manda sobre su rumbo** con las aletas y
## ésta no manda sobre nada. Meterlas en la misma clase con un `if` obligaría a
## arrastrar guiado, espoleta de proximidad y punto de apuntado por un camino que
## no los usa jamás.
##
## Vuela en dos tiempos:
##   1. Separación — cae del pilón con el freno todavía cerrado, casi sin frenar.
##      Son unas décimas, y es lo que la aleja del avión antes de plantarse.
##   2. Retardada — el freno de cola abre y la bomba frena de golpe. Deja de
##      seguir al avión y se queda atrás, que es exactamente para lo que existe
##      un freno: que quien la soltó no vuele hacia su propia explosión.
##
## **De dónde sale su alcance.** No hay ningún parámetro que diga "llega a X px":
## llega hasta donde la lleve su velocidad mientras dure `fall_time`. Soltarla
## pronto la deja corta y soltarla tarde la pasa de largo, y las dos cosas salen
## de la geometría, no de un dado. Eso es lo que hace tonta a una bomba tonta, y
## por eso el `max_range` del arma es "desde dónde hay que soltarla", no un muro.
##
## **La dispersión vive aquí y no en el arma.** `WeaponType.salvo_spread` reparte
## el punto de APUNTADO, y esto no apunta a nada. Lo que varía de una bomba a
## otra es cómo se desprende: sale un pelo torcida y frena un pelo distinto. De
## ahí sale que una ristra bata un área en vez de dejar seis agujeros en fila.

@export_group("Suelta")
## Cuánto tarda el freno de cola en abrir. Mientras, la bomba va casi con la
## velocidad del avión: es el rato en el que se separa de él.
@export var separation_time: float = 0.25
## Cuánto frena antes de abrir el freno. Bajo a propósito — todavía no hay nada
## desplegado que la frene.
@export var separation_drag: float = 0.35
## Cuánto frena con el freno abierto, por segundo. Es el número que decide cuánto
## se queda atrás respecto del avión.
@export var drag: float = 1.6
## Velocidad a la que acaba cayendo, con el freno abierto y ya sin inercia.
@export var terminal_speed: float = 45.0
## Segundos desde la suelta hasta tocar suelo. **Ésta es su altura**, igual que
## en la planeadora, y de aquí sale su alcance: lo que recorra mientras cae.
@export var fall_time: float = 3.0

@export_group("Dispersión")
## Cuánto puede salir torcida, en grados. No es puntería del avión: es que una
## bomba se desprende como se desprende. Reparte la ristra a lo ancho.
@export var wander_deg: float = 3.0
## Cuánto puede variar su caída, en tanto por uno. Reparte la ristra a lo largo:
## unas se plantan antes y otras siguen un poco más.
@export_range(0.0, 0.5, 0.01) var fall_spread: float = 0.09

@export_group("Arte")
## Grados a sumar al rumbo para orientar el dibujo, igual que en el avión, el
## misil y las trazadoras: el arte de este proyecto apunta a +Y, de ahí el −90.
##
## Con +90 la bomba sale girada 180°: vuela de culo y **el freno se despliega
## por delante**, que es justo lo contrario de lo que es. La cola va detrás.
@export var sprite_offset_deg: float = -90.0
## La cola abriéndose. Se reproduce una vez al desprenderse y se queda en el
## último frame: el freno no se vuelve a cerrar.
@export var deploy_anim: StringName = &"drop"
@export var body_path: NodePath = ^"Body"

var _heading: float = 0.0
var _speed: float = 0.0
var _t: float = 0.0
## Su caída, ya con lo suyo sumado. `fall_time` es el de diseño; éste es el de
## esta bomba en concreto.
var _falls_for: float = 0.0
var _braking := false
var _body: AnimatedSprite2D


func _ready() -> void:
	_body = get_node_or_null(body_path) as AnimatedSprite2D
	set_physics_process(false)


func get_speed() -> float:
	return _speed


## Se desprende. Toma el rumbo y la velocidad del avión — no se empuja a sí
## misma, que es la diferencia con un misil — y les suma su parte de dispersión.
##
## `aim_offset` llega y **se ignora a propósito**: es el desvío de un punto de
## apuntado, y esto no apunta. Ignorarlo aquí es la forma de decir que una bomba
## tonta no tiene puntería que dispersar.
func launch(shooter: Unit, muzzle: Node2D, at: Unit, weapon: WeaponType,
		aim_offset: Vector2 = Vector2.ZERO) -> void:
	super(shooter, muzzle, at, weapon, aim_offset)
	_heading = shooter.get_facing() + deg_to_rad(randf_range(-wander_deg, wander_deg))
	_speed = shooter.get_velocity().length()
	_falls_for = fall_time * (1.0 + randf_range(-fall_spread, fall_spread))
	rotation = _heading + deg_to_rad(sprite_offset_deg)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	_t += delta

	if _t >= separation_time and not _braking:
		_open_the_brake()

	# Frenado exponencial y no lineal: una bomba retardada pierde de golpe casi
	# toda la velocidad que traía y luego baja despacio hasta la suya. Restado
	# a plazos fijos se quedaría quieta de repente, que es otra cosa.
	var rate := drag if _braking else separation_drag
	_speed = terminal_speed + (_speed - terminal_speed) * exp(-rate * delta)
	global_position += Vector2.RIGHT.rotated(_heading) * _speed * delta

	# El único final que tiene. No hay espoleta de proximidad ni impacto directo:
	# no sabe dónde está el blanco, así que no puede acertarle a propósito. Toca
	# suelo cuando se le acaba la altura y hace daño a lo que haya debajo.
	if _t >= _falls_for:
		detonate()


func _open_the_brake() -> void:
	_braking = true
	if _body != null:
		_body.play(deploy_anim)
