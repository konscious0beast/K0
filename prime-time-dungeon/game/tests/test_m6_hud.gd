extends TestCase
## ExplorationHud (02_TECH §9.5, GDD §14.3, 03_ART §9.2): public API (bind_layout / set_player / mark_visited /
## set_prompt / set_quest), floor timer (hidden until the countdown starts, < 5:00 sodium, < 1:00 red + pulse, expired
## 00:00), party mini status, touch prompt icon, pause menu / big map open the modal and pause the tree, minimap view.

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const MinimapScript := preload("res://scenes/ui/minimap.gd")
const SCENE_HUD: String = "res://scenes/ui/exploration_hud.tscn"
const SCENE_TOUCH: String = "res://scenes/ui/touch_controls.tscn"


func before_each() -> void:
	Engine.time_scale = 8.0
	tree.paused = false
	Game.new_game(0, "Kai", 11)
	if Game.state.floor_run != null:
		Game.state.floor_run.timer_started = false


func after_each() -> void:
	Engine.time_scale = 1.0
	tree.paused = false
	Router.adopt(null)


func _hud() -> ExplorationHud:
	var h: ExplorationHud = (load(SCENE_HUD) as PackedScene).instantiate() as ExplorationHud
	add_to_tree(h)
	return h


func test_layer_and_children() -> void:
	var h: ExplorationHud = _hud()
	await wait_frames(2)
	assert_eq(h.layer, 5, "HUD layer 5 (§9.4)")
	assert_not_null(h.minimap, "minimap")
	assert_not_null(h.touch, "touch layer child")
	if h.touch != null:
		assert_eq(h.touch.layer, 20, "touch layer 20")


func test_timer_hidden_until_started_then_colors() -> void:
	var h: ExplorationHud = _hud()
	await wait_frames(2)
	assert_false(h.is_timer_visible(), "no countdown before the tutorial battle")
	Events.floor_timer_changed.emit(1200)
	assert_true(h.is_timer_visible(), "first tick shows the timer")
	assert_eq(h.timer_text(), "20:00")
	assert_eq(h.timer_color(), UiTheme.C_TEXT, "normal colour")
	Events.floor_timer_changed.emit(299)
	assert_eq(h.timer_text(), "04:59")
	assert_eq(h.timer_color(), UiUtil.C_SODIUM, "< 5:00 sodium orange")
	Events.floor_timer_changed.emit(59)
	assert_eq(h.timer_color(), UiUtil.C_LIVE, "< 1:00 live red")
	await wait_frames(20)
	var panel: Control = h.find_child("Timer", true, false) as Control
	assert_not_null(panel, "timer panel")
	var scales: Array[float] = []
	for i in 30:
		scales.append(panel.scale.x)
		await wait_frames(1)
	assert_gt(scales.max(), 1.0, "red timer pulses (scale 1.0 ↔ 1.08)")
	assert_true(float(scales.max()) <= 1.081, "pulse amplitude 8 %")
	Events.floor_timer_expired.emit()
	assert_eq(h.timer_text(), "00:00")


func test_timer_started_signal_shows_remaining_time() -> void:
	var h: ExplorationHud = _hud()
	await wait_frames(2)
	assert_false(h.is_timer_visible())
	Events.floor_timer_started.emit()
	assert_true(h.is_timer_visible(), "floor_timer_started shows the countdown")
	assert_eq(h.timer_text(), UiUtil.fmt_time(floori(Game.time_left())))
	# Start pop 1.3 → 1.0 (regression: the per-frame scale reset of _process undid it before a tween's first step).
	var panel: Control = h.find_child("Timer", true, false) as Control
	await wait_frames(1)
	assert_gt(panel.scale.x, 1.05, "the pop is still visible one frame later")
	var ok: bool = await wait_until(func() -> bool: return is_equal_approx(panel.scale.x, 1.0), 60)
	assert_true(ok, "pop settles back to 1.0")


