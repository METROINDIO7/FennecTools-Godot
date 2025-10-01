@tool
extends Node
class_name NodeGrouper

## Sistema para agrupar y desagrupar nodos dinámicamente
## Se controla localmente desde cada escena según necesidad

# Configuración exportada
@export_group("Configuración de Grupos")
@export var target_group_name: String = "interactuable"
@export var backup_group_name: String = "interactuable_backup"

@export_group("Nodos a Gestionar")
@export var nodes_to_manage: Array[NodePath] = []
@export var search_in_children: bool = true
@export var search_depth: int = -1  # -1 = sin límite

@export_group("Comportamiento")
@export var restore_on_tree_exit: bool = true
@export var debug_mode: bool = false

# Variables internas
var managed_nodes: Array[Node] = []
var nodes_currently_grouped: bool = true
var original_groups: Dictionary = {}  # node -> Array[String]

# Señales
signal nodes_grouped()
signal nodes_ungrouped()
signal grouping_changed(is_grouped: bool)

func _ready():
	# Recopilar nodos a gestionar
	_collect_managed_nodes()
	
	# Guardar grupos originales
	_save_original_groups()
	
	if debug_mode:
		print("[NodeGrouper] Iniciado con ", managed_nodes.size(), " nodos gestionados")

func _exit_tree():
	# Restaurar grupos originales si está configurado
	if restore_on_tree_exit:
		restore_original_groups()

func _collect_managed_nodes():
	"""Recopila todos los nodos que serán gestionados por este NodeGrouper"""
	managed_nodes.clear()
	
	# Agregar nodos especificados en nodes_to_manage
	for node_path in nodes_to_manage:
		var node = get_node_or_null(node_path)
		if is_instance_valid(node):
			managed_nodes.append(node)
			if debug_mode:
				print("[NodeGrouper] Nodo agregado por path: ", node.name)
	
	# Buscar en hijos si está habilitado
	if search_in_children:
		_search_children(self, 0)
	
	if debug_mode:
		print("[NodeGrouper] Total de nodos recopilados: ", managed_nodes.size())

func _search_children(parent_node: Node, current_depth: int):
	"""Busca nodos en los hijos recursivamente"""
	if search_depth != -1 and current_depth >= search_depth:
		return
	
	for child in parent_node.get_children():
		if is_instance_valid(child) and child != self:
			# Verificar si el nodo está en el grupo objetivo
			if child.is_in_group(target_group_name):
				if child not in managed_nodes:
					managed_nodes.append(child)
					if debug_mode:
						print("[NodeGrouper] Nodo encontrado en hijos: ", child.name)
			
			# Buscar recursivamente
			_search_children(child, current_depth + 1)

func _save_original_groups():
	"""Guarda los grupos originales de todos los nodos gestionados"""
	original_groups.clear()
	
	for node in managed_nodes:
		if is_instance_valid(node):
			var groups = node.get_groups()
			original_groups[node] = groups.duplicate()
			
			if debug_mode:
				print("[NodeGrouper] Grupos originales de ", node.name, ": ", groups)

func group_nodes():
	"""Agrupa todos los nodos gestionados al grupo objetivo"""
	if nodes_currently_grouped:
		if debug_mode:
			print("[NodeGrouper] Los nodos ya están agrupados")
		return
	
	var grouped_count = 0
	
	for node in managed_nodes:
		if is_instance_valid(node):
			# Agregar al grupo objetivo si no está
			if not node.is_in_group(target_group_name):
				node.add_to_group(target_group_name)
				grouped_count += 1
				if debug_mode:
					print("[NodeGrouper] Nodo ", node.name, " agregado al grupo ", target_group_name)
	
	nodes_currently_grouped = true
	nodes_grouped.emit()
	grouping_changed.emit(true)
	
	# Forzar actualización de navegación
	_force_navigation_update()
	
	if debug_mode:
		print("[NodeGrouper] ", grouped_count, " nodos agrupados en ", target_group_name)

func ungroup_nodes():
	"""Desagrupa todos los nodos gestionados del grupo objetivo"""
	if not nodes_currently_grouped:
		if debug_mode:
			print("[NodeGrouper] Los nodos ya están desagrupados")
		return
	
	var ungrouped_count = 0
	
	for node in managed_nodes:
		if is_instance_valid(node):
			# Remover del grupo objetivo
			if node.is_in_group(target_group_name):
				node.remove_from_group(target_group_name)
				ungrouped_count += 1
				if debug_mode:
					print("[NodeGrouper] Nodo ", node.name, " removido del grupo ", target_group_name)
			
			# Agregar al grupo de backup si está especificado
			if not backup_group_name.is_empty() and not node.is_in_group(backup_group_name):
				node.add_to_group(backup_group_name)
				if debug_mode:
					print("[NodeGrouper] Nodo ", node.name, " agregado al grupo backup ", backup_group_name)
	
	nodes_currently_grouped = false
	nodes_ungrouped.emit()
	grouping_changed.emit(false)
	
	# Forzar actualización de navegación
	_force_navigation_update()
	
	if debug_mode:
		print("[NodeGrouper] ", ungrouped_count, " nodos desagrupados de ", target_group_name)

