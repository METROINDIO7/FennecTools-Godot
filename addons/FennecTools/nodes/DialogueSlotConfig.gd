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

# === SOUND SETTINGS ===
@export_group("Sound Settings", "sound_")
@export var sound_enabled: bool = false
@export var sound_effect: AudioStream
@export var sound_frequency: int = 3  # How often it is played (in characters)
@export_range(0.5, 2.0, 0.1) var sound_pitch_min: float = 0.9
@export_range(0.5, 2.0, 0.1) var sound_pitch_max: float = 1.1
@export_range(0.0, 1.0, 0.1) var sound_volume: float = 0.7


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

# ✅ NEW: Check if it has sound configured
func has_sound() -> bool:
	return sound_enabled and sound_effect != null

# ✅ NEW: Get sound debug information
func get_sound_debug_info() -> String:
	if not has_sound():
		return "No sound"
	return "Sound: %s (freq: %d, pitch: %.1f-%.1f, vol: %.1f)" % [
		sound_effect.resource_path.get_file() if sound_effect else "null",
		sound_frequency,
		sound_pitch_min,
		sound_pitch_max,
		sound_volume
	]
