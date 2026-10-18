extends Node

const Protocol = preload("res://scripts/online_protocol.gd")
const MAX_CLIENTS: int = 32
const DEFAULT_PORT: int = 9080
const DEFAULT_BIND_ADDRESS: String = "127.0.0.1"
const WORLD_HALF_SIZE: float = 2250.0
const BASE_MOVE_SPEED: float = 4.5
const SPRINT_MULTIPLIER: float = 1.65
const STAMINA_DRAIN_PER_SECOND: float = 14.0
const STAMINA_RECOVERY_PER_SECOND: float = 12.0
const HUNGER_DRAIN_PER_SECOND: float = 0.025
const THIRST_DRAIN_PER_SECOND: float = 0.04
const SNAPSHOT_INTERVAL_SECONDS: float = 0.1
const INPUT_TIMEOUT_MS: int = 350

var _server_peer: WebSocketMultiplayerPeer
var _peer_state: Dictionary = {}
var _players: Dictionary = {}
var _snapshot_timer: float = 0.0


func _ready() -> void:
	set_process(true)


func start_server(port: int = DEFAULT_PORT, bind_address: String = DEFAULT_BIND_ADDRESS) -> int:
	if _server_peer != null:
		push_error("Primalis Online server is already running.")
		return ERR_ALREADY_IN_USE
	if port < 1 or port > 65535 or bind_address.strip_edges().is_empty():
		push_error("Invalid server endpoint. Port must be 1-65535 and bind address cannot be empty.")
		return ERR_INVALID_PARAMETER

	var candidate := WebSocketMultiplayerPeer.new()
	candidate.max_queued_packets = 128
	var result: int = candidate.create_server(port, bind_address)
	if result != OK:
		push_error("Could not start Primalis Online WebSocket server (error %d) on %s:%d." % [result, bind_address, port])
		return result

	_server_peer = candidate
	_peer_state.clear()
	print("PRIMALIS_SERVER_READY host=%s port=%d protocol=%d max_clients=%d" % [
		bind_address, port, Protocol.PROTOCOL_VERSION, MAX_CLIENTS
	])
	return OK


func stop_server() -> void:
	# Dropping the peer releases the listening socket; state is not persisted by this transport prototype.
	_peer_state.clear()
	_server_peer = null
	print("PRIMALIS_SERVER_STOPPED")


func _process(_delta: float) -> void:
	if _server_peer == null:
		return

	_server_peer.poll()
	_simulate_players(minf(maxf(_delta, 0.0), 0.1))
	_snapshot_timer += minf(maxf(_delta, 0.0), 0.1)
	if _snapshot_timer >= SNAPSHOT_INTERVAL_SECONDS:
		_snapshot_timer = 0.0
		_broadcast_world_snapshot()

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
				"stage": "transport_only"
			}
		"session_join":
			if not bool(state.get("handshake_complete", false)):
				return {"type": "error", "code": "handshake_required"}
			if _players.has(peer_id):
				return {
					"type": "session_joined",
					"player": _public_player_state(peer_id),
					"players": _public_player_list()
				}
			if _players.size() >= MAX_CLIENTS:
				return {"type": "error", "code": "world_full"}
			var display_name: String = "Viajero-%d" % peer_id
			_players[peer_id] = {
				"player_id": "player-%d" % peer_id,
				"display_name": display_name,
				"x": 0.0,
				"z": 0.0,
				"yaw": 0.0,
				"input_x": 0.0,
				"input_z": 0.0,
				"sprint_requested": false,
				"is_sprinting": false,
				"is_moving": false,
				"last_input_ms": Time.get_ticks_msec(),
				"is_respawning": false,
				"respawn_remaining": 0.0,
				"health": 100.0,
				"hunger": 100.0,
				"thirst": 100.0,
				"stamina": 100.0
			}
			state["session_joined"] = true
			_peer_state[peer_id] = state
			print("PRIMALIS_PLAYER_JOINED id=%s" % String(_players[peer_id]["player_id"]))
			return {
				"type": "session_joined",
				"player": _public_player_state(peer_id),
				"players": _public_player_list()
			}
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
		var stamina: float = float(player_state.get("stamina", 100.0))
		var is_sprinting: bool = moving and sprint_requested and stamina > 0.0

		if is_sprinting:
			stamina = maxf(0.0, stamina - STAMINA_DRAIN_PER_SECOND * delta)
		else:
			stamina = minf(100.0, stamina + STAMINA_RECOVERY_PER_SECOND * delta)

		if moving:
			var direction := input_direction.normalized()
			var speed: float = BASE_MOVE_SPEED * (SPRINT_MULTIPLIER if is_sprinting else 1.0)
			player_state["x"] = clampf(float(player_state.get("x", 0.0)) + direction.x * speed * delta, -WORLD_HALF_SIZE, WORLD_HALF_SIZE)
			player_state["z"] = clampf(float(player_state.get("z", 0.0)) + direction.y * speed * delta, -WORLD_HALF_SIZE, WORLD_HALF_SIZE)
			player_state["yaw"] = atan2(-direction.x, -direction.y)

		player_state["is_moving"] = moving
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
		"players": _public_player_list()
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
		"stamina": float(source.get("stamina", 100.0))
	}


func _is_finite_number(value: Variant) -> bool:
	var value_type: int = typeof(value)
	if value_type != TYPE_INT and value_type != TYPE_FLOAT:
		return false
	return is_finite(float(value))
