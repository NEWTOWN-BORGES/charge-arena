extends Control
## ÁRVORE DA ARENA: the whole tournament, readable. The global view is the ladder of the
## draw - 1 024 down to the champion - with what happened in each round that has been
## played. The close view is the stretch of the draw around the player: who is left, who
## already fell (struck through), and who could still come - never who will.
signal closed
const UI = preload("res://scripts/story_ui.gd")
const Press = preload("res://scripts/story_press.gd")
const Taca = preload("res://scripts/tournament.gd")

var cup
var hud
var scroll: ScrollContainer
var column: VBoxContainer
var zoom_near = false

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
	column.add_theme_constant_override("separation", 12)
	scroll.add_child(column)
	resized.connect(arrange)
	build()
	arrange()

func arrange() -> void:
	var width = minf(size.x - 32, 760)
	scroll.position = Vector2((size.x - width) * 0.5, 16)
	scroll.size = Vector2(width, size.y - 16)

func build() -> void:
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()
	var bar = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	column.add_child(bar)
	var back = UI.key(hud, "‹  TAÇA", false, func(): closed.emit(), 52)
	back.custom_minimum_size.x = 150
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bar.add_child(back)
	column.add_child(UI.label("ÁRVORE DA ARENA", 46, UI.WHITE, "display", false))
	var switch = HBoxContainer.new()
	switch.add_theme_constant_override("separation", 10)
	column.add_child(switch)
	switch.add_child(UI.key(hud, "VISÃO GLOBAL", not zoom_near, func(): zoom_near = false; build(), 56))
	switch.add_child(UI.key(hud, "A TUA ZONA", zoom_near, func(): zoom_near = true; build(), 56))
	if zoom_near: near()
	else: overview()
	UI.gap(column, 30)

func overview() -> void:
	column.add_child(UI.label("Do primeiro dia ao campeão. Os resultados de cada ronda aparecem quando ela acontece.", 16, UI.MUTED, "body"))
	var played = cup.rounds_played()
	for r in range(1, Taca.ROUNDS + 2):
		var champion_row = r == Taca.ROUNDS + 1
		var field: int = 1 if champion_row else (Taca.FIELD >> (r - 1))
		var done = r <= played
		var here = not champion_row and cup.entrance_passed and r == played + 1 and not cup.champion()
		var fill = UI.NAVY_LIGHT if here else UI.NAVY
		var edge = UI.MINT if here else (UI.GOLD_DEEP if done else UI.LINE)
		var row = UI.card(column, fill, edge, 14)
		var top = HBoxContainer.new()
		row.add_child(top)
		var count = UI.label("CAMPEÃO" if champion_row else "%s" % group(field), 34 if not champion_row else 28, UI.GOLD if done or (champion_row and cup.champion()) else UI.WHITE, "display", false)
		count.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		count.custom_minimum_size.x = 150
		top.add_child(count)
		var name_label = UI.label("" if champion_row else Taca.ROUND_NAMES[r].to_upper(), 16, UI.MUTED, "display", false)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		top.add_child(name_label)
		var state = "CONCLUÍDA" if done else ("ESTÁS AQUI" if here else ("TU" if champion_row and cup.champion() else "POR DISPUTAR"))
		var state_label = UI.label(state, 15, UI.MINT if here or (champion_row and cup.champion()) else (UI.GOLD if done else Color(UI.WHITE, 0.35)), "display", false)
		state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		top.add_child(state_label)
		if done:
			var notes: Array = round_notes(r)
			for note in notes:
				row.add_child(UI.label(note, 15, Color(UI.WHITE, 0.8), "body"))

func group(value: int) -> String:
	return "1.024" if value == 1024 else str(value)

func round_notes(r: int) -> Array:
	# The round in a line or two: the player's match, then who else made it news.
	var notes: Array = []
	var yours: Dictionary = Press.played(cup, r)
	if not yours.is_empty():
		notes.append("Tu  %s  %s" % [String(yours.result), String(yours.opponent)])
	for e in cup.events:
		if int(e.get("round", -1)) != r: continue
		match String(e.type):
			"FAVORITE_ELIMINATED": notes.append("Caiu: %s, eliminada por %s" % [e.subject, e.other] if e.subject == "Lira" else "Caiu: %s, eliminado por %s" % [e.subject, e.other])
			"WITHDRAWAL": notes.append("Desistência: %s" % e.subject)
			"UPSET": notes.append("Surpresa: %s continua" % e.subject)
			"UPSET_ENDS": notes.append("%s trava %s" % [e.other, e.subject])
			"RIVAL_ELIMINATED": notes.append("%s elimina %s" % [e.other, e.subject])
	return notes.slice(0, 4)

