extends SceneTree
const News = preload("res://scripts/cup_news.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var cup = preload("res://scripts/cup.gd").new()
	cup.complete([2, 0]) # Fixture starts after admission.
	for n in range(12):
		var stories = News.edition(cup, n)
		assert(stories.size() == 3)
		assert(stories[0].prioridade > stories[1].prioridade)
		for story in stories:
			assert(News.TYPES.has(story.tipo))
			assert(News.SCENES.has(story.cenario))
			assert(story.personagemPrincipal != "Nadir" or story.prioridade == 10)
		if n == 4: assert(stories[0].personagemSecundario == "Lira")
		if n == 5: assert(stories[0].personagemPrincipal == "Faroleiro")
		if n < 11: cup.complete([2, n % 2])
	var earlier = News.edition(cup, 3)
	assert(earlier[0].personagemPrincipal == "Lira")
	for template in News.SCENES:
		var photo = preload("res://scripts/news_scene.gd").new()
		root.add_child(photo)
		var story = earlier[0].duplicate()
		story.cenario = template
		photo.setup(story)
		assert(photo.render_target_update_mode == SubViewport.UPDATE_ONCE)
		photo.free()
	var screen = preload("res://scripts/cup_screen.gd").new()
	screen.cup = cup
	root.add_child(screen)
	screen.tab = 2
	screen.refresh()
	var journal = screen.content.get_child(0)
	journal.article(earlier[0])
	assert(journal.opened_id == "03_cover")
	journal.edition_number = 4
	journal.front()
	assert(journal.opened_id.is_empty())
	assert(not screen.footer.visible)
	screen.free()
	print("PASS: editions, narrative priorities, templates, article/archive navigation")
	quit()
