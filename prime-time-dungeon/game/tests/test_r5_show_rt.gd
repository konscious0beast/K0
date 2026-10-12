extends TestCase
## 07 §9.1 / §9.3 (R5a): the ShowRules profile rt row by row — skill moments only for the person (by_ai false) and
## interrupts / dodges only for the controlled unit (CONTROL_CHANGED moves it), slot 1 without the repetition
## penalty, party moments for everyone (the AI's SHOW too, but not as an own SHOW, E27), kills by KO.command, train
## kills, perfect phases, the first enrage, boredom and drag on SECOND, taunts_total; the M.O.D. line tags as reasons
## and the line rate of Show in a real-time combat; the CTB profile stays as it was.

const RtLive := preload("res://tests/fixtures/rt_live/rt_live.gd")
const K := BattleCommand.Kind

var _rules: ShowRules = null


func before_each() -> void:
	RtLive.swap_data()
	_rules = ShowRules.new(RtKit.data(), RtKit.setup(RtKit.state(6), RtKit.canned_encounter()))


func after_each() -> void:
	Show.abort_battle()
	Game.state = null
	RtLive.restore_data()


static func _ev(t: ActionEvent.Type, fields: Dictionary = {}) -> ActionEvent:
	var e: ActionEvent = ActionEvent.make(t)
	for k: String in fields.keys():
		if k == "target_ids":
			e.target_ids = PackedStringArray(fields[k])
		else:
			e.set(k, fields[k])
	return e


static func _act(actor: String, skill: String, ai: bool, cmd: int = K.SKILL) -> ActionEvent:
	return _ev(ActionEvent.Type.ACTION_START, {"actor_id": actor, "skill_id": skill, "by_ai": ai, "command": cmd})


## The hype of one event (raw, before the Show factors).
func _hype(e: ActionEvent) -> float:
	return _rules.feed(e).hype


func test_the_profile_comes_from_the_setup() -> void:
	assert_eq(_rules.profile, ShowRules.PROFILE_RT)
	assert_eq(_rules.controlled_id(), "p0", "RtSetup.controlled_id")
	var ctb: ShowRules = ShowRules.new(RtKit.data(), BattleSetup.new())
	assert_eq(ctb.profile, ShowRules.PROFILE_CTB, "a CTB setup keeps the CTB profile")
	assert_eq(ctb.feed(_act("p0", "skl_kai_heavy_swing", false)).hype, ShowRules.HYPE_VARIETY, "CTB values")


func test_start_bonus_as_in_ctb() -> void:
	var s: RtSetup = RtKit.setup(RtKit.state(6), RtKit.canned_encounter())
	var expect: Array = [[BattleSetup.Advantage.NORMAL, false, 3.0], [BattleSetup.Advantage.PREEMPTIVE, false, 3.0],
		[BattleSetup.Advantage.AMBUSH, false, 5.0], [BattleSetup.Advantage.NORMAL, true, 8.0]]
	for row: Array in expect:
		s.advantage = row[0]
		s.is_boss = row[1]
		var r: ShowRules = ShowRules.new(RtKit.data(), s)
		assert_eq(r.feed(_ev(ActionEvent.Type.BATTLE_START)).hype, float(row[2]), str(row))


func test_variety_and_repetition_count_the_person_only() -> void:
	assert_eq(_hype(_act("p0", "skl_kai_leash_trip", false)), ShowRules.RT_VARIETY, "a new own action")
	assert_eq(_hype(_act("p1", "skl_mop_noble_flame", true)), 0.0, "the AI partner's actions do not count")
	assert_eq(_hype(_act("p0", "skl_kai_leash_trip", false)), 0.0, "among the last 4 own actions")
	assert_eq(_hype(_act("p0", "skl_kai_leash_trip", false)), 0.0)
	var d: ShowDelta = _rules.feed(_act("p0", "skl_kai_leash_trip", false))
	assert_eq(d.hype, ShowRules.RT_REPEAT, "the 4th time in a row")
	assert_has(d.reasons, &"boring_fight")
	assert_eq(_hype(_act("p1", "skl_mop_holy_lick", false)), ShowRules.RT_VARIETY,
		"the Partner-Spezial is the person's action (by_ai false)")
	var slot1: Array = []
	for i in 5:
		slot1.append(_hype(_act("p0", "skl_kai_heavy_swing", false)))
	assert_eq(slot1, [ShowRules.RT_VARIETY, 0.0, 0.0, 0.0, 0.0], "the slot-1 skill never costs hype")


