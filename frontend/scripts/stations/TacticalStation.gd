extends Control

@onready var connection_label = $MainContainer/LeftPanel/ConnectionStatus/StatusContainer/ConnectionLabel
@onready var phaser_power_slider = $MainContainer/LeftPanel/WeaponsControl/WeaponsContainer/PhaserControls/PhaserPowerSlider
@onready var phaser_status = $MainContainer/LeftPanel/WeaponsControl/WeaponsContainer/PhaserControls/PhaserStatus
@onready var torpedo_type_option = $MainContainer/LeftPanel/WeaponsControl/WeaponsContainer/TorpedoControls/TorpedoTypeOption
@onready var torpedo_status = $MainContainer/LeftPanel/WeaponsControl/WeaponsContainer/TorpedoControls/TorpedoStatus
@onready var fire_phasers_button = $MainContainer/LeftPanel/WeaponsControl/WeaponsContainer/WeaponButtons/FirePhasersButton
@onready var fire_torpedo_button = $MainContainer/LeftPanel/WeaponsControl/WeaponsContainer/WeaponButtons/FireTorpedoButton
@onready var charge_button = $MainContainer/LeftPanel/WeaponsControl/WeaponsContainer/WeaponButtons/ChargeButton
@onready var standby_button = $MainContainer/LeftPanel/WeaponsControl/WeaponsContainer/WeaponButtons/StandbyButton

@onready var shield_power_slider = $MainContainer/LeftPanel/ShieldControl/ShieldContainer/ShieldPowerContainer/ShieldPowerSlider
@onready var shield_power_value = $MainContainer/LeftPanel/ShieldControl/ShieldContainer/ShieldPowerContainer/ShieldPowerValue
@onready var shield_status = $MainContainer/LeftPanel/ShieldControl/ShieldContainer/ShieldStatus
@onready var raise_shields_button = $MainContainer/LeftPanel/ShieldControl/ShieldContainer/ShieldButtons/RaiseShieldsButton
@onready var modulate_button = $MainContainer/LeftPanel/ShieldControl/ShieldContainer/ShieldButtons/ModulateButton

@onready var weapon_power_slider = $MainContainer/LeftPanel/PowerAllocation/PowerContainer/WeaponPowerContainer/WeaponPowerSlider
@onready var weapon_power_value = $MainContainer/LeftPanel/PowerAllocation/PowerContainer/WeaponPowerContainer/WeaponPowerValue

@onready var tactical_camera = $MainContainer/CenterPanel/TacticalDisplay/DisplayContainer/TacticalViewport/TacticalCamera
@onready var tactical_objects = $MainContainer/CenterPanel/TacticalDisplay/DisplayContainer/TacticalViewport/TacticalObjects
@onready var weapon_effects = $MainContainer/CenterPanel/TacticalDisplay/DisplayContainer/TacticalViewport/WeaponEffects
@onready var zoom_out_button = $MainContainer/CenterPanel/TacticalDisplay/DisplayContainer/DisplayControls/ZoomOutButton
@onready var zoom_in_button = $MainContainer/CenterPanel/TacticalDisplay/DisplayContainer/DisplayControls/ZoomInButton
@onready var center_button = $MainContainer/CenterPanel/TacticalDisplay/DisplayContainer/DisplayControls/CenterButton
@onready var scan_button = $MainContainer/CenterPanel/TacticalDisplay/DisplayContainer/DisplayControls/ScanButton

@onready var log_text = $MainContainer/CenterPanel/CombatLog/LogContainer/LogScroll/LogText
@onready var clear_log_button = $MainContainer/CenterPanel/CombatLog/LogContainer/LogControls/ClearLogButton

@onready var target_name = $MainContainer/RightPanel/TargetInfo/TargetContainer/TargetName
@onready var target_distance = $MainContainer/RightPanel/TargetInfo/TargetContainer/TargetDetails/TargetDistance
@onready var target_bearing = $MainContainer/RightPanel/TargetInfo/TargetContainer/TargetDetails/TargetBearing
@onready var target_health = $MainContainer/RightPanel/TargetInfo/TargetContainer/TargetDetails/TargetHealth
@onready var target_shields = $MainContainer/RightPanel/TargetInfo/TargetContainer/TargetDetails/TargetShields
@onready var lock_target_button = $MainContainer/RightPanel/TargetInfo/TargetContainer/TargetButtons/LockTargetButton
@onready var scan_target_button = $MainContainer/RightPanel/TargetInfo/TargetContainer/TargetButtons/ScanTargetButton

