extends Resource
class_name WeaponType

## Definición compartida de un arma: existe una sola por tipo y los loadouts
## la referencian en vez de copiarla, así el nombre y el icono no se pueden
## desincronizar entre misiones.

@export var display_name: String = ""
## Nombre para los botones de la barra de armas. Ahí sólo caben ~6 caracteres,
## así que se escribe a mano en vez de recortar el nombre largo: un arma nueva
## mal nombrada saldría cortada donde no toca.
@export var short_name: String = ""
@export var icon: Texture2D


## El nombre corto si lo tiene; si no, el largo — un botón sin texto no se
## puede pulsar a ciegas.
func get_short_name() -> String:
	return short_name if short_name != "" else display_name
