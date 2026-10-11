extends TestCase
## 07 §3.3, §3.13 (R1b-I1) test_r1_rt_tick_order: the exact order of a tick — 1a player positions, 1b commands (in
## submission order), 2 status ticks and expiries, 5 pending hits, 6 cast ends, 7 queue / Partner-Spezial / AI, 8
## auto-attacks, 9 movement and the flight counter, 10 the end check, 11 MP over time and SECOND — in one tick that
## has all of them; KO is immediate (the unit's own pending hit lapses, its cast fails); the event stream (tick on
## every event, the prelude, by_ai, commands for later ticks, past ticks).

const StatusFx := preload("res://core/rt/rt_status_fx.gd")
const T := ActionEvent.Type
const K := BattleCommand.Kind


func _until(sim: RtSim, ct: int) -> Array[ActionEvent]:
	var out: Array[ActionEvent] = []
	while sim.tick() < ct and not sim.is_finished():
		out.append_array(sim.step())
	return out


static func _hex(e: RtUnit, start: int, end: int) -> Dictionary:
	return {"skill": "skl_e_test_hex", "target": "p0", "targets": ["p0"], "x": e.x, "z": e.z, "start": start,
		"end": end, "interruptible": true, "worthy": true, "moving_cancels": false, "channel": false, "period": 0,
		"next_tick": -1, "tele": -1, "kind": "ability", "item": "", "ai": true, "cmd": K.SKILL}


## A short, readable signature of an event: type plus the fields that identify it.
static func _sig(e: ActionEvent) -> String:
	var parts: PackedStringArray = [ActionEvent.type_name(e.type)]
	for f: String in ["actor_id", "target_id", "skill_id", "status_id", "text"]:
		var v: String = str(e.get(f))
		if v != "":
			parts.append("%s=%s" % [f, v])
	if e.type in [T.MP_CHANGE, T.SECOND, T.FLEE_WARNING]:
		parts.append("v=%d" % (e.amount if e.type == T.MP_CHANGE else e.value))
	return " ".join(parts)


