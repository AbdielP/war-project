extends Control

## La pantalla de carga. **No es una [Screen]**: no se navega a ella, la pone la
## carcasa mientras espera y sólo si la espera se nota. Ver [GameShell].

@onready var _bar: ProgressBar = $Bar


func set_progress(value: float) -> void:
	_bar.value = clampf(value, 0.0, 1.0) * 100.0
