@tool
extends Control

# Dialog Panel/Bubble controller
# ✨ FIXED: Mejor coordinación de señales para ExpressionState

signal dialog_started(text: String, speaker: String)
signal chunk_shown(index: int, total: int)
signal dialog_completed()  # Se emite cuando el texto termina de mostrarse
signal dialog_ready_to_advance()  # ✨ NUEVO: Se emite después del delay y antes de avanzar
signal dialog_exit_started()  # ✨ NUEVO: Se emite cuando comienza la animación de salida
signal dialog_exited()  # Se emite cuando termina la animación de salida
signal dialogue_finished()  # Compatibility

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
@export var chunk_delimiter: String = "|"

# Label visibility default when no toggle is provided
@export var show_speaker_label: bool = true

# === ALIGNMENT SETTINGS ===
@export_group("Text Alignment and Margin")

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
@export_group("Sound Character and Voiceline")
@export var sound_enabled: bool = false

@export var character_sound_effect: AudioStream
@export var character_sound_frequency: int = 3
@export_range(0.5, 2.0, 0.1) var character_sound_pitch_min: float = 0.9
@export_range(0.5, 2.0, 0.1) var character_sound_pitch_max: float = 1.1
@export_range(0.0, 1.0, 0.1) var character_sound_volume: float = 0.7

var voiceline_player: NodePath

# Audio players
var _character_sound_player: AudioStreamPlayer
var _voiceline_player: AudioStreamPlayer
var _char_count_since_last_sound: int = 0

# Internal references
var _label: Label
var _rtl: RichTextLabel
var _anim: AnimationPlayer
var _original_rtl_stylebox: StyleBox

# Internal state
var _pending_text: String = ""
var _pending_speaker: String = ""
var _chunks: PackedStringArray = PackedStringArray()
var _current_chunk: int = -1
var _is_revealing: bool = false
var _cancel_reveal: bool = false
var _block_node: Node = null

# === DYNAMIC NAME SYSTEM ===
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

	if _rtl:
		_rtl.visible_characters = 0
		_original_rtl_stylebox = _rtl.get_theme_stylebox("normal")
	
	_apply_alignment_settings()
	
	if not dialog_completed.is_connected(_on_dialog_completed):
		dialog_completed.connect(_on_dialog_completed)
	
	_setup_sound_system()

# ==============
# SOUND SYSTEM
# ==============

func _setup_sound_system() -> void:
	if not is_instance_valid(_character_sound_player):
		_character_sound_player = AudioStreamPlayer.new()
		_character_sound_player.name = "CharacterSoundPlayer"
		add_child(_character_sound_player)
	_character_sound_player.process_mode = Node.PROCESS_MODE_ALWAYS

	if voiceline_player != NodePath(""):
		_voiceline_player = get_node_or_null(voiceline_player)
	if not is_instance_valid(_voiceline_player):
		_voiceline_player = AudioStreamPlayer.new()
		_voiceline_player.name = "VoicelinePlayer"
		add_child(_voiceline_player)
	_voiceline_player.process_mode = Node.PROCESS_MODE_ALWAYS

func play_voiceline(voiceline_config: Dictionary) -> void:
	if not sound_enabled or not _voiceline_player or not voiceline_config.has("stream"):
		return
	
	var stream = voiceline_config.get("stream")
	if not stream is AudioStream:
		return

	_voiceline_player.stream = stream
	_voiceline_player.volume_db = linear_to_db(voiceline_config.get("volume", 0.7))
	_voiceline_player.pitch_scale = randf_range(
		voiceline_config.get("pitch_min", 0.9),
		voiceline_config.get("pitch_max", 1.1)
	)
	
	var bus_name = voiceline_config.get("bus", "Master")
	if bus_name != "" and AudioServer.get_bus_index(bus_name) != -1:
		_voiceline_player.bus = bus_name
	else:
		_voiceline_player.bus = "Master"
	
	_voiceline_player.play()

