extends Node
class_name AudioManager

signal audio_settings_changed

var master_bus_index: int
var music_bus_index: int
var sfx_bus_index: int
var ui_bus_index: int
var ambient_bus_index: int
var voice_bus_index: int

var current_music_track: AudioStreamPlayer
var ambient_player: AudioStreamPlayer
var ui_sounds: Dictionary = {}
var alert_sounds: Dictionary = {}
var current_alert_level: int = 0
var music_fade_tween: Tween

var music_tracks: Dictionary = {
	"menu": "res://audio/music/celestial_menu.ogg",
	"exploration": "res://audio/music/space_ambient.ogg",
	"combat": "res://audio/music/battle_stations.ogg",
	"alert": "res://audio/music/red_alert.ogg",
	"victory": "res://audio/music/mission_complete.ogg"
}

var ambient_sounds: Dictionary = {
	"bridge": "res://audio/ambient/bridge_hum.ogg",
	"space": "res://audio/ambient/space_ambient.ogg",
	"warp": "res://audio/ambient/warp_core.ogg",
	"alert": "res://audio/ambient/alert_klaxon.ogg"
}

var ui_sound_files: Dictionary = {
	"button_hover": "res://audio/ui/button_hover.ogg",
	"button_click": "res://audio/ui/button_click.ogg",
	"panel_open": "res://audio/ui/panel_open.ogg",
	"panel_close": "res://audio/ui/panel_close.ogg",
	"error": "res://audio/ui/error_beep.ogg",
	"success": "res://audio/ui/success_chime.ogg",
	"alert": "res://audio/ui/alert_tone.ogg",
	"typing": "res://audio/ui/keyboard_type.ogg"
}

var alert_sound_files: Dictionary = {
	0: "",  # No alert
	1: "res://audio/alerts/yellow_alert.ogg",
	2: "res://audio/alerts/orange_alert.ogg",
	3: "res://audio/alerts/red_alert.ogg"
}

var station_ambient_settings: Dictionary = {
	"helm": {"volume": -5, "ambient": "bridge"},
	"tactical": {"volume": -3, "ambient": "bridge"},
	"communication": {"volume": -8, "ambient": "bridge"},
	"logistics": {"volume": -6, "ambient": "bridge"},
	"captain": {"volume": -4, "ambient": "bridge"},
	"gamemaster": {"volume": -10, "ambient": "space"},
	"viewscreen": {"volume": 0, "ambient": "space"}
}

func _ready():
	_setup_audio_buses()
	_load_ui_sounds()
	_setup_music_player()
	_setup_ambient_player()
	_load_alert_sounds()

func _setup_audio_buses():
	master_bus_index = AudioServer.get_bus_index("Master")
	music_bus_index = AudioServer.get_bus_index("Music")
	sfx_bus_index = AudioServer.get_bus_index("SFX")
	ui_bus_index = AudioServer.get_bus_index("UI")
	ambient_bus_index = AudioServer.get_bus_index("Ambient")
	voice_bus_index = AudioServer.get_bus_index("Voice")

	if music_bus_index == -1:
		music_bus_index = AudioServer.bus_count
		AudioServer.add_bus(music_bus_index)
		AudioServer.set_bus_name(music_bus_index, "Music")
		AudioServer.set_bus_send(music_bus_index, "Master")

	if sfx_bus_index == -1:
		sfx_bus_index = AudioServer.bus_count
		AudioServer.add_bus(sfx_bus_index)
		AudioServer.set_bus_name(sfx_bus_index, "SFX")
		AudioServer.set_bus_send(sfx_bus_index, "Master")

	if ui_bus_index == -1:
		ui_bus_index = AudioServer.bus_count
		AudioServer.add_bus(ui_bus_index)
		AudioServer.set_bus_name(ui_bus_index, "UI")
		AudioServer.set_bus_send(ui_bus_index, "Master")

	if ambient_bus_index == -1:
		ambient_bus_index = AudioServer.bus_count
		AudioServer.add_bus(ambient_bus_index)
		AudioServer.set_bus_name(ambient_bus_index, "Ambient")
		AudioServer.set_bus_send(ambient_bus_index, "Master")

	if voice_bus_index == -1:
		voice_bus_index = AudioServer.bus_count
		AudioServer.add_bus(voice_bus_index)
		AudioServer.set_bus_name(voice_bus_index, "Voice")
		AudioServer.set_bus_send(voice_bus_index, "Master")

