@tool
extends Node

# Dialogue Launcher actualizado para trabajar con DialogueSlotConfig unificado
# Ahora cada slot maneja internamente si es CHAIN o SEQUENCE

signal started(total: int)
signal item_started(index: int, id: int)
signal item_finished(index: int, id: int)
signal finished()

# Array de slots unificados (reemplaza el sistema anterior de recursos separados)
@export var slots: Array[DialogueSlotConfig] = []
@export var character_name: String = ""

# Dónde instanciar el panel (por defecto se añade al padre del launcher)
@export var panel_parent_path: NodePath

# Parámetros globales por defecto (pueden ser sobrescritos por cada slot)
@export var typewriter_cps: float = 40.0
@export var pre_entry_delay: float = 0.0
@export var between_chunks_delay: float = 0.3
@export var exit_delay: float = 0.0
@export var auto_free_on_exit: bool = true

# Controlador de personaje asociado
@export var character_controller_path: NodePath

# Reutilizar el mismo panel para toda la secuencia (global)
@export var reuse_single_panel: bool = false

# === NUEVAS CONFIGURACIONES DE AVANCE ===
@export_group("Auto Advance Settings")
# Controla si hay avance automático entre diálogos
@export var auto_advance_between_items: bool = true
# Tiempo de espera antes del avance automático (en segundos)
@export var auto_advance_delay: float = 2.0

# === CONFIGURACIÓN DE INPUT MANUAL ===
@export_group("Manual Input Settings")
# Usar el sistema de mapeo personalizado (FGGlobal) o una acción de InputMap directa
@export var use_custom_input_mapping: bool = true
# Nombre del mapeo/acción para avanzar ("accept" si es custom, o por ejemplo "ui_accept" si no)
@export var advance_action_name: String = "accept"

# Internos
var _cancelled: bool = false
var _input_consumed: bool = false  # Nueva variable para controlar input

func _ready():
	# Asegurarse de que el nodo procese input
	process_mode = Node.PROCESS_MODE_ALWAYS

func _get_panel_scene_reference(panel_node: Node) -> PackedScene:
	"""Obtiene una referencia a la escena de origen de un panel instanciado"""
	if not panel_node:
		return null
	
	# Obtener el path de la escena original
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

func _get_character_controller() -> Node:
	if character_controller_path != NodePath(""):
		return get_node_or_null(character_controller_path)
	return null

func _resolve_panel_scene_path(override_path: String) -> String:
	if override_path.strip_edges() != "":
		return override_path
	
	# Intentar overrides por personaje vía FGGlobal
	if Engine.is_editor_hint():
		return ""  # En editor no forzar dependencias
	
	if typeof(FGGlobal) != TYPE_NIL and FGGlobal:
		var p = FGGlobal.get_dialog_panel_scene(character_name)
		if p.strip_edges() != "":
			return p
		# Default global
		return String(FGGlobal.dialog_config.get("default_panel_scene", ""))
	return ""

func _panel_from_path(path: String) -> Node:
	if path.strip_edges() == "":
		return null
	var s = load(path)
	if s and s is PackedScene:
		return (s as PackedScene).instantiate()
	return null

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
	
	# Usar valores del slot si están definidos, sino los globales
	var cps = slot.typewriter_cps if slot.typewriter_cps > 0 else typewriter_cps
	var pre = slot.pre_entry_delay
	var between = slot.between_chunks_delay
	var exit = slot.exit_delay
	var auto_free = slot.auto_free_on_exit
	
	# Configurar parámetros si el controller expone los métodos
	if controller.has_method("set_typewriter_speed"):
		controller.set_typewriter_speed(cps)
	
	if controller.has_method("set_delays"):
		controller.set_delays(pre, between, exit)
	
	if _has_property(controller, "auto_free_on_exit"):
		controller.set("auto_free_on_exit", auto_free)

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