func _play_character_sound() -> void:
	if not sound_enabled or not _character_sound_player or not character_sound_effect:
		return
	
	_character_sound_player.stream = character_sound_effect
	_character_sound_player.volume_db = linear_to_db(character_sound_volume)
	_character_sound_player.pitch_scale = randf_range(character_sound_pitch_min, character_sound_pitch_max)
	_character_sound_player.play()

func _should_play_character_sound() -> bool:
	if not sound_enabled or not character_sound_effect:
		return false
	
	if character_sound_frequency <= 0:
		return false
	
	_char_count_since_last_sound += 1
	if _char_count_since_last_sound >= character_sound_frequency:
		_char_count_since_last_sound = 0
		return true
	
	return false

func _reset_sound_counter() -> void:
	_char_count_since_last_sound = 0

# ==============
# Compatibility
# ==============
func _on_dialog_completed():
	dialogue_finished.emit()

func reset_for_reuse() -> void:
	_pending_text = ""
	_pending_speaker = ""
	_chunks = PackedStringArray()
	_current_chunk = -1
	_is_revealing = false
	_cancel_reveal = false
	_block_node = null
	
	if _rtl:
		_rtl.visible_characters = 0
		_rtl.text = ""
	
	if _label:
		_label.text = ""
	
	_reset_sound_counter()
	
	if _anim:
		_anim.stop()
		if _anim.has_animation("reset"):
			_anim.play("reset")
		elif _anim.has_animation("idle"):
			_anim.play("idle")
		elif _anim.has_animation(entry_animation):
			_anim.play(entry_animation)
			_anim.seek(0.0)
			_anim.stop()

# ==============
# ALIGNMENT
# ==============

func _apply_alignment_settings() -> void:
	_apply_text_alignment()
	_apply_speaker_alignment()

func _apply_text_alignment() -> void:
	pass

func _apply_speaker_alignment() -> void:
	if not _rtl:
		return
	
	var text_height := _rtl.get_content_height()
	var rect_height := _rtl.size.y
	if text_height <= 0:
		text_height = rect_height
	
	var extra_space := rect_height - text_height
	var top_margin := clampi(Margin_top, 0, max(0, extra_space))
	
	var style_box = StyleBoxEmpty.new()
	style_box.content_margin_top = top_margin
	style_box.content_margin_bottom = Margin_bottom
	style_box.content_margin_left = Margin_left
	style_box.content_margin_right = Margin_right
	
	_rtl.add_theme_stylebox_override("normal", style_box)

func _wrap_text_with_alignment(text: String) -> String:
	var wrapped_text = text
	
	match text_alignment:
		TextHorizontalAlign.LEFT:
			wrapped_text = text
		TextHorizontalAlign.CENTER:
			wrapped_text = "[center]" + text + "[/center]"
		TextHorizontalAlign.RIGHT:
			wrapped_text = "[right]" + text + "[/right]"
		TextHorizontalAlign.FILL:
			wrapped_text = "[fill]" + text + "[/fill]"
	
	return wrapped_text

func set_text_alignment(alignment: TextHorizontalAlign) -> void:
	text_alignment = alignment
	_apply_text_alignment()

func set_vertical_spacings(top: int) -> void:
	Margin_top = max(0, top)
	_apply_speaker_alignment()

# ==============
# Public API
# ==============

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

