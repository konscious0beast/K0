extends Control
## The player's hand (10 §4.2, §4.6): five card views in a row (desktop / gamepad) or a light fan (touch: an arc, the
## outer cards lower), the marked card lifted 24 px. Focus IS the marking: ← / → (ui_left / ui_right, D-pad, stick)
## walk the cards (wrapping), a click or tap marks, a second tap or a double click plays. Gestures on a card (mouse and
## touch alike, touch arrives as emulated mouse events): press + move ≥ 12 px drags it (tap ≠ drag, 07 E19) — dropped
## on the counter it is played, on the Ablage it is filed (the table decides from the drop point); a long press of
## 0.4 s opens the big view. Signals only — the table validates and submits.

signal marked(slot: int)
signal tapped(slot: int)
signal play_requested(slot: int)
signal big_requested(slot: int)
signal drag_moved(slot: int, global_pos: Vector2)
signal dropped(slot: int, global_pos: Vector2)

const SdStyle := preload("res://scenes/stempel/sd_style.gd")
const CardView := preload("res://scenes/stempel/sd_card_view.gd")

const DRAG_PX: float = 12.0
const LONG_PRESS_SEC: float = 0.4
const LIFT_SEC: float = 0.12
const FAN_DROP: Array[float] = [14.0, 5.0, 0.0, 5.0, 14.0]   # touch fan: how much lower the outer cards sit

var touch: bool = false
var fan: bool = true                                # touch: the light arc (off when the layout needs the room)
var card_w: float = 0.0                             # narrower cards on narrow touch screens (0 = the scheme's size)
var card_gap: float = -1.0                          # gap between the cards (-1 = the scheme's gap)
var text_size: int = 100
var reduce_motion: bool = false
var back_id: String = ""
var interactive: bool = true                        # off while events play / the opponent moves
var views: Array[Control] = []                      # sd_card_view.gd per slot
var marked_slot: int = -1

var _ids: PackedStringArray = []
var _book: SdRulebook = null
var _press_slot: int = -1
var _press_pos: Vector2 = Vector2.ZERO
var _press_t: float = 0.0
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _long_timer: Timer = null
var _long_fired: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_long_timer = Timer.new()
	_long_timer.one_shot = true
	_long_timer.wait_time = LONG_PRESS_SEC
	_long_timer.timeout.connect(_on_long_press)
	add_child(_long_timer)
	resized.connect(layout_cards.bind(false))


## Shows `ids` (hand order = slots). Views of unchanged slots are kept.
func set_cards(ids: PackedStringArray, book: SdRulebook) -> void:
	_book = book
	_ids = ids.duplicate()
	while views.size() > ids.size():
		var v: Control = views.pop_back()
		v.queue_free()
	for i in ids.size():
		var c: SdCardDef = book.card(ids[i])
		if i >= views.size():
			var v2: Control = CardView.new()
			v2.name = "Card%d" % (i + 1)
			v2.mouse_filter = Control.MOUSE_FILTER_STOP
			v2.focus_mode = Control.FOCUS_ALL
			var slot: int = i
			v2.gui_input.connect(func(e: InputEvent) -> void: _on_card_input(slot, e))
			v2.focus_entered.connect(func() -> void: _on_focus(slot))
			add_child(v2)
			views.append(v2)
		var view: Control = views[i]
		if view.get("card") != c or bool(view.get("touch")) != touch or int(view.get("text_size")) != text_size:
			view.call("setup", c, touch, text_size, false)
		view.set("back_id", back_id)
	_wire_focus()
	if marked_slot >= ids.size():
		marked_slot = ids.size() - 1
	layout_cards(false)


func ids() -> PackedStringArray:
	return _ids.duplicate()


## Card positions in the hand rect (the hand's own coordinates; lift of the marked card included).
func slot_rect(i: int) -> Rect2:
	var cs: Vector2 = SdStyle.card_size(touch)
	if card_w > 0.0:
		cs.x = card_w
	var n: int = maxi(1, _ids.size())
	var gap: float = card_gap if card_gap >= 0.0 else default_gap(touch)
	var total: float = n * cs.x + (n - 1) * gap
	var x0: float = (size.x - total) * 0.5
	var y: float = size.y - cs.y
	if touch and fan and n == FAN_DROP.size():
		y -= FAN_DROP[0]
		y += FAN_DROP[i]
	if i == marked_slot:
		y -= SdStyle.LIFT
	return Rect2(Vector2(x0 + i * (cs.x + gap), y), cs)


## Width the hand needs (five cards + gaps; `p_card_w` / `p_gap` < 0: the scheme's).
static func needed_width(p_touch: bool, n: int = 5, p_card_w: float = -1.0, p_gap: float = -1.0) -> float:
	var w: float = p_card_w if p_card_w > 0.0 else SdStyle.card_size(p_touch).x
	return n * w + (n - 1) * (p_gap if p_gap >= 0.0 else default_gap(p_touch))


