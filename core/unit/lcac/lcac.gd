extends Unit
class_name LandingCraft

## Qué ES una lancha de desembarco: lleva carga, cruza y la deja en la arena. No
## navega — de eso se encarga [BoatController].
##
## **Es un contenedor que vuelve, no la unidad que sale.** El Harrier despega y
## ya es la unidad; ésta lleva, descarga y regresa, y si la hunden por el camino
## se pierde todo lo que iba dentro. Eso no hay que programarlo: la tropa no
## existe como nodo hasta que toca la arena, así que hundirla es que no llegue a
## existir nunca. La flota ya la descontó al embarcarla.
##
## **Desembarca por estar en la arena, no por haber llegado a su destino.**
##
## Parece lo mismo y no lo es. Atado al destino, redirigirla a mitad de travesía
## la dejaría con la tropa dentro y sin forma de volver a soltarla: haría falta
## una segunda pantalla para volver a elegir playa. Atado al terreno, la regla es
## una sola frase —*una lancha que se para en la arena, descarga*— y redirigirla
## funciona sin nada más: si el sitio nuevo es playa, desembarca allí; si es
## agua, se queda esperando órdenes con la carga puesta.

## Ha dejado la tropa en tierra. Lo escucha quien lleve la cuenta del
## desembarco; hoy nadie, y sale igual porque es el suceso del que cuelga todo
## lo que venga después.
signal unloaded(units: Array)
## Llegó a donde se le mandó, haya desembarcado o no. Es lo que el HUD escucha
## para retirar el aviso de la orden en curso.
signal order_fulfilled

@export_group("Desembarco")
## Cuánto por delante de la lancha sale el primero, en píxeles.
##
## Se cuenta de centro a centro, así que hay que descontar **los dos** medios
## cascos: 36 de la lancha más 22 del carro más largo que puede salir. Con los 52
## de la separación entre ellos el primero quedaba 6 px metido dentro de la proa,
## que es exactamente la imagen que esto tiene que evitar.
@export var disembark_lead: float = 64.0
## Cuánto va uno detrás de otro. Sale del largo del carro más grande —el Abrams
## mide 44— más un palmo, para que no se toquen.
@export var disembark_spacing: float = 52.0
## Cuántos pasos hacia atrás se prueban cuando a uno le toca caer en el agua.
@export var disembark_retries: int = 6

@onready var pilot: BoatController = $BoatController

## Lo que lleva dentro: `[{entry, scene, count}]`. Lo llena el dique antes de
## soltarla. Guarda la entrada de la flota además de la escena porque **una carga
## que vuelve hay que devolverla**, y para eso hace falta saber de qué casilla del
## pañol salió; con la escena sola habría que adivinarlo comparando recursos.
var _cargo: Array = []
## Su propia casilla en la flota. Es lo que la deja volver a estar disponible al
## atracar. Se la pone el dique al crearla.
var fleet_entry: Dictionary = {}
## De qué dique salió. Es a donde vuelve cuando se le da la orden sin decirle a
## cuál — que es el caso normal, porque hay un buque.
var home_deck: WellDeck = null
## A qué dique está volviendo ahora mismo, o `null`.
##
## **La vuelta es una intención, no una casualidad.** Antes se atracaba por
## pararse cerca de la popa, y eso obligaba al jugador a acertarle a un punto
## invisible en mitad del agua: si pinchaba sobre el casco —que es lo natural—
## quedaba fuera de radio y no pasaba nada, sin un solo aviso. Ahora el dique
## recoge a quien **venía a él**, así que basta con pedirlo y da igual dónde
## caiga el click.
var _returning_to: WellDeck = null
## Ya está en franquía: el tramo que queda es entrar derecho por el eje.
##
## Es un pestillo y no una comparación de cada fotograma **a propósito**. Con una
## condición viva —"¿estoy por detrás de tal línea?"— la lancha la cruzaba de
## camino al punto de franquía, se re-apuntaba al muelle que tenía justo al lado
## y pegaba un frenazo de través a media eslora del barco. Una vez en franquía,
## se entra; no se vuelve a discutir.
var _lined_up := false
## A qué distancia del punto de franquía se da por puesta en él.
@export var lineup_radius: float = 40.0
## A cuánto entra en el dique, en píxeles por segundo.
##
## Es la maniobra entera. Llegando a franquía a velocidad de crucero, la lancha
## tiene que dar media vuelta para encarar el buque y la curva le sale de 76 px
## de radio: se abría 65 px del eje y entraba de costado por la banda de
## estribor. Despacio la curva se cierra y entra derecha. Y además es lo que se
## hace: nadie atraca a toda máquina.
@export var docking_speed: float = 22.0
## La capa de tiles de la misión, para preguntar sobre qué está parada. Se busca
## una vez: es la misma durante toda la partida.
var _layer: TileMapLayer = null


