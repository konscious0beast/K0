extends TestCase
## Safe room (02_TECH §9.5, GDD §14.7): entering records the safe room + full heal, menu order, modals (vending,
## lootboxes, pause/equipment) with focus return, Mopsula scenes as blocking ModDialog lines tagged "scene:<id>" that
## end in Game.mark_scene_seen, event runs cannot save.

const SCENE_SAFE_ROOM: String = "res://scenes/safe_room/safe_room.tscn"
const SCENE_DIALOG: String = "res://scenes/ui/mod_dialog.tscn"
const WAIT: int = 1500


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


func before_each() -> void:
	Engine.time_scale = 8.0
	tree.paused = false
	Game.new_game(0, "Kai", 3)
	_saved_log = Game.run_log
	_spy = SpyLog.new()
	Game.run_log = _spy


func after_each() -> void:
	Engine.time_scale = 1.0
	tree.paused = false
	Game.run_log = _saved_log
	Game.mode = &"campaign"
	Game.clear_blocking_dialogs()
	Router.adopt(null)


func _room() -> Node:
	var r: Node = (load(SCENE_SAFE_ROOM) as PackedScene).instantiate()
	r.call("setup", {})
	add_to_tree(r)
	return r


func test_enter_records_and_heals() -> void:
	var kai: PartyMember = Game.state.member("kai")
	assert_not_null(kai, "precondition: Kai in the party")
	if kai == null:
		return
	kai.hp = 1
	var r: Node = _room()
	await wait_frames(2)
	assert_true(r is SafeRoomScene)
	var sr: String = str(r.get("safe_room_id"))
	assert_ne(sr, "", "safe room id resolved")
	assert_eq(_spy.of_type("safe_room"), [{"t": "safe_room", "id": sr}] as Array[Dictionary], "Game.enter_safe_room")
	assert_eq(kai.hp, Progression.total_stats(kai, DB.data).values[StatBlock.Stat.HP],
		"full heal on entering (Progression.full_heal)")
	assert_eq(r.call("menu_ids"), PackedStringArray(["save", "lootbox", "vending", "equipment", "mopsula", "leave"]),
		"menu order (GDD §14.7)")


func test_vending_modal_returns_focus() -> void:
	var r: Node = _room()
	await wait_frames(3)
	r.call("activate", "vending")
	await wait_frames(3)
	var vend: Node = null
	for c: Node in r.get_children():
		if c.has_method("confirm") and c.has_signal("closed"):
			vend = c
	assert_not_null(vend, "vending machine opens as modal")
	if vend == null:
		return
	var owner: Control = tree.root.gui_get_focus_owner()
	assert_true(owner != null and vend.is_ancestor_of(owner), "focus inside the vending menu")
	r.call("activate", "lootbox")
	assert_eq(r.find_children("*", "CanvasLayer", false, false).filter(func(n: Node) -> bool:
		return n.has_method("tap")).size(), 0, "no second modal while one is open")
	vend.call("close")
	await wait_frames(3)
	var owner2: Control = tree.root.gui_get_focus_owner()
	var vbtn: Control = (r.get("menu_buttons") as Dictionary)["vending"] as Control
	assert_eq(owner2, vbtn, "focus returns to 'Automat'")


func test_equipment_opens_pause_menu_on_equipment_tab() -> void:
	var r: Node = _room()
	await wait_frames(3)
	r.call("activate", "equipment")
	await wait_frames(3)
	var pm: Node = null
	for c: Node in r.get_children():
		if c.has_method("show_tab"):
			pm = c
	assert_not_null(pm, "pause menu opened")
	if pm == null:
		return
	assert_eq(str(pm.get("current_tab")), "equipment")
	assert_true(tree.paused)
	pm.call("close")
	await wait_frames(3)
	assert_false(tree.paused)


