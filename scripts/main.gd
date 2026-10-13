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
const WORLD_HALF_SIZE: float = 2300.0
const CHUNK_SIZE: float = 220.0
const STREAM_RADIUS: int = 1
const TERRAIN_GRID_CELLS: int = 256
var terrain_noise: FastNoiseLite
var terrain_detail_noise: FastNoiseLite
var river_bank_material: StandardMaterial3D
var river_paths: Array[Array] = []
var interactable_items: Array[Node3D] = []
var loaded_world_chunks: Dictionary = {}
var current_chunk := Vector2i(999999, 999999)
var local_world_started := false
var wildlife_timer := 12.0
var wildlife_next_id := 1
var species_paths: Array[String] = ["res://assets/dinos/Stegosaurus.glb", "res://assets/dinos/Triceratops.glb", "res://assets/dinos/Ankylosaurus.glb", "res://assets/dinos/Pachycephalosaurus.glb", "res://assets/dinos/Oviraptor.glb"]
var river_water_source: Node3D
var minimap: Control
var world_position_label: Label
var menu_overlay: ColorRect
var server_join_button: Button

func _ready() -> void:
	player.set_physics_process(false)
	_apply_ground_material()
	_apply_world_sky()
	_build_world_props()
	_build_mobile_ui()
	_build_main_menu()
	get_viewport().size_changed.connect(_layout_mobile_ui)
	_layout_mobile_ui()

func _process(delta: float) -> void:
	if not local_world_started:
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	wildlife_timer -= delta
	if wildlife_timer <= 0.0:
		wildlife_timer = 12.0
		_maintain_wildlife()
	_stream_world_chunks()
	if is_instance_valid(status_label):
		status_label.text = "PRIMALIS ONLINE  •  LOCAL"
		_update_survival_hud()
	_update_food_respawns(delta)
	_update_nearby_item()
	if is_instance_valid(feedback_label):
		feedback_label.text = str(player.get("status_message"))
	if is_instance_valid(minimap):
		minimap.call("set_world_state", Vector2(player.global_position.x, player.global_position.z), river_paths)
	if is_instance_valid(world_position_label):
		world_position_label.text = "%s  X %d  Z %d" % [_region_name(), roundi(player.global_position.x), roundi(player.global_position.z)]

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
	ground_material.normal_scale = 0.48
	ground_material.roughness = 1.0
	ground_material.roughness_texture = roughness
	# Slightly finer tiling retains scanned ground detail on the very large terrain.
	ground_material.uv1_scale = Vector3(820.0, 820.0, 1.0)
	ground_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ground_mesh.material_override = ground_material
	river_bank_material = ground_material.duplicate() as StandardMaterial3D
	river_bank_material.uv1_scale = Vector3.ONE


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
	_initialize_terrain_noise()
	_build_rivers()
	_build_terrain_surface()
	_add_pond(Vector3(15.0, 0.035, 15.0), Vector2(24.0, 18.0))
	_add_water_marker(Vector3(15.0, 0.0, 15.0))
	_add_food_plant(Vector3(-8.0, _terrain_height_at(Vector2(-8.0, 4.0)), 4.0), "Bush001.glb", 1)
	_add_food_plant(Vector3(34.0, _terrain_height_at(Vector2(34.0, -40.0)), -40.0), "Bush002.glb", 2)
	_add_food_plant(Vector3(-52.0, _terrain_height_at(Vector2(-52.0, -26.0)), -26.0), "Bush001.glb", 3)
	_add_food_plant(Vector3(54.0, _terrain_height_at(Vector2(54.0, 38.0)), 38.0), "Bush002.glb", 4)
	_add_food_plant(Vector3(-22.0, _terrain_height_at(Vector2(-22.0, 63.0)), 63.0), "Bush001.glb", 5)
	_add_food_plant(Vector3(64.0, _terrain_height_at(Vector2(64.0, -59.0)), -59.0), "Bush002.glb", 6)
	var rng := RandomNumberGenerator.new()
	rng.seed = 64281
	for index in range(32):
		var angle := TAU * float(index) / 32.0
		var radius := WORLD_HALF_SIZE + 70.0
		var point := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		point.y = _terrain_height_at(Vector2(point.x, point.z))
		var path := "res://assets/environment/MountainFar00%d.glb" % (index % 3 + 1)
		_add_environment_prop("BackgroundMountain_%02d" % (index + 1), path, point, rng.randf_range(90.0, 150.0), -angle)
	_build_world_boundaries()
	_stream_world_chunks(true)
	_spawn_wild_dinosaurs()


