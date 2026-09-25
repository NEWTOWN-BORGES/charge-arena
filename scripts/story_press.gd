extends RefCounted
## The newsroom of AURORA EM CAMPO, the Taça's paper, and the voices around it.
##
## Every edition is written by hand for its place in the run - twelve covers, none alike -
## and only the facts are read from the draw: scores, who fell, who is still standing. A
## paper never prints what has not happened yet. Nothing here draws; the kiosk, the
## versus card and the hub all read from it.
##
## Two threads run under the results and only come together at the end:
## - Kael Brasa, the Planalto favourite, walks out "for personal reasons", is seen in the
##   Arconte Solar's box, and on the eve of the final says he was paid to leave the draw.
## - Aurora, who tests every rookie at the door, lost a final to the Arconte twelve years
##   ago that nobody could ever explain, and never competed again. Nova is her pupil.
const Taca = preload("res://scripts/tournament.gd")

# How loud an edition is, from a normal day to the one that goes on the wall.
const TIERS = ["regular", "headline", "cover", "special", "historic"]

# Photographs by what they show. Each maps to a staged scene built from the game's own
# models; a finished press image dropped at res://art/press/<key>.png takes its place, and
# nothing else ever does.
const PHOTO_SCENES = {
	"VICTORY": "ARENA_VICTORY", "DEFEAT": "ARENA_DEFEAT", "INTERVIEW": "POST_MATCH_INTERVIEW",
	"CELEBRATION": "CROWD_CELEBRATION", "RIVALRY": "FACE_OFF", "ARENA_EVENT": "UPSET",
	"BOSS_ENTRANCE": "ARENA_ENTRANCE", "TOURNAMENT": "PRESS_CONFERENCE", "CROWD": "CROWD_CELEBRATION",
	"FINAL": "FINAL_PROMO", "TRAINING": "TRAINING", "BACKSTAGE": "BACKSTAGE",
}

# Who they are in public: what the stands call them, what the paper says about them,
# and what they say when a camera is in front of them. Taken from each pilot's own
# description in the hangar, and kept to it.
const CAST = {
	"Aurora": {"epithet": "A PORTA DA TAÇA", "line": "Testa todos os estreantes desde a final que perdeu há doze anos.", "quote": "Mostra-me que sabes apontar. O resto vem depois."},
	"Faroleiro": {"epithet": "O VETERANO DO FAROL", "line": "Guarda a primeira porta da Taça há mais anos do que alguém se lembra.", "quote": "Ninguém atravessa a baía de olhos fechados."},
	"Mineiro": {"epithet": "O OPERÁRIO", "line": "Poucas palavras e muitas horas de arena. Nunca desiste de um tijolo.", "quote": "Capacete posto, cabeça baixa. Vamos a isso."},
	"Alquimista": {"epithet": "O IMPREVISÍVEL", "line": "Destila plasma das nebulosas. Nem ele sabe o que vai fazer a seguir.", "quote": "Ainda não sei o que vou fazer. É essa a graça."},
	"Relojoeiro": {"epithet": "O METÓDICO", "line": "Afina as engrenagens do circuito. Nunca chegou atrasado a uma partida.", "quote": "Noventa segundos. Estou a contar."},
	"Jardineiro": {"epithet": "O FAVORITO DO PÚBLICO", "line": "Cuida dos jardins orbitais. A bancada canta o nome dele antes de ele entrar.", "quote": "Que ganhe o melhor. De preferência, eu."},
	"Corsário": {"epithet": "O PROVOCADOR", "line": "Pirata das rotas estelares. Fala mais alto do que dispara - e dispara muito.", "quote": "Estreante? Vou-te devolver ao cais."},
	"Caça-Trovões": {"epithet": "O PRODÍGIO", "line": "Persegue tempestades de plasma. O piloto mais rápido do circuito.", "quote": "Pisca os olhos e perdes a jogada."},
	"Astrónomo": {"epithet": "O MISTERIOSO", "line": "Cartógrafo das órbitas. Dizem que lê a arena antes de ela acontecer.", "quote": "Já vi como isto acaba. Tu ainda não."},
	"Sentinela": {"epithet": "A MURALHA", "line": "Guarda de elite do circuito. Respeitada por todos, temida por quase todos.", "quote": "Ninguém passa o eclipse."},
	"Arconte Solar": {"epithet": "O SENHOR DO CIRCUITO", "line": "Chegou à final sem que ninguém lhe roubasse o sol. Ou quase ninguém.", "quote": "Toda a Taça está a olhar. Ótimo."},
	"Aurel": {"epithet": "O TETRACAMPEÃO", "line": "Quatro títulos, um nome nas capas. Veio buscar o penta.", "quote": "Cinco soa melhor do que quatro."},
	"Lira": {"epithet": "A PROMESSA DO FAROL", "line": "Dezanove anos, bancada cheia em cada jogo.", "quote": "Não vim para aprender. Vim para ganhar."},
	"Vértice": {"epithet": "A REVELAÇÃO", "line": "Ninguém o conhecia há um mês. Agora ninguém o esquece.", "quote": "Ângulo certo, tiro certo. Simples."},
	"Nina Vento": {"epithet": "A ZEBRA DO DELTA", "line": "Entrou na Taça pela porta das traseiras e não pára de ganhar.", "quote": "Ninguém apostou em mim. Melhor assim."},
	"Kael Brasa": {"epithet": "O FAVORITO DO PLANALTO", "line": "Chegou à Taça como um dos nomes a seguir.", "quote": "Vim para ganhar. Mais nada."},
	"Oto Fio": {"epithet": "A SEQUÊNCIA", "line": "Não perde desde a primeira ronda. Não fala com ninguém.", "quote": "..."},
	"Mara Lume": {"epithet": "A PREFERIDA DA BAÍA", "line": "Enche a bancada onde quer que jogue.", "quote": "Esta Taça é para a Baía."},
}

