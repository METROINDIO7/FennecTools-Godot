@tool
extends Node

# ✨ FIXED: Mejor coordinación entre DialogPanel y ExpressionState

signal started(total: int)
signal item_started(index: int, id: int)
signal item_finished(index: int, id: int)
signal finished()

@export var slots: Array[DialogueSlotConfig] = []
@export var character_name: String = ""
@export var panel_parent_path: NodePath
@export var typewriter_cps: float = 40.0
@export var pre_entry_delay: float = 0.0
@export var between_chunks_delay: float = 0.3
@export var exit_delay: float = 0.0
@export var auto_free_on_exit: bool = true
@export var character_controller_path: NodePath
@export var reuse_single_panel: bool = false

@export_group("Auto Advance Settings")
@export var auto_advance_between_items: bool = true
@export var auto_advance_delay: float = 2.0

@export_group("Manual Input Settings")
@export var use_custom_input_mapping: bool = true
@export var advance_action_name: String = "accept"

@export_group("Instance Settings")
@export var default_instance_parent_path: NodePath

var _cancelled: bool = false
var _input_consumed: bool = false
var _current_character_group: String = ""
var _current_instance: Node = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func find_character_animation_node(character_group_name: String) -> Node:
	if character_group_name.is_empty():
		return null
	
	var nodes_in_group = get_tree().get_nodes_in_group(character_group_name)
	
	for node in nodes_in_group:
		if node is Node and node.has_method("set_expression_by_id"):
			return node
	
	return null

func animate_character_for_dialogue(character_group_name: String, expression_id: int, dialog_panel: Node = null) -> bool:
	"""
	✨ MEJORADO: Ahora soporta múltiples personajes usando "|" como delimitador
	Ejemplo: "miguel|santi|mario" aplicará la expresión a los 3 personajes
	"""
	if character_group_name.is_empty():
		return false
	
	if expression_id < 0:
		return false
	
	# ✨ NUEVO: Detectar si hay múltiples personajes
	var character_groups := _parse_character_groups(character_group_name)
	
	if character_groups.size() == 0:
		return false
	
	var any_success := false
	
	# Aplicar expresión a cada personaje
	for group_name in character_groups:
		var character_node = find_character_animation_node(group_name)
		if character_node:
			if character_node.has_method("has_expression_index"):
				var has_expression = character_node.has_expression_index(expression_id)
				
				if has_expression:
					character_node.set_expression_by_id(expression_id, dialog_panel)
					any_success = true
				else:
					# Intentar con expresión por defecto
					if character_node.has_method("set_expression_by_id"):
						var default_index = character_node.default_expression_index
						
						if default_index >= 0 and character_node.has_expression_index(default_index):
							character_node.set_expression_by_id(default_index, dialog_panel)
							any_success = true
	
	return any_success

func start_character_talking(character_group_name: String) -> bool:
	"""
	✨ MEJORADO: Soporta múltiples personajes con "|"
	"""
	if character_group_name.is_empty():
		return false
	
	var character_groups := _parse_character_groups(character_group_name)
	var any_success := false
	
	for group_name in character_groups:
		var character_node = find_character_animation_node(group_name)
		if character_node and character_node.has_method("start_talking"):
			character_node.start_talking()
			any_success = true
	
	return any_success

func stop_character_talking(character_group_name: String) -> bool:
	"""
	✨ MEJORADO: Soporta múltiples personajes con "|"
	"""
	if character_group_name.is_empty():
		return false
	
	var character_groups := _parse_character_groups(character_group_name)
	var any_success := false
	
	for group_name in character_groups:
		var character_node = find_character_animation_node(group_name)
		if character_node and character_node.has_method("stop_talking"):
			character_node.stop_talking()
			any_success = true
	
	return any_success

func _get_panel_scene_reference(panel_node: Node) -> PackedScene:
	if not panel_node:
		return null
	
	var scene_file = panel_node.scene_file_path
	if scene_file != "":
		return load(scene_file) as PackedScene
	
	return null

func _get_panel_parent() -> Node:
	if panel_parent_path != NodePath(""):
		var n = get_node_or_null(panel_parent_path)
		if n:
			return n
	return get_parent() if get_parent() else self

func _get_instance_parent(slot: DialogueSlotConfig) -> Node:
	if slot and slot.instance_target != NodePath(""):
		var target_node = get_node_or_null(slot.instance_target)
		if target_node:
			return target_node
	
	if default_instance_parent_path != NodePath(""):
		var global_target = get_node_or_null(default_instance_parent_path)
		if global_target:
			return global_target
	
	var panel_parent = _get_panel_parent()
	return panel_parent

