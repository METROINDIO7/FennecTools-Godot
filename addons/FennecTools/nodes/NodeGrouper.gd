extends Node
class_name NodeGrouper

## 🔒 IMPORTANTE: Removido @tool para evitar ejecución en el editor
## Sistema mejorado para agrupar/desagrupar nodos con protección contra race conditions

# Configuración exportada
@export_group("Configuración de Grupos")
@export var target_group_name: String = "interactuable"
@export var backup_group_name: String = "interactuable_backup"

@export_group("Nodos a Gestionar")
@export var nodes_to_manage: Array[NodePath] = []
@export var search_in_children: bool = true
@export var search_depth: int = -1

@export_group("Comportamiento")
@export var group_at_start: bool = true
@export var restore_on_tree_exit: bool = true
@export var debug_mode: bool = false
@export var navigation_update_delay: float = 0.15  # 🔒 Delay para evitar race conditions

# Variables internas
var managed_nodes: Array[Node] = []
var nodes_currently_grouped: bool = true
var original_groups: Dictionary = {}
var _pending_navigation_update: bool = false

# Señales
signal nodes_grouped()
signal nodes_ungrouped()
signal grouping_changed(is_grouped: bool)

func _ready():
	# 🔒 LIMPIEZA: Resetear estado al iniciar
	_pending_navigation_update = false
	managed_nodes.clear()
	original_groups.clear()
	
	_collect_managed_nodes()
	_save_original_groups()
	
	if debug_mode:
		print("[NodeGrouper] Iniciado con ", managed_nodes.size(), " nodos gestionados")

	if group_at_start:
		nodes_currently_grouped = false
		group_nodes()
	else:
		nodes_currently_grouped = true
		ungroup_nodes()

func _exit_tree():
	# 🔒 LIMPIEZA: Cancelar updates pendientes
	_pending_navigation_update = false
	
	if restore_on_tree_exit:
		restore_original_groups()
	
	# Limpiar referencias
	managed_nodes.clear()
	original_groups.clear()
	
	if debug_mode:
		print("[NodeGrouper] Limpiado completamente")

func _collect_managed_nodes():
	managed_nodes.clear()
	
	for node_path in nodes_to_manage:
		var node = get_node_or_null(node_path)
		if is_instance_valid(node):
			managed_nodes.append(node)
			if debug_mode:
				print("[NodeGrouper] Nodo agregado por path: ", node.name)
	
	if search_in_children:
		_search_children(self, 0)
	
	if debug_mode:
		print("[NodeGrouper] Total de nodos recopilados: ", managed_nodes.size())

func _search_children(parent_node: Node, current_depth: int):
	if search_depth != -1 and current_depth >= search_depth:
		return
	
	for child in parent_node.get_children():
		if is_instance_valid(child) and child != self:
			if child.is_in_group(target_group_name):
				if child not in managed_nodes:
					managed_nodes.append(child)
					if debug_mode:
						print("[NodeGrouper] Nodo encontrado en hijos: ", child.name)
			
			_search_children(child, current_depth + 1)

func _save_original_groups():
	original_groups.clear()
	
	for node in managed_nodes:
		if is_instance_valid(node):
			var groups = node.get_groups()
			original_groups[node] = groups.duplicate()
			
			if debug_mode:
				print("[NodeGrouper] Grupos originales de ", node.name, ": ", groups)

func group_nodes():
	if nodes_currently_grouped:
		if debug_mode:
			print("[NodeGrouper] Los nodos ya están agrupados")
		return
	
	var grouped_count = 0
	
	for node in managed_nodes:
		if is_instance_valid(node):
			if not backup_group_name.is_empty() and node.is_in_group(backup_group_name):
				node.remove_from_group(backup_group_name)
			
			if not node.is_in_group(target_group_name):
				node.add_to_group(target_group_name)
				grouped_count += 1
				if debug_mode:
					print("[NodeGrouper] Nodo ", node.name, " agregado al grupo ", target_group_name)
	
	nodes_currently_grouped = true
	nodes_grouped.emit()
	grouping_changed.emit(true)
	
	# 🔒 Actualización diferida de navegación
	_schedule_navigation_update()
	
	if debug_mode:
		print("[NodeGrouper] ", grouped_count, " nodos agrupados en ", target_group_name)

