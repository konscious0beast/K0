extends TestCase
## M2 show system (02_TECH §6.1/§6.2, §3.5, GDD §7): ShowModel formulas, ShowRules hype table row by row,
## SponsorSystem thresholds / weights / pick, ModAnnouncer, and the Show autoload (hype, viewers, followers,
## sponsor gift flow 70/85/100 with limits 1/2 and reset to 80, external gift queue, end of battle).

const Fx := preload("res://tests/test_m2_fixtures.gd")
const K := BattleCommand.Kind


class _SpyLog extends RunLog:
	var entries: Array[Dictionary] = []

	func add_cmd(tick: int, cmd: Dictionary, cmd_id: int = 0) -> void:
		entries.append({"k": tick, "id": cmd_id, "c": cmd})


var _prev_data: GameData = null


func before_each() -> void:
	_prev_data = null


func after_each() -> void:
	if _prev_data != null:
		Fx.end_world(_prev_data)
		_prev_data = null


func _world(seed: int = 77) -> void:
	_prev_data = Fx.begin_world(seed)


# --- builders ---------------------------------------------------------------------------------------------------------

static func _comb(id: String, def_id: String, hp: int, max_hp: int, mp: int = 10, max_mp: int = 10) -> Combatant:
	var c: Combatant = Combatant.new()
	c.id = id
	c.def_id = def_id
	c.side = Combatant.Side.PARTY if id.begins_with("p") else Combatant.Side.ENEMY
	c.hp = hp
	c.mp = mp
	var sb: StatBlock = StatBlock.new()
	sb.values = PackedInt32Array([max_hp, max_mp, 10, 10, 10, 10, 10, 10])
	c.stats = sb
	return c


static func _setup(is_boss: bool = false, adv: BattleSetup.Advantage = BattleSetup.Advantage.NORMAL) -> BattleSetup:
	var s: BattleSetup = BattleSetup.new()
	s.encounter_id = "enc_f1_qb" if is_boss else "enc_f1_a"
	s.is_boss = is_boss
	s.advantage = adv
	s.party = [_comb("p0", "kai", 70, 70), _comb("p1", "mopsula", 42, 42)]
	return s


static func _ev(t: ActionEvent.Type, fields: Dictionary = {}) -> ActionEvent:
	var e: ActionEvent = ActionEvent.new()
	e.type = t
	for k: String in fields:
		e.set(k, fields[k])
	return e


static func _act(actor: String, cmd: int, skill: String = "", item: String = "") -> ActionEvent:
	return _ev(ActionEvent.Type.ACTION_START, {"actor_id": actor, "command": cmd, "skill_id": skill, "item_id": item})


static func _end(actor: String) -> ActionEvent:
	return _ev(ActionEvent.Type.TURN_END, {"actor_id": actor})


static func _ko(target: String, def_id: String, killer: String, skill: String = "",
		overkill: bool = false) -> ActionEvent:
	return _ev(ActionEvent.Type.KO, {"target_id": target, "def_id": def_id, "actor_id": killer, "skill_id": skill,
		"value": 1 if overkill else 0})


static func _result(outcome: BattleResult.Outcome) -> BattleResult:
	var r: BattleResult = BattleResult.new()
	r.outcome = outcome
	r.encounter_id = "enc_f1_a"
	r.group_id = "f1_g1"
	r.party_turns = 4
	r.min_party_hp = 30
	r.min_party_hp_pct = 0.5
	r.damage_taken = 20
	return r


func _rules(is_boss: bool = false) -> ShowRules:
	return ShowRules.new(Fx.data(), _setup(is_boss))


# --- ShowModel --------------------------------------------------------------------------------------------------------

func test_viewer_formula() -> void:
	assert_eq(ShowModel.viewers_for(1.0, 30.0, 0), 1150, "(1000) × (0.4 + 0.75)")
	assert_eq(ShowModel.viewers_for(1.0, 0.0, 0), 400, "hype 0 → 0.4×")
	assert_eq(ShowModel.viewers_for(1.0, 50.0, 0), 1650, "hype 50 → 1.65×")
	assert_eq(ShowModel.viewers_for(1.0, 100.0, 1500), 5075, "GDD §13 check value: (1000 + 0.5 × 1500) × 2.9")
	assert_eq(ShowModel.viewers_for(1.5, 50.0, 100), 2558, "floor_mult 1.5: (1500 + 50) × 1.65 = 2557.5 → 2558")
	assert_eq(ShowModel.viewers_for(1.0, 37.0, 6), 1329, "1003 × 1.325 = 1328.975 → 1329")
	assert_eq(ShowModel.viewers_for(1.0, 150.0, -5), 2900, "hype clamped, negative followers ignored")


func test_follower_formulas() -> void:
	assert_eq(ShowModel.followers_for_battle(4000, 50.0, false, 1.0), 56, "4000 × (0.007 + 0.007)")
	assert_eq(ShowModel.followers_for_battle(4000, 50.0, true, 1.0), 112, "boss × 2")
	assert_eq(ShowModel.followers_for_battle(4000, 50.0, false, 1.15), 64, "clip mic × 1.15: 64.4 → 64")
	assert_eq(ShowModel.followers_for_battle(4000, 0.0, false, 1.0), 28, "hype 0 → 0.7 %")
	assert_eq(ShowModel.followers_for_battle(1275, 35.0, false, 1.0), 15, "floori(1275 × 0.0119 = 15.17)")
	assert_eq(ShowModel.followers_for_battle(0, 100.0, true, 1.0), 0)
	assert_eq(ShowModel.followers_lost_on_flee(1234), 12, "floori(1 %)")
	assert_eq(ShowModel.followers_lost_on_flee(99), 0)
	assert_eq(ShowModel.followers_lost_on_flee(0), 0)


func test_hype_decay_and_clamp() -> void:
	assert_eq(ShowModel.decay_step(30.0), 29.0, "5 over the floor: 10 % rounds down to 0 → at least −1")
	assert_eq(ShowModel.decay_step(45.0), 43.0, "20 over the floor → −2")
	assert_eq(ShowModel.decay_step(85.0), 79.0, "60 over the floor → −6: hot shows cool faster")
	assert_eq(ShowModel.decay_step(100.0), 93.0, "75 × 10 % = 7.5 → −7 (integer per mille)")
	assert_eq(ShowModel.decay_step(25.5), 25.0, "never below 25")
	assert_eq(ShowModel.decay_step(25.0), 25.0)
	assert_eq(ShowModel.decay_step(10.0), 10.0, "below the floor: unchanged")
	assert_eq(ShowModel.clamp_hype(120.0), 100.0)
	assert_eq(ShowModel.clamp_hype(-5.0), 0.0)
	assert_eq(ShowModel.HYPE_DECAY_TICKS, 60, "one cooling step per 2 s at 30 ticks/s")
	assert_eq(ShowModel.HYPE_EXPLORE_FLOOR, 25.0)
	var h: float = 85.0
	for i in 15:                                          # 30 s of exploration
		h = ShowModel.decay_step(h)
	assert_between(h, 38.0, 45.0, "a hot fight end (85) loses most of its excess within 30 s of exploration")
	for i in 15:                                          # another 30 s
		h = ShowModel.decay_step(h)
	assert_between(h, 25.0, 30.0, "and is back near the floor after a minute")


# --- ShowRules: hype table §6.2 row by row ----------------------------------------------------------------------------

func test_rules_battle_start_hype() -> void:
	var cases: Array = [[false, BattleSetup.Advantage.NORMAL, 3.0], [false, BattleSetup.Advantage.PREEMPTIVE, 3.0],
		[false, BattleSetup.Advantage.AMBUSH, 5.0], [true, BattleSetup.Advantage.PREEMPTIVE, 8.0],
		[true, BattleSetup.Advantage.NORMAL, 8.0]]
	for c: Array in cases:
		var r: ShowRules = ShowRules.new(Fx.data(), _setup(c[0], c[1]))
		assert_eq(r.feed(_ev(ActionEvent.Type.BATTLE_START)).hype, c[2], "start hype %s" % str(c))
		assert_eq(r.feed(_ev(ActionEvent.Type.BATTLE_START)).hype, 0.0, "only once per battle")
		assert_eq(r.start_delta().hype, 0.0)


