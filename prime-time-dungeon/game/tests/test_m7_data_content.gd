extends TestCase
## M7 data content (02_TECH §11.5): res://data is valid and holds the complete Floor-1 content of 01_GDD —
## quantities, the numbers of the GDD tables (stats, skills, items, prices, AI patterns, rewards) and cross-table sanity
## (every AI action is affordable, every consumable reachable, shops priced, encounter EXP/credits = GDD §5.4).

const KAI_SKILLS: PackedStringArray = ["skl_kai_heavy_swing", "skl_kai_taunt", "skl_kai_sweep", "skl_kai_first_aid",
	"skl_kai_leash_trip", "skl_kai_deo_torch", "skl_kai_cable_whip", "skl_kai_prime_finisher"]
const MOP_SKILLS: PackedStringArray = ["skl_mop_noble_flame", "skl_mop_holy_lick", "skl_mop_frost_sneeze",
	"skl_mop_thunder_bark", "skl_mop_royal_decree", "skl_mop_mass_lick", "skl_mop_revive", "skl_mop_inferno"]
const ENEMY_SKILLS_F1: PackedStringArray = ["skl_e_bite", "skl_e_gnaw_poison", "skl_e_peck", "skl_e_dive_bomb",
	"skl_e_briefcase", "skl_e_delay_rage", "skl_e_slam", "skl_e_toxic_splash", "skl_e_zap", "skl_e_rat_heal",
	"skl_e_lash", "skl_e_short_circuit", "skl_e_venom_bite", "skl_e_web", "skl_e_spray_flame", "skl_e_fumes",
	"skl_e_pinch", "skl_e_brace", "skl_e_step_crush", "skl_e_halberd", "skl_e_shield_wall", "skl_e_lunge",
	"skl_e_ticket_cut", "skl_e_fine", "skl_e_escape"]
const BOSS_SKILLS: PackedStringArray = ["skl_b_broom", "skl_b_keys", "skl_b_rules", "skl_b_cleaner_fog",
	"skl_b_call_tenant", "skl_b_mop_whirl", "skl_q_scepter", "skl_q_plague_bite", "skl_q_screech", "skl_q_summon",
	"skl_q_crown_nova"]
const REGULAR_F1: PackedStringArray = ["enm_kanalratte", "enm_taubenschwarm", "enm_pendler", "enm_kanalschleim",
	"enm_rattenschamane", "enm_kabelsalat", "enm_kellerspinne", "enm_spruehgeist", "enm_rolltreppenkrabbe",
	"enm_rattengardist", "enm_fahrscheinfresser"]
const BOSSES: PackedStringArray = ["enm_boss_hausmeister", "enm_boss_rattenkoenigin"]

## GDD §5.1: id → [lv, hp, mp, str, mag, def, res, spd, lck, exp, credits, field_speed].
const ENEMY_TABLE: Dictionary = {
	"enm_kanalratte": [1, 24, 0, 13, 3, 5, 3, 13, 5, 12, 6, 4.8],
	"enm_taubenschwarm": [2, 20, 0, 12, 4, 3, 6, 19, 8, 14, 5, 6.2],
	"enm_pendler": [2, 48, 0, 17, 2, 8, 4, 7, 3, 22, 14, 3.5],
	"enm_kanalschleim": [2, 40, 10, 12, 12, 10, 4, 9, 3, 20, 8, 3.0],
	"enm_rattenschamane": [3, 34, 30, 9, 16, 6, 12, 12, 6, 26, 12, 4.5],
	"enm_kabelsalat": [3, 46, 20, 14, 17, 12, 10, 14, 5, 30, 15, 4.0],
	"enm_kellerspinne": [4, 50, 10, 22, 6, 10, 8, 17, 10, 34, 12, 5.8],
	"enm_spruehgeist": [4, 44, 40, 8, 23, 18, 10, 15, 8, 36, 18, 5.0],
	"enm_rolltreppenkrabbe": [5, 72, 0, 25, 4, 24, 8, 10, 4, 60, 20, 3.8],
	"enm_rattengardist": [6, 78, 10, 27, 6, 17, 10, 14, 8, 66, 22, 5.0],
	"enm_fahrscheinfresser": [4, 60, 0, 18, 18, 20, 20, 16, 20, 60, 150, 0.0],
	"enm_boss_hausmeister": [6, 380, 60, 23, 14, 14, 10, 12, 6, 180, 200, 0.0],
	"enm_boss_rattenkoenigin": [8, 720, 120, 26, 20, 18, 16, 15, 10, 420, 500, 0.0],
}

## GDD §5.1 affinities: id → element_mods.
const AFFINITIES: Dictionary = {
	"enm_kanalratte": {"fire": 1.5},
	"enm_taubenschwarm": {"shock": 1.5},
	"enm_pendler": {"fire": 1.5, "poison": 0.5},
	"enm_kanalschleim": {"fire": 1.5, "physical": 0.5, "poison": 0.0},
	"enm_rattenschamane": {"fire": 1.5, "shock": 0.5},
	"enm_kabelsalat": {"ice": 1.5, "fire": 0.5, "shock": 0.0},
	"enm_kellerspinne": {"fire": 1.5, "poison": 0.0},
	"enm_spruehgeist": {"ice": 1.5, "physical": 0.5, "poison": 0.0},
	"enm_rolltreppenkrabbe": {"shock": 1.5, "physical": 0.5, "ice": 0.5},
	"enm_rattengardist": {"fire": 1.5, "ice": 1.5},
	"enm_fahrscheinfresser": {"shock": 1.5, "physical": 0.5, "poison": 0.0},
	"enm_boss_hausmeister": {"shock": 1.5, "poison": 0.5},
	"enm_boss_rattenkoenigin": {"ice": 1.5, "fire": 0.5, "poison": 0.0},
}

## GDD §5.4: encounter → [EXP total, credits total].
const ENCOUNTER_REWARDS: Dictionary = {
	"enc_f1_a1_tutorial": [24, 12], "enc_f1_a2": [38, 17], "enc_f1_a3": [36, 19], "enc_f1_a4": [40, 16],
	"enc_f1_a_rare": [60, 150], "enc_f1_b1": [44, 20], "enc_f1_b2": [50, 24], "enc_f1_b3": [50, 23],
	"enc_f1_b4": [66, 28], "enc_f1_c1": [68, 24], "enc_f1_c2": [66, 33], "enc_f1_c3": [82, 36],
	"enc_f1_boss_hausmeister": [180, 200], "enc_f1_d1": [86, 32], "enc_f1_d2": [158, 56], "enc_f1_d3": [126, 42],
	"enc_f1_boss_rattenkoenigin": [420, 500], "enc_f1_evt_pigeons": [28, 10], "enc_f1_evt_slime": [40, 16],
}

## GDD §6.1: consumable → [price, sell value, rarity, usable].
const CONSUMABLES: Dictionary = {
	"itm_bandage": [25, 12, "common", "both"], "itm_antidote": [20, 10, "common", "both"],
	"itm_energy_krawumm": [60, 30, "common", "both"], "itm_brutzel_burger": [80, 40, "rare", "both"],
	"itm_smelling_salts": [150, 75, "rare", "battle"], "itm_molotov": [70, 35, "common", "battle"],
	"itm_ice_spray": [50, 25, "common", "battle"], "itm_smoke": [100, 50, "rare", "battle"],
	"itm_hype_megaphone": [120, 60, "rare", "battle"], "itm_elixir": [0, 300, "epic", "both"],
}

