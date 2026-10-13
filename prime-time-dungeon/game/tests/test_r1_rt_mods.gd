extends TestCase
## 07 §9.5, §9.6 (R1b-I3) test_r1_rt_mods: the static modifiers of a real-time combat (RtMods) — validate (integers
## only, the vocabularies of RtVocab), the unit selectors, the static ops (stats with a full unit staying full, speed,
## swing, threat, element swap, extra enemies before every other op, never in a boss fight, up to MAX_ENEMIES), the
## add_rule rules (a shared timer), the "on" reactions to every event kind (and wired into the tick), the fold factors
## (dmg_dealt_pm, dmg_taken_pm — percent hits the target's only —, the first hit once, heal_taken_pm), skill_pm (every
## field and selector), the forbid ops; the mapping of battle twists, show bosses (reward once on VICTORY) and species
## passives in BattleBridge.make_rt_setup, and unlock_variant in the bar.

const Damage := preload("res://core/rt/rt_damage.gd")
const Ability := preload("res://core/rt/rt_ability.gd")
const StatusFx := preload("res://core/rt/rt_status_fx.gd")
const FixedMath := preload("res://core/stats/fixed_math.gd")
const T := ActionEvent.Type
const K := BattleCommand.Kind


func _rats() -> Dictionary:
	return RtKit.encounter("enc_rt_rats", [["g", "enc_rt_rats", [0, -300, 128]]])


func _chief() -> Dictionary:
	return RtKit.encounter("enc_rt_chief", [["g", "enc_rt_chief", [0, -300, 128]]])


## The setup of `cmd` (Kai level 6 unless `st`) with the mod list `mods` in place of its own, applied like
## make_rt_setup does (RtMods.apply_static).
func _setup(mods: Array, cmd: Dictionary = {}, st: GameState = null) -> RtSetup:
	var s: RtSetup = RtKit.setup(st if st != null else RtKit.state(6), cmd if not cmd.is_empty() else RtKit.dummy_cmd())
	var list: Array[Dictionary] = []
	for m: Variant in mods:
		list.append(m)
	s.mods = list
	RtMods.apply_static(s, RtKit.data())
	return s


## A started sim of _setup (rules cleared, auto-attacks off).
func _sim(mods: Array, cmd: Dictionary = {}, st: GameState = null) -> RtSim:
	var sim: RtSim = RtSim.new(_setup(mods, cmd, st), RtKit.data())
	sim.start()
	for u: RtUnit in RtKit.no_ai(sim).units_ref():
		u.auto_on = false
	return sim


## Kai and Mopsula of a level-6 state with the species `kai_sp` / `mop_sp` (stats, full HP / MP like RtKit.state).
static func _species_state(kai_sp: String, mop_sp: String) -> GameState:
	var st: GameState = RtKit.state(6)
	for m: PartyMember in st.party:
		m.species_id = kai_sp if m.id == "kai" else mop_sp
		var sb: StatBlock = Progression.total_stats(m, RtKit.data())
		m.hp = sb.values[StatBlock.Stat.HP]
		m.mp = sb.values[StatBlock.Stat.MP]
	return st


static func _json(v: Variant) -> String:
	return JSON.stringify(v)


static func _ev(type: ActionEvent.Type, actor: String, target: String) -> ActionEvent:
	var e: ActionEvent = ActionEvent.make(type)
	e.actor_id = actor
	e.target_id = target
	return e


