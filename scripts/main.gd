extends Node3D
const Rules = preload("res://scripts/arena_rules.gd")
const ArenaView = preload("res://scripts/indie_arena_view.gd")
const HUD = preload("res://scripts/game_hud.gd")
const VideoSettings = preload("res://scripts/video_settings.gd")
const Music = preload("res://scripts/music_player.gd")
const Skins = preload("res://scripts/skins.gd")
const GameSettings = preload("res://scripts/game_settings.gd")
const Campaign = preload("res://scripts/campaign.gd")
const PORT = 27940
var rules = Rules.new()
var arena
var hud
var mode = "menu"
var local_team = 0
var connected = false
var remote_id = 0
var remote_command = {"move": Vector2.ZERO, "fire": false}
var remote_age = 0.0
var network_tick = 0.0
var connection_timer = 0.0
var network_status = ""
var pause_ai = false
var tones: Dictionary = {}
var audio: AudioStreamPlayer
var audio_voices: Array = []
var audio_cursor = 0
var last_phase = ""
var last_stuns: Array = [0.0, 0.0]
var packets_received = 0
var mouse_firing = false
var video = VideoSettings.new()
var music
var visual_packet_age = 0.0
var hud_timer = 0.0
var fps_timer = 0.0
var pve_paused = false
var skins = Skins.new()
var game_settings = GameSettings.new()
var campaign = Campaign.new()
# Campaign level being played, or -1 for quick play, PvP and the menu.
var level_index = -1
# Level shown in the menu carousel, and the delay before its arena is rebuilt.
var menu_level = 0
var menu_preview_timer = -1.0
var client_boosted_ids: Dictionary = {}

func _ready() -> void:
	arena = ArenaView.new()
	add_child(arena)
	arena.build()
	var layer = CanvasLayer.new()
	add_child(layer)
	hud = HUD.new()
	layer.add_child(hud)
	hud.arena_aspect = arena.view_aspect()
	hud.layout_changed.connect(frame_arena)
	get_window().size_changed.connect(fit_content_scale)
	fit_content_scale()
	hud.play_requested.connect(start_pve)
	hud.host_requested.connect(host_game)
	hud.join_requested.connect(join_game)
	hud.menu_requested.connect(request_menu)
	hud.resume_requested.connect(resume_pve)
	hud.quit_requested.connect(return_to_menu)
	hud.replay_requested.connect(replay)
	hud.video_changed.connect(change_video)
	hud.video_opened.connect(func(): mouse_firing = false)
	hud.audio_changed.connect(change_audio)
	video.load_preferences()
	video.apply(get_viewport(), arena)
	hud.sync_video(video)
	music = Music.new()
	add_child(music)
	music.load_preferences()
	hud.sync_audio(music)
	music.play("menu")
	skins.load_preferences()
	hud.team_skins = arena.unit_skins
	hud.team_tints = arena.unit_tints
	hud.arena_view = arena
	hud.skin_selected.connect(select_skin)
	hud.sync_skins(skins)
	dress_pilots(0)
	game_settings.load_preferences()
	rules.ai_level = game_settings.difficulty
	arena.guide_enabled = game_settings.aim_guide
	hud.sync_game(game_settings)
	hud.difficulty_changed.connect(change_difficulty)
	hud.guide_changed.connect(change_guide)
	hud.sensitivity_changed.connect(change_sensitivity)
	campaign.load_preferences()
	sync_boss_skins()
	hud.sync_campaign(campaign)
	hud.level_selected.connect(start_level)
	hud.next_level_requested.connect(func(): start_level(level_index + 1))
	hud.levels_requested.connect(show_levels)
	hud.menu_level_changed.connect(step_menu_level)
	menu_level = campaign.suggested_level()
	hud.sync_menu_level(menu_level)
	show_menu_preview()
	hud.show_menu()
	get_window().focus_exited.connect(func(): hud.reset_touch(); mouse_firing = false)
	get_window().focus_exited.connect(pause_pve)
	multiplayer.peer_connected.connect(peer_connected)
	multiplayer.peer_disconnected.connect(peer_disconnected)
	multiplayer.connected_to_server.connect(joined_server)
	multiplayer.connection_failed.connect(func(): return_to_menu.call_deferred("Não foi possível ligar. Confirma o IP e a rede."))
	multiplayer.server_disconnected.connect(func(): return_to_menu.call_deferred("O anfitrião saiu da partida."))
	build_audio()
	for arg in OS.get_cmdline_user_args():
		if arg == "--pve":
			start_pve()
		if arg.begins_with("--capture="):
			capture_preview(arg.trim_prefix("--capture="))

