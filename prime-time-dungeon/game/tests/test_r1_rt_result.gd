extends TestCase
## 07 §2.11, §3.12 (R1b-I1) test_r1_rt_result: the BattleResult of a real-time combat — EXP (× exp_mult), credits with
## the new overkill rule (killing blow ≥ 50 % of max HP → × 1.25), drops (derive(seed, "drops", 0) in kill order),
## party HP / MP, kills, KOs, group_ids, damage taken, crits, weakness hits, the counters of the controlled unit only
## (interrupts), turns / party_turns (by_ai), duration; double KO = victory; defeat; the time limit ("Sendezeit
## überzogen!"). Thieves, refunds, boss rewards and the telegraph / train counters follow with R1b-I3.

const Damage := preload("res://core/rt/rt_damage.gd")
const StatusFx := preload("res://core/rt/rt_status_fx.gd")
const T := ActionEvent.Type
const K := BattleCommand.Kind
const RAT_HP: int = 168                      # Kanalratte: 24 × ENEMY_HP_PM 7000


func _two_groups(opts: Dictionary = {}) -> Dictionary:
	return RtKit.encounter("enc_rt_rats", [["g1", "enc_rt_rats", [0, -300, 128]], ["g2", "enc_rt_rats",
		[300, -200, 160]]], opts)


func _sim(cmd: Dictionary, bal: Dictionary = {}) -> RtSim:
	var s: RtSetup = RtKit.setup(RtKit.state(6), cmd)
	if not bal.is_empty():
		s.balance = RtBalance.from_values(bal)
	var sim: RtSim = RtSim.new(s, RtKit.data())
	sim.start()
	for u: RtUnit in sim.units():
		u.auto_on = false
	return sim


## `src` deals exactly `amount` to `tgt` (an ability hit without the formula).
func _hit(sim: RtSim, src: String, tgt: String, amount: int, element: String = "physical", crit: bool = false,
		weak: bool = false) -> void:
	var r: HitResult = HitResult.new()
	r.crit = crit
	r.weak = weak
	Damage.apply(sim, sim.unit(src), sim.unit(tgt), amount, element, r, "skl_kai_heavy_swing", "", "",
		Damage.Kind.ABILITY, false, K.SKILL, 1000)


func _finish(sim: RtSim) -> Array[ActionEvent]:
	var out: Array[ActionEvent] = []
	var n: int = 0
	while not sim.is_finished() and n < 2000:
		out.append_array(sim.step())
		n += 1
	return out


func test_victory_rewards() -> void:
	var sim: RtSim = _sim(_two_groups())
	assert_eq(sim.units().map(func(u: RtUnit) -> String: return u.id), ["p0", "p1", "e0", "e1", "e2", "e3"])
	sim.step()
	sim.unit("e0").hp = 10
	_hit(sim, "p0", "e0", RAT_HP, "fire", true, true)       # overkill (≥ 84), a crit, a weakness hit
	sim.unit("e1").hp = 10
	_hit(sim, "p0", "e1", 10)                               # no overkill
	_hit(sim, "e3", "p0", 30)                               # damage taken
	sim.unit("e2").hp = 100
	_hit(sim, "p1", "e2", 100)                              # overkill
	sim.unit("e3").hp = 50
	_hit(sim, "p0", "e3", 50)                               # no overkill
	var ev: Array[ActionEvent] = sim.step()
	assert_eq(ev[ev.size() - 1].type, T.BATTLE_END)
	var r: BattleResult = sim.result
	assert_eq([r.outcome, r.encounter_id, r.group_id, r.group_ids, r.is_boss, r.boss_id, r.advantage],
		[BattleResult.Outcome.VICTORY, "enc_rt_rats", "g1", PackedStringArray(["g1", "g2"]), false, "", 0])
	assert_eq([r.kills, r.defeated_ids], [4, PackedStringArray(["enm_kanalratte", "enm_kanalratte", "enm_kanalratte",
		"enm_kanalratte"])])
	assert_eq([r.exp, r.credits, r.overkill_credits], [4 * 12, 8 + 6 + 8 + 6, 2 + 2],
		"EXP 12 each; credits 6, overkill × 1.25 → 8")
	var lck: int = sim.unit("p0").stat(StatBlock.Stat.LCK) + sim.unit("p1").stat(StatBlock.Stat.LCK)
	var rng: RandomNumberGenerator = SeedUtil.make_rng(SeedUtil.derive(sim.setup.seed, "drops", 0))
	var drops: PackedStringArray = []
	for id: String in ["e0", "e1", "e2", "e3"]:
		drops.append_array(BattleState.roll_drops(sim.unit(id).drops, lck, 2, rng))
	assert_eq(r.drops, drops, "drops in kill order from derive(seed, \"drops\", 0)")
	var kai: RtUnit = sim.unit("p0")
	var mop: RtUnit = sim.unit("p1")
	assert_eq([r.party_hp, r.party_mp], [{"kai": kai.hp, "mopsula": mop.hp}, {"kai": kai.mp, "mopsula": mop.mp}])
	assert_eq([r.damage_taken, r.crits, r.weakness_hits, r.weak_found], [30, 1, 1, {"enm_kanalratte":
		PackedStringArray(["fire"])}])
	assert_eq([r.min_party_hp, r.party_kos, r.items_used, r.duration_ticks], [mini(kai.hp, mop.hp), 0, 0, 2],
		"the lowest HP of the living members")
	assert_almost(r.min_party_hp_pct, float(kai.hp) / float(kai.max_hp()), 0.000001, "the lowest share (Kai's)")