func toggle_grouping():
	"""Alterna entre agrupar y desagrupar"""
	if nodes_currently_grouped:
		ungroup_nodes()
	else:
		group_nodes()

func restore_original_groups():
	"""Restaura los grupos originales de todos los nodos"""
	var restored_count = 0
	
	for node in original_groups:
		if is_instance_valid(node):
			# Limpiar todos los grupos actuales
			var current_groups = node.get_groups()
			for group in current_groups:
				node.remove_from_group(group)
			
			# Restaurar grupos originales
			var original = original_groups[node]
			for group in original:
				node.add_to_group(group)
			
			restored_count += 1
			if debug_mode:
				print("[NodeGrouper] Grupos restaurados para ", node.name, ": ", original)
	
	nodes_currently_grouped = true  # Asumir que los originales estaban agrupados
	
	# Forzar actualización de navegación
	_force_navigation_update()
	
	if debug_mode:
		print("[NodeGrouper] Grupos originales restaurados para ", restored_count, " nodos")

func _force_navigation_update():
	"""Fuerza la actualización del sistema de navegación si está disponible"""
	if FGGlobal and FGGlobal.has_method("force_navigation_refresh"):
		FGGlobal.force_navigation_refresh()

func add_node_to_management(node: Node):
	"""Agrega un nodo a la gestión dinámica"""
	if is_instance_valid(node) and node not in managed_nodes:
		managed_nodes.append(node)
		
		# Guardar grupos originales del nuevo nodo
		original_groups[node] = node.get_groups().duplicate()
		
		# Aplicar estado actual (agrupado o desagrupado)
		if nodes_currently_grouped:
			if not node.is_in_group(target_group_name):
				node.add_to_group(target_group_name)
		else:
			if node.is_in_group(target_group_name):
				node.remove_from_group(target_group_name)
			if not backup_group_name.is_empty() and not node.is_in_group(backup_group_name):
				node.add_to_group(backup_group_name)
		
		_force_navigation_update()
		
		if debug_mode:
			print("[NodeGrouper] Nodo ", node.name, " agregado a la gestión")

func remove_node_from_management(node: Node):
	"""Remueve un nodo de la gestión"""
	if node in managed_nodes:
		managed_nodes.erase(node)
		original_groups.erase(node)
		
		if debug_mode:
			print("[NodeGrouper] Nodo ", node.name, " removido de la gestión")

func refresh_managed_nodes():
	"""Refresca la lista de nodos gestionados"""
	_collect_managed_nodes()
	_save_original_groups()
	
	if debug_mode:
		print("[NodeGrouper] Lista de nodos gestionados actualizada")

# Funciones para configurar nodos específicos desde código
func set_nodes_by_paths(node_paths: Array[NodePath]):
	"""Establece nodos específicos por sus paths"""
	nodes_to_manage = node_paths
	_collect_managed_nodes()
	_save_original_groups()

func set_nodes_by_references(nodes: Array[Node]):
	"""Establece nodos específicos por referencias directas"""
	managed_nodes.clear()
	for node in nodes:
		if is_instance_valid(node):
			managed_nodes.append(node)
	
	_save_original_groups()
	
	if debug_mode:
		print("[NodeGrouper] Nodos establecidos por referencia: ", managed_nodes.size())

# Funciones de consulta
func get_managed_nodes() -> Array[Node]:
	"""Devuelve la lista de nodos gestionados"""
	return managed_nodes.duplicate()

func is_node_managed(node: Node) -> bool:
	"""Verifica si un nodo está siendo gestionado"""
	return node in managed_nodes

func get_grouping_state() -> bool:
	"""Devuelve el estado actual de agrupación"""
	return nodes_currently_grouped

func set_target_group(new_group_name: String):
	"""Cambia el grupo objetivo dinámicamente"""
	var was_grouped = nodes_currently_grouped
	
	# Si estaban agrupados, desagrupar primero
	if was_grouped:
		ungroup_nodes()
	
	# Cambiar el grupo objetivo
	target_group_name = new_group_name
	
	# Si estaban agrupados, agrupar en el nuevo grupo
	if was_grouped:
		group_nodes()
	
	if debug_mode:
		print("[NodeGrouper] Grupo objetivo cambiado a: ", target_group_name)

# Aliases para facilitar uso desde código
func group():
	"""Agrupa los nodos"""
	group_nodes()

func ungroup():
	"""Desagrupa los nodos"""
	ungroup_nodes()

func toggle():
	"""Alterna agrupación"""
	toggle_grouping()
