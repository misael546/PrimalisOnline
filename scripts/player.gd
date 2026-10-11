
extends CharacterBody3D

## Starter controller. Keyboard and on-screen controls share the same movement actions.
@export var move_speed: float = 4.5
@export var gravity_strength: float = 18.0
@export var turn_speed: float = 8.0
@export var hunger_drain_per_second: float = 0.025
@export var thirst_drain_per_second: float = 0.04

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

func set_mobile_action(action: String, is_pressed: bool) -> void:
	mobile_actions[action] = is_pressed

func _physics_process(delta: float) -> void:
	var x_input := float(Input.is_action_pressed("move_right") or mobile_actions.get("move_right", false)) - float(Input.is_action_pressed("move_left") or mobile_actions.get("move_left", false))
	var z_input := float(Input.is_action_pressed("move_back") or mobile_actions.get("move_back", false)) - float(Input.is_action_pressed("move_forward") or mobile_actions.get("move_forward", false))
	var move_dir := Vector3(x_input, 0.0, z_input).normalized()

	if move_dir.length_squared() > 0.001:
		velocity.x = move_dir.x * move_speed
		velocity.z = move_dir.z * move_speed
		rotation.y = lerp_angle(rotation.y, atan2(-move_dir.x, -move_dir.z), turn_speed * delta)
		stamina = maxf(0.0, stamina - 7.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 4.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 4.0 * delta)
		stamina = minf(100.0, stamina + 12.0 * delta)

	hunger = maxf(0.0, hunger - hunger_drain_per_second * delta)
	thirst = maxf(0.0, thirst - thirst_drain_per_second * delta)
	if hunger <= 0.0 or thirst <= 0.0:
		health = maxf(0.0, health - 1.5 * delta)

	if not is_on_floor():
		velocity.y -= gravity_strength * delta
	else:
		velocity.y = 0.0

	move_and_slide()
