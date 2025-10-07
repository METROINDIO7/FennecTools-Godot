extends Node

# Improved navigation system integrated with FGGlobal
var current_button_index: int = 0
var interactuable_nodes: Array[Node] = []
var navigation_sound: AudioStreamPlayer

# Configuration
@export var wrap_selection: bool = true
@export var highlight_color: Color = Color.ALICE_BLUE
@export var navigation_sound_path: String = ""
@export var grid_navigation: bool = false
@export var grid_columns: int = 3
@export var slider_step: float = 1.5
@export var auto_refresh_enabled: bool = true
@export var auto_refresh_interval: float = 0.5

# States
var original_colors: Dictionary = {}
var is_adjusting_slider: bool = false
var is_editing_text: bool = false  # new state for text fields
var refresh_timer: Timer
var last_node_count: int = 0

# Signals
signal selection_changed(node: Control)

func _ready():
	if not FGGlobal or not FGGlobal.input_control_enabled:
		return
		
	process_mode = Node.PROCESS_MODE_ALWAYS
	refresh_interactables()
	
	
	# Configure navigation sound
	if navigation_sound_path:
		navigation_sound = AudioStreamPlayer.new()
		add_child(navigation_sound)
		navigation_sound.stream = load(navigation_sound_path)
		navigation_sound.volume_db = -10
	
	# Connect controller signals
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	
	# Configure auto-refresh timer
	if auto_refresh_enabled:
		refresh_timer = Timer.new()
		add_child(refresh_timer)
		refresh_timer.wait_time = auto_refresh_interval
		refresh_timer.timeout.connect(_on_refresh_timer_timeout)
		refresh_timer.start()
	
	# Connect tree signals
	get_tree().node_added.connect(_on_node_added)
	last_node_count = get_tree().get_nodes_in_group("interactuable").size()

func _process(delta: float) -> void:
	# Check if the system is enabled
	if not FGGlobal or not FGGlobal.input_control_enabled:
		return
		
	# Check for visibility changes
	_check_visibility_changes()
	
	if interactuable_nodes.size() == 0:
		return
	
	var current_node = interactuable_nodes[current_button_index]
	
	if is_editing_text and (current_node is TextEdit or current_node is LineEdit):
		_handle_text_editing(current_node)
		return
	
	# Handle slider adjustment mode
	if is_adjusting_slider and (current_node is HSlider or current_node is VSlider):
		_handle_slider_adjustment(current_node)
		return  # IMPORTANT: return here prevents normal navigation from being processed
		
	
	# Handle normal navigation using the custom system
	var old_index = current_button_index
	
	if grid_navigation:
		_handle_grid_navigation()
	else:
		_handle_linear_navigation()
	
	# Only update focus if the selection changed
	if old_index != current_button_index:
		_play_navigation_sound()
		_update_focus()
		
		# Emit signal with the newly selected node
		if current_button_index < interactuable_nodes.size():
			selection_changed.emit(interactuable_nodes[current_button_index])
	
	# Handle interaction with the current control
	if FGGlobal.is_custom_action_just_pressed("accept"):
		_interact_with_control(current_node)




func _handle_text_editing(text_node: Control) -> void:
	# Only ui_cancel can exit text editing mode
	# This avoids conflicts with custom keys like "Q" for back
	if Input.is_action_just_pressed("ui_cancel"):
		is_editing_text = false
		text_node.release_focus()
		_update_focus()
		return
	
	# The rest of the input is handled normally by the TextEdit/LineEdit
	# We do not intercept other keys to allow normal writing




