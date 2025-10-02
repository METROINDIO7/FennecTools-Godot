@tool
extends Node

# Character Controller (2D/3D) - Sistema manual de expresiones mejorado
# Con caché de nodos y sistema de fallback mejorado

@export var character_name: String = ""

@export_group("Expressions")
@export var expressions: Array[CharacterExpressionSlot] = [] : set = set_expressions
@export var default_expression_name: String = "default"

@export_group("Mouth Talking")
@export var mouth_targets: Array[NodePath] = []
@export var mouth_blendshape_index: int = 0
@export var mouth_intensity: float = 1.0
@export var mouth_interval: float = 0.1

@export_group("AnimationTree Helpers")
@export var expression_lerp_speed: float = 5.0

@export_group("Performance")
@export var enable_node_caching: bool = true

# Cache de nodos para mejor rendimiento
var _node_cache: Dictionary = {}
var _expr_index: Dictionary = {}
var _active_expression: String = ""

# Sistema de boca
var _talking: bool = false
var _mouth_task_running: bool = false

# =====================
# Initialization
# =====================
func _ready() -> void:
	_rebuild_caches()
	_editor_update_entries_context()
	if default_expression_name.strip_edges() != "":
		set_expression(default_expression_name)

# =====================
# Cache Management
# =====================
func _rebuild_caches() -> void:
	_rebuild_expression_index()
	_rebuild_node_cache()

func _rebuild_expression_index() -> void:
	_expr_index.clear()
	for i in range(expressions.size()):
		var s: CharacterExpressionSlot = expressions[i]
		if s and s.name.strip_edges() != "":
			_expr_index[s.name] = i

func _rebuild_node_cache() -> void:
	if not enable_node_caching:
		return
	
	_node_cache.clear()
	
	# Cachear nodos de mouth targets
	for path in mouth_targets:
		if path != NodePath(""):
			var node = get_node_or_null(path)
			if node:
				_node_cache[path] = node
	
	# Cachear nodos de expresiones
	for slot in expressions:
		if slot and slot.entries:
			for entry in slot.entries:
				if entry and entry.target != NodePath(""):
					var path = entry.target
					if not _node_cache.has(path):
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
# Expression System
# =====================
func set_expression(name: String) -> void:
	if name.strip_edges() == "":
		return
	
	if not _expr_index.has(name):
		push_warning("Expression '%s' not found for character %s" % [name, character_name])
		# Fallback mejorado
		if default_expression_name.strip_edges() != "" and _expr_index.has(default_expression_name) and name != default_expression_name:
			set_expression(default_expression_name)
		return
	
	_active_expression = name
	var slot: CharacterExpressionSlot = expressions[_expr_index[name]]
	if slot and slot.entries:
		for entry in slot.entries:
			if entry:
				_apply_entry(entry)

# NUEVO: Aplicar expresión con blending
func set_expression_with_blend(name: String, blend_time: float = 0.5) -> void:
	if blend_time <= 0:
		set_expression(name)
		return
	
	# Para implementar blending necesitaríamos un sistema más complejo
	# Por ahora, simplemente aplicamos la expresión
	set_expression(name)

# NUEVO: Obtener expresión actual
func get_current_expression() -> String:
	return _active_expression

# =====================
# Entry Application
# =====================
func _apply_entry(entry: CharacterExpressionEntry) -> void:
	if not entry.is_valid():
		push_warning("Invalid expression entry: %s" % entry.get_validation_error())
		return
	
	var node := _get_cached_node(entry.target)
	if not node:
		push_warning("Node not found for path: %s" % entry.target)
		return
	
	var act := entry.get_action()
	_apply_action_to_node(node, String(act.get("type", "none")), act.get("params", {}))

func _apply_action_to_node(node: Node, action_type: String, params: Dictionary) -> void:
	if node is AnimationPlayer:
		_apply_animation_player(node as AnimationPlayer, action_type, params)
	elif node is AnimatedSprite2D:
		_apply_animated_sprite(node as AnimatedSprite2D, action_type, params)
	elif node is AnimationTree:
		_apply_animation_tree(node as AnimationTree, action_type, params)
	elif node is MeshInstance3D:
		_apply_mesh_instance(node as MeshInstance3D, action_type, params)
	elif node is Node3D or node is Node2D:
		_apply_transform(node, action_type, params)
	else:
		# Fallback genérico
		if action_type == "call_method":
			var method: String = str(params.get("method", ""))
			var args = params.get("args", [])
			if method != "" and node.has_method(method):
				match typeof(args):
					TYPE_ARRAY:
						node.callv(method, args)
					_:
						node.call(method)

# =====================
# Specific Node Handlers
# =====================
func _apply_animation_player(ap: AnimationPlayer, action_type: String, params: Dictionary) -> void:
	match action_type:
		"play_animation":
			var anim_name: String = str(params.get("animation", ""))
			if anim_name != "" and ap.has_animation(anim_name):
				ap.play(anim_name)
		"stop_animation":
			ap.stop()
		"set_speed":
			var speed: float = float(params.get("speed", 1.0))
			ap.speed_scale = speed
		"seek":
			var pos: float = float(params.get("position", 0.0))
			var update: bool = bool(params.get("update", true))
			ap.seek(pos, update)

