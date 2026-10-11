extends TestCase
## 07 §12.5 R4 test_r4_rt_data: the real-time content of floor 1. Every floor-1 enemy, every skill it or the party
## uses, every status they apply, the party, the consumables and the encounters carry rt blocks; the real data passes
## validators/rt.gd (V1–V14) and validators/show_boss.gd without a warning; the new entries of 07 §4.11 / E26 exist;
## the bosses follow 07 §6.6–6.7 (phases, Gleis-9 stage); and the validator rejects the typical mistakes (negative
## cases on a copy of the real data, GameData.load_from_tables).

const Harness := preload("res://tests/tools/rt_harness.gd")
const Damage := preload("res://core/rt/rt_damage.gd")
const FixedMath := preload("res://core/stats/fixed_math.gd")

const NEW_STATUSES: PackedStringArray = ["sts_taunted", "sts_dazed", "sts_regen", "sts_burn", "sts_admonished",
	"sts_dizzy", "sts_enrage", "sts_spores"]
const NEW_SKILLS: PackedStringArray = ["skl_rt_auto_mopsula", "skl_e_azubi_hop", "skl_e_showboss_slow", "skl_q_train",
	"skl_q_scepter_flash", "skl_q_puddles"]
const FLOOR1_ENEMIES: PackedStringArray = ["enm_kanalratte", "enm_kanalratte_azubi", "enm_taubenschwarm", "enm_pendler",
	"enm_kanalschleim", "enm_rattenschamane", "enm_kabelsalat", "enm_kellerspinne", "enm_spruehgeist",
	"enm_rolltreppenkrabbe", "enm_rattengardist", "enm_fahrscheinfresser", "enm_boss_hausmeister",
	"enm_boss_rattenkoenigin"]


## The real data as file-shaped tables (+ rt_balance), for negative copies.
func _raw() -> Dictionary:
	var raw: Dictionary = {}
	for t: String in GameData.TABLES:
		raw[t] = JsonUtil.read_file("res://data/%s.json" % t)
	raw["rt_balance"] = JsonUtil.read_file("res://data/rt_balance.json")
	return raw


static func _entry(raw: Dictionary, table: String, id: String) -> Dictionary:
	for e: Variant in ((raw[table] as Dictionary)["entries"] as Array):
		if str((e as Dictionary).get("id", "")) == id:
			return e
	return {}


static func _encounter(raw: Dictionary, id: String) -> Dictionary:
	for f: Variant in ((raw["floors"] as Dictionary)["entries"] as Array):
		for e: Variant in ((f as Dictionary).get("encounters", []) as Array):
			if str((e as Dictionary).get("id", "")) == id:
				return e
	return {}