func test_validate() -> void:
	var ok: Array = [
		{"src": "species:spc_x", "op": "stat_pm", "unit": "p0", "stat": "max_hp", "pm": 1200},
		{"src": "twist:tw_x", "op": "skill_pm", "unit": "party", "skill": "tag:flashy", "field": "cooldown", "pm": 800},
		{"src": "equip:itm_x", "op": "on", "unit": "p1", "event": "kill", "effect": {"heal_pct": 5}},
		{"src": "equip:itm_y", "op": "on", "unit": "p3", "event": "dodge", "effect": {"status": "sts_haste", "ms": 3000}},
		{"src": "showboss:enc_x", "op": "add_rule", "unit": "enemies", "shared": true,
			"rule": {"skill": "skl_e_rt_slow", "target": "threat_top", "first_ms": 4000, "every_ms": 8000}},
		{"src": "spec:cls_x", "op": "element_swap", "unit": "all"},
		{"src": "twist:tw_y", "op": "extra_enemy", "unit": "enemies", "enemy": "first", "count": 2},
		{"src": "spec:cls_y", "op": "forbid_items", "unit": "party", "tag": "heal"},
		{"src": "spec:cls_z", "op": "unlock_variant", "unit": "p0", "slot": 2, "skill": "skl_x"},
		{"src": "twist:tw_z", "op": "dmg_taken_pm", "unit": "boss", "pm": 1100}]
	assert_eq(RtMods.validate(ok), PackedStringArray(), "a valid list")
	for row: Array in [
		[{"src": "species:x", "op": "move_pm", "unit": "p0", "pm": 1.5}, "every number must be an integer"],
		[{"src": "x", "op": "move_pm", "unit": "p0", "pm": 900}, ".src"],
		[{"src": "mood:x", "op": "move_pm", "unit": "p0", "pm": 900}, ".src"],
		[{"src": "twist:x", "op": "fly", "unit": "p0"}, "unknown op 'fly'"],
		[{"src": "twist:x", "op": "move_pm", "unit": "p4", "pm": 900}, "unknown unit 'p4'"],
		[{"src": "twist:x", "op": "move_pm", "unit": "p0"}, "move_pm needs 'pm'"],
		[{"src": "twist:x", "op": "move_pm", "unit": "p0", "pm": 900, "x": 1}, "unknown key 'x'"],
		[{"src": "twist:x", "op": "move_pm", "unit": "p0", "pm": "fast"}, ".pm: wrong type"],
		[{"src": "twist:x", "op": "move_pm", "unit": "p0", "pm": 5001}, "outside 0..5000"],
		[{"src": "twist:x", "op": "stat_pm", "unit": "p0", "stat": "hp", "pm": 900}, "unknown stat 'hp'"],
		[{"src": "twist:x", "op": "skill_pm", "unit": "p0", "skill": "item:itm_bandage", "field": "power", "pm": 900},
			"bad selector"],
		[{"src": "twist:x", "op": "skill_pm", "unit": "p0", "skill": "*", "field": "range", "pm": 900},
			"unknown field 'range'"],
		[{"src": "twist:x", "op": "on", "unit": "p0", "event": "jump", "effect": {"mp": 5}}, "unknown event 'jump'"],
		[{"src": "twist:x", "op": "on", "unit": "p0", "event": "kill", "effect": {"heal_pct": 0}}, "heal_pct: 1..100"],
		[{"src": "twist:x", "op": "on", "unit": "p0", "event": "kill", "effect": {"mp": 5, "heal_pct": 5}}, "one of"],
		[{"src": "twist:x", "op": "add_rule", "unit": "enemies", "rule": {"target": "self"}}, "needs a skill"],
		[{"src": "twist:x", "op": "add_rule", "unit": "enemies", "rule": {"skill": "s", "cond": {"moon": 1}}},
			"unknown condition 'moon'"],
		[{"src": "twist:x", "op": "add_rule", "unit": "enemies", "rule": {"skill": "s", "target": "moon"}},
			"unknown target 'moon'"],
		[{"src": "twist:x", "op": "extra_enemy", "unit": "enemies", "enemy": "first", "count": 3}, "count 1..2"],
		[{"src": "twist:x", "op": "unlock_variant", "unit": "p0", "slot": 6, "skill": "s"}, "slot 1..5"]]:
		var got: PackedStringArray = RtMods.validate([row[0]])
		assert_true(", ".join(got).contains(str(row[1])), "%s → %s" % [_json(row[0]), str(got)])
	assert_eq(RtMods.validate(["x"]), PackedStringArray(["mods[0]: not an object"]))


func test_selectors() -> void:
	var sim: RtSim = _sim([], _chief())
	var kai: RtUnit = sim.unit("p0")
	var mop: RtUnit = sim.unit("p1")
	var chief: RtUnit = sim.unit("e0")
	var rows: Array = []
	for sel: String in ["all", "party", "enemies", "boss", "p0", "p1"]:
		var m: Dictionary = {"unit": sel}
		rows.append([RtMods.applies(m, kai), RtMods.applies(m, mop), RtMods.applies(m, chief)])
	assert_eq(rows, [[true, true, true], [true, true, false], [false, false, true], [false, false, true],
		[true, false, false], [false, true, false]])
	var rats: RtSim = _sim([], _rats())
	assert_false(RtMods.applies({"unit": "boss"}, rats.unit("e0")), "boss: bosses only")
	assert_true(RtMods.unit_ok("p3") and not RtMods.unit_ok("p4") and not RtMods.unit_ok("e0"))