func test_rules_variety_repetition_and_boring() -> void:
	var r: ShowRules = _rules()
	assert_eq(r.feed(_act("p0", K.ATTACK)).hype, 2.0, "first party action: variety +2")
	assert_eq(r.feed(_end("p0")).hype, 0.0, "positive event in this turn → not boring")
	assert_eq(r.feed(_act("p1", K.ATTACK)).hype, 0.0, "same key: no variety, 2nd in a row")
	assert_eq(r.feed(_end("p1")).hype, -3.0, "turn without positive event → boring −3")
	var third: ShowDelta = r.feed(_act("p0", K.ATTACK))
	assert_eq(third.hype, -5.0, "3rd identical key in a row (whoever) → −5")
	assert_has(third.reasons, &"boring_fight")
	r.feed(_end("p0"))
	assert_eq(r.feed(_act("p1", K.ATTACK)).hype, -5.0, "and every further time")
	r.feed(_end("p1"))
	assert_eq(r.feed(_act("p0", K.SKILL, "skl_kai_heavy_swing")).hype, 2.0, "new key → variety")
	r.feed(_end("p0"))
	# window of the last 4 party keys: B C D E then A again → variety
	var r2: ShowRules = _rules()
	var keys: Array = [[K.ATTACK, ""], [K.SKILL, "skl_kai_heavy_swing"], [K.STUNT, "skl_stunt_kai_suplex"],
		[K.FLEE, ""], [K.SKILL, "skl_mop_flame"]]
	for k: Array in keys:
		assert_eq(r2.feed(_act("p0", k[0], k[1])).hype, 2.0, "distinct key %s" % str(k))
		r2.feed(_end("p0"))
	assert_eq(r2.feed(_act("p0", K.ATTACK)).hype, 2.0, "attack no longer among the last 4 keys")
	r2.feed(_end("p0"))
	assert_eq(r2.feed(_act("p1", K.STUNT, "skl_stunt_kai_suplex")).hype, 0.0, "stunt among the last 4")


func test_rules_skill_hype_defend_twice_and_drag() -> void:
	var r: ShowRules = _rules()
	assert_eq(r.feed(_act("p0", K.ITEM, "skl_item_megaphone", "itm_megaphone")).hype, 27.0, "variety +2, item hype +25")
	r.feed(_end("p0"))
	assert_eq(r.feed(_act("p0", K.DEFEND)).hype, 2.0)
	r.feed(_end("p0"))
	assert_eq(r.feed(_act("p1", K.ATTACK)).hype, 2.0)
	r.feed(_end("p1"))
	assert_eq(r.feed(_act("p0", K.DEFEND)).hype, -4.0, "defend twice in a row by the same character")
	r.feed(_end("p0"))
	assert_eq(r.feed(_act("p1", K.DEFEND)).hype, 0.0, "other character: no −4 (defend among last keys, run of 2)")
	r.feed(_end("p1"))
	# drag: every party turn after the 10th (boss: 25th) −3; keys cycle over 5 so variety +2 always applies
	var cycle: Array = [[K.ATTACK, "", ""], [K.STUNT, "skl_stunt_kai_suplex", ""], [K.FLEE, "", ""],
		[K.SKILL, "skl_kai_heavy_swing", ""], [K.ITEM, "skl_item_bandage", "itm_bandage"]]
	for boss: bool in [false, true]:
		var rr: ShowRules = _rules(boss)
		var limit: int = 25 if boss else 10
		for i in limit + 2:
			var c: Array = cycle[i % cycle.size()]
			var d: ShowDelta = rr.feed(_act("p0", c[0], c[1], c[2]))
			rr.feed(_end("p0"))
			assert_eq(d.hype, 2.0 if i < limit else -1.0, "party action %d (boss %s)" % [i + 1, str(boss)])


func test_rules_crit_and_weakness() -> void:
	var r: ShowRules = _rules()
	r.feed(_act("p0", K.SKILL, "skl_mop_thunder"))
	var d1: ShowDelta = r.feed(_ev(ActionEvent.Type.DAMAGE, {"actor_id": "p0", "target_id": "e0", "amount": 9,
		"hp_after": 5, "max_hp": 24, "crit": true, "weak": true}))
	assert_eq(d1.hype, 5.0, "crit +3, weak +2")
	assert_eq(d1.stats.get("crits_total", 0), 1)
	assert_has(d1.reasons, &"crit")
	assert_has(d1.reasons, &"weakness")
	var d2: ShowDelta = r.feed(_ev(ActionEvent.Type.DAMAGE, {"actor_id": "p0", "target_id": "e1", "amount": 9,
		"hp_after": 5, "max_hp": 24, "crit": true, "weak": true, "beat": 0}))
	assert_eq(d2.hype, 3.0, "weakness at most once per action, crit per crit")
	var d3: ShowDelta = r.feed(_ev(ActionEvent.Type.DAMAGE, {"actor_id": "e0", "target_id": "p0", "amount": 9,
		"hp_after": 61, "max_hp": 70, "crit": true}))
	assert_eq(d3.hype, 0.0, "enemy crits do not count")
	r.feed(_end("p0"))
	r.feed(_act("p1", K.ATTACK))
	assert_eq(r.feed(_ev(ActionEvent.Type.DAMAGE, {"actor_id": "p1", "target_id": "e0", "amount": 3, "hp_after": 2,
		"max_hp": 24, "weak": true})).hype, 2.0, "next action: weakness again")


func test_rules_kills_overkill_streak() -> void:
	var r: ShowRules = _rules()
	r.feed(_act("p0", K.ATTACK))
	var k1: ShowDelta = r.feed(_ko("e0", "enm_rat", "p0", "skl_attack_kai"))
	assert_eq(k1.hype, 1.0, "attack kill +1")
	assert_eq(k1.stats, {"kills_total": 1})
	assert_eq(k1.triggers, [{"trigger": "enemy_killed",
		"payload": {"enemy_id": "enm_rat", "overkill": false, "by": "attack", "member": "kai"}}])
	r.feed(_end("p0"))
	r.feed(_act("p1", K.SKILL, "skl_mop_flame"))
	var k2: ShowDelta = r.feed(_ko("e1", "enm_rat", "p1", "skl_mop_flame"))
	assert_eq(k2.hype, 2.0, "skill kill +2")
	assert_eq(k2.stats, {"kills_total": 1, "kills_skill": 1})
	assert_eq(k2.triggers[0]["payload"]["member"], "mopsula")
	r.feed(_end("p1"))
	r.feed(_act("p0", K.SKILL, "skl_kai_finisher"))
	var k3: ShowDelta = r.feed(_ko("e2", "enm_boss", "p0", "skl_kai_finisher", true))
	assert_eq(k3.hype, 20.0, "skill +2, kill_hype +10, overkill +3, kill streak +5 (3 kills in 3 party actions)")
	assert_has(k3.reasons, &"overkill")
	assert_has(k3.reasons, &"kill_streak")
	assert_eq(k3.triggers[0]["payload"]["overkill"], true)
	r.feed(_end("p0"))
	r.feed(_act("p1", K.ITEM, "skl_item_molotov", "itm_molotov"))
	var k4: ShowDelta = r.feed(_ko("e3", "enm_rat", "p1", "skl_item_molotov"))
	assert_eq(k4.hype, 1.0, "item kill counts like attack; streak window restarted")
	assert_eq(k4.triggers[0]["payload"]["by"], "item")
	r.feed(_end("p1"))
	r.feed(_act("p0", K.STUNT, "skl_stunt_kai_suplex"))
	var k5: ShowDelta = r.feed(_ko("e4", "enm_rat", "p0", "skl_stunt_kai_suplex"))
	assert_eq(k5.hype, 4.0, "stunt kill +4")
	assert_eq(k5.triggers[0]["payload"]["by"], "stunt")
	r.feed(_end("p0"))
	var k6: ShowDelta = r.feed(_ko("e5", "enm_rat", ""))
	assert_eq(k6.hype, 0.0, "status-tick kill: no kill hype")
	assert_eq(k6.stats, {"kills_total": 1})
	assert_eq(k6.triggers[0]["payload"], {"enemy_id": "enm_rat", "overkill": false, "by": "attack", "member": ""},
		"no known source: 'by' stays within attack/skill/stunt/item (§6.3)")


