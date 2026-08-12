extends Resource
class_name WeaponType

## Definición compartida de un arma: existe una sola por tipo y los loadouts
## la referencian en vez de copiarla, así el nombre y el icono no se pueden
## desincronizar entre misiones.
##
## Aquí vive TODO lo que no depende de cómo vuela el proyectil: a qué distancia
## se puede tirar, qué daño hace y cuántas salen por andanada. Cómo vuela es
## asunto de la escena del proyectil, que tiene sus propios parámetros — así el
## mismo misil se puede reutilizar con otras cifras de daño y viceversa.

## Cómo se dispara. No es un detalle de presentación: cambia quién hace el daño
## y cuándo el avión rompe el ataque.
##
## Las firmas usan `WeaponType.FireMode` y no `FireMode` a secas, por lo mismo
## que `UnitType.Domain`.
enum FireMode {
	## Suelta un proyectil que vuela solo: misiles, bombas, cohetes. El daño lo
	## hace el proyectil al llegar.
	LAUNCHER,
	## Chorro continuo mientras se aguante el gatillo: cañones. No hay proyectil
	## que instanciar — un GAU-12 son ~60 balas por segundo, y sesenta nodos por
	## segundo no se sostienen. El daño se aplica desde el arma.
	SUSTAINED,
}

@export var display_name: String = ""
## Nombre para los botones de la barra de armas. Ahí sólo caben ~6 caracteres,
## así que se escribe a mano en vez de recortar el nombre largo: un arma nueva
## mal nombrada saldría cortada donde no toca.
@export var short_name: String = ""
## Código de brevedad OTAN que se canta al soltarla: "Rifle" un misil
## aire-superficie, "Fox Two" uno aire-aire de infrarrojos, "Pickle" una bomba,
## "Guns" el cañón. Va en el arma y no en una tabla del registro de eventos
## porque es parte de lo que el arma **es**: un arma nueva lo trae puesto y
## nadie tiene que acordarse de añadirla a una lista aparte. Vacío = no se canta
## nada y el registro sólo dice el nombre.
@export var brevity_code: String = ""
@export var icon: Texture2D

## Cómo busca el blanco lo que dispara esta arma. **Decide qué señuelo la
## engaña**: chaff contra radar, bengalas contra calor. Soltar el que no es no
## sirve de nada, y ahí está la decisión — hay que saber qué te tiraron.
##
## `NONE` es lo que no persigue nada: un cañón, una bomba tonta.
enum Seeker { NONE, RADAR, HEAT }

@export_group("Objetivos")
## Contra qué sirve. Un Sidewinder no le hace nada a un tanque y un Maverick
## no alcanza a un avión: sin esto el jugador puede disparar armas que jamás
## acertarían.
@export_flags("Aire", "Superficie") var targets: int = 3

@export_group("Alcance")
## Distancia mínima de tiro. Por debajo el arma aún no se ha estabilizado tras
## soltarse del ala y pasa de largo.
@export var min_range: float = 0.0
## Distancia máxima. Por encima el proyectil se queda sin combustible antes de
## llegar. No es un muro: es hasta dónde tiene sentido tirar.
@export var max_range: float = 200.0
## Cuánto puede estar el blanco fuera del morro para poder disparar. El arma
## sale hacia adelante, así que hay que enfilar antes de tirar.
@export var firing_arc_deg: float = 30.0
## Desde qué parte del blanco hay que atacarlo, en grados medidos **desde su
## cola**. 0 = justo detrás; 180 = por donde sea, incluso de frente.
##
## Es lo que separa las tres armas de un caza y lo que le da forma al combate
## aéreo. No es preferencia, es cómo funciona cada una:
##
##   - Un misil de radar da igual por dónde le entre: **180**.
##   - Uno de calor busca la tobera, así que hay que estar por detrás: **~60**.
##   - El cañón necesita estar en la cola y apuntando: **~45**.
##
## De ahí sale solo el arco del combate: se abre de lejos y de frente, se cruzan,
## y a partir de ahí es un duelo por ganar ángulo — y cada trozo de ángulo que
## ganas desbloquea un arma mejor.
##
## Contra algo que no se mueve no significa nada: un tanque no tiene cola. Las
## armas de ataque a tierra lo dejan en 180 y siguen comportándose igual que
## siempre.
@export_range(0.0, 180.0, 5.0) var max_aspect_deg: float = 180.0
## Alcance mínimo **contra lo que vuela**, cuando no es el mismo que contra
## tierra. −1 = usa `min_range` para todo.
##
## Existe por el cañón, y es un caso real y no un parche: contra un tanque el
## avión no debe meterse encima —hay una distancia por debajo de la cual atacar
## no compensa—, pero en un duelo aéreo a quemarropa es lo único que queda. Es la
## misma arma con dos usos, y **cada uno tiene su distancia**.
##
## Antes esto se resolvía subiendo `min_range` a secas, y eso ataba las dos cosas:
## bajarlo para el aire estropeaba el ataque a tierra —dónde rompía la pasada y
## hasta la puntería— sin que nadie tocara nada de tierra.
@export var air_min_range: float = -1.0
## Alcance máximo contra lo que vuela. −1 = usa `max_range` para todo.
##
## El mismo caso del cañón, por el otro extremo: contra un tanque quieto se
## ametralla desde lejos, pero **acertarle a un avión a esa distancia no pasa**.
## Sin esto, el cañón alcanzaba más lejos que el misil de corto alcance y el
## avión se ponía a los tiros a 400 px en vez de tirar el AIM-9 — el cañón era lo
## único que llegaba, así que "último recurso" no le quitaba el puesto.
@export var air_max_range: float = -1.0

