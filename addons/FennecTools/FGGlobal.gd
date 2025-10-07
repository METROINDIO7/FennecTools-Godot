@tool
extends Node

# ============================================================================
# FENNEC TOOLS - SHARED GLOBAL AUTOLOAD
# Unified system for multiple development tools
# ============================================================================

# System configuration variables
var config = ConfigFile.new()
var config_path = "user://fennec_settings.cfg"

# ============================================================================
# CONDITIONAL SYSTEM - SIMPLIFIED WITH SLOTS
# ============================================================================
var plugin_conditionals_path: String = "res://addons/FennecTools/data/fennec_conditionals.json"
var condicionales: Array = []

var conditionals: Array:
	get: return condicionales
	set(value): condicionales = value

var current_save_slot: int = 1
var save_slots: Dictionary = {}  # slot_id -> conditionals_data

var _conditionals_initialized: bool = false

# ============================================================================
# TRANSLATION SYSTEM
# ============================================================================
var current_language = "EN"
var current_target_group: String = "translate"  # Added variable to store target group
var translations: Dictionary = {}
var translation_groups: Dictionary = {}

# ============================================================================
# DIALOGUE SYSTEM
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

# === DYNAMIC CHARACTER NAMES SYSTEM ===
# Global dictionary for custom names assigned by code
# Normal keys: to_lower() and strip_edges() of the character's logical key
var dynamic_character_names: Dictionary = {}

# ============================================================================
# CONFIGURATION SYSTEM (inherited from your original code)
# ============================================================================
var Audio_Master = 0.0
var Audio_Music = 0.0
var Audio_Sounds = 0.0
var FOV = 45
var Full_screen = false
var Shadows = true

# ============================================================================
# SIGNALS FOR COMMUNICATION BETWEEN MODULES
# ============================================================================
signal conditional_changed(id: int, new_value: Variant)
signal language_changed(new_language: String)
signal dialog_started(dialog_id: int)
signal dialog_finished()
signal conditionals_loaded()

var input_mappings: Dictionary = {}

# ============================================================================
# CUSTOMIZABLE INPUT CONTROL SYSTEM
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

var interactable_group_name: String = "interactable"

# Reference to the navigation system
var navigation_system: Node = null

# Signals for the input system
signal input_control_toggled(enabled: bool)
signal custom_input_detected(action: String)

var custom_actions_created: Dictionary = {}

# Additional variables in FGGlobal
var custom_input_json_path: String = "res://addons/FennecTools/data/fennec_custom_inputs.json"
var input_mappings_cache: Dictionary = {}

# ============================================================================
# CHARACTER ANIMATION SYSTEM FOR DIALOGUE
# ============================================================================

# Function to find the CharacterController node by animation group
func find_character_animation_node(character_group_name: String) -> Node:
	"""Finds the CharacterController node that belongs to the specified group"""
	if character_group_name.is_empty():
		print("[FGGlobal] Warning: character_group_name is empty")
		return null
	
	# Search all nodes in the specified group
	var nodes_in_group = get_tree().get_nodes_in_group(character_group_name)
	
	if nodes_in_group.is_empty():
		print("[FGGlobal] No nodes found in group: ", character_group_name)
		return null
	
	# Search for the first CharacterController in the group
	for node in nodes_in_group:
		if node is Node and node.has_method("set_expression"):
			# Verify that it has the character_group_name property
			if node.has_method("get_current_expression") or node.has_method("set_expression"):
				print("[FGGlobal] Found CharacterController in group ", character_group_name, ": ", node.name)
				return node
	
	# If a valid CharacterController is not found
	print("[FGGlobal] No valid CharacterController found in group: ", character_group_name)
	return null

# Function to animate a character by dialogue
# Improve animation functions with better error handling
func animate_character_for_dialogue(character_group_name: String, expression_id: int) -> bool:
	"""✅ CHANGE: Now uses numeric expression_id"""
	if character_group_name.is_empty():
		print("[FGGlobal] Error: character_group_name is empty")
		return false
	
	# expression_id = -1 means no expression
	if expression_id < 0:
		print("[FGGlobal] No expression to set (expression_id = -1)")
		return false
	
	var character_node = find_character_animation_node(character_group_name)
	if character_node:
		# Check if the expression index exists
		if character_node.has_method("has_expression_index") and character_node.has_expression_index(expression_id):
			character_node.set_expression_by_id(expression_id)
			print("[FGGlobal] Expression ID '", expression_id, "' applied to character group: ", character_group_name)
			return true
		else:
			print("[FGGlobal] Warning: Expression ID '", expression_id, "' not found in character")
			# Try with default expression
			if character_node.has_method("set_expression_by_id"):
				var default_index = character_node.default_expression_index
				if default_index >= 0:
					character_node.set_expression_by_id(default_index)
					print("[FGGlobal] Using default expression index: '", default_index, "'")
					return true
	else:
		print("[FGGlobal] Could not animate character: group not found - ", character_group_name)
		return false
	
	return false

# Improved function to start mouth animation
func start_character_talking(character_group_name: String) -> bool:
	"""Starts the mouth animation for the specified character"""
	var character_node = find_character_animation_node(character_group_name)
	if character_node:
		if character_node.has_method("start_talking"):
			character_node.start_talking()
			print("[FGGlobal] Starting mouth animation for: ", character_group_name)
			return true
		else:
			print("[FGGlobal] Warning: CharacterController has no start_talking method")
	return false
	

