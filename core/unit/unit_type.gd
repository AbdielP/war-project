extends Resource
class_name UnitType

## En qué medio se mueve. Es lo que decide qué armas pueden atacarla: un
## Sidewinder busca aviones, un Maverick busca blancos de superficie.
enum Domain { AIR, SURFACE }

@export var display_name: String = ""
@export var actions: PackedStringArray = []
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
