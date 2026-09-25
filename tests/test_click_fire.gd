extends SceneTree
# Disparo manual: cada clique é um tiro - no botão, no joystick, no rato ou no espaço. Manter
# o dedo em baixo não continua a disparar, e um clique feito durante a recarga não se perde.
var failures = 0

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: ", description)

func _initialize() -> void:
	call_deferred("run")

func touch(hud, at: Vector2, down: bool, index: int = 0) -> void:
	var event = InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = down
	hud._input(event)

func ready_gun(game) -> void:
	game.rules.phase = "play"
	game.rules.players[game.local_team].cooldown = 0.0
	game.rules.players[game.local_team].stun = 0.0

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_pve()
	await process_frame
	game.game_settings.auto_fire = false
	game.game_settings.fire_control = 0
	game.hud.sync_game(game.game_settings)
	var hud = game.hud
	ready_gun(game)

	touch(hud, hud.fire_center, true)
	check(game.local_command().fire, "Um toque no botão de tiro dispara")
	ready_gun(game)
	check(not game.local_command().fire, "Manter o dedo no botão não volta a disparar")
	touch(hud, hud.fire_center, false)

	game.rules.players[game.local_team].cooldown = 0.3
	touch(hud, hud.fire_center, true)
	touch(hud, hud.fire_center, false)
	check(not game.local_command().fire, "Um toque durante a recarga espera pela arma")
	game.rules.players[game.local_team].cooldown = 0.0
	check(game.local_command().fire and not game.local_command().fire, "E sai assim que a arma está pronta, uma única vez")

	game.rules.players[game.local_team].cooldown = 0.3
	touch(hud, hud.fire_center, true)
	touch(hud, hud.fire_center, false)
	game.local_command()
	touch(hud, hud.fire_center, true)
	touch(hud, hud.fire_center, false)
	game.local_command()
	game.rules.players[game.local_team].cooldown = 0.0
	var first: bool = game.local_command().fire
	game.rules.players[game.local_team].cooldown = 0.0
	var second: bool = game.local_command().fire
	check(first and second and not game.local_command().fire, "Dois toques rápidos são dois tiros")

	game.rules.players[game.local_team].cooldown = 0.3
	touch(hud, hud.fire_center, true)
	touch(hud, hud.fire_center, false)
	game.local_command()
	game.queued_until[game.local_team] = Time.get_ticks_msec() - 1
	game.rules.players[game.local_team].cooldown = 0.0
	check(not game.local_command().fire, "Um toque antigo demais expira em vez de disparar muito depois")

	# Ten quick taps, some of them between two ticks of the match: ten shots, one per reload.
	game.rules.players[game.local_team].cooldown = 0.3
	for tap in range(10):
		touch(hud, hud.fire_center, true)
		touch(hud, hud.fire_center, false)
		if tap % 3 == 0:
			game.local_command()
	var fired = 0
	for reload in range(14):
		game.rules.players[game.local_team].cooldown = 0.0
		if game.local_command().fire:
			fired += 1
	check(fired == 10, "Dez toques rápidos são dez tiros (%d)" % fired)

	game.game_settings.fire_control = 1
	hud.sync_game(game.game_settings)
	ready_gun(game)
	var stick: Vector2 = Vector2(hud.fire_center.x * 0.3, hud.touch_top + 40)
	touch(hud, stick, true, 1)
	check(game.local_command().fire, "No modo joystick, pousar o dedo no joystick dispara")
	ready_gun(game)
	check(not game.local_command().fire and hud.move_id == 1, "Mas arrastar ou manter o joystick só move, não dispara")
	touch(hud, stick, false, 1)
	game.rules.players[game.local_team].cooldown = 0.3
	for tap in range(10):
		touch(hud, stick, true, 1)
		touch(hud, stick, false, 1)
	fired = 0
	for reload in range(14):
		game.rules.players[game.local_team].cooldown = 0.0
		if game.local_command().fire:
			fired += 1
	check(fired == 10, "Dez toques no joystick são dez tiros (%d)" % fired)

	var key = InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	game._unhandled_key_input(key)
	ready_gun(game)
	check(game.local_command().fire and not game.local_command().fire, "O espaço dispara um tiro por cada vez que é premido")

	game.game_settings.auto_fire = true
	hud.sync_game(game.game_settings)
	check(game.local_command().fire, "O disparo automático continua a disparar sozinho")

	print("CLICK_FIRE_RESULT failures=", failures)
	quit(failures)
