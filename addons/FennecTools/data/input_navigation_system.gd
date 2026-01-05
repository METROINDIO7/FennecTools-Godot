extends Node

# Sistema de navegación mejorado con detección espacial real
# Ahora los botones se navegan según su posición visual en pantalla

var current_button_index: int = 0
var interactuable_nodes: Array[Node] = []
var navigation_sound: AudioStreamPlayer

# Configuration
@export var wrap_selection: bool = true
@export var highlight_color: Color = Color.ALICE_BLUE
@export var navigation_sound_path: String = ""
@export var slider_step: float = 1.5
@export var auto_refresh_enabled: bool = false
@export var auto_refresh_interval: float = 1.0
@export var debug_mode: bool = false

# 🆕 NUEVA CONFIGURACIÓN: Navegación espacial
@export var spatial_navigation: bool = true  # Activar navegación por posición real
@export var directional_tolerance: float = 0.3  # Tolerancia angular (0-1, más bajo = más estricto)
@export var prefer_closest: bool = true  # Priorizar el nodo más cercano

# States
var original_colors: Dictionary = {}
var is_adjusting_slider: bool = false
var is_editing_text: bool = false
var refresh_timer: Timer
var last_node_count: int = 0
var is_refreshing: bool = false
var refresh_scheduled: bool = false
var interaction_lock: bool = false
var last_refresh_time: float = 0.0
var min_refresh_interval: float = 0.2

# Signals
signal selection_changed(node: Control)

func _ready():
	current_button_index = 0
	interactuable_nodes.clear()
	original_colors.clear()
	is_refreshing = false
	refresh_scheduled = false
	interaction_lock = false
	is_adjusting_slider = false
	is_editing_text = false
	last_node_count = 0
	
	if not FGGlobal or not FGGlobal.input_control_enabled:
		return
		
	process_mode = Node.PROCESS_MODE_ALWAYS
	refresh_interactables()
	
	if navigation_sound_path:
		navigation_sound = AudioStreamPlayer.new()
		add_child(navigation_sound)
		navigation_sound.stream = load(navigation_sound_path)
		navigation_sound.volume_db = -10
	
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	
	if auto_refresh_enabled:
		refresh_timer = Timer.new()
		add_child(refresh_timer)
		refresh_timer.wait_time = auto_refresh_interval
		refresh_timer.timeout.connect(_on_refresh_timer_timeout)
		refresh_timer.start()
	
	get_tree().node_added.connect(_on_node_added)
	last_node_count = get_tree().get_nodes_in_group("interactuable").size()

func _process(delta: float) -> void:
	if not FGGlobal or not FGGlobal.input_control_enabled:
		return
	
	if is_refreshing or interaction_lock:
		return
	
	var accept_just_pressed = FGGlobal.is_custom_action_just_pressed("accept")
	
	var interaction_node_snapshot = null
	var interaction_index_snapshot = -1
	
	if accept_just_pressed and interactuable_nodes.size() > 0 and current_button_index < interactuable_nodes.size():
		interaction_node_snapshot = interactuable_nodes[current_button_index]
		interaction_index_snapshot = current_button_index
		if debug_mode:
			print("[Navigation] 📸 Snapshot capturado: ", interaction_node_snapshot.name, " at index ", interaction_index_snapshot)
	
	_check_visibility_changes()
	
	if interactuable_nodes.size() == 0:
		return
	
	if current_button_index >= interactuable_nodes.size():
		current_button_index = 0
		_update_focus()
		return
	
	var current_node = interactuable_nodes[current_button_index]
	
	if not is_instance_valid(current_node) or not _is_node_usable(current_node):
		_safe_refresh_with_selection_recovery()
		return
	
	if is_editing_text and (current_node is TextEdit or current_node is LineEdit):
		_handle_text_editing(current_node)
		return
	
	if is_adjusting_slider and (current_node is HSlider or current_node is VSlider):
		_handle_slider_adjustment(current_node)
		return
	
	var old_index = current_button_index
	
	# 🆕 NAVEGACIÓN ESPACIAL O LINEAL
	if spatial_navigation:
		_handle_spatial_navigation()
	else:
		_handle_linear_navigation()
	
	if old_index != current_button_index:
		_play_navigation_sound()
		_update_focus()
		
		if current_button_index < interactuable_nodes.size():
			selection_changed.emit(interactuable_nodes[current_button_index])
	
	if accept_just_pressed and is_instance_valid(interaction_node_snapshot):
		if debug_mode:
			print("[Navigation] 🎯 Ejecutando interacción con snapshot capturado")
		_safe_interact_with_control_snapshot(interaction_node_snapshot, interaction_index_snapshot)

