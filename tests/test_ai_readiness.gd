extends SceneTree
const Rules = preload("res://scripts/arena_rules.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Cup = preload("res://scripts/cup.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var human = Rules.new()
	human.phase = "play"
	var before = human.powers[1].charge.duplicate()
	for tick in range(180): human.step(1.0 / 60.0, [{}, {}])
	assert(human.powers[1].charge == before, "Human PvP opponent must not receive bot passive charge")
	var bot = Rules.new()
	bot.phase = "play"
	bot.ai_level = 2
	before = bot.powers[1].charge.duplicate()
	for tick in range(180): bot.step(1.0 / 60.0, [{}, bot.ai_command()])
	assert(bot.powers[1].charge[0] > before[0], "Quick-play bot can charge its kit")
	for difficulty in [1, 2]:
		var r = Rules.new()
		r.phase = "play"
		r.ai_level = difficulty
		r.elapsed = 12
		r.players[1].cooldown = 5.0
		r.ai_next_fire_check = 100.0
		r.loadouts[1] = ["blast", "air", "meteors"]
		r.powers[1].charge[2] = r.power_charge_cost(1, 2)
		assert(r.ai_command().power == 2, "Ready ultimate cannot depend on basic-shot cooldown")
		r = Rules.new()
		r.phase = "play"
		r.ai_level = difficulty
		r.elapsed = 12
		r.players[1].cooldown = 5
		r.loadouts[1] = ["weld", "walls", "b_patch"]
		for brick in r.bricks:
			if brick.team == 1: brick.hp = 2
		r.powers[1].charge[0] = r.power_charge_cost(1, 0)
		assert(r.ai_command().power == 0, "Heal damaged wall while weapon is cooling")
		r = Rules.new()
		r.phase = "play"
		r.ai_level = difficulty
		r.elapsed = 12
		r.loadouts[1] = ["blast", "air", "b_patch"]
		r.powers[1].charge[2] = r.power_charge_cost(1, 2)
		assert(r.ai_ultimate(Rules.AI_LEVELS[difficulty], true) == -1, "Do not waste a heal on a full wall")
		for story in [false, true]:
			r = Rules.new()
			r.phase = "play"
			r.ai_level = difficulty
			r.ai_profile = Cup.new().profile(difficulty) if story else Campaign.ai_profile(1, difficulty)
			r.loadouts[1] = ["blast", "air", "meteors"]
			r.power_rng.seed = 50924
			var first = -1.0
			for tick in range(60 * 30):
				r.step(1.0 / 60.0, [{}, r.ai_command()])
				if r.events.any(func(e): return e.kind == "ultimate_charge" and e.team == 1):
					first = r.elapsed
					break
			assert(first > 0 and first < 25, "Campaign ultimate should enter play well before the end")
			print("AI_FIRST_ULTIMATE difficulty=", difficulty, " story=", story, " seconds=", first)
	print("PASS AI READINESS: independent power decisions, healing context and early ultimates on both difficulties")
	quit()
