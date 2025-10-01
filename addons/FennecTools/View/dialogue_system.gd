@tool
extends Control

# === REFERENCIAS UI DESDE TSCN ===

# === REFERENCIAS UI - FILTROS ===
@onready var character_option: OptionButton = $MainVBox/FiltersPanel/FiltersVBox/CharacterAndLanguageRow/CharacterOption
@onready var group_filter_input: LineEdit = $MainVBox/FiltersPanel/FiltersVBox/CharacterAndLanguageRow/GroupFilterInput
@onready var clear_group_filter_btn: Button = $MainVBox/FiltersPanel/FiltersVBox/CharacterAndLanguageRow/ClearGroupFilterButton
@onready var add_character_input: LineEdit = $MainVBox/FiltersPanel/FiltersVBox/AddCharacterRow/AddCharacterInput
@onready var add_character_button: Button = $MainVBox/FiltersPanel/FiltersVBox/AddCharacterRow/AddCharacterButton

# === REFERENCIAS UI - PANEL DE IDIOMAS ===
@onready var language_toggle_button: Button = $"MainVBox/FiltersPanel/FiltersVBox/AddCharacterRow/LanguageCheckboxToggleButton"
@onready var checkbox_panel: PanelContainer = $"LanguageCheckboxPanel"
@onready var checkbox_grid: GridContainer = $"LanguageCheckboxPanel/LanguageCheckboxGrid"

# === REFERENCIAS UI - TABLA ===
@onready var dialogue_table: Tree = $MainVBox/DialogueTableScroll/DialogueTable

# === REFERENCIAS UI - EDICIÓN ===
@onready var character_name_input: OptionButton = $MainVBox/EditPanel/EditVBox/BasicEditRow/CharacterNameInput
@onready var add_button: Button = $MainVBox/EditPanel/EditVBox/BasicEditRow/AddButton
@onready var delete_button: Button = $MainVBox/EditPanel/EditVBox/BasicEditRow/DeleteButton
@onready var move_up_button: Button = $MainVBox/EditPanel/EditVBox/BasicEditRow/MoveUpButton
@onready var move_down_button: Button = $MainVBox/EditPanel/EditVBox/BasicEditRow/MoveDownButton
@onready var mood_option: OptionButton = $MainVBox/EditPanel/EditVBox/MoodGroupRow/MoodOption
@onready var apply_mood_button: Button = $MainVBox/EditPanel/EditVBox/MoodGroupRow/ApplyMoodButton
@onready var group_input: LineEdit = $MainVBox/EditPanel/EditVBox/MoodGroupRow/GroupInput
@onready var apply_group_button: Button = $MainVBox/EditPanel/EditVBox/MoodGroupRow/ApplyGroupButton

# === REFERENCIAS UI - OVERLAY CONFIG ===
@onready var toggle_config_button: Button = $MainVBox/EditPanel/EditVBox/BasicEditRow/ConfigButton
@onready var overlay_layer: Control = $OverlayConfig

@onready var overlay_close_button: Button = $OverlayConfig/CenterContainer/OverlayPanel/OverlayVBox/HeaderRow/CloseButton
@onready var default_panel_input: LineEdit = $OverlayConfig/CenterContainer/OverlayPanel/OverlayVBox/ConfigContainer/DefaultPanelRow/DefaultPanelInput
@onready var save_config_button: Button = $OverlayConfig/CenterContainer/OverlayPanel/OverlayVBox/ConfigContainer/DefaultPanelRow/SaveConfigButton
@onready var override_character_option: OptionButton = $OverlayConfig/CenterContainer/OverlayPanel/OverlayVBox/ConfigContainer/OverrideRow/OverrideCharacterOption
@onready var override_panel_input: LineEdit = $OverlayConfig/CenterContainer/OverlayPanel/OverlayVBox/ConfigContainer/OverrideRow/OverridePanelInput
@onready var override_default_name_input: LineEdit = $OverlayConfig/CenterContainer/OverlayPanel/OverlayVBox/ConfigContainer/OverrideRow/OverrideDefaultNameInput
@onready var save_override_btn: Button = $OverlayConfig/CenterContainer/OverlayPanel/OverlayVBox/ConfigContainer/OverrideRow/SaveOverrideButton
@onready var names_tree: Tree = $OverlayConfig/CenterContainer/OverlayPanel/OverlayVBox/ConfigContainer/NamesScrollContainer/NamesTree
@onready var character_list: ItemList = $OverlayConfig/CenterContainer/OverlayPanel/OverlayVBox/CharacterManagement/ManagementRow/CharacterList
@onready var rename_input: LineEdit = $OverlayConfig/CenterContainer/OverlayPanel/OverlayVBox/CharacterManagement/ManagementRow/ActionsVBox/RenameInput
@onready var rename_button: Button = $OverlayConfig/CenterContainer/OverlayPanel/OverlayVBox/CharacterManagement/ManagementRow/ActionsVBox/RenameButton
@onready var delete_character_button: Button = $OverlayConfig/CenterContainer/OverlayPanel/OverlayVBox/CharacterManagement/ManagementRow/ActionsVBox/DeleteCharacterButton