func test_mopsula_scene_plays_as_blocking_lines_and_is_marked_seen() -> void:
	var dialog: Node = (load(SCENE_DIALOG) as PackedScene).instantiate()
	dialog.call("setup", {})
	tree.root.add_child(dialog)
	_nodes.append(dialog)
	var r: Node = _room()
	await wait_frames(3)
	var scene: SceneDef = r.get("pending_scene") as SceneDef
	if scene == null:
		skip("no Mopsula scene pending on the first visit with the current data")
		return
	var tags: Array[String] = []
	var cb: Callable = func(_text: String, _voice: StringName, tag: String, blocking: bool) -> void:
		if blocking:
			tags.append(tag)
	Events.mod_said.connect(cb)
	r.call("activate", "mopsula")
	await wait_frames(2)
	assert_eq(tags.size(), scene.lines.size(), "every scene line is said")
	for t: String in tags:
		assert_eq(t, "scene:" + scene.id)
	assert_true(bool(dialog.call("is_busy")), "lines wait in the dialog box")
	assert_eq(_spy.of_type("scene").size(), 0, "not seen before the last line is dismissed")
	for i in scene.lines.size() * 2 + 2:
		dialog.call("advance")
	var done: bool = await wait_until(func() -> bool: return _spy.of_type("scene").size() == 1, WAIT)
	assert_true(done, "Game.mark_scene_seen after the dialog")
	assert_eq(_spy.of_type("scene"), [{"t": "scene", "id": scene.id}] as Array[Dictionary])
	assert_true(bool(Game.get_flag("scene_" + scene.id, false)), "flag scene_<id> set")
	assert_null(r.get("pending_scene"), "no scene pending anymore")
	Events.mod_said.disconnect(cb)


## Two scenes that both qualify on the same visit (like scn_mop_2 + scn_mop_4 on the first sr_signalbox visit after the
## Hausmeister): both play in that visit — the second becomes pending right after the first is marked seen.
func test_two_qualifying_scenes_both_play_in_one_visit() -> void:
	var data: GameData = _data_with_scenes([
		{"id": "scn_test_a", "name": "Test A", "condition": "e.first_visit == true", "priority": 0,
			"lines": [{"voice": "mopsula", "text": "Erste Szene."}]},
		{"id": "scn_test_b", "name": "Test B", "condition": "e.first_visit == true", "priority": 1,
			"set_flag": "test_pep_talk", "lines": [{"voice": "mopsula", "text": "Zweite Szene."},
			{"voice": "kai", "text": "Verstanden."}]}])
	if data == null:
		return
	var saved: GameData = DB.data
	DB.data = data
	Game.new_game(0, "Kai", 3)
	Game.run_log = _spy
	var dialog: Node = (load(SCENE_DIALOG) as PackedScene).instantiate()
	dialog.call("setup", {})
	tree.root.add_child(dialog)
	_nodes.append(dialog)
	var r: Node = _room()
	await wait_frames(3)
	var first: SceneDef = r.get("pending_scene") as SceneDef
	assert_true(first != null and first.id == "scn_test_a", "first scene pending")
	r.call("activate", "mopsula")
	await wait_frames(2)
	for i in 6:
		dialog.call("advance")
	var ok: bool = await wait_until(func() -> bool:
		var p: SceneDef = r.get("pending_scene") as SceneDef
		return _spy.of_type("scene").size() == 1 and p != null, WAIT)
	assert_true(ok, "after the first scene the second one is pending in the same visit")
	var second: SceneDef = r.get("pending_scene") as SceneDef
	assert_true(second != null and second.id == "scn_test_b", "second scene = scn_test_b")
	var marker: Node3D = r.find_child("SceneMarker", true, false) as Node3D
	assert_true(marker != null and marker.visible, "'!' stays for the next scene")
	r.call("activate", "mopsula")
	await wait_frames(2)
	for i in 8:
		dialog.call("advance")
	var ok2: bool = await wait_until(func() -> bool: return _spy.of_type("scene").size() == 2, WAIT)
	assert_true(ok2, "second scene played in the same visit")
	assert_eq(_spy.of_type("scene"), [{"t": "scene", "id": "scn_test_a"}, {"t": "scene", "id": "scn_test_b"}] as
		Array[Dictionary])
	assert_true(bool(Game.get_flag("test_pep_talk", false)), "set_flag of the second scene applied")
	assert_null(r.get("pending_scene"), "nothing left")
	DB.data = saved


