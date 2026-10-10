class_name TwistApplier extends RefCounted
## M.O.D.'s "Twists" (06 §5.6/§5.7, package D): whitelisted, parameter-bounded interventions from the catalog
## data/twists.json — chosen by the offline Regie (RegieDirector), the AI admin (mod-brain, "M.O.D. live"), viewer votes
## (S2), fixed event schedules or QA (F6). Whoever proposes, THIS class decides: validate() is the one legality check,
## apply() the one state change. Game.apply_twist records an applied twist as the external command
## {"t": "twist", "twist": {"schema", "id", "n", "src", "params", "duration", "tick", "req"?, "vote_id"?}} (cmd id 0),
## Game.replay_log / RunSim.apply re-apply it at its `tick` — replays stay hash-identical. "The AI chooses WHAT, never
## the outcome": randomness (rat rain zone) comes from SeedUtil.derive(floor_run.loot_seed, "twist", n).
##
## Pure and static (no autoloads, no SceneTree, integers only). State: GameState.flags["live"]["twist"] (hashed, saved),
## created by the first applied twist / Regie decision only — runs without twists keep their state hash:
##   {"n": twists applied in the run, "floor": floor index of the counters, "floor_count" / "floor_spicy" /
##    "floor_regie": gameplay twists / spicy ones / Regie ones on this floor, "once": once_per_floor ids used,
##    "end_at": floor_run.stats.time_used_ticks when the last gameplay twist ended (-1 = none on this floor),
##    "active": [{"id", "n", "src", "params", "unit", "left", "visiting", "given"}]}
## Durations: "sec" count EXPLORATION ticks (RunSim step 6, tick()), "battles" count finished battles
## (on_battle_end, from BattleBridge.apply_result), "visits" count safe-room visits (on_safe_room_enter/_exit, from
## RunRules), "run" never ends, "none" = instant (applied and over). A floor change ends every twist but "run" ones.
##
## The refusal rules are a pure function over a small context (refusal_for) so that the mod-brain service checks
## proposals with the very same rules (tests/fixtures/live/twist_cases.json is run by GDScript and pytest).

const STATE_KEY: String = "twist"                # GameState.flags["live"][STATE_KEY]
## The replay buffer: GameState.flags[BUFFER_KEY] (buffer / buffered / take_due; saved, not hashed — StateHash).
const BUFFER_KEY: String = "twist_buffer"
const SCHEMA: int = 1
const TICKS_PER_SEC: int = 30                    # == RunSim.TICKS_PER_SEC
const SCOPES: PackedStringArray = ["explore", "instant", "battle", "safe_room", "presentation", "room", "boss"]
const SPICES: PackedStringArray = ["helpful", "neutral", "spicy", "none"]
const UNITS: PackedStringArray = ["sec", "battles", "visits", "run", "none"]
const SOURCES: PackedStringArray = ["regie", "mod_brain", "vote", "schedule", "dev"]
## Hard bounds per parameter: the data may narrow them, never widen them (DataValidator: validators/twists.gd).
const PARAM_BOUNDS: Dictionary = {
	"enemy_sight_pm": [300, 1000], "enemy_hear_pm": [300, 1000], "credits_pm": [1000, 2000], "credits_cap": [0, 500],
	"seconds": [0, 120], "pct": [0, 50], "hype_gain_pm": [1000, 1500], "lines": [1, 3], "sweet": [0, 1],
	"costume": [0, 3], "elite_pm": [1000, 1500], "reward_pm": [1000, 2000], "extra_enemies": [0, 1], "gifts": [1, 2],
	"aggressive": [0, 1], "hit_mult": [1, 2],
}
## Hard bounds per duration unit ([min, max] of duration.min / duration.max).
const DURATION_BOUNDS: Dictionary = {"sec": [1, 300], "battles": [1, 3], "visits": [1, 2], "run": [0, 0],
	"none": [0, 0]}
## Twists with an effect in this build (slice: true is only valid for these).
const IMPLEMENTED: PackedStringArray = ["tw_lights_out", "tw_quiet_please", "tw_fog_of_fame", "tw_confetti_gravity",
	"tw_double_credits", "tw_overtime", "tw_happy_hour", "tw_rat_rain", "tw_party_hats", "tw_mopsula_moderates",
	"tw_mopsula_monologue"]
## Refusal reasons of validate() / refusal_for() (06 §5.7 + sequence_mismatch, no_target).
const REASONS: PackedStringArray = ["unknown_twist", "not_in_slice", "source_not_allowed", "league_pur",
	"floor_too_low", "params_out_of_range", "sequence_mismatch", "tick_mismatch", "wrong_phase", "busy",
	"once_per_floor", "cooldown", "floor_cap", "spice_budget", "party_weak", "timer_low", "no_target"]
