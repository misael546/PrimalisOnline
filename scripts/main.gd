extends Node3D

@onready var player: CharacterBody3D = $Player
var status_label: Label
var prompt_label: Label
var feedback_label: Label
var nearby_item: Node3D
var mobile_ui: Control
var move_buttons: Array[Button] = []
var use_button: Button
var sprint_button: Button
var attack_button: Button
var attack_cooldown: float = 0.0
var food_respawn_timers: Dictionary = {}
var survival_bars: Dictionary = {}
var survival_values: Dictionary = {}
var survival_labels: Dictionary = {}

func _ready() -> void:
	_apply_ground_material()
	_apply_world_sky()
	_build_world_props()
	_build_mobile_ui()
	get_viewport().size_changed.connect(_layout_mobile_ui)
	_layout_mobile_ui()

func _process(_delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - _delta)
	if is_instance_valid(status_label):
		status_label.text = "PRIMALIS ONLINE"
		_update_survival_hud()

	_update_food_respawns(_delta)
	_update_nearby_item()
	if is_instance_valid(feedback_label):
		feedback_label.text = str(player.get("status_message"))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			_interact()
		elif event.keycode == KEY_SPACE:
			_attack()

func _apply_ground_material() -> void:
	var ground_mesh := get_node_or_null("Ground/Mesh") as MeshInstance3D
	if ground_mesh == null:
		push_error("Ground mesh is missing.")
		return
	# Poly Haven Forest Ground 01 — external CC0 PBR maps, deliberately kept at 1K for mobile.
	var albedo := load("res://assets/textures/forrest_ground_01_diff_1k.jpg") as Texture2D
	var normal := load("res://assets/textures/forrest_ground_01_nor_gl_1k.jpg") as Texture2D
	var roughness := load("res://assets/textures/forrest_ground_01_rough_1k.jpg") as Texture2D
	if albedo == null or normal == null or roughness == null:
		push_error("Required Poly Haven terrain PBR textures did not load.")
		return
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_texture = albedo
	ground_material.normal_enabled = true
	ground_material.normal_texture = normal
	ground_material.normal_scale = 0.7
	ground_material.roughness = 1.0
	ground_material.roughness_texture = roughness
	ground_material.uv1_scale = Vector3(100.0, 100.0, 1.0)
	ground_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ground_mesh.material_override = ground_material


func _apply_world_sky() -> void:
	var world_environment := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_environment == null or world_environment.environment == null:
		push_error("WorldEnvironment is missing.")
		return
	# CC0 Poly Haven pure-sky HDRI instead of a flat-color background.
	var panorama_texture := load("res://assets/sky/kloppenheim_06_puresky_1k.hdr") as Texture2D
	if panorama_texture == null:
		push_error("Required Poly Haven sky HDRI did not load.")
		return
	var panorama_material := PanoramaSkyMaterial.new()
	panorama_material.panorama = panorama_texture
	var sky := Sky.new()
	sky.sky_material = panorama_material
	world_environment.environment.background_mode = Environment.BG_SKY
	world_environment.environment.sky = sky
	world_environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	world_environment.environment.ambient_light_energy = 0.65


