extends Node
## Gun feel: the one place that knows how a shot, an impact, a broken brick and a goal
## should feel. The rules decide what happened - deterministically, on the host - and
## nothing here ever reads back into them. This only decides how the moment is told:
## how far the gun kicks, how long the flash lasts, how hard the phone buzzes.
##
## Every feedback system listens to the same events instead of being called one by one:
##   weapon_fired      a shot left a barrel (or, on a PvP guest, the tap that will be one)
##   projectile_impact a round met a surface: brick, metal, shield, wall or booster
##   brick_destroyed   a brick went (last_brick: the one that opens the goal)
##   goal_scored       the payoff
signal weapon_fired(info: Dictionary)
signal projectile_impact(info: Dictionary)
signal brick_destroyed(info: Dictionary)
signal goal_scored(info: Dictionary)

const CONFIG_PATH = "user://combat_feel.cfg"
# name: [default, min, max, step, caption]. Times in seconds; strengths are multipliers
# unless the caption says otherwise.
const PARAMS = {
	"fire_recoil_strength": [1.0, 0.0, 2.0, 0.05, "Recuo da arma · força"],
	"fire_recoil_duration": [0.065, 0.03, 0.12, 0.005, "Recuo · tempo até ao pico (s)"],
	"fire_return_duration": [0.15, 0.08, 0.3, 0.01, "Recuo · regresso (s)"],
	"camera_fire_strength": [1.0, 0.0, 3.0, 0.05, "Câmara · disparo"],
	"camera_destroy_strength": [1.0, 0.0, 3.0, 0.05, "Câmara · destruição"],
	"camera_goal_strength": [1.0, 0.0, 2.0, 0.05, "Câmara · golo"],
	"haptic_fire_strength": [0.14, 0.0, 0.5, 0.01, "Vibração · disparo (amplitude)"],
	"trail_length": [1.0, 0.3, 2.0, 0.05, "Rasto do projétil · comprimento"],
	"impact_particle_amount": [1.0, 0.0, 2.0, 0.1, "Partículas · impacto"],
	"destruction_particle_amount": [1.0, 0.0, 2.0, 0.1, "Partículas · destruição"],
	"audio_pitch_variation": [0.025, 0.0, 0.08, 0.005, "Som · variação de tom (±)"],
	"muzzle_flash_duration": [0.05, 0.02, 0.1, 0.005, "Clarão do cano · duração (s)"],
	"light_flash_duration": [0.05, 0.0, 0.08, 0.005, "Luz do disparo · duração (s)"],
	"hitstop_destroy": [0.028, 0.0, 0.06, 0.002, "Micro-pausa · tijolo (s)"],
	"hitstop_last_brick": [0.05, 0.0, 0.1, 0.005, "Micro-pausa · último tijolo (s)"],
	"hitstop_goal": [0.09, 0.0, 0.2, 0.01, "Micro-pausa · golo (s)"],
}
# The hierarchy. Each moment has a level, and the level decides how far it may reach:
# which sounds it may push aside, how hard the camera and the hand feel it. A ricochet is
# told the least - bouncing a shot off a wall is not what the game rewards.
const LEVELS = {
	"ambient": 0,
	"ricochet": 1,
	"shot": 2,
	"brick_hit": 3,
	"brick": 4,
	"power": 5,
	"ultimate": 6,
	"last_brick": 6,
	"goal": 7,
}
# Haptic categories: [milliseconds, amplitude]. FIRE takes its amplitude from the tuning.
const HAPTICS = {
	"fire": [9, -1.0],
	"destroy": [16, 0.24],
	"last_brick": [30, 0.42],
	"power": [22, 0.30],
	"ultimate": [42, 0.55],
	"goal": [70, 0.80],
}
# Who is pushed aside when a big moment speaks: [duck below this level, dB, seconds].
const DUCKING = {
	"brick": [2, -2.0, 0.08],
	"last_brick": [5, -5.0, 0.25],
	"ultimate": [6, -4.5, 0.18],
	"goal": [7, -8.0, 1.1],
}
# Camera shake per moment: [intensity, seconds, frequency Hz, directional share].
# Intensity is in arena units at the camera; the directional share is how much of it is
# a push along the event's direction rather than a wobble.
const SHAKES = {
	"shot": [0.022, 0.09, 24.0, 0.9],
	"brick_hit": [0.02, 0.08, 30.0, 0.6],
	"brick": [0.075, 0.16, 26.0, 0.55],
	"last_brick": [0.15, 0.28, 20.0, 0.5],
	"power": [0.14, 0.22, 18.0, 0.2],
	"goal": [0.42, 0.75, 11.0, 0.35],
}

