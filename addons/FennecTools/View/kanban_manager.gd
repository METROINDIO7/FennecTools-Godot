@tool
extends Control

# ============================================================================
# FENNEC TOOLS - ENHANCED KANBAN BOARD MANAGER
# Kanban-style task management system with drag & drop and corrected filters
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

# New: Column selector in the detail panel
@onready var detail_column_selector: OptionButton

# Filters
@onready var filter_assignee: LineEdit = $VBoxContainer/FilterPanel/HBoxContainer/FilterAssignee
@onready var filter_status: OptionButton = $VBoxContainer/FilterPanel/HBoxContainer/FilterStatus
@onready var filter_clear_btn: Button = $VBoxContainer/FilterPanel/HBoxContainer/ClearFiltersButton

# Stats
@onready var stats_label: Label = $VBoxContainer/HeaderPanel/HBoxContainer/StatsLabel

# Column Management
@onready var add_column_btn: Button = $VBoxContainer/ColumnManagement/HBoxContainer/AddColumnButton
@onready var column_name_input: LineEdit = $VBoxContainer/ColumnManagement/HBoxContainer/ColumnNameInput
@onready var column_color_input: LineEdit = $VBoxContainer/ColumnManagement/HBoxContainer/ColumnColorInput

# System variables
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

# Drag & drop variables
var dragging_task: Control = null
var drag_preview: Control = null
var drag_offset: Vector2 = Vector2.ZERO

# Improved default colors
var default_colors: Array[Color] = [
	Color("#3498DB"),    # To Do - Blue
	Color("#F39C12"),    # In Progress - Orange
	Color("#2ECC71")     # Completed - Green
]

# ============================================================================
# INITIALIZATION
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
	"""Sets up default columns if they don't exist"""
	if kanban_data.columns.is_empty():
		kanban_data.columns = [
			{
				"id": 1,
				"name": "To Do",
				"color": default_colors[0],
				"order": 0
			},
			{
				"id": 2, 
				"name": "In Progress",
				"color": default_colors[1],
				"order": 1
			},
			{
				"id": 3,
				"name": "Completed", 
				"color": default_colors[2],
				"order": 2
			}
		]
		kanban_data.next_column_id = 4

func create_detail_column_selector():
	"""Creates the column selector in the details panel"""
	var container = $VBoxContainer/MainContent/TaskDetailPanel/VBoxContainer/HBoxContainer
	
	# Add container for the status selector
	var state_vbox = VBoxContainer.new()
	state_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(state_vbox)
	
	var state_label = Label.new()
	state_label.text = "Status:"
	state_vbox.add_child(state_label)
	
	detail_column_selector = OptionButton.new()
	detail_column_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state_vbox.add_child(detail_column_selector)

func setup_ui_connections():
	"""Connects the interface signals"""
	detail_save_btn.pressed.connect(_on_save_task)
	detail_cancel_btn.pressed.connect(_on_cancel_edit)
	detail_delete_btn.pressed.connect(_on_delete_task)
	
	add_column_btn.pressed.connect(_on_add_column)
	filter_clear_btn.pressed.connect(_on_clear_filters)
	
	filter_assignee.text_changed.connect(_on_filter_changed)
	filter_status.item_selected.connect(_on_filter_changed)

func setup_filters():
	"""Configures the available filters"""
	filter_status.clear()
	filter_status.add_item("All statuses", -1)  # Index 0, ID -1
	
	# Also configure the column selector in details
	if detail_column_selector:
		detail_column_selector.clear()
	
	# Add columns with their real IDs
	for column in kanban_data.columns:
		filter_status.add_item(column.name, column.id)  # Índices 1+, IDs reales
		if detail_column_selector:
			detail_column_selector.add_item(column.name, column.id)
	
	# Ensure "All statuses" is selected by default
	filter_status.selected = 0


# ============================================================================
# DATA MANAGEMENT
# ============================================================================

