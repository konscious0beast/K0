class_name LevelBand extends RefCounted
## Levels in a season (09 §8.2, ST1-D): the EXP table up to level 50, the level band of every floor with its cap
## ("Deckel"), "Überstunden" (EXP over the cap become 10 % credits), the catch-up ("Aufholjagd": EXP × 2 below the band,
## × 3 a whole band below) and its interplay with "Ausgeruht" (the higher factor counts; the rested pool is only used
## when no catch-up runs), the "Regie-Crashkurs" (a rescue lifts a figure below band start − 2 to it, with the
## "Aufholpaket"), the colour and the level difference of an enemy (WoW-style, the number carries the information) and
## the EXP sources besides the combat — the stairs (half a level) and a floor event (5 % of a level).
## Static and pure (core): no autoloads, integer math only, no randomness. Everything here acts only with
## state.season != null (09 V-4); without a season Progression.add_exp and Balance.LEVEL_CAP rule unchanged.
## The callers: BattleBridge (combat EXP), SeasonRules.on_descend (stairs), SeasonRules._rescue (crash course),
## RunRules.apply_floor_event (event EXP); the login of ST1-G calls crash_course last (09 §5.5).

const SEASON_CAP: int = 50                 # == Balance.SEASON_LEVEL_CAP (09 §8.2)
const PM: int = 1000
## "Überstunden" (09 §8.2): EXP a figure cannot take at the cap of its floor become this share of credits.
const OVERTIME_PCT: int = 10
## Aufholjagd (09 §8.2, V-8): below the band start every EXP counts twice, a whole band (three levels) or more below
## three times.
const CATCH_UP_PM: int = 2000
const CATCH_UP_DEEP_PM: int = 3000
const DEEP_GAP: int = 3
## Regie-Crashkurs (09 §8.2, V-8): a figure below band start − CRASH_GAP is lifted exactly there.
const CRASH_GAP: int = 2
const CRASH_POTIONS: int = 3               # the Aufholpaket's three potions
const POTION_TAG: String = "heal"
## The EXP sources as shares of a level in per mille (09 §8.2, start values at band level): a regular group 4 %, a
## show boss 15 %, a Revier-Boss 25 %, an Etagenboss 50 % (the groups of the season floors give exactly these:
## EnemyLevels.apply, ST1-C), the stairs 50 % and a floor event 5 % (here), one profession point 0.2 % (ST1-E).
const SHARE_GROUP_PM: int = 40
const SHARE_SHOW_BOSS_PM: int = 150
const SHARE_QUARTER_BOSS_PM: int = 250
const SHARE_FLOOR_BOSS_PM: int = 500
const SHARE_STAIRS_PM: int = 500
const SHARE_EVENT_PM: int = 50
const SHARE_PROF_PM: int = 2
## Enemy colours (09 §3.4, §8.2): grey ≥ 6 levels below, green 3–5 below, yellow ± 2, orange 3–4 above, red ≥ 5 above
## (with the warning) — and their EXP factor.
const COLORS: PackedStringArray = ["grey", "green", "yellow", "orange", "red"]
const COLOR_EXP_PM: PackedInt32Array = [0, 500, 1000, 1200, 1400]
## The EXP kinds of add_exp: "combat" may use the rested pool; every kind but "crash" gets the catch-up.
const KINDS: PackedStringArray = ["combat", "stairs", "event", "prof"]


# --- the table and the band ------------------------------------------------------------------------------------------

## EXP from `level` to the next one: in a season the table party.json → exp_table (levels 1–49; 0 at 50), else
## Progression.exp_to_next (the campaign curve up to Balance.LEVEL_CAP). Data without a table (fixtures) continue the
## GDD curve with its last entry.
static func exp_to_next(state: GameState, data: GameData, level: int) -> int:
	if state == null or state.season == null:
		return Progression.exp_to_next(level)
	if level >= SEASON_CAP:
		return 0
	var t: PackedInt32Array = data.exp_table() if data != null else PackedInt32Array()
	if t.size() >= SEASON_CAP - 1:
		return t[clampi(level, 1, SEASON_CAP - 1) - 1]
	var g: PackedInt32Array = Progression.EXP_TABLE
	return g[clampi(level, 1, g.size()) - 1]


## The level band of floor `floor` (09 §2.4): floors.json → level_band (ST1-C) or the table of 09 §2.4 — floor 1
## 1–7, from floor 2 three levels per floor (7–10, 10–13 … 46–49), 49–50 on floor 16, 50 on floors 17 and 18.
static func band(data: GameData, floor: int) -> Vector2i:
	var def: FloorDef = data.floor_def(floor) if data != null and floor >= 1 else null
	if def != null and def.has_band():
		return Vector2i(def.level_band[0], def.level_band[1])
	return default_band(floor)


