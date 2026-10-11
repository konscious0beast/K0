extends TestCase
## R5a (07 §4.1, §5.2): the recorded loadout command — action bar variants and the partner tactic chosen outside a
## combat ({"t": "loadout", "member", "bar", "preset", "tog"}), checked by RunRules.loadout_refusal in the live entry
## (Game.apply_loadout) and both verifiers, applied by RunRules.apply_loadout; the next combat's setup reads it.

const RtLive := preload("res://tests/fixtures/rt_live/rt_live.gd")


func before_each() -> void:
	RtLive.swap_data()


func after_each() -> void:
	if Game.combat != null:
		Game.end_combat()
	Show.abort_battle()
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.in_battle = false
	RtLive.restore_data()


func test_the_rules_of_a_loadout() -> void:
	var cmd: Dictionary = RunRules.loadout_cmd("kai", {4: "skl_kai_deo_torch"}, "careful", {"potions": true, "x": true})
	assert_eq(cmd, {"t": "loadout", "member": "kai", "bar": {"4": "skl_kai_deo_torch"}, "preset": "careful",
		"tog": {"potions": true}}, "the builder: slot keys as Strings, known switches only")
	assert_eq(Command.validate(cmd), "")
	var d: GameData = RtKit.data()
	var st: GameState = RtKit.state(6)
	var refusal: Callable = func(member: String, bar: Dictionary) -> String:
		return RunRules.loadout_refusal(st, d, RunRules.loadout_cmd(member, bar))
	assert_eq(refusal.call("kai", {"4": "skl_kai_deo_torch", "2": "skl_kai_first_aid"}), "", "level 6: two variants")
	assert_eq(refusal.call("kai", {}), "", "back to the base abilities")
	assert_eq(refusal.call("kai", {"4": "skl_kai_heavy_swing"}), "not_a_variant")
	assert_eq(refusal.call("kai", {"2": "skl_kai_deo_torch"}), "not_a_variant", "a variant of another slot")
	assert_eq(refusal.call("kai", {"3": "skl_kai_cable_whip"}), "not_learned", "level 7 variant")
	assert_eq(refusal.call("rattenkoenigin", {}), "unknown_member")
	var ctb: GameState = RtKit.state(6)
	ctb.combat_mode = &"ctb"
	assert_eq(RunRules.loadout_refusal(ctb, d, cmd), "not_realtime", "CTB runs have no action bar")
	assert_true(RunRules.apply_loadout(st, cmd))
	var kai: PartyMember = st.member("kai")
	assert_eq([kai.rt_loadout, kai.rt_preset, kai.rt_toggles], [{"4": "skl_kai_deo_torch"}, "careful",
		{"potions": true}])
	var before: String = StateHash.of(st)
	RunRules.apply_loadout(st, RunRules.loadout_cmd("kai", {}))
	assert_ne(StateHash.of(st), before, "the choice is part of the state (07 §10.4)")


func test_live_entry_next_combat_and_replays() -> void:
	RtLive.adopt(RtLive.state(6, 20.0, {"itm_smoke": 1}))
	assert_true(Game.apply_loadout(RunRules.loadout_cmd("kai", {"4": "skl_kai_deo_torch"}, "careful")))
	assert_true(Game.apply_loadout(RunRules.loadout_cmd("mopsula", {"3": "skl_mop_expert_opinion"}, "attack",
		{"potions": true})))
	assert_false(Game.apply_loadout(RunRules.loadout_cmd("kai", {"3": "skl_kai_cable_whip"})), "refused: not learned")
	assert_eq(RtLive.cmd_types(Game.run_log).count("loadout"), 2, "only the accepted choices are recorded")
	var setup: RtSetup = Game.make_rt_setup(RtKit.dummy_cmd())
	assert_not_null(setup)
	var p0: RtUnit = null
	var p1: RtUnit = null
	for u: RtUnit in setup.units:
		if u.id == "p0":
			p0 = u
		elif u.id == "p1":
			p1 = u
	assert_eq(str(p0.bar.get(4, "")), "skl_kai_deo_torch", "the hero's bar takes the variant")
	assert_eq([p1.preset, bool(p1.toggles["potions"])], ["attack", true], "the AI partner plays the chosen tactic")
	assert_false(Game.apply_loadout(RunRules.loadout_cmd("kai", {})), "never during a combat")
	RtLive.play([RtCommand.item(5, "p0", "itm_smoke", "")], 300)
	assert_eq(RtLive.cmd_types(Game.run_log).count("loadout"), 2)
	var live: String = StateHash.of(Game.state)
	var res: Dictionary = Game.replay_log(Game.run_log)
	assert_eq([res["errors"], res["mismatch_at"], res["final_hash"]], [PackedStringArray(), -1, live])
	var core: Dictionary = RunSim.replay(DB.data, Game.run_log)
	assert_eq([core["errors"], core["combat_mismatch_at"]], [PackedStringArray(), -1], "the core verifier agrees")


func test_the_core_refuses_forged_loadouts() -> void:
	var sim: RunSim = RtLive.core_sim(RtKit.state(1))
	sim.apply(RunRules.loadout_cmd("kai", {"4": "skl_kai_deo_torch"}))
	sim.apply(RunRules.loadout_cmd("kai", {}, "support"))
	var reasons: Array = sim.rejected_cmds.map(func(r: Dictionary) -> String: return str(r["reason"]))
	assert_eq(reasons, ["not_learned"], "level 1 has no variants")
	assert_eq(sim.state.member("kai").rt_preset, "support")
	var ctb: GameState = RtKit.state(6)
	ctb.combat_mode = &"ctb"
	var csim: RunSim = RunSim.new(RtKit.data(), ctb, {})
	csim.apply(RunRules.loadout_cmd("kai", {}))
	assert_eq(csim.rejected_cmds.size(), 1)
	assert_eq(str(csim.rejected_cmds[0]["reason"]), "not_realtime")
