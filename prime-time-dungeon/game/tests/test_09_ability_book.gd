extends TestCase
## 09 §11.6 test_09_ability_book (ST1-D): the ability book of 09 §8.3 — the figures' bars (party.json rt.bar, levels
## 1–9) unchanged; the class bars (classes.json rt.bar: the signature at the Recall, then one ability on each of the
## levels 12, 17, 22, 27, 32, every one a variant of a slot 1–4 or the SHOW; real-time wording) and the ranks II–IV on
## 37 / 42 / 47 (RtMods skill_pm power, source class:<id>); what a level-up unlocks (the banner), the Klassen-Vorschau
## before the Recall; the loadout of a class ability (slots 1–5, only in a season, only once learned) and the combat:
## BattleBridge puts it on the bar and into the AI rules of its slot, the pull bar of the exploration agrees. Without a
## season the book is the figure's bar alone. The page "Fähigkeiten" as the book: class abilities on their slots, the
## ranks, a class ability chosen for slot 1 (the recorded loadout), the tab "Klassen-Vorschau" before the Recall.

const Kit := preload("res://tests/fixtures/season_core/season_core.gd")
const Harness := preload("res://tests/tools/rt_harness.gd")
const PullRules := preload("res://scenes/exploration/pull_rules.gd")
const CLASS_LEVELS: Array = [1, 12, 17, 22, 27, 32]
const RANKS: Array = [[37, 1100], [42, 1200], [47, 1300]]

var _data: GameData = null


func before_each() -> void:
	_data = DB.data


func after_each() -> void:
	DB.data = _data
	if Game.combat != null:
		Game.end_combat()
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.mode = &"campaign"
	Game.timer_running = false
	Game.in_battle = false
	Save._journal_close()


static func _member(id: String, level: int, class_id: String = "") -> PartyMember:
	var m: PartyMember = PartyMember.new()
	m.id = id
	m.level = level
	m.class_id = class_id
	return m


## A season run (Kit) with `hero` controlled; Kai of class `class_id` at `level`.
static func _season(class_id: String, level: int, hero: String = "kai") -> RunSim:
	var d: GameData = Kit.data(6)
	var s: RunSim = Kit.sim(d, "ssn_basis", "calendar", "net", Kit.SEED, hero)
	var kai: PartyMember = s.state.member("kai")
	kai.class_id = class_id
	kai.level = level
	return s


# --- the bars ---------------------------------------------------------------------------------------------------------

func test_the_figure_bars_are_unchanged() -> void:
	var d: GameData = real_data()
	for mid: String in ["kai", "mopsula"]:
		var prt: Dictionary = d.party_member(mid).rt
		var want: int = (prt.get("bar", []) as Array).size() + (prt.get("context", []) as Array).size()
		var rows: Array[Dictionary] = AbilityBook.rows(d, mid)
		assert_eq(rows.size(), want, mid + ": the bar of 07 §4.2 / §4.3 and its context row")
		for r: Dictionary in rows:
			assert_eq(r["source"], AbilityBook.SOURCE_PARTY)
			assert_between(int(r["level"]), 1, 9, mid + ": figure abilities on levels 1–9")
		for i in range(1, rows.size()):
			assert_true(int(rows[i - 1]["slot"]) <= int(rows[i]["slot"]), "sorted by slot")
		var camp: GameState = GameState.create_new(d, 0, "Kai", 4242, &"prime")
		var m: PartyMember = camp.member(mid)
		m.class_id = d.all_classes().filter(func(c: ClassDef) -> bool: return c.is_for(mid))[0].id
		assert_eq(AbilityBook.rows_of(camp, d, m), rows, mid + ": no season — the class bar stays out")
		assert_eq(AbilityBook.class_variants(camp, d, m), {})
		assert_eq(AbilityBook.rank_of(camp, d, m), Vector2i(1, 1000))


