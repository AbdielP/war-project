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

@export_group("Daño")
@export var damage: float = 100.0
## Radio en px donde la explosión reparte daño, decayendo hacia el borde.
## 0 = sólo hace daño a lo que toca directamente.
@export var blast_radius: float = 0.0

@export_group("Lanzamiento")
@export var fire_mode: FireMode = FireMode.LAUNCHER
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
