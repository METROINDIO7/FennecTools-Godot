@tool
extends Resource
class_name CharacterExpressionEntry

# Recurso que representa una acción sobre un nodo específico para una expresión
# Sistema mejorado con caché de propiedades y validación automática

# === CONTEXTO ===
var _context_node: Node = null
var _last_node_type: String = ""
var _cached_properties: Array = []  # Cache para propiedades dinámicas

# === TARGET ===
@export var target: NodePath = NodePath("")

# === CAMPOS INTERNOS ===
var action_type: StringName = &"none"
var params: Dictionary = {}

# === AnimationPlayer ===
var ap_action: String = "play"
var ap_animation: String = ""
var ap_speed: float = 1.0
var ap_position: float = 0.0
var ap_update: bool = true

# === AnimatedSprite2D ===
var as_action: String = "play"
var as_animation: String = ""
var as_frame: int = 0

# === AnimationTree ===
var at_action: String = "set_property"
var at_property: String = ""
var at_value_string: String = ""
var at_oneshot_name: String = ""

# === MeshInstance3D ===
var mi_action: String = "set_blendshape"
var mi_blendshape_mode: String = "by_name"
var mi_blendshape_name: String = ""
var mi_blendshape_index: int = 0
var mi_value: float = 0.0

# === Transform (Node2D/Node3D) ===
var tr_action: String = "set_position"
var tr_position_2d: Vector2 = Vector2.ZERO
var tr_rotation_2d: float = 0.0
var tr_scale_2d: Vector2 = Vector2.ONE
var tr_position_3d: Vector3 = Vector3.ZERO
var tr_rotation_3d: Vector3 = Vector3.ZERO
var tr_scale_3d: Vector3 = Vector3.ONE

# === NUEVO: Validación y Debug ===
var _is_valid: bool = false
var _validation_error: String = ""

# =====================
# Context helpers
# =====================
func set_editor_context(n: Node) -> void:
	_context_node = n
	_clear_cache()
	notify_property_list_changed()

func _resolve_node() -> Node:
	if _context_node and target != NodePath(""):
		return _context_node.get_node_or_null(target)
	return null

func _detect_node_type(node: Node) -> String:
	if node is AnimationPlayer:
		return "AnimationPlayer"
	if node is AnimatedSprite2D:
		return "AnimatedSprite2D"
	if node is AnimationTree:
		return "AnimationTree"
	if node is MeshInstance3D:
		return "MeshInstance3D"
	if node is Node3D:
		return "Node3D"
	if node is Node2D:
		return "Node2D"
	return "Unknown"

# =====================
# Cache de propiedades
# =====================
func _clear_cache() -> void:
	_cached_properties.clear()
	_is_valid = false
	_validation_error = ""

func _build_property_cache() -> void:
	_clear_cache()
	
	# Target siempre visible
	_cached_properties.append({
		"name": "target",
		"type": TYPE_NODE_PATH,
		"usage": PROPERTY_USAGE_DEFAULT
	})

	var node := _resolve_node()
	var type_name := _detect_node_type(node) if node else _last_node_type
	if type_name == "":
		type_name = "Unknown"

	# Validar configuración
	_validate_configuration(node, type_name)

	# Construir propiedades según tipo
	match type_name:
		"AnimationPlayer":
			_append_ap_properties(node)
		"AnimatedSprite2D":
			_append_as_properties(node)
		"AnimationTree":
			_append_at_properties(node)
		"MeshInstance3D":
			_append_mi_properties(node)
		"Node2D", "Node3D":
			_append_tr_properties(node, type_name)
		_:
			_cached_properties.append({
				"name": "info",
				"type": TYPE_STRING,
				"usage": PROPERTY_USAGE_EDITOR,
				"hint_string": "Asigna un NodePath válido para mostrar opciones contextuales"
			})