func _initialize_terrain_noise() -> void:
	terrain_noise = FastNoiseLite.new()
	terrain_noise.seed = 726401
	terrain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	terrain_noise.frequency = 0.00095
	terrain_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	terrain_noise.fractal_octaves = 4
	terrain_noise.fractal_lacunarity = 2.0
	terrain_noise.fractal_gain = 0.50
	terrain_detail_noise = FastNoiseLite.new()
	terrain_detail_noise.seed = 413907
	terrain_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	terrain_detail_noise.frequency = 0.0045
	terrain_detail_noise.fractal_octaves = 2


func _build_rivers() -> void:
	river_paths.clear()
	var trunk: Array[Vector2] = []
	for i in range(221):
		var t := float(i) / 220.0
		trunk.append(Vector2(lerpf(-2280.0, 2280.0, t), 570.0 + 330.0 * sin(t * TAU * 1.15) + 100.0 * sin(t * TAU * 3.4)))
	river_paths.append(trunk)
	var north: Array[Vector2] = []
	var nt := 1700.0 / 4560.0
	var nz := 570.0 + 330.0 * sin(nt * TAU * 1.15) + 100.0 * sin(nt * TAU * 3.4)
	for i in range(161):
		var t := float(i) / 160.0
		north.append(Vector2(-880.0 + 374.0 * t + 220.0 * sin(t * PI) + 88.0 * sin(t * TAU * 2.0), lerpf(-2280.0, nz, t)))
	north[north.size() - 1].x = -506.0
	river_paths.append(north)
	var south: Array[Vector2] = []
	var st := 3300.0 / 4560.0
	var sz := 570.0 + 330.0 * sin(st * TAU * 1.15) + 100.0 * sin(st * TAU * 3.4)
	for i in range(161):
		var t := float(i) / 160.0
		south.append(Vector2(1430.0 - 550.0 * t - 242.0 * sin(t * PI) + 99.0 * sin(t * TAU * 2.0), lerpf(2280.0, sz, t)))
	south[south.size() - 1].x = 880.0
	river_paths.append(south)
	var river_labels := ["MainRiver", "NorthernTributary", "SouthernTributary"]
	var river_widths := [18.0, 12.0, 9.0]
	for river_index in range(river_paths.size()):
		_add_river(river_labels[river_index], river_paths[river_index], river_widths[river_index])
	river_water_source = Node3D.new()
	river_water_source.name = "RiverWaterSource"
	river_water_source.set_meta("kind", "water")
	river_water_source.set_meta("available", true)
	river_water_source.set_meta("source_type", "river")
	add_child(river_water_source)
	interactable_items.append(river_water_source)


func _terrain_height_at(point: Vector2) -> float:
	var broad := terrain_noise.get_noise_2d(point.x, point.y) * 22.0
	var detail := terrain_detail_noise.get_noise_2d(point.x, point.y) * 2.2
	var height := broad + detail
	if not river_paths.is_empty():
		var river_distance := float(_river_distance_for_terrain(point).get("distance", WORLD_HALF_SIZE))
		height = lerpf(-2.8, height, smoothstep(0.0, 125.0, river_distance))
	if point.length() < 170.0:
		height = lerpf(0.0, height, smoothstep(105.0, 170.0, point.length()))
	return height


func _river_distance_for_terrain(point: Vector2) -> Dictionary:
	var nearest := point
	var shortest := INF
	for path in river_paths:
		for i in range(0, path.size() - 1, 4):
			var a: Vector2 = path[i]
			var b: Vector2 = path[mini(i + 4, path.size() - 1)]
			var edge := b - a
			var t := 0.0
			if edge.length_squared() > 0.001:
				t = clampf((point - a).dot(edge) / edge.length_squared(), 0.0, 1.0)
			var candidate := a + edge * t
			var distance := point.distance_to(candidate)
			if distance < shortest:
				shortest = distance
				nearest = candidate
	return {"distance": shortest, "point": nearest}


