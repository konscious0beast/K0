class_name Command extends RefCounted
## Schema check of recorded commands (02_TECH §3.4 "t" types, 05 §10.6). Commands are the "Befehle rein" half of the
## live contract (Brief §6b.2): plain JSON dictionaries; after a JSON round trip every number is a float, so integer
## fields accept integral floats. Shapes recorded by Game: floor {"floor"}, encounter {"enc", "adv", "group", "rt"}
## (R5b part 2b: the real-time block is required — the campaign fights in real time only), lootbox {"box"}, buy
## {"item", "qty", "safe_room"}, sell {"item", "qty"}, equip {"member", "slot", "item"}, use_item {"item", "member"},
## rest {}, event {"id", "choice"}, chest {"id"}, gate {"key"}, room {"cell": [x, y]}, safe_room {"id"},
## safe_room_exit {}, scene {"id"}, flag {"key" ∈ FLAG_KEYS, "value"}, difficulty {"to"}, descend
## {}, gift {"gift"} (external input, cmd id 0), sponsor_window {"op": "dev_open", "sec", "slots"} (QA Sponsor-Fenster,
## SponsorWindows.dev_open, 05 §6.13), hero {"id": "kai" | "mopsula"} (06 §1.7: the controlled character; the choice
## of a new run right after "floor", later switches in a safe room — HeroRules.check), talent {"member", "id"}
## (Talent-Show pick, 06 §2.2), casting {"member", "species", "class"} (06 §3.4), secret {"id": "sec_…"} (06 §2.7:
## Kulissenwand knocked over / Regie-Notiz read — Secrets.check_open), twist {"twist": {"schema": 1, "id", "n", "src",
## "params", "duration", "tick", "req"?, "vote_id"?}} (06 §5.7, external input, cmd id 0; TwistApplier decides whether
## it applies).
## Additional unknown fields are allowed (additive protocol versions, 05 §4.3). The CTB "battle" command left with the
## CTB campaign (R5b part 2b; a log of that kernel is an older version, RunSim.SIM_VERSION).
## Echtzeitkampf (07 §10.1, R1a): the real-time combat types (RtCommand.TYPES: ability_use, target_change, move_sample,
## combat_item, partner_preset, partner_special, auto_attack, autopilot, combat_hint, move_input, combat_speed,
## move_batch) and the "rt" block of "encounter" are checked by RtCommand.validate; R5a replays them (RunSim
## combat branch, Game.replay_log combat loop). loadout {"member", "bar": {"1" … "5": skill id}, "preset": "" |
## RtVocab.RT_PRESETS, "tog": {switch: bool}} (R5a: action bar variants and partner tactic chosen outside a combat;
## the rules are RunRules.loadout_refusal's; slots 1 and 5 carry class abilities of a season, 09 §8.3 / ST1-D).
## Casting (08 §2.3, K0): persona {"v": 1, "talent", "bias": [≤ 3 Strings]} (start, once per run) — ids only; the
## rules are PersonaRules.check's. K1 (CR-33): "talent" is "" (no start talents; any other talent is refused by
## PersonaRules.check; the K0 swap left with the start talents in 09 ST0).
## Staffeln (09 §9.1, ST0): persona v2 {"v": 2, "prof": "" | prf_, "recipe": "" | rcp_, "bias"} (the Vorleben head
## start, 09 §8.6; v1 stays readable for old logs), talent v2 {"v": 2, "member", "row", "id"} (a row of the talent
## tree; without "v" the 06-B pick), season {"v": 1, "op": "start", "def", "format", "tempo", "mode", "number",
## "day0_utc", "collapse_utc", "cast"} | {"v": 1, "op": "tempo"} | {"v": 1, "op": "pause", "sec", "why"} | {"v": 1,
## "op": "leave"}, clock {"sec"} and away {"sec"} (external inputs: the clock is set from outside, cmd id 0), sleep
## {"tactic"}, prof {"op", "id"}, gather {"node"}, craft {"recipe", "n"}, cast {"op", "who", "item"?}; the rules are
## RunRules.season_refusal's (every one needs state.season != null, ST0 refuses them all). Stempelduell (10 §6.8,
## ST0 stub): sd {"v": 1, "op": "start", "opp", "deck", "rh"} | {"v": 1, "op": "end", "moves", "res"} — refused with
## sd_unavailable until SD3.