@onready var photon_torpedoes = $MainContainer/RightPanel/AmmoStatus/AmmoContainer/PhotonTorpedoes
@onready var quantum_torpedoes = $MainContainer/RightPanel/AmmoStatus/AmmoContainer/QuantumTorpedoes
@onready var proximity_mines = $MainContainer/RightPanel/AmmoStatus/AmmoContainer/ProximityMines
@onready var phaser_cells = $MainContainer/RightPanel/AmmoStatus/AmmoContainer/PhaserCells

@onready var hull_integrity = $MainContainer/RightPanel/DamageControl/DamageContainer/HullIntegrity
@onready var hull_label = $MainContainer/RightPanel/DamageControl/DamageContainer/HullLabel
@onready var systems_vbox = $MainContainer/RightPanel/DamageControl/DamageContainer/SystemsScroll/SystemsVBox
@onready var back_button = $BackButton

var rendered_tactical_objects: Dictionary = {}
var selected_target_id: String = ""
var current_phaser_power: float = 0.5
var current_shield_power: float = 0.8
var current_weapon_power: float = 0.6
var shields_raised: bool = false
var weapons_charged: bool = false
var tactical_map_scale: float = 0.0005

var torpedo_types: Array = ["Photon Torpedoes", "Quantum Torpedoes", "Plasma Torpedoes"]
var log_entries: Array = []
var ammunition_count: Dictionary = {
	"photon": 12,
	"quantum": 8,
	"mines": 4,
	"phaser_cells": 98
}

func _ready():
	_setup_connections()
	_setup_ui()
	_initialize_tactical_station()

	GameState.switch_station("tactical")
	GameState.audio_manager.set_station_audio_profile("tactical")
	GameState.audio_manager.play_music("exploration")

func _setup_connections():
	if GameState:
		GameState.universe_state_updated.connect(_on_universe_updated)
		GameState.connection_status_changed.connect(_on_connection_status_changed)
		GameState.alert_level_changed.connect(_on_alert_level_changed)
	else:
		print("Gamestate not detected, cannot setup signals")

	phaser_power_slider.value_changed.connect(_on_phaser_power_changed)
	shield_power_slider.value_changed.connect(_on_shield_power_changed)
	weapon_power_slider.value_changed.connect(_on_weapon_power_changed)

	fire_phasers_button.pressed.connect(_fire_phasers)
	fire_torpedo_button.pressed.connect(_fire_torpedo)
	charge_button.pressed.connect(_charge_weapons)
	standby_button.pressed.connect(_weapons_standby)

	raise_shields_button.pressed.connect(_toggle_shields)
	modulate_button.pressed.connect(_modulate_shields)

	zoom_out_button.pressed.connect(_zoom_tactical_out)
	zoom_in_button.pressed.connect(_zoom_tactical_in)
	center_button.pressed.connect(_center_tactical_display)
	scan_button.pressed.connect(_long_range_scan)

	lock_target_button.pressed.connect(_lock_target)
	scan_target_button.pressed.connect(_scan_target)

	clear_log_button.pressed.connect(_clear_combat_log)
	back_button.pressed.connect(_on_back_pressed)

func _setup_ui():
	for torpedo_type in torpedo_types:
		torpedo_type_option.add_item(torpedo_type)

	tactical_camera.zoom = Vector2(tactical_map_scale, tactical_map_scale)

	phaser_status.text = "Power: " + str(int(current_phaser_power * 100)) + "% | Status: Ready"
	shield_power_value.text = str(int(current_shield_power * 100)) + "%"
	weapon_power_value.text = str(int(current_weapon_power * 100)) + "%"

func _initialize_tactical_station():
	GameState.input_manager.set_station("tactical")
	_add_combat_log_entry("Tactical station initialized", "system")
	_add_combat_log_entry("Weapons systems online", "system")
	_add_combat_log_entry("Shields ready", "system")
	_update_ammunition_display()

func _process(delta):
	_update_ui()
	_update_tactical_display()
	_process_tactical_input()

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
		_update_ship_combat_status(player_ship)

