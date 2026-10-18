extends Node

signal state_changed(state: String, detail: String)
signal message_received(message: Dictionary)

const Protocol = preload("res://scripts/online_protocol.gd")
const CONNECT_TIMEOUT_MS: int = 10000
const INITIAL_RETRY_DELAY_MS: int = 1000
const MAX_RETRY_DELAY_MS: int = 30000

@export var server_url: String = ""
@export var auto_reconnect: bool = true

var _peer: WebSocketMultiplayerPeer
var _state: String = "disconnected"
var _detail: String = ""
var _connect_started_ms: int = 0
var _next_retry_ms: int = 0
var _retry_delay_ms: int = INITIAL_RETRY_DELAY_MS
var _hello_sent: bool = false
var _intentional_disconnect: bool = false
var _session_id: String = ""
var _session_requested: bool = false


func _ready() -> void:
	set_process(true)
	server_url = server_url.strip_edges()
	if server_url.is_empty():
		_set_state("unconfigured", "Falta configurar la dirección del servidor online.")
	else:
		connect_to_server()


func _process(_delta: float) -> void:
	var now_ms: int = Time.get_ticks_msec()
	if _peer == null:
		if _state == "retry_wait" and now_ms >= _next_retry_ms:
			connect_to_server(server_url)
		return

	_peer.poll()
	var connection_status: int = _peer.get_connection_status()

	if connection_status == MultiplayerPeer.CONNECTION_CONNECTED:
		if not _hello_sent:
			var hello_result: int = _send_raw({
				"type": "client_hello",
				"protocol_version": Protocol.PROTOCOL_VERSION
			})
			if hello_result != OK:
				_schedule_reconnect("No se pudo enviar el saludo al servidor.")
				return
			_hello_sent = true
			_set_state("awaiting_welcome", "Conectado al transporte; validando protocolo...")

		var packets_pending: int = _peer.get_available_packet_count()
		while packets_pending > 0:
			packets_pending -= 1
			var decoded: Dictionary = Protocol.decode_message(_peer.get_packet())
			if not bool(decoded.get("ok", false)):
				_fail_permanently("El servidor devolvió un paquete inválido.")
				return

			var message: Dictionary = decoded.get("message", {})
			var message_type: String = String(message.get("type", ""))
			match message_type:
				"welcome":
					var protocol_version: Variant = message.get("protocol_version", null)
					var version_type: int = typeof(protocol_version)
					if (version_type != TYPE_INT and version_type != TYPE_FLOAT) or float(protocol_version) != float(Protocol.PROTOCOL_VERSION):
						_fail_permanently("La versión de protocolo del servidor no coincide.")
						return
					_retry_delay_ms = INITIAL_RETRY_DELAY_MS
					_set_state("connected", String(message.get("stage", "unknown")))
					if _session_requested:
						var rejoin_result: int = int(join_session())
						if rejoin_result != OK:
							_schedule_reconnect("No se pudo recuperar la sesión del mundo.")
				"session_joined":
					var player_value: Variant = message.get("player", {})
					if typeof(player_value) != TYPE_DICTIONARY:
						_fail_permanently("El servidor devolvió una sesión sin personaje válido.")
						return
					_session_id = String((player_value as Dictionary).get("player_id", ""))
					if _session_id.is_empty():
						_fail_permanently("El servidor no asignó un identificador al personaje.")
						return
					message_received.emit(message)
				"world_snapshot":
					message_received.emit(message)
				"error":
					message_received.emit(message)
					_fail_permanently("El servidor rechazó la solicitud: %s" % String(message.get("code", "error_desconocido")))
					return
				_:
					if _state != "connected":
						_fail_permanently("Se recibió un mensaje antes de validar el protocolo.")
						return
					message_received.emit(message)
		if now_ms - _connect_started_ms > CONNECT_TIMEOUT_MS and _state != "connected":
			_schedule_reconnect("Se agotó el tiempo de espera del servidor.")
	elif connection_status == MultiplayerPeer.CONNECTION_DISCONNECTED:
		if _state == "connecting" or _state == "awaiting_welcome" or _state == "connected":
			_schedule_reconnect("La conexión con el servidor se cerró.")
	elif now_ms - _connect_started_ms > CONNECT_TIMEOUT_MS:
		_schedule_reconnect("No se pudo completar la conexión a tiempo.")