func _handle_option_button(option_button: OptionButton) -> void:
	# Get the popup menu
	var popup = option_button.get_popup()
	if not popup:
		return
	
	# Store current selection
	var current_selection = option_button.selected
	
	# Show the popup
	option_button.show_popup()
	
	# Wait for the popup to appear
	await get_tree().process_frame
	
	# Temporarily disable our normal navigation
	var was_processing = is_processing()
	set_process(false)
	
	# Current selected item in the popup
	var current_item = current_selection
	var item_count = popup.item_count
	
	# Variables to control the delay of pressed keys
	var input_delay = 0.15  # seconds between each movement when held down
	var time_since_last_input = 0.0
	var is_holding_key = false
	
	# Handle popup navigation until it closes
	while popup.visible:
		var delta = get_process_delta_time()
		time_since_last_input += delta
		
		# Check if any navigation key is being pressed
		var up_pressed = FGGlobal.is_custom_action_pressed("up")
		var down_pressed = FGGlobal.is_custom_action_pressed("down")
		var accept_pressed = FGGlobal.is_custom_action_just_pressed("accept") or Input.is_action_just_pressed("ui_accept")
		var back_pressed = FGGlobal.is_custom_action_just_pressed("back") or Input.is_action_just_pressed("ui_cancel")
		
		# Navigate up
		if (up_pressed and (FGGlobal.is_custom_action_just_pressed("up") or time_since_last_input >= input_delay)):
			current_item = (current_item - 1 + item_count) % item_count
			
			# Skip disabled items
			var attempts = 0
			while attempts < item_count and popup.is_item_disabled(current_item):
				current_item = (current_item - 1 + item_count) % item_count
				attempts += 1
			
			# Visually highlight the current item
			popup.set_focused_item(current_item)
			
			time_since_last_input = 0.0
			is_holding_key = true
			_play_navigation_sound()
		
		# Navigate down
		elif (down_pressed and (FGGlobal.is_custom_action_just_pressed("down") or time_since_last_input >= input_delay)):
			current_item = (current_item + 1) % item_count
			
			# Skip disabled items
			var attempts = 0
			while attempts < item_count and popup.is_item_disabled(current_item):
				current_item = (current_item + 1) % item_count
				attempts += 1
			
			# Visually highlight the current item
			popup.set_focused_item(current_item)
			
			time_since_last_input = 0.0
			is_holding_key = true
			_play_navigation_sound()
		
		# Reset the counter if no key is being pressed
		if not up_pressed and not down_pressed:
			is_holding_key = false
			time_since_last_input = 0.0
		
		# Select the item
		if accept_pressed:
			# Verify that the item is not disabled
			if not popup.is_item_disabled(current_item):
				# Close the popup
				popup.hide()
				
				# Manually select the item
				option_button.selected = current_item
				
				# Manually emit the item_selected signal
				if option_button.has_signal("item_selected"):
					option_button.item_selected.emit(current_item)
				
			break
		
		# Cancel selection
		if back_pressed:
			popup.hide()
			break
		
		await get_tree().process_frame
	
	# Re-enable our normal processing
	set_process(was_processing)
	
	# Restore focus to the option button
	_update_focus()
	


func _update_focus() -> void:
	# Reset all nodes to their original state
	for node in interactuable_nodes:
		if is_instance_valid(node) and node is Control:
			node.modulate = Color.WHITE
			if node.has_method("release_focus"):
				node.release_focus()
	
	# Highlight and focus the current node
	if interactuable_nodes.size() > 0 and current_button_index < interactuable_nodes.size():
		var current_node = interactuable_nodes[current_button_index]
		if is_instance_valid(current_node) and current_node is Control:
			if not is_editing_text:
				current_node.modulate = highlight_color
			if current_node.has_method("grab_focus") and not is_editing_text:
				current_node.grab_focus()


# Modify the _interact_with_control function to include VSlider
func _interact_with_control(node: Node) -> void:
	if node is BaseButton:
		if node is CheckButton or node is CheckBox:
			node.button_pressed = !node.button_pressed
			# Emit the toggled signal
			if node.has_signal("toggled"):
				node.toggled.emit(node.button_pressed)
		elif node is OptionButton:
			# For OptionButton, handle the selection manually
			_handle_option_button(node)
		else:
			# For regular buttons
			if node.has_signal("pressed"):
				node.pressed.emit()
	
	elif node is HSlider or node is VSlider:  # Modified to include VSlider
		# Enter slider adjustment mode
		is_adjusting_slider = true
		# Visual feedback that we are adjusting this slider
		node.modulate = Color(1.5, 1.5, 0.5, 1)
	
	elif node is TextEdit or node is LineEdit:
		# Enter text editing mode
		is_editing_text = true
		node.grab_focus()
		
		# Visual feedback that we are editing this field
		node.modulate = Color(0.5, 1.5, 0.5, 1)

