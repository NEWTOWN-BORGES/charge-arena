extends RefCounted
## PvE campaign: ten arenas, each with its own challenge and boss. Winning a level
## unlocks the next one. Progress stays on this device.
const Rules = preload("res://scripts/arena_rules.gd")
const CONFIG_PATH = "user://campaign.cfg"
# Testing build: every level can be played. Set to false to unlock level by level again;
# wins are saved either way.
const UNLOCK_ALL_FOR_TESTS = true
# boss: skin worn by the rival (and its bricks), a different one per level; beating it
# unlocks that skin. tier: 0 (gentle) to 9 (relentless).
const LEVELS = [
	{"name": "Oficina do Relógio", "tag": "Deslizadores", "boss": 6, "tier": 0,
		"challenge": "Duas engrenagens deslizam no meio. Usa-as para ganhar ricochetes.",
		"map": {"id": "aurora", "outline": "hex", "boosters": true, "bricks": "banks", "barriers": [],
			"obstacles": [
				{"kind": "slide", "center": Vector2(0, -1.25), "axis": Vector2(1, 0), "travel": Rules.OBSTACLE_TRAVEL, "frequency": Rules.OBSTACLE_FREQUENCY, "phase": 0.0},
				{"kind": "slide", "center": Vector2(0, 1.25), "axis": Vector2(1, 0), "travel": Rules.OBSTACLE_TRAVEL, "frequency": Rules.OBSTACLE_FREQUENCY, "phase": PI}]}},
	{"name": "Baía do Farol", "tag": "Pilares e muralha", "boss": 1, "tier": 1,
		"challenge": "Três faróis fixos cortam o meio e uma muralha guarda cada baliza.",
		"map": {"id": "farol", "outline": "octagon", "boosters": true, "bricks": "wall", "barriers": [],
			"obstacles": [
				{"kind": "fixed", "center": Vector2(-3.3, 0), "radius": 0.62},
				{"kind": "fixed", "center": Vector2(0, 0), "radius": 0.5},
				{"kind": "fixed", "center": Vector2(3.3, 0), "radius": 0.62}]}},
	{"name": "Estufa Suspensa", "tag": "Cintura estreita", "boss": 3, "tier": 2,
		"challenge": "A arena aperta no meio e dois vasos giram em órbita.",
		"map": {"id": "estufa", "outline": "pinch", "boosters": true, "bricks": "arc", "barriers": [],
			"obstacles": [
				{"kind": "orbit", "center": Vector2.ZERO, "travel": 1.9, "frequency": 0.7, "phase": 0.0, "radius": 0.58},
				{"kind": "orbit", "center": Vector2.ZERO, "travel": 1.9, "frequency": 0.7, "phase": PI, "radius": 0.58}]}},
	{"name": "Observatório Lunar", "tag": "Três luas", "boss": 2, "tier": 3,
		"challenge": "Sem aceleradores. Três luas giram à volta do centro.",
		"map": {"id": "observatorio", "outline": "hex", "boosters": false, "bricks": "islands", "barriers": [],
			"obstacles": [
				{"kind": "orbit", "center": Vector2.ZERO, "travel": 2.4, "frequency": 0.45, "phase": 0.0, "radius": 0.55},
				{"kind": "orbit", "center": Vector2.ZERO, "travel": 2.4, "frequency": 0.45, "phase": TAU / 3, "radius": 0.55},
				{"kind": "orbit", "center": Vector2.ZERO, "travel": 2.4, "frequency": 0.45, "phase": TAU * 2 / 3, "radius": 0.55}]}},
	{"name": "Mina Profunda", "tag": "Vagonetas", "boss": 4, "tier": 4,
		"challenge": "Vagonetas sobem e descem nos lados; uma barreira trava o tiro a direito.",
		"map": {"id": "mina", "outline": "wide", "boosters": true, "bricks": "chevron",
			"barriers": [{"a": Vector2(-1.1, 0), "b": Vector2(1.1, 0)}],
			"obstacles": [
				{"kind": "slide", "center": Vector2(-3.4, 0), "axis": Vector2(0, 1), "travel": 1.9, "frequency": 0.9, "phase": 0.0},
				{"kind": "slide", "center": Vector2(3.4, 0), "axis": Vector2(0, 1), "travel": 1.9, "frequency": 0.9, "phase": PI}]}},
	{"name": "Santuário Eclipse", "tag": "Monólito central", "boss": 5, "tier": 5,
		"challenge": "Um monólito no centro desvia tudo e duas luas guardam-no.",
		"map": {"id": "santuario", "outline": "octagon", "boosters": true, "bricks": "banks", "barriers": [],
			"obstacles": [
				{"kind": "fixed", "center": Vector2.ZERO, "radius": 1.05},
				{"kind": "orbit", "center": Vector2.ZERO, "travel": 2.6, "frequency": 0.55, "phase": 0.0, "radius": 0.5},
				{"kind": "orbit", "center": Vector2.ZERO, "travel": 2.6, "frequency": 0.55, "phase": PI, "radius": 0.5}]}},
	{"name": "Torre da Tempestade", "tag": "Defletores", "boss": 7, "tier": 6,
		"challenge": "Quatro defletores em diagonal e um deslizador rápido no centro.",
		"map": {"id": "tempestade", "outline": "pinch", "boosters": true, "bricks": "islands",
			"barriers": [
				{"a": Vector2(-3.6, -2.5), "b": Vector2(-2.3, -1.6)}, {"a": Vector2(2.3, -1.6), "b": Vector2(3.6, -2.5)},
				{"a": Vector2(-3.6, 2.5), "b": Vector2(-2.3, 1.6)}, {"a": Vector2(2.3, 1.6), "b": Vector2(3.6, 2.5)}],
			"obstacles": [
				{"kind": "slide", "center": Vector2.ZERO, "axis": Vector2(1, 0), "travel": 2.2, "frequency": 1.3, "phase": 0.0, "radius": 0.55}]}},
	{"name": "Laboratório de Cristal", "tag": "Losango de pilares", "boss": 8, "tier": 7,
		"challenge": "Quatro pilares em losango e dois deslizadores à frente dos arcos.",
		"map": {"id": "jardim", "outline": "wide", "boosters": true, "bricks": "arc", "barriers": [],
			"obstacles": [
				{"kind": "fixed", "center": Vector2(-2.6, 0), "radius": 0.5},
				{"kind": "fixed", "center": Vector2(2.6, 0), "radius": 0.5},
				{"kind": "fixed", "center": Vector2(0, -1.5), "radius": 0.5},
				{"kind": "fixed", "center": Vector2(0, 1.5), "radius": 0.5},
				{"kind": "slide", "center": Vector2(0, -2.5), "axis": Vector2(1, 0), "travel": 3.2, "frequency": 0.8, "phase": 0.0, "radius": 0.5},
				{"kind": "slide", "center": Vector2(0, 2.5), "axis": Vector2(1, 0), "travel": 3.2, "frequency": 0.8, "phase": PI, "radius": 0.5}]}},
	{"name": "Recife dos Corsários", "tag": "Órbita e barreira", "boss": 9, "tier": 8,
		"challenge": "Uma barreira no centro, dois barris em órbita e botes junto às paredes.",
		"map": {"id": "veio", "outline": "hex", "boosters": false, "bricks": "wall",
			"barriers": [{"a": Vector2(-0.9, 0), "b": Vector2(0.9, 0)}],
			"obstacles": [
				{"kind": "orbit", "center": Vector2.ZERO, "travel": 2.2, "frequency": 0.8, "phase": 0.0, "radius": 0.5},
				{"kind": "orbit", "center": Vector2.ZERO, "travel": 2.2, "frequency": 0.8, "phase": PI, "radius": 0.5},
				{"kind": "slide", "center": Vector2(-4.8, 0), "axis": Vector2(0, 1), "travel": 1.6, "frequency": 1.0, "phase": 0.0, "radius": 0.5},
				{"kind": "slide", "center": Vector2(4.8, 0), "axis": Vector2(0, 1), "travel": 1.6, "frequency": 1.0, "phase": PI, "radius": 0.5}]}},
	{"name": "Coroa Solar", "tag": "Tudo junto", "boss": 10, "tier": 9,
		"challenge": "O último boss: um sol no centro, três luas e defletores em V junto às paredes.",
		"map": {"id": "coroa", "outline": "octagon", "boosters": true, "bricks": "chevron",
			"barriers": [
				{"a": Vector2(-5.9, -1.0), "b": Vector2(-4.7, 0)}, {"a": Vector2(-4.7, 0), "b": Vector2(-5.9, 1.0)},
				{"a": Vector2(5.9, -1.0), "b": Vector2(4.7, 0)}, {"a": Vector2(4.7, 0), "b": Vector2(5.9, 1.0)}],
			"obstacles": [
				{"kind": "fixed", "center": Vector2.ZERO, "radius": 0.85},
				{"kind": "orbit", "center": Vector2.ZERO, "travel": 2.5, "frequency": 0.6, "phase": 0.0, "radius": 0.5},
				{"kind": "orbit", "center": Vector2.ZERO, "travel": 2.5, "frequency": 0.6, "phase": TAU / 3, "radius": 0.5},
				{"kind": "orbit", "center": Vector2.ZERO, "travel": 2.5, "frequency": 0.6, "phase": TAU * 2 / 3, "radius": 0.5}]}},
]
var config_path = CONFIG_PATH
var unlocked = 1
var unlock_all = UNLOCK_ALL_FOR_TESTS
var completed: Array = []

static func ai_profile(index: int, difficulty: int) -> Dictionary:
	# The boss grows stronger level by level; FÁCIL / DIFÍCIL shift the whole curve.
	var tier = LEVELS[clampi(index, 0, LEVELS.size() - 1)].tier / 9.0
	var profile = {"fire_gap": lerpf(1.7, 0.1, tier), "move": lerpf(0.45, 1.0, tier), "dodge": tier >= 0.2}
	match difficulty:
		0:
			profile.fire_gap = profile.fire_gap * 1.4 + 0.5
			profile.move *= 0.85
			profile.dodge = tier >= 0.6
		2:
			profile.fire_gap *= 0.55
			profile.move = minf(1.0, profile.move * 1.15)
			profile.dodge = true
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