func test_the_class_bars_and_their_levels() -> void:
	var d: GameData = real_data()
	var turns: RegEx = RegEx.create_from_string("\\b(Runde|Runden|Zug|Züge|Zügen)\\b")
	var seen: Dictionary = {}
	var n: int = 0
	for c: ClassDef in d.all_classes():
		n += 1
		var bar: Array = c.rt.get("bar", []) as Array
		assert_eq(bar.map(func(b: Dictionary) -> int: return int(b["level"])), CLASS_LEVELS,
			c.id + ": the signature at the Recall, then 12, 17, 22, 27, 32 (09 §8.3)")
		assert_eq((c.rt.get("ranks", []) as Array).map(func(r: Dictionary) -> Array: return [int(r["level"]),
			int(r["pm"])]), RANKS, c.id + ": Rang II–IV, +10 % power each")
		assert_eq(int((bar[0] as Dictionary)["slot"]), 1, c.id + ": the signature is a main ability")
		var mid: String = c.for_members[0]
		for b: Variant in bar:
			var e: Dictionary = b
			var sid: String = str(e["skill"])
			assert_true(bool(e.get("variant", false)), sid + ": a variant of its slot")
			assert_between(int(e["slot"]), 1, 5, sid)
			assert_true(d.has_id("skills", sid), sid + " exists")
			assert_false(seen.has(sid), sid + ": in one class only")
			seen[sid] = true
			if not d.has_id("skills", sid):
				continue
			var sk: SkillDef = d.skill(sid)
			assert_eq(sk.category == "stunt", int(e["slot"]) == 5, sid + ": the SHOW slot holds the stunt")
			assert_ne(AbilityBook.base_skill(d, mid, int(e["slot"])), "", sid + ": its slot has a base ability")
			assert_true(sk.name != "" and sk.desc != "", sid + ": named and described")
			assert_eq(turns.search(sk.desc), null, sid + ": real-time wording, no turns — " + sk.desc)
			var rows: Array[Dictionary] = AbilityBook.rows(d, mid, c.id)
			var found: bool = false
			for r: Dictionary in rows:
				found = found or (str(r["skill"]) == sid and str(r["source"]) == c.id and str(r["kind"]) == "variant")
			assert_true(found, sid + ": in the book of " + c.id)
	assert_eq([n, seen.size()], [8, 48], "8 classes × 6 abilities")


# --- learning -------------------------------------------------------------------------------------------------------

func test_class_abilities_unlock_on_their_levels() -> void:
	var s: RunSim = _season("cls_kai_wrecker", 11)
	var d: GameData = s.data
	var kai: PartyMember = s.state.member("kai")
	assert_eq(AbilityBook.class_variants(s.state, d, kai), {"skl_kai_wrecking_ball": 1}, "the signature: the Recall")
	kai.level = 12
	assert_eq(AbilityBook.class_variants(s.state, d, kai), {"skl_kai_wrecking_ball": 1, "skl_kai_quick_concrete": 3})
	kai.level = 32
	assert_eq(AbilityBook.class_variants(s.state, d, kai).size(), 6, "all six at level 32")
	assert_eq(AbilityBook.new_between(kai, d, 11, 12), PackedStringArray(["skl_kai_quick_concrete"]),
		"the banner of level 12")
	assert_eq(AbilityBook.new_between(kai, d, 21, 27), PackedStringArray(["skl_kai_jackhammer",
		"skl_kai_demolition"]), "two at once (the crash course)")
	assert_eq(AbilityBook.new_between(kai, d, 0, 1).has("skl_kai_wrecking_ball"), false,
		"the signature comes with the Recall, not with a level")
	var party: PackedStringArray = AbilityBook.new_between(_member("kai", 1), d, 1, 4)
	for sid: String in party:
		assert_true(d.has_id("skills", sid), sid)
	assert_gt(party.size(), 0, "the figure's own abilities of levels 2–4")
	kai.class_id = ""
	assert_eq(AbilityBook.class_variants(s.state, d, kai), {}, "no class: no class abilities")
	var r: Dictionary = {"slot": 3, "skill": "skl_kai_quick_concrete", "level": 12, "kind": "variant",
		"source": "cls_kai_wrecker"}
	assert_false(AbilityBook.is_learned(kai, r), "another class's row is never learned")


