extends RefCounted
## Taça Aurora: the campaign told as a 1 024-pilot knockout.
##
## The admission is the campaign's first level, against Aurora. Then ten rounds, one per
## campaign boss, in campaign order and at campaign difficulty: 1 024 -> 512 -> ... -> 2 ->
## champion. Everything else in the draw is played out around the player, round by round,
## from the save's own seed: the same pilots, the same results, every time the game opens.
## Nothing here draws anything - the hub, the paper, the tree and the route all read it.
const Campaign = preload("res://scripts/campaign.gd")
const Skins = preload("res://scripts/skins.gd")
const SAVE_PATH = "user://taca_v5.cfg"
const SAVE_VERSION = 5
const FIELD = 1024
const ROUNDS = 10
const FULL_MATCHES = ROUNDS
const DEMO_MATCHES = ROUNDS
const ROUND_NAMES = ["Admissão", "1.ª eliminatória", "2.ª eliminatória", "3.ª eliminatória", "4.ª eliminatória", "5.ª eliminatória", "16 avos de final", "Oitavos de final", "Quartos de final", "Meias-finais", "Final"]
const BOSS_NAMES = {1: "Faroleiro", 2: "Astrónomo", 3: "Jardineiro", 4: "Mineiro", 5: "Sentinela", 6: "Relojoeiro", 7: "Caça-Trovões", 8: "Alquimista", 9: "Corsário", 10: "Arconte Solar"}
const PLAYER = "Nova"
const PLAYER_SLOT = 0
# The rest of the named cast and where each one stands in the draw. `wins` is how many
# rounds they win before they fall; the bosses fall to the player, everyone else to the
# bracket. `out` marks a withdrawal instead of a defeat. These are the stories the paper
# follows while the player is busy with its own.
const FIGURES = {
	"Aurel": {"slot": 768, "wins": 8, "rating": 99, "skin": 11, "hue": "e8bd78", "region": "Coroa"},
	"Vértice": {"slot": 192, "wins": 6, "rating": 96, "skin": 108, "hue": "d28263", "region": "Farol"},
	"Lira": {"slot": 196, "wins": 2, "rating": 95, "skin": 103, "hue": "bd9ee0", "region": "Farol"},
	"Nina Vento": {"slot": 896, "wins": 7, "rating": 41, "skin": 112, "hue": "7fd6a4", "region": "Delta"},
	"Kael Brasa": {"slot": 640, "wins": 3, "rating": 94, "skin": 121, "hue": "ff8f5c", "region": "Planalto", "out": true},
	"Oto Fio": {"slot": 384, "wins": 7, "rating": 90, "skin": 135, "hue": "8fb3ff", "region": "Anel Norte"},
	"Mara Lume": {"slot": 48, "wins": 4, "rating": 88, "skin": 117, "hue": "ffd06b", "region": "Baía"},
}
const FIRST = ["Aro", "Bora", "Ciro", "Duna", "Elo", "Faro", "Gala", "Hélio", "Ivo", "Juno", "Kito", "Lume", "Miro", "Nexo", "Ola", "Pico", "Quim", "Runa", "Salo", "Tila", "Umi", "Vela", "Wilo", "Xara", "Yuna", "Zuri", "Ária", "Bruma", "Cora", "Domo", "Eco", "Téo", "Mavi", "Bento", "Suri", "Orion", "Nila", "Dário", "Íris", "Zeno", "Vésper", "Rita", "Gil", "Leda", "Tao"]
const LAST = ["Vale", "Mar", "Norte", "Sul", "Brasa", "Névoa", "Luz", "Aço", "Vento", "Duna", "Rocha", "Ponte", "Farol", "Cais", "Serra", "Cobre", "Areia", "Lago", "Pinho", "Faísca", "Prata", "Onda", "Vidro", "Ferro"]
const REGIONS = ["Farol", "Pedreira", "Órbita", "Bastião", "Jardim", "Pêndulo", "Tempestade", "Cristal", "Recife", "Solar", "Coroa", "Delta", "Anel Norte", "Baía", "Vale Alto", "Planalto"]

