extends TestCase
## 06 package B — Talent-Show core (06 §2.2, 02_TECH §4.4.15/§6.1): talents.json content and validator rules, open
## choices on odd levels from L3 (derived, never stored), the seeded offer (deterministic, without replacement,
## for / min_level / max_rank), the pick rules (safe room, oldest open level, offer only), every effect kind at its
## place (Progression stats, to_combatant crit / elements, BattleBridge MP, ActionResolver first strike, BattleState
## stunt chance, field ability API, show bets API, GameState hype / follower), the recorded command + replay (RunSim
## verifier and the Game facade) and save / hash compatibility.

const Fx := preload("res://tests/test_m2_fixtures.gd")
const TalentsRules := preload("res://core/data/validators/talents.gd")
const UiUtil := preload("res://scenes/ui/ui_util.gd")
const SR: StringName = &"sr_test"


func after_each() -> void:
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.in_battle = false
	Game.auto_battle = false


## Real-data state at `level` for both members, in a safe room (unless `in_room` is false).
func _state(seed: int = 4242, level: int = 3, in_room: bool = true) -> GameState:
	var d: GameData = real_data()
	var st: GameState = GameState.create_new(d, 0, "Kai", seed)
	st.floor_run = FloorRun.create(d.floor_def(1), st.seed, st.difficulty)
	if in_room:
		st.floor_run.location = SR
	for m: PartyMember in st.party:
		m.level = level
	return st


## Fixture tables with `talents` (validator tests).
func _data_with(talents: Array) -> GameData:
	var t: Dictionary = Fx.tables()
	t["talents"] = talents
	var d: GameData = GameData.new()
	d.load_from_dicts(t)
	return d


func _talent(effects: Array, extra: Dictionary = {}) -> Dictionary:
	var d: Dictionary = {"id": "tal_test", "name": "Test", "desc": "Ein Test.", "for": ["kai"], "icon": "atk",
		"effects": effects}
	d.merge(extra, true)
	return d


# --- content ----------------------------------------------------------------------------------------------------------

func test_pool_has_12_talents_per_member_with_a_third_behaviour() -> void:
	var d: GameData = real_data()
	assert_eq(d.all_talents().size(), 24, "06 §2.2: 24 talents")
	for mid: String in ["kai", "mopsula"]:
		var pool: Array[TalentDef] = d.talents_for(mid)
		assert_eq(pool.size(), 12, mid + ": 12 talents")
		var behaviour: int = 0
		for t: TalentDef in pool:
			assert_eq(t.for_members, PackedStringArray([mid]), t.id + " belongs to one member")
			assert_true(t.id.begins_with("tal_kai_" if mid == "kai" else "tal_mop_"), t.id)
			assert_eq(t.min_level, 3, t.id + ": all choices from L3")
			assert_between(t.max_rank, 1, 2, t.id)
			behaviour += 1 if t.is_behaviour() else 0
		assert_true(behaviour * 3 >= pool.size(), "%s: >= 1/3 behaviour talents (%d of %d)" % [mid, behaviour,
			pool.size()])


func test_texts_are_short_render_and_have_no_foot_words() -> void:
	for t: TalentDef in real_data().all_talents():
		assert_between(t.desc.length(), 1, TalentsRules.DESC_MAX, t.id + " desc fits the card (two lines)")
		assert_between(t.name.length(), 1, TalentsRules.NAME_MAX, t.id + " name")
		assert_eq(UiUtil.missing_glyphs(t.name + t.desc), "", t.id + ": every glyph renders")
		for w: String in TalentsRules.FORBIDDEN_WORDS:
			assert_false((t.name + " " + t.desc).to_lower().contains(w), "%s: no '%s' (06 §0.3)" % [t.id, w])
		if t.for_members.is_empty() or t.for_members.has("mopsula"):
			for w: String in TalentsRules.MOPSULA_FORBIDDEN_WORDS:
				assert_false((t.name + " " + t.desc).to_lower().contains(w), "%s: no majesty motif" % t.id)


func test_kind_vocabulary_matches_the_validator() -> void:
	var kinds: Array = TalentsRules.KIND_FIELDS.keys()
	kinds.sort()
	var vocab: Array = Array(TalentDef.KINDS)
	vocab.sort()
	assert_eq(kinds, vocab, "every TalentDef.KINDS entry has validator fields and ranges")
	for k: String in TalentDef.BEHAVIOUR_KINDS:
		assert_has(TalentDef.KINDS, k)


# --- validator --------------------------------------------------------------------------------------------------------

func test_validator_accepts_a_valid_talent() -> void:
	var d: GameData = _data_with([_talent([{"kind": "stat_flat", "stat": "str", "value": 2},
		{"kind": "element_pm", "element": "poison", "pm": 750}], {"max_rank": 2, "weight": 3})])
	assert_eq(d.errors, PackedStringArray())
	assert_true(d.has_id("talents", "tal_test"))
	assert_eq(d.talent("tal_test").effects.size(), 2)
	assert_eq(d.talent("tal_test").max_rank, 2)
	# the majesty rule is about Graf Mopsula only: a Kai talent may name the Rattenkönigin's title
	var kai_only: GameData = _data_with([_talent([{"kind": "crit_add_pm", "pm": 10}],
		{"desc": "Kennt Ihre Majestät von Gleis 9."})])
	assert_eq(kai_only.errors, PackedStringArray(), "Kai's texts are not checked for majesty words")


