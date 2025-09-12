extends Node
class_name HOTASManager

signal hotas_connected(device_info)
signal hotas_disconnected(device_info)
signal hotas_calibration_complete(device_id, axis_id)
signal hotas_input_received(device_id, input_type, value)

var connected_hotas: Dictionary = {}
var device_profiles: Dictionary = {}
var calibration_in_progress: Dictionary = {}
var axis_ranges: Dictionary = {}
var button_mappings: Dictionary = {}

var logitech_x56_profile: Dictionary = {
	"name": "Logitech X56 Pro HOTAS",
	"vendor_id": 1133,
	"product_ids": [49737, 49738],
	"axes": {
		"stick_x": {"id": 0, "invert": false, "curve": "linear"},
		"stick_y": {"id": 1, "invert": true, "curve": "linear"},
		"stick_twist": {"id": 2, "invert": false, "curve": "linear"},
		"throttle_left": {"id": 3, "invert": true, "curve": "linear"},
		"throttle_right": {"id": 4, "invert": true, "curve": "linear"},
		"mini_stick_x": {"id": 5, "invert": false, "curve": "linear"},
		"mini_stick_y": {"id": 6, "invert": false, "curve": "linear"},
		"slider_1": {"id": 7, "invert": false, "curve": "linear"},
		"slider_2": {"id": 8, "invert": false, "curve": "linear"}
	},
	"buttons": {
		"trigger": 0,
		"fire_a": 1,
		"fire_b": 2,
		"fire_c": 3,
		"pinky_trigger": 4,
		"fire_d": 5,
		"fire_e": 6,
		"thumbstick_click": 7,
		"hat_up": 8,
		"hat_down": 9,
		"hat_left": 10,
		"hat_right": 11,
		"throttle_hat_up": 12,
		"throttle_hat_down": 13,
		"throttle_hat_left": 14,
		"throttle_hat_right": 15,
		"mode_1": 16,
		"mode_2": 17,
		"mode_3": 18,
		"clutch": 19,
		"function": 20,
		"start_stop": 21,
		"reset": 22,
		"pg_up": 23,
		"pg_dn": 24,
		"up": 25,
		"down": 26,
		"scroll_fwd": 27,
		"scroll_back": 28
	}
}

var logitech_yoke_profile: Dictionary = {
	"name": "Logitech Flight Yoke System",
	"vendor_id": 1133,
	"product_ids": [49686, 49687],
	"axes": {
		"yoke_x": {"id": 0, "invert": false, "curve": "linear"},
		"yoke_y": {"id": 1, "invert": true, "curve": "linear"},
		"left_throttle": {"id": 2, "invert": true, "curve": "linear"},
		"right_throttle": {"id": 3, "invert": true, "curve": "linear"},
		"left_prop": {"id": 4, "invert": false, "curve": "linear"},
		"right_prop": {"id": 5, "invert": false, "curve": "linear"},
		"left_mixture": {"id": 6, "invert": false, "curve": "linear"},
		"right_mixture": {"id": 7, "invert": false, "curve": "linear"},
		"rudder": {"id": 8, "invert": false, "curve": "linear"}
	},
	"buttons": {
		"trigger": 0,
		"fire_button": 1,
		"button_3": 2,
		"button_4": 3,
		"button_5": 4,
		"button_6": 5,
		"gear_up": 6,
		"gear_down": 7,
		"flaps_up": 8,
		"flaps_down": 9,
		"trim_up": 10,
		"trim_down": 11,
		"view_hat_up": 12,
		"view_hat_down": 13,
		"view_hat_left": 14,
		"view_hat_right": 15
	}
}

var station_hotas_mappings: Dictionary = {
	"helm": {
		"primary_axis": "throttle_left",
		"steering_axis": "yoke_x",
		"pitch_axis": "yoke_y",
		"rudder_axis": "rudder",
		"warp_up": "pg_up",
		"warp_down": "pg_dn",
		"autopilot": "mode_1",
		"emergency_stop": "clutch"
	},
	"tactical": {
		"weapon_aim_x": "stick_x",
		"weapon_aim_y": "stick_y",
		"weapon_power": "throttle_right",
		"shield_power": "slider_1",
		"fire_phasers": "trigger",
		"fire_torpedoes": "fire_a",
		"raise_shields": "pinky_trigger",
		"target_lock": "fire_b"
	},
	"captain": {
		"alert_yellow": "mode_1",
		"alert_red": "mode_3",
		"all_stop": "clutch",
		"general_quarters": "start_stop",
		"camera_control_x": "mini_stick_x",
		"camera_control_y": "mini_stick_y"
	}
}

func _ready():
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_scan_for_hotas_devices()
	_load_device_profiles()

func _process(_delta):
	_process_hotas_inputs()