func start_pve() -> void:
	pve_paused = false
	close_network()
	mode = "pve"
	local_team = 0
	network_status = ""
	leave_campaign()
	rules.reset_match()
	dress_pilots(local_team)
	hud.show_game(mode, local_team)
	music.play_skin(skins.selected)

func start_level(index: int) -> void:
	if not campaign.is_unlocked(index):
		return
	var level: Dictionary = Campaign.LEVELS[index]
	pve_paused = false
	close_network()
	mode = "pve"
	local_team = 0
	network_status = ""
	level_index = index
	menu_level = index
	hud.sync_menu_level(index)
	use_map(level.map)
	rules.ai_profile = Campaign.ai_profile(index, game_settings.difficulty)
	rules.reset_match()
	dress_pilots(local_team)
	# The boss wears its own skin and bricks, all in red until beaten, and brings its theme.
	arena.set_skin(1, level.boss, true)
	hud.level_info = {"number": index + 1, "name": level.name, "challenge": level.challenge, "boss_name": Skins.CATALOG[level.boss].name, "has_next": index + 1 < Campaign.LEVELS.size()}
	hud.level_result = ""
	hud.level_skin = ""
	hud.show_game(mode, local_team)
	music.play_skin(level.boss)

func leave_campaign(layout: Dictionary = {}) -> void:
	level_index = -1
	rules.ai_profile = {}
	hud.level_info = {}
	hud.level_result = ""
	hud.level_skin = ""
	use_map(layout if not layout.is_empty() else Rules.default_map())

func step_menu_level(step: int) -> void:
	var chosen = clampi(menu_level + step, 0, Campaign.LEVELS.size() - 1)
	if chosen == menu_level:
		return
	menu_level = chosen
	hud.sync_menu_level(menu_level)
	# The name updates at once; the arena follows once the thumb settles.
	menu_preview_timer = 0.18

func show_menu_preview() -> void:
	var level: Dictionary = Campaign.LEVELS[menu_level]
	use_map(level.map)
	dress_pilots(0)
	show_menu_boss()

func show_menu_boss() -> void:
	# The previewed boss stays red until it has been beaten once.
	var boss: int = Campaign.LEVELS[menu_level].boss
	arena.set_skin(1, boss, not skins.is_unlocked(boss))

func sync_boss_skins() -> void:
	# Levels won before boss skins existed still award their skins.
	var changed = false
	for index in campaign.completed:
		changed = skins.defeat(Campaign.LEVELS[index].boss) or changed
	if changed:
		save_skins()
		hud.sync_skins(skins)

func use_map(layout: Dictionary) -> void:
	# Swap the rules layout and rebuild the stadium only when the map really changes.
	if rules.map.get("id", "") != layout.get("id", ""):
		rules.set_map(layout)
	if arena.map.get("id", "") == layout.get("id", ""):
		return
	var old = arena
	remove_child(old)
	old.queue_free()
	arena = ArenaView.new()
	add_child(arena)
	arena.build(layout)
	video.apply(get_viewport(), arena)
	arena.guide_enabled = game_settings.aim_guide
	hud.arena_view = arena
	hud.team_skins = arena.unit_skins
	hud.team_tints = arena.unit_tints
	hud.arena_aspect = arena.view_aspect()
	hud.layout()

