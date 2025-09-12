extends Control

@onready var connection_label = $MainContainer/LeftPanel/ConnectionStatus/StatusContainer/ConnectionLabel
@onready var current_heading = $MainContainer/LeftPanel/NavigationControls/NavContainer/CurrentHeading
@onready var current_speed = $MainContainer/LeftPanel/NavigationControls/NavContainer/CurrentSpeed
@onready var heading_input = $MainContainer/LeftPanel/NavigationControls/NavContainer/DesiredHeadingContainer/HeadingInput
@onready var warp_slider = $MainContainer/LeftPanel/NavigationControls/NavContainer/WarpFactorContainer/WarpSlider
@onready var warp_value = $MainContainer/LeftPanel/NavigationControls/NavContainer/WarpFactorContainer/WarpValue

@onready var autopilot_mode_option = $MainContainer/LeftPanel/AutopilotPanel/AutopilotContainer/AutopilotModeOption
@onready var autopilot_status = $MainContainer/LeftPanel/AutopilotPanel/AutopilotContainer/AutopilotStatus
@onready var station_keeping_button = $MainContainer/LeftPanel/AutopilotPanel/AutopilotContainer/PresetManeuvers/ManeuverButtons/StationKeepingButton
@onready var evasive_button = $MainContainer/LeftPanel/AutopilotPanel/AutopilotContainer/PresetManeuvers/ManeuverButtons/EvasiveButton
@onready var intercept_button = $MainContainer/LeftPanel/AutopilotPanel/AutopilotContainer/PresetManeuvers/ManeuverButtons/InterceptButton
@onready var emergency_stop_button = $MainContainer/LeftPanel/AutopilotPanel/AutopilotContainer/PresetManeuvers/ManeuverButtons/EmergencyStopButton

@onready var hotas_status = $MainContainer/LeftPanel/InputDeviceStatus/InputContainer/HOTASStatus
@onready var yoke_status = $MainContainer/LeftPanel/InputDeviceStatus/InputContainer/YokeStatus
@onready var throttle_reading = $MainContainer/LeftPanel/InputDeviceStatus/InputContainer/InputReadings/ThrottleReading
@onready var rudder_reading = $MainContainer/LeftPanel/InputDeviceStatus/InputContainer/InputReadings/RudderReading
@onready var pitch_reading = $MainContainer/LeftPanel/InputDeviceStatus/InputContainer/InputReadings/PitchReading
@onready var roll_reading = $MainContainer/LeftPanel/InputDeviceStatus/InputContainer/InputReadings/RollReading

@onready var nav_camera = $MainContainer/CenterPanel/NavigationMap/MapContainer/MapViewport/NavCamera
@onready var navigation_objects = $MainContainer/CenterPanel/NavigationMap/MapContainer/MapViewport/NavigationObjects
@onready var waypoint_system = $MainContainer/CenterPanel/NavigationMap/MapContainer/MapViewport/WaypointSystem
@onready var zoom_out_button = $MainContainer/CenterPanel/NavigationMap/MapContainer/MapControls/ZoomOutButton
@onready var zoom_in_button = $MainContainer/CenterPanel/NavigationMap/MapContainer/MapControls/ZoomInButton
@onready var center_button = $MainContainer/CenterPanel/NavigationMap/MapContainer/MapControls/CenterButton
@onready var plot_course_button = $MainContainer/CenterPanel/NavigationMap/MapContainer/MapControls/PlotCourseButton
@onready var clear_waypoints_button = $MainContainer/CenterPanel/NavigationMap/MapContainer/MapControls/ClearWaypointsButton

@onready var collision_warning = $MainContainer/RightPanel/ProximityAlerts/AlertContainer/CollisionWarning
@onready var alerts_vbox = $MainContainer/RightPanel/ProximityAlerts/AlertContainer/AlertsScroll/AlertsVBox
@onready var log_text = $MainContainer/RightPanel/TravelLog/LogContainer/LogScroll/LogText
@onready var clear_log_button = $MainContainer/RightPanel/TravelLog/LogContainer/LogControls/ClearLogButton
@onready var save_log_button = $MainContainer/RightPanel/TravelLog/LogContainer/LogControls/SaveLogButton
@onready var waypoint_vbox = $MainContainer/RightPanel/WaypointList/WaypointContainer/WaypointScroll/WaypointVBox
@onready var add_waypoint_button = $MainContainer/RightPanel/WaypointList/WaypointContainer/WaypointControls/AddWaypointButton
@onready var remove_waypoint_button = $MainContainer/RightPanel/WaypointList/WaypointContainer/WaypointControls/RemoveWaypointButton

