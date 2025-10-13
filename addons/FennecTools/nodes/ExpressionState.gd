@tool
extends Node
class_name ExpressionState

# ✨ FIXED: Coordinación mejorada con DialogPanel

@export var state_id: int = 0
@export var state_name: String = "default"

@export_group("Mouth Animation")
@export var animate_mouth: bool = true

@export var auto_play_on_activate: bool = true

# ✨ SISTEMA DE RETORNO MEJORADO
@export_group("Return Behavior")
enum ReturnTiming {
	NONE = 0,                    # No regresar automáticamente
	TEXT_COMPLETED = 1,          # Regresar cuando el texto termine (después del typewriter)
	READY_TO_ADVANCE = 2,        # ✨ NUEVO: Regresar justo antes de avanzar al siguiente diálogo
	EXIT_ANIMATION_STARTED = 3,  # Regresar cuando comienza la animación de salida
	EXIT_ANIMATION_COMPLETED = 4, # Regresar cuando termina la animación de salida
	CUSTOM_DELAY = 5             # Regresar después de un delay desde TEXT_COMPLETED
}

@export var return_timing: ReturnTiming = ReturnTiming.NONE
@export var return_target_id: int = -1  # ID del estado al que regresar (-1 = estado por defecto)
@export var return_delay: float = 0.5  # Delay adicional (solo para CUSTOM_DELAY)

@export_group("Animation Players & Sprites")
@export var animation_nodes: Array[NodePath] = []
@export var animation_names: Array[String] = []
@export var play_all_animations: bool = false

@export_group("AnimationTree Control")
@export var animation_tree: NodePath
@export var tree_parameters: Array[AnimationTreeParameter] = []

@export_group("Blendshapes")
@export var blend_shape_meshes: Array[NodePath] = []
@export var blend_shape_names: Array[String] = []
@export var blend_shape_values: Array[float] = []

@export_group("Transform Overrides")
@export var transform_nodes: Array[NodePath] = []
@export var positions: Array[Vector3] = []
@export var rotations: Array[Vector3] = []
@export var scales: Array[Vector3] = []

signal state_activated
signal state_deactivated
signal animation_finished(animation_name)
signal return_requested(target_state_id: int)

var _active: bool = false
var _tree_node: AnimationTree = null
var _return_task_active: bool = false
var _connected_panel: Node = null  # ✨ NUEVO: Tracking del panel conectado

func _ready():
	for anim_path in animation_nodes:
		var anim_node = get_node_or_null(anim_path)
		if anim_node and anim_node is AnimationPlayer:
			if not anim_node.animation_finished.is_connected(_on_animation_finished):
				anim_node.animation_finished.connect(_on_animation_finished)
	
	if animation_tree != NodePath(""):
		_tree_node = get_node_or_null(animation_tree)
		if _tree_node and not _tree_node is AnimationTree:
			push_warning("El nodo en animation_tree no es un AnimationTree: " + str(animation_tree))
			_tree_node = null

func activate() -> void:
	_active = true
	_return_task_active = false
	
	_set_animation_tree_parameters()
	_play_animations()
	_apply_blend_shapes()
	_apply_transforms()
	
	state_activated.emit()

func deactivate() -> void:
	_active = false
	_return_task_active = false
	_disconnect_from_panel()  # ✨ NUEVO: Limpiar conexiones
	_reset_blend_shapes()
	state_deactivated.emit()

func is_active() -> bool:
	return _active

# ✨ MEJORADO: Manejo más robusto de conexiones
func start_return_sequence(dialog_panel: Node = null) -> void:
	if return_timing == ReturnTiming.NONE or _return_task_active:
		return
	
	if not is_instance_valid(dialog_panel):
		push_warning("[%s] DialogPanel no válido para return_sequence" % state_name)
		return
	
	_return_task_active = true
	_connected_panel = dialog_panel
	_execute_return_sequence(dialog_panel)

# ✨ COMPLETAMENTE REESCRITO: Mejor manejo de señales
func _execute_return_sequence(dialog_panel: Node) -> void:
	match return_timing:
		ReturnTiming.TEXT_COMPLETED:
			await _wait_for_signal(dialog_panel, "dialog_completed")
		
		ReturnTiming.READY_TO_ADVANCE:
			# ✨ NUEVO: Espera hasta que el diálogo esté listo para avanzar
			# (después de delays, pero antes de avanzar al siguiente)
			await _wait_for_signal(dialog_panel, "dialog_ready_to_advance")
		
		ReturnTiming.EXIT_ANIMATION_STARTED:
			# ✨ NUEVO: Detecta cuando comienza la animación de salida
			await _wait_for_signal(dialog_panel, "dialog_exit_started")
		
		ReturnTiming.EXIT_ANIMATION_COMPLETED:
			await _wait_for_signal(dialog_panel, "dialog_exited")
		
		ReturnTiming.CUSTOM_DELAY:
			# Primero espera que el texto complete
			await _wait_for_signal(dialog_panel, "dialog_completed")
			# Luego aplica el delay personalizado
			if return_delay > 0.0:
				await get_tree().create_timer(return_delay).timeout
	
	# Emitir solo si todo sigue válido
	if _active and _return_task_active and is_instance_valid(self):
		return_requested.emit(return_target_id)
	
	_return_task_active = false
	_disconnect_from_panel()

