extends TestCase
## M2 progression (02_TECH §6.1, GDD §4/§3.12/§10.2): EXP table (30/63/112/173/246/330/424/529/643, cap 10), stat
## table, level-up (no full heal, learnset, cap), equip/unequip, full heal, field item use, to_combatant,
## GameState / FloorRun (ticks, warnings, loot_seed) and BattleBridge (setup, MP regen 15 %, KO → 1 HP, pep talk,
## timer start after the tutorial, rewards, bestiary).

const Fx := preload("res://tests/test_m2_fixtures.gd")
const HP: int = StatBlock.Stat.HP
const MP: int = StatBlock.Stat.MP


func _state() -> GameState:
	var st: GameState = GameState.create_new(Fx.data(), 1, "Kai", 4242)
	st.floor_run = FloorRun.create(Fx.data().floor_def(1), st.seed, st.difficulty)
	return st


func _stats_of(member: PartyMember) -> PackedInt32Array:
	return Progression.total_stats(member, Fx.data()).values


# --- EXP / stats ------------------------------------------------------------------------------------------------------

func test_exp_table_matches_formula_and_gdd() -> void:
	var gdd: Array = [33, 73, 131, 205, 292, 393, 506, 632, 769]
	for lv in range(1, 10):
		assert_eq(Progression.exp_to_next(lv), gdd[lv - 1], "GDD §4.3 level %d" % lv)
		assert_eq(Progression.exp_to_next(lv), floori(Balance.EXP_A * pow(lv, Balance.EXP_B) + Balance.EXP_C),
			"table == floori(18 × L^1.7 + 15)")
	assert_eq(Progression.exp_to_next(Balance.LEVEL_CAP), 0, "cap")
	assert_eq(Progression.exp_to_next(12), 0)
	var total: int = 0
	for lv in range(1, 10):
		total += Progression.exp_to_next(lv)
	assert_eq(total, 3034, "EXP total at level 10")


func test_base_stats_match_gdd_table() -> void:
	var d: GameData = Fx.data()
	var rows: Dictionary = {
		1: [[64, 12, 12, 5, 9, 6, 11, 8], [42, 30, 5, 13, 6, 11, 14, 12]],
		3: [[82, 16, 16, 6, 12, 7, 12, 9], [54, 38, 6, 17, 7, 14, 15, 13]],
		5: [[100, 20, 20, 7, 15, 9, 13, 10], [66, 46, 7, 21, 9, 17, 16, 14]],
		7: [[118, 24, 24, 8, 18, 10, 14, 11], [78, 54, 8, 26, 10, 20, 17, 16]],
		8: [[127, 26, 26, 9, 19, 11, 14, 11], [84, 58, 9, 28, 11, 22, 18, 16]],
		10: [[145, 30, 30, 10, 22, 13, 15, 12], [96, 66, 10, 32, 13, 25, 19, 18]],
	}
	for lv: int in rows:
		assert_eq(Progression.base_stats_at(d.party_member("kai"), lv).values, rows[lv][0], "Kai L%d" % lv)
		assert_eq(Progression.base_stats_at(d.party_member("mopsula"), lv).values, rows[lv][1], "Mopsula L%d" % lv)


func test_total_stats_equipment_and_class() -> void:
	var d: GameData = Fx.data()
	var st: GameState = _state()
	var kai: PartyMember = st.member("kai")
	assert_eq(_stats_of(kai), [74, 12, 15, 5, 11, 6, 11, 8], "mop STR +3, hoodie HP +10 / DEF +2")
	kai.level = 3
	kai.class_id = "cls_kai_test"
	assert_eq(Progression.base_stats_at(d.party_member("kai"), 3, d.class_def("cls_kai_test")).values[HP], 88,
		"growth_add hp +3 per level")
	var t: PackedInt32Array = _stats_of(kai)
	assert_eq([t[HP], t[StatBlock.Stat.STR]], [108, 22], "(88 + 10) × 1.1, (16 + 3) × 1.15 rounded")
	kai.class_id = "cls_unknown"
	assert_eq(_stats_of(kai)[HP], 82 + 10, "unknown class ignored")
	assert_eq(Progression.total_stats(null, d).values, [0, 0, 0, 0, 0, 0, 0, 0])


