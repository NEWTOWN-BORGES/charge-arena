extends Control
const Skins = preload("res://scripts/skins.gd")
const GameSettings = preload("res://scripts/game_settings.gd")
const Campaign = preload("res://scripts/campaign.gd")
const STICK_RADIUS = 62.0
const FIRE_RADIUS = 76.0
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
signal difficulty_changed(level: int)
signal guide_changed(on: bool)
signal sensitivity_changed(level: int)
signal level_selected(index: int)
signal next_level_requested
signal levels_requested
signal menu_level_changed(step: int)
const INK = Color("142b32")
const MUTED = Color("8fa8a5")
const WHITE = Color("ede6d2")
const CYAN = Color("72ddc6")
const CORAL = Color("ef947e")
const LIME = Color("dbdf9a")
var menu: PanelContainer
var menu_status: Label
var ip: LineEdit
var back: Button
var replay: Button
var match_data: Dictionary = {}
var team = 0
var mode = "menu"
var network_status = ""
var touches: Dictionary = {}
var move_id = -1
var fire_id = -1
var move_vector = Vector2.ZERO
var touch_fire = false
var move_center = Vector2.ZERO
var fire_center = Vector2.ZERO
var fire_home = Vector2.ZERO
var difficulty_buttons: Array = []
var guide_choice: CheckButton
var sensitivity_choice: OptionButton
var viewer_audio: AudioStreamPlayer
var viewer_sound_pending = false
var font: Font
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
	build_video_menu()
	build_pause_menu()
	build_skins_menu()
	build_pvp_menu()
	build_levels_menu()
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
	titles.add_child(label("SKINS", 25, WHITE, true))
	titles.add_child(label("Arrasta o piloto para o rodar.", 14, MUTED))
	skins_total = label("", 13, CYAN, true)
	skins_total.size_flags_vertical = Control.SIZE_SHRINK_END
	header.add_child(skins_total)
	skins_body = BoxContainer.new()
	skins_body.add_theme_constant_override("separation", 16)
	list.add_child(skins_body)
	build_skin_viewer()
	skins_body.add_child(viewer)
	var details = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 6)
	skins_body.add_child(details)
	skin_name = label("", 26, WHITE, true)
	details.add_child(skin_name)
	skin_weapon = label("", 13, LIME, true)
	details.add_child(skin_weapon)
	skin_bricks = label("", 13, CYAN, true)
	details.add_child(skin_bricks)
	skin_about = label("", 14, MUTED)
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
	thumbs.columns = 3
	thumbs.add_theme_constant_override("h_separation", 10)
	thumbs.add_theme_constant_override("v_separation", 10)
	details.add_child(thumbs)
	for index in range(Skins.CATALOG.size()):
		var thumb = Button.new()
		thumb.custom_minimum_size = Vector2(104, 116)
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
	var camera = Camera3D.new()
	camera.fov = 30
	camera.transform = Transform3D(Basis(), Vector3(0, 1.6, 5.6)).looking_at(Vector3(0, 0.78, 0), Vector3.UP)
	camera.current = true
	viewer_stage.add_child(camera)
	viewer_turntable = Node3D.new()
	viewer_stage.add_child(viewer_turntable)
	viewer_audio = AudioStreamPlayer.new()
	viewer_audio.volume_db = -18
	add_child(viewer_audio)

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
	# A boss not yet beaten is shown in its fighting red; its own colours are the reward.
	viewer_pilot = arena_view.build_player(CORAL if locked else CYAN, 0, preview_index, viewer_turntable, locked)
	viewer_pilot.position = Vector3(0, 0.02, 0)
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

func viewer_input(event: InputEvent) -> void:
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

func viewer_palette() -> Dictionary:
	return Skins.colors(viewer_skin, CORAL, true) if viewer_locked else Skins.colors(viewer_skin, CYAN)

