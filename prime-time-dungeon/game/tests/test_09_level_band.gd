extends TestCase
## 09 §11.6 test_09_level_band (ST1-D): levels in a season (09 §8.2) — the EXP table up to level 50 (party.json
## exp_table, the GDD curve continued), the level band of every floor (09 §2.4) with its cap ("Deckel") and the
## Überstunden (EXP over the cap become 10 % credits), the Aufholjagd (× 2 below the band, × 3 a whole band below) and
## Ausgeruht (the higher factor counts; the pool only without a catch-up), the Regie-Crashkurs with its Aufholpaket, the
## colours and the level difference of an enemy, the combat EXP by colour (a KO'd member half), the EXP of the stairs
## (half a level, counted for the floor below) and of a floor event (5 %, once), and the MP / HP formulas of 07 §4.2 /
## §4.3 up to level 50 (CR-32 d: a test without a code change). Without a season every rule stays the campaign's.

const Kit := preload("res://tests/fixtures/season_core/season_core.gd")
const DAY: int = Kit.DAY
const DAY0: int = Kit.DAY0


## A season run (Kit, six floors) on floor `floor` with every member at `level`.
static func _season(floor: int = 1, level: int = 1) -> RunSim:
	var d: GameData = Kit.data(6)
	var s: RunSim = Kit.sim(d)
	if floor != 1:
		Kit.put_on_floor(s, floor)
	for m: PartyMember in s.state.party:
		_set_level(m, level, d)
	return s


## `m` at `level` with no EXP, nothing rested and full HP / MP.
static func _set_level(m: PartyMember, level: int, d: GameData) -> void:
	m.level = level
	m.exp = 0
	m.rested = 0
	var sb: StatBlock = Progression.total_stats(m, d)
	m.hp = sb.values[StatBlock.Stat.HP]
	m.mp = sb.values[StatBlock.Stat.MP]


static func _campaign(d: GameData) -> GameState:
	var st: GameState = GameState.create_new(d, 0, "Kai", 4242, &"prime")
	RunRules.start_floor(st, d, 1)
	return st


# --- the table ------------------------------------------------------------------------------------------------------

func test_the_exp_table_up_to_level_50() -> void:
	var d: GameData = real_data()
	var t: PackedInt32Array = d.exp_table()
	assert_eq(t.size(), 49, "levels 1–49 need EXP for the next one; 50 is the season's end")
	var total: int = 0
	for lv in range(1, 50):
		assert_eq(t[lv - 1], floori(18.0 * pow(float(lv), 1.7) + 15.0), "level %d: floor(18 × L^1.7 + 15)" % lv)
		if lv > 1:
			assert_gt(t[lv - 1], t[lv - 2], "rising")
		if lv <= Progression.EXP_TABLE.size():
			assert_eq(t[lv - 1], Progression.EXP_TABLE[lv - 1], "levels 1–9: the campaign's curve")
		total += t[lv - 1]
	var s: RunSim = Kit.sim(d)
	for lv in range(1, 50):
		assert_eq(LevelBand.exp_to_next(s.state, d, lv), t[lv - 1], "a season reads the table")
	assert_eq(LevelBand.exp_to_next(s.state, d, 50), 0, "level 50: nothing more")
	var camp: GameState = _campaign(d)
	for lv in range(1, 13):
		assert_eq(LevelBand.exp_to_next(camp, d, lv), Progression.exp_to_next(lv), "no season: the campaign curve")
	assert_eq(LevelBand.cap(camp, d), Balance.LEVEL_CAP, "no season: the cap of the campaign")
	print("[09_level_band] EXP from level 1 to 50: %d" % total)


# --- the band and the cap -------------------------------------------------------------------------------------------