# Add function to force external update
func force_refresh_from_external():
	"""Allows updating the list from external scripts"""
	refresh_interactables()



func _handle_linear_navigation() -> void:
	if FGGlobal.is_custom_action_just_pressed("down") or FGGlobal.is_custom_action_just_pressed("right"):
		_move_selection(1)
	elif FGGlobal.is_custom_action_just_pressed("up") or FGGlobal.is_custom_action_just_pressed("left"):
		_move_selection(-1)

func _handle_grid_navigation() -> void:
	@warning_ignore("integer_division")
	var row = current_button_index / grid_columns
	var col = current_button_index % grid_columns
	var rows = ceil(float(interactuable_nodes.size()) / grid_columns)
	var new_index = current_button_index
	
	if FGGlobal.is_custom_action_just_pressed("right"):
		# Move right
		var attempts = 0
		while attempts < grid_columns:
			attempts += 1
			if col < grid_columns - 1 and new_index + 1 < interactuable_nodes.size():
				new_index += 1
				col += 1
			elif wrap_selection:
				new_index = row * grid_columns
				col = 0
			else:
				break
				
			if _is_node_usable(interactuable_nodes[new_index]):
				current_button_index = new_index
				break
	
	elif FGGlobal.is_custom_action_just_pressed("left"):
		# Move left
		var attempts = 0
		while attempts < grid_columns:
			attempts += 1
			if col > 0:
				new_index -= 1
				col -= 1
			elif wrap_selection:
				col = grid_columns - 1
				new_index = min(row * grid_columns + col, interactuable_nodes.size() - 1)
			else:
				break
				
			if _is_node_usable(interactuable_nodes[new_index]):
				current_button_index = new_index
				break
	
	elif FGGlobal.is_custom_action_just_pressed("down"):
		# Move down
		var attempts = 0
		while attempts < rows:
			attempts += 1
			if row < rows - 1 and new_index + grid_columns < interactuable_nodes.size():
				new_index += grid_columns
				row += 1
			elif wrap_selection:
				new_index = col
				row = 0
			else:
				break
				
			# Ensure we don't go out of bounds
			if new_index >= interactuable_nodes.size():
				if wrap_selection:
					new_index = col
					row = 0
				else:
					# Find the last valid index in this column
					new_index = interactuable_nodes.size() - 1
					while new_index >= 0 and new_index % grid_columns != col:
						new_index -= 1
					if new_index < 0:
							break
			
			if _is_node_usable(interactuable_nodes[new_index]):
				current_button_index = new_index
				break
	
	elif FGGlobal.is_custom_action_just_pressed("up"):
		# Move up
		var attempts = 0
		while attempts < rows:
			attempts += 1
			if row > 0:
				new_index -= grid_columns
				row -= 1
			elif wrap_selection:
				row = rows - 1
				new_index = min(row * grid_columns + col, interactuable_nodes.size() - 1)
			else:
				break
				
			if new_index >= 0 and _is_node_usable(interactuable_nodes[new_index]):
				current_button_index = new_index
				break


func _handle_slider_adjustment(slider) -> void:
	if FGGlobal.is_custom_action_just_pressed("accept") or FGGlobal.is_custom_action_just_pressed("back"):
		# Exit slider adjustment mode
		is_adjusting_slider = false
		_update_focus()
		return
		
	var value_changed = false
	var new_value = slider.value
	
	if slider is HSlider:
		# Horizontal navigation for HSlider
		if FGGlobal.is_custom_action_just_pressed("right") or FGGlobal.is_custom_action_pressed("right"):
			new_value = min(slider.value + slider_step, slider.max_value)
			value_changed = true
		elif FGGlobal.is_custom_action_just_pressed("left") or FGGlobal.is_custom_action_pressed("left"):
			new_value = max(slider.value - slider_step, slider.min_value)
			value_changed = true
	elif slider is VSlider:
		# Vertical navigation for VSlider - FIXED
		# up increases the value, down decreases it (standard VSlider behavior)
		if FGGlobal.is_custom_action_just_pressed("up") or FGGlobal.is_custom_action_pressed("up"):
			new_value = min(slider.value + slider_step, slider.max_value)
			value_changed = true
		elif FGGlobal.is_custom_action_just_pressed("down") or FGGlobal.is_custom_action_pressed("down"):
			new_value = max(slider.value - slider_step, slider.min_value)
			value_changed = true
	
	if value_changed and new_value != slider.value:
		slider.value = new_value
		# Emit the value_changed signal
		if slider.has_signal("value_changed"):
			slider.value_changed.emit(new_value)