# Function to stop mouth animation
func stop_character_talking(character_group_name: String) -> bool:
	"""Stops the mouth animation for the specified character"""
	var character_node = find_character_animation_node(character_group_name)
	if character_node and character_node.has_method("stop_talking"):
		character_node.stop_talking()
		print("[FGGlobal] Stopping mouth animation for: ", character_group_name)
		return true
	return false

# Function to get the current expression of a character
func get_character_current_expression(character_group_name: String) -> String:
	"""Gets the current expression of the specified character"""
	var character_node = find_character_animation_node(character_group_name)
	if character_node and character_node.has_method("get_current_expression"):
		return character_node.get_current_expression()
	return ""

# Function to check if a character exists
func has_character_animation_node(character_group_name: String) -> bool:
	"""Checks if a CharacterController exists for the specified group"""
	return find_character_animation_node(character_group_name) != null

# ============================================================================
# IMPROVED _ready() FUNCTION
# ============================================================================
func _ready():
	
	# Create necessary directories
	ensure_directories()
	
	# Migrate legacy data if necessary
	migrate_legacy_data()
	
	
	await initialize_conditionals_safe()
	
	load_input_control_settings()
	
	initialize_translations()
	initialize_dialogs()
	
	setup_input_control_system()
	
	# Verify integrity
	verify_data_integrity()
	
	if current_save_slot != -1:
		sync_slot_with_original(current_save_slot)

# ============================================================================
# SIMPLIFIED CONDITIONAL SYSTEM WITH SLOTS
# ============================================================================
func initialize_conditionals_safe():
	"""Initializes conditionals using simplified slot system"""
	if _conditionals_initialized:
		print("[FGGlobal] Conditionals already initialized")
		return
	
	print("[FGGlobal] Initializing conditional system with slot ", current_save_slot, "...")
	
	if not load_save_slot(current_save_slot):
		print("[FGGlobal] Creating slot ", current_save_slot, " from base file...")
		if load_conditionals_from_plugin():
			duplicate_conditionals_for_save_slot(current_save_slot)
			load_save_slot(current_save_slot)
		else:
			# If there is no base file, create an empty structure
			print("[FGGlobal] Creating empty conditional structure")
			condicionales = []
			save_slot_conditionals(current_save_slot)
	
	_conditionals_initialized = true
	conditionals_loaded.emit()
	print("[FGGlobal] Conditionals initialized in slot ", current_save_slot, ": ", condicionales.size(), " elements")

func load_conditionals_from_plugin() -> bool:
	"""Loads conditionals from the plugin's base file"""
	if not FileAccess.file_exists(plugin_conditionals_path):
		print("[FGGlobal] Base file does not exist: ", plugin_conditionals_path)
		return false
	
	var file = FileAccess.open(plugin_conditionals_path, FileAccess.READ)
	if not file:
		print("[FGGlobal] Error opening base file: ", plugin_conditionals_path)
		return false
	
	var json_data = file.get_as_text()
	file.close()
	
	if json_data.is_empty():
		print("[FGGlobal] Base file is empty: ", plugin_conditionals_path)
		return false
	
	var result = JSON.parse_string(json_data)
	if result == null:
		print("[FGGlobal] Error parsing base JSON: ", plugin_conditionals_path)
		return false
	
	if not result.has("conditionals"):
		print("[FGGlobal] Base JSON without 'conditionals' structure: ", plugin_conditionals_path)
		return false
	
	condicionales = result.conditionals
	print("[FGGlobal] Loaded ", condicionales.size(), " conditionals from base file")
	return true