## Mopsula is the hero (casts, regenerates MP over time), Kai the AI partner (without rules until the tactic change
## brings those of "careful"); at ct 149 every step has work.
func test_one_tick_in_step_order() -> void:
	var c: int = 149
	var sim: RtSim = RtKit.sim_no_ai(RtKit.dummy_cmd({"ctl": "p1"}), 6, "mopsula")
	var kai: RtUnit = sim.unit("p0")
	var mop: RtUnit = sim.unit("p1")
	var e: RtUnit = sim.unit("e0")
	for u: RtUnit in sim.units():
		u.auto_on = false
	_until(sim, c - 120)
	StatusFx.apply(sim, "p0", e, "sts_poison", 0, 1000)              # ticks at c − 60 and c
	StatusFx.apply(sim, "p0", e, "sts_slow", 0, 1000)                # expires at c
	_until(sim, c - 9)
	e.auto_on = true                                                 # the dummy swings at c − 9: its hit lands at c
	e.swing_ready = c - 9
	_until(sim, c - 8)
	e.auto_on = false
	e.cast = _hex(e, c - 8, c)                                       # its cast ends at c
	_until(sim, c)
	kai.auto_on = true
	kai.swing_ready = c
	kai.target_id = ""
	mop.x = 0
	mop.z = 600                                                      # in the south door lane for 14 ticks
	mop.sample = [c - 1, 0, 600, 0, 0, 0]
	mop.move_budget = 600
	mop.outside_since = c - 14
	mop.mp = mop.max_mp() - 10
	mop.mp_regen_next = c
	mop.cooldowns["skl_mop_frost_sneeze"] = [c + 100, 180]
	assert_eq(sim.submit(RtCommand.move(c, "p1", 0, 700, 0, 0, 128)), "")          # too far: cut back
	assert_eq(sim.submit(RtCommand.target(c, "p1", "e0")), "")
	assert_eq(sim.submit(RtCommand.preset(c, "p0", "careful", {})), "")
	assert_eq(sim.submit(RtCommand.ability(c, "p1", "skl_mop_frost_sneeze", "")), "")
	assert_eq(sim.submit(RtCommand.ability(c, "p1", "skl_mop_noble_flame", "")), "")
	assert_eq(sim.submit(RtCommand.partner_special(c, "p0")), "")
	var ev: Array[ActionEvent] = sim.step()
	assert_eq(Array(ev.map(_sig)), [
		"POS_CORRECTED target_id=p1",                                                   # 1a
		"TARGET_CHANGED actor_id=p1 target_id=e0",                                      # 1b, submission order
		"PRESET_CHANGED actor_id=p0 text=careful",
		"ACTION_REFUSED actor_id=p1 skill_id=skl_mop_frost_sneeze text=cooldown",
		"ACTION_START actor_id=p1 skill_id=skl_mop_noble_flame text=Adelsflamme",
		"CAST_START actor_id=p1 target_id=e0 skill_id=skl_mop_noble_flame",
		"DAMAGE target_id=e0 status_id=sts_poison",                                     # 2
		"STATUS_REMOVED target_id=e0 status_id=sts_slow",
		"DAMAGE actor_id=e0 target_id=p0 skill_id=skl_e_dummy_poke",                    # 5
		"DAMAGE actor_id=e0 target_id=p0 skill_id=skl_e_test_hex",                      # 6
		"ACTION_END actor_id=e0 skill_id=skl_e_test_hex",
		"ACTION_START actor_id=p0 skill_id=skl_kai_leash_trip text=Leinen-Fallstrick",   # 7: the order, …
		"MP_CHANGE target_id=p0 v=-3",
		"TARGET_CHANGED actor_id=p0 target_id=e0",                                      # … then the AI ("assist"
		"ACTION_START actor_id=p0 skill_id=skl_kai_heavy_swing text=Wuchtschlag",        # target, the filler of the
		"MP_CHANGE target_id=p0 v=-2",                                                  # new tactic "careful")
		"SWING actor_id=p0 target_id=e0 skill_id=skl_attack_kai",                       # 8
		"FLEE_WARNING actor_id=p1 v=45",                                                # 9
		"MP_CHANGE target_id=p1 v=1",                                                   # 11
		"SECOND v=5",
	])
	assert_true(ev.all(func(x: ActionEvent) -> bool: return x.tick == c), "every event carries the tick")


## 07 §3.3: a KO in steps 2–6 is immediate — the unit's own pending hit lapses, its cast fails (CAST_FAILED dead).
func test_ko_is_immediate() -> void:
	var sim: RtSim = RtKit.sim(RtKit.dummy_cmd(), 6)
	var e: RtUnit = sim.unit("e0")
	for u: RtUnit in sim.units():
		u.auto_on = false
	StatusFx.apply(sim, "p0", e, "sts_poison", 0, 1000)              # ticks at 60
	_until(sim, 51)
	e.auto_on = true
	e.swing_ready = 51
	_until(sim, 52)
	e.auto_on = false
	e.cast = _hex(e, 52, 60)
	e.hp = 1
	var kai: RtUnit = sim.unit("p0")
	var hp0: int = kai.hp
	var quiet: Array[ActionEvent] = _until(sim, 60)
	assert_eq(RtKit.of(quiet, T.SWING).size() + RtKit.of(quiet, T.DAMAGE).size(), 0)
	var ev: Array[ActionEvent] = sim.step()
	assert_eq(Array(ev.map(_sig)), [
		"DAMAGE target_id=e0 status_id=sts_poison",
		"KO actor_id=p0 target_id=e0",
		"CAST_FAILED actor_id=e0 skill_id=skl_e_test_hex text=dead",
		"ACTION_END actor_id=e0 skill_id=skl_e_test_hex",
		"TARGET_CHANGED actor_id=p1",                                # step 7: the AI partner has no target left
		"BATTLE_END",
	], "no hit from the fallen dummy in step 5, no hex in step 6, then the end")
	assert_eq(kai.hp, hp0)
	assert_eq(sim.result.outcome, BattleResult.Outcome.VICTORY)


