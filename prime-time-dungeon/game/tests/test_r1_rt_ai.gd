extends TestCase
## 07 §5, §3.9.3 (R1b-I2) test_r1_rt_ai: the rule AI of the AI partner and the autopilot — compile, rule order,
## first_ms / every_ms / once / then, every condition and target (random ones reproducible from the combat stream),
## the presets of 07 §5.4 (heal thresholds, switches), the fixed engine rules (filler reserve, potions only "careful" /
## switch and never the last one, SHOW after AI_SHOW_GRACE_TICKS with by_ai, FINALE never); E25: ai_seen from the own
## stream "rt_ai" (15 + jitter 0–10, 25 % late +45), an autopilot switch shifts no draw, never during an own cast or
## in the last 5 GCD ticks (afterwards yes), 0/0/0 = without E25, ai_seen forgotten at cast end / interrupt / KO;
## dodging with REACT_TICKS 15/12/6 and "missed" 130/130/40 ‰, the attack AI leaves the Putzmittelnebel in time,
## RtGeo.escape_point, the cast abort, zones; the Partner-Spezial holds the rules, keep_cm with the tactic, the
## autopilot, suggest(); the fast rule walk equals a plain reference of 07 §5.3 in whole combats (party and enemies).
## R1b-I3: the enemy rules (rt.rules, slot offset, timers), boss phases with every op (PHASE_CHANGE at the start,
## perfect phases, several thresholds in one tick), enrage, summons (cap, door / near, SUMMON_HP_PM, pop-in, threat),
## random targets (auto_target random_enemy, skill target random_enemy), the staggered thinking (07 §3.15).

const Ability := preload("res://core/rt/rt_ability.gd")
const FixedMath := preload("res://core/stats/fixed_math.gd")
const Damage := preload("res://core/rt/rt_damage.gd")
const StatusFx := preload("res://core/rt/rt_status_fx.gd")
const T := ActionEvent.Type
const K := BattleCommand.Kind
const NO_MISS: Dictionary = {"AI_DODGE_MISS_PM": {"attack": 0, "support": 0, "careful": 0}}


## A started combat against the stationary dummy (2000 HP, its auto-attack off) at (0, −50): Kai at (0, 200), Mopsula
## at (−150, 300); `ctl` is controlled, the other one is the AI partner. `rules` (when given) replaces the AI partner's
## rules (compiled with the prefix "t"); `bal` overrides balance values.
func _sim(ctl: String = "p1", level: int = 6, rules: Array = [], bal: Dictionary = {}, seed: int = RtKit.SEED,
		cmd: Dictionary = {}, items: Dictionary = {}) -> RtSim:
	var st: GameState = RtKit.state(level, "kai" if ctl == "p0" else "mopsula", items)
	var s: RtSetup = RtKit.setup(st, cmd if not cmd.is_empty() else RtKit.dummy_cmd({"ctl": ctl}), seed)
	if not bal.is_empty():
		s.balance = RtBalance.from_values(bal)
	var sim: RtSim = RtSim.new(s, RtKit.data())
	sim.start()
	if not rules.is_empty():
		sim.unit("p0" if ctl == "p1" else "p1").rules = RtRules.compile(rules, "t")
	for u: RtUnit in sim.units():
		if u.side == Combatant.Side.ENEMY:
			u.auto_on = false
	return sim


func _until(sim: RtSim, ct: int) -> Array[ActionEvent]:
	var out: Array[ActionEvent] = []
	while sim.tick() < ct and not sim.is_finished():
		out.append_array(sim.step())
	return out


## [tick, skill or item id] of the AI's ACTION_STARTs of `uid`.
static func _ai_starts(events: Array[ActionEvent], uid: String) -> Array:
	var out: Array = []
	for e: ActionEvent in events:
		if e.type == T.ACTION_START and e.actor_id == uid and e.by_ai:
			out.append([e.tick, e.item_id if e.item_id != "" else e.skill_id])
	return out


## The first tick ≥ ct at which the unit with list index `i` thinks (staggered AI thinking, 07 §3.15: p0 = 0,
## p1 = 1, e0 = 2 in the dummy combats).
static func _think(i: int, ct: int) -> int:
	return ct + posmod(-(ct + i), RtSim.AI_THINK_TICKS)


## The draw `n` of the AI stream of `seed` (07 §3.9.3).
static func _ai_draw(seed: int, n: int) -> RandomNumberGenerator:
	return SeedUtil.make_rng(SeedUtil.derive(seed, "rt_ai", n))


## The worthy test spell of the dummy (skl_e_test_hex: 2 s cast, interruptible, interrupt-worthy) on `target`.
static func _hex(sim: RtSim, target: String = "p1") -> void:
	assert(Ability.use_ability(sim, sim.unit("e0"), "skl_e_test_hex", target, true) == "")


## A hostile circle telegraph on the party (07 §6.3) at (x, z) with radius r, striking `impact_in` ticks from now.
static func _tele(sim: RtSim, x: int, z: int, r: int, impact_in: int, zone: bool = false) -> RtTelegraph:
	var t: RtTelegraph = RtTelegraph.new()
	t.source_id = "e0"
	t.skill_id = "skl_e_test_slam"
	t.side = Combatant.Side.PARTY
	t.shape = RtTelegraph.Shape.CIRCLE
	t.x = x
	t.z = z
	t.r = r
	t.start = sim.tick()
	t.impact_at = -1 if zone else sim.tick() + impact_in
	t.is_zone = zone
	t.ends_at = sim.tick() + impact_in if zone else -1
	sim.add_telegraph(t)
	return t


# --- compile, order, timers ------------------------------------------------------------------------------------------

func test_compile() -> void:
	var raw: Array = [{"skill": "skl_x", "target": "assist", "cond": {"self_hp_below_pm": 350.0,
		"enemies_in_radius": {"r_cm": 350.0, "min": 2.0}}, "first_ms": 1000.0, "every_ms": 2500.0, "once": true,
		"filler": true, "then": {"skill": "skl_y", "delay_ms": 1500.0}}, "no rule", {"item": "heal", "target": "self"}]
	var c: Array[Dictionary] = RtRules.compile(raw, "attack")
	assert_eq(c.size(), 2, "entries that are no object are left out")
	assert_eq(c[0], {"key": "attack:0", "skill": "skl_x", "item": "", "target": "assist", "cond": {"self_hp_below_pm": 350,
		"enemies_in_radius": {"r_cm": 350, "min": 2}}, "first": 30, "every": 75, "once": true, "filler": true,
		"then": {"skill": "skl_y", "delay": 45}}, "ms → ticks, keys \"<preset>:<index>\"")
	assert_eq(typeof(c[0]["cond"]["self_hp_below_pm"]), TYPE_INT, "integral numbers as int")
	assert_eq(c[1], {"key": "attack:2", "skill": "", "item": "heal", "target": "self", "cond": {}, "first": 0,
		"every": 0, "once": false, "filler": false, "then": {}}, "… and their index stays taken")
	var prt: Dictionary = RtKit.data().party_member("kai").rt
	var att: Array[Dictionary] = RtRules.preset_rules(prt, "attack")
	assert_eq([att.size(), att[1]["key"], att[1]["skill"], att[7]["filler"]], [8, "attack:1", "skl_kai_leash_trip", true],
		"07 §5.4: Kai's attack list")
	assert_eq(RtRules.preset_rules(prt, "nope").size(), 0)
	var sim: RtSim = _sim()
	assert_eq(sim.unit("p0").rules, att, "make_rt_setup compiles the AI partner's tactic …")
	assert_eq(sim.unit("p1").rules, RtRules.preset_rules(RtKit.data().party_member("mopsula").rt, "support"),
		"… and the controlled unit's own (its default_preset; the autopilot plays it)")


func test_first_usable_rule_fires_in_list_order() -> void:
	var sim: RtSim = _sim("p1", 6, [
		{"skill": "skl_kai_taunt", "target": "self", "cond": {"self_hp_below_pm": 100}},
		{"skill": "skl_kai_sweep", "target": "self", "cond": {"enemies_in_radius": {"r_cm": 350, "min": 2}}},
		{"skill": "skl_kai_heavy_swing", "target": "assist"},
		{"skill": "skl_kai_leash_trip", "target": "assist"}])
	var ev: Array[ActionEvent] = _until(sim, 50)
	assert_eq(_ai_starts(ev, "p0"), [[0, "skl_kai_heavy_swing"], [3, "skl_kai_leash_trip"], [45, "skl_kai_heavy_swing"]],
		"conditions false → skipped; the first usable rule fires; the GCD-free lasso at its next thinking tick")
	var st: Array[ActionEvent] = RtKit.of(ev, T.ACTION_START)
	assert_true(st.all(func(e: ActionEvent) -> bool: return e.by_ai and e.command == K.SKILL), "by_ai on every start")
	assert_eq(int(sim.tally["party_turns"]), 0, "party_turns counts the person's actions only")


