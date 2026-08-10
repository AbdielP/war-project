extends Sprite2D
class_name Casing

## Un casquillo saliendo por el eyector. Sale de lado, da vueltas, frena y se
## apaga en el suelo.
##
## No es munición y no hace nada: **la bala ya salió por el otro extremo**. Esto
## es lo que sobra, y sólo está para que se vea que el arma está trabajando.
##
## Va por calibre y no por unidad — `casing_30mm`, `casing_25mm` — porque el
## casquillo es del cartucho, no del vehículo: el mismo 25 mm vale para cualquier
## arma que lo dispare.
##
## Vive en el mundo y no colgado del arma, como el humo y las trazadoras: una vez
## fuera ya no le pertenece, y si el que disparó se va o muere, lo que expulsó se
## queda en el suelo donde cayó.

## Píxeles por segundo al salir. Es un trozo de latón escupido a un lado, no un
## proyectil: se queda cerca.
@export var eject_speed: float = 70.0
## Cuánto varía esa velocidad, en tanto por uno. Sin esto todos los casquillos
## caen a la misma distancia y se ve una fila, no un reguero.
@export_range(0.0, 1.0, 0.05) var speed_spread: float = 0.35
## Cuánto frena por segundo, en tanto por uno de su velocidad. Alto: el latón no
## rueda, cae y se queda.
@export var drag: float = 6.0
## Vueltas por segundo mientras cae, en grados. Se elige el sentido al azar.
@export var spin_deg: float = 720.0
## Segundos hasta desaparecer. Los últimos se va en un fundido.
@export var lifetime: float = 0.9
## Qué fracción final de la vida se pasa desvaneciéndose.
@export_range(0.0, 1.0, 0.05) var fade_fraction: float = 0.35

var _velocity: Vector2 = Vector2.ZERO
var _spin: float = 0.0
var _age: float = 0.0


## Lo escupe hacia `direction`, en radianes de mundo. **Ya viene resuelta**: por
## qué lado sale es del eyector del arma, no del cartucho — el mismo 30 mm sale
## por la derecha en un sitio y por la izquierda en otro.
##
## Va aparte de `_ready()` por lo mismo que en `Tracer`: el nodo entra en el
## árbol antes de que se le coloque, así que ahí todavía no sabe nada.
## `carried` es lo que se lleva del que disparó. Un casquillo que sale de un
## avión en movimiento no se queda clavado en el aire: sigue un poco hacia
## adelante y **se va quedando atrás**, porque no lleva tanta velocidad como el
## avión. Con el que dispara quieto no cambia nada.
func launch(direction: float, carried: Vector2 = Vector2.ZERO) -> void:
	var speed := eject_speed * (1.0 + randf_range(-speed_spread, speed_spread))
	_velocity = Vector2.RIGHT.rotated(direction) * speed + carried
	_spin = deg_to_rad(spin_deg) * (1.0 if randf() < 0.5 else -1.0)
	rotation = randf() * TAU


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return

	global_position += _velocity * delta
	# Frenada exponencial: pierde casi todo el impulso enseguida y luego se
	# arrastra un pelo, que es lo que hace un trozo de metal contra el suelo.
	_velocity = _velocity.lerp(Vector2.ZERO, clampf(drag * delta, 0.0, 1.0))
	# Deja de dar vueltas a la vez que deja de moverse: un casquillo quieto
	# girando en el sitio se ve como un error.
	_spin = lerpf(_spin, 0.0, clampf(drag * delta, 0.0, 1.0))
	rotation += _spin * delta

	var fade_at := lifetime * (1.0 - fade_fraction)
	if _age > fade_at and fade_fraction > 0.0:
		modulate.a = 1.0 - (_age - fade_at) / (lifetime - fade_at)