# 🆕 NUEVA FUNCIÓN: Navegación basada en posición espacial real
func _handle_spatial_navigation() -> void:
	if not interactuable_nodes.size() > 0 or current_button_index >= interactuable_nodes.size():
		return
	
	var current_node = interactuable_nodes[current_button_index]
	if not is_instance_valid(current_node) or not current_node is Control:
		return
	
	var current_pos = _get_node_center_position(current_node)
	var direction = Vector2.ZERO
	
	# Detectar dirección del input
	if FGGlobal.is_custom_action_just_pressed("up"):
		direction = Vector2.UP
	elif FGGlobal.is_custom_action_just_pressed("down"):
		direction = Vector2.DOWN
	elif FGGlobal.is_custom_action_just_pressed("left"):
		direction = Vector2.LEFT
	elif FGGlobal.is_custom_action_just_pressed("right"):
		direction = Vector2.RIGHT
	else:
		return
	
	if debug_mode:
		print("[Navigation] 🧭 Navegando desde '", current_node.name, "' hacia ", _direction_to_string(direction))
	
	# Buscar el mejor candidato en esa dirección
	var best_candidate = _find_best_spatial_candidate(current_node, current_pos, direction)
	
	if best_candidate != -1:
		current_button_index = best_candidate
		if debug_mode:
			print("[Navigation] ✅ Nuevo nodo: '", interactuable_nodes[current_button_index].name, "'")
	else:
		if debug_mode:
			print("[Navigation] ⚠️ No se encontró candidato en esa dirección")

# 🆕 Encuentra el mejor nodo en una dirección específica
func _find_best_spatial_candidate(from_node: Control, from_pos: Vector2, direction: Vector2) -> int:
	var best_index = -1
	var best_score = INF
	
	for i in range(interactuable_nodes.size()):
		if i == current_button_index:
			continue
		
		var candidate = interactuable_nodes[i]
		if not _is_node_usable(candidate) or not candidate is Control:
			continue
		
		var candidate_pos = _get_node_center_position(candidate)
		var to_candidate = candidate_pos - from_pos
		
		# Verificar si está en la dirección correcta
		var dot_product = direction.dot(to_candidate.normalized())
		
		# Solo considerar nodos que estén en la dirección general correcta
		# dot_product > 0 significa que está adelante en esa dirección
		var min_alignment = 1.0 - directional_tolerance
		if dot_product < min_alignment:
			continue
		
		# Calcular score: combina distancia y alineación
		var distance = from_pos.distance_to(candidate_pos)
		var alignment_bonus = dot_product * 100  # Favorece mejor alineación
		var score = distance - alignment_bonus
		
		if debug_mode:
			print("  Candidato '", candidate.name, "': dist=", "%.1f" % distance, 
				  ", align=", "%.2f" % dot_product, ", score=", "%.1f" % score)
		
		if score < best_score:
			best_score = score
			best_index = i
	
	return best_index

# 🆕 Obtiene la posición central de un nodo en coordenadas globales
func _get_node_center_position(node: Control) -> Vector2:
	if not is_instance_valid(node):
		return Vector2.ZERO
	
	# Obtener posición global del centro del nodo
	var global_rect = node.get_global_rect()
	return global_rect.get_center()

# 🆕 Helper para debug
func _direction_to_string(dir: Vector2) -> String:
	if dir == Vector2.UP: return "ARRIBA"
	if dir == Vector2.DOWN: return "ABAJO"
	if dir == Vector2.LEFT: return "IZQUIERDA"
	if dir == Vector2.RIGHT: return "DERECHA"
	return "DESCONOCIDO"