func test_static_ops() -> void:
	var plain: RtSetup = _setup([], _rats())
	var s: RtSetup = _setup([
		{"src": "species:a", "op": "stat_pm", "unit": "p0", "stat": "max_hp", "pm": 1500},
		{"src": "species:a", "op": "stat_pm", "unit": "enemies", "stat": "str", "pm": 2000},
		{"src": "spec:b", "op": "move_pm", "unit": "party", "pm": 500},
		{"src": "spec:b", "op": "swing_pm", "unit": "p1", "pm": 800},
		{"src": "spec:b", "op": "threat_pm", "unit": "p0", "pm": 3000},
		{"src": "twist:tw_mirror_room", "op": "element_swap", "unit": "enemies"}], _rats())
	var p: Array[RtUnit] = plain.units
	var u: Array[RtUnit] = s.units
	assert_eq([u[0].max_hp(), u[0].hp], [FixedMath.mul_pm(p[0].max_hp(), 1500), FixedMath.mul_pm(p[0].max_hp(), 1500)],
		"max_hp × 1.5, the full unit stays full")
	assert_eq(u[1].max_hp(), p[1].max_hp())
	assert_eq([u[2].stat(StatBlock.Stat.STR), u[3].stat(StatBlock.Stat.STR)],
		[p[2].stat(StatBlock.Stat.STR) * 2, p[3].stat(StatBlock.Stat.STR) * 2])
	assert_eq([u[0].move_cm_tick, u[1].move_cm_tick, u[2].move_cm_tick], [FixedMath.mul_pm(p[0].move_cm_tick, 500),
		FixedMath.mul_pm(p[1].move_cm_tick, 500), p[2].move_cm_tick])
	assert_eq([u[0].swing_ticks, u[1].swing_ticks], [p[0].swing_ticks, FixedMath.mul_pm(p[1].swing_ticks, 800)])
	assert_eq([u[0].threat_pm, u[1].threat_pm], [p[0].threat_pm * 3, p[1].threat_pm])
	assert_eq([Elements.multiplier_pm(p[2].element_mods, "fire"), Elements.multiplier_pm(u[2].element_mods, "fire")],
		[1500, 500], "element_swap: fire 1.5 → 2000 − 1500")
	var w: RtUnit = RtUnit.new()
	w.element_mods = {"fire": 2.0, "ice": 0.5, "shock": 0.0, "poison": 1.0}
	RtMods.apply_unit_op(w, {"op": "element_swap"})
	assert_eq(["fire", "ice", "shock", "poison"].map(func(e: String) -> int: return Elements.multiplier_pm(
		w.element_mods, e)), [500, 1500, 0, 1000], "≥ 2000 → 500, immunity and neutral stay")
	var hurt: RtUnit = p[1]
	hurt.hp = 10
	RtMods.apply_unit_op(hurt, {"op": "stat_pm", "stat": "max_hp", "pm": 2000})
	assert_eq(hurt.hp, 10, "a hurt unit keeps its HP")
	var full_mp: int = hurt.max_mp()
	hurt.mp = full_mp
	RtMods.apply_unit_op(hurt, {"op": "stat_pm", "stat": "max_mp", "pm": 500})
	assert_eq([hurt.max_mp(), hurt.mp], [FixedMath.mul_pm(full_mp, 500), FixedMath.mul_pm(full_mp, 500)])


func test_extra_enemies() -> void:
	var s: RtSetup = _setup([{"src": "twist:a", "op": "stat_pm", "unit": "enemies", "stat": "str", "pm": 2000},
		{"src": "twist:tw_double_trouble", "op": "extra_enemy", "unit": "enemies", "enemy": "first", "count": 2}],
		_rats())
	var plain: RtSetup = _setup([], _rats())
	assert_eq(s.units.map(func(u: RtUnit) -> String: return u.id + ":" + u.def_id), ["p0:kai", "p1:mopsula",
		"e0:enm_kanalratte", "e1:enm_kanalratte", "e2:enm_kanalratte", "e3:enm_kanalratte"])
	assert_eq(s.groups[0]["units"], ["e0", "e1", "e2", "e3"], "komparsen of the first group")
	var e2: RtUnit = s.units[4]
	var f: Vector2i = RtGeo.formation(2, 0, -300, 128)
	var at: Vector2i = RtGeo.project_walkable(s.geo, f.x, f.y, e2.radius, false)
	assert_eq([e2.x, e2.z, e2.slot, e2.pop_in_until], [at.x, at.y, 2, 15], "the next formation slot, popping in")
	assert_eq(e2.stat(StatBlock.Stat.STR), plain.units[2].stat(StatBlock.Stat.STR) * 2,
		"created before every other op: the earlier stat_pm applies to it too")
	var boss: RtSetup = _setup([{"src": "twist:tw_double_trouble", "op": "extra_enemy", "unit": "enemies",
		"enemy": "first", "count": 2}], _chief())
	assert_eq(boss.units.size(), 3, "never in a boss fight")
	var five: Dictionary = RtKit.encounter("enc_rt_dummies", [["g1", "enc_rt_dummies", [0, -50, 128]],
		["g2", "enc_rt_rats", [300, -200, 160]]])
	var capped: RtSetup = _setup([{"src": "twist:tw_double_trouble", "op": "extra_enemy", "unit": "enemies",
		"enemy": "enm_kanalratte", "count": 2}], five)
	assert_eq(capped.units.size() - 2, 6, "5 enemies + 2 → MAX_ENEMIES 6")
	assert_eq(capped.groups[0]["units"], ["e0", "e1", "e2", "e5"])


