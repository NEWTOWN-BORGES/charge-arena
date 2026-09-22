extends Control
var cup_difficulty: OptionButton
var options_scroll: ScrollContainer
const Skins = preload("res://scripts/skins.gd")
const GameSettings = preload("res://scripts/game_settings.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Rules = preload("res://scripts/arena_rules.gd")
const STICK_RADIUS = 62.0
# Power buttons sit in the free band between the two thumb controls, above the FPS line.
# The two bought powers, and then the ultimate, which is the one you are waiting for all
# match and deserves to look like it.
const POWER_RADIUS = 48.0
const ULTIMATE_RADIUS = 62.0

func power_button_radius(index: int) -> float:
	return ULTIMATE_RADIUS if index == Rules.POWER_SLOTS - 1 else POWER_RADIUS
const POWER_GAP = 100.0
const POWER_RISE = 176.0
const Powers = preload("res://scripts/powers.gd")
signal pvp_ai_requested
signal play_requested
signal host_requested
signal join_requested(address: String)
signal menu_requested
signal resume_requested
signal quit_requested
signal replay_requested
signal video_changed(fps: int, quality: int, sync: bool, counter: bool)
signal video_opened
signal audio_changed(enabled: bool, volume: float)
signal layout_changed
signal skin_selected(index: int)
signal skin_previewed(index: int)
signal skin_preview_closed
signal cup_requested
var skin_strip: ScrollContainer
var skin_music_note: Label
signal difficulty_changed(level: int)
signal guide_changed(on: bool)
signal sensitivity_changed(level: int)
signal level_selected(index: int)
signal next_level_requested
signal levels_requested
signal power_bought(id: String)
signal power_equipped(slot: int, id: String)
signal menu_level_changed(step: int)
const INK = Color("142b32")
const BRASS = Color("e8bd78")
const CERAMIC = Color("dedbca")
const MUTED = Color("a6b7bd")
const WHITE = Color("f2eee4")
const CYAN = Color("72ddc6")
const CORAL = Color("ef947e")
const LIME = Color("dbdf9a")
var menu: PanelContainer
var menu_status: Label
var ip: LineEdit
var back: Button
var host_ai_button: Button
var replay: Button
var match_data: Dictionary = {}
var team = 0
var mode = "menu"
var network_status = ""
var touches: Dictionary = {}
var move_id = -1
var move_vector = Vector2.ZERO
var move_center = Vector2.ZERO
var power_centers: Array = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
# One-shot request, read once by the match loop; the flash is only the press animation.
var power_request = -1
var power_flash: Array = [0.0, 0.0, 0.0]
var difficulty_buttons: Array = []
var guide_choice: CheckButton
var sensitivity_choice: OptionButton
var viewer_audio: AudioStreamPlayer
var viewer_sound_pending = false
var font: Font
# Soft edges on every little circle and arc cost one draw call each. Kept on the roomier
# profiles, dropped on the light one, where the frame budget matters more than the edges.
var smooth = true
# The HUD redraws at most thirty times a second. Dragging the stick used to redraw it on
# every frame, and the HUD is over half the draw calls in a frame.
const REDRAW_INTERVAL = 1.0 / 30.0
var redraw_wait = 0.0
var redraw_asked = false
var font_bold: Font
var video_overlay: ColorRect
var video_panel: PanelContainer
var video_button: Button
var fps_choice: OptionButton
var quality_choice: OptionButton
var sync_choice: CheckButton
var counter_choice: CheckButton
var video_note: Label
var fps_label: Label
var style_cache: Dictionary = {}
var music_choice: CheckButton
var music_volume: HSlider
# Layout results shared by _draw, touch input and the camera framing in main.gd.
var vertical = false
var arena_rect = Rect2()
var arena_aspect = 16.06 / 13.68
var safe_top = 0.0
var safe_bottom = 0.0
var touch_top = 0.0
var move_home = Vector2.ZERO
var score_rect = Rect2()
var card_rects: Array = [Rect2(), Rect2()]
var message_center = Vector2.ZERO
var pause_overlay: ColorRect
var campaign_state = null
# Level being played ({} outside the campaign) and how it ended: "", "won" or "lost".
var level_info: Dictionary = {}
var level_result = ""
var level_opened = false
# Name of the skin this win unlocked, for the result card.
var level_skin = ""
var campaign_button: Button
var quick_button: Button
var next_button: Button
var levels_button: Button
var pvp_overlay: ColorRect
var pvp_panel: PanelContainer
var levels_overlay: ColorRect
var levels_panel: PanelContainer
var levels_grid: GridContainer
var levels_progress: Label
var level_cards: Array = []
# Menu carousel: the level previewed behind the menu, and where a swipe started.
var menu_level = 0
var swipe_start = Vector2.INF
const SWIPE_DISTANCE = 70.0
var skins_overlay: ColorRect
var skins_panel: PanelContainer
var skins_button: Button
var powers_button: Button
var news_text = ""
const MENU_HINT = "Toque: arrasta para mover · o disparo é automático · PC: A/D"
var powers_overlay: ColorRect
var powers_panel: PanelContainer
var powers_wallet: Label
var powers_detail: Label
var power_cards: Array = []
var power_slot_buttons: Array = []
var power_buy: Button
var power_actions: GridContainer
var power_shop = null
var shop_index = 0
var power_demo: Control
var skin_ultimate_name: Label
var skin_ultimate_about: Label
var skin_ultimate_demo: Control
var viewer_column: VBoxContainer
var viewer_zoom = 1.0
var skins_scroll: ScrollContainer
# Seconds into the looping demonstration of the previewed power.
var demo_clock = 0.0
var skins_total: Label
var skins_body: BoxContainer
var skin_name: Label
var skin_weapon: Label
var skin_bricks: Label
var skin_about: Label
var skin_state: Label
var skin_progress: ProgressBar
var skin_swatches: Control
var skin_thumbs: Array = []
var skin_action: Button
var skins_progress = null
var preview_index = 0
# 3D turntable: its own world, built with the arena's pilot factory.
var arena_view: Node3D
var viewer: SubViewportContainer
var viewer_stage: Node3D
var viewer_turntable: Node3D
var viewer_pilot: Node3D
var viewer_skin = -1
var viewer_locked = false
var viewer_camera: Camera3D
var viewer_yaw = 0.5
var viewer_idle = 9.0
var viewer_clock = 0.0
var viewer_fire_timer = 0.6
var viewer_shots: Array = []
var viewer_sparks: Array = []
var viewer_bricks: Array = []
# Skin worn by each team; main.gd shares the arena's own array.
var team_skins: Array = [0, 0]
var team_tints: Array = [false, false]
var team_hues: Array = ["", ""]
var unlock_text = ""
var unlock_timer = 0.0
var pause_panel: PanelContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	var bold = SystemFont.new()
	bold.font_names = PackedStringArray(["Bahnschrift", "Arial", "sans-serif"])
	bold.font_weight = 700
	font_bold = bold
	build_menu()
	back = make_button("MENU", false)
	add_child(back)
	back.pressed.connect(func(): menu_requested.emit())
	replay = make_button("JOGAR NOVAMENTE", true)
	add_child(replay)
	replay.pressed.connect(func(): replay_requested.emit())
	replay.hide()
	next_button = make_button("PRÓXIMO NÍVEL  →", true)
	add_child(next_button)
	next_button.pressed.connect(func(): next_level_requested.emit())
	next_button.hide()
	levels_button = make_button("NÍVEIS", false)
	add_child(levels_button)
	levels_button.pressed.connect(func(): levels_requested.emit())
	levels_button.hide()
	host_ai_button = make_button("JOGAR COM IA AGORA", true)
	add_child(host_ai_button)
	host_ai_button.pressed.connect(func(): pvp_ai_requested.emit())
	host_ai_button.hide()
	build_video_menu()
	build_pause_menu()
	build_skins_menu()
	build_pvp_menu()
	build_levels_menu()
	build_powers_menu()
	resized.connect(layout)
	layout()

func style(color: Color, border: Color = Color.TRANSPARENT, radius: int = 16) -> StyleBoxFlat:
	var key = str(color) + str(border) + str(radius)
	if style_cache.has(key):
		return style_cache[key]
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.corner_detail = 10
	s.anti_aliasing = true
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	style_cache[key] = s
	return s

func build_pause_menu() -> void:
	pause_overlay = ColorRect.new()
	pause_overlay.color = Color(0.015, 0.035, 0.045, 0.88)
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(pause_overlay)
	pause_panel = PanelContainer.new()
	pause_panel.add_theme_stylebox_override("panel", style(Color("122b32"), CYAN, 24))
	pause_overlay.add_child(pause_panel)
	var list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 18)
	pause_panel.add_child(list)
	list.add_child(label("JOGO EM PAUSA", 26, WHITE, true))
	var resume = make_button("VOLTAR AO JOGO", true)
	list.add_child(resume)
	resume.pressed.connect(func(): resume_requested.emit())
	var leave = make_button("TERMINAR E IR AO MENU", false)
	list.add_child(leave)
	leave.pressed.connect(func(): quit_requested.emit())
	pause_overlay.hide()

func build_skins_menu() -> void:
	skins_overlay = ColorRect.new()
	skins_overlay.color = Color(0.015, 0.035, 0.045, 0.92)
	skins_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(skins_overlay)
	skins_panel = PanelContainer.new()
	skins_panel.add_theme_stylebox_override("panel", style(Color("122b32"), Color("496563"), 24))
	skins_overlay.add_child(skins_panel)
	var list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	skins_panel.add_child(list)
	var header = HBoxContainer.new()
	list.add_child(header)
	var titles = VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	titles.add_child(label("HANGAR · PILOTOS", 28, WHITE, true))
	titles.add_child(label("Roda com o dedo · usa + e − para ver os detalhes.", 17, MUTED))
	skins_total = label("", 16, CYAN, true)
	titles.add_child(skins_total)
	skins_body = BoxContainer.new()
	skins_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	skins_body.add_theme_constant_override("separation", 16)
	list.add_child(skins_body)
	build_skin_viewer()
	viewer_column = VBoxContainer.new()
	viewer_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewer_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	skins_body.add_child(viewer_column)
	viewer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewer_column.add_child(viewer)
	var zoom_controls = HBoxContainer.new()
	zoom_controls.add_theme_constant_override("separation", 8)
	viewer_column.add_child(zoom_controls)
	for item in [["−", 0.16], ["ENQUADRAR", 0.0], ["+", -0.16]]:
		var zoom_button = make_button(item[0], false)
		zoom_button.custom_minimum_size.y = 44
		zoom_button.add_theme_font_size_override("font_size", 16)
		zoom_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		zoom_button.pressed.connect(func(): zoom_viewer(item[1]))
		zoom_controls.add_child(zoom_button)
	# Name, weapon, palette, ultimate and the thumbnail grid: more than a phone screen
	# holds, so the column scrolls inside the panel.
	skins_scroll = ScrollContainer.new()
	skins_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	skins_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	skins_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skins_scroll.custom_minimum_size.y = 420
	skins_body.add_child(skins_scroll)
	var details = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 6)
	skins_scroll.add_child(details)
	skin_name = label("", 32, WHITE, true)
	details.add_child(skin_name)
	skin_weapon = label("", 16, LIME, true)
	details.add_child(skin_weapon)
	skin_bricks = label("", 16, CYAN, true)
	details.add_child(skin_bricks)
	skin_about = label("", 17, MUTED)
	skin_about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skin_about.custom_minimum_size.x = 320
	details.add_child(skin_about)
	skin_swatches = Control.new()
	skin_swatches.custom_minimum_size = Vector2(320, 50)
	skin_swatches.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skin_swatches.draw.connect(draw_swatches)
	details.add_child(skin_swatches)
	skin_progress = ProgressBar.new()
	skin_progress.show_percentage = false
	skin_progress.custom_minimum_size.y = 8
	for part in [["background", Color("0d2227")], ["fill", LIME]]:
		var bar = StyleBoxFlat.new()
		bar.bg_color = part[1]
		bar.set_corner_radius_all(4)
		skin_progress.add_theme_stylebox_override(part[0], bar)
	details.add_child(skin_progress)
	skin_state = label("", 12, MUTED, true)
	details.add_child(skin_state)
	var thumbs = GridContainer.new()
	thumbs.columns = Skins.CATALOG.size()
	thumbs.add_theme_constant_override("h_separation", 10)
	thumbs.add_theme_constant_override("v_separation", 10)
	skin_strip = ScrollContainer.new()
	skin_strip.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	skin_strip.custom_minimum_size.y = 150
	list.add_child(skin_strip)
	list.move_child(skin_strip, 1)
	skin_strip.add_child(thumbs)
	for index in range(Skins.CATALOG.size()):
		var thumb = Button.new()
		thumb.custom_minimum_size = Vector2(126, 134)
		thumb.focus_mode = Control.FOCUS_NONE
		thumb.add_theme_stylebox_override("hover", style(Color("1f444c"), Color("496563"), 16))
		thumb.add_theme_stylebox_override("pressed", style(Color("1f444c"), LIME, 16))
		thumbs.add_child(thumb)
		var face = Control.new()
		face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.draw.connect(func(): draw_thumb(face, index))
		thumb.add_child(face)
		thumb.pressed.connect(func(): preview_skin(index))
		skin_thumbs.append(thumb)
	# The ultimate this skin brings, outside the scrolling column: it is the reason a player
	# opens this page, and it used to be the one thing you had to scroll to reach.
	skin_ultimate_name = label("", 19, BRASS, true)
	details.add_child(skin_ultimate_name)
	skin_ultimate_about = label("", 16, MUTED)
	skin_ultimate_about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(skin_ultimate_about)
	skin_ultimate_demo = Control.new()
	skin_ultimate_demo.clip_contents = true
	skin_ultimate_demo.custom_minimum_size = Vector2(320, 160)
	skin_ultimate_demo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skin_ultimate_demo.draw.connect(func(): draw_demo(skin_ultimate_demo, String(Skins.CATALOG[preview_index].ultimate)))
	details.add_child(skin_ultimate_demo)
	skin_music_note = label("PRÉ-ESCUTA · tema próprio do piloto", 15, BRASS)
	list.add_child(skin_music_note)
	var actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	list.add_child(actions)
	skin_action = make_button("", true)
	skin_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skin_action.add_theme_stylebox_override("disabled", style(Color("203b41"), Color("425a59")))
	skin_action.add_theme_color_override("font_disabled_color", MUTED)
	skin_action.pressed.connect(func(): skin_selected.emit(preview_index))
	actions.add_child(skin_action)
	var done = make_button("VOLTAR", false)
	done.custom_minimum_size.x = 140
	done.pressed.connect(close_skins)
	actions.add_child(done)
	skins_overlay.hide()

func build_skin_viewer() -> void:
	viewer = SubViewportContainer.new()
	viewer.stretch = true
	viewer.mouse_filter = Control.MOUSE_FILTER_STOP
	viewer.gui_input.connect(viewer_input)
	var viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewer.add_child(viewport)
	viewer_stage = Node3D.new()
	viewport.add_child(viewer_stage)
	var environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b0c6c5")
	environment.environment.ambient_light_energy = 0.55
	viewer_stage.add_child(environment)
	# Same key and fill as the arena, plus a cool rim so the back of the model reads.
	for rig in [[Vector3(-52, -35, 0), Color("ffe9cc"), 1.12], [Vector3(-35, 145, 0), Color("8bc6cf"), 0.42], [Vector3(-18, 180, 0), Color("c9d8ff"), 0.45]]:
		var light = DirectionalLight3D.new()
		light.rotation_degrees = rig[0]
		light.light_color = rig[1]
		light.light_energy = rig[2]
		viewer_stage.add_child(light)
	viewer_camera = Camera3D.new()
	viewer_camera.fov = 30
	viewer_camera.current = true
	viewer_stage.add_child(viewer_camera)
	frame_viewer(1.7)
	viewer_turntable = Node3D.new()
	viewer_stage.add_child(viewer_turntable)
	viewer_audio = AudioStreamPlayer.new()
	viewer_audio.volume_db = -18
	add_child(viewer_audio)

func frame_viewer(tall: float) -> void:
	# Pull the camera back until the whole pilot fits, however tall this one is. A crown, a
	# lantern mast or a tricorne used to walk straight out of the top of the frame.
	if not is_instance_valid(viewer_camera):
		return
	var middle: float = tall * 0.5
	# What half an image has to cover, plus a little air, converted into a distance.
	var reach: float = maxf(middle + 0.12, 0.85)
	var back: float = reach / tan(deg_to_rad(viewer_camera.fov) * 0.5)
	viewer_camera.transform = Transform3D(Basis(), Vector3(0, middle + 0.55, (back + 0.15) * viewer_zoom)).looking_at(Vector3(0, middle, 0), Vector3.UP)

func measure_viewer_pilot() -> float:
	# How tall the model standing on the turntable actually is, in world units.
	if not is_instance_valid(viewer_pilot):
		return 1.7
	var tall := 0.0
	for node in viewer_pilot.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = node.transform * node.get_aabb()
		var walk: Node3D = node.get_parent()
		while walk != null and walk != viewer_pilot:
			box = walk.transform * box
			walk = walk.get_parent()
		tall = maxf(tall, box.end.y)
	return clampf(tall, 1.2, 4.0)

func build_viewer_pilot() -> void:
	if not is_instance_valid(arena_view):
		return
	var locked = skins_progress != null and not skins_progress.is_unlocked(preview_index)
	if viewer_skin == preview_index and viewer_locked == locked and is_instance_valid(viewer_pilot):
		return
	if viewer_turntable.get_child_count() == 0:
		# Pedestal with brass studs, so the turn is visible even on a symmetric pose.
		arena_view.cylinder(viewer_turntable, Vector3(0, -0.1, 0), 1.08, 0.2, arena_view.DARK)
		arena_view.cylinder(viewer_turntable, Vector3(0, 0.005, 0), 0.99, 0.03, Color("2c4c54"))
		arena_view.torus(viewer_turntable, Vector3(0, 0.02, 0), 0.99, 0.014, arena_view.CREAM, false)
		arena_view.torus(viewer_turntable, Vector3(0, 0.0, 0), 1.08, 0.02, arena_view.GOLD, false)
		for i in range(6):
			var angle = i * TAU / 6
			arena_view.cylinder(viewer_turntable, Vector3(cos(angle) * 1.03, -0.05, sin(angle) * 1.03), 0.05, 0.12, arena_view.GOLD, false, 8)
	clear_viewer_shots()
	if is_instance_valid(viewer_pilot):
		viewer_pilot.queue_free()
	# Every pilot is shown in the colours it was drawn in, beaten or not.
	viewer_pilot = arena_view.build_player(CYAN, 0, preview_index, viewer_turntable, false)
	viewer_pilot.position = Vector3(0, 0.02, 0)
	frame_viewer(measure_viewer_pilot())
	for brick in viewer_bricks:
		brick.queue_free()
	viewer_bricks.clear()
	# Two exhibition bricks of the skin's theme; the second shows a lost life.
	for side in [-1, 1]:
		var data = {"team": 1 if locked else 0, "p": Vector2(side * 0.7, 0.28), "rotation": side * 1.05}
		viewer_bricks.append(arena_view.make_brick(viewer_turntable, data, preview_index, locked))
	viewer_bricks[1].scale = Vector3.ONE * arena_view.Rules.brick_scale(2)
	viewer_bricks[1].get_node("HP2").hide()
	viewer_skin = preview_index
	viewer_locked = locked
	viewer_fire_timer = 0.35

