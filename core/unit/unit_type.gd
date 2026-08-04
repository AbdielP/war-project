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
