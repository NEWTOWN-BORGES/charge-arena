extends SceneTree
# Powers and ultimates across the wire: the client presses its keys, the host presses its
# own, and both sides must see both go off. Run as two processes, host first:
#   godot --headless --path . --script res://tests/test_pvp_powers.gd -- --host
#   godot --headless --path . --script res://tests/test_pvp_powers.gd -- --client
var game
var role = ""
var ticks = 0
var seen_local_power = false
var seen_remote_power = false
var seen_local_ultimate = false
var seen_remote_ultimate = false
var asked_power = false
var asked_ultimate = false

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	role = "host" if OS.get_cmdline_user_args().has("--host") else "client"
	if role == "host":
		game.host_game()
	else:
		game.join_game("127.0.0.1")
	while ticks < 900:
		await create_timer(0.02).timeout
		ticks += 1
		if not game.connected:
			continue
		var mine: int = game.local_team
		if role == "host" and ticks < 100:
			# The host owns the simulation, so it is the one that hands out charge. It stops
			# well before either side presses a key: topping up on the same tick a power is
			# spent hides the very spending this test is looking for.
			for team in range(2):
				for slot in range(game.Rules.POWER_SLOTS):
					game.rules.powers[team].charge[slot] = game.rules.power_charge_cost(team, slot)
		if ticks > 120 and not asked_power:
			asked_power = true
			game.hud.request_power(0)
		if ticks > 320 and not asked_ultimate:
			asked_ultimate = true
			game.hud.request_power(game.Rules.POWER_SLOTS - 1)
		# Read durable state, not the one-tick events: a 20 ms sampler misses a 16 ms event
		# by luck alone, and that is a flaw in the test, not in the game.
		for team in range(2):
			var spent: bool = asked_power and int(game.rules.powers[team].charge[0]) < game.rules.power_charge_cost(team, 0)
			var casting: bool = float(game.rules.powers[team].ultimate_windup) > 0.0 or float(game.rules.powers[team].ultimate_time) > 0.0
			if team == mine:
				seen_local_power = seen_local_power or spent
				seen_local_ultimate = seen_local_ultimate or casting
			else:
				seen_remote_power = seen_remote_power or spent
				seen_remote_ultimate = seen_remote_ultimate or casting
		if seen_local_power and seen_remote_power and seen_local_ultimate and seen_remote_ultimate:
			print("PVP_POWERS_PASS role=", role, " local_power=true remote_power=true local_ultimate=true remote_ultimate=true")
			await create_timer(3.0 if role == "host" else 1.0).timeout
			game.close_network()
			quit(0)
			return
	push_error("PVP_POWERS_FAIL role=" + role + " kit=" + str(game.rules.loadouts) + " local_power=" + str(seen_local_power) + " remote_power=" + str(seen_remote_power) + " local_ultimate=" + str(seen_local_ultimate) + " remote_ultimate=" + str(seen_remote_ultimate))
	game.close_network()
	quit(1)
