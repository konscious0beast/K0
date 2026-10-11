extends TestCase
## 07 §3.6.12, §4.1–4.3 (R1b-I1) test_r1_rt_show: SHOW and FINALE — the seeded success roll of a SHOW and both of its
## outcomes (damage; or self damage 10 % + the self stun without a resistance roll), the party-wide SHOW cooldown of
## 900 ticks (instants from their start, casts from their end; nobody fires while a SHOW cast runs), the FINALE gate
## (level 6 and a hostile target below 30 %), FINALE never rolls and counts as a stunt, by_ai of STUNT_RESULT.

const FixedMath := preload("res://core/stats/fixed_math.gd")
const StatusFx := preload("res://core/rt/rt_status_fx.gd")
const T := ActionEvent.Type
const K := BattleCommand.Kind


func _sim(level: int = 6, hero: String = "kai", seed: int = RtKit.SEED) -> RtSim:
	var s: RtSetup = RtKit.setup(RtKit.state(level, hero), RtKit.dummy_cmd({"ctl": "p0" if hero == "kai" else "p1"}),
		seed)
	var sim: RtSim = RtKit.no_ai(RtSim.new(s, RtKit.data()))
	sim.start()
	for u: RtUnit in sim.units():
		u.auto_on = false
	return sim


func _until(sim: RtSim, ct: int) -> Array[ActionEvent]:
	var out: Array[ActionEvent] = []
	while sim.tick() < ct and not sim.is_finished():
		out.append_array(sim.step())
	return out


static func _rng_n(sim: RtSim) -> int:
	return int(sim.snapshot()["rng_n"])


## Kai's Suplex on the dummy at ct 0 lands at ct 24 (stunt impact): the roll of that tick follows its seeded draw.
func test_show_roll_is_seeded_and_both_outcomes_play_out() -> void:
	var seen: Dictionary = {}
	for seed in range(1, 41):
		var sim: RtSim = _sim(6, "kai", seed)
		var kai: RtUnit = sim.unit("p0")
		var sk: SkillDef = sim.skill_def("skl_stunt_kai_suplex")
		var start: Array = RtKit.act(sim, RtCommand.ability(0, "p0", "skl_stunt_kai_suplex", "e0"))
		var st: ActionEvent = RtKit.of(start[1], T.ACTION_START)[0]
		assert_eq([st.command, st.skill_id, st.by_ai], [K.STUNT, "skl_stunt_kai_suplex", false])
		_until(sim, 24)
		var chance: int = RtSim.Ability.stunt_chance_bp(sim, kai, sk, PackedStringArray(["e0"]))
		assert_eq(chance, 6000 + kai.stat(StatBlock.Stat.LCK) * 100, "(0.6 + LCK × 0.01), no boss, below the cap")
		var n: int = _rng_n(sim)
		var ok: bool = FixedMath.roll_bp(SeedUtil.make_rng(SeedUtil.derive(seed, "rt", n + 1)), chance)
		var hp0: int = kai.hp
		var ev: Array[ActionEvent] = sim.step()
		var sr: Array[ActionEvent] = RtKit.of(ev, T.STUNT_RESULT)
		assert_eq(sr.size(), 1)
		if sr.size() != 1:
			return
		assert_eq([sr[0].success, sr[0].actor_id, sr[0].skill_id, sr[0].by_ai], [ok, "p0", "skl_stunt_kai_suplex", false],
			"seed %d" % seed)
		var dmg: Array[ActionEvent] = RtKit.of(ev, T.DAMAGE)
		if ok:
			assert_true(dmg.size() == 1 and dmg[0].target_id == "e0" and dmg[0].actor_id == "p0", "the SHOW hits")
			assert_eq(kai.hp, hp0)
		else:
			var self_dmg: int = FixedMath.div_round(kai.max_hp() * 10, 100)
			assert_true(dmg.size() == 1 and dmg[0].target_id == "p0" and dmg[0].amount == self_dmg,
				"a failed SHOW costs 10 % of the own max HP")
			var stun: Array = RtKit.of(ev, T.STATUS_ADDED).filter(func(x: ActionEvent) -> bool:
				return x.status_id == "sts_stun")
			assert_true(stun.size() == 1 and stun[0].target_id == "p0" and stun[0].value == 45, "rt.fail_ms 1500")
		var end: Array[ActionEvent] = RtKit.of(ev, T.ACTION_END)
		assert_true(end.size() == 1 and ev.find(sr[0]) < ev.find(end[0]))
		seen[ok] = true
		if seen.size() == 2 and seed >= 5:
			break
	assert_eq(seen.size(), 2, "success and failure both played out")


func test_failed_show_stun_ignores_resistance() -> void:
	for seed in range(1, 60):
		var sim: RtSim = _sim(6, "kai", seed)
		var kai: RtUnit = sim.unit("p0")
		kai.stats.values[StatBlock.Stat.LCK] = 0
		kai.status_resist = {"sts_stun": 1.0}
		RtKit.act(sim, RtCommand.ability(0, "p0", "skl_stunt_kai_suplex", "e0"))
		_until(sim, 24)
		var ev: Array[ActionEvent] = sim.step()
		var sr: Array[ActionEvent] = RtKit.of(ev, T.STUNT_RESULT)
		if sr.size() == 1 and not sr[0].success:
			assert_true(kai.has_status("sts_stun"), "the self stun is forced")
			assert_eq(RtKit.of(ev, T.STATUS_BLOCKED).size(), 0)
			return
	fail("no failed SHOW in 59 seeds")