func test_the_ranks_raise_every_class_ability() -> void:
	var s: RunSim = _season("cls_mop_physician", 36)
	var d: GameData = s.data
	var mop: PartyMember = s.state.member("mopsula")
	mop.class_id = "cls_mop_physician"
	var want: Array = [[36, Vector2i(1, 1000), Vector2i(2, 37)], [37, Vector2i(2, 1100), Vector2i(3, 42)],
		[42, Vector2i(3, 1200), Vector2i(4, 47)], [50, Vector2i(4, 1300), Vector2i.ZERO]]
	for w: Array in want:
		mop.level = int(w[0])
		assert_eq(AbilityBook.rank_of(s.state, d, mop), w[1], "level %d" % mop.level)
		assert_eq(AbilityBook.next_rank(d, mop), w[2])
	var mods: Array[Dictionary] = AbilityBook.rank_mods(s.state, d, mop, "p1")
	assert_eq(mods.size(), 6, "one mod per class ability")
	for md: Dictionary in mods:
		assert_eq([md["src"], md["op"], md["field"], md["pm"], md["unit"]], ["class:cls_mop_physician", "skill_pm",
			"power", 1300, "p1"])
	assert_eq(RtMods.validate(mods), PackedStringArray(), "valid RtMods")
	mop.level = 36
	assert_eq(AbilityBook.rank_mods(s.state, d, mop, "p1"), [] as Array[Dictionary], "Rang I: no mod")
	var camp: GameState = GameState.create_new(d, 0, "Kai", 1, &"prime")
	var m: PartyMember = camp.member("mopsula")
	m.class_id = "cls_mop_physician"
	m.level = 50
	assert_eq(AbilityBook.rank_mods(camp, d, m, "p1"), [] as Array[Dictionary], "no season: no ranks")


func test_the_preview_before_the_recall() -> void:
	var d: GameData = real_data()
	for mid: String in ["kai", "mopsula"]:
		var pv: Array[Dictionary] = AbilityBook.preview(d, mid)
		var ids: Array = []
		for c: ClassDef in d.all_classes():
			if c.is_for(mid):
				ids.append(c.id)
		assert_eq(pv.map(func(e: Dictionary) -> String: return str(e["class"])), ids, mid + ": all four classes")
		for e: Dictionary in pv:
			assert_eq((e["rows"] as Array).size(), 6, str(e["class"]) + ": six abilities")
			assert_eq((e["ranks"] as Array).size(), 3, "three ranks")
			assert_eq(e["name"], d.class_def(str(e["class"])).name)


# --- the loadout and the combat -----------------------------------------------------------------------------------

func test_the_loadout_of_class_abilities() -> void:
	var s: RunSim = _season("cls_kai_wrecker", 12)
	var d: GameData = s.data
	var st: GameState = s.state
	var ok: Dictionary = RunRules.loadout_cmd("kai", {"1": "skl_kai_wrecking_ball", "3": "skl_kai_quick_concrete"})
	assert_eq(Command.validate(ok), "", "slots 1 and 5 are valid keys now")
	assert_eq(RunRules.loadout_refusal(st, d, ok), "", "learned class abilities on their slots")
	var cases: Array = [[{"5": "skl_kai_demolition"}, "not_learned"], [{"2": "skl_kai_wrecking_ball"}, "not_a_variant"],
		[{"1": "skl_kai_switch_kick"}, "not_a_variant"]]
	for c: Array in cases:
		assert_eq(RunRules.loadout_refusal(st, d, RunRules.loadout_cmd("kai", c[0] as Dictionary)), c[1], str(c[0]))
	assert_ne(Command.validate(RunRules.loadout_cmd("kai", {"6": "skl_kai_wrecking_ball"})), "", "slot 6: the potion")
	s.apply(ok)
	assert_eq(st.member("kai").rt_loadout, {"1": "skl_kai_wrecking_ball", "3": "skl_kai_quick_concrete"})
	st.member("kai").level = 27
	assert_eq(RunRules.loadout_refusal(st, d, RunRules.loadout_cmd("kai", {"5": "skl_kai_demolition"})), "",
		"the SHOW variant from level 27")
	var camp: GameState = GameState.create_new(d, 0, "Kai", 1, &"prime")
	camp.member("kai").class_id = "cls_kai_wrecker"
	assert_eq(RunRules.loadout_refusal(camp, d, ok), "not_a_variant", "no season: no class abilities")


