extends Screen

## El parte de la misión que acabas de jugar. Está separada de la campaña a
## propósito: una informa de lo que pasó y la otra es el estado del jugador. Si
## luego se quieren fusionar, se fusionan sin coste; separarlas después sí
## cuesta.

@onready var _result: Label = $Result
@onready var _values: Label = $Panel/Rows/Values
@onready var _continue: Button = $Continue

const _WON := Color(0.5686275, 0.85882354, 0.4117647)
const _LOST := Color(0.9098039, 0.23137255, 0.23137255)


func enter() -> void:
	_continue.pressed.connect(_on_continue)
	_continue.grab_focus()
	var won := bool(ctx("won", true))
	_result.text = "MISION CUMPLIDA" if won else "MISION FALLIDA"
	_result.add_theme_color_override("font_color", _WON if won else _LOST)
	# Los números llegan como texto ya formado: el debriefing no sabe contar
	# bajas, sólo enseñarlas. Lo que trae la escena queda de muestra.
	_values.text = str(ctx("detail", _values.text))


## El progreso se apunta **aquí y no al terminar la misión**: hasta que el
## jugador no ha leído el parte, la misión no está cerrada. Si sale del juego
## antes, la vuelve a jugar.
func _on_continue() -> void:
	if bool(ctx("won", true)):
		Campaign.mission_cleared(int(ctx("reward", 0)))
	Screens.go_to(Screens.Id.CAMPAIGN)
