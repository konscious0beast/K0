extends TestCase
## The Recall (06 §3.5; 08 F-7 named the floor-3 round so; 09 §11.3: the screen ST1-C1/ST1-D left open) in a basis
## season on the real data: what Casting offers where (first choice, trying again during the visit, the Umschulung of a
## later floor's first safe room — 06 §3.6), the safe room (opens by itself on the first visit of a room while a first
## choice is open, the RECALL button, "Später"), the screen (species and class cards with their sentences, badges, stats
## and the first class abilities; touch needs a second tap; ui_cancel goes back), the recorded commands ("casting" and
## the signature's "loadout") in both verifiers, the refusals outside the right place, the class bar it unlocks
## (09 §8.3), the species passives outside a combat (Original-Verpackung: battle followers, Flattermops: the bark), the
## level cap of floor 3, Ohne Netz after the first class choice (09 §2.2), the party page and the words of 09 §1.2.

const SCENE_SAFE_ROOM: String = "res://scenes/safe_room/safe_room.tscn"
const SCENE_RECALL: String = "res://scenes/ui/recall.tscn"
const RecallScript := preload("res://scenes/ui/recall.gd")
const UiUtil := preload("res://scenes/ui/ui_util.gd")
const PullRules := preload("res://scenes/exploration/pull_rules.gd")
const GameReplayScript := preload("res://autoload/game_replay.gd")
const ROOT: String = "user://test_09_recall"
const NOW: int = 1791918000                 # one hour before day 0 of the test seasons (season_core Kit.START)
## 09 §1.2: the floor-3 choice is a "Klasse"; "Beruf" are the crafts, "Vorleben" the casting's job — and never
## "Level", "Lv", "Ebene" or "Crawler" in anything a player reads.
const FORBIDDEN: PackedStringArray = ["Beruf", "Level", "Lv", "Ebene", "Crawler", "Spezialisierung"]

var _data: GameData = null


func before_each() -> void:
	_data = DB.data
	_rmrf(ROOT)
	Save.save_dir = ROOT.path_join("saves")
	Save.read_only = false
	tree.paused = false
	Game.set_input_scheme(Game.InputScheme.KEYBOARD_MOUSE)


func after_each() -> void:
	DB.data = _data
	tree.paused = false
	Game.clear_blocking_dialogs()
	Router.adopt(null)
	Sfx.stop_all()
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.persona = null
	Game.mode = &"campaign"
	Game.timer_running = false
	Game.in_battle = false
	Game.safe_room_clock = false
	Game.set_input_scheme(Game.InputScheme.KEYBOARD_MOUSE)
	Save._journal_close()
	Save.save_dir = "user://saves"
	_rmrf(ROOT)


static func _rmrf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for f: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	for sub: String in DirAccess.get_directories_at(path):
		_rmrf(path.path_join(sub))
	DirAccess.remove_absolute(path)


# --- helpers ----------------------------------------------------------------------------------------------------------

## A basis season Am Stück (real data, seed `seed`) taken down the stairs to `floor` (Game.season_debug_descend).
func _season_on(floor: int, seed: int = 21, hero: String = "kai") -> void:
	assert_true(Game.start_season(0, "ssn_basis", {"tempo": "binge", "seed": seed, "unlock": true, "now": NOW,
		"tz_sec": 0, "number": 1}, hero), "the season starts")
	while Game.state != null and Game.state.floor_run.index < floor:
		if not Game.season_debug_descend():
			fail("no stairs down to floor %d" % floor)
			return


## The safe rooms of the current floor in the order of their quarters (the first is the floor's first).
static func _rooms() -> PackedStringArray:
	var st: GameState = Game.state
	var layout: FloorLayout = DungeonGenerator.generate(DB.floor_def(st.floor_run.index), st.floor_run.seed)
	var out: PackedStringArray = []
	for cell: Vector2i in layout.safe_rooms:
		out.append(str(layout.safe_room_ids[cell]))
	return out


func _room(params: Dictionary = {}) -> Node:
	var r: Node = (load(SCENE_SAFE_ROOM) as PackedScene).instantiate()
	r.call("setup", params)
	add_to_tree(r)
	return r


static func _recall_of(r: Node) -> Node:
	for c: Node in r.get_children():
		if c.has_method("confirm") and c.has_signal("closed") and not c.is_queued_for_deletion():
			return c
	return null


## The Recall as a screen of its own (no room around it), for the member flow.
func _screen() -> Node:
	var rc: Node = (load(SCENE_RECALL) as PackedScene).instantiate()
	rc.call("setup", {})
	add_to_tree(rc)
	return rc


func _cmd_types_since(n: int) -> Array:
	var out: Array = []
	var cmds: Array[Dictionary] = Game.run_log.cmds()
	for i in range(n, cmds.size()):
		out.append(str((cmds[i]["c"] as Dictionary).get("t", "")))
	return out


## Every text of a node tree (labels and buttons).
static func _texts(n: Node) -> PackedStringArray:
	var out: PackedStringArray = []
	for c: Node in n.find_children("*", "Label", true, false):
		out.append((c as Label).text)
	for c: Node in n.find_children("*", "Button", true, false):
		out.append((c as Button).text)
	return out


# --- Casting: what the Recall offers where (06 §3.5, §3.6) ------------------------------------------------------------

