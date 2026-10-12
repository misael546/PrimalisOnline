class_name PrimalisDinoAssetLoader
extends RefCounted

## Optional external GLB support. If an asset is missing or fails to import, callers keep their procedural fallback.
static func attach_model(host: Node3D, resource_path: String, target_height: float, yaw: float = PI, floor_offset: float = -0.62) -> Dictionary:
	if not ResourceLoader.exists(resource_path):
		return {}
	var packed_scene := load(resource_path) as PackedScene
	if packed_scene == null:
		return {}
	var model_node := packed_scene.instantiate()
	if not model_node is Node3D:
		model_node.queue_free()
		return {}
	var model := model_node as Node3D
	model.name = "ImportedDinosaur"
	host.add_child(model)

	var bounds_state: Dictionary = {"has_bounds": false, "bounds": AABB()}
	_collect_bounds(model, Transform3D.IDENTITY, bounds_state)
	var factor := target_height
	if bool(bounds_state.get("has_bounds", false)):
		var model_bounds: AABB = bounds_state.get("bounds", AABB())
		factor = target_height / maxf(model_bounds.size.y, 0.05)
		var center := model_bounds.position + model_bounds.size * 0.5
		model.position = Vector3(-center.x * factor, floor_offset - model_bounds.position.y * factor, -center.z * factor)
	model.scale = Vector3.ONE * factor
	model.rotation.y = yaw

	var animation_player := _find_animation_player(model)
	var source_animation: StringName = &""
	var longest_duration := 0.0
	var animation_clips: Dictionary = {}
	var longest_animation: StringName = &""
	if is_instance_valid(animation_player):
		for animation_name in animation_player.get_animation_list():
			var animation := animation_player.get_animation(animation_name) as Animation
			if animation == null:
				continue
			if animation.length > longest_duration:
				longest_duration = animation.length
				longest_animation = animation_name
			var lowered_name := String(animation_name).to_lower()
			if lowered_name.contains("idle") and not animation_clips.has("idle"):
				animation_clips["idle"] = animation_name
			elif lowered_name.contains("walk") and not animation_clips.has("walk"):
				animation_clips["walk"] = animation_name
			elif lowered_name.contains("attack") and not animation_clips.has("attack"):
				animation_clips["attack"] = animation_name
			elif lowered_name.contains("dead") and not animation_clips.has("dead"):
				animation_clips["dead"] = animation_name
		# Some importers preserve a single five-second clip; others split it into named actions.
		if longest_duration >= 4.5:
			source_animation = longest_animation
			animation_player.play(source_animation)
			animation_player.speed_scale = 0.0
			animation_player.seek(0.0, true)
		else:
			if not animation_clips.is_empty():
				for clip_key in animation_clips:
					var named_clip := animation_player.get_animation(animation_clips[clip_key]) as Animation
					if named_clip != null:
						named_clip.loop_mode = Animation.LOOP_NONE if clip_key == "dead" else Animation.LOOP_LINEAR
				if animation_clips.has("idle"):
					animation_player.play(animation_clips["idle"])
				elif animation_clips.has("walk"):
					animation_player.play(animation_clips["walk"])
				animation_player.speed_scale = 1.0
			var diagnostic := []
			for animation_name in animation_player.get_animation_list():
				var animation := animation_player.get_animation(animation_name) as Animation
				diagnostic.append("%s (%.3fs)" % [String(animation_name), animation.length if animation != null else 0.0])
			print("DINO GLB animation audit [%s]: %s" % [resource_path, ", ".join(diagnostic)])
	else:
		print("DINO GLB animation audit [%s]: no AnimationPlayer found" % resource_path)

	return {
		"model": model,
		"animation_player": animation_player,
		"source_animation": source_animation,
		"animation_clips": animation_clips,
		"timeline_length": longest_duration
	}

static func set_segment(info: Dictionary, segment: String, elapsed_seconds: float) -> void:
	var animation_player := info.get("animation_player") as AnimationPlayer
	if not is_instance_valid(animation_player):
		return
	var source_animation := StringName(info.get("source_animation", &""))
	if source_animation == &"":
		var clips: Dictionary = info.get("animation_clips", {})
		var named_clip := StringName(clips.get(segment, clips.get("idle", clips.get("walk", &""))))
		if named_clip == &"":
			return
		if animation_player.current_animation != named_clip or not animation_player.is_playing():
			animation_player.play(named_clip)
		animation_player.speed_scale = 1.0
		return

	if animation_player.current_animation != source_animation:
		animation_player.play(source_animation)
	animation_player.speed_scale = 0.0

	var start_time := 0.0
	var segment_duration := 1.25
	match segment:
		"attack":
			start_time = 1.25
		"dead":
			start_time = 2.5
		"walk":
			start_time = 3.75
		_:
			start_time = 0.0
	var sample_time := start_time
	if segment == "dead":
		sample_time += minf(maxf(elapsed_seconds, 0.0), segment_duration - 0.001)
	else:
		sample_time += fposmod(maxf(elapsed_seconds, 0.0), segment_duration)
	animation_player.seek(sample_time, true)

static func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child in root.get_children():
		var found := _find_animation_player(child)
		if is_instance_valid(found):
			return found
	return null

static func _collect_bounds(node: Node, parent_transform: Transform3D, state: Dictionary) -> void:
	var current_transform := parent_transform
	if node is Node3D:
		current_transform = parent_transform * (node as Node3D).transform
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			var mesh_bounds: AABB = mesh_instance.mesh.get_aabb()
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
							var accumulated: AABB = state.get("bounds", AABB())
							state["bounds"] = accumulated.expand(point)
						else:
							state["bounds"] = AABB(point, Vector3.ZERO)
							state["has_bounds"] = true
	for child in node.get_children():
		_collect_bounds(child, current_transform, state)
