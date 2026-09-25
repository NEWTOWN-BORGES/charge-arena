extends SceneTree
const OUT = "res://previews/premium/"
func _initialize(): call_deferred("run")
func capture(name):
	await process_frame
	await RenderingServer.frame_post_draw
	var img = root.get_texture().get_image()
	img.save_png(OUT + name + ".png")
	return img
func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(720,1280)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	if root.focus_exited.is_connected(game.pause_pve): root.focus_exited.disconnect(game.pause_pve)
	game.game_settings.config_path = "res://tests/premium-preview.tmp"
	game.set_process(false)
	game.set_physics_process(false)
	game.mode = "pve"
	game.rules.phase = "play"
	game.hud.show_game("pve",0)
	game.video.configure(60,2,false,false)
	game.video.apply(root,game.arena)
	game.arena.set_skin(0,5)
	game.arena.set_skin(1,10)
	game.hud.team_skins=[5,10]
	game.fit_content_scale()
	game.hud.layout()
	game.frame_arena()
	game.arena.update_state(game.rules,0,0.2)
	game.hud.update_match(game.rules,"")
	await capture("arena")
	game.arena.explosion(Vector2(1.2,-3.5),1.65)
	game.arena.CombatFinish.event(game.arena,{"kind":"explosion","p":Vector2(1.2,-3.5),"radius":1.65,"team":0},game.rules)
	game.arena.thunder_bolt(Vector2(-1.5,2.5),1.0)
	game.arena.CombatFinish.event(game.arena,{"kind":"thunder","p":Vector2(-1.5,2.5),"radius":1.0,"team":1},game.rules)
	game.arena.update_state(game.rules,0,0.18)
	await capture("combat")
	for i in range(90): game.arena.update_state(game.rules,0,1.0/60)
	game.video.configure(60,0,false,false)
	game.video.apply(root,game.arena)
	await capture("arena-leve")
	game.video.configure(60,2,false,false)
	game.video.apply(root,game.arena)
	root.size=Vector2i(512,640)
	game.hud.hide()
	game.arena.units[1].hide()
	var cam=game.arena.camera
	var shots=[]
	for skin in [0,5,10]:
		game.arena.set_skin(0,skin)
		var unit=game.arena.units[0]
		unit.get_node("Body").rotation.y=PI+0.35
		cam.projection=Camera3D.PROJECTION_PERSPECTIVE
		cam.fov=26
		cam.h_offset=0
		cam.v_offset=0
		cam.global_position=unit.global_position+Vector3(0,1.6,5.7)
		cam.look_at(unit.global_position+Vector3.UP*1.0)
		shots.append(await capture("skin-%d"%skin))
	var sheet=Image.create(1536,640,false,shots[0].get_format())
	for i in range(3): sheet.blit_rect(shots[i],Rect2i(0,0,512,640),Vector2i(i*512,0))
	sheet.save_png(OUT+"skins.png")
	# Full collection proof, including the differently shaped Aurel helmet.
	var catalog=Image.create(2048,1920,false,shots[0].get_format())
	for skin in range(12):
		game.arena.set_skin(0,skin)
		var unit=game.arena.units[0]
		unit.get_node("Body").rotation.y=PI+0.35
		cam.global_position=unit.global_position+Vector3(0,1.75,6.8)
		cam.look_at(unit.global_position+Vector3.UP*1.10)
		var shot=await capture("collection-%d"%skin)
		catalog.blit_rect(shot,Rect2i(0,0,512,640),Vector2i((skin%4)*512,(skin/4)*640))
	catalog.save_png(OUT+"collection.png")
	game.queue_free()
	await process_frame
	quit()
