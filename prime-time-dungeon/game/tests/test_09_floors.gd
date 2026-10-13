extends TestCase
## 09 ST1-C1: the floors of the basis season — the Kulissen (themes.json: art theme, programme pool), floors 2–6 in
## floors.json (Kulisse, place, level band, quarters, key, bosses; one new rule per floor, 09 §0.6), the enemy levels
## of 07 CR-32 d (RtBalance.ENEMY_LEVEL_PM, EnemyLevels: a season only — without one nothing changes), the campaign
## guard (floors 2–6 are season floors: the campaign still ends after floor 1), a basis season played from floor 1 to
## its end after floor 6, and — as CR-32 d asks — the MP and HP formulas of 07 §4.2/§4.3 up to level 50.

const Kit := preload("res://tests/fixtures/season_core/season_core.gd")
const Harness := preload("res://tests/tools/rt_harness.gd")
const FloorSeasonCheck := preload("res://core/data/validators/floor_season.gd")
const SEASON_FLOORS: Array[int] = [2, 3, 4, 5, 6]
const KULISSEN: Dictionary = {2: ["thm_passage", "mall", 1], 3: ["thm_fundus", "metro", 1],
	4: ["thm_paketzentrum", "metro", 1], 5: ["thm_paketzentrum", "metro", 2], 6: ["thm_paketzentrum", "metro", 3]}


func after_each() -> void:
	Game.state = null
	Game.mode = &"campaign"


# --- data -------------------------------------------------------------------------------------------------------------

func test_kulissen_and_floors() -> void:
	var d: GameData = real_data()
	var t1: ThemeDef = d.theme("thm_unterstadt")
	assert_eq([t1.floors, t1.art, t1.program.size()], [PackedInt32Array([1]), "metro", 0],
		"floor 1 keeps its programme placeholders (handbuilt, no doors)")
	var prev_band: PackedInt32Array = d.floor_def(1).level_band
	for f: int in SEASON_FLOORS:
		var def: FloorDef = d.floor_def(f)
		var want: Array = KULISSEN[f]
		assert_eq([def.kulisse(), ThemeDef.art_of(def, d), def.variant], want, "floor %d: Kulisse, art, place" % f)
		var t: ThemeDef = d.theme(def.kulisse())
		assert_true(t.floors.has(f), "floor %d listed by its Kulisse" % f)
		assert_between(t.program.size(), 5, 20, "floor %d: a programme pool of its own" % f)
		assert_true(def.playable and def.season_only(), "floor %d: a season floor" % f)
		assert_true(def.has_zones() and def.has_band(), "floor %d: quarters and band" % f)
		assert_true(def.level_band[0] >= prev_band[1] - 1, "floor %d: the bands climb" % f)
		prev_band = def.level_band
		assert_between(def.zones.size(), 2, 4, "floor %d: quarters" % f)
		assert_ne(def.quarter_boss, "", "floor %d: a Revier-Boss" % f)
		assert_true(d.has_id("items", ZoneGenerator.key_item(def)), "floor %d: its key" % f)
		var spots: int = 0
		for z: Dictionary in def.zones:
			spots += int(z["spots"])
			assert_true((FloorSeasonCheck.STYLES.get(ThemeDef.art_of(def, d), []) as Array).has(str(z["style"])),
				"floor %d %s: a dressing style of its art theme" % [f, str(z["id"])])
		assert_eq(spots, 5, "floor %d: five programme doors (09 §3.3: 5 points)" % f)
	assert_eq(d.floor_def(6).floor_boss != "", true, "the finale floor has its Etagenboss")
	assert_null(d.floor_def(7), "floors 7–18: ST1-C2")


## 09 §0.6: one new rule per floor at most — each floor brings its own enemy kinds, the Paketzentrum floors add one
## each (floor 5 the Rollcontainer-Rudel, floor 6 the Paketberg as Etagenboss).
func test_one_new_thing_per_floor() -> void:
	var d: GameData = real_data()
	var seen: Dictionary = {}
	for e: EnemyDef in d.all_enemies():
		if e.tags.has("floor_1"):
			seen[e.id] = true
	var new_per_floor: Dictionary = {}
	for f: int in SEASON_FLOORS:
		var fresh: PackedStringArray = []
		for enc: EncounterDef in d.floor_def(f).encounters:
			for eid: String in enc.enemies:
				if not seen.has(eid) and not fresh.has(eid) and not d.enemy(eid).boss:
					fresh.append(eid)
		for eid: String in fresh:
			seen[eid] = true
		new_per_floor[f] = fresh.size()
	assert_eq(new_per_floor[5], 1, "floor 5: one new kind (Rollcontainer-Rudel)")
	assert_eq(new_per_floor[6], 0, "floor 6: no new regular kind (the Paketberg is its new rule)")
	assert_gt(new_per_floor[4], 0, "floor 4: a new Kulisse brings its cast")