func test_add_exp_levels_learning_and_cap() -> void:
	var d: GameData = Fx.data()
	var st: GameState = _state()
	var kai: PartyMember = st.member("kai")
	kai.hp = 10
	var ups: Array[LevelUpInfo] = Progression.add_exp(kai, 33, d)
	assert_len(ups, 1)
	assert_eq([kai.level, kai.exp], [2, 0])
	assert_eq([ups[0].member_id, ups[0].old_level, ups[0].new_level], ["kai", 1, 2])
	assert_eq(ups[0].stat_gains, {"hp": 9, "mp": 2, "str": 2, "mag": 0, "def": 1, "res": 0, "spd": 0, "lck": 0})
	assert_eq(kai.hp, 19, "hp raised by the max delta, no full heal")
	assert_eq(kai.mp, 14)
	assert_eq(Progression.add_exp(kai, 72, d), [], "1 EXP short of level 3")
	assert_eq([kai.level, kai.exp], [2, 72])
	var up3: Array[LevelUpInfo] = Progression.add_exp(kai, 1, d)
	assert_eq(up3[0].learned, ["skl_kai_finisher"], "learnset level 3")
	assert_has(kai.skills, "skl_kai_finisher")
	var mop: PartyMember = st.member("mopsula")
	var multi: Array[LevelUpInfo] = Progression.add_exp(mop, 106 + 5, d)
	assert_len(multi, 1, "one info spanning several levels")
	assert_eq([multi[0].old_level, multi[0].new_level, mop.exp], [1, 3, 5])
	assert_eq(multi[0].learned, ["skl_mop_frost", "skl_mop_thunder"])
	var capped: Array[LevelUpInfo] = Progression.add_exp(mop, 100000, d)
	assert_eq([mop.level, mop.exp], [10, 0], "surplus EXP at the cap is discarded")
	assert_eq(capped[0].new_level, 10)
	assert_eq(Progression.add_exp(mop, 50, d), [])
	assert_eq(mop.exp, 0)
	var ko: PartyMember = st.member("kai")
	ko.hp = 0
	Progression.add_exp(ko, 131, d)
	assert_eq(ko.hp, 0, "a KO'd member stays KO")
	kai.class_id = "cls_kai_test"
	var fresh: GameState = _state()
	fresh.member("kai").class_id = "cls_kai_test"
	fresh.member("kai").skills = PackedStringArray()
	assert_eq(Progression.add_exp(fresh.member("kai"), 33, d)[0].learned, ["skl_kai_finisher"], "class learnset")


# --- equipment, healing, items ----------------------------------------------------------------------------------------

func test_equip_and_unequip() -> void:
	var d: GameData = Fx.data()
	var st: GameState = _state()
	var kai: PartyMember = st.member("kai")
	var mop: PartyMember = st.member("mopsula")
	var inv: Inventory = st.inventory
	assert_false(Progression.equip(kai, inv, d, "weapon", "itm_wpn_axe"), "not owned")
	inv.add("itm_wpn_axe")
	assert_false(Progression.equip(mop, inv, d, "weapon", "itm_wpn_axe"), "equip_by kai only")
	assert_false(Progression.equip(kai, inv, d, "armor", "itm_wpn_axe"), "wrong slot")
	assert_false(Progression.equip(kai, inv, d, "hat", "itm_wpn_axe"), "unknown slot")
	assert_true(Progression.equip(kai, inv, d, "weapon", "itm_wpn_axe"))
	assert_eq(kai.equipment["weapon"], "itm_wpn_axe")
	assert_eq([inv.count("itm_wpn_axe"), inv.count("itm_wpn_mop")], [0, 1], "old weapon back into the inventory")
	assert_eq(_stats_of(kai)[StatBlock.Stat.STR], 24)
	assert_false(Progression.equip(kai, inv, d, "weapon", "itm_wpn_axe"), "already equipped")
	assert_false(Progression.equip(kai, inv, d, "accessory", ""), "nothing to unequip")
	assert_eq(kai.hp, 74)
	assert_true(Progression.equip(kai, inv, d, "armor", ""), "unequip")
	assert_eq(inv.count("itm_arm_hoodie"), 1)
	assert_eq(kai.hp, 64, "hp clamped to the new maximum")
	inv.add("itm_arm_vest")
	assert_true(Progression.equip(kai, inv, d, "armor", "itm_arm_vest"))
	assert_eq([kai.hp, _stats_of(kai)[HP]], [64, 84], "a higher maximum does not heal")
	inv.add("itm_wpn_axe", 9)
	assert_eq(inv.count("itm_wpn_axe"), 9)
	assert_false(Progression.equip(kai, inv, d, "weapon", ""), "inventory stack full → stays equipped")
	assert_eq(kai.equipment["weapon"], "itm_wpn_axe")
	inv.add("itm_wpn_mop", 8)
	assert_false(Progression.equip(kai, inv, d, "weapon", "itm_wpn_mop"), "swap back fails: no room for the axe")
	assert_eq([kai.equipment["weapon"], inv.count("itm_wpn_mop")], ["itm_wpn_axe", 9], "nothing changed")


