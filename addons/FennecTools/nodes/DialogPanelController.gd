@tool
extends Control

# Dialog Panel/Bubble controller
# - Entry/Exit animations
# - Typewriter effect with configurable speed and delays
# - Optional speaker label visibility using a CheckButton
# - RichTextLabel visibility progress control
# - Configurable text alignment options
# - Ability to pause exit until an external node (e.g., question UI) is removed
# - Exposed methods to be controlled from a dialogue editor

signal dialog_started(text: String, speaker: String)
signal chunk_shown(index: int, total: int)
signal dialog_completed()
signal dialog_exited()
# Additional signal for compatibility with the old launcher
signal dialogue_finished()

@export var auto_play_entry: bool = true
@export var auto_free_on_exit: bool = true

# Assignable node paths
@export var label_path: NodePath
@export var richtext_path: NodePath
@export var anim_player_path: NodePath

# Animation names
@export var entry_animation: String = "show_dialog"
@export var exit_animation: String = "hide_dialog"

# Typewriter settings
@export var chars_per_second: float = 40.0
@export var pre_entry_delay: float = 0.0
@export var between_chunks_delay: float = 0.3
@export var exit_delay: float = 0.0
@export var chunk_delimiter: String = "|"   # Split text into visible chunks using this delimiter

# Label visibility default when no toggle is provided
@export var show_speaker_label: bool = true

# === ALIGNMENT SETTINGS ===
@export_group("Text Alignment and Margin")

# Horizontal alignment for the text (RichTextLabel)
enum TextHorizontalAlign {
	LEFT,
	CENTER, 
	RIGHT,
	FILL
}

@export var text_alignment: TextHorizontalAlign = TextHorizontalAlign.LEFT

@export var Margin_top: int = 0
@export var Margin_bottom: int = 0
@export var Margin_left: int = 0
@export var Margin_right: int = 0

# === SOUND SETTINGS ===
@export_group("Sound")
@export var sound_enabled: bool = false  # Global control to enable/disable sounds
@export var external_sound_player: NodePath # ✅ NEW: To assign an external AudioStreamPlayer
var _current_sound_config: Dictionary = {}

# Audio player for text sounds
var _text_sound_player: AudioStreamPlayer # ✅ This will be the player, it can be external or internal
var _char_count_since_last_sound: int = 0

# Internal references
var _label: Label
var _rtl: RichTextLabel
var _anim: AnimationPlayer
var _original_rtl_stylebox: StyleBox  # To save the original StyleBox of the RichTextLabel

# Internal state
var _pending_text: String = ""
var _pending_speaker: String = ""
var _chunks: PackedStringArray = PackedStringArray()
var _current_chunk: int = -1
var _is_revealing: bool = false
var _cancel_reveal: bool = false
var _block_node: Node = null

# === DYNAMIC NAME SYSTEM ===
# Dictionary to store custom names assigned by code
# Format: {"character_name": "Displayed Name"}
var _custom_character_names: Dictionary = {}

func _ready() -> void:
	if label_path != NodePath(""):
		_label = get_node_or_null(label_path) as Label
	if richtext_path != NodePath(""):
		_rtl = get_node_or_null(richtext_path) as RichTextLabel
	if anim_player_path != NodePath(""):
		_anim = get_node_or_null(anim_player_path) as AnimationPlayer
		if _anim and not _anim.animation_finished.is_connected(_on_anim_finished):
			_anim.animation_finished.connect(_on_anim_finished)

	# Make sure RichTextLabel starts hidden text
	if _rtl:
		_rtl.visible_characters = 0
		# Save the original StyleBox of the RichTextLabel
		_original_rtl_stylebox = _rtl.get_theme_stylebox("normal")
	
	# Apply initial alignment settings
	_apply_alignment_settings()
	
	# Connect additional signal for compatibility
	if not dialog_completed.is_connected(_on_dialog_completed):
		dialog_completed.connect(_on_dialog_completed)
	
	# ✅ NEW: Initialize sound system (now done after nodes are ready)
	call_deferred("_setup_sound_system")

# ==============
# SOUND SYSTEM
# ==============

func _setup_sound_system() -> void:
	"""Configures the sound system"""
	if external_sound_player != NodePath(""):
		# Try to use the external node
		_text_sound_player = get_node_or_null(external_sound_player)
		if not (_text_sound_player and _text_sound_player is AudioStreamPlayer):
			_create_internal_sound_player()
	else:
		# Create an internal one
		_create_internal_sound_player()

