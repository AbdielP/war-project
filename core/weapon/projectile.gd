extends Node2D
class_name Projectile

## Lo que sale del arma, sea lo que sea: un misil guiado, una bomba que cae o
## un cohete que va recto. Aquí está sólo lo que TODOS comparten — de dónde
## salieron, a qué apuntan y qué pasa al explotar. Cómo vuelan es lo que los
## distingue, y eso lo pone cada subclase.
##
## Las cifras de daño no están aquí: vienen en el `WeaponType` que se recibe al
## lanzar. Así una misma escena de proyectil sirve para dos armas con pegada
## distinta, y la cifra que ve el jugador en el hangar es la que se aplica.

## Explotó. Enganche para la animación de explosión.
signal detonated(where: Vector2)

## Por debajo de esta distancia es impacto directo: daño completo.
@export var direct_hit_radius: float = 5.0

var target: Unit = null

var _weapon: WeaponType = null
var _shooter: Unit = null
var _aim_offset: Vector2 = Vector2.ZERO
## Último sitio donde se vio al blanco. Si muere a mitad de vuelo el proyectil
## no se entera: sigue hasta ahí, como haría uno de verdad.
var _aim_point: Vector2 = Vector2.ZERO


## Suéltalo. `muzzle` es el punto del que sale — la estación del ala, no el
## centro del avión — y `aim_offset` desvía el punto de impacto, que es lo que
## hace que una andanada bata un área en vez de meter todo en el mismo píxel.
##
## Las subclases llaman a `super()` y luego arrancan su vuelo.
func launch(shooter: Unit, muzzle: Node2D, at: Unit, weapon: WeaponType,
		aim_offset: Vector2 = Vector2.ZERO) -> void:
	_shooter = shooter
	_weapon = weapon
	_aim_offset = aim_offset
	target = at
	global_position = muzzle.global_position
	_aim_point = at.global_position + aim_offset if is_instance_valid(at) \
		else global_position


## Segundos que le faltan para llegar, al ritmo que lleva ahora. Es una
## estimación honesta y no una cuenta atrás exacta: si el blanco maniobra o el
## arma pierde empuje, la cifra sube. Devuelve -1 si no hay forma de saberlo.
func time_to_impact() -> float:
	var speed := get_speed()
	if speed <= 1.0:
		return -1.0
	return global_position.distance_to(_aim_point) / speed


## A qué velocidad va, en px/s. Cada tipo de proyectil sabe la suya.
func get_speed() -> float:
	return 0.0


func detonate() -> void:
	set_physics_process(false)
	_apply_damage()
	detonated.emit(global_position)
	queue_free()


## Reparte daño a todo lo que pille alrededor, del bando que sea — una
## explosión no distingue. Al que disparó no: sale hacia adelante y nunca
## debería alcanzarse a sí mismo, pero si la geometría se tuerce, un avión
## suicidándose con su propia arma se lee como un bug, no como fuego amigo.
func _apply_damage() -> void:
	if _weapon == null:
		return
	for node in get_tree().get_nodes_in_group(Unit.GROUP):
		var unit := node as Unit
		if unit == null or unit == _shooter or not unit.is_alive():
			continue
		var damage := _damage_at(global_position.distance_to(unit.global_position))
		if damage > 0.0:
			# El arma la tiró alguien: la baja es suya, no del proyectil, que
			# para entonces ya no existe.
			unit.take_damage(damage, _shooter)


## Daño completo dentro del radio de impacto directo, decayendo hasta cero en
## el borde de la explosión. Un arma sin área sólo daña lo que toca.
func _damage_at(distance: float) -> float:
	if distance <= direct_hit_radius:
		return _weapon.damage
	if distance >= _weapon.blast_radius or _weapon.blast_radius <= direct_hit_radius:
		return 0.0
	var falloff := (distance - direct_hit_radius) \
		/ (_weapon.blast_radius - direct_hit_radius)
	return _weapon.damage * (1.0 - falloff)
