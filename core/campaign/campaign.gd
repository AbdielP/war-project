extends Node

## La partida en curso: por dónde va la campaña, cuánto dinero hay y qué está
## desbloqueado. Es **el contenido del guardado**, y nada más — la economía y
## las mejoras las pondrá el Puerto encima de esto.
##
## Se guarda **entre misiones y no en mitad de una**. La diferencia no es de
## comodidad, es de coste: guardar a mitad obliga a serializar cada unidad, cada
## proyectil en el aire y cada orden pendiente, y condiciona cómo se escribe
## todo lo demás. Entre misiones cabe en cuatro campos, y es lo que hace falta
## para que "Continuar" funcione.
##
## No decide nada por su cuenta: quien gana una misión llama a
## [method mission_cleared]. Aquí sólo se apunta.

## Cambió algo que la campaña enseña. Lo escucha la pantalla de campaña.
signal changed

const SAVE_PATH := "user://campaign.save"
## Sube cuando el formato deja de poder leerse. Un guardado viejo se descarta en
## vez de cargarse a medias: media partida cargada es peor que ninguna.
const FORMAT := 1

## Cuántas misiones lleva superadas. Es también el índice de la siguiente.
var progress: int = 0
var money: int = 0
## Qué tiene comprado o desbloqueado el jugador. Por nombre y no por recurso: un
## guardado no puede depender de rutas de archivo que mañana se muevan.
var unlocked: Array[String] = []


## ¿Hay algo que continuar? Es lo que decide si el menú principal enseña
## *Continuar* activo. **No hay botón gris que no hace nada.**
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Empieza de cero. No borra el archivo: se sobrescribe al guardar, y mientras
## tanto la partida vieja sigue ahí por si el jugador se arrepiente.
func start_new() -> void:
	progress = 0
	money = 0
	unlocked = []
	changed.emit()


func mission_cleared(reward: int = 0) -> void:
	progress += 1
	money += reward
	changed.emit()


func save() -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("No se pudo guardar en %s" % SAVE_PATH)
		return false
	file.store_string(JSON.stringify({
		"format": FORMAT,
		"progress": progress,
		"money": money,
		"unlocked": unlocked,
	}, "\t"))
	return true


func load_game() -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var data: Variant = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or int(data.get("format", 0)) != FORMAT:
		push_warning("Guardado ilegible o de otra versión: se ignora")
		return false
	progress = int(data.get("progress", 0))
	money = int(data.get("money", 0))
	unlocked.assign(data.get("unlocked", []))
	changed.emit()
	return true
