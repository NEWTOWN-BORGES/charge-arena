extends RefCounted
## Power shop and kit. A pilot takes three powers into a match: two bought here and
## equipped in the kit, plus the ultimate that comes with the skin. Tijolos destroyed in
## any mode are the currency. Progress stays on this device.
const CONFIG_PATH = "user://powers.cfg"
# charge: enemy bricks to destroy in the match before it can be fired the first time.
# wait: seconds before it can be fired again, once it has been.
# price: tijolos accumulated across matches to buy it in the shop.
const CATALOG = [
	{"id": "blast", "short": "EXPLOSÃO", "name": "EXPLOSÃO", "kind": "ataque", "charge": 4, "wait": 7, "price": 0, "color": "ffb36b",
		"about": "Uma bala que rebenta ao acertar: 2 de dano a tudo o que for inimigo à volta."},
	{"id": "rapid", "short": "METRALHA", "name": "METRALHADORA", "kind": "ataque", "charge": 6, "wait": 13, "price": 120, "color": "ffe978",
		"about": "Uma rajada de 10 balas seguidas, umas atrás das outras, sem tirar o dedo do botão."},
	{"id": "air", "short": "LEQUE", "name": "RAJADA DE AR", "kind": "ataque", "charge": 7, "wait": 10, "price": 0, "color": "90e6ff",
		"about": "Cinco balas de uma vez num leque à frente do piloto, cada uma com 2 de dano."},
	{"id": "ghost", "short": "FANTASMA", "name": "BALAS FANTASMA", "kind": "ataque", "charge": 3, "wait": 11, "price": 150, "color": "c8a8ff",
		"about": "Oito segundos com as balas a atravessar pilares, barreiras e obstáculos. As paredes continuam a reflectir."},
	{"id": "laser", "short": "LASER", "name": "RAIO LASER", "kind": "ataque", "charge": 11, "wait": 19, "price": 420, "color": "ff6b7a",
		"about": "Uma lança contínua durante 3 segundos, que morde a cada meio segundo e **dobra uma vez na parede**: com o ângulo certo apanha a muralha de frente e ainda leva o resto do feixe para outro lado. Atravessa bumpers e barreiras, e enquanto está acesa a pistola cala-se."},
	{"id": "rebuild", "short": "REPOR", "name": "RECONSTRUÇÃO", "kind": "defesa", "charge": 9, "wait": 21, "price": 320, "color": "9fe37a",
		"about": "Sete tijolos teus voltam inteiros ao campo, os mais próximos da baliza primeiro, cada um dentro de um anel de luz."},
	{"id": "mirror", "short": "ESPELHO", "name": "CAPA ESPELHO", "kind": "defesa", "charge": 7, "wait": 15, "price": 360, "color": "7fe6ff",
		"about": "4,5 segundos de capa nos teus tijolos: a bala inimiga volta como bala de boost — mais rápida, 2 de dano e sem ricochete."},
	{"id": "walls", "short": "MURALHA", "name": "MURALHAS", "kind": "defesa", "charge": 6, "wait": 17, "price": 180, "color": "dbdf9a",
		"about": "Muralhas sobem à frente de cada banco de tijolos teus durante 6,5 segundos e voltam à terra. Deixam frestas: o rival ainda acerta, mas tem de apontar."},
	{"id": "stun", "short": "CHOQUE", "name": "PULSO DE CHOQUE", "kind": "defesa", "charge": 9, "wait": 18, "price": 280, "color": "b9e6ff",
		"about": "Uma onda limpa todas as balas do campo e deixa o rival — e os obstáculos móveis — atordoados 4,5 segundos."},
	{"id": "weld", "short": "SOLDA", "name": "SOLDA RÁPIDA", "kind": "vida", "charge": 5, "wait": 15, "price": 200, "color": "8fe0a8",
		"about": "Uma vida de volta em cada tijolo teu que já levou pancada. Não levanta os que caíram — para isso é a Reconstrução — mas é barata e rápida, e uma muralha inteira a meia vida fica outra vez inteira."},
	{"id": "thorns", "short": "ESPINHOS", "name": "ESPINHOS", "kind": "defesa", "charge": 9, "wait": 19, "price": 240, "color": "e8a0ff",
		"about": "Oito segundos de espinhos na tua muralha: cada bala do rival que parta um tijolo teu tira uma vida ao piloto que a disparou. Quanto mais ele insistir, mais caro lhe fica."},
	{"id": "freeze", "short": "GELO", "name": "GELO", "kind": "debuff", "charge": 8, "wait": 17, "price": 300, "color": "a8dcff",
		"about": "Cinco segundos de gelo no rival: anda a menos de metade da velocidade, demora o dobro do tempo entre tiros e não pode usar nenhuma abilidade nem a ultimate enquanto durar. Não o atordoa — deixa-o lento e desarmado, que é pior para quem precisa de apontar."},
	{"id": "magnet", "short": "ÍMAN", "name": "ÍMAN", "kind": "buff", "charge": 8, "wait": 15, "price": 340, "color": "ffd06b",
		"about": "Sete segundos com as tuas balas a curvar na direcção do tijolo inimigo mais próximo da rota delas. Salva o tiro que ia passar de raspão; não dispara por ti, uma bala apontada ao lado errado continua errada."},
	{"id": "pierce", "short": "PERFURA", "name": "PERFURANTE", "kind": "ataque", "charge": 10, "wait": 17, "price": 400, "color": "ff8f6b",
		"about": "Seis segundos com as balas a atravessar o tijolo que partem e a seguir caminho. Contra uma muralha de quatro fileiras, um tiro certeiro abre um corredor em vez de uma mossa."},
]
# One ultimate per skin (see Skins.CATALOG["ultimate"]). They are never bought: the skin
# brings its own, in the third slot, and all of them spend two seconds charging up first.
# Thirteen and not twenty: a whole match now destroys thirty to forty-five bricks, and at
# twenty the ultimate was arriving once, near the end, or not at all.
const ULTIMATE_CHARGE = 13
# Every ultimate waits the same long half minute between outings.
const ULTIMATE_WAIT = 34
const ULTIMATES = [
	{"id": "sun_ray", "short": "SOL", "name": "COROA SOLAR", "kind": "ultimate", "charge": ULTIMATE_CHARGE, "wait": ULTIMATE_WAIT, "price": 0, "color": "ffe45c",
		"about": "Um raio de sol grosso que atravessa a arena e segue para lá dela: 2 de dano em tudo o que apanha, largo o bastante para quatro tijolos em fila."},
	{"id": "meteors", "short": "METEOROS", "name": "CHUVA DE METEOROS", "kind": "ultimate", "charge": ULTIMATE_CHARGE, "wait": ULTIMATE_WAIT, "price": 0, "color": "cbb2ff",
		"about": "Um segundo de meteoros roxos e amarelos a cair sobre metade do campo do rival, 1 de dano cada."},
	{"id": "thunder", "short": "TROVOADA", "name": "TROVOADA", "kind": "ultimate", "charge": ULTIMATE_CHARGE, "wait": ULTIMATE_WAIT, "price": 0, "color": "7fe6ff",
		"about": "Dois segundos de raios a cair ao acaso no campo do rival, 2 de dano cada."},
	{"id": "singularity", "short": "VÓRTICE", "name": "SINGULARIDADE", "kind": "ultimate", "charge": ULTIMATE_CHARGE, "wait": ULTIMATE_WAIT, "price": 0, "color": "f3a13c",
		"about": "Três ondas de choque caem do céu e varrem a arena: tudo o que apanham perde o rumo e é arrastado em câmara lenta até ao Sentinela. Quando está tudo compactado, o núcleo larga uma só onda enorme, que corre o mapa todo e sai para lá dele: 3 de dano na primeira fila da muralha do rival, 2 na de trás e 1 nas seguintes."},
	{"id": "sentries", "short": "SENTINELAS", "name": "SENTINELAS", "kind": "ultimate", "charge": ULTIMATE_CHARGE, "wait": ULTIMATE_WAIT, "price": 0, "color": "8fd3c7",
		"about": "Duas mini-guns automáticas ficam de pé no meio do ringue. Disparam sozinhas, devagar, 2 de dano e sem ricochete, atacam a muralha do rival e metem golo se a baliza já estiver aberta. São frágeis — 2 vidas cada — e estão expostas: duas bolas em jogo bastam para abater uma."},
	{"id": "bloom", "short": "FLORIR", "name": "FLORESCER", "kind": "ultimate", "charge": ULTIMATE_CHARGE, "wait": ULTIMATE_WAIT, "price": 0, "color": "9fe37a",
		"about": "Cura 2 de vida em cada tijolo teu; os que já estão inteiros ganham mais 2 e crescem."},
	{"id": "plunder", "short": "PILHAGEM", "name": "PILHAGEM", "kind": "ultimate", "charge": ULTIMATE_CHARGE, "wait": ULTIMATE_WAIT, "price": 0, "color": "ff5c8a",
		"about": "As duas muralhas cruzam-se no ar, tijolo a tijolo e cada um a sua velocidade, e assentam em espelho do lado contrario. Quando pousam, o que ele tinha passa a ser teu."},
	{"id": "surge", "short": "SOBRECARGA", "name": "SOBRECARGA", "kind": "ultimate", "charge": ULTIMATE_CHARGE, "wait": ULTIMATE_WAIT, "price": 0, "color": "7fe6c8",
		"about": "Seis segundos com a manopla em sobrecarga: cada tiro teu sai turbinado, com 2 de dano, e a cadencia duplica."},
	{"id": "volley", "short": "RAJADA", "name": "RAJADA DO FAROL", "kind": "ultimate", "charge": ULTIMATE_CHARGE, "wait": ULTIMATE_WAIT, "price": 0, "color": "ffc978",
		"about": "O mesmo leque da abilidade, mas cinco vezes seguidas: cinco ondas de cinco balas, 2 de dano cada. Entre uma onda e a seguinte da para andar na calha, por isso as cinco podem cobrir a muralha toda."},
	{"id": "plating", "short": "COURACA", "name": "COURACA DE CRISTAL", "kind": "ultimate", "charge": ULTIMATE_CHARGE, "wait": ULTIMATE_WAIT, "price": 0, "color": "8fd8ff",
		"about": "Sete segundos com a tua muralha blindada a cristal: cada pancada que lhe acerta perde uma vida pelo caminho. O tiro normal deixa de lhe fazer nada, o turbinado tira 1 em vez de 2 e uma ultimate de 3 tira 2."},
]
# The pilots between the bosses are nobody in particular: no skin of their own, no name to
# remember. What they bring is one of these - a plain ultimate, built out of what the shop
# already does, tuned down. They are meant to be recognised on sight after the second time,
# not studied.
const BASIC_ULTIMATES = [
	{"id": "b_salvo", "short": "SALVA", "name": "SALVA", "kind": "ultimate", "charge": ULTIMATE_CHARGE, "wait": ULTIMATE_WAIT, "price": 0, "color": "ffc978",
		"about": "Tres leques seguidos, a metade da rajada do Faroleiro."},
	{"id": "b_hail", "short": "GRANIZO", "name": "GRANIZO", "kind": "ultimate", "charge": ULTIMATE_CHARGE, "wait": ULTIMATE_WAIT, "price": 0, "color": "cbb2ff",
		"about": "Cinco pedras pequenas sobre a muralha do rival, uma vida cada."},
	{"id": "b_spark", "short": "FAISCA", "name": "FAISCA", "kind": "ultimate", "charge": ULTIMATE_CHARGE, "wait": ULTIMATE_WAIT, "price": 0, "color": "7fe6ff",
		"about": "Tres descargas curtas, duas vidas cada, sem a tempestade a volta."},
	{"id": "b_patch", "short": "REMENDO", "name": "REMENDO", "kind": "ultimate", "charge": ULTIMATE_CHARGE, "wait": ULTIMATE_WAIT, "price": 0, "color": "8fe0a8",
		"about": "Uma vida de volta em cada tijolo seu que ja levou pancada."},
	{"id": "b_bar", "short": "BARREIRA", "name": "BARREIRA", "kind": "ultimate", "charge": ULTIMATE_CHARGE, "wait": ULTIMATE_WAIT, "price": 0, "color": "dbdf9a",
		"about": "Muralhas a frente dos bancos dele durante nove segundos."},
	{"id": "b_push", "short": "EMPURRAO", "name": "EMPURRAO", "kind": "ultimate", "charge": ULTIMATE_CHARGE, "wait": ULTIMATE_WAIT, "price": 0, "color": "b9e6ff",
		"about": "Uma onda limpa o campo de balas e atordoa quem estiver do outro lado."},
	{"id": "b_slow", "short": "LASTRO", "name": "LASTRO", "kind": "ultimate", "charge": ULTIMATE_CHARGE, "wait": ULTIMATE_WAIT, "price": 0, "color": "a8dcff",
		"about": "Quatro segundos a arrastar-te: mais lento, mais devagar a disparar e sem kit."},
	{"id": "b_forge", "short": "FORJA", "name": "FORJA", "kind": "ultimate", "charge": ULTIMATE_CHARGE, "wait": ULTIMATE_WAIT, "price": 0, "color": "7fe6c8",
		"about": "Quatro segundos com os tiros dele turbinados e ao dobro da cadencia."},
	{"id": "b_aim", "short": "MIRA", "name": "MIRA", "kind": "ultimate", "charge": ULTIMATE_CHARGE, "wait": ULTIMATE_WAIT, "price": 0, "color": "ffd06b",
		"about": "Seis segundos com as balas dele a curvar para o teu tijolo mais proximo."},
	{"id": "b_drill", "short": "FURA", "name": "FURA", "kind": "ultimate", "charge": ULTIMATE_CHARGE, "wait": ULTIMATE_WAIT, "price": 0, "color": "ff8f6b",
		"about": "Cinco segundos com as balas dele a atravessar o tijolo que partem."},
]