func preview_skin(index: int) -> void:
	preview_index = clampi(index, 0, Skins.CATALOG.size() - 1)
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
	skins_total.text = "BOSSES DERROTADOS: %d / %d" % [skins_progress.unlocked_count() - 1, bosses]
	skin_name.text = entry.name
	skin_weapon.text = "ARMA  ·  " + entry.weapon.to_upper()
	skin_bricks.text = "TIJOLOS  ·  " + entry.bricks.to_upper()
	skin_about.text = entry.about
	# The bar tracks the whole boss collection.
	skin_progress.visible = level > 0
	skin_progress.max_value = bosses
	skin_progress.value = skins_progress.unlocked_count() - 1
	if level == 0:
		skin_state.text = "DE SÉRIE"
	elif open:
		skin_state.text = "DESBLOQUEADA  ·  BOSS DO NÍVEL %d" % level
	else:
		skin_state.text = "BLOQUEADA  ·  DERROTA O BOSS DO NÍVEL %d" % level
	skin_state.add_theme_color_override("font_color", LIME if open else MUTED)
	if skins_progress.selected == preview_index:
		skin_action.text = "EQUIPADA"
	elif open:
		skin_action.text = "EQUIPAR"
	else:
		skin_action.text = "VENCE O NÍVEL %d" % level
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
		skin_swatches.draw_circle(at, 10, items[i][1], true, -1, true)
		skin_swatches.draw_arc(at, 10, 0, TAU, 32, Color(WHITE, 0.3), 1, true)
		skin_swatches.draw_string(font_bold, at + Vector2(17, 5), items[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, WHITE)
	var note = "Paleta própria · ombros na cor da equipa"
	if locked:
		note = "Cores originais reveladas ao derrotar o boss"
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
	var caption = ""
	var color = MUTED
	if locked:
		canvas.draw_circle(Vector2(canvas.size.x * 0.5, 56), 47, Color(0.02, 0.05, 0.06, 0.45), true, -1, true)
		caption = "BOSS NÍVEL %d" % Skins.CATALOG[index].level
	elif skins_progress.selected == index:
		caption = "EQUIPADA"
		color = LIME
	if caption != "":
		var width = font_bold.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		canvas.draw_string(font_bold, Vector2((canvas.size.x - width) * 0.5, 110), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)

func open_skins() -> void:
	reset_touch()
	skins_overlay.show()
	preview_skin(skins_progress.selected if skins_progress != null else 0)

func close_skins() -> void:
	skins_overlay.hide()
	clear_viewer_shots()

func announce_unlock(names: Array) -> void:
	unlock_text = " · ".join(names)
	unlock_timer = 4.0
	queue_redraw()

func _process(dt: float) -> void:
	if unlock_timer > 0:
		unlock_timer = maxf(unlock_timer - dt, 0)
		queue_redraw()
	if skins_overlay.visible and is_instance_valid(viewer_pilot):
		animate_viewer(dt)

func show_pause(value: bool) -> void:
	reset_touch()
	pause_overlay.visible = value
	queue_redraw()

func make_button(text: String, primary: bool) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size.y = 49
	b.add_theme_font_override("font", font_bold)
	b.add_theme_font_size_override("font_size", 16)
	paint_button(b, primary)
	return b

func paint_button(b: Button, primary: bool) -> void:
	b.add_theme_color_override("font_color", INK if primary else WHITE)
	b.add_theme_color_override("font_hover_color", INK if primary else WHITE)
	b.add_theme_color_override("font_pressed_color", INK if primary else WHITE)
	b.add_theme_stylebox_override("normal", style(LIME if primary else Color("203b41"), Color.TRANSPARENT if primary else Color("425a59")))
	b.add_theme_stylebox_override("hover", style(LIME.lightened(0.1) if primary else Color("304e51")))
	b.add_theme_stylebox_override("pressed", style(LIME.darkened(0.2) if primary else Color("426561")))
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
	list.add_theme_constant_override("separation", 11)
	menu.add_child(list)
	# Reading on top, buttons below and the main action last: with the panel anchored to
	# the bottom of the screen, that is where a thumb already rests.
	list.add_child(label("✦  CIRCUITO AURORA", 13, CYAN, true))
	list.add_child(label("CHARGE ARENA", 34, WHITE, true))
	list.add_child(label("Destrói as defesas do rival e marca 3 golos.", 15, MUTED))
	menu_status = label("Toque: esquerda move, direita dispara · PC: A/D + clique", 13, MUTED)
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
		pick.custom_minimum_size.y = 40
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.toggle_mode = true
		pick.button_group = levels
		pick.focus_mode = Control.FOCUS_NONE
		pick.add_theme_font_size_override("font_size", 13)
		pick.add_theme_stylebox_override("pressed", style(LIME))
		pick.add_theme_stylebox_override("hover_pressed", style(LIME.lightened(0.1)))
		pick.add_theme_color_override("font_pressed_color", INK)
		pick.add_theme_color_override("font_hover_pressed_color", INK)
		pick.pressed.connect(func(): difficulty_changed.emit(level))
		level_row.add_child(pick)
		difficulty_buttons.append(pick)
	var extras = HBoxContainer.new()
	extras.add_theme_constant_override("separation", 8)
	list.add_child(extras)
	skins_button = make_button("SKINS", false)
	skins_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	extras.add_child(skins_button)
	skins_button.pressed.connect(open_skins)
	var graphics = make_button("OPÇÕES", false)
	graphics.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	extras.add_child(graphics)
	graphics.pressed.connect(open_video)
	var modes = HBoxContainer.new()
	modes.add_theme_constant_override("separation", 8)
	list.add_child(modes)
	var pvp = make_button("PvP", false)
	pvp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modes.add_child(pvp)
	pvp.pressed.connect(open_pvp)
	var level_list = make_button("NÍVEIS", false)
	level_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modes.add_child(level_list)
	level_list.pressed.connect(open_levels)
	quick_button = make_button("JOGO RÁPIDO", false)
	quick_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modes.add_child(quick_button)
	quick_button.pressed.connect(func(): play_requested.emit())
	campaign_button = make_button("JOGAR NÍVEL 1  →", true)
	campaign_button.custom_minimum_size.y = 66
	campaign_button.add_theme_font_size_override("font_size", 19)
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
	var leave = make_button("VOLTAR", false)
	list.add_child(leave)
	leave.pressed.connect(close_pvp)
	pvp_overlay.hide()

func open_pvp() -> void:
	reset_touch()
	pvp_overlay.show()

func close_pvp() -> void:
	pvp_overlay.hide()

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
	return video_overlay.visible or skins_overlay.visible or pvp_overlay.visible or levels_overlay.visible

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
	centered("NÍVEL %02d / %02d  ·  BOSS %s" % [menu_level + 1, total, Skins.CATALOG[level.boss].name], Vector2(center_x, top + 14), 12, LIME if done else CYAN, true)
	centered(level.name.to_upper(), Vector2(center_x, top + 42), 26, WHITE, true)
	var line = level.challenge if open else "BLOQUEADO · vence o nível anterior"
	centered(("✓  " if done else "") + line, Vector2(center_x, top + 64), 12, LIME if done else MUTED)
	var dots_y = (menu.position.y - 26) if vertical else size.y - 30.0
	for i in range(total):
		var dot = Vector2(center_x + (i - (total - 1) * 0.5) * 18, dots_y)
		if i == menu_level:
			draw_circle(dot, 5, LIME, true, -1, true)
		else:
			draw_circle(dot, 3.5, Color(WHITE, 0.55) if campaign_state.is_unlocked(i) else Color(WHITE, 0.18), true, -1, true)
	# Chevrons at the sides hint that the stadium can be swiped.
	var hint_y = area.get_center().y + (20 if vertical else 0)
	var reach = minf(area.size.x * 0.5 - 22, 330) if vertical else area.size.x * 0.5 - 22
	for step in [-1, 1]:
		var target = menu_level + step
		if target < 0 or target >= total:
			continue
		var tip = Vector2(center_x + step * reach, hint_y)
		draw_polyline(PackedVector2Array([tip + Vector2(-step * 14, -22), tip, tip + Vector2(-step * 14, 22)]), Color(WHITE, 0.55), 4, true)

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
	video_panel.add_child(list)
	list.add_child(label("OPÇÕES", 25, WHITE, true))
	list.add_child(label("Imagem, som e ajudas de jogo.", 15, MUTED))
	quality_choice = video_option(list, "Qualidade", ["Leve · desempenho móvel", "Equilibrado · mais definição", "Refinado · máxima suavização"])
	fps_choice = video_option(list, "Limite de FPS", ["60 FPS", "90 FPS", "120 FPS"])
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
	var done = make_button("VOLTAR AO JOGO", true)
	list.add_child(done)
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
	fps_choice.select([60, 90, 120].find(settings.fps))
	quality_choice.select(settings.quality)
	sync_choice.set_pressed_no_signal(settings.vsync)
	counter_choice.set_pressed_no_signal(settings.show_fps)
	fps_label.visible = settings.show_fps
	video_note.text = "Refinado e Equilibrado preservam os gráficos e reduzem apenas 120→90→60 FPS. Só o perfil Leve pode baixar a resolução 3D."

func emit_video() -> void:
	video_changed.emit([60, 90, 120][fps_choice.selected], quality_choice.selected, sync_choice.button_pressed, counter_choice.button_pressed)

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
	back.position = Vector2(size.x - 130, 27 + safe_top)
	back.size = Vector2(100, 46)
	video_button.position = Vector2(size.x - 242, 27 + safe_top)
	video_button.size = Vector2(100, 46)
	skins_body.vertical = size.y > size.x
	viewer.custom_minimum_size = Vector2(0, 360) if skins_body.vertical else Vector2(420, 440)
	var skins_size = skins_panel.get_combined_minimum_size().max(Vector2(minf(size.x - 48, 640 if skins_body.vertical else 900), 0))
	skins_panel.size = skins_size
	skins_panel.position = (size - skins_size) * 0.5
	var panel_size = video_panel.get_combined_minimum_size().max(Vector2(510, 0))
	video_panel.size = panel_size
	video_panel.position = (size - panel_size) * 0.5
	if is_instance_valid(pause_panel):
		pause_panel.size = pause_panel.get_combined_minimum_size().max(Vector2(420, 0))
		pause_panel.position = (size - pause_panel.size) * 0.5
	move_home = Vector2(130, size.y - safe_bottom - 139)
	move_center = move_home
	fire_home = Vector2(size.x - 130, size.y - safe_bottom - 139)
	fire_center = fire_home
	var menu_height = menu.get_combined_minimum_size().y
	levels_grid.columns = 2 if vertical else 5
	var levels_width = minf(size.x - 48, 660)
	for card in level_cards:
		card.custom_minimum_size = Vector2((levels_width - 46) * 0.5, 104) if vertical else Vector2(164, 172)
	levels_panel.size = levels_panel.get_combined_minimum_size().max(Vector2(levels_width if vertical else 0.0, 0))
	levels_panel.position = thumb_panel_position(levels_panel.size)
	pvp_panel.size = pvp_panel.get_combined_minimum_size().max(Vector2(minf(size.x - 48, 520), 0))
	pvp_panel.position = thumb_panel_position(pvp_panel.size)
	if vertical:
		layout_vertical(menu_height)
	else:
		menu.size = Vector2(450, menu_height)
		menu.position = Vector2(48, maxf(76, size.y - menu.size.y - 40))
		fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		fps_label.size = Vector2.ZERO
		fps_label.position = Vector2(size.x - 260, size.y - 53)
		score_rect = Rect2(size.x * 0.5 - 152, 19, 304, 59)
		card_rects = [Rect2(38, 184, 200, 222), Rect2(size.x - 238, 184, 200, 222)]
		message_center = size * 0.5
		arena_rect = Rect2(Vector2.ZERO, size)
		touch_top = size.y * 0.42
	for result_button in [next_button, replay, levels_button]:
		result_button.size = Vector2(260, 50)
	place_result_buttons()
	queue_redraw()
	layout_changed.emit()

func layout_vertical(menu_height: float) -> void:
	var mid = size.x * 0.5
	var bottom = size.y - safe_bottom
	score_rect = Rect2(mid - 152, safe_top + 86, 304, 59)
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fps_label.size = Vector2(240, 20)
	fps_label.position = Vector2(mid - 120, bottom - (46 if mode == "menu" else 124))
	menu.size = Vector2(minf(size.x - 48, 520), menu_height)
	menu.position = Vector2((size.x - menu.size.x) * 0.5, maxf(safe_top + 150, bottom - menu.size.y - 56))
	if mode == "menu":
		# The previewed level's name sits above its stadium and the page dots below it.
		var top = safe_top + 172
		arena_rect = Rect2(16, top, size.x - 32, maxf(menu.position.y - 48 - top, 120))
	else:
		# Score, opponent card, arena and player card form one block between the header and
		# the thumb controls, with the spare height split evenly above and below.
		var card_h = 104.0
		var free_top = safe_top + 84
		var free_h = (bottom - FIRE_RADIUS - 151) - free_top
		var fixed = 59 + 12 + 2 * (card_h + 10)
		var arena_h = maxf(minf((size.x - 32) / arena_aspect, free_h - fixed), 80)
		score_rect.position.y = free_top + maxf(0, free_h - arena_h - fixed) * 0.5
		var upper = Rect2(24, score_rect.end.y + 12, size.x - 48, card_h)
		arena_rect = Rect2(16, upper.end.y + 10, size.x - 32, arena_h)
		var lower = Rect2(24, arena_rect.end.y + 10, size.x - 48, card_h)
		# Team 0 defends the bottom goal, so each card sits beside its own side of the arena.
		card_rects = [lower, upper] if team == 0 else [upper, lower]
	message_center = arena_rect.get_center()
	touch_top = arena_rect.get_center().y

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
	reset_touch()
	layout()

func reset_touch() -> void:
	touches.clear()
	move_id = -1
	fire_id = -1
	move_vector = Vector2.ZERO
	touch_fire = false
	move_center = move_home
	fire_center = fire_home

func _input(event: InputEvent) -> void:
	if mode == "menu":
		menu_swipe(event)
		return
	if video_overlay.visible or pause_overlay.visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.y < touch_top:
				return
			if event.position.x < size.x * 0.5:
				if move_id < 0:
					move_id = event.index
					move_center = event.position
			elif fire_id < 0:
				# Any press on the lower right fires at once; the button jumps under the thumb.
				fire_id = event.index
				fire_center = event.position
				touch_fire = true
		else:
			if event.index == move_id:
				move_id = -1
				move_vector = Vector2.ZERO
				move_center = move_home
			if event.index == fire_id:
				fire_id = -1
				touch_fire = false
				fire_center = fire_home
	if event is InputEventScreenDrag:
		if event.index == move_id:
			move_vector = ((event.position - move_center) / 58).limit_length()
		if event.index == fire_id:
			fire_center = event.position
	queue_redraw()

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
	match_data = {"players": rules.players, "bricks": rules.bricks, "scores": rules.scores, "phase": rules.phase, "timer": rules.timer, "winner": rules.winner}
	network_status = status
	var finished = mode != "menu" and rules.phase == "finished" and mode != "client"
	var in_campaign = not level_info.is_empty()
	replay.visible = finished
	replay.text = ("REPETIR NÍVEL" if level_result == "won" else "TENTAR DE NOVO") if in_campaign else "JOGAR NOVAMENTE"
	next_button.visible = finished and in_campaign and level_result == "won" and level_info.get("has_next", false)
	# Only one bright button at a time: replay steps back when a next level is offered.
	paint_button(replay, not next_button.visible)
	levels_button.visible = finished and in_campaign
	place_result_buttons()
	queue_redraw()

func portrait(center: Vector2, color: Color, stunned: bool, skin: int = 0, canvas: CanvasItem = null, tint: bool = false) -> void:
	# `canvas` lets the skins panel draw the same avatar inside its own preview controls.
	var c: CanvasItem = canvas if canvas != null else self
	c.draw_circle(center, 46, Color(color, 0.055), true, -1, true)
	c.draw_arc(center, 45, 0.2, TAU - 0.2, 64, Color(color, 0.28), 1.2, true)
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
	c.draw_circle(center + Vector2(-31, -2), 9, Color("bda579"), true, -1, true)
	c.draw_circle(center + Vector2(31, -2), 9, Color("bda579"), true, -1, true)
	c.draw_style_box(style(WHITE, Color.TRANSPARENT, 22), Rect2(center + Vector2(-32, -29), Vector2(64, 55)))
	c.draw_style_box(style(INK, Color.TRANSPARENT, 12), Rect2(center + Vector2(-27, -10), Vector2(54, 24)))
	c.draw_style_box(style(color, Color.TRANSPARENT, 3), Rect2(center + Vector2(-4, -29), Vector2(8, 13)))
	for side in [-1, 1]:
		var p = center + Vector2(side * 12, 1)
		if stunned:
			c.draw_line(p - Vector2(3, 3), p + Vector2(3, 3), LIME, 2, true)
			c.draw_line(p - Vector2(-3, 3), p + Vector2(-3, 3), LIME, 2, true)
		else:
			c.draw_style_box(style(color.lightened(0.2), Color.TRANSPARENT, 2), Rect2(p - Vector2(2, 4), Vector2(4, 8)))

func lighthouse_portrait(c: CanvasItem, center: Vector2, glow: Color, stunned: bool) -> void:
	# Faroleiro: beacon gem on a brass mast, side lamps, tall dome, brass band and one visor slit.
	var brass = Color("d2ad73")
	c.draw_line(center + Vector2(0, -31), center + Vector2(0, -41), brass, 3, true)
	c.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -50), center + Vector2(6, -43), center + Vector2(0, -36), center + Vector2(-6, -43)]), brass.lightened(0.15))
	for side in [-1, 1]:
		c.draw_circle(center + Vector2(side * 31, -2), 9, brass, true, -1, true)
		c.draw_circle(center + Vector2(side * 32, -2), 4.5, glow, true, -1, true)
	c.draw_style_box(style(WHITE, Color.TRANSPARENT, 28), Rect2(center + Vector2(-30, -35), Vector2(60, 61)))
	c.draw_style_box(style(brass, Color.TRANSPARENT, 2), Rect2(center + Vector2(-31, 13), Vector2(62, 5)))
	c.draw_style_box(style(INK, Color.TRANSPARENT, 9), Rect2(center + Vector2(-26, -9), Vector2(52, 19)))
	if stunned:
		for side in [-1, 1]:
			var p = center + Vector2(side * 12, 0)
			c.draw_line(p - Vector2(3, 3), p + Vector2(3, 3), LIME, 2, true)
			c.draw_line(p - Vector2(-3, 3), p + Vector2(-3, 3), LIME, 2, true)
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
	c.draw_polyline(orbit_points(orbit_center, PI, TAU), brass, 2, true)
	for side in [-1, 1]:
		c.draw_circle(center + Vector2(side * 31, -2), 9, palette.body.lightened(0.1), true, -1, true)
	c.draw_style_box(style(WHITE, Color.TRANSPARENT, 22), Rect2(center + Vector2(-32, -29), Vector2(64, 55)))
	c.draw_style_box(style(INK, Color.TRANSPARENT, 12), Rect2(center + Vector2(-27, -10), Vector2(54, 24)))
	c.draw_circle(center + Vector2(13, 1), 8, brass, true, -1, true)
	if stunned:
		for p in [center + Vector2(-12, 1), center + Vector2(13, 1)]:
			c.draw_line(p - Vector2(3, 3), p + Vector2(3, 3), LIME, 2, true)
			c.draw_line(p - Vector2(-3, 3), p + Vector2(-3, 3), LIME, 2, true)
	else:
		c.draw_style_box(style(glow, Color.TRANSPARENT, 2), Rect2(center + Vector2(-14, -3), Vector2(4, 8)))
		c.draw_circle(center + Vector2(13, 1), 4, glow, true, -1, true)
	c.draw_polyline(orbit_points(orbit_center, 0, PI), brass, 2, true)
	c.draw_circle(orbit_points(orbit_center, 0.55, 0.55)[0], 5, glow, true, -1, true)
	c.draw_circle(orbit_points(orbit_center, 2.5, 2.5)[0], 3.5, team_color, true, -1, true)

