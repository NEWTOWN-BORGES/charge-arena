extends Control
## Non-modal, queued reward banners. Only the close button consumes touches.
var painter
var pending: Array = []
var current: Dictionary = {}
var remaining = 0.0
var card: Panel
var icon: Control
var heading: Label
var title: Label
var close: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card = Panel.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame = StyleBoxFlat.new()
	frame.bg_color = Color("152e38")
	frame.border_color = Color("537a79")
	frame.set_border_width_all(1)
	frame.set_corner_radius_all(18)
	frame.shadow_color = Color(0, 0, 0, 0.22)
	frame.shadow_size = 5
	card.add_theme_stylebox_override("panel", frame)
	add_child(card)
	icon = Control.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.position = Vector2(9, 8)
	icon.size = Vector2(56, 56)
	icon.draw.connect(draw_item)
	card.add_child(icon)
	heading = Label.new()
	heading.position = Vector2(73, 12)
	heading.add_theme_font_size_override("font_size", 11)
	heading.add_theme_color_override("font_color", Color("81d9c4"))
	card.add_child(heading)
	title = Label.new()
	title.position = Vector2(73, 31)
	title.add_theme_font_override("font", painter.font_bold)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("f3f1e8"))
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	card.add_child(title)
	for label in [heading, title]: label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	close = Button.new()
	close.text = "×"
	close.tooltip_text = "Fechar notificação"
	close.flat = true
	close.size = Vector2(44, 44)
	close.add_theme_font_size_override("font_size", 24)
	close.pressed.connect(dismiss)
	card.add_child(close)
	resized.connect(arrange)
	arrange()
	card.hide()
	set_process(false)

func arrange() -> void:
	var width = minf(344, maxf(240, size.x - 24))
	card.size = Vector2(width, 72)
	card.position = Vector2((size.x - width) * 0.5, painter.safe_top + 12)
	close.position = Vector2(width - 46, 14)
	title.size = Vector2(width - 123, 28)
	heading.size = Vector2(width - 123, 18)

func enqueue(item: Dictionary) -> void:
	if item == current or pending.has(item): return
	pending.append(item.duplicate())
	if current.is_empty(): show_next()

func show_next() -> void:
	if pending.is_empty():
		current = {}
		card.hide()
		set_process(false)
		return
	current = pending.pop_front()
	heading.text = "SKIN DESBLOQUEADA" if current.kind == "skin" else "PODER DESBLOQUEADO"
	title.text = current.name
	remaining = 4.0
	arrange()
	icon.queue_redraw()
	card.show()
	set_process(true)

func dismiss() -> void:
	show_next()

func _process(dt: float) -> void:
	remaining -= dt
	# Short opacity transition; no sliding across controls or continuous redraw.
	card.modulate.a = minf(clampf((4.0 - remaining) / 0.18, 0, 1), clampf(remaining / 0.2, 0, 1))
	if remaining <= 0: show_next()

func draw_item() -> void:
	if current.is_empty(): return
	icon.draw_circle(Vector2(28, 28), 27, Color("203f49"), true, -1, true)
	if current.kind == "skin":
		icon.draw_set_transform(Vector2(28, 29), 0, Vector2.ONE * 0.53)
		painter.portrait(Vector2.ZERO, Color("81d9c4"), false, int(current.id), icon)
		icon.draw_set_transform(Vector2.ZERO)
	else:
		painter.power_icon(current.id, Vector2(28, 28), Color("e8bd78"), icon, 0.75)
