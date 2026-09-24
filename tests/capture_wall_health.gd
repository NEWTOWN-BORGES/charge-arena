extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://preview-wall-health-" + name + ".png")
func run() -> void:
	root.size = Vector2i(540, 960)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	if root.focus_exited.is_connected(game.pause_pve): root.focus_exited.disconnect(game.pause_pve)
	game.game_settings.config_path = "res://tests/feedback-capture.tmp"
	game.set_process(false)
	game.set_physics_process(false)
	game.mode = "pve"
	game.rules.phase = "play"
	game.hud.show_game("pve", 0)
	game.change_feedback(1, true, false, 0.85)
	game.hud.set_process(false)
	game.arena.set_quality(2)
	game.rules.shoot(0)
	game.rules.shoot(1)
	game.arena.update_state(game.rules, 0, 0.016)
	game.play_events()
	game.hud.update_match(game.rules, "")
	game.rules.bricks[0].hp -= 1
	game.rules.bricks[40].hp += 2
	game.hud.update_match(game.rules, "")
	game.hud._process(0.18)
	await capture("manual-portrait")
	var hit: Dictionary = game.rules.bricks.filter(func(b): return b.team == 1)[4]
	game.arena.impact_feedback({"kind": "brick", "p": hit.p, "team": 1, "heading": Vector2.UP, "defense_open": true})
	game.hud.defense_notice = "DEFESA ABERTA — ATACA A BALIZA!"
	game.hud.defense_notice_time = 1.0
	game.arena.update_state(game.rules, 0, 0.08)
	game.hud.queue_redraw()
	await capture("break")
	game.hud.open_video()
	await capture("options")
	game.hud.close_video()
	root.size = Vector2i(960, 540)
	await process_frame
	game.fit_content_scale()
	game.hud.layout()
	game.frame_arena()
	await capture("manual-landscape")
	game.queue_free()
	await process_frame
	quit()
