extends TestCase
## 07 §3.6, §3.11 (R1b-I1) test_r1_rt_timing: GCD 45 / Turbo 34 / slowed 56 / minimum 30, the swing timer, casts and
## the cancel thresholds (25 % run speed = 46 mm per tick, 40 cm), the queue window of 9 ticks, GCD-free actions,
## the drink pause of 15 ticks, the party cooldowns (items 450, SHOW 900), impact ≥ 1 tick, the interrupt lockout
## of 60 ticks and the Partner-Spezial buffer of 45 ticks.

const T := ActionEvent.Type


func _sim(level: int = 6, hero: String = "kai", bal: Dictionary = {}, items: Dictionary = {}) -> RtSim:
	var st: GameState = RtKit.state(level, hero, items)
	var s: RtSetup = RtKit.setup(st, RtKit.dummy_cmd({"ctl": "p0" if hero == "kai" else "p1"}))
	if not bal.is_empty():
		s.balance = RtBalance.from_values(bal)
	var sim: RtSim = RtKit.no_ai(RtSim.new(s, RtKit.data()))
	sim.start()
	sim.unit("e0").auto_on = false
	return sim


func _use(sim: RtSim, u: String, skill: String, target: String = "") -> Array[ActionEvent]:
	assert_eq(sim.submit(RtCommand.ability(sim.tick(), u, skill, target)), "", "accepted: " + skill)
	return sim.step()


func _until(sim: RtSim, ct: int) -> Array[ActionEvent]:
	var out: Array[ActionEvent] = []
	while sim.tick() < ct and not sim.is_finished():
		out.append_array(sim.step())
	return out


func _first(events: Array[ActionEvent], type: ActionEvent.Type) -> ActionEvent:
	var l: Array[ActionEvent] = RtKit.of(events, type)
	return l[0] if not l.is_empty() else null


func test_gcd_and_its_tempo_factors() -> void:
	var sim: RtSim = _sim()
	_use(sim, "p0", "skl_kai_heavy_swing")
	assert_eq([sim.unit("p0").gcd_until, sim.gcd_left("p0"), sim.gcd_total("p0")], [45, 44, 45])
	var fast: RtSim = _sim()
	RtSim.StatusFx.apply(fast, "p1", fast.unit("p0"), "sts_haste", 0, 1000)
	_use(fast, "p0", "skl_kai_heavy_swing")
	assert_eq(fast.gcd_total("p0"), 34, "Turbo: 45 × 750 ‰")
	var slow: RtSim = _sim()
	RtSim.StatusFx.apply(slow, "e0", slow.unit("p0"), "sts_slow", 0, 1000)
	_use(slow, "p0", "skl_kai_heavy_swing")
	assert_eq(slow.gcd_total("p0"), 56, "slowed: 45 × 1250 ‰")
	var floor_sim: RtSim = _sim(6, "kai", {"GCD_TICKS": 35})
	RtSim.StatusFx.apply(floor_sim, "p1", floor_sim.unit("p0"), "sts_haste", 0, 1000)
	_use(floor_sim, "p0", "skl_kai_heavy_swing")
	assert_eq(floor_sim.gcd_total("p0"), 30, "never below GCD_MIN_TICKS")


