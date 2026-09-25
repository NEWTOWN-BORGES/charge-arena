extends Node3D
const Rules = preload("res://scripts/arena_rules.gd")
const ArenaView = preload("res://scripts/indie_arena_view.gd")
const HUD = preload("res://scripts/game_hud.gd")
const VideoSettings = preload("res://scripts/video_settings.gd")
const Music = preload("res://scripts/music_player.gd")
const Skins = preload("res://scripts/skins.gd")
const PowerShop = preload("res://scripts/powers.gd")
const GameSettings = preload("res://scripts/game_settings.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Cup = preload("res://scripts/cup.gd")
const CupScreen = preload("res://scripts/story_hub.gd")
var cup = Cup.new()
var cup_screen
var cup_active = false
var cup_resolved = false
var skin_music_return = ""
const PORT = 27940
var rules = Rules.new()
var arena
var hud
var mode = "menu"
var local_team = 0
var connected = false
var remote_id = 0
var remote_command = {"move": Vector2.ZERO, "fire": false}
# Powers arrive on their own reliable channel, so a tap is never lost in the input stream.
var remote_power = -1
# One shot per click. A click made while the gun is still reloading is kept for a moment and
# goes as soon as it can, so a quick tapper never loses one; holding the finger down does not
# keep firing. Per team: the host keeps the guest's clicks the same way it keeps its own.
const FIRE_BUFFER_MS = 900
const MAX_QUEUED_SHOTS = 2
var queued_shots: Array = [0, 0]
var queued_until: Array = [0, 0]
var pending_clicks = 0
var pending_events: Array = []
var remote_power_until = 0
var remote_age = 0.0
var network_tick = 0.0
var connection_timer = 0.0
var network_status = ""
var pause_ai = false
var tones: Dictionary = {}
var audio: AudioStreamPlayer
var audio_voices: Array = []
var audio_cursor = 0
var sound_times: Dictionary = {}
var shot_variants = [0, 1]
var impact_variant = 0
var haptic_next_ms = 0
var haptic_strength = 0.0
var sustained_haptic = false
var sustained_next_ms = 0
var haptic_pulse_until = 0
var arena_duck_db = 0.0
var release_focus = 0.0
var break_times = [-10.0, -10.0]
var last_phase = ""
var last_stuns: Array = [0.0, 0.0]
var packets_received = 0
var mouse_firing = false
var fps_measuring = false
# Stereo position of the event being played, set while play_events walks the list.
var event_pan = 0.0
const CombatAudio = preload("res://scripts/combat_audio.gd")
var video = VideoSettings.new()
var music
var visual_packet_age = 0.0
var hud_timer = 0.0
var fps_timer = 0.0
var pve_paused = false
var skins = Skins.new()
var power_shop = PowerShop.new()
# Bricks already paid into the shop wallet this match.
var credited_bricks = 0
# The angle the pilot is walking to, chosen by tapping the stadium or stepping with the
# arrows. INF means "stay where you are".
const MAGNET_ANGLE = 0.05
# The stick: anything under the dead zone is a resting thumb, and anything over it moves
# the pilot at once, never below STICK_FLOOR of its speed.
const POWER_HOLD_MS = 500
var held_power = -1
var held_power_until = 0
const STICK_DEADZONE = 0.08
const STICK_FLOOR = 0.34
var game_settings = GameSettings.new()
var campaign = Campaign.new()
# Campaign level being played, or -1 for quick play, PvP and the menu.
var level_index = -1
# Level shown in the menu carousel, and the delay before its arena is rebuilt.
var menu_level = 0
var menu_preview_timer = -1.0
var client_boosted_ids: Dictionary = {}
# Last seen position of each explosive round, to replay the blast the host resolved.
var client_blast_spots: Dictionary = {}

func configure_test_access(enabled: bool) -> void:
	# Access flags, not fake victories. Enabled only by the isolated LAB export.
	if not enabled:
		return
	skins.unlock_all = true
	skins.selected = 5
	power_shop.unlock_all = true
	power_shop.owned = PowerShop.all_ids()
	power_shop.bricks = PowerShop.TEST_WALLET
	campaign.unlock_all = true

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
	hud.pvp_ai_requested.connect(start_pvp_ai)
	hud.menu_requested.connect(request_menu)
	hud.resume_requested.connect(resume_pve)
	hud.quit_requested.connect(return_to_menu)
	hud.replay_requested.connect(replay)
	hud.video_changed.connect(change_video)
	hud.video_opened.connect(func(): mouse_firing = false)
	hud.audio_changed.connect(change_audio)
	video.load_preferences()
	video.apply(get_viewport(), arena)
	hud.smooth = video.smooth_hud
	hud.queue_redraw()
	hud.sync_video(video)
	music = Music.new()
	add_child(music)
	music.load_preferences()
	hud.sync_audio(music)
	music.play("menu")
	configure_test_access(OS.has_feature("open_test"))
	skins.load_preferences()
	power_shop.load_preferences()
	hud.sync_powers(power_shop)
	hud.power_bought.connect(buy_power)
	hud.power_equipped.connect(equip_power)
	hud.team_skins = arena.unit_skins
	hud.team_tints = arena.unit_tints
	hud.arena_view = arena
	hud.skin_selected.connect(select_skin)
	hud.skin_previewed.connect(preview_skin_music)
	hud.skin_preview_closed.connect(restore_skin_music)
	hud.cup_requested.connect(open_cup)
	hud.sync_skins(skins)
	dress_pilots(0)
	game_settings.load_preferences()
	rules.ai_level = game_settings.difficulty
	arena.guide_enabled = game_settings.aim_guide
	arena.shake_scale = [0.0, 0.45, 1.0][game_settings.camera_feedback]
	rules.assist_team = local_team if game_settings.aim_assist else -1
	hud.sync_game(game_settings)
	hud.difficulty_changed.connect(change_difficulty)
	hud.guide_changed.connect(change_guide)
	hud.sensitivity_changed.connect(change_sensitivity)
	hud.feedback_changed.connect(change_feedback)
	hud.fire_layout_changed.connect(change_fire_layout)
	campaign.load_preferences()
	sync_boss_skins()
	hud.sync_campaign(campaign)
	hud.level_selected.connect(start_level)
	hud.next_level_requested.connect(func(): start_level(Campaign.menu_level(level_index + 1)))
	hud.levels_requested.connect(show_levels)
	hud.menu_level_changed.connect(step_menu_level)
	menu_level = Campaign.menu_level(campaign.suggested_level())
	hud.sync_menu_level(menu_level)
	show_menu_preview()
	hud.show_menu()
	get_window().focus_exited.connect(func(): hud.reset_touch(); mouse_firing = false)
	get_window().focus_exited.connect(pause_pve)
	get_window().focus_exited.connect(stop_haptics)
	multiplayer.peer_connected.connect(peer_connected)
	multiplayer.peer_disconnected.connect(peer_disconnected)
	multiplayer.connected_to_server.connect(joined_server)
	multiplayer.connection_failed.connect(func(): return_to_menu.call_deferred("Não foi possível ligar. Confirma o IP e a rede."))
	multiplayer.server_disconnected.connect(func(): return_to_menu.call_deferred("O anfitrião saiu da partida."))
	build_audio()
	cup.restore()
	# Reconcile earned rewards when upgrading an older tournament save.
	for reward in cup.defeated_bosses():
		skins.defeat(reward)
	if cup.wins == Cup.FULL_MATCHES:
		skins.defeat(11)
	save_skins()
	sync_story()
	show_menu_preview()
	cup_screen = CupScreen.new()
	cup_screen.cup = cup
	cup_screen.player_skin_provider = func(): return skins.selected
	hud.add_child(cup_screen)
	hud.move_child(cup_screen, hud.menu.get_index() + 1)
	cup_screen.action.connect(cup_action)
	cup_screen.refresh()
	cup_screen.hide()
	var scroll_gestures = preload("res://scripts/ui_scroll.gd").new()
	scroll_gestures.name = "ScrollGestures"
	scroll_gestures.surface = func():
		for overlay in [hud.pause_overlay, hud.video_overlay, hud.powers_overlay, hud.skins_overlay, hud.levels_overlay, hud.pvp_overlay]:
			if overlay.visible: return overlay
		return cup_screen if cup_screen.visible else hud.menu
	hud.add_child(scroll_gestures)
	arena.show()
	for arg in OS.get_cmdline_user_args():
		if arg == "--pve":
			start_pve()
		if arg == "--pvp-ai" or arg == "--colosseum":
			start_pvp_ai()
		if arg.begins_with("--capture="):
			capture_preview(arg.trim_prefix("--capture="))

func use_loadouts(boss_kit: Array, boss_skin: int = 0, rival_ultimate: String = "") -> void:
	# Two bought powers plus the ultimate that comes with each pilot's skin. The local
	# pilot is not always team 0 — in PvP the guest plays team 1 — so the kits are placed
	# by side. Built the other way round, the guest walked in with the host's ultimate in
	# its keys and none of its own.
	var mine: Array = power_shop.loadout(String(Skins.CATALOG[skins.selected].ultimate))
	# A station pilot has no skin to bring one, so its level names the ultimate instead.
	var theirs: Array = boss_kit + [rival_ultimate if rival_ultimate != "" else String(Skins.CATALOG[boss_skin].ultimate)]
	rules.loadouts = [mine, theirs] if local_team == 0 else [theirs, mine]
	credited_bricks = 0
	if PowerShop.START_WITH_ULTIMATE_FOR_TESTS:
		# Testing build: both sides walk in with the ultimate ready.
		charge_ultimates.call_deferred()

func charge_ultimates() -> void:
	for team in range(rules.powers.size()):
		var cost = rules.power_charge_cost(team, 2)
		if cost > 0:
			rules.powers[team].charge[2] = cost

func start_pve(layout: Dictionary = {}) -> void:
	close_cup_screen()
	# Quick play opens on the tall arena, which fills a phone held upright instead of
	# sitting in a band across the middle of it. Campaign levels bring their own.
	if layout.is_empty():
		layout = Rules.tower_map()
	pve_paused = false
	close_network()
	mode = "pve"
	local_team = 0
	network_status = ""
	leave_campaign(layout)
	use_loadouts(["blast", "rapid"])
	rules.reset_match()
	dress_pilots(local_team)
	hud.show_game(mode, local_team)
	sync_assist()
	music.play_skin(skins.selected)

func start_pvp_ai() -> void:
	start_pve(Rules.pvp_map())

func start_level(index: int) -> void:
	close_cup_screen()
	if not campaign.is_unlocked(index):
		return
	var level: Dictionary = Campaign.LEVELS[index]
	pve_paused = false
	close_network()
	mode = "pve"
	local_team = 0
	network_status = ""
	level_index = index
	menu_level = Campaign.menu_level(index)
	hud.sync_menu_level(index)
	use_map(level.map)
	rules.ai_profile = Campaign.ai_profile(index, game_settings.difficulty)
	use_loadouts(Campaign.boss_kit(index), level.boss, Campaign.level_ultimate(index))
	rules.reset_match()
	dress_pilots(local_team)
	# The boss wears its own skin and its own bricks, in the colours they were drawn in. A
	# station pilot has none: it flies the standard hull in the rival's colour, which is how
	# you know at a glance that there is no skin to win here.
	arena.set_skin(1, level.boss, Campaign.is_minor(index), Campaign.level_hue(index))
	hud.team_hues = arena.unit_hues
	var rival_name: String = String(level.name).to_upper() if Campaign.is_minor(index) else String(Skins.CATALOG[level.boss].name)
	hud.level_info = {"number": Campaign.menu_levels().find(Campaign.menu_level(index)) + 1, "name": level.name, "challenge": level.challenge, "boss_name": rival_name, "has_next": index + 1 < Campaign.LEVELS.size()}
	hud.level_result = ""
	hud.level_skin = ""
	hud.show_game(mode, local_team)
	sync_assist()
	# The theme follows whoever is on the other side, station pilot or boss, so ten matches
	# in a row do not share one tune. A station hull is numbered past the catalogue, so the
	# level names its theme instead - left to the hull number they all fell through to the
	# last track in the list, which is the final boss's.
	if Campaign.is_minor(index):
		music.play_bot(Campaign.level_music(index))
	else:
		music.play_skin(Campaign.level_music(index))

func leave_campaign(layout: Dictionary = {}) -> void:
	level_index = -1
	rules.ai_profile = {}
	hud.level_info = {}
	hud.level_result = ""
	hud.level_skin = ""
	use_map(layout if not layout.is_empty() else Rules.default_map())

func step_menu_level(step: int) -> void:
	var visible = Campaign.menu_levels()
	var chosen: int = visible[clampi(visible.find(menu_level) + step, 0, visible.size() - 1)]
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
	# The previewed rival is shown in its own colours, like it fights: a boss in its skin's
	# palette, a station pilot in the colour its level gives it.
	var boss: int = Campaign.LEVELS[menu_level].boss
	arena.set_skin(1, boss, Campaign.is_minor(menu_level), Campaign.level_hue(menu_level))
	hud.team_hues = arena.unit_hues

func sync_boss_skins() -> void:
	# Levels won before boss skins existed still award their skins.
	var changed = false
	for index in campaign.completed:
		# A station pilot has no skin to award: its hull is numbered past the catalogue.
		if Campaign.is_minor(index):
			continue
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
	hud.smooth = video.smooth_hud
	hud.queue_redraw()
	arena.guide_enabled = game_settings.aim_guide
	arena.shake_scale = [0.0, 0.45, 1.0][game_settings.camera_feedback]
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
		# Nothing to win from a station pilot but the way through.
		if not Campaign.is_minor(level_index) and skins.defeat(boss):
			save_skins()
			hud.sync_skins(skins)
			hud.level_skin = Skins.CATALOG[boss].name
			hud.announce_unlock([hud.level_skin])
		if not Campaign.is_minor(level_index):
			arena.set_skin(1, boss, false)
	hud.level_result = "won" if won else "lost"
	hud.level_opened = opened
	hud.sync_campaign(campaign)

func show_levels() -> void:
	return_to_menu()
	hud.open_levels()

func close_network() -> void:
	clear_shots()
	mouse_firing = false
	connected = false
	remote_id = 0
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	remote_command = {"move": Vector2.ZERO, "fire": false}
	remote_power = -1
	remote_age = 0
	packets_received = 0
	client_boosted_ids.clear()
	client_blast_spots.clear()

func return_to_menu(message: String = "") -> void:
	if hud.skins_overlay.visible:
		hud.close_skins()
	cup_active = false
	pve_paused = false
	close_network()
	mode = "menu"
	network_status = ""
	menu_preview_timer = -1.0
	leave_campaign(Campaign.LEVELS[menu_level].map)
	rules.reset_match()
	save_skins()
	save_powers()
	dress_pilots(0)
	show_menu_boss()
	hud.sync_skins(skins)
	hud.show_menu(message)
	music.play("menu")
	if is_instance_valid(cup_screen):
		cup_screen.hide()
		arena.show()

func request_menu() -> void:
	if mode == "pve":
		pause_pve()
	else:
		return_to_menu()

func pause_pve() -> void:
	stop_haptics()
	if mode != "pve" or not is_instance_valid(hud):
		return
	pve_paused = true
	mouse_firing = false
	clear_shots()
	hud.show_pause(true)

func resume_pve() -> void:
	if mode != "pve":
		return
	hud.show_pause(false)
	mouse_firing = false
	clear_shots()
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
	close_cup_screen()
	close_network()
	mode = "host"
	local_team = 0
	leave_campaign(Rules.pvp_map())
	use_loadouts(PowerShop.STARTER_KIT.duplicate())
	rules.reset_match()
	dress_pilots(local_team)
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, 1)
	if error != OK:
		hud.show_menu("Não foi possível criar a sala. A porta pode estar ocupada.")
		return
	multiplayer.multiplayer_peer = peer
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
	close_cup_screen()
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
	leave_campaign(Rules.pvp_map())
	use_loadouts(PowerShop.STARTER_KIT.duplicate())
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
		if PowerShop.START_WITH_ULTIMATE_FOR_TESTS:
			# The match restarts when the guest arrives, and that wipes the charge the
			# testing build hands out: without this, PvP begins with dead ultimate keys.
			charge_ultimates()
		share_skin.rpc_id(id, skins.selected)
		share_kit.rpc_id(id, String(power_shop.kit[0]), String(power_shop.kit[1]))
		print("HOST_PEER_CONNECTED ", id)

