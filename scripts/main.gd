extends Node3D

@onready var player: CharacterBody3D = $Player
var status_label: Label

func _ready() -> void:
	_build_world_props()
	_build_mobile_ui()

func _process(_delta: float) -> void:
	if is_instance_valid(status_label):
		status_label.text = "PRIMALIS ONLINE\nSalud: %d   Hambre: %d\nSed: %d   Resistencia: %d" % [
			roundi(float(player.get("health"))), roundi(float(player.get("hunger"))), roundi(float(player.get("thirst"))), roundi(float(player.get("stamina")))
		]

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

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material

func _build_mobile_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "MobileHUD"
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(ui)

	status_label = Label.new()
	status_label.position = Vector2(18, 16)
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	status_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	status_label.add_theme_constant_override("shadow_offset_x", 2)
	status_label.add_theme_constant_override("shadow_offset_y", 2)
	ui.add_child(status_label)

	_add_move_button(ui, "▲", "move_forward", Vector2(98, -184))
	_add_move_button(ui, "▼", "move_back", Vector2(98, -82))
	_add_move_button(ui, "◀", "move_left", Vector2(18, -133))
	_add_move_button(ui, "▶", "move_right", Vector2(178, -133))

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
	button.button_down.connect(_set_action.bind(action, true))
	button.button_up.connect(_set_action.bind(action, false))

func _set_action(action: String, pressed: bool) -> void:
	player.call("set_mobile_action", action, pressed)