func test_first_every_once_then() -> void:
	var every: RtSim = _sim("p1", 6, [{"skill": "skl_kai_heavy_swing", "target": "assist", "first_ms": 1000,
		"every_ms": 2500}])
	assert_eq(_ai_starts(_until(every, 200), "p0"), [[30, "skl_kai_heavy_swing"], [105, "skl_kai_heavy_swing"],
		[180, "skl_kai_heavy_swing"]], "first_ms 1000 → ct 30, then every 75 ticks (the GCD alone would allow 45)")
	assert_eq(int(every.unit("p0").rule_ready["t:0"]), 255)
	var once: RtSim = _sim("p1", 6, [{"skill": "skl_kai_heavy_swing", "target": "assist", "once": true}])
	assert_eq(_ai_starts(_until(once, 200), "p0"), [[0, "skl_kai_heavy_swing"]], "once: never again")
	assert_eq(int(once.unit("p0").rule_ready["t:0"]), RtRules.NEVER)
	var then: RtSim = _sim("p1", 6, [{"skill": "skl_kai_heavy_swing", "target": "assist", "once": true,
		"then": {"skill": "skl_kai_leash_trip", "delay_ms": 500}}])
	var ev: Array[ActionEvent] = _until(then, 100)
	assert_eq(_ai_starts(ev, "p0"), [[0, "skl_kai_heavy_swing"], [15, "skl_kai_leash_trip"]],
		"then: the follow-up after its delay, without conditions")
	var leash: Array = RtKit.of(ev, T.ACTION_START).filter(func(e: ActionEvent) -> bool:
		return e.skill_id == "skl_kai_leash_trip")
	assert_eq(Array(leash[0].target_ids), ["e0"], "on the rule's target")
	assert_eq(then.unit("p0").follow_up, {})
	var busy: RtSim = _sim("p1", 6, [{"skill": "skl_kai_heavy_swing", "target": "assist", "once": true,
		"then": {"skill": "skl_kai_heavy_swing", "delay_ms": 100}}])
	assert_eq(_ai_starts(_until(busy, 100), "p0"), [[0, "skl_kai_heavy_swing"], [45, "skl_kai_heavy_swing"]],
		"a busy follow-up (GCD) waits until it is usable")


# --- conditions and targets ------------------------------------------------------------------------------------------

func test_conditions() -> void:
	var sim: RtSim = _sim("p1", 6, [], {}, RtKit.SEED, RtKit.encounter("enc_rt_rats",
		[["g", "enc_rt_rats", [0, -100, 128]]], {"ctl": "p1"}))
	var kai: RtUnit = sim.unit("p0")
	var mop: RtUnit = sim.unit("p1")
	var r0: RtUnit = sim.unit("e0")
	var r1: RtUnit = sim.unit("e1")
	_until(sim, 40)
	kai.x = 0
	kai.z = 0
	r0.x = 0
	r0.z = -300
	r1.x = 200
	r1.z = 0
	kai.hp = kai.max_hp() * 3 / 10
	var c: Callable = func(cond: Dictionary, target: String) -> bool: return RtRules.eval_cond(sim, kai, cond, target)
	assert_true(c.call({}, ""), "no condition: true")
	assert_eq([c.call({"self_hp_below_pm": 350}, ""), c.call({"self_hp_below_pm": 300}, ""),
		c.call({"self_hp_above_pm": 250}, ""), c.call({"self_hp_above_pm": 300}, "")],
		[true, kai.hp * 1000 < 300 * kai.max_hp(), true, false], "own HP share, ‰")
	assert_eq([c.call({"ally_hp_below_pm": 350}, ""), c.call({"allies_below_pm": {"pm": 350, "min": 2}}, ""),
		c.call({"allies_below_pm": {"pm": 1001, "min": 2}}, "")], [true, false, true], "allies incl. the unit itself")
	assert_eq([c.call({"ally_ko": false}, ""), c.call({"ally_ko": true}, "")], [true, false])
	r0.hp = r0.max_hp() / 4
	assert_eq([c.call({"target_hp_below_pm": 300}, "e0"), c.call({"target_hp_above_pm": 300}, "e0"),
		c.call({"target_hp_below_pm": 300}, "")], [true, false, false], "the rule target's HP share (none → false)")
	StatusFx.apply(sim, "p1", r0, "sts_slow", 0, 1000)
	assert_eq([c.call({"target_no_status": "sts_slow"}, "e0"), c.call({"target_no_status": "sts_slow"}, "e1"),
		c.call({"self_no_status": "sts_slow"}, "")], [false, true, true])
	kai.mp = 5
	assert_eq([c.call({"self_mp_min": 5}, ""), c.call({"self_mp_min": 6}, ""),
		c.call({"self_mp_above_pm": 5000 / kai.max_mp() - 1}, ""), c.call({"self_mp_above_pm": 999}, "")],
		[true, false, true, false])
	assert_eq([c.call({"enemies_in_radius": {"r_cm": 270, "min": 2}}, ""), c.call({"enemies_in_radius": {"r_cm": 269,
		"min": 2}}, ""), c.call({"enemies_in_radius": {"r_cm": 170, "min": 1}}, "")], [true, false, true],
		"enemies within r + their radius (30): 300 ≤ 270 + 30")
	r0.target_id = "p1"
	r1.target_id = "p0"
	assert_true(c.call({"enemy_on_ally": true}, ""), "a rat attacks Mopsula")
	r0.fixate_id = "p0"
	r0.fixate_until = sim.tick() + 10
	assert_true(c.call({"enemy_on_ally": false}, ""), "… not while it is fixed on Kai")
	assert_eq([RtRules.eval_cond(sim, r0, {"adds_below": 2}, ""), RtRules.eval_cond(sim, r0, {"adds_below": 1}, "")],
		[true, false], "living allies besides itself < value")
	assert_eq([c.call({"phase": 1}, ""), c.call({"phase": 2}, "")], [true, false], "phase from 1")
	assert_eq([c.call({"after_ms": 1333}, ""), c.call({"after_ms": 1334}, "")], [true, false], "ct 40 = 1333 ms")
	assert_eq([c.call({"boss_fight": false}, ""), c.call({"boss_fight": true}, "")], [true, false])
	assert_eq([c.call({"toggle": "interrupt"}, ""), c.call({"toggle": "potions"}, "")], [true, false], "the switches")
	assert_false(c.call({"no_such_condition": 1}, ""), "unknown keys are false")
	assert_false(c.call({"toggle": "interrupt", "self_hp_below_pm": 100}, ""), "all must hold")


func test_cast_conditions_see_like_a_person_or_from_ai_seen() -> void:
	var sim: RtSim = _sim("p1", 6, [], {"AI_INTERRUPT_LATE_PM": 0})
	var kai: RtUnit = sim.unit("p0")
	var mop: RtUnit = sim.unit("p1")
	_until(sim, 5)
	assert_false(RtRules.eval_cond(sim, kai, {"caster_within_cm": 600}, ""))
	_hex(sim)
	var seen: int = int(kai.ai_seen["e0"])
	assert_between(seen, 5 + 15, 5 + 15 + 10)
	assert_eq([RtRules.eval_cond(sim, kai, {"caster_within_cm": 600}, ""),
		RtRules.eval_cond(sim, kai, {"target_casting": true}, "e0"),
		RtRules.eval_cond(sim, mop, {"caster_within_cm": 600}, ""), RtRules.eval_cond(sim, mop, {"target_casting": true},
		"e0")], [false, false, true, true], "before ai_seen the AI sees nothing; the person at once")
	assert_true(RtRules.eval_cond(sim, kai, {"target_casting": false}, "e0"))
	_until(sim, seen)
	assert_eq([RtRules.eval_cond(sim, kai, {"caster_within_cm": 600}, ""), RtRules.eval_cond(sim, kai,
		{"caster_within_cm": 200}, "")], [true, false], "from ai_seen on, within the radius (+ its radius 40)")


func test_targets() -> void:
	var sim: RtSim = _sim("p1", 7, [], {}, RtKit.SEED, RtKit.encounter("enc_rt_dummies",
		[["g", "enc_rt_dummies", [0, -100, 128]]], {"ctl": "p1"}))
	_until(sim, 40)
	var kai: RtUnit = sim.unit("p0")
	var mop: RtUnit = sim.unit("p1")
	var e: Array = [sim.unit("e0"), sim.unit("e1"), sim.unit("e2")]
	kai.x = 0
	kai.z = 200
	for i in 3:
		(e[i] as RtUnit).x = [0, -300, 300][i]
		(e[i] as RtUnit).z = [-100, -100, 100][i]
	var tg: Callable = func(u: RtUnit, target: String) -> String:
		var res: Dictionary = RtRules.rule_target(sim, u, target, sim.skill_def("skl_kai_leash_trip"))
		return str(res["id"]) if bool(res["ok"]) else "-"
	assert_eq([tg.call(kai, "none"), tg.call(kai, "self"), tg.call(kai, "controlled")], ["", "p0", "p1"])
	mop.target_id = "e2"
	kai.target_id = "e1"
	assert_eq([tg.call(kai, "assist"), tg.call(kai, "current")], ["e2", "e1"], "assist: the controlled unit's target")
	mop.target_id = ""
	assert_eq(tg.call(kai, "assist"), "e1", "… else the own")
	kai.target_id = ""
	assert_eq(tg.call(kai, "assist"), "e0", "… else the nearest (300 vs 361 / 316)")
	assert_eq([tg.call(kai, "nearest_enemy"), tg.call(kai, "farthest_enemy")], ["e0", "e1"])
	(e[2] as RtUnit).hp = (e[2] as RtUnit).max_hp() / 2
	(e[1] as RtUnit).hp = (e[1] as RtUnit).max_hp() / 2
	assert_eq(tg.call(kai, "lowest_hp_pct_enemy"), "e1", "ties: unit order")
	kai.hp = kai.max_hp() / 2
	mop.hp = mop.max_hp() / 2
	assert_eq(tg.call(kai, "lowest_hp_pct_ally"), mop.id if mop.hp * kai.max_hp() <= kai.hp * mop.max_hp() else "p0",
		"lowest share; ties: the controlled figure first")
	mop.hp = mop.max_hp()
	assert_eq(tg.call(kai, "lowest_hp_pct_ally"), "p0")
	assert_eq(tg.call(kai, "ko_ally"), "-", "nobody KO'd")
	assert_eq(tg.call(sim.unit("e0"), "threat_top"), "p0", "enemies: the threat target (Kai × 1.5)")
	assert_eq(tg.call(kai, "caster"), "-", "no worthy cast")
	assert_eq(tg.call(kai, "no_such_target"), "-")


