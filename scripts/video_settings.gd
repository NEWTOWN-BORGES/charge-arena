extends RefCounted
## Local display preferences; never change the authoritative 60 Hz simulation.
const FPS_OPTIONS = [30, 60, 90]
const QUALITY_NAMES = ["Leve", "Equilibrado", "Refinado"]
# Compatibility does not support screen-space FXAA. Use actual MSAA for silhouettes.
const AA_LEVELS = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_8X]
const SCREEN_AA = [Viewport.SCREEN_SPACE_AA_DISABLED, Viewport.SCREEN_SPACE_AA_DISABLED, Viewport.SCREEN_SPACE_AA_DISABLED]
const EFFECT_LIMITS = [20, 48, 96]
# Leve targets budget phones (Galaxy A15): 0.72x keeps text readable while
# halving pixel throughput vs native.  Refinado stays at 1.0 for flagship feel.
const RENDER_SCALES = [0.72, 0.88, 1.0]
const MIN_RENDER_SCALES = [0.50, 0.62, 0.72]
const CONFIG_PATH = "user://video_settings.cfg"
const AUTO_NOTE = "Para manter os FPS escolhidos, o telemóvel baixa primeiro o antialiasing e a resolução 3D, e só depois os FPS. Volta a subir sozinho quando o jogo estabiliza."
var fps = 60
# A phone starts on the performance profile; a PC has no reason to.
var quality = 2 if OS.has_feature("open_test") else (0 if OS.has_feature("mobile") else 2)
var vsync = true
var show_fps = false
var runtime_scale = 0.72
var runtime_fps = 60
var smooth_hud = true
var low_windows = 0
var stable_windows = 0
# The automatic adjustment: how far down the ladder of cheaper steps it has gone.
const GRACE_WINDOWS = 3
const RECOVER_WINDOWS = 40
const MAX_RECOVER_WINDOWS = 240
var ladder: Array = []
var level = 0
var runtime_msaa = Viewport.MSAA_8X
var recover_after = RECOVER_WINDOWS
var since_raise = -1
var grace = 0
# The screen's own refresh rate when that, and not the phone, is what holds the frames down.
var panel_cap = 0
# The arena being drawn, so a step of the ladder can switch its shadows off.
var arena_ref = null
var runtime_shadows = true

func load_preferences(path: String = CONFIG_PATH) -> void:
	var config = ConfigFile.new()
	if config.load(path) != OK:
		return
	var saved_quality = int(config.get_value("video", "quality", 0))
	# Existing Android installs used a much heavier profile. Migrate once so an
	# update cannot preserve the setting that caused stalls on entry-level phones.
	if OS.has_feature("mobile") and int(config.get_value("video", "performance_version", 0)) < 2:
		saved_quality = 0
	if OS.has_feature("open_test") and int(config.get_value("video", "presentation_version", 0)) < 3:
		saved_quality = 2
	configure(int(config.get_value("video", "fps", 60)), saved_quality, bool(config.get_value("video", "vsync", true)), bool(config.get_value("video", "show_fps", false)))

func configure(new_fps: int, new_quality: int, sync: bool, counter: bool) -> void:
	# A setting saved by an older build may still say 120; it lands on 60.
	fps = new_fps if new_fps in FPS_OPTIONS else 60
	quality = clampi(new_quality, 0, QUALITY_NAMES.size() - 1)
	vsync = sync
	show_fps = counter
	runtime_scale = RENDER_SCALES[quality]
	runtime_fps = fps
	reset_adjustment()

func reset_adjustment() -> void:
	low_windows = 0
	stable_windows = 0
	ladder = []
	level = 0
	recover_after = RECOVER_WINDOWS
	since_raise = -1
	grace = GRACE_WINDOWS
	panel_cap = 0

func save_preferences(path: String = CONFIG_PATH) -> Error:
	var config = ConfigFile.new()
	config.set_value("video", "fps", fps)
	config.set_value("video", "quality", quality)
	config.set_value("video", "vsync", vsync)
	config.set_value("video", "show_fps", show_fps)
	config.set_value("video", "performance_version", 2)
	config.set_value("video", "presentation_version", 3)
	return config.save(path)

func apply(viewport: Viewport, arena) -> void:
	arena_ref = arena
	runtime_shadows = true
	runtime_fps = fps
	runtime_scale = RENDER_SCALES[quality]
	runtime_msaa = AA_LEVELS[quality]
	reset_adjustment()
	Engine.max_fps = runtime_fps
	viewport.msaa_3d = AA_LEVELS[quality]
	viewport.screen_space_aa = SCREEN_AA[quality]
	viewport.use_debanding = quality > 0
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = runtime_scale
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	arena.effect_limit = EFFECT_LIMITS[quality]
	# The light profile drops per-primitive antialiasing in the HUD: on a mid-range phone
	# those 182 soft edges were more than half of the draw calls in a frame.
	smooth_hud = quality > 0
	arena.trail_interval = [0.11, 0.06, 0.035][quality]
	arena.set_quality(quality)

