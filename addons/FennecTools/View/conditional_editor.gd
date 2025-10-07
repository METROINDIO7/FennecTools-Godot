@tool
extends Control

# Correct references based on the .tscn file
@onready var item_list: ItemList = $VBoxContainer/ScrollContainer/ItemList
@onready var name_input: LineEdit = $VBoxContainer/HBoxContainer/NameInput
@onready var type_option: OptionButton = $VBoxContainer/HBoxContainer/TypeOption
@onready var value_checkbox: CheckBox = $VBoxContainer/HBoxContainer/ValueCheckBox
@onready var value_spinbox: SpinBox = $VBoxContainer/HBoxContainer/ValueSpinBox
@onready var group_input: LineEdit = $VBoxContainer/HBoxContainer2/GroupInput
@onready var description_input: TextEdit = $VBoxContainer/DescriptionInput

# Adding OptionButton for group filtering
@onready var group_filter: OptionButton = $VBoxContainer/FilterContainer/GroupFilter
@onready var text_values_container: VBoxContainer = $VBoxContainer/TextValuesContainer
@onready var text_values_list: ItemList = $VBoxContainer/TextValuesContainer/TextValuesList
@onready var text_input: LineEdit = $VBoxContainer/TextValuesContainer/HBoxContainer/TextInput
@onready var add_text_button: Button = $VBoxContainer/TextValuesContainer/HBoxContainer/AddTextButton
@onready var remove_text_button: Button = $VBoxContainer/TextValuesContainer/HBoxContainer/RemoveTextButton

@onready var add_button: Button = $VBoxContainer/ButtonContainer/AddButton
@onready var edit_button: Button = $VBoxContainer/ButtonContainer/EditButton
@onready var delete_button: Button = $VBoxContainer/ButtonContainer/DeleteButton

var _fgglobal_connected: bool = false
var current_filter_group: String = "All"
var current_text_values: Array = []

func safe_load_conditionals() -> Array:
	"""Helper function to safely load conditionals"""
	if not FGGlobal or not FGGlobal._conditionals_initialized:
		return []
	
	# We need to access FGGlobal.conditionals directly after ensuring it's loaded
	if FGGlobal.load_conditionals_from_plugin():
		return FGGlobal.conditionals
	else:
		return []

func _ready():
	if not FGGlobal:
		await get_tree().process_frame
	
	connect_to_fgglobal()
	
	setup_ui()
	connect_signals()
	
	if not FGGlobal._conditionals_initialized:
		await FGGlobal.conditionals_loaded
	
	refresh_list()
	update_group_filter()

func connect_to_fgglobal():
	"""Connects to FGGlobal signals for real-time updates"""
	if FGGlobal and not _fgglobal_connected:
		if not FGGlobal.conditional_changed.is_connected(_on_conditional_changed):
			FGGlobal.conditional_changed.connect(_on_conditional_changed)
		if not FGGlobal.conditionals_loaded.is_connected(_on_conditionals_loaded):
			FGGlobal.conditionals_loaded.connect(_on_conditionals_loaded)
		_fgglobal_connected = true

func _on_conditional_changed(id: int, new_value: Variant):
	"""Callback when a conditional changes from elsewhere"""
	refresh_list()

func _on_conditionals_loaded():
	"""Callback when conditionals finish loading"""
	refresh_list()
	update_group_filter()

func setup_ui():
	# Clear duplicate options in .tscn
	type_option.clear()
	type_option.add_item("Boolean", 0)
	type_option.add_item("Numeric", 1)
	type_option.add_item("Texts", 2)  # New type
	type_option.selected = 0
	_on_type_selected(0)
	
	# Configure group filter
	group_filter.clear()
	group_filter.add_item("All", -1)
	
	# Initially hide multiple text container
	text_values_container.visible = false