func test_swing_timer() -> void:
	var sim: RtSim = _sim()
	var ev: Array[ActionEvent] = []
	sim.submit(RtCommand.target(0, "p0", "e0"))
	ev.append_array(_until(sim, 130))
	var swings: Array = RtKit.of(ev, T.SWING).filter(func(e: ActionEvent) -> bool: return e.actor_id == "p0")
	assert_eq(swings.map(func(e: ActionEvent) -> int: return e.tick), [0, 60, 120], "Kai every 2.0 s")
	var hits: Array = RtKit.of(ev, T.DAMAGE).filter(func(e: ActionEvent) -> bool: return e.actor_id == "p0")
	assert_eq(hits.map(func(e: ActionEvent) -> int: return e.tick), [9, 69, 129], "hit 9 ticks after the swing")
	var fast: RtSim = _sim()
	RtSim.StatusFx.apply(fast, "p1", fast.unit("p0"), "sts_haste", 0, 1000)
	fast.submit(RtCommand.target(0, "p0", "e0"))
	var fs: Array = RtKit.of(_until(fast, 100), T.SWING).filter(func(e: ActionEvent) -> bool:
		return e.actor_id == "p0")
	assert_eq(fs.map(func(e: ActionEvent) -> int: return e.tick), [0, 45, 90], "Turbo: swing × 750 ‰")
	var foe: RtSim = _sim()
	foe.unit("e0").auto_on = true
	foe.unit("p1").auto_on = false                    # Mopsula's hits would draw the dummy's threat away
	var es: Array = RtKit.of(_until(foe, 40), T.SWING).filter(func(e: ActionEvent) -> bool:
		return e.actor_id == "e0")
	assert_eq(es.map(func(e: ActionEvent) -> int: return e.tick), [30], "enemies swing from ct 30 on")


func test_swing_waits_while_casting() -> void:
	var sim: RtSim = _sim(6, "mopsula")
	sim.submit(RtCommand.target(0, "p1", "e0"))
	var ev: Array[ActionEvent] = _use(sim, "p1", "skl_mop_noble_flame")
	assert_eq(RtKit.of(ev, T.SWING).filter(func(e: ActionEvent) -> bool: return e.actor_id == "p1").size(), 0,
		"no swing while the cast runs")
	ev.append_array(_until(sim, 50))
	var sw: Array = RtKit.of(ev, T.SWING).filter(func(e: ActionEvent) -> bool: return e.actor_id == "p1")
	assert_eq(sw.map(func(e: ActionEvent) -> int: return e.tick), [45], "the swing comes right after the cast")


func test_cast_and_cancel_thresholds() -> void:
	var sim: RtSim = _sim(6, "mopsula")
	sim.submit(RtCommand.target(0, "p1", "e0"))
	var ev: Array[ActionEvent] = _use(sim, "p1", "skl_mop_noble_flame")
	var cs: ActionEvent = _first(ev, T.CAST_START)
	assert_not_null(cs)
	if cs != null:
		assert_eq([cs.value, cs.success, cs.rt, cs.by_ai], [45, true, {"end": 45, "worthy": 0}, false])
	assert_eq(sim.cast_progress("p1"), Vector2i(1, 45))
	var mop: RtUnit = sim.unit("p1")
	var mp0: int = mop.mp
	var x0: int = mop.x
	assert_eq(sim.submit(RtCommand.move(sim.tick(), "p1", x0, mop.z, 46, 0, 0)), "")
	sim.step()
	assert_false(mop.cast.is_empty(), "46 mm per tick (25 % of the run speed) does not cancel")
	assert_eq(sim.submit(RtCommand.move(sim.tick(), "p1", x0 + 40, mop.z, 0, 0, 0)), "")
	sim.step()
	assert_false(mop.cast.is_empty(), "40 cm from the cast start does not cancel")
	ev = _until(sim, 46)
	var dmg: Array = RtKit.of(ev, T.DAMAGE).filter(func(e: ActionEvent) -> bool: return e.actor_id == "p1")
	assert_true(dmg.size() == 1 and dmg[0].tick == 45 and dmg[0].skill_id == "skl_mop_noble_flame",
		"the effect at the end")
	assert_eq(mop.mp, mp0 - 4 + _regen_between(1, 45), "MP at the cast end (+ time regeneration)")
	# 47 mm per tick cancels
	var s2: RtSim = _sim(6, "mopsula")
	s2.submit(RtCommand.target(0, "p1", "e0"))
	_use(s2, "p1", "skl_mop_noble_flame")
	var m2: RtUnit = s2.unit("p1")
	s2.submit(RtCommand.move(s2.tick(), "p1", m2.x, m2.z, 47, 0, 0))
	var fail: ActionEvent = _first(s2.step(), T.CAST_FAILED)
	assert_true(fail != null and fail.text == "moved", "47 mm per tick cancels")
	assert_eq([m2.mp, s2.cooldown_left("p1", "skl_mop_noble_flame"), s2.gcd_left("p1")], [m2.max_mp(), 0, 43],
		"no MP, no cooldown; the GCD runs on")
	# 41 cm cancels
	var s3: RtSim = _sim(6, "mopsula")
	s3.submit(RtCommand.target(0, "p1", "e0"))
	_use(s3, "p1", "skl_mop_noble_flame")
	s3.step()
	var m3: RtUnit = s3.unit("p1")
	s3.submit(RtCommand.move(s3.tick(), "p1", m3.x + 41, m3.z, 0, 0, 0))
	var fail3: ActionEvent = _first(s3.step(), T.CAST_FAILED)
	assert_true(fail3 != null and fail3.text == "moved", "41 cm cancels")