func _build_terrain_surface() -> void:
	var ground_body := get_node_or_null("Ground") as StaticBody3D
	var ground_mesh := get_node_or_null("Ground/Mesh") as MeshInstance3D
	if not is_instance_valid(ground_body) or not is_instance_valid(ground_mesh):
		push_error("Ground body/mesh missing while building landscape.")
		return
	var vertex_count := TERRAIN_GRID_CELLS + 1
	var step_size := (WORLD_HALF_SIZE * 2.0) / float(TERRAIN_GRID_CELLS)
	var heights := PackedFloat32Array()
	heights.resize(vertex_count * vertex_count)
	for z in range(vertex_count):
		for x in range(vertex_count):
			var world_x := -WORLD_HALF_SIZE + float(x) * step_size
			var world_z := -WORLD_HALF_SIZE + float(z) * step_size
			heights[z * vertex_count + x] = _terrain_height_at(Vector2(world_x, world_z))
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for z in range(vertex_count):
		for x in range(vertex_count):
			var index := z * vertex_count + x
			var world_x := -WORLD_HALF_SIZE + float(x) * step_size
			var world_z := -WORLD_HALF_SIZE + float(z) * step_size
			vertices.append(Vector3(world_x, heights[index], world_z))
			uvs.append(Vector2(float(x) / float(TERRAIN_GRID_CELLS), float(z) / float(TERRAIN_GRID_CELLS)))
			var left := heights[z * vertex_count + maxi(x - 1, 0)]
			var right := heights[z * vertex_count + mini(x + 1, vertex_count - 1)]
			var up := heights[maxi(z - 1, 0) * vertex_count + x]
			var down := heights[mini(z + 1, vertex_count - 1) * vertex_count + x]
			var dx_denominator := step_size * (2.0 if x > 0 and x < vertex_count - 1 else 1.0)
			var dz_denominator := step_size * (2.0 if z > 0 and z < vertex_count - 1 else 1.0)
			var slope_x := (right - left) / dx_denominator
			var slope_z := (down - up) / dz_denominator
			normals.append(Vector3(-slope_x, 1.0, -slope_z).normalized())
	for z in range(TERRAIN_GRID_CELLS):
		for x in range(TERRAIN_GRID_CELLS):
			var a := z * vertex_count + x
			var b := a + 1
			var c := a + vertex_count
			var d := c + 1
			indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var terrain_mesh := ArrayMesh.new()
	terrain_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	ground_mesh.mesh = terrain_mesh
	var old_collision := ground_body.get_node_or_null("Collision") as CollisionShape3D
	if is_instance_valid(old_collision):
		ground_body.remove_child(old_collision)
		old_collision.free()
	var terrain_collision := CollisionShape3D.new()
	terrain_collision.name = "TerrainCollision"
	terrain_collision.shape = terrain_mesh.create_trimesh_shape()
	ground_body.add_child(terrain_collision)
	print("WORLD AUDIT: generated 4.6 km terrain mesh with river valleys (%d vertices)." % vertices.size())


func _add_river(label: String, points: Array[Vector2], half_width: float) -> void:
	if is_instance_valid(river_bank_material):
		_river_ribbon(label + "Banks", points, half_width + 10.0, 0.014, river_bank_material, 6.0, true)
	var shader := load("res://materials/water_pond.gdshader") as Shader
	if shader == null:
		push_error("Water shader could not be loaded for " + label)
		return
	var material := ShaderMaterial.new()
	material.shader = shader
	_river_ribbon(label, points, half_width, 0.042, material, 28.0, false)