## Effect key → [twist id, parameter] (effect_pm); "*" = fixed 1000 while active.
const EFFECTS: Dictionary = {
	"enemy_sight_pm": [["tw_lights_out", "enemy_sight_pm"]],
	"enemy_hear_pm": [["tw_quiet_please", "enemy_hear_pm"]],
	"credits_pm": [["tw_double_credits", "credits_pm"]],
	"hype_gain_pm": [["tw_party_hats", "hype_gain_pm"]],
	"hype_decay_pause": [["tw_fog_of_fame", "*"], ["tw_confetti_gravity", "*"]],
	"mod_voice_mopsula": [["tw_mopsula_moderates", "*"]],
}
## Campaign / offline rules (rules.twists of an event is merged over these; 05 §10.1).
const DEFAULT_RULES: Dictionary = {
	"enabled": true,
	"min_floor": 2,                  # 06 §0.6: Regie-Twists from floor 2 — enforced for every source
	"sources": ["regie", "mod_brain", "vote", "schedule", "dev"],
	"dev_any_floor": true,           # QA (F6) may test on floor 1; live events switch it off
	"max_per_floor": 4,
	"max_spicy_per_floor": 1,
	"gap_sec": 90,                   # exploration seconds between the end of one gameplay twist and the next
	"spicy_min_party_hp_pct": 50,
	"spicy_min_timer_sec": 180,
	"regie": {"enabled": true, "every_sec": 120, "chance_pm": 350, "max_per_floor": 3, "low_timer_sec": 180,
		"weak_party_hp_pct": 50},
	"schedule": [],
}
## Event runs differ from the campaign: no Regie, no AI twists — a fixed schedule for everyone (06 §5.7).
const EVENT_OVERRIDES: Dictionary = {"sources": ["schedule", "dev"], "regie": {"enabled": false}}


# --- rules ------------------------------------------------------------------------------------------------------------

## The effective twist rules of a run: DEFAULT_RULES (campaign: rules {} or only "twists"), event runs (any other
## rules key, e.g. leagues / mode) with EVENT_OVERRIDES, then rules.twists merged over them key by key.
static func rules_of(rules: Dictionary) -> Dictionary:
	var out: Dictionary = DEFAULT_RULES.duplicate(true)
	if not rules.is_empty() and not (rules.size() == 1 and rules.has("twists")):
		_merge(out, EVENT_OVERRIDES)
	var src: Variant = rules.get("twists", null)
	if src is Dictionary:
		_merge(out, src)
	return out


## Problems of an event's rules.twists (EventDef.validate): known keys, types, sources ⊆ SOURCES, schedule entries
## {tick >= 1, id, params?}. Ids are checked against the catalog by validate_schedule (needs GameData).
static func validate_rules(cfg: Variant) -> PackedStringArray:
	var out: PackedStringArray = []
	if cfg == null:
		return out
	if not (cfg is Dictionary):
		out.append("rules.twists must be a Dictionary")
		return out
	for k: Variant in (cfg as Dictionary).keys():
		if not DEFAULT_RULES.has(str(k)):
			out.append("rules.twists: unknown key '%s'" % str(k))
	var m: Dictionary = rules_of({"twists": cfg})
	for key: String in ["min_floor", "max_per_floor", "max_spicy_per_floor", "gap_sec", "spicy_min_party_hp_pct",
			"spicy_min_timer_sec"]:
		if not _is_int(m.get(key, null)) or int(m[key]) < 0:
			out.append("rules.twists.%s must be an integer >= 0" % key)
	for key: String in ["enabled", "dev_any_floor"]:
		if not (m.get(key, null) is bool):
			out.append("rules.twists.%s must be a bool" % key)
	var srcs: Variant = m.get("sources", [])
	if not (srcs is Array):
		out.append("rules.twists.sources must be an Array")
	else:
		for s: Variant in (srcs as Array):
			if not SOURCES.has(str(s)):
				out.append("rules.twists.sources: unknown source '%s'" % str(s))
	if not (m.get("regie", null) is Dictionary):
		out.append("rules.twists.regie must be a Dictionary")
	var sch: Variant = m.get("schedule", [])
	if not (sch is Array):
		out.append("rules.twists.schedule must be an Array")
	else:
		for i in (sch as Array).size():
			var e: Variant = (sch as Array)[i]
			if not (e is Dictionary) or not _is_int((e as Dictionary).get("tick", null)) \
					or int((e as Dictionary)["tick"]) < 1 or str((e as Dictionary).get("id", "")) == "":
				out.append("rules.twists.schedule[%d] must be {tick >= 1, id, params?}" % i)
	return out


# --- the check --------------------------------------------------------------------------------------------------------