# The kit every pilot starts with, and how many bought powers it holds. The third slot is
# always the skin's ultimate, so it is neither bought nor equipped.
# Saves written by the old unlocked test builds have everything open and a full wallet.
# The demo refuses to read them: a stored file without this stamp is left behind and the
# run starts from nothing, which is the whole point of a progression build.
const SAVE_VERSION = 2
const STARTER_KIT = ["blast", "air"]
const KIT_SIZE = 2
# Testing build: every power is already bought, with a full wallet, so the whole kit can
# be tried out. Set to false to sell them one by one again; purchases are saved either way.
const UNLOCK_ALL_FOR_TESTS = false
const TEST_WALLET = 5000
# Testing build: the ultimate starts a match already charged, so it can be tried out
# without farming twenty bricks first.
const START_WITH_ULTIMATE_FOR_TESTS = false
var config_path = CONFIG_PATH
var unlock_all = UNLOCK_ALL_FOR_TESTS
var bricks = TEST_WALLET if UNLOCK_ALL_FOR_TESTS else 0
var owned: Array = all_ids() if UNLOCK_ALL_FOR_TESTS else STARTER_KIT.duplicate()
var kit: Array = STARTER_KIT.duplicate()

static func all_ids() -> Array:
	return CATALOG.map(func(entry): return String(entry.id))

