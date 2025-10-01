@tool
extends Control

# Referencias correctas basadas en el archivo .tscn
@onready var item_list: ItemList = $VBoxContainer/ScrollContainer/ItemList
@onready var name_input: LineEdit = $VBoxContainer/HBoxContainer/NameInput
@onready var type_option: OptionButton = $VBoxContainer/HBoxContainer/TypeOption
@onready var value_checkbox: CheckBox = $VBoxContainer/HBoxContainer/ValueCheckBox
@onready var value_spinbox: SpinBox = $VBoxContainer/HBoxContainer/ValueSpinBox
@onready var group_input: LineEdit = $VBoxContainer/HBoxContainer2/GroupInput
@onready var description_input: TextEdit = $VBoxContainer/DescriptionInput

# Agregando OptionButton para filtrar por grupos
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
var current_filter_group: String = "Todos"
var current_text_values: Array = []

func safe_load_conditionals() -> Array:
	"""Función auxiliar para cargar condicionales de forma segura"""
	if not FGGlobal or not FGGlobal._conditionals_initialized:
		return []
	
	# We need to access FGGlobal.condicionales directly after ensuring it's loaded
	if FGGlobal.load_conditionals_from_plugin():
		return FGGlobal.condicionales
	else:
		print("[ConditionalEditor] Error: No se pudieron cargar las condicionales del plugin")
		return []

func _ready():
	if not FGGlobal:
		print("[ConditionalEditor] Esperando FGGlobal...")
		await get_tree().process_frame
	
	connect_to_fgglobal()
	
	setup_ui()
	connect_signals()
	
	if not FGGlobal._conditionals_initialized:
		print("[ConditionalEditor] Esperando inicialización de condicionales...")
		await FGGlobal.conditionals_loaded
	
	refresh_list()
	update_group_filter()

func connect_to_fgglobal():
	"""Conecta a las señales de FGGlobal para actualizaciones en tiempo real"""
	if FGGlobal and not _fgglobal_connected:
		if not FGGlobal.conditional_changed.is_connected(_on_conditional_changed):
			FGGlobal.conditional_changed.connect(_on_conditional_changed)
		if not FGGlobal.conditionals_loaded.is_connected(_on_conditionals_loaded):
			FGGlobal.conditionals_loaded.connect(_on_conditionals_loaded)
		_fgglobal_connected = true
		print("[ConditionalEditor] Conectado a FGGlobal")

func _on_conditional_changed(id: int, new_value: Variant):
	"""Callback cuando una condicional cambia desde otro lugar"""
	print("[ConditionalEditor] Condicional ", id, " cambió a: ", new_value)
	refresh_list()

func _on_conditionals_loaded():
	"""Callback cuando las condicionales terminan de cargar"""
	print("[ConditionalEditor] Condicionales cargadas, actualizando lista")
	refresh_list()
	update_group_filter()

func setup_ui():
	# Limpiar opciones duplicadas en el .tscn
	type_option.clear()
	type_option.add_item("Booleano", 0)
	type_option.add_item("Numérico", 1)
	type_option.add_item("Textos", 2)  # Nuevo tipo
	type_option.selected = 0
	_on_type_selected(0)
	
	# Configurar filtro de grupos
	group_filter.clear()
	group_filter.add_item("Todos", -1)
	
	# Ocultar contenedor de texto múltiple inicialmente
	text_values_container.visible = false

