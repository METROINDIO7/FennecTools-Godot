@tool
extends Resource
class_name DialogueSlotConfig
# Unified configuration resource for DialogueLauncher
# Allows defining both sequences (SEQUENCE) and chains (CHAIN) in a single resource
enum DialogueMode {
	CHAIN, # Generates consecutive IDs from start_id for count elements
	SEQUENCE # Uses a specific list of IDs
}
# === MODE SETTINGS ===
@export var mode: DialogueMode = DialogueMode.CHAIN
# === CHAIN SETTINGS ===
@export_group("Chain Mode", "chain")
@export var chain_start_id: int = 1
@export var chain_count: int = 1
# === SEQUENCE SETTINGS ===
@export_group("Sequence Mode", "sequence")
@export var sequence_ids: Array[int] = []
# === GENERAL SETTINGS ===
@export_group("Character & Presentation")
var character: String = ""
@export var character_group_name: String = "" 
@export var panel_override: PackedScene
# ✅ CHANGE: Expression is now a numeric ID instead of a string
@export var expression_id: int = -1  # -1 = no expression, 0+ = expression slot index

# === PLAYBACK SETTINGS ===
@export_group("Playback Settings")
@export var typewriter_cps: float = 40.0
@export var pre_entry_delay: float = 0.0
@export var between_chunks_delay: float = 0.3
@export var exit_delay: float = 0.0
@export var auto_free_on_exit: bool = true
# === PANEL CONTROL ===
@export_group("Panel Control")
@export var reuse_single_panel: bool = false
# === NEW: QUESTION/OBJECT INSTANTIATION SYSTEM ===
@export_group("Question & Object System")
# Scene to instantiate (question or object)
@export var instance_scene: PackedScene
# Target where it will be instantiated as a child (leave empty to use default)
@export var instance_target: NodePath

# === VOICELINE AUDIO SETTINGS ===
@export_group("Voiceline Audio", "voiceline_")
@export var voiceline_enabled: bool = false
@export var voiceline_stream: AudioStream
@export_range(0.5, 2.0, 0.1) var voiceline_pitch_min: float = 0.9
@export_range(0.5, 2.0, 0.1) var voiceline_pitch_max: float = 1.1
@export_range(0.0, 1.0, 0.1) var voiceline_volume: float = 0.7


# Main method that builds the items according to the selected mode
func build_items(context: Dictionary = {}) -> Array:
	match mode:
		DialogueMode.CHAIN:
			return build_chain_items()
		DialogueMode.SEQUENCE:
			return build_sequence_items()
		_:
			return []

# Builds items for CHAIN mode (consecutive IDs)
func build_chain_items() -> Array:
	var items: Array = []
	var n = max(0, chain_count)
	for i in range(n):
		var id_val = chain_start_id + i
		var item = {"id": id_val}
		items.append(item)
	return items

# Builds items for SEQUENCE mode (specific IDs)
func build_sequence_items() -> Array:
	var items: Array = []
	for id_val in sequence_ids:
		var item = {"id": int(id_val)}
		items.append(item)
	return items

# Helper method to get the total number of items without building the full array
func get_total_items() -> int:
	match mode:
		DialogueMode.CHAIN:
			return max(0, chain_count)
		DialogueMode.SEQUENCE:
			return sequence_ids.size()
		_:
			return 0

# Helper method to validate the configuration
func is_valid() -> bool:
	match mode:
		DialogueMode.CHAIN:
			return chain_count > 0
		DialogueMode.SEQUENCE:
			return sequence_ids.size() > 0
		_:
			return false

# Helper method to get debugging information
func get_debug_info() -> String:
	match mode:
		DialogueMode.CHAIN:
			return "CHAIN: %d items from ID %d (Expression ID: %d)" % [chain_count, chain_start_id, expression_id]
		DialogueMode.SEQUENCE:
			return "SEQUENCE: %d items %s (Expression ID: %d)" % [sequence_ids.size(), str(sequence_ids), expression_id]
		_:
			return "INVALID MODE"

# ✅ NEW: Check if it has a configured expression
func has_expression() -> bool:
	return expression_id >= 0

# ✅ NEW: Check if it has a scene to instantiate
func has_instance_scene() -> bool:
	return instance_scene != null

# ✅ NEW: Get instance debug information
func get_instance_debug_info() -> String:
	if not has_instance_scene():
		return "No instance scene"
	var target_info = "default parent"
	if instance_target != NodePath(""):
		target_info = "target: " + str(instance_target)
	return "Instance: " + instance_scene.resource_path.get_file() + " -> " + target_info

# ✅ NEW: Check if it has a voiceline configured
func has_voiceline() -> bool:
	return voiceline_enabled and voiceline_stream != null

# ✅ NEW: Get voiceline debug information
func get_voiceline_debug_info() -> String:
	if not has_voiceline():
		return "No voiceline"
	return "Voiceline: %s (pitch: %.1f-%.1f, vol: %.1f)" % [
		voiceline_stream.resource_path.get_file() if voiceline_stream else "null",
		voiceline_pitch_min,
		voiceline_pitch_max,
		voiceline_volume
	]

# ✅ NEW: Get a dictionary with the voiceline configuration
func get_voiceline_config() -> Dictionary:
	if not has_voiceline():
		return {}
	return {
		"stream": voiceline_stream,
		"volume": voiceline_volume,
		"pitch_min": voiceline_pitch_min,
		"pitch_max": voiceline_pitch_max
	}
