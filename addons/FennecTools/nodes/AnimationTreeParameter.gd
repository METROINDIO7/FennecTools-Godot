@tool
extends Resource
class_name AnimationTreeParameter

# Tipo de parámetro según la documentación de Godot
enum ParameterType {
	FLOAT,              # Para valores numéricos generales
	INT,                # Para valores enteros
	BOOL,               # Para booleanos y conditions
	VECTOR2,            # Para Vector2 genéricos
	BLEND_POSITION,     # Para BlendSpace1D (float) o BlendSpace2D (Vector2)
	BLEND_AMOUNT,       # Para Blend2/Blend3 (float 0.0-1.0)
	TRANSITION_REQUEST, # ✨ Para AnimationNodeStateMachine. Solo necesitas el nombre del estado.
	ONESHOT_REQUEST,    # Para OneShot nodes (constante de request)
	TIMESEEK_REQUEST,   # Para TimeSeek nodes (float en segundos)
	TIMESCALE_SCALE,    # Para TimeScale nodes (float multiplicador)
	ADD_AMOUNT          # Para Add2/Add3 nodes (float)
}

# Configuración del parámetro
@export var parameter_path: String = ""  # Ej: "Idle/blend_position" o "conditions/is_running"
@export var parameter_type: ParameterType = ParameterType.FLOAT

# Valores según el tipo
@export var float_value: float = 0.0
@export var int_value: int = 0
@export var bool_value: bool = false
@export var vector2_value: Vector2 = Vector2.ZERO
@export var string_value: String = ""  # Para transition_request

# Opciones avanzadas
@export_group("Opciones Avanzadas")
@export var enabled: bool = true  # Permite desactivar temporalmente sin borrar
@export_multiline var notes: String = ""  # Notas para documentar qué hace

# Obtiene el valor correcto según el tipo
func get_typed_value():
	match parameter_type:
		ParameterType.FLOAT, ParameterType.TIMESCALE_SCALE, ParameterType.TIMESEEK_REQUEST, ParameterType.ADD_AMOUNT:
			return float_value
		
		ParameterType.INT:
			return int_value
		
		ParameterType.BOOL:
			return bool_value
		
		ParameterType.VECTOR2:
			return vector2_value
		
		ParameterType.BLEND_POSITION:
			# BlendSpace1D usa float, BlendSpace2D usa Vector2
			# El usuario debe saber cuál está usando
			return vector2_value
		
		ParameterType.BLEND_AMOUNT:
			return clampf(float_value, 0.0, 1.0)
		
		ParameterType.TRANSITION_REQUEST:
			return string_value
		
		ParameterType.ONESHOT_REQUEST:
			# Devuelve la constante correcta
			# 0 = ONE_SHOT_REQUEST_NONE
			# 1 = ONE_SHOT_REQUEST_FIRE
			# 2 = ONE_SHOT_REQUEST_ABORT
			return int_value
	
	return float_value  # Fallback

# Validación
func is_valid() -> bool:
	if not enabled:
		return false
	
	# ✨ MEJORA: Las transiciones no necesitan un path, solo un nombre de estado en string_value
	if parameter_type == ParameterType.TRANSITION_REQUEST:
		return not string_value.is_empty()
	
	# Todos los demás parámetros requieren un path
	if parameter_path.is_empty():
		return false
		
	return true

# Helper para obtener el path completo del parámetro
func get_full_parameter_path() -> String:
	# La documentación muestra que los paths deben empezar con "parameters/"
	# Ejemplos:
	# - Blend Position: "parameters/Idle/blend_position"
	# - Condición booleana: "parameters/conditions/is_running"
	# - OneShot: "parameters/shot/request"
	if parameter_path.begins_with("parameters/"):
		return parameter_path
	return "parameters/" + parameter_path

# Para debugging
func _to_string() -> String:
	if parameter_type == ParameterType.TRANSITION_REQUEST:
		return "[AnimationTreeParameter] Transition to '%s'" % string_value
		
	return "[AnimationTreeParameter] %s = %s (tipo: %s)" % [
		get_full_parameter_path(), 
		str(get_typed_value()), 
		ParameterType.keys()[parameter_type]
	]

# Helpers para tipos comunes
static func create_blend_position_2d(path: String, position: Vector2) -> AnimationTreeParameter:
	var param = AnimationTreeParameter.new()
	param.parameter_path = path
	param.parameter_type = ParameterType.BLEND_POSITION
	param.vector2_value = position
	return param

static func create_blend_amount(path: String, amount: float) -> AnimationTreeParameter:
	var param = AnimationTreeParameter.new()
	param.parameter_path = path
	param.parameter_type = ParameterType.BLEND_AMOUNT
	param.float_value = amount
	return param

# ✨ MEJORA: Ahora solo necesita el nombre del estado
static func create_transition(state_name: String) -> AnimationTreeParameter:
	var param = AnimationTreeParameter.new()
	param.parameter_type = ParameterType.TRANSITION_REQUEST
	param.string_value = state_name
	return param

static func create_condition(path: String, value: bool) -> AnimationTreeParameter:
	var param = AnimationTreeParameter.new()
	param.parameter_path = path
	param.parameter_type = ParameterType.BOOL
	param.bool_value = value
	return param
