extends Control

@onready var camera = $SubViewport/Camera3D
@onready var universe_container = $SubViewport/UniverseContainer
@onready var ships_container = $SubViewport/UniverseContainer/ShipsContainer
@onready var projectiles_container = $SubViewport/UniverseContainer/ProjectilesContainer
@onready var effects_container = $SubViewport/UniverseContainer/EffectsContainer
@onready var environment_container = $SubViewport/UniverseContainer/EnvironmentContainer
@onready var planets_container = $SubViewport/UniverseContainer/PlanetsContainer
@onready var stations_container = $SubViewport/UniverseContainer/StationsContainer
@onready var particle_effects = $SubViewport/ParticleEffects
@onready var engine_trails = $SubViewport/ParticleEffects/EngineTrails
@onready var weapon_effects = $SubViewport/ParticleEffects/WeaponEffects
@onready var explosion_effects = $SubViewport/ParticleEffects/ExplosionEffects
@onready var starfield = $SubViewport/StarField

@onready var health_value = $HUDOverlay/TopHUD/LeftInfo/ShipStatus/StatusGrid/HealthValue
@onready var shield_value = $HUDOverlay/TopHUD/LeftInfo/ShipStatus/StatusGrid/ShieldValue
@onready var power_value = $HUDOverlay/TopHUD/LeftInfo/ShipStatus/StatusGrid/PowerValue
@onready var ship_name = $HUDOverlay/TopHUD/CenterInfo/ShipName
@onready var alert_level = $HUDOverlay/TopHUD/CenterInfo/AlertLevel
@onready var velocity_value = $HUDOverlay/TopHUD/RightInfo/NavigationPanel/NavGrid/VelocityValue
@onready var heading_value = $HUDOverlay/TopHUD/RightInfo/NavigationPanel/NavGrid/HeadingValue
@onready var time_value = $HUDOverlay/TopHUD/RightInfo/NavigationPanel/NavGrid/TimeValue
@onready var connection_status = $HUDOverlay/ConnectionStatus
@onready var back_button = $HUDOverlay/BackButton
@onready var contacts_vbox = $HUDOverlay/BottomHUD/ContactsList/ContactsScroll/ContactsVBox
@onready var threat_bar = $HUDOverlay/BottomHUD/ThreatLevel/ThreatBar
@onready var threat_value = $HUDOverlay/BottomHUD/ThreatLevel/ThreatValue
@onready var camera_mode_button = $HUDOverlay/CameraControls/CameraModeButton
@onready var view_mode_button = $HUDOverlay/CameraControls/ViewModeButton
@onready var zoom_slider = $HUDOverlay/CameraControls/ZoomSlider

var rendered_objects: Dictionary = {}
var rendered_effects: Dictionary = {}
var camera_mode: String = "follow_ship"
var view_mode: String = "external"
var camera_target: Node3D = null
var camera_offset: Vector3 = Vector3(0, 50, 100)
var camera_smooth_speed: float = 5.0
var zoom_distance: float = 300.0
var camera_rotation_speed: float = 2.0

var player_ship_node: Node3D = null
var universe_scale: float = 0.01
var effect_duration_tracker: Dictionary = {}
var particle_systems: Dictionary = {}

var star_positions: Array = []
var nebula_effects: Array = []

var camera_modes: Array = ["follow_ship", "free_camera", "tactical_view", "orbit_ship"]
var view_modes: Array = ["external", "bridge", "tactical"]
var current_camera_index: int = 0
var current_view_index: int = 0

var mouse_sensitivity: float = 0.002
var camera_pitch: float = 0.0
var camera_yaw: float = 0.0
var is_mouse_captured: bool = false

func _ready():
	_setup_connections()
	_setup_camera()
	_setup_starfield()
	_setup_ui()

	GameState.switch_station("viewscreen")
	GameState.audio_manager.set_station_audio_profile("viewscreen")
	GameState.audio_manager.play_music("exploration")

	print("[Viewscreen] Viewscreen ready")