func _update_ship_combat_status(ship_data: Dictionary):
	var health = ship_data.get("health", 100)
	var max_health = ship_data.get("max_health", 100)
	var shield = ship_data.get("shield", 100)
	var max_shield = ship_data.get("max_shield", 100)

	var hull_percent = (health / max_health) * 100 if max_health > 0 else 0
	hull_integrity.value = hull_percent
	hull_label.text = "Hull Integrity: " + str(int(hull_percent)) + "%"

	if hull_percent > 75:
		hull_label.modulate = Color.GREEN
	elif hull_percent > 25:
		hull_label.modulate = Color.YELLOW
	else:
		hull_label.modulate = Color.RED

	var shield_percent = (shield / max_shield) * 100 if max_shield > 0 else 0
	var shield_freq = randf_range(240.0, 260.0)
	shield_status.text = "Shields: " + str(int(shield_percent)) + "% | Frequency: " + str("%.2f" % shield_freq)

	if shields_raised:
		raise_shields_button.text = "LOWER\nSHIELDS"
		raise_shields_button.modulate = Color.RED
	else:
		raise_shields_button.text = "RAISE\nSHIELDS"
		raise_shields_button.modulate = Color.GREEN

func _update_tactical_display():
	var objects = GameState.get_universe_objects()

	for obj_id in objects:
		var obj = objects[obj_id]
		_create_or_update_tactical_object(obj_id, obj)

	for obj_id in rendered_tactical_objects.keys():
		if not objects.has(obj_id):
			_remove_tactical_object(obj_id)

func _process_tactical_input():
	if Input.is_action_just_pressed("tactical_fire_primary"):
		_fire_phasers()
	elif Input.is_action_just_pressed("tactical_fire_secondary"):
		_fire_torpedo()

func _create_or_update_tactical_object(obj_id: String, obj_data: Dictionary):
	var position = obj_data.get("position", {})
	if not position.has("x") or not position.has("z"):
		return

	var tactical_pos = Vector2(position.x, position.z) * tactical_map_scale

	if not rendered_tactical_objects.has(obj_id):
		var tactical_object = _create_tactical_object_node(obj_id, obj_data)
		if tactical_object:
			rendered_tactical_objects[obj_id] = tactical_object
			tactical_objects.add_child(tactical_object)

	var tactical_object = rendered_tactical_objects.get(obj_id)
	if tactical_object:
		tactical_object.position = tactical_pos

func _create_tactical_object_node(obj_id: String, obj_data: Dictionary) -> Node2D:
	var node = Node2D.new()
	node.name = obj_id

	var shape = _create_tactical_shape(obj_data)
	node.add_child(shape)

	var area = Area2D.new()
	var collision = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = 15
	collision.shape = circle_shape
	area.add_child(collision)
	node.add_child(area)

	area.input_event.connect(_on_tactical_object_clicked.bind(obj_id))

	return node

func _create_tactical_shape(obj_data: Dictionary) -> Node2D:
	var obj_type = obj_data.get("type", "unknown")
	var is_player = obj_data.get("is_player_ship", false)

	match obj_type:
		"ship":
			var polygon = Polygon2D.new()
			polygon.polygon = PackedVector2Array([
				Vector2(-10, -15), Vector2(0, 15), Vector2(10, -15)
			])
			polygon.color = Color.CYAN if is_player else Color.RED
			return polygon
		"station":
			var rect = Polygon2D.new()
			rect.polygon = PackedVector2Array([
				Vector2(-12, -12), Vector2(12, -12), Vector2(12, 12), Vector2(-12, 12)
			])
			rect.color = Color.GREEN
			return rect
		"projectile", "torpedo":
			var dot = Polygon2D.new()
			dot.polygon = PackedVector2Array([
				Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2)
			])
			dot.color = Color.YELLOW
			return dot
		_:
			var circle = Polygon2D.new()
			var points = PackedVector2Array()
			for i in range(8):
				var angle = i * PI * 2 / 8
				points.append(Vector2(cos(angle), sin(angle)) * 8)
			circle.polygon = points
			circle.color = Color.WHITE
			return circle

func _remove_tactical_object(obj_id: String):
	if rendered_tactical_objects.has(obj_id):
		var tactical_object = rendered_tactical_objects[obj_id]
		tactical_object.queue_free()
		rendered_tactical_objects.erase(obj_id)

func _on_tactical_object_clicked(obj_id: String, _viewport: Node, event: InputEvent, _shape_idx: int):
	if event is InputEventMouseButton and event.pressed:
		_select_target(obj_id)