# === VARIABLES DE ESTADO ===
var available_characters: Array = []
var current_languages: Array = ["ES", "EN"]
var language_checkboxes: Dictionary = {}
var visible_language_columns: Array = []

# === VARIABLES DE CONFIGURACIÓN ===
var config_file_path := "res://addons/FennecTools/data/fennec_dialogue_config.json"
var config_data: Dictionary = {"default_panel_scene": "", "character_overrides": {}, "characters": []}

# Mood system
var mood_colors: Dictionary = {
	"neutral": Color.WHITE, "happy": Color.YELLOW, "sad": Color.CYAN,
	"angry": Color.LIGHT_CORAL, "excited": Color.ORANGE, "scared": Color.MEDIUM_PURPLE,
	"confused": Color.LIGHT_GRAY, "romantic": Color.PINK,
	"whisper": Color(0.8, 0.8, 1.0), "shout": Color(1.0, 0.3, 0.3),
	"sarcastic": Color(0.6, 1.0, 0.6), "formal": Color(0.9, 0.9, 0.9),
	"casual": Color(1.0, 0.9, 0.7), "mysterious": Color(0.4, 0.2, 0.6),
	"playful": Color(1.0, 0.8, 0.4), "serious": Color(0.5, 0.5, 0.7),
	"thoughtful": Color(0.7, 0.9, 0.8), "confident": Color(1.0, 0.7, 0.2),
	"nervous": Color(0.9, 0.7, 0.9), "tired": Color(0.7, 0.7, 0.7),
	"energetic": Color(0.9, 1.0, 0.3), "bored": Color(0.8, 0.8, 0.6),
	"curious": Color(0.4, 0.8, 1.0), "determined": Color(0.8, 0.4, 0.2),
	"friendly": Color(0.9, 1.0, 0.5), "hostile": Color(0.8, 0.2, 0.2),
	"protective": Color(0.3, 0.7, 0.3), "submissive": Color(0.8, 0.9, 1.0),
	"dominant": Color(0.7, 0.3, 0.7), "apologetic": Color(1.0, 0.9, 0.8),
	"grateful": Color(0.9, 0.8, 0.5), "explaining": Color(0.6, 0.8, 1.0),
	"questioning": Color(0.9, 0.6, 1.0), "storytelling": Color(0.8, 0.6, 0.4),
	"joking": Color(1.0, 0.9, 0.3), "complaining": Color(0.9, 0.5, 0.5),
	"praising": Color(0.5, 0.9, 0.7), "threatening": Color(0.6, 0.1, 0.1),
	"comforting": Color(0.8, 1.0, 0.9), "breathless": Color(0.9, 0.9, 1.0),
	"drunk": Color(0.9, 0.6, 0.9), "sick": Color(0.7, 0.9, 0.7),
	"cold": Color(0.8, 0.9, 1.0), "hot": Color(1.0, 0.8, 0.6)
}

var mood_names: Array = [
	"neutral", "happy", "sad", "angry", "excited", "scared", "confused", "romantic",
	"whisper", "shout", "sarcastic", "formal", "casual", "mysterious", "playful", "serious",
	"thoughtful", "confident", "nervous", "tired", "energetic", "bored", "curious", "determined",
	"friendly", "hostile", "protective", "submissive", "dominant", "apologetic", "grateful",
	"explaining", "questioning", "storytelling", "joking", "complaining", "praising", 
	"threatening", "comforting", "breathless", "drunk", "sick", "cold", "hot"
]

# === INICIALIZACIÓN ===
func _ready():
	# Verificar que los nodos críticos existen
	if not _verify_critical_nodes():
		push_error("Faltan nodos críticos en la escena")
		return
	
	_populate_mood_options()
	_connect_signals()
	_load_config_file()
	_refresh_languages_from_translations()
	_refresh_available_characters()
	_setup_dialogue_table()
	_setup_language_checkboxes()
	_setup_names_tree()
	_refresh_config_ui()
	refresh_display()

func _verify_critical_nodes() -> bool:
	var critical_nodes = [
		character_option, group_filter_input, clear_group_filter_btn,
		add_character_input, add_character_button, dialogue_table,
		character_name_input, add_button, delete_button, move_up_button,
		move_down_button, mood_option, apply_mood_button, group_input,
		apply_group_button, toggle_config_button, overlay_layer
	]
	
	for node in critical_nodes:
		if not node:
			push_error("Nodo crítico no encontrado: " + str(node))
			return false
	return true

func _populate_mood_options():
	if not mood_option:
		return
		
	mood_option.clear()
	for mood_name in mood_names:
		mood_option.add_item(mood_name)

func _setup_dialogue_table():
	if not dialogue_table:
		return
		
	dialogue_table.column_titles_visible = true
	dialogue_table.hide_root = true
	_configure_column_sizes()

