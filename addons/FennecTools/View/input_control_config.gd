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
	
	# Conectar señales solo si los nodos existen
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
	
	# Configurar guardado en tiempo real
	_setup_realtime_save()
	
	# Agregar todos los elementos interactuables al grupo
	_add_to_interactable_group()
	
	# Cargar configuración actual desde JSON
	_load_current_config()
	
	# Conectar a las señales del sistema global si está disponible
	if FGGlobal:
		FGGlobal.input_control_toggled.connect(_on_input_control_toggled)

func _setup_input_field_references():
	"""Configura las referencias a los campos de entrada con validación"""
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
			print("[InputControlConfig] Campo encontrado para '", action, "'")
		else:
			print("[InputControlConfig] ADVERTENCIA: No se encontró el campo para '", action, "' en ruta: ", field_paths[action])
	
	print("[InputControlConfig] Total de campos encontrados: ", input_fields.size())



func _add_to_interactable_group():
	"""Agrega todos los elementos interactuables al grupo para navegación"""
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
			node.add_to_group("interactuable")

func _load_current_config():
	"""Carga la configuración actual del sistema desde JSON"""
	if not FGGlobal:
		_update_status("FGGlobal no disponible")
		return
	
	# Forzar carga desde JSON
	FGGlobal.load_custom_input_mappings()
	
	# Cargar estado habilitado
	if is_instance_valid(enabled_checkbox):
		enabled_checkbox.button_pressed = FGGlobal.input_control_enabled
	
	if is_instance_valid(group_line_edit):
		group_line_edit.text = FGGlobal.get_interactable_group_name()
	
	# Cargar mapeos de entrada desde FGGlobal
	var mappings = FGGlobal.custom_input_mappings
	for action in input_fields:
		if mappings.has(action) and is_instance_valid(input_fields[action]):
			var inputs = mappings[action]
			if inputs.size() > 0:
				input_fields[action].text = ", ".join(inputs)
			else:
				input_fields[action].text = ""
			print("[InputControlConfig] Cargado mapeo para '", action, "': ", inputs)
	
	_update_status("Configuración cargada desde JSON")

func _update_status(message: String):
	"""Actualiza el label de estado de forma segura"""
	if is_instance_valid(status_label):
		status_label.text = "Estado: " + message
	print("[InputControlConfig] ", message)

func _on_group_changed(new_text: String):
	"""Callback cuando cambia el nombre del grupo"""
	if FGGlobal:
		FGGlobal.set_interactable_group_name(new_text.strip_edges())
		_update_status("Grupo actualizado a '" + new_text + "'")

func _on_enabled_toggled(button_pressed: bool):
	"""Callback cuando se cambia el estado del checkbox"""
	if FGGlobal:
		FGGlobal.enable_input_control(button_pressed)
		_update_status("Sistema " + ("ACTIVADO" if button_pressed else "DESACTIVADO"))

func _on_save_pressed():
	"""Guarda la configuración actual en JSON"""
	if not FGGlobal:
		_update_status("Error - FGGlobal no disponible")
		return
	
	print("[InputControlConfig] === INICIANDO GUARDADO EN JSON ===")
	
	# Guardar estado habilitado
	if is_instance_valid(enabled_checkbox):
		FGGlobal.enable_input_control(enabled_checkbox.button_pressed)
		print("Estado habilitado: ", enabled_checkbox.button_pressed)
	
	# Guardar nombre del grupo
	if is_instance_valid(group_line_edit):
		FGGlobal.set_interactable_group_name(group_line_edit.text.strip_edges())
		print("Grupo: ", group_line_edit.text.strip_edges())
	
	# Procesar y guardar cada mapeo de entrada
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
			print("Procesando acción '", action, "': '", input_text, "' -> ", inputs)
			
			# Actualizar FGGlobal inmediatamente
			FGGlobal.custom_input_mappings[action] = inputs
	
	# Guardar todo en JSON
	var save_success = FGGlobal.save_custom_input_mappings()
	
	if save_success:
		# Aplicar mapeos al InputMap si el sistema está habilitado
		if FGGlobal.input_control_enabled:
			FGGlobal.apply_custom_input_mappings()
		
		_update_status("Configuración guardada en JSON exitosamente")
		print("[InputControlConfig] Guardado exitoso")
		
		# Debug para verificar
		FGGlobal.debug_input_system()
	else:
		_update_status("Error guardando configuración en JSON")
		print("[InputControlConfig] Error en el guardado")

func reload_config():
	"""Recarga la configuración desde el archivo JSON"""
	if FGGlobal:
		FGGlobal.load_custom_input_mappings()
		_load_current_config()
		_update_status("Configuración recargada desde JSON")