func test_add_rule_and_shared_timer() -> void:
	var s: RtSetup = _setup([{"src": "showboss:x", "op": "add_rule", "unit": "enemies", "shared": true,
		"rule": {"skill": "skl_e_rt_slow", "target": "threat_top", "first_ms": 4000, "every_ms": 8000}},
		{"src": "spec:y", "op": "add_rule", "unit": "p1", "rule": {"skill": "skl_mop_holy_lick", "target": "self"}}],
		_rats())
	var rat: RtUnit = s.units[2]
	assert_eq(rat.rules.map(func(r: Dictionary) -> String: return r["key"]), ["0:0", "m0:0"], "appended, \"m<i>:0\"")
	assert_true(bool(rat.rules[1].get("shared", false)) and int(rat.rule_ready["m0:0"]) == 120,
		"shared: ready at first_ms for all (no slot offset)")
	assert_eq(int(s.units[3].rule_ready["m0:0"]), 120)
	assert_eq(str(s.units[1].rules.back()["key"]), "m1:0")
	assert_false(s.units[1].rules.back().has("shared"))
	var sim: RtSim = RtSim.new(s, RtKit.data())
	sim.start()
	for u: RtUnit in sim.party_ref():
		u.rules = []
		u.auto_on = false
	var starts: Array = []
	for _i in 700:
		for e: ActionEvent in sim.step():
			if e.type == T.ACTION_START and e.skill_id == "skl_e_rt_slow":
				starts.append([e.tick, e.actor_id])
	assert_true(starts.size() >= 2 and int(starts[0][0]) >= 120, "fired: %s" % str(starts))
	for i in range(1, starts.size()):
		assert_true(int(starts[i][0]) - int(starts[i - 1][0]) >= 240, "one timer for both rats: %s" % str(starts))
	assert_eq(int(sim.unit("e0").rule_ready["m0:0"]), int(sim.unit("e1").rule_ready["m0:0"]))
	assert_eq(int(sim.unit("e0").rule_ready["m0:0"]), int(starts.back()[0]) + 240)


func test_on_reactions() -> void:
	var effects: Array = [{"heal_pct": 10}, {"mp": 7}, {"status": "sts_haste", "ms": 3000}]
	var events: Array = ["combat_start", "kill", "interrupt", "dodge", "crit", "ko_ally", "show_success"]
	for ei in events.size():
		var mods: Array = []
		for k in effects.size():
			mods.append({"src": "equip:x", "op": "on", "unit": "p0", "event": events[ei], "effect": effects[k]})
		var sim: RtSim = _sim(mods)
		var kai: RtUnit = sim.unit("p0")
		kai.hp = kai.max_hp() / 2
		kai.mp = 0
		StatusFx.clear_all(kai)
		var hit: ActionEvent = null
		match events[ei]:
			"combat_start":
				hit = _ev(T.BATTLE_START, "", "")
			"kill":
				hit = _ev(T.KO, "p0", "e0")
			"interrupt":
				hit = _ev(T.CAST_INTERRUPTED, "p0", "e0")
			"dodge":
				hit = _ev(T.TELEGRAPH_DODGED, "", "p0")
			"crit":
				hit = _ev(T.DAMAGE, "p0", "e0")
				hit.crit = true
			"ko_ally":
				hit = _ev(T.KO, "e0", "p1")
			"show_success":
				hit = _ev(T.STUNT_RESULT, "p0", "")
				hit.success = true
		var out: Array[ActionEvent] = RtMods.on_event(sim, hit)
		assert_eq(out.map(func(e: ActionEvent) -> String: return "%s %s %d" % [ActionEvent.type_name(e.type),
			e.target_id, e.amount if e.type != T.STATUS_ADDED else e.value]), ["HEAL p0 %d" %
			FixedMath.div_round(kai.max_hp() * 10, 100), "MP_CHANGE p0 7", "STATUS_ADDED p0 90"], str(events[ei]))
	var quiet: RtSim = _sim([{"src": "equip:x", "op": "on", "unit": "p0", "event": "kill", "effect": {"mp": 7}},
		{"src": "equip:x", "op": "on", "unit": "p1", "event": "ko_ally", "effect": {"mp": 7}}])
	quiet.unit("p0").mp = 0
	quiet.unit("p1").mp = 0
	assert_eq(RtMods.on_event(quiet, _ev(T.KO, "p1", "e0")).size(), 0, "another unit's kill; its own KO is no ko_ally")
	assert_eq(RtMods.on_event(quiet, _ev(T.KO, "e0", "p1")).size(), 0)
	assert_eq(RtMods.on_event(quiet, _ev(T.KO, "e0", "p0")).map(func(e: ActionEvent) -> String: return e.target_id),
		["p1"], "ko_ally of p1 when p0 falls")