@onready var back_button = $BackButton

# Debug settings
const DEBUG_ENABLED: bool = true
const DEBUG_PREFIX: String = "[HELM_DEBUG] "

var current_throttle: float = 0.0
var current_rudder: float = 0.0
var current_pitch: float = 0.0
var current_roll: float = 0.0
var desired_heading: float = 0.0
var current_warp_factor: float = 1.0
var autopilot_mode: String = "manual"
var is_plotting_course: bool = false

var rendered_nav_objects: Dictionary = {}
var waypoints: Array = []
var nav_map_scale: float = 0.01
var player_ship_position: Vector3 = Vector3.ZERO
var ship_velocity: Vector3 = Vector3.ZERO
var ship_heading: float = 0.0

var autopilot_modes: Array = ["manual", "position", "heading", "follow", "station_keeping"]
var log_entries: Array = []
var proximity_alerts: Array = []

var input_update_rate: float = 1.0/60.0
var last_input_time: float = 0.0

# Debug helpers
func debug_log(message: String):
	if DEBUG_ENABLED:
		print(DEBUG_PREFIX + message)

func debug_warn(message: String):
	if DEBUG_ENABLED:
		print_rich("[color=yellow]" + DEBUG_PREFIX + "WARNING: " + message + "[/color]")

func debug_error(message: String):
	if DEBUG_ENABLED:
		print_rich("[color=red]" + DEBUG_PREFIX + "ERROR: " + message + "[/color]")

func _ready():
	debug_log("Helm station _ready() started")
	
	_setup_connections()
	_setup_ui()
	_initialize_helm_station()

	debug_log("Switching to helm station...")
	GameState.switch_station("helm")
	GameState.audio_manager.set_station_audio_profile("helm")
	GameState.audio_manager.play_music("exploration")
	
	debug_log("Helm station initialization complete")

func _setup_connections():
	debug_log("Setting up connections...")
	
	if GameState:
		debug_log("Connecting GameState signals...")
		GameState.universe_state_updated.connect(_on_universe_updated)
		GameState.connection_status_changed.connect(_on_connection_status_changed)
		GameState.alert_level_changed.connect(_on_alert_level_changed)
		debug_log("GameState signals connected")
	else:
		debug_error("GameState is null!")

	if GameState.input_manager:
		debug_log("Connecting InputManager signals...")
		GameState.input_manager.input_event_generated.connect(_on_input_event)
		GameState.input_manager.device_connected.connect(_on_input_device_connected)
		GameState.input_manager.device_disconnected.connect(_on_input_device_disconnected)
		debug_log("InputManager signals connected")
	else:
		debug_warn("GameState.input_manager is null")

	if GameState.hotas_manager:
		debug_log("Connecting HOTASManager signals...")
		GameState.hotas_manager.hotas_input_received.connect(_on_hotas_input)
		GameState.hotas_manager.hotas_connected.connect(_on_hotas_connected)
		GameState.hotas_manager.hotas_disconnected.connect(_on_hotas_disconnected)
		debug_log("HOTASManager signals connected")
	else:
		debug_warn("GameState.hotas_manager is null")

	debug_log("Connecting UI signals...")
	heading_input.value_changed.connect(_on_desired_heading_changed)
	warp_slider.value_changed.connect(_on_warp_factor_changed)
	autopilot_mode_option.item_selected.connect(_on_autopilot_mode_changed)

	station_keeping_button.pressed.connect(_activate_station_keeping)
	evasive_button.pressed.connect(_activate_evasive_maneuvers)
	intercept_button.pressed.connect(_activate_intercept_course)
	emergency_stop_button.pressed.connect(_activate_emergency_stop)

	zoom_out_button.pressed.connect(_zoom_nav_map_out)
	zoom_in_button.pressed.connect(_zoom_nav_map_in)
	center_button.pressed.connect(_center_nav_map)
	plot_course_button.pressed.connect(_toggle_course_plotting)
	clear_waypoints_button.pressed.connect(_clear_waypoints)

	clear_log_button.pressed.connect(_clear_travel_log)
	save_log_button.pressed.connect(_save_travel_log)
	add_waypoint_button.pressed.connect(_add_manual_waypoint)
	remove_waypoint_button.pressed.connect(_remove_selected_waypoint)

	back_button.pressed.connect(_on_back_pressed)
	
	debug_log("All connections established")