func _setup_connections():
	if GameState:
		GameState.universe_state_updated.connect(_on_universe_updated)
		GameState.connection_status_changed.connect(_on_connection_status_changed)
		GameState.alert_level_changed.connect(_on_alert_level_changed)

	back_button.pressed.connect(_on_back_pressed)
	camera_mode_button.pressed.connect(_cycle_camera_mode)
	view_mode_button.pressed.connect(_cycle_view_mode)
	zoom_slider.value_changed.connect(_on_zoom_changed)

func _setup_camera():
	camera.fov = 75.0
	camera.position = Vector3(0, 200, 300)
	camera.look_at(Vector3.ZERO, Vector3.UP)

func _setup_starfield():
	_generate_stars(2000)
	_generate_nebulae(5)

func _setup_ui():
	camera_mode_button.text = camera_mode.capitalize().replace("_", " ")
	view_mode_button.text = view_mode.capitalize()
	zoom_slider.value = zoom_distance

func _generate_stars(count: int):
	for i in range(count):
		var star_pos = Vector3(
			randf_range(-50000, 50000),
			randf_range(-50000, 50000),
			randf_range(-50000, 50000)
		)

		var star = MeshInstance3D.new()
		var sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = randf_range(10, 50)
		star.mesh = sphere_mesh

		var material = StandardMaterial3D.new()
		var brightness = randf_range(0.5, 1.0)
		var star_color = Color(brightness, brightness * randf_range(0.8, 1.2), brightness * randf_range(0.6, 1.0))
		material.albedo_color = star_color
		material.emission_enabled = true
		material.emission = star_color
		material.emission_energy = randf_range(2.0, 8.0)
		material.flags_unshaded = true
		star.material_override = material

		star.position = star_pos
		starfield.add_child(star)
	print("[Viewscreen] Stars ready")

func _generate_nebulae(count: int):
	for i in range(count):
		var nebula = GPUParticles3D.new()
		var material = ParticleProcessMaterial.new()

		material.direction = Vector3(0, 1, 0)
		material.initial_velocity_min = 0.0
		material.initial_velocity_max = 5.0
		material.gravity = Vector3.ZERO
		material.scale_min = 50.0
		material.scale_max = 200.0
		material.color = Color(randf_range(0.2, 0.8), randf_range(0.2, 0.8), 1.0, 0.3)

		nebula.process_material = material
		nebula.amount = 500
		nebula.lifetime = 30.0
		nebula.position = Vector3(
			randf_range(-20000, 20000),
			randf_range(-5000, 5000),
			randf_range(-20000, 20000)
		)

		starfield.add_child(nebula)
		nebula.emitting = true
	print("[Viewscreen] Nebula Ready")

func _process(delta):
	_update_camera(delta)
	_update_effects(delta)
	_update_hud()

func _update_camera(delta: float):
	if not camera:
		return

	match camera_mode:
		"follow_ship":
			_update_follow_ship_camera(delta)
		"free_camera":
			_update_free_camera(delta)
		"tactical_view":
			_update_tactical_camera(delta)
		"orbit_ship":
			_update_orbit_camera(delta)

func _update_follow_ship_camera(delta: float):
	if player_ship_node:
		var target_pos = player_ship_node.global_position + camera_offset
		camera.global_position = camera.global_position.lerp(target_pos, camera_smooth_speed * delta)
		camera.look_at(player_ship_node.global_position, Vector3.UP)

func _update_free_camera(delta: float):
	var input_vector = Vector3.ZERO

	if Input.is_action_pressed("ui_up"):
		input_vector.z -= 1
	if Input.is_action_pressed("ui_down"):
		input_vector.z += 1
	if Input.is_action_pressed("ui_left"):
		input_vector.x -= 1
	if Input.is_action_pressed("ui_right"):
		input_vector.x += 1

	if input_vector.length() > 0:
		var speed = 500.0 * delta
		if Input.is_action_pressed("ui_accept"):
			speed *= 5.0

		camera.translate(input_vector.normalized() * speed)