static func default_band(floor: int) -> Vector2i:
	if floor <= 1:
		return Vector2i(1, 7)
	return Vector2i(mini(SEASON_CAP, 3 * floor + 1), mini(SEASON_CAP, 3 * floor + 4))


## The highest level now (09 §8.2 "Deckel"): in a season the band end of the floor the party stands on (`floor`;
## default: the current one), never above 50; else Balance.LEVEL_CAP.
static func cap(state: GameState, data: GameData, floor: int = -1) -> int:
	if state == null or state.season == null:
		return Balance.LEVEL_CAP
	var f: int = floor if floor >= 1 else (state.floor_run.index if state.floor_run != null else 1)
	return mini(SEASON_CAP, band(data, f).y)


## The catch-up factor of `member` on its floor in per mille (09 §8.2, V-8): 1000, 2000 below the band start, 3000 a
## whole band (DEEP_GAP levels) or more below it. Only in a season.
static func catch_up_pm(state: GameState, data: GameData, member: PartyMember, floor: int = -1) -> int:
	if state == null or state.season == null or member == null:
		return PM
	var f: int = floor if floor >= 1 else (state.floor_run.index if state.floor_run != null else 1)
	var lo: int = band(data, f).x
	if member.level <= lo - DEEP_GAP:
		return CATCH_UP_DEEP_PM
	return CATCH_UP_PM if member.level < lo else PM


# --- colours ---------------------------------------------------------------------------------------------------------

## Index into COLORS of an enemy `diff` levels above the figure (negative = below).
static func color_index(diff: int) -> int:
	if diff <= -6:
		return 0
	if diff <= -3:
		return 1
	if diff <= 2:
		return 2
	if diff <= 4:
		return 3
	return 4


static func color_name(diff: int) -> String:
	return COLORS[color_index(diff)]


## The EXP factor of an enemy `diff` levels above the figure: grey 0, green 500, yellow 1000, orange 1200, red 1400.
static func color_exp_pm(diff: int) -> int:
	return COLOR_EXP_PM[color_index(diff)]


## The difference as the nameplate shows it next to the plaque (09 §3.4, V-6): "+3", "−4", "±0" (U+2212 minus).
static func diff_text(diff: int) -> String:
	if diff == 0:
		return "±0"
	return ("+%d" % diff) if diff > 0 else ("−%d" % -diff)


## Red (≥ 5 above) carries the warning symbol "Achtung" (09 §3.4).
static func is_warning(diff: int) -> bool:
	return color_index(diff) == COLORS.size() - 1


## The level of a beaten group (09 §3.4): on a season floor with band and quarters the level its groups fought on
## (ST1-C: EnemyLevels.result_level, with `state`), else the highest level of its defeated enemies; 0 without one.
static func group_level(data: GameData, result: BattleResult, state: GameState = null) -> int:
	var lv: int = 0
	if data == null or result == null:
		return lv
	if state != null:
		lv = EnemyLevels.result_level(state, data, result)
		if lv > 0:
			return lv
	for id: String in result.defeated_ids:
		if data.has_id("enemies", id):
			lv = maxi(lv, data.enemy(id).level)
	return lv


# --- EXP -------------------------------------------------------------------------------------------------------------

## EXP for `member` in a season (09 §8.2): `amount` (≥ 0) × the higher of the catch-up factor and — combat EXP only —
## "Ausgeruht" (bonus = min(amount, rested), the pool shrinks by it; with a catch-up the pool stays), then level-ups
## along the table up to the cap of `floor` (default the current one; the stairs count for the floor below); EXP over
## the cap become "Überstunden" (OVERTIME_PCT % as credits into the inventory). HP / MP rise like a level-up of the
## campaign (no full heal, a KO'd figure stays at 0 HP). Returns {"gained": EXP taken, "factor_pm", "rested": pool
## used, "overtime": credits, "info": LevelUpInfo or null}. Nothing happens without a season.
static func add_exp(state: GameState, data: GameData, member: PartyMember, amount: int, kind: String,
		floor: int = -1) -> Dictionary:
	var out: Dictionary = {"gained": 0, "factor_pm": PM, "rested": 0, "overtime": 0, "info": null}
	if state == null or state.season == null or member == null or amount <= 0:
		return out
	var factor: int = catch_up_pm(state, data, member, floor) if KINDS.has(kind) else PM
	var total: int = amount * factor / PM
	if factor == PM and kind == "combat" and member.rested > 0:
		var bonus: int = mini(amount, member.rested)
		member.rested -= bonus
		total += bonus
		out["rested"] = bonus
		factor = (amount + bonus) * PM / amount
	out["factor_pm"] = factor
	var top: int = cap(state, data, floor)
	var old_level: int = member.level
	var before: StatBlock = Progression.total_stats(member, data)
	var left: int = total
	var overtime_exp: int = 0
	while left > 0:
		if member.level >= top:
			overtime_exp += left
			member.exp = 0
			break
		var need: int = exp_to_next(state, data, member.level) - member.exp
		if left < need:
			member.exp += left
			left = 0
		else:
			left -= need
			member.level += 1
			member.exp = 0
	out["gained"] = total - overtime_exp
	if overtime_exp > 0:
		var credits: int = overtime_exp * OVERTIME_PCT / 100
		out["overtime"] = credits
		if credits > 0 and state.inventory != null:
			state.inventory.add_credits(credits)
	if member.level != old_level:
		out["info"] = _level_up(member, data, old_level, before)
	return out