func test_on_reactions_in_the_tick() -> void:
	var cmd: Dictionary = RtKit.encounter("enc_rt_dummies", [["g", "enc_rt_dummies", [0, -50, 128]]])
	var sim: RtSim = RtSim.new(_setup([
		{"src": "equip:x", "op": "on", "unit": "party", "event": "combat_start", "effect": {"mp": 3}},
		{"src": "equip:x", "op": "on", "unit": "p0", "event": "kill", "effect": {"heal_pct": 10}}], cmd), RtKit.data())
	for u: RtUnit in sim.units_ref():
		u.mp = 0
	var ev: Array[ActionEvent] = sim.start()
	assert_eq(RtKit.of(ev, T.MP_CHANGE).map(func(e: ActionEvent) -> Array: return [e.tick, e.target_id, e.amount]),
		[[0, "p0", 3], [0, "p1", 3]], "combat_start: with the start events")
	RtKit.no_ai(sim)
	var kai: RtUnit = sim.unit("p0")
	kai.hp = kai.max_hp() / 2
	sim.unit("e0").hp = 1
	assert_eq(sim.submit(RtCommand.ability(0, "p0", "skl_kai_heavy_swing", "e0")), "")
	var ko_tick: int = -1
	var heal: Array = []
	for _i in 60:
		ev = sim.step()
		for e: ActionEvent in ev:
			if e.type == T.KO and e.target_id == "e0":
				ko_tick = e.tick
		if ko_tick >= 0:
			heal = RtKit.of(ev, T.HEAL).map(func(e: ActionEvent) -> Array: return [e.tick, e.target_id, e.amount])
			break
	assert_true(ko_tick > 0, "the dummy falls")
	assert_eq(heal, [[ko_tick, "p0", FixedMath.div_round(kai.max_hp() * 10, 100)]], "kill: healed in the KO's tick")


func test_fold_factors_first_hit_and_heal() -> void:
	var sim: RtSim = _sim([
		{"src": "spec:a", "op": "dmg_dealt_pm", "unit": "p0", "pm": 2000},
		{"src": "spec:a", "op": "dmg_taken_pm", "unit": "enemies", "pm": 500},
		{"src": "spec:a", "op": "dmg_taken_pm", "unit": "enemies", "pm": 1200},
		{"src": "species:b", "op": "first_hit_taken_pm", "unit": "p0", "pm": 700},
		{"src": "spec:c", "op": "heal_taken_pm", "unit": "p1", "pm": 500}])
	var kai: RtUnit = sim.unit("p0")
	var mop: RtUnit = sim.unit("p1")
	var dummy: RtUnit = sim.unit("e0")
	var f: Array[int] = []
	sim.mod_factors(kai, dummy, true, f)
	assert_eq(f, [2000, 500, 1200] as Array[int], "the source's dealt, then the target's taken (list order)")
	f.clear()
	sim.mod_factors(kai, dummy, false, f)
	assert_eq(f, [500, 1200] as Array[int], "percent hits and status ticks: the target's only")
	assert_eq(sim.first_hit, {"p0": [700]}, "state: the unused first-hit factors")
	kai.element_mods = {}
	var hex: SkillDef = sim.skill_def("skl_e_test_hex")
	var base: int = FixedMath.div_round(kai.max_hp() * 20, 100)
	assert_eq(Damage.pct_hit(sim, dummy, kai, hex, 20, Damage.Kind.ABILITY, true, K.SKILL), FixedMath.mul_pm(base, 700),
		"the first hit taken × 700")
	kai.hp = kai.max_hp()
	assert_eq(Damage.pct_hit(sim, dummy, kai, hex, 20, Damage.Kind.ABILITY, true, K.SKILL), base, "only once")
	assert_eq(sim.first_hit, {})
	assert_eq([sim.heal_taken(mop, 100), sim.heal_taken(mop, 1), sim.heal_taken(kai, 100)], [50, 1, 100])
	mop.hp = 1
	var healed: int = Damage.heal(sim, null, mop, 100, "", "")
	assert_eq([healed, mop.hp], [50, 51], "heal_taken_pm in the heal")


