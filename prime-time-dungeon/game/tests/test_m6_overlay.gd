extends TestCase
## Global UI (02_TECH §1.6, §3.4, §9.4; 03_ART §9.2): ShowOverlay as TV broadcast (modes, number formats, sponsor lower
## third queue, gift drop banner without contents, chat ticker, layout against the M.O.D. text box), ModDialog (queue,
## blocking lines + Events.dialog_finished, presenter registration, chat routing, soft-queue limit), toasts, GlobalUi
## composition / single instance / run summary cache, debug overlay.

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const ModDialogScript := preload("res://scenes/ui/mod_dialog.gd")
const RunResultScript := preload("res://scenes/ui/run_result.gd")
const ToastStackScript := preload("res://scenes/ui/toast_stack.gd")
const SCENE_OVERLAY: String = "res://scenes/ui/show_overlay.tscn"
const SCENE_DIALOG: String = "res://scenes/ui/mod_dialog.tscn"
const SCENE_GLOBAL: String = "res://scenes/ui/global_ui.tscn"
const SCENE_PAUSE: String = "res://scenes/ui/pause_menu.tscn"
const WAIT: int = 1500

var _saved_fast_text: bool = false
var _saved_text_speed: int = 1


func before_each() -> void:
	Engine.time_scale = 8.0
	tree.paused = false
	Game.ensure_state()
	_saved_fast_text = Game.fast_text
	_saved_text_speed = Game.settings.text_speed
	Game.fast_text = false
	Game.settings.text_speed = 1


func after_each() -> void:
	Engine.time_scale = 1.0
	Game.fast_text = _saved_fast_text
	Game.settings.text_speed = _saved_text_speed
	Game.autoplay = false
	Game.clear_blocking_dialogs()
	tree.paused = false
	Events.overlay_mode_requested.emit(&"hidden")


# --- number formats -------------------------------------------------------------------------------------------------

func test_number_formats() -> void:
	assert_eq(UiUtil.fmt_int(0), "0")
	assert_eq(UiUtil.fmt_int(999), "999")
	assert_eq(UiUtil.fmt_int(1000), "1.000")
	assert_eq(UiUtil.fmt_int(7250), "7.250")
	assert_eq(UiUtil.fmt_int(1234567), "1.234.567")
	assert_eq(UiUtil.fmt_int(-12345), "-12.345")
	assert_eq(UiUtil.fmt_signed(1234), "+1.234")
	assert_eq(UiUtil.fmt_signed(-3), "-3")
	assert_eq(UiUtil.fmt_signed(0), "0")
	assert_eq(UiUtil.fmt_time(0), "00:00")
	assert_eq(UiUtil.fmt_time(65), "01:05")
	assert_eq(UiUtil.fmt_time(1200), "20:00")
	assert_eq(UiUtil.fmt_time(3725), "1:02:05")
	assert_eq(UiUtil.fmt_time(-5), "00:00")
	assert_eq(UiUtil.fmt_pct(0.36), "36,0 %")
	assert_eq(UiUtil.fmt_pct(0.174468, 2), "17,45 %")
	assert_eq(UiUtil.fmt_pct(1.5), "100,0 %", "clamped")


# --- ShowOverlay -----------------------------------------------------------------------------------------------------

func test_overlay_modes_and_badge() -> void:
	var o: CanvasLayer = _overlay({})
	await wait_frames(2)
	assert_eq(o.layer, 40, "ShowOverlay layer 40 (§9.4)")
	assert_eq(o.process_mode, Node.PROCESS_MODE_ALWAYS)
	Events.overlay_mode_requested.emit(&"explore")
	assert_eq(o.get("mode"), &"explore")
	assert_eq(str(o.call("badge_text")), "LIVE")
	Events.overlay_mode_requested.emit(&"safe_room")
	assert_eq(o.get("mode"), &"safe_room")
	assert_eq(str(o.call("badge_text")), "WERBEPAUSE", "safe room = advertising break")
	Events.overlay_mode_requested.emit(&"battle")
	assert_eq(o.get("mode"), &"battle")
	assert_eq(str(o.call("badge_text")), "LIVE")
	o.call("set_mode", &"no_such_mode")
	assert_eq(o.get("mode"), &"hidden", "unknown modes hide the overlay")


