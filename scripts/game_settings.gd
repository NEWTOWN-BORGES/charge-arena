extends RefCounted
## Gameplay preferences on this device: AI, aiming guide and stick response.
const CONFIG_PATH = "user://game_settings.cfg"
const DIFFICULTIES = ["FÁCIL", "NORMAL", "DIFÍCIL"]
const SENSITIVITY_NAMES = ["MUITO LENTA", "LENTA", "NORMAL", "RÁPIDA", "MUITO RÁPIDA"]
const SENSITIVITY_SCALES = [0.55, 0.75, 1.0, 1.2, 1.45]
var config_path = CONFIG_PATH
var difficulty = 1
var aim_guide = true
var aim_assist = true
var joystick_sensitivity = 2

func configure(level: int, guide: bool, sensitivity: int = -1) -> void:
	difficulty = clampi(level, 0, DIFFICULTIES.size() - 1)
	aim_guide = guide
	if sensitivity >= 0:
		joystick_sensitivity = clampi(sensitivity, 0, SENSITIVITY_NAMES.size() - 1)

func load_preferences() -> void:
	var config = ConfigFile.new()
	if config.load(config_path) != OK:
		return
	configure(int(config.get_value("game", "difficulty", 1)), bool(config.get_value("game", "aim_guide", true)), int(config.get_value("game", "joystick_sensitivity", 2)))
	aim_assist = bool(config.get_value("game", "aim_assist", true))

func save_preferences() -> Error:
	var config = ConfigFile.new()
	config.set_value("game", "difficulty", difficulty)
	config.set_value("game", "aim_guide", aim_guide)
	config.set_value("game", "aim_assist", aim_assist)
	config.set_value("game", "joystick_sensitivity", joystick_sensitivity)
	return config.save(config_path)

func sensitivity_scale() -> float:
	return SENSITIVITY_SCALES[joystick_sensitivity]
