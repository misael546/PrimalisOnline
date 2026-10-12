
extends CharacterBody3D

## Starter controller. Keyboard and on-screen controls share the same movement actions.
@export var move_speed: float = 4.5
@export var gravity_strength: float = 18.0
@export var turn_speed: float = 8.0
@export var look_sensitivity: float = 0.006
@onready var camera_pivot: Node3D = $CameraPivot
var camera_dragging: bool = false
var dinosaur_parts: Node3D
var attack_animation_remaining: float = 0.0
var attack_animation_duration: float = 0.85
@export var hunger_drain_per_second: float = 0.025
@export var thirst_drain_per_second: float = 0.04
@export var stamina_drain_per_second: float = 7.0
@export var stamina_recovery_per_second: float = 12.0
@export var sprint_speed_multiplier: float = 1.65
@export var sprint_stamina_cost_multiplier: float = 2.0
var sprint_requested: bool = false
var sprint_exhausted: bool = false
var imported_model_active: bool = false
var imported_model_info: Dictionary = {}
var imported_animation_clock: float = 0.0
var is_respawning: bool = false
var respawn_remaining: float = 0.0

func _ready() -> void:
	_build_dinosaur_model()


# Player visuals come from the licensed animated T-Rex GLB; no procedural model fallback.
func _build_dinosaur_model() -> void:
	dinosaur_parts = Node3D.new()
	dinosaur_parts.name = "DinosaurModel"
	add_child(dinosaur_parts)
	imported_model_info = PrimalisDinoAssetLoader.attach_model(
		dinosaur_parts,
		"res://assets/dinos/Trex.glb",
		2.1,
		PI,
		-0.62
	)
	if imported_model_info.is_empty():
		push_error("Primalis Online cannot start: the licensed T-Rex GLB failed to load.")
		return
	imported_model_active = true
	PrimalisDinoAssetLoader.set_segment(imported_model_info, "idle", 0.0)

var mobile_actions: Dictionary = {}
var health: float = 100.0
var hunger: float = 100.0
var thirst: float = 100.0
var stamina: float = 100.0
var status_message: String = "Explora para encontrar agua y alimento."

func consume_water() -> void:
	thirst = minf(100.0, thirst + 38.0)
	status_message = "Bebiste agua."

func eat_food() -> void:
	hunger = minf(100.0, hunger + 30.0)
	status_message = "Comiste plantas."

func eat_meat() -> void:
	hunger = minf(100.0, hunger + 48.0)
	health = minf(100.0, health + 8.0)
	status_message = "Comiste carne fresca. Recuperaste hambre y un poco de salud."

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		camera_dragging = event.pressed
	elif event is InputEventMouseMotion and camera_dragging:
		_apply_camera_look(event.relative)
	elif event is InputEventScreenDrag and event.position.x > get_viewport().get_visible_rect().size.x * 0.5 and event.position.y < get_viewport().get_visible_rect().size.y - 150.0:
		_apply_camera_look(event.relative)

func _apply_camera_look(relative: Vector2) -> void:
	camera_pivot.rotation.y -= relative.x * look_sensitivity
	camera_pivot.rotation.x = clampf(camera_pivot.rotation.x - relative.y * look_sensitivity, -0.65, 0.2)

func set_mobile_action(action: String, is_pressed: bool) -> void:
	mobile_actions[action] = is_pressed

func set_sprint(is_pressed: bool) -> void:
	sprint_requested = is_pressed
	if not is_pressed:
		# Require a deliberate release before sprinting again after exhaustion.
		sprint_exhausted = false

func _physics_process(delta: float) -> void:
	# A survival death should return the player to the start, not leave a frozen run.
	if health <= 0.0:
		if not is_respawning:
			is_respawning = true
			respawn_remaining = 3.0
			velocity = Vector3.ZERO
			mobile_actions.clear()
			sprint_requested = false
			status_message = "Te debilitaste por falta de comida o agua. Reapareces en 3 segundos."
		respawn_remaining -= delta
		status_message = "Te debilitaste. Reapareces en %.1f segundos." % maxf(respawn_remaining, 0.0)
		if respawn_remaining <= 0.0:
			_respawn_player()
		return

	var x_input := float(Input.is_action_pressed("move_right") or mobile_actions.get("move_right", false)) - float(Input.is_action_pressed("move_left") or mobile_actions.get("move_left", false))
	var z_input := float(Input.is_action_pressed("move_back") or mobile_actions.get("move_back", false)) - float(Input.is_action_pressed("move_forward") or mobile_actions.get("move_forward", false))
	var input_dir := Vector3(x_input, 0.0, z_input).normalized()
	var camera_yaw := Basis(Vector3.UP, camera_pivot.global_rotation.y)
	var move_dir := (camera_yaw * input_dir).normalized()

	var can_sprint := sprint_requested and not sprint_exhausted and stamina > 0.0 and move_dir.length_squared() > 0.001
	var current_speed := move_speed * (sprint_speed_multiplier if can_sprint else 1.0)
	if move_dir.length_squared() > 0.001:
		velocity.x = move_dir.x * current_speed
		velocity.z = move_dir.z * current_speed
		rotation.y = lerp_angle(rotation.y, atan2(-move_dir.x, -move_dir.z), turn_speed * delta)
		if can_sprint:
			stamina = maxf(0.0, stamina - stamina_drain_per_second * sprint_stamina_cost_multiplier * delta)
			if stamina <= 0.0:
				sprint_exhausted = true
		else:
			# Walking should not drain sprint stamina; recover slowly while moving.
			stamina = minf(100.0, stamina + stamina_recovery_per_second * 0.45 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 4.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 4.0 * delta)
		stamina = minf(100.0, stamina + stamina_recovery_per_second * delta)

	hunger = maxf(0.0, hunger - hunger_drain_per_second * delta)
	thirst = maxf(0.0, thirst - thirst_drain_per_second * delta)
	if hunger <= 0.0 or thirst <= 0.0:
		health = maxf(0.0, health - 1.5 * delta)

	if not is_on_floor():
		velocity.y -= gravity_strength * delta
	else:
		velocity.y = 0.0

	move_and_slide()
	_update_dino_animation(delta, move_dir.length_squared() > 0.001)

func _respawn_player() -> void:
	global_position = Vector3(0.0, 0.72, 0.0)
	velocity = Vector3.ZERO
	health = 100.0
	hunger = 65.0
	thirst = 65.0
	stamina = 100.0
	is_respawning = false
	respawn_remaining = 0.0
	sprint_requested = false
	sprint_exhausted = false
	mobile_actions.clear()
	status_message = "Reapareciste. Busca agua y plantas para sobrevivir."

func play_attack_animation() -> void:
	if not imported_model_active:
		return
	attack_animation_remaining = attack_animation_duration
	imported_animation_clock = 0.0
	PrimalisDinoAssetLoader.set_segment(imported_model_info, "attack", 0.0)


func _update_dino_animation(delta: float, is_moving: bool) -> void:
	if not imported_model_active:
		return
	if attack_animation_remaining > 0.0:
		attack_animation_remaining = maxf(0.0, attack_animation_remaining - delta)
		var attack_elapsed := attack_animation_duration - attack_animation_remaining
		PrimalisDinoAssetLoader.set_segment(imported_model_info, "attack", attack_elapsed)
		return
	imported_animation_clock += delta * (1.0 if is_moving else 0.65)
	PrimalisDinoAssetLoader.set_segment(imported_model_info, "walk" if is_moving else "idle", imported_animation_clock)
