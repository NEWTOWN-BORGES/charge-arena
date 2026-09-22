extends SceneTree
# Background music follows the game: menu loop, match loop, ducking, the
# on/off and volume preferences, and silence while the app is suspended.
const Music = preload("res://scripts/music_player.gd")
var failures = 0

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: ", description)

func _initialize() -> void:
	call_deferred("run")

func advance(music, seconds: float) -> void:
	for i in range(roundi(seconds / 0.05)):
		music._process(0.05)

func run() -> void:
	var menu_stream: AudioStreamOggVorbis = Music.TRACKS.menu
	check(Music.TRACKS.size() == 14, "Menu, eleven skin themes and the tournament cues are loaded")
	var theme_hashes = range(1, 11).map(func(index): return FileAccess.get_sha256("res://audio/music_skin_%d.ogg" % index))
	check(theme_hashes.all(func(hash): return hash != "") and theme_hashes.duplicate().reduce(func(unique, hash): return unique + ([] if hash in unique else [hash]), []).size() == 10, "All ten skin themes contain distinct audio")
	check(absf(menu_stream.get_length() - 45.714) < 0.01 and absf(Music.TRACKS.match.get_length() - 64.0) < 0.03, "Original menu and standard skin duration unchanged")
	check(range(1, 11).all(func(i): return absf(Music.TRACKS["skin_%d" % i].get_length() - 64.0) < 0.03), "Original boss recordings restored at their original length")

	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	await process_frame
	await process_frame
	var music = game.music
	check(music.players.values().all(func(player): return player.stream.loop), "Every music track is configured as a seamless loop")
	music.set_process(false)
	music.configure(true, 0.8)
	game.skins.selected = 0
	advance(music, 2.0)
	check(music.players.menu.playing and not music.players.match.playing, "Menu music plays on the title screen")

	game.start_pve()
	advance(music, 0.7)
	check(music.players.menu.playing and music.players.match.playing and music.levels.menu < 1.0 and music.levels.match > 0.0, "Starting a match crossfades between the two loops")
	advance(music, 1.5)
	check(not music.players.menu.playing and is_equal_approx(music.levels.match, 1.0), "Menu loop stops once the match loop has taken over")
	game.return_to_menu()
	advance(music, 1.5)
	game.skins.selected = 3
	game.start_pve()
	advance(music, 0.7)
	check(music.track == "skin_3" and music.players.menu.playing and music.players.skin_3.playing, "Equipping the Gardener crossfades from the same menu music into its own theme")
	advance(music, 1.5)

	music.follow_phase("play")
	advance(music, 1.0)
	var playing_db: float = music.players.skin_3.volume_db
	music.follow_phase("countdown")
	advance(music, 1.0)
	check(is_equal_approx(music.players.skin_3.volume_db, playing_db - 5.0), "Music dips 5 dB during the countdown")
	music.follow_phase("goal")
	advance(music, 1.0)
	check(is_equal_approx(music.players.skin_3.volume_db, playing_db - 9.0), "Music dips 9 dB so the goal sound stands out")
	music.follow_phase("play")
	advance(music, 1.0)

	music.configure(true, 0.4)
	advance(music, 0.1)
	check(music.players.skin_3.volume_db < playing_db - 5.0, "Lower volume setting makes the music quieter")
	music.configure(false, 0.4)
	advance(music, 2.0)
	check(music.players.values().all(func(player): return not player.playing), "Turning music off silences every loop")
	music.configure(true, 0.8)
	advance(music, 0.2)
	check(music.players.skin_3.playing, "Turning music back on resumes the current skin theme")

	music._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	advance(music, 1.0)
	check(music.players.skin_3.stream_paused, "Leaving the app pauses the music")
	music._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(not music.players.skin_3.stream_paused, "Returning to the app resumes the music")

	game.return_to_menu()
	advance(music, 2.0)
	check(music.players.menu.playing and not music.players.skin_3.playing, "Returning to the menu brings the unchanged menu loop back")

	var saved = Music.new()
	saved.configure(false, 0.35)
	var path = "res://tests/audio-preferences.tmp"
	check(saved.save_preferences(path) == OK, "Music preferences save")
	var restored = Music.new()
	restored.load_preferences(path)
	check(not restored.enabled and is_equal_approx(restored.volume, 0.35), "Music on/off and volume survive a restart")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	restored.configure(true, 7.0)
	check(is_equal_approx(restored.volume, 1.0), "Out-of-range volume is clamped")
	saved.free()
	restored.free()

	var hud = game.hud
	hud.audio_changed.disconnect(game.change_audio)
	var received: Array = []
	hud.audio_changed.connect(func(on, volume): received.append([on, volume]))
	hud.sync_audio(music)
	check(hud.music_choice.button_pressed and is_equal_approx(hud.music_volume.value, 80), "Settings panel shows the current music preferences")
	hud.music_volume.value = 55
	hud.music_choice.button_pressed = false
	check(received.size() == 2 and received[0] == [true, 0.55] and received[1] == [false, 0.55], "Slider and switch report changes")
	check(not hud.music_volume.editable, "Volume slider is locked while music is off")
	print("MUSIC_RESULT failures=", failures)
	quit(failures)
