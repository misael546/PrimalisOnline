extends Node3D

@export var display_name: String = "Viajero"
var _model_info: Dictionary = {}
var _target_position: Vector3 = Vector3.ZERO
var _target_yaw: float = 0.0
var _is_moving: bool = false
var _is_sprinting: bool = false
var _animation_clock: float = 0.0


func _ready() -> void:
	set_process(true)
	var model_host := Node3D.new()
	model_host.name = "DinosaurModel"
	add_child(model_host)
	_model_info = PrimalisDinoAssetLoader.attach_model(
		model_host,
		"res://assets/dinos/Trex.glb",
		1.8,
		PI,
		-0.62
	)
	if _model_info.is_empty():
		push_error("Could not load the remote player's licensed dinosaur model.")


func set_server_state(world_position: Vector3, yaw: float, is_moving: bool, is_sprinting: bool) -> void:
	_target_position = world_position
	_target_yaw = yaw
	_is_moving = is_moving
	_is_sprinting = is_sprinting
	if global_position.distance_squared_to(_target_position) > 10000.0:
		global_position = _target_position


func _process(delta: float) -> void:
	var interpolation: float = clampf(delta * 12.0, 0.0, 1.0)
	global_position = global_position.lerp(_target_position, interpolation)
	rotation.y = lerp_angle(rotation.y, _target_yaw, interpolation)
	_animation_clock += delta * (1.4 if _is_sprinting else 1.0)
	if not _model_info.is_empty():
		PrimalisDinoAssetLoader.set_segment(_model_info, "walk" if _is_moving else "idle", _animation_clock)
