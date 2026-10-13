class_name ModLiveSummary extends RefCounted
## The request of one "M.O.D. live" round (06 §5.4, protocol schema 1, package D): a compact, privacy-safe summary of
## the run for services/mod-brain. Pure and static.
##
## Input hygiene (06 §5.9 Nr. 2): NO free text leaves the game — only numbers in ranges, catalog ids (enemies,
## achievements, twists, party members) and enums. Never the player name (lines use {name}; the client fills it in),
## never chat, never account / device data. run_ref is a random pseudonym per run (ModLiveLink).
##
## {"schema": 1, "req_id", "run_ref", "lang": "de",
##  "state": {"floor", "timer_sec", "hype", "viewers_k", "hero", "liga_tier", "party": [{"id", "lvl", "hp_pct"}],
##            "bets": [], "phase"},
##  "events": [{"t": EVENT_KINDS, "id"?, "by"?, "member"?, "level"?}], "recent_line_ids": [...],
##  "allowed_twists_hint": [...], "spice_left_hint", "last_twist_result"}

const SCHEMA: int = 1
const MAX_EVENTS: int = 8
const MAX_RECENT: int = 6
## Event kinds the game reports (ModLiveLink collects them from Events signals).
const EVENT_KINDS: PackedStringArray = ["kill", "boss_defeated", "achievement", "level_up", "stunt", "battle_won",
	"battle_fled", "party_ko", "floor_completed", "chest", "twist_applied", "twist_ended", "timer_warning"]
const KILL_BY: PackedStringArray = ["attack", "skill", "stunt", "item", "other"]
const PHASES: PackedStringArray = ["explore", "battle", "safe_room", "waiting", "done"]


## The round request. events: already compact ({"t", …} ids/ints only — filtered again here), recent_line_ids: ids
## the service gave out (never text), last_twist_result: "" | "applied" | a TwistApplier refusal reason.
static func build(state: GameState, data: GameData, rules: Dictionary, now_tick: int, in_battle: bool,
		events: Array, recent_line_ids: PackedStringArray, req_id: String, run_ref: String,
		last_twist_result: String = "", layout: FloorLayout = null) -> Dictionary:
	var fr: FloorRun = state.floor_run if state != null else null
	var ctx: Dictionary = TwistApplier.context(state, data, rules, now_tick, in_battle, layout)
	var party: Array = []
	for m: PartyMember in state.party:
		if m == null or not data.has_id("party", m.id):
			continue
		var max_hp: int = maxi(1, Progression.total_stats(m, data).values[StatBlock.Stat.HP])
		party.append({"id": m.id, "lvl": m.level, "hp_pct": clampi(m.hp, 0, max_hp) * 100 / max_hp})
	var def: FloorDef = data.floor_def(fr.index) if fr != null else null
	var hype: int = roundi(state.show.hype) if state.show != null else 0
	var viewers: int = ShowModel.viewers_for(def.floor_mult if def != null else 1.0, float(hype),
		state.show.followers if state.show != null else 0)
	var recent: PackedStringArray = recent_line_ids.slice(maxi(0, recent_line_ids.size() - MAX_RECENT))
	return {
		"schema": SCHEMA, "req_id": req_id, "run_ref": run_ref, "lang": "de",
		"state": {
			"floor": fr.index if fr != null else 1,
			"timer_sec": fr.time_left_ticks / TwistApplier.TICKS_PER_SEC if fr != null else 0,
			"hype": clampi(hype, 0, 100),
			"viewers_k": viewers / 1000,
			"hero": str(state.get("hero")) if "hero" in state else "kai",
			"liga_tier": 0,
			"party": party,
			"bets": [],
			"phase": str(ctx.get("phase", "explore")),
		},
		"events": clean_events(events, data),
		"recent_line_ids": Array(recent),
		"allowed_twists_hint": Array(TwistApplier.allowed_now(state, data, rules, now_tick, in_battle, "mod_brain",
			layout)),
		"spice_left_hint": TwistApplier.spice_left(state, rules),
		"last_twist_result": last_twist_result if last_twist_result == "" or last_twist_result == "applied" \
			or TwistApplier.REASONS.has(last_twist_result) else "",
	}


## Only known kinds with catalog ids / small integers survive; the newest MAX_EVENTS.
static func clean_events(events: Array, data: GameData) -> Array:
	var out: Array = []
	for e: Variant in events:
		if not (e is Dictionary):
			continue
		var d: Dictionary = e
		var t: String = str(d.get("t", ""))
		if not EVENT_KINDS.has(t):
			continue
		var c: Dictionary = {"t": t}
		var id: String = str(d.get("id", ""))
		match t:
			"kill", "boss_defeated":
				if id != "" and data.has_id("enemies", id):
					c["id"] = id
				var by: String = str(d.get("by", ""))
				if KILL_BY.has(by):
					c["by"] = by
			"achievement":
				if not data.has_id("achievements", id):
					continue
				c["id"] = id
			"twist_applied", "twist_ended":
				if not data.has_id("twists", id):
					continue
				c["id"] = id
			"timer_warning", "floor_completed":
				c["n"] = clampi(int(d.get("n", 0)), 0, 9999)
		var member: String = str(d.get("member", ""))
		if member != "" and data.has_id("party", member):
			c["member"] = member
		if t == "level_up":
			c["level"] = clampi(int(d.get("level", 1)), 1, 99)
		out.append(c)
	return out.slice(maxi(0, out.size() - MAX_EVENTS))