func test_skill_pm_fields_and_selectors() -> void:
	var sim: RtSim = _sim([
		{"src": "spec:x", "op": "skill_pm", "unit": "p0", "skill": "tag:flashy", "field": "power", "pm": 2000},
		{"src": "spec:x", "op": "skill_pm", "unit": "p0", "skill": "skl_kai_heavy_swing", "field": "mp", "pm": 500},
		{"src": "spec:x", "op": "skill_pm", "unit": "p1", "skill": "*", "field": "cast", "pm": 500},
		{"src": "spec:x", "op": "skill_pm", "unit": "p0", "skill": "skl_kai_deo_torch", "field": "cooldown", "pm": 500},
		{"src": "spec:x", "op": "skill_pm", "unit": "p0", "skill": "*", "field": "power", "pm": 1500},
		{"src": "spec:x", "op": "skill_pm", "unit": "p1", "skill": "element:fire", "field": "power", "pm": 1100},
		{"src": "spec:x", "op": "skill_pm", "unit": "p1", "skill": "item:*", "field": "power", "pm": 1300}])
	var kai: RtUnit = sim.unit("p0")
	var mop: RtUnit = sim.unit("p1")
	var heavy: SkillDef = sim.skill_def("skl_kai_heavy_swing")
	var taunt: SkillDef = sim.skill_def("skl_kai_taunt")
	var flame: SkillDef = sim.skill_def("skl_mop_noble_flame")
	var molotov: SkillDef = sim.skill_def("skl_item_molotov")
	var torch: SkillDef = sim.skill_def("skl_kai_deo_torch")
	assert_eq(Array(sim.skill_pm(kai, heavy)), [3000, 1000, 1000, 500], "tag:flashy 2000, then * 1500; mp × 500")
	assert_eq(Array(sim.skill_pm(kai, taunt)), [1500, 1000, 1000, 1000])
	assert_eq(sim.view_for(kai, heavy).power, FixedMath.mul_pm(sim.view(heavy).power, 3000))
	assert_eq(sim.view(heavy).power, heavy.power, "the shared view stays")
	assert_eq(Ability.cost(sim, kai, heavy), FixedMath.mul_pm(Ability.mp_cost(heavy), 500))
	assert_eq(Ability.cooldown_ticks(sim, kai, torch), 210, "14000 ms = 420 ticks × 500")
	assert_eq(Ability.cast_ticks(sim, mop, flame), maxi(sim.bal.i("CAST_MIN_TICKS"), FixedMath.mul_pm(45, 500)))
	assert_eq(Ability.cast_ticks(sim, kai, flame), 45, "the other unit unchanged")
	assert_eq(Array(sim.skill_pm(mop, flame)), [1100, 1000, 500, 1000], "element:fire")
	assert_eq(sim.skill_pm(mop, molotov)[0], FixedMath.mul_pm(1100, 1300), "a fire item: element:fire and item:*")
	assert_eq(sim.skill_pm(mop, sim.skill_def("skl_mop_holy_lick"))[0], 1000)


func test_forbid_ops() -> void:
	var st: GameState = RtKit.state(6, "kai", {"itm_bandage": 2, "itm_antidote": 2})
	var sim: RtSim = _sim([{"src": "spec:x", "op": "forbid_skill", "unit": "p0", "skill": "skl_kai_heavy_swing"},
		{"src": "spec:x", "op": "forbid_items", "unit": "party", "tag": "heal"},
		{"src": "spec:x", "op": "forbid_skill", "unit": "p1", "skill": "skl_mop_holy_lick"}], {}, st)
	assert_eq(sim.submit(RtCommand.ability(0, "p0", "skl_kai_heavy_swing", "e0")), "forbidden", "submit")
	assert_eq(sim.can_use("p0", "skl_kai_heavy_swing", "e0"), "forbidden")
	assert_eq(sim.can_use("p0", "skl_kai_leash_trip", "e0"), "")
	assert_eq(sim.can_use_item("p0", "itm_bandage", "p0"), "forbidden", "tag heal")
	assert_true(sim.can_use_item("p0", "itm_antidote", "p0") != "forbidden")
	var mop: RtUnit = sim.unit("p1")
	mop.hp = mop.max_hp() / 3
	mop.rules = RtRules.compile([{"skill": "skl_mop_holy_lick", "target": "self"}], "t")
	assert_eq(RtRules.choose(sim, mop), {}, "the AI skips a forbidden skill")
	var ev: Array[ActionEvent] = RtKit.steps(sim, 30)
	assert_eq(RtKit.of(ev, T.ACTION_START).size(), 0)


