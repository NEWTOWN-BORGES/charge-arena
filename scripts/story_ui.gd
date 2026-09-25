extends RefCounted
## The Taça's look, shared by the hub, the paper, the tree, the route and the versus card:
## a night-navy stadium with gold for the competition, mint for the player, coral for the
## rival, and cream paper with black ink for the press.
const Models = preload("res://scripts/indie_arena_view.gd")
const Taca = preload("res://scripts/tournament.gd")

const NIGHT = Color("08141b")
const NAVY = Color("0e2330")
const NAVY_LIGHT = Color("163446")
const LINE = Color("2a4b5a")
const GOLD = Color("e8bd78")
const GOLD_DEEP = Color("b88a3e")
const MINT = Color("81d9c4")
const CORAL = Color("ef947e")
const WHITE = Color("f2eee4")
const MUTED = Color("9fb3ba")
const PAPER = Color("f3eee1")
const PAPER_SHADE = Color("e2d9c6")
const INK = Color("16191c")
const INK_SOFT = Color("4a4f52")
const PRESS_RED = Color("b83a2b")

static var _fonts: Dictionary = {}

static func font(kind: String) -> Font:
	# display: the game's Rajdhani. headline / headline_black: Playfair Display, the paper's
	# titling. body / italic: Lora, the paper's text.
	if _fonts.has(kind):
		return _fonts[kind]
	var result: Font
	match kind:
		"headline", "headline_black":
			var f = FontVariation.new()
			f.base_font = load("res://art/fonts/press/PlayfairDisplay.ttf")
			f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 900 if kind == "headline_black" else 700}
			result = f
		"body", "body_bold":
			var f = FontVariation.new()
			f.base_font = load("res://art/fonts/press/Lora.ttf")
			f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700 if kind == "body_bold" else 450}
			result = f
		"italic":
			var f = FontVariation.new()
			f.base_font = load("res://art/fonts/press/Lora-Italic.ttf")
			f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 450}
			result = f
		_:
			result = load("res://art/fonts/Rajdhani-Bold.ttf")
	_fonts[kind] = result
	return result

static func label(text: String, size: int, color: Color, kind: String = "display", wrap: bool = true) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

static func panel_style(fill: Color, edge: Color = Color.TRANSPARENT, radius: int = 14, margin: int = 18) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(1 if edge.a > 0 else 0)
	s.set_corner_radius_all(radius)
	s.corner_detail = 8
	s.anti_aliasing = true
	s.set_content_margin_all(margin)
	return s

static func card(parent: Control, fill: Color = NAVY, edge: Color = LINE, margin: int = 18) -> VBoxContainer:
	var frame = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", panel_style(fill, edge, 14, margin))
	parent.add_child(frame)
	var stack = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	frame.add_child(stack)
	return stack

static func rule(parent: Control, color: Color, thick: int = 1) -> ColorRect:
	var line = ColorRect.new()
	line.color = color
	line.custom_minimum_size.y = thick
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)
	return line

static func gap(parent: Control, height: float) -> void:
	var g = Control.new()
	g.custom_minimum_size.y = height
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(g)

static func key(hud, text: String, primary: bool, action: Callable, height: float = 64) -> Button:
	# The game's own keys, so the Taça presses like the rest of it.
	var b: Button = hud.make_button(text, primary) if hud != null else Button.new()
	if hud == null: b.text = text
	b.custom_minimum_size.y = height
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(action)
	return b

static func spec(cup, who: String, player_skin: int) -> Array:
	# [skin, colour] to build a pilot from: the player's equipped hull, a boss in its own
	# palette, anyone else in the draw in the hull and colour the draw gave them.
	if who == Taca.PLAYER or who == "Tu": return [player_skin, "81d9c4"]
	if who == "Aurora": return [0, "ef947e"]
	var slot: int = cup.slot_of(who) if cup != null else -1
	if slot < 0: return [101, "8fa3aa"]
	var e: Dictionary = cup.entrant(slot)
	var hue = String(e.hue)
	return [int(e.skin), hue if hue != "" else "ef947e"]

class Snapshot extends SubViewport:
	## A still that develops over a moment instead of in one frame, then holds its picture.
	## Drawn once, a phone could send that single frame out before the model's materials
	## were ready, and the portrait stayed empty for good.
	var settle = 0.9
	func _ready() -> void:
		render_target_update_mode = SubViewport.UPDATE_ALWAYS
	func _process(dt: float) -> void:
		settle -= dt
		if settle <= 0.0:
			render_target_update_mode = SubViewport.UPDATE_DISABLED
			set_process(false)

static func pilot_render(cup, who: String, player_skin: int, turn: float = 0.0, pixels: Vector2i = Vector2i(420, 480)) -> TextureRect:
	# A still of the real model, lit like a portrait, rendered once into a texture.
	var image = TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport = Snapshot.new()
	viewport.size = pixels
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	image.add_child(viewport)
	var models = Models.new()
	models.quality_level = 2
	viewport.add_child(models)
	var entry: Array = spec(cup, who, player_skin)
	var pilot: Node3D = models.build_player(Color(String(entry[1])), 0, int(entry[0]))
	# The model is built at its seat in the arena; a portrait wants it in the middle.
	pilot.position = Vector3.ZERO
	pilot.rotation.y = PI + turn
	for rig in [[Vector3(-38, -30, 0), Color("ffe9cc"), 1.5], [Vector3(-20, 150, 0), Color("8fc8ff"), 0.9]]:
		var light = DirectionalLight3D.new()
		light.rotation_degrees = rig[0]
		light.light_color = rig[1]
		light.light_energy = rig[2]
		viewport.add_child(light)
	var world = WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_CLEAR_COLOR
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("b4dce3")
	world.environment.ambient_light_energy = 0.6
	world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	viewport.add_child(world)
	var camera = Camera3D.new()
	camera.fov = 26
	# Aimed through its transform: the viewport is not in the tree yet.
	camera.transform = Transform3D(Basis(), Vector3(0, 1.35, 5.4)).looking_at(Vector3(0, 0.95, 0), Vector3.UP)
	viewport.add_child(camera)
	image.texture = viewport.get_texture()
	return image