## MP Mopsula regenerates over time between two ticks (+1 every 45 ticks from ct 0).
func _regen_between(from_ct: int, to_ct: int) -> int:
	var n: int = 0
	for c in range(from_ct, to_ct + 1):
		if c > 0 and c % 45 == 0:
			n += 1
	return n


func test_queue_window() -> void:
	var sim: RtSim = _sim()
	_use(sim, "p0", "skl_kai_heavy_swing")
	_until(sim, 35)
	var refused: ActionEvent = _first(_use(sim, "p0", "skl_kai_heavy_swing"), T.ACTION_REFUSED)
	assert_true(refused != null and refused.text == "gcd", "10 ticks of GCD left: refused")
	var ev: Array[ActionEvent] = _use(sim, "p0", "skl_kai_heavy_swing")
	assert_eq(RtKit.of(ev, T.ACTION_REFUSED).size(), 0, "9 ticks left: buffered")
	assert_eq(str(sim.unit("p0").queued.get("skill", "")), "skl_kai_heavy_swing")
	assert_eq(sim.can_use("p0", "skl_kai_heavy_swing", ""), "", "the HUD sees a usable slot")
	_until(sim, 38)
	_use(sim, "p0", "skl_kai_sweep")
	assert_eq(str(sim.unit("p0").queued.get("skill", "")), "skl_kai_sweep", "a new press replaces the buffer")
	ev = _until(sim, 46)
	var st: Array[ActionEvent] = RtKit.of(ev, T.ACTION_START)
	assert_eq(st.size(), 1)
	if st.size() == 1:
		assert_eq([st[0].tick, st[0].skill_id, st[0].by_ai], [45, "skl_kai_sweep", false], "starts when the GCD ends")
	assert_true(sim.unit("p0").queued.is_empty())


func test_gcd_free_actions() -> void:
	var sim: RtSim = _sim()
	_use(sim, "p0", "skl_kai_heavy_swing")
	var ev: Array[ActionEvent] = _use(sim, "p0", "skl_kai_taunt")
	var st: ActionEvent = _first(ev, T.ACTION_START)
	assert_true(st != null and st.skill_id == "skl_kai_taunt" and st.tick == 1, "taunt during the GCD")
	assert_eq(sim.unit("p0").gcd_until, 45, "and it does not restart the GCD")
	var cast: RtSim = _sim(6, "mopsula")
	cast.submit(RtCommand.target(0, "p1", "e0"))
	_use(cast, "p1", "skl_mop_noble_flame")
	var bark: Array[ActionEvent] = _use(cast, "p1", "skl_mop_thunder_bark")
	assert_eq(_first(bark, T.ACTION_START).skill_id, "skl_mop_thunder_bark", "GCD-free during the own cast")
	assert_eq(str(cast.unit("p1").cast.get("skill", "")), "skl_mop_noble_flame", "the cast goes on")
	var refuse: ActionEvent = _first(_use(cast, "p1", "skl_mop_frost_sneeze"), T.ACTION_REFUSED)
	assert_true(refuse != null and refuse.text == "casting", "a GCD ability with > 9 ticks of cast left")


