extends Node3D

## Client-side rendering only; all wildlife decisions and health come from server snapshots.
@export var species_id: int = 0

const SPECIES_PATHS: Array[String] = [
	"res://assets/dinos/Stegosaurus.glb",
	"res://assets/dinos/Triceratops.glb",
	"res://assets/dinos/Ankylosaurus.glb",
	"res://assets/dinos/Pachycephalosaurus.glb",
	"res://assets/dinos/Oviraptor.glb"
]

var _model_info: Dictionary = {}
var _target_position: Vector3 = Vector3.ZERO
var _target_yaw: float = 0.0
var _is_moving: bool = false
var _is_dead: bool = false
var _meat_available: bool = false
var _health: float = 100.0
var _animation_clock: float = 0.0


func _ready() -> void:
	set_process(true)
	var model_host := Node3D.new()
	model_host.name = "WildlifeModel"
	add_child(model_host)
	var safe_species_id: int = clampi(species_id, 0, SPECIES_PATHS.size() - 1)
	var asset_path: String = SPECIES_PATHS[safe_species_id]
	var target_height: float = 1.35 if safe_species_id == 4 else (1.55 if safe_species_id == 1 else 1.5)
	_model_info = PrimalisDinoAssetLoader.attach_model(model_host, asset_path, target_height, PI, -0.75)
	if _model_info.is_empty():
		push_error("Could not load server-replicated wildlife model: %s" % asset_path)
	else:
		PrimalisDinoAssetLoader.set_segment(_model_info, "idle", 0.0)
	_update_visibility()


func set_server_state(world_position: Vector3, yaw: float, is_moving: bool, is_dead: bool, health: float, meat_available: bool) -> void:
	_target_position = world_position
	_target_yaw = yaw
	_is_moving = is_moving
	_is_dead = is_dead
	_health = clampf(health, 0.0, 100.0)
	_meat_available = meat_available
	if global_position.distance_squared_to(_target_position) > 10000.0:
		global_position = _target_position
	_update_visibility()


func _update_visibility() -> void:
	visible = not _is_dead or _meat_available


func _process(delta: float) -> void:
	var interpolation: float = clampf(delta * 10.0, 0.0, 1.0)
	global_position = global_position.lerp(_target_position, interpolation)
	rotation.y = lerp_angle(rotation.y, _target_yaw, interpolation)
	_animation_clock += delta
	if _model_info.is_empty():
		return
	if _is_dead:
		PrimalisDinoAssetLoader.set_segment(_model_info, "dead", 0.0)
	else:
		PrimalisDinoAssetLoader.set_segment(_model_info, "walk" if _is_moving else "idle", _animation_clock)