func joined_server() -> void:
	if mode == "client":
		connected = true
		network_status = ""
		share_skin.rpc_id(1, skins.selected)
		share_kit.rpc_id(1, String(power_shop.kit[0]), String(power_shop.kit[1]))
		print("CLIENT_CONNECTED")

func peer_disconnected(_id: int) -> void:
	if mode == "host" or mode == "client":
		return_to_menu.call_deferred("O outro jogador desligou-se. Podes criar uma nova partida.")

func replay() -> void:
	if cup_active:
		start_cup()
		return
	if mode == "pve" and level_index >= 0:
		start_level(level_index)
		return
	if mode == "pve" or mode == "host":
		rules.reset_match()
		hud.reset_touch()
		mouse_firing = false
		clear_shots()

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
		if mouse_firing:
			pending_clicks += 1

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and event is InputEventKey and mode == "menu" and not hud.menu_overlay_open():
		if event.keycode == KEY_LEFT or event.keycode == KEY_RIGHT:
			step_menu_level(-1 if event.keycode == KEY_LEFT else 1)
			return
	if event.is_pressed() and not event.is_echo() and event is InputEventKey and mode != "menu":
		if event.keycode == KEY_SPACE:
			pending_clicks += 1
			return
		# On a PC the three powers are on the number keys; phones use the HUD buttons.
		var slot = [KEY_1, KEY_2, KEY_3].find(event.keycode)
		if slot < 0:
			slot = [KEY_KP_1, KEY_KP_2, KEY_KP_3].find(event.keycode)
		if slot >= 0:
			hud.request_power(slot)
			return
	if event.is_pressed() and event is InputEventKey and event.keycode == KEY_ESCAPE:
		if hud.video_overlay.visible:
			hud.close_video()
		elif hud.skins_overlay.visible:
			hud.close_skins()
		elif hud.levels_overlay.visible:
			hud.close_levels()
		elif hud.powers_overlay.visible:
			hud.close_powers()
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