func adapt(viewport: Viewport, measured_fps: float, force_mobile: bool = false, refresh_rate: float = -2.0) -> bool:
	# Keeps the frame rate the player chose. When the phone cannot hold it, the picture gives
	# way first - MSAA, then 3D resolution - and only then the frame rate. And it climbs back:
	# after a stretch of steady play it tries the step above again, so one hitch (a shader
	# compiling the first time an ultimate goes off) no longer leaves the game at 30 for good.
	if (not OS.has_feature("mobile") and not force_mobile) or fps < 60:
		return false
	var refresh: float = DisplayServer.screen_get_refresh_rate() if refresh_rate == -2.0 else refresh_rate
	if panel_cap > 0 and refresh > panel_cap + 5.0:
		# The screen went faster (an adaptive panel picking a higher mode): lift the cap.
		panel_cap = 0
		ladder = build_ladder(refresh)
		level = 0
		use_step(viewport)
		return true
	if ladder.is_empty():
		ladder = build_ladder(refresh)
	if grace > 0:
		# The counter averages the last second, so right after a change it still reports the
		# frames from before it.
		grace -= 1
		return false
	var expected = float(ladder[level][2])
	if measured_fps < expected * 0.84 and panel_cap == 0 and refresh > 0 and refresh < expected - 1.0 and absf(measured_fps - refresh) <= 3.0:
		# Running at exactly the screen's rate: it is the panel that stops at 60, not the
		# phone. No picture it gives up would show one more frame, so none is given up.
		panel_cap = roundi(refresh)
		ladder = build_ladder(refresh)
		level = 0
		use_step(viewport)
		return true
	if measured_fps < expected * 0.84:
		low_windows += 1
		stable_windows = 0
	else:
		low_windows = 0
		stable_windows += 1
		if since_raise >= 0:
			since_raise += 1
			if since_raise >= RECOVER_WINDOWS:
				# The step up held: the next one is tried at the normal pace again.
				since_raise = -1
				recover_after = RECOVER_WINDOWS
	var required_windows = 4 if quality > 0 else 2
	if low_windows >= required_windows:
		low_windows = 0
		if level >= ladder.size() - 1:
			return false
		if since_raise >= 0:
			# It went up and could not stay there: wait twice as long before the next try.
			recover_after = mini(recover_after * 2, MAX_RECOVER_WINDOWS)
			since_raise = -1
		level += 1
		use_step(viewport)
		return true
	if level > 0 and stable_windows >= recover_after:
		level -= 1
		since_raise = 0
		use_step(viewport)
		return true
	return false

func build_ladder(refresh_rate: float) -> Array:
	# Each step is [MSAA, 3D scale, frame limit, shadows]; the first is the profile as chosen.
	var msaa = AA_LEVELS[quality]
	var scale = RENDER_SCALES[quality]
	var top: int = mini(fps, panel_cap) if panel_cap > 0 else fps
	var shadows: bool = quality == 2
	var steps: Array = [[msaa, scale, top, shadows]]
	if shadows:
		# Real shadows are the heaviest thing Refinado draws - every solid piece a second
		# time - and the first thing given up; the painted contact shadows stay.
		shadows = false
		steps.append([msaa, scale, top, shadows])
	if msaa == Viewport.MSAA_8X:
		# The dearest thing on a phone's tiled GPU after shadows, and least missed at a glance.
		msaa = Viewport.MSAA_4X
		steps.append([msaa, scale, top, shadows])
		msaa = Viewport.MSAA_2X
		steps.append([msaa, scale, top, shadows])
	while scale > MIN_RENDER_SCALES[quality] + 0.01:
		scale = maxf(MIN_RENDER_SCALES[quality], scale - 0.08)
		steps.append([msaa, scale, top, shadows])
	if top > 60:
		steps.append([msaa, scale, 60, shadows])
	# 45 divides a 90 Hz panel evenly; on a 60 Hz one it paces unevenly, so it is skipped.
	if top > 45 and refresh_rate >= 85.0:
		steps.append([msaa, scale, 45, shadows])
	if top > 30:
		steps.append([msaa, scale, 30, shadows])
	return steps

func use_step(viewport: Viewport) -> void:
	var step: Array = ladder[level]
	runtime_msaa = step[0]
	runtime_scale = step[1]
	runtime_fps = step[2]
	runtime_shadows = step[3]
	if arena_ref != null and is_instance_valid(arena_ref) and arena_ref.has_method("set_shadows"):
		arena_ref.set_shadows(runtime_shadows)
	viewport.msaa_3d = runtime_msaa
	viewport.scaling_3d_scale = runtime_scale
	Engine.max_fps = runtime_fps
	low_windows = 0
	stable_windows = 0
	grace = GRACE_WINDOWS

func hold() -> void:
	# Play resumed after a pause or a countdown: ignore the next readings, which still
	# carry the resting frame rate.
	grace = GRACE_WINDOWS
	low_windows = 0

func adjusted() -> bool:
	return level > 0
