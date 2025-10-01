extends Node

# Sistema de navegación mejorado integrado con FGGlobal
var current_button_index: int = 0
var interactuable_nodes: Array[Node] = []
var navigation_sound: AudioStreamPlayer

# Configuración
@export var wrap_selection: bool = true
@export var highlight_color: Color = Color.ALICE_BLUE
@export var navigation_sound_path: String = ""
@export var grid_navigation: bool = false
@export var grid_columns: int = 3
@export var slider_step: float = 1.5
@export var auto_refresh_enabled: bool = true
@export var auto_refresh_interval: float = 0.5

# Estados
var original_colors: Dictionary = {}
var is_adjusting_slider: bool = false
var is_editing_text: bool = false  # nuevo estado para campos de texto
var refresh_timer: Timer
var last_node_count: int = 0

# Señales
signal selection_changed(node: Control)

func _ready():
	if not FGGlobal or not FGGlobal.input_control_enabled:
		return
		
	process_mode = Node.PROCESS_MODE_ALWAYS
	refresh_interactables()
	
	
	# Configurar sonido de navegación
	if navigation_sound_path:
		navigation_sound = AudioStreamPlayer.new()
		add_child(navigation_sound)
		navigation_sound.stream = load(navigation_sound_path)
		navigation_sound.volume_db = -10
	
	# Conectar señales de controlador
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	
	# Configurar timer de auto-refresh
	if auto_refresh_enabled:
		refresh_timer = Timer.new()
		add_child(refresh_timer)
		refresh_timer.wait_time = auto_refresh_interval
		refresh_timer.timeout.connect(_on_refresh_timer_timeout)
		refresh_timer.start()
	
	# Conectar señales del árbol
	get_tree().node_added.connect(_on_node_added)
	last_node_count = get_tree().get_nodes_in_group("interactuable").size()

func _process(delta: float) -> void:
	# Verificar si el sistema está habilitado
	if not FGGlobal or not FGGlobal.input_control_enabled:
		return
		
	# Verificar cambios de visibilidad
	_check_visibility_changes()
	
	if interactuable_nodes.size() == 0:
		return
	
	var current_node = interactuable_nodes[current_button_index]
	
	if is_editing_text and (current_node is TextEdit or current_node is LineEdit):
		_handle_text_editing(current_node)
		return
	
	# Manejar modo de ajuste de slider
	if is_adjusting_slider and (current_node is HSlider or current_node is VSlider):
		_handle_slider_adjustment(current_node)
		return  # IMPORTANTE: return aquí evita que se procese navegación normal
		
	
	# Manejar navegación normal usando el sistema personalizado
	var old_index = current_button_index
	
	if grid_navigation:
		_handle_grid_navigation()
	else:
		_handle_linear_navigation()
	
	# Solo actualizar foco si la selección cambió
	if old_index != current_button_index:
		_play_navigation_sound()
		_update_focus()
		
		# Emitir señal con el nodo recién seleccionado
		if current_button_index < interactuable_nodes.size():
			selection_changed.emit(interactuable_nodes[current_button_index])
	
	# Manejar interacción con el control actual
	if FGGlobal.is_custom_action_just_pressed("accept"):
		_interact_with_control(current_node)




func _handle_text_editing(text_node: Control) -> void:
	# Solo ui_cancel puede salir del modo de edición de texto
	# Esto evita conflictos con teclas personalizadas como "Q" para retroceder
	if Input.is_action_just_pressed("ui_cancel"):
		is_editing_text = false
		text_node.release_focus()
		_update_focus()
		print("[Navigation] Saliendo del modo de edición de texto")
		return
	
	# El resto de la entrada se maneja normalmente por el TextEdit/LineEdit
	# No interceptamos otras teclas para permitir escritura normal