## GDD §6.2–6.4: equipment → [type, price, sell value, rarity, stats, equip_by].
const EQUIPMENT: Dictionary = {
	"itm_wpn_mop": ["weapon", 0, 0, "common", {"str": 4}, ["kai"]],
	"itm_wpn_pipe_wrench": ["weapon", 220, 110, "common", {"str": 8}, ["kai"]],
	"itm_wpn_fire_axe": ["weapon", 480, 240, "epic", {"str": 12}, ["kai"]],
	"itm_wpn_rail_crowbar": ["weapon", 0, 250, "epic", {"str": 15}, ["kai"]],
	"itm_wpn_collar_leather": ["weapon", 0, 0, "common", {"mag": 4}, ["mopsula"]],
	"itm_wpn_collar_studded": ["weapon", 200, 100, "rare", {"mag": 7}, ["mopsula"]],
	"itm_wpn_collar_signet": ["weapon", 460, 230, "epic", {"mag": 11, "mp": 10}, ["mopsula"]],
	"itm_wpn_collar_royal": ["weapon", 0, 250, "epic", {"mag": 14, "mp": 15}, ["mopsula"]],
	"itm_arm_hoodie": ["armor", 0, 0, "common", {"def": 3, "res": 1}, ["kai"]],
	"itm_arm_safety_vest": ["armor", 180, 90, "rare", {"def": 6, "res": 2}, ["kai"]],
	"itm_arm_sewer_suit": ["armor", 420, 210, "common", {"def": 9, "res": 4}, ["kai"]],
	"itm_arm_pug_sweater": ["armor", 0, 0, "common", {"def": 2, "res": 3}, ["mopsula"]],
	"itm_arm_velvet_cape": ["armor", 220, 110, "common", {"def": 4, "res": 6}, ["mopsula"]],
	"itm_arm_ermine": ["armor", 0, 250, "epic", {"def": 6, "res": 9, "hp": 15}, ["mopsula"]],
	"itm_acc_lucky_ticket": ["accessory", 150, 75, "rare", {"lck": 5}, []],
	"itm_acc_rubber_boots": ["accessory", 200, 100, "rare", {}, []],
	"itm_acc_sneakers": ["accessory", 260, 130, "epic", {"spd": 2}, []],
	"itm_acc_gas_mask": ["accessory", 300, 150, "common", {}, []],
	"itm_acc_key_ring": ["accessory", 0, 150, "rare", {"def": 2}, []],
	"itm_acc_queen_crown": ["accessory", 0, 250, "epic", {"str": 3, "mag": 3, "spd": 1}, ["kai"]],
	"itm_acc_fan_scarf": ["accessory", 0, 150, "rare", {}, []],
	"itm_acc_clip_mic": ["accessory", 0, 150, "rare", {}, []],
}

## GDD §4.2 result table: level → [kai stats..., mopsula stats...] (without equipment; order = StatBlock.KEYS).
const LEVEL_TABLE: Dictionary = {
	1: [[64, 12, 12, 5, 9, 6, 11, 8], [42, 30, 5, 13, 6, 11, 14, 12]],
	3: [[82, 16, 16, 6, 12, 7, 12, 9], [54, 38, 6, 17, 7, 14, 15, 13]],
	5: [[100, 20, 20, 7, 15, 9, 13, 10], [66, 46, 7, 21, 9, 17, 16, 14]],
	7: [[118, 24, 24, 8, 18, 10, 14, 11], [78, 54, 8, 26, 10, 20, 17, 16]],
	8: [[127, 26, 26, 9, 19, 11, 14, 11], [84, 58, 9, 28, 11, 22, 18, 16]],
	10: [[145, 30, 30, 10, 22, 13, 15, 12], [96, 66, 10, 32, 13, 25, 19, 18]],
}
const STAT_KEYS: PackedStringArray = ["hp", "mp", "str", "mag", "def", "res", "spd", "lck"]


func _data() -> GameData:
	return real_data()


# --- validity + quantities -------------------------------------------------------------------------------------------

func test_real_data_is_valid_without_warnings() -> void:
	var d: GameData = GameData.new()
	assert_true(d.load_dir("res://data"), "errors: " + "; ".join(d.errors))
	assert_len(d.warnings, 0, "warnings: " + "; ".join(d.warnings))


func test_quantities_match_gdd() -> void:
	var d: GameData = _data()
	assert_len(d.all_statuses(), 6, "GDD §3.9: exactly 6 statuses")
	var party_skills: Dictionary = {}
	for m: PartyMemberDef in d.all_party():
		for l: Dictionary in m.learnset:
			party_skills[str(l["skill"])] = true
	assert_eq(party_skills.size(), 16, "8 skills per party member")
	for id: String in KAI_SKILLS + MOP_SKILLS:
		assert_true(party_skills.has(id), "learnset contains " + id)
	var stunts: int = 0
	var enemy_skills: int = 0
	var item_skills: int = 0
	for s: SkillDef in d.all_skills():
		if s.category == "stunt":
			stunts += 1
		if s.user == "item":
			item_skills += 1
		if s.user == "enemy":
			enemy_skills += 1
	assert_eq(stunts, 2, "2 stunts")
	for id: String in ENEMY_SKILLS_F1:
		assert_true(d.has_id("skills", id), "enemy skill " + id)
		if d.has_id("skills", id):
			assert_eq(d.skill(id).user, "enemy", id)
	for id: String in BOSS_SKILLS:
		assert_true(d.has_id("skills", id), "boss skill " + id)
	# Counted from the data (TECH §1.7: 25 enemy skills, 11 boss skills), not from the constants above.
	var f1_ai: Dictionary = {}
	var f2_ai: Dictionary = {}
	for e: EnemyDef in d.all_enemies():
		if e.boss:
			continue
		var bucket: Dictionary = f1_ai if e.tags.has("floor_1") else f2_ai
		for sid: String in _skills_of(e.ai.get("actions", []) as Array):
			if sid != "skl_e_strike":
				bucket[sid] = true
	var f1_list: Array = f1_ai.keys()
	f1_list.sort()
	var expected_f1: Array = Array(ENEMY_SKILLS_F1)
	expected_f1.sort()
	assert_eq(f1_list, expected_f1, "skills used by floor-1 regular enemy AI (minus strike) = GDD §5.2 list")
	assert_len(f1_list, 25, "25 floor-1 enemy skills")
	var boss_list: Array = []
	for sid: String in d.ids("skills"):
		if sid.begins_with("skl_b_") or sid.begins_with("skl_q_"):
			boss_list.append(sid)
	boss_list.sort()
	var expected_boss: Array = Array(BOSS_SKILLS)
	expected_boss.sort()
	assert_eq(boss_list, expected_boss, "skl_b_*/skl_q_* skills = GDD boss skill list")
	assert_len(boss_list, 11, "11 boss skills")
	for sid: String in f2_ai:
		assert_false(f1_ai.has(sid), sid + " is a floor-2 stub skill, not shared with floor 1")
	assert_eq(enemy_skills, 25 + 11 + 1 + f2_ai.size(), "enemy skills = 25 + 11 boss + strike + floor-2 stubs")
	assert_eq(item_skills, 10, "one use_skill per consumable")
	var regular: int = 0
	var bosses: int = 0
	for e: EnemyDef in d.all_enemies():
		if not e.tags.has("floor_1"):
			continue
		if e.boss:
			bosses += 1
		else:
			regular += 1
	assert_eq(regular, 11, "10 regular enemies + 1 rarity")
	assert_eq(bosses, 2)
	assert_len(d.all_achievements(), 29)
	assert_len(d.all_sponsors(), 7)
	assert_len(d.all_milestones(), 6)
	assert_len(d.all_scenes(), 4)
	assert_len(d.all_classes(), 8)
	assert_len(d.all_lootboxes(), 4)
	assert_len(d.all_pseudo_units(), 1)
	assert_len(d.all_floors(), 2)


