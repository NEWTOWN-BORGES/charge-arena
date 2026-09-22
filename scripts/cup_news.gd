extends RefCounted
## Editorial records are deterministic projections of the saved competition.
const TYPES = ["VICTORY", "UPSET", "INTERVIEW", "RIVALRY", "ELIMINATION", "STREAK", "BOSS_REVEAL", "PLAYER_NEWS", "FINAL", "TOURNAMENT_NEWS"]
const SCENES = ["ARENA_VICTORY", "ARENA_DEFEAT", "POST_MATCH_INTERVIEW", "PRESS_CONFERENCE", "BACKSTAGE", "ARENA_ENTRANCE", "FACE_OFF", "TRAINING", "CROWD_CELEBRATION", "UPSET", "FINAL_PROMO"]
const COVERS = [
["O QUARTO ESTÁ NA MIRA", "Aurel", "PRESS_CONFERENCE", "O tricampeão abre a Taça rodeado de câmaras. Do outro lado das portas, mil percursos começam.", "TOURNAMENT_NEWS"],
["AS PORTAS ESTÃO ABERTAS", "Tu", "ARENA_ENTRANCE", "Primeira vitória nas qualificatórias. O ruído das bancadas já acompanha os novos pilotos.", "PLAYER_NEWS"],
["O HOMEM A ABATER", "Aurel", "ARENA_VICTORY", "Mais um 2–0 no setor central. A imprensa volta a apontar o tricampeão ao título.", "VICTORY"],
["O FAROL NÃO VACILA", "Faroleiro", "ARENA_VICTORY", "Três eliminatórias, três vitórias. O guardião do setor constrói o seu próprio caminho.", "STREAK"],
["«AINDA SÓ COMECEI»", "Lira", "POST_MATCH_INTERVIEW", "A promessa do Farol responde à imprensa depois de voltar a vencer. A confiança cresce nas bancadas.", "INTERVIEW"],
["A PRESSÃO SOBE", "Astrónomo", "TRAINING", "Noutro setor, o Astrónomo regressa ao treino depois de vencer. Ninguém chega à próxima fase por convite.", "STREAK"],
["JÁ SABEM O TEU NOME", "Tu", "POST_MATCH_INTERVIEW", "Seis vitórias depois, há microfones à saída da arena. O estreante começa a conquistar espaço.", "PLAYER_NEWS"],
["A FAVORITA CAIU", "Vértice", "UPSET", "Vértice elimina Lira. A final que tantos antecipavam acaba de mudar de rosto.", "UPSET"],
["QUEM PÁRA AUREL?", "Aurel", "PRESS_CONFERENCE", "O tricampeão continua invicto. O quarto título domina as perguntas; ele prefere falar da próxima partida.", "STREAK"],
["ANTES DA ÚLTIMA PORTA", "Tu", "BACKSTAGE", "Nove vitórias. Um momento de silêncio no túnel, antes da qualificatória decisiva.", "PLAYER_NEWS"],
["O FAROLEIRO CHEGOU", "Faroleiro", "FACE_OFF", "Dez eliminatórias vencidas. Depois de superar Vértice, o vencedor da chave cruza finalmente o teu caminho.", "BOSS_REVEAL"],
["O FAROL É TEU", "Tu", "CROWD_CELEBRATION", "O protagonista vence a final do setor. Entre flashes e aplausos, Faroleiro reconhece o novo vencedor.", "FINAL"]
]
static func article(round_id: int, key: String, priority: int, kind: String, headline: String, sub: String, subject: String, scene: String, other: String = "", score: String = "") -> Dictionary:
	return {"id": "%02d_%s" % [round_id, key], "jornada": round_id, "prioridade": priority, "tipo": kind, "titulo": headline, "subtitulo": sub, "personagemPrincipal": subject, "personagemSecundario": other, "resultado": score, "evento": kind, "cenario": scene, "estado": "publicado", "imagem": scene, "ordem": round_id * 10 + priority, "etapa": "Abertura da Taça" if round_id == 0 else ("Final do setor do Farol" if round_id == 11 else "Qualificatórias · jornada %02d" % round_id), "corpo": sub}
static func edition(cup, number: int) -> Array:
	var n = clampi(number, 0, cup.wins)
	var c: Array = COVERS[n]
	var rival = "Lira" if n == 7 else ("Tu" if n == 10 else ("Faroleiro" if n == 11 else ""))
	var score = ""
	if n > 0 and c[1] == "Tu":
		score = "%s–%s" % cup.history[n - 1].score
		if rival.is_empty(): rival = cup.history[n - 1].opponent
	if n in [3, 7, 10]:
		for fixture in cup.rounds[n - 1].fixtures:
			if fixture.winner.to_upper() == str(c[1]).to_upper():
				score = fixture.score
				if rival.is_empty(): rival = fixture.loser
	if n == 2: score = "2–0"
	var stories: Array = [article(n, "cover", 100, c[4], c[0], c[3], c[1], c[2], rival, score)]
	var subject = "Lira" if n < 7 else "Vértice"
	var secondary = "Uma promessa entre os favoritos" if n < 7 else "O preço de chegar mais longe"
	var description = "Lira avança na chave do Farol. À saída do treino, os adeptos já pedem uma final à altura da promessa." if n < 7 else "A chave não perdoa: cada nome que avança deixa outro para trás. Consulta os resultados oficiais desta edição."
	if n == 0:
		subject = "Faroleiro"; secondary = "O guardião também tem de vencer"; description = "Faroleiro entra numa chave com 1 024 participantes. Só um deles terá lugar na final do setor."
	if n == 4:
		subject = "Faroleiro"; secondary = "Quatro passos rumo à final"; description = "Enquanto Lira conquista os microfones, Faroleiro soma mais uma vitória na sua metade da chave."
	if n == 11:
		subject = "Faroleiro"; secondary = "Respeito depois do apito"; description = "Derrotado na final, Faroleiro deixa a arena entre aplausos. Dez vitórias na chave não desaparecem com uma derrota."
	stories.append(article(n, "report", 60, "ELIMINATION" if n == 11 else "INTERVIEW", secondary, description, subject, "ARENA_DEFEAT" if n == 11 else "BACKSTAGE"))
	if n in [2, 4, 5, 6, 9, 11]:
		stories.append(article(n, "nadir", 10, "STREAK", "Nadir volta a vencer sem sofrer", "Setor exterior · 2–0. O piloto evita os microfones e regressa ao corredor de treino. Um percurso que ainda recebe poucas linhas.", "Nadir", "TRAINING", "", "2–0"))
	else:
		stories.append(article(n, "wire", 10, "TOURNAMENT_NEWS", "A competição continua nos outros setores", "Mineiro, Astrónomo e Sentinela disputam o seu lugar. Os resultados do Farol estão no boletim oficial abaixo.", "Mineiro", "ARENA_ENTRANCE"))
	return stories