func _build_world_props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 64281

	_add_pond(Vector3(15.0, 0.035, 15.0), Vector2(10.0, 7.0))
	_add_water_marker(Vector3(15.0, 0.0, 15.0))
	_add_food_plant(Vector3(-8.0, 0.0, 4.0), "Bush001.glb", 1)
	_add_food_plant(Vector3(34.0, 0.0, -40.0), "Bush002.glb", 2)
	_add_food_plant(Vector3(-52.0, 0.0, -26.0), "Bush001.glb", 3)
	_add_food_plant(Vector3(54.0, 0.0, 38.0), "Bush002.glb", 4)
	_add_food_plant(Vector3(-22.0, 0.0, 63.0), "Bush001.glb", 5)
	_add_food_plant(Vector3(64.0, 0.0, -59.0), "Bush002.glb", 6)

	# Visible nature is supplied by the licensed external GLBs, not hand-built primitive meshes.
	var tree_index := 0
	for attempt in range(160):
		if tree_index >= 82:
			break
		var candidate := Vector3(rng.randf_range(-71.0, 71.0), 0.0, rng.randf_range(-71.0, 71.0))
		if _is_near_spawn_or_pond(candidate, 11.0, 12.0):
			continue
		if _is_near_existing_scenery(candidate, 5.8):
			continue
		var tree_path := "res://assets/environment/TreeHigh001.glb" if tree_index % 2 == 0 else "res://assets/environment/TreeHigh002.glb"
		_add_tree(candidate, tree_path, rng.randf_range(4.6, 7.2), rng.randf_range(0.0, TAU), tree_index + 1)
		tree_index += 1

	var rock_index := 0
	for attempt in range(110):
		if rock_index >= 34:
			break
		var candidate := Vector3(rng.randf_range(-73.0, 73.0), 0.0, rng.randf_range(-73.0, 73.0))
		if _is_near_spawn_or_pond(candidate, 9.0, 9.0) or _is_near_existing_scenery(candidate, 4.0):
			continue
		var rock_path := "res://assets/environment/Rock001.glb" if rock_index % 3 == 0 else ("res://assets/environment/Rock002.glb" if rock_index % 3 == 1 else "res://assets/environment/Rock003.glb")
		_add_rock(candidate, rock_path, rng.randf_range(0.8, 2.0), rng.randf_range(0.0, TAU), rock_index + 1)
		rock_index += 1

	var bush_index := 0
	for attempt in range(100):
		if bush_index >= 40:
			break
		var candidate := Vector3(rng.randf_range(-72.0, 72.0), 0.0, rng.randf_range(-72.0, 72.0))
		if _is_near_spawn_or_pond(candidate, 8.0, 8.0):
			continue
		var bush_path := "res://assets/environment/Bush001.glb" if bush_index % 2 == 0 else "res://assets/environment/Bush002.glb"
		_add_environment_prop("ExternalBush_%03d" % (bush_index + 1), bush_path, candidate, rng.randf_range(1.0, 1.8), rng.randf_range(0.0, TAU))
		bush_index += 1

	var grass_index := 0
	for attempt in range(120):
		if grass_index >= 56:
			break
		var candidate := Vector3(rng.randf_range(-74.0, 74.0), 0.0, rng.randf_range(-74.0, 74.0))
		if _is_near_spawn_or_pond(candidate, 7.5, 8.0):
			continue
		var grass_path := "res://assets/environment/Grass00%d.glb" % (grass_index % 3 + 1)
		_add_environment_prop("ExternalGrass_%03d" % (grass_index + 1), grass_path, candidate, rng.randf_range(0.55, 1.0), rng.randf_range(0.0, TAU))
		grass_index += 1

	# A CC0 mountain belt beyond the playable boundary; the ground extends behind it
	# so its edge is not immediately visible like a small floating island.
	for index in range(12):
		var angle := TAU * float(index) / 12.0
		var position := Vector3(cos(angle) * 119.0, 0.0, sin(angle) * 119.0)
		var mountain_path := "res://assets/environment/MountainFar00%d.glb" % (index % 3 + 1)
		_add_environment_prop("BackgroundMountain_%02d" % (index + 1), mountain_path, position, rng.randf_range(25.0, 32.0), -angle)

	_build_world_boundaries()
	_spawn_wild_dinosaurs()


func _is_near_spawn_or_pond(point: Vector3, spawn_radius: float, pond_radius: float) -> bool:
	if Vector2(point.x, point.z).length() < spawn_radius:
		return true
	return Vector2(point.x - 15.0, point.z - 15.0).length() < pond_radius


