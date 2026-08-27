extends Control
class_name Screen

## Base de toda pantalla del juego. Lo único que aporta es la regla que hace que
## el desarrollo no tenga que atravesar la secuencia:
##
## **Ninguna pantalla depende de que otra la haya preparado.** Si nadie le pasó
## contexto —porque la abriste con F6— usa [member default_context], que se
## rellena en el inspector con datos de trabajo. Así el Puerto abierto solo
## enseña una flota de muestra en vez de una pantalla vacía o un error.
##
## Es la misma idea del `@export var preview: PackedScene` del hangar, subida un
## nivel: lo que se llena en marcha se guarda *puesto*, con datos de muestra.
##
## Las clases derivadas **sobrescriben [method enter], no `_ready`**. Así no hay
## que acordarse de llamar a `super._ready()` y los `@onready` ya están
## resueltos cuando toca leer el contexto.

## Con qué arranca la pantalla cuando nadie la configuró. **Sólo para
## desarrollo**: en el juego real siempre llega contexto de verdad.
@export var default_context: Dictionary = {}

var _context: Dictionary = {}


func _ready() -> void:
	_context = Screens.context().duplicate(true)
	if _context.is_empty():
		_context = default_context.duplicate(true)
	enter()


## Aquí va lo que haría `_ready`. El contexto ya está resuelto.
func enter() -> void:
	pass


## Un dato del contexto, con su valor de trabajo si no vino.
func ctx(key: String, fallback: Variant = null) -> Variant:
	return _context.get(key, fallback)
