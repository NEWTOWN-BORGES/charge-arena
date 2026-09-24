extends RefCounted
## PvE campaign: eleven arenas, each with its own challenge and boss. The first is a
## training bout against a copy of the standard pilot; the other ten each carry a skin. Winning a level
## unlocks the next one. Progress stays on this device.
const Rules = preload("res://scripts/arena_rules.gd")
const CONFIG_PATH = "user://campaign.cfg"
# A single match victory unlocks the next arena. Progress is saved on device.
# TESTING BUILD: every level, skin and power is open from the start, so the whole game can
# be walked through without playing up to it. The three switches move together - a build is
# open or closed, never half - and there is a test that says so. Set all three back to
# false to ship a build that has to be earned.
const UNLOCK_ALL_FOR_TESTS = true
# Saves written by the old unlocked test builds have everything open and a full wallet.
# The demo refuses to read them: a stored file without this stamp is left behind and the
# run starts from nothing, which is the whole point of a progression build.
const SAVE_VERSION = 2

# boss: skin worn by the rival (and its bricks), a different one per level; beating it
# unlocks that skin. tier: 0 (gentle) to 9 (relentless).
# The hardest tier any level carries. The whole difficulty curve is read against this.
const TOP_TIER = 9
const LEVELS = [
	{"name": "Circuito Aurora", "tag": "Treino", "boss": 0, "tier": 0,
		"challenge": "A arena de origem, sem obstáculos: aprende o arco, o ricochete e os aceleradores.",
		"map": {"tall": true, "lean": true, "id": "treino", "outline": "stadium", "boosters": true, "bricks": "banks", "lives": 3, "barriers": [], "obstacles": []}},
	{"name": "Baía do Farol", "tag": "Faróis giratórios", "boss": 1, "tier": 1,
		"challenge": "Dois faróis giram encostados às paredes e devolvem os tiros largos.",
		"map": {"tall": true, "lean": true, "id": "farol", "outline": "octagon", "boosters": true, "bricks": "wall", "lives": 3, "barriers": [],
			"obstacles": [
				{"kind": "orbit", "center": Vector2(0, 0), "travel": 2.6, "frequency": 0.5, "phase": 0.0, "radius": 0.46},
				{"kind": "orbit", "center": Vector2(0, 0), "travel": 2.6, "frequency": 0.5, "phase": PI, "radius": 0.46},
				{"kind": "fixed", "center": Vector2(-6.9, -4.6), "radius": 0.44},
				{"kind": "fixed", "center": Vector2(6.9, -4.6), "radius": 0.44},
				{"kind": "fixed", "center": Vector2(-6.9, 4.6), "radius": 0.44},
				{"kind": "fixed", "center": Vector2(6.9, 4.6), "radius": 0.44}]}},
	{"name": "Mina Profunda", "tag": "Vagonetas", "boss": 4, "tier": 2,
		"challenge": "As vagonetas sobem e descem coladas às paredes do coliseu, longe da linha de tiro.",
		"map": {"tall": true, "lean": true, "id": "mina", "outline": "colosseum", "boosters": true, "bricks": "chevron", "lives": 3, "barriers": [],
			"obstacles": [
				{"kind": "slide", "center": Vector2(0, -1.7), "axis": Vector2(1, 0), "travel": 5.0, "frequency": 0.65, "phase": 0.0, "radius": 0.44},
				{"kind": "slide", "center": Vector2(0, 1.7), "axis": Vector2(1, 0), "travel": 5.0, "frequency": 0.65, "phase": PI, "radius": 0.44}]}},
	{"name": "Laboratório de Cristal", "tag": "Quatro cristais", "boss": 8, "tier": 3,
		"challenge": "Quatro cristais orbitam junto às paredes: muito ricochete, nenhum corredor fechado.",
		"map": {"tall": true, "lean": true, "id": "laboratorio", "outline": "gorge", "boosters": true, "bricks": "islands", "lives": 3, "barriers": [],
			"obstacles": [
				{"kind": "orbit", "center": Vector2(0, 0), "travel": 2.2, "frequency": 0.5, "phase": 0.0, "radius": 0.4},
				{"kind": "slide", "center": Vector2(0, 0), "axis": Vector2(1, 0), "travel": 4.0, "frequency": 0.4, "phase": PI / 2, "radius": 0.4}]}},
	{"name": "Oficina do Relógio", "tag": "Deslizadores", "boss": 6, "tier": 4,
		"challenge": "Duas engrenagens sobem e descem junto às paredes. A rota do meio fica toda tua.",
		"map": {"tall": true, "lean": true, "id": "oficina", "outline": "stadium", "boosters": true, "bricks": "arc", "lives": 3, "barriers": [],
			"obstacles": [
				{"kind": "slide", "center": Vector2(0, -2.3), "axis": Vector2(1, 0), "travel": 4.4, "frequency": 0.6, "phase": 0.0, "radius": 0.44},
				{"kind": "slide", "center": Vector2(0, 2.3), "axis": Vector2(1, 0), "travel": 4.4, "frequency": 0.6, "phase": PI, "radius": 0.44}]}},
	{"name": "Estufa Suspensa", "tag": "Cintura estreita", "boss": 3, "tier": 5,
		"challenge": "A arena aperta a meio, mas o fundo é largo: corre até ao canto para abrir ângulo.",
		"map": {"tall": true, "lean": true, "id": "estufa", "outline": "gorge", "boosters": true, "bricks": "bulwark", "lives": 3, "barriers": [],
			"obstacles": [
				{"kind": "slide", "center": Vector2(0, -1.9), "axis": Vector2(1, 0), "travel": 3.6, "frequency": 0.55, "phase": 0.0, "radius": 0.42},
				{"kind": "slide", "center": Vector2(0, 1.9), "axis": Vector2(1, 0), "travel": 3.6, "frequency": 0.55, "phase": PI, "radius": 0.42}]}},
	{"name": "Recife dos Corsários", "tag": "Coliseu", "boss": 9, "tier": 6,
		"challenge": "O estádio retangular: cantos chanfrados, barris lentos junto às paredes e nada no meio.",
		"map": {"tall": true, "lean": true, "id": "recife", "outline": "colosseum", "boosters": true, "bricks": "banks", "lives": 4, "barriers": [],
			"obstacles": [
				{"kind": "orbit", "center": Vector2(0, 0), "travel": 2.2, "frequency": 0.48, "phase": 0.0, "radius": 0.42},
				{"kind": "orbit", "center": Vector2(0, 0), "travel": 2.2, "frequency": 0.48, "phase": PI, "radius": 0.42}]}},
	{"name": "Torre da Tempestade", "tag": "Pára-raios", "boss": 7, "tier": 7,
		"challenge": "Dois pára-raios varrem as bojudas laterais. Nada fechado, tudo para ricochetear.",
		"map": {"tall": true, "lean": true, "id": "tempestade", "outline": "lens", "boosters": true, "bricks": "bulwark", "lives": 4, "barriers": [],
			"obstacles": [
				{"kind": "slide", "center": Vector2(0, -2.0), "axis": Vector2(1, 0), "travel": 4.8, "frequency": 0.72, "phase": 0.0, "radius": 0.43},
				{"kind": "slide", "center": Vector2(0, 2.0), "axis": Vector2(1, 0), "travel": 4.8, "frequency": 0.72, "phase": PI, "radius": 0.43}]}},
	{"name": "Observatório Lunar", "tag": "Duas luas", "boss": 2, "tier": 8,
		"challenge": "Duas luas lentas correm pelas bojudas laterais; sem aceleradores, o ricochete é todo teu.",
		"map": {"tall": true, "lean": true, "id": "observatorio", "outline": "lens", "boosters": false, "bricks": "fortress", "lives": 3, "barriers": [],
			"obstacles": [
				{"kind": "orbit", "center": Vector2(0, 0), "travel": 2.4, "frequency": 0.36, "phase": 0.0, "radius": 0.43},
				{"kind": "orbit", "center": Vector2(0, 0), "travel": 2.4, "frequency": 0.36, "phase": PI, "radius": 0.43}]}},
	{"name": "Posto Sentinela I", "tag": "Piloto de posto", "boss": 100, "tier": 8, "minor": true, "music": 1, "hue": "ff8f5c", "ultimate": "b_salvo", "kit": ["blast", "air"],
		"challenge": "Um piloto de posto, sem nome e sem skin: traz a sentinela e o que comprou.",
		"map": {"tall": true, "lean": true, "id": "posto_01", "outline": "octagon", "boosters": true, "bricks": "wall", "lives": 3, "barriers": [],
			"obstacles": [
				{"kind": "slide", "center": Vector2(0, -1.9), "axis": Vector2(1, 0), "travel": 3.6, "frequency": 0.6, "phase": 0.0, "radius": 0.42},
				{"kind": "slide", "center": Vector2(0, 1.9), "axis": Vector2(1, 0), "travel": 3.6, "frequency": 0.6, "phase": PI, "radius": 0.42}]}},
	{"name": "Posto Sentinela II", "tag": "Piloto de posto", "boss": 101, "tier": 8, "minor": true, "music": 2, "hue": "ffd06b", "ultimate": "b_hail", "kit": ["rapid", "walls"],
		"challenge": "Um piloto de posto, sem nome e sem skin: traz a sentinela e o que comprou.",
		"map": {"tall": true, "lean": true, "id": "posto_02", "outline": "stadium", "boosters": true, "bricks": "arc", "lives": 3, "barriers": [],
			"obstacles": [
				{"kind": "slide", "center": Vector2(0, -2.4), "axis": Vector2(1, 0), "travel": 2.8, "frequency": 0.6, "phase": 0.0, "radius": 0.42},
				{"kind": "slide", "center": Vector2(0, 2.4), "axis": Vector2(1, 0), "travel": 2.8, "frequency": 0.6, "phase": PI, "radius": 0.42}]}},
	{"name": "Posto Sentinela III", "tag": "Piloto de posto", "boss": 102, "tier": 8, "minor": true, "music": 3, "hue": "a8e06b", "ultimate": "b_spark", "kit": ["blast", "weld"],
		"challenge": "Um piloto de posto, sem nome e sem skin: traz a sentinela e o que comprou.",
		"map": {"tall": true, "lean": true, "id": "posto_03", "outline": "colosseum", "boosters": true, "bricks": "chevron", "lives": 3, "barriers": [],
			"obstacles": [
				{"kind": "slide", "center": Vector2(0, -1.9), "axis": Vector2(1, 0), "travel": 3.6, "frequency": 0.6, "phase": 0.0, "radius": 0.42},
				{"kind": "slide", "center": Vector2(0, 1.9), "axis": Vector2(1, 0), "travel": 3.6, "frequency": 0.6, "phase": PI, "radius": 0.42}]}},
	{"name": "Posto Sentinela IV", "tag": "Piloto de posto", "boss": 103, "tier": 8, "minor": true, "music": 4, "hue": "5fe0b4", "ultimate": "b_patch", "kit": ["air", "mirror"],
		"challenge": "Um piloto de posto, sem nome e sem skin: traz a sentinela e o que comprou.",
		"map": {"tall": true, "lean": true, "id": "posto_04", "outline": "gorge", "boosters": true, "bricks": "islands", "lives": 4, "barriers": [],
			"obstacles": [
				{"kind": "slide", "center": Vector2(0, -2.4), "axis": Vector2(1, 0), "travel": 2.8, "frequency": 0.6, "phase": 0.0, "radius": 0.42},
				{"kind": "slide", "center": Vector2(0, 2.4), "axis": Vector2(1, 0), "travel": 2.8, "frequency": 0.6, "phase": PI, "radius": 0.42}]}},
	{"name": "Posto Sentinela V", "tag": "Piloto de posto", "boss": 104, "tier": 8, "minor": true, "music": 5, "hue": "5fc8ff", "ultimate": "b_bar", "kit": ["rapid", "stun"],
		"challenge": "Um piloto de posto, sem nome e sem skin: traz a sentinela e o que comprou.",
		"map": {"tall": true, "lean": true, "id": "posto_05", "outline": "lens", "boosters": true, "bricks": "banks", "lives": 4, "barriers": [],
			"obstacles": [
				{"kind": "slide", "center": Vector2(0, -1.9), "axis": Vector2(1, 0), "travel": 3.6, "frequency": 0.6, "phase": 0.0, "radius": 0.42},
				{"kind": "slide", "center": Vector2(0, 1.9), "axis": Vector2(1, 0), "travel": 3.6, "frequency": 0.6, "phase": PI, "radius": 0.42}]}},
	{"name": "Santuário Eclipse", "tag": "Quatro luas", "boss": 5, "tier": 9,
		"challenge": "Quatro luas guardam os cantos. O centro continua aberto de ponta a ponta.",
		"map": {"tall": true, "lean": true, "id": "santuario", "outline": "octagon", "boosters": true, "bricks": "fortress", "lives": 4, "barriers": [],
			"obstacles": [
				{"kind": "orbit", "center": Vector2(0, 0), "travel": 2.4, "frequency": 0.42, "phase": 0.0, "radius": 0.42},
				{"kind": "orbit", "center": Vector2(0, 0), "travel": 2.4, "frequency": 0.28, "phase": PI, "radius": 0.42}]}},
	{"name": "Posto Arconte I", "tag": "Piloto de posto", "boss": 105, "tier": 9, "minor": true, "music": 6, "hue": "b78fff", "ultimate": "b_push", "kit": ["blast", "freeze"],
		"challenge": "Um piloto de posto, sem nome e sem skin: traz a arconte e o que comprou.",
		"map": {"tall": true, "lean": true, "id": "posto_06", "outline": "stadium", "boosters": true, "bricks": "wall", "lives": 4, "barriers": [],
			"obstacles": [
				{"kind": "slide", "center": Vector2(0, -2.4), "axis": Vector2(1, 0), "travel": 2.8, "frequency": 0.6, "phase": 0.0, "radius": 0.42},
				{"kind": "slide", "center": Vector2(0, 2.4), "axis": Vector2(1, 0), "travel": 2.8, "frequency": 0.6, "phase": PI, "radius": 0.42}]}},
	{"name": "Posto Arconte II", "tag": "Piloto de posto", "boss": 106, "tier": 9, "minor": true, "music": 7, "hue": "ff6bb4", "ultimate": "b_slow", "kit": ["laser", "walls"],
		"challenge": "Um piloto de posto, sem nome e sem skin: traz a arconte e o que comprou.",
		"map": {"tall": true, "lean": true, "id": "posto_07", "outline": "octagon", "boosters": true, "bricks": "arc", "lives": 4, "barriers": [],
			"obstacles": [
				{"kind": "slide", "center": Vector2(0, -1.9), "axis": Vector2(1, 0), "travel": 3.6, "frequency": 0.6, "phase": 0.0, "radius": 0.42},
				{"kind": "slide", "center": Vector2(0, 1.9), "axis": Vector2(1, 0), "travel": 3.6, "frequency": 0.6, "phase": PI, "radius": 0.42}]}},
	{"name": "Posto Arconte III", "tag": "Piloto de posto", "boss": 107, "tier": 9, "minor": true, "music": 8, "hue": "ffe06b", "ultimate": "b_forge", "kit": ["pierce", "weld"],
		"challenge": "Um piloto de posto, sem nome e sem skin: traz a arconte e o que comprou.",
		"map": {"tall": true, "lean": true, "id": "posto_08", "outline": "lens", "boosters": true, "bricks": "chevron", "lives": 4, "barriers": [],
			"obstacles": [
				{"kind": "slide", "center": Vector2(0, -2.4), "axis": Vector2(1, 0), "travel": 2.8, "frequency": 0.6, "phase": 0.0, "radius": 0.42},
				{"kind": "slide", "center": Vector2(0, 2.4), "axis": Vector2(1, 0), "travel": 2.8, "frequency": 0.6, "phase": PI, "radius": 0.42}]}},
	{"name": "Posto Arconte IV", "tag": "Piloto de posto", "boss": 108, "tier": 9, "minor": true, "music": 9, "hue": "8fa8ff", "ultimate": "b_aim", "kit": ["rapid", "thorns"],
		"challenge": "Um piloto de posto, sem nome e sem skin: traz a arconte e o que comprou.",
		"map": {"tall": true, "lean": true, "id": "posto_09", "outline": "colosseum", "boosters": true, "bricks": "banks", "lives": 4, "barriers": [],
			"obstacles": [
				{"kind": "slide", "center": Vector2(0, -1.9), "axis": Vector2(1, 0), "travel": 3.6, "frequency": 0.6, "phase": 0.0, "radius": 0.42},
				{"kind": "slide", "center": Vector2(0, 1.9), "axis": Vector2(1, 0), "travel": 3.6, "frequency": 0.6, "phase": PI, "radius": 0.42}]}},
	{"name": "Posto Arconte V", "tag": "Piloto de posto", "boss": 109, "tier": 9, "minor": true, "music": 10, "hue": "ff7d7d", "ultimate": "b_drill", "kit": ["laser", "magnet"],
		"challenge": "Um piloto de posto, sem nome e sem skin: traz a arconte e o que comprou.",
		"map": {"tall": true, "lean": true, "id": "posto_10", "outline": "gorge", "boosters": true, "bricks": "islands", "lives": 4, "barriers": [],
			"obstacles": [
				{"kind": "slide", "center": Vector2(0, -2.4), "axis": Vector2(1, 0), "travel": 2.8, "frequency": 0.6, "phase": 0.0, "radius": 0.42},
				{"kind": "slide", "center": Vector2(0, 2.4), "axis": Vector2(1, 0), "travel": 2.8, "frequency": 0.6, "phase": PI, "radius": 0.42}]}},
	{"name": "Coroa Solar", "tag": "Tudo junto", "boss": 10, "tier": 10,
		"challenge": "O desafio final: seis corpos em movimento pelas paredes, o centro livre para o teu tiro.",
		"map": {"tall": true, "lean": true, "id": "coroa", "outline": "stadium", "boosters": true, "bricks": "fortress", "lives": 4,
			"barriers": [
				{"a": Vector2(-7.2, -1.2), "b": Vector2(-6.5, 0)}, {"a": Vector2(-6.5, 0), "b": Vector2(-7.2, 1.2)},
				{"a": Vector2(7.2, -1.2), "b": Vector2(6.5, 0)}, {"a": Vector2(6.5, 0), "b": Vector2(7.2, 1.2)}],
			"obstacles": [
				{"kind": "slide", "center": Vector2(0, -2.6), "axis": Vector2(1, 0), "travel": 4.6, "frequency": 0.5, "phase": 0.0, "radius": 0.42},
				{"kind": "slide", "center": Vector2(0, 2.6), "axis": Vector2(1, 0), "travel": 4.6, "frequency": 0.5, "phase": PI, "radius": 0.42},
				{"kind": "orbit", "center": Vector2(0, 0), "travel": 2.6, "frequency": 0.43, "phase": 0.0, "radius": 0.41}]}},
]
var config_path = CONFIG_PATH
var unlocked = 1
var unlock_all = UNLOCK_ALL_FOR_TESTS
var completed: Array = []

