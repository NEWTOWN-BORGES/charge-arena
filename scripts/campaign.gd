extends RefCounted
## PvE campaign: eleven arenas, each with its own challenge and boss. The first is a
## training bout against a copy of the standard pilot; the other ten each carry a skin. Winning a level
## unlocks the next one. Progress stays on this device.
const Rules = preload("res://scripts/arena_rules.gd")
const CONFIG_PATH = "user://campaign.cfg"
# A single match victory unlocks the next arena. Progress is saved on device.
const UNLOCK_ALL_FOR_TESTS = true
# boss: skin worn by the rival (and its bricks), a different one per level; beating it
# unlocks that skin. tier: 0 (gentle) to 9 (relentless).
const LEVELS = [
	{"name": "Circuito Aurora", "tag": "Treino", "boss": 0, "tier": 0,
		"challenge": "A arena de origem, sem obstáculos: aprende o arco, o ricochete e os aceleradores.",
		"map": {"id": "treino", "outline": "hex", "boosters": true, "bricks": "banks", "barriers": [], "obstacles": []}},
	{"name": "Oficina do Relógio", "tag": "Deslizadores", "boss": 6, "tier": 1,
		"challenge": "Duas engrenagens deslizam no meio. Usa-as para desviar os teus tiros.",
		"map": {"id": "aurora", "outline": "hex", "boosters": true, "bricks": "banks", "barriers": [],
			"obstacles": [
				{"kind": "slide", "center": Vector2(0, -1.25), "axis": Vector2(1, 0), "travel": Rules.OBSTACLE_TRAVEL, "frequency": Rules.OBSTACLE_FREQUENCY, "phase": 0.0},
				{"kind": "slide", "center": Vector2(0, 1.25), "axis": Vector2(1, 0), "travel": Rules.OBSTACLE_TRAVEL, "frequency": Rules.OBSTACLE_FREQUENCY, "phase": PI}]}},
	{"name": "Baía do Farol", "tag": "Pilares e muralha", "boss": 1, "tier": 2,
		"challenge": "Dois faróis afastados criam ricochetes, com caminhos largos para avançar.",
		"map": {"id": "farol", "outline": "octagon", "boosters": true, "bricks": "wall", "barriers": [],
			"obstacles": [
				{"kind": "fixed", "center": Vector2(-3.0, 0), "radius": 0.44},
				{"kind": "fixed", "center": Vector2(3.0, 0), "radius": 0.44}]}},
	{"name": "Estufa Suspensa", "tag": "Cintura estreita", "boss": 3, "tier": 3,
		"challenge": "Dois vasos lentos giram em órbita, deixando o centro livre para apontar.",
		"map": {"id": "estufa", "outline": "pinch", "boosters": true, "bricks": "arc", "barriers": [],
			"obstacles": [
				{"kind": "orbit", "center": Vector2.ZERO, "travel": 1.7, "frequency": 0.5, "phase": 0.0, "radius": 0.44},
				{"kind": "orbit", "center": Vector2.ZERO, "travel": 1.7, "frequency": 0.5, "phase": PI, "radius": 0.44}]}},
	{"name": "Observatório Lunar", "tag": "Duas luas", "boss": 2, "tier": 4,
		"challenge": "Duas luas lentas giram à volta do centro; explora os ricochetes com calma.",
		"map": {"id": "observatorio", "outline": "hex", "boosters": false, "bricks": "islands", "barriers": [],
			"obstacles": [
				{"kind": "orbit", "center": Vector2.ZERO, "travel": 2.15, "frequency": 0.36, "phase": 0.0, "radius": 0.43},
				{"kind": "orbit", "center": Vector2.ZERO, "travel": 2.15, "frequency": 0.36, "phase": PI, "radius": 0.43}]}},
	{"name": "Mina Profunda", "tag": "Vagonetas", "boss": 4, "tier": 5,
		"challenge": "Vagonetas lentas passam pelos lados; a barreira curta convida a apontar pelos cantos.",
		"map": {"id": "mina", "outline": "wide", "boosters": true, "bricks": "chevron",
			"barriers": [{"a": Vector2(-0.72, 0), "b": Vector2(0.72, 0)}],
			"obstacles": [
				{"kind": "slide", "center": Vector2(-3.4, 0), "axis": Vector2(0, 1), "travel": 1.4, "frequency": 0.65, "phase": 0.0, "radius": 0.44},
				{"kind": "slide", "center": Vector2(3.4, 0), "axis": Vector2(0, 1), "travel": 1.4, "frequency": 0.65, "phase": PI, "radius": 0.44}]}},
	{"name": "Santuário Eclipse", "tag": "Monólito central", "boss": 5, "tier": 6,
		"challenge": "Um monólito no centro desvia tudo e duas luas guardam-no.",
		"map": {"id": "santuario", "outline": "octagon", "boosters": true, "bricks": "banks", "barriers": [],
			"obstacles": [
				{"kind": "fixed", "center": Vector2.ZERO, "radius": 0.72},
				{"kind": "orbit", "center": Vector2.ZERO, "travel": 2.3, "frequency": 0.4, "phase": 0.0, "radius": 0.42},
				{"kind": "orbit", "center": Vector2.ZERO, "travel": 2.3, "frequency": 0.4, "phase": PI, "radius": 0.42}]}},
	{"name": "Torre da Tempestade", "tag": "Defletores", "boss": 7, "tier": 7,
		"challenge": "Defletores curtos nos cantos e um deslizador tranquilo no centro.",
		"map": {"id": "tempestade", "outline": "pinch", "boosters": true, "bricks": "islands",
			"barriers": [
				{"a": Vector2(-3.4, -2.3), "b": Vector2(-2.55, -1.72)}, {"a": Vector2(2.55, -1.72), "b": Vector2(3.4, -2.3)},
				{"a": Vector2(-3.4, 2.3), "b": Vector2(-2.55, 1.72)}, {"a": Vector2(2.55, 1.72), "b": Vector2(3.4, 2.3)}],
			"obstacles": [
				{"kind": "slide", "center": Vector2.ZERO, "axis": Vector2(1, 0), "travel": 1.65, "frequency": 0.72, "phase": 0.0, "radius": 0.43}]}},
	{"name": "Laboratório de Cristal", "tag": "Losango de pilares", "boss": 8, "tier": 8,
		"challenge": "Pilares pequenos em losango e dois deslizadores lentos, com corredores visíveis.",
		"map": {"id": "jardim", "outline": "wide", "boosters": true, "bricks": "arc", "barriers": [],
			"obstacles": [
				{"kind": "fixed", "center": Vector2(-2.6, 0), "radius": 0.4},
				{"kind": "fixed", "center": Vector2(2.6, 0), "radius": 0.4},
				{"kind": "fixed", "center": Vector2(0, -1.5), "radius": 0.4},
				{"kind": "fixed", "center": Vector2(0, 1.5), "radius": 0.4},
				{"kind": "slide", "center": Vector2(0, -2.5), "axis": Vector2(1, 0), "travel": 2.3, "frequency": 0.52, "phase": 0.0, "radius": 0.4},
				{"kind": "slide", "center": Vector2(0, 2.5), "axis": Vector2(1, 0), "travel": 2.3, "frequency": 0.52, "phase": PI, "radius": 0.4}]}},
	{"name": "Recife dos Corsários", "tag": "Órbita e barreira", "boss": 9, "tier": 9,
		"challenge": "Barreira curta, barris lentos e botes junto às paredes deixam a rota central mais aberta.",
		"map": {"id": "veio", "outline": "hex", "boosters": false, "bricks": "wall",
			"barriers": [{"a": Vector2(-0.6, 0), "b": Vector2(0.6, 0)}],
			"obstacles": [
				{"kind": "orbit", "center": Vector2.ZERO, "travel": 2.0, "frequency": 0.48, "phase": 0.0, "radius": 0.42},
				{"kind": "orbit", "center": Vector2.ZERO, "travel": 2.0, "frequency": 0.48, "phase": PI, "radius": 0.42},
				{"kind": "slide", "center": Vector2(-4.8, 0), "axis": Vector2(0, 1), "travel": 1.15, "frequency": 0.6, "phase": 0.0, "radius": 0.42},
				{"kind": "slide", "center": Vector2(4.8, 0), "axis": Vector2(0, 1), "travel": 1.15, "frequency": 0.6, "phase": PI, "radius": 0.42}]}},
	{"name": "Coroa Solar", "tag": "Tudo junto", "boss": 10, "tier": 10,
		"challenge": "O desafio final: sol pequeno, luas lentas e defletores curtos junto às paredes.",
		"map": {"id": "coroa", "outline": "octagon", "boosters": true, "bricks": "chevron",
			"barriers": [
				{"a": Vector2(-5.55, -0.75), "b": Vector2(-4.85, 0)}, {"a": Vector2(-4.85, 0), "b": Vector2(-5.55, 0.75)},
				{"a": Vector2(5.55, -0.75), "b": Vector2(4.85, 0)}, {"a": Vector2(4.85, 0), "b": Vector2(5.55, 0.75)}],
			"obstacles": [
				{"kind": "fixed", "center": Vector2.ZERO, "radius": 0.62},
				{"kind": "orbit", "center": Vector2.ZERO, "travel": 2.25, "frequency": 0.43, "phase": 0.0, "radius": 0.41},
				{"kind": "orbit", "center": Vector2.ZERO, "travel": 2.25, "frequency": 0.43, "phase": TAU / 3, "radius": 0.41},
				{"kind": "orbit", "center": Vector2.ZERO, "travel": 2.25, "frequency": 0.43, "phase": TAU * 2 / 3, "radius": 0.41}]}},
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
