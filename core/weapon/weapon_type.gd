extends Resource
class_name WeaponType

## Definición compartida de un arma: existe una sola por tipo y los loadouts
## la referencian en vez de copiarla, así el nombre y el icono no se pueden
## desincronizar entre misiones.

@export var display_name: String = ""
@export var icon: Texture2D