func test_validator_rejects_bad_talents() -> void:
	var cases: Array = [
		[_talent([{"kind": "stat_flat", "stat": "str", "value": 4}]), "out of range 1..3"],
		[_talent([{"kind": "stat_pct", "stat": "hp", "pm": 60}]), "out of range 30..50"],
		[_talent([{"kind": "crit_add_pm", "pm": 5}]), "out of range 10..30"],
		[_talent([{"kind": "element_pm", "element": "none", "pm": 750}]), "'none' not in"],
		[_talent([{"kind": "element_pm", "element": "ice", "pm": 1200}]), "out of range 700..1000"],
		[_talent([{"kind": "field_range_pm", "pm": 1600}]), "out of range 1000..1500"],
		[_talent([{"kind": "field_cd_pm", "pm": 400}]), "out of range 500..1000"],
		[_talent([{"kind": "preemptive_dmg_pm", "pm": 1300}]), "out of range 1000..1200"],
		[_talent([{"kind": "stunt_window_pm", "pm": 1300}]), "out of range 1000..1250"],
		[_talent([{"kind": "marotte_heart", "per_floor": 2}]), "out of range 1..1"],
		[_talent([{"kind": "liga_stat_pct", "stat": "xyz", "pm": 50}]), "'xyz' not in"],
		[_talent([{"kind": "teleport", "pm": 1000}]), "kind: 'teleport' not in"],
		[_talent([{"kind": "stat_flat", "stat": "str"}]), "value: missing required field"],
		[_talent([{"kind": "crit_add_pm", "pm": 20, "stat": "str"}]), "stat: unknown key"],
		[_talent([{"kind": "crit_add_pm", "pm": 2.5}]), "expected integer"],
		[_talent([]), "needs 1..3 effects"],
		[_talent([{"kind": "crit_add_pm", "pm": 10}, {"kind": "crit_add_pm", "pm": 10},
			{"kind": "crit_add_pm", "pm": 10}, {"kind": "crit_add_pm", "pm": 10}]), "needs 1..3 effects"],
		[_talent([{"kind": "crit_add_pm", "pm": 10}], {"max_rank": 3}), "max_rank: out of range 1..2"],
		[_talent([{"kind": "crit_add_pm", "pm": 10}], {"min_level": 2}), "min_level: out of range 3..99"],
		[_talent([{"kind": "crit_add_pm", "pm": 10}], {"weight": 0}), "weight: out of range 1..10"],
		[_talent([{"kind": "crit_add_pm", "pm": 10}], {"icon": "rocket"}), "icon: 'rocket' not in"],
		[_talent([{"kind": "crit_add_pm", "pm": 10}], {"for": ["nobody"]}), "unknown party member 'nobody'"],
		[_talent([{"kind": "crit_add_pm", "pm": 10}], {"id": "talent_x"}), "invalid id 'talent_x'"],
		[_talent([{"kind": "crit_add_pm", "pm": 10}], {"desc": "Barfuß durch die Kanalisation."}), "no foot words"],
		[_talent([{"kind": "crit_add_pm", "pm": 10}], {"desc": "x".repeat(91)}), "longer than 90"],
		[_talent([{"kind": "crit_add_pm", "pm": 10}], {"for": ["mopsula"], "name": "Majestätischer Blick"}),
			"no majesty motif"],
		[_talent([{"kind": "crit_add_pm", "pm": 10}], {"for": [], "desc": "Pluralis Majestatis."}), "no majesty motif"],
		[_talent([{"kind": "crit_add_pm", "pm": 10}], {"rank": 1}), "rank: unknown key"],
	]
	for c: Array in cases:
		var d: GameData = _data_with([c[0]])
		var joined: String = " | ".join(d.errors)
		assert_false(d.errors.is_empty(), "rejected: %s" % str(c[0]))
		assert_true(joined.contains(str(c[1])), "'%s' in: %s" % [str(c[1]), joined])


# --- open choices -----------------------------------------------------------------------------------------------------

func test_choices_only_on_odd_levels_from_3() -> void:
	var m: PartyMember = PartyMember.new()
	m.id = "kai"
	var want: Dictionary = {1: [], 2: [], 3: [3], 4: [3], 5: [3, 5], 6: [3, 5], 7: [3, 5, 7], 8: [3, 5, 7],
		9: [3, 5, 7, 9], 10: [3, 5, 7, 9], 11: [3, 5, 7, 9, 11], 13: [3, 5, 7, 9, 11, 13]}
	for lv: int in want:
		m.level = lv
		assert_eq(Array(Talents.pending_levels(m)), want[lv], "level %d" % lv)
	for lv in range(1, 14):
		assert_eq(Talents.is_talent_level(lv), lv >= 3 and lv % 2 == 1, "is_talent_level(%d)" % lv)
	m.level = 9
	m.talents = {"tal_kai_wischtechnik": 2, "tal_kai_bissfest": 1}
	assert_eq(Array(Talents.pending_levels(m)), [9], "3 picks resolve the oldest levels 3, 5, 7")
	assert_eq(Talents.picks(m), 3)