## Gap between two cards: 12 px, touch 16 px.
static func default_gap(p_touch: bool) -> float:
	return SdStyle.GAP + (4.0 if p_touch else 0.0)


func layout_cards(animate: bool = true) -> void:
	for i in views.size():
		var v: Control = views[i]
		if _dragging and i == _press_slot:
			continue
		var r: Rect2 = slot_rect(i)
		v.custom_minimum_size = r.size
		v.size = r.size
		if animate and not reduce_motion and is_inside_tree():
			var tw: Tween = v.create_tween()
			tw.tween_property(v, "position", r.position, LIFT_SEC)
		else:
			v.position = r.position


## Marks `slot` (focus follows; -1 clears).
func mark(slot: int, grab: bool = true) -> void:
	marked_slot = slot
	for i in views.size():
		views[i].set("marked", i == slot)
	if grab and slot >= 0 and slot < views.size() and not views[slot].has_focus():
		views[slot].grab_focus()
	layout_cards(true)


## The Graf's tip (paw badge), the Lernduell's forced card (gold glow) and the others dimmed while it is forced.
func set_flags(recommended: int, forced: int, dim_others: bool) -> void:
	for i in views.size():
		views[i].set("recommended", i == recommended)
		views[i].set("highlight", 1.0 if i == forced else 0.0)
		views[i].set("dim", dim_others and forced >= 0 and i != forced)


func view(slot: int) -> Control:
	return views[slot] if slot >= 0 and slot < views.size() else null


func _wire_focus() -> void:
	var n: int = views.size()
	for i in n:
		var v: Control = views[i]
		v.focus_neighbor_left = v.get_path_to(views[(i - 1 + n) % n])
		v.focus_neighbor_right = v.get_path_to(views[(i + 1) % n])
		v.focus_neighbor_top = v.get_path_to(v)
		v.focus_neighbor_bottom = v.get_path_to(v)
		v.focus_previous = v.get_path_to(views[(i - 1 + n) % n])
		v.focus_next = v.get_path_to(views[(i + 1) % n])


func _on_focus(slot: int) -> void:
	if marked_slot != slot:
		mark(slot, false)
		marked.emit(slot)


# --- gestures -----------------------------------------------------------------------------------------------------

func _on_card_input(slot: int, e: InputEvent) -> void:
	if not interactive:
		return
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: InputEventMouseButton = e
		if mb.pressed:
			if mb.double_click:
				_reset_press()
				play_requested.emit(slot)
				accept_event()
				return
			_press_slot = slot
			_press_pos = mb.global_position
			_dragging = false
			_long_fired = false
			_long_timer.start(LONG_PRESS_SEC)
			accept_event()
		elif _press_slot == slot:
			_long_timer.stop()
			if _dragging:
				_dragging = false
				dropped.emit(slot, mb.global_position)
				views[slot].z_index = 0
				layout_cards(true)
			elif not _long_fired:
				tapped.emit(slot)
			_reset_press()
			accept_event()
	elif e is InputEventMouseMotion and _press_slot == slot:
		var mm: InputEventMouseMotion = e
		if not _dragging and mm.global_position.distance_to(_press_pos) >= DRAG_PX and not _long_fired:
			_dragging = true
			_long_timer.stop()
			var v: Control = views[slot]
			v.z_index = 10
			_drag_offset = v.global_position - _press_pos
		if _dragging:
			views[slot].global_position = mm.global_position + _drag_offset
			drag_moved.emit(slot, mm.global_position)
		accept_event()


func _on_long_press() -> void:
	if _press_slot >= 0 and not _dragging:
		_long_fired = true
		big_requested.emit(_press_slot)


func _reset_press() -> void:
	_press_slot = -1
	_dragging = false
	_long_timer.stop()


func is_dragging() -> bool:
	return _dragging


## Test seam: a tap (press + release without movement) on `slot`.
func simulate_tap(slot: int) -> void:
	var v: Control = view(slot)
	if v == null:
		return
	var p: Vector2 = v.get_global_rect().get_center()
	_on_card_input(slot, _mouse(true, p))
	_on_card_input(slot, _mouse(false, p))


## Test seam: drag `slot` from its centre to `to` (global) and drop it there.
func simulate_drag(slot: int, to: Vector2) -> void:
	var v: Control = view(slot)
	if v == null:
		return
	var p: Vector2 = v.get_global_rect().get_center()
	_on_card_input(slot, _mouse(true, p))
	var mm: InputEventMouseMotion = InputEventMouseMotion.new()
	mm.global_position = to
	mm.position = to
	_on_card_input(slot, mm)
	_on_card_input(slot, _mouse(false, to))


static func _mouse(pressed: bool, p: Vector2) -> InputEventMouseButton:
	var mb: InputEventMouseButton = InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = pressed
	mb.global_position = p
	mb.position = p
	return mb
