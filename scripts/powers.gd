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
		"about": "Três segundos de feixe contínuo que atravessa tudo menos as paredes e tira 2 de vida a cada tijolo."},
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
		"about": "Três ondas de choque caem do céu e varrem a arena: tudo o que apanham perde o rumo e é arrastado em câmara lenta até ao Sentinela. Quando está tudo compactado, o núcleo abre-se e devolve dezenas de projéteis num leque que ocupa a arena quase toda, à velocidade de bola turbinada, 2 de dano e sem ricochete."},
	{"id": "sentries", "short": "SENTINELAS", "name": "SENTINELAS", "kind": "ultimate", "charge": ULTIMATE_CHARGE, "price": 0, "color": "8fd3c7",
		"about": "Duas mini-guns automáticas ficam de pé no meio do ringue. Disparam sozinhas, devagar, 2 de dano e sem ricochete, atacam a muralha do rival e metem golo se a baliza já estiver aberta. São frágeis — 2 vidas cada — e estão expostas: duas bolas em jogo bastam para abater uma."},
	{"id": "bloom", "short": "FLORIR", "name": "FLORESCER", "kind": "ultimate", "charge": ULTIMATE_CHARGE, "price": 0, "color": "9fe37a",
		"about": "Cura 2 de vida em cada tijolo teu; os que já estão inteiros ganham mais 2 e crescem."},
	{"id": "plunder", "short": "PILHAGEM", "name": "PILHAGEM", "kind": "ultimate", "charge": ULTIMATE_CHARGE, "price": 0, "color": "ff5c8a",
		"about": "Troca a tua muralha com a do rival, tijolo a tijolo e em espelho: o que ele tinha passa a ser teu."},
]
# The kit every pilot starts with, and how many bought powers it holds. The third slot is
# always the skin's ultimate, so it is neither bought nor equipped.
const STARTER_KIT = ["blast", "air"]
const KIT_SIZE = 2
# Testing build: every power is already bought, with a full wallet, so the whole kit can
# be tried out. Set to false to sell them one by one again; purchases are saved either way.
const UNLOCK_ALL_FOR_TESTS = true
const TEST_WALLET = 5000
# Testing build: the ultimate starts a match already charged, so it can be tried out
# without farming twenty bricks first.
const START_WITH_ULTIMATE_FOR_TESTS = true
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
	config.set_value("powers", "bricks", bricks)
	config.set_value("powers", "owned", owned)
	config.set_value("powers", "kit", kit)
	return config.save(config_path)