## "" or why `twist` may not be applied now (REASONS order, see refusal_for). `twist` as recorded / proposed:
## {"id", "src", "params"?, "duration"?, "n"?, "tick"?}; missing params / duration mean the defaults. in_battle: a
## battle runs or the floor is finished (Game: in_battle or descend). layout: the floor layout (rat rain needs a stray
## zone).
## Read-only.
static func validate(state: GameState, data: GameData, twist: Dictionary, rules: Dictionary, now_tick: int,
		in_battle: bool, layout: FloorLayout = null) -> String:
	var def: TwistDef = _def(data, str(twist.get("id", "")))
	return refusal_for(def.to_dict() if def != null else {}, twist, context(state, data, rules, now_tick, in_battle,
		layout), rules_of(rules))


## THE refusal rules over plain dictionaries (shared with mod-brain via tests/fixtures/live/twist_cases.json):
## def_d = TwistDef.to_dict() ({} = unknown), twist = proposal, ctx = context(), trules = rules_of().
## Order: unknown_twist, not_in_slice, source_not_allowed (twist source not in def.sources / trules.sources, twists
## disabled, Regie disabled), league_pur (gameplay twist in the Pur-Liga), floor_too_low (floor < min_floor; a "dev"
## twist with dev_any_floor is exempt), params_out_of_range (unknown key, non-integer, outside the def's bounds; also
## the duration), sequence_mismatch (n given and != ctx.next_n), tick_mismatch (tick given and != ctx.now_tick),
## wrong_phase (not exploring with a running floor timer), busy (same twist active, or any gameplay twist active for a
## gameplay one), once_per_floor, cooldown (gap_sec of exploration after the last gameplay twist ended), floor_cap
## (max_per_floor gameplay twists; Regie: regie.max_per_floor), spice_budget, party_weak / timer_low (spicy only:
## party HP average, floor timer), no_target (rat rain without a free stray zone).
static func refusal_for(def_d: Dictionary, twist: Dictionary, ctx: Dictionary, trules: Dictionary) -> String:
	var id: String = str(twist.get("id", ""))
	if def_d.is_empty():
		return "unknown_twist"
	if not bool(def_d.get("slice", false)) or not IMPLEMENTED.has(id):
		return "not_in_slice"
	var src: String = str(twist.get("src", ""))
	var gameplay: bool = bool(def_d.get("gameplay", true))
	var regie: Dictionary = trules.get("regie", {}) if trules.get("regie", {}) is Dictionary else {}
	if not _str_list(def_d.get("sources", [])).has(src) or not _str_list(trules.get("sources", [])).has(src) \
			or not bool(trules.get("enabled", true)) or (src == "regie" and not bool(regie.get("enabled", true))):
		return "source_not_allowed"
	if gameplay and str(ctx.get("league", "")) == "pur":
		return "league_pur"
	if _int(ctx.get("floor", 1)) < _int(trules.get("min_floor", 2)) \
			and not (src == "dev" and bool(trules.get("dev_any_floor", false))):
		return "floor_too_low"
	if not params_ok(def_d, twist):
		return "params_out_of_range"
	if twist.has("n") and _int(twist["n"]) != _int(ctx.get("next_n", 1)):
		return "sequence_mismatch"
	if twist.has("tick") and _int(twist["tick"]) != _int(ctx.get("now_tick", 0)):
		return "tick_mismatch"
	if str(ctx.get("phase", "")) != "explore":
		return "wrong_phase"
	var active: Array = ctx.get("active", []) if ctx.get("active", []) is Array else []
	for a: Variant in active:
		if a is Dictionary and (str((a as Dictionary).get("id", "")) == id
				or (gameplay and bool((a as Dictionary).get("gameplay", false)))):
			return "busy"
	if bool(def_d.get("once_per_floor", false)) and _str_list(ctx.get("once", [])).has(id):
		return "once_per_floor"
	if not gameplay:
		return ""
	var since: int = _int(ctx.get("since_end_sec", -1))
	if since >= 0 and since < _int(trules.get("gap_sec", 90)):
		return "cooldown"
	if _int(ctx.get("floor_count", 0)) >= _int(trules.get("max_per_floor", 4)) \
			or (src == "regie" and _int(ctx.get("floor_regie", 0)) >= _int(regie.get("max_per_floor", 3))):
		return "floor_cap"
	if str(def_d.get("spice", "")) == "spicy":
		if _int(ctx.get("floor_spicy", 0)) >= _int(trules.get("max_spicy_per_floor", 1)):
			return "spice_budget"
		if _int(ctx.get("party_hp_pct", 100)) < _int(trules.get("spicy_min_party_hp_pct", 50)):
			return "party_weak"
		if _int(ctx.get("timer_sec", 0)) < _int(trules.get("spicy_min_timer_sec", 180)):
			return "timer_low"
	if id == "tw_rat_rain" and not bool(ctx.get("stray_zone_free", false)):
		return "no_target"
	return ""


