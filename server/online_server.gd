extends Node

const Protocol = preload("res://scripts/online_protocol.gd")
const CharacterStoreScript = preload("res://server/character_store.gd")
const TerrainAuthorityScript = preload("res://scripts/world_terrain.gd")
const MAX_CLIENTS: int = 32
const DEFAULT_PORT: int = 9080
const DEFAULT_BIND_ADDRESS: String = "127.0.0.1"
const WORLD_HALF_SIZE: float = 2250.0
const MAX_GROUND_STEP_PER_TICK: float = 0.85
const BASE_MOVE_SPEED: float = 4.5
const SPRINT_MULTIPLIER: float = 1.65
const STAMINA_DRAIN_PER_SECOND: float = 14.0
const STAMINA_RECOVERY_PER_SECOND: float = 12.0
const HUNGER_DRAIN_PER_SECOND: float = 0.025
const THIRST_DRAIN_PER_SECOND: float = 0.04
const SNAPSHOT_INTERVAL_SECONDS: float = 0.1
const INPUT_TIMEOUT_MS: int = 350
const SAVE_INTERVAL_SECONDS: float = 5.0
const INITIAL_WILDLIFE_COUNT: int = 10
const WILDLIFE_WORLD_LIMIT: float = 2240.0
const WILDLIFE_NOTICE_DISTANCE: float = 8.5
const WILDLIFE_WALK_SPEED: float = 1.7
const WILDLIFE_FLEE_SPEED: float = 4.0
const WILDLIFE_ROAM_RADIUS: float = 85.0
const WILDLIFE_RESPAWN_SECONDS: float = 90.0
const WILDLIFE_ATTACK_DAMAGE: float = 25.0
const ATTACK_RANGE: float = 3.25
const ATTACK_DAMAGE: float = 25.0
const ATTACK_COOLDOWN_MS: int = 850
const FOOD_USE_DISTANCE: float = 4.75
const FOOD_RESPAWN_MS: int = 45000
const FOOD_POINTS: Array[Vector2] = [
	Vector2(-8.0, 4.0),
	Vector2(34.0, -40.0),
	Vector2(-52.0, -26.0),
	Vector2(54.0, 38.0),
	Vector2(-22.0, 63.0),
	Vector2(64.0, -59.0)
]
const WATER_CENTER: Vector2 = Vector2(15.0, 15.0)
const WATER_RADII: Vector2 = Vector2(26.0, 21.0)

var _server_peer: WebSocketMultiplayerPeer
var _peer_state: Dictionary = {}
var _players: Dictionary = {}
var _snapshot_timer: float = 0.0
var _save_timer: float = 0.0
var _food_respawn_at_ms: Dictionary = {}
var _wildlife: Dictionary = {}
var _wildlife_rng := RandomNumberGenerator.new()
var _wildlife_next_id: int = 1
var _character_store: RefCounted
var _terrain_authority: RefCounted
var _data_directory: String = "user://primalis_server/characters"


func _ready() -> void:
	set_process(true)


func configure_data_directory(path: String) -> void:
	if _server_peer != null:
		push_warning("Cannot change the character store directory while the server is running.")
		return
	if not path.strip_edges().is_empty():
		_data_directory = path.strip_edges()


func start_server(port: int = DEFAULT_PORT, bind_address: String = DEFAULT_BIND_ADDRESS) -> int:
	if _server_peer != null:
		push_error("Primalis Online server is already running.")
		return ERR_ALREADY_IN_USE
	if port < 1 or port > 65535 or bind_address.strip_edges().is_empty():
		push_error("Invalid server endpoint. Port must be 1-65535 and bind address cannot be empty.")
		return ERR_INVALID_PARAMETER

	_character_store = CharacterStoreScript.new() as RefCounted
	if _character_store == null or not bool(_character_store.call("initialize", _data_directory)):
		push_error("Could not initialize persistent server-side character storage.")
		_character_store = null
		return ERR_CANT_OPEN
	_terrain_authority = TerrainAuthorityScript.new() as RefCounted
	if _terrain_authority == null:
		push_error("Could not initialize shared island terrain authority.")
		return ERR_CANT_OPEN

	var candidate := WebSocketMultiplayerPeer.new()
	candidate.max_queued_packets = 128
	var result: int = candidate.create_server(port, bind_address)
	if result != OK:
		push_error("Could not start Primalis Online WebSocket server (error %d) on %s:%d." % [result, bind_address, port])
		return result

	_server_peer = candidate
	_peer_state.clear()
	_wildlife_rng.randomize()
	_initialize_wildlife()
	print("PRIMALIS_SERVER_READY host=%s port=%d protocol=%d max_clients=%d" % [
		bind_address, port, Protocol.PROTOCOL_VERSION, MAX_CLIENTS
	])
	return OK


func stop_server() -> void:
	_save_all_players()
	_peer_state.clear()
	_players.clear()
	_wildlife.clear()
	_wildlife_next_id = 1
	_server_peer = null
	print("PRIMALIS_SERVER_STOPPED")