func test_status_rows_match_gdd() -> void:
	var d: GameData = _data()
	var poison: StatusDef = d.status("sts_poison")
	assert_eq([poison.kind, poison.default_turns, poison.tick_timing, poison.tick_pct, poison.tick_min, poison.element],
		["debuff", 4, "turn_start", -8, 1, "poison"])
	assert_true(d.status("sts_stun").has_flag("delay_on_apply"))
	assert_eq(d.status("sts_stun").default_turns, 1)
	assert_almost(d.status("sts_slow").tick_speed_mult, 1.5)
	assert_almost(d.status("sts_haste").tick_speed_mult, 0.6)
	assert_eq(d.status("sts_slow").excludes, ["sts_haste"])
	assert_eq(d.status("sts_haste").excludes, ["sts_slow"])
	assert_true(d.status("sts_guard").has_flag("guard"))
	assert_true(d.status("sts_taunt").has_flag("taunt"))
	assert_eq(d.status("sts_haste").kind, "buff")
	assert_eq(d.status("sts_slow").kind, "debuff")


# --- party ---------------------------------------------------------------------------------------------------------

func test_party_level_table_matches_gdd() -> void:
	var d: GameData = _data()
	var members: Array[PartyMemberDef] = [d.party_member("kai"), d.party_member("mopsula")]
	for level: int in LEVEL_TABLE:
		var rows: Array = LEVEL_TABLE[level]
		for m in 2:
			var def: PartyMemberDef = members[m]
			var row: Array = rows[m]
			for i in STAT_KEYS.size():
				var k: String = STAT_KEYS[i]
				var v: int = floori(float(def.base_stats[k]) + float(def.growth[k]) * float(level - 1))
				assert_eq(v, int(row[i]), "%s L%d %s" % [def.id, level, k])


func test_party_start_block_and_equipment() -> void:
	var d: GameData = _data()
	assert_eq(d.party_start(), {"inventory": {"itm_bandage": 3, "itm_antidote": 1}, "credits": 50})
	var kai: PartyMemberDef = d.party_member("kai")
	var mop: PartyMemberDef = d.party_member("mopsula")
	assert_eq(kai.equipment, {"weapon": "itm_wpn_mop", "armor": "itm_arm_hoodie", "accessory": ""})
	assert_eq(mop.equipment, {"weapon": "itm_wpn_collar_leather", "armor": "itm_arm_pug_sweater", "accessory": ""})
	assert_eq([kai.battle_slot, mop.battle_slot], [0, 1])
	assert_eq(mop.title, "Graf")
	assert_eq(kai.stunts, ["skl_stunt_kai_suplex"])
	assert_eq(mop.stunts, ["skl_stunt_mop_entrance"])
	assert_eq(kai.attack_skill, "skl_attack_kai")
	assert_eq(mop.attack_skill, "skl_attack_mopsula")
	assert_eq(kai.model["base"], "humanoid")
	assert_has(kai.model["props"], "mop")
	assert_eq(mop.model["base"], "pug")
	assert_false((mop.model["props"] as PackedStringArray).has("crown"), "no crown motif on Mopsula (03_ART §5.3)")
	# Unlock levels (GDD §4.5 / §4.6).
	var kai_levels: Array = []
	for l: Dictionary in kai.learnset:
		kai_levels.append(int(l["level"]))
	assert_eq(kai_levels, [1, 2, 3, 4, 5, 6, 7, 9])
	var mop_levels: Array = []
	for l: Dictionary in mop.learnset:
		mop_levels.append(int(l["level"]))
	assert_eq(mop_levels, [1, 1, 2, 3, 4, 6, 7, 9])
	# Level 1: exactly one damage skill + Mopsula's heal (start kit of GameState.create_new).
	var learnable_l1: int = 0
	for m: PartyMemberDef in d.all_party():
		for l: Dictionary in m.learnset:
			if int(l["level"]) == 1:
				learnable_l1 += 1
	assert_eq(learnable_l1, 3)


func test_party_skill_rows_match_gdd() -> void:
	var d: GameData = _data()
	# id → [mp, power, rank, target, element, damage_type]
	var rows: Dictionary = {
		"skl_kai_heavy_swing": [3, 160, 4, "single_enemy", "physical", "physical"],
		"skl_kai_taunt": [2, 0, 2, "self", "none", "none"],
		"skl_kai_sweep": [5, 80, 3, "all_enemies", "physical", "physical"],
		"skl_kai_first_aid": [4, 30, 2, "single_ally", "none", "heal"],
		"skl_kai_leash_trip": [5, 70, 3, "single_enemy", "physical", "physical"],
		"skl_kai_deo_torch": [7, 130, 3, "single_enemy", "fire", "physical"],
		"skl_kai_cable_whip": [8, 120, 3, "single_enemy", "shock", "physical"],
		"skl_kai_prime_finisher": [12, 260, 5, "single_enemy", "physical", "physical"],
		"skl_mop_noble_flame": [4, 110, 3, "single_enemy", "fire", "magical"],
		"skl_mop_holy_lick": [4, 100, 2, "single_ally", "none", "heal"],
		"skl_mop_frost_sneeze": [5, 105, 3, "single_enemy", "ice", "magical"],
		"skl_mop_thunder_bark": [7, 75, 3, "all_enemies", "shock", "magical"],
		"skl_mop_royal_decree": [6, 0, 2, "single_ally", "none", "none"],
		"skl_mop_mass_lick": [10, 60, 3, "all_allies", "none", "heal"],
		"skl_mop_revive": [14, 40, 4, "single_ally_ko", "none", "heal"],
		"skl_mop_inferno": [14, 130, 4, "all_enemies", "fire", "magical"],
		"skl_attack_kai": [0, 100, 3, "single_enemy", "physical", "physical"],
		"skl_attack_mopsula": [0, 100, 3, "single_enemy", "physical", "physical"],
		"skl_e_strike": [0, 100, 3, "single_enemy", "physical", "physical"],
	}
	for id: String in rows:
		var s: SkillDef = d.skill(id)
		var r: Array = rows[id]
		assert_eq([s.mp_cost, s.power, s.rank, s.target, s.element, s.damage_type], r, id)
		assert_eq(s.accuracy, -1, id + " always hits")
	assert_eq(d.skill("skl_kai_first_aid").heal_mode, "pct")
	assert_eq(d.skill("skl_kai_first_aid").cleanse, ["sts_poison"])
	assert_eq(d.skill("skl_mop_mass_lick").cleanse, ["sts_poison"])
	assert_eq(d.skill("skl_mop_holy_lick").heal_mode, "mag")
	assert_eq(d.skill("skl_mop_revive").heal_mode, "pct")
	assert_eq(d.skill("skl_kai_taunt").statuses, [{"id": "sts_taunt", "chance": 1.0, "turns": 3},
		{"id": "sts_guard", "chance": 1.0, "turns": 3}])
	assert_eq(d.skill("skl_kai_leash_trip").statuses, [{"id": "sts_slow", "chance": 0.9, "turns": 3}])
	assert_eq(d.skill("skl_kai_cable_whip").statuses, [{"id": "sts_stun", "chance": 0.35, "turns": 0}])
	assert_eq(d.skill("skl_mop_frost_sneeze").statuses, [{"id": "sts_slow", "chance": 0.25, "turns": 3}])
	assert_eq(d.skill("skl_mop_royal_decree").statuses, [{"id": "sts_haste", "chance": 1.0, "turns": 3}])
	assert_almost(d.skill("skl_kai_prime_finisher").crit_bonus, 0.2)
	assert_eq(d.skill("skl_kai_prime_finisher").kill_hype, 10)


