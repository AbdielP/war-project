extends EffectEmitter
class_name CasingEjector

## El eyector de un arma: va escupiendo casquillos mientras se dispara.
##
## Hermano de [TracerStream] — los dos siembran por cadencia, y esa cuenta la
## lleva la base. Lo único suyo es que lo que sale no va hacia adelante: sale de
## lado, y de eso se encarga cada [Casing].
##
## **No son las balas.** Igual que con las trazadoras, se echa uno de cada tantos
## disparos: un cañón de rotación vacía 50 cartuchos por segundo y dibujarlos
## todos no se sostiene ni se distingue.

## Casquillos por segundo. No es la cadencia del arma, es cada cuántos disparos
## se ve uno caer. Subirlo llena el suelo de latón.
@export var casings_per_second: float = 10.0
## Por qué lado salen, respecto a donde apunta el arma. **−90 es la izquierda de
## quien va dentro; +90, su derecha.**
##
## Cuidado con confundir eso con la izquierda del dibujo, que es la trampa en la
## que se cae mirando el sprite quieto en el editor: el arte apunta a +Y, o sea
## al sur, y **quien mira al sur tiene el este a su izquierda**. Así que la
## izquierda del piloto es el lado +X, el derecho de la imagen. Las dos
## izquierdas son lados opuestos.
##
## Es del arma y no del cartucho: el mismo calibre sale por un lado en un cañón y
## por el otro en el de al lado.
@export var eject_angle_deg: float = 90.0
## Cuánto se abre el chorro, en grados a cada lado. Sin esto salen todos por la
## misma línea y se ve un peine, no un reguero.
@export var angle_spread_deg: float = 25.0
## Qué fracción de la velocidad del que dispara se lleva el casquillo.
##
## Ni 0 ni 1. **A 1 volarían con el avión** y parecerían pegados a él; a 0 se
## quedarían clavados donde salieron, como si el avión no llevara nada de
## inercia. En medio es lo que se ve de verdad: salen acompañando y se van
## quedando atrás. Da igual en un arma que no se mueve.
@export_range(0.0, 1.0, 0.05) var inherit_velocity: float = 0.5


func _physics_process(delta: float) -> void:
	var due := _due(delta, casings_per_second)
	if due <= 0:
		return
	var heading := _emit_heading()
	var carried := _carried_velocity()
	for _i in due:
		var casing := _spawn(global_position, heading) as Casing
		if casing != null:
			# Aparte de colocarlo, como en `Tracer`: al entrar en el árbol
			# todavía no sabe hacia dónde va.
			casing.launch(_eject_direction(heading), carried)


## Lo que el casquillo se lleva del vehículo. Se pregunta a la unidad y no se
## deduce de cómo se mueve este nodo: la torreta de un antiaéreo gira, y girar no
## es desplazarse.
func _carried_velocity() -> Vector2:
	if inherit_velocity <= 0.0:
		return Vector2.ZERO
	var shooter := _shooter()
	return shooter.get_velocity() * inherit_velocity if shooter != null else Vector2.ZERO


## Hacia dónde sale el siguiente: el lado del eyector, más su pizca de azar.
func _eject_direction(heading: float) -> float:
	var spread := randf_range(-angle_spread_deg, angle_spread_deg)
	return heading + deg_to_rad(eject_angle_deg + spread)