func test_prompt_and_touch_icon() -> void:
	var h: ExplorationHud = _hud()
	await wait_frames(2)
	h.set_prompt("Truhe öffnen")
	assert_eq(h.prompt_text(), "Truhe öffnen")
	var panel: Control = h.find_child("Prompt", true, false) as Control
	assert_true(panel != null and panel.visible, "prompt panel visible")
	var action: Button = (h.touch.get("buttons") as Dictionary).get(&"action") as Button if h.touch != null else null
	if action != null:
		assert_eq(action.get_node("Icon").get("kind"), &"hand", "touch action shows the hand with a prompt")
	h.set_prompt("")
	assert_eq(h.prompt_text(), "")
	assert_false(panel.visible, "empty prompt hides")
	if action != null:
		assert_eq(action.get_node("Icon").get("kind"), &"fist", "field strike without a prompt")


## M3 CR 4: the quest line comes from the live QuestTracker (label key translation, else text from its definition).
func test_quest_line_from_the_live_tracker() -> void:
	var q: QuestTracker = QuestTracker.from_def({"type": "reach_stairs", "label_key": "quest_reach_stairs_untranslated",
		"params": {"floor": 1}})
	assert_eq(ExplorationHud.quest_line(q), "Erreiche die Treppe von Etage 1.", "no translation → generated text")
	assert_eq(ExplorationHud.quest_line(null), "")


func test_quest_line() -> void:
	var h: ExplorationHud = _hud()
	await wait_frames(2)
	var panel: Control = h.find_child("Quest", true, false) as Control
	assert_false(panel.visible, "campaign: no quest line")
	h.set_quest("Erreiche die Treppe von Etage 1.", 0.5)
	assert_eq(h.quest_text(), "Erreiche die Treppe von Etage 1.")
	assert_true(panel.visible)
	var bar: ProgressBar = panel.find_children("*", "ProgressBar", true, false)[0] as ProgressBar
	assert_almost(bar.value, 50.0, 0.01, "progress 0.5 → 50 %")
	Events.quest_progress.emit(0.75)
	assert_almost(bar.value, 75.0, 0.01, "quest_progress updates the bar")
	h.set_quest("", 0.0)
	assert_false(panel.visible, "empty quest hides")


func test_party_mini_status() -> void:
	var h: ExplorationHud = _hud()
	await wait_frames(40)
	var party: Array = UiUtil.party()
	assert_gt(party.size(), 0, "party exists")
	for m: Variant in party:
		var pm: PartyMember = m as PartyMember
		var panel: Node = h.find_child("Member_" + pm.id, true, false)
		assert_not_null(panel, "mini status for %s" % pm.id)
		if panel == null:
			continue
		var hp_text: Label = panel.find_child("HpText", true, false) as Label
		assert_eq(hp_text.text, "%d/%d" % [pm.hp, UiUtil.max_hp(pm)], "HP text of %s" % pm.id)
		var mp_text: Label = panel.find_child("MpText", true, false) as Label
		assert_eq(mp_text.text, "%d/%d MP" % [pm.mp, UiUtil.max_mp(pm)], "MP text of %s" % pm.id)


func test_minimap_api_and_view() -> void:
	var h: ExplorationHud = _hud()
	await wait_frames(2)
	var layout: FloorLayout = MinimapScript.layout_from_def(Game.floor_def())
	if layout == null or layout.cells.is_empty():
		skip("floor 1 has no hand-built layout")
		return
	var start: Vector2i = layout.start
	var visited: Array[Vector2i] = [start]
	h.bind_layout(layout, visited)
	assert_eq(int(h.minimap.call("visited_count")), 1)
	h.mark_visited(start)
	assert_eq(int(h.minimap.call("visited_count")), 1, "no duplicates")
	var other: Vector2i = start
	for key: Variant in layout.cells.keys():
		if (key as Vector2i) != start:
			other = key
			break
	h.mark_visited(other)
	assert_eq(int(h.minimap.call("visited_count")), 2)
	h.set_player(start, 0.5)
	assert_eq(h.minimap.get("player_cell"), start)
	var view: Rect2 = h.minimap.call("view_cells")
	assert_true(view.size.x >= float(MinimapScript.MIN_SPAN_SMALL), "HUD map shows at least a 5×5 window")
	assert_true(view.has_point(Vector2(start) + Vector2(0.5, 0.5)), "player inside the shown window")
	assert_almost(view.size.x, view.size.y, 0.001, "square HUD window")