func _process(_delta: float) -> void:
	if _server_peer == null:
		return

	_server_peer.poll()
	var safe_delta: float = minf(maxf(_delta, 0.0), 0.1)
	_simulate_players(safe_delta)
	_simulate_wildlife(safe_delta)
	_snapshot_timer += safe_delta
	if _snapshot_timer >= SNAPSHOT_INTERVAL_SECONDS:
		_snapshot_timer = 0.0
		_broadcast_world_snapshot()
	_save_timer += safe_delta
	if _save_timer >= SAVE_INTERVAL_SECONDS:
		_save_timer = 0.0
		_save_all_players()

	# WebSocketMultiplayerPeer exposes incoming packets through a central queue.
	# The first application packet registers the peer; no unsupported peer-list API
	# is needed, and disconnected peer objects are pruned below.
	var packets_pending: int = _server_peer.get_available_packet_count()
	while packets_pending > 0:
		packets_pending -= 1
		var peer_id: int = _server_peer.get_packet_peer()
		var packet: PackedByteArray = _server_peer.get_packet()

		if not _peer_state.has(peer_id):
			if _peer_state.size() >= MAX_CLIENTS:
				_close_peer(peer_id, 1008, "server_full")
				continue
			_peer_state[peer_id] = {
				"window_start_ms": Time.get_ticks_msec(),
				"message_count": 0,
				"handshake_complete": false
			}
			print("PRIMALIS_CLIENT_CONNECTED id=%d" % peer_id)

		if packet.size() > Protocol.MAX_PACKET_BYTES:
			_close_peer(peer_id, 1009, "packet_too_large")
			continue
		if not _allow_message(peer_id):
			_close_peer(peer_id, 1008, "rate_limit")
			continue

		var decoded: Dictionary = Protocol.decode_message(packet)
		if not bool(decoded.get("ok", false)):
			_close_peer(peer_id, 1007, String(decoded.get("error", "invalid_message")))
			continue

		var message: Dictionary = decoded.get("message", {})
		var response: Dictionary = _handle_message(peer_id, message)
		if not response.is_empty():
			_send_message(peer_id, response)

	for peer_id_variant in _peer_state.keys():
		var known_peer_id: int = int(peer_id_variant)
		var socket: WebSocketPeer = _server_peer.get_peer(known_peer_id)
		if socket == null or socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			_peer_state.erase(known_peer_id)
			if _players.has(known_peer_id):
				_save_player_state(known_peer_id)
				print("PRIMALIS_PLAYER_DISCONNECTED id=%s" % String(_players[known_peer_id].get("player_id", known_peer_id)))
				_players.erase(known_peer_id)