func test_caster_target_shortest_rest_in_range() -> void:
	var sim: RtSim = _sim("p1", 7, [], {"AI_INTERRUPT_REACT_TICKS": 0, "AI_INTERRUPT_JITTER_TICKS": 0,
		"AI_INTERRUPT_LATE_PM": 0}, RtKit.SEED, RtKit.encounter("enc_rt_dummies", [["g", "enc_rt_dummies",
		[0, -100, 128]]], {"ctl": "p1"}))
	_until(sim, 40)
	var kai: RtUnit = sim.unit("p0")
	kai.rules = []
	kai.x = 0
	kai.z = 200
	for i in 3:
		sim.unit("e%d" % i).x = [0, -300, 300][i]
		sim.unit("e%d" % i).z = [-100, -100, 100][i]
	assert(Ability.use_ability(sim, sim.unit("e2"), "skl_e_test_hex", "p0", true) == "")
	sim.step()
	assert(Ability.use_ability(sim, sim.unit("e1"), "skl_e_test_hex", "p0", true) == "")
	var best: Dictionary = RtRules.rule_target(sim, kai, "caster", sim.skill_def("skl_kai_leash_trip"))
	assert_eq(best["id"], "e2", "the shortest remaining cast first (e2 ends at 100, e1 at 101)")
	var near: Dictionary = RtRules.rule_target(sim, kai, "caster", sim.skill_def("skl_kai_heavy_swing"))
	assert_false(bool(near["ok"]), "only casters within the skill's range (250 + 40)")


func test_random_target_is_drawn_from_the_combat_stream() -> void:
	var picks: Array = []
	for seed: int in [3, 4, 5, 6, 7, 8]:
		var sim: RtSim = _sim("p1", 6, [{"skill": "skl_kai_leash_trip", "target": "random_enemy"}], {}, seed,
			RtKit.encounter("enc_rt_dummies", [["g", "enc_rt_dummies", [0, -100, 128]]], {"ctl": "p1"}))
		var pick: Dictionary = RtRules.choose(sim, sim.unit("p0"))
		assert_eq(pick.get("random", []), ["e0", "e1", "e2"], "the candidates in range (pure: no draw yet)")
		var n: int = int(sim.snapshot()["rng_n"])
		var want: String = "e%d" % SeedUtil.make_rng(SeedUtil.derive(seed, "rt", n + 1)).randi_range(0, 2)
		var ev: Array[ActionEvent] = sim.step()
		var st: Array = RtKit.of(ev, T.ACTION_START).filter(func(x: ActionEvent) -> bool: return x.actor_id == "p0")
		assert_eq(Array(st[0].target_ids), [want], "seed %d: the draw rng_n + 1 of the combat stream" % seed)
		picks.append(want)
		var twin: RtSim = _sim("p1", 6, [{"skill": "skl_kai_leash_trip", "target": "random_enemy"}], {}, seed,
			RtKit.encounter("enc_rt_dummies", [["g", "enc_rt_dummies", [0, -100, 128]]], {"ctl": "p1"}))
		var tw: Array = RtKit.of(twin.step(), T.ACTION_START).filter(func(x: ActionEvent) -> bool:
			return x.actor_id == "p0")
		assert_eq(Array(tw[0].target_ids), [want], "reproducible")
	assert_gt(picks.reduce(func(acc: Dictionary, x: String) -> Dictionary:
		acc[x] = true
		return acc, {}).size(), 1, "and not always the same")


# --- presets, switches, fixed engine rules ---------------------------------------------------------------------------

func test_preset_heal_thresholds() -> void:
	var want: Dictionary = {"support": [true, true, false], "attack": [true, false, false],
		"careful": [true, true, true]}
	for preset: String in want.keys():
		var got: Array = []
		for pm: int in [300, 500, 700]:
			var sim: RtSim = _sim("p0")
			var kai: RtUnit = sim.unit("p0")
			kai.hp = kai.max_hp() * pm / 1000
			sim.submit(RtCommand.preset(0, "p1", preset, {}))
			var st: Array = _ai_starts(_until(sim, 3), "p1")
			got.append(st.size() == 1 and st[0][1] == "skl_mop_holy_lick")
		assert_eq(got, want[preset], "Mopsula %s heals Kai at 30 / 50 / 70 %% (thresholds 600 / 350 / 750 ‰)" % preset)


func test_switches() -> void:
	for tog: bool in [true, false]:
		var sim: RtSim = _sim("p1", 6, [], {"AI_INTERRUPT_REACT_TICKS": 0, "AI_INTERRUPT_JITTER_TICKS": 0,
			"AI_INTERRUPT_LATE_PM": 0})
		sim.submit(RtCommand.preset(0, "p0", "attack", {"interrupt": tog, "show": false}))
		_until(sim, 5)
		_hex(sim)
		var ev: Array[ActionEvent] = _until(sim, 160)
		var st: Array = _ai_starts(ev, "p0")
		assert_eq(st.has([_think(0, 5), "skl_kai_leash_trip"]), tog, "interrupt %s: the lasso rule on the caster" % tog)
		assert_eq(RtKit.of(ev, T.CAST_INTERRUPTED).size(), 1 if tog else 0, "… and the interruption")
		assert_true(st.all(func(x: Array) -> bool: return x[1] != "skl_stunt_kai_suplex"), "show off: no SHOW")


func test_filler_keeps_the_interrupter_mp() -> void:
	var mp_want: Dictionary = {4: false, 5: true}
	for mp: int in mp_want.keys():
		var sim: RtSim = _sim("p1", 6, [{"skill": "skl_kai_heavy_swing", "target": "assist", "filler": true}])
		var kai: RtUnit = sim.unit("p0")
		assert_eq(sim.interrupter_mp(kai), 3, "Kai's interrupter: the lasso, 3 MP")
		kai.mp = mp
		assert_eq(_ai_starts(_until(sim, 1), "p0").size() == 1, mp_want[mp], "MP %d − 2 ≥ 3?" % mp)
	var off: RtSim = _sim("p1", 6, [{"skill": "skl_kai_heavy_swing", "target": "assist", "filler": true}])
	off.unit("p0").mp = 4
	off.unit("p0").toggles["interrupt"] = false
	assert_eq(_ai_starts(_until(off, 1), "p0").size(), 1, "switch interrupt off: no reserve")
	var heal: RtSim = _sim("p0")
	var mop: RtUnit = heal.unit("p1")
	assert_eq(heal.interrupter_mp(mop), 5, "Mopsula's interrupter: Donnerbellen, 5 MP")
	assert_eq(_sim("p0", 2).interrupter_mp(_sim("p0", 2).unit("p1")), 0, "level 2: no interrupter yet")
	mop.mp = 5
	heal.unit("p0").hp = heal.unit("p0").max_hp() / 2
	assert_eq(_ai_starts(_until(heal, 3), "p1"), [[2, "skl_mop_holy_lick"]], "a heal is no filler: it may use the reserve")


func test_potions_only_careful_or_switch_never_the_last() -> void:
	var low: Callable = func(sim: RtSim, pm: int) -> void:
		var kai: RtUnit = sim.unit("p0")
		kai.hp = kai.max_hp() * pm / 1000
	var off: RtSim = _sim("p1", 6, [], {}, RtKit.SEED, {}, {"itm_brutzel_burger": 2})
	low.call(off, 300)
	assert_eq(_ai_starts(_until(off, 3), "p0").filter(func(x: Array) -> bool: return str(x[1]).begins_with("itm_")), [],
		"attack without the switch: no potion")
	var on: RtSim = _sim("p1", 6, [], {}, RtKit.SEED, {}, {"itm_brutzel_burger": 2})
	low.call(on, 300)
	on.submit(RtCommand.preset(0, "p0", "attack", {"potions": true}))
	var ev: Array[ActionEvent] = _until(on, 3)
	var items: Array = RtKit.of(ev, T.ACTION_START).filter(func(x: ActionEvent) -> bool: return x.item_id != "")
	assert_true(items.size() == 1 and items[0].by_ai and items[0].command == K.ITEM and items[0].tick == 0,
		"with the switch: below 35 % at once (by_ai, ITEM)")
	assert_eq(items[0].item_id, "itm_brutzel_burger", "the smallest heal item covering the missing HP (potion key)")
	var careful: RtSim = _sim("p1", 6, [], {}, RtKit.SEED, {}, {"itm_brutzel_burger": 2})
	low.call(careful, 450)
	careful.submit(RtCommand.preset(0, "p0", "careful", {}))
	assert_eq(RtKit.of(_until(careful, 3), T.ACTION_START).filter(func(x: ActionEvent) -> bool:
		return x.item_id != "").size(), 1, "\"careful\": always, below 50 %")
	var last: RtSim = _sim("p1", 6)
	last.items = {"itm_bandage": 1}
	low.call(last, 100)
	last.submit(RtCommand.preset(0, "p0", "careful", {}))
	assert_eq(RtKit.of(_until(last, 3), T.ACTION_START).filter(func(x: ActionEvent) -> bool:
		return x.item_id != "").size(), 0, "never the last heal item")
	var two: RtSim = _sim("p1", 6)
	two.items = {"itm_bandage": 1, "itm_brutzel_burger": 1}
	low.call(two, 100)
	two.submit(RtCommand.preset(0, "p0", "careful", {}))
	var used: Array = RtKit.of(_until(two, 3), T.ACTION_START).filter(func(x: ActionEvent) -> bool:
		return x.item_id != "")
	assert_eq(used.size(), 1, "two of the kind: one")
	_until(two, 470)
	low.call(two, 100)
	assert_eq(RtKit.of(_until(two, 480), T.ACTION_START).filter(func(x: ActionEvent) -> bool:
		return x.item_id != "").size(), 0, "… then the last one stays (item cooldown 450 over)")
	assert_eq(two.items.values().reduce(func(a: int, b: int) -> int: return a + b, 0), 1)


