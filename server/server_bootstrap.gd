extends SceneTree

const SERVER_SCRIPT_PATH: String = "res://server/online_server.gd"
const DEFAULT_PORT: int = 9080
const DEFAULT_BIND_ADDRESS: String = "127.0.0.1"


func _initialize() -> void:
	call_deferred("_start_server")


func _start_server() -> void:
	var port_text: String = _read_option("--port=", str(DEFAULT_PORT))
	if not port_text.is_valid_int():
		push_error("Invalid --port value: %s" % port_text)
		quit(2)
		return
	var port: int = int(port_text)
	var bind_address: String = _read_option("--bind-address=", DEFAULT_BIND_ADDRESS)

	var server_script: Script = load(SERVER_SCRIPT_PATH) as Script
	if server_script == null:
		push_error("Could not load dedicated server runtime: %s" % SERVER_SCRIPT_PATH)
		quit(1)
		return

	var server_node := Node.new()
	server_node.name = "PrimalisOnlineServer"
	server_node.set_script(server_script)
	root.add_child(server_node)

	var result: int = int(server_node.call("start_server", port, bind_address))
	if result != OK:
		server_node.queue_free()
		quit(1)


func _read_option(prefix: String, default_value: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.substr(prefix.length())
	return default_value