func test_the_band_of_every_floor() -> void:
	assert_eq([LevelBand.default_band(1), LevelBand.default_band(2), LevelBand.default_band(3)],
		[Vector2i(1, 7), Vector2i(7, 10), Vector2i(10, 13)], "09 §2.4: floor 1 1–7, then three levels per floor")
	assert_eq([LevelBand.default_band(15), LevelBand.default_band(16), LevelBand.default_band(17),
		LevelBand.default_band(18)], [Vector2i(46, 49), Vector2i(49, 50), Vector2i(50, 50), Vector2i(50, 50)])
	for f in range(2, 19):
		assert_eq(LevelBand.default_band(f).x, LevelBand.default_band(f - 1).y, "floor %d starts where %d ends" % [f,
			f - 1])
	var d: GameData = real_data()
	for f in range(1, 19):
		var def: FloorDef = d.floor_def(f)
		var want: Vector2i = LevelBand.default_band(f)
		if def != null and def.has_band():
			want = Vector2i(def.level_band[0], def.level_band[1])
		assert_eq(LevelBand.band(d, f), want, "floor %d: floors.json level_band, else the table of 09 §2.4" % f)
	var s: RunSim = _season(1, 1)
	assert_eq(LevelBand.cap(s.state, s.data), LevelBand.band(s.data, 1).y, "the cap: the band end of the floor")
	Kit.put_on_floor(s, 3)
	assert_eq(LevelBand.cap(s.state, s.data), LevelBand.band(s.data, 3).y)
	assert_eq(LevelBand.cap(s.state, s.data, 2), LevelBand.band(s.data, 2).y, "of a given floor")


func test_the_cap_and_the_overtime() -> void:
	var s: RunSim = _season(1, 1)
	var d: GameData = s.data
	var kai: PartyMember = s.state.member("kai")
	var top: int = LevelBand.cap(s.state, d)
	_set_level(kai, top - 1, d)
	var credits: int = s.state.inventory.credits
	var need: int = LevelBand.exp_to_next(s.state, d, top - 1)
	var r: Dictionary = LevelBand.add_exp(s.state, d, kai, need + 250, "combat")
	assert_eq([kai.level, kai.exp, r["gained"], r["overtime"]], [top, 0, need, 25],
		"up to the cap; 250 EXP over it are Überstunden: 25 credits")
	assert_eq(s.state.inventory.credits, credits + 25)
	var info: LevelUpInfo = r["info"]
	assert_eq([info.old_level, info.new_level], [top - 1, top], "a level-up")
	r = LevelBand.add_exp(s.state, d, kai, 1000, "combat")
	assert_eq([kai.level, kai.exp, r["gained"], r["overtime"], r["info"]], [top, 0, 0, 100, null],
		"at the cap every EXP is overtime")
	assert_eq(s.state.inventory.credits, credits + 125)
	Kit.put_on_floor(s, 2)
	r = LevelBand.add_exp(s.state, d, kai, LevelBand.exp_to_next(s.state, d, top), "combat")
	assert_eq([kai.level, r["overtime"]], [top + 1, 0], "one floor deeper the cap rises")
	var camp: GameState = _campaign(d)
	var m: PartyMember = camp.member("kai")
	r = LevelBand.add_exp(camp, d, m, 500, "combat")
	assert_eq([m.level, m.exp, r["gained"], camp.inventory.credits], [1, 0, 0, _campaign(d).inventory.credits],
		"no season: LevelBand does nothing (Progression.add_exp rules)")


# --- the catch-up and Ausgeruht -------------------------------------------------------------------------------------

func test_the_catch_up_doubles_and_triples() -> void:
	var s: RunSim = _season(3, 1)
	var d: GameData = s.data
	var lo: int = LevelBand.band(d, 3).x
	var kai: PartyMember = s.state.member("kai")
	for lv: int in [lo + 1, lo, lo - 1, lo - 2, lo - 3, lo - 4]:
		_set_level(kai, lv, d)
		var want: int = 1000 if lv >= lo else (2000 if lv > lo - LevelBand.DEEP_GAP else 3000)
		assert_eq(LevelBand.catch_up_pm(s.state, d, kai), want, "level %d on a band from %d" % [lv, lo])
	_set_level(kai, lo - 1, d)
	var r: Dictionary = LevelBand.add_exp(s.state, d, kai, 10, "combat")
	assert_eq([r["gained"], r["factor_pm"], kai.exp], [20, 2000, 20], "× 2 below the band")
	_set_level(kai, lo - 3, d)
	for kind: String in ["combat", "stairs", "event", "prof"]:
		r = LevelBand.add_exp(s.state, d, kai, 10, kind)
		assert_eq([r["gained"], r["factor_pm"]], [30, 3000], kind + ": × 3 a whole band below — every EXP source")
	assert_eq(LevelBand.catch_up_pm(s.state, d, kai, 1), 1000, "measured against the floor asked for")
	assert_eq(LevelBand.catch_up_pm(_campaign(d), d, _campaign(d).member("kai")), 1000, "no season: none")


