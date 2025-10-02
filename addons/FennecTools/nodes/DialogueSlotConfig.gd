@tool
extends Resource
class_name DialogueSlotConfig

# Recurso de configuración unificado para DialogueLauncher
# Permite definir tanto secuencias (SEQUENCE) como cadenas (CHAIN) en un solo recurso

enum DialogueMode {
	CHAIN, # Genera IDs consecutivos desde start_id por count elementos
	SEQUENCE # Usa lista específica de IDs
}

# === CONFIGURACIÓN DEL MODO ===
@export var mode: DialogueMode = DialogueMode.CHAIN

# === CONFIGURACIÓN CHAIN ===
@export_group("Chain Mode", "chain_")
@export var chain_start_id: int = 1
@export var chain_count: int = 1

# === CONFIGURACIÓN SEQUENCE ===
@export_group("Sequence Mode", "sequence_")
@export var sequence_ids: Array[int] = []

# === CONFIGURACIÓN GENERAL ===
@export_group("Character & Presentation")
@export var character: String = ""
@export var panel_override: PackedScene
@export var question_scene: PackedScene
@export var expression: String = ""

# === CONFIGURACIÓN DE REPRODUCCIÓN ===
@export_group("Playback Settings")
@export var typewriter_cps: float = 40.0
@export var pre_entry_delay: float = 0.0
@export var between_chunks_delay: float = 0.3
@export var exit_delay: float = 0.0
@export var auto_free_on_exit: bool = true

# === CONTROL DE PANEL ===
@export_group("Panel Control")
@export var reuse_single_panel: bool = false

# === NUEVO: SISTEMA DE INSTANCIACIÓN DE PREGUNTAS/OBJETOS ===
@export_group("Question & Object System")
# Escena a instanciar (pregunta u objeto)
@export var instance_scene: PackedScene
# Desactivar avance automático cuando se instancia una escena
@export var disable_auto_advance_when_instanced: bool = false

# Método principal que construye los items según el modo seleccionado
func build_items(context: Dictionary = {}) -> Array:
	match mode:
		DialogueMode.CHAIN:
			return _build_chain_items()
		DialogueMode.SEQUENCE:
			return _build_sequence_items()
		_:
			return []

# Construye items para modo CHAIN (IDs consecutivos)
func _build_chain_items() -> Array:
	var items: Array = []
	var n = max(0, chain_count)
	for i in range(n):
		var id_val = chain_start_id + i
		var item = {"id": id_val}
		items.append(item)
	return items

# Construye items para modo SEQUENCE (IDs específicos)
func _build_sequence_items() -> Array:
	var items: Array = []
	for id_val in sequence_ids:
		var item = {"id": int(id_val)}
		items.append(item)
	return items

# Método helper para obtener el total de items sin construir el array completo
func get_total_items() -> int:
	match mode:
		DialogueMode.CHAIN:
			return max(0, chain_count)
		DialogueMode.SEQUENCE:
			return sequence_ids.size()
		_:
			return 0

# Método helper para validar la configuración
func is_valid() -> bool:
	match mode:
		DialogueMode.CHAIN:
			return chain_count > 0
		DialogueMode.SEQUENCE:
			return sequence_ids.size() > 0
		_:
			return false

# Método helper para obtener información de depuración
func get_debug_info() -> String:
	match mode:
		DialogueMode.CHAIN:
			return "CHAIN: %d items from ID %d" % [chain_count, chain_start_id]
		DialogueMode.SEQUENCE:
			return "SEQUENCE: %d items %s" % [sequence_ids.size(), str(sequence_ids)]
		_:
			return "INVALID MODE"

# NUEVO: Verificar si este slot instancia una escena
func has_instance_scene() -> bool:
	return instance_scene != null or question_scene != null

# NUEVO: Obtener la escena a instanciar (prioriza instance_scene sobre question_scene)
func get_instance_scene() -> PackedScene:
	if instance_scene:
		return instance_scene
	return question_scene