var path = SAVE_PATH
var seed_value = 0
var entrance_passed = false
var entrance_score: Array = []
# Bracket rounds the player has won: 0 to 10.
var wins = 0
# The player's own run: one record per match won, admission included.
var history: Array = []
# After round r (1-based), winners[r - 1] holds the slots still in.
var winners: Array = []
# Everything that happened, in order: the paper, the kiosk and the route read these.
var events: Array = []
# Matches lost on the way. Not canon - a retry is always there - but the kiosk remembers.
var attempts: Array = []
# The newest edition the player has opened.
var editions_read = -1
var entrants: Array = []

func _init() -> void:
	seed_value = randi() % 900000 + 100000
	reset()

static func story_levels() -> Array:
	# The admission and the ten rounds are the campaign's eleven levels, in order.
	return Campaign.menu_levels()

static func boss_of(step: int) -> int:
	return int(Campaign.LEVELS[story_levels()[clampi(step, 0, ROUNDS)]].boss)

static func boss_slot(round_number: int) -> int:
	# Each boss waits alone in the half of the draw the player meets in that round.
	return 1 << (round_number - 1)

static func field_after(round_number: int) -> int:
	return FIELD >> round_number

func reset() -> void:
	entrance_passed = false
	entrance_score = []
	wins = 0
	history.clear()
	winners.clear()
	events.clear()
	attempts.clear()
	editions_read = -1
	prepare_entrants()

# --- the draw ------------------------------------------------------------------------

func prepare_entrants() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	entrants.clear()
	# Every first-and-last pairing, shuffled by the seed: 1 080 of them for 1 024 places,
	# so no two pilots in the draw share a name.
	var pairings: Array = []
	for first in FIRST:
		for last in LAST:
			pairings.append("%s %s" % [first, last])
	for i in range(pairings.size() - 1, 0, -1):
		var j = rng.randi() % (i + 1)
		var keep = pairings[i]
		pairings[i] = pairings[j]
		pairings[j] = keep
	for slot in range(FIELD):
		var name_value: String = pairings[slot]
		entrants.append({"slot": slot, "name": name_value, "region": REGIONS[rng.randi() % REGIONS.size()],
			"hue": Color.from_hsv(rng.randf(), rng.randf_range(0.35, 0.6), rng.randf_range(0.78, 0.95)).to_html(false),
			"symbol": rng.randi() % 8, "rating": rng.randi_range(28, 84), "skin": 100 + rng.randi() % 50, "wins": -1, "cast": ""})
	entrants[PLAYER_SLOT] = {"slot": PLAYER_SLOT, "name": PLAYER, "region": "Aurora", "hue": "81d9c4", "symbol": 0, "rating": 100, "skin": 0, "wins": ROUNDS, "cast": "player"}
	for round_number in range(1, ROUNDS + 1):
		var boss = boss_of(round_number)
		var slot = boss_slot(round_number)
		entrants[slot] = {"slot": slot, "name": BOSS_NAMES[boss], "region": ["Farol", "Órbita", "Jardim", "Pedreira", "Bastião", "Pêndulo", "Tempestade", "Cristal", "Recife", "Solar"][boss - 1], "hue": "", "symbol": 0, "rating": 97, "skin": boss, "wins": round_number - 1 if round_number < ROUNDS else ROUNDS - 1, "cast": "boss"}
	for who in FIGURES:
		var f: Dictionary = FIGURES[who]
		entrants[f.slot] = {"slot": f.slot, "name": who, "region": f.region, "hue": f.hue, "symbol": 0, "rating": f.rating, "skin": f.skin, "wins": f.wins, "cast": "figure", "out": f.get("out", false)}

func entrant(slot: int) -> Dictionary:
	return entrants[clampi(slot, 0, FIELD - 1)]

