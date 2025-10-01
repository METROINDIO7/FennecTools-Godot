@tool
extends Control

# ============================================================================
# FENNEC TOOLS - KANBAN BOARD MANAGER MEJORADO
# Sistema de gestión de tareas tipo Kanban con drag & drop y filtros corregidos
# ============================================================================

@onready var columns_container: HBoxContainer = $VBoxContainer/MainContent/ScrollContainer/ColumnsContainer
@onready var task_detail_panel: Panel = $VBoxContainer/MainContent/TaskDetailPanel
@onready var detail_title: LineEdit = $VBoxContainer/MainContent/TaskDetailPanel/VBoxContainer/DetailTitle
@onready var detail_description: TextEdit = $VBoxContainer/MainContent/TaskDetailPanel/VBoxContainer/DetailDescription
@onready var detail_assignee: LineEdit = $VBoxContainer/MainContent/TaskDetailPanel/VBoxContainer/HBoxContainer/VBoxContainer/DetailAssignee
@onready var detail_due_date: LineEdit = $VBoxContainer/MainContent/TaskDetailPanel/VBoxContainer/HBoxContainer/VBoxContainer2/DetailDueDate
@onready var detail_save_btn: Button = $VBoxContainer/MainContent/TaskDetailPanel/VBoxContainer/ButtonContainer/SaveButton
@onready var detail_cancel_btn: Button = $VBoxContainer/MainContent/TaskDetailPanel/VBoxContainer/ButtonContainer/CancelButton
@onready var detail_delete_btn: Button = $VBoxContainer/MainContent/TaskDetailPanel/VBoxContainer/ButtonContainer/DeleteButton

# Nuevo: Selector de columna en el panel de detalles
@onready var detail_column_selector: OptionButton

# Filtros
@onready var filter_assignee: LineEdit = $VBoxContainer/FilterPanel/HBoxContainer/FilterAssignee
@onready var filter_status: OptionButton = $VBoxContainer/FilterPanel/HBoxContainer/FilterStatus
@onready var filter_clear_btn: Button = $VBoxContainer/FilterPanel/HBoxContainer/ClearFiltersButton

# Stats
@onready var stats_label: Label = $VBoxContainer/HeaderPanel/HBoxContainer/StatsLabel

# Gestión de columnas
@onready var add_column_btn: Button = $VBoxContainer/ColumnManagement/HBoxContainer/AddColumnButton
@onready var column_name_input: LineEdit = $VBoxContainer/ColumnManagement/HBoxContainer/ColumnNameInput
@onready var column_color_input: LineEdit = $VBoxContainer/ColumnManagement/HBoxContainer/ColumnColorInput

# Variables del sistema
var kanban_data_path: String = "res://addons/FennecTools/data/fennec_kanban_data.json"
var kanban_data: Dictionary = {
	"columns": [],
	"tasks": [],
	"next_task_id": 1,
	"next_column_id": 1
}

var current_editing_task: Dictionary = {}
var task_cards: Array[Control] = []
var column_panels: Array[Panel] = []

# Variables para drag & drop
var dragging_task: Control = null
var drag_preview: Control = null
var drag_offset: Vector2 = Vector2.ZERO

# Colores por defecto mejorados
var default_colors: Array[Color] = [
	Color("#3498DB"),    # Por hacer - Azul
	Color("#F39C12"),    # En progreso - Naranja
	Color("#2ECC71")     # Completado - Verde
]

# ============================================================================
# INICIALIZACIÓN
# ============================================================================

func _ready():
	setup_default_columns()
	load_kanban_data()
	setup_ui_connections()
	create_detail_column_selector()
	setup_filters()
	refresh_board()
	task_detail_panel.visible = false

func setup_default_columns():
	"""Configura las columnas por defecto si no existen"""
	if kanban_data.columns.is_empty():
		kanban_data.columns = [
			{
				"id": 1,
				"name": "Por Hacer",
				"color": default_colors[0],
				"order": 0
			},
			{
				"id": 2, 
				"name": "En Progreso",
				"color": default_colors[1],
				"order": 1
			},
			{
				"id": 3,
				"name": "Completado", 
				"color": default_colors[2],
				"order": 2
			}
		]
		kanban_data.next_column_id = 4