## Parameters and duration of a proposal inside the def's bounds (integers; unknown parameter keys fail).
static func params_ok(def_d: Dictionary, twist: Dictionary) -> bool:
	var bounds: Dictionary = def_d.get("params", {}) if def_d.get("params", {}) is Dictionary else {}
	var p: Variant = twist.get("params", {})
	if p == null:
		p = {}
	if not (p is Dictionary):
		return false
	for k: Variant in (p as Dictionary).keys():
		if not bounds.has(str(k)) or not _in_bounds((p as Dictionary)[k], bounds[str(k)]):
			return false
	if twist.has("duration"):
		var du: Dictionary = def_d.get("duration", {}) if def_d.get("duration", {}) is Dictionary else {}
		if not _in_bounds(twist["duration"], du):
			return false
	return true


## The context of refusal_for for the run now: floor, league, phase (explore | battle | safe_room | waiting | done),
## timer_sec, party_hp_pct (average of hp × 100 / max hp), active [{id, gameplay}], next_n, now_tick, the floor
## counters, since_end_sec (-1 = no gameplay twist ended on this floor), once, stray_zone_free (rat rain).
static func context(state: GameState, data: GameData, rules: Dictionary, now_tick: int, in_battle: bool,
		layout: FloorLayout = null) -> Dictionary:
	var ts: Dictionary = state_of(state)
	var fr: FloorRun = state.floor_run if state != null else null
	var phase: String = "explore"
	if fr == null or fr.time_left_ticks <= 0:
		phase = "done"
	elif in_battle:
		phase = "battle"
	elif fr.location != &"start":
		phase = "safe_room"
	elif not fr.timer_started:
		phase = "waiting"
	var active: Array = []
	for e: Dictionary in _active(ts):
		var def: TwistDef = _def(data, str(e.get("id", "")))
		active.append({"id": str(e.get("id", "")), "gameplay": def != null and def.gameplay})
	var on_floor: bool = fr != null and _int(ts.get("floor", -1)) == fr.index
	var since: int = -1
	if on_floor and _int(ts.get("end_at", -1)) >= 0:
		since = (_int(fr.stats.get("time_used_ticks", 0)) - _int(ts["end_at"])) / TICKS_PER_SEC
	var live: Variant = state.flags.get("live", {}) if state != null else {}
	return {
		"floor": fr.index if fr != null else 1,
		"league": GiftPolicy.run_league(live if live is Dictionary else {}, rules),
		"phase": phase,
		"timer_sec": fr.time_left_ticks / TICKS_PER_SEC if fr != null else 0,
		"party_hp_pct": party_hp_pct(state, data),
		"active": active,
		"next_n": _int(ts.get("n", 0)) + 1,
		"now_tick": now_tick,
		"floor_count": _int(ts.get("floor_count", 0)) if on_floor else 0,
		"floor_spicy": _int(ts.get("floor_spicy", 0)) if on_floor else 0,
		"floor_regie": _int(ts.get("floor_regie", 0)) if on_floor else 0,
		"since_end_sec": since,
		"once": _str_list(ts.get("once", [])) if on_floor else PackedStringArray(),
		"stray_zone_free": not stray_zone(state, layout, 0).is_empty(),
	}


## Ids of the twists `src` could apply right now with their default parameters (sorted) — the Regie's candidates and
## the "allowed_twists_hint" for mod-brain.
static func allowed_now(state: GameState, data: GameData, rules: Dictionary, now_tick: int, in_battle: bool,
		src: String = "regie", layout: FloorLayout = null) -> PackedStringArray:
	var out: PackedStringArray = []
	if state == null or data == null:
		return out
	var ctx: Dictionary = context(state, data, rules, now_tick, in_battle, layout)
	var tr: Dictionary = rules_of(rules)
	for def: TwistDef in data.all_twists():
		if refusal_for(def.to_dict(), {"id": def.id, "src": src}, ctx, tr) == "":
			out.append(def.id)
	return out


## Spicy twists still allowed on this floor (the "spice_left_hint" for mod-brain).
static func spice_left(state: GameState, rules: Dictionary) -> int:
	var ts: Dictionary = state_of(state)
	var fr: FloorRun = state.floor_run if state != null else null
	var used: int = _int(ts.get("floor_spicy", 0)) if fr != null and _int(ts.get("floor", -1)) == fr.index else 0
	return maxi(0, _int(rules_of(rules).get("max_spicy_per_floor", 1)) - used)