func _is_near_existing_scenery(point: Vector3, radius: float) -> bool:
	for item in get_children():
		if item.has_meta("scenery"):
			var offset := Vector2(point.x - item.global_position.x, point.z - item.global_position.z)
			if offset.length() < radius:
				return true
	return false


func _build_world_boundaries() -> void:
	# Invisible collision boundary; the visible terrain extends well beyond playable space.
	_add_boundary_wall(Vector3(0.0, 2.0, -81.5), Vector3(164.0, 4.0, 1.0))
	_add_boundary_wall(Vector3(0.0, 2.0, 81.5), Vector3(164.0, 4.0, 1.0))
	_add_boundary_wall(Vector3(-81.5, 2.0, 0.0), Vector3(1.0, 4.0, 164.0))
	_add_boundary_wall(Vector3(81.5, 2.0, 0.0), Vector3(1.0, 4.0, 164.0))


func _spawn_wild_dinosaurs() -> void:
	var wild_script := load("res://scripts/wild_dinosaur.gd") as Script
	if wild_script == null:
		push_error("Wild dinosaur script is missing.")
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 91811
	var species_paths: Array[String] = [
		"res://assets/dinos/Stegosaurus.glb",
		"res://assets/dinos/Triceratops.glb",
		"res://assets/dinos/Ankylosaurus.glb",
		"res://assets/dinos/Pachycephalosaurus.glb",
		"res://assets/dinos/Oviraptor.glb"
	]
	for index in range(species_paths.size()):
		var spawn_point := Vector3.ZERO
		var found_safe_spot := false
		for attempt in range(120):
			var candidate := Vector3(rng.randf_range(-64.0, 64.0), 0.88, rng.randf_range(-64.0, 64.0))
			if Vector2(candidate.x, candidate.z).length() < 14.0:
				continue
			if Vector2(candidate.x - 15.0, candidate.z - 15.0).length() < 12.0:
				continue
			if _is_near_existing_scenery(candidate, 4.0):
				continue
			spawn_point = candidate
			found_safe_spot = true
			break
		if not found_safe_spot:
			push_warning("Could not find a safe spawn point for wildlife index %d." % index)
			continue
		var creature := CharacterBody3D.new()
		creature.set_script(wild_script)
		creature.position = spawn_point
		creature.set("species_asset_path", species_paths[index])
		var target_height := 1.35 if species_paths[index].ends_with("Oviraptor.glb") else (1.55 if species_paths[index].ends_with("Triceratops.glb") else 1.5)
		creature.set("species_target_height", target_height)
		add_child(creature)
		creature.name = "WildDinosaur_%02d" % (index + 1)
		creature.call("set_target", player)


func _add_boundary_wall(at: Vector3, wall_size: Vector3) -> void:
	var wall := StaticBody3D.new()
	wall.position = at
	wall.name = "WorldBoundary"
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = wall_size
	collision.shape = shape
	wall.add_child(collision)
	add_child(wall)


func _add_tree(at: Vector3, asset_path: String, target_height: float, yaw: float, index: int) -> void:
	var tree := Node3D.new()
	tree.name = "ExternalTree_%03d" % index
	tree.position = at
	tree.set_meta("scenery", true)
	add_child(tree)
	if not _add_external_visual(tree, asset_path, target_height, yaw):
		push_error("External tree asset failed: %s" % asset_path)
		return
	var trunk_body := StaticBody3D.new()
	trunk_body.name = "TreeCollision"
	trunk_body.position.y = 1.25
	tree.add_child(trunk_body)
	var trunk_collision := CollisionShape3D.new()
	var trunk_shape := CapsuleShape3D.new()
	trunk_shape.radius = 0.34
	trunk_shape.height = 2.5
	trunk_collision.shape = trunk_shape
	trunk_body.add_child(trunk_collision)