func create_detail_column_selector():
	"""Crea el selector de columna en el panel de detalles"""
	var container = $VBoxContainer/MainContent/TaskDetailPanel/VBoxContainer/HBoxContainer
	
	# Agregar contenedor para el selector de estado
	var state_vbox = VBoxContainer.new()
	state_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(state_vbox)
	
	var state_label = Label.new()
	state_label.text = "Estado:"
	state_vbox.add_child(state_label)
	
	detail_column_selector = OptionButton.new()
	detail_column_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state_vbox.add_child(detail_column_selector)

func setup_ui_connections():
	"""Conecta las señales de la interfaz"""
	detail_save_btn.pressed.connect(_on_save_task)
	detail_cancel_btn.pressed.connect(_on_cancel_edit)
	detail_delete_btn.pressed.connect(_on_delete_task)
	
	add_column_btn.pressed.connect(_on_add_column)
	filter_clear_btn.pressed.connect(_on_clear_filters)
	
	filter_assignee.text_changed.connect(_on_filter_changed)
	filter_status.item_selected.connect(_on_filter_changed)

func setup_filters():
	"""Configura los filtros disponibles"""
	filter_status.clear()
	filter_status.add_item("Todos los estados", -1)  # Índice 0, ID -1
	
	# Configurar también el selector de columna en detalles
	if detail_column_selector:
		detail_column_selector.clear()
	
	# Agregar columnas con sus IDs reales
	for column in kanban_data.columns:
		filter_status.add_item(column.name, column.id)  # Índices 1+, IDs reales
		if detail_column_selector:
			detail_column_selector.add_item(column.name, column.id)
	
	# Asegurar que "Todos los estados" esté seleccionado por defecto
	filter_status.selected = 0


# ============================================================================
# GESTIÓN DE DATOS
# ============================================================================

func load_kanban_data():
	"""Carga los datos del Kanban desde JSON"""
	if FileAccess.file_exists(kanban_data_path):
		var file = FileAccess.open(kanban_data_path, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_text)
			
			if parse_result == OK:
				var loaded_data = json.data
				if loaded_data.has("columns"):
					kanban_data.columns = loaded_data.columns
					# Convertir strings de color a Color objects
					for column in kanban_data.columns:
						if column.has("color") and column.color is String:
							column.color = Color(column.color)
				if loaded_data.has("tasks"):
					kanban_data.tasks = loaded_data.tasks
				if loaded_data.has("next_task_id"):
					kanban_data.next_task_id = loaded_data.next_task_id
				if loaded_data.has("next_column_id"):
					kanban_data.next_column_id = loaded_data.next_column_id
				
				print("[KanbanManager] Datos cargados: ", kanban_data.tasks.size(), " tareas, ", kanban_data.columns.size(), " columnas")
			else:
				print("[KanbanManager] Error parseando JSON: ", json.error_string)
	else:
		print("[KanbanManager] Archivo de datos no existe, usando valores por defecto")

func save_kanban_data():
	"""Guarda los datos del Kanban en JSON"""
	var file = FileAccess.open(kanban_data_path, FileAccess.WRITE)
	if file:
		# Crear copia para guardar, convirtiendo Colors a strings
		var save_data = kanban_data.duplicate(true)
		for column in save_data.columns:
			if column.has("color") and column.color is Color:
				column.color = column.color.to_html()
		
		var json_string = JSON.stringify(save_data)
		file.store_string(json_string)
		file.close()
		print("[KanbanManager] Datos guardados exitosamente")
	else:
		print("[KanbanManager] Error guardando datos")

# ============================================================================
# GESTIÓN DE COLUMNAS
# ============================================================================