func test_party_moments_count_for_everyone() -> void:
	_rules.feed(_act("p1", "skl_mop_noble_flame", true))
	var crit: ShowDelta = _rules.feed(_ev(ActionEvent.Type.DAMAGE, {"actor_id": "p1", "target_id": "e0", "crit": true,
		"skill_id": "skl_mop_noble_flame", "amount": 5}))
	assert_eq(crit.hype, ShowRules.RT_CRIT, "the AI partner's ability crit counts for the party")
	assert_eq(crit.stats.get("crits_total", 0), 1)
	_rules.feed(_act("p0", "skl_kai_leash_trip", false))
	var weak: Callable = func(skill: String) -> float:
		return _hype(_ev(ActionEvent.Type.DAMAGE, {"actor_id": "p0", "target_id": "e0", "weak": true, "skill_id": skill,
			"amount": 5}))
	assert_eq([weak.call("skl_kai_leash_trip"), weak.call("skl_kai_leash_trip"), weak.call("skl_attack_kai")],
		[ShowRules.RT_WEAK, 0.0, 0.0], "weakness once per ability action; an auto-attack hit brings none (E32)")
	var combo: ShowDelta = _rules.feed(_ev(ActionEvent.Type.COMBO, {"actor_id": "p1", "target_id": "e0"}))
	assert_eq(combo.hype, ShowRules.RT_COMBO)
	assert_eq(combo.triggers[0]["trigger"], "combo")


func test_kills_by_their_command() -> void:
	var ko: Callable = func(actor: String, target: String, cmd: int, skill: String, ct: int, over: int = 0) -> ShowDelta:
		return _rules.feed(_ev(ActionEvent.Type.KO, {"actor_id": actor, "target_id": target, "command": cmd,
			"skill_id": skill, "tick": ct, "value": over, "def_id": "enm_kanalratte"}))
	assert_eq((ko.call("p0", "e0", K.ATTACK, "skl_attack_kai", 10) as ShowDelta).hype, ShowRules.HYPE_KILL_ATTACK)
	var sk: ShowDelta = ko.call("p1", "e1", K.SKILL, "skl_mop_noble_flame", 400)
	assert_eq(sk.hype, ShowRules.HYPE_KILL_SKILL, "the AI partner's kill counts")
	assert_eq(sk.stats.get("kills_skill", 0), 1)
	assert_eq(sk.triggers[0]["payload"], {"enemy_id": "enm_kanalratte", "overkill": false, "by": "skill",
		"member": "mopsula"})
	assert_eq((ko.call("p0", "e2", K.STUNT, "skl_stunt_kai_suplex", 800) as ShowDelta).hype, ShowRules.HYPE_KILL_STUNT)
	var fin: ShowDelta = ko.call("p0", "e3", K.STUNT, "skl_kai_prime_finisher", 1200, 1)
	assert_eq(fin.hype, ShowRules.HYPE_KILL_STUNT + 10.0 + ShowRules.HYPE_OVERKILL, "+ kill_hype 10 + overkill")
	# three kills within 6 s: the streak
	var r: ShowRules = ShowRules.new(RtKit.data(), RtKit.setup(RtKit.state(6), RtKit.canned_encounter()))
	var streak: Array = []
	for i in 3:
		streak.append(r.feed(_ev(ActionEvent.Type.KO, {"actor_id": "p0", "target_id": "e%d" % i, "command": K.ATTACK,
			"skill_id": "skl_attack_kai", "tick": 100 + 80 * i})).reasons.has(&"kill_streak"))
	assert_eq(streak, [false, false, true], "3 kills within 180 ticks")
	# a status kill (command −1) is credited, without kill hype; the train kills an add (+4, train_kills)
	_rules.feed(_act("p1", "skl_mop_noble_flame", true))
	_rules.feed(_ev(ActionEvent.Type.STATUS_ADDED, {"actor_id": "p1", "target_id": "e3", "status_id": "sts_burn"}))
	_rules.feed(_ev(ActionEvent.Type.DAMAGE, {"target_id": "e3", "status_id": "sts_burn", "amount": 3}))
	var st_ko: ShowDelta = ko.call("p1", "e3", -1, "", 1300)
	assert_eq(st_ko.hype, 0.0, "a status kill gives no kill hype")
	assert_eq(st_ko.triggers[0]["payload"]["by"], "skill", "credited to the skill that applied the status")
	var train: ShowDelta = ko.call("e0", "e4", -1, "skl_e_test_train", 1400)
	assert_eq(train.hype, ShowRules.RT_TRAIN_KILL)
	assert_eq(train.stats, {"kills_total": 1, "train_kills": 1})
	assert_has(train.reasons, &"rt_train_kill")