## The recorded form of a proposal: {"schema", "id", "n" (next), "src", "params" (defaults ← given), "duration"
## (given or default), "tick" (now_tick)} + "req" / "vote_id" when given as Strings. Values the proposer set are kept
## as they are (validate refuses bad ones).
static func complete(state: GameState, data: GameData, twist: Dictionary, now_tick: int) -> Dictionary:
	var def: TwistDef = _def(data, str(twist.get("id", "")))
	var params: Dictionary = def.default_params() if def != null else {}
	var given: Variant = twist.get("params", {})
	if given is Dictionary:
		for k: Variant in (given as Dictionary).keys():
			var v: Variant = (given as Dictionary)[k]
			params[str(k)] = int(v) if _is_int(v) else v
	var duration: Variant = _int(def.duration.get("default", 0)) if def != null else 0
	if twist.has("duration"):
		duration = int(twist["duration"]) if _is_int(twist["duration"]) else twist["duration"]
	var out: Dictionary = {"schema": SCHEMA, "id": str(twist.get("id", "")),
		"n": _int(twist["n"]) if twist.has("n") else _int(state_of(state).get("n", 0)) + 1,
		"src": str(twist.get("src", "")), "params": params, "duration": duration,
		"tick": _int(twist["tick"]) if twist.has("tick") else now_tick}
	for k: String in ["req", "vote_id"]:
		if twist.get(k, null) is String and str(twist[k]) != "":
			out[k] = str(twist[k])
	return out


# --- state changes --------------------------------------------------------------------------------------------------

## Applies a twist that passed validate() (complete() form). Returns ExploreEvents: TWIST_APPLIED {"twist": view
## entry, "src", "n"} and, for rat rain, STRAY_DUE {"zone", "group_id", "encounter_id"} (the exploration spawns the
## group out of sight like any stray). Instant twists end at once (TWIST_ENDED follows, reason "instant").
static func apply(state: GameState, data: GameData, twist: Dictionary,
		layout: FloorLayout = null) -> Array[ExploreEvent]:
	var out: Array[ExploreEvent] = []
	var def: TwistDef = _def(data, str(twist.get("id", "")))
	var fr: FloorRun = state.floor_run if state != null else null
	if def == null or fr == null:
		return out
	var ts: Dictionary = ensure(state)
	var n: int = _int(ts.get("n", 0)) + 1
	ts["n"] = n
	var params: Dictionary = {}
	var given: Dictionary = twist.get("params", {}) if twist.get("params", {}) is Dictionary else {}
	for k: Variant in def.params.keys():
		params[str(k)] = _int(given.get(k, (def.params[k] as Dictionary).get("default", 0)))
	var src: String = str(twist.get("src", ""))
	if def.gameplay:
		ts["floor_count"] = _int(ts.get("floor_count", 0)) + 1
		if def.spice == "spicy":
			ts["floor_spicy"] = _int(ts.get("floor_spicy", 0)) + 1
	if src == "regie":
		ts["floor_regie"] = _int(ts.get("floor_regie", 0)) + 1
	if def.once_per_floor:
		var once: Array = ts["once"]
		if not once.has(def.id):
			once.append(def.id)
	var dur: int = _int(twist.get("duration", def.duration.get("default", 0)))
	var unit: String = def.unit()
	var entry: Dictionary = {"id": def.id, "n": n, "src": src, "params": params, "unit": unit, "left": 0}
	match unit:
		"sec":
			entry["left"] = maxi(1, dur) * TICKS_PER_SEC
			entry["full"] = entry["left"]
		"battles", "visits":
			entry["left"] = maxi(1, dur)
			if unit == "visits":
				entry["visiting"] = 0
	if def.id == "tw_double_credits":
		entry["given"] = 0
	var tick: int = _int(twist.get("tick", 0))
	out.append(ExploreEvent.make(ExploreEvent.Type.TWIST_APPLIED, tick, {"twist": _view_entry(data, entry, fr),
		"src": src, "n": n}))
	match def.id:
		"tw_overtime":
			fr.time_left_ticks += maxi(0, _int(params.get("seconds", 0))) * TICKS_PER_SEC
		"tw_rat_rain":
			var zone: Dictionary = stray_zone(state, layout, n)
			if not zone.is_empty():
				var group: String = "f%d_s%d" % [fr.index, fr.stray_counter]
				fr.strays[group] = {"zone": str(zone["zone"]), "enc": str(zone["enc"])}
				fr.stray_counter += 1
				out.append(ExploreEvent.make(ExploreEvent.Type.STRAY_DUE, tick, {"zone": str(zone["zone"]),
					"group_id": group, "encounter_id": str(zone["enc"])}))
	if unit == "none":
		if def.gameplay:
			ts["end_at"] = _int(fr.stats.get("time_used_ticks", 0))
		out.append(ExploreEvent.make(ExploreEvent.Type.TWIST_ENDED, tick, {"id": def.id, "n": n, "reason": "instant"}))
	else:
		(ts["active"] as Array).append(entry)
	return out