# --- 07 CR-32 d: the enemy level table -------------------------------------------------------------------------------

func test_enemy_level_table() -> void:
	var bal: RtBalance = RtBalance.from_data(real_data())
	assert_eq(bal.enemy_level_pm(1), 1000, "level 1 = 1000")
	for lv in range(2, RtBalance.ENEMY_LEVEL_MAX + 1):
		assert_eq(bal.enemy_level_pm(lv), 1000 + 150 * (lv - 1), "level %d: + 150 ‰ per level" % lv)
	assert_eq([bal.enemy_level_pm(0), bal.enemy_level_pm(99)], [1000, bal.enemy_level_pm(52)], "clamped to 1..52")
	assert_eq(RtBalance.ENEMY_LEVEL_MAX, 52, "band end 50 + elite 2")
	var broken: Dictionary = RtBalance.DEFAULTS.duplicate(true)
	(broken[RtBalance.ENEMY_LEVEL_KEY] as Dictionary)["1"] = 1100
	assert_has("; ".join(RtBalance.validate(broken)), RtBalance.ENEMY_LEVEL_KEY, "level 1 must be 1000")
	broken = RtBalance.DEFAULTS.duplicate(true)
	(broken[RtBalance.ENEMY_LEVEL_KEY] as Dictionary)["20"] = 100
	assert_has("; ".join(RtBalance.validate(broken)), RtBalance.ENEMY_LEVEL_KEY, "rising from level to level")
	assert_eq(EnemyLevels.factor_pm(bal, EnemyLevels.NO_LEVEL, 8), 1000, "no level: factor 1000")
	assert_eq(EnemyLevels.factor_pm(bal, 8, 8), 1000)
	assert_eq(EnemyLevels.factor_pm(bal, 10, 8), (2350 * 1000 + 1025) / 2050)


## A combat on floor 2 of a season gets the group's level (unit level, HP, STR, MAG, DEF, RES, credits) and the EXP
## share of ST1-D for its group (09 §8.2, D-6); the same combat without a season keeps the data values bit for bit.
func test_enemy_levels_only_in_a_season() -> void:
	var d: GameData = real_data()
	var st: GameState = GameState.create_new(d, 0, "Kai", 404, &"prime")
	RunRules.start_floor(st, d, 2)
	var layout: FloorLayout = DungeonGenerator.generate(d.floor_def(2), st.floor_run.seed)
	var group: EnemySpawn = null
	for e: EnemySpawn in layout.enemies:
		var regular: bool = not e.is_boss and d.floor_def(2).encounter(e.encounter_id).show_boss.is_empty()
		if regular and e.level > ZoneGenerator.band_middle(d.floor_def(2)):
			group = e
			break
	assert_not_null(group, "a regular side group above the band's middle")
	if group == null:
		return
	var plain: RtSetup = BattleBridge.make_rt_setup(st, d, _command(group), 77)
	st.season = SeasonState.new()
	st.season.format = 6
	var lifted: RtSetup = BattleBridge.make_rt_setup(st, d, _command(group), 77)
	var bal: RtBalance = RtBalance.from_data(d)
	var want_level: int = mini(group.level, EnemyLevels.level_cap(d))
	var checked: int = 0
	var exp_sum: int = 0
	for i in plain.units.size():
		var a: RtUnit = plain.units[i]
		var b: RtUnit = lifted.units[i]
		if a.side != Combatant.Side.ENEMY:
			assert_eq(a.stats.values, b.stats.values, "the party is untouched")
			continue
		var def_level: int = d.enemy(a.def_id).level
		assert_eq(a.level, def_level, "no season: the data level")
		assert_eq(a.exp_reward, d.enemy(a.def_id).exp, "no season: the data EXP")
		assert_eq(b.level, want_level, "a season: the group's level")
		var pm: int = EnemyLevels.factor_pm(bal, want_level, def_level)
		var hp: int = (a.stats.values[StatBlock.Stat.HP] * pm + 500) / 1000
		assert_between(b.stats.values[StatBlock.Stat.HP], hp - 1, hp + 1, "HP × the level factor (± rounding of the mods)")
		assert_eq(b.stats.values[StatBlock.Stat.SPD], a.stats.values[StatBlock.Stat.SPD], "speed stays")
		var cr: int = (a.credit_reward * pm + 500) / 1000
		assert_between(b.credit_reward, cr - 1, cr + 1, "credits × the level factor")
		exp_sum += b.exp_reward
		checked += 1
	assert_gt(checked, 0)
	var share: int = EnemyLevels.exp_share_pm(d.floor_def(2), group.encounter_id)
	assert_eq(share, LevelBand.SHARE_GROUP_PM, "a regular group: 4 % of a level")
	assert_eq(exp_sum, LevelBand.exp_to_next(st, d, want_level) * share / 1000, "the group is worth its share exactly")
	assert_eq(EnemyLevels.enemy_level(GameState.create_new(d, 0, "Kai", 1, &"prime"), d, group.id), 0,
		"no season: no level")


