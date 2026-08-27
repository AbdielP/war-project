extends Screen

## Mejoras, desbloqueos y compras. **No es un destino**: se llega desde la
## campaña o desde el briefing, y su única salida es volver a quien lo abrió —
## por eso usa [method Screens.back] y no una pantalla fija elegida de antemano.
##
## Abierta con F6 no tiene a quién volver: el botón sale apagado en vez de
## muerto.

@onready var _funds: Label = $Funds
@onready var _back: Button = $Back


func enter() -> void:
	_back.pressed.connect(func() -> void: Screens.back())
	_back.disabled = not Screens.has_previous()
	_funds.text = "FONDOS  %d" % Campaign.money
