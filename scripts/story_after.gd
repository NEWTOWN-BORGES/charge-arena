extends Control
## After a Taça match, before the hub: what just happened and what it changed. A win
## celebrates, shows the score, lets the draw shrink in front of you and announces the
## paper that is now on Rosa's stand. A defeat shows the score and Rosa's word, and the
## way back in. The cup won gets a screen of its own.
signal read_paper
signal retry
signal done
const UI = preload("res://scripts/story_ui.gd")
const Press = preload("res://scripts/story_press.gd")
const Taca = preload("res://scripts/tournament.gd")

var cup
var hud
var player_skin = 0
# {"won": bool, "score": [a, b], "rival": String, "step": int, "reward": String}
var outcome: Dictionary
var clock = 0.0
var counter: Label
var from_field = 0
var to_field = 0
var confetti: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var won = bool(outcome.get("won", false))
	var champion = won and cup.champion()
	var ground = ColorRect.new()
	ground.color = Color("050c10") if won else Color("100807")
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)
	if won:
		confetti = Confetti.new()
		confetti.gold = champion
		confetti.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		confetti.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(confetti)
	var column = VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 12)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(column)
	var step = int(outcome.get("step", 0))
	var kicker = UI.label("TAÇA AURORA  ·  %s" % ("ADMISSÃO" if step == 0 else Taca.ROUND_NAMES[clampi(step, 0, Taca.ROUNDS)].to_upper()), 17, UI.GOLD, "display", false)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(kicker)
	var title = UI.label("CAMPEÃO" if champion else ("VITÓRIA" if won else "DERROTA"), 96 if champion else 84, UI.GOLD if won else UI.CORAL, "display", false)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var score: Array = outcome.get("score", [0, 0])
	var line = UI.label("TU  %d–%d  %s" % [int(score[0]), int(score[1]), String(outcome.get("rival", "")).to_upper()], 30, UI.WHITE, "display", false)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(line)
	if won:
		if champion:
			var crown = UI.label("A Taça Aurora é tua. O arquivo guarda a tua Taça inteira, da primeira porta à última capa.", 20, UI.WHITE, "italic")
			crown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			column.add_child(crown)
		elif step == 0:
			var door = UI.label("Estás dentro. 1.024 pilotos na chave - e agora um deles és tu.", 20, UI.WHITE, "italic")
			door.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			column.add_child(door)
		else:
			# The draw shrinks in front of you.
			from_field = Taca.FIELD >> (step - 1)
			to_field = Taca.FIELD >> step
			counter = UI.label(str(from_field), 64, UI.MINT, "display", false)
			counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			column.add_child(counter)
			var next = "Avanças para %s." % ("a final" if step == Taca.ROUNDS - 1 else Taca.ROUND_NAMES[mini(step + 1, Taca.ROUNDS)].to_lower())
			var advance = UI.label("PILOTOS EM PROVA  ·  %s" % next, 17, UI.MUTED, "display", false)
			advance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			column.add_child(advance)
		var reward = String(outcome.get("reward", ""))
		if reward != "":
			var unlocked = UI.label("SKIN DESBLOQUEADA  ·  %s" % reward, 18, UI.GOLD, "display", false)
			unlocked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			column.add_child(unlocked)
		# The paper: what did they write about it?
		var e: Dictionary = Press.edition(cup, Press.editions_available(cup) - 1)
		var news = UI.card(column, Color("1a1712"), UI.GOLD_DEEP, 18)
		news.add_child(UI.label("NOVA EDIÇÃO  ·  AURORA EM CAMPO  N.º %03d" % int(e.number), 15, UI.PRESS_RED.lightened(0.3), "display", false))
		news.add_child(UI.label(String(e.headline), 30, UI.PAPER, "headline_black"))
		news.add_child(UI.label("Já está na Banca da Rosa.", 15, UI.MUTED, "italic"))
		var keys = HBoxContainer.new()
		keys.add_theme_constant_override("separation", 12)
		column.add_child(keys)
		keys.add_child(UI.key(hud, "LER AGORA", true, func(): read_paper.emit(), 76))
		keys.add_child(UI.key(hud, "CONTINUAR", false, func(): done.emit(), 76))
	else:
		var rosa = UI.label("«%s»" % Press.kiosk_line(cup), 21, UI.WHITE, "italic")
		rosa.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(rosa)
		var who = UI.label("ROSA, DA BANCA", 14, UI.GOLD, "display", false)
		who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(who)
		var note = UI.label("Uma derrota não te tira da Taça: a ronda espera por ti.", 16, UI.MUTED, "body")
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(note)
		var keys = HBoxContainer.new()
		keys.add_theme_constant_override("separation", 12)
		column.add_child(keys)
		keys.add_child(UI.key(hud, "TENTAR DE NOVO", true, func(): retry.emit(), 76))
		keys.add_child(UI.key(hud, "VOLTAR À TAÇA", false, func(): done.emit(), 76))
	resized.connect(arrange)
	arrange()
	call_deferred("arrange")

func arrange() -> void:
	var column: Control = get_node("Column")
	var width = minf(size.x - 40, 720)
	column.position = Vector2((size.x - width) * 0.5, 30)
	# Wrapped text measures itself against the width it is given, so the column is
	# first narrowed to its real width, then given its height.
	column.size = Vector2(width, 0)
	column.size = Vector2(width, size.y - 60)

func _process(dt: float) -> void:
	clock += dt
	if is_instance_valid(counter):
		# 512 ... 256: the field halves in front of you over a second and a half.
		var t = clampf((clock - 0.6) / 1.5, 0.0, 1.0)
		t = t * t * (3.0 - 2.0 * t)
		counter.text = str(int(round(lerpf(from_field, to_field, t))))
	if is_instance_valid(confetti):
		confetti.clock = clock
		confetti.queue_redraw()

class Confetti extends Control:
	var clock = 0.0
	var gold = false
	func _draw() -> void:
		for i in range(70):
			var seed_x = fmod(i * 97.13, 1.0)
			var speed = 80.0 + fmod(i * 31.7, 90.0)
			var x = size.x * fmod(i * 0.1379 + sin(clock * 0.7 + i) * 0.02, 1.0)
			var y = fmod(clock * speed + i * 57.0, size.y + 40) - 20
			var palette = [Color("e8bd78"), Color("f3eee1"), Color("81d9c4")] if not gold else [Color("e8bd78"), Color("ffd98a"), Color("f6ecd2")]
			var c: Color = palette[i % palette.size()]
			var turn = clock * 3.0 + i
			var half = Vector2(cos(turn), sin(turn)) * 6.0
			draw_line(Vector2(x, y) - half, Vector2(x, y) + half, Color(c, 0.85), 4.0 + seed_x * 2.0)