func test_vorabend_exp() -> void:
	var sim: RtSim = _sim(RtKit.encounter("enc_rt_rats", [["g", "enc_rt_rats", [0, -300, 128]]], {"diff": "vorabend"}))
	assert_eq(sim.setup.difficulty, &"vorabend")
	_hit(sim, "p0", "e0", RAT_HP)
	_hit(sim, "p0", "e1", RAT_HP)
	_finish(sim)
	assert_eq(sim.result.exp, 24 * 1200 / 1000, "× EASY_EXP 1.2 (truncated like CTB)")


func test_turns_and_controlled_counters() -> void:
	var sim: RtSim = _sim(RtKit.dummy_cmd())
	var e: RtUnit = sim.unit("e0")
	var mop: RtUnit = sim.unit("p1")
	e.cast = {"skill": "skl_e_test_hex", "target": "p0", "targets": ["p0"], "x": e.x, "z": e.z, "start": 0, "end": 60,
		"interruptible": true, "worthy": true, "moving_cancels": false, "channel": false, "period": 0, "next_tick": -1,
		"tele": -1, "kind": "ability", "item": "", "ai": true, "cmd": K.SKILL}
	sim.submit(RtCommand.ability(0, "p0", "skl_kai_leash_trip", "e0"))
	sim.submit(RtCommand.ability(0, "p0", "skl_kai_heavy_swing", "e0"))
	sim.submit(RtCommand.item(0, "p0", "itm_bandage", ""))
	sim.submit(RtCommand.partner_special(0, "p1"))
	var ev: Array[ActionEvent] = []
	while sim.tick() < 20:
		ev.append_array(sim.step())
	assert_eq(sim.tally["interrupts"], 1, "the controlled unit's interrupt counts")
	var cast2: Dictionary = e.cast
	assert_true(cast2.is_empty())
	for ai: bool in [true, false]:
		e.cast = {"skill": "skl_e_test_hex", "target": "p0", "targets": ["p0"], "x": e.x, "z": e.z, "start": 20,
			"end": 80, "interruptible": true, "worthy": true, "moving_cancels": false, "channel": false, "period": 0,
			"next_tick": -1, "tele": -1, "kind": "ability", "item": "", "ai": true, "cmd": K.SKILL}
		assert_true(sim.interrupt(mop, e, ai))
	assert_eq(sim.tally["interrupts"], 1, "the partner's interrupts never count (AI or Partner-Spezial)")
	var turns0: int = int(sim.tally["turns"])
	var party0: int = int(sim.tally["party_turns"])
	RtSim.Ability.use_ability(sim, mop, "skl_mop_thunder_bark", "", true)
	assert_eq([int(sim.tally["turns"]) - turns0, int(sim.tally["party_turns"]) - party0], [1, 0],
		"an AI action is a turn, not a party turn")
	Damage.apply(sim, sim.unit("p0"), e, e.hp, Elements.PHYSICAL, HitResult.new(), "skl_kai_heavy_swing", "", "",
		Damage.Kind.ABILITY, false, K.SKILL, 1000)
	ev.append_array(_finish(sim))
	var starts: Array[ActionEvent] = RtKit.of(ev, T.ACTION_START)
	var mine: Array = starts.filter(func(x: ActionEvent) -> bool: return not x.by_ai)
	assert_eq(mine.map(func(x: ActionEvent) -> String: return x.skill_id), ["skl_kai_leash_trip", "skl_kai_heavy_swing",
		"skl_item_bandage", "skl_mop_holy_lick"], "the person's actions incl. the Partner-Spezial")
	var r: BattleResult = sim.result
	assert_eq([r.turns, r.party_turns, r.interrupts, r.items_used], [starts.size() + 1, mine.size(), 1, 1])
	assert_eq(RtKit.of(ev, T.SWING).size(), 0, "(auto-attacks are no turns either way)")