const TYPES: PackedStringArray = ["floor", "encounter", "lootbox", "buy", "sell", "equip", "use_item", "rest",
	"event", "chest", "gate", "room", "safe_room", "safe_room_exit", "scene", "flag", "difficulty", "descend", "gift",
	"sponsor_window",
	"hero", "talent", "casting", "secret",   # 06 packages A (hero, secret) and B (talent, casting)
	"twist",                                 # 06-D (external input like "gift")
	# Echtzeitkampf (07, R1a, §10.1): == RtCommand.TYPES — schema in RtCommand.validate
	"ability_use", "target_change", "move_sample", "combat_item", "partner_preset", "partner_special", "auto_attack",
	"autopilot", "combat_hint", "move_input", "combat_speed", "move_batch",
	"loadout",                               # Echtzeitkampf (07 §4.1, §5.2; R5a): variants + partner tactic
	"persona",                               # Casting (08, K0): bias (v1) / head start + bias (v2, 09 ST0)
	# --- Staffeln (09, ST0): the season commands (09 §9.1) and the Stempelduell stub (10 §6.8) ---
	"season", "clock", "away", "sleep", "prof", "gather", "craft", "cast",
	"sd"]
const SPONSOR_WINDOW_OPS: PackedStringArray = ["dev_open"]
## Inputs from outside the player (cmd id 0, 05 §10.6): viewer gifts, M.O.D. twists (06-D) and the season clock
## (09 §9.1, Brief §6b Nr. 4: the clock is set from outside — clock, away).
const EXTERNAL: PackedStringArray = ["gift", "twist", "clock", "away"]
const EQUIP_SLOTS: PackedStringArray = ["weapon", "armor", "accessory"]
const DIFFICULTIES: PackedStringArray = ["prime", "vorabend"]
## Flag keys a player command may set (Game.set_flag: only the intro). Every other flag is a reaction of the core
## (scene_*, defeated_*, title_*, mop_pep_talk, "live" — the gift counters) and never a recorded write (05 §11.4).
const FLAG_KEYS: PackedStringArray = ["intro_seen"]
const ADVANTAGE_MAX: int = 2           # BattleSetup.Advantage NORMAL 0 / PREEMPTIVE 1 / AMBUSH 2
const PERSONA_VERSION: int = 2         # Casting (08 §2.3, K0; v2 since 09 ST0) == PersonaRules.VERSION
const PERSONA_MAX_BIAS: int = 3        # == PersonaRules.MAX_BIAS
# --- Staffeln (09, ST0) ---
const PERSONA_V1: int = 1              # the K0/K1 persona command (old logs)
const TALENT_ROW_VERSION: int = 2      # talent v2: a row of the talent tree (09 §8.4)
const SEASON_VERSION: int = 1
const SEASON_OPS: PackedStringArray = ["start", "tempo", "pause", "leave"]
const SEASON_FORMATS: PackedStringArray = ["6", "12", "18"]   # floors of a season (09 §2.1)
const PAUSE_WHY: PackedStringArray = ["user", "clamp"]       # 09 §2.9: the player's pause | after a clock jump
const PROF_OPS: PackedStringArray = ["learn", "unlearn", "rank", "head"]
const CAST_OPS: PackedStringArray = ["hire", "trade", "help"]
const SD_VERSION: int = 1              # the "sd" command of 10 §6.8
const SD_OPS: PackedStringArray = ["start", "end"]

static var _gate_key: RegEx = null


## "" = valid, else a message "<t>: <problem>".
static func validate(d: Dictionary) -> String:
	if not d.has("t") or not (d["t"] is String or d["t"] is StringName):
		return "missing command type 't'"
	var t: String = str(d["t"])
	if not TYPES.has(t):
		return "unknown command type '%s'" % t
	var err: String = _validate_fields(t, d)
	return "" if err == "" else "%s: %s" % [t, err]


