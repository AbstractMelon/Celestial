extends Node
class_name InputManager

signal input_event_generated(action, value, context)
signal device_connected(device_name)
signal device_disconnected(device_name)

var connected_devices: Dictionary = {}
var input_mappings: Dictionary = {}
var current_station: String = ""
var input_sensitivity: Dictionary = {}
var deadzone_settings: Dictionary = {}
var calibration_data: Dictionary = {}

var hotas_devices: Dictionary = {
	"logitech_x56": {
		"name": "Logitech X56 Pro HOTAS",
		"vendor_id": 1133,
		"product_ids": [49737, 49738]
	},
	"logitech_yoke": {
		"name": "Logitech Flight Yoke System",
		"vendor_id": 1133,
		"product_ids": [49686, 49687]
	}
}

var station_input_configs: Dictionary = {
	"helm": {
		"throttle": {"axis": 1, "invert": false, "sensitivity": 1.0, "deadzone": 0.05},
		"rudder": {"axis": 0, "invert": false, "sensitivity": 1.0, "deadzone": 0.05},
		"pitch": {"axis": 3, "invert": true, "sensitivity": 0.8, "deadzone": 0.05},
		"roll": {"axis": 2, "invert": false, "sensitivity": 0.8, "deadzone": 0.05},
		"warp_up": {"button": 6, "type": "digital"},
		"warp_down": {"button": 7, "type": "digital"},
		"autopilot": {"button": 4, "type": "toggle"},
		"emergency_stop": {"button": 5, "type": "digital"}
	},
	"tactical": {
		"target_select": {"axis": 0, "invert": false, "sensitivity": 1.0, "deadzone": 0.1},
		"weapon_power": {"axis": 2, "invert": false, "sensitivity": 1.0, "deadzone": 0.05},
		"shield_power": {"axis": 3, "invert": false, "sensitivity": 1.0, "deadzone": 0.05},
		"fire_phasers": {"button": 0, "type": "digital"},
		"fire_torpedoes": {"button": 1, "type": "digital"},
		"raise_shields": {"button": 2, "type": "toggle"},
		"target_lock": {"button": 3, "type": "digital"}
	},
	"communication": {
		"frequency_tune": {"axis": 0, "invert": false, "sensitivity": 1.0, "deadzone": 0.05},
		"volume_control": {"axis": 1, "invert": false, "sensitivity": 1.0, "deadzone": 0.05},
		"transmit": {"button": 0, "type": "hold"},
		"emergency_broadcast": {"button": 1, "type": "digital"}
	},
	"logistics": {
		"power_engines": {"axis": 0, "invert": false, "sensitivity": 1.0, "deadzone": 0.05},
		"power_shields": {"axis": 1, "invert": false, "sensitivity": 1.0, "deadzone": 0.05},
		"power_weapons": {"axis": 2, "invert": false, "sensitivity": 1.0, "deadzone": 0.05},
		"power_life_support": {"axis": 3, "invert": false, "sensitivity": 1.0, "deadzone": 0.05},
		"repair_priority": {"button": 0, "type": "digital"},
		"damage_control": {"button": 1, "type": "toggle"}
	},
	"captain": {
		"alert_yellow": {"button": 0, "type": "digital"},
		"alert_orange": {"button": 1, "type": "digital"},
		"alert_red": {"button": 2, "type": "digital"},
		"all_stop": {"button": 3, "type": "digital"},
		"general_quarters": {"button": 4, "type": "digital"},
		"emergency_power": {"button": 5, "type": "toggle"}
	},
	"gamemaster": {
		"spawn_mode": {"button": 0, "type": "toggle"},
		"delete_mode": {"button": 1, "type": "toggle"},
		"time_control": {"axis": 0, "invert": false, "sensitivity": 1.0, "deadzone": 0.05},
		"pause_simulation": {"button": 2, "type": "toggle"}
	}
}

var button_states: Dictionary = {}
var axis_values: Dictionary = {}
var toggle_states: Dictionary = {}
var last_input_time: float = 0.0
var input_rate_limit: float = 1.0/60.0

func _ready():
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_scan_for_devices()
	_load_calibration_data()
	_setup_default_settings()

