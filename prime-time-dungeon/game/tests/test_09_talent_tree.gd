extends TestCase
## 09 §11.6 test_09_talent_tree (ST1-D): the talent tree of 09 §8.4 — its rows (base 3/5/7/9 out of the 24 talents of
## 06-B with their ranks merged into one value, decision D-2; class rows 15/25/35/45 with a branch on each outer column;
## figure rows 20/30/40/50), one of three per row, every text one sentence that names its effect (06 L-1); the command
## "talent" v2: picks and free re-picks only in a safe room, every refusal reason, the 06-B pick refused; the effects of
## the picks (stats, the Talents kinds, RtMods with the source talent:<id> into the combat setup); a class change frees
## the class rows; the caps (level 10: the 06 band of +15 % per stat; level 50: +30 % per stat, crit ≤ +120 ‰, damage
## from skill_pm / dmg_dealt_pm ≤ +40 %, damage taken ≥ −25 % — exact over every pick sequence, reduced to the peaks of
## every row as 09 §8.4 allows); the V-20 switch (decision D-1: designed, tested, off) — on, the campaign and an event
## run use the tree and the migration of 09 §8.7 resets their 06-B picks on load; off, nothing changes; and a season
## session with picks and re-picks in both verifiers (RunSim.replay, Game.replay_log's engine); the screens — the
## Talent-Show presents rows, the talent tree picks and re-picks only in a safe room, the party page of a season.

const Kit := preload("res://tests/fixtures/season_core/season_core.gd")
const Harness := preload("res://tests/tools/rt_harness.gd")
const GameReplayScript := preload("res://autoload/game_replay.gd")
const ROOT: String = "user://test_09_talent_tree"
const DAY: int = Kit.DAY
const DAY0: int = Kit.DAY0
## The additive kinds (ranks merge by multiplying the value); the others are factors (1000 = neutral).
const ADDITIVE: PackedStringArray = ["stat_flat", "stat_pct", "crit_add_pm", "post_battle_mp_pm", "liga_stat_pct",
	"marotte_heart"]
const STAT_CAP_L10_PM: int = 150             # 06 §8.3: +15 % at level 10
const STAT_CAP_L50_PM: int = 300             # 09 §8.4: +30 % at level 50
const CRIT_CAP_PM: int = 120
const DMG_CAP_PM: int = 1400
const TAKEN_FLOOR_PM: int = 750

var _data: GameData = null


func before_each() -> void:
	_data = DB.data
	_rmrf(ROOT)
	Save.save_dir = ROOT.path_join("saves")
	Save.read_only = false


func after_each() -> void:
	TalentTree.everywhere = false
	DB.data = _data
	if Game.combat != null:
		Game.end_combat()
	Show.abort_battle()
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.quest = null
	Game.persona = null
	Game.mode = &"campaign"
	Game.timer_running = false
	Game.in_battle = false
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


static func _first_safe_room(d: GameData, st: GameState) -> String:
	var layout: FloorLayout = DungeonGenerator.generate(d.floor_def(st.floor_run.index), st.floor_run.seed)
	return str(layout.safe_room_ids[layout.safe_rooms[0]])


static func _set_level(m: PartyMember, level: int, d: GameData) -> void:
	m.level = level
	m.exp = 0
	var sb: StatBlock = Progression.total_stats(m, d)
	m.hp = sb.values[StatBlock.Stat.HP]
	m.mp = sb.values[StatBlock.Stat.MP]


static func _stat(m: PartyMember, d: GameData, i: int) -> int:
	return Progression.total_stats(m, d).values[i]


## The stat `i` of `m` without its tree picks.
static func _stat_without_rows(m: PartyMember, d: GameData, i: int) -> int:
	var rows: Dictionary = m.talent_rows
	m.talent_rows = {}
	var v: int = _stat(m, d, i)
	m.talent_rows = rows
	return v


static func _cmd(member: String, row: int, id: String) -> Dictionary:
	return {"t": "talent", "v": 2, "member": member, "row": row, "id": id}


## Numbers of a JSON-ish value as ints (data effects may hold floats).
static func _norm(v: Variant) -> Variant:
	if v is Dictionary:
		var out: Dictionary = {}
		for k: Variant in (v as Dictionary).keys():
			out[str(k)] = _norm((v as Dictionary)[k])
		return out
	if v is Array:
		return (v as Array).map(func(e: Variant) -> Variant: return _norm(e))
	if v is float:
		return int(v)
	return v


# --- the rows ---------------------------------------------------------------------------------------------------------