func _setup_music_player():
	current_music_track = AudioStreamPlayer.new()
	current_music_track.bus = "Music"
	current_music_track.volume_db = -10
	add_child(current_music_track)

	music_fade_tween = create_tween()

func _setup_ambient_player():
	ambient_player = AudioStreamPlayer.new()
	ambient_player.bus = "Ambient"
	ambient_player.volume_db = -15
	add_child(ambient_player)

func _load_ui_sounds():
	for sound_name in ui_sound_files:
		var sound_path = ui_sound_files[sound_name]
		if ResourceLoader.exists(sound_path):
			ui_sounds[sound_name] = load(sound_path)

func _load_alert_sounds():
	for level in alert_sound_files:
		var sound_path = alert_sound_files[level]
		if sound_path != "" and ResourceLoader.exists(sound_path):
			alert_sounds[level] = load(sound_path)

func play_music(track_name: String, fade_time: float = 2.0):
	if not music_tracks.has(track_name):
		print("AudioManager: Unknown music track: ", track_name)
		return

	var track_path = music_tracks[track_name]
	if not ResourceLoader.exists(track_path):
		print("AudioManager: Music file not found: ", track_path)
		return

	var new_stream = load(track_path)

	if current_music_track.playing:
		music_fade_tween.tween_property(current_music_track, "volume_db", -80, fade_time / 2.0)
		await music_fade_tween.tween_callback(_switch_music_track.bind(new_stream))
		music_fade_tween.tween_property(current_music_track, "volume_db", -10, fade_time / 2.0)
	else:
		current_music_track.stream = new_stream
		current_music_track.play()

func _switch_music_track(new_stream):
	current_music_track.stop()
	current_music_track.stream = new_stream
	current_music_track.play()

func stop_music(fade_time: float = 2.0):
	if current_music_track.playing:
		music_fade_tween.tween_property(current_music_track, "volume_db", -80, fade_time)
		await music_fade_tween.finished
		current_music_track.stop()
		current_music_track.volume_db = -10

func play_ambient(ambient_name: String):
	if not ambient_sounds.has(ambient_name):
		print("AudioManager: Unknown ambient sound: ", ambient_name)
		return

	var ambient_path = ambient_sounds[ambient_name]
	if not ResourceLoader.exists(ambient_path):
		print("AudioManager: Ambient file not found: ", ambient_path)
		return

	var ambient_stream = load(ambient_path)
	ambient_player.stream = ambient_stream
	ambient_player.play()

func stop_ambient():
	ambient_player.stop()

func play_ui_sound(sound_name: String, volume_offset: float = 0.0):
	if not ui_sounds.has(sound_name):
		print("AudioManager: Unknown UI sound: ", sound_name)
		return

	var player = AudioStreamPlayer.new()
	player.bus = "UI"
	player.stream = ui_sounds[sound_name]
	player.volume_db += volume_offset
	add_child(player)
	player.play()

	await player.finished
	player.queue_free()

func play_sfx_3d(sound_path: String, position: Vector3, volume: float = 0.0):
	if not ResourceLoader.exists(sound_path):
		print("AudioManager: SFX file not found: ", sound_path)
		return null

	var player = AudioStreamPlayer3D.new()
	player.stream = load(sound_path)
	player.position = position
	player.volume_db = volume
	player.bus = "SFX"

	get_tree().current_scene.add_child(player)
	player.play()

	await player.finished
	player.queue_free()

	return player

