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

	var player := main_node.get_node_or_null("Player")
	if player == null:
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

	var imported_player_required := ResourceLoader.exists("res://assets/dinos/Trex.glb")
	if imported_player_required:
		if not bool(player.get("imported_model_active")):
			push_error("ASSET AUDIT: T-Rex GLB exists but was not attached to the player.")
			quit(1)
			return
		var player_info: Dictionary = player.get("imported_model_info")
		if not _has_usable_animation(player_info):
			push_error("ASSET AUDIT: T-Rex GLB loaded without a usable idle/walk animation. Clips: %s" % str(player_info.get("animation_clips", {})))
			quit(1)
			return
		print("ASSET AUDIT: T-Rex model and animation timeline loaded.")
	else:
		print("ASSET AUDIT: no T-Rex GLB; procedural player fallback is active.")

	var wild_count := 0
	var imported_wild_count := 0
	for child in main_node.get_children():
		if child is CharacterBody3D and String(child.name).begins_with("WildDinosaur_"):
			wild_count += 1
			if ResourceLoader.exists("res://assets/dinos/Stegosaurus.glb") and ResourceLoader.exists("res://assets/dinos/Triceratops.glb"):
				if not bool(child.get("imported_model_active")):
					push_error("ASSET AUDIT: expected an imported herbivore model but it was not attached.")
					quit(1)
					return
				var wild_info: Dictionary = child.get("imported_model_info")
				if not _has_usable_animation(wild_info):
					push_error("ASSET AUDIT: imported herbivore lacks usable idle/walk animation. Clips: %s" % str(wild_info.get("animation_clips", {})))
					quit(1)
					return
				imported_wild_count += 1
	if wild_count != 3:
		push_error("ASSET AUDIT: expected 3 wild dinosaurs, found %d." % wild_count)
		quit(1)
		return
	if imported_wild_count == 3:
		print("ASSET AUDIT: 3 herbivores attached with animation timelines.")
	else:
		print("ASSET AUDIT: procedural herbivore fallback is available.")

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
	player.global_position = Vector3(-8.0, 1.0, 4.0)
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
	player.global_position = Vector3(15.0, 1.0, 15.0)
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

func _has_usable_animation(info: Dictionary) -> bool:
	if StringName(info.get("source_animation", &"")) != &"":
		return true
	var clips: Dictionary = info.get("animation_clips", {})
	return clips.has("idle") and clips.has("walk")
