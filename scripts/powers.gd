extends RefCounted
## Power shop and kit. A pilot takes three powers into a match: two bought here and
## equipped in the kit, plus the ultimate that comes with the skin. Tijolos destroyed in
## any mode are the currency. Progress stays on this device.
const CONFIG_PATH = "user://powers.cfg"
# charge: enemy bricks to destroy in the match before it can be fired.
# price: tijolos accumulated across matches to buy it in the shop.
const CATALOG = [
	{"id": "blast", "short": "EXPLOSÃO", "name": "EXPLOSÃO", "kind": "ataque", "charge": 5, "price": 0, "color": "ffb36b",
		"about": "Uma bala que rebenta ao acertar: 2 de dano a tudo o que for inimigo à volta."},
	{"id": "rapid", "short": "METRALHA", "name": "METRALHADORA", "kind": "ataque", "charge": 10, "price": 200, "color": "ffe978",
		"about": "Uma rajada de 10 balas seguidas, umas atrás das outras, sem tirar o dedo do botão."},
	{"id": "air", "short": "LEQUE", "name": "RAJADA DE AR", "kind": "ataque", "charge": 12, "price": 0, "color": "90e6ff",
		"about": "Cinco balas de uma vez num leque à frente do piloto, cada uma com 2 de dano."},
	{"id": "ghost", "short": "FANTASMA", "name": "BALAS FANTASMA", "kind": "ataque", "charge": 4, "price": 250, "color": "c8a8ff",
		"about": "Oito segundos com as balas a atravessar pilares, barreiras e obstáculos. As paredes continuam a reflectir."},
	{"id": "laser", "short": "LASER", "name": "RAIO LASER", "kind": "ataque", "charge": 18, "price": 800, "color": "ff6b7a",
		"about": "Uma lança contínua durante 3 segundos, que morde a cada meio segundo e **dobra uma vez na parede**: com o ângulo certo apanha a muralha de frente e ainda leva o resto do feixe para outro lado. Atravessa bumpers e barreiras, e enquanto está acesa a pistola cala-se."},
	{"id": "rebuild", "short": "REPOR", "name": "RECONSTRUÇÃO", "kind": "defesa", "charge": 15, "price": 600, "color": "9fe37a",
		"about": "Sete tijolos teus voltam inteiros ao campo, os mais próximos da baliza primeiro, cada um dentro de um anel de luz."},
	{"id": "mirror", "short": "ESPELHO", "name": "CAPA ESPELHO", "kind": "defesa", "charge": 12, "price": 700, "color": "7fe6ff",
		"about": "4,5 segundos de capa nos teus tijolos: a bala inimiga volta como bala de boost — mais rápida, 2 de dano e sem ricochete."},
	{"id": "walls", "short": "MURALHA", "name": "MURALHAS", "kind": "defesa", "charge": 10, "price": 300, "color": "dbdf9a",
		"about": "Muralhas sobem à frente de cada banco de tijolos teus durante 6,5 segundos e voltam à terra. Deixam frestas: o rival ainda acerta, mas tem de apontar."},
	{"id": "stun", "short": "CHOQUE", "name": "PULSO DE CHOQUE", "kind": "defesa", "charge": 15, "price": 500, "color": "b9e6ff",
		"about": "Uma onda limpa todas as balas do campo e deixa o rival — e os obstáculos móveis — atordoados 4,5 segundos."},
]
# One ultimate per skin (see Skins.CATALOG["ultimate"]). They are never bought: the skin
# brings its own, in the third slot, and all of them spend two seconds charging up first.
const ULTIMATE_CHARGE = 20
const ULTIMATES = [
	{"id": "sun_ray", "short": "SOL", "name": "COROA SOLAR", "kind": "ultimate", "charge": ULTIMATE_CHARGE, "price": 0, "color": "ffe45c",
		"about": "Um raio de sol grosso que atravessa a arena e segue para lá dela: 2 de dano em tudo o que apanha, largo o bastante para quatro tijolos em fila."},
	{"id": "meteors", "short": "METEOROS", "name": "CHUVA DE METEOROS", "kind": "ultimate", "charge": ULTIMATE_CHARGE, "price": 0, "color": "cbb2ff",
		"about": "Um segundo de meteoros roxos e amarelos a cair sobre metade do campo do rival, 1 de dano cada."},
	{"id": "thunder", "short": "TROVOADA", "name": "TROVOADA", "kind": "ultimate", "charge": ULTIMATE_CHARGE, "price": 0, "color": "7fe6ff",
		"about": "Dois segundos de raios a cair ao acaso no campo do rival, 2 de dano cada."},
	{"id": "singularity", "short": "VÓRTICE", "name": "SINGULARIDADE", "kind": "ultimate", "charge": ULTIMATE_CHARGE, "price": 0, "color": "f3a13c",
		"about": "Três ondas de choque caem do céu e varrem a arena: tudo o que apanham perde o rumo e é arrastado em câmara lenta até ao Sentinela. Quando está tudo compactado, o núcleo larga uma só onda enorme, que corre o mapa todo e sai para lá dele: 3 de dano na primeira fila da muralha do rival, 2 na de trás e 1 nas seguintes."},
	{"id": "sentries", "short": "SENTINELAS", "name": "SENTINELAS", "kind": "ultimate", "charge": ULTIMATE_CHARGE, "price": 0, "color": "8fd3c7",
		"about": "Duas mini-guns automáticas ficam de pé no meio do ringue. Disparam sozinhas, devagar, 2 de dano e sem ricochete, atacam a muralha do rival e metem golo se a baliza já estiver aberta. São frágeis — 2 vidas cada — e estão expostas: duas bolas em jogo bastam para abater uma."},
	{"id": "bloom", "short": "FLORIR", "name": "FLORESCER", "kind": "ultimate", "charge": ULTIMATE_CHARGE, "price": 0, "color": "9fe37a",
		"about": "Cura 2 de vida em cada tijolo teu; os que já estão inteiros ganham mais 2 e crescem."},
	{"id": "plunder", "short": "PILHAGEM", "name": "PILHAGEM", "kind": "ultimate", "charge": ULTIMATE_CHARGE, "price": 0, "color": "ff5c8a",
		"about": "As duas muralhas cruzam-se no ar, tijolo a tijolo e cada um a sua velocidade, e assentam em espelho do lado contrario. Quando pousam, o que ele tinha passa a ser teu."},
	{"id": "surge", "short": "SOBRECARGA", "name": "SOBRECARGA", "kind": "ultimate", "charge": ULTIMATE_CHARGE, "price": 0, "color": "7fe6c8",
		"about": "Seis segundos com a manopla em sobrecarga: cada tiro teu sai turbinado, com 2 de dano, e a cadencia duplica."},
	{"id": "volley", "short": "RAJADA", "name": "RAJADA DO FAROL", "kind": "ultimate", "charge": ULTIMATE_CHARGE, "price": 0, "color": "ffc978",
		"about": "O mesmo leque da abilidade, mas cinco vezes seguidas: cinco ondas de cinco balas, 2 de dano cada. Entre uma onda e a seguinte da para andar na calha, por isso as cinco podem cobrir a muralha toda."},
	{"id": "plating", "short": "COURACA", "name": "COURACA DE CRISTAL", "kind": "ultimate", "charge": ULTIMATE_CHARGE, "price": 0, "color": "8fd8ff",
		"about": "Sete segundos com a tua muralha blindada a cristal: cada pancada que lhe acerta perde uma vida pelo caminho. O tiro normal deixa de lhe fazer nada, o turbinado tira 1 em vez de 2 e uma ultimate de 3 tira 2."},
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

static func entry(id: String) -> Dictionary:
	# Bought powers first, then the skin ultimates, which share the same shape.
	var index = index_of(id)
	if index >= 0:
		return CATALOG[index]
	for ultimate in ULTIMATES:
		if ultimate.id == id:
			return ultimate
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