func test_rules_status_kill_is_credited_to_the_applying_party_action() -> void:
	var r: ShowRules = _rules()
	var by_values: Array = []
	r.feed(_act("p1", K.SKILL, "skl_mop_flame"))
	r.feed(_ev(ActionEvent.Type.STATUS_ADDED, {"target_id": "e0", "status_id": "sts_burn", "value": 3}))
	r.feed(_end("p1"))
	r.feed(_act("e0", K.ATTACK))
	r.feed(_end("e0"))
	r.feed(_ev(ActionEvent.Type.DAMAGE, {"target_id": "e0", "status_id": "sts_burn", "amount": 3, "hp_after": 0,
		"max_hp": 24}))
	var k1: ShowDelta = r.feed(_ko("e0", "enm_rat", ""))
	assert_eq(k1.hype, 0.0, "tick kill: no kill hype (not a party action)")
	assert_eq(k1.stats, {"kills_total": 1, "kills_skill": 1}, "credited to Mopsula's skill")
	assert_eq(k1.triggers[0]["payload"], {"enemy_id": "enm_rat", "overkill": false, "by": "skill", "member": "mopsula"})
	by_values.append(k1.triggers[0]["payload"]["by"])
	r.feed(_act("p0", K.ITEM, "skl_item_molotov", "itm_molotov"))
	r.feed(_ev(ActionEvent.Type.STATUS_ADDED, {"target_id": "e1", "status_id": "sts_burn", "value": 3}))
	r.feed(_end("p0"))
	r.feed(_ev(ActionEvent.Type.DAMAGE, {"target_id": "e1", "status_id": "sts_burn", "amount": 3, "hp_after": 0,
		"max_hp": 24}))
	var k2: ShowDelta = r.feed(_ko("e1", "enm_rat", ""))
	assert_eq(k2.triggers[0]["payload"]["by"], "item")
	assert_eq(k2.triggers[0]["payload"]["member"], "kai")
	by_values.append(k2.triggers[0]["payload"]["by"])
	# applied by a party action, then re-applied outside one (enemy turn): the party no longer owns the status
	r.feed(_act("p0", K.SKILL, "skl_mop_flame"))
	r.feed(_ev(ActionEvent.Type.STATUS_ADDED, {"target_id": "e2", "status_id": "sts_poison", "value": 3}))
	r.feed(_end("p0"))
	r.feed(_act("e3", K.SKILL, "skl_mop_flame"))
	r.feed(_ev(ActionEvent.Type.STATUS_ADDED, {"target_id": "e2", "status_id": "sts_poison", "value": 3}))
	r.feed(_end("e3"))
	r.feed(_ev(ActionEvent.Type.DAMAGE, {"target_id": "e2", "status_id": "sts_poison", "amount": 3, "hp_after": 0,
		"max_hp": 24}))
	var k3: ShowDelta = r.feed(_ko("e2", "enm_rat", ""))
	assert_eq(k3.stats, {"kills_total": 1})
	assert_eq(k3.triggers[0]["payload"], {"enemy_id": "enm_rat", "overkill": false, "by": "attack", "member": ""})
	by_values.append(k3.triggers[0]["payload"]["by"])
	for by: Variant in by_values:
		assert_has(["attack", "skill", "stunt", "item"], by, "documented 'by' values only")


## M2 verify: a non-lethal status tick must not credit a LATER actor-less KO of the same enemy to the old status
## source — the tick entry is cleared by any other damage and consumed by the KO right after a lethal tick.
func test_rules_stale_status_tick_is_not_credited_later() -> void:
	var r: ShowRules = _rules()
	r.feed(_act("p1", K.SKILL, "skl_mop_flame"))
	r.feed(_ev(ActionEvent.Type.STATUS_ADDED, {"target_id": "e0", "status_id": "sts_burn", "value": 3}))
	r.feed(_end("p1"))
	r.feed(_ev(ActionEvent.Type.DAMAGE, {"target_id": "e0", "status_id": "sts_burn", "amount": 3, "hp_after": 9,
		"max_hp": 24}))
	# the next damage on e0 is no tick (e.g. a pseudo unit / counter without party actor) and kills it
	r.feed(_ev(ActionEvent.Type.DAMAGE, {"target_id": "e0", "amount": 9, "hp_after": 0, "max_hp": 24}))
	var k1: ShowDelta = r.feed(_ko("e0", "enm_rat", ""))
	assert_eq(k1.stats, {"kills_total": 1}, "not credited to Mopsula's old burn")
	assert_eq(k1.triggers[0]["payload"]["member"], "")
	# a lethal tick is still credited, once
	r.feed(_act("p1", K.SKILL, "skl_mop_flame"))
	r.feed(_ev(ActionEvent.Type.STATUS_ADDED, {"target_id": "e1", "status_id": "sts_burn", "value": 3}))
	r.feed(_end("p1"))
	r.feed(_ev(ActionEvent.Type.DAMAGE, {"target_id": "e1", "status_id": "sts_burn", "amount": 3, "hp_after": 0,
		"max_hp": 24}))
	var k2: ShowDelta = r.feed(_ko("e1", "enm_rat", ""))
	assert_eq(k2.triggers[0]["payload"]["member"], "mopsula")
	var k3: ShowDelta = r.feed(_ko("e1", "enm_rat", ""))
	assert_eq(k3.triggers[0]["payload"]["member"], "", "the tick entry was consumed by the first KO")


func test_rules_combo_and_stunts() -> void:
	var r: ShowRules = _rules()
	r.feed(_act("p1", K.SKILL, "skl_mop_flame"))
	var c: ShowDelta = r.feed(_ev(ActionEvent.Type.COMBO, {"actor_id": "p1", "target_id": "e0", "def_id": "enm_rat"}))
	assert_eq(c.hype, 2.0)
	assert_eq(c.triggers, [{"trigger": "combo", "payload": {"member": "mopsula", "enemy_id": "enm_rat"}}])
	r.feed(_end("p1"))
	r.feed(_act("p0", K.STUNT, "skl_stunt_kai_suplex"))
	var ok: ShowDelta = r.feed(_ev(ActionEvent.Type.STUNT_RESULT, {"actor_id": "p0", "skill_id": "skl_stunt_kai_suplex",
		"success": true}))
	assert_eq(ok.hype, 12.0)
	assert_eq(ok.stats, {"stunts_success": 1})
	assert_eq(ok.triggers, [{"trigger": "stunt_resolved",
		"payload": {"success": true, "member": "kai", "skill_id": "skl_stunt_kai_suplex"}}])
	assert_has(ok.reasons, &"stunt_success")
	var fail: ShowDelta = r.feed(_ev(ActionEvent.Type.STUNT_RESULT, {"actor_id": "p0",
		"skill_id": "skl_stunt_kai_suplex", "success": false}))
	assert_eq(fail.hype, 4.0, "even a failed stunt is good TV")
	assert_eq(fail.stats, {"stunts_fail": 1})
	assert_eq(r.stunts_succeeded(), 1)


func test_rules_party_low_hp_ko_revive_flee() -> void:
	var r: ShowRules = _rules()
	var hit: Dictionary = {"actor_id": "e0", "target_id": "p1", "amount": 22, "hp_after": 20, "max_hp": 42}
	assert_eq(r.feed(_ev(ActionEvent.Type.DAMAGE, hit)).hype, 0.0, "20/42 is above 25 %")
	hit["hp_after"] = 9
	var low: ShowDelta = r.feed(_ev(ActionEvent.Type.DAMAGE, hit))
	assert_eq(low.hype, 6.0, "falls under 25 % for the first time")
	assert_has(low.reasons, &"low_hp")
	hit["hp_after"] = 5
	assert_eq(r.feed(_ev(ActionEvent.Type.DAMAGE, hit)).hype, 0.0, "already under")
	r.feed(_ev(ActionEvent.Type.HEAL, {"actor_id": "p0", "target_id": "p1", "amount": 30, "hp_after": 35, "max_hp": 42}))
	hit["hp_after"] = 8
	assert_eq(r.feed(_ev(ActionEvent.Type.DAMAGE, hit)).hype, 0.0, "once per member and battle")
	var ko: ShowDelta = r.feed(_ko("p1", "mopsula", "e0"))
	assert_eq(ko.hype, 10.0)
	assert_eq(ko.stats, {"ko_mopsula": 1})
	assert_eq(ko.triggers, [{"trigger": "party_ko", "payload": {"member": "mopsula"}}])
	assert_has(ko.reasons, &"mopsula_ko")
	var ko_kai: ShowDelta = r.feed(_ko("p0", "kai", "e0"))
	assert_eq(ko_kai.stats, {}, "only Mopsula counts for ko_mopsula")
	assert_has(ko_kai.reasons, &"kai_ko")
	var rev: ShowDelta = r.feed(_ev(ActionEvent.Type.REVIVE, {"target_id": "p1", "hp_after": 12, "max_hp": 42}))
	assert_eq(rev.hype, 8.0)
	assert_has(rev.reasons, &"revive")
	var ff: ShowDelta = r.feed(_ev(ActionEvent.Type.FLEE_RESULT, {"actor_id": "p0", "success": false}))
	assert_eq(ff.hype, -5.0)
	assert_has(ff.reasons, &"flee_fail")
	var fl: ShowDelta = r.feed(_ev(ActionEvent.Type.FLEE_RESULT, {"actor_id": "p0", "success": true}))
	assert_eq(fl.hype, -30.0)
	assert_has(fl.reasons, &"flee")