static func _validate_fields(t: String, d: Dictionary) -> String:
	match t:
		"floor":
			return _int_min(d, "floor", 1)
		"encounter":
			var e: String = _id(d, "enc")
			if e != "":
				return e
			e = _int_min(d, "adv", 0)
			if e != "":
				return e
			if int(d["adv"]) > ADVANTAGE_MAX:
				return "adv must be 0..%d" % ADVANTAGE_MAX
			if d.has("opener") and (not (d["opener"] is String) or str(d["opener"]) != "bark" \
					or int(d["adv"]) != BattleSetup.Advantage.PREEMPTIVE):
				return "opener must be \"bark\" (only with adv 1)"      # 06 integration: BattleSetup.opener
			if not d.has("rt"):                                        # R5b part 2b: real time only
				return "rt: the real-time block is required"
			var rt_err: String = RtCommand.validate(d)              # Echtzeitkampf (07, R1a): the rt block
			if rt_err != "":
				return rt_err
			return _str(d, "group")
		"lootbox":
			return _id(d, "box")
		"buy":
			var e2: String = _first([_id(d, "item"), _int_min(d, "qty", 1)])
			return e2 if e2 != "" else _str(d, "safe_room")
		"sell":
			return _first([_id(d, "item"), _int_min(d, "qty", 1)])
		"equip":
			var e3: String = _first([_id(d, "member"), _str(d, "item")])
			if e3 != "":
				return e3
			if not EQUIP_SLOTS.has(str(d.get("slot", ""))):
				return "slot must be weapon|armor|accessory"
			return ""
		"use_item":
			return _first([_id(d, "item"), _str(d, "member")])
		"rest", "safe_room_exit", "descend":
			return ""
		"event":
			return _first([_id(d, "id"), _id(d, "choice")])
		"chest", "safe_room", "scene":
			return _id(d, "id")
		"gate":
			var e4: String = _id(d, "key")
			if e4 != "":
				return e4
			if _gate_key == null:
				_gate_key = RegEx.create_from_string("^-?\\d+,-?\\d+,[NESW]$")
			return "" if _gate_key.search(str(d["key"])) != null else "key must be \"x,y,N|E|S|W\""
		"room":
			var cell: Variant = d.get("cell", null)
			if not (cell is Array) or (cell as Array).size() != 2 or not _is_int((cell as Array)[0]) \
					or not _is_int((cell as Array)[1]):
				return "cell must be [x, y] (integers)"
			return ""
		"flag":
			var e5: String = _id(d, "key")
			if e5 != "":
				return e5
			if not FLAG_KEYS.has(str(d["key"])):
				return "key '%s' is not a player flag (%s)" % [str(d["key"]), ", ".join(FLAG_KEYS)]
			if not d.has("value"):
				return "missing 'value'"
			var v: Variant = d["value"]
			if not (v is bool or v is String or _is_int(v)):
				return "value must be bool, int or String"
			return ""
		"difficulty":
			return "" if DIFFICULTIES.has(str(d.get("to", ""))) else "to must be prime|vorabend"
		"sponsor_window":
			if not SPONSOR_WINDOW_OPS.has(str(d.get("op", ""))):
				return "op must be one of %s" % ", ".join(SPONSOR_WINDOW_OPS)
			var e6: String = _first([_int_min(d, "sec", 1), _int_min(d, "slots", 1)])
			if e6 != "":
				return e6
			if int(d["sec"]) > SponsorWindows.DEV_MAX_SEC or int(d["slots"]) > SponsorWindows.DEV_MAX_SLOTS:
				return "sec must be <= %d, slots <= %d" % [SponsorWindows.DEV_MAX_SEC, SponsorWindows.DEV_MAX_SLOTS]
			return ""
		"hero":                                    # 06 package A
			var e7: String = _id(d, "id")
			if e7 != "":
				return e7
			return "" if HeroRules.HEROES.has(str(d["id"])) else "id must be one of %s" % ", ".join(HeroRules.HEROES)
		"secret":                                  # 06 package A
			var e8: String = _id(d, "id")
			if e8 != "":
				return e8
			return "" if str(d["id"]).begins_with("sec_") else "id must start with sec_"
		"talent":                            # 06 package B; v2 (09 ST0): a row of the talent tree
			if d.has("v"):
				if not _is_int(d["v"]) or int(d["v"]) != TALENT_ROW_VERSION:
					return "v must be %d (or absent: the 06-B pick)" % TALENT_ROW_VERSION
				return _first([_id(d, "member"), _int_min(d, "row", 1), _id(d, "id")])
			return _first([_id(d, "member"), _id(d, "id")])
		"casting":
			return _first([_id(d, "member"), _id(d, "species"), _id(d, "class")])
		"twist":
			return _twist(d.get("twist", null))
		"persona":                                 # Casting (08, K0)
			return _persona(d)
		"loadout":                                 # Echtzeitkampf (07 §4.1, §5.2; R5a)
			return _loadout(d)
		"ability_use", "target_change", "move_sample", "combat_item", "partner_preset", "partner_special", \
				"auto_attack", "autopilot", "combat_hint", "move_input", "combat_speed", "move_batch":
			return RtCommand.validate(d)                     # Echtzeitkampf (07, R1a): delegated (07 §10.1)
		"gift":
			if not (d.get("gift", null) is Dictionary):
				return "gift must be a Dictionary"
			var reason: String = Gift.validate(d["gift"])
			return "" if reason == "" else "%s (%s)" % [reason, Gift.last_detail]
		# --- Staffeln (09, ST0) ---
		"season":
			return _season(d)
		"clock", "away":
			return _int_min(d, "sec", 1)
		"sleep":
			return "" if RtVocab.RT_PRESETS.has(str(d.get("tactic", ""))) else "tactic must be one of %s" % \
				", ".join(RtVocab.RT_PRESETS)
		"prof":
			if not PROF_OPS.has(str(d.get("op", ""))):
				return "op must be one of %s" % ", ".join(PROF_OPS)
			return _prefixed(d, "id", "prf_")
		"gather":
			return _id(d, "node")
		"craft":
			return _first([_prefixed(d, "recipe", "rcp_"), _int_min(d, "n", 1)])
		"cast":
			if not CAST_OPS.has(str(d.get("op", ""))):
				return "op must be one of %s" % ", ".join(CAST_OPS)
			if d.has("item") and not (d["item"] is String):
				return "item must be a String"
			return _int_min(d, "who", 0)
		"sd":                                      # Stempelduell (10 §6.8): the shape only (SD3 has the rules)
			return _sd(d)
	return ""


