
extends CharacterBody3D

## Starter controller. Keyboard and on-screen controls share the same movement actions.
@export var move_speed: float = 4.5
@export var gravity_strength: float = 18.0
@export var turn_speed: float = 8.0
@export var look_sensitivity: float = 0.006
@onready var camera_pivot: Node3D = $CameraPivot
var camera_dragging: bool = false
var left_leg: MeshInstance3D
var right_leg: MeshInstance3D
var left_arm: MeshInstance3D
var right_arm: MeshInstance3D
var tail: MeshInstance3D
var dinosaur_parts: Node3D
var animation_time: float = 0.0
@export var hunger_drain_per_second: float = 0.025
@export var thirst_drain_per_second: float = 0.04
@export var stamina_drain_per_second: float = 7.0
@export var stamina_recovery_per_second: float = 12.0
@export var sprint_speed_multiplier: float = 1.65
@export var sprint_stamina_cost_multiplier: float = 2.0
var sprint_requested: bool = false
var sprint_exhausted: bool = false

func _ready() -> void:
	_build_dinosaur_model()


# Procedural anatomy replaces the original primitive toy-like dinosaur meshes.
# The segmented tapered mesh keeps an organic silhouette without external assets.
func _build_dinosaur_model() -> void:
	for part_name in ["Body", "Head", "Tail", "LeftLeg", "RightLeg", "Snout", "LeftArm", "RightArm"]:
		var old_part := get_node_or_null(part_name)
		if old_part != null:
			old_part.queue_free()
	dinosaur_parts = Node3D.new()
	dinosaur_parts.name = "DinosaurModel"
	add_child(dinosaur_parts)
	var hide_mat := _dino_material(Color(0.24, 0.34, 0.16))
	var belly_mat := _dino_material(Color(0.48, 0.43, 0.29))
	var dark_mat := _dino_material(Color(0.13, 0.18, 0.10))
	_add_dino_mesh("Torso", _tube_z([Vector3(0,0,-0.66),Vector3(0,0.02,-0.42),Vector3(0,0.02,-0.12),Vector3(0,0,0.22),Vector3(0,0,0.52),Vector3(0,0,0.72)], [Vector2(0.12,0.14),Vector2(0.34,0.35),Vector2(0.48,0.43),Vector2(0.46,0.40),Vector2(0.30,0.29),Vector2(0.12,0.13)], 14), Vector3(0,0.68,0), hide_mat)
	_add_dino_mesh("Belly", _tube_z([Vector3(0,0,-0.38),Vector3(0,0,-0.12),Vector3(0,0,0.18),Vector3(0,0,0.38)], [Vector2(0.20,0.15),Vector2(0.31,0.16),Vector2(0.29,0.15),Vector2(0.18,0.12)], 12), Vector3(0,0.49,0), belly_mat)
	_add_dino_mesh("Neck", _tube_z([Vector3(0,0,0.22),Vector3(0,0,-0.02),Vector3(0,0,-0.29),Vector3(0,0,-0.50)], [Vector2(0.27,0.27),Vector2(0.25,0.25),Vector2(0.20,0.20),Vector2(0.16,0.16)], 12), Vector3(0,0.88,0), hide_mat)
	_add_dino_mesh("Skull", _tube_z([Vector3(0,0,0.02),Vector3(0,0,-0.12),Vector3(0,0,-0.32),Vector3(0,0,-0.48)], [Vector2(0.19,0.17),Vector2(0.22,0.18),Vector2(0.17,0.13),Vector2(0.11,0.09)], 12), Vector3(0,1.02,-0.43), hide_mat)
	_add_dino_mesh("Jaw", _tube_z([Vector3(0,0,0.02),Vector3(0,0,-0.13),Vector3(0,0,-0.29)], [Vector2(0.13,0.065),Vector2(0.12,0.055),Vector2(0.07,0.04)], 10), Vector3(0,0.91,-0.48), dark_mat)
	tail = _add_dino_mesh("Tail", _tube_z([Vector3(0,0,0),Vector3(0,0,0.25),Vector3(0,0,0.52),Vector3(0,0,0.82),Vector3(0,0,1.12),Vector3(0,0,1.42),Vector3(0,0,1.64)], [Vector2(0.28,0.27),Vector2(0.24,0.23),Vector2(0.18,0.18),Vector2(0.13,0.13),Vector2(0.085,0.085),Vector2(0.04,0.04),Vector2(0.008,0.01)], 12), Vector3(0,0.57,0.48), hide_mat)
	left_leg = _add_limb("LeftLeg", Vector3(-0.30,0.46,0.20), -1.0, hide_mat)
	right_leg = _add_limb("RightLeg", Vector3(0.30,0.46,0.20), 1.0, hide_mat)
	left_arm = _add_dino_mesh("LeftArm", _tube_y([Vector3(0,0.12,0),Vector3(-0.02,-0.05,-0.02),Vector3(-0.04,-0.18,-0.10)], [Vector2(0.095,0.09),Vector2(0.075,0.07),Vector2(0.045,0.045)], 8), Vector3(-0.29,0.77,-0.27), hide_mat)
	right_arm = _add_dino_mesh("RightArm", _tube_y([Vector3(0,0.12,0),Vector3(0.02,-0.05,-0.02),Vector3(0.04,-0.18,-0.10)], [Vector2(0.095,0.09),Vector2(0.075,0.07),Vector2(0.045,0.045)], 8), Vector3(0.29,0.77,-0.27), hide_mat)
	# Small ridges and eyes break up the silhouette without oversized spherical parts.
	for i in range(6):
		var z := -0.20 + float(i) * 0.16
		_add_dino_mesh("DorsalRidge%d" % i, _tube_y([Vector3(0,0.0,0),Vector3(0,0.07,0),Vector3(0,0.12,0.015)], [Vector2(0.055,0.045),Vector2(0.035,0.03),Vector2(0.002,0.002)], 6), Vector3(0,1.05,z), dark_mat)
	for side in [-1.0, 1.0]:
		var eye := _add_dino_mesh("Eye", _tube_z([Vector3(0,0,0),Vector3(0,0,-0.025)], [Vector2(0.035,0.035),Vector2(0.025,0.025)], 8), Vector3(side*0.17,1.075,-0.55), _dino_material(Color(0.92,0.72,0.22)))
		_add_dino_mesh("Nostril", _tube_z([Vector3(0,0,0),Vector3(0,0,-0.018)], [Vector2(0.018,0.018),Vector2(0.01,0.01)], 6), Vector3(side*0.075,1.01,-0.89), dark_mat)