func _river_ribbon(label: String, points: Array[Vector2], half_width: float, height: float, material: Material, repeat: float, tile_across: bool) -> void:
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var distance := 0.0
	for i in range(points.size()):
		var tangent: Vector2
		if i == 0:
			tangent = (points[1] - points[0]).normalized()
		elif i == points.size() - 1:
			tangent = (points[i] - points[i - 1]).normalized()
		else:
			tangent = (points[i + 1] - points[i - 1]).normalized()
		var side := Vector2(-tangent.y, tangent.x)
		if i > 0:
			distance += points[i].distance_to(points[i - 1])
		var left := points[i] + side * half_width
		var right := points[i] - side * half_width
		# Water and shore ribbons track the generated terrain instead of floating at one Y.
		var left_height := _terrain_height_at(left) + height
		var right_height := _terrain_height_at(right) + height
		vertices.append(Vector3(left.x, left_height, left.y))
		vertices.append(Vector3(right.x, right_height, right.y))
		var u := distance / maxf(repeat, 0.1)
		var v := half_width * 2.0 / maxf(repeat, 0.1) if tile_across else 1.0
		uv.append(Vector2(u, 0.0))
		uv.append(Vector2(u, v))
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		if i < points.size() - 1:
			var base := i * 2
			indices.append_array(PackedInt32Array([base, base + 2, base + 1, base + 1, base + 2, base + 3]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _river_distance(point: Vector2) -> Dictionary:
	var nearest := point
	var shortest := INF
	for path in river_paths:
		for i in range(path.size() - 1):
			var a: Vector2 = path[i]
			var b: Vector2 = path[i + 1]
			var edge := b - a
			var t := 0.0
			if edge.length_squared() > 0.001:
				t = clampf((point - a).dot(edge) / edge.length_squared(), 0.0, 1.0)
			var candidate := a + edge * t
			var d := point.distance_to(candidate)
			if d < shortest:
				shortest = d
				nearest = candidate
	return {"distance": shortest, "point": nearest}


func _near_river(point: Vector2, radius: float) -> bool:
	return float(_river_distance(point).get("distance", INF)) < radius


func _build_world_boundaries() -> void:
	var half := WORLD_HALF_SIZE
	_add_boundary_wall(Vector3(0.0, 3.0, -half), Vector3(half * 2.0, 6.0, 2.0))
	_add_boundary_wall(Vector3(0.0, 3.0, half), Vector3(half * 2.0, 6.0, 2.0))
	_add_boundary_wall(Vector3(-half, 3.0, 0.0), Vector3(2.0, 6.0, half * 2.0))
	_add_boundary_wall(Vector3(half, 3.0, 0.0), Vector3(2.0, 6.0, half * 2.0))


func _stream_world_chunks(force: bool = false) -> void:
	var center := Vector2i(floori(player.global_position.x / CHUNK_SIZE), floori(player.global_position.z / CHUNK_SIZE))
	if not force and center == current_chunk:
		return
	var wanted: Dictionary = {}
	for dx in range(-STREAM_RADIUS, STREAM_RADIUS + 1):
		for dz in range(-STREAM_RADIUS, STREAM_RADIUS + 1):
			var coord := Vector2i(center.x + dx, center.y + dz)
			if absf(float(coord.x) * CHUNK_SIZE) > WORLD_HALF_SIZE + CHUNK_SIZE or absf(float(coord.y) * CHUNK_SIZE) > WORLD_HALF_SIZE + CHUNK_SIZE:
				continue
			var key := "%d,%d" % [coord.x, coord.y]
			wanted[key] = true
			if not loaded_world_chunks.has(key):
				_create_world_chunk(coord, key)
	for key_value in loaded_world_chunks.keys():
		var key := String(key_value)
		if wanted.has(key):
			continue
		var entry: Dictionary = loaded_world_chunks[key]
		var node := entry.get("node") as Node3D
		if is_instance_valid(node):
			var dead_items: Array[Node3D] = []
			for item in interactable_items:
				if is_instance_valid(item) and node.is_ancestor_of(item):
					dead_items.append(item)
			for item in dead_items:
				interactable_items.erase(item)
			node.queue_free()
		loaded_world_chunks.erase(key)
	current_chunk = center


func _create_world_chunk(coord: Vector2i, key: String) -> void:
	var chunk := Node3D.new()
	chunk.name = "WorldChunk_%d_%d" % [coord.x, coord.y]
	add_child(chunk)
	loaded_world_chunks[key] = {"node": chunk, "coordinate": coord}
	var rng := RandomNumberGenerator.new()
	rng.seed = int((coord.x + 1109) * 73856093) ^ int((coord.y + 1301) * 19349663) ^ 64281
	var min_x := maxf(float(coord.x) * CHUNK_SIZE, -WORLD_HALF_SIZE + 14.0)
	var max_x := minf(float(coord.x + 1) * CHUNK_SIZE, WORLD_HALF_SIZE - 14.0)
	var min_z := maxf(float(coord.y) * CHUNK_SIZE, -WORLD_HALF_SIZE + 14.0)
	var max_z := minf(float(coord.y + 1) * CHUNK_SIZE, WORLD_HALF_SIZE - 14.0)
	if min_x >= max_x or min_z >= max_z:
		return
	var occupied: Array[Vector2] = []
	var target_trees := rng.randi_range(24, 32)
	var trees := 0
	for attempt in range(target_trees * 5):
		if trees >= target_trees:
			break
		var p := Vector2(rng.randf_range(min_x, max_x), rng.randf_range(min_z, max_z))
		if p.length() < 36.0 or _near_river(p, 43.0) or _too_close(p, occupied, 6.0):
			continue
		occupied.append(p)
		var asset := "res://assets/environment/TreeHigh00%d.glb" % (trees % 3 + 1)
		_add_tree(Vector3(p.x, _terrain_height_at(p), p.y), asset, rng.randf_range(5.5, 8.5), rng.randf_range(0.0, TAU), trees + 1, chunk)
		trees += 1
	var rocks := 0
	for attempt in range(30):
		if rocks >= 4:
			break
		var p := Vector2(rng.randf_range(min_x, max_x), rng.randf_range(min_z, max_z))
		if p.length() < 32.0 or _near_river(p, 17.0) or _too_close(p, occupied, 3.2):
			continue
		occupied.append(p)
		var asset := "res://assets/environment/Rock00%d.glb" % (rocks % 3 + 1)
		_add_rock(Vector3(p.x, _terrain_height_at(p), p.y), asset, rng.randf_range(0.9, 2.8), rng.randf_range(0.0, TAU), rocks + 1, chunk)
		rocks += 1
	for i in range(12):
		var p := Vector2(rng.randf_range(min_x, max_x), rng.randf_range(min_z, max_z))
		if p.length() < 30.0 or _near_river(p, 12.0):
			continue
		var asset := "res://assets/environment/Bush00%d.glb" % (i % 2 + 1)
		_add_environment_prop("ExternalBush_%03d" % i, asset, Vector3(p.x, _terrain_height_at(p), p.y), rng.randf_range(1.2, 2.1), rng.randf_range(0.0, TAU), chunk)
	for i in range(18):
		var p := Vector2(rng.randf_range(min_x, max_x), rng.randf_range(min_z, max_z))
		if p.length() < 27.0 or _near_river(p, 8.0):
			continue
		var asset := "res://assets/environment/Grass00%d.glb" % (i % 3 + 1)
		_add_environment_prop("ExternalGrass_%03d" % i, asset, Vector3(p.x, _terrain_height_at(p), p.y), rng.randf_range(0.65, 1.2), rng.randf_range(0.0, TAU), chunk)
	for i in range(1):
		var p := Vector2(rng.randf_range(min_x, max_x), rng.randf_range(min_z, max_z))
		if p.length() >= 38.0 and not _near_river(p, 40.0):
			_add_food_plant(Vector3(p.x, _terrain_height_at(p), p.y), "Bush001.glb", 100000 + (coord.x + 6) * 1000 + (coord.y + 6) * 10 + i, chunk)


func _too_close(p: Vector2, points: Array[Vector2], radius: float) -> bool:
	for existing in points:
		if p.distance_squared_to(existing) < radius * radius:
			return true
	return false


func _spawn_wild_dinosaurs() -> void:
	for index in range(10):
		_spawn_wildlife(index, 65.0, 230.0)


func _spawn_wildlife(index: int, minimum: float, maximum: float) -> bool:
	var script := load("res://scripts/wild_dinosaur.gd") as Script
	if script == null or species_paths.is_empty():
		push_error("Wildlife controller/species list missing.")
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = int(index * 15485863 + player.global_position.x * 73856093 + player.global_position.z * 19349663 + 91811)
	var p := Vector2.ZERO
	var found := false
	for attempt in range(100):
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(minimum, maximum)
		p = Vector2(player.global_position.x, player.global_position.z) + Vector2(cos(angle), sin(angle)) * radius
		p.x = clampf(p.x, -WORLD_HALF_SIZE + 22.0, WORLD_HALF_SIZE - 22.0)
		p.y = clampf(p.y, -WORLD_HALF_SIZE + 22.0, WORLD_HALF_SIZE - 22.0)
		if Vector2(player.global_position.x - p.x, player.global_position.z - p.y).length() < minimum * 0.65 or _near_river(p, 39.0):
			continue
		found = true
		break
	if not found:
		return false
	var creature := CharacterBody3D.new()
	creature.set_script(script)
	creature.name = "WildDinosaur_%03d" % wildlife_next_id
	wildlife_next_id += 1
	creature.position = Vector3(p.x, _terrain_height_at(p) + 0.88, p.y)
	var asset: String = species_paths[index % species_paths.size()]
	creature.set("species_asset_path", asset)
	creature.set("species_target_height", 1.35 if asset.ends_with("Oviraptor.glb") else (1.55 if asset.ends_with("Triceratops.glb") else 1.5))
	add_child(creature)
	creature.set_physics_process(local_world_started)
	creature.call("set_target", player)
	interactable_items.append(creature)
	return true


func _maintain_wildlife() -> void:
	var count := 0
	var here := Vector2(player.global_position.x, player.global_position.z)
	for child in get_children():
		if not child is CharacterBody3D or not String(child.name).begins_with("WildDinosaur_"):
			continue
		var animal := child as Node3D
		var d := Vector2(animal.global_position.x, animal.global_position.z).distance_to(here)
		if d > 520.0:
			interactable_items.erase(animal)
			animal.queue_free()
		elif d < 300.0:
			count += 1
	var attempts := 0
	while count < 10 and attempts < 10:
		if not _spawn_wildlife(wildlife_next_id + attempts, 90.0, 235.0):
			break
		count += 1
		attempts += 1




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


func _add_tree(at: Vector3, asset_path: String, target_height: float, yaw: float, index: int, host: Node3D = null) -> void:
	var tree := Node3D.new()
	tree.name = "ExternalTree_%03d" % index
	tree.position = at
	tree.set_meta("scenery", true)
	(host if is_instance_valid(host) else self).add_child(tree)
	if not _add_external_visual(tree, asset_path, target_height, yaw):
		push_error("External tree asset failed: %s" % asset_path)
		return
	var body := StaticBody3D.new()
	body.name = "TreeCollision"
	body.position.y = 1.25
	tree.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.34
	shape.height = 2.5
	collision.shape = shape
	body.add_child(collision)


func _add_rock(at: Vector3, asset_path: String, target_height: float, yaw: float, index: int, host: Node3D = null) -> void:
	var rock := Node3D.new()
	rock.name = "ExternalRock_%03d" % index
	rock.position = at
	rock.set_meta("scenery", true)
	(host if is_instance_valid(host) else self).add_child(rock)
	if not _add_external_visual(rock, asset_path, target_height, yaw):
		push_error("External rock asset failed: %s" % asset_path)
		return
	var body := StaticBody3D.new()
	body.position.y = target_height * 0.23
	rock.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = target_height * 0.32
	collision.shape = shape
	body.add_child(collision)


func _add_environment_prop(instance_name: String, asset_path: String, at: Vector3, target_height: float, yaw: float, host: Node3D = null) -> void:
	var prop := Node3D.new()
	prop.name = instance_name
	prop.position = at
	prop.set_meta("scenery", true)
	(host if is_instance_valid(host) else self).add_child(prop)
	if not _add_external_visual(prop, asset_path, target_height, yaw):
		push_error("External environment asset failed: %s" % asset_path)


func _add_food_plant(at: Vector3, asset_name: String, index: int, host: Node3D = null) -> void:
	var plant := Node3D.new()
	plant.name = "FoodPlant_%d" % index
	plant.position = at
	plant.set_meta("kind", "food")
	plant.set_meta("available", true)
	plant.set_meta("scenery", true)
	(host if is_instance_valid(host) else self).add_child(plant)
	interactable_items.append(plant)
	var path := "res://assets/environment/%s" % asset_name
	if not _add_external_visual(plant, path, 1.45, 0.0):
		push_error("Food shrub model could not be loaded: %s" % path)


func _add_water_marker(at: Vector3) -> void:
	var marker := Node3D.new()
	marker.name = "WaterSource"
	marker.position = at
	marker.set_meta("kind", "water")
	marker.set_meta("available", true)
	marker.set_meta("source_type", "pond")
	add_child(marker)
	interactable_items.append(marker)


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
	var point := Vector2(player.global_position.x, player.global_position.z)
	var river_info := _river_distance(point)
	if is_instance_valid(river_water_source):
		var nearest: Vector2 = river_info.get("point", point)
		river_water_source.global_position = Vector3(nearest.x, 0.0, nearest.y)
	for index in range(interactable_items.size() - 1, -1, -1):
		var item := interactable_items[index]
		if not is_instance_valid(item):
			interactable_items.remove_at(index)
			continue
		if not item.has_meta("kind") or not bool(item.get_meta("available", false)) or not item.visible:
			continue
		var distance := player.global_position.distance_to(item.global_position)
		if item == river_water_source:
			if float(river_info.get("distance", INF)) <= 34.0:
				distance = 2.9
			else:
				continue
		elif str(item.get_meta("kind")) == "water":
			var offset: Vector3 = player.global_position - item.global_position
			if absf(offset.x) <= 13.0 and absf(offset.z) <= 9.0:
				distance = 2.9
		if distance < best:
			best = distance
			nearby_item = item
	if is_instance_valid(prompt_label):
		if nearby_item == null:
			var hunger_value := float(player.get("hunger"))
			var thirst_value := float(player.get("thirst"))
			if hunger_value <= 20.0 and thirst_value <= 20.0:
				prompt_label.text = "¡Peligro! Busca agua y alimento pronto."
			elif thirst_value <= 20.0:
				prompt_label.text = "Tienes sed. Busca un río o estanque."
			elif hunger_value <= 20.0:
				prompt_label.text = "Tienes hambre. Busca plantas o caza."
			else:
				prompt_label.text = "Explora la isla; busca agua, plantas o presas."
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
	world_position_label = Label.new()
	world_position_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	world_position_label.add_theme_font_size_override("font_size", 14)
	world_position_label.add_theme_color_override("font_color", Color(0.88, 1.0, 0.94))
	mobile_ui.add_child(world_position_label)
	var minimap_script := load("res://scripts/world_minimap.gd") as Script
	if minimap_script != null:
		minimap = Control.new()
		minimap.name = "WorldMiniMap"
		minimap.set_script(minimap_script)
		minimap.set("world_half_size", WORLD_HALF_SIZE)
		minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		minimap.position = Vector2(-166.0, 12.0)
		minimap.size = Vector2(150.0, 150.0)
		minimap.custom_minimum_size = minimap.size
		mobile_ui.add_child(minimap)
	else:
		push_error("Minimap script missing.")
	mobile_ui.visible = false

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
	_style_action_button(button)
	parent.add_child(button)
	move_buttons.append(button)
	button.button_down.connect(_set_action.bind(action, true))
	button.button_up.connect(_set_action.bind(action, false))


func _style_action_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.015, 0.075, 0.068, 0.86)
	normal.border_color = Color(0.04, 0.74, 0.64, 0.92)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.025, 0.18, 0.15, 0.95)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.02, 0.28, 0.22, 0.98)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(0.92, 1.0, 0.97))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))