func test_rules_delta_keeps_positive_and_negative_parts() -> void:
	var cycle: Array = [[K.ATTACK, "", ""], [K.STUNT, "skl_stunt_kai_suplex", ""], [K.FLEE, "", ""],
		[K.SKILL, "skl_kai_heavy_swing", ""], [K.ITEM, "skl_item_bandage", "itm_bandage"]]
	var r: ShowRules = _rules()
	var d: ShowDelta = null
	for i in 11:
		var c: Array = cycle[i % cycle.size()]
		d = r.feed(_act("p0", c[0], c[1], c[2]))
		r.feed(_end("p0"))
	assert_eq([d.hype, d.hype_gain, d.hype_loss], [-1.0, 2.0, -3.0], "11th action: variety +2 and drag −3 kept apart")
	var start: ShowDelta = r.start_delta()
	assert_eq([start.hype, start.hype_gain, start.hype_loss], [3.0, 3.0, 0.0], "battle start: gain only")
	var k: ShowDelta = _rules().feed(_ev(ActionEvent.Type.FLEE_RESULT, {"actor_id": "p0", "success": true}))
	assert_eq([k.hype, k.hype_gain, k.hype_loss], [-30.0, 0.0, -30.0])


func test_rules_end_delta() -> void:
	var r: ShowRules = _rules()
	var res: BattleResult = _result(BattleResult.Outcome.VICTORY)
	res.min_party_hp_pct = 0.10
	assert_eq(r.end_delta(res).hype, 15.0, "close win (≤ 10 %)")
	res.min_party_hp_pct = 0.11
	assert_eq(r.end_delta(res).hype, 0.0)
	res.damage_taken = 0
	assert_eq(r.end_delta(res).hype, 3.0, "flawless")
	res.outcome = BattleResult.Outcome.DEFEAT
	assert_eq(r.end_delta(res).hype, 0.0, "only victories")
	assert_eq(r.end_delta(null).hype, 0.0)
	assert_not_null(r.feed(null), "feed never returns null")


# --- SponsorSystem ----------------------------------------------------------------------------------------------------

func test_sponsor_thresholds_crossed() -> void:
	assert_eq(SponsorSystem.crossed(65.0, 75.0, []), [70])
	assert_eq(SponsorSystem.crossed(65.0, 100.0, []), [70, 85, 100], "several at once, ascending")
	assert_eq(SponsorSystem.crossed(65.0, 100.0, [70]), [85, 100], "each threshold once per battle")
	assert_eq(SponsorSystem.crossed(69.0, 70.0, []), [70], "reaching the value counts")
	assert_eq(SponsorSystem.crossed(70.0, 80.0, []), [], "not from below")
	assert_eq(SponsorSystem.crossed(90.0, 40.0, []), [], "downwards never")
	assert_eq(SponsorSystem.crossed(30.0, 69.0, []), [], "a routine fight (30 → 69) brings no sponsor")
	assert_eq(SponsorSystem.THRESHOLDS, [70, 85, 100])
	assert_eq([SponsorSystem.MAX_GIFTS_PER_BATTLE, SponsorSystem.MAX_GIFTS_PER_BOSS_BATTLE], [1, 2])
	assert_eq([SponsorSystem.HYPE_COST, SponsorSystem.HYPE_AFTER_TOP], [0.0, 80.0])


func test_sponsor_weight_mods() -> void:
	var d: GameData = Fx.data()
	var full: Array = [_comb("p0", "kai", 70, 70, 10, 10), _comb("p1", "mopsula", 42, 42, 30, 30)]
	var hurt: Array = [_comb("p0", "kai", 28, 70, 10, 10), _comb("p1", "mopsula", 42, 42, 30, 30)]
	var ko: Array = [_comb("p0", "kai", 70, 70), _comb("p1", "mopsula", 0, 42)]
	var no_mp: Array = [_comb("p0", "kai", 70, 70, 10, 10), _comb("p1", "mopsula", 42, 42, 5, 30)]
	assert_eq(SponsorSystem.weight_of(d.sponsor("spn_heal"), {"party": full}), 3.0)
	assert_eq(SponsorSystem.weight_of(d.sponsor("spn_heal"), {"party": hurt}), 9.0, "ally under 50 % HP: × 3")
	assert_eq(SponsorSystem.weight_of(d.sponsor("spn_heal"), {"party": ko}), 3.0, "KO is not 'living under 50 %'")
	assert_eq(SponsorSystem.weight_of(d.sponsor("spn_revive"), {"party": ko}), 6.0, "ally KO: × 6")
	assert_eq(SponsorSystem.weight_of(d.sponsor("spn_mana"), {"party": no_mp}), 4.0, "ally under 30 % MP: × 2")
	assert_eq(SponsorSystem.weight_of(d.sponsor("spn_slow"), {"party": full, "is_boss": true}), 4.0, "boss: × 2")
	assert_eq(SponsorSystem.weight_of(d.sponsor("spn_slow"), {"party": full, "is_boss": false}), 2.0)


func test_sponsor_pick_deterministic_weighted_and_floor_range() -> void:
	var d: GameData = Fx.data()
	var ctx: Dictionary = {"floor_index": 1, "is_boss": false, "party": []}
	var a: PackedStringArray = []
	var b: PackedStringArray = []
	var rng_a: RandomNumberGenerator = make_rng(42)
	var rng_b: RandomNumberGenerator = make_rng(42)
	for i in 50:
		a.append(SponsorSystem.pick(d, ctx, rng_a))
		b.append(SponsorSystem.pick(d, ctx, rng_b))
	assert_eq(a, b, "same rng seed → same picks")
	var counts: Dictionary = {}
	var rng: RandomNumberGenerator = make_rng(7)
	for i in 4000:
		var id: String = SponsorSystem.pick(d, ctx, rng)
		counts[id] = int(counts.get(id, 0)) + 1
	assert_false(counts.has("spn_late"), "min_floor 2 sponsor never on floor 1")
	assert_between(int(counts.get("spn_heal", 0)), 1340, 1660, "weight 3 of 8 ≈ 37.5 %")
	assert_between(int(counts.get("spn_revive", 0)), 370, 630, "weight 1 of 8 ≈ 12.5 %")
	ctx["floor_index"] = 2
	var seen_late: bool = false
	for i in 200:
		seen_late = seen_late or SponsorSystem.pick(d, ctx, rng) == "spn_late"
	assert_true(seen_late, "floor 2 includes spn_late")
	assert_eq(SponsorSystem.pick(GameData.new(), ctx, rng), "", "no sponsors → \"\"")


# --- ModAnnouncer -----------------------------------------------------------------------------------------------------

func test_announcer_fallback_filters_and_format() -> void:
	var m: ModAnnouncer = ModAnnouncer.new(Fx.data(), make_rng(3))
	assert_eq(m.pick("achievement:ach_first_blood:extra", 1, 30.0, 0.0).id, "mod_ach_first_blood_01", "a:b:c → a:b")
	assert_eq(m.pick("boss_intro:enm_boss", 1, 30.0, 0.0).id, "mod_boss_intro_01")
	assert_null(m.pick("no_such_tag", 1, 30.0, 0.0))
	assert_eq(m.pick("floor_start", 1, 30.0, 100.0).id, "mod_floor_start_01", "floor 1 line")
	assert_eq(m.pick("floor_start", 2, 30.0, 200.0).id, "mod_floor_start_02", "floor 2 line")
	assert_eq(m.pick("low_hp", 1, 60.0, 300.0).id, "mod_low_hp_hi", "hype ≥ 50 line")
	assert_eq(m.pick("low_hp", 1, 20.0, 400.0).id, "mod_low_hp_lo", "hype ≤ 49 line")
	var line: ModLineDef = Fx.data().mod_lines("floor_start")[0]
	assert_eq(m.format(line, {"floor": 2.0, "name": "Kai"}), "Etage 2! Los, Kai.", "integral floats without .0")
	assert_eq(m.format(line, {"floor": 3}), "Etage 3! Los, {name}.", "missing keys stay visible")
	assert_eq(ModAnnouncer.fallback_chain("a:b:c"), ["a:b:c", "a:b", "a"])
	assert_true(m.has_lines("achievement:ach_first_blood"))
	assert_false(m.has_lines("achievement:ach_other"), "fallback 'achievement' has no lines")


