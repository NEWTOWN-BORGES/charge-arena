extends Control
## MEU PERCURSO: the player's own story in the Taça, from the admission to the round being
## played and the question mark after it. Only the player's matches - the rest of the
## draw lives in the tree.
signal closed
signal play_requested
const UI = preload("res://scripts/story_ui.gd")
const Press = preload("res://scripts/story_press.gd")
const Taca = preload("res://scripts/tournament.gd")
const Campaign = preload("res://scripts/campaign.gd")

var cup
var hud
var player_skin = 0
var scroll: ScrollContainer
var column: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var ground = ColorRect.new()
	ground.color = UI.NIGHT
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 0)
	scroll.add_child(column)
	resized.connect(arrange)
	build()
	arrange()

func arrange() -> void:
	var width = minf(size.x - 32, 760)
	scroll.position = Vector2((size.x - width) * 0.5, 16)
	scroll.size = Vector2(width, size.y - 16)

func build() -> void:
	var bar = HBoxContainer.new()
	column.add_child(bar)
	var back = UI.key(hud, "‹  TAÇA", false, func(): closed.emit(), 52)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.custom_minimum_size.x = 150
	bar.add_child(back)
	UI.gap(column, 14)
	column.add_child(UI.label("MEU PERCURSO", 46, UI.WHITE, "display", false))
	column.add_child(UI.label("A tua Taça, ronda a ronda. Quem ficou para trás e o que se escreveu no dia seguinte.", 17, UI.MUTED, "body"))
	UI.gap(column, 18)
	# The door.
	var entry = step_card(0)
	column.add_child(entry)
	for record in cup.history:
		if int(record.step) == 0: continue
		column.add_child(link(true))
		column.add_child(step_card(int(record.step)))
	if not cup.champion():
		column.add_child(link(false))
		column.add_child(current_card())
		column.add_child(link(false))
		var unknown = PanelContainer.new()
		unknown.add_theme_stylebox_override("panel", UI.panel_style(Color(0, 0, 0, 0), UI.LINE, 14, 18))
		column.add_child(unknown)
		var box = VBoxContainer.new()
		unknown.add_child(box)
		var q = UI.label("?", 54, Color(UI.WHITE, 0.25), "display", false)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(q)
		var left = Taca.ROUNDS - cup.wins - (0 if cup.entrance_passed else 0)
		var tail = UI.label("A Coroa Solar fica a %d ronda%s daqui." % [left, "" if left == 1 else "s"], 16, UI.MUTED, "italic")
		tail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(tail)
	else:
		column.add_child(link(true))
		var crown = UI.card(column, Color("2b2112"), UI.GOLD, 22)
		crown.add_child(UI.label("CAMPEÃO DA TAÇA AURORA", 30, UI.GOLD, "display", false))
		crown.add_child(UI.label("Dez rondas. Dez nomes grandes. Nenhum por sorte.", 17, UI.WHITE, "body"))
	UI.gap(column, 30)

func link(done: bool) -> Control:
	var line = Control.new()
	line.custom_minimum_size.y = 34
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.draw.connect(func():
		var x = 46.0
		if done:
			line.draw_line(Vector2(x, 0), Vector2(x, 34), UI.GOLD, 3.0, true)
		else:
			for y in range(0, 34, 8):
				line.draw_line(Vector2(x, y), Vector2(x, y + 4), Color(UI.MINT, 0.7), 3.0, true))
	return line

func step_card(step: int) -> PanelContainer:
	var record: Dictionary = Press.played(cup, step)
	var frame = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UI.panel_style(UI.NAVY, UI.GOLD_DEEP if step > 0 else UI.LINE, 14, 18))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	frame.add_child(row)
	var face = Control.new()
	face.custom_minimum_size = Vector2(64, 64)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var who = String(record.get("opponent", "Aurora"))
	var boss = int(record.get("boss", 0))
	face.draw.connect(func():
		face.draw_circle(Vector2(32, 32), 30, Color(0, 0.03, 0.04, 0.9), true, -1, true)
		if hud != null: hud.portrait(Vector2(32, 32), UI.CORAL, true, boss, face, false)
		face.draw_arc(Vector2(32, 32), 31, 0, TAU, 40, UI.GOLD, 2.0, true))
	row.add_child(face)
	var words = VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 4)
	row.add_child(words)
	var top = HBoxContainer.new()
	words.add_child(top)
	top.add_child(UI.label(("ENTRADA NA TAÇA" if step == 0 else Taca.ROUND_NAMES[step].to_upper()), 15, UI.GOLD, "display", false))
	var badge = UI.label("✓ VITÓRIA", 15, UI.MINT, "display", false)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(badge)
	var line = HBoxContainer.new()
	words.add_child(line)
	line.add_child(UI.label(who.to_upper(), 26, UI.WHITE, "display", false))
	var score = UI.label(String(record.get("result", "")), 28, UI.GOLD, "display", false)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(score)
	words.add_child(UI.label(String(record.get("arena", "")), 14, UI.MUTED, "body"))
	# What the paper printed the day after: the edition that followed this match.
	var next_edition = step + 1
	if next_edition < Press.editions_available(cup):
		var e: Dictionary = Press.edition(cup, next_edition)
		words.add_child(UI.label("NO JORNAL  ·  «%s»" % String(e.headline), 14, Color(UI.WHITE, 0.75), "italic"))
	return frame

func current_card() -> PanelContainer:
	var m: Dictionary = cup.confirmed_match()
	var frame = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UI.panel_style(UI.NAVY_LIGHT, UI.MINT, 14, 18))
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	frame.add_child(box)
	box.add_child(UI.label("RONDA ATUAL  ·  %s" % String(m.round_name).to_upper(), 15, UI.MINT, "display", false))
	box.add_child(UI.label("TU  vs  %s" % String(m.name).to_upper(), 30, UI.WHITE, "display", false))
	box.add_child(UI.label(String(cup.level().name), 15, UI.MUTED, "body"))
	box.add_child(UI.key(hud, "JOGAR", true, func(): play_requested.emit(), 64))
	return frame
