extends SceneTree
## Skins unlock when their campaign boss is beaten, persist, dress the right
## models with their own colours, show in the 3D viewer and travel to the rival in PvP.
const Skins = preload("res://scripts/skins.gd")
const TMP = "res://tests/skins-progress.tmp"
var failures = 0

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: ", description)

func _initialize() -> void:
	call_deferred("run")

func floor_glow(projectile: Node3D) -> Color:
	for child in projectile.get_children():
		if child.material_override is ShaderMaterial:
			return child.material_override.get_shader_parameter("tint")
	return Color.BLACK

func run() -> void:
	check(Skins.CATALOG.size() == 12, "Catalog has ten bosses, Aurora and the Aurel prize")
	check(Skins.CATALOG[0].level == 0 and Skins.CATALOG[0].name == "PILOTO AURORA", "First skin is the default Aurora pilot")
	check(Skins.boss_skin(1) == -1, "Level 1 trains against the standard pilot, so it carries no skin")
	check(range(2, 12).all(func(lvl): return Skins.boss_skin(lvl) > 0), "Every campaign level from 2 to 11 has a boss skin of its own")
	check(Skins.CATALOG.all(func(e): return e.bricks != "" and e.weapon != "" and e.about != ""), "Every skin names its weapon, brick theme and description")

	var cyan = Color("72ddc6")
	var coral = Color("ef947e")
	check(Skins.colors(0, cyan) == {"body": cyan, "light": cyan.lightened(0.3), "shot": cyan}, "Default pilot keeps the team colours")
	check(Skins.colors(1, cyan).body == cyan and Skins.colors(1, cyan).shot == Color("9cc2ff"), "Faroleiro keeps the team coat and fires beacon-blue shots")
	check(Skins.colors(2, cyan).body == Color("444f8f") and Skins.colors(2, cyan).shot == Color("b99cff"), "Astrónomo has its own indigo body and violet shots")
	check(Skins.colors(1, coral, true).body == coral.darkened(0.3), "Boss tint forces red team colours before being defeated")

	# These checks use the real progression, not the testing build's open collection.
	var testing = Skins.new()
	testing.unlock_all = true
	check(testing.unlocked_count() == Skins.CATALOG.size(), "A testing build can wear every skin")
	testing.unlock_all = false
	testing.defeated = []
	testing.unlock_all = false
	check(testing.unlocked_count() == 1, "With the test unlock off, a pilot starts with the standard hull alone")
	var progress = Skins.new()
	progress.unlock_all = false
	progress.config_path = TMP
	check(progress.is_unlocked(0) and not progress.is_unlocked(1) and progress.unlocked_count() == 1, "Only the default skin starts unlocked")
	check(not progress.select(1) and progress.selected == 0, "A locked skin cannot be equipped")
	check(progress.defeat(1) and progress.is_unlocked(1) and progress.unlocked_count() == 2, "Defeating boss 1 unlocks its skin")
	check(not progress.defeat(1), "Defeating an already unlocked boss skin returns false")
	check(progress.select(1) and progress.selected == 1, "Unlocked skin can be equipped")
	check(progress.defeat(6) and progress.defeat(10) and progress.unlocked_count() == 4, "Can unlock multiple boss skins")
	check(progress.select(6) and progress.save_preferences() == OK, "Equipping and saving preferences works")

	var restored = Skins.new()
	restored.unlock_all = false
	restored.config_path = TMP
	restored.load_preferences()
	check(restored.defeated.has(1) and restored.defeated.has(6) and restored.defeated.has(10) and restored.selected == 6, "Defeated bosses and equipped skin survive reload")

	var edited = ConfigFile.new()
	edited.set_value("skins", "version", Skins.SAVE_VERSION)
	edited.set_value("skins", "defeated", [1])
	edited.set_value("skins", "selected", 6)
	edited.save(TMP)
	restored.load_preferences()
	check(restored.selected == 0, "An edited save cannot equip a locked skin")

	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await process_frame
	await process_frame

	var arena = game.arena
	var hud = game.hud
	game.skins.config_path = TMP
	game.skins.unlock_all = false
	game.skins.defeated = []
	game.skins.selected = 0
	hud.sync_skins(game.skins)
	arena.set_skin(1, 0) # Set rival to default so testing team 0 bricks is isolated

	for skin in range(Skins.CATALOG.size()):
		arena.set_skin(0, skin)
		var unit: Node3D = arena.units[0]
		var rigged = unit.has_node("Body/LegL") and unit.has_node("Body/LegR") and unit.has_node("Body/Gun/Flash") and unit.has_node("Stun")
		game.rules.players[0].cooldown = 0.0
		arena.update_state(game.rules, 0, 1.0 / 60)
		game.rules.players[0].cooldown = 1.0
		arena.update_state(game.rules, 0, 1.0 / 60)
		check(rigged and unit.get_node("Body/Gun/Flash").scale.x > 0.2, "Skin %d has every animated part and fires muzzle flash" % skin)
		if skin == 5:
			var left_eye: Node3D = unit.get_node("Body/SentinelEyeL")
			var right_eye: Node3D = unit.get_node("Body/SentinelEyeR")
			check(left_eye.rotation_degrees.z < 0 and right_eye.rotation_degrees.z > 0, "Sentinel eyes use stern inward angle")
		var themed = range(80).all(func(i): return arena.brick_nodes[i].get_meta("skin") == (skin if i < 40 else 0))
		var lit = arena.brick_nodes.all(func(b): return b.has_node("HP0") and b.has_node("HP1") and b.has_node("HP2"))
		check(themed and lit and arena.brick_nodes.size() == 80 and arena.brick_batches.size() < 24, "Skin %d styles team bricks with life lights and batching" % skin)

	arena.set_skin(0, 2)
	var orbit: Node3D = arena.units[0].get_node("Body/OrbitTilt/Orbit")
	var turn = orbit.rotation.y
	arena.update_state(game.rules, 0, 0.5)
	check(not is_equal_approx(orbit.rotation.y, turn), "Astrónomo's orbit rings spin during play")

	# Shot colours: aura follows skin, floor glow keeps team, boosts stay gold.
	arena.set_skin(0, 2)
	arena.set_skin(1, 0)
	game.rules.phase = "play"
	game.rules.balls.append({"id": 900, "owner": 0, "p": Vector2(0, 2), "v": Vector2.UP, "bounces": 0, "ttl": 4.0, "damage": 1, "boosted": false})
	game.rules.balls.append({"id": 901, "owner": 1, "p": Vector2(0, -2), "v": Vector2.DOWN, "bounces": 0, "ttl": 4.0, "damage": 1, "boosted": false})
	game.rules.balls.append({"id": 902, "owner": 0, "p": Vector2(1, 2), "v": Vector2.UP, "bounces": 0, "ttl": 4.0, "damage": 2, "boosted": true})
	arena.update_state(game.rules, 0, 1.0 / 60)
	var aura = func(id): return arena.projectiles[id].get_node("Aura").material_override.albedo_color
	check(aura.call(900) == Color(Color("b99cff"), 0.28), "Astrónomo shots glow violet")
	check(aura.call(901) == Color(cyan.lerp(coral, 1.0), 0.28), "Default rival keeps coral shots")
	check(floor_glow(arena.projectiles[900]) == Color(cyan, 0.42) and floor_glow(arena.projectiles[901]) == Color(coral, 0.42), "Floor glow shows team")
	check(aura.call(902) == Color(arena.GOLD, 0.45), "Boosted shots stay gold")
	game.rules.balls.clear()
	arena.update_state(game.rules, 0, 1.0 / 60)
	arena.set_skin(0, 0)

	# Viewer: preview a locked skin, drag to turn, idle spin and demo shots.
	hud.open_skins()
	check(hud.preview_index == 0 and hud.viewer_skin == 0 and is_instance_valid(hud.viewer_pilot), "Viewer opens on equipped pilot")
	hud.preview_skin(2)
	await process_frame
	check(hud.viewer_skin == 2 and hud.viewer_pilot.has_node("Body/OrbitTilt/Orbit") and hud.skin_name.text == "ASTRÓNOMO", "Previewing Astrónomo updates 3D model and name")
	check(hud.skin_thumbs.size() == Skins.CATALOG.size() and hud.viewer_bricks.size() == 2, "Shows all eleven skins and two exhibition bricks")
	check(hud.skin_action.disabled and hud.skin_action.text == "VENCE ESTE PILOTO" and hud.skin_state.text.begins_with("BLOQUEADA"), "Locked skin displays victory requirement and disabled action")
	check(hud.skins_button.text == "HANGAR  1/12", "Menu counts one unlocked skin")

	var drag = InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag.relative = Vector2(50, 0)
	var yaw_before = hud.viewer_yaw
	hud.viewer_input(drag)
	hud.animate_viewer(0.1)
	check(is_equal_approx(hud.viewer_yaw, yaw_before + 0.6), "Dragging rotates the preview turntable")
	hud.close_skins()

	# Campaign unlock flow: the Relojoeiro now guards level 5, and level 1 only trains.
	game.campaign.unlock_all = true
	game.start_level(0)
	check(game.arena.unit_skins[1] == 0, "Level 1 is a bout against a copy of the standard pilot")
	game.start_level(4) # Level 5 (index 4) has boss 6 (Relojoeiro)
	check(game.arena.unit_skins[1] == 6 and game.arena.unit_tints[1] == false, "The level 5 boss fights in the colours its own skin was drawn in")
	game.rules.phase = "finished"
	game.rules.winner = 0 # Player wins
	game.finish_level()
	check(game.skins.is_unlocked(6), "Winning the level unlocks the boss skin")
	check(hud.level_skin == "RELOJOEIRO", "HUD announces the unlocked boss skin")
	check(game.arena.unit_tints[1] == false, "After victory the boss drops the red tint and displays true colours")
	check(hud.skins_button.text.begins_with("HANGAR  2/12"), "Skins button updates count to 2/12")

	# Return to menu to equip newly unlocked skin
	game.return_to_menu()
	hud.open_skins()
	hud.preview_skin(6)
	check(hud.skin_action.text == "EQUIPAR" and not hud.skin_action.disabled, "Defeated boss skin is now equippable")
	hud.skin_selected.emit(6)
	check(game.skins.selected == 6 and game.arena.unit_skins[0] == 6 and hud.skin_action.text == "EQUIPADA" and hud.skin_action.disabled, "Equipping updates pilot and action text")
	hud.close_skins()

	# PvP networking
	game.mode = "client"
	game.local_team = 1
	game.dress_pilots(1)
	check(game.arena.unit_skins == [0, 6], "PvP client pilot dresses in equipped skin")
	game.share_skin(1)
	check(game.arena.unit_skins == [1, 6], "Rival's shared skin applies correctly")
	game.share_skin(99)
	check(game.arena.unit_skins == [1, 6], "Out-of-range skin ids are ignored")

	game.return_to_menu()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	print("SKINS_RESULT failures=", failures)
	quit(failures)
