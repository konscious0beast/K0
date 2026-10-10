class_name MarottenRules extends RefCounted
## M.O.D.'s preferences ("Marotten", show bets) and the Unterhosen-Liga (06 §4, package C). Static and pure: reads
## and writes only GameState / ShowState (ShowState.marotten, two StatIds) and GameData — no autoloads, no clock, no
## global RNG. Show is the only caller (a reaction to recorded commands like the achievements: Show.start_floor,
## begin_battle / end_battle, Game.visit_room → Show.on_room_visited, floor_completed), so a live run and
## Game.replay_log compute the same state; nothing here is a recorded command.
##
## Rules in one sentence each (the player-facing texts are data, marotten.json):
## - Per floor M.O.D. announces her preferences: floor 1 one starter, from floor 2 on two — chosen from the seed
##   (SeedUtil.derive(seed, "marotte", floor)), not repeating the previous floor's where the pool allows it.
## - A won battle (or, for kind explore, a first room visit) that matches a preference fills a heart (at most one per
##   preference and battle); `goal` hearts win the bet: Fanpost-Paket (won_box), followers, hype, bets_won +1.
## - Unterhosen-Liga (always on, kind liga): tier 1 = the controlled hero wears no armor and no accessory, tier 2 =
##   both; frozen at battle start; multiplies the battle's hype gains and followers (reward.tiers, per mille).
## - Never mandatory, never a penalty: unmet preferences simply expire with the floor.
## - Event runs (rules non-empty, 06 §4.8 Nr. 4): preferences and Liga are shown and counted (hearts, lines), but give
##   no multipliers, no followers / hype / boxes and fire no show_bet achievements — the score is the same with or
##   without them. rules.marotten.enabled / rules.liga.enabled switch them off (part of rules_hash).

const BATTLE: String = "marotte_battle"
const EXPLORE: String = "explore_zone"
## e-keys of the two condition contexts (06 §4.6; == the DataValidator marotten helper's lists).
const BATTLE_KEYS: PackedStringArray = ["won", "hero", "party_turns", "items_used", "gifts", "defends",
	"flee_attempts", "distinct_actions", "stunts_success", "weakness_hits", "min_party_hp_pct", "party_kos",
	"last_kill_member", "encounter_type", "is_boss", "is_floor_boss", "boss_id", "kai_weapon", "equip_all_common",
	"hero_armor_empty", "hero_acc_empty", "party_armor_empty", "party_acc_empty", "liga_tier"]
const ZONE_KEYS: PackedStringArray = ["zones_since_battle", "zone", "floor"]
const LIGA_SLOTS: PackedStringArray = ["armor", "accessory"]
const DEFAULT_HERO: String = "kai"
## Liga floor bonus (06 §4.3): all won battles of a floor (at least these many) in the Liga.
const LIGA_FLOOR_MIN_BATTLES: int = 3
const DUO_FLOOR_MIN_BATTLES: int = 5


# --- run rules (event runs) -----------------------------------------------------------------------------------------

## Preferences are announced (rules.marotten.enabled, default true).
static func enabled(rules: Dictionary) -> bool:
	return _rule_on(rules, "marotten")


## The Liga tiers count (rules.liga.enabled, default true).
static func liga_enabled(rules: Dictionary) -> bool:
	return _rule_on(rules, "liga")


## Rewards and multipliers only in the campaign (rules {}); event runs: show and comment only (06 §4.8 Nr. 4).
static func rewards_on(rules: Dictionary) -> bool:
	return rules.is_empty()


