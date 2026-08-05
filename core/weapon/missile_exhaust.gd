extends AnimatedSprite2D
class_name MissileExhaust

## El fuego del propulsor. Cuelga de la cola del misil y sigue sus fases de
## vuelo escuchando sus señales — el misil no sabe que existe.
##
## Es el enganche que `GuidedMissile.motor_ignited` / `fuel_spent` dejaron
## abierto: la simulación decide cuándo hay empuje, esto sólo lo enseña. Por eso
## vive en un nodo aparte y no dentro del misil, igual que el humo y la
## explosión cuando existan.
##
## Tres animaciones sobre la misma tira, porque el motor tiene tres momentos y
## se leen distinto: prende, arde, se apaga. `burn` es la única que cicla; las
## otras dos se disparan una vez y ceden el paso.
##
## Colocación: `position` mide desde el centro del misil hasta la cola. Con el
## arte actual (Maverick de 16x16, morro hacia +Y, último píxel en la fila 2) el
## valor es (0, -13). Si cambia el sprite del misil, este número es lo único que
## hay que volver a tocar.

## Prendiendo. Se dispara con `motor_ignited`.
@export var ignite_anim: StringName = &"ignite"
## Ardiendo. Cicla hasta que se acabe el combustible.
@export var burn_anim: StringName = &"burn"
## Apagándose. Se dispara con `fuel_spent` y deja el nodo invisible.
@export var shutdown_anim: StringName = &"shutdown"

var _burning := false


func _ready() -> void:
	visible = false
	animation_finished.connect(_on_animation_finished)

	# Duck-typing, igual que en el resto del proyecto: cualquier proyectil que
	# emita estas dos señales puede llevar escape sin heredar de nada concreto.
	var source: Node = get_parent()
	if source.has_signal(&"motor_ignited"):
		source.connect(&"motor_ignited", _on_motor_ignited)
	if source.has_signal(&"fuel_spent"):
		source.connect(&"fuel_spent", _on_fuel_spent)


func _on_motor_ignited() -> void:
	_burning = true
	visible = true
	play(ignite_anim)


## Se acabó el empuje. Si aún no había terminado de prender, se corta igual: el
## misil ya está planeando y una llama creciendo sería mentira.
func _on_fuel_spent() -> void:
	_burning = false
	play(shutdown_anim)


func _on_animation_finished() -> void:
	if animation == ignite_anim and _burning:
		play(burn_anim)
	elif animation == shutdown_anim:
		visible = false
