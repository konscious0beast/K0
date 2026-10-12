class_name EnemyLevels extends RefCounted
## Enemy levels of the seasons (09 §3.4; 07 CR-32 d; ST1-C): every enemy group of a season floor with a band has a level
## in it (the generator v2 sets it per group: the Pflichtweg at the band's middle, side ways up to band end + 1, the
## show boss's elite group band end + 2, Revier-Boss band end, Etagenboss band end + 1) and its enemies grow with the
## level table of data/rt_balance.json (RtBalance.enemy_level_pm, Ganzzahl-Promille): an enemy of data level d at
## level L has its HP, STR, MAG, DEF, RES, EXP and credits × table(L) / table(d). BattleBridge.make_rt_setup calls
## apply() — a season only: without one no level is set (factor 1000) and every run stays bit-identical; floor 1 (no
## quarters) keeps its data levels in a season too.
##
## Until the levels above 10 exist (ST1-D ships party.json exp_table) no figure passes Balance.LEVEL_CAP, so no enemy of
## a season gets more than that either (level_cap) — the bands apply by themselves once the table ships.
## Pure (core): no autoloads; layer core/progression (like BattleBridge: core/dungeon for the layout, core/rt for the
## units and the table).

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
	var fr: FloorRun = state.floor_run if state != null else null
	if state == null or state.season == null or fr == null or data == null:
		return NO_LEVEL
	var def: FloorDef = data.floor_def(fr.index)
	if def == null or not def.has_band() or not def.has_zones():
		return NO_LEVEL
	var level: int = ZoneGenerator.band_middle(def)
	if group_id != "":
		var l: FloorLayout = layout if layout != null else DungeonGenerator.generate(def, fr.seed)
		var spawn: EnemySpawn = l.enemy_by_id(group_id) if l != null else null
		if spawn != null and spawn.level > 0:
			level = spawn.level
	return mini(level, level_cap(data))


## The ‰ factor that lifts an enemy of data level `def_level` to `level` (07 CR-32 d): table(level) × 1000 /
## table(def_level), rounded half up; 1000 for NO_LEVEL.
static func factor_pm(bal: RtBalance, level: int, def_level: int) -> int:
	if bal == null or level <= NO_LEVEL:
		return 1000
	var base: int = maxi(1, bal.enemy_level_pm(maxi(1, def_level)))
	return (bal.enemy_level_pm(level) * 1000 + base / 2) / base


## BattleBridge.make_rt_setup's hook (a season only, before the RtMods): every enemy unit of the setup gets the level of
## its group (enemy_level; the unit's level for the HUD's plaque) and its HP, STR, MAG, DEF, RES, EXP and credits ×
## factor_pm. Nothing changes without a season or on a floor without band and quarters. Summons of a running combat
## keep their data level.
static func apply(s: RtSetup, state: GameState, data: GameData, bal: RtBalance) -> void:
	if s == null or state == null or state.season == null or data == null or state.floor_run == null:
		return
	var def: FloorDef = data.floor_def(state.floor_run.index)
	if def == null or not def.has_band() or not def.has_zones():
		return
	var layout: FloorLayout = DungeonGenerator.generate(def, state.floor_run.seed)
	var by_unit: Dictionary = {}
	for g: Dictionary in s.groups:
		var level: int = enemy_level(state, data, str(g.get("group_id", "")), layout)
		for uid: Variant in (g.get("units", []) as Array):
			by_unit[str(uid)] = level
	for u: RtUnit in s.units:
		if u.side != Combatant.Side.ENEMY or not by_unit.has(u.id) or not data.has_id("enemies", u.def_id):
			continue
		var level: int = int(by_unit[u.id])
		if level <= NO_LEVEL:
			continue
		u.level = level
		var pm: int = factor_pm(bal, level, data.enemy(u.def_id).level)
		if pm == 1000:
			continue
		for stat: StatBlock.Stat in [StatBlock.Stat.HP, StatBlock.Stat.STR, StatBlock.Stat.MAG, StatBlock.Stat.DEF,
				StatBlock.Stat.RES]:
			u.stats.values[stat] = maxi(1 if stat == StatBlock.Stat.HP else 0, _scale(u.stats.values[stat], pm))
		u.hp = u.stats.values[StatBlock.Stat.HP]
		u.exp_reward = _scale(u.exp_reward, pm)
		u.credit_reward = _scale(u.credit_reward, pm)


static func _scale(v: int, pm: int) -> int:
	return (v * pm + 500) / 1000