func zoom_viewer(amount: float) -> void:
	viewer_zoom = 1.0 if is_zero_approx(amount) else clampf(viewer_zoom + amount, 0.55, 1.55)
	frame_viewer(measure_viewer_pilot())

func viewer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: zoom_viewer(-0.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: zoom_viewer(0.1)
	# Touch arrives as emulated mouse motion, so one path serves phones and PC.
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		viewer_yaw += event.relative.x * 0.012
		viewer_idle = 0.0

func animate_viewer(dt: float) -> void:
	viewer_clock += dt
	viewer_idle += dt
	if viewer_idle > 1.5:
		viewer_yaw += dt * 0.55
	viewer_turntable.rotation.y = viewer_yaw
	var body: Node3D = viewer_pilot.get_node("Body")
	body.position.y = sin(viewer_clock * 2.2) * 0.02
	var orbit: Node3D = body.get_node_or_null("OrbitTilt/Orbit")
	if orbit != null:
		orbit.rotation.y = viewer_clock * 1.1
	arena_view.spin_parts(body, viewer_clock)
	var gun: Node3D = body.get_node("Gun")
	var flash: Node3D = gun.get_node("Flash")
	viewer_fire_timer -= dt
	if viewer_fire_timer <= 0:
		viewer_fire_timer = 1.6
		gun.position.z = 0.13
		flash.scale = Vector3.ONE * 0.34
		spawn_viewer_shot(flash.global_position, -body.global_transform.basis.z)
		if viewer_sound_pending:
			# Only the first demo shot after choosing a skin is heard, so the loop stays quiet.
			viewer_sound_pending = false
			viewer_audio.stream = load(Skins.SHOT_SOUND % viewer_skin)
			viewer_audio.play()
	gun.position.z = lerpf(gun.position.z, 0, minf(dt * 18, 1))
	flash.scale = flash.scale.lerp(Vector3.ONE * 0.001, minf(dt * 22, 1))
	var shot_color: Color = viewer_palette().shot
	for shot in viewer_shots.duplicate():
		shot.ttl -= dt
		shot.node.position += shot.v * dt
		shot.spark -= dt
		if shot.spark <= 0 and shot.ttl > 0:
			shot.spark = 0.04
			var spark = arena_view.sphere(viewer_stage, shot.node.position, Vector3.ONE * 0.12, Color(shot_color, 0.7), true)
			viewer_sparks.append({"node": spark, "ttl": 0.25})
		if shot.ttl <= 0:
			shot.node.queue_free()
			viewer_shots.erase(shot)
	for spark in viewer_sparks.duplicate():
		spark.ttl -= dt
		spark.node.scale = Vector3.ONE * 0.12 * clampf(spark.ttl / 0.25, 0.001, 1)
		if spark.ttl <= 0:
			spark.node.queue_free()
			viewer_sparks.erase(spark)

func spawn_viewer_shot(origin: Vector3, direction: Vector3) -> void:
	var shot_color: Color = viewer_palette().shot
	var root = Node3D.new()
	viewer_stage.add_child(root)
	root.position = origin
	arena_view.sphere(root, Vector3.ZERO, Vector3.ONE * 0.2, Color("fff3d5"), true)
	arena_view.sphere(root, Vector3.ZERO, Vector3.ONE * 0.32, Color(shot_color, 0.3), true)
	viewer_shots.append({"node": root, "v": direction.normalized() * 3.2, "ttl": 1.0, "spark": 0.0})

func clear_viewer_shots() -> void:
	for item in viewer_shots + viewer_sparks:
		item.node.queue_free()
	viewer_shots.clear()
	viewer_sparks.clear()

func sync_skins(skins) -> void:
	skins_progress = skins
	skins_button.text = "SKINS  %d/%d" % [skins.unlocked_count(), Skins.CATALOG.size()]
	refresh_skins()
	refresh_news()

func refresh_news() -> void:
	# A pilot who has just won a skin, or saved enough for a power, should not have to go
	# looking: the button that holds it says so, and a line underneath names it.
	if menu_status == null:
		return
	var lines: Array = []
	var fresh_skins: Array = []
	if skins_progress != null:
		fresh_skins = skins_progress.unseen()
	var buyable: Array = []
	if power_shop != null:
		buyable = power_shop.affordable()
	var cheapest: Dictionary = {}
	for entry in buyable:
		if cheapest.is_empty() or int(entry.price) < int(cheapest.price):
			cheapest = entry
	# One line has to hold this, so with news on both sides each half says less.
	var crowded: bool = not fresh_skins.is_empty() and not buyable.is_empty()
	if not fresh_skins.is_empty():
		var names: Array = fresh_skins.map(func(i): return String(Skins.CATALOG[i].name))
		if crowded:
			lines.append("Skin nova: %s" % String(names[0]) if names.size() == 1 else "%d skins novas" % names.size())
		else:
			lines.append("Skin nova: %s — abre SKINS" % " · ".join(names))
	if not buyable.is_empty():
		if crowded:
			lines.append("%d poderes ao teu alcance" % buyable.size() if buyable.size() > 1 else "%s ao teu alcance" % String(cheapest.name))
		else:
			var tail = "" if buyable.size() == 1 else " (e mais %d)" % (buyable.size() - 1)
			lines.append("Podes comprar %s por %d tijolos%s — abre PODERES" % [String(cheapest.name), int(cheapest.price), tail])
	news_text = "  ·  ".join(lines)
	# Shown in the row the menu already keeps for its hint, so nothing grows and the
	# main action stays where the thumb rests.
	menu_status.text = news_text if news_text != "" else MENU_HINT
	menu_status.add_theme_color_override("font_color", LIME if news_text != "" else MUTED)
	if skins_button != null:
		skins_button.text = "SKINS  %d/%d%s" % [skins_progress.unlocked_count() if skins_progress != null else 0, Skins.CATALOG.size(), "  •" if not fresh_skins.is_empty() else ""]
	if powers_button != null and power_shop != null:
		powers_button.text = "PODERES  %d/%d%s" % [power_shop.owned.size(), Powers.CATALOG.size(), "  •" if not buyable.is_empty() else ""]

func viewer_palette() -> Dictionary:
	return Skins.colors(viewer_skin, CORAL, true) if viewer_locked else Skins.colors(viewer_skin, CYAN)

func preview_skin(index: int) -> void:
	preview_index = clampi(index, 0, Skins.CATALOG.size() - 1)
	if skins_overlay.visible:
		skin_music_note.text = "PRÉ-ESCUTA · " + String(Skins.CATALOG[preview_index].name)
		skin_previewed.emit(preview_index)
	viewer_sound_pending = true
	refresh_skins()
	build_viewer_pilot()

func refresh_skins() -> void:
	if skins_progress == null:
		return
	var entry: Dictionary = Skins.CATALOG[preview_index]
	var level: int = entry.level
	var open: bool = skins_progress.is_unlocked(preview_index)
	var bosses = Skins.CATALOG.size() - 1
	skins_total.text = "COLEÇÃO: %d / %d" % [skins_progress.unlocked_count(), Skins.CATALOG.size()]
	skin_name.text = entry.name
	skin_weapon.text = "ARMA  ·  " + entry.weapon.to_upper()
	skin_bricks.text = "TIJOLOS  ·  " + entry.bricks.to_upper()
	skin_about.text = entry.about
	# The bar tracks the whole boss collection.
	skin_progress.visible = level > 0
	skin_progress.max_value = bosses
	skin_progress.value = skins_progress.unlocked_count() - 1
	if entry.get("cup_reward", false):
		skin_state.text = "PRÉMIO DA TAÇA · DESBLOQUEADO" if open else "SKIN DE PRÉMIO · CONQUISTA A TAÇA"
	elif level == 0:
		skin_state.text = "DE SÉRIE"
	elif open:
		skin_state.text = "DESBLOQUEADA  ·  BOSS DO NÍVEL %d" % level
	else:
		skin_state.text = "BLOQUEADA  ·  VENCE ESTE PILOTO NA TAÇA OU NO NÍVEL %d" % level
	skin_state.add_theme_color_override("font_color", LIME if open else MUTED)
	var ultimate: Dictionary = Powers.entry(String(entry.ultimate))
	skin_ultimate_name.text = ("ULTIMATE  ·  " + String(ultimate.name)) if not ultimate.is_empty() else "ULTIMATE  ·  EM BREVE"
	skin_ultimate_about.text = String(ultimate.about) if not ultimate.is_empty() else "Esta skin ainda não tem ultimate; o terceiro slot fica por preencher."
	skin_ultimate_name.add_theme_color_override("font_color", BRASS if not ultimate.is_empty() else MUTED)
	skin_ultimate_demo.queue_redraw()
	if skins_progress.selected == preview_index:
		skin_action.text = "EQUIPADA"
	elif open:
		skin_action.text = "EQUIPAR"
	else:
		skin_action.text = "CONQUISTA A TAÇA" if entry.get("cup_reward", false) else "VENCE ESTE PILOTO"
	skin_action.disabled = skins_progress.selected == preview_index or not open
	for index in range(skin_thumbs.size()):
		var thumb: Button = skin_thumbs[index]
		thumb.add_theme_stylebox_override("normal", style(Color("1f444c") if index == preview_index else Color("183840"), LIME if index == preview_index else Color("334f51"), 16))
		thumb.get_child(0).queue_redraw()
	skin_swatches.queue_redraw()
	if skins_overlay.visible:
		# A boss beaten while the panel is open swaps to its true colours.
		build_viewer_pilot()

func draw_swatches() -> void:
	var entry: Dictionary = Skins.CATALOG[preview_index]
	var locked = skins_progress != null and not skins_progress.is_unlocked(preview_index)
	var palette = Skins.colors(preview_index, CORAL, true) if locked else Skins.colors(preview_index, CYAN)
	var items = [["CORPO", palette.body], ["LUZ", palette.light], ["DISPARO", palette.shot]]
	for i in range(items.size()):
		var at = Vector2(11 + i * 106, 13)
		skin_swatches.draw_circle(at, 10, items[i][1], true, -1, smooth)
		skin_swatches.draw_arc(at, 10, 0, TAU, 32, Color(WHITE, 0.3), 1, smooth)
		skin_swatches.draw_string(font_bold, at + Vector2(17, 5), items[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, WHITE)
	var note = "Paleta própria · ombros na cor da equipa"
	if locked:
		note = "Roda o piloto para veres todos os detalhes"
	elif entry.body == "" and entry.shot == "":
		note = "Cores da equipa: jade ou coral"
	elif entry.body == "":
		note = "Casaco da equipa · luz e disparo próprios"
	skin_swatches.draw_string(font, Vector2(0, 45), note, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MUTED)

func draw_thumb(canvas: Control, index: int) -> void:
	var locked = skins_progress != null and not skins_progress.is_unlocked(index)
	portrait(Vector2(canvas.size.x * 0.5, 56), CORAL if locked else CYAN, false, index, canvas, locked)
	if skins_progress == null:
		return
	var short_name = String(Skins.CATALOG[index].name).replace("PILOTO ", "")
	canvas.draw_string(font_bold, Vector2(5, 113), short_name, HORIZONTAL_ALIGNMENT_CENTER, canvas.size.x - 10, 12, WHITE)
	var caption = ""
	var color = MUTED
	if locked:
		canvas.draw_circle(Vector2(canvas.size.x * 0.5, 56), 47, Color(0.02, 0.05, 0.06, 0.45), true, -1, smooth)
		caption = "PRÉMIO DA TAÇA" if Skins.CATALOG[index].get("cup_reward", false) else "BOSS NÍVEL %d" % Skins.CATALOG[index].level
	elif skins_progress.selected == index:
		caption = "EQUIPADA"
		color = LIME
	if caption != "":
		var width = font_bold.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		canvas.draw_string(font_bold, Vector2((canvas.size.x - width) * 0.5, 129), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)

func open_skins() -> void:
	reset_touch()
	if skins_progress != null:
		# Opening the panel is what marks them as seen; the dot goes out.
		skins_progress.mark_seen()
		skins_progress.save_preferences()
		refresh_news()
	skins_overlay.show()
	preview_skin(skins_progress.selected if skins_progress != null else 0)

func close_skins() -> void:
	skins_overlay.hide()
	skin_preview_closed.emit()
	clear_viewer_shots()

func announce_unlock(names: Array) -> void:
	unlock_text = " · ".join(names)
	unlock_timer = 4.0
	queue_redraw()

func ask_redraw() -> void:
	# Marks the HUD dirty; the repaint happens on the next slot of the redraw clock.
	redraw_asked = true

func _process(dt: float) -> void:
	redraw_wait += dt
	if redraw_asked and redraw_wait >= REDRAW_INTERVAL:
		redraw_wait = 0.0
		redraw_asked = false
		queue_redraw()
	if unlock_timer > 0:
		unlock_timer = maxf(unlock_timer - dt, 0)
		queue_redraw()
	for index in range(power_flash.size()):
		if power_flash[index] > 0:
			power_flash[index] = maxf(power_flash[index] - dt, 0)
			queue_redraw()
	if skins_overlay.visible and is_instance_valid(viewer_pilot):
		animate_viewer(dt)
	if powers_overlay != null and powers_overlay.visible:
		demo_clock += dt
		power_demo.queue_redraw()
	elif skins_overlay.visible and skin_ultimate_demo != null:
		demo_clock += dt
		skin_ultimate_demo.queue_redraw()

func show_pause(value: bool) -> void:
	reset_touch()
	pause_overlay.visible = value
	queue_redraw()

func make_button(text: String, primary: bool) -> Button:
	# 64 px is a comfortable thumb target on a phone, and reads well on a monitor too. The
	# type on it was set for a desktop and came out small on a six inch screen held at arm
	# length, which is where this game is actually played.
	var b = Button.new()
	b.text = text
	b.custom_minimum_size.y = 64
	b.add_theme_font_override("font", font_bold)
	b.add_theme_font_size_override("font_size", 21)
	paint_button(b, primary)
	return b

func raised_style(color: Color, border: Color, lift: int = 4) -> StyleBoxFlat:
	# Ceramic key with a brass edge and a soft drop shadow, like the arena furniture.
	var key = "raised" + str(color) + str(border) + str(lift)
	if style_cache.has(key):
		return style_cache[key]
	var s: StyleBoxFlat = style(color, border).duplicate()
	s.shadow_color = Color(0.01, 0.04, 0.05, 0.45)
	s.shadow_size = lift
	s.shadow_offset = Vector2(0, lift * 0.5)
	style_cache[key] = s
	return s

func paint_button(b: Button, primary: bool) -> void:
	b.add_theme_color_override("font_color", INK if primary else WHITE)
	b.add_theme_color_override("font_hover_color", INK if primary else WHITE)
	b.add_theme_color_override("font_pressed_color", INK if primary else WHITE)
	b.add_theme_stylebox_override("normal", raised_style(LIME if primary else Color("1b3940"), Color(BRASS, 0.55) if primary else Color("42625f")))
	b.add_theme_stylebox_override("hover", raised_style(LIME.lightened(0.1) if primary else Color("2b4e52"), Color(BRASS, 0.75) if primary else Color("5b7d76"), 5))
	b.add_theme_stylebox_override("pressed", raised_style(LIME.darkened(0.2) if primary else Color("426561"), Color(BRASS, 0.4) if primary else Color("6d8f88"), 1))
	b.add_theme_stylebox_override("focus", style(Color.TRANSPARENT, CYAN))

func label(text: String, font_size: int, color: Color, bold: bool = false) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_font_override("font", font_bold if bold else font)
	l.add_theme_color_override("font_color", color)
	return l

func build_menu() -> void:
	menu = PanelContainer.new()
	menu.add_theme_stylebox_override("panel", style(Color(0.055, 0.105, 0.125, 0.97), Color("3c5756"), 22))
	add_child(menu)
	var list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 13)
	menu.add_child(list)
	# Reading on top, buttons below and the main action last: with the panel anchored to
	# the bottom of the screen, that is where a thumb already rests.
	list.add_child(label("✦  CIRCUITO AURORA", 13, CYAN, true))
	list.add_child(label("CHARGE ARENA", 34, WHITE, true))
	list.add_child(label("Destrói as defesas do rival e marca 2 golos.", 15, MUTED))
	menu_status = label(MENU_HINT, 13, MUTED)
	menu_status.clip_text = true
	menu_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	list.add_child(menu_status)
	var level_row = HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 6)
	list.add_child(level_row)
	var level_caption = label("IA", 13, MUTED, true)
	level_caption.custom_minimum_size.x = 30
	level_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_row.add_child(level_caption)
	var levels = ButtonGroup.new()
	for level in range(GameSettings.DIFFICULTIES.size()):
		var pick = make_button(GameSettings.DIFFICULTIES[level], false)
		pick.custom_minimum_size.y = 48
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.toggle_mode = true
		pick.button_group = levels
		pick.focus_mode = Control.FOCUS_NONE
		pick.add_theme_font_size_override("font_size", 14)
		pick.add_theme_stylebox_override("pressed", style(LIME))
		pick.add_theme_stylebox_override("hover_pressed", style(LIME.lightened(0.1)))
		pick.add_theme_color_override("font_pressed_color", INK)
		pick.add_theme_color_override("font_hover_pressed_color", INK)
		pick.pressed.connect(func(): difficulty_changed.emit(level))
		level_row.add_child(pick)
		difficulty_buttons.append(pick)
	var extras = HBoxContainer.new()
	extras.add_theme_constant_override("separation", 10)
	list.add_child(extras)
	skins_button = make_button("SKINS", false)
	skins_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	extras.add_child(skins_button)
	skins_button.pressed.connect(open_skins)
	powers_button = make_button("PODERES", false)
	powers_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	extras.add_child(powers_button)
	powers_button.pressed.connect(open_powers)
	var graphics = make_button("OPÇÕES", false)
	graphics.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	extras.add_child(graphics)
	graphics.pressed.connect(open_video)
	# What is waiting behind those buttons, named in a line under them.
	var modes = HBoxContainer.new()
	modes.add_theme_constant_override("separation", 10)
	list.add_child(modes)
	var pvp = make_button("PvP", false)
	pvp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modes.add_child(pvp)
	pvp.pressed.connect(open_pvp)
	var level_list = make_button("TAÇA", false)
	level_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modes.add_child(level_list)
	level_list.pressed.connect(func(): cup_requested.emit())
	quick_button = make_button("JOGO RÁPIDO", false)
	quick_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modes.add_child(quick_button)
	quick_button.pressed.connect(func(): play_requested.emit())
	campaign_button = make_button("JOGAR NÍVEL 1  →", true)
	campaign_button.custom_minimum_size.y = 76
	campaign_button.add_theme_font_size_override("font_size", 21)
	campaign_button.add_theme_stylebox_override("disabled", style(Color("203b41"), Color("425a59")))
	campaign_button.add_theme_color_override("font_disabled_color", MUTED)
	list.add_child(campaign_button)
	campaign_button.pressed.connect(func(): level_selected.emit(menu_level))