func test_level_up_onto_l3_and_l5_opens_choices_and_emits() -> void:
	var st: GameState = _state(4242, 1, false)
	var kai: PartyMember = st.member("kai")
	Progression.add_exp(kai, Progression.exp_to_next(1), real_data())
	assert_eq(kai.level, 2)
	assert_eq(Talents.pending_levels(kai).size(), 0, "L2: no choice")
	Progression.add_exp(kai, Progression.exp_to_next(2) + Progression.exp_to_next(3) + Progression.exp_to_next(4),
		real_data())
	assert_eq(kai.level, 5)
	assert_eq(Array(Talents.pending_levels(kai)), [3, 5], "one level-up across L3..L5 opens both choices")
	# Game emits talent_pending once per talent level gained
	Game.state = st
	var got: Array = []
	var cb: Callable = func(mid: String, lv: int) -> void: got.append([mid, lv])
	Events.talent_pending.connect(cb)
	var r: BattleResult = BattleResult.new()
	r.outcome = BattleResult.Outcome.VICTORY
	r.exp = Progression.exp_to_next(1) + Progression.exp_to_next(2)
	Game.apply_battle_result(r)
	Events.talent_pending.disconnect(cb)
	assert_eq(got, [["mopsula", 3]], "Mopsula L1 → L3: one choice; Kai L5 → L6 none")


# --- offer ------------------------------------------------------------------------------------------------------------

func test_offer_is_deterministic_distinct_and_from_the_pool() -> void:
	var st: GameState = _state(4242, 9)
	var d: GameData = real_data()
	for mid: String in ["kai", "mopsula"]:
		var seen: Dictionary = {}
		for lv: int in [3, 5, 7, 9]:
			var a: PackedStringArray = Talents.offer(st, d, mid, lv)
			assert_eq(a.size(), Talents.OFFER_SIZE, "%s L%d: 2 talents" % [mid, lv])
			assert_ne(a[0], a[1], "never the same talent twice")
			assert_eq(Talents.offer(st, d, mid, lv), a, "same seed + level → same offer (reload-proof)")
			for id: String in a:
				assert_true(d.talent(id).is_for(mid), id + " is for " + mid)
			seen[",".join(a)] = true
		assert_gt(seen.size(), 1, mid + ": the level changes the offer")
	var other: GameState = _state(777, 9)
	var differs: bool = false
	for lv: int in [3, 5, 7, 9]:
		differs = differs or Talents.offer(other, d, "kai", lv) != Talents.offer(st, d, "kai", lv)
	assert_true(differs, "another run seed → other offers")


func test_offer_respects_max_rank_and_min_level() -> void:
	var st: GameState = _state(4242, 9)
	var d: GameData = real_data()
	var kai: PartyMember = st.member("kai")
	for t: TalentDef in d.talents_for("kai"):
		if t.id != "tal_kai_wischtechnik" and t.id != "tal_kai_bissfest":
			kai.talents[t.id] = t.max_rank
	kai.talents["tal_kai_wischtechnik"] = 1
	var left: Array = Array(Talents.offer(st, d, "kai", 13))
	left.sort()
	assert_eq(left, ["tal_kai_bissfest", "tal_kai_wischtechnik"], "only talents below max_rank remain")
	kai.talents["tal_kai_wischtechnik"] = 2
	assert_eq(Array(Talents.offer(st, d, "kai", 13)), ["tal_kai_bissfest"], "smaller pool → smaller offer")
	kai.talents["tal_kai_bissfest"] = 1
	assert_eq(Talents.offer(st, d, "kai", 13).size(), 0, "pool exhausted")
	# min_level: a fixture talent from L5 is not offered on L3
	var t: Dictionary = Fx.tables()
	t["talents"] = [_talent([{"kind": "crit_add_pm", "pm": 10}], {"id": "tal_a"}),
		_talent([{"kind": "crit_add_pm", "pm": 10}], {"id": "tal_b"}),
		_talent([{"kind": "crit_add_pm", "pm": 10}], {"id": "tal_late", "min_level": 5})]
	var fd: GameData = GameData.new()
	fd.load_from_dicts(t)
	var fst: GameState = GameState.create_new(fd, 0, "Kai", 5)
	for lv: int in [3, 4]:
		var o: PackedStringArray = Talents.offer(fst, fd, "kai", lv)
		assert_false(o.has("tal_late"), "L%d: tal_late (min_level 5) not offered" % lv)
	assert_eq(Talents.offer(fst, fd, "mopsula", 3).size(), 0, "no talent for Mopsula in the fixture")


func test_weights_shape_the_offer() -> void:
	var d: GameData = real_data()
	var rare: int = 0
	var common: int = 0
	var n_common: int = 0
	for t: TalentDef in d.talents_for("mopsula"):
		if t.weight == 2:
			n_common += 1
	assert_eq(d.talent("tal_mop_monokel").weight, 1, "the speed talent is the rare one (06b balance)")
	for s in 600:
		var st: GameState = _state(1000 + s, 3)
		for id: String in Talents.offer(st, d, "mopsula", 3):
			if d.talent(id).weight == 1:
				rare += 1
			else:
				common += 1
	# weight 1 vs 2: the rare talent shows up about half as often as one common talent
	var ratio: float = float(rare) / (float(common) / float(n_common))
	assert_between(ratio, 0.35, 0.7, "weighted draw (rare %d, common %d over %d talents)" % [rare, common, n_common])


# --- pick -------------------------------------------------------------------------------------------------------------