func load_kanban_data():
	"""Loads Kanban data from JSON"""
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
					# Convert color strings to Color objects
					for column in kanban_data.columns:
						if column.has("color") and column.color is String:
							column.color = Color(column.color)
				if loaded_data.has("tasks"):
					kanban_data.tasks = loaded_data.tasks
				if loaded_data.has("next_task_id"):
					kanban_data.next_task_id = loaded_data.next_task_id
				if loaded_data.has("next_column_id"):
					kanban_data.next_column_id = loaded_data.next_column_id
	else:
		pass # Data file does not exist, using default values

func save_kanban_data():
	"""Saves Kanban data to JSON"""
	var file = FileAccess.open(kanban_data_path, FileAccess.WRITE)
	if file:
		# Create a copy to save, converting Colors to strings
		var save_data = kanban_data.duplicate(true)
		for column in save_data.columns:
			if column.has("color") and column.color is Color:
				column.color = column.color.to_html()
		
		var json_string = JSON.stringify(save_data)
		file.store_string(json_string)
		file.close()
	else:
		pass # Error saving data

# ============================================================================
# COLUMN MANAGEMENT
# ============================================================================

func create_column_panel(column_data: Dictionary) -> Panel:
	"""Creates a visual panel for a column"""
	var column_panel = Panel.new()
	column_panel.custom_minimum_size = Vector2(320, 400)
	column_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Apply improved background color
	var style_box = StyleBoxFlat.new()
	var base_color = column_data.color if column_data.color is Color else Color(column_data.color)
	style_box.bg_color = base_color
	style_box.bg_color.a = 0.15  # More subtle transparency
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
	
	# Column header
	var header = create_column_header(column_data)
	vbox.add_child(header)
	
	# Task container with drag & drop
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	var tasks_container = VBoxContainer.new()
	tasks_container.name = "TasksContainer"
	tasks_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tasks_container.add_theme_constant_override("separation", 8)
	scroll.add_child(tasks_container)
	
	# Button to add task
	var add_task_btn = Button.new()
	add_task_btn.text = "+ Add Task"
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
	"""Creates a column header with title and options"""
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	
	# Color indicator
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
	
	# Task counter
	var count = get_task_count_for_column(column_data.id)
	var count_label = Label.new()
	count_label.text = "(" + str(count) + ")"
	count_label.add_theme_font_size_override("font_size", 12)
	count_label.add_theme_color_override("font_color", Color.GRAY)
	header.add_child(count_label)
	
	# FIX: Show delete button for ALL columns, but disabled for default ones
	var delete_btn = Button.new()
	delete_btn.text = "×"
	delete_btn.flat = true
	delete_btn.custom_minimum_size = Vector2(28, 28)
	delete_btn.add_theme_font_size_override("font_size", 18)
	
	if column_data.id <= 3:  # Default columns
		delete_btn.disabled = true
		delete_btn.tooltip_text = "Default columns cannot be deleted"
		delete_btn.add_theme_color_override("font_color", Color.GRAY)
	else:  # Custom columns
		delete_btn.add_theme_color_override("font_color", Color.RED)
		delete_btn.tooltip_text = "Delete column (tasks will be moved to 'To Do')"
		delete_btn.pressed.connect(_on_delete_column.bind(column_data.id))
	
	header.add_child(delete_btn)
	
	return header


func get_task_count_for_column(column_id: int) -> int:
	"""Gets the number of tasks in a column"""
	var count = 0
	for task in kanban_data.tasks:
		if task.has("column_id") and task.column_id == column_id and task_matches_filters(task):
			count += 1
	return count