# The kiosk and the woman who runs it. Rosa has sold the paper at the Praça da Taça for
# longer than Aurel has been winning it; she knows more than she says, and says it once.
const KIOSK_NAME = "BANCA DA ROSA"
const KIOSK_LINES = [
	"Primeira vez na Taça? Leva o jornal. O teu nome ainda não vem cá dentro. Ainda.",
	"Passaste a porta da Aurora? Ela não deixa passar quase ninguém. Guarda isso.",
	"O Faroleiro foi para casa cedo... e na redação ainda ninguém sabe o teu nome.",
	"Olha só quem resolveu aparecer. Página um. Até eu fiquei surpreendida.",
	"Andam a perguntar por ti na redação. Eu não disse nada. Por agora.",
	"O Kael Brasa desistiu? Aquele rapaz nunca desistiu de nada na vida. Isto cheira-me mal.",
	"Vendi o dobro hoje. E vi o Kael a subir para o camarote do Arconte. Não digo mais nada.",
	"O Corsário passou aqui a resmungar. Não comprou jornal nenhum.",
	"A Aurora esteve aqui de manhã. Comprou três jornais. Todos com a tua cara.",
	"Agora já sabes que a redação sabe. Ela nunca me pediu segredo - mas eu guardei-o.",
	"A final. O Kael falou, a Aurora falou. Agora falas tu - em campo.",
	"Campeão. Esta capa vai para a parede da banca. Ao lado da Aurora - que é onde sempre devia ter estado.",
]
const KIOSK_AFTER_DEFEAT = [
	"Um tropeção não é notícia. Voltas lá e resolves.",
	"%s ainda está a sorrir. Não o deixes habituar-se.",
	"Ninguém na redação escreveu nada. Por mim, também não aconteceu.",
	"Os grandes também caíram antes de ganhar. Pergunta à Aurora.",
]

# --- editions --------------------------------------------------------------------------

static func editions_available(cup) -> int:
	# The opening edition is out before the admission; one more after it, and one after
	# every round won. A defeat never prints: the round is still there to be won.
	return 1 + (1 if cup.entrance_passed else 0) + cup.wins

static func has_new_edition(cup) -> bool:
	return cup.editions_read < editions_available(cup) - 1

static func kiosk_line(cup) -> String:
	var lost = cup.losses_here()
	if lost > 0 and not cup.champion():
		var line: String = KIOSK_AFTER_DEFEAT[mini(lost - 1, KIOSK_AFTER_DEFEAT.size() - 1)]
		return line % cup.opponent() if line.contains("%s") else line
	return KIOSK_LINES[clampi(editions_available(cup) - 1, 0, KIOSK_LINES.size() - 1)]

