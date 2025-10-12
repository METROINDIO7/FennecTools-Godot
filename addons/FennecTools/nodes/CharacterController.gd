@tool
extends Node

# Character Controller with an expression state system based on child nodes
# ✨ AHORA CON SOPORTE PARA RETORNO AUTOMÁTICO DE ESTADOS

@export var character_group_name: String = ""

@export_group("Expression States")
@export var default_state_id: int = 0
@export var states_container_path: NodePath = "ExpressionStates"

@export_group("Mouth Talking (Blendshapes)")
@export var mouth_targets_mesh: Array[NodePath] = []
@export var mouth_blendshape_index: int = 0
@export var mouth_intensity: float = 1.0

@export_group("Mouth Talking (Animations)")
@export var mouth_targets_plays: Array[NodePath] = []
@export var mouth_open_animation: String = "mouth_open"
@export var mouth_closed_animation: String = "mouth_closed"

@export_group("Mouth Settings")
@export var mouth_interval: float = 0.1
@export var use_random_interval: bool = true
@export var mouth_interval_min: float = 0.05
@export var mouth_interval_max: float = 0.15

@export_group("Performance")
@export var enable_node_caching: bool = true

# States and cache
var _expression_states: Dictionary = {}  # state_id -> ExpressionState
var _current_state_id: int = -1
var _node_cache: Dictionary = {}
var _talking: bool = false
var _mouth_task_running: bool = false

# ✨ NUEVO: Sistema de retorno automático
var _current_dialog_panel: Node = null
var _return_connection_active: bool = false

func _ready() -> void:
	if character_group_name != "":
		add_to_group(character_group_name)
	
	_rebuild_caches()
	_setup_expression_states()
	
	# Activate default state
	if default_state_id in _expression_states:
		set_expression_state(default_state_id)

# =====================
# Cache Management
# =====================
func _rebuild_caches() -> void:
	if not enable_node_caching:
		return
	
	_node_cache.clear()
	
	# Cache mouth nodes
	for path in mouth_targets_mesh:
		if path != NodePath(""):
			var node = get_node_or_null(path)
			if node:
				_node_cache[path] = node
	
	for path in mouth_targets_plays:
		if path != NodePath(""):
			var node = get_node_or_null(path)
			if node:
				_node_cache[path] = node

func _get_cached_node(path: NodePath) -> Node:
	if enable_node_caching and _node_cache.has(path):
		return _node_cache[path]
	
	var node = get_node_or_null(path)
	if enable_node_caching and node:
		_node_cache[path] = node
	
	return node

# =====================
# Expression States System
# =====================
func _setup_expression_states() -> void:
	_expression_states.clear()
	
	var container = get_node_or_null(states_container_path)
	if not container:
		# Automatically search for the container
		container = _find_expression_states_container()
	
	if not container:
		return
	
	for child in container.get_children():
		if child is ExpressionState:
			var state = child as ExpressionState
			_expression_states[state.state_id] = state
			
			# ✨ NUEVO: Conectar señal de retorno
			if not state.return_requested.is_connected(_on_state_return_requested):
				state.return_requested.connect(_on_state_return_requested)

func _find_expression_states_container() -> Node:
	# Search by name
	var container = get_node_or_null("ExpressionStates")
	if container:
		return container
	
	# Search for any child that has ExpressionState nodes
	for child in get_children():
		for grandchild in child.get_children():
			if grandchild is ExpressionState:
				return child
	
	return null

# ✨ MEJORADO: Ahora con soporte para retorno automático
func set_expression_state(state_id: int, dialog_panel: Node = null) -> void:
	if state_id == _current_state_id:
		return
	
	# Deactivate current state
	if _current_state_id in _expression_states:
		var current_state = _expression_states[_current_state_id]
		current_state.deactivate()
	
	# Activate new state
	if state_id in _expression_states:
		var new_state = _expression_states[state_id]
		new_state.activate()
		_current_state_id = state_id
		
		# ✨ NUEVO: Iniciar secuencia de retorno si está configurada
		if new_state.should_auto_return():
			_current_dialog_panel = dialog_panel
			new_state.start_return_sequence(dialog_panel)
	else:
		# Try default state
		if default_state_id in _expression_states and state_id != default_state_id:
			set_expression_state(default_state_id, dialog_panel)

# ✨ NUEVO: Callback para cuando un estado solicita regresar
func _on_state_return_requested(target_state_id: int) -> void:
	# Determinar el estado objetivo
	var target_id = target_state_id if target_state_id >= 0 else default_state_id
	
	# Cambiar al estado objetivo
	set_expression_state(target_id)
	
	# Limpiar referencia al panel de diálogo
	_current_dialog_panel = null

# ✅ CRITICAL COMPATIBILITY: This is the method called by DialogueLauncher
# ✨ MEJORADO: Ahora acepta referencia al DialogPanel
func set_expression_by_id(expression_id: int, dialog_panel: Node = null) -> void:
	set_expression_state(expression_id, dialog_panel)

# ✅ CRITICAL METHOD: Check if an expression exists
func has_expression_index(expression_id: int) -> bool:
	return expression_id in _expression_states

# ✅ ADDITIONAL METHOD: For compatibility with FGGlobal
func has_expression_state(state_id: int) -> bool:
	return state_id in _expression_states

func get_current_state_id() -> int:
	return _current_state_id

func get_current_state_name() -> String:
	if _current_state_id in _expression_states:
		return _expression_states[_current_state_id].state_name
	return ""

