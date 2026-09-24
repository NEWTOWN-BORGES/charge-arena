extends Node
## Menu music and one match theme per skin (campaign levels play their boss's theme). Tracks crossfade, dip during
## countdowns/goals, and pause while the app is in the background.
const TRACKS = {
	"cup": preload("res://audio/polished/music_cup.ogg"),
	"cup_boss": preload("res://audio/polished/music_skin_1.ogg"),
	"menu": preload("res://audio/polished/music_menu.ogg"),
	"match": preload("res://audio/polished/music_match.ogg"),
	"skin_1": preload("res://audio/polished/music_skin_1.ogg"),
	"skin_2": preload("res://audio/polished/music_skin_2.ogg"),
	"skin_3": preload("res://audio/polished/music_skin_3.ogg"),
	"skin_4": preload("res://audio/polished/music_skin_4.ogg"),
	"skin_5": preload("res://audio/polished/music_skin_5.ogg"),
	"skin_6": preload("res://audio/polished/music_skin_6.ogg"),
	"skin_7": preload("res://audio/polished/music_skin_7.ogg"),
	"skin_8": preload("res://audio/polished/music_skin_8.ogg"),
	"skin_9": preload("res://audio/polished/music_skin_9.ogg"),
	"skin_10": preload("res://audio/polished/music_skin_10.ogg"),
	"skin_11": preload("res://audio/polished/music_cup.ogg"),
}
const CONFIG_PATH = "user://audio_settings.cfg"
const FADE_SECONDS = 1.4
const BASE_DB = -7.0
# Masters preserve the original melodies, arrangements and tempo; originals remain archived.
const BOSS_PRESENCE_DB = 1.25
const DUCK_DB = {"countdown": -5.0, "goal": -9.0, "finished": -9.0}
const DUCK_SPEED_DB = 14.0
var enabled = true
var volume = 0.8
var track = ""
var players: Dictionary = {}
var levels: Dictionary = {}
var duck_db = 0.0
var duck_target_db = 0.0
var suspended = false

func _ready() -> void:
	for key in TRACKS:
		var player = AudioStreamPlayer.new()
		player.stream = TRACKS[key]
		# Enforce looping at runtime as well as in import settings, so an Android
		# incremental import cannot accidentally leave a skin theme one-shot.
		player.stream.loop = true
		player.volume_db = -80
		add_child(player)
		players[key] = player
		levels[key] = 0.0

func load_preferences(path: String = CONFIG_PATH) -> void:
	var config = ConfigFile.new()
	if config.load(path) != OK:
		return
	configure(bool(config.get_value("music", "enabled", true)), float(config.get_value("music", "volume", 0.8)))

func configure(on: bool, new_volume: float) -> void:
	enabled = on
	volume = clampf(new_volume, 0, 1)

func save_preferences(path: String = CONFIG_PATH) -> Error:
	var config = ConfigFile.new()
	config.set_value("music", "enabled", enabled)
	config.set_value("music", "volume", volume)
	return config.save(path)

func play(key: String) -> void:
	if TRACKS.has(key):
		track = key

func play_skin(index: int) -> void:
	play("match" if index <= 0 else "skin_%d" % clampi(index, 1, 11))

func follow_phase(phase: String) -> void:
	duck_target_db = DUCK_DB.get(phase, 0.0)

func gain_db(key: String) -> float:
	# Squared slider gives a more even loudness taper than a linear one.
	var presence = BOSS_PRESENCE_DB if key.begins_with("skin_") or key == "cup_boss" else 0.0
	return linear_to_db(maxf(levels[key] * volume * volume, 0.00001)) + BASE_DB + duck_db + presence

func _process(dt: float) -> void:
	if suspended:
		return
	duck_db = move_toward(duck_db, duck_target_db, DUCK_SPEED_DB * dt)
	for key in players:
		var target = 1.0 if enabled and key == track else 0.0
		levels[key] = move_toward(levels[key], target, dt / FADE_SECONDS)
		var player: AudioStreamPlayer = players[key]
		if levels[key] <= 0.0:
			# A silent track restarts from its beginning the next time it is chosen.
			if player.playing:
				player.stop()
			continue
		player.volume_db = gain_db(key)
		if not player.playing:
			player.play()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_RESUMED:
		suspended = what == NOTIFICATION_APPLICATION_PAUSED
		for player in players.values():
			player.stream_paused = suspended
