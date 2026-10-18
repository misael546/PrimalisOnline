extends SceneTree

const Protocol = preload("res://scripts/online_protocol.gd")
const ServerScript = preload("res://server/online_server.gd")
const TEST_PORT: int = 19089

var _failures: int = 0
var _server_node: Node
var _client := WebSocketMultiplayerPeer.new()
var _started: bool = false
var _deadline_ms: int = 0
var _sent_hello: bool = false
var _sent_ping: bool = false
var _saw_welcome: bool = false
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
	_expect(ServerScript != null, "server runtime script loads")
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

	var connect_result: int = _client.create_client("ws://127.0.0.1:%d" % TEST_PORT)
	_expect(connect_result == OK, "WebSocket client begins local connection")
	if _failures > 0:
		quit(1)
		return

	_deadline_ms = Time.get_ticks_msec() + 6000
	_started = true


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


func _on_process_frame() -> void:
	if not _started:
		return
	_client.poll()

	if _client.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		while _client.get_available_packet_count() > 0:
			var packet: PackedByteArray = _client.get_packet()
			var decoded: Dictionary = Protocol.decode_message(packet)
			if not bool(decoded.get("ok", false)):
				_fail("server returned an invalid protocol message")
				return
			var message: Dictionary = decoded.get("message", {})
			var message_type: String = String(message.get("type", ""))
			match message_type:
				"server_hello":
					if not _sent_hello:
						_sent_hello = true
						var hello_result: int = _client.put_packet(Protocol.encode_message({
							"type": "client_hello",
							"protocol_version": Protocol.PROTOCOL_VERSION
						}))
						if hello_result != OK:
							_fail("client hello could not be sent")
							return
				"welcome":
					_saw_welcome = int(message.get("protocol_version", -1)) == Protocol.PROTOCOL_VERSION
					if not _sent_ping:
						_sent_ping = true
						var ping_result: int = _client.put_packet(Protocol.encode_message({"type": "ping"}))
						if ping_result != OK:
							_fail("ping could not be sent")
							return
				"pong":
					_saw_pong = true
				"error":
					_fail("server rejected protocol test: %s" % String(message.get("code", "unknown")))
					return

	if _saw_welcome and _saw_pong:
		print("ONLINE PROTOCOL TESTS PASSED: JSON validation, local WebSocket connect, handshake, and ping/pong.")
		_finish(true)
	elif Time.get_ticks_msec() > _deadline_ms:
		_fail("timed out waiting for server hello, welcome, and pong")


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
	_started = false
	_client.close()
	if is_instance_valid(_server_node):
		_server_node.call("stop_server")
		_server_node.queue_free()
	quit(0 if success else 1)
