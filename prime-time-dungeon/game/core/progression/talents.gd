class_name Talents extends RefCounted
## Talent-Show (06 §2.2, 02_TECH §6.5): from level 3 every odd level (L3, L5, L7, L9; later caps continue with L11 …)
## earns each party member one talent choice — 1 of 2 talents from the member's pool (talents.json, `for`). Choices
## wait until the player opens the Talent-Show in a safe room (nothing interrupts a battle or the exploration).
##
## Static and pure (core): reads only GameState / PartyMember / GameData, no autoloads, integer / per-mille math only.
## Determinism (05 §3.3): the offer is a function of (run seed, member, level, current ranks) — reloading never changes
## it and it is never recorded; the pick is the recorded command {"t": "talent", "member", "id"} (Game.pick_talent).
## Open choices are derived, not stored: the odd levels >= 3 up to the member's level minus the number of picks (the
## oldest open level is always resolved first).
##
## Where the effects apply (06 §2.2 table):
##   stat_flat / stat_pct / liga_stat_pct → Progression.total_stats (after equipment, before class / species);
##     liga_stat_pct only while the member fights in the Unterhosen-Liga — the single source of truth is package C's
##     tier (MarottenRules.in_liga: the controlled hero from tier 1, the partner in tier 2), passed in as `liga`
##   crit_add_pm, element_pm → Progression.to_combatant (crit_bonus, element_mods)
##   preemptive_dmg_pm, stunt_window_pm → Combatant.talent_mods → ActionResolver (first own turn after a preemptive
##     strike) / BattleState.stunt_chance (success chance before success_cap)
##   post_battle_mp_pm → BattleBridge.apply_result ("Werbepause" regeneration)
##   field_range_pm / field_cd_pm → field ability of the controlled hero (exploration, package A: EncounterRules)
##   marotte_heart → MarottenRules (package C) via marotte_bonus_hearts; hype_gain_pm / follower_pm → GameState

const OFFER_SIZE: int = 2
const FIRST_LEVEL: int = 3
const PM: int = 1000


## True for the levels that earn a choice (odd, >= 3).
static func is_talent_level(level: int) -> bool:
	return level >= FIRST_LEVEL and level % 2 == 1


## Number of talent choices made (sum of all ranks).
static func picks(member: PartyMember) -> int:
	var n: int = 0
	if member == null:
		return n
	for k: Variant in member.talents.keys():
		n += maxi(0, int(member.talents[k]))
	return n


## Talent choices made by the whole party (0 = the Talent-Show was never used in this run).
static func picks_in_party(state: GameState) -> int:
	var n: int = 0
	if state == null:
		return n
	for m: PartyMember in state.party:
		n += picks(m)
	return n


## Open choices: odd levels >= 3 up to the member's level that are not picked yet, oldest first.
static func pending_levels(member: PartyMember) -> PackedInt32Array:
	var out: PackedInt32Array = []
	if member == null:
		return out
	var skip: int = picks(member)
	for lv in range(FIRST_LEVEL, member.level + 1, 2):
		if skip > 0:
			skip -= 1
			continue
		out.append(lv)
	return out


static func rank(member: PartyMember, talent_id: String) -> int:
	if member == null:
		return 0
	return int(member.talents.get(talent_id, 0))


## The 2 talents offered to `member_id` for its choice of `level`: weighted draw without replacement over the pool
## (`for` contains the member, min_level <= level, rank < max_rank) in id order with
## SeedUtil.derive(state.seed, "talent:" + member_id, level). Fewer if the pool is smaller; [] for an unknown member.
static func offer(state: GameState, data: GameData, member_id: String, level: int) -> PackedStringArray:
	var out: PackedStringArray = []
	var m: PartyMember = state.member(member_id) if state != null else null
	if m == null or data == null:
		return out
	var cands: Array[TalentDef] = []
	for t: TalentDef in data.talents_for(member_id):
		if t.min_level <= level and rank(m, t.id) < t.max_rank:
			cands.append(t)
	var rng: RandomNumberGenerator = SeedUtil.make_rng(SeedUtil.derive(state.seed, "talent:" + member_id, level))
	while out.size() < OFFER_SIZE and not cands.is_empty():
		var total: int = 0
		for t: TalentDef in cands:
			total += maxi(1, t.weight)
		var r: int = rng.randi_range(0, total - 1)
		var i: int = 0
		while r >= maxi(1, cands[i].weight):
			r -= maxi(1, cands[i].weight)
			i += 1
		out.append(cands[i].id)
		cands.remove_at(i)
	return out