func test_modes_on_floors_three_and_four() -> void:
	_season_on(2)
	var d: GameData = DB.data
	Game.enter_safe_room(_rooms()[0])
	assert_eq([Casting.mode(Game.state, d, "kai"), Casting.mode(Game.state, d, "mopsula")], ["", ""],
		"floor 2: no Recall yet (the wish: from floor 3, not from level 3)")
	Game.leave_safe_room()
	assert_true(Game.season_debug_descend())
	assert_eq(Game.state.floor_run.index, 3)
	assert_eq(Casting.mode(Game.state, d, "kai"), "", "floor 3, in the exploration: nothing")
	var rooms: PackedStringArray = _rooms()
	Game.enter_safe_room(rooms[0])
	assert_eq([Casting.mode(Game.state, d, "kai"), Casting.mode(Game.state, d, "mopsula")], ["first", "first"])
	assert_eq(Casting.open_members(Game.state, d), PackedStringArray(["kai", "mopsula"]), "the hero first")
	Game.state.hero = "mopsula"
	assert_eq(Casting.open_members(Game.state, d), PackedStringArray(["mopsula", "kai"]), "the hero first")
	Game.state.hero = "kai"
	assert_true(Game.choose_casting("kai", "spc_kai_neonfalter", "cls_kai_runner"))
	assert_eq(Casting.mode(Game.state, d, "kai"), "redo", "during the visit: species and class stay open")
	Game.leave_safe_room()
	Game.enter_safe_room(rooms[0])
	assert_eq(Casting.mode(Game.state, d, "kai"), "", "the next visit: Vertrag ist Vertrag")
	assert_eq(Casting.mode(Game.state, d, "mopsula"), "first", "a first choice waits in every safe room")
	assert_eq(Casting.open_members(Game.state, d), PackedStringArray(["mopsula"]))
	Game.leave_safe_room()
	assert_true(Game.season_debug_descend())
	var four: PackedStringArray = _rooms()
	Game.enter_safe_room(four[0])
	assert_eq(Casting.mode(Game.state, d, "kai"), "retrain", "floor 4's first safe room: the Umschulung")
	assert_true(Game.choose_casting("kai", "spc_kai_neonfalter", "cls_kai_showrunner"))
	assert_eq(Casting.mode(Game.state, d, "kai"), "retrain", "the rest of that visit: the class may change again")
	assert_false(Game.choose_casting("kai", "spc_kai_pilzling", "cls_kai_showrunner"), "the species stays")
	Game.leave_safe_room()
	Game.enter_safe_room(four[1])
	assert_eq(Casting.mode(Game.state, d, "kai"), "", "the floor's second safe room: no Umschulung")
	Game.leave_safe_room()
	Game.enter_safe_room(four[0])
	assert_eq(Casting.mode(Game.state, d, "kai"), "", "once per floor")
	assert_eq(Casting.open_members(Game.state, d), PackedStringArray(["mopsula"]), "the Count's first choice waits")


# --- the safe room: by itself, the button, "Später" -------------------------------------------------------------------

func test_no_recall_before_floor_three() -> void:
	_season_on(2)
	var r: Node = _room()
	await wait_frames(4)
	assert_null(_recall_of(r), "floor 2: the Recall does not open")
	assert_false(bool(r.call("recall_available")), "… and no RECALL button")
	assert_null(r.call("open_recall"), "nobody can choose here")


func test_the_recall_opens_by_itself_and_waits_after_later() -> void:
	_season_on(3)
	var r: Node = _room()
	assert_true(await wait_until(func() -> bool: return _recall_of(r) != null, 30),
		"06 §3.5 step 1: entering the safe room opens the Recall")
	var rc: Node = _recall_of(r)
	assert_eq([rc.get("member_id"), rc.get("step")], ["kai", RecallScript.STEP_SPECIES], "Kai first, species")
	assert_eq(str(rc.call("jury_text")), UiUtil.mod_line("casting_open", {}, 0),
		"M.O.D. as the jury: the Recall's one sentence (06 §0.5)")
	var said: Array = []
	var cb: Callable = func(_t: String, _v: StringName, tag: String, _b: bool) -> void: said.append(tag)
	Events.mod_said.connect(cb)
	var n0: int = Game.run_log.cmds().size()
	(rc.get("close_button") as Button).pressed.emit()
	await wait_frames(3)
	Events.mod_said.disconnect(cb)
	assert_has(said, "casting_later", "Später: M.O.D. says where the Recall waits")
	assert_eq(Game.run_log.cmds().size(), n0, "nothing was recorded")
	assert_null(_recall_of(r))
	assert_true(bool(r.call("recall_available")), "the RECALL button stays")
	var b: Button = (r.get("menu_buttons") as Dictionary)["recall"] as Button
	assert_eq((b.find_child("Text", true, false) as Label).text, "RECALL")
	assert_eq((b.find_child("Sub", true, false) as Label).text, "Spezies & Klasse wählen")
	assert_true(b.size.y >= UiTheme.TOUCH_HIT, "hit area >= 88 px: %.0f" % b.size.y)
	var talents: bool = bool(r.call("talent_show_available"))
	var top: float = r.get("CTA_TOP") + (float(UiTheme.TOUCH_HIT + r.get("MENU_GAP")) if talents else 0.0)
	assert_almost(b.offset_top, top, 0.5, "under the TALENT-SHOW while it is shown, else level with the first row")
	assert_eq(r.call("menu_ids"), PackedStringArray(["lootbox", "vending", "equipment", "hero", "mopsula", "save",
		"leave"]), "the menu keeps its seven entries")
	b.pressed.emit()
	await wait_frames(3)
	assert_not_null(_recall_of(r), "the button opens it again")
	(_recall_of(r) as Node).call("close")
	await wait_frames(2)
	Game.leave_safe_room()                      # (not r.leave(): the Router's way out would end the next scene)
	r.queue_free()
	await wait_frames(2)
	var again: Node = _room({"safe_room_id": str(Game.state.floor_run.visited_safe_rooms[0])})
	await wait_frames(4)
	assert_null(_recall_of(again), "a revisit only offers the button")
	assert_true(bool(again.call("recall_available")))