func _scan_for_hotas_devices():
	connected_hotas.clear()

	for device_id in Input.get_connected_joypads():
		var device_name = Input.get_joy_name(device_id)
		var device_guid = Input.get_joy_guid(device_id)

		var profile = _identify_hotas_device(device_name, device_guid)
		if profile:
			connected_hotas[device_id] = {
				"profile": profile,
				"name": device_name,
				"guid": device_guid,
				"calibrated": false,
				"last_input": 0.0,
				"axis_values": {},
				"button_states": {}
			}

			print("HOTASManager: Found HOTAS device - ", device_name, " (ID: ", device_id, ")")
			hotas_connected.emit(connected_hotas[device_id])
			_initialize_device_state(device_id)

func _identify_hotas_device(device_name: String, _device_guid: String) -> Dictionary:
	device_name = device_name.to_lower()

	if "x56" in device_name and "saitek" in device_name or "x56" in device_name and "logitech" in device_name:
		return logitech_x56_profile
	elif "yoke" in device_name and "logitech" in device_name:
		return logitech_yoke_profile

	return {}

func _initialize_device_state(device_id: int):
	if not connected_hotas.has(device_id):
		return

	var device_info = connected_hotas[device_id]
	var profile = device_info.profile

	for axis_name in profile.axes:
		device_info.axis_values[axis_name] = 0.0

	for button_name in profile.buttons:
		device_info.button_states[button_name] = false

func _process_hotas_inputs():
	for device_id in connected_hotas:
		_process_device_inputs(device_id)

func _process_device_inputs(device_id: int):
	var device_info = connected_hotas[device_id]
	var profile = device_info.profile

	for axis_name in profile.axes:
		var axis_config = profile.axes[axis_name]
		var axis_id = axis_config.id
		var raw_value = Input.get_joy_axis(device_id, axis_id)

		var processed_value = _process_axis_value(device_id, axis_name, raw_value)
		var stored_value = device_info.axis_values.get(axis_name, 0.0)

		if abs(processed_value - stored_value) > 0.01:
			device_info.axis_values[axis_name] = processed_value
			device_info.last_input = Time.get_unix_time_from_system()
			hotas_input_received.emit(device_id, axis_name, processed_value)

	for button_name in profile.buttons:
		var button_id = profile.buttons[button_name]
		var is_pressed = Input.is_joy_button_pressed(device_id, button_id)
		var was_pressed = device_info.button_states.get(button_name, false)

		if is_pressed != was_pressed:
			device_info.button_states[button_name] = is_pressed
			device_info.last_input = Time.get_unix_time_from_system()
			hotas_input_received.emit(device_id, button_name, is_pressed)

func _process_axis_value(device_id: int, axis_name: String, raw_value: float) -> float:
	var device_info = connected_hotas[device_id]
	var profile = device_info.profile
	var axis_config = profile.axes.get(axis_name, {})

	var processed_value = raw_value

	if axis_config.get("invert", false):
		processed_value *= -1.0

	var range_key = str(device_id) + "_" + axis_name
	if axis_ranges.has(range_key):
		var range_data = axis_ranges[range_key]
		var center = range_data.get("center", 0.0)
		var min_val = range_data.get("min", -1.0)
		var max_val = range_data.get("max", 1.0)

		if processed_value > center:
			processed_value = (processed_value - center) / (max_val - center)
		else:
			processed_value = (processed_value - center) / (center - min_val)

	var curve = axis_config.get("curve", "linear")
	match curve:
		"linear":
			pass
		"quadratic":
			processed_value = sign(processed_value) * processed_value * processed_value
		"cubic":
			processed_value = processed_value * processed_value * processed_value
		"exponential":
			processed_value = sign(processed_value) * (pow(abs(processed_value), 2.0))

	return clamp(processed_value, -1.0, 1.0)

func calibrate_device_axis(device_id: int, axis_name: String, duration: float = 10.0) -> bool:
	if not connected_hotas.has(device_id):
		return false

	var device_info = connected_hotas[device_id]
	var profile = device_info.profile

	if not profile.axes.has(axis_name):
		return false

	var axis_id = profile.axes[axis_name].id
	var range_key = str(device_id) + "_" + axis_name

	print("HOTASManager: Starting calibration for ", device_info.name, " axis ", axis_name)
	calibration_in_progress[range_key] = true

	var min_value = 0.0
	var max_value = 0.0
	var center_value = 0.0
	var sample_count = 0
	var start_time = Time.get_unix_time_from_system()

	while Time.get_unix_time_from_system() - start_time < duration:
		var current_value = Input.get_joy_axis(device_id, axis_id)

		if sample_count == 0:
			min_value = current_value
			max_value = current_value
			center_value = current_value
		else:
			min_value = min(min_value, current_value)
			max_value = max(max_value, current_value)
			center_value += current_value

		sample_count += 1
		await get_tree().process_frame

	center_value /= sample_count

	axis_ranges[range_key] = {
		"min": min_value,
		"max": max_value,
		"center": center_value
	}

	calibration_in_progress.erase(range_key)
	device_info.calibrated = true

	_save_calibration_data()
	print("HOTASManager: Calibration complete for ", device_info.name, " axis ", axis_name)
	hotas_calibration_complete.emit(device_id, axis_name)

	return true