## Offer of the member's oldest open level; [] without an open choice.
static func current_offer(state: GameState, data: GameData, member_id: String) -> PackedStringArray:
	var m: PartyMember = state.member(member_id) if state != null else null
	var open: PackedInt32Array = pending_levels(m)
	if open.is_empty():
		return PackedStringArray()
	return offer(state, data, member_id, open[0])


## True if the member has an open choice with a non-empty offer.
static func has_choice(state: GameState, data: GameData, member_id: String) -> bool:
	return not current_offer(state, data, member_id).is_empty()


## Total open choices over the party (badges: safe room menu, party menu).
static func open_choices(state: GameState, data: GameData) -> int:
	var n: int = 0
	if state == null:
		return n
	for m: PartyMember in state.party:
		if m != null and has_choice(state, data, m.id):
			n += pending_levels(m).size()
	return n


## In a safe room (FloorRun.location is a safe room id; THE rule is RunRules.in_safe_room): the Talent-Show only runs
## there.
static func in_safe_room(state: GameState) -> bool:
	return RunRules.in_safe_room(state)


## "" = the pick is valid, else "unknown_member" | "unknown_talent" | "no_pending" | "not_in_safe_room" |
## "max_rank" | "not_offered" (only the offer of the oldest open level can be picked).
static func check_pick(state: GameState, data: GameData, member_id: String, talent_id: String) -> String:
	var m: PartyMember = state.member(member_id) if state != null else null
	if m == null or data == null:
		return "unknown_member"
	if not data.has_id("talents", talent_id):
		return "unknown_talent"
	var open: PackedInt32Array = pending_levels(m)
	if open.is_empty():
		return "no_pending"
	if not in_safe_room(state):
		return "not_in_safe_room"
	if rank(m, talent_id) >= data.talent(talent_id).max_rank:
		return "max_rank"
	if not offer(state, data, member_id, open[0]).has(talent_id):
		return "not_offered"
	return ""


## Applies a valid pick (rank + 1). HP / MP follow a changed maximum like a level-up (no full heal; KO stays KO).
static func pick(state: GameState, data: GameData, member_id: String, talent_id: String) -> bool:
	if check_pick(state, data, member_id, talent_id) != "":
		return false
	var m: PartyMember = state.member(member_id)
	var before: StatBlock = Progression.total_stats(m, data)
	m.talents[talent_id] = rank(m, talent_id) + 1
	Progression.follow_max_vitals(m, before, Progression.total_stats(m, data))
	return true


# --- effects ----------------------------------------------------------------------------------------------------------

## Bonus to add to `base` (level stat + equipment) for StatBlock index `stat_index`: flat values, then the summed
## per-mille of stat_pct (+ liga_stat_pct when `liga`: the member fights in the Unterhosen-Liga — callers ask
## MarottenRules.in_liga / liga_member, package C's tier), round half up.
static func stat_bonus(member: PartyMember, data: GameData, stat_index: int, base: int, liga: bool = false) -> int:
	if member == null or member.talents.is_empty() or data == null:
		return 0
	var key: String = StatBlock.KEYS[stat_index]
	var flat: int = 0
	var pct: int = 0
	for e: Array in _effects(member, data):
		var fx: Dictionary = e[0]
		if str(fx.get("stat", "")) != key:
			continue
		match str(fx["kind"]):
			"stat_flat":
				flat += int(fx["value"]) * int(e[1])
			"stat_pct":
				pct += int(fx["pm"]) * int(e[1])
			"liga_stat_pct":
				if liga:
					pct += int(fx["pm"]) * int(e[1])
	var v: int = base + flat
	if pct != 0:
		v = (maxi(0, v) * (PM + pct) + PM / 2) / PM
	return v - base


## Summed crit chance bonus in per-mille (+30 = +3 % crit).
static func crit_add_pm(member: PartyMember, data: GameData) -> int:
	return _sum(member, data, "crit_add_pm")


## Damage-taken factor for `element` in per-mille (1000 = neutral, 750 = ×0.75).
static func element_pm(member: PartyMember, data: GameData, element: String) -> int:
	return _product(member, data, "element_pm", element)


