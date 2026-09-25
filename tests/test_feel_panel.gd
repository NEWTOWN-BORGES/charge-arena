extends SceneTree
# The tuning panel opens from the options, moves the live tuning, starts the test range
# and saves what was set.
var failures = 0

func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(720, 1280)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.feel.config_path = "res://tests/feel-panel.tmp"
	game.hud.open_video()
	game.hud.feel_panel_requested.emit()
	await process_frame
	var panel = game.feel_panel
	check(is_instance_valid(panel) and panel.sliders.size() == game.CombatFeel.PARAMS.size(), "Every tuning parameter has a slider")
	panel.sliders["trail_length"].value = 1.6
	check(game.feel.value("trail_length") == 1.6 and game.arena.tune("trail_length") == 1.6, "A slider moves the live tuning the arena reads")
	game.hud.effects_choice.select(1)
	game.hud.effects_choice.item_selected.emit(1)
	check(game.feel.effects_reduced, "Effects can be reduced from the options")
	panel.range_requested.emit()
	await process_frame
	await process_frame
	check(game.mode == "pve" and game.pause_ai and not is_instance_valid(game.feel_panel), "CAMPO DE TESTE opens a match with the rival standing still")
	var saved = game.CombatFeel.new()
	saved.config_path = game.feel.config_path
	saved.load_preferences()
	check(saved.value("trail_length") == 1.6 and saved.effects_reduced, "What was tuned is saved")
	saved.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.feel.config_path))
	game.queue_free()
	await process_frame
	print("FEEL_PANEL_RESULT failures=", failures)
	quit(failures)
