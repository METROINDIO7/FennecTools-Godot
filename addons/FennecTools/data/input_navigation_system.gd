extends Node

# Sistema de navegación mejorado con protección contra bugs de sincronización
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
var is_editing_text: bool = false
var refresh_timer: Timer
var last_node_count: int = 0

# 🔒 PROTECCIÓN CONTRA BUGS
var is_refreshing: bool = false  # Previene refresh concurrente
var refresh_scheduled: bool = false  # Para diferir refresh si está ocupado
var interaction_lock: bool = false  # Previene interacción durante cambios

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
	
	# 🔒 No procesar input si estamos en medio de un refresh
	if is_refreshing or interaction_lock:
		return
		
	# Check for visibility changes
	_check_visibility_changes()
	
	if interactuable_nodes.size() == 0:
		return
	
	# 🔒 VALIDACIÓN: Verificar que el índice actual es válido
	if current_button_index >= interactuable_nodes.size():
		current_button_index = 0
		_update_focus()
		return
	
	var current_node = interactuable_nodes[current_button_index]
	
	# 🔒 VALIDACIÓN: Verificar que el nodo actual es válido
	if not is_instance_valid(current_node) or not _is_node_usable(current_node):
		_safe_refresh_with_selection_recovery()
		return
	
	if is_editing_text and (current_node is TextEdit or current_node is LineEdit):
		_handle_text_editing(current_node)
		return
	
	if is_adjusting_slider and (current_node is HSlider or current_node is VSlider):
		_handle_slider_adjustment(current_node)
		return
	
	# 🔒 CRÍTICO: Capturar el nodo ANTES de procesar input para evitar race conditions
	var node_snapshot = current_node
	var index_snapshot = current_button_index
		
	# Handle normal navigation
	var old_index = current_button_index
	
	if grid_navigation:
		_handle_grid_navigation()
	else:
		_handle_linear_navigation()
	
	# Only update focus if the selection changed
	if old_index != current_button_index:
		_play_navigation_sound()
		_update_focus()
		
		if current_button_index < interactuable_nodes.size():
			selection_changed.emit(interactuable_nodes[current_button_index])
		
		# Actualizar snapshot si cambió la selección
		if current_button_index < interactuable_nodes.size():
			node_snapshot = interactuable_nodes[current_button_index]
			index_snapshot = current_button_index
	
	# 🔒 CRÍTICO: Usar el snapshot capturado para interacción
	if FGGlobal.is_custom_action_just_pressed("accept"):
		_safe_interact_with_control_snapshot(node_snapshot, index_snapshot)

# 🔒 NUEVA FUNCIÓN: Interacción segura con snapshot del nodo
func _safe_interact_with_control_snapshot(node_snapshot: Node, index_snapshot: int) -> void:
	# Bloquear INMEDIATAMENTE para prevenir refreshes durante interacción
	interaction_lock = true
	
	# Verificar que el snapshot del nodo es válido
	if not is_instance_valid(node_snapshot):
		print("[Navigation] ❌ ERROR: Snapshot node is invalid")
		interaction_lock = false
		return
	
	# Verificar que el índice no ha cambiado (detectar refresh durante navegación)
	if index_snapshot >= interactuable_nodes.size():
		print("[Navigation] ❌ ERROR: Index snapshot out of bounds (", index_snapshot, " >= ", interactuable_nodes.size(), ")")
		interaction_lock = false
		return
	
	# Verificar que el nodo en el snapshot sigue siendo el mismo
	var current_node_at_index = interactuable_nodes[index_snapshot]
	if node_snapshot != current_node_at_index:
		print("[Navigation] ⚠️ WARNING: Node changed during interaction!")
		print("  Snapshot node: ", node_snapshot.name)
		print("  Current node at index: ", current_node_at_index.name if is_instance_valid(current_node_at_index) else "invalid")
		
		# Buscar el nodo snapshot en la lista actual
		var new_index = interactuable_nodes.find(node_snapshot)
		if new_index != -1:
			print("[Navigation] ✓ Found snapshot node at new index: ", new_index)
			current_button_index = new_index
			_update_focus()
			# Usar el snapshot node original
			_interact_with_control(node_snapshot)
		else:
			print("[Navigation] ❌ ERROR: Snapshot node no longer in list!")
		
		interaction_lock = false
		return
	
	# Verificar que current_button_index coincide con index_snapshot
	if current_button_index != index_snapshot:
		print("[Navigation] ⚠️ WARNING: Index mismatch!")
		print("  Snapshot index: ", index_snapshot)
		print("  Current index: ", current_button_index)
		# Sincronizar con el snapshot
		current_button_index = index_snapshot
		_update_focus()
	
	# TODO: Verificación final - el nodo debe estar visible y usable
	if not _is_node_usable(node_snapshot):
		print("[Navigation] ❌ ERROR: Snapshot node is not usable")
		interaction_lock = false
		return
	
	# ✅ Todas las verificaciones pasadas - ejecutar interacción
	print("[Navigation] ✓ Interacting with: ", node_snapshot.name, " at index ", index_snapshot)
	_interact_with_control(node_snapshot)
	
	# Desbloquear después de un frame para asegurar que la interacción se complete
	await get_tree().process_frame
	interaction_lock = false