# --- the screen: one member's turn, both members, the end -------------------------------------------------------------

func test_a_whole_recall_records_both_turns_and_unlocks_the_class_bar() -> void:
	_season_on(3)
	Game.persona = PersonaProfile.canon(DB.data)           # Vorleben Tierpflege → the class tip Abrissbirne (08 C-9)
	var r: Node = _room()
	assert_true(await wait_until(func() -> bool: return _recall_of(r) != null, 30))
	var rc: Node = _recall_of(r)
	var n0: int = Game.run_log.cmds().size()
	var cards: Array = rc.get("card_buttons")
	assert_eq(Array(rc.get("options")), Array(Casting.options(Game.state, DB.data, "kai")["species"]),
		"step 1: every species of Kai, Original-Verpackung first")
	for c: Variant in cards:
		var card: Button = c
		assert_true(card.size.y >= UiTheme.TOUCH_HIT, "card hit area %.0f" % card.size.y)
		assert_ne((card.find_child("Line", true, false) as Label).text, "", "every card says its effect")
	assert_true(await wait_until(func() -> bool: return (cards[0] as Button).has_focus(), 30), "first card focused")
	(cards[1] as Button).grab_focus()
	await wait_frames(2)
	assert_eq(str(rc.get("preview_id")), "spc_kai_kachelgolem", "the detail follows the focus")
	var stats: Node = rc.find_child("Stats", true, false)
	assert_eq(stats.get_child_count(), 8, "eight stats before -> after")
	(cards[1] as Button).pressed.emit()                     # keyboard / mouse: choose and go on
	await wait_frames(2)
	assert_eq([rc.get("step"), rc.get("species_id")], [RecallScript.STEP_CLASS, "spc_kai_kachelgolem"])
	cards = rc.get("card_buttons")
	var pills: PackedStringArray = []
	for p: Node in (cards[0] as Button).find_child("Pills", true, false).get_children():
		pills.append(((p as Node).get_child(0) as Label).text)
	assert_eq(pills, PackedStringArray(["EMPFOHLEN", "PASST ZU IHREM VORLEBEN"]),
		"Abrissbirne: recommended by the Kachelgolem (06 §3.1) and the candidate's class tip (08 C-9)")
	assert_eq(str(rc.call("jury_text")), UiUtil.mod_line("persona_spec_hint:cls_kai_wrecker", {}, 0),
		"08 §4.3 H8: M.O.D. says the class tip on 'Was kannst du?'")
	var first: Node = rc.find_child("Ability_0", true, false)
	assert_not_null(first, "the class bar's first abilities from the ability book")
	if first != null:
		assert_true(_joined(_texts(first)).contains("beim Recall"), "the signature comes with the Recall")
	(cards[0] as Button).pressed.emit()
	await wait_frames(2)
	assert_eq(rc.get("step"), RecallScript.STEP_CONFIRM)
	assert_eq(Game.run_log.cmds().size(), n0, "nothing is recorded before Bestätigen")
	(rc.get("next_button") as Button).pressed.emit()        # BESTÄTIGEN
	await wait_frames(2)
	assert_eq(rc.get("step"), RecallScript.STEP_JUDGED)
	var cmds: Array[Dictionary] = Game.run_log.cmds()
	assert_eq(cmds[n0]["c"], {"t": "casting", "member": "kai", "species": "spc_kai_kachelgolem",
		"class": "cls_kai_wrecker"}, "the one recorded casting command")
	assert_eq(cmds[n0 + 1]["c"], RunRules.loadout_cmd("kai", {"1": "skl_kai_wrecking_ball"},
		Game.state.member("kai").rt_preset, Game.state.member("kai").rt_toggles),
		"… and the signature on slot 1 (recorded loadout)")
	assert_eq(str(rc.call("jury_text")), UiUtil.mod_line("casting_combo:spc_kai_kachelgolem:cls_kai_wrecker"),
		"06 §3.5 step 4: the jury on the pair")
	(rc.get("next_button") as Button).pressed.emit()        # WEITER: Graf Mopsula
	await wait_frames(2)
	assert_eq([rc.get("member_id"), rc.get("step")], ["mopsula", RecallScript.STEP_SPECIES], "06 §3.5 step 5")
	assert_eq(str(rc.call("jury_text")), UiUtil.mod_line("casting_species:mopsula", {}, 0))
	assert_true(bool(rc.call("choose", 3)), "Flattermops")
	assert_true(bool(rc.call("choose", 3)), "Zeremonienmeister")
	assert_true(bool(rc.call("confirm")))
	(rc.get("next_button") as Button).pressed.emit()
	await wait_frames(2)
	assert_eq(rc.get("step"), RecallScript.STEP_DONE, "the end page")
	var tree_b: Button = rc.get("tree_button") as Button
	assert_true(tree_b.visible, "06 §3.6 row 3: the talents can be re-picked right here")
	var t: Node = rc.call("open_tree")
	assert_not_null(t, "Talentbaum (09 §8.4: free re-picks in a safe room)")
	if t != null:
		assert_true(bool(t.call("can_pick")), "in the safe room the tree picks and re-picks")
		t.call("close")
		await wait_frames(2)
	assert_true(_joined(_texts(rc)).contains("Höchststufe auf dieser Etage: 13"), "06 §0.6: the cap rose to 13")
	assert_true(_joined(_texts(rc)).contains("NEU: OHNE NETZ"), "09 §2.2: the first class choice unlocks it")
	assert_true(bool(Save.career().get("no_net", false)), "… kept in the career file")
	assert_eq(_cmd_types_since(n0), ["casting", "loadout", "casting", "loadout"])
	for mid: String in ["kai", "mopsula"]:
		var m: PartyMember = Game.state.member(mid)
		assert_false(AbilityBook.class_variants(Game.state, DB.data, m).is_empty(), mid + ": the class bar is open")
		assert_eq(Casting.signature_loadout(Game.state, DB.data, mid), {}, mid + ": the signature is on its slot")
	var bars: Array = []                                    # the bar of the pull and of the combat (09 D-9)
	for mid: String in ["kai", "mopsula"]:
		var m: PartyMember = Game.state.member(mid)
		var slots: Dictionary = PullRules.bar_slots(m, DB.party_member(mid), AbilityBook.class_variants(Game.state,
			DB.data, m))
		bars.append(slots.get(1, ""))
	assert_eq(bars, ["skl_kai_wrecking_ball", "skl_mop_etiquette_flame"], "both signatures on slot 1")
	(rc.get("next_button") as Button).pressed.emit()        # FERTIG
	await wait_frames(3)
	assert_null(_recall_of(r))
	var b: Button = (r.get("menu_buttons") as Dictionary)["recall"] as Button
	assert_true(bool(r.call("recall_available")), "06 §3.6: during this visit both may still try again")
	assert_eq((b.find_child("Sub", true, false) as Label).text, "Umentscheiden – noch frei")
	Game.leave_safe_room()
	Game.enter_safe_room(str(Game.state.floor_run.visited_safe_rooms[0]))
	r.call("_refresh_menu_labels")
	assert_false(bool(r.call("recall_available")), "the next visit: Vertrag ist Vertrag — the button is gone")


