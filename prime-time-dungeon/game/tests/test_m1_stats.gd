extends TestCase
## M1: StatBlock, Elements, Combatant basics (02_TECH §5.2, §5.4). Fixture data only.

const Fx := preload("res://tests/test_m1_fixture.gd")

var data: GameData


func before_each() -> void:
	data = fixture_data(Fx.tables())


func test_stat_block_get_set_add_duplicate() -> void:
	var a: StatBlock = StatBlock.from_dict(
			{"hp": 64, "mp": 12, "str": 12, "mag": 5, "def": 9, "res": 6, "spd": 11, "lck": 8})
	assert_eq(a.get_stat(StatBlock.Stat.HP), 64)
	assert_eq(a.get_stat(StatBlock.Stat.SPD), 11)
	assert_eq(a.get_stat(StatBlock.Stat.LCK), 8)
	a.set_stat(StatBlock.Stat.STR, 20)
	assert_eq(a.get_stat(StatBlock.Stat.STR), 20)
	var b: StatBlock = StatBlock.from_dict({"str": 4, "def": 3, "res": 1})
	var c: StatBlock = a.add(b)
	assert_eq(c.get_stat(StatBlock.Stat.STR), 24, "add sums per stat")
	assert_eq(c.get_stat(StatBlock.Stat.DEF), 12)
	assert_eq(c.get_stat(StatBlock.Stat.HP), 64)
	assert_eq(a.get_stat(StatBlock.Stat.STR), 20, "add returns a new block")
	var d: StatBlock = a.duplicate_block()
	d.set_stat(StatBlock.Stat.HP, 1)
	assert_eq(a.get_stat(StatBlock.Stat.HP), 64, "duplicate is independent")
	assert_eq(a.add(null).to_dict(), a.to_dict(), "add(null) copies")


func test_stat_block_scaled_rounds_exact_decimals() -> void:
	var a: StatBlock = StatBlock.from_dict({"hp": 64, "str": 10, "def": 9, "spd": 11, "lck": 7})
	var s: StatBlock = a.scaled({"hp": 1.10, "str": 1.15, "def": 1.10, "spd": 0.95})
	assert_eq(s.get_stat(StatBlock.Stat.HP), 70, "64 × 1.1 = 70.4 → 70")
	assert_eq(s.get_stat(StatBlock.Stat.STR), 12, "10 × 1.15 = 11.5 → 12 (exact decimal, half away from zero)")
	assert_eq(s.get_stat(StatBlock.Stat.DEF), 10, "9 × 1.1 = 9.9 → 10")
	assert_eq(s.get_stat(StatBlock.Stat.SPD), 10, "11 × 0.95 = 10.45 → 10")
	assert_eq(s.get_stat(StatBlock.Stat.LCK), 7, "missing key → × 1.0")


func test_stat_block_dict_roundtrip_and_keys() -> void:
	var d: Dictionary = {"hp": 24.0, "mp": 0, "str": 13, "mag": 3, "def": 5, "res": 3, "spd": 13.0, "lck": 5}
	var a: StatBlock = StatBlock.from_dict(d)
	assert_eq(a.to_dict(), {"hp": 24, "mp": 0, "str": 13, "mag": 3, "def": 5, "res": 3, "spd": 13, "lck": 5})
	assert_eq(typeof(a.to_dict()["hp"]), TYPE_INT, "JSON floats become ints")
	var partial: StatBlock = StatBlock.from_dict({"spd": 7})
	assert_eq(partial.get_stat(StatBlock.Stat.HP), 0, "missing keys → 0")
	assert_eq(partial.to_dict().size(), 8)
	for i in StatBlock.KEYS.size():
		assert_eq(int(StatBlock.key_to_stat(StatBlock.KEYS[i])), i, "KEYS index == Stat value (%s)" % StatBlock.KEYS[i])
	assert_eq(StatBlock.KEYS, DataValidator.STATS)