# ✅ Compatibility with DialogueLauncher
func get_current_expression_name() -> String:
	return get_current_state_name()

func get_expression_states_info() -> Array:
	var info = []
	for state_id in _expression_states:
		var state = _expression_states[state_id]
		info.append({
			"id": state_id,
			"name": state.state_name,
			"active": state.is_active()
		})
	return info

# ✨ NUEVO: Cancelar retorno automático del estado actual
func cancel_auto_return() -> void:
	if _current_state_id in _expression_states:
		var current_state = _expression_states[_current_state_id]
		current_state.cancel_return_sequence()
	_current_dialog_panel = null

# =====================
# Mouth System - IMPORTANT: Works independently of expressions
# =====================
func start_talking() -> void:
	_talking = true
	if not _mouth_task_running:
		_mouth_task_running = true
		_mouth_loop()

func stop_talking() -> void:
	_talking = false

func _mouth_loop() -> void:
	while _talking:
		var interval = mouth_interval
		if use_random_interval:
			interval = randf_range(mouth_interval_min, mouth_interval_max)
		
		_animate_mouth_3d()
		_animate_mouth_2d(true)
		await get_tree().create_timer(interval).timeout
	
	_mouth_task_running = false
	_reset_mouth_3d()
	_reset_mouth_2d()

func _animate_mouth_3d() -> void:
	for path in mouth_targets_mesh:
		var mesh = _get_cached_node(path) as MeshInstance3D
		if mesh and mesh.get_mesh() and mouth_blendshape_index >= 0:
			var v = randf_range(0.0, 1.0) * mouth_intensity
			_set_blend_shape_on_mesh(mesh, mouth_blendshape_index, v)

func _animate_mouth_2d(open: bool) -> void:
	for path in mouth_targets_plays:
		var node = _get_cached_node(path)
		if not node:
			continue
		
		if node is AnimationPlayer:
			var anim_player := node as AnimationPlayer
			var anim_name = mouth_open_animation if open else mouth_closed_animation
			
			if anim_player.has_animation(anim_name):
				# IMPORTANT: Do not interrupt expression animations
				# Only play if an expression animation is not already playing
				if not _is_playing_expression_animation(anim_player):
					anim_player.play(anim_name)
		
		elif node is AnimatedSprite2D:
			var sprite := node as AnimatedSprite2D
			var anim_name = mouth_open_animation if open else mouth_closed_animation
			
			if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
				sprite.play(anim_name)

func _is_playing_expression_animation(anim_player: AnimationPlayer) -> bool:
	# Check if the AnimationPlayer is being used by any active expression
	if _current_state_id in _expression_states:
		var current_state = _expression_states[_current_state_id]
		for path in current_state.animation_nodes:
			var node = get_node_or_null(path)
			if node == anim_player and anim_player.is_playing():
				# If it is playing and it is not a mouth animation, it is an expression
				var current_anim = anim_player.current_animation
				if current_anim != mouth_open_animation and current_anim != mouth_closed_animation:
					return true
	return false

func _reset_mouth_3d() -> void:
	for path in mouth_targets_mesh:
		var mesh = _get_cached_node(path) as MeshInstance3D
		if mesh:
			_set_blend_shape_on_mesh(mesh, mouth_blendshape_index, 0.0)

func _reset_mouth_2d() -> void:
	for path in mouth_targets_plays:
		var node = _get_cached_node(path)
		if not node:
			continue
		
		if node is AnimationPlayer:
			var anim_player := node as AnimationPlayer
			if anim_player.has_animation(mouth_closed_animation):
				if not _is_playing_expression_animation(anim_player):
					anim_player.play(mouth_closed_animation)
			else:
				anim_player.stop()
		
		elif node is AnimatedSprite2D:
			var sprite := node as AnimatedSprite2D
			if sprite.sprite_frames and sprite.sprite_frames.has_animation(mouth_closed_animation):
				sprite.play(mouth_closed_animation)
			else:
				sprite.stop()

func _set_blend_shape_on_mesh(mesh_instance: MeshInstance3D, index: int, value: float) -> void:
	var mesh = mesh_instance.get_mesh()
	if mesh and index >= 0 and index < mesh.get_blend_shape_count():
		mesh_instance.set("blend_shapes/%s" % mesh.get_blend_shape_name(index), value)



@export var _refresh_states: bool = false:
	set(value):
		if value:
			_refresh_states = false
			_setup_expression_states()

# =====================
# Public API
# =====================
func add_expression_state(state: ExpressionState) -> void:
	if not state:
		return
	
	_expression_states[state.state_id] = state
	
	# ✨ NUEVO: Conectar señal de retorno
	if not state.return_requested.is_connected(_on_state_return_requested):
		state.return_requested.connect(_on_state_return_requested)
	
	if not state.get_parent():
		var container = get_node_or_null(states_container_path)
		if container:
			container.add_child(state)
		else:
			add_child(state)

func remove_expression_state(state_id: int) -> void:
	if state_id in _expression_states:
		var state = _expression_states[state_id]
		if state.is_active():
			state.deactivate()
		
		# ✨ NUEVO: Desconectar señal
		if state.return_requested.is_connected(_on_state_return_requested):
			state.return_requested.disconnect(_on_state_return_requested)
		
		_expression_states.erase(state_id)
		state.queue_free()
		
		# If we delete the active state, reset
		if _current_state_id == state_id:
			_current_state_id = -1

# ✅ PROPERTIES FOR COMPATIBILITY
var default_expression_index: int:
	get:
		return default_state_id