func _joined(p: PackedStringArray) -> String:
	return " | ".join(p)


func test_touch_shows_first_and_chooses_on_the_second_tap() -> void:
	_season_on(3)
	Game.enter_safe_room(_rooms()[0])
	var rc: Node = _screen()
	await wait_frames(2)
	Game.set_input_scheme(Game.InputScheme.TOUCH)
	var cards: Array = rc.get("card_buttons")
	(cards[2] as Button).pressed.emit()
	await wait_frames(1)
	assert_eq([rc.get("step"), rc.get("preview_id")], [RecallScript.STEP_SPECIES, "spc_kai_neonfalter"],
		"a tap shows the card in the detail")
	(cards[2] as Button).pressed.emit()
	await wait_frames(1)
	assert_eq([rc.get("step"), rc.get("species_id")], [RecallScript.STEP_CLASS, "spc_kai_neonfalter"],
		"the second tap chooses it")
	cards = rc.get("card_buttons")
	(cards[1] as Button).pressed.emit()
	await wait_frames(1)
	assert_eq(rc.get("step"), RecallScript.STEP_CLASS)
	(rc.get("next_button") as Button).pressed.emit()          # or WEITER
	await wait_frames(1)
	assert_eq([rc.get("step"), rc.get("class_id")], [RecallScript.STEP_CONFIRM, "cls_kai_runner"])
	for b: Button in [rc.get("next_button") as Button, rc.get("back_button") as Button,
			rc.get("close_button") as Button]:
		assert_true(b.size.y >= UiTheme.TOUCH_HIT, "%s: hit area %.0f" % [b.name, b.size.y])
	rc.call("close")
	await wait_frames(1)


func test_cancel_goes_back_one_step() -> void:
	_season_on(3)
	Game.enter_safe_room(_rooms()[0])
	var rc: Node = _screen()
	await wait_frames(2)
	assert_true(bool(rc.call("choose", 2)))
	assert_true(bool(rc.call("choose", 1)))
	assert_eq(rc.get("step"), RecallScript.STEP_CONFIRM)
	var closed: Array[bool] = [false]
	rc.connect("closed", func() -> void: closed[0] = true)
	for want: int in [RecallScript.STEP_CLASS, RecallScript.STEP_SPECIES]:
		var ev: InputEventAction = InputEventAction.new()
		ev.action = &"ui_cancel"
		ev.pressed = true
		Input.parse_input_event(ev)
		await wait_frames(2)
		assert_eq(rc.get("step"), want, "ui_cancel: one step back")
	assert_eq(rc.get("species_id"), "spc_kai_neonfalter", "the choice so far stays")
	var esc: InputEventAction = InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	await wait_frames(2)
	assert_true(closed[0], "from the first step: Später")
	assert_eq(Game.state.member("kai").class_id, "", "nothing chosen")