func _setup_names_tree():
	if not names_tree:
		return
		
	names_tree.set_column_title(0, "Idioma")
	names_tree.set_column_title(1, "Nombre")
	names_tree.set_column_expand(0, false)
	names_tree.set_column_custom_minimum_width(0, 140)
	names_tree.set_column_expand(1, true)
	names_tree.set_column_custom_minimum_width(1, 450)

# === CONECTAR SEÑALES ===
func _connect_signals():
	# Verificar que los nodos existen antes de conectar
	if add_character_button:
		add_character_button.pressed.connect(_on_add_character_pressed)
	if character_option:
		character_option.item_selected.connect(_on_character_filter_selected)
	if group_filter_input:
		group_filter_input.text_changed.connect(_on_group_filter_changed)
	if clear_group_filter_btn:
		clear_group_filter_btn.pressed.connect(_on_clear_group_filter)
	if language_toggle_button:
		language_toggle_button.toggled.connect(_on_language_panel_toggled)
	if dialogue_table:
		dialogue_table.item_selected.connect(_on_dialogue_selected)
		dialogue_table.item_edited.connect(_on_cell_edited)
	if add_button:
		add_button.pressed.connect(_on_add_dialogue_pressed)
	if delete_button:
		delete_button.pressed.connect(_on_delete_dialogue_pressed)
	if move_up_button:
		move_up_button.pressed.connect(_on_move_up_pressed)
	if move_down_button:
		move_down_button.pressed.connect(_on_move_down_pressed)
	if apply_mood_button:
		apply_mood_button.pressed.connect(_on_apply_mood_pressed)
	if apply_group_button:
		apply_group_button.pressed.connect(_on_apply_group_pressed)
	if toggle_config_button:
		toggle_config_button.toggled.connect(_on_toggle_config_toggled)
	if overlay_close_button:
		overlay_close_button.pressed.connect(_on_close_overlay_pressed)
	if save_config_button:
		save_config_button.pressed.connect(_on_save_config_pressed)
	if save_override_btn:
		save_override_btn.pressed.connect(_on_save_override_pressed)
	if override_character_option:
		override_character_option.item_selected.connect(_on_override_character_selected)
	if names_tree:
		names_tree.item_edited.connect(_on_names_tree_edited)
	if character_list:
		character_list.item_selected.connect(_on_character_list_selected)
	if rename_button:
		rename_button.pressed.connect(_on_rename_character_pressed)
	if delete_character_button:
		delete_character_button.pressed.connect(_on_delete_character_pressed)

func _on_language_panel_toggled(pressed: bool):
	if checkbox_panel and language_toggle_button:
		checkbox_panel.visible = pressed
		language_toggle_button.text = ("▼ Columnas visibles" if pressed else "▶ Columnas visibles")

# === CONFIGURACIÓN DE COLUMNAS ===
func _configure_column_sizes():
	if not dialogue_table:
		return
		
	var total_columns = dialogue_table.get_columns()
	if total_columns >= 2:
		dialogue_table.set_column_expand(0, false)
		dialogue_table.set_column_custom_minimum_width(0, 50)
		dialogue_table.set_column_expand(1, false)
		dialogue_table.set_column_custom_minimum_width(1, 120)
		for i in range(2, total_columns):
			dialogue_table.set_column_expand(i, true)
			dialogue_table.set_column_custom_minimum_width(i, 200)

# === FILTROS DE IDIOMA ===
func _setup_language_checkboxes():
	if not checkbox_grid:
		return
		
	# Limpiar checkboxes existentes
	for child in checkbox_grid.get_children():
		child.queue_free()
	
	language_checkboxes.clear()
	visible_language_columns.clear()
	
	# Crear checkbox para cada idioma
	for lang in current_languages:
		var checkbox = CheckBox.new()
		checkbox.text = lang
		checkbox.button_pressed = true
		checkbox.toggled.connect(_on_language_checkbox_toggled.bind(lang))
		checkbox_grid.add_child(checkbox)
		language_checkboxes[lang] = checkbox
		visible_language_columns.append(lang)
	



func _on_language_checkbox_toggled(pressed: bool, lang: String):
	if pressed and lang not in visible_language_columns:
		visible_language_columns.append(lang)
	elif not pressed and lang in visible_language_columns:
		visible_language_columns.erase(lang)
	refresh_display()

func _on_group_filter_changed(new_text: String):
	refresh_display()

func _on_clear_group_filter():
	if group_filter_input:
		group_filter_input.text = ""
	refresh_display()