func test_stunts_match_gdd() -> void:
	var d: GameData = _data()
	var suplex: SkillDef = d.skill("skl_stunt_kai_suplex")
	assert_eq([suplex.category, suplex.rank, suplex.cooldown, suplex.power, suplex.target, suplex.damage_type],
		["stunt", 4, 3, 230, "single_enemy", "physical"])
	assert_eq([suplex.success_base, suplex.success_lck, suplex.success_cap, suplex.success_boss_mod],
		[0.60, 0.01, 0.85, -0.15])
	assert_eq(suplex.fail_effect, {"self_dmg_pct": 10, "delay_pct": 50, "status": "", "status_turns": 0})
	var entrance: SkillDef = d.skill("skl_stunt_mop_entrance")
	assert_eq([entrance.category, entrance.rank, entrance.cooldown, entrance.power, entrance.target, entrance.element,
		entrance.damage_type], ["stunt", 4, 3, 140, "all_enemies", "fire", "magical"])
	assert_eq([entrance.success_base, entrance.success_lck, entrance.success_cap, entrance.success_boss_mod],
		[0.55, 0.01, 0.85, -0.15])
	assert_eq(entrance.fail_effect, {"self_dmg_pct": 0, "delay_pct": 0, "status": "sts_stun", "status_turns": 0})
	for s: SkillDef in [suplex, entrance]:
		assert_eq(s.mp_cost, 0, s.id + ": stunts cost no MP")
		assert_has(s.show_tags, "risky")
		# Kai L5 with LCK 10: 0.70 (GDD §3.6 example) and 0.55 against bosses.
	assert_almost(minf(suplex.success_base + 10.0 * suplex.success_lck, suplex.success_cap), 0.70)
	assert_almost(minf(suplex.success_base + 10.0 * suplex.success_lck, suplex.success_cap) + suplex.success_boss_mod,
		0.55)


# --- enemies -------------------------------------------------------------------------------------------------------

func test_enemy_table_matches_gdd() -> void:
	var d: GameData = _data()
	for id: String in ENEMY_TABLE:
		var e: EnemyDef = d.enemy(id)
		var r: Array = ENEMY_TABLE[id]
		var got: Array = [e.level]
		for k: String in STAT_KEYS:
			got.append(int(e.stats[k]))
		got.append(e.exp)
		got.append(e.credits)
		got.append(float(e.explore["field_speed"]))
		assert_eq(got, r, id)
		assert_eq(e.element_mods, AFFINITIES[id], id + " affinities")
		if float((AFFINITIES[id] as Dictionary).get("poison", 1.0)) == 0.0:
			assert_eq(e.status_immune, ["sts_poison"], id + ": poison immunity also blocks the status")
		assert_eq(e.attack_skill, "skl_e_strike", id + " fallback attack")
	for id: String in BOSSES:
		var b: EnemyDef = d.enemy(id)
		assert_true(b.boss)
		assert_true(b.is_phased())
		assert_len(b.phases, 3)
		assert_eq(b.status_resist, {"sts_stun": 0.5, "sts_slow": 0.5})
	assert_almost(float(d.enemy("enm_taubenschwarm").explore["sight_range"]), 14.0)
	var fr: EnemyDef = d.enemy("enm_fahrscheinfresser")
	for k: String in ["field_speed", "sight_range", "hear_run", "hear_sneak"]:
		assert_almost(float(fr.explore[k]), 0.0, 0.0001, "Fahrscheinfresser never reacts: " + k)
	assert_almost(float(d.enemy("enm_kanalratte").explore["sight_range"]), 10.0, 0.0001, "default sight")


func test_enemy_drops_match_gdd() -> void:
	var d: GameData = _data()
	var drops: Dictionary = {
		"enm_kanalratte": {"itm_bandage": 0.25, "itm_antidote": 0.10},
		"enm_taubenschwarm": {"itm_bandage": 0.20},
		"enm_pendler": {"itm_energy_krawumm": 0.15},
		"enm_kanalschleim": {"itm_antidote": 0.30},
		"enm_rattenschamane": {"itm_energy_krawumm": 0.25, "itm_smelling_salts": 0.05},
		"enm_kabelsalat": {"itm_energy_krawumm": 0.15, "itm_acc_rubber_boots": 0.05},
		"enm_kellerspinne": {"itm_antidote": 0.30, "itm_bandage": 0.20},
		"enm_spruehgeist": {"itm_ice_spray": 0.20, "itm_hype_megaphone": 0.05},
		"enm_rolltreppenkrabbe": {"itm_brutzel_burger": 0.20, "itm_arm_safety_vest": 0.05},
		"enm_rattengardist": {"itm_brutzel_burger": 0.20, "itm_smelling_salts": 0.10},
		"enm_fahrscheinfresser": {"itm_acc_lucky_ticket": 0.50},
	}
	for id: String in drops:
		var got: Dictionary = {}
		for dr: Dictionary in d.enemy(id).drops:
			got[str(dr["item"])] = float(dr["chance"])
		assert_eq(got, drops[id], id)
	assert_eq(d.enemy("enm_boss_hausmeister").boss_drops, [{"kind": "item", "id": "itm_key_master", "amount": 1},
		{"kind": "item", "id": "itm_acc_key_ring", "amount": 1}, {"kind": "box", "id": "box_silver", "amount": 1}])
	assert_eq(d.enemy("enm_boss_rattenkoenigin").boss_drops, [
		{"kind": "item", "id": "itm_acc_queen_crown", "amount": 1}, {"kind": "box", "id": "box_gold", "amount": 1}])


