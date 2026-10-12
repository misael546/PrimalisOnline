extends Control

var world_half_size: float = 1000.0
var player_world_position: Vector2 = Vector2.ZERO
var river_lines: Array = []

func set_world_state(position_world: Vector2, paths: Array) -> void:
	player_world_position = position_world
	river_lines = paths
	queue_redraw()

func _draw() -> void:
	if size.x < 2.0 or size.y < 2.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.065, 0.055, 0.94), true)
	for step in range(1, 4):
		var x := size.x * float(step) / 4.0
		var y := size.y * float(step) / 4.0
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), Color(0.25, 0.43, 0.35, 0.45), 1.0)
		draw_line(Vector2(0.0, y), Vector2(size.x, y), Color(0.25, 0.43, 0.35, 0.45), 1.0)
	for variant in river_lines:
		var path := PackedVector2Array()
		for p in variant:
			var world_point: Vector2 = p
			path.append(Vector2(clampf((world_point.x + world_half_size) / (world_half_size * 2.0), 0.0, 1.0) * size.x, clampf((world_point.y + world_half_size) / (world_half_size * 2.0), 0.0, 1.0) * size.y))
		if path.size() > 1:
			draw_polyline(path, Color(0.10, 0.66, 0.90, 0.94), 2.0, true)
	var position := Vector2(clampf((player_world_position.x + world_half_size) / (world_half_size * 2.0), 0.0, 1.0) * size.x, clampf((player_world_position.y + world_half_size) / (world_half_size * 2.0), 0.0, 1.0) * size.y)
	draw_circle(position, 5.5, Color(0.02, 0.02, 0.02, 0.95))
	draw_circle(position, 3.3, Color(0.25, 1.0, 0.68, 1.0))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.23, 0.86, 0.69, 0.9), false, 2.0)