func slot_of(who: String) -> int:
	if who == PLAYER or who == "Tu": return PLAYER_SLOT
	for e in entrants:
		if e.name == who: return e.slot
	return -1

func alive(round_number: int) -> Array:
	# Who is still in after `round_number` rounds have been played (0 = the full field).
	if round_number <= 0: return range(FIELD)
	return winners[mini(round_number, winners.size()) - 1]

func rounds_played() -> int:
	return winners.size()

func is_alive(slot: int) -> bool:
	return alive(rounds_played()).has(slot)

func eliminated_in(slot: int) -> int:
	# The round a pilot fell in, or 0 while still in.
	for r in range(1, rounds_played() + 1):
		if not winners[r - 1].has(slot): return r
	return 0

func opponent_in(slot: int, round_number: int) -> int:
	# Who this pilot met in that round, once the round before it has been played.
	var pool: Array = alive(round_number - 1)
	var index = pool.find(slot)
	if index < 0: return -1
	return pool[index ^ 1] if (index ^ 1) < pool.size() else -1

func block(slot: int, round_number: int) -> Array:
	# The stretch of the draw a round-r opponent of this slot can come from.
	var width = 1 << (round_number - 1)
	var start = (slot / (width * 2)) * width * 2 + (width if (slot / width) % 2 == 0 else 0)
	return range(start, start + width)

func possible_opponents(round_number: int) -> Array:
	# Everyone still standing in the part of the draw the player would meet in that round.
	# Never a single name for a round that has not been decided: curiosity, not spoilers.
	var candidates: Array = block(PLAYER_SLOT, round_number)
	var standing: Array = alive(rounds_played())
	return candidates.filter(func(s): return standing.has(s))

# --- the player's run ----------------------------------------------------------------

func step() -> int:
	# 0 = admission, 1..10 = the round to play next, 11 = the cup is won.
	return 0 if not entrance_passed else wins + 1

func champion() -> bool:
	return wins >= ROUNDS

func level_index(at_step: int = -1) -> int:
	return story_levels()[clampi(step() if at_step < 0 else at_step, 0, ROUNDS)]

func round_name(at_step: int = -1) -> String:
	return ROUND_NAMES[clampi(step() if at_step < 0 else at_step, 0, ROUNDS)]

func boss_id() -> int:
	return boss_of(mini(step(), ROUNDS))

func opponent() -> String:
	if not entrance_passed: return "Aurora"
	return BOSS_NAMES[boss_id()] if not champion() else ""

func confirmed_match() -> Dictionary:
	if champion(): return {}
	var s = step()
	return {"name": opponent(), "step": s, "round": s, "round_name": round_name(s), "entrance": s == 0,
		"is_final": s == ROUNDS, "grand_final": s == ROUNDS, "boss": boss_id(), "hue": "",
		"level": level_index(s), "field": FIELD if s == 0 else field_after(s - 1)}

func level() -> Dictionary:
	var entry: Dictionary = Campaign.LEVELS[level_index()].duplicate(true)
	if not entrance_passed:
		entry.name = "Admissão · " + String(entry.name)
		entry.challenge = "Vence a Aurora para entrar na Taça. Move-te para apontar, abre a defesa e marca."
	return entry

func profile(difficulty: int) -> Dictionary:
	return Campaign.ai_profile(level_index(), difficulty)

func kit() -> Array:
	return Campaign.boss_kit(level_index())

func ultimate() -> String:
	return String(Skins.CATALOG[boss_id()].ultimate) if boss_id() < Skins.CATALOG.size() else ""

func defeated_bosses() -> Array:
	return history.filter(func(h): return int(h.get("boss", 0)) > 0).map(func(h): return int(h.boss))

func record(kind: String, subject: String, other: String = "", tier: int = 1, extra: Dictionary = {}) -> void:
	var event = {"id": events.size(), "type": kind, "step": step(), "subject": subject, "other": other, "tier": tier}
	event.merge(extra)
	events.append(event)