func _setup_ui():
	debug_log("Setting up UI...")
	
	debug_log("Adding autopilot modes to dropdown...")
	for mode in autopilot_modes:
		autopilot_mode_option.add_item(mode.capitalize().replace("_", " "))
		debug_log("Added autopilot mode: " + mode)

	nav_camera.zoom = Vector2(1.0, 1.0)
	warp_value.text = str(current_warp_factor) + "x"
	autopilot_status.text = "Status: " + autopilot_mode.capitalize().replace("_", " ") + " Control"
	
	debug_log("UI setup complete - nav_map_scale: " + str(nav_map_scale) + ", warp_factor: " + str(current_warp_factor))

func _initialize_helm_station():
	debug_log("Initializing helm station...")
	
	GameState.input_manager.set_station("helm")
	_add_travel_log_entry("Helm station initialized", "system")
	_add_travel_log_entry("Navigation systems online", "system")
	_update_input_device_status()
	
	debug_log("Helm station initialized successfully")

func _process(delta):
	_update_ui()
	_update_navigation_map()
	_update_proximity_alerts()
	_process_helm_controls(delta)

	if GameState.input_manager.is_hotas_connected():
		_process_hotas_input()

func _update_ui():
	var status = GameState.get_connection_status()
	connection_label.text = "Status: " + status.to_upper()

	match status:
		"Connected":
			connection_label.modulate = Color.GREEN
		"Connecting":
			connection_label.modulate = Color.YELLOW
		_:
			connection_label.modulate = Color.RED

	var player_ship = GameState.get_player_ship()
	if player_ship:
		_update_ship_status(player_ship)
	else:
		debug_warn("No player ship data available")

func _update_ship_status(ship_data: Dictionary):
	debug_log("Updating ship status with data keys: " + str(ship_data.keys()))
	
	var position = normalize_vector_dict(ship_data.get("position", {}))
	if position.has("x") and position.has("y") and position.has("z"):
		var old_pos = player_ship_position
		player_ship_position = Vector3(position.x, position.y, position.z)
		if old_pos.distance_to(player_ship_position) > 100:  # Only log significant position changes
			debug_log("Ship position updated: " + str(player_ship_position))
	else:
		debug_warn("Ship position data incomplete: " + str(position))

	var velocity = normalize_vector_dict(ship_data.get("velocity", {}))
	if velocity.has("x") and velocity.has("y") and velocity.has("z"):
		ship_velocity = Vector3(velocity.x, velocity.y, velocity.z)
		var speed = ship_velocity.length()
		current_speed.text = "Current Speed: " + str(int(speed)) + " m/s"
		debug_log("Ship speed updated: " + str(speed) + " m/s")
	else:
		debug_warn("Ship velocity data incomplete: " + str(velocity))

	var rotation = normalize_vector_dict(ship_data.get("rotation", {}))
	if rotation.has("y"):
		var old_heading = ship_heading
		ship_heading = rotation.y
		current_heading.text = "Current Heading: " + str(int(rad_to_deg(ship_heading))) + "°"
		if abs(old_heading - ship_heading) > 0.1:  # Only log significant heading changes
			debug_log("Ship heading updated: " + str(rad_to_deg(ship_heading)) + "°")
	else:
		debug_warn("Ship rotation data incomplete: " + str(rotation))

func _update_navigation_map():
	var objects = GameState.get_universe_objects()
	debug_log("Updating navigation map with " + str(objects.size()) + " objects")

	for obj_id in objects:
		var obj = objects[obj_id]
		_create_or_update_nav_object(obj_id, obj)

	for obj_id in rendered_nav_objects.keys():
		if not objects.has(obj_id):
			debug_log("Removing nav object: " + obj_id)
			_remove_nav_object(obj_id)

	_update_waypoint_display()

func _update_proximity_alerts():
	proximity_alerts.clear()
	var objects = GameState.get_universe_objects()

	var closest_distance = INF
	var collision_risk = false
	var alert_count = 0

	for obj_id in objects:
		var obj = objects[obj_id]
		if obj.get("is_player_ship", false):
			continue

		var position = obj.get("position", {})
		if position.has("x") and position.has("z"):
			var obj_pos = Vector3(position.x, position.get("y", 0), position.z)
			var distance = player_ship_position.distance_to(obj_pos)

			if distance < 1000:  # Within 1km
				alert_count += 1
				var alert = {
					"object_id": obj_id,
					"name": obj.get("name", "Unknown"),
					"distance": distance,
					"type": obj.get("type", "unknown")
				}
				proximity_alerts.append(alert)

				if distance < 200:  # Collision warning threshold
					collision_risk = true
					debug_warn("COLLISION RISK: " + obj.get("name", "Unknown") + " at " + str(int(distance)) + "m")

			if distance < closest_distance:
				closest_distance = distance

	if alert_count > 0:
		debug_log("Proximity alerts: " + str(alert_count) + ", closest: " + str(int(closest_distance)) + "m")

	if collision_risk:
		collision_warning.text = "COLLISION WARNING"
		collision_warning.modulate = Color.RED
	elif proximity_alerts.size() > 0:
		collision_warning.text = "PROXIMITY ALERT"
		collision_warning.modulate = Color.YELLOW
	else:
		collision_warning.text = "All Clear"
		collision_warning.modulate = Color.GREEN

	_update_proximity_alert_list()