var config_path = CONFIG_PATH
var values: Dictionary = {}
# Accessibility: fewer particles, no light flashes, no micro-pauses.
var effects_reduced = false
# The last measured shot, for the tuning panel. -1 = not measured yet.
var latency = {"input_to_spawn_ms": -1.0, "spawn_to_frame_ms": -1.0, "audio_output_ms": -1.0, "input_to_frame_ms": -1.0}
var input_usec = 0
var waiting_frame = false
var spawn_usec = 0

func _init() -> void:
	reset()

static func default_of(name: String) -> float:
	return float(PARAMS[name][0]) if PARAMS.has(name) else 0.0

func value(name: String) -> float:
	return float(values.get(name, default_of(name)))

func set_value(name: String, v: float) -> void:
	if not PARAMS.has(name):
		return
	values[name] = clampf(v, float(PARAMS[name][1]), float(PARAMS[name][2]))

func reset() -> void:
	values.clear()
	for name in PARAMS.keys():
		values[name] = default_of(name)

func load_preferences() -> void:
	var config = ConfigFile.new()
	if config.load(config_path) != OK:
		return
	for name in PARAMS.keys():
		set_value(name, float(config.get_value("tuning", name, default_of(name))))
	effects_reduced = bool(config.get_value("access", "effects_reduced", false))

func save_preferences() -> Error:
	var config = ConfigFile.new()
	for name in PARAMS.keys():
		config.set_value("tuning", name, value(name))
	config.set_value("access", "effects_reduced", effects_reduced)
	return config.save(config_path)

static func level_of(kind: String) -> int:
	return int(LEVELS.get(kind, 2))

func haptic_for(kind: String) -> Vector2:
	# x = milliseconds, y = amplitude; zero when this category does not buzz.
	if not HAPTICS.has(kind):
		return Vector2.ZERO
	var entry: Array = HAPTICS[kind]
	var amplitude = value("haptic_fire_strength") if float(entry[1]) < 0.0 else float(entry[1])
	return Vector2(float(entry[0]), amplitude) if amplitude > 0.0 else Vector2.ZERO

func hitstop_for(kind: String) -> float:
	if effects_reduced:
		return 0.0
	match kind:
		"brick": return value("hitstop_destroy")
		"last_brick": return value("hitstop_last_brick")
		"goal": return value("hitstop_goal")
	return 0.0

func pitch() -> float:
	var spread = value("audio_pitch_variation")
	return 1.0 + randf_range(-spread, spread)

# --- Latency probe -------------------------------------------------------------------
# input (touch/click arrives) -> spawn (the shot event is presented) -> first frame drawn
# with it. Audio adds the output buffer on top of the spawn moment.

func mark_input() -> void:
	input_usec = Time.get_ticks_usec()

func mark_spawn() -> void:
	var now = Time.get_ticks_usec()
	spawn_usec = now
	if input_usec > 0:
		latency.input_to_spawn_ms = (now - input_usec) / 1000.0
	latency.audio_output_ms = AudioServer.get_output_latency() * 1000.0
	if not waiting_frame and is_inside_tree() and DisplayServer.get_name() != "headless":
		waiting_frame = true
		RenderingServer.frame_post_draw.connect(frame_drawn, CONNECT_ONE_SHOT)

func frame_drawn() -> void:
	waiting_frame = false
	var now = Time.get_ticks_usec()
	latency.spawn_to_frame_ms = (now - spawn_usec) / 1000.0
	if input_usec > 0:
		latency.input_to_frame_ms = (now - input_usec) / 1000.0
	input_usec = 0

# --- The events ------------------------------------------------------------------------

func fire(info: Dictionary) -> void:
	if bool(info.get("local", false)):
		mark_spawn()
	weapon_fired.emit(info)

func impact(info: Dictionary) -> void:
	projectile_impact.emit(info)

func destroyed(info: Dictionary) -> void:
	brick_destroyed.emit(info)

func goal(info: Dictionary) -> void:
	goal_scored.emit(info)

static func material_of(event: Dictionary) -> String:
	# The surface a round met, in the language the feedback speaks: a brick answers THOCK,
	# metal TANG with sparks, a shield BWOM with a ripple, a plain wall a dry tap, a booster
	# its own gold kick.
	var kind = String(event.get("kind", ""))
	if kind in ["brick", "brick_hit"]:
		return "shield" if event.get("soaked", false) else "brick"
	if kind in ["player_hit", "mirror"]:
		return "shield"
	var surface = String(event.get("surface", "wall"))
	if surface == "obstacle" or surface == "turret":
		return "metal"
	if surface == "boost":
		return "boost"
	return "wall"