## One run tick (RunSim step 6): on exploration ticks the "sec" twists count down; at 0 they end (TWIST_ENDED
## {"id", "n", "reason": "time"}). Idle ticks in safe rooms change nothing.
static func tick(state: GameState, data: GameData, explore: bool, now_tick: int = 0) -> Array[ExploreEvent]:
	var out: Array[ExploreEvent] = []
	if not explore:
		return out
	var ts: Dictionary = state_of(state)
	var active: Array[Dictionary] = _active(ts)
	if active.is_empty():
		return out
	var keep: Array = []
	for e: Dictionary in active:
		if str(e.get("unit", "")) == "sec":
			e["left"] = _int(e.get("left", 0)) - 1
			if _int(e["left"]) <= 0:
				_end(state, data, ts, e)
				out.append(ExploreEvent.make(ExploreEvent.Type.TWIST_ENDED, now_tick, {"id": str(e["id"]),
					"n": _int(e.get("n", 0)), "reason": "time"}))
				continue
		keep.append(e)
	ts["active"] = keep
	return out


## A battle ended (BattleBridge.apply_result, every outcome): "battles" twists count down and end at 0.
static func on_battle_end(state: GameState, data: GameData = null) -> void:
	var ts: Dictionary = state_of(state)
	var keep: Array = []
	for e: Dictionary in _active(ts):
		if str(e.get("unit", "")) == "battles":
			e["left"] = _int(e.get("left", 0)) - 1
			if _int(e["left"]) <= 0:
				_end(state, data, ts, e)
				continue
		keep.append(e)
	if not ts.is_empty():
		ts["active"] = keep


## Entering a safe room (RunRules.enter_safe_room): "visits" twists start their visit (happy hour prices apply).
static func on_safe_room_enter(state: GameState) -> void:
	for e: Dictionary in _active(state_of(state)):
		if str(e.get("unit", "")) == "visits":
			e["visiting"] = 1


## Leaving a safe room (RunRules.leave_safe_room): a visit that ran counts down; at 0 the twist ends.
static func on_safe_room_exit(state: GameState, data: GameData = null) -> void:
	var ts: Dictionary = state_of(state)
	var keep: Array = []
	for e: Dictionary in _active(ts):
		if str(e.get("unit", "")) == "visits" and _int(e.get("visiting", 0)) == 1:
			e["visiting"] = 0
			e["left"] = _int(e.get("left", 0)) - 1
			if _int(e["left"]) <= 0:
				_end(state, data, ts, e)
				continue
		keep.append(e)
	if not ts.is_empty():
		ts["active"] = keep


## Floor start (RunRules.start_floor): every twist but "run" ones ends, the floor counters restart.
static func on_floor(state: GameState, floor_index: int) -> void:
	var ts: Dictionary = state_of(state)
	if ts.is_empty():
		return
	var keep: Array = []
	for e: Dictionary in _active(ts):
		if str(e.get("unit", "")) == "run":
			keep.append(e)
	ts["active"] = keep
	ts["floor"] = floor_index
	ts["floor_count"] = 0
	ts["floor_spicy"] = 0
	ts["floor_regie"] = 0
	ts["once"] = []
	ts["end_at"] = -1


## The effect of the active twists on `key` (EFFECTS; 1000 = neutral factor): enemy_sight_pm / enemy_hear_pm (scene
## perception), credits_pm, hype_gain_pm (Show, battles), hype_decay_pause / mod_voice_mopsula (1000 = on),
## price_pm (happy hour during its safe-room visit: 1000 − pct × 10). default_pm when no twist affects it.
static func effect_pm(state: GameState, key: String, default_pm: int) -> int:
	var active: Array[Dictionary] = _active(state_of(state))
	if active.is_empty():
		return default_pm
	if key == "price_pm":
		for e: Dictionary in active:
			if str(e.get("id", "")) == "tw_happy_hour" and _int(e.get("visiting", 0)) == 1:
				return clampi(1000 - _int((e.get("params", {}) as Dictionary).get("pct", 0)) * 10, 500, 1000)
		return default_pm
	var srcs: Array = EFFECTS.get(key, [])
	for e: Dictionary in active:
		for s: Variant in srcs:
			if str(e.get("id", "")) == str((s as Array)[0]):
				var param: String = str((s as Array)[1])
				return 1000 if param == "*" else _int((e.get("params", {}) as Dictionary).get(param, default_pm))
	return default_pm


## Extra credits of an active tw_double_credits for `base` credits (battle victory, chest): base × (credits_pm −
## 1000) / 1000, capped by credits_cap minus what this twist already gave; booked into the twist ("given"). 0 = none.
static func take_bonus_credits(state: GameState, base: int) -> int:
	if base <= 0:
		return 0
	for e: Dictionary in _active(state_of(state)):
		if str(e.get("id", "")) != "tw_double_credits":
			continue
		var p: Dictionary = e.get("params", {})
		var room: int = maxi(0, _int(p.get("credits_cap", 0)) - _int(e.get("given", 0)))
		var extra: int = mini(room, base * maxi(0, _int(p.get("credits_pm", 1000)) - 1000) / 1000)
		e["given"] = _int(e.get("given", 0)) + extra
		return extra
	return 0


