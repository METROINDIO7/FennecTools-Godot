@tool
extends Node

# Character Controller (2D/3D)
# - Assign by character_name
# - Supports AnimatedSprite2D/SpriteFrames, AnimationPlayer (2D/3D), AnimationTree, BlendShapes (via MeshInstance3D)
# - Mouth talking loop for 3D blendshapes
# - Expressions through configurable map: expression_name -> method/params
# - Utility setters for AnimationTree parameters (oneshot, blend_amount, blend_position, scale)

@export var character_name: String = ""
@export var is_2d: bool = false

# Node paths (optional)
@export var animated_sprite_path: NodePath
@export var animation_player_path: NodePath
@export var animation_tree_path: NodePath
@export var mesh_instance_path: NodePath

# BlendShape index for mouth (if using MeshInstance3D)
@export var mouth_blendshape_index: int = 0
@export var mouth_intensity: float = 1.0
@export var mouth_interval: float = 0.1

# Expression configuration
# Example structure:
# {
#   "feliz": {"type": "blendshape", "index": 2, "value": 0.8},
#   "triste": {"type": "sprite", "anim": "sad"},
#   "enojado": {"type": "tree_blend", "path": "parameters/face/blend_amount", "value": 1.0}
# }
@export var expressions: Dictionary = {}

# AnimationTree helpers
@export var expression_lerp_speed: float = 5.0

var _sprite: AnimatedSprite2D
var _anim: AnimationPlayer
var _tree: AnimationTree
var _mesh: MeshInstance3D

var _talking: bool = false
var _mouth_task_running: bool = false
var _current_expression_value: float = 0.0
var _target_expression_value: float = 0.0
var _tree_expression_path: String = ""

func _ready() -> void:
	if animated_sprite_path != NodePath(""):
		_sprite = get_node_or_null(animated_sprite_path) as AnimatedSprite2D
	if animation_player_path != NodePath(""):
		_anim = get_node_or_null(animation_player_path) as AnimationPlayer
	if animation_tree_path != NodePath(""):
		_tree = get_node_or_null(animation_tree_path) as AnimationTree
	if mesh_instance_path != NodePath(""):
		_mesh = get_node_or_null(mesh_instance_path) as MeshInstance3D

func start_talking() -> void:
	_talking = true
	if not _mouth_task_running:
		_mouth_task_running = true
		_mouth_loop()

func stop_talking() -> void:
	_talking = false

func _mouth_loop() -> void:
	# Default simple random mouth movement using blendshape
	while _talking:
		if _mesh and _mesh.get_mesh() and mouth_blendshape_index >= 0:
			var v = randf_range(-1.0, 1.0) * mouth_intensity
			_set_blend_shape(mouth_blendshape_index, v)
		await get_tree().create_timer(mouth_interval).timeout
	_mouth_task_running = false
	if _mesh:
		_set_blend_shape(mouth_blendshape_index, 0.0)

func _set_blend_shape(index: int, value: float) -> void:
	var m = _mesh.get_mesh()
	if m and m.get_blend_shape_count() > index:
		_mesh.set("blend_shapes/%s" % m.get_blend_shape_name(index), value)

# Expressions API
func set_expression(name: String) -> void:
	if not expressions.has(name):
		return
	var e: Dictionary = expressions[name] as Dictionary
	var t := str(e.get("type", ""))
	match t:
		"blendshape":
			var idx: int = int(e.get("index", mouth_blendshape_index))
			var val: float = float(e.get("value", 1.0))
			_set_blend_shape(idx, val)
		"sprite":
			if _sprite:
				var anim := str(e.get("anim", ""))
				if anim != "":
					_sprite.play(anim)
		"anim":
			if _anim:
				var anim_name := str(e.get("anim", ""))
				if anim_name != "":
					_anim.play(anim_name)
		"tree_blend":
			if _tree:
				_tree_expression_path = str(e.get("path", ""))
				_target_expression_value = float(e.get("value", 1.0))
				# Lerp en _process si hay path válido
		"tree_set":
			if _tree:
				var p := str(e.get("path", ""))
				var v := e.get("value", 1.0)
				_tree.set(p, v)
		_:
			pass

func _process(delta: float) -> void:
	if _tree and _tree_expression_path != "":
		_current_expression_value = lerp(_current_expression_value, _target_expression_value, expression_lerp_speed * delta)
		_tree.set(_tree_expression_path, _current_expression_value)
		if abs(_current_expression_value - _target_expression_value) < 0.002:
			_tree_expression_path = ""

# AnimationTree helpers
func trigger_oneshot(name: String) -> void:
	if _tree:
		_tree.set("parameters/%s/request" % name, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func set_blend_amount(path: String, value: float) -> void:
	if _tree:
		_tree.set(path, value)

func set_blend_position(path: String, pos: Vector2) -> void:
	if _tree:
		_tree.set(path, pos)

func set_scale_param(path: String, value: float) -> void:
	if _tree:
		_tree.set(path, value)
