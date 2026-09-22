extends RefCounted
## Saved tournament: ten stages of ten qualifiers and a confirmed sector champion.
const Campaign = preload("res://scripts/campaign.gd")
const Skins = preload("res://scripts/skins.gd")
const SAVE_PATH = "user://cup_v1.cfg"
const FULL_STAGES = 10
const FULL_MATCHES = 110
const DEMO_MATCHES = FULL_MATCHES # Compatibility with the tournament desk.
const NAMES = ["Téo", "Mavi", "Bento", "Suri", "Orion", "Nila", "Dário", "Íris", "Zeno", "Vésper"]
const COLORS = ["73cabb", "e6b87b", "b39ae1", "8ac5eb", "d59b82", "a8c778", "d5a3c3", "e4ca88", "83b6cc", "de8d79"]
const SEEDS = ["Aro", "Bora", "Ciro", "Duna", "Elo", "Faro", "Gala", "Hélio", "Ivo", "Juno", "Kito", "Lume", "Miro", "Nexo", "Ola", "Pico", "Quim", "Runa", "Salo", "Tila", "Umi", "Vela", "Wilo", "Xara", "Yuna", "Zuri", "Ária", "Bruma", "Cora", "Domo", "Eco", "Fio"]
const BOSS_NAMES = {1: "Faroleiro", 2: "Astrónomo", 3: "Jardineiro", 4: "Mineiro", 5: "Sentinela", 6: "Relojoeiro", 7: "Caça-Trovões", 8: "Alquimista", 9: "Corsário", 10: "Arconte Solar"}
var path = SAVE_PATH
var wins = 0
var history: Array = []
var entrants: Array = []
var rounds: Array = []
var headlines: Array = []
var world_results: Array = []
var seed_value = 0
var boss_order: Array = []

func _init() -> void:
	seed_value = randi()
	reset()