func _update_proximity_alert_list():
	# Clear existing alerts
	for child in alerts_vbox.get_children():
		child.queue_free()

	debug_log("Updating proximity alert list with " + str(proximity_alerts.size()) + " alerts")

	for alert in proximity_alerts:
		var alert_label = Label.new()
		var distance_text = str(int(alert.distance)) + "m"
		alert_label.text = alert.name + " - " + distance_text
		alert_label.add_theme_color_override("font_color", Color.YELLOW if alert.distance < 500 else Color.WHITE)
		alert_label.add_theme_font_size_override("font_size", 10)
		alerts_vbox.add_child(alert_label)

func _process_helm_controls(delta: float):
	if Time.get_unix_time_from_system() - last_input_time < input_update_rate:
		return

	var input_changed = false

	# Process keyboard input for manual control
	if Input.is_action_pressed("helm_throttle"):
		var new_throttle = Input.get_action_strength("helm_throttle")
		if abs(new_throttle - current_throttle) > 0.01:
			debug_log("Keyboard throttle input: " + str(new_throttle))
			current_throttle = new_throttle
			input_changed = true

	if Input.is_action_pressed("helm_rudder"):
		var new_rudder = Input.get_action_strength("helm_rudder") * 2.0 - 1.0
		if abs(new_rudder - current_rudder) > 0.01:
			debug_log("Keyboard rudder input: " + str(new_rudder))
			current_rudder = new_rudder
			input_changed = true

	if input_changed:
		debug_log("Sending flight controls - T:" + str(current_throttle) + " R:" + str(current_rudder))
		_send_flight_controls()

	last_input_time = Time.get_unix_time_from_system()

func _process_hotas_input():
	if not GameState.hotas_manager.is_hotas_connected():
		return

	var hotas_devices = GameState.hotas_manager.get_all_hotas_devices()
	debug_log("Processing HOTAS input for " + str(hotas_devices.size()) + " devices")

	for device_id in hotas_devices:
		var throttle_val = GameState.hotas_manager.get_axis_value(device_id, "throttle_left")
		var rudder_val = GameState.hotas_manager.get_axis_value(device_id, "yoke_x")
		var pitch_val = GameState.hotas_manager.get_axis_value(device_id, "yoke_y")
		var roll_val = GameState.hotas_manager.get_axis_value(device_id, "stick_twist")

		var input_changed = false

		if abs(throttle_val - current_throttle) > 0.01:
			debug_log("HOTAS throttle: " + str(throttle_val))
			current_throttle = clamp(throttle_val, 0.0, 1.0)
			throttle_reading.text = "Throttle: " + str(int(current_throttle * 100)) + "%"
			input_changed = true

		if abs(rudder_val - current_rudder) > 0.01:
			debug_log("HOTAS rudder: " + str(rudder_val))
			current_rudder = clamp(rudder_val, -1.0, 1.0)
			rudder_reading.text = "Rudder: " + str(int(current_rudder * 100)) + "%"
			input_changed = true

		if abs(pitch_val - current_pitch) > 0.01:
			debug_log("HOTAS pitch: " + str(pitch_val))
			current_pitch = clamp(pitch_val, -1.0, 1.0)
			pitch_reading.text = "Pitch: " + str(int(current_pitch * 100)) + "%"
			input_changed = true

		if abs(roll_val - current_roll) > 0.01:
			debug_log("HOTAS roll: " + str(roll_val))
			current_roll = clamp(roll_val, -1.0, 1.0)
			roll_reading.text = "Roll: " + str(int(current_roll * 100)) + "%"
			input_changed = true

		if input_changed:
			_send_flight_controls()

