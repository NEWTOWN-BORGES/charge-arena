extends Control
## The lobby. The equipped pilot stands in the arena behind this layer, lit and turning
## slowly; everything else is arranged around it the way a game lobby is: who you are and
## what you have across the top, the hangar, powers, story and PvP down the left, and the
## mode with its big PLAY key at the bottom, where the thumb already rests.
const Campaign = preload("res://scripts/campaign.gd")
const Skins = preload("res://scripts/skins.gd")
const Powers = preload("res://scripts/powers.gd")
const GameSettings = preload("res://scripts/game_settings.gd")

const YELLOW = Color("ffd23f")
const GLASS = Color(0.025, 0.07, 0.09, 0.78)
const MODES = {
	"campanha": {"title": "CAMPANHA", "about": "Bosses e postos, nível a nível", "icon": "campaign"},
	"rapido": {"title": "JOGO RÁPIDO", "about": "Uma partida contra a IA, já", "icon": "quick"},
	"historia": {"title": "MODO HISTÓRIA", "about": "A Taça Aurora, combate a combate", "icon": "story"},
	"pvp": {"title": "PvP", "about": "Dois jogadores na mesma rede, ou o Coliseu", "icon": "pvp"},
}
const MODE_ORDER = ["campanha", "rapido", "historia", "pvp"]

var hud
var lobby_mode = "campanha"
var profile: Button
var wallet: Button
var settings: Button
var skins_button: Button
var powers_button: Button
var story_button: Button
var pvp_button: Button
var play: Button
var mode_card: Button
var level_row: Control
var level_prev: Button
var level_next: Button
var level_title: Label
var pilot_name: Label
var pilot_caption: Label
var status: Label
var difficulty_row: HBoxContainer
var difficulty_buttons: Array = []
var sheet: ColorRect
var sheet_list: VBoxContainer
var sheet_cards: Dictionary = {}
var levels_link: Button
var quick_button: Button
# Where the pilot stands on screen and how tall it is drawn, read by the arena camera.
var focus = Vector2.ZERO
var pilot_height = 520.0
var vertical = true
var bottom_top = 0.0