# 🔒 NUEVA FUNCIÓN: Interacción segura con validaciones
func _safe_interact_with_control(node: Node) -> void:
	# Verificar que el nodo es válido antes de interactuar
	if not is_instance_valid(node):
		print("[Navigation] WARNING: Attempted to interact with invalid node")
		return
	
	# Verificar que el nodo está en el índice correcto
	if current_button_index >= interactuable_nodes.size():
		print("[Navigation] WARNING: Index out of bounds during interaction")
		return
	
	# Verificar que es el nodo correcto
	if interactuable_nodes[current_button_index] != node:
		print("[Navigation] WARNING: Node mismatch during interaction!")
		print("  Expected: ", node.name if is_instance_valid(node) else "invalid")
		print("  Got: ", interactuable_nodes[current_button_index].name)
		# Intentar sincronizar
		_update_focus()
		return
	
	# Bloquear interacciones durante el proceso
	interaction_lock = true
	_interact_with_control(node)
	interaction_lock = false

func _handle_text_editing(text_node: Control) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		is_editing_text = false
		text_node.release_focus()
		_update_focus()
		return

func _handle_option_button(option_button: OptionButton) -> void:
	var popup = option_button.get_popup()
	if not popup:
		return
	
	var current_selection = option_button.selected
	option_button.show_popup()
	await get_tree().process_frame
	
	var was_processing = is_processing()
	set_process(false)
	
	var current_item = current_selection
	var item_count = popup.item_count
	var input_delay = 0.15
	var time_since_last_input = 0.0
	
	while popup.visible:
		var delta = get_process_delta_time()
		time_since_last_input += delta
		
		var up_pressed = FGGlobal.is_custom_action_pressed("up")
		var down_pressed = FGGlobal.is_custom_action_pressed("down")
		var accept_pressed = FGGlobal.is_custom_action_just_pressed("accept") or Input.is_action_just_pressed("ui_accept")
		var back_pressed = FGGlobal.is_custom_action_just_pressed("back") or Input.is_action_just_pressed("ui_cancel")
		
		if (up_pressed and (FGGlobal.is_custom_action_just_pressed("up") or time_since_last_input >= input_delay)):
			current_item = (current_item - 1 + item_count) % item_count
			var attempts = 0
			while attempts < item_count and popup.is_item_disabled(current_item):
				current_item = (current_item - 1 + item_count) % item_count
				attempts += 1
			popup.set_focused_item(current_item)
			time_since_last_input = 0.0
			_play_navigation_sound()
		
		elif (down_pressed and (FGGlobal.is_custom_action_just_pressed("down") or time_since_last_input >= input_delay)):
			current_item = (current_item + 1) % item_count
			var attempts = 0
			while attempts < item_count and popup.is_item_disabled(current_item):
				current_item = (current_item + 1) % item_count
				attempts += 1
			popup.set_focused_item(current_item)
			time_since_last_input = 0.0
			_play_navigation_sound()
		
		if not up_pressed and not down_pressed:
			time_since_last_input = 0.0
		
		if accept_pressed:
			if not popup.is_item_disabled(current_item):
				popup.hide()
				option_button.selected = current_item
				if option_button.has_signal("item_selected"):
					option_button.item_selected.emit(current_item)
			break
		
		if back_pressed:
			popup.hide()
			break
		
		await get_tree().process_frame
	
	set_process(was_processing)
	_update_focus()

func _update_focus() -> void:
	# Reset all nodes
	for node in interactuable_nodes:
		if is_instance_valid(node) and node is Control:
			node.modulate = Color.WHITE
			if node.has_method("release_focus"):
				node.release_focus()
	
	# Highlight current node
	if interactuable_nodes.size() > 0 and current_button_index < interactuable_nodes.size():
		var current_node = interactuable_nodes[current_button_index]
		if is_instance_valid(current_node) and current_node is Control:
			if not is_editing_text:
				current_node.modulate = highlight_color
			if current_node.has_method("grab_focus") and not is_editing_text:
				current_node.grab_focus()