func test_enemy_ai_patterns_match_gdd() -> void:
	var d: GameData = _data()
	# id → [[skill, weight, target, cond], …] (GDD §5.1 "KI-Muster").
	var patterns: Dictionary = {
		"enm_kanalratte": [["skl_e_bite", 3, "random", {}], ["skl_e_gnaw_poison", 1, "not_status:sts_poison", {}]],
		"enm_taubenschwarm": [["skl_e_peck", 3, "lowest_hp_pct", {}], ["skl_e_dive_bomb", 1, "all_enemies", {}]],
		"enm_pendler": [["skl_e_briefcase", 3, "random", {}],
			["skl_e_delay_rage", 10, "random", {"turn_mod": [3, 2]}]],
		"enm_kanalschleim": [["skl_e_slam", 2, "random", {}], ["skl_e_toxic_splash", 2, "not_status:sts_poison", {}]],
		"enm_rattenschamane": [["skl_e_bite", 1, "random", {}], ["skl_e_zap", 2, "random", {}],
			["skl_e_rat_heal", 6, "ally_lowest_hp_pct", {"ally_hp_below": 0.5}]],
		"enm_kabelsalat": [["skl_e_lash", 2, "random", {}],
			["skl_e_short_circuit", 10, "all_enemies", {"turn_mod": [3, 1]}]],
		"enm_kellerspinne": [["skl_e_venom_bite", 3, "not_status:sts_poison", {}], ["skl_e_bite", 1, "random", {}],
			["skl_e_web", 2, "not_status:sts_slow", {"once": true}]],
		"enm_spruehgeist": [["skl_e_spray_flame", 3, "random", {}], ["skl_e_fumes", 1, "all_enemies", {}],
			["skl_e_slam", 1, "random", {}]],
		"enm_rolltreppenkrabbe": [["skl_e_brace", 10, "self", {"turn_mod": [3, 0]}],
			["skl_e_step_crush", 10, "highest_hp", {"turn_mod": [3, 1]}], ["skl_e_pinch", 3, "random", {}]],
		"enm_rattengardist": [["skl_e_shield_wall", 10, "all_allies", {"once": true}],
			["skl_e_lunge", 2, "lowest_hp_pct", {}], ["skl_e_halberd", 3, "random", {}]],
		"enm_fahrscheinfresser": [["skl_e_fine", 10, "random", {"once": true}], ["skl_e_ticket_cut", 3, "random", {}],
			["skl_e_escape", 100, "self", {"turn_mod": [4, 3]}]],
	}
	for id: String in patterns:
		var e: EnemyDef = d.enemy(id)
		assert_eq(e.ai["type"], "weighted", id)
		var got: Array = []
		for a: Dictionary in e.ai["actions"]:
			got.append([a["skill"], a["weight"], a["target"], a["cond"]])
		assert_eq(got, patterns[id], id)


func test_boss_phases_match_gdd() -> void:
	var d: GameData = _data()
	var hm: EnemyDef = d.enemy("enm_boss_hausmeister")
	assert_eq([hm.phases[0]["hp_above"], hm.phases[1]["hp_above"], hm.phases[2]["hp_above"]], [0.60, 0.25, 0.0])
	assert_eq(hm.phases[0]["on_enter"], [{"op": "say", "tag": "boss_intro:enm_boss_hausmeister"}])
	assert_eq(hm.phases[1]["on_enter"], [{"op": "summon", "enemy": "enm_kanalratte", "count": 1},
		{"op": "say", "tag": "boss_phase:enm_boss_hausmeister:2"}])
	assert_eq(hm.phases[2]["on_enter"], [{"op": "status_self", "status": "sts_haste", "turns": 5},
		{"op": "say", "tag": "boss_phase:enm_boss_hausmeister:3"}])
	assert_eq(_skills_of(hm.phases[0]["actions"]), ["skl_b_rules", "skl_b_broom", "skl_b_keys"])
	assert_eq(_skills_of(hm.phases[1]["actions"]), ["skl_b_broom", "skl_b_cleaner_fog", "skl_b_keys",
		"skl_b_call_tenant"])
	assert_eq(hm.phases[1]["actions"][3]["cond"], {"allies_alive_below": 2, "turn_mod": [4, 0]})
	assert_eq(_skills_of(hm.phases[2]["actions"]), ["skl_b_mop_whirl", "skl_b_broom"])
	var q: EnemyDef = d.enemy("enm_boss_rattenkoenigin")
	assert_eq([q.phases[0]["hp_above"], q.phases[1]["hp_above"], q.phases[2]["hp_above"]], [0.65, 0.30, 0.0])
	assert_eq(q.phases[0]["on_enter"][0], {"op": "summon", "enemy": "enm_kanalratte", "count": 2})
	assert_eq(q.phases[1]["on_enter"][0], {"op": "add_pseudo", "unit": "pu_train_gleis9", "ctr": 120})
	assert_eq(q.phases[2]["on_enter"], [{"op": "remove_pseudo", "unit": "pu_train_gleis9"},
		{"op": "fixed_damage_self", "amount": 72, "min_hp": 1}, {"op": "status_self", "status": "sts_haste", "turns": 99},
		{"op": "say", "tag": "boss_phase:enm_boss_rattenkoenigin:3"}])
	assert_eq(_skills_of(q.phases[2]["actions"]), ["skl_q_scepter", "skl_q_plague_bite", "skl_q_crown_nova"])
	assert_eq(q.phases[2]["actions"][2]["cond"], {"turn_mod": [4, 1]})
	assert_eq(q.model["pose"], "quadruped")
	assert_eq(q.status_immune, ["sts_poison"])
	assert_eq(d.skill("skl_q_summon").summon, ["enm_kanalratte", "enm_kanalratte"])
	assert_eq(d.skill("skl_b_call_tenant").summon, ["enm_kanalratte"])
	var train: PseudoUnitDef = d.pseudo_unit("pu_train_gleis9")
	assert_eq(train.action, {"fixed_pct_maxhp": 35, "element": "physical", "ignores_guard": true, "target": "all_party"})
	assert_eq([train.ctr_after, train.warn_tag, train.warn_at], [160, "boss_train_warning", 2])


func test_every_ai_action_is_usable() -> void:
	# Dead data guard: an action whose MP cost exceeds the unit's max MP would never be chosen.
	var d: GameData = _data()
	for e: EnemyDef in d.all_enemies():
		var lists: Array = [e.ai["actions"]]
		for p: Dictionary in e.phases:
			lists.append(p["actions"])
		for actions: Array in lists:
			for a: Dictionary in actions:
				var s: SkillDef = d.skill(str(a["skill"]))
				assert_true(s.mp_cost <= int(e.stats["mp"]), "%s: %s costs %d MP > %d" % [e.id, s.id, s.mp_cost,
					int(e.stats["mp"])])
				assert_ne(s.user, "item", "%s uses an item skill" % e.id)
				if s.category == "summon":
					assert_eq(a["target"], "self", e.id + ": summons target self")


func test_enemy_models_follow_art_casting() -> void:
	var d: GameData = _data()
	# 03_ART §5.5: id → [base, scale, props]
	var cast: Dictionary = {
		"enm_kanalratte": ["rodent", 0.8, []], "enm_taubenschwarm": ["swarm", 1.0, []],
		"enm_pendler": ["humanoid", 1.09, ["newspaper_head", "briefcase"]], "enm_kanalschleim": ["blob", 1.0, []],
		"enm_rattenschamane": ["rodent", 1.3, ["staff", "cape", "bottlecap_chain"]],
		"enm_kabelsalat": ["blob", 0.6, ["cable_tangle"]], "enm_kellerspinne": ["insect", 1.0, []],
		"enm_spruehgeist": ["specter", 0.65, ["spray_cap"]],
		"enm_rolltreppenkrabbe": ["insect", 1.5, ["escalator_back", "claws"]],
		"enm_rattengardist": ["rodent", 2.0, ["helmet", "shield", "halberd"]], "enm_fahrscheinfresser": ["robot", 1.2, []],
		"enm_boss_hausmeister": ["brute", 1.36, ["cap", "key_ring", "broom"]],
		"enm_boss_rattenkoenigin": ["rodent", 4.0, ["ticket_crown", "cape", "staff", "rat_king_tail"]],
	}
	for id: String in cast:
		var m: Dictionary = d.enemy(id).model
		var c: Array = cast[id]
		assert_eq([m["base"], m["scale"], m["props"]], c, id)
		assert_true((m["colors"] as Dictionary).has("primary"), id)


# --- encounters ----------------------------------------------------------------------------------------------------

