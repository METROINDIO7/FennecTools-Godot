@tool
extends Control

@onready var tab_container: TabContainer = $VBoxContainer/TabContainer
@onready var info_label: Label = $VBoxContainer/InfoLabel

var loaded_scenes: Array[PackedScene] = []
var scene_names: Array[String] = []

func _ready():
	load_view_scenes()
	setup_tabs()
	update_info()

func load_view_scenes():
	loaded_scenes.clear()
	scene_names.clear()
	
	var view_path = "res://addons/FennecTools/View/"
	var dir = DirAccess.open(view_path)
	
	if not dir:
		print("[ViewMain] No se pudo acceder al directorio: ", view_path)
		return
	
	var files = dir.get_files()
	
	# Filtrar y ordenar archivos .tscn
	var tscn_files = []
	for file in files:
		if file.ends_with(".tscn"):
			tscn_files.append(file)
	
	tscn_files.sort()
	
	for file_name in tscn_files:
		var scene_path = view_path + file_name
		var scene = load(scene_path) as PackedScene
		
		if scene:
			loaded_scenes.append(scene)
			var clean_name = file_name.get_basename().replace("_", " ").capitalize()
			scene_names.append(clean_name)
			print("[ViewMain] Cargada escena: ", clean_name)
		else:
			print("[ViewMain] Error cargando escena: ", scene_path)

func setup_tabs():
	# Limpiar tabs existentes
	for child in tab_container.get_children():
		child.queue_free()
	
	# Agregar tabs dinámicamente
	for i in range(loaded_scenes.size()):
		var scene_instance = loaded_scenes[i].instantiate()
		if scene_instance:
			scene_instance.name = scene_names[i]
			tab_container.add_child(scene_instance)
			print("[ViewMain] Tab agregado: ", scene_names[i])
		else:
			print("[ViewMain] Error instanciando escena: ", scene_names[i])

func update_info():
	var info_text = "Fennec Tools v1.0 - Herramientas de desarrollo integradas\n"
	info_text += "Tabs cargados: " + str(scene_names.size())
	
	# Acceso directo a FGGlobal (autoload)
	if FGGlobal:
		info_text += " | Condicionales: " + str(FGGlobal.condicionales.size())
		info_text += " | Idiomas: " + str(FGGlobal.translations.keys().size())
	
	info_label.text = info_text