func bank_bricks() -> void:
	# Bricks destroyed in any mode are the shop currency; they are banked as they fall.
	var earned: int = int(rules.powers[local_team].destroyed) - credited_bricks
	if earned <= 0:
		return
	credited_bricks += earned
	power_shop.add_bricks(earned)
	hud.sync_powers(power_shop)

func save_powers() -> void:
	if power_shop.save_preferences() != OK:
		push_warning("Could not save power progress to " + power_shop.config_path)

func buy_power(id: String) -> void:
	if not power_shop.buy(id):
		return
	hud.announce_power(id, PowerShop.CATALOG[PowerShop.index_of(id)].name)
	save_powers()
	hud.sync_powers(power_shop)

func equip_power(slot: int, id: String) -> void:
	if not power_shop.equip(slot, id):
		return
	save_powers()
	hud.sync_powers(power_shop)

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
	# The rival's third key is the ultimate of the skin it just showed.
	var kit: Array = rules.loadouts[1 - local_team]
	rules.loadouts[1 - local_team] = [kit[0], kit[1], String(Skins.CATALOG[skin].ultimate)]

@rpc("any_peer", "call_remote", "reliable")
func share_kit(first: String, second: String) -> void:
	# The two bought powers the rival brought; the ultimate rides with the skin.
	if mode != "host" and mode != "client":
		return
	if mode == "host" and multiplayer.get_remote_sender_id() != remote_id:
		return
	var kit: Array = [first, second]
	for id in kit:
		if PowerShop.index_of(id) < 0:
			return
	rules.loadouts[1 - local_team] = kit + [rules.power_id(1 - local_team, 2)]

func fit_content_scale() -> void:
	# Keep 720 HUD units on the short side, whichever way the screen is held.
	var window = get_window()
	window.content_scale_size = Vector2i(720, 1280) if window.size.y > window.size.x else Vector2i(1280, 720)

