extends TestCase
## 09 §11.6 test_09_zone_generator (ST1-C1): generator v2 (ZoneGenerator, 09 §3.6) on the real floors 2–6 — 200 seeds
## per floor pass FloorLayout.validate() and the check rules of 09 §3.6 Nr. 5 (ZoneGenerator.check), the same seed
## gives the same layout, the check rules catch broken layouts, the build time per floor (layout generation, the
## attempts it took) is measured and printed (ZONEGEN lines). The scene build of the floors: tools/perf.sh.

const FLOORS: Array[int] = [2, 3, 4, 5, 6]
const SEEDS: int = 200
const GEN_BUDGET_MS: float = 250.0           # one layout on a CI machine, every attempt included (mobile: perf.sh)


func _seed(i: int) -> int:
	return SeedUtil.derive(4242, "zone_gen_test", i)


# --- 200 seeds per floor ----------------------------------------------------------------------------------------------

func test_two_hundred_seeds_per_floor_pass_the_check_rules() -> void:
	var d: GameData = real_data()
	for f: int in FLOORS:
		var def: FloorDef = d.floor_def(f)
		assert_not_null(def, "floor %d" % f)
		if def == null:
			continue
		assert_true(def.has_zones() and def.has_band(), "floor %d: quarters and a level band (ST1-C1)" % f)
		var bad: PackedStringArray = []
		var attempts: int = 0
		var worst_attempts: int = 0
		var total_us: int = 0
		var worst_us: int = 0
		var rooms_min: int = 1 << 30
		var rooms_max: int = 0
		for i in SEEDS:
			var seed: int = _seed(i)
			var t0: int = Time.get_ticks_usec()
			var l: FloorLayout = _generate_counted(def, seed)
			var us: int = Time.get_ticks_usec() - t0
			total_us += us
			worst_us = maxi(worst_us, us)
			var n: int = int(l.get_meta("attempts", ZoneGenerator.MAX_ATTEMPTS))
			attempts += n
			worst_attempts = maxi(worst_attempts, n)
			var errs: PackedStringArray = l.validate()
			errs.append_array(ZoneGenerator.check(l, def))
			if not errs.is_empty():
				bad.append("seed %d: %s" % [seed, "; ".join(errs)])
			rooms_min = mini(rooms_min, l.cells.size())
			rooms_max = maxi(rooms_max, l.cells.size())
		assert_eq(bad, PackedStringArray(), "floor %d: every seed passes 09 §3.6" % f)
		print("ZONEGEN floor %d: %d seeds, rooms %d..%d, attempts avg %.2f max %d, gen avg %.1f ms max %.1f ms" % [
			f, SEEDS, rooms_min, rooms_max, float(attempts) / SEEDS, worst_attempts, total_us / 1000.0 / SEEDS,
			worst_us / 1000.0])
		assert_time_budget(worst_us / 1000.0, GEN_BUDGET_MS, "floor %d: the slowest layout" % f)   # CI asserts


## ZoneGenerator.generate step by step (the same attempts, generators and checks) with the attempt count as meta.
func _generate_counted(def: FloorDef, seed: int) -> FloorLayout:
	var last: FloorLayout = null
	for k in ZoneGenerator.MAX_ATTEMPTS:
		var rng: RandomNumberGenerator = SeedUtil.make_rng(SeedUtil.derive(seed, "zone_gen_f%d" % def.index, k))
		var res: Dictionary = ZoneGenerator._attempt(def, seed, rng)
		last = res["layout"]
		if str(res["error"]) == "" and last.validate().is_empty() and ZoneGenerator.check(last, def).is_empty():
			last.set_meta("attempts", k + 1)
			return last
	return last