func _handle_message(peer_id: int, message: Dictionary) -> Dictionary:
	var message_type: String = String(message.get("type", ""))
	var state: Dictionary = _peer_state.get(peer_id, {})

	match message_type:
		"client_hello":
			var client_version: Variant = message.get("protocol_version", null)
			var version_type: int = typeof(client_version)
			# JSON decoding may represent integer-looking numbers as floats.
			# Accept only numeric values exactly equal to this protocol version.
			if (version_type != TYPE_INT and version_type != TYPE_FLOAT) or float(client_version) != float(Protocol.PROTOCOL_VERSION):
				return {
					"type": "error",
					"code": "protocol_mismatch",
					"server_protocol_version": Protocol.PROTOCOL_VERSION
				}
			state["handshake_complete"] = true
			_peer_state[peer_id] = state
			return {
				"type": "welcome",
				"protocol_version": Protocol.PROTOCOL_VERSION,
				"server_name": "Primalis Online",
				"stage": "survival_foundation"
			}
		"session_join":
			if not bool(state.get("handshake_complete", false)):
				return {"type": "error", "code": "handshake_required"}
			if _players.has(peer_id):
				return {
					"type": "session_joined",
					"player": _public_player_state(peer_id),
					"players": _public_player_list(),
					"wildlife": _public_wildlife_list()
				}
			if _players.size() >= MAX_CLIENTS:
				return {"type": "error", "code": "world_full"}
			var token_value: Variant = message.get("identity_token", null)
			if typeof(token_value) != TYPE_STRING or not _is_valid_identity_token(String(token_value)):
				return {"type": "error", "code": "invalid_identity_token"}
			var identity_hash: String = String(token_value).to_lower().sha256_text()
			for existing_peer_variant in _players.keys():
				var existing_peer_id: int = int(existing_peer_variant)
				if String(_players[existing_peer_id].get("identity_hash", "")) == identity_hash:
					return {"type": "error", "code": "character_already_online"}
			if _character_store == null:
				return {"type": "error", "code": "storage_unavailable"}
			var saved_value: Variant = _character_store.call("load_character", identity_hash)
			var saved_character: Dictionary = saved_value if typeof(saved_value) == TYPE_DICTIONARY else {}
			var stable_id: String = "player-" + identity_hash.substr(0, 12)
			var display_name: String = "Viajero-" + identity_hash.substr(0, 4).to_upper()
			_players[peer_id] = {
				"identity_hash": identity_hash,
				"player_id": stable_id,
				"display_name": display_name,
				"x": float(saved_character.get("x", 0.0)),
				"z": float(saved_character.get("z", 0.0)),
				"yaw": float(saved_character.get("yaw", 0.0)),
				"input_x": 0.0,
				"input_z": 0.0,
				"sprint_requested": false,
				"sprint_exhausted": false,
				"is_sprinting": false,
				"is_moving": false,
				"last_input_ms": Time.get_ticks_msec(),
				"last_attack_ms": 0,
				"is_respawning": false,
				"respawn_remaining": 0.0,
				"health": float(saved_character.get("health", 100.0)),
				"hunger": float(saved_character.get("hunger", 100.0)),
				"thirst": float(saved_character.get("thirst", 100.0)),
				"stamina": float(saved_character.get("stamina", 100.0)),
				"kills": int(saved_character.get("kills", 0))
			}
			state["session_joined"] = true
			state["identity_hash"] = identity_hash
			_peer_state[peer_id] = state
			_save_player_state(peer_id)
			print("PRIMALIS_PLAYER_JOINED id=%s" % String(_players[peer_id]["player_id"]))
			return {
				"type": "session_joined",
				"player": _public_player_state(peer_id),
				"players": _public_player_list(),
				"wildlife": _public_wildlife_list()
			}
		"interact":
			if not bool(state.get("handshake_complete", false)) or not _players.has(peer_id):
				return {"type": "error", "code": "session_required"}
			return _handle_interact(peer_id)
		"attack":
			if not bool(state.get("handshake_complete", false)) or not _players.has(peer_id):
				return {"type": "error", "code": "session_required"}
			return _handle_attack(peer_id)
		"move_input":
			if not bool(state.get("handshake_complete", false)) or not _players.has(peer_id):
				return {"type": "error", "code": "session_required"}
			var x_value: Variant = message.get("x", null)
			var z_value: Variant = message.get("z", null)
			var sprint_value: Variant = message.get("sprint", false)
			if not _is_finite_number(x_value) or not _is_finite_number(z_value) or typeof(sprint_value) != TYPE_BOOL:
				return {"type": "error", "code": "invalid_move_input"}
			var input_x: float = clampf(float(x_value), -1.0, 1.0)
			var input_z: float = clampf(float(z_value), -1.0, 1.0)
			var input_length: float = Vector2(input_x, input_z).length()
			if input_length > 1.0:
				input_x /= input_length
				input_z /= input_length
			var player_state: Dictionary = _players[peer_id]
			player_state["input_x"] = input_x
			player_state["input_z"] = input_z
			player_state["sprint_requested"] = sprint_value
			player_state["last_input_ms"] = Time.get_ticks_msec()
			_players[peer_id] = player_state
			return {}
		"ping":
			if not bool(state.get("handshake_complete", false)):
				return {"type": "error", "code": "handshake_required"}
			return {"type": "pong", "server_time_ms": Time.get_ticks_msec()}
		_:
			return {"type": "error", "code": "unknown_message"}


func _allow_message(peer_id: int) -> bool:
	var now_ms: int = Time.get_ticks_msec()
	var state: Dictionary = _peer_state.get(peer_id, {})
	var window_start: int = int(state.get("window_start_ms", now_ms))
	var message_count: int = int(state.get("message_count", 0))

	if now_ms - window_start >= 1000:
		window_start = now_ms
		message_count = 0
	message_count += 1
	state["window_start_ms"] = window_start
	state["message_count"] = message_count
	_peer_state[peer_id] = state
	return message_count <= Protocol.MAX_MESSAGES_PER_SECOND


func _send_message(peer_id: int, message: Dictionary) -> void:
	if _server_peer == null:
		return
	var socket: WebSocketPeer = _server_peer.get_peer(peer_id)
	if socket == null or socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		return
	_server_peer.set_target_peer(peer_id)
	var result: int = _server_peer.put_packet(Protocol.encode_message(message))
	_server_peer.set_target_peer(0)
	if result != OK:
		push_warning("Could not send protocol message to peer %d (error %d)." % [peer_id, result])


func _close_peer(peer_id: int, code: int, reason: String) -> void:
	if _server_peer == null:
		return
	var socket: WebSocketPeer = _server_peer.get_peer(peer_id)
	if socket != null:
		socket.close(code, reason)
		_server_peer.disconnect_peer(peer_id, true)
	_peer_state.erase(peer_id)