func _update_tactical_camera(delta: float):
	if player_ship_node:
		var distance = zoom_distance * 2
		var height = distance * 0.5
		var target_pos = player_ship_node.global_position + Vector3(0, height, distance)
		camera.global_position = camera.global_position.lerp(target_pos, camera_smooth_speed * delta)
		camera.look_at(player_ship_node.global_position, Vector3.UP)

func _update_orbit_camera(delta: float):
	if player_ship_node:
		var time = Time.get_time_dict_from_system().get("second", 0) + Time.get_time_dict_from_system().get("minute", 0) * 60
		var orbit_angle = time * 0.1
		var orbit_radius = zoom_distance

		var orbit_pos = Vector3(
			sin(orbit_angle) * orbit_radius,
			orbit_radius * 0.3,
			cos(orbit_angle) * orbit_radius
		)

		camera.global_position = player_ship_node.global_position + orbit_pos
		camera.look_at(player_ship_node.global_position, Vector3.UP)

func _update_effects(delta: float):
	for effect_id in effect_duration_tracker.keys():
		effect_duration_tracker[effect_id] -= delta
		if effect_duration_tracker[effect_id] <= 0:
			_remove_effect(effect_id)

func _update_hud():
	var player_ship = GameState.get_player_ship()
	if player_ship:
		_update_ship_status(player_ship)

	_update_connection_status()
	_update_contacts()
	_update_threat_level()

func _update_ship_status(ship_data: Dictionary):
	var health = ship_data.get("health", 0)
	var max_health = ship_data.get("max_health", 100)
	var shield = ship_data.get("shield", 0)
	var max_shield = ship_data.get("max_shield", 100)
	var power = ship_data.get("power", 0)
	var max_power = ship_data.get("max_power", 100)
	var velocity = ship_data.get("velocity", {})

	health_value.text = str(int((health / max_health) * 100)) + "%"
	shield_value.text = str(int((shield / max_shield) * 100)) + "%"
	power_value.text = str(int((power / max_power) * 100)) + "%"

	if velocity.has("x") and velocity.has("y") and velocity.has("z"):
		var vel_magnitude = Vector3(velocity.x, velocity.y, velocity.z).length()
		velocity_value.text = str(int(vel_magnitude)) + " m/s"

	ship_name.text = ship_data.get("name", "USS CELESTIAL")

	var health_percent = health / max_health
	if health_percent > 0.75:
		health_value.modulate = Color.GREEN
	elif health_percent > 0.25:
		health_value.modulate = Color.YELLOW
	else:
		health_value.modulate = Color.RED

func _update_connection_status():
	var status = GameState.get_connection_status()
	connection_status.text = status.to_upper()

	match status:
		"Connected":
			connection_status.modulate = Color.GREEN
		"Connecting":
			connection_status.modulate = Color.YELLOW
		_:
			connection_status.modulate = Color.RED

func _update_contacts():
	for child in contacts_vbox.get_children():
		child.queue_free()

	var objects = GameState.get_universe_objects()
	var contact_count = 0

	for obj_id in objects:
		var obj = objects[obj_id]
		if obj.get("type", "") in ["ship", "station"] and not obj.get("is_player_ship", false):
			var contact_label = Label.new()
			contact_label.text = obj.get("name", "Unknown")
			contact_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
			contact_label.add_theme_font_size_override("font_size", 10)
			contacts_vbox.add_child(contact_label)

			contact_count += 1
			if contact_count >= 8:
				break

func _update_threat_level():
	var objects = GameState.get_universe_objects()
	var threat_level = 0
	var enemy_ships = 0

	for obj_id in objects:
		var obj = objects[obj_id]
		if obj.get("type", "") == "ship" and not obj.get("is_player_ship", false):
			enemy_ships += 1

	threat_level = min(enemy_ships * 20, 100)
	threat_bar.value = threat_level

	if threat_level < 25:
		threat_value.text = "LOW"
		threat_value.modulate = Color.GREEN
	elif threat_level < 75:
		threat_value.text = "MEDIUM"
		threat_value.modulate = Color.YELLOW
	else:
		threat_value.text = "HIGH"
		threat_value.modulate = Color.RED