func reset() -> void:
	wins = 0
	history.clear()
	rounds.clear()
	world_results.clear()
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	boss_order = [4, 8, 6, 3, 9, 7, 2, 5]
	for i in range(boss_order.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var swap = boss_order[i]
		boss_order[i] = boss_order[j]
		boss_order[j] = swap
	boss_order.push_front(1)
	boss_order.append(10)
	headlines = [{"round": 0, "title": "Uma taça. Mil percursos.", "body": "Cada vitória tua faz avançar a competição."}, {"round": 0, "title": "Aurel procura o penta", "body": "O tetracampeão domina as capas. Sentinela e Arconte Solar entram na luta pelo título."}]
	prepare_entrants()

func stage_index(at: int = -1) -> int:
	return mini((wins if at < 0 else at) / 11, FULL_STAGES - 1)

func local_wins(at: int = -1) -> int:
	var count = wins if at < 0 else at
	return 11 if count >= FULL_MATCHES else count % 11

func sector_label(at: int = -1) -> String:
	var index = stage_index(at)
	return "FAROL" if index == 0 else ("FASE FINAL" if index == 9 else "SETOR %02d" % (index + 1))

func boss_id() -> int:
	return boss_order[stage_index()]

func normal_name(stage: int, index: int) -> String:
	return NAMES[index] if stage == 0 else "%s %s" % [SEEDS[(stage * 7 + index) % 32], ["Vale", "Mar", "Norte", "Sul", "Brasa", "Névoa", "Luz", "Aço", "Vento"][stage - 1]]

func prepare_entrants() -> void:
	entrants.clear()
	var stage = stage_index()
	for i in range(1024):
		entrants.append({"id": i, "name": "%s %s%s" % [SEEDS[i % 32], SEEDS[i / 32], "" if stage == 0 else " · %02d" % (stage + 1)], "rating": 35 + (i * 17 + stage * 11) % 50})
	entrants[0] = {"id": 0, "name": BOSS_NAMES[boss_id()], "rating": 100}
	if stage == 0:
		entrants[512] = {"id": 512, "name": "Lira", "rating": 98}
		entrants[576] = {"id": 576, "name": "Vértice", "rating": 99}
	elif stage == 9:
		entrants[512] = {"id": 512, "name": "Aurel", "rating": 99}

func stage_rounds(stage: int = -1) -> Array:
	var index = stage_index() if stage < 0 else stage
	return rounds.filter(func(r): return r.stage == index)

func opponent() -> String:
	return BOSS_NAMES[boss_id()] if local_wins() >= 10 else normal_name(stage_index(), local_wins())

func confirmed_match() -> Dictionary:
	if wins >= FULL_MATCHES: return {}
	var name_value = opponent()
	if local_wins() == 10:
		var played = stage_rounds()
		if played.size() != 10 or played.back().winners.size() != 1: return {}
		var winner: Dictionary = played.back().winners[0]
		var fixtures: Array = played.back().fixtures
		if fixtures.size() != 1 or fixtures[0].winner != winner.name: return {}
		name_value = winner.name
	var entry = level()
	return {"name": name_value, "round": wins + 1, "is_final": local_wins() == 10,
		"grand_final": wins == FULL_MATCHES - 1, "boss": entry.boss, "hue": entry.hue}

func level() -> Dictionary:
	var sources = [0, 1, 2, 3, 4, 5, 6, 7, 8, 1]
	var result: Dictionary = Campaign.LEVELS[sources[mini(local_wins(), 9)]].duplicate(true)
	if local_wins() >= 10:
		for entry in Campaign.LEVELS:
			if entry.boss == boss_id():
				result = entry.duplicate(true)
				break
	result.map.id = "cup_%03d" % mini(wins, 109)
	result.name = ("Grande final" if wins == 109 else "Final do setor") if local_wins() >= 10 else "Qualificatória %02d" % (local_wins() + 1)
	result.boss = boss_id() if local_wins() >= 10 else 100 + local_wins()
	result.hue = "" if local_wins() >= 10 else COLORS[local_wins()]
	return result

func profile(difficulty: int) -> Dictionary:
	var t = minf(wins / 109.0, 1.0)
	var factor = [1.35, 1.0, 0.72][clampi(difficulty, 0, 2)]
	return {"fire_gap": lerpf(2.6, 0.7, t) * factor, "move": lerpf(0.32, 0.72, t), "dodge": wins >= 5, "power_gap": lerpf(14.0, 6.0, t) * factor, "ultimate_wait": 32.0 * factor, "charge_tick": 2.5 * factor, "ultimate_gap": 38.0, "ultimate_rate": 1.0}

func kit() -> Array:
	if wins < 3: return ["blast", "air"]
	return [["blast", "walls"], ["rapid", "weld"], ["air", "ghost"], ["blast", "mirror"], ["rapid", "magnet"], ["pierce", "walls"], ["air", "freeze"]][wins % 7].duplicate()

func ultimate() -> String:
	if local_wins() >= 10: return Skins.CATALOG[boss_id()].ultimate
	var equipped = kit()
	if "walls" in equipped or "mirror" in equipped: return "b_bar"
	if "weld" in equipped: return "b_patch"
	if "freeze" in equipped: return "b_slow"
	if "magnet" in equipped: return "b_aim"
	if "pierce" in equipped: return "b_drill"
	return "b_forge" if "rapid" in equipped else "b_salvo"

func defeated_bosses() -> Array:
	return history.filter(func(h): return h.get("boss", 0) > 0).map(func(h): return h.boss)

func complete(score: Array) -> bool:
	if confirmed_match().is_empty(): return false
	var stage = stage_index()
	var local = local_wins()
	history.append({"opponent": opponent(), "score": score.duplicate(), "round": wins + 1, "stage": stage, "boss": boss_id() if local == 10 else 0})
	wins += 1
	if local < 10:
		var played = stage_rounds(stage)
		var pool: Array = entrants if played.is_empty() else played.back().winners
		var winners: Array = []
		var fixtures: Array = []
		for i in range(0, pool.size(), 2):
			var a: Dictionary = pool[i]
			var b: Dictionary = pool[i + 1]
			var victor: Dictionary = a if a.rating >= b.rating else b
			var loser: Dictionary = b if victor.id == a.id else a
			var record = {"winner": victor.name, "loser": loser.name, "score": "2–%d" % ((i + wins) % 2), "round": wins, "stage": stage}
			fixtures.append(record)
			winners.append(victor)
			if loser.name == "Lira": headlines.append({"round": wins, "title": "A favorita caiu: Vértice elimina Lira", "body": "A promessa sai da Taça. Vértice conquistou o lugar em campo."})
			if loser.name == "Vértice": headlines.append({"round": wins, "title": "Faroleiro vence a revelação Vértice", "body": "Ele também teve de chegar até aqui. O confronto contigo está confirmado."})
			if loser.name == "Aurel": headlines.append({"round": wins, "title": "O penta caiu: Arconte Solar elimina Aurel", "body": "A semifinal terminou. O tetracampeão está fora; Arconte Solar conquistou a outra vaga na grande final."})
		rounds.append({"winners": winners, "fixtures": fixtures, "stage": stage, "round": wins})
		# Distant results are explicit published fixtures, never inferred from a cover.
		if stage < 9:
			for who in ["Aurel", "Sentinela", "Arconte Solar"]:
				if who == "Sentinela" and defeated_bosses().has(5): continue
				if who == BOSS_NAMES[boss_order[stage]]: continue
				world_results.append({"winner": who, "loser": "Piloto %s-%03d" % [who, wins], "score": "2–%d" % (wins % 2), "round": wins, "stage": stage})
		headlines.append({"round": wins, "title": BOSS_NAMES[boss_order[stage]] + " avança", "body": "%d participantes continuam na chave do setor." % winners.size()})
	else:
		headlines.append({"round": wins, "title": "Conquistaste o setor", "body": "Venceste %s e ganhaste a sua skin." % history.back().opponent})
		if wins < FULL_MATCHES: prepare_entrants()
	return true

func save() -> Error:
	var data = ConfigFile.new()
	data.set_value("cup", "version", 2)
	data.set_value("cup", "seed", seed_value)
	data.set_value("cup", "wins", wins)
	data.set_value("cup", "history", history)
	return data.save(path)

func restore() -> void:
	var data = ConfigFile.new()
	if data.load(path) != OK: return
	seed_value = int(data.get_value("cup", "seed", 2026))
	var count = clampi(int(data.get_value("cup", "wins", 0)), 0, FULL_MATCHES)
	var saved = data.get_value("cup", "history", [])
	reset()
	for i in range(count):
		var score: Array = [2, 0]
		if saved is Array and i < saved.size() and saved[i] is Dictionary and saved[i].get("score") is Array: score = saved[i].score
		complete(score)
