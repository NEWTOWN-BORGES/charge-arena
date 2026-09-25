extends SceneTree
# The story mode as it is played: lobby -> Taça hub -> versus card -> arena -> result ->
# today's paper -> hub, and a lost round that waits for a retry.
const Press = preload("res://scripts/story_press.gd")
var failures = 0

func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func finish(game, winner: int) -> void:
	game.rules.phase = "finished"
	game.rules.winner = winner
	game.rules.scores = [2, 1] if winner == 0 else [1, 2]
	game._process(0.02)
	await process_frame
	await process_frame

func run() -> void:
	root.size = Vector2i(720, 1280)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.campaign.config_path = "res://tests/story-hub-campaign.tmp"
	game.skins.config_path = "res://tests/story-hub-skins.tmp"
	game.power_shop.config_path = "res://tests/story-hub-powers.tmp"
	game.cup.path = "res://tests/story-hub-cup.tmp"
	game.cup.seed_value = 31337
	game.cup.reset()
	game.sync_story()
	await process_frame
	var hud = game.hud
	check(hud.lobby.lobby_mode == "historia" and String(hud.story_line).contains("ADMISSÃO") and String(hud.story_line).contains("AURORA"), "The lobby opens on the story, naming the round and the rival")
	hud.campaign_button.pressed.emit()
	await process_frame
	var hub = game.cup_screen
	check(hub.visible and not game.arena.visible, "JOGAR in the story mode opens the Taça hub")
	check(Press.has_new_edition(game.cup), "The opening edition waits unread at the kiosk")
	hub.open_versus()
	await process_frame
	check(is_instance_valid(hub.overlay) and String(hub.overlay.info.round) == "ADMISSÃO" and hub.overlay.info.name == "Aurora", "The versus card comes before the match")
	hub.overlay.enter.emit()
	await process_frame
	check(game.mode == "pve" and game.cup_active and not hub.visible and game.arena.map.id == "treino", "ENTRAR NA ARENA plays the admission on the campaign's first arena")
	await finish(game, 0)
	check(hub.visible and is_instance_valid(hub.overlay) and hub.overlay.outcome.won and game.cup.entrance_passed, "A win comes back to the hub with the result, not to a generic menu")
	check(Press.editions_available(game.cup) == 2 and Press.has_new_edition(game.cup), "And a new edition is on the stand")
	hub.overlay.read_paper.emit()
	await process_frame
	check(is_instance_valid(hub.page) and hub.page.number == 1 and not Press.has_new_edition(game.cup), "Reading the paper opens today's edition and puts the badge out")
	hub.page.closed.emit()
	await process_frame
	check(not is_instance_valid(hub.page), "The paper closes back to the hub")
	# Round 1, lost.
	hub.open_versus()
	hub.overlay.enter.emit()
	await process_frame
	check(game.cup_active and game.rules.loadouts[1].size() == 3 and game.arena.unit_skins[1] == 1, "Round 1 brings the Faroleiro in its own skin and kit")
	await finish(game, 1)
	check(is_instance_valid(hub.overlay) and not hub.overlay.outcome.won and game.cup.losses_here() == 1 and game.cup.wins == 0, "A defeat is shown and remembered, and the round is still there")
	check(Press.editions_available(game.cup) == 2 and Press.kiosk_line(game.cup) == Press.KIOSK_AFTER_DEFEAT[0], "Nothing is printed; Rosa has a word")
	hub.overlay.retry.emit()
	await process_frame
	check(is_instance_valid(hub.overlay) and hub.overlay.has_signal("enter"), "TENTAR DE NOVO goes back to the versus card")
	hub.overlay.enter.emit()
	await process_frame
	await finish(game, 0)
	check(game.cup.wins == 1 and game.skins.is_unlocked(1) and game.campaign.completed.has(game.cup.story_levels()[1]), "Winning the round moves the draw on, gives the Faroleiro's skin and opens its arena")
	var restored = load("res://scripts/tournament.gd").new()
	restored.path = game.cup.path
	restored.restore()
	check(restored.wins == 1 and restored.attempts.size() == 1 and restored.editions_read == 1, "All of it is saved: the round, the lost attempt and what has been read")
	hub.overlay.done.emit()
	await process_frame
	hub.open_route()
	await process_frame
	check(is_instance_valid(hub.page) and hub.page.column.get_child_count() > 4, "The route lists the admission and the round won")
	hub.open_bracket()
	await process_frame
	hub.page.zoom_near = true
	hub.page.build()
	await process_frame
	check(is_instance_valid(hub.page), "The tree opens, globally and around the player")
	for f in ["story-hub-campaign.tmp", "story-hub-skins.tmp", "story-hub-powers.tmp", "story-hub-cup.tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("res://tests/" + f))
	game.queue_free()
	await process_frame
	print("STORY_HUB_RESULT failures=", failures)
	quit(failures)