func build(owner_hud) -> void:
	hud = owner_hud
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Across the top: the pilot you fly as, the bricks you hold, and the options.
	profile = flat_button(func(): hud.open_skins())
	add_child(profile)
	paint_face(profile, draw_profile)
	wallet = flat_button(func(): hud.open_powers())
	add_child(wallet)
	paint_face(wallet, draw_wallet)
	settings = flat_button(func(): hud.open_video())
	settings.tooltip_text = "Opções"
	add_child(settings)
	paint_face(settings, func(c): glyph(c, "settings", c.size * 0.5, 17, hud.WHITE))
	# Down the left: the rail.
	skins_button = rail_button("HANGAR", "hangar", func(): hud.open_skins())
	powers_button = rail_button("PODERES", "powers", func(): hud.open_powers())
	story_button = rail_button("HISTÓRIA", "story", func(): hud.cup_requested.emit())
	pvp_button = rail_button("PvP", "pvp", func(): hud.open_pvp())
	# The name of the pilot, under its feet.
	pilot_name = hud.label("", 46, hud.WHITE, true)
	pilot_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pilot_name.add_theme_constant_override("outline_size", 8)
	pilot_name.add_theme_color_override("font_outline_color", Color(0.0, 0.03, 0.05, 0.7))
	add_child(pilot_name)
	pilot_caption = hud.label("PILOTO EQUIPADO  ·  TOCA NO PERFIL PARA MUDAR", 13, Color(hud.CYAN, 0.9), true)
	pilot_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(pilot_caption)
	# News and messages: one line over the controls.
	status = hud.label(hud.MENU_HINT, 15, hud.MUTED, true)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.clip_text = true
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(status)
	# The AI: three chips.
	difficulty_row = HBoxContainer.new()
	difficulty_row.add_theme_constant_override("separation", 8)
	add_child(difficulty_row)
	var caption = hud.label("IA", 15, hud.MUTED, true)
	caption.custom_minimum_size.x = 34
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	difficulty_row.add_child(caption)
	var levels = ButtonGroup.new()
	for level in range(GameSettings.DIFFICULTIES.size()):
		var pick = Button.new()
		pick.text = GameSettings.DIFFICULTIES[level]
		pick.toggle_mode = true
		pick.button_group = levels
		pick.focus_mode = Control.FOCUS_NONE
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.add_theme_font_override("font", hud.font_bold)
		pick.add_theme_font_size_override("font_size", 17)
		for state in ["normal", "hover", "disabled"]:
			pick.add_theme_stylebox_override(state, chip(Color(0.03, 0.08, 0.1, 0.7), Color(hud.CYAN, 0.22)))
		for state in ["pressed", "hover_pressed"]:
			pick.add_theme_stylebox_override(state, chip(Color(hud.CYAN, 0.9), Color(hud.CYAN, 1.0)))
		pick.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		pick.add_theme_color_override("font_color", hud.MUTED)
		pick.add_theme_color_override("font_hover_color", hud.WHITE)
		pick.add_theme_color_override("font_pressed_color", hud.INK)
		pick.add_theme_color_override("font_hover_pressed_color", hud.INK)
		pick.pressed.connect(func(): hud.difficulty_changed.emit(level))
		difficulty_row.add_child(pick)
		difficulty_buttons.append(pick)
	# Campaign only: which level, with a step either way.
	level_row = Control.new()
	level_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(level_row)
	level_prev = arrow_button(-1)
	level_row.add_child(level_prev)
	level_next = arrow_button(1)
	level_row.add_child(level_next)
	level_title = hud.label("", 19, hud.WHITE, true)
	level_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_title.clip_text = true
	level_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	level_row.add_child(level_title)
	# The bottom: the mode and the key that starts it.
	mode_card = flat_button(open_sheet)
	mode_card.add_theme_stylebox_override("normal", glass_style(Color(hud.CYAN, 0.35), 3))
	add_child(mode_card)
	paint_face(mode_card, draw_mode_card)
	play = hud.make_button("JOGAR", true)
	play.add_theme_font_size_override("font_size", 40)
	play.add_theme_stylebox_override("disabled", hud.key_style(Color("26363b"), Color("172226")))
	play.add_theme_color_override("font_disabled_color", hud.MUTED)
	play.pressed.connect(start_mode)
	add_child(play)
	build_sheet()
	refresh_mode()

