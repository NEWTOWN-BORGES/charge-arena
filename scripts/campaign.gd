extends RefCounted
## PvE campaign: eleven arenas, each with its own challenge and boss. The first is a
## training bout against a copy of the standard pilot; the other ten each carry a skin. Winning a level
## unlocks the next one. Progress stays on this device.
const Rules = preload("res://scripts/arena_rules.gd")
const CONFIG_PATH = "user://campaign.cfg"
# A single match victory unlocks the next arena. Progress is saved on device.
const UNLOCK_ALL_FOR_TESTS = false
# boss: skin worn by the rival (and its bricks), a different one per level; beating it
# unlocks that skin. tier: 0 (gentle) to 9 (relentless).
const LEVELS = [
	{"name": "Circuito Aurora", "tag": "Treino", "boss": 0, "tier": 0,
		"challenge": "A arena de origem, sem obstáculos: aprende o arco, o ricochete e os aceleradores.",
		"map": {"id": "treino", "outline": "stadium", "boosters": true, "bricks": "banks", "barriers": [], "obstacles": []}},
	{"name": "Oficina do Relógio", "tag": "Deslizadores", "boss": 6, "tier": 1,
		"challenge": "Duas engrenagens sobem e descem junto às paredes. A rota do meio fica toda tua.",
		"map": {"id": "oficina", "outline": "stadium", "boosters": true, "bricks": "chevron", "barriers": [],
			"obstacles": [
				{"kind": "slide", "center": Vector2(0, -2.3), "axis": Vector2(1, 0), "travel": 4.4, "frequency": 0.6, "phase": 0.0, "radius": 0.44},
				{"kind": "slide", "center": Vector2(0, 2.3), "axis": Vector2(1, 0), "travel": 4.4, "frequency": 0.6, "phase": PI, "radius": 0.44}]}},
	{"name": "Baía do Farol", "tag": "Faróis giratórios", "boss": 1, "tier": 2,
		"challenge": "Dois faróis giram encostados às paredes e devolvem os tiros largos.",
		"map": {"id": "farol", "outline": "octagon", "boosters": true, "bricks": "wall", "lives": 3, "barriers": [],
			"obstacles": [
				{"kind": "orbit", "center": Vector2(0, 0), "travel": 2.6, "frequency": 0.5, "phase": 0.0, "radius": 0.46},
				{"kind": "orbit", "center": Vector2(0, 0), "travel": 2.6, "frequency": 0.5, "phase": PI, "radius": 0.46},
				{"kind": "fixed", "center": Vector2(-6.9, -4.6), "radius": 0.44},
				{"kind": "fixed", "center": Vector2(6.9, -4.6), "radius": 0.44},
				{"kind": "fixed", "center": Vector2(-6.9, 4.6), "radius": 0.44},
				{"kind": "fixed", "center": Vector2(6.9, 4.6), "radius": 0.44}]}},
	{"name": "Estufa Suspensa", "tag": "Cintura estreita", "boss": 3, "tier": 3,
		"challenge": "A arena aperta a meio, mas o fundo é largo: corre até ao canto para abrir ângulo.",
		"map": {"id": "estufa", "outline": "gorge", "boosters": true, "bricks": "islands", "barriers": [],
			"obstacles": [
				{"kind": "slide", "center": Vector2(0, -1.9), "axis": Vector2(1, 0), "travel": 3.6, "frequency": 0.55, "phase": 0.0, "radius": 0.42},
				{"kind": "slide", "center": Vector2(0, 1.9), "axis": Vector2(1, 0), "travel": 3.6, "frequency": 0.55, "phase": PI, "radius": 0.42}]}},
	{"name": "Observatório Lunar", "tag": "Duas luas", "boss": 2, "tier": 4,
		"challenge": "Duas luas lentas correm pelas bojudas laterais; sem aceleradores, o ricochete é todo teu.",
		"map": {"id": "observatorio", "outline": "lens", "boosters": false, "bricks": "arc", "barriers": [],
			"obstacles": [
				{"kind": "orbit", "center": Vector2(0, 0), "travel": 2.4, "frequency": 0.36, "phase": 0.0, "radius": 0.43},
				{"kind": "orbit", "center": Vector2(0, 0), "travel": 2.4, "frequency": 0.36, "phase": PI, "radius": 0.43}]}},
	{"name": "Mina Profunda", "tag": "Vagonetas", "boss": 4, "tier": 5,
		"challenge": "As vagonetas sobem e descem coladas às paredes do coliseu, longe da linha de tiro.",
		"map": {"id": "mina", "outline": "colosseum", "boosters": true, "bricks": "bulwark", "lives": 3, "barriers": [],
			"obstacles": [
				{"kind": "slide", "center": Vector2(0, -1.7), "axis": Vector2(1, 0), "travel": 5.0, "frequency": 0.65, "phase": 0.0, "radius": 0.44},
				{"kind": "slide", "center": Vector2(0, 1.7), "axis": Vector2(1, 0), "travel": 5.0, "frequency": 0.65, "phase": PI, "radius": 0.44}]}},
	{"name": "Santuário Eclipse", "tag": "Quatro luas", "boss": 5, "tier": 6,
		"challenge": "Quatro luas guardam os cantos. O centro continua aberto de ponta a ponta.",
		"map": {"id": "santuario", "outline": "octagon", "boosters": true, "bricks": "banks", "lives": 4, "barriers": [],
			"obstacles": [
				{"kind": "orbit", "center": Vector2(0, 0), "travel": 2.4, "frequency": 0.42, "phase": 0.0, "radius": 0.42},
				{"kind": "orbit", "center": Vector2(0, 0), "travel": 3.6, "frequency": 0.28, "phase": PI, "radius": 0.42}]}},
	{"name": "Torre da Tempestade", "tag": "Pára-raios", "boss": 7, "tier": 7,
		"challenge": "Dois pára-raios varrem as bojudas laterais. Nada fechado, tudo para ricochetear.",
		"map": {"id": "tempestade", "outline": "lens", "boosters": true, "bricks": "bulwark", "lives": 4, "barriers": [],
			"obstacles": [
				{"kind": "slide", "center": Vector2(0, -2.0), "axis": Vector2(1, 0), "travel": 4.8, "frequency": 0.72, "phase": 0.0, "radius": 0.43},
				{"kind": "slide", "center": Vector2(0, 2.0), "axis": Vector2(1, 0), "travel": 4.8, "frequency": 0.72, "phase": PI, "radius": 0.43}]}},
	{"name": "Laboratório de Cristal", "tag": "Quatro cristais", "boss": 8, "tier": 8,
		"challenge": "Quatro cristais orbitam junto às paredes: muito ricochete, nenhum corredor fechado.",
		"map": {"id": "laboratorio", "outline": "gorge", "boosters": true, "bricks": "fortress", "lives": 3, "barriers": [],
			"obstacles": [
				{"kind": "orbit", "center": Vector2(0, 0), "travel": 2.2, "frequency": 0.5, "phase": 0.0, "radius": 0.4},
				{"kind": "slide", "center": Vector2(0, 0), "axis": Vector2(1, 0), "travel": 4.0, "frequency": 0.4, "phase": PI / 2, "radius": 0.4}]}},
	{"name": "Recife dos Corsários", "tag": "Coliseu", "boss": 9, "tier": 9,
		"challenge": "O estádio retangular: cantos chanfrados, barris lentos junto às paredes e nada no meio.",
		"map": {"id": "recife", "outline": "colosseum", "boosters": true, "bricks": "fortress", "lives": 4, "barriers": [],
			"obstacles": [
				{"kind": "orbit", "center": Vector2(0, 0), "travel": 2.2, "frequency": 0.48, "phase": 0.0, "radius": 0.42},
				{"kind": "orbit", "center": Vector2(0, 0), "travel": 2.2, "frequency": 0.48, "phase": PI, "radius": 0.42}]}},
	{"name": "Coroa Solar", "tag": "Tudo junto", "boss": 10, "tier": 10,
		"challenge": "O desafio final: seis corpos em movimento pelas paredes, o centro livre para o teu tiro.",
		"map": {"id": "coroa", "outline": "stadium", "boosters": true, "bricks": "fortress", "lives": 4,
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
const BOSS_KITS = [
	["blast", "air"], ["blast", "air"], ["blast", "air"], ["blast", "rapid"], ["blast", "ghost"],
	["rapid", "stun"], ["blast", "mirror"], ["rapid", "ghost"], ["laser", "rebuild"], ["rapid", "walls"],
	["laser", "stun"],
]

static func boss_kit(index: int) -> Array:
	return BOSS_KITS[clampi(index, 0, BOSS_KITS.size() - 1)].duplicate()

static func ai_profile(index: int, difficulty: int) -> Dictionary:
	# The boss grows stronger level by level; FÁCIL / DIFÍCIL shift the whole curve.
	var tier = LEVELS[clampi(index, 0, LEVELS.size() - 1)].tier / float(LEVELS.size() - 1)
	# The campaign starts welcoming and ramps smoothly. Bosses still develop their
	# own behaviour, but leave time to aim around the scenery.
	# Powers too: the first bosses save them for a long time, the last ones keep them coming.
	# The ultimate too: the first bosses only reach for it near the end of a long match,
	# the last ones open with it.
	var profile = {"fire_gap": lerpf(2.35, 0.55, tier), "move": lerpf(0.34, 0.76, tier), "dodge": tier >= 0.5,
		"power_gap": lerpf(9.5, 3.0, tier), "ultimate_wait": lerpf(42.0, 7.0, tier)}
	match difficulty:
		0:
			profile.fire_gap = profile.fire_gap * 1.55 + 0.55
			profile.move *= 0.8
			profile.dodge = tier >= 0.7
			profile.power_gap *= 1.5
			profile.ultimate_wait *= 1.5
		2:
			profile.fire_gap *= 0.55
			profile.move = minf(1.0, profile.move * 1.15)
			profile.dodge = true
			profile.power_gap *= 0.65
			profile.ultimate_wait *= 0.6
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
	unlocked = clampi(int(config.get_value("campaign", "unlocked", 1)), 1, LEVELS.size())
	completed = Array(config.get_value("campaign", "completed", [])).filter(func(i): return i is int and i >= 0 and i < unlocked)

func save_preferences() -> Error:
	var config = ConfigFile.new()
	config.set_value("campaign", "unlocked", unlocked)
	config.set_value("campaign", "completed", completed)
	return config.save(config_path)
