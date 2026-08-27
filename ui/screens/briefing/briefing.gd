extends Screen

## Lo que vas a hacer y con qué. Es el último sitio desde el que se puede ir al
## Puerto antes de despegar, que es justo cuando hace falta: aquí es donde te
## das cuenta de que te falta armamento.

@onready var _name: Label = $MissionName
@onready var _brief: Label = $Panel/Text
@onready var _port: Button = $Buttons/Port
@onready var _launch: Button = $Buttons/Launch
@onready var _back: Button = $Buttons/Back


func enter() -> void:
	_port.pressed.connect(func() -> void: Screens.push(Screens.Id.PORT))
	_launch.pressed.connect(_on_launch)
	_back.pressed.connect(func() -> void: Screens.go_to(Screens.Id.CAMPAIGN))
	var index := int(ctx("mission", 0))
	_name.text = "MISION %02d" % (index + 1)
	# Lo que trae la escena queda de texto de muestra: abierta con F6 se ve el
	# briefing lleno en vez de un panel en blanco.
	_brief.text = str(ctx("brief", _brief.text))


func _on_launch() -> void:
	Screens.go_to(Screens.Id.MISSION, {"mission": ctx("mission", 0)})