func _handle_option_button(option_button: OptionButton) -> void:
	# Obtener el menú popup
	var popup = option_button.get_popup()
	if not popup:
		return
		
	# Almacenar selección actual
	var current_selection = option_button.selected
	
	# Mostrar el popup
	option_button.show_popup()
	
	# Esperar a que aparezca el popup
	await get_tree().process_frame
	
	# Deshabilitar temporalmente nuestra navegación normal
	var was_processing = is_processing()
	set_process(false)
	
	# Elemento seleccionado actual en el popup
	var current_item = current_selection
	var item_count = popup.item_count
	
	# Manejar navegación del popup hasta que se cierre
	while popup.visible:
		await get_tree().process_frame
		
		# Navegar arriba/abajo en el popup
		if FGGlobal.is_custom_action_just_pressed("up"):
			current_item = (current_item - 1 + item_count) % item_count
			# Saltar elementos deshabilitados
			while current_item < item_count and popup.is_item_disabled(current_item):
				current_item = (current_item - 1 + item_count) % item_count
		elif FGGlobal.is_custom_action_just_pressed("down"):
			current_item = (current_item + 1) % item_count
			# Saltar elementos deshabilitados
			while current_item < item_count and popup.is_item_disabled(current_item):
				current_item = (current_item + 1) % item_count
				
		# Verificar tanto el sistema personalizado como ui_accept por defecto
		var accept_pressed = FGGlobal.is_custom_action_just_pressed("accept") or Input.is_action_just_pressed("ui_accept")
		var back_pressed = FGGlobal.is_custom_action_just_pressed("back") or Input.is_action_just_pressed("ui_cancel")
		
		# Seleccionar el elemento
		if accept_pressed:
			# Cerrar el popup
			popup.hide()
			
			# Seleccionar manualmente el elemento y forzar las señales
			option_button.selected = current_item
			
			# Emitir manualmente la señal item_selected
			if option_button.has_signal("item_selected"):
				option_button.item_selected.emit(current_item)
			
			break
			
		# Cancelar selección
		if back_pressed:
			popup.hide()
			break
	
	# Re-habilitar nuestro procesamiento normal
	set_process(was_processing)


func _update_focus() -> void:
	# Resetear todos los nodos al estado original
	for node in interactuable_nodes:
		if is_instance_valid(node) and node is Control:
			node.modulate = Color.WHITE
			if node.has_method("release_focus"):
				node.release_focus()
	
	# Resaltar y enfocar el nodo actual
	if interactuable_nodes.size() > 0 and current_button_index < interactuable_nodes.size():
		var current_node = interactuable_nodes[current_button_index]
		if is_instance_valid(current_node) and current_node is Control:
			if not is_editing_text:
				current_node.modulate = highlight_color
			if current_node.has_method("grab_focus") and not is_editing_text:
				current_node.grab_focus()


# Modificar la función _interact_with_control para incluir VSlider
func _interact_with_control(node: Node) -> void:
	if node is BaseButton:
		if node is CheckButton or node is CheckBox:
			node.button_pressed = !node.button_pressed
			# Emitir la señal toggled
			if node.has_signal("toggled"):
				node.toggled.emit(node.button_pressed)
		elif node is OptionButton:
			# Para OptionButton, manejar la selección manualmente
			_handle_option_button(node)
		else:
			# Para botones regulares
			if node.has_signal("pressed"):
				node.pressed.emit()
	
	elif node is HSlider or node is VSlider:  # Modificado para incluir VSlider
		# Entrar en modo de ajuste de slider
		is_adjusting_slider = true
		# Feedback visual de que estamos ajustando este slider
		node.modulate = Color(1.5, 1.5, 0.5, 1)
	
	elif node is TextEdit or node is LineEdit:
		# Entrar en modo de edición de texto
		is_editing_text = true
		node.grab_focus()
		
		# Feedback visual de que estamos editando este campo
		node.modulate = Color(0.5, 1.5, 0.5, 1)
		
		print("[Navigation] Entrando en modo de edición de texto. Usa ui_cancel para salir.")