func _find_next_enabled_item(popup: PopupMenu, current: int) -> int:
	var item_count = popup.item_count
	var next_item = (current + 1) % item_count
	var attempts = 0
	
	while attempts < item_count and popup.is_item_disabled(next_item):
		next_item = (next_item + 1) % item_count
		attempts += 1
	
	return next_item if attempts < item_count else current

func _find_previous_enabled_item(popup: PopupMenu, current: int) -> int:
	var item_count = popup.item_count
	var prev_item = (current - 1 + item_count) % item_count
	var attempts = 0
	
	while attempts < item_count and popup.is_item_disabled(prev_item):
		prev_item = (prev_item - 1 + item_count) % item_count
		attempts += 1
	
	return prev_item if attempts < item_count else current




func _is_node_usable(node: Node) -> bool:
	# Check if the node is still valid
	if not is_instance_valid(node):
		return false
		
	# Check if it is a Control
	if not node is Control:
		return false
		
	var control = node as Control
	
	# Check if the node is still in the scene tree
	if not control.is_inside_tree():
		return false
	
	# Check if the node is visible
	if not control.visible:
		return false
		
	# Check if the node is completely transparent
	if control.modulate.a <= 0.01:
		return false
		
	# Check if the node is disabled (if it has that property)
	if control.has_method("is_disabled") and control.is_disabled():
		return false
	
	# For buttons
	if control is BaseButton and control.disabled:
		return false
	
	# Check if any parent is invisible
	var parent = control.get_parent()
	while is_instance_valid(parent):
		if parent is Control and (not parent.visible or parent.modulate.a <= 0.01):
			return false
		parent = parent.get_parent()
	
	return true

func refresh_interactables() -> void:
	# Get the group name from FGGlobal
	var group_name = "interactuable"  # default value
	if FGGlobal and FGGlobal.has_method("get_interactable_group_name"):
		group_name = FGGlobal.get_interactable_group_name()
	
	# Get all nodes in the specified group
	var all_nodes = get_tree().get_nodes_in_group(group_name)
	
	# Filter invalid nodes
	interactuable_nodes.clear()
	for node in all_nodes:
		if is_instance_valid(node) and _is_node_usable(node):
			interactuable_nodes.append(node)
	
	# Store original colors
	original_colors.clear()
	for node in interactuable_nodes:
		if is_instance_valid(node) and node is Control:
			original_colors[node] = node.modulate
	
	# Reset current index if necessary
	if interactuable_nodes.size() > 0:
		if current_button_index >= interactuable_nodes.size():
			current_button_index = 0
		_update_focus()
	else:
		current_button_index = 0
	
	# Update the node count using the customizable group
	last_node_count = get_tree().get_nodes_in_group(group_name).size()

func _move_selection(direction: int) -> void:
	var new_index = current_button_index
	var attempts = 0
	var max_attempts = interactuable_nodes.size() * 2  # Prevent infinite loops
	
	while attempts < max_attempts:
		attempts += 1
		
		if wrap_selection:
			new_index = (new_index + direction + interactuable_nodes.size()) % interactuable_nodes.size()
		else:
			new_index = clamp(new_index + direction, 0, interactuable_nodes.size() - 1)
			
			# If we reach the edge and can't move anymore, stop
			if (direction > 0 and new_index == interactuable_nodes.size() - 1) or \
			   (direction < 0 and new_index == 0):
				break
		
		# If we have returned to the starting point, stop
		if new_index == current_button_index:
			break
			
		# If we find a usable node, use it
		if _is_node_usable(interactuable_nodes[new_index]):
			current_button_index = new_index
			break