func _safe_interact_with_control_snapshot(node_snapshot: Node, index_snapshot: int) -> void:
	interaction_lock = true
	
	if debug_mode:
		print("[Navigation] 🔐 Lock activado para interacción")
	
	if not is_instance_valid(node_snapshot):
		print("[Navigation] ❌ ERROR: Snapshot node is invalid")
		interaction_lock = false
		return
	
	if not _is_node_usable(node_snapshot):
		print("[Navigation] ❌ ERROR: Snapshot node is not usable")
		interaction_lock = false
		return
	
	if index_snapshot < 0 or index_snapshot >= interactuable_nodes.size():
		print("[Navigation] ❌ ERROR: Index snapshot out of bounds")
		interaction_lock = false
		return
	
	var current_node_at_index = interactuable_nodes[index_snapshot]
	
	if node_snapshot != current_node_at_index:
		print("[Navigation] ⚠️ WARNING: Node changed during interaction!")
		var new_index = interactuable_nodes.find(node_snapshot)
		if new_index != -1:
			current_button_index = new_index
			_update_focus()
			_interact_with_control(node_snapshot)
		
		interaction_lock = false
		return
	
	if debug_mode:
		print("[Navigation] ✅ Snapshot validation passed")
	
	_interact_with_control(node_snapshot)
	
	await get_tree().process_frame
	interaction_lock = false
	
	if debug_mode:
		print("[Navigation] 🔓 Lock liberado")

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
	for node in interactuable_nodes:
		if is_instance_valid(node) and node is Control:
			if original_colors.has(node):
				node.modulate = original_colors[node]
			else:
				node.modulate = Color.WHITE
			
			if node.has_method("release_focus"):
				node.release_focus()
	
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
	
	if control.modulate.a <= 0.0:
		return false
		
	if control.has_method("is_disabled") and control.is_disabled():
		return false
	
	if control is BaseButton and control.disabled:
		return false
	
	var parent = control.get_parent()
	var parent_checks = 0
	var max_parent_checks = 3
	
	while is_instance_valid(parent) and parent_checks < max_parent_checks:
		if parent is Control:
			if not parent.visible:
				return false
			if parent.modulate.a <= 0.0:
				return false
		parent = parent.get_parent()
		parent_checks += 1
	
	return true

func _safe_refresh_with_selection_recovery():
	if is_refreshing:
		refresh_scheduled = true
		return
	
	var previous_node = null
	if current_button_index < interactuable_nodes.size():
		previous_node = interactuable_nodes[current_button_index]
	
	refresh_interactables()
	
	if is_instance_valid(previous_node) and previous_node in interactuable_nodes:
		current_button_index = interactuable_nodes.find(previous_node)
		_update_focus()
	
	if refresh_scheduled:
		refresh_scheduled = false
		call_deferred("_safe_refresh_with_selection_recovery")

func refresh_interactables() -> void:
	if is_refreshing:
		refresh_scheduled = true
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_refresh_time < min_refresh_interval:
		if debug_mode:
			print("[Navigation] ⏱️ Refresh bloqueado por throttling")
		refresh_scheduled = true
		return
	
	is_refreshing = true
	last_refresh_time = current_time
	
	if debug_mode:
		print("[Navigation] 🔄 Iniciando refresh...")
	
	var group_name = "interactuable"
	if FGGlobal and FGGlobal.has_method("get_interactable_group_name"):
		group_name = FGGlobal.get_interactable_group_name()
	
	var all_nodes = get_tree().get_nodes_in_group(group_name)
	
	var old_count = interactuable_nodes.size()
	interactuable_nodes.clear()
	
	for node in all_nodes:
		if is_instance_valid(node) and _is_node_usable(node):
			interactuable_nodes.append(node)
	
	if debug_mode:
		print("[Navigation] ✅ Nodos usables: ", interactuable_nodes.size())
	
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
	if interaction_lock:
		return
	_check_for_new_interactables()

func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	pass

func _exit_tree() -> void:
	if debug_mode:
		print("[Navigation] 🧹 Iniciando limpieza completa...")
	
	for node in original_colors:
		if is_instance_valid(node) and node is Control:
			node.modulate = original_colors[node]
			if node.has_method("release_focus"):
				node.release_focus()
	
	for node in interactuable_nodes:
		if is_instance_valid(node) and node is Control:
			if original_colors.has(node):
				node.modulate = original_colors[node]
			else:
				node.modulate = Color.WHITE
			if node.has_method("release_focus"):
				node.release_focus()
	
	if is_instance_valid(refresh_timer):
		refresh_timer.stop()
		refresh_timer.queue_free()
	
	if is_instance_valid(navigation_sound):
		navigation_sound.stop()
		navigation_sound.queue_free()
	
	is_refreshing = false
	refresh_scheduled = false
	interaction_lock = false
	is_adjusting_slider = false
	is_editing_text = false
	
	interactuable_nodes.clear()
	original_colors.clear()
	
	current_button_index = 0
	last_node_count = 0
	last_refresh_time = 0.0
	
	if FGGlobal:
		FGGlobal.navigation_system = null
	
	print("[Navigation] ✅ Sistema completamente limpiado")