func test_show_cooldown_is_party_wide() -> void:
	var sim: RtSim = _sim()
	sim.unit("e0").hp = 1000
	RtKit.act(sim, RtCommand.ability(0, "p0", "skl_stunt_kai_suplex", "e0"))
	assert_eq([sim.cooldown_left("p0", "skl_stunt_kai_suplex"), sim.cooldown_total("p0", "skl_stunt_kai_suplex")],
		[899, 900], "an instant SHOW: from its start")
	assert_eq(sim.cooldown_left("p1", "skl_stunt_mop_entrance"), 899, "the partner's SHOW too")
	sim.unit("e0").hp = 100
	assert_eq(sim.can_use("p0", "skl_kai_prime_finisher", "e0"), "cooldown", "and the FINALE")
	_until(sim, 900)
	assert_eq(sim.can_use("p0", "skl_stunt_kai_suplex", "e0"), "", "30 s later")
	var mop: RtSim = _sim(6, "mopsula")
	RtKit.act(mop, RtCommand.ability(0, "p1", "skl_stunt_mop_entrance", ""))
	assert_eq(mop.cast_progress("p1"), Vector2i(1, 30), "a SHOW cast")
	assert_eq(mop.cooldown_left("p1", "skl_stunt_mop_entrance"), 0, "a cast SHOW: from its end …")
	assert_eq(mop.can_use("p0", "skl_stunt_kai_suplex", "e0"), "cooldown", "… but nobody fires while it runs")
	var ev: Array[ActionEvent] = _until(mop, 31)
	assert_eq(RtKit.of(ev, T.STUNT_RESULT).size(), 1)
	assert_eq([mop.cooldown_left("p1", "skl_stunt_mop_entrance"), mop.cooldown_total("p0", "skl_stunt_kai_suplex")],
		[899, 900])


func test_finale_gate() -> void:
	var sim: RtSim = _sim()
	var e: RtUnit = sim.unit("e0")
	sim.submit(RtCommand.target(0, "p0", "e0"))
	sim.step()
	assert_eq(sim.bar("p0")[5], "skl_stunt_kai_suplex", "full HP target: SHOW")
	e.hp = 600
	assert_eq(sim.bar("p0")[5], "skl_stunt_kai_suplex", "exactly 30 %: still SHOW")
	assert_eq(sim.can_use("p0", "skl_kai_prime_finisher", "e0"), "target_hp")
	var r: ActionEvent = RtKit.of(RtKit.act(sim, RtCommand.ability(1, "p0", "skl_kai_prime_finisher", "e0"))[1],
		T.ACTION_REFUSED)[0]
	assert_eq([r.text, r.skill_id], ["target_hp", "skl_kai_prime_finisher"])
	e.hp = 599
	assert_eq(sim.bar("p0")[5], "skl_kai_prime_finisher", "below 30 %: FINALE on slot 5")
	assert_eq(sim.can_use("p0", "skl_kai_prime_finisher", "e0"), "")
	var st: Array[ActionEvent] = RtKit.of(RtKit.act(sim, RtCommand.ability(2, "p0", "skl_kai_prime_finisher",
		"e0"))[1], T.ACTION_START)
	assert_true(st.size() == 1 and st[0].command == K.STUNT, "FINALE counts as a stunt")
	assert_eq(sim.cooldown_left("p0", "skl_stunt_kai_suplex"), 899, "and takes the SHOW cooldown")
	_until(sim, 26)
	var n: int = _rng_n(sim)
	var ev: Array[ActionEvent] = sim.step()
	var sr: Array[ActionEvent] = RtKit.of(ev, T.STUNT_RESULT)
	assert_true(sr.size() == 1 and sr[0].success, "FINALE never fails")
	assert_eq(_rng_n(sim), n + 1, "no success roll: the one draw is the damage formula")
	assert_eq(RtKit.of(ev, T.DAMAGE).size(), 1)
	var low: RtSim = _sim(5)
	low.unit("e0").hp = 100
	low.submit(RtCommand.target(0, "p0", "e0"))
	low.step()
	assert_eq(low.bar("p0")[5], "skl_stunt_kai_suplex", "level 5: no FINALE")
	assert_eq(low.submit(RtCommand.ability(1, "p0", "skl_kai_prime_finisher", "e0")), "not_learned")
	var friend: RtSim = _sim()
	friend.submit(RtCommand.target(0, "p0", "p1"))
	friend.step()
	friend.unit("p1").hp = 1
	assert_eq(friend.bar("p0")[5], "skl_stunt_kai_suplex", "a friendly target never shows the FINALE")


func test_ai_show_reports_by_ai() -> void:
	var sim: RtSim = _sim()
	var kai: RtUnit = sim.unit("p0")
	sim.step()
	assert_eq(RtSim.Ability.use_ability(sim, sim.unit("p1"), "skl_stunt_mop_entrance", "", true), "",
		"the AI partner's SHOW (rules: R1b-I2) goes through the same start")
	var ev: Array[ActionEvent] = _until(sim, 32)
	var sr: Array[ActionEvent] = RtKit.of(ev, T.STUNT_RESULT)
	assert_true(sr.size() == 1 and sr[0].by_ai and sr[0].actor_id == "p1", "STUNT_RESULT.by_ai")
	assert_eq(sim.can_use("p0", "skl_stunt_kai_suplex", "e0"), "cooldown")
	assert_eq(kai.hp, kai.max_hp())
