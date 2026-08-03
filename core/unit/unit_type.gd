extends Resource
class_name UnitType

@export var display_name: String = ""
@export var actions: PackedStringArray = []
## Arma fija de la unidad: va siempre, no depende del armamento que se le
## cuelgue y no ocupa estación. Vacío = la unidad no tiene cañón.
@export var cannon: WeaponType
