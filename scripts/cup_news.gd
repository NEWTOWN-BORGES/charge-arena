extends RefCounted
## Editions contain only fixtures published by the selected date.
const TYPES = ["VICTORY", "UPSET", "INTERVIEW", "RIVALRY", "ELIMINATION", "STREAK", "BOSS_REVEAL", "PLAYER_NEWS", "FINAL", "TOURNAMENT_NEWS"]
const SCENES = ["ARENA_VICTORY", "ARENA_DEFEAT", "POST_MATCH_INTERVIEW", "PRESS_CONFERENCE", "BACKSTAGE", "ARENA_ENTRANCE", "FACE_OFF", "TRAINING", "CROWD_CELEBRATION", "UPSET", "FINAL_PROMO"]

static func article(n: int, key: String, priority: int, kind: String, title: String, body: String, subject: String, scene: String, other: String = "", score: String = "") -> Dictionary:
	return {"id": "%02d_%s" % [n, key], "jornada": n, "prioridade": priority, "tipo": kind, "titulo": title, "subtitulo": body, "personagemPrincipal": subject, "personagemSecundario": other, "resultado": score, "evento": kind, "cenario": scene, "estado": "publicado", "imagem": scene, "ordem": n * 10 + priority, "etapa": "Abertura da Taça" if n == 0 else "Taça Aurora · jornada %03d" % n, "corpo": body}

static func published(cup, who: String, n: int) -> Dictionary:
	var found: Dictionary = {}
	for fixture in cup.world_results:
		if fixture.round <= n and fixture.winner == who: found = fixture
	for round_data in cup.rounds:
		if round_data.round > n: continue
		for fixture in round_data.fixtures:
			if fixture.winner == who or fixture.loser == who:
				if found.is_empty() or fixture.round >= found.round: found = fixture
	for record in cup.history:
		if record.round <= n and record.opponent == who:
			if found.is_empty() or record.round >= found.round:
				found = {"winner": "Tu", "loser": who, "score": "%s–%s" % record.score, "round": record.round}
	return found

static func edition(cup, number: int) -> Array:
	var n = clampi(number, 0, cup.wins)
	var lead = article(n, "cover", 100, "TOURNAMENT_NEWS", "CINCO PASSOS ATÉ AO DESAFIO", "A Taça acelera: cinco batalhas e o vencedor da chave do setor. Aurel chega à procura do penta; os novos pilotos querem mudar a história.", "Aurel", "ARENA_ENTRANCE")
	var stage = cup.stage_index(maxi(0, n - 1))
	if n > 0:
		var result: Dictionary = cup.history[n - 1]
		var local = (n - 1) % cup.STAGE_MATCHES + 1
		var headings = ["UMA NOVA ARENA, UMA NOVA VITÓRIA", "O RICOCHETE QUE MUDOU O JOGO", "A BANCADA JÁ SABE O TEU NOME", "NINGUÉM OFERECE ESTA PASSAGEM", "A ÚLTIMA PORTA ESTÁ ABERTA"]
		var scenes = ["ARENA_ENTRANCE", "ARENA_VICTORY", "CROWD_CELEBRATION", "TRAINING", "BACKSTAGE"]
		var index = (local - 1 + stage) % 5
		lead = article(n, "cover", 100, "PLAYER_NEWS", headings[index], "%s ficou para trás por %s–%s. Etapa %d: %d das cinco batalhas estão vencidas. A arena, os ângulos e os rivais mudam; a passagem continua a ser conquistada em campo." % [result.opponent, result.score[0], result.score[1], stage + 1, mini(local, 5)], "Tu", scenes[index], result.opponent, "%s–%s" % result.score)
		if local == cup.STAGE_MATCHES:
			lead.titulo = "O SETOR %02d TEM NOVO CAMPEÃO" % (stage + 1)
			lead.subtitulo = "Venceste %s. Os adeptos invadem a zona de celebração, a imprensa procura uma declaração e o rival reconhece a tua passagem." % result.opponent
			lead.cenario = "CROWD_CELEBRATION"
		elif local == cup.QUALIFIERS:
			var rounds = cup.stage_rounds(stage).filter(func(r): return r.round <= n)
			if not rounds.is_empty():
				var final: Dictionary = rounds.back().fixtures[0]
				lead = article(n, "cover", 100, "BOSS_REVEAL", final.winner.to_upper() + " GANHOU O SEU LUGAR", "%s superou %s por %s. Os dois percursos cruzam-se agora: a próxima partida decide o setor." % [final.winner, final.loser, final.score], final.winner, "FACE_OFF", "Tu", final.score)
		elif local == 2 and stage % 2 == 0:
			var champion = published(cup, "Aurel", n)
			if not champion.is_empty(): lead = article(n, "cover", 100, "STREAK", ["O FAVORITO SENTE A PRESSÃO", "QUATRO TÍTULOS, NENHUM ATALHO", "AUREL SOB OS HOLOFOTES"][(stage / 2) % 3], "Mais uma vitória de Aurel, agora contra %s. O resultado foi %s; fora da arena, a pergunta sobre o penta volta a dominar a conversa." % [champion.loser, champion.score], "Aurel", ["PRESS_CONFERENCE", "BACKSTAGE", "ARENA_VICTORY"][(stage / 2) % 3], champion.loser, champion.score)
		if n == 3:
			lead = article(n, "cover", 100, "INTERVIEW", "LIRA JÁ NÃO É UMA SURPRESA", "Seis eliminatórias vencidas na chave paralela. Lira responde aos adeptos antes do próximo desafio.", "Lira", "POST_MATCH_INTERVIEW")
		if n == 4:
			var upset = published(cup, "Lira", n)
			lead = article(n, "cover", 100, "UPSET", "A PROMESSA FICOU PELO CAMINHO", "Vértice elimina Lira. Os prognósticos caem por terra; a chave tem um novo nome a seguir.", "Vértice", "UPSET", "Lira", upset.score)
		if n == cup.FULL_MATCHES - 1:
			var upset = published(cup, "Aurel", n)
			lead = article(n, "cover", 100, "UPSET", "O SILÊNCIO DEPOIS DO PENTA", "Arconte Solar elimina Aurel. O tetracampeão abandona a arena; o vencedor vai disputar contigo a grande final.", "Arconte Solar", "UPSET", "Aurel", upset.score)
		if n == cup.FULL_MATCHES:
			lead.titulo = "A TAÇA É TUA"
			lead.subtitulo = "Sessenta combates. Dez etapas conquistadas. O troféu é teu e toda a arena celebra este percurso."
			lead.tipo = "FINAL"
	var candidates = ["Faroleiro", "Mineiro", "Astrónomo", "Jardineiro", "Sentinela", "Relojoeiro", "Corsário", "Caça-Trovões", "Alquimista", "Arconte Solar"]
	var focus: String = candidates[(n + stage * 3) % candidates.size()]
	var record = published(cup, focus, n)
	var fallen = not record.is_empty() and record.loser == focus
	var report = article(n, "report", 60, "ELIMINATION" if fallen else "INTERVIEW", ("O adeus de " if fallen else ["Na oficina de ", "O treino de ", "À conversa com ", "A chegada de "][n % 4]) + focus, "As vitórias de %s ficam no arquivo, mesmo depois da eliminação." % focus if fallen else "%s mostra como se prepara longe do apito. Novos cenários, novas rotinas e a mesma vontade de conquistar a próxima passagem." % focus, focus, "ARENA_DEFEAT" if fallen else ["BACKSTAGE", "TRAINING", "POST_MATCH_INTERVIEW", "ARENA_ENTRANCE"][n % 4], record.get("winner", "") if fallen else record.get("loser", ""), record.get("score", ""))
	var brief = article(n, "wire", 10, "TOURNAMENT_NEWS", "O setor em números", "Consulta em RESULTADOS quem avançou e quem foi eliminado. Cada batalha tua faz avançar duas eliminatórias da chave paralela.", focus, "BACKSTAGE")
	for story in [lead, report, brief]:
		story["visual_variant"] = n + stage * 3
		story["sector"] = stage
		story["cast"] = {story.personagemPrincipal: preload("res://scripts/cup_tree_data.gd").portrait_spec(cup, story.personagemPrincipal), story.personagemSecundario: preload("res://scripts/cup_tree_data.gd").portrait_spec(cup, story.personagemSecundario)}
		story.corpo = story.subtitulo + "\n\n" + report_body(cup, story, n)
	return [lead, report, brief]