func test_pick_rules_and_reasons() -> void:
	var d: GameData = real_data()
	var st: GameState = _state(4242, 5)
	var offer3: PackedStringArray = Talents.offer(st, d, "kai", 3)
	var outside: GameState = _state(4242, 5, false)
	assert_eq(Talents.check_pick(outside, d, "kai", offer3[0]), "not_in_safe_room", "only in a safe room")
	assert_eq(Talents.check_pick(st, d, "kai", "tal_nope"), "unknown_talent")
	assert_eq(Talents.check_pick(st, d, "nobody", offer3[0]), "unknown_member")
	var not_offered: String = ""
	for t: TalentDef in d.talents_for("kai"):
		if not offer3.has(t.id):
			not_offered = t.id
			break
	assert_eq(Talents.check_pick(st, d, "kai", not_offered), "not_offered")
	for id: String in Talents.offer(st, d, "kai", 5):
		if not offer3.has(id):
			assert_eq(Talents.check_pick(st, d, "kai", id), "not_offered", "only the oldest open level (L3)")
	assert_eq(Talents.current_offer(st, d, "kai"), offer3, "current offer = oldest open level")
	assert_true(Talents.pick(st, d, "kai", offer3[1]))
	assert_eq(Talents.rank(st.member("kai"), offer3[1]), 1)
	assert_eq(Array(Talents.pending_levels(st.member("kai"))), [5])
	assert_eq(Talents.current_offer(st, d, "kai"), Talents.offer(st, d, "kai", 5), "then L5")
	var offer5: PackedStringArray = Talents.current_offer(st, d, "kai")
	assert_true(Talents.pick(st, d, "kai", offer5[0]))
	assert_eq(Talents.check_pick(st, d, "kai", offer5[1]), "no_pending")
	assert_false(Talents.pick(st, d, "kai", offer5[1]), "nothing changes without an open choice")
	assert_eq(Talents.picks(st.member("kai")), 2)
	assert_eq(Talents.open_choices(st, d), 2, "Mopsula still has L3 and L5 open")


func test_max_rank_reason() -> void:
	var t: Dictionary = Fx.tables()
	t["talents"] = [_talent([{"kind": "crit_add_pm", "pm": 10}], {"id": "tal_a"})]
	var fd: GameData = GameData.new()
	fd.load_from_dicts(t)
	var st: GameState = GameState.create_new(fd, 0, "Kai", 5)
	st.floor_run = FloorRun.create(fd.floor_def(1), st.seed, st.difficulty)
	st.floor_run.location = SR
	st.member("kai").level = 5
	assert_true(Talents.pick(st, fd, "kai", "tal_a"))
	assert_eq(Talents.check_pick(st, fd, "kai", "tal_a"), "max_rank", "max_rank 1 reached")
	assert_false(Talents.has_choice(st, fd, "kai"), "L5 stays open but nothing can be offered")
	assert_eq(Talents.open_choices(st, fd), 0, "an empty offer is no open choice (no badge)")


func test_pick_raises_vitals_like_a_level_up() -> void:
	var d: GameData = real_data()
	var st: GameState = _state(4242, 3)
	var kai: PartyMember = st.member("kai")
	Progression.full_heal(st, d)
	var before: StatBlock = Progression.total_stats(kai, d)
	var hp0: int = kai.hp
	kai.talents["tal_kai_nachtschicht"] = 1
	var after: StatBlock = Progression.total_stats(kai, d)
	kai.talents.erase("tal_kai_nachtschicht")
	assert_gt(after.values[StatBlock.Stat.HP], before.values[StatBlock.Stat.HP], "HP +5 % raises MaxHP")
	# force the offer to contain the HP talent: pick through Talents.pick only if offered, else check follow_max_vitals
	Progression.follow_max_vitals(kai, before, after)
	assert_eq(kai.hp, hp0 + after.values[StatBlock.Stat.HP] - before.values[StatBlock.Stat.HP], "full stays full")
	kai.hp = 0
	Progression.follow_max_vitals(kai, before, after)
	assert_eq(kai.hp, 0, "KO stays KO")


# --- effects ----------------------------------------------------------------------------------------------------------

func _member(id: String, level: int, talents: Dictionary, equipment: Dictionary = {}) -> PartyMember:
	var m: PartyMember = PartyMember.new()
	m.id = id
	m.level = level
	m.talents = talents
	var eq: Dictionary = {"weapon": "", "armor": "", "accessory": ""}
	eq.merge(equipment, true)
	m.equipment = eq
	return m


func test_stat_talents_flat_then_per_mille_round_half_up() -> void:
	var d: GameData = real_data()
	var plain: PartyMember = _member("kai", 5, {}, {"weapon": "itm_wpn_mop", "armor": "itm_arm_hoodie"})
	var base: PackedInt32Array = Progression.total_stats(plain, d).values
	var m: PartyMember = _member("kai", 5, {"tal_kai_wischtechnik": 2, "tal_kai_nachtschicht": 1,
		"tal_kai_dicke_haut": 1}, plain.equipment)
	var v: PackedInt32Array = Progression.total_stats(m, d).values
	assert_eq(v[StatBlock.Stat.STR], base[StatBlock.Stat.STR] + 2, "Stärke +1 × rank 2")
	assert_eq(v[StatBlock.Stat.DEF], base[StatBlock.Stat.DEF] + 1, "Abwehr +1")
	assert_eq(v[StatBlock.Stat.HP], (base[StatBlock.Stat.HP] * 1050 + 500) / 1000, "HP +5 % (round half up)")
	assert_eq(Talents.stat_bonus(m, d, StatBlock.Stat.HP, 110), 6, "110 × 1.05 = 115.5 → 116")
	assert_eq(Talents.stat_bonus(m, d, StatBlock.Stat.SPD, 13), 0, "no SPD talent")
	assert_eq(Talents.stat_bonus(plain, d, StatBlock.Stat.HP, 110), 0, "no talents → 0")


