class_name PrimalisOnlineProtocol
extends RefCounted

## Shared JSON message envelope for the browser, Android, and dedicated server.
## Messages are validated here; sessions, actions, and persistent character state are server-owned.
const PROTOCOL_VERSION: int = 1
const MAX_PACKET_BYTES: int = 4096
const MAX_MESSAGES_PER_SECOND: int = 30

static func encode_message(message: Dictionary) -> PackedByteArray:
	return JSON.stringify(message).to_utf8_buffer()


static func decode_message(packet: PackedByteArray) -> Dictionary:
	if packet.is_empty():
		return {"ok": false, "error": "empty_packet"}
	if packet.size() > MAX_PACKET_BYTES:
		return {"ok": false, "error": "packet_too_large"}

	var parser := JSON.new()
	if parser.parse(packet.get_string_from_utf8()) != OK:
		return {"ok": false, "error": "invalid_json"}
	var parsed: Variant = parser.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "error": "invalid_json_object"}

	var message: Dictionary = parsed
	var message_type: Variant = message.get("type", null)
	if typeof(message_type) != TYPE_STRING:
		return {"ok": false, "error": "missing_message_type"}

	var type_text: String = String(message_type)
	if type_text.is_empty() or type_text.length() > 32:
		return {"ok": false, "error": "invalid_message_type"}

	return {"ok": true, "message": message}