func build_pvp_menu() -> void:
	pvp_overlay = ColorRect.new()
	pvp_overlay.color = Color(0.015, 0.035, 0.045, 0.92)
	pvp_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(pvp_overlay)
	pvp_panel = PanelContainer.new()
	pvp_panel.add_theme_stylebox_override("panel", style(Color("122b32"), Color("496563"), 24))
	pvp_overlay.add_child(pvp_panel)
	var list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 14)
	pvp_panel.add_child(list)
	list.add_child(label("PvP · DOIS JOGADORES", 25, WHITE, true))
	var about = label("Os dois aparelhos na mesma rede Wi-Fi e com esta versão. Um cria a sala; o outro escreve o IP que aparece e entra.", 14, MUTED)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.custom_minimum_size.x = 400
	list.add_child(about)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	list.add_child(row)
	ip = LineEdit.new()
	ip.placeholder_text = "IP do outro jogador"
	ip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip.custom_minimum_size = Vector2(210, 52)
	ip.add_theme_stylebox_override("normal", style(Color("142b32"), Color("3b5556")))
	ip.add_theme_color_override("font_color", WHITE)
	ip.add_theme_font_size_override("font_size", 16)
	row.add_child(ip)
	var join = make_button("ENTRAR", false)
	join.custom_minimum_size.y = 52
	row.add_child(join)
	join.pressed.connect(func(): close_pvp(); join_requested.emit(ip.text.strip_edges()))
	var host = make_button("CRIAR PARTIDA", true)
	host.custom_minimum_size.y = 58
	list.add_child(host)
	host.pressed.connect(func(): close_pvp(); host_requested.emit())
	var pvp_ai = make_button("JOGAR CONTRA IA (COLISEU)", false)
	pvp_ai.custom_minimum_size.y = 56
	list.add_child(pvp_ai)
	pvp_ai.pressed.connect(func(): close_pvp(); pvp_ai_requested.emit())
	var leave = make_button("VOLTAR", false)
	list.add_child(leave)
	leave.pressed.connect(close_pvp)
	pvp_overlay.hide()

func open_pvp() -> void:
	reset_touch()
	pvp_overlay.show()

func close_pvp() -> void:
	pvp_overlay.hide()

func build_powers_menu() -> void:
	# Shop and kit: buy with the bricks you have destroyed, then fill the two slots.
	powers_overlay = ColorRect.new()
	powers_overlay.color = Color(0.015, 0.035, 0.045, 0.94)
	powers_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(powers_overlay)
	powers_panel = PanelContainer.new()
	powers_panel.add_theme_stylebox_override("panel", style(Color("122b32"), Color("496563"), 24))
	powers_overlay.add_child(powers_panel)
	var list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	powers_panel.add_child(list)
	var header = HBoxContainer.new()
	list.add_child(header)
	var titles = VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	titles.add_child(label("PODERES", 25, WHITE, true))
	titles.add_child(label("Compra com os tijolos que destruíres e leva dois para a partida.", 14, MUTED))
	powers_wallet = label("", 15, CYAN, true)
	titles.add_child(powers_wallet)
	# Fourteen cards do not fit a phone screen, so the grid scrolls inside the panel.
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 300
	list.add_child(scroll)
	var grid = GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	for index in range(shop_entries().size()):
		var card = Button.new()
		card.custom_minimum_size = Vector2(190, 92)
		card.focus_mode = Control.FOCUS_NONE
		card.add_theme_stylebox_override("hover", style(Color("1f444c"), Color("496563"), 16))
		card.add_theme_stylebox_override("pressed", style(Color("1f444c"), LIME, 16))
		grid.add_child(card)
		var face = Control.new()
		face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.draw.connect(func(): draw_power_card(face, index))
		card.add_child(face)
		card.pressed.connect(func(): preview_power(index))
		power_cards.append(card)
	power_demo = Control.new()
	power_demo.clip_contents = true
	power_demo.custom_minimum_size = Vector2(600, 196)
	power_demo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_demo.draw.connect(draw_power_demo)
	list.add_child(power_demo)
	powers_detail = label("", 17, MUTED)
	powers_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	powers_detail.custom_minimum_size = Vector2(600, 40)
	list.add_child(powers_detail)
	# A grid and not a row: four buttons at this type size do not fit across a phone, and
	# the panel used to grow wider than the screen to hold them.
	power_actions = GridContainer.new()
	power_actions.columns = 4
	power_actions.add_theme_constant_override("h_separation", 8)
	power_actions.add_theme_constant_override("v_separation", 8)
	power_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var actions = power_actions
	list.add_child(actions)
	power_buy = make_button("COMPRAR", true)
	power_buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	power_buy.add_theme_stylebox_override("disabled", style(Color("203b41"), Color("425a59")))
	power_buy.add_theme_color_override("font_disabled_color", MUTED)
	power_buy.pressed.connect(func(): power_bought.emit(String(shop_entries()[shop_index].id)))
	actions.add_child(power_buy)
	for slot in range(Powers.KIT_SIZE):
		var equip = make_button("SLOT %d" % (slot + 1), false)
		equip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		equip.add_theme_stylebox_override("disabled", style(Color("203b41"), Color("425a59")))
		equip.add_theme_color_override("font_disabled_color", MUTED)
		equip.pressed.connect(func(): power_equipped.emit(slot, String(shop_entries()[shop_index].id)))
		actions.add_child(equip)
		power_slot_buttons.append(equip)
	var leave = make_button("VOLTAR", false)
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leave.pressed.connect(close_powers)
	actions.add_child(leave)
	powers_overlay.hide()

func shop_entries() -> Array:
	# Only what is actually for sale. The ultimates used to be listed here too, with a
	# "comes with the skin" label, and every visit ended in the same question: why can I
	# not buy these. They live in the skins panel, next to the skin that brings them.
	return Powers.CATALOG

func sync_powers(shop) -> void:
	power_shop = shop
	if powers_button != null:
		powers_button.text = "PODERES  %d/%d" % [shop.owned.size(), Powers.CATALOG.size()]
	refresh_powers()
	refresh_news()

func preview_power(index: int) -> void:
	shop_index = clampi(index, 0, shop_entries().size() - 1)
	# Each power starts its demonstration from the top.
	demo_clock = 0.0
	refresh_powers()

func refresh_powers() -> void:
	if power_shop == null or powers_wallet == null:
		return
	var entry: Dictionary = shop_entries()[shop_index]
	var ultimate: bool = Powers.is_ultimate(String(entry.id))
	var owned: bool = ultimate or power_shop.is_owned(entry.id)
	powers_wallet.text = "TIJOLOS: %d" % power_shop.bricks
	powers_detail.text = "%s  ·  %s  ·  carga %d tijolos\n%s" % [entry.name, String(entry.kind).to_upper(), entry.charge, entry.about]
	power_buy.text = "VEM COM A SKIN" if ultimate else ("COMPRADO" if owned else "COMPRAR · %d TIJOLOS" % entry.price)
	power_buy.disabled = ultimate or owned or not power_shop.can_buy(entry.id)
	for slot in range(power_slot_buttons.size()):
		var button: Button = power_slot_buttons[slot]
		var here: bool = power_shop.kit[slot] == entry.id
		button.text = "EQUIPADO" if here else "SLOT %d" % (slot + 1)
		button.disabled = ultimate or here or not owned
	for index in range(power_cards.size()):
		var card: Button = power_cards[index]
		card.add_theme_stylebox_override("normal", style(Color("1f444c") if index == shop_index else Color("183840"), LIME if index == shop_index else Color("334f51"), 16))
		card.get_child(0).queue_redraw()

