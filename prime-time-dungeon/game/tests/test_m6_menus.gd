extends TestCase
## M6 menus change game state only through recorded Game commands (02_TECH §3.4, Brief §6b.3): inventory use, equipment,
## vending buy/sell, lootbox opening — checked with a spy RunLog. Plus confirm dialog contract, settings → GameSettings,
## title menu + options modal + navigation, name entry keyboard, slot summaries, results/summary formatting.

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const TitleFlow := preload("res://scenes/title/title_flow.gd")
const EventInfo := preload("res://scenes/ui/event_info.gd")
const SlotSelect := preload("res://scenes/title/slot_select.gd")
const ROUTER_FIXTURE: String = "res://tests/fixtures/router/router_screen.tscn"
const SCENE_TITLE: String = "res://scenes/title/title.tscn"
const SCENE_SLOTS: String = "res://scenes/title/slot_select.tscn"
const SCENE_NAME: String = "res://scenes/title/name_entry.tscn"
const SCENE_VENDING: String = "res://scenes/safe_room/vending_menu.tscn"
const SCENE_LOOTBOX: String = "res://scenes/safe_room/lootbox_opening.tscn"
const SCENE_CONFIRM: String = "res://scenes/ui/confirm_dialog.tscn"
const SCENE_SETTINGS: String = "res://scenes/ui/settings_menu.tscn"
const SCENE_LOBBY: String = "res://scenes/ui/event_lobby.tscn"
const SCENE_RESULT: String = "res://scenes/ui/run_result.tscn"
const SCENE_SUMMARY: String = "res://scenes/ui/floor_summary.tscn"
const SCENE_GAME_OVER: String = "res://scenes/title/game_over.tscn"
const INVENTORY_MENU: String = "res://scenes/ui/inventory_menu.gd"
const EQUIPMENT_MENU: String = "res://scenes/ui/equipment_menu.gd"
const WAIT: int = 1500


## Records every command Game.record() writes (the real RunLog may still be a stub).
class SpyLog extends RunLog:
	var got: Array[Dictionary] = []

	func add_cmd(_tick: int, cmd: Dictionary, _cmd_id: int = 0) -> void:
		got.append(cmd.duplicate(true))

	func of_type(t: String) -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		for c: Dictionary in got:
			if str(c.get("t", "")) == t:
				out.append(c)
		return out


var _spy: SpyLog = null
var _saved_log: RunLog = null
var _saved_settings: Dictionary = {}


func before_each() -> void:
	Engine.time_scale = 8.0
	tree.paused = false
	Game.new_game(0, "Kai", 7)
	_saved_log = Game.run_log
	_spy = SpyLog.new()
	Game.run_log = _spy
	var s: GameSettings = Game.settings
	_saved_settings = {"text_speed": s.text_speed, "master_volume": s.master_volume, "battle_speed": s.battle_speed,
		"show_fps": s.show_fps, "camera_invert_y": s.camera_invert_y, "auto_battle_default": s.auto_battle_default}


func after_each() -> void:
	Engine.time_scale = 1.0
	tree.paused = false
	Game.run_log = _saved_log
	var s: GameSettings = Game.settings
	s.text_speed = int(_saved_settings["text_speed"])
	s.master_volume = float(_saved_settings["master_volume"])
	s.battle_speed = float(_saved_settings["battle_speed"])
	s.show_fps = bool(_saved_settings["show_fps"])
	s.camera_invert_y = bool(_saved_settings["camera_invert_y"])
	s.auto_battle_default = bool(_saved_settings["auto_battle_default"])
	Game.auto_battle = false
	Game.apply_settings()
	await _settle_router()


# --- recorded commands -----------------------------------------------------------------------------------------------

func test_inventory_use_goes_through_game_use_item() -> void:
	var page: Control = (load(INVENTORY_MENU) as GDScript).new() as Control
	add_to_tree(page)
	await wait_frames(2)
	var ids: Array = UiUtil.inventory_counts().keys()
	assert_true(ids.has("itm_bandage"), "start inventory has Werbepflaster")
	assert_not_null(page.find_child("Item_itm_bandage", true, false), "listed in the inventory page")
	page.call("use_on", "itm_bandage", "kai")
	var cmds: Array[Dictionary] = _spy.of_type("use_item")
	assert_eq(cmds.size(), 1, "one recorded use_item")
	if cmds.size() == 1:
		assert_eq(cmds[0], {"t": "use_item", "item": "itm_bandage", "member": "kai"})


