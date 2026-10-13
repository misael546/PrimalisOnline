extends SceneTree

func _initialize() -> void:
	call_deferred("_run_asset_audit")

func _run_asset_audit() -> void:
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	if main_scene == null:
		push_error("ASSET AUDIT: main scene did not load.")
		quit(1)
		return

	var main_node := main_scene.instantiate()
	root.add_child(main_node)
	await process_frame
	await process_frame
	var world_environment := main_node.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if not is_instance_valid(world_environment) or world_environment.environment == null:
		push_error("ASSET AUDIT: WorldEnvironment or Environment resource is missing.")
		quit(1)
		return
	if not world_environment.environment.fog_enabled or world_environment.environment.tonemap_mode != Environment.TONE_MAPPER_ACES:
		push_error("ASSET AUDIT: natural lighting, filmic tone mapping, or distance fog is not configured.")
		quit(1)
		return
	if world_environment.environment.background_mode != Environment.BG_SKY or world_environment.environment.sky == null:
		push_error("ASSET AUDIT: external HDRI sky is not configured.")
		quit(1)
		return
	print("ASSET AUDIT: HDRI sky, filmic lighting and distance fog are configured.")
	var server_join_button := main_node.get("server_join_button") as Button
	if not is_instance_valid(server_join_button):
		push_error("ASSET AUDIT: the single local server entry is missing.")
		quit(1)
		return
	if bool(main_node.get("local_world_started")):
		push_error("ASSET AUDIT: local game should start only after pressing server entry.")
		quit(1)
		return
	main_node.call("_enter_local_world")
	await process_frame

	var player := main_node.get_node_or_null("Player") as CharacterBody3D
	if not is_instance_valid(player):
		push_error("ASSET AUDIT: Player node is missing.")
		quit(1)
		return

	var attack_button := main_node.get("attack_button") as Button
	var use_button := main_node.get("use_button") as Button
	var sprint_button := main_node.get("sprint_button") as Button
	if not is_instance_valid(attack_button) or not is_instance_valid(use_button) or not is_instance_valid(sprint_button):
		push_error("ASSET AUDIT: one or more touch combat/survival controls are missing.")
		quit(1)
		return
	print("ASSET AUDIT: touch attack, use and sprint controls are present.")

	var start_position: Vector3 = player.global_position
	player.call("set_mobile_action", "move_forward", true)
	for frame in range(30):
		await physics_frame
	player.call("set_mobile_action", "move_forward", false)
	var moved_distance := Vector2(
		player.global_position.x - start_position.x,
		player.global_position.z - start_position.z
	).length()
	if moved_distance < 0.25:
		push_error("ASSET AUDIT: mobile forward input did not move the player; distance %.3f." % moved_distance)
		quit(1)
		return
	print("ASSET AUDIT: mobile movement action passed (%.2f m)." % moved_distance)

	if not ResourceLoader.exists("res://assets/dinos/Trex.glb") or not bool(player.get("imported_model_active")):
		push_error("ASSET AUDIT: the required licensed T-Rex GLB is missing or not attached.")
		quit(1)
		return
	var player_info: Dictionary = player.get("imported_model_info")
	if not _has_usable_animation(player_info):
		push_error("ASSET AUDIT: T-Rex GLB loaded without a usable idle/walk animation. Clips: %s" % str(player_info.get("animation_clips", {})))
		quit(1)
		return
	var player_scale_factor := float(player_info.get("normalization_scale", 0.0))
	if player_scale_factor <= 0.0 or player_scale_factor > 8.0:
		push_error("ASSET AUDIT: T-Rex normalization factor is implausible (%.3f); skinned rest-pose bounds may be missing." % player_scale_factor)
		quit(1)
		return
	var player_visual_root := player_info.get("normalization_root") as Node3D
	var skin_material := _find_first_base_material(player_visual_root)
	if not is_instance_valid(skin_material):
		push_error("ASSET AUDIT: T-Rex has no accessible source material to light correctly.")
		quit(1)
		return
	if skin_material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED or skin_material.roughness < 0.78 or skin_material.metallic > 0.01:
		push_error("ASSET AUDIT: T-Rex source material is still unlit or too glossy (roughness %.2f)." % skin_material.roughness)
		quit(1)
		return
	var player_visual_height := _measure_visual_height(player_visual_root)
	if player_visual_height < 1.4 or player_visual_height > 2.8:
		push_error("ASSET AUDIT: T-Rex visual height is outside its safe normalized range (%.3f m)." % player_visual_height)
		quit(1)
		return
	var player_camera := player.get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if not is_instance_valid(player_camera) or player_camera.position.z < 15.0:
		push_error("ASSET AUDIT: third-person camera is too close to frame the full dinosaur.")
		quit(1)
		return
	print("ASSET AUDIT: CC0 T-Rex loaded at %.2f m with a pulled-back third-person camera." % player_visual_height)

	var ground_mesh := main_node.get_node_or_null("Ground/Mesh") as MeshInstance3D
	if ground_mesh == null or not (ground_mesh.mesh is ArrayMesh):
		push_error("ASSET AUDIT: generated terrain mesh is missing.")
		quit(1)
		return
	var terrain_bounds := ground_mesh.mesh.get_aabb()
	if terrain_bounds.size.x < 4500.0 or terrain_bounds.size.z < 4500.0 or terrain_bounds.size.y < 8.0:
		push_error("ASSET AUDIT: terrain must span about 4.6 km and include real height variation (bounds %s)." % str(terrain_bounds.size))
		quit(1)
		return
	var terrain_collision := main_node.get_node_or_null("Ground/TerrainCollision") as CollisionShape3D
	if terrain_collision == null or terrain_collision.shape == null:
		push_error("ASSET AUDIT: generated landscape collision is missing.")
		quit(1)
		return
	var minimap := main_node.get("minimap") as Control
	if not is_instance_valid(minimap) or float(minimap.get("world_half_size")) < 2200.0:
		push_error("ASSET AUDIT: global map scale is not reflected in the minimap.")
		quit(1)
		return
	var river_paths: Array = main_node.get("river_paths")
	if river_paths.size() < 3 or main_node.get_node_or_null("MainRiver") == null or main_node.get_node_or_null("NorthernTributary") == null or main_node.get_node_or_null("SouthernTributary") == null:
		push_error("ASSET AUDIT: the three river channels are missing.")
		quit(1)
		return
	var chunks: Dictionary = main_node.get("loaded_world_chunks")
	if chunks.size() < 5:
		push_error("ASSET AUDIT: streamed chunks were not loaded around player.")
		quit(1)
		return
	var terrain_arrays: Array = ground_mesh.mesh.surface_get_arrays(0)
	var terrain_vertices: PackedVector3Array = terrain_arrays[Mesh.ARRAY_VERTEX]
	if terrain_vertices.size() < 65000:
		push_error("ASSET AUDIT: terrain vertex density is too low for the smoothed landscape (%d)." % terrain_vertices.size())
		quit(1)
		return
	print("ASSET AUDIT: smoothed 4.6 km terrain (%d vertices), three rivers and streaming chunks passed." % terrain_vertices.size())

	# Regression: a player that slips below the collision surface must recover on the terrain.
	var fall_probe := Vector2(180.0, -140.0)
	var sampled_ground := float(main_node.call("_terrain_height_at", fall_probe))
	player.global_position = Vector3(fall_probe.x, sampled_ground - 30.0, fall_probe.y)
	player.velocity = Vector3.ZERO
	await physics_frame
	sampled_ground = float(main_node.call("_terrain_height_at", fall_probe))
	if player.global_position.y < sampled_ground - 1.5:
		push_error("ASSET AUDIT: player failed to recover after a terrain fall.")
		quit(1)
		return
	print("ASSET AUDIT: player fall recovery passed.")

	# Water vertices should follow the generated terrain height instead of a fixed global Y.
	for river_name in ["MainRiver", "NorthernTributary", "SouthernTributary"]:
		var river_instance := main_node.get_node_or_null(river_name) as MeshInstance3D
		if not is_instance_valid(river_instance) or not (river_instance.mesh is ArrayMesh):
			push_error("ASSET AUDIT: river ribbon missing: %s." % river_name)
			quit(1)
			return
		var river_arrays: Array = river_instance.mesh.surface_get_arrays(0)
		var river_vertices: PackedVector3Array = river_arrays[Mesh.ARRAY_VERTEX]
		if river_vertices.size() < 8:
			push_error("ASSET AUDIT: river has too few vertices: %s." % river_name)
			quit(1)
			return
		for vertex_index in range(mini(8, river_vertices.size())):
			var river_vertex: Vector3 = river_vertices[vertex_index]
			var local_height := float(main_node.call("_terrain_height_at", Vector2(river_vertex.x, river_vertex.z)))
			if absf(river_vertex.y - (local_height + 0.042)) > 0.03:
				push_error("ASSET AUDIT: river %s does not follow local terrain height." % river_name)
				quit(1)
				return
	print("ASSET AUDIT: all three river surfaces follow the terrain height.")
	var terrain_material := ground_mesh.material_override as StandardMaterial3D if is_instance_valid(ground_mesh) else null
	if terrain_material == null or terrain_material.albedo_texture == null or terrain_material.normal_texture == null or terrain_material.roughness_texture == null:
		push_error("ASSET AUDIT: external Poly Haven PBR terrain material is not fully loaded.")
		quit(1)
		return
	if not ResourceLoader.exists("res://assets/sky/kloppenheim_06_puresky_1k.hdr"):
		push_error("ASSET AUDIT: CC0 Poly Haven sky HDRI is missing.")
		quit(1)
		return

	var all_nodes: Array[Node] = []
	_collect_all_nodes(main_node, all_nodes)
	var wild_count := 0
	var imported_wild_count := 0
	for child in all_nodes:
		if child is CharacterBody3D and String(child.name).begins_with("WildDinosaur_"):
			wild_count += 1
			if not bool(child.get("imported_model_active")):
				push_error("ASSET AUDIT: expected imported CC0 herbivore model missing.")
				quit(1)
				return
			var wild_info: Dictionary = child.get("imported_model_info")
			if not _has_usable_animation(wild_info):
				push_error("ASSET AUDIT: imported herbivore animation missing. Clips: %s" % str(wild_info.get("animation_clips", {})))
				quit(1)
				return
			var wild_scale_factor := float(wild_info.get("normalization_scale", 0.0))
			if wild_scale_factor <= 0.0 or wild_scale_factor > 8.0:
				push_error("ASSET AUDIT: herbivore normalization factor is implausible (%.3f): %s" % [wild_scale_factor, String(child.name)])
				quit(1)
				return
			var wild_visual_root := wild_info.get("normalization_root") as Node3D
			var wild_visual_height := _measure_visual_height(wild_visual_root)
			if wild_visual_height < 0.8 or wild_visual_height > 2.1:
				push_error("ASSET AUDIT: unsafe herbivore height %.3f m: %s" % [wild_visual_height, String(child.name)])
				quit(1)
				return
			imported_wild_count += 1
	if wild_count < 5 or imported_wild_count != wild_count:
		push_error("ASSET AUDIT: expected 5 animated external herbivores, found %d (%d imported)." % [wild_count, imported_wild_count])
		quit(1)
		return

	# Regression: wildlife placed below the terrain must be snapped back onto land.
	var fall_animal: CharacterBody3D
	for child in all_nodes:
		if child is CharacterBody3D and String(child.name).begins_with("WildDinosaur_"):
			fall_animal = child as CharacterBody3D
			break
	if not is_instance_valid(fall_animal):
		push_error("ASSET AUDIT: no herbivore is available for fall recovery test.")
		quit(1)
		return
	var animal_probe := Vector2(fall_animal.global_position.x, fall_animal.global_position.z)
	var animal_ground := float(main_node.call("_terrain_height_at", animal_probe))
	fall_animal.global_position.y = animal_ground - 30.0
	fall_animal.velocity = Vector3.ZERO
	await physics_frame
	animal_ground = float(main_node.call("_terrain_height_at", Vector2(fall_animal.global_position.x, fall_animal.global_position.z)))
	if fall_animal.global_position.y < animal_ground - 1.5:
		push_error("ASSET AUDIT: wildlife failed to recover after a terrain fall.")
		quit(1)
		return
	print("ASSET AUDIT: wildlife fall recovery passed.")

	var tree_count := 0
	var rock_count := 0
	var bush_count := 0
	var grass_count := 0
	var mountain_count := 0
	for child in all_nodes:
		if String(child.name).begins_with("ExternalTree_"):
			tree_count += 1
		elif String(child.name).begins_with("ExternalRock_"):
			rock_count += 1
		elif String(child.name).begins_with("ExternalBush_"):
			bush_count += 1
		elif String(child.name).begins_with("ExternalGrass_"):
			grass_count += 1
		elif String(child.name).begins_with("BackgroundMountain_"):
			mountain_count += 1
	if tree_count < 50 or rock_count < 15 or bush_count < 20 or grass_count < 30 or mountain_count < 8:
		push_error("ASSET AUDIT: the CC0 environment population is incomplete (trees %d, rocks %d, bushes %d, grass %d, mountains %d)." % [tree_count, rock_count, bush_count, grass_count, mountain_count])
		quit(1)
		return
	print("ASSET AUDIT: external environment loaded (trees %d, rocks %d, bushes %d, grass %d, mountain backdrop %d)." % [tree_count, rock_count, bush_count, grass_count, mountain_count])

	# Verify hunting loop: three bites kill, corpse becomes edible meat, then revives.
	var prey: Node3D
	for child in main_node.get_children():
		if child is CharacterBody3D and String(child.name).begins_with("WildDinosaur_"):
			prey = child as Node3D
			break
	if not is_instance_valid(prey):
		push_error("ASSET AUDIT: could not find a herbivore for combat test.")
		quit(1)
		return
	# Stop residual movement so the direction and line-of-sight checks are deterministic.
	player.velocity = Vector3.ZERO
	prey.set_physics_process(false)

	# The bite must not hit a dinosaur standing directly behind the player.
	prey.global_position = player.global_position + Vector3(0.0, 0.0, 1.35)
	main_node.set("attack_cooldown", 0.0)
	main_node.call("_attack")
	if absf(float(prey.get("health")) - 100.0) > 0.01:
		push_error("ASSET AUDIT: the bite incorrectly hit a herbivore behind the player.")
		quit(1)
		return
	print("ASSET AUDIT: attacks do not hit prey behind the player.")

	# An obstruction between the player and prey must prevent a bite from passing through.
	prey.global_position = player.global_position + Vector3(0.0, 0.0, -1.35)
	var test_wall := StaticBody3D.new()
	test_wall.name = "BiteLineOfSightTestWall"
	test_wall.position = player.global_position + Vector3(0.0, 0.8, -0.68)
	var wall_collision := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(1.0, 2.0, 0.22)
	wall_collision.shape = wall_box
	test_wall.add_child(wall_collision)
	main_node.add_child(test_wall)
	await physics_frame
	main_node.set("attack_cooldown", 0.0)
	main_node.call("_attack")
	if absf(float(prey.get("health")) - 100.0) > 0.01:
		push_error("ASSET AUDIT: the bite passed through a blocking obstacle.")
		quit(1)
		return
	main_node.remove_child(test_wall)
	test_wall.queue_free()
	await physics_frame
	print("ASSET AUDIT: bites are blocked by obstacles.")

	# Exercise the same attack entry point used by the screen button; keep prey in front.
	player.velocity = Vector3.ZERO
	prey.global_position = player.global_position + Vector3(0.0, 0.0, -1.35)
	for hit in range(3):
		main_node.set("attack_cooldown", 0.0)
		main_node.call("_attack")
	if float(player.get("attack_animation_remaining")) <= 0.0:
		push_error("ASSET AUDIT: player attack input did not trigger the bite animation.")
		quit(1)
		return
	if not bool(prey.get("is_dead")) or not bool(prey.get_meta("available", false)) or String(prey.get_meta("kind", "")) != "meat":
		push_error("ASSET AUDIT: attack entry point did not create an edible meat pickup after three bites.")
		quit(1)
		return

	# Verify that meat is a usable pickup and restores hunger/health.
	player.set("hunger", 20.0)
	player.set("health", 70.0)
	main_node.call("_update_nearby_item")
	if main_node.get("nearby_item") != prey:
		push_error("ASSET AUDIT: nearby meat was not selected for interaction.")
		quit(1)
		return
	main_node.call("_interact")
	if absf(float(player.get("hunger")) - 68.0) > 0.01 or absf(float(player.get("health")) - 78.0) > 0.01:
		push_error("ASSET AUDIT: eating meat did not restore the expected hunger and health.")
		quit(1)
		return
	if prey.visible or bool(prey.get_meta("available", true)):
		push_error("ASSET AUDIT: meat pickup did not disappear after being eaten.")
		quit(1)
		return
	print("ASSET AUDIT: eating a meat pickup restores hunger/health.")

	# Verify plant interaction uses the nearest available plant and restores hunger.
	var plant_point := Vector3(-8.0, 0.0, 4.0)
	var food_plant: Node3D
	for item in main_node.get_children():
		if item.has_meta("kind") and String(item.get_meta("kind")) == "food":
			var item_offset := Vector2(item.global_position.x - plant_point.x, item.global_position.z - plant_point.z)
			if item_offset.length() < 0.1:
				food_plant = item as Node3D
				break
	if not is_instance_valid(food_plant):
		push_error("ASSET AUDIT: initial edible plant could not be found.")
		quit(1)
		return
	player.global_position = Vector3(-8.0, 0.72, 4.0)
	player.velocity = Vector3.ZERO
	player.set("hunger", 5.0)
	main_node.call("_update_nearby_item")
	if main_node.get("nearby_item") != food_plant:
		push_error("ASSET AUDIT: nearby plant was not selected for interaction.")
		quit(1)
		return
	main_node.call("_interact")
	if absf(float(player.get("hunger")) - 35.0) > 0.01 or food_plant.visible or bool(food_plant.get_meta("available", true)):
		push_error("ASSET AUDIT: plant interaction failed or did not restore hunger.")
		quit(1)
		return
	print("ASSET AUDIT: eating plants restores hunger and consumes the pickup.")

	# Verify drinking at the pond restores thirst.
	player.global_position = Vector3(15.0, 0.72, 15.0)
	player.set("thirst", 10.0)
	player.velocity = Vector3.ZERO
	main_node.call("_update_nearby_item")
	var selected_water := main_node.get("nearby_item") as Node3D
	if not is_instance_valid(selected_water) or String(selected_water.get_meta("kind", "")) != "water":
		push_error("ASSET AUDIT: the pond did not become the nearby water source.")
		quit(1)
		return
	main_node.call("_interact")
	if absf(float(player.get("thirst")) - 48.0) > 0.01:
		push_error("ASSET AUDIT: drinking water did not restore thirst.")
		quit(1)
		return
	print("ASSET AUDIT: pond interaction restores thirst.")

	# Advance the respawn timers deterministically instead of waiting a full minute in CI.
	main_node.call("_update_food_respawns", 61.0)
	if bool(prey.get("is_dead")) or float(prey.get("health")) < 99.9 or prey.has_meta("kind") or not prey.visible:
		push_error("ASSET AUDIT: consumed meat did not respawn as a living herbivore.")
		quit(1)
		return
	if not food_plant.visible or not bool(food_plant.get_meta("available", false)):
		push_error("ASSET AUDIT: consumed plant did not respawn after its timer.")
		quit(1)
		return
	print("ASSET AUDIT: meat and plant respawn timers passed.")
	print("ASSET AUDIT: all required survival, combat and resource checks passed.")
	quit(0)