# =====================
# Validación mejorada
# =====================
func _validate_configuration(node: Node, type_name: String) -> void:
	_is_valid = false
	_validation_error = ""
	
	if target == NodePath(""):
		_validation_error = "NodePath no asignado"
		return
	
	if not node:
		_validation_error = "Nodo no encontrado en el path"
		return
	
	# Validaciones específicas por tipo
	match type_name:
		"AnimationPlayer":
			if ap_action == "play" and ap_animation != "":
				if not node.has_animation(ap_animation):
					_validation_error = "Animación '%s' no encontrada" % ap_animation
					return
		"AnimatedSprite2D":
			if as_action == "play" and as_animation != "":
				var sprite = node as AnimatedSprite2D
				if not sprite.sprite_frames or not sprite.sprite_frames.has_animation(as_animation):
					_validation_error = "Animación '%s' no encontrada" % as_animation
					return
		"MeshInstance3D":
			if mi_action == "set_blendshape" and mi_blendshape_mode == "by_index":
				var mesh = node.get_mesh()
				if mesh and mi_blendshape_index >= mesh.get_blend_shape_count():
					_validation_error = "Índice de blendshape fuera de rango"
					return
	
	_is_valid = true

# =====================
# Dynamic inspector
# =====================
func _get_property_list() -> Array:
	if _cached_properties.is_empty():
		_build_property_cache()
	
	# Añadir información de validación si hay error
	if not _validation_error.is_empty():
		_cached_properties.append({
			"name": "validation_error",
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_EDITOR,
			"hint_string": _validation_error
		})
	
	return _cached_properties