## ST1-D × ST1-C (09 §8.2, D-6): the colour of a won fight's EXP reads the level its groups fought on
## (LevelBand.group_level → EnemyLevels.result_level), not the enemies' data levels; bosses and the show boss's group
## are worth their shares of a level.
func test_combat_exp_reads_the_band_level() -> void:
	var d: GameData = real_data()
	var st: GameState = GameState.create_new(d, 0, "Kai", 404, &"prime")
	RunRules.start_floor(st, d, 2)
	st.season = SeasonState.new()
	st.season.format = 6
	var def: FloorDef = d.floor_def(2)
	var layout: FloorLayout = DungeonGenerator.generate(def, st.floor_run.seed)
	var group: EnemySpawn = null
	for e: EnemySpawn in layout.enemies:
		if not e.is_boss and e.level == ZoneGenerator.band_middle(def):
			group = e
			break
	assert_not_null(group, "a group on the Pflichtweg")
	if group == null:
		return
	var res: BattleResult = BattleResult.new()
	res.group_id = group.id
	res.group_ids = PackedStringArray([group.id])
	res.defeated_ids = PackedStringArray(def.encounter(group.encounter_id).enemies)
	var data_level: int = 0
	for id: String in res.defeated_ids:
		data_level = maxi(data_level, d.enemy(id).level)
	assert_eq(LevelBand.group_level(d, res), data_level, "without the state: the enemies' data level")
	assert_eq(LevelBand.group_level(d, res, st), group.level, "a season floor: the group's band level")
	var kai: PartyMember = st.member("kai")
	kai.level = group.level
	kai.exp = 0
	kai.rested = 0
	var rw: BattleRewards = BattleRewards.new()
	LevelBand.combat_exp(st, d, res, 20, {}, rw)
	assert_eq(int(rw.exp_by_member["kai"]), 20, "at the group's level the EXP count in full (yellow)")
	var plain: GameState = GameState.create_new(d, 0, "Kai", 404, &"prime")
	RunRules.start_floor(plain, d, 2)
	assert_eq(EnemyLevels.result_level(plain, d, res), EnemyLevels.NO_LEVEL, "no season: no band level")
	assert_eq([EnemyLevels.exp_share_pm(def, def.quarter_boss), EnemyLevels.exp_share_pm(def, def.floor_boss),
		EnemyLevels.exp_share_pm(def, group.encounter_id)], [LevelBand.SHARE_QUARTER_BOSS_PM,
		LevelBand.SHARE_FLOOR_BOSS_PM, LevelBand.SHARE_GROUP_PM], "Revier-Boss 25 %, Etagenboss 50 %, a group 4 %")
	for enc: EncounterDef in def.encounters:
		if not enc.show_boss.is_empty():
			assert_eq(EnemyLevels.exp_share_pm(def, enc.id), LevelBand.SHARE_SHOW_BOSS_PM, "the show boss's group 15 %")
	assert_eq(EnemyLevels.group_exp(st, d, 8, 40), LevelBand.exp_to_next(st, d, 8) * 40 / 1000)
	assert_eq(EnemyLevels.group_exp(st, d, 52, 500), LevelBand.exp_to_next(st, d, 49) * 500 / 1000,
		"the elite levels above 49 count as 49")


static func _command(g: EnemySpawn) -> Dictionary:
	var poses: Array = Harness.POSES["regular"]
	var rt: Dictionary = {"v": 1, "cell": [g.cell.x, g.cell.y], "ctl": "p0",
		"party": [{"u": "p0", "p": poses[1]}, {"u": "p1", "p": poses[2]}],
		"groups": [{"group": g.id, "enc": g.encounter_id, "lead": poses[0], "state": "IDLE"}],
		"presets": {}, "auto": true, "retarget": true, "open": {}, "diff": "prime"}
	return {"t": "encounter", "enc": g.encounter_id, "adv": 0, "group": g.id, "rt": rt}