func _interact_with_control(node: Node) -> void:
	if node is BaseButton:
		if node is CheckButton or node is CheckBox:
			node.button_pressed = !node.button_pressed
			if node.has_signal("toggled"):
				node.toggled.emit(node.button_pressed)
		elif node is OptionButton:
			_handle_option_button(node)
		else:
			if node.has_signal("pressed"):
				node.pressed.emit()
	
	elif node is HSlider or node is VSlider:
		is_adjusting_slider = true
		node.modulate = Color(1.5, 1.5, 0.5, 1)
	
	elif node is TextEdit or node is LineEdit:
		is_editing_text = true
		node.grab_focus()
		node.modulate = Color(0.5, 1.5, 0.5, 1)

func force_refresh_from_external():
	_safe_refresh_with_selection_recovery()

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
				
			if new_index >= interactuable_nodes.size():
				if wrap_selection:
					new_index = col
					row = 0
				else:
					new_index = interactuable_nodes.size() - 1
					while new_index >= 0 and new_index % grid_columns != col:
						new_index -= 1
					if new_index < 0:
						break
			
			if _is_node_usable(interactuable_nodes[new_index]):
				current_button_index = new_index
				break
	
	elif FGGlobal.is_custom_action_just_pressed("up"):
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
		is_adjusting_slider = false
		_update_focus()
		return
		
	var value_changed = false
	var new_value = slider.value
	
	if slider is HSlider:
		if FGGlobal.is_custom_action_just_pressed("right") or FGGlobal.is_custom_action_pressed("right"):
			new_value = min(slider.value + slider_step, slider.max_value)
			value_changed = true
		elif FGGlobal.is_custom_action_just_pressed("left") or FGGlobal.is_custom_action_pressed("left"):
			new_value = max(slider.value - slider_step, slider.min_value)
			value_changed = true
	elif slider is VSlider:
		if FGGlobal.is_custom_action_just_pressed("up") or FGGlobal.is_custom_action_pressed("up"):
			new_value = min(slider.value + slider_step, slider.max_value)
			value_changed = true
		elif FGGlobal.is_custom_action_just_pressed("down") or FGGlobal.is_custom_action_pressed("down"):
			new_value = max(slider.value - slider_step, slider.min_value)
			value_changed = true
	
	if value_changed and new_value != slider.value:
		slider.value = new_value
		if slider.has_signal("value_changed"):
			slider.value_changed.emit(new_value)

func _is_node_usable(node: Node) -> bool:
	if not is_instance_valid(node):
		return false
		
	if not node is Control:
		return false
		
	var control = node as Control
	
	if not control.is_inside_tree():
		return false
	
	if not control.visible:
		return false
		
	if control.modulate.a <= 0.01:
		return false
		
	if control.has_method("is_disabled") and control.is_disabled():
		return false
	
	if control is BaseButton and control.disabled:
		return false
	
	var parent = control.get_parent()
	while is_instance_valid(parent):
		if parent is Control and (not parent.visible or parent.modulate.a <= 0.01):
			return false
		parent = parent.get_parent()
	
	return true

# 🔒 NUEVA FUNCIÓN: Refresh seguro con recuperación de selección
func _safe_refresh_with_selection_recovery():
	if is_refreshing:
		refresh_scheduled = true
		return
	
	# Guardar referencia al nodo actual
	var previous_node = null
	if current_button_index < interactuable_nodes.size():
		previous_node = interactuable_nodes[current_button_index]
	
	refresh_interactables()
	
	# Intentar recuperar la selección
	if is_instance_valid(previous_node) and previous_node in interactuable_nodes:
		current_button_index = interactuable_nodes.find(previous_node)
		_update_focus()
	
	# Procesar refresh programado si existe
	if refresh_scheduled:
		refresh_scheduled = false
		call_deferred("_safe_refresh_with_selection_recovery")

func refresh_interactables() -> void:
	# 🔒 Prevenir refresh concurrente
	if is_refreshing:
		refresh_scheduled = true
		return
	
	is_refreshing = true
	
	var group_name = "interactuable"
	if FGGlobal and FGGlobal.has_method("get_interactable_group_name"):
		group_name = FGGlobal.get_interactable_group_name()
	
	var all_nodes = get_tree().get_nodes_in_group(group_name)
	
	interactuable_nodes.clear()
	for node in all_nodes:
		if is_instance_valid(node) and _is_node_usable(node):
			interactuable_nodes.append(node)
	
	original_colors.clear()
	for node in interactuable_nodes:
		if is_instance_valid(node) and node is Control:
			original_colors[node] = node.modulate
	
	if interactuable_nodes.size() > 0:
		if current_button_index >= interactuable_nodes.size():
			current_button_index = 0
		_update_focus()
	else:
		current_button_index = 0
	
	last_node_count = get_tree().get_nodes_in_group(group_name).size()
	
	is_refreshing = false
	
	# Procesar refresh programado si existe
	if refresh_scheduled:
		refresh_scheduled = false
		call_deferred("refresh_interactables")

