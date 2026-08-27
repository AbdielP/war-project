extends RefCounted
class_name DevBoot

## El arranque de desarrollo: a qué pantalla ir al abrir el proyecto, y con qué
## estado. Existe porque F6 te lleva a *una pantalla*, pero no a una pantalla
## **en una situación concreta** — "el Puerto con 50.000 y el Cobra
## desbloqueado", "el debriefing de una misión perdida".
##
## Se lee de `res://dev_boot.cfg`, que **no va al repositorio**: es de tu
## máquina y de tu día de trabajo, no del juego. Si no existe, no pasa nada y se
## arranca por el principio.
##
## **Y no llega nunca a una versión publicada**, sin tener que acordarse de
## quitarlo: se consulta bajo `OS.has_feature("editor")`, que es falso en
## cualquier build exportada.
##
## También se acepta por línea de comandos, que es lo que sirve para lanzar una
## prueba automática en una pantalla concreta:
## [codeblock]
## godot --screen=port --instant
## [/codeblock]

const PATH := "res://dev_boot.cfg"


## Devuelve `{screen, context, instant}`. `screen` es un [enum Screens.Id], o −1
## si no se pidió ninguna.
static func read() -> Dictionary:
	var out := {"screen": -1, "context": {}, "instant": false}
	if not OS.has_feature("editor"):
		return out
	_read_file(out)
	_read_cmdline(out)
	if out["screen"] >= 0:
		print("[dev_boot] arrancando en '%s'" % Screens.name_of(out["screen"]))
	return out


static func _read_file(out: Dictionary) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	var wanted := str(cfg.get_value("boot", "screen", ""))
	if wanted != "":
		var id := Screens.id_from_name(wanted)
		if id < 0:
			push_warning("[dev_boot] pantalla desconocida: '%s'" % wanted)
		else:
			out["screen"] = id
	out["instant"] = bool(cfg.get_value("boot", "instant", out["instant"]))
	# Todo lo que haya en [context] se le pasa tal cual a la pantalla. No hay
	# lista de claves permitidas a propósito: cada pantalla sabe qué mirar y las
	# que no entiende una clave la ignoran.
	var ctx := {}
	var keys: PackedStringArray = cfg.get_section_keys("context") if cfg.has_section("context") else PackedStringArray()
	for key in keys:
		ctx[key] = cfg.get_value("context", key)
	out["context"] = ctx


static func _read_cmdline(out: Dictionary) -> void:
	for arg in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg == "--instant":
			out["instant"] = true
		elif arg.begins_with("--screen="):
			var id := Screens.id_from_name(arg.substr("--screen=".length()))
			if id >= 0:
				out["screen"] = id