func test_equipment_goes_through_game_equip() -> void:
	var page: Control = (load(EQUIPMENT_MENU) as GDScript).new() as Control
	add_to_tree(page)
	await wait_frames(2)
	var cands: PackedStringArray = page.call("candidates", "weapon")
	assert_true(cands.size() >= 1 and cands[0] == "", "first candidate is 'unequip'")
	for id: String in cands:
		if id != "":
			assert_eq(UiUtil.item_def(id).type, "weapon", "only weapons offered for the weapon slot")
	page.call("select_member", "mopsula")
	page.call("equip", "armor", "")
	var cmds: Array[Dictionary] = _spy.of_type("equip")
	assert_eq(cmds.size(), 1, "one recorded equip")
	if cmds.size() == 1:
		assert_eq(cmds[0], {"t": "equip", "member": "mopsula", "slot": "armor", "item": ""})


func test_vending_buy_and_sell_go_through_game() -> void:
	var v: Node = _scene(SCENE_VENDING, {})
	add_to_tree(v)
	await wait_frames(3)
	var sr: String = str(v.get("safe_room_id"))
	assert_ne(sr, "", "vending machine belongs to a safe room of the floor")
	var stock: PackedStringArray = v.call("items")
	assert_true(stock.has("itm_bandage"), "stock lists Werbepflaster (got %s)" % str(stock))
	assert_eq(int(v.call("max_qty", "itm_bandage")), 2, "50 Cr / 25 Cr → 2")
	v.set("selected", "itm_bandage")
	v.call("set_qty", 5)
	assert_eq(int(v.get("qty")), 2, "quantity clamped to what credits allow")
	v.call("set_qty", 1)
	v.call("confirm")
	var buys: Array[Dictionary] = _spy.of_type("buy")
	assert_eq(buys.size(), 1, "one recorded buy")
	if buys.size() == 1:
		assert_eq(buys[0], {"t": "buy", "item": "itm_bandage", "qty": 1, "safe_room": sr})
	v.call("set_mode", "sell")
	var sellable: PackedStringArray = v.call("items")
	assert_true(sellable.has("itm_bandage"), "sell list = inventory")
	v.set("selected", "itm_antidote")
	v.call("set_qty", 1)
	v.call("confirm")
	var sells: Array[Dictionary] = _spy.of_type("sell")
	assert_eq(sells.size(), 1, "one recorded sell")
	if sells.size() == 1:
		assert_eq(sells[0], {"t": "sell", "item": "itm_antidote", "qty": 1})
	v.set("selected", "itm_key_master")
	assert_eq(int(v.call("max_qty", "itm_key_master")), 0, "key items are not sold")
	assert_false(bool(v.call("confirm")), "blocked sale does nothing")
	assert_eq(_spy.of_type("sell").size(), 1, "no command for a blocked sale")


func test_lootbox_opening_goes_through_game_open_lootbox() -> void:
	Game.state.pending_lootboxes.append("box_bronze")
	var lb: Node = _scene(SCENE_LOOTBOX, {})
	add_to_tree(lb)
	await wait_frames(3)
	assert_eq(lb.call("pending"), {"box_bronze": 1}, "pending boxes grouped")
	lb.call("select_box", "box_bronze")
	lb.call("tap")             # select → tease
	assert_eq(lb.get("state"), &"tease")
	assert_eq(_spy.of_type("lootbox").size(), 0, "no roll before the first tap on the box")
	lb.call("tap")
	assert_eq(_spy.of_type("lootbox"), [{"t": "lootbox", "box": "box_bronze"}] as Array[Dictionary],
		"first tap opens via Game.open_lootbox")
	assert_false(Array(Game.state.pending_lootboxes).has("box_bronze"), "box consumed")
	lb.call("tap")
	lb.call("tap")
	assert_true(lb.get("state") == &"reveal" or lb.get("state") == &"done", "third tap explodes the box")
	assert_eq(_spy.of_type("lootbox").size(), 1, "exactly one roll per box")
	lb.call("reveal_all")
	var ok: bool = await wait_until(func() -> bool: return lb.get("state") == &"done", WAIT)
	assert_true(ok, "all cards revealed → done")