func test_full_heal() -> void:
	var st: GameState = _state()
	for m: PartyMember in st.party:
		m.hp = 0
		m.mp = 0
	Progression.full_heal(st, Fx.data())
	assert_eq([st.member("kai").hp, st.member("kai").mp, st.member("mopsula").hp, st.member("mopsula").mp],
		[74, 12, 42, 30])


func test_use_item_in_the_field() -> void:
	var d: GameData = Fx.data()
	var st: GameState = _state()
	var kai: PartyMember = st.member("kai")
	var mop: PartyMember = st.member("mopsula")
	assert_false(Progression.use_item(st, d, "itm_bandage", "kai"), "full HP: nothing changes")
	assert_eq(st.inventory.count("itm_bandage"), 3, "not consumed")
	kai.hp = 20
	assert_true(Progression.use_item(st, d, "itm_bandage", "kai"))
	assert_eq([kai.hp, st.inventory.count("itm_bandage")], [65, 2], "fixed 45 HP")
	kai.hp = 70
	assert_true(Progression.use_item(st, d, "itm_bandage", "kai"))
	assert_eq(kai.hp, 74, "capped")
	mop.hp = 0
	assert_false(Progression.use_item(st, d, "itm_bandage", "mopsula"), "no healing for KO members")
	st.inventory.add("itm_salts", 2)
	assert_true(Progression.use_item(st, d, "itm_salts", "mopsula"))
	assert_eq(mop.hp, 13, "revive with 30 % of 42 (rounded)")
	assert_false(Progression.use_item(st, d, "itm_salts", "mopsula"), "revive only on KO members")
	st.inventory.add("itm_ether")
	mop.mp = 0
	assert_true(Progression.use_item(st, d, "itm_ether", "mopsula"))
	assert_eq(mop.mp, 13, "flat 10 + 10 % of 30")
	assert_false(Progression.use_item(st, d, "itm_antidote", "kai"), "no statuses outside battle")
	st.inventory.add("itm_molotov")
	st.inventory.add("itm_megaphone")
	assert_false(Progression.use_item(st, d, "itm_molotov", "kai"), "battle-only item")
	assert_false(Progression.use_item(st, d, "itm_megaphone", "kai"), "battle-only item")
	st.inventory.add("itm_group_heal")
	kai.hp = 20
	mop.hp = 10
	assert_true(Progression.use_item(st, d, "itm_group_heal", "kai"))
	assert_eq([kai.hp, mop.hp, st.inventory.count("itm_group_heal")], [35, 18, 0], "all allies +20 %")
	assert_false(Progression.use_item(st, d, "itm_unknown", "kai"))
	assert_false(Progression.use_item(st, d, "itm_bandage", "nobody"))
	assert_false(Progression.use_item(st, d, "itm_group_heal", "kai"), "none left")