func test_interrupts_and_dodges_count_the_controlled_unit_only() -> void:
	var intr: Callable = func(actor: String, ai: bool) -> ShowDelta:
		return _rules.feed(_ev(ActionEvent.Type.CAST_INTERRUPTED, {"actor_id": actor, "target_id": "e1",
			"by_ai": ai}))
	var own: ShowDelta = intr.call("p0", false)
	assert_eq([own.hype, own.stats, own.reasons], [ShowRules.RT_INTERRUPT, {"interrupts_total": 1},
		[&"rt_interrupt"]])
	assert_eq((intr.call("p1", false) as ShowDelta).hype, 0.0, "the partner's interrupt (Partner-Spezial) no")
	assert_eq((intr.call("p0", true) as ShowDelta).hype, 0.0, "the autopilot's no")
	var dodge: Callable = func(target: String, close: bool, ai: bool) -> ShowDelta:
		return _rules.feed(_ev(ActionEvent.Type.TELEGRAPH_DODGED, {"target_id": target, "success": close,
			"by_ai": ai}))
	assert_eq((dodge.call("p0", false, false) as ShowDelta).hype, ShowRules.RT_DODGE)
	var close: ShowDelta = dodge.call("p0", true, false)
	assert_eq([close.hype, close.stats, close.reasons], [ShowRules.RT_DODGE_CLOSE, {"dodges_total": 1},
		[&"rt_dodge_close"]])
	assert_eq((dodge.call("p0", true, true) as ShowDelta).hype, 0.0, "a sim-driven dodge no")
	assert_eq((dodge.call("p1", true, false) as ShowDelta).hype, 0.0, "the partner's no")
	var sw: ShowDelta = _rules.feed(_ev(ActionEvent.Type.CONTROL_CHANGED, {"actor_id": "p0", "target_id": "p1"}))
	assert_eq(sw.reasons, [&"rt_control_switch:mopsula"])
	assert_eq(_rules.controlled_id(), "p1")
	assert_eq((intr.call("p1", false) as ShowDelta).hype, ShowRules.RT_INTERRUPT, "now the Graf is the person's")
	assert_eq((intr.call("p0", false) as ShowDelta).hype, 0.0)