func warm_up() -> void:
	# Compile what a match can draw while nothing is happening yet: in the lobby, and in
	# the countdown of every match, which is when a new arena has just been built.
	arena.warm_shaders()

func frame_arena() -> void:
	if hud.mode == "menu" and hud.lobby != null:
		# The lobby: the pilot, up close, where the lobby left room for it.
		arena.frame_lobby(hud.size, hud.lobby.focus, hud.lobby.pilot_height)
		return
	if hud.vertical:
		arena.frame_rect(hud.arena_rect, hud.size, hud.mode == "menu")
	else:
		arena.frame_landscape(-4.5 if hud.mode == "menu" else 0.0)

func change_difficulty(level: int) -> void:
	game_settings.configure(level, game_settings.aim_guide)
	rules.ai_level = game_settings.difficulty
	if level_index >= 0:
		rules.ai_profile = Campaign.ai_profile(level_index, game_settings.difficulty)
	if cup_active:
		rules.ai_profile = cup.profile(game_settings.difficulty)
	save_game_settings()

func sync_assist() -> void:
	# PvE and PvP alike: only the pilot on this device gets the magnetism.
	rules.assist_team = local_team if (game_settings.aim_assist and mode != "menu") else -1

func change_guide(on: bool) -> void:
	game_settings.configure(game_settings.difficulty, on)
	arena.guide_enabled = on
	save_game_settings()

func change_fire_layout(control: int, radius_scale: float, x: float, y: float) -> void:
	game_settings.fire_control = clampi(control, 0, 1)
	game_settings.fire_size = clampf(radius_scale, 0.7, 1.5)
	game_settings.fire_x = clampf(x, 0.0, 1.0)
	game_settings.fire_y = clampf(y, 0.0, 1.0)
	save_game_settings()

func change_feedback(camera: int, haptics: bool, automatic: bool, volume: float) -> void:
	game_settings.camera_feedback = camera
	game_settings.haptics = haptics
	if not haptics: stop_haptics()
	game_settings.auto_fire = automatic
	game_settings.sfx_volume = volume
	arena.shake_scale = [0.0, 0.45, 1.0][camera]
	if camera == 0: arena.shake_power = 0.0
	mouse_firing = false
	clear_shots()
	save_game_settings()

func haptic(milliseconds: int, strength: float) -> void:
	if not game_settings.haptics or mode == "menu" or not OS.has_feature("android"):
		return
	var now = Time.get_ticks_msec()
	if now < haptic_next_ms and strength <= haptic_strength: return
	haptic_next_ms = now + maxi(110, milliseconds + 55)
	haptic_strength = strength
	haptic_pulse_until = now + milliseconds
	sustained_next_ms = haptic_pulse_until + 15
	Input.vibrate_handheld(milliseconds, strength)

func stop_haptics() -> void:
	if OS.has_feature("android"): Input.vibrate_handheld(0)
	sustained_haptic = false
	sustained_next_ms = 0
	haptic_pulse_until = 0
	haptic_next_ms = 0

static func sustained_haptic_profile(state: Dictionary) -> Vector3:
	# x = pulse duration, y = refresh interval in ms, z = amplitude.
	# Beam pulses overlap for a continuous feel; other powers keep a distinct rhythm.
	if state.laser_time > 0.0: return Vector3(130, 95, 0.20)
	if state.ultimate_time > 0.0:
		match String(state.ultimate_id):
			"sun_ray": return Vector3(150, 105, 0.32)
			"singularity": return Vector3(65, 170, 0.25)
	if state.rapid_time > 0.0: return Vector3(12, 115, 0.17)
	if state.surge_time > 0.0: return Vector3(20, 190, 0.20)
	return Vector3.ZERO

func update_sustained_haptics() -> void:
	if not OS.has_feature("android"): return
	if not game_settings.haptics or mode == "menu" or pve_paused or hud.video_overlay.visible or not get_window().has_focus():
		if sustained_haptic or haptic_pulse_until > 0: stop_haptics()
		return
	var now = Time.get_ticks_msec()
	var profile = sustained_haptic_profile(rules.powers[local_team]) if rules.phase == "play" else Vector3.ZERO
	if profile == Vector3.ZERO:
		if sustained_haptic:
			# Do not cancel a stronger goal/impact pulse that replaced the beam.
			if now >= haptic_pulse_until: Input.vibrate_handheld(0)
			sustained_haptic = false
		return
	if now < sustained_next_ms or now < haptic_pulse_until: return
	Input.vibrate_handheld(int(profile.x), profile.z)
	sustained_haptic = true
	sustained_next_ms = now + int(profile.y)

func update_feedback_mix(dt: float) -> void:
	release_focus = maxf(0.0, release_focus - dt)
	var focus = release_focus > 0.0
	for state in rules.powers:
		if state.ultimate_windup > 0.0 and state.ultimate_windup < 0.18: focus = true
	arena_duck_db = move_toward(arena_duck_db, -4.5 if focus else 0.0, dt * (70.0 if focus else 24.0))
	var volume = linear_to_db(maxf(game_settings.sfx_volume, 0.0001))
	for voice in audio_voices:
		if voice.playing:
			voice.volume_db = float(voice.get_meta("mix_gain", -18.0)) + volume + (arena_duck_db if voice.get_meta("secondary", false) else 0.0)

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
	hud.smooth = video.smooth_hud
	hud.queue_redraw()
	var error = video.save_preferences()
	hud.sync_video(video)
	if error != OK:
		hud.video_note.text = "Aplicado nesta sessão. Não foi possível guardar as opções."