func _simulate_players(delta: float) -> void:
	if delta <= 0.0:
		return
	var now_ms: int = Time.get_ticks_msec()
	for peer_id_variant in _players.keys():
		var peer_id: int = int(peer_id_variant)
		var player_state: Dictionary = _players[peer_id]
		var health: float = float(player_state.get("health", 100.0))

		if health <= 0.0:
			if not bool(player_state.get("is_respawning", false)):
				player_state["is_respawning"] = true
				player_state["respawn_remaining"] = 3.0
				player_state["input_x"] = 0.0
				player_state["input_z"] = 0.0
				player_state["sprint_requested"] = false
				player_state["sprint_exhausted"] = false
				player_state["is_moving"] = false
				player_state["is_sprinting"] = false
			else:
				var remaining: float = maxf(0.0, float(player_state.get("respawn_remaining", 0.0)) - delta)
				player_state["respawn_remaining"] = remaining
				if remaining <= 0.0:
					player_state["x"] = 0.0
					player_state["z"] = 0.0
					player_state["yaw"] = 0.0
					player_state["health"] = 100.0
					player_state["hunger"] = 65.0
					player_state["thirst"] = 65.0
					player_state["stamina"] = 100.0
					player_state["sprint_exhausted"] = false
					player_state["respawn_remaining"] = 0.0
					player_state["is_respawning"] = false
			_players[peer_id] = player_state
			continue

		# Missing movement packets must never leave a dinosaur walking indefinitely.
		if now_ms - int(player_state.get("last_input_ms", now_ms)) > INPUT_TIMEOUT_MS:
			player_state["input_x"] = 0.0
			player_state["input_z"] = 0.0
			player_state["sprint_requested"] = false

		var input_x: float = float(player_state.get("input_x", 0.0))
		var input_z: float = float(player_state.get("input_z", 0.0))
		var input_direction := Vector2(input_x, input_z)
		var moving: bool = input_direction.length_squared() > 0.0001
		var sprint_requested: bool = bool(player_state.get("sprint_requested", false))
		var sprint_exhausted: bool = bool(player_state.get("sprint_exhausted", false))
		var stamina: float = float(player_state.get("stamina", 100.0))
		if not sprint_requested:
			sprint_exhausted = false
		var is_sprinting: bool = moving and sprint_requested and not sprint_exhausted and stamina > 0.0
		if moving:
			var current_position := Vector2(float(player_state.get("x", 0.0)), float(player_state.get("z", 0.0)))
			var intended_speed: float = BASE_MOVE_SPEED * (SPRINT_MULTIPLIER if is_sprinting else 1.0)
			var intended_position: Vector2 = current_position + input_direction.normalized() * intended_speed * delta
			intended_position.x = clampf(intended_position.x, -WORLD_HALF_SIZE, WORLD_HALF_SIZE)
			intended_position.y = clampf(intended_position.y, -WORLD_HALF_SIZE, WORLD_HALF_SIZE)
			if not _can_traverse_step(current_position, intended_position):
				moving = false
				input_direction = Vector2.ZERO
				sprint_requested = false
				sprint_exhausted = false
				is_sprinting = false
				player_state["input_x"] = 0.0
				player_state["input_z"] = 0.0
				player_state["sprint_requested"] = false

		if is_sprinting:
			stamina = maxf(0.0, stamina - STAMINA_DRAIN_PER_SECOND * delta)
			if stamina <= 0.0:
				sprint_exhausted = true
		else:
			stamina = minf(100.0, stamina + STAMINA_RECOVERY_PER_SECOND * delta)

		if moving:
			var direction := input_direction.normalized()
			var speed: float = BASE_MOVE_SPEED * (SPRINT_MULTIPLIER if is_sprinting else 1.0)
			player_state["x"] = clampf(float(player_state.get("x", 0.0)) + direction.x * speed * delta, -WORLD_HALF_SIZE, WORLD_HALF_SIZE)
			player_state["z"] = clampf(float(player_state.get("z", 0.0)) + direction.y * speed * delta, -WORLD_HALF_SIZE, WORLD_HALF_SIZE)
			player_state["yaw"] = atan2(-direction.x, -direction.y)

		player_state["is_moving"] = moving
		player_state["sprint_exhausted"] = sprint_exhausted
		player_state["stamina"] = stamina
		player_state["is_sprinting"] = is_sprinting
		player_state["hunger"] = maxf(0.0, float(player_state.get("hunger", 100.0)) - HUNGER_DRAIN_PER_SECOND * delta)
		player_state["thirst"] = maxf(0.0, float(player_state.get("thirst", 100.0)) - THIRST_DRAIN_PER_SECOND * delta)
		if float(player_state["hunger"]) <= 0.0 or float(player_state["thirst"]) <= 0.0:
			player_state["health"] = maxf(0.0, float(player_state.get("health", 100.0)) - 1.5 * delta)
		_players[peer_id] = player_state


func _broadcast_world_snapshot() -> void:
	if _server_peer == null or _players.is_empty():
		return
	var message := {
		"type": "world_snapshot",
		"server_time_ms": Time.get_ticks_msec(),
		"players": _public_player_list(),
		"wildlife": _public_wildlife_list()
	}
	for peer_id_variant in _peer_state.keys():
		var peer_id: int = int(peer_id_variant)
		var state: Dictionary = _peer_state[peer_id]
		if bool(state.get("handshake_complete", false)) and bool(state.get("session_joined", false)):
			_send_message(peer_id, message)


