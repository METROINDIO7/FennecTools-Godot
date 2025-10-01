extends Control

@onready var grupos: NodeGrouper = $NodeGrouper
var pp = true

func _on_button_pressed() -> void:
	var random_color = Color(randf(), randf(), randf())
	RenderingServer.set_default_clear_color(random_color)


func _on_button_2_pressed() -> void:
	if pp:
		grupos.ungroup()
		pp = false
	else :
		grupos.group()
		pp = true


#navigation_refresh() para actualizar lista de nodos por cualquier error al instanciaaar nuevos
