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
	turret.target_acquired.connect(_on_locked_on)
	# `bind` porque la señal no lleva nada y `set_attack_target` pide a quién:
	# perderlo es dejar de apuntar a nadie.
	turret.target_lost.connect(set_attack_target.bind(null))
	weapons.firing_started.connect(_on_opened_fire)


## Enganchó a alguien: se le apunta y **se le avisa**.
##
## El aviso va del agresor a la víctima y no al revés porque el que apunta es el
## único que sabe a quién. La víctima decide qué hacer con la noticia — hoy sale
## por el parte de eventos, mañana por la radio.
func _on_locked_on(unit: Unit) -> void:
	set_attack_target(unit)
	unit.notify_tracked(self)


func _on_opened_fire() -> void:
	if is_instance_valid(attack_target):
		attack_target.notify_fired_upon(self)


## Hacia dónde sale el fuego: la línea de los cañones, que giran solos. El casco
## puede estar mirando a cualquier otro lado y da igual.
##
## Lo usan tanto `WeaponSystem`, para saber si el blanco está en el cono, como
## los efectos, para saber hacia dónde salen el fogonazo y las trazadoras.
func get_facing() -> float:
	return turret.get_facing()