@export_group("Daño")
@export var damage: float = 100.0
## Radio en px donde la explosión reparte daño, decayendo hacia el borde.
## 0 = sólo hace daño a lo que toca directamente.
@export var blast_radius: float = 0.0

@export_group("Lanzamiento")
@export var fire_mode: FireMode = FireMode.LAUNCHER
## Por qué guía va. Ver [enum Seeker].
@export var seeker: Seeker = Seeker.NONE

@export_subgroup("Contramedidas")
## Cuánto **suma** un señuelo a lo que el blanco ya se libra por su cuenta
## (`UnitType.ecm_evasion`). Son dos capas: el equipo de a bordo siempre está, y
## las cargas añaden encima mientras queden.
##
## Se tira una vez, al lanzar, y el resto es representación: si sale a favor el
## misil se irá tras una bengala a la vista de todos, y si no, va derecho.
## Decidirlo de una hace el resultado ajustable con un número, en vez de depender
## de cinco variables de vuelo que nadie puede predecir.
@export_range(0.0, 1.0, 0.05) var decoy_bonus: float = 0.55
## Cuánto baja esa probabilidad con cada misil más que se le tira **al mismo
## blanco**. La batería va afinando la solución de tiro: quedarse en la zona sale
## cada vez más caro, y eso es lo que empuja a sacar el avión de ahí.
@export_range(0.0, 1.0, 0.05) var decoy_defeat_step: float = 0.15
## Segundos que la batería recuerda lo aprendido sobre un blanco al que ha
## dejado de seguir. **No se olvida al salir del círculo**: si fuera así,
## bastaría con entrar y salir para volver a empezar de cero.
@export var fire_solution_memory: float = 25.0
@export var projectile_scene: PackedScene
## Cuántas armas salen de una vez. 1 = una a una, esperando a ver si hace
## falta la siguiente. 0 = todas las que queden — un bombardeo suelta la
## carga entera en una pasada.
@export var salvo_size: int = 1
## Radio en px de la dispersión del punto de apuntado de cada arma de la
## andanada. Es lo que convierte una tirada de bombas en un área batida en
## vez de N impactos en el mismo píxel.
##
## Sólo tiene sentido con armas que APUNTAN a algo. Una bomba tonta no apunta:
## cae donde la deja la inercia, y su dispersión sale de cómo se desprende cada
## una — está en la escena de la bomba, no aquí.
@export var salvo_spread: float = 0.0
## Segundos entre una arma y la siguiente DENTRO de la misma andanada. 0 = todas
## en el mismo instante.
##
## Es lo que convierte una tirada de bombas en una ristra: salen una detrás de
## otra mientras el avión avanza, así que caen repartidas en una línea sobre el
## blanco en vez de amontonarse. La longitud de esa línea no se configura — sale
## de este intervalo por la velocidad a la que vaya el avión.
@export var salvo_interval: float = 0.0
## Segundos de espera entre andanadas.
@export var reload_time: float = 1.0
## ¿El avión frena para alinearse con esta arma? Apuntar despacio da más tiempo
## en parámetros, pero deja al avión lento y cerca del blanco.
##
## Un cañón sí: hay que apuntar, y la pasada es larga. Una bomba tonta no: viene
## alineándose desde lejos y lo que necesita es cruzar rápido y salir de ahí —
## es el ataque en el que más se expone el avión.
@export var slows_to_aim: bool = true