func test_ai_show_after_grace_with_by_ai() -> void:
	var sim: RtSim = _sim("p0", 6, [{"skill": "skl_stunt_mop_entrance", "target": "self"}])
	var ev: Array[ActionEvent] = _until(sim, 200)
	var first: int = _think(1, 150)
	assert_eq(_ai_starts(ev, "p1"), [[first, "skl_stunt_mop_entrance"]],
		"SHOW ready since ct 0: the AI waits 150 ticks (then its next thinking tick)")
	var sr: Array[ActionEvent] = RtKit.of(ev, T.STUNT_RESULT)
	assert_true(sr.size() == 1 and sr[0].by_ai and sr[0].actor_id == "p1" and sr[0].tick == first + 30,
		"STUNT_RESULT by_ai at the cast end")
	assert_eq(sim.show_ready_at(), first + 30 + 900, "the party SHOW cooldown starts at the cast end")
	ev = _until(sim, 1300)
	assert_eq(_ai_starts(ev, "p1"), [[_think(1, first + 30 + 900 + 150), "skl_stunt_mop_entrance"]],
		"next: ready at the cooldown end, + 150")
	var after: RtSim = _sim("p0", 6, [{"skill": "skl_stunt_mop_entrance", "target": "self"}])
	after.submit(RtCommand.ability(0, "p0", "skl_stunt_kai_suplex", "e0"))
	var ev2: Array[ActionEvent] = _until(after, 1100)
	assert_eq(_ai_starts(ev2, "p1"), [[_think(1, 1050), "skl_stunt_mop_entrance"]], "after the person's SHOW: 900 + 150")


func test_finale_never() -> void:
	var sim: RtSim = _sim("p1", 6, [{"skill": "skl_kai_prime_finisher", "target": "assist"},
		{"skill": "skl_kai_heavy_swing", "target": "assist"}])
	var d: RtUnit = sim.unit("e0")
	d.hp = d.max_hp() / 10
	sim.unit("p0").target_id = "e0"
	assert_eq(sim.can_use("p0", "skl_kai_prime_finisher", "e0"), "", "usable — for the person")
	var st: Array = _ai_starts(_until(sim, 60), "p0")
	assert_true(st.size() > 0 and st.all(func(x: Array) -> bool: return x[1] == "skl_kai_heavy_swing"), "the AI never")
	var kai_ctl: RtSim = _sim("p0", 6)
	kai_ctl.unit("e0").hp = kai_ctl.unit("e0").max_hp() / 10
	kai_ctl.unit("p0").target_id = "e0"
	assert_eq(RtRules.suggest(kai_ctl, kai_ctl.unit("p0"), RtRules.compile([{"skill": "skl_kai_prime_finisher",
		"target": "current"}], "a")), "", "nor the assist")


# --- E25: the AI interrupts like a person ----------------------------------------------------------------------------

## At CAST_START of a worthy cast every living party unit draws (slot order) jitter, then "late", from "rt_ai".
func test_ai_seen_draws_from_the_own_stream() -> void:
	var late_n: int = 0
	var jitters: Dictionary = {}
	for seed in range(1, 101):
		var sim: RtSim = _sim("p1", 6, [], {}, seed)
		_until(sim, 5)
		var snap: Dictionary = sim.snapshot()
		var n: int = int(snap["ai_rng_n"])
		_hex(sim)
		var want: Array = []
		for k in 2:
			var j: int = _ai_draw(seed, n + 1 + 2 * k).randi_range(0, 10)
			var late: bool = FixedMath.roll_bp(_ai_draw(seed, n + 2 + 2 * k), 2500)
			want.append(5 + 15 + j + (45 if late else 0))
			late_n += 1 if late else 0
			jitters[j] = true
		assert_eq([sim.unit("p0").ai_seen["e0"], sim.unit("p1").ai_seen["e0"]], want, "seed %d: start + 15 + j (+ 45)" %
			seed)
		var after: Dictionary = sim.snapshot()
		assert_eq([int(after["ai_rng_n"]), int(after["rng_n"])], [n + 4, int(snap["rng_n"])],
			"two AI draws per living party unit, no combat draw")
	assert_between(late_n, 25, 75, "≈ 25 % of 200 late")
	assert_eq(jitters.size(), 11, "jitter 0 … 10")


func test_autopilot_switch_shifts_no_draw() -> void:
	var a: RtSim = _sim("p1", 6, [], {}, 11)
	var b: RtSim = _sim("p1", 6, [], {}, 11)
	_until(a, 5)
	_until(b, 5)
	Ability.autopilot(b, b.unit("p1"), true)
	assert_eq(b.unit("p1").driver, RtUnit.Driver.AUTOPILOT)
	_hex(a)
	_hex(b)
	assert_eq([a.unit("p0").ai_seen, a.unit("p1").ai_seen], [b.unit("p0").ai_seen, b.unit("p1").ai_seen],
		"the person's unit draws as well — the same values whoever steers it")
	assert_eq([a.snapshot()["rng_n"], a.snapshot()["ai_rng_n"]], [b.snapshot()["rng_n"], b.snapshot()["ai_rng_n"]])


func test_interrupt_from_ai_seen_late_never() -> void:
	var cases: Dictionary = {"on_time": 0, "late": 0}
	for seed in range(1, 41):
		var sim: RtSim = _sim("p1", 6, [{"skill": "skl_kai_leash_trip", "target": "caster", "cond": {"toggle":
			"interrupt"}}], {}, seed)
		_until(sim, 5)
		_hex(sim)
		var seen: int = int(sim.unit("p0").ai_seen["e0"])
		var ev: Array[ActionEvent] = _until(sim, 80)
		var cut: Array[ActionEvent] = RtKit.of(ev, T.CAST_INTERRUPTED)
		var at: int = _think(0, seen)
		if at < 65:
			cases["on_time"] += 1
			assert_eq(_ai_starts(ev, "p0"), [[at, "skl_kai_leash_trip"]],
				"seed %d: the lasso at ai_seen (its next thinking tick)" % seed)
			assert_true(cut.size() == 1 and cut[0].tick == at + 9 and cut[0].actor_id == "p0" and cut[0].by_ai,
				"… its hit interrupts 9 ticks later")
		else:
			cases["late"] += 1
			assert_eq([_ai_starts(ev, "p0"), cut.size()], [[], 0], "seed %d: late (%d ≥ the cast end 65): never" % [seed,
				seen])
	assert_true(int(cases["on_time"]) > 0 and int(cases["late"]) > 0, str(cases))


func test_gcd_tail_waits_then_acts() -> void:
	for gap: int in [3, 5, 6, 20]:
		var sim: RtSim = _sim("p1", 6, [{"skill": "skl_kai_leash_trip", "target": "caster"}], {"AI_INTERRUPT_LATE_PM": 0},
			9)
		_until(sim, 5)
		_hex(sim)
		var kai: RtUnit = sim.unit("p0")
		var seen: int = int(kai.ai_seen["e0"])
		_until(sim, seen)
		kai.gcd_until = seen + gap
		kai.gcd_len = 45
		var want: int = _think(0, seen + gap if gap <= 5 else seen)
		assert_eq(_ai_starts(_until(sim, 70), "p0"), [[want, "skl_kai_leash_trip"]],
			"GCD %d ticks left at ai_seen: %s" % [gap, "waits for its end" if gap <= 5 else "at once"])


func test_no_interrupt_during_an_own_cast() -> void:
	var sim: RtSim = _sim("p0", 6, [{"skill": "skl_mop_thunder_bark", "target": "self", "cond": {"toggle": "interrupt",
		"caster_within_cm": 600}}, {"skill": "skl_mop_noble_flame", "target": "assist"}],
		{"AI_INTERRUPT_LATE_PM": 0, "AI_INTERRUPT_JITTER_TICKS": 0})
	_until(sim, 5)
	assert_eq(sim.unit("p1").cast.get("skill", ""), "skl_mop_noble_flame", "casting 2 … 47")
	_hex(sim, "p0")
	assert_eq(sim.unit("p1").ai_seen["e0"], 20)
	var ev: Array[ActionEvent] = _until(sim, 70)
	var barks: Array = _ai_starts(ev, "p1").filter(func(x: Array) -> bool: return x[1] == "skl_mop_thunder_bark")
	assert_eq(barks, [[47, "skl_mop_thunder_bark"]], "seen at 20, free at 47 (the own cast is never broken off)")
	var cut: Array[ActionEvent] = RtKit.of(ev, T.CAST_INTERRUPTED)
	assert_true(cut.size() == 1 and cut[0].tick == 48 and cut[0].actor_id == "p1")


func test_zero_reaction_is_without_e25() -> void:
	var sim: RtSim = _sim("p1", 6, [{"skill": "skl_kai_leash_trip", "target": "caster"}],
		{"AI_INTERRUPT_REACT_TICKS": 0, "AI_INTERRUPT_JITTER_TICKS": 0, "AI_INTERRUPT_LATE_PM": 0})
	_until(sim, 5)
	_hex(sim)
	assert_eq([sim.unit("p0").ai_seen["e0"], sim.unit("p1").ai_seen["e0"]], [5, 5])
	assert_eq(_ai_starts(_until(sim, 30), "p0"), [[_think(0, 5), "skl_kai_leash_trip"]],
		"0/0/0: the first (thinking) tick it can act")


func test_ai_seen_is_forgotten() -> void:
	var ended: RtSim = _sim("p1", 6, [{"skill": "skl_kai_heavy_swing", "target": "assist"}],
		{"AI_INTERRUPT_LATE_PM": 1000})
	_until(ended, 5)
	_hex(ended)
	assert_true(ended.unit("p0").ai_seen.has("e0") and ended.unit("p1").ai_seen.has("e0"))
	_until(ended, 66)
	assert_eq([ended.unit("p0").ai_seen, ended.unit("p1").ai_seen], [{}, {}], "at the cast end")
	var cut: RtSim = _sim("p1", 6, [{"skill": "skl_kai_leash_trip", "target": "caster"}],
		{"AI_INTERRUPT_REACT_TICKS": 0, "AI_INTERRUPT_JITTER_TICKS": 0, "AI_INTERRUPT_LATE_PM": 0})
	_until(cut, 5)
	_hex(cut)
	assert_eq(RtKit.of(_until(cut, _think(0, 5) + 10), T.CAST_INTERRUPTED).size(), 1)
	assert_eq(cut.unit("p0").ai_seen, {}, "at the interruption")
	var ko: RtSim = _sim("p1", 6, [{"skill": "skl_kai_heavy_swing", "target": "assist"}])
	_until(ko, 5)
	_hex(ko)
	Damage.apply(ko, ko.unit("p0"), ko.unit("e0"), 99999, Elements.PHYSICAL, HitResult.new(), "skl_kai_heavy_swing", "",
		"", Damage.Kind.ABILITY, true, K.SKILL, 1000)
	assert_true(ko.unit("e0").is_ko())
	assert_eq(ko.unit("p0").ai_seen, {}, "at the caster's KO")