func _add_rock(at: Vector3, asset_path: String, target_height: float, yaw: float, index: int) -> void:
	var rock := Node3D.new()
	rock.name = "ExternalRock_%03d" % index
	rock.position = at
	rock.set_meta("scenery", true)
	add_child(rock)
	if not _add_external_visual(rock, asset_path, target_height, yaw):
		push_error("External rock asset failed: %s" % asset_path)
		return
	var rock_body := StaticBody3D.new()
	rock_body.position.y = target_height * 0.23
	rock.add_child(rock_body)
	var rock_collision := CollisionShape3D.new()
	var rock_shape := SphereShape3D.new()
	rock_shape.radius = target_height * 0.32
	rock_collision.shape = rock_shape
	rock_body.add_child(rock_collision)


func _add_environment_prop(instance_name: String, asset_path: String, at: Vector3, target_height: float, yaw: float) -> void:
	var prop := Node3D.new()
	prop.name = instance_name
	prop.position = at
	add_child(prop)
	if not _add_external_visual(prop, asset_path, target_height, yaw):
		push_error("External environment asset failed: %s" % asset_path)


func _add_food_plant(at: Vector3, asset_name: String, index: int) -> void:
	var plant := Node3D.new()
	plant.name = "FoodPlant_%02d" % index
	plant.position = at
	plant.set_meta("kind", "food")
	plant.set_meta("available", true)
	add_child(plant)
	var asset_path := "res://assets/environment/%s" % asset_name
	if not _add_external_visual(plant, asset_path, 1.45, 0.0):
		push_error("Food shrub model could not be loaded: %s" % asset_path)


func _add_water_marker(at: Vector3) -> void:
	var marker := Node3D.new()
	marker.name = "WaterSource"
	marker.position = at
	marker.set_meta("kind", "water")
	marker.set_meta("available", true)
	add_child(marker)


func _add_external_visual(host: Node3D, asset_path: String, target_height: float, yaw: float) -> bool:
	if not ResourceLoader.exists(asset_path):
		push_error("Required CC0 environment asset is missing: %s" % asset_path)
		return false
	var packed_scene := load(asset_path) as PackedScene
	if packed_scene == null:
		push_error("Could not import CC0 environment asset: %s" % asset_path)
		return false
	var model_node := packed_scene.instantiate()
	if not model_node is Node3D:
		model_node.queue_free()
		push_error("CC0 environment asset root is not Node3D: %s" % asset_path)
		return false
	var model := model_node as Node3D
	var normalizer := Node3D.new()
	normalizer.name = "NormalizedExternalAsset"
	host.add_child(normalizer)
	normalizer.add_child(model)
	var bounds_state: Dictionary = {"has_bounds": false, "bounds": AABB()}
	_collect_asset_bounds(model, Transform3D.IDENTITY, bounds_state)
	if not bool(bounds_state.get("has_bounds", false)):
		normalizer.queue_free()
		push_error("CC0 environment asset has no measurable mesh: %s" % asset_path)
		return false
	var bounds: AABB = bounds_state.get("bounds", AABB())
	var scale_factor := target_height / maxf(bounds.size.y, 0.05)
	var center := bounds.position + bounds.size * 0.5
	normalizer.rotation.y = yaw
	normalizer.scale = Vector3.ONE * scale_factor
	normalizer.position = -(normalizer.basis * Vector3(center.x, bounds.position.y, center.z))
	return true


func _collect_asset_bounds(node: Node, parent_transform: Transform3D, state: Dictionary) -> void:
	var current_transform := parent_transform
	if node is Node3D:
		current_transform = parent_transform * (node as Node3D).transform
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			var mesh_bounds := mesh_instance.mesh.get_aabb()
			for ix in range(2):
				for iy in range(2):
					for iz in range(2):
						var local_point := mesh_bounds.position + Vector3(
							mesh_bounds.size.x * float(ix),
							mesh_bounds.size.y * float(iy),
							mesh_bounds.size.z * float(iz)
						)
						var point := current_transform * local_point
						if bool(state.get("has_bounds", false)):
							var existing: AABB = state.get("bounds", AABB())
							state["bounds"] = existing.expand(point)
						else:
							state["bounds"] = AABB(point, Vector3.ZERO)
							state["has_bounds"] = true
	for child in node.get_children():
		_collect_asset_bounds(child, current_transform, state)