func test_lootbox_screen_shows_odds_pity_and_purchase_note() -> void:
	Game.state.pending_lootboxes.append("box_silver")
	Game.state.pity_rare = 3
	Game.state.pity_epic = 5
	var lb: Node = _scene(SCENE_LOOTBOX, {})
	add_to_tree(lb)
	await wait_frames(3)
	lb.call("select_box", "box_silver")
	await wait_frames(1)
	var texts: String = _all_text(lb)
	assert_has(texts, "Gewöhnlich 55,0 %", "per-roll odds")
	assert_has(texts, "Selten 38,0 %")
	assert_has(texts, "Episch 7,0 %")
	assert_has(texts, "17,45 %", "chance of at least one epic in this box")
	assert_has(texts, "jetzt 3", "pity rare counter")
	assert_has(texts, "jetzt 5", "pity epic counter")
	assert_has(texts, "können nicht gekauft werden", "lootboxes are never sold")
	Game.state.pity_rare = 4
	lb.call("select_box", "box_silver")
	await wait_frames(1)
	assert_has(_all_text(lb), "erste Ziehung garantiert Selten", "pity forces the next first roll")


# --- confirm dialog ----------------------------------------------------------------------------------------------------

func test_confirm_dialog_yes_no_and_cancel() -> void:
	for answer_yes: bool in [true, false]:
		var d: Node = _scene(SCENE_CONFIRM, {"title": "Test", "text": "Sicher?", "yes": "Ja", "no": "Nein"})
		var log: Array[String] = []
		d.connect("confirmed", func() -> void: log.append("confirmed"))
		d.connect("cancelled", func() -> void: log.append("cancelled"))
		d.connect("closed", func(accepted: bool) -> void: log.append("closed:%s" % str(accepted)))
		add_to_tree(d)
		await wait_frames(2)
		assert_true((d.call("yes_button") as Button).has_focus(), "yes is default")
		d.call("answer", answer_yes)
		if answer_yes:
			assert_eq(log, ["confirmed", "closed:true"] as Array[String])
		else:
			assert_eq(log, ["cancelled", "closed:false"] as Array[String])
		await wait_frames(2)
		assert_false(is_instance_valid(d), "dialog frees itself")
	var d2: Node = _scene(SCENE_CONFIRM, {"text": "Abbrechen?", "default_no": true})
	var res: Array[bool] = []
	d2.connect("closed", func(accepted: bool) -> void: res.append(accepted))
	add_to_tree(d2)
	await wait_frames(2)
	assert_true((d2.call("no_button") as Button).has_focus(), "default_no focuses 'no'")
	var ev: InputEventAction = InputEventAction.new()
	ev.action = &"ui_cancel"
	ev.pressed = true
	Input.parse_input_event(ev)
	await wait_frames(2)
	assert_eq(res, [false] as Array[bool], "ui_cancel answers no")


# --- settings -----------------------------------------------------------------------------------------------------------

func test_settings_rows_write_game_settings() -> void:
	Game.settings.text_speed = 1
	var sm: Node = _scene(SCENE_SETTINGS, {"framed": true})
	add_to_tree(sm)
	await wait_frames(2)
	var rows: Dictionary = sm.get("rows")
	for key: String in ["master_volume", "music_volume", "sfx_volume", "battle_speed", "text_speed",
			"auto_battle_default", "camera_sensitivity", "camera_invert_x", "camera_invert_y", "touch_controls", "quality",
			"show_fps", "language", "difficulty"]:
		assert_true(rows.has(key), "settings row '%s'" % key)
	var changed: Array[int] = [0]
	var cb: Callable = func() -> void: changed[0] += 1
	Events.settings_changed.connect(cb)
	(rows["text_speed"] as Button).call("step", 1)
	assert_eq(Game.settings.text_speed, 2, "text speed → instant")
	(rows["battle_speed"] as Button).call("step", 1)
	assert_almost(Game.settings.battle_speed, 2.0 if float(_saved_settings["battle_speed"]) < 1.5 else 1.0, 0.001)
	(rows["show_fps"] as Button).call("step", 1)
	assert_eq(Game.settings.show_fps, not bool(_saved_settings["show_fps"]))
	(rows["auto_battle_default"] as Button).call("step", 1)
	assert_eq(Game.auto_battle, Game.settings.auto_battle_default, "auto battle follows its default")
	(rows["master_volume"] as HSlider).value = 35.0
	assert_almost(Game.settings.master_volume, 0.35, 0.001, "slider 0..100 → 0..1")
	assert_true(changed[0] >= 5, "every change applies settings (settings_changed)")
	assert_true((rows["language"] as Button).disabled, "German only for now")
	Events.settings_changed.disconnect(cb)


