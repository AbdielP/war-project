extends Unit

## Qué ES el Tunguska: una batería antiaérea que se defiende sola.
##
## No pilota ni apunta — de eso se encargan `TurretTracker` y `WeaponSystem`,
## que cuelgan de esta misma escena. Aquí sólo se atan los dos cabos que ninguno
## de ellos puede atar por su cuenta:
##
##   1. **Lo que el radar engancha es a quien se dispara.** La torreta sabe a
##      quién sigue y el armamento sabe cuándo puede tirar, pero ninguno conoce
##      al otro. Este es el único sitio donde eso se decide.
##   2. **Hacia dónde mira la unidad es hacia dónde miran los cañones**, no
##      hacia dónde mira el casco. Sin esto el armamento creería estar apuntando
##      al frente del vehículo y no dispararía nunca — o peor, dispararía de
##      lado.
##
## Se defiende sola y no recibe órdenes: es del otro bando.

@onready var turret: TurretTracker = $Turret
@onready var weapons: WeaponSystem = $WeaponSystem


func _ready() -> void:
	super._ready()
	turret.target_acquired.connect(set_attack_target)
	# `bind` porque la señal no lleva nada y `set_attack_target` pide a quién:
	# perderlo es dejar de apuntar a nadie.
	turret.target_lost.connect(set_attack_target.bind(null))


## Hacia dónde sale el fuego: la línea de los cañones, que giran solos. El casco
## puede estar mirando a cualquier otro lado y da igual.
##
## Lo usan tanto `WeaponSystem`, para saber si el blanco está en el cono, como
## los efectos, para saber hacia dónde salen el fogonazo y las trazadoras.
func get_facing() -> float:
	return turret.get_facing()
