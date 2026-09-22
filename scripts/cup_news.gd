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
	var lead = article(n, "cover", 100, "TOURNAMENT_NEWS", "O PENTA ESTÁ NA MIRA", "Quatro títulos. Aurel abre a Taça rodeado de câmaras e de adeptos que já sonham com outra final. Em campo, todos começam do zero.", "Aurel", "PRESS_CONFERENCE")
	if n > 0:
		var result: Dictionary = cup.history[n - 1]
		lead = article(n, "cover", 100, "PLAYER_NEWS", "MAIS UM PASSO TEU", "Venceste %s. A caminhada continua: cada ronda deixa um rival para trás." % result.opponent, "Tu", "POST_MATCH_INTERVIEW", result.opponent, "%s–%s" % result.score)
		if n % 11 == 0:
			lead.titulo = "UM SETOR CONQUISTADO"
			lead.subtitulo = "%s reconhece a tua vitória. A sua skin é tua; uma nova etapa da Taça começa." % result.opponent
			lead.cenario = "CROWD_CELEBRATION"
		elif n % 11 == 10:
			var rival = published(cup, cup.BOSS_NAMES[cup.boss_order[cup.stage_index(n)]], n)
			lead = article(n, "cover", 100, "BOSS_REVEAL", "UM ENCONTRO CONQUISTADO", "%s venceu %s e ganhou o direito de cruzar o teu caminho. O confronto está confirmado." % [rival.winner, rival.loser], rival.winner, "FACE_OFF", "Tu", rival.score)
		elif n % 4 == 0 or n == 2:
			var champion = published(cup, "Aurel", n)
			lead = article(n, "cover", 100, "STREAK", "QUEM PÁRA AUREL?", "O tetracampeão voltou a vencer. Nas bancadas fala-se no penta; Aurel diz que só pensa na próxima partida.", "Aurel", "PRESS_CONFERENCE", champion.get("loser", ""), champion.get("score", ""))
		if n == 4:
			lead = article(n, "cover", 100, "INTERVIEW", "«AINDA SÓ COMECEI»", "Lira ganha espaço nas capas. Quatro vitórias fizeram dela a promessa do Farol; os adeptos já pedem uma final.", "Lira", "POST_MATCH_INTERVIEW")
		if n == 7:
			var upset = published(cup, "Lira", n)
			lead = article(n, "cover", 100, "UPSET", "A FAVORITA CAIU", "Vértice elimina Lira. A final que tantos antecipavam acaba de mudar de rosto.", "Vértice", "UPSET", "Lira", upset.score)
		if n == 109:
			var upset = published(cup, "Aurel", n)
			lead = article(n, "cover", 100, "UPSET", "O PENTA CAIU", "Arconte Solar derrotou Aurel na semifinal. O tetracampeão despede-se entre o silêncio das bancadas. A outra vaga na grande final está decidida.", "Arconte Solar", "UPSET", "Aurel", upset.score)
		if n == 110:
			lead.titulo = "A TAÇA É TUA"
			lead.subtitulo = "Venceste o Arconte Solar e conquistaste a Taça Aurora. Ganhas a skin do rival e a armadura de Aurel como prémio da competição."
			lead.tipo = "FINAL"
		lead.corpo = lead.subtitulo
	var focus = "Faroleiro" if n < 11 else "Sentinela"
	var record = published(cup, focus, n)
	var fallen = not record.is_empty() and record.loser == focus
	var report = article(n, "report", 60, "ELIMINATION" if fallen else "INTERVIEW", "Respeito depois do apito" if fallen else "O trabalho longe das capas", "%s deixou a competição, mas as suas vitórias ficam na história." % focus if fallen else "%s prepara o próximo desafio. Entre treinos e entrevistas, cada lugar tem de ser conquistado em campo." % focus, focus, "ARENA_DEFEAT" if fallen else "TRAINING", record.get("winner", "") if fallen else record.get("loser", ""), record.get("score", ""))
	var latest = published(cup, "Aurel", n)
	var brief = article(n, "wire", 10, "TOURNAMENT_NEWS", "A Taça tem mais de uma história", "Os resultados publicados estão na Árvore. Os adversários futuros dependem de quem continuar em prova.", "Sentinela", "ARENA_ENTRANCE")
	if not latest.is_empty():
		brief = article(n, "wire", 10, "ELIMINATION" if latest.loser == "Aurel" else "VICTORY", "Aurel despede-se da Taça" if latest.loser == "Aurel" else "O tetracampeão volta a vencer", "%s · %s · %s. Resultado oficial da jornada %d." % [latest.winner, latest.score, latest.loser, latest.round], "Aurel", "ARENA_DEFEAT" if latest.loser == "Aurel" else "ARENA_VICTORY", latest.winner if latest.loser == "Aurel" else latest.loser, latest.score)
	for story in [lead, report, brief]:
		story.corpo = report_body(cup, story, n)
	return [lead, report, brief]

static func report_body(cup, story: Dictionary, n: int) -> String:
	var who: String = story.personagemPrincipal
	if n == 0 and who == "Aurel":
		return "Há quatro troféus no palmarés de Aurel e uma quinta conquista no centro de todas as perguntas. O tetracampeão chega com o peso de uma reputação que enche bancadas antes do primeiro disparo.\n\nA experiência faz dele uma referência, mas não lhe reserva um lugar na final. Cada participante terá de sobreviver à sua chave. Por agora, o penta é uma ambição; os resultados começam a escrever-se na arena."
	if n >= 109 and who in ["Aurel", "Arconte Solar"]:
		var result = published(cup, "Aurel", n)
		return "O marcador fechou em %s. Aurel, apontado durante toda a competição como candidato ao quinto título, foi eliminado por Arconte Solar na outra semifinal.\n\nA surpresa tem agora lugar no boletim oficial. O favoritismo que ocupou as capas não bastou para atravessar a última porta: foi Arconte Solar quem conquistou a vaga em campo." % result.score
	if who == "Tu":
		return "Esta é a tua vitória número %d na Taça Aurora. O resultado fica no teu Percurso, junto dos adversários que superaste desde a primeira ronda.\n\n%s" % [n, "A competição terminou. O troféu e as skins da final estão conquistados; todo o caminho continua disponível no arquivo." if n == cup.FULL_MATCHES else "A próxima página depende do próximo combate. A Árvore reúne os resultados conhecidos e o Percurso identifica o teu encontro confirmado."]
	var fixture = published(cup, who, n)
	if fixture.is_empty():
		return "%s prepara a entrada em prova. A redação acompanha os treinos, os corredores e as bancadas, mas a classificação será decidida dentro da arena.\n\nOs primeiros resultados serão publicados depois do apito. Até lá, os prognósticos pertencem aos adeptos." % who
	return "Na jornada %d, %s venceu %s por %s. É este o resultado confirmado que sustenta a reportagem; o registo completo pode ser consultado na Árvore.\n\n%s" % [fixture.round, fixture.winner, fixture.loser, fixture.score, "Para quem sai, ficam os encontros disputados e o reconhecimento das bancadas. A competição prossegue com quem conquistou a passagem." if fixture.loser == who else "A vitória acrescenta um capítulo ao percurso do piloto. Os adeptos já discutem o que vem a seguir, mas o próximo lugar ainda terá de ser conquistado."]