# --- dodging (07 §5.5) -----------------------------------------------------------------------------------------------

func test_react_ticks_by_tactic() -> void:
	var want: Dictionary = {"attack": 15, "support": 12, "careful": 6}
	for preset: String in want.keys():
		var sim: RtSim = _sim("p1", 6, [], NO_MISS)
		var kai: RtUnit = sim.unit("p0")
		sim.submit(RtCommand.preset(0, "p0", preset, {}))
		_until(sim, 10)
		kai.rules = []
		var x: int = kai.x
		var z: int = kai.z
		_tele(sim, x, z, 250, 30)
		assert_eq(kai.react_at, 10 + int(want[preset]), preset)
		assert_eq(sim.unit("p1").react_at, -1, "the person's unit draws but does not react")
		var moved: int = -1
		while sim.tick() < 40:
			sim.step()
			if moved < 0 and (kai.x != x or kai.z != z):
				moved = sim.tick() - 1
		assert_eq(moved, 10 + int(want[preset]), "%s: it walks from react_at on" % preset)


func test_missed_telegraphs_by_tactic() -> void:
	var bounds: Dictionary = {"attack": [15, 70], "careful": [2, 30]}
	for preset: String in bounds.keys():
		var sim: RtSim = _sim("p1", 6, [], {}, 21)
		var kai: RtUnit = sim.unit("p0")
		Ability.set_preset(sim, kai, preset, {})
		kai.rules = []
		_until(sim, 2)
		var n: int = int(sim.snapshot()["ai_rng_n"])
		var missed: int = 0
		for k in 300:
			kai.react_at = -1
			var t: RtTelegraph = _tele(sim, kai.x, kai.z, 250, 30)
			var miss: bool = FixedMath.roll_bp(_ai_draw(21, n + 1 + 2 * k), sim.bal.sub("AI_DODGE_MISS_PM", preset) * 10)
			assert_eq(kai.react_at == -1, miss, "%s #%d: the draw of the AI stream" % [preset, k])
			missed += 1 if miss else 0
			sim.remove_telegraph(t)
		assert_between(missed, int(bounds[preset][0]), int(bounds[preset][1]), "%s: %d of 300 missed" % [preset,
			missed])


func test_attack_ai_leaves_the_cleaner_fog_in_time() -> void:
	for react: int in [15, 18]:
		var sim: RtSim = _sim("p1", 6, [], {"AI_DODGE_MISS_PM": {"attack": 0}, "REACT_TICKS": {"attack": react}})
		var kai: RtUnit = sim.unit("p0")
		_until(sim, 10)
		var cx: int = kai.x
		var cz: int = kai.z
		_tele(sim, cx, cz, 250, 30)
		_until(sim, 40)
		var d: int = DetMath.dist(cx, cz, kai.x, kai.z)
		assert_eq(d > 250, react == 15, "REACT %d: %d cm from the centre at the impact (07 §5.5: 15 + 14 fit, 18 not)" %
			[react, d])


func test_escape_point() -> void:
	var sim: RtSim = _sim("p1", 6, [], NO_MISS)
	var kai: RtUnit = sim.unit("p0")
	var mop: RtUnit = sim.unit("p1")
	kai.target_id = "e0"
	assert_eq(RtGeo.escape_point(sim, kai), Vector2i(0, 100), "no danger: 100 cm, towards the target (melee)")
	mop.x = 0
	mop.z = 0
	assert_eq(RtGeo.escape_point(sim, mop), Vector2i(0, 100), "ranged: away from the nearest enemy")
	mop.z = 400
	var edge: Vector2i = RtGeo.escape_point(sim, mop)
	assert_true(RtGeo.walkable(sim.setup.geo, edge.x, edge.y, mop.radius, false) and DetMath.dist(0, 400, edge.x,
		edge.y) == 100 and edge != Vector2i(0, 500), "at the ring: the nearest walkable direction (%s)" % edge)
	_tele(sim, 0, 200, 250, 30)
	assert_eq(RtGeo.escape_point(sim, kai), Vector2i(0, -250), "out of the grown circle (310): 450 cm on")
	_tele(sim, 0, -250, 100, 80)
	assert_eq(RtGeo.escape_point(sim, kai), Vector2i(0, -250), "shapes striking later than 60 ticks do not count")
	_tele(sim, 0, 0, 2000, 30)
	assert_eq(RtGeo.escape_point(sim, kai), Vector2i(0, 200), "nowhere safe: it stands")


func test_moving_cast_aborted_unless_it_ends_in_time() -> void:
	for impact_in: int in [30, 72]:
		var sim: RtSim = _sim("p0", 6, [{"skill": "skl_mop_noble_flame", "target": "assist"}], NO_MISS)
		var mop: RtUnit = sim.unit("p1")
		_until(sim, 3)
		assert_eq(mop.cast.get("skill", ""), "skl_mop_noble_flame", "casting 2 … 47")
		_tele(sim, mop.x, mop.z, 250, impact_in)
		var ev: Array[ActionEvent] = _until(sim, 52)
		var failed: Array[ActionEvent] = RtKit.of(ev, T.CAST_FAILED)
		if impact_in == 30:
			assert_true(failed.size() == 1 and failed[0].tick == 15 and failed[0].text == "moved",
				"impact at 33: from react_at 15 on (every tick, not only when it thinks) it breaks the cast off")
		else:
			assert_eq(failed.size(), 0, "impact at 75: the cast ends at 47, then it walks (47 ≤ 75 − 25)")
			var ends: Array = RtKit.of(ev, T.ACTION_END).filter(func(e: ActionEvent) -> bool: return e.actor_id == "p1")
			assert_eq(ends.map(func(e: ActionEvent) -> int: return e.tick), [47], "the cast ends")


func test_zones_are_avoided() -> void:
	var cmd: Dictionary = RtKit.dummy_cmd({"ctl": "p1", "party": [{"u": "p0", "p": [0, 400, 0]},
		{"u": "p1", "p": [-150, 300, 0]}]})
	var sim: RtSim = _sim("p1", 6, [], NO_MISS, RtKit.SEED, cmd)
	var kai: RtUnit = sim.unit("p0")
	kai.rules = []
	sim.step()
	assert_eq(Array(kai.goal), [0, 210], "the melee goal (reach 250 + 40 − 30 from the dummy)")
	_tele(sim, 0, 210, 120, 300, true)
	_until(sim, 3)
	assert_eq(Array(kai.goal), [0, 210], "the goal stays until Kai thinks again (staggered AI, 07 §3.15)")
	var ep: Vector2i = RtGeo.escape_point(sim, kai)
	sim.step()
	assert_eq(Array(kai.goal), [ep.x, ep.y], "a goal in a zone becomes the escape point")
	assert_eq(sim.escape.get("p0"), [ep.x, ep.y], "the escape point is kept …")
	sim.step()
	assert_eq(Array(kai.goal), [ep.x, ep.y], "… while it stays safe (no new search every tick)")
	kai.x = 0
	kai.z = 210
	sim.escape.clear()
	ep = RtGeo.escape_point(sim, kai)
	sim.step()
	assert_eq(Array(kai.goal), [ep.x, ep.y], "standing in a zone: out")
	assert_false(DetMath.dist2(kai.x, kai.z, 0, 210) <= 120 * 120 and kai.z == 210, "and it walks")


func test_partner_follows_the_fleeing_figure() -> void:
	var sim: RtSim = _sim("p0", 6, [], {}, RtKit.SEED, RtKit.encounter("enc_rt_dummy",
		[["g", "enc_rt_dummy", [0, 300, 0]]], {"ctl": "p0", "party": [{"u": "p0", "p": [0, -200, 0]},
		{"u": "p1", "p": [100, -100, 0]}]}))
	var kai: RtUnit = sim.unit("p0")
	var mop: RtUnit = sim.unit("p1")
	mop.rules = []
	var z: int = kai.z
	var far: int = 0
	for _i in 40:
		z = maxi(z - 18, -760)
		sim.submit(RtCommand.move(sim.tick(), "p0", 0, z, 0, -180, 0))
		sim.step()
		far = mini(far, mop.z)
	assert_eq(kai.z, -760, "Kai stands in the north door lane (outside the ring)")
	assert_lt(far, -450, "Mopsula follows him into the lane (the ring ends at −445 for her)")
	assert_eq(Array(mop.goal), [DetMath.toward(kai.x, kai.z, mop.x, mop.z, 75).x, DetMath.toward(kai.x, kai.z, mop.x,
		mop.z, 75).y], "her goal: next to him")


# --- Partner-Spezial, tactics, autopilot, assist ----------------------------------------------------------------------