func _add_pond(at: Vector3, pond_size: Vector2) -> void:
	# A flattened ellipse with a narrow shoreline reads more naturally than a rectangular water plane.
	var ellipse_ratio := pond_size.y / pond_size.x
	var shoreline := MeshInstance3D.new()
	shoreline.name = "PondShoreline"
	var shore_mesh := CylinderMesh.new()
	shore_mesh.top_radius = pond_size.x * 0.52
	shore_mesh.bottom_radius = shore_mesh.top_radius
	shore_mesh.height = 0.035
	shore_mesh.radial_segments = 48
	shoreline.mesh = shore_mesh
	shoreline.position = Vector3(at.x, at.y - 0.018, at.z)
	shoreline.scale = Vector3(1.0, 1.0, ellipse_ratio)
	shoreline.material_override = _material(Color(0.29, 0.30, 0.17))
	shoreline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shoreline)

	var pond := MeshInstance3D.new()
	pond.name = "PondWater"
	var mesh := CylinderMesh.new()
	mesh.top_radius = pond_size.x * 0.48
	mesh.bottom_radius = mesh.top_radius
	mesh.height = 0.022
	mesh.radial_segments = 48
	pond.mesh = mesh
	pond.position = at
	pond.scale = Vector3(1.0, 1.0, ellipse_ratio)
	var water_shader := load("res://materials/water_pond.gdshader") as Shader
	if water_shader != null:
		var water_material := ShaderMaterial.new()
		water_material.shader = water_shader
		pond.material_override = water_material
	else:
		# Keep a visible fallback in case the shader resource cannot be loaded.
		var water := StandardMaterial3D.new()
		water.albedo_color = Color(0.09, 0.37, 0.52, 0.84)
		water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		water.roughness = 0.22
		water.metallic = 0.08
		pond.material_override = water
	pond.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pond)


func _update_nearby_item() -> void:
	nearby_item = null
	var best := 3.0
	for item in get_children():
		if not item.has_meta("kind") or not bool(item.get_meta("available", false)):
			continue
		var distance := player.global_position.distance_to(item.global_position)
		if str(item.get_meta("kind")) == "water":
			# The pond is wide: allow drinking around its shallow edges, not only at its center.
			var offset: Vector3 = player.global_position - item.global_position
			var inside_pond_reach := absf(offset.x) <= 6.5 and absf(offset.z) <= 5.0
			if inside_pond_reach:
				distance = 2.9
		if distance < best:
			best = distance
			nearby_item = item
	if is_instance_valid(prompt_label):
		if nearby_item == null:
			var hunger_value := float(player.get("hunger"))
			var thirst_value := float(player.get("thirst"))
			if hunger_value <= 20.0 and thirst_value <= 20.0:
				prompt_label.text = "¡Peligro! Busca agua y plantas pronto."
			elif thirst_value <= 20.0:
				prompt_label.text = "Tienes mucha sed. Busca el estanque."
			elif hunger_value <= 20.0:
				prompt_label.text = "Tienes mucha hambre. Busca plantas o caza."
			else:
				prompt_label.text = "Busca agua, plantas o caza"
		elif str(nearby_item.get_meta("kind")) == "water":
			prompt_label.text = "Pulsa USAR para beber agua"
		elif str(nearby_item.get_meta("kind")) == "meat":
			prompt_label.text = "Pulsa USAR para comer carne"
		else:
			prompt_label.text = "Pulsa USAR para comer plantas"