func _ready() -> void:
	super._ready()
	add_to_group("unit_maritime")
	pilot.target_reached.connect(_on_arrived)


## El dique le mete la carga **antes** de soltarla al mundo. Mientras está dentro
## del buque no se pilota: es carga ella misma, y quien la mueve es el barco.
## La copia es **superficial a propósito**. En profundidad se copiarían también
## las casillas de la flota que van dentro de cada fila, y entonces devolver la
## carga al volver le sumaría las plazas a una copia que no lee nadie: la lancha
## atracaba, la interfaz decía que todo estaba en su sitio y los carros seguían
## contados como desembarcados. La fila sí es nuestra —la arma quien nos llama y
## la suelta—, la casilla no.
func load_cargo(cargo: Array) -> void:
	_cargo = cargo.duplicate()


## Ha atracado: se devuelve al pañol, ella y lo que siga llevando dentro.
##
## Lo hace **ella y no el dique**, porque es la que sabe de dónde salió cada
## cosa. El dique sabe recoger una lancha; de qué casilla de la flota vino esa
## lancha, y de cuáles los carros que lleva encima, sólo lo sabe ella.
##
## Y devuelve la carga entera: traerte a casa lo que no llegaste a desembarcar no
## puede costarte perderlo. Es la simétrica de hundirse, donde no vuelve nada.
func return_to_fleet() -> void:
	if not fleet_entry.is_empty():
		PlayerFleet.recall(fleet_entry)
		fleet_entry = {}
	for line: Dictionary in _cargo:
		var entry: Dictionary = line.get("entry", {})
		if entry.is_empty():
			continue
		for n in int(line.get("count", 0)):
			PlayerFleet.recall(entry)
	_cargo.clear()


## Cuántas unidades lleva. Lo pregunta el dique para no soltar una lancha vacía.
func cargo_count() -> int:
	var total := 0
	for line: Dictionary in _cargo:
		total += int(line.get("count", 0))
	return total


## El dique la suelta al mar y le pasa a dónde va. **La orden se le da aquí y no
## al crearla**: entre lo uno y lo otro está la salida por popa, y una orden de
## navegación peleando contra ese recorrido es el mismo fallo que ya costó la
## cubierta de vuelo.
func start_crossing(beach: Vector2) -> void:
	pilot.enable()
	pilot.set_target(beach)


## **Dentro del buque no obedece.** Mientras baja la rampa es carga, la mueve el
## barco, y una orden anotada ahí no llegaría a hacer nada: al soltarla,
## [method start_crossing] la pisaría con la playa. Salía bien por accidente —la
## playa es lo que se quería— y ese es justo el tipo de acierto que deja de serlo
## el día que se toque el orden de las llamadas.
func receive_move_order(target: Vector2) -> void:
	if not pilot.under_way():
		return
	# Mandarla a un sitio cancela la vuelta. Si no, seguiría persiguiendo al
	# buque cada fotograma y el punto que acaba de pedir el jugador no duraría
	# ni un frame — la lancha parecería no haber hecho caso.
	_returning_to = null
	_lined_up = false
	pilot.speed_limit = 0.0
	super.receive_move_order(target)
	pilot.set_target(target)


## Vuelve al dique del que salió.
func return_home() -> void:
	return_to(home_deck)


## Vuelve a un dique concreto. **Persigue al buque, no a un punto del agua**: el
## destino se recalcula cada fotograma contra la popa, así que la orden sigue
## valiendo con el barco navegando.
func return_to(deck: WellDeck) -> void:
	if deck == null or not is_instance_valid(deck) or not pilot.under_way():
		return
	set_attack_target(null)
	_returning_to = deck
	# Quien ya está por detrás del punto de franquía no tiene que ir a buscarlo:
	# sería navegar hacia atrás para volver sobre lo andado.
	_lined_up = deck.is_lined_up(global_position)
	pilot.set_target(_return_target())


## Si viene de camino a ese dique.
func is_returning_to(deck: WellDeck) -> bool:
	return _returning_to == deck and is_instance_valid(deck)


## Si además ya está en el tramo final, entrando por el eje. Es lo que pregunta
## el dique para saber a quién recoger: la que todavía va a ponerse en franquía
## le pasa cerca a toda máquina y no hay que tragársela de paso.
func is_docking_at(deck: WellDeck) -> bool:
	return _lined_up and is_returning_to(deck)