# === DISPLAY ===
func refresh_display():
	if not dialogue_table or not FGGlobal:
		return
		
	dialogue_table.clear()
	var root := dialogue_table.create_item()
	
	# Determinar idiomas a mostrar
	var display_languages: Array
	if visible_language_columns.size() > 0:
		display_languages = visible_language_columns.duplicate()
	elif current_languages.size() > 0:
		display_languages = current_languages.duplicate()
	else:
		display_languages = ["ES"] # Fallback
	
	# Agrupar diálogos
	var groups: Dictionary = {}
	for d in FGGlobal.dialog_data:
		var dialog_entry: Dictionary = d as Dictionary
		var id_val := int(dialog_entry.get("id", 0))
		var character := str(dialog_entry.get("character", ""))
		var lang := str(dialog_entry.get("language", "")).to_upper()
		var text := str(dialog_entry.get("text", ""))
		var mood := str(dialog_entry.get("mood", "neutral"))
		var group := str(dialog_entry.get("group", ""))
		var key := str(id_val) + "|" + character
		
		if not groups.has(key):
			groups[key] = {"id": id_val, "character": character, "texts": {}, "mood": mood, "group": group}
		var group_entry: Dictionary = groups[key] as Dictionary
		var texts_dict: Dictionary = group_entry["texts"] as Dictionary
		texts_dict[lang] = text
	
	# Aplicar filtros
	var filter_char := ""
	if character_option and character_option.item_count > 0:
		var ftxt := character_option.get_item_text(character_option.selected)
		if ftxt != "Todos":
			filter_char = ftxt
	
	var filter_group := ""
	if group_filter_input:
		filter_group = group_filter_input.text.strip_edges().to_lower()
	
	# Ordenar
	var keys := groups.keys()
	keys.sort_custom(func(a, b):
		var ea: Dictionary = groups[a]
		var eb: Dictionary = groups[b]
		var group_a := str(ea.get("group", ""))
		var group_b := str(eb.get("group", ""))
		var id_a := int(ea["id"])
		var id_b := int(eb["id"])
		
		if group_a != "" and group_b != "":
			if group_a != group_b:
				return group_a < group_b
			return id_a < id_b
		elif group_a != "" and group_b == "":
			return true
		elif group_a == "" and group_b != "":
			return false
		else:
			return id_a < id_b)
	
	# Configurar columnas
	var cols := 2 + display_languages.size()
	dialogue_table.set_columns(cols)
	dialogue_table.set_column_title(0, "ID")
	dialogue_table.set_column_title(1, "Personaje")
	for i in range(display_languages.size()):
		dialogue_table.set_column_title(2 + i, display_languages[i])
	
	_configure_column_sizes()
	
	# Mostrar datos
	var current_group := ""
	for key in keys:
		var entry: Dictionary = groups[key] as Dictionary
		
		if filter_char != "" and str(entry["character"]) != filter_char:
			continue
		
		var entry_group := str(entry.get("group", "")).to_lower()
		if filter_group != "" and filter_group not in entry_group:
			continue
		
		# MOSTRAR TODOS LOS DIÁLOGOS, INCLUYENDO LOS VACÍOS
		# Eliminamos la verificación de texto visible para que aparezcan los diálogos vacíos
		
		# Separador de grupo
		entry_group = str(entry.get("group", ""))
		if entry_group != "" and entry_group != current_group:
			var group_item := dialogue_table.create_item(root)
			group_item.set_text(0, "--- " + entry_group + " ---")
			group_item.set_custom_bg_color(0, Color(0.3, 0.3, 0.3, 0.5))
			group_item.set_custom_color(0, Color.WHITE)
			for i in range(1, dialogue_table.get_columns()):
				group_item.set_custom_bg_color(i, Color(0.3, 0.3, 0.3, 0.5))
				group_item.set_custom_color(i, Color.WHITE)
			group_item.set_selectable(0, false)
			current_group = entry_group
		
		var item := dialogue_table.create_item(root)
		item.set_text(0, str(entry["id"]))
		item.set_text(1, str(entry["character"]))
		
		# Aplicar color según mood
		var mood := str(entry.get("mood", "neutral"))
		if mood_colors.has(mood):
			var mood_color = mood_colors[mood]
			var text_color = _get_contrasting_text_color(mood_color)
			for i in range(dialogue_table.get_columns()):
				item.set_custom_bg_color(i, mood_color)
				item.set_custom_color(i, text_color)
		
		for i in range(display_languages.size()):
			var lang: String = display_languages[i]
			var value = entry["texts"].get(lang, "")
			item.set_text(2 + i, str(value))
			item.set_editable(2 + i, true)

func _get_contrasting_text_color(background_color: Color) -> Color:
	var luminance = 0.299 * background_color.r + 0.587 * background_color.g + 0.114 * background_color.b
	return Color.BLACK if luminance > 0.6 else Color.WHITE

# === EDICIÓN ===
func _on_dialogue_selected():
	if not dialogue_table:
		return
		
	var selected := dialogue_table.get_selected()
	if not selected:
		return
		
	var ch := selected.get_text(1)
	if character_name_input:
		for i in range(character_name_input.item_count):
			if character_name_input.get_item_text(i) == ch:
				character_name_input.selected = i
				break
	_update_mood_group_fields_from_selection()

