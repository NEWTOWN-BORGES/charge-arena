extends SceneTree
# The Taça Aurora as the story mode: the campaign's eleven levels as the admission and ten
# knockout rounds, a deterministic 1 024-pilot draw, and a paper that only prints what has
# happened - twelve different covers along the way.
const Taca = preload("res://scripts/tournament.gd")
const Press = preload("res://scripts/story_press.gd")
const Campaign = preload("res://scripts/campaign.gd")
const TMP = "res://tests/taca-test.tmp"
var failures = 0

func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var cup = Taca.new()
	cup.path = TMP
	cup.seed_value = 424242
	cup.reset()
	check(Taca.story_levels() == Campaign.menu_levels() and Taca.story_levels().size() == Taca.ROUNDS + 1, "The admission and the ten rounds are the campaign's eleven levels, in order")
	check(cup.confirmed_match().entrance and cup.opponent() == "Aurora" and cup.level_index() == Campaign.menu_levels()[0], "The run opens with the admission against Aurora on the first level")
	check(cup.entrants.size() == 1024 and cup.entrant(0).name == Taca.PLAYER, "1 024 pilots in the draw, the player among them")
	var names: Dictionary = {}
	for e in cup.entrants: names[e.name] = true
	check(names.size() == 1024, "Every pilot in the draw has a name of their own")
	check(Press.editions_available(cup) == 1 and Press.has_new_edition(cup), "The opening edition is on the stand before the admission")
	cup.complete([2, 1])
	check(cup.entrance_passed and cup.wins == 0 and cup.rounds_played() == 0, "Passing the admission enters the draw without playing a round")
	var bosses: Array = []
	for r in range(1, Taca.ROUNDS + 1):
		var m: Dictionary = cup.confirmed_match()
		check(m.round == r and m.boss == Campaign.LEVELS[Campaign.menu_levels()[r]].boss and m.field == (1024 >> (r - 1)), "Round %d (%s) is against the campaign's boss for it, with %d pilots left" % [r, m.round_name, m.field])
		var standing: Array = cup.alive(cup.rounds_played())
		check(standing.has(Taca.boss_slot(r)) and standing.has(0), "Round %d: the player and that boss are both still standing" % r)
		if r > 1:
			check(cup.opponent_in(0, r) == Taca.boss_slot(r), "Round %d: the draw really pairs them" % r)
		bosses.append(cup.opponent())
		cup.complete([2, r % 2])
	check(cup.champion() and cup.confirmed_match().is_empty() and cup.alive(Taca.ROUNDS) == [0], "Ten wins: the player is the one left, and there is no match after it")
	check(bosses == ["Faroleiro", "Mineiro", "Alquimista", "Relojoeiro", "Jardineiro", "Corsário", "Caça-Trovões", "Astrónomo", "Sentinela", "Arconte Solar"], "The rivals come in campaign order, Sentinela in the semi-final and the Arconte in the final")
	check(Press.beaten_by(cup, "Lira") == "Vértice" and Press.beaten_by(cup, "Vértice") == "Astrónomo" and Press.beaten_by(cup, "Aurel") == "Arconte Solar", "The side stories play out: Vértice beats Lira, the Astrónomo stops Vértice, the Arconte ends the penta")
	check(cup.eliminated_in(cup.slot_of("Aurel")) == 9 and cup.eliminated_in(cup.slot_of("Kael Brasa")) == 4, "Aurel falls in the other semi-final, Kael walks out in the fourth round")
	check(not Press.find(cup, "WITHDRAWAL", "Kael Brasa").is_empty() and not Press.find(cup, "FINALISTS_DECIDED").is_empty(), "The walk-out and the finalists are recorded as events")
	# Twelve editions, twelve covers.
	var headlines: Array = []
	var bodies: Array = []
	for n in range(Press.editions_available(cup)):
		var e: Dictionary = Press.edition(cup, n)
		headlines.append(e.headline)
		bodies.append(e.body)
		check(not String(e.headline).is_empty() and not String(e.dek).is_empty() and not e.photo.is_empty(), "Edition %d has a headline, a standfirst and a photograph" % e.number)
	check(headlines.size() == 12, "Twelve editions from the opening to the champion")
	var unique_headlines: Dictionary = {}
	for h in headlines: unique_headlines[h] = true
	var unique_bodies: Dictionary = {}
	for b in bodies: unique_bodies[b] = true
	check(unique_headlines.size() == 12 and unique_bodies.size() == 12, "Every cover is its own: no headline or lead story repeats")
	check(Press.edition(cup, 11).tier == "historic" and Press.edition(cup, 10).tier == "special", "The eve of the final is a special edition and the champion's a historic one")
	# Nothing printed before it happens.
	var early = Taca.new()
	early.path = TMP
	early.seed_value = 424242
	early.reset()
	early.complete([2, 0])
	for r in range(3):
		early.complete([2, 0])
	var text = ""
	for n in range(Press.editions_available(early)):
		var e: Dictionary = Press.edition(early, n)
		text += e.headline + e.dek + e.body
		for s in e.stories: text += s.headline + s.body
	check(not text.contains("PAGOU-ME") and not text.contains("treinou") and not text.contains("camarote") and not text.contains("CAMPEÃO.
") and not text.begins_with("CAMPEÃO."), "Three rounds in, the paper knows nothing of the twists or the champion")
	check(not range(Press.editions_available(early)).any(func(n): return Press.edition(early, n).headline == "CAMPEÃO."), "And no champion's cover before there is a champion")
	check(Press.editions_available(early) == 5 and Press.edition(early, 4).headline == "QUEM É ESTE PILOTO?", "Each won round prints its own edition")
	# A defeat does not print, but the kiosk notices.
	var before = Press.editions_available(early)
	early.lose([1, 2])
	check(Press.editions_available(early) == before and early.losses_here() == 1 and Press.kiosk_line(early) == Press.KIOSK_AFTER_DEFEAT[0], "A defeat prints nothing; Rosa has a word about it")
	# Same seed, same Taça; saved and restored, the same Taça again.
	var twin = Taca.new()
	twin.path = TMP
	twin.seed_value = 424242
	twin.reset()
	twin.complete([2, 0])
	for r in range(3): twin.complete([2, 0])
	check(twin.winners == early.winners and twin.entrants.map(func(e): return e.name) == early.entrants.map(func(e): return e.name), "The same seed draws the same pilots and the same results")
	check(early.save() == OK, "The Taça saves")
	var restored = Taca.new()
	restored.path = TMP
	restored.restore()
	check(restored.seed_value == 424242 and restored.wins == 3 and restored.winners == early.winners and restored.events.size() == early.events.size() and restored.attempts.size() == 1, "Restored, it is the same Taça: seed, rounds, results, events and the lost attempt")
	check(restored.confirmed_match().name == "Relojoeiro" and restored.possible_opponents(5).size() > 1, "The next rival is confirmed; further on there are only possible ones")
	var versus: Dictionary = Press.versus(restored)
	check(versus.name == "Relojoeiro" and versus.epithet == "O METÓDICO" and versus.line.begins_with("Venceu as últimas 3"), "The versus card names the round, the rival and its run - not its plan")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	print("TACA_RESULT failures=", failures)
	quit(failures)
