@tool
extends Node

# ============================================================================
# FENNEC TOOLS - AUTOLOAD GLOBAL COMPARTIDO
# Sistema unificado para múltiples herramientas de desarrollo
# ============================================================================

# Variables de configuración del sistema
var config = ConfigFile.new()
var config_path = "user://fennec_settings.cfg"

# ============================================================================
# SISTEMA DE CONDICIONALES - SIMPLIFICADO CON SLOTS
# ============================================================================
var plugin_condicionales_path: String = "res://addons/FennecTools/data/fennec_conditionals.json"
var condicionales: Array = []

var current_save_slot: int = 1
var save_slots: Dictionary = {}  # slot_id -> condicionales_data

var _conditionals_initialized: bool = false

# ============================================================================
# SISTEMA DE TRADUCCIONES
# ============================================================================
var current_language = "EN"
var current_target_group: String = "ui"  # Added variable to store target group
var translations: Dictionary = {}
var translation_groups: Dictionary = {}

# ============================================================================
# SISTEMA DE DIÁLOGOS
# ============================================================================
var dialog_data: Array = []
var dialog_config: Dictionary = {
	"default_panel_scene": "",
	"character_overrides": {}
}
var dialog_queue: Array = []
var is_dialog_active: bool = false
var current_character: CharacterBody3D = null
var talk = false

# === SISTEMA DE NOMBRES DINÁMICOS DE PERSONAJES ===
# Diccionario global para nombres personalizados asignados por código
# Claves normales: to_lower() y strip_edges() de la clave lógica de personaje
var dynamic_character_names: Dictionary = {}

# ============================================================================
# SISTEMA DE CONFIGURACIÓN (heredado de tu código original)
# ============================================================================
var Audio_Master = 0.0
var Audio_Music = 0.0
var Audio_Sounds = 0.0
var FOV = 45
var Full_screen = false
var Shadows = true

# ============================================================================
# SEÑALES PARA COMUNICACIÓN ENTRE MÓDULOS
# ============================================================================
signal conditional_changed(id: int, new_value: Variant)
signal language_changed(new_language: String)
signal dialog_started(dialog_id: int)
signal dialog_finished()
signal conditionals_loaded()

var input_mappings: Dictionary = {}

# ============================================================================
# SISTEMA DE CONTROL DE ENTRADA PERSONALIZABLE
# ============================================================================
var input_control_enabled: bool = false
var custom_input_mappings: Dictionary = {
	"up": ["ui_up"],
	"down": ["ui_down"], 
	"left": ["ui_left"],
	"right": ["ui_right"],
	"accept": ["ui_accept"],
	"back": ["ui_cancel"]
}

var interactable_group_name: String = "interactuable"

# Referencia al sistema de navegación
var navigation_system: Node = null

# Señales para el sistema de entrada
signal input_control_toggled(enabled: bool)
signal custom_input_detected(action: String)

var custom_actions_created: Dictionary = {}

# Variables adicionales en FGGlobal
var custom_input_json_path: String = "res://addons/FennecTools/data/fennec_custom_inputs.json"
var input_mappings_cache: Dictionary = {}

# ============================================================================
# SISTEMA DE ANIMACIÓN DE PERSONAJES POR DIÁLOGO
# ============================================================================

# Función para encontrar el nodo CharacterController por grupo de animación
func find_character_animation_node(character_group_name: String) -> Node:
	"""Encuentra el nodo CharacterController que pertenece al grupo especificado"""
	if character_group_name.is_empty():
		print("[FGGlobal] Advertencia: character_group_name está vacío")
		return null
	
	# Buscar todos los nodos en el grupo especificado
	var nodes_in_group = get_tree().get_nodes_in_group(character_group_name)
	
	if nodes_in_group.is_empty():
		print("[FGGlobal] No se encontraron nodos en el grupo: ", character_group_name)
		return null
	
	# Buscar el primer CharacterController en el grupo
	for node in nodes_in_group:
		if node is Node and node.has_method("set_expression"):
			# Verificar que tenga la propiedad character_group_name
			if node.has_method("get_current_expression") or node.has_method("set_expression"):
				print("[FGGlobal] Encontrado CharacterController en grupo ", character_group_name, ": ", node.name)
				return node
	
	# Si no se encuentra un CharacterController válido
	print("[FGGlobal] No se encontró CharacterController válido en el grupo: ", character_group_name)
	return null

# Función para animar un personaje por diálogo
# Mejorar las funciones de animación con mejor manejo de errores
func animate_character_for_dialogue(character_group_name: String, expression_id: int) -> bool:
	"""✅ CAMBIO: Ahora usa expression_id numérico"""
	if character_group_name.is_empty():
		print("[FGGlobal] Error: character_group_name está vacío")
		return false
	
	# expression_id = -1 significa no expresión
	if expression_id < 0:
		print("[FGGlobal] No expression to set (expression_id = -1)")
		return false
	
	var character_node = find_character_animation_node(character_group_name)
	if character_node:
		# Verificar si el índice de expresión existe
		if character_node.has_method("has_expression_index") and character_node.has_expression_index(expression_id):
			character_node.set_expression_by_id(expression_id)
			print("[FGGlobal] Expression ID '", expression_id, "' applied to character group: ", character_group_name)
			return true
		else:
			print("[FGGlobal] Warning: Expression ID '", expression_id, "' not found in character")
			# Intentar con expresión por defecto
			if character_node.has_method("set_expression_by_id"):
				var default_index = character_node.default_expression_index
				if default_index >= 0:
					character_node.set_expression_by_id(default_index)
					print("[FGGlobal] Using default expression index: '", default_index, "'")
					return true
	else:
		print("[FGGlobal] No se pudo animar personaje: grupo no encontrado - ", character_group_name)
		return false
	
	return false

# Función mejorada para iniciar animación de boca
func start_character_talking(character_group_name: String) -> bool:
	"""Inicia la animación de boca para el personaje especificado"""
	var character_node = find_character_animation_node(character_group_name)
	if character_node:
		if character_node.has_method("start_talking"):
			character_node.start_talking()
			print("[FGGlobal] Iniciando animación de boca para: ", character_group_name)
			return true
		else:
			print("[FGGlobal] Advertencia: CharacterController no tiene método start_talking")
	return false
	

# Función para detener animación de boca
func stop_character_talking(character_group_name: String) -> bool:
	"""Detiene la animación de boca para el personaje especificado"""
	var character_node = find_character_animation_node(character_group_name)
	if character_node and character_node.has_method("stop_talking"):
		character_node.stop_talking()
		print("[FGGlobal] Deteniendo animación de boca para: ", character_group_name)
		return true
	return false

# Función para obtener la expresión actual de un personaje
func get_character_current_expression(character_group_name: String) -> String:
	"""Obtiene la expresión actual del personaje especificado"""
	var character_node = find_character_animation_node(character_group_name)
	if character_node and character_node.has_method("get_current_expression"):
		return character_node.get_current_expression()
	return ""

