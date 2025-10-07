@tool
extends Control

@onready var enabled_checkbox: CheckBox = $VBoxContainer/EnabledContainer/EnabledCheckBox
@onready var group_line_edit: LineEdit = $VBoxContainer/GroupContainer/GroupLineEdit
@onready var save_button: Button = $VBoxContainer/ButtonsContainer/SaveButton
@onready var reset_button: Button = $VBoxContainer/ButtonsContainer/ResetButton
@onready var test_button: Button = $VBoxContainer/ButtonsContainer/TestButton
@onready var status_label: Label = $VBoxContainer/StatusLabel

var input_fields: Dictionary = {}

func _ready():
	_setup_input_field_references()
	
	# Connect signals only if nodes exist
	if is_instance_valid(enabled_checkbox):
		enabled_checkbox.toggled.connect(_on_enabled_toggled)
	if is_instance_valid(group_line_edit):
		group_line_edit.text_changed.connect(_on_group_changed)
	if is_instance_valid(save_button):
		save_button.pressed.connect(_on_save_pressed)
	if is_instance_valid(reset_button):
		reset_button.pressed.connect(_on_reset_pressed)
	if is_instance_valid(test_button):
		test_button.pressed.connect(_on_test_pressed)
	
	# Configure real-time saving
	_setup_realtime_save()
	
	# Add all interactable elements to group
	_add_to_interactable_group()
	
	# Load current configuration from JSON
	_load_current_config()
	
	# Connect to global system signals if available
	if FGGlobal:
		FGGlobal.input_control_toggled.connect(_on_input_control_toggled)

func _setup_input_field_references():
	"""Sets up references to input fields with validation"""
	var field_paths = {
		"up": "VBoxContainer/VBoxContainer_ScrollContainer#MappingsContainer/VBoxContainer_ScrollContainer_MappingsContainer#UpContainer/VBoxContainer_ScrollContainer_MappingsContainer_UpContainer#UpLineEdit",
		"down": "VBoxContainer/VBoxContainer_ScrollContainer#MappingsContainer/VBoxContainer_ScrollContainer_MappingsContainer#DownContainer/VBoxContainer_ScrollContainer_MappingsContainer_DownContainer#DownLineEdit",
		"left": "VBoxContainer/VBoxContainer_ScrollContainer#MappingsContainer/VBoxContainer_ScrollContainer_MappingsContainer#LeftContainer/VBoxContainer_ScrollContainer_MappingsContainer_LeftContainer#LeftLineEdit",
		"right": "VBoxContainer/VBoxContainer_ScrollContainer#MappingsContainer/VBoxContainer_ScrollContainer_MappingsContainer#RightContainer/VBoxContainer_ScrollContainer_MappingsContainer_RightContainer#RightLineEdit",
		"accept": "VBoxContainer/VBoxContainer_ScrollContainer#MappingsContainer/VBoxContainer_ScrollContainer_MappingsContainer#AcceptContainer/VBoxContainer_ScrollContainer_MappingsContainer_AcceptContainer#AcceptLineEdit",
		"back": "VBoxContainer/VBoxContainer_ScrollContainer#MappingsContainer/VBoxContainer_ScrollContainer_MappingsContainer#BackContainer/VBoxContainer_ScrollContainer_MappingsContainer_BackContainer#BackLineEdit"
	}
	
	for action in field_paths:
		var node = get_node_or_null(field_paths[action])
		if is_instance_valid(node):
			input_fields[action] = node

func _add_to_interactable_group():
	"""Adds all interactable elements to group for navigation"""
	var interactable_nodes = [
		enabled_checkbox,
		group_line_edit,
		save_button,
		reset_button,
		test_button
	]
	
	for field in input_fields.values():
		if is_instance_valid(field):
			interactable_nodes.append(field)
	
	for node in interactable_nodes:
		if is_instance_valid(node):
			node.add_to_group("interactable")

func _load_current_config():
	"""Loads current system configuration from JSON"""
	if not FGGlobal:
		_update_status("FGGlobal not available")
		return
	
	# Force load from JSON
	FGGlobal.load_custom_input_mappings()
	
	# Load enabled state
	if is_instance_valid(enabled_checkbox):
		enabled_checkbox.button_pressed = FGGlobal.input_control_enabled
	
	if is_instance_valid(group_line_edit):
		group_line_edit.text = FGGlobal.get_interactable_group_name()
	
	# Load input mappings from FGGlobal
	var mappings = FGGlobal.custom_input_mappings
	for action in input_fields:
		if mappings.has(action) and is_instance_valid(input_fields[action]):
			var inputs = mappings[action]
			if inputs.size() > 0:
				input_fields[action].text = ", ".join(inputs)
			else:
				input_fields[action].text = ""

func _update_status(message: String):
	"""Safely updates status label"""
	if is_instance_valid(status_label):
		status_label.text = "Status: " + message

func _on_group_changed(new_text: String):
	"""Callback when group name changes"""
	if FGGlobal:
		FGGlobal.set_interactable_group_name(new_text.strip_edges())
		_update_status("Group updated to '" + new_text + "'")

func _on_enabled_toggled(button_pressed: bool):
	"""Callback when checkbox state changes"""
	if FGGlobal:
		FGGlobal.enable_input_control(button_pressed)
		_update_status("System " + ("ENABLED" if button_pressed else "DISABLED"))