func test_to_combatant() -> void:
	var d: GameData = Fx.data()
	var st: GameState = _state()
	var kai: PartyMember = st.member("kai")
	var c: Combatant = Progression.to_combatant(kai, d, "p0", 0)
	assert_not_null(c)
	assert_eq([c.id, c.def_id, c.slot, c.level, c.hp, c.mp], ["p0", "kai", 0, 1, 74, 12])
	assert_eq(c.stats.values, [74, 12, 15, 5, 11, 6, 11, 8])
	assert_eq([c.attack_skill, c.attack_element, c.crit_bonus], ["skl_attack_kai", "physical", 0.0])
	assert_eq(c.skills, ["skl_kai_heavy_swing"])
	assert_eq(c.stunts, ["skl_stunt_kai_suplex"])
	st.inventory.add("itm_wpn_axe")
	st.inventory.add("itm_acc_mask")
	Progression.equip(kai, st.inventory, d, "weapon", "itm_wpn_axe")
	Progression.equip(kai, st.inventory, d, "accessory", "itm_acc_mask")
	kai.hp = 30
	var c2: Combatant = Progression.to_combatant(kai, d, "p0", 0)
	assert_almost(c2.crit_bonus, 0.10, 0.0001, "Σ equipment crit_bonus")
	assert_eq(c2.attack_element, "fire", "weapon attack element")
	assert_eq(c2.element_mods, {"poison": 0.0})
	assert_eq(c2.status_immune, ["sts_poison"])
	assert_eq(c2.hp, 30)
	var mop: PartyMember = st.member("mopsula")
	st.inventory.add("itm_arm_vest")
	Progression.equip(mop, st.inventory, d, "armor", "itm_arm_vest")
	var c3: Combatant = Progression.to_combatant(mop, d, "p1", 1)
	assert_eq(c3.element_mods, {"ice": 0.5, "poison": 0.5}, "def mods × equipment mods")
	assert_eq(c3.status_resist, {"sts_poison": 0.25}, "status_resist from the def")
	assert_eq(c3.stunts, [])
	assert_null(Progression.to_combatant(null, d, "p9", 0))


# --- GameState / FloorRun ---------------------------------------------------------------------------------------------

func test_game_state_create_new_and_show_mods() -> void:
	var d: GameData = Fx.data()
	var st: GameState = GameState.create_new(d, 2, "Alex", 99, &"vorabend")
	assert_eq([st.slot, st.seed, st.player_name, String(st.difficulty)], [2, 99, "Alex", "vorabend"])
	assert_eq(st.party.size(), 2)
	assert_eq(st.party[0].id, "kai", "battle_slot order")
	assert_eq(st.member("kai").display_name, "Alex", "Kai carries the player name")
	assert_eq(st.member("mopsula").display_name, "Mopsula")
	assert_eq([st.member("kai").level, st.member("kai").hp, st.member("kai").mp], [1, 74, 12], "full incl. equipment")
	assert_eq(st.member("kai").equipment, {"weapon": "itm_wpn_mop", "armor": "itm_arm_hoodie", "accessory": ""})
	assert_eq(st.member("mopsula").skills, ["skl_mop_flame", "skl_mop_lick"], "learnset level ≤ 1")
	assert_eq(st.inventory.counts, {"itm_antidote": 1, "itm_bandage": 3})
	assert_eq(st.inventory.credits, 50)
	assert_eq([st.show.hype, st.show.followers], [30.0, 0])
	assert_null(st.floor_run)
	assert_eq(st.hype_gain_mult(d), 1.0)
	st.inventory.add("itm_acc_scarf")
	st.inventory.add("itm_acc_mic")
	Progression.equip(st.member("kai"), st.inventory, d, "accessory", "itm_acc_scarf")
	Progression.equip(st.member("mopsula"), st.inventory, d, "accessory", "itm_acc_mic")
	assert_almost(st.hype_gain_mult(d), 1.2)
	assert_almost(st.follower_mult(d), 1.15)


