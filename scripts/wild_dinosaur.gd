extends CharacterBody3D

## Lightweight roaming herbivore for the mobile survival prototype.
@export var walk_speed: float = 1.7
@export var flee_speed: float = 4.0
@export var notice_distance: float = 7.0

var player_target: Node3D
var rng := RandomNumberGenerator.new()
var wander_destination := Vector3.ZERO
var decision_timer: float = 0.0
var flee_timer: float = 0.0
var flee_direction := Vector3.ZERO
var animation_clock: float = 0.0
var legs: Array[MeshInstance3D] = []
var tail_mesh: MeshInstance3D
var species_asset_path: String = "res://assets/dinos/Stegosaurus.glb"
var imported_model_active: bool = false
var imported_model_info: Dictionary = {}
var imported_animation_time: float = 0.0
@export var max_health: float = 100.0
var health: float = 100.0
var is_dead: bool = false
var collision_shape: CollisionShape3D

func _ready() -> void:
	health = max_health
	rng.randomize()
	_create_collision()
	_build_visual()
	_pick_destination()

func set_target(target: Node3D) -> void:
	player_target = target

func _create_collision() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "WildDinosaurCollision"
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.5
	collision.shape = shape
	collision_shape = collision
	add_child(collision)

func _build_visual() -> void:
	# Use an imported, animated herbivore when the optional build-time asset exists.
	imported_model_info = PrimalisDinoAssetLoader.attach_model(self, species_asset_path, 1.4, PI, -0.75)
	if not imported_model_info.is_empty():
		imported_model_active = true
		PrimalisDinoAssetLoader.set_segment(imported_model_info, "idle", 0.0)
		return
	var skin := _dino_material(Color(0.39, 0.43, 0.22))
	var belly := _dino_material(Color(0.62, 0.55, 0.37))
	var dark := _dino_material(Color(0.20, 0.25, 0.12))
	var eye_material := _dino_material(Color(0.92, 0.68, 0.20))

	_add_mesh("Torso", _tube_z(
		[Vector3(0,0,-0.58),Vector3(0,0.02,-0.35),Vector3(0,0,0.02),Vector3(0,-0.01,0.32),Vector3(0,-0.04,0.58)],
		[Vector2(0.12,0.13),Vector2(0.31,0.30),Vector2(0.42,0.36),Vector2(0.34,0.30),Vector2(0.15,0.16)], 12),
		Vector3.ZERO, skin)
	_add_mesh("Belly", _tube_z(
		[Vector3(0,0,-0.28),Vector3(0,0,0.02),Vector3(0,-0.01,0.30)],
		[Vector2(0.22,0.12),Vector2(0.30,0.13),Vector2(0.21,0.11)], 10),
		Vector3(0,-0.10,0), belly)
	_add_mesh("Neck", _tube_z(
		[Vector3(0,0.03,0.02),Vector3(0,0.13,-0.12),Vector3(0,0.30,-0.28),Vector3(0,0.43,-0.43),Vector3(0,0.46,-0.55)],
		[Vector2(0.25,0.26),Vector2(0.22,0.22),Vector2(0.17,0.18),Vector2(0.14,0.15),Vector2(0.12,0.12)], 12),
		Vector3(0,0.14,-0.36), skin)
	_add_mesh("Skull", _tube_z(
		[Vector3(0,0,0.02),Vector3(0,0,-0.12),Vector3(0,-0.01,-0.27),Vector3(0,-0.03,-0.39)],
		[Vector2(0.14,0.13),Vector2(0.17,0.14),Vector2(0.13,0.10),Vector2(0.08,0.07)], 10),
		Vector3(0,0.60,-0.77), skin)
	_add_mesh("Jaw", _tube_z(
		[Vector3(0,0,0.01),Vector3(0,0,-0.13),Vector3(0,0,-0.28)],
		[Vector2(0.10,0.05),Vector2(0.11,0.05),Vector2(0.06,0.035)], 8),
		Vector3(0,0.52,-0.80), dark)
	tail_mesh = _add_mesh("Tail", _tube_z(
		[Vector3(0,0,0),Vector3(0,0,0.24),Vector3(0,-0.02,0.48),Vector3(0,-0.05,0.76),Vector3(0,-0.08,1.02),Vector3(0,-0.10,1.24)],
		[Vector2(0.25,0.23),Vector2(0.20,0.19),Vector2(0.14,0.14),Vector2(0.09,0.09),Vector2(0.045,0.05),Vector2(0.008,0.012)], 10),
		Vector3(0,-0.03,0.43), skin)

	# Four narrow, tapered legs create a quadruped silhouette without toy-like spheres.
	for side in [-1.0, 1.0]:
		for fore in [true, false]:
			var z_offset := -0.30 if fore else 0.34
			var leg := _add_mesh("Leg", _tube_y(
				[Vector3(0,0.08,0),Vector3(side*0.015,-0.14,-0.01),Vector3(side*0.035,-0.39,-0.03),Vector3(side*0.05,-0.61,-0.09),Vector3(side*0.05,-0.69,-0.16)],
				[Vector2(0.12,0.12),Vector2(0.105,0.10),Vector2(0.075,0.075),Vector2(0.075,0.08),Vector2(0.12,0.14)], 8),
				Vector3(side*0.26,-0.02,z_offset), skin)
			legs.append(leg)

	# Small plates and eyes add definition but remain inexpensive for phones.
	for i in range(5):
		var z := -0.23 + float(i) * 0.17
		_add_mesh("DorsalRidge", _tube_y(
			[Vector3(0,0,0),Vector3(0,0.07,0),Vector3(0,0.11,0.01)],
			[Vector2(0.045,0.04),Vector2(0.028,0.025),Vector2(0.002,0.002)], 6),
			Vector3(0,0.30,z), dark)
	for side in [-1.0, 1.0]:
		_add_mesh("Eye", _tube_z(
			[Vector3(0,0,0),Vector3(0,0,-0.02)],
			[Vector2(0.025,0.025),Vector2(0.018,0.018)], 8),
			Vector3(side*0.13,0.63,-0.94), eye_material)