func test_the_combat_bar_and_the_ai_rules() -> void:
	var s: RunSim = _season("cls_kai_wrecker", 37, "mopsula")
	var d: GameData = s.data
	var st: GameState = s.state
	var kai: PartyMember = st.member("kai")
	kai.rt_loadout = {"1": "skl_kai_wrecking_ball", "3": "skl_kai_quick_concrete"}
	var cmd: Dictionary = Harness.command_for("enc_f1_a2", "mopsula", BattleSetup.Advantage.NORMAL)
	var setup: RtSetup = BattleBridge.make_rt_setup(st, d, cmd, 7)
	assert_not_null(setup)
	if setup == null:
		return
	var u: RtUnit = null
	for x: RtUnit in setup.units:
		if x.id == "p0":
			u = x
	assert_not_null(u, "Kai's unit")
	if u == null:
		return
	assert_eq([u.bar.get(1, ""), u.bar.get(3, "")], ["skl_kai_wrecking_ball", "skl_kai_quick_concrete"],
		"the chosen class abilities on their slots")
	var skills: Array = []
	for r: Dictionary in u.rules:
		skills.append(str(r.get("skill", "")))
	assert_false(skills.has("skl_kai_heavy_swing"), "the AI rules of slot 1 use the class ability")
	assert_has(skills, "skl_kai_wrecking_ball")
	assert_false(skills.has("skl_kai_leash_trip"), "and those of slot 3")
	var ranks: Array = setup.mods.filter(func(md: Dictionary) -> bool: return str(md.get("src", "")) \
		== "class:cls_kai_wrecker")
	assert_eq(ranks.size(), 6, "Rang II on level 37: every class ability")
	var pull: Dictionary = PullRules.bar_slots(kai, d.party_member("kai"), AbilityBook.class_variants(st, d, kai))
	assert_eq([pull.get(1, ""), pull.get(3, "")], [u.bar.get(1, ""), u.bar.get(3, "")],
		"the pull bar of the exploration agrees with the combat")
	var camp: GameState = GameState.create_new(real_data(), 0, "Kai", 4242, &"prime")
	RunRules.start_floor(camp, real_data(), 1)
	camp.hero = "mopsula"
	var ck: PartyMember = camp.member("kai")
	ck.class_id = "cls_kai_wrecker"
	ck.level = 10
	ck.rt_loadout = kai.rt_loadout.duplicate()
	var plain: RtSetup = BattleBridge.make_rt_setup(camp, real_data(), cmd, 7)
	for x: RtUnit in plain.units:
		if x.id == "p0":
			assert_eq(x.bar.get(1, ""), "skl_kai_heavy_swing", "no season: the figure's bar")


# --- the page "Fähigkeiten" as the book -------------------------------------------------------------------------------

func test_the_book_page_in_a_season() -> void:
	DB.data = Kit.data(6)
	assert_true(Game.start_season(0, "ssn_basis", {"now": Kit.START, "tz_sec": 0, "seed": 11}))
	var kai: PartyMember = Game.state.member("kai")
	kai.class_id = "cls_kai_wrecker"
	kai.level = 12
	var page: Control = (load("res://scenes/ui/skills_menu.gd") as GDScript).new() as Control
	add_to_tree(page)
	await wait_frames(2)
	for sid: String in ["skl_kai_heavy_swing", "skl_kai_wrecking_ball", "skl_kai_quick_concrete",
			"skl_kai_construction_fence"]:
		assert_not_null(page.find_child("RtSkill_" + sid, true, false), sid + " in the book")
	assert_eq(((page.find_child("RtSkill_skl_kai_construction_fence", true, false) as Node).find_child("Right", true,
		false) as Label).text, "ab Stufe 17", "ahead: its level")
	for r: int in [2, 3, 4]:
		assert_not_null(page.find_child("RtRank_%d" % r, true, false), "Rang %d" % r)
	var b: Button = page.find_child("RtSkill_skl_kai_wrecking_ball", true, false) as Button
	b.pressed.emit()
	await wait_frames(1)
	assert_eq(kai.rt_loadout, {"1": "skl_kai_wrecking_ball"}, "the signature on slot 1 (a recorded loadout)")
	assert_eq(Game.run_log.cmds().back()["c"]["t"], "loadout")
	assert_null(page.find_child("View_preview", true, false), "after the Recall: no preview tab")
	page.call("select_member", "mopsula")
	await wait_frames(1)
	assert_not_null(page.find_child("View_preview", true, false), "before the Recall: the tab Klassen-Vorschau")
	page.call("show_view", "preview")
	await wait_frames(1)
	assert_not_null(page.find_child("PreviewNote", true, false))
	var rows: int = 0
	for c: Node in page.find_children("RtSkill_*", "Button", true, false):
		rows += 1 if c.is_inside_tree() else 0
	assert_eq(rows, 24, "four classes × six abilities")
	page.queue_free()
	await wait_frames(1)
	Game.new_game(1, "Kai", 3)
	Game.state.member("kai").class_id = "cls_kai_wrecker"
	var plain: Control = (load("res://scenes/ui/skills_menu.gd") as GDScript).new() as Control
	add_to_tree(plain)
	await wait_frames(2)
	assert_null(plain.find_child("RtSkill_skl_kai_wrecking_ball", true, false), "no season: the figure's bar only")
	assert_null(plain.find_child("View_preview", true, false))
	plain.queue_free()
	await wait_frames(1)
