extends Control


func _ready() -> void:
	
	# Verificar condición booleana
	if FGGlobal.check_condition(1) == true:
	# Sumar 3 a la condicional ID 2
		FGGlobal.modify_condition(2, 3, "sumar") 
	# Cambiar condicional ID 1 a false
		FGGlobal.modify_condition(1, false)
		
	
	
