class_name EnemyLevels extends RefCounted
## Enemy levels of the seasons (09 §3.4; 07 CR-32 d; ST1-C): every enemy group of a season floor with a band has a level
## in it (the generator v2 sets it per group: the Pflichtweg at the band's middle, side ways up to band end + 1, the
## show boss's elite group band end + 2, Revier-Boss band end, Etagenboss band end + 1) and its enemies grow with the
## level table of data/rt_balance.json (RtBalance.enemy_level_pm, Ganzzahl-Promille): an enemy of data level d at
## level L has its HP, STR, MAG, DEF, RES and credits × table(L) / table(d). Its EXP follow the sources of ST1-D (09
## §8.2, D-6): a group is worth a share of the level it stands on (LevelBand.exp_to_next(L) × LevelBand.SHARE_*_PM — a
## regular group 4 %, the show boss's group 15 %, the Revier-Boss 25 %, the Etagenboss 50 %), split over its enemies by
## their data EXP. BattleBridge.make_rt_setup calls apply() — a season only: without one no level is set (factor 1000)
## and every run stays bit-identical; floor 1 (no quarters) keeps its data levels and EXP in a season too. The colour
## of the combat EXP (LevelBand.group_level) reads the level of the beaten groups here (result_level).
##
## Data without the EXP table of the levels above 10 (party.json exp_table; fixtures) let no figure pass
## Balance.LEVEL_CAP, so no enemy gets more than that either (level_cap); with ST1-D's table the bands apply in full.
## Pure (core): no autoloads; layer core/progression (like BattleBridge: core/dungeon for the layout, core/rt for the
## units and the table, core/season for the EXP table and shares of LevelBand).

const NO_LEVEL: int = 0


## The enemies' level cap: Balance.LEVEL_CAP without the EXP table of the levels above 10 (party.json exp_table),
## else the end of the level table (RtBalance.ENEMY_LEVEL_MAX, band end 50 + elite 2).
static func level_cap(data: GameData) -> int:
	if data != null and not data.exp_table().is_empty():
		return RtBalance.ENEMY_LEVEL_MAX
	return Balance.LEVEL_CAP


## The level of group `group_id` on the current floor of a season (NO_LEVEL = the encounter's data levels, factor
## 1000): its layout level; a combat the layout does not know (an event fight, a stray) the band's middle — capped by
## level_cap(). NO_LEVEL without a season or on a floor without band and quarters (floor 1 stays as it is). `layout`:
## the floor's layout when the caller has it (else it is generated).
static func enemy_level(state: GameState, data: GameData, group_id: String, layout: FloorLayout = null) -> int:
	var def: FloorDef = _season_floor(state, data)
	if def == null:
		return NO_LEVEL
	var level: int = ZoneGenerator.band_middle(def)
	if group_id != "":
		var l: FloorLayout = layout if layout != null else DungeonGenerator.generate(def, state.floor_run.seed)
		var spawn: EnemySpawn = l.enemy_by_id(group_id) if l != null else null
		if spawn != null and spawn.level > 0:
			level = spawn.level
	return mini(level, level_cap(data))


## The level of the groups a combat beat (09 §8.2, the colour of its EXP; LevelBand.group_level): the highest
## enemy_level over result.group_ids (else result.group_id — no group: the band's middle). NO_LEVEL without a season or
## on a floor without band and quarters.
static func result_level(state: GameState, data: GameData, result: BattleResult) -> int:
	var def: FloorDef = _season_floor(state, data)
	if def == null or result == null:
		return NO_LEVEL
	var ids: PackedStringArray = result.group_ids.duplicate()
	if ids.is_empty():
		ids.append(result.group_id)
	var layout: FloorLayout = DungeonGenerator.generate(def, state.floor_run.seed)
	var level: int = NO_LEVEL
	for gid: String in ids:
		level = maxi(level, enemy_level(state, data, gid, layout))
	return level


## The ‰ factor that lifts an enemy of data level `def_level` to `level` (07 CR-32 d): table(level) × 1000 /
## table(def_level), rounded half up; 1000 for NO_LEVEL.
static func factor_pm(bal: RtBalance, level: int, def_level: int) -> int:
	if bal == null or level <= NO_LEVEL:
		return 1000
	var base: int = maxi(1, bal.enemy_level_pm(maxi(1, def_level)))
	return (bal.enemy_level_pm(level) * 1000 + base / 2) / base