func test_game_state_dict_round_trip() -> void:
	var st: GameState = _state()
	st.play_time_sec = 812.5
	st.rng_counter = 41
	st.pity_rare = 2
	st.pity_epic = 5
	st.pending_lootboxes = PackedStringArray(["box_bronze"])
	st.bestiary = {"enm_rat": {"defeated": 4, "weak_known": PackedStringArray(["fire"])}}
	st.flags = {"intro_seen": true, "count": 3, "live": {"gift_ids": ["g_1"]}}
	st.show.stats = {"kills_total": 6}
	st.show.achievements = PackedStringArray(["ach_first_blood"])
	st.floor_run.visited.append(Vector2i(3, 7))
	st.floor_run.strays["f1_s0"] = {"zone": "zone_platform", "enc": "enc_f1_a"}
	st.floor_run.location = &"sr_kiosk"
	var d1: Dictionary = st.to_dict()
	var back: GameState = GameState.from_dict(JSON.parse_string(JSON.stringify(d1)))
	assert_eq(back.to_dict(), d1, "to_dict → JSON → from_dict → to_dict is identical")
	assert_eq(typeof(back.flags["count"]), TYPE_INT, "integral floats become int again")
	assert_eq(back.floor_run.location, &"sr_kiosk")
	assert_eq(back.floor_run.visited, [Vector2i(3, 7)])
	var legacy: Dictionary = d1.duplicate(true)
	(legacy["floor_run"] as Dictionary).erase("loot_seed")
	var derived: GameState = GameState.from_dict(legacy)
	assert_eq(derived.floor_run.loot_seed, SeedUtil.derive(st.seed, "loot", 1), "missing loot_seed is derived")


func test_floor_run_create_and_seeds() -> void:
	var d: GameData = Fx.data()
	var fr: FloorRun = FloorRun.create(d.floor_def(1), 4242, &"prime")
	assert_eq([fr.floor_id, fr.index, fr.time_left_ticks, fr.timer_started], ["floor_1", 1, 36000, false])
	assert_eq(fr.seed, 1557687279, "SeedUtil golden value derive(4242, \"floor\", 1)")
	assert_eq(fr.loot_seed, SeedUtil.derive(4242, "loot", 1), "05 CR-11")
	assert_ne(fr.loot_seed, fr.seed)
	assert_eq(FloorRun.create(d.floor_def(1), 4242, &"vorabend").time_left_ticks, 54000, "× 1.5")
	assert_true(FloorRun.create(d.floor_def(2), 4242, &"prime").timer_started, "no timer_start_after → running")
	assert_almost(fr.time_left_sec(), 1200.0)
	assert_null(FloorRun.create(null, 1, &"prime"))


func test_floor_run_tick_timer_warnings_and_summary() -> void:
	var fr: FloorRun = FloorRun.create(Fx.data().floor_def(1), 1, &"prime")
	var warn: PackedInt32Array = [600, 300, 60]
	fr.time_left_ticks = 600 * 30 + 15
	var a: Dictionary = fr.tick_timer(15, warn)
	assert_eq(a, {"second_changed": false, "warnings": PackedInt32Array([600]), "expired": false})
	var b: Dictionary = fr.tick_timer(1, warn)
	assert_eq(b["second_changed"], true, "600 s → 599 s")
	assert_eq(b["warnings"], PackedInt32Array())
	var c: Dictionary = fr.tick_timer(1_000_000, warn)
	assert_eq(c["warnings"], PackedInt32Array([300, 60]), "several warnings in one step, once each")
	assert_eq(c["expired"], true)
	assert_eq(fr.time_left_ticks, 0)
	assert_eq(fr.stats["time_used_ticks"], 15 + 1 + 17999)
	assert_eq(fr.warned, PackedInt32Array([600, 300, 60]))
	assert_eq(fr.tick_timer(30, warn), {"second_changed": false, "warnings": PackedInt32Array(), "expired": false},
		"stopped at 0")
	fr.stats["kills"] = 6
	assert_eq(fr.summary(), {"floor": 1, "time_used_sec": 600, "time_left_sec": 0, "kills": 6, "viewers_peak": 0,
		"followers_gained": 0, "achievements": 0})


# --- BattleBridge -----------------------------------------------------------------------------------------------------

