extends SceneTree
# What is waiting behind the menu buttons: a skin just won, a power the wallet already
# pays for. The buttons carry a dot and a line under them names what it is, and opening
# the panel puts the dot out.
const Skins = preload("res://scripts/skins.gd")
const Powers = preload("res://scripts/powers.gd")
const TMP = "res://tests/news"
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
	game.skins.config_path = TMP + "-skins.tmp"
	game.power_shop.config_path = TMP + "-powers.tmp"
	game.skins.unlock_all = false
	game.skins.defeated = []
	game.skins.seen = []
	game.power_shop.unlock_all = false
	game.power_shop.owned = Powers.STARTER_KIT.duplicate()
	game.power_shop.bricks = 0
	await process_frame
	var hud = game.hud
	hud.sync_skins(game.skins)
	hud.sync_powers(game.power_shop)
	check(hud.news_text == "", "A fresh pilot with an empty wallet is told nothing")
	check(not hud.skins_button.text.ends_with("•") and not hud.powers_button.text.ends_with("•"), "And no button carries a dot")

	# A boss falls: the skin is news until the panel is opened.
	game.skins.defeat(6)
	hud.sync_skins(game.skins)
	check(hud.news_text != "" and hud.news_text.contains("RELOJOEIRO") and hud.news_text.contains("SKINS"), "A won skin is named, and points at the panel that holds it")
	check(hud.skins_button.text.ends_with("•"), "The SKINS button carries the dot")
	hud.open_skins()
	hud.close_skins()
	hud.sync_skins(game.skins)
	check(not hud.skins_button.text.ends_with("•"), "Opening the panel puts the dot out")
	check(game.skins.seen.has(6), "And remembers it was shown")

	# Bricks enough for a power: the shop is worth a visit.
	# Enough for the first two, so buying one leaves the next within reach.
	game.power_shop.bricks = 600
	hud.sync_powers(game.power_shop)
	check(hud.news_text != "" and hud.news_text.contains("PODERES"), "An affordable power points at the shop")
	check(hud.powers_button.text.ends_with("•"), "The PODERES button carries the dot")
	check(hud.news_text.contains("METRALHADORA") or hud.news_text.contains("200"), "It names the cheapest one within reach")
	game.power_shop.buy("rapid")
	hud.sync_powers(game.power_shop)
	check(hud.news_text.contains("FANTASMA") or hud.news_text.contains("250"), "Buying it moves the hint on to the next one")
	game.power_shop.bricks = 0
	hud.sync_powers(game.power_shop)
	check(not hud.powers_button.text.ends_with("•"), "With an empty wallet the dot goes out")

	# What was seen survives a restart.
	game.skins.save_preferences()
	var again = Skins.new()
	again.config_path = TMP + "-skins.tmp"
	again.unlock_all = false
	again.load_preferences()
	check(again.seen.has(6), "What was already shown is still shown after a restart")

	game.return_to_menu()
	for leftover in ["-skins.tmp", "-powers.tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP + leftover))
	print("NEWS_RESULT failures=", failures)
	quit(failures)
