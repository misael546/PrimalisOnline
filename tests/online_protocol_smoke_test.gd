extends SceneTree

const Protocol = preload("res://scripts/online_protocol.gd")
const ServerScript = preload("res://server/online_server.gd")
const ClientScript = preload("res://scripts/online_client.gd")
const RemotePlayerScript = preload("res://scripts/remote_player.gd")
const RemoteWildlifeScript = preload("res://scripts/remote_wildlife.gd")
const CharacterStoreScript = preload("res://server/character_store.gd")
const WorldStoreScript = preload("res://server/world_store.gd")
const TerrainAuthorityScript = preload("res://scripts/world_terrain.gd")
const TEST_PORT: int = 19089

var _failures: int = 0
var _server_node: Node
var _client_a: Node
var _client_b: Node
var _deadline_ms: int = 0
var _first_player_id: String = ""
var _second_player_id: String = ""
var _seen_session: Dictionary = {"A": false, "B": false}
var _join_requested: Dictionary = {"A": false, "B": false}
var _move_started_ms: int = -1
var _move_stop_sent: bool = false
var _saw_two_players: bool = false
var _saw_server_movement: bool = false
var _sprint_regression_checked: bool = false
var _gameplay_regressions_checked: bool = false
var _max_first_player_x: float = 0.0


func _initialize() -> void:
	process_frame.connect(_on_process_frame)
	call_deferred("_begin")


func _begin() -> void:
	_run_terrain_authority_cases()
	_run_character_store_cases()
	_run_world_store_cases()
	_run_protocol_cases()
	if _failures > 0:
		quit(1)
		return
	_expect(Protocol != null, "protocol script loads")
	_expect(ServerScript != null, "dedicated server script loads")
	_expect(ClientScript != null, "online client script loads")
	_expect(RemotePlayerScript != null, "remote player visual script loads")
	_expect(RemoteWildlifeScript != null, "remote wildlife visual script loads")
	if _failures > 0:
		quit(1)
		return

	_server_node = Node.new()
	_server_node.name = "PrimalisOnlineServerTest"
	_server_node.set_script(ServerScript)
	_server_node.call("configure_data_directory", "user://primalis_online_server_smoke")
	root.add_child(_server_node)
	var listen_result: int = int(_server_node.call("start_server", TEST_PORT, "127.0.0.1"))
	_expect(listen_result == OK, "dedicated WebSocket server binds to loopback")
	var initial_wildlife: Dictionary = _server_node.get("_wildlife")
	_expect(initial_wildlife.size() == 10, "server creates its initial replicated herbivore population")
	_expect(bool(_server_node.call("_can_traverse_step", Vector2.ZERO, Vector2(0.45, 0.0))), "server permits normal movement over the central terrain")
	if _failures > 0:
		quit(1)
		return

	_client_a = _create_client("A")
	_client_b = _create_client("B")
	_deadline_ms = Time.get_ticks_msec() + 10000


func _create_client(label: String) -> Node:
	var client_node := Node.new()
	client_node.name = "OnlineClientTest%s" % label
	client_node.set_script(ClientScript)
	client_node.set("server_url", "ws://127.0.0.1:%d" % TEST_PORT)
	client_node.set("auto_reconnect", false)
	client_node.set("identity_token_override", "a".repeat(64) if label == "A" else "b".repeat(64))
	client_node.connect("state_changed", _on_client_state_changed.bind(label))
	client_node.connect("message_received", _on_client_message_received.bind(label))
	root.add_child(client_node)
	return client_node


func _run_terrain_authority_cases() -> void:
	var terrain := TerrainAuthorityScript.new()
	var center_height: float = float(terrain.call("height_at", Vector2.ZERO))
	_expect(absf(center_height) < 0.001, "shared terrain keeps the central spawn area level")
	var test_point := Vector2(420.0, -735.0)
	var first_height: float = float(terrain.call("height_at", test_point))
	var second_height: float = float(terrain.call("height_at", test_point))
	_expect(is_finite(first_height) and absf(first_height - second_height) < 0.0001, "shared terrain height is deterministic")
	var paths_value: Variant = terrain.call("get_river_paths")
	_expect(typeof(paths_value) == TYPE_ARRAY and (paths_value as Array).size() == 3, "shared terrain provides the main river and two tributaries")
	if typeof(paths_value) != TYPE_ARRAY or (paths_value as Array).size() != 3:
		return
	var paths: Array = paths_value
	var trunk: Array = paths[0]
	var river_point: Vector2 = trunk[100]
	var river_result: Dictionary = terrain.call("river_distance_for_terrain", river_point)
	_expect(float(river_result.get("distance", INF)) < 0.001, "river distance uses the same shared path coordinates")