func test_double_ko_is_a_victory() -> void:
	var sim: RtSim = _sim(RtKit.encounter("enc_rt_rats", [["g", "enc_rt_rats", [0, -300, 128]]]))
	var kai: RtUnit = sim.unit("p0")
	var mop: RtUnit = sim.unit("p1")
	var rat: RtUnit = sim.unit("e0")
	_hit(sim, "p0", "e1", RAT_HP)
	_hit(sim, "e0", "p1", mop.hp)
	assert_true(mop.is_ko())
	kai.hp = 1
	rat.hp = 1
	StatusFx.apply(sim, "e0", kai, "sts_poison", 0, 1000)
	StatusFx.apply(sim, "p0", rat, "sts_poison", 0, 1000)
	var ev: Array[ActionEvent] = _finish(sim)
	var ko: Array[ActionEvent] = RtKit.of(ev, T.KO)
	assert_eq(ko.map(func(x: ActionEvent) -> Array: return [x.tick, x.target_id]), [[60, "p0"], [60, "e0"]],
		"both fall in step 2 of the same tick")
	assert_eq(sim.result.outcome, BattleResult.Outcome.VICTORY, "all enemies down wins, even if the party fell too")
	assert_eq([sim.result.party_kos, sim.result.party_hp, sim.result.min_party_hp, sim.result.kills],
		[2, {"kai": 0, "mopsula": 0}, 0, 2])
	assert_eq(sim.result.min_party_hp_pct, 0.0)


func test_defeat() -> void:
	var sim: RtSim = _sim(RtKit.encounter("enc_rt_rats", [["g", "enc_rt_rats", [0, -300, 128]]]))
	_hit(sim, "p0", "e1", RAT_HP)
	_hit(sim, "e0", "p1", sim.unit("p1").hp)
	_hit(sim, "e0", "p0", sim.unit("p0").hp)
	var ev: Array[ActionEvent] = _finish(sim)
	assert_eq(ev[ev.size() - 1].value, BattleResult.Outcome.DEFEAT)
	var r: BattleResult = sim.result
	assert_eq([r.outcome, r.exp, r.credits, r.drops, r.kills, r.party_kos, r.duration_ticks],
		[BattleResult.Outcome.DEFEAT, 0, 0, PackedStringArray(), 1, 2, 1], "no rewards without a victory")


func test_time_limit() -> void:
	var sim: RtSim = _sim(RtKit.dummy_cmd(), {"MAX_COMBAT_TICKS": 900})
	var ev: Array[ActionEvent] = _finish(sim)
	var fr: Array[ActionEvent] = RtKit.of(ev, T.FLEE_RESULT)
	assert_true(fr.size() == 1 and fr[0].success and fr[0].text == "Sendezeit überzogen!" and fr[0].tick == 899)
	assert_eq([sim.result.outcome, sim.result.duration_ticks, sim.result.flee_attempts],
		[BattleResult.Outcome.FLED, 900, 0])
	assert_eq(RtKit.of(ev, T.SECOND).size(), 29, "SECOND 1…29; the last tick ends with BATTLE_END")