func draw_power_card(canvas: Control, index: int) -> void:
	# A ceramic tile: brass medallion with the sigil, the name, a type pill and the state.
	var entry: Dictionary = shop_entries()[index]
	var color = Color(entry.color)
	var ultimate: bool = Powers.is_ultimate(String(entry.id))
	var owned: bool = ultimate or (power_shop != null and power_shop.is_owned(entry.id))
	var slot: int = power_shop.kit.find(entry.id) if power_shop != null else -1
	var medallion = Vector2(40, canvas.size.y * 0.5)
	canvas.draw_circle(medallion + Vector2(0, 2), 25, Color(INK, 0.5), true, -1, smooth)
	canvas.draw_circle(medallion, 25, Color(color, 0.14 if owned else 0.07), true, -1, smooth)
	canvas.draw_arc(medallion, 25, 0, TAU, 40, Color(BRASS, 0.9 if owned else 0.35), 1.4, smooth)
	canvas.draw_arc(medallion, 21, -PI * 0.75, PI * 0.15, 24, Color(CERAMIC, 0.18), 1.0, smooth)
	power_icon(String(entry.id), medallion, color if owned else Color(color, 0.42), canvas)
	var left = 76.0
	canvas.draw_string(font_bold, Vector2(left, medallion.y - 14), String(entry.short), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, WHITE if owned else Color(WHITE, 0.55))
	# Type pill in the family colour: coral attacks, jade defends.
	var attack: bool = entry.kind == "ataque"
	var pill_color = BRASS if ultimate else (CORAL if attack else CYAN)
	var pill_text = String(entry.kind).to_upper()
	var pill_width = font_bold.get_string_size(pill_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 14
	var pill = Rect2(Vector2(left, medallion.y + 1), Vector2(pill_width, 15))
	canvas.draw_style_box(style(Color(pill_color, 0.16), Color(pill_color, 0.5), 7), pill)
	canvas.draw_string(font_bold, pill.position + Vector2(7, 11), pill_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, pill_color)
	charge_glyph(canvas, Vector2(left + pill_width + 12, medallion.y + 8), entry.charge, Color(BRASS, 0.95 if owned else 0.5))
	# Bottom line: where it sits in the kit, or what it costs.
	var status = "NO SLOT %d" % (slot + 1) if slot >= 0 else ("NA MOCHILA" if owned else "%d TIJOLOS" % entry.price)
	var status_color = LIME if slot >= 0 else (CYAN if owned else MUTED)
	if ultimate:
		status = "SLOT 3 · %s" % skin_with_ultimate(String(entry.id))
		status_color = BRASS
	canvas.draw_string(font_bold, Vector2(left, medallion.y + 32), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, status_color)
	if slot >= 0:
		canvas.draw_line(Vector2(left, medallion.y + 37), Vector2(left + 54, medallion.y + 37), Color(LIME, 0.5), 1.2, smooth)

func skin_with_ultimate(id: String) -> String:
	for skin in Skins.CATALOG:
		if skin.ultimate == id:
			return String(skin.name)
	return "SKIN"

func charge_glyph(canvas: CanvasItem, at: Vector2, charge: int, color: Color) -> void:
	# A small brass bolt and the number of bricks it takes to charge.
	var bolt = PackedVector2Array([at + Vector2(2, -8), at + Vector2(-3, -1), at + Vector2(0.5, -1), at + Vector2(-2, 6), at + Vector2(3, -1), at + Vector2(-0.5, -1)])
	canvas.draw_colored_polygon(bolt, color)
	canvas.draw_string(font_bold, at + Vector2(7, 4), str(charge), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)

const DEMO_LOOP = 3.2

func demo_ball(c: CanvasItem, at: Vector2, color: Color, size: float = 5.0) -> void:
	c.draw_circle(at + Vector2(0, 2), size, Color(INK, 0.5), true, -1, smooth)
	c.draw_circle(at, size, color, true, -1, smooth)
	c.draw_circle(at, size * 0.45, Color(WHITE, 0.85), true, -1, smooth)

func demo_brick_at(area: Rect2, y: float, index: int) -> Vector2:
	# Where the nth brick of a demonstration row stands, so a drawn shot can aim at one.
	return Vector2(area.position.x + 28 + index * (area.size.x - 56) / 8.0, y)

func demo_bricks(c: CanvasItem, area: Rect2, team: Color, y: float, gone: Array = []) -> void:
	for i in range(9):
		if gone.has(i):
			continue
		var at = Vector2(area.position.x + 28 + i * (area.size.x - 56) / 8.0, y)
		c.draw_rect(Rect2(at - Vector2(13, 7), Vector2(26, 14)), team, true)
		c.draw_rect(Rect2(at - Vector2(13, 7), Vector2(26, 3)), Color(WHITE, 0.35), true)

func demo_pilot(c: CanvasItem, at: Vector2, team: Color, dazed: bool = false) -> void:
	c.draw_circle(at, 11, CERAMIC, true, -1, smooth)
	c.draw_rect(Rect2(at - Vector2(7, 2), Vector2(14, 5)), INK, true)
	c.draw_arc(at, 15, 0, TAU, 24, Color(team, 0.75), 2.0, smooth)
	if dazed:
		for i in range(3):
			var angle = demo_clock * 3.0 + i * TAU / 3.0
			var star = at + Vector2(cos(angle), sin(angle) * 0.4) * 19 - Vector2(0, 16)
			c.draw_line(star - Vector2(3, 0), star + Vector2(3, 0), LIME, 2.0, smooth)
			c.draw_line(star - Vector2(0, 3), star + Vector2(0, 3), LIME, 2.0, smooth)

func demo_brick_row(area: Rect2, index: int, top: bool) -> Vector2:
	var y = area.position.y + 50 if top else area.end.y - 56
	return Vector2(area.position.x + 28 + index * (area.size.x - 56) / 8.0, y)

func draw_power_demo() -> void:
	draw_demo(power_demo, String(shop_entries()[shop_index].id))

func draw_demo(panel: Control, id: String) -> void:
	# A little top-down rehearsal of a power, looping every few seconds.
	var entry: Dictionary = Powers.entry(id)
	var color = Color(entry.color) if not entry.is_empty() else Color(MUTED, 0.6)
	var frame = Rect2(Vector2.ZERO, panel.size)
	panel.draw_style_box(style(Color(0.03, 0.08, 0.09, 0.96), Color("2f4f53"), 14), frame)
	var area = frame.grow(-12)
	panel.draw_arc(area.get_center(), 26, 0, TAU, 40, Color(CERAMIC, 0.07), 1.2, smooth)
	var enemy_y = area.position.y + 50
	var mine_y = area.end.y - 56
	var my_pilot = Vector2(area.get_center().x, area.end.y - 16)
	var their_pilot = Vector2(area.get_center().x, area.position.y + 16)
	var u = fmod(demo_clock, DEMO_LOOP) / DEMO_LOOP
	var c: CanvasItem = panel
	if entry.is_empty():
		centered_on(c, "SEM ULTIMATE", area.get_center(), 13, Color(MUTED, 0.8))
		return
	var gone_enemy: Array = []
	var gone_mine: Array = []
	var dazed = false
	# Every demonstration is drawn back to front: bricks, then the action over them.
	match id:
		"blast":
			if u > 0.62:
				gone_enemy = [3, 4, 5]
			demo_bricks(c, area, CORAL, enemy_y, gone_enemy)
			demo_bricks(c, area, CYAN, mine_y)
			if u <= 0.6:
				demo_ball(c, my_pilot.lerp(demo_brick_row(area, 4, true), u / 0.6), color, 6.0)
			else:
				var blast = (u - 0.6) / 0.4
				c.draw_arc(demo_brick_row(area, 4, smooth), 10 + blast * 52, 0, TAU, 40, Color(color, 1.0 - blast), 3.0, true)
		"rapid":
			if u > 0.75:
				gone_enemy = [4]
			demo_bricks(c, area, CORAL, enemy_y, gone_enemy)
			demo_bricks(c, area, CYAN, mine_y)
			for round_index in range(10):
				var launched = u - round_index * 0.055
				if launched <= 0 or launched > 0.62:
					continue
				demo_ball(c, my_pilot.lerp(demo_brick_row(area, 4, true), launched / 0.62), color, 4.5)
		"air":
			demo_bricks(c, area, CORAL, enemy_y, [1, 4, 7] if u > 0.72 else [])
			demo_bricks(c, area, CYAN, mine_y)
			for pellet in range(5):
				var target = demo_brick_row(area, pellet * 2, true)
				demo_ball(c, my_pilot.lerp(target, minf(u / 0.7, 1.0)), color, 5.0)
		"ghost":
			demo_bricks(c, area, CORAL, enemy_y, [6] if u > 0.8 else [])
			demo_bricks(c, area, CYAN, mine_y)
			var pillar = Vector2(area.get_center().x + 26, area.get_center().y)
			c.draw_circle(pillar, 17, Color(CERAMIC, 0.5), true, -1, smooth)
			c.draw_arc(pillar, 17, 0, TAU, 28, Color(BRASS, 0.8), 1.6, smooth)
			demo_ball(c, my_pilot.lerp(demo_brick_row(area, 6, true), minf(u / 0.8, 1.0)), color, 5.5)
		"laser":
			var reach = minf(u / 0.25, 1.0)
			var beam_end = my_pilot.lerp(Vector2(demo_brick_row(area, 4, true).x, area.position.y + 6), reach)
			var bitten = int(clampf((u - 0.3) / 0.18, 0, 3))
			demo_bricks(c, area, CORAL, enemy_y, [4] if bitten >= 2 else [])
			demo_bricks(c, area, CYAN, mine_y)
			c.draw_line(my_pilot, beam_end, Color(color, 0.35), 12.0, smooth)
			c.draw_line(my_pilot, beam_end, color, 4.0, smooth)
			if u > 0.3:
				c.draw_circle(demo_brick_row(area, 4, smooth), 8 + sin(demo_clock * 22) * 3, Color(color, 0.5), true, -1, true)
		"rebuild":
			var back = int(clampf(u / 0.7 * 4, 0, 4))
			var missing = [1, 3, 5, 7].slice(back)
			demo_bricks(c, area, CORAL, enemy_y)
			demo_bricks(c, area, CYAN, mine_y, missing)
			for i in range(4):
				var slot = [1, 3, 5, 7][i]
				if i < back and u < 0.85:
					var age = clampf(u - i * 0.175, 0, 0.3) / 0.3
					c.draw_arc(demo_brick_row(area, slot, false), 8 + age * 16, 0, TAU, 28, Color(color, 1.0 - age), 2.4, smooth)
		"mirror":
			demo_bricks(c, area, CORAL, enemy_y, [2] if u > 0.9 else [])
			demo_bricks(c, area, CYAN, mine_y)
			# The cape over your own bricks, then the shot going home twice as fast.
			for i in range(9):
				var lid = demo_brick_row(area, i, false)
				c.draw_rect(Rect2(lid - Vector2(14, 12), Vector2(28, 4)), Color(color, 0.85), true)
				c.draw_rect(Rect2(lid - Vector2(14, 9), Vector2(28, 18)), Color(color, 0.16), true)
			var contact = demo_brick_row(area, 4, false) - Vector2(0, 12)
			if u <= 0.45:
				demo_ball(c, their_pilot.lerp(contact, u / 0.45), CORAL, 5.0)
			else:
				var back_home = minf((u - 0.45) / 0.4, 1.0)
				demo_ball(c, contact.lerp(demo_brick_row(area, 2, true), back_home), Color("d2ad73"), 6.0)
		"walls":
			demo_bricks(c, area, CORAL, enemy_y)
			demo_bricks(c, area, CYAN, mine_y)
			var rise = clampf(minf(u / 0.18, (1.0 - u) / 0.18), 0.0, 1.0)
			for slot in range(3):
				var base = Vector2(area.position.x + area.size.x * (0.22 + slot * 0.28), mine_y - 16)
				var height = 26.0 * rise
				c.draw_rect(Rect2(base - Vector2(46, height), Vector2(92, height)), CERAMIC, true)
				if height > 3:
					c.draw_rect(Rect2(base - Vector2(46, height), Vector2(92, 3)), color, true)
			# One shot rebounds off a slab, another threads the gap between two.
			var bounce_at = Vector2(area.position.x + area.size.x * 0.22, mine_y - 44)
			if u <= 0.5:
				demo_ball(c, their_pilot.lerp(bounce_at, u / 0.5), CORAL, 5.0)
			else:
				demo_ball(c, bounce_at.lerp(their_pilot + Vector2(40, 0), (u - 0.5) / 0.5), CORAL, 5.0)
			var gap = Vector2(area.position.x + area.size.x * 0.365, mine_y - 4)
			demo_ball(c, their_pilot.lerp(gap, minf(u / 0.8, 1.0)), Color(CORAL, 0.75), 4.5)
		"sun_ray":
			var lit = int(clampf((u - 0.25) / 0.2, 0, 3))
			demo_bricks(c, area, CORAL, enemy_y, [3, 4, 5].slice(0, lit))
			demo_bricks(c, area, CYAN, mine_y)
			if u > 0.2:
				# A column so wide it covers four bricks, running past the top edge.
				var beam_x = demo_brick_row(area, 4, true).x
				var fade = clampf((1.0 - u) / 0.3, 0, 1)
				c.draw_rect(Rect2(Vector2(beam_x - 46, frame.position.y - 10), Vector2(92, my_pilot.y - frame.position.y + 10)), Color(color, 0.22 * fade), true)
				c.draw_rect(Rect2(Vector2(beam_x - 26, frame.position.y - 10), Vector2(52, my_pilot.y - frame.position.y + 10)), Color(color, 0.75 * fade), true)
		"meteors":
			var fallen = int(clampf(u / 0.75 * 4, 0, 4))
			demo_bricks(c, area, CORAL, enemy_y, [1, 3, 5, 7].slice(0, fallen))
			demo_bricks(c, area, CYAN, mine_y)
			for i in range(4):
				var land = demo_brick_row(area, [1, 3, 5, 7][i], true)
				var start = land - Vector2(26, 120)
				var travel = clampf((u - i * 0.16) / 0.3, 0, 1)
				if travel <= 0:
					continue
				var rock = Color("ffd76b") if i % 2 == 0 else color
				if travel < 1:
					demo_ball(c, start.lerp(land, travel), rock, 6.0)
					c.draw_line(start.lerp(land, maxf(travel - 0.18, 0)), start.lerp(land, travel), Color(rock, 0.45), 3.0, smooth)
				else:
					c.draw_arc(land, 6 + (u - i * 0.16 - 0.3) * 40, 0, TAU, 24, Color(rock, maxf(0.0, 1.0 - (u - i * 0.16 - 0.3) * 3)), 2.0, smooth)
		"thunder":
			var struck = int(clampf(u / 0.8 * 3, 0, 3))
			demo_bricks(c, area, CORAL, enemy_y, [2, 4, 6].slice(0, struck))
			demo_bricks(c, area, CYAN, mine_y)
			for i in range(3):
				var at = demo_brick_row(area, [2, 4, 6][i], true)
				var age = (u - i * 0.26) / 0.22
				if age < 0 or age > 1:
					continue
				var bolt = PackedVector2Array([Vector2(at.x, frame.position.y + 2), Vector2(at.x - 9, at.y - 34), Vector2(at.x + 6, at.y - 30), Vector2(at.x - 4, at.y)])
				c.draw_polyline(bolt, Color(color, 1.0 - age * 0.4), 3.0, smooth)
				c.draw_arc(at, 10 + age * 18, 0, TAU, 24, Color(color, 1.0 - age), 2.0, smooth)
		"bloom":
			demo_bricks(c, area, CORAL, enemy_y)
			demo_bricks(c, area, CYAN, mine_y)
			for i in range(9):
				var brick = demo_brick_row(area, i, false)
				var age = (u - i * 0.05) / 0.5
				if age < 0 or age > 1:
					continue
				# Grown bricks and a +2 floating away.
				c.draw_rect(Rect2(brick - Vector2(15, 8.5), Vector2(30, 17)), Color(color, 0.5 * (1.0 - age)), true)
				c.draw_arc(brick, 10 + age * 12, 0, TAU, 20, Color(color, 1.0 - age), 2.0, smooth)
				if i % 2 == 0:
					c.draw_string(font_bold, brick + Vector2(-8, -16 - age * 18), "+2", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(color, 1.0 - age))
		"singularity":
			demo_bricks(c, area, CORAL, enemy_y, [2, 3, 4, 5, 6] if u > 0.84 else [])
			demo_bricks(c, area, CYAN, mine_y)
			if u < 0.62:
				# Three waves sweep in from beyond the arena, each one collecting whatever
				# it washes over; the core swells as it eats.
				var draw_in = u / 0.62
				for wave in range(3):
					var span = 1.0 - fmod(draw_in * 3.0 - wave * 0.02, 1.0)
					if span < 0 or span > 1:
						continue
					c.draw_arc(my_pilot, 30 + span * 150.0, 0, TAU, 44, Color(color, 0.7 * (1.0 - span * 0.5)), 2.4, smooth)
				for i in range(5):
					var from = [Vector2(-52, -34), Vector2(40, -18), Vector2(-28, 22), Vector2(48, 28), Vector2(4, -44)][i]
					var caught = clampf((draw_in - i * 0.06) / 0.7, 0, 1)
					demo_ball(c, my_pilot + from * (1.0 - ease(caught, 2.4)), CORAL if i % 2 == 0 else CYAN, 5.0)
				c.draw_circle(my_pilot, 4.0 + draw_in * 6.0, Color(0.02, 0.03, 0.05, 1.0), true, -1, smooth)
				c.draw_arc(my_pilot, 4.5 + draw_in * 6.0, 0, TAU, 26, color, 2.0, smooth)
			else:
				# The release: a wide fan of turbocharged rounds across the whole arena.
				var out = (u - 0.62) / 0.38
				for i in range(13):
					var spread = lerpf(-1.35, 1.35, i / 12.0)
					var course = Vector2(sin(spread), -cos(spread))
					var flying = my_pilot + course * out * 108.0
					c.draw_line(flying - course * 18.0, flying, Color(color, 0.45), 2.4, smooth)
					demo_ball(c, flying, color, 5.5)
				c.draw_arc(my_pilot, out * 70.0, 0, TAU, 36, Color(color, 1.0 - out), 2.8, smooth)
		"sentries":
			var fallen: Array = []
			if u > 0.55:
				fallen = [3, 5]
			if u > 0.8:
				fallen = [2, 3, 5, 6]
			demo_bricks(c, area, CORAL, enemy_y, fallen)
			demo_bricks(c, area, CYAN, mine_y)
			# Two platforms in the middle of the ring, firing up the field.
			for side in [-1, 1]:
				var post = area.get_center() + Vector2(side * 46, 0)
				var arrival = clampf(u / 0.16, 0, 1)
				c.draw_circle(post, 11.0 * arrival, Color(color, 0.25), true, -1, smooth)
				c.draw_circle(post, 7.0 * arrival, color, true, -1, smooth)
				c.draw_circle(post, 3.0 * arrival, Color(INK, 0.8), true, -1, smooth)
				if arrival >= 1:
					# Five pips of health, and a round on its way to the wall.
					for pip in range(Rules.TURRET_LIVES):
						var lost = 1 if side < 0 and u > 0.7 else 0
						c.draw_circle(post + Vector2(-5 + pip * 6, 13), 2.0, Color(color, 0.35 if pip >= Rules.TURRET_LIVES - lost else 1.0), true, -1, smooth)
					var travel = fmod(u * 3.4 + (0.5 if side > 0 else 0.0), 1.0)
					var aim = demo_brick_row(area, 3 if side < 0 else 6, true)
					demo_ball(c, post.lerp(aim, travel), color, 4.5)
					c.draw_line(post, post.lerp(aim, 0.16), Color(color, 0.8), 3.0, smooth)
		"plunder":
			# The two walls trade places: each side slides across to the other.
			var slide = clampf((u - 0.15) / 0.55, 0, 1)
			var mine_at = lerpf(mine_y, enemy_y, slide)
			var theirs_at = lerpf(enemy_y, mine_y, slide)
			demo_bricks(c, area, CORAL, theirs_at, [1, 4, 7])
			demo_bricks(c, area, CYAN, mine_at)
			if slide > 0 and slide < 1:
				c.draw_line(Vector2(area.position.x, area.get_center().y), Vector2(area.end.x, area.get_center().y), Color(color, 0.8), 2.0, smooth)
		"weld":
			# Half the wall comes back up to full as the seam runs across it.
			demo_bricks(c, area, CORAL, enemy_y)
			demo_bricks(c, area, CYAN if u > 0.45 else Color(CYAN, 0.45), mine_y)
			if u > 0.2 and u < 0.75:
				var seam = lerpf(area.position.x + 10, area.end.x - 10, (u - 0.2) / 0.55)
				c.draw_line(Vector2(seam, mine_y - 12), Vector2(seam, mine_y + 12), Color(color, 0.9), 3.0, smooth)
			centered_on(c, "+1 EM CADA TIJOLO TOCADO", Vector2(area.get_center().x, mine_y + 34), 11, color)
		"thorns":
			demo_bricks(c, area, CORAL, enemy_y)
			demo_bricks(c, area, CYAN, mine_y, [4] if u > 0.55 else [])
			var spike_y = mine_y - 16
			for step in range(7):
				var root_x = lerpf(area.position.x + 24, area.end.x - 24, step / 6.0)
				c.draw_polyline(PackedVector2Array([Vector2(root_x - 4, spike_y + 8), Vector2(root_x, spike_y - 6), Vector2(root_x + 4, spike_y + 8)]), Color(color, 0.85), 2.0, smooth)
			if u > 0.55:
				c.draw_circle(their_pilot, 12, Color(color, 0.35), true, -1, smooth)
				centered_on(c, "-1", their_pilot + Vector2(0, -18), 14, color)
		"freeze":
			demo_bricks(c, area, CORAL, enemy_y)
			demo_bricks(c, area, CYAN, mine_y)
			if u > 0.25:
				c.draw_circle(their_pilot, 20, Color(color, 0.22), true, -1, smooth)
				for step in range(3):
					var arm = step * PI / 3.0 + u * 0.6
					var reach = Vector2(cos(arm), sin(arm)) * 15.0
					c.draw_line(their_pilot - reach, their_pilot + reach, Color(color, 0.8), 2.0, smooth)
				centered_on(c, "METADE DA VELOCIDADE · DOBRO DA PAUSA", Vector2(area.get_center().x, enemy_y - 26), 11, color)
		"magnet":
			demo_bricks(c, area, CORAL, enemy_y, [2] if u > 0.82 else [])
			demo_bricks(c, area, CYAN, mine_y)
			# A round that would have missed, bending onto the brick it passes.
			var bend = PackedVector2Array()
			for step in range(13):
				var t = minf(u * 1.25, 1.0) * step / 12.0
				var straight = my_pilot.lerp(Vector2(area.position.x + 34, enemy_y - 14), t)
				var onto = my_pilot.lerp(demo_brick_at(area, enemy_y, 2), t)
				bend.append(straight.lerp(onto, t * t))
			if bend.size() > 1:
				c.draw_polyline(bend, Color(color, 0.9), 2.6, smooth)
		"pierce":
			# One round, straight through three bricks in a line.
			var broken: Array = []
			for step in range(3):
				if u > 0.3 + step * 0.16:
					broken.append(3 + step)
			demo_bricks(c, area, CORAL, enemy_y, broken)
			demo_bricks(c, area, CYAN, mine_y)
			var tip = my_pilot.lerp(Vector2(area.get_center().x + 14, area.position.y + 8), minf(u * 1.4, 1.0))
			c.draw_line(my_pilot, tip, Color(color, 0.85), 2.8, smooth)
			c.draw_circle(tip, 4.0, color, true, -1, smooth)
		"stun":
			demo_bricks(c, area, CORAL, enemy_y)
			demo_bricks(c, area, CYAN, mine_y)
			dazed = u > 0.22
			if u <= 0.22:
				demo_ball(c, their_pilot.lerp(my_pilot, 0.35 + u), CORAL, 5.0)
				demo_ball(c, my_pilot.lerp(their_pilot, 0.2 + u * 1.4), CYAN, 5.0)
			var wave = clampf(u / 0.45, 0, 1)
			if u < 0.5:
				c.draw_arc(my_pilot, 8 + wave * 210, 0, TAU, 64, Color(color, 1.0 - wave), 3.4, smooth)
		_:
			demo_bricks(c, area, CORAL, enemy_y)
			demo_bricks(c, area, CYAN, mine_y)
	demo_pilot(c, their_pilot, CORAL, dazed)
	demo_pilot(c, my_pilot, CYAN)
	c.draw_string(font_bold, Vector2(area.position.x + 4, area.end.y - 2), "DEMONSTRAÇÃO", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(MUTED, 0.75))

func centered_on(c: CanvasItem, text: String, at: Vector2, font_size: int, color: Color) -> void:
	var width = font_bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	c.draw_string(font_bold, at - Vector2(width * 0.5, -font_size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func open_powers() -> void:
	reset_touch()
	powers_overlay.show()
	refresh_powers()

func close_powers() -> void:
	powers_overlay.hide()

func build_levels_menu() -> void:
	levels_overlay = ColorRect.new()
	levels_overlay.color = Color(0.015, 0.035, 0.045, 0.94)
	levels_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(levels_overlay)
	levels_panel = PanelContainer.new()
	levels_panel.add_theme_stylebox_override("panel", style(Color("122b32"), Color("496563"), 24))
	levels_overlay.add_child(levels_panel)
	var list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	levels_panel.add_child(list)
	var header = HBoxContainer.new()
	list.add_child(header)
	var titles = VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	titles.add_child(label("CAMPANHA", 25, WHITE, true))
	titles.add_child(label("Uma arena, um desafio e um boss por nível.", 14, MUTED))
	levels_progress = label("", 13, CYAN, true)
	levels_progress.size_flags_vertical = Control.SIZE_SHRINK_END
	header.add_child(levels_progress)
	levels_grid = GridContainer.new()
	levels_grid.add_theme_constant_override("h_separation", 10)
	levels_grid.add_theme_constant_override("v_separation", 10)
	list.add_child(levels_grid)
	for index in range(Campaign.LEVELS.size()):
		var card = Button.new()
		card.focus_mode = Control.FOCUS_NONE
		card.add_theme_stylebox_override("normal", style(Color("183840"), Color("334f51"), 16))
		card.add_theme_stylebox_override("hover", style(Color("1f444c"), Color("496563"), 16))
		card.add_theme_stylebox_override("pressed", style(Color("1f444c"), LIME, 16))
		levels_grid.add_child(card)
		var face = Control.new()
		face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.draw.connect(func(): draw_level_card(face, index))
		card.add_child(face)
		card.pressed.connect(func(): choose_level(index))
		level_cards.append(card)
	var leave = make_button("VOLTAR", false)
	list.add_child(leave)
	leave.pressed.connect(close_levels)
	levels_overlay.hide()

func draw_level_card(canvas: Control, index: int) -> void:
	var level: Dictionary = Campaign.LEVELS[index]
	var open = campaign_state != null and campaign_state.is_unlocked(index)
	var done = campaign_state != null and campaign_state.is_completed(index)
	# Wide strips in portrait (avatar on the left), tall tiles in landscape (avatar on top).
	var wide = canvas.size.x > canvas.size.y * 1.6
	var beaten = skins_progress != null and skins_progress.is_unlocked(level.boss)
	portrait(Vector2(56, canvas.size.y * 0.5) if wide else Vector2(canvas.size.x * 0.5, 56), CORAL, false, level.boss, canvas, not beaten)
	var at = Vector2(116, 34) if wide else Vector2(12, 122)
	var status = level.tag
	if done:
		status = "✓ " + level.tag
	elif not open:
		status = "BLOQUEADO"
	canvas.draw_string(font_bold, at, "NÍVEL %02d" % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, LIME if done else CYAN)
	canvas.draw_string(font_bold, at + Vector2(0, 22 if wide else 19), level.name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15 if wide else 12, WHITE)
	canvas.draw_string(font, at + Vector2(0, 44 if wide else 37), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 12 if wide else 10, LIME if done else MUTED)
	if not open:
		canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), Color(0.02, 0.05, 0.06, 0.55))

func choose_level(index: int) -> void:
	if campaign_state == null or not campaign_state.is_unlocked(index):
		return
	close_levels()
	level_selected.emit(index)

func sync_menu_level(index: int) -> void:
	menu_level = clampi(index, 0, Campaign.LEVELS.size() - 1)
	refresh_menu_level()

func refresh_menu_level() -> void:
	var open = campaign_state == null or campaign_state.is_unlocked(menu_level)
	campaign_button.text = ("JOGAR NÍVEL %d  →" % (menu_level + 1)) if open else ("NÍVEL %d BLOQUEADO" % (menu_level + 1))
	campaign_button.disabled = not open
	queue_redraw()

func menu_overlay_open() -> bool:
	return video_overlay.visible or skins_overlay.visible or pvp_overlay.visible or levels_overlay.visible or powers_overlay.visible

func swipe_area() -> Rect2:
	# Portrait: the stadium band above the menu. Landscape: everything right of the panel.
	if vertical:
		return arena_rect
	var left = menu.get_rect().end.x + 20
	return Rect2(left, 0, size.x - left, size.y)

func menu_swipe(event: InputEvent) -> void:
	if menu_overlay_open():
		swipe_start = Vector2.INF
		return
	var pressed: bool
	var at: Vector2
	if event is InputEventScreenTouch and event.index == 0:
		pressed = event.pressed
		at = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		# A real mouse drags the same way; touch already arrives as a screen touch.
		pressed = event.pressed
		at = event.position
	else:
		return
	if pressed:
		swipe_start = at if swipe_area().has_point(at) else Vector2.INF
	elif swipe_start != Vector2.INF:
		var travel = at - swipe_start
		swipe_start = Vector2.INF
		# Mostly sideways and long enough: a tap or a vertical scroll never changes level.
		if absf(travel.x) >= SWIPE_DISTANCE and absf(travel.x) > absf(travel.y) * 1.5:
			menu_level_changed.emit(1 if travel.x < 0 else -1)

func draw_menu_level() -> void:
	if campaign_state == null:
		return
	var level: Dictionary = Campaign.LEVELS[menu_level]
	var total = Campaign.LEVELS.size()
	var open = campaign_state.is_unlocked(menu_level)
	var done = campaign_state.is_completed(menu_level)
	var area = swipe_area()
	var center_x = area.get_center().x
	var top = (safe_top + 92) if vertical else 34.0
	var beaten: bool = skins_progress != null and int(level.boss) < Skins.CATALOG.size() and skins_progress.is_unlocked(level.boss)
	centered("NÍVEL %02d / %02d" % [menu_level + 1, total], Vector2(center_x, top + 14), 12, LIME if done else CYAN, true)
	centered(level.name.to_upper(), Vector2(center_x, top + 42), 26, WHITE, true)
	var line = level.challenge if open else "BLOQUEADO · vence o nível anterior"
	centered(("✓  " if done else "") + line, Vector2(center_x, top + 64), 12, LIME if done else MUTED)
	var dots_y = (menu.position.y - 26) if vertical else size.y - 30.0
	# The boss of the previewed level, in its fighting red until it has been beaten: in the
	# empty band over the menu on a phone, in the gap above the panel on a wide screen.
	var boss_at = Vector2(center_x, dots_y - 132) if vertical else Vector2(menu.position.x + menu.size.x * 0.5, maxf(menu.position.y - 128, 150.0))
	# A station pilot has no entry in the skins catalogue: it wears a hull numbered past the
	# end of it and answers to the level's own name.
	var station: bool = int(level.boss) >= 100
	var rival_hue: Color = Color(String(level.hue)) if level.has("hue") else CORAL
	draw_circle(boss_at + Vector2(0, 4), 52, Color(INK, 0.55), true, -1, smooth)
	portrait(boss_at, rival_hue if station else CORAL, false, level.boss, null, station or not beaten)
	draw_arc(boss_at, 53, 0, TAU, 56, Color(BRASS, 0.5), 1.4, smooth)
	draw_arc(boss_at, 53, -PI * 0.78, -PI * 0.22, 20, Color(CERAMIC, 0.35), 1.6, smooth)
	centered("POSTO" if station else "BOSS", boss_at + Vector2(0, 74), 9, MUTED, true)
	var rival_label: String = String(level.name).to_upper() if station else String(Skins.CATALOG[level.boss].name)
	centered(rival_label, boss_at + Vector2(0, 93), 15, rival_hue if station else (WHITE if beaten else CORAL), true)
	for i in range(total):
		var dot = Vector2(center_x + (i - (total - 1) * 0.5) * 18, dots_y)
		if i == menu_level:
			draw_circle(dot, 5, LIME, true, -1, smooth)
		else:
			draw_circle(dot, 3.5, Color(WHITE, 0.55) if campaign_state.is_unlocked(i) else Color(WHITE, 0.18), true, -1, smooth)
	# Chevrons at the sides hint that the stadium can be swiped.
	var hint_y = area.get_center().y + (20 if vertical else 0)
	var reach = minf(area.size.x * 0.5 - 22, 330) if vertical else area.size.x * 0.5 - 22
	for step in [-1, 1]:
		var target = menu_level + step
		if target < 0 or target >= total:
			continue
		var tip = Vector2(center_x + step * reach, hint_y)
		draw_polyline(PackedVector2Array([tip + Vector2(-step * 14, -22), tip, tip + Vector2(-step * 14, 22)]), Color(WHITE, 0.55), 4, smooth)

func open_levels() -> void:
	reset_touch()
	levels_overlay.show()
	for card in level_cards:
		card.get_child(0).queue_redraw()

func close_levels() -> void:
	levels_overlay.hide()

func sync_campaign(campaign) -> void:
	campaign_state = campaign
	var total = Campaign.LEVELS.size()
	refresh_menu_level()
	levels_progress.text = "%d/%d CONCLUÍDOS" % [campaign.completed.size(), total]
	for card in level_cards:
		card.get_child(0).queue_redraw()

func build_video_menu() -> void:
	video_button = make_button("OPÇÕES", false)
	add_child(video_button)
	video_button.pressed.connect(open_video)
	fps_label = label("", 12, CYAN, true)
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fps_label)
	video_overlay = ColorRect.new()
	video_overlay.color = Color(0.015, 0.035, 0.045, 0.88)
	video_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(video_overlay)
	video_panel = PanelContainer.new()
	video_panel.add_theme_stylebox_override("panel", style(Color("122b32"), Color("496563"), 24))
	video_overlay.add_child(video_panel)
	var list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	options_scroll = ScrollContainer.new()
	options_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var option_stack = VBoxContainer.new()
	option_stack.add_theme_constant_override("separation", 12)
	video_panel.add_child(option_stack)
	option_stack.add_child(options_scroll)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_scroll.add_child(list)
	list.add_child(label("OPÇÕES", 25, WHITE, true))
	list.add_child(label("Imagem, som e ajudas de jogo.", 15, MUTED))
	cup_difficulty = video_option(list, "Dificuldade da IA", ["Fácil", "Normal", "Difícil"])
	cup_difficulty.item_selected.connect(func(index): difficulty_changed.emit(index))
	quality_choice = video_option(list, "Qualidade", ["Leve · desempenho móvel", "Equilibrado · mais definição", "Refinado · máxima suavização"])
	fps_choice = video_option(list, "Limite de FPS", ["30 FPS", "60 FPS", "90 FPS"])
	sync_choice = CheckButton.new()
	sync_choice.text = "Sincronizar com o ecrã (VSync)"
	sync_choice.custom_minimum_size.y = 44
	list.add_child(sync_choice)
	counter_choice = CheckButton.new()
	counter_choice.text = "Mostrar FPS reais"
	counter_choice.custom_minimum_size.y = 44
	list.add_child(counter_choice)
	guide_choice = CheckButton.new()
	guide_choice.text = "Guia de mira (percurso do disparo)"
	guide_choice.custom_minimum_size.y = 44
	list.add_child(guide_choice)
	guide_choice.toggled.connect(func(value): guide_changed.emit(value))
	sensitivity_choice = video_option(list, "Sensibilidade", ["Muito lenta", "Lenta", "Normal", "Rápida", "Muito rápida"])
	sensitivity_choice.item_selected.connect(func(index): sensitivity_changed.emit(index))
	music_choice = CheckButton.new()
	music_choice.text = "Música de fundo"
	music_choice.custom_minimum_size.y = 44
	list.add_child(music_choice)
	music_volume = volume_slider(list, "Volume")
	video_note = label("", 14, MUTED)
	video_note.custom_minimum_size = Vector2(470, 63)
	video_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(video_note)
	var done = make_button("FECHAR OPÇÕES", true)
	option_stack.add_child(done)
	done.pressed.connect(close_video)
	quality_choice.item_selected.connect(func(_index): emit_video())
	fps_choice.item_selected.connect(func(_index): emit_video())
	sync_choice.toggled.connect(func(_value): emit_video())
	counter_choice.toggled.connect(func(_value): emit_video())
	music_choice.toggled.connect(func(_value): emit_audio())
	music_volume.value_changed.connect(func(_value): emit_audio())
	video_overlay.hide()