func flat_button(action: Callable) -> Button:
	var b = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", glass_style(Color(hud.CYAN, 0.18)))
	b.add_theme_stylebox_override("hover", glass_style(Color(hud.CYAN, 0.45)))
	b.add_theme_stylebox_override("pressed", glass_style(Color(hud.CYAN, 0.8), 1, Color(0.05, 0.14, 0.17, 0.9)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("disabled", glass_style(Color(hud.CYAN, 0.1)))
	b.pressed.connect(action)
	return b

func glass_style(border: Color, bottom: int = 3, fill: Color = GLASS) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(1)
	s.border_width_bottom = bottom
	s.set_corner_radius_all(14)
	s.corner_detail = 8
	s.anti_aliasing = true
	s.shadow_color = Color(0, 0.02, 0.03, 0.45)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 4)
	s.set_content_margin_all(10)
	return s

func chip(fill: Color, border: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(22)
	s.corner_detail = 8
	s.anti_aliasing = true
	s.content_margin_left = 10
	s.content_margin_right = 10
	return s

func paint_face(button: Button, painter: Callable) -> Control:
	# Buttons here draw their own faces: icons, portraits and two-line captions.
	var face = Control.new()
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.draw.connect(func(): painter.call(face))
	button.add_child(face)
	button.set_meta("face", face)
	return face

func redraw() -> void:
	for b in [profile, wallet, settings, skins_button, powers_button, story_button, pvp_button, mode_card]:
		if b != null and b.has_meta("face"):
			b.get_meta("face").queue_redraw()
	queue_redraw()

func rail_button(title: String, icon: String, action: Callable) -> Button:
	var b = flat_button(action)
	b.set_meta("title", title)
	b.set_meta("icon", icon)
	b.set_meta("badge", "")
	b.set_meta("fresh", false)
	# The text itself is kept for the tests and screen readers; the face draws it.
	b.text = title
	b.clip_text = true
	b.add_theme_color_override("font_color", Color.TRANSPARENT)
	b.add_theme_color_override("font_hover_color", Color.TRANSPARENT)
	b.add_theme_color_override("font_pressed_color", Color.TRANSPARENT)
	add_child(b)
	paint_face(b, func(c): draw_rail(c, b))
	return b

func arrow_button(step: int) -> Button:
	var b = flat_button(func(): hud.menu_level_changed.emit(step))
	b.set_meta("step", step)
	paint_face(b, func(c):
		var mid: Vector2 = c.size * 0.5
		var dir = float(step)
		c.draw_polyline(PackedVector2Array([mid + Vector2(-dir * 6, -11), mid + Vector2(dir * 6, 0), mid + Vector2(-dir * 6, 11)]), hud.WHITE if not b.disabled else Color(hud.WHITE, 0.25), 3.2, true))
	return b

func build_sheet() -> void:
	# The mode chooser: full screen, one big card per way to play.
	sheet = ColorRect.new()
	sheet.color = Color(0.01, 0.03, 0.04, 0.94)
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sheet)
	sheet_list = VBoxContainer.new()
	sheet_list.add_theme_constant_override("separation", 14)
	sheet.add_child(sheet_list)
	var title = hud.label("ESCOLHE O MODO", 38, hud.WHITE, true)
	sheet_list.add_child(title)
	sheet_list.add_child(hud.label("O modo escolhido fica no lobby: depois é só carregar em JOGAR.", 16, hud.MUTED))
	for id in MODE_ORDER:
		var card = flat_button(func(): choose_mode(id))
		card.custom_minimum_size.y = 118
		card.set_meta("mode", id)
		sheet_list.add_child(card)
		paint_face(card, func(c): draw_mode_entry(c, id))
		sheet_cards[id] = card
	quick_button = sheet_cards["rapido"]
	quick_button.text = "JOGO RÁPIDO"
	quick_button.clip_text = true
	quick_button.add_theme_color_override("font_color", Color.TRANSPARENT)
	quick_button.add_theme_color_override("font_hover_color", Color.TRANSPARENT)
	quick_button.add_theme_color_override("font_pressed_color", Color.TRANSPARENT)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	sheet_list.add_child(row)
	levels_link = hud.make_button("TODOS OS NÍVEIS", false)
	levels_link.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	levels_link.pressed.connect(func(): close_sheet(); hud.open_levels())
	row.add_child(levels_link)
	var back = hud.make_button("VOLTAR", false)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(close_sheet)
	row.add_child(back)
	sheet.hide()

func open_sheet() -> void:
	hud.reset_touch()
	sheet.show()
	for card in sheet_cards.values():
		card.get_meta("face").queue_redraw()

func close_sheet() -> void:
	sheet.hide()

func choose_mode(id: String) -> void:
	lobby_mode = id
	close_sheet()
	refresh_mode()

func start_mode() -> void:
	match lobby_mode:
		"campanha":
			hud.level_selected.emit(hud.menu_level)
		"rapido":
			hud.play_requested.emit()
		"historia":
			hud.cup_requested.emit()
		"pvp":
			hud.open_pvp()

func refresh_mode() -> void:
	var campaign = lobby_mode == "campanha"
	level_row.visible = campaign
	difficulty_row.visible = lobby_mode != "pvp"
	if campaign:
		var visible_levels = Campaign.menu_levels()
		var page = visible_levels.find(hud.menu_level)
		var open = hud.campaign_state == null or hud.campaign_state.is_unlocked(hud.menu_level)
		var level: Dictionary = Campaign.LEVELS[hud.menu_level]
		level_title.text = "NÍVEL %02d / %02d  ·  %s" % [page + 1, visible_levels.size(), String(level.name).to_upper()]
		level_prev.disabled = page <= 0
		level_next.disabled = page >= visible_levels.size() - 1
		play.text = "JOGAR" if open else "BLOQUEADO"
		play.disabled = not open
	else:
		play.text = "JOGAR"
		play.disabled = false
	redraw()

func refresh_news(fresh_skins: bool, buyable: bool, skins_count: String, powers_count: String) -> void:
	skins_button.set_meta("badge", skins_count)
	skins_button.set_meta("fresh", fresh_skins)
	powers_button.set_meta("badge", powers_count)
	powers_button.set_meta("fresh", buyable)
	skins_button.text = "HANGAR  %s%s" % [skins_count, "  •" if fresh_skins else ""]
	powers_button.text = "PODERES  %s%s" % [powers_count, "  •" if buyable else ""]
	redraw()

func refresh_pilot() -> void:
	var skin: int = hud.skins_progress.selected if hud.skins_progress != null else 0
	pilot_name.text = String(Skins.CATALOG[clampi(skin, 0, Skins.CATALOG.size() - 1)].name).to_upper()
	redraw()

func arrange(screen: Vector2, safe_top: float, safe_bottom: float, tall: bool) -> void:
	vertical = tall
	var margin = 20.0
	var bottom = screen.y - safe_bottom
	var top = safe_top + 16.0
	# Top bar.
	profile.position = Vector2(margin, top)
	profile.size = Vector2(minf(330.0, screen.x * 0.46), 84)
	settings.position = Vector2(screen.x - margin - 64, top + 10)
	settings.size = Vector2(64, 64)
	wallet.position = Vector2(settings.position.x - 12 - 150, top + 14)
	wallet.size = Vector2(150, 56)
	# Rail.
	var rail_top = top + 84 + (34.0 if tall else 24.0)
	var rail_size = Vector2(98, 104) if tall else Vector2(92, 96)
	var rail_gap = 14.0 if tall else 10.0
	for index in range(4):
		var b: Button = [skins_button, powers_button, story_button, pvp_button][index]
		b.position = Vector2(margin, rail_top + index * (rail_size.y + rail_gap))
		b.size = rail_size
	# Bottom block, laid out upwards from the thumb.
	var block_h = 108.0
	if tall:
		var width = screen.x - margin * 2
		mode_card.position = Vector2(margin, bottom - margin - block_h)
		mode_card.size = Vector2(width * 0.6 - 6, block_h)
		play.position = Vector2(margin + width * 0.6 + 6, bottom - margin - block_h)
		play.size = Vector2(width * 0.4 - 6, block_h)
		level_row.position = Vector2(margin, mode_card.position.y - 14 - 56)
		level_row.size = Vector2(width, 56)
		difficulty_row.position = Vector2(margin, level_row.position.y - 12 - 46)
		difficulty_row.size = Vector2(width, 46)
		status.position = Vector2(margin, difficulty_row.position.y - 38)
		status.size = Vector2(width, 26)
		bottom_top = status.position.y
		pilot_caption.position = Vector2(0, status.position.y - 34)
		pilot_caption.size = Vector2(screen.x, 20)
		pilot_name.position = Vector2(0, pilot_caption.position.y - 58)
		pilot_name.size = Vector2(screen.x, 56)
		# The pilot fills the band between the top bar and its own name.
		var band_top = top + 84 + 20
		var band_bottom = pilot_name.position.y + 4
		pilot_height = clampf((band_bottom - band_top) * 0.82, 260, 600)
		focus = Vector2(screen.x * 0.56, band_bottom - 16 - pilot_height * 0.5)
	else:
		play.size = Vector2(300, block_h)
		play.position = Vector2(screen.x - margin - 300, bottom - margin - block_h)
		mode_card.size = Vector2(380, block_h)
		mode_card.position = Vector2(play.position.x - 12 - 380, play.position.y)
		var width = play.position.x + play.size.x - mode_card.position.x
		level_row.position = Vector2(mode_card.position.x, mode_card.position.y - 12 - 52)
		level_row.size = Vector2(width, 52)
		difficulty_row.position = Vector2(mode_card.position.x, level_row.position.y - 10 - 44)
		difficulty_row.size = Vector2(width, 44)
		status.position = Vector2(mode_card.position.x, difficulty_row.position.y - 32)
		status.size = Vector2(width, 24)
		bottom_top = status.position.y
		pilot_name.position = Vector2(margin + rail_size.x + 30, bottom - margin - 96)
		pilot_name.size = Vector2(mode_card.position.x - pilot_name.position.x - 20, 56)
		pilot_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		pilot_caption.position = pilot_name.position + Vector2(0, 58)
		pilot_caption.size = Vector2(pilot_name.size.x, 20)
		pilot_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		# Left of the controls and clear above its name.
		pilot_height = clampf(pilot_name.position.y - (top + 84 + 24), 260, 470)
		focus = Vector2(minf(screen.x * 0.33, mode_card.position.x - 150), top + 84 + 16 + pilot_height * 0.5)
	level_prev.position = Vector2.ZERO
	level_prev.size = Vector2(56, level_row.size.y)
	level_next.position = Vector2(level_row.size.x - 56, 0)
	level_next.size = Vector2(56, level_row.size.y)
	level_title.position = Vector2(64, 0)
	level_title.size = Vector2(level_row.size.x - 128, level_row.size.y)
	# The sheet: a column of cards hanging from the bottom.
	var sheet_width = minf(screen.x - 40, 640)
	sheet_list.size = Vector2(sheet_width, 0)
	sheet_list.size = sheet_list.get_combined_minimum_size().max(Vector2(sheet_width, 0))
	sheet_list.position = Vector2((screen.x - sheet_width) * 0.5, maxf(safe_top + 30, bottom - sheet_list.size.y - 30))
	redraw()

func swipe_rect() -> Rect2:
	# The stretch of arena around the pilot: sideways there browses the campaign.
	var left = skins_button.get_rect().end.x + 10
	var top = profile.get_rect().end.y + 10
	return Rect2(left, top, size.x - left - 10, maxf(bottom_top - top - 10, 80))

func _draw() -> void:
	# Shade the edges so the white type reads over the lit arena: the top bar, the rail
	# and the whole bottom block sit on gradients rather than on boxes.
	var w = size.x
	var h = size.y
	var ink = Color(0.0, 0.02, 0.03)
	shade(Rect2(0, 0, w, 250), Color(ink, 0.82), Color(ink, 0.0), true)
	var low = bottom_top - 140
	shade(Rect2(0, low, w, h - low), Color(ink, 0.0), Color(ink, 0.9), true)
	shade(Rect2(0, 0, 200, h), Color(ink, 0.55), Color(ink, 0.0), false)
	# A thin accent line under the top bar, fading out towards the right.
	var line_y = profile.get_rect().end.y + 12
	shade(Rect2(20, line_y, w * 0.6, 2), Color(hud.CYAN, 0.55), Color(hud.CYAN, 0.0), false)
	# The pedestal glow under the pilot.
	if not sheet.visible:
		var feet = Vector2(focus.x, focus.y + pilot_height * 0.47)
		for ring in range(3):
			var r = pilot_height * (0.26 + ring * 0.07)
			draw_arc(feet, r, 0, TAU, 64, Color(hud.CYAN, 0.10 - ring * 0.03), 2.0, true)

func shade(rect: Rect2, from: Color, to: Color, downwards: bool) -> void:
	var a = rect.position
	var b = rect.position + Vector2(rect.size.x, 0)
	var c = rect.end
	var d = rect.position + Vector2(0, rect.size.y)
	var colors = PackedColorArray([from, to, to, from]) if not downwards else PackedColorArray([from, from, to, to])
	draw_polygon(PackedVector2Array([a, b, c, d]), colors)

# --- faces ---------------------------------------------------------------------------

func draw_profile(c: Control) -> void:
	var skin: int = hud.skins_progress.selected if hud.skins_progress != null else 0
	var center = Vector2(46, c.size.y * 0.5)
	c.draw_circle(center, 31, Color(0.0, 0.04, 0.05, 0.9), true, -1, true)
	hud.portrait(center, hud.CYAN, false, skin, c)
	c.draw_arc(center, 32, 0, TAU, 48, Color(hud.CYAN, 0.9), 2.0, true)
	var pilot = String(Skins.CATALOG[clampi(skin, 0, Skins.CATALOG.size() - 1)].name).to_upper()
	c.draw_string(hud.font_bold, Vector2(88, 34), pilot, HORIZONTAL_ALIGNMENT_LEFT, c.size.x - 96, 24, hud.WHITE)
	var done = 0
	var total = Campaign.menu_levels().size()
	if hud.campaign_state != null:
		done = Campaign.menu_levels().filter(func(i): return i in hud.campaign_state.completed).size()
	c.draw_string(hud.font_bold, Vector2(88, 54), "CAMPANHA  %d/%d" % [done, total], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, hud.MUTED)
	var bar = Rect2(88, 62, c.size.x - 104, 6)
	c.draw_rect(bar, Color(1, 1, 1, 0.1))
	c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * (float(done) / maxf(total, 1)), bar.size.y)), YELLOW)

