@tool
extends Node

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
@export var default_instance_parent_path: NodePath  # Renombrado para claridad

var _cancelled: bool = false
var _input_consumed: bool = false
var _current_character_group: String = ""
var _current_instance: Node = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func find_character_animation_node(character_group_name: String) -> Node:
	print("[DialogueLauncher] find_character_animation_node called for group: ", character_group_name)
	
	if character_group_name.is_empty():
		print("[DialogueLauncher] Group name is empty")
		return null
	
	var nodes_in_group = get_tree().get_nodes_in_group(character_group_name)
	print("[DialogueLauncher] Found ", nodes_in_group.size(), " nodes in group: ", character_group_name)
	
	for node in nodes_in_group:
		print("[DialogueLauncher] Checking node: ", node.name, " (", node.get_class(), ")")
		if node is Node and node.has_method("set_expression_by_id"):
			print("[DialogueLauncher] Found valid CharacterController: ", node.name)
			return node
		else:
			print("[DialogueLauncher] Node doesn't have set_expression_by_id method")
	
	print("[DialogueLauncher] No valid CharacterController found in group")
	return null

func animate_character_for_dialogue(character_group_name: String, expression_id: int) -> bool:
	"""✅ CAMBIO: Ahora usa expression_id numérico en lugar de nombre"""
	print("[DialogueLauncher] animate_character_for_dialogue called - Group: ", character_group_name, " Expression ID: ", expression_id)
	
	if character_group_name.is_empty():
		print("[DialogueLauncher] ERROR: character_group_name is empty")
		return false
	
	# expression_id = -1 significa no expresión
	if expression_id < 0:
		print("[DialogueLauncher] No expression to set (expression_id = -1)")
		return false

	print("[DialogueLauncher] Looking for character in group: ", character_group_name)
	
	var character_node = find_character_animation_node(character_group_name)
	if character_node:
		print("[DialogueLauncher] Character node found: ", character_node.name)
		
		# Verificar si el índice de expresión existe
		if character_node.has_method("has_expression_index"):
			var has_expression = character_node.has_expression_index(expression_id)
			print("[DialogueLauncher] Character has expression index ", expression_id, ": ", has_expression)
			
			if has_expression:
				print("[DialogueLauncher] Setting expression ID: ", expression_id)
				character_node.set_expression_by_id(expression_id)
				print("[DialogueLauncher] Expression ID '", expression_id, "' applied to character group: ", character_group_name)
				return true
			else:
				print("[DialogueLauncher] Warning: Expression ID '", expression_id, "' not found in character")
				# Intentar con expresión por defecto
				if character_node.has_method("set_expression_by_id"):
					var default_index = character_node.default_expression_index
					print("[DialogueLauncher] Trying default expression index: ", default_index)
					
					if default_index >= 0 and character_node.has_expression_index(default_index):
						character_node.set_expression_by_id(default_index)
						print("[DialogueLauncher] Using default expression index: '", default_index, "'")
						return true
					else:
						print("[DialogueLauncher] Default expression index also not available")
		else:
			print("[DialogueLauncher] Character doesn't have has_expression_index method")
	else:
		print("[DialogueLauncher] ERROR: No character found in group: ", character_group_name)
		return false
	
	print("[DialogueLauncher] Failed to set expression")
	return false

func start_character_talking(character_group_name: String) -> bool:
	print("[DialogueLauncher] start_character_talking called for group: ", character_group_name)
	
	var character_node = find_character_animation_node(character_group_name)
	if character_node and character_node.has_method("start_talking"):
		character_node.start_talking()
		print("[DialogueLauncher] Started talking for: ", character_group_name)
		return true
	
	print("[DialogueLauncher] Failed to start talking for: ", character_group_name)
	return false

func stop_character_talking(character_group_name: String) -> bool:
	print("[DialogueLauncher] stop_character_talking called for group: ", character_group_name)
	
	var character_node = find_character_animation_node(character_group_name)
	if character_node and character_node.has_method("stop_talking"):
		character_node.stop_talking()
		print("[DialogueLauncher] Stopped talking for: ", character_group_name)
		return true
	
	print("[DialogueLauncher] Failed to stop talking for: ", character_group_name)
	return false

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
	"""Obtiene el nodo padre para instanciar basado en la configuración del slot"""
	
	# 1. Primero intenta usar el target específico del slot
	if slot and slot.instance_target != NodePath(""):
		var target_node = get_node_or_null(slot.instance_target)
		if target_node:
			print("[DialogueLauncher] Using slot-specific instance target: ", target_node.name)
			return target_node
		else:
			print("[DialogueLauncher] WARNING: Slot instance target not found: ", slot.instance_target)
	
	# 2. Fallback al target global del DialogueLauncher
	if default_instance_parent_path != NodePath(""):
		var global_target = get_node_or_null(default_instance_parent_path)
		if global_target:
			print("[DialogueLauncher] Using global instance parent: ", global_target.name)
			return global_target
	
	# 3. Fallback final al padre del panel
	var panel_parent = _get_panel_parent()
	print("[DialogueLauncher] Using panel parent as instance parent: ", panel_parent.name)
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
	"""Limpia la instancia actual si existe"""
	if _current_instance and is_instance_valid(_current_instance):
		print("[DialogueLauncher] Cleaning up current instance: ", _current_instance.name)
		
		# Si la instancia tiene método de limpieza, usarlo
		if _current_instance.has_method("cleanup_before_removal"):
			_current_instance.cleanup_before_removal()
		elif _current_instance.has_method("queue_free"):
			_current_instance.queue_free()
		else:
			_current_instance.queue_free()
		
		_current_instance = null