func _on_add_column():
	"""Adds a new custom column"""
	var column_name = column_name_input.text.strip_edges()
	if column_name.is_empty():
		column_name = "New Column"
	
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
	"""Deletes a custom column"""
	if column_id <= 3:  # Do not allow deleting default columns
		return
	
	# Move tasks from this column to "To Do"
	for task in kanban_data.tasks:
		if task.has("column_id") and task.column_id == column_id:
			task.column_id = 1  # To Do
	
	# Delete column
	for i in range(kanban_data.columns.size()):
		if kanban_data.columns[i].id == column_id:
			kanban_data.columns.remove_at(i)
			break
	
	save_kanban_data()
	setup_filters()
	refresh_board()

func parse_hex_color(hex_string: String) -> Color:
	"""Converts a hexadecimal code to Color"""
	hex_string = hex_string.strip_edges()
	if hex_string.is_empty():
		return Color("#9B59B6")  # Default purple color
	
	# Remove # if it exists
	if hex_string.begins_with("#"):
		hex_string = hex_string.substr(1)
	
	# Validate length and characters
	if hex_string.length() != 6:
		return Color("#9B59B6")
	
	# Verify that it only contains hexadecimal characters
	for char in hex_string:
		if not char.to_lower() in "0123456789abcdef":
			return Color("#9B59B6")
	
	return Color("#" + hex_string)

# ============================================================================
# TASK MANAGEMENT WITH DRAG & DROP
# ============================================================================

func create_task_card(task_data: Dictionary) -> Control:
	"""Creates a visual card for a task with drag & drop capability"""
	var card = Panel.new()
	card.custom_minimum_size = Vector2(290, 100)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Improved card style
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
	
	# Border color according to column
	var border_color = get_column_color(task_data.column_id)
	style_box.border_color = border_color
	
	# Subtle shadow
	style_box.shadow_color = Color.BLACK
	style_box.shadow_color.a = 0.1
	style_box.shadow_size = 2
	
	card.add_theme_stylebox_override("panel", style_box)
	
	var vbox = VBoxContainer.new()
	card.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 6)
	
	# Task title
	var title_label = Label.new()
	title_label.text = task_data.title
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color.BLACK)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	vbox.add_child(title_label)
	
	# Short description if it exists
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
	
	# Additional information
	var info_container = HBoxContainer.new()
	vbox.add_child(info_container)
	
	# Assigned to
	if not task_data.assignee.is_empty():
		var assignee_label = Label.new()
		assignee_label.text = "👤 " + task_data.assignee
		assignee_label.add_theme_font_size_override("font_size", 10)
		assignee_label.add_theme_color_override("font_color", Color.DIM_GRAY)
		info_container.add_child(assignee_label)
	
	# Due date
	if not task_data.due_date.is_empty():
		var due_label = Label.new()
		due_label.text = "📅 " + task_data.due_date
		due_label.add_theme_font_size_override("font_size", 10)
		due_label.add_theme_color_override("font_color", Color.DIM_GRAY)
		info_container.add_child(due_label)
	
	# Configure drag & drop and click
	card.set_meta("task_id", task_data.id)
	card.set_meta("task_data", task_data)
	card.set_meta("draggable", true)
	
	# Connect mouse events for drag & drop
	card.gui_input.connect(_on_task_card_input.bind(card))
	
	return card

func get_column_color(column_id: int) -> Color:
	"""Gets the color of a column by its ID"""
	for column in kanban_data.columns:
		if column.id == column_id:
			return column.color if column.color is Color else Color(column.color)
	return Color.GRAY