func _on_universe_updated(state_data: Dictionary):
	_update_objects(state_data.get("objects", []))
	_update_visual_effects(state_data.get("effects", []))
	_remove_objects(state_data.get("removed", []))

func _update_objects(objects: Array):
	for obj_data in objects:
		var obj_id = obj_data.get("id", "")
		if obj_id == "":
			continue

		var obj_type = obj_data.get("type", "")
		_create_or_update_object(obj_id, obj_data, obj_type)

func _create_or_update_object(obj_id: String, obj_data: Dictionary, obj_type: String):
	var container = _get_container_for_type(obj_type)
	if not container:
		return

	var obj_node = rendered_objects.get(obj_id)

	if not obj_node:
		obj_node = _create_object_node(obj_data, obj_type)
		if obj_node:
			rendered_objects[obj_id] = obj_node
			container.add_child(obj_node)

			if obj_data.get("is_player_ship", false):
				player_ship_node = obj_node

	if obj_node:
		_update_object_node(obj_node, obj_data)

func _get_container_for_type(obj_type: String) -> Node3D:
	match obj_type:
		"ship":
			return ships_container
		"projectile", "torpedo", "missile":
			return projectiles_container
		"planet":
			return planets_container
		"station":
			return stations_container
		"asteroid", "debris":
			return environment_container
		_:
			return environment_container

func _create_object_node(obj_data: Dictionary, obj_type: String) -> Node3D:
	var node = Node3D.new()
	node.name = obj_data.get("name", obj_type + "_" + obj_data.get("id", "unknown"))

	var mesh_instance = MeshInstance3D.new()
	var mesh = _create_mesh_for_type(obj_type, obj_data)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _create_material_for_type(obj_type, obj_data)

	node.add_child(mesh_instance)

	if obj_type == "ship":
		_add_ship_effects(node, obj_data)

	print("[Viewscreen] Created object node: " + obj_data.get("name", obj_type + "_" + obj_data.get("id", "unknown")))
	return node

func _create_mesh_for_type(obj_type: String, obj_data: Dictionary) -> Mesh:
	match obj_type:
		"ship":
			var box_mesh = BoxMesh.new()
			box_mesh.size = Vector3(20, 5, 40)
			return box_mesh
		"planet":
			var sphere_mesh = SphereMesh.new()
			sphere_mesh.radius = obj_data.get("radius", 100) * universe_scale
			return sphere_mesh
		"station":
			var cylinder_mesh = CylinderMesh.new()
			cylinder_mesh.height = 30
			cylinder_mesh.top_radius = 15
			cylinder_mesh.bottom_radius = 15
			return cylinder_mesh
		"projectile", "torpedo":
			var capsule_mesh = CapsuleMesh.new()
			capsule_mesh.radius = 1
			capsule_mesh.height = 4
			return capsule_mesh
		_:
			var box_mesh = BoxMesh.new()
			box_mesh.size = Vector3(10, 10, 10)
			return box_mesh

func _create_material_for_type(obj_type: String, obj_data: Dictionary) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()

	match obj_type:
		"ship":
			if obj_data.get("is_player_ship", false):
				material.albedo_color = Color(0.2, 0.6, 1.0)
				material.emission_enabled = true
				material.emission = Color(0.1, 0.3, 0.5)
				material.emission_energy = 1.0
			else:
				material.albedo_color = Color(0.8, 0.3, 0.3)
				material.emission_enabled = true
				material.emission = Color(0.4, 0.1, 0.1)
				material.emission_energy = 0.5
		"planet":
			material.albedo_color = Color(0.3, 0.7, 0.4)
		"station":
			material.albedo_color = Color(0.7, 0.7, 0.7)
			material.emission_enabled = true
			material.emission = Color(0.3, 0.3, 0.3)
			material.emission_energy = 0.8
		"projectile", "torpedo":
			material.albedo_color = Color(1.0, 0.5, 0.2)
			material.emission_enabled = true
			material.emission = Color(1.0, 0.3, 0.1)
			material.emission_energy = 3.0
		_:
			material.albedo_color = Color(0.5, 0.5, 0.5)

	return material

