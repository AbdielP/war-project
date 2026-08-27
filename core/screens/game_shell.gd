extends Node
class_name GameShell

## La carcasa del juego: un hueco y un velo. **No es una pantalla**, es lo que
## las contiene. El menú, la campaña, el puerto y la misión son todos inquilinos
## del mismo hueco, y ninguno sabe de la existencia de los otros.
##
## También es el arranque. No hay pantalla de "Boot" porque no habría nada que
## enseñar: se mira si hay un arranque de desarrollo puesto y se salta a donde
## toque. Una pantalla para eso sería un fundido a negro para entrar en algo
## negro y otro para salir.
##
## El velo va en su propia [CanvasLayer] y no de hermano del hueco: cualquier
## cosa de la misión que llame a `move_to_front()` reordena a los hermanos, y
## tarde o temprano uno se pondría por encima del fundido.

## Cuánto dura el fundido a negro, en segundos. Ida y vuelta cuestan el doble.
@export var fade_time: float = 0.18
## Cuánto se espera antes de sacar la pantalla de carga, en segundos. **No es un
## retraso, es lo contrario**: casi todas las pantallas cargan en un fotograma, y
## enseñar "CARGANDO" durante 30 ms es un parpadeo que se lee como un fallo. Sólo
## la misión pasa de aquí.
@export var loading_delay: float = 0.25
## A dónde se va cuando no hay arranque de desarrollo puesto.
@export_enum("splash", "main_menu", "campaign", "briefing", "port", "mission", "debriefing")
var first_screen: int = 0

@onready var _slot: Node = $Slot
@onready var _veil: ColorRect = $Veil/Fade

const _LOADING := preload("res://ui/screens/loading/loading.tscn")

## La pantalla que se está montando ahora mismo. Mientras haya una, las
## peticiones nuevas no se atienden: se apuntan en [member _pending] y se
## atienden al terminar. Sin esto, una pantalla que pide otra desde su propio
## `_ready` —el splash que se salta solo— se perdería.
var _busy: bool = false
var _pending: Dictionary = {}
## La barra de carga, mientras se ve. Que exista es lo que dice que hubo que
## destapar el velo y que hay que volver a taparlo antes de cambiar.
var _bar: Node = null


func _ready() -> void:
	Screens.attach(self)
	_veil.color.a = 1.0
	var boot := DevBoot.read()
	Screens.instant = boot.get("instant", false)
	var id: int = boot.get("screen", -1)
	Screens.go_to(id if id >= 0 else first_screen, boot.get("context", {}))


func show_screen(path: String, with_context: Dictionary) -> void:
	_pending = {"path": path, "context": with_context}
	if _busy:
		return
	_busy = true
	# En bucle y no recursivo: la pantalla que acaba de nacer puede pedir otra
	# antes de que ésta termine, y eso tiene que encadenarse sin apilar awaits.
	while not _pending.is_empty():
		var job := _pending
		_pending = {}
		await _swap(str(job["path"]))
	_busy = false


func _swap(path: String) -> void:
	await _fade(1.0)
	_clear_slot()
	var scene := await _load(path)
	# Si la carga llegó a verse, el velo está abierto: hay que volver a cerrarlo
	# antes de cambiar, o el salto de una pantalla a la otra se ve en seco.
	if _bar != null:
		await _fade(1.0)
	_clear_slot()
	if scene == null:
		push_error("No se pudo cargar la pantalla: %s" % path)
		await _fade(0.0)
		return
	_slot.add_child(scene.instantiate())
	await _fade(0.0)


func _clear_slot() -> void:
	_bar = null
	for child in _slot.get_children():
		# `remove_child` antes de `queue_free`: el segundo sólo desengancha al
		# final del fotograma, y hasta entonces la pantalla vieja sigue viva
		# encima de la nueva.
		_slot.remove_child(child)
		child.queue_free()


## Carga en hilo aparte, y saca la pantalla de carga sólo si de verdad tarda.
func _load(path: String) -> PackedScene:
	if ResourceLoader.load_threaded_request(path) != OK:
		return null
	var progress: Array = []
	var waited := 0.0
	while true:
		var status := ResourceLoader.load_threaded_get_status(path, progress)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			break
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return null
		waited += get_process_delta_time()
		if _bar == null and waited >= loading_delay:
			_bar = _LOADING.instantiate()
			_slot.add_child(_bar)
			await _fade(0.0)
		if _bar != null and _bar.has_method("set_progress"):
			_bar.set_progress(float(progress[0]) if not progress.is_empty() else 0.0)
		await get_tree().process_frame
	return ResourceLoader.load_threaded_get(path) as PackedScene


func _fade(to: float) -> void:
	if Screens.instant or fade_time <= 0.0:
		_veil.color.a = to
		return
	var tween := create_tween()
	tween.tween_property(_veil, "color:a", to, fade_time)
	await tween.finished