func _create_internal_sound_player() -> void:
	"""Creates an internal AudioStreamPlayer"""
	_text_sound_player = AudioStreamPlayer.new()
	_text_sound_player.name = "TextSoundPlayer"
	add_child(_text_sound_player)
	_text_sound_player.process_mode = Node.PROCESS_MODE_ALWAYS

func set_sound_config(config: Dictionary) -> void:
	"""Configures the sound parameters from the DialogueLauncher"""
	_current_sound_config = config

func _play_text_sound() -> void:
	"""Plays the text sound according to the current configuration"""
	if not sound_enabled:
		return
	
	if _current_sound_config.is_empty():
		return
	
	# ✅ NEW: Check if the player is available
	if not _text_sound_player:
		return
	
	var sound_effect: AudioStream = _current_sound_config.get("sound_effect")
	if not sound_effect:
		return
	
	# Configure the audio player
	_text_sound_player.stream = sound_effect
	_text_sound_player.volume_db = linear_to_db(_current_sound_config.get("sound_volume", 0.7))
	
	# Apply random pitch variation
	var pitch_min: float = _current_sound_config.get("sound_pitch_min", 0.9)
	var pitch_max: float = _current_sound_config.get("sound_pitch_max", 1.1)
	_text_sound_player.pitch_scale = randf_range(pitch_min, pitch_max)
	
	# Play sound
	_text_sound_player.play()

func _should_play_sound() -> bool:
	"""Determines if the sound should be played based on the configured frequency"""
	if not _current_sound_config.get("sound_enabled", false):
		return false
	
	var frequency: int = _current_sound_config.get("sound_frequency", 3)
	if frequency <= 0:
		return false
	
	_char_count_since_last_sound += 1
	if _char_count_since_last_sound >= frequency:
		_char_count_since_last_sound = 0
		return true
	
	return false

func _reset_sound_counter() -> void:
	"""Resets the character counter for sounds"""
	_char_count_since_last_sound = 0

# ==============
# Compatibility with old launcher
# ==============
func _on_dialog_completed():
	# Emit compatibility signal
	dialogue_finished.emit()

# Method to reset the panel without exit animation (for reuse)
func reset_for_reuse() -> void:
	_pending_text = ""
	_pending_speaker = ""
	_chunks = PackedStringArray()
	_current_chunk = -1
	_is_revealing = false
	_cancel_reveal = false
	_block_node = null
	
	# Reset visual state
	if _rtl:
		_rtl.visible_characters = 0
		_rtl.text = ""
	
	if _label:
		_label.text = ""
	
	# ✅ NEW: Reset sound system
	_reset_sound_counter()
	_current_sound_config = {}
	
	# Reset animations if necessary
	if _anim:
		_anim.stop()
		# If "reset" or "idle" animation exists, play it
		if _anim.has_animation("reset"):
			_anim.play("reset")
		elif _anim.has_animation("idle"):
			_anim.play("idle")
		elif _anim.has_animation(entry_animation):
			# Play entry animation from the beginning but paused
			_anim.play(entry_animation)
			_anim.seek(0.0)
			_anim.stop()

# ==============
# ALIGNMENT METHODS
# ==============

func _apply_alignment_settings() -> void:
	_apply_text_alignment()
	_apply_speaker_alignment()

func _apply_text_alignment() -> void:
	# Horizontal text alignment is handled with BBCode tags
	# It will be applied when the text is set
	pass

func _apply_speaker_alignment() -> void:
	if not _rtl:
		return
	
	# Calculate the current text height
	var text_height := _rtl.get_content_height()
	var rect_height := _rtl.size.y
	if text_height <= 0:
		text_height = rect_height
	
	# Difference between the available height and the text
	var extra_space := rect_height - text_height
	
	# Dynamic adjustment ONLY for the top, using the user's value as a preference
	var top_margin := clampi(Margin_top, 0, max(0, extra_space))
	
	# Create StyleBoxEmpty with all configured margins
	var style_box = StyleBoxEmpty.new()
	style_box.content_margin_top = top_margin
	style_box.content_margin_bottom = Margin_bottom
	style_box.content_margin_left = Margin_left
	style_box.content_margin_right = Margin_right
	
	# Apply the new stylebox
	_rtl.add_theme_stylebox_override("normal", style_box)

# Helper function to wrap text with horizontal alignment BBCode
func _wrap_text_with_alignment(text: String) -> String:
	var wrapped_text = text
	
	match text_alignment:
		TextHorizontalAlign.LEFT:
			# By default it is already left-aligned, no tags needed
			wrapped_text = text
		TextHorizontalAlign.CENTER:
			wrapped_text = "[center]" + text + "[/center]"
		TextHorizontalAlign.RIGHT:
			wrapped_text = "[right]" + text + "[/right]"
		TextHorizontalAlign.FILL:
			wrapped_text = "[fill]" + text + "[/fill]"
	
	return wrapped_text