func _add_ship_effects(ship_node: Node3D, obj_data: Dictionary):
	var engine_particles = GPUParticles3D.new()
	var process_material = ParticleProcessMaterial.new()

	process_material.direction = Vector3(0, 0, -1)
	process_material.initial_velocity_min = 50.0
	process_material.initial_velocity_max = 100.0
	process_material.gravity = Vector3.ZERO
	process_material.scale_min = 0.5
	process_material.scale_max = 2.0
	process_material.color = Color(0.2, 0.6, 1.0, 0.8)

	engine_particles.process_material = process_material
	engine_particles.amount = 50
	engine_particles.lifetime = 2.0
	engine_particles.position = Vector3(0, 0, -25)

	ship_node.add_child(engine_particles)
	engine_particles.emitting = true

func _update_object_node(node: Node3D, obj_data: Dictionary):
	var position = obj_data.get("position", {})
	if position.has("x") and position.has("y") and position.has("z"):
		node.position = Vector3(position.x, position.y, position.z) * universe_scale

	var rotation = obj_data.get("rotation", {})
	if rotation.has("x") and rotation.has("y") and rotation.has("z") and rotation.has("w"):
		node.quaternion = Quaternion(rotation.x, rotation.y, rotation.z, rotation.w)

func _update_visual_effects(effects: Array):
	for effect_data in effects:
		var effect_id = effect_data.get("id", "")
		if effect_id == "":
			continue

		_create_or_update_effect(effect_id, effect_data)

func _create_or_update_effect(effect_id: String, effect_data: Dictionary):
	var effect_type = effect_data.get("type", "")
	var duration = effect_data.get("duration", 1.0)

	effect_duration_tracker[effect_id] = effect_data.get("time_left", duration)

	if rendered_effects.has(effect_id):
		return

	match effect_type:
		"phaser_beam":
			_create_phaser_beam(effect_id, effect_data)
		"explosion":
			_create_explosion(effect_id, effect_data)
		"torpedo_trail":
			_create_torpedo_trail(effect_id, effect_data)

func _create_phaser_beam(effect_id: String, effect_data: Dictionary):
	var beam = MeshInstance3D.new()
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(2, 1000)
	beam.mesh = quad_mesh

	var material = StandardMaterial3D.new()
	material.flags_transparent = true
	material.flags_unshaded = true
	material.albedo_color = Color(1, 0.2, 0.2, 0.8)
	material.emission_enabled = true
	material.emission = Color(1, 0.2, 0.2)
	material.emission_energy = 5.0
	beam.material_override = material

	var position = effect_data.get("position", {})
	if position.has("x") and position.has("y") and position.has("z"):
		beam.position = Vector3(position.x, position.y, position.z) * universe_scale

	var direction = effect_data.get("direction", {})
	if direction.has("x") and direction.has("y") and direction.has("z"):
		beam.look_at(beam.position + Vector3(direction.x, direction.y, direction.z), Vector3.UP)

	weapon_effects.add_child(beam)
	rendered_effects[effect_id] = beam

	GameState.audio_manager.play_weapon_fire_sound("phaser", beam.position)