func test_the_rows_of_every_tree() -> void:
	var d: GameData = real_data()
	var n: int = 0
	for t: TalentDef in d.all_talents():
		n += 1 if t.is_tree() else 0
	assert_eq(n, 2 * 8 * 3 + 8 * 4 * 3, "two figures × 8 rows, eight classes × 4 rows, three talents each")
	var sentence: RegEx = RegEx.create_from_string("[.!?](\\s|$)")
	for mid: String in ["kai", "mopsula"]:
		var classes: int = 0
		for c: ClassDef in d.all_classes():
			if not c.is_for(mid):
				continue
			classes += 1
			var m: PartyMember = PartyMember.new()
			m.id = mid
			m.level = 50
			m.class_id = c.id
			assert_eq(TalentTree.rows(d, m), TalentDef.tree_rows(), "%s / %s: every row" % [mid, c.id])
			var specs: Array = ["", ""]
			for row: int in TalentDef.tree_rows():
				var three: Array[TalentDef] = TalentTree.row_talents(d, m, row)
				assert_eq(three.size(), 3, "%s row %d: one of three" % [c.id, row])
				for i in three.size():
					var t: TalentDef = three[i]
					assert_eq([t.col, t.max_rank, t.row], [i + 1, 1, row], t.id)
					assert_true(t.is_for(mid), t.id + " is for " + mid)
					assert_eq(t.tree, c.id if TalentDef.CLASS_ROWS.has(row) else mid, t.id + ": its tree")
					assert_eq(sentence.search_all(t.desc).size(), 1, t.id + ": one sentence — " + t.desc)
					assert_true(t.desc.length() <= 90 and t.name.length() <= 32, t.id + ": fits its card")
					if TalentDef.CLASS_ROWS.has(row) and i != 1:
						var k: int = 0 if i == 0 else 1
						assert_ne(t.spec, "", t.id + ": an outer column names its branch")
						if specs[k] == "":
							specs[k] = t.spec
						assert_eq(t.spec, specs[k], t.id + ": one branch per side")
					else:
						assert_eq(t.spec, "", t.id + ": no branch")
			assert_ne(specs[0], specs[1], c.id + ": two branches")
		assert_eq(classes, 4, mid + ": four classes")


func test_the_base_rows_are_the_24_talents_of_06b() -> void:
	var d: GameData = real_data()
	var used: Dictionary = {}
	for mid: String in ["kai", "mopsula"]:
		var m: PartyMember = PartyMember.new()
		m.id = mid
		m.level = 9
		for row: int in TalentDef.BASE_ROWS:
			for t: TalentDef in TalentTree.row_talents(d, m, row):
				var twin: TalentDef = null
				for p: TalentDef in d.talents_for(mid):
					if p.name == t.name:
						twin = p
				assert_not_null(twin, t.id + ": a talent of the 06-B pool")
				if twin == null:
					continue
				used[twin.id] = true
				var merged: Array = []
				for fx: Dictionary in twin.effects:
					var e: Dictionary = _norm(fx)
					for key: String in ["value", "pm", "per_floor"]:
						if not e.has(key):
							continue
						if ADDITIVE.has(str(e["kind"])):
							e[key] = int(e[key]) * twin.max_rank
						else:
							e[key] = 1000 + (int(e[key]) - 1000) * twin.max_rank
					merged.append(e)
				assert_eq(_norm(t.effects), merged, "%s: the ranks of %s in one value (D-2)" % [t.id, twin.id])
	assert_eq(used.size(), 24, "every talent of the pool has its cell")
	for mid: String in ["kai", "mopsula"]:
		assert_eq(d.talents_for(mid).size(), 12, mid + ": the 06-B pool stays for the runs without a season")


# --- "talent" v2 ------------------------------------------------------------------------------------------------------

