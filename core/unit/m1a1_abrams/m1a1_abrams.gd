extends GroundVehicle
class_name Abrams

## Qué ES el Abrams: un casco que va a donde le mandan y una torre que mira a
## otro lado. Esa separación es el vehículo entero.
##
## Ni conduce ni apunta ni dispara — de eso van [TankController],
## [TurretTracker] y [WeaponSystem], que cuelgan de esta misma escena. Aquí sólo
## se atan los cabos que ninguno de ellos puede atar solo, que son los mismos
## tres del Tunguska más uno que él no tiene:
##
##   1. **A quien la torre engancha es a quien se dispara.**
##   2. **Hacia dónde mira la unidad es hacia dónde mira el cañón**, no el casco.
##      Sin esto el armamento creería apuntar al frente del vehículo.
##   3. **Con cuál de las dos armas tira**, que lo lleva el `WeaponSelector`.
##   4. Y el que el Tunguska no necesita: **éste recibe órdenes.** Una batería
##      que se defiende sola nunca tiene que decidir entre lo que ve y lo que le
##      mandan; un carro del jugador, sí.
##
## **La orden manda sobre lo que la torre ve por su cuenta.** Señalado un blanco,
## la torre se queda con él aunque pase otro más cerca, y el casco se acerca si
## hace falta. Suelto, vuelve a engancharse sola: la búsqueda nunca se apagó.

## El arma principal. Va en un armamento y no como arma fija —al revés que la
## ametralladora— porque **se gasta**: los tiros que lleve y no hay más hasta
## que alguien lo recargue.
##
## Exportado y no `preload`, como los misiles del Tunguska: así el valor vive en
## la escena y los círculos de alcance pueden leerlo en el editor, donde el
## armamento todavía no existe.
@export var main_gun: WeaponType
## Cuántos proyectiles lleva.
@export var main_gun_rounds: int = 40

@export_group("Acercarse")
## Hasta qué fracción del alcance se mete antes de plantarse.
##
## **El sitio bueno es un anillo, no un punto**, y de ahí que sean dos números y
## no uno: se pone en marcha cuando el blanco se sale del alcance y se para al
## llegar a esta fracción de él. Con un solo número, el carro corrige el último
## píxel eternamente contra un blanco que también se mueve.
@export_range(0.1, 1.0, 0.05) var approach_fraction: float = 0.75
## Cuánto se tiene que mover el punto al que va para replantearse el rumbo. Por
## debajo se deja como está, porque volver a dar la orden cada fotograma le
## borraría al conductor la marcha que llevaba metida.
@export var approach_slack: float = 8.0

## Estación de la que salen los tiros. No hay `HardpointRack` en la escena —un
## carro no lleva el arma colgada a la vista—, así que el nombre no dibuja nada:
## sólo lleva la cuenta de la munición.
const MAIN_STATION := &"Breech"

@export_group("Efectos")
## Lo que dura el fogonazo del cañón.
##
## **Va por tiempo y no por señal**, al revés que el de la ametralladora. Un arma
## sostenida abre y cierra fuego, así que el fogonazo tiene dos señales a las que
## engancharse; un tiro suelto no cierra nada, y sin este corte la llama se
## quedaría encendida ciclando su animación de ráfaga para siempre.
@export var main_flash_seconds: float = 0.12

@onready var turret: TurretTracker = $Turret
@onready var weapons: WeaponSystem = $WeaponSystem
@onready var selector: WeaponSelector = $WeaponSelector
@onready var main_flash: MuzzleFlash = $Turret/MainFlash

## El blanco que señaló el jugador, que no es lo mismo que el que la torre ve.
## Sólo por éste se mueve el carro: si se acercara también a lo que engancha
## solo, se iría de paseo en cuanto asomara un enemigo por el borde del alcance.
var _ordered_target: Unit = null
## Yendo a por él. Pestillo, para que el anillo tenga dos bordes y no uno.
var _closing: bool = false


func _ready() -> void:
	super._ready()
	if main_gun != null:
		set_weapon_loadout(WeaponLoadout.new("M1A1", [
			WeaponMount.new(main_gun, PackedStringArray([MAIN_STATION]), main_gun_rounds),
		]))
	turret.target_acquired.connect(_on_locked_on)
	turret.target_lost.connect(set_attack_target.bind(null))
	weapons.firing_started.connect(_on_opened_fire)
	weapons.fired.connect(_on_shot)


## Hacia dónde sale el fuego: la línea del cañón, que gira solo. El casco puede
## estar mirando a cualquier otro lado y da igual. Es lo mismo que hace el
## Tunguska, y por eso el conductor sigue usando su propio rumbo por dentro: lo
## que se publica aquí es de dónde sale el tiro, no hacia dónde se anda.
func get_facing() -> float:
	return turret.get_facing()


## Le señalan un blanco. La torre se queda con ése y el casco se acerca si el
## arma no llega.
func receive_attack_order(target: Unit) -> void:
	super.receive_attack_order(target)
	_ordered_target = target
	_closing = false
	turret.hold(target)


## Y moverse lo suelta. `Unit.receive_move_order` ya cancela el ataque —son dos
## órdenes que se pelean por el mismo vehículo—; esto es la otra mitad, soltar
## la torre para que vuelva a mirar por su cuenta.
func receive_move_order(target: Vector2) -> void:
	_ordered_target = null
	_closing = false
	turret.release()
	super.receive_move_order(target)