# --- Staffeln (09, ST0) -----------------------------------------------------------------------------------------------

## The shape of a "season" command (the rules are RunRules.season_refusal's).
static func _season(d: Dictionary) -> String:
	if not _is_int(d.get("v", null)) or int(d["v"]) != SEASON_VERSION:
		return "v must be %d" % SEASON_VERSION
	match str(d.get("op", "")):
		"start":
			var e: String = _first([_prefixed(d, "def", "ssn_"), _int_min(d, "number", 1), _int_min(d, "day0_utc", 0)])
			if e != "":
				return e
			if not _is_int(d.get("format", null)) or not SEASON_FORMATS.has(str(int(d["format"]))):
				return "format must be 6, 12 or 18"
			if not SeasonState.TEMPOS.has(str(d.get("tempo", ""))):
				return "tempo must be one of %s" % ", ".join(SeasonState.TEMPOS)
			if not SeasonState.MODES.has(str(d.get("mode", ""))):
				return "mode must be one of %s" % ", ".join(SeasonState.MODES)
			var times: Variant = d.get("collapse_utc", null)
			if not (times is Array) or (times as Array).size() != int(d["format"]):
				return "collapse_utc must hold one time per floor"
			var last: int = int(d["day0_utc"])
			for t: Variant in (times as Array):
				if not _is_int(t) or int(t) <= last:
					return "collapse_utc must be ascending integers after day0_utc"
				last = int(t)
			return "" if d.get("cast", null) is Dictionary else "cast must be a Dictionary"
		"tempo", "leave":
			return ""
		"pause":
			var ep: String = _int_min(d, "sec", 1)
			if ep != "":
				return ep
			return "" if PAUSE_WHY.has(str(d.get("why", ""))) else "why must be one of %s" % ", ".join(PAUSE_WHY)
	return "op must be one of %s" % ", ".join(SEASON_OPS)


## The shape of the "sd" command stub (10 §6.8; SdRules decides from SD3 on).
static func _sd(d: Dictionary) -> String:
	if not _is_int(d.get("v", null)) or int(d["v"]) != SD_VERSION:
		return "v must be %d" % SD_VERSION
	match str(d.get("op", "")):
		"start":
			var deck: Variant = d.get("deck", null)
			if not (deck is Array):
				return "deck must be an array of card ids"
			for c: Variant in (deck as Array):
				if not (c is String) or str(c) == "":
					return "deck must contain non-empty Strings"
			return _first([_id(d, "opp"), _str(d, "rh")])
		"end":
			if not (d.get("moves", null) is Array):
				return "moves must be an array"
			return _id(d, "res")
	return "op must be one of %s" % ", ".join(SD_OPS)


## "" or why d[key] is not a non-empty String starting with `prefix`.
static func _prefixed(d: Dictionary, key: String, prefix: String) -> String:
	var e: String = _id(d, key)
	if e != "":
		return e
	return "" if str(d[key]).begins_with(prefix) else "%s must start with %s" % [key, prefix]


## 06-D: the shape of a recorded twist (the rules are TwistApplier.validate's).
static func _twist(v: Variant) -> String:
	if not (v is Dictionary):
		return "twist must be a Dictionary"
	var tw: Dictionary = v
	if not _is_int(tw.get("schema", null)) or int(tw["schema"]) != 1:
		return "twist.schema must be 1"
	var e: String = _first([_id(tw, "id"), _int_min(tw, "n", 1), _int_min(tw, "duration", 0), _int_min(tw, "tick", 0)])
	if e != "":
		return "twist." + e
	if not TwistApplier.SOURCES.has(str(tw.get("src", ""))):
		return "twist.src must be one of %s" % ", ".join(TwistApplier.SOURCES)
	if not (tw.get("params", null) is Dictionary):
		return "twist.params must be a Dictionary"
	for k: Variant in (tw["params"] as Dictionary).keys():
		if not _is_int((tw["params"] as Dictionary)[k]):
			return "twist.params.%s must be an integer" % str(k)
	for k: String in ["req", "vote_id"]:
		if tw.has(k) and not (tw[k] is String):
			return "twist.%s must be a String" % k
	return ""