func test_rested_and_the_higher_factor() -> void:
	var s: RunSim = _season(1, 3)
	var d: GameData = s.data
	var kai: PartyMember = s.state.member("kai")
	kai.rested = 25
	var r: Dictionary = LevelBand.add_exp(s.state, d, kai, 10, "combat")
	assert_eq([r["gained"], r["rested"], r["factor_pm"], kai.rested], [20, 10, 2000, 15],
		"Ausgeruht doubles combat EXP out of the pool")
	r = LevelBand.add_exp(s.state, d, kai, 40, "combat")
	assert_eq([r["gained"], r["rested"], kai.rested], [55, 15, 0], "until the pool is empty")
	kai.rested = 50
	r = LevelBand.add_exp(s.state, d, kai, 10, "stairs")
	assert_eq([r["gained"], r["rested"], kai.rested], [10, 0, 50], "only combat EXP use the pool")
	Kit.put_on_floor(s, 3)
	_set_level(kai, LevelBand.band(d, 3).x - 1, d)
	kai.rested = 50
	r = LevelBand.add_exp(s.state, d, kai, 10, "combat")
	assert_eq([r["gained"], r["rested"], r["factor_pm"], kai.rested], [20, 0, 2000, 50],
		"with a catch-up the higher factor counts — the pool stays for later")


# --- the Regie-Crashkurs ----------------------------------------------------------------------------------------------

func test_the_crash_course_and_its_package() -> void:
	var s: RunSim = _season(4, 1)
	var d: GameData = s.data
	var target: int = LevelBand.band(d, 4).x - LevelBand.CRASH_GAP
	var kai: PartyMember = s.state.member("kai")
	var mop: PartyMember = s.state.member("mopsula")
	_set_level(mop, target, d)
	var potion: String = LevelBand.catch_up_potion(d)
	assert_ne(potion, "", "a common healing potion")
	var potions: int = s.state.inventory.count(potion)
	var pieces: PackedStringArray = LevelBand.catch_up_items(s.state, d, kai)
	assert_gt(pieces.size(), 0, "at least the empty accessory slot gets a piece")
	var ev: Array[ExploreEvent] = LevelBand.crash_course(s.state, d)
	var c: Dictionary = Kit.event(ev, "crash")
	assert_eq(c.get("members", {}), {"kai": [1, target]}, "who is below band start − 2 is lifted exactly there")
	assert_eq([kai.level, kai.exp, mop.level], [target, 0, target])
	assert_eq(kai.hp, Progression.total_stats(kai, d).values[StatBlock.Stat.HP], "HP follow like a level-up")
	assert_eq(c.get("items", []), Array(pieces) + [potion, potion, potion], "the Aufholpaket: pieces, three potions")
	for id: String in pieces:
		assert_true(s.state.inventory.has(id), id + " in the inventory")
	assert_eq(s.state.inventory.count(potion), mini(potions + 3, d.item(potion).max_stack))
	assert_eq(LevelBand.crash_course(s.state, d), [] as Array[ExploreEvent], "nobody is behind any more")
	var camp: GameState = _campaign(d)
	assert_eq(LevelBand.crash_course(camp, d), [] as Array[ExploreEvent], "no season: no crash course")


func test_a_rescue_gives_the_crash_course() -> void:
	var d: GameData = Kit.data(6)
	var s: RunSim = Kit.sim(d)
	var target: int = LevelBand.band(d, 2).x - LevelBand.CRASH_GAP
	var ev: Array = Kit.clock_to(s, DAY0 + 2 * DAY)              # floor 1 collapses: rescued to floor 2
	var kinds: Array = Kit.kinds(ev)
	assert_has(kinds, "rescue")
	if target <= 1:
		assert_false(kinds.has("crash"), "floor 2 starts low enough: no crash course")
		return
	assert_eq(kinds.find("crash"), kinds.find("rescue") + 1, "right after the rescue (09 §8.2)")
	for m: PartyMember in s.state.party:
		assert_eq(m.level, target, m.id + " at band start − 2 of floor 2")


# --- colours and the combat EXP -----------------------------------------------------------------------------------