func avatar_eyes(c: CanvasItem, center: Vector2, glow: Color, stunned: bool, spread: float = 12) -> void:
	for side in [-1, 1]:
		var p = center + Vector2(side * spread, 1)
		if stunned:
			c.draw_line(p - Vector2(3, 3), p + Vector2(3, 3), LIME, 2, true)
			c.draw_line(p - Vector2(-3, 3), p + Vector2(-3, 3), LIME, 2, true)
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
	c.draw_line(center + Vector2(0, -22), center + Vector2(0, -32), leaf.darkened(0.2), 2, true)
	c.draw_circle(center + Vector2(-5, -33), 4.5, leaf, true, -1, true)
	c.draw_circle(center + Vector2(5, -35), 4.5, leaf, true, -1, true)
	c.draw_circle(center + Vector2(0, -6), 40, Color(0.82, 0.96, 0.92, 0.16), true, -1, true)
	c.draw_arc(center + Vector2(0, -6), 40, 0, TAU, 64, Color(0.82, 0.96, 0.92, 0.85), 2.0, true)
	c.draw_arc(center + Vector2(0, -6), 33, PI * 1.1, PI * 1.45, 16, Color(WHITE, 0.6), 2.5, true)

func miner_portrait(c: CanvasItem, center: Vector2, palette: Dictionary, stunned: bool) -> void:
	# Mineiro: hard hat with brim and headlamp over the classic helmet.
	var steel = Color("9aa1ab")
	c.draw_style_box(style(palette.body, Color.TRANSPARENT, 14), Rect2(center + Vector2(-24, 15), Vector2(48, 24)))
	for side in [-1, 1]:
		c.draw_circle(center + Vector2(side * 31, -2), 9, steel, true, -1, true)
	c.draw_style_box(style(WHITE, Color.TRANSPARENT, 22), Rect2(center + Vector2(-32, -29), Vector2(64, 55)))
	c.draw_style_box(style(INK, Color.TRANSPARENT, 12), Rect2(center + Vector2(-27, -10), Vector2(54, 24)))
	avatar_eyes(c, center, palette.light, stunned)
	c.draw_style_box(style(palette.body, Color.TRANSPARENT, 16), Rect2(center + Vector2(-34, -44), Vector2(68, 30)))
	c.draw_style_box(style(palette.body.darkened(0.15), Color.TRANSPARENT, 3), Rect2(center + Vector2(-40, -18), Vector2(80, 6)))
	c.draw_circle(center + Vector2(0, -30), 7, Color("d2ad73"), true, -1, true)
	c.draw_circle(center + Vector2(0, -30), 4, palette.light, true, -1, true)