## Every skill an enemy uses in real time: auto skills, rules (and their "then"), phase rules and telegraph ops.
static func _enemy_skills(rt: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for k: String in ["auto_skill", "auto_ranged_skill"]:
		if str(rt.get(k, "")) != "":
			out.append(str(rt[k]))
	var rules: Array = (rt.get("rules", []) as Array).duplicate()
	for p: Variant in (rt.get("phases", []) as Array):
		rules.append_array((p as Dictionary).get("rules", []) as Array)
		for op: Variant in ((p as Dictionary).get("on_enter", []) as Array):
			if str((op as Dictionary).get("skill", "")) != "":
				out.append(str((op as Dictionary)["skill"]))
	for r: Variant in rules:
		out.append(str((r as Dictionary).get("skill", "")))
		var then: Variant = (r as Dictionary).get("then", {})
		if then is Dictionary and str((then as Dictionary).get("skill", "")) != "":
			out.append(str((then as Dictionary)["skill"]))
	return out


func test_real_data_valid_without_warnings() -> void:
	var d: GameData = real_data()
	assert_eq(d.errors, PackedStringArray(), "no errors")
	assert_eq(d.warnings, PackedStringArray(), "no warnings (e.g. a show-boss banner tag without a line)")
	assert_eq(RtBalance.validate(JsonUtil.read_file("res://data/rt_balance.json")), PackedStringArray(),
		"rt_balance.json: every key, every value in its range (V1, V14)")


func test_floor1_content_has_rt_blocks() -> void:
	var d: GameData = real_data()
	var used_skills: Dictionary = {}
	var used_statuses: Dictionary = {}
	for id: String in FLOOR1_ENEMIES:
		var e: EnemyDef = d.enemy(id)
		assert_false(e.rt.is_empty(), id + ": rt block (V10)")
		for sid: String in _enemy_skills(e.rt):
			used_skills[sid] = id
	for m: PartyMemberDef in d.all_party():
		assert_false(m.rt.is_empty(), m.id + ": rt block (V8)")
		used_skills[str(m.rt.get("auto_skill", ""))] = m.id
		for b: Variant in (m.rt.get("bar", []) as Array):
			used_skills[str((b as Dictionary).get("skill", ""))] = m.id
	for item: ItemDef in d.all_items():
		if item.type == "consumable" and (item.usable == "battle" or item.usable == "both"):
			assert_false(item.rt.is_empty(), item.id + ": wheel position (07 §4.8)")
			used_skills[item.use_skill] = item.id
	for sid: Variant in used_skills.keys():
		var sk: SkillDef = d.skill(str(sid))
		assert_not_null(sk, "%s (used by %s)" % [str(sid), str(used_skills[sid])])
		if sk == null:
			continue
		assert_false(sk.rt.is_empty(), "%s (used by %s): rt block (V4)" % [str(sid), str(used_skills[sid])])
		for st: Variant in (sk.rt.get("statuses", []) as Array):
			used_statuses[str((st as Dictionary).get("id", ""))] = sid
	for st: Variant in used_statuses.keys():
		assert_false(d.status(str(st)).rt.is_empty(), "%s (applied by %s): rt block" % [str(st), str(used_statuses[st])])
	for f: FloorDef in d.all_floors():
		if f.index != 1:
			continue
		for enc: EncounterDef in f.encounters:
			for id: String in (enc.rt.get("enemies", []) as Array) + Array(enc.enemies):
				assert_has(FLOOR1_ENEMIES, id, enc.id + ": a floor-1 enemy with an rt block")


func test_new_entries_of_r4() -> void:
	var d: GameData = real_data()
	for id: String in NEW_STATUSES:
		assert_true(d.has_id("statuses", id), id)
	for id: String in NEW_SKILLS:
		assert_true(d.has_id("skills", id), id)
		if d.has_id("skills", id):
			assert_false(d.skill(id).rt.is_empty(), id + ": rt block")
	assert_eq(d.enemy("enm_kanalratte_azubi").rt.get("hp", 0), 280, "the tutorial rat: 280 HP absolute (07 §6.5)")
	assert_eq(d.encounter("enc_f1_a1_tutorial").rt.get("enemies", []), ["enm_kanalratte_azubi", "enm_kanalratte_azubi"])
	assert_eq(d.encounter("enc_f1_a1_tutorial").rt.get("tutorial", []), ["target", "bar1", "show", "dodge"])
	for tag: String in ["rt_interrupt", "rt_train_kill", "rt_healer_first", "rt_finale", "showboss_rule",
			"showboss_spotted", "showboss_won", "rt_enrage:enm_boss_hausmeister", "rt_enrage:enm_boss_rattenkoenigin",
			"rt_tutorial_dodge", "rt_hint_zone"]:
		assert_false(d.mod_lines(tag).is_empty(), "M.O.D. lines for '%s'" % tag)
	# the interrupt card keeps R3's wording: it names the interrupter's key per hero and device (07 §2.13)
	assert_true(d.mod_lines("rt_hint_interrupt").is_empty(), "no rt_hint_interrupt line")


func test_bosses_follow_07() -> void:
	var d: GameData = real_data()
	var hm: Dictionary = d.enemy("enm_boss_hausmeister").rt
	assert_eq((hm["phases"] as Array).size(), 3, "Hausmeister: Kehrwoche, Hausordnung § 7, Feierabend")
	assert_eq([int(hm["phases"][0]["hp_above_pm"]), int(hm["phases"][1]["hp_above_pm"]),
		int(hm["phases"][2]["hp_above_pm"])], [600, 250, 0], "phase thresholds 60 % / 25 % (07 §6.6)")
	assert_eq(int((hm["enrage"] as Dictionary)["at_ms"]), 270000, "enrage at 4:30")
	var q: Dictionary = d.enemy("enm_boss_rattenkoenigin").rt
	assert_eq((q["phases"] as Array).size(), 3, "Königin: Hofstaat, Zug fährt ein, Endstation")
	assert_eq([int(q["phases"][0]["hp_above_pm"]), int(q["phases"][1]["hp_above_pm"])], [650, 300])
	assert_true(bool(q.get("stationary", false)), "P1 / P2 on the waggon")
	var p3_ops: Array = []
	for op: Variant in (q["phases"][2]["on_enter"] as Array):
		p3_ops.append(str((op as Dictionary)["op"]))
	for op: String in ["say", "fixed_damage_self", "clear_zones", "set", "status_self"]:
		assert_has(p3_ops, op, "P3 „Endstation“: " + op)
	# R5b (07 §6.7, §11.5 "Stand R5b-1"): the scepter flash in reach and out of reach (magical shock: the tank's
	# armour counts by RES, so the Unterhosen-Liga step of the tank stays small), no plague spit any more
	assert_eq([str(q.get("auto_skill", "")), str(q.get("auto_ranged_skill", ""))],
		["skl_q_scepter_flash", "skl_q_scepter_flash"], "the queen's auto attack in and out of reach")
	assert_eq([d.skill("skl_q_scepter_flash").damage_type, d.skill("skl_q_scepter_flash").element,
		int(d.skill("skl_q_scepter_flash").rt["range_cm"])], ["magical", "shock", 1500])
	var train: Dictionary = d.skill("skl_q_train").rt
	assert_true(bool(train.get("kill_adds", false)) and bool(train.get("ignore_guard", false)), "train: kill adds")
	assert_eq(int(train.get("pct_maxhp", 0)), 35, "train: 35 %")
	assert_eq(str((train["telegraph"] as Dictionary)["anchor"]), "lane")
	assert_eq((d.encounter("enc_f1_boss_rattenkoenigin").rt.get("blockers", []) as Array).size(), 1,
		"the derailed waggon is the stage's one blocker (07 §3.5.4)")


## The species passives R4 maps (07 §9.6, BattleBridge._rt_species_unit / _rt_species_mods): Pilzling (pas_spores) —
## poison immunity and the Sporenkur for the whole combat (+1 % max HP every 3 s); Neonfalter (pas_lightdrunk) — +10 %
## crit when the hype stands at 70 or more at the start, nothing below.
func test_species_passives_in_real_time() -> void:
	var d: GameData = real_data()
	var crit: Dictionary = {}
	for c: Array in [["spc_kai_pilzling", 50], ["spc_kai_neonfalter", 69], ["spc_kai_neonfalter", 70]]:
		var st: GameState = Harness.state_for(d, "enc_f1_b2", "kai", 0, 0)
		st.member("kai").species_id = str(c[0])
		st.show.hype = float(c[1])
		var cmd: Dictionary = Harness.command_for("enc_f1_b2", "kai", BattleSetup.Advantage.NORMAL)
		var sim: RtSim = RtSim.new(BattleBridge.make_rt_setup(st, d, cmd, 7), d)
		var kai: RtUnit = null
		for u: RtUnit in sim.units():
			if u.def_id == "kai":
				kai = u
		crit["%s %d" % c] = kai.crit_bonus
		if str(c[0]) != "spc_kai_pilzling":
			assert_false(kai.status_immune.has("sts_poison"), "only the Pilzling is immune to poison")
			continue
		assert_true(kai.status_immune.has("sts_poison"), "Pilzling: immune to poison")
		sim.start()
		for i in 95:
			sim.step()
		assert_true(kai.has_status("sts_spores"), "Pilzling: Sporenkur from the combat start on")
	assert_almost(float(crit["spc_kai_neonfalter 70"]) - float(crit["spc_kai_neonfalter 69"]), 0.1, 0.0001,
		"Neonfalter: +10 % crit from hype 70 on")
	assert_almost(float(crit["spc_kai_neonfalter 69"]), float(crit["spc_kai_pilzling 50"]), 0.0001, "below: nothing")


## E30 and the difficulty on percent hits with the real data (07 §3.9.1): the queen's poison puddles (rt.pct_maxhp of
## the data) on Graf Mopsula with the gas mask (poison immunity → counts as 500 ‰) and on Kai in the sewer suit (poison
## × 0.5), the train (physical, 35 %) unchanged — and on Vorabend everything × EASY_ENEMY_DMG (enemy_dmg_mult folds into
## percent hits).
func test_percent_hits_e30_and_difficulty() -> void:
	var d: GameData = real_data()
	for diff: StringName in [&"prime", &"vorabend"]:
		var st: GameState = Harness.state_for(d, "enc_f1_boss_rattenkoenigin", "kai", 0, 0)
		st.member("kai").equipment["armor"] = "itm_arm_sewer_suit"
		assert_eq(st.member("mopsula").equipment["accessory"], "itm_acc_gas_mask", "late gear: the gas mask")
		Progression.full_heal(st, d)
		var cmd: Dictionary = Harness.command_for("enc_f1_boss_rattenkoenigin", "kai", BattleSetup.Advantage.NORMAL)
		(cmd["rt"] as Dictionary)["diff"] = String(diff)          # the recorded difficulty (07 §10.1)
		var sim: RtSim = RtSim.new(BattleBridge.make_rt_setup(st, d, cmd, 5), d)
		sim.start()
		var queen: RtUnit = null
		for u: RtUnit in sim.units():
			if u.is_boss:
				queen = u
		var mult: int = 1000 if diff == &"prime" else roundi(Balance.EASY_ENEMY_DMG * 1000.0)
		assert_eq(roundi(sim.setup.enemy_dmg_mult * 1000.0), mult, "enemy_dmg_mult of %s" % diff)
		# [unit, skill, E30 element factor, equipment mod]: R5b — Mopsula's Samtcape (items rt.mods) takes 10 % off
		# physical hits only (the train, not the poison puddles), folded after the element-free factors
		for c: Array in [["p1", "skl_q_puddles", 500, 0], ["p0", "skl_q_puddles", 500, 0],
				["p1", "skl_q_train", 1000, 900]]:
			var u: RtUnit = sim.unit(str(c[0]))
			var sk: SkillDef = d.skill(str(c[1]))
			var pct: int = int(sk.rt["pct_maxhp"])
			assert_eq(Damage.pct_element_pm(u, sk.element), int(c[2]), "%s: E30 factor" % str(c))
			var before: int = u.hp
			var factors: Array[int] = [int(c[2]), mult]
			if int(c[3]) > 0:
				factors.append(int(c[3]))
			var want: int = Damage.fold(FixedMath.div_round(u.max_hp() * pct, 100), factors,
				sim.bal.i("DMG_FACTOR_MAX_PM"))
			Damage.pct_hit(sim, queen, u, sk, pct, Damage.Kind.TELEGRAPH, true, -1)
			assert_eq(before - u.hp, want, "%s (%d %%) on %s (%s)" % [sk.id, pct, str(c[0]), diff])


## [case, expected error fragment]: every case mutates its own copy of the real data (_mutate).
func test_validator_rejects_bad_rt_blocks() -> void:
	var cases: Array = [
		["telegraph_pct", "an enemy telegraph hits"],
		["filler_interruptible", "is a filler"],
		["enemy_unknown_key", "unknown key"],
		["enemy_without_rt", "has no rt block (V10"],
		["phases_not_descending", "strictly descending"],
		["partner_special_off_bar", "is not on this member's bar"],
		["blocker_reversed", "x0 < x1"],
		["elite_pm", "elite_pm"],
		["reward_unknown_box", "box_nonexistent"],
		["banner_tag_prefix", "showboss_"],
		["show_boss_on_tutorial", "a show boss is an optional regular group"],
		["show_boss_rule_every", "every_ms"],
		["balance_range", "ENEMY_HP_PM"],
	]
	var base: Dictionary = _raw()
	var ok: GameData = GameData.new()
	assert_true(ok.load_from_tables(base.duplicate(true)), "the unchanged copy loads: " + "; ".join(ok.errors))
	for c: Array in cases:
		var raw: Dictionary = base.duplicate(true)
		_mutate(raw, str(c[0]))
		var d: GameData = GameData.new()
		d.load_from_tables(raw)
		var joined: String = " | ".join(d.errors)
		assert_true(joined.contains(str(c[1])), "%s: '%s' expected in: %s" % [str(c[0]), str(c[1]), joined.left(600)])


static func _mutate(r: Dictionary, what: String) -> void:
	var sb: Dictionary = _encounter(r, "enc_e1_showboss").get("show_boss", {})
	match what:
		"telegraph_pct":
			(_entry(r, "skills", "skl_b_keys")["rt"] as Dictionary)["pct_maxhp"] = 50
		"filler_interruptible":
			(_entry(r, "skills", "skl_e_zap")["rt"] as Dictionary)["interruptible"] = true
		"enemy_unknown_key":
			(_entry(r, "enemies", "enm_kanalratte")["rt"] as Dictionary)["wings"] = 2
		"enemy_without_rt":
			_entry(r, "enemies", "enm_pendler").erase("rt")
		"phases_not_descending":
			var phases: Array = (_entry(r, "enemies", "enm_boss_hausmeister")["rt"] as Dictionary)["phases"]
			(phases[1] as Dictionary)["hp_above_pm"] = 700
		"partner_special_off_bar":
			(_entry(r, "party", "kai")["rt"] as Dictionary)["partner_special"] = "skl_mop_noble_flame"
		"blocker_reversed":
			(_encounter(r, "enc_f1_boss_rattenkoenigin")["rt"] as Dictionary)["blockers"] = [[160, -80, -160, 80]]
		"elite_pm":
			sb["elite_pm"] = 2500
		"reward_unknown_box":
			sb["reward"] = {"kind": "box", "id": "box_nonexistent"}
		"banner_tag_prefix":
			sb["banner_tag"] = "rt_finale"
		"show_boss_on_tutorial":
			_encounter(r, "enc_f1_a1_tutorial")["show_boss"] = sb.duplicate(true)
		"show_boss_rule_every":
			(sb["rule"] as Dictionary)["every_ms"] = 500
		"balance_range":
			((r["rt_balance"] as Dictionary)["values"] as Dictionary)["ENEMY_HP_PM"] = 50000
