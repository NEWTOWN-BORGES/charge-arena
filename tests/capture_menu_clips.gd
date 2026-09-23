extends SceneTree
# Films the six short loops that would sit behind the swipe menu, one per page. Needs a
# GPU, so run it without --headless. Frames land as PNGs in the folder given by --frames.
#
# ON HOLD. The menu uses live 3D behind each page, not video. This rig is kept because the
# filming works and only the encoding does not: the libtheora in the ffmpeg build on this
# machine writes corrupt Ogg Theora at every setting tried - high quality, low quality,
# fixed bitrate, through yuv4mpeg, at macroblock-aligned sizes, and with the alpha channel
# stripped. Godot plays those files but they come out full of block noise. Godot 4 reads no
# other video format without a plugin, so the video path waits for a working encoder.
#
# When one turns up: run this, then
#   ffmpeg -framerate 30 -i <dir>/<page>/%04d.png -c:v libtheora -q:v 6 -an video/menu/<page>.ogv
# and check the result decodes cleanly before trusting it. One thing still to fix first:
# these clips film the whole screen, HUD included. A menu background wants the arena alone.
const TMP = "res://tests/menu-clips.tmp"
const FPS = 30
const SECONDS = 2.5

var out_dir := ""
var game

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--frames="):
			out_dir = argument.substr(9)
	if out_dir == "":
		out_dir = OS.get_user_data_dir() + "/menu-clips"
	DirAccess.make_dir_recursive_absolute(out_dir)
	call_deferred("run")

func film(page: String) -> void:
	# One clip: every frame of it, at a fixed step, so the encoder gets an even cadence.
	DirAccess.make_dir_recursive_absolute(out_dir + "/" + page)
	for frame in range(int(FPS * SECONDS)):
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s/%04d.png" % [out_dir, page, frame])
	print("CLIP ", page, " frames=", int(FPS * SECONDS))

func settle(seconds: float) -> void:
	await create_timer(seconds).timeout

func playing() -> void:
	# The rival stands still and the local pilot walks and fires, so every clip has motion
	# without the match actually being decided while it is filmed.
	game.pause_ai = true
	game.rules.phase = "play"

func run() -> void:
	root.size = Vector2i(540, 1200)
	Engine.max_fps = FPS
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.power_shop.config_path = TMP
	await settle(1.0)

	# 1. Campanha: the first level, mid-rally.
	game.start_level(0)
	await settle(1.4)
	playing()
	await settle(0.6)
	await film("campanha")

	# 2. Modo Historia: a station pilot, which is what that mode is made of.
	game.start_level(11)
	await settle(1.4)
	playing()
	await settle(0.6)
	await film("historia")

	# 3. Jogo Rapido: the tall arena, leaning.
	game.return_to_menu()
	await settle(0.4)
	game.start_pve()
	await settle(1.4)
	playing()
	await settle(0.6)
	await film("rapido")

	# 4. PvP: the colosseum, both walls up.
	game.return_to_menu()
	await settle(0.4)
	game.start_pvp_ai()
	await settle(1.6)
	playing()
	await settle(0.6)
	await film("pvp")

	# 5. Skins: the equipped pilot turning on its pedestal.
	game.return_to_menu()
	await settle(0.4)
	game.hud.open_skins()
	game.hud.preview_skin(10)
	await settle(1.0)
	await film("skins")
	game.hud.close_skins()

	# 6. Poderes: a storm going off, which is the loudest thing the kit does.
	await settle(0.3)
	game.start_pve()
	await settle(1.4)
	playing()
	game.rules.loadouts[0] = ["blast", "air", "thunder"]
	game.rules.powers[0].charge[2] = game.rules.power_charge_cost(0, 2)
	game.rules.activate_power(0, 2)
	await settle(game.Rules.ULTIMATE_WINDUP - 0.2)
	await film("poderes")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	print("CLIPS_DONE dir=", out_dir)
	quit(0)