## Slider steps apply live but write user://settings.cfg only at drag end / close; camera sensitivity 1.00× exact.
func test_settings_sliders_debounce_saving_and_camera_hits_one() -> void:
	var sm: Node = _scene(SCENE_SETTINGS, {"framed": true})
	add_to_tree(sm)
	await wait_frames(2)
	var rows: Dictionary = sm.get("rows")
	var vol: HSlider = rows["master_volume"] as HSlider
	vol.value = 40.0
	vol.value = 45.0
	assert_almost(Game.settings.master_volume, 0.45, 0.001, "applied live")
	assert_true(bool(sm.call("is_dirty")), "not written per slider step")
	vol.drag_ended.emit(true)
	assert_false(bool(sm.call("is_dirty")), "written once at the end of the drag")
	var cam: HSlider = rows["camera_sensitivity"] as HSlider
	cam.value = 120.0
	cam.value = 100.0
	assert_eq(Game.settings.camera_sensitivity, 1.0, "1.00× is exactly selectable")
	assert_almost(cam.min_value, 25.0, 0.001, "0.25×")
	assert_almost(cam.max_value, 300.0, 0.001, "3.00×")
	assert_true(bool(sm.call("is_dirty")))
	sm.call("close")
	assert_false(bool(sm.call("is_dirty")), "closing writes pending changes")


func test_settings_mode_can_only_be_lowered() -> void:
	assert_eq(Game.state.difficulty, &"prime")
	var sm: Node = _scene(SCENE_SETTINGS, {"framed": true})
	add_to_tree(sm)
	await wait_frames(2)
	var b: Button = (sm.get("rows") as Dictionary)["difficulty"] as Button
	b.emit_signal("pressed")
	await wait_frames(2)
	var dlg: Node = null
	for c: Node in sm.get_children():
		if c.has_method("answer"):
			dlg = c
	assert_not_null(dlg, "lowering the mode asks first")
	if dlg == null:
		return
	assert_true((dlg.call("no_button") as Button).has_focus(), "'Abbrechen' is the default")
	dlg.call("answer", true)
	await wait_frames(2)
	assert_eq(Game.state.difficulty, &"vorabend", "Game.set_difficulty applied")
	assert_eq(_spy.of_type("difficulty").size(), 1, "recorded")
	assert_true(b.disabled, "Vorabendprogramm cannot be raised again")


# --- title flow ---------------------------------------------------------------------------------------------------------

func test_title_menu_and_options_modal() -> void:
	var t: Node = _scene(SCENE_TITLE, {})
	add_to_tree(t)
	await wait_frames(3)
	var ids: PackedStringArray = t.call("menu_ids")
	for id: String in ["new", "load", "event", "options", "credits"]:
		assert_true(ids.has(id), "title menu has '%s'" % id)
	assert_eq(ids.has("quit"), not OS.has_feature("mobile"), "quit only on desktop (§10.5)")
	assert_eq(ids[ids.size() - 1] if not ids.is_empty() else "", "quit" if not OS.has_feature("mobile") else "credits")
	t.call("activate", "options")
	await wait_frames(3)
	var modal: Node = t.find_child("SettingsMenu", true, false)
	if modal == null:
		for c: Node in t.find_children("*", "Control", true, false):
			if c.has_method("focus_default") and c.has_signal("closed") and c.get("rows") != null:
				modal = c
	assert_not_null(modal, "options open as modal over the title")
	if modal != null:
		var owner: Control = tree.root.gui_get_focus_owner()
		assert_true(owner != null and modal.is_ancestor_of(owner), "focus moves into the options")
		modal.call("close")
		await wait_frames(3)
		var owner2: Control = tree.root.gui_get_focus_owner()
		assert_true(owner2 != null and t.is_ancestor_of(owner2), "focus returns to the title menu")