# --- refusals: only where the Recall belongs --------------------------------------------------------------------------

func test_refusals_outside_the_right_place() -> void:
	_season_on(2)
	var n0: int = Game.run_log.cmds().size()
	Game.enter_safe_room(_rooms()[0])
	assert_eq(Casting.check(Game.state, DB.data, "kai", "spc_original", "cls_kai_wrecker"), "floor_too_low")
	assert_false(Game.choose_casting("kai", "spc_original", "cls_kai_wrecker"), "floor 2: refused")
	Game.leave_safe_room()
	assert_true(Game.season_debug_descend())
	assert_eq(Casting.check(Game.state, DB.data, "kai", "spc_original", "cls_kai_wrecker"), "not_in_safe_room")
	assert_false(Game.choose_casting("kai", "spc_original", "cls_kai_wrecker"), "floor 3, exploration: refused")
	Game.enter_safe_room(_rooms()[0])
	assert_false(Game.choose_casting("kai", "spc_mop_glutmops", "cls_kai_wrecker"), "the Count's species")
	assert_false(Game.choose_casting("mopsula", "spc_original", "cls_kai_wrecker"), "Kai's class")
	var types: Array = _cmd_types_since(n0)
	assert_false(types.has("casting"), "a refused choice records nothing")
	# a forged command: both verifiers refuse what Casting.check refuses
	var forged: RunLog = RunLog.from_dict(Game.run_log.to_dict())
	forged.add_cmd(Game.sim.tick(), {"t": "casting", "member": "kai", "species": "spc_mop_glutmops",
		"class": "cls_kai_wrecker"}, forged.last_cmd_id() + 1)
	var rs: Dictionary = RunSim.replay(DB.data, forged)
	assert_false((rs["errors"] as PackedStringArray).is_empty(), "RunSim.replay: the forged casting is an error")
	assert_true(" ".join(rs["errors"] as PackedStringArray).contains("not_for_member"), str(rs["errors"]))


# --- determinism: a Recall session in both verifiers ------------------------------------------------------------------

func test_a_recall_session_replays_in_both_verifiers() -> void:
	_season_on(3, 33)
	var rooms: PackedStringArray = _rooms()
	Game.enter_safe_room(rooms[0])
	var rc: Node = _screen()
	await wait_frames(2)
	for pick: Array in [[1, 0], [2, 1]]:                     # Kai: Kachelgolem / Abrissbirne, the Count: Spukmops / …
		assert_true(bool(rc.call("choose", pick[0])))
		assert_true(bool(rc.call("choose", pick[1])))
		assert_true(bool(rc.call("confirm")))
		(rc.get("next_button") as Button).pressed.emit()
		await wait_frames(1)
	assert_eq(rc.get("step"), RecallScript.STEP_DONE)
	rc.call("close")
	await wait_frames(1)
	var redo: Node = _screen()                               # the same visit: Kai tries again (06 §3.6)
	await wait_frames(2)
	assert_eq([redo.get("member_id"), redo.get("turn_mode")], ["kai", "redo"])
	assert_true(bool(redo.call("choose", 2)))                # Neonfalter …
	assert_true(bool(redo.call("choose", 1)))                # … Gleisläufer:in
	assert_true(bool(redo.call("confirm")))
	redo.call("close")
	await wait_frames(1)
	var kai: PartyMember = Game.state.member("kai")
	assert_eq([kai.species_id, kai.class_id], ["spc_kai_neonfalter", "cls_kai_runner"])
	assert_eq(kai.rt_loadout, {"1": "skl_kai_switch_kick"}, "the old signature left the bar, the new one is on it")
	Game.leave_safe_room()
	assert_true(Game.season_debug_descend())
	Game.enter_safe_room(_rooms()[0])
	var retrain: Node = _screen()
	await wait_frames(2)
	assert_eq([retrain.get("member_id"), retrain.get("turn_mode"), retrain.get("step")],
		["kai", "retrain", RecallScript.STEP_CLASS], "the Umschulung skips the species")
	assert_true(bool(retrain.call("choose", 3)))             # Showrunner:in
	assert_true(bool(retrain.call("confirm")))
	retrain.call("close")
	await wait_frames(1)
	assert_eq([kai.species_id, kai.class_id], ["spc_kai_neonfalter", "cls_kai_showrunner"])
	var types: Array = []
	for e: Dictionary in Game.run_log.cmds():
		types.append(str((e["c"] as Dictionary).get("t", "")))
	assert_eq(types.count("casting"), 4)
	assert_eq(types.count("loadout"), 4)
	var live: String = StateHash.of(Game.state)
	var core_live: Dictionary = _core_part(Game.state)
	var log: RunLog = Game.run_log
	# Game.replay_log's engine: every entry accepted, the same core state (the Show's own part — followers,
	# achievements — is the live debug descent's, not the Recall's: season_debug_descend skips the floor summary)
	var gr: RefCounted = GameReplayScript.new(Game)
	var g: Dictionary = gr.call("run", log, -1)
	assert_eq([g["errors"], g["mismatch_at"]], [PackedStringArray(), -1], "Game.replay_log accepts every entry")
	var shown: GameState = gr.get("_final_state")
	assert_not_null(shown)
	if shown != null:
		assert_eq(_core_part(shown), core_live, "Game.replay_log: the same species, classes, bookkeeping and bars")
	var r: Dictionary = RunSim.replay(DB.data, log)
	assert_eq([r["errors"], r["combat_mismatch_at"]], [PackedStringArray(), -1], "RunSim.replay accepts it all")
	var core: GameState = _core_replay(DB.data, log)
	assert_eq(StateHash.of(core), r["final_hash"], "(the walk of RunSim.replay)")
	assert_eq(_core_part(core), core_live, "RunSim.replay: the same species, classes, bookkeeping and bars")
	# deterministic: the same session again (same seed, same choices) — the same state, bit for bit
	var again: String = await _same_session_again()
	assert_eq(again, live, "a second live run of the same session")


