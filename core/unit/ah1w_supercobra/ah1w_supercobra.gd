extends Unit

## Qué ES el SuperCobra: identidad y cómo recibe órdenes. No pilota — de eso se
## encarga `HelicopterController`.
##
## Es mucho más corto que el Harrier y no por estar a medias: **un helicóptero no
## necesita comportamientos**. El avión los tiene porque no puede parar, así que
## hay que inventarle qué hacer cuando no hay nada que hacer —dar vueltas— y cómo
## acercarse a un blanco sin poder frenar —la pasada—. Aquí no: se le manda un
## punto, va, y se queda. Ir y esperar son lo mismo.
##
## Sin patrón de espera a propósito. Un helicóptero en su sitio ya está
## esperando.
##
## **Atacar tampoco es un comportamiento**, por lo mismo. El avión necesita la
## pasada porque no puede parar; aquí la maniobra de tiro es plantarse a la
## distancia que pida el arma con el morro puesto, y eso es un destino más. Lo
## único que hay que decidir aquí es **cuál** es esa distancia, porque depende
## del arma y el piloto no sabe de armas.

signal order_fulfilled
## Dejó la cubierta. Lo reemite el piloto; se anuncia desde aquí porque quien
## escucha es el barco, y el barco habla con la unidad, no con sus tripas.
signal took_off

## Qué fracción del alcance del arma se deja como distancia de tiro.
##
## No se pega al máximo: ahí la puntería del cañón está en su peor momento y
## cualquier movimiento del blanco lo saca de alcance. Tampoco se mete encima —
## acercarse más no mejora lo bastante como para pagar el fuego que se come.
@export_range(0.1, 1.0, 0.05) var standoff_fraction: float = 0.8

@onready var pilot: HelicopterController = $HelicopterController
@onready var weapons: WeaponSystem = $WeaponSystem


func _ready() -> void:
	super._ready()
	add_to_group("unit_air")
	pilot.target_reached.connect(func() -> void: order_fulfilled.emit())
	pilot.took_off.connect(_on_took_off)
	# Un solo sitio donde se traduce "a quién ataco" a maniobra, venga de una
	# orden, de una orden de movimiento que la cancela o de que el blanco murió.
	attack_target_changed.connect(_on_attack_target_changed)
	# El arma manda sobre la colocación: cambiarla en pleno ataque cambia a qué
	# distancia hay que quedarse.
	active_weapon_changed.connect(_on_active_weapon_changed)
	# En cubierta no se dispara, aunque ya venga con el blanco apuntado desde el
	# hangar.
	weapons.set_active(false)


## Se despega del suelo. Aquí es donde entra en combate y no en `start_flight`:
## el barco le cede el control **con el aparato todavía posado**, y un cañón
## abriendo fuego desde la cubierta le tiraría a la superestructura.
func _on_took_off() -> void:
	weapons.set_active(true)
	took_off.emit()


## El rumbo real, no la rotación del nodo: el arte apunta a +Y, así que la
## rotación lleva un desfase que el armamento no debe heredar.
func get_facing() -> float:
	return pilot.heading


func get_velocity() -> Vector2:
	return pilot.velocity


## Cuánto falta para que llegue lo que tenga en el aire. Se pregunta **acotado a
## su blanco**: con un misil todavía volando, cambiar de objetivo le pasaría al
## nuevo la cuenta atrás del anterior, y su marca se cerraría contra un impacto
## que va a ocurrir en otro sitio.
func get_time_to_impact() -> float:
	return weapons.time_to_impact(attack_target)


## A dónde va. Cuando llega deja de ir a ninguna parte: quedarse en el sitio no
## es una maniobra, es el reposo de este aparato.
func get_move_destination() -> Variant:
	return pilot.target if pilot.has_target else null


## El barco le cede el control **con el aparato todavía en cubierta**, al
## contrario que el avión, al que suelta ya volando. Aquí el despegue es suyo:
## sale cuando el jugador le dé un sitio a donde ir.
##
## `orbit_center` se ignora — no hay circuito de espera que montar alrededor del
## barco. Se acepta el argumento porque es lo que la cubierta llama a todo lo que
## despega, y no tiene por qué saber qué está soltando.
func start_flight(_orbit_center: Node2D) -> void:
	pilot.enable()
	# Si le apuntaron un blanco mientras el barco lo colocaba, la orden vale:
	# aquí es donde se convierte en maniobra, que es cuando ya hay piloto con el
	# que hacerla. Anotarla antes y montarla ahora es el orden que pide la
	# cubierta.
	if is_instance_valid(attack_target):
		receive_attack_order(attack_target)


func receive_move_order(target: Vector2) -> void:
	super.receive_move_order(target)
	pilot.set_target(target)


## Cambió a quién le tira, y aquí es donde eso se convierte en maniobra. No hay
## `receive_attack_order` que sobrescribir: la orden sólo anota a quién, y por
## este mismo aviso pasan también el ataque que termina porque el blanco murió y
## el que se cancela porque el jugador mandó al aparato a otro sitio.
func _on_attack_target_changed(target: Unit) -> void:
	if not is_instance_valid(target):
		pilot.stop_attack()
		return
	pilot.attack(target, _firing_distance(target))


func _on_active_weapon_changed(_weapon: WeaponType) -> void:
	if is_instance_valid(attack_target):
		pilot.set_hold_distance(_firing_distance(attack_target))


## A qué distancia se planta a tirarle. Sale del arma que lleve puesta, que es
## lo que quería decir "se acerca según con qué vaya armado".
##
## **Sin nada con lo que dispararle se queda donde está**, con el morro puesto:
## meterse en el alcance de algo a lo que no puedes hacer nada es sólo ponerse a
## tiro. No es negarse a la orden —el blanco queda marcado y el HUD lo dice—,
## es no gastar el aparato en un viaje que no sirve.
func _firing_distance(target: Unit) -> float:
	var weapon := active_weapon
	var here := global_position.distance_to(target.global_position)
	if weapon == null or not has_ammo(weapon):
		return here
	var domain := target.get_domain()
	if not weapon.can_engage_domain(domain):
		return here
	var reach := weapon.max_range_against(domain)
	# El mínimo del arma no es una preferencia sino física: por dentro de él no
	# se puede tirar, así que manda sobre la fracción.
	return maxf(weapon.min_range_against(domain), reach * standoff_fraction)


## Se quedó sin objetivo porque murió. Nadie más lo vigila: el piloto suelta la
## referencia para no apuntar a un fantasma, pero `attack_target` es de la unidad
## y hay que soltarlo aquí, o el HUD seguiría diciendo que está atacando.
func _physics_process(_delta: float) -> void:
	if attack_target == null:
		return
	if not is_instance_valid(attack_target) or not attack_target.is_alive():
		set_attack_target(null)