## Rat rain target: a spawner zone of the layout without a living stray, picked with SeedUtil.derive(loot_seed,
## "twist", n) → {"zone", "enc"} ({} = none). n = 0: only "is there one".
static func stray_zone(state: GameState, layout: FloorLayout, n: int) -> Dictionary:
	var fr: FloorRun = state.floor_run if state != null else null
	if fr == null or layout == null:
		return {}
	var free: Array[Dictionary] = []
	for sp: Dictionary in layout.spawners:
		var zone: String = str(sp.get("zone", ""))
		var pool: PackedStringArray = JsonUtil.to_str_array(sp.get("pool", []))
		if zone == "" or pool.is_empty() or _zone_has_stray(fr, zone):
			continue
		free.append({"zone": zone, "pool": pool})
	if free.is_empty():
		return {}
	if n <= 0:
		return {"zone": str(free[0]["zone"]), "enc": (free[0]["pool"] as PackedStringArray)[0]}
	var rng: RandomNumberGenerator = SeedUtil.make_rng(SeedUtil.derive(fr.loot_seed, "twist", n))
	var pick: Dictionary = free[rng.randi_range(0, free.size() - 1)]
	var pool2: PackedStringArray = pick["pool"]
	return {"zone": str(pick["zone"]), "enc": pool2[rng.randi_range(0, pool2.size() - 1)]}


# --- views ------------------------------------------------------------------------------------------------------------

## The twist state of the run ({} = no twist so far).
static func state_of(state: GameState) -> Dictionary:
	if state == null:
		return {}
	var live: Variant = state.flags.get("live", {})
	if not (live is Dictionary):
		return {}
	var ts: Variant = (live as Dictionary).get(STATE_KEY, null)
	return ts if ts is Dictionary else {}


## Creates the twist state if missing (first twist / Regie decision) and returns it.
static func ensure(state: GameState) -> Dictionary:
	var ts: Dictionary = state_of(state)
	if not ts.is_empty():
		return ts
	if not (state.flags.get("live", null) is Dictionary):
		state.flags["live"] = {}
	var fi: int = state.floor_run.index if state.floor_run != null else 1
	ts = {"n": 0, "floor": fi, "floor_count": 0, "floor_spicy": 0, "floor_regie": 0, "once": [], "end_at": -1,
		"active": []}
	(state.flags["live"] as Dictionary)[STATE_KEY] = ts
	return ts


## The replay buffer (06 §5.7): a twist command a log sorts in AHEAD of its tick (an external input delivered early;
## RunSim.apply / Game.replay_log, never the live entry) waits in GameState.flags[BUFFER_KEY] as
## {"wait": run ticks until due, "twist": complete form}. It is part of the state, so a save made while a twist waits
## keeps it and the next log segment (from_save: its clock starts at 0 again — hence a countdown, not an absolute tick)
## applies it after the same number of ticks; StateHash leaves it out (input not yet applied — an early twist keeps
## every checkpoint hash). `wait` >= 1.
static func buffer(state: GameState, twist: Dictionary, wait: int) -> void:
	if state == null:
		return
	var b: Variant = state.flags.get(BUFFER_KEY, null)
	var list: Array = (b as Array).duplicate(true) if b is Array else []
	list.append({"wait": maxi(1, wait), "twist": twist.duplicate(true)})
	state.flags[BUFFER_KEY] = list