## Problems of rules.marotten / rules.liga ({"enabled": bool}) for EventDef validation.
static func validate_rules(rules: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for key: String in ["marotten", "liga"]:
		if not rules.has(key):
			continue
		var v: Variant = rules[key]
		if not (v is Dictionary):
			out.append("rules.%s must be a Dictionary {\"enabled\": bool}" % key)
			continue
		for k: Variant in (v as Dictionary).keys():
			if str(k) != "enabled":
				out.append("rules.%s: unknown key '%s'" % [key, str(k)])
		if (v as Dictionary).has("enabled") and not ((v as Dictionary)["enabled"] is bool):
			out.append("rules.%s.enabled must be a bool" % key)
	return out


# --- floor ----------------------------------------------------------------------------------------------------------

## The preferences of floor `floor_index` (pure, nothing changes): 1 on floor 1 (starters only), 2 from floor 2 on;
## rotation entries with min_floor <= floor, sorted by id; the previous floor's ids (`prev`) are left out while enough
## others remain; weighted draw without replacement with SeedUtil.derive(state.seed, "marotte", floor_index).
static func announce(state: GameState, data: GameData, floor_index: int,
		prev: PackedStringArray = PackedStringArray()) -> PackedStringArray:
	var out: PackedStringArray = []
	if state == null or data == null:
		return out
	var want: int = 1 if floor_index <= 1 else 2
	var pool: Array[MarotteDef] = []
	for def: MarotteDef in data.all_marotten():
		if def.kind == "liga" or not def.rotation or def.min_floor > floor_index:
			continue
		if floor_index <= 1 and not def.starter:
			continue
		pool.append(def)
	pool.sort_custom(func(a: MarotteDef, b: MarotteDef) -> bool: return a.id < b.id)
	var fresh: Array[MarotteDef] = []
	for def: MarotteDef in pool:
		if not prev.has(def.id):
			fresh.append(def)
	if fresh.size() >= want:
		pool = fresh
	var rng: RandomNumberGenerator = SeedUtil.make_rng(SeedUtil.derive(state.seed, "marotte", floor_index))
	while out.size() < want and not pool.is_empty():
		var total: int = 0
		for def: MarotteDef in pool:
			total += maxi(1, def.weight)
		var roll: int = rng.randi_range(0, total - 1)
		var pick: int = 0
		for i in pool.size():
			roll -= maxi(1, pool[i].weight)
			if roll < 0:
				pick = i
				break
		out.append(pool[pick].id)
		pool.remove_at(pick)
	return out


## Floor start (Show.start_floor): the new floor's preferences; hearts, won bets, the pacifist counter and the Liga
## floor counters start over; the old preferences become `prev`. → {"announce": PackedStringArray}.
static func on_floor(state: GameState, data: GameData, floor_index: int, rules: Dictionary) -> Dictionary:
	if state == null or state.show == null:
		return {"announce": PackedStringArray()}
	var old: Dictionary = state.show.marotten
	var prev: PackedStringArray = JsonUtil.to_str_array(old.get("active", []))
	if JsonUtil.to_int(old.get("floor", 0)) == floor_index:
		prev = JsonUtil.to_str_array(old.get("prev", []))   # the same floor again: keep its predecessor
	var ids: PackedStringArray = announce(state, data, floor_index, prev) if enabled(rules) else PackedStringArray()
	state.show.marotten = {"floor": floor_index, "active": Array(ids), "hits": {}, "won": [], "prev": Array(prev),
		"zones": 0, "liga": {"battles": 0, "t1": 0, "t2": 0}}
	return {"announce": ids}


## Old saves (no record yet) or a record of another floor: the preferences of the current floor, deterministic from
## the seed. No-op when the record matches the floor.
static func ensure_floor(state: GameState, data: GameData, rules: Dictionary) -> void:
	if state == null or state.show == null or state.floor_run == null:
		return
	if JsonUtil.to_int(state.show.marotten.get("floor", 0)) != state.floor_run.index:
		on_floor(state, data, state.floor_run.index, rules)


# --- Unterhosen-Liga ------------------------------------------------------------------------------------------------

## The controlled hero (GameState.hero of package A; "kai" while that field does not exist / is empty).
static func hero_of(state: GameState) -> String:
	if state == null:
		return DEFAULT_HERO
	var h: Variant = state.get("hero")
	var s: String = str(h) if h != null else ""
	return s if s != "" and state.member(s) != null else DEFAULT_HERO


## The liga entry of the data (kind "liga"), null if none.
static func liga_def(data: GameData) -> MarotteDef:
	if data == null:
		return null
	for def: MarotteDef in data.all_marotten():
		if def.kind == "liga":
			return def
	return null


## 0 | 1 (the controlled hero: armor and accessory slot empty) | 2 (both party members). rules.liga.enabled false → 0.
static func liga_tier(state: GameState, rules: Dictionary = {}) -> int:
	if state == null or not liga_enabled(rules):
		return 0
	if not liga_blockers(state, hero_of(state)).is_empty() or state.member(hero_of(state)) == null:
		return 0
	for m: PartyMember in state.party:
		if m != null and not liga_blockers(state, m.id).is_empty():
			return 1
	return 2


## Item ids in the armor / accessory slot of `member_id` (the "Liga blockiert durch: …" line); [] = Liga-ready.
static func liga_blockers(state: GameState, member_id: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var m: PartyMember = state.member(member_id) if state != null else null
	if m == null:
		return out
	for slot: String in LIGA_SLOTS:
		var item_id: String = str(m.equipment.get(slot, ""))
		if item_id != "":
			out.append(item_id)
	return out


## Per-mille factor of a Liga tier on battle hype gains (&"hype") or battle followers (&"follower"); 1000 = neutral.
static func liga_pm(data: GameData, tier: int, what: StringName) -> int:
	var def: MarotteDef = liga_def(data)
	if def == null or tier <= 0:
		return 1000
	var t: Dictionary = def.liga_tier_reward(tier)
	return maxi(1000, JsonUtil.to_int(t.get("hype_pm" if what == &"hype" else "follower_pm", 1000), 1000))


# --- battles --------------------------------------------------------------------------------------------------------

## A battle starts: the pacifist counter (new rooms since the last battle) resets.
static func on_battle_start(state: GameState) -> void:
	if state != null and state.show != null and not state.show.marotten.is_empty():
		state.show.marotten["zones"] = 0


## The marotte_battle context (06 §4.6) of a won battle: BattleResult + tally (MarottenTracker) + equipment.
static func battle_context(state: GameState, data: GameData, result: BattleResult, tally: Dictionary) -> Dictionary:
	var hero: String = hero_of(state)
	var kai: PartyMember = state.member("kai") if state != null else null
	var floor_def: FloorDef = data.floor_def(state.floor_run.index) if data != null and state != null \
		and state.floor_run != null else null
	var party_armor: bool = true
	var party_acc: bool = true
	var all_common: bool = true
	if state != null:
		for m: PartyMember in state.party:
			if m == null:
				continue
			party_armor = party_armor and str(m.equipment.get("armor", "")) == ""
			party_acc = party_acc and str(m.equipment.get("accessory", "")) == ""
			for slot: String in ["weapon", "armor", "accessory"]:
				var iid: String = str(m.equipment.get(slot, ""))
				if iid != "" and data != null and data.has_id("items", iid) and data.item(iid).rarity != "common":
					all_common = false
	var hm: PartyMember = state.member(hero) if state != null else null
	return {
		"won": result != null and result.outcome == BattleResult.Outcome.VICTORY,
		"hero": hero,
		"party_turns": result.party_turns if result != null else 0,
		"items_used": result.items_used if result != null else 0,
		"gifts": JsonUtil.to_int(tally.get("gifts", 0)),
		"defends": JsonUtil.to_int(tally.get("defends", 0)),
		"flee_attempts": JsonUtil.to_int(tally.get("flee_attempts", 0)),
		"distinct_actions": JsonUtil.to_int(tally.get("distinct_actions", 0)),
		"stunts_success": JsonUtil.to_int(tally.get("stunts_success", 0)),
		"weakness_hits": result.weakness_hits if result != null else 0,
		"min_party_hp_pct": result.min_party_hp_pct if result != null else 1.0,
		"party_kos": result.party_kos if result != null else 0,
		"last_kill_member": str(tally.get("last_kill_member", "")),
		"encounter_type": _encounter_type(result.advantage if result != null else 0),
		"is_boss": result != null and result.is_boss,
		"is_floor_boss": result != null and floor_def != null and result.encounter_id == floor_def.floor_boss,
		"boss_id": result.boss_id if result != null else "",
		"kai_weapon": str(kai.equipment.get("weapon", "")) if kai != null else "",
		"equip_all_common": all_common,
		"hero_armor_empty": hm != null and str(hm.equipment.get("armor", "")) == "",
		"hero_acc_empty": hm != null and str(hm.equipment.get("accessory", "")) == "",
		"party_armor_empty": party_armor,
		"party_acc_empty": party_acc,
		"liga_tier": JsonUtil.to_int(tally.get("liga_tier", 0)),
	}


## A finished battle (victories only; tutorial battles never count) → hearts, won bets, Liga counters; writes
## ShowState.marotten and the StatIds bets_won / liga_battles. Returns what Show applies:
## {"hits": [ids], "won": [ids], "hype": int (hit hype, before multipliers), "follower_pm": int (this battle's
## followers × hits), "boxes": [box ids], "followers": int (won bets), "won_hype": int, "show_bet": [payloads],
## "liga_tier": int}.
static func on_battle_end(state: GameState, data: GameData, result: BattleResult, tally: Dictionary,
		rules: Dictionary) -> Dictionary:
	var out: Dictionary = _empty_result()
	if state == null or state.show == null or result == null or data == null:
		return out
	if result.outcome != BattleResult.Outcome.VICTORY or bool(tally.get("tutorial", false)):
		return out
	if state.show.marotten.is_empty():
		ensure_floor(state, data, rules)
		if state.show.marotten.is_empty():
			return out                                         # no floor yet (tests): nothing to count
	var ctx: Dictionary = battle_context(state, data, result, tally)
	_evaluate(state, data, BATTLE, ctx, rules, out)
	var tier: int = JsonUtil.to_int(ctx["liga_tier"])
	out["liga_tier"] = tier
	var liga: Dictionary = _liga_record(state)
	liga["battles"] = JsonUtil.to_int(liga.get("battles", 0)) + 1
	if tier >= 1:
		liga["t1"] = JsonUtil.to_int(liga.get("t1", 0)) + 1
		_bump(state, "liga_battles")
		if rewards_on(rules):
			(out["show_bet"] as Array).append(_payload(state, "liga", "battle", _liga_id(data), tier, 0, 0, ctx))
	if tier >= 2:
		liga["t2"] = JsonUtil.to_int(liga.get("t2", 0)) + 1
	return out


## A first room visit while the countdown runs (Show.on_room_visited; never safe rooms): the pacifist counter +1 and
## the explore preferences (`e.zones_since_battle`). A hit latches: the counter starts over. Same result shape as
## on_battle_end.
static func on_zone(state: GameState, data: GameData, zone: String, rules: Dictionary) -> Dictionary:
	var out: Dictionary = _empty_result()
	if state == null or state.show == null or data == null or state.show.marotten.is_empty():
		return out
	var m: Dictionary = state.show.marotten
	m["zones"] = JsonUtil.to_int(m.get("zones", 0)) + 1
	var payload: Dictionary = {"zones_since_battle": int(m["zones"]), "zone": zone,
		"floor": state.floor_run.index if state.floor_run != null else 0}
	_evaluate(state, data, EXPLORE, payload, rules, out)
	if not (out["hits"] as Array).is_empty():
		m["zones"] = 0
	return out


## The floor is done (Events.floor_completed): the Liga floor bonus — every won battle of the floor (>= 3) in the Liga
## → floor_box; the floor's Liga tier for the show_bet "floor" payload (achievement ach_duo_floor). → {"boxes",
## "show_bet", "missed": [ids not won], "floor_tier": int, "battles": int, "liga_battles": int (of them in the Liga)}.
static func on_floor_end(state: GameState, data: GameData, floor_index: int, rules: Dictionary) -> Dictionary:
	var out: Dictionary = {"boxes": [], "show_bet": [], "missed": [], "floor_tier": 0, "battles": 0, "liga_battles": 0}
	if state == null or state.show == null or state.show.marotten.is_empty():
		return out
	var m: Dictionary = state.show.marotten
	var won: PackedStringArray = JsonUtil.to_str_array(m.get("won", []))
	for id: String in JsonUtil.to_str_array(m.get("active", [])):
		if not won.has(id):
			(out["missed"] as Array).append(id)
	var liga: Dictionary = _liga_record(state)
	var battles: int = JsonUtil.to_int(liga.get("battles", 0))
	var tier: int = 0
	if battles >= LIGA_FLOOR_MIN_BATTLES and JsonUtil.to_int(liga.get("t1", 0)) == battles:
		tier = 2 if JsonUtil.to_int(liga.get("t2", 0)) == battles else 1
	out["floor_tier"] = tier
	out["battles"] = battles
	out["liga_battles"] = JsonUtil.to_int(liga.get("t1", 0))
	if tier >= 1 and liga_enabled(rules) and rewards_on(rules):
		var def: MarotteDef = liga_def(data)
		var box: String = str(def.reward.get("floor_box", "")) if def != null else ""
		if box != "" and data.has_id("lootboxes", box):
			(out["boxes"] as Array).append(box)
		var p: Dictionary = _payload(state, "liga", "floor", _liga_id(data), 0, tier, battles, {})
		p["floor"] = floor_index
		(out["show_bet"] as Array).append(p)
	return out


# --- views (HUD chip, pause tab "Show", results) ---------------------------------------------------------------------

## {"floor", "items": [{"id", "name", "desc", "hits", "goal", "won"}], "liga_tier", "liga_hype_pm",
## "liga_follower_pm", "rewards": bool} — read-only.
static func view(state: GameState, data: GameData, rules: Dictionary) -> Dictionary:
	var items: Array = []
	var m: Dictionary = state.show.marotten if state != null and state.show != null else {}
	var hits: Dictionary = m.get("hits", {}) if m.get("hits", {}) is Dictionary else {}
	var won: PackedStringArray = JsonUtil.to_str_array(m.get("won", []))
	for id: String in JsonUtil.to_str_array(m.get("active", [])):
		if data == null or not data.has_id("marotten", id):
			continue
		var def: MarotteDef = data.marotte(id)
		items.append({"id": id, "name": def.name, "desc": def.desc, "hits": mini(JsonUtil.to_int(hits.get(id, 0)),
			def.goal), "goal": def.goal, "won": won.has(id)})
	var tier: int = liga_tier(state, rules)
	return {"floor": JsonUtil.to_int(m.get("floor", 0)), "items": items, "liga_tier": tier,
		"liga_hype_pm": liga_pm(data, tier, &"hype"), "liga_follower_pm": liga_pm(data, tier, &"follower"),
		"rewards": rewards_on(rules)}


# --- internals ------------------------------------------------------------------------------------------------------

static func _empty_result() -> Dictionary:
	return {"hits": [], "won": [], "hype": 0, "follower_pm": 1000, "boxes": [], "followers": 0, "won_hype": 0,
		"show_bet": [], "liga_tier": 0}


## Every active, not yet won preference of `trigger` whose condition holds: +1 heart (once per call), goal → won.
static func _evaluate(state: GameState, data: GameData, trigger: String, ctx: Dictionary, rules: Dictionary,
		out: Dictionary) -> void:
	var m: Dictionary = state.show.marotten
	if not (m.get("hits", null) is Dictionary):
		m["hits"] = {}
	if not (m.get("won", null) is Array):
		m["won"] = []
	var hits: Dictionary = m["hits"]
	var won: Array = m["won"]
	var paid: bool = rewards_on(rules)
	for id: String in JsonUtil.to_str_array(m.get("active", [])):
		if won.has(id) or not data.has_id("marotten", id):
			continue
		var def: MarotteDef = data.marotte(id)
		if def.trigger != trigger or def.expr == null or not def.expr.eval(ctx, state.show.stats, state.flags):
			continue
		var n: int = JsonUtil.to_int(hits.get(id, 0)) + 1
		hits[id] = n
		(out["hits"] as Array).append(id)
		if paid:
			out["hype"] = int(out["hype"]) + def.reward_int("hit_hype")
			var pm: int = def.reward_int("hit_follower_pm")
			if pm > 0:
				out["follower_pm"] = (int(out["follower_pm"]) * pm + 500) / 1000
		if n < maxi(1, def.goal):
			continue
		won.append(id)
		(out["won"] as Array).append(id)
		_bump(state, "bets_won")
		if not paid:
			continue
		var box: String = str(def.reward.get("won_box", ""))
		if box != "" and data.has_id("lootboxes", box):
			(out["boxes"] as Array).append(box)
		out["followers"] = int(out["followers"]) + def.reward_int("won_followers")
		out["won_hype"] = int(out["won_hype"]) + def.reward_int("won_hype")
		(out["show_bet"] as Array).append(_payload(state, "marotte", "won", id, 0, 0, 0, ctx))


## show_bet payload (06 §4.6; DataValidator.TRIGGER_PAYLOAD_KEYS["show_bet"]).
static func _payload(state: GameState, kind: String, event: String, id: String, tier: int, floor_tier: int,
		battles: int, ctx: Dictionary) -> Dictionary:
	return {"kind": kind, "event": event, "id": id, "tier": tier, "floor_tier": floor_tier, "battles": battles,
		"is_boss": bool(ctx.get("is_boss", false)), "is_floor_boss": bool(ctx.get("is_floor_boss", false)),
		"boss_id": str(ctx.get("boss_id", "")), "party_kos": JsonUtil.to_int(ctx.get("party_kos", 0)),
		"floor": state.floor_run.index if state.floor_run != null else 0}


static func _liga_record(state: GameState) -> Dictionary:
	var m: Dictionary = state.show.marotten
	if not (m.get("liga", null) is Dictionary):
		m["liga"] = {"battles": 0, "t1": 0, "t2": 0}
	return m["liga"]


static func _liga_id(data: GameData) -> String:
	var def: MarotteDef = liga_def(data)
	return def.id if def != null else ""


static func _bump(state: GameState, stat_id: String) -> void:
	state.show.stats[stat_id] = JsonUtil.to_int(state.show.stats.get(stat_id, 0)) + 1


static func _rule_on(rules: Dictionary, key: String) -> bool:
	var v: Variant = rules.get(key, null)
	if v is Dictionary:
		return bool((v as Dictionary).get("enabled", true))
	return true


static func _encounter_type(advantage: int) -> String:
	match advantage:
		BattleSetup.Advantage.PREEMPTIVE:
			return "preemptive"
		BattleSetup.Advantage.AMBUSH:
			return "ambush"
	return "normal"