static func report_body(cup, story: Dictionary, n: int) -> String:
	var who: String = story.personagemPrincipal
	if n == 0 and who == "Aurel":
		return "Há quatro troféus no palmarés de Aurel e uma quinta conquista no centro de todas as perguntas. O tetracampeão chega com o peso de uma reputação que enche bancadas antes do primeiro disparo.\n\nA experiência faz dele uma referência, mas não lhe reserva um lugar na final. Cada participante terá de sobreviver à sua chave. Por agora, o penta é uma ambição; os resultados começam a escrever-se na arena."
	if n >= cup.FULL_MATCHES - 1 and who in ["Aurel", "Arconte Solar"]:
		var result = published(cup, "Aurel", n)
		return "O marcador fechou em %s. Aurel, apontado durante toda a competição como candidato ao quinto título, foi eliminado por Arconte Solar na outra semifinal.\n\nA surpresa tem agora lugar no boletim oficial. O favoritismo que ocupou as capas não bastou para atravessar a última porta: foi Arconte Solar quem conquistou a vaga em campo." % result.score
	if who == "Tu":
		return "Esta é a tua vitória número %d na Taça Aurora. O resultado fica no teu Percurso, junto dos adversários que superaste desde a primeira ronda.\n\n%s" % [n, "A competição terminou. O troféu e as skins da final estão conquistados; todo o caminho continua disponível no arquivo." if n == cup.FULL_MATCHES else "A próxima página depende do próximo combate. A Árvore reúne os resultados conhecidos e o Percurso identifica o teu encontro confirmado."]
	var fixture = published(cup, who, n)
	if fixture.is_empty():
		return "%s prepara a entrada em prova. A redação acompanha os treinos, os corredores e as bancadas, mas a classificação será decidida dentro da arena.\n\nOs primeiros resultados serão publicados depois do apito. Até lá, os prognósticos pertencem aos adeptos." % who
	return "Na jornada %d, %s venceu %s por %s. É este o resultado confirmado que sustenta a reportagem; o registo completo pode ser consultado na Árvore.\n\n%s" % [fixture.round, fixture.winner, fixture.loser, fixture.score, "Para quem sai, ficam os encontros disputados e o reconhecimento das bancadas. A competição prossegue com quem conquistou a passagem." if fixture.loser == who else "A vitória acrescenta um capítulo ao percurso do piloto. Os adeptos já discutem o que vem a seguir, mas o próximo lugar ainda terá de ser conquistado."]