func _add_mesh(part_name: String, mesh_data: ArrayMesh, at: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = mesh_data
	part.position = at
	part.material_override = material
	add_child(part)
	return part

func _dino_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	return material

func _tube_z(points: Array, radii: Array, sides: int) -> ArrayMesh:
	return _tube_mesh(points, radii, sides, true)

func _tube_y(points: Array, radii: Array, sides: int) -> ArrayMesh:
	return _tube_mesh(points, radii, sides, false)

func _tube_mesh(points: Array, radii: Array, sides: int, along_z: bool) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(points.size() - 1):
		for j in range(sides):
			var a0 := TAU * float(j) / float(sides)
			var a1 := TAU * float(j + 1) / float(sides)
			var p00 := _ring_point(points[ring], radii[ring], a0, along_z)
			var p01 := _ring_point(points[ring], radii[ring], a1, along_z)
			var p10 := _ring_point(points[ring + 1], radii[ring + 1], a0, along_z)
			var p11 := _ring_point(points[ring + 1], radii[ring + 1], a1, along_z)
			surface.add_vertex(p00)
			surface.add_vertex(p11)
			surface.add_vertex(p10)
			surface.add_vertex(p00)
			surface.add_vertex(p01)
			surface.add_vertex(p11)
	surface.generate_normals()
	return surface.commit()

func _ring_point(center: Vector3, radius: Vector2, angle: float, along_z: bool) -> Vector3:
	if along_z:
		return center + Vector3(cos(angle) * radius.x, sin(angle) * radius.y, 0)
	return center + Vector3(cos(angle) * radius.x, 0, sin(angle) * radius.y)

func _pick_destination() -> void:
	wander_destination = Vector3(rng.randf_range(-27.0, 27.0), global_position.y, rng.randf_range(-27.0, 27.0))
	decision_timer = rng.randf_range(3.0, 6.0)

func receive_damage(amount: float, source: Node3D = null) -> void:
	if is_dead or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	if health <= 0.0:
		is_dead = true
		flee_timer = 0.0
		velocity = Vector3.ZERO
		set_meta("kind", "meat")
		set_meta("available", true)
		if is_instance_valid(collision_shape):
			collision_shape.set_deferred("disabled", true)
		if imported_model_active:
			PrimalisDinoAssetLoader.set_segment(imported_model_info, "dead", 0.0)
		if is_instance_valid(player_target):
			player_target.set("status_message", "¡Cacería exitosa! Acércate y pulsa USAR para comer carne.")
	else:
		var attacker := source if is_instance_valid(source) else player_target
		if is_instance_valid(attacker):
			var away := global_position - attacker.global_position
			away.y = 0.0
			if away.length_squared() > 0.01:
				flee_direction = away.normalized()
				flee_timer = 3.0
		if is_instance_valid(player_target):
			player_target.set("status_message", "Mordida acertada. Salud del herbívoro: %d." % roundi(health))

func revive() -> void:
	health = max_health
	is_dead = false
	velocity = Vector3.ZERO
	flee_timer = 0.0
	if has_meta("kind"):
		remove_meta("kind")
	if has_meta("available"):
		remove_meta("available")
	if is_instance_valid(collision_shape):
		collision_shape.set_deferred("disabled", false)
	visible = true
	_pick_destination()

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector3.ZERO
		return
	var move_dir := Vector3.ZERO
	var current_speed := walk_speed

	if is_instance_valid(player_target):
		var away := global_position - player_target.global_position
		away.y = 0.0
		if away.length() < notice_distance:
			if away.length_squared() < 0.01:
				away = Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))
			flee_direction = away.normalized()
			flee_timer = 2.1

	if flee_timer > 0.0:
		flee_timer = maxf(0.0, flee_timer - delta)
		move_dir = flee_direction
		current_speed = flee_speed
	else:
		decision_timer -= delta
		var to_destination := wander_destination - global_position
		to_destination.y = 0.0
		if decision_timer <= 0.0 or to_destination.length() < 1.2:
			_pick_destination()
			to_destination = wander_destination - global_position
			to_destination.y = 0.0
		if to_destination.length_squared() > 0.01:
			move_dir = to_destination.normalized()

	# Turn back toward the playable area if the creature is pushed near an edge.
	if absf(global_position.x) > 32.0 or absf(global_position.z) > 32.0:
		var inward := Vector3(-global_position.x, 0.0, -global_position.z)
		move_dir = inward.normalized()
		current_speed = walk_speed

	if move_dir.length_squared() > 0.001:
		velocity.x = move_dir.x * current_speed
		velocity.z = move_dir.z * current_speed
		rotation.y = lerp_angle(rotation.y, atan2(-move_dir.x, -move_dir.z), 5.0 * delta)
		animation_clock += delta * (8.0 if current_speed > walk_speed else 4.0)
		if imported_model_active:
			imported_animation_time += delta
			PrimalisDinoAssetLoader.set_segment(imported_model_info, "walk", imported_animation_time)
		else:
			for i in range(legs.size()):
				var phase := PI if i == 1 or i == 2 else 0.0
				legs[i].rotation.x = sin(animation_clock + phase) * (0.12 if current_speed == walk_speed else 0.22)
			if is_instance_valid(tail_mesh):
				tail_mesh.rotation.y = sin(animation_clock * 0.55) * 0.10
	else:
		velocity.x = move_toward(velocity.x, 0.0, walk_speed * 3.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, walk_speed * 3.0 * delta)
		if imported_model_active:
			imported_animation_time += delta
			PrimalisDinoAssetLoader.set_segment(imported_model_info, "idle", imported_animation_time)
		else:
			for leg in legs:
				leg.rotation.x = move_toward(leg.rotation.x, 0.0, 2.0 * delta)

	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
