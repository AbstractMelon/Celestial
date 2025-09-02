extends Control

@onready var status_value = $MainContainer/ConnectionStatus/StatusValue
@onready var server_input = $MainContainer/ServerContainer/ServerInput
@onready var connect_button = $MainContainer/ServerContainer/ConnectButton
@onready var station_grid = $MainContainer/StationGrid
@onready var viewscreen_button = $MainContainer/ViewscreenButton
@onready var settings_button = $MainContainer/BottomContainer/SettingsButton
@onready var exit_button = $MainContainer/BottomContainer/ExitButton

var station_buttons: Dictionary = {}
var is_connecting: bool = false
var connection_timer: Timer
var star_particles: Array = []
var settings_dialog: AcceptDialog

func _ready():
	_setup_ui()
	_connect_signals()
	_update_connection_status()

	GameState.audio_manager.play_music("menu", 0)

func _setup_ui():
	station_buttons = {
		"helm": $MainContainer/StationGrid/HelmButton,
		"tactical": $MainContainer/StationGrid/TacticalButton,
		"communication": $MainContainer/StationGrid/CommunicationButton,
		"logistics": $MainContainer/StationGrid/LogisticsButton,
		"captain": $MainContainer/StationGrid/CaptainButton,
		"gamemaster": $MainContainer/StationGrid/GameMasterButton
	}

	for station_name in station_buttons:
		var button = station_buttons[station_name]
		button.pressed.connect(_on_station_selected.bind(station_name))
		button.disabled = true

	viewscreen_button.pressed.connect(_on_station_selected.bind("viewscreen"))
	viewscreen_button.disabled = true

	connect_button.pressed.connect(_on_connect_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

	server_input.text_submitted.connect(_on_server_input_submitted)

	connection_timer = Timer.new()
	connection_timer.wait_time = 5.0
	connection_timer.one_shot = true
	connection_timer.timeout.connect(_on_connection_timeout)
	add_child(connection_timer)
	
func _connect_signals():
	if GameState:
		GameState.connection_status_changed.connect(_on_connection_status_changed)
		GameState.station_changed.connect(_on_station_changed)

func _update_connection_status():
	if not GameState:
		status_value.text = "No GameState"
		status_value.modulate = Color.RED
		return

	var status = GameState.get_connection_status()

	match status:
		"Connected":
			status_value.text = "Connected"
			status_value.modulate = Color.GREEN
			_enable_station_buttons(true)
			connect_button.text = "Disconnect"
		"Connecting":
			status_value.text = "Connecting..."
			status_value.modulate = Color.YELLOW
			_enable_station_buttons(false)
			connect_button.text = "Cancel"
		"Disconnected":
			status_value.text = "Disconnected"
			status_value.modulate = Color.RED
			_enable_station_buttons(false)
			connect_button.text = "Connect"
		_:
			status_value.text = status
			status_value.modulate = Color.ORANGE
			_enable_station_buttons(false)
			connect_button.text = "Connect"

func _enable_station_buttons(enabled: bool):
	for button in station_buttons.values():
		button.disabled = not enabled

	viewscreen_button.disabled = not enabled

func _on_connection_status_changed(is_connected: bool):
	_update_connection_status()
	connection_timer.stop()
	is_connecting = false

	if is_connected:
		GameState.audio_manager.play_success_sound()
		print("MainMenu: Successfully connected to server")
	else:
		GameState.audio_manager.play_error_sound()
		print("MainMenu: Disconnected from server")

func _on_station_changed(station_name: String):
	print("MainMenu: Station changed to: ", station_name)

func _on_connect_pressed():
	GameState.audio_manager.play_button_sound()

	if GameState.get_connection_status() == "Connected":
		GameState.websocket_client.disconnect_from_server()
		return

	if is_connecting:
		connection_timer.stop()
		is_connecting = false
		_update_connection_status()
		return

	var server_url = server_input.text.strip_edges()
	if server_url == "":
		server_url = "ws://localhost:8080/ws"
		server_input.text = server_url

	print("MainMenu: Connecting to server: ", server_url)
	is_connecting = true
	connection_timer.start()
	_update_connection_status()

	GameState.connect_to_server(server_url)

func _on_connection_timeout():
	is_connecting = false
	_update_connection_status()
	GameState.audio_manager.play_error_sound()
	print("MainMenu: Connection timeout")

func _on_server_input_submitted(text: String):
	if text.strip_edges() != "":
		_on_connect_pressed()

func _on_station_selected(station_name: String):
	if GameState.get_connection_status() != "Connected":
		GameState.audio_manager.play_error_sound()
		return

	GameState.audio_manager.play_button_sound()
	print("MainMenu: Selecting station: ", station_name)

	var scene_path = GameState.station_scenes.get(station_name, "")
	if scene_path == "":
		print("MainMenu: No scene path for station: ", station_name)
		return

	GameState.switch_station(station_name)
	GameState.audio_manager.stop_music(1.0)

	var transition_time = 0.5
	var fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.modulate.a = 0.0
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fade_rect)

	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, transition_time)
	await tween.finished

	get_tree().change_scene_to_file(scene_path)