func finish_level() -> void:
	var won = rules.winner == local_team
	var opened = false
	var boss: int = Campaign.LEVELS[level_index].boss
	hud.level_skin = ""
	if won:
		opened = campaign.complete(level_index)
		if campaign.save_preferences() != OK:
			push_warning("Could not save campaign progress to " + campaign.config_path)
		if skins.defeat(boss):
			save_skins()
			hud.sync_skins(skins)
			hud.level_skin = Skins.CATALOG[boss].name
			hud.announce_unlock([hud.level_skin])
		# Beaten, the boss drops the red and shows its own colours.
		arena.set_skin(1, boss, false)
	hud.level_result = "won" if won else "lost"
	hud.level_opened = opened
	hud.sync_campaign(campaign)

func show_levels() -> void:
	return_to_menu()
	hud.open_levels()

func close_network() -> void:
	mouse_firing = false
	connected = false
	remote_id = 0
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	remote_command = {"move": Vector2.ZERO, "fire": false}
	remote_age = 0
	packets_received = 0
	client_boosted_ids.clear()

func return_to_menu(message: String = "") -> void:
	pve_paused = false
	close_network()
	mode = "menu"
	network_status = ""
	menu_preview_timer = -1.0
	leave_campaign(Campaign.LEVELS[menu_level].map)
	rules.reset_match()
	save_skins()
	dress_pilots(0)
	show_menu_boss()
	hud.sync_skins(skins)
	hud.show_menu(message)
	music.play("menu")

func request_menu() -> void:
	if mode == "pve":
		pause_pve()
	else:
		return_to_menu()

func pause_pve() -> void:
	if mode != "pve" or not is_instance_valid(hud):
		return
	pve_paused = true
	mouse_firing = false
	hud.show_pause(true)

func resume_pve() -> void:
	if mode != "pve":
		return
	hud.show_pause(false)
	mouse_firing = false
	pve_paused = false
	arena.capture_motion(rules)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		pause_pve()
		save_skins()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_skins()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		request_menu()

func host_game() -> void:
	close_network()
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, 1)
	if error != OK:
		hud.show_menu("Não foi possível criar a sala. A porta pode estar ocupada.")
		return
	multiplayer.multiplayer_peer = peer
	mode = "host"
	local_team = 0
	leave_campaign()
	rules.reset_match()
	dress_pilots(local_team)
	network_status = "À espera do rival…"
	hud.show_game(mode, local_team)
	music.play_skin(skins.selected)
	var addresses: PackedStringArray = []
	for address in IP.get_local_addresses():
		if ":" not in address and not address.begins_with("127.") and not address.begins_with("169.254."):
			addresses.append(address)
	hud.menu_status.text = "IP desta sala: " + ", ".join(addresses)
	# Host address stays visible while waiting, in the status panel.
	if addresses.size() > 0:
		network_status = "IP: " + addresses[0]
	print("HOST_READY port=", PORT)

func join_game(address: String) -> void:
	if address.is_empty():
		hud.show_menu("Escreve o IP do telemóvel ou PC que criou a partida.")
		return
	close_network()
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, PORT)
	if error != OK:
		hud.show_menu("Não foi possível iniciar a ligação a esse IP.")
		return
	multiplayer.multiplayer_peer = peer
	mode = "client"
	local_team = 1
	connection_timer = 10.0
	network_status = "A ligar ao rival…"
	leave_campaign()
	rules.reset_match()
	dress_pilots(local_team)
	hud.show_game(mode, local_team)
	music.play_skin(skins.selected)

func peer_connected(id: int) -> void:
	if mode == "host":
		remote_id = id
		connected = true
		network_status = ""
		rules.reset_match()
		share_skin.rpc_id(id, skins.selected)
		print("HOST_PEER_CONNECTED ", id)

func joined_server() -> void:
	if mode == "client":
		connected = true
		network_status = ""
		share_skin.rpc_id(1, skins.selected)
		print("CLIENT_CONNECTED")