func _interact() -> void:
	if nearby_item == null:
		return
	var kind := str(nearby_item.get_meta("kind"))
	if kind == "water":
		player.call("consume_water")
	elif kind == "meat":
		player.call("eat_meat")
		nearby_item.set_meta("available", false)
		nearby_item.visible = false
		food_respawn_timers[nearby_item.get_instance_id()] = {"item": nearby_item, "remaining": 60.0}
	else:
		player.call("eat_food")
		nearby_item.set_meta("available", false)
		nearby_item.visible = false
		food_respawn_timers[nearby_item.get_instance_id()] = {"item": nearby_item, "remaining": 45.0}

func _attack() -> void:
	if attack_cooldown > 0.0 or bool(player.get("is_respawning")):
		return
	attack_cooldown = 0.75
	player.call("play_attack_animation")

	# Bites only connect with nearby dinosaurs in the T-Rex's forward arc and clear line of sight.
	var flat_forward := -player.global_transform.basis.z
	flat_forward.y = 0.0
	if flat_forward.length_squared() > 0.001:
		flat_forward = flat_forward.normalized()
	var closest: Node3D
	var closest_distance := 2.8
	for creature in get_children():
		if not creature is CharacterBody3D or not String(creature.name).begins_with("WildDinosaur_"):
			continue
		if bool(creature.get("is_dead")):
			continue
		var target := creature as Node3D
		var offset: Vector3 = target.global_position - player.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > closest_distance:
			continue
		if distance > 0.001 and flat_forward.dot(offset / distance) < 0.3:
			continue
		if not _has_clear_bite_path(target):
			continue
		closest_distance = distance
		closest = target
	if not is_instance_valid(closest):
		player.set("status_message", "Mira hacia un herbívoro, acércate y evita los obstáculos para morderlo.")
		return
	closest.call("receive_damage", 40.0, player)


func _has_clear_bite_path(target: Node3D) -> bool:
	var origin := player.global_position + Vector3(0.0, 0.65, 0.0)
	var target_point := target.global_position + Vector3(0.0, 0.65, 0.0)
	var query := PhysicsRayQueryParameters3D.create(origin, target_point)
	query.exclude = [player.get_rid()]
	query.collide_with_areas = false
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	return hit.get("collider") == target

func _update_food_respawns(delta: float) -> void:
	for item_id in food_respawn_timers.keys():
		var entry: Dictionary = food_respawn_timers[item_id]
		entry["remaining"] = float(entry["remaining"]) - delta
		if float(entry["remaining"]) <= 0.0:
			var item: Node3D = entry["item"]
			if is_instance_valid(item):
				if item.has_method("revive"):
					item.call("revive")
				else:
					item.set_meta("available", true)
					item.visible = true
			food_respawn_timers.erase(item_id)
		else:
			food_respawn_timers[item_id] = entry

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material

func _build_mobile_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "MobileHUD"
	add_child(layer)
	mobile_ui = Control.new()
	mobile_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(mobile_ui)

	status_label = Label.new()
	status_label.position = Vector2(18, 16)
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	status_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	status_label.add_theme_constant_override("shadow_offset_x", 2)
	status_label.add_theme_constant_override("shadow_offset_y", 2)
	mobile_ui.add_child(status_label)
	_add_stat_row(mobile_ui, "health", "SALUD", 43.0, Color(0.72, 0.18, 0.16))
	_add_stat_row(mobile_ui, "hunger", "HAMBRE", 67.0, Color(0.86, 0.48, 0.12))
	_add_stat_row(mobile_ui, "thirst", "SED", 91.0, Color(0.16, 0.52, 0.83))
	_add_stat_row(mobile_ui, "stamina", "RESIST.", 115.0, Color(0.36, 0.72, 0.24))
	prompt_label = Label.new()
	prompt_label.position = Vector2(18, 148)
	prompt_label.add_theme_font_size_override("font_size", 18)
	prompt_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	mobile_ui.add_child(prompt_label)

	feedback_label = Label.new()
	feedback_label.add_theme_font_size_override("font_size", 17)
	feedback_label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.82))
	feedback_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	feedback_label.add_theme_constant_override("shadow_offset_x", 2)
	feedback_label.add_theme_constant_override("shadow_offset_y", 2)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mobile_ui.add_child(feedback_label)

	_add_move_button(mobile_ui, "▲", "move_forward", Vector2.ZERO)
	_add_move_button(mobile_ui, "▼", "move_back", Vector2.ZERO)
	_add_move_button(mobile_ui, "◀", "move_left", Vector2.ZERO)
	_add_move_button(mobile_ui, "▶", "move_right", Vector2.ZERO)
	_add_use_button(mobile_ui)
	_add_sprint_button(mobile_ui)
	_add_attack_button(mobile_ui)

