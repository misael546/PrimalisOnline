extends RefCounted

## Small, dependency-free persistent character store for the dedicated server.
## Each identity has its own JSON file and a previous-file backup.
const SCHEMA_VERSION: int = 1

var _directory_absolute: String = ""


func initialize(directory_path: String = "user://primalis_server/characters") -> bool:
	var clean_path := directory_path.strip_edges()
	if clean_path.is_empty():
		push_error("Character store path cannot be empty.")
		return false
	_directory_absolute = ProjectSettings.globalize_path(clean_path)
	if not DirAccess.dir_exists_absolute(_directory_absolute):
		var mkdir_result: int = DirAccess.make_dir_recursive_absolute(_directory_absolute)
		if mkdir_result != OK and not DirAccess.dir_exists_absolute(_directory_absolute):
			push_error("Could not create character store directory (error %d)." % mkdir_result)
			return false
	return DirAccess.dir_exists_absolute(_directory_absolute)


func get_directory_path() -> String:
	return _directory_absolute


func load_character(identity_hash: String) -> Dictionary:
	if _directory_absolute.is_empty() or not _is_valid_hash(identity_hash):
		return _default_character()
	var target_path := _character_path(identity_hash)
	var character := _read_character_file(target_path)
	if character.is_empty():
		character = _read_character_file(target_path + ".bak")
	if character.is_empty():
		return _default_character()
	return _sanitize_character(character)


func save_character(identity_hash: String, source: Dictionary) -> bool:
	if _directory_absolute.is_empty() or not _is_valid_hash(identity_hash):
		push_warning("Character save skipped because the store or identity is invalid.")
		return false
	var target_path := _character_path(identity_hash)
	var temp_path := target_path + ".tmp"
	var backup_path := target_path + ".bak"
	var payload := {
		"schema_version": SCHEMA_VERSION,
		"character": _sanitize_character(source)
	}
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not open temporary character save (error %d)." % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(payload))
	file.flush()
	file.close()

	var moved_previous := false
	if FileAccess.file_exists(target_path):
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_path)
		var backup_result: int = DirAccess.rename_absolute(target_path, backup_path)
		if backup_result != OK:
			DirAccess.remove_absolute(temp_path)
			push_error("Could not protect the previous character save (error %d)." % backup_result)
			return false
		moved_previous = true
	var commit_result: int = DirAccess.rename_absolute(temp_path, target_path)
	if commit_result != OK:
		if moved_previous and FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(backup_path, target_path)
		if FileAccess.file_exists(temp_path):
			DirAccess.remove_absolute(temp_path)
		push_error("Could not commit character save (error %d)." % commit_result)
		return false
	return true


func _character_path(identity_hash: String) -> String:
	return _directory_absolute.path_join("%s.json" % identity_hash)


func _read_character_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return {}
	var payload: Dictionary = parser.data
	if int(payload.get("schema_version", -1)) != SCHEMA_VERSION:
		return {}
	var character_value: Variant = payload.get("character", null)
	if typeof(character_value) != TYPE_DICTIONARY:
		return {}
	return character_value


func _default_character() -> Dictionary:
	return {
		"x": 0.0,
		"z": 0.0,
		"yaw": 0.0,
		"health": 100.0,
		"hunger": 100.0,
		"thirst": 100.0,
		"stamina": 100.0,
		"kills": 0
	}


func _sanitize_character(source: Dictionary) -> Dictionary:
	var result := _default_character()
	for key in ["x", "z", "yaw", "health", "hunger", "thirst", "stamina"]:
		var raw_value: Variant = source.get(key, result[key])
		var value_type: int = typeof(raw_value)
		if value_type == TYPE_INT or value_type == TYPE_FLOAT:
			var number := float(raw_value)
			if is_finite(number):
				match key:
					"x", "z":
						result[key] = clampf(number, -2250.0, 2250.0)
					"yaw":
						result[key] = wrapf(number, -PI, PI)
					_:
						result[key] = clampf(number, 0.0, 100.0)
	var kills_value: Variant = source.get("kills", 0)
	if typeof(kills_value) == TYPE_INT or typeof(kills_value) == TYPE_FLOAT:
		var kills_number := float(kills_value)
		if is_finite(kills_number):
			result["kills"] = clampi(int(kills_number), 0, 2147483647)
	return result


func _is_valid_hash(value: String) -> bool:
	if value.length() != 64:
		return false
	for character in value.to_lower():
		if not "0123456789abcdef".contains(character):
			return false
	return true