func test_bridge_make_setup() -> void:
	var d: GameData = Fx.data()
	var st: GameState = _state()
	var s: BattleSetup = BattleBridge.make_setup(st, d, "enc_f1_a", BattleSetup.Advantage.PREEMPTIVE, "f1_g1", 1234)
	assert_not_null(s)
	assert_eq([s.encounter_id, s.group_id, s.seed, s.advantage], ["enc_f1_a", "f1_g1", 1234, 1])
	assert_eq(s.enemy_ids, ["enm_rat"])
	assert_eq([s.party.size(), s.party[0].id, s.party[0].def_id, s.party[1].id, s.party[1].slot],
		[2, "p0", "kai", "p1", 1])
	assert_eq(s.items, {"itm_antidote": 1, "itm_bandage": 3}, "battle-usable consumables")
	assert_eq([s.credits_available, s.is_boss, s.can_flee, s.tutorial], [50, false, true, false])
	assert_eq([s.enemy_dmg_mult, s.exp_mult], [1.0, 1.0])
	assert_eq(s.show_mods, {"hype_gain_mult": 1.0, "follower_mult": 1.0})
	assert_eq([s.theme_id, s.floor_index], ["metro", 1])
	assert_false(s.palette.is_empty())
	var boss: BattleSetup = BattleBridge.make_setup(st, d, "enc_f1_qb", BattleSetup.Advantage.AMBUSH, "f1_qb", 1)
	assert_eq([boss.advantage, boss.is_boss, boss.can_flee], [BattleSetup.Advantage.NORMAL, true, false],
		"bosses force NORMAL")
	var tut: BattleSetup = BattleBridge.make_setup(st, d, "enc_f1_tutorial", 0, "f1_g0", 1)
	assert_eq([tut.tutorial, tut.enemy_dmg_mult], [true, 0.5])
	st.difficulty = &"vorabend"
	var easy: BattleSetup = BattleBridge.make_setup(st, d, "enc_f1_tutorial", 0, "f1_g0", 1)
	assert_almost(easy.enemy_dmg_mult, 0.375)
	assert_almost(easy.exp_mult, 1.2)
	assert_null(BattleBridge.make_setup(st, d, "enc_nope", 0, "", 1))


func test_bridge_pep_talk() -> void:
	var d: GameData = Fx.data()
	var st: GameState = _state()
	st.flags["mop_pep_talk"] = true
	var normal: BattleSetup = BattleBridge.make_setup(st, d, "enc_f1_a", 0, "f1_g1", 1)
	assert_eq(normal.party[0].statuses.size(), 0, "only boss battles")
	assert_true(st.flags.has("mop_pep_talk"))
	var boss: BattleSetup = BattleBridge.make_setup(st, d, "enc_f1_qb", 0, "f1_qb", 1)
	for c: Combatant in boss.party:
		assert_eq(c.statuses.size(), 1)
		assert_eq([c.statuses[0].def.id, c.statuses[0].turns_left], ["sts_guard", 2], "guard 2 on " + c.id)
	assert_false(st.flags.has("mop_pep_talk"), "flag erased")


