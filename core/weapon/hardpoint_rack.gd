extends Node2D
class_name HardpointRack

## Cuelga los sprites del armamento en los Marker2D hijos. Es lo único que
## sabe dibujar armas: no conoce misiones ni unidades, solo recibe un
## WeaponLoadout y lo representa.
##
## Cada marker es una posición de arma y su nombre empieza por el id de la
## estación a la que pertenece — "L2a", "L2b" y "L2c" son la estación "L2".
## Mover, añadir o borrar markers en la escena cambia lo que se dibuja sin
## tocar código.
##
## Si una estación lleva más armas de las que tiene markers se dibujan solo
## las que caben: a 48x48 la cantidad exacta no se lee, el tipo de carga sí.


func apply_loadout(loadout: WeaponLoadout) -> void:
	clear_weapons()
	if loadout == null:
		return
	for mount in loadout.mounts:
		for station in mount.stations:
			_mount_on_station(mount, station)


func clear_weapons() -> void:
	for marker in _all_markers():
		for sprite in marker.get_children():
			marker.remove_child(sprite)
			sprite.queue_free()


func _mount_on_station(mount: WeaponMount, station: String) -> void:
	var markers := _markers_of(station)
	if markers.is_empty():
		return
	# Las armas se reparten desde el centro de la estación: con un solo arma
	# y tres markers cuelga del de en medio, no del borde del pylon.
	var drawn: int = mini(mount.per_station, markers.size())
	var first: int = (markers.size() - drawn) / 2
	for i in drawn:
		markers[first + i].add_child(_make_sprite(mount.weapon))


func _make_sprite(weapon: WeaponType) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = weapon.icon
	return sprite


func _all_markers() -> Array[Marker2D]:
	var markers: Array[Marker2D] = []
	for child in get_children():
		var marker := child as Marker2D
		if marker != null:
			markers.append(marker)
	return markers


func _markers_of(station: String) -> Array[Marker2D]:
	var markers: Array[Marker2D] = []
	for marker in _all_markers():
		if String(marker.name).begins_with(station):
			markers.append(marker)
	# Ordenados por distancia al eje del avión, no por orden en el árbol: el
	# árbol solo coincide con el orden visual en un ala, así que ordenarlo
	# aquí es lo que hace que la posición N signifique lo mismo en las dos y
	# las cargas de un arma por estación salgan simétricas.
	markers.sort_custom(func(a: Marker2D, b: Marker2D) -> bool:
		return absf(a.position.x) < absf(b.position.x)
	)
	return markers