@export_group("Fuego sostenido")
## Proyectiles por segundo. Sólo con `SUSTAINED`. Junto con `damage`, que sigue
## siendo el daño de UN proyectil, sale lo que hace el arma por segundo — pero
## sólo si entrasen todos, y casi nunca entran todos.
@export var rounds_per_second: float = 60.0
## Qué fracción de la ráfaga entra en el borde del alcance máximo. De cerca
## entra todo; según se abre la distancia, la dispersión reparte los impactos
## alrededor del blanco en vez de encima.
##
## Es lo que hace que la pasada importe y no baste con aguantar el gatillo:
## acercarse bien encarado mata, hostigar desde lejos hace cosquillas. El fallo
## sale de la geometría, no de una tirada.
@export_range(0.0, 1.0, 0.05) var long_range_accuracy: float = 0.25
## Cuánto se ensancha el cono una vez abierto fuego, para soltar el gatillo.
## Mismo truco que el compromiso de viraje del piloto: cuesta más empezar a
## disparar que seguir. Sin esto el blanco entra y sale del cono mientras el
## avión corrige y la ráfaga sale a tirones.
@export var arc_hysteresis: float = 2.0

@export_subgroup("Ráfagas")
## Segundos que dura una ráfaga antes de soltar el gatillo. **0 = sin ráfagas**:
## el arma tira sin parar mientras haya ocasión, que es como se comporta un
## cañón de avión durante la pasada — la pasada ya es la ráfaga.
##
## Con un valor por encima de 0 el arma corta sola y espera. Es lo propio de una
## batería antiaérea, que no tiene una pasada que le marque el ritmo: si no
## cortara, se quedaría escupiendo fuego continuo desde que te ve hasta que
## salgas, y ni suena ni se ve como un antiaéreo.
@export var burst_seconds: float = 0.0
## Segundos de silencio entre ráfagas. Sólo cuenta si `burst_seconds` > 0.
@export var burst_pause: float = 0.6


## El nombre corto si lo tiene; si no, el largo — un botón sin texto no se
## puede pulsar a ciegas.
func get_short_name() -> String:
	return short_name if short_name != "" else display_name


## ¿Puede atacar a algo que está en ese medio?
func can_engage_domain(domain: UnitType.Domain) -> bool:
	return (targets & (1 << domain)) != 0


## ¿La distancia da para tirar? Fuera de estos dos límites el disparo se
## desperdicia, así que quien dispara espera en vez de gastar munición.
func in_range(distance: float) -> bool:
	return distance >= min_range and distance <= max_range


## Igual que [method in_range] pero sabiendo contra qué se dispara: sólo cambia
## para las armas que tienen un mínimo propio contra blancos aéreos.
func in_range_against(distance: float, domain: UnitType.Domain) -> bool:
	return distance >= min_range_against(domain) \
		and distance <= max_range_against(domain)


## El alcance mínimo que toca según el blanco.
func min_range_against(domain: UnitType.Domain) -> float:
	if domain == UnitType.Domain.AIR and air_min_range >= 0.0:
		return air_min_range
	return min_range


## El alcance máximo que toca según el blanco.
func max_range_against(domain: UnitType.Domain) -> float:
	if domain == UnitType.Domain.AIR and air_max_range >= 0.0:
		return air_max_range
	return max_range


## ¿Exige atacar desde atrás? Un arma que entra por donde sea no obliga al vuelo
## a nada más que acercarse.
func needs_rear_aspect() -> bool:
	return max_aspect_deg < 180.0


## Desde dónde se le está entrando al blanco, en grados desde su cola: 0 es justo
## detrás y 180 justo de frente.
##
## Estático porque lo necesitan dos que no se conocen: el armamento, para saber
## si puede tirar, y el vuelo, para saber si tiene que seguir buscando ángulo.
static func aspect_to(shooter: Vector2, target: Unit) -> float:
	var tail := target.get_facing() + PI
	var to_shooter := (shooter - target.global_position).angle()
	return absf(rad_to_deg(angle_difference(tail, to_shooter)))