func test_title_new_game_navigates_to_slot_select() -> void:
	var t: Node = _scene(SCENE_TITLE, {})
	add_to_tree(t)
	await wait_frames(2)
	t.call("activate", "new")
	var ok: bool = await wait_until(func() -> bool:
		return Router.current != null and is_instance_valid(Router.current) \
			and Router.current.scene_file_path == SCENE_SLOTS and not Router.busy, WAIT)
	assert_true(ok, "Neues Spiel → slot selection")
	if ok:
		assert_eq(str(Router.current.get("mode")), "new")


func test_title_flow_helpers() -> void:
	assert_eq(TitleFlow.clean_name("  Kai  "), "Kai")
	assert_eq(TitleFlow.clean_name(""), "Kai", "empty → Kai")
	assert_eq(TitleFlow.clean_name("Abcdefghijklmnop"), "Abcdefghijkl", "max 12")
	assert_eq(TitleFlow.clean_name("Jö" + String.chr(0x2665)), "Jö", "unsupported glyphs removed")
	assert_eq(TitleFlow.parse_args(PackedStringArray()), {"autoplay": false, "autoplay_mode": "", "seed": -1,
		"goto": ""})
	assert_eq(TitleFlow.parse_args(PackedStringArray(["--autoplay", "--seed=4242", "--goto=battle:enc_f1_rats"])),
		{"autoplay": true, "autoplay_mode": "smoke", "seed": 4242, "goto": "battle:enc_f1_rats"})
	assert_eq(int(TitleFlow.parse_args(PackedStringArray(["--seed=abc"]))["seed"]), -1, "invalid seed ignored")
	assert_has(TitleFlow.load_error_text(ERR_FILE_NOT_FOUND), "Kein Spielstand")


func test_name_entry_keyboard() -> void:
	var n: Node = _scene(SCENE_NAME, {"slot": 2})
	add_to_tree(n)
	await wait_frames(2)
	var edit: LineEdit = n.get("name_edit") as LineEdit
	assert_eq(int(n.get("slot")), 2)
	for i in 16:
		if edit.text == "":
			break
		n.call("backspace")
	assert_eq(edit.text, "", "backspace clears the default name")
	for c: String in ["M", "O", "P", "S"]:
		n.call("type_char", c)
	assert_eq(edit.text, "Mops", "first letter upper case, then lower case")
	n.call("backspace")
	assert_eq(edit.text, "Mop")
	for i in 20:
		n.call("type_char", "A")
	assert_eq(edit.text.length(), 12, "never longer than 12")
	assert_eq(str(n.call("entered_name")).length(), 12)
	n.call("set_difficulty", &"vorabend")
	assert_eq(n.get("difficulty"), &"vorabend")


func test_slot_summary_of_missing_slot_is_empty() -> void:
	var free_slot: int = -1
	for s: int in [1, 2, 3]:
		if not Save.has_save(s):
			free_slot = s
			break
	if free_slot < 0:
		skip("every slot has a save on this machine")
		return
	var info: Dictionary = SlotSelect.summary_of(free_slot)
	assert_true(info.is_empty() or bool(info.get("corrupt", false)), "empty slot → {}")


# --- results / summaries / lobby / game over -----------------------------------------------------------------------------

func test_run_result_shows_breakdown_and_total() -> void:
	var summary: Dictionary = {"event_id": "evt_probe", "cause": "timer", "quest_complete": false, "score": 12345,
		"rank": 0, "breakdown": {"quest": 0, "time": 0, "show": 12345, "achievements": 0, "ko": 0}}
	var r: Node = _scene(SCENE_RESULT, {"summary": summary})
	add_to_tree(r)
	var ok: bool = await wait_until(func() -> bool: return str(r.call("score_text")) == "12.345", WAIT)
	assert_true(ok, "total counts up to 12.345 (got '%s')" % str(r.call("score_text")))
	assert_eq(str(r.call("event_id")), "evt_probe")
	assert_has(_all_text(r), "SENDESCHLUSS – ZEIT ABGELAUFEN", "cause badge")


func test_floor_summary_values() -> void:
	var summary: Dictionary = {"floor": 1, "time_used_sec": 754, "time_left_sec": 446, "kills": 12, "viewers_peak": 4321,
		"followers_gained": 250, "achievements": 3}
	var s: Node = _scene(SCENE_SUMMARY, {"summary": summary})
	add_to_tree(s)
	var ok: bool = await wait_until(func() -> bool: return str(s.call("value_text", "achievements")) == "3", WAIT)
	assert_true(ok, "count-up finishes")
	assert_eq(str(s.call("value_text", "time_used_sec")), "12:34")
	assert_eq(str(s.call("value_text", "time_left_sec")), "07:26")
	assert_eq(str(s.call("value_text", "kills")), "12")
	assert_eq(str(s.call("value_text", "viewers_peak")), "4.321")
	assert_eq(str(s.call("value_text", "followers_gained")), "+250")


