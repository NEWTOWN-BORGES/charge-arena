extends Control
signal picked(key: String)
signal interaction
const GOLD = Color("e8bd78")
const MINT = Color("81d9c4")
var nodes: Array = []
var edges: Array = []
var portraits: Dictionary = {}
var pan = Vector2(20, 20)
var zoom = 1.0
var dragging = false
var origin = Vector2.ZERO
var distance_dragged = 0.0
var fingers: Dictionary = {}
func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(input_map)
func locate(key: String) -> void:
	for node in nodes:
		if node.key == key:
			pan = size * 0.5 - node.rect.get_center() * zoom
			queue_redraw()
			return
func fit() -> void:
	zoom = clampf(size.x / 1030.0, 0.45, 1.1)
	pan = Vector2((size.x - 1000 * zoom) * 0.5, 24)
	queue_redraw()
func scale_at(factor: float, anchor: Vector2) -> void:
	var before = zoom
	zoom = clampf(zoom * factor, 0.35, 1.8)
	pan = anchor - (anchor - pan) * zoom / before
	queue_redraw()
func hit(pos: Vector2) -> void:
	var world = (pos - pan) / zoom
	for i in range(nodes.size() - 1, -1, -1):
		if nodes[i].rect.has_point(world):
			picked.emit(nodes[i].key)
			return
func input_map(event: InputEvent) -> void:
	if event is InputEventMagnifyGesture:
		scale_at(event.factor, event.position)
	elif event is InputEventPanGesture:
		pan -= event.delta * 16
		queue_redraw()
	elif event is InputEventScreenTouch:
		if event.pressed:
			fingers[event.index] = event.position
			origin = event.position
			distance_dragged = 100 if fingers.size() > 1 else 0
		else:
			fingers.erase(event.index)
			if distance_dragged < 12: hit(event.position)
	elif event is InputEventScreenDrag:
		if fingers.size() >= 2:
			distance_dragged = 100
			var positions = fingers.values()
			var before: float = positions[0].distance_to(positions[1])
			fingers[event.index] = event.position
			positions = fingers.values()
			if before > 5: scale_at(positions[0].distance_to(positions[1]) / before, (positions[0] + positions[1]) * 0.5)
		else:
			fingers[event.index] = event.position
			pan += event.relative
			distance_dragged += event.relative.length()
		queue_redraw()
	elif event is InputEventMouseButton and event.device != -1:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed: scale_at(1.15, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed: scale_at(1 / 1.15, event.position)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if dragging:
				origin = event.position
				distance_dragged = 0
			elif distance_dragged < 12: hit(event.position)
	elif event is InputEventMouseMotion and dragging:
		pan += event.relative
		distance_dragged += event.relative.length()
		queue_redraw()
	accept_event()
func words(value: String, pos: Vector2, points: int, color: Color, width: float) -> void:
	draw_string(ThemeDB.fallback_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, width, points, color)
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0b1b24"))
	for x in range(0, int(size.x), 48):
		for y in range(0, int(size.y), 48): draw_circle(Vector2(x, y), 1, Color("20363e"))
	draw_set_transform(pan, 0, Vector2.ONE * zoom)
	for edge in edges:
		var a: Vector2 = edge[0]
		var b: Vector2 = edge[1]
		var color: Color = edge[2]
		var middle = (a.y + b.y) * 0.5
		draw_polyline(edge[3] if edge.size() > 3 else PackedVector2Array([a, Vector2(a.x, middle), Vector2(b.x, middle), b]), color, 4 if color == MINT else 2, true)
		draw_circle(b, 5, color)
	for node in nodes:
		var rect: Rect2 = node.rect
		var accent: Color = node.get("accent", Color("36525d"))
		var style = StyleBoxFlat.new()
		style.bg_color = Color("16323d") if node.key == "Tu" else Color("122731")
		style.border_color = accent
		style.set_border_width_all(3 if node.key == "Tu" else 1)
		style.set_corner_radius_all(14)
		draw_style_box(style, rect)
		if node.key == "future":
			var trophy = rect.position + Vector2(rect.size.x - 40, 35)
			draw_polygon(PackedVector2Array([trophy + Vector2(-13, -12), trophy + Vector2(13, -12), trophy + Vector2(8, 6), trophy + Vector2(-8, 6)]), PackedColorArray([GOLD]))
			draw_line(trophy + Vector2(0, 6), trophy + Vector2(0, 20), GOLD, 4)
			draw_line(trophy + Vector2(-12, 20), trophy + Vector2(12, 20), GOLD, 4)
		var p: Vector2 = rect.position + Vector2(16, 27)
		words(node.get("tag", ""), p, 18, accent.lightened(0.2), rect.size.x - 30)
		var has_portrait = portraits.has(node.get("person", ""))
		if has_portrait:
			draw_texture_rect(portraits[node.person], Rect2(p + Vector2(-4, 6), Vector2(116, 116) if node.key == "Tu" else Vector2(88, 88)), false, Color(0.55, 0.6, 0.63) if node.get("out", false) else Color.WHITE)
		var text_x = (132 if node.key == "Tu" else 100) if node.has("person") else 0
		words(node.title, p + Vector2(text_x, 40), 26, Color("f2eee4"), rect.size.x - text_x - 30)
		words(node.get("sub", ""), p + Vector2(text_x, 70), 20, Color("b5c9cd"), rect.size.x - text_x - 30)
		words(node.get("status", ""), p + Vector2(0, rect.size.y - 44), 18, Color("e19a83") if node.get("out", false) else accent.lightened(0.15), rect.size.x - 30)
		if node.get("out", false):
			draw_line(rect.position + Vector2(rect.size.x - 30, 18), rect.position + Vector2(rect.size.x - 18, 30), Color("e19a83"), 3)
			draw_line(rect.position + Vector2(rect.size.x - 18, 18), rect.position + Vector2(rect.size.x - 30, 30), Color("e19a83"), 3)
	draw_set_transform(Vector2.ZERO)
