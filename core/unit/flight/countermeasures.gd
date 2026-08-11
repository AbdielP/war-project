extends Node
class_name Countermeasures

## Lo que lleva un avión para engañar a un misil: chaff contra los de radar,
## bengalas contra los de calor.
##
## Lleva la cuenta y **las suelta solo** cuando le viene un misil: se engancha al
## aviso de su propia unidad y va soltando con un respiro entre una y otra hasta
## que el misil se pierde o impacta. No pregunta a nadie — un piloto no espera
## permiso para soltar bengalas.
##
## Lo que suelta es un [Decoy]. Que engañe o no **no se decide aquí ni con un
## dado**: el señuelo se queda en el aire y el buscador del misil se lleva lo que
## tenga más centrado. Por eso soltar volando recto no sirve de mucho — hace
## falta virar para separar los dos contactos.
##
## Va aparte del armamento a propósito: **una contramedida no es un arma**. No se
## elige, no apunta, no hace daño y no se dispara contra nadie. Meterla en el
## `WeaponLoadout` la habría metido en la rotación de armas activas, que es justo
## lo que no debe pasar.
##
## Cada tipo sirve contra una guía y sólo contra ésa. Soltar el equivocado no
## hace nada, y ahí está la decisión: hay que saber qué te dispararon. El parte
## ya lo dice — `MUD SPIKE` es radar.

## Se gastó una. `left` es lo que queda de ese tipo.
signal spent(kind: Kind, left: int)
## Empezó a soltar contra una amenaza. Lo escucha el parte para cantar
## `DEFENDING`, y el vuelo para saber que toca maniobrar.
signal dispensing_started(threat: Unit)
## Dejó de soltar: el misil se perdió, impactó, o se acabaron las cargas.
signal dispensing_stopped

enum Kind { CHAFF, FLARES }

## Contra misiles guiados por radar.
@export var chaff: int = 30
## Contra misiles guiados por calor.
@export var flares: int = 30

@export_group("Dispensado")
## Qué se suelta. Un `Decoy` con su tipo puesto al nacer.
@export var decoy_scene: PackedScene
## Segundos entre una soltada y la siguiente. Corto: lo que se busca es una
## ristra, no un señuelo suelto.
@export var interval: float = 0.25
## Cuántos salen **de golpe** en cada soltada. 2 con apertura da la V clásica,
## una a cada lado.
##
## Ojo al subirlo: cada uno es un contacto que el buscador puede confundir, así
## que soltar seis no es más vistoso, es seis veces más difícil de acertar.
@export_range(1, 8, 1) var per_release: int = 1
## Cuánto se abre el abanico, en grados totales. Con `per_release` a 2 y esto a
## 60, salen a ±30 de la cola. A 0 salen todos por el mismo sitio.
@export var spread_deg: float = 60.0
## A qué distancia del avión aparecen, hacia atrás. Lo justo para que no salgan
## de dentro del propio sprite.
@export var behind_px: float = 6.0
## Cuánto se lleva el señuelo de la velocidad del avión. Menos de la mitad: tiene
## que quedarse atrás rápido, porque **lo que engaña es que los dos contactos se
## separen**.
@export_range(0.0, 1.0, 0.05) var inherit_velocity: float = 0.35

var _unit: Unit = null
## El misil del que nos estamos defendiendo. Mientras exista, se sigue soltando.
var _threat_missile: Node2D = null
var _threat: Unit = null
var _kind_needed: Kind = Kind.CHAFF
var _until_next: float = 0.0


func _ready() -> void:
	set_physics_process(false)
	_unit = get_parent() as Unit
	if _unit != null:
		_unit.missile_inbound.connect(_on_missile_inbound)


