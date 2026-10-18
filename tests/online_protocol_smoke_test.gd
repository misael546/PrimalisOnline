extends SceneTree

const Protocol = preload("res://scripts/online_protocol.gd")
const ServerScript = preload("res://server/online_server.gd")
const ClientScript = preload("res://scripts/online_client.gd")
const RemotePlayerScript = preload("res://scripts/remote_player.gd")
const TEST_PORT: int = 19089

var _failures: int = 0
var _server_node: Node
var _client_a: Node
var _client_b: Node
var _deadline_ms: int = 0
var _first_player_id: String = ""
var _seen_session: Dictionary = {"A": false, "B": false}
var _join_requested: Dictionary = {"A": false, "B": false}
var _move_started_ms: int = -1
var _move_stop_sent: bool = false
var _saw_two_players: bool = false
var _saw_server_movement: bool = false
var _max_first_player_x: float = 0.0


func _initialize() -> void:
	process_frame.connect(_on_process_frame)
	call_deferred("_begin")


func _begin() -> void:
	_run_protocol_cases()
	if _failures > 0:
		quit(1)
		return
	_expect(Protocol != null, "protocol script loads")
	_expect(ServerScript != null, "dedicated server script loads")
	_expect(ClientScript != null, "online client script loads")
	_expect(RemotePlayerScript != null, "remote player visual script loads")
	if _failures > 0:
		quit(1)
		return

	_server_node = Node.new()
	_server_node.name = "PrimalisOnlineServerTest"
	_server_node.set_script(ServerScript)
	root.add_child(_server_node)
	var listen_result: int = int(_server_node.call("start_server", TEST_PORT, "127.0.0.1"))
	_expect(listen_result == OK, "dedicated WebSocket server binds to loopback")
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
	client_node.connect("state_changed", _on_client_state_changed.bind(label))
	client_node.connect("message_received", _on_client_message_received.bind(label))
	root.add_child(client_node)
	return client_node


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
		print("ONLINE SESSION TEST PASSED: two clients joined, server broadcast both players, and server-authoritative movement advanced X to %.2f." % _max_first_player_x)
		_finish(true)
	elif _deadline_ms > 0 and Time.get_ticks_msec() > _deadline_ms:
		_fail("timed out waiting for two sessions and server-authoritative movement; A=%s B=%s two_players=%s max_x=%.3f" % [
			str(_seen_session["A"]), str(_seen_session["B"]), str(_saw_two_players), _max_first_player_x
		])


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