func test_colours_and_the_level_difference() -> void:
	var want: Dictionary = {-10: "grey", -6: "grey", -5: "green", -3: "green", -2: "yellow", 0: "yellow",
		2: "yellow", 3: "orange", 4: "orange", 5: "red", 12: "red"}
	for diff: int in want.keys():
		assert_eq(LevelBand.color_name(diff), want[diff], "%+d" % diff)
	assert_eq([LevelBand.color_exp_pm(-6), LevelBand.color_exp_pm(-4), LevelBand.color_exp_pm(0),
		LevelBand.color_exp_pm(3), LevelBand.color_exp_pm(5)], [0, 500, 1000, 1200, 1400], "the EXP by colour")
	assert_eq([LevelBand.diff_text(0), LevelBand.diff_text(3), LevelBand.diff_text(-4)], ["±0", "+3", "−4"],
		"the number carries the information (09 V-6)")
	assert_true(LevelBand.is_warning(5), "red warns")
	assert_false(LevelBand.is_warning(4))


func test_combat_exp_by_colour() -> void:
	var s: RunSim = _season(1, 1)
	var d: GameData = s.data
	var kai: PartyMember = s.state.member("kai")
	var mop: PartyMember = s.state.member("mopsula")
	var top: int = LevelBand.cap(s.state, d)
	var weak: String = _enemy_of_level(d, 1, 1)
	var strong: String = _enemy_of_level(d, 6, top + 1)          # Kai at its level − 2 stays below the cap
	assert_ne(weak, "", "an enemy of level 1")
	assert_ne(strong, "", "an enemy of level 6–%d" % (top + 1))
	var res: BattleResult = Kit.result(BattleResult.Outcome.VICTORY)
	res.defeated_ids = PackedStringArray([weak, strong])
	var g: int = d.enemy(strong).level
	assert_eq(LevelBand.group_level(d, res), g, "a group's level: its highest enemy")
	# [group, Kai's level, Mopsula's level, Kai's factor, Mopsula's factor] — every level within the band of floor 1
	var cases: Array = [[g, g - 2, g - 4, 1000, 1200], [g, g - 3, g - 5, 1200, 1400], [1, 4, 7, 500, 0],
		[1, 1, 3, 1000, 1000]]
	for c: Array in cases:
		res.defeated_ids = PackedStringArray([strong] if int(c[0]) == g else [weak])
		_set_level(kai, int(c[1]), d)
		_set_level(mop, int(c[2]), d)
		var rw: BattleRewards = BattleRewards.new()
		LevelBand.combat_exp(s.state, d, res, 20, {}, rw)
		assert_eq(rw.exp_by_member, {"kai": 20 * int(c[3]) / 1000, "mopsula": 20 * int(c[4]) / 1000},
			"levels %d / %d against a group of level %d" % [kai.level, mop.level, int(c[0])])
	res.defeated_ids = PackedStringArray([weak])
	_set_level(kai, 1, d)
	_set_level(mop, 1, d)
	var rw2: BattleRewards = BattleRewards.new()
	LevelBand.combat_exp(s.state, d, res, 20, {"kai": true}, rw2)
	assert_eq(rw2.exp_by_member, {"kai": 20 * BattleBridge.KO_EXP_PCT / 100, "mopsula": 20}, "a KO'd member: half")


## The first enemy (id order) with a level in lo..hi; "" if none.
static func _enemy_of_level(d: GameData, lo: int, hi: int) -> String:
	var ids: Array = []
	for e: EnemyDef in d.all_enemies():
		if e.level >= lo and e.level <= hi:
			ids.append(e.id)
	ids.sort()
	return str(ids[0]) if not ids.is_empty() else ""


# --- the stairs and a floor event -------------------------------------------------------------------------------------

func test_the_stairs_give_half_a_level_for_the_floor_below() -> void:
	var d: GameData = Kit.data(6)
	var s: RunSim = Kit.sim(d)
	var kai: PartyMember = s.state.member("kai")
	var factor: int = LevelBand.catch_up_pm(s.state, d, kai, 2)
	var amount: int = LevelBand.exp_to_next(s.state, d, 1) * LevelBand.SHARE_STAIRS_PM / 1000 * factor / 1000
	var ev: Array = s.apply({"t": "descend"})
	var e: Dictionary = Kit.event(ev, "exp")
	assert_eq(e.get("source", ""), "stairs", "the stairs' EXP (Abschluss-EP)")
	var km: Dictionary = (e.get("members", {}) as Dictionary).get("kai", {})
	assert_eq([km.get("gained", -1), km.get("from", -1)], [amount, 1],
		"half of level 1's EXP × the catch-up of floor 2 (its band, not floor 1's)")
	var left: int = amount
	var lv: int = 1
	while left >= LevelBand.exp_to_next(s.state, d, lv):
		left -= LevelBand.exp_to_next(s.state, d, lv)
		lv += 1
	assert_eq([kai.level, kai.exp, km.get("level", -1)], [lv, left, lv])