func test_partner_special_holds_the_rules() -> void:
	var sim: RtSim = _sim("p0", 6, [{"skill": "skl_mop_thunder_bark", "target": "self"}])
	var mop: RtUnit = sim.unit("p1")
	mop.gcd_until = 20
	mop.gcd_len = 45
	sim.submit(RtCommand.partner_special(0, "p1"))
	var ev: Array[ActionEvent] = _until(sim, 120)
	var mine: Array = RtKit.of(ev, T.ACTION_START).filter(func(e: ActionEvent) -> bool: return e.actor_id == "p1").map(
		func(e: ActionEvent) -> Array: return [e.tick, e.skill_id, e.by_ai])
	assert_eq(mine.slice(0, 2), [[20, "skl_mop_holy_lick", false], [65, "skl_mop_thunder_bark", true]],
		"the order waits for the GCD and holds the rules; after it they play on")
	var free: RtSim = _sim("p0", 6, [{"skill": "skl_mop_thunder_bark", "target": "self"}])
	free.unit("p1").gcd_until = 20
	assert_eq(_ai_starts(_until(free, 3), "p1"), [[2, "skl_mop_thunder_bark"]],
		"without an order: at once (its first thinking tick)")


func test_tactic_change_brings_rules_and_distance() -> void:
	var sim: RtSim = _sim("p0")
	var mop: RtUnit = sim.unit("p1")
	var prt: Dictionary = RtKit.data().party_member("mopsula").rt
	assert_eq([mop.preset, mop.keep_cm], ["support", 600])
	var keep: Dictionary = {"attack": 450, "careful": 700, "support": 600}
	for p: String in ["attack", "careful", "support"]:
		sim.submit(RtCommand.preset(sim.tick(), "p1", p, {"potions": p == "careful"}))
		var pc: Array[ActionEvent] = RtKit.of(sim.step(), T.PRESET_CHANGED)
		assert_eq([mop.preset, mop.keep_cm, mop.rules], [p, keep[p], RtRules.preset_rules(prt, p)], p)
		assert_true(pc.size() == 1 and pc[0].text == p and int(pc[0].rt["tog"]["potions"]) == (1 if p == "careful" else
			0))
	var kai: RtSim = _sim("p1")
	Ability.set_preset(kai, kai.unit("p0"), "support", {})
	assert_eq([kai.unit("p0").keep_cm, kai.unit("p0").rules[0]["key"]], [0, "support:0"], "Kai: melee in every tactic")


func test_autopilot_plays_the_controlled_unit() -> void:
	var cmd: Dictionary = RtKit.dummy_cmd({"ctl": "p0", "party": [{"u": "p0", "p": [0, 450, 0]},
		{"u": "p1", "p": [-150, 300, 0]}]})
	var sim: RtSim = _sim("p0", 6, [], {}, RtKit.SEED, cmd)
	var kai: RtUnit = sim.unit("p0")
	sim.submit(RtCommand.autopilot(0, "p0", true))
	var ev: Array[ActionEvent] = _until(sim, 60)
	assert_eq(kai.driver, RtUnit.Driver.AUTOPILOT)
	assert_lt(kai.z, 450, "it walks into reach (the range goal of its attack rules)")
	var st: Array = _ai_starts(ev, "p0")
	assert_eq(st, [[3, "skl_kai_taunt"], [12, "skl_kai_heavy_swing"], [57, "skl_kai_heavy_swing"]],
		"its tactic plays (by_ai): the dummy is on Mopsula (nearer at the start) → taunt, then the filler in reach")
	sim.submit(RtCommand.autopilot(sim.tick(), "p0", false))
	var z: int = kai.z
	ev = _until(sim, 200)
	assert_eq([_ai_starts(ev, "p0"), kai.z, kai.driver], [[], z, RtUnit.Driver.PLAYER], "off: the person again")


func test_suggest() -> void:
	var sim: RtSim = _sim("p0")
	assert_eq(sim.suggest("p0"), "skl_stunt_kai_suplex", "the first usable rule of assist_preset (no AI grace)")
	assert_eq([sim.suggest("e0"), sim.suggest("nobody")], ["", ""])
	var h0: String = StateHash.of_rt(sim)
	for _i in 300:
		sim.suggest("p0")
		sim.suggest("p1")
	assert_eq(StateHash.of_rt(sim), h0, "pure")
	sim.unit("p0").hp = sim.unit("p0").max_hp() / 10
	sim.unit("p0").toggles["potions"] = true
	assert_eq(sim.suggest("p0"), "skl_stunt_kai_suplex", "never an item")
	sim.submit(RtCommand.ability(0, "p0", "skl_kai_heavy_swing", "e0"))
	_until(sim, 2)
	assert_eq(sim.suggest("p0"), "", "GCD 43 left: nothing usable")
	_until(sim, 36)
	assert_eq(sim.suggest("p0"), "skl_stunt_kai_suplex", "9 left: buffered counts as usable")
	_hex(sim, "p0")
	assert_eq(sim.suggest("p0"), "skl_kai_leash_trip", "a worthy cast: the interrupter at once (the person sees it)")


## The queries of the AI (suggest, RtRules.choose / eval_cond / rule_target, RtGeo.escape_point, escaping, safe_point)
## stay pure while a telegraph is pending and a worthy cast runs (07 §3.4).
func test_ai_queries_are_pure() -> void:
	var a: RtSim = _sim("p1", 6, [], NO_MISS)
	var b: RtSim = _sim("p1", 6, [], NO_MISS)
	for sim: RtSim in [a, b]:
		_until(sim, 5)
		_hex(sim)
		_tele(sim, sim.unit("p0").x, sim.unit("p0").z, 250, 40)
		_until(sim, 25)
	var h0: String = StateHash.of_rt(a)
	for _i in 200:
		for u: RtUnit in a.units():
			a.suggest(u.id)
			RtRules.choose(a, u)
			RtRules.eval_cond(a, u, {"caster_within_cm": 600, "enemies_in_radius": {"r_cm": 300, "min": 1}}, "e0")
			RtRules.rule_target(a, u, "random_enemy", a.skill_def("skl_kai_leash_trip"))
			RtGeo.escape_point(a, u)
			a.escaping(u)
			a.safe_point(u, 0, 0)
	assert_eq(StateHash.of_rt(a), h0, "no draw, no write")
	assert_eq(h0, StateHash.of_rt(b))
	var ea: Array[ActionEvent] = _until(a, 200)
	var eb: Array[ActionEvent] = _until(b, 200)
	assert_eq(ea.map(func(e: ActionEvent) -> Dictionary: return e.to_dict()), eb.map(func(e: ActionEvent) -> Dictionary:
		return e.to_dict()), "and the combat goes on the same")


# --- the fast rule walk = a plain reference of 07 §5.3 ----------------------------------------------------------------

## RtRules.choose written straight from 07 §5.3 with the slow public pieces (Ability.precheck / targets / check_item,
## eval_cond on all conditions, is_show_skill, …).
static func _ref_choose(sim: RtSim, u: RtUnit) -> Dictionary:
	if not RtRules.may_act(sim, u):
		return {}
	var c: int = sim.tick()
	var goal: Array = []
	var party: bool = u.side == Combatant.Side.PARTY
	var tail: bool = u.gcd_until - c > 0 and u.gcd_until - c <= sim.bal.i("AI_INTERRUPT_GCD_TAIL_TICKS")
	var grace_until: int = sim.show_ready_at() + sim.bal.i("AI_SHOW_GRACE_TICKS")
	for pos in u.rules.size():
		var r: Dictionary = u.rules[pos]
		var key: String = str(r["key"])
		var offset: int = 0 if party else u.slot * sim.bal.i("AI_SLOT_OFFSET_TICKS")
		if (int(u.rule_ready[key]) if u.rule_ready.has(key) else int(r["first"]) + offset) > c:
			continue
		var cond: Dictionary = r["cond"]
		if tail and (str(r["target"]) == "caster" or cond.has("caster_within_cm") or cond.has("target_casting")):
			continue
		var sid: String = str(r["skill"])
		if sid == "":
			if not party or str(r["item"]) == "" or (u.preset != "careful" and not bool(u.toggles.get("potions",
					false))) or sim.items_left() <= 0 or sim.item_cd_left() > 0:
				continue
			var ti: Dictionary = RtRules.rule_target(sim, u, str(r["target"]), null)
			if not bool(ti["ok"]) or not RtRules.eval_cond(sim, u, cond, str(ti["id"])):
				continue
			var item: String = RtRules.pick_item(sim, u, str(r["item"]), str(ti["id"]))
			if item == "":
				continue
			var ir: Dictionary = Ability.check_item(sim, u, item, str(ti["id"]))
			if str(ir["reason"]) == "range":
				if goal.is_empty():
					var isk: SkillDef = sim.skill_def(sim.item_def(item).use_skill)
					goal = _ref_goal(sim, u, int(isk.rt.get("range_cm", 0)), str(ir["primary"]) if str(ir["primary"])
						!= "" else str(ti["id"]))
				continue
			if str(ir["reason"]) != "":
				continue
			return _ref_out({"item": item, "target": str(ti["id"]), "at": pos}, ti, goal)
		var sk: SkillDef = sim.skill_def(sid)
		if sk == null or sim.is_finale(u, sid) or (party and sim.is_show_skill(u, sid) and c < grace_until):
			continue
		if Ability.precheck(sim, u, sk) != "":
			continue
		if sim.escaping(u) and bool(sk.rt.get("moving_cancels", false)) and (Ability.cast_ticks(sim, u, sk) > 0 or
				Ability.channel_ticks(sk) > 0):
			continue
		var tg: Dictionary = RtRules.rule_target(sim, u, str(r["target"]), sk)
		if not bool(tg["ok"]) or not RtRules.eval_cond(sim, u, cond, str(tg["id"])):
			continue
		if bool(r["filler"]) and not RtRules.reserve_ok(sim, u, sk):
			continue
		var tr: Dictionary = Ability.targets(sim, u, sk, str(tg["id"]), false)
		if str(tr["reason"]) == "range":
			if goal.is_empty():
				goal = _ref_goal(sim, u, int(sk.rt.get("range_cm", 0)), str(tr["primary"]) if str(tr["primary"]) != ""
					else str(tg["id"]))
			continue
		if str(tr["reason"]) != "":
			continue
		return _ref_out({"skill": sid, "target": str(tg["id"]), "at": pos}, tg, goal)
	return {"goal": goal} if not goal.is_empty() else {}


