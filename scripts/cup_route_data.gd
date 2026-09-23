extends RefCounted
## Presentation projection only. Tournament.confirmed_match owns encounter authority.
static func snapshot(cup) -> Dictionary:
	var match_record: Dictionary = cup.confirmed_match()
	var done: bool = cup.wins >= cup.FULL_MATCHES
	var route = {"state": "COMPLETE" if done else ("WAITING" if match_record.is_empty() else "CONFIRMED"), "wins": cup.wins, "round": cup.wins + 1, "opponent": match_record.get("name", ""), "stage": "Ronda %02d" % (cup.wins + 1), "consequence": "Avanças para a próxima ronda.", "history": cup.history.duplicate(true), "large_encounter": match_record.get("is_final", false), "grand_final": match_record.get("grand_final", false), "sector": cup.sector_label()}
	route.history.reverse()
	if done:
		route.stage = "Taça conquistada"
		route.consequence = "Campeão da Taça Aurora. Este é o caminho que construíste."
	elif cup.local_wins() == cup.QUALIFIERS - 1:
		route.consequence = "Conquistas a classificação para a final do setor."
	elif cup.local_wins() == cup.QUALIFIERS:
		route.consequence = "Título do setor + skin do adversário. Avanças para o próximo setor."
		if cup.wins == cup.FULL_MATCHES - 1:
			route.consequence = "Conquistas a Taça Aurora e as skins de prémio da final."
	return route