func test_prelude_and_event_ticks() -> void:
	var s: RtSetup = RtKit.setup(RtKit.state(6), RtKit.encounter("enc_rt_rats", [["g", "enc_rt_rats", [0, -300, 128]]],
		{"adv": BattleSetup.Advantage.PREEMPTIVE}))
	var sim: RtSim = RtSim.new(s, RtKit.data())
	var first: Array[ActionEvent] = sim.step()                       # step() plays the prelude itself
	assert_eq(first[0].type, T.BATTLE_START)
	assert_eq([first[0].value, first[0].target_ids, first[0].tick], [BattleSetup.Advantage.PREEMPTIVE,
		PackedStringArray(["p0", "p1", "e0", "e1"]), 0])
	assert_eq(first[1].type, T.ANNOUNCE)
	assert_eq(sim.start().size(), 0, "start() runs once")
	var all: Array[ActionEvent] = []
	for c in range(1, 90):
		var ev: Array[ActionEvent] = sim.step()
		assert_true(ev.all(func(x: ActionEvent) -> bool: return x.tick == c and x.beat == 0), "tick %d" % c)
		all.append_array(ev)
	assert_eq(RtKit.of(all, T.SECOND).map(func(x: ActionEvent) -> Array: return [x.tick, x.value]),
		[[29, 1], [59, 2], [89, 3]])
	assert_eq(RtKit.of(all, T.BATTLE_START).size(), 0)


func test_commands_for_later_ticks_and_the_past() -> void:
	var sim: RtSim = RtKit.sim(RtKit.dummy_cmd(), 6)
	assert_eq(sim.submit(RtCommand.target(5, "p0", "e0")), "", "queued for ct 5")
	assert_eq(sim.submit(RtCommand.target(5, "p0", "")), "")
	assert_eq(sim.submit(RtCommand.target(3, "p0", "p1")), "", "submission order is not tick order")
	var ev: Array[ActionEvent] = _until(sim, 6)
	var tc: Array = RtKit.of(ev, T.TARGET_CHANGED).filter(func(x: ActionEvent) -> bool: return x.actor_id == "p0")
	assert_eq(tc.map(func(x: ActionEvent) -> Array: return [x.tick, x.target_id]), [[3, "p1"], [5, "e0"], [5, ""]])
	assert_eq(sim.submit(RtCommand.target(5, "p0", "e0")), "past_tick")
	assert_eq(sim.submit({"t": "target_change", "ct": 9, "u": "p0"}), "schema")
	assert_eq(sim.submit(RtCommand.target(9, "e0", "p0")), "not_controlled")
	assert_eq(sim.submit(RtCommand.target(9, "p7", "p0")), "schema", "unit ids are p0..p3, e<n>")
	assert_eq(sim.submit(RtCommand.target(9, "p3", "p0")), "unknown_unit")
	assert_eq(sim.submit({"t": "move_input", "ct": 9, "u": "p0", "dir": [0, 0], "run": false}), "grade_b")
	assert_eq(sim.submit(RtCommand.speed(1000)), "schema", "not a combat tick command")


## by_ai (07 §3.13): the person's actions false (own unit, buffered, Partner-Spezial), the sim's choices true (enemies,
## AI partner, autopilot) — on SWING hits, KOs and actions.
func test_by_ai() -> void:
	var sim: RtSim = RtKit.sim_no_ai(RtKit.encounter("enc_rt_rats", [["g", "enc_rt_rats", [0, 100, 128]]]), 6)
	var kai: RtUnit = sim.unit("p0")
	var rat: RtUnit = sim.unit("e0")
	for u: RtUnit in sim.units():
		u.auto_on = false
	kai.auto_on = true
	rat.hp = 1
	sim.submit(RtCommand.target(0, "p0", "e0"))
	var ev: Array[ActionEvent] = _until(sim, 20)
	var ko: Array[ActionEvent] = RtKit.of(ev, T.KO)
	assert_true(ko.size() == 1 and ko[0].actor_id == "p0" and not ko[0].by_ai and ko[0].command == K.ATTACK,
		"the person's auto-attack: by_ai false, command ATTACK")
	assert_eq(sim.submit(RtCommand.autopilot(sim.tick(), "p0", true)), "")
	sim.step()
	assert_eq(kai.driver, RtUnit.Driver.AUTOPILOT)
	assert_true(sim.is_ai_driven(kai))
	sim.unit("e1").hp = 1
	ev = _until(sim, 300)
	ko = RtKit.of(ev, T.KO)
	assert_true(ko.size() == 1 and ko[0].actor_id == "p0" and ko[0].by_ai, "under autopilot: by_ai true")
	assert_true(sim.is_finished())
	var p2: RtSim = RtKit.sim_no_ai(RtKit.dummy_cmd(), 6)
	p2.submit(RtCommand.partner_special(0, "p1"))
	var st: Array = RtKit.of(_until(p2, 2), T.ACTION_START).filter(func(x: ActionEvent) -> bool:
		return x.actor_id == "p1")
	assert_true(st.size() == 1 and not st[0].by_ai, "Partner-Spezial: the person's order")