func _apply_animated_sprite(aspr: AnimatedSprite2D, action_type: String, params: Dictionary) -> void:
	match action_type:
		"play_animation":
			var anim_name: String = str(params.get("animation", ""))
			if anim_name != "":
				aspr.play(anim_name)
		"stop_animation":
			aspr.stop()
		"set_frame":
			var frame: int = int(params.get("frame", 0))
			aspr.frame = frame

func _apply_animation_tree(atree: AnimationTree, action_type: String, params: Dictionary) -> void:
	match action_type:
		"set_parameter", "set_property":
			var prop: String = str(params.get("property", params.get("parameter", "")))
			if prop.strip_edges() != "":
				atree.set(prop, params.get("value"))
		"trigger_oneshot":
			var name: String = str(params.get("oneshot_name", ""))
			if name.strip_edges() != "":
				atree.set("parameters/%s/request" % name, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func _apply_mesh_instance(mesh: MeshInstance3D, action_type: String, params: Dictionary) -> void:
	match action_type:
		"set_blendshape":
			var value: float = float(params.get("value", 0.0))
			if params.has("name"):
				var bname: String = str(params.get("name"))
				_set_blend_shape_by_name(mesh, bname, value)
			else:
				var index: int = int(params.get("index", 0))
				_set_blend_shape_on_mesh(mesh, index, value)
		"reset_blendshapes":
			var m = mesh.get_mesh()
			if m:
				for i in range(m.get_blend_shape_count()):
					mesh.set("blend_shapes/%s" % m.get_blend_shape_name(i), 0.0)

func _apply_transform(node: Node, action_type: String, params: Dictionary) -> void:
	if node is Node3D:
		var n3 := node as Node3D
		match action_type:
			"set_position":
				n3.position = params.get("position", n3.position)
			"set_rotation":
				n3.rotation = params.get("rotation", n3.rotation)
			"set_scale":
				n3.scale = params.get("scale", n3.scale)
	elif node is Node2D:
		var n2 := node as Node2D
		match action_type:
			"set_position":
				n2.position = params.get("position", n2.position)
			"set_rotation":
				n2.rotation = float(params.get("rotation", n2.rotation))
			"set_scale":
				n2.scale = params.get("scale", n2.scale)

# =====================
# Mouth System
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
		for path in mouth_targets:
			var mesh = _get_cached_node(path) as MeshInstance3D
			if mesh and mesh.get_mesh() and mouth_blendshape_index >= 0:
				var v = randf_range(-1.0, 1.0) * mouth_intensity
				_set_blend_shape_on_mesh(mesh, mouth_blendshape_index, v)
		await get_tree().create_timer(mouth_interval).timeout
	
	_mouth_task_running = false
	# Resetear blendshapes de boca
	for path in mouth_targets:
		var mesh = _get_cached_node(path) as MeshInstance3D
		if mesh:
			_set_blend_shape_on_mesh(mesh, mouth_blendshape_index, 0.0)

# =====================
# Blendshape Utilities
# =====================
func _set_blend_shape_by_name(mesh_instance: MeshInstance3D, name: String, value: float) -> void:
	var mesh = mesh_instance.get_mesh()
	if mesh:
		for i in range(mesh.get_blend_shape_count()):
			if mesh.get_blend_shape_name(i) == name:
				mesh_instance.set("blend_shapes/%s" % name, value)
				return

func _set_blend_shape_on_mesh(mesh_instance: MeshInstance3D, index: int, value: float) -> void:
	var mesh = mesh_instance.get_mesh()
	if mesh and index >= 0 and index < mesh.get_blend_shape_count():
		mesh_instance.set("blend_shapes/%s" % mesh.get_blend_shape_name(index), value)

# =====================
# Editor Integration
# =====================
func set_expressions(value: Array[CharacterExpressionSlot]) -> void:
	expressions = value
	_rebuild_caches()
	_editor_update_entries_context()

func _editor_update_entries_context() -> void:
	if not Engine.is_editor_hint():
		return
	for s in expressions:
		if s and s.entries:
			for e in s.entries:
				if e and e.has_method("set_editor_context"):
					e.set_editor_context(self)

# =====================
# Public API
# =====================
func add_expression_slot(slot: CharacterExpressionSlot) -> void:
	if not slot:
		return
	expressions.append(slot)
	_rebuild_caches()
	_editor_update_entries_context()

func remove_expression_by_name(name: String) -> void:
	if not _expr_index.has(name):
		return
	var idx: int = int(_expr_index[name])
	expressions.remove_at(idx)
	_rebuild_caches()

func get_expression_names() -> Array[String]:
	var names: Array[String] = []
	for s in expressions:
		if s and s.name.strip_edges() != "":
			names.append(s.name)
	return names

# NUEVO: Verificar si una expresión existe
func has_expression(name: String) -> bool:
	return _expr_index.has(name)

# NUEVO: Obtener información de debug
func get_debug_info() -> String:
	var info := "Character: %s\n" % character_name
	info += "Current Expression: %s\n" % _active_expression
	info += "Available Expressions: %s\n" % get_expression_names()
	info += "Cached Nodes: %d\n" % _node_cache.size()
	info += "Mouth Targets: %d\n" % mouth_targets.size()
	return info