func _update_mood_group_fields_from_selection():
	var selected = dialogue_table.get_selected()
	if not selected or not FGGlobal:
		return
	
	var id_val = int(selected.get_text(0))
	var character = selected.get_text(1)
	
	for dialog_entry in FGGlobal.dialog_data:
		var entry_dict = dialog_entry as Dictionary
		if int(entry_dict.get("id", -1)) == id_val and str(entry_dict.get("character", "")) == character:
			var mood_value = str(entry_dict.get("mood", "neutral"))
			if mood_option:
				for i in range(mood_names.size()):
					if mood_names[i] == mood_value:
						mood_option.selected = i
						break
			if group_input:
				group_input.text = str(entry_dict.get("group", ""))
			break

func _on_cell_edited():
	if not FGGlobal or not dialogue_table:
		return
		
	var item = dialogue_table.get_edited()
	if not item:
		return
		
	var col = dialogue_table.get_edited_column()
	if col < 2:
		return
	
	var id_val = int(item.get_text(0))
	var character = item.get_text(1)
	var display_languages = visible_language_columns if visible_language_columns.size() > 0 else current_languages
	var lang = display_languages[col - 2]
	var new_text = item.get_text(col)
	
	_ensure_dialog_entry(id_val, character, lang)
	for i in range(FGGlobal.dialog_data.size()):
		var dialog_entry: Dictionary = FGGlobal.dialog_data[i] as Dictionary
		if (int(dialog_entry.get("id", -1)) == id_val and 
			str(dialog_entry.get("character", "")) == character and 
			str(dialog_entry.get("language", "")).to_upper() == lang):
			dialog_entry["text"] = new_text
			break
	FGGlobal.save_dialog_data()

# === BOTONES DE EDICIÓN ===
func _on_add_dialogue_pressed():
	if not FGGlobal or not character_name_input or character_name_input.item_count == 0:
		return
		
	var character_name := character_name_input.get_item_text(character_name_input.selected).strip_edges()
	if character_name == "":
		return
		
	var new_id := _next_id_for_character(character_name)
	
	# Crear diálogo para todos los idiomas actuales
	for lang in current_languages:
		_ensure_dialog_entry(new_id, character_name, lang)
		
	FGGlobal.save_dialog_data()
	refresh_display()
	print("[DialogueSystem] Diálogo creado con ID ", new_id, " para todos los idiomas")

func _on_delete_dialogue_pressed():
	if not FGGlobal:
		return
		
	var selected := dialogue_table.get_selected()
	if not selected:
		return
		
	var del_id := int(selected.get_text(0))
	var del_char := selected.get_text(1)
	var new_array: Array = []
	for d in FGGlobal.dialog_data:
		var dialog_entry: Dictionary = d as Dictionary
		if not (int(dialog_entry.get("id", -1)) == del_id and str(dialog_entry.get("character", "")) == del_char):
			new_array.append(d)
	FGGlobal.dialog_data = new_array
	_reorganize_all_ids()
	FGGlobal.save_dialog_data()
	refresh_display()
	print("[DialogueSystem] Diálogo eliminado y IDs reorganizados")

func _on_move_up_pressed():
	if not FGGlobal:
		return
		
	var selected := dialogue_table.get_selected()
	if not selected:
		return
		
	var sel_id := int(selected.get_text(0))
	if sel_id <= 1:
		return
		
	var prev_id := sel_id - 1
	_swap_dialogue_ids_direct(sel_id, prev_id)
	FGGlobal.save_dialog_data()
	refresh_display()
	_select_table_row_by_id(prev_id)

func _on_move_down_pressed():
	if not FGGlobal:
		return
		
	var selected := dialogue_table.get_selected()
	if not selected:
		return
		
	var sel_id := int(selected.get_text(0))
	var max_id := _get_max_global_id()
	if sel_id >= max_id:
		return
		
	var next_id := sel_id + 1
	_swap_dialogue_ids_direct(sel_id, next_id)
	FGGlobal.save_dialog_data()
	refresh_display()
	_select_table_row_by_id(next_id)

func _on_apply_mood_pressed():
	if not FGGlobal:
		return
		
	var selected = dialogue_table.get_selected()
	if not selected:
		return
		
	var id_val = int(selected.get_text(0))
	var character = selected.get_text(1)
	var mood_value = mood_names[mood_option.selected] if mood_option else "neutral"
	
	for dialog_entry in FGGlobal.dialog_data:
		var entry_dict = dialog_entry as Dictionary
		if int(entry_dict.get("id", -1)) == id_val and str(entry_dict.get("character", "")) == character:
			entry_dict["mood"] = mood_value
	FGGlobal.save_dialog_data()
	refresh_display()

