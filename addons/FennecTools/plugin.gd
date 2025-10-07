@tool
extends EditorPlugin

const MainView = preload("res://addons/FennecTools/view_main.tscn")
const NodeGrouper = preload("res://addons/FennecTools/nodes/NodeGrouper.gd")
const DialogPanelController = preload("res://addons/FennecTools/nodes/DialogPanelController.gd")
const DialogueLauncher = preload("res://addons/FennecTools/nodes/DialogueLauncher.gd")
const CharacterController = preload("res://addons/FennecTools/nodes/CharacterController.gd")
const ExpressionState = preload("res://addons/FennecTools/nodes/ExpressionState.gd")

var main_view

func _enter_tree():
	# Add autoload if it doesn't exist
	if not ProjectSettings.has_setting("autoload/FGGlobal"):
		add_autoload_singleton("FGGlobal", "res://addons/FennecTools/FGGlobal.gd")
	
	# Register NodeGrouper as custom node
	add_custom_type(
		"NodeGrouper",
		"Node", 
		NodeGrouper,
		preload("res://addons/FennecTools/icons/node_grouper_icon.svg")
	)
	# Register DialogPanelController
	add_custom_type(
		"DialogPanelController",
		"Control",
		DialogPanelController,
		preload("res://addons/FennecTools/icons/minimal_speech_play_icon.svg")
	)
	# Register DialogueLauncher
	add_custom_type(
		"DialogueLauncher",
		"Node",
		DialogueLauncher,
		preload("res://addons/FennecTools/icons/flow_branch_node_icon.svg")
	)
	# Register CharacterController
	add_custom_type(
		"CharacterController",
		"Node",
		CharacterController,
		preload("res://addons/FennecTools/icons/character_bust_animationtree_icon.svg")
	)
	add_custom_type(
		"ExpressionState",
		"Resource",
		ExpressionState,
		preload("res://addons/FennecTools/icons/D_states.svg")
	)
	
	main_view = MainView.instantiate()
	EditorInterface.get_editor_main_screen().add_child(main_view)
	_make_visible(false)

func _exit_tree():
	if is_instance_valid(main_view):
		main_view.queue_free()
	
	# Remove custom nodes
	remove_custom_type("DialogueCodeSequence")
	remove_custom_type("DialogueCodeChain")
	remove_custom_type("DialogueSlotConfig")
	remove_custom_type("CharacterController")
	remove_custom_type("DialogueLauncher")
	remove_custom_type("DialogPanelController")
	remove_custom_type("NodeGrouper")
	
	# Optional: remove autoload (commented to keep data)
	# remove_autoload_singleton("FGGlobal")

func _has_main_screen() -> bool:
	return true

func _make_visible(next_visible: bool) -> void:
	if is_instance_valid(main_view):
		main_view.visible = next_visible

func _get_plugin_name() -> String:
	return "Fennec Tools"

func _get_plugin_icon() -> Texture2D:
	var texture = load("res://addons/FennecTools/icons/icon.svg") as Texture2D
	if texture:
		var image = texture.get_image()
		if image and image.get_size().x > 24:
			image.resize(16, 16, Image.INTERPOLATE_LANCZOS)
			var new_texture = ImageTexture.create_from_image(image)
			return new_texture
	return texture
