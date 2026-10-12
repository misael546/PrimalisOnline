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
	# Exercise the same attack entry point used by the screen button; keep prey in range.
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
	prey.call("revive")
	if bool(prey.get("is_dead")) or float(prey.get("health")) < 99.9 or prey.has_meta("kind"):
		push_error("ASSET AUDIT: dead herbivore did not restore its alive state on respawn.")
		quit(1)
		return
	print("ASSET AUDIT: hunting, edible meat drop and herbivore respawn passed.")
	print("ASSET AUDIT: all required node and resource checks passed.")
	quit(0)

func _has_usable_animation(info: Dictionary) -> bool:
	if StringName(info.get("source_animation", &"")) != &"":
		return true
	var clips: Dictionary = info.get("animation_clips", {})
	return clips.has("idle") and clips.has("walk")
