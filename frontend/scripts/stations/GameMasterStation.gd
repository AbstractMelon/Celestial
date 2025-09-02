extends Control

@onready var server_status = $MainContainer/LeftPanel/ConnectionStatus/StatusContainer/ServerStatus
@onready var object_type_option = $MainContainer/LeftPanel/ObjectSpawning/SpawnContainer/ObjectTypeOption
@onready var object_name_input = $MainContainer/LeftPanel/ObjectSpawning/SpawnContainer/ObjectNameInput
@onready var x_input = $MainContainer/LeftPanel/ObjectSpawning/SpawnContainer/PositionContainer/XInput
@onready var y_input = $MainContainer/LeftPanel/ObjectSpawning/SpawnContainer/PositionContainer/YInput
@onready var z_input = $MainContainer/LeftPanel/ObjectSpawning/SpawnContainer/PositionContainer/ZInput
@onready var spawn_button = $MainContainer/LeftPanel/ObjectSpawning/SpawnContainer/SpawnButton

@onready var mission_select = $MainContainer/LeftPanel/MissionControl/MissionContainer/MissionSelect
@onready var load_mission_button = $MainContainer/LeftPanel/MissionControl/MissionContainer/MissionButtons/LoadMissionButton
@onready var stop_mission_button = $MainContainer/LeftPanel/MissionControl/MissionContainer/MissionButtons/StopMissionButton
@onready var mission_status = $MainContainer/LeftPanel/MissionControl/MissionContainer/MissionStatus
@onready var mission_progress = $MainContainer/LeftPanel/MissionControl/MissionContainer/MissionProgress

@onready var time_label = $MainContainer/LeftPanel/UniverseControls/UniverseContainer/TimeControlContainer/TimeLabel
@onready var time_slider = $MainContainer/LeftPanel/UniverseControls/UniverseContainer/TimeControlContainer/TimeSlider
@onready var green_alert_button = $MainContainer/LeftPanel/UniverseControls/UniverseContainer/AlertControls/AlertButtons/GreenAlertButton
@onready var yellow_alert_button = $MainContainer/LeftPanel/UniverseControls/UniverseContainer/AlertControls/AlertButtons/YellowAlertButton
@onready var red_alert_button = $MainContainer/LeftPanel/UniverseControls/UniverseContainer/AlertControls/AlertButtons/RedAlertButton
@onready var pause_button = $MainContainer/LeftPanel/UniverseControls/UniverseContainer/EmergencyControls/EmergencyButtons/PauseButton
@onready var reset_button = $MainContainer/LeftPanel/UniverseControls/UniverseContainer/EmergencyControls/EmergencyButtons/ResetButton

@onready var map_camera = $MainContainer/CenterPanel/UniverseMap/MapContainer/MapViewport/MapCamera
@onready var universe_objects_2d = $MainContainer/CenterPanel/UniverseMap/MapContainer/MapViewport/UniverseObjects2D
@onready var zoom_out_button = $MainContainer/CenterPanel/UniverseMap/MapContainer/MapControls/ZoomOutButton
@onready var zoom_in_button = $MainContainer/CenterPanel/UniverseMap/MapContainer/MapControls/ZoomInButton
@onready var center_on_player_button = $MainContainer/CenterPanel/UniverseMap/MapContainer/MapControls/CenterOnPlayerButton
@onready var follow_player_toggle = $MainContainer/CenterPanel/UniverseMap/MapContainer/MapControls/FollowPlayerToggle

@onready var log_text = $MainContainer/CenterPanel/LogPanel/LogContainer/LogScroll/LogText
@onready var clear_log_button = $MainContainer/CenterPanel/LogPanel/LogContainer/LogControls/ClearLogButton
@onready var save_log_button = $MainContainer/CenterPanel/LogPanel/LogContainer/LogControls/SaveLogButton

@onready var selected_object_label = $MainContainer/RightPanel/ObjectInspector/InspectorContainer/SelectedObjectLabel
@onready var object_properties_vbox = $MainContainer/RightPanel/ObjectInspector/InspectorContainer/ObjectPropertiesScroll/ObjectPropertiesVBox
@onready var modify_button = $MainContainer/RightPanel/ObjectInspector/InspectorContainer/ObjectActions/ModifyButton
@onready var delete_button = $MainContainer/RightPanel/ObjectInspector/InspectorContainer/ObjectActions/DeleteButton

