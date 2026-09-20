extends RefCounted
## Cosmetic pilot skins. Every skin but the first is a campaign boss: beating its level
## unlocks it. Progress stays on this device.
const CONFIG_PATH = "user://skins.cfg"
const SHOT_SOUND = "res://audio/sfx/shot_%d.wav"
# "level" is the campaign level (2-11) whose boss wears the skin; 0 means always owned.
# "ultimate" is the power in the third slot (see Powers.ULTIMATES); "" while one is missing.
# Level 1 is a training bout against a copy of the standard pilot, so it unlocks nothing.
# Empty colours fall back to the team colour, so each side stays readable.
# Each skin also restyles its team's bricks ("bricks" names that theme).
const CATALOG = [
	{"name": "PILOTO AURORA", "ultimate": "", "weapon": "Manopla de energia", "bricks": "Baterias Aurora", "about": "O equipamento de série do circuito.", "level": 0,
		"body": "", "light": "", "shot": ""},
	{"name": "FAROLEIRO", "ultimate": "", "weapon": "Lança-Farol", "bricks": "Farolins", "about": "Guarda dos faróis flutuantes: cúpula de latão, lanterna às costas e lança de cristal.", "level": 3,
		"body": "", "light": "9cc2ff", "shot": "9cc2ff"},
	{"name": "ASTRÓNOMO", "ultimate": "meteors", "weapon": "Sextante Estelar", "bricks": "Observatórios", "about": "Cartógrafo das órbitas do circuito: anéis planetários, luneta no olho e sextante de cristal.", "level": 5,
		"body": "444f8f", "light": "cbb2ff", "shot": "b99cff"},
	{"name": "JARDINEIRO", "ultimate": "bloom", "weapon": "Semeador", "bricks": "Estufas", "about": "Cuida dos jardins orbitais: cúpula de vidro com rebento, vaso às costas e semeador de sementes de luz.", "level": 4,
		"body": "5f7f52", "light": "c8f08f", "shot": "9fe37a"},
	{"name": "MINEIRO", "ultimate": "", "weapon": "Perfuradora de Cristal", "bricks": "Veios de cristal", "about": "Extrai cristais dos asteroides: capacete de obra com lanterna, carga de minério às costas e broca de quartzo.", "level": 6,
		"body": "59606b", "light": "ff9ad8", "shot": "ff7ad0"},
	{"name": "SENTINELA", "ultimate": "singularity", "weapon": "Lança Eclipse", "bricks": "Monólitos Eclipse", "about": "Guarda de elite do circuito: capa de obsidiana, halo de eclipse dourado e lança de corona.", "level": 7,
		"body": "2e3140", "light": "f2f4ff", "shot": "eef2ff"},
	{"name": "RELOJOEIRO", "ultimate": "sentries", "weapon": "Canhão de Corda", "bricks": "Relógios de torre", "about": "Afina as engrenagens do circuito: monóculo de lupa, chave de corda nas costas e canhão de molas.", "level": 2,
		"body": "7a5236", "light": "ffb14e", "shot": "ffa640"},
	{"name": "CAÇA-TROVÕES", "ultimate": "thunder", "weapon": "Bobina de Tesla", "bricks": "Para-raios", "about": "Persegue tempestades de plasma: capacete com para-raios, bateria às costas e bobina de Tesla.", "level": 8,
		"body": "36445e", "light": "7fe6ff", "shot": "8aeeff"},
	{"name": "ALQUIMISTA", "ultimate": "", "weapon": "Frasco de Plasma", "bricks": "Alambiques", "about": "Destila plasma das nebulosas: óculos de latão, alambique às costas e frascos borbulhantes.", "level": 9,
		"body": "5b4030", "light": "c6ff4d", "shot": "b8ff3d"},
	{"name": "CORSÁRIO", "ultimate": "plunder", "weapon": "Bacamarte Estelar", "bricks": "Arcas do tesouro", "about": "Pirata das rotas estelares: tricórnio, pala luminosa e bacamarte de boca larga.", "level": 10,
		"body": "2c3a4d", "light": "ff5c8a", "shot": "ff4f7e"},
	{"name": "ARCONTE SOLAR", "ultimate": "sun_ray", "weapon": "Cetro Solar", "bricks": "Obeliscos solares", "about": "Senhor do circuito: coroa de raios de sol, manto real e cetro com um sol em miniatura.", "level": 11,
		"body": "5a2e4f", "light": "ffe45c", "shot": "fff06a"},
]
# Testing build: every skin can be worn without beating its boss first. Set to false to
# earn them again; the bosses you have beaten are saved either way.
const UNLOCK_ALL_FOR_TESTS = false
# Saves written by the old unlocked test builds have every pilot already won. The demo
# refuses to read them, so a run starts with the standard pilot alone.
const SAVE_VERSION = 2

var config_path = CONFIG_PATH
var unlock_all = UNLOCK_ALL_FOR_TESTS
var defeated: Array = []
var selected = 0

static func colors(index: int, team_color: Color, boss_tint: bool = false) -> Dictionary:
	# boss_tint: campaign bosses fight in their team's red until beaten.
	if boss_tint:
		return {"body": team_color.darkened(0.3), "light": team_color.lightened(0.3), "shot": team_color}
	var entry: Dictionary = CATALOG[clampi(index, 0, CATALOG.size() - 1)]
	return {
		"body": Color(entry.body) if entry.body != "" else team_color,
		"light": Color(entry.light) if entry.light != "" else team_color.lightened(0.3),
		"shot": Color(entry.shot) if entry.shot != "" else team_color,
	}

static func boss_skin(level: int) -> int:
	# The skin worn by the boss of campaign level `level` (1-10), or -1.
	for index in range(CATALOG.size()):
		if CATALOG[index].level == level and level > 0:
			return index
	return -1

func is_unlocked(index: int) -> bool:
	return index >= 0 and index < CATALOG.size() and (unlock_all or CATALOG[index].level == 0 or defeated.has(index))

func unlocked_count() -> int:
	return range(CATALOG.size()).filter(is_unlocked).size()

func defeat(index: int) -> bool:
	# Returns true when beating this boss unlocked its skin for the first time.
	if index <= 0 or index >= CATALOG.size() or is_unlocked(index):
		return false
	defeated.append(index)
	return true

func select(index: int) -> bool:
	if not is_unlocked(index):
		return false
	selected = index
	return true

func load_preferences() -> void:
	var config = ConfigFile.new()
	if config.load(config_path) != OK:
		return
	if int(config.get_value("skins", "version", 1)) < SAVE_VERSION:
		return
	defeated = []
	for index in Array(config.get_value("skins", "defeated", [])):
		if index is int and index > 0 and index < CATALOG.size() and not defeated.has(index):
			defeated.append(index)
	var saved = int(config.get_value("skins", "selected", 0))
	selected = saved if is_unlocked(saved) else 0

func save_preferences() -> Error:
	var config = ConfigFile.new()
	config.set_value("skins", "version", SAVE_VERSION)
	config.set_value("skins", "defeated", defeated)
	config.set_value("skins", "selected", selected)
	return config.save(config_path)
