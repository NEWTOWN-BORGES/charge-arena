extends SceneTree
# Verifica que um telemóvel consegue navegar nos menus por toque sem que
# esses toques sejam confundidos com disparos dentro da partida.
var failures = 0

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: ", description)

func _initialize() -> void:
	call_deferred("run")

func find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node
	for child in node.get_children():
		var found = find_button(child, text)
		if found != null:
			return found
	return null

func mouse_event(position: Vector2, down: bool, emulated: bool) -> InputEventMouseButton:
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = position
	event.global_position = position
	event.device = InputEvent.DEVICE_ID_EMULATION if emulated else 0
	return event

func run() -> void:
	check(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", false),
		"O projeto emula rato a partir do toque, para os botões do menu responderem no telemóvel")

	# Headless abre uma janela 64x64; sem isto os botões caem fora da área de toque.
	root.size = Vector2i(1280, 720)
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var hud = scene.hud

	var play: Button = hud.campaign_button
	check(play != null and play.visible and find_button(hud.menu, "JOGO RÁPIDO") != null, "Os botões de campanha e jogo rápido existem e estão visíveis no menu")
	check(play != null and play.mouse_filter != Control.MOUSE_FILTER_IGNORE,
		"O botão de jogar aceita eventos de ponteiro")

	# O DisplayServer headless não entrega cliques a Controls, por isso aqui
	# verifica-se que o ponteiro emulado pelo toque chega mesmo ao botão.
	# A pressão final confirma-se no aparelho.
	if play != null:
		var center = play.get_global_rect().get_center()
		var motion = InputEventMouseMotion.new()
		motion.position = center
		motion.global_position = center
		motion.device = InputEvent.DEVICE_ID_EMULATION
		root.push_input(motion)
		await process_frame
	check(root.gui_get_hovered_control() == play,
		"Um toque emulado aterra no botão de jogar, e não no fundo do menu")

	scene.start_pve()
	await process_frame
	scene.mouse_firing = false
	scene._unhandled_input(mouse_event(Vector2(640, 600), true, true))
	check(not scene.mouse_firing, "Um toque emulado na arena não dispara — só o botão de fogo do HUD dispara")

	scene._unhandled_input(mouse_event(Vector2(640, 600), true, false))
	check(scene.mouse_firing, "O rato verdadeiro continua a disparar no PC")

	scene._input(mouse_event(Vector2(640, 600), false, true))
	check(scene.mouse_firing, "Um largar emulado não cancela o disparo feito com o rato")

	scene._input(mouse_event(Vector2(640, 600), false, false))
	check(not scene.mouse_firing, "Largar o rato verdadeiro pára o disparo")

	print("MOBILE_INPUT_RESULT failures=", failures)
	quit(failures)
