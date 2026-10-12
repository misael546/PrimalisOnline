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

	var imported_player_required := ResourceLoader.exists("res://assets/dinos/Trex.glb")
	if imported_player_required:
		if not bool(player.get("imported_model_active")):
			push_error("ASSET AUDIT: T-Rex GLB exists but was not attached to the player.")
			quit(1)
			return
		var player_info: Dictionary = player.get("imported_model_info")
		if StringName(player_info.get("source_animation", &"")) == &"":
			push_error("ASSET AUDIT: T-Rex GLB loaded without an animation timeline.")
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
				if StringName(wild_info.get("source_animation", &"")) == &"":
					push_error("ASSET AUDIT: imported herbivore lacks an animation timeline.")
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
	print("ASSET AUDIT: all required node and resource checks passed.")
	quit(0)