func create_column_panel(column_data: Dictionary) -> Panel:
	"""Crea un panel visual para una columna"""
	var column_panel = Panel.new()
	column_panel.custom_minimum_size = Vector2(320, 400)
	column_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Aplicar color de fondo mejorado
	var style_box = StyleBoxFlat.new()
	var base_color = column_data.color if column_data.color is Color else Color(column_data.color)
	style_box.bg_color = base_color
	style_box.bg_color.a = 0.15  # Transparencia más sutil
	style_box.corner_radius_top_left = 12
	style_box.corner_radius_top_right = 12
	style_box.corner_radius_bottom_left = 12
	style_box.corner_radius_bottom_right = 12
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = base_color
	column_panel.add_theme_stylebox_override("panel", style_box)
	
	var vbox = VBoxContainer.new()
	column_panel.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	
	# Header de la columna
	var header = create_column_header(column_data)
	vbox.add_child(header)
	
	# Contenedor de tareas con drag & drop
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	var tasks_container = VBoxContainer.new()
	tasks_container.name = "TasksContainer"
	tasks_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tasks_container.add_theme_constant_override("separation", 8)
	scroll.add_child(tasks_container)
	
	# Botón para agregar tarea
	var add_task_btn = Button.new()
	add_task_btn.text = "+ Agregar Tarea"
	add_task_btn.modulate = Color.WHITE
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = base_color
	btn_style.corner_radius_top_left = 6
	btn_style.corner_radius_top_right = 6
	btn_style.corner_radius_bottom_left = 6
	btn_style.corner_radius_bottom_right = 6
	add_task_btn.add_theme_stylebox_override("normal", btn_style)
	add_task_btn.pressed.connect(_on_add_task.bind(column_data.id))
	vbox.add_child(add_task_btn)
	
	column_panel.set_meta("column_id", column_data.id)
	column_panel.set_meta("accepts_drops", true)
	
	return column_panel


func create_column_header(column_data: Dictionary) -> Control:
	"""Crea el header de una columna con título y opciones"""
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	
	# Indicador de color
	var color_indicator = Panel.new()
	color_indicator.custom_minimum_size = Vector2(4, 24)
	var color_style = StyleBoxFlat.new()
	color_style.bg_color = column_data.color if column_data.color is Color else Color(column_data.color)
	color_style.corner_radius_top_left = 2
	color_style.corner_radius_bottom_left = 2
	color_indicator.add_theme_stylebox_override("panel", color_style)
	header.add_child(color_indicator)
	
	var title_label = Label.new()
	title_label.text = column_data.name
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color.BLACK)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	
	# Contador de tareas
	var count = get_task_count_for_column(column_data.id)
	var count_label = Label.new()
	count_label.text = "(" + str(count) + ")"
	count_label.add_theme_font_size_override("font_size", 12)
	count_label.add_theme_color_override("font_color", Color.GRAY)
	header.add_child(count_label)
	
	# CORRECCIÓN: Mostrar botón de eliminar para TODAS las columnas, pero deshabilitado para las por defecto
	var delete_btn = Button.new()
	delete_btn.text = "×"
	delete_btn.flat = true
	delete_btn.custom_minimum_size = Vector2(28, 28)
	delete_btn.add_theme_font_size_override("font_size", 18)
	
	if column_data.id <= 3:  # Columnas por defecto
		delete_btn.disabled = true
		delete_btn.tooltip_text = "No se pueden eliminar las columnas por defecto"
		delete_btn.add_theme_color_override("font_color", Color.GRAY)
	else:  # Columnas personalizadas
		delete_btn.add_theme_color_override("font_color", Color.RED)
		delete_btn.tooltip_text = "Eliminar columna (las tareas se moverán a 'Por Hacer')"
		delete_btn.pressed.connect(_on_delete_column.bind(column_data.id))
	
	header.add_child(delete_btn)
	
	return header


func get_task_count_for_column(column_id: int) -> int:
	"""Obtiene el número de tareas en una columna"""
	var count = 0
	for task in kanban_data.tasks:
		if task.has("column_id") and task.column_id == column_id and task_matches_filters(task):
			count += 1
	return count

func _on_add_column():
	"""Agrega una nueva columna personalizada"""
	var column_name = column_name_input.text.strip_edges()
	if column_name.is_empty():
		column_name = "Nueva Columna"
	
	var column_color = parse_hex_color(column_color_input.text)
	
	var new_column = {
		"id": kanban_data.next_column_id,
		"name": column_name,
		"color": column_color,
		"order": kanban_data.columns.size()
	}
	
	kanban_data.columns.append(new_column)
	kanban_data.next_column_id += 1
	
	column_name_input.text = ""
	column_color_input.text = ""
	save_kanban_data()
	setup_filters()
	refresh_board()

func _on_delete_column(column_id: int):
	"""Elimina una columna personalizada"""
	if column_id <= 3:  # No permitir eliminar columnas por defecto
		return
	
	# Mover tareas de esta columna a "Por Hacer"
	for task in kanban_data.tasks:
		if task.has("column_id") and task.column_id == column_id:
			task.column_id = 1  # Por Hacer
	
	# Eliminar columna
	for i in range(kanban_data.columns.size()):
		if kanban_data.columns[i].id == column_id:
			kanban_data.columns.remove_at(i)
			break
	
	save_kanban_data()
	setup_filters()
	refresh_board()

