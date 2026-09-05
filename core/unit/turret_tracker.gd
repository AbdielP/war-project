extends Node2D
class_name TurretTracker

## La torreta de una unidad antiaérea: engancha el avión más cercano que entre en
## su rango y lo va siguiendo con los cañones.
##
## Gira DESPACIO y a propósito. Una torreta que se planta encima del blanco en un
## frame no se lee como una máquina apuntando, se lee como un número asignado —
## y además le quita al jugador lo único que tiene a favor, que es cruzar el
## rango antes de que le apunten. Lo lento es la mecánica, no un adorno.
##
## **No dispara.** Sólo apunta, y avisa por señal de a quién. Lo que se haga con
## eso es del arma, que ya sabe de alcances y de munición.
##
## Busca por DISTANCIA y no con un área de colisión, igual que `WeaponSystem`
## resuelve su alcance: un `Area2D` aquí sería un segundo mecanismo de detección
## en paralelo respondiendo a la misma pregunta.
##
## Hasta dónde ve no se apunta aquí: se lo pregunta a los círculos que ya lo
## dicen en pantalla. Tenerlo en los dos sitios daría una torreta que engancha
## más lejos de lo que dibuja, y el jugador ajusta lo que ve.

## Enganchó a alguien y empieza a seguirlo.
signal target_acquired(unit: Unit)
## Lo perdió — se fue de rango o dejó de existir.
signal target_lost

## Grados por segundo girando. Bajo aposta: es el tiempo de reacción de la
## unidad, y lo que decide si un avión rápido puede cruzar sin comerse la ráfaga.
@export var turn_speed_deg: float = 60.0
## Hacia dónde miran los cañones cuando la rotación es 0, igual que en el avión y
## en el misil. Están dibujados apuntando hacia abajo (+Y), de ahí el −90.
@export var sprite_offset_deg: float = -90.0

@export_group("Búsqueda")
## En qué grupos busca. Cualquier unidad que esté en uno de ellos entra en la
## búsqueda.
##
## **Es una lista y no un grupo suelto** porque hay torretas que sirven para más
## de una cosa: la del Tunguska sólo mira al aire, pero la del carro tiene un
## cañón para blindados y una ametralladora que también le llega a lo que vuela,
## y con un solo grupo habría que elegir a cuál de las dos hacerle caso.
##
## Qué se puede disparar contra lo que se enganche no se decide aquí: eso lo
## sabe el arma. Esto sólo dice a quién mirar.
@export var target_groups: PackedStringArray = PackedStringArray(["unit_air"])
## Cada cuánto vuelve a mirar quién anda cerca, en segundos. No hace falta cada
## frame — nada cruza un rango entero en una décima — y así no se recorre la
## lista de aviones 60 veces por segundo.
@export var rescan_interval: float = 0.1

@export_group("Enlace")
## De dónde saca su alcance. Los mismos círculos que se dibujan en el suelo.
@export var rings_path: NodePath = ^"../RangeRings"

## A quién está siguiendo, o `null` si no hay nadie.
var target: Unit = null
## Un blanco impuesto desde fuera, que manda sobre la búsqueda. Es el que señaló
## el jugador.
##
## **La preferencia es del jugador y no caduca porque pase otro más cerca.** Sin
## esto, la torreta de una unidad propia rehace su elección cada décima de
## segundo y le quita la orden de las manos al que la dio. La búsqueda sigue
## corriendo por debajo, así que en cuanto se suelte —o el blanco muera— vuelve
## a engancharse sola sin que nadie tenga que reiniciarla.
##
## No lo usa el Tunguska: una batería que se defiende sola no recibe órdenes.
var forced: Unit = null

var _rings: RangeRings
var _owner_unit: Unit
var _until_rescan: float = 0.0


func _ready() -> void:
	_rings = get_node_or_null(rings_path) as RangeRings
	_owner_unit = _find_owner_unit()


## Hacia dónde miran los cañones, en radianes de mundo. Es lo que tiene que
## devolver `get_facing()` de la unidad: de aquí sale el fuego, no del casco.
func get_facing() -> float:
	return global_rotation - deg_to_rad(sprite_offset_deg)


## De quién es esta torreta. Se sube por el árbol en vez de exigir que cuelgue
## directamente de la unidad, para que dé igual cómo esté montado el vehículo.
func _find_owner_unit() -> Unit:
	var node: Node = get_parent()
	while node != null:
		var unit := node as Unit
		if unit != null:
			return unit
		node = node.get_parent()
	return null


func _physics_process(delta: float) -> void:
	_until_rescan -= delta
	if _until_rescan <= 0.0:
		_until_rescan = maxf(rescan_interval, 0.0)
		_refresh_target()

	# Sin blanco se queda como está. Volver sola a una posición de reposo sería
	# inventarse una maniobra que nadie pidió; ahí se queda, apuntando a donde se
	# fue el último.
	if is_instance_valid(target):
		_aim_at(target.global_position, delta)


## Gira hacia el punto sin pasarse, a su velocidad y ni un grado más. Que llegue
## tarde cuando el avión va rápido no es un fallo: es el margen del jugador.
func _aim_at(point: Vector2, delta: float) -> void:
	var wanted := (point - global_position).angle() + deg_to_rad(sprite_offset_deg)
	global_rotation = rotate_toward(
		global_rotation, wanted, deg_to_rad(turn_speed_deg) * delta)


## Elige a quién seguir: lo más cercano dentro del alcance. Se rehace entero cada
## vez en vez de aferrarse al de antes, así la torreta cambia sola al que se le
## meta más encima.
## Sigue a éste y no busques a nadie más, hasta que se suelte o se muera.
func hold(unit: Unit) -> void:
	forced = unit
	_refresh_target()


func release() -> void:
	forced = null
	_refresh_target()


func _refresh_target() -> void:
	# Un blanco impuesto que ya no está no bloquea la torreta: se cae solo y la
	# búsqueda vuelve a mandar. Así no hace falta que nadie llame a `release()`
	# cuando lo que señaló el jugador se muere.
	if forced != null and (not is_instance_valid(forced) or not forced.is_alive()):
		forced = null
	var found: Unit = forced if forced != null else _closest_in_range()
	if found == target:
		return
	target = found
	if target != null:
		target_acquired.emit(target)
	else:
		target_lost.emit()


func _closest_in_range() -> Unit:
	var reach := _reach()
	if reach <= 0.0:
		return null
	var best: Unit = null
	var best_distance := reach
	var seen: Dictionary = {}
	var candidates: Array[Node] = []
	for group in target_groups:
		for node in get_tree().get_nodes_in_group(StringName(group)):
			# Una unidad puede estar en dos de los grupos vigilados, y sin este
			# filtro se mediría dos veces. No cambia a quién se elige, pero sí
			# el trabajo, que es por fotograma y por torreta.
			if seen.has(node.get_instance_id()):
				continue
			seen[node.get_instance_id()] = true
			candidates.append(node)
	for node in candidates:
		var candidate := node as Unit
		if candidate == null or not candidate.is_alive():
			continue
		# Una batería antiaérea no apunta a los suyos. Sin esto, en cuanto haya
		# aviones en los dos bandos seguiría al aliado que pase más cerca.
		if _owner_unit != null and not _owner_unit.is_hostile_to(candidate):
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance <= best_distance:
			best = candidate
			best_distance = distance
	return best


## Hasta dónde engancha. Sale de los círculos; sin ellos no hay alcance que valga
## y la torreta se queda quieta, que es mejor que inventarse un número que no
## está dibujado en ninguna parte.
func _reach() -> float:
	return _rings.detection_radius if _rings != null else 0.0