## The pull opener (07 §2.2, rt.open): a skill or an item of the opening unit at ct 0 without a range check, or the
## field strike as the first auto swing regardless of reach.
func test_openers_at_ct_0() -> void:
	var far: Array = [["g", "enc_rt_dummy", [0, -420, 128]]]               # 620 cm from Kai: out of every melee reach
	var skill: RtSim = RtKit.sim(RtKit.encounter("enc_rt_dummy", far, {"open": {"kind": "skill",
		"skill": "skl_kai_heavy_swing", "target": "e0"}}), 6)
	assert_eq(skill.unit("p0").target_id, "e0", "the prelude turns the opener to its target")
	var ev: Array[ActionEvent] = _until(skill, 10)
	var st: Array = RtKit.of(ev, T.ACTION_START).filter(func(x: ActionEvent) -> bool: return x.actor_id == "p0")
	assert_eq(st.map(func(x: ActionEvent) -> Array: return [x.tick, x.skill_id, x.by_ai]),
		[[0, "skl_kai_heavy_swing", false]], "a skill opener at ct 0, out of range")
	var hit: Array = RtKit.of(ev, T.DAMAGE).filter(func(x: ActionEvent) -> bool:
		return x.skill_id == "skl_kai_heavy_swing")
	assert_true(hit.size() == 1 and hit[0].tick == 9 and hit[0].target_id == "e0")
	_until(skill, 45)
	assert_eq(skill.can_use("p0", "skl_kai_heavy_swing", "e0"), "range", "afterwards range counts again")
	var item: RtSim = RtKit.sim(RtKit.encounter("enc_rt_dummy", far, {"party": [{"u": "p0", "p": [0, 440, 0]},
		{"u": "p1", "p": [0, -380, 0]}], "open": {"kind": "item", "item": "itm_bandage", "target": "p1"}}), 6)
	item.unit("p1").hp -= 50
	ev = _until(item, 16)
	var drink: Array = RtKit.of(ev, T.ACTION_START).filter(func(x: ActionEvent) -> bool: return x.item_id != "")
	assert_eq(drink.map(func(x: ActionEvent) -> Array: return [x.tick, x.item_id, x.target_ids]),
		[[0, "itm_bandage", PackedStringArray(["p1"])]], "an item opener: 820 cm > 800 + 35, used anyway")
	assert_eq(RtKit.of(ev, T.HEAL).map(func(x: ActionEvent) -> Array: return [x.tick, x.target_id]), [[15, "p1"]])
	var strike: RtSim = RtKit.sim(RtKit.encounter("enc_rt_dummy", far, {"open": {"kind": "strike", "target": "e0"}}), 6)
	ev = _until(strike, 70)
	var sw: Array = RtKit.of(ev, T.SWING).filter(func(x: ActionEvent) -> bool: return x.actor_id == "p0")
	assert_eq(sw.map(func(x: ActionEvent) -> Array: return [x.tick, x.target_id]), [[0, "e0"]],
		"the field strike is the first swing (out of reach); later swings need reach")
	assert_eq(RtKit.of(ev, T.DAMAGE).filter(func(x: ActionEvent) -> bool: return x.actor_id == "p0").size(), 1)
