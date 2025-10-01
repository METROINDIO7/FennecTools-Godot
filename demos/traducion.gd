extends Control

@onready var lenguaje: OptionButton = $OptionButton

var language_codes = ["EN", "ES"]

func _ready() -> void:
	FGGlobal.load_game_data()
	
	var lang_index = language_codes.find(FGGlobal.current_language)
	if lang_index != -1:
		lenguaje.select(lang_index)
		
	FGGlobal.update_language()


func _on_option_button_item_selected(index: int) -> void:
	if index == 0:
		FGGlobal.current_language = "EN"
	elif index == 1:
		FGGlobal.current_language = "ES"
	
	FGGlobal.update_language()
	FGGlobal.save_game_data()