func test_twists_mapping() -> void:
	var d: GameData = RtKit.data()
	var got: Array[Dictionary] = RtMods.from_twists([{"id": "tw_mirror_room"},
		{"id": "tw_elite_guest", "params": {"elite_pm": 1500}}, {"id": "tw_double_trouble"},
		{"id": "tw_boss_mood", "params": {"aggressive": 0}}, {"id": "tw_overtime"}, "x"], d)
	assert_eq(_json(got), _json([
		{"src": "twist:tw_mirror_room", "op": "element_swap", "unit": "enemies"},
		{"src": "twist:tw_elite_guest", "op": "stat_pm", "unit": "enemies", "stat": "max_hp", "pm": 1500},
		{"src": "twist:tw_elite_guest", "op": "stat_pm", "unit": "enemies", "stat": "str", "pm": 1500},
		{"src": "twist:tw_double_trouble", "op": "extra_enemy", "unit": "enemies", "enemy": "first", "count": 1},
		{"src": "twist:tw_boss_mood", "op": "dmg_taken_pm", "unit": "boss", "pm": 1100}]), "show-only twists: none")
	assert_eq(RtMods.validate(got), PackedStringArray())
	var dflt: Array[Dictionary] = RtMods.from_twists([{"id": "tw_elite_guest"}, {"id": "tw_boss_mood"}], d)
	assert_eq(_json(dflt), _json([
		{"src": "twist:tw_elite_guest", "op": "stat_pm", "unit": "enemies", "stat": "max_hp", "pm": 1200},
		{"src": "twist:tw_elite_guest", "op": "stat_pm", "unit": "enemies", "stat": "str", "pm": 1200},
		{"src": "twist:tw_boss_mood", "op": "swing_pm", "unit": "boss", "pm": 850},
		{"src": "twist:tw_boss_mood", "op": "dmg_dealt_pm", "unit": "boss", "pm": 1100}]), "twists.json defaults")


func test_twists_in_the_setup() -> void:
	var st: GameState = RtKit.state(6)
	st.flags["live"] = {"twist": {"active": [
		{"id": "tw_double_trouble", "unit": "battles", "left": 1},
		{"id": "tw_mirror_room", "unit": "battles", "left": 2},
		{"id": "tw_elite_guest", "unit": "battles", "left": 0},
		{"id": "tw_boss_mood", "unit": "floors", "left": 1}]}}
	var s: RtSetup = RtKit.setup(st, _rats())
	assert_eq(_json(s.mods), _json([
		{"src": "twist:tw_double_trouble", "op": "extra_enemy", "unit": "enemies", "enemy": "first", "count": 1},
		{"src": "twist:tw_mirror_room", "op": "element_swap", "unit": "enemies"}]),
		"battle twists with battles left, stored order")
	var foes: Array = s.units.filter(func(u: RtUnit) -> bool: return u.side == Combatant.Side.ENEMY)
	assert_eq(foes.map(func(u: RtUnit) -> int: return Elements.multiplier_pm(u.element_mods, "fire")), [500, 500, 500],
		"an extra rat, every rat mirrored")
	var bst: GameState = RtKit.state(6)
	bst.flags["live"] = {"twist": {"active": [{"id": "tw_double_trouble", "unit": "battles", "left": 1},
		{"id": "tw_boss_mood", "unit": "battles", "left": 1}]}}
	var plain: RtSetup = RtKit.setup(RtKit.state(6), _chief())
	var bs: RtSetup = RtKit.setup(bst, _chief())
	assert_eq(bs.units.size(), 3, "no extra enemy in a boss fight")
	assert_eq(bs.units[2].swing_ticks, FixedMath.mul_pm(plain.units[2].swing_ticks, 850), "aggressive boss")
	var sim: RtSim = RtSim.new(bs, RtKit.data())
	var f: Array[int] = []
	sim.mod_factors(sim.unit("e0"), sim.unit("p0"), true, f)
	assert_eq(f, [1100] as Array[int])


func test_show_boss() -> void:
	var d: GameData = RtKit.data()
	var enc: EncounterDef = d.encounter("enc_rt_showboss")
	var rule: Dictionary = {"skill": "skl_e_rt_slow", "target": "threat_top", "first_ms": 4000, "every_ms": 8000}
	var want: Array = [
		{"src": "showboss:enc_rt_showboss", "op": "stat_pm", "unit": "enemies", "stat": "max_hp", "pm": 1200},
		{"src": "showboss:enc_rt_showboss", "op": "stat_pm", "unit": "enemies", "stat": "str", "pm": 1200},
		{"src": "showboss:enc_rt_showboss", "op": "add_rule", "unit": "enemies", "shared": true, "rule": rule}]
	assert_eq(_json(RtMods.from_show_boss(enc)), _json(want))
	var neutral: EncounterDef = EncounterDef.new()
	neutral.id = "enc_x"
	neutral.show_boss = {"elite_pm": 1000, "rule": rule}
	assert_eq(RtMods.from_show_boss(neutral).map(func(m: Dictionary) -> String: return m["op"]), ["add_rule"],
		"elite_pm 1000: no stat mods")
	assert_eq(RtMods.from_show_boss(d.encounter("enc_rt_rats")).size(), 0)
	var cmd: Dictionary = RtKit.encounter("enc_rt_showboss", [["g", "enc_rt_showboss", [0, -300, 128]],
		["g2", "enc_rt_showboss", [300, -200, 160]]])
	var s: RtSetup = RtKit.setup(RtKit.state(6), cmd)
	assert_eq(_json(s.mods), _json(want), "once per encounter, even with two of its groups")
	assert_eq(s.units[2].max_hp(), FixedMath.mul_pm(168, 1200), "a rat 168 HP × 1.2")
	var sim: RtSim = RtSim.new(s, RtKit.data())
	sim.start()
	var kai: RtUnit = sim.unit("p0")
	for u: RtUnit in sim.units_ref():
		if u.side == Combatant.Side.ENEMY:
			Damage.ko(sim, u, kai, "", "", 1, false, -1, false)
	sim.step()
	assert_eq(sim.result.outcome, BattleResult.Outcome.VICTORY)
	assert_eq(sim.result.boss_rewards, [{"kind": "box", "id": "box_fan", "amount": 1}] as Array[Dictionary],
		"the reward once (BattleResult.boss_rewards)")