## 07 CR-32 d (test without a code change): the MP of §4.2 / §4.3 (Kai 12 + 2 per level, Mopsula 30 + 4) and the HP of
## party.json (GDD §4.1, baked × 4: Kai 256 + 36, Mopsula 168 + 24) up to level 50.
func test_mp_and_hp_formulas_to_level_fifty() -> void:
	var d: GameData = real_data()
	var kai: PartyMemberDef = d.party_member("kai")
	var mop: PartyMemberDef = d.party_member("mopsula")
	for lv in range(1, Balance.SEASON_LEVEL_CAP + 1):
		var k: StatBlock = Progression.base_stats_at(kai, lv)
		var m: StatBlock = Progression.base_stats_at(mop, lv)
		assert_eq([k.values[StatBlock.Stat.MP], m.values[StatBlock.Stat.MP]], [12 + 2 * (lv - 1), 30 + 4 * (lv - 1)],
			"MP at level %d" % lv)
		assert_eq([k.values[StatBlock.Stat.HP], m.values[StatBlock.Stat.HP]], [256 + 36 * (lv - 1), 168 + 24 * (lv - 1)],
			"HP at level %d" % lv)
	assert_eq(Progression.base_stats_at(kai, 50).values[StatBlock.Stat.MP], 110)
	assert_eq(Progression.base_stats_at(mop, 50).values[StatBlock.Stat.MP], 226)


# --- the campaign guard and a basis season ----------------------------------------------------------------------------

func test_floors_two_to_six_are_season_floors_only() -> void:
	var d: GameData = real_data()
	assert_true(d.floor_def(1).playable_in(false) and d.floor_def(1).playable_in(true))
	for f: int in SEASON_FLOORS:
		assert_false(d.floor_def(f).playable_in(false), "floor %d: never in the campaign (the slice ends at 1)" % f)
		assert_true(d.floor_def(f).playable_in(true), "floor %d: in a season" % f)
	var s: RunSim = Kit.sim(d)
	assert_eq(SeasonRules.last_floor(s.state, d), 6, "the basis season plays floors 1–6")


func test_a_basis_season_from_floor_one_to_its_end() -> void:
	var d: GameData = real_data()
	var s: RunSim = Kit.sim(d, "ssn_basis", "binge")
	for f in range(1, 6):
		s.apply({"t": "descend"})
		s.apply({"t": "floor", "floor": f + 1})
		var fr: FloorRun = s.state.floor_run
		assert_eq(fr.index, f + 1, "the stairs lead to floor %d" % (f + 1))
		assert_eq(fr.daily.size(), 1, "Am Stück: a programme point on entering floor %d" % (f + 1))
		var l: FloorLayout = DungeonGenerator.generate(d.floor_def(f + 1), fr.seed)
		assert_eq(ZoneGenerator.check(l, d.floor_def(f + 1)), PackedStringArray(), "floor %d's layout" % (f + 1))
		assert_true(fr.opened_gates.has(str(l.programme[0]["key"])), "programme door 1 is open")
		assert_false(fr.opened_gates.has(str(l.programme[1]["key"])), "door 2 waits for point 2")
	assert_eq(s.rejected_cmds, [] as Array[Dictionary])
	assert_eq(SeasonRules.stairs_refusal(s.state, d), "no_stairs", "floor 6 is the finale floor of the basis format")
	var ev: Array = SeasonRules.on_combat_end(s.state, d, Kit.result(BattleResult.Outcome.VICTORY,
		d.floor_def(6).floor_boss))
	assert_eq(Kit.kinds(ev), ["finale"], "the Paketberg beaten on floor 6: the finale")
	assert_eq(s.state.season.result, "finalist")


func test_the_last_collapse_ends_a_basis_season_on_floor_six() -> void:
	var d: GameData = real_data()
	var s: RunSim = Kit.sim(d)
	Kit.put_on_floor(s, 6)
	s.state.season.collapsed = 5
	var ev: Array = Kit.clock_to(s, s.state.season.collapse_utc[5])
	assert_eq(Kit.event(ev, "end"), {"kind": "end", "why": "last", "floor": 6}, "Letzter Einsturz = Staffelende")
	assert_true(SeasonRules.season_over(s.state))
