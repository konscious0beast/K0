extends TestCase
## 07 §2.7 (R1b-I3) test_r1_regen: the regeneration out of combat in RunSim (step 7 of _tick_once, after the 06-D
## twists) — real-time runs only (CTB runs never count, bit-identical), exploration ticks with a running clock only
## (no safe room, no stopped clock); floor_run.regen_ticks counts every tick, every REGEN_PERIOD_TICKS (90) each member
## with HP > 0 gets max(1, div_round(max_mp × 20, 1000)) MP and — from regen_ticks ≥ REGEN_HP_DELAY_TICKS (150) —
## max(1, div_round(max_hp × 5, 1000)) HP, capped; the counter restarts after every combat (BattleBridge.apply_result)
## and after out-of-combat damage (a floor event's party_damage_pct); it is saved and hashed when ≠ 0.

const FixedMath := preload("res://core/stats/fixed_math.gd")


## A run on fixture floor 1 with a running clock (real-time unless `mode`), Kai at 1 HP / 0 MP, Mopsula at 0 MP.
func _run(mode: StringName = &"realtime") -> RunSim:
	var st: GameState = RtKit.state(6)
	st.combat_mode = mode
	st.floor_run.timer_started = true
	st.floor_run.time_left_ticks = 30 * 600
	for m: PartyMember in st.party:
		m.mp = 0
	st.party[0].hp = 1
	return RunSim.new(RtKit.data(), st, {})


static func _max(rs: RunSim, i: int) -> StatBlock:
	return Progression.total_stats(rs.state.party[i], rs.data)


static func _hpmp(rs: RunSim) -> Array:
	var out: Array = []
	for m: PartyMember in rs.state.party:
		out.append([m.hp, m.mp])
	return out


func test_mp_every_period_hp_after_the_delay() -> void:
	var rs: RunSim = _run()
	var kai: StatBlock = _max(rs, 0)
	var mop: StatBlock = _max(rs, 1)
	var mp_k: int = maxi(1, FixedMath.div_round(kai.values[StatBlock.Stat.MP] * 20, 1000))
	var mp_m: int = maxi(1, FixedMath.div_round(mop.values[StatBlock.Stat.MP] * 20, 1000))
	var hp_k: int = maxi(1, FixedMath.div_round(kai.values[StatBlock.Stat.HP] * 5, 1000))
	var mop_hp: int = rs.state.party[1].hp
	rs.step(89)
	assert_eq(_hpmp(rs), [[1, 0], [mop_hp, 0]], "nothing before the first period")
	assert_eq(rs.state.floor_run.regen_ticks, 89)
	rs.step(1)
	assert_eq(_hpmp(rs), [[1, mp_k], [mop_hp, mp_m]], "tick 90: MP only (regen_ticks 90 < 150)")
	rs.step(90)
	assert_eq(_hpmp(rs), [[1 + hp_k, 2 * mp_k], [mop_hp, 2 * mp_m]], "tick 180: MP and HP (Mopsula is full)")
	assert_eq(rs.state.floor_run.regen_ticks, 180)
	var other: RunSim = _run()
	for _i in 180:
		other.step(1)
	assert_eq(_hpmp(other), _hpmp(rs), "step(1) × n ≡ step(n)")


func test_caps_and_ko() -> void:
	var rs: RunSim = _run()
	var kai: StatBlock = _max(rs, 0)
	var mop: PartyMember = rs.state.party[1]
	rs.state.party[0].hp = kai.values[StatBlock.Stat.HP] - 1
	rs.state.party[0].mp = kai.values[StatBlock.Stat.MP] - 1
	mop.hp = 0
	rs.step(180)
	assert_eq(_hpmp(rs)[0], [kai.values[StatBlock.Stat.HP], kai.values[StatBlock.Stat.MP]], "capped at the maximum")
	assert_eq(_hpmp(rs)[1], [0, 0], "a KO'd member does not regenerate")


func test_ctb_and_stopped_clock_and_safe_room() -> void:
	var ctb: RunSim = _run(&"ctb")
	var before: String = StateHash.of(ctb.state)
	var hpmp: Array = _hpmp(ctb)
	ctb.step(400)
	assert_eq([_hpmp(ctb), ctb.state.floor_run.regen_ticks], [hpmp, 0], "CTB runs never count")
	assert_false(ctb.state.floor_run.to_dict().has("regen_ticks"), "nothing new in a CTB save")
	assert_true(StateHash.of(ctb.state) != before, "(the clock itself moved)")
	var idle: RunSim = _run()
	idle.state.floor_run.timer_started = false
	idle.step(200)
	assert_eq([_hpmp(idle), idle.state.floor_run.regen_ticks], [_hpmp(_run()), 0], "a stopped clock")
	var safe: RunSim = _run()
	safe.state.floor_run.location = &"sr_kiosk"
	safe.step(200)
	assert_eq([_hpmp(safe), safe.state.floor_run.regen_ticks], [_hpmp(_run()), 0],
		"a safe room tick (full heal there anyway)")


func test_resets() -> void:
	var rs: RunSim = _run()
	rs.step(120)
	assert_eq(rs.state.floor_run.regen_ticks, 120)
	var r: BattleResult = BattleResult.new()
	r.outcome = BattleResult.Outcome.FLED
	for m: PartyMember in rs.state.party:
		r.party_hp[m.id] = m.hp
		r.party_mp[m.id] = m.mp
	BattleBridge.apply_result(rs.state, rs.data, r)
	assert_eq(rs.state.floor_run.regen_ticks, 0, "after every combat")
	rs.step(100)
	var hp_k: int = rs.state.party[0].hp
	assert_eq(hp_k, 1, "the HP delay counts again from the combat end (100 < 150)")
	var fr: FloorRun = rs.state.floor_run
	RunRules._rt_regen_after_damage(fr, {"valid": true, "party_damage_pct": {"kai": 0}})
	assert_eq(fr.regen_ticks, 100, "no damage: no reset")
	RunRules._rt_regen_after_damage(fr, {"valid": false, "party_damage_pct": {"kai": 10}})
	assert_eq(fr.regen_ticks, 100, "an invalid outcome changes nothing")
	RunRules._rt_regen_after_damage(fr, {"valid": true, "party_damage_pct": {"mopsula": 0, "kai": 10}})
	assert_eq(fr.regen_ticks, 0, "out-of-combat damage")


func test_saved_and_hashed() -> void:
	var rs: RunSim = _run()
	var h0: String = StateHash.of(rs.state)
	rs.state.floor_run.regen_ticks = 0
	assert_false(rs.state.floor_run.to_dict().has("regen_ticks"), "0: not serialized")
	rs.state.floor_run.regen_ticks = 45
	assert_eq(int(rs.state.floor_run.to_dict()["regen_ticks"]), 45)
	assert_true(StateHash.of(rs.state) != h0, "hashed when ≠ 0")
	var back: FloorRun = FloorRun.from_dict(rs.state.floor_run.to_dict())
	assert_eq(back.regen_ticks, 45, "round trip")
	rs.step(45)
	var a: Array = _hpmp(rs)
	assert_eq(a[0][1], maxi(1, FixedMath.div_round(_max(rs, 0).values[StatBlock.Stat.MP] * 20, 1000)),
		"a loaded counter continues: 45 + 45 = 90")
