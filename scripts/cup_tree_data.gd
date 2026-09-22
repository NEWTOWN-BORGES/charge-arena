extends RefCounted
## Public knowledge projected from completed fixtures. No future seed ratings exposed.
const News = preload("res://scripts/cup_news.gd")
const CAST = {
	"Tu": [0, "81d9c4", "Qualificatórias"],
	"Faroleiro": [1, "81d9c4", "Farol"],
	"Lira": [103, "bd9ee0", "Farol"],
	"Vértice": [108, "d28263", "Farol"],
	"Aurel": [10, "e8bd78", "Coroa"],
	"Nadir": [105, "839da7", "Exterior"],
	"Mineiro": [4, "b99668", "Pedreira"],
	"Astrónomo": [2, "aaa7ed", "Órbita"],
	"Sentinela": [5, "8dbbd7", "Bastião"],
	"Jardineiro": [3, "9ecb86", "Jardim"],
	"Relojoeiro": [6, "d2b990", "Pêndulo"]
}
static func public_name(value: String) -> String:
	return "Faroleiro" if value.to_upper() == "FAROLEIRO" else value
static func profile(cup, who: String) -> Dictionary:
	var p = {"name": who, "state": "ACTIVE", "wins": 0, "history": [], "eliminated_by": "", "sector": CAST.get(who, [0, "", "Farol"])[2], "meeting": "Ainda por determinar", "tag": "PILOTO", "confirmed_only": false}
	if who == "Tu":
		p.state = "PLAYER"
		p.tag = "O TEU PERCURSO"
		p.wins = cup.wins
		for match_record in cup.history:
			p.history.append({"winner": "Tu", "loser": public_name(match_record.opponent), "score": "%s–%s" % match_record.score, "round": match_record.round})
		p.meeting = "Setor conquistado" if cup.wins >= 11 else ("Final do setor" if cup.wins == 10 else "Qualificatória %02d" % (cup.wins + 1))
		return p
	if who in ["Faroleiro", "Lira", "Vértice"] or not CAST.has(who):
		for r in range(cup.rounds.size()):
			for fixture in cup.rounds[r].fixtures:
				if who not in [public_name(fixture.winner), public_name(fixture.loser)]: continue
				var record: Dictionary = fixture.duplicate()
				record.winner = public_name(record.winner)
				record.loser = public_name(record.loser)
				record.round = r + 1
				p.history.append(record)
				if record.winner == who: p.wins += 1
				else:
					p.state = "ELIMINATED"
					p.eliminated_by = record.winner
		if who == "Faroleiro" and cup.wins >= 11:
			p.state = "ELIMINATED"
			p.eliminated_by = "Tu"
			p.history.append({"winner": "Tu", "loser": who, "score": "%s–%s" % cup.history[10].score, "round": 11})
		p.meeting = "Não se cruzará contigo neste setor" if p.state == "ELIMINATED" else ("Agora · final do setor" if cup.wins == 10 else "Possível final do setor · faltam %d qualificatórias tuas" % (10 - cup.wins))
		p.tag = "PROMESSA" if who == "Lira" else ("REVELAÇÃO" if who == "Vértice" and cup.wins >= 7 else "CHAVE DO FAROL")
	else:
		p.confirmed_only = true
		p.tag = "3× CAMPEÃO DA TAÇA" if who == "Aurel" else "OUTRO SETOR"
		if who == "Aurel": p.state = "CHAMPION"
		# Only count results already published. Distant sectors are not a fabricated
		# second bracket: their full trajectories unlock in future campaign stages.
		var seen_rounds: Array = []
		for news in cup.headlines:
			if news.round == 0 or not str(news.title).begins_with(who): continue
			if seen_rounds.has(news.round): continue
			seen_rounds.append(news.round)
			p.history.append({"winner": who, "loser": "Adversário do setor", "score": "2–0" if who in ["Aurel", "Nadir"] else "2–1", "round": news.round})
		# The journal also publishes Nadir at rounds five and eleven, and Aurel at two.
		for r in range(1, cup.wins + 1):
			for story in News.edition(cup, r):
				if story.personagemPrincipal != who or story.resultado.is_empty() or seen_rounds.has(r): continue
				seen_rounds.append(r)
				p.history.append({"winner": who, "loser": "Adversário do setor", "score": story.resultado, "round": r})
		p.history.sort_custom(func(a, b): return a.round < b.round)
		p.wins = p.history.size()
		p.meeting = "Possível encontro em fases futuras · sem data confirmada"
	return p
static func fixtures(cup, round_index: int, page: int) -> Array:
	if cup.rounds.is_empty(): return []
	var matches: Array = cup.rounds[clampi(round_index, 0, cup.rounds.size() - 1)].fixtures
	return matches.slice(page * 8, mini(matches.size(), page * 8 + 8))