func video_option(parent: VBoxContainer, title: String, options: Array) -> OptionButton:
	var row = HBoxContainer.new()
	parent.add_child(row)
	var caption = label(title, 15, WHITE)
	caption.custom_minimum_size.x = 132
	row.add_child(caption)
	var option = OptionButton.new()
	option.custom_minimum_size = Vector2(328, 48)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.add_theme_font_size_override("font_size", 14)
	option.add_theme_stylebox_override("normal", style(Color("203b41"), Color("496563")))
	option.add_theme_color_override("font_color", WHITE)
	for text in options:
		option.add_item(text)
	row.add_child(option)
	return option

func volume_slider(parent: VBoxContainer, title: String) -> HSlider:
	var row = HBoxContainer.new()
	parent.add_child(row)
	var caption = label(title, 15, WHITE)
	caption.custom_minimum_size.x = 132
	row.add_child(caption)
	var slider = HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.custom_minimum_size = Vector2(328, 48)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for part in [["slider", Color("203b41")], ["grabber_area", LIME], ["grabber_area_highlight", LIME.lightened(0.1)]]:
		var bar = StyleBoxFlat.new()
		bar.bg_color = part[1]
		bar.set_corner_radius_all(4)
		bar.content_margin_top = 4
		bar.content_margin_bottom = 4
		slider.add_theme_stylebox_override(part[0], bar)
	row.add_child(slider)
	return slider

func sync_game(settings) -> void:
	if is_instance_valid(cup_difficulty):
		cup_difficulty.selected = settings.difficulty
	for level in range(difficulty_buttons.size()):
		difficulty_buttons[level].set_pressed_no_signal(level == settings.difficulty)
	guide_choice.set_pressed_no_signal(settings.aim_guide)
	if is_instance_valid(sensitivity_choice):
		sensitivity_choice.select(settings.joystick_sensitivity)

func sync_audio(settings) -> void:
	music_choice.set_pressed_no_signal(settings.enabled)
	music_volume.set_value_no_signal(roundi(settings.volume * 100))
	music_volume.editable = settings.enabled

func emit_audio() -> void:
	music_volume.editable = music_choice.button_pressed
	audio_changed.emit(music_choice.button_pressed, music_volume.value / 100.0)

func sync_video(settings) -> void:
	fps_choice.select([30, 60, 90].find(settings.fps))
	quality_choice.select(settings.quality)
	sync_choice.set_pressed_no_signal(settings.vsync)
	counter_choice.set_pressed_no_signal(settings.show_fps)
	fps_label.visible = settings.show_fps
	video_note.text = "Refinado e Equilibrado preservam os gráficos e reduzem apenas 90→60→30 FPS. Só o perfil Leve pode baixar a resolução 3D."

func emit_video() -> void:
	video_changed.emit([30, 60, 90][fps_choice.selected], quality_choice.selected, sync_choice.button_pressed, counter_choice.button_pressed)

func open_video() -> void:
	reset_touch()
	video_overlay.show()
	video_opened.emit()

func close_video() -> void:
	reset_touch()
	video_overlay.hide()

func layout() -> void:
	if not is_instance_valid(menu):
		return
	vertical = size.y > size.x
	var insets = safe_insets() if vertical else Vector2.ZERO
	safe_top = insets.x
	safe_bottom = insets.y
	if vertical:
		video_button.custom_minimum_size.y = 36
		video_button.add_theme_font_size_override("font_size", 13)
		video_button.position = Vector2(size.x - 198, safe_top + 8)
		video_button.size = Vector2(92, 36)
		back.custom_minimum_size.y = 36
		back.add_theme_font_size_override("font_size", 13)
		back.position = Vector2(size.x - 100, safe_top + 8)
		back.size = Vector2(92, 36)
	else:
		video_button.custom_minimum_size.y = 46
		video_button.add_theme_font_size_override("font_size", 17)
		video_button.position = Vector2(size.x - 242, 27 + safe_top)
		video_button.size = Vector2(100, 46)
		back.custom_minimum_size.y = 46
		back.add_theme_font_size_override("font_size", 17)
		back.position = Vector2(size.x - 130, 27 + safe_top)
		back.size = Vector2(100, 46)
	skins_body.vertical = size.y > size.x
	var skin_room = size.y - safe_top - safe_bottom - 48
	viewer.custom_minimum_size = Vector2(0, clampf(skin_room * 0.42, 300, 520)) if skins_body.vertical else Vector2(480, maxf(240, skin_room - 380))
	viewer_column.custom_minimum_size.x = 0 if skins_body.vertical else 480
	skins_scroll.custom_minimum_size.y = maxf(120, skin_room - viewer.custom_minimum_size.y - 560) if skins_body.vertical else maxf(200, skin_room - 430)
	var skins_size = Vector2(minf(size.x - 48, 680 if skins_body.vertical else 1140), skin_room)
	skins_panel.size = skins_size
	skins_panel.position = Vector2((size.x - skins_size.x)*0.5, safe_top + 24)
	options_scroll.custom_minimum_size = Vector2(510, minf(700, size.y - safe_top - safe_bottom - 184))
	var panel_size = video_panel.get_combined_minimum_size().max(Vector2(510, 0))
	video_panel.size = panel_size
	video_panel.position = (size - panel_size) * 0.5
	if is_instance_valid(pause_panel):
		pause_panel.size = pause_panel.get_combined_minimum_size().max(Vector2(420, 0))
		pause_panel.position = (size - pause_panel.size) * 0.5
	# No stick any more: the pilot walks to whatever you point at. Under the right hand
	# sit the two arrows that step from target to target; the power keys stay on the left.
	move_home = Vector2(size.x * (0.70 if vertical else 0.88), size.y - safe_bottom - (132 if vertical else 139))
	move_center = move_home
	var menu_height = menu.get_combined_minimum_size().y
	levels_grid.columns = 2 if vertical else 5
	var levels_width = minf(size.x - 48, 660)
	for card in level_cards:
		card.custom_minimum_size = Vector2((levels_width - 46) * 0.5, 104) if vertical else Vector2(164, 172)
	levels_panel.size = levels_panel.get_combined_minimum_size().max(Vector2(levels_width if vertical else 0.0, 0))
	levels_panel.position = thumb_panel_position(levels_panel.size)
	pvp_panel.size = pvp_panel.get_combined_minimum_size().max(Vector2(minf(size.x - 48, 520), 0))
	pvp_panel.position = thumb_panel_position(pvp_panel.size)
	var shop_scroll: ScrollContainer = powers_panel.get_child(0).get_child(1)
	var shop_grid: GridContainer = shop_scroll.get_child(0)
	shop_grid.columns = 2 if vertical else 3
	if is_instance_valid(power_actions):
		power_actions.columns = 2 if vertical else 4
	# Leave room for the header, the demonstration, the description and the buttons.
	shop_scroll.custom_minimum_size.y = clampf(size.y - (620 if vertical else 500), 190, 430)
	powers_detail.custom_minimum_size.x = minf(size.x - 96, 600)
	power_demo.custom_minimum_size = Vector2(minf(size.x - 96, 600), 178 if vertical else 196)
	powers_panel.size = powers_panel.get_combined_minimum_size().max(Vector2(minf(size.x - 48, 640) if vertical else 0.0, 0))
	powers_panel.position = thumb_panel_position(powers_panel.size)
	if vertical:
		layout_vertical(menu_height)
	else:
		menu.size = Vector2(450, menu_height)
		menu.position = Vector2(48, maxf(76, size.y - menu.size.y - 40))
		fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		fps_label.size = Vector2.ZERO
		# In a match the stick and its caption own the bottom right corner, so the counter
		# takes the left one, which is where the arena name sits on the menu.
		fps_label.position = Vector2(size.x - 260, size.y - 53) if mode == "menu" else Vector2(34, size.y - 42)
		score_rect = Rect2(size.x * 0.5 - 152, 19, 304, 59)
		card_rects = [Rect2(38, 184, 200, 222), Rect2(size.x - 238, 184, 200, 222)]
		message_center = size * 0.5
		arena_rect = Rect2(Vector2.ZERO, size)
		touch_top = size.y * 0.42
	# Powers: a row between the thumb controls on a phone, where the band under the arena is
	# free; on a wide screen that band is the stadium itself, so they take the pocket under
	# your own card, clear of the arena on the right and of the movement stick below.
	# Laid out end to end from their own sizes, so the bigger ultimate key cannot land on
	# top of its neighbour or walk into the stick.
	var reach: float = (16.0 if vertical else card_rects[0].position.x + 8.0)
	var row_y: float = move_home.y if vertical else card_rects[0].end.y + 62
	for index in range(power_centers.size()):
		var button: float = power_button_radius(index)
		reach += button
		power_centers[index] = Vector2(reach, row_y)
		reach += button + 14.0
	for result_button in [next_button, replay, levels_button]:
		result_button.size = Vector2(260, 50)
	place_result_buttons()
	queue_redraw()
	layout_changed.emit()

func layout_vertical(menu_height: float) -> void:
	var mid = size.x * 0.5
	var bottom = size.y - safe_bottom
	score_rect = Rect2(mid - 152, safe_top + 86, 304, 59)
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if mode == "menu" else HORIZONTAL_ALIGNMENT_LEFT
	fps_label.size = Vector2(240 if mode == "menu" else 128, 20)
	# The stick sits on the right of the band with its caption under it, so in a match the
	# counter takes the left corner instead of landing on top of them.
	fps_label.position = Vector2(mid - 120, bottom - 46) if mode == "menu" else Vector2(30, bottom - 26)
	menu.size = Vector2(minf(size.x - 48, 520), menu_height)
	menu.position = Vector2((size.x - menu.size.x) * 0.5, maxf(safe_top + 150, bottom - menu.size.y - 56))
	if mode == "menu":
		# The previewed level's name sits above its stadium, and under it come the boss card
		# and the page dots. The stadium stops above the boss: it used to be framed down to
		# the panel and drew straight over the face.
		var top = safe_top + 172
		arena_rect = Rect2(16, top, size.x - 32, maxf(menu.position.y - 221 - top, 120))
	else:
		# Top match info band sits comfortably below the header buttons (bar_y = safe_top + 48)
		var bar_y = safe_top + 48.0
		# Tall enough for a face you can actually see: the avatar is 40 across now.
		var card_h = 96.0
		var score_w = clampf(size.x * 0.25, 116.0, 150.0)
		score_rect = Rect2(mid - score_w * 0.5, bar_y, score_w, card_h)
		var card_w = maxf((size.x - score_w - 20.0) * 0.5, 110.0)
		var left_card = Rect2(8, bar_y, card_w, card_h)
		var right_card = Rect2(size.x - 8 - card_w, bar_y, card_w, card_h)
		card_rects = [left_card, right_card] if team == 0 else [right_card, left_card]
		var band_top = bar_y + card_h + 10.0
		# The stadium stops where the stick begins. Measured from the stick itself, because
		# a short screen pushes the two into each other and the field would cover the thumb.
		var band_bottom = move_home.y - STICK_RADIUS - 10.0
		arena_rect = Rect2(10, band_top, size.x - 20, maxf(band_bottom - band_top, 120))
	message_center = arena_rect.get_center()
	touch_top = arena_rect.get_center().y
	if is_instance_valid(host_ai_button):
		host_ai_button.custom_minimum_size = Vector2(250, 52)
		host_ai_button.size = Vector2(250, 52)
		host_ai_button.position = message_center + Vector2(-125, 68)

func safe_insets() -> Vector2:
	# Camera cutouts on phones, converted to HUD units: x = top, y = bottom.
	if not OS.has_feature("mobile"):
		return Vector2.ZERO
	var screen = DisplayServer.window_get_size()
	var safe = DisplayServer.get_display_safe_area()
	if screen.y <= 0 or safe.size.y <= 0:
		return Vector2.ZERO
	return Vector2(maxf(0, safe.position.y), maxf(0, screen.y - safe.end.y)) * (size.y / screen.y)

func thumb_panel_position(panel_size: Vector2) -> Vector2:
	# On a tall phone, panels with a list of choices hang from the bottom, near the thumb.
	var centered_position = (size - panel_size) * 0.5
	if size.y <= size.x:
		return centered_position
	return Vector2(centered_position.x, maxf(safe_top + 20, size.y - safe_bottom - panel_size.y - 40))

func place_result_buttons() -> void:
	# Stack whichever end-of-match buttons are showing, under the result message.
	var row = 0
	for result_button in [next_button, replay, levels_button]:
		if result_button.visible:
			result_button.position = message_center + Vector2(-130, 80 + row * 58)
			row += 1