func _run_character_store_cases() -> void:
	var store := CharacterStoreScript.new()
	var test_directory: String = "user://primalis_character_store_smoke"
	_expect(bool(store.call("initialize", test_directory)), "character store initializes")
	var test_hash: String = "c".repeat(64)
	var sample := {
		"x": 21.5, "z": -4.25, "yaw": 0.8,
		"health": 68.0, "hunger": 42.0, "thirst": 31.0, "stamina": 77.0, "kills": 3
	}
	_expect(bool(store.call("save_character", test_hash, sample)), "character state is saved")
	var reopened := CharacterStoreScript.new()
	_expect(bool(reopened.call("initialize", test_directory)), "character store can reopen its data directory")
	var restored: Dictionary = reopened.call("load_character", test_hash)
	_expect(absf(float(restored.get("x", 0.0)) - 21.5) < 0.01, "saved character position survives store reload")
	_expect(absf(float(restored.get("health", 0.0)) - 68.0) < 0.01, "saved character vitals survive store reload")
	_expect(int(restored.get("kills", 0)) == 3, "saved character statistics survive store reload")
	var malicious_sample := {"x": 999999.0, "health": 900.0, "hunger": -50.0, "kills": -7}
	_expect(bool(reopened.call("save_character", test_hash, malicious_sample)), "character save sanitizes untrusted state")
	var sanitized: Dictionary = reopened.call("load_character", test_hash)
	_expect(absf(float(sanitized.get("x", 0.0)) - 2250.0) < 0.01 and absf(float(sanitized.get("health", 0.0)) - 100.0) < 0.01 and int(sanitized.get("kills", 0)) == 0, "persistent data is clamped to safe bounds")


