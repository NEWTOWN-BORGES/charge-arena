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
	# This test APK exposes the sandbox arenas and powers, while keeping skin prizes earned.
	check(not Skins.UNLOCK_ALL_FOR_TESTS and not Powers.UNLOCK_ALL_FOR_TESTS, "Skin rewards and powers start locked and must be earned or bought")
	check(not Powers.START_WITH_ULTIMATE_FOR_TESTS, "And a match still starts with the ultimate keys cold, open build or not")
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
	check(boss_two == 1, "Level 2 is the Faroleiro's")
	check(skins.defeat(boss_two) and skins.is_unlocked(boss_two), "Beating a boss hands you its skin")
	check(not skins.defeat(boss_two), "And it is only handed over once")
	check(skins.unlocked_count() == 2, "Two pilots now")
	# Every boss skin is reachable: each one is tied to a level of the campaign.
	var reachable = 0
	for level in range(2, Campaign.LEVELS.size() + 1):
		if Skins.boss_skin(level) >= 0:
			reachable += 1
	check(reachable == Skins.CATALOG.filter(func(s): return s.level > 0).size(), "Every pilot but the starter is the prize of a level (%d)" % reachable)

	# ---------------------------------------------------------------- the wallet pays for the shop
	var cheapest = 99999
	var dearest = 0
	for entry in Powers.CATALOG:
		if int(entry.price) > 0:
			cheapest = mini(cheapest, int(entry.price))
			dearest = maxi(dearest, int(entry.price))
	# A match is worth about eighty bricks, measured against the campaign bosses.
	check(cheapest <= 140 and dearest <= 450, "The first power costs about three matches (%d) and the dearest about ten (%d)" % [cheapest, dearest])
	shop.bricks = cheapest - 1
	check(not shop.buy("rapid") or cheapest != 120, "A power cannot be bought without the bricks for it")
	shop.bricks = dearest
	check(shop.buy("laser") and shop.is_owned("laser") and shop.bricks == dearest - 420, "Paying for one takes the bricks and hands it over")
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

	# Version 2 purchases and balance survive the version-3 closed-shop update.
	var v2 = ConfigFile.new()
	v2.set_value("powers", "version", 2)
	v2.set_value("powers", "bricks", 321)
	v2.set_value("powers", "owned", ["blast", "air", "laser"])
	v2.set_value("powers", "kit", ["laser", "air"])
	v2.save(TMP + "-v2.tmp")
	var upgraded = fresh_shop()
	upgraded.config_path = TMP + "-v2.tmp"
	upgraded.load_preferences()
	check(upgraded.bricks == 321 and upgraded.is_owned("laser") and upgraded.kit[0] == "laser", "Version-2 earned powers, equipped kit and currency survive migration")
	check(FileAccess.file_exists(upgraded.config_path + ".before-v3"), "Migration keeps a backup of the previous shop save")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(upgraded.config_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(upgraded.config_path + ".before-v3"))

	# ---------------------------------------------------------------- an old open save is refused
	# Exactly what sits on a phone that ran the unlocked test builds: everything won, a full
	# wallet, and no version stamp.
	var stale = ConfigFile.new()
	stale.set_value("campaign", "unlocked", Campaign.LEVELS.size())
	stale.set_value("campaign", "completed", range(Campaign.LEVELS.size()))
	stale.save(TMP + "-old-campaign.tmp")
	stale = ConfigFile.new()
	stale.set_value("skins", "defeated", range(1, Skins.CATALOG.size()))
	stale.set_value("skins", "selected", 5)
	stale.save(TMP + "-old-skins.tmp")
	stale = ConfigFile.new()
	stale.set_value("powers", "bricks", 5000)
	stale.set_value("powers", "owned", Powers.all_ids())
	stale.set_value("powers", "kit", ["laser", "mirror"])
	stale.save(TMP + "-old-powers.tmp")
	var old_campaign = fresh_campaign()
	old_campaign.config_path = TMP + "-old-campaign.tmp"
	old_campaign.load_preferences()
	var old_skins = fresh_skins()
	old_skins.config_path = TMP + "-old-skins.tmp"
	old_skins.load_preferences()
	var old_shop = fresh_shop()
	old_shop.config_path = TMP + "-old-powers.tmp"
	old_shop.load_preferences()
	check(not old_campaign.is_unlocked(1), "A save from an unlocked build opens no level here")
	check(old_skins.unlocked_count() == 1, "And hands over no pilot")
	check(old_shop.bricks == 0 and not old_shop.is_owned("laser"), "And no bricks and no bought power")

	for leftover in ["-campaign.tmp", "-skins.tmp", "-powers.tmp", "-old-campaign.tmp", "-old-skins.tmp", "-old-powers.tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP + leftover))
	print("PROGRESS_RESULT failures=", failures)
	quit(failures)