func connect_signals():
	add_button.pressed.connect(_on_add_pressed)
	edit_button.pressed.connect(_on_edit_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	type_option.item_selected.connect(_on_type_selected)
	item_list.item_selected.connect(_on_item_selected)
	
	# Conectar señales del filtro de grupos
	group_filter.item_selected.connect(_on_group_filter_selected)
	
	# Conectar señales para texto múltiple
	add_text_button.pressed.connect(_on_add_text_pressed)
	remove_text_button.pressed.connect(_on_remove_text_pressed)
	text_input.text_submitted.connect(_on_text_submitted)

func _on_type_selected(index: int):
	value_checkbox.visible = (index == 0)  # Booleano
	value_spinbox.visible = (index == 1)   # Numérico
	text_values_container.visible = (index == 2)  # Texto Múltiple
	
	# Para texto simple, usaremos description_input
	if index == 2:  # Texto Múltiple
		update_text_values_list()

func update_group_filter():
	"""Actualiza el OptionButton con los grupos disponibles"""
	if not FGGlobal or not FGGlobal._conditionals_initialized:
		return
	
	var current_selection = current_filter_group
	group_filter.clear()
	group_filter.add_item("Todos", -1)
	
	var original_conditionals = safe_load_conditionals()
	var groups = []
	for conditional in original_conditionals:
		var group = conditional.get("grupo", "default")
		if group not in groups:
			groups.append(group)
	
	for i in range(groups.size()):
		group_filter.add_item(groups[i], i)
		if groups[i] == current_selection:
			group_filter.selected = i + 1

func _on_group_filter_selected(index: int):
	"""Callback cuando se selecciona un filtro de grupo"""
	if index == 0:
		current_filter_group = "Todos"
	else:
		current_filter_group = group_filter.get_item_text(index)
	
	refresh_list()

func refresh_list():
	item_list.clear()
	
	if not FGGlobal:
		item_list.add_item("❌ Error: FGGlobal no disponible")
		print("[ConditionalEditor] FGGlobal no disponible")
		return
	
	if not FGGlobal._conditionals_initialized:
		item_list.add_item("⏳ Cargando condicionales...")
		print("[ConditionalEditor] Condicionales aún no inicializadas")
		return
	
	var original_conditionals = safe_load_conditionals()
	
	if original_conditionals.size() == 0:
		item_list.add_item("📝 No hay condicionales definidas")
		print("[ConditionalEditor] No hay condicionales cargadas")
		return
	
	print("[ConditionalEditor] Cargando ", original_conditionals.size(), " condicionales del archivo original")
	
	for conditional in original_conditionals:
		var group_text = conditional.get("grupo", "default")
		
		# Aplicar filtro de grupo
		if current_filter_group != "Todos" and group_text != current_filter_group:
			continue
		
		var text = ""
		
		match conditional.get("tipo", ""):
			"booleano":
				var icon = "✅" if conditional.get("valor_bool", false) else "⛔"
				text = "[%s] %s %s (ID: %d)" % [group_text, icon, conditional.get("nombre", "Sin nombre"), conditional.get("id", 0)]
			"numerico":
				text = "[%s] %.2f %s (ID: %d)" % [group_text, conditional.get("valor_float", 0.0), conditional.get("nombre", "Sin nombre"), conditional.get("id", 0)]
			"textos":
				var values = conditional.get("valores_texto", [])
				var values_str = str(values.size()) + " textos"
				text = "[%s] [%s] %s (ID: %d)" % [group_text, values_str, conditional.get("nombre", "Sin nombre"), conditional.get("id", 0)]
			_:
				text = "[%s] ❓ %s (ID: %d) - Tipo desconocido" % [group_text, conditional.get("nombre", "Sin nombre"), conditional.get("id", 0)]
		
		item_list.add_item(text)

func _on_item_selected(index: int):
	if not FGGlobal or not FGGlobal._conditionals_initialized:
		return
	
	# Ajustar índice por filtro aplicado
	var filtered_conditionals = get_filtered_conditionals()
	if index < 0 or index >= filtered_conditionals.size():
		return
	
	var conditional = filtered_conditionals[index]
	name_input.text = conditional.get("nombre", "")
	group_input.text = conditional.get("grupo", "default")
	description_input.text = conditional.get("descripcion", "")
	
	match conditional.get("tipo", ""):
		"booleano":
			type_option.selected = 0
			value_checkbox.button_pressed = conditional.get("valor_bool", false)
		"numerico":
			type_option.selected = 1
			value_spinbox.value = conditional.get("valor_float", 0.0)
		"textos":
			type_option.selected = 2  # ✅ CORREGIDO: era 3, ahora es 2
			current_text_values = conditional.get("valores_texto", [])
			update_text_values_list()
	
	_on_type_selected(type_option.selected)

func get_filtered_conditionals() -> Array:
	"""Obtiene las condicionales filtradas por grupo"""
	if not FGGlobal or not FGGlobal._conditionals_initialized:
		return []
	
	var original_conditionals = safe_load_conditionals()
	
	if current_filter_group == "Todos":
		return original_conditionals
	
	var filtered = []
	for conditional in original_conditionals:
		var group_text = conditional.get("grupo", "default")
		if group_text == current_filter_group:
			filtered.append(conditional)
	
	return filtered

func update_text_values_list():
	"""Actualiza la lista de valores de texto múltiple"""
	text_values_list.clear()
	for value in current_text_values:
		text_values_list.add_item(value)

func _on_add_text_pressed():
	"""Agrega un nuevo valor de texto"""
	var text = text_input.text.strip_edges()
	if text != "" and text not in current_text_values:
		current_text_values.append(text)
		update_text_values_list()
		text_input.text = ""

func _on_remove_text_pressed():
	"""Remueve el valor de texto seleccionado"""
	var selected = text_values_list.get_selected_items()
	if selected.size() > 0:
		var index = selected[0]
		if index >= 0 and index < current_text_values.size():
			current_text_values.remove_at(index)
			update_text_values_list()

func _on_text_submitted(text: String):
	"""Callback cuando se presiona Enter en el input de texto"""
	_on_add_text_pressed()

func _on_add_pressed():
	if not FGGlobal or not FGGlobal._conditionals_initialized:
		print("[ConditionalEditor] Error: FGGlobal no disponible o no inicializado")
		return
	
	var name_text = name_input.text.strip_edges()
	if name_text == "":
		print("[ConditionalEditor] Error: El nombre no puede estar vacío")
		return
	
	var original_conditionals = safe_load_conditionals()
	for conditional in original_conditionals:
		if conditional.get("nombre", "") == name_text:
			print("[ConditionalEditor] Error: Ya existe una condicional con ese nombre")
			return
	
	# Generar nuevo ID único
	var new_id = 1
	for conditional in original_conditionals:
		if conditional.get("id", 0) >= new_id:
			new_id = conditional.get("id", 0) + 1
	
	var new_conditional = {
		"id": new_id,
		"nombre": name_text,
		"grupo": group_input.text.strip_edges() if group_input.text.strip_edges() != "" else "default",
		"descripcion": description_input.text.strip_edges(),
		"tipo": ""
	}
	
	match type_option.selected:
		0: # Booleano
			new_conditional.tipo = "booleano"
			new_conditional.valor_bool = value_checkbox.button_pressed
		1: # Numérico
			new_conditional.tipo = "numerico"
			new_conditional.valor_float = value_spinbox.value
		2: # Texto Múltiple
			new_conditional.tipo = "textos"
			new_conditional.valores_texto = current_text_values.duplicate()
	
	original_conditionals.append(new_conditional)
	FGGlobal.condicionales = original_conditionals
	FGGlobal.save_conditionals()
	refresh_list()
	update_group_filter()
	clear_inputs()
	print("[ConditionalEditor] Condicional agregada: ", new_conditional.nombre)

func _on_edit_pressed():
	if not FGGlobal or not FGGlobal._conditionals_initialized:
		return
	
	var selected = item_list.get_selected_items()
	if selected.size() == 0:
		print("[ConditionalEditor] No hay elemento seleccionado")
		return
	
	var filtered_conditionals = get_filtered_conditionals()
	var index = selected[0]
	if index < 0 or index >= filtered_conditionals.size():
		return
	
	var conditional = filtered_conditionals[index]
	var name_text = name_input.text.strip_edges()
	
	# Validar nombre único (excluyendo la condicional actual)
	var original_conditionals = safe_load_conditionals()
	for other_conditional in original_conditionals:
		if other_conditional.get("id", -1) != conditional.get("id", -1) and other_conditional.get("nombre", "") == name_text:
			print("[ConditionalEditor] Error: Ya existe una condicional con ese nombre")
			return
	
	# Encontrar la condicional real en el array original (no en el filtrado)
	var real_conditional = null
	var real_index = -1
	for i in range(original_conditionals.size()):
		if original_conditionals[i].get("id", -1) == conditional.get("id", -1):
			real_conditional = original_conditionals[i]
			real_index = i
			break
	
	if real_conditional == null:
		print("[ConditionalEditor] Error: No se encontró la condicional en el array original")
		return
	
	# Actualizar datos básicos
	real_conditional.nombre = name_text
	real_conditional.grupo = group_input.text.strip_edges() if group_input.text.strip_edges() != "" else "default"
	real_conditional.descripcion = description_input.text.strip_edges()
	
	# Actualizar según el tipo
	match type_option.selected:
		0: # Booleano
			real_conditional.tipo = "booleano"
			real_conditional.valor_bool = value_checkbox.button_pressed
			# Limpiar otros valores si cambió de tipo
			real_conditional.erase("valor_float")
			real_conditional.erase("valores_texto")
		1: # Numérico
			real_conditional.tipo = "numerico"
			real_conditional.valor_float = value_spinbox.value
			# Limpiar otros valores si cambió de tipo
			real_conditional.erase("valor_bool")
			real_conditional.erase("valores_texto")
		2: # Texto Múltiple
			real_conditional.tipo = "textos"
			real_conditional.valores_texto = current_text_values.duplicate()
			# Limpiar otros valores si cambió de tipo
			real_conditional.erase("valor_bool")
			real_conditional.erase("valor_float")
			
			print("[ConditionalEditor] Actualizando valores_texto: ", real_conditional.valores_texto)
	
	# Actualizar FGGlobal y guardar
	FGGlobal.condicionales = original_conditionals
	FGGlobal.save_conditionals()
	
	# Refrescar interfaz
	refresh_list()
	update_group_filter()
	print("[ConditionalEditor] Condicional editada: ", real_conditional.nombre)
	
	# Debug: Verificar que se guardó correctamente
	var verification = safe_load_conditionals()
	for v_conditional in verification:
		if v_conditional.get("id", -1) == real_conditional.get("id", -1):
			print("[ConditionalEditor] Verificación - valores_texto guardados: ", v_conditional.get("valores_texto", []))
			break



func _on_delete_pressed():
	if not FGGlobal or not FGGlobal._conditionals_initialized:
		return
	
	var selected = item_list.get_selected_items()
	if selected.size() == 0:
		print("[ConditionalEditor] No hay elemento seleccionado")
		return
	
	var filtered_conditionals = get_filtered_conditionals()
	var index = selected[0]
	if index < 0 or index >= filtered_conditionals.size():
		return
	
	var conditional = filtered_conditionals[index]
	var conditional_name = conditional.get("nombre", "Sin nombre")
	
	var original_conditionals = safe_load_conditionals()
	for i in range(original_conditionals.size()):
		if original_conditionals[i] == conditional:
			original_conditionals.remove_at(i)
			break
	
	# Fix: Update FGGlobal.condicionales and save only to plugin file (not slots)
	FGGlobal.condicionales = original_conditionals
	FGGlobal.save_conditionals_to_plugin()  # Only save to plugin file, not user slots
	refresh_list()
	update_group_filter()
	clear_inputs()
	print("[ConditionalEditor] Condicional eliminada del archivo plugin: ", conditional_name)

func clear_inputs():
	name_input.text = ""
	group_input.text = ""
	description_input.text = ""
	value_checkbox.button_pressed = false
	value_spinbox.value = 0.0
	current_text_values.clear()
	update_text_values_list()

func _exit_tree():
	"""Limpieza al salir"""
	if FGGlobal and _fgglobal_connected:
		if FGGlobal.conditional_changed.is_connected(_on_conditional_changed):
			FGGlobal.conditional_changed.disconnect(_on_conditional_changed)
		if FGGlobal.conditionals_loaded.is_connected(_on_conditionals_loaded):
			FGGlobal.conditionals_loaded.disconnect(_on_conditionals_loaded)
		_fgglobal_connected = false