func _handle_slot_instance(slot: DialogueSlotConfig) -> bool:
	"""Maneja la instanciación de objetos para un slot"""
	if not slot or not slot.instance_scene:
		return false
	
	print("[DialogueLauncher] Instantiating scene from slot: ", slot.get_instance_debug_info())
	_cleanup_current_instance()
	
	var instance_parent = _get_instance_parent(slot)
	if not instance_parent:
		print("[DialogueLauncher] ERROR: No instance parent found")
		return false
	
	# Instanciar la escena
	_current_instance = slot.instance_scene.instantiate()
	if not _current_instance:
		print("[DialogueLauncher] ERROR: Failed to instantiate scene")
		return false
	
	instance_parent.add_child(_current_instance)
	
	# Opcional: Si es CanvasItem y quieres posición específica, pero ahora el target maneja esto
	if _current_instance is CanvasItem and instance_parent is CanvasItem:
		# Por defecto en (0,0) relativo al padre, que es lo que queremos
		print("[DialogueLauncher] Instance is CanvasItem, position: ", _current_instance.position)
	
	print("[DialogueLauncher] Successfully instantiated: ", _current_instance.name, " as child of: ", instance_parent.name)
	
	# Si la instancia tiene método de inicialización, llamarlo
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
	print("[DialogueLauncher] ===== STARTING DIALOGUE LAUNCHER =====")
	_cancelled = false
	_input_consumed = false
	
	var parent = _get_panel_parent()
	
	if slots.size() == 0:
		print("[DialogueLauncher] No slots configured")
		finished.emit()
		return
	
	var total := _calculate_total_items()
	print("[DialogueLauncher] Total items to process: ", total)
	started.emit(total)
	
	var global_index := 0
	var current_panel: Node = null
	
	for slot_idx in range(slots.size()):
		if _cancelled:
			print("[DialogueLauncher] Dialogue cancelled at slot ", slot_idx)
			break
			
		var slot = slots[slot_idx]
		if not slot or not slot.is_valid():
			print("[DialogueLauncher] Slot ", slot_idx, " is invalid, skipping")
			continue
		
		print("[DialogueLauncher] Processing slot ", slot_idx)
		print("[DialogueLauncher] Slot info: ", slot.get_debug_info())
		if slot.has_instance_scene():
			print("[DialogueLauncher] Slot instance info: ", slot.get_instance_debug_info())
		
		# ✅ Manejar expresión del personaje
		_current_character_group = slot.character_group_name
		var slot_expression_id = slot.expression_id
		
		if _current_character_group != "" and slot_expression_id >= 0:
			var success = animate_character_for_dialogue(_current_character_group, slot_expression_id)
			print("[DialogueLauncher] Expression set: ", success)
		
		# ✅ NUEVO: Manejar instanciación de objetos (ANTES del diálogo)
		if slot.instance_scene:
			print("[DialogueLauncher] Slot has instance_scene, attempting to instantiate")
			var instance_success = _handle_slot_instance(slot)
			
			if instance_success:
				print("[DialogueLauncher] Instance created successfully")
				
				# Si la instancia tiene su propio flujo de diálogo, manejarlo aquí
				if _current_instance and _current_instance.has_method("start_dialogue_flow"):
					print("[DialogueLauncher] Instance has dialogue flow, starting it")
					await _current_instance.start_dialogue_flow()
				
				# Control de avance automático
				if slot.disable_auto_advance_when_instanced:
					print("[DialogueLauncher] Auto-advance disabled, waiting for manual input")
					await _await_advance_input()
				else:
					# Esperar un frame para que la instancia se establezca
					await get_tree().process_frame
			
			# Si el slot solo tiene instancia (sin diálogos), continuar al siguiente
			if not slot.is_valid() or slot.get_total_items() == 0:
				print("[DialogueLauncher] Slot is instance-only, continuing to next slot")
				continue
		
		# ✅ Continuar con el procesamiento normal de diálogos
		var items = slot.build_items()
		print("[DialogueLauncher] Slot has ", items.size(), " items")
		
		for item_idx in range(items.size()):
			if _cancelled:
				print("[DialogueLauncher] Dialogue cancelled at item ", item_idx)
				break
				
			var item = items[item_idx]
			var id = int(item.get("id", -1))
			
			if id < 0:
				continue
			
			print("[DialogueLauncher] Starting item ", global_index, " with ID: ", id)
			item_started.emit(global_index, id)
			
			var effective_char = slot.character if slot.character.strip_edges() != "" else _get_character_for_id(id)
			if effective_char.strip_edges() == "":
				effective_char = character_name
			
			print("[DialogueLauncher] Effective character: ", effective_char)
			
			var panel_scene_needed: PackedScene = null
			if slot.panel_override:
				panel_scene_needed = slot.panel_override
				print("[DialogueLauncher] Using panel override")
			else:
				panel_scene_needed = _fallback_panel_for_character(effective_char)
				print("[DialogueLauncher] Using fallback panel")
			
			var need_new_panel = true
			
			if current_panel and is_instance_valid(current_panel):
				var current_scene = _get_panel_scene_reference(current_panel)
				if current_scene == panel_scene_needed:
					need_new_panel = false
					if current_panel.has_method("reset_for_reuse"):
						current_panel.reset_for_reuse()
					print("[DialogueLauncher] Reusing existing panel")
			
			if need_new_panel:
				print("[DialogueLauncher] Need new panel")
				if current_panel and is_instance_valid(current_panel):
					if current_panel.has_method("request_exit"):
						await current_panel.request_exit()
					current_panel.queue_free()
					current_panel = null
				
				if panel_scene_needed:
					current_panel = panel_scene_needed.instantiate()
					if current_panel:
						parent.add_child(current_panel)
						print("[DialogueLauncher] New panel instantiated: ", current_panel.name)
					else:
						print("[DialogueLauncher] Failed to instantiate panel")
				else:
					print("[DialogueLauncher] No panel scene available")
			
			if current_panel:
				_setup_panel(current_panel, slot)
				
				var text = _get_text_for_id(id, effective_char)
				var display_name = _resolve_display_speaker_name(effective_char)
				
				print("[DialogueLauncher] Displaying text: ", text.substr(0, 50) + "..." if text.length() > 50 else text)
				
				# INICIO: Iniciar animación de boca ANTES de mostrar texto
				if _current_character_group != "":
					print("[DialogueLauncher] Starting character talking")
					start_character_talking(_current_character_group)
				
				# Mostrar diálogo
				if current_panel.has_method("play_dialog"):
					print("[DialogueLauncher] Calling play_dialog on panel")
					await current_panel.play_dialog(text, display_name)
				elif current_panel.has_method("show_dialogue"):
					print("[DialogueLauncher] Calling show_dialogue on panel")
					current_panel.show_dialogue(text, display_name)
					if current_panel.has_signal("dialogue_finished"):
						await current_panel.dialogue_finished
					elif current_panel.has_signal("dialog_completed"):
						await current_panel.dialog_completed
				else:
					print("[DialogueLauncher] Panel doesn't have expected dialogue methods")
				
				# FIN: Detener animación de boca DESPUÉS de que termine el texto
				if _current_character_group != "":
					print("[DialogueLauncher] Stopping character talking")
					stop_character_talking(_current_character_group)
				
				var is_last_item = (slot_idx == slots.size() - 1) and (item_idx == items.size() - 1)
				print("[DialogueLauncher] Is last item: ", is_last_item)
				
				if not _cancelled:
					print("[DialogueLauncher] Awaiting between dialogue advance")
					await _await_between_dialogue_advance(is_last_item)
				
				var should_exit_panel = is_last_item
				
				if should_exit_panel and current_panel and current_panel.has_method("request_exit"):
					print("[DialogueLauncher] Requesting panel exit")
					await current_panel.request_exit()
				elif should_exit_panel and current_panel:
					print("[DialogueLauncher] Queue freeing panel")
					current_panel.queue_free()
					current_panel = null
				
				item_finished.emit(global_index, id)
				global_index += 1
				print("[DialogueLauncher] Item finished, global index: ", global_index)
	
	# Limpieza final
	if current_panel and is_instance_valid(current_panel):
		print("[DialogueLauncher] Cleaning up final panel")
		if current_panel.has_method("request_exit"):
			await current_panel.request_exit()
		current_panel.queue_free()
		current_panel = null

	# ✅ Limpiar instancia actual
	_cleanup_current_instance()

	_current_character_group = ""
	
	print("[DialogueLauncher] ===== DIALOGUE LAUNCHER FINISHED =====")
	finished.emit()

# Función para obtener la expresión actual de un personaje
func get_character_current_expression(character_group_name: String) -> String:
	"""Obtiene la expresión actual del personaje especificado"""
	var character_node = find_character_animation_node(character_group_name)
	if character_node and character_node.has_method("get_current_expression_name"):
		return character_node.get_current_expression_name()
	return ""

# Función para verificar si un personaje existe
func has_character_animation_node(character_group_name: String) -> bool:
	"""Verifica si existe un CharacterController para el grupo especificado"""
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