# What the boss of each level carries: the early ones only shoot, the late ones defend too.
# Two bought powers each, chosen to say something about the pilot and to put every power
# in the shop in front of the player at least once before the run is over.
const BOSS_KITS = [
	["blast", "air"], ["blast", "air"], ["blast", "weld"], ["blast", "magnet"], ["blast", "freeze"],
	["rapid", "stun"], ["blast", "thorns"], ["rapid", "ghost"], ["laser", "rebuild"], ["pierce", "walls"],
	["laser", "magnet"],
]

static func boss_kit(index: int) -> Array:
	# A station pilot brings the kit written on its own level; a boss brings the one from
	# the table, which is ordered by boss and not by level number.
	var level: Dictionary = LEVELS[clampi(index, 0, LEVELS.size() - 1)]
	if level.has("kit"):
		return Array(level.kit).duplicate()
	var seat: int = 0
	for step in range(clampi(index, 0, LEVELS.size() - 1)):
		if not LEVELS[step].get("minor", false):
			seat += 1
	return BOSS_KITS[clampi(seat, 0, BOSS_KITS.size() - 1)].duplicate()

static func is_minor(index: int) -> bool:
	# A station pilot: no skin of its own to win, and a plain ultimate.
	return LEVELS[clampi(index, 0, LEVELS.size() - 1)].get("minor", false)