func _create_explosion(effect_id: String, effect_data: Dictionary):
	var explosion = GPUParticles3D.new()
	var process_material = ParticleProcessMaterial.new()

	process_material.direction = Vector3(0, 1, 0)
	process_material.initial_velocity_min = 100.0
	process_material.initial_velocity_max = 300.0
	process_material.gravity = Vector3.ZERO
	process_material.scale_min = 5.0
	process_material.scale_max = 20.0
	process_material.color = Color(1.0, 0.5, 0.1, 1.0)

	explosion.process_material = process_material
	explosion.amount = 200
	explosion.lifetime = 3.0

	var position = effect_data.get("position", {})
	if position.has("x") and position.has("y") and position.has("z"):
		explosion.position = Vector3(position.x, position.y, position.z) * universe_scale

	explosion_effects.add_child(explosion)
	explosion.emitting = true
	rendered_effects[effect_id] = explosion

	var intensity = effect_data.get("properties", {}).get("intensity", 1.0)
	GameState.audio_manager.play_explosion_sound(explosion.position, intensity)

func _create_torpedo_trail(effect_id: String, effect_data: Dictionary):
	var trail = GPUParticles3D.new()
	var process_material = ParticleProcessMaterial.new()

	process_material.direction = Vector3(0, 0, -1)
	process_material.initial_velocity_min = 20.0
	process_material.initial_velocity_max = 50.0
	process_material.gravity = Vector3.ZERO
	process_material.scale_min = 1.0
	process_material.scale_max = 3.0
	process_material.color = Color(1.0, 0.8, 0.2, 0.6)

	trail.process_material = process_material
	trail.amount = 30
	trail.lifetime = 1.0

	var position = effect_data.get("position", {})
	if position.has("x") and position.has("y") and position.has("z"):
		trail.position = Vector3(position.x, position.y, position.z) * universe_scale

	weapon_effects.add_child(trail)
	trail.emitting = true
	rendered_effects[effect_id] = trail

func _remove_effect(effect_id: String):
	if rendered_effects.has(effect_id):
		var effect_node = rendered_effects[effect_id]
		effect_node.queue_free()
		rendered_effects.erase(effect_id)

	effect_duration_tracker.erase(effect_id)

func _remove_objects(removed_ids: Array):
	for obj_id in removed_ids:
		if rendered_objects.has(obj_id):
			var obj_node = rendered_objects[obj_id]
			obj_node.queue_free()
			rendered_objects.erase(obj_id)

			if obj_node == player_ship_node:
				player_ship_node = null

func _cycle_camera_mode():
	GameState.audio_manager.play_button_sound()
	current_camera_index = (current_camera_index + 1) % camera_modes.size()
	camera_mode = camera_modes[current_camera_index]
	camera_mode_button.text = camera_mode.capitalize().replace("_", " ")

func _cycle_view_mode():
	GameState.audio_manager.play_button_sound()
	current_view_index = (current_view_index + 1) % view_modes.size()
	view_mode = view_modes[current_view_index]
	view_mode_button.text = view_mode.capitalize()

func _on_zoom_changed(value: float):
	zoom_distance = value
	camera_offset = Vector3(0, zoom_distance * 0.3, zoom_distance)

func _on_connection_status_changed(is_connected: bool):
	pass

func _on_alert_level_changed(level: int):
	var alert_colors = [
		Color.GREEN,     # Green
		Color.YELLOW,    # Yellow
		Color.ORANGE,    # Orange
		Color.RED        # Red
	]

	var alert_texts = [
		"CONDITION GREEN",
		"YELLOW ALERT",
		"ORANGE ALERT",
		"RED ALERT"
	]

	if level >= 0 and level < alert_colors.size():
		alert_level.text = alert_texts[level]
		alert_level.modulate = alert_colors[level]

func _on_back_pressed():
	GameState.audio_manager.play_button_sound()
	GameState.audio_manager.stop_music(1.0)
	get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				is_mouse_captured = true
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				is_mouse_captured = false

	elif event is InputEventMouseMotion and is_mouse_captured and camera_mode == "free_camera":
		camera_yaw -= event.relative.x * mouse_sensitivity
		camera_pitch -= event.relative.y * mouse_sensitivity
		camera_pitch = clamp(camera_pitch, -PI/2, PI/2)

		camera.rotation.y = camera_yaw
		camera.rotation.x = camera_pitch

	elif event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