func sentinel_portrait(c: CanvasItem, center: Vector2, palette: Dictionary, stunned: bool) -> void:
	# Sentinela: eclipse halo behind the helmet, gold crest and a stern pair of eye slits.
	var brass = Color("d2ad73")
	c.draw_arc(center + Vector2(0, -6), 41, 0, TAU, 72, brass, 3, true)
	c.draw_arc(center + Vector2(0, -6), 36, 0, TAU, 72, Color(palette.light, 0.8), 1.5, true)
	c.draw_style_box(style(palette.body, Color.TRANSPARENT, 14), Rect2(center + Vector2(-24, 15), Vector2(48, 24)))
	c.draw_style_box(style(brass, Color.TRANSPARENT, 2), Rect2(center + Vector2(-24, 15), Vector2(48, 4)))
	for side in [-1, 1]:
		c.draw_circle(center + Vector2(side * 31, -2), 9, brass, true, -1, true)
	c.draw_style_box(style(WHITE, Color.TRANSPARENT, 22), Rect2(center + Vector2(-32, -29), Vector2(64, 55)))
	c.draw_style_box(style(INK, Color.TRANSPARENT, 12), Rect2(center + Vector2(-27, -10), Vector2(54, 24)))
	c.draw_style_box(style(brass, Color.TRANSPARENT, 2), Rect2(center + Vector2(-3, -33), Vector2(6, 12)))
	if stunned:
		avatar_eyes(c, center, palette.light, true)
	else:
		for side in [-1, 1]:
			c.draw_line(center + Vector2(side * 19, -2), center + Vector2(side * 8, 2), palette.light, 3, true)