func test_bridge_apply_victory() -> void:
	var d: GameData = Fx.data()
	var st: GameState = _state()
	var r: BattleResult = BattleResult.new()
	r.outcome = BattleResult.Outcome.VICTORY
	r.encounter_id = "enc_f1_tutorial"
	r.group_id = "f1_g0"
	r.party_hp = {"kai": 30, "mopsula": 0}
	r.party_mp = {"kai": 5, "mopsula": 10}
	r.exp = 40
	r.credits = 25
	r.overkill_credits = 5
	r.credits_stolen = 10
	r.credits_delta = 7
	r.drops = PackedStringArray(["itm_bandage"])
	r.boss_rewards = [{"kind": "item", "id": "itm_key_master", "amount": 1}, {"kind": "box", "id": "box_silver",
		"amount": 1}]
	r.item_delta = {"itm_bandage": -1, "itm_salts": 2}
	r.kills = 2
	r.defeated_ids = PackedStringArray(["enm_rat", "enm_rat"])
	r.weak_found = {"enm_rat": PackedStringArray(["fire"])}
	var rw: BattleRewards = BattleBridge.apply_result(st, d, r)
	var kai: PartyMember = st.member("kai")
	var mop: PartyMember = st.member("mopsula")
	assert_eq(rw.revived, ["mopsula"], "KO → 1 HP after a victory")
	assert_eq(mop.hp, 1)
	assert_eq([kai.level, kai.exp, mop.level, mop.exp], [2, 7, 1, 20], "alive full EXP, KO'd floori(50 %)")
	assert_eq(kai.hp, 39, "30 + level-up delta 9")
	assert_eq(rw.mp_regen, {"kai": 3}, "Werbepause: ceili(14 × 0.15) for the living only")
	assert_eq([kai.mp, mop.mp], [10, 10], "5 + 2 (level) + 3 (regen); KO'd member gets no regen")
	assert_eq([rw.exp, rw.credits, rw.overkill_credits, rw.credits_refunded, rw.credits_lost], [40, 25, 5, 10, 0])
	assert_eq(st.inventory.credits, 50 + 7 + 25, "gift credits + battle credits; stolen credits refunded")
	assert_eq([st.inventory.count("itm_bandage"), st.inventory.count("itm_salts"), st.inventory.count("itm_key_master")],
		[3, 2, 1])
	assert_eq(rw.items, ["itm_bandage", "itm_key_master"])
	assert_eq(rw.boxes, ["box_silver"])
	assert_eq(st.pending_lootboxes, PackedStringArray(["box_silver"]))
	assert_eq(rw.level_ups.size(), 1)
	assert_eq(st.floor_run.defeated_groups, PackedStringArray(["f1_g0"]))
	assert_true(st.floor_run.timer_started, "victory over timer_start_after starts the countdown")
	assert_eq(st.floor_run.stats["kills"], 2)
	assert_eq(st.bestiary["enm_rat"]["defeated"], 2)
	assert_eq(st.bestiary["enm_rat"]["weak_known"], PackedStringArray(["fire"]))


func test_bridge_apply_boss_flee_and_defeat() -> void:
	var d: GameData = Fx.data()
	var st: GameState = _state()
	st.floor_run.strays["f1_s0"] = {"zone": "zone_platform", "enc": "enc_f1_a"}
	var stray: BattleResult = BattleResult.new()
	stray.outcome = BattleResult.Outcome.VICTORY
	stray.encounter_id = "enc_f1_a"
	stray.group_id = "f1_s0"
	BattleBridge.apply_result(st, d, stray)
	assert_false(st.floor_run.strays.has("f1_s0"), "defeated stray removed")
	assert_false(st.floor_run.timer_started, "only the tutorial encounter starts the timer")
	var boss: BattleResult = BattleResult.new()
	boss.outcome = BattleResult.Outcome.VICTORY
	boss.encounter_id = "enc_f1_qb"
	boss.group_id = "f1_qb"
	boss.is_boss = true
	boss.boss_id = "enm_boss"
	BattleBridge.apply_result(st, d, boss)
	assert_true(st.floor_run.quarter_boss_defeated)
	assert_false(st.floor_run.floor_boss_defeated)
	assert_eq(st.flags.get("defeated_enm_boss", false), true)
	var fled: BattleResult = BattleResult.new()
	fled.outcome = BattleResult.Outcome.FLED
	fled.party_hp = {"kai": 0, "mopsula": 20}
	fled.credits_stolen = 10
	fled.exp = 99
	fled.weak_found = {"enm_boss": ["shock"]}
	var rw: BattleRewards = BattleBridge.apply_result(st, d, fled)
	assert_eq([rw.credits_lost, st.inventory.credits], [10, 40], "stolen credits are lost when fleeing")
	assert_eq(rw.exp, 0, "no EXP")
	assert_eq(st.member("kai").hp, 1, "KO → 1 HP (not a defeat)")
	assert_eq(st.bestiary["enm_boss"]["weak_known"], PackedStringArray(["shock"]), "weakness knowledge kept")
	var lost: BattleResult = BattleResult.new()
	lost.outcome = BattleResult.Outcome.DEFEAT
	lost.party_hp = {"kai": 0, "mopsula": 0}
	var rd: BattleRewards = BattleBridge.apply_result(st, d, lost)
	assert_eq([st.member("kai").hp, st.member("mopsula").hp], [0, 0], "defeat: no revive")
	assert_eq(rd.revived, [])
	assert_not_null(BattleBridge.apply_result(null, d, lost))
