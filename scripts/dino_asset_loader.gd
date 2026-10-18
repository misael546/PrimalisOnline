class_name PrimalisDinoAssetLoader
extends RefCounted

## Loads licensed external GLBs and normalizes them without overwriting the imported root transform.
## Keeping the original GLB under a separate scale/position wrapper avoids huge-model regressions.

## Keep artists' original albedo textures/colors while making unlit baked-color assets react
## to the scene's real lighting. A high roughness avoids the glossy, toy-like finish.
static func naturalize_materials(root: Node) -> int:
	if not is_instance_valid(root):
		return 0
	var changed_count := 0
	var nodes: Array[Node] = [root]
	while not nodes.is_empty():
		var current: Node = nodes.pop_back()
		if current is MeshInstance3D:
			var mesh_instance := current as MeshInstance3D
			if mesh_instance.mesh != null:
				for surface_index in range(mesh_instance.mesh.get_surface_count()):
					# Imported GLBs may contain empty slots. Read the source surface material
					# directly to avoid renderer-side active/override lookups on null slots.
					var source_material: Material = mesh_instance.mesh.surface_get_material(surface_index)
					if source_material == null:
						# Some GLB meshes ship empty material slots. Keep the mesh renderable
						# with a neutral, non-metallic fallback instead of passing null onward.
						var fallback := StandardMaterial3D.new()
						fallback.albedo_color = Color.WHITE
						fallback.vertex_color_use_as_albedo = true
						fallback.roughness = 0.9
						fallback.metallic = 0.0
						mesh_instance.set_surface_override_material(surface_index, fallback)
						changed_count += 1
						continue
					if source_material is StandardMaterial3D:
						var material := (source_material as StandardMaterial3D).duplicate() as StandardMaterial3D
						if material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
							material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
						material.roughness = maxf(material.roughness, 0.82)
						material.metallic = 0.0
						material.metallic_specular = minf(material.metallic_specular, 0.28)
						mesh_instance.set_surface_override_material(surface_index, material)
						changed_count += 1
		for child in current.get_children():
			nodes.append(child)
	return changed_count


static func attach_model(host: Node3D, resource_path: String, target_height: float, yaw: float = PI, floor_offset: float = -0.62) -> Dictionary:
	if not ResourceLoader.exists(resource_path):
		push_error("Required external dinosaur model is missing: %s" % resource_path)
		return {}
	var packed_scene := load(resource_path) as PackedScene
	if packed_scene == null:
		push_error("Could not load external dinosaur model: %s" % resource_path)
		return {}
	var model_node := packed_scene.instantiate()
	if not model_node is Node3D:
		model_node.queue_free()
		push_error("External dinosaur root is not Node3D: %s" % resource_path)
		return {}
	var model := model_node as Node3D
	model.name = "ImportedDinosaur"
	naturalize_materials(model)
	var normalizer := Node3D.new()
	normalizer.name = "NormalizedModelRoot"
	host.add_child(normalizer)
	normalizer.add_child(model)

	# Measure the model with its original imported scale/transform, then scale a parent wrapper.
	var bounds_state: Dictionary = {"has_bounds": false, "bounds": AABB()}
	_collect_bounds(model, Transform3D.IDENTITY, bounds_state)
	if not bool(bounds_state.get("has_bounds", false)):
		normalizer.queue_free()
		push_error("External dinosaur contains no measurable mesh: %s" % resource_path)
		return {}
	var model_bounds: AABB = bounds_state.get("bounds", AABB())
	var factor := target_height / maxf(model_bounds.size.y, 0.05)
	var center := model_bounds.position + model_bounds.size * 0.5
	normalizer.rotation.y = yaw
	normalizer.scale = Vector3.ONE * factor
	# Center X/Z and place the mesh's lowest point at the requested foot offset.
	normalizer.position = -(normalizer.basis * Vector3(center.x, model_bounds.position.y, center.z)) + Vector3(0.0, floor_offset, 0.0)
	print("DINO SCALE AUDIT [%s]: source height %.3f, target %.3f, wrapper scale %.6f" % [resource_path, model_bounds.size.y, target_height, factor])

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
		"normalization_root": normalizer,
		"source_bounds_height": model_bounds.size.y,
		"target_height": target_height,
		"normalization_scale": factor,
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
	if node is Skeleton3D:
		# A skinned GLB's undeformed mesh AABB can be tiny even when the rest-pose
		# skeleton spans a full dinosaur. Include bone origins and tips before normalizing.
		var skeleton := node as Skeleton3D
		for bone_index in range(skeleton.get_bone_count()):
			var bone_rest: Transform3D = skeleton.get_bone_global_rest(bone_index)
			var bone_point := current_transform * bone_rest.origin
			if bool(state.get("has_bounds", false)):
				var accumulated: AABB = state.get("bounds", AABB())
				state["bounds"] = accumulated.expand(bone_point)
			else:
				state["bounds"] = AABB(bone_point, Vector3.ZERO)
				state["has_bounds"] = true
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