func draw_wallet(c: Control) -> void:
	var bricks: int = hud.power_shop.bricks if hud.power_shop != null else 0
	var at = Vector2(30, c.size.y * 0.5)
	glyph(c, "brick", at, 13, YELLOW)
	c.draw_string(hud.font_bold, Vector2(52, c.size.y * 0.5 + 9), str(bricks), HORIZONTAL_ALIGNMENT_LEFT, c.size.x - 58, 26, hud.WHITE)

func draw_rail(c: Control, b: Button) -> void:
	var icon_at = Vector2(c.size.x * 0.5, 38)
	c.draw_circle(icon_at, 27, Color(hud.CYAN, 0.12), true, -1, true)
	glyph(c, String(b.get_meta("icon")), icon_at, 17, hud.WHITE)
	var title = String(b.get_meta("title"))
	var width = hud.font_bold.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	c.draw_string(hud.font_bold, Vector2((c.size.x - width) * 0.5, c.size.y - 22), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, hud.WHITE)
	var badge = String(b.get_meta("badge"))
	if badge != "":
		var bw = hud.font_bold.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		c.draw_string(hud.font_bold, Vector2((c.size.x - bw) * 0.5, c.size.y - 7), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, hud.MUTED)
	if bool(b.get_meta("fresh")):
		c.draw_circle(Vector2(c.size.x - 14, 14), 7, YELLOW, true, -1, true)
		c.draw_arc(Vector2(c.size.x - 14, 14), 7, 0, TAU, 20, Color(0, 0, 0, 0.5), 1.2, true)