## The session of test_a_recall_session_replays_in_both_verifiers through Game alone (no screen): its StateHash.
func _same_session_again() -> String:
	Game.state = null
	_season_on(3, 33)
	Game.enter_safe_room(_rooms()[0])
	for c: Array in [["kai", "spc_kai_kachelgolem", "cls_kai_wrecker"], ["mopsula", "spc_mop_spukmops",
			"cls_mop_physician"], ["kai", "spc_kai_neonfalter", "cls_kai_runner"]]:
		assert_true(Game.choose_casting(str(c[0]), str(c[1]), str(c[2])))
		var lo: Dictionary = Casting.signature_loadout(Game.state, DB.data, str(c[0]))
		if not lo.is_empty():
			assert_true(Game.apply_loadout(lo))
	Game.leave_safe_room()
	assert_true(Game.season_debug_descend())
	Game.enter_safe_room(_rooms()[0])
	assert_true(Game.choose_casting("kai", "spc_kai_neonfalter", "cls_kai_showrunner"))
	assert_true(Game.apply_loadout(Casting.signature_loadout(Game.state, DB.data, "kai")))
	await wait_frames(1)
	return StateHash.of(Game.state)


## The state without the Show's own part (Game.replay_log's alone, 05 §11.4) — what both verifiers agree on.
static func _core_part(st: GameState) -> Dictionary:
	var d: Dictionary = CanonicalJson.normalize(st.to_dict())
	for k: String in ["show", "pending_lootboxes", "play_time_sec", "slot"]:
		d.erase(k)
	if d.get("floor_run", null) is Dictionary:
		for k: String in ["achievements", "followers_gained", "viewers_peak"]:
			((d["floor_run"] as Dictionary).get("stats", {}) as Dictionary).erase(k)
	if d.get("season", null) is Dictionary:
		(d["season"] as Dictionary).erase("seen_unix")
	return d


## RunSim.replay's walk of a log that starts at a new game (the final state).
static func _core_replay(d: GameData, rl: RunLog) -> GameState:
	var h: Dictionary = rl.header
	var st: GameState = GameState.create_new(d, int(h.get("slot", 0)), GameState.DEFAULT_NAME, int(h.get("seed", 1)),
		StringName(str(h.get("difficulty", "prime"))))
	RunRules.rt_start(st, d)
	var sim: RunSim = RunSim.new(d, st, {}, RunSim.identity_of(h))
	var advance: Callable = func(k: int) -> void:
		sim.advance_to(k)
	var apply_cmd: Callable = func(i: int, c: Dictionary) -> int:
		sim.apply(c)
		return i + 1
	var on_checkpoint: Callable = func(_cp: int, k: int, _want: String) -> void:
		sim.settle()
		sim.advance_to(k)
	rl.walk(advance, apply_cmd, on_checkpoint)
	sim.settle()
	return st


# --- the re-spec rules (06 §3.6) and what a class change leaves -------------------------------------------------------

