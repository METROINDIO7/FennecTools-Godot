@tool
extends Node

# Character Controller con sistema de estados de expresión basado en nodos hijos

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

# Estados y cache
var _expression_states: Dictionary = {}  # state_id -> ExpressionState
var _current_state_id: int = -1
var _node_cache: Dictionary = {}
var _talking: bool = false
var _mouth_task_running: bool = false

func _ready() -> void:
	if character_group_name != "":
		add_to_group(character_group_name)
		print("[CharacterController] Added to group: ", character_group_name)
	
	_rebuild_caches()
	_setup_expression_states()
	
	# Activar estado por defecto
	if default_state_id in _expression_states:
		set_expression_state(default_state_id)

# =====================
# Cache Management
# =====================
func _rebuild_caches() -> void:
	if not enable_node_caching:
		return
	
	_node_cache.clear()
	
	# Cachear nodos de boca
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
		# Buscar automáticamente el contenedor
		container = _find_expression_states_container()
	
	if not container:
		print("[CharacterController] No expression states container found")
		return
	
	print("[CharacterController] Setting up expression states from container: ", container.name)
	
	for child in container.get_children():
		if child is ExpressionState:
			var state = child as ExpressionState
			_expression_states[state.state_id] = state
			print("[CharacterController] Registered expression state: ID=", state.state_id, " Name=", state.state_name)

func _find_expression_states_container() -> Node:
	# Buscar por nombre
	var container = get_node_or_null("ExpressionStates")
	if container:
		return container
	
	# Buscar cualquier hijo que tenga nodos ExpressionState
	for child in get_children():
		for grandchild in child.get_children():
			if grandchild is ExpressionState:
				return child
	
	return null

func set_expression_state(state_id: int) -> void:
	print("[CharacterController] Setting expression state: ", state_id)
	
	if state_id == _current_state_id:
		print("[CharacterController] State already active: ", state_id)
		return
	
	# Desactivar estado actual
	if _current_state_id in _expression_states:
		var current_state = _expression_states[_current_state_id]
		current_state.deactivate()
	
	# Activar nuevo estado
	if state_id in _expression_states:
		var new_state = _expression_states[state_id]
		new_state.activate()
		_current_state_id = state_id
		print("[CharacterController] State activated: ", new_state.state_name)
	else:
		print("[CharacterController] State ID not found: ", state_id)
		# Intentar estado por defecto
		if default_state_id in _expression_states and state_id != default_state_id:
			set_expression_state(default_state_id)

# ✅ COMPATIBILIDAD CRÍTICA: Este es el método que llama DialogueLauncher
func set_expression_by_id(expression_id: int) -> void:
	print("[CharacterController] set_expression_by_id called with: ", expression_id)
	set_expression_state(expression_id)

# ✅ MÉTODO CRÍTICO: Verificar si una expresión existe
func has_expression_index(expression_id: int) -> bool:
	return expression_id in _expression_states

# ✅ MÉTODO ADICIONAL: Para compatibilidad con FGGlobal
func has_expression_state(state_id: int) -> bool:
	return state_id in _expression_states

func get_current_state_id() -> int:
	return _current_state_id

func get_current_state_name() -> String:
	if _current_state_id in _expression_states:
		return _expression_states[_current_state_id].state_name
	return ""

# ✅ Compatibilidad con DialogueLauncher
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

# =====================
# Mouth System - IMPORTANTE: Funciona independientemente de las expresiones
# =====================
func start_talking() -> void:
	print("[CharacterController] Start talking called")
	_talking = true
	if not _mouth_task_running:
		_mouth_task_running = true
		_mouth_loop()

func stop_talking() -> void:
	print("[CharacterController] Stop talking called")
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
				# IMPORTANTE: No interrumpir animaciones de expresión
				# Solo reproducir si no está reproduciendo una animación de expresión
				if not _is_playing_expression_animation(anim_player):
					anim_player.play(anim_name)
		
		elif node is AnimatedSprite2D:
			var sprite := node as AnimatedSprite2D
			var anim_name = mouth_open_animation if open else mouth_closed_animation
			
			if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
				sprite.play(anim_name)

func _is_playing_expression_animation(anim_player: AnimationPlayer) -> bool:
	# Verificar si el AnimationPlayer está siendo usado por alguna expresión activa
	if _current_state_id in _expression_states:
		var current_state = _expression_states[_current_state_id]
		for path in current_state.animation_players:
			var node = get_node_or_null(path)
			if node == anim_player and anim_player.is_playing():
				# Si está reproduciendo y no es una animación de boca, es de expresión
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
			print("[CharacterController] Expression states refreshed")

# =====================
# Public API
# =====================
func add_expression_state(state: ExpressionState) -> void:
	if not state:
		return
	
	_expression_states[state.state_id] = state
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
		_expression_states.erase(state_id)
		state.queue_free()
		
		# Si eliminamos el estado activo, resetear
		if _current_state_id == state_id:
			_current_state_id = -1

# ✅ PROPIEDADES PARA COMPATIBILIDAD
var default_expression_index: int:
	get:
		return default_state_id
