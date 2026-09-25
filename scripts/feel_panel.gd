extends Control
## The gun-feel tuning panel (debug). Every parameter of CombatFeel as a slider, applied
## live, saved on close; the last shot's measured latency; a reset; and the test range -
## a match with the rival standing still, to fire, hit, break and score against.
signal range_requested
const CombatFeel = preload("res://scripts/combat_feel.gd")
const FONT = preload("res://art/fonts/Rajdhani-SemiBold.ttf")
const FONT_BOLD = preload("res://art/fonts/Rajdhani-Bold.ttf")
const INK = Color("071116")
const CYAN = Color("81d9c4")
const WHITE = Color("eef3ef")
const MUTED = Color("8ea4a3")

var feel
var sliders: Dictionary = {}
var readouts: Dictionary = {}
var latency_label: Label
var clock = 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var ground = ColorRect.new()
	ground.color = Color(INK, 0.94)
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ground)
	var scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 6)
	scroll.add_child(column)
	column.add_child(text("AFINAÇÃO DOS TIROS", 30, CYAN, true))
	column.add_child(text("Ferramenta de afinação: aplica-se já, guarda-se ao fechar. Não mexe em dano nem em equilíbrio.", 15, MUTED))
	latency_label = text("", 15, WHITE)
	column.add_child(latency_label)
	for name in CombatFeel.PARAMS.keys():
		var spec: Array = CombatFeel.PARAMS[name]
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		column.add_child(row)
		var caption = text(String(spec[4]), 15, WHITE)
		caption.custom_minimum_size.x = 250
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(caption)
		var slider = HSlider.new()
		slider.min_value = float(spec[1])
		slider.max_value = float(spec[2])
		slider.step = float(spec[3])
		slider.value = feel.value(name)
		slider.custom_minimum_size = Vector2(180, 44)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(func(v): changed(name, v))
		row.add_child(slider)
		var shown = text("", 15, CYAN)
		shown.custom_minimum_size.x = 64
		row.add_child(shown)
		sliders[name] = slider
		readouts[name] = shown
		show_value(name)
	var keys = HBoxContainer.new()
	keys.add_theme_constant_override("separation", 10)
	column.add_child(keys)
	keys.add_child(key("REPOR", func():
		feel.reset()
		for name in sliders.keys():
			sliders[name].set_value_no_signal(feel.value(name))
			show_value(name)))
	keys.add_child(key("CAMPO DE TESTE", func():
		feel.save_preferences()
		range_requested.emit()))
	keys.add_child(key("FECHAR", func():
		feel.save_preferences()
		queue_free()))
	resized.connect(arrange)
	arrange()

func arrange() -> void:
	var scroll: Control = get_node("Scroll")
	var width = minf(size.x - 32, 760)
	scroll.position = Vector2((size.x - width) * 0.5, 24)
	scroll.size = Vector2(width, size.y - 48)

func text(value: String, font_size: int, color: Color, bold: bool = false) -> Label:
	var label = Label.new()
	label.text = value
	label.add_theme_font_override("font", FONT_BOLD if bold else FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func key(caption: String, action: Callable) -> Button:
	var b = Button.new()
	b.text = caption
	b.custom_minimum_size = Vector2(0, 56)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_override("font", FONT_BOLD)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(action)
	return b

func changed(name: String, v: float) -> void:
	feel.set_value(name, v)
	show_value(name)

func show_value(name: String) -> void:
	var v = feel.value(name)
	readouts[name].text = ("%.0f ms" % (v * 1000.0)) if String(CombatFeel.PARAMS[name][4]).ends_with("(s)") else ("%.2f" % v)

func _process(dt: float) -> void:
	clock += dt
	if clock < 0.25:
		return
	clock = 0.0
	var l: Dictionary = feel.latency
	if float(l.input_to_spawn_ms) < 0.0:
		latency_label.text = "Latência: dispara um tiro manual para medir."
		return
	latency_label.text = "Último tiro · toque→tiro %.1f ms · tiro→imagem %.1f ms · toque→imagem %.1f ms · saída de áudio %.0f ms" % [float(l.input_to_spawn_ms), maxf(float(l.spawn_to_frame_ms), 0.0), maxf(float(l.input_to_frame_ms), 0.0), float(l.audio_output_ms)]