func peer_disconnected(_id: int) -> void:
	if mode == "host" or mode == "client":
		return_to_menu.call_deferred("O outro jogador desligou-se. Podes criar uma nova partida.")

func replay() -> void:
	if mode == "pve" and level_index >= 0:
		start_level(level_index)
		return
	if mode == "pve" or mode == "host":
		rules.reset_match()
		hud.reset_touch()
		mouse_firing = false

func _input(event: InputEvent) -> void:
	# Release even if the pointer ends over a UI button.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		mouse_firing = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Touch is emulated into mouse clicks so the menu buttons work on a phone.
		# The HUD already reads the real touches, so ignore the emulated copies.
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		mouse_firing = event.pressed and mode != "menu"

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and event is InputEventKey and mode == "menu" and not hud.menu_overlay_open():
		if event.keycode == KEY_LEFT or event.keycode == KEY_RIGHT:
			step_menu_level(-1 if event.keycode == KEY_LEFT else 1)
			return
	if event.is_pressed() and event is InputEventKey and event.keycode == KEY_ESCAPE:
		if hud.video_overlay.visible:
			hud.close_video()
		elif hud.skins_overlay.visible:
			hud.close_skins()
		elif hud.levels_overlay.visible:
			hud.close_levels()
		elif hud.pvp_overlay.visible:
			hud.close_pvp()
		elif pve_paused:
			resume_pve()
		else:
			request_menu()

func dress_pilots(team: int) -> void:
	# The local pilot wears the chosen skin; the rival stays default until PvP shares theirs.
	arena.set_skin(team, skins.selected)
	arena.set_skin(1 - team, 0)

func select_skin(index: int) -> void:
	if not skins.select(index):
		return
	save_skins()
	hud.sync_skins(skins)
	if mode == "menu":
		arena.set_skin(0, index)

func save_skins() -> void:
	if skins.save_preferences() != OK:
		push_warning("Could not save skin progress to " + skins.config_path)

@rpc("any_peer", "call_remote", "reliable")
func share_skin(skin: int) -> void:
	if mode != "host" and mode != "client":
		return
	if mode == "host" and multiplayer.get_remote_sender_id() != remote_id:
		return
	if skin < 0 or skin >= Skins.CATALOG.size():
		return
	arena.set_skin(1 - local_team, skin)

func fit_content_scale() -> void:
	# Keep 720 HUD units on the short side, whichever way the screen is held.
	var window = get_window()
	window.content_scale_size = Vector2i(720, 1280) if window.size.y > window.size.x else Vector2i(1280, 720)

func frame_arena() -> void:
	if hud.vertical:
		arena.frame_rect(hud.arena_rect, hud.size)
	else:
		arena.frame_landscape(-4.5 if hud.mode == "menu" else 0.0)

func change_difficulty(level: int) -> void:
	game_settings.configure(level, game_settings.aim_guide)
	rules.ai_level = game_settings.difficulty
	if level_index >= 0:
		rules.ai_profile = Campaign.ai_profile(level_index, game_settings.difficulty)
	save_game_settings()

func change_guide(on: bool) -> void:
	game_settings.configure(game_settings.difficulty, on)
	arena.guide_enabled = on
	save_game_settings()

func change_sensitivity(level: int) -> void:
	game_settings.configure(game_settings.difficulty, game_settings.aim_guide, level)
	save_game_settings()

func save_game_settings() -> void:
	if game_settings.save_preferences() != OK:
		hud.video_note.text = "Aplicado nesta sessão. Não foi possível guardar as opções."
	hud.sync_game(game_settings)

func change_audio(on: bool, volume: float) -> void:
	music.configure(on, volume)
	var error = music.save_preferences()
	hud.sync_audio(music)
	if error != OK:
		hud.video_note.text = "Aplicado nesta sessão. Não foi possível guardar as opções."

