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
var camera_feedback = 1
var haptics = true
var auto_fire = true
var fire_control = 0
var fire_size = 1.0
var fire_x = 0.95
var fire_y = 0.99
var sfx_volume = 0.85

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
	camera_feedback = clampi(int(config.get_value("game", "camera_feedback", 1)), 0, 2)
	haptics = bool(config.get_value("game", "haptics", true))
	auto_fire = bool(config.get_value("game", "auto_fire", true))
	fire_control = clampi(int(config.get_value("game", "fire_control", 0)), 0, 1)
	fire_size = clampf(float(config.get_value("game", "fire_size", 1.0)), 0.7, 1.5)
	fire_x = clampf(float(config.get_value("game", "fire_x", 0.95)), 0.0, 1.0)
	fire_y = clampf(float(config.get_value("game", "fire_y", 0.99)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value("game", "sfx_volume", 0.85)), 0.0, 1.0)

func save_preferences() -> Error:
	var config = ConfigFile.new()
	config.set_value("game", "difficulty", difficulty)
	config.set_value("game", "aim_guide", aim_guide)
	config.set_value("game", "aim_assist", aim_assist)
	config.set_value("game", "joystick_sensitivity", joystick_sensitivity)
	config.set_value("game", "camera_feedback", camera_feedback)
	config.set_value("game", "haptics", haptics)
	config.set_value("game", "auto_fire", auto_fire)
	config.set_value("game", "sfx_volume", sfx_volume)
	config.set_value("game", "fire_control", fire_control)
	config.set_value("game", "fire_size", fire_size)
	config.set_value("game", "fire_x", fire_x)
	config.set_value("game", "fire_y", fire_y)
	return config.save(config_path)

func sensitivity_scale() -> float:
	return SENSITIVITY_SCALES[joystick_sensitivity]
