extends Unit

## Qué ES el Harrier: identidad, categoría y cómo recibe órdenes.
## No pilota — de eso se encarga PlaneController, y de a dónde ir,
## OrbitBehavior o AttackRunBehavior. Todos cuelgan de esta misma escena.
##
## Aquí sólo se arbitra cuál de los dos comportamientos manda: los dos le dan
## puntos al mismo piloto y no pueden correr a la vez. Y aquí se traduce el
## arma activa a la envolvente de tiro que el vuelo tiene que respetar — el
## comportamiento no sabe de armas y el arma no sabe de vuelo.

signal order_fulfilled

@onready var pilot: PlaneController = $PlaneController
@onready var orbit: OrbitBehavior = $OrbitBehavior
@onready var attack: AttackRunBehavior = $AttackRun
@onready var weapons: WeaponSystem = $WeaponSystem


func _ready() -> void:
	super._ready()
	add_to_group("unit_air")
	orbit.center_reached.connect(func() -> void: order_fulfilled.emit())
	attack.target_lost.connect(_on_target_lost)
	# Sólo se tira dentro de la pasada. Fuera de ella el avión está maniobrando
	# y el blanco le cruza el morro de refilón cada vez que vira: sin esto, cada
	# uno de esos cruces sería un tiro, y el ataque se vería como un baile.
	attack.attack_run_started.connect(weapons.set_cleared_to_fire.bind(true))
	attack.attack_run_ended.connect(weapons.set_cleared_to_fire.bind(false))
	# Disparar y romper el ataque son la misma maniobra: en cuanto sale el arma
	# el avión deja de meterse hacia el blanco.
	weapons.fired.connect(func(_weapon: WeaponType) -> void: attack.break_off())
	# Cambiar de arma en pleno ataque cambia a qué distancia hay que volar.
	active_weapon_changed.connect(_on_active_weapon_changed)
	# En cubierta no se dispara, aunque ya tenga objetivo asignado.
	weapons.set_active(false)


## El rumbo real de vuelo, no la rotación del nodo: el arte apunta a +Y, así
## que la rotación lleva un desfase que el armamento no debe heredar — saldría
## disparado de lado.
func get_facing() -> float:
	return pilot.heading


func get_velocity() -> Vector2:
	return pilot.velocity


## Deja la cubierta a su velocidad mínima de vuelo. Es lo más despacio que
## puede sostenerse en el aire y, por tanto, lo antes que puede irse: no hay
## motivo para gastar más pista de la necesaria. La cubierta lo acelera hasta
## aquí y el piloto lo recoge volando ya a esta velocidad, así que el relevo no
## se nota. Y como es la misma a la que espera en el circuito, tampoco hay un
## acelerón inútil nada más despegar.
func get_takeoff_speed() -> float:
	return pilot.min_speed


func get_time_to_impact() -> float:
	return weapons.time_to_impact()


## El portaaviones cede el control cuando el avión ya está en el aire.
##
## El circuito de espera es lo que hace un avión SIN órdenes. Si le dieron una
## mientras estaba en cubierta, al soltarlo hay que cumplirla: mandarlo a dar
## vueltas al barco sería ignorarla.
func start_flight(orbit_center: Node2D) -> void:
	pilot.enable()
	weapons.set_active(true)
	if is_instance_valid(attack_target):
		receive_attack_order(attack_target)
	elif not orbit.has_pending_order():
		# Si ya iba hacia un punto ordenado, el destino sigue puesto en el
		# piloto: basta con no tocarlo, ahora que puede volar.
		_orbit_around(orbit_center)


func receive_move_order(target: Vector2) -> void:
	super.receive_move_order(target)
	attack.stop()
	orbit.orbit_at(target)


func receive_attack_order(target: Unit) -> void:
	super.receive_attack_order(target)
	orbit.stop()
	# Se empieza sin permiso: primero se enfila, y el permiso llega con la
	# pasada. Al revés, el avión abriría fuego mientras todavía está buscando la
	# línea de ataque.
	weapons.set_cleared_to_fire(false)
	attack.engage(target, _weapon_min_range(), _weapon_max_range())


## Se quedó sin objetivo en pleno viaje. Un avión no puede pararse: orbita
## donde llegó, no donde estaba el enemigo — seguir volando hasta un punto
## vacío parecería que no se enteró.
func _on_target_lost() -> void:
	set_attack_target(null)
	orbit.orbit_at(global_position)


## El arma manda sobre el vuelo: si cambia mientras se ataca, el avión tiene
## que rehacer las distancias sin soltar el blanco.
func _on_active_weapon_changed(_weapon: WeaponType) -> void:
	if is_instance_valid(attack_target):
		attack.set_envelope(_weapon_min_range(), _weapon_max_range())


func _weapon_min_range() -> float:
	return active_weapon.min_range if active_weapon != null else 0.0


## 0 = sin arma con la que atacar. El comportamiento lo entiende como "ve
## derecho", que es lo único sensato cuando no hay envolvente que respetar.
func _weapon_max_range() -> float:
	return active_weapon.max_range if active_weapon != null else 0.0


func _orbit_around(center: Node2D) -> void:
	attack.stop()
	orbit.orbit_around(center)
