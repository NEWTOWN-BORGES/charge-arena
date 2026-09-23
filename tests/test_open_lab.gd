extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	var before = game.cup.wins
	game.configure_test_access(false)
	assert(not game.skins.unlock_all)
	game.configure_test_access(true)
	assert(game.skins.unlocked_count() == game.Skins.CATALOG.size())
	assert(game.skins.selected == 5)
	for entry in game.PowerShop.CATALOG:
		assert(game.power_shop.is_owned(entry.id))
	for index in range(game.Campaign.LEVELS.size()):
		assert(game.campaign.is_unlocked(index))
	assert(game.campaign.completed.is_empty() and game.skins.defeated.is_empty())
	assert(game.cup.wins == before)
	var config = ConfigFile.new()
	assert(config.load("res://export_presets.cfg") == OK)
	assert(config.get_value("preset.2", "custom_features") == "open_test")
	var lab_package = config.get_value("preset.2.options", "package/unique_name")
	assert(lab_package != config.get_value("preset.0.options", "package/unique_name"))
	assert(lab_package != config.get_value("preset.1.options", "package/unique_name"))
	assert(config.get_value("preset.0", "custom_features") == "")
	assert(config.get_value("preset.1", "custom_features") == "")
	game.free()
	print("OPEN_LAB_PASS: all skins, powers and maps; no invented wins; isolated package and export flag")
	quit()