func play_events() -> void:
	# Sound and spectacle for whatever just happened. The host runs this off its own
	# simulation; the client runs it off the events the host ships with each snapshot,
	# which is the only way it sees a power go off at all.
	for event in rules.events:
		# Where it happened, left to right as this player sees the arena: the sound comes
		# from that side.
		var heard_at = event.get("p", null)
		event_pan = clampf(float(heard_at.x) / Rules.HALF_WIDTH, -1.0, 1.0) * (1.0 if local_team == 0 else -1.0) if heard_at is Vector2 else 0.0
		ArenaView.CombatFinish.event(arena, event, rules)
		if event.kind == "shot":
			var team = int(event.team)
			arena.shot_feedback(team)
			if team == local_team:
				arena.shake(0.016)
				haptic(8, 0.12)
				hud.fire_age = 0.0
			var skin = int(arena.unit_skins[team])
			# Intermediate opponents share the Aurora base, never a missing sample.
			if skin >= Skins.CATALOG.size(): skin = 0
			var variant = int(shot_variants[team]) % 3
			shot_variants[team] += 1
			play_tone("shot_%d_%d" % [skin, variant], 0.0 if team == local_team else -5.0)
		elif event.kind == "boost":
			play_tone("boost")
		elif event.kind in ["bounce", "spent"]:
			arena.impact_feedback(event)
			play_tone("metal" if event.get("surface", "") == "obstacle" else "ricochet")
		elif event.kind == "player_hit":
			arena.impact_feedback(event)
			play_tone("shield")
		elif event.kind == "power":
			# Both sides are announced: a power launched at you should never be silent.
			arena.power_flash(event.p, String(event.get("id", "")))
			var ability_cue = "ability_" + String(event.get("id", ""))
			play_tone(ability_cue if tones.has(ability_cue) else "power")
			arena.shake(0.22)
			if int(event.team) == local_team: haptic(22, 0.30)
		elif event.kind == "laser":
			arena.laser_beam(event.p, event.heading, event.team)
			play_tone("laser_tick", -2.0)
		elif event.kind == "rebuild":
			var back: Array = event.bricks.map(func(i): return rules.bricks[i].p)
			arena.rebuild_flash(back)
			for spot in back:
				arena.gain_mark(spot, int(event.get("gain", 0)), Rules.power_color("rebuild"))
		elif event.kind == "mirror":
			arena.impact_feedback(event)
			play_tone("shield")
		elif event.kind == "shock":
			arena.shock_pulse(event.p)
		elif event.kind == "ultimate_charge":
			# Two seconds of rising charge, heard by both sides.
			play_tone("charging")
		elif event.kind == "ultimate":
			release_focus = 0.14
			arena.ultimate_accent(event.p, String(event.get("id", "")))
			if int(event.team) == local_team:
				haptic(48 if String(event.get("id", "")) in ["meteors", "sun_ray", "singularity"] else 30, 0.55)
			play_tone("unleash")
			if tones.has(String(event.get("id", ""))):
				play_tone(String(event.id))
		elif event.kind == "sun_ray":
			# The beam is drawn from the gun; this is the discharge around it.
			arena.sun_ray(event.p, event.heading, event.width)
			play_tone("sun_ray")
		elif event.kind == "meteor":
			arena.meteor_fall(event.p, event.radius, randf() < 0.5)
			if int(event.team) == local_team: haptic(28, 0.38)
			# Fourteen rocks in a second would be a wall of noise: every other one sounds.
			if randf() < 0.5:
				play_tone("meteor")
		elif event.kind == "thunder":
			arena.thunder_bolt(event.p, event.radius)
			if int(event.team) == local_team: haptic(35, 0.55)
			play_tone("thunder")
		elif event.kind == "singularity":
			arena.singularity_open(event.p)
		elif event.kind == "singularity_wave":
			arena.singularity_wave(event.p, int(event.index), float(event.seconds))
			if int(event.team) == local_team: haptic(45, 0.50)
			play_tone("void_wave")
		elif event.kind == "swallow":
			arena.singularity_swallow(event.p)
		elif event.kind == "turret_shot":
			# Lighter than the pilot's gun, so a wall of sentry fire stays readable.
			play_tone("sentry")
		elif event.kind == "turret_hit":
			play_tone("power")
		elif event.kind == "turret_down":
			arena.sentry_down(event.p, int(event.team))
			play_tone("blast")
		elif event.kind == "bloom":
			arena.bloom_flash(event.bricks.map(func(i): return rules.bricks[i].p), event.heal)
		elif event.kind == "plunder":
			arena.plunder_flash(event.team)
		elif event.kind == "surge":
			arena.surge_flash(event.p)
			arena.gain_mark(event.p, int(event.get("gain", 0)), Rules.power_color("surge"))
			play_tone("boost")
		elif event.kind == "volley":
			arena.volley_flash(event.p, event.heading)
			if int(event.team) == local_team: haptic(18, 0.30)
			play_tone("power")
		elif event.kind == "weld":
			var mended: Array = event.bricks.map(func(i): return rules.bricks[i].p)
			arena.weld_flash(mended)
			for spot in mended:
				arena.gain_mark(spot, int(event.get("heal", 0)), Rules.power_color("weld"))
			play_tone("ability_weld")
		elif event.kind == "freeze":
			arena.frost_flash(event.p)
			play_tone("ability_freeze")
		elif event.kind == "magnet":
			arena.magnet_flash(event.p)
			play_tone("ability_magnet")
		elif event.kind == "thorns":
			arena.thorns_flash(int(event.team))
			play_tone("ability_thorns")
		elif event.kind == "thorns_bite":
			arena.burst(event.p, Rules.power_color("thorns"), false)
		elif event.kind == "plating":
			arena.plating_flash(event.team)
			arena.gain_mark(event.p, int(event.get("gain", 0)), Rules.power_color("plating"))
			play_tone("power")
		elif event.kind == "shock_wave":
			arena.shock_wave(event.p, event.get("marks", []), 1 - int(event.team))
			play_tone("void_burst")
		elif event.kind == "plunder_land":
			arena.plunder_land(event.team)
			play_tone("power")
		elif event.kind == "power_ready" and event.team == local_team:
			play_tone("ready")
		elif event.kind in ["brick", "brick_hit"]:
			arena.impact_feedback(event)
			impact_variant = (impact_variant + 1) % 3
			var cue = ("break_" if event.kind == "brick" else "hit_") + str(impact_variant)
			play_tone("shield" if event.get("soaked", false) else cue)
			if event.kind == "brick":
				var team = int(event.team)
				var repeated = rules.elapsed - float(break_times[team]) < 0.18
				break_times[team] = rules.elapsed
				arena.shake(0.13 if repeated else 0.075)
				if team != local_team: haptic(16, 0.24)
			if event.get("defense_open", false):
				play_tone("defense")
				arena.shake(0.19)
				haptic(25, 0.34)
				hud.defense_notice = "DEFESA ABERTA — ATACA A BALIZA!" if int(event.team) != local_team else "A TUA BALIZA ESTÁ DESPROTEGIDA!"
				hud.defense_notice_time = 1.25
			if int(event.get("bite", 0)) > 0:
				arena.damage_mark(int(event.team), event.p, int(event.bite))
		elif event.kind == "explosion":
			arena.explosion(event.p, event.radius)
			play_tone("blast")
	event_pan = 0.0