## A dónde toca ir ahora: primero ponerse en franquía por detrás, luego entrar.
func _return_target() -> Vector2:
	if _lined_up:
		return _returning_to.dock_point()
	var franquia: Vector2 = _returning_to.lineup_point()
	if global_position.distance_to(franquia) <= lineup_radius:
		_lined_up = true
		return _returning_to.dock_point()
	return franquia


## Tiene a donde volver. Sin dique, la acción no se ofrece: un botón que no puede
## cumplir lo que ofrece es peor que no tenerlo. Pasa con una lancha puesta a
## mano en una escena de prueba, que no salió de ningún buque.
func get_actions() -> PackedStringArray:
	if not is_instance_valid(home_deck):
		return PackedStringArray()
	return super.get_actions()


func _physics_process(_delta: float) -> void:
	# Sobre la arena vira en seco: al piloto hay que decírselo porque el terreno
	# no es cosa suya. Ver [member BoatController.aground].
	pilot.aground = _terrain_here() == MapTerrain.BEACH_KIND
	if _returning_to == null:
		return
	if not is_instance_valid(_returning_to):
		_returning_to = null
		_lined_up = false
		pilot.speed_limit = 0.0
		return
	pilot.set_target(_return_target())
	pilot.speed_limit = docking_speed if _lined_up else 0.0


func get_facing() -> float:
	return pilot.heading


func get_velocity() -> Vector2:
	return pilot.velocity


func get_move_destination() -> Variant:
	return pilot.target if pilot.has_target else null


## Se paró donde se le mandó. Si eso es arena, desembarca; si no, se queda.
func _on_arrived() -> void:
	order_fulfilled.emit()
	if _cargo.is_empty():
		return
	if _terrain_here() == MapTerrain.BEACH_KIND:
		_unload()


## Sobre qué está parada. Sin capa de tiles a la que preguntar devuelve arena:
## una escena de prueba sin mapa tiene que poder ver el desembarco, y negarse
## por no haber terreno sería un fallo silencioso justo en lo que se quiere ver.
func _terrain_here() -> String:
	if _layer == null:
		_layer = MapTerrain.find_layer(get_tree())
	if _layer == null:
		return MapTerrain.BEACH_KIND
	return MapTerrain.kind_under(_layer, global_position)


## Saca la tropa a la arena.
##
## **En columna por el propio rumbo, no en línea de frente.** Es lo que hace una
## rampa —los vehículos salen uno detrás de otro— y además es lo único que cae
## siempre en tierra: la lancha llegó apuntando a la playa, así que su rumbo
## señala tierra adentro y todo lo que se ponga sobre esa recta se aleja del
## agua. En línea de frente los de los flancos desembarcaban nadando, porque una
## celda de playa mide 32 px y la fila medía el triple.
func _unload() -> void:
	var world := get_parent()
	if world == null:
		return
	var ahead := Vector2.from_angle(pilot.heading)
	var salidos: Array = []
	var i := 0
	for line: Dictionary in _cargo:
		var scene: PackedScene = line.get("scene")
		if scene == null:
			continue
		for n in int(line.get("count", 0)):
			var unit := scene.instantiate() as Node2D
			if unit == null:
				continue
			world.add_child(unit)
			unit.global_position = _dry_spot(ahead, i)
			unit.rotation = rotation
			salidos.append(unit)
			i += 1
	_cargo.clear()
	unloaded.emit(salidos)


## Dónde poner al que hace el número `index` de la columna.
##
## La columna basta mientras quepa en la isla, y una isla se acaba: el último de
## una carga larga puede caer al agua por el otro lado. Por eso se comprueba y,
## si moja, se va acercando a la lancha hasta pisar seco. Apretarse contra el que
## va delante es más feo que ir en fila, pero mucho menos que aparecer flotando.
func _dry_spot(ahead: Vector2, index: int) -> Vector2:
	var wanted: float = disembark_lead + index * disembark_spacing
	# Se retrocede **hasta la lancha misma**, no hasta el hueco del primero de la
	# fila. Lo único seco con seguridad es donde ella está parada —ha varado en
	# la arena—, y tomando el hueco del primero como tope, el primero se quedaba
	# sin sitio al que retroceder y desembarcaba en el agua igual.
	var step: float = wanted / float(maxi(disembark_retries, 1))
	for back in disembark_retries + 1:
		var spot: Vector2 = global_position + ahead * (wanted - back * step)
		if _layer == null or MapTerrain.kind_under(_layer, spot) != MapTerrain.WATER_KIND:
			return spot
	return global_position