func test_show_results_for_the_party_stats_for_the_person() -> void:
	var ai: ShowDelta = _rules.feed(_ev(ActionEvent.Type.STUNT_RESULT, {"actor_id": "p1", "success": true,
		"by_ai": true, "skill_id": "skl_stunt_mop_entrance"}))
	assert_eq([ai.hype, ai.stats, ai.triggers], [ShowRules.RT_SHOW_SUCCESS, {}, []],
		"the AI's SHOW: hype for the party, no own SHOW (E27)")
	var own: ShowDelta = _rules.feed(_ev(ActionEvent.Type.STUNT_RESULT, {"actor_id": "p0", "success": true,
		"skill_id": "skl_stunt_kai_suplex"}))
	assert_eq([own.hype, own.stats], [ShowRules.RT_SHOW_SUCCESS, {"stunts_success": 1}])
	assert_eq(own.triggers[0]["trigger"], "stunt_resolved")
	var fail: ShowDelta = _rules.feed(_ev(ActionEvent.Type.STUNT_RESULT, {"actor_id": "p0", "success": false,
		"skill_id": "skl_stunt_kai_suplex"}))
	assert_eq([fail.hype, fail.stats], [ShowRules.RT_SHOW_FAIL, {"stunts_fail": 1}])
	assert_eq(_rules.stunts_succeeded(), 1)


func test_boss_moments_low_hp_ko_revive_flight() -> void:
	assert_eq(_hype(_ev(ActionEvent.Type.PHASE_CHANGE, {"actor_id": "e0", "value": 2, "success": true})),
		ShowRules.RT_PERFECT_PHASE)
	assert_eq(_hype(_ev(ActionEvent.Type.PHASE_CHANGE, {"actor_id": "e0", "value": 3})), 0.0)
	assert_eq(_hype(_ev(ActionEvent.Type.ENRAGE, {"actor_id": "e0", "value": 1})), ShowRules.RT_ENRAGE)
	assert_eq(_hype(_ev(ActionEvent.Type.ENRAGE, {"actor_id": "e0", "value": 2})), 0.0, "once")
	assert_eq(_hype(_ev(ActionEvent.Type.BATTLE_END, {"value": 0, "success": true})), ShowRules.RT_PERFECT_PHASE)
	var low: ActionEvent = _ev(ActionEvent.Type.DAMAGE, {"actor_id": "e0", "target_id": "p0", "amount": 400,
		"hp_after": 50, "max_hp": 400})
	assert_eq(_hype(low), ShowRules.HYPE_LOW_HP)
	assert_eq(_hype(low), 0.0, "once per member")
	var ko: ShowDelta = _rules.feed(_ev(ActionEvent.Type.KO, {"actor_id": "e0", "target_id": "p1", "def_id": "mopsula",
		"command": -1}))
	assert_eq([ko.hype, ko.stats, ko.reasons], [ShowRules.HYPE_PARTY_KO, {"ko_mopsula": 1}, [&"mopsula_ko"]])
	assert_eq(_hype(_ev(ActionEvent.Type.REVIVE, {"target_id": "p1", "hp_after": 100})), ShowRules.HYPE_REVIVE)
	assert_eq(_hype(_ev(ActionEvent.Type.FLEE_RESULT, {"actor_id": "p0", "success": true})), ShowRules.HYPE_FLEE_OK)


func test_boredom_and_drag_run_on_seconds() -> void:
	var r: ShowRules = ShowRules.new(RtKit.data(), RtKit.setup(RtKit.state(6), RtKit.canned_encounter()))
	r.feed(_ev(ActionEvent.Type.BATTLE_START))
	var per_sec: Array = []
	for s in range(1, 14):
		per_sec.append(r.feed(_ev(ActionEvent.Type.SECOND, {"value": s})).hype)
	assert_eq(per_sec, [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, ShowRules.RT_BORING, 0.0, 0.0, 0.0, 0.0, 0.0,
		ShowRules.RT_BORING], "−2 after every 6 s without a positive event (the start bonus counted for second 1)")
	var drag: Callable = func(boss: bool, sec: int) -> float:
		var s2: RtSetup = RtKit.setup(RtKit.state(6), RtKit.canned_encounter())
		s2.is_boss = boss
		var r2: ShowRules = ShowRules.new(RtKit.data(), s2)
		r2.feed(_ev(ActionEvent.Type.COMBO, {"actor_id": "p0"}))        # a positive event: no boredom here
		return r2.feed(_ev(ActionEvent.Type.SECOND, {"value": sec})).hype
	assert_eq([drag.call(false, 44), drag.call(false, 45), drag.call(false, 50), drag.call(false, 55)],
		[0.0, ShowRules.RT_DRAG, 0.0, ShowRules.RT_DRAG], "−3 every 10 s from 45 s")
	assert_eq([drag.call(true, 45), drag.call(true, 240)], [0.0, ShowRules.RT_DRAG], "bosses from 4:00")