func test_overlay_capture_numbers_use_thousands_separator() -> void:
	var o: CanvasLayer = _overlay({"capture": true})
	var ok: bool = await wait_until(func() -> bool: return str(o.call("viewers_text")) == "7.250", WAIT)
	assert_true(ok, "viewer counter shows 7.250 (got '%s')" % str(o.call("viewers_text")))
	assert_almost(float(o.call("hype_value")), 72.0, 0.01, "demo hype")
	assert_true(bool(o.call("is_lower_third_visible")), "demo lower third")
	assert_true(bool(o.call("is_gift_banner_visible")), "demo gift banner")


func test_lower_third_queue_and_dedupe() -> void:
	var o: CanvasLayer = _overlay({})
	await wait_frames(1)
	Events.overlay_mode_requested.emit(&"explore")
	# Unknown ids fall back to the id as name, so the queue is testable independent of the sponsor data.
	Events.sponsor_gift_triggered.emit("sp_probe_a")
	Events.sponsor_gift_triggered.emit("sp_probe_a")      # same sponsor within 1 s → shown once
	Events.sponsor_gift_triggered.emit("sp_probe_b")
	assert_true(bool(o.call("is_lower_third_visible")), "lower third appears at once")
	assert_eq(str(o.call("lower_third_text")), "SP_PROBE_A")
	assert_eq((o.get("_lower_queue") as Array).size(), 1, "duplicate dropped, second sponsor queued")
	var seen_b: bool = await wait_until(func() -> bool: return str(o.call("lower_third_text")) == "SP_PROBE_B", WAIT)
	assert_true(seen_b, "second sponsor follows from the queue")
	var gone: bool = await wait_until(func() -> bool: return not bool(o.call("is_lower_third_visible")), WAIT)
	assert_true(gone, "queue empties (0.25 s in, 2.5 s hold, 0.2 s out each)")
	var sponsors: PackedStringArray = DB.data.ids("sponsors")
	if sponsors.is_empty():
		return
	# System gifts (sponsor package) show the sponsor's lower third with its data name.
	Events.gift_received.emit({"kind": "sponsor_buff", "source": "system", "sponsor_id": sponsors[0]})
	assert_eq(str(o.call("lower_third_text")), UiUtil.tr_text(DB.sponsor(sponsors[0]).name).to_upper(),
		"system gift → sponsor lower third")
	assert_false(bool(o.call("is_gift_banner_visible")), "system gifts are no viewer drop")


func test_gift_banner_shows_kind_tier_sender_only() -> void:
	var o: CanvasLayer = _overlay({})
	await wait_frames(1)
	Events.gift_received.emit({"kind": "chest", "tier": "silver", "source": "viewer", "sender": {"anon": true},
		"contents": [{"id": "secret_item"}]})
	assert_true(bool(o.call("is_gift_banner_visible")), "viewer gift → drop announcement")
	var text: String = str(o.call("gift_text"))
	assert_has(text, "Sponsorkiste Silber", "kind + tier")
	assert_has(text, "anonymen Fan", "anonymous by default")
	assert_false(text.contains("secret_item"), "never the contents")
	Events.gift_received.emit({"kind": "gold", "source": "viewer", "sender": {"anon": false, "display_name": "OmaHilde"}})
	assert_has(str(o.call("gift_text")), "OmaHilde", "named sender when not anonymous")
	var gone: bool = await wait_until(func() -> bool: return not bool(o.call("is_gift_banner_visible")), WAIT)
	assert_true(gone, "banner leaves after its hold time")


