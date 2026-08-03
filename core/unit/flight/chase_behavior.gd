extends Node
class_name ChaseBehavior

## Decide A DÓNDE va el avión cuando persigue a alguien: detrás del objetivo,
## corrigiendo el rumbo mientras el objetivo se mueve.
##
## Hermano de `OrbitBehavior` — los dos le dan puntos al mismo piloto, así que
## nunca deben correr a la vez. Quien reciba la orden decide cuál manda.
##
## No dispara ni sabe de armas: sólo lleva el avión hasta el objetivo.

## El objetivo dejó de existir. Quien escuche decide qué hacer con el avión;
## aquí ya se apagó solo.
signal target_lost

@export_group("Enlace")
@export var pilot_path: NodePath = ^"../PlaneController"

var target: Unit = null

var _pilot: PlaneController


func _ready() -> void:
	_pilot = get_node_or_null(pilot_path) as PlaneController
	set_process(false)


func pursue(new_target: Unit) -> void:
	if _pilot == null or not is_instance_valid(new_target):
		return
	target = new_target
	# `set_target` y no `update_target`: es un destino nuevo, y el avión tiene
	# que replantear hacia qué lado vira desde cero.
	_pilot.set_target(target.global_position)
	set_process(true)


func stop() -> void:
	target = null
	set_process(false)


func _process(_delta: float) -> void:
	if not is_instance_valid(target):
		# Se apaga antes de avisar: quien escuche puede darle otra orden al
		# avión sin que este nodo se la pise en el frame siguiente.
		target = null
		set_process(false)
		target_lost.emit()
		return
	# Corrige el punto sin replantear el viraje ya comprometido.
	_pilot.update_target(target.global_position)