## Elegir arma a mano contra algo a lo que ya se está disparando **es** decir
## cómo se quiere resolver ese combate, así que a partir de ahí el blanco cuenta
## como ordenado y el carro se acerca si lo elegido no llega.
##
## Sin esto había un agujero: la torre engancha sola a lo que se le pone a tiro,
## le pones la ametralladora —130 px contra los 260 del cañón— y el carro se
## queda quieto, callado y para siempre. Estaba atacando, cambias de arma y deja
## de atacar. Nada avisaba, porque no había nada roto: sencillamente el que
## decide acercarse sólo miraba los blancos que había señalado el jugador.
##
## **Sólo cuenta la elección a mano.** El selector automático cambia de arma
## cada pocas décimas, y sin este filtro el carro saldría detrás de cualquier
## cosa que asomara por el borde del alcance.
func set_active_weapon(weapon: WeaponType) -> void:
	super.set_active_weapon(weapon)
	if selector == null or selector.automatic or _ordered_target != null:
		return
	if is_instance_valid(attack_target):
		_ordered_target = attack_target
		_closing = false


func _physics_process(_delta: float) -> void:
	_work_the_approach()


## Acercarse hasta poder tirar, y ni un metro más.
func _work_the_approach() -> void:
	if not is_instance_valid(_ordered_target) or not _ordered_target.is_alive():
		_ordered_target = null
		_closing = false
		return
	# **A lo que vuela no se le persigue.** El carro le tira si le pasa por
	# encima del alcance y ya está: correr detrás de un avión es una carrera
	# perdida de antemano —va diez veces más rápido— y encima lo saca de donde
	# se le mandó. Es la misma idea que "quédate donde estás si no tienes con
	# qué": acercarse sólo vale cuando acercarse sirve para algo.
	if _ordered_target.get_domain() == UnitType.Domain.AIR:
		_closing = false
		return
	var reach := _reach_against(_ordered_target)
	if reach <= 0.0:
		# Sin nada con qué dispararle, la respuesta buena es quedarse donde
		# está: meterse en el alcance de algo a lo que no puedes hacer nada es
		# sólo ponerse a tiro.
		_closing = false
		return
	var distance := global_position.distance_to(_ordered_target.global_position)
	if not _closing:
		_closing = distance > reach
		if not _closing:
			return
	if distance <= reach * approach_fraction:
		_closing = false
		pilot.stop()
		return
	var want := _standoff(reach)
	if not pilot.has_target() or pilot.destination().distance_to(want) > approach_slack:
		pilot.set_target(want)


## Hasta dónde llega lo mejor que lleva contra ese blanco.
##
## **Lo calcula el que da la orden y no el conductor.** El conductor sólo sabe
## llegar a un punto; de alcances y de munición sabe la unidad, que es la que
## lleva las armas. Es la misma reparto que en el aire.
func _reach_against(target: Unit) -> float:
	var air: bool = target.get_domain() == UnitType.Domain.AIR
	var bit: int = 1 if air else 2
	# **Si el jugador eligió arma, la distancia es la de ESA y no la del mejor
	# alcance que se lleve.** Con el máximo, un carro al que le pones la
	# ametralladora se planta a 195 px y se queda mirando, porque el que decide
	# dónde parar y el que decide con qué tirar estaban contestando cosas
	# distintas. Es el mismo reparto de siempre: la preferencia es suya, y el
	# vehículo sólo resuelve lo que es físicamente imposible.
	if selector != null and not selector.automatic and active_weapon != null \
			and has_ammo(active_weapon) and (active_weapon.targets & bit) != 0:
		return active_weapon.air_max_range if air and active_weapon.air_max_range >= 0.0 \
				else active_weapon.max_range
	var best := 0.0
	for weapon in get_weapons():
		if weapon == null or not has_ammo(weapon):
			continue
		if (weapon.targets & bit) == 0:
			continue
		var reach: float = weapon.air_max_range if air and weapon.air_max_range >= 0.0 \
				else weapon.max_range
		best = maxf(best, reach)
	return best


## El punto del anillo al que ir: en la recta que los une, del lado en que ya
## está. Acercarse por donde ya se viene es lo corto y además no le da el
## costado al blanco por el camino.
func _standoff(reach: float) -> Vector2:
	var away := global_position - _ordered_target.global_position
	if away == Vector2.ZERO:
		return global_position
	return _ordered_target.global_position + away.normalized() * reach * approach_fraction


## Enganchó a alguien por su cuenta: se le apunta y **se le avisa**. El aviso va
## del agresor a la víctima porque el que apunta es el único que sabe a quién.
func _on_locked_on(unit: Unit) -> void:
	set_attack_target(unit)
	unit.notify_tracked(self)


func _on_opened_fire() -> void:
	if is_instance_valid(attack_target):
		attack_target.notify_fired_upon(self)


## El fogonazo del cañón, encendido y apagado a mano. Ver [member
## main_flash_seconds].
func _on_shot(weapon: WeaponType) -> void:
	if weapon != main_gun or not is_instance_valid(main_flash):
		return
	main_flash.start_firing()
	await get_tree().create_timer(main_flash_seconds).timeout
	if is_instance_valid(main_flash):
		main_flash.stop_firing()