func stun_cross(c: CanvasItem, p: Vector2) -> void:
	c.draw_line(p - Vector2(3, 3), p + Vector2(3, 3), LIME, 2, true)
	c.draw_line(p - Vector2(-3, 3), p + Vector2(-3, 3), LIME, 2, true)

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
		c.draw_circle(gear + Vector2(cos(angle), sin(angle)) * 13, 4, brass, true, -1, true)
	c.draw_circle(gear, 13, palette.body, true, -1, true)
	c.draw_circle(gear + Vector2(0, -5), 4, palette.light, true, -1, true)
	for side in [-1, 1]:
		c.draw_circle(center + Vector2(side * 31, -2), 9, brass, true, -1, true)
		c.draw_circle(center + Vector2(side * 31, -2), 3, palette.body, true, -1, true)
	helmet(c, center)
	c.draw_circle(center + Vector2(13, 1), 10, brass, true, -1, true)
	if stunned:
		stun_cross(c, center + Vector2(-12, 1))
		stun_cross(c, center + Vector2(13, 1))
	else:
		c.draw_style_box(style(palette.light, Color.TRANSPARENT, 2), Rect2(center + Vector2(-14, -3), Vector2(4, 8)))
		c.draw_circle(center + Vector2(13, 1), 6, palette.light, true, -1, true)