func connect_to_server(url: String = "") -> int:
	var requested_url: String = url.strip_edges()
	if requested_url.is_empty():
		requested_url = server_url.strip_edges()
	if requested_url.is_empty():
		_set_state("unconfigured", "Falta configurar la dirección del servidor online.")
		return ERR_INVALID_PARAMETER
	if requested_url.length() > 255 or (not requested_url.begins_with("ws://") and not requested_url.begins_with("wss://")):
		_set_state("error", "Dirección inválida. Usa ws:// para pruebas locales o wss:// para Internet.")
		return ERR_INVALID_PARAMETER
	if OS.has_feature("web") and not requested_url.begins_with("wss://"):
		_set_state("error", "El cliente web requiere una conexión segura wss://.")
		return ERR_INVALID_PARAMETER
	if _peer != null:
		var current_status: int = _peer.get_connection_status()
		if requested_url == server_url and (current_status == MultiplayerPeer.CONNECTION_CONNECTING or current_status == MultiplayerPeer.CONNECTION_CONNECTED):
			return OK
		_peer.close()
		_peer = null

	server_url = requested_url
	_intentional_disconnect = false
	_hello_sent = false
	_connect_started_ms = Time.get_ticks_msec()
	var candidate := WebSocketMultiplayerPeer.new()
	candidate.max_queued_packets = 128
	var result: int = candidate.create_client(server_url)
	if result != OK:
		_set_state("error", "No se pudo iniciar la conexión (código %d)." % result)
		return result

	_peer = candidate
	_set_state("connecting", "Conectando con el servidor...")
	return OK


func send_message(message: Dictionary) -> int:
	if _peer == null or _state != "connected":
		return ERR_UNAVAILABLE
	if typeof(message.get("type", null)) != TYPE_STRING:
		return ERR_INVALID_PARAMETER
	return _send_raw(message)


func join_session() -> int:
	if _state != "connected":
		return ERR_UNAVAILABLE
	_session_requested = true
	if not _session_id.is_empty():
		return OK
	var result: int = send_message({"type": "session_join"})
	if result != OK:
		_session_requested = false
	return result


func send_move_input(direction: Vector2, sprint: bool = false) -> int:
	if _state != "connected" or _session_id.is_empty():
		return ERR_UNAVAILABLE
	var safe_direction := direction
	if safe_direction.length() > 1.0:
		safe_direction = safe_direction.normalized()
	return send_message({
		"type": "move_input",
		"x": clampf(safe_direction.x, -1.0, 1.0),
		"z": clampf(safe_direction.y, -1.0, 1.0),
		"sprint": sprint
	})


func disconnect_from_server() -> void:
	_intentional_disconnect = true
	_session_requested = false
	if _peer != null:
		_peer.close()
		_peer = null
	_hello_sent = false
	_session_id = ""
	_set_state("disconnected", "Desconectado por el cliente.")


func get_connection_state() -> String:
	return _state


func _send_raw(message: Dictionary) -> int:
	if _peer == null:
		return ERR_UNAVAILABLE
	_peer.set_target_peer(MultiplayerPeer.TARGET_PEER_SERVER)
	var result: int = _peer.put_packet(Protocol.encode_message(message))
	_peer.set_target_peer(MultiplayerPeer.TARGET_PEER_BROADCAST)
	return result


func _schedule_reconnect(detail: String) -> void:
	if _peer != null:
		_peer.close()
		_peer = null
	_hello_sent = false
	_session_id = ""
	if _intentional_disconnect or not auto_reconnect or server_url.is_empty():
		_set_state("disconnected", detail)
		return
	_next_retry_ms = Time.get_ticks_msec() + _retry_delay_ms
	var scheduled_delay: int = _retry_delay_ms
	_retry_delay_ms = mini(_retry_delay_ms * 2, MAX_RETRY_DELAY_MS)
	_set_state("retry_wait", "%s Reintento en %.1f s." % [detail, float(scheduled_delay) / 1000.0])


func _fail_permanently(detail: String) -> void:
	if _peer != null:
		_peer.close()
		_peer = null
	_hello_sent = false
	_session_id = ""
	_session_requested = false
	_set_state("error", detail)


func _set_state(next_state: String, detail: String) -> void:
	if _state == next_state and _detail == detail:
		return
	_state = next_state
	_detail = detail
	state_changed.emit(_state, _detail)