func _on_settings_pressed():
	GameState.audio_manager.play_button_sound()
	_show_settings_dialog()

func _show_settings_dialog():
	if settings_dialog:
		settings_dialog.queue_free()

	settings_dialog = AcceptDialog.new()
	settings_dialog.title = "Celestial Bridge Settings"
	settings_dialog.size = Vector2(600, 400)
	add_child(settings_dialog)

	var vbox = VBoxContainer.new()
	settings_dialog.add_child(vbox)

	var audio_section = Label.new()
	audio_section.text = "Audio Settings"
	audio_section.add_theme_font_size_override("font_size", 18)
	vbox.add_child(audio_section)

	var master_volume = _create_volume_slider("Master Volume", GameState.audio_manager.get_master_volume())
	master_volume.value_changed.connect(GameState.audio_manager.set_master_volume)
	vbox.add_child(master_volume)

	var music_volume = _create_volume_slider("Music Volume", GameState.audio_manager.get_music_volume())
	music_volume.value_changed.connect(GameState.audio_manager.set_music_volume)
	vbox.add_child(music_volume)

	var sfx_volume = _create_volume_slider("SFX Volume", GameState.audio_manager.get_sfx_volume())
	sfx_volume.value_changed.connect(GameState.audio_manager.set_sfx_volume)
	vbox.add_child(sfx_volume)

	var input_section = Label.new()
	input_section.text = "Input Settings"
	input_section.add_theme_font_size_override("font_size", 18)
	vbox.add_child(input_section)

	var hotas_status = Label.new()
	var hotas_info = GameState.input_manager.get_hotas_status()
	if hotas_info.connected:
		hotas_status.text = "HOTAS Connected: " + str(hotas_info.count) + " device(s)"
		hotas_status.modulate = Color.GREEN
	else:
		hotas_status.text = "No HOTAS devices detected"
		hotas_status.modulate = Color.ORANGE
	vbox.add_child(hotas_status)

	var calibrate_button = Button.new()
	calibrate_button.text = "Calibrate HOTAS"
	calibrate_button.disabled = not hotas_info.connected
	calibrate_button.pressed.connect(_start_hotas_calibration)
	vbox.add_child(calibrate_button)

	settings_dialog.popup_centered()

func _create_volume_slider(label_text: String, initial_value: float) -> HBoxContainer:
	var container = HBoxContainer.new()

	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 120
	container.add_child(label)

	var slider = HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.value = initial_value
	slider.custom_minimum_size.x = 200
	container.add_child(slider)

	var value_label = Label.new()
	value_label.text = str(int(initial_value)) + "%"
	value_label.custom_minimum_size.x = 50
	container.add_child(value_label)

	slider.value_changed.connect(func(value): value_label.text = str(int(value)) + "%")

	return container

func _start_hotas_calibration():
	print("MainMenu: Starting HOTAS calibration")
	GameState.audio_manager.play_success_sound()

func _on_exit_pressed():
	GameState.audio_manager.play_button_sound()

	var confirmation = ConfirmationDialog.new()
	confirmation.dialog_text = "Are you sure you want to exit the Celestial Bridge Simulator?"
	confirmation.title = "Confirm Exit"
	add_child(confirmation)

	confirmation.confirmed.connect(_confirm_exit)
	confirmation.popup_centered()

func _confirm_exit():
	print("MainMenu: Exiting application")
	if GameState:
		GameState.audio_manager.stop_music(0.5)
		if GameState.websocket_client:
			GameState.websocket_client.disconnect_from_server()

	get_tree().quit()

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		_on_exit_pressed()
	elif event.is_action_pressed("ui_accept") and connect_button.has_focus():
		_on_connect_pressed()

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_confirm_exit()
