extends Resource
class_name UnitType

## En qué medio se mueve. Es lo que decide qué armas pueden atacarla: un
## Sidewinder busca aviones, un Maverick busca blancos de superficie.
enum Domain { AIR, SURFACE }

## Las escalas a las que puede verse una unidad en la cámara en vivo de la caja
## de selección. **Es un enum y no un número suelto** para que sólo quepan
## potencias de dos: la regla de escala entera del proyecto no admite un 0,3, y
## un desplegable no deja escribirlo. Ver [member thumb_zoom].
enum ThumbZoom { FULL, HALF, QUARTER, EIGHTH }

## Lo que vale cada escala, en el mismo orden que [enum ThumbZoom].
const THUMB_SCALES: PackedFloat32Array = [1.0, 0.5, 0.25, 0.125]

@export var display_name: String = ""
## Cómo se llama en el panel de desplegadas, donde el cuadrito mide 24 px y la
## fuente gasta 8 px por letra: **tres caracteres, ni uno más**. Va a mano y no
## recortado del nombre largo porque no hay regla que saque "LHD" de "Buque de
## asalto anfibio". Vacío = se recorta el nombre largo, que para los modelos con
## designación ("AH-1W SuperCobra") sale bien solo.
@export var short_name: String = ""
@export var actions: PackedStringArray = []
## Esta unidad **se puede visitar por dentro**: tiene hangar, pañol de munición,
## tropas embarcadas. Enciende el botón "A bordo" de la etiqueta de selección.
##
## Va aparte de [member actions] a propósito. Una acción es una orden que se le
## da a la unidad y se resuelve sola —"despegar", "fondear"—, y por eso viven en
## una lista de textos que el panel de acciones convierte en botones sueltos.
## Esto es otra cosa: es una **puerta a otra pantalla**, tiene su propio arte y
## su propio sitio en el HUD, y sólo puede haber una. Metida en la lista, saldría
## dibujada como un botón de texto más y volvería al panel del que la sacamos.
@export var has_interior: bool = false
## Cuánto se aparta la etiqueta de selección del centro de la unidad, **además**
## de donde esté puesta en la escena de la etiqueta.
##
## Existe porque el tamaño de las unidades no se parece en nada: la colocación de
## la escena está pensada contra un avión de 23×53 y sobre el LHD, que mide
## 160×304, cae dentro del casco. No es un caso que se pueda resolver con una
## sola medida buena para todos, y tampoco conviene deducirla del sprite: el
## dibujo no dice por qué lado hay sitio libre ni cuánto aire pide cada unidad.
##
## Se **suma**, así que dejarlo en cero es lo normal y sólo lo tocan las unidades
## grandes.
@export var tag_offset: Vector2 = Vector2.ZERO
## La silueta que la representa en el panel de desplegadas. Va en el tipo y no en
## la instancia: dos Harrier se dibujan igual. Vacío = no sale silueta, sólo el
## marco — es lo que pasa con las unidades ajenas, que en ese panel no aparecen.
@export var portrait_icon: Texture2D
## A qué escala se ve en la cámara en vivo de la caja de unidad seleccionada.
##
## **La caja no se dimensiona al sprite: el zoom se dimensiona a la caja.** Entre
## el helicóptero y el LHD hay un factor de 8, así que ninguna medida de hueco
## sirve para los dos. El hueco lo decide cuánto de los 640×384 se gasta —hoy
## 93×59— y esto ajusta cada unidad a él.
##
## **Sólo potencias de dos**, por la regla de escala entera del proyecto: 1.0,
## 0.5, 0.25, 0.125. Cualquier otro valor remuestrea a media rejilla y el pixel
## art se ensucia.
##
## Lo que tiene que caber no es el sprite, **es el círculo que barre al girar**
## —la unidad gira en vivo—, o sea la diagonal de su silueta: entre 49 (T-14) y
## 69 (Tunguska) para las pequeñas, y 247 para el LHD.
##
## **El valor por omisión es 1:1 y bajarlo es el último recurso**, porque a 0.5
## se descarta la mitad de los píxeles y la unidad se ve peor aquí que en el
## mapa. Con 59 px de alto todas las pequeñas entran a 1:1 salvo unos píxeles de
## las puntas en el ángulo diagonal justo, y eso no se nota; el LHD, que no tiene
## arreglo, va a 0.25. **Recortar no es un fallo** — un trozo de la cubierta del
## LHD dice "barco grande" mejor que el barco entero y diminuto.
@export var thumb_zoom: UnitType.ThumbZoom = UnitType.ThumbZoom.FULL
## Arma fija de la unidad: va siempre, no depende del armamento que se le
## cuelgue y no ocupa estación. Vacío = la unidad no tiene cañón.
@export var cannon: WeaponType

@export_group("Combate")
## Las firmas usan `UnitType.Domain` y no `Domain` a secas: dentro del propio
## archivo GDScript trata el enum local como un tipo distinto del que ven los
## demás, y las llamadas de fuera no compilan.
@export var domain: UnitType.Domain = UnitType.Domain.SURFACE
## Cuánto aguanta. Un AGM-65 pega 120, así que un tanque de 100 muere de uno
## y algo más grande necesita varios.
@export var max_health: float = 100.0
## Lo que se libra de un misil guiado **sin gastar nada**: su equipo de guerra
## electrónica de serie. Los señuelos suman encima de esto, así que un avión sin
## cargas no queda vendido del todo — le queda lo suyo.
##
## Va en el tipo y no en la instancia, como `max_health`: es lo que trae el
## modelo de fábrica, y así el día que haya menú de mejoras se sube para todos
## los de ese modelo de una vez. Lo que sí es de cada unidad es el bando, porque
## el mismo avión puede cambiarlo.
@export_range(0.0, 1.0, 0.05) var ecm_evasion: float = 0.0


## El [member thumb_zoom] como número, para dárselo a la cámara. Se traduce aquí
## y no en quien lo usa: el día que haga falta un 1/16 se añade al enum y a
## [constant THUMB_SCALES], y no hay que tocar nada más.
func thumb_scale() -> float:
	var i := int(thumb_zoom)
	return THUMB_SCALES[i] if i >= 0 and i < THUMB_SCALES.size() else 1.0