func test_elements_multiplier_and_affinity() -> void:
	var mods: Dictionary = {"fire": 1.5, "physical": 0.5, "poison": 0.0}
	assert_almost(Elements.multiplier(mods, "fire"), 1.5)
	assert_almost(Elements.multiplier(mods, "physical"), 0.5)
	assert_almost(Elements.multiplier(mods, "poison"), 0.0)
	assert_almost(Elements.multiplier(mods, "ice"), 1.0, 0.0001, "missing → 1.0")
	assert_almost(Elements.multiplier({"none": 0.0}, "none"), 1.0, 0.0001, "none always 1.0")
	assert_eq(Elements.multiplier_pm(mods, "fire"), 1500)
	assert_eq(Elements.affinity(1.5), &"weak")
	assert_eq(Elements.affinity(2.0), &"weak")
	assert_eq(Elements.affinity(1.0), &"normal")
	assert_eq(Elements.affinity(1.2), &"normal")
	assert_eq(Elements.affinity(0.5), &"resist")
	assert_eq(Elements.affinity(0.0), &"immune")
	assert_eq(Elements.ALL, DataValidator.ELEMENTS)


func test_combatant_effective_stats_apply_status_mults() -> void:
	var kai: Combatant = Fx.member(data, "kai", "p0", 0)
	assert_eq(kai.stat(StatBlock.Stat.DEF), 9)
	kai.statuses.append(StatusEffect.new(data.status("sts_brittle"), 2, "e0"))
	assert_eq(kai.stat(StatBlock.Stat.DEF), 5, "9 × 0.5 = 4.5 → 5")
	assert_eq(kai.stat(StatBlock.Stat.SPD), 17, "11 × 1.5 = 16.5 → 17")
	assert_eq(kai.stat(StatBlock.Stat.HP), 64, "HP unmodified")
	kai.stats.set_stat(StatBlock.Stat.DEF, 1)
	assert_eq(kai.stat(StatBlock.Stat.DEF), 1, "min 1")
	kai.stats.set_stat(StatBlock.Stat.DEF, 0)
	assert_eq(kai.stat(StatBlock.Stat.DEF), 1, "min 1 also for 0")
	assert_true(kai.has_status("sts_brittle"))
	assert_false(kai.has_flag("guard"))
	kai.statuses.append(StatusEffect.new(data.status("sts_guard"), 3, "p0"))
	assert_true(kai.has_flag("guard"))


func test_combatant_speed_mult_and_ratios() -> void:
	var kai: Combatant = Fx.member(data, "kai", "p0", 0, {"hp": 16})
	assert_almost(kai.speed_mult(), 1.0)
	kai.statuses.append(StatusEffect.new(data.status("sts_haste"), 3, ""))
	assert_almost(kai.speed_mult(), 0.6)
	assert_eq(kai.speed_pm(), 600)
	kai.statuses.clear()
	kai.statuses.append(StatusEffect.new(data.status("sts_slow"), 3, ""))
	assert_almost(kai.speed_mult(), 1.5)
	assert_almost(kai.hp_ratio(), 0.25)
	assert_eq(kai.max_hp(), 64)
	assert_eq(kai.max_mp(), 12)
	kai.hp = 0
	assert_false(kai.is_alive())
	assert_true(kai.is_ko())


func test_create_enemy_and_pseudo() -> void:
	var rat: Combatant = Combatant.create_enemy(data.enemy("enm_rat"), "e0", 2)
	assert_eq(rat.id, "e0")
	assert_eq(rat.slot, 2)
	assert_false(rat.is_party())
	assert_eq(rat.hp, 24)
	assert_eq(rat.max_hp(), 24)
	assert_eq(rat.exp_reward, 12)
	assert_eq(rat.credit_reward, 6)
	assert_eq(rat.skills, PackedStringArray(["skl_e_bite", "skl_e_gnaw_poison", "skl_e_strike"]),
			"AI skills in data order + attack skill")
	assert_eq(rat.phase, 0)
	assert_len(rat.drops, 2)
	rat.drops[0]["chance"] = 1.0
	assert_almost(float(data.enemy("enm_rat").drops[0]["chance"]), 0.25, 0.0001, "copies are writable, defs untouched")
	var boss: Combatant = Combatant.create_enemy(data.enemy("enm_boss_janitor"), "e1", 0)
	assert_true(boss.is_boss)
	assert_eq(boss.phase, -1, "phased enemies start before phase 1")
	assert_len(boss.phases, 3)
	assert_has(boss.skills, "skl_b_call_tenant")
	var train: Combatant = Combatant.create_pseudo(data.pseudo_unit("pu_train"), "u0")
	assert_true(train.is_pseudo)
	assert_true(train.is_alive(), "pseudo units are alive while in the order")
	assert_eq(train.slot, -1)
	assert_eq(train.pseudo_def.ctr_after, 160)
	train.left_battle = true
	assert_false(train.is_alive())