func local_command() -> Dictionary:
	if hud.video_overlay.visible or pve_paused:
		# Drop anything tapped while the match was on hold.
		hud.take_power()
		hud.fire_tap = false
		hud.fire_id = -1
		clear_shots()
		return {"move": Vector2.ZERO, "fire": false, "power": -1}
	# Past a small dead zone the pilot leaves at once: the first sliver of the push is
	# already worth a third of the speed, so nudging the stick never feels like nothing
	# happened. From there it climbs almost straight to a full run.
	var stick: float = hud.move_vector.x
	var response = 0.0
	if absf(stick) > STICK_DEADZONE:
		var push = (absf(stick) - STICK_DEADZONE) / (1.0 - STICK_DEADZONE)
		response = signf(stick) * lerpf(STICK_FLOOR, 1.0, pow(push, 1.2)) * game_settings.sensitivity_scale()
	else:
		# Thumb still: let the magnetism settle the pilot on the target it is beside.
		response = magnet_pull()
	var move = Vector2(response, 0)
	if DisplayServer.get_name() != "headless":
		var keys = Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
		move += keys
	# Manual fire: every click is one shot, whether it came from the button, the joystick,
	# the mouse or the space bar.
	if hud.fire_tap:
		pending_clicks += 1
	hud.fire_tap = false
	var clicks: int = 0 if game_settings.auto_fire else mini(pending_clicks, MAX_QUEUED_SHOTS)
	pending_clicks = 0
	var fire: bool = game_settings.auto_fire
	if mode != "client":
		for click in range(clicks):
			queue_shot(local_team)
		fire = fire or take_queued_shot(local_team)
	return {"move": Vector2(clampf(move.x, -1, 1), 0), "fire": fire, "tap": clicks > 0, "clicks": clicks, "power": read_power()}

func queue_shot(team: int) -> void:
	queued_shots[team] = mini(int(queued_shots[team]) + 1, MAX_QUEUED_SHOTS)
	queued_until[team] = Time.get_ticks_msec() + FIRE_BUFFER_MS

func take_queued_shot(team: int) -> bool:
	if int(queued_shots[team]) <= 0:
		return false
	if Time.get_ticks_msec() > int(queued_until[team]):
		queued_shots[team] = 0
		return false
	if not rules.can_fire(team, 1.0 / Engine.physics_ticks_per_second):
		return false
	queued_shots[team] = int(queued_shots[team]) - 1
	# A second click waiting behind this one gets its own moment from here.
	queued_until[team] = Time.get_ticks_msec() + FIRE_BUFFER_MS
	return true

func clear_shots() -> void:
	queued_shots = [0, 0]
	queued_until = [0, 0]
	pending_clicks = 0

func read_power() -> int:
	# A key pressed a moment too early — during the countdown, or while another power is
	# still running — used to be swallowed without a word. It is now held for half a
	# second and tried again, which is the difference between a power that feels broken
	# and one that simply waited its turn.
	var asked: int = hud.take_power()
	if asked >= 0:
		held_power = asked
		held_power_until = Time.get_ticks_msec() + POWER_HOLD_MS
	if held_power < 0:
		return -1
	if Time.get_ticks_msec() > held_power_until:
		held_power = -1
		return -1
	if not rules.can_activate_power(local_team, held_power):
		return -1
	var ready = held_power
	held_power = -1
	return ready

func magnet_pull() -> float:
	# With the thumb nearly still, the pilot eases onto the nearest firing angle instead
	# of hovering a hair beside it. It never fights a real push of the stick.
	if not game_settings.aim_assist or rules.players.size() <= local_team:
		return 0.0
	var player: Dictionary = rules.players[local_team]
	var best = INF
	var best_gap = MAGNET_ANGLE
	for option in rules.firing_angles(local_team):
		var gap: float = absf(option.angle - player.angle)
		if gap < best_gap:
			best_gap = gap
			best = option.angle
	if best == INF:
		return 0.0
	return clampf((best - player.angle) * 5.0, -0.35, 0.35)

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
		for click in range(int(command.get("clicks", 0))):
			submit_fire_tap.rpc_id(1)
		if command.power >= 0:
			submit_power.rpc_id(1, command.power)
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
		var stale = remote_age >= 0.35
		# The rival's key gets the same half second of patience the local one does: pressed
		# during the countdown, or while another power is running, it used to vanish on the
		# host without the guest ever knowing why.
		var remote_slot = -1
		if remote_power >= 0:
			if Time.get_ticks_msec() > remote_power_until:
				remote_power = -1
			elif rules.can_activate_power(1 - local_team, remote_power):
				remote_slot = remote_power
				remote_power = -1
		var remote_team: int = 1 - local_team
		other = {"move": Vector2.ZERO if stale else remote_command.move, "fire": (false if stale else remote_command.fire) or take_queued_shot(remote_team), "power": remote_slot}
	arena.capture_motion(rules)
	rules.step(dt, [command, other])
	bank_bricks()
	play_events()
	if mode == "host":
		# Events happen every tick but packets leave at 20 Hz, so they are kept until the
		# next one goes out. Capped, because a meteor shower must not inflate a packet.
		if pending_events.size() < 80:
			pending_events.append_array(rules.events)
		network_tick += dt
		if network_tick >= 1.0 / 20:
			network_tick = 0
			# Already-packed numeric arrays avoid a synchronous DEFLATE spike every 50 ms.
			var packet: Dictionary = rules.network_snapshot()
			packet["e"] = pending_events
			pending_events = []
			receive_state.rpc_id(remote_id, packet)

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func submit_input(move: Vector2, firing: bool) -> void:
	if mode != "host" or multiplayer.get_remote_sender_id() != remote_id:
		return
	if not move.is_finite():
		return
	remote_command = {"move": Vector2(clampf(move.x, -1, 1), 0), "fire": firing}
	remote_age = 0
	packets_received += 1

@rpc("any_peer", "call_remote", "reliable")
func submit_fire_tap() -> void:
	if mode == "host" and multiplayer.get_remote_sender_id() == remote_id:
		queue_shot(1 - local_team)

@rpc("any_peer", "call_remote", "reliable")
func submit_power(power: int) -> void:
	# Reliable and separate: a dropped movement packet must not swallow a power.
	if mode != "host" or multiplayer.get_remote_sender_id() != remote_id:
		return
	if power < 0 or power >= Rules.POWER_SLOTS:
		return
	remote_power = power
	remote_power_until = Time.get_ticks_msec() + POWER_HOLD_MS

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func receive_state(data: Dictionary) -> void:
	if mode != "client":
		return
	arena.capture_motion(rules)
	if not rules.apply_network_snapshot(data):
		return
	# The client does not simulate, so without these it never sees a shot, a power or an
	# ultimate happen: no flash, no sound, nothing.
	var carried = data.get("e", [])
	# Left in place until the next packet overwrites them: they are what the arena and the
	# HUD read to know what just happened.
	rules.events = carried if typeof(carried) == TYPE_ARRAY else []
	play_events()
	visual_packet_age = 0.0
	packets_received += 1

const IDLE_FPS = 30

func idle_frame_rate() -> void:
	# Outside a live match — menu, shop, skins, pause — the screen is nearly still, and
	# there is no reason to paint it 120 times a second. An hour of testing spends most of
	# its time on these screens, and on a 120 Hz phone that is most of the battery.
	var resting: bool = mode == "menu" or pve_paused or hud.video_overlay.visible or network_status != ""
	var wanted: int = IDLE_FPS if resting else video.runtime_fps
	if Engine.max_fps != wanted:
		Engine.max_fps = wanted

