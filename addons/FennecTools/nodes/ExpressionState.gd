@tool
extends Node
class_name ExpressionState

# Expression state configuration
@export var state_id: int = 0
@export var state_name: String = "default"
@export var auto_play_on_activate: bool = true

# Animations to execute in this state
@export_group("Animation Targets")
@export var animation_players: Array[NodePath] = []
@export var animation_names: Array[String] = []  # Specific animation names
@export var play_all_animations: bool = false  # Whether to play all animations or just the first one

# AnimationTree Parameters
@export_group("AnimationTree Parameters")
@export var animation_trees: Array[NodePath] = []
@export var parameters_to_set: Array[String] = []
@export var parameter_values: Array[String] = []

# Transformations (optional)
@export_group("Transform Overrides")
@export var transform_nodes: Array[NodePath] = []
@export var positions: Array[Vector3] = []
@export var rotations: Array[Vector3] = []
@export var scales: Array[Vector3] = []

# Signals
signal state_activated
signal state_deactivated
signal animation_finished(animation_name)

var _active: bool = false

func _ready():
	# Connect AnimationPlayers signals
	for anim_path in animation_players:
		var anim_player = get_node_or_null(anim_path)
		if anim_player and anim_player is AnimationPlayer:
			if anim_player.animation_finished.connect(_on_animation_finished) != OK:
				push_warning("Failed to connect animation_finished signal for: " + str(anim_path))

func activate() -> void:
	_active = true
	
	# Execute animations
	_play_animations()
	
	# Configure AnimationTrees
	_set_animation_tree_parameters()
	
	# Apply transformations
	_apply_transforms()
	
	state_activated.emit()

func deactivate() -> void:
	_active = false
	state_deactivated.emit()

func is_active() -> bool:
	return _active

func _play_animations() -> void:
	if not auto_play_on_activate:
		return
	
	for i in range(animation_players.size()):
		var anim_path = animation_players[i]
		var anim_player = get_node_or_null(anim_path)
		
		if anim_player and anim_player is AnimationPlayer:
			var anim_name = ""
			
			if i < animation_names.size() and animation_names[i] != "":
				anim_name = animation_names[i]
			else:
				# Use first available animation
				var anim_list = anim_player.get_animation_list()
				if anim_list.size() > 0:
					anim_name = anim_list[0]
			
			if anim_name != "" and anim_player.has_animation(anim_name):
				anim_player.play(anim_name)
				
				# If not play_all, exit after the first valid animation
				if not play_all_animations:
					break

func _set_animation_tree_parameters() -> void:
	for i in range(animation_trees.size()):
		if i < parameters_to_set.size() and i < parameter_values.size():
			var tree_path = animation_trees[i]
			var anim_tree = get_node_or_null(tree_path)
			
			if anim_tree and anim_tree is AnimationTree:
				var param_name = parameters_to_set[i]
				var param_value_str = parameter_values[i]
				var value = _parse_parameter_value(param_value_str)
				
				anim_tree.set(param_name, value)

func _apply_transforms() -> void:
	for i in range(transform_nodes.size()):
		var node_path = transform_nodes[i]
		var node = get_node_or_null(node_path)
		
		if node:
			if node is Node3D:
				var node_3d = node as Node3D
				if i < positions.size():
					node_3d.position = positions[i]
				if i < rotations.size():
					node_3d.rotation = rotations[i]
				if i < scales.size():
					node_3d.scale = scales[i]
			elif node is Node2D:
				var node_2d = node as Node2D
				if i < positions.size():
					node_2d.position = Vector2(positions[i].x, positions[i].y)
				if i < rotations.size():
					node_2d.rotation = rotations[i].z
				if i < scales.size():
					node_2d.scale = Vector2(scales[i].x, scales[i].y)

func _parse_parameter_value(value_str: String):
	var clean_str = value_str.strip_edges()
	
	# Boolean
	if clean_str.to_lower() == "true":
		return true
	if clean_str.to_lower() == "false":
		return false
	
	# Integer
	if clean_str.is_valid_int():
		return clean_str.to_int()
	
	# Float
	if clean_str.is_valid_float():
		return clean_str.to_float()
	
	# String
	return clean_str

func _on_animation_finished(anim_name: String) -> void:
	if _active:
		animation_finished.emit(anim_name)

func get_debug_info() -> String:
	var info = "ExpressionState: " + state_name + " (ID: " + str(state_id) + ")\n"
	info += "Active: " + str(_active) + "\n"
	info += "Animation Players: " + str(animation_players.size()) + "\n"
	info += "Animation Trees: " + str(animation_trees.size()) + "\n"
	info += "Transform Nodes: " + str(transform_nodes.size()) + "\n"
	return info