func save_slot_conditionals(slot_id: int):
	"""Saves conditionals of the specific slot only in user://"""
	var slot_path = "user://fennec_conditionals_slot_" + str(slot_id) + ".json"
	var data = {"conditionals": condicionales, "slot_id": slot_id}
	var json_string = JSON.stringify(data)
	
	var file = FileAccess.open(slot_path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("[FGGlobal] Conditionals saved in slot ", slot_id)
	else:
		print("[FGGlobal] Error saving slot ", slot_id)

func load_conditionals_from_file(file_path: String) -> bool:
	"""Loads conditionals from a specific file"""
	if not FileAccess.file_exists(file_path):
		print("[FGGlobal] File does not exist: ", file_path)
		return false
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("[FGGlobal] Error opening file: ", file_path)
		return false
	
	var json_data = file.get_as_text()
	file.close()
	
	if json_data.is_empty():
		print("[FGGlobal] File is empty: ", file_path)
		return false
	
	var result = JSON.parse_string(json_data)
	if result == null:
		print("[FGGlobal] Error parsing JSON: ", file_path)
		return false
	
	if not result.has("conditionals"):
		print("[FGGlobal] JSON without 'conditionals' structure: ", file_path)
		return false
	
	condicionales = result.conditionals
	print("[FGGlobal] Loaded ", condicionales.size(), " conditionals from: ", file_path)
	return true

func duplicate_conditionals_json() -> bool:
	"""Duplicates the original file to the working location"""
	var conditionals_path = "res://data/Progress.json"
	if not FileAccess.file_exists(conditionals_path):
		print("[FGGlobal] Original file does not exist: ", conditionals_path)
		return false
	
	var file = FileAccess.open(conditionals_path, FileAccess.READ)
	if not file:
		print("[FGGlobal] Error opening original file")
		return false
	
	var json_data = file.get_as_text()
	file.close()
	
	var file_copy = FileAccess.open("user://fennec_conditionals.json", FileAccess.WRITE)
	if not file_copy:
		print("[FGGlobal] Error creating copy")
		return false
	
	file_copy.store_string(json_data)
	file_copy.close()
	print("[FGGlobal] Copy created at: user://fennec_conditionals.json")
	return true

func check_condition(id_condition: int) -> Variant:
	"""Checks a condition by ID with improved error handling"""
	if not _conditionals_initialized:
		print("[FGGlobal] Warning: Conditionals not initialized")
		return null
	
	for conditional in condicionales:
		if conditional.has("id") and conditional.id == id_condition:
			match conditional.get("type", ""):
				"boolean":
					return conditional.get("value_bool", false)
				"numeric":
					return conditional.get("value_float", 0.0) 
				"texts":
					return conditional.get("text_values", [])
				_:
					print("[FGGlobal] Unknown conditional type: ", conditional.get("type", ""))
					return null
	
	print("[FGGlobal] Condition with ID ", id_condition, " not found.")
	return null

# Function to check if user text matches any of the values
func check_text_condition(id_condition: int, input_text: String) -> bool:
	"""Checks if a text matches any of the values of a text conditional"""
	if not _conditionals_initialized:
		print("[FGGlobal] Warning: Conditionals not initialized")
		return false
	
	for conditional in condicionales:
		if conditional.has("id") and conditional.id == id_condition:
			match conditional.get("type", ""):
				"texts":
					var values = conditional.get("text_values", [])
					var input_lower = input_text.to_lower().strip_edges()
					for value in values:
						if input_lower == value.to_lower().strip_edges():
							return true
					return false
				_:
					print("[FGGlobal] Conditional ", id_condition, " is not of type text")
					return false
	
	print("[FGGlobal] Condition with ID ", id_condition, " not found.")
	return false

# Function to get a specific text by index
func get_text_value(id_condition: int, index: int = 0) -> String:
	"""Gets a specific text from a text conditional by index"""
	if not _conditionals_initialized:
		print("[FGGlobal] Warning: Conditionals not initialized")
		return ""
	
	for conditional in condicionales:
		if conditional.has("id") and conditional.id == id_condition:
			match conditional.get("type", ""):
				"texts":
					var values = conditional.get("text_values", [])
					if index >= 0 and index < values.size():
						return values[index]
					else:
						print("[FGGlobal] Index out of range for conditional ", id_condition)
						return ""
				_:
					print("[FGGlobal] Conditional ", id_condition, " is not of type text")
					return ""
	
	print("[FGGlobal] Condition with ID ", id_condition, " not found.")
	return ""

# Function to get a random text from the list
func get_random_text_value(id_condition: int) -> String:
	"""Gets a random text from a text conditional"""
	if not _conditionals_initialized:
		print("[FGGlobal] Warning: Conditionals not initialized")
		return ""
	
	for conditional in condicionales:
		if conditional.has("id") and conditional.id == id_condition:
			match conditional.get("type", ""):
				"texts":
					var values = conditional.get("text_values", [])
					if values.size() > 0:
						return values[randi() % values.size()]
					else:
						print("[FGGlobal] No text values in conditional ", id_condition)
						return ""
				_:
					print("[FGGlobal] Conditional ", id_condition, " is not of type text")
					return ""
	
	print("[FGGlobal] Condition with ID ", id_condition, " not found.")
	return ""

# Function to get the entire list of texts
func get_all_text_values(id_condition: int) -> Array:
	"""Gets all text values of a conditional"""
	if not _conditionals_initialized:
		print("[FGGlobal] Warning: Conditionals not initialized")
		return []
	
	for conditional in condicionales:
		if conditional.has("id") and conditional.id == id_condition:
			match conditional.get("type", ""):
				"texts":
					return conditional.get("text_values", [])
				_:
					print("[FGGlobal] Conditional ", id_condition, " is not of type text")
					return []
	
	print("[FGGlobal] Condition with ID ", id_condition, " not found.")
	return []

# Function to add a text to the list
func add_text_value(id_condition: int, new_text: String) -> bool:
	"""Adds a new text to a text conditional"""
	if not _conditionals_initialized:
		print("[FGGlobal] Error: Conditionals not initialized")
		return false
	
	for conditional in condicionales:
		if conditional.has("id") and conditional.id == id_condition:
			match conditional.get("type", ""):
				"texts":
					if not conditional.has("text_values"):
						conditional.text_values = []
					
					var text_clean = new_text.strip_edges()
					if text_clean != "" and text_clean not in conditional.text_values:
						conditional.text_values.append(text_clean)
						save_slot_conditionals(current_save_slot)
						conditional_changed.emit(id_condition, conditional.text_values)
						print("[FGGlobal] Text added to conditional ", id_condition, ": ", text_clean)
						return true
					else:
						print("[FGGlobal] Empty or already existing text in conditional ", id_condition)
						return false
				_:
					print("[FGGlobal] Conditional ", id_condition, " is not of type text")
					return false
	
	print("[FGGlobal] Condition with ID ", id_condition, " not found.")
	return false

# Function to remove a specific text
func remove_text_value(id_condition: int, text_to_remove: String) -> bool:
	"""Removes a specific text from a text conditional"""
	if not _conditionals_initialized:
		print("[FGGlobal] Error: Conditionals not initialized")
		return false
	
	for conditional in condicionales:
		if conditional.has("id") and conditional.id == id_condition:
			match conditional.get("type", ""):
				"texts":
					if conditional.has("text_values"):
						var removed = conditional.text_values.erase(text_to_remove)
						if removed:
							save_slot_conditionals(current_save_slot)
							conditional_changed.emit(id_condition, conditional.text_values)
							print("[FGGlobal] Text removed from conditional ", id_condition, ": ", text_to_remove)
							return true
						else:
							print("[FGGlobal] Text not found in conditional ", id_condition)
							return false
					else:
						print("[FGGlobal] No text values in conditional ", id_condition)
						return false
				_:
					print("[FGGlobal] Conditional ", id_condition, " is not of type text")
					return false
	
	print("[FGGlobal] Condition with ID ", id_condition, " not found.")
	return false

# Function to get the number of texts in a conditional
func get_text_count(id_condition: int) -> int:
	"""Gets the number of texts in a text conditional"""
	if not _conditionals_initialized:
		print("[FGGlobal] Warning: Conditionals not initialized")
		return 0
	
	for conditional in condicionales:
		if conditional.has("id") and conditional.id == id_condition:
			match conditional.get("type", ""):
				"texts":
					return conditional.get("text_values", []).size()
				_:
					print("[FGGlobal] Conditional ", id_condition, " is not of type text")
					return 0
	
	print("[FGGlobal] Condition with ID ", id_condition, " not found.")
	return 0

func modify_condition(id_condition: int, new_value: Variant, operation: String = "replace"):
	"""Modifies a condition - only affects the user's current slot"""
	if not _conditionals_initialized:
		print("[FGGlobal] Error: Conditionals not initialized")
		return
	
	for conditional in condicionales:
		if conditional.has("id") and conditional.id == id_condition:
			var type = conditional.get("type", "")
			
			match type:
				"boolean":
					if typeof(new_value) == TYPE_BOOL:
						conditional.value_bool = new_value
						save_slot_conditionals(current_save_slot)
						conditional_changed.emit(id_condition, new_value)
						print("[FGGlobal] Boolean conditional updated: ID ", id_condition, " = ", new_value)
						return
					else:
						print("[FGGlobal] Error: Non-boolean value for boolean conditional")
				
				"numeric":
					if typeof(new_value) in [TYPE_FLOAT, TYPE_INT]:
						var float_value = float(new_value)
						match operation:
							"add":
								conditional.value_float += float_value
							"subtract":
								conditional.value_float -= float_value
							_: # "replace"
								conditional.value_float = float_value
						
						save_slot_conditionals(current_save_slot)
						conditional_changed.emit(id_condition, conditional.value_float)
						print("[FGGlobal] Numeric conditional updated: ID ", id_condition, " = ", conditional.value_float)
						return
					else:
						print("[FGGlobal] Error: Non-numeric value for numeric conditional")
				
				"texts":
					if typeof(new_value) == TYPE_ARRAY:
						conditional.text_values = new_value
						save_slot_conditionals(current_save_slot)
						conditional_changed.emit(id_condition, new_value)
						print("[FGGlobal] Multiple text conditional updated: ID ", id_condition, " = ", new_value)
						return
					elif typeof(new_value) == TYPE_STRING:
						# If a string is passed, add it to the list
						if not conditional.has("text_values"):
							conditional.text_values = []
						match operation:
							"add":
								if new_value not in conditional.text_values:
									conditional.text_values.append(new_value)
							"remove":
								conditional.text_values.erase(new_value)
							_: # "replace"
								conditional.text_values = [new_value]
						save_slot_conditionals(current_save_slot)
						conditional_changed.emit(id_condition, conditional.text_values)
						print("[FGGlobal] Multiple text conditional updated: ID ", id_condition, " = ", conditional.text_values)
						return
					else:
						print("[FGGlobal] Error: Invalid value for multiple text conditional")
				
				_:
					print("[FGGlobal] Error: Unknown conditional type: ", type)
			return
	
	print("[FGGlobal] Condition with ID ", id_condition, " not found.")

func duplicate_conditionals_for_save_slot(slot_id: int) -> bool:
	"""Duplicates the current conditionals for a specific game save"""
	if not _conditionals_initialized:
		print("[FGGlobal] Error: Conditionals not initialized")
		return false
	
	# Create a deep copy of the current conditionals
	var duplicated_conditionals = []
	for conditional in condicionales:
		var duplicated = {}
		for key in conditional:
			duplicated[key] = conditional[key]
		
		duplicated.slot_id = slot_id
		duplicated.original_id = duplicated.get("id", 0)
		
		duplicated_conditionals.append(duplicated)
	
	# Save to the slots dictionary
	save_slots[slot_id] = duplicated_conditionals
	
	# Save to the slot's specific file
	var slot_path = "user://fennec_conditionals_slot_" + str(slot_id) + ".json"
	var data = {"conditionals": duplicated_conditionals, "slot_id": slot_id}
	var json_string = JSON.stringify(data)
	
	var file = FileAccess.open(slot_path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("[FGGlobal] Conditionals duplicated for slot ", slot_id, ": ", duplicated_conditionals.size(), " elements")
		return true
	else:
		print("[FGGlobal] Error saving slot ", slot_id)
		return false

func load_save_slot(slot_id: int) -> bool:
	"""Loads the conditionals of a specific game save"""
	var slot_path = "user://fennec_conditionals_slot_" + str(slot_id) + ".json"
	
	if not FileAccess.file_exists(slot_path):
		print("[FGGlobal] Slot ", slot_id, " does not exist")
		return false
	
	var file = FileAccess.open(slot_path, FileAccess.READ)
	if not file:
		print("[FGGlobal] Error opening slot ", slot_id)
		return false
	
	var json_data = file.get_as_text()
	file.close()
	
	var result = JSON.parse_string(json_data)
	if result == null or not result.has("conditionals"):
		print("[FGGlobal] Error parsing slot ", slot_id)
		return false
	
	condicionales = result.conditionals
	current_save_slot = slot_id
	save_slots[slot_id] = condicionales
	
	print("[FGGlobal] Slot ", slot_id, " loaded: ", condicionales.size(), " conditionals")
	conditionals_loaded.emit()
	return true

func get_available_save_slots() -> Array:
	"""Gets the list of available save slots"""
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
	"""Deletes a save slot"""
	var slot_path = "user://fennec_conditionals_slot_" + str(slot_id) + ".json"
	
	if FileAccess.file_exists(slot_path):
		DirAccess.remove_absolute(slot_path)
		save_slots.erase(slot_id)
		print("[FGGlobal] Slot ", slot_id, " deleted")
		return true
	
	return false

func get_conditional_groups() -> Array:
	"""Gets the list of unique conditional groups"""
	var groups = []
	
	if not _conditionals_initialized:
		return groups
	
	for conditional in condicionales:
		var group = conditional.get("group", "default")
		if group not in groups:
			groups.append(group)
	
	groups.sort()
	return groups

# ============================================================================
# DIRECTORY AND FILE MANAGEMENT
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
# DATA INTEGRITY VERIFICATION
# ============================================================================
func verify_data_integrity():
	"""Verifies that the JSON data is in the correct format"""
	var issues = []
	
	# Verify conditionals
	for i in range(condicionales.size()):
		var conditional = condicionales[i]
		if not conditional.has("id") or not conditional.has("name") or not conditional.has("type"):
			issues.append("Conditional at index " + str(i) + " has incomplete structure")
	
	# Verify translations
	for lang in translations:
		if not typeof(translations[lang]) == TYPE_DICTIONARY:
			issues.append("Translations for language '" + lang + "' is not a dictionary")
	
	if issues.size() > 0:
		print("[FGGlobal] Integrity issues found:")
		for issue in issues:
			print("  - " + issue)
	else:
		print("[FGGlobal] Data integrity verified successfully")
	
	return issues.size() == 0

# ============================================================================
# LEGACY DATA MIGRATION
# ============================================================================
func migrate_legacy_data():
	"""Migrates data from the old format to the new one if necessary"""
	var legacy_path = "res://data/Progress.json"
	
	# If the legacy file exists but not the new one, perform migration
	if FileAccess.file_exists(legacy_path) and not FileAccess.file_exists(plugin_conditionals_path):
		print("[FGGlobal] Migrating legacy data...")
		duplicate_conditionals_json()
		
		# Migrate dialogues as well
		var legacy_dialog_path = "res://data/Dialogues.json"
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
					print("[FGGlobal] Legacy dialogues migrated")

# ============================================================================
# TRANSLATION SYSTEM
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
				
				# Load the target group with multiple sources
				current_target_group = result.get("target_group", 
					result.get("selected_group", "translate"))
				
				print("[FGGlobal] Translations loaded. Target group: ", current_target_group)
			else:
				print("[FGGlobal] Error parsing translations file")
				# Use default values
				current_target_group = "translate"
		else:
			print("[FGGlobal] Error reading translations file")
			current_target_group = "translate"
	else:
		print("[FGGlobal] Translations file does not exist, using default values")
		current_target_group = "translate"

func save_translations():
	var translation_path = "res://addons/FennecTools/data/fennec_translations.json"
	ensure_plugin_data_directory()
	var file = FileAccess.open(translation_path, FileAccess.WRITE)
	if file:
		var data = {
			"translations": translations,
			"groups": translation_groups,
			"target_group": current_target_group,
			"selected_group": current_target_group  # For compatibility
		}
		file.store_string(JSON.stringify(data))
		file.close()
		print("[FGGlobal] Translations saved. Target group: ", current_target_group)
	else:
		print("[FGGlobal] Error saving translations")

func set_translation_target_group(group_name: String):
	"""Sets the target group for translations and saves it immediately"""
	if group_name.strip_edges().is_empty():
		group_name = "translate"  # Default value
	
	current_target_group = group_name
	save_translations()  # Save immediately
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
# DIALOGUE SYSTEM
# ============================================================================
func initialize_dialogs():
	load_dialog_data()
	load_dialog_config()

func load_dialog_data():
	var plugin_dialog_path = "res://addons/FennecTools/data/fennec_dialogues.json"
	var original_dialog_path = "res://data/Dialogues.json"
	
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

# Dialogue: load configuration (avoids error in initialize_dialogs)
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
		# Keep default values defined in dialog_config
		pass

# Dialogue system helpers
# Gets the text by exact id+character+language; returns "" if it doesn't exist
func get_dialog_text(id: int, character: String, language: String) -> String:
	var lang_u := str(language).to_upper()
	var char_s := str(character)
	for d in dialog_data:
		var e: Dictionary = d as Dictionary
		if int(e.get("id", -1)) == id and str(e.get("character", "")) == char_s and str(e.get("language", "")).to_upper() == lang_u:
			return str(e.get("text", ""))
	return ""

# Gets the first text that matches id and language, ignoring character
# If there is no match by language, it returns the first one that matches by id
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

# Returns the panel path associated with a character, or the default panel
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
		print("[FGGlobal] Dialogue already in progress, ignoring new request.")
		return
	
	if get_tree().has_group("Diag"):
		var dialog_node = get_tree().get_nodes_in_group("Diag")[0]
		talk = true
		current_character = character
		dialog_started.emit(dialog_id)
		dialog_node.start_dialog(dialog_id, dialog_count, show_question, question_path, character)
	else:
		print("[FGGlobal] Error: No node found in the 'Diag' group.")

# Function to synchronize a slot with the original JSON
func sync_slot_with_original(slot_id: int) -> bool:
	"""Synchronizes a specific slot with the original JSON, adding missing conditionals"""
	
	# Load original conditionals
	var original_conditionals = []
	if not load_original_conditionals_to_array(original_conditionals):
		print("[FGGlobal] Error: Could not load original JSON for synchronization")
		return false
	
	# Load current slot (if it exists)
	var slot_path = "user://fennec_conditionals_slot_" + str(slot_id) + ".json"
	var current_slot_conditionals = []
	
	if FileAccess.file_exists(slot_path):
		if not load_slot_conditionals_to_array(slot_id, current_slot_conditionals):
			print("[FGGlobal] Error loading slot ", slot_id, " for synchronization")
			return false
	else:
		print("[FGGlobal] Slot ", slot_id, " does not exist, it will be created with all original conditionals")
	
	# Create a dictionary of existing IDs in the slot for quick search
	var existing_ids = {}
	for conditional in current_slot_conditionals:
		if conditional.has("id"):
			existing_ids[conditional.id] = true
	
	# Add missing conditionals
	var added_count = 0
	for original_conditional in original_conditionals:
		if original_conditional.has("id"):
			var id = original_conditional.id
			if not existing_ids.has(id):
				# Create a copy of the original conditional with default values
				var new_conditional = original_conditional.duplicate(true)
				reset_conditional_to_default(new_conditional)
				current_slot_conditionals.append(new_conditional)
				added_count += 1
				print("[FGGlobal] Added missing conditional ID: ", id)
	
	# Update current conditionals and save
	condicionales = current_slot_conditionals
	current_save_slot = slot_id
	save_slot_conditionals(slot_id)
	
	print("[FGGlobal] Synchronization completed. Added ", added_count, " conditionals to slot ", slot_id)
	conditionals_loaded.emit()
	return true

# Helper function to load original conditionals into an array
func load_original_conditionals_to_array(target_array: Array) -> bool:
	"""Loads the conditionals from the original JSON into a specific array"""
	if not FileAccess.file_exists(plugin_conditionals_path):
		print("[FGGlobal] Original file does not exist: ", plugin_conditionals_path)
		return false
	
	var file = FileAccess.open(plugin_conditionals_path, FileAccess.READ)
	if not file:
		print("[FGGlobal] Error opening original file")
		return false
	
	var json_data = file.get_as_text()
	file.close()
	
	var result = JSON.parse_string(json_data)
	if result == null or not result.has("conditionals"):
		print("[FGGlobal] Error parsing original JSON")
		return false
	
	target_array.clear()
	target_array.append_array(result.conditionals)
	return true

# Helper function to load slot conditionals into an array
func load_slot_conditionals_to_array(slot_id: int, target_array: Array) -> bool:
	"""Loads the conditionals of a specific slot into an array"""
	var slot_path = "user://fennec_conditionals_slot_" + str(slot_id) + ".json"
	
	if not FileAccess.file_exists(slot_path):
		return false
	
	var file = FileAccess.open(slot_path, FileAccess.READ)
	if not file:
		return false
	
	var json_data = file.get_as_text()
	file.close()
	
	var result = JSON.parse_string(json_data)
	if result == null or not result.has("conditionals"):
		return false
	
	target_array.clear()
	target_array.append_array(result.conditionals)
	return true

# Function to reset a conditional to its default values
# Corrected function to reset a conditional to its default values
func reset_conditional_to_default(conditional: Dictionary):
	"""Resets a conditional to its default values according to its type"""
	var type = conditional.get("type", "")
	
	match type:
		"boolean":
			conditional.value_bool = conditional.get("default_value", false)
		"numeric":
			conditional.value_float = conditional.get("default_value", 0.0)
		"texts":
			# <CHANGE> Ensure that text_values is copied correctly from the original
			var original_values = conditional.get("default_values", [])
			if original_values.is_empty():
				# If there are no default_values, use text_values from the original
				original_values = conditional.get("text_values", [])
			
			# Create a deep copy of the array
			conditional.text_values = []
			for value in original_values:
				conditional.text_values.append(str(value))


# Function to synchronize all existing slots
func sync_all_slots_with_original():
	"""Synchronizes all existing slots with the original JSON"""
	var available_slots = get_available_save_slots()
	var synced_count = 0
	
	for slot_id in available_slots:
		if sync_slot_with_original(slot_id):
			synced_count += 1
	
	print("[FGGlobal] Synchronized ", synced_count, " slots out of ", available_slots.size(), " available")


func load_save_slot_with_sync(slot_id: int) -> bool:
	if slot_needs_sync(slot_id):
		print("[FGGlobal] Slot ", slot_id, " needs synchronization")
		sync_slot_with_original(slot_id)
	else:
		load_save_slot(slot_id)
	return true

# Function to check if a slot needs synchronization
func slot_needs_sync(slot_id: int) -> bool:
	"""Checks if a slot needs synchronization with the original JSON"""
	var original_conditionals = []
	var slot_conditionals = []
	
	if not load_original_conditionals_to_array(original_conditionals):
		return false
	
	if not load_slot_conditionals_to_array(slot_id, slot_conditionals):
		return true  # If it cannot be loaded, it probably needs synchronization
	
	# Create a set of slot IDs
	var slot_ids = {}
	for conditional in slot_conditionals:
		if conditional.has("id"):
			slot_ids[conditional.id] = true
	
	# Check for missing conditionals
	for original_conditional in original_conditionals:
		if original_conditional.has("id") and not slot_ids.has(original_conditional.id):
			return true
	
	return false



func change_save_slot(slot_id: String):
	"""Main method to switch between game saves - Usage: FGGlobal.change_save_slot('1')"""
	var numeric_slot = 1  # Default slot 1
	
	# Convert string to int if possible
	if slot_id.is_valid_int():
		numeric_slot = int(slot_id)
	else:
		# If it is not numeric, use a hash to generate a unique ID
		numeric_slot = abs(slot_id.hash()) % 1000
	
	print("[FGGlobal] Changing to save slot: ", slot_id, " (Numeric ID: ", numeric_slot, ")")
	
	# If the slot does not exist, create it by duplicating the base conditionals
	if not load_save_slot(numeric_slot):
		print("[FGGlobal] Creating new save slot: ", slot_id)
		if load_conditionals_from_plugin():
			duplicate_conditionals_for_save_slot(numeric_slot)
			load_save_slot(numeric_slot)
	
	current_save_slot = numeric_slot
	print("[FGGlobal] Active save slot: ", slot_id, " with ", condicionales.size(), " conditionals")

# ============================================================================
# GENERAL UTILITIES
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
	"""Compatibility function for conditional_editor.gd - saves to base file"""
	return save_conditionals_to_plugin()

func save_conditionals_to_plugin() -> bool:
	"""Saves conditionals to the plugin's original file - ONLY for editor use"""
	ensure_plugin_data_directory()
	
	var data = {"conditionals": condicionales}
	var json_string = JSON.stringify(data)
	
	var file = FileAccess.open(plugin_conditionals_path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("[FGGlobal] Conditionals saved to plugin base file")
		return true
	else:
		print("[FGGlobal] Error saving to plugin base file")
		return false

func get_translation(key: String, language: String = "") -> String:
	var lang = language if language != "" else current_language
	if translations.has(lang) and translations[lang].has(key):
		return translations[lang][key]
	return key # Returns the key if no translation is found

# ============================================================================
# Input control system functions
# ============================================================================

# Function for navigation update
func navigation_refresh():
	"""Forces the navigation system to update"""
	if navigation_system and navigation_system.has_method("refresh_interactables"):
		navigation_system.refresh_interactables()
		print("[FGGlobal] Navigation system manually updated")


func setup_input_control_system():
	"""Configures the customizable input control system"""
	# Load custom mappings from JSON first
	load_custom_input_mappings()
	
	# Create the navigation system if it doesn't exist
	if not navigation_system:
		var navigation_scene = preload("res://addons/FennecTools/data/input_navigation_system.gd")
		navigation_system = navigation_scene.new()
		navigation_system.name = "InputNavigationSystem"
		add_child(navigation_system)
		
		# Connect signals
		if navigation_system.has_signal("selection_changed"):
			navigation_system.selection_changed.connect(_on_navigation_selection_changed)


func _ensure_custom_input_actions():
	"""Creates custom actions in the InputMap if they don't exist"""
	for action in custom_input_mappings:
		var mappings = custom_input_mappings[action]
		for input_action in mappings:
			if not InputMap.has_action(input_action):
				# Create the action if it doesn't exist
				InputMap.add_action(input_action)
				print("[FGGlobal] Action created in InputMap: ", input_action)
				custom_actions_created[input_action] = true

func enable_input_control(enabled: bool):
	"""Activates or deactivates the input control system"""
	input_control_enabled = enabled
	
	if navigation_system:
		navigation_system.set_process(enabled)
		navigation_system.set_physics_process(enabled)
	
	# Apply custom mappings when enabled
	if enabled:
		apply_custom_input_mappings()
	
	# Save configuration to JSON
	save_custom_input_mappings()
	
	input_control_toggled.emit(enabled)
	print("[FGGlobal] Input control system: ", "ENABLED" if enabled else "DISABLED")

func set_custom_input_mapping(action: String, inputs: Array):
	"""Defines a custom mapping for an action"""
	if action in custom_input_mappings:
		# Clean empty inputs
		var valid_inputs = []
		for input_action in inputs:
			var action_name = str(input_action).strip_edges()
			if action_name.length() > 0:
				# If the action does not exist, create it
				if not InputMap.has_action(action_name):
					InputMap.add_action(action_name)
					custom_actions_created[action_name] = true
					print("[FGGlobal] Custom action created: ", action_name)
				valid_inputs.append(action_name)
		
		# Always update the mapping (even if it's empty)
		custom_input_mappings[action] = valid_inputs
		
		print("[FGGlobal] Mapping updated for '", action, "': ", valid_inputs)

func debug_input_system():
	pass


func get_custom_input_mapping(action: String) -> Array:
	"""Gets the custom mapping for an action"""
	return custom_input_mappings.get(action, [])




# Improved function to get effective mappings that always returns a valid mapping
func get_effective_input_mapping(action: String) -> Array:
	# First try to get the custom mapping
	var custom_mapping = get_custom_input_mapping(action)
	
	# If the custom mapping is empty or does not exist, use the default
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

# Improved function to check actions that correctly handles default mappings
func is_custom_action_just_pressed(action: String) -> bool:
	if not input_control_enabled:
		return false
		
	var mappings = get_effective_input_mapping(action)  # Use the new function
	
	for mapping in mappings:
		if InputMap.has_action(mapping) and Input.is_action_just_pressed(mapping):
			return true
	
	return false

func is_custom_action_pressed(action: String) -> bool:
	if not input_control_enabled:
		return false
		
	var mappings = get_effective_input_mapping(action)  # Use the new function
	
	for mapping in mappings:
		if InputMap.has_action(mapping) and Input.is_action_pressed(mapping):
			return true
	
	return false


func save_input_control_settings():
	"""Saves the input control system settings"""
	var config_file = ConfigFile.new()
	
	# Load existing configuration if it exists
	config_file.load("user://fennec_input_control.cfg")
	
	# Save input system settings
	config_file.set_value("input_control", "enabled", input_control_enabled)
	config_file.set_value("input_control", "mappings", custom_input_mappings)
	config_file.set_value("input_control", "group_name", interactable_group_name)
	
	# Save file
	config_file.save("user://fennec_input_control.cfg")

func debug_input_mappings():
	"""Debug function to check current mappings"""
	print("[FGGlobal] === DEBUG CURRENT MAPPINGS ===")
	print("System enabled: ", input_control_enabled)
	print("Interactable group: ", interactable_group_name)
	for action in custom_input_mappings:
		print("Action '", action, "': ", custom_input_mappings[action])
		var defaults = _get_default_mapping(action)
		var current_mapping = get_custom_input_mapping(action)
		var effective_mapping = current_mapping if current_mapping.size() > 0 else defaults
		print("  -> Effective mapping: ", effective_mapping)
	print("=================================")

func load_input_control_settings():
	"""Loads the input control system settings"""
	var config_file = ConfigFile.new()
	
	if config_file.load("user://fennec_input_control.cfg") == OK:
		input_control_enabled = config_file.get_value("input_control", "enabled", false)
		var loaded_mappings = config_file.get_value("input_control", "mappings", {})
		interactable_group_name = config_file.get_value("input_control", "group_name", "interactable")
		
		# Apply only defined (non-empty) mappings
		for action in loaded_mappings:
			if loaded_mappings[action].size() > 0:
				custom_input_mappings[action] = loaded_mappings[action]
			# If it is empty or does not exist, keep the default values

func set_interactable_group_name(group_name: String):
	"""Sets the name of the interactable nodes group"""
	if group_name.strip_edges().is_empty():
		group_name = "interactable"  # default value
	
	interactable_group_name = group_name.strip_edges()
	save_input_control_settings()
	
	# Refresh the navigation system if it exists
	if navigation_system and navigation_system.has_method("refresh_interactables"):
		navigation_system.refresh_interactables()
	
	print("[FGGlobal] Interactable nodes group changed to: ", interactable_group_name)

func get_interactable_group_name() -> String:
	"""Gets the name of the interactable nodes group"""
	return interactable_group_name

func _on_navigation_selection_changed(node: Control):
	"""Callback when the selection in the navigation system changes"""
	print("[FGGlobal] Selection changed to: ", node.name if node else "null")

func refresh_navigation_system():
	"""Refreshes the navigation system"""
	if navigation_system and navigation_system.has_method("refresh_interactables"):
		navigation_system.refresh_interactables()

func select_navigation_node(node: Control):
	"""Selects a specific node in the navigation system"""
	if navigation_system and navigation_system.has_method("select_specific_node"):
		navigation_system.select_specific_node(node)

# Function to save mappings to JSON
func save_custom_input_mappings():
	"""Saves custom input mappings to JSON"""
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
		print("[FGGlobal] Custom mappings saved to: ", custom_input_json_path)
		print("[FGGlobal] Mappings saved: ", custom_input_mappings)
		return true
	else:
		print("[FGGlobal] Error saving custom mappings")
		return false

# Function to load mappings from JSON
func load_custom_input_mappings():
	"""Loads custom input mappings from JSON"""
	if not FileAccess.file_exists(custom_input_json_path):
		print("[FGGlobal] Custom mappings file does not exist, using default values")
		return false
	
	var file = FileAccess.open(custom_input_json_path, FileAccess.READ)
	if not file:
		print("[FGGlobal] Error opening custom mappings file")
		return false
	
	var json_data = file.get_as_text()
	file.close()
	
	var result = JSON.parse_string(json_data)
	if result == null:
		print("[FGGlobal] Error parsing custom mappings JSON")
		return false
	
	# Load data
	input_control_enabled = result.get("enabled", false)
	interactable_group_name = result.get("group_name", "interactable")
	var loaded_mappings = result.get("custom_mappings", {})
	custom_actions_created = result.get("created_actions", {})
	
	# Apply loaded mappings
	for action in loaded_mappings:
		custom_input_mappings[action] = loaded_mappings[action]
	
	print("[FGGlobal] Custom mappings loaded:")
	print("  - Enabled: ", input_control_enabled)
	print("  - Group: ", interactable_group_name)  
	print("  - Mappings: ", custom_input_mappings)
	
	# Apply mappings to InputMap immediately
	apply_custom_input_mappings()
	
	return true

func apply_custom_input_mappings():
	if not input_control_enabled:
		return
	
	print("[FGGlobal] Applying custom mappings...")
	
	for action in ["up", "down", "left", "right", "accept", "back"]:
		var mappings = get_effective_input_mapping(action)  # Use the new function
		print("Action '", action, "' mapped to: ", mappings)
		
		# Check that all actions exist in InputMap
		for mapping in mappings:
			if not InputMap.has_action(mapping):
				print("WARNING: Action '", mapping, "' does not exist in InputMap")