func draw_mode_card(c: Control) -> void:
	var info: Dictionary = MODES[lobby_mode]
	var icon_at = Vector2(50, c.size.y * 0.5)
	c.draw_circle(icon_at, 32, Color(hud.CYAN, 0.16), true, -1, true)
	glyph(c, String(info.icon), icon_at, 18, hud.CYAN)
	c.draw_string(hud.font_bold, Vector2(94, 22), "MODO  ▾", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, hud.MUTED)
	c.draw_string(hud.font_bold, Vector2(94, 52), String(info.title), HORIZONTAL_ALIGNMENT_LEFT, c.size.x - 170, 28, hud.WHITE)
	var sub = String(info.about)
	if lobby_mode == "campanha" and hud.campaign_state != null:
		var level: Dictionary = Campaign.LEVELS[hud.menu_level]
		sub = String(level.challenge) if hud.campaign_state.is_unlocked(hud.menu_level) else "Vence o nível anterior para abrir"
	c.draw_string(hud.font, Vector2(94, 78), sub, HORIZONTAL_ALIGNMENT_LEFT, c.size.x - (180 if lobby_mode == "campanha" else 104), 14, hud.MUTED)
	if lobby_mode == "campanha":
		# The rival waiting at the end of this level.
		var level: Dictionary = Campaign.LEVELS[hud.menu_level]
		var station: bool = int(level.boss) >= 100
		var beaten: bool = hud.skins_progress != null and int(level.boss) < Skins.CATALOG.size() and hud.skins_progress.is_unlocked(level.boss)
		var hue: Color = Color(String(level.hue)) if level.has("hue") else hud.CORAL
		var at = Vector2(c.size.x - 46, c.size.y * 0.5 - 6)
		c.draw_circle(at, 30, Color(0, 0.03, 0.04, 0.9), true, -1, true)
		hud.portrait(at, hue if station else hud.CORAL, false, level.boss, c, station or not beaten)
		c.draw_arc(at, 31, 0, TAU, 40, Color(hud.CORAL, 0.8), 1.6, true)
		var tag = "POSTO" if station else "BOSS"
		var tw = hud.font_bold.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		c.draw_string(hud.font_bold, Vector2(at.x - tw * 0.5, c.size.y - 8), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, hud.CORAL)