func _select_target(obj_id: String):
	selected_target_id = obj_id
	var obj_data = GameState.get_object(obj_id)

	if obj_data and not obj_data.get("is_player_ship", false):
		target_name.text = obj_data.get("name", "Unknown Target")
		_update_target_info(obj_data)
		_add_combat_log_entry("Target selected: " + obj_data.get("name", "Unknown"), "targeting")
	else:
		target_name.text = "No Target Selected"
		target_distance.text = "Distance: --"
		target_bearing.text = "Bearing: --"
		target_health.text = "Hull: --"
		target_shields.text = "Shields: --"

func _update_target_info(target_data: Dictionary):
	var player_ship = GameState.get_player_ship()
	if player_ship and target_data:
		var player_pos = player_ship.get("position", {})
		var target_pos = target_data.get("position", {})

		if player_pos.has("x") and target_pos.has("x"):
			var distance = Vector3(player_pos.x, player_pos.y, player_pos.z).distance_to(Vector3(target_pos.x, target_pos.y, target_pos.z))
			target_distance.text = "Distance: " + str(int(distance)) + "m"

			var bearing = rad_to_deg(atan2(target_pos.z - player_pos.z, target_pos.x - player_pos.x))
			target_bearing.text = "Bearing: " + str(int(bearing)) + "°"

		var health = target_data.get("health", 0)
		var max_health = target_data.get("max_health", 100)
		var health_percent = (health / max_health) * 100 if max_health > 0 else 0
		target_health.text = "Hull: " + str(int(health_percent)) + "%"

		var shield = target_data.get("shield", 0)
		var max_shield = target_data.get("max_shield", 100)
		var shield_percent = (shield / max_shield) * 100 if max_shield > 0 else 0
		target_shields.text = "Shields: " + str(int(shield_percent)) + "%"

func _on_phaser_power_changed(value: float):
	current_phaser_power = value
	phaser_status.text = "Power: " + str(int(value * 100)) + "% | Status: " + ("Charged" if weapons_charged else "Ready")

func _on_shield_power_changed(value: float):
	current_shield_power = value
	shield_power_value.text = str(int(value * 100)) + "%"
	if GameState.is_station_authenticated():
		GameState.send_input_event("shield_power", value)

func _on_weapon_power_changed(value: float):
	current_weapon_power = value
	weapon_power_value.text = str(int(value * 100)) + "%"
	if GameState.is_station_authenticated():
		GameState.send_input_event("weapon_power", value)

func _fire_phasers():
	if not GameState.is_station_authenticated() or selected_target_id == "":
		GameState.audio_manager.play_error_sound()
		return

	var context = {
		"weapon_type": "phaser",
		"target_id": selected_target_id,
		"power": current_phaser_power
	}

	GameState.send_input_event("fire_weapon", true, context)
	_add_combat_log_entry("PHASERS FIRED at " + target_name.text, "weapons")
	GameState.audio_manager.play_weapon_fire_sound("phaser", Vector3.ZERO)

	if ammunition_count.phaser_cells > 0:
		ammunition_count.phaser_cells -= 2
		_update_ammunition_display()

func _fire_torpedo():
	if not GameState.is_station_authenticated() or selected_target_id == "":
		GameState.audio_manager.play_error_sound()
		return

	var torpedo_type = torpedo_types[torpedo_type_option.selected].to_lower().replace(" ", "_")
	var ammo_key = torpedo_type.split("_")[0]

	if ammunition_count.get(ammo_key, 0) <= 0:
		_add_combat_log_entry("TORPEDO TUBES EMPTY", "error")
		GameState.audio_manager.play_error_sound()
		return

	var context = {
		"weapon_type": "torpedo",
		"target_id": selected_target_id,
		"torpedo_type": ammo_key
	}

	GameState.send_input_event("fire_weapon", true, context)
	_add_combat_log_entry("TORPEDO LAUNCHED at " + target_name.text, "weapons")
	GameState.audio_manager.play_weapon_fire_sound("torpedo", Vector3.ZERO)

	ammunition_count[ammo_key] -= 1
	_update_ammunition_display()

func _charge_weapons():
	weapons_charged = not weapons_charged
	charge_button.text = "STANDBY" if weapons_charged else "CHARGE\nWEAPONS"
	charge_button.modulate = Color.RED if weapons_charged else Color.YELLOW

	if GameState.is_station_authenticated():
		GameState.send_input_event("weapon_power", current_weapon_power if weapons_charged else 0.0)

	_add_combat_log_entry("Weapons " + ("CHARGED" if weapons_charged else "ON STANDBY"), "system")