func storm_portrait(c: CanvasItem, center: Vector2, palette: Dictionary, stunned: bool) -> void:
	# Caça-Trovões: lightning rod with a glowing tip and a bolt, rain-yellow collar, wide eye bars.
	var brass = Color("d2ad73")
	var yellow = Color("e0b84a")
	c.draw_style_box(style(yellow, Color.TRANSPARENT, 14), Rect2(center + Vector2(-24, 15), Vector2(48, 24)))
	c.draw_line(center + Vector2(0, -27), center + Vector2(0, -42), brass, 3, true)
	c.draw_circle(center + Vector2(0, -46), 5, palette.light, true, -1, true)
	c.draw_polyline(PackedVector2Array([center + Vector2(9, -52), center + Vector2(15, -43), center + Vector2(10, -42), center + Vector2(17, -33)]), palette.light, 2, true)
	for side in [-1, 1]:
		c.draw_circle(center + Vector2(side * 31, -2), 9, Color("9aa1ab"), true, -1, true)
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
	c.draw_line(center + Vector2(-32, 1), center + Vector2(32, 1), Color("3a2a20"), 4, true)
	for side in [-1, 1]:
		var p = center + Vector2(side * 12, 1)
		c.draw_circle(p, 9, brass, true, -1, true)
		c.draw_circle(p, 6, INK if stunned else palette.light, true, -1, true)
		if stunned:
			stun_cross(c, p)
	for bubble in [[Vector2(-6, -40), 4.0], [Vector2(5, -47), 3.0], [Vector2(-2, -54), 2.2]]:
		c.draw_circle(center + bubble[0], bubble[1], Color(palette.light, 0.85), true, -1, true)