func _play_navigation_sound() -> void:
	if navigation_sound:
		navigation_sound.play()

func _check_visibility_changes() -> void:
	var visible_nodes = _get_visible_interactables()
	
	# If the current selection is no longer valid, we need to update
	if interactuable_nodes.size() > 0 and current_button_index < interactuable_nodes.size():
		var current_node = interactuable_nodes[current_button_index]
		if not is_instance_valid(current_node) or not _is_node_usable(current_node) or not visible_nodes.has(current_node):
			# Our current selection is no longer valid, refresh the list
			refresh_interactables()
	
	# If the visible node count has changed, refresh the list
	if visible_nodes.size() != interactuable_nodes.size():
		refresh_interactables()

func _get_visible_interactables() -> Array[Node]:
	var visible_nodes: Array[Node] = []
	var group_name = "interactuable"  # default value
	if FGGlobal and FGGlobal.has_method("get_interactable_group_name"):
		group_name = FGGlobal.get_interactable_group_name()
	
	var all_nodes = get_tree().get_nodes_in_group(group_name)
	
	for node in all_nodes:
		if _is_node_usable(node):
			visible_nodes.append(node)
	
	return visible_nodes

func select_specific_node(node: Control) -> void:
	var group_name = "interactuable"  # default value
	if FGGlobal and FGGlobal.has_method("get_interactable_group_name"):
		group_name = FGGlobal.get_interactable_group_name()
	
	if node.is_in_group(group_name) and _is_node_usable(node):
		var index = interactuable_nodes.find(node)
		if index != -1:
			current_button_index = index
			_update_focus()

func register_new_scene(scene_root: Node) -> void:
	# Ensure the scene root is valid
	if not is_instance_valid(scene_root):
		return
		
	# Wait two frames to ensure all children are initialized
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Check again if scene_root is still valid after waiting
	if not is_instance_valid(scene_root):
		return
		
	# Refresh the list of interactable nodes
	refresh_interactables()
	
	# Find the first interactable in this scene
	var first_interactable = _find_first_interactable_in_scene(scene_root)
	if first_interactable != null:
		select_specific_node(first_interactable)

func _find_first_interactable_in_scene(scene_root: Node) -> Control:
	# Ensure the scene root is valid
	if not is_instance_valid(scene_root):
		return null
	
	var group_name = "interactuable"  # default value
	if FGGlobal and FGGlobal.has_method("get_interactable_group_name"):
		group_name = FGGlobal.get_interactable_group_name()
		
	# Get all interactable nodes
	var all_interactables = get_tree().get_nodes_in_group(group_name)
	
	# Filter to include only valid nodes that are descendants of scene_root
	for node in all_interactables:
		if is_instance_valid(node) and node is Control and _is_node_usable(node):
			# Check if the node is a descendant of scene_root
			var parent = node
			while is_instance_valid(parent):
				if parent == scene_root:
					return node
				parent = parent.get_parent()
		
	return null

func _on_node_added(node: Node) -> void:
	var group_name = "interactuable"  # default value
	if FGGlobal and FGGlobal.has_method("get_interactable_group_name"):
		group_name = FGGlobal.get_interactable_group_name()
	
	# When a node is added to the scene tree, check if it is in the interactable group
	# or if it could contain interactable nodes
	if node.is_in_group(group_name):
		# A new interactable node was added directly
		call_deferred("refresh_interactables")
	elif node is Control:
		# This is a control that could contain interactable nodes
		# Wait one frame for it to fully initialize
		call_deferred("_check_for_new_interactables")

func _check_for_new_interactables() -> void:
	var group_name = "interactuable"  # default value
	if FGGlobal and FGGlobal.has_method("get_interactable_group_name"):
		group_name = FGGlobal.get_interactable_group_name()
	
	var current_count = get_tree().get_nodes_in_group(group_name).size()
	if current_count != last_node_count:
		refresh_interactables()
		last_node_count = current_count

func _on_refresh_timer_timeout() -> void:
	_check_for_new_interactables()

func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	if connected:
		pass
	else:
		pass