func _add_use_button(parent: Control) -> void:
	use_button = Button.new()
	use_button.text = "USAR"
	use_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	use_button.position = Vector2(-124, -112)
	use_button.size = Vector2(100, 70)
	_style_action_button(use_button)
	parent.add_child(use_button)
	use_button.pressed.connect(_interact)


func _add_sprint_button(parent: Control) -> void:
	sprint_button = Button.new()
	sprint_button.text = "CORRER"
	sprint_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	sprint_button.size = Vector2(112, 58)
	sprint_button.custom_minimum_size = sprint_button.size
	_style_action_button(sprint_button)
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
	_style_action_button(attack_button)
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
	prompt_label.add_theme_font_size_override("font_size", roundi(16.0 * ui_scale))
	feedback_label.position = Vector2(viewport_size.x * 0.28, 16.0 * ui_scale)
	feedback_label.size = Vector2(viewport_size.x * 0.38, 44.0 * ui_scale)
	feedback_label.add_theme_font_size_override("font_size", roundi(16.0 * ui_scale))
	var button_size := Vector2(70.0, 64.0) * ui_scale
	var offsets: Array[Vector2] = [Vector2(98.0, -184.0), Vector2(98.0, -82.0), Vector2(18.0, -133.0), Vector2(178.0, -133.0)]
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
	if is_instance_valid(sprint_button):
		sprint_button.position = Vector2(-250.0, -92.0) * ui_scale
		sprint_button.size = Vector2(112.0, 58.0) * ui_scale
		sprint_button.custom_minimum_size = sprint_button.size
	if is_instance_valid(attack_button):
		attack_button.position = Vector2(-124.0, -190.0) * ui_scale
		attack_button.size = Vector2(100.0, 64.0) * ui_scale
		attack_button.custom_minimum_size = attack_button.size
	if is_instance_valid(minimap):
		minimap.position = Vector2(-166.0 * ui_scale, 12.0 * ui_scale)
		minimap.size = Vector2(150.0, 150.0) * ui_scale
		minimap.custom_minimum_size = minimap.size
	if is_instance_valid(world_position_label):
		world_position_label.position = Vector2(viewport_size.x * 0.37, 42.0 * ui_scale)
		world_position_label.size = Vector2(viewport_size.x * 0.3, 26.0 * ui_scale)


