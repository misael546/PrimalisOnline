extends CharacterBody3D

## Placeholder controller for the first Primalis Online prototype.
## Keyboard input is for development; touch controls will be added in a later milestone.

@export var move_speed: float = 5.0
@export var gravity_strength: float = 18.0
@export var turn_speed: float = 8.0

@onready var body_visual: Node3D = get_node_or_null("Body")
@onready var camera_pivot: Node3D = get_node_or_null("CameraPivot")

func _physics_process(delta: float) -> void:
	var input_2d := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_dir := Vector3(input_2d.x, 0.0, input_2d.y)

	if move_dir.length_squared() > 0.001:
		move_dir = move_dir.normalized()
		velocity.x = move_dir.x * move_speed
		velocity.z = move_dir.z * move_speed
		rotation.y = lerp_angle(rotation.y, atan2(-move_dir.x, -move_dir.z), turn_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 4.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 4.0 * delta)

	if not is_on_floor():
		velocity.y -= gravity_strength * delta
	else:
		velocity.y = 0.0

	move_and_slide()
