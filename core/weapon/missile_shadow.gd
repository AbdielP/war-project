extends AnimatedSprite2D
class_name MissileShadow

## Sombra del misil en el suelo. No es una animación que se reproduzca: es un
## indicador de altura, y el frame lo decide lo que le queda al misil para
## llegar al blanco. Por eso la sombra se junta con él justo en el impacto,
## venga a la velocidad que venga y desde donde venga.
##
## Un temporizador no valdría: el misil lleva espoleta de proximidad, así que
## no sabe de antemano cuándo va a explotar. La distancia sí la sabe siempre.
##
## Como el fuego y la estela, este nodo escucha al misil; el misil no sabe que
## existe.

## Distancia al blanco a la que empieza a picar. Más lejos que esto la sombra
## se queda en el primer frame: el misil va alto y todavía no baja.
@export var descent_px: float = 120.0

## A qué distancia del blanco se considera que la sombra ya tocó el suelo.
##
## No es cero, y eso importa: el misil explota por proximidad antes de llegar a
## tocar nada (`proximity_radius`, 12 px). Contando hasta cero, el último frame
## —la sombra pegada al misil, que es el remate del efecto— no se vería nunca.
@export var ground_px: float = 12.0

## Cuánto se separa la sombra hacia abajo cuando el misil va alto.
##
## El arte ya trae pintado el alejamiento horizontal —la barra viaja de la
## columna 14 a la 8 según baja—, pero le falta la otra mitad de la diagonal:
## con el sol al noroeste, cuanto más alto vuela más se va la sombra abajo Y a
## la derecha, no sólo a la derecha. No cabía en el tile: el cuerpo del misil
## ya llega a la fila 13 y sólo quedan dos libres. Puesto desde aquí no está
## atado al tile de 16 px.
##
## Va en el espacio del misil, no del mundo: la sombra gira con él, misma
## convención que el resto del arte del juego (los sprites se dibujan mirando
## al sur con su sombra abajo a la derecha, y al rotar la sombra rota también).
@export var altitude_drop_px: float = 5.0

var _source: Node = null


func _ready() -> void:
	var source := get_parent()
	if not source.has_method(&"get_distance_to_aim"):
		set_physics_process(false)
		return
	_source = source


func _physics_process(_delta: float) -> void:
	# 1 = alto y lejos, 0 = pegada al suelo encima del blanco.
	var span := maxf(descent_px - ground_px, 1.0)
	var altitude := clampf((_source.get_distance_to_aim() - ground_px) / span, 0.0, 1.0)
	frame = int(round((1.0 - altitude) * float(sprite_frames.get_frame_count(animation) - 1)))
	# El desplazamiento se encoge con la misma cuenta que el dibujo. Si se
	# quedara fijo, al impactar la sombra estaría 5 px por debajo del misil en
	# vez de justo debajo.
	position.y = altitude_drop_px * altitude