func test_generate_is_the_counted_attempt_and_deterministic() -> void:
	var d: GameData = real_data()
	for f: int in FLOORS:
		var def: FloorDef = d.floor_def(f)
		for i in 6:
			var seed: int = _seed(1000 + i)
			var a: FloorLayout = ZoneGenerator.generate(def, seed)
			var b: FloorLayout = DungeonGenerator.generate(def, seed)       # the one-line switch (09 §11.4)
			var c: FloorLayout = _generate_counted(def, seed)
			assert_eq(a.to_debug_string(), b.to_debug_string(), "floor %d seed %d: the same layout twice" % [f, seed])
			assert_eq(a.to_debug_string(), c.to_debug_string(), "floor %d seed %d: generate = the counted attempt" % [
				f, seed])
		var x: String = ZoneGenerator.generate(def, _seed(1)).to_debug_string()
		var y: String = ZoneGenerator.generate(def, _seed(2)).to_debug_string()
		assert_ne(x, y, "floor %d: another seed, another layout" % f)


func test_floor_one_keeps_its_handbuilt_layout() -> void:
	var d: GameData = real_data()
	var f1: FloorDef = d.floor_def(1)
	assert_false(f1.has_zones(), "floor 1: no quarters (its layout is handbuilt)")
	var l: FloorLayout = DungeonGenerator.generate(f1, 77)
	assert_eq(l.programme, [] as Array[Dictionary])
	assert_eq(l.nodes, [] as Array[Dictionary])
	for e: EnemySpawn in l.enemies:
		assert_eq(e.level, 0, "floor 1 groups carry no level: " + e.id)
	assert_false(l.to_debug_string().contains("zones "), "floor 1's debug string as before")


# --- the shape of a layout --------------------------------------------------------------------------------------------

func test_quarters_bosses_doors_and_levels() -> void:
	var d: GameData = real_data()
	for f: int in FLOORS:
		var def: FloorDef = d.floor_def(f)
		var l: FloorLayout = ZoneGenerator.generate(def, _seed(7))
		var ctx: String = "floor %d" % f
		assert_eq(l.zones.size(), def.zones.size(), ctx + ": every quarter")
		var last: String = str(def.zones[def.zones.size() - 1]["id"])
		assert_eq(l.cell_at(l.stairs).zone, last, ctx + ": the stairs in the last quarter")
		assert_eq(l.cell_at(l.quarter_boss).zone, last, ctx + ": the Revier-Boss in the last quarter")
		var key_gate: Dictionary = {}
		for g: Dictionary in l.gates:
			if str(g["requires"]) == ZoneGenerator.key_item(def):
				key_gate = g
		assert_false(key_gate.is_empty(), ctx + ": the key gate in front of the stairs")
		assert_true(d.has_id("items", ZoneGenerator.key_item(def)), ctx + ": the key exists")
		var qb_lead: String = def.encounter(def.quarter_boss).enemies[0]
		var drops: Array = []
		for bd: Dictionary in d.enemy(qb_lead).boss_drops:
			drops.append(str(bd["id"]))
		assert_has(drops, ZoneGenerator.key_item(def), ctx + ": the Revier-Boss drops the key")
		var spots: int = 0
		for z: Dictionary in def.zones:
			spots += int(z.get("spots", 0))
		assert_eq(l.programme.size(), spots, ctx + ": a door per programme spot")
		for p: Dictionary in l.programme:
			var g: Dictionary = l.gate_by_key(str(p["key"]))
			assert_eq(str(g.get("requires", "")), ZoneGenerator.programme_requirement(int(p["n"])), ctx)
			assert_false(l.path.has(p["cell"] as Vector2i), ctx + ": a programme room is off the path")
		var safe: int = 0
		for c: Vector2i in l.sorted_cells():
			safe += 1 if l.cell_at(c).kind == RoomCell.Kind.SAFE else 0
		assert_eq(safe, def.zones.size(), ctx + ": a safe room per quarter")
		var lo: int = def.level_band[0]
		var hi: int = def.level_band[1]
		var show: int = 0
		for e: EnemySpawn in l.enemies:
			assert_between(e.level, lo, hi + ZoneGenerator.ELITE_LEVELS, ctx + ": level of " + e.id)
			if l.path.has(e.cell) and not e.is_boss and def.encounter(e.encounter_id).show_boss.is_empty():
				assert_eq(e.level, ZoneGenerator.band_middle(def), ctx + ": the Pflichtweg at the band's middle")
			if not def.encounter(e.encounter_id).show_boss.is_empty():
				show += 1
				assert_eq(e.level, hi + ZoneGenerator.ELITE_LEVELS, ctx + ": the show boss's elite group")
		assert_eq(show, 1, ctx + ": one show boss group")
		var dangers: Array = []
		for z: Dictionary in def.zones:
			dangers.append(str((l.zones[str(z["id"])] as Dictionary)["danger"]))
		assert_eq(dangers[0], "calm", ctx)
		assert_eq(dangers[dangers.size() - 1], "dangerous", ctx)
		var nodes: int = 0
		for z: Dictionary in def.zones:
			nodes += 1
		assert_between(l.nodes.size(), nodes * ZoneGenerator.NODES_DEFAULT.x, nodes * ZoneGenerator.NODES_DEFAULT.y,
			ctx + ": 4–6 gather nodes per quarter")


