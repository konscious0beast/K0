extends TestCase
## 07 §3.4, §10.1, §10.5, §3.16 (R1b-I1) test_r1_rt_setup: BattleBridge.make_rt_setup builds the start data from the
## recorded encounter command — encounter flags, advantage (bosses NORMAL), difficulty factors, party units from
## party.json rt (ids by battle slot, drivers, poses, timers, MP regeneration, presets, bar by level and loadout),
## enemy units from enemies.json rt (HP scale, timers, first swing, entry from outside the ring, komparsen in
## formation with pop-in, the MAX_ENEMIES cap over groups, the anchor of a group-less combat), the opening action,
## switches, the pep talk guard; invalid commands give null. RtBalance.from_data / from_values; the rt block
## validation of RtCommand (incl. the opening action).

const T := ActionEvent.Type


func _unit(s: RtSetup, id: String) -> RtUnit:
	for u: RtUnit in s.units:
		if u.id == id:
			return u
	return null


func test_balance_from_data() -> void:
	var bal: RtBalance = RtBalance.from_data(RtKit.data())
	assert_eq(bal.values, RtBalance.DEFAULTS, "rt_min ships the start values")
	assert_eq(RtBalance.validate(JsonUtil.read_file("res://tests/fixtures/rt_min/rt_balance.json")), PackedStringArray())
	var tuned: RtBalance = RtBalance.from_values({"GCD_TICKS": 40.0, "QUEUE_TICKS": 7.5, "IMPACT_TICKS": {"attack": 6},
		"SET_R_CM": 500, "NOT_A_KEY": 3})
	assert_eq([tuned.i("GCD_TICKS"), tuned.i("QUEUE_TICKS"), tuned.values["IMPACT_TICKS"], tuned.values["SET_R_CM"]],
		[40, 9, {"attack": 6, "cast": 0, "stunt": 24, "item": 9}, {"regular": 480, "boss": 600}],
		"integral floats count, the rest falls back to the defaults")
	assert_false(tuned.values.has("NOT_A_KEY"))
	var s: RtSetup = RtKit.setup(RtKit.state(3), RtKit.dummy_cmd())
	assert_eq(s.balance.values, bal.values, "make_rt_setup pins the balance of the data")
	s.balance = null
	var sim: RtSim = RtSim.new(s, RtKit.data())
	assert_eq(sim.bal.values, RtBalance.DEFAULTS, "without one the sim reads it from the data")


func test_setup_fields() -> void:
	var st: GameState = RtKit.state(6, "kai", {"itm_molotov": 2})
	var cmd: Dictionary = RtKit.dummy_cmd({"adv": BattleSetup.Advantage.PREEMPTIVE, "opener": "bark",
		"open": {"kind": "strike", "target": "e0"}, "auto": false, "retarget": false})
	var s: RtSetup = BattleBridge.make_rt_setup_rules(st, RtKit.data(), cmd, 99, {"combat": {"autopilot": false}})
	assert_eq([s.encounter_id, s.group_id, s.seed, s.is_boss, s.can_flee, s.tutorial],
		["enc_rt_dummy", "g_dummy", 99, false, true, false])
	assert_eq([s.advantage, s.opener, s.rt_opener], [BattleSetup.Advantage.PREEMPTIVE, "bark",
		{"kind": "strike", "target": "e0"}])
	assert_eq([s.auto_attack, s.auto_retarget, s.difficulty, s.rules], [false, false, &"prime",
		{"combat": {"autopilot": false}}])
	assert_eq([s.enemy_dmg_mult, s.exp_mult, s.floor_index, s.theme_id], [1.0, 1.0, 1, "metro"])
	assert_eq([int(s.items.get("itm_molotov", 0)), int(s.items.get("itm_bandage", 0))], [2, 3], "the battle items")
	assert_true(s.mods.is_empty() and s.tutorial_steps.is_empty(), "no mods in R1b-I1, no tutorial steps")
	var p0: RtUnit = _unit(s, "p0")
	assert_false(p0.auto_on, "rt.auto switches the controlled unit's auto-attack")
	assert_true(_unit(s, "p1").auto_on)
	var vor: RtSetup = RtKit.setup(RtKit.state(6), RtKit.dummy_cmd({"diff": "vorabend"}))
	assert_eq([vor.difficulty, vor.enemy_dmg_mult, vor.exp_mult], [&"vorabend", Balance.EASY_ENEMY_DMG, Balance.EASY_EXP])
	var boss: RtSetup = RtKit.setup(RtKit.state(6), RtKit.encounter("enc_rt_test_boss", [["g", "enc_rt_test_boss",
		[0, -300, 128]]], {"adv": BattleSetup.Advantage.PREEMPTIVE, "opener": "bark"}))
	assert_eq([boss.advantage, boss.opener, boss.is_boss, boss.can_flee], [BattleSetup.Advantage.NORMAL, "", true,
		false], "bosses: always NORMAL")
	var amb: RtSetup = RtKit.setup(RtKit.state(6), RtKit.dummy_cmd({"adv": BattleSetup.Advantage.AMBUSH,
		"opener": "bark"}))
	assert_eq(amb.opener, "", "\"bark\" only with a first strike")