# CORREGIDO: Función para esperar entre diálogos según configuración
func _await_between_dialogue_advance(is_last_dialogue: bool = false) -> void:
	if auto_advance_between_items and not is_last_dialogue:
		# Avance automático con posibilidad de skip por input configurado (solo para diálogos intermedios)
		if auto_advance_delay > 0.0:
			_input_consumed = false  # Resetear flag de input
			var elapsed_time := 0.0
			var delta_time := 0.0
			
			# Esperar usando delta time acumulado
			while not _cancelled and elapsed_time < auto_advance_delay:
				if _is_advance_pressed():
					# Input detectado, salir inmediatamente
					_input_consumed = true
					break
				
				await get_tree().process_frame
				delta_time = get_process_delta_time()
				elapsed_time += delta_time
		else:
			# Sin delay, avanzar inmediatamente pero permitir skip
			await get_tree().process_frame
			if _is_advance_pressed():
				_input_consumed = true
	elif is_last_dialogue:
		# Para el último diálogo, aplicar un delay de visualización sin avance automático
		if auto_advance_delay > 0.0:
			_input_consumed = false
			var elapsed_time := 0.0
			var delta_time := 0.0
			
			# Permitir que el usuario vea el último diálogo por un tiempo mínimo
			var min_display_time = auto_advance_delay * 0.5  # La mitad del tiempo normal
			while not _cancelled and elapsed_time < min_display_time:
				if _is_advance_pressed():
					_input_consumed = true
					break
				
				await get_tree().process_frame
				delta_time = get_process_delta_time()
				elapsed_time += delta_time
		
		# Después del tiempo mínimo, esperar input del usuario
		if not _cancelled and not _input_consumed:
			await _await_advance_input()
	else:
		# Avance manual: esperar input del usuario
		await _await_advance_input()

func _await_advance_input() -> void:
	# Espera a que se pulse el input configurado para avanzar
	_input_consumed = false
	while not _cancelled and not _input_consumed:
		if _is_advance_pressed():
			_input_consumed = true
			break
		await get_tree().process_frame

func _is_advance_pressed() -> bool:
	# Evitar detectar el mismo input múltiples veces
	if _input_consumed:
		return false
		
	var name := advance_action_name.strip_edges()
	if name == "":
		name = "accept" if use_custom_input_mapping else "ui_accept"
	
	# 1) Sistema de mapeo personalizado (si está disponible)
	if use_custom_input_mapping and typeof(FGGlobal) != TYPE_NIL and FGGlobal:
		if FGGlobal.has_method("is_custom_action_just_pressed"):
			if FGGlobal.is_custom_action_just_pressed(name):
				return true
		
		# Intentar resolver mapeos efectivos y consultar InputMap directamente
		if FGGlobal.has_method("get_effective_input_mapping"):
			var mappings = FGGlobal.get_effective_input_mapping(name)
			if mappings and mappings.size() > 0:
				for m in mappings:
					var act = str(m)
					if InputMap.has_action(act) and Input.is_action_just_pressed(act):
						return true
	
	# 2) Fallback a InputMap con el mismo nombre
	if InputMap.has_action(name) and Input.is_action_just_pressed(name):
		return true
	
	return false

# Calcula el total de items en todos los slots
func _calculate_total_items() -> int:
	var total := 0
	for slot in slots:
		if slot and slot.is_valid():
			total += slot.get_total_items()
	return total

