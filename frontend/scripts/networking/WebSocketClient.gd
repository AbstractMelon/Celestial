extends Node
class_name WebSocketClient

signal connected_to_server
signal disconnected_from_server
signal state_updated(state_data)
signal error_received(error_data)
signal connection_failed

var socket: WebSocketPeer
var connection_url: String = "ws://localhost:8080/ws"
var is_connected: bool = false
var current_station: String = ""
var client_id: String = ""
var heartbeat_timer: Timer
var reconnect_timer: Timer
var reconnect_attempts: int = 0
var max_reconnect_attempts: int = 10
var base_reconnect_delay: float = 1.0
var last_heartbeat: float = 0.0
var heartbeat_interval: float = 30.0

func _ready():
	socket = WebSocketPeer.new()
	client_id = generate_client_id()

	heartbeat_timer = Timer.new()
	heartbeat_timer.wait_time = heartbeat_interval
	heartbeat_timer.timeout.connect(_send_heartbeat)
	heartbeat_timer.autostart = false
	add_child(heartbeat_timer)

	reconnect_timer = Timer.new()
	reconnect_timer.timeout.connect(_attempt_reconnect)
	reconnect_timer.one_shot = true
	add_child(reconnect_timer)

func _process(_delta):
	if socket:
		socket.poll()
		var state = socket.get_ready_state()

		match state:
			WebSocketPeer.STATE_OPEN:
				if not is_connected:
					is_connected = true
					reconnect_attempts = 0
					print("WebSocket connected successfully")
					connected_to_server.emit()
					heartbeat_timer.start()

				while socket.get_available_packet_count() > 0:
					var packet = socket.get_packet()
					var message = packet.get_string_from_utf8()
					_handle_message(message)

			WebSocketPeer.STATE_CLOSING:
				pass

			WebSocketPeer.STATE_CLOSED:
				if is_connected:
					is_connected = false
					heartbeat_timer.stop()
					print("WebSocket disconnected")
					disconnected_from_server.emit()
					_schedule_reconnect()

func connect_to_server(url: String = ""):
	if url != "":
		connection_url = url

	print("Connecting to: ", connection_url)
	var error = socket.connect_to_url(connection_url)

	if error != OK:
		print("Failed to connect to WebSocket: ", error)
		connection_failed.emit()
		_schedule_reconnect()

func disconnect_from_server():
	if socket and is_connected:
		socket.close(1000, "Client disconnect")
	is_connected = false
	heartbeat_timer.stop()

func authenticate_station(station_type: String):
	if not is_connected:
		print("Cannot authenticate - not connected to server")
		return false

	current_station = station_type
	var auth_message = {
		"type": "station_connect",
		"timestamp": get_iso_timestamp(),
		"data": {
			"station": station_type,
			"client_id": client_id,
			"version": "1.0.0"
		}
	}

	return send_message(auth_message)

func send_input_event(action: String, value, context: Dictionary = {}):
	if not is_connected or current_station == "":
		return false

	var input_message = {
		"type": "input_event",
		"timestamp": get_iso_timestamp(),
		"data": {
			"station": current_station,
			"action": action,
			"value": value,
			"context": context
		}
	}

	return send_message(input_message)

func send_gamemaster_command(command: String, target: String = "", position: Vector3 = Vector3.ZERO, value = null, object_def: Dictionary = {}, script: String = "", context: Dictionary = {}):
	if not is_connected or current_station != "gamemaster":
		return false

	var gm_message = {
		"type": "gamemaster_command",
		"timestamp": get_iso_timestamp(),
		"data": {
			"command": command,
			"target": target,
			"position": {"x": position.x, "y": position.y, "z": position.z},
			"value": value,
			"object_def": object_def,
			"script": script,
			"context": context
		}
	}

	return send_message(gm_message)

func load_mission(mission_file: String, parameters: Dictionary = {}):
	if not is_connected or current_station != "gamemaster":
		return false

	var mission_message = {
		"type": "mission_load",
		"timestamp": get_iso_timestamp(),
		"data": {
			"mission_file": mission_file,
			"parameters": parameters
		}
	}

	return send_message(mission_message)

func send_message(message: Dictionary) -> bool:
	if not is_connected:
		return false

	var json_string = JSON.stringify(message)
	var error = socket.send_text(json_string)

	if error != OK:
		print("Failed to send message: ", error)
		return false

	return true

func _handle_message(message_text: String):
	var json = JSON.new()
	var parse_result = json.parse(message_text)

	if parse_result != OK:
		print("Failed to parse JSON message: ", message_text)
		return

	var message = json.data

	if not message.has("type"):
		print("Message missing type field: ", message_text)
		return
	
	print("Handling message with type of " + str(message.type))

	match message.type:
		"state_update":
			if message.has("data"):
				print(message.data)
				state_updated.emit(message.data)
			else:
				print("State ain't got no data")

		"error":
			print("Server error: ", message.data.message if message.has("data") else "Unknown error")
			if message.has("data"):
				error_received.emit(message.data)

		_:
			print("Unknown message type: ", message.type)

func _send_heartbeat():
	if not is_connected:
		return

	var heartbeat_message = {
		"type": "heartbeat",
		"timestamp": get_iso_timestamp(),
		"data": {
			"client_id": client_id,
			"ping": get_iso_timestamp()
		}
	}

	if not send_message(heartbeat_message):
		print("Failed to send heartbeat")

func _schedule_reconnect():
	if reconnect_attempts >= max_reconnect_attempts:
		print("Max reconnection attempts reached")
		return

	reconnect_attempts += 1
	var delay = base_reconnect_delay * pow(2, min(reconnect_attempts - 1, 6))

	print("Scheduling reconnect attempt ", reconnect_attempts, " in ", delay, " seconds")
	reconnect_timer.wait_time = delay
	reconnect_timer.start()

func _attempt_reconnect():
	print("Attempting to reconnect...")
	connect_to_server()

func generate_client_id() -> String:
	var timestamp = Time.get_unix_time_from_system()
	var random = randi() % 10000
	return "godot_client_" + str(timestamp) + "_" + str(random)

func get_connection_status() -> String:
	if not socket:
		return "No Socket"

	match socket.get_ready_state():
		WebSocketPeer.STATE_CONNECTING:
			return "Connecting"
		WebSocketPeer.STATE_OPEN:
			return "Connected"
		WebSocketPeer.STATE_CLOSING:
			return "Disconnecting"
		WebSocketPeer.STATE_CLOSED:
			return "Disconnected"
		_:
			return "Unknown"

func is_station_authenticated() -> bool:
	return is_connected and current_station != ""

func get_current_station() -> String:
	return current_station

func get_client_id() -> String:
	return client_id
	
func get_iso_timestamp() -> String:
	var dt = Time.get_datetime_dict_from_system()
	# Zero-pad components and insert the 'T'
	return "%04d-%02d-%02dT%02d:%02d:%02dZ" % [
		dt.year, dt.month, dt.day,
		dt.hour, dt.minute, dt.second
	]