func _add_stat_row(parent: Control, key: String, caption: String, y_position: float, fill_color: Color) -> void:
	var row_label := Label.new()
	row_label.text = caption
	row_label.position = Vector2(18.0, y_position)
	row_label.size = Vector2(82.0, 22.0)
	row_label.add_theme_font_size_override("font_size", 15)
	row_label.add_theme_color_override("font_color", Color(0.98, 0.98, 0.92))
	row_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	row_label.add_theme_constant_override("shadow_offset_x", 1)
	row_label.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(row_label)
	survival_labels[key] = row_label

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.position = Vector2(108.0, y_position + 2.0)
	bar.size = Vector2(138.0, 15.0)
	bar.custom_minimum_size = bar.size
	var background_style := StyleBoxFlat.new()
	background_style.bg_color = Color(0.02, 0.03, 0.025, 0.82)
	background_style.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", background_style)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill_style)
	parent.add_child(bar)
	survival_bars[key] = bar

	var number_label := Label.new()
	number_label.text = "100"
	number_label.position = Vector2(252.0, y_position - 1.0)
	number_label.size = Vector2(34.0, 22.0)
	number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	number_label.add_theme_font_size_override("font_size", 15)
	number_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	number_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	number_label.add_theme_constant_override("shadow_offset_x", 1)
	number_label.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(number_label)
	survival_values[key] = number_label

func _update_survival_hud() -> void:
	_set_stat_hud("health", float(player.get("health")))
	_set_stat_hud("hunger", float(player.get("hunger")))
	_set_stat_hud("thirst", float(player.get("thirst")))
	_set_stat_hud("stamina", float(player.get("stamina")))

func _set_stat_hud(key: String, value: float) -> void:
	var bar := survival_bars.get(key) as ProgressBar
	var number_label := survival_values.get(key) as Label
	if is_instance_valid(bar):
		bar.value = clampf(value, 0.0, 100.0)
	if is_instance_valid(number_label):
		number_label.text = str(roundi(clampf(value, 0.0, 100.0)))

func _add_move_button(parent: Control, caption: String, action: String, offset: Vector2) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(70, 64)
	button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	button.position = offset
	button.size = Vector2(70, 64)
	button.add_theme_font_size_override("font_size", 26)
	button.modulate = Color(1, 1, 1, 0.88)
	parent.add_child(button)
	move_buttons.append(button)
	button.button_down.connect(_set_action.bind(action, true))
	button.button_up.connect(_set_action.bind(action, false))

func _add_use_button(parent: Control) -> void:
	var button := Button.new()
	use_button = button
	button.text = "USAR"
	button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	button.position = Vector2(-124, -112)
	button.size = Vector2(100, 70)
	parent.add_child(button)
	button.pressed.connect(_interact)

func _add_sprint_button(parent: Control) -> void:
	sprint_button = Button.new()
	sprint_button.text = "CORRER"
	sprint_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	sprint_button.size = Vector2(112, 58)
	sprint_button.custom_minimum_size = sprint_button.size
	parent.add_child(sprint_button)
	sprint_button.button_down.connect(_set_sprint.bind(true))
	sprint_button.button_up.connect(_set_sprint.bind(false))

func _add_attack_button(parent: Control) -> void:
	attack_button = Button.new()
	attack_button.text = "ATACAR"
	attack_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	attack_button.position = Vector2(-124.0, -190.0)
	attack_button.size = Vector2(100.0, 64.0)
	attack_button.custom_minimum_size = attack_button.size
	parent.add_child(attack_button)
	attack_button.pressed.connect(_attack)