func _on_reset_pressed():
	"""Restaura los valores por defecto"""
	if not FGGlobal:
		_update_status("Error - FGGlobal no disponible")
		return
	
	if is_instance_valid(group_line_edit):
		group_line_edit.text = "interactuable"
	FGGlobal.set_interactable_group_name("interactuable")
	
	var default_mappings = {
		"up": ["ui_up"],
		"down": ["ui_down"],
		"left": ["ui_left"],
		"right": ["ui_right"],
		"accept": ["ui_accept"],
		"back": ["ui_cancel"]
	}
	
	# Actualizar campos de entrada
	for action in input_fields:
		if default_mappings.has(action) and is_instance_valid(input_fields[action]):
			input_fields[action].text = ", ".join(default_mappings[action])
	
	# Actualizar FGGlobal
	for action in default_mappings:
		FGGlobal.set_custom_input_mapping(action, default_mappings[action])
	
	_update_status("Valores por defecto restaurados")

func _on_test_pressed():
	"""Prueba la configuración actual"""
	if not FGGlobal:
		_update_status("Error - FGGlobal no disponible")
		return
	
	# Guardar configuración primero
	_on_save_pressed()
	
	# Activar el sistema temporalmente si no está activo
	var was_enabled = FGGlobal.input_control_enabled
	if not was_enabled:
		FGGlobal.enable_input_control(true)
		FGGlobal.apply_custom_input_mappings()
	
	_update_status("Probando configuración... Usa las teclas configuradas")
	
	# Debug de las acciones disponibles
	print("[InputControlConfig] === PRUEBA DE MAPEOS ===")
	for action in input_fields:
		var mappings = FGGlobal.get_custom_input_mapping(action)
		var effective_mappings = mappings if mappings.size() > 0 else FGGlobal._get_default_mapping(action)
		print("Acción '", action, "': ", effective_mappings)
		
		# Verificar que las acciones existan en InputMap
		for mapping in effective_mappings:
			if InputMap.has_action(mapping):
				var events = InputMap.action_get_events(mapping)
				print("  -> '", mapping, "' tiene ", events.size(), " eventos en InputMap")
			else:
				print("  -> ERROR: '", mapping, "' no existe en InputMap")
	
	# Crear un timer para mostrar el resultado de la prueba
	var test_timer = Timer.new()
	add_child(test_timer)
	test_timer.wait_time = 5.0
	test_timer.one_shot = true
	test_timer.timeout.connect(_on_test_timeout.bind(was_enabled, test_timer))
	test_timer.start()

func _setup_realtime_save():
	"""Configura guardado en tiempo real cuando cambian los campos"""
	for action in input_fields:
		if is_instance_valid(input_fields[action]):
			# Conectar señal de cambio de texto para guardado automático
			if input_fields[action].has_signal("text_changed"):
				input_fields[action].text_changed.connect(_on_field_changed.bind(action))
			
			# También conectar cuando se pierde el foco
			if input_fields[action].has_signal("focus_exited"):
				input_fields[action].focus_exited.connect(_on_field_focus_lost.bind(action))

func _on_field_changed(new_text: String, action: String):
	"""Callback cuando cambia el texto de un campo"""
	# Opcional: Guardado automático en tiempo real
	# _auto_save_field(action, new_text)
	pass

func _on_field_focus_lost(action: String):
	"""Callback cuando un campo pierde el foco - guardar automáticamente"""
	if is_instance_valid(input_fields[action]):
		var input_text = input_fields[action].text.strip_edges()
		var inputs = []
		
		if input_text.length() > 0:
			var parts = input_text.split(",")
			for part in parts:
				var trimmed = part.strip_edges()
				if trimmed.length() > 0:
					inputs.append(trimmed)
		
		# Actualizar FGGlobal y guardar
		if FGGlobal:
			FGGlobal.custom_input_mappings[action] = inputs
			FGGlobal.save_custom_input_mappings()
			print("[InputControlConfig] Auto-guardado campo '", action, "': ", inputs)


func _on_test_timeout(was_enabled: bool, timer: Timer):
	"""Callback cuando termina la prueba"""
	# Restaurar estado original si era necesario
	if not was_enabled and FGGlobal:
		FGGlobal.enable_input_control(false)
	
	_update_status("Prueba completada")
	
	# Limpiar el timer
	if is_instance_valid(timer):
		timer.queue_free()

func _on_input_control_toggled(enabled: bool):
	"""Callback cuando el sistema de control cambia de estado"""
	if is_instance_valid(enabled_checkbox):
		enabled_checkbox.button_pressed = enabled
	_update_status("Sistema " + ("ACTIVADO" if enabled else "DESACTIVADO"))