func test_respec_species_fixed_class_once_per_floor_and_the_bar_follows() -> void:
	_season_on(3, 44)
	var d: GameData = DB.data
	Game.enter_safe_room(_rooms()[0])
	assert_true(Game.choose_casting("kai", "spc_kai_pilzling", "cls_kai_wrecker"))
	assert_true(Game.apply_loadout(Casting.signature_loadout(Game.state, d, "kai")))
	var kai: PartyMember = Game.state.member("kai")
	assert_eq(kai.rt_loadout, {"1": "skl_kai_wrecking_ball"})
	assert_true(Game.choose_casting("kai", "spc_kai_teilautomat", "cls_kai_tinker"), "same visit: try again")
	assert_eq(kai.rt_loadout, {}, "the old class's signature leaves the bar (Casting.choose)")
	assert_eq(RunRules.loadout_refusal(Game.state, d, RunRules.loadout_cmd("kai", kai.rt_loadout)), "",
		"the skills menu's next loadout command is accepted (the whole bar)")
	Game.leave_safe_room()
	Game.enter_safe_room(_rooms()[0])
	assert_eq(Casting.check(Game.state, d, "kai", "spc_kai_pilzling", "cls_kai_tinker"), "locked",
		"Vertrag ist Vertrag")
	assert_eq(Casting.check(Game.state, d, "kai", "spc_kai_teilautomat", "cls_kai_runner"), "locked",
		"the class: once per floor, in its first safe room")
	Game.leave_safe_room()
	assert_true(Game.season_debug_descend())
	Game.enter_safe_room(_rooms()[0])
	assert_eq(Casting.check(Game.state, d, "kai", "spc_kai_teilautomat", "cls_kai_runner"), "", "Umschulung")
	assert_eq(Casting.check(Game.state, d, "kai", "spc_kai_pilzling", "cls_kai_runner"), "locked", "species stays")
	# the player's own party variants stay: a class change drops only the old class's abilities, the signature takes
	# only its own slot (today every signature is a slot-1 variant, and slot 1 has no party variant)
	kai.level = 9
	assert_true(Game.apply_loadout(RunRules.loadout_cmd("kai", {"2": "skl_kai_first_aid", "3": "skl_kai_cable_whip"},
		kai.rt_preset, kai.rt_toggles)))
	assert_true(Game.choose_casting("kai", "spc_kai_teilautomat", "cls_kai_runner"))
	assert_eq(kai.rt_loadout, {"2": "skl_kai_first_aid", "3": "skl_kai_cable_whip"}, "party variants are kept")
	assert_true(Game.apply_loadout(Casting.signature_loadout(Game.state, d, "kai")))
	assert_eq(kai.rt_loadout, {"1": "skl_kai_switch_kick", "2": "skl_kai_first_aid", "3": "skl_kai_cable_whip"},
		"the Gleisläufer:in's signature joins them on slot 1")


# --- species passives outside a combat, the level cap -----------------------------------------------------------------

func test_original_follows_the_show_and_flattermops_the_bark() -> void:
	_season_on(3, 55)
	var d: GameData = DB.data
	var st: GameState = Game.state
	var pm0: int = st.follower_pm(d)
	assert_eq(Casting.follower_pm(st, d), 1000, "nobody cast: neutral (runs without a season stay bit for bit)")
	Game.enter_safe_room(_rooms()[0])
	assert_true(Game.choose_casting("kai", "spc_original", "cls_kai_runner"))
	assert_eq(Casting.follower_pm(st, d), 1100, "Original-Verpackung: battle followers +10 %")
	assert_eq(st.follower_pm(d), (pm0 * 1100 + 500) / 1000)
	assert_true(Game.choose_casting("mopsula", "spc_original", "cls_mop_hexer"))
	assert_eq(Casting.follower_pm(st, d), 1210, "both original: the party product")
	assert_eq(HeroRules.field_mods(st, d)["range_pm"], 1000, "Kai leads: his strike, no species reach")
	assert_true(Game.choose_casting("mopsula", "spc_mop_flattermops", "cls_mop_hexer"), "same visit: try again")
	st.hero = "mopsula"
	assert_eq(HeroRules.field_mods(st, d)["range_pm"], 1500, "Flattermops leads: the bark reaches 50 % further")
	st.member("mopsula").talents["tal_mop_stereo"] = 1
	assert_eq(HeroRules.field_mods(st, d)["range_pm"], 1875, "with 'Bellen in Stereo': 1250 × 1500, round half up")
	st.member("mopsula").talents.erase("tal_mop_stereo")


func test_the_level_cap_rises_with_floor_three() -> void:
	_season_on(2, 66)
	var d: GameData = DB.data
	assert_eq(LevelBand.cap(Game.state, d), 10, "floor 2: band 7–10")
	assert_true(Game.season_debug_descend())
	assert_eq(LevelBand.cap(Game.state, d), 13, "floor 3: 13, as 06 §2.3 proposes (the band end, 09 §8.2)")
	Game.enter_safe_room(_rooms()[0])
	var rc: Node = _screen()
	await wait_frames(2)
	assert_true(_joined(_texts(rc)).contains("Etage 3 · Höchststufe 13"), "the Recall says so")
	rc.call("close")
	await wait_frames(1)


# --- layout: the whole screen fits a 720 px canvas --------------------------------------------------------------------

## The canvas is never smaller than 1280 × 720 (stretch aspect "expand"; the phone's is wider). The panel's minimum
## height stays inside the safe area for every card of every step of both members — the class detail (role, stats, the
## first class abilities) is the tallest.
func test_the_recall_fits_a_720p_screen() -> void:
	_season_on(3)
	Game.persona = PersonaProfile.canon(DB.data)
	Game.enter_safe_room(_rooms()[0])
	var rc: Node = _screen()
	await wait_frames(2)
	var panel: Control = rc.find_child("Panel", true, false) as Control
	assert_not_null(panel)
	if panel == null:
		return
	assert_true(panel.get_viewport_rect().size.x <= 1280.0, "measured on the narrowest canvas (1280 px wide)")
	var limit: float = 720.0 - 2.0 * SafeAreaContainer.EDGE
	var worst: Array = [0.0, ""]
	var probe: Callable = func(what: String) -> void:
		var h: float = panel.get_combined_minimum_size().y
		if h > float(worst[0]):
			worst[0] = h
			worst[1] = what
	for turn in 2:
		var mid: String = str(rc.get("member_id"))
		for step: int in [RecallScript.STEP_SPECIES, RecallScript.STEP_CLASS]:
			var cards: Array = rc.get("card_buttons")
			for i in cards.size():
				(cards[i] as Button).grab_focus()
				await wait_frames(1)
				probe.call("%s %s" % [mid, str(rc.get("preview_id"))])
			if step == RecallScript.STEP_SPECIES:
				assert_true(bool(rc.call("choose", 0)), mid + ": Original-Verpackung")
				await wait_frames(1)
		for i in (rc.get("options") as PackedStringArray).size():
			assert_true(bool(rc.call("choose", i)))
			await wait_frames(1)
			probe.call("%s confirm %s" % [mid, str(rc.get("class_id"))])
			rc.call("back")
			await wait_frames(1)
		assert_true(bool(rc.call("choose", 0)) and bool(rc.call("confirm")))
		await wait_frames(1)
		probe.call(mid + " judged")
		(rc.get("next_button") as Button).pressed.emit()
		await wait_frames(2)
	assert_eq(rc.get("step"), RecallScript.STEP_DONE)
	probe.call("the end page")
	assert_true(float(worst[0]) <= limit, "the tallest: %s, %.0f px of %.0f" % [worst[1], worst[0], limit])