func _add_limb(part_name: String, at: Vector3, side: float, material: Material) -> MeshInstance3D:
	var pivot := Node3D.new()
	pivot.name = part_name + "Pivot"
	pivot.position = at
	dinosaur_parts.add_child(pivot)
	var limb := MeshInstance3D.new()
	limb.name = part_name
	limb.mesh = _tube_y([Vector3(0,0.10,0),Vector3(0,-0.10,0.015),Vector3(side*0.015,-0.33,-0.015),Vector3(side*0.02,-0.48,-0.12),Vector3(side*0.02,-0.49,-0.24)], [Vector2(0.16,0.15),Vector2(0.145,0.13),Vector2(0.105,0.10),Vector2(0.075,0.07),Vector2(0.12,0.15)], 10)
	limb.position = Vector3.ZERO
	limb.material_override = material
	pivot.add_child(limb)
	return limb

func _add_dino_mesh(part_name: String, mesh_data: ArrayMesh, at: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = mesh_data
	part.position = at
	part.material_override = material
	dinosaur_parts.add_child(part)
	return part

func _dino_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.86
	material.metallic = 0.0
	return material

func _tube_z(points: Array, radii: Array, sides: int) -> ArrayMesh:
	return _tube_mesh(points, radii, sides, true)

func _tube_y(points: Array, radii: Array, sides: int) -> ArrayMesh:
	return _tube_mesh(points, radii, sides, false)

func _tube_mesh(points: Array, radii: Array, sides: int, along_z: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(points.size() - 1):
		for j in range(sides):
			var a0 := TAU * float(j) / float(sides)
			var a1 := TAU * float(j + 1) / float(sides)
			var p00 := _ring_point(points[ring], radii[ring], a0, along_z)
			var p01 := _ring_point(points[ring], radii[ring], a1, along_z)
			var p10 := _ring_point(points[ring+1], radii[ring+1], a0, along_z)
			var p11 := _ring_point(points[ring+1], radii[ring+1], a1, along_z)
			st.add_vertex(p00); st.add_vertex(p10); st.add_vertex(p11)
			st.add_vertex(p00); st.add_vertex(p11); st.add_vertex(p01)
	st.generate_normals()
	return st.commit()

func _ring_point(center: Vector3, radius: Vector2, angle: float, along_z: bool) -> Vector3:
	if along_z:
		return center + Vector3(cos(angle) * radius.x, sin(angle) * radius.y, 0)
	return center + Vector3(cos(angle) * radius.x, 0, sin(angle) * radius.y)

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

func _update_dino_animation(delta: float, is_moving: bool) -> void:
	if is_moving:
		animation_time += delta * 9.0
		var stride := sin(animation_time) * 0.42
		left_leg.rotation.x = stride
		right_leg.rotation.x = -stride
		left_arm.rotation.x = 0.2 - stride * 0.45
		right_arm.rotation.x = 0.2 + stride * 0.45
		tail.rotation.y = sin(animation_time * 0.5) * 0.12
	else:
		left_leg.rotation.x = move_toward(left_leg.rotation.x, 0.0, delta * 3.0)
		right_leg.rotation.x = move_toward(right_leg.rotation.x, 0.0, delta * 3.0)
		left_arm.rotation.x = move_toward(left_arm.rotation.x, 0.2, delta * 3.0)
		right_arm.rotation.x = move_toward(right_arm.rotation.x, 0.2, delta * 3.0)
		tail.rotation.y = move_toward(tail.rotation.y, 0.0, delta * 0.5)