func test_create_party_copies_inputs() -> void:
	var mods: Dictionary = {"poison": 0.5}
	var kai: Combatant = Fx.member(data, "kai", "p0", 0, {"element_mods": mods, "crit_bonus": 0.05})
	mods["poison"] = 0.0
	assert_almost(float(kai.element_mods["poison"]), 0.5, 0.0001, "element_mods copied")
	assert_true(kai.is_party())
	assert_eq(kai.def_id, "kai")
	assert_eq(kai.attack_skill, "skl_attack_kai")
	assert_eq(kai.stunts, PackedStringArray(["skl_stunt_kai_suplex"]))
	assert_almost(kai.crit_bonus, 0.05)


func test_combatant_snapshot_roundtrip_is_float_free() -> void:
	var kai: Combatant = Fx.member(data, "kai", "p0", 0, {"element_mods": {"poison": 0.5}, "crit_bonus": 0.05})
	kai.status_resist = {"sts_stun": 0.25}
	var st: StatusEffect = StatusEffect.new(data.status("sts_poison"), 3, "e0")
	st.fresh = true
	kai.statuses.append(st)
	kai.ctb_counter = 37
	kai.stunt_cooldown = 2
	var d: Dictionary = kai.to_dict()
	assert_true(_float_free(d), "Combatant.to_dict has no non-integral floats")
	var json: Variant = JSON.parse_string(JSON.stringify(d))
	var back: Combatant = Combatant.from_dict(json, data)
	assert_not_null(back)
	assert_eq(back.to_dict(), d, "to_dict → JSON → from_dict → to_dict is stable")
	assert_almost(float(back.element_mods["poison"]), 0.5)
	assert_almost(back.crit_bonus, 0.05)
	assert_eq(back.statuses[0].id(), "sts_poison")
	assert_true(back.statuses[0].fresh)
	assert_eq(back.model, data.party_member("kai").model, "model re-derived from the def")
	var rat: Combatant = Combatant.create_enemy(data.enemy("enm_rat"), "e3", 1)
	var rback: Combatant = Combatant.from_dict(JSON.parse_string(JSON.stringify(rat.to_dict())), data)
	assert_eq(rback.to_dict(), rat.to_dict())
	assert_len(rback.drops, 2, "static enemy data re-derived from EnemyDef")
	assert_eq(rback.ai, rat.ai)


## 05 CR-12 / §11.4 lint (also checked by test_m8_no_global_rng): no float RNG, libm or clock calls in the battle core.
func test_battle_core_uses_integer_rng_only() -> void:
	var re: RegEx = RegEx.create_from_string(
			"randf|randfn|\\bpow\\(|\\bexp\\(|\\bsin\\(|\\bcos\\(|atan2\\(|\\blerp\\(|Time\\.|OS\\.get_ticks|"
			+ "randomize\\(|(^|[^.\\w])randi\\(|(^|[^.\\w])randi_range\\(")
	var files: PackedStringArray = []
	for dir: String in ["res://core/stats", "res://core/battle"]:
		for f: String in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				files.append(dir + "/" + f)
	assert_gt(files.size(), 15)
	for path: String in files:
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			if re.search(lines[i]) != null and not lines[i].contains("# det-ok:"):
				fail("%s:%d uses a forbidden call: %s" % [path, i + 1, lines[i].strip_edges()])


static func _float_free(v: Variant) -> bool:
	match typeof(v):
		TYPE_FLOAT:
			return fmod(float(v), 1.0) == 0.0
		TYPE_DICTIONARY:
			for k: Variant in (v as Dictionary).keys():
				if typeof(k) != TYPE_STRING or not _float_free((v as Dictionary)[k]):
					return false
		TYPE_ARRAY:
			for e: Variant in (v as Array):
				if not _float_free(e):
					return false
		TYPE_INT, TYPE_STRING, TYPE_BOOL, TYPE_NIL:
			return true
		_:
			return false
	return true