## A repeatable scene (once = false) that still qualifies comes first from Game.next_scene again after it played; it
## must not hide the next qualifying scene for the rest of the visit, and it never plays twice in one visit.
func test_repeatable_scene_does_not_hide_later_scenes_of_the_visit() -> void:
	var data: GameData = _data_with_scenes([
		{"id": "scn_test_rep", "name": "Wiederholung", "condition": "e.first_visit == true", "priority": 0,
			"once": false, "lines": [{"voice": "mopsula", "text": "Immer wieder gern."}]},
		{"id": "scn_test_next", "name": "Danach", "condition": "e.first_visit == true", "priority": 1,
			"lines": [{"voice": "mopsula", "text": "Und noch etwas."}]}])
	if data == null:
		return
	var saved: GameData = DB.data
	DB.data = data
	Game.new_game(0, "Kai", 3)
	Game.run_log = _spy
	var dialog: Node = (load(SCENE_DIALOG) as PackedScene).instantiate()
	dialog.call("setup", {})
	tree.root.add_child(dialog)
	_nodes.append(dialog)
	var r: Node = _room()
	await wait_frames(3)
	var first: SceneDef = r.get("pending_scene") as SceneDef
	assert_true(first != null and first.id == "scn_test_rep", "repeatable scene pending first")
	r.call("activate", "mopsula")
	await wait_frames(2)
	for i in 4:
		dialog.call("advance")
	var ok: bool = await wait_until(func() -> bool: return _spy.of_type("scene").size() == 1 and not bool(r.get("_busy")),
		WAIT)
	assert_true(ok, "repeatable scene played")
	var again: SceneDef = Game.next_scene(r.get("context") as Dictionary)
	assert_true(again != null and again.id == "scn_test_rep", "precondition: Game.next_scene offers it again")
	var nxt: SceneDef = r.get("pending_scene") as SceneDef
	assert_true(nxt != null and nxt.id == "scn_test_next", "the later qualifying scene is pending, not hidden")
	r.call("activate", "mopsula")
	await wait_frames(2)
	for i in 4:
		dialog.call("advance")
	var ok2: bool = await wait_until(func() -> bool: return _spy.of_type("scene").size() == 2 and not bool(r.get("_busy")),
		WAIT)
	assert_true(ok2, "second scene played in the same visit")
	assert_eq(_spy.of_type("scene"), [{"t": "scene", "id": "scn_test_rep"}, {"t": "scene", "id": "scn_test_next"}] as
		Array[Dictionary])
	assert_null(r.get("pending_scene"), "the repeatable scene does not come back in the same visit")
	DB.data = saved


func _data_with_scenes(scenes: Array) -> GameData:
	var tables: Dictionary = {}
	for t: String in GameData.TABLES:
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % t))
		if typeof(raw) != TYPE_DICTIONARY:
			fail("cannot read data/%s.json" % t)
			return null
		var d: Dictionary = raw
		tables[t] = d.get("entries", [])
		match t:
			"party":
				tables["party_start"] = d.get("start", {})
			"enemies":
				if d.has("pseudo_units"):
					tables["pseudo_units"] = d["pseudo_units"]
			"lootboxes":
				tables["lootbox_pools"] = d.get("pools", {})
				tables["lootbox_pity"] = d.get("pity", {"rare": 4, "epic": 8})
	tables["scenes"] = scenes
	return fixture_data(tables)


func test_event_run_cannot_save() -> void:
	var r: Node = _room()
	await wait_frames(2)
	Game.mode = &"event_offline"
	assert_null(r.call("open_save"), "no save dialog in event runs")
	assert_has(str(r.call("status_text")), "Event-Lauf", "explains why")