@onready var metrics_vbox = $MainContainer/RightPanel/PlayerMetrics/MetricsContainer/MetricsScroll/MetricsVBox
@onready var ship_status_metric = $MainContainer/RightPanel/PlayerMetrics/MetricsContainer/MetricsScroll/MetricsVBox/ShipStatusMetric
@onready var performance_metric = $MainContainer/RightPanel/PlayerMetrics/MetricsContainer/MetricsScroll/MetricsVBox/PerformanceMetric
@onready var station_status_metric = $MainContainer/RightPanel/PlayerMetrics/MetricsContainer/MetricsScroll/MetricsVBox/StationStatusMetric

@onready var spawn_enemy_button = $MainContainer/RightPanel/QuickActions/ActionsContainer/ActionButtonsGrid/SpawnEnemyButton
@onready var spawn_ally_button = $MainContainer/RightPanel/QuickActions/ActionsContainer/ActionButtonsGrid/SpawnAllyButton
@onready var create_asteroid_button = $MainContainer/RightPanel/QuickActions/ActionsContainer/ActionButtonsGrid/CreateAsteroidButton
@onready var create_station_button = $MainContainer/RightPanel/QuickActions/ActionsContainer/ActionButtonsGrid/CreateStationButton
@onready var heal_player_button = $MainContainer/RightPanel/QuickActions/ActionsContainer/ActionButtonsGrid/HealPlayerButton
@onready var damage_player_button = $MainContainer/RightPanel/QuickActions/ActionsContainer/ActionButtonsGrid/DamagePlayerButton

@onready var back_button = $BackButton

var rendered_map_objects: Dictionary = {}
var selected_object_id: String = ""
var map_scale: float = 0.0001
var follow_player: bool = false
var is_dragging_map: bool = false
var last_mouse_pos: Vector2
var current_time_factor: float = 1.0
var is_paused: bool = false
var mission_start_time: float = 0.0
var log_entries: Array = []

var object_types: Array = [
	"ship",
	"station",
	"planet",
	"asteroid",
	"torpedo",
	"mine"
]

var available_missions: Array = [
	"missions/tutorial.lua",
	"missions/patrol.lua",
	"missions/rescue.lua",
	"missions/defense.lua",
	"missions/exploration.lua"
]

func _ready():
	_setup_connections()
	_setup_ui()
	_initialize_game_master()

	GameState.switch_station("gamemaster")
	GameState.audio_manager.set_station_audio_profile("gamemaster")
	GameState.audio_manager.play_music("exploration")

func _setup_connections():
	if GameState:
		GameState.universe_state_updated.connect(_on_universe_updated)
		GameState.connection_status_changed.connect(_on_connection_status_changed)
		GameState.alert_level_changed.connect(_on_alert_level_changed)

	spawn_button.pressed.connect(_on_spawn_object)
	load_mission_button.pressed.connect(_on_load_mission)
	stop_mission_button.pressed.connect(_on_stop_mission)

	time_slider.value_changed.connect(_on_time_factor_changed)
	green_alert_button.pressed.connect(_set_alert_level.bind(0))
	yellow_alert_button.pressed.connect(_set_alert_level.bind(1))
	red_alert_button.pressed.connect(_set_alert_level.bind(3))
	pause_button.pressed.connect(_on_pause_toggle)
	reset_button.pressed.connect(_on_reset_universe)

	zoom_out_button.pressed.connect(_zoom_map_out)
	zoom_in_button.pressed.connect(_zoom_map_in)
	center_on_player_button.pressed.connect(_center_on_player)
	follow_player_toggle.toggled.connect(_on_follow_player_toggled)

	clear_log_button.pressed.connect(_clear_log)
	save_log_button.pressed.connect(_save_log)

	modify_button.pressed.connect(_on_modify_object)
	delete_button.pressed.connect(_on_delete_object)

	spawn_enemy_button.pressed.connect(_spawn_quick_enemy)
	spawn_ally_button.pressed.connect(_spawn_quick_ally)
	create_asteroid_button.pressed.connect(_spawn_quick_asteroid)
	create_station_button.pressed.connect(_spawn_quick_station)
	heal_player_button.pressed.connect(_heal_player)
	damage_player_button.pressed.connect(_damage_player)

	back_button.pressed.connect(_on_back_pressed)

func _setup_ui():
	for object_type in object_types:
		object_type_option.add_item(object_type.capitalize())

	for mission in available_missions:
		var mission_name = mission.get_file().get_basename().capitalize()
		mission_select.add_item(mission_name)

	map_camera.zoom = Vector2(map_scale, map_scale)
	time_slider.value = current_time_factor

	modify_button.disabled = true
	delete_button.disabled = true