func test_announcer_cooldown_and_no_repeat() -> void:
	var m: ModAnnouncer = ModAnnouncer.new(Fx.data(), make_rng(5))
	assert_not_null(m.pick("crit", 1, 30.0, 0.0))
	assert_null(m.pick("crit", 1, 30.0, 10.0), "20 s key cooldown")
	assert_not_null(m.pick("crit", 1, 30.0, 20.5))
	for tag: String in ["intro", "death", "timer_warn_300", "boss_intro:enm_boss", "chat_hype_mid"]:
		assert_not_null(m.pick(tag, 1, 30.0, 1000.0), tag)
		assert_not_null(m.pick(tag, 1, 30.0, 1000.5), tag + " has no cooldown")
	var last: String = ""
	for i in 8:
		var l: ModLineDef = m.pick("crit", 1, 30.0, 2000.0 + i * 30.0)
		assert_ne(l.id, last, "never the same line twice in a row")
		last = l.id
	assert_eq(ModAnnouncer.priority("death"), 5)
	assert_eq(ModAnnouncer.priority("boss_intro:enm_boss"), 4)
	assert_eq(ModAnnouncer.priority("timer_warn_60"), 3)
	assert_eq(ModAnnouncer.priority("achievement:ach_x"), 2)
	assert_eq(ModAnnouncer.priority("achievement_generic"), 2)
	assert_eq(ModAnnouncer.priority("lootbox_open_gold"), 1)
	assert_eq(ModAnnouncer.priority("crit"), 0)


# --- Show autoload ----------------------------------------------------------------------------------------------------

func test_show_add_hype_gain_mult_rounding_and_hype_100_count() -> void:
	_world()
	assert_eq(Show.hype(), 30.0, "Game.start_floor → hype 30")
	var st: GameState = Game.state
	st.inventory.add("itm_acc_scarf")
	assert_true(Progression.equip(st.member("kai"), st.inventory, Fx.data(), "accessory", "itm_acc_scarf"))
	assert_almost(st.hype_gain_mult(Fx.data()), 1.2)
	var seen: Array = []
	var cb: Callable = func(h: float, d: float, reason: StringName) -> void:
		seen.append([h, d, String(reason), int(Game.state.show.stats.get("hype_100_count", 0))])
	Events.hype_changed.connect(cb)
	Show.add_hype(3.0, &"crit")
	assert_eq(Show.hype(), 34.0, "3 × 1.2 = 3.6 → 4 (whole points)")
	Show.add_hype(-5.0)
	assert_eq(Show.hype(), 29.0, "negative values are not multiplied")
	Show.add_hype(200.0)
	assert_eq(Show.hype(), 100.0, "clamped")
	Show.add_hype(-10.0)
	Show.add_hype(20.0)
	Events.hype_changed.disconnect(cb)
	assert_eq(seen[0], [34.0, 4.0, "crit", 0])
	assert_eq(seen[2], [100.0, 71.0, "", 1], "hype_100_count raised before hype_changed")
	assert_eq(seen[4][3], 2, "reaching 100 from below again counts again")


## GDD §7.3: only positive events are × hype_gain_mult — a mixed-sign action must not net out before scaling.
func test_show_hype_gain_mult_scales_only_the_positive_parts_of_an_action() -> void:
	_world()
	var st: GameState = Game.state
	st.inventory.add("itm_acc_scarf")
	assert_true(Progression.equip(st.member("kai"), st.inventory, Fx.data(), "accessory", "itm_acc_scarf"))
	Show.begin_battle(_setup())
	var cycle: Array = [[K.ATTACK, "", ""], [K.STUNT, "skl_stunt_kai_suplex", ""], [K.FLEE, "", ""],
		[K.SKILL, "skl_kai_heavy_swing", ""], [K.ITEM, "skl_item_bandage", "itm_bandage"]]
	for i in 10:
		var c: Array = cycle[i % cycle.size()]
		Show.on_battle_event(_act("p0", c[0], c[1], c[2]))
		Show.on_battle_event(_end("p0"))
	st.show.hype = 20.0
	Show.on_battle_event(_act("p0", K.ATTACK))
	assert_eq(Show.hype(), 19.0, "11th action: variety +2 × 1.2 = 2.4 → 2, drag −3 unscaled → −1")
	Show.end_battle(_result(BattleResult.Outcome.FLED))
	Show.begin_battle(_setup())
	for i in 2:
		Show.on_battle_event(_act("p0", K.ITEM, "skl_item_megaphone", "itm_megaphone"))
		Show.on_battle_event(_end("p0"))
	st.show.hype = 10.0
	Show.on_battle_event(_act("p0", K.ITEM, "skl_item_megaphone", "itm_megaphone"))
	assert_eq(Show.hype(), 35.0, "3rd megaphone in a row: +25 × 1.2 = 30, repetition −5 → +25 (not 24)")
	Show.end_battle(_result(BattleResult.Outcome.FLED))


func test_show_viewers_changed_is_synchronous_with_stats_first() -> void:
	_world()
	var seen: Array = []
	var cb: Callable = func(v: int) -> void:
		seen.append([v, int(Game.state.show.stats.get("viewers_target_peak", 0)), Show.viewers()])
	Events.viewers_changed.connect(cb)
	Show.add_hype(10.0)
	Show.add_hype(-10.0)
	Events.viewers_changed.disconnect(cb)
	assert_eq(seen, [[1400, 1400, 1400], [1150, 1400, 1150]], "emitted inside add_hype, peak stat first")
	assert_eq(Game.state.show.viewers, 1150)
	assert_eq(Game.state.show.stats["viewers_max"], 1400)
	assert_eq(Game.state.floor_run.stats["viewers_peak"], 1400)
	assert_eq(Show.display_viewers() > 0, true)


func test_show_followers_and_milestones() -> void:
	_world()
	var st: GameState = Game.state
	var reached: Array = []
	var seen: Array = []
	var cb_ms: Callable = func(id: String) -> void: reached.append(id)
	var cb_f: Callable = func(f: int, d: int) -> void:
		seen.append([f, d, int(Game.state.show.stats.get("followers_gained_run", 0))])
	Events.milestone_reached.connect(cb_ms)
	Events.followers_changed.connect(cb_f)
	Show.add_followers(120)
	assert_eq(seen[0], [120, 120, 120], "followers_gained_run before followers_changed")
	assert_eq(reached, ["ms_100"])
	assert_has(st.pending_lootboxes, "box_bronze")
	Show.add_followers(400)
	assert_eq(reached, ["ms_100", "ms_250", "ms_500"])
	assert_eq(st.inventory.credits, 50 + 300, "ms_500 credits via Game.add_rewards")
	Show.add_followers(5000)
	assert_eq(reached, ["ms_100", "ms_250", "ms_500", "ms_1000"], "ms_5000 needs floor 2")
	assert_eq(st.inventory.count("itm_acc_scarf"), 1, "ms_1000 item")
	assert_false(st.flags.has("title_ms_5000"))
	Game.start_floor(2)
	assert_eq(reached.back(), "ms_5000", "reached when entering floor 2")
	assert_eq(st.flags.get("title_ms_5000", false), true, "title flag set directly")
	assert_eq(st.show.milestones, PackedStringArray(["ms_100", "ms_250", "ms_500", "ms_1000", "ms_5000"]))
	var total: int = Show.followers()
	assert_gt(total, 5520, "the viewer achievement on the way added followers too")
	Show.add_followers(-100000)
	assert_eq(Show.followers(), 0, "never negative")
	assert_eq(seen.back()[1], -total)
	assert_eq(st.show.stats["followers_gained_run"], total, "only gains are summed")
	Events.milestone_reached.disconnect(cb_ms)
	Events.followers_changed.disconnect(cb_f)


func test_show_sponsor_gifts_thresholds_limit_and_reset() -> void:
	_world(91)
	Game.in_battle = true
	var triggered: Array = []
	var cb: Callable = func(sid: String) -> void: triggered.append(sid)
	Events.sponsor_gift_triggered.connect(cb)
	Show.begin_battle(_setup())
	assert_eq(Show.take_pending_gift(null), {}, "nothing due")
	Show.add_hype(30.0)                                   # 30 → 60: a routine fight crosses no threshold
	assert_eq(Show.take_pending_gift(null), {}, "below 70: no sponsor")
	Show.add_hype(15.0)                                   # 60 → 75: crosses 70
	var g1: Dictionary = Show.take_pending_gift(null)
	assert_eq(g1.get("kind", ""), "sponsor_buff")
	assert_eq(g1.get("source", ""), "system")
	assert_has(["spn_heal", "spn_mana", "spn_revive", "spn_slow"], str(g1.get("sponsor_id", "")), "floor-1 sponsor")
	assert_eq(Show.take_pending_gift(null), {}, "threshold 70 only once")
	assert_eq(Game.state.show.stats.get("sponsor_gifts", 0), 1)
	assert_true(Show.is_unlocked("ach_sponsor_first"), "trigger sponsor_gift")
	assert_eq(Game.state.show.sponsor_uses.get(str(g1["sponsor_id"]), 0), 1)
	assert_eq(Show.hype(), 80.0, "75 + 5 for ach_sponsor_first")
	Show.add_hype(8.0)                                    # 80 → 88: crosses 85
	assert_eq(Show.take_pending_gift(null), {}, "max. 1 gift per regular battle")
	Show.add_hype(30.0)                                   # → 100: limit reached
	assert_eq(Show.hype(), 80.0, "crossing 100 sets hype to 80 even without gift")
	assert_eq(Show.take_pending_gift(null), {})
	assert_eq(triggered.size(), 1)
	Events.sponsor_gift_triggered.disconnect(cb)
	Show.end_battle(_result(BattleResult.Outcome.VICTORY))


