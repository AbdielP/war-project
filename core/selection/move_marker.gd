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
## La onda **se reproduce una vez y no se repite**. Un marcador que late sin
## parar acaba pidiendo atención cada dos segundos para no decir nada nuevo; el
## dato ya lo dio al aparecer.

## La tira tiene la bandera sola en el primer fotograma y las ondas en los cinco
## siguientes, así que volver al primero al acabar es lo que deja el sitio
## marcado y la onda apagada.
const _RESTING := 0


func _ready() -> void:
	animation_finished.connect(_rest)
	hide()


## Planta la bandera en un punto y lanza la onda desde cero.
##
## Se vuelve a poner el fotograma a mano antes de arrancar: `play()` sobre una
## animación que ya terminó no rebobina, y la segunda orden se quedaría con la
## bandera puesta sin que se viera salir la onda.
func plant(where: Vector2) -> void:
	global_position = where
	frame = 0
	show()
	play()


func _rest() -> void:
	frame = _RESTING
