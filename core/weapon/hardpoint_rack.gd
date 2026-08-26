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
## Por eso el rack NO es el contador de munición — de eso sabe el loadout —,
## sino de dónde sale cada arma y qué se ve todavía colgado.

const _WEAPON_META := &"weapon"

var _loadout: WeaponLoadout = null
## Lado del último lanzamiento: -1 izquierda, +1 derecha, 0 aún ninguno.
var _last_side: int = 0


func apply_loadout(loadout: WeaponLoadout) -> void:
	clear_weapons()
	_loadout = loadout
	_last_side = 0
	if loadout == null:
		return
	for mount in loadout.mounts:
		for station in mount.stations:
			_mount_on_station(mount, station)


func clear_weapons() -> void:
	for marker in _all_markers():
		_empty(marker)


## Suelta un arma de ese tipo y devuelve el punto del que salió, o null si no
## cuelga de ninguna parte. Alterna alas: se vacía de fuera hacia dentro y de
## un lado al otro, que es como se descarga un avión de verdad y además evita
## que quede visiblemente descompensado a mitad de ataque.
##
## Descolgar el sprite y descontar munición son cosas distintas a propósito:
## una estación puede llevar más armas de las que caben dibujadas, así que el
## avión sigue teniendo con qué tirar aunque el ala ya se vea vacía. Y hay armas
## cuyo sprite no se descuelga con el tiro porque no es el arma sino el aparato
## que la lanza — ver [method _sprite_goes_with_the_shot].
func release(weapon: WeaponType) -> Marker2D:
	var loaded := _markers_loaded_with(weapon)
	if not loaded.is_empty():
		var marker := _pick_alternating(loaded)
		if _sprite_goes_with_the_shot(weapon, loaded.size()):
			_empty(marker)
		return marker
	var stations := _markers_for(weapon)
	return _pick_alternating(stations) if not stations.is_empty() else null


## ¿Se va el dibujo con el disparo? Depende de qué sea el dibujo.
##
## Un arma que **es** lo que cuelga se va y deja el pilón vacío. Un contenedor se
## queda mientras le queden cohetes dentro, y se suelta cuando ya no puede llevar
## lo que falta por tirar: con dos contenedores de 19 y 19 tiros gastados, uno
## sobra y cae; con el último vacío, cae también.
##
## Se cuenta desde la munición y no llevando la cuenta aquí, porque el rack no es
## el contador — mirar el mismo número desde dos sitios es como se acaba con dos
## verdades distintas. Ojo al orden: esto corre **después** de gastar el tiro, así
## que lo que se lee ya está descontado.
func _sprite_goes_with_the_shot(weapon: WeaponType, hanging: int) -> bool:
	if not weapon.icon_is_launcher:
		return true
	var per_station := _per_station_of(weapon)
	if per_station <= 0 or _loadout == null:
		return true
	var left := _loadout.ammo_of(weapon)
	var still_needed := int(ceil(float(left) / float(per_station)))
	return hanging > still_needed


## Cuántas armas lleva cada estación de ese tipo, o 0 si no está montada.
func _per_station_of(weapon: WeaponType) -> int:
	if _loadout == null:
		return 0
	for mount in _loadout.mounts:
		if mount.weapon == weapon:
			return mount.per_station
	return 0


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
	# Marcado con su tipo para poder descolgar el arma correcta más tarde: el
	# sprite es lo único que queda de ella una vez montada.
	sprite.set_meta(_WEAPON_META, weapon)
	return sprite


func _empty(marker: Marker2D) -> void:
	for sprite in marker.get_children():
		marker.remove_child(sprite)
		sprite.queue_free()


## De los candidatos, uno del lado contrario al último lanzamiento y, dentro
## de ese lado, el más externo. Si no queda nada de ese lado vale cualquiera.
func _pick_alternating(markers: Array[Marker2D]) -> Marker2D:
	var wanted := -_last_side
	var best: Marker2D = null
	var fallback: Marker2D = null
	for marker in markers:
		if fallback == null or absf(marker.position.x) > absf(fallback.position.x):
			fallback = marker
		if wanted != 0 and int(signf(marker.position.x)) == wanted:
			if best == null or absf(marker.position.x) > absf(best.position.x):
				best = marker
	var pick: Marker2D = best if best != null else fallback
	_last_side = int(signf(pick.position.x))
	return pick


func _markers_loaded_with(weapon: WeaponType) -> Array[Marker2D]:
	var markers: Array[Marker2D] = []
	for marker in _all_markers():
		for child in marker.get_children():
			if child.get_meta(_WEAPON_META, null) == weapon:
				markers.append(marker)
				break
	return markers


## Todos los markers de las estaciones que llevan ese arma, cuelgue o no algo
## de ellos ahora mismo.
func _markers_for(weapon: WeaponType) -> Array[Marker2D]:
	var markers: Array[Marker2D] = []
	if _loadout == null:
		return markers
	for station in _loadout.stations_of(weapon):
		markers.append_array(_markers_of(station))
	return markers


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