func _send_flight_controls():
	if not GameState.is_station_authenticated():
		debug_warn("Cannot send flight controls - station not authenticated")
		return

	debug_log("Sending flight controls: T=" + str(current_throttle) + " R=" + str(current_rudder) + " P=" + str(current_pitch) + " Roll=" + str(current_roll))
	
	GameState.send_input_event("throttle", current_throttle)
	GameState.send_input_event("rudder", current_rudder)
	GameState.send_input_event("pitch", current_pitch)
	GameState.send_input_event("roll", current_roll)

func _create_or_update_nav_object(obj_id: String, obj_data: Dictionary):
	var position = normalize_vector_dict(obj_data.get("position", {}))
	if not position.has("x") or not position.has("z"):
		debug_warn("Object does not have position")
		return

	var nav_pos = Vector2(position.x, position.z) * nav_map_scale

	if not rendered_nav_objects.has(obj_id):
		debug_log("Creating nav object: " + obj_id + " (" + obj_data.get("type", "unknown") + ")")
		var nav_object = _create_nav_object_node(obj_id, obj_data)
		if nav_object:
			rendered_nav_objects[obj_id] = nav_object
			navigation_objects.add_child(nav_object)

	var nav_object = rendered_nav_objects.get(obj_id)
	if nav_object:
		nav_object.position = nav_pos

func _create_nav_object_node(obj_id: String, obj_data: Dictionary) -> Node2D:
	var node = Node2D.new()
	node.name = obj_id

	var shape = _create_nav_shape(obj_data)
	node.add_child(shape)
	
	debug_log("Created nav object node for " + obj_id + " with shape type: " + obj_data.get("type", "unknown"))

	return node

func _create_nav_shape(obj_data: Dictionary) -> Node2D:
	var obj_type = obj_data.get("type", "unknown")
	var is_player = obj_data.get("is_player_ship", false)

	match obj_type:
		"ship":
			var polygon = Polygon2D.new()
			polygon.polygon = PackedVector2Array([
				Vector2(-8, -12), Vector2(0, 12), Vector2(8, -12)
			])
			polygon.color = Color.CYAN if is_player else Color.ORANGE
			return polygon
		"station":
			var rect = Polygon2D.new()
			rect.polygon = PackedVector2Array([
				Vector2(-10, -10), Vector2(10, -10), Vector2(10, 10), Vector2(-10, 10)
			])
			rect.color = Color.GREEN
			return rect
		"planet":
			var circle = Polygon2D.new()
			var points = PackedVector2Array()
			var radius = 15
			for i in range(12):
				var angle = i * PI * 2 / 12
				points.append(Vector2(cos(angle), sin(angle)) * radius)
			circle.polygon = points
			circle.color = Color.BLUE
			return circle
		_:
			var dot = Polygon2D.new()
			dot.polygon = PackedVector2Array([
				Vector2(-3, -3), Vector2(3, -3), Vector2(3, 3), Vector2(-3, 3)
			])
			dot.color = Color.WHITE
			return dot

func _remove_nav_object(obj_id: String):
	if rendered_nav_objects.has(obj_id):
		var nav_object = rendered_nav_objects[obj_id]
		nav_object.queue_free()
		rendered_nav_objects.erase(obj_id)

func _update_waypoint_display():
	# Clear existing waypoints
	for child in waypoint_system.get_children():
		child.queue_free()

	debug_log("Updating waypoint display with " + str(waypoints.size()) + " waypoints")

	for i in range(waypoints.size()):
		var waypoint = waypoints[i]
		var waypoint_pos = Vector2(waypoint.x, waypoint.z) * nav_map_scale

		var waypoint_node = Node2D.new()
		var circle = Polygon2D.new()
		var points = PackedVector2Array()
		for j in range(8):
			var angle = j * PI * 2 / 8
			points.append(Vector2(cos(angle), sin(angle)) * 5)
		circle.polygon = points
		circle.color = Color.YELLOW

		waypoint_node.add_child(circle)
		waypoint_node.position = waypoint_pos

		var label = Label.new()
		label.text = str(i + 1)
		label.position = Vector2(8, -8)
		label.add_theme_color_override("font_color", Color.YELLOW)
		label.add_theme_font_size_override("font_size", 8)
		waypoint_node.add_child(label)

		waypoint_system.add_child(waypoint_node)

	_update_waypoint_list()

