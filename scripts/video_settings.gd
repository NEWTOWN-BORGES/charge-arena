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
	low_windows = 0
	stable_windows = 0

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
	runtime_fps = fps
	runtime_scale = RENDER_SCALES[quality]
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

func adapt(viewport: Viewport, measured_fps: float, force_mobile: bool = false) -> bool:
	if (not OS.has_feature("mobile") and not force_mobile) or fps < 60:
		return false
	var expected = float(runtime_fps)
	if measured_fps < expected * 0.84:
		low_windows += 1
		stable_windows = 0
	else:
		low_windows = 0
		stable_windows += 1
	var required_windows = 4 if quality > 0 else 2
	if low_windows < required_windows:
		return false
	low_windows = 0
	# Equilibrado and Refinado preserve their exact visual profile and give up frames
	# instead: 90 -> 60 -> 30. With 120 gone from the options, the ladder reaches all the
	# way down rather than stopping at 60 on a phone that cannot hold it.
	if quality > 0:
		if runtime_fps > 60:
			runtime_fps = 60
		elif runtime_fps > 30:
			runtime_fps = 30
		else:
			return false
		Engine.max_fps = runtime_fps
		return true
	# Leve is the performance profile for weaker phones and may lower its 3D
	# resolution before using a stable 45/30 FPS fallback.
	var minimum = MIN_RENDER_SCALES[quality]
	if runtime_scale > minimum + 0.01:
		runtime_scale = maxf(minimum, runtime_scale - 0.08)
		viewport.scaling_3d_scale = runtime_scale
		return true
	if runtime_fps > 45:
		# 45 divides a 90 Hz display evenly. On a 60 Hz panel it causes uneven
		# pacing, so go straight to the stable 30 FPS fallback.
		var refresh_rate = DisplayServer.screen_get_refresh_rate()
		runtime_fps = 45 if refresh_rate >= 85.0 else 30
	elif runtime_fps > 30:
		runtime_fps = 30
	else:
		return false
	Engine.max_fps = runtime_fps
	return true