static func index_of(id: String) -> int:
	for index in range(CATALOG.size()):
		if CATALOG[index].id == id:
			return index
	return -1

static func wait_of(id: String) -> float:
	# How long this power sits out after being fired.
	var found: Dictionary = entry(id)
	return float(found.get("wait", 0)) if not found.is_empty() else 0.0

static func entry(id: String) -> Dictionary:
	# Bought powers first, then the skin ultimates, which share the same shape.
	var index = index_of(id)
	if index >= 0:
		return CATALOG[index]
	for ultimate in ULTIMATES:
		if ultimate.id == id:
			return ultimate
	for basic in BASIC_ULTIMATES:
		if basic.id == id:
			return basic
	return {}

static func is_ultimate(id: String) -> bool:
	return ULTIMATES.any(func(entry_data): return entry_data.id == id)

func affordable() -> Array:
	# Powers the wallet already pays for and the pilot does not own: what the menu points at.
	return CATALOG.filter(func(entry): return int(entry.price) > 0 and not is_owned(String(entry.id)) and bricks >= int(entry.price))

func is_owned(id: String) -> bool:
	return owned.has(id) or (unlock_all and index_of(id) >= 0)

func can_buy(id: String) -> bool:
	var found: Dictionary = entry(id)
	return not found.is_empty() and not is_owned(id) and bricks >= int(found.price)