func test_liga_talent_needs_no_armor_and_no_accessory() -> void:
	var d: GameData = real_data()
	var dressed: PartyMember = _member("kai", 9, {"tal_kai_liga_routine": 1}, {"weapon": "itm_wpn_mop",
		"armor": "itm_arm_hoodie"})
	assert_false(Talents.liga_dressed(dressed))
	assert_eq(Talents.stat_bonus(dressed, d, StatBlock.Stat.DEF, 30), 0, "with armor: no Liga bonus")
	var liga: PartyMember = _member("kai", 9, {"tal_kai_liga_routine": 1}, {"weapon": "itm_wpn_mop"})
	assert_true(Talents.liga_dressed(liga), "the weapon is allowed")
	assert_eq(Talents.stat_bonus(liga, d, StatBlock.Stat.DEF, 30), 2, "30 × 1.05 = 31.5 → 32")
	liga.equipment["accessory"] = "itm_acc_lucky_ticket"
	assert_eq(Talents.stat_bonus(liga, d, StatBlock.Stat.DEF, 30), 0, "an accessory blocks the Liga too")


func test_combat_talents_reach_the_combatant() -> void:
	var d: GameData = real_data()
	var plain: PartyMember = _member("kai", 5, {}, {"weapon": "itm_wpn_mop"})
	var c0: Combatant = Progression.to_combatant(plain, d, "p0", 0)
	var m: PartyMember = _member("kai", 5, {"tal_kai_fester_griff": 2, "tal_kai_bissfest": 1,
		"tal_kai_glueckspfote": 1, "tal_kai_erster_eindruck": 1}, {"weapon": "itm_wpn_mop"})
	var c: Combatant = Progression.to_combatant(m, d, "p0", 0)
	assert_almost(c.crit_bonus - c0.crit_bonus, 0.08, 0.000001, "Krit +3 % × 2 + Glückspfote +2 %")
	assert_almost(float(c.element_mods.get("poison", 1.0)), float(c0.element_mods.get("poison", 1.0)) * 0.75)
	assert_eq(c.talent_mods, {"preemptive_dmg_pm": 1150})
	assert_eq(c0.talent_mods, {}, "no talents → no talent_mods")
	var mop: PartyMember = _member("mopsula", 5, {"tal_mop_taktgefuehl": 1})
	assert_eq(Progression.to_combatant(mop, d, "p1", 1).talent_mods, {"stunt_pm": 1200})
	# snapshot: talent_mods survive to_dict/from_dict; without them the snapshot has no key (old hashes stay)
	var back: Combatant = Combatant.from_dict(c.to_dict(), d)
	assert_eq(back.talent_mods, {"preemptive_dmg_pm": 1150})
	assert_eq(back.to_dict(), c.to_dict())
	assert_false(c0.to_dict().has("talent_mods"))
	assert_eq(c.duplicate_combatant().talent_mods, c.talent_mods)


func test_stunt_talent_raises_the_chance_before_the_cap() -> void:
	var d: GameData = real_data()
	var setup: BattleSetup = BattleSetup.new()
	setup.encounter_id = "enc_f1_a2"
	setup.enemy_ids = d.encounter("enc_f1_a2").enemies.duplicate()
	setup.seed = 3
	var mop: Combatant = Progression.to_combatant(_member("mopsula", 3, {}), d, "p0", 0)
	var party: Array[Combatant] = [mop]
	setup.party = party
	var st: BattleState = BattleState.new(setup, d)
	var sk: SkillDef = d.skill("skl_stunt_mop_entrance")
	var base: float = st.stunt_chance(mop, sk)
	mop.talent_mods = {"stunt_pm": 1200}
	var lck: int = mop.stat(StatBlock.Stat.LCK)
	var want: float = minf((sk.success_base + lck * sk.success_lck) * 1.2, sk.success_cap)
	assert_almost(st.stunt_chance(mop, sk), want, 0.0001)
	assert_gt(st.stunt_chance(mop, sk), base, "Taktgefühl: stunts land more often")
	mop.talent_mods = {"stunt_pm": 1250}
	assert_true(st.stunt_chance(mop, sk) <= sk.success_cap + 0.0001, "the skill cap still holds")


func test_first_strike_talent_only_in_the_first_own_turn_after_preemptive() -> void:
	var d: GameData = real_data()
	var dmg: Array = []
	for pm: int in [1000, 1150]:
		for adv: BattleSetup.Advantage in [BattleSetup.Advantage.PREEMPTIVE, BattleSetup.Advantage.NORMAL]:
			var setup: BattleSetup = BattleSetup.new()
			setup.encounter_id = "enc_f1_a2"
			setup.enemy_ids = d.encounter("enc_f1_a2").enemies.duplicate()
			setup.seed = 11
			setup.advantage = adv
			var kai: Combatant = Progression.to_combatant(_member("kai", 5, {}, {"weapon": "itm_wpn_mop"}), d, "p0", 0)
			if pm != 1000:
				kai.talent_mods = {"preemptive_dmg_pm": pm}
			var party: Array[Combatant] = [kai]
			setup.party = party
			var st: BattleState = BattleState.new(setup, d)
			st.start()
			var target: String = st.living(Combatant.Side.ENEMY)[0].id
			var hit: HitResult = HitResult.new()
			hit.amount = 40
			kai.own_turns = 0
			ActionResolver._talent_first_strike(st, kai, hit)
			var first: int = hit.amount
			kai.own_turns = 1
			var hit2: HitResult = HitResult.new()
			hit2.amount = 40
			ActionResolver._talent_first_strike(st, kai, hit2)
			dmg.append([pm, int(adv), first, hit2.amount, target != ""])
	assert_eq(dmg[0].slice(2, 4), [40, 40], "no talent: unchanged")
	assert_eq(dmg[2].slice(2, 4), [46, 40], "talent + preemptive: 40 × 1.15 = 46 in the first own turn only")
	assert_eq(dmg[3].slice(2, 4), [40, 40], "talent without preemptive: unchanged")