func test_show_boss_battle_two_gifts_and_multi_crossing() -> void:
	_world(5)
	Game.in_battle = true
	Show.begin_battle(_setup(true))
	Show.add_hype(70.0)                                   # 30 → 100: 70, 85, 100 at once
	assert_eq(Show.hype(), 80.0, "both boss slots go to 70 and 85: no slot for 100 → reset to 80 at once")
	var ids: PackedStringArray = []
	for i in 4:
		var g: Dictionary = Show.take_pending_gift(null)
		if g.is_empty():
			break
		ids.append(str(g["gift_id"]))
	assert_eq(ids.size(), 2, "boss: max. 2 gifts, one per take")
	assert_eq(Show.hype(), 85.0, "80 + 5 for ach_sponsor_first (70 and 85 already fired this battle)")
	assert_eq(ids.size(), Array(ids).filter(func(x: String) -> bool: return x.begins_with("g_sys_")).size(),
		"system gift ids g_sys_<battle_n>_<k>")
	Show.end_battle(_result(BattleResult.Outcome.VICTORY))
	# regular battle crossing all three at once: 1 gift, hype reset right away
	Show.begin_battle(_setup(false))
	Game.state.show.hype = 30.0
	Show.add_hype(70.0)
	assert_eq(Show.hype(), 80.0)
	var n: int = 0
	while not Show.take_pending_gift(null).is_empty() and n < 5:
		n += 1
	assert_eq(n, 1)
	Show.end_battle(_result(BattleResult.Outcome.FLED))


func test_show_sponsor_choice_is_deterministic_per_seed() -> void:
	var runs: Array = []
	for r in 2:
		_world(4242)
		Game.in_battle = true
		Show.begin_battle(_setup(true))
		Show.add_hype(70.0)
		var picks: PackedStringArray = []
		for i in 2:
			picks.append(str(Show.take_pending_gift(null).get("sponsor_id", "")))
		runs.append(picks)
		Fx.end_world(_prev_data)
		_prev_data = null
	assert_eq(runs[0], runs[1], "Show rng seeded from Game.next_seed(\"show\")")


func test_show_external_gifts_queue_record_and_duplicates() -> void:
	_world()
	var spy: _SpyLog = _SpyLog.new()
	Game.run_log = spy
	var received: Array = []
	var rejected: Array = []
	var cb_r: Callable = func(g: Dictionary) -> void: received.append(str(g.get("gift_id", "")))
	var cb_x: Callable = func(id: String, reason: String) -> void: rejected.append([id, reason])
	Events.gift_received.connect(cb_r)
	Events.gift_rejected.connect(cb_x)
	Game.in_battle = true
	Show.begin_battle(_setup())
	var g1: Dictionary = _dev_gift(1)
	var g2: Dictionary = _dev_gift(2)
	assert_eq(Show.receive_gift(g1), {"accepted": true, "ok": true, "reason": "", "gift_id": g1["gift_id"],
		"apply": "queued"})
	assert_eq(Show.receive_gift(g2)["apply"], "queued")
	assert_eq(spy.entries.size(), 0, "recorded at application, not on reception")
	assert_eq(Show.receive_gift(g1)["reason"], "duplicate", "same gift id while queued")
	var t1: Dictionary = Show.take_pending_gift(null)
	assert_eq(t1.get("gift_id", ""), g1["gift_id"], "first waiting external gift first")
	assert_eq(spy.entries.size(), 1)
	assert_eq(spy.entries[0]["c"]["t"], "gift")
	assert_eq(spy.entries[0]["c"]["gift"]["gift_id"], g1["gift_id"])
	assert_eq(Show.take_pending_gift(null), {}, "max. 1 external gift per battle")
	Show.end_battle(_result(BattleResult.Outcome.VICTORY))
	assert_eq(spy.entries.size(), 2, "waiting gift applied after the battle")
	assert_eq(received, [g1["gift_id"], g2["gift_id"]])
	assert_eq(Show.receive_gift(g2)["reason"], "duplicate", "applied ids are remembered in flags.live")
	Game.in_battle = false
	var g3: Dictionary = _dev_gift(3)
	assert_eq(Show.receive_gift(g3)["apply"], "now", "outside a battle: applied at once")
	assert_eq(spy.entries.size(), 3)
	var saved: GameState = Game.state
	Game.state = null
	assert_eq(Show.receive_gift(_dev_gift(4))["reason"], "run_not_active")
	Game.state = saved
	assert_eq(rejected.size(), 3)
	Events.gift_received.disconnect(cb_r)
	Events.gift_rejected.disconnect(cb_x)


func test_show_system_gift_is_not_recorded() -> void:
	_world()
	var spy: _SpyLog = _SpyLog.new()
	Game.run_log = spy
	Game.in_battle = true
	Show.begin_battle(_setup())
	Show.add_hype(45.0)                                   # 30 → 75: threshold 70
	assert_false(Show.take_pending_gift(null).is_empty())
	for e: Dictionary in spy.entries:
		assert_ne(e["c"].get("t", ""), "gift", "system gifts are reproducible from the show rng")
	Show.end_battle(_result(BattleResult.Outcome.VICTORY))


func test_show_end_battle_followers_triggers_and_unlocks() -> void:
	_world()
	var won: Array = []
	var cb: Callable = func(p: Dictionary) -> void: won.append(p)
	Events.battle_won.connect(cb)
	Show.begin_battle(_setup())
	Show.on_battle_event(_ev(ActionEvent.Type.BATTLE_START))
	assert_eq(Show.hype(), 33.0, "battle start +3 through feed")
	assert_eq(Show.viewers(), 1225)
	var gained: int = Show.end_battle(_result(BattleResult.Outcome.VICTORY))
	assert_eq(gained, 14, "floori(1225 × (0.007 + 0.014 × 33 / 100) = 14.23)")
	assert_eq(Game.state.show.stats["battles_won"], 1)
	assert_eq(won.size(), 1)
	for key: String in DataValidator.TRIGGER_PAYLOAD_KEYS["battle_won"]:
		assert_true(won[0].has(key), "battle_won payload key " + key)
	assert_eq(won[0]["encounter_type"], "normal")
	assert_has(Show.unlocked_this_battle(), "ach_first_win")
	assert_eq(Show.followers(), 14 + 20, "battle followers + bronze achievement")
	Events.battle_won.disconnect(cb)
	# boss victory
	var bosses: Array = []
	var cb_b: Callable = func(p: Dictionary) -> void: bosses.append(p)
	Events.boss_defeated.connect(cb_b)
	Show.begin_battle(_setup(true))
	var res: BattleResult = _result(BattleResult.Outcome.VICTORY)
	res.is_boss = true
	res.boss_id = "enm_boss"
	res.party_turns = 17
	assert_gt(Show.end_battle(res), 0)
	assert_eq(bosses, [{"boss_id": "enm_boss", "party_turns": 17}])
	assert_true(Show.is_unlocked("ach_boss"))
	assert_has(Game.state.pending_lootboxes, "box_gold")
	Events.boss_defeated.disconnect(cb_b)
	# flight: −1 % followers
	Show.add_followers(2000)
	var before: int = Show.followers()
	Show.begin_battle(_setup())
	var lost: int = Show.end_battle(_result(BattleResult.Outcome.FLED))
	assert_eq(lost, -(before / 100))
	assert_eq(Game.state.show.stats["battles_fled"], 1)
	assert_true(Show.is_unlocked("ach_flee_first"))
	Show.begin_battle(_setup())
	assert_eq(Show.end_battle(_result(BattleResult.Outcome.DEFEAT)), 0, "defeat: no followers")