## Combat EXP of a won fight (BattleBridge, only in a season): per living member the battle EXP `base` (a KO'd member
## half of it, BattleBridge.KO_EXP_PCT) × the colour factor of the beaten group against the member's level, then
## add_exp ("combat"). Fills rw.level_ups, rw.exp_by_member and rw.overtime.
static func combat_exp(state: GameState, data: GameData, result: BattleResult, base: int, was_ko: Dictionary,
		rw: BattleRewards) -> void:
	var group: int = group_level(data, result, state)
	for m: PartyMember in state.party:
		if m == null:
			continue
		var gain: int = base * BattleBridge.KO_EXP_PCT / 100 if was_ko.has(m.id) else base
		if group > 0:
			gain = gain * color_exp_pm(group - m.level) / PM
		var r: Dictionary = add_exp(state, data, m, gain, "combat")
		rw.exp_by_member[m.id] = int(r["gained"])
		rw.overtime += int(r["overtime"])
		if r["info"] != null:
			rw.level_ups.append(r["info"] as LevelUpInfo)


## Taking the stairs (09 §2.5 Nr. 7, §8.2; SeasonRules.on_descend): every member gets half of the EXP its level needs
## ("Abschluss-EP"), counted against the band of the floor below (the stairs lead there; the floor's last band step is
## the next one's first). Returns the SEASON event "exp" (nothing when no member gains).
static func on_descend(state: GameState, data: GameData) -> Array[ExploreEvent]:
	var fr: FloorRun = state.floor_run if state != null else null
	if state == null or state.season == null or fr == null:
		var none: Array[ExploreEvent] = []
		return none
	return _share_event(state, data, "stairs", SHARE_STAIRS_PM, fr.index + 1)


## A floor event completed for the first time (RunRules.apply_floor_event, only in a season): 5 % of a level each.
static func on_floor_event(state: GameState, data: GameData) -> Array[ExploreEvent]:
	if state == null or state.season == null:
		var none: Array[ExploreEvent] = []
		return none
	return _share_event(state, data, "event", SHARE_EVENT_PM, -1)


## The SEASON event "exp" {source, members: {id: {gained, level, from, overtime}}, overtime} of a share of a level for
## every member ("stairs" / "event"); [] without a gain.
static func _share_event(state: GameState, data: GameData, source: String, share_pm: int,
		floor: int) -> Array[ExploreEvent]:
	var out: Array[ExploreEvent] = []
	var members: Dictionary = {}
	var overtime: int = 0
	for m: PartyMember in state.party:
		if m == null:
			continue
		var amount: int = exp_to_next(state, data, m.level) * share_pm / PM
		var from: int = m.level
		var r: Dictionary = add_exp(state, data, m, amount, source, floor)
		overtime += int(r["overtime"])
		if int(r["gained"]) > 0 or int(r["overtime"]) > 0:
			var learned: PackedStringArray = PackedStringArray()
			if r["info"] != null:
				learned = (r["info"] as LevelUpInfo).learned
			members[m.id] = {"gained": int(r["gained"]), "from": from, "level": m.level, "overtime": int(r["overtime"]),
				"learned": Array(learned)}
	if not members.is_empty():
		out.append(_ev("exp", {"source": source, "members": members, "overtime": overtime}))
	return out


# --- Regie-Crashkurs -------------------------------------------------------------------------------------------------