func test_pause_menu_and_big_map_pause_the_tree() -> void:
	var h: ExplorationHud = _hud()
	await wait_frames(2)
	var toggles: Array[bool] = []
	var cb: Callable = func(open: bool) -> void: toggles.append(open)
	Events.pause_menu_toggled.connect(cb)
	var pm: Node = h.open_pause_menu("party")
	assert_not_null(pm, "pause menu opens")
	await wait_frames(2)
	assert_true(tree.paused, "tree paused while the menu is open (timer stops)")
	assert_true(h.is_modal_open())
	assert_null(h.open_big_map(), "only one modal at a time")
	pm.call("close")
	await wait_frames(2)
	assert_false(tree.paused)
	assert_false(h.is_modal_open(), "closed menu frees the modal slot")
	var bm: Node = h.open_big_map()
	assert_not_null(bm, "big map opens")
	await wait_frames(2)
	assert_true(tree.paused, "big map pauses")
	assert_eq(bm.process_mode, Node.PROCESS_MODE_WHEN_PAUSED)
	bm.call("close")
	await wait_frames(2)
	assert_false(tree.paused)
	assert_eq(toggles, [true, false, true, false] as Array[bool], "pause_menu_toggled open/close pairs")
	Events.pause_menu_toggled.disconnect(cb)


func test_pause_action_opens_the_menu() -> void:
	var h: ExplorationHud = _hud()
	await wait_frames(2)
	var ev: InputEventAction = InputEventAction.new()
	ev.action = &"pause"
	ev.pressed = true
	Input.parse_input_event(ev)
	var ok: bool = await wait_until(func() -> bool: return h.is_modal_open(), 30)
	assert_true(ok, "pause opens the pause menu")
	var rel: InputEventAction = InputEventAction.new()
	rel.action = &"pause"
	rel.pressed = false
	Input.parse_input_event(rel)
	await wait_frames(2)
	assert_true(tree.paused)


## TouchControls is PAUSABLE (inherits the HUD): while PauseMenu/BigMap pause the tree it gets no touch_up, so pausing
## releases the joystick (move_*/sneak) and held button actions.
func test_pausing_releases_touch_joystick_and_buttons() -> void:
	var t: Node = (load(SCENE_TOUCH) as PackedScene).instantiate()
	t.call("setup", {"force_visible": true})
	add_to_tree(t)
	await wait_frames(2)
	var joy: Control = t.get("joystick") as Control
	var start: Vector2 = Vector2(150, joy.size.y - 150)
	assert_true(bool(joy.call("touch_down", 0, start)), "joystick takes the touch")
	joy.call("touch_move", 0, start + Vector2(0, -80))
	assert_true(Input.is_action_pressed(&"move_forward"), "stick pushes move_forward")
	var held: Button = (t.get("buttons") as Dictionary)[&"action"] as Button
	held.button_down.emit()
	await wait_frames(1)                 # parse_input_event is applied on the next flush
	assert_true(Input.is_action_pressed(&"action"), "action held")
	tree.paused = true
	await wait_frames(2)
	assert_false(Input.is_action_pressed(&"move_forward"), "move released on pause")
	assert_false(Input.is_action_pressed(&"sneak"), "sneak released")
	assert_false(Input.is_action_pressed(&"action"), "held button action released")
	assert_false(bool(joy.get("active")), "joystick inactive")
	tree.paused = false
	await wait_frames(1)
	assert_false(Input.is_action_pressed(&"move_forward"), "Kai does not keep walking after the pause")
	UiUtil.release_move_actions()


