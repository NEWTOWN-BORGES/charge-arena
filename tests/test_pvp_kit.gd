extends SceneTree
# PvP: each pilot brings its own bought kit and the ultimate of the skin it is wearing,
# announced to the other side when the match is joined.
const Rules = preload("res://scripts/arena_rules.gd")
const Skins = preload("res://scripts/skins.gd")
const Powers = preload("res://scripts/powers.gd")
const TMP = "res://tests/pvp-kit.tmp"
var failures = 0

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: ", description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	# Temporary config files: a test must never write over the real saves.
	game.power_shop.config_path = TMP
	game.skins.config_path = TMP + "s"
	game.skins.unlock_all = true
	game.skins.selected = 10
	game.power_shop.kit = ["ghost", "rebuild"]
	game.host_game()
	await process_frame
	check(game.rules.loadouts[0] == ["ghost", "rebuild", "sun_ray"], "The host takes its kit and the ultimate of its own skin into PvP")
	game.mode = "host"
	game.remote_id = 0
	game.share_skin(3)
	check(game.rules.power_id(1, 2) == "bloom" and game.arena.unit_skins[1] == 3, "The rival's skin brings its ultimate with it")
	game.share_kit("laser", "mirror")
	check(game.rules.loadouts[1] == ["laser", "mirror", "bloom"], "And the two powers it bought arrive without losing the ultimate")
	game.share_kit("inventado", "mirror")
	check(game.rules.loadouts[1] == ["laser", "mirror", "bloom"], "A kit with an unknown power is ignored")
	game.share_skin(0)
	check(game.rules.power_id(1, 2) == "", "The standard pilot has no ultimate, so the third key stays empty")
	game.share_skin(Skins.CATALOG.size())
	check(game.rules.power_id(1, 2) == "" and game.arena.unit_skins[1] == 0, "A skin index that does not exist is ignored, kit and model left as they were")
	game.return_to_menu()
	for leftover in [TMP, TMP + "s"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(leftover))
	print("PVP_KIT_RESULT failures=", failures)
	quit(failures)