# Where each photograph was taken: in the arena, aboard ships, on the docks, in the press
# room, the plaza and the boxes. A photograph not listed here uses its scene's usual place.
const PHOTO_SETS = {
	"e01_capa": "PLAZA", "e01_favoritos": "DOCK", "e02_capa": "ARENA", "e02_kael": "PRESS_ROOM",
	"e03_capa": "ARENA", "e03_faroleiro": "CORRIDOR", "e04_capa": "ARENA", "e04_lira": "PLAZA",
	"e05_capa": "PRESS_ROOM", "e05_lira": "ARENA", "e06_capa": "ARENA", "e06_kael": "LOCKER",
	"e07_capa": "ARENA", "e07_corsario": "DOCK", "e07_camarote": "BOX", "e08_capa": "CORRIDOR",
	"e08_corsario": "DOCK", "e09_capa": "ARENA", "e09_aurora": "BOX", "e09_astronomo": "OBSERVATORY",
	"e10_capa": "HANGAR", "e10_nina": "ARENA", "e11_capa": "BRIDGE", "e11_aurel": "CORRIDOR", "e12_capa": "ARENA",
}

static func photo(category: String, subject: String, other: String = "", caption: String = "", key: String = "") -> Dictionary:
	return {"category": category, "scene": PHOTO_SCENES.get(category, "ARENA_ENTRANCE"), "set": PHOTO_SETS.get(key, ""), "subject": subject, "other": other, "caption": caption, "key": key, "asset": ("res://art/press/%s.png" % key) if key != "" else ""}

static func story(kicker: String, headline: String, body: String, picture: Dictionary = {}, twist: bool = false) -> Dictionary:
	return {"kicker": kicker, "headline": headline, "body": body, "photo": picture, "twist": twist}

static func played(cup, at_step: int) -> Dictionary:
	for h in cup.history:
		if int(h.step) == at_step: return h
	return {}

static func find(cup, kind: String, subject: String = "") -> Dictionary:
	for e in cup.events:
		if e.type == kind and (subject == "" or e.subject == subject): return e
	return {}

static func beaten_by(cup, who: String) -> String:
	# The pilot who knocked this one out, once it has happened.
	var slot = cup.slot_of(who)
	var r = cup.eliminated_in(slot)
	if r <= 0: return ""
	var other = cup.opponent_in(slot, r)
	return cup.entrant(other).name if other >= 0 else ""

static func player_name() -> String:
	return Taca.PLAYER