# Agregar función para forzar actualización externa
func force_refresh_from_external():
	"""Permite actualizar la lista desde scripts externos"""
	refresh_interactables()
	print("[Navigation] Lista de interactuables actualizada externamente")



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
		# Mover a la derecha
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
		# Mover a la izquierda
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
		# Mover hacia abajo
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
				
			# Asegurar que no salimos de los límites
			if new_index >= interactuable_nodes.size():
				if wrap_selection:
					new_index = col
					row = 0
				else:
					# Encontrar el último índice válido en esta columna
					new_index = interactuable_nodes.size() - 1
					while new_index >= 0 and new_index % grid_columns != col:
						new_index -= 1
					if new_index < 0:
						break
			
			if _is_node_usable(interactuable_nodes[new_index]):
				current_button_index = new_index
				break
	
	elif FGGlobal.is_custom_action_just_pressed("up"):
		# Mover hacia arriba
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
		# Salir del modo de ajuste de slider
		is_adjusting_slider = false
		_update_focus()
		return
		
	var value_changed = false
	var new_value = slider.value
	
	if slider is HSlider:
		# Navegación horizontal para HSlider
		if FGGlobal.is_custom_action_just_pressed("right") or FGGlobal.is_custom_action_pressed("right"):
			new_value = min(slider.value + slider_step, slider.max_value)
			value_changed = true
		elif FGGlobal.is_custom_action_just_pressed("left") or FGGlobal.is_custom_action_pressed("left"):
			new_value = max(slider.value - slider_step, slider.min_value)
			value_changed = true
	elif slider is VSlider:
		# Navegación vertical para VSlider - CORREGIDO
		# up aumenta el valor, down lo disminuye (comportamiento estándar de VSlider)
		if FGGlobal.is_custom_action_just_pressed("up") or FGGlobal.is_custom_action_pressed("up"):
			new_value = min(slider.value + slider_step, slider.max_value)
			value_changed = true
		elif FGGlobal.is_custom_action_just_pressed("down") or FGGlobal.is_custom_action_pressed("down"):
			new_value = max(slider.value - slider_step, slider.min_value)
			value_changed = true
	
	if value_changed and new_value != slider.value:
		slider.value = new_value
		# Emitir la señal value_changed
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
	# Verificar si el nodo sigue siendo válido
	if not is_instance_valid(node):
		return false
		
	# Verificar si es un Control
	if not node is Control:
		return false
		
	var control = node as Control
	
	# Verificar si el nodo sigue en el árbol de escena
	if not control.is_inside_tree():
		return false
	
	# Verificar si el nodo es visible
	if not control.visible:
		return false
		
	# Verificar si el nodo es completamente transparente
	if control.modulate.a <= 0.01:
		return false
		
	# Verificar si el nodo está deshabilitado (si tiene esa propiedad)
	if control.has_method("is_disabled") and control.is_disabled():
		return false
	
	# Para botones
	if control is BaseButton and control.disabled:
		return false
	
	# Verificar si algún padre es invisible
	var parent = control.get_parent()
	while is_instance_valid(parent):
		if parent is Control and (not parent.visible or parent.modulate.a <= 0.01):
			return false
		parent = parent.get_parent()
	
	return true

func refresh_interactables() -> void:
	# Obtener el nombre del grupo desde FGGlobal
	var group_name = "interactuable"  # valor por defecto
	if FGGlobal and FGGlobal.has_method("get_interactable_group_name"):
		group_name = FGGlobal.get_interactable_group_name()
	
	# Obtener todos los nodos en el grupo especificado
	var all_nodes = get_tree().get_nodes_in_group(group_name)
	
	# Filtrar nodos inválidos
	interactuable_nodes.clear()
	for node in all_nodes:
		if is_instance_valid(node) and _is_node_usable(node):
			interactuable_nodes.append(node)
	
	# Almacenar colores originales
	original_colors.clear()
	for node in interactuable_nodes:
		if is_instance_valid(node) and node is Control:
			original_colors[node] = node.modulate
	
	# Resetear índice actual si es necesario
	if interactuable_nodes.size() > 0:
		if current_button_index >= interactuable_nodes.size():
			current_button_index = 0
		_update_focus()
	else:
		current_button_index = 0
	
	# Actualizar el conteo de nodos usando el grupo personalizable
	last_node_count = get_tree().get_nodes_in_group(group_name).size()

func _move_selection(direction: int) -> void:
	var new_index = current_button_index
	var attempts = 0
	var max_attempts = interactuable_nodes.size() * 2  # Prevenir bucles infinitos
	
	while attempts < max_attempts:
		attempts += 1
		
		if wrap_selection:
			new_index = (new_index + direction + interactuable_nodes.size()) % interactuable_nodes.size()
		else:
			new_index = clamp(new_index + direction, 0, interactuable_nodes.size() - 1)
			
			# Si llegamos al borde y no podemos movernos más, parar
			if (direction > 0 and new_index == interactuable_nodes.size() - 1) or \
			   (direction < 0 and new_index == 0):
				break
		
		# Si hemos vuelto al punto de partida, parar
		if new_index == current_button_index:
			break
			
		# Si encontramos un nodo utilizable, usarlo
		if _is_node_usable(interactuable_nodes[new_index]):
			current_button_index = new_index
			break