func _process(dt: float) -> void:
	update_sustained_haptics()
	update_feedback_mix(dt)
	idle_frame_rate()
	hud.fps_label.visible = video.show_fps and mode != "menu"
	if mode == "menu" and is_instance_valid(cup_screen) and cup_screen.visible:
		return
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
		# Only a match in play is a fair reading: the countdown, a goal, a pause or the menu
		# run at the resting rate on purpose, and used to be taken for a phone that could not
		# keep up - which is how a game set to 90 ended up stuck at 30.
		var measuring: bool = mode != "menu" and rules.phase == "play" and Engine.max_fps == video.runtime_fps
		if measuring and not fps_measuring:
			video.hold()
		fps_measuring = measuring
		if measuring and video.adapt(get_viewport(), measured):
			hud.video_note.text = "Ajuste automático ativo: resolução 3D %d%%, limite %d FPS." % [roundi(video.runtime_scale * 100), video.runtime_fps] if video.adjusted() else video.AUTO_NOTE
		if video.panel_cap > 0 and video.runtime_fps < video.fps:
			hud.fps_label.text = "%d FPS  /  alvo %d (ecrã a %d Hz)" % [measured, video.runtime_fps, video.panel_cap]
		elif video.runtime_fps < video.fps:
			hud.fps_label.text = "%d FPS  /  alvo %d (auto, escolhido %d)" % [measured, video.runtime_fps, video.fps]
		else:
			hud.fps_label.text = "%d FPS  /  alvo %d" % [measured, video.runtime_fps]
	if rules.phase == "finished" and cup_active and not cup_resolved:
		cup_resolved = true
		finish_cup.call_deferred()
	if rules.phase != last_phase:
		if rules.phase == "finished" and mode == "pve" and level_index >= 0:
			finish_level()
		if rules.phase == "goal" or rules.phase == "finished":
			play_tone("goal")
			arena.shake(1.05)
			haptic(65, 0.75)
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
			if int(ball.get("power", 0)) == 1:
				client_blast_spots[ball.id] = ball.p
		for id in client_boosted_ids.keys():
			if not present.has(id):
				client_boosted_ids.erase(id)
		for id in client_blast_spots.keys():
			if present.has(id):
				continue
			# The host already resolved this blast; replay it where the round was last seen.
			if rules.phase == "play":
				arena.explosion(client_blast_spots[id], Rules.EXPLOSION_RADIUS)
				play_tone("blast")
			client_blast_spots.erase(id)

func build_audio() -> void:
	# A pool lets weapon tails, ricochets and impacts overlap instead of every
	# new effect cutting the sound already playing.
	var combat_bus = preload("res://scripts/combat_audio.gd").prepare_bus()
	for i in range(28):
		var voice = AudioStreamPlayer.new()
		voice.bus = combat_bus
		voice.set_meta("weapon_voice", i < 12)
		voice.volume_db = -16
		add_child(voice)
		audio_voices.append(voice)
	audio = audio_voices[0]
	tones = preload("res://scripts/combat_audio.gd").TRACKS.duplicate()
	for skin in range(Skins.CATALOG.size()):
		tones["shot_%d" % skin] = tones["shot_%d_0" % skin]

func roar_wave(seconds: float, base_hz: float, grit: float) -> AudioStreamWAV:
	# A held, throaty beam: two detuned saws under a slow tremolo.
	var wave = AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = 22050
	var count = int(22050 * seconds)
	var bytes = PackedByteArray()
	bytes.resize(count * 2)
	var noise = RandomNumberGenerator.new()
	noise.seed = int(base_hz)
	for i in range(count):
		var t = float(i) / 22050.0
		var progress = float(i) / count
		var saw = fmod(t * base_hz, 1.0) * 2.0 - 1.0 + fmod(t * base_hz * 1.004, 1.0) * 2.0 - 1.0
		var tremolo = 0.75 + 0.25 * sin(t * TAU * 21.0)
		var envelope = minf(t * 24.0, 1.0) * minf((1.0 - progress) * 4.0, 1.0)
		var value = saw * 0.4 + grit * noise.randf_range(-1.0, 1.0) * 0.5
		bytes.encode_s16(i * 2, int(clampf(value * tremolo * envelope * 0.8, -1.0, 1.0) * 19000))
	wave.data = bytes
	return wave

func crack_wave(seconds: float) -> AudioStreamWAV:
	# Lightning: a white crack that collapses into a rolling tail.
	var wave = AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = 22050
	var count = int(22050 * seconds)
	var bytes = PackedByteArray()
	bytes.resize(count * 2)
	var noise = RandomNumberGenerator.new()
	noise.seed = 4711
	var rumble = 0.0
	for i in range(count):
		var t = float(i) / 22050.0
		var progress = float(i) / count
		var snap = noise.randf_range(-1.0, 1.0) * pow(1.0 - progress, 5.0)
		rumble = lerpf(rumble, noise.randf_range(-1.0, 1.0), 0.06)
		var body = rumble * pow(1.0 - progress, 1.6) * 0.9 + sin(t * TAU * lerpf(90.0, 40.0, progress)) * 0.3 * pow(1.0 - progress, 2.0)
		bytes.encode_s16(i * 2, int(clampf(snap + body, -1.0, 1.0) * 19000))
	wave.data = bytes
	return wave

func chime_wave(seconds: float, base_hz: float) -> AudioStreamWAV:
	# Bloom: a soft major chord that opens upwards, like the wall breathing again.
	var wave = AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = 22050
	var count = int(22050 * seconds)
	var bytes = PackedByteArray()
	bytes.resize(count * 2)
	for i in range(count):
		var t = float(i) / 22050.0
		var progress = float(i) / count
		var value = 0.0
		for step in range(3):
			var partial = base_hz * [1.0, 1.26, 1.5][step]
			var start = step * 0.08
			if t < start:
				continue
			value += sin((t - start) * TAU * partial) * pow(1.0 - progress, 1.8) * [0.5, 0.36, 0.3][step]
		bytes.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 19000))
	wave.data = bytes
	return wave

func sweep_wave(seconds: float, from_hz: float, to_hz: float, grit: float) -> AudioStreamWAV:
	# Continuous phase keeps the sweep free of clicks; the noise share gives each cue its body.
	var wave = AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = 22050
	var count = int(22050 * seconds)
	var bytes = PackedByteArray()
	bytes.resize(count * 2)
	var noise = RandomNumberGenerator.new()
	noise.seed = int(from_hz + to_hz)
	var phase = 0.0
	for i in range(count):
		var progress = float(i) / count
		phase += TAU * lerpf(from_hz, to_hz, progress * progress) / 22050.0
		var envelope = minf(float(i) / 140.0, 1.0) * pow(1.0 - progress, 1.55)
		var value = sin(phase) + grit * noise.randf_range(-1.0, 1.0) * (1.0 - progress)
		bytes.encode_s16(i * 2, int(clampf(value * envelope * 0.62, -1.0, 1.0) * 19000))
	wave.data = bytes
	return wave