## The waiting twists (complete form, in buffer order).
static func buffered(state: GameState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var b: Variant = state.flags.get(BUFFER_KEY, null) if state != null else null
	if b is Array:
		for e: Variant in (b as Array):
			if e is Dictionary and (e as Dictionary).get("twist", null) is Dictionary:
				out.append(CanonicalJson.normalize((e as Dictionary)["twist"]) as Dictionary)
	return out


## One run tick of the buffer (RunSim.step, after the tick's evaluation): every wait − 1; the twists due now come back
## in buffer order (complete form) and leave the buffer; an empty buffer removes the key (runs without one keep their
## saves unchanged).
static func take_due(state: GameState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if state == null or not (state.flags.get(BUFFER_KEY, null) is Array):
		return out
	var keep: Array = []
	for e: Variant in (state.flags[BUFFER_KEY] as Array):
		if not (e is Dictionary) or not ((e as Dictionary).get("twist", null) is Dictionary):
			continue
		var w: int = _int((e as Dictionary).get("wait", 1)) - 1
		if w <= 0:
			out.append(CanonicalJson.normalize((e as Dictionary)["twist"]) as Dictionary)
		else:
			keep.append({"wait": w, "twist": (e as Dictionary)["twist"]})
	if keep.is_empty():
		state.flags.erase(BUFFER_KEY)
	else:
		state.flags[BUFFER_KEY] = keep
	return out


## Ids of the active twists (sorted).
static func active_ids(state: GameState) -> PackedStringArray:
	var out: PackedStringArray = []
	for e: Dictionary in _active(state_of(state)):
		out.append(str(e.get("id", "")))
	out.sort()
	return out


## UI view of the active twists: [{"id", "name", "n", "src", "unit", "gameplay", "left" (seconds | battles | visits),
## "left_pm" (remaining share, 1000 = full), "params"}].
static func view(state: GameState, data: GameData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var fr: FloorRun = state.floor_run if state != null else null
	for e: Dictionary in _active(state_of(state)):
		out.append(_view_entry(data, e, fr))
	return out


## Average party HP in percent (hp × 100 / max hp per member, integer; 100 without party).
static func party_hp_pct(state: GameState, data: GameData) -> int:
	if state == null or data == null:
		return 100
	var sum: int = 0
	var n: int = 0
	for m: PartyMember in state.party:
		if m == null or not data.has_id("party", m.id):
			continue
		var max_hp: int = maxi(1, Progression.total_stats(m, data).values[StatBlock.Stat.HP])
		sum += clampi(m.hp, 0, max_hp) * 100 / max_hp
		n += 1
	return sum / n if n > 0 else 100


# --- internals --------------------------------------------------------------------------------------------------------

static func _view_entry(data: GameData, e: Dictionary, _fr: FloorRun) -> Dictionary:
	var def: TwistDef = _def(data, str(e.get("id", "")))
	var unit: String = str(e.get("unit", "none"))
	var left: int = _int(e.get("left", 0))
	var total: int = _int(def.duration.get("default", 0)) if def != null else 0
	var left_pm: int = 1000
	if unit == "sec":
		var full: int = maxi(1, _int(e.get("full", 0)) if e.has("full") else total * TICKS_PER_SEC)
		left_pm = clampi(left * 1000 / full, 0, 1000)
		left = (left + TICKS_PER_SEC - 1) / TICKS_PER_SEC
	return {"id": str(e.get("id", "")), "name": def.name if def != null else str(e.get("id", "")),
		"n": _int(e.get("n", 0)), "src": str(e.get("src", "")), "unit": unit,
		"gameplay": def != null and def.gameplay, "left": left, "left_pm": left_pm,
		"params": (e.get("params", {}) as Dictionary).duplicate(true)}


static func _end(state: GameState, data: GameData, ts: Dictionary, e: Dictionary) -> void:
	var def: TwistDef = _def(data, str(e.get("id", "")))
	var gameplay: bool = def.gameplay if def != null else true
	if gameplay and state != null and state.floor_run != null:
		ts["end_at"] = _int(state.floor_run.stats.get("time_used_ticks", 0))


static func _zone_has_stray(fr: FloorRun, zone: String) -> bool:
	for g: Variant in fr.strays.keys():
		var s: Variant = fr.strays[g]
		if s is Dictionary and str((s as Dictionary).get("zone", "")) == zone:
			return true
	return false


static func _active(ts: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var a: Variant = ts.get("active", [])
	if a is Array:
		for e: Variant in (a as Array):
			if e is Dictionary:
				out.append(e)
	return out


static func _def(data: GameData, id: String) -> TwistDef:
	if data == null or id == "" or not data.has_id("twists", id):
		return null
	return data.twist(id)


static func _in_bounds(v: Variant, b: Variant) -> bool:
	if not _is_int(v) or not (b is Dictionary):
		return false
	return int(v) >= _int((b as Dictionary).get("min", 0)) and int(v) <= _int((b as Dictionary).get("max", 0))


static func _str_list(v: Variant) -> PackedStringArray:
	return JsonUtil.to_str_array(v) if (v is Array or v is PackedStringArray) else PackedStringArray()


static func _merge(dst: Dictionary, src: Dictionary) -> void:
	for k: Variant in src.keys():
		var key: String = str(k)
		if dst.get(key, null) is Dictionary and src[k] is Dictionary:
			_merge(dst[key], src[k])
		else:
			dst[key] = src[k].duplicate(true) if (src[k] is Dictionary or src[k] is Array) else src[k]


static func _is_int(v: Variant) -> bool:
	if typeof(v) == TYPE_INT:
		return true
	return typeof(v) == TYPE_FLOAT and is_finite(float(v)) and float(v) == floorf(float(v))


static func _int(v: Variant) -> int:
	if typeof(v) == TYPE_INT:
		return v
	if typeof(v) == TYPE_FLOAT and is_finite(float(v)):
		return int(v)
	return 0
