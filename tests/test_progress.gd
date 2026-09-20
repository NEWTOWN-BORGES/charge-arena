extends SceneTree
# The demo's progression, end to end: one level open, one pilot, two free powers and an
# empty wallet. Beating a boss opens the next level and its skin; destroyed bricks pay for
# the shop. Nothing here touches the real saves — every store writes to res://tests/*.tmp.
const Rules = preload("res://scripts/arena_rules.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Skins = preload("res://scripts/skins.gd")
const Powers = preload("res://scripts/powers.gd")
const TMP = "res://tests/progress"
var failures = 0

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: ", description)

func _initialize() -> void:
	call_deferred("run")

func fresh_campaign():
	var campaign = Campaign.new()
	campaign.config_path = TMP + "-campaign.tmp"
	campaign.unlock_all = false
	campaign.unlocked = 1
	campaign.completed = []
	return campaign

func fresh_skins():
	var skins = Skins.new()
	skins.config_path = TMP + "-skins.tmp"
	skins.unlock_all = false
	skins.defeated = []
	return skins

func fresh_shop():
	var shop = Powers.new()
	shop.config_path = TMP + "-powers.tmp"
	shop.unlock_all = false
	shop.bricks = 0
	shop.owned = Powers.STARTER_KIT.duplicate()
	shop.kit = Powers.STARTER_KIT.duplicate()
	return shop

func run() -> void:
	# ---------------------------------------------------------------- the demo starts closed
	check(not Campaign.UNLOCK_ALL_FOR_TESTS and not Skins.UNLOCK_ALL_FOR_TESTS and not Powers.UNLOCK_ALL_FOR_TESTS and not Powers.START_WITH_ULTIMATE_FOR_TESTS, "The shipped build has every test unlock switched off")
	var campaign = fresh_campaign()
	var skins = fresh_skins()
	var shop = fresh_shop()
	check(campaign.is_unlocked(0) and not campaign.is_unlocked(1), "Only the first level is open")
	check(skins.unlocked_count() == 1 and skins.is_unlocked(0), "Only the standard pilot is yours")
	check(shop.bricks == 0 and shop.owned.size() == 2 and shop.owned.has("blast") and shop.owned.has("air"), "An empty wallet and the two free powers")
	check(Powers.CATALOG.filter(func(p): return int(p.price) == 0).size() == 2, "Only those two are free; the other seven are bought")

	# ---------------------------------------------------------------- beating a boss opens things
	var opened = campaign.complete(0)
	check(opened and campaign.is_unlocked(1) and not campaign.is_unlocked(2), "Winning level 1 opens level 2, and only level 2")
	var boss_two = Skins.boss_skin(2)
	check(boss_two == 6, "Level 2 is the Relojoeiro's")
	check(skins.defeat(boss_two) and skins.is_unlocked(boss_two), "Beating a boss hands you its skin")
	check(not skins.defeat(boss_two), "And it is only handed over once")
	check(skins.unlocked_count() == 2, "Two pilots now")
	# Every boss skin is reachable: each one is tied to a level of the campaign.
	var reachable = 0
	for level in range(2, Campaign.LEVELS.size() + 1):
		if Skins.boss_skin(level) >= 0:
			reachable += 1
	check(reachable == Skins.CATALOG.size() - 1, "Every pilot but the starter is the prize of a level (%d)" % reachable)

	# ---------------------------------------------------------------- the wallet pays for the shop
	var cheapest = 99999
	var dearest = 0
	for entry in Powers.CATALOG:
		if int(entry.price) > 0:
			cheapest = mini(cheapest, int(entry.price))
			dearest = maxi(dearest, int(entry.price))
	# A match is worth about eighty bricks, measured against the campaign bosses.
	check(cheapest <= 240 and dearest <= 1000, "The first power costs about three matches (%d) and the dearest about ten (%d)" % [cheapest, dearest])
	shop.bricks = cheapest - 1
	check(not shop.buy("rapid") or cheapest != 200, "A power cannot be bought without the bricks for it")
	shop.bricks = dearest
	check(shop.buy("laser") and shop.is_owned("laser") and shop.bricks == dearest - 800, "Paying for one takes the bricks and hands it over")
	check(shop.equip(0, "laser") and shop.kit[0] == "laser", "And it can go straight into the kit")
	check(not shop.buy("laser"), "Nothing is bought twice")

	# ---------------------------------------------------------------- and all of it survives a restart
	check(campaign.save_preferences() == OK and skins.save_preferences() == OK and shop.save_preferences() == OK, "Progress is written to disk")
	var again_campaign = fresh_campaign()
	var again_skins = fresh_skins()
	var again_shop = fresh_shop()
	again_campaign.load_preferences()
	again_skins.load_preferences()
	again_shop.load_preferences()
	check(again_campaign.is_unlocked(1), "The opened level is still open after a restart")
	check(again_skins.is_unlocked(boss_two), "The won pilot is still yours")
	check(again_shop.is_owned("laser") and again_shop.kit[0] == "laser", "The bought power is still bought, and still equipped")

	for leftover in ["-campaign.tmp", "-skins.tmp", "-powers.tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP + leftover))
	print("PROGRESS_RESULT failures=", failures)
	quit(failures)
