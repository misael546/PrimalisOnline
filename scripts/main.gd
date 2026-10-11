
extends Node3D

@onready var player: CharacterBody3D = $Player
var status_label: Label

func _ready() -> void:
	_build_mobile_ui()

func _process(_delta: float) -> void:
	if is_instance_valid(status_label):
		status_label.text = "PRIMALIS ONLINE\nSalud: %d   Hambre: %d\nSed: %d   Resistencia: %d" % [
			roundi(player.health), roundi(player.hunger), roundi(player.thirst), roundi(player.stamina)
		]

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
	player.set_mobile_action(action, pressed)