func test_post_battle_mp_talent_adds_to_the_werbepause() -> void:
	var d: GameData = real_data()
	var st: GameState = _state(4242, 5, false)
	var mop: PartyMember = st.member("mopsula")
	var max_mp: int = Progression.total_stats(mop, d).values[StatBlock.Stat.MP]
	var r: BattleResult = BattleResult.new()
	r.outcome = BattleResult.Outcome.VICTORY
	mop.mp = 0
	r.party_mp = {"mopsula": 0}
	var rw: BattleRewards = BattleBridge.apply_result(st, d, r)
	assert_eq(int(rw.mp_regen["mopsula"]), (max_mp * 150 + 999) / 1000, "Werbepause 15 % (ceil)")
	mop.talents["tal_mop_koerbchen"] = 2
	max_mp = Progression.total_stats(mop, d).values[StatBlock.Stat.MP]
	mop.mp = 0
	rw = BattleBridge.apply_result(st, d, r)
	assert_eq(int(rw.mp_regen["mopsula"]), (max_mp * 250 + 999) / 1000, "+5 % × rank 2 → 25 %")


func test_field_and_show_talent_apis() -> void:
	var d: GameData = real_data()
	var kai: PartyMember = _member("kai", 5, {"tal_kai_weit_ausholen": 1})
	var mop: PartyMember = _member("mopsula", 5, {"tal_mop_stereo": 1, "tal_mop_schwer_vermittelbar": 1})
	assert_eq(Talents.field_range_pm(kai, d), 1250)
	assert_eq(Talents.field_cd_pm(kai, d), 1000)
	assert_eq(Talents.field_range_pm(mop, d), 1250)
	assert_eq(Talents.field_cd_pm(mop, d), 700)
	assert_eq(Talents.preemptive_dmg_pm(kai, d), 1000)
	var st: GameState = _state(4242, 5)
	assert_eq(Talents.marotte_bonus_hearts(st, d), 0)
	st.member("kai").talents["tal_kai_kamera3"] = 1
	assert_eq(Talents.marotte_bonus_hearts(st, d), 1, "Kamera 3 kennt mich: +1 heart per floor")
	assert_eq(Talents.hype_pm(st, d), 1000, "no hype talent in the slice pool")
	assert_eq(Talents.follower_pm(st, d), 1000)


func test_reserved_hype_and_follower_kinds_multiply_the_show() -> void:
	var t: Dictionary = Fx.tables()
	t["talents"] = [_talent([{"kind": "hype_gain_pm", "pm": 1100}], {"id": "tal_h"}),
		_talent([{"kind": "follower_pm", "pm": 1200}], {"id": "tal_f", "for": ["mopsula"]})]
	var fd: GameData = GameData.new()
	assert_true(fd.load_from_dicts(t), "; ".join(fd.errors))
	var st: GameState = GameState.create_new(fd, 0, "Kai", 5)
	var h0: float = st.hype_gain_mult(fd)
	var f0: float = st.follower_mult(fd)
	assert_eq([st.hype_gain_pm(fd), st.follower_pm(fd)], [1000, 1000], "neutral without such talents")
	st.member("kai").talents["tal_h"] = 1
	st.member("mopsula").talents["tal_f"] = 1
	assert_eq(Talents.hype_pm(st, fd), 1100)
	assert_eq(Talents.follower_pm(st, fd), 1200)
	# the Show's factors are integer per mille (06 §8.0 Nr. 4); the float views stay equipment-only
	assert_eq(st.hype_gain_pm(fd), 1100)
	assert_eq(st.follower_pm(fd), 1200)
	assert_eq([st.hype_gain_mult(fd), st.follower_mult(fd)], [h0, f0])


## 06 §8.0 Nr. 4 (integration round 1b): talent hype / follower factors are integer per mille — GameState.hype_gain_pm /
## follower_pm = equipment product (converted once) × Talents party product, each step (a × b + 500) / 1000, and the
## Show applies them. Same inputs → the same integers in two independent runs, equal to the hand-computed values.
func test_hype_and_follower_talents_are_integer_per_mille_in_the_show() -> void:
	var runs: Array = [_show_factor_run(), _show_factor_run()]
	assert_eq(runs[0], runs[1], "two runs → identical integers")
	# Talents: 1000 × 1100 → 1100; × 1075 = 1182.5 → 1183 (half up). Equipment: scarf 1.2 → 1200, mic 1.15 → 1150.
	# hype: 1200 × 1183 = 1419.6 → 1420; follower: 1150 × 1200 = 1380. Show.add_hype(7): 7 × 1.420 = 9.94 → +10 (30 →
	# 40). Followers of a won battle (4000 viewers, hype 50): 4000 × 0.014 × 1.380 = 77.28 → 77.
	assert_eq(runs[0], {"talent_hype": 1183, "talent_follower": 1200, "hype_pm": 1420, "follower_pm": 1380,
		"hype": 40, "followers": 77})