func _update_waypoint_list():
	# Clear existing waypoint list
	for child in waypoint_vbox.get_children():
		child.queue_free()

	for i in range(waypoints.size()):
		var waypoint = waypoints[i]
		var waypoint_label = Label.new()
		waypoint_label.text = "%d: (%.0f, %.0f, %.0f)" % [i + 1, waypoint.x, waypoint.y, waypoint.z]
		waypoint_label.add_theme_color_override("font_color", Color.WHITE)
		waypoint_label.add_theme_font_size_override("font_size", 10)
		waypoint_vbox.add_child(waypoint_label)

func _on_desired_heading_changed(value: float):
	debug_log("Desired heading changed to: " + str(value) + "°")
	desired_heading = value
	if GameState.is_station_authenticated():
		GameState.send_input_event("desired_heading", desired_heading)
		_add_travel_log_entry("Heading set to " + str(int(desired_heading)) + "°", "navigation")
	else:
		debug_warn("Cannot send heading change - station not authenticated")

func _on_warp_factor_changed(value: float):
	debug_log("Warp factor changed to: " + str(value) + "x")
	current_warp_factor = value
	warp_value.text = str(value) + "x"
	if GameState.is_station_authenticated():
		GameState.send_input_event("warp_factor", current_warp_factor)
		_add_travel_log_entry("Warp factor set to " + str(value) + "x", "navigation")
	else:
		debug_warn("Cannot send warp factor change - station not authenticated")

func _on_autopilot_mode_changed(index: int):
	if index >= 0 and index < autopilot_modes.size():
		var old_mode = autopilot_mode
		autopilot_mode = autopilot_modes[index]
		debug_log("Autopilot mode changed from '" + old_mode + "' to '" + autopilot_mode + "'")
		autopilot_status.text = "Status: " + autopilot_mode.capitalize().replace("_", " ") + " Control"

		if GameState.is_station_authenticated():
			GameState.send_input_event("autopilot_mode", autopilot_mode)
			_add_travel_log_entry("Autopilot mode: " + autopilot_mode.replace("_", " "), "autopilot")
		else:
			debug_warn("Cannot send autopilot mode change - station not authenticated")
	else:
		debug_error("Invalid autopilot mode index: " + str(index))

func _activate_station_keeping():
	debug_log("Activating station keeping maneuver")
	autopilot_mode = "station_keeping"
	autopilot_mode_option.select(autopilot_modes.find("station_keeping"))
	if GameState.is_station_authenticated():
		GameState.send_input_event("autopilot_mode", "station_keeping")
		_add_travel_log_entry("Station keeping maneuver activated", "autopilot")
	else:
		debug_warn("Cannot activate station keeping - station not authenticated")
	GameState.audio_manager.play_success_sound()

func _activate_evasive_maneuvers():
	debug_log("Activating evasive maneuvers")
	if GameState.is_station_authenticated():
		var context = {"maneuver_type": "evasive", "intensity": 0.8}
		GameState.send_input_event("evasive_maneuvers", true, context)
		_add_travel_log_entry("Evasive maneuvers activated", "maneuver")
	else:
		debug_warn("Cannot activate evasive maneuvers - station not authenticated")
	GameState.audio_manager.play_success_sound()

func _activate_intercept_course():
	debug_log("Activating intercept course")
	if GameState.is_station_authenticated():
		var context = {"maneuver_type": "intercept"}
		GameState.send_input_event("intercept_course", true, context)
		_add_travel_log_entry("Intercept course plotted", "maneuver")
	else:
		debug_warn("Cannot activate intercept course - station not authenticated")
	GameState.audio_manager.play_success_sound()

func _activate_emergency_stop():
	debug_log("EMERGENCY STOP ACTIVATED!")
	current_throttle = 0.0
	if GameState.is_station_authenticated():
		GameState.send_input_event("throttle", 0.0)
		GameState.send_input_event("emergency_stop", true)
		_add_travel_log_entry("EMERGENCY STOP ACTIVATED", "emergency")
	else:
		debug_error("Cannot activate emergency stop - station not authenticated")
	GameState.audio_manager.play_error_sound()

func _zoom_nav_map_out():
	var old_zoom = nav_camera.zoom
	var new_zoom = nav_camera.zoom / 1.5
	nav_camera.zoom = new_zoom.clamp(Vector2(0.1, 0.1), Vector2(10, 10))
	debug_log("Nav map zoomed out from " + str(old_zoom) + " to " + str(nav_camera.zoom))
	GameState.audio_manager.play_button_sound()

func _zoom_nav_map_in():
	var old_zoom = nav_camera.zoom
	var new_zoom = nav_camera.zoom * 1.5
	nav_camera.zoom = new_zoom.clamp(Vector2(0.1, 0.1), Vector2(10, 10))
	debug_log("Nav map zoomed in from " + str(old_zoom) + " to " + str(nav_camera.zoom))
	GameState.audio_manager.play_button_sound()