static func edition(cup, number: int) -> Dictionary:
	var n = clampi(number, 0, editions_available(cup) - 1)
	var e: Dictionary = {"number": n + 1, "day": n + 1, "tier": "regular", "round": "", "stories": [], "results": [], "ahead": {}, "kiosk": KIOSK_LINES[mini(n, KIOSK_LINES.size() - 1)]}
	# Edition n is printed after the player's n-th match: n = 1 after the admission,
	# n = 1 + r after round r.
	var r = n - 1
	var you: Dictionary = played(cup, r) if n >= 1 else {}
	var score: String = String(you.get("result", ""))
	var nova = player_name()
	match n:
		0:
			e.tier = "cover"
			e.round = "ABERTURA"
			e.headline = "1.024 PILOTOS. APENAS UM CAMPEÃO."
			e.dek = "A Taça Aurora abre hoje as portas na capital da arena. Aurel chega com quatro títulos e uma pergunta: há alguém capaz de lhe tirar o penta?"
			e.body = "São dez rondas de eliminação direta até à final na Coroa Solar. Quem perde vai para casa; quem ganha volta amanhã. Os estreantes jogam primeiro a admissão frente à Aurora - a porta que decide quem chega sequer a entrar na chave."
			e.photo = photo("CROWD", "Aurel", "", "A Praça da Taça, horas antes da abertura. A fila para ver Aurel dava a volta ao estádio.", "e01_capa")
			e.stories = [
				story("FAVORITOS", "OS NOMES QUE TODOS QUEREM VER", "Arconte Solar, a Sentinela e Aurel lideram as apostas. Nas bancas de apostas da Praça, ninguém paga menos de dez por um estreante.", photo("BOSS_ENTRANCE", "Arconte Solar", "", "O Arconte Solar à chegada. Não falou com ninguém.", "e01_favoritos")),
				story("MEMÓRIA", "HÁ DOZE ANOS, A ÚLTIMA FINAL DA AURORA", "A pilota que hoje testa os estreantes à porta perdeu a final de há doze anos para o Arconte Solar, com os aceleradores apagados a meio do jogo. A organização nunca explicou porquê. Ela nunca mais competiu.", {}),
				story("REGRAS", "COMO SE GANHA UMA TAÇA", "Eliminação direta. Dez rondas. 1.024 à partida, um no fim. A admissão abre a porta aos estreantes - quem a falha vê o resto pela televisão.", {}),
			]
		1:
			e.round = "1.ª ELIMINATÓRIA"
			e.headline = "A PRIMEIRA NOITE DA TAÇA"
			e.dek = "Metade dos pilotos que entram hoje em pista dormem em casa amanhã. A primeira eliminatória não perdoa ninguém."
			e.body = "A organização confirmou o quadro completo: 1.024 nomes, 512 encontros num só dia, arenas abertas desde o nascer do sol. Na Baía do Farol, o Faroleiro volta a guardar a primeira porta - a mesma que fechou a tantos estreantes nas edições anteriores."
			e.photo = photo("BOSS_ENTRANCE", "Faroleiro", "", "O Faroleiro a acender os faróis da baía na véspera da primeira eliminatória.", "e02_capa")
			e.stories = [
				story("ADMISSÕES", "A AURORA DEIXOU PASSAR UM", "Das dezenas de estreantes que se apresentaram à porta, poucos saíram de lá inteiros. Um deles, %s, venceu a Aurora por %s. No fim, a porteira da Taça disse apenas: \"Este é diferente.\"" % [nova, score], {}),
				story("ENTREVISTA", "KAEL BRASA: \"VIM PARA GANHAR\"", "O favorito do Planalto não quis falar de adversários. \"Vim para ganhar. Mais nada.\" Foi a frase mais longa que disse aos jornalistas.", photo("INTERVIEW", "Kael Brasa", "", "Kael Brasa na zona de imprensa, sem tirar o capacete.", "e02_kael")),
			]
		2:
			e.round = "2.ª ELIMINATÓRIA"
			e.headline = "METADE DA TAÇA JÁ FOI PARA CASA"
			e.dek = "512 pilotos continuam em prova depois de um dia inteiro de eliminatórias. Os favoritos passaram - quase todos."
			e.body = "Aurel precisou de menos de dois minutos para despachar a estreia. A Sentinela nem suou. A Lira ganhou com a bancada da Baía aos gritos. E na Baía do Farol, a primeira surpresa da Taça passou quase despercebida."
			e.photo = photo("VICTORY", "Aurel", "", "Aurel ergue o punho depois de uma estreia de noventa segundos.", "e03_capa")
			e.stories = [
				story("BAÍA DO FAROL", "O FAROL APAGOU-SE CEDO", "O Faroleiro, que guarda a primeira porta da Taça há anos, caiu à primeira: %s frente a um estreante chamado %s. Na redação, ninguém tinha a ficha deste piloto." % [score, nova], photo("DEFEAT", "Faroleiro", "", "O Faroleiro abandona a Baía pelo túnel dos pilotos.", "e03_faroleiro")),
				story("BANCADA", "MARA LUME ENCHE A BAÍA", "Os bilhetes para os jogos da preferida da Baía esgotaram em vinte minutos.", {}),
			]
		3:
			e.tier = "headline"
			e.round = "3.ª ELIMINATÓRIA"
			e.headline = "DESCONHECIDO SURPREENDE NA TAÇA"
			e.dek = "Primeiro o Faroleiro, agora o Mineiro. O estreante %s venceu por %s na Mina Profunda e já soma duas vítimas de peso." % [nova, score]
			e.body = "Ninguém o viu treinar. Ninguém sabe de onde vem. Na Mina Profunda, o Mineiro fez o jogo de sempre - cabeça baixa, tijolo a tijolo - e mesmo assim saiu derrotado. \"Não o conhecia\", disse no fim. \"Agora conheço.\""
			e.photo = photo("VICTORY", nova, "Mineiro", "%s depois do último golo na Mina Profunda. O Mineiro ainda de joelhos." % nova, "e04_capa")
			e.stories = [
				story("FAROL", "LIRA SEGUE E JÁ É A FAVORITA DO PÚBLICO", "A promessa do Farol venceu outra vez. Na próxima ronda pode cruzar-se com um nome que anda a fazer barulho: Vértice, o parceiro de treino dela há três épocas.", photo("CROWD", "Lira", "", "Adeptos da Lira à porta do estádio do Farol.", "e04_lira")),
				story("QUADRO", "256 EM PROVA", "A chave fecha-se a cada dia. Das 512 partidas de ontem, só três acabaram em prolongamento.", {}),
			]
		4:
			e.tier = "headline"
			e.round = "4.ª ELIMINATÓRIA"
			e.headline = "QUEM É ESTE PILOTO?"
			e.dek = "Três vitórias, três nomes grandes. Depois do Alquimista (%s), a Taça inteira quer saber quem é %s." % [score, nova]
			e.body = "O Alquimista entrou no Laboratório de Cristal a prometer o imprevisível. Saiu a falar sozinho. A redação procurou o nome nos arquivos de todas as ligas regionais do circuito: nenhum registo, nenhum clube, nenhuma partida oficial antes desta Taça."
			e.photo = photo("INTERVIEW", nova, "", "%s na primeira conferência de imprensa. Respondeu a duas perguntas." % nova, "e05_capa")
			var lira = beaten_by(cup, "Lira")
			e.stories = [
				story("FAROL", "O PARCEIRO DE TREINO ELIMINA A PROMESSA", "Três épocas a treinar lado a lado, e foi %s quem mandou a Lira para casa (%s). \"Ela ensinou-me este ângulo\", disse. Ela não quis falar." % [lira, String(find(cup, "FAVORITE_ELIMINATED", "Lira").get("score", "2–1"))], photo("ARENA_EVENT", lira, "Lira", "O momento em que a Lira percebe que acabou.", "e05_lira"), true),
				story("CRISTAL", "ALQUIMISTA: \"FOI UMA EXPERIÊNCIA\"", "O derrotado recusou-se a lamentar. \"Aprendi mais nesta derrota do que em dez vitórias.\" Depois partiu um frasco contra a parede.", {}),
			]
		5:
			e.tier = "headline"
			e.round = "5.ª ELIMINATÓRIA"
			e.headline = "JÁ NÃO É SORTE"
			e.dek = "Quatro rondas, quatro vitórias. O Relojoeiro, que nunca se atrasou para uma partida, ficou sem tempo frente a %s (%s)." % [nova, score]
			e.body = "Nas primeiras rondas havia quem falasse de sorte - um desconhecido a apanhar veteranos num mau dia. Na Oficina do Relógio, o Relojoeiro não teve um mau dia. Jogou o jogo perfeito dele, cronometrado ao segundo. E perdeu."
			e.photo = photo("VICTORY", nova, "Relojoeiro", "A última engrenagem da Oficina do Relógio parou com o golo decisivo.", "e06_capa")
			var kael = find(cup, "WITHDRAWAL", "Kael Brasa")
			e.stories = [
				story("PLANALTO", "KAEL BRASA ABANDONA A TAÇA", "O favorito do Planalto não se apresentou na quarta eliminatória. A organização fala em \"razões pessoais\"; %s passa sem jogar. A equipa dele não atende o telefone." % String(kael.get("other", "o adversário")), photo("BACKSTAGE", "Kael Brasa", "", "O cacifo de Kael Brasa, vazio, na manhã da quarta eliminatória.", "e06_kael"), true),
				story("RELÓGIO", "RELOJOEIRO: \"ELE NÃO ESTAVA NO MEU CALENDÁRIO\"", "O metódico do circuito admitiu que não tinha estudado o adversário. \"Não achei que fosse preciso. Enganei-me.\"", {}),
			]
		6:
			e.tier = "headline"
			e.round = "16 AVOS DE FINAL"
			e.headline = "A ASCENSÃO CONTINUA"
			e.dek = "Nem a bancada do Jardineiro o travou: %s ganhou por %s na Estufa Suspensa e está nos 16 avos de final." % [nova, score]
			e.body = "A Estufa cantava o nome do Jardineiro antes de ele entrar - como sempre. Acabou em silêncio. O favorito do público saiu a aplaudir o vencedor, e a bancada, pela primeira vez, aplaudiu com ele."
			e.photo = photo("CELEBRATION", nova, "Jardineiro", "A bancada da Estufa Suspensa, de pé, depois do último golo.", "e07_capa")
			var mara = find(cup, "RIVAL_ELIMINATED", "Mara Lume")
			e.stories = [
				story("RECIFE", "CORSÁRIO ATROPELA MARA LUME", "A preferida da Baía durou pouco frente ao Corsário (%s). O pirata espera agora %s - e já disse que vai \"devolver o estreante ao cais\"." % [String(mara.get("score", "2–0")), nova], photo("BOSS_ENTRANCE", "Corsário", "", "O Corsário à saída da arena, a acenar à bancada que o vaiava.", "e07_corsario")),
				story("CAMAROTES", "KAEL BRASA VISTO NO CAMAROTE DO ARCONTE", "O piloto que abandonou a Taça por \"razões pessoais\" passou a tarde de ontem no camarote privado do Arconte Solar. Nenhum dos dois quis comentar.", photo("BACKSTAGE", "Kael Brasa", "", "Kael Brasa no camarote privado do Arconte Solar, fotografado da bancada de imprensa.", "e07_camarote"), true),
			]
		7:
			e.tier = "cover"
			e.round = "OITAVOS DE FINAL"
			e.headline = "NINGUÉM CONSEGUE PARÁ-LO?"
			e.dek = "O Corsário prometeu devolvê-lo ao cais. %s ganhou por %s no Recife dos Corsários e está nos oitavos de final." % [nova, score]
			e.body = "Foi o jogo mais provocado da Taça até agora: vaias, gestos, um tricórnio atirado à bancada. No fim, o Corsário recusou o aperto de mão e saiu pelo túnel sem falar. %s não disse nada - foi a vitória a falar." % nova
			e.photo = photo("RIVALRY", nova, "Corsário", "%s e o Corsário frente a frente antes do apito inicial." % nova, "e08_capa")
			e.stories = [
				story("RECIFE", "O CORSÁRIO NÃO ACEITA: \"QUERO A DESFORRA\"", "Já no cais, o pirata exigiu uma nova partida. A organização lembrou-lhe que a Taça é de eliminação direta.", photo("DEFEAT", "Corsário", "", "O Corsário a caminho do cais, de tricórnio na mão.", "e08_corsario")),
				story("ANEL NORTE", "OTO FIO NÃO PERDE", "Seis rondas, seis vitórias, nenhuma palavra aos jornalistas. O piloto do Anel Norte caminha em silêncio para os oitavos.", {}),
			]
		8:
			e.tier = "cover"
			e.round = "QUARTOS DE FINAL"
			e.headline = "TAÇA AURORA EM CHOQUE"
			e.dek = "O Caça-Trovões, o piloto mais rápido do circuito, caiu frente a %s (%s). E na bancada, pela primeira vez em doze anos, estava a Aurora." % [nova, score]
			e.body = "Ninguém vence o Caça-Trovões em velocidade - e %s não tentou. Esperou, leu a tempestade e fechou-a de uma vez. Na Torre da Tempestade, os pára-raios ainda zumbiam quando o placar parou. Na fila três, a Aurora levantou-se, aplaudiu uma vez e saiu antes de alguém lhe fazer perguntas." % nova
			e.photo = photo("ARENA_EVENT", nova, "Caça-Trovões", "A Torre da Tempestade depois do encontro mais intenso da Taça. Três painéis ficaram por reparar.", "e09_capa")
			e.stories = [
				story("BANCADA", "A AURORA VOLTOU", "Doze anos depois da final que perdeu, a porteira da Taça voltou a sentar-se numa bancada. Só veio a um jogo. Adivinhem qual.", photo("CROWD", "Aurora", "", "A Aurora na fila três da Torre da Tempestade.", "e09_aurora"), true),
				story("ÓRBITA", "O ASTRÓNOMO TRAVA A REVELAÇÃO", "Vértice, que tinha eliminado a Lira, encontrou alguém que já tinha visto o jogo antes de ele acontecer. O Astrónomo espera agora por %s nos quartos." % nova, photo("TRAINING", "Astrónomo", "", "O Astrónomo no Observatório Lunar, na véspera dos quartos.", "e09_astronomo")),
			]
		9:
			e.tier = "cover"
			e.round = "MEIAS-FINAIS"
			e.headline = "O SEGREDO DE %s" % nova.to_upper()
			e.dek = "Venceu o Astrónomo (%s) e está nas meias-finais. E agora sabe-se quem o treinou: a Aurora." % score
			e.body = "Durante três anos, num pavilhão fechado na Baía, a Aurora treinou um único aluno. Nunca o inscreveu numa liga, nunca o levou a um jogo - até esta Taça. \"Não o treinei para ganhar a Taça\", disse ontem à noite, na primeira entrevista em doze anos. \"Treinei-o para chegar à final. O resto é com ele.\""
			e.photo = photo("INTERVIEW", "Aurora", nova, "A Aurora, na primeira entrevista em doze anos. %s esperava à porta." % nova, "e10_capa")
			var nina = find(cup, "UPSET_ENDS", "Nina Vento")
			e.stories = [
				story("PLANALTO", "O QUE ACONTECEU A KAEL BRASA?", "A redação falou com três membros da equipa do Planalto. Os três dizem o mesmo: na véspera de desistir, Kael recebeu uma visita. Nenhum quis dizer de quem.", {}, true),
				story("DELTA", "O CONTO DE FADAS DA NINA VENTO ACABA NOS PÉS DE AUREL", "A zebra do Delta chegou aos quartos. Aurel mandou-a para casa (%s) e ainda lhe pediu o capacete autografado." % String(nina.get("score", "2–1")), photo("ARENA_EVENT", "Aurel", "Nina Vento", "Aurel e Nina Vento, no fim de um jogo que ninguém esperava ver.", "e10_nina")),
				story("BASTIÃO", "A SENTINELA TRAVA OTO FIO", "A sequência do Anel Norte acabou no eclipse. A Sentinela espera %s nas meias-finais." % nova, {}),
			]
		10:
			e.tier = "special"
			e.round = "FINAL"
			e.headline = "\"O ARCONTE PAGOU-ME PARA SAIR\""
			e.dek = "Kael Brasa quebra o silêncio na véspera da final. E a Aurora diz o que calou durante doze anos."
			e.body = "\"Ofereceu-me um lugar na equipa dele se eu saísse da chave\", contou Kael Brasa à redação. \"Eu era o único do lado dele que o podia travar.\" Horas depois, a Aurora falou pela primeira vez da final de há doze anos: \"Os meus aceleradores não se apagaram sozinhos. Nunca o consegui provar.\" %s passou o eclipse da Sentinela (%s). Do outro lado, o Arconte Solar acabou com o sonho do penta de Aurel. Amanhã, na Coroa Solar, a final é mais do que uma final." % [nova, score]
			e.photo = photo("FINAL", nova, "Arconte Solar", "%s e o Arconte Solar na apresentação oficial da final. Não se cumprimentaram." % nova, "e11_capa")
			var aurel = find(cup, "FAVORITE_ELIMINATED", "Aurel")
			e.stories = [
				story("COROA", "DOIS PILOTOS. UMA ARENA. UM CAMPEÃO.", "O Arconte Solar eliminou Aurel por %s e fechou o caminho do penta. O tetracampeão saiu sem falar - pela primeira vez em cinco edições. Ao Arconte, a organização não pediu explicações. Ainda." % String(aurel.get("score", "2–1")), photo("DEFEAT", "Aurel", "", "Aurel a deixar a Coroa Solar pela porta lateral.", "e11_aurel")),
			]
		_:
			e.tier = "historic"
			e.round = "EDIÇÃO HISTÓRICA"
			e.headline = "CAMPEÃO."
			e.dek = "O piloto que ninguém conhecia venceu o Arconte Solar (%s) e levantou a Taça Aurora. Doze anos depois, a final da Aurora teve outro fim." % score
			e.body = "Há dez rondas, %s era um nome numa lista de admissões. Hoje é o nome gravado na Taça. Do Faroleiro ao Arconte Solar, dez vitórias frente a dez dos pilotos mais temidos do circuito - e nenhuma delas por sorte. Quando o último golo entrou, a Aurora já estava de pé na fila três. Não aplaudiu uma vez: não parou de aplaudir." % nova
			e.photo = photo("CELEBRATION", nova, "", "%s com a Taça Aurora, na Coroa Solar, debaixo de uma chuva de papel dourado." % nova, "e12_capa")
			e.stories = [
				story("ORGANIZAÇÃO", "INQUÉRITO AO ARCONTE SOLAR", "Depois das declarações de Kael Brasa e da Aurora, a organização abriu um inquérito ao Arconte Solar. Kael foi o primeiro a descer ao relvado para abraçar o campeão.", {}, true),
			]
	# The player's own result and the round's notable ones, straight from the draw.
	if n >= 1 and not you.is_empty():
		e.results.append({"left": nova.to_upper(), "score": score, "right": String(you.opponent).to_upper(), "yours": true})
	if n >= 2:
		for event in cup.events:
			if int(event.get("round", -1)) == r and event.type in ["FAVORITE_ELIMINATED", "RIVAL_ELIMINATED", "UPSET_ENDS", "BOSS_ADVANCED", "UPSET", "RIVAL_ADVANCED", "FAVORITE_ADVANCED"] and event.has("score"):
				var pair = [String(event.subject), String(event.other)] if event.type in ["BOSS_ADVANCED", "UPSET", "RIVAL_ADVANCED", "FAVORITE_ADVANCED"] else [String(event.other), String(event.subject)]
				e.results.append({"left": pair[0].to_upper(), "score": String(event.score), "right": pair[1].to_upper(), "yours": false})
		e.results = e.results.slice(0, 5)
	# What is ahead. The next opponent is news once the draw has decided it.
	if not cup.champion() and n == editions_available(cup) - 1 and cup.entrance_passed:
		var next = cup.confirmed_match()
		e.ahead = {"round": String(next.round_name).to_upper(), "name": String(next.name), "field": int(next.field)}
	return e