func get_station_input_mapping(station: String, hotas_input: String) -> String:
	if not station_hotas_mappings.has(station):
		return ""

	var station_mapping = station_hotas_mappings[station]

	for action in station_mapping:
		if station_mapping[action] == hotas_input:
			return action

	return ""

func send_station_input(station: String, hotas_input: String, value):
	var action = get_station_input_mapping(station, hotas_input)
	if action == "" or not GameState:
		return

	var context = {
		"source": "hotas",
		"device": "hotas_manager",
		"raw_input": hotas_input
	}

	GameState.send_input_event(action, value, context)

func is_hotas_connected() -> bool:
	return connected_hotas.size() > 0

func get_connected_hotas_count() -> int:
	return connected_hotas.size()

func get_hotas_info(device_id: int) -> Dictionary:
	return connected_hotas.get(device_id, {})

func get_all_hotas_devices() -> Dictionary:
	return connected_hotas

func is_device_calibrated(device_id: int) -> bool:
	if not connected_hotas.has(device_id):
		return false
	return connected_hotas[device_id].get("calibrated", false)

func get_axis_value(device_id: int, axis_name: String) -> float:
	if not connected_hotas.has(device_id):
		return 0.0

	var device_info = connected_hotas[device_id]
	return device_info.axis_values.get(axis_name, 0.0)

func get_button_state(device_id: int, button_name: String) -> bool:
	if not connected_hotas.has(device_id):
		return false

	var device_info = connected_hotas[device_id]
	return device_info.button_states.get(button_name, false)

func set_axis_curve(device_id: int, axis_name: String, curve_type: String):
	if not connected_hotas.has(device_id):
		return

	var device_info = connected_hotas[device_id]
	var profile = device_info.profile

	if profile.axes.has(axis_name):
		profile.axes[axis_name]["curve"] = curve_type

func _on_joy_connection_changed(device_id: int, connected: bool):
	if connected:
		var device_name = Input.get_joy_name(device_id)
		var device_guid = Input.get_joy_guid(device_id)

		var profile = _identify_hotas_device(device_name, device_guid)
		if profile:
			connected_hotas[device_id] = {
				"profile": profile,
				"name": device_name,
				"guid": device_guid,
				"calibrated": false,
				"last_input": 0.0,
				"axis_values": {},
				"button_states": {}
			}

			print("HOTASManager: HOTAS device connected - ", device_name)
			hotas_connected.emit(connected_hotas[device_id])
			_initialize_device_state(device_id)
	else:
		if connected_hotas.has(device_id):
			var device_info = connected_hotas[device_id]
			print("HOTASManager: HOTAS device disconnected - ", device_info.name)
			hotas_disconnected.emit(device_info)
			connected_hotas.erase(device_id)

func _load_device_profiles():
	var file_path = "user://hotas_profiles.cfg"

	if not FileAccess.file_exists(file_path):
		return

	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()

		var json = JSON.new()
		var parse_result = json.parse(json_string)

		if parse_result == OK:
			device_profiles = json.data

func _save_device_profiles():
	var file_path = "user://hotas_profiles.cfg"
	var file = FileAccess.open(file_path, FileAccess.WRITE)

	if file:
		var json_string = JSON.stringify(device_profiles)
		file.store_string(json_string)
		file.close()

func _load_calibration_data():
	var file_path = "user://hotas_calibration.cfg"

	if not FileAccess.file_exists(file_path):
		return

	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()

		var json = JSON.new()
		var parse_result = json.parse(json_string)

		if parse_result == OK:
			axis_ranges = json.data

func _save_calibration_data():
	var file_path = "user://hotas_calibration.cfg"
	var file = FileAccess.open(file_path, FileAccess.WRITE)

	if file:
		var json_string = JSON.stringify(axis_ranges)
		file.store_string(json_string)
		file.close()

func get_device_status() -> Dictionary:
	var status = {}

	for device_id in connected_hotas:
		var device_info = connected_hotas[device_id]
		var last_input = device_info.get("last_input", 0.0)
		var is_active = Time.get_unix_time_from_system() - last_input < 5.0

		status[device_id] = {
			"name": device_info.get("name", "Unknown"),
			"calibrated": device_info.get("calibrated", false),
			"active": is_active,
			"profile": device_info.profile.get("name", "Unknown")
		}

	return status