func _show_factor_run() -> Dictionary:
	var t: Dictionary = Fx.tables()
	t["talents"] = [_talent([{"kind": "hype_gain_pm", "pm": 1100}], {"id": "tal_h"}),
		_talent([{"kind": "hype_gain_pm", "pm": 1075}], {"id": "tal_h2", "for": ["mopsula"]}),
		_talent([{"kind": "follower_pm", "pm": 1200}], {"id": "tal_f", "for": ["mopsula"]})]
	var fd: GameData = GameData.new()
	assert_true(fd.load_from_dicts(t), "; ".join(fd.errors))
	var prev: GameData = DB.data
	DB.data = fd
	Game.new_game(0, "Kai", 5)
	var st: GameState = Game.state
	st.inventory.add("itm_acc_scarf")
	st.inventory.add("itm_acc_mic")
	assert_true(Progression.equip(st.member("kai"), st.inventory, fd, "accessory", "itm_acc_scarf"))
	assert_true(Progression.equip(st.member("mopsula"), st.inventory, fd, "accessory", "itm_acc_mic"))
	st.member("kai").talents["tal_h"] = 1
	st.member("mopsula").talents["tal_h2"] = 1
	st.member("mopsula").talents["tal_f"] = 1
	Show.add_hype(7.0, &"crit")
	var out: Dictionary = {"talent_hype": Talents.hype_pm(st, fd), "talent_follower": Talents.follower_pm(st, fd),
		"hype_pm": st.hype_gain_pm(fd), "follower_pm": st.follower_pm(fd), "hype": roundi(Show.hype()),
		"followers": ShowModel.followers_for_battle_pm(4000, 50.0, false, st.follower_pm(fd))}
	Fx.end_world(prev)
	return out


# --- command, replay, save --------------------------------------------------------------------------------------------

func test_game_pick_records_only_valid_picks() -> void:
	Game.new_game(0, "Kai", 4242)
	var st: GameState = Game.state
	for m: PartyMember in st.party:
		m.level = 3
	var offer: PackedStringArray = Talents.current_offer(st, DB.data, "kai")
	var n0: int = Game.run_log.cmds().size()
	assert_false(Game.pick_talent("kai", offer[0]), "not in a safe room → refused")
	assert_eq(Game.run_log.cmds().size(), n0, "a refused pick is not recorded")
	st.floor_run.location = SR
	var got: Array = []
	var cb: Callable = func(mid: String, tid: String) -> void: got.append([mid, tid])
	Events.talent_picked.connect(cb)
	assert_true(Game.pick_talent("kai", offer[0]))
	Events.talent_picked.disconnect(cb)
	var last: Dictionary = Game.run_log.cmds().back()["c"]
	assert_eq(last, {"t": "talent", "member": "kai", "id": offer[0]})
	assert_eq(Command.validate(last), "")
	assert_eq(got, [["kai", offer[0]]])
	assert_eq(Talents.rank(st.member("kai"), offer[0]), 1)


## RunSim (the verifier) plays a run up to L3+, picks in a safe room; RunSim.replay reproduces the hash bit for bit.
func test_talent_commands_replay_bit_for_bit_in_runsim() -> void:
	var run: Dictionary = _runsim_run(4242)
	var rl: RunLog = run["log"]
	var st: GameState = run["state"]
	assert_true(st.member("kai").level >= 3 and st.member("mopsula").level >= 3, "the run reached L3")
	var picks: int = 0
	for c: Dictionary in rl.cmds():
		if str(c["c"]["t"]) == "talent":
			picks += 1
	assert_eq(picks, Talents.picks_in_party(st), "every pick is a recorded command")
	assert_gt(picks, 1)
	assert_eq(rl.validate(), PackedStringArray())
	var res: Dictionary = RunSim.replay(real_data(), rl)
	assert_eq(res["mismatch_at"], -1, "every checkpoint matches")
	assert_eq(res["final_hash"], run["hash"], "replay → same final hash")
	assert_eq(res["errors"], PackedStringArray())
	# manipulated pick (a talent that was not offered) → refused by the core → different state
	var d: Dictionary = rl.to_dict()
	for e: Dictionary in d["cmds"]:
		if str((e["c"] as Dictionary)["t"]) == "talent":
			var offered: String = str((e["c"] as Dictionary)["id"])
			for t: TalentDef in real_data().talents_for(str((e["c"] as Dictionary)["member"])):
				if t.id != offered:
					(e["c"] as Dictionary)["id"] = t.id
					break
			break
	var forged: Dictionary = RunSim.replay(real_data(), RunLog.from_dict(d))
	assert_ne(forged["final_hash"], run["hash"], "a forged pick does not reproduce the run")


func _runsim_run(seed: int) -> Dictionary:
	var data: GameData = real_data()
	var st: GameState = GameState.create_new(data, 0, "Kai", seed, &"prime")
	var sim: RunSim = RunSim.new(data, st, {})
	var rl: RunLog = RunLog.new()
	rl.header = {"schema": 1, "seed": seed, "slot": 0, "player_name": "Kai", "difficulty": "prime",
		"mode": "campaign", "sim_hz": RunSim.TICKS_PER_SEC, "event_id": "", "run_id": "run_b_%d" % seed}
	sim.run_log = rl
	sim.apply({"t": "floor", "floor": 1})
	for enc: String in ["enc_f1_a1_tutorial", "enc_f1_a2", "enc_f1_a3", "enc_f1_a_rare", "enc_f1_a4", "enc_f1_b1",
			"enc_f1_b4"]:
		if st.member("mopsula").level >= 3 and st.member("kai").level >= 3:
			break
		sim.apply({"t": "rest"})
		sim.apply({"t": "encounter", "enc": enc, "adv": BattleSetup.Advantage.PREEMPTIVE, "group": ""})
		var guard: int = 0
		while sim.battle != null and guard < 600:
			guard += 1
			sim.apply({"t": "battle", "cmd": sim.battle.choose_ai_command().to_dict(), "auto": true})
	var fdef: FloorDef = data.floor_def(1)
	var sr: String = str((fdef.layout.get("safe_rooms", []) as Array)[0]["id"])
	sim.apply({"t": "safe_room", "id": sr})
	for m: PartyMember in st.party:
		while Talents.has_choice(st, data, m.id):
			sim.apply({"t": "talent", "member": m.id, "id": Talents.current_offer(st, data, m.id)[0]})
	sim.apply({"t": "safe_room_exit"})
	var h: String = sim.close("floor_completed")
	return {"log": rl, "hash": h, "state": st}


