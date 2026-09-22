extends Node
## Drag scrolling shared by menus. A drag cancels a button tap; sliders keep their gestures.
var surface: Callable
var target: ScrollContainer
var start = Vector2.ZERO
var last = Vector2.ZERO
var dragging = false
var finger = -2
var velocity = Vector2.ZERO
var last_motion = 0
var last_touch = -1000
const DEADZONE = 10.0

func collect(node: Node, found: Array) -> void:
	if node is Control and not node.is_visible_in_tree(): return
	if node is ScrollContainer:
		# The gesture owner handles wheel and drag; native scrollbar handles still work.
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		found.append(node)
	for child in node.get_children(): collect(child, found)

func clipped_rect(control: Control) -> Rect2:
	var rect = control.get_global_rect()
	var parent = control.get_parent()
	while parent is Control:
		if parent.clip_contents: rect = rect.intersection(parent.get_global_rect())
		parent = parent.get_parent()
	return rect

func find_scroll(at: Vector2) -> ScrollContainer:
	if not surface.is_valid(): return null
	var root = surface.call()
	if not is_instance_valid(root): return null
	var found: Array = []
	collect(root, found)
	found.reverse()
	for scroll in found:
		if clipped_rect(scroll).has_point(at):
			for node in scroll.find_children("*", "Range", true, false):
				# A progress bar is a Range the finger never drags, so it must not
				# punch a dead band through the middle of a list.
				if node is ProgressBar: continue
				if node.is_visible_in_tree() and clipped_rect(node).has_point(at): return null
			return scroll
	return null

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		last_touch = Time.get_ticks_msec()
		if event.pressed:
			if finger == -2: begin(event.position, event.index)
		elif event.index == finger: finish()
	elif event is InputEventScreenDrag and event.index == finger:
		last_touch = Time.get_ticks_msec()
		move(event.position)
	elif event is InputEventMouseButton:
		if Time.get_ticks_msec() - last_touch < 300: return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: begin(event.position, -1)
			elif finger == -1: finish()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			var scroller = find_scroll(event.position)
			if scroller == null: return
			var direction = -1.0 if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT] else 1.0
			var horizontal = event.shift_pressed or scroller.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED or event.button_index in [MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]
			scroll_by(scroller, Vector2(direction * 70 * event.factor, 0) if horizontal else Vector2(0, direction * 70 * event.factor))
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and finger == -1:
		move(event.position)

func begin(at: Vector2, id: int) -> void:
	velocity = Vector2.ZERO
	target = find_scroll(at)
	if target == null: return
	start = at
	last = at
	finger = id
	dragging = false
	last_motion = Time.get_ticks_msec()

func move(at: Vector2) -> void:
	if not is_instance_valid(target) or not target.is_visible_in_tree():
		cancel()
		return
	if not dragging and at.distance_to(start) < DEADZONE: return
	if not dragging:
		dragging = true
		target.propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
		for button in target.find_children("*", "BaseButton", true, false):
			if not button.toggle_mode: button.set_pressed_no_signal(false)
	var delta = last - at
	var now = Time.get_ticks_msec()
	velocity = delta / maxf(0.016, (now - last_motion) / 1000.0)
	velocity = velocity.limit_length(2200)
	scroll_by(target, delta)
	last = at
	last_motion = now
	get_viewport().set_input_as_handled()

func scroll_by(scroller: ScrollContainer, delta: Vector2) -> void:
	if scroller.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		scroller.scroll_horizontal += roundi(delta.x)
	if scroller.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		scroller.scroll_vertical += roundi(delta.y)

func finish() -> void:
	if dragging:
		get_viewport().set_input_as_handled()
		if is_instance_valid(target): target.propagate_notification(Control.NOTIFICATION_SCROLL_END)
	if Time.get_ticks_msec() - last_motion > 100: velocity = Vector2.ZERO
	finger = -2
	dragging = false

func cancel() -> void:
	if dragging and is_instance_valid(target): target.propagate_notification(Control.NOTIFICATION_SCROLL_END)
	target = null
	finger = -2
	dragging = false
	velocity = Vector2.ZERO

func _process(dt: float) -> void:
	if not is_instance_valid(target): return
	if not target.is_visible_in_tree() or not surface.call().is_ancestor_of(target):
		cancel()
		return
	if finger != -2 or velocity.length() < 10: return
	scroll_by(target, velocity * minf(dt, 0.05))
	velocity = velocity.move_toward(Vector2.ZERO, 4200 * dt)