# --- the check rules catch broken layouts -----------------------------------------------------------------------------

func test_check_rules_catch_broken_layouts() -> void:
	var d: GameData = real_data()
	var def: FloorDef = d.floor_def(4)
	var seed: int = _seed(3)
	# the key gate gone: the stairs are reachable without the key
	var l: FloorLayout = ZoneGenerator.generate(def, seed)
	for i in l.gates.size():
		if str(l.gates[i]["requires"]) == ZoneGenerator.key_item(def):
			l.gates.remove_at(i)
			break
	assert_has("; ".join(ZoneGenerator.check(l, def)), "stairs", "no key gate")
	# a quarter without its safe room
	l = ZoneGenerator.generate(def, seed)
	var sc: Vector2i = l.safe_rooms[0]
	l.safe_rooms.remove_at(0)
	l.cell_at(sc).kind = RoomCell.Kind.NORMAL
	assert_has("; ".join(ZoneGenerator.check(l, def)), "safe rooms", "a safe room missing")
	# a group off its band
	l = ZoneGenerator.generate(def, seed)
	l.enemies[0].level = def.level_band[1] + 5
	assert_has("; ".join(ZoneGenerator.check(l, def)), "level", "a level beyond band end + 2")
	# a programme door without its event
	l = ZoneGenerator.generate(def, seed)
	var cell: Vector2i = l.programme[0]["cell"]
	for i in range(l.events.size() - 1, -1, -1):
		if l.events[i].cell == cell:
			l.events.remove_at(i)
	assert_has("; ".join(ZoneGenerator.check(l, def)), "programme", "a programme room without its event")
	assert_eq(ZoneGenerator.check(ZoneGenerator.generate(def, seed), def), PackedStringArray(), "the intact layout")


# --- programme doors (09 §3.3) ----------------------------------------------------------------------------------------

func test_programme_doors_open_with_the_daily_programme() -> void:
	var d: GameData = real_data()
	var st: GameState = GameState.create_new(d, 0, GameState.DEFAULT_NAME, 31, &"prime")
	RunRules.start_floor(st, d, 2)
	var l: FloorLayout = DungeonGenerator.generate(d.floor_def(2), st.floor_run.seed)
	st.floor_run.daily = PackedStringArray(["daily_passage_a", "daily_passage_b"])
	ZoneGenerator.open_programme_doors(st, d)
	assert_eq(st.floor_run.opened_gates, PackedStringArray(), "no season: no programme door opens")
	st.season = SeasonState.new()
	ZoneGenerator.open_programme_doors(st, d)
	var want: PackedStringArray = []
	for p: Dictionary in l.programme:
		if int(p["n"]) <= 2:
			want.append(str(p["key"]))
	assert_eq(st.floor_run.opened_gates, want, "points 1 and 2 open doors 1 and 2")
	ZoneGenerator.open_programme_doors(st, d)
	assert_eq(st.floor_run.opened_gates, want, "idempotent")
	assert_eq([ZoneGenerator.programme_number("daily:3"), ZoneGenerator.programme_number("itm_key_f2"),
		ZoneGenerator.programme_number("daily:x")], [3, 0, 0])