func _collect_all_nodes(node: Node, output: Array[Node]) -> void:
	for child in node.get_children():
		output.append(child)
		_collect_all_nodes(child, output)



func _find_first_base_material(root_node: Node) -> BaseMaterial3D:
	if not is_instance_valid(root_node):
		return null
	var nodes: Array[Node] = [root_node]
	while not nodes.is_empty():
		var current: Node = nodes.pop_back()
		if current is MeshInstance3D:
			var mesh_instance := current as MeshInstance3D
			if mesh_instance.mesh != null:
				for surface_index in range(mesh_instance.mesh.get_surface_count()):
					var material: Material = mesh_instance.get_surface_override_material(surface_index)
					if material == null:
						material = mesh_instance.mesh.surface_get_material(surface_index)
					if material is BaseMaterial3D:
						return material as BaseMaterial3D
		for child in current.get_children():
			nodes.append(child)
	return null


func _measure_visual_height(root_node: Node3D) -> float:
	if not is_instance_valid(root_node):
		return 0.0
	var state: Dictionary = {"has_bounds": false, "bounds": AABB()}
	_collect_global_mesh_bounds(root_node, state)
	if not bool(state.get("has_bounds", false)):
		return 0.0
	var bounds: AABB = state.get("bounds", AABB())
	return bounds.size.y