static func level_music(index: int) -> int:
	# Which theme plays. A station pilot has no skin to take one from, so its level says.
	var level: Dictionary = LEVELS[clampi(index, 0, LEVELS.size() - 1)]
	return int(level.music) if level.has("music") else int(level.boss)

static func level_hue(index: int) -> String:
	# A station pilot wears a hull from the catalogue dressed in a colour of its own, so ten
	# of them in a row do not read as the same nobody ten times. The bosses keep their own
	# palettes and answer with an empty string.
	var level: Dictionary = LEVELS[clampi(index, 0, LEVELS.size() - 1)]
	return String(level.hue) if level.has("hue") else ""

static func level_ultimate(index: int) -> String:
	# What the opponent on this level brings in its third key.
	var level: Dictionary = LEVELS[clampi(index, 0, LEVELS.size() - 1)]
	return String(level.ultimate) if level.has("ultimate") else ""

static func ai_profile(index: int, difficulty: int) -> Dictionary:
	# The boss grows stronger level by level; FÁCIL / DIFÍCIL shift the whole curve.
	var tier = LEVELS[clampi(index, 0, LEVELS.size() - 1)].tier / float(TOP_TIER)
	# The campaign starts welcoming and ramps smoothly. Bosses still develop their
	# own behaviour, but leave time to aim around the scenery.
	# Powers too: the first bosses save them for a long time, the last ones keep them coming.
	# The ultimate too: the first bosses only reach for it near the end of a long match,
	# the last ones open with it.
	var profile = {"fire_gap": lerpf(2.35, 0.55, tier), "move": lerpf(0.34, 0.76, tier), "dodge": tier >= 0.5,
		"power_gap": lerpf(9.5, 3.0, tier), "ultimate_wait": lerpf(42.0, 7.0, tier),
		"charge_tick": lerpf(2.4, 0.9, tier), "ultimate_gap": lerpf(45.0, 26.0, tier), "ultimate_rate": 1.0}
	match difficulty:
		0:
			profile.fire_gap = profile.fire_gap * 1.55 + 0.55
			profile.move *= 0.8
			profile.dodge = tier >= 0.7
			profile.power_gap *= 1.5
			profile.ultimate_wait *= 1.5
			profile.charge_tick *= 1.4
			profile.ultimate_gap *= 1.3
		2:
			profile.fire_gap *= 0.55
			profile.move = minf(1.0, profile.move * 1.15)
			profile.dodge = true
			profile.power_gap *= 0.65
			profile.ultimate_wait *= 0.6
			profile.charge_tick *= 0.75
			profile.ultimate_gap *= 0.7
			# On DIFICIL the ultimate winds as fast as the rest of the kit.
			profile.ultimate_rate = 2.0
	if difficulty > 0:
		profile.fire_gap = lerpf(0.8, 0.25, tier) if difficulty == 1 else lerpf(0.28, 0.0, tier)
		profile.move = lerpf(0.65, 0.88, tier) if difficulty == 1 else lerpf(0.86, 1.0, tier)
		profile.dodge = true
		profile.power_gap = lerpf(1.2, 0.9, tier) if difficulty == 1 else lerpf(0.65, 0.45, tier)
		profile.charge_tick = lerpf(1.0, 0.8, tier) if difficulty == 1 else lerpf(0.7, 0.55, tier)
		profile.ultimate_rate = 2.0
		profile.ultimate_wait = lerpf(8.0, 4.0, tier) if difficulty == 1 else lerpf(5.0, 2.0, tier)
		profile.ultimate_gap = 14.0 if difficulty == 1 else 10.0
	return profile