# ✨ NUEVO: Helper genérico para esperar señales con validación
func _wait_for_signal(node: Node, signal_name: String) -> void:
	if not is_instance_valid(node):
		push_warning("[%s] Nodo no válido para señal '%s'" % [state_name, signal_name])
		return
	
	if not node.has_signal(signal_name):
		push_warning("[%s] El nodo no tiene la señal '%s'" % [state_name, signal_name])
		return
	
	# Esperar la señal del nodo
	await node[signal_name]

# ✨ NUEVO: Limpiar conexiones cuando se desactiva
func _disconnect_from_panel() -> void:
	_connected_panel = null

func should_auto_return() -> bool:
	return return_timing != ReturnTiming.NONE and return_target_id >= -1

func cancel_return_sequence() -> void:
	_return_task_active = false
	_disconnect_from_panel()

func _play_animations() -> void:
	if not auto_play_on_activate:
		return
	
	for i in range(animation_nodes.size()):
		var anim_node_path = animation_nodes[i]
		var anim_node = get_node_or_null(anim_node_path)
		
		if not anim_node:
			continue

		var anim_name = ""
		if i < animation_names.size() and animation_names[i] != "":
			anim_name = animation_names[i]

		if anim_node is AnimationPlayer:
			var anim_player = anim_node as AnimationPlayer
			if anim_name == "":
				var anim_list = anim_player.get_animation_list()
				if anim_list.size() > 0:
					anim_name = anim_list[0]
			
			if anim_name != "" and anim_player.has_animation(anim_name):
				anim_player.play(anim_name)
		
		elif anim_node is AnimatedSprite2D:
			var sprite = anim_node as AnimatedSprite2D
			if anim_name != "" and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
				sprite.play(anim_name)

		if not play_all_animations:
			break

func _set_animation_tree_parameters() -> void:
	if not _tree_node:
		if Engine.is_editor_hint() and animation_tree != NodePath(""):
			push_warning("AnimationTree no encontrado en la ruta: " + str(animation_tree))
		return
	
	if not _tree_node.active:
		if Engine.is_editor_hint():
			push_warning("AnimationTree no está activo. Activándolo automáticamente.")
		_tree_node.active = true
	
	if _tree_node.get("anim_player") == NodePath():
		push_error("El AnimationTree en '" + str(animation_tree) + "' no tiene un AnimationPlayer asignado.")
		return

	for param in tree_parameters:
		if not param or not param.is_valid():
			continue
		
		if param.parameter_type == AnimationTreeParameter.ParameterType.TRANSITION_REQUEST:
			var state_name_to_travel = param.get_typed_value()
			_tree_node.travel(state_name_to_travel)
			
			if Engine.is_editor_hint():
				print("✓ [%s] Transición a estado: '%s'" % [self.state_name, state_name_to_travel])
		else:
			var full_path = param.get_full_parameter_path()
			var value = param.get_typed_value()
			
			_tree_node.set(full_path, value)
			
			if Engine.is_editor_hint():
				print("✓ [%s] Parámetro: %s = %s" % [self.state_name, full_path, str(value)])

func _apply_blend_shapes():
	for i in range(blend_shape_meshes.size()):
		if i < blend_shape_names.size() and i < blend_shape_values.size():
			var mesh_path = blend_shape_meshes[i]
			var mesh_node = get_node_or_null(mesh_path)

			if mesh_node and (mesh_node is MeshInstance3D):
				var shape_name = blend_shape_names[i]
				var shape_value = blend_shape_values[i]
				mesh_node.set("blend_shapes/" + shape_name, shape_value)

func _reset_blend_shapes():
	for i in range(blend_shape_meshes.size()):
		if i < blend_shape_names.size():
			var mesh_path = blend_shape_meshes[i]
			var mesh_node = get_node_or_null(mesh_path)

			if mesh_node and (mesh_node is MeshInstance3D):
				var shape_name = blend_shape_names[i]
				mesh_node.set("blend_shapes/" + shape_name, 0.0)

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

func _on_animation_finished(anim_name: String) -> void:
	if _active:
		animation_finished.emit(anim_name)

# ✨ HELPERS
func get_animation_tree() -> AnimationTree:
	return _tree_node

func set_tree_parameter(param_path: String, value) -> void:
	if _tree_node:
		var full_path = param_path
		if not full_path.begins_with("parameters/"):
			full_path = "parameters/" + full_path
		_tree_node.set(full_path, value)

func get_tree_parameter(param_path: String):
	if _tree_node:
		var full_path = param_path
		if not full_path.begins_with("parameters/"):
			full_path = "parameters/" + full_path
		return _tree_node.get(full_path)
	return null