# Función para verificar si un personaje existe
func has_character_animation_node(character_group_name: String) -> bool:
	"""Verifica si existe un CharacterController para el grupo especificado"""
	return find_character_animation_node(character_group_name) != null

# ============================================================================
# FUNCIÓN _ready() MEJORADA
# ============================================================================
func _ready():
	
	# Crear directorios necesarios
	ensure_directories()
	
	# Migrar datos legacy si es necesario
	migrate_legacy_data()
	
	
	await initialize_conditionals_safe()
	
	load_input_control_settings()
	
	initialize_translations()
	initialize_dialogs()
	
	setup_input_control_system()
	
	# Verificar integridad
	verify_data_integrity()
	
	if current_save_slot != -1:
		sync_slot_with_original(current_save_slot)

# ============================================================================
# SISTEMA DE CONDICIONALES SIMPLIFICADO CON SLOTS
# ============================================================================
func initialize_conditionals_safe():
	"""Inicializa condicionales usando sistema de slots simplificado"""
	if _conditionals_initialized:
		print("[FGGlobal] Condicionales ya inicializadas")
		return
	
	print("[FGGlobal] Inicializando sistema de condicionales con slot ", current_save_slot, "...")
	
	if not load_save_slot(current_save_slot):
		print("[FGGlobal] Creando slot ", current_save_slot, " desde archivo base...")
		if load_conditionals_from_plugin():
			duplicate_conditionals_for_save_slot(current_save_slot)
			load_save_slot(current_save_slot)
		else:
			# Si no hay archivo base, crear estructura vacía
			print("[FGGlobal] Creando estructura de condicionales vacía")
			condicionales = []
			save_slot_conditionals(current_save_slot)
	
	_conditionals_initialized = true
	conditionals_loaded.emit()
	print("[FGGlobal] Condicionales inicializadas en slot ", current_save_slot, ": ", condicionales.size(), " elementos")

func load_conditionals_from_plugin() -> bool:
	"""Carga condicionales desde el archivo base del plugin"""
	if not FileAccess.file_exists(plugin_condicionales_path):
		print("[FGGlobal] Archivo base no existe: ", plugin_condicionales_path)
		return false
	
	var file = FileAccess.open(plugin_condicionales_path, FileAccess.READ)
	if not file:
		print("[FGGlobal] Error abriendo archivo base: ", plugin_condicionales_path)
		return false
	
	var json_data = file.get_as_text()
	file.close()
	
	if json_data.is_empty():
		print("[FGGlobal] Archivo base vacío: ", plugin_condicionales_path)
		return false
	
	var result = JSON.parse_string(json_data)
	if result == null:
		print("[FGGlobal] Error parseando JSON base: ", plugin_condicionales_path)
		return false
	
	if not result.has("condicionales"):
		print("[FGGlobal] JSON base sin estructura 'condicionales': ", plugin_condicionales_path)
		return false
	
	condicionales = result.condicionales
	print("[FGGlobal] Cargadas ", condicionales.size(), " condicionales desde archivo base")
	return true