func test_show_end_battle_resets_unserved_top_threshold() -> void:
	_world()
	Game.in_battle = true
	Show.begin_battle(_setup())
	Game.state.show.hype = 90.0
	var res: BattleResult = _result(BattleResult.Outcome.VICTORY)
	res.min_party_hp_pct = 0.05
	var at_won: Array = []
	var cb: Callable = func(_p: Dictionary) -> void: at_won.append(Show.hype())
	Events.battle_won.connect(cb)
	var gained: int = Show.end_battle(res)                # close win +15 → 100 with no turn left for a gift
	Events.battle_won.disconnect(cb)
	assert_eq(at_won, [80.0], "crossing 100 still resets hype to 80 — before the follower conversion")
	assert_eq(gained, ShowModel.followers_for_battle(ShowModel.viewers_for(1.0, 100.0, 0), 80.0, false, 1.0),
		"peak at hype 100, hype_end 80")
	assert_eq(Show.hype(), 85.0, "then +5 for ach_first_win")
	assert_eq(Game.state.show.stats["hype_100_count"], 1)


## Crossing 100 records the viewer value at hype 100 and converts the same followers whether gift slots were free
## (reservation, reset to 80 later) or used up (reset to 80 at once) — mid-battle and through the end-of-battle bonus.
func test_show_top_threshold_peak_and_followers_do_not_depend_on_gift_slots() -> void:
	var peak_100: int = ShowModel.viewers_for(1.0, 100.0, 0)
	assert_eq(peak_100, 2900)
	var expected: int = ShowModel.followers_for_battle(peak_100, 80.0, false, 1.0)
	for at_end: bool in [false, true]:
		for gifts_before: bool in [false, true]:
			var label: String = "at_end %s, gift slot used before %s" % [str(at_end), str(gifts_before)]
			_world()
			Game.in_battle = true
			Show.begin_battle(_setup())
			if gifts_before:
				Show.add_hype(45.0)                       # 30 → 75: gift at 70 (+5 hype / +20 followers achievement)
				assert_false(Show.take_pending_gift(null).is_empty(), label)    # the only regular slot is used
			Game.state.show.followers = 0
			Game.state.show.hype = 90.0 if at_end else 95.0
			var seen: Array = []
			var cb: Callable = func(v: int) -> void: seen.append(v)
			Events.viewers_changed.connect(cb)
			if not at_end:
				Show.add_hype(5.0)                        # 95 → 100
			var res: BattleResult = _result(BattleResult.Outcome.VICTORY)
			if at_end:
				res.min_party_hp_pct = 0.05               # close win +15 → 100
			var gained: int = Show.end_battle(res)
			Events.viewers_changed.disconnect(cb)
			assert_has(seen, peak_100, label + ": the hype-100 value is emitted")
			assert_eq(Game.state.show.stats["viewers_max"], peak_100, label)
			assert_eq(Game.state.floor_run.stats["viewers_peak"], peak_100, label)
			assert_eq(Game.state.show.stats["hype_100_count"], 1, label)
			assert_eq(gained, expected, label + ": peak 2900, hype_end 80")
			assert_eq(expected, 52, "floori(2900 × (0.007 + 0.014 × 0.8) = 52.78)")
			Fx.end_world(_prev_data)
			_prev_data = null


## An external gift that takes the slot reserved for threshold 100 drops the reservation at once: hype is reset to
## 80 right away instead of staying at 100 for another turn.
func test_show_external_gift_taking_the_reserved_top_slot_resets_hype_at_once() -> void:
	_world()
	Game.in_battle = true
	Show.begin_battle(_setup(true))                       # boss: 2 gifts
	Show.add_hype(45.0)                                   # 30 → 75: 70 (+5 achievement)
	assert_false(Show.take_pending_gift(null).is_empty())
	var ext: Dictionary = _dev_gift(7)
	assert_eq(Show.receive_gift(ext)["apply"], "queued")
	Game.state.show.hype = 95.0                           # above 85 without crossing it
	Show.add_hype(5.0)                                    # → 100: the second slot is reserved for threshold 100
	assert_eq(Show.hype(), 100.0, "reserved: hype stays at 100 until the gift")
	assert_eq(Show.take_pending_gift(null).get("gift_id", ""), ext["gift_id"], "waiting external gift first")
	assert_eq(Show.hype(), 80.0, "no slot left for threshold 100: reservation dropped, reset to 80 at once")
	assert_eq(Show.take_pending_gift(null), {}, "max. 2 gifts")
	Show.end_battle(_result(BattleResult.Outcome.VICTORY))


func test_show_battle_events_signals_and_lines() -> void:
	_world()
	var kills: Array = []
	var lines: Array = []
	var cb_k: Callable = func(p: Dictionary) -> void: kills.append(p)
	var cb_l: Callable = func(text: String, voice: StringName, tag: String, _b: bool) -> void:
		lines.append([text, String(voice), tag])
	Events.enemy_killed.connect(cb_k)
	Events.mod_said.connect(cb_l)
	var setup: BattleSetup = _setup(false, BattleSetup.Advantage.PREEMPTIVE)
	Game.state.show.stats["explore_seconds_since_battle"] = 250
	Show.begin_battle(setup)
	assert_eq(Game.state.show.stats["explore_seconds_since_battle"], 0, "pacifist counter reset")
	assert_eq(Game.state.show.stats["preemptives"], 1)
	Show.on_battle_event(_act("p0", K.ATTACK))
	Show.on_battle_event(_ko("e0", "enm_rat", "p0", "skl_attack_kai"))
	assert_eq(kills, [{"enemy_id": "enm_rat", "overkill": false, "by": "attack", "member": "kai"}])
	assert_eq(Game.state.show.stats["kills_total"], 1)
	assert_has(Show.unlocked_this_battle(), "ach_first_blood")
	Show.on_battle_event(_ev(ActionEvent.Type.MOD_LINE, {"text": "boss_intro:enm_boss"}))
	assert_eq(lines.back(), ["Applaus für den Hausmeister!", "mod", "boss_intro:enm_boss"], "MOD_LINE → say(tag)")
	Events.enemy_killed.disconnect(cb_k)
	Events.mod_said.disconnect(cb_l)
	Show.end_battle(_result(BattleResult.Outcome.VICTORY))


func test_show_say_chat_priority_and_replay_silence() -> void:
	_world()
	var lines: Array = []
	var chats: Array = []
	var cb_l: Callable = func(text: String, voice: StringName, tag: String, blocking: bool) -> void:
		lines.append([text, String(voice), tag, blocking])
	var cb_c: Callable = func(user: String, text: String, mood: StringName) -> void:
		chats.append([user, text, String(mood)])
	Events.mod_said.connect(cb_l)
	Events.chat_posted.connect(cb_c)
	assert_eq(Show.say("death", {}, true), "Sendeschluss, Kai.", "name added to the context")
	assert_eq(lines.back(), ["Sendeschluss, Kai.", "mod", "death", true])
	assert_eq(Show.say("crit"), "", "lower priority than a fresh death line → dropped")
	assert_eq(Show.say("intro"), "", "priority 0 < 5")
	Show.chat("chat_crit")
	assert_eq(chats, [["u_bahn_ultra", "KRIT!!", "neutral"]], "fixed sender, mood by hype band")
	Show.chat("chat_hype_mid")
	assert_eq(chats.size(), 1, "max. one chat line per 2.5 s")
	Game.replaying = true
	assert_eq(Show.say("death"), "", "no presentation while replaying")
	Game.replaying = false
	Events.mod_said.disconnect(cb_l)
	Events.chat_posted.disconnect(cb_c)


## Balancing regression (full-run bot): the purchase acknowledgement right after the lootbox lines and the descent line
## right after an achievement line (ach_speedrun fires on floor_completed) were dropped by the priority window. The
## ModAnnouncer.always_said tags still come — queued behind the fresh line — and do not refresh the window themselves.
func test_show_always_said_lines_survive_the_priority_window() -> void:
	_world()
	var tags: Array = []
	var cb: Callable = func(_text: String, _voice: StringName, tag: String, _blocking: bool) -> void:
		tags.append(tag)
	Events.mod_said.connect(cb)
	for tag: String in ["vendor_buy", "safe_room_enter", "stairs_found", "floor_end"]:
		assert_true(ModAnnouncer.always_said(tag), tag)
	assert_false(ModAnnouncer.always_said("crit"))
	assert_false(ModAnnouncer.always_said("achievement_generic"))
	assert_ne(Show.say("achievement:ach_first_blood"), "", "priority 2 line")
	assert_eq(Show.say("crit"), "", "a normal priority-0 line is still dropped")
	assert_ne(Show.say("vendor_buy", {"item": "Bandage"}), "", "purchase acknowledgement despite the fresh line")
	assert_ne(Show.say("floor_end"), "", "descent line despite the fresh line")
	assert_eq(Show.say("level_up", {"level": 3}), "", "the always-said lines did not lower the window's priority")
	assert_eq(tags, ["achievement:ach_first_blood", "vendor_buy", "floor_end"])
	Show.set("_now", float(Show.get("_now")) + Show.PRIORITY_WINDOW_SEC + 1.0)
	assert_ne(Show.say("crit"), "", "window over")
	Events.mod_said.disconnect(cb)


