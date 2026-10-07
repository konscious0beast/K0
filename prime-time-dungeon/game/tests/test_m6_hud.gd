extends TestCase
## ExplorationHud (02_TECH §9.5, GDD §14.3, 03_ART §9.2): public API (bind_layout / set_player / mark_visited /
## set_prompt / set_quest), floor timer (hidden until the countdown starts, < 5:00 sodium, < 1:00 red + pulse, expired
## 00:00), party mini status, touch prompt icon, pause menu / big map open the modal and pause the tree, minimap view.

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const MinimapScript := preload("res://scenes/ui/minimap.gd")
const SCENE_HUD: String = "res://scenes/ui/exploration_hud.tscn"


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