## The live path: Game facade (Show in the loop) → Game.replay_log reproduces the live StateHash with talent picks.
func test_game_facade_replays_talent_picks() -> void:
	Game.auto_battle = true
	Game.new_game(0, "Kai", 5150)
	var fdef: FloorDef = DB.floor_def(1)
	for enc: String in ["enc_f1_a1_tutorial", "enc_f1_a2", "enc_f1_a3", "enc_f1_a_rare", "enc_f1_a4", "enc_f1_b1"]:
		if Game.state.member("kai").level >= 3 and Game.state.member("mopsula").level >= 3:
			break
		Game.rest_full_heal()
		_game_battle(enc)
	var srs: Array = fdef.layout.get("safe_rooms", [])
	Game.enter_safe_room(str((srs[0] as Dictionary)["id"]))
	var picked: int = 0
	for m: PartyMember in Game.state.party:
		while Talents.has_choice(Game.state, DB.data, m.id):
			assert_true(Game.pick_talent(m.id, Talents.current_offer(Game.state, DB.data, m.id)[1]))
			picked += 1
	Game.leave_safe_room()
	assert_gt(picked, 1, "both members picked")
	var live: String = StateHash.of(Game.state)
	var res: Dictionary = Game.replay_log(Game.run_log)
	assert_eq(res["final_hash"], live, "Game.replay_log ≡ live run with talent picks")
	Game.auto_battle = false


func _game_battle(enc: String) -> void:
	var setup: BattleSetup = Game.make_battle_setup(enc, BattleSetup.Advantage.PREEMPTIVE, "")
	var battle: BattleState = BattleState.new(setup, DB.data)
	Show.begin_battle(setup)
	Events.battle_started.emit(setup.encounter_id, setup.is_boss)
	_play(battle, battle.start())
	var guard: int = 0
	while not battle.is_finished() and guard < 600:
		guard += 1
		var cmd: BattleCommand = battle.choose_ai_command()
		Game.record({"t": "battle", "cmd": cmd.to_dict(), "auto": true})
		_play(battle, battle.submit(cmd))
	Events.battle_ended.emit(battle.result.outcome, battle.result.encounter_id)
	Game.apply_battle_result(battle.result)
	Show.end_battle(battle.result)


## Like BattleController._play / Game._replay_play: events → Show, then one pending sponsor gift at the boundary.
func _play(battle: BattleState, events: Array[ActionEvent]) -> void:
	for e: ActionEvent in events:
		Show.on_battle_event(e)
	if battle.is_finished():
		return
	var g: Dictionary = Show.take_pending_gift(battle)
	if not g.is_empty():
		var gift_events: Array[ActionEvent] = battle.apply_gift(g)
		Show.note_battle_gift(g, gift_events)
		for e: ActionEvent in gift_events:
			Show.on_battle_event(e)


func test_save_round_trip_and_hash_compatibility() -> void:
	var d: GameData = real_data()
	var st: GameState = _state(4242, 5)
	var plain: Dictionary = st.member("kai").to_dict()
	assert_false(plain.has("talents"), "no talents → no key: older saves / run logs keep their StateHash")
	assert_false(plain.has("species_id"))
	assert_false(plain.has("casting"))
	var h0: String = StateHash.of(st)
	st.member("kai").talents = {"tal_kai_wischtechnik": 2}
	assert_ne(StateHash.of(st), h0, "talents are part of the hash")
	var back: GameState = GameState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())))
	assert_eq(back.member("kai").talents, {"tal_kai_wischtechnik": 2}, "JSON round trip (ints back from floats)")
	assert_eq(StateHash.of(back), StateHash.of(st))
	assert_eq(Array(Talents.pending_levels(back.member("kai"))), [], "2 picks resolve L3 + L5")
	# an old save without the field: both choices open (derived), nothing stored
	var old: Dictionary = st.member("mopsula").to_dict()
	old.erase("talents")
	var om: PartyMember = PartyMember.from_dict(old)
	assert_eq(om.talents, {})
	assert_eq(Array(Talents.pending_levels(om)), [3, 5], "old L5 save: two choices wait in the Talent-Show")
	# SaveCodec drops unknown / foreign talents and clamps ranks
	st.member("kai").talents = {"tal_kai_wischtechnik": 5, "tal_gone": 1, "tal_mop_mitternachtsformel": 1}
	var gs: GameState = SaveCodec.decode(JSON.parse_string(JSON.stringify(SaveCodec.encode(st, "test"))), d)
	assert_not_null(gs, "decoded")
	if gs != null:
		assert_eq(gs.member("kai").talents, {"tal_kai_wischtechnik": 2}, "unknown/foreign dropped, rank clamped")