func test_a_pick_and_a_re_pick_only_in_a_safe_room() -> void:
	var d: GameData = Kit.data(6)
	var s: RunSim = Kit.sim(d)
	var st: GameState = s.state
	var kai: PartyMember = st.member("kai")
	_set_level(kai, 6, d)
	_set_level(st.member("mopsula"), 2, d)
	assert_eq(Array(TalentTree.open_rows(st, d, kai)), [3, 5], "the rows reached: 3 and 5")
	assert_eq(Talents.open_choices(st, d), 2, "the badges count the open rows")
	assert_true(Talents.has_choice(st, d, "kai"))
	assert_false(Talents.has_choice(st, d, "mopsula"), "level 2: no row yet")
	var r3: Array[TalentDef] = TalentTree.row_talents(d, kai, 3)
	assert_eq(RunRules.command_refusal(st, d, {}, _cmd("kai", 3, r3[0].id), false, {}), "not_in_safe_room",
		"picks only in a safe room (09 §9.1)")
	s.apply(_cmd("kai", 3, r3[0].id))
	assert_eq(s.rejected_cmds.back()["reason"], "not_in_safe_room", "RunSim refuses it too")
	s.apply({"t": "safe_room", "id": _first_safe_room(d, st)})
	var str0: int = _stat(kai, d, StatBlock.Stat.STR)
	var hp_max0: int = _stat(kai, d, StatBlock.Stat.HP)
	var ev: Array = s.apply(_cmd("kai", 3, r3[0].id))
	var e: Dictionary = Kit.event(ev, "talent")
	assert_eq([e.get("member"), e.get("row"), e.get("id"), e.get("before")], ["kai", 3, r3[0].id, ""], "a first pick")
	assert_eq(kai.talent_rows, {"3": r3[0].id})
	assert_eq(_stat(kai, d, StatBlock.Stat.STR), str0 + 2, r3[0].name + ": STR +2")
	assert_eq(Array(TalentTree.open_rows(st, d, kai)), [5])
	var credits: int = st.inventory.credits
	var hp0: int = kai.hp
	ev = s.apply(_cmd("kai", 3, r3[1].id))
	assert_eq(Kit.event(ev, "talent").get("before"), r3[0].id, "a re-pick names the old talent")
	assert_eq([kai.talent_rows, st.inventory.credits], [{"3": r3[1].id}, credits], "free (09 §8.4)")
	assert_eq(_stat(kai, d, StatBlock.Stat.STR), str0, "the old effect is gone")
	var hp_max: int = _stat(kai, d, StatBlock.Stat.HP)
	assert_eq(hp_max, (hp_max0 * 1100 + 500) / 1000, r3[1].name + ": HP +10 %")
	assert_eq(kai.hp, hp0 + hp_max - hp_max0, "HP follow the maximum like a level-up")
	var r5: Array[TalentDef] = TalentTree.row_talents(d, kai, 5)
	var cases: Array = [[_cmd("kai", 3, r3[1].id), "same"],
		[_cmd("kai", 7, TalentTree.row_talents(d, kai, 7)[0].id), "row_locked"],
		[_cmd("kai", 4, r3[0].id), "unknown_row"],
		[_cmd("kai", 15, r3[0].id), "unknown_row"],
		[_cmd("kai", 5, r3[0].id), "not_in_row"],
		[_cmd("kai", 5, TalentTree.row_talents(d, st.member("mopsula"), 5)[0].id), "not_in_row"],
		[_cmd("nobody", 3, r3[0].id), "unknown_member"],
		[{"t": "talent", "member": "kai", "id": d.talents_for("kai")[0].id}, TalentTree.TREE_RULES]]
	for c: Array in cases:
		var n: int = s.rejected_cmds.size()
		s.apply(c[0] as Dictionary)
		assert_eq([s.rejected_cmds.size(), s.rejected_cmds.back()["reason"]], [n + 1, c[1]], str(c[0]))
	assert_true(kai.talents.is_empty(), "no 06-B pick in a season")
	s.apply(_cmd("kai", 5, r5[2].id))
	s.apply({"t": "safe_room_exit"})
	assert_eq(RunRules.command_refusal(st, d, {}, _cmd("kai", 5, r5[0].id), false, {}), "not_in_safe_room",
		"re-picks only in a safe room too")
	assert_eq(kai.talent_rows, {"3": r3[1].id, "5": r5[2].id})
	assert_eq(Talents.open_choices(st, d), 0)


func test_the_effects_reach_the_combat() -> void:
	var d: GameData = Kit.data(6)
	var s: RunSim = Kit.sim(d)
	var st: GameState = s.state
	var kai: PartyMember = st.member("kai")
	kai.class_id = "cls_kai_wrecker"
	_set_level(kai, 50, d)
	var picks: Dictionary = {}
	for row: int in [5, 15, 40]:
		picks[str(row)] = TalentTree.row_talents(d, kai, row)[0 if row != 15 else 2].id
	kai.talent_rows = picks.duplicate()
	assert_eq(Talents.crit_add_pm(kai, d), 60, "Fester Griff: a Talents kind")
	var mods: Array[Dictionary] = TalentTree.rt_mods(d, kai, "p0")
	var srcs: Array = mods.map(func(md: Dictionary) -> String: return str(md["src"]))
	assert_eq(srcs, ["talent:" + picks["15"], "talent:" + picks["15"], "talent:" + picks["40"]],
		"one mod per rt_mod effect, in row order")
	for md: Dictionary in mods:
		assert_eq(md.get("unit"), "p0", "on the member's own unit")
		assert_false(md.has("kind"))
		assert_eq(RtMods.validate([md]), PackedStringArray(), str(md))
	var cmd: Dictionary = Harness.command_for("enc_f1_a2", "kai", BattleSetup.Advantage.NORMAL)
	var setup: RtSetup = BattleBridge.make_rt_setup(st, d, cmd, 7)
	assert_not_null(setup)
	if setup == null:
		return
	var tsrc: Array = []
	for md: Dictionary in setup.mods:
		if str(md.get("src", "")).begins_with("talent:"):
			tsrc.append(str(md["src"]))
	assert_eq(tsrc, srcs, "BattleBridge puts them into the combat (after the class, 07 §9.5)")
	var camp: GameState = GameState.create_new(real_data(), 0, "Kai", 4242, &"prime")
	camp.member("kai").talent_rows = picks.duplicate()
	RunRules.start_floor(camp, real_data(), 1)
	var plain: RtSetup = BattleBridge.make_rt_setup(camp, real_data(), cmd, 7)
	for md: Dictionary in plain.mods:
		assert_false(str(md.get("src", "")).begins_with("talent:"), "no season: no tree mods")