func play_tone(sound: String, gain_db: float = 0.0) -> void:
	if audio_voices.is_empty() or not tones.has(sound):
		return
	var now = Time.get_ticks_msec()
	var weapon = sound.begins_with("shot_")
	var priority = 0 if weapon or sound in ["bounce", "ricochet", "metal"] else (3 if sound in ["charging", "unleash", "goal"] else 2)
	# Dense combat should not turn one event into a stack of identical loud transients.
	if not weapon and priority < 3 and now - int(sound_times.get(sound, -1000)) < 28 and audio_voices.any(func(v): return v.playing and v.stream == tones[sound]):
		return
	sound_times[sound] = now
	var voice: AudioStreamPlayer = null
	for candidate in audio_voices:
		if bool(candidate.get_meta("weapon_voice", false)) == weapon and not candidate.playing:
			voice = candidate
			break
	if voice == null and not weapon:
		for candidate in audio_voices:
			if not candidate.get_meta("weapon_voice", false) and int(candidate.get_meta("priority", 0)) < priority and (voice == null or int(candidate.get_meta("started", 0)) < int(voice.get_meta("started", 0))):
				voice = candidate
	if voice == null:
		return
	voice.set_meta("priority", priority)
	voice.set_meta("started", now)
	voice.volume_db = (-17.5 if weapon else (-14.0 if priority == 3 else (-23.0 if priority == 0 else -18.0))) + gain_db
	voice.set_meta("mix_gain", voice.volume_db)
	voice.set_meta("secondary", weapon or sound in ["bounce", "metal", "ricochet", "sentry", "hit_0", "hit_1", "hit_2", "break_0", "break_1", "break_2"])
	voice.volume_db += linear_to_db(maxf(game_settings.sfx_volume, 0.0001)) + (arena_duck_db if voice.get_meta("secondary") else 0.0)
	voice.pitch_scale = 1.0
	voice.bus = CombatAudio.bus_for(event_pan)
	voice.stream = tones[sound]
	voice.play()

func capture_preview(path: String) -> void:
	await get_tree().create_timer(4.2).timeout
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	var error = img.save_png(path)
	print("CAPTURE_RESULT ", error, " ", path)
	get_tree().quit(error)

func close_cup_screen() -> void:
	if hud.skins_overlay.visible:
		hud.close_skins()
	cup_active = false
	arena.show()
	if is_instance_valid(cup_screen):
		cup_screen.hide()

func cup_action(id: String) -> void:
	match id:
		"play": start_cup()
		"menu": return_to_menu()
		"practice": start_pve()
		"arenas": hud.open_levels()
		"settings_open": hud.open_video()
		"skins": hud.open_skins()
		"powers": hud.open_powers()
		"settings": hud.open_video()
		"pvp": hud.open_pvp()

func start_cup() -> void:
	# A Taça match is the campaign level for that round, played exactly as the campaign
	# plays it: its arena, its boss in its own colours, its kit, its pace and its theme.
	if cup.confirmed_match().is_empty():
		return
	var index: int = cup.level_index()
	var level: Dictionary = cup.level()
	arena.show()
	close_network()
	pve_paused = false
	mode = "pve"
	local_team = 0
	network_status = ""
	level_index = -1
	menu_level = index
	use_map(level.map)
	rules.ai_profile = cup.profile(game_settings.difficulty)
	use_loadouts(cup.kit(), int(level.boss), Campaign.level_ultimate(index))
	rules.reset_match()
	dress_pilots(0)
	arena.set_skin(1, int(level.boss), Campaign.is_minor(index), Campaign.level_hue(index))
	hud.team_hues = arena.unit_hues
	hud.level_info = {"number": cup.step(), "cup": true, "round": cup.round_name().to_upper(), "name": level.name, "challenge": level.get("challenge", ""), "boss_name": cup.opponent().to_upper(), "has_next": false}
	hud.level_result = ""
	hud.level_skin = ""
	hud.show_game(mode, 0)
	sync_assist()
	cup_screen.hide()
	cup_active = true
	cup_resolved = false
	last_phase = ""
	music.play_skin(Campaign.level_music(index))

func finish_cup() -> void:
	# The result becomes part of the story: a win moves the draw on and prints the next
	# edition; a defeat is remembered by the kiosk and nothing else. Either way the run
	# comes back to the hub, never to a generic menu.
	var won = rules.winner == 0
	var step: int = cup.step()
	var rival: String = cup.opponent()
	var boss: int = cup.boss_id()
	var index: int = cup.level_index()
	var score = Array(rules.scores).duplicate()
	bank_bricks()
	var rewards: Array = []
	if won:
		cup.complete(score)
		open_arena(index)
		if step > 0 and boss > 0 and skins.defeat(boss):
			rewards.append(Skins.CATALOG[boss].name)
		if cup.champion() and skins.defeat(11):
			rewards.append(Skins.CATALOG[11].name)
		save_skins()
	else:
		cup.lose(score)
	if cup.save() != OK:
		push_warning("Não foi possível guardar a Taça.")
	sync_story()
	return_to_menu()
	open_cup()
	cup_screen.show_after({"won": won, "score": score, "rival": rival, "step": step, "reward": " · ".join(rewards)})

func open_arena(index: int) -> void:
	# A round won opens its arena for free play in ARENAS, whatever the build.
	if not campaign.completed.has(index):
		campaign.completed.append(index)
	campaign.unlocked = clampi(maxi(campaign.unlocked, index + 2), 1, Campaign.LEVELS.size())
	campaign.save_preferences()
	hud.sync_campaign(campaign)

func sync_story() -> void:
	# What the lobby says about the story: the round to play and who waits in it.
	if cup.champion():
		hud.story_line = "Campeão da Taça Aurora"
		hud.story_boss = -1
	else:
		var m: Dictionary = cup.confirmed_match()
		hud.story_line = "%s  ·  vs %s" % [String(m.round_name).to_upper(), String(m.name).to_upper()]
		hud.story_boss = int(m.boss)
	menu_level = cup.level_index() if not cup.champion() else Campaign.menu_levels().back()
	hud.sync_menu_level(menu_level)

func open_cup() -> void:
	cup_screen.show()
	cup_screen.refresh()
	arena.hide()

func preview_skin_music(index: int) -> void:
	if skin_music_return.is_empty():
		skin_music_return = music.track
	music.play_skin(index)
	if not music.enabled:
		hud.skin_music_note.text = "MÚSICA DESLIGADA · ativa-a nas Opções"

func restore_skin_music() -> void:
	if not skin_music_return.is_empty():
		music.play(skin_music_return)
		skin_music_return = ""