func _process(delta):
	if Time.get_unix_time_from_system() - last_input_time < input_rate_limit:
		return

	_process_connected_devices()
	last_input_time = Time.get_unix_time_from_system()

func _scan_for_devices():
	connected_devices.clear()

	for device_id in Input.get_connected_joypads():
		var device_name = Input.get_joy_name(device_id)
		var device_guid = Input.get_joy_guid(device_id)

		connected_devices[device_id] = {
			"name": device_name,
			"guid": device_guid,
			"type": _identify_device_type(device_name, device_guid),
			"last_activity": 0.0
		}

		print("InputManager: Found device - ", device_name, " (ID: ", device_id, ")")
		device_connected.emit(device_name)

func _identify_device_type(device_name: String, device_guid: String) -> String:
	device_name = device_name.to_lower()

	if "x56" in device_name or "saitek" in device_name:
		return "hotas_x56"
	elif "yoke" in device_name and "logitech" in device_name:
		return "flight_yoke"
	elif "throttle" in device_name and "logitech" in device_name:
		return "throttle_panel"
	elif "joystick" in device_name or "stick" in device_name:
		return "generic_joystick"
	else:
		return "unknown"

func _setup_default_settings():
	input_sensitivity = {
		"throttle": 1.0,
		"steering": 1.0,
		"weapons": 1.0,
		"power": 1.0
	}

	deadzone_settings = {
		"throttle": 0.05,
		"steering": 0.05,
		"weapons": 0.1,
		"power": 0.05
	}

func _process_connected_devices():
	if current_station == "" or not station_input_configs.has(current_station):
		return

	var config = station_input_configs[current_station]

	for action_name in config:
		var action_config = config[action_name]
		_process_input_action(action_name, action_config)

func _process_input_action(action_name: String, config: Dictionary):
	if config.has("axis"):
		_process_axis_input(action_name, config)
	elif config.has("button"):
		_process_button_input(action_name, config)

func _process_axis_input(action_name: String, config: Dictionary):
	var axis_id = config.get("axis", 0)
	var invert = config.get("invert", false)
	var sensitivity = config.get("sensitivity", 1.0)
	var deadzone = config.get("deadzone", 0.05)

	for device_id in connected_devices:
		var raw_value = Input.get_joy_axis(device_id, axis_id)

		if abs(raw_value) < deadzone:
			raw_value = 0.0
		else:
			raw_value = sign(raw_value) * ((abs(raw_value) - deadzone) / (1.0 - deadzone))

		if invert:
			raw_value *= -1.0

		raw_value *= sensitivity
		raw_value = clamp(raw_value, -1.0, 1.0)

		var current_stored = axis_values.get(action_name, 0.0)
		if abs(raw_value - current_stored) > 0.01:
			axis_values[action_name] = raw_value
			_emit_input_event(action_name, raw_value)

func _process_button_input(action_name: String, config: Dictionary):
	var button_id = config.get("button", 0)
	var button_type = config.get("type", "digital")

	for device_id in connected_devices:
		var is_pressed = Input.is_joy_button_pressed(device_id, button_id)
		var was_pressed = button_states.get(action_name, false)

		match button_type:
			"digital":
				if is_pressed and not was_pressed:
					_emit_input_event(action_name, true)
				elif not is_pressed and was_pressed:
					_emit_input_event(action_name, false)

			"toggle":
				if is_pressed and not was_pressed:
					var current_toggle = toggle_states.get(action_name, false)
					toggle_states[action_name] = not current_toggle
					_emit_input_event(action_name, toggle_states[action_name])

			"hold":
				if is_pressed != was_pressed:
					_emit_input_event(action_name, is_pressed)

		button_states[action_name] = is_pressed

func _emit_input_event(action: String, value, context: Dictionary = {}):
	input_event_generated.emit(action, value, context)

	if GameState:
		GameState.send_input_event(action, value, context)

func set_station(station_name: String):
	if station_name == current_station:
		return

	print("InputManager: Switching to station input profile: ", station_name)
	current_station = station_name

	button_states.clear()
	axis_values.clear()
	toggle_states.clear()