func _initialize_game_master():
	_add_log_entry("Game Master Console initialized", "system")
	_add_log_entry("Awaiting server connection...", "system")

func _process(_delta):
	_update_ui()
	_update_map()
	_update_metrics()

	if follow_player:
		_center_camera_on_player()

func _update_ui():
	var status = GameState.get_connection_status()
	server_status.text = "Server: " + status.to_upper()

	match status:
		"Connected":
			server_status.modulate = Color.GREEN
		"Connecting":
			server_status.modulate = Color.YELLOW
		_:
			server_status.modulate = Color.RED

	time_label.text = "Time Acceleration: " + str(current_time_factor) + "x"

	if is_paused:
		pause_button.text = "Resume"
		pause_button.modulate = Color.GREEN
	else:
		pause_button.text = "Pause"
		pause_button.modulate = Color.YELLOW

func _update_map():
	var objects = GameState.get_universe_objects()

	for obj_id in objects:
		var obj = objects[obj_id]
		_create_or_update_map_object(obj_id, obj)

	for obj_id in rendered_map_objects.keys():
		if not objects.has(obj_id):
			_remove_map_object(obj_id)

func _update_metrics():
	var player_ship = GameState.get_player_ship()
	if player_ship:
		var health = player_ship.get("health", 0)
		var max_health = player_ship.get("max_health", 100)
		var shield = player_ship.get("shield", 0)
		var max_shield = player_ship.get("max_shield", 100)
		var power = player_ship.get("power", 0)
		var max_power = player_ship.get("max_power", 100)

		var health_pct = int((health / max_health) * 100) if max_health > 0 else 0
		var shield_pct = int((shield / max_shield) * 100) if max_shield > 0 else 0
		var power_pct = int((power / max_power) * 100) if max_power > 0 else 0

		ship_status_metric.text = "Hull: %d%% | Shield: %d%% | Power: %d%%" % [health_pct, shield_pct, power_pct]

	var elapsed_time = Time.get_time_dict_from_system().get("unix", 0) - mission_start_time if mission_start_time > 0 else 0
	var minutes = int(elapsed_time / 60)
	var seconds = int(elapsed_time % 60)
	performance_metric.text = "Mission Score: 0 | Time Elapsed: %02d:%02d" % [minutes, seconds]

	var connected_stations = 0
	station_status_metric.text = "Stations Connected: %d" % connected_stations

func _create_or_update_map_object(obj_id: String, obj_data: Dictionary):
	var position = obj_data.get("position", {})
	if not position.has("x") or not position.has("z"):
		return

	var map_pos = Vector2(position.x, position.z) * map_scale
	var _obj_type = obj_data.get("type", "unknown")

	if not rendered_map_objects.has(obj_id):
		var map_object = _create_map_object_node(obj_id, obj_data)
		if map_object:
			rendered_map_objects[obj_id] = map_object
			universe_objects_2d.add_child(map_object)

	var map_object = rendered_map_objects.get(obj_id)
	if map_object:
		map_object.position = map_pos

func _create_map_object_node(obj_id: String, obj_data: Dictionary) -> Node2D:
	var node = Node2D.new()
	node.name = obj_id

	var shape = _create_map_shape(obj_data)
	node.add_child(shape)

	var area = Area2D.new()
	var collision = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = 20
	collision.shape = circle_shape
	area.add_child(collision)
	node.add_child(area)

	area.input_event.connect(_on_map_object_clicked.bind(obj_id))

	return node

func _create_map_shape(obj_data: Dictionary) -> Node2D:
	var obj_type = obj_data.get("type", "unknown")
	var is_player = obj_data.get("is_player_ship", false)

	match obj_type:
		"ship":
			var polygon = Polygon2D.new()
			polygon.polygon = PackedVector2Array([
				Vector2(-10, -15), Vector2(0, 15), Vector2(10, -15)
			])
			polygon.color = Color.BLUE if is_player else Color.RED
			return polygon
		"station":
			var polygon = Polygon2D.new()
			polygon.polygon = PackedVector2Array([
				Vector2(-15, -15), Vector2(15, -15), Vector2(15, 15), Vector2(-15, 15)
			])
			polygon.color = Color.CYAN
			return polygon
		"planet":
			var circle = Polygon2D.new()
			var points = PackedVector2Array()
			var radius = 25
			for i in range(16):
				var angle = i * PI * 2 / 16
				points.append(Vector2(cos(angle), sin(angle)) * radius)
			circle.polygon = points
			circle.color = Color.GREEN
			return circle
		_:
			var rect = Polygon2D.new()
			rect.polygon = PackedVector2Array([
				Vector2(-5, -5), Vector2(5, -5), Vector2(5, 5), Vector2(-5, 5)
			])
			rect.color = Color.WHITE
			return rect