## The Regie-Crashkurs (09 §8.2, V-8): at a rescue (SeasonRules._rescue, after the move) and at a login (ST1-G, the last
## step of "away") every member below band start − CRASH_GAP of its floor is lifted exactly there (EXP at the start of
## the level, HP / MP follow like a level-up) — and the party gets the Aufholpaket: for every equipment slot of a lifted
## member that holds something weaker, the best common piece of that slot it can wear (catch_up_items), plus three
## potions. No title, no Quote, no credits. Returns the SEASON event "crash" {floor, members: {id: [from, to]}, items}
## or [] when nobody is far enough behind.
static func crash_course(state: GameState, data: GameData) -> Array[ExploreEvent]:
	var out: Array[ExploreEvent] = []
	if state == null or state.season == null or state.floor_run == null or data == null:
		return out
	var target: int = maxi(1, band(data, state.floor_run.index).x - CRASH_GAP)
	var lifted: Dictionary = {}
	var items: PackedStringArray = []
	for m: PartyMember in state.party:
		if m == null or m.level >= target:
			continue
		var before: StatBlock = Progression.total_stats(m, data)
		var from: int = m.level
		m.level = target
		m.exp = 0
		_level_up(m, data, from, before)
		lifted[m.id] = [from, target]
		items.append_array(catch_up_items(state, data, m))
	if lifted.is_empty():
		return out
	var potion: String = catch_up_potion(data)
	for i in CRASH_POTIONS:
		if potion != "":
			items.append(potion)
	if state.inventory != null:
		for id: String in items:
			state.inventory.add_item_or_credits(data, id, 1)
	out.append(_ev("crash", {"floor": state.floor_run.index, "members": lifted, "items": Array(items)}))
	return out


## The Aufholpaket's pieces for `member` (09 §8.2): per slot the common equipment of that slot the member can wear with
## the highest stat sum (ties: the lower id) — when it beats the equipped piece (an empty slot counts −1) and the
## inventory holds none of it yet. Until ST1-C gives loot an item level, "common piece of the floor" means the best
## common piece of the data.
static func catch_up_items(state: GameState, data: GameData, member: PartyMember) -> PackedStringArray:
	var out: PackedStringArray = []
	for slot: String in ["weapon", "armor", "accessory"]:
		var best: ItemDef = null
		for it: ItemDef in data.all_items():
			if it.type != slot or it.rarity != "common" or not (it.equip_by.is_empty() or it.equip_by.has(member.id)):
				continue
			if best == null or _stat_sum(it) > _stat_sum(best) or (_stat_sum(it) == _stat_sum(best) and it.id < best.id):
				best = it
		if best == null:
			continue
		var cur: String = str(member.equipment.get(slot, ""))
		var cur_sum: int = _stat_sum(data.item(cur)) if cur != "" and data.has_id("items", cur) else -1
		var owned: bool = state.inventory != null and state.inventory.has(best.id)
		if _stat_sum(best) > cur_sum and best.id != cur and not owned and not out.has(best.id):
			out.append(best.id)
	return out


## The potion of the Aufholpaket: the cheapest common consumable with the tag "heal" (ties: the lower id); "" if none.
static func catch_up_potion(data: GameData) -> String:
	var best: ItemDef = null
	for it: ItemDef in data.all_items():
		if it.type != "consumable" or it.rarity != "common" or not it.tags.has(POTION_TAG):
			continue
		if best == null or it.price < best.price or (it.price == best.price and it.id < best.id):
			best = it
	return best.id if best != null else ""


# --- private ---------------------------------------------------------------------------------------------------------

## The LevelUpInfo of a level change (stats before → after; HP / MP follow the new maxima like a campaign level-up;
## the learnset skills join member.skills like there; learned = the abilities the new levels unlock,
## AbilityBook.new_between).
static func _level_up(member: PartyMember, data: GameData, old_level: int, before: StatBlock) -> LevelUpInfo:
	var after: StatBlock = Progression.total_stats(member, data)
	var info: LevelUpInfo = LevelUpInfo.new()
	info.member_id = member.id
	info.old_level = old_level
	info.new_level = member.level
	for i in StatBlock.KEYS.size():
		info.stat_gains[StatBlock.KEYS[i]] = after.values[i] - before.values[i]
	Progression.follow_max_vitals(member, before, after)
	Progression.learn_between(member, data, old_level, member.level)
	info.learned = AbilityBook.new_between(member, data, old_level, member.level)
	return info


static func _stat_sum(it: ItemDef) -> int:
	var n: int = 0
	if it == null:
		return n
	for k: Variant in it.stats.keys():
		n += JsonUtil.to_int(it.stats[k])
	return n


static func _ev(kind: String, data: Dictionary) -> ExploreEvent:
	var d: Dictionary = {"kind": kind}
	d.merge(data)
	return ExploreEvent.make(ExploreEvent.Type.SEASON, 0, d)