func test_chat_ticker_receives_chat_and_mod_chat_lines() -> void:
	var o: CanvasLayer = _overlay({})
	await wait_frames(1)
	Events.overlay_mode_requested.emit(&"explore")
	var n0: int = int(o.call("ticker_items"))
	Events.chat_posted.emit("mopsfan_88", "GRAF MOPSULA <3", &"hype")
	assert_eq(int(o.call("ticker_items")), n0 + 1, "chat_posted → ticker")
	Events.mod_said.emit("Chat sagt hallo", &"chat", "chat", false)
	assert_eq(int(o.call("ticker_items")), n0 + 2, "mod_said voice chat → ticker")
	Events.mod_said.emit("M.O.D. spricht", &"mod", "intro", false)
	assert_eq(int(o.call("ticker_items")), n0 + 2, "other voices are not ticker lines")


func test_lower_third_is_lifted_above_the_dialog_box() -> void:
	var sponsors: PackedStringArray = DB.data.ids("sponsors")
	if sponsors.is_empty():
		skip("no sponsors in data")
		return
	var g: Node = _global({})
	await wait_frames(2)
	var o: CanvasLayer = g.get("show_overlay") as CanvasLayer
	var d: CanvasLayer = g.get("mod_dialog") as CanvasLayer
	Events.overlay_mode_requested.emit(&"explore")
	d.call("enqueue", "Ein sehr langer Satz der M.O.D., damit die Textbox sicher sichtbar ist.", &"mod", "intro", true)
	o.call("show_lower_third", sponsors[0])
	var ok: bool = await wait_until(func() -> bool:
		var box: Rect2 = d.call("box_rect")
		var lt: Rect2 = o.call("lower_third_rect")
		return box.size.x > 0.0 and lt.size.x > 0.0 and lt.end.y <= box.position.y + 0.5, 120)
	assert_true(ok, "lower third sits above the M.O.D. box (lt %s, box %s)" % [str(o.call("lower_third_rect")),
		str(d.call("box_rect"))])
	d.call("advance")
	d.call("advance")


# --- ModDialog -------------------------------------------------------------------------------------------------------

func test_dialog_registers_presenter_and_layer() -> void:
	var d: CanvasLayer = _dialog()
	await wait_frames(1)
	assert_eq(d.layer, 45, "ModDialog layer 45 (§9.4)")
	assert_true(bool(Game.get("_dialog_presenter")), "presenter registered in _ready")
	assert_eq(ModDialogScript.current, d, "current dialog")
	_free_now(d)
	assert_false(bool(Game.get("_dialog_presenter")), "presenter unregistered in _exit_tree")
	assert_null(ModDialogScript.current, "current cleared")


func test_blocking_line_waits_and_emits_dialog_finished_once() -> void:
	var d: CanvasLayer = _dialog()
	await wait_frames(1)
	var finished: Array[String] = []
	var cb: Callable = func(tag: String) -> void: finished.append(tag)
	Events.dialog_finished.connect(cb)
	Events.mod_said.emit("Willkommen in der Unterstadt!", &"mod", "intro", true)
	assert_eq(int(Game.get("_blocking_dialogs")), 1, "Game counts the blocking line (timer pauses)")
	assert_true(bool(d.call("is_busy")))
	assert_eq(str((d.call("current_line") as Dictionary).get("tag", "")), "intro")
	await wait_frames(30)
	assert_eq(finished.size(), 0, "a blocking line never ends on its own")
	d.call("advance")      # reveal the rest
	d.call("advance")      # dismiss
	assert_eq(finished, ["intro"] as Array[String], "dialog_finished(tag) exactly once")
	assert_eq(int(Game.get("_blocking_dialogs")), 0, "timer released")
	assert_false(bool(d.call("is_busy")))
	Events.dialog_finished.disconnect(cb)


