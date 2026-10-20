extends RefCounted

## Dependency-free shared-world save store for plant cooldowns and the server-owned herd.
## Remaining durations are saved, so the world pauses while the dedicated server is offline.
const SCHEMA_VERSION: int = 1
const MAX_WORLD_COORDINATE: float = 2240.0
const MAX_PLANT_COOLDOWN_MS: int = 45000
const MAX_WILDLIFE_RESPAWN_SECONDS: float = 90.0

var _directory_absolute: String = ""


func initialize(directory_path: String = "user://primalis_server/world") -> bool:
	var clean_path: String = directory_path.strip_edges()
	if clean_path.is_empty():
		push_error("World store path cannot be empty.")
		return false
	_directory_absolute = ProjectSettings.globalize_path(clean_path)
	if not DirAccess.dir_exists_absolute(_directory_absolute):
		var mkdir_result: int = DirAccess.make_dir_recursive_absolute(_directory_absolute)
		if mkdir_result != OK and not DirAccess.dir_exists_absolute(_directory_absolute):
			push_error("Could not create world store directory (error %d)." % mkdir_result)
			return false
	return DirAccess.dir_exists_absolute(_directory_absolute)


func get_directory_path() -> String:
	return _directory_absolute


func load_world_state() -> Dictionary:
	if _directory_absolute.is_empty():
		return _empty_world_state()
	var target_path: String = _world_file_path()
	var saved: Dictionary = _read_world_file(target_path)
	if saved.is_empty():
		saved = _read_world_file(target_path + ".bak")
	if saved.is_empty():
		return _empty_world_state()
	return _sanitize_world_state(saved)


func save_world_state(food_respawn_remaining_ms: Dictionary, wildlife: Dictionary) -> bool:
	if _directory_absolute.is_empty():
		push_warning("World save skipped because the store is not initialized.")
		return false
	var payload := {
		"schema_version": SCHEMA_VERSION,
		"food_respawn_remaining_ms": _sanitize_food_cooldowns(food_respawn_remaining_ms),
		"wildlife": _sanitize_wildlife(wildlife)
	}
	var target_path: String = _world_file_path()
	var temp_path: String = target_path + ".tmp"
	var backup_path: String = target_path + ".bak"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not open temporary world save (error %d)." % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(payload))
	file.flush()
	file.close()

	var moved_previous: bool = false
	if FileAccess.file_exists(target_path):
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_path)
		var backup_result: int = DirAccess.rename_absolute(target_path, backup_path)
		if backup_result != OK:
			DirAccess.remove_absolute(temp_path)
			push_error("Could not protect previous world save (error %d)." % backup_result)
			return false
		moved_previous = true
	var commit_result: int = DirAccess.rename_absolute(temp_path, target_path)
	if commit_result != OK:
		if moved_previous and FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(backup_path, target_path)
		if FileAccess.file_exists(temp_path):
			DirAccess.remove_absolute(temp_path)
		push_error("Could not commit world save (error %d)." % commit_result)
		return false
	return true


func _world_file_path() -> String:
	return _directory_absolute.path_join("world_state.json")


func _read_world_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return {}
	var payload: Dictionary = parser.data
	if int(payload.get("schema_version", -1)) != SCHEMA_VERSION:
		return {}
	return {
		"food_respawn_remaining_ms": payload.get("food_respawn_remaining_ms", {}),
		"wildlife": payload.get("wildlife", {})
	}


func _empty_world_state() -> Dictionary:
	return {
		"food_respawn_remaining_ms": {},
		"wildlife": {}
	}


func _sanitize_world_state(source: Dictionary) -> Dictionary:
	var food_value: Variant = source.get("food_respawn_remaining_ms", {})
	var wildlife_value: Variant = source.get("wildlife", {})
	var food: Dictionary = food_value if typeof(food_value) == TYPE_DICTIONARY else {}
	var wildlife: Dictionary = wildlife_value if typeof(wildlife_value) == TYPE_DICTIONARY else {}
	return {
		"food_respawn_remaining_ms": _sanitize_food_cooldowns(food),
		"wildlife": _sanitize_wildlife(wildlife)
	}


func _sanitize_food_cooldowns(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key_value in source.keys():
		var key: String = String(key_value)
		if not key.begins_with("plant_") or key.length() > 24:
			continue
		var raw_value: Variant = source[key_value]
		var value_type: int = typeof(raw_value)
		if value_type != TYPE_INT and value_type != TYPE_FLOAT:
			continue
		var number: float = float(raw_value)
		if not is_finite(number):
			continue
		var remaining: int = clampi(int(number), 0, MAX_PLANT_COOLDOWN_MS)
		if remaining > 0:
			result[key] = remaining
	return result


func _sanitize_wildlife(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for index in range(1, 11):
		var wildlife_id: String = "herbivore-%03d" % index
		if not source.has(wildlife_id) or typeof(source[wildlife_id]) != TYPE_DICTIONARY:
			continue
		var raw: Dictionary = source[wildlife_id]
		var max_health: float = _number(raw, "max_health", 100.0, 1.0, 200.0)
		var is_dead: bool = _boolean(raw, "is_dead", false)
		result[wildlife_id] = {
			"species_id": clampi(int(_number(raw, "species_id", float((index - 1) % 5), 0.0, 4.0)), 0, 4),
			"x": _number(raw, "x", 0.0, -MAX_WORLD_COORDINATE, MAX_WORLD_COORDINATE),
			"z": _number(raw, "z", 0.0, -MAX_WORLD_COORDINATE, MAX_WORLD_COORDINATE),
			"yaw": wrapf(_number(raw, "yaw", 0.0, -100000.0, 100000.0), -PI, PI),
			"home_x": _number(raw, "home_x", 0.0, -MAX_WORLD_COORDINATE, MAX_WORLD_COORDINATE),
			"home_z": _number(raw, "home_z", 0.0, -MAX_WORLD_COORDINATE, MAX_WORLD_COORDINATE),
			"destination_x": _number(raw, "destination_x", 0.0, -MAX_WORLD_COORDINATE, MAX_WORLD_COORDINATE),
			"destination_z": _number(raw, "destination_z", 0.0, -MAX_WORLD_COORDINATE, MAX_WORLD_COORDINATE),
			"decision_timer": _number(raw, "decision_timer", 0.0, 0.0, 10.0),
			"flee_timer": 0.0,
			"flee_x": _number(raw, "flee_x", 0.0, -1.0, 1.0),
			"flee_z": _number(raw, "flee_z", 0.0, -1.0, 1.0),
			"health": minf(_number(raw, "health", max_health, 0.0, 200.0), max_health),
			"max_health": max_health,
			"is_dead": is_dead,
			"is_moving": false,
			"meat_available": _boolean(raw, "meat_available", false) if is_dead else false,
			"respawn_remaining": _number(raw, "respawn_remaining", 0.0, 0.0, MAX_WILDLIFE_RESPAWN_SECONDS) if is_dead else 0.0
		}
	return result


func _number(source: Dictionary, key: String, fallback: float, minimum: float, maximum: float) -> float:
	var raw_value: Variant = source.get(key, fallback)
	var value_type: int = typeof(raw_value)
	if value_type != TYPE_INT and value_type != TYPE_FLOAT:
		return fallback
	var number: float = float(raw_value)
	if not is_finite(number):
		return fallback
	return clampf(number, minimum, maximum)


func _boolean(source: Dictionary, key: String, fallback: bool) -> bool:
	var raw_value: Variant = source.get(key, fallback)
	return raw_value if typeof(raw_value) == TYPE_BOOL else fallback