func test_party_units() -> void:
	var st: GameState = RtKit.state(6, "mopsula")
	st.member("kai").rt_loadout = {"2": "skl_kai_first_aid", "4": "skl_kai_deo_torch", "3": "skl_kai_cable_whip"}
	st.member("kai").rt_preset = "careful"
	st.member("mopsula").rt_preset = "attack"
	var cmd: Dictionary = RtKit.dummy_cmd({"ctl": "p1", "party": [{"u": "p0", "p": [10, 200, 200]},
		{"u": "p1", "p": [-150, 300, 64]}], "presets": {"p0": {"preset": "support", "tog": {"show": false}}}})
	var s: RtSetup = RtKit.setup(st, cmd)
	assert_eq(s.units.map(func(u: RtUnit) -> String: return u.id), ["p0", "p1", "e0"],
		"party by battle slot, then the enemies")
	assert_eq(s.controlled_id, "p1")
	var kai: RtUnit = _unit(s, "p0")
	var mop: RtUnit = _unit(s, "p1")
	assert_eq([kai.def_id, kai.driver, mop.def_id, mop.driver], ["kai", RtUnit.Driver.AI, "mopsula",
		RtUnit.Driver.PLAYER])
	assert_eq([kai.x, kai.z, kai.yaw, mop.yaw], [10, 200, 200, 64], "the recorded poses")
	assert_eq([kai.radius, kai.move_cm_tick, kai.threat_pm, kai.auto_skill, kai.swing_ticks, kai.reach, kai.follow_cm],
		[40, 18, 1500, "skl_attack_kai", 60, 250, 600])
	assert_eq([mop.radius, mop.threat_pm, mop.swing_ticks, mop.reach, mop.follow_cm], [35, 1000, 72, 1000, 700])
	assert_eq(kai.mp_regen, {"mode": "hit", "amount": 1, "taken": 1, "taken_every_ticks": 30, "every_ticks": 0})
	assert_eq([mop.mp_regen, mop.mp_regen_next], [{"mode": "time", "amount": 1, "taken": 0, "taken_every_ticks": 0,
		"every_ticks": 45}, 45], "+1 MP every 45 ticks from ct 0")
	assert_eq([kai.preset, kai.toggles], ["support", {"interrupt": true, "show": false, "potions": false}],
		"the recorded preset wins over the member's")
	assert_eq([mop.preset, mop.keep_cm], ["attack", 450], "the member's preset (07 §5.2) and its keep distance")
	assert_eq(kai.bar, {1: "skl_kai_heavy_swing", 2: "skl_kai_first_aid", 3: "skl_kai_leash_trip",
		4: "skl_kai_deo_torch", 5: "skl_stunt_kai_suplex"}, "variants once their level is reached (cable whip: 7)")
	assert_eq(mop.bar, {1: "skl_mop_noble_flame", 2: "skl_mop_holy_lick", 3: "skl_mop_frost_sneeze",
		4: "skl_mop_thunder_bark", 5: "skl_stunt_mop_entrance"}, "FINALE and context variants stay off the bar")
	assert_eq([kai.move_budget, kai.swing_ready, kai.hp, kai.mp], [600, 0, kai.max_hp(), kai.max_mp()])
	assert_eq(s.presets, {"p0": {"preset": "support", "tog": {"interrupt": true, "show": false, "potions": false}}},
		"presets of the AI partner")
	var fallback: RtSetup = RtKit.setup(RtKit.state(6, "mopsula"), RtKit.dummy_cmd({"ctl": "p3"}))
	assert_eq(fallback.controlled_id, "p1", "an unknown controlled unit falls back to the hero")