func test_show_explore_signal_reactions() -> void:
	_world()
	var st: GameState = Game.state
	Events.chest_opened.emit("f1_c0", [])
	assert_eq(Show.hype(), 32.0, "chest +2")
	assert_eq(st.show.stats["chests_opened"], 1)
	assert_false(Show.is_unlocked("ach_chest_metal"), "f1_c0 is a wood chest")
	Events.chest_opened.emit("f1_c1", [])
	assert_true(Show.is_unlocked("ach_chest_metal"), "chest type looked up in the layout")
	var hype_now: float = Show.hype()
	Events.event_completed.emit({"event_id": "fev_x", "choice": "pose"})
	assert_eq(Show.hype(), hype_now + 5.0, "event +5")
	assert_eq(st.show.stats["events_completed"], 1)
	Events.item_bought.emit({"item_id": "itm_bandage", "qty": 4, "cost": 100, "safe_room_id": "sr_kiosk"})
	assert_eq(st.show.stats["credits_spent_vendor"], 100)
	assert_true(Show.is_unlocked("ach_vendor_100"))
	Events.lootbox_opened.emit("box_bronze", [])
	Events.lootbox_opened.emit("box_bronze", [])
	assert_true(Show.is_unlocked("ach_lootbox_2"))
	st.show.stats["explore_seconds_since_battle"] = 300
	Events.explore_tick.emit({"seconds_since_battle": 300})
	assert_true(Show.is_unlocked("ach_pacifist"))
	Events.level_up.emit({"member": "kai", "level": 3})
	assert_true(Show.is_unlocked("ach_level_3"))
	Events.sponsor_gift_triggered.emit("spn_heal")
	assert_eq(st.show.stats["sponsor_gifts"], 1)
	hype_now = Show.hype()
	Events.floor_timer_warning.emit(600)
	assert_eq(Show.hype(), hype_now, "10:00 warning: chat only")
	Events.floor_timer_warning.emit(300)
	assert_eq(Show.hype(), minf(100.0, hype_now + 10.0), "5:00 warning +10")
	st.show.hype = 40.0
	Events.floor_timer_warning.emit(60)
	assert_eq(Show.hype(), 55.0, "1:00 warning +15")
	st.floor_run.time_left_ticks = 600 * 30
	Events.floor_completed.emit(1)
	assert_true(Show.is_unlocked("ach_speedrun"), "floor_completed with timer_left in seconds")


func test_show_sync_from_state_reemits() -> void:
	_world()
	var hy: Array = []
	var vi: Array = []
	var cb_h: Callable = func(h: float, d: float, _r: StringName) -> void: hy.append([h, d])
	var cb_v: Callable = func(v: int) -> void: vi.append(v)
	Events.hype_changed.connect(cb_h)
	Events.viewers_changed.connect(cb_v)
	Game.state.show.hype = 29.0                            # RunSim decay changes the state directly
	Show.sync_from_state()
	assert_eq(hy, [[29.0, -1.0]])
	assert_eq(vi, [ShowModel.viewers_for(1.0, 29.0, 0)])
	Show.sync_from_state()
	assert_eq(vi.size(), 2, "unchanged values are re-sent for the UI")
	Events.hype_changed.disconnect(cb_h)
	Events.viewers_changed.disconnect(cb_v)


## M5 CR 2: a battle torn down before its end (BattleScene freed) drops Show's battle context: no thresholds,
## no queue, no follower conversion; waiting external gifts are refused, never applied later.
func test_show_abort_battle_drops_the_battle_context() -> void:
	_world()
	var rejected: Array = []
	var cb_x: Callable = func(id: String, reason: String) -> void: rejected.append([id, reason])
	Events.gift_rejected.connect(cb_x)
	Game.in_battle = true
	Show.begin_battle(_setup())
	var g: Dictionary = _dev_gift(7)
	assert_eq(Show.receive_gift(g)["apply"], "queued")
	Show.add_hype(45.0)                       # 30 → 75: threshold 70 open
	Game.in_battle = false
	var credits: int = Game.state.inventory.credits
	var followers: int = Show.followers()
	Show.abort_battle()
	assert_eq(rejected, [[g["gift_id"], "run_not_active"]], "the waiting gift is refused")
	assert_eq(Show.take_pending_gift(null), {}, "no threshold gift from the aborted battle")
	Show.add_hype(30.0)
	assert_eq(Show.take_pending_gift(null), {}, "outside a battle no threshold opens")
	assert_eq(Game.state.inventory.credits, credits, "nothing applied")
	assert_eq(Show.followers(), followers, "no follower conversion")
	assert_eq(Show.receive_gift(g)["apply"], "now", "the refused gift id was never applied")
	Show.abort_battle()                       # no battle: no-op
	assert_len(rejected, 1)
	Events.gift_rejected.disconnect(cb_x)


# --- helpers ----------------------------------------------------------------------------------------------------------

## Schema-complete external gift (05 §6.5), unique ULID-style id per n.
static func _dev_gift(n: int) -> Dictionary:
	var g: Dictionary = Gift.make_dev("gold", "", 100)
	if g.is_empty():
		g = {"schema": 1, "source": "dev", "kind": "gold", "tier": "", "amount": 100, "sponsor_id": "",
			"sender": {"display_name": "", "anon": true, "sender_ref": ""}, "message_key": "",
			"target": {"player_id": "local", "run_id": ""}, "event_id": "", "window_id": "", "league": "show",
			"effect_pm": 1000, "load_half": 0, "roll": {}, "contents": [], "run_bound": true, "deliver_by_tick": 0,
			"issued_at": "", "payload": {}}
	g["gift_id"] = "g_01HZY0000000000000000000%02d" % n
	return g


## Full-run finding (GDD §1.4 B2): "floor_start" („Die Uhr läuft …“) comes when the countdown runs in the exploration —
## not at new game (it played over the title / intro), not at start_floor of an unplayable floor (over the credits).
## Floor 1: after floor_timer_started (tutorial victory) on the next explore second; a floor whose countdown runs at
## once: after floor_entered. A fresher line of higher priority only postpones it to a later tick; it comes once.
func test_floor_start_line_waits_for_the_running_countdown() -> void:
	var lines: Array[String] = []
	var cb: Callable = func(_text: String, _voice: StringName, tag: String, _b: bool) -> void: lines.append(tag)
	Events.mod_said.connect(cb)
	_world()
	var tick: Dictionary = {"seconds_since_battle": 1}
	assert_false(lines.has("floor_start"), "new game (title → intro): no floor_start line yet")
	Game.state.floor_run.timer_started = false
	Events.floor_entered.emit(1)
	Events.explore_tick.emit(tick)
	assert_false(lines.has("floor_start"), "exploration before the tutorial victory: countdown not running")
	Game.state.floor_run.timer_started = true
	Events.floor_timer_started.emit()
	assert_false(lines.has("floor_start"), "not at the battle end itself")
	Show.say("death")
	Events.explore_tick.emit(tick)
	assert_false(lines.has("floor_start"), "suppressed by the fresher death line (priority window)")
	Show.set("_now", float(Show.get("_now")) + Show.PRIORITY_WINDOW_SEC + 1.0)
	Events.explore_tick.emit(tick)
	assert_eq(lines.count("floor_start"), 1, "said on the next explore second")
	Events.explore_tick.emit(tick)
	assert_eq(lines.count("floor_start"), 1, "only once")
	Game.start_floor(2)
	Events.explore_tick.emit(tick)
	assert_eq(lines.count("floor_start"), 1, "start_floor alone (e.g. unplayable floor 2 → credits) says nothing")
	Game.state.floor_run.timer_started = true
	Events.floor_entered.emit(2)
	Events.explore_tick.emit(tick)
	assert_eq(lines.count("floor_start"), 1, "the tag still cools down (ModAnnouncer 20 s): retried later")
	Show.set("_now", float(Show.get("_now")) + ModAnnouncer.KEY_COOLDOWN_SEC + 1.0)
	Events.explore_tick.emit(tick)
	assert_eq(lines.count("floor_start"), 2, "a floor whose countdown runs at once: after its first entry")
	Events.mod_said.disconnect(cb)
