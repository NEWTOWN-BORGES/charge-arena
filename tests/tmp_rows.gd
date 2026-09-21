extends SceneTree
const Rules = preload("res://scripts/arena_rules.gd")
const Campaign = preload("res://scripts/campaign.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for name in ["banks", "wall", "arc", "islands", "chevron", "torre", "bulwark", "fortress", "colosseum"]:
		var bricks: Array = Rules.make_bricks(name)
		var mine: Array = bricks.filter(func(b): return b.team == 0)
		var depths: Dictionary = {}
		for b in mine:
			depths[snappedf(absf(b.p.y - Rules.goal_center(0).y), 0.1)] = true
		var span := 0.0
		for b in mine:
			span = maxf(span, absf(b.p.x))
		var closest := 99.0
		for i in range(mine.size()):
			for j in range(i + 1, mine.size()):
				closest = minf(closest, mine[i].p.distance_to(mine[j].p))
		print("%-11s %d por equipa  profundidades=%d  |x| max=%.2f  mais perto=%.2f" % [name, mine.size(), depths.size(), span, closest])
	print("--- muralhas da campanha ---")
	for index in range(Campaign.LEVELS.size()):
		var level: Dictionary = Campaign.LEVELS[index]
		var r = Rules.new()
		r.set_map(level.map)
		var mine: int = r.bricks.filter(func(b): return b.team == 0).size()
		print("nivel %2d  %-13s %2d tijolos x %d vidas = %3d" % [index + 1, level.map.id, mine, r.brick_lives, mine * r.brick_lives])
	quit(0)