## A blocking line that is never shown (empty text / chat voice) was still counted by Game (§3.4): ModDialog balances
## it, so the floor countdown does not freeze until the next goto.
func test_dropped_blocking_line_releases_the_timer() -> void:
	var d: CanvasLayer = _dialog()
	await wait_frames(1)
	Game.new_game(0, "Kai", 2)
	Game.timer_running = true
	Game.state.floor_run.timer_started = true
	assert_true(Game.is_timer_ticking(), "timer ticks before")
	var got: Array[String] = []
	var cb: Callable = func(tag: String) -> void: got.append(tag)
	Events.dialog_finished.connect(cb)
	Events.mod_said.emit("   ", &"mod", "empty_line", true)
	Events.mod_said.emit("nur fürs Chat-Band", &"chat", "chat_line", true)
	assert_false(bool(d.call("is_busy")), "nothing shown")
	var ok: bool = await wait_until(func() -> bool: return Game.is_timer_ticking(), 30)
	assert_true(ok, "timer ticks again after the dropped blocking lines")
	assert_eq(got, ["empty_line", "chat_line"] as Array[String], "each dropped blocking line is balanced once")
	assert_eq(int(Game.get("_blocking_dialogs")), 0)
	Events.dialog_finished.disconnect(cb)
	Game.timer_running = false


## ui_accept belongs to a menu opened over a waiting blocking line (PauseMenu, layer 60, tree paused): the focused
## tab is pressed and the line stays where it is.
func test_menu_over_a_blocking_line_keeps_its_confirm_input() -> void:
	var d: CanvasLayer = _dialog()
	await wait_frames(1)
	Events.mod_said.emit("Eine sehr wichtige Durchsage, bitte bis zum Ende lesen.", &"mod", "important", true)
	d.call("advance")                    # full text shown; the next accept would end the line
	var line_before: Dictionary = d.call("current_line")
	var pm: Node = (load(SCENE_PAUSE) as PackedScene).instantiate()
	pm.call("setup", {})
	tree.root.add_child(pm)
	_nodes.append(pm)
	var focused: bool = await wait_until(func() -> bool:
		var f: Control = tree.root.gui_get_focus_owner()
		return f != null and pm.is_ancestor_of(f), 60)
	assert_true(focused, "a pause tab has the focus")
	var tab: BaseButton = tree.root.gui_get_focus_owner() as BaseButton
	var presses: Array[int] = [0]
	if tab != null:
		tab.pressed.connect(func() -> void: presses[0] += 1)
	var ev: InputEventAction = InputEventAction.new()
	ev.action = &"ui_accept"
	ev.pressed = true
	Input.parse_input_event(ev)
	var rel: InputEventAction = InputEventAction.new()
	rel.action = &"ui_accept"
	rel.pressed = false
	Input.parse_input_event(rel)
	await wait_frames(3)
	assert_eq(presses[0], 1, "the focused tab got the confirm press")
	assert_true(bool(d.call("is_busy")), "the line is still waiting")
	assert_eq(d.call("current_line"), line_before, "same line as before")
	if is_instance_valid(pm):
		pm.call("close")
	await wait_frames(2)
	tree.paused = false
	d.call("advance")
	assert_false(bool(d.call("is_busy")), "without the menu the box takes ui_accept/advance again")


func test_dialog_moves_right_in_the_safe_room() -> void:
	var d: CanvasLayer = _dialog()
	await wait_frames(1)
	Events.overlay_mode_requested.emit(&"safe_room")
	d.call("enqueue", "Rechts neben dem Menü.", &"mod", "x", false)
	await wait_frames(2)
	var r: Rect2 = d.call("box_rect")
	assert_true(bool(d.call("is_align_right")), "safe room aligns the box right")
	assert_gt(r.position.x, 412.0, "box clear of the safe-room menu column (x <= 412)")
	Events.overlay_mode_requested.emit(&"explore")
	assert_false(bool(d.call("is_align_right")), "other modes: bottom centre")