func _public_player_list() -> Array[Dictionary]:
	var public_players: Array[Dictionary] = []
	for peer_id_variant in _players.keys():
		public_players.append(_public_player_state(int(peer_id_variant)))
	return public_players


func _public_wildlife_list() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for wildlife_id_variant in _wildlife.keys():
		var wildlife_state: Dictionary = _wildlife[wildlife_id_variant]
		result.append({
			"wildlife_id": String(wildlife_id_variant),
			"species_id": int(wildlife_state.get("species_id", 0)),
			"x": float(wildlife_state.get("x", 0.0)),
			"z": float(wildlife_state.get("z", 0.0)),
			"yaw": float(wildlife_state.get("yaw", 0.0)),
			"health": float(wildlife_state.get("health", 100.0)),
			"max_health": float(wildlife_state.get("max_health", 100.0)),
			"is_dead": bool(wildlife_state.get("is_dead", false)),
			"is_moving": bool(wildlife_state.get("is_moving", false)),
			"meat_available": bool(wildlife_state.get("meat_available", false)),
			"respawn_remaining": float(wildlife_state.get("respawn_remaining", 0.0))
		})
	return result


func _public_player_state(peer_id: int) -> Dictionary:
	if not _players.has(peer_id):
		return {}
	var source: Dictionary = _players[peer_id]
	return {
		"player_id": String(source.get("player_id", "")),
		"display_name": String(source.get("display_name", "Viajero")),
		"x": float(source.get("x", 0.0)),
		"z": float(source.get("z", 0.0)),
		"yaw": float(source.get("yaw", 0.0)),
		"is_sprinting": bool(source.get("is_sprinting", false)),
		"is_moving": bool(source.get("is_moving", false)),
		"is_respawning": bool(source.get("is_respawning", false)),
		"respawn_remaining": float(source.get("respawn_remaining", 0.0)),
		"health": float(source.get("health", 100.0)),
		"hunger": float(source.get("hunger", 100.0)),
		"thirst": float(source.get("thirst", 100.0)),
		"stamina": float(source.get("stamina", 100.0)),
		"kills": int(source.get("kills", 0))
	}


func _handle_interact(peer_id: int) -> Dictionary:
	var player_state: Dictionary = _players.get(peer_id, {})
	if player_state.is_empty() or bool(player_state.get("is_respawning", false)) or float(player_state.get("health", 0.0)) <= 0.0:
		return _action_result(peer_id, "interact", false, "respawning")
	var position := Vector2(float(player_state.get("x", 0.0)), float(player_state.get("z", 0.0)))
	var thirst: float = float(player_state.get("thirst", 100.0))
	if _is_near_water(position) and thirst < 99.0:
		player_state["thirst"] = minf(100.0, thirst + 42.0)
		_players[peer_id] = player_state
		_save_player_state(peer_id)
		return _action_result(peer_id, "interact", true, "drank_water")

	var nearest_carcass_id: String = ""
	var nearest_carcass_distance: float = FOOD_USE_DISTANCE
	for wildlife_id_variant in _wildlife.keys():
		var wildlife_id: String = String(wildlife_id_variant)
		var wildlife_state: Dictionary = _wildlife[wildlife_id]
		if not bool(wildlife_state.get("is_dead", false)) or not bool(wildlife_state.get("meat_available", false)):
			continue
		var wildlife_position := Vector2(float(wildlife_state.get("x", 0.0)), float(wildlife_state.get("z", 0.0)))
		var carcass_distance: float = position.distance_to(wildlife_position)
		if carcass_distance <= nearest_carcass_distance:
			nearest_carcass_distance = carcass_distance
			nearest_carcass_id = wildlife_id
	if not nearest_carcass_id.is_empty():
		var carcass_hunger: float = float(player_state.get("hunger", 100.0))
		if carcass_hunger >= 99.0:
			return _action_result(peer_id, "interact", false, "not_hungry")
		player_state["hunger"] = minf(100.0, carcass_hunger + 45.0)
		_players[peer_id] = player_state
		var carcass_state: Dictionary = _wildlife[nearest_carcass_id]
		carcass_state["meat_available"] = false
		_wildlife[nearest_carcass_id] = carcass_state
		_save_player_state(peer_id)
		return _action_result(peer_id, "interact", true, "ate_meat")

	var nearest_plant_id: String = ""
	var nearest_distance: float = FOOD_USE_DISTANCE
	for index in range(FOOD_POINTS.size()):
		var plant_id: String = "plant_%d" % index
		var distance: float = position.distance_to(FOOD_POINTS[index])
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_plant_id = plant_id
	if nearest_plant_id.is_empty():
		return _action_result(peer_id, "interact", false, "nothing_nearby")
	if int(_food_respawn_at_ms.get(nearest_plant_id, 0)) > Time.get_ticks_msec():
		return _action_result(peer_id, "interact", false, "plant_regrowing")
	var hunger: float = float(player_state.get("hunger", 100.0))
	if hunger >= 99.0:
		return _action_result(peer_id, "interact", false, "not_hungry")
	player_state["hunger"] = minf(100.0, hunger + 35.0)
	_players[peer_id] = player_state
	_food_respawn_at_ms[nearest_plant_id] = Time.get_ticks_msec() + FOOD_RESPAWN_MS
	_save_player_state(peer_id)
	return _action_result(peer_id, "interact", true, "ate_plant")