## The ‰ share of a level the group of encounter `enc_id` is worth on floor `def` (09 §8.2, D-6): the Etagenboss, the
## Revier-Boss, the show boss's group, else a regular group.
static func exp_share_pm(def: FloorDef, enc_id: String) -> int:
	if def != null and enc_id != "":
		if enc_id == def.floor_boss:
			return LevelBand.SHARE_FLOOR_BOSS_PM
		if enc_id == def.quarter_boss:
			return LevelBand.SHARE_QUARTER_BOSS_PM
		var enc: EncounterDef = def.encounter(enc_id)
		if enc != null and not enc.show_boss.is_empty():
			return LevelBand.SHARE_SHOW_BOSS_PM
	return LevelBand.SHARE_GROUP_PM


## The EXP a group on `level` is worth (09 §8.2, D-6): the EXP that level needs (LevelBand.exp_to_next; the elite levels
## above 49 count as 49, the table ends there) × `share_pm` / 1000.
static func group_exp(state: GameState, data: GameData, level: int, share_pm: int) -> int:
	var lv: int = clampi(level, 1, LevelBand.SEASON_CAP - 1)
	return LevelBand.exp_to_next(state, data, lv) * share_pm / 1000


## BattleBridge.make_rt_setup's hook (a season only, before the RtMods): every enemy unit of the setup gets the level of
## its group (enemy_level; the unit's level for the HUD's plaque), its HP, STR, MAG, DEF, RES and credits × factor_pm,
## and its share of the group's EXP (group_exp × exp_share_pm, split by the enemies' data EXP; the integer rest goes to
## the group's first unit, so the beaten group gives exactly its share). Nothing changes without a season or on a floor
## without band and quarters. Summons of a running combat keep their data values.
static func apply(s: RtSetup, state: GameState, data: GameData, bal: RtBalance) -> void:
	var def: FloorDef = _season_floor(state, data)
	if s == null or def == null:
		return
	var layout: FloorLayout = DungeonGenerator.generate(def, state.floor_run.seed)
	var units: Dictionary = {}                 # unit id → RtUnit (the enemies of a known type)
	for u: RtUnit in s.units:
		if u.side == Combatant.Side.ENEMY and data.has_id("enemies", u.def_id):
			units[u.id] = u
	for g: Dictionary in s.groups:
		var level: int = enemy_level(state, data, str(g.get("group_id", "")), layout)
		if level <= NO_LEVEL:
			continue
		var members: Array[RtUnit] = []
		for uid: Variant in (g.get("units", []) as Array):
			if units.has(str(uid)):
				members.append(units[str(uid)])
		for u: RtUnit in members:
			_lift(u, level, factor_pm(bal, level, data.enemy(u.def_id).level))
		_share_exp(members, data, group_exp(state, data, level, exp_share_pm(def, str(g.get("encounter_id", "")))))


## The floor of a season the levels apply to (with band and quarters), else null.
static func _season_floor(state: GameState, data: GameData) -> FloorDef:
	if state == null or state.season == null or state.floor_run == null or data == null:
		return null
	var def: FloorDef = data.floor_def(state.floor_run.index)
	return def if def != null and def.has_band() and def.has_zones() else null


## Level `level` for unit `u`: HP, STR, MAG, DEF, RES and credits × `pm`.
static func _lift(u: RtUnit, level: int, pm: int) -> void:
	u.level = level
	if pm == 1000:
		return
	for stat: StatBlock.Stat in [StatBlock.Stat.HP, StatBlock.Stat.STR, StatBlock.Stat.MAG, StatBlock.Stat.DEF,
			StatBlock.Stat.RES]:
		u.stats.values[stat] = maxi(1 if stat == StatBlock.Stat.HP else 0, _scale(u.stats.values[stat], pm))
	u.hp = u.stats.values[StatBlock.Stat.HP]
	u.credit_reward = _scale(u.credit_reward, pm)


## `total` EXP over `members` by their data EXP (each weighs at least 1); the rest of the integer split to the first.
static func _share_exp(members: Array[RtUnit], data: GameData, total: int) -> void:
	if members.is_empty():
		return
	var weights: Array[int] = []
	var sum: int = 0
	for u: RtUnit in members:
		var w: int = maxi(1, data.enemy(u.def_id).exp)
		weights.append(w)
		sum += w
	var given: int = 0
	for i in members.size():
		members[i].exp_reward = total * weights[i] / sum
		given += members[i].exp_reward
	members[0].exp_reward += total - given


static func _scale(v: int, pm: int) -> int:
	return (v * pm + 500) / 1000