func complete(score: Array) -> bool:
	if champion(): return false
	var s = step()
	var entry: Dictionary = Campaign.LEVELS[level_index(s)]
	var result = "%d–%d" % [int(score[0]) if score.size() > 0 else 2, int(score[1]) if score.size() > 1 else 0]
	history.append({"step": s, "round_name": round_name(s), "opponent": opponent(), "boss": boss_id() if s > 0 else 0,
		"score": score.duplicate(), "result": result, "arena": String(entry.name), "level": level_index(s)})
	if s == 0:
		entrance_passed = true
		entrance_score = score.duplicate()
		record("PLAYER_ENTERED", PLAYER, "Aurora", 1, {"score": result})
		return true
	var beaten = opponent()
	wins += 1
	simulate_round(wins)
	record("PLAYER_WON_MATCH", PLAYER, beaten, 1, {"score": result, "round": wins})
	record("PLAYER_DEFEATED_BOSS", PLAYER, beaten, 2 if wins < ROUNDS else 4, {"score": result, "round": wins})
	if wins < ROUNDS:
		record("PLAYER_REACHED_ROUND", PLAYER, ROUND_NAMES[wins + 1], 1 if wins < 6 else 2, {"round": wins, "field": field_after(wins)})
	else:
		record("PLAYER_CHAMPION", PLAYER, beaten, 4, {"score": result, "round": wins})
	return true

func lose(score: Array) -> void:
	# A defeat is not the end: the round waits for a retry. It is remembered, not printed.
	attempts.append({"step": step(), "opponent": opponent(), "score": score.duplicate()})

func losses_here() -> int:
	var s = step()
	return attempts.filter(func(a): return int(a.step) == s).size()

# --- the rest of the draw ------------------------------------------------------------

func match_seed(round_number: int, slot: int) -> int:
	return hash([seed_value, round_number, slot])

func decide(a: int, b: int, round_number: int) -> int:
	# Scripted figures win exactly as many rounds as their story says; the player always
	# wins its own match (it is only simulated once the player has won it); everyone else
	# is settled by rating and a fixed roll per match.
	var ea: Dictionary = entrants[a]
	var eb: Dictionary = entrants[b]
	var fa: int = int(ea.wins)
	var fb: int = int(eb.wins)
	if fa >= 0 and fb >= 0:
		if fa == fb: return a if a < b else b
		return a if fa > fb else b
	if fa >= 0: return a if fa >= round_number else b
	if fb >= 0: return b if fb >= round_number else a
	var rng = RandomNumberGenerator.new()
	rng.seed = match_seed(round_number, mini(a, b))
	var edge = float(ea.rating - eb.rating) / 60.0
	return a if rng.randf() < clampf(0.5 + edge, 0.12, 0.88) else b

func score_for(round_number: int, winner: int, loser: int) -> String:
	var rng = RandomNumberGenerator.new()
	rng.seed = match_seed(round_number, winner * FIELD + loser)
	return "2–0" if rng.randf() < 0.55 else "2–1"

func simulate_round(round_number: int) -> void:
	var pool: Array = alive(round_number - 1)
	var next: Array = []
	for i in range(0, pool.size(), 2):
		var a: int = pool[i]
		var b: int = pool[i + 1]
		var victor = decide(a, b, round_number)
		var loser = b if victor == a else a
		next.append(victor)
		tell(round_number, victor, loser)
	winners.append(next)
	record("TOURNAMENT_ROUND_COMPLETED", ROUND_NAMES[round_number], "", 0, {"round": round_number, "field": next.size()})
	if round_number == ROUNDS - 1:
		var other = next.filter(func(s): return s != PLAYER_SLOT)
		record("FINALISTS_DECIDED", PLAYER, entrants[other[0]].name if not other.is_empty() else "", 4, {"round": round_number})