func change_video(fps: int, quality: int, sync: bool, counter: bool) -> void:
	video.configure(fps, quality, sync, counter)
	video.apply(get_viewport(), arena)
	var error = video.save_preferences()
	hud.sync_video(video)
	if error != OK:
		hud.video_note.text = "Aplicado nesta sessão. Não foi possível guardar as opções."

func local_command() -> Dictionary:
	if hud.video_overlay.visible or pve_paused:
		return {"move": Vector2.ZERO, "fire": false}
	# Gentle response curve: small thumb movements aim finely, full deflection still runs.
	var stick: float = hud.move_vector.x
	var response = signf(stick) * pow(absf(stick), 1.7) * game_settings.sensitivity_scale()
	var move = Vector2(response, 0)
	if DisplayServer.get_name() != "headless":
		move += Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	return {"move": Vector2(clampf(move.x, -1, 1), 0), "fire": hud.touch_fire or mouse_firing}

func _physics_process(dt: float) -> void:
	if mode == "menu":
		return
	if mode == "pve" and (hud.video_overlay.visible or pve_paused):
		return
	if mode == "client" and not connected:
		connection_timer -= dt
		if connection_timer <= 0:
			return_to_menu("A ligação demorou demasiado. Confirma o IP e a rede Wi-Fi.")
		return
	if mode == "host" and not connected:
		return
	var command = local_command()
	if mode == "client":
		network_tick += dt
		if network_tick >= 1.0 / 30:
			network_tick = 0
			submit_input.rpc_id(1, command.move, command.fire)
		return
	var other: Dictionary
	if mode == "pve":
		other = rules.ai_command() if not pause_ai else {"move": Vector2.ZERO, "fire": false}
	else:
		remote_age += dt
		other = remote_command if remote_age < 0.35 else {"move": Vector2.ZERO, "fire": false}
	arena.capture_motion(rules)
	rules.step(dt, [command, other])
	for event in rules.events:
		if event.kind == "shot" and event.team == local_team:
			play_tone("shot_%d" % arena.unit_skins[local_team])
		elif event.kind == "boost":
			play_tone("boost")
		elif event.kind == "bounce":
			play_tone("bounce")
	if mode == "host":
		network_tick += dt
		if network_tick >= 1.0 / 20:
			network_tick = 0
			# Already-packed numeric arrays avoid a synchronous DEFLATE spike every 50 ms.
			receive_state.rpc_id(remote_id, rules.network_snapshot())

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func submit_input(move: Vector2, firing: bool) -> void:
	if mode != "host" or multiplayer.get_remote_sender_id() != remote_id:
		return
	if not move.is_finite():
		return
	remote_command = {"move": Vector2(clampf(move.x, -1, 1), 0), "fire": firing}
	remote_age = 0
	packets_received += 1

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func receive_state(data: Dictionary) -> void:
	if mode != "client":
		return
	arena.capture_motion(rules)
	if not rules.apply_network_snapshot(data):
		return
	visual_packet_age = 0.0
	packets_received += 1

