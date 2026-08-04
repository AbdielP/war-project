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

@export var display_name: String = ""
## Nombre para los botones de la barra de armas. Ahí sólo caben ~6 caracteres,
## así que se escribe a mano en vez de recortar el nombre largo: un arma nueva
## mal nombrada saldría cortada donde no toca.
@export var short_name: String = ""
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
@export var projectile_scene: PackedScene
## Cuántas armas salen de una vez. 1 = una a una, esperando a ver si hace
## falta la siguiente. 0 = todas las que queden — un bombardeo suelta la
## carga entera en una pasada.
@export var salvo_size: int = 1
## Radio en px de la dispersión del punto de apuntado de cada arma de la
## andanada. Es lo que convierte una tirada de bombas en un área batida en
## vez de N impactos en el mismo píxel.
@export var salvo_spread: float = 0.0
## Segundos de espera entre andanadas.
@export var reload_time: float = 1.0


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
