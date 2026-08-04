extends RefCounted
class_name WeaponLoadout

## Configuración de armamento completa de una salida: qué cuelga de cada
## estación. Es la única fuente de verdad — el HUD saca de aquí el resumen
## que muestra y el HardpointRack saca de aquí los sprites que cuelga, así
## que no hay dos cifras que puedan discrepar.
##
## Un mismo objeto hace de dos cosas según quién lo tenga: en `PlayerFleet` es
## un CATÁLOGO — qué configuraciones existen — y en un avión es su carga real,
## con la munición que le va quedando. Son incompatibles, así que quien arma
## una unidad se queda con un `clone()`; si no, el segundo avión de la misión
## despegaría con los misiles que gastó el primero.

var display_name: String
var mounts: Array[WeaponMount] = []
## Arma con la que sale seleccionado el avión. Opcional: vacío = la primera
## montada. Sirve para que la principal no dependa del orden de declaración,
## que también manda el orden de los botones y de la lista del hangar.
var default_weapon: WeaponType = null


func _init(p_display_name: String = "", p_mounts: Array = [],
		p_default_weapon: WeaponType = null) -> void:
	display_name = p_display_name
	mounts.assign(p_mounts)
	default_weapon = p_default_weapon


## Con qué arma sale el avión. Nunca el cañón si lleva algo colgado: quien
## arma un jet con AGM-65 no quiere que ataque a tiros.
##
## Si `default_weapon` apunta a un arma que no está montada — porque cambiaron
## los mounts y nadie actualizó el campo — cae a la primera en vez de dejar al
## avión con un arma que no lleva.
func get_default_weapon() -> WeaponType:
	if mounts.is_empty():
		return null
	if default_weapon != null:
		for mount in mounts:
			if mount.weapon == default_weapon:
				return default_weapon
	return mounts[0].weapon


## ¿Se puede armar esta configuración con las armas que tiene el jugador?
## Todo o nada: si falta una sola, la configuración no se ofrece.
func can_arm_with(available_weapons: Array) -> bool:
	for mount in mounts:
		if not available_weapons.has(mount.weapon):
			return false
	return true


## Copia propia, con la munición llena. Lo que se comparte entre aviones es el
## catálogo; la carga de cada uno es suya.
func clone() -> WeaponLoadout:
	var copy := WeaponLoadout.new(display_name, [], default_weapon)
	for mount in mounts:
		copy.mounts.append(mount.clone())
	return copy


## Cuántas quedan de ese tipo, sumando todas las estaciones que lo llevan.
func ammo_of(weapon: WeaponType) -> int:
	var left := 0
	for mount in mounts:
		if mount.weapon == weapon:
			left += mount.remaining
	return left


## Gasta una de ese tipo. Devuelve si había.
func spend(weapon: WeaponType) -> bool:
	for mount in mounts:
		if mount.weapon == weapon and mount.spend():
			return true
	return false


## Las estaciones donde cuelga ese tipo, para saber de dónde puede salir.
func stations_of(weapon: WeaponType) -> PackedStringArray:
	var found := PackedStringArray()
	for mount in mounts:
		if mount.weapon == weapon:
			found.append_array(mount.stations)
	return found