func test_drink_pause_and_party_cooldowns() -> void:
	var sim: RtSim = _sim(6, "kai", {}, {"itm_bandage": 2})
	var kai: RtUnit = sim.unit("p0")
	kai.hp = 100
	assert_eq(sim.submit(RtCommand.item(0, "p0", "itm_bandage", "")), "")
	var ev: Array[ActionEvent] = sim.step()
	var st: ActionEvent = _first(ev, T.ACTION_START)
	assert_true(st != null and st.command == BattleCommand.Kind.ITEM and st.item_id == "itm_bandage")
	assert_eq([sim.item_cd_left(), sim.item_cd_total(), sim.items_left()], [449, 450, 2])
	assert_eq(sim.cast_progress("p0"), Vector2i(1, 15), "the drink pause shows as the player's bar")
	sim.submit(RtCommand.move(1, "p0", kai.x + 18, kai.z, 180, 0, 0))
	ev = sim.step()
	assert_eq(kai.x, 0, "no moving while drinking")
	assert_eq(RtKit.of(ev, T.POS_CORRECTED).size(), 1)
	assert_eq(sim.can_use("p0", "skl_kai_heavy_swing", ""), "drinking")
	ev = _until(sim, 16)
	var heal: ActionEvent = _first(ev, T.HEAL)
	assert_true(heal != null and heal.tick == 15 and heal.amount == 180, "180 (45 × 4, baked) at the end")
	assert_eq(kai.gcd_until, 0, "items are GCD-free")
	assert_eq(sim.can_use_item("p0", "itm_bandage", ""), "item_cd")
	var show: RtSim = _sim()
	_use(show, "p0", "skl_stunt_kai_suplex", "e0")
	assert_eq([show.cooldown_left("p0", "skl_stunt_kai_suplex"), show.cooldown_total("p0", "skl_stunt_kai_suplex")],
		[899, 900], "SHOW: 30 s for the party")
	assert_eq(show.cooldown_left("p1", "skl_stunt_mop_entrance"), 899, "shared with the partner")
	assert_eq(show.can_use("p1", "skl_stunt_mop_entrance", ""), "cooldown")


func test_instant_effects_land_at_least_one_tick_later() -> void:
	var sim: RtSim = _sim()
	var ev: Array[ActionEvent] = _use(sim, "p0", "skl_kai_taunt")
	assert_eq(RtKit.of(ev, T.STATUS_ADDED).size(), 0, "impact_ms 0: not in the start tick")
	ev = sim.step()
	var added: Array[ActionEvent] = RtKit.of(ev, T.STATUS_ADDED)
	assert_eq(added.map(func(e: ActionEvent) -> String: return e.status_id), ["sts_taunted", "sts_guard"],
		"one tick later: taunted on the enemy, guard on Kai")
	assert_eq(added[0].tick, 1)


## A running enemy cast set up by hand (enemy casts come with the enemy AI in R1b-I3).
static func _hex_cast(e: RtUnit, interruptible: bool) -> Dictionary:
	return {"skill": "skl_e_test_hex", "target": "p0", "targets": ["p0"], "x": e.x, "z": e.z, "start": 0,
		"end": 60, "interruptible": interruptible, "worthy": interruptible, "moving_cancels": false, "channel": false,
		"period": 0, "next_tick": -1, "tele": -1, "kind": "ability", "item": "", "ai": true, "cmd": 1}


func test_interrupt_and_lockout() -> void:
	var sim: RtSim = _sim()
	var e: RtUnit = sim.unit("e0")
	e.cast = _hex_cast(e, true)
	var ev: Array[ActionEvent] = _use(sim, "p0", "skl_kai_leash_trip", "e0")
	ev.append_array(_until(sim, 12))
	var it: ActionEvent = _first(ev, T.CAST_INTERRUPTED)
	assert_not_null(it)
	if it != null:
		assert_eq([it.tick, it.actor_id, it.target_id, it.skill_id, it.by_ai], [9, "p0", "e0", "skl_e_test_hex", false])
	assert_eq(e.lockout_until, 9 + 60, "INTERRUPT_LOCKOUT_TICKS")
	assert_true(e.cast.is_empty())
	assert_eq(sim.tally["interrupts"], 1, "counted for the controlled unit")
	var e2: RtSim = _sim()
	var u2: RtUnit = e2.unit("e0")
	u2.cast = _hex_cast(u2, false)
	_use(e2, "p0", "skl_kai_leash_trip", "e0")
	_until(e2, 12)
	assert_false(u2.cast.is_empty(), "a non-interruptible cast goes on")