func test_taunts_and_presentation_tags() -> void:
	assert_eq(_rules.feed(_act("p0", "skl_kai_taunt", false)).stats, {"taunts_total": 1}, "the person's taunt")
	assert_eq(_rules.feed(_act("p0", "skl_kai_taunt", true)).stats, {}, "an AI taunt reveals nothing")
	var fin: ShowDelta = _rules.feed(_act("p0", "skl_kai_prime_finisher", false, K.STUNT))
	assert_has(fin.reasons, &"rt_finale")
	assert_eq(_rules.feed(_ev(ActionEvent.Type.FLEE_WARNING, {"actor_id": "p0", "value": 30})).reasons,
		[&"rt_flee_warn"])
	assert_eq(_rules.feed(_ev(ActionEvent.Type.TELEGRAPH_IMPACT, {"actor_id": "e1",
		"target_ids": ["p1", "p0"]})).reasons, [&"rt_telegraph_hit"])
	assert_eq(_rules.feed(_ev(ActionEvent.Type.PRESET_CHANGED, {"actor_id": "p1", "text": "careful"})).reasons,
		[&"rt_partner_preset:careful"])
	var heal_cast: ActionEvent = _ev(ActionEvent.Type.CAST_START, {"actor_id": "e1", "skill_id": "skl_mop_holy_lick"})
	assert_eq(_rules.feed(heal_cast).reasons, [&"rt_healer_first"], "the first heal cast of an enemy")
	assert_eq(_rules.feed(heal_cast).reasons, [], "once per combat")


## Show (07 §9.3): in a real-time combat at most one non-blocking line per 6 s unless it ranks higher
## (boss_phase / rt_enrage > a party KO > rt_control_switch > interrupt / close dodge / train kill > the rest);
## blocking lines are free; CTB battles keep their pacing.
func test_line_rate_in_a_real_time_combat() -> void:
	assert_eq([Show.rt_line_priority("boss_phase:enm_x:2"), Show.rt_line_priority("rt_enrage:enm_x"),
		Show.rt_line_priority("kai_ko"), Show.rt_line_priority("rt_control_switch:kai"),
		Show.rt_line_priority("rt_interrupt"), Show.rt_line_priority("rt_train_kill"), Show.rt_line_priority("crit")],
		[4, 4, 3, 2, 1, 1, 0])
	Game.state = RtKit.state(6)
	Show.begin_battle(RtKit.setup(Game.state, RtKit.canned_encounter()))
	assert_true(Show._rt_combat())
	Show._now = 100.0
	Show._rt_line_said("crit", false)
	assert_true(Show._rt_line_blocked("weakness", false), "the same rank within 6 s is dropped")
	assert_false(Show._rt_line_blocked("rt_interrupt", false), "a higher rank speaks")
	assert_false(Show._rt_line_blocked("weakness", true), "blocking lines are free")
	Show._now = 106.1
	assert_false(Show._rt_line_blocked("weakness", false), "6 s later")
	Show.abort_battle()
	Show.begin_battle(BattleSetup.new())
	Show._rt_line_said("crit", false)
	assert_false(Show._rt_line_blocked("weakness", false), "CTB: no real-time rate")