func connect_signals():
	add_button.pressed.connect(_on_add_pressed)
	edit_button.pressed.connect(_on_edit_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	type_option.item_selected.connect(_on_type_selected)
	item_list.item_selected.connect(_on_item_selected)
	
	# Connect group filter signals
	group_filter.item_selected.connect(_on_group_filter_selected)
	
	# Connect signals for multiple text
	add_text_button.pressed.connect(_on_add_text_pressed)
	remove_text_button.pressed.connect(_on_remove_text_pressed)
	text_input.text_submitted.connect(_on_text_submitted)

func _on_type_selected(index: int):
	value_checkbox.visible = (index == 0)  # Boolean
	value_spinbox.visible = (index == 1)   # Numeric
	text_values_container.visible = (index == 2)  # Multiple Text
	
	# For simple text, we'll use description_input
	if index == 2:  # Multiple Text
		update_text_values_list()

func update_group_filter():
	"""Updates OptionButton with available groups"""
	if not FGGlobal or not FGGlobal._conditionals_initialized:
		return
	
	var current_selection = current_filter_group
	group_filter.clear()
	group_filter.add_item("All", -1)
	
	var original_conditionals = safe_load_conditionals()
	var groups = []
	for conditional in original_conditionals:
		var group = conditional.get("group", "default")
		if group not in groups:
			groups.append(group)
	
	for i in range(groups.size()):
		group_filter.add_item(groups[i], i)
		if groups[i] == current_selection:
			group_filter.selected = i + 1

func _on_group_filter_selected(index: int):
	"""Callback when group filter is selected"""
	if index == 0:
		current_filter_group = "All"
	else:
		current_filter_group = group_filter.get_item_text(index)
	
	refresh_list()

func refresh_list():
	item_list.clear()
	
	if not FGGlobal:
		item_list.add_item("❌ Error: FGGlobal not available")
		return
	
	if not FGGlobal._conditionals_initialized:
		item_list.add_item("⏳ Loading conditionals...")
		return
	
	var original_conditionals = safe_load_conditionals()
	
	if original_conditionals.size() == 0:
		item_list.add_item("📝 No conditionals defined")
		return
	
	for conditional in original_conditionals:
		var group_text = conditional.get("group", "default")
		
		# Apply group filter
		if current_filter_group != "All" and group_text != current_filter_group:
			continue
		
		var text = ""
		
		match conditional.get("type", ""):
			"boolean":
				var icon = "✅" if conditional.get("value_bool", false) else "⛔"
				text = "[%s] %s %s (ID: %d)" % [group_text, icon, conditional.get("name", "No name"), conditional.get("id", 0)]
			"numeric":
				text = "[%s] %.2f %s (ID: %d)" % [group_text, conditional.get("value_float", 0.0), conditional.get("name", "No name"), conditional.get("id", 0)]
			"texts":
				var values = conditional.get("text_values", [])
				var values_str = str(values.size()) + " texts"
				text = "[%s] [%s] %s (ID: %d)" % [group_text, values_str, conditional.get("name", "No name"), conditional.get("id", 0)]
			_:
				text = "[%s] ❓ %s (ID: %d) - Unknown type" % [group_text, conditional.get("name", "No name"), conditional.get("id", 0)]
		
		item_list.add_item(text)

func _on_item_selected(index: int):
	if not FGGlobal or not FGGlobal._conditionals_initialized:
		return
	
	# Adjust index by applied filter
	var filtered_conditionals = get_filtered_conditionals()
	if index < 0 or index >= filtered_conditionals.size():
		return
	
	var conditional = filtered_conditionals[index]
	name_input.text = conditional.get("name", "")
	group_input.text = conditional.get("group", "default")
	description_input.text = conditional.get("description", "")
	
	match conditional.get("type", ""):
		"boolean":
			type_option.selected = 0
			value_checkbox.button_pressed = conditional.get("value_bool", false)
		"numeric":
			type_option.selected = 1
			value_spinbox.value = conditional.get("value_float", 0.0)
		"texts":
			type_option.selected = 2  # ✅ CORRECTED: was 3, now is 2
			current_text_values = conditional.get("text_values", [])
			update_text_values_list()
	
	_on_type_selected(type_option.selected)

func get_filtered_conditionals() -> Array:
	"""Gets conditionals filtered by group"""
	if not FGGlobal or not FGGlobal._conditionals_initialized:
		return []
	
	var original_conditionals = safe_load_conditionals()
	
	if current_filter_group == "All":
		return original_conditionals
	
	var filtered = []
	for conditional in original_conditionals:
		var group_text = conditional.get("group", "default")
		if group_text == current_filter_group:
			filtered.append(conditional)
	
	return filtered

func update_text_values_list():
	"""Updates multiple text values list"""
	text_values_list.clear()
	for value in current_text_values:
		text_values_list.add_item(value)

func _on_add_text_pressed():
	"""Adds new text value"""
	var text = text_input.text.strip_edges()
	if text != "" and text not in current_text_values:
		current_text_values.append(text)
		update_text_values_list()
		text_input.text = ""

func _on_remove_text_pressed():
	"""Removes selected text value"""
	var selected = text_values_list.get_selected_items()
	if selected.size() > 0:
		var index = selected[0]
		if index >= 0 and index < current_text_values.size():
			current_text_values.remove_at(index)
			update_text_values_list()

func _on_text_submitted(text: String):
	"""Callback when Enter is pressed in text input"""
	_on_add_text_pressed()

func _on_add_pressed():
	if not FGGlobal or not FGGlobal._conditionals_initialized:
		return
	
	var name_text = name_input.text.strip_edges()
	if name_text == "":
		return
	
	var original_conditionals = safe_load_conditionals()
	for conditional in original_conditionals:
		if conditional.get("name", "") == name_text:
			return
	
	# Generate new unique ID
	var new_id = 1
	for conditional in original_conditionals:
		if conditional.get("id", 0) >= new_id:
			new_id = conditional.get("id", 0) + 1
	
	var new_conditional = {
		"id": new_id,
		"name": name_text,
		"group": group_input.text.strip_edges() if group_input.text.strip_edges() != "" else "default",
		"description": description_input.text.strip_edges(),
		"type": ""
	}
	
	match type_option.selected:
		0: # Boolean
			new_conditional.type = "boolean"
			new_conditional.value_bool = value_checkbox.button_pressed
		1: # Numeric
			new_conditional.type = "numeric"
			new_conditional.value_float = value_spinbox.value
		2: # Multiple Text
			new_conditional.type = "texts"
			new_conditional.text_values = current_text_values.duplicate()
	
	original_conditionals.append(new_conditional)
	FGGlobal.conditionals = original_conditionals
	FGGlobal.save_conditionals()
	refresh_list()
	update_group_filter()
	clear_inputs()

func _on_edit_pressed():
	if not FGGlobal or not FGGlobal._conditionals_initialized:
		return
	
	var selected = item_list.get_selected_items()
	if selected.size() == 0:
		return
	
	var filtered_conditionals = get_filtered_conditionals()
	var index = selected[0]
	if index < 0 or index >= filtered_conditionals.size():
		return
	
	var conditional = filtered_conditionals[index]
	var name_text = name_input.text.strip_edges()
	
	# Validate unique name (excluding current conditional)
	var original_conditionals = safe_load_conditionals()
	for other_conditional in original_conditionals:
		if other_conditional.get("id", -1) != conditional.get("id", -1) and other_conditional.get("name", "") == name_text:
			return
	
	# Find real conditional in original array (not filtered)
	var real_conditional = null
	var real_index = -1
	for i in range(original_conditionals.size()):
		if original_conditionals[i].get("id", -1) == conditional.get("id", -1):
			real_conditional = original_conditionals[i]
			real_index = i
			break
	
	if real_conditional == null:
		return
	
	# Update basic data
	real_conditional.name = name_text
	real_conditional.group = group_input.text.strip_edges() if group_input.text.strip_edges() != "" else "default"
	real_conditional.description = description_input.text.strip_edges()
	
	# Update according to type
	match type_option.selected:
		0: # Boolean
			real_conditional.type = "boolean"
			real_conditional.value_bool = value_checkbox.button_pressed
			# Clear other values if type changed
			real_conditional.erase("value_float")
			real_conditional.erase("text_values")
		1: # Numeric
			real_conditional.type = "numeric"
			real_conditional.value_float = value_spinbox.value
			# Clear other values if type changed
			real_conditional.erase("value_bool")
			real_conditional.erase("text_values")
		2: # Multiple Text
			real_conditional.type = "texts"
			real_conditional.text_values = current_text_values.duplicate()
			# Clear other values if type changed
			real_conditional.erase("value_bool")
			real_conditional.erase("value_float")
	
	# Update FGGlobal and save
	FGGlobal.conditionals = original_conditionals
	FGGlobal.save_conditionals()
	
	# Refresh interface
	refresh_list()
	update_group_filter()

func _on_delete_pressed():
	if not FGGlobal or not FGGlobal._conditionals_initialized:
		return
	
	var selected = item_list.get_selected_items()
	if selected.size() == 0:
		return
	
	var filtered_conditionals = get_filtered_conditionals()
	var index = selected[0]
	if index < 0 or index >= filtered_conditionals.size():
		return
	
	var conditional = filtered_conditionals[index]
	var conditional_name = conditional.get("name", "No name")
	
	var original_conditionals = safe_load_conditionals()
	for i in range(original_conditionals.size()):
		if original_conditionals[i] == conditional:
			original_conditionals.remove_at(i)
			break
	
	# Fix: Update FGGlobal.conditionals and save only to plugin file (not slots)
	FGGlobal.conditionals = original_conditionals
	FGGlobal.save_conditionals_to_plugin()  # Only save to plugin file, not user slots
	refresh_list()
	update_group_filter()
	clear_inputs()

func clear_inputs():
	name_input.text = ""
	group_input.text = ""
	description_input.text = ""
	value_checkbox.button_pressed = false
	value_spinbox.value = 0.0
	current_text_values.clear()
	update_text_values_list()

func _exit_tree():
	"""Cleanup on exit"""
	if FGGlobal and _fgglobal_connected:
		if FGGlobal.conditional_changed.is_connected(_on_conditional_changed):
			FGGlobal.conditional_changed.disconnect(_on_conditional_changed)
		if FGGlobal.conditionals_loaded.is_connected(_on_conditionals_loaded):
			FGGlobal.conditionals_loaded.disconnect(_on_conditionals_loaded)
		_fgglobal_connected = false