func test_partner_special_buffer() -> void:
	var sim: RtSim = _sim(3, "kai")
	assert_eq(sim.partner_special_skill("p1"), "skl_mop_holy_lick")
	assert_eq(sim.partner_special_skill("p0"), "", "only for the AI partner")
	var mop: RtUnit = sim.unit("p1")
	sim.unit("p0").hp -= 100
	mop.gcd_until = 20
	assert_eq(sim.submit(RtCommand.partner_special(0, "p1")), "")
	var ev: Array[ActionEvent] = _until(sim, 22)
	var st: Array = RtKit.of(ev, T.ACTION_START).filter(func(e: ActionEvent) -> bool: return e.actor_id == "p1")
	assert_eq(st.size(), 1, "starts once the partner is free")
	if st.size() == 1:
		assert_eq([st[0].tick, st[0].skill_id, st[0].by_ai, st[0].target_ids], [20, "skl_mop_holy_lick", false,
			PackedStringArray(["p0"])], "the person's order (by_ai false), smart target")
	var late: RtSim = _sim(3, "kai")
	late.unit("p1").gcd_until = 60
	late.submit(RtCommand.partner_special(0, "p1"))
	var ev2: Array[ActionEvent] = _until(late, 61)
	var ref: Array = RtKit.of(ev2, T.ACTION_REFUSED).filter(func(e: ActionEvent) -> bool: return e.actor_id == "p1")
	assert_eq(ref.size(), 1, "the order lapses after 45 ticks")
	if ref.size() == 1:
		assert_eq([ref[0].tick, ref[0].text], [45, "gcd"])
	var broke: RtSim = _sim(3, "kai")
	broke.unit("p1").mp = 0
	broke.submit(RtCommand.partner_special(0, "p1"))
	var r3: ActionEvent = _first(broke.step(), T.ACTION_REFUSED)
	assert_true(r3 != null and r3.text == "mp", "a failed check refuses at once")
	assert_eq(broke.submit(RtCommand.partner_special(1, "p0")), "not_controlled", "the controlled unit has none")


## Out of range the partner walks there first (07 §3.6.13), then starts the order (by_ai false).
func test_partner_special_walks_into_range() -> void:
	var cmd: Dictionary = RtKit.encounter("enc_rt_dummy", [["g", "enc_rt_dummy", [0, -420, 128]]], {"ctl": "p1",
		"party": [{"u": "p0", "p": [0, 440, 0]}, {"u": "p1", "p": [-150, 300, 0]}]})
	var sim: RtSim = RtKit.no_ai(RtSim.new(RtKit.setup(RtKit.state(3, "mopsula"), cmd), RtKit.data()))
	sim.start()
	for u: RtUnit in sim.units():
		u.auto_on = false
	var kai: RtUnit = sim.unit("p0")
	assert_eq(sim.submit(RtCommand.target(0, "p1", "e0")), "")
	assert_eq(sim.submit(RtCommand.partner_special(0, "p0")), "")
	var ev: Array[ActionEvent] = _until(sim, 2)
	assert_eq([kai.x, kai.z], [0, 404], "860 cm > 800 + 40: two steps of 18 cm towards the target …")
	ev.append_array(_until(sim, 10))
	var st: Array = RtKit.of(ev, T.ACTION_START).filter(func(e: ActionEvent) -> bool: return e.actor_id == "p0")
	assert_eq(st.map(func(e: ActionEvent) -> Array: return [e.tick, e.skill_id, e.by_ai]),
		[[2, "skl_kai_leash_trip", false]], "… then the lasso")
	assert_eq(RtKit.of(ev, T.ACTION_REFUSED).size(), 0)
