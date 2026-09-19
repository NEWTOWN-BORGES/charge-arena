extends SceneTree
# Campaign: eleven playable arenas with their own boss, progression that unlocks level by
# level, the end-of-level flow, and a menu whose main actions sit under the thumb.
const Rules = preload("res://scripts/arena_rules.gd")
const Campaign = preload("res://scripts/campaign.gd")
const TMP = "res://tests/campaign-progress.tmp"
var failures = 0

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: ", description)

func _initialize() -> void:
	call_deferred("run")

func brick_corners(brick: Dictionary) -> Array:
	var corners = []
	for c in [Vector2(-0.27, -0.14), Vector2(0.27, -0.14), Vector2(0.27, 0.14), Vector2(-0.27, 0.14)]:
		corners.append(brick.p + c.rotated(brick.rotation))
	return corners

func layout_problems(r) -> Array:
	var problems: Array = []
	if r.bricks.size() != 80 or r.bricks.filter(func(b): return b.team == 0).size() != 40:
		problems.append("40 bricks per team")
	for brick in r.bricks:
		if not brick_corners(brick).all(func(c): return Rules.point_inside(r.walls, c)):
			problems.append("brick %d outside the walls" % brick.id)
	for i in range(r.bricks.size()):
		for j in range(i + 1, r.bricks.size()):
			if r.bricks[i].p.distance_to(r.bricks[j].p) < 0.27:
				problems.append("bricks %d and %d overlap" % [i, j])
	for index in range(r.obstacles.size()):
		var radius: float = r.obstacles[index].radius
		for step in range(160):
			var at: Vector2 = r.obstacle_at(index, step * 0.08)
			if not Rules.point_inside(r.walls, at):
				problems.append("obstacle %d leaves the arena" % index)
			if r.bricks.any(func(b): return at.distance_to(b.p) < radius + 0.4):
				problems.append("obstacle %d runs into bricks" % index)
			for team in range(2):
				for k in range(9):
					if at.distance_to(Rules.track_position(team, lerpf(-Rules.TRACK_LIMIT, Rules.TRACK_LIMIT, k / 8.0))) < radius + 0.6:
						problems.append("obstacle %d crosses a pilot's arc" % index)
			for barrier in r.barriers:
				if at.distance_to(Geometry2D.get_closest_point_to_segment(at, barrier.a, barrier.b)) < radius + Rules.BARRIER_RADIUS + 0.2:
					problems.append("obstacle %d hits a barrier" % index)
	for barrier in r.barriers:
		if r.bricks.any(func(b): return b.p.distance_to(Geometry2D.get_closest_point_to_segment(b.p, barrier.a, barrier.b)) < 0.5):
			problems.append("barrier touches bricks")
	return problems