func _handle_attack(peer_id: int) -> Dictionary:
	var attacker: Dictionary = _players.get(peer_id, {})
	if attacker.is_empty() or bool(attacker.get("is_respawning", false)) or float(attacker.get("health", 0.0)) <= 0.0:
		return _action_result(peer_id, "attack", false, "respawning")
	var now_ms: int = Time.get_ticks_msec()
	var last_attack_ms: int = int(attacker.get("last_attack_ms", 0))
	if last_attack_ms > 0 and now_ms - last_attack_ms < ATTACK_COOLDOWN_MS:
		return _action_result(peer_id, "attack", false, "attack_cooldown")
	attacker["last_attack_ms"] = now_ms
	var attacker_position := Vector2(float(attacker.get("x", 0.0)), float(attacker.get("z", 0.0)))
	var yaw: float = float(attacker.get("yaw", 0.0))
	var forward := Vector2(-sin(yaw), -cos(yaw))
	var target_peer_id: int = -1
	var target_wildlife_id: String = ""
	var target_kind: String = ""
	var closest_distance: float = ATTACK_RANGE

	for target_peer_variant in _players.keys():
		var candidate_peer_id: int = int(target_peer_variant)
		if candidate_peer_id == peer_id:
			continue
		var target: Dictionary = _players[candidate_peer_id]
		if bool(target.get("is_respawning", false)) or float(target.get("health", 0.0)) <= 0.0:
			continue
		var target_position := Vector2(float(target.get("x", 0.0)), float(target.get("z", 0.0)))
		var offset: Vector2 = target_position - attacker_position
		var distance: float = offset.length()
		if distance > closest_distance or (distance > 0.1 and forward.dot(offset / distance) < 0.15):
			continue
		target_peer_id = candidate_peer_id
		target_wildlife_id = ""
		target_kind = "player"
		closest_distance = distance

	for wildlife_id_variant in _wildlife.keys():
		var wildlife_id: String = String(wildlife_id_variant)
		var animal: Dictionary = _wildlife[wildlife_id]
		if bool(animal.get("is_dead", false)) or float(animal.get("health", 0.0)) <= 0.0:
			continue
		var animal_position := Vector2(float(animal.get("x", 0.0)), float(animal.get("z", 0.0)))
		var animal_offset: Vector2 = animal_position - attacker_position
		var animal_distance: float = animal_offset.length()
		if animal_distance > closest_distance or (animal_distance > 0.1 and forward.dot(animal_offset / animal_distance) < 0.15):
			continue
		target_peer_id = -1
		target_wildlife_id = wildlife_id
		target_kind = "wildlife"
		closest_distance = animal_distance

	if target_kind.is_empty():
		_players[peer_id] = attacker
		_save_player_state(peer_id)
		return _action_result(peer_id, "attack", false, "no_target")

	if target_kind == "wildlife":
		var animal: Dictionary = _wildlife[target_wildlife_id]
		var previous_animal_health: float = float(animal.get("health", 100.0))
		var new_animal_health: float = maxf(0.0, previous_animal_health - WILDLIFE_ATTACK_DAMAGE)
		animal["health"] = new_animal_health
		if new_animal_health <= 0.0:
			animal["is_dead"] = true
			animal["is_moving"] = false
			animal["meat_available"] = true
			animal["respawn_remaining"] = WILDLIFE_RESPAWN_SECONDS
			animal["flee_timer"] = 0.0
			if previous_animal_health > 0.0:
				attacker["kills"] = int(attacker.get("kills", 0)) + 1
		else:
			var escape := Vector2(float(animal.get("x", 0.0)), float(animal.get("z", 0.0))) - attacker_position
			if escape.length_squared() < 0.01:
				escape = Vector2(_wildlife_rng.randf_range(-1.0, 1.0), _wildlife_rng.randf_range(-1.0, 1.0))
			escape = escape.normalized()
			animal["flee_x"] = escape.x
			animal["flee_z"] = escape.y
			animal["flee_timer"] = 2.4
		_wildlife[target_wildlife_id] = animal
		_players[peer_id] = attacker
		_save_player_state(peer_id)
		return _action_result(peer_id, "attack", true, "wildlife_killed" if new_animal_health <= 0.0 else "wildlife_hit")

	var target_state: Dictionary = _players[target_peer_id]
	var previous_health: float = float(target_state.get("health", 100.0))
	var new_health: float = maxf(0.0, previous_health - ATTACK_DAMAGE)
	target_state["health"] = new_health
	_players[target_peer_id] = target_state
	if previous_health > 0.0 and new_health <= 0.0:
		attacker["kills"] = int(attacker.get("kills", 0)) + 1
	_players[peer_id] = attacker
	_save_player_state(target_peer_id)
	_save_player_state(peer_id)
	_send_message(target_peer_id, _action_result(target_peer_id, "damaged", true, "player_hit"))
	return _action_result(peer_id, "attack", true, "player_hit")