func _on_task_card_input(event: InputEvent, card: Control):
	"""Handles mouse input on task cards"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if event.double_click:
					# Double click to edit
					var task_data = card.get_meta("task_data")
					edit_task(task_data)
				else:
					# Start drag
					start_drag(card, event.position)
			else:
				# End drag
				end_drag(event.global_position)
	elif event is InputEventMouseMotion and dragging_task != null:
		# Update drag position
		update_drag(event.global_position)

func start_drag(card: Control, local_position: Vector2):
	"""Starts dragging a card"""
	dragging_task = card
	drag_offset = local_position
	
	# Create visual preview
	create_drag_preview(card)
	
	# Change z-index to appear on top
	card.z_index = 100
	card.modulate.a = 0.7

func create_drag_preview(card: Control):
	"""Creates a visual preview of the element being dragged"""
	drag_preview = card.duplicate()
	get_viewport().add_child(drag_preview)
	drag_preview.modulate = Color(1, 1, 1, 0.8)
	drag_preview.z_index = 1000

func update_drag(global_position: Vector2):
	"""Updates the position of the drag preview"""
	if drag_preview:
		drag_preview.global_position = global_position - drag_offset

func end_drag(global_position: Vector2):
	"""Ends the drag and handles the drop"""
	if dragging_task == null:
		return
	
	# Restore original appearance
	dragging_task.z_index = 0
	dragging_task.modulate.a = 1.0
	
	# Find target column
	var target_column = find_column_at_position(global_position)
	if target_column != null:
		var task_data = dragging_task.get_meta("task_data")
		var old_column_id = task_data.column_id
		var new_column_id = target_column.get_meta("column_id")
		
		if old_column_id != new_column_id:
			# Change task column
			move_task_to_column(task_data.id, new_column_id)
	
	# Clear drag
	if drag_preview:
		drag_preview.queue_free()
		drag_preview = null
	
	dragging_task = null

func find_column_at_position(global_position: Vector2) -> Panel:
	"""Finds the column at a specific global position"""
	for column_panel in column_panels:
		var rect = Rect2(column_panel.global_position, column_panel.size)
		if rect.has_point(global_position):
			return column_panel
	return null

func move_task_to_column(task_id: int, new_column_id: int):
	"""Moves a task to a new column"""
	for task in kanban_data.tasks:
		if task.id == task_id:
			task.column_id = new_column_id
			break
	
	save_kanban_data()
	refresh_board()

func _on_add_task(column_id: int):
	"""Adds a new task to a specific column"""
	var new_task = {
		"id": kanban_data.next_task_id,
		"title": "New Task",
		"description": "",
		"assignee": "",
		"due_date": "",
		"column_id": column_id,
		"created_date": Time.get_datetime_string_from_system()
	}
	
	kanban_data.tasks.append(new_task)
	kanban_data.next_task_id += 1
	
	# Open editor for the new task
	edit_task(new_task)

func edit_task(task_data: Dictionary):
	"""Opens the editing panel for a task"""
	current_editing_task = task_data
	
	detail_title.text = task_data.title
	detail_description.text = task_data.description
	detail_assignee.text = task_data.assignee
	detail_due_date.text = task_data.due_date
	
	# Configure column selector
	for i in range(detail_column_selector.get_item_count()):
		if detail_column_selector.get_item_id(i) == task_data.column_id:
			detail_column_selector.selected = i
			break
	
	task_detail_panel.visible = true

func _on_save_task():
	"""Saves the changes of the current task"""
	if current_editing_task.is_empty():
		return
	
	current_editing_task.title = detail_title.text
	current_editing_task.description = detail_description.text
	current_editing_task.assignee = detail_assignee.text
	current_editing_task.due_date = detail_due_date.text
	
	# Update column if it changed
	if detail_column_selector.selected >= 0:
		var new_column_id = detail_column_selector.get_item_id(detail_column_selector.selected)
		current_editing_task.column_id = new_column_id
	
	save_kanban_data()
	task_detail_panel.visible = false
	current_editing_task = {}
	refresh_board()

func _on_cancel_edit():
	"""Cancels the current edit"""
	task_detail_panel.visible = false
	current_editing_task = {}

func _on_delete_task():
	"""Deletes the current task"""
	if current_editing_task.is_empty():
		return
	
	for i in range(kanban_data.tasks.size()):
		if kanban_data.tasks[i].get("id") == current_editing_task.get("id"):
			kanban_data.tasks.remove_at(i)
			break
	
	save_kanban_data()
	task_detail_panel.visible = false
	current_editing_task = {}
	refresh_board()

# ============================================================================
# CORRECTED FILTER SYSTEM
# ============================================================================

func _on_filter_changed(value = null):
	"""Applies the current filters"""
	refresh_board()

func _on_clear_filters():
	"""Clears all filters"""
	filter_assignee.text = ""
	filter_status.selected = 0
	refresh_board()

func task_matches_filters(task_data: Dictionary) -> bool:
	"""Checks if a task matches the current filters"""
	if not task_data.has("assignee") or not task_data.has("column_id"):
		return false
	
	# Filter by assignee
	var assignee_filter = filter_assignee.text.strip_edges().to_lower()
	if not assignee_filter.is_empty():
		var task_assignee = str(task_data.assignee).to_lower()
		if not task_assignee.contains(assignee_filter):
			return false
	
	# FIX: Filter by status/column - Fixed for "All statuses"
	var status_filter_index = filter_status.selected
	if status_filter_index > 0:  # 0 = "All statuses", indices > 0 are specific statuses
		var status_filter_id = filter_status.get_item_id(status_filter_index)
		var task_column_id = int(task_data.column_id)
		if task_column_id != status_filter_id:
			return false
	# If status_filter_index == 0, we don't apply a filter (show all)
	
	return true

# ============================================================================
# INTERFACE UPDATE
# ============================================================================

func refresh_board():
	"""Updates the entire board display"""
	# Clear existing columns
	for child in columns_container.get_children():
		child.queue_free()
	
	column_panels.clear()
	task_cards.clear()
	
	# Get the current status filter
	var status_filter_index = filter_status.selected
	var status_filter_id = -1
	if status_filter_index >= 0:
		status_filter_id = filter_status.get_item_id(status_filter_index)

	# Create columns
	kanban_data.columns.sort_custom(func(a, b): return a.order < b.order)
	
	for column_data in kanban_data.columns:
		# Check if the column should be displayed based on the filter
		var should_display = true
		if status_filter_index > 0:
			if column_data.id != status_filter_id:
				should_display = false
		
		if should_display:
			var column_panel = create_column_panel(column_data)
			columns_container.add_child(column_panel)
			column_panels.append(column_panel)
			
			# Add tasks to the column
			var tasks_container = column_panel.find_child("TasksContainer", true, false)
			
			if tasks_container != null:
				for task_data in kanban_data.tasks:
					if task_data.has("column_id") and task_data.column_id == column_data.id and task_matches_filters(task_data):
						var task_card = create_task_card(task_data)
						tasks_container.add_child(task_card)
						task_cards.append(task_card)
			else:
				pass # ERROR: Could not find TasksContainer in column
	
	# Update statistics
	update_stats_display()

func update_stats_display():
	"""Updates the statistics display"""
	var total_tasks = 0
	var visible_tasks = 0
	
	for task in kanban_data.tasks:
		total_tasks += 1
		if task_matches_filters(task):
			visible_tasks += 1
	
	var stats_text = "Tasks: %d" % visible_tasks
	if visible_tasks != total_tasks:
		stats_text += " of %d" % total_tasks
	stats_text += " | Columns: %d" % kanban_data.columns.size()
	
	if stats_label:
		stats_label.text = stats_text

# ============================================================================
# INTEGRATION WITH FGGLOBAL AND UTILITIES
# ============================================================================

func _notification(what):
	"""Handles system notifications"""
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_kanban_data()

func get_kanban_stats() -> Dictionary:
	"""Gets Kanban statistics for integration with FGGlobal"""
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
	
	# Additional statistics
	for task in kanban_data.tasks:
		if not task.assignee.is_empty():
			stats.tasks_with_assignee += 1
		if not task.due_date.is_empty():
			stats.tasks_with_due_date += 1
			# Here you could add logic to detect overdue tasks
	
	return stats

func export_kanban_data() -> String:
	"""Exports Kanban data as a JSON string"""
	var export_data = kanban_data.duplicate(true)
	# Convert Colors to strings for export
	for column in export_data.columns:
		if column.has("color") and column.color is Color:
			column.color = column.color.to_html()
	return JSON.stringify(export_data)

func import_kanban_data(json_data: String) -> bool:
	"""Imports Kanban data from a JSON string"""
	var json = JSON.new()
	var parse_result = json.parse(json_data)
	
	if parse_result != OK:
		return false
	
	var imported_data = json.data
	if not imported_data.has("columns") or not imported_data.has("tasks"):
		return false
	
	kanban_data = imported_data
	# Convert color strings to Color objects
	for column in kanban_data.columns:
		if column.has("color") and column.color is String:
			column.color = Color(column.color)
	
	save_kanban_data()
	setup_filters()
	refresh_board()
	return true

# ============================================================================
# ADDITIONAL UTILITY FUNCTIONS
# ============================================================================

func get_tasks_by_assignee(assignee: String) -> Array:
	"""Gets all tasks assigned to a specific person"""
	var assigned_tasks = []
	for task in kanban_data.tasks:
		if task.has("assignee") and task.assignee.to_lower() == assignee.to_lower():
			assigned_tasks.append(task)
	return assigned_tasks

func get_tasks_by_due_date(date: String) -> Array:
	"""Gets all tasks with a specific due date"""
	var due_tasks = []
	for task in kanban_data.tasks:
		if task.has("due_date") and task.due_date == date:
			due_tasks.append(task)
	return due_tasks

func get_column_by_id(column_id: int) -> Dictionary:
	"""Gets a column by its ID"""
	for column in kanban_data.columns:
		if column.id == column_id:
			return column
	return {}

func get_task_by_id(task_id: int) -> Dictionary:
	"""Gets a task by its ID"""
	for task in kanban_data.tasks:
		if task.id == task_id:
			return task
	return {}

# ============================================================================
# FUNCTIONS TO IMPROVE USER EXPERIENCE
# ============================================================================

func _input(event):
	"""Handles global input events"""
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if task_detail_panel.visible:
				_on_cancel_edit()
		elif event.keycode == KEY_ENTER and event.ctrl_pressed:
			if task_detail_panel.visible:
				_on_save_task()

func _ready_post():
	"""Additional configuration after _ready"""
	# Connect resize signal to adjust columns
	get_viewport().size_changed.connect(_on_viewport_resized)

func _on_viewport_resized():
	"""Adjusts the layout when the window size changes"""
	if columns_container:
		# Adjust minimum column size based on available width
		var available_width = get_viewport().size.x - 40  # Margin
		var column_count = kanban_data.columns.size()
		if column_count > 0:
			var min_column_width = max(300, available_width / column_count - 20)
			for column_panel in column_panels:
				column_panel.custom_minimum_size.x = min_column_width

# ============================================================================
# VALIDATION AND CLEANUP FUNCTIONS
# ============================================================================

func validate_data():
	"""Validates and cleans Kanban data"""
	var cleaned = false
	
	# Verify that all tasks have a valid column_id
	for task in kanban_data.tasks:
		if not task.has("column_id"):
			task.column_id = 1  # Assign to "To Do"
			cleaned = true
		else:
			var column_exists = false
			for column in kanban_data.columns:
				if column.id == task.column_id:
					column_exists = true
					break
			if not column_exists:
				task.column_id = 1  # Move to "To Do" if the column does not exist
				cleaned = true
	
	# Verify that all columns have required properties
	for column in kanban_data.columns:
		if not column.has("order"):
			column.order = kanban_data.columns.find(column)
			cleaned = true
		if not column.has("color"):
			column.color = default_colors[0]
			cleaned = true
	
	if cleaned:
		save_kanban_data()

# Call validation at startup
func _ready_final():
	validate_data()