func test_enemy_units() -> void:
	var cmd: Dictionary = RtKit.encounter("enc_f1_a2", [["g1", "enc_f1_a2", [0, -300, 128]],
		["g2", "enc_rt_rats", [0, -760, 128]]])
	var s: RtSetup = RtKit.setup(RtKit.state(6), cmd)
	assert_eq(s.units.map(func(u: RtUnit) -> String: return u.id), ["p0", "p1", "e0", "e1", "e2", "e3"])
	var rat: RtUnit = _unit(s, "e0")
	var caster: RtUnit = _unit(s, "e1")
	assert_eq([rat.def_id, rat.hp, rat.max_hp(), rat.radius, rat.move_cm_tick, rat.swing_ticks, rat.reach, rat.dmg_pm,
		rat.swing_ready, rat.auto_skill, rat.keep_cm], ["enm_kanalratte", 168, 168, 30, 12, 72, 220, 1000, 30,
		"skl_e_strike", 0], "24 HP × ENEMY_HP_PM 7000 (rt.hp_pm), first swing at ct 30")
	assert_eq([caster.def_id, caster.hp, caster.keep_cm], ["enm_rt_test_caster", 210, 600], "rt.enemies of enc_f1_a2")
	assert_eq([rat.x, rat.z, rat.yaw, Array(rat.entry), rat.pop_in_until], [0, -300, 128, [], 0],
		"the leader at its recorded position")
	assert_eq(caster.pop_in_until, 15, "komparsen pop in after POP_IN_TICKS")
	assert_true(RtGeo.walkable(s.geo, caster.x, caster.z, caster.radius, false))
	var lead2: RtUnit = _unit(s, "e2")
	assert_eq([lead2.x, lead2.z], [0, -760], "outside the ring: the leader starts where it stood …")
	assert_eq(Array(lead2.entry), [0, -450], "… and walks in to its ring point")
	assert_eq(_unit(s, "e3").pop_in_until, 15 + 30, "its komparse pops in after the entry")
	assert_eq(s.groups.map(func(g: Dictionary) -> Array: return [g["group_id"], g["encounter_id"], g["units"],
		g["entry"]]), [["g1", "enc_f1_a2", ["e0", "e1"], []], ["g2", "enc_rt_rats", ["e2", "e3"], [0, -450]]])
	assert_eq([s.group_id, s.enemy_ids], ["g1", PackedStringArray(["enm_kanalratte", "enm_rt_test_caster"])])


func test_enemy_cap_over_groups() -> void:
	var cmd: Dictionary = RtKit.encounter("enc_rt_dummies", [["g1", "enc_rt_dummies", [0, -300, 128]],
		["g2", "enc_rt_dummies", [300, 0, 192]], ["g3", "enc_rt_rats", [-300, 0, 64]]])
	var s: RtSetup = RtKit.setup(RtKit.state(6), cmd)
	assert_eq(s.groups.map(func(g: Dictionary) -> String: return g["group_id"]), ["g1", "g2"], "6 enemies: the rats wait")
	assert_eq(s.units.size(), 2 + 6)
	var low: RtSetup = BattleBridge.make_rt_setup_rules(RtKit.state(6), RtKit.data(), cmd, RtKit.SEED,
		{"combat": {"max_enemies": 4}})
	assert_eq(low.groups.map(func(g: Dictionary) -> String: return g["group_id"]), ["g1"],
		"run rules may lower the cap; the first group always comes")


