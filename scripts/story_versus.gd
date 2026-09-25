extends Control
## Before walking into the arena: a sports-broadcast card. The round, the two pilots, one
## line about the rival - never its plan - and, for the big matches, a few seconds of what
## is being said around it. Always skippable; ENTRAR NA ARENA is always one tap away.
signal enter
signal cancelled
const UI = preload("res://scripts/story_ui.gd")
const Press = preload("res://scripts/story_press.gd")
const Taca = preload("res://scripts/tournament.gd")

var cup
var hud
var player_skin = 0
var info: Dictionary
var clock = 0.0
var beat = 0
var moment_box: VBoxContainer
var speaker: Label
var words: Label
var skip: Button
const BEAT = 2.6

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	info = Press.versus(cup)
	var ground = Split.new()
	ground.final = bool(info.get("final", false))
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)
	var column = VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	var kicker = UI.label("TAÇA AURORA", 18, UI.GOLD, "display", false)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(kicker)
	var round_label = UI.label(String(info.round), 50 if not info.final else 64, UI.WHITE, "display", false)
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(round_label)
	var arena = UI.label(String(info.arena).to_upper(), 15, UI.MUTED, "display", false)
	arena.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(arena)
	var duel = HBoxContainer.new()
	duel.custom_minimum_size.y = 400
	duel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(duel)
	duel.add_child(side(Taca.PLAYER, "O ESTREANTE" if cup.wins < 3 else "A SENSAÇÃO DA TAÇA", UI.MINT, -0.4))
	var versus = UI.label("VS", 72, UI.GOLD, "display", false)
	versus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	versus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	versus.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	duel.add_child(versus)
	duel.add_child(side(String(info.name), String(info.epithet), UI.CORAL, 0.4))
	var line = UI.label(String(info.line), 19, UI.WHITE, "italic")
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(line)
	# The moment before: one voice at a time.
	moment_box = VBoxContainer.new()
	moment_box.custom_minimum_size.y = 96
	moment_box.add_theme_constant_override("separation", 4)
	column.add_child(moment_box)
	speaker = UI.label("", 15, UI.GOLD, "display", false)
	speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	moment_box.add_child(speaker)
	words = UI.label("", 21, UI.WHITE, "italic")
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	moment_box.add_child(words)
	var keys = HBoxContainer.new()
	keys.add_theme_constant_override("separation", 12)
	column.add_child(keys)
	var back = UI.key(hud, "VOLTAR", false, func(): cancelled.emit(), 72)
	back.size_flags_stretch_ratio = 0.6
	keys.add_child(back)
	keys.add_child(UI.key(hud, "ENTRAR NA ARENA", true, func(): enter.emit(), 72))
	skip = UI.key(hud, "SALTAR  ›", false, skip_moment, 44)
	skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	skip.custom_minimum_size.x = 180
	column.add_child(skip)
	resized.connect(arrange)
	arrange()
	call_deferred("arrange")
	show_beat()

func side(who: String, caption: String, tint: Color, turn: float) -> VBoxContainer:
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var art = UI.pilot_render(cup, who, player_skin, turn, Vector2i(480, 620))
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.custom_minimum_size.y = 260
	box.add_child(art)
	var name_label = UI.label(who.to_upper(), 34, UI.WHITE, "display", false)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	var tag = UI.label(caption, 15, tint, "display", false)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tag)
	return box

func arrange() -> void:
	var column: Control = get_node("Column")
	var top = 24.0
	if OS.has_feature("mobile"):
		var safe = DisplayServer.get_display_safe_area()
		var screen = DisplayServer.screen_get_size()
		if screen.y > 0: top += float(safe.position.y) / screen.y * size.y
	var width = minf(size.x - 40, 820)
	column.position = Vector2((size.x - width) * 0.5, top)
	# Wrapped text measures itself against the width it is given, so the column is
	# first narrowed to its real width, then given its height.
	column.size = Vector2(width, 0)
	column.size = Vector2(width, size.y - top - 24)

func show_beat() -> void:
	var moment: Array = info.get("moment", [])
	if beat >= moment.size():
		skip.hide()
		return
	speaker.text = String(moment[beat][0])
	words.text = "«%s»" % String(moment[beat][1])
	words.modulate.a = 0.0

func skip_moment() -> void:
	beat = 99
	speaker.text = ""
	words.text = ""
	skip.hide()

func _process(dt: float) -> void:
	clock += dt
	if is_instance_valid(words) and words.modulate.a < 1.0:
		words.modulate.a = minf(1.0, words.modulate.a + dt * 3.0)
	if clock >= BEAT and beat < 99:
		clock = 0.0
		beat += 1
		show_beat()

class Split extends Control:
	## The broadcast backdrop: the player's mint on the left, the rival's coral on the
	## right, cut on a diagonal; gold for the final.
	var final = false
	func _draw() -> void:
		var w = size.x
		var h = size.y
		draw_rect(Rect2(Vector2.ZERO, size), Color("060d12"))
		var left = Color(0.05, 0.22, 0.2, 1.0)
		var right = Color(0.25, 0.08, 0.07, 1.0) if not final else Color(0.28, 0.2, 0.06, 1.0)
		draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w * 0.56, 0), Vector2(w * 0.44, h), Vector2(0, h)]), left)
		draw_colored_polygon(PackedVector2Array([Vector2(w * 0.56, 0), Vector2(w, 0), Vector2(w, h), Vector2(w * 0.44, h)]), right)
		draw_line(Vector2(w * 0.56, 0), Vector2(w * 0.44, h), Color("e8bd78"), 4.0, true)
		for i in range(14):
			var y = h * i / 14.0
			draw_line(Vector2(0, y), Vector2(w, y), Color(1, 1, 1, 0.025), 1.0)
		draw_rect(Rect2(0, h - 160, w, 160), Color(0, 0, 0, 0.35))