func _remove_map_object(obj_id: String):
	if rendered_map_objects.has(obj_id):
		var map_object = rendered_map_objects[obj_id]
		map_object.queue_free()
		rendered_map_objects.erase(obj_id)

func _center_camera_on_player():
	var player_ship = GameState.get_player_ship()
	if player_ship:
		var position = player_ship.get("position", {})
		if position.has("x") and position.has("z"):
			var target_pos = Vector2(position.x, position.z) * map_scale
			map_camera.global_position = target_pos

func _on_spawn_object():
	if not GameState.is_station_authenticated():
		_add_log_entry("Cannot spawn object - not connected to server", "error")
		return

	var selected_index = object_type_option.selected
	if selected_index < 0 or selected_index >= object_types.size():
		_add_log_entry("Invalid object type selected", "error")
		return

	var obj_type = object_types[selected_index]
	var obj_name = object_name_input.text.strip_edges()
	if obj_name == "":
		obj_name = obj_type.capitalize() + "_" + str(randi() % 1000)

	var position = Vector3(x_input.value, y_input.value, z_input.value)

	var object_def = {
		"type": obj_type,
		"name": obj_name,
		"position": {"x": position.x, "y": position.y, "z": position.z},
		"health": 100,
		"max_health": 100
	}

	var success = GameState.send_gamemaster_command("spawn_object", "", position, null, object_def)

	if success:
		_add_log_entry("Spawned " + obj_type + ": " + obj_name + " at " + str(position), "action")
		GameState.audio_manager.play_success_sound()
	else:
		_add_log_entry("Failed to spawn object", "error")
		GameState.audio_manager.play_error_sound()

func _on_load_mission():
	var selected_index = mission_select.selected
	if selected_index < 0 or selected_index >= available_missions.size():
		_add_log_entry("No mission selected", "error")
		return

	var mission_file = available_missions[selected_index]
	var success = GameState.load_mission(mission_file)

	if success:
		mission_start_time = Time.get_time_dict_from_system().get("unix", 0)
		mission_status.text = "Status: Loading " + mission_file.get_file().get_basename()
		_add_log_entry("Loading mission: " + mission_file, "mission")
		GameState.audio_manager.play_success_sound()
	else:
		_add_log_entry("Failed to load mission", "error")
		GameState.audio_manager.play_error_sound()

func _on_stop_mission():
	mission_status.text = "Status: No Mission Active"
	mission_progress.value = 0
	mission_start_time = 0
	_add_log_entry("Mission stopped by Game Master", "mission")
	GameState.audio_manager.play_success_sound()

func _on_time_factor_changed(value: float):
	current_time_factor = value
	var success = GameState.send_gamemaster_command("universe_control", "", Vector3.ZERO, {"time_acceleration": value})

	if success:
		_add_log_entry("Time acceleration set to " + str(value) + "x", "control")

func _set_alert_level(level: int):
	var success = GameState.send_gamemaster_command("universe_control", "", Vector3.ZERO, {"alert_level": level})

	if success:
		var alert_names = ["GREEN", "YELLOW", "ORANGE", "RED"]
		var alert_name = alert_names[level] if level < alert_names.size() else "UNKNOWN"
		_add_log_entry("Alert level set to " + alert_name, "control")
		GameState.audio_manager.play_success_sound()

func _on_pause_toggle():
	is_paused = not is_paused
	var time_factor = 0.0 if is_paused else current_time_factor
	var success = GameState.send_gamemaster_command("universe_control", "", Vector3.ZERO, {"time_acceleration": time_factor})

	if success:
		_add_log_entry("Universe " + ("paused" if is_paused else "resumed"), "control")

func _on_reset_universe():
	var confirmation = ConfirmationDialog.new()
	confirmation.dialog_text = "Are you sure you want to reset the universe? This will remove all objects and reset the simulation."
	confirmation.title = "Confirm Universe Reset"
	add_child(confirmation)

	confirmation.confirmed.connect(_confirm_reset_universe)
	confirmation.popup_centered()