## Le viene un misil: empieza a soltar lo que sirva contra esa guía.
##
## El tipo sale del arma que lo lanzó, no de una preferencia: **soltar el
## equivocado no engaña a nadie**. Contra radar, chaff.
func _on_missile_inbound(threat: Unit, weapon: WeaponType, missile: Node2D) -> void:
	_kind_needed = kind_against(weapon)
	if not has(_kind_needed):
		return
	_threat = threat
	# El más reciente manda. Con dos misiles encima no tiene sentido llevar dos
	# cuentas: se sigue soltando igual, y basta con no parar hasta que el último
	# haya terminado.
	_threat_missile = missile
	_until_next = 0.0
	if not is_physics_processing():
		set_physics_process(true)
		# Diferido para que el parte quede en orden. Esto cuelga del mismo aviso
		# (`missile_inbound`) que el registro de eventos y se conecta antes que
		# él, así que emitir aquí mismo cantaría "DEFENDING" antes que "SAM
		# LAUNCH" — la respuesta antes que la amenaza.
		dispensing_started.emit.call_deferred(threat)


## Contra qué guía sirve cada cosa. Hoy todo lo que vuela por radar se responde
## con chaff; cuando haya misiles de calor, esto es lo único que hay que tocar.
static func kind_against(weapon: WeaponType) -> Kind:
	return Kind.FLARES if weapon != null and weapon.seeker == WeaponType.Seeker.HEAT \
		else Kind.CHAFF


func _physics_process(delta: float) -> void:
	# Se para cuando el misil deja de existir —impactó o se agotó— o cuando ya no
	# queda con qué. Lo segundo es lo que hace que un avión que lleva mucho fuera
	# acabe siendo vulnerable.
	if not is_instance_valid(_threat_missile) or not has(_kind_needed):
		_stop()
		return
	_until_next -= delta
	if _until_next > 0.0:
		return
	_until_next = maxf(interval, 0.01)
	_release_one()


func _stop() -> void:
	set_physics_process(false)
	_threat_missile = null
	_threat = null
	dispensing_stopped.emit()


## Una soltada: **una carga, salgan los que salgan**.
##
## El cartucho es lo que se gasta, no cada trozo que se ve. Cobrar por trozo
## haría que cambiar el patrón cambiase la autonomía del avión, y entonces los
## números de carga no querrían decir nada.
func _release_one() -> void:
	if not spend(_kind_needed) or decoy_scene == null or _unit == null:
		return
	for i in per_release:
		_put_one(_release_angle(i))


## Hacia dónde sale el enésimo del abanico. Se reparten por detrás del avión: un
## señuelo soltado hacia adelante volvería a cruzarse con él.
func _release_angle(index: int) -> float:
	var tail := _unit.get_facing() + PI
	if per_release <= 1:
		return tail
	var step := deg_to_rad(spread_deg) / float(per_release - 1)
	return tail - deg_to_rad(spread_deg) * 0.5 + step * index


func _put_one(angle: float) -> void:
	var decoy := decoy_scene.instantiate() as Decoy
	if decoy == null:
		return
	decoy.kind = _kind_needed
	# Cuelga del mundo y no del avión: un señuelo que viaja con quien lo soltó no
	# engaña a nada, porque nunca llega a separarse de él.
	_unit.get_parent().add_child(decoy)
	decoy.global_position = _unit.global_position \
		+ Vector2.RIGHT.rotated(angle) * behind_px
	decoy.launch(_unit.get_velocity() * inherit_velocity)


## Cuántas quedan de ese tipo.
func remaining(kind: Kind) -> int:
	return chaff if kind == Kind.CHAFF else flares


func has(kind: Kind) -> bool:
	return remaining(kind) > 0


## Gasta una. Devuelve si había con qué.
func spend(kind: Kind) -> bool:
	if not has(kind):
		return false
	if kind == Kind.CHAFF:
		chaff -= 1
	else:
		flares -= 1
	spent.emit(kind, remaining(kind))
	return true


## El nombre corto para la interfaz.
static func label_of(kind: Kind) -> String:
	return "CHAFF" if kind == Kind.CHAFF else "FLARE"