# === AnimationPlayer props ===
func _append_ap_properties(node: Node) -> void:
	_last_node_type = "AnimationPlayer"
	var actions = "play,stop,set_speed,seek"
	_cached_properties.append({"name": "ap_action", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": actions, "usage": PROPERTY_USAGE_DEFAULT})
	
	if ap_action == "play":
		var anims := _get_ap_animations(node)
		var hint := ",".join(anims) if anims.size() > 0 else ""
		_cached_properties.append({"name": "ap_animation", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": hint, "usage": PROPERTY_USAGE_DEFAULT})
	elif ap_action == "set_speed":
		_cached_properties.append({"name": "ap_speed", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.01,10,0.01,or_greater", "usage": PROPERTY_USAGE_DEFAULT})
	elif ap_action == "seek":
		_cached_properties.append({"name": "ap_position", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0,9999,0.01,or_greater", "usage": PROPERTY_USAGE_DEFAULT})
		_cached_properties.append({"name": "ap_update", "type": TYPE_BOOL, "usage": PROPERTY_USAGE_DEFAULT})

# === AnimatedSprite2D props ===
func _append_as_properties(node: Node) -> void:
	_last_node_type = "AnimatedSprite2D"
	var actions = "play,stop,set_frame"
	_cached_properties.append({"name": "as_action", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": actions, "usage": PROPERTY_USAGE_DEFAULT})
	
	if as_action == "play":
		var anims := _get_as_animations(node)
		var hint := ",".join(anims) if anims.size() > 0 else ""
		_cached_properties.append({"name": "as_animation", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": hint, "usage": PROPERTY_USAGE_DEFAULT})
	elif as_action == "set_frame":
		_cached_properties.append({"name": "as_frame", "type": TYPE_INT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0,9999,1,or_greater", "usage": PROPERTY_USAGE_DEFAULT})

# === AnimationTree props ===
func _append_at_properties(node: Node) -> void:
	_last_node_type = "AnimationTree"
	var actions = "set_property,trigger_oneshot"
	_cached_properties.append({"name": "at_action", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": actions, "usage": PROPERTY_USAGE_DEFAULT})
	
	if at_action == "set_property":
		_cached_properties.append({"name": "at_property", "type": TYPE_STRING, "usage": PROPERTY_USAGE_DEFAULT})
		_cached_properties.append({"name": "at_value_string", "type": TYPE_STRING, "usage": PROPERTY_USAGE_DEFAULT, "hint_string": "Valor (auto-parse: bool/int/float/string)"})
	elif at_action == "trigger_oneshot":
		_cached_properties.append({"name": "at_oneshot_name", "type": TYPE_STRING, "usage": PROPERTY_USAGE_DEFAULT})

# === MeshInstance3D props ===
func _append_mi_properties(node: Node) -> void:
	_last_node_type = "MeshInstance3D"
	var actions = "set_blendshape,reset_blendshapes"
	_cached_properties.append({"name": "mi_action", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": actions, "usage": PROPERTY_USAGE_DEFAULT})
	
	if mi_action == "set_blendshape":
		_cached_properties.append({"name": "mi_blendshape_mode", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": "by_name,by_index", "usage": PROPERTY_USAGE_DEFAULT})
		if mi_blendshape_mode == "by_name":
			var names := _get_mesh_blendshape_names(node)
			var hint := ",".join(names) if names.size() > 0 else ""
			_cached_properties.append({"name": "mi_blendshape_name", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": hint, "usage": PROPERTY_USAGE_DEFAULT})
		else:
			_cached_properties.append({"name": "mi_blendshape_index", "type": TYPE_INT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0,256,1,or_greater", "usage": PROPERTY_USAGE_DEFAULT})
		_cached_properties.append({"name": "mi_value", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "-1,1,0.01", "usage": PROPERTY_USAGE_DEFAULT})

# === Transform props ===
func _append_tr_properties(node: Node, type_name: String) -> void:
	_last_node_type = type_name
	var actions = "set_position,set_rotation,set_scale"
	_cached_properties.append({"name": "tr_action", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": actions, "usage": PROPERTY_USAGE_DEFAULT})
	
	if type_name == "Node2D":
		match tr_action:
			"set_position":
				_cached_properties.append({"name": "tr_position_2d", "type": TYPE_VECTOR2, "usage": PROPERTY_USAGE_DEFAULT})
			"set_rotation":
				_cached_properties.append({"name": "tr_rotation_2d", "type": TYPE_FLOAT, "usage": PROPERTY_USAGE_DEFAULT})
			"set_scale":
				_cached_properties.append({"name": "tr_scale_2d", "type": TYPE_VECTOR2, "usage": PROPERTY_USAGE_DEFAULT})
	else:
		match tr_action:
			"set_position":
				_cached_properties.append({"name": "tr_position_3d", "type": TYPE_VECTOR3, "usage": PROPERTY_USAGE_DEFAULT})
			"set_rotation":
				_cached_properties.append({"name": "tr_rotation_3d", "type": TYPE_VECTOR3, "usage": PROPERTY_USAGE_DEFAULT})
			"set_scale":
				_cached_properties.append({"name": "tr_scale_3d", "type": TYPE_VECTOR3, "usage": PROPERTY_USAGE_DEFAULT})

# =====================
# Setters mejorados
# =====================
func _set_property(property: StringName, value) -> bool:
	match property:
		"ap_action":
			ap_action = value
		"as_action":
			as_action = value
		"at_action":
			at_action = value
		"mi_action":
			mi_action = value
		"mi_blendshape_mode":
			mi_blendshape_mode = value
		"tr_action":
			tr_action = value
		"ap_animation":
			ap_animation = value
		"as_animation":
			as_animation = value
		"at_property":
			at_property = value
		"at_value_string":
			at_value_string = value
		"at_oneshot_name":
			at_oneshot_name = value
		"mi_blendshape_name":
			mi_blendshape_name = value
		"mi_blendshape_index":
			mi_blendshape_index = value
		"mi_value":
			mi_value = value
		"ap_speed":
			ap_speed = value
		"ap_position":
			ap_position = value
		"ap_update":
			ap_update = value
		"as_frame":
			as_frame = value
		"tr_position_2d":
			tr_position_2d = value
		"tr_rotation_2d":
			tr_rotation_2d = value
		"tr_scale_2d":
			tr_scale_2d = value
		"tr_position_3d":
			tr_position_3d = value
		"tr_rotation_3d":
			tr_rotation_3d = value
		"tr_scale_3d":
			tr_scale_3d = value
		"target":
			target = value
		_:
			return false
	
	_sync_action_fields()
	_clear_cache()
	notify_property_list_changed()
	return true

func _get(property: StringName):
	match property:
		"ap_action": return ap_action
		"as_action": return as_action
		"at_action": return at_action
		"mi_action": return mi_action
		"mi_blendshape_mode": return mi_blendshape_mode
		"tr_action": return tr_action
		"ap_animation": return ap_animation
		"as_animation": return as_animation
		"at_property": return at_property
		"at_value_string": return at_value_string
		"at_oneshot_name": return at_oneshot_name
		"mi_blendshape_name": return mi_blendshape_name
		"mi_blendshape_index": return mi_blendshape_index
		"mi_value": return mi_value
		"ap_speed": return ap_speed
		"ap_position": return ap_position
		"ap_update": return ap_update
		"as_frame": return as_frame
		"tr_position_2d": return tr_position_2d
		"tr_rotation_2d": return tr_rotation_2d
		"tr_scale_2d": return tr_scale_2d
		"tr_position_3d": return tr_position_3d
		"tr_rotation_3d": return tr_rotation_3d
		"tr_scale_3d": return tr_scale_3d
		"target": return target
	return null

# =====================
# Opciones dinámicas de nodos
# =====================
func _get_ap_animations(node: Node) -> Array[String]:
	var result: Array[String] = []
	if node and node is AnimationPlayer:
		var ap := node as AnimationPlayer
		for a in ap.get_animation_list():
			result.append(str(a))
	return result

func _get_as_animations(node: Node) -> Array[String]:
	var result: Array[String] = []
	if node and node is AnimatedSprite2D and (node as AnimatedSprite2D).sprite_frames:
		var sf := (node as AnimatedSprite2D).sprite_frames
		for a in sf.get_animation_names():
			result.append(str(a))
	return result

func _get_mesh_blendshape_names(node: Node) -> Array[String]:
	var result: Array[String] = []
	if node and node is MeshInstance3D and (node as MeshInstance3D).get_mesh():
		var m := (node as MeshInstance3D).get_mesh()
		for i in range(m.get_blend_shape_count()):
			result.append(str(m.get_blend_shape_name(i)))
	return result

# =====================
# Sincronización action_type + params
# =====================
func _sync_action_fields() -> void:
	var node := _resolve_node()
	var t := _detect_node_type(node) if node else _last_node_type
	if t == "":
		t = "Unknown"
	
	match t:
		"AnimationPlayer":
			match ap_action:
				"play":
					action_type = &"play_animation"
					params = {"animation": ap_animation}
				"stop":
					action_type = &"stop_animation"
					params = {}
				"set_speed":
					action_type = &"set_speed"
					params = {"speed": ap_speed}
				"seek":
					action_type = &"seek"
					params = {"position": ap_position, "update": ap_update}
				_:
					action_type = &"none"
					params = {}
		"AnimatedSprite2D":
			match as_action:
				"play":
					action_type = &"play_animation"
					params = {"animation": as_animation}
				"stop":
					action_type = &"stop_animation"
					params = {}
				"set_frame":
					action_type = &"set_frame"
					params = {"frame": as_frame}
				_:
					action_type = &"none"
					params = {}
		"AnimationTree":
			match at_action:
				"set_property":
					action_type = &"set_parameter"
					params = {"parameter": at_property, "value": _parse_string_value(at_value_string)}
				"trigger_oneshot":
					action_type = &"trigger_oneshot"
					params = {"oneshot_name": at_oneshot_name}
				_:
					action_type = &"none"
					params = {}
		"MeshInstance3D":
			if mi_action == "reset_blendshapes":
				action_type = &"reset_blendshapes"
				params = {}
			else:
				var p := {}
				if mi_blendshape_mode == "by_name":
					p["name"] = mi_blendshape_name
				else:
					p["index"] = mi_blendshape_index
				p["value"] = mi_value
				action_type = &"set_blendshape"
				params = p
		"Node2D":
			match tr_action:
				"set_position":
					action_type = &"set_position"
					params = {"position": tr_position_2d}
				"set_rotation":
					action_type = &"set_rotation"
					params = {"rotation": tr_rotation_2d}
				"set_scale":
					action_type = &"set_scale"
					params = {"scale": tr_scale_2d}
				_:
					action_type = &"none"
					params = {}
		"Node3D":
			match tr_action:
				"set_position":
					action_type = &"set_position"
					params = {"position": tr_position_3d}
				"set_rotation":
					action_type = &"set_rotation"
					params = {"rotation": tr_rotation_3d}
				"set_scale":
					action_type = &"set_scale"
					params = {"scale": tr_scale_3d}
				_:
					action_type = &"none"
					params = {}
		_:
			action_type = &"none"
			params = {}

func _parse_string_value(s: String):
	var t := s.strip_edges()
	if t.to_lower() == "true":
		return true
	if t.to_lower() == "false":
		return false
	if t.is_valid_int():
		return int(t)
	if t.is_valid_float():
		return float(t)
	return s

# =====================
# API de acción pública
# =====================
func get_action() -> Dictionary:
	_sync_action_fields()
	return {"type": String(action_type), "params": params}

func is_valid() -> bool:
	return _is_valid

func get_validation_error() -> String:
	return _validation_error

# =====================
# Debug
# =====================
func get_debug_string() -> String:
	var a = get_action()
	var status = "✓" if _is_valid else "✗"
	return "%s %s -> %s %s" % [status, str(target), a.get("type", "none"), str(a.get("params", {}))]
