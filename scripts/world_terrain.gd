extends RefCounted

## Single source of truth for the island's procedural ground height and river paths.
## Both the rendered client world and headless server call these same methods.
const WORLD_HALF_SIZE: float = 2300.0

var _terrain_noise: FastNoiseLite
var _terrain_detail_noise: FastNoiseLite
var _river_paths: Array[Array] = []


func _init() -> void:
	_initialize_terrain_noise()
	_build_river_paths()


func get_terrain_noise() -> FastNoiseLite:
	return _terrain_noise


func get_terrain_detail_noise() -> FastNoiseLite:
	return _terrain_detail_noise


func get_river_paths() -> Array[Array]:
	return _river_paths


func height_at(point: Vector2) -> float:
	var broad: float = _terrain_noise.get_noise_2d(point.x, point.y) * 22.0
	var detail: float = _terrain_detail_noise.get_noise_2d(point.x, point.y) * 2.2
	var height: float = broad + detail
	if not _river_paths.is_empty():
		var river_distance: float = float(river_distance_for_terrain(point).get("distance", WORLD_HALF_SIZE))
		height = lerpf(-2.8, height, smoothstep(0.0, 125.0, river_distance))
	if point.length() < 170.0:
		height = lerpf(0.0, height, smoothstep(105.0, 170.0, point.length()))
	return height


func river_distance_for_terrain(point: Vector2) -> Dictionary:
	var nearest := point
	var shortest := INF
	for path in _river_paths:
		for i in range(0, path.size() - 1, 4):
			var a: Vector2 = path[i]
			var b: Vector2 = path[mini(i + 4, path.size() - 1)]
			var edge := b - a
			var t := 0.0
			if edge.length_squared() > 0.001:
				t = clampf((point - a).dot(edge) / edge.length_squared(), 0.0, 1.0)
			var candidate := a + edge * t
			var distance: float = point.distance_to(candidate)
			if distance < shortest:
				shortest = distance
				nearest = candidate
	return {"distance": shortest, "point": nearest}


## Exact path distance for server-side interaction checks; terrain generation uses the
## coarse method above to keep the full mobile terrain mesh inexpensive to build.
func river_distance_for_water(point: Vector2) -> Dictionary:
	var nearest := point
	var shortest := INF
	for path in _river_paths:
		for i in range(path.size() - 1):
			var a: Vector2 = path[i]
			var b: Vector2 = path[i + 1]
			var edge := b - a
			var t := 0.0
			if edge.length_squared() > 0.001:
				t = clampf((point - a).dot(edge) / edge.length_squared(), 0.0, 1.0)
			var candidate := a + edge * t
			var distance: float = point.distance_to(candidate)
			if distance < shortest:
				shortest = distance
				nearest = candidate
	return {"distance": shortest, "point": nearest}


func _initialize_terrain_noise() -> void:
	_terrain_noise = FastNoiseLite.new()
	_terrain_noise.seed = 726401
	_terrain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_terrain_noise.frequency = 0.00095
	_terrain_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_terrain_noise.fractal_octaves = 4
	_terrain_noise.fractal_lacunarity = 2.0
	_terrain_noise.fractal_gain = 0.50

	_terrain_detail_noise = FastNoiseLite.new()
	_terrain_detail_noise.seed = 413907
	_terrain_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_terrain_detail_noise.frequency = 0.0045
	_terrain_detail_noise.fractal_octaves = 2


func _build_river_paths() -> void:
	_river_paths.clear()
	var trunk: Array[Vector2] = []
	for i in range(221):
		var t := float(i) / 220.0
		trunk.append(Vector2(lerpf(-2280.0, 2280.0, t), 570.0 + 330.0 * sin(t * TAU * 1.15) + 100.0 * sin(t * TAU * 3.4)))
	_river_paths.append(trunk)

	var north: Array[Vector2] = []
	var nt := 1700.0 / 4560.0
	var nz := 570.0 + 330.0 * sin(nt * TAU * 1.15) + 100.0 * sin(nt * TAU * 3.4)
	for i in range(161):
		var t := float(i) / 160.0
		north.append(Vector2(-880.0 + 374.0 * t + 220.0 * sin(t * PI) + 88.0 * sin(t * TAU * 2.0), lerpf(-2280.0, nz, t)))
	north[north.size() - 1].x = -506.0
	_river_paths.append(north)

	var south: Array[Vector2] = []
	var st := 3300.0 / 4560.0
	var sz := 570.0 + 330.0 * sin(st * TAU * 1.15) + 100.0 * sin(st * TAU * 3.4)
	for i in range(161):
		var t := float(i) / 160.0
		south.append(Vector2(1430.0 - 550.0 * t - 242.0 * sin(t * PI) + 99.0 * sin(t * TAU * 2.0), lerpf(2280.0, sz, t)))
	south[south.size() - 1].x = 880.0
	_river_paths.append(south)