# Public methods to change alignments
func set_text_alignment(alignment: TextHorizontalAlign) -> void:
	text_alignment = alignment
	_apply_text_alignment()

# Method to configure custom vertical spacings
func set_vertical_spacings(top: int) -> void:
	Margin_top = max(0, top)
	_apply_speaker_alignment()

# ==============
# Public API
# ==============

# Local API for panel-level dynamic names
func set_character_name(character_key: String, display_name: String) -> void:
	var key := character_key.strip_edges().to_lower()
	var name := display_name.strip_edges()
	if key != "":
		if name != "":
			_custom_character_names[key] = name
		else:
			_custom_character_names.erase(key)

func get_character_name(character_key: String) -> String:
	var key := character_key.strip_edges().to_lower()
	return _custom_character_names.get(key, "")

func clear_character_names() -> void:
	_custom_character_names.clear()

# Plays a dialog with optional speaker name.
# Supports chunked text separated by chunk_delimiter. Returns when all chunks are finished.
# Now supports @p:character_name commands in text and speaker
func play_dialog(text: String, speaker: String = "") -> void:
	# Process special commands in the text and the speaker
	var processed_text := _process_text_commands(text)
	var processed_speaker := _process_speaker_command(speaker)
	
	_pending_text = processed_text
	_pending_speaker = processed_speaker
	# Prepare chunks
	_chunks = PackedStringArray()
	if chunk_delimiter != "" and processed_text.find(chunk_delimiter) != -1:
		_chunks = processed_text.split(chunk_delimiter, false)
	else:
		_chunks = PackedStringArray([processed_text])
	_current_chunk = -1

	# Apply horizontal alignment to all chunks
	for i in range(_chunks.size()):
		_chunks[i] = _wrap_text_with_alignment(_chunks[i])

	# Label handling with vertical alignment
	if _label:
		_label.text = processed_speaker
		_label.visible = _should_show_label()
	
	# Apply vertical alignment to the RichTextLabel
	_apply_speaker_alignment()

	# Entry
	if pre_entry_delay > 0.0:
		await get_tree().create_timer(pre_entry_delay).timeout
	if auto_play_entry:
		await _play_entry()

	dialog_started.emit(processed_text, processed_speaker)
	# Show chunks
	for i in range(_chunks.size()):
		_current_chunk = i
		await _reveal_text(_chunks[i])
		chunk_shown.emit(i, _chunks.size())
		if i < _chunks.size() - 1:
			if between_chunks_delay > 0.0:
				await get_tree().create_timer(between_chunks_delay).timeout

	dialog_completed.emit()

# Request exit. Optionally waits for a node to be removed before playing exit animation.
# Example: await request_exit(question_node)
func request_exit(wait_for_node: Node = null) -> void:
	_block_node = wait_for_node
	if is_instance_valid(_block_node):
		# Wait until it's removed from the tree
		while is_instance_valid(_block_node) and _block_node.get_parent() != null:
			await get_tree().process_frame
		_block_node = null
	if exit_delay > 0.0:
		await get_tree().create_timer(exit_delay).timeout
	await _play_exit()
	if auto_free_on_exit:
		queue_free()
	dialog_exited.emit()

# Immediately reveal entire current chunk or advance to next if already revealed.
func skip_or_advance() -> void:
	if not _rtl:
		return
	if _is_revealing:
		_cancel_reveal = true
		_rtl.visible_characters = _total_chars()
	else:
		# Advance to next chunk if any
		if _current_chunk >= 0 and _current_chunk < _chunks.size() - 1:
			_current_chunk += 1
			_reveal_text(_chunks[_current_chunk])

# Allows external control of visibility progress 0..1
func set_visibility_progress(progress: float) -> void:
	if not _rtl:
		return
	var p = clamp(progress, 0.0, 1.0)
	var total = _total_chars()
	_rtl.visible_characters = int(ceil(total * p))

# Allows external configuration from editors
func set_typewriter_speed(cps: float) -> void:
	chars_per_second = max(1.0, cps)

func set_delays(pre_entry: float, between_chunks: float, exit_d: float) -> void:
	pre_entry_delay = max(0.0, pre_entry)
	between_chunks_delay = max(0.0, between_chunks)
	exit_delay = max(0.0, exit_d)

func set_animations(entry: String, exit: String) -> void:
	entry_animation = entry
	exit_animation = exit