func is_unlocked(index: int) -> bool:
	return index >= 0 and index < LEVELS.size() and (unlock_all or index < mini(unlocked, LEVELS.size()))

func suggested_level() -> int:
	# The first playable level not yet won, for the menu to open on.
	for index in range(LEVELS.size()):
		if is_unlocked(index) and not completed.has(index):
			return index
	return next_level()

func is_completed(index: int) -> bool:
	return completed.has(index)

func next_level() -> int:
	return mini(unlocked, LEVELS.size()) - 1

func complete(index: int) -> bool:
	# Returns true when this win opened a new level.
	if not is_unlocked(index):
		return false
	if not completed.has(index):
		completed.append(index)
	var opened = index + 2 > unlocked and index + 1 < LEVELS.size()
	unlocked = clampi(maxi(unlocked, index + 2), 1, LEVELS.size())
	return opened

func load_preferences() -> void:
	var config = ConfigFile.new()
	if config.load(config_path) != OK:
		return
	if int(config.get_value("campaign", "version", 1)) < SAVE_VERSION:
		return
	unlocked = clampi(int(config.get_value("campaign", "unlocked", 1)), 1, LEVELS.size())
	completed = Array(config.get_value("campaign", "completed", [])).filter(func(i): return i is int and i >= 0 and i < unlocked)

func save_preferences() -> Error:
	var config = ConfigFile.new()
	config.set_value("campaign", "version", SAVE_VERSION)
	config.set_value("campaign", "unlocked", unlocked)
	config.set_value("campaign", "completed", completed)
	return config.save(config_path)
