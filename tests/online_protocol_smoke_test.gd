extends SceneTree

const Protocol = preload("res://scripts/online_protocol.gd")
const ServerScript = preload("res://server/online_server.gd")
const ClientScript = preload("res://scripts/online_client.gd")
const TEST_PORT: int = 19089

var _failures: int = 0
var _server_node: Node
var _client_node: Node
var _deadline_ms: int = 0
var _saw_connected: bool = false
var _saw_pong: bool = false


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

	_client_node = Node.new()
	_client_node.name = "OnlineClientTest"
	_client_node.set_script(ClientScript)
	_client_node.set("server_url", "ws://127.0.0.1:%d" % TEST_PORT)
	_client_node.set("auto_reconnect", false)
	_client_node.connect("state_changed", _on_client_state_changed)
	_client_node.connect("message_received", _on_client_message_received)
	root.add_child(_client_node)
	_deadline_ms = Time.get_ticks_msec() + 8000


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


func _on_client_state_changed(state: String, detail: String) -> void:
	print("ONLINE CLIENT TEST STATE: %s — %s" % [state, detail])
	if state == "connected":
		_saw_connected = true
		var ping_result: int = int(_client_node.call("send_message", {"type": "ping"}))
		if ping_result != OK:
			_fail("online client could not send ping after protocol validation")
	elif state == "error":
		_fail("online client reported error: %s" % detail)


func _on_client_message_received(message: Dictionary) -> void:
	if String(message.get("type", "")) == "pong":
		_saw_pong = true


func _on_process_frame() -> void:
	if _failures > 0:
		return
	if _saw_connected and _saw_pong:
		print("ONLINE CLIENT TEST PASSED: validated JSON, loopback connect, protocol handshake, and ping/pong through the reusable client.")
		_finish(true)
	elif _deadline_ms > 0 and Time.get_ticks_msec() > _deadline_ms:
		_fail("timed out waiting for the online client handshake and pong")


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
	if is_instance_valid(_client_node):
		_client_node.call("disconnect_from_server")
		_client_node.queue_free()
	if is_instance_valid(_server_node):
		_server_node.call("stop_server")
		_server_node.queue_free()
	quit(0 if success else 1)
