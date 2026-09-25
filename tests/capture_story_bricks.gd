extends SceneTree
# Story match bricks, as the phone draws them (needs a GPU; omit --headless).

func _initialize() -> void:
	call_deferred("run")

func capture(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	print("SCREENSHOT ", path, " result=", root.get_texture().get_image().save_png("res://" + path))

func report(game, tag: String) -> void:
	var arena = game.arena
	var shown = 0
	var collapsed = 0
	for i in range(game.rules.bricks.size()):
		if not game.rules.bricks[i].alive:
			continue
		if arena.brick_nodes[i].visible:
			shown += 1
		for binding in arena.brick_instances[i]:
			if not is_instance_valid(binding.part) or not binding.part.is_visible_in_tree():
				continue
			if binding.batch.get_instance_transform(binding.slot).basis.get_scale().x < 0.001:
				collapsed += 1
	var live_batches = 0
	for b in arena.brick_batches:
		if is_instance_valid(b) and not b.is_queued_for_deletion():
			live_batches += 1
	print("BRICKS ", tag, " alive=", game.rules.brick_count(0) + game.rules.brick_count(1), " shown=", shown, " collapsed_parts=", collapsed, " batches=", live_batches, "/", arena.brick_batches.size(), " nodes=", arena.brick_nodes.size())

func run() -> void:
	root.size = Vector2i(720, 1440)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.campaign.config_path = "res://tests/story-bricks-campaign.tmp"
	game.skins.config_path = "res://tests/story-bricks-skins.tmp"
	game.power_shop.config_path = "res://tests/story-bricks-powers.tmp"
	game.cup.path = "res://tests/story-bricks-cup.tmp"
	game.cup.seed_value = 31337
	game.cup.reset()
	game.sync_story()
	await create_timer(1.0).timeout
	game.start_cup()
	game.pause_ai = true
	await create_timer(0.5).timeout
	report(game, "start")
	await create_timer(4.0).timeout
	report(game, "play")
	await capture("preview-story-bricks.png")
	for f in ["story-bricks-campaign.tmp", "story-bricks-skins.tmp", "story-bricks-powers.tmp", "story-bricks-cup.tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("res://tests/" + f))
	quit(0)
