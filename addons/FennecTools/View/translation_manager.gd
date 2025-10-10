@tool
extends Control

# Correct references based on the .tscn file
@onready var add_language_input: LineEdit = $VBoxContainer/LanguageContainer/AddLanguageInput
@onready var add_language_button: Button = $VBoxContainer/LanguageContainer/AddLanguageButton
@onready var delete_language_button: Button = $VBoxContainer/LanguageContainer/DeleteLanguageButton

@onready var group_target_input: LineEdit = $VBoxContainer/NodeGroupsContainer/GroupTargetInput
@onready var apply_to_group_button: Button = $VBoxContainer/NodeGroupsContainer/ApplyToGroupButton

@onready var translation_tree: Tree = $VBoxContainer/ScrollContainer/TranslationTree

@onready var key_input: LineEdit = $VBoxContainer/EditContainer/KeyInput
@onready var language_option: OptionButton = $VBoxContainer/EditContainer/LanguageOption
@onready var value_input: TextEdit = $VBoxContainer/EditContainer/ValueInput

@onready var add_button: Button = $VBoxContainer/ButtonContainer/AddButton
@onready var edit_button: Button = $VBoxContainer/ButtonContainer/EditButton
@onready var delete_button: Button = $VBoxContainer/ButtonContainer/DeleteButton

var current_languages: Array = ["es", "en"]
var selected_update_group: String = "translate"  # Default value
var delete_language_panel: PanelContainer
var delete_language_option_button: OptionButton


func _ready():
	load_translation_data()
	_create_delete_language_panel()
	setup_ui()
	connect_signals()
	refresh_display()


func _create_delete_language_panel():
	delete_language_panel = PanelContainer.new()
	delete_language_panel.name = "DeleteLanguagePanel"

	var temp_container = VBoxContainer.new()
	
	var label = Label.new()
	label.text = "Select the language to delete:"
	temp_container.add_child(label)
	
	delete_language_option_button = OptionButton.new()
	temp_container.add_child(delete_language_option_button)
	
	var button_container = HBoxContainer.new()
	
	var delete_btn = Button.new()
	delete_btn.text = "Delete"
	delete_btn.pressed.connect(func():
		var selected_lang = current_languages[delete_language_option_button.selected]
		_delete_language(selected_lang)
		delete_language_panel.visible = false
	)
	button_container.add_child(delete_btn)
	
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(func():
		delete_language_panel.visible = false
	)
	button_container.add_child(cancel_btn)
	
	temp_container.add_child(button_container)
	
	delete_language_panel.add_child(temp_container)
	$VBoxContainer.add_child(delete_language_panel)
	delete_language_panel.visible = false


func setup_ui():
	update_language_options()
	setup_translation_tree()
	# Load the saved group from FGGlobal
	if FGGlobal and FGGlobal.current_target_group:
		selected_update_group = FGGlobal.current_target_group
		group_target_input.text = selected_update_group
	else:
		group_target_input.text = selected_update_group
	group_target_input.placeholder_text = "Enter the group name (e.g., ui, pp, player)"


func connect_signals():
	add_language_button.pressed.connect(_on_add_language_pressed)
	delete_language_button.pressed.connect(_on_delete_language_pressed)
	add_button.pressed.connect(_on_add_translation_pressed)
	edit_button.pressed.connect(_on_edit_translation_pressed)
	delete_button.pressed.connect(_on_delete_translation_pressed)
	translation_tree.item_selected.connect(_on_item_selected)
	translation_tree.item_edited.connect(_on_cell_edited)
	group_target_input.text_submitted.connect(_on_group_target_submitted)
	apply_to_group_button.pressed.connect(_on_apply_to_group_pressed)
	# Also connect the text change to save automatically
	group_target_input.text_changed.connect(_on_group_target_changed)


func clear_inputs():
	key_input.text = ""
	value_input.text = ""


func _on_add_language_pressed():
	var new_lang = add_language_input.text.strip_edges()
	if new_lang != "" and not current_languages.has(new_lang) and FGGlobal:
		current_languages.append(new_lang)
		if not FGGlobal.translations.has(new_lang):
			FGGlobal.translations[new_lang] = {}
		update_language_options()
		setup_translation_tree()
		refresh_display()
		save_translation_data()
		add_language_input.text = ""