func play_dialog(text: String, speaker: String = "") -> void:
	var processed_text := _process_text_commands(text)
	var processed_speaker := _process_speaker_command(speaker)
	
	_pending_text = processed_text
	_pending_speaker = processed_speaker
	
	_chunks = PackedStringArray()
	if chunk_delimiter != "" and processed_text.find(chunk_delimiter) != -1:
		_chunks = processed_text.split(chunk_delimiter, false)
	else:
		_chunks = PackedStringArray([processed_text])
	_current_chunk = -1

	for i in range(_chunks.size()):
		_chunks[i] = _wrap_text_with_alignment(_chunks[i])

	if _label:
		_label.text = processed_speaker
		_label.visible = _should_show_label()
	
	_apply_speaker_alignment()

	if pre_entry_delay > 0.0:
		await get_tree().create_timer(pre_entry_delay).timeout
	if auto_play_entry:
		await _play_entry()

	dialog_started.emit(processed_text, processed_speaker)
	
	for i in range(_chunks.size()):
		_current_chunk = i
		await _reveal_text(_chunks[i])
		chunk_shown.emit(i, _chunks.size())
		if i < _chunks.size() - 1:
			if between_chunks_delay > 0.0:
				await get_tree().create_timer(between_chunks_delay).timeout

	dialog_completed.emit()
	
	# ✨ NUEVO: Emitir señal cuando está listo para avanzar (después de cualquier delay)
	# Esto se hace aquí porque el DialogueLauncher manejará el delay de avance
	dialog_ready_to_advance.emit()

# ✨ MODIFICADO: Ahora emite dialog_exit_started
func request_exit(wait_for_node: Node = null) -> void:
	_block_node = wait_for_node
	if is_instance_valid(_block_node):
		while is_instance_valid(_block_node) and _block_node.get_parent() != null:
			await get_tree().process_frame
		_block_node = null
	
	if exit_delay > 0.0:
		await get_tree().create_timer(exit_delay).timeout
	
	# Notificar que la animación de salida está por comenzar
	dialog_exit_started.emit()
	
	await _play_exit()
	
	# ✨ NUEVO: Limpiar estado global si es necesario
	if typeof(FGGlobal) != TYPE_NIL and FGGlobal:
		# Solo establecer en false si este es el último panel activo
		# Puedes ajustar esta lógica según tus necesidades
		FGGlobal.talk = false
	
	if auto_free_on_exit:
		queue_free()
	
	dialog_exited.emit()

func skip_or_advance() -> void:
	if not _rtl:
		return
	if _is_revealing:
		_cancel_reveal = true
		_rtl.visible_characters = _total_chars()
	else:
		if _current_chunk >= 0 and _current_chunk < _chunks.size() - 1:
			_current_chunk += 1
			_reveal_text(_chunks[_current_chunk])

func set_visibility_progress(progress: float) -> void:
	if not _rtl:
		return
	var p = clamp(progress, 0.0, 1.0)
	var total = _total_chars()
	_rtl.visible_characters = int(ceil(total * p))

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

func _process_text_commands(text: String) -> String:
	var result := text
	
	var regex := RegEx.new()
	regex.compile("@p:([a-zA-Z0-9_ -áéíóúÁÉÍÓÚñÑ]+)")
	
	var matches := regex.search_all(result)
	for match_obj in matches:
		if match_obj.get_group_count() >= 1:
			var character_key := match_obj.get_string(1).strip_edges().to_lower()
			var replacement := _resolve_character_display_name(character_key)
			result = result.replace(match_obj.get_string(0), replacement)
	
	return result

func _process_speaker_command(speaker: String) -> String:
	if speaker.begins_with("@p:"):
		var character_key := speaker.substr(3).strip_edges().to_lower()
		return _resolve_character_display_name(character_key)
	return speaker

func _resolve_character_display_name(character_key: String) -> String:
	var key := character_key.strip_edges().to_lower()
	
	if _custom_character_names.has(key):
		return _custom_character_names[key]
	
	if typeof(FGGlobal) != TYPE_NIL and FGGlobal:
		if FGGlobal.has_method("resolve_character_display_name"):
			return FGGlobal.resolve_character_display_name(key)
		else:
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
	
	while _anim.is_playing():
		await _anim.animation_finished
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
		
		if _should_play_character_sound():
			_play_character_sound()
		
		await get_tree().create_timer(tpc).timeout
		_apply_speaker_alignment()
	
	_rtl.visible_characters = total
	_is_revealing = false
	_apply_speaker_alignment()

func _on_anim_finished(anim_name: StringName) -> void:
	pass