func save_slot_conditionals(slot_id: int):
	"""Guarda condicionales del slot específico solo en user://"""
	var slot_path = "user://fennec_conditionals_slot_" + str(slot_id) + ".json"
	var data = {"condicionales": condicionales, "slot_id": slot_id}
	var json_string = JSON.stringify(data)
	
	var file = FileAccess.open(slot_path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("[FGGlobal] Condicionales guardadas en slot ", slot_id)
	else:
		print("[FGGlobal] Error guardando slot ", slot_id)

func load_conditionals_from_file(file_path: String) -> bool:
	"""Carga condicionales desde un archivo específico"""
	if not FileAccess.file_exists(file_path):
		print("[FGGlobal] Archivo no existe: ", file_path)
		return false
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("[FGGlobal] Error abriendo archivo: ", file_path)
		return false
	
	var json_data = file.get_as_text()
	file.close()
	
	if json_data.is_empty():
		print("[FGGlobal] Archivo vacío: ", file_path)
		return false
	
	var result = JSON.parse_string(json_data)
	if result == null:
		print("[FGGlobal] Error parseando JSON: ", file_path)
		return false
	
	if not result.has("condicionales"):
		print("[FGGlobal] JSON sin estructura 'condicionales': ", file_path)
		return false
	
	condicionales = result.condicionales
	print("[FGGlobal] Cargadas ", condicionales.size(), " condicionales desde: ", file_path)
	return true

func duplicate_conditionals_json() -> bool:
	"""Duplica el archivo original a la ubicación de trabajo"""
	var condicionales_path = "res://data/Progresos.json"
	if not FileAccess.file_exists(condicionales_path):
		print("[FGGlobal] Archivo original no existe: ", condicionales_path)
		return false
	
	var file = FileAccess.open(condicionales_path, FileAccess.READ)
	if not file:
		print("[FGGlobal] Error abriendo archivo original")
		return false
	
	var json_data = file.get_as_text()
	file.close()
	
	var file_copy = FileAccess.open("user://fennec_conditionals.json", FileAccess.WRITE)
	if not file_copy:
		print("[FGGlobal] Error creando copia")
		return false
	
	file_copy.store_string(json_data)
	file_copy.close()
	print("[FGGlobal] Copia creada en: user://fennec_conditionals.json")
	return true

func check_condition(id_condition: int) -> Variant:
	"""Verifica una condición por ID con manejo de errores mejorado"""
	if not _conditionals_initialized:
		print("[FGGlobal] Advertencia: Condicionales no inicializadas")
		return null
	
	for conditional in condicionales:
		if conditional.has("id") and conditional.id == id_condition:
			match conditional.get("tipo", ""):
				"booleano":
					return conditional.get("valor_bool", false)
				"numerico":
					return conditional.get("valor_float", 0.0) 
				"textos":
					return conditional.get("valores_texto", [])
				_:
					print("[FGGlobal] Tipo de condicional desconocido: ", conditional.get("tipo", ""))
					return null
	
	print("[FGGlobal] Condición con ID ", id_condition, " no encontrada.")
	return null

# Función para verificar si un texto del usuario coincide con alguno de los valores
func check_text_condition(id_condition: int, input_text: String) -> bool:
	"""Verifica si un texto coincide con alguno de los valores de una condicional de texto"""
	if not _conditionals_initialized:
		print("[FGGlobal] Advertencia: Condicionales no inicializadas")
		return false
	
	for conditional in condicionales:
		if conditional.has("id") and conditional.id == id_condition:
			match conditional.get("tipo", ""):
				"textos":
					var valores = conditional.get("valores_texto", [])
					var input_lower = input_text.to_lower().strip_edges()
					for valor in valores:
						if input_lower == valor.to_lower().strip_edges():
							return true
					return false
				_:
					print("[FGGlobal] Condicional ", id_condition, " no es de tipo texto")
					return false
	
	print("[FGGlobal] Condición con ID ", id_condition, " no encontrada.")
	return false

# Función para obtener un texto específico por índice
func get_text_value(id_condition: int, index: int = 0) -> String:
	"""Obtiene un texto específico de una condicional de texto por índice"""
	if not _conditionals_initialized:
		print("[FGGlobal] Advertencia: Condicionales no inicializadas")
		return ""
	
	for conditional in condicionales:
		if conditional.has("id") and conditional.id == id_condition:
			match conditional.get("tipo", ""):
				"textos":
					var valores = conditional.get("valores_texto", [])
					if index >= 0 and index < valores.size():
						return valores[index]
					else:
						print("[FGGlobal] Índice fuera de rango para condicional ", id_condition)
						return ""
				_:
					print("[FGGlobal] Condicional ", id_condition, " no es de tipo texto")
					return ""
	
	print("[FGGlobal] Condición con ID ", id_condition, " no encontrada.")
	return ""

# Función para obtener un texto aleatorio de la lista
func get_random_text_value(id_condition: int) -> String:
	"""Obtiene un texto aleatorio de una condicional de texto"""
	if not _conditionals_initialized:
		print("[FGGlobal] Advertencia: Condicionales no inicializadas")
		return ""
	
	for conditional in condicionales:
		if conditional.has("id") and conditional.id == id_condition:
			match conditional.get("tipo", ""):
				"textos":
					var valores = conditional.get("valores_texto", [])
					if valores.size() > 0:
						return valores[randi() % valores.size()]
					else:
						print("[FGGlobal] No hay valores de texto en condicional ", id_condition)
						return ""
				_:
					print("[FGGlobal] Condicional ", id_condition, " no es de tipo texto")
					return ""
	
	print("[FGGlobal] Condición con ID ", id_condition, " no encontrada.")
	return ""

# Función para obtener toda la lista de textos
func get_all_text_values(id_condition: int) -> Array:
	"""Obtiene todos los valores de texto de una condicional"""
	if not _conditionals_initialized:
		print("[FGGlobal] Advertencia: Condicionales no inicializadas")
		return []
	
	for conditional in condicionales:
		if conditional.has("id") and conditional.id == id_condition:
			match conditional.get("tipo", ""):
				"textos":
					return conditional.get("valores_texto", [])
				_:
					print("[FGGlobal] Condicional ", id_condition, " no es de tipo texto")
					return []
	
	print("[FGGlobal] Condición con ID ", id_condition, " no encontrada.")
	return []

# Función para agregar un texto a la lista
func add_text_value(id_condition: int, new_text: String) -> bool:
	"""Agrega un nuevo texto a una condicional de texto"""
	if not _conditionals_initialized:
		print("[FGGlobal] Error: Condicionales no inicializadas")
		return false
	
	for conditional in condicionales:
		if conditional.has("id") and conditional.id == id_condition:
			match conditional.get("tipo", ""):
				"textos":
					if not conditional.has("valores_texto"):
						conditional.valores_texto = []
					
					var text_clean = new_text.strip_edges()
					if text_clean != "" and text_clean not in conditional.valores_texto:
						conditional.valores_texto.append(text_clean)
						save_slot_conditionals(current_save_slot)
						conditional_changed.emit(id_condition, conditional.valores_texto)
						print("[FGGlobal] Texto agregado a condicional ", id_condition, ": ", text_clean)
						return true
					else:
						print("[FGGlobal] Texto vacío o ya existe en condicional ", id_condition)
						return false
				_:
					print("[FGGlobal] Condicional ", id_condition, " no es de tipo texto")
					return false
	
	print("[FGGlobal] Condición con ID ", id_condition, " no encontrada.")
	return false

# Función para remover un texto específico
func remove_text_value(id_condition: int, text_to_remove: String) -> bool:
	"""Remueve un texto específico de una condicional de texto"""
	if not _conditionals_initialized:
		print("[FGGlobal] Error: Condicionales no inicializadas")
		return false
	
	for conditional in condicionales:
		if conditional.has("id") and conditional.id == id_condition:
			match conditional.get("tipo", ""):
				"textos":
					if conditional.has("valores_texto"):
						var removed = conditional.valores_texto.erase(text_to_remove)
						if removed:
							save_slot_conditionals(current_save_slot)
							conditional_changed.emit(id_condition, conditional.valores_texto)
							print("[FGGlobal] Texto removido de condicional ", id_condition, ": ", text_to_remove)
							return true
						else:
							print("[FGGlobal] Texto no encontrado en condicional ", id_condition)
							return false
					else:
						print("[FGGlobal] No hay valores de texto en condicional ", id_condition)
						return false
				_:
					print("[FGGlobal] Condicional ", id_condition, " no es de tipo texto")
					return false
	
	print("[FGGlobal] Condición con ID ", id_condition, " no encontrada.")
	return false

# Función para obtener el número de textos en una condicional
func get_text_count(id_condition: int) -> int:
	"""Obtiene el número de textos en una condicional de texto"""
	if not _conditionals_initialized:
		print("[FGGlobal] Advertencia: Condicionales no inicializadas")
		return 0
	
	for conditional in condicionales:
		if conditional.has("id") and conditional.id == id_condition:
			match conditional.get("tipo", ""):
				"textos":
					return conditional.get("valores_texto", []).size()
				_:
					print("[FGGlobal] Condicional ", id_condition, " no es de tipo texto")
					return 0
	
	print("[FGGlobal] Condición con ID ", id_condition, " no encontrada.")
	return 0

func modify_condition(id_condition: int, new_value: Variant, operation: String = "replace"):
	"""Modifica una condición - solo afecta el slot actual del usuario"""
	if not _conditionals_initialized:
		print("[FGGlobal] Error: Condicionales no inicializadas")
		return
	
	for conditional in condicionales:
		if conditional.has("id") and conditional.id == id_condition:
			var tipo = conditional.get("tipo", "")
			
			match tipo:
				"booleano":
					if typeof(new_value) == TYPE_BOOL:
						conditional.valor_bool = new_value
						save_slot_conditionals(current_save_slot)
						conditional_changed.emit(id_condition, new_value)
						print("[FGGlobal] Condicional booleana actualizada: ID ", id_condition, " = ", new_value)
						return
					else:
						print("[FGGlobal] Error: Valor no booleano para condicional booleana")
				
				"numerico":
					if typeof(new_value) in [TYPE_FLOAT, TYPE_INT]:
						var float_value = float(new_value)
						match operation:
							"add", "sumar":
								conditional.valor_float += float_value
							"subtract", "restar":
								conditional.valor_float -= float_value
							_: # "replace"
								conditional.valor_float = float_value
						
						save_slot_conditionals(current_save_slot)
						conditional_changed.emit(id_condition, conditional.valor_float)
						print("[FGGlobal] Condicional numérica actualizada: ID ", id_condition, " = ", conditional.valor_float)
						return
					else:
						print("[FGGlobal] Error: Valor no numérico para condicional numérica")
				
				"textos":
					if typeof(new_value) == TYPE_ARRAY:
						conditional.valores_texto = new_value
						save_slot_conditionals(current_save_slot)
						conditional_changed.emit(id_condition, new_value)
						print("[FGGlobal] Condicional de texto múltiple actualizada: ID ", id_condition, " = ", new_value)
						return
					elif typeof(new_value) == TYPE_STRING:
						# Si se pasa un string, agregarlo a la lista
						if not conditional.has("valores_texto"):
							conditional.valores_texto = []
						match operation:
							"add":
								if new_value not in conditional.valores_texto:
									conditional.valores_texto.append(new_value)
							"remove":
								conditional.valores_texto.erase(new_value)
							_: # "replace"
								conditional.valores_texto = [new_value]
						save_slot_conditionals(current_save_slot)
						conditional_changed.emit(id_condition, conditional.valores_texto)
						print("[FGGlobal] Condicional de texto múltiple actualizada: ID ", id_condition, " = ", conditional.valores_texto)
						return
					else:
						print("[FGGlobal] Error: Valor no válido para condicional de texto múltiple")
				
				_:
					print("[FGGlobal] Error: Tipo de condicional desconocido: ", tipo)
			return
	
	print("[FGGlobal] Condición con ID ", id_condition, " no encontrada.")

func duplicate_conditionals_for_save_slot(slot_id: int) -> bool:
	"""Duplica las condicionales actuales para una partida específica"""
	if not _conditionals_initialized:
		print("[FGGlobal] Error: Condicionales no inicializadas")
		return false
	
	# Crear una copia profunda de las condicionales actuales
	var duplicated_conditionals = []
	for conditional in condicionales:
		var duplicated = {}
		for key in conditional:
			duplicated[key] = conditional[key]
		
		duplicated.slot_id = slot_id
		duplicated.original_id = duplicated.get("id", 0)
		
		duplicated_conditionals.append(duplicated)
	
	# Guardar en el diccionario de slots
	save_slots[slot_id] = duplicated_conditionals
	
	# Guardar en archivo específico del slot
	var slot_path = "user://fennec_conditionals_slot_" + str(slot_id) + ".json"
	var data = {"condicionales": duplicated_conditionals, "slot_id": slot_id}
	var json_string = JSON.stringify(data)
	
	var file = FileAccess.open(slot_path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("[FGGlobal] Condicionales duplicadas para slot ", slot_id, ": ", duplicated_conditionals.size(), " elementos")
		return true
	else:
		print("[FGGlobal] Error guardando slot ", slot_id)
		return false

func load_save_slot(slot_id: int) -> bool:
	"""Carga las condicionales de una partida específica"""
	var slot_path = "user://fennec_conditionals_slot_" + str(slot_id) + ".json"
	
	if not FileAccess.file_exists(slot_path):
		print("[FGGlobal] Slot ", slot_id, " no existe")
		return false
	
	var file = FileAccess.open(slot_path, FileAccess.READ)
	if not file:
		print("[FGGlobal] Error abriendo slot ", slot_id)
		return false
	
	var json_data = file.get_as_text()
	file.close()
	
	var result = JSON.parse_string(json_data)
	if result == null or not result.has("condicionales"):
		print("[FGGlobal] Error parseando slot ", slot_id)
		return false
	
	condicionales = result.condicionales
	current_save_slot = slot_id
	save_slots[slot_id] = condicionales
	
	print("[FGGlobal] Slot ", slot_id, " cargado: ", condicionales.size(), " condicionales")
	conditionals_loaded.emit()
	return true

func get_available_save_slots() -> Array:
	"""Obtiene la lista de slots de guardado disponibles"""
	var slots = []
	var dir = DirAccess.open("user://")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.begins_with("fennec_conditionals_slot_") and file_name.ends_with(".json"):
				var slot_str = file_name.replace("fennec_conditionals_slot_", "").replace(".json", "")
				if slot_str.is_valid_int():
					slots.append(int(slot_str))
			file_name = dir.get_next()
	
	slots.sort()
	return slots

func delete_save_slot(slot_id: int) -> bool:
	"""Elimina un slot de guardado"""
	var slot_path = "user://fennec_conditionals_slot_" + str(slot_id) + ".json"
	
	if FileAccess.file_exists(slot_path):
		DirAccess.remove_absolute(slot_path)
		save_slots.erase(slot_id)
		print("[FGGlobal] Slot ", slot_id, " eliminado")
		return true
	
	return false

func get_conditional_groups() -> Array:
	"""Obtiene la lista de grupos únicos de condicionales"""
	var groups = []
	
	if not _conditionals_initialized:
		return groups
	
	for conditional in condicionales:
		var group = conditional.get("grupo", "default")
		if group not in groups:
			groups.append(group)
	
	groups.sort()
	return groups

# ============================================================================
# GESTIÓN DE DIRECTORIOS Y ARCHIVOS
# ============================================================================
func ensure_directories():
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("user://fennec_data"):
		dir.make_dir("fennec_data")

func ensure_plugin_data_directory():
	var dir = DirAccess.open("res://addons/FennecTools/")
	if dir and not dir.dir_exists("data"):
		dir.make_dir("data")

# ============================================================================
# VERIFICACIÓN DE INTEGRIDAD DE DATOS
# ============================================================================
func verify_data_integrity():
	"""Verifica que los datos JSON estén en formato correcto"""
	var issues = []
	
	# Verificar condicionales
	for i in range(condicionales.size()):
		var conditional = condicionales[i]
		if not conditional.has("id") or not conditional.has("nombre") or not conditional.has("tipo"):
			issues.append("Condicional en índice " + str(i) + " tiene estructura incompleta")
	
	# Verificar traducciones
	for lang in translations:
		if not typeof(translations[lang]) == TYPE_DICTIONARY:
			issues.append("Traducciones para idioma '" + lang + "' no es un diccionario")
	
	if issues.size() > 0:
		print("[FGGlobal] Problemas de integridad encontrados:")
		for issue in issues:
			print("  - " + issue)
	else:
		print("[FGGlobal] Integridad de datos verificada correctamente")
	
	return issues.size() == 0

# ============================================================================
# MIGRACIÓN DE DATOS LEGACY
# ============================================================================
func migrate_legacy_data():
	"""Migra datos del formato antiguo al nuevo si es necesario"""
	var legacy_path = "res://data/Progresos.json"
	
	# Si existe el archivo legacy pero no el nuevo, hacer migración
	if FileAccess.file_exists(legacy_path) and not FileAccess.file_exists(plugin_condicionales_path):
		print("[FGGlobal] Migrando datos legacy...")
		duplicate_conditionals_json()
		
		# Migrar diálogos también
		var legacy_dialog_path = "res://data/Dialogos.json"
		var plugin_dialog_path = "res://addons/FennecTools/data/fennec_dialogues.json"
		
		if FileAccess.file_exists(legacy_dialog_path) and not FileAccess.file_exists(plugin_dialog_path):
			var file = FileAccess.open(legacy_dialog_path, FileAccess.READ)
			if file:
				var content = file.get_as_text()
				file.close()
				
				ensure_plugin_data_directory()
				var new_file = FileAccess.open(plugin_dialog_path, FileAccess.WRITE)
				if new_file:
					new_file.store_string(content)
					new_file.close()
					print("[FGGlobal] Diálogos legacy migrados")

# ============================================================================
# SISTEMA DE TRADUCCIONES
# ============================================================================
func initialize_translations():
	load_translations()

func load_translations():
	var translation_path = "res://addons/FennecTools/data/fennec_translations.json"
	if FileAccess.file_exists(translation_path):
		var file = FileAccess.open(translation_path, FileAccess.READ)
		if file:
			var json_data = file.get_as_text()
			file.close()
			var result = JSON.parse_string(json_data)
			if result:
				translations = result.get("translations", {})
				translation_groups = result.get("groups", {})
				
				# Cargar el grupo objetivo con múltiples fuentes
				current_target_group = result.get("target_group", 
					result.get("selected_group", "traducir"))
				
				print("[FGGlobal] Traducciones cargadas. Grupo objetivo: ", current_target_group)
			else:
				print("[FGGlobal] Error parseando archivo de traducciones")
				# Usar valores por defecto
				current_target_group = "traducir"
		else:
			print("[FGGlobal] Error leyendo archivo de traducciones")
			current_target_group = "traducir"
	else:
		print("[FGGlobal] Archivo de traducciones no existe, usando valores por defecto")
		current_target_group = "traducir"

func save_translations():
	var translation_path = "res://addons/FennecTools/data/fennec_translations.json"
	ensure_plugin_data_directory()
	var file = FileAccess.open(translation_path, FileAccess.WRITE)
	if file:
		var data = {
			"translations": translations,
			"groups": translation_groups,
			"target_group": current_target_group,
			"selected_group": current_target_group  # Para compatibilidad
		}
		file.store_string(JSON.stringify(data))
		file.close()
		print("[FGGlobal] Traducciones guardadas. Grupo objetivo: ", current_target_group)
	else:
		print("[FGGlobal] Error guardando traducciones")

func set_translation_target_group(group_name: String):
	"""Sets the target group for translations and saves it immediately"""
	if group_name.strip_edges().is_empty():
		group_name = "traducir"  # Valor por defecto
	
	current_target_group = group_name
	save_translations()  # Guardar inmediatamente
	print("[FGGlobal] Translation target group set to: ", group_name)
	
func update_language():
	"""Updates all nodes in the target group with current language translations"""
	if not get_tree():
		print("[FGGlobal] Error: No tree available")
		return
	
	var nodes_in_group = get_tree().get_nodes_in_group(current_target_group)
	if nodes_in_group.is_empty():
		print("[FGGlobal] Warning: No nodes found in group '", current_target_group, "'")
		return
	
	var updated_count = 0
	
	for node in nodes_in_group:
		if node is Label:
			var key = node.name
			if translations.has(current_language) and translations[current_language].has(key):
				node.text = translations[current_language][key]
				updated_count += 1
		elif node is Button:
			var key = node.name
			if translations.has(current_language) and translations[current_language].has(key):
				node.text = translations[current_language][key]
				updated_count += 1
	
	print("[FGGlobal] Updated ", updated_count, " nodes in group '", current_target_group, "' to language '", current_language, "'")
	language_changed.emit(current_language)

# ============================================================================
# SISTEMA DE DIÁLOGOS
# ============================================================================
func initialize_dialogs():
	load_dialog_data()
	load_dialog_config()

func load_dialog_data():
	var plugin_dialog_path = "res://addons/FennecTools/data/fennec_dialogues.json"
	var original_dialog_path = "res://data/Dialogos.json"
	
	if FileAccess.file_exists(plugin_dialog_path):
		var file = FileAccess.open(plugin_dialog_path, FileAccess.READ)
		if file:
			var text = file.get_as_text()
			file.close()
			var json = JSON.parse_string(text)
			if json != null and json.has("data"):
				dialog_data = json["data"]
	elif FileAccess.file_exists(original_dialog_path):
		var file = FileAccess.open(original_dialog_path, FileAccess.READ)
		if file:
			var text = file.get_as_text()
			file.close()
			var json = JSON.parse_string(text)
			if json != null and json.has("data"):
				dialog_data = json["data"]

func save_dialog_data():
	var dialog_path = "res://addons/FennecTools/data/fennec_dialogues.json"
	ensure_plugin_data_directory()
	var file = FileAccess.open(dialog_path, FileAccess.WRITE)
	if file:
		var data = {"data": dialog_data}
		file.store_string(JSON.stringify(data))
		file.close()

# Diálogo: cargar configuración (evita error en initialize_dialogs)
func load_dialog_config():
	var cfg_path = "res://addons/FennecTools/data/fennec_dialogue_config.json"
	if FileAccess.file_exists(cfg_path):
		var f = FileAccess.open(cfg_path, FileAccess.READ)
		if f:
			var txt = f.get_as_text()
			f.close()
			var parsed = JSON.parse_string(txt)
			if typeof(parsed) == TYPE_DICTIONARY:
				dialog_config = parsed
	else:
		# Mantener valores por defecto definidos en dialog_config
		pass

# Helpers del sistema de diálogos
# Obtiene el texto por id+personaje+idioma exactos; retorna "" si no existe
func get_dialog_text(id: int, character: String, language: String) -> String:
	var lang_u := str(language).to_upper()
	var char_s := str(character)
	for d in dialog_data:
		var e: Dictionary = d as Dictionary
		if int(e.get("id", -1)) == id and str(e.get("character", "")) == char_s and str(e.get("language", "")).to_upper() == lang_u:
			return str(e.get("text", ""))
	return ""

# Obtiene el primer texto que coincida con id e idioma, ignorando personaje
# Si no hay coincidencia por idioma, devuelve el primero que coincida por id
func get_dialog_text_by_id(id: int, language: String) -> String:
	var lang_u := str(language).to_upper()
	var fallback := ""
	for d in dialog_data:
		var e: Dictionary = d as Dictionary
		if int(e.get("id", -1)) == id:
			if str(e.get("language", "")).to_upper() == lang_u:
				return str(e.get("text", ""))
			elif fallback == "":
				fallback = str(e.get("text", ""))
	return fallback

# Retorna el path de panel asociado a un personaje, o el panel por defecto
func get_dialog_panel_scene(character: String) -> String:
	var cfg: Dictionary = dialog_config if typeof(dialog_config) == TYPE_DICTIONARY else {}
	var overrides: Dictionary = cfg.get("character_overrides", {})
	if typeof(overrides) == TYPE_DICTIONARY and overrides.has(character):
		var data = overrides[character]
		if typeof(data) == TYPE_DICTIONARY:
			var p := str(data.get("panel_scene", ""))
			if p.strip_edges() != "":
				return p
	return str(cfg.get("default_panel_scene", ""))

#

func start_dialog(dialog_id: int, dialog_count: int, show_question: bool = false, question_path: String = "", character: CharacterBody3D = null):
	if talk:
		print("[FGGlobal] Diálogo ya en curso, ignorando nueva solicitud.")
		return
	
	if get_tree().has_group("Diag"):
		var dialog_node = get_tree().get_nodes_in_group("Diag")[0]
		talk = true
		current_character = character
		dialog_started.emit(dialog_id)
		dialog_node.start_dialog(dialog_id, dialog_count, show_question, question_path, character)
	else:
		print("[FGGlobal] Error: No se encontró nodo en el grupo 'Diag'.")

# Función para sincronizar un slot con el JSON original
func sync_slot_with_original(slot_id: int) -> bool:
	"""Sincroniza un slot específico con el JSON original, agregando condicionales faltantes"""
	
	# Cargar condicionales originales
	var original_conditionals = []
	if not load_original_conditionals_to_array(original_conditionals):
		print("[FGGlobal] Error: No se pudo cargar JSON original para sincronización")
		return false
	
	# Cargar slot actual (si existe)
	var slot_path = "user://fennec_conditionals_slot_" + str(slot_id) + ".json"
	var current_slot_conditionals = []
	
	if FileAccess.file_exists(slot_path):
		if not load_slot_conditionals_to_array(slot_id, current_slot_conditionals):
			print("[FGGlobal] Error cargando slot ", slot_id, " para sincronización")
			return false
	else:
		print("[FGGlobal] Slot ", slot_id, " no existe, se creará con todas las condicionales originales")
	
	# Crear diccionario de IDs existentes en el slot para búsqueda rápida
	var existing_ids = {}
	for conditional in current_slot_conditionals:
		if conditional.has("id"):
			existing_ids[conditional.id] = true
	
	# Agregar condicionales faltantes
	var added_count = 0
	for original_conditional in original_conditionals:
		if original_conditional.has("id"):
			var id = original_conditional.id
			if not existing_ids.has(id):
				# Crear copia de la condicional original con valores por defecto
				var new_conditional = original_conditional.duplicate(true)
				reset_conditional_to_default(new_conditional)
				current_slot_conditionals.append(new_conditional)
				added_count += 1
				print("[FGGlobal] Agregada condicional faltante ID: ", id)
	
	# Actualizar condicionales actuales y guardar
	condicionales = current_slot_conditionals
	current_save_slot = slot_id
	save_slot_conditionals(slot_id)
	
	print("[FGGlobal] Sincronización completada. Agregadas ", added_count, " condicionales al slot ", slot_id)
	conditionals_loaded.emit()
	return true

# Función auxiliar para cargar condicionales originales a un array
func load_original_conditionals_to_array(target_array: Array) -> bool:
	"""Carga las condicionales del JSON original a un array específico"""
	if not FileAccess.file_exists(plugin_condicionales_path):
		print("[FGGlobal] Archivo original no existe: ", plugin_condicionales_path)
		return false
	
	var file = FileAccess.open(plugin_condicionales_path, FileAccess.READ)
	if not file:
		print("[FGGlobal] Error abriendo archivo original")
		return false
	
	var json_data = file.get_as_text()
	file.close()
	
	var result = JSON.parse_string(json_data)
	if result == null or not result.has("condicionales"):
		print("[FGGlobal] Error parseando JSON original")
		return false
	
	target_array.clear()
	target_array.append_array(result.condicionales)
	return true

# Función auxiliar para cargar condicionales de slot a un array
func load_slot_conditionals_to_array(slot_id: int, target_array: Array) -> bool:
	"""Carga las condicionales de un slot específico a un array"""
	var slot_path = "user://fennec_conditionals_slot_" + str(slot_id) + ".json"
	
	if not FileAccess.file_exists(slot_path):
		return false
	
	var file = FileAccess.open(slot_path, FileAccess.READ)
	if not file:
		return false
	
	var json_data = file.get_as_text()
	file.close()
	
	var result = JSON.parse_string(json_data)
	if result == null or not result.has("condicionales"):
		return false
	
	target_array.clear()
	target_array.append_array(result.condicionales)
	return true

# Función para resetear una condicional a sus valores por defecto
# Función corregida para resetear una condicional a sus valores por defecto
func reset_conditional_to_default(conditional: Dictionary):
	"""Resetea una condicional a sus valores por defecto según su tipo"""
	var tipo = conditional.get("tipo", "")
	
	match tipo:
		"booleano":
			conditional.valor_bool = conditional.get("valor_defecto", false)
		"numerico":
			conditional.valor_float = conditional.get("valor_defecto", 0.0)
		"textos":
			# <CHANGE> Asegurar que valores_texto se copie correctamente del original
			var valores_originales = conditional.get("valores_defecto", [])
			if valores_originales.is_empty():
				# Si no hay valores_defecto, usar valores_texto del original
				valores_originales = conditional.get("valores_texto", [])
			
			# Crear una copia profunda del array
			conditional.valores_texto = []
			for valor in valores_originales:
				conditional.valores_texto.append(str(valor))


# Función para sincronizar todos los slots existentes
func sync_all_slots_with_original():
	"""Sincroniza todos los slots existentes con el JSON original"""
	var available_slots = get_available_save_slots()
	var synced_count = 0
	
	for slot_id in available_slots:
		if sync_slot_with_original(slot_id):
			synced_count += 1
	
	print("[FGGlobal] Sincronizados ", synced_count, " slots de ", available_slots.size(), " disponibles")


func load_save_slot_with_sync(slot_id: int) -> bool:
	if slot_needs_sync(slot_id):
		print("[FGGlobal] Slot ", slot_id, " necesita sincronización")
		sync_slot_with_original(slot_id)
	else:
		load_save_slot(slot_id)
	return true

# Función para verificar si un slot necesita sincronización
func slot_needs_sync(slot_id: int) -> bool:
	"""Verifica si un slot necesita sincronización con el JSON original"""
	var original_conditionals = []
	var slot_conditionals = []
	
	if not load_original_conditionals_to_array(original_conditionals):
		return false
	
	if not load_slot_conditionals_to_array(slot_id, slot_conditionals):
		return true  # Si no se puede cargar, probablemente necesita sincronización
	
	# Crear set de IDs del slot
	var slot_ids = {}
	for conditional in slot_conditionals:
		if conditional.has("id"):
			slot_ids[conditional.id] = true
	
	# Verificar si faltan condicionales
	for original_conditional in original_conditionals:
		if original_conditional.has("id") and not slot_ids.has(original_conditional.id):
			return true
	
	return false



func Partida(slot_id: String):
	"""Método principal para cambiar entre partidas - Uso: FGGlobal.Partida('1')"""
	var numeric_slot = 1  # Por defecto slot 1
	
	# Convertir string a int si es posible
	if slot_id.is_valid_int():
		numeric_slot = int(slot_id)
	else:
		# Si no es numérico, usar hash para generar ID único
		numeric_slot = abs(slot_id.hash()) % 1000
	
	print("[FGGlobal] Cambiando a partida: ", slot_id, " (ID numérico: ", numeric_slot, ")")
	
	# Si el slot no existe, crearlo duplicando las condicionales base
	if not load_save_slot(numeric_slot):
		print("[FGGlobal] Creando nueva partida: ", slot_id)
		if load_conditionals_from_plugin():
			duplicate_conditionals_for_save_slot(numeric_slot)
			load_save_slot(numeric_slot)
	
	current_save_slot = numeric_slot
	print("[FGGlobal] Partida activa: ", slot_id, " con ", condicionales.size(), " condicionales")

# ============================================================================
# UTILIDADES GENERALES
# ============================================================================

func save_game_data():
	var file = FileAccess.open("user://fennec_gamedata.dat", FileAccess.WRITE)
	if file:
		var data = {
			"current_language" = current_language,
			"Audio_Master" = Audio_Master,
			"Audio_Music" = Audio_Music,
			"Audio_Sounds" = Audio_Sounds,
			"FOV" = FOV,
			"Full_screen" = Full_screen,
			"Shadows" = Shadows
		}
		file.store_var(data)
		file.close()

func load_game_data():
	if FileAccess.file_exists("user://fennec_gamedata.dat"):
		var file = FileAccess.open("user://fennec_gamedata.dat", FileAccess.READ)
		if file:
			var data = file.get_var()
			file.close()
			current_language = data.get("current_language", "EN")
			Audio_Master = data.get("Audio_Master", 0.0)
			Audio_Music = data.get("Audio_Music", 0.0)
			Audio_Sounds = data.get("Audio_Sounds", 0.0)
			FOV = data.get("FOV", 45)
			Full_screen = data.get("Full_screen", false)
			Shadows = data.get("Shadows", false)

func reset_game_data():
	current_language = "EN"
	Audio_Master = 0.0
	Audio_Music = 0.0
	Audio_Sounds = 0.0
	FOV = 45
	Full_screen = false
	Shadows = false
	var save_path = "user://fennec_gamedata.dat"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
func save_conditionals() -> bool:
	"""Función de compatibilidad para conditional_editor.gd - guarda en archivo base"""
	return save_conditionals_to_plugin()

func save_conditionals_to_plugin() -> bool:
	"""Guarda condicionales en el archivo original del plugin - SOLO para uso del editor"""
	ensure_plugin_data_directory()
	
	var data = {"condicionales": condicionales}
	var json_string = JSON.stringify(data)
	
	var file = FileAccess.open(plugin_condicionales_path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("[FGGlobal] Condicionales guardadas en archivo base del plugin")
		return true
	else:
		print("[FGGlobal] Error guardando en archivo base del plugin")
		return false

func get_translation(key: String, language: String = "") -> String:
	var lang = language if language != "" else current_language
	if translations.has(lang) and translations[lang].has(key):
		return translations[lang][key]
	return key # Retorna la clave si no encuentra traducción

# ============================================================================
# Funciones del sistema de control de entrada
# ============================================================================

# Función para actualización de la navegación
func navigation_refresh():
	"""Fuerza la actualización del sistema de navegación"""
	if navigation_system and navigation_system.has_method("refresh_interactables"):
		navigation_system.refresh_interactables()
		print("[FGGlobal] Sistema de navegación actualizado manualmente")


func setup_input_control_system():
	"""Configura el sistema de control de entrada personalizable"""
	# Cargar mapeos personalizados desde JSON primero
	load_custom_input_mappings()
	
	# Crear el sistema de navegación si no existe
	if not navigation_system:
		var navigation_scene = preload("res://addons/FennecTools/data/input_navigation_system.gd")
		navigation_system = navigation_scene.new()
		navigation_system.name = "InputNavigationSystem"
		add_child(navigation_system)
		
		# Conectar señales
		if navigation_system.has_signal("selection_changed"):
			navigation_system.selection_changed.connect(_on_navigation_selection_changed)


func _ensure_custom_input_actions():
	"""Crea acciones personalizadas en el InputMap si no existen"""
	for action in custom_input_mappings:
		var mappings = custom_input_mappings[action]
		for input_action in mappings:
			if not InputMap.has_action(input_action):
				# Crear la acción si no existe
				InputMap.add_action(input_action)
				print("[FGGlobal] Acción creada en InputMap: ", input_action)
				custom_actions_created[input_action] = true

func enable_input_control(enabled: bool):
	"""Activa o desactiva el sistema de control de entrada"""
	input_control_enabled = enabled
	
	if navigation_system:
		navigation_system.set_process(enabled)
		navigation_system.set_physics_process(enabled)
	
	# Aplicar mapeos personalizados cuando se habilita
	if enabled:
		apply_custom_input_mappings()
	
	# Guardar configuración en JSON
	save_custom_input_mappings()
	
	input_control_toggled.emit(enabled)
	print("[FGGlobal] Sistema de control de entrada: ", "ACTIVADO" if enabled else "DESACTIVADO")

func set_custom_input_mapping(action: String, inputs: Array):
	"""Define un mapeo personalizado para una acción"""
	if action in custom_input_mappings:
		# Limpiar entradas vacías
		var valid_inputs = []
		for input_action in inputs:
			var action_name = str(input_action).strip_edges()
			if action_name.length() > 0:
				# Si la acción no existe, crearla
				if not InputMap.has_action(action_name):
					InputMap.add_action(action_name)
					custom_actions_created[action_name] = true
					print("[FGGlobal] Acción personalizada creada: ", action_name)
				valid_inputs.append(action_name)
		
		# Siempre actualizar el mapeo (incluso si está vacío)
		custom_input_mappings[action] = valid_inputs
		
		print("[FGGlobal] Mapeo actualizado para '", action, "': ", valid_inputs)

func debug_input_system():
	pass


func get_custom_input_mapping(action: String) -> Array:
	"""Obtiene el mapeo personalizado para una acción"""
	return custom_input_mappings.get(action, [])




# Función mejorada para obtener mapeos efectivos que siempre devuelve un mapeo válido
func get_effective_input_mapping(action: String) -> Array:
	# Primero intentar obtener el mapeo personalizado
	var custom_mapping = get_custom_input_mapping(action)
	
	# Si el mapeo personalizado está vacío o no existe, usar el por defecto
	if custom_mapping.is_empty():
		return _get_default_mapping(action)
	
	return custom_mapping

func _get_default_mapping(action: String) -> Array:
	var defaults = {
		"up": ["ui_up"],
		"down": ["ui_down"], 
		"left": ["ui_left"],
		"right": ["ui_right"],
		"accept": ["ui_accept"],
		"back": ["ui_cancel"]
	}
	
	return defaults.get(action, [])

# Función mejorada para verificar acciones que maneja correctamente los mapeos por defecto
func is_custom_action_just_pressed(action: String) -> bool:
	if not input_control_enabled:
		return false
		
	var mappings = get_effective_input_mapping(action)  # Usar la nueva función
	
	for mapping in mappings:
		if InputMap.has_action(mapping) and Input.is_action_just_pressed(mapping):
			return true
	
	return false

func is_custom_action_pressed(action: String) -> bool:
	if not input_control_enabled:
		return false
		
	var mappings = get_effective_input_mapping(action)  # Usar la nueva función
	
	for mapping in mappings:
		if InputMap.has_action(mapping) and Input.is_action_pressed(mapping):
			return true
	
	return false


func save_input_control_settings():
	"""Guarda la configuración del sistema de control de entrada"""
	var config_file = ConfigFile.new()
	
	# Cargar configuración existente si existe
	config_file.load("user://fennec_input_control.cfg")
	
	# Guardar configuración del sistema de entrada
	config_file.set_value("input_control", "enabled", input_control_enabled)
	config_file.set_value("input_control", "mappings", custom_input_mappings)
	config_file.set_value("input_control", "group_name", interactable_group_name)
	
	# Guardar archivo
	config_file.save("user://fennec_input_control.cfg")

func debug_input_mappings():
	"""Función de debug para verificar mapeos actuales"""
	print("[FGGlobal] === DEBUG MAPEOS ACTUALES ===")
	print("Sistema habilitado: ", input_control_enabled)
	print("Grupo interactuable: ", interactable_group_name)
	for action in custom_input_mappings:
		print("Acción '", action, "': ", custom_input_mappings[action])
		var defaults = _get_default_mapping(action)
		var current_mapping = get_custom_input_mapping(action)
		var effective_mapping = current_mapping if current_mapping.size() > 0 else defaults
		print("  -> Mapeo efectivo: ", effective_mapping)
	print("=================================")

func load_input_control_settings():
	"""Carga la configuración del sistema de control de entrada"""
	var config_file = ConfigFile.new()
	
	if config_file.load("user://fennec_input_control.cfg") == OK:
		input_control_enabled = config_file.get_value("input_control", "enabled", false)
		var loaded_mappings = config_file.get_value("input_control", "mappings", {})
		interactable_group_name = config_file.get_value("input_control", "group_name", "interactuable")
		
		# Aplicar solo los mapeos que están definidos (no vacíos)
		for action in loaded_mappings:
			if loaded_mappings[action].size() > 0:
				custom_input_mappings[action] = loaded_mappings[action]
			# Si está vacío o no existe, mantener los valores por defecto

func set_interactable_group_name(group_name: String):
	"""Establece el nombre del grupo de nodos interactuables"""
	if group_name.strip_edges().is_empty():
		group_name = "interactuable"  # valor por defecto
	
	interactable_group_name = group_name.strip_edges()
	save_input_control_settings()
	
	# Refrescar el sistema de navegación si existe
	if navigation_system and navigation_system.has_method("refresh_interactables"):
		navigation_system.refresh_interactables()
	
	print("[FGGlobal] Grupo de nodos interactuables cambiado a: ", interactable_group_name)

func get_interactable_group_name() -> String:
	"""Obtiene el nombre del grupo de nodos interactuables"""
	return interactable_group_name

func _on_navigation_selection_changed(node: Control):
	"""Callback cuando cambia la selección en el sistema de navegación"""
	print("[FGGlobal] Selección cambiada a: ", node.name if node else "null")

func refresh_navigation_system():
	"""Refresca el sistema de navegación"""
	if navigation_system and navigation_system.has_method("refresh_interactables"):
		navigation_system.refresh_interactables()

func select_navigation_node(node: Control):
	"""Selecciona un nodo específico en el sistema de navegación"""
	if navigation_system and navigation_system.has_method("select_specific_node"):
		navigation_system.select_specific_node(node)

# Función para guardar mapeos en JSON
func save_custom_input_mappings():
	"""Guarda los mapeos de entrada personalizados en JSON"""
	ensure_directories()
	
	var data = {
		"version": "1.0",
		"enabled": input_control_enabled,
		"group_name": interactable_group_name,
		"custom_mappings": custom_input_mappings,
		"created_actions": custom_actions_created
	}
	
	var json_string = JSON.stringify(data)
	var file = FileAccess.open(custom_input_json_path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("[FGGlobal] Mapeos personalizados guardados en: ", custom_input_json_path)
		print("[FGGlobal] Mapeos guardados: ", custom_input_mappings)
		return true
	else:
		print("[FGGlobal] Error guardando mapeos personalizados")
		return false

# Función para cargar mapeos desde JSON
func load_custom_input_mappings():
	"""Carga los mapeos de entrada personalizados desde JSON"""
	if not FileAccess.file_exists(custom_input_json_path):
		print("[FGGlobal] Archivo de mapeos personalizados no existe, usando valores por defecto")
		return false
	
	var file = FileAccess.open(custom_input_json_path, FileAccess.READ)
	if not file:
		print("[FGGlobal] Error abriendo archivo de mapeos personalizados")
		return false
	
	var json_data = file.get_as_text()
	file.close()
	
	var result = JSON.parse_string(json_data)
	if result == null:
		print("[FGGlobal] Error parseando JSON de mapeos personalizados")
		return false
	
	# Cargar datos
	input_control_enabled = result.get("enabled", false)
	interactable_group_name = result.get("group_name", "interactuable")
	var loaded_mappings = result.get("custom_mappings", {})
	custom_actions_created = result.get("created_actions", {})
	
	# Aplicar mapeos cargados
	for action in loaded_mappings:
		custom_input_mappings[action] = loaded_mappings[action]
	
	print("[FGGlobal] Mapeos personalizados cargados:")
	print("  - Habilitado: ", input_control_enabled)
	print("  - Grupo: ", interactable_group_name)  
	print("  - Mapeos: ", custom_input_mappings)
	
	# Aplicar mapeos al InputMap inmediatamente
	apply_custom_input_mappings()
	
	return true

func apply_custom_input_mappings():
	if not input_control_enabled:
		return
	
	print("[FGGlobal] Aplicando mapeos personalizados...")
	
	for action in ["up", "down", "left", "right", "accept", "back"]:
		var mappings = get_effective_input_mapping(action)  # Usar la nueva función
		print("Acción '", action, "' mapeada a: ", mappings)
		
		# Verificar que todas las acciones existan en InputMap
		for mapping in mappings:
			if not InputMap.has_action(mapping):
				print("ADVERTENCIA: Acción '", mapping, "' no existe en InputMap")
