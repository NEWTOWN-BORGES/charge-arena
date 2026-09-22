extends RefCounted
## Demo: ten qualifying bouts and the winner of the parallel regional bracket.
## All fixtures are deterministic and persisted; retries never advance the other bracket.
const Campaign = preload("res://scripts/campaign.gd")
const SAVE_PATH = "user://cup_v1.cfg"
const DEMO_MATCHES = 11
const FULL_STAGES = 11
const FULL_MATCHES = 121
const NAMES = ["Téo", "Mavi", "Bento", "Suri", "Orion", "Nila", "Dário", "Íris", "Zeno", "Vésper"]
const COLORS = ["73cabb", "e6b87b", "b39ae1", "8ac5eb", "d59b82", "a8c778", "d5a3c3", "e4ca88", "83b6cc", "de8d79"]
const SEEDS = ["Aro", "Bora", "Ciro", "Duna", "Elo", "Faro", "Gala", "Hélio", "Ivo", "Juno", "Kito", "Lume", "Miro", "Nexo", "Ola", "Pico", "Quim", "Runa", "Salo", "Tila", "Umi", "Vela", "Wilo", "Xara", "Yuna", "Zuri", "Ária", "Bruma", "Cora", "Domo", "Eco", "Fio"]
var path = SAVE_PATH
var wins = 0
var history: Array = []
var entrants: Array = []
var rounds: Array = []
var headlines: Array = []

func _init() -> void:
	reset()

func reset() -> void:
	wins = 0
	history.clear()
	rounds.clear()
	headlines = [{"round": 0, "title": "Uma taça. Mil percursos.", "body": "Dez qualificatórias separam-te do vencedor da chave do Farol. Cada vitória tua faz avançar o resto da competição."}, {"round": 0, "title": "Aurel procura o quarto título", "body": "O tricampeão domina as capas. No outro setor, um estreante chamado Nadir chega sem equipa nem favoritos."}]
	entrants.clear()
	for i in range(1024):
		entrants.append({"id": i, "name": "%s %s" % [SEEDS[i % 32], SEEDS[i / 32]], "rating": 35 + (i * 17) % 50})
	entrants[0] = {"id": 0, "name": "FAROLEIRO", "rating": 100}
	entrants[512] = {"id": 512, "name": "Lira", "rating": 98}
	entrants[576] = {"id": 576, "name": "Vértice", "rating": 99}

func opponent() -> String:
	return "FAROLEIRO" if wins >= 10 else NAMES[wins]

func level() -> Dictionary:
	# Reuse proven collision layouts, not decorative geometry with mismatched walls.
	var sources = [0, 1, 2, 3, 4, 5, 6, 7, 8, 1, 1]
	var result: Dictionary = Campaign.LEVELS[sources[mini(wins, 10)]].duplicate(true)
	result.map.id = "cup_%02d" % mini(wins, 10)
	result.name = "Final do Farol" if wins >= 10 else "Qualificatória %02d" % (wins + 1)
	result.boss = 1 if wins >= 10 else 100 + wins
	result.hue = "" if wins >= 10 else COLORS[wins]
	return result

func profile(difficulty: int) -> Dictionary:
	var t = mini(wins, 10) / 10.0
	var factor = [1.35, 1.0, 0.72][clampi(difficulty, 0, 2)]
	return {"fire_gap": lerpf(2.6, 0.7, t) * factor, "move": lerpf(0.32, 0.72, t), "dodge": wins >= 5, "power_gap": lerpf(14.0, 6.0, t) * factor, "ultimate_wait": 32.0 * factor, "charge_tick": 2.5 * factor, "ultimate_gap": 38.0, "ultimate_rate": 1.0}

func kit() -> Array:
	if wins < 3:
		return ["blast", "air"]
	return [["blast", "walls"], ["rapid", "weld"], ["air", "ghost"], ["blast", "mirror"]][wins % 4].duplicate()

func complete(score: Array) -> bool:
	if wins >= DEMO_MATCHES:
		return false
	history.append({"opponent": opponent(), "score": score.duplicate(), "round": wins + 1})
	wins += 1
	if wins <= 10:
		var pool: Array = entrants if rounds.is_empty() else rounds.back().winners
		var winners: Array = []
		var fixtures: Array = []
		for i in range(0, pool.size(), 2):
			var a: Dictionary = pool[i]
			var b: Dictionary = pool[i + 1]
			var victor: Dictionary = a if a.rating >= b.rating else b
			var loser: Dictionary = b if victor.id == a.id else a
			var result = {"winner": victor.name, "loser": loser.name, "score": "2–%d" % ((i + wins) % 2)}
			fixtures.append(result)
			winners.append(victor)
			if loser.name == "Lira":
				headlines.append({"round": wins, "title": "A favorita caiu: Vértice elimina Lira", "body": "A promessa do setor sai da Taça. O nome que ninguém conhecia ocupa agora o lugar dela."})
			if loser.name == "Vértice":
				headlines.append({"round": wins, "title": "Faroleiro vence a revelação Vértice", "body": "Ele também teve de chegar até aqui. A próxima partida é contra ti."})
		rounds.append({"winners": winners, "fixtures": fixtures})
		headlines.append({"round": wins, "title": "Faroleiro avança · %d ainda em prova" % winners.size(), "body": "Chave do Farol: 2–%d. Resultados completos guardados na árvore." % (wins % 2)})
		if wins in [1, 3, 5, 8]:
			headlines.append({"round": wins, "title": "Aurel continua a mandar", "body": "Noutro setor, o tricampeão vence por 2–0. A imprensa já fala do quarto título."})
		if wins in [2, 4, 6, 9]:
			headlines.append({"round": wins, "title": "Nadir: mais uma vitória sem sofrer", "body": "Nota de rodapé do setor exterior: 2–0. Sem entrevistas, sem derrotas. Um percurso longe das câmaras."})
		if wins in [2, 5, 8]:
			var rivals = ["Mineiro", "Astrónomo", "Sentinela"]
			var rival_name = rivals[[2, 5, 8].find(wins)]
			headlines.append({"round": wins, "title": rival_name + " vence no seu setor", "body": "Resultado confirmado: 2–1. Os futuros chefes também estão a disputar o seu lugar na Taça."})
		if wins == 3:
			headlines.append({"round": wins, "title": "Lira é a nova promessa do Farol", "body": "Três eliminatórias vencidas. Os comentadores já a imaginam na final do setor."})
	else:
		headlines.append({"round": wins, "title": "O Farol tem um novo vencedor: tu", "body": "Demo concluída. Ganhaste a skin Faroleiro. O Mineiro avança no próximo setor; Aurel e Nadir continuam nos seus percursos."})
	return true

func save() -> Error:
	var data = ConfigFile.new()
	data.set_value("cup", "wins", wins)
	data.set_value("cup", "history", history)
	return data.save(path)

func restore() -> void:
	var data = ConfigFile.new()
	if data.load(path) != OK:
		return
	var count = clampi(int(data.get_value("cup", "wins", 0)), 0, DEMO_MATCHES)
	var saved = data.get_value("cup", "history", [])
	reset()
	for i in range(count):
		var score: Array = [2, 0]
		if saved is Array and i < saved.size() and saved[i] is Dictionary and saved[i].get("score") is Array:
			score = saved[i].score
		complete(score)