func ungroup_nodes():
	if not nodes_currently_grouped:
		if debug_mode:
			print("[NodeGrouper] Los nodos ya están desagrupados")
		return
	
	var ungrouped_count = 0
	
	for node in managed_nodes:
		if is_instance_valid(node):
			if node.is_in_group(target_group_name):
				node.remove_from_group(target_group_name)
				ungrouped_count += 1
				if debug_mode:
					print("[NodeGrouper] Nodo ", node.name, " removido del grupo ", target_group_name)
			
			if not backup_group_name.is_empty() and not node.is_in_group(backup_group_name):
				node.add_to_group(backup_group_name)
				if debug_mode:
					print("[NodeGrouper] Nodo ", node.name, " agregado al grupo backup ", backup_group_name)
	
	nodes_currently_grouped = false
	nodes_ungrouped.emit()
	grouping_changed.emit(false)
	
	# 🔒 Actualización diferida de navegación
	_schedule_navigation_update()
	
	if debug_mode:
		print("[NodeGrouper] ", ungrouped_count, " nodos desagrupados de ", target_group_name)

func toggle_grouping():
	if nodes_currently_grouped:
		ungroup_nodes()
	else:
		group_nodes()

func restore_original_groups():
	var restored_count = 0
	
	for node in original_groups:
		if is_instance_valid(node):
			var current_groups = node.get_groups()
			for group in current_groups:
				node.remove_from_group(group)
			
			var original = original_groups[node]
			for group in original:
				node.add_to_group(group)
			
			restored_count += 1
			if debug_mode:
				print("[NodeGrouper] Grupos restaurados para ", node.name, ": ", original)
	
	nodes_currently_grouped = true
	
	# 🔒 Actualización diferida de navegación
	_schedule_navigation_update()
	
	if debug_mode:
		print("[NodeGrouper] Grupos originales restaurados para ", restored_count, " nodos")

# 🔒 NUEVO: Sistema de actualización diferida para evitar race conditions
func _schedule_navigation_update():
	if _pending_navigation_update:
		return
	
	_pending_navigation_update = true
	
	# Esperar el delay configurado antes de actualizar navegación
	await get_tree().create_timer(navigation_update_delay).timeout
	
	_pending_navigation_update = false
	_force_navigation_update()

func _force_navigation_update():
	if FGGlobal and FGGlobal.has_method("refresh_navigation_system"):
		FGGlobal.refresh_navigation_system()
		
		if debug_mode:
			print("[NodeGrouper] Sistema de navegación actualizado")

func add_node_to_management(node: Node):
	if is_instance_valid(node) and node not in managed_nodes:
		managed_nodes.append(node)
		original_groups[node] = node.get_groups().duplicate()
		
		if nodes_currently_grouped:
			if not node.is_in_group(target_group_name):
				node.add_to_group(target_group_name)
		else:
			if node.is_in_group(target_group_name):
				node.remove_from_group(target_group_name)
			if not backup_group_name.is_empty() and not node.is_in_group(backup_group_name):
				node.add_to_group(backup_group_name)
		
		_schedule_navigation_update()
		
		if debug_mode:
			print("[NodeGrouper] Nodo ", node.name, " agregado a la gestión")

func remove_node_from_management(node: Node):
	if node in managed_nodes:
		managed_nodes.erase(node)
		original_groups.erase(node)
		
		if debug_mode:
			print("[NodeGrouper] Nodo ", node.name, " removido de la gestión")

func refresh_managed_nodes():
	_collect_managed_nodes()
	_save_original_groups()
	
	if debug_mode:
		print("[NodeGrouper] Lista de nodos gestionados actualizada")

func set_nodes_by_paths(node_paths: Array[NodePath]):
	nodes_to_manage = node_paths
	_collect_managed_nodes()
	_save_original_groups()

func set_nodes_by_references(nodes: Array[Node]):
	managed_nodes.clear()
	for node in nodes:
		if is_instance_valid(node):
			managed_nodes.append(node)
	
	_save_original_groups()
	
	if debug_mode:
		print("[NodeGrouper] Nodos establecidos por referencia: ", managed_nodes.size())

func get_managed_nodes() -> Array[Node]:
	return managed_nodes.duplicate()

func is_node_managed(node: Node) -> bool:
	return node in managed_nodes

func get_grouping_state() -> bool:
	return nodes_currently_grouped

func set_target_group(new_group_name: String):
	var was_grouped = nodes_currently_grouped
	
	if was_grouped:
		ungroup_nodes()
	
	target_group_name = new_group_name
	
	if was_grouped:
		group_nodes()
	
	if debug_mode:
		print("[NodeGrouper] Grupo objetivo cambiado a: ", target_group_name)

# Aliases
func group():
	group_nodes()

func ungroup():
	ungroup_nodes()

func toggle():
	toggle_grouping()