func _on_apply_group_pressed():
	if not FGGlobal:
		return
		
	var selected = dialogue_table.get_selected()
	if not selected:
		return
		
	var id_val = int(selected.get_text(0))
	var character = selected.get_text(1)
	var group_value = group_input.text.strip_edges() if group_input else ""
	
	for dialog_entry in FGGlobal.dialog_data:
		var entry_dict = dialog_entry as Dictionary
		if int(entry_dict.get("id", -1)) == id_val and str(entry_dict.get("character", "")) == character:
			entry_dict["group"] = group_value
	FGGlobal.save_dialog_data()
	refresh_display()

# === HELPERS ===
func _ensure_dialog_entry(id_val: int, character: String, lang: String) -> int:
	if not FGGlobal:
		return -1
		
	var lang_u := lang.to_upper()
	for i in range(FGGlobal.dialog_data.size()):
		var dialog_entry: Dictionary = FGGlobal.dialog_data[i] as Dictionary
		if (int(dialog_entry.get("id", -1)) == id_val and 
			str(dialog_entry.get("character", "")) == character and 
			str(dialog_entry.get("language", "")).to_upper() == lang_u):
			return i
	
	# Crear nueva entrada para este idioma
	var new_dialogue := {
		"id": id_val, 
		"character": character, 
		"language": lang_u, 
		"text": "", 
		"responses": [],
		"mood": "neutral",
		"group": ""
	}
	FGGlobal.dialog_data.append(new_dialogue)
	return FGGlobal.dialog_data.size() - 1

func _next_id_for_character(character: String) -> int:
	var max_id := 0
	if FGGlobal:
		for d in FGGlobal.dialog_data:
			var dialog_entry: Dictionary = d as Dictionary
			var id_val := int(dialog_entry.get("id", 0))
			if id_val > max_id:
				max_id = id_val
	return max_id + 1

func _get_max_global_id() -> int:
	var max_id := 0
	if FGGlobal:
		for d in FGGlobal.dialog_data:
			var dialog_entry: Dictionary = d as Dictionary
			var id_val := int(dialog_entry.get("id", 0))
			if id_val > max_id:
				max_id = id_val
	return max_id

func _reorganize_all_ids():
	if not FGGlobal:
		return
		
	var dialogue_groups: Dictionary = {}
	for d in FGGlobal.dialog_data:
		var dialog_entry: Dictionary = d as Dictionary
		var id_val := int(dialog_entry.get("id", 0))
		var character := str(dialog_entry.get("character", ""))
		var key := str(id_val) + "|" + character
		if not dialogue_groups.has(key):
			dialogue_groups[key] = {"original_id": id_val, "character": character, "entries": []}
		dialogue_groups[key]["entries"].append(dialog_entry)
	
	var groups_array := []
	for key in dialogue_groups.keys():
		groups_array.append(dialogue_groups[key])
	groups_array.sort_custom(func(a, b): return int(a["original_id"]) < int(b["original_id"]))
	
	for i in range(groups_array.size()):
		var group: Dictionary = groups_array[i]
		var new_id := i + 1
		var entries: Array = group["entries"]
		for entry in entries:
			entry["id"] = new_id

func _swap_dialogue_ids_direct(id1: int, id2: int):
	if not FGGlobal:
		return
		
	var entries_id1: Array = []
	var entries_id2: Array = []
	for i in range(FGGlobal.dialog_data.size()):
		var dialog_entry: Dictionary = FGGlobal.dialog_data[i] as Dictionary
		var current_id := int(dialog_entry.get("id", 0))
		if current_id == id1:
			entries_id1.append(dialog_entry)
		elif current_id == id2:
			entries_id2.append(dialog_entry)
	for entry in entries_id1:
		entry["id"] = id2
	for entry in entries_id2:
		entry["id"] = id1

func _select_table_row_by_id(id_val: int):
	if not dialogue_table:
		return
		
	var root := dialogue_table.get_root()
	if not root:
		return
		
	var item := root.get_first_child()
	while item:
		var item_id := int(item.get_text(0))
		if item_id == id_val:
			dialogue_table.set_selected(item, 0)
			break
		item = item.get_next()

# === PERSONAJES ===
func _on_add_character_pressed():
	var new_character := ""
	if add_character_input:
		new_character = add_character_input.text.strip_edges()
		
	if new_character != "" and not available_characters.has(new_character):
		available_characters.append(new_character)
		var chars := config_data.get("characters", [])
		if typeof(chars) != TYPE_ARRAY:
			chars = []
		if new_character not in chars:
			chars.append(new_character)
		config_data["characters"] = chars
		_save_config_file()
		_update_character_options()
		if add_character_input:
			add_character_input.text = ""

func _refresh_available_characters():
	# Usar personajes base del TSCN
	var base_characters = ["Ayudante", "Narrador", "Protagonista", "Vendedor"]
	var chars := {}
	
	# Incluir personajes base
	for c in base_characters:
		chars[c] = true
	
	# Incluir personajes persistidos en config
	var persisted := config_data.get("characters", [])
	if typeof(persisted) == TYPE_ARRAY:
		for c in persisted:
			chars[str(c)] = true
	
	# Incluir personajes usados en diálogos
	if FGGlobal:
		for d in FGGlobal.dialog_data:
			var name := str(d.get("character", "")).strip_edges()
			if name != "":
				chars[name] = true
	
	available_characters = chars.keys()
	available_characters.sort_custom(func(a, b): return str(a) < str(b))
	_update_character_options()

