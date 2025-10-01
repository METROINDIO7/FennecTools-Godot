extends Control

@onready var dd = $DialogueLauncher
@onready var label = $Label

func _ready() -> void:
	FGGlobal.load_game_data()
	
	FGGlobal.update_language()

@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	label.text = str(FGGlobal.current_language)

func _on_button_pressed() -> void:
	dd.start()