func _on_save_pressed():
	"""Saves current configuration to JSON"""
	if not FGGlobal:
		_update_status("Error - FGGlobal not available")
		return
	
	# Save enabled state
	if is_instance_valid(enabled_checkbox):
		FGGlobal.enable_input_control(enabled_checkbox.button_pressed)
	
	# Save group name
	if is_instance_valid(group_line_edit):
		FGGlobal.set_interactable_group_name(group_line_edit.text.strip_edges())
	
	# Process and save each input mapping
	var mappings_to_save = {}
	for action in input_fields:
		if is_instance_valid(input_fields[action]):
			var input_text = input_fields[action].text.strip_edges()
			var inputs = []
			
			if input_text.length() > 0:
				var parts = input_text.split(",")
				for part in parts:
					var trimmed = part.strip_edges()
					if trimmed.length() > 0:
						inputs.append(trimmed)
			
			mappings_to_save[action] = inputs
			
			# Update FGGlobal immediately
			FGGlobal.custom_input_mappings[action] = inputs
	
	# Save everything to JSON
	var save_success = FGGlobal.save_custom_input_mappings()
	
	if save_success:
		# Apply mappings to InputMap if system is enabled
		if FGGlobal.input_control_enabled:
			FGGlobal.apply_custom_input_mappings()
		
		_update_status("Configuration saved to JSON successfully")
	else:
		_update_status("Error saving configuration to JSON")

func reload_config():
	"""Reloads configuration from JSON file"""
	if FGGlobal:
		FGGlobal.load_custom_input_mappings()
		_load_current_config()
		_update_status("Configuration reloaded from JSON")

func _on_reset_pressed():
	"""Restores default values"""
	if not FGGlobal:
		_update_status("Error - FGGlobal not available")
		return
	
	if is_instance_valid(group_line_edit):
		group_line_edit.text = "interactable"
	FGGlobal.set_interactable_group_name("interactable")
	
	var default_mappings = {
		"up": ["ui_up"],
		"down": ["ui_down"],
		"left": ["ui_left"],
		"right": ["ui_right"],
		"accept": ["ui_accept"],
		"back": ["ui_cancel"]
	}
	
	# Update input fields
	for action in input_fields:
		if default_mappings.has(action) and is_instance_valid(input_fields[action]):
			input_fields[action].text = ", ".join(default_mappings[action])
	
	# Update FGGlobal
	for action in default_mappings:
		FGGlobal.set_custom_input_mapping(action, default_mappings[action])
	
	_update_status("Default values restored")

func _on_test_pressed():
	"""Tests current configuration"""
	if not FGGlobal:
		_update_status("Error - FGGlobal not available")
		return
	
	# Save configuration first
	_on_save_pressed()
	
	# Activate system temporarily if not active
	var was_enabled = FGGlobal.input_control_enabled
	if not was_enabled:
		FGGlobal.enable_input_control(true)
		FGGlobal.apply_custom_input_mappings()
	
	_update_status("Testing configuration... Use configured keys")
	
	# Create timer to show test result
	var test_timer = Timer.new()
	add_child(test_timer)
	test_timer.wait_time = 5.0
	test_timer.one_shot = true
	test_timer.timeout.connect(_on_test_timeout.bind(was_enabled, test_timer))
	test_timer.start()

func _setup_realtime_save():
	"""Sets up real-time saving when fields change"""
	for action in input_fields:
		if is_instance_valid(input_fields[action]):
			# Connect text change signal for auto-saving
			if input_fields[action].has_signal("text_changed"):
				input_fields[action].text_changed.connect(_on_field_changed.bind(action))
			
			# Also connect when focus is lost
			if input_fields[action].has_signal("focus_exited"):
				input_fields[action].focus_exited.connect(_on_field_focus_lost.bind(action))

func _on_field_changed(new_text: String, action: String):
	"""Callback when field text changes"""
	# Optional: Real-time auto-saving
	# _auto_save_field(action, new_text)
	pass

func _on_field_focus_lost(action: String):
	"""Callback when field loses focus - save automatically"""
	if is_instance_valid(input_fields[action]):
		var input_text = input_fields[action].text.strip_edges()
		var inputs = []
		
		if input_text.length() > 0:
			var parts = input_text.split(",")
			for part in parts:
				var trimmed = part.strip_edges()
				if trimmed.length() > 0:
					inputs.append(trimmed)
		
		# Update FGGlobal and save
		if FGGlobal:
			FGGlobal.custom_input_mappings[action] = inputs
			FGGlobal.save_custom_input_mappings()

func _on_test_timeout(was_enabled: bool, timer: Timer):
	"""Callback when test finishes"""
	# Restore original state if needed
	if not was_enabled and FGGlobal:
		FGGlobal.enable_input_control(false)
	
	_update_status("Test completed")
	
	# Clean up timer
	if is_instance_valid(timer):
		timer.queue_free()

func _on_input_control_toggled(enabled: bool):
	"""Callback when control system changes state"""
	if is_instance_valid(enabled_checkbox):
		enabled_checkbox.button_pressed = enabled
	_update_status("System " + ("ENABLED" if enabled else "DISABLED"))