func _resolve_panel_scene_path(override_path: String) -> String:
	if override_path.strip_edges() != "":
		return override_path
	
	if Engine.is_editor_hint():
		return ""
	
	if typeof(FGGlobal) != TYPE_NIL and FGGlobal:
		var p = FGGlobal.get_dialog_panel_scene(character_name)
		if p.strip_edges() != "":
			return p
		return String(FGGlobal.dialog_config.get("default_panel_scene", ""))
	return ""

func _fallback_panel_for_character(char_name: String) -> PackedScene:
	if typeof(FGGlobal) != TYPE_NIL and FGGlobal:
		var path := ""
		var p = FGGlobal.get_dialog_panel_scene(char_name)
		if p.strip_edges() != "":
			path = p
		else:
			path = String(FGGlobal.dialog_config.get("default_panel_scene", ""))
		
		if path.strip_edges() != "":
			var res = load(path)
			if res and res is PackedScene:
				return res
	return null

func _get_text_for_id(id: int, char_override: String = "") -> String:
	if Engine.is_editor_hint():
		return ""
	
	if typeof(FGGlobal) != TYPE_NIL and FGGlobal:
		var lang = FGGlobal.current_language
		if char_override.strip_edges() != "":
			var t1 = FGGlobal.get_dialog_text(id, char_override, lang)
			if t1.strip_edges() != "":
				return t1
		if character_name.strip_edges() != "":
			var t2 = FGGlobal.get_dialog_text(id, character_name, lang)
			if t2.strip_edges() != "":
				return t2
		return FGGlobal.get_dialog_text_by_id(id, lang)
	return ""

func _setup_panel(controller: Node, slot: DialogueSlotConfig) -> void:
	if not controller or not slot:
		return
	
	var cps = slot.typewriter_cps if slot.typewriter_cps > 0 else typewriter_cps
	var pre = slot.pre_entry_delay
	var between = slot.between_chunks_delay
	var exit = slot.exit_delay
	var auto_free = slot.auto_free_on_exit
	
	if controller.has_method("set_typewriter_speed"):
		controller.set_typewriter_speed(cps)
	
	if controller.has_method("set_delays"):
		controller.set_delays(pre, between, exit)
	
	if _has_property(controller, "auto_free_on_exit"):
		controller.set("auto_free_on_exit", auto_free)

func _cleanup_current_instance():
	if _current_instance and is_instance_valid(_current_instance):
		if _current_instance.has_method("cleanup_before_removal"):
			_current_instance.cleanup_before_removal()
		elif _current_instance.has_method("queue_free"):
			_current_instance.queue_free()
		else:
			_current_instance.queue_free()
		
		_current_instance = null

func _handle_slot_instance(slot: DialogueSlotConfig) -> bool:
	if not slot or not slot.instance_scene:
		return false
	
	_cleanup_current_instance()
	
	var instance_parent = _get_instance_parent(slot)
	if not instance_parent:
		return false
	
	_current_instance = slot.instance_scene.instantiate()
	if not _current_instance:
		return false
	
	instance_parent.add_child(_current_instance)
	
	if _current_instance is CanvasItem and instance_parent is CanvasItem:
		pass
	
	if _current_instance.has_method("initialize_for_dialogue"):
		_current_instance.initialize_for_dialogue()
	
	return true

func cancel():
	_cancelled = true

func _has_property(obj: Object, prop_name: String) -> bool:
	for p in obj.get_property_list():
		if str(p.get("name", "")) == prop_name:
			return true
	return false

func _get_character_for_id(id: int) -> String:
	if typeof(FGGlobal) != TYPE_NIL and FGGlobal:
		for d in FGGlobal.dialog_data:
			var e: Dictionary = d as Dictionary
			if int(e.get("id", -1)) == id:
				return str(e.get("character", ""))
	return ""

func _resolve_display_speaker_name(char_name: String) -> String:
	var name := char_name
	if typeof(FGGlobal) != TYPE_NIL and FGGlobal:
		var cfg: Dictionary = FGGlobal.dialog_config if typeof(FGGlobal.dialog_config) == TYPE_DICTIONARY else {}
		var overrides: Dictionary = cfg.get("character_overrides", {})
		
		if typeof(overrides) == TYPE_DICTIONARY and overrides.has(char_name):
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
	
	return name