func test_encounter_groups_match_gdd() -> void:
	var d: GameData = _data()
	var f1: FloorDef = d.floor_def(1)
	assert_len(f1.encounters, 19)
	var regular_exp: int = 0
	for enc_id: String in ENCOUNTER_REWARDS:
		var enc: EncounterDef = f1.encounter(enc_id)
		assert_not_null(enc, enc_id)
		if enc == null:
			continue
		var exp_sum: int = 0
		var cr_sum: int = 0
		for e: String in enc.enemies:
			exp_sum += d.enemy(e).exp
			cr_sum += d.enemy(e).credits
		assert_eq([exp_sum, cr_sum], ENCOUNTER_REWARDS[enc_id], enc_id + " EXP/credits")
		assert_eq(enc.weight, 0, enc_id + ": placed, never rolled")
		if not enc.boss and not enc_id.contains("_evt_"):
			regular_exp += exp_sum
	assert_eq(regular_exp, 994, "GDD §5.4: 15 regular groups incl. tutorial and rarity")
	var tut: EncounterDef = f1.encounter("enc_f1_a1_tutorial")
	assert_true(tut.tutorial)
	assert_false(tut.can_flee)
	for id: String in ["enc_f1_boss_hausmeister", "enc_f1_boss_rattenkoenigin"]:
		assert_true(f1.encounter(id).boss, id)
		assert_false(f1.encounter(id).can_flee, id)
	assert_true(f1.encounter("enc_f1_evt_pigeons").can_flee, "event battles allow fleeing")
	assert_eq(f1.encounter("enc_f1_a2").enemies, ["enm_kanalratte", "enm_taubenschwarm", "enm_kanalratte"])
	assert_eq(f1.encounter("enc_f1_d2").enemies, ["enm_rattengardist", "enm_rattengardist", "enm_rattenschamane"])
	assert_eq(f1.quarter_boss, "enc_f1_boss_hausmeister")
	assert_eq(f1.floor_boss, "enc_f1_boss_rattenkoenigin")
	assert_eq(f1.timer_start_after, "enc_f1_a1_tutorial")
	assert_eq([f1.timer_seconds, f1.floor_mult, f1.theme], [1200, 1.0, "metro"])
	assert_true(f1.playable)


# --- items ---------------------------------------------------------------------------------------------------------

func test_consumables_match_gdd() -> void:
	var d: GameData = _data()
	for id: String in CONSUMABLES:
		var it: ItemDef = d.item(id)
		var r: Array = CONSUMABLES[id]
		assert_eq([it.price, it.sell_value(), it.rarity, it.usable], r, id)
		assert_eq(it.type, "consumable", id)
		assert_eq(it.max_stack, 9, id)
		assert_eq(it.use_skill, "skl_item_" + id.trim_prefix("itm_"), id + " use_skill naming")
		var s: SkillDef = d.skill(it.use_skill)
		assert_eq([s.user, s.category, s.rank], ["item", "item", 2], it.use_skill)
	assert_eq([d.skill("skl_item_bandage").heal_mode, d.skill("skl_item_bandage").power], ["fixed", 45])
	assert_eq([d.skill("skl_item_brutzel_burger").heal_mode, d.skill("skl_item_brutzel_burger").power], ["fixed", 120])
	assert_eq(d.skill("skl_item_antidote").cleanse, ["sts_poison"])
	assert_eq(d.skill("skl_item_energy_krawumm").mp_restore, 20)
	var salts: SkillDef = d.skill("skl_item_smelling_salts")
	assert_eq([salts.target, salts.heal_mode, salts.power], ["single_ally_ko", "pct", 30])
	var molotov: SkillDef = d.skill("skl_item_molotov")
	assert_eq([molotov.damage_type, molotov.power, molotov.element, molotov.target], ["fixed", 60, "fire",
		"all_enemies"])
	var spray: SkillDef = d.skill("skl_item_ice_spray")
	assert_eq([spray.damage_type, spray.power, spray.element, spray.target], ["fixed", 90, "ice", "single_enemy"])
	assert_true(d.skill("skl_item_smoke").flee_guaranteed)
	assert_eq(d.skill("skl_item_hype_megaphone").hype, 25)
	var elixir: SkillDef = d.skill("skl_item_elixir")
	assert_eq([elixir.heal_mode, elixir.power, elixir.mp_restore_pct], ["pct", 100, 100])
	assert_true(d.item("itm_bandage").tags.has("heal"), "fev_lost_candidate needs heal items")
	var key: ItemDef = d.item("itm_key_master")
	assert_eq([key.type, key.sell, key.price, key.max_stack], ["key", 0, 0, 1])


func test_equipment_matches_gdd() -> void:
	var d: GameData = _data()
	var counts: Dictionary = {"weapon": 0, "armor": 0, "accessory": 0}
	for it: ItemDef in d.all_items():
		if it.is_equipment():
			counts[it.type] = int(counts[it.type]) + 1
	assert_eq(counts, {"weapon": 8, "armor": 6, "accessory": 8})
	for id: String in EQUIPMENT:
		var it: ItemDef = d.item(id)
		var r: Array = EQUIPMENT[id]
		assert_eq([it.type, it.price, it.sell_value(), it.rarity, it.stats, it.equip_by], r, id)
		assert_eq(it.attack_element, "physical", id)
	for id: String in ["itm_wpn_fire_axe", "itm_wpn_rail_crowbar", "itm_acc_key_ring"]:
		assert_almost(d.item(id).crit_bonus, 0.05, 0.0001, id)
	assert_eq(d.item("itm_arm_sewer_suit").element_mods, {"poison": 0.5})
	assert_eq(d.item("itm_acc_rubber_boots").element_mods, {"shock": 0.5})
	assert_eq(d.item("itm_acc_gas_mask").element_mods, {"poison": 0.0})
	assert_eq(d.item("itm_acc_gas_mask").status_immune, ["sts_poison"])
	assert_almost(float(d.item("itm_acc_fan_scarf").show_mods["hype_gain_mult"]), 1.2)
	assert_almost(float(d.item("itm_acc_clip_mic").show_mods["follower_mult"]), 1.15)
	# Loot-only equipment has the fixed sell values of 02_TECH §4.4.3 (rare 150 / epic 250).
	for it: ItemDef in d.all_items():
		if it.is_equipment() and it.price == 0 and it.sell != 0:
			assert_eq(it.sell, 150 if it.rarity == "rare" else 250, it.id + " loot-only sell value")


func test_shops_match_gdd() -> void:
	var d: GameData = _data()
	var srs: Array = d.floor_def(1).layout["safe_rooms"]
	var shops: Dictionary = {}
	for sr: Dictionary in srs:
		shops[str(sr["id"])] = Array(sr["shop"] as PackedStringArray)
	var sr1: Array = shops["sr_kiosk"]
	assert_len(sr1, 14, "9 consumables + 5 pieces of equipment")
	for id: String in CONSUMABLES:
		if id == "itm_elixir":
			assert_false(sr1.has(id), "elixir is loot only")
		else:
			assert_true(sr1.has(id), "SR1 sells " + id)
	for id: String in ["itm_wpn_pipe_wrench", "itm_wpn_collar_studded", "itm_arm_safety_vest", "itm_arm_velvet_cape",
			"itm_acc_lucky_ticket"]:
		assert_true(sr1.has(id), "SR1 sells " + id)
	var sr2: Array = shops["sr_pumphouse"]
	assert_eq(shops["sr_signalbox"], sr2, "SR3 = SR2")
	for id: Variant in sr1:
		assert_true(sr2.has(id), "SR2 ⊇ SR1: " + str(id))
	for id: String in ["itm_wpn_fire_axe", "itm_wpn_collar_signet", "itm_arm_sewer_suit", "itm_acc_rubber_boots",
			"itm_acc_sneakers", "itm_acc_gas_mask"]:
		assert_true(sr2.has(id), "SR2 sells " + id)
	assert_len(sr2, 20)
	for list: Variant in shops.values():
		for id: Variant in (list as Array):
			assert_gt(d.item(str(id)).price, 0, str(id) + " has a price")