func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	bricks -= int(entry(id).price)
	owned.append(id)
	return true

func equip(slot: int, id: String) -> bool:
	# A power sits in one slot at a time; equipping it where it already is swaps the two.
	if slot < 0 or slot >= KIT_SIZE or not is_owned(id):
		return false
	var current = kit.find(id)
	if current == slot:
		return false
	if current >= 0:
		kit[current] = kit[slot]
	kit[slot] = id
	return true

func add_bricks(count: int) -> void:
	bricks += maxi(count, 0)

func loadout(ultimate: String) -> Array:
	# The three powers taken into a match, in button order.
	return [kit[0], kit[1], ultimate]

func load_preferences() -> void:
	var config = ConfigFile.new()
	if config.load(config_path) != OK:
		return
	if int(config.get_value("powers", "version", 1)) < SAVE_VERSION:
		return
	bricks = maxi(int(config.get_value("powers", "bricks", 0)), 0)
	owned = all_ids() if unlock_all else STARTER_KIT.duplicate()
	if unlock_all:
		bricks = maxi(bricks, TEST_WALLET)
	for id in Array(config.get_value("powers", "owned", [])):
		if id is String and index_of(id) >= 0 and not owned.has(id):
			owned.append(id)
	var saved = Array(config.get_value("powers", "kit", []))
	for slot in range(KIT_SIZE):
		var id = saved[slot] if slot < saved.size() else ""
		kit[slot] = id if id is String and is_owned(id) and not kit.slice(0, slot).has(id) else STARTER_KIT[slot]

func save_preferences() -> Error:
	var config = ConfigFile.new()
	config.set_value("powers", "version", SAVE_VERSION)
	config.set_value("powers", "bricks", bricks)
	config.set_value("powers", "owned", owned)
	config.set_value("powers", "kit", kit)
	return config.save(config_path)
