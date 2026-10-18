extends Node

const Protocol = preload("res://scripts/online_protocol.gd")
const MAX_CLIENTS: int = 32
const DEFAULT_PORT: int = 9080
const DEFAULT_BIND_ADDRESS: String = "127.0.0.1"

var _server_peer: WebSocketMultiplayerPeer
var _peer_state: Dictionary = {}


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


func _handle_message(peer_id: int, message: Dictionary) -> Dictionary:
	var message_type: String = String(message.get("type", ""))
	var state: Dictionary = _peer_state.get(peer_id, {})

	match message_type:
		"client_hello":
			var client_version: Variant = message.get("protocol_version", null)
			if typeof(client_version) != TYPE_INT or int(client_version) != Protocol.PROTOCOL_VERSION:
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