func _confirm_reset_universe():
	var success = GameState.send_gamemaster_command("universe_control", "", Vector3.ZERO, {"reset": true})

	if success:
		_add_log_entry("Universe reset by Game Master", "control")
		rendered_map_objects.clear()
		for child in universe_objects_2d.get_children():
			child.queue_free()

func _zoom_map_in():
	map_camera.zoom *= 1.5
	GameState.audio_manager.play_button_sound()

func _zoom_map_out():
	map_camera.zoom /= 1.5
	GameState.audio_manager.play_button_sound()

func _center_on_player():
	_center_camera_on_player()
	GameState.audio_manager.play_button_sound()

func _on_follow_player_toggled(enabled: bool):
	follow_player = enabled
	if enabled:
		_center_camera_on_player()

func _on_map_object_clicked(obj_id: String, _viewport: Node, event: InputEvent, _shape_idx: int):
	if event is InputEventMouseButton and event.pressed:
		_select_object(obj_id)

func _select_object(obj_id: String):
	selected_object_id = obj_id
	var obj_data = GameState.get_object(obj_id)

	if obj_data:
		selected_object_label.text = obj_data.get("name", "Unknown Object")
		_update_object_properties(obj_data)
		modify_button.disabled = false
		delete_button.disabled = false
	else:
		selected_object_label.text = "No Object Selected"
		modify_button.disabled = true
		delete_button.disabled = true

func _update_object_properties(obj_data: Dictionary):
	for child in object_properties_vbox.get_children():
		child.queue_free()

	for property in obj_data:
		var prop_container = HBoxContainer.new()

		var prop_label = Label.new()
		prop_label.text = property.capitalize() + ":"
		prop_label.custom_minimum_size.x = 80
		prop_label.theme_override_colors["font_color"] = Color(0.8, 0.8, 0.8, 1)
		prop_label.theme_override_font_sizes["font_size"] = 10
		prop_container.add_child(prop_label)

		var prop_value = Label.new()
		prop_value.text = str(obj_data[property])
		prop_value.theme_override_colors["font_color"] = Color(1, 1, 0.8, 1)
		prop_value.theme_override_font_sizes["font_size"] = 10
		prop_container.add_child(prop_value)

		object_properties_vbox.add_child(prop_container)

func _on_modify_object():
	if selected_object_id == "":
		return

	_add_log_entry("Modifying object: " + selected_object_id, "action")

func _on_delete_object():
	if selected_object_id == "":
		return

	var success = GameState.send_gamemaster_command("delete_object", selected_object_id)

	if success:
		_add_log_entry("Deleted object: " + selected_object_id, "action")
		selected_object_id = ""
		_select_object("")
		GameState.audio_manager.play_success_sound()

func _spawn_quick_enemy():
	var player_ship = GameState.get_player_ship()
	var spawn_pos = Vector3(1000, 0, 1000)

	if player_ship:
		var pos = player_ship.get("position", {})
		if pos.has("x") and pos.has("z"):
			spawn_pos = Vector3(pos.x + randf_range(500, 2000), pos.get("y", 0), pos.z + randf_range(500, 2000))

	var object_def = {
		"type": "ship",
		"name": "Enemy_" + str(randi() % 1000),
		"position": {"x": spawn_pos.x, "y": spawn_pos.y, "z": spawn_pos.z},
		"health": 100,
		"max_health": 100,
		"is_hostile": true
	}

	GameState.send_gamemaster_command("spawn_object", "", spawn_pos, null, object_def)
	_add_log_entry("Quick spawned enemy ship", "action")

func _spawn_quick_ally():
	var player_ship = GameState.get_player_ship()
	var spawn_pos = Vector3(-1000, 0, -1000)

	if player_ship:
		var pos = player_ship.get("position", {})
		if pos.has("x") and pos.has("z"):
			spawn_pos = Vector3(pos.x + randf_range(-2000, -500), pos.get("y", 0), pos.z + randf_range(-2000, -500))

	var object_def = {
		"type": "ship",
		"name": "Ally_" + str(randi() % 1000),
		"position": {"x": spawn_pos.x, "y": spawn_pos.y, "z": spawn_pos.z},
		"health": 100,
		"max_health": 100,
		"is_hostile": false
	}

	GameState.send_gamemaster_command("spawn_object", "", spawn_pos, null, object_def)
	_add_log_entry("Quick spawned ally ship", "action")