## Casting (08 §2.3, K0): the shape of a persona command (the rules are PersonaRules.check's). v1: "talent" (a
## String, "" since K1); v2 (09 ST0): "prof" and "recipe" ("" or a prf_ / rcp_ id).
static func _persona(d: Dictionary) -> String:
	var v: int = int(d["v"]) if _is_int(d.get("v", null)) else -1
	if v != PERSONA_V1 and v != PERSONA_VERSION:
		return "v must be %d or %d" % [PERSONA_V1, PERSONA_VERSION]
	var e: String = _str(d, "talent") if v == PERSONA_V1 else _first([_str(d, "prof"), _str(d, "recipe")])
	if e != "":
		return e
	if v == PERSONA_VERSION:
		for pair: Array in [["prof", "prf_"], ["recipe", "rcp_"]]:
			if str(d[str(pair[0])]) != "" and not str(d[str(pair[0])]).begins_with(str(pair[1])):
				return "%s must be \"\" or start with %s" % pair
	var bias: Variant = d.get("bias", null)
	if not (bias is Array) or (bias as Array).size() > PERSONA_MAX_BIAS:
		return "bias must be an array of at most %d marotte ids" % PERSONA_MAX_BIAS
	for b: Variant in (bias as Array):
		if not (b is String) or str(b) == "":
			return "bias must contain non-empty Strings"
	return ""


## Echtzeitkampf (07 §4.1, §5.2; R5a): the shape of a loadout command (the rules are RunRules.loadout_refusal's).
static func _loadout(d: Dictionary) -> String:
	var e: String = _id(d, "member")
	if e != "":
		return e
	var bar: Variant = d.get("bar", null)
	if not (bar is Dictionary):
		return "bar must be a Dictionary (slot \"1\" … \"5\" → skill id)"
	for k: Variant in (bar as Dictionary).keys():
		if not (k is String) or not RunRules.LOADOUT_SLOTS.has(str(k)):   # 09 §8.3 (ST1-D): 1 and 5 for classes
			return "bar keys must be \"1\" … \"5\""
		if not ((bar as Dictionary)[k] is String) or str((bar as Dictionary)[k]) == "":
			return "bar.%s must be a non-empty skill id" % str(k)
	var preset: Variant = d.get("preset", null)
	if not (preset is String) or (str(preset) != "" and not RtVocab.RT_PRESETS.has(str(preset))):
		return "preset must be \"\" or one of %s" % ", ".join(RtVocab.RT_PRESETS)
	var tog: Variant = d.get("tog", null)
	if not (tog is Dictionary):
		return "tog must be a Dictionary"
	for k: Variant in (tog as Dictionary).keys():
		if not RtVocab.RT_TOGGLES.has(str(k)):
			return "tog.%s is not a switch (%s)" % [str(k), ", ".join(RtVocab.RT_TOGGLES)]
		if not ((tog as Dictionary)[k] is bool):
			return "tog.%s must be a bool" % str(k)
	return ""


## True for command types that come from outside the player (cmd id 0).
static func is_external(d: Dictionary) -> bool:
	return EXTERNAL.has(str(d.get("t", "")))


static func _id(d: Dictionary, key: String) -> String:
	var v: Variant = d.get(key, null)
	if not (v is String or v is StringName) or str(v) == "":
		return "%s must be a non-empty String" % key
	return ""


static func _str(d: Dictionary, key: String) -> String:
	var v: Variant = d.get(key, null)
	if not (v is String or v is StringName):
		return "%s must be a String" % key
	return ""


static func _int_min(d: Dictionary, key: String, lo: int) -> String:
	var v: Variant = d.get(key, null)
	if not _is_int(v) or int(v) < lo:
		return "%s must be an integer >= %d" % [key, lo]
	return ""


static func _first(errors: Array) -> String:
	for e: Variant in errors:
		if str(e) != "":
			return str(e)
	return ""


static func _is_int(v: Variant) -> bool:
	if typeof(v) == TYPE_INT:
		return true
	return typeof(v) == TYPE_FLOAT and is_finite(float(v)) and float(v) == floorf(float(v))
