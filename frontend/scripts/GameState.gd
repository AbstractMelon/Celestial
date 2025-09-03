extends Node

signal station_changed(station_name)
signal universe_state_updated(universe_data)
signal connection_status_changed(is_connected)
signal alert_level_changed(level)
signal mission_status_changed(mission_data)

var websocket_client: WebSocketClient
var current_station: String = ""
var universe_objects: Dictionary = {}
var effects: Array = []
var removed_objects: Array = []
var meta_data: Dictionary = {}
var server_url: String = "ws://localhost:8080/ws"
var is_connected: bool = false
var alert_level: int = 0
var time_acceleration: float = 1.0
var player_ship_id: String = ""
var mission_data: Dictionary = {}

var station_scenes: Dictionary = {
	"helm": "res://scenes/stations/HelmStation.tscn",
	"tactical": "res://scenes/stations/TacticalStation.tscn",
	"communication": "res://scenes/stations/CommunicationStation.tscn",
	"logistics": "res://scenes/stations/LogisticsStation.tscn",
	"captain": "res://scenes/stations/CaptainStation.tscn",
	"gamemaster": "res://scenes/stations/GameMasterStation.tscn",
	"viewscreen": "res://scenes/3d_viewscreen/ViewScreen.tscn"
}

var audio_manager: AudioManager
var input_manager: InputManager
var hotas_manager: HOTASManager

func _ready():
	websocket_client = WebSocketClient.new()
	add_child(websocket_client)

	websocket_client.connected_to_server.connect(_on_websocket_connected)
	websocket_client.disconnected_from_server.connect(_on_websocket_disconnected)
	websocket_client.state_updated.connect(_on_state_updated)
	websocket_client.error_received.connect(_on_error_received)
	websocket_client.connection_failed.connect(_on_connection_failed)

	audio_manager = AudioManager.new()
	add_child(audio_manager)

	input_manager = InputManager.new()
	add_child(input_manager)

	hotas_manager = HOTASManager.new()
	add_child(hotas_manager)

func connect_to_server(url: String = ""):
	if url != "":
		server_url = url

	print("GameState: Connecting to server at ", server_url)
	websocket_client.connect_to_server(server_url)

func switch_station(station_name: String):
	if station_name == current_station:
		return

	print("GameState: Switching to station: ", station_name)

	if is_connected:
		websocket_client.authenticate_station(station_name)

	current_station = station_name
	station_changed.emit(station_name)

func send_input_event(action: String, value, context: Dictionary = {}):
	if is_connected and current_station != "":
		return websocket_client.send_input_event(action, value, context)
	return false

func send_gamemaster_command(command: String, target: String = "", position: Vector3 = Vector3.ZERO, value = null, object_def: Dictionary = {}, script: String = "", context: Dictionary = {}):
	if current_station == "gamemaster":
		return websocket_client.send_gamemaster_command(command, target, position, value, object_def, script, context)
	return false

func load_mission(mission_file: String, parameters: Dictionary = {}):
	if current_station == "gamemaster":
		return websocket_client.load_mission(mission_file, parameters)
	return false

func get_object(object_id: String) -> Dictionary:
	return universe_objects.get(object_id, {})

func get_player_ship() -> Dictionary:
	if player_ship_id != "":
		return get_object(player_ship_id)

	for obj in universe_objects.values():
		if obj.get("is_player_ship", false):
			player_ship_id = obj.get("id", "")
			return obj

	return {}

func get_objects_by_type(object_type: String) -> Array:
	var result = []
	for obj in universe_objects.values():
		if obj.get("type", "") == object_type:
			result.append(obj)
	return result

func get_objects_in_range(center: Vector3, radius: float) -> Array:
	var result = []
	for obj in universe_objects.values():
		var pos = obj.get("position", {})
		if pos.has("x") and pos.has("y") and pos.has("z"):
			var obj_pos = Vector3(pos.x, pos.y, pos.z)
			if center.distance_to(obj_pos) <= radius:
				result.append(obj)
	return result

func get_connection_status() -> String:
	if websocket_client:
		return websocket_client.get_connection_status()
	return "No Client"

func is_station_authenticated() -> bool:
	return websocket_client and websocket_client.is_station_authenticated()

func get_current_station() -> String:
	return current_station

func get_time_acceleration() -> float:
	return time_acceleration

func get_alert_level() -> int:
	return alert_level

func get_universe_objects() -> Dictionary:
	return universe_objects

func get_effects() -> Array:
	return effects

func get_meta_data() -> Dictionary:
	return meta_data

func _on_websocket_connected():
	is_connected = true
	connection_status_changed.emit(true)
	print("GameState: Connected to server")

	if current_station != "":
		websocket_client.authenticate_station(current_station)

func _on_websocket_disconnected():
	is_connected = false
	connection_status_changed.emit(false)
	print("GameState: Disconnected from server")

func _on_state_updated(state_data: Dictionary):
	var full_state = state_data.get("full", {})

	_update_universe_objects(full_state.get("objects", []))
	_update_effects(full_state.get("effects", []))
	_update_removed_objects(full_state.get("removed", []))
	_update_meta_data(full_state.get("meta", {}))

	print("Updated state")
	print("Objects: " + str(get_universe_objects()))

	universe_state_updated.emit(full_state)

func _on_error_received(error_data: Dictionary):
	print("GameState: Server error - ", error_data.get("message", "Unknown error"))
	var code = error_data.get("code", 0)
	var message = error_data.get("message", "Unknown error")
	var details = error_data.get("details", "")

	audio_manager.play_error_sound()

func _on_connection_failed():
	print("GameState: Connection to server failed")
	is_connected = false
	connection_status_changed.emit(false)

func _update_universe_objects(objects: Array):
	for obj_data in objects:
		var obj_id = obj_data.get("id", "")
		if obj_id != "":
			universe_objects[obj_id] = obj_data

			if obj_data.get("is_player_ship", false):
				player_ship_id = obj_id

func _update_effects(effects_data: Array):
	effects = effects_data

func _update_removed_objects(removed_ids: Array):
	removed_objects = removed_ids
	for obj_id in removed_ids:
		if universe_objects.has(obj_id):
			universe_objects.erase(obj_id)

		if obj_id == player_ship_id:
			player_ship_id = ""

func _update_meta_data(meta: Dictionary):
	meta_data = meta

	var new_time_accel = meta.get("time_acceleration", time_acceleration)
	if new_time_accel != time_acceleration:
		time_acceleration = new_time_accel

	var new_alert = meta.get("alert_level", alert_level)
	if new_alert != alert_level:
		alert_level = new_alert
		alert_level_changed.emit(alert_level)
		audio_manager.update_alert_level(alert_level)

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if websocket_client and is_connected:
			websocket_client.disconnect_from_server()
		get_tree().quit()