func _spawn_quick_asteroid():
	var spawn_pos = Vector3(randf_range(-5000, 5000), randf_range(-1000, 1000), randf_range(-5000, 5000))

	var object_def = {
		"type": "asteroid",
		"name": "Asteroid_" + str(randi() % 1000),
		"position": {"x": spawn_pos.x, "y": spawn_pos.y, "z": spawn_pos.z},
		"radius": randf_range(10, 50)
	}

	GameState.send_gamemaster_command("spawn_object", "", spawn_pos, null, object_def)
	_add_log_entry("Quick spawned asteroid", "action")

func _spawn_quick_station():
	var spawn_pos = Vector3(randf_range(-3000, 3000), 0, randf_range(-3000, 3000))

	var object_def = {
		"type": "station",
		"name": "Station_" + str(randi() % 1000),
		"position": {"x": spawn_pos.x, "y": spawn_pos.y, "z": spawn_pos.z},
		"health": 500,
		"max_health": 500
	}

	GameState.send_gamemaster_command("spawn_object", "", spawn_pos, null, object_def)
	_add_log_entry("Quick spawned station", "action")

func _heal_player():
	var player_ship = GameState.get_player_ship()
	if not player_ship:
		_add_log_entry("No player ship found", "error")
		return

	var player_id = player_ship.get("id", "")
	if player_id != "":
		GameState.send_gamemaster_command("modify_object", player_id, Vector3.ZERO, {"health": 100, "shield": 100, "power": 100})
		_add_log_entry("Player ship healed", "action")

func _damage_player():
	var player_ship = GameState.get_player_ship()
	if not player_ship:
		_add_log_entry("No player ship found", "error")
		return

	var player_id = player_ship.get("id", "")
	if player_id != "":
		var current_health = player_ship.get("health", 100)
		var new_health = max(0, current_health - 25)
		GameState.send_gamemaster_command("modify_object", player_id, Vector3.ZERO, {"health": new_health})
		_add_log_entry("Player ship damaged", "action")

func _add_log_entry(message: String, log_type: String = "info"):
	var timestamp = Time.get_datetime_string_from_system().substr(11, 8)
	var color = "white"

	match log_type:
		"error": color = "red"
		"action": color = "yellow"
		"mission": color = "cyan"
		"control": color = "orange"
		"system": color = "green"

	var formatted_entry = "[color=gray]%s[/color] [color=%s]%s[/color]" % [timestamp, color, message]
	log_text.append_text(formatted_entry + "\n")

	log_entries.append({
		"timestamp": timestamp,
		"message": message,
		"type": log_type
	})

	if log_entries.size() > 1000:
		log_entries.pop_front()

func _clear_log():
	log_text.clear()
	log_text.append_text("[color=green]Log cleared[/color]\n")
	log_entries.clear()
	GameState.audio_manager.play_success_sound()

func _save_log():
	var file_path = "user://gamemaster_log_" + Time.get_datetime_string_from_system().replace(":", "-") + ".txt"
	var file = FileAccess.open(file_path, FileAccess.WRITE)

	if file:
		file.store_line("Celestial Bridge Simulator - Game Master Log")
		file.store_line("Generated: " + Time.get_datetime_string_from_system())
		file.store_line("==================================================")

		for entry in log_entries:
			file.store_line("%s [%s] %s" % [entry.timestamp, entry.type.to_upper(), entry.message])

		file.close()
		_add_log_entry("Log saved to " + file_path, "system")
		GameState.audio_manager.play_success_sound()
	else:
		_add_log_entry("Failed to save log file", "error")
		GameState.audio_manager.play_error_sound()

func _on_universe_updated(state_data: Dictionary):
	pass

func _on_connection_status_changed(is_connected: bool):
	if is_connected:
		_add_log_entry("Connected to server", "system")
	else:
		_add_log_entry("Disconnected from server", "system")

func _on_alert_level_changed(level: int):
	var alert_names = ["GREEN", "YELLOW", "ORANGE", "RED"]
	var alert_name = alert_names[level] if level < alert_names.size() else "UNKNOWN"
	_add_log_entry("Alert level changed to " + alert_name, "system")

func _on_back_pressed():
	GameState.audio_manager.play_button_sound()
	GameState.audio_manager.stop_music(1.0)
	get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging_map = true
			last_mouse_pos = event.position
		else:
			is_dragging_map = false
	elif event is InputEventMouseMotion and is_dragging_map:
		var delta = event.position - last_mouse_pos
		map_camera.global_position -= delta / map_camera.zoom.x
		last_mouse_pos = event.position
		follow_player = false
		follow_player_toggle.button_pressed = false

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_on_back_pressed()