func test_a_class_change_frees_the_class_rows() -> void:
	var d: GameData = real_data()
	var m: PartyMember = PartyMember.new()
	m.id = "kai"
	m.level = 25
	m.class_id = "cls_kai_wrecker"
	var s: RunSim = Kit.sim(Kit.data(6))
	var st: GameState = s.state
	var r15: Array[TalentDef] = TalentTree.row_talents(d, m, 15)
	var r25: Array[TalentDef] = TalentTree.row_talents(d, m, 25)
	m.talent_rows = {"3": TalentTree.row_talents(d, m, 3)[0].id, "15": r15[0].id, "20": TalentTree.row_talents(d, m,
		20)[1].id, "25": r25[0].id}
	assert_eq(TalentTree.spec_of(d, m), r15[0].spec, "mostly left: the left branch as a badge")
	m.talent_rows["25"] = r25[2].id
	assert_eq(TalentTree.spec_of(d, m), "", "a tie: no badge")
	m.class_id = "cls_kai_runner"                         # Umschulung (06 §3.6)
	assert_eq(TalentTree.pick_of(d, m, 15), "", "the class rows are free")
	assert_eq(TalentTree.pick_of(d, m, 25), "")
	assert_ne(TalentTree.pick_of(d, m, 3), "", "the base rows stay")
	assert_ne(TalentTree.pick_of(d, m, 20), "", "the figure rows stay")
	st.party[0] = m
	assert_eq(Array(TalentTree.open_rows(st, d, m)), [5, 7, 9, 15, 25], "two rows to choose for the new class")
	assert_eq(TalentTree.row_talents(d, m, 15)[0].tree, "cls_kai_runner")
	m.class_id = ""
	assert_eq(Array(TalentTree.open_rows(st, d, m)), [5, 7, 9], "no class (before the Recall): no class rows")
	m.class_id = "cls_kai_wrecker"
	assert_eq(TalentTree.pick_of(d, m, 15), r15[0].id, "back to the old class: its picks count again")


# --- the caps ---------------------------------------------------------------------------------------------------------

func test_the_cap_at_level_10_for_every_pick_sequence() -> void:
	var d: GameData = real_data()
	for mid: String in ["kai", "mopsula"]:
		var bare: PartyMember = PartyMember.new()
		bare.id = mid
		bare.level = 10
		var base: PackedInt32Array = Progression.total_stats(bare, d).values
		var rows: Array = []
		for row: int in TalentDef.BASE_ROWS:
			rows.append(TalentTree.row_talents(d, bare, row))
		var worst: PackedInt32Array = []
		worst.resize(base.size())
		var crit_max: int = 0
		var mp_max: int = 0
		var n: int = 0
		for a in 3:
			for b in 3:
				for c in 3:
					for e in 3:
						bare.talent_rows = {"3": (rows[0] as Array)[a].id, "5": (rows[1] as Array)[b].id,
							"7": (rows[2] as Array)[c].id, "9": (rows[3] as Array)[e].id}
						var v: PackedInt32Array = Progression.total_stats(bare, d).values
						for i in v.size():
							worst[i] = maxi(worst[i], v[i] - base[i])
							assert_true((v[i] - base[i]) * 1000 <= base[i] * STAT_CAP_L10_PM, "%s %s: +%d on %d" % [
								mid, StatBlock.KEYS[i], v[i] - base[i], base[i]])
						crit_max = maxi(crit_max, Talents.crit_add_pm(bare, d))
						mp_max = maxi(mp_max, Talents.post_battle_mp_pm(bare, d))
						n += 1
		assert_eq(n, 81, "3^4 pick sequences")
		assert_true(crit_max <= 80 and mp_max <= 100, "%s: crit +%d, Werbepause +%d (06 band)" % [mid, crit_max,
			mp_max])
		print("[09_talent_tree] %s level 10: worst bonus per stat %s on %s" % [mid, str(Array(worst)), str(Array(base))])