func _center_nav_map():
	var old_pos = nav_camera.position
	nav_camera.position = Vector2(player_ship_position.x, player_ship_position.z) * nav_map_scale
	debug_log("Nav map centered from " + str(old_pos) + " to " + str(nav_camera.position))
	GameState.audio_manager.play_button_sound()

func _toggle_course_plotting():
	is_plotting_course = not is_plotting_course
	debug_log("Course plotting mode: " + ("ON" if is_plotting_course else "OFF"))
	plot_course_button.text = "Stop Plotting" if is_plotting_course else "Plot Course"
	plot_course_button.modulate = Color.YELLOW if is_plotting_course else Color.WHITE
	GameState.audio_manager.play_button_sound()

func _clear_waypoints():
	var waypoint_count = waypoints.size()
	waypoints.clear()
	debug_log("Cleared " + str(waypoint_count) + " waypoints")
	if GameState.is_station_authenticated():
		GameState.send_input_event("navigation_plot", waypoints)
		_add_travel_log_entry("Navigation waypoints cleared", "navigation")
	else:
		debug_warn("Cannot clear waypoints - station not authenticated")
	GameState.audio_manager.play_success_sound()

func _add_manual_waypoint():
	var new_waypoint = player_ship_position + Vector3(1000, 0, 1000)
	waypoints.append(new_waypoint)
	debug_log("Added manual waypoint " + str(waypoints.size()) + " at " + str(new_waypoint))
	if GameState.is_station_authenticated():
		GameState.send_input_event("navigation_plot", _waypoints_to_array())
		_add_travel_log_entry("Waypoint added at " + str(new_waypoint), "navigation")
	else:
		debug_warn("Cannot add waypoint - station not authenticated")
	GameState.audio_manager.play_success_sound()

func _remove_selected_waypoint():
	if waypoints.size() > 0:
		var removed_waypoint = waypoints.pop_back()
		debug_log("Removed waypoint: " + str(removed_waypoint) + " (" + str(waypoints.size()) + " remaining)")
		if GameState.is_station_authenticated():
			GameState.send_input_event("navigation_plot", _waypoints_to_array())
			_add_travel_log_entry("Last waypoint removed", "navigation")
		else:
			debug_warn("Cannot remove waypoint - station not authenticated")
		GameState.audio_manager.play_success_sound()
	else:
		debug_log("Cannot remove waypoint - no waypoints to remove")

func _waypoints_to_array() -> Array:
	var waypoint_array = []
	for waypoint in waypoints:
		waypoint_array.append({"x": waypoint.x, "y": waypoint.y, "z": waypoint.z})
	debug_log("Converted " + str(waypoints.size()) + " waypoints to array")
	return waypoint_array

func _update_input_device_status():
	debug_log("Updating input device status...")
	
	var hotas_info = GameState.hotas_manager.get_device_status()
	var input_info = GameState.input_manager.get_hotas_status()

	debug_log("HOTAS info - connected: " + str(input_info.connected) + ", count: " + str(input_info.count))

	if input_info.connected:
		hotas_status.text = "HOTAS: Connected (" + str(input_info.count) + ")"
		hotas_status.modulate = Color.GREEN
	else:
		hotas_status.text = "HOTAS: Not Connected"
		hotas_status.modulate = Color.ORANGE

	yoke_status.text = "Flight Yoke: Not Connected"
	var yoke_found = false
	for device in input_info.devices:
		debug_log("Input device: " + device.name)
		if "yoke" in device.name.to_lower():
			yoke_status.text = "Flight Yoke: Connected"
			yoke_status.modulate = Color.GREEN
			yoke_found = true
			break
	
	if not yoke_found:
		yoke_status.modulate = Color.ORANGE
	
	debug_log("Input device status update complete")

func _add_travel_log_entry(message: String, log_type: String = "info"):
	var timestamp = Time.get_datetime_string_from_system().substr(11, 8)
	var color = "white"

	match log_type:
		"error": color = "red"
		"emergency": color = "red"
		"maneuver": color = "yellow"
		"navigation": color = "cyan"
		"autopilot": color = "orange"
		"system": color = "green"

	var formatted_entry = "[color=gray]%s[/color] [color=%s]%s[/color]" % [timestamp, color, message]
	log_text.append_text(formatted_entry + "\n")

	log_entries.append({
		"timestamp": timestamp,
		"message": message,
		"type": log_type
	})

	if log_entries.size() > 500:
		log_entries.pop_front()

	debug_log("Added log entry [" + log_type + "]: " + message)