## Elements with an element_pm talent (sorted).
static func elements(member: PartyMember, data: GameData) -> PackedStringArray:
	var out: PackedStringArray = []
	for e: Array in _effects(member, data):
		var fx: Dictionary = e[0]
		if str(fx["kind"]) == "element_pm" and not out.has(str(fx["element"])):
			out.append(str(fx["element"]))
	out.sort()
	return out


## Extra "Werbepause" MP after a won battle in per-mille of MaxMP (added to Balance.POST_BATTLE_MP_REGEN).
static func post_battle_mp_pm(member: PartyMember, data: GameData) -> int:
	return _sum(member, data, "post_battle_mp_pm")


## Field ability reach factor (1000 = neutral; Kai: Feldschlag, Mopsula: Bellen).
static func field_range_pm(member: PartyMember, data: GameData) -> int:
	return _product(member, data, "field_range_pm")


## Field ability cooldown factor (1000 = neutral, 700 = −30 %).
static func field_cd_pm(member: PartyMember, data: GameData) -> int:
	return _product(member, data, "field_cd_pm")


## Damage factor of the member's first own turn after a preemptive strike (1000 = neutral).
static func preemptive_dmg_pm(member: PartyMember, data: GameData) -> int:
	return _product(member, data, "preemptive_dmg_pm")


## Stunt success factor (1000 = neutral), applied before the skill's success_cap.
static func stunt_window_pm(member: PartyMember, data: GameData) -> int:
	return _product(member, data, "stunt_window_pm")


## Battle-time factors for Combatant.talent_mods: {"preemptive_dmg_pm", "stunt_pm"} — only the non-neutral ones.
static func battle_mods(member: PartyMember, data: GameData) -> Dictionary:
	var out: Dictionary = {}
	var pre: int = preemptive_dmg_pm(member, data)
	if pre != PM:
		out["preemptive_dmg_pm"] = pre
	var stunt: int = stunt_window_pm(member, data)
	if stunt != PM:
		out["stunt_pm"] = stunt
	return out


## Extra hearts per floor for the first fulfilled M.O.D. preference (read by MarottenRules, package C).
static func marotte_bonus_hearts(state: GameState, data: GameData) -> int:
	var n: int = 0
	if state == null:
		return n
	for m: PartyMember in state.party:
		n += _sum(m, data, "marotte_heart", "", "per_floor")
	return n


## Hype gain factor of the party in per-mille (1000 = neutral; product, round half up per step).
static func hype_pm(state: GameState, data: GameData) -> int:
	return _party_product(state, data, "hype_gain_pm")


## Follower factor of the party in per-mille (1000 = neutral).
static func follower_pm(state: GameState, data: GameData) -> int:
	return _party_product(state, data, "follower_pm")


# --- helpers ----------------------------------------------------------------------------------------------------------

## [[effect: Dictionary, rank: int], …] of the member's known talents (talent id order, effect order).
static func _effects(member: PartyMember, data: GameData) -> Array:
	var out: Array = []
	if member == null or data == null or member.talents.is_empty():
		return out
	var ids: Array = member.talents.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	for id: Variant in ids:
		var r: int = int(member.talents[id])
		if r <= 0 or not data.has_id("talents", str(id)):
			continue
		for fx: Dictionary in data.talent(str(id)).effects:
			out.append([fx, r])
	return out


static func _sum(member: PartyMember, data: GameData, kind: String, element: String = "", field: String = "pm") -> int:
	var n: int = 0
	for e: Array in _effects(member, data):
		var fx: Dictionary = e[0]
		if str(fx["kind"]) == kind and (element == "" or str(fx.get("element", "")) == element):
			n += int(fx.get(field, 0)) * int(e[1])
	return n


static func _product(member: PartyMember, data: GameData, kind: String, element: String = "") -> int:
	var acc: int = PM
	for e: Array in _effects(member, data):
		var fx: Dictionary = e[0]
		if str(fx["kind"]) == kind and (element == "" or str(fx.get("element", "")) == element):
			for _r in int(e[1]):
				acc = (acc * int(fx["pm"]) + PM / 2) / PM
	return acc


static func _party_product(state: GameState, data: GameData, kind: String) -> int:
	var acc: int = PM
	if state == null:
		return acc
	for m: PartyMember in state.party:
		var f: int = _product(m, data, kind)
		if f != PM:
			acc = (acc * f + PM / 2) / PM
	return acc