func show_menu(message: String = "") -> void:
	show_pause(false)
	menu.show()
	back.hide()
	video_button.hide()
	video_overlay.hide()
	skins_overlay.hide()
	pvp_overlay.hide()
	replay.hide()
	next_button.hide()
	levels_button.hide()
	host_ai_button.hide()
	mode = "menu"
	reset_touch()
	if message != "":
		menu_status.text = message
	layout()

func show_game(new_mode: String, local_team: int) -> void:
	show_pause(false)
	skins_overlay.hide()
	pvp_overlay.hide()
	levels_overlay.hide()
	unlock_timer = 0.0
	back.text = "PAUSA" if new_mode == "pve" else "MENU"
	mode = new_mode
	team = local_team
	menu.hide()
	back.show()
	video_button.show()
	host_ai_button.visible = (new_mode == "host")
	reset_touch()
	layout()

func reset_touch() -> void:
	touches.clear()
	move_id = -1
	move_vector = Vector2.ZERO
	move_vector = Vector2.ZERO
	move_center = move_home
	power_request = -1

func power_at(point: Vector2) -> int:
	for index in range(power_centers.size()):
		if point.distance_to(power_centers[index]) <= power_button_radius(index) + 8:
			return index
	return -1

func request_power(index: int) -> void:
	# Held until the next match tick reads it, so a tap is never lost between frames.
	if index < 0 or index >= power_centers.size():
		return
	power_request = index
	power_flash[index] = 0.22
	ask_redraw()

func take_power() -> int:
	var index = power_request
	power_request = -1
	return index

func _input(event: InputEvent) -> void:
	if mode == "menu":
		menu_swipe(event)
		return
	if video_overlay.visible or pause_overlay.visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			# Power buttons sit between the thumb controls, so they are tested first.
			var slot = power_at(event.position)
			if slot >= 0:
				request_power(slot)
				return
			if event.position.y < touch_top:
				return
			# The pilot fires by itself, so any press down here takes hold of the stick,
			# wherever the thumb lands.
			if move_id < 0:
				move_id = event.index
				move_center = event.position
		else:
			if event.index == move_id:
				move_id = -1
				move_vector = Vector2.ZERO
				move_center = move_home
	if event is InputEventScreenDrag and event.index == move_id:
		move_vector = ((event.position - move_center) / 44).limit_length()
	ask_redraw()

func write(text: String, pos: Vector2, font_size: int, color: Color, bold: bool = false) -> void:
	draw_string(font_bold if bold else font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func centered(text: String, pos: Vector2, font_size: int, color: Color, bold: bool = false) -> void:
	var f = font_bold if bold else font
	var width = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	write(text, pos - Vector2(width * 0.5, 0), font_size, color, bold)

func panel(rect: Rect2, color: Color = Color(0.05, 0.10, 0.12, 0.88)) -> void:
	draw_style_box(style(color, Color("334f51"), 18), rect)

func update_match(rules, status: String) -> void:
	# The HUD only reads display fields; no full network snapshot allocation per frame.
	match_data = {"players": rules.players, "bricks": rules.bricks, "scores": rules.scores, "phase": rules.phase, "timer": rules.timer, "winner": rules.winner, "powers": rules.powers, "loadouts": rules.loadouts}
	network_status = status
	if is_instance_valid(host_ai_button):
		host_ai_button.visible = (mode == "host" and network_status != "")
	var finished = mode != "menu" and rules.phase == "finished" and mode != "client"
	var in_campaign = not level_info.is_empty()
	replay.visible = finished
	replay.text = ("REPETIR NÍVEL" if level_result == "won" else "TENTAR DE NOVO") if in_campaign else "JOGAR NOVAMENTE"
	next_button.visible = finished and in_campaign and level_result == "won" and level_info.get("has_next", false)
	# Only one bright button at a time: replay steps back when a next level is offered.
	paint_button(replay, not next_button.visible)
	levels_button.visible = finished and in_campaign
	place_result_buttons()
	ask_redraw()

func pilot_hue(team: int, fallback: Color) -> Color:
	# The card shows the pilot in the colour it is actually flying in.
	return Color(String(team_hues[team])) if team < team_hues.size() and String(team_hues[team]) != "" else fallback

func portrait(center: Vector2, color: Color, stunned: bool, skin: int = 0, canvas: CanvasItem = null, tint: bool = false) -> void:
	# `canvas` lets the skins panel draw the same avatar inside its own preview controls.
	var c: CanvasItem = canvas if canvas != null else self
	c.draw_circle(center, 46, Color(color, 0.055), true, -1, smooth)
	c.draw_arc(center, 45, 0.2, TAU - 0.2, 64, Color(color, 0.28), 1.2, smooth)
	c.draw_style_box(style(color.darkened(0.3), Color.TRANSPARENT, 14), Rect2(center + Vector2(-24, 15), Vector2(48, 24)))
	var palette = Skins.colors(skin, color, tint)
	match skin:
		6:
			clockmaker_portrait(c, center, palette, stunned)
			return
		7:
			storm_portrait(c, center, palette, stunned)
			return
		8:
			alchemist_portrait(c, center, palette, stunned)
			return
		9:
			corsair_portrait(c, center, palette, stunned)
			return
		10:
			archon_portrait(c, center, palette, stunned)
			return
	if skin == 1:
		lighthouse_portrait(c, center, palette.light, stunned)
		return
	if skin == 2:
		astronomer_portrait(c, center, color, palette, stunned)
		return
	if skin == 3:
		gardener_portrait(c, center, palette, stunned)
		return
	if skin == 4:
		miner_portrait(c, center, palette, stunned)
		return
	if skin == 5:
		sentinel_portrait(c, center, palette, stunned)
		return
	c.draw_circle(center + Vector2(-31, -2), 9, Color("bda579"), true, -1, smooth)
	c.draw_circle(center + Vector2(31, -2), 9, Color("bda579"), true, -1, smooth)
	c.draw_style_box(style(WHITE, Color.TRANSPARENT, 22), Rect2(center + Vector2(-32, -29), Vector2(64, 55)))
	c.draw_style_box(style(INK, Color.TRANSPARENT, 12), Rect2(center + Vector2(-27, -10), Vector2(54, 24)))
	c.draw_style_box(style(color, Color.TRANSPARENT, 3), Rect2(center + Vector2(-4, -29), Vector2(8, 13)))
	for side in [-1, 1]:
		var p = center + Vector2(side * 12, 1)
		if stunned:
			c.draw_line(p - Vector2(3, 3), p + Vector2(3, 3), LIME, 2, smooth)
			c.draw_line(p - Vector2(-3, 3), p + Vector2(-3, 3), LIME, 2, smooth)
		else:
			c.draw_style_box(style(color.lightened(0.2), Color.TRANSPARENT, 2), Rect2(p - Vector2(2, 4), Vector2(4, 8)))

func lighthouse_portrait(c: CanvasItem, center: Vector2, glow: Color, stunned: bool) -> void:
	# Faroleiro: beacon gem on a brass mast, side lamps, tall dome, brass band and one visor slit.
	var brass = Color("d2ad73")
	c.draw_line(center + Vector2(0, -31), center + Vector2(0, -41), brass, 3, smooth)
	c.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -50), center + Vector2(6, -43), center + Vector2(0, -36), center + Vector2(-6, -43)]), brass.lightened(0.15))
	for side in [-1, 1]:
		c.draw_circle(center + Vector2(side * 31, -2), 9, brass, true, -1, smooth)
		c.draw_circle(center + Vector2(side * 32, -2), 4.5, glow, true, -1, smooth)
	c.draw_style_box(style(WHITE, Color.TRANSPARENT, 28), Rect2(center + Vector2(-30, -35), Vector2(60, 61)))
	c.draw_style_box(style(brass, Color.TRANSPARENT, 2), Rect2(center + Vector2(-31, 13), Vector2(62, 5)))
	c.draw_style_box(style(INK, Color.TRANSPARENT, 9), Rect2(center + Vector2(-26, -9), Vector2(52, 19)))
	if stunned:
		for side in [-1, 1]:
			var p = center + Vector2(side * 12, 0)
			c.draw_line(p - Vector2(3, 3), p + Vector2(3, 3), LIME, 2, smooth)
			c.draw_line(p - Vector2(-3, 3), p + Vector2(-3, 3), LIME, 2, smooth)
	else:
		c.draw_style_box(style(glow, Color.TRANSPARENT, 2), Rect2(center + Vector2(-17, -2), Vector2(34, 4)))