func parse_hex_color(hex_string: String) -> Color:
	"""Convierte un código hexadecimal a Color"""
	hex_string = hex_string.strip_edges()
	if hex_string.is_empty():
		return Color("#9B59B6")  # Color púrpura por defecto
	
	# Remover # si existe
	if hex_string.begins_with("#"):
		hex_string = hex_string.substr(1)
	
	# Validar longitud y caracteres
	if hex_string.length() != 6:
		return Color("#9B59B6")
	
	# Verificar que solo contenga caracteres hexadecimales
	for char in hex_string:
		if not char.to_lower() in "0123456789abcdef":
			return Color("#9B59B6")
	
	return Color("#" + hex_string)

# ============================================================================
# GESTIÓN DE TAREAS CON DRAG & DROP
# ============================================================================

func create_task_card(task_data: Dictionary) -> Control:
	"""Crea una tarjeta visual para una tarea con capacidad de drag & drop"""
	var card = Panel.new()
	card.custom_minimum_size = Vector2(290, 100)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Estilo de la tarjeta mejorado
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color.WHITE
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	style_box.border_width_left = 3
	style_box.border_width_right = 3
	style_box.border_width_top = 3
	style_box.border_width_bottom = 3
	
	# Color del borde según columna
	var border_color = get_column_color(task_data.column_id)
	style_box.border_color = border_color
	
	# Sombra sutil
	style_box.shadow_color = Color.BLACK
	style_box.shadow_color.a = 0.1
	style_box.shadow_size = 2
	
	card.add_theme_stylebox_override("panel", style_box)
	
	var vbox = VBoxContainer.new()
	card.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 6)
	
	# Título de la tarea
	var title_label = Label.new()
	title_label.text = task_data.title
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color.BLACK)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	vbox.add_child(title_label)
	
	# Descripción corta si existe
	if not task_data.description.is_empty():
		var desc_label = Label.new()
		var short_desc = task_data.description.substr(0, 50)
		if task_data.description.length() > 50:
			short_desc += "..."
		desc_label.text = short_desc
		desc_label.add_theme_font_size_override("font_size", 11)
		desc_label.add_theme_color_override("font_color", Color.GRAY)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc_label)
	
	# Información adicional
	var info_container = HBoxContainer.new()
	vbox.add_child(info_container)
	
	# Asignado a
	if not task_data.assignee.is_empty():
		var assignee_label = Label.new()
		assignee_label.text = "👤 " + task_data.assignee
		assignee_label.add_theme_font_size_override("font_size", 10)
		assignee_label.add_theme_color_override("font_color", Color.DIM_GRAY)
		info_container.add_child(assignee_label)
	
	# Fecha de vencimiento
	if not task_data.due_date.is_empty():
		var due_label = Label.new()
		due_label.text = "📅 " + task_data.due_date
		due_label.add_theme_font_size_override("font_size", 10)
		due_label.add_theme_color_override("font_color", Color.DIM_GRAY)
		info_container.add_child(due_label)
	
	# Configurar drag & drop y click
	card.set_meta("task_id", task_data.id)
	card.set_meta("task_data", task_data)
	card.set_meta("draggable", true)
	
	# Conectar eventos de mouse para drag & drop
	card.gui_input.connect(_on_task_card_input.bind(card))
	
	return card

func get_column_color(column_id: int) -> Color:
	"""Obtiene el color de una columna por su ID"""
	for column in kanban_data.columns:
		if column.id == column_id:
			return column.color if column.color is Color else Color(column.color)
	return Color.GRAY