# --- texts, lines, the party page -------------------------------------------------------------------------------------

func test_every_card_says_its_effect_in_one_sentence() -> void:
	DB.data = real_data()
	for sp: SpeciesDef in DB.data.all_species():
		var t: String = RecallScript.passive_text(sp)
		assert_between(t.length(), 8, 56, sp.id + ": one line on a card — " + t)
		assert_true(t.ends_with("."), sp.id + ": a sentence")
		assert_eq(UiUtil.missing_glyphs(t), "", sp.id + ": every glyph renders")
		for w: String in FORBIDDEN:
			assert_false(t.contains(w), "%s: no '%s'" % [sp.id, w])
	for c: ClassDef in DB.data.all_classes():
		assert_ne(c.desc, "", c.id + ": the role in one sentence")
		assert_eq(UiUtil.missing_glyphs(c.desc), "", c.id)
	assert_eq(RecallScript.passive_text(DB.species_def("spc_kai_kachelgolem")),
		"Erster erlittener Treffer je Kampf −30 %.", "the number is the data's (first_hit_taken_pm 700)")
	assert_eq(RecallScript.passive_text(DB.species_def("spc_mop_flattermops")),
		"Turbo zum Kampfstart; Bellen reicht 50 % weiter.")


func test_the_jury_has_a_line_for_every_step_and_pair() -> void:
	var d: GameData = real_data()
	for tag: String in ["casting_open", "casting_species", "casting_species:mopsula", "casting_class",
			"casting_class:mopsula", "casting_confirm", "casting_combo", "casting_redo", "casting_retrain",
			"casting_done", "casting_later", "casting_no_net"]:
		assert_gt(d.mod_lines(tag).size(), 0, "a line for " + tag)
	assert_eq(d.mod_lines("casting_open")[0].text,
		"Recall! Wer wollen Sie sein? Und was wollen Sie können? Die Jury bin ich.", "06 §0.5 word for word")
	for mid: String in ["kai", "mopsula"]:
		for s: SpeciesDef in d.all_species():
			if not s.is_for(mid):
				continue
			assert_gt(d.mod_lines("casting_combo:" + s.id).size(), 0, "every species has its own jury line")
			for c: String in s.recommended_classes:
				assert_gt(d.mod_lines("casting_combo:%s:%s" % [s.id, c]).size(), 0,
					"a recommended pair has its own line: %s + %s" % [s.id, c])
	var tags: Dictionary = {}
	for e: Variant in (JsonUtil.read_file("res://data/mod_lines.json") as Dictionary)["entries"]:
		if str((e as Dictionary)["tag"]).begins_with("casting_"):
			tags[str((e as Dictionary)["tag"])] = true
	assert_gt(tags.size(), 20, "the Recall block")
	for tag: Variant in tags.keys():
		for l: ModLineDef in d.mod_lines(str(tag)):
			assert_between(l.text.length(), 1, 110, l.id)
			assert_eq(UiUtil.missing_glyphs(l.text), "", l.id)
			for w: String in FORBIDDEN:
				assert_false(l.text.contains(w), "%s: no '%s' (09 §1.2)" % [l.id, w])


func test_the_party_page_says_where_the_recall_waits() -> void:
	var page: Script = load("res://scenes/ui/party_menu.gd") as Script
	_season_on(2, 77)
	var kai: PartyMember = Game.state.member("kai")
	assert_eq(page.call("casting_text", kai), "Spezies & Klasse: Recall auf Etage 3")
	assert_true(Game.season_debug_descend())
	assert_eq(page.call("casting_text", kai), "Spezies & Klasse: Recall offen – im Safe Room")
	Game.enter_safe_room(_rooms()[0])
	assert_true(Game.choose_casting("kai", "spc_kai_kachelgolem", "cls_kai_wrecker"))
	assert_eq(page.call("casting_text", kai), "Kachelgolem · Abrissbirne")
	var rc: Node = _screen()
	await wait_frames(2)
	for t: String in _texts(rc):
		for w: String in FORBIDDEN:
			assert_false(RegEx.create_from_string("\\b%s\\b" % w).search(t) != null, "'%s' in: %s" % [w, t])
	rc.call("close")
	await wait_frames(1)
