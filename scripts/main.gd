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
var food_respawn_timers: Dictionary = {}

func _ready() -> void:
	_build_world_props()
	_build_mobile_ui()
	get_viewport().size_changed.connect(_layout_mobile_ui)
	_layout_mobile_ui()

func _process(_delta: float) -> void:
	if is_instance_valid(status_label):
		status_label.text = "PRIMALIS ONLINE\nSalud: %d   Hambre: %d\nSed: %d   Resistencia: %d" % [
			roundi(float(player.get("health"))), roundi(float(player.get("hunger"))), roundi(float(player.get("thirst"))), roundi(float(player.get("stamina")))
		]

	_update_food_respawns(_delta)
	_update_nearby_item()
	if is_instance_valid(feedback_label):
		feedback_label.text = str(player.get("status_message"))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		_interact()

func _build_world_props() -> void:
	# Lightweight procedural scenery: no downloaded assets or extra dependencies.
	var rng := RandomNumberGenerator.new()
	rng.seed = 64281
	for i in range(34):
		var x := rng.randf_range(-31.0, 31.0)
		var z := rng.randf_range(-31.0, 31.0)
		if Vector2(x, z).length() < 6.5 or (x > 9.0 and x < 22.0 and z > 8.0 and z < 22.0):
			continue
		_add_tree(Vector3(x, 0, z), rng.randf_range(0.75, 1.35), rng)

	for i in range(18):
		var x := rng.randf_range(-32.0, 32.0)
		var z := rng.randf_range(-32.0, 32.0)
		if Vector2(x, z).length() < 5.0:
			continue
		_add_rock(Vector3(x, 0.0, z), rng.randf_range(0.45, 1.1), rng)

	_add_pond(Vector3(15.0, 0.035, 15.0), Vector2(10.0, 7.0))
	_add_food_plant(Vector3(-8, 0, 4))
	_add_food_plant(Vector3(5, 0, -13))
	_add_food_plant(Vector3(-19, 0, -7))
	_add_food_plant(Vector3(23, 0, -12))
	_add_food_plant(Vector3(-24, 0, 19))
	_add_water_marker(Vector3(15, 0, 15))
	_build_world_boundaries()

func _build_world_boundaries() -> void:
	# Keep the player inside the 80x80 playable ground instead of falling off its edge.
	_add_boundary_wall(Vector3(0, 2.0, -39.5), Vector3(80, 4, 1))
	_add_boundary_wall(Vector3(0, 2.0, 39.5), Vector3(80, 4, 1))
	_add_boundary_wall(Vector3(-39.5, 2.0, 0), Vector3(1, 4, 80))
	_add_boundary_wall(Vector3(39.5, 2.0, 0), Vector3(1, 4, 80))

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

func _add_tree(at: Vector3, scale_factor: float, rng: RandomNumberGenerator) -> void:
	var tree := Node3D.new()
	tree.position = at
	tree.scale = Vector3.ONE * scale_factor
	add_child(tree)

	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.16
	trunk_mesh.bottom_radius = 0.25
	trunk_mesh.height = 2.2
	trunk.mesh = trunk_mesh
	trunk.position.y = 1.1
	trunk.material_override = _material(Color(0.28, 0.17, 0.09))
	tree.add_child(trunk)

	# Give the trunk a simple collision body so trees are real obstacles.
	var trunk_body := StaticBody3D.new()
	trunk_body.position.y = 1.1
	tree.add_child(trunk_body)
	var trunk_collision := CollisionShape3D.new()
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.28
	trunk_shape.height = 2.2
	trunk_collision.shape = trunk_shape
	trunk_body.add_child(trunk_collision)

	var crown := MeshInstance3D.new()
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = rng.randf_range(0.9, 1.35)
	crown_mesh.height = crown_mesh.radius * 1.7
	crown.mesh = crown_mesh
	crown.position.y = 2.45
	crown.material_override = _material(Color(rng.randf_range(0.12, 0.2), rng.randf_range(0.28, 0.4), 0.1))
	tree.add_child(crown)

func _add_rock(at: Vector3, size_factor: float, rng: RandomNumberGenerator) -> void:
	var rock := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.8
	mesh.height = 1.2
	rock.mesh = mesh
	rock.position = at + Vector3(0, 0.35 * size_factor, 0)
	rock.scale = Vector3(size_factor * rng.randf_range(0.8, 1.4), size_factor * 0.65, size_factor)
	rock.material_override = _material(Color(0.34, 0.36, 0.31))
	add_child(rock)

	# Match the obstacle collision to the visible rock's approximate footprint.
	var rock_body := StaticBody3D.new()
	rock_body.position = rock.position
	rock_body.scale = rock.scale
	add_child(rock_body)
	var rock_collision := CollisionShape3D.new()
	var rock_shape := SphereShape3D.new()
	rock_shape.radius = 0.72
	rock_collision.shape = rock_shape
	rock_body.add_child(rock_collision)

func _add_pond(at: Vector3, pond_size: Vector2) -> void:
	var pond := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = pond_size
	pond.mesh = mesh
	pond.position = at
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.12, 0.43, 0.57, 0.82)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.25
	pond.material_override = water
	add_child(pond)


func _add_food_plant(at: Vector3) -> void:
	var plant := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.35
	mesh.height = 0.3
	plant.mesh = mesh
	plant.position = at + Vector3(0, 0.25, 0)
	plant.scale = Vector3(1.5, 0.5, 1.0)
	plant.material_override = _material(Color(0.35, 0.62, 0.15))
	plant.set_meta("kind", "food")
	plant.set_meta("available", true)
	add_child(plant)

func _add_water_marker(at: Vector3) -> void:
	var marker := Node3D.new()
	marker.position = at
	marker.set_meta("kind", "water")
	marker.set_meta("available", true)
	add_child(marker)

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
			prompt_label.text = "Busca agua y plantas"
		elif str(nearby_item.get_meta("kind")) == "water":
			prompt_label.text = "Pulsa USAR para beber agua"
		else:
			prompt_label.text = "Pulsa USAR para comer plantas"

func _interact() -> void:
	if nearby_item == null:
		return
	if str(nearby_item.get_meta("kind")) == "water":
		player.call("consume_water")
	else:
		player.call("eat_food")
		nearby_item.set_meta("available", false)
		nearby_item.visible = false
		food_respawn_timers[nearby_item.get_instance_id()] = {"item": nearby_item, "remaining": 45.0}

func _update_food_respawns(delta: float) -> void:
	for item_id in food_respawn_timers.keys():
		var entry: Dictionary = food_respawn_timers[item_id]
		entry["remaining"] = float(entry["remaining"]) - delta
		if float(entry["remaining"]) <= 0.0:
			var plant: Node3D = entry["item"]
			if is_instance_valid(plant):
				plant.set_meta("available", true)
				plant.visible = true
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
	prompt_label = Label.new()
	prompt_label.position = Vector2(18, 112)
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

func _set_action(action: String, pressed: bool) -> void:
	player.call("set_mobile_action", action, pressed)

func _set_sprint(pressed: bool) -> void:
	player.call("set_sprint", pressed)

func _layout_mobile_ui() -> void:
	if not is_instance_valid(mobile_ui):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var ui_scale := clampf(minf(viewport_size.x / 1280.0, viewport_size.y / 720.0), 0.72, 1.35)
	status_label.position = Vector2(18.0, 16.0) * ui_scale
	status_label.add_theme_font_size_override("font_size", roundi(20.0 * ui_scale))
	prompt_label.position = Vector2(18.0, 112.0) * ui_scale
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