func _on_delete_language_pressed():
	if current_languages.size() <= 1:
		return
	
	if not FGGlobal:
		return

	delete_language_option_button.clear()
	for lang in current_languages:
		delete_language_option_button.add_item(lang)

	delete_language_panel.visible = true


func _delete_language(lang_to_delete: String):
	if current_languages.has(lang_to_delete):
		current_languages.erase(lang_to_delete)
		if FGGlobal.translations.has(lang_to_delete):
			FGGlobal.translations.erase(lang_to_delete)
		
		update_language_options()
		setup_translation_tree()
		refresh_display()
		save_translation_data()
	else:
		pass


# New function to handle real-time changes
func _on_group_target_changed(new_text: String):
	selected_update_group = new_text.strip_edges()
	if selected_update_group.is_empty():
		selected_update_group = "translate"  # Default value
	
	# Update FGGlobal immediately
	if FGGlobal:
		FGGlobal.set_translation_target_group(selected_update_group)
	
	# Save data for persistence
	save_translation_data()


func _on_group_target_submitted(new_text: String):
	selected_update_group = new_text.strip_edges()
	if selected_update_group.is_empty():
		selected_update_group = "translate"  # Default value
		group_target_input.text = selected_update_group
	
	if FGGlobal:
		FGGlobal.set_translation_target_group(selected_update_group)
	
	save_translation_data()


func _on_apply_to_group_pressed():
	var group_name = group_target_input.text.strip_edges()
	if group_name.is_empty():
		group_name = "translate"  # Default value
		group_target_input.text = group_name
	
	selected_update_group = group_name
	if FGGlobal:
		FGGlobal.set_translation_target_group(selected_update_group)
		FGGlobal.update_language()
	
	save_translation_data()


func setup_translation_tree():
	translation_tree.set_columns(current_languages.size() + 1)  # +1 for key column
	translation_tree.set_column_title(0, "Key")
	for i in range(current_languages.size()):
		translation_tree.set_column_title(i + 1, current_languages[i].to_upper())
	translation_tree.column_titles_visible = true
	translation_tree.set_column_expand(0, false)
	translation_tree.set_column_custom_minimum_width(0, 150)


func _validate_and_apply_to_group():
	if selected_update_group == "":
		selected_update_group = "translate"  # Default value
	
	var nodes = get_tree().get_nodes_in_group(selected_update_group)
	if nodes.size() == 0:
		return
	
	for node in nodes:
		if node.has_method("update_language"):
			node.update_language()
		else:
			pass


func _on_cell_edited():
	var selected = translation_tree.get_selected()
	if selected and FGGlobal:
		var key = selected.get_text(0)
		
		# Update all languages for this key
		for i in range(current_languages.size()):
			var lang = current_languages[i]
			var value = selected.get_text(i + 1)
			
			if not FGGlobal.translations.has(lang):
				FGGlobal.translations[lang] = {}
			
			FGGlobal.translations[lang][key] = value
		
		save_translation_data()
		update_language_nodes()


func refresh_display():
	translation_tree.clear()
	if not FGGlobal:
		return
		
	var root = translation_tree.create_item()
	
	var all_keys = {}
	for lang in FGGlobal.translations:
		for key in FGGlobal.translations[lang]:
			all_keys[key] = true
	
	for key in all_keys:
		var item = translation_tree.create_item(root)
		item.set_text(0, key)
		
		for i in range(current_languages.size()):
			var lang = current_languages[i]
			var value = ""
			if FGGlobal.translations.has(lang) and FGGlobal.translations[lang].has(key):
				value = FGGlobal.translations[lang][key]
			item.set_text(i + 1, value)
			item.set_editable(i + 1, true)


func _on_item_selected():
	var selected = translation_tree.get_selected()
	if selected and FGGlobal:
		var key = selected.get_text(0)
		key_input.text = key
		
		var selected_lang = current_languages[language_option.selected] if language_option.selected < current_languages.size() else "es"
		if FGGlobal.translations.has(selected_lang) and FGGlobal.translations[selected_lang].has(key):
			value_input.text = FGGlobal.translations[selected_lang][key]
		else:
			value_input.text = ""