func _weapons_standby():
	weapons_charged = false
	charge_button.text = "CHARGE\nWEAPONS"
	charge_button.modulate = Color.YELLOW

	if GameState.is_station_authenticated():
		GameState.send_input_event("weapon_power", 0.0)

	_add_combat_log_entry("All weapons on standby", "system")

func _toggle_shields():
	shields_raised = not shields_raised

	if GameState.is_station_authenticated():
		GameState.send_input_event("raise_shields", shields_raised)

	_add_combat_log_entry("Shields " + ("RAISED" if shields_raised else "LOWERED"), "shields")
	GameState.audio_manager.play_success_sound()

func _modulate_shields():
	if GameState.is_station_authenticated():
		var context = {"modulation": "random"}
		GameState.send_input_event("shield_modulation", true, context)

	_add_combat_log_entry("Shield frequency modulated", "shields")
	GameState.audio_manager.play_success_sound()

func _lock_target():
	if selected_target_id != "":
		if GameState.is_station_authenticated():
			GameState.send_input_event("target_lock", selected_target_id)
		_add_combat_log_entry("Target locked: " + target_name.text, "targeting")
		GameState.audio_manager.play_success_sound()

func _scan_target():
	if selected_target_id != "":
		if GameState.is_station_authenticated():
			GameState.send_input_event("tactical_scan", selected_target_id)
		_add_combat_log_entry("Scanning target: " + target_name.text, "sensors")
		GameState.audio_manager.play_success_sound()

func _zoom_tactical_out():
	tactical_camera.zoom /= 1.5
	GameState.audio_manager.play_button_sound()

func _zoom_tactical_in():
	tactical_camera.zoom *= 1.5
	GameState.audio_manager.play_button_sound()

func _center_tactical_display():
	var player_ship = GameState.get_player_ship()
	if player_ship:
		var position = player_ship.get("position", {})
		if position.has("x") and position.has("z"):
			var player_pos = Vector2(position.x, position.z) * tactical_map_scale
			tactical_camera.global_position = player_pos
	GameState.audio_manager.play_button_sound()

func _long_range_scan():
	if GameState.is_station_authenticated():
		GameState.send_input_event("long_range_scan", true)
	_add_combat_log_entry("Long range scan initiated", "sensors")
	GameState.audio_manager.play_success_sound()

func _update_ammunition_display():
	photon_torpedoes.text = "Photon Torpedoes: " + str(ammunition_count.get("photon", 0))
	quantum_torpedoes.text = "Quantum Torpedoes: " + str(ammunition_count.get("quantum", 0))
	proximity_mines.text = "Proximity Mines: " + str(ammunition_count.get("mines", 0))
	phaser_cells.text = "Phaser Cells: " + str(ammunition_count.get("phaser_cells", 0)) + "%"

func _add_combat_log_entry(message: String, log_type: String = "info"):
	var timestamp = Time.get_datetime_string_from_system().substr(11, 8)
	var color = "white"

	match log_type:
		"error": color = "red"
		"weapons": color = "red"
		"shields": color = "blue"
		"targeting": color = "yellow"
		"sensors": color = "cyan"
		"system": color = "green"

	var formatted_entry = "[color=gray]%s[/color] [color=%s]%s[/color]" % [timestamp, color, message]
	log_text.append_text(formatted_entry + "\n")

	log_entries.append({
		"timestamp": timestamp,
		"message": message,
		"type": log_type
	})

	if log_entries.size() > 300:
		log_entries.pop_front()

func _clear_combat_log():
	log_text.clear()
	log_text.append_text("[color=red]Combat log cleared[/color]\n")
	log_entries.clear()
	GameState.audio_manager.play_success_sound()

func _on_universe_updated(state_data: Dictionary):
	if selected_target_id != "":
		var target_data = GameState.get_object(selected_target_id)
		if target_data:
			_update_target_info(target_data)

func _on_connection_status_changed(is_connected: bool):
	if is_connected:
		_add_combat_log_entry("Connected to tactical network", "system")
	else:
		_add_combat_log_entry("Disconnected from tactical network", "system")

func _on_alert_level_changed(level: int):
	var alert_names = ["GREEN", "YELLOW", "ORANGE", "RED"]
	var alert_name = alert_names[level] if level < alert_names.size() else "UNKNOWN"
	_add_combat_log_entry("Alert condition: " + alert_name, "system")

func _on_back_pressed():
	GameState.audio_manager.play_button_sound()
	GameState.audio_manager.stop_music(1.0)
	get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_on_back_pressed()