func test_group_less_combat_takes_the_anchor() -> void:
	var cmd: Dictionary = RtKit.encounter("enc_rt_rats", [], {"party": [{"u": "p0", "p": [0, 300, 0]},
		{"u": "p1", "p": [-150, 350, 0]}]})
	var s: RtSetup = RtKit.setup(RtKit.state(6), cmd)
	assert_eq(s.groups.size(), 1)
	var lead: RtUnit = _unit(s, "e0")
	assert_eq([lead.x, lead.z, Array(lead.entry)], [0, -750, [0, -450]],
		"from the door farthest from the controlled unit (north), walking in")
	assert_eq(lead.yaw, DetMath.yaw_of(0, 750), "facing the centre")


func test_pep_talk_guard_for_bosses() -> void:
	var st: GameState = RtKit.state(6)
	st.flags[BattleBridge.PEP_TALK_FLAG] = true
	var plain: RtSetup = RtKit.setup(st, RtKit.dummy_cmd())
	assert_true(bool(st.flags.get(BattleBridge.PEP_TALK_FLAG, false)), "kept for a boss")
	assert_false(_unit(plain, "p0").has_status("sts_guard"))
	var boss: RtSetup = RtKit.setup(st, RtKit.encounter("enc_rt_test_boss", [["g", "enc_rt_test_boss", [0, -300, 128]]]))
	for id: String in ["p0", "p1"]:
		var g: StatusEffect = _unit(boss, id).get_status("sts_guard")
		assert_true(g is RtStatus and (g as RtStatus).ends_at == 180, id + ": guarded for rt.default_ms 6000")
	assert_false(st.flags.has(BattleBridge.PEP_TALK_FLAG), "used up")


func test_invalid_commands_give_null() -> void:
	var st: GameState = RtKit.state(3)
	assert_null(BattleBridge.make_rt_setup(st, RtKit.data(), {"t": "move", "dx": 1}, 1))
	var bad: Dictionary = RtKit.dummy_cmd()
	bad["rt"]["v"] = 2
	assert_null(BattleBridge.make_rt_setup(st, RtKit.data(), bad, 1), "invalid rt block")
	var unknown: Dictionary = RtKit.dummy_cmd()
	unknown["enc"] = "enc_nope"
	assert_null(BattleBridge.make_rt_setup(st, RtKit.data(), unknown, 1))
	assert_null(BattleBridge.make_rt_setup(null, RtKit.data(), RtKit.dummy_cmd(), 1))


func test_opening_action_schema() -> void:
	var good: Array = [{}, {"kind": "strike", "target": "e0"}, {"kind": "skill", "u": "p0", "skill": "skl_x", "target":
		"e0"}, {"kind": "skill", "skill": "skl_x", "target": ""}, {"kind": "item", "u": "p1", "item": "itm_x",
		"target": "e2"}]
	for o: Variant in good:
		assert_eq(RtCommand.validate(RtKit.dummy_cmd({"open": o})), "", str(o))
	var bad: Array = [{"kind": "dance"}, {"kind": "strike", "target": ""}, {"kind": "skill", "target": "e0"},
		{"kind": "item", "u": "e0", "item": "itm_x", "target": "e0"}, {"kind": "skill", "skill": "skl_x", "target": "x"},
		[], "strike"]
	for o: Variant in bad:
		assert_ne(RtCommand.validate(RtKit.dummy_cmd({"open": o})), "", "rejected: " + str(o))
		assert_ne(Command.validate(RtKit.dummy_cmd({"open": o})), "")