func _set_action(action: String, pressed: bool) -> void:
	player.call("set_mobile_action", action, pressed)

func _set_sprint(pressed: bool) -> void:
	player.call("set_sprint", pressed)

func _layout_mobile_ui() -> void:
	if not is_instance_valid(mobile_ui):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var ui_scale := clampf(minf(viewport_size.x / 1280.0, viewport_size.y / 720.0), 0.72, 1.35)
	status_label.position = Vector2(18.0, 12.0) * ui_scale
	status_label.add_theme_font_size_override("font_size", roundi(20.0 * ui_scale))
	var stat_index := 0
	for key in ["health", "hunger", "thirst", "stamina"]:
		var row_y := (43.0 + float(stat_index) * 24.0) * ui_scale
		var row_label := survival_labels.get(key) as Label
		var bar := survival_bars.get(key) as ProgressBar
		var number_label := survival_values.get(key) as Label
		if is_instance_valid(row_label):
			row_label.position = Vector2(18.0, row_y)
			row_label.size = Vector2(82.0, 22.0) * ui_scale
			row_label.add_theme_font_size_override("font_size", roundi(15.0 * ui_scale))
		if is_instance_valid(bar):
			bar.position = Vector2(108.0, row_y + 2.0 * ui_scale)
			bar.size = Vector2(138.0, 15.0) * ui_scale
			bar.custom_minimum_size = bar.size
		if is_instance_valid(number_label):
			number_label.position = Vector2(252.0, row_y - 1.0 * ui_scale)
			number_label.size = Vector2(34.0, 22.0) * ui_scale
			number_label.add_theme_font_size_override("font_size", roundi(15.0 * ui_scale))
		stat_index += 1
	prompt_label.position = Vector2(18.0, 148.0) * ui_scale
	prompt_label.add_theme_font_size_override("font_size", roundi(18.0 * ui_scale))
	feedback_label.position = Vector2(viewport_size.x * 0.25, 18.0 * ui_scale)
	feedback_label.size = Vector2(viewport_size.x * 0.5, 54.0 * ui_scale)
	feedback_label.add_theme_font_size_override("font_size", roundi(17.0 * ui_scale))
	var button_size := Vector2(70.0, 64.0) * ui_scale
	var offsets: Array[Vector2] = [
		Vector2(98.0, -184.0),
		Vector2(98.0, -82.0),
		Vector2(18.0, -133.0),
		Vector2(178.0, -133.0)
	]
	for i in range(mini(move_buttons.size(), offsets.size())):
		var button := move_buttons[i]
		button.position = offsets[i] * ui_scale
		button.size = button_size
		button.custom_minimum_size = button_size
		button.add_theme_font_size_override("font_size", roundi(26.0 * ui_scale))
	if is_instance_valid(use_button):
		use_button.position = Vector2(-124.0, -112.0) * ui_scale
		use_button.size = Vector2(100.0, 70.0) * ui_scale
		use_button.custom_minimum_size = use_button.size
		use_button.add_theme_font_size_override("font_size", roundi(20.0 * ui_scale))
	if is_instance_valid(sprint_button):
		sprint_button.position = Vector2(-250.0, -92.0) * ui_scale
		sprint_button.size = Vector2(112.0, 58.0) * ui_scale
		sprint_button.custom_minimum_size = sprint_button.size
		sprint_button.add_theme_font_size_override("font_size", roundi(17.0 * ui_scale))
	if is_instance_valid(attack_button):
		attack_button.position = Vector2(-124.0, -190.0) * ui_scale
		attack_button.size = Vector2(100.0, 64.0) * ui_scale
		attack_button.custom_minimum_size = attack_button.size
		attack_button.add_theme_font_size_override("font_size", roundi(17.0 * ui_scale))