func _build_main_menu() -> void:
	var layer := CanvasLayer.new()
	layer.name = "MainMenuLayer"
	layer.layer = 10
	add_child(layer)
	menu_overlay = ColorRect.new()
	menu_overlay.name = "MainMenuOverlay"
	menu_overlay.color = Color(0.006, 0.024, 0.021, 0.96)
	menu_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(menu_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(540.0, 330.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.018, 0.07, 0.062, 0.98)
	panel_style.border_color = Color(0.02, 0.76, 0.65, 0.98)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	var title := Label.new()
	title.text = "PRIMALIS ONLINE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.27, 0.96, 0.79))
	content.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "SUPERVIVENCIA  ·  MUNDO ABIERTO DE 4.6 KM  ·  RÍOS Y BIOMAS"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.72, 0.88, 0.82))
	content.add_child(subtitle)
	var server_title := Label.new()
	server_title.text = "MUNDO LOCAL 01  ·  ISLA PRIMORDIAL"
	server_title.add_theme_font_size_override("font_size", 18)
	server_title.add_theme_color_override("font_color", Color(0.92, 1.0, 0.96))
	content.add_child(server_title)
	var server_state := Label.new()
	server_state.text = "SIN SERVIDOR DE RED  ·  PARTIDA LOCAL PARA 1 JUGADOR"
	server_state.add_theme_font_size_override("font_size", 13)
	server_state.add_theme_color_override("font_color", Color(0.73, 0.86, 0.81))
	content.add_child(server_state)
	server_join_button = Button.new()
	server_join_button.text = "ENTRAR AL MUNDO"
	server_join_button.custom_minimum_size = Vector2(440.0, 58.0)
	_style_action_button(server_join_button)
	server_join_button.add_theme_font_size_override("font_size", 20)
	content.add_child(server_join_button)
	server_join_button.pressed.connect(_enter_local_world)
	var footer := Label.new()
	footer.text = "Una sola entrada de prueba. Multijugador real aún no conectado."
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", Color(0.63, 0.75, 0.70))
	content.add_child(footer)


func _enter_local_world() -> void:
	if local_world_started:
		return
	local_world_started = true
	if is_instance_valid(menu_overlay):
		menu_overlay.visible = false
	if is_instance_valid(mobile_ui):
		mobile_ui.visible = true
	player.set_physics_process(true)
	for child in get_children():
		if child is CharacterBody3D and String(child.name).begins_with("WildDinosaur_"):
			child.set_physics_process(true)
	player.set("status_message", "Partida local. No hay servidor de red conectado.")
	if is_instance_valid(minimap):
		minimap.call("set_world_state", Vector2(player.global_position.x, player.global_position.z), river_paths)


func _region_name() -> String:
	var point := Vector2(player.global_position.x, player.global_position.z)
	if _near_river(point, 48.0):
		return "ORILLA DEL RÍO"
	if point.length() < 150.0:
		return "SELVA CENTRAL"
	if point.x < -350.0 and point.y < -250.0:
		return "TIERRAS DEL NORTE"
	if point.x > 350.0 and point.y > 250.0:
		return "BOSQUE DEL ESTE"
	if point.y > 350.0:
		return "LLANURA DEL SUR"
	return "ISLA PRIMORDIAL"