# --- before a match ------------------------------------------------------------------

static func versus(cup) -> Dictionary:
	# The card shown before walking into the arena: the round, the two names, and one
	# line about the rival - never what it will do in the match. Some matches open with
	# a few seconds of what is being said around them; they can always be skipped.
	var m: Dictionary = cup.confirmed_match()
	if m.is_empty(): return {}
	var who: String = String(m.name)
	var info: Dictionary = CAST.get(who, {"epithet": "", "line": "", "quote": ""})
	var streak = 0 if m.entrance else int(m.step) - 1
	var record = String(info.line)
	if streak >= 2:
		record = "Venceu as últimas %d partidas na Taça." % streak
	var moment: Array = []
	match int(m.step):
		0: moment = [["ROSA, DA BANCA", "Entras naquela porta e já não és só mais um na bancada. Boa sorte, miúdo."], ["A AURORA", info.quote]]
		1: moment = [["O FAROLEIRO", info.quote], ["A BANCADA", "Metade da Baía nem sabe quem és. A outra metade está a torcer pelo Faroleiro."]]
		5: moment = [["ROSA, DA BANCA", "Soubeste do Kael Brasa? Desistiu. Aquele rapaz nunca desistiu de nada."]]
		6: moment = [["O CORSÁRIO", "Estreante? Vou-te devolver ao cais."], ["ROSA, DA BANCA", "Não lhe ligues. Ladra mais do que dispara."]]
		9: moment = [["A SENTINELA", info.quote], ["A AURORA", "Ela fecha o centro. Não lutes contra a muralha - dá-lhe a volta."]]
		10: moment = [["O ARCONTE SOLAR", info.quote], ["KAEL BRASA", "Ele tirou-me a Taça antes de eu a jogar. Não o deixes fazer o mesmo contigo."], ["A AURORA", "Doze anos à espera disto. Não é por mim. É por ti."]]
		_: moment = [[who.to_upper(), String(info.quote)]]
	return {"round": String(m.round_name).to_upper(), "name": who, "epithet": info.epithet, "line": record, "moment": moment,
		"final": m.is_final, "arena": String(cup.level().name), "field": int(m.field), "entrance": m.entrance}