func _on_task_card_input(event: InputEvent, card: Control):
	"""Maneja la entrada de mouse en las tarjetas de tareas"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if event.double_click:
					# Doble click para editar
					var task_data = card.get_meta("task_data")
					edit_task(task_data)
				else:
					# Iniciar drag
					start_drag(card, event.position)
			else:
				# Finalizar drag
				end_drag(event.global_position)
	elif event is InputEventMouseMotion and dragging_task != null:
		# Actualizar posición del drag
		update_drag(event.global_position)

func start_drag(card: Control, local_position: Vector2):
	"""Inicia el arrastre de una tarjeta"""
	dragging_task = card
	drag_offset = local_position
	
	# Crear preview visual
	create_drag_preview(card)
	
	# Cambiar z-index para que aparezca encima
	card.z_index = 100
	card.modulate.a = 0.7

func create_drag_preview(card: Control):
	"""Crea una vista previa visual del elemento que se está arrastrando"""
	drag_preview = card.duplicate()
	get_viewport().add_child(drag_preview)
	drag_preview.modulate = Color(1, 1, 1, 0.8)
	drag_preview.z_index = 1000

func update_drag(global_position: Vector2):
	"""Actualiza la posición del drag preview"""
	if drag_preview:
		drag_preview.global_position = global_position - drag_offset

func end_drag(global_position: Vector2):
	"""Finaliza el arrastre y maneja el drop"""
	if dragging_task == null:
		return
	
	# Restaurar apariencia original
	dragging_task.z_index = 0
	dragging_task.modulate.a = 1.0
	
	# Encontrar columna de destino
	var target_column = find_column_at_position(global_position)
	if target_column != null:
		var task_data = dragging_task.get_meta("task_data")
		var old_column_id = task_data.column_id
		var new_column_id = target_column.get_meta("column_id")
		
		if old_column_id != new_column_id:
			# Cambiar columna de la tarea
			move_task_to_column(task_data.id, new_column_id)
	
	# Limpiar drag
	if drag_preview:
		drag_preview.queue_free()
		drag_preview = null
	
	dragging_task = null

func find_column_at_position(global_position: Vector2) -> Panel:
	"""Encuentra la columna en una posición global específica"""
	for column_panel in column_panels:
		var rect = Rect2(column_panel.global_position, column_panel.size)
		if rect.has_point(global_position):
			return column_panel
	return null

func move_task_to_column(task_id: int, new_column_id: int):
	"""Mueve una tarea a una nueva columna"""
	for task in kanban_data.tasks:
		if task.id == task_id:
			task.column_id = new_column_id
			break
	
	save_kanban_data()
	refresh_board()
	print("[KanbanManager] Tarea ", task_id, " movida a columna ", new_column_id)

func _on_add_task(column_id: int):
	"""Agrega una nueva tarea a una columna específica"""
	var new_task = {
		"id": kanban_data.next_task_id,
		"title": "Nueva Tarea",
		"description": "",
		"assignee": "",
		"due_date": "",
		"column_id": column_id,
		"created_date": Time.get_datetime_string_from_system()
	}
	
	kanban_data.tasks.append(new_task)
	kanban_data.next_task_id += 1
	
	# Abrir editor para la nueva tarea
	edit_task(new_task)

func edit_task(task_data: Dictionary):
	"""Abre el panel de edición para una tarea"""
	current_editing_task = task_data
	
	detail_title.text = task_data.title
	detail_description.text = task_data.description
	detail_assignee.text = task_data.assignee
	detail_due_date.text = task_data.due_date
	
	# Configurar selector de columna
	for i in range(detail_column_selector.get_item_count()):
		if detail_column_selector.get_item_id(i) == task_data.column_id:
			detail_column_selector.selected = i
			break
	
	task_detail_panel.visible = true

func _on_save_task():
	"""Guarda los cambios de la tarea actual"""
	if current_editing_task.is_empty():
		return
	
	current_editing_task.title = detail_title.text
	current_editing_task.description = detail_description.text
	current_editing_task.assignee = detail_assignee.text
	current_editing_task.due_date = detail_due_date.text
	
	# Actualizar columna si cambió
	if detail_column_selector.selected >= 0:
		var new_column_id = detail_column_selector.get_item_id(detail_column_selector.selected)
		current_editing_task.column_id = new_column_id
	
	save_kanban_data()
	task_detail_panel.visible = false
	current_editing_task.clear()
	refresh_board()

func _on_cancel_edit():
	"""Cancela la edición actual"""
	task_detail_panel.visible = false
	current_editing_task.clear()

func _on_delete_task():
	"""Elimina la tarea actual"""
	if current_editing_task.is_empty():
		return
	
	for i in range(kanban_data.tasks.size()):
		if kanban_data.tasks[i].id == current_editing_task.id:
			kanban_data.tasks.remove_at(i)
			break
	
	save_kanban_data()
	task_detail_panel.visible = false
	current_editing_task.clear()
	refresh_board()

# ============================================================================
# SISTEMA DE FILTROS CORREGIDO
# ============================================================================

func _on_filter_changed(value = null):
	"""Aplica los filtros actuales"""
	refresh_board()

func _on_clear_filters():
	"""Limpia todos los filtros"""
	filter_assignee.text = ""
	filter_status.selected = 0
	refresh_board()

func task_matches_filters(task_data: Dictionary) -> bool:
	"""Verifica si una tarea coincide con los filtros actuales"""
	if not task_data.has("assignee") or not task_data.has("column_id"):
		return false
	
	# Filtro por asignado
	var assignee_filter = filter_assignee.text.strip_edges().to_lower()
	if not assignee_filter.is_empty():
		var task_assignee = str(task_data.assignee).to_lower()
		if not task_assignee.contains(assignee_filter):
			return false
	
	# CORRECCIÓN: Filtro por estado/columna - Arreglado para "Todos los estados"
	var status_filter_index = filter_status.selected
	if status_filter_index > 0:  # 0 = "Todos los estados", índices > 0 son estados específicos
		var status_filter_id = filter_status.get_item_id(status_filter_index)
		var task_column_id = int(task_data.column_id)
		if task_column_id != status_filter_id:
			return false
	# Si status_filter_index == 0, no aplicamos filtro (mostrar todos)
	
	return true

# ============================================================================
# ACTUALIZACIÓN DE LA INTERFAZ
# ============================================================================

func refresh_board():
	"""Actualiza toda la visualización del tablero"""
	# Limpiar columnas existentes
	for child in columns_container.get_children():
		child.queue_free()
	
	column_panels.clear()
	task_cards.clear()
	
	# Crear columnas
	kanban_data.columns.sort_custom(func(a, b): return a.order < b.order)
	
	for column_data in kanban_data.columns:
		var column_panel = create_column_panel(column_data)
		columns_container.add_child(column_panel)
		column_panels.append(column_panel)
		
		# Agregar tareas a la columna
		var tasks_container = column_panel.find_child("TasksContainer", true, false)
		
		if tasks_container != null:
			for task_data in kanban_data.tasks:
				if task_data.has("column_id") and task_data.column_id == column_data.id and task_matches_filters(task_data):
					var task_card = create_task_card(task_data)
					tasks_container.add_child(task_card)
					task_cards.append(task_card)
		else:
			print("[KanbanManager] ERROR: No se pudo encontrar TasksContainer en columna ", column_data.name)
	
	# Actualizar estadísticas
	update_stats_display()

func update_stats_display():
	"""Actualiza el display de estadísticas"""
	var total_tasks = 0
	var visible_tasks = 0
	
	for task in kanban_data.tasks:
		total_tasks += 1
		if task_matches_filters(task):
			visible_tasks += 1
	
	var stats_text = "Tareas: %d" % visible_tasks
	if visible_tasks != total_tasks:
		stats_text += " de %d" % total_tasks
	stats_text += " | Columnas: %d" % kanban_data.columns.size()
	
	if stats_label:
		stats_label.text = stats_text

# ============================================================================
# INTEGRACIÓN CON FGGLOBAL Y UTILIDADES
# ============================================================================

func _notification(what):
	"""Maneja notificaciones del sistema"""
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_kanban_data()

func get_kanban_stats() -> Dictionary:
	"""Obtiene estadísticas del Kanban para integración con FGGlobal"""
	var stats = {
		"total_tasks": kanban_data.tasks.size(),
		"columns": kanban_data.columns.size(),
		"tasks_by_column": {},
		"tasks_with_assignee": 0,
		"tasks_with_due_date": 0,
		"overdue_tasks": 0
	}
	
	for column in kanban_data.columns:
		var count = 0
		for task in kanban_data.tasks:
			if task.has("column_id") and task.column_id == column.id:
				count += 1
		stats.tasks_by_column[column.name] = count
	
	# Estadísticas adicionales
	for task in kanban_data.tasks:
		if not task.assignee.is_empty():
			stats.tasks_with_assignee += 1
		if not task.due_date.is_empty():
			stats.tasks_with_due_date += 1
			# Aquí podrías agregar lógica para detectar tareas vencidas
	
	return stats

func export_kanban_data() -> String:
	"""Exporta los datos del Kanban como JSON string"""
	var export_data = kanban_data.duplicate(true)
	# Convertir Colors a strings para exportación
	for column in export_data.columns:
		if column.has("color") and column.color is Color:
			column.color = column.color.to_html()
	return JSON.stringify(export_data)

func import_kanban_data(json_data: String) -> bool:
	"""Importa datos del Kanban desde JSON string"""
	var json = JSON.new()
	var parse_result = json.parse(json_data)
	
	if parse_result != OK:
		print("[KanbanManager] Error importando datos: ", json.error_string)
		return false
	
	var imported_data = json.data
	if not imported_data.has("columns") or not imported_data.has("tasks"):
		print("[KanbanManager] Datos importados no tienen la estructura correcta")
		return false
	
	kanban_data = imported_data
	# Convertir strings de color a Color objects
	for column in kanban_data.columns:
		if column.has("color") and column.color is String:
			column.color = Color(column.color)
	
	save_kanban_data()
	setup_filters()
	refresh_board()
	print("[KanbanManager] Datos importados exitosamente")
	return true

# ============================================================================
# FUNCIONES DE UTILIDAD ADICIONALES
# ============================================================================

func get_tasks_by_assignee(assignee: String) -> Array:
	"""Obtiene todas las tareas asignadas a una persona específica"""
	var assigned_tasks = []
	for task in kanban_data.tasks:
		if task.has("assignee") and task.assignee.to_lower() == assignee.to_lower():
			assigned_tasks.append(task)
	return assigned_tasks

func get_tasks_by_due_date(date: String) -> Array:
	"""Obtiene todas las tareas con una fecha de vencimiento específica"""
	var due_tasks = []
	for task in kanban_data.tasks:
		if task.has("due_date") and task.due_date == date:
			due_tasks.append(task)
	return due_tasks

func get_column_by_id(column_id: int) -> Dictionary:
	"""Obtiene una columna por su ID"""
	for column in kanban_data.columns:
		if column.id == column_id:
			return column
	return {}

func get_task_by_id(task_id: int) -> Dictionary:
	"""Obtiene una tarea por su ID"""
	for task in kanban_data.tasks:
		if task.id == task_id:
			return task
	return {}

# ============================================================================
# FUNCIONES PARA MEJORAR LA EXPERIENCIA DE USUARIO
# ============================================================================

func _input(event):
	"""Maneja eventos globales de entrada"""
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if task_detail_panel.visible:
				_on_cancel_edit()
		elif event.keycode == KEY_ENTER and event.ctrl_pressed:
			if task_detail_panel.visible:
				_on_save_task()

func _ready_post():
	"""Configuración adicional después de _ready"""
	# Conectar señal de redimensionado para ajustar columnas
	get_viewport().size_changed.connect(_on_viewport_resized)

func _on_viewport_resized():
	"""Ajusta el layout cuando cambia el tamaño de la ventana"""
	if columns_container:
		# Ajustar tamaño mínimo de columnas basado en el ancho disponible
		var available_width = get_viewport().size.x - 40  # Margen
		var column_count = kanban_data.columns.size()
		if column_count > 0:
			var min_column_width = max(300, available_width / column_count - 20)
			for column_panel in column_panels:
				column_panel.custom_minimum_size.x = min_column_width

# ============================================================================
# FUNCIONES DE VALIDACIÓN Y LIMPIEZA
# ============================================================================

func validate_data():
	"""Valida y limpia los datos del Kanban"""
	var cleaned = false
	
	# Verificar que todas las tareas tengan column_id válido
	for task in kanban_data.tasks:
		if not task.has("column_id"):
			task.column_id = 1  # Asignar a "Por Hacer"
			cleaned = true
		else:
			var column_exists = false
			for column in kanban_data.columns:
				if column.id == task.column_id:
					column_exists = true
					break
			if not column_exists:
				task.column_id = 1  # Mover a "Por Hacer" si la columna no existe
				cleaned = true
	
	# Verificar que todas las columnas tengan propiedades requeridas
	for column in kanban_data.columns:
		if not column.has("order"):
			column.order = kanban_data.columns.find(column)
			cleaned = true
		if not column.has("color"):
			column.color = default_colors[0]
			cleaned = true
	
	if cleaned:
		save_kanban_data()
		print("[KanbanManager] Datos limpiados y corregidos")

# Llamar validación al inicio
func _ready_final():
	validate_data()