func _update_character_options():
	if not character_option or not override_character_option or not character_name_input:
		return
		
	var current_filter := character_option.get_item_text(character_option.selected) if character_option.item_count > 0 else "Todos"
	var current_override := override_character_option.get_item_text(override_character_option.selected) if override_character_option.item_count > 0 else ""
	var current_edit_char := character_name_input.get_item_text(character_name_input.selected) if character_name_input.item_count > 0 else ""
	
	character_option.clear()
	character_option.add_item("Todos")
	for ch in available_characters:
		character_option.add_item(ch)
	
	var idx := 0
	for i in range(character_option.item_count):
		if character_option.get_item_text(i) == current_filter:
			idx = i
			break
	character_option.selected = idx
	
	override_character_option.clear()
	character_name_input.clear()
	for ch in available_characters:
		override_character_option.add_item(ch)
		character_name_input.add_item(ch)
	
	idx = 0
	for i in range(override_character_option.item_count):
		if override_character_option.get_item_text(i) == current_override:
			idx = i
			break
	override_character_option.selected = idx if override_character_option.item_count > 0 else -1
	
	idx = 0
	for i in range(character_name_input.item_count):
		if character_name_input.get_item_text(i) == current_edit_char:
			idx = i
			break
	character_name_input.selected = idx if character_name_input.item_count > 0 else -1

func _refresh_languages_from_translations():
	current_languages.clear()
	if FGGlobal and FGGlobal.translations.size() > 0:
		for lang in FGGlobal.translations.keys():
			var code := str(lang).to_upper()
			if code not in current_languages:
				current_languages.append(code)
	else:
		current_languages = ["ES", "EN"]
	_setup_language_checkboxes()

# === CONFIG OVERLAY ===
func _on_toggle_config_toggled(pressed: bool):
	if overlay_layer:
		overlay_layer.visible = pressed
	if pressed:
		_populate_character_list()
		_refresh_config_ui()

func _on_close_overlay_pressed():
	if overlay_layer:
		overlay_layer.visible = false
	if toggle_config_button:
		toggle_config_button.button_pressed = false

func _refresh_config_ui():
	if default_panel_input:
		default_panel_input.text = config_data.get("default_panel_scene", "")
	if override_character_option and override_character_option.item_count > 0:
		override_character_option.selected = 0
		_on_override_character_selected(0)
	_rebuild_names_tree_rows()

func _on_save_config_pressed():
	if default_panel_input:
		config_data["default_panel_scene"] = default_panel_input.text.strip_edges()
	_save_config_file()

func _on_override_character_selected(idx: int):
	if not override_character_option or override_character_option.item_count == 0:
		return
		
	var sel_char := override_character_option.get_item_text(idx)
	var ov := config_data.get("character_overrides", {})
	if not ov.has(sel_char):
		ov[sel_char] = {"panel_scene": "", "default_name": "", "names": {}}
		config_data["character_overrides"] = ov
	
	if override_panel_input:
		override_panel_input.text = ov[sel_char].get("panel_scene", "")
	if override_default_name_input:
		override_default_name_input.text = ov[sel_char].get("default_name", "")
	_rebuild_names_tree_rows()

func _on_save_override_pressed():
	if not override_character_option or override_character_option.item_count == 0:
		return
		
	var sel_char := override_character_option.get_item_text(override_character_option.selected)
	if sel_char == "":
		return
		
	var ov := config_data.get("character_overrides", {})
	if not ov.has(sel_char):
		ov[sel_char] = {"panel_scene": "", "default_name": "", "names": {}}
	
	if override_panel_input:
		ov[sel_char]["panel_scene"] = override_panel_input.text.strip_edges()
	if override_default_name_input:
		ov[sel_char]["default_name"] = override_default_name_input.text.strip_edges()
	
	var names := {}
	var root := names_tree.get_root() if names_tree else null
	if root:
		var item := root.get_first_child()
		while item:
			var lang: String = item.get_text(0)
			var value := item.get_text(1)
			if value.strip_edges() != "":
				names[lang] = value
			item = item.get_next()
	ov[sel_char]["names"] = names
	config_data["character_overrides"] = ov
	_save_config_file()

func _on_names_tree_edited():
	pass