func orbit_points(center: Vector2, from_angle: float, to_angle: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(25):
		var t = lerpf(from_angle, to_angle, i / 24.0)
		points.append(center + Vector2(cos(t) * 45, sin(t) * 11).rotated(-0.28))
	return points

func astronomer_portrait(c: CanvasItem, center: Vector2, team_color: Color, palette: Dictionary, stunned: bool) -> void:
	# Astrónomo: indigo collar, tilted orbit passing behind and in front of the helmet, monocle.
	var brass = Color("d2ad73")
	var glow: Color = palette.light
	var orbit_center = center + Vector2(0, -8)
	c.draw_style_box(style(palette.body, Color.TRANSPARENT, 14), Rect2(center + Vector2(-24, 15), Vector2(48, 24)))
	c.draw_polyline(orbit_points(orbit_center, PI, TAU), brass, 2, smooth)
	for side in [-1, 1]:
		c.draw_circle(center + Vector2(side * 31, -2), 9, palette.body.lightened(0.1), true, -1, smooth)
	c.draw_style_box(style(WHITE, Color.TRANSPARENT, 22), Rect2(center + Vector2(-32, -29), Vector2(64, 55)))
	c.draw_style_box(style(INK, Color.TRANSPARENT, 12), Rect2(center + Vector2(-27, -10), Vector2(54, 24)))
	c.draw_circle(center + Vector2(13, 1), 8, brass, true, -1, smooth)
	if stunned:
		for p in [center + Vector2(-12, 1), center + Vector2(13, 1)]:
			c.draw_line(p - Vector2(3, 3), p + Vector2(3, 3), LIME, 2, smooth)
			c.draw_line(p - Vector2(-3, 3), p + Vector2(-3, 3), LIME, 2, smooth)
	else:
		c.draw_style_box(style(glow, Color.TRANSPARENT, 2), Rect2(center + Vector2(-14, -3), Vector2(4, 8)))
		c.draw_circle(center + Vector2(13, 1), 4, glow, true, -1, smooth)
	c.draw_polyline(orbit_points(orbit_center, 0, PI), brass, 2, smooth)
	c.draw_circle(orbit_points(orbit_center, 0.55, 0.55)[0], 5, glow, true, -1, smooth)
	c.draw_circle(orbit_points(orbit_center, 2.5, 2.5)[0], 3.5, team_color, true, -1, smooth)

func avatar_eyes(c: CanvasItem, center: Vector2, glow: Color, stunned: bool, spread: float = 12) -> void:
	for side in [-1, 1]:
		var p = center + Vector2(side * spread, 1)
		if stunned:
			c.draw_line(p - Vector2(3, 3), p + Vector2(3, 3), LIME, 2, smooth)
			c.draw_line(p - Vector2(-3, 3), p + Vector2(-3, 3), LIME, 2, smooth)
		else:
			c.draw_style_box(style(glow, Color.TRANSPARENT, 2), Rect2(p - Vector2(2, 4), Vector2(4, 8)))

func gardener_portrait(c: CanvasItem, center: Vector2, palette: Dictionary, stunned: bool) -> void:
	# Jardineiro: small head under a glass dome, a sprout on top, brass neck ring.
	var leaf = Color("7fbf5a")
	c.draw_style_box(style(palette.body, Color.TRANSPARENT, 14), Rect2(center + Vector2(-24, 15), Vector2(48, 24)))
	c.draw_style_box(style(Color("d2ad73"), Color.TRANSPARENT, 2), Rect2(center + Vector2(-22, 13), Vector2(44, 5)))
	c.draw_style_box(style(WHITE, Color.TRANSPARENT, 18), Rect2(center + Vector2(-26, -22), Vector2(52, 44)))
	c.draw_style_box(style(INK, Color.TRANSPARENT, 9), Rect2(center + Vector2(-21, -8), Vector2(42, 18)))
	avatar_eyes(c, center, palette.light, stunned, 10)
	c.draw_line(center + Vector2(0, -22), center + Vector2(0, -32), leaf.darkened(0.2), 2, smooth)
	c.draw_circle(center + Vector2(-5, -33), 4.5, leaf, true, -1, smooth)
	c.draw_circle(center + Vector2(5, -35), 4.5, leaf, true, -1, smooth)
	c.draw_circle(center + Vector2(0, -6), 40, Color(0.82, 0.96, 0.92, 0.16), true, -1, smooth)
	c.draw_arc(center + Vector2(0, -6), 40, 0, TAU, 64, Color(0.82, 0.96, 0.92, 0.85), 2.0, smooth)
	c.draw_arc(center + Vector2(0, -6), 33, PI * 1.1, PI * 1.45, 16, Color(WHITE, 0.6), 2.5, smooth)

func miner_portrait(c: CanvasItem, center: Vector2, palette: Dictionary, stunned: bool) -> void:
	# Mineiro: hard hat with brim and headlamp over the classic helmet.
	var steel = Color("9aa1ab")
	c.draw_style_box(style(palette.body, Color.TRANSPARENT, 14), Rect2(center + Vector2(-24, 15), Vector2(48, 24)))
	for side in [-1, 1]:
		c.draw_circle(center + Vector2(side * 31, -2), 9, steel, true, -1, smooth)
	c.draw_style_box(style(WHITE, Color.TRANSPARENT, 22), Rect2(center + Vector2(-32, -29), Vector2(64, 55)))
	c.draw_style_box(style(INK, Color.TRANSPARENT, 12), Rect2(center + Vector2(-27, -10), Vector2(54, 24)))
	avatar_eyes(c, center, palette.light, stunned)
	c.draw_style_box(style(palette.body, Color.TRANSPARENT, 16), Rect2(center + Vector2(-34, -44), Vector2(68, 30)))
	c.draw_style_box(style(palette.body.darkened(0.15), Color.TRANSPARENT, 3), Rect2(center + Vector2(-40, -18), Vector2(80, 6)))
	c.draw_circle(center + Vector2(0, -30), 7, Color("d2ad73"), true, -1, smooth)
	c.draw_circle(center + Vector2(0, -30), 4, palette.light, true, -1, smooth)

func sentinel_portrait(c: CanvasItem, center: Vector2, palette: Dictionary, stunned: bool) -> void:
	# Sentinela: eclipse halo behind the helmet, gold crest and a stern pair of eye slits.
	var brass = Color("d2ad73")
	c.draw_arc(center + Vector2(0, -6), 41, 0, TAU, 72, brass, 3, smooth)
	c.draw_arc(center + Vector2(0, -6), 36, 0, TAU, 72, Color(palette.light, 0.8), 1.5, smooth)
	c.draw_style_box(style(palette.body, Color.TRANSPARENT, 14), Rect2(center + Vector2(-24, 15), Vector2(48, 24)))
	c.draw_style_box(style(brass, Color.TRANSPARENT, 2), Rect2(center + Vector2(-24, 15), Vector2(48, 4)))
	for side in [-1, 1]:
		c.draw_circle(center + Vector2(side * 31, -2), 9, brass, true, -1, smooth)
	c.draw_style_box(style(WHITE, Color.TRANSPARENT, 22), Rect2(center + Vector2(-32, -29), Vector2(64, 55)))
	c.draw_style_box(style(INK, Color.TRANSPARENT, 12), Rect2(center + Vector2(-27, -10), Vector2(54, 24)))
	c.draw_style_box(style(brass, Color.TRANSPARENT, 2), Rect2(center + Vector2(-3, -33), Vector2(6, 12)))
	if stunned:
		avatar_eyes(c, center, palette.light, true)
	else:
		for side in [-1, 1]:
			c.draw_line(center + Vector2(side * 19, -2), center + Vector2(side * 8, 2), palette.light, 3, smooth)

func stun_cross(c: CanvasItem, p: Vector2) -> void:
	c.draw_line(p - Vector2(3, 3), p + Vector2(3, 3), LIME, 2, smooth)
	c.draw_line(p - Vector2(-3, 3), p + Vector2(-3, 3), LIME, 2, smooth)

func helmet(c: CanvasItem, center: Vector2) -> void:
	c.draw_style_box(style(WHITE, Color.TRANSPARENT, 22), Rect2(center + Vector2(-32, -29), Vector2(64, 55)))
	c.draw_style_box(style(INK, Color.TRANSPARENT, 12), Rect2(center + Vector2(-27, -10), Vector2(54, 24)))

func clockmaker_portrait(c: CanvasItem, center: Vector2, palette: Dictionary, stunned: bool) -> void:
	# Relojoeiro: gear cap, brass ear gears and a loupe monocle over one eye.
	var brass = Color("d2ad73")
	c.draw_style_box(style(palette.body, Color.TRANSPARENT, 14), Rect2(center + Vector2(-24, 15), Vector2(48, 24)))
	var gear = center + Vector2(0, -33)
	for i in range(8):
		var angle = i * TAU / 8
		c.draw_circle(gear + Vector2(cos(angle), sin(angle)) * 13, 4, brass, true, -1, smooth)
	c.draw_circle(gear, 13, palette.body, true, -1, smooth)
	c.draw_circle(gear + Vector2(0, -5), 4, palette.light, true, -1, smooth)
	for side in [-1, 1]:
		c.draw_circle(center + Vector2(side * 31, -2), 9, brass, true, -1, smooth)
		c.draw_circle(center + Vector2(side * 31, -2), 3, palette.body, true, -1, smooth)
	helmet(c, center)
	c.draw_circle(center + Vector2(13, 1), 10, brass, true, -1, smooth)
	if stunned:
		stun_cross(c, center + Vector2(-12, 1))
		stun_cross(c, center + Vector2(13, 1))
	else:
		c.draw_style_box(style(palette.light, Color.TRANSPARENT, 2), Rect2(center + Vector2(-14, -3), Vector2(4, 8)))
		c.draw_circle(center + Vector2(13, 1), 6, palette.light, true, -1, smooth)

func storm_portrait(c: CanvasItem, center: Vector2, palette: Dictionary, stunned: bool) -> void:
	# Caça-Trovões: lightning rod with a glowing tip and a bolt, rain-yellow collar, wide eye bars.
	var brass = Color("d2ad73")
	var yellow = Color("e0b84a")
	c.draw_style_box(style(yellow, Color.TRANSPARENT, 14), Rect2(center + Vector2(-24, 15), Vector2(48, 24)))
	c.draw_line(center + Vector2(0, -27), center + Vector2(0, -42), brass, 3, smooth)
	c.draw_circle(center + Vector2(0, -46), 5, palette.light, true, -1, smooth)
	c.draw_polyline(PackedVector2Array([center + Vector2(9, -52), center + Vector2(15, -43), center + Vector2(10, -42), center + Vector2(17, -33)]), palette.light, 2, smooth)
	for side in [-1, 1]:
		c.draw_circle(center + Vector2(side * 31, -2), 9, Color("9aa1ab"), true, -1, smooth)
	helmet(c, center)
	for side in [-1, 1]:
		if stunned:
			stun_cross(c, center + Vector2(side * 12, 1))
		else:
			c.draw_style_box(style(palette.light, Color.TRANSPARENT, 2), Rect2(center + Vector2(side * 12 - 6, -1), Vector2(12, 4)))

func alchemist_portrait(c: CanvasItem, center: Vector2, palette: Dictionary, stunned: bool) -> void:
	# Alquimista: hood, brass goggles on a strap and potion bubbles rising.
	var brass = Color("d2ad73")
	c.draw_style_box(style(palette.body, Color.TRANSPARENT, 14), Rect2(center + Vector2(-24, 15), Vector2(48, 24)))
	c.draw_style_box(style(palette.body.darkened(0.1), Color.TRANSPARENT, 26), Rect2(center + Vector2(-37, -36), Vector2(74, 60)))
	helmet(c, center)
	c.draw_line(center + Vector2(-32, 1), center + Vector2(32, 1), Color("3a2a20"), 4, smooth)
	for side in [-1, 1]:
		var p = center + Vector2(side * 12, 1)
		c.draw_circle(p, 9, brass, true, -1, smooth)
		c.draw_circle(p, 6, INK if stunned else palette.light, true, -1, smooth)
		if stunned:
			stun_cross(c, p)
	for bubble in [[Vector2(-6, -40), 4.0], [Vector2(5, -47), 3.0], [Vector2(-2, -54), 2.2]]:
		c.draw_circle(center + bubble[0], bubble[1], Color(palette.light, 0.85), true, -1, smooth)

func corsair_portrait(c: CanvasItem, center: Vector2, palette: Dictionary, stunned: bool) -> void:
	# Corsário: tricorn with a gem, gold ear rings, an eye patch and one glowing eye.
	var brass = Color("d2ad73")
	var patch = Color("141e24")
	c.draw_style_box(style(palette.body, Color.TRANSPARENT, 14), Rect2(center + Vector2(-24, 15), Vector2(48, 24)))
	for side in [-1, 1]:
		c.draw_circle(center + Vector2(side * 31, -2), 9, brass, true, -1, smooth)
	helmet(c, center)
	c.draw_line(center + Vector2(-30, 9), center + Vector2(20, -22), patch, 3, smooth)
	c.draw_circle(center + Vector2(-12, 1), 7, patch, true, -1, smooth)
	c.draw_arc(center + Vector2(-12, 1), 7.5, 0, TAU, 24, brass, 1.2, smooth)
	if stunned:
		stun_cross(c, center + Vector2(12, 1))
	else:
		c.draw_style_box(style(palette.light, Color.TRANSPARENT, 2), Rect2(center + Vector2(10, -3), Vector2(4, 8)))
	var brim = [Vector2(-44, -18), Vector2(-28, -40), Vector2(0, -47), Vector2(28, -40), Vector2(44, -18)]
	var hat = PackedVector2Array()
	for point in brim:
		hat.append(center + point)
	hat.append(center + Vector2(0, -25))
	c.draw_colored_polygon(hat, palette.body)
	var trim = PackedVector2Array()
	for point in brim:
		trim.append(center + point)
	c.draw_polyline(trim, brass, 2, smooth)
	c.draw_circle(center + Vector2(0, -36), 3.5, palette.light, true, -1, smooth)

func archon_portrait(c: CanvasItem, center: Vector2, palette: Dictionary, stunned: bool) -> void:
	# Arconte Solar: a crown of sun rays, gold band and ear discs over a royal collar.
	var brass = Color("d2ad73")
	var crown = center + Vector2(0, -12)
	for i in range(9):
		var angle = lerpf(PI * 1.12, PI * 1.88, i / 8.0)
		var direction = Vector2(cos(angle), sin(angle))
		var side = Vector2(-direction.y, direction.x) * (4.5 if i % 2 == 0 else 3.0)
		var tip = crown + direction * (46 if i % 2 == 0 else 39)
		c.draw_colored_polygon(PackedVector2Array([crown + direction * 22 + side, tip, crown + direction * 22 - side]), palette.light if i % 2 == 0 else brass)
	c.draw_style_box(style(palette.body, Color.TRANSPARENT, 14), Rect2(center + Vector2(-24, 15), Vector2(48, 24)))
	c.draw_style_box(style(brass, Color.TRANSPARENT, 2), Rect2(center + Vector2(-24, 15), Vector2(48, 4)))
	for side in [-1, 1]:
		c.draw_circle(center + Vector2(side * 31, -2), 9, brass, true, -1, smooth)
	helmet(c, center)
	c.draw_style_box(style(brass, Color.TRANSPARENT, 3), Rect2(center + Vector2(-27, -31), Vector2(54, 7)))
	c.draw_circle(center + Vector2(0, -27), 4, palette.light, true, -1, smooth)
	avatar_eyes(c, center, palette.light, stunned)

func player_card(rect: Rect2, side: int, t: int) -> void:
	# Tall side cards in landscape; wide strips beside each goal in portrait.
	var color = CYAN if t == 0 else CORAL
	var at = rect.position
	panel(rect)
	var role = "TU" if side == 0 else ("ADVERSÁRIO / IA" if mode == "pve" else "ADVERSÁRIO")
	if side == 1 and not level_info.is_empty():
		role = ("FINALISTA" if level_info.number == 11 else "QUALIFICATÓRIA") if level_info.get("cup", false) else "BOSS · NÍVEL %d" % level_info.number
	var pilot = "NOVA" if t == 0 else "EMBER"
	if side == 1 and not level_info.is_empty():
		pilot = level_info.boss_name
	var count = 0
	var health = 0
	var per_team: int = match_data.bricks.size() / 2
	for i in range(per_team):
		var data: Dictionary = match_data.bricks[t * per_team + i]
		if data.alive:
			count += 1
		health += data.hp
	var status = "BALIZA ABERTA" if count == 0 else str(count) + " TIJOLOS  ·  " + str(health) + "/120"
	var status_color = LIME if count == 0 else MUTED
	var stunned: bool = match_data.players[t].stun > 0
	var tips = [["Move-te para apontar", WHITE, false], ["Dispara sozinho, sempre em frente", MUTED, false]]
	if side == 1:
		tips = [["BOOST: 2 NOS TIJOLOS", LIME, true], ["5 acertos · pausa 0,5 s", MUTED, false]]
	if vertical:
		var is_left = (side == 0)
		var avatar_x = at.x + 46.0 if is_left else at.x + rect.size.x - 46.0
		var content_x = at.x + 92.0 if is_left else at.x + 12.0
		var avatar_center = Vector2(avatar_x, at.y + rect.size.y * 0.5)

		# The pilot's face is what the eye goes to, so it gets the room.
		draw_circle(avatar_center, 40.0, Color(INK, 0.45), true, -1, smooth)
		draw_set_transform(avatar_center, 0.0, Vector2(0.88, 0.88))
		portrait(Vector2.ZERO, pilot_hue(t, color), stunned, team_skins[t], null, team_tints[t])
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		var disp_name = pilot
		if disp_name.length() > 8 and rect.size.x < 190:
			disp_name = disp_name.substr(0, 7) + "."
		write(disp_name, Vector2(content_x, at.y + 26), 16, color, true)
		player_life_bar_compact(Vector2(content_x, at.y + 38), match_data.players[t].hp, color)
		# The wall count is what both pilots watch, so it never leaves the card. Whatever else
		# there is to say — a stun, the rival's charged powers — takes the line under it.
		write(status, Vector2(content_x, at.y + 64), 11, status_color, count == 0)
		if stunned:
			write("⚡ ATORDOADO %.1fs" % match_data.players[t].stun, Vector2(content_x, at.y + 84), 12, LIME, true)
		elif side == 1 and match_data.has("powers") and t < match_data.powers.size():
			power_pips(Vector2(content_x, at.y + 84), t)
	else:
		var bricks_at = at + Vector2(23, 172)
		for i in range(per_team):
			var data: Dictionary = match_data.bricks[t * per_team + i]
			var alive: bool = data.alive
			var brick = Rect2(bricks_at + Vector2((i % 10) * 16, floori(i / 10.0) * 6), Vector2(12, 4))
			draw_style_box(style(color.darkened((3 - data.hp) * 0.22) if alive else Color("284349"), Color.TRANSPARENT, 1), brick)
		var center = at.x + 100
		write(role, at + Vector2(17, 24), 10, MUTED, true)
		portrait(Vector2(center, at.y + 85), pilot_hue(t, color), stunned, team_skins[t], null, team_tints[t])
		centered(pilot, Vector2(center, at.y + 146), 22, WHITE, true)
		player_life_bar(Vector2(center - 47, at.y + 158), match_data.players[t].hp, color)
		centered(status, Vector2(center, at.y + 210), 10, status_color, true)
		# Your own hints go under the power buttons, which hang below your card; the rival's
		# take the same band on the other side, where the buttons never reach.
		var tip_x = 49.0 if side == 0 else size.x - 221
		var tip_y = 556.0 if side == 0 else 437.0
		write(tips[0][0], Vector2(tip_x, tip_y), 13, tips[0][1], tips[0][2])
		write(tips[1][0], Vector2(tip_x, tip_y + 24), 12, tips[1][1], tips[1][2])
		if side == 1:
			power_pips(Vector2(tip_x, tip_y + 48), t)

func player_life_bar_compact(at: Vector2, hp: int, color: Color) -> void:
	for i in range(5):
		var cell = Rect2(at + Vector2(i * 15, 0), Vector2(11, 6))
		var fill = color if i < hp else Color("263f44")
		draw_style_box(style(fill, Color(fill.lightened(0.22), 0.8), 1), cell)

func power_pips(at: Vector2, t: int) -> void:
	# Which of the rival's powers are charged, in the same colours as your own buttons.
	if not match_data.has("powers") or t >= match_data.powers.size():
		return
	var state: Dictionary = match_data.powers[t]
	write("PODERES", at, 10, MUTED, true)
	for index in range(Rules.POWER_SLOTS):
		var id = match_loadout(t, index)
		var cost: int = int(Powers.entry(id).get("charge", 0))
		var ready: bool = cost > 0 and state.charge[index] >= cost
		draw_circle(at + Vector2(62 + index * 16, -4), 5, Rules.power_color(id) if ready else Color("284349"), true, -1, smooth)

func player_life_bar(at: Vector2, hp: int, color: Color) -> void:
	# Five separate cells stay legible on small displays and make every hit clear.
	for i in range(5):
		var cell = Rect2(at + Vector2(i * 20, 0), Vector2(15, 7))
		var fill = color if i < hp else Color("263f44")
		draw_style_box(style(fill, Color(fill.lightened(0.22), 0.75), 2), cell)

func _draw() -> void:
	if font == null:
		return
	var top = Vector2(0, safe_top)
	var bottom = size.y - safe_bottom
	if vertical:
		draw_circle(Vector2(28, 26) + top, 14, Color(CYAN, 0.12), true, -1, smooth)
		var bolt = PackedVector2Array([Vector2(32, 16) + top, Vector2(23, 27) + top, Vector2(31, 27) + top, Vector2(25, 36) + top])
		draw_polyline(bolt, CYAN, 2.2, smooth)
		write("CHARGE ARENA", Vector2(49, 24) + top, 15, WHITE, true)
		write("C I R C U I T O   A U R O R A", Vector2(49, 38) + top, 8, MUTED)
	else:
		draw_circle(Vector2(49, 47) + top, 19, Color(CYAN, 0.1), true, -1, smooth)
		var bolt = PackedVector2Array([Vector2(54, 32) + top, Vector2(40, 49) + top, Vector2(52, 49) + top, Vector2(44, 62) + top])
		draw_polyline(bolt, CYAN, 2.5, smooth)
		write("CHARGE ARENA", Vector2(82, 44) + top, 17, WHITE, true)
		write("C I R C U I T O   A U R O R A", Vector2(82, 62) + top, 9, MUTED)
	if mode == "menu":
		# Flavour for the menu alone. In a match that strip belongs to the stick's caption and
		# to the frame counter, and the three of them were landing on top of each other.
		write("ARENA 01   /   AURORA", Vector2(34, bottom - 24), 10, MUTED)
		write("ENCONTRA O TEU ÂNGULO", Vector2(size.x - 204, bottom - 24), 10, MUTED)
		if not vertical:
			write("UM DISPARO.", Vector2(size.x - 285, size.y - 126), 22, WHITE, true)
			write("MIL POSSIBILIDADES.", Vector2(size.x - 285, size.y - 98), 22, LIME, true)
		draw_menu_level()
		return
	if match_data.is_empty():
		return
	var mid = size.x * 0.5
	var s = score_rect.position
	panel(score_rect)
	if vertical:
		var round_text = "1º A %d GOLOS" % Rules.WIN_SCORE
		if not level_info.is_empty():
			round_text = ("FINAL" if level_info.number == 11 else "JOGO %d" % level_info.number) if level_info.get("cup", false) else "NÍVEL %d" % level_info.number
		centered(round_text, Vector2(score_rect.get_center().x, s.y + 19), 10, LIME, true)
		centered(str(match_data.scores[0]) + "  :  " + str(match_data.scores[1]), Vector2(score_rect.get_center().x, s.y + 44), 26, WHITE, true)
		var mode_label = "TREINO / PvE" if mode == "pve" else "DUELO / PvP"
		if not level_info.is_empty():
			mode_label = "TAÇA AURORA" if level_info.get("cup", false) else "CAMPANHA"
		centered(mode_label, Vector2(score_rect.get_center().x, s.y + 64), 9, MUTED, true)
	else:
		draw_circle(s + Vector2(23, 30), 4, CYAN, true, -1, smooth)
		write("NOVA", s + Vector2(36, 35), 12, CYAN, true)
		centered(str(match_data.scores[0]) + "  :  " + str(match_data.scores[1]), Vector2(score_rect.get_center().x, s.y + 41), 31, WHITE, true)
		write("EMBER", s + Vector2(218, 35), 12, CORAL, true)
		draw_circle(s + Vector2(284, 30), 4, CORAL, true, -1, smooth)
		var mode_at = Vector2(38, 116)
		var mode_name = "TREINO / PvE" if mode == "pve" else "DUELO / PvP"
		if not level_info.is_empty():
			mode_name = "CAMPANHA · NÍVEL %d" % level_info.number
		write(mode_name, mode_at, 12, LIME, true)
		write("PRIMEIRO A %d GOLOS" % Rules.WIN_SCORE, mode_at + Vector2(0, 23), 10, MUTED)
	for side in range(2):
		player_card(card_rects[side], side, team if side == 0 else 1 - team)
	var p: Dictionary = match_data.players[team]
	if p.stun > 0:
		var banner = stun_banner_rect()
		panel(banner)
		centered("PARALISADO   %.1f s" % p.stun, Vector2(banner.get_center().x, banner.get_center().y + 5), 15, LIME, true)
	var message = ""
	var sub = ""
	var detail = ""
	if network_status != "":
		message = network_status
	elif match_data.phase == "countdown":
		message = str(maxi(1, ceili(match_data.timer)))
		sub = "PREPARA O TEU DISPARO"
		if not level_info.is_empty():
			sub = "NÍVEL %d · %s" % [level_info.number, level_info.name.to_upper()]
			detail = level_info.challenge
	elif match_data.phase == "goal":
		message = "GOLO!" if match_data.winner == team else "GOLO DO RIVAL"
		sub = "NOVA RONDA A SEGUIR"
	elif match_data.phase == "finished":
		message = "VITÓRIA" if match_data.winner == team else "O RIVAL VENCEU"
		sub = "PRIMEIRO A %d GOLOS" % Rules.WIN_SCORE
		if level_result == "won":
			sub = "NÍVEL %d CONCLUÍDO" % level_info.number
			if not level_info.has_next:
				sub = "CAMPANHA CONCLUÍDA!"
			elif level_opened:
				sub += " · NÍVEL %d DESBLOQUEADO" % (level_info.number + 1)
			if level_skin != "":
				detail = "Skin %s desbloqueada na aba SKINS" % level_skin
		elif level_result == "lost":
			message = "O BOSS VENCEU"
			sub = "TENTA OUTRA VEZ"
	if message != "":
		var c = message_center
		var half_width = 204.0 if detail == "" else minf(size.x * 0.5 - 20, 290)
		panel(Rect2(c.x - half_width, c.y - 62, half_width * 2, 124), Color(0.065, 0.125, 0.14, 0.96))
		centered(message, Vector2(c.x, c.y - 4 - (8 if detail != "" else 0)), 36 if message.length() < 16 else 22, WHITE, true)
		centered(sub, Vector2(c.x, c.y + 24), 11, LIME)
		if detail != "":
			centered(detail, Vector2(c.x, c.y + 44), 11, MUTED)
	if unlock_timer > 0:
		var at = message_center - Vector2(0, 170 if vertical else 150)
		panel(Rect2(at.x - 190, at.y - 34, 380, 68), Color(0.065, 0.125, 0.14, 0.96))
		centered("✦  NOVA SKIN DESBLOQUEADA  ✦", at + Vector2(0, -8), 11, LIME, true)
		centered(unlock_text, at + Vector2(0, 21), 22, WHITE, true)
	# The stick: grabbed anywhere in the band, it slides the pilot along its arc.
	var stick = move_center
	draw_circle(stick + Vector2(0, 3), STICK_RADIUS, Color(0.01, 0.04, 0.05, 0.5), true, -1, smooth)
	draw_circle(stick, STICK_RADIUS, Color(0.08, 0.15, 0.16, 0.9), true, -1, smooth)
	draw_arc(stick, STICK_RADIUS - 1.5, 0, TAU, 72, Color(BRASS, 0.5), 1.3, smooth)
	draw_arc(stick, STICK_RADIUS - 10, 0.2, PI - 0.2, 40, Color(CYAN, 0.07), 5, smooth)
	draw_arc(stick, STICK_RADIUS - 10, PI + 0.2, TAU - 0.2, 40, Color(CYAN, 0.07), 5, smooth)
	for side in [-1, 1]:
		var tip = stick + Vector2(side * (STICK_RADIUS - 15), 0)
		draw_polyline(PackedVector2Array([tip - Vector2(side * 8, 9), tip, tip - Vector2(side * 8, -9)]), Color(CYAN, 0.45), 2.6, smooth)
	var knob = stick + move_vector * 39
	draw_circle(knob + Vector2(0, 3), 26, Color(0.02, 0.05, 0.06, 0.45), true, -1, smooth)
	draw_circle(knob, 26, CYAN.darkened(0.2 if move_id >= 0 else 0.55), true, -1, smooth)
	draw_arc(knob, 26, 0, TAU, 48, Color(CYAN, 0.65), 1.2, smooth)
	draw_circle(knob, 3, INK if move_id >= 0 else CYAN, true, -1, smooth)
	centered("MOVER E APONTAR", stick + Vector2(0, 84), 10, CYAN, true)
	centered("DISPARO AUTOMÁTICO  ·  MIRA ASSISTIDA", stick + Vector2(0, 99), 9, Color(LIME, 0.75), true)
	draw_powers()

func stun_banner_rect() -> Rect2:
	# Over the thumb band on a phone, under the score on a wide screen.
	var mid = size.x * 0.5
	if vertical:
		return Rect2(mid - 130, move_home.y - STICK_RADIUS - 52, 260, 36)
	return Rect2(mid - 130, size.y - 77, 260, 36)

func draw_powers() -> void:
	# One button per power: the ring is the charge, the disc lights up when it is ready.
	if not match_data.has("powers") or team >= match_data.powers.size():
		return
	var state: Dictionary = match_data.powers[team]
	for index in range(power_centers.size()):
		var center: Vector2 = power_centers[index]
		var span: float = power_button_radius(index)
		var id = match_loadout(team, index)
		var cost: int = int(Powers.entry(id).get("charge", 0))
		var charge: int = clampi(state.charge[index], 0, maxi(cost, 1))
		# Two things can hold a power back: the bricks that open it the first time, and the
		# clock that runs after every use. The clock takes the button once it is running.
		var cool: float = state.cool[index] if state.has("cool") else 0.0
		var wait: float = maxf(Powers.wait_of(id), 0.001)
		# Frost shuts the whole kit, so no button reads as ready while it holds.
		var frozen: float = state.freeze_time if state.has("freeze_time") else 0.0
		var ready: bool = cost > 0 and charge >= cost and cool <= 0 and frozen <= 0
		var color: Color = Rules.power_color(id)
		var running: bool = (id == "rapid" and state.rapid_time > 0) or (id == "laser" and state.laser_time > 0)
		var charging: bool = Powers.is_ultimate(id) and state.get("ultimate_windup", 0.0) > 0
		draw_circle(center + Vector2(0, 3), span, Color(0.01, 0.04, 0.05, 0.5), true, -1, smooth)
		draw_circle(center, span, Color(0.08, 0.15, 0.16, 0.92), true, -1, smooth)
		draw_arc(center, span - 1.5, 0, TAU, 56, Color(BRASS, 0.55 if cost > 0 else 0.25), 1.6, smooth)
		draw_arc(center, span - 4, 0, TAU, 56, Color(color, 0.18), 1.4, smooth)
		# The ring is whichever of the two is still counting: the bricks before the first
		# use, the clock after it.
		var filled: float = (1.0 - frozen / Rules.FREEZE_SECONDS) if frozen > 0 else ((1.0 - cool / wait) if cool > 0 else (float(charge) / maxi(cost, 1)))
		if filled > 0 and cost > 0:
			# Fills clockwise from the top, so a glance is enough to read the progress.
			draw_arc(center, span - 4, -PI * 0.5, -PI * 0.5 + TAU * clampf(filled, 0, 1), 56, Color(color, 0.95 if ready else 0.5), 4.2, smooth)
		var pressed: bool = power_flash[index] > 0
		var disc = color.darkened(0.0 if pressed else (0.2 if ready else 0.62))
		if ready or pressed:
			# A ready power glows, so it is caught out of the corner of the eye.
			draw_circle(center, span - 6, Color(color, 0.18), true, -1, smooth)
		if charging:
			# Winding up: a ring closes on the key while the pilot glows on the field.
			var wind = 1.0 - state.ultimate_windup / Rules.ULTIMATE_WINDUP
			draw_circle(center, span - 6, Color(color, 0.12 + 0.3 * wind), true, -1, smooth)
			draw_arc(center, span + 4 - wind * 10, 0, TAU, 48, Color(color, 0.85), 2.6, smooth)
		draw_circle(center, span - 11, disc, true, -1, smooth)
		draw_arc(center, span - 11, PI * 1.15, PI * 1.85, 20, Color(CERAMIC, 0.22 if ready else 0.1), 1.2, smooth)
		power_icon(id, center + Vector2(0, -span * 0.28), INK if ready or pressed else Color(WHITE, 0.75), self, span / POWER_RADIUS)
		var caption = "PRONTO" if ready else "%d/%d" % [charge, cost]
		if cool > 0:
			# Counting down: whole seconds while there is time, tenths in the last one.
			caption = ("%.0f s" % ceilf(cool)) if cool >= 1.0 else ("%.1f s" % cool)
		if frozen > 0:
			caption = "GELADO"
		if cost <= 0:
			caption = "EM BREVE"
		elif charging:
			caption = "%.1f s" % state.ultimate_windup
		elif running:
			caption = "%.1f s" % (state.laser_time if id == "laser" else state.rapid_time)
		centered(caption, center + Vector2(0, span * 0.33), roundi(11 * span / POWER_RADIUS), INK if ready or pressed else WHITE, true)
		# The name goes under the button, not inside it: the ring is forty pixels across, and
		# with the icon and the charge already in there the name was crossing the rim.
		centered(Rules.power_label(id), center + Vector2(0, span + 15), roundi(11 * span / POWER_RADIUS), Color(WHITE, 0.85 if ready or pressed else 0.5), true)

func match_loadout(t: int, index: int) -> String:
	# The power on that button: empty while the skin ultimates are still to come.
	var kits: Array = match_data.get("loadouts", [])
	if t < kits.size() and index < kits[t].size():
		return String(kits[t][index])
	return ""

func power_icon(id: String, center: Vector2, color: Color, canvas: CanvasItem = null, scale_value: float = 1.0) -> void:
	# One sigil per power, all drawn at the same weight inside a 26 px circle. `scale_value`
	# blows the whole drawing up for the bigger keys without redrawing any of it.
	var c: CanvasItem = canvas if canvas != null else self
	if not is_equal_approx(scale_value, 1.0):
		c.draw_set_transform(center, 0.0, Vector2.ONE * scale_value)
		power_icon(id, Vector2.ZERO, color, c)
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var brass = Color(BRASS, 0.85)
	match id:
		"blast":
			# Blast: a charge core throwing off shards.
			for step in range(6):
				var angle = step * TAU / 6.0 + 0.26
				var direction = Vector2(cos(angle), sin(angle))
				c.draw_line(center + direction * 6.5, center + direction * 12.5, color, 2.0, smooth)
			c.draw_circle(center, 5.0, color, true, -1, smooth)
			c.draw_arc(center, 5.0, 0, TAU, 20, brass, 1.0, smooth)
		"rapid":
			# Machine gun: three rounds leaving a brass barrel.
			c.draw_line(center + Vector2(-13, 9), center + Vector2(-1, 9), brass, 3.0, smooth)
			for row in range(3):
				var y = center.y - 8.0 + row * 8.0
				c.draw_line(Vector2(center.x - 6, y), Vector2(center.x + 5, y), color, 2.0, smooth)
				c.draw_circle(Vector2(center.x + 9, y), 2.2, color, true, -1, smooth)
		"air":
			# Air burst: a fan of pellets out of one muzzle.
			var muzzle = center + Vector2(0, 11)
			c.draw_circle(muzzle, 2.6, brass, true, -1, smooth)
			for spread in [-0.62, -0.21, 0.21, 0.62]:
				var direction = Vector2(sin(spread), -cos(spread))
				c.draw_line(muzzle + direction * 4.0, muzzle + direction * 19.0, color, 2.0, smooth)
		"ghost":
			# Ghost rounds: a shot crossing a pillar it should have hit.
			c.draw_arc(center + Vector2(1, 0), 8.5, 0, TAU, 28, brass, 1.6, smooth)
			c.draw_line(center + Vector2(-13, 0), center + Vector2(9, 0), color, 2.0, smooth)
			c.draw_circle(center + Vector2(12, 0), 3.2, color, true, -1, smooth)
		"laser":
			# Laser: a lance with a widening muzzle.
			c.draw_line(center + Vector2(-12, 9), center + Vector2(11, -8), color, 3.0, smooth)
			c.draw_line(center + Vector2(-13, 11), center + Vector2(-8, 4), brass, 2.4, smooth)
			c.draw_line(center + Vector2(5, -12), center + Vector2(12, -5), Color(color, 0.65), 1.8, smooth)
		"rebuild":
			# Rebuild: a wall stacking itself back up, the top course still landing.
			for row in range(2):
				for column in range(3 - row):
					var at = center + Vector2((column - (2 - row) * 0.5) * 9.0 + 4.5, 9.0 - row * 8.0)
					c.draw_rect(Rect2(at - Vector2(3.8, 3.0), Vector2(7.6, 6.0)), color if row == 0 else Color(color, 0.8), true)
			c.draw_line(center + Vector2(-8, -8), center + Vector2(-1, -12), brass, 1.8, smooth)
			c.draw_line(center + Vector2(8, -8), center + Vector2(1, -12), brass, 1.8, smooth)
		"mirror":
			# Mirror cape: a shot bouncing off a curved shield.
			c.draw_arc(center + Vector2(5, 0), 11.0, PI * 0.58, PI * 1.42, 26, color, 2.4, smooth)
			c.draw_arc(center + Vector2(5, 0), 7.5, PI * 0.58, PI * 1.42, 20, Color(color, 0.4), 1.4, smooth)
			c.draw_line(center + Vector2(-13, -8), center + Vector2(-5, -1), brass, 2.0, smooth)
			c.draw_line(center + Vector2(-5, -1), center + Vector2(-13, 7), brass, 2.0, smooth)
		"walls":
			# Walls: four slabs rising out of the ground, with the gaps between them.
			c.draw_line(center + Vector2(-13, 10), center + Vector2(13, 10), brass, 1.6, smooth)
			for slot in range(4):
				var x = center.x - 10.5 + slot * 7.0
				c.draw_rect(Rect2(Vector2(x - 2.1, center.y - 9.0 + slot % 2 * 2.0), Vector2(4.2, 19.0 - slot % 2 * 2.0)), color, true)
			c.draw_line(center + Vector2(-8, -12), center + Vector2(-8, -16), Color(color, 0.6), 1.6, smooth)
			c.draw_line(center + Vector2(5, -12), center + Vector2(5, -16), Color(color, 0.6), 1.6, smooth)
		"stun":
			# Shock pulse: a ring sweeping outwards with stunned stars above it.
			c.draw_arc(center + Vector2(0, 3), 12.0, PI, TAU, 26, color, 2.2, smooth)
			c.draw_arc(center + Vector2(0, 3), 6.5, PI, TAU, 18, Color(color, 0.55), 1.6, smooth)
			c.draw_circle(center + Vector2(0, 3), 2.6, color, true, -1, smooth)
			for star in [Vector2(-9, -9), Vector2(0, -13), Vector2(9, -9)]:
				var at = center + star
				c.draw_line(at + Vector2(-3, 0), at + Vector2(3, 0), brass, 1.6, smooth)
				c.draw_line(at + Vector2(0, -3), at + Vector2(0, 3), brass, 1.6, smooth)
		"sun_ray":
			# Sun ray: a broad column out of a sun.
			c.draw_circle(center + Vector2(0, 9), 5.0, color, true, -1, smooth)
			for spread in [-6.0, 0.0, 6.0]:
				c.draw_line(center + Vector2(spread * 0.7, 6), center + Vector2(spread, -13), color, 2.6, smooth)
			c.draw_arc(center + Vector2(0, 9), 9.0, PI, TAU, 18, brass, 1.6, smooth)
		"meteors":
			# Meteors: two rocks with trails.
			for rock in [[Vector2(-7, 2), 4.0], [Vector2(6, 7), 3.0]]:
				var at = center + rock[0]
				c.draw_circle(at, rock[1], color, true, -1, smooth)
				c.draw_line(at + Vector2(6, -11), at, Color(color, 0.5), 2.2, smooth)
			c.draw_line(center + Vector2(13, -13), center + Vector2(3, -3), brass, 2.0, smooth)
		"thunder":
			# Thunder: a bolt with a flash at its foot.
			c.draw_polyline(PackedVector2Array([center + Vector2(2, -13), center + Vector2(-6, 0), center + Vector2(1, 0), center + Vector2(-3, 13)]), color, 2.8, smooth)
			c.draw_arc(center + Vector2(-2, 12), 8.0, PI, TAU, 16, brass, 1.6, smooth)
		"bloom":
			# Bloom: a sprout over a brick, with the +2.
			c.draw_rect(Rect2(center + Vector2(-11, 3), Vector2(22, 9)), color, true)
			c.draw_line(center + Vector2(0, 3), center + Vector2(0, -6), color, 2.2, smooth)
			c.draw_circle(center + Vector2(-5, -8), 4.0, color, true, -1, smooth)
			c.draw_circle(center + Vector2(5, -10), 4.0, brass, true, -1, smooth)
		"singularity":
			# Singularity: a black core with a ring of debris and shots falling in.
			c.draw_arc(center, 12.0, 0, TAU, 28, Color(color, 0.85), 2.0, smooth)
			c.draw_circle(center, 5.6, Color(0.02, 0.03, 0.05, 1.0), true, -1, smooth)
			c.draw_arc(center, 5.6, 0, TAU, 20, brass, 1.6, smooth)
			for way in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				c.draw_line(center + way * 15.0, center + way * 9.0, Color(color, 0.9), 1.8, smooth)
		"sentries":
			# Sentries: two gun platforms side by side, firing upwards.
			for side in [-1, 1]:
				var post = center + Vector2(side * 8, 4)
				c.draw_circle(post, 5.0, color, true, -1, smooth)
				c.draw_circle(post, 2.0, Color(INK, 0.85), true, -1, smooth)
				c.draw_line(post + Vector2(0, -4), post + Vector2(0, -11), brass, 2.2, smooth)
			c.draw_line(center + Vector2(-13, 10), center + Vector2(13, 10), Color(color, 0.7), 2.0, smooth)
		"plunder":
			# Plunder: two stacks swapping places.
			c.draw_rect(Rect2(center + Vector2(-13, -12), Vector2(11, 7)), color, true)
			c.draw_rect(Rect2(center + Vector2(2, 5), Vector2(11, 7)), color, true)
			c.draw_polyline(PackedVector2Array([center + Vector2(-2, -6), center + Vector2(6, -6), center + Vector2(3, -9)]), brass, 2.0, smooth)
			c.draw_polyline(PackedVector2Array([center + Vector2(2, 2), center + Vector2(-6, 2), center + Vector2(-3, 5)]), brass, 2.0, smooth)
		"surge":
			# Overload: a core with three bars of charge climbing out of it.
			c.draw_circle(center, 4.6, color, true, -1, smooth)
			c.draw_arc(center, 4.6, 0, TAU, 20, brass, 1.0, smooth)
			for step in range(3):
				var height = 6.0 + step * 3.0
				var x = center.x - 9.0 + step * 9.0
				c.draw_line(Vector2(x, center.y + 11), Vector2(x, center.y + 11 - height), color, 2.4, smooth)
			c.draw_polyline(PackedVector2Array([center + Vector2(2, -13), center + Vector2(-4, -5), center + Vector2(2, -5), center + Vector2(-2, 3)]), brass, 1.8, smooth)
		"volley":
			# Volley: the fan of the Leque, drawn five deep.
			for step in range(5):
				var lane = lerpf(-0.62, 0.62, step / 4.0)
				var direction = Vector2(sin(lane), -cos(lane))
				c.draw_line(center + direction * 3.0, center + direction * 12.0, color, 2.0, smooth)
			c.draw_arc(center, 6.0, -PI * 0.5 - 0.8, -PI * 0.5 + 0.8, 16, brass, 1.4, smooth)
			c.draw_arc(center, 10.5, -PI * 0.5 - 0.7, -PI * 0.5 + 0.7, 16, Color(color, 0.7), 1.2, smooth)
			c.draw_circle(center + Vector2(0, 8), 3.0, brass, true, -1, smooth)
		"weld":
			# Weld: a brick with a seam of light running across the crack.
			c.draw_rect(Rect2(center + Vector2(-12, -7), Vector2(24, 14)), Color(color, 0.7), true)
			c.draw_rect(Rect2(center + Vector2(-12, -7), Vector2(24, 14)), brass, false, 1.2)
			c.draw_polyline(PackedVector2Array([center + Vector2(-2, -7), center + Vector2(2, 0), center + Vector2(-2, 7)]), CERAMIC, 2.4, smooth)
			for step in range(3):
				c.draw_circle(center + Vector2(-2 + step * 4, -11 - step * 2), 1.8, color, true, -1, smooth)
		"thorns":
			# Thorns: spikes standing up off a wall line.
			c.draw_line(center + Vector2(-13, 8), center + Vector2(13, 8), brass, 2.0, smooth)
			for step in range(4):
				var root_x = center.x - 10.5 + step * 7.0
				c.draw_polyline(PackedVector2Array([Vector2(root_x - 3, center.y + 8), Vector2(root_x, center.y - 9), Vector2(root_x + 3, center.y + 8)]), color, 2.0, smooth)
		"freeze":
			# Frost: a six-pointed crystal.
			for step in range(3):
				var arm = step * PI / 3.0
				var reach = Vector2(cos(arm), sin(arm)) * 12.0
				c.draw_line(center - reach, center + reach, color, 2.2, smooth)
				c.draw_line(center + reach * 0.62, center + reach * 0.62 + reach.rotated(2.2) * 0.3, color, 1.6, smooth)
				c.draw_line(center - reach * 0.62, center - reach * 0.62 - reach.rotated(2.2) * 0.3, color, 1.6, smooth)
			c.draw_circle(center, 3.0, brass, true, -1, smooth)
		"magnet":
			# Magnet: a horseshoe with its poles pointing up, and a round curving in.
			c.draw_arc(center + Vector2(0, 3), 9.0, PI, TAU, 22, color, 3.4, smooth)
			for side in [-1.0, 1.0]:
				c.draw_line(center + Vector2(side * 9, 3), center + Vector2(side * 9, 10), color, 3.4, smooth)
				c.draw_line(center + Vector2(side * 9, 8), center + Vector2(side * 9, 10), brass, 3.4, smooth)
			c.draw_arc(center + Vector2(0, -6), 7.0, PI * 1.15, PI * 1.85, 16, Color(color, 0.6), 1.6, smooth)
			c.draw_circle(center + Vector2(0, -12), 2.6, CERAMIC, true, -1, smooth)
		"pierce":
			# Piercing: a dart through two plates.
			for plate in [-4.0, 4.0]:
				c.draw_rect(Rect2(center + Vector2(plate - 1.5, -12), Vector2(3, 24)), Color(brass, 0.6), true)
			c.draw_line(center + Vector2(-13, 0), center + Vector2(11, 0), color, 3.0, smooth)
			c.draw_polyline(PackedVector2Array([center + Vector2(6, -5), center + Vector2(13, 0), center + Vector2(6, 5)]), color, 2.4, smooth)
		"plating":
			# Plating: a brick under a crystal shell, with the blow glancing off it.
			c.draw_rect(Rect2(center + Vector2(-10, 0), Vector2(20, 10)), Color(color, 0.7), true)
			c.draw_polyline(PackedVector2Array([center + Vector2(-12, 0), center + Vector2(-7, -9), center + Vector2(7, -9), center + Vector2(12, 0)]), color, 2.2, smooth)
			c.draw_line(center + Vector2(-12, 0), center + Vector2(12, 0), brass, 1.6, smooth)
			c.draw_polyline(PackedVector2Array([center + Vector2(9, -16), center + Vector2(4, -11), center + Vector2(11, -7)]), brass, 2.0, smooth)
		_:
			# An empty slot: the skin ultimate, still to come.
			var star = PackedVector2Array()
			for step in range(9):
				var angle = -PI * 0.5 + step * TAU / 8.0
				star.append(center + Vector2(cos(angle), sin(angle)) * (11.0 if step % 2 == 0 else 4.5))
			c.draw_polyline(star, Color(color, 0.6), 1.6, smooth)
