extends RefCounted
class_name WeaponLoadout

## Configuración de armamento completa de una salida: qué cuelga de cada
## estación. Es la única fuente de verdad — el HUD saca de aquí el resumen
## que muestra y el HardpointRack saca de aquí los sprites que cuelga, así
## que no hay dos cifras que puedan discrepar.

var display_name: String
var mounts: Array[WeaponMount] = []


func _init(p_display_name: String = "", p_mounts: Array = []) -> void:
	display_name = p_display_name
	mounts.assign(p_mounts)