func _action_result(peer_id: int, action: String, succeeded: bool, code: String) -> Dictionary:
	var messages := {
		"respawning": "No puedes realizar acciones mientras reapareces.",
		"not_thirsty": "No tienes sed.",
		"drank_water": "Has bebido agua.",
		"nothing_nearby": "Acércate a una planta o al agua para interactuar.",
		"plant_regrowing": "Esta planta todavía está creciendo.",
		"not_hungry": "No tienes hambre.",
		"ate_plant": "Has comido plantas y recuperado hambre.",
		"attack_cooldown": "Espera un momento antes de volver a morder.",
		"no_target": "No hay otro dinosaurio al alcance y frente a ti.",
		"wildlife_hit": "Has mordido a un herbívoro. ¡Cuidado, ahora huye!",
		"wildlife_killed": "Cacería exitosa. El cadáver se puede comer mientras tenga carne.",
		"ate_meat": "Has comido carne y recuperado hambre.",
		"player_hit": "Has recibido una mordida: -25 de salud."
	}
	var message_text: String = String(messages.get(code, "Acción completada." if succeeded else "No se pudo completar la acción."))
	if code == "player_hit" and action == "attack":
		message_text = "Mordida acertada: el objetivo perdió 25 de salud."
	return {
		"type": "action_result",
		"action": action,
		"ok": succeeded,
		"code": code,
		"message": message_text,
		"player": _public_player_state(peer_id)
	}


func _initialize_wildlife() -> void:
	_wildlife.clear()
	_wildlife_next_id = 1
	for index in range(INITIAL_WILDLIFE_COUNT):
		var angle: float = _wildlife_rng.randf_range(0.0, TAU)
		var radius: float = _wildlife_rng.randf_range(65.0, 230.0)
		var spawn_position := Vector2(cos(angle), sin(angle)) * radius
		var wildlife_id := "herbivore-%03d" % _wildlife_next_id
		_wildlife_next_id += 1
		var animal := {
			"species_id": index % 5,
			"x": spawn_position.x,
			"z": spawn_position.y,
			"yaw": _wildlife_rng.randf_range(-PI, PI),
			"home_x": spawn_position.x,
			"home_z": spawn_position.y,
			"destination_x": spawn_position.x,
			"destination_z": spawn_position.y,
			"decision_timer": 0.0,
			"flee_timer": 0.0,
			"flee_x": 0.0,
			"flee_z": 0.0,
			"health": 100.0,
			"max_health": 100.0,
			"is_dead": false,
			"is_moving": false,
			"meat_available": false,
			"respawn_remaining": 0.0
		}
		_pick_wildlife_destination(animal)
		_wildlife[wildlife_id] = animal
	print("PRIMALIS_WILDLIFE_READY count=%d species=5" % _wildlife.size())


func _pick_wildlife_destination(animal: Dictionary) -> void:
	var home := Vector2(float(animal.get("home_x", 0.0)), float(animal.get("home_z", 0.0)))
	var angle: float = _wildlife_rng.randf_range(0.0, TAU)
	var distance: float = _wildlife_rng.randf_range(12.0, WILDLIFE_ROAM_RADIUS)
	var destination := home + Vector2(cos(angle), sin(angle)) * distance
	destination.x = clampf(destination.x, -WILDLIFE_WORLD_LIMIT, WILDLIFE_WORLD_LIMIT)
	destination.y = clampf(destination.y, -WILDLIFE_WORLD_LIMIT, WILDLIFE_WORLD_LIMIT)
	animal["destination_x"] = destination.x
	animal["destination_z"] = destination.y
	animal["decision_timer"] = _wildlife_rng.randf_range(3.0, 7.0)