## M3 CR 3 / GDD pinch zoom: two fingers on the free camera area send Events.camera_zoom (closer = zoom out, apart =
## zoom in) instead of camera_drag; one finger keeps dragging the camera.
func test_two_finger_pinch_sends_camera_zoom() -> void:
	var t: Node = (load(SCENE_TOUCH) as PackedScene).instantiate()
	t.call("setup", {"force_visible": true})
	add_to_tree(t)
	await wait_frames(2)
	var zooms: Array[float] = []
	var drags: Array = []
	var cb_z: Callable = func(a: float) -> void: zooms.append(a)
	var cb_d: Callable = func(r: Vector2) -> void: drags.append(r)
	Events.camera_zoom.connect(cb_z)
	Events.camera_drag.connect(cb_d)
	t.call("_input", _st(0, Vector2(900, 400), true))
	t.call("_input", _sd(0, Vector2(920, 400), Vector2(20, 0)))
	assert_eq(drags.size(), 1, "one finger drags the camera")
	t.call("_input", _st(1, Vector2(1020, 400), true))      # second finger: 100 px apart
	t.call("_input", _sd(1, Vector2(1120, 400), Vector2(100, 0)))   # apart → 200 px: zoom in
	assert_eq(zooms.size(), 1)
	if zooms.size() == 1:
		assert_almost(zooms[0], -100.0 * float(t.get("PINCH_M_PER_PX")), 0.0001, "fingers apart → shorter arm")
	t.call("_input", _sd(0, Vector2(1020, 400), Vector2(100, 0)))   # together → 100 px: zoom out
	assert_true(zooms.size() == 2 and zooms[1] > 0.0, "fingers closer → zoom out")
	assert_eq(drags.size(), 1, "no camera drag while pinching")
	t.call("_input", _st(1, Vector2(1020, 400), false))
	t.call("_input", _sd(0, Vector2(1000, 400), Vector2(-20, 0)))
	assert_eq(drags.size(), 2, "back to dragging with one finger")
	Events.camera_zoom.disconnect(cb_z)
	Events.camera_drag.disconnect(cb_d)


static func _st(index: int, pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var e: InputEventScreenTouch = InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	return e


static func _sd(index: int, pos: Vector2, rel: Vector2) -> InputEventScreenDrag:
	var e: InputEventScreenDrag = InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	e.relative = rel
	return e


## Detached stack screen (§13.3): party_changed / floor_entered / quest signals while the HUD is out of the tree only
## mark it dirty; re-attaching refreshes.
func test_detached_hud_refreshes_on_reattach() -> void:
	var h: ExplorationHud = _hud()
	await wait_frames(2)
	var box: Node = h.find_child("Party", true, false)
	var before: Array[Node] = box.get_children()
	var parent: Node = h.get_parent()
	parent.remove_child(h)
	var kai: PartyMember = Game.state.member("kai")
	kai.display_name = "Neuname"
	Events.party_changed.emit()
	await wait_frames(1)
	assert_eq(box.get_children(), before, "no rebuild while detached")
	parent.add_child(h)
	var ok: bool = await wait_until(func() -> bool:
		var lbls: Array[Node] = box.find_children("*", "Label", true, false)
		for l: Node in lbls:
			if (l as Label).text == "Neuname":
				return true
		return false, 30)
	assert_true(ok, "party panel refreshed after re-attaching")
	kai.display_name = ""


## Full-run finding: the tutorial victory starts the countdown (Events.floor_timer_started) while the exploration and
## its HUD are detached for the battle. The HUD must show the timer as soon as it is back (with the start pop), not
## only on the first second tick afterwards.
func test_countdown_started_while_detached_shows_on_reattach() -> void:
	var h: ExplorationHud = _hud()
	await wait_frames(2)
	assert_false(h.is_timer_visible(), "no countdown before the tutorial battle")
	var parent: Node = h.get_parent()
	parent.remove_child(h)
	Game.state.floor_run.timer_started = true
	Events.floor_timer_started.emit()
	assert_false(h.is_timer_visible(), "nothing applied while detached")
	parent.add_child(h)
	var ok: bool = await wait_until(func() -> bool: return h.is_timer_visible(), 5)
	assert_true(ok, "timer visible right after re-attaching (no floor_timer_changed tick needed)")
	assert_eq(h.timer_text(), UiUtil.fmt_time(floori(Game.time_left())))
	var panel: Control = h.find_child("Timer", true, false) as Control
	var peak: float = panel.scale.x
	for i in 6:
		await wait_frames(1)
		peak = maxf(peak, panel.scale.x)
	assert_gt(peak, 1.05, "start pop plays on re-attach")
	ok = await wait_until(func() -> bool: return is_equal_approx(panel.scale.x, 1.0), 60)
	assert_true(ok, "pop settles back to 1.0")
