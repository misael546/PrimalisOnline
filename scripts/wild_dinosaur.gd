extends CharacterBody3D

## Wildlife behavior controller. Creature visuals come from licensed external GLBs.
@export var walk_speed: float = 1.7
@export var flee_speed: float = 4.0
@export var notice_distance: float = 7.0

var player_target: Node3D
var rng := RandomNumberGenerator.new()
var wander_destination := Vector3.ZERO
var decision_timer: float = 0.0
var flee_timer: float = 0.0
var flee_direction := Vector3.ZERO
var species_asset_path: String = "res://assets/dinos/Stegosaurus.glb"
var species_target_height: float = 1.5
var imported_model_active: bool = false
var imported_model_info: Dictionary = {}
var imported_animation_time: float = 0.0
@export var max_health: float = 100.0
var health: float = 100.0
var is_dead: bool = false
var collision_shape: CollisionShape3D
var home_position: Vector3 = Vector3.ZERO
@export var roam_radius: float = 105.0
const WILDLIFE_WORLD_LIMIT: float = 2250.0

func _ready() -> void:
	health = max_health
	home_position = global_position
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
	imported_model_info = PrimalisDinoAssetLoader.attach_model(self, species_asset_path, species_target_height, PI, -0.75)
	if imported_model_info.is_empty():
		push_error("Required licensed herbivore model failed to load: %s" % species_asset_path)
		return
	imported_model_active = true
	PrimalisDinoAssetLoader.set_segment(imported_model_info, "idle", 0.0)

func _pick_destination() -> void:
	var angle := rng.randf_range(0.0, TAU)
	var distance := rng.randf_range(8.0, roam_radius)
	var candidate := home_position + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
	candidate.x = clampf(candidate.x, -WILDLIFE_WORLD_LIMIT, WILDLIFE_WORLD_LIMIT)
	candidate.z = clampf(candidate.z, -WILDLIFE_WORLD_LIMIT, WILDLIFE_WORLD_LIMIT)
	wander_destination = Vector3(candidate.x, global_position.y, candidate.z)
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

func _recover_from_terrain_failure() -> void:
	var world_root := get_parent()
	if not is_instance_valid(world_root) or not world_root.has_method("_terrain_height_at"):
		return
	var safe_x := clampf(global_position.x, -2240.0, 2240.0)
	var safe_z := clampf(global_position.z, -2240.0, 2240.0)
	var ground_y := float(world_root.call("_terrain_height_at", Vector2(safe_x, safe_z)))
	var outside_world := absf(global_position.x) > 2250.0 or absf(global_position.z) > 2250.0
	var below_terrain := global_position.y < ground_y - 5.0
	if not outside_world and not below_terrain:
		return
	global_position = Vector3(safe_x, ground_y + 0.9, safe_z)
	velocity = Vector3.ZERO
	_pick_destination()

func _physics_process(delta: float) -> void:
	_recover_from_terrain_failure()
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
	if absf(global_position.x) > WILDLIFE_WORLD_LIMIT or absf(global_position.z) > WILDLIFE_WORLD_LIMIT:
		var inward := Vector3(-global_position.x, 0.0, -global_position.z)
		move_dir = inward.normalized()
		current_speed = walk_speed

	if move_dir.length_squared() > 0.001:
		velocity.x = move_dir.x * current_speed
		velocity.z = move_dir.z * current_speed
		rotation.y = lerp_angle(rotation.y, atan2(-move_dir.x, -move_dir.z), 5.0 * delta)
		imported_animation_time += delta
		PrimalisDinoAssetLoader.set_segment(imported_model_info, "walk", imported_animation_time)
	else:
		velocity.x = move_toward(velocity.x, 0.0, walk_speed * 3.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, walk_speed * 3.0 * delta)
		imported_animation_time += delta
		PrimalisDinoAssetLoader.set_segment(imported_model_info, "idle", imported_animation_time)

	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