func _simulate_wildlife(delta: float) -> void:
	if delta <= 0.0:
		return
	for wildlife_id_variant in _wildlife.keys():
		var wildlife_id: String = String(wildlife_id_variant)
		var animal: Dictionary = _wildlife[wildlife_id]
		if bool(animal.get("is_dead", false)):
			var remaining: float = maxf(0.0, float(animal.get("respawn_remaining", 0.0)) - delta)
			animal["respawn_remaining"] = remaining
			if remaining <= 0.0:
				animal["is_dead"] = false
				animal["health"] = float(animal.get("max_health", 100.0))
				animal["meat_available"] = false
				animal["flee_timer"] = 0.0
				animal["x"] = clampf(float(animal.get("home_x", 0.0)) + _wildlife_rng.randf_range(-12.0, 12.0), -WILDLIFE_WORLD_LIMIT, WILDLIFE_WORLD_LIMIT)
				animal["z"] = clampf(float(animal.get("home_z", 0.0)) + _wildlife_rng.randf_range(-12.0, 12.0), -WILDLIFE_WORLD_LIMIT, WILDLIFE_WORLD_LIMIT)
				animal["is_moving"] = false
				_pick_wildlife_destination(animal)
			_wildlife[wildlife_id] = animal
			continue

		var position := Vector2(float(animal.get("x", 0.0)), float(animal.get("z", 0.0)))
		var nearest_player_distance: float = WILDLIFE_NOTICE_DISTANCE
		var flee_direction := Vector2.ZERO
		for peer_id_variant in _players.keys():
			var player_state: Dictionary = _players[int(peer_id_variant)]
			if bool(player_state.get("is_respawning", false)) or float(player_state.get("health", 0.0)) <= 0.0:
				continue
			var player_position := Vector2(float(player_state.get("x", 0.0)), float(player_state.get("z", 0.0)))
			var offset: Vector2 = position - player_position
			var distance: float = offset.length()
			if distance < nearest_player_distance:
				nearest_player_distance = distance
				flee_direction = offset.normalized() if distance > 0.1 else Vector2.RIGHT
		if nearest_player_distance < WILDLIFE_NOTICE_DISTANCE:
			animal["flee_x"] = flee_direction.x
			animal["flee_z"] = flee_direction.y
			animal["flee_timer"] = maxf(float(animal.get("flee_timer", 0.0)), 1.8)

		var move_direction := Vector2.ZERO
		var speed: float = WILDLIFE_WALK_SPEED
		var flee_timer: float = float(animal.get("flee_timer", 0.0))
		if flee_timer > 0.0:
			flee_timer = maxf(0.0, flee_timer - delta)
			animal["flee_timer"] = flee_timer
			move_direction = Vector2(float(animal.get("flee_x", 0.0)), float(animal.get("flee_z", 0.0))).normalized()
			speed = WILDLIFE_FLEE_SPEED
		else:
			var decision_timer: float = float(animal.get("decision_timer", 0.0)) - delta
			animal["decision_timer"] = decision_timer
			var destination := Vector2(float(animal.get("destination_x", position.x)), float(animal.get("destination_z", position.y)))
			var to_destination: Vector2 = destination - position
			if decision_timer <= 0.0 or to_destination.length() < 1.5:
				_pick_wildlife_destination(animal)
				destination = Vector2(float(animal["destination_x"]), float(animal["destination_z"]))
				to_destination = destination - position
			if to_destination.length_squared() > 0.01:
				move_direction = to_destination.normalized()

		var is_moving: bool = move_direction.length_squared() > 0.001
		if is_moving:
			var candidate_position: Vector2 = position + move_direction * speed * delta
			candidate_position.x = clampf(candidate_position.x, -WILDLIFE_WORLD_LIMIT, WILDLIFE_WORLD_LIMIT)
			candidate_position.y = clampf(candidate_position.y, -WILDLIFE_WORLD_LIMIT, WILDLIFE_WORLD_LIMIT)
			if _can_traverse_step(position, candidate_position):
				position = candidate_position
				animal["yaw"] = atan2(-move_direction.x, -move_direction.y)
			else:
				_pick_wildlife_destination(animal)
				is_moving = false
		animal["x"] = position.x
		animal["z"] = position.y
		animal["is_moving"] = is_moving
		_wildlife[wildlife_id] = animal


func _can_traverse_step(from_position: Vector2, to_position: Vector2) -> bool:
	if _terrain_authority == null:
		return true
	if to_position.distance_squared_to(from_position) < 0.000001:
		return false
	if absf(to_position.x) > WORLD_HALF_SIZE or absf(to_position.y) > WORLD_HALF_SIZE:
		return false
	var from_height: float = float(_terrain_authority.call("height_at", from_position))
	var to_height: float = float(_terrain_authority.call("height_at", to_position))
	return is_finite(from_height) and is_finite(to_height) and absf(to_height - from_height) <= MAX_GROUND_STEP_PER_TICK


func _is_near_water(position: Vector2) -> bool:
	var normalized_x: float = (position.x - WATER_CENTER.x) / WATER_RADII.x
	var normalized_z: float = (position.y - WATER_CENTER.y) / WATER_RADII.y
	return normalized_x * normalized_x + normalized_z * normalized_z <= 1.0


func _save_player_state(peer_id: int) -> void:
	if _character_store == null or not _players.has(peer_id):
		return
	var player_state: Dictionary = _players[peer_id]
	var identity_hash: String = String(player_state.get("identity_hash", ""))
	if identity_hash.is_empty():
		return
	if not bool(_character_store.call("save_character", identity_hash, player_state)):
		push_warning("Could not persist character %s." % String(player_state.get("player_id", peer_id)))


func _save_all_players() -> void:
	if _character_store == null:
		return
	for peer_id_variant in _players.keys():
		_save_player_state(int(peer_id_variant))


func _is_valid_identity_token(value: String) -> bool:
	if value.length() != 64:
		return false
	for character in value.to_lower():
		if not "0123456789abcdef".contains(character):
			return false
	return true


func _is_finite_number(value: Variant) -> bool:
	var value_type: int = typeof(value)
	if value_type != TYPE_INT and value_type != TYPE_FLOAT:
		return false
	return is_finite(float(value))
