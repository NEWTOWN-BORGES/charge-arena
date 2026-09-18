extends SceneTree
# Writes the ultimate cues the game synthesises, exactly as they are played.

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var out = "C:/Users/ADMIN/AppData/Local/Temp/charge-sounds/"
	DirAccess.make_dir_recursive_absolute(out)
	for name in ["charging", "unleash", "sun_ray", "meteor", "thunder", "bloom", "plunder", "power", "ready", "blast"]:
		var stream = game.tones.get(name)
		if stream is AudioStreamWAV:
			stream.save_to_wav(out + name + ".wav")
			print("GRAVADO ", name, " ", stream.data.size() / 2, " amostras")
	quit()