func test_every_consumable_is_obtainable() -> void:
	# Each consumable must come from a shop, a drop, a chest, a pool, an event or a sponsor.
	var d: GameData = _data()
	var sources: Dictionary = {}
	var f1: FloorDef = d.floor_def(1)
	for sr: Dictionary in f1.layout["safe_rooms"]:
		for id: String in sr["shop"]:
			sources[id] = true
	for e: EnemyDef in d.all_enemies():
		for dr: Dictionary in e.drops:
			sources[str(dr["item"])] = true
		for bd: Dictionary in e.boss_drops:
			sources[str(bd["id"])] = true
	for c: Dictionary in f1.layout["chests"]:
		for it: Dictionary in c["contents"]:
			sources[str(it["id"])] = true
	for rarity: String in ["common", "rare", "epic", "fan"]:
		for entry: Dictionary in d.loot_pool(1, rarity):
			sources[str(entry["id"])] = true
	for ev: Dictionary in f1.layout["events"]:
		var p: Dictionary = ev["params"]
		if p.has("reward_item"):
			sources[str(p["reward_item"])] = true
	for sp: SponsorDef in d.all_sponsors():
		for g: Dictionary in sp.gift:
			sources[str(g["item"])] = true
	for ms: MilestoneDef in d.all_milestones():
		sources[ms.item] = true
	for it: ItemDef in d.all_items():
		if it.id == "itm_wpn_collar_royal":
			assert_true(_in_pool(d, 2, it.id), "Hofjuwelier-Halsband enters the epic pool on floor 2")
			assert_false(_in_pool(d, 1, it.id), "…and is not available on floor 1")
			continue
		if it.id == "itm_wpn_mop" or it.id == "itm_wpn_collar_leather" or it.id == "itm_arm_hoodie" \
				or it.id == "itm_arm_pug_sweater":
			continue   # start equipment
		assert_true(sources.has(it.id), it.id + " is obtainable on floor 1")


# --- show tables ---------------------------------------------------------------------------------------------------

func test_lootboxes_match_gdd() -> void:
	var d: GameData = _data()
	var rows: Dictionary = {
		"box_bronze": [1, 2, {"common": 80, "rare": 18, "epic": 2}, "", ""],
		"box_silver": [2, 3, {"common": 55, "rare": 38, "epic": 7}, "rare", ""],
		"box_gold": [3, 4, {"common": 25, "rare": 55, "epic": 20}, "epic", ""],
		"box_fan": [4, 2, {"common": 50, "rare": 40, "epic": 10}, "", "fan"],
	}
	for id: String in rows:
		var b: LootboxDef = d.lootbox(id)
		assert_eq([b.tier, b.rolls, b.rarity_weights, b.guarantee, b.fixed_pool], rows[id], id)
		assert_eq(b.effective_mod_tag(), "lootbox_open_" + id.trim_prefix("box_"))
	assert_eq(d.pity_limits(), {"rare": 4, "epic": 8})
	var common: Dictionary = _pool_map(d.loot_pool(1, "common"))
	assert_eq(common, {"credits:25": 30, "itm_bandage:2": 25, "itm_antidote:2": 15, "itm_energy_krawumm:1": 15,
		"itm_ice_spray:1": 10, "itm_molotov:1": 10})
	var rare: Dictionary = _pool_map(d.loot_pool(1, "rare"))
	assert_eq(rare, {"itm_brutzel_burger:2": 20, "itm_smelling_salts:1": 20, "credits:120": 15,
		"itm_hype_megaphone:1": 10, "itm_smoke:1": 10, "itm_acc_lucky_ticket:1": 8, "itm_acc_rubber_boots:1": 8,
		"itm_arm_safety_vest:1": 5, "itm_wpn_collar_studded:1": 5})
	var epic: Dictionary = _pool_map(d.loot_pool(1, "epic"))
	assert_eq(epic, {"itm_elixir:1": 25, "itm_wpn_fire_axe:1": 15, "itm_wpn_collar_signet:1": 15,
		"itm_acc_sneakers:1": 15, "itm_arm_ermine:1": 10, "itm_wpn_rail_crowbar:1": 10, "credits:400": 10})
	var fan: Dictionary = _pool_map(d.loot_pool(1, "fan"))
	assert_eq(fan, {"itm_acc_clip_mic:1": 40, "itm_elixir:1": 30, "itm_hype_megaphone:2": 30})
	# Lootboxes never contain key items (GDD §9: item/credits only, key items are not sellable/convertible).
	for f: int in [1, 2]:
		for r: String in ["common", "rare", "epic", "fan"]:
			for e: Dictionary in d.loot_pool(f, r):
				if str(e["kind"]) == "item":
					assert_ne(d.item(str(e["id"])).type, "key", "pool f%d.%s" % [f, r])


func test_achievements_match_gdd() -> void:
	var d: GameData = _data()
	var tiers: Dictionary = {"box_bronze": 0, "box_silver": 0, "box_gold": 0}
	var hidden: PackedStringArray = []
	var names: Dictionary = {}
	for a: AchievementDef in d.all_achievements():
		tiers[a.box] = int(tiers.get(a.box, 0)) + 1
		if a.hidden:
			hidden.append(a.id)
		assert_false(names.has(a.name), "unique name " + a.name)
		names[a.name] = true
		assert_eq(a.followers, -1, a.id + " followers by tier")
		assert_gt(d.mod_lines("achievement:" + a.id).size(), 0, a.id + " has its M.O.D. line")
		assert_not_null(a.expr, a.id)
	assert_eq(tiers, {"box_bronze": 18, "box_silver": 8, "box_gold": 3})
	hidden.sort()
	assert_eq(hidden, ["ach_last_minute", "ach_mimic", "ach_mopsula_ko", "ach_one_hp", "ach_stunt_fail_3"])
	# Sample evaluations (ConditionExpr semantics, §4.4.9).
	assert_true(d.achievement("ach_first_blood").expr.eval({}, {"kills_total": 1}, {}))
	assert_false(d.achievement("ach_first_blood").expr.eval({}, {"kills_total": 2}, {}))
	assert_true(d.achievement("ach_close_call").expr.eval({"min_party_hp_pct": 0.1}, {}, {}))
	assert_true(d.achievement("ach_mimic").expr.eval({"enemy_id": "enm_fahrscheinfresser"}, {}, {}))
	assert_false(d.achievement("ach_mimic").expr.eval({"enemy_id": "enm_kanalratte"}, {}, {}))
	assert_true(d.achievement("ach_preemptive_3").expr.eval({"encounter_type": "preemptive"}, {"preemptives": 3}, {}))
	assert_true(d.achievement("ach_hausmeister_no_items").expr.eval({"boss_id": "enm_boss_hausmeister",
		"items_used": 0}, {}, {}))
	assert_false(d.achievement("ach_hausmeister_no_items").expr.eval({"boss_id": "enm_boss_hausmeister",
		"items_used": 1}, {}, {}))
	assert_true(d.achievement("ach_speedrun").expr.eval({"floor": 1, "timer_left": 480}, {}, {}))
	assert_false(d.achievement("ach_speedrun").expr.eval({"floor": 1, "timer_left": 479}, {}, {}))
	assert_true(d.achievement("ach_last_minute").expr.eval({"floor": 1, "timer_left": 59}, {}, {}))
	assert_true(d.achievement("ach_level_5").expr.eval({"member": "kai", "level": 5}, {}, {}))
	assert_false(d.achievement("ach_level_5").expr.eval({"member": "mopsula", "level": 5}, {}, {}))
	assert_true(d.achievement("ach_events_all").expr.eval({}, {"events_completed": 5}, {}))
	assert_true(d.achievement("ach_combo_first").expr.eval({}, {}, {}))
	# ach_events_all counts the floor's events: there must be exactly 5 on floor 1.
	assert_len(d.floor_def(1).layout["events"], 5)