func test_event_lobby_lists_offline_events() -> void:
	var expected: Array[Dictionary] = EventInfo.offline_events()
	var l: Node = _scene(SCENE_LOBBY, {})
	add_to_tree(l)
	await wait_frames(3)
	var events: Array = l.get("events")
	assert_eq(events.size(), expected.size(), "every offline event is listed")
	if events.is_empty():
		return
	l.call("select", events.size() - 1)
	assert_eq(int(l.get("selected")), events.size() - 1)
	var info: Dictionary = events[events.size() - 1]
	assert_has(_all_text(l), EventInfo.quest_text(info.get("quest", {}) as Dictionary), "quest text on the card")


func test_game_over_buttons_by_mode() -> void:
	var g: Node = _scene(SCENE_GAME_OVER, {"reason": &"timer"})
	add_to_tree(g)
	await wait_frames(3)
	assert_eq(g.get("reason"), &"timer")
	var buttons: Dictionary = g.get("buttons")
	assert_true(buttons.has("load") and buttons.has("title"), "campaign: load + title")
	var ok: bool = await wait_until(func() -> bool: return bool(g.call("buttons_ready")), WAIT)
	assert_true(ok, "buttons become active")
	assert_eq((buttons["load"] as Button).disabled, not bool(g.call("can_load")), "load only with a save")
	assert_has(_all_text(g), "Die Etage ist eingestürzt.", "timer reason text")


func test_game_over_buttons_wait_before_accepting_input() -> void:
	Engine.time_scale = 1.0
	var g: Node = _scene(SCENE_GAME_OVER, {"reason": &"defeat"})
	add_to_tree(g)
	await wait_frames(2)
	var buttons: Dictionary = g.get("buttons")
	assert_false(bool(g.call("buttons_ready")), "not ready in the first frames (03_ART: buttons after 1.5 s)")
	assert_true((buttons["title"] as Button).disabled, "'Zum Titel' disabled during the delay")
	var owner: Control = tree.root.gui_get_focus_owner()
	assert_true(owner == null or not g.is_ancestor_of(owner), "no button focused during the delay")
	var ev: InputEventAction = InputEventAction.new()
	ev.action = &"ui_accept"
	ev.pressed = true
	Input.parse_input_event(ev)
	await wait_frames(2)
	assert_false(Router.busy, "a carried-over confirm press does not leave the screen")
	Engine.time_scale = 8.0
	var ok: bool = await wait_until(func() -> bool: return bool(g.call("buttons_ready")), WAIT)
	assert_true(ok, "buttons active after the delay")
	assert_false((buttons["title"] as Button).disabled)
	var focused: bool = await wait_until(func() -> bool:
		var f: Control = tree.root.gui_get_focus_owner()
		return f != null and g.is_ancestor_of(f), 60)
	assert_true(focused, "first button focused once active")


# --- helpers -------------------------------------------------------------------------------------------------------------

func _scene(path: String, params: Dictionary) -> Node:
	var n: Node = (load(path) as PackedScene).instantiate()
	n.call("setup", params)
	return n


func _all_text(root: Node) -> String:
	var parts: PackedStringArray = []
	for c: Node in root.find_children("*", "Label", true, false):
		parts.append((c as Label).text)
	for b: Node in root.find_children("*", "Button", true, false):
		parts.append((b as Button).text)
	return "\n".join(parts)


func _settle_router() -> void:
	for i in 600:
		if not Router.busy:
			break
		await tree.process_frame
	var cur: Node = Router.current
	if cur != null and is_instance_valid(cur) and not _nodes.has(cur):
		Router.goto(ROUTER_FIXTURE, {}, Router.Transition.NONE)
		for j in 240:
			if not Router.busy:
				break
			await tree.process_frame
		cur = Router.current
		if cur != null and is_instance_valid(cur):
			if cur.get_parent() != null:
				cur.get_parent().remove_child(cur)
			cur.free()
	Router.adopt(null)
	Game.timer_running = false