# ✨ MODIFICADO: Ahora respeta mejor el flujo de señales del DialogPanel
func _await_between_dialogue_advance(is_last_dialogue: bool = false) -> void:
	if auto_advance_between_items and not is_last_dialogue:
		if auto_advance_delay > 0.0:
			_input_consumed = false
			var elapsed_time := 0.0
			var delta_time := 0.0
			
			while not _cancelled and elapsed_time < auto_advance_delay:
				if _is_advance_pressed():
					_input_consumed = true
					break
				
				await get_tree().process_frame
				delta_time = get_process_delta_time()
				elapsed_time += delta_time
		else:
			await get_tree().process_frame
			if _is_advance_pressed():
				_input_consumed = true
	elif is_last_dialogue:
		if auto_advance_delay > 0.0:
			_input_consumed = false
			var elapsed_time := 0.0
			var delta_time := 0.0
			
			var min_display_time = auto_advance_delay * 0.5
			while not _cancelled and elapsed_time < min_display_time:
				if _is_advance_pressed():
					_input_consumed = true
					break
				
				await get_tree().process_frame
				delta_time = get_process_delta_time()
				elapsed_time += delta_time
		
		if not _cancelled and not _input_consumed:
			await _await_advance_input()
	else:
		await _await_advance_input()

func _await_advance_input() -> void:
	_input_consumed = false
	while not _cancelled and not _input_consumed:
		if _is_advance_pressed():
			_input_consumed = true
			break
		await get_tree().process_frame

func _is_advance_pressed() -> bool:
	if _input_consumed:
		return false
		
	var name := advance_action_name.strip_edges()
	if name == "":
		name = "accept" if use_custom_input_mapping else "ui_accept"
	
	if use_custom_input_mapping and typeof(FGGlobal) != TYPE_NIL and FGGlobal:
		if FGGlobal.has_method("is_custom_action_just_pressed"):
			if FGGlobal.is_custom_action_just_pressed(name):
				return true
		
		if FGGlobal.has_method("get_effective_input_mapping"):
			var mappings = FGGlobal.get_effective_input_mapping(name)
			if mappings and mappings.size() > 0:
				for m in mappings:
					var act = str(m)
					if InputMap.has_action(act) and Input.is_action_just_pressed(act):
						return true
	
	if InputMap.has_action(name) and Input.is_action_just_pressed(name):
		return true
	
	return false

func _calculate_total_items() -> int:
	var total := 0
	for slot in slots:
		if slot and slot.is_valid():
			total += slot.get_total_items()
	return total