static func _ref_goal(sim: RtSim, u: RtUnit, range_cm: int, tid: String) -> Array:
	var t: RtUnit = sim.unit(tid)
	var want: int = maxi(0, (range_cm if range_cm > 0 else u.reach) + t.radius - sim.bal.i("MELEE_STOP_CM"))
	var p: Vector2i = DetMath.toward(t.x, t.z, u.x, u.z, want)
	return [p.x, p.y]


static func _ref_out(out: Dictionary, tg: Dictionary, goal: Array) -> Dictionary:
	if tg.has("random"):
		out["random"] = tg["random"]
	if not goal.is_empty():
		out["goal"] = goal
	return out


## Plays `sim` to the end (≤ max_ticks) with `cmds`; every 97 ticks a telegraph under a party unit, every 131 ticks a
## worthy cast of the first free enemy; before every tick choose == the reference for every AI-driven party unit.
func _same_as_reference(sim: RtSim, cmds: Array, max_ticks: int) -> int:
	var i: int = 0
	var checked: int = 0
	while not sim.is_finished() and sim.tick() < max_ticks:
		while i < cmds.size() and int((cmds[i] as Dictionary)["ct"]) <= sim.tick():
			sim.submit(cmds[i])
			i += 1
		var c: int = sim.tick()
		if c % 97 == 50:
			var p: RtUnit = sim.unit("p%d" % ((c / 97) % 2))
			if sim.is_alive(p):
				_tele(sim, p.x, p.z, 200 + (c % 3) * 50, 25 + (c % 4) * 10)
		if c % 131 == 70:
			for e: RtUnit in sim.units():
				if e.side == Combatant.Side.ENEMY and sim.targetable(e) and e.cast.is_empty() and e.entry.is_empty():
					Ability.use_ability(sim, e, "skl_e_test_hex", "p0", true)
					break
		for u: RtUnit in sim.units():
			if sim.is_ai_driven(u):
				var got: Dictionary = RtRules.choose(sim, u)
				var want: Dictionary = _ref_choose(sim, u)
				if not _deep_eq(got, want):
					fail("ct %d %s: choose %s, reference %s" % [c, u.id, str(got), str(want)])
					return checked
				checked += 1
		sim.step()
	return checked


func test_fast_rule_walk_equals_the_reference() -> void:
	var n: int = _same_as_reference(RtKit.canned_sim(), RtKit.canned_commands(), 1800)
	var six: Dictionary = RtKit.encounter("enc_rt_rats", [["g1", "enc_rt_rats", [-100, -300, 128]],
		["g2", "enc_f1_a2", [250, -250, 160]], ["g3", "enc_rt_rats", [-250, -100, 100]]])
	var auto: Array = [RtCommand.autopilot(0, "p0", true), RtCommand.preset(300, "p1", "attack", {"potions": true}),
		RtCommand.preset(700, "p1", "careful", {})]
	n += _same_as_reference(RtKit.sim(six, 6, "kai", RtKit.canned_state()), auto, 1800)
	var mop: Dictionary = RtKit.encounter("enc_f1_a2", [["g1", "enc_f1_a2", [0, -300, 128]]], {"ctl": "p1"})
	n += _same_as_reference(RtKit.sim(mop, 7, "mopsula", RtKit.canned_state()), [RtCommand.autopilot(0, "p1", true)],
		1800)
	assert_gt(n, 1500, "%d AI decisions compared" % n)



# --- R1b-I3: enemies -------------------------------------------------------------------------------------------------

## A started combat of `cmd` (Kai level 6 controlled) whose party plays no rules (only the enemies do).
func _foes(cmd: Dictionary, st: GameState = null) -> RtSim:
	var sim: RtSim = RtKit.sim(cmd, 6, "kai", st)
	for u: RtUnit in sim.party_ref():
		u.rules = []
	return sim


static func _starts_of(events: Array[ActionEvent], uid: String) -> Array:
	return RtKit.of(events, T.ACTION_START).filter(func(e: ActionEvent) -> bool: return e.actor_id == uid).map(
		func(e: ActionEvent) -> Array: return [e.tick, e.skill_id, e.by_ai])


func test_enemy_rules_timers_and_slot_offset() -> void:
	var sim: RtSim = _foes(RtKit.encounter("enc_f1_a2", [["g", "enc_f1_a2", [0, -300, 128]]]))
	var rat: RtUnit = sim.unit("e0")
	var caster: RtUnit = sim.unit("e1")
	assert_eq([rat.rules.map(func(r: Dictionary) -> String: return r["key"]), caster.rules.map(
		func(r: Dictionary) -> String: return r["key"])], [["0:0"], ["0:0", "0:1"]], "rt.rules, keys \"0:<index>\"")
	assert_eq([rat.slot, caster.slot], [0, 1])
	var ev: Array[ActionEvent] = _until(sim, 89)
	assert_eq(RtRules.choose(sim, rat), {}, "the rat's bite (slot 0): not before first_ms 3000")
	ev.append_array(sim.step())
	assert_false(RtRules.choose(sim, rat).is_empty(), "ready at 90 (it walks to its threat target, then bites)")
	ev.append_array(_until(sim, 140))
	var cs: Array = RtKit.of(ev, T.CAST_START).filter(func(e: ActionEvent) -> bool: return e.actor_id == "e1")
	assert_eq([cs[0].tick, cs[0].skill_id, cs[0].by_ai], [_think(3, 30 + 9), "skl_e_test_hex", true],
		"first_ms 1000 + slot 1 × AI_SLOT_OFFSET_TICKS 9 = 39, at its thinking tick (index 3)")
	assert_eq(int(caster.rule_ready["0:0"]), int(cs[0].tick) + 240, "every_ms 8000")
	assert_eq([cs[1].tick, cs[1].skill_id], [_think(3, cs[0].tick + 60), "skl_e_test_slam"],
		"the next rule once the hex cast is over (its own timer was ready at 69)")


func test_boss_phases_and_ops() -> void:
	var sim: RtSim = RtKit.sim_no_ai(RtKit.encounter("enc_rt_chief", [["g", "enc_rt_chief", [0, -300, 128]]]), 6)
	var chief: RtUnit = sim.unit("e0")
	chief.auto_on = false
	assert_eq([chief.phase, chief.is_boss, chief.hp], [0, true, 3000], "the first phase is entered at the start")
	var st: RtSim = RtSim.new(RtKit.setup(RtKit.state(6), RtKit.encounter("enc_rt_chief", [["g", "enc_rt_chief",
		[0, -300, 128]]])), RtKit.data())
	var start: Array[ActionEvent] = st.start()
	var first: Array[ActionEvent] = RtKit.of(start, T.PHASE_CHANGE)
	assert_true(first.size() == 1 and first[0].tick == 0 and first[0].value == 1 and not first[0].success
		and first[0].actor_id == "e0", "PHASE_CHANGE 1 at the start (no phase before it was perfect)")
	assert_eq(RtKit.of(start, T.MOD_LINE).map(func(e: ActionEvent) -> String: return e.text), ["rt_test_chief_1"],
		"its on_enter ops after it")
	assert_true(start.find(first[0]) > start.find(RtKit.of(start, T.BATTLE_START)[0]), "after BATTLE_START")
	assert_eq(int(st.tally["perfect_phases"]), 0)
	var c0: RtUnit = st.unit("e0")
	assert_eq([c0.rules.map(func(r: Dictionary) -> String: return r["key"]), int(c0.rule_ready["0:0"]),
		int(c0.rule_ready["0:1"])], [["0:0", "0:1"], 60, 120], "phase rules \"<phase>:<index>\", ready first_ms after "
		+ "the phase start")
	_until(sim, 10)
	chief.hp = chief.max_hp() / 2
	var ev: Array[ActionEvent] = sim.step()
	var pc: Array[ActionEvent] = RtKit.of(ev, T.PHASE_CHANGE)
	assert_true(pc.size() == 1 and pc[0].value == 2 and pc[0].success and pc[0].actor_id == "e0",
		"60 % crossed: PHASE_CHANGE 2, success = the first phase was perfect")
	assert_eq(int(sim.tally["perfect_phases"]), 1)
	assert_eq(RtKit.of(ev, T.MOD_LINE).map(func(e: ActionEvent) -> String: return e.text), ["rt_test_chief_2"], "say")
	var sm: Array[ActionEvent] = RtKit.of(ev, T.SUMMON)
	assert_true(sm.size() == 1 and sm[0].actor_id == "e0" and sm[0].target_id == "e1" and sm[0].value == 1
		and sm[0].def_id == "enm_kanalratte", "summon: SUMMON (value = its number)")
	var add: RtUnit = sim.unit("e1")
	assert_eq([add.x, add.z, add.is_summon, add.max_hp(), add.pop_in_until], [0, 450, true, 96, 10 + 15],
		"at the ring point before the door nearest to the party (closed boss set), stats.hp × SUMMON_HP_PM, pop-in")
	assert_eq(RtKit.of(ev, T.CAST_START).size(), 0, "the telegraph op: shapes without a cast")
	assert_eq(RtKit.of(ev, T.TELEGRAPH_START).map(func(e: ActionEvent) -> String: return e.skill_id),
		["skl_e_rt_puddles", "skl_e_rt_puddles", "skl_e_rt_puddles"])
	var guard: Array = RtKit.of(ev, T.STATUS_ADDED).filter(func(e: ActionEvent) -> bool:
		return e.target_id == "e0" and e.status_id == "sts_guard")
	assert_eq(guard.map(func(e: ActionEvent) -> int: return e.value), [90], "status_self: 3000 ms")
	assert_eq([chief.phase, chief.rules.map(func(r: Dictionary) -> String: return r["key"]),
		int(chief.rule_ready["1:0"]), int(chief.rule_ready["1:1"])], [1, ["1:0", "1:1"], 10 + 90, 10 + 150],
		"the phase's rules from its start (07 §6.6)")
	_until(sim, 120)
	var perfect: bool = chief.phase_perfect
	chief.hp = chief.max_hp() * 2 / 10
	var zones: int = sim.telegraphs().filter(func(t: RtTelegraph) -> bool: return t.is_zone).size()
	ev = sim.step()
	pc = RtKit.of(ev, T.PHASE_CHANGE)
	assert_true(pc.size() == 1 and pc[0].value == 3 and pc[0].success == perfect, "30 %: PHASE_CHANGE 3")
	var self_hit: Array = RtKit.of(ev, T.DAMAGE).filter(func(e: ActionEvent) -> bool: return e.target_id == "e0")
	assert_eq(self_hit.map(func(e: ActionEvent) -> int: return e.amount), [150], "fixed_damage_self: 50 ‰ of 3000")
	assert_eq([RtKit.of(ev, T.ZONE_END).size(), sim.telegraphs().filter(func(t: RtTelegraph) -> bool: return t.is_zone)
		.size()], [zones, 0], "clear_zones ends its zones")
	var haste: Array = RtKit.of(ev, T.STATUS_ADDED).filter(func(e: ActionEvent) -> bool: return e.status_id == "sts_haste")
	assert_true(haste.size() == 1 and haste[0].value == -1 and not chief.stationary, "status until the end; set")


