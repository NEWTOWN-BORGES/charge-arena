extends SceneTree
const Rules = preload("res://scripts/arena_rules.gd")
const View = preload("res://scripts/indie_arena_view.gd")
var failures = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	else: print("PASS: ", message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var rules = Rules.new()
	rules.phase = "play"
	rules.assist_team = -1
	var positions: Array
	rules.shoot(0)
	check(rules.balls.size() == 1 and rules.events.back().kind == "shot", "Shot and projectile on same simulation tick")
	check(is_equal_approx(rules.balls[0].v.length(), Rules.BALL_SPEED) and rules.balls[0].damage == 1, "Original shot speed and damage")
	var index = -1
	for i in range(rules.bricks.size()):
		if rules.bricks[i].team == 1:
			index = i
			break
	var hp: int = rules.bricks[index].hp
	rules.damage_brick(index, 1, 1, rules.bricks[index].p)
	check(rules.bricks[index].hp == hp, "Friendly bricks remain immune")
	rules.damage_brick(index, 1, 0, rules.bricks[index].p, false, Vector2.UP)
	check(rules.events.back().kind == "brick_hit" and rules.events.back().heading == Vector2.UP, "Impact carries direction without changing damage")
	for brick in rules.bricks:
		if brick.team == 1 and brick.id != index: brick.alive = false
	rules.damage_brick(index, hp, 0, rules.bricks[index].p)
	check(rules.events.any(func(e): return e.get("defense_open", false)), "Last brick announces defense drop")
	var count = rules.events.size()
	rules.damage_brick(index, hp, 0, rules.bricks[index].p)
	check(rules.events.size() == count, "No duplicate defense drop for dead brick")
	positions = rules.players.duplicate(true)
	var view = View.new()
	root.add_child(view)
	view.build()
	view.shot_feedback(0)
	check(view.units[0].get_node("Body/Gun/Flash").scale.x > 0.3, "Muzzle responds immediately")
	view.update_state(rules, 0, 0.06)
	check(view.units[0].get_node("Body/Gun").position.z > 0.15, "Recoil reaches peak at 60 ms")
	view.update_state(rules, 0, 0.1)
	check(view.units[0].get_node("Body/Gun").position.z < 0.12, "Recoil is on its way back 160 ms in")
	view.update_state(rules, 0, 0.15)
	check(view.units[0].get_node("Body/Gun").position.z == 0.0, "Recoil has settled by 310 ms")
	check(rules.players == positions, "Recoil never changes player or aiming physics")
	for quality in range(3):
		view.set_quality(quality)
		for n in range(250):
			view.shot_feedback(n % 2)
			view.impact_feedback({"kind": "brick", "p": Vector2.ZERO, "team": n % 2, "heading": Vector2.UP})
			view.update_state(rules, 0, 0.025)
		check(view.effects.size() <= view.effect_limit and view.feedback_allocated <= view.FEEDBACK_POOL_LIMIT, "Bounded particles at quality %d" % quality)
	view.update_state(rules, 0, 1.0)
	check(view.feedback_pool.size() == view.feedback_allocated, "All pooled basic particles returned")
	view.queue_free()
	await process_frame
	print("FEEDBACK_RESULT failures=", failures)
	quit(failures)