func calibrate_axis(device_id: int, axis_id: int):
	if not connected_devices.has(device_id):
		return false

	print("InputManager: Starting calibration for device ", device_id, " axis ", axis_id)

	var min_value = 0.0
	var max_value = 0.0
	var center_value = 0.0
	var sample_count = 0
	var calibration_time = 5.0
	var start_time := Time.get_unix_time_from_system()

	while Time.get_unix_time_from_system() - start_time < calibration_time:
		var current_value = Input.get_joy_axis(device_id, axis_id)

		if sample_count == 0:
			min_value = current_value
			max_value = current_value
			center_value = current_value
		else:
			min_value = min(min_value, current_value)
			max_value = max(max_value, current_value)
			center_value = (center_value * sample_count + current_value) / (sample_count + 1)

		sample_count += 1
		await get_tree().process_frame

	calibration_data[str(device_id) + "_" + str(axis_id)] = {
		"min": min_value,
		"max": max_value,
		"center": center_value
	}

	_save_calibration_data()
	print("InputManager: Calibration complete for device ", device_id, " axis ", axis_id)
	return true

func get_calibrated_axis_value(device_id: int, axis_id: int) -> float:
	var key = str(device_id) + "_" + str(axis_id)
	var raw_value = Input.get_joy_axis(device_id, axis_id)

	if not calibration_data.has(key):
		return raw_value

	var cal_data = calibration_data[key]
	var center = cal_data.get("center", 0.0)
	var min_val = cal_data.get("min", -1.0)
	var max_val = cal_data.get("max", 1.0)

	if raw_value > center:
		return (raw_value - center) / (max_val - center)
	else:
		return (raw_value - center) / (center - min_val)

func set_input_sensitivity(input_type: String, sensitivity: float):
	input_sensitivity[input_type] = clamp(sensitivity, 0.1, 5.0)

func set_deadzone(input_type: String, deadzone: float):
	deadzone_settings[input_type] = clamp(deadzone, 0.0, 0.5)

func get_device_info(device_id: int) -> Dictionary:
	return connected_devices.get(device_id, {})

func get_connected_device_count() -> int:
	return connected_devices.size()

func is_device_active(device_id: int) -> bool:
	if not connected_devices.has(device_id):
		return false

	var last_activity = connected_devices[device_id].get("last_activity", 0.0)
	return Time.get_unix_time_from_system() - last_activity < 5.0

func _on_joy_connection_changed(device_id: int, connected: bool):
	if connected:
		var device_name = Input.get_joy_name(device_id)
		var device_guid = Input.get_joy_guid(device_id)

		connected_devices[device_id] = {
			"name": device_name,
			"guid": device_guid,
			"type": _identify_device_type(device_name, device_guid),
			"last_activity": Time.get_unix_time_from_system()
		}

		print("InputManager: Device connected - ", device_name)
		device_connected.emit(device_name)
	else:
		if connected_devices.has(device_id):
			var device_name = connected_devices[device_id].get("name", "Unknown")
			connected_devices.erase(device_id)
			print("InputManager: Device disconnected - ", device_name)
			device_disconnected.emit(device_name)

func _load_calibration_data():
	var file_path = "user://input_calibration.cfg"

	if not FileAccess.file_exists(file_path):
		return

	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()

		var json = JSON.new()
		var parse_result = json.parse(json_string)

		if parse_result == OK:
			calibration_data = json.data

func _save_calibration_data():
	var file_path = "user://input_calibration.cfg"
	var file = FileAccess.open(file_path, FileAccess.WRITE)

	if file:
		var json_string = JSON.stringify(calibration_data)
		file.store_string(json_string)
		file.close()

func get_station_input_actions(station: String) -> Array:
	if not station_input_configs.has(station):
		return []

	return station_input_configs[station].keys()

func is_hotas_connected() -> bool:
	for device in connected_devices.values():
		var device_type = device.get("type", "unknown")
		if device_type in ["hotas_x56", "flight_yoke", "throttle_panel"]:
			return true
	return false

func get_hotas_status() -> Dictionary:
	var hotas_devices_found = []

	for device in connected_devices.values():
		var device_type = device.get("type", "unknown")
		if device_type in ["hotas_x56", "flight_yoke", "throttle_panel"]:
			hotas_devices_found.append({
				"name": device.get("name", "Unknown"),
				"type": device_type
			})

	return {
		"connected": hotas_devices_found.size() > 0,
		"devices": hotas_devices_found,
		"count": hotas_devices_found.size()
	}
