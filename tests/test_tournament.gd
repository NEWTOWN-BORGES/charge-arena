extends SceneTree
const Cup = preload("res://scripts/cup.gd")
const News = preload("res://scripts/cup_news.gd")
const Data = preload("res://scripts/cup_tree_data.gd")
const Powers = preload("res://scripts/powers.gd")
const Rules = preload("res://scripts/arena_rules.gd")
const Skins = preload("res://scripts/skins.gd")
var failures = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var cup = Cup.new()
	cup.seed_value = 73
	cup.reset()
	var names: Dictionary = {}
	var boss_ids: Array = []
	for index in range(Cup.FULL_MATCHES):
		var match_data: Dictionary = cup.confirmed_match()
		check(not match_data.is_empty() and match_data.round == index + 1, "Confirmed playable round %d" % index)
		check(not names.has(match_data.name), "No repeated opponent")
		names[match_data.name] = true
		check(cup.level().map.has("outline"), "Arena exists")
		check(Powers.is_ultimate(cup.ultimate()), "Every opponent has a functional ultimate")
		if match_data.is_final: boss_ids.append(match_data.boss)
		if index == Cup.FULL_MATCHES - 2:
			check(Data.profile(cup, "Aurel").state != "ELIMINATED", "Aurel remains in contention before semifinal")
		check(cup.complete([2, index % 2]), "One win advances one match")
		check(cup.wins == index + 1, "Single advancement")
		var stories = News.edition(cup, cup.wins)
		check(stories.size() == 3, "Every round publishes an edition")
		if cup.wins < Cup.FULL_MATCHES - 1:
			check(not stories.any(func(s): return "O PENTA CAIU" in s.titulo or "derrotou Aurel" in s.corpo), "No future upset leaked")
		if cup.wins == Cup.FULL_MATCHES - 1:
			check(Data.profile(cup, "Aurel").eliminated_by == "Arconte Solar", "Semifinal defeat backed by fixture")
			check(stories[0].personagemSecundario == "Aurel" and stories[0].tipo == "UPSET", "Newspaper reports surprise at correct time")
			check(cup.confirmed_match().name == "Arconte Solar", "Finalist revealed after semifinal")
	check(boss_ids.size() == 10 and boss_ids.has(5) and boss_ids.back() == 10, "Ten bosses include Sentinela and end with Solar")
	check(cup.rounds.size() == 100 and cup.history.size() == Cup.FULL_MATCHES, "All stages simulated and recorded")
	check(cup.confirmed_match().is_empty() and not cup.complete([2, 0]), "Tournament ends exactly once")
	check(News.edition(cup, 0)[0].personagemPrincipal == "Aurel", "Archive keeps the opening favorite")
	check(News.edition(cup, 8)[0].tipo != "UPSET", "Archive never gains later spoilers")
	cup.path = "user://tournament-test.cfg"
	check(cup.save() == OK, "Tournament saves")
	var restored = Cup.new()
	restored.path = cup.path
	restored.restore()
	check(restored.boss_order == cup.boss_order and restored.history == cup.history and restored.rounds == cup.rounds and restored.world_results == cup.world_results, "Seed and every result survive restart")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(cup.path))
	var skins = Skins.new()
	check(not skins.is_unlocked(11), "Aurel starts as a prize skin")
	for skin in cup.defeated_bosses(): skins.defeat(skin)
	check(skins.is_unlocked(5) and not skins.is_unlocked(11), "Sentinela earned by defeating him; Aurel has a separate award")
	check(skins.defeat(11) and skins.select(11), "Championship prize is equippable")
	for entry in Powers.BASIC_ULTIMATES:
		var rules = Rules.new()
		rules.phase = "play"
		rules.loadouts = [["blast", "air", entry.id], ["blast", "air", ""]]
		rules.powers[0].charge[2] = rules.power_charge_cost(0, 2)
		check(rules.activate_power(0, 2), "Basic ultimate activates: " + entry.id)
		check(rules.powers[0].ultimate_windup > 0, "Basic ultimate visibly charges")
		rules.step_ultimate(0, 2.1)
		check(rules.events.any(func(e): return e.kind == "ultimate" and e.id == entry.id), "Basic ultimate executes")
		if entry.id == "b_forge": check(rules.powers[0].surge_time > 0, "Forge strengthens shots")
		if entry.id == "b_bar": check(rules.powers[0].walls_time > 0, "Barrier protects wall")
	# Start and finish the last real match, including both rewards and result UI.
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.skins.config_path = "user://tournament-skins-test.cfg"
	game.power_shop.config_path = "user://tournament-powers-test.cfg"
	game.cup = Cup.new()
	game.cup.path = "user://tournament-game-test.cfg"
	game.cup_screen.cup = game.cup
	for i in range(Cup.FULL_MATCHES - 1): game.cup.complete([2, 1])
	game.start_cup()
	check(game.rules.loadouts[1][2] == "sun_ray" and game.arena.unit_skins[1] == 10, "Grand final has actual Solar loadout and model")
	game.rules.winner = 0
	game.rules.scores = [2, 1]
	game.finish_cup()
	check(game.cup.wins == Cup.FULL_MATCHES and game.skins.is_unlocked(10) and game.skins.is_unlocked(11), "Winning grants both final rewards")
	for path in [game.skins.config_path, game.power_shop.config_path, game.cup.path]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game.queue_free()
	await process_frame
	print("TOURNAMENT FAILURES: ", failures)
	quit(failures)