# ==============
# Internals
# ==============

# Processes special commands in the dialog text
# Currently supports: @p:character_name
func _process_text_commands(text: String) -> String:
	var result := text
	
	# Find and replace @p:character_name commands
	var regex := RegEx.new()
	regex.compile("@p:([a-zA-Z0-9_ -áéíóúÁÉÍÓÚñÑ]+)")
	
	var matches := regex.search_all(result)
	for match_obj in matches:
		if match_obj.get_group_count() >= 1:
			var character_key := match_obj.get_string(1).strip_edges().to_lower()
			var replacement := _resolve_character_display_name(character_key)
			result = result.replace(match_obj.get_string(0), replacement)
	
	return result

# Processes the speaker name to resolve @p: commands
func _process_speaker_command(speaker: String) -> String:
	if speaker.begins_with("@p:"):
		var character_key := speaker.substr(3).strip_edges().to_lower()
		return _resolve_character_display_name(character_key)
	return speaker

# Resolves the display name for a character
# Priority: 1) Custom name by code (panel local), 2) Global FGGlobal, 3) Capitalized fallback
func _resolve_character_display_name(character_key: String) -> String:
	var key := character_key.strip_edges().to_lower()
	
	# 1. Check if there is a custom name assigned by code (panel local override)
	if _custom_character_names.has(key):
		return _custom_character_names[key]
	
	# 2. Use global resolution if it exists (includes dynamic names + editor overrides)
	if typeof(FGGlobal) != TYPE_NIL and FGGlobal:
		if FGGlobal.has_method("resolve_character_display_name"):
			return FGGlobal.resolve_character_display_name(key)
		else:
			# Manual fallback to dialog_config.character_overrides
			var cfg := FGGlobal.dialog_config if typeof(FGGlobal.dialog_config) == TYPE_DICTIONARY else {}
			var overrides := cfg.get("character_overrides", {})
			if typeof(overrides) == TYPE_DICTIONARY and overrides.keys().size() > 0:
				for char_name in overrides.keys():
					var cmp := str(char_name).strip_edges().to_lower()
					if cmp == key:
						var data = overrides[char_name]
						if typeof(data) == TYPE_DICTIONARY:
							var lang := str(FGGlobal.current_language).to_upper()
							var names = data.get("names", {})
							if typeof(names) == TYPE_DICTIONARY:
								var n = str(names.get(lang, "")).strip_edges()
								if n != "":
									return n
							var def = str(data.get("default_name", "")).strip_edges()
							if def != "":
								return def
	
	# 3. Fallback: return the original capitalized key
	return character_key.capitalize()

func _should_show_label() -> bool:
	return show_speaker_label

func _total_chars() -> int:
	if _rtl and _rtl.has_method("get_total_character_count"):
		return _rtl.get_total_character_count()
	return _rtl.text.length() if _rtl else 0

func _play_entry() -> void:
	if _anim and entry_animation != "" and _anim.has_animation(entry_animation):
		_anim.play(entry_animation)
		await _wait_anim(entry_animation)

func _play_exit() -> void:
	if _anim and exit_animation != "" and _anim.has_animation(exit_animation):
		_anim.play(exit_animation)
		await _wait_anim(exit_animation)

func _wait_anim(name: String) -> void:
	if not _anim:
		await get_tree().process_frame
		return
	# Wait until this animation finishes
	while _anim.is_playing():
		await _anim.animation_finished
		# Ensure we exit when the specific anim finished
		if _anim.current_animation == "" or _anim.current_animation == name:
			break

func _reveal_text(text: String) -> void:
	if not _rtl:
		return
	_is_revealing = true
	_cancel_reveal = false
	_rtl.bbcode_enabled = true
	_rtl.text = text
	_rtl.visible_characters = 0
	
	# ✅ NEW: Reset sound counter
	_reset_sound_counter()
	
	var total := _total_chars()
	if total <= 0:
		_is_revealing = false
		return
	var tpc = 1.0 / max(1.0, chars_per_second)
	var i := 0
	while i < total:
		if _cancel_reveal:
			break
		_rtl.visible_characters = i
		i += 1
		
		# ✅ NEW: Play sound if applicable
		if _should_play_sound():
			_play_text_sound()
		
		await get_tree().create_timer(tpc).timeout
		_apply_speaker_alignment() # <-- Adjusts dynamically as it appears
	
	# Final
	_rtl.visible_characters = total
	_is_revealing = false
	_apply_speaker_alignment()

func _on_anim_finished(anim_name: StringName) -> void:
	# Placeholder if extra handling needed
	pass
