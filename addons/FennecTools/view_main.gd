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
		return
	
	var files = dir.get_files()
	
	# Filter and sort .tscn files
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

func setup_tabs():
	# Clean existing tabs
	for child in tab_container.get_children():
		child.queue_free()
	
	# Add tabs dynamically
	for i in range(loaded_scenes.size()):
		var scene_instance = loaded_scenes[i].instantiate()
		if scene_instance:
			scene_instance.name = scene_names[i]
			tab_container.add_child(scene_instance)

func update_info():
	var info_text = "Fennec Tools v1.0 - Integrated development tools\n"
	info_text += "Loaded tabs: " + str(scene_names.size())
	
	# Direct access to FGGlobal (autoload)
	if FGGlobal:
		info_text += " | Conditionals: " + str(FGGlobal.conditionals.size())
		info_text += " | Languages: " + str(FGGlobal.translations.keys().size())
	
	info_label.text = info_text
