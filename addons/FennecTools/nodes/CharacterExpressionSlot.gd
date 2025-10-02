@tool
extends Resource
class_name CharacterExpressionSlot

# Recurso que define una expresión con un nombre y una lista de entradas (acciones) sobre nodos

@export var name: String = "default"
@export var entries: Array[CharacterExpressionEntry] = []

func is_valid() -> bool:
	return name.strip_edges() != ""

func get_debug_info() -> String:
	var s := "Expression '%s' with %d entries\n" % [name, entries.size()]
	for e in entries:
		if e:
			s += "  - %s\n" % e.get_debug_string()
	return s