func test_sponsors_match_gdd() -> void:
	var d: GameData = _data()
	var rows: Dictionary = {
		"spn_gluckwasser": [3, [{"cond": "ally_hp_below", "value": 0.5, "mult": 3.0}]],
		"spn_krawumm": [2, []],
		"spn_panzerkeks": [2, [{"cond": "ally_hp_below", "value": 0.35, "mult": 2.0}]],
		"spn_sorgenfrei": [1, [{"cond": "ally_ko", "value": 0.0, "mult": 6.0}]],
		"spn_novanet": [2, [{"cond": "ally_mp_below", "value": 0.3, "mult": 2.0}]],
		"spn_brutzel": [2, []],
		"spn_doomscroll": [2, [{"cond": "is_boss", "value": 0.0, "mult": 2.0}]],
	}
	for id: String in rows:
		var s: SponsorDef = d.sponsor(id)
		assert_eq([s.weight, s.weight_mods], rows[id], id)
		assert_ne(s.slogan, "", id)
		assert_eq(s.mod_tag, "sponsor_gift")
	assert_eq(d.sponsor("spn_gluckwasser").gift[0]["kind"], "heal_party_pct")
	assert_eq(d.sponsor("spn_gluckwasser").gift[0]["value"], 35)
	assert_eq([d.sponsor("spn_krawumm").gift[0]["status"], d.sponsor("spn_krawumm").gift[0]["turns"]], ["sts_haste", 3])
	assert_eq(d.sponsor("spn_panzerkeks").gift[0]["status"], "sts_guard")
	assert_eq([d.sponsor("spn_sorgenfrei").gift[0]["kind"], d.sponsor("spn_sorgenfrei").gift[0]["value"]],
		["revive_or_heal_lowest", 50])
	assert_eq(d.sponsor("spn_novanet").gift[0]["value"], 40)
	assert_len(d.sponsor("spn_brutzel").gift, 2)
	assert_eq(d.sponsor("spn_brutzel").gift[0]["item"], "itm_brutzel_burger")
	var doom: Dictionary = d.sponsor("spn_doomscroll").gift[0]
	assert_eq([doom["kind"], doom["status"], doom["turns"], doom["target"], doom["ignore_resist"]],
		["status_enemies", "sts_slow", 3, "enemies", true])


func test_milestones_match_gdd() -> void:
	var d: GameData = _data()
	var got: Array = []
	for m: MilestoneDef in d.all_milestones():
		got.append([m.id, m.followers, m.reward_box, m.credits, m.item, m.title, m.min_floor])
	assert_eq(got, [
		["ms_100", 100, "box_bronze", 0, "", "", 1],
		["ms_250", 250, "box_fan", 0, "", "", 1],
		["ms_500", 500, "box_silver", 300, "", "", 1],
		["ms_1000", 1000, "box_fan", 0, "itm_acc_fan_scarf", "", 1],
		["ms_2000", 2000, "box_gold", 0, "", "", 1],
		["ms_5000", 5000, "box_gold", 0, "", "Quotenkönig:in", 2],
	])


func test_classes_prepared_for_floor_3() -> void:
	var d: GameData = _data()
	var per_member: Dictionary = {"kai": 0, "mopsula": 0}
	for c: ClassDef in d.all_classes():
		assert_eq(c.min_floor, 3, c.id)
		assert_len(c.for_members, 1, c.id)
		per_member[c.for_members[0]] = int(per_member[c.for_members[0]]) + 1
		assert_len(c.passives, 1, c.id)
		assert_true(str(c.passives[0]["id"]).begins_with("pas_"), c.id)
		assert_ne(c.desc, "", c.id)
		for k: Variant in c.stat_mult:
			assert_between(float(c.stat_mult[k]), 0.5, 2.0, c.id)
	assert_eq(per_member, {"kai": 4, "mopsula": 4})
	assert_eq(d.class_def("cls_kai_wrecker").stat_mult, {"hp": 1.10, "str": 1.15, "def": 1.10, "spd": 0.95})
	var showrunner: ClassDef = d.class_def("cls_kai_showrunner")
	assert_almost(float(showrunner.show_mods["stunt_success_add"]), 0.15)
	assert_eq(int(showrunner.show_mods["stunt_cooldown"]), 2)
	assert_eq(d.class_def("cls_mop_diva").show_mods["sponsor_thresholds"], [45, 70, 95])


func test_floor_2_stub() -> void:
	var d: GameData = _data()
	var f2: FloorDef = d.floor_def(2)
	assert_not_null(f2)
	if f2 == null:
		return
	assert_false(f2.playable, "slice ends after floor 1")
	assert_false(f2.has_layout(), "floor 2 is procedural")
	assert_eq([f2.theme, f2.timer_seconds, f2.floor_mult, f2.safe_rooms], ["mall", 1500, 1.5, 2])
	assert_eq(f2.grid, {"w": 9, "h": 9})
	assert_eq(f2.timer_warnings, [600, 300, 60])
	assert_gt(f2.chest_table.size(), 0)
	assert_gt(f2.shop.size(), 0)
	for enc: EncounterDef in f2.encounters:
		assert_gt(enc.weight, 0, enc.id + " rollable")
		for e: String in enc.enemies:
			assert_true(d.enemy(e).tags.has("floor_2"), enc.id + " uses floor-2 enemies")
		var carts: int = enc.enemies.count("enm_einkaufswagen_rudel")
		assert_true(carts == 0 or carts == 3, "%s: the Einkaufswagen-Rudel always comes in threes (GDD §15), got %d" % [
			enc.id, carts])
	for id: String in ["enm_schaufensterpuppe", "enm_einkaufswagen_rudel", "enm_rabattschild"]:
		assert_true(d.has_id("enemies", id), id)
	assert_eq(d.enemy("enm_schaufensterpuppe").stats["hp"], 90)
	assert_eq(d.enemy("enm_einkaufswagen_rudel").stats["spd"], 20)
	assert_eq(d.enemy("enm_rabattschild").stats["def"], 26)


# --- helpers -------------------------------------------------------------------------------------------------------

func _skills_of(actions: Array) -> Array:
	var out: Array = []
	for a: Dictionary in actions:
		out.append(str(a["skill"]))
	return out


func _pool_map(entries: Array[Dictionary]) -> Dictionary:
	var out: Dictionary = {}
	for e: Dictionary in entries:
		var key: String = ("credits:%d" if str(e["kind"]) == "credits" else str(e["id"]) + ":%d") % int(e["amount"])
		out[key] = int(e["weight"])
	return out


func _in_pool(d: GameData, floor_index: int, item_id: String) -> bool:
	for r: String in ["common", "rare", "epic", "fan"]:
		for e: Dictionary in d.loot_pool(floor_index, r):
			if str(e["id"]) == item_id:
				return true
	return false