func corsair_portrait(c: CanvasItem, center: Vector2, palette: Dictionary, stunned: bool) -> void:
	# Corsário: tricorn with a gem, gold ear rings, an eye patch and one glowing eye.
	var brass = Color("d2ad73")
	var patch = Color("141e24")
	c.draw_style_box(style(palette.body, Color.TRANSPARENT, 14), Rect2(center + Vector2(-24, 15), Vector2(48, 24)))
	for side in [-1, 1]:
		c.draw_circle(center + Vector2(side * 31, -2), 9, brass, true, -1, true)
	helmet(c, center)
	c.draw_line(center + Vector2(-30, 9), center + Vector2(20, -22), patch, 3, true)
	c.draw_circle(center + Vector2(-12, 1), 7, patch, true, -1, true)
	c.draw_arc(center + Vector2(-12, 1), 7.5, 0, TAU, 24, brass, 1.2, true)
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
	c.draw_polyline(trim, brass, 2, true)
	c.draw_circle(center + Vector2(0, -36), 3.5, palette.light, true, -1, true)

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
		c.draw_circle(center + Vector2(side * 31, -2), 9, brass, true, -1, true)
	helmet(c, center)
	c.draw_style_box(style(brass, Color.TRANSPARENT, 3), Rect2(center + Vector2(-27, -31), Vector2(54, 7)))
	c.draw_circle(center + Vector2(0, -27), 4, palette.light, true, -1, true)
	avatar_eyes(c, center, palette.light, stunned)