func _run_world_store_cases() -> void:
	var store := WorldStoreScript.new()
	var test_directory: String = "user://primalis_world_store_smoke"
	_expect(bool(store.call("initialize", test_directory)), "shared-world store initializes")
	var initial_wildlife := {
		"herbivore-001": {
			"species_id": 1, "x": 123.5, "z": -44.25, "yaw": 0.7,
			"home_x": 100.0, "home_z": -50.0,
			"destination_x": 140.0, "destination_z": -20.0,
			"decision_timer": 3.5, "flee_timer": 1.0, "flee_x": 1.0, "flee_z": 0.0,
			"health": 61.0, "max_health": 100.0, "is_dead": false,
			"is_moving": true, "meat_available": false, "respawn_remaining": 0.0
		}
	}
	_expect(bool(store.call("save_world_state", {"plant_0": 30000, "plant_4": 90000, "plant_99": 12000}, initial_wildlife)), "shared world state saves")
	var reopened := WorldStoreScript.new()
	_expect(bool(reopened.call("initialize", test_directory)), "shared-world store can reopen its directory")
	var restored: Dictionary = reopened.call("load_world_state")
	var restored_food: Dictionary = restored.get("food_respawn_remaining_ms", {})
	var restored_wildlife: Dictionary = restored.get("wildlife", {})
	var restored_animal: Dictionary = restored_wildlife.get("herbivore-001", {})
	_expect(int(restored_food.get("plant_0", 0)) == 30000, "plant cooldown survives a store reload")
	_expect(int(restored_food.get("plant_4", 0)) == 45000 and not restored_food.has("plant_99"), "plant cooldowns are bounded to known resources")
	_expect(absf(float(restored_animal.get("x", 0.0)) - 123.5) < 0.01 and absf(float(restored_animal.get("health", 0.0)) - 61.0) < 0.01, "wildlife position and health survive a store reload")
	_expect(not bool(restored_animal.get("is_moving", true)), "wildlife resumes safely from a stopped state after restart")

	var second_wildlife := initial_wildlife.duplicate(true)
	var second_animal: Dictionary = second_wildlife["herbivore-001"]
	second_animal["health"] = 49.0
	second_wildlife["herbivore-001"] = second_animal
	_expect(bool(reopened.call("save_world_state", {"plant_2": 5000}, second_wildlife)), "shared-world store rotates a recovery backup")
	var world_path: String = String(reopened.call("_world_file_path"))
	var corrupt_file := FileAccess.open(world_path, FileAccess.WRITE)
	_expect(corrupt_file != null, "shared-world save file can be opened for corruption recovery test")
	if corrupt_file != null:
		corrupt_file.store_string("{invalid")
		corrupt_file.close()
	var recovery_store := WorldStoreScript.new()
	_expect(bool(recovery_store.call("initialize", test_directory)), "recovery store initializes")
	var recovered: Dictionary = recovery_store.call("load_world_state")
	var recovered_food: Dictionary = recovered.get("food_respawn_remaining_ms", {})
	var recovered_wildlife: Dictionary = recovered.get("wildlife", {})
	var recovered_animal: Dictionary = recovered_wildlife.get("herbivore-001", {})
	_expect(int(recovered_food.get("plant_0", 0)) == 30000 and absf(float(recovered_animal.get("health", 0.0)) - 61.0) < 0.01, "corrupt world save recovers from the previous backup")

	var malicious_wildlife := {
		"herbivore-001": {"x": 999999.0, "z": -999999.0, "health": 500.0, "max_health": 100.0, "is_dead": false, "is_moving": true},
		"player-fake": {"x": 0.0, "health": 100.0}
	}
	_expect(bool(recovery_store.call("save_world_state", {"plant_0": -10, "invalid": 12000}, malicious_wildlife), "untrusted world data is saved only after sanitization")
	var sanitized_world: Dictionary = recovery_store.call("load_world_state")
	var sanitized_food: Dictionary = sanitized_world.get("food_respawn_remaining_ms", {})
	var sanitized_wildlife: Dictionary = sanitized_world.get("wildlife", {})
	var sanitized_animal: Dictionary = sanitized_wildlife.get("herbivore-001", {})
	_expect(absf(float(sanitized_animal.get("x", 0.0)) - 2240.0) < 0.01 and absf(float(sanitized_animal.get("z", 0.0)) + 2240.0) < 0.01, "persisted wildlife coordinates are clamped to map bounds")
	_expect(absf(float(sanitized_animal.get("health", 0.0)) - 100.0) < 0.01 and not bool(sanitized_animal.get("is_moving", true)), "persisted wildlife vitals and motion state are sanitized")
	_expect(sanitized_wildlife.size() == 1 and sanitized_food.is_empty(), "unknown wildlife ids and invalid cooldowns are discarded")


func _run_server_gameplay_regressions() -> void:
	var players: Dictionary = _server_node.get("_players")
	var identity_a: String = "a".repeat(64).sha256_text()
	var identity_b: String = "b".repeat(64).sha256_text()
	var peer_a: int = -1
	var peer_b: int = -1
	for peer_variant in players.keys():
		var peer_id: int = int(peer_variant)
		var state: Dictionary = players[peer_id]
		if String(state.get("identity_hash", "")) == identity_a:
			peer_a = peer_id
		elif String(state.get("identity_hash", "")) == identity_b:
			peer_b = peer_id
	_expect(peer_a >= 0 and peer_b >= 0, "server assigned unique persistent identities")
	if peer_a < 0 or peer_b < 0:
		return

	var state_a: Dictionary = players[peer_a]
	var state_b: Dictionary = players[peer_b]
	state_a["x"] = 15.0
	state_a["z"] = 15.0
	state_a["health"] = 100.0
	state_a["hunger"] = 100.0
	state_a["thirst"] = 50.0
	state_a["last_input_ms"] = Time.get_ticks_msec()
	state_b["x"] = 100.0
	state_b["z"] = 100.0
	state_b["health"] = 100.0
	state_b["last_input_ms"] = Time.get_ticks_msec()
	players[peer_a] = state_a
	players[peer_b] = state_b
	_server_node.set("_players", players)
	var drink_result: Dictionary = _server_node.call("_handle_message", peer_a, {"type": "interact"})
	var drink_player: Dictionary = drink_result.get("player", {})
	_expect(bool(drink_result.get("ok", false)) and String(drink_result.get("code", "")) == "drank_water", "server allows drinking only beside the pond")
	_expect(float(drink_player.get("thirst", 0.0)) > 50.0, "drinking restores server-owned thirst")
	if _failures > 0:
		return

	players = _server_node.get("_players")
	state_a = players[peer_a]
	state_a["x"] = -8.0
	state_a["z"] = 4.0
	state_a["hunger"] = 20.0
	state_a["thirst"] = 100.0
	state_a["last_input_ms"] = Time.get_ticks_msec()
	players[peer_a] = state_a
	_server_node.set("_players", players)
	var eat_result: Dictionary = _server_node.call("_handle_message", peer_a, {"type": "interact"})
	var eat_player: Dictionary = eat_result.get("player", {})
	_expect(bool(eat_result.get("ok", false)) and String(eat_result.get("code", "")) == "ate_plant", "server allows eating only beside an available plant")
	_expect(float(eat_player.get("hunger", 0.0)) > 20.0, "eating restores server-owned hunger")
	if _failures > 0:
		return

	players = _server_node.get("_players")
	state_a = players[peer_a]
	state_b = players[peer_b]
	state_a["x"] = 0.0
	state_a["z"] = 0.0
	state_a["yaw"] = -PI / 2.0
	state_a["last_attack_ms"] = 0
	state_b["x"] = 2.0
	state_b["z"] = 0.0
	state_b["health"] = 100.0
	state_b["is_respawning"] = false
	players[peer_a] = state_a
	players[peer_b] = state_b
	_server_node.set("_players", players)
	var attack_result: Dictionary = _server_node.call("_handle_message", peer_a, {"type": "attack"})
	players = _server_node.get("_players")
	state_b = players[peer_b]
	_expect(bool(attack_result.get("ok", false)), "server accepts a bite only when a player is in front and in range")
	_expect(absf(float(state_b.get("health", 100.0)) - 75.0) < 0.01, "server applies the configured 25 damage to the target")
	if _failures > 0:
		return

	players = _server_node.get("_players")
	state_a = players[peer_a]
	var store_verifier := CharacterStoreScript.new()
	_expect(bool(store_verifier.call("initialize", String(_server_node.get("_data_directory")))), "server character directory can be reopened")
	var saved_state: Dictionary = store_verifier.call("load_character", identity_a)
	_expect(absf(float(saved_state.get("hunger", -1.0)) - float(state_a.get("hunger", 0.0))) < 0.01, "server persists authoritative survival state after actions")
	_expect(absf(float(saved_state.get("x", -9999.0)) - float(state_a.get("x", 0.0))) < 0.01, "server persists authoritative world position")

	players = _server_node.get("_players")
	state_a = players[peer_a]
	state_b = players[peer_b]
	state_a["x"] = 100.0
	state_a["z"] = 0.0
	state_a["yaw"] = -PI / 2.0
	state_a["last_attack_ms"] = 0
	state_a["last_input_ms"] = Time.get_ticks_msec()
	state_b["x"] = 500.0
	state_b["z"] = 500.0
	state_b["last_input_ms"] = Time.get_ticks_msec()
	players[peer_a] = state_a
	players[peer_b] = state_b
	_server_node.set("_players", players)

	var wildlife: Dictionary = _server_node.get("_wildlife")
	var wildlife_keys: Array = wildlife.keys()
	_expect(not wildlife_keys.is_empty(), "server maintains an authoritative wildlife collection")
	if wildlife_keys.is_empty():
		return
	var target_wildlife_id: String = String(wildlife_keys[0])
	for other_wildlife_id_value in wildlife_keys:
		var other_wildlife_id: String = String(other_wildlife_id_value)
		if other_wildlife_id == target_wildlife_id:
			continue
		var distant_animal: Dictionary = wildlife[other_wildlife_id]
		distant_animal["x"] = -1000.0
		distant_animal["z"] = 1000.0
		distant_animal["is_dead"] = false
		distant_animal["health"] = 100.0
		wildlife[other_wildlife_id] = distant_animal
	var target_animal: Dictionary = wildlife[target_wildlife_id]
	target_animal["x"] = 102.0
	target_animal["z"] = 0.0
	target_animal["home_x"] = 102.0
	target_animal["home_z"] = 0.0
	target_animal["destination_x"] = 102.0
	target_animal["destination_z"] = 0.0
	target_animal["decision_timer"] = 10.0
	target_animal["flee_timer"] = 0.0
	target_animal["health"] = 100.0
	target_animal["is_dead"] = false
	target_animal["is_moving"] = false
	target_animal["meat_available"] = false
	target_animal["respawn_remaining"] = 0.0
	wildlife[target_wildlife_id] = target_animal
	_server_node.set("_wildlife", wildlife)
	var wildlife_hit: Dictionary = _server_node.call("_handle_message", peer_a, {"type": "attack"})
	wildlife = _server_node.get("_wildlife")
	target_animal = wildlife[target_wildlife_id]
	_expect(bool(wildlife_hit.get("ok", false)) and absf(float(target_animal.get("health", 0.0)) - 75.0) < 0.01, "server validates a bite against nearby living herbivores")
	if _failures > 0:
		return
	for strike_index in range(3):
		players = _server_node.get("_players")
		state_a = players[peer_a]
		state_a["last_attack_ms"] = 0
		players[peer_a] = state_a
		_server_node.set("_players", players)
		_server_node.call("_handle_message", peer_a, {"type": "attack"})
	wildlife = _server_node.get("_wildlife")
	target_animal = wildlife[target_wildlife_id]
	_expect(bool(target_animal.get("is_dead", false)) and bool(target_animal.get("meat_available", false)), "hunting a herbivore creates a server-owned carcass")
	if _failures > 0:
		return

	players = _server_node.get("_players")
	state_a = players[peer_a]
	state_a["x"] = 102.0
	state_a["z"] = 0.0
	state_a["hunger"] = 30.0
	state_a["thirst"] = 100.0
	state_a["last_input_ms"] = Time.get_ticks_msec()
	players[peer_a] = state_a
	_server_node.set("_players", players)
	var meat_result: Dictionary = _server_node.call("_handle_message", peer_a, {"type": "interact"})
	var meat_player: Dictionary = meat_result.get("player", {})
	wildlife = _server_node.get("_wildlife")
	target_animal = wildlife[target_wildlife_id]
	_expect(bool(meat_result.get("ok", false)) and String(meat_result.get("code", "")) == "ate_meat", "player can eat a hunted carcass within interaction range")
	_expect(float(meat_player.get("hunger", 0.0)) > 30.0 and not bool(target_animal.get("meat_available", true)), "carcass consumption restores hunger and makes the meat unavailable")
	if _failures > 0:
		return
	target_animal["respawn_remaining"] = 0.1
	target_animal["is_dead"] = true
	wildlife[target_wildlife_id] = target_animal
	_server_node.set("_wildlife", wildlife)
	_server_node.call("_simulate_wildlife", 0.2)
	wildlife = _server_node.get("_wildlife")
	target_animal = wildlife[target_wildlife_id]
	_expect(not bool(target_animal.get("is_dead", true)) and absf(float(target_animal.get("health", 0.0)) - 100.0) < 0.01 and not bool(target_animal.get("meat_available", true)), "hunted wildlife respawns with restored health after its timer")


func _run_protocol_cases() -> void:
	var valid_packet: PackedByteArray = Protocol.encode_message({"type": "ping"})
	var valid_result: Dictionary = Protocol.decode_message(valid_packet)
	_expect(bool(valid_result.get("ok", false)), "valid JSON object is accepted")
	var invalid_json: Dictionary = Protocol.decode_message("{".to_utf8_buffer())
	_expect(not bool(invalid_json.get("ok", true)), "malformed JSON is rejected")
	var non_object: Dictionary = Protocol.decode_message("[]".to_utf8_buffer())
	_expect(not bool(non_object.get("ok", true)), "non-object JSON is rejected")
	var missing_type: Dictionary = Protocol.decode_message(Protocol.encode_message({"payload": 1}))
	_expect(not bool(missing_type.get("ok", true)), "messages without a type are rejected")
	var invalid_type: Dictionary = Protocol.decode_message(Protocol.encode_message({"type": 7}))
	_expect(not bool(invalid_type.get("ok", true)), "non-string message types are rejected")
	var oversized := PackedByteArray()
	oversized.resize(Protocol.MAX_PACKET_BYTES + 1)
	var oversized_result: Dictionary = Protocol.decode_message(oversized)
	_expect(not bool(oversized_result.get("ok", true)), "oversized messages are rejected")


func _get_client(label: String) -> Node:
	return _client_a if label == "A" else _client_b


func _on_client_state_changed(state: String, detail: String, label: String) -> void:
	print("ONLINE CLIENT %s TEST STATE: %s — %s" % [label, state, detail])
	if state == "connected" and not bool(_join_requested.get(label, false)):
		_join_requested[label] = true
		var join_result: int = int(_get_client(label).call("join_session"))
		if join_result != OK:
			_fail("client %s could not request a server-owned player session" % label)
	elif state == "error":
		_fail("online client %s reported error: %s" % [label, detail])


func _on_client_message_received(message: Dictionary, label: String) -> void:
	var message_type: String = String(message.get("type", ""))
	if message_type == "session_joined":
		_seen_session[label] = true
		var player_state: Dictionary = message.get("player", {})
		if label == "A":
			_first_player_id = String(player_state.get("player_id", ""))
			_move_started_ms = Time.get_ticks_msec()
			var move_result: int = int(_client_a.call("send_move_input", Vector2(1.0, 0.0), false))
			if move_result != OK:
				_fail("client A could not send validated movement intent")
		else:
			_second_player_id = String(player_state.get("player_id", ""))
	elif message_type == "world_snapshot":
		var players: Array = message.get("players", [])
		if players.size() >= 2:
			_saw_two_players = true
		for state_variant in players:
			if not state_variant is Dictionary:
				continue
			var player_state: Dictionary = state_variant
			if String(player_state.get("player_id", "")) == _first_player_id:
				_max_first_player_x = maxf(_max_first_player_x, float(player_state.get("x", 0.0)))
				if _max_first_player_x > 0.5:
					_saw_server_movement = true


func _on_process_frame() -> void:
	if _failures > 0:
		return
	if _move_started_ms >= 0 and not _move_stop_sent and Time.get_ticks_msec() - _move_started_ms >= 450:
		_move_stop_sent = true
		var stop_result: int = int(_client_a.call("send_move_input", Vector2.ZERO, false))
		if stop_result != OK:
			_fail("client A could not send stop movement intent")
			return

	if bool(_seen_session.get("A", false)) and bool(_seen_session.get("B", false)) and _saw_two_players and _saw_server_movement and _move_stop_sent:
		if not _sprint_regression_checked:
			_sprint_regression_checked = true
			_run_sprint_exhaustion_regression()
			if _failures > 0:
				return
		if not _gameplay_regressions_checked:
			_gameplay_regressions_checked = true
			_run_server_gameplay_regressions()
			if _failures > 0:
				return
		print("ONLINE SESSION TEST PASSED: persistence, two clients, movement, sprint, survival actions, PvP, hunting, carcass consumption and wildlife respawn.")
		_finish(true)
	elif _deadline_ms > 0 and Time.get_ticks_msec() > _deadline_ms:
		_fail("timed out waiting for two sessions and server-authoritative movement; A=%s B=%s two_players=%s max_x=%.3f" % [
			str(_seen_session["A"]), str(_seen_session["B"]), str(_saw_two_players), _max_first_player_x
		])


func _run_sprint_exhaustion_regression() -> void:
	var players: Dictionary = _server_node.get("_players")
	var selected_peer_id: int = -1
	for peer_id_variant in players.keys():
		var state: Dictionary = players[peer_id_variant]
		if String(state.get("player_id", "")) == _first_player_id:
			selected_peer_id = int(peer_id_variant)
			break
	if selected_peer_id < 0:
		_fail("could not locate first server-owned player for sprint regression")
		return

	var player_state: Dictionary = players[selected_peer_id]
	player_state["input_x"] = 1.0
	player_state["input_z"] = 0.0
	player_state["sprint_requested"] = true
	player_state["sprint_exhausted"] = true
	player_state["stamina"] = 20.0
	player_state["last_input_ms"] = Time.get_ticks_msec()
	players[selected_peer_id] = player_state
	_server_node.set("_players", players)
	_server_node.call("_simulate_players", 0.1)

	players = _server_node.get("_players")
	player_state = players[selected_peer_id]
	_expect(not bool(player_state.get("is_sprinting", true)), "sprint stays disabled while held after exhaustion")
	_expect(float(player_state.get("stamina", 0.0)) > 20.0, "stamina recovers while exhausted without restarting sprint")

	player_state["sprint_requested"] = false
	player_state["last_input_ms"] = Time.get_ticks_msec()
	players[selected_peer_id] = player_state
	_server_node.set("_players", players)
	_server_node.call("_simulate_players", 0.1)
	players = _server_node.get("_players")
	player_state = players[selected_peer_id]
	_expect(not bool(player_state.get("sprint_exhausted", true)), "releasing sprint resets exhaustion state")


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		_fail("FAIL: %s" % label)


func _fail(message: String) -> void:
	_failures += 1
	push_error(message)
	_finish(false)


func _finish(success: bool) -> void:
	for client_node in [_client_a, _client_b]:
		if is_instance_valid(client_node):
			client_node.call("disconnect_from_server")
			client_node.queue_free()
	if is_instance_valid(_server_node):
		_server_node.call("stop_server")
		_server_node.queue_free()
	quit(0 if success else 1)