func _on_add_translation_pressed():
	if not FGGlobal:
		return
		
	var key = key_input.text.strip_edges()
	var value = value_input.text.strip_edges()
	var selected_lang = current_languages[language_option.selected] if language_option.selected < current_languages.size() else "es"
	
	if key == "" or value == "":
		return
	
	if not FGGlobal.translations.has(selected_lang):
		FGGlobal.translations[selected_lang] = {}
	
	FGGlobal.translations[selected_lang][key] = value
	save_translation_data()
	refresh_display()
	update_language_nodes()
	clear_inputs()


func _on_edit_translation_pressed():
	var selected = translation_tree.get_selected()
	if not selected:
		return

	if not FGGlobal:
		return

	var old_key = selected.get_text(0)
	var new_key = key_input.text.strip_edges()
	var value = value_input.text.strip_edges()
	var selected_lang = current_languages[language_option.selected] if language_option.selected < current_languages.size() else "es"

	if new_key == "":
		return

	# If the key has changed, we need to update it across all languages
	if old_key != new_key:
		for lang in FGGlobal.translations:
			if FGGlobal.translations[lang].has(old_key):
				var old_value = FGGlobal.translations[lang][old_key]
				FGGlobal.translations[lang].erase(old_key)
				FGGlobal.translations[lang][new_key] = old_value

	# Update the value for the current language
	if value != "":
		if not FGGlobal.translations.has(selected_lang):
			FGGlobal.translations[selected_lang] = {}
		FGGlobal.translations[selected_lang][new_key] = value

	save_translation_data()
	refresh_display()
	update_language_nodes()


func _on_delete_translation_pressed():
	if not FGGlobal:
		return
		
	var key = key_input.text.strip_edges()
	if key == "":
		return
	
	for lang in FGGlobal.translations:
		if FGGlobal.translations[lang].has(key):
			FGGlobal.translations[lang].erase(key)
	
	save_translation_data()
	refresh_display()
	update_language_nodes()
	clear_inputs()


func update_language_nodes():
	_validate_and_apply_to_group()


func save_translation_data():
	if not FGGlobal:
		return
		
	var translation_path = "res://addons/FennecTools/data/fennec_translations.json"
	ensure_data_directory()
	var file = FileAccess.open(translation_path, FileAccess.WRITE)
	if file:
		var data = {
			"translations": FGGlobal.translations,
			"selected_group": selected_update_group,
			"target_group": selected_update_group,  # We duplicate for compatibility
			"current_languages": current_languages
		}
		file.store_string(JSON.stringify(data))
		file.close()
		
		# Also update FGGlobal to ensure synchronization
		if FGGlobal:
			FGGlobal.current_target_group = selected_update_group
			FGGlobal.save_translations()
	else:
		pass


func load_translation_data():
	var translation_path = "res://addons/FennecTools/data/fennec_translations.json"
	if FileAccess.file_exists(translation_path):
		var file = FileAccess.open(translation_path, FileAccess.READ)
		if file:
			var json_data = file.get_as_text()
			file.close()
			var result = JSON.parse_string(json_data)
			if result and FGGlobal:
				FGGlobal.translations = result.get("translations", {})
				
				# Load the target group with multiple backup sources
				selected_update_group = result.get("selected_group", 
					result.get("target_group", "translate"))
				
				# Load saved languages
				var saved_languages = result.get("current_languages", [])
				if saved_languages.size() > 0:
					current_languages = saved_languages
				elif FGGlobal.translations.size() > 0:
					current_languages = FGGlobal.translations.keys()
				
				# Synchronize with FGGlobal
				FGGlobal.current_target_group = selected_update_group
			else:
				pass
		else:
			pass
	else:
		# If the file does not exist, use default values and synchronize with FGGlobal
		if FGGlobal and FGGlobal.current_target_group:
			selected_update_group = FGGlobal.current_target_group


func ensure_data_directory():
	var dir = DirAccess.open("res://addons/FennecTools/")
	if dir and not dir.dir_exists("data"):
		dir.make_dir("data")


func update_language_options():
	language_option.clear()
	for lang in current_languages:
		language_option.add_item(lang)