func _move_selection(direction: int) -> void:
	var new_index = current_button_index
	var attempts = 0
	var max_attempts = interactuable_nodes.size() * 2
	
	while attempts < max_attempts:
		attempts += 1
		
		if wrap_selection:
			new_index = (new_index + direction + interactuable_nodes.size()) % interactuable_nodes.size()
		else:
			new_index = clamp(new_index + direction, 0, interactuable_nodes.size() - 1)
			
			if (direction > 0 and new_index == interactuable_nodes.size() - 1) or \
			   (direction < 0 and new_index == 0):
				break
		
		if new_index == current_button_index:
			break
			
		if _is_node_usable(interactuable_nodes[new_index]):
			current_button_index = new_index
			break

func _play_navigation_sound() -> void:
	if navigation_sound:
		navigation_sound.play()

func _check_visibility_changes() -> void:
	# 🔒 No verificar durante refresh o durante interacción
	if is_refreshing or interaction_lock:
		return
		
	var visible_nodes = _get_visible_interactables()
	
	if interactuable_nodes.size() > 0 and current_button_index < interactuable_nodes.size():
		var current_node = interactuable_nodes[current_button_index]
		if not is_instance_valid(current_node) or not _is_node_usable(current_node) or not visible_nodes.has(current_node):
			_safe_refresh_with_selection_recovery()
	
	if visible_nodes.size() != interactuable_nodes.size():
		_safe_refresh_with_selection_recovery()

func _get_visible_interactables() -> Array[Node]:
	var visible_nodes: Array[Node] = []
	var group_name = "interactuable"
	if FGGlobal and FGGlobal.has_method("get_interactable_group_name"):
		group_name = FGGlobal.get_interactable_group_name()
	
	var all_nodes = get_tree().get_nodes_in_group(group_name)
	
	for node in all_nodes:
		if _is_node_usable(node):
			visible_nodes.append(node)
	
	return visible_nodes

func select_specific_node(node: Control) -> void:
	var group_name = "interactuable"
	if FGGlobal and FGGlobal.has_method("get_interactable_group_name"):
		group_name = FGGlobal.get_interactable_group_name()
	
	if node.is_in_group(group_name) and _is_node_usable(node):
		var index = interactuable_nodes.find(node)
		if index != -1:
			current_button_index = index
			_update_focus()

func register_new_scene(scene_root: Node) -> void:
	if not is_instance_valid(scene_root):
		return
		
	await get_tree().process_frame
	await get_tree().process_frame
	
	if not is_instance_valid(scene_root):
		return
		
	_safe_refresh_with_selection_recovery()
	
	var first_interactable = _find_first_interactable_in_scene(scene_root)
	if first_interactable != null:
		select_specific_node(first_interactable)

func _find_first_interactable_in_scene(scene_root: Node) -> Control:
	if not is_instance_valid(scene_root):
		return null
	
	var group_name = "interactuable"
	if FGGlobal and FGGlobal.has_method("get_interactable_group_name"):
		group_name = FGGlobal.get_interactable_group_name()
		
	var all_interactables = get_tree().get_nodes_in_group(group_name)
	
	for node in all_interactables:
		if is_instance_valid(node) and node is Control and _is_node_usable(node):
			var parent = node
			while is_instance_valid(parent):
				if parent == scene_root:
					return node
				parent = parent.get_parent()
		
	return null

func _on_node_added(node: Node) -> void:
	var group_name = "interactuable"
	if FGGlobal and FGGlobal.has_method("get_interactable_group_name"):
		group_name = FGGlobal.get_interactable_group_name()
	
	if node.is_in_group(group_name):
		call_deferred("_safe_refresh_with_selection_recovery")
	elif node is Control:
		call_deferred("_check_for_new_interactables")

func _check_for_new_interactables() -> void:
	var group_name = "interactuable"
	if FGGlobal and FGGlobal.has_method("get_interactable_group_name"):
		group_name = FGGlobal.get_interactable_group_name()
	
	var current_count = get_tree().get_nodes_in_group(group_name).size()
	if current_count != last_node_count:
		_safe_refresh_with_selection_recovery()
		last_node_count = current_count

func _on_refresh_timer_timeout() -> void:
	# 🔒 No refrescar durante interacciones
	if interaction_lock:
		return
	_check_for_new_interactables()

func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	pass