func tell(round_number: int, victor: int, loser: int) -> void:
	# The results the paper cares about, turned into events as they happen.
	var w: Dictionary = entrants[victor]
	var l: Dictionary = entrants[loser]
	if victor == PLAYER_SLOT or loser == PLAYER_SLOT: return
	var score = score_for(round_number, victor, loser)
	if l.cast == "figure":
		if l.get("out", false):
			record("WITHDRAWAL", l.name, w.name, 2, {"round": round_number})
		elif l.name in ["Aurel", "Lira"]:
			record("FAVORITE_ELIMINATED", l.name, w.name, 4 if l.name == "Aurel" else 3, {"round": round_number, "score": score})
		elif l.name == "Nina Vento":
			record("UPSET_ENDS", l.name, w.name, 2, {"round": round_number, "score": score})
		else:
			record("RIVAL_ELIMINATED", l.name, w.name, 2, {"round": round_number, "score": score})
	if w.cast == "figure":
		if w.name == "Nina Vento" and round_number >= 3:
			record("UPSET", w.name, l.name, 2 if round_number >= 5 else 1, {"round": round_number, "score": score})
		elif w.name in ["Oto Fio", "Vértice", "Mara Lume"] and round_number >= 2:
			record("RIVAL_ADVANCED", w.name, l.name, 1, {"round": round_number, "score": score, "streak": round_number})
		elif w.name == "Aurel" and round_number >= 4:
			record("FAVORITE_ADVANCED", w.name, l.name, 1, {"round": round_number, "score": score})
	if w.cast == "boss":
		# The boss the player meets next, and the Arconte on the far side, make the news.
		var next_boss = round_number + 1 <= ROUNDS and victor == boss_slot(round_number + 1)
		var arconte = victor == boss_slot(ROUNDS) and round_number >= 3
		if next_boss or arconte:
			record("BOSS_ADVANCED", w.name, l.name, 2 if l.cast == "figure" else 1, {"round": round_number, "score": score, "next": next_boss})

# --- save ------------------------------------------------------------------------------

func save() -> Error:
	var data = ConfigFile.new()
	data.set_value("taca", "version", SAVE_VERSION)
	data.set_value("taca", "seed", seed_value)
	data.set_value("taca", "entrance_passed", entrance_passed)
	data.set_value("taca", "entrance_score", entrance_score)
	data.set_value("taca", "wins", wins)
	data.set_value("taca", "history", history)
	data.set_value("taca", "winners", winners)
	data.set_value("taca", "events", events)
	data.set_value("taca", "attempts", attempts)
	data.set_value("taca", "editions_read", editions_read)
	data.set_value("taca", "names", entrants.map(func(e): return e.name))
	return data.save(path)

func restore() -> void:
	var data = ConfigFile.new()
	if data.load(path) != OK or int(data.get_value("taca", "version", 0)) != SAVE_VERSION:
		return
	seed_value = int(data.get_value("taca", "seed", seed_value))
	reset()
	# The draw is rebuilt from the seed, then the saved names are laid over it, so a pilot
	# keeps its name even if the name lists grow in a later version.
	var names: Array = data.get_value("taca", "names", [])
	if names.size() == FIELD:
		for slot in range(FIELD):
			if entrants[slot].cast == "": entrants[slot].name = String(names[slot])
	entrance_passed = bool(data.get_value("taca", "entrance_passed", false))
	entrance_score = Array(data.get_value("taca", "entrance_score", []))
	wins = clampi(int(data.get_value("taca", "wins", 0)), 0, ROUNDS)
	history = Array(data.get_value("taca", "history", []))
	winners = Array(data.get_value("taca", "winners", []))
	events = Array(data.get_value("taca", "events", []))
	attempts = Array(data.get_value("taca", "attempts", []))
	editions_read = int(data.get_value("taca", "editions_read", -1))
	# A save from before the rounds were stored plays them out again, identically.
	if winners.size() != wins:
		winners.clear()
		for r in range(1, wins + 1):
			var keep = events.duplicate()
			simulate_round(r)
			events = keep
