extends SceneTree
# The Sentinela's singularity, caught at three moments: the hole opening, the collapse at
# its tightest with the shots crawling in, and the release (needs a GPU; omit --headless).
const TMP = "res://tests/singularity-fx.tmp"

func _initialize() -> void:
	call_deferred("run")

func capture(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	print("SCREENSHOT ", path, " result=", root.get_texture().get_image().save_png("res://" + path))

func run() -> void:
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.power_shop.config_path = TMP
	await create_timer(0.8).timeout
	game.start_pve()
	game.pause_ai = true
	await create_timer(1.4).timeout
	game.rules.phase = "play"
	game.rules.loadouts[0] = ["blast", "air", "singularity"]
	game.rules.powers[0].charge[2] = game.rules.power_charge_cost(0, 2)
	game.rules.activate_power(0, 2)
	# A field full of shots, so the collapse has plenty to drag in.
	for spot in [Vector2(-3.4, 1.2), Vector2(2.8, -1.6), Vector2(-1.2, -3.2), Vector2(3.6, 2.4), Vector2(0.6, 3.4), Vector2(-2.6, 3.0)]:
		game.rules.balls.append({"id": game.rules.next_id, "owner": game.rules.next_id % 2, "p": spot,
			"v": Vector2(game.Rules.BALL_SPEED, 0), "bounces": 0, "boosted": false, "damage": 1,
			"ttl": game.Rules.BALL_LIFE, "power": 0, "ghost": false})
		game.rules.next_id += 1
	# Three moments: the first wave breaking, the last one closing, and the release itself.
	await create_timer(game.Rules.ULTIMATE_WINDUP + 0.22).timeout
	await capture("preview-fx-singularity-open.png")
	await create_timer(game.Rules.SINGULARITY_PULL * 0.78 - 0.22).timeout
	await capture("preview-fx-singularity-draw.png")
	await create_timer(game.Rules.SINGULARITY_PULL * 0.22 + 0.07).timeout
	await capture("preview-fx-singularity-burst.png")
	await create_timer(0.6).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	quit(0)