func test_soft_lines_advance_on_their_own_without_dialog_finished() -> void:
	var d: CanvasLayer = _dialog()
	await wait_frames(1)
	var finished: Array[String] = []
	var cb: Callable = func(tag: String) -> void: finished.append(tag)
	Events.dialog_finished.connect(cb)
	Events.mod_said.emit("Kurz.", &"mod", "crit", false)
	Events.mod_said.emit("Noch kürzer.", &"mopsula", "mopsula", false)
	assert_eq(int(d.call("pending")), 1)
	var done: bool = await wait_until(func() -> bool: return not bool(d.call("is_busy")), WAIT)
	assert_true(done, "non-blocking lines advance after their reading time")
	assert_eq(finished.size(), 0, "only blocking lines emit dialog_finished (§3.4)")
	assert_eq(int(Game.get("_blocking_dialogs")), 0)
	Events.dialog_finished.disconnect(cb)


func test_soft_queue_is_capped_and_blocking_lines_survive() -> void:
	var d: CanvasLayer = _dialog()
	await wait_frames(1)
	d.call("enqueue", "Erste Zeile", &"mod", "a", false)
	d.call("enqueue", "Wichtig", &"mod", "important", true)
	for i in 6:
		d.call("enqueue", "Füllzeile %d" % i, &"mod", "filler", false)
	var pend: int = int(d.call("pending"))
	assert_eq(pend, 1 + int(ModDialogScript.MAX_PENDING_SOFT), "blocking line + at most MAX_PENDING_SOFT soft lines")
	var lines: Array = d.get("_queue")
	var has_blocking: bool = false
	for l: Variant in lines:
		if bool((l as Dictionary)["blocking"]):
			has_blocking = true
	assert_true(has_blocking, "the blocking line is never dropped")


func test_chat_voice_never_opens_the_box_and_text_is_glyph_safe() -> void:
	var d: CanvasLayer = _dialog()
	await wait_frames(1)
	Events.mod_said.emit("nur Chat", &"chat", "chat", false)
	assert_false(bool(d.call("is_busy")), "chat lines go to the ticker only")
	d.call("enqueue", "Herz " + String.chr(0x2665) + " und Pfeil " + String.chr(0x2192), &"mod", "x", true)
	var shown: String = str((d.call("current_line") as Dictionary).get("text", ""))
	assert_eq(UiUtil.missing_glyphs(shown), "", "missing glyphs replaced (F8)")
	d.call("advance")
	d.call("advance")


func test_autoplay_dismisses_blocking_lines() -> void:
	Game.autoplay = true
	var d: CanvasLayer = _dialog()
	await wait_frames(1)
	var got: Array[String] = []
	var cb: Callable = func(tag: String) -> void: got.append(tag)
	Events.dialog_finished.connect(cb)
	Events.mod_said.emit("Autoplay hört nicht zu.", &"mod", "intro", true)
	var ok: bool = await wait_until(func() -> bool: return not bool(d.call("is_busy")), WAIT)
	assert_true(ok, "autoplay closes blocking lines by itself")
	assert_eq(got, ["intro"] as Array[String], "and still emits dialog_finished")
	Events.dialog_finished.disconnect(cb)


func test_text_speed_instant_shows_everything_at_once() -> void:
	Game.settings.text_speed = 2
	var d: CanvasLayer = _dialog()
	await wait_frames(1)
	d.call("enqueue", "Sofort da.", &"mod", "x", true)
	var label: Label = null
	for c: Node in d.find_children("*", "Label", true, false):
		if (c as Label).text == "Sofort da.":
			label = c as Label
	assert_not_null(label, "line label")
	if label != null:
		assert_eq(label.visible_characters, -1, "text_speed 2 = instant")
	d.call("advance")


# --- toasts ------------------------------------------------------------------------------------------------------------