func run() -> void:
	var levels: Array = Campaign.LEVELS
	var ids = levels.map(func(l): return l.map.id)
	check(levels.size() == 11 and ids.all(func(id): return ids.count(id) == 1), "Eleven levels, each on its own arena")
	check(levels[0].boss == 0 and levels[1].boss == 6 and levels[10].boss == 10, "Level 1 trains against a copy of the standard pilot, level 2 meets the Relojoeiro and the Arconte closes the campaign")
	var bosses = levels.slice(1).map(func(l): return l.boss)
	check(bosses.size() == 10 and bosses.all(func(b): return bosses.count(b) == 1), "Every boss skin has a level of its own")
	check(levels.all(func(l): return l.boss >= 0 and l.boss <= 10 and l.challenge != "" and l.tag != ""), "Every level names its challenge and a valid boss skin")
	check(range(1, 11).all(func(i): return levels[i].tier > levels[i - 1].tier), "Bosses get stronger level by level")
	var outlines = levels.map(func(l): return l.map.outline)
	var layouts = levels.map(func(l): return l.map.bricks)
	check(["hex", "octagon", "pinch", "wide"].all(func(o): return outlines.has(o)) and ["banks", "wall", "arc", "islands", "chevron"].all(func(b): return layouts.has(b)), "Maps mix four outlines and five brick layouts")
	var kinds: Array = []
	for level in levels:
		for spec in level.map.obstacles:
			kinds.append(spec.kind)
	check(kinds.has("fixed") and kinds.has("slide") and kinds.has("orbit") and levels.any(func(l): return not l.map.barriers.is_empty()), "Challenges use fixed pillars, sliders, orbits and inner barriers")

	for index in range(levels.size()):
		var r = Rules.new()
		r.set_map(levels[index].map)
		var problems = layout_problems(r)
		check(problems.is_empty(), "Level %d layout is clean%s" % [index + 1, "" if problems.is_empty() else ": " + problems[0]])
		# Two full-strength AIs play for a while: no ball may escape and both must reach bricks.
		r.phase = "play"
		var escaped = 0
		var hits = 0
		for tick in range(60 * 12):
			var aim = r.predict_shot(0, r.players[0].angle)
			var own = {"move": Vector2(sin(tick * 0.02), 0), "fire": aim.get("kind", "") == "brick"}
			r.step(1.0 / 60, [own, r.ai_command()])
			hits += r.events.filter(func(e): return e.kind in ["brick", "brick_hit"]).size()
			escaped += r.balls.filter(func(b): return not Rules.point_inside(r.walls, b.p)).size()
			if r.phase == "goal":
				r.phase = "play"
		check(escaped == 0 and hits > 5, "Level %d plays: no ball escapes, %d brick hits in 12 s" % [index + 1, hits])

	var default_rules = Rules.new()
	var same_obstacles = range(40).all(func(t): return default_rules.obstacle_at(0, t * 0.1).is_equal_approx(Rules.obstacle_position(0, t * 0.1)) and default_rules.obstacle_at(1, t * 0.1).is_equal_approx(Rules.obstacle_position(1, t * 0.1)))
	check(default_rules.walls == Rules.WALLS and default_rules.boost_centers == Rules.booster_centers(Rules.default_map()) and default_rules.barriers.is_empty() and same_obstacles, "Quick play and PvP keep the original arena exactly")
	var first = Campaign.ai_profile(0, 1)
	var last = Campaign.ai_profile(9, 1)
	check(first.fire_gap > last.fire_gap and first.move < last.move, "The first boss fires and moves far less than the last")
	check(Campaign.ai_profile(5, 0).fire_gap > Campaign.ai_profile(5, 1).fire_gap and Campaign.ai_profile(5, 1).fire_gap > Campaign.ai_profile(5, 2).fire_gap, "FÁCIL and DIFÍCIL shift every boss")

	var testing = Campaign.new()
	check(Campaign.UNLOCK_ALL_FOR_TESTS and range(Campaign.LEVELS.size()).all(func(i): return testing.is_unlocked(i)) and testing.suggested_level() == 0, "Testing build: every level is open and the menu starts on the first unplayed one")

	# Level-by-level unlocking, as it works once the testing switch is turned off.
	var progress = Campaign.new()
	progress.unlock_all = false
	progress.config_path = TMP
	check(progress.is_unlocked(0) and not progress.is_unlocked(1) and progress.next_level() == 0, "A new player starts with level 1 only")
	check(not progress.complete(4) and progress.unlocked == 1, "Winning a locked level changes nothing")
	check(progress.complete(0) and progress.is_unlocked(1) and progress.is_completed(0), "Winning level 1 unlocks level 2")
	check(not progress.complete(0) and progress.unlocked == 2, "Replaying a won level does not skip ahead")
	check(progress.save_preferences() == OK, "Campaign progress saves")
	var restored = Campaign.new()
	restored.unlock_all = false
	restored.config_path = TMP
	restored.load_preferences()
	check(restored.unlocked == 2 and restored.completed == [0], "Progress survives a restart")
	var edited = ConfigFile.new()
	edited.set_value("campaign", "unlocked", 99)
	edited.set_value("campaign", "completed", [0, 3, 50, "x"])
	edited.save(TMP)
	restored.load_preferences()
	check(restored.unlocked == Campaign.LEVELS.size() and restored.completed == [0, 3], "An edited save is clamped")

	root.size = Vector2i(720, 1600)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await process_frame
	await process_frame
	var hud = game.hud
	game.campaign = Campaign.new()
	game.campaign.unlock_all = false
	game.campaign.config_path = TMP
	hud.sync_campaign(game.campaign)
	game.menu_level = 0
	hud.sync_menu_level(0)
	game.show_menu_preview()

	var menu_buttons = hud.menu.find_children("*", "Button", true, false).filter(func(b): return b.visible)
	var lowest = menu_buttons.reduce(func(low, b): return b if b.get_global_rect().end.y > low.get_global_rect().end.y else low)
	check(lowest == hud.campaign_button and hud.campaign_button.size.y >= 60, "CAMPANHA is the largest button and the lowest one")
	check(hud.campaign_button.get_global_rect().end.y > hud.size.y - 110, "In portrait the main action sits in the bottom thumb zone")
	check(hud.quick_button.visible and hud.campaign_button.text == "JOGAR NÍVEL 1  →", "The menu shows quick play and a button to play the previewed level")

	# Carousel: swipe the stadium sideways to browse levels; the arena follows once settled.
	var area: Rect2 = hud.swipe_area()
	var swipe = func(from: Vector2, to: Vector2):
		for pressed in [true, false]:
			var touch = InputEventScreenTouch.new()
			touch.index = 0
			touch.pressed = pressed
			touch.position = from if pressed else to
			hud._input(touch)
	var middle = area.get_center()
	swipe.call(middle + Vector2(120, 0), middle - Vector2(120, 0))
	check(game.menu_level == 1 and hud.menu_level == 1 and game.arena.map.id == "treino", "Swiping left selects the next level at once, before rebuilding")
	game._process(0.1)
	game._process(0.1)
	await process_frame
	check(game.arena.map.id == "oficina" and game.arena.unit_skins[1] == 6 and game.arena.brick_nodes[40].get_meta("skin") == 6, "The stadium then shows level 2's arena, boss and bricks")
	swipe.call(middle, middle + Vector2(30, 4))
	check(game.menu_level == 1, "A tap or short drag does not change level")
	swipe.call(middle + Vector2(0, -100), middle + Vector2(90, 120))
	check(game.menu_level == 1, "A mostly vertical drag does not change level")
	swipe.call(Vector2(hud.size.x * 0.5, hud.menu.get_rect().get_center().y), Vector2(hud.size.x * 0.5 - 200, hud.menu.get_rect().get_center().y))
	check(game.menu_level == 1, "Swipes over the menu buttons are ignored")
	swipe.call(middle - Vector2(120, 0), middle + Vector2(120, 0))
	swipe.call(middle - Vector2(120, 0), middle + Vector2(120, 0))
	check(game.menu_level == 0, "Swiping right goes back and stops at level 1")
	for i in range(13):
		game.step_menu_level(1)
	check(game.menu_level == Campaign.LEVELS.size() - 1, "Browsing stops at the last level")
	game.step_menu_level(-(Campaign.LEVELS.size() - 1))
	game._process(0.3)
	await process_frame
	check(game.arena.map.id == "treino" and hud.campaign_button.text == "JOGAR NÍVEL 1  →" and not hud.campaign_button.disabled, "Rapid browsing rebuilds only the level it settles on")
	hud.open_pvp()
	check(hud.pvp_overlay.visible and hud.ip.is_visible_in_tree(), "PvP moved to its own panel with the IP field")
	hud.close_pvp()

	hud.open_levels()
	check(hud.levels_overlay.visible and hud.level_cards.size() == Campaign.LEVELS.size(), "The level screen lists every arena")
	check(hud.levels_panel.get_rect().end.y > hud.size.y - 60, "In portrait the level list hangs from the bottom of the screen")
	hud.level_cards[3].pressed.emit()
	check(game.mode == "menu" and hud.levels_overlay.visible, "Locked levels cannot be started")
	hud.level_cards[0].pressed.emit()
	check(game.mode == "pve" and game.level_index == 0 and not hud.levels_overlay.visible and game.arena.map.id == "treino", "Level 1 starts from its card")

	game._process(0.02)
	game.rules.phase = "finished"
	game.rules.winner = 0
	game._process(0.02)
	hud.update_match(game.rules, "")
	check(game.campaign.unlocked == 2 and hud.level_result == "won" and hud.level_opened, "Winning the level unlocks the next one")
	check(hud.next_button.visible and hud.replay.visible and hud.levels_button.visible and hud.replay.text == "REPETIR NÍVEL", "The win screen offers next level, replay and the level list")
	check(hud.next_button.position.y < hud.replay.position.y and hud.replay.position.y < hud.levels_button.position.y, "Result buttons stack under the message")
	check(hud.next_button.get_theme_color("font_color") == hud.INK and hud.replay.get_theme_color("font_color") == hud.WHITE, "Only the next-level button is highlighted")

	hud.next_button.pressed.emit()
	await process_frame
	check(game.level_index == 1 and game.arena.map.id == "oficina" and game.rules.obstacles.size() == 2, "Next level rebuilds the arena with the clockwork sliders")
	check(game.arena.unit_skins == [game.skins.selected, 6] and game.arena.brick_nodes[40].get_meta("skin") == 6, "The Relojoeiro boss arrives with its own bricks")
	check(game.rules.obstacles.size() == 2 and game.arena.obstacle_nodes.size() == 2 and hud.level_info.name == "Oficina do Relógio" and hud.level_info.boss_name == "RELOJOEIRO", "Its two friendly pillars, name and boss name come with it")
	check(game.rules.ai_profile == Campaign.ai_profile(1, game.game_settings.difficulty), "The boss uses its level's pace")

	game._process(0.02)
	game.rules.phase = "finished"
	game.rules.winner = 1
	game._process(0.02)
	hud.update_match(game.rules, "")
	check(hud.level_result == "lost" and not hud.next_button.visible and hud.replay.text == "TENTAR DE NOVO" and game.campaign.unlocked == 2, "Losing offers a retry and unlocks nothing")
	hud.replay.pressed.emit()
	check(game.level_index == 1 and game.rules.phase == "countdown" and game.rules.scores == [0, 0] and hud.level_result == "", "Retry restarts the same level")

	hud.levels_button.pressed.emit()
	await process_frame
	check(game.mode == "menu" and hud.levels_overlay.visible and game.level_index == -1 and game.menu_level == 1 and game.arena.map.id == "oficina", "NÍVEIS returns to the menu previewing the level just played")
	hud.close_levels()
	hud.campaign_button.pressed.emit()
	check(game.mode == "pve" and game.level_index == 1, "JOGAR NÍVEL starts the previewed level")
	game.return_to_menu()
	hud.open_levels()
	hud.close_levels()
	hud.quick_button.pressed.emit()
	check(game.mode == "pve" and game.level_index == -1 and game.rules.ai_profile.is_empty() and game.arena.map.id == "aurora" and hud.level_info.is_empty(), "Quick play stays on the original arena with the chosen AI level")
	game.return_to_menu()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	print("CAMPAIGN_RESULT failures=", failures)
	quit(failures)