func start() -> void:
	_cancelled = false
	_input_consumed = false
	
	var parent = _get_panel_parent()
	
	if slots.size() == 0:
		finished.emit()
		return
	
	var total := _calculate_total_items()
	started.emit(total)
	
	var global_index := 0
	var current_panel: Node = null
	
	for slot_idx in range(slots.size()):
		if _cancelled:
			break
			
		var slot = slots[slot_idx]
		if not slot or not slot.is_valid():
			continue
		
		# ✨ Configurar expresión ANTES de mostrar el diálogo
		_current_character_group = slot.character_group_name
		var slot_expression_id = slot.expression_id
		
		# ✨ MEJORADO: No animar si no hay diálogos válidos en este slot
		var items = slot.build_items()
		var has_valid_dialogues = items.size() > 0
		
		if _current_character_group != "" and slot_expression_id >= 0 and has_valid_dialogues:
			# Solo animaremos cuando tengamos un panel válido
			pass
		
		# Manejar instanciación de objetos
		if slot.instance_scene:
			var instance_success = _handle_slot_instance(slot)
			
			if instance_success:
				if _current_instance and _current_instance.has_method("start_dialogue_flow"):
					await _current_instance.start_dialogue_flow()
				
				await get_tree().process_frame
			
			if not slot.is_valid() or slot.get_total_items() == 0:
				continue
		
		# Procesar diálogos
		for item_idx in range(items.size()):
			if _cancelled:
				break
				
			var item = items[item_idx]
			var id = int(item.get("id", -1))
			
			if id < 0:
				continue
			
			item_started.emit(global_index, id)
			
			var effective_char = slot.character if slot.character.strip_edges() != "" else _get_character_for_id(id)
			if effective_char.strip_edges() == "":
				effective_char = character_name
			
			var panel_scene_needed: PackedScene = null
			if slot.panel_override:
				panel_scene_needed = slot.panel_override
			else:
				panel_scene_needed = _fallback_panel_for_character(effective_char)
			
			var need_new_panel = true
			
			if current_panel and is_instance_valid(current_panel):
				var current_scene = _get_panel_scene_reference(current_panel)
				if current_scene == panel_scene_needed:
					need_new_panel = false
					if current_panel.has_method("reset_for_reuse"):
						current_panel.reset_for_reuse()
			
			if need_new_panel:
				if current_panel and is_instance_valid(current_panel):
					if current_panel.has_method("request_exit"):
						await current_panel.request_exit()
					current_panel.queue_free()
					current_panel = null
				
				if panel_scene_needed:
					current_panel = panel_scene_needed.instantiate()
					if current_panel:
						parent.add_child(current_panel)
			
			if current_panel:
				_setup_panel(current_panel, slot)
				
				# ✨ CRÍTICO: Configurar expresión AHORA que tenemos el panel
				if _current_character_group != "" and slot_expression_id >= 0:
					animate_character_for_dialogue(_current_character_group, slot_expression_id, current_panel)
				
				var text = _get_text_for_id(id, effective_char)
				var display_name = _resolve_display_speaker_name(effective_char)
				
				# Iniciar animación de boca ANTES del texto
				if _current_character_group != "":
					start_character_talking(_current_character_group)
				
				# ✨ Reproducir voiceline si está configurada
				if slot.has_voiceline() and current_panel.has_method("play_voiceline"):
					current_panel.play_voiceline(slot.get_voiceline_config())
				
				# ✨ IMPORTANTE: play_dialog maneja todo el ciclo interno
				if current_panel.has_method("play_dialog"):
					await current_panel.play_dialog(text, display_name)
				elif current_panel.has_method("show_dialogue"):
					current_panel.show_dialogue(text, display_name)
					if current_panel.has_signal("dialogue_finished"):
						await current_panel.dialogue_finished
					elif current_panel.has_signal("dialog_completed"):
						await current_panel.dialog_completed
				
				# Detener animación de boca DESPUÉS del texto
				if _current_character_group != "":
					stop_character_talking(_current_character_group)
				
				var is_last_item = (slot_idx == slots.size() - 1) and (item_idx == items.size() - 1)
				
				# ✨ CRÍTICO: El delay de avance ocurre AQUÍ
				# Esto permite que READY_TO_ADVANCE se emita en el momento correcto
				if not _cancelled:
					await _await_between_dialogue_advance(is_last_item)
				
				var should_exit_panel = is_last_item
				
				if should_exit_panel and current_panel and current_panel.has_method("request_exit"):
					await current_panel.request_exit()
				elif should_exit_panel and current_panel:
					current_panel.queue_free()
					current_panel = null
				
				item_finished.emit(global_index, id)
				global_index += 1
	
	# Limpieza final
	if current_panel and is_instance_valid(current_panel):
		if current_panel.has_method("request_exit"):
			await current_panel.request_exit()
		current_panel.queue_free()
		current_panel = null

	_cleanup_current_instance()

	_current_character_group = ""
	
	finished.emit()

func get_character_current_expression(character_group_name: String) -> String:
	var character_node = find_character_animation_node(character_group_name)
	if character_node and character_node.has_method("get_current_expression_name"):
		return character_node.get_current_expression_name()
	return ""

func has_character_animation_node(character_group_name: String) -> bool:
	return find_character_animation_node(character_group_name) != null

func _get_character_controller() -> Node:
	if character_controller_path != NodePath(""):
		return get_node_or_null(character_controller_path)
	return null

func _panel_from_path(path: String) -> Node:
	if path.strip_edges() == "":
		return null
	var s = load(path)
	if s and s is PackedScene:
		return (s as PackedScene).instantiate()
	return null

# ✨ NUEVO: Helper para parsear múltiples character groups
func _parse_character_groups(character_group_name: String) -> PackedStringArray:
	"""
	Parsea una cadena de character groups separados por "|"
	Ejemplos:
	  "miguel" -> ["miguel"]
	  "miguel|santi|mario" -> ["miguel", "santi", "mario"]
	  "miguel | santi | mario" -> ["miguel", "santi", "mario"] (elimina espacios)
	"""
	if character_group_name.is_empty():
		return PackedStringArray()
	
	# Dividir por "|"
	var groups := character_group_name.split("|", false)
	var result := PackedStringArray()
	
	# Limpiar espacios en blanco de cada grupo
	for group in groups:
		var cleaned := group.strip_edges()
		if not cleaned.is_empty():
			result.append(cleaned)
	
	return result