func test_phase_thresholds_in_one_tick_and_self_damage_never_kills() -> void:
	var sim: RtSim = RtKit.sim_no_ai(RtKit.encounter("enc_rt_chief", [["g", "enc_rt_chief", [0, -300, 128]]]), 6)
	var chief: RtUnit = sim.unit("e0")
	chief.auto_on = false
	_until(sim, 5)
	chief.hp = 2
	var ev: Array[ActionEvent] = sim.step()
	assert_eq(RtKit.of(ev, T.PHASE_CHANGE).map(func(e: ActionEvent) -> int: return e.value), [2, 3],
		"two thresholds crossed: both phases in order, each with its ops")
	assert_eq(RtKit.of(ev, T.SUMMON).size(), 1, "the ops of phase 2 ran")
	assert_eq(chief.hp, 1, "fixed_damage_self never takes the last HP point")
	assert_true(sim.is_alive(chief))


func test_enrage() -> void:
	var sim: RtSim = RtKit.sim_no_ai(RtKit.encounter("enc_rt_chief", [["g", "enc_rt_chief", [0, -300, 128]]]), 6)
	for u: RtUnit in sim.units_ref():
		u.auto_on = false
	var ev: Array[ActionEvent] = _until(sim, 601)
	var en: Array[ActionEvent] = RtKit.of(ev, T.ENRAGE)
	assert_true(en.size() == 1 and en[0].tick == 600 and en[0].value == 1 and en[0].actor_id == "e0", "at at_ms 20000")
	var ml: Array = RtKit.of(ev, T.MOD_LINE).filter(func(e: ActionEvent) -> bool: return e.tick == 600)
	assert_eq(ml.map(func(e: ActionEvent) -> String: return e.text), ["rt_enrage:enm_rt_test_chief"])
	var sa: Array = RtKit.of(ev, T.STATUS_ADDED).filter(func(e: ActionEvent) -> bool: return e.status_id == "sts_enrage")
	assert_true(sa.size() == 1 and sa[0].value == -1 and int(sa[0].rt["stacks"]) == 1, "the status until the end")
	ev = _until(sim, 901)
	en = RtKit.of(ev, T.ENRAGE)
	assert_true(en.size() == 1 and en[0].tick == 900 and en[0].value == 2, "every every_ms another stack")
	assert_eq(RtKit.of(ev, T.MOD_LINE).size(), 0, "the M.O.D. line only once")
	assert_eq(StatusFx.factor(sim.unit("e0"), "dmg_dealt_pm"), 2250, "× 1.5 per stack (07 §6.4)")


func test_summons() -> void:
	var sim: RtSim = RtKit.sim_no_ai(RtKit.encounter("enc_rt_dummies", [["g", "enc_rt_dummies", [0, -50, 128]]]), 6)
	var dummy: RtUnit = sim.unit("e0")
	_until(sim, 20)
	var made: Array = []
	for k in 4:
		made.append(RtSim.Boss.summon(sim, dummy, "enm_kanalratte", "near", k))
	assert_eq(made.map(func(u: Variant) -> bool: return u != null), [true, true, true, false],
		"at most MAX_ENEMIES (6) living enemies")
	var add: RtUnit = made[0]
	var near: Vector2i = RtGeo.project_walkable(sim.setup.geo, RtGeo.formation(1, dummy.x, dummy.z, dummy.yaw).x,
		RtGeo.formation(1, dummy.x, dummy.z, dummy.yaw).y, add.radius, false)
	assert_eq([add.id, add.x, add.z, add.max_hp(), add.hp, add.is_summon, add.pop_in_until], ["e3", near.x, near.y, 96,
		96, true, 35], "near: formation slot 1 + k around the summoner; 24 × SUMMON_HP_PM 4000; acts 15 ticks later")
	assert_eq(add.threat, {"p0": 1}, "threat 1 on the nearest party unit")
	assert_eq(int(add.rule_ready["0:0"]), 20 + 90 + 3 * 9, "its rules from the summon on (first_ms + slot offset)")
	var open: RtSim = RtKit.sim_no_ai(RtKit.dummy_cmd(), 6)
	_until(open, 5)
	var walker: RtUnit = RtSim.Boss.summon(open, open.unit("e0"), "enm_kanalratte", "door", 0)
	assert_eq([walker.x, walker.z, Array(walker.entry), walker.pop_in_until], [0, 750, [0, 450], 5 + 15 + 30],
		"door in an open set: the end of the lane nearest to the party, then the walk in")
	assert_false(open.targetable(walker), "not on stage while it walks in")
	var steps: int = 0
	while not walker.entry.is_empty() and steps < 40:
		open.step()
		steps += 1
	assert_eq([walker.x, walker.z, walker.pop_in_until, open.targetable(walker)], [0, 450, open.tick() - 1 + 15, true],
		"arrived: on stage at once, acting POP_IN_TICKS later")
	var by_skill: RtSim = RtKit.sim_no_ai(RtKit.dummy_cmd(), 6)
	by_skill.unit("e0").rules = RtRules.compile([{"skill": "skl_e_rt_call", "target": "self", "once": true}], "t")
	var ev: Array[ActionEvent] = _until(by_skill, 70)
	var sev: Array[ActionEvent] = RtKit.of(ev, T.SUMMON)
	assert_true(sev.size() == 1 and sev[0].tick == _think(2, 0) + 60 and sev[0].def_id == "enm_kanalratte",
		"a summon skill (skill.summon) at its cast end, at the door")


func test_random_targets() -> void:
	var sim: RtSim = _foes(RtKit.encounter("enc_rt_pigeons", [["g", "enc_rt_pigeons", [0, -300, 128]]]))
	var pigeon: RtUnit = sim.unit("e0")
	var n: int = int(sim.snapshot()["rng_n"])
	sim.step()
	assert_eq(pigeon.target_id, "", "it thinks at ct 1 (index 2)")
	var ev: Array[ActionEvent] = sim.step()
	var draw: int = SeedUtil.make_rng(SeedUtil.derive(RtKit.SEED, "rt", n + 1)).randi_range(0, 1)
	var tc: Array = RtKit.of(ev, T.TARGET_CHANGED).filter(func(e: ActionEvent) -> bool: return e.actor_id == "e0")
	assert_eq([pigeon.target_id, tc.size()], [["p0", "p1"][draw], 1], "auto_target random_enemy: drawn from the "
		+ "combat stream")
	var first: String = pigeon.target_id
	_until(sim, 60)
	assert_eq(pigeon.target_id, first, "kept while it lives (no draw every tick)")
	var dummy: RtSim = RtKit.sim_no_ai(RtKit.dummy_cmd(), 6)
	var d: RtUnit = dummy.unit("e0")
	d.rules = RtRules.compile([{"skill": "skl_e_rt_scatter", "target": "none", "once": true}], "t")
	var before: int = int(dummy.snapshot()["rng_n"])
	ev = _until(dummy, 2)
	var st: Array = RtKit.of(ev, T.ACTION_START).filter(func(e: ActionEvent) -> bool: return e.actor_id == "e0")
	var pick: int = SeedUtil.make_rng(SeedUtil.derive(RtKit.SEED, "rt", before + 1)).randi_range(0, 1)
	assert_eq(Array(st[0].target_ids), [["p0", "p1"][pick]], "skill target random_enemy: drawn when it starts")


func test_staggered_thinking() -> void:
	var sim: RtSim = _sim("p1", 6, [{"skill": "skl_kai_heavy_swing", "target": "assist"}])
	var kai_ticks: Array = _ai_starts(_until(sim, 300), "p0").map(func(x: Array) -> int: return int(x[0]) % 3)
	assert_true(kai_ticks.size() > 3 and kai_ticks.all(func(m: int) -> bool: return m == 0),
		"the AI partner p0 (index 0) picks only at ct % 3 == 0")
	var mop: RtSim = _sim("p0", 6, [{"skill": "skl_mop_frost_sneeze", "target": "assist"}])
	var mop_ticks: Array = _ai_starts(_until(mop, 300), "p1").map(func(x: Array) -> int: return int(x[0]) % 3)
	assert_true(mop_ticks.size() >= 2 and mop_ticks.all(func(m: int) -> bool: return m == 2),
		"Mopsula (index 1) at ct % 3 == 2")
	var foes: RtSim = _foes(RtKit.encounter("enc_f1_a2", [["g", "enc_f1_a2", [0, -300, 128]]]))
	var e_ticks: Array = _starts_of(_until(foes, 600), "e1").map(func(x: Array) -> int: return int(x[0]) % 3)
	assert_true(e_ticks.size() > 1 and e_ticks.all(func(m: int) -> bool: return m == 0), "the caster (index 3)")