func test_toasts_stack_max_three_and_expire() -> void:
	var t: CanvasLayer = ToastStackScript.new()
	add_to_tree(t)
	await wait_frames(1)
	assert_eq(t.layer, 45, "toasts on layer 45")
	Events.toast_requested.emit("Erster Kill", &"achievement")
	assert_eq(int(t.call("count")), 1)
	for i in 4:
		Events.toast_requested.emit("Toast %d" % i, &"info")
	assert_eq(int(t.call("count")), ToastStackScript.MAX_VISIBLE, "max visible")
	Events.game_saved.emit(2, true)
	var texts: PackedStringArray = []
	for l: Node in t.find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	assert_has(texts, "Slot 2 gesichert.", "game_saved toast")
	var gone: bool = await wait_until(func() -> bool: return int(t.call("count")) == 0, WAIT * 2)
	assert_true(gone, "toasts expire after 3.2 s")


func test_toasts_are_silent_while_replaying() -> void:
	var t: CanvasLayer = ToastStackScript.new()
	add_to_tree(t)
	await wait_frames(1)
	Game.replaying = true
	Events.toast_requested.emit("Replay", &"achievement")
	Game.replaying = false
	assert_eq(int(t.call("count")), 0, "presentation is skipped during replay")


# --- GlobalUi ----------------------------------------------------------------------------------------------------------

func test_global_ui_composition_and_single_instance() -> void:
	var g: Node = _global({})
	await wait_frames(2)
	var o: CanvasLayer = g.get("show_overlay") as CanvasLayer
	var d: CanvasLayer = g.get("mod_dialog") as CanvasLayer
	var t: CanvasLayer = g.get("toasts") as CanvasLayer
	var dbg: CanvasLayer = g.get("debug_overlay") as CanvasLayer
	assert_true(o != null and d != null and t != null and dbg != null, "overlay, dialog, toasts, debug")
	if o == null or d == null or t == null or dbg == null:
		return
	assert_eq([o.layer, d.layer, t.layer, dbg.layer], [40, 45, 45, 90], "layer order §9.4")
	assert_eq(g.process_mode, Node.PROCESS_MODE_ALWAYS)
	var second: Node = _global({})
	await wait_frames(2)
	assert_false(is_instance_valid(second) and second.is_inside_tree(), "a second GlobalUi removes itself")
	Events.run_finished.emit({"event_id": "ev_test", "score": 1234})
	assert_eq(int((RunResultScript.last_summary as Dictionary).get("score", 0)), 1234, "run summary cached for RunResult")


func test_debug_overlay_info() -> void:
	var g: Node = _global({})
	await wait_frames(2)
	var dbg: CanvasLayer = g.get("debug_overlay") as CanvasLayer
	var info: String = str(dbg.call("info_text"))
	for key: String in ["FPS", "Seed"]:
		assert_has(info, key, "debug info lists %s" % key)
	dbg.call("send_test_gift")
	await wait_frames(1)


# --- helpers -------------------------------------------------------------------------------------------------------------

func _overlay(params: Dictionary) -> CanvasLayer:
	var o: CanvasLayer = (load(SCENE_OVERLAY) as PackedScene).instantiate() as CanvasLayer
	o.call("setup", params)
	tree.root.add_child(o)        # not adopted: an overlay is no screen
	_nodes.append(o)
	return o


func _dialog() -> CanvasLayer:
	var d: CanvasLayer = (load(SCENE_DIALOG) as PackedScene).instantiate() as CanvasLayer
	d.call("setup", {})
	tree.root.add_child(d)
	_nodes.append(d)
	return d


func _global(params: Dictionary) -> Node:
	var g: Node = (load(SCENE_GLOBAL) as PackedScene).instantiate()
	g.call("setup", params)
	tree.root.add_child(g)
	_nodes.append(g)
	return g


func _free_now(n: Node) -> void:
	_nodes.erase(n)
	if n.get_parent() != null:
		n.get_parent().remove_child(n)
	n.free()