func _rebuild_names_tree_rows():
	if not names_tree:
		return
		
	names_tree.clear()
	var root := names_tree.create_item()
	var lang_map := {}
	for lang in current_languages:
		lang_map[lang] = ""
	
	var sel_char := ""
	if override_character_option and override_character_option.item_count > 0:
		sel_char = override_character_option.get_item_text(override_character_option.selected)
	
	if sel_char != "" and config_data.get("character_overrides", {}).has(sel_char):
		var names_dict: Dictionary = config_data["character_overrides"][sel_char].get("names", {})
		for lang in names_dict.keys():
			lang_map[str(lang).to_upper()] = str(names_dict[lang])
	
	for lang in current_languages:
		var item := names_tree.create_item(root)
		item.set_text(0, lang)
		item.set_text(1, lang_map.get(lang, ""))
		item.set_editable(1, true)

func _populate_character_list():
	if not character_list:
		return
		
	character_list.clear()
	available_characters.sort_custom(func(a, b): return str(a) < str(b))
	for name in available_characters:
		character_list.add_item(str(name))
	if character_list.item_count > 0:
		character_list.select(0)
		_on_character_list_selected(0)

func _on_character_list_selected(idx: int):
	if not character_list or idx < 0 or idx >= character_list.item_count:
		return
		
	var sel_name := character_list.get_item_text(idx)
	if rename_input:
		rename_input.text = sel_name
	
	if override_character_option:
		for i in range(override_character_option.item_count):
			if override_character_option.get_item_text(i) == sel_name:
				override_character_option.selected = i
				break
		_on_override_character_selected(override_character_option.selected)
	_rebuild_names_tree_rows()

func _on_rename_character_pressed():
	if not character_list:
		return
		
	var idx := character_list.get_selected_items()
	if idx.is_empty():
		return
		
	var sel_idx: int = idx[0]
	var old_name := character_list.get_item_text(sel_idx)
	var new_name := ""
	if rename_input:
		new_name = rename_input.text.strip_edges()
		
	if new_name == "" or new_name == old_name:
		return
		
	_rename_character(old_name, new_name)
	_populate_character_list()
	_refresh_available_characters()
	_update_character_options()
	_refresh_config_ui()
	refresh_display()

func _on_delete_character_pressed():
	if not character_list:
		return
		
	var idx := character_list.get_selected_items()
	if idx.is_empty():
		return
		
	var sel_idx: int = idx[0]
	var name := character_list.get_item_text(sel_idx)
	_delete_character(name)
	_populate_character_list()
	_refresh_available_characters()
	_update_character_options()
	_refresh_config_ui()
	refresh_display()

func _rename_character(old_name: String, new_name: String):
	for i in range(available_characters.size()):
		if str(available_characters[i]) == old_name:
			available_characters[i] = new_name
			break
	
	if FGGlobal:
		for i in range(FGGlobal.dialog_data.size()):
			var dialog_entry: Dictionary = FGGlobal.dialog_data[i] as Dictionary
			if str(dialog_entry.get("character", "")) == old_name:
				dialog_entry["character"] = new_name
		FGGlobal.save_dialog_data()
	
	var overrides: Dictionary = config_data.get("character_overrides", {})
	if overrides.has(old_name):
		var data = overrides[old_name]
		overrides.erase(old_name)
		overrides[new_name] = data
		config_data["character_overrides"] = overrides
	
	var chars := config_data.get("characters", [])
	if typeof(chars) == TYPE_ARRAY:
		for i in range(chars.size()):
			if str(chars[i]) == old_name:
				chars[i] = new_name
				break
		config_data["characters"] = chars
	
	_save_config_file()

func _delete_character(name: String):
	available_characters.erase(name)
	
	if FGGlobal:
		var new_array: Array = []
		for d in FGGlobal.dialog_data:
			var dialog_entry: Dictionary = d as Dictionary
			if str(dialog_entry.get("character", "")) != name:
				new_array.append(d)
		FGGlobal.dialog_data = new_array
		FGGlobal.save_dialog_data()
	
	var overrides: Dictionary = config_data.get("character_overrides", {})
	if overrides.has(name):
		overrides.erase(name)
		config_data["character_overrides"] = overrides
	
	var chars := config_data.get("characters", [])
	if typeof(chars) == TYPE_ARRAY:
		var idx := -1
		for i in range(chars.size()):
			if str(chars[i]) == name:
				idx = i
				break
		if idx != -1:
			chars.remove_at(idx)
		config_data["characters"] = chars
	
	_save_config_file()

# === CONFIG FILE ===
func _load_config_file():
	if FileAccess.file_exists(config_file_path):
		var f := FileAccess.open(config_file_path, FileAccess.READ)
		if f:
			var txt := f.get_as_text()
			f.close()
			var parsed := JSON.parse_string(txt)
			if typeof(parsed) == TYPE_DICTIONARY:
				config_data = parsed
				if not config_data.has("characters"):
					config_data["characters"] = []

func _save_config_file():
	var dir := DirAccess.open("res://addons/FennecTools/")
	if dir and not dir.dir_exists("data"):
		dir.make_dir("data")
	var f := FileAccess.open(config_file_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(config_data, "\t"))
		f.close()

# === SEÑALES ADICIONALES ===
func _on_character_filter_selected(index: int):
	refresh_display()