func test_a_floor_event_gives_five_percent_once() -> void:
	var d: GameData = Kit.data(6)
	var s: RunSim = Kit.sim(d)
	for m: PartyMember in s.state.party:
		_set_level(m, 5, d)
	var layout: FloorLayout = DungeonGenerator.generate(d.floor_def(1), s.state.floor_run.seed)
	var done: String = ""
	for ev: EventSpawn in layout.events:
		for choice: String in FloorEvent.choices(ev, s.state, d):
			var before: int = s.state.member("kai").exp
			var out: Dictionary = RunRules.apply_floor_event(s.state, d, layout, ev.id, choice)
			if not s.state.floor_run.completed_events.has(ev.id):
				assert_false(out.has("season"), "no EXP before the event is completed")
				continue
			var e: Dictionary = Kit.event(out.get("season", []), "exp")
			assert_eq(e.get("source", ""), "event")
			assert_eq(s.state.member("kai").exp - before, LevelBand.exp_to_next(s.state, d, 5) * 50 / 1000,
				"5 % of a level")
			out = RunRules.apply_floor_event(s.state, d, layout, ev.id, choice)
			assert_false(out.has("season"), "only the first completion counts")
			done = ev.id
			break
		if done != "":
			break
	assert_ne(done, "", "floor 1 has an event a choice completes")


# --- 07 §4.2 / §4.3 up to level 50 (CR-32 d) ------------------------------------------------------------------------

func test_mp_and_hp_up_to_level_50() -> void:
	var d: GameData = real_data()
	# 07 §4.2 Kai: MP 12 (+2 per level), HP 256 (+36); 07 §4.3 Mopsula: MP 30 (+4), HP 168 (+24).
	for row: Array in [["kai", 12, 2, 256, 36], ["mopsula", 30, 4, 168, 24]]:
		var m: PartyMember = PartyMember.new()
		m.id = str(row[0])
		for lv in range(1, LevelBand.SEASON_CAP + 1):
			m.level = lv
			var sb: StatBlock = Progression.total_stats(m, d)
			assert_eq([sb.values[StatBlock.Stat.MP], sb.values[StatBlock.Stat.HP]],
				[int(row[1]) + int(row[2]) * (lv - 1), int(row[3]) + int(row[4]) * (lv - 1)],
				"%s level %d: the formulas of 07 hold without a cap" % [m.id, lv])
		var lo: Vector2i = Vector2i(1 << 30, 1 << 30)
		var hi: Vector2i = Vector2i.ZERO
		for c: ClassDef in d.all_classes():
			if not c.is_for(m.id):
				continue
			for sp: SpeciesDef in d.all_species():
				if not sp.is_for(m.id):
					continue
				m.class_id = c.id
				m.species_id = sp.id
				var prev: Vector2i = Vector2i.ZERO
				for lv in range(1, LevelBand.SEASON_CAP + 1):
					m.level = lv
					var sb: StatBlock = Progression.total_stats(m, d)
					var v: Vector2i = Vector2i(sb.values[StatBlock.Stat.HP], sb.values[StatBlock.Stat.MP])
					assert_true(v.x > prev.x and v.y >= prev.y, "%s %s %s level %d: the maxima rise" % [m.id, c.id,
						sp.id, lv])
					prev = v
				lo = Vector2i(mini(lo.x, prev.x), mini(lo.y, prev.y))
				hi = Vector2i(maxi(hi.x, prev.x), maxi(hi.y, prev.y))
		m.class_id = ""
		m.species_id = ""
		print("[09_level_band] %s level 50: bare HP %d MP %d; with class and species HP %d–%d MP %d–%d" % [m.id,
			int(row[3]) + int(row[4]) * 49, int(row[1]) + int(row[2]) * 49, lo.x, hi.x, lo.y, hi.y])
