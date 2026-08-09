extends EffectEmitter
class_name TracerStream

## Las trazadoras de una ráfaga. Va soltando [Tracer] por la boca del arma
## mientras se dispare.
##
## Lo suyo, frente al humo, es que **siembra por cadencia y no por distancia**:
## un cañón dispara a su ritmo aunque el avión frene, y si el avión se parase en
## seco el humo dejaría de salir pero la ráfaga no. Es la única diferencia entre
## los dos emisores, y por eso es lo único que hay aquí.
##
## No son las balas: son una de cada tantas, que es lo que es una trazadora. Las
## balas de verdad no existen como nodos — el daño lo reparte el arma.

## Trazos por segundo. No es la cadencia real del cañón (~60/s), es cada cuántas
## balas se ve una. Subirlo llena la línea de fuego; bajarlo la deja punteada.
@export var tracers_per_second: float = 12.0

var _until_next: float = 0.0


func _begin() -> void:
	# El primero sale ya: esperar el intervalo dejaría un hueco entre el
	# fogonazo y la primera trazadora.
	_until_next = 0.0


func _physics_process(delta: float) -> void:
	if tracers_per_second <= 0.0:
		return
	_until_next -= delta
	var interval := 1.0 / tracers_per_second
	# Un `while` y no un `if`: con cadencias por encima de los fps toca soltar
	# más de uno en el mismo frame, y el resto se arrastra al siguiente en vez
	# de perderse — así la cadencia real no queda limitada por los fps.
	var heading := _emit_heading()
	var reach := _reach()
	while _until_next <= 0.0:
		var tracer := _spawn(global_position, heading) as Tracer
		if tracer != null:
			# El rumbo se le da aparte de colocarlo: cuando entra en el árbol
			# todavía no está puesto, y leerlo de su rotación en `_ready()` lo
			# mandaría siempre hacia +X.
			tracer.launch(heading, reach)
		_until_next += interval


## Hasta dónde tienen que llegar los trazos de este momento: donde esté el
## blanco. Se le pregunta al arma en vez de llevarlo apuntado aquí — el alcance
## del cañón ya está escrito en el arma y repetirlo sería tener el mismo número
## en dos sitios, que es como se acaba con dos verdades distintas.
##
## Se pregunta por si acaso y no se da por hecho: esto se cuelga de lo que sea
## que dispare, y no todo lo que dispara es un `WeaponSystem`.
func _reach() -> float:
	if _source != null and _source.has_method(&"get_firing_distance"):
		return _source.get_firing_distance()
	return 0.0