# Inicia la reproducción de todos los slots
func start() -> void:
	_cancelled = false
	_input_consumed = false
	
	var parent = _get_panel_parent()
	var char_ctrl = _get_character_controller()
	
	if slots.size() == 0:
		finished.emit()
		return
	
	# Calcular total de items
	var total := _calculate_total_items()
	started.emit(total)
	
	var global_index := 0
	var shared_panel: Node = null
	
	# Procesar cada slot
	for slot_idx in range(slots.size()):
		if _cancelled:
			break
			
		var slot = slots[slot_idx]
		if not slot or not slot.is_valid():
			continue
		
		var items = slot.build_items()
		
		# Procesar cada item del slot
		for item_idx in range(items.size()):
			if _cancelled:
				break
				
			var item = items[item_idx]
			var id = int(item.get("id", -1))
			
			if id < 0:
				continue
			
			item_started.emit(global_index, id)
			
			# Determinar si necesitamos un nuevo panel
			var current_panel: Node = null
			var panel_scene_needed: PackedScene = null
			var need_new_panel = false
			
			# Determinar personaje efectivo para este item
			var effective_char = slot.character if slot.character.strip_edges() != "" else _get_character_for_id(id)
			if effective_char.strip_edges() == "":
				effective_char = character_name
			
			if slot.panel_override:
				panel_scene_needed = slot.panel_override
			else:
				panel_scene_needed = _fallback_panel_for_character(effective_char)
			
			if reuse_single_panel:
				if not shared_panel:
					# Crear panel compartido la primera vez
					if panel_scene_needed:
						shared_panel = panel_scene_needed.instantiate()
						if shared_panel:
							parent.add_child(shared_panel)
					need_new_panel = true  # Es el primer panel
				else:
					# Verificar si necesitamos cambiar de panel (diferente escena)
					var current_scene = _get_panel_scene_reference(shared_panel)
					if current_scene != panel_scene_needed:
						# Necesitamos cambiar de panel - hacer exit del actual
						if shared_panel.has_method("request_exit"):
							await shared_panel.request_exit()
						else:
							shared_panel.queue_free()
						
						# Crear nuevo panel
						if panel_scene_needed:
							shared_panel = panel_scene_needed.instantiate()
							if shared_panel:
								parent.add_child(shared_panel)
						need_new_panel = true
				
				current_panel = shared_panel
			else:
				# Crear nuevo panel para cada item (comportamiento original)
				if panel_scene_needed:
					current_panel = panel_scene_needed.instantiate()
					if current_panel:
						parent.add_child(current_panel)
				need_new_panel = true
			
			if current_panel:
				_setup_panel(current_panel, slot)
				
				# Configurar personaje si es necesario
				if char_ctrl:
					if char_ctrl.has_method("set_expression") and slot.expression != "":
						char_ctrl.set_expression(slot.expression)
				
				# Mostrar diálogo
				var text = _get_text_for_id(id, effective_char)
				var display_name = _resolve_display_speaker_name(effective_char)
				
				# El panel usa play_dialog, no show_dialogue
				if current_panel.has_method("play_dialog"):
					await current_panel.play_dialog(text, display_name)
				elif current_panel.has_method("show_dialogue"):
					current_panel.show_dialogue(text, display_name)
					# Esperar a que termine el diálogo actual
					if current_panel.has_signal("dialogue_finished"):
						await current_panel.dialogue_finished
					elif current_panel.has_signal("dialog_completed"):
						await current_panel.dialog_completed
				
				# Determinar si este es el último diálogo
				var is_last_item = (slot_idx == slots.size() - 1) and (item_idx == items.size() - 1)
				
				# Aplicar lógica de avance (ahora incluye manejo especial para último diálogo)
				if not _cancelled:
					await _await_between_dialogue_advance(is_last_item)
				
				# Solo hacer exit si NO reutilizamos panel O si es el último item
				var should_exit_panel = false
				if not reuse_single_panel:
					should_exit_panel = true  # Siempre hacer exit si no reutilizamos
				elif is_last_item:
					should_exit_panel = true  # Exit solo en el último item cuando reutilizamos
				
				if should_exit_panel and current_panel.has_method("request_exit"):
					await current_panel.request_exit()
				elif should_exit_panel and not reuse_single_panel:
					# Para paneles individuales sin request_exit
					if current_panel and is_instance_valid(current_panel):
						current_panel.queue_free()
				
				item_finished.emit(global_index, id)
				global_index += 1
	
	finished.emit()
