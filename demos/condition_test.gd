extends Control

@onready var vv: Label = $GridContainer/vv
@onready var nn: Label = $GridContainer/nn
@onready var ttt: Label = $GridContainer/ttt
@onready var ttt2: Label = $GridContainer/ttt2
@onready var ttt3: Label = $GridContainer/ttt3
@onready var ttt4: Label = $GridContainer/ttt4

func _ready() -> void:
	
	mm()
	ttt3.text = str(FGGlobal.get_text_value(3,2))

func pp():
	
	if FGGlobal.check_condition(1) == true:
		FGGlobal.modify_condition(1, false)
		FGGlobal.modify_condition(2, 5, "add")  # Usar "add" en lugar de "sumar"
		FGGlobal.add_text_value(3,"pedro") #remove_text_value() lo contrario
	else:
		FGGlobal.modify_condition(1, true)
		FGGlobal.modify_condition(2, 10, "subtract")  # Usar "subtract" en lugar de "restar"
		FGGlobal.add_text_value(3,"pablo") #remove_text_value() lo contrario
	
	mm()

func mm():
	vv.text = str(FGGlobal.check_condition(1))
	nn.text = str(FGGlobal.check_condition(2))
	ttt.text = str(FGGlobal.get_all_text_values(3))
	ttt2.text = str(FGGlobal.get_random_text_value(3))
	
	if ttt2.text == FGGlobal.get_text_value(3,1):
		ttt4.text = "algo cambio"
	else :
		ttt4.text = "seguimos igual"
	


func _on_button_pressed() -> void:
	
	pp()

func _on_button_2_pressed() -> void:
	#FGGlobal.modify_condition(1, true)
	#pp()
	
	FGGlobal.delete_save_slot(1)
	FGGlobal.Partida(str(1)) 
	mm()