func _process(dt: float) -> void:
	if mode == "menu" and menu_preview_timer >= 0:
		menu_preview_timer -= dt
		if menu_preview_timer < 0:
			show_menu_preview()
	if not is_instance_valid(arena) or rules.players.size() != 2:
		return
	if mode == "pve" and (pve_paused or hud.video_overlay.visible):
		return
	visual_packet_age += dt
	var alpha = clampf(visual_packet_age * 20.0, 0, 1) if mode == "client" else Engine.get_physics_interpolation_fraction()
	if mode == "menu" or (mode == "pve" and hud.video_overlay.visible):
		alpha = 1.0
	arena.update_state(rules, local_team, dt, alpha)
	music.follow_phase("" if mode == "menu" or network_status != "" else rules.phase)
	hud_timer += dt
	if hud_timer >= 1.0 / 30.0:
		hud_timer = 0
		hud.update_match(rules, network_status)
	fps_timer += dt
	if fps_timer >= 0.5:
		fps_timer = 0
		var measured = Engine.get_frames_per_second()
		if mode != "menu" and video.adapt(get_viewport(), measured):
			hud.video_note.text = "Ajuste automático ativo: resolução 3D %d%%, limite %d FPS." % [roundi(video.runtime_scale * 100), video.runtime_fps]
		hud.fps_label.text = "%d FPS  /  alvo %d" % [measured, video.runtime_fps]
	if rules.phase != last_phase:
		if rules.phase == "finished" and mode == "pve" and level_index >= 0:
			finish_level()
		if rules.phase == "goal" or rules.phase == "finished":
			play_tone("goal")
			save_skins()
		last_phase = rules.phase
	for i in range(2):
		if rules.players[i].stun > 0 and last_stuns[i] <= 0:
			play_tone("stun")
		last_stuns[i] = rules.players[i].stun
	if mode == "client":
		var present: Dictionary = {}
		for ball in rules.balls:
			present[ball.id] = true
			if ball.get("boosted", false) and not client_boosted_ids.has(ball.id):
				play_tone("boost")
				client_boosted_ids[ball.id] = true
		for id in client_boosted_ids.keys():
			if not present.has(id):
				client_boosted_ids.erase(id)

func build_audio() -> void:
	# A pool lets weapon tails, ricochets and impacts overlap instead of every
	# new effect cutting the sound already playing.
	for i in range(10):
		var voice = AudioStreamPlayer.new()
		voice.volume_db = -16
		add_child(voice)
		audio_voices.append(voice)
	audio = audio_voices[0]
	for skin in range(Skins.CATALOG.size()):
		tones["shot_%d" % skin] = load(Skins.SHOT_SOUND % skin)
	for sound in [["bounce", 1150, 0.07], ["stun", 150, 0.24], ["goal", 520, 0.45]]:
		var wave = AudioStreamWAV.new()
		wave.format = AudioStreamWAV.FORMAT_16_BITS
		wave.mix_rate = 22050
		var bytes = PackedByteArray()
		var count = int(22050 * sound[2])
		bytes.resize(count * 2)
		for i in range(count):
			var t = float(i) / 22050
			var envelope = (1.0 - float(i) / count) * minf(t * 150, 1)
			var frequency = float(sound[1]) * (1.0 - float(i) / count * 0.35)
			bytes.encode_s16(i * 2, int(sin(t * TAU * frequency) * envelope * 18000))
		wave.data = bytes
		tones[sound[0]] = wave
	# Rising two-note charge cue, clearly different from the short ricochet tick.
	var boost_wave = AudioStreamWAV.new()
	boost_wave.format = AudioStreamWAV.FORMAT_16_BITS
	boost_wave.mix_rate = 22050
	var boost_count = int(22050 * 0.30)
	var boost_bytes = PackedByteArray()
	boost_bytes.resize(boost_count * 2)
	for i in range(boost_count):
		var t = float(i) / 22050.0
		var progress = float(i) / boost_count
		var frequency = lerpf(310.0, 930.0, progress * progress)
		var envelope = minf(t * 90.0, 1.0) * pow(1.0 - progress, 1.35)
		var shimmer = sin(t * TAU * frequency) + 0.38 * sin(t * TAU * frequency * 2.01)
		boost_bytes.encode_s16(i * 2, int(clampf(shimmer * envelope, -1.0, 1.0) * 19000))
	boost_wave.data = boost_bytes
	tones["boost"] = boost_wave

func play_tone(sound: String) -> void:
	if audio_voices.is_empty() or not tones.has(sound):
		return
	var voice: AudioStreamPlayer = null
	for candidate in audio_voices:
		if not candidate.playing:
			voice = candidate
			break
	if voice == null:
		voice = audio_voices[audio_cursor % audio_voices.size()]
		audio_cursor += 1
	voice.stream = tones[sound]
	voice.play()

func capture_preview(path: String) -> void:
	await get_tree().create_timer(4.2).timeout
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	var error = img.save_png(path)
	print("CAPTURE_RESULT ", error, " ", path)
	get_tree().quit(error)