func _collect_global_mesh_bounds(node: Node, state: Dictionary) -> void:
	if node is Skeleton3D:
		var skeleton := node as Skeleton3D
		for bone_index in range(skeleton.get_bone_count()):
			var bone_rest: Transform3D = skeleton.get_bone_global_rest(bone_index)
			var bone_point := skeleton.global_transform * bone_rest.origin
			if bool(state.get("has_bounds", false)):
				var current: AABB = state.get("bounds", AABB())
				state["bounds"] = current.expand(bone_point)
			else:
				state["bounds"] = AABB(bone_point, Vector3.ZERO)
				state["has_bounds"] = true
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			var bounds: AABB = mesh_instance.get_aabb()
			for ix in range(2):
				for iy in range(2):
					for iz in range(2):
						var local_point := bounds.position + Vector3(bounds.size.x * float(ix), bounds.size.y * float(iy), bounds.size.z * float(iz))
						var world_point := mesh_instance.global_transform * local_point
						if bool(state.get("has_bounds", false)):
							var current: AABB = state.get("bounds", AABB())
							state["bounds"] = current.expand(world_point)
						else:
							state["bounds"] = AABB(world_point, Vector3.ZERO)
							state["has_bounds"] = true
	for child in node.get_children():
		_collect_global_mesh_bounds(child, state)


func _has_usable_animation(info: Dictionary) -> bool:
	if StringName(info.get("source_animation", &"")) != &"":
		return true
	var clips: Dictionary = info.get("animation_clips", {})
	return clips.has("idle") and clips.has("walk")