func test_the_caps_at_level_50_for_every_pick_sequence() -> void:
	var d: GameData = real_data()
	for mid: String in ["kai", "mopsula"]:
		for c: ClassDef in d.all_classes():
			if not c.is_for(mid):
				continue
			var m: PartyMember = PartyMember.new()
			m.id = mid
			m.level = 50
			m.class_id = c.id
			var rows: Array = []
			for row: int in TalentDef.tree_rows():
				rows.append(TalentTree.row_talents(d, m, row))
			var bare: PartyMember = PartyMember.new()
			bare.id = mid
			bare.level = 50
			var base: PackedInt32Array = Progression.total_stats(bare, d).values   # the strictest base
			var worst: Array = []
			for i in base.size():
				var bonus: int = _max_stat_bonus(rows, StatBlock.KEYS[i], base[i])
				worst.append(bonus)
				assert_true(bonus * 1000 <= base[i] * STAT_CAP_L50_PM, "%s %s: +%d on %d" % [c.id, StatBlock.KEYS[i],
					bonus, base[i]])
			var crit: int = 0
			var taken: int = 1000
			for r: Variant in rows:
				var best: int = 0
				var low: int = 1000
				for t: TalentDef in (r as Array):
					var sum: int = 0
					var prod: int = 1000
					for fx: Dictionary in t.effects:
						if str(fx["kind"]) == "crit_add_pm":
							sum += int(fx["pm"])
						if str(fx["kind"]) == "rt_mod" and str(fx.get("op", "")) == "dmg_taken_pm":
							prod = prod * int(fx["pm"]) / 1000
					best = maxi(best, sum)
					low = mini(low, prod)
				crit += best
				taken = taken * low / 1000
			var dmg: Dictionary = {}
			for sid: String in _skills_of(d, mid, c.id):
				dmg[sid] = _max_damage_pm(rows, sid)
				assert_true(int(dmg[sid]) <= DMG_CAP_PM, "%s %s: damage × %d ‰" % [c.id, sid, int(dmg[sid])])
			assert_true(crit <= CRIT_CAP_PM, "%s: crit +%d ‰" % [c.id, crit])
			assert_true(taken >= TAKEN_FLOOR_PM, "%s: damage taken × %d ‰" % [c.id, taken])
			var top: int = 0
			for v: Variant in dmg.values():
				top = maxi(top, int(v))
			print("[09_talent_tree] %s level 50: worst bonus per stat %s on %s, crit +%d, damage ≤ %d ‰, taken ≥ %d ‰"
				% [c.id, str(worst), str(Array(base)), crit, top, taken])


## The largest bonus on stat `key` over every pick sequence of `rows` (exact: per row its distinct (flat, ‰) pairs on
## that stat, every combination — few rows touch one stat), applied like Talents.stat_bonus on `base`.
static func _max_stat_bonus(rows: Array, key: String, base: int) -> int:
	var combos: Array = [Vector2i.ZERO]
	for r: Variant in rows:
		var pairs: Array = [Vector2i.ZERO]
		for t: TalentDef in (r as Array):
			var p: Vector2i = Vector2i.ZERO
			for fx: Dictionary in t.effects:
				if str(fx.get("stat", "")) != key:
					continue
				if str(fx["kind"]) == "stat_flat":
					p.x += int(fx["value"])
				elif str(fx["kind"]) == "stat_pct" or str(fx["kind"]) == "liga_stat_pct":
					p.y += int(fx["pm"])
			if not pairs.has(p):
				pairs.append(p)
		if pairs.size() == 1:
			continue
		var next: Array = []
		for a: Variant in combos:
			for b: Variant in pairs:
				var sum: Vector2i = (a as Vector2i) + (b as Vector2i)
				if not next.has(sum):
					next.append(sum)
		combos = next
	var best: int = 0
	for cmb: Variant in combos:
		var v: int = base + (cmb as Vector2i).x
		if (cmb as Vector2i).y != 0:
			v = (maxi(0, v) * (1000 + (cmb as Vector2i).y) + 500) / 1000
		best = maxi(best, v - base)
	return best


## The largest damage factor (‰) on skill `sid` over every pick sequence: per row the strongest talent on it (skill_pm
## power of the skill or "*", dmg_dealt_pm), multiplied (every factor ≥ 1000, so the peaks of the rows are exact).
static func _max_damage_pm(rows: Array, sid: String) -> int:
	var acc: int = 1000
	for r: Variant in rows:
		var best: int = 1000
		for t: TalentDef in (r as Array):
			var f: int = 1000
			for fx: Dictionary in t.effects:
				if str(fx["kind"]) != "rt_mod":
					continue
				var op: String = str(fx.get("op", ""))
				if op == "dmg_dealt_pm" or (op == "skill_pm" and str(fx.get("field", "")) == "power"
						and (str(fx.get("skill", "")) == sid or str(fx.get("skill", "")) == "*")):
					f = f * int(fx["pm"]) / 1000
			best = maxi(best, f)
		acc = acc * best / 1000
	return acc


