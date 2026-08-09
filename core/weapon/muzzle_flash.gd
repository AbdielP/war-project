extends AnimatedSprite2D
class_name MuzzleFlash

## El fogonazo de un arma automática. Cuelga de la boca del cañón y no hace nada
## más que encenderse mientras se dispara.
##
## No sabe de armas, ni de munición, ni de a quién se le está tirando: sólo
## "ahora sale fuego" y "ahora ya no". Se engancha por señal al padre igual que
## [MissileExhaust] y [SmokeTrail], así que quien dispare no tiene que conocerlo.
##
## Dos animaciones sobre la misma tira, porque un cañón tiene dos momentos y se
## leen distinto:
##
##   1. `start` — el arranque. Se reproduce UNA vez: el arma se pone en marcha,
##      la llama crece de una chispa a la primera bocanada seria.
##   2. `sustain` — la ráfaga. CICLA mientras se siga disparando, alternando
##      llamaradas grandes y pequeñas.
##
## Por eso la segunda cicla y la primera no: un cañón de rotación suelta cientos
## de proyectiles por minuto, así que el fogonazo sostenido no es un destello por
## bala — que a esa cadencia sería un parpadeo ilegible — sino una llama que
## titila. Pero arrancar sí se ve una sola vez, y volver a enseñar ese crecimiento
## en mitad de la ráfaga delataría el bucle.
##
## Se coloca en el editor. Arranca invisible en juego, pero el nodo se sigue
## viendo en el editor: así se puede mover a mano hasta cuadrarlo con el arte sin
## tener que dispararlo para saber dónde cae.

## El arranque del arma. Se reproduce una vez y cede el paso.
@export var start_anim: StringName = &"start"
## La ráfaga. Cicla hasta que se deje de disparar.
@export var sustain_anim: StringName = &"sustain"

@export_group("Enganche")
## Quién abre y cierra el fuego. Por defecto el padre; se apunta a otro nodo
## cuando quien manda no es de quien cuelga — el fogonazo cuelga del avión pero
## lo manda su `WeaponSystem`.
@export var source_path: NodePath = ^".."
## Señal de esa fuente que abre fuego. Vacío = no se engancha y hay que llamar a
## `start_firing()` a mano.
@export var start_signal: StringName = &"firing_started"
## Señal que lo corta.
@export var stop_signal: StringName = &"firing_stopped"

var _firing := false


func _ready() -> void:
	visible = false
	animation_finished.connect(_on_animation_finished)
	# Un fogonazo es un sprite y no puede heredar de [EffectEmitter], pero se
	# engancha igual que el humo y la trazadora: misma función, un solo sitio.
	EffectEmitter.hook_up(self, source_path, start_signal, stop_signal,
		start_firing, stop_firing)


## Abre fuego. Llamarlo mientras ya se dispara no reinicia nada: seguir
## disparando es seguir disparando, y repetir el arranque daría un tirón en la
## llama justo en mitad de la ráfaga.
func start_firing() -> void:
	if _firing:
		return
	_firing = true
	visible = true
	play(start_anim)


## Alto el fuego. Se corta en seco, incluso a mitad del arranque: el arma ha
## dejado de disparar, y una llama creciendo sería mentira.
func stop_firing() -> void:
	_firing = false
	visible = false
	stop()


func _on_animation_finished() -> void:
	# El arranque terminó y se sigue disparando: entra la ráfaga.
	if animation == start_anim and _firing:
		play(sustain_anim)
