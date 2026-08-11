extends Node2D
class_name Decoy

## Un señuelo suelto en el aire: una nube de chaff o una bengala.
##
## No hace daño ni engaña a nadie por su cuenta. **Lo único que hace es estar
## ahí**, y que un misil se lo trague o no lo decide la geometría — si en el
## momento de mirar tiene el señuelo más centrado que al avión, se va con el
## señuelo.
##
## Por eso la contramedida sola no salva: soltarla volando recto deja el señuelo
## justo detrás del avión, los dos igual de centrados, y el buscador se queda con
## el avión. **Lo que separa los dos contactos es la maniobra.** Soltar y virar es
## una sola cosa.
##
## Vive en el mundo y no colgado del avión, como el humo y los casquillos: una
## vez fuera ya no le pertenece.

## Contra qué guía sirve. Un misil de radar no se traga una bengala.
@export var kind: Countermeasures.Kind = Countermeasures.Kind.CHAFF
## Lo que "brilla" en su mejor momento, tomando el avión como 1. Por encima de 1
## porque una nube de chaff devuelve más eco que el propio avión — si no, no
## engañaría a nada.
@export var peak_strength: float = 1.4
## Lo que tarda en abrirse del todo. **Es la pieza que hace que soltar tarde no
## sirva**: recién salido está pegado al avión y no vale como contacto aparte;
## para cuando brilla, ya se separó.
@export var bloom_time: float = 0.4
## Segundos que dura. Corto: una bengala arde y se apaga, y si durasen mucho el
## cielo se llenaría de blancos falsos permanentes.
@export var lifetime: float = 2.6
## Qué fracción final de la vida se pasa desvaneciéndose.
@export_range(0.0, 1.0, 0.05) var fade_fraction: float = 0.5
## Lo que frena por segundo, en tanto por uno de su velocidad. Alto: el señuelo
## se queda casi donde salió mientras el avión sigue, que es lo que hace que los
## dos contactos se separen.
@export var drag: float = 2.2

@export_group("Dibujo")
@export var radius: float = 2.0
@export var color: Color = Color(1.0, 0.93, 0.7)

## En qué grupo se apunta, para que los buscadores lo encuentren sin conocer a
## quien lo soltó.
const GROUP := &"decoys"

var _velocity: Vector2 = Vector2.ZERO
var _age: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)


## Lo suelta con la velocidad que llevaba el avión, para que salga acompañándolo
## y se vaya quedando atrás en vez de aparecer clavado en el aire.
func launch(carried: Vector2) -> void:
	_velocity = carried


## Cuánto brilla ahora mismo, con el avión valiendo 1. Sube mientras se abre y
## baja mientras se deshace: **fuera de esa ventana no engaña a nadie**, y por eso
## soltar en el último segundo no salva.
func strength() -> float:
	if _age < bloom_time:
		return peak_strength * (_age / maxf(bloom_time, 0.01))
	var left := 1.0 - (_age - bloom_time) / maxf(lifetime - bloom_time, 0.01)
	return peak_strength * clampf(left, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	global_position += _velocity * delta
	_velocity = _velocity.lerp(Vector2.ZERO, clampf(drag * delta, 0.0, 1.0))
	queue_redraw()


func _draw() -> void:
	var fade_at := lifetime * (1.0 - fade_fraction)
	var alpha := 1.0
	if _age > fade_at and fade_fraction > 0.0:
		alpha = 1.0 - (_age - fade_at) / (lifetime - fade_at)
	draw_circle(Vector2.ZERO, radius, Color(color, alpha))