func player_card(rect: Rect2, side: int, t: int) -> void:
	# Tall side cards in landscape; wide strips beside each goal in portrait.
	var color = CYAN if t == 0 else CORAL
	var at = rect.position
	panel(rect)
	var role = "TU" if side == 0 else ("ADVERSÁRIO / IA" if mode == "pve" else "ADVERSÁRIO")
	if side == 1 and not level_info.is_empty():
		role = "BOSS · NÍVEL %d" % level_info.number
	var pilot = "NOVA" if t == 0 else "EMBER"
	if side == 1 and not level_info.is_empty():
		pilot = level_info.boss_name
	var bricks_at = at + (Vector2(124, 56) if vertical else Vector2(23, 172))
	var count = 0
	var health = 0
	var per_team: int = match_data.bricks.size() / 2
	for i in range(per_team):
		var data: Dictionary = match_data.bricks[t * per_team + i]
		var alive: bool = data.alive
		if alive:
			count += 1
		health += data.hp
		var brick = Rect2(bricks_at + Vector2((i % 10) * 16, floori(i / 10.0) * 6), Vector2(12, 4))
		draw_style_box(style(color.darkened((3 - data.hp) * 0.22) if alive else Color("284349"), Color.TRANSPARENT, 1), brick)
	var status = "BALIZA ABERTA" if count == 0 else str(count) + " TIJOLOS  ·  " + str(health) + "/120"
	var status_color = LIME if count == 0 else MUTED
	var stunned: bool = match_data.players[t].stun > 0
	var tips = [["Move-te para apontar", WHITE, false], ["Disparo sempre em frente", MUTED, false]]
	if side == 1:
		tips = [["BOOST: 2 NOS TIJOLOS", LIME, true], ["5 acertos · pausa 0,5 s", MUTED, false]]
	if vertical:
		write(role, at + Vector2(124, 22), 10, MUTED, true)
		portrait(at + Vector2(62, 56), color, stunned, team_skins[t], null, team_tints[t])
		write(pilot, at + Vector2(124, 48), 22, WHITE, true)
		player_life_bar(Vector2(at.x + 124, at.y + 82), match_data.players[t].hp, color)
		write(status, at + Vector2(124, 101), 10, status_color, true)
		draw_line(at + Vector2(318, 18), at + Vector2(318, rect.size.y - 18), Color("334f51"), 1, true)
		write(tips[0][0], at + Vector2(340, 46), 13, tips[0][1], tips[0][2])
		write(tips[1][0], at + Vector2(340, 70), 12, tips[1][1], tips[1][2])
	else:
		var center = at.x + 100
		write(role, at + Vector2(17, 24), 10, MUTED, true)
		portrait(Vector2(center, at.y + 85), color, stunned, team_skins[t], null, team_tints[t])
		centered(pilot, Vector2(center, at.y + 146), 22, WHITE, true)
		player_life_bar(Vector2(center - 47, at.y + 158), match_data.players[t].hp, color)
		centered(status, Vector2(center, at.y + 210), 10, status_color, true)
		var tip_x = 49.0 if side == 0 else size.x - 221
		write(tips[0][0], Vector2(tip_x, 437), 13, tips[0][1], tips[0][2])
		write(tips[1][0], Vector2(tip_x, 461), 12, tips[1][1], tips[1][2])

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
	draw_circle(Vector2(49, 47) + top, 19, Color(CYAN, 0.1), true, -1, true)
	var bolt = PackedVector2Array([Vector2(54, 32) + top, Vector2(40, 49) + top, Vector2(52, 49) + top, Vector2(44, 62) + top])
	draw_polyline(bolt, CYAN, 2.5, true)
	write("CHARGE ARENA", Vector2(82, 44) + top, 17, WHITE, true)
	write("C I R C U I T O   A U R O R A", Vector2(82, 62) + top, 9, MUTED)
	write("ARENA 01   /   AURORA", Vector2(34, bottom - 24), 10, MUTED)
	write("ENCONTRA O TEU ÂNGULO", Vector2(size.x - 204, bottom - 24), 10, MUTED)
	if mode == "menu":
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
	draw_circle(s + Vector2(23, 30), 4, CYAN, true, -1, true)
	write("NOVA", s + Vector2(36, 35), 12, CYAN, true)
	centered(str(match_data.scores[0]) + "  :  " + str(match_data.scores[1]), Vector2(score_rect.get_center().x, s.y + 41), 31, WHITE, true)
	write("EMBER", s + Vector2(218, 35), 12, CORAL, true)
	draw_circle(s + Vector2(284, 30), 4, CORAL, true, -1, true)
	var mode_at = Vector2(24, score_rect.position.y + 24) if vertical else Vector2(38, 116)
	var mode_name = "TREINO / PvE" if mode == "pve" else "DUELO / PvP"
	if not level_info.is_empty():
		mode_name = "CAMPANHA · NÍVEL %d" % level_info.number
	write(mode_name, mode_at, 12, LIME, true)
	write("PRIMEIRO A 3 GOLOS", mode_at + Vector2(0, 22 if vertical else 23), 10, MUTED)
	for side in range(2):
		player_card(card_rects[side], side, team if side == 0 else 1 - team)
	var p: Dictionary = match_data.players[team]
	if p.stun > 0:
		panel(Rect2(mid - 130, bottom - 77, 260, 36))
		centered("PARALISADO   %.1f s" % p.stun, Vector2(mid, bottom - 53), 15, LIME, true)
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
		sub = "PRIMEIRO A 3 GOLOS"
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
	for which in range(2):
		var center = move_center if which == 0 else fire_center
		var color = CYAN if which == 0 else LIME
		var radius = STICK_RADIUS if which == 0 else FIRE_RADIUS
		draw_circle(center, radius, Color(0.08, 0.15, 0.16, 0.85), true, -1, true)
		draw_arc(center, radius, 0, TAU, 80, Color(color, 0.2), 1.2, true)
		draw_arc(center, radius - 10, 0.2, PI - 0.2, 40, Color(color, 0.07), 5, true)
		draw_arc(center, radius - 10, PI + 0.2, TAU - 0.2, 40, Color(color, 0.07), 5, true)
		var offset = move_vector * 39 if which == 0 else Vector2.ZERO
		draw_circle(center + offset + Vector2(0, 3), 24, Color(0.02, 0.05, 0.06, 0.45), true, -1, true)
		draw_circle(center + offset, 24 if which == 0 else 46, color.darkened(0.15 if which == 1 and touch_fire else 0.55), true, -1, true)
		draw_arc(center + offset, 24, 0, TAU, 48, Color(color, 0.65), 1.2, true)
		if which == 0:
			draw_circle(center + offset, 3, color, true, -1, true)
		else:
			var shot_icon = PackedVector2Array([center + Vector2(7, -22), center + Vector2(-11, 2), center + Vector2(7, 2), center + Vector2(-7, 22)])
			draw_polyline(shot_icon, WHITE, 3.5, true)
		centered("MOVER NO ARCO" if which == 0 else "DISPARAR", center + Vector2(0, 99), 10, color, true)