func draw_mode_entry(c: Control, id: String) -> void:
	var info: Dictionary = MODES[id]
	var chosen = id == lobby_mode
	if chosen:
		c.draw_rect(Rect2(0, 10, 5, c.size.y - 20), YELLOW)
	var icon_at = Vector2(62, c.size.y * 0.5)
	c.draw_circle(icon_at, 38, Color(YELLOW if chosen else hud.CYAN, 0.16), true, -1, true)
	glyph(c, String(info.icon), icon_at, 22, YELLOW if chosen else hud.CYAN)
	c.draw_string(hud.font_bold, Vector2(122, c.size.y * 0.5 - 4), String(info.title), HORIZONTAL_ALIGNMENT_LEFT, -1, 32, hud.WHITE)
	c.draw_string(hud.font, Vector2(122, c.size.y * 0.5 + 24), String(info.about), HORIZONTAL_ALIGNMENT_LEFT, c.size.x - 140, 15, hud.MUTED)
	if chosen:
		c.draw_string(hud.font_bold, Vector2(c.size.x - 110, 26), "ESCOLHIDO", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, YELLOW)

# --- icons ---------------------------------------------------------------------------

func glyph(c: CanvasItem, kind: String, at: Vector2, r: float, color: Color) -> void:
	# Small line icons, drawn rather than loaded, so they stay sharp at any size.
	var w = maxf(2.0, r * 0.16)
	match kind:
		"hangar":
			c.draw_circle(at + Vector2(0, -r * 0.1), r * 0.78, color, false, w, true)
			c.draw_rect(Rect2(at + Vector2(-r * 0.55, -r * 0.3), Vector2(r * 1.1, r * 0.42)), color)
			c.draw_line(at + Vector2(-r * 0.6, r * 0.75), at + Vector2(r * 0.6, r * 0.75), color, w, true)
		"powers", "quick":
			var bolt = PackedVector2Array([at + Vector2(r * 0.25, -r), at + Vector2(-r * 0.45, r * 0.12), at + Vector2(r * 0.05, r * 0.12), at + Vector2(-r * 0.25, r), at + Vector2(r * 0.5, -r * 0.2), at + Vector2(0, -r * 0.2)])
			c.draw_colored_polygon(bolt, color)
		"story":
			c.draw_arc(at + Vector2(0, -r * 0.35), r * 0.6, 0, PI, 20, color, w, true)
			c.draw_line(at + Vector2(-r * 0.6, -r * 0.35), at + Vector2(r * 0.6, -r * 0.35), color, w, true)
			c.draw_line(at + Vector2(0, r * 0.25), at + Vector2(0, r * 0.7), color, w, true)
			c.draw_line(at + Vector2(-r * 0.45, r * 0.8), at + Vector2(r * 0.45, r * 0.8), color, w * 1.4, true)
			c.draw_arc(at + Vector2(-r * 0.62, -r * 0.1), r * 0.25, PI * 0.5, PI * 1.5, 10, color, w * 0.8, true)
			c.draw_arc(at + Vector2(r * 0.62, -r * 0.1), r * 0.25, -PI * 0.5, PI * 0.5, 10, color, w * 0.8, true)
		"pvp":
			for side in [-1, 1]:
				var tip = at + Vector2(side * r * 0.8, -r * 0.8)
				var hilt = at + Vector2(-side * r * 0.55, r * 0.55)
				c.draw_line(tip, hilt, color, w * 1.2, true)
				var across = Vector2(side, side).normalized().orthogonal() * r * 0.3
				c.draw_line(hilt + (tip - hilt) * 0.2 - across, hilt + (tip - hilt) * 0.2 + across, color, w, true)
		"campaign":
			c.draw_line(at + Vector2(-r * 0.55, r * 0.9), at + Vector2(-r * 0.55, -r * 0.9), color, w, true)
			c.draw_colored_polygon(PackedVector2Array([at + Vector2(-r * 0.5, -r * 0.9), at + Vector2(r * 0.75, -r * 0.55), at + Vector2(-r * 0.5, -r * 0.15)]), color)
		"settings":
			for tooth in range(8):
				var angle = tooth * TAU / 8.0
				c.draw_line(at + Vector2.from_angle(angle) * r * 0.62, at + Vector2.from_angle(angle) * r * 0.98, color, w * 1.6, true)
			c.draw_circle(at, r * 0.62, color, false, w * 1.2, true)
			c.draw_circle(at, r * 0.24, color, false, w, true)
		"brick":
			c.draw_rect(Rect2(at - Vector2(r, r * 0.62), Vector2(r * 2, r * 1.24)), color)
			for x in [-0.45, 0.45]:
				c.draw_circle(at + Vector2(x * r, -r * 0.62), r * 0.24, color, true, -1, true)