func _play_navigation_sound() -> void:
	if navigation_sound:
		navigation_sound.play()

func _check_visibility_changes() -> void:
	var visible_nodes = _get_visible_interactables()
	
	# Si la selección actual ya no es válida, necesitamos actualizar
	if interactuable_nodes.size() > 0 and current_button_index < interactuable_nodes.size():
		var current_node = interactuable_nodes[current_button_index]
		if not is_instance_valid(current_node) or not _is_node_usable(current_node) or not visible_nodes.has(current_node):
			# Nuestra selección actual ya no es válida, refrescar la lista
			refresh_interactables()
	
	# Si el conteo de nodos visibles cambió, refrescar la lista
	if visible_nodes.size() != interactuable_nodes.size():
		refresh_interactables()

func _get_visible_interactables() -> Array[Node]:
	var visible_nodes: Array[Node] = []
	var group_name = "interactuable"  # valor por defecto
	if FGGlobal and FGGlobal.has_method("get_interactable_group_name"):
		group_name = FGGlobal.get_interactable_group_name()
	
	var all_nodes = get_tree().get_nodes_in_group(group_name)
	
	for node in all_nodes:
		if _is_node_usable(node):
			visible_nodes.append(node)
	
	return visible_nodes

func select_specific_node(node: Control) -> void:
	var group_name = "interactuable"  # valor por defecto
	if FGGlobal and FGGlobal.has_method("get_interactable_group_name"):
		group_name = FGGlobal.get_interactable_group_name()
	
	if node.is_in_group(group_name) and _is_node_usable(node):
		var index = interactuable_nodes.find(node)
		if index != -1:
			current_button_index = index
			_update_focus()

func register_new_scene(scene_root: Node) -> void:
	# Asegurar que la raíz de la escena es válida
	if not is_instance_valid(scene_root):
		return
		
	# Esperar dos frames para asegurar que todos los hijos estén inicializados
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Verificar de nuevo si scene_root sigue siendo válido después de esperar
	if not is_instance_valid(scene_root):
		return
		
	# Refrescar la lista de nodos interactuables
	refresh_interactables()
	
	# Encontrar el primer interactuable en esta escena
	var first_interactable = _find_first_interactable_in_scene(scene_root)
	if first_interactable != null:
		select_specific_node(first_interactable)

func _find_first_interactable_in_scene(scene_root: Node) -> Control:
	# Asegurar que la raíz de la escena es válida
	if not is_instance_valid(scene_root):
		return null
	
	var group_name = "interactuable"  # valor por defecto
	if FGGlobal and FGGlobal.has_method("get_interactable_group_name"):
		group_name = FGGlobal.get_interactable_group_name()
		
	# Obtener todos los nodos interactuables
	var all_interactables = get_tree().get_nodes_in_group(group_name)
	
	# Filtrar para incluir solo nodos válidos que sean descendientes de scene_root
	for node in all_interactables:
		if is_instance_valid(node) and node is Control and _is_node_usable(node):
			# Verificar si el nodo es descendiente de scene_root
			var parent = node
			while is_instance_valid(parent):
				if parent == scene_root:
					return node
				parent = parent.get_parent()
	
	return null

func _on_node_added(node: Node) -> void:
	var group_name = "interactuable"  # valor por defecto
	if FGGlobal and FGGlobal.has_method("get_interactable_group_name"):
		group_name = FGGlobal.get_interactable_group_name()
	
	# Cuando se agrega un nodo al árbol de escena, verificar si está en el grupo interactuable
	# o si podría contener nodos interactuables
	if node.is_in_group(group_name):
		# Se agregó directamente un nuevo nodo interactuable
		call_deferred("refresh_interactables")
	elif node is Control:
		# Este es un control que podría contener nodos interactuables
		# Esperar un frame para que se inicialice completamente
		call_deferred("_check_for_new_interactables")

func _check_for_new_interactables() -> void:
	var group_name = "interactuable"  # valor por defecto
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
		print("[InputNavigation] Controlador conectado: ", device_id)
	else:
		print("[InputNavigation] Controlador desconectado: ", device_id)