func near() -> void:
	column.add_child(UI.label("O teu canto da chave. Riscados: quem já caiu. Os possíveis adversários dependem de resultados que ainda não aconteceram.", 16, UI.MUTED, "body"))
	var chart = Chart.new()
	chart.cup = cup
	chart.custom_minimum_size.y = 540
	column.add_child(chart)
	if cup.champion() or not cup.entrance_passed: return
	# Further ahead: only possibilities.
	var next: int = cup.wins + 1
	for r in range(next + 1, mini(next + 3, Taca.ROUNDS) + 1):
		var pool: Array = cup.possible_opponents(r)
		if pool.is_empty(): continue
		var box = UI.card(column, UI.NAVY, UI.LINE, 14)
		box.add_child(UI.label("POSSÍVEIS ADVERSÁRIOS  ·  %s" % Taca.ROUND_NAMES[r].to_upper(), 15, UI.GOLD, "display", false))
		var names: Array = pool.map(func(s): return cup.entrant(s)).filter(func(e): return e.cast != "")
		var others: Array = pool.map(func(s): return cup.entrant(s)).filter(func(e): return e.cast == "")
		others.sort_custom(func(a, b): return a.rating > b.rating)
		var shown: Array = (names + others).slice(0, 4).map(func(e): return String(e.name))
		box.add_child(UI.label(",  ".join(shown) + ("  e mais %d" % (pool.size() - shown.size()) if pool.size() > shown.size() else ""), 18, UI.WHITE, "body"))

class Chart extends Control:
	## A small real bracket: the eight pilots around the player in the round to play, the
	## ones they knocked out the round before (struck through), and the rounds after,
	## still blank.
	const UI = preload("res://scripts/story_ui.gd")
	const Taca = preload("res://scripts/tournament.gd")
	var cup
	func _draw() -> void:
		var played: int = cup.rounds_played()
		var pool: Array = cup.alive(played)
		var at = pool.find(0)
		if at < 0: at = 0
		var start = (at / 8) * 8
		var eight: Array = pool.slice(start, mini(start + 8, pool.size()))
		var col_w = size.x / 4.0
		var row_h = size.y / 8.0
		var f = UI.font("display")
		# Column 0: last round's matches (winner over loser), when there was one.
		for i in range(eight.size()):
			var slot: int = eight[i]
			var y = row_h * (i + 0.5)
			var e: Dictionary = cup.entrant(slot)
			if played > 0:
				var beaten: int = cup.opponent_in(slot, played)
				if beaten >= 0:
					var loser_name = String(cup.entrant(beaten).name)
					draw_string(f, Vector2(4, y + 5), loser_name, HORIZONTAL_ALIGNMENT_LEFT, col_w - 12, 14, Color(1, 1, 1, 0.35))
					var w = minf(f.get_string_size(loser_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x, col_w - 12)
					draw_line(Vector2(4, y), Vector2(4 + w, y), Color("ef947e", 0.8), 1.5)
			# Column 1: who is left.
			var box = Rect2(col_w, y - row_h * 0.34, col_w - 10, row_h * 0.68)
			var mine = slot == 0
			var next_rival = slot == cup.opponent_in(0, played + 1) if not cup.champion() else false
			draw_rect(box, Color("163446") if not mine else Color("1d4a45"))
			draw_rect(box, Color("81d9c4") if mine else (Color("ef947e") if next_rival else Color("2a4b5a")), false, 1.5)
			draw_string(f, box.position + Vector2(8, box.size.y * 0.5 + 6), "TU" if mine else String(e.name), HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 14, 16, Color("f2eee4"))
		# Columns 2 and 3: the rounds to come - blank, with the player's line lit.
		for k in range(2):
			var span = 2 << k
			for i in range(0, 8, span):
				var y0 = row_h * (i + 0.5)
				var y1 = row_h * (i + span - 0.5)
				var x0 = col_w * (1 + k) + col_w - 10
				var x1 = col_w * (2 + k)
				var lit = start + i <= at and at < start + i + span
				var color = Color("81d9c4", 0.8) if lit else Color("2a4b5a")
				draw_line(Vector2(x0, y0), Vector2(x0 + 8, y0), color, 1.5)
				draw_line(Vector2(x0, y1), Vector2(x0 + 8, y1), color, 1.5)
				draw_line(Vector2(x0 + 8, y0), Vector2(x0 + 8, y1), color, 1.5)
				var mid = (y0 + y1) * 0.5
				draw_line(Vector2(x0 + 8, mid), Vector2(x1, mid), color, 1.5)
				var box = Rect2(x1, mid - row_h * 0.3, col_w - 10, row_h * 0.6)
				draw_rect(box, Color("0e2330"))
				draw_rect(box, color, false, 1.0)
				draw_string(f, box.position + Vector2(8, box.size.y * 0.5 + 6), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.4))
		var labels = ["RONDA ANTERIOR" if played > 0 else "", Taca.ROUND_NAMES[mini(played + 1, Taca.ROUNDS)].to_upper(), "A SEGUIR", "DEPOIS"]
		for k in range(4):
			draw_string(f, Vector2(col_w * k + 4, 14), labels[k], HORIZONTAL_ALIGNMENT_LEFT, col_w - 8, 12, Color("e8bd78"))