## Every ability of the figure's bar and of the class bar.
static func _skills_of(d: GameData, mid: String, class_id: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for r: Dictionary in AbilityBook.rows(d, mid, class_id):
		if not out.has(str(r["skill"])):
			out.append(str(r["skill"]))
	return out


# --- the V-20 switch and the migration (09 §8.7) ----------------------------------------------------------------------

func test_the_v20_switch_off_keeps_the_06b_talent_show() -> void:
	assert_false(TalentTree.everywhere, "D-1: designed and tested, off until the ST1 gate")
	var d: GameData = real_data()
	var st: GameState = GameState.create_new(d, 0, "Kai", 4242, &"prime")
	RunRules.start_floor(st, d, 1)
	var kai: PartyMember = st.member("kai")
	_set_level(kai, 5, d)
	assert_false(TalentTree.governs(st))
	assert_eq(Array(Talents.pending_levels(kai)), [3, 5], "the odd levels of 06-B")
	assert_eq(TalentTree.open_rows(st, d, kai).size(), 0, "no tree without a season")
	var cmd: Dictionary = _cmd("kai", 3, TalentTree.row_talents(d, kai, 3)[0].id)
	assert_eq(RunRules.command_refusal(st, d, {}, cmd, false, {}), RunRules.NO_SEASON, "talent v2 needs a season")
	assert_eq(TalentTree.migrate_06b(st, d), 0, "nothing to migrate")
	st.floor_run.location = &"sr_test"
	var offer: PackedStringArray = Talents.current_offer(st, d, "kai")
	assert_eq(Talents.check_pick(st, d, "kai", offer[0]), "", "the 06-B pick")


func test_the_v20_switch_on_in_the_campaign_and_an_event_run() -> void:
	var d: GameData = real_data()
	TalentTree.everywhere = true
	for event_run: bool in [false, true]:
		var st: GameState = GameState.create_new(d, 0, "Kai", 4242, &"prime")
		RunRules.rt_start(st, d)
		var ident: Dictionary = {"run_id": "run_v20", "event_id": "evt_v20" if event_run else "",
			"player_id": "local", "window_id": "", "league": ""}
		var s: RunSim = RunSim.new(d, st, {}, ident)
		s.apply({"t": "floor", "floor": 1})
		s.apply({"t": "hero", "id": "kai"})
		assert_eq(s.is_event_run(), event_run)
		var kai: PartyMember = st.member("kai")
		_set_level(kai, 5, d)
		var what: String = "event run" if event_run else "campaign"
		assert_true(TalentTree.governs(st), what + ": the tree governs")
		assert_eq(Talents.open_choices(st, d), 2, what + ": rows 3 and 5 open")
		var r3: Array[TalentDef] = TalentTree.row_talents(d, kai, 3)
		s.apply(_cmd("kai", 3, r3[0].id))
		assert_eq(s.rejected_cmds.back()["reason"], "not_in_safe_room", what)
		s.apply({"t": "safe_room", "id": _first_safe_room(d, st)})
		var n: int = s.rejected_cmds.size()
		s.apply(_cmd("kai", 3, r3[0].id))
		s.apply(_cmd("kai", 3, r3[2].id))
		assert_eq(s.rejected_cmds.size(), n, what + ": pick and re-pick accepted")
		assert_eq(kai.talent_rows, {"3": r3[2].id})
		s.apply({"t": "talent", "member": "kai", "id": d.talents_for("kai")[0].id})
		assert_eq(s.rejected_cmds.back()["reason"], TalentTree.TREE_RULES, what + ": no 06-B pick any more")
		assert_eq(_stat(kai, d, StatBlock.Stat.DEF), _stat_without_rows(kai, d, StatBlock.Stat.DEF) + 2,
			what + ": " + r3[2].name + " counts")
	TalentTree.everywhere = false


func test_the_migration_on_load_with_the_switch_on() -> void:
	var d: GameData = DB.data
	Game.new_game(1, "Kai", 4242)
	var kai: PartyMember = Game.state.member("kai")
	_set_level(kai, 7, d)
	kai.talents = {"tal_kai_wischtechnik": 2, "tal_kai_kaffee": 1}
	var str_with: int = _stat(kai, d, StatBlock.Stat.STR)
	assert_eq(Save.save_slot(1), OK)
	assert_eq(Save.load_slot(1), OK, Save.last_error())
	assert_eq(Game.state.member("kai").talents.size(), 2, "switch off: the 06-B picks load unchanged")
	TalentTree.everywhere = true
	assert_eq(Save.load_slot(1), OK, Save.last_error())
	var m: PartyMember = Game.state.member("kai")
	assert_true(m.talents.is_empty(), "09 §8.7: old picks are reset")
	assert_eq(_stat(m, d, StatBlock.Stat.STR), str_with - 2, "their effects are gone")
	assert_eq(Array(TalentTree.open_rows(Game.state, d, m)), [3, 5, 7], "every reached row is open")
	assert_true(m.hp <= _stat(m, d, StatBlock.Stat.HP) and m.mp <= _stat(m, d, StatBlock.Stat.MP), "vitals follow")
	TalentTree.everywhere = false


# --- both verifiers ---------------------------------------------------------------------------------------------------

func test_picks_in_both_verifiers() -> void:
	var d: GameData = Kit.data(6)
	var s: RunSim = Kit.sim(d, "ssn_basis", "calendar", "net", 77)
	Kit.clock_to(s, DAY0 + 2 * DAY)                        # floor 1 collapses: rescue and Regie-Crashkurs
	var kai: PartyMember = s.state.member("kai")
	var mop: PartyMember = s.state.member("mopsula")
	assert_true(kai.level >= 5 and mop.level >= 5, "the crash course lifted the party to band start − 2")
	s.apply({"t": "safe_room_exit"})
	s.apply({"t": "safe_room", "id": _first_safe_room(d, s.state)})
	var picks: Array = [["kai", 3, 0], ["kai", 5, 1], ["mopsula", 3, 2], ["kai", 3, 2], ["mopsula", 5, 0]]
	for p: Array in picks:
		var m: PartyMember = s.state.member(str(p[0]))
		s.apply(_cmd(m.id, int(p[1]), TalentTree.row_talents(d, m, int(p[1]))[int(p[2])].id))
	assert_eq(s.rejected_cmds, [] as Array[Dictionary], "every command accepted")
	assert_eq(kai.talent_rows.size() + mop.talent_rows.size(), 4)
	var live: String = StateHash.of(s.state)
	var r: Dictionary = RunSim.replay(d, s.run_log)
	assert_eq([r["errors"], r["mismatch_at"], r["final_hash"]], [PackedStringArray(), -1, live], "RunSim.replay")
	DB.data = d
	var gr: RefCounted = GameReplayScript.new(Game)
	var g: Dictionary = gr.call("run", s.run_log, -1)
	assert_eq(g["errors"], PackedStringArray(), "Game.replay_log accepts every entry")
	var shown: GameState = gr.get("_final_state")
	assert_not_null(shown)
	if shown != null:
		for mid: String in ["kai", "mopsula"]:
			var a: PartyMember = shown.member(mid)
			var b: PartyMember = s.state.member(mid)
			assert_eq([a.level, a.exp, a.talent_rows, a.hp, a.mp], [b.level, b.exp, b.talent_rows, b.hp, b.mp],
				mid + ": both verifiers agree")
		assert_eq(shown.inventory.to_dict(), s.state.inventory.to_dict(), "the Aufholpaket in both")


func test_game_pick_talent_row_live() -> void:
	DB.data = Kit.data(6)
	assert_true(Game.start_season(0, "ssn_basis", {"now": Kit.START, "tz_sec": 0, "seed": 5}))
	var kai: PartyMember = Game.state.member("kai")
	var id: String = TalentTree.row_talents(DB.data, kai, 3)[0].id
	var n: int = Game.run_log.size()
	assert_false(Game.pick_talent_row("kai", 3, id), "level 1: the row is locked")
	_set_level(kai, 3, DB.data)
	assert_false(Game.pick_talent_row("kai", 3, id), "not in a safe room")
	assert_eq(Game.run_log.size(), n, "a refused pick records nothing")
	var got: Array = []
	var cb: Callable = func(mid: String, tid: String) -> void: got.append([mid, tid])
	Events.talent_picked.connect(cb)
	Game.enter_safe_room(_first_safe_room(DB.data, Game.state))
	assert_true(Game.pick_talent_row("kai", 3, id), "in the safe room")
	Events.talent_picked.disconnect(cb)
	assert_eq(got, [["kai", id]], "Events.talent_picked")
	assert_eq(kai.talent_rows, {"3": id})
	assert_eq(Game.run_log.cmds().back()["c"], _cmd("kai", 3, id), "recorded as talent v2")


# --- the screens: the Talent-Show of rows, the talent tree, the party page ---------------------------------------

## A live season on the placeholder data, standing in a safe room of floor 1: Kai at `level` (of class `cls`), the
## Count at `mop_level`.
func _live_season(level: int, mop_level: int, cls: String = "") -> void:
	DB.data = Kit.data(6)
	assert_true(Game.start_season(0, "ssn_basis", {"now": Kit.START, "tz_sec": 0, "seed": 9}))
	Game.enter_safe_room(_first_safe_room(DB.data, Game.state))
	var kai: PartyMember = Game.state.member("kai")
	kai.class_id = cls
	_set_level(kai, level, DB.data)
	_set_level(Game.state.member("mopsula"), mop_level, DB.data)


func test_the_talent_show_presents_rows() -> void:
	_live_season(5, 3)
	var ts: Node = (load("res://scenes/ui/talent_show.tscn") as PackedScene).instantiate()
	ts.call("setup", {})
	add_to_tree(ts)
	await wait_frames(3)
	assert_true(bool(ts.call("tree_mode")), "a season: rows")
	assert_eq([ts.get("member_id"), ts.get("row")], ["kai", 3], "the oldest open row first")
	assert_eq((ts.get("card_buttons") as Array).size(), 3, "three cards")
	assert_eq(ts.call("progress_text"), "Reihe 1 von 3", "Kai's rows 3 and 5, the Count's row 3")
	var ids: PackedStringArray = ts.get("offer")
	assert_eq(Array(ids), TalentTree.row_talents(DB.data, Game.state.member("kai"), 3).map(
		func(t: TalentDef) -> String: return t.id), "the row's talents, left to right")
	assert_true(bool(await ts.call("pick", 1)))
	assert_eq(Game.state.member("kai").talent_rows, {"3": ids[1]})
	assert_eq(Game.run_log.cmds().back()["c"], _cmd("kai", 3, ids[1]), "recorded as talent v2")
	assert_eq([ts.get("member_id"), ts.get("row")], ["kai", 5], "then the next row")
	ts.call("close")
	await wait_frames(1)


func test_the_talent_tree_screen() -> void:
	_live_season(16, 3, "cls_kai_wrecker")
	var t: Node = (load("res://scenes/ui/talent_tree.tscn") as PackedScene).instantiate()
	t.call("setup", {"member": "kai"})
	add_to_tree(t)
	await wait_frames(3)
	assert_eq((t.get("cards") as Dictionary).size(), 36, "twelve rows of three with a class")
	var kai: PartyMember = Game.state.member("kai")
	var r15: Array[TalentDef] = TalentTree.row_talents(DB.data, kai, 15)
	assert_false(bool(t.call("choose", 20, TalentTree.row_talents(DB.data, kai, 20)[0].id)), "row 20 is ahead")
	assert_true(bool(t.call("choose", 15, r15[2].id)), "a pick in the safe room")
	assert_true(bool(t.call("choose", 15, r15[0].id)), "a free re-pick")
	assert_eq(kai.talent_rows, {"15": r15[0].id})
	assert_false(bool(t.call("choose", 15, r15[0].id)), "the same again: nothing")
	Game.leave_safe_room()
	assert_false(bool(t.call("choose", 15, r15[1].id)), "outside a safe room: only to look at")
	assert_eq(kai.talent_rows, {"15": r15[0].id})
	t.call("select_member", "mopsula")
	await wait_frames(2)
	assert_eq((t.get("cards") as Dictionary).size(), 24, "the Count before the Recall: base and figure rows")
	t.call("close")
	await wait_frames(1)


func test_the_party_page_in_a_season() -> void:
	_live_season(5, 3)
	var kai: PartyMember = Game.state.member("kai")
	kai.rested = 40
	var page: Control = (load("res://scenes/ui/party_menu.gd") as GDScript).new() as Control
	add_to_tree(page)
	await wait_frames(2)
	var card: Node = page.find_child("Card_kai", true, false)
	assert_eq((card.find_child("TalentNames", true, false) as Label).text, "2 Reihen offen – im Safe Room wählen")
	assert_eq((card.find_child("SeasonLine", true, false) as Label).text, "Ausgeruht: 40 EXP")
	assert_not_null(page.get("tree_button"), "the button \"Talentbaum\"")
	var tree_page: Node = page.call("open_tree", "mopsula")
	assert_not_null(tree_page)
	await wait_frames(2)
	assert_eq(tree_page.get("member_id"), "mopsula")
	tree_page.call("close")
	await wait_frames(2)
	_set_level(kai, 7, DB.data)
	assert_true(bool(page.call("season_capped", kai)), "level 7 on floor 1: the cap")
	page.queue_free()
	await wait_frames(1)
	Game.new_game(1, "Kai", 3)
	var plain: Control = (load("res://scenes/ui/party_menu.gd") as GDScript).new() as Control
	add_to_tree(plain)
	await wait_frames(2)
	assert_null(plain.get("tree_button"), "no season: no talent tree")
	assert_null(plain.find_child("SeasonLine", true, false))
	plain.queue_free()
	await wait_frames(1)
