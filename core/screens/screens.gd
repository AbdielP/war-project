extends Node

## El router de pantallas. **Nadie instancia a nadie**: una pantalla pide ir a
## otra y se olvida. Sin esto, el menú acabaría guardando una referencia a la
## campaña y la campaña al menú, y ninguna de las dos se podría abrir sola.
##
## Correr sola es el punto entero: abres la escena de una pantalla, F6, y la
## estás viendo — sin logo, sin menú, sin partida guardada. Para que eso valga,
## aquí hay dos caminos:
##
## - **Con carcasa** ([GameShell] enganchada): fundido, carga en hilo aparte y
##   pantalla de carga si tarda. Es lo que pasa al arrancar el juego.
## - **Sin carcasa** (F6 sobre una pantalla suelta): se cambia de escena a pelo.
##   Se pierde el fundido, pero la navegación **sigue funcionando** y puedes
##   recorrer el flujo desde donde estabas trabajando.
##
## Ninguna pantalla necesita saber en cuál de los dos está.

## Se pidió otra pantalla. Emitida al pedirla, no al terminar de mostrarla.
signal screen_changed(id: Id)

## Las pantallas del juego. **No hay BOOT**: el arranque lo hace la propia
## carcasa antes de enseñar nada — ver [GameShell]. Una pantalla de arranque
## sería un fundido a negro para entrar a algo negro y otro para salir.
enum Id {
	SPLASH,
	MAIN_MENU,
	CAMPAIGN,
	BRIEFING,
	PORT,
	MISSION,
	DEBRIEFING,
}

## Por ruta y no con `preload`: cargar aquí las siete pantallas metería la
## misión entera —terreno, unidades, HUD— en memoria nada más arrancar, que es
## justo lo que la carga en hilo aparte viene a evitar.
const PATHS := {
	Id.SPLASH: "res://ui/screens/splash/splash.tscn",
	Id.MAIN_MENU: "res://ui/screens/main_menu/main_menu.tscn",
	Id.CAMPAIGN: "res://ui/screens/campaign/campaign_screen.tscn",
	Id.BRIEFING: "res://ui/screens/briefing/briefing.tscn",
	Id.PORT: "res://ui/screens/port/port.tscn",
	Id.MISSION: "res://ui/screens/mission/mission.tscn",
	Id.DEBRIEFING: "res://ui/screens/debriefing/debriefing.tscn",
}

## Fundidos a cero. Lo enciende el arranque de desarrollo: durante el desarrollo
## la secuencia no se atraviesa, se salta.
var instant: bool = false

var _shell: Node = null
var _current: Id = Id.SPLASH
var _context: Dictionary = {}
## De dónde se vino, para [method back]. Sólo lo llena [method push].
var _stack: Array[Dictionary] = []


## La carcasa se presenta al nacer. Si nadie se presenta, se navega a pelo.
func attach(shell: Node) -> void:
	_shell = shell


func current() -> Id:
	return _current


## Lo que le pasaron a la pantalla que se está viendo. Vacío si nadie le pasó
## nada — que es lo normal al abrirla con F6.
func context() -> Dictionary:
	return _context


## Va a otra pantalla y **vacía la pila**. Es el movimiento normal: del menú a
## la campaña, de la campaña a la misión.
func go_to(id: Id, with_context: Dictionary = {}) -> void:
	_stack.clear()
	_show(id, with_context)


## Va a otra pantalla **recordando desde dónde**. Es lo que usa el Puerto, que
## se abre desde la campaña y desde el briefing y tiene que volver al que lo
## abrió — no a uno fijo elegido de antemano.
func push(id: Id, with_context: Dictionary = {}) -> void:
	_stack.push_back({"id": _current, "context": _context})
	_show(id, with_context)


## ¿Alguien abrió esta pantalla, o se está viendo suelta? Lo pregunta el Puerto
## para apagar su botón de volver en vez de dejarlo muerto.
func has_previous() -> bool:
	return not _stack.is_empty()


## Vuelve a quien abrió esta pantalla. Devuelve `false` si nadie la abrió, que
## es lo que pasa al correrla suelta con F6: ahí no hay a dónde volver y el
## botón simplemente no hace nada, en vez de reventar.
func back() -> bool:
	if _stack.is_empty():
		return false
	var entry: Dictionary = _stack.pop_back()
	_show(entry["id"], entry["context"])
	return true


## Apunta a dónde vamos y **con qué**, y se lo pide a la carcasa. El contexto se
## queda aquí y no se le pasa a la pantalla por parámetro: así lo recoge igual
## la que nace dentro de la carcasa y la que nace de un cambio de escena a pelo.
## Ver [method context] y [Screen].
func _show(id: Id, with_context: Dictionary) -> void:
	_current = id
	_context = with_context
	screen_changed.emit(id)
	var path: String = PATHS[id]
	if is_instance_valid(_shell):
		_shell.show_screen(path, with_context)
		return
	# Sin carcasa: F6 sobre una pantalla suelta. El contexto se queda aquí y la
	# pantalla nueva lo recoge en su `_ready` — ver [Screen].
	get_tree().change_scene_to_file(path)


## El identificador escrito, para el archivo de arranque de desarrollo y para
## los mensajes de error. `"port"` -> `Id.PORT`.
static func id_from_name(name: String) -> int:
	var wanted := name.strip_edges().to_upper()
	for key: String in Id.keys():
		if key == wanted:
			return Id[key]
	return -1


static func name_of(id: Id) -> String:
	return str(Id.keys()[id]).to_lower()
