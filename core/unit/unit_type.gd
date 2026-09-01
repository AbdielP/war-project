extends Resource
class_name UnitType

## En qué medio se mueve. Decide dos cosas: qué armas pueden atacarla —un
## Sidewinder busca aviones, un Maverick busca blancos de superficie— y cómo se
## anuncia en el mapa táctico.
##
## **Los valores nuevos van al final.** Se guardan como número en los `.tres`, y
## colar uno en medio le cambiaría el medio a las unidades ya escritas. Por eso
## `SURFACE` sigue valiendo 1 aunque ahora signifique sólo "por el suelo": lo
## que era un buque se marca a mano como `NAVAL`.
##
## Todo lo que no vuela sigue contando igual para el combate, que pregunta
## siempre por `AIR` y nunca por el resto.
enum Domain {
	AIR,       ## Vuela.
	SURFACE,   ## Va por el suelo.
	NAVAL,     ## Navega.
	SUBMERGED, ## Bajo el agua.
}

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
## La miniatura que la representa en su casilla del hangar.
##
## Es **otro dibujo** que el de `portrait_icon`, no el mismo achicado: aquel se
## ve a 20 px y éste a 13, y bajar pixel art figurativo tirando píxeles pierde
## tres de cada cuatro. Cada uno está dibujado a su tamaño.
##
## Vacío = se recurre a `portrait_icon`. Sirve de relleno mientras la miniatura
## de esa unidad no exista: se ve algo reconocible en vez de una casilla muda, y
## el día que la dibujes basta con ponerla aquí.
@export var hangar_icon: Texture2D
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
## Proyectiles que lleva ese cañón al despegar.
##
## Va en la aeronave y no en el arma porque **no es propiedad del cañón sino de
## lo que le cabe al aparato**: el mismo GAU-12 va en un avión con sitio para
## trescientos y podría ir en otro con la mitad. 0 = no se enseña la cuenta, que
## es lo que toca mientras nadie haya decidido cuántos lleva.
@export var cannon_rounds: int = 0
## Lo buena que es la aeronave, de un vistazo: 0 la barra vacía, 9 la barra
## llena.
##
## **Es una nota, no una estadística.** No sale de la velocidad, ni de la vida,
## ni de la defensa, y no lo usa nada del juego: existe para que el jugador
## compare dos aparatos en el hangar sin leerse una tabla. Por eso es un número
## a mano y no una cuenta — el día que se ajuste el equilibrio se sube o se baja
## aquí, sin tocar nada más.
##
## El tope es 9 porque la barra son diez dibujos, uno por valor. No hay
## conversión que hacer ni escala que ajustar: el número **es** el fotograma.
@export_range(0, 9, 1) var power: int = 0

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

@export_group("Desembarco")
## Cuántas plazas ocupa dentro de una lancha. 0 = no se embarca.
##
## **Es un reparto, no una cuenta.** Lo que la pantalla de tropas pregunta no es
## "cuántos mando" sino "qué cabe": un Abrams gasta la lancha entera y con lo
## mismo van tres LAV. Es la misma forma que el armamento —estaciones y qué
## cuelga de cada una—, y por eso vive aquí y no en una tabla de la pantalla: el
## tamaño es del modelo, y así no hay un segundo sitio que se quede viejo.
@export var deck_slots: int = 0
## Cuántas plazas tiene si **es** una lancha de desembarco. 0 = no lo es.
@export var cargo_slots: int = 0
## Llega a la playa por su cuenta, nadando, sin ocupar lancha.
##
## Es de una sola unidad —el Amtrac— y es justo lo que la hace distinta: puede ir
## sola, lenta y expuesta, o embarcada, rápida pero jugándose la carga entera si
## hunden la lancha. Sin esto, todo lo que desembarca sería lo mismo con otro
## número de plazas.
@export var amphibious: bool = false

@export_group("Puerto")
## Lo que cuesta comprarla en el arsenal. **Va en el tipo y no en una lista del
## puerto** porque el precio es del modelo: teniéndolo aquí, el arsenal enseña lo
## que hay y no existe una segunda tabla que se quede vieja el día que se toque
## una. 0 = no está a la venta.
@export var price: int = 0


## El [member thumb_zoom] como número, para dárselo a la cámara. Se traduce aquí
## y no en quien lo usa: el día que haga falta un 1/16 se añade al enum y a
## [constant THUMB_SCALES], y no hay que tocar nada más.
func thumb_scale() -> float:
	var i := int(thumb_zoom)
	return THUMB_SCALES[i] if i >= 0 and i < THUMB_SCALES.size() else 1.0


## Los tres caracteres que identifican al modelo de un vistazo: "AH-1W
## SuperCobra" acaba en "AH1". Manda [member short_name] cuando está puesto; sin
## él se recorta el primer token del nombre —el modelo, que es lo que distingue
## una unidad de otra— quitándole los separadores, que sólo gastan sitio.
##
## **Es estática y recibe el nombre en vez de leerlo de la unidad** porque hay
## dos sitios que la necesitan sin unidad viva: el cuadrito de una unidad
## perdida, que conserva el tipo y el nombre pero ya no tiene instancia, y el
## mapa, que la pinta mientras la unidad muere.
static func short_label(full: String, type: UnitType) -> String:
	if type != null and not type.short_name.is_empty():
		return type.short_name
	var cut := full.find(" ")
	var model := full if cut < 1 else full.substr(0, cut)
	model = model.replace("-", "").replace(".", "").to_upper()
	return model.substr(0, 3)