func play_weapon_fire_sound(weapon_type: String, position: Vector3):
	var sound_path = ""
	match weapon_type:
		"phaser":
			sound_path = "res://audio/weapons/phaser_fire.ogg"
		"torpedo":
			sound_path = "res://audio/weapons/torpedo_launch.ogg"
		"laser":
			sound_path = "res://audio/weapons/laser_fire.ogg"

	if sound_path != "":
		play_sfx_3d(sound_path, position, -5.0)

func play_explosion_sound(position: Vector3, intensity: float = 1.0):
	var volume = clamp(-10 + (intensity * 10), -30, 5)
	play_sfx_3d("res://audio/explosions/explosion_large.ogg", position, volume)

func play_engine_sound(position: Vector3, throttle: float):
	var volume = -20 + (throttle * 15)
	play_sfx_3d("res://audio/engines/warp_engine.ogg", position, volume)

func play_error_sound():
	play_ui_sound("error", 5.0)

func play_success_sound():
	play_ui_sound("success")

func play_button_sound():
	play_ui_sound("button_click")

func play_hover_sound():
	play_ui_sound("button_hover", -10.0)

func play_typing_sound():
	play_ui_sound("typing", -15.0)

func update_alert_level(level: int):
	if level == current_alert_level:
		return

	current_alert_level = level

	if level == 0:
		stop_ambient()
		play_music("exploration")
	elif level == 1:
		play_ambient("alert")
		play_music("combat", 1.0)
	elif level == 2:
		play_ambient("alert")
		play_music("combat", 0.5)
	elif level == 3:
		play_ambient("alert")
		play_music("alert", 0.3)

	if alert_sounds.has(level) and level > 0:
		var player = AudioStreamPlayer.new()
		player.bus = "UI"
		player.stream = alert_sounds[level]
		player.volume_db = 0
		add_child(player)
		player.play()

		await player.finished
		player.queue_free()

func set_station_audio_profile(station: String):
	if not station_ambient_settings.has(station):
		return

	var settings = station_ambient_settings[station]
	AudioServer.set_bus_volume_db(ambient_bus_index, settings.volume)

	if settings.has("ambient"):
		play_ambient(settings.ambient)

func set_master_volume(volume_percent: float):
	var db = linear_to_db(volume_percent / 100.0)
	AudioServer.set_bus_volume_db(master_bus_index, db)

func set_music_volume(volume_percent: float):
	var db = linear_to_db(volume_percent / 100.0)
	AudioServer.set_bus_volume_db(music_bus_index, db)

func set_sfx_volume(volume_percent: float):
	var db = linear_to_db(volume_percent / 100.0)
	AudioServer.set_bus_volume_db(sfx_bus_index, db)

func set_ui_volume(volume_percent: float):
	var db = linear_to_db(volume_percent / 100.0)
	AudioServer.set_bus_volume_db(ui_bus_index, db)

func set_ambient_volume(volume_percent: float):
	var db = linear_to_db(volume_percent / 100.0)
	AudioServer.set_bus_volume_db(ambient_bus_index, db)

func set_voice_volume(volume_percent: float):
	var db = linear_to_db(volume_percent / 100.0)
	AudioServer.set_bus_volume_db(voice_bus_index, db)

func get_master_volume() -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(master_bus_index)) * 100.0

func get_music_volume() -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(music_bus_index)) * 100.0

func get_sfx_volume() -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(sfx_bus_index)) * 100.0

func get_ui_volume() -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(ui_bus_index)) * 100.0

func get_ambient_volume() -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(ambient_bus_index)) * 100.0

func get_voice_volume() -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(voice_bus_index)) * 100.0

func mute_all():
	AudioServer.set_bus_mute(master_bus_index, true)

func unmute_all():
	AudioServer.set_bus_mute(master_bus_index, false)

func is_muted() -> bool:
	return AudioServer.is_bus_mute(master_bus_index)
