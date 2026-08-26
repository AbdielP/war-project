extends AnimatedSprite2D
class_name MoveMarker

## La banderita que marca a dónde se ha mandado ir a la unidad.
##
## Antes era un círculo con una cruz trazados a mano; ahora es arte, y con arte
## se puede contar algo más que "aquí": al plantarse suelta una onda que sale del
## punto y se apaga, y lo que queda después es la bandera sola. La onda es el
## acuse de recibo —se ve dónde ha caído la orden aunque estuvieras mirando a
## otro lado— y la bandera es el recordatorio, que no parpadea ni se mueve porque
## va a estar puesta mucho rato.
##
## La onda sale **unas cuantas veces al plantar y después se calla para
## siempre**. Repetirla un par de veces la hace imposible de perder aunque
## estuvieras mirando a otro lado, que es todo lo que tiene que conseguir; latir
## sin parar sería pedir atención cada dos segundos para no decir nada nuevo.

## La tira tiene la bandera sola en el primer fotograma y las ondas en los cinco
## siguientes, así que volver al primero al acabar es lo que deja el sitio
## marcado y la onda apagada.
const _RESTING := 0

## Cuántas ondas salen por orden.
@export_range(1, 6, 1) var pulses: int = 3
## Cuánto se espera entre una onda y la siguiente, en segundos. Corto: es el
## respiro que las hace contar como tres y no como una animación larga.
@export var pulse_gap: float = 0.2

## Ondas que quedan por salir de la orden en curso.
var _left: int = 0
## Qué orden es la de ahora. Cambia con cada plantada, y sirve para que una
## espera empezada por la anterior no arranque una onda que ya no toca: entre
## dos órdenes seguidas hay menos tiempo que el que dura la tanda entera.
var _order: int = 0


func _ready() -> void:
	animation_finished.connect(_on_wave_ended)
	hide()


## Planta la bandera en un punto y lanza la tanda de ondas desde cero.
func plant(where: Vector2) -> void:
	global_position = where
	_order += 1
	_left = maxi(pulses, 1)
	show()
	_wave()


## Suelta una onda. El fotograma se pone a mano antes de arrancar: `play()` sobre
## una animación que ya terminó no rebobina, y la siguiente se quedaría con la
## bandera puesta sin que se viera salir nada.
func _wave() -> void:
	_left -= 1
	frame = 0
	play()


func _on_wave_ended() -> void:
	frame = _RESTING
	if _left <= 0:
		return
	var mine := _order
	await get_tree().create_timer(pulse_gap).timeout
	# Mientras se esperaba pudo llegar otra orden —o retirarse ésta—, y entonces
	# esta tanda ya no significa nada.
	if mine != _order or not visible:
		return
	_wave()
