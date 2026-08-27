extends Screen

## La entrada al juego. Tres decisiones y nada más.
##
## *Continuar* va **primero y no segundo**: quien ya empezó una partida viene a
## seguirla, y es lo que va a pulsar nueve de cada diez veces. Y si no hay nada
## que continuar sale apagado, no escondido: que la opción exista dice que el
## juego se guarda, aunque hoy no puedas usarla.
##
## Falta *Opciones*, a propósito: no hay ninguna todavía y un botón que abre una
## pantalla vacía es peor que no tenerlo.

@onready var _continue: Button = $Menu/Continue
@onready var _new: Button = $Menu/New
@onready var _quit: Button = $Menu/Quit


func enter() -> void:
	_continue.disabled = not Campaign.has_save()
	_continue.pressed.connect(_on_continue)
	_new.pressed.connect(_on_new)
	_quit.pressed.connect(_on_quit)
	# El foco al primero que se puede pulsar, para que el mando y el teclado
	# entren directos sin tener que tabular a ciegas.
	var first: Button = _new if _continue.disabled else _continue
	first.grab_focus()


func _on_continue() -> void:
	if not Campaign.load_game():
		# El archivo estaba y no se pudo leer. No se arranca una partida a
		# medias: se apaga el botón y se queda a la vista que algo pasa.
		_continue.disabled = true
		_new.grab_focus()
		return
	Screens.go_to(Screens.Id.CAMPAIGN)


func _on_new() -> void:
	Campaign.start_new()
	Screens.go_to(Screens.Id.CAMPAIGN)


func _on_quit() -> void:
	get_tree().quit()