func _clear_travel_log():
	var entry_count = log_entries.size()
	log_text.clear()
	log_text.append_text("[color=green]Travel log cleared[/color]\n")
	log_entries.clear()
	debug_log("Cleared travel log (" + str(entry_count) + " entries)")
	GameState.audio_manager.play_success_sound()

func _save_travel_log():
	var file_path = "user://helm_log_" + Time.get_datetime_string_from_system().replace(":", "-") + ".txt"
	var file = FileAccess.open(file_path, FileAccess.WRITE)

	if file:
		debug_log("Saving travel log to: " + file_path)
		file.store_line("Celestial Bridge Simulator - Helm Station Travel Log")
		file.store_line("Generated: " + Time.get_datetime_string_from_system())
		file.store_line("==================================================")

		for entry in log_entries:
			file.store_line("%s [%s] %s" % [entry.timestamp, entry.type.to_upper(), entry.message])

		file.close()
		debug_log("Travel log saved successfully (" + str(log_entries.size()) + " entries)")
		_add_travel_log_entry("Travel log saved to " + file_path, "system")
		GameState.audio_manager.play_success_sound()
	else:
		debug_error("Failed to save travel log to " + file_path)
		_add_travel_log_entry("Failed to save travel log", "error")
		GameState.audio_manager.play_error_sound()

func _on_input_event(action: String, value, context: Dictionary):
	debug_log("Input event received - action: " + action + ", value: " + str(value) + ", context: " + str(context))

func _on_input_device_connected(device_name: String):
	debug_log("Input device connected: " + device_name)
	_add_travel_log_entry("Input device connected: " + device_name, "system")
	_update_input_device_status()

func _on_input_device_disconnected(device_name: String):
	debug_log("Input device disconnected: " + device_name)
	_add_travel_log_entry("Input device disconnected: " + device_name, "system")
	_update_input_device_status()

func _on_hotas_input(device_id: int, input_type: String, value):
	debug_log("HOTAS input - device: " + str(device_id) + ", type: " + input_type + ", value: " + str(value))

func _on_hotas_connected(device_info: Dictionary):
	debug_log("HOTAS device connected: " + str(device_info))
	_add_travel_log_entry("HOTAS device connected: " + device_info.get("name", "Unknown"), "system")
	_update_input_device_status()

func _on_hotas_disconnected(device_info: Dictionary):
	debug_log("HOTAS device disconnected: " + str(device_info))
	_add_travel_log_entry("HOTAS device disconnected: " + device_info.get("name", "Unknown"), "system")
	_update_input_device_status()

func _on_universe_updated(state_data: Dictionary):
	debug_log("Universe state updated with " + str(state_data.keys().size()) + " data keys")

func _on_connection_status_changed(is_connected: bool):
	debug_log("Connection status changed to: " + ("CONNECTED" if is_connected else "DISCONNECTED"))
	if is_connected:
		_add_travel_log_entry("Connected to navigation server", "system")
	else:
		_add_travel_log_entry("Disconnected from navigation server", "system")

func _on_alert_level_changed(level: int):
	var alert_names = ["GREEN", "YELLOW", "ORANGE", "RED"]
	var alert_name = alert_names[level] if level < alert_names.size() else "UNKNOWN"
	debug_log("Alert level changed to: " + str(level) + " (" + alert_name + ")")
	_add_travel_log_entry("Alert condition: " + alert_name, "system")

func _on_back_pressed():
	debug_log("Back button pressed - returning to main menu")
	GameState.audio_manager.play_button_sound()
	GameState.audio_manager.stop_music(1.0)
	get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		debug_log("Cancel input detected")
		_on_back_pressed()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and is_plotting_course:
		var map_pos = nav_camera.get_global_mouse_position()
		var world_pos = Vector3(map_pos.x / nav_map_scale, player_ship_position.y, map_pos.y / nav_map_scale)
		waypoints.append(world_pos)
		debug_log("Mouse waypoint plotted at: " + str(world_pos))
		_add_travel_log_entry("Waypoint plotted at " + str(world_pos), "navigation")
		GameState.audio_manager.play_success_sound()

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		debug_log("Window close request - returning to main menu")
		_on_back_pressed()

func normalize_vector_dict(vec: Dictionary) -> Dictionary:
	var normalized = {}
	for k in vec.keys():
		normalized[k.to_lower()] = vec[k]
	return normalized