func test_species_mods_in_the_setup() -> void:
	var s: RtSetup = RtKit.setup(_species_state("spc_kai_kachelgolem", "spc_mop_flattermops"), RtKit.dummy_cmd())
	assert_eq(_json(s.mods), _json([
		{"src": "species:spc_kai_kachelgolem", "op": "first_hit_taken_pm", "unit": "p0", "pm": 700},
		{"src": "species:spc_mop_flattermops", "op": "on", "unit": "p1", "event": "combat_start",
			"effect": {"status": "sts_haste", "ms": 3000}}]))
	var sim: RtSim = RtSim.new(s, RtKit.data())
	var ev: Array[ActionEvent] = sim.start()
	var haste: Array = RtKit.of(ev, T.STATUS_ADDED).filter(func(e: ActionEvent) -> bool:
		return e.status_id == "sts_haste")
	assert_eq(haste.map(func(e: ActionEvent) -> Array: return [e.tick, e.target_id, e.value]), [[0, "p1", 90]],
		"Hofflug: haste at the start")
	assert_eq(sim.first_hit, {"p0": [700]}, "Fugenkitt: the first hit taken × 0.7")
	var s2: RtSetup = RtKit.setup(_species_state("spc_kai_teilautomat", "spc_mop_glutmops"), RtKit.dummy_cmd())
	assert_eq(_json(s2.mods), _json([
		{"src": "species:spc_kai_teilautomat", "op": "skill_pm", "unit": "p0", "skill": "item:*", "field": "power",
			"pm": 1250},
		{"src": "species:spc_mop_glutmops", "op": "skill_pm", "unit": "p1", "skill": "element:fire",
			"field": "power", "pm": 1150}]))
	var sim2: RtSim = RtSim.new(s2, RtKit.data())
	var bandage: SkillDef = sim2.skill_def("skl_item_bandage")
	assert_eq([sim2.skill_pm(sim2.unit("p0"), bandage)[0], sim2.skill_pm(sim2.unit("p0"),
		sim2.skill_def("skl_kai_heavy_swing"))[0], sim2.skill_pm(sim2.unit("p1"), sim2.skill_def(
		"skl_mop_noble_flame"))[0], sim2.skill_pm(sim2.unit("p1"), bandage)[0]], [1250, 1000, 1150, 1000])
	assert_eq(RtKit.setup(_species_state("spc_original", ""), RtKit.dummy_cmd()).mods.size(), 0,
		"pas_authentic: Show only")


func test_unlock_variant_widens_the_bar() -> void:
	var d: GameData = RtKit.data()
	var prt: Dictionary = d.party_member("kai").rt
	var m: PartyMember = RtKit.state(3).party[0]
	m.rt_loadout = {"2": "skl_kai_first_aid"}
	assert_eq(BattleBridge._rt_bar(prt, m)[2], "skl_kai_taunt", "level 3: the variant (level 4) is not reached")
	assert_eq(BattleBridge._rt_bar(prt, m, {"skl_kai_first_aid": 2})[2], "skl_kai_first_aid", "unlocked")
	assert_eq(BattleBridge._rt_bar(prt, m, {"skl_kai_first_aid": 3})[2], "skl_kai_taunt", "only for its own slot")
	m.rt_loadout = {}
	assert_eq(BattleBridge._rt_bar(prt, m, {"skl_kai_first_aid": 2})[2], "skl_kai_taunt", "the loadout chooses it")
	assert_false(BattleBridge._rt_bar(prt, m, {"skl_kai_prime_finisher": 5}).values().has("skl_kai_prime_finisher"),
		"FINALE stays out")
