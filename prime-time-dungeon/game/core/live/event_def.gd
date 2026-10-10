class_name EventDef extends RefCounted
## Live/offline event incl. quest and windows (05 §1.2, §10.1, Brief §6b.5). Fields mirror data/events.json.
## Time checks take the time as a parameter (`now_unix`, seconds UTC) — no clock in core/ (Brief §6b.1); the
## presentation passes Time.get_unix_time_from_system(), tests pass fixed values. Window times are parsed from
## ISO-8601 UTC ("2026-11-07T19:00:00Z", optional fraction, "Z" or "+00:00") with pure integer calendar math.

const KINDS: PackedStringArray = ["offline", "daily", "weekly", "live_show", "special"]
const LATE_ENTRY: PackedStringArray = ["until_last_entry", "first_10_min", "none"]
const SEED_TYPES: PackedStringArray = ["fixed", "daily_derived", "commit_reveal"]
const MODES: PackedStringArray = ["solo", "coop"]
const LEAGUES: PackedStringArray = ["show", "pur"]
const TIMER_MODES: PackedStringArray = ["explore_only", "realtime"]
const EVENT_GIFT_SOURCES: PackedStringArray = ["fan", "shop", "dev"]   # 05 §10.1 rules.gifts.sources
const KEYS: PackedStringArray = ["id", "kind", "name_key", "floor", "windows", "late_entry", "seed_policy", "quest",
	"rules", "votes", "scoring", "rewards"]
const WINDOW_KEYS: PackedStringArray = ["id", "open_at", "close_at", "region"]
const S0_PARTY_PRESETS: PackedStringArray = ["new_game"]
const DEFAULT_MAX_RUN_WALL_SEC: int = 2700    # 45 min (05 §1.2)
const CLOSING_SEC: int = 300                  # "closing" 5 min before close_at
const FIRST_MINUTES_SEC: int = 600            # late_entry first_10_min / none: entry only in the first 10 min

var id: String = ""
var kind: String = "offline"
var name_key: String = ""
var floor_index: int = 1          # JSON key "floor" (floor() is a builtin, §13.1)
var windows: Array[Dictionary] = []
var late_entry: String = "until_last_entry"     # 05 §1.2 standard; "none" / "first_10_min" = opt-in
var seed_policy: Dictionary = {}
var quest: Dictionary = {}
var rules: Dictionary = {}
var votes: Dictionary = {}
var scoring: Dictionary = {}
var rewards: Dictionary = {}

var _parse_errors: PackedStringArray = []

static var _id_re: RegEx = null
static var _iso_re: RegEx = null


## Never null: type problems and unknown keys are kept and reported by validate().
static func from_dict(d: Dictionary) -> EventDef:
	var e: EventDef = EventDef.new()
	for k: Variant in d.keys():
		if not KEYS.has(str(k)):
			e._parse_errors.append("unknown key '%s'" % str(k))
	e.id = e._get_str(d, "id", "")
	e.kind = e._get_str(d, "kind", "offline")
	e.name_key = e._get_str(d, "name_key", "")
	var fl: Variant = d.get("floor", 1)
	if _is_int(fl):
		e.floor_index = int(fl)
	else:
		e._parse_errors.append("floor must be an integer")
		e.floor_index = 0
	var ws: Variant = d.get("windows", [])
	if ws is Array:
		for w: Variant in (ws as Array):
			if w is Dictionary:
				e.windows.append(CanonicalJson.normalize(w))
			else:
				e._parse_errors.append("windows entries must be Dictionaries")
	else:
		e._parse_errors.append("windows must be an Array")
	e.late_entry = e._get_str(d, "late_entry", "until_last_entry")
	e.seed_policy = e._get_dict(d, "seed_policy")
	e.quest = e._get_dict(d, "quest")
	e.rules = e._get_dict(d, "rules")
	e.votes = e._get_dict(d, "votes")
	e.scoring = e._get_dict(d, "scoring")
	e.rewards = e._get_dict(d, "rewards")
	return e


## Problems of the definition, [] = valid. With `data`, the event is also checked against the game data: the floor
## exists, and an offline (S0) event's rules.floor_timer_sec — if given — equals FloorDef.timer_seconds (RunSim/Game
## run the floor with the FloorDef timer; the lobby shows rules.floor_timer_sec).
func validate(data: GameData = null) -> PackedStringArray:
	var out: PackedStringArray = _parse_errors.duplicate()
	if _id_re == null:
		_id_re = RegEx.create_from_string("^evt_[a-z0-9_]+$")
	if _id_re.search(id) == null:
		out.append("id '%s' must match evt_[a-z0-9_]+" % id)
	if not KINDS.has(kind):
		out.append("unknown kind '%s'" % kind)
	if floor_index < 1:
		out.append("floor must be >= 1")
	if name_key == "":
		out.append("name_key missing")
	if not LATE_ENTRY.has(late_entry):
		out.append("late_entry must be one of %s" % ", ".join(LATE_ENTRY))
	_validate_windows(out)
	_validate_seed_policy(out)
	out.append_array(QuestTracker.validate_def(quest))
	_validate_rules(out)
	if data != null:
		_validate_against_data(data, out)
	if votes.has("enabled") and not (votes["enabled"] is bool):
		out.append("votes.enabled must be a bool")
	for k: Variant in scoring.keys():
		if not ScoreCalc.DEFAULT_SCORING.has(str(k)):
			out.append("unknown scoring key '%s'" % str(k))
		elif not _is_int(scoring[k]):
			out.append("scoring.%s must be an integer" % str(k))
	if rewards.has("sponsored_runs") and str(rewards["sponsored_runs"]) != "participation_only":
		out.append("rewards.sponsored_runs must be 'participation_only' (05 §1.6)")
	for part: String in ["seed_policy", "quest", "rules", "votes", "scoring", "rewards"]:
		if CanonicalJson.stringify(get(part)) == "" and CanonicalJson.last_error != "":
			out.append("%s is not canonical JSON (integers only): %s" % [part, CanonicalJson.last_error])
	return out


## &"always", &"scheduled", &"open", &"last_entry", &"closing", &"closed"
## No windows → always. Inside a window: closing (≥ close_at − 5 min) > last_entry (≥ last entry time) > open.
## Before a window (incl. between two windows) → scheduled; after the last one → closed.
func window_state(now_unix: int) -> StringName:
	if windows.is_empty():
		return &"always"
	for w: Dictionary in _sorted_windows():
		var open_at: int = int(w["open"])
		var close_at: int = int(w["close"])
		if now_unix < open_at:
			return &"scheduled"
		if now_unix < close_at:
			if now_unix >= close_at - CLOSING_SEC:
				return &"closing"
			if now_unix >= last_entry_at(open_at, close_at):
				return &"last_entry"
			return &"open"
	return &"closed"


func can_start(now_unix: int) -> bool:
	if not validate().is_empty():
		return false
	var s: StringName = window_state(now_unix)
	return s == &"always" or s == &"open"


## Only seed_policy "fixed"; 0 otherwise (the seed of commit-reveal events comes from the server).
func run_seed() -> int:
	if str(seed_policy.get("type", "")) != "fixed" or not _is_int(seed_policy.get("run_seed", null)):
		return 0
	return int(seed_policy["run_seed"])


# --- additions ----------------------------------------------------------------------------------------------------

## Last moment a run may start in a window [open_at, close_at): until_last_entry → close − max_run_wall_sec;
## first_10_min / none → open + 10 min (but never later than the standard).
func last_entry_at(open_at: int, close_at: int) -> int:
	var wall: int = int(rules.get("max_run_wall_sec", DEFAULT_MAX_RUN_WALL_SEC)) if _is_int(
		rules.get("max_run_wall_sec", DEFAULT_MAX_RUN_WALL_SEC)) else DEFAULT_MAX_RUN_WALL_SEC
	var standard: int = close_at - maxi(0, wall)
	if late_entry == "first_10_min" or late_entry == "none":
		return mini(open_at + FIRST_MINUTES_SEC, standard)
	return standard


## SHA-256 over the canonical rules (rules_hash of the commit, 05 §7.3); "" if not canonical.
func rules_hash() -> String:
	return CanonicalJson.sha256_hex(rules)


## Leagues of the event (rules.leagues), ["pur"] if missing.
func leagues() -> PackedStringArray:
	var out: PackedStringArray = []
	var raw: Variant = rules.get("leagues", ["pur"])
	if raw is Array:
		for l: Variant in (raw as Array):
			out.append(str(l))
	return out if not out.is_empty() else PackedStringArray(["pur"])


## Seconds since 1970-01-01T00:00:00Z of an ISO-8601 UTC timestamp; [ok: bool, unix: int].
static func parse_iso_utc(s: String) -> Array:
	if _iso_re == null:
		_iso_re = RegEx.create_from_string(
			"^(\\d{4})-(\\d{2})-(\\d{2})T(\\d{2}):(\\d{2}):(\\d{2})(\\.\\d+)?(Z|\\+00:00|-00:00)$")
	var m: RegExMatch = _iso_re.search(s)
	if m == null:
		return [false, 0]
	var y: int = m.get_string(1).to_int()
	var mo: int = m.get_string(2).to_int()
	var d: int = m.get_string(3).to_int()
	var hh: int = m.get_string(4).to_int()
	var mi: int = m.get_string(5).to_int()
	var ss: int = m.get_string(6).to_int()
	if mo < 1 or mo > 12 or d < 1 or d > _days_in_month(y, mo) or hh > 23 or mi > 59 or ss > 59:
		return [false, 0]
	return [true, _days_from_civil(y, mo, d) * 86400 + hh * 3600 + mi * 60 + ss]


# --- internals ----------------------------------------------------------------------------------------------------

## [{"id", "open", "close"}] of the parseable windows, ascending by open time.
func _sorted_windows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for w: Dictionary in windows:
		var o: Array = parse_iso_utc(str(w.get("open_at", "")))
		var c: Array = parse_iso_utc(str(w.get("close_at", "")))
		if bool(o[0]) and bool(c[0]) and int(c[1]) > int(o[1]):
			out.append({"id": str(w.get("id", "")), "open": int(o[1]), "close": int(c[1])})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["open"]) < int(b["open"]))
	return out


func _validate_windows(out: PackedStringArray) -> void:
	if kind == "offline":
		if not windows.is_empty():
			out.append("offline events have no windows (always open)")
		return
	if windows.is_empty():
		out.append("%s events need at least one window" % kind)
		return
	var ids: Dictionary = {}
	for w: Dictionary in windows:
		var wid: String = str(w.get("id", ""))
		for k: Variant in w.keys():
			if not WINDOW_KEYS.has(str(k)):
				out.append("window '%s': unknown key '%s'" % [wid, str(k)])
		if wid == "" or ids.has(wid):
			out.append("window ids must be unique and non-empty ('%s')" % wid)
		ids[wid] = true
		var o: Array = parse_iso_utc(str(w.get("open_at", "")))
		var c: Array = parse_iso_utc(str(w.get("close_at", "")))
		if not bool(o[0]) or not bool(c[0]):
			out.append("window '%s': open_at/close_at must be ISO-8601 UTC" % wid)
		elif int(c[1]) <= int(o[1]):
			out.append("window '%s': close_at must be after open_at" % wid)
	var sorted: Array[Dictionary] = _sorted_windows()
	for i in range(1, sorted.size()):
		if int(sorted[i]["open"]) < int(sorted[i - 1]["close"]):
			out.append("windows '%s' and '%s' overlap" % [sorted[i - 1]["id"], sorted[i]["id"]])


func _validate_seed_policy(out: PackedStringArray) -> void:
	var t: String = str(seed_policy.get("type", ""))
	if not SEED_TYPES.has(t):
		out.append("seed_policy.type must be one of %s" % ", ".join(SEED_TYPES))
		return
	match t:
		"fixed":
			if kind != "offline":
				out.append("seed_policy fixed is only allowed for offline events")
			if not _is_int(seed_policy.get("run_seed", null)) or int(seed_policy["run_seed"]) < 0:
				out.append("seed_policy fixed needs run_seed: int >= 0")
		"commit_reveal":
			var commits: Variant = seed_policy.get("commits", null)
			if not (commits is Dictionary):
				out.append("seed_policy commit_reveal needs commits per window")
			else:
				for w: Dictionary in windows:
					if not ((commits as Dictionary).get(str(w.get("id", "")), null) is String):
						out.append("seed_policy.commits has no commit for window '%s'" % str(w.get("id", "")))
			if seed_policy.has("commit_version") and not _is_int(seed_policy["commit_version"]):
				out.append("seed_policy.commit_version must be an integer")


func _validate_rules(out: PackedStringArray) -> void:
	if not MODES.has(str(rules.get("mode", ""))):
		out.append("rules.mode must be solo|coop")
	var leagues_v: Variant = rules.get("leagues", null)
	if not (leagues_v is Array) or (leagues_v as Array).is_empty():
		out.append("rules.leagues must be a non-empty Array")
	else:
		for l: Variant in (leagues_v as Array):
			if not LEAGUES.has(str(l)):
				out.append("rules.leagues: unknown league '%s'" % str(l))
		if kind == "offline" and ((leagues_v as Array).size() != 1 or str((leagues_v as Array)[0]) != "pur"):
			out.append("offline events are Pur-Liga only")
	if not TIMER_MODES.has(str(rules.get("timer_mode", ""))):
		out.append("rules.timer_mode must be explore_only|realtime")
	elif kind == "offline" and str(rules["timer_mode"]) != "explore_only":
		out.append("rules.timer_mode: offline events (S0) run explore_only (RunSim has no realtime clock)")
	if not (rules.get("party_preset", null) is String):
		out.append("rules.party_preset must be a String")
	elif kind == "offline" and not S0_PARTY_PRESETS.has(str(rules["party_preset"])):
		out.append("rules.party_preset: S0 supports only %s" % ", ".join(S0_PARTY_PRESETS))
	for k: String in ["floor_timer_sec", "max_run_wall_sec", "turn_timeout_sec"]:
		if rules.has(k) and (not _is_int(rules[k]) or int(rules[k]) < 0):
			out.append("rules.%s must be an integer >= 0" % k)
	var gifts: Variant = rules.get("gifts", {})
	if not (gifts is Dictionary):
		out.append("rules.gifts must be a Dictionary")
	else:
		var g: Dictionary = gifts
		if g.has("enabled") and not (g["enabled"] is bool):
			out.append("rules.gifts.enabled must be a bool")
		if kind == "offline" and bool(g.get("enabled", false)):
			out.append("offline events have no gifts (S0)")
		for k: Variant in g.keys():
			if GiftPolicy.DEFAULT_GIFT_RULES.has(str(k)) and _is_int(GiftPolicy.DEFAULT_GIFT_RULES[str(k)]) \
					and not _is_int(g[k]):
				out.append("rules.gifts.%s must be an integer" % str(k))
		# 05 §10.1: sources ⊆ fan, shop, dev — "bits" is not offered (decision 2026-10-08, L11), "dev" (QA) only offline
		if g.has("sources"):
			if not (g["sources"] is Array):
				out.append("rules.gifts.sources must be an Array")
			else:
				for src: Variant in (g["sources"] as Array):
					if not EVENT_GIFT_SOURCES.has(str(src)):
						out.append("rules.gifts.sources: '%s' is not offered (fan, shop, dev)" % str(src))
					elif str(src) == "dev" and kind != "offline":
						out.append("rules.gifts.sources: 'dev' (QA) only in offline events")
	# Sponsor-Fenster (05 §6.13): schema; QA dev windows only offline (a live event must switch them off explicitly)
	var sw: Variant = rules.get("sponsor_windows", null)
	out.append_array(SponsorWindows.validate_rules(sw))
	if kind != "offline" and not (sw is Dictionary and (sw as Dictionary).get("dev_open", true) is bool
			and not bool((sw as Dictionary)["dev_open"])):
		out.append("rules.sponsor_windows.dev_open must be false for %s events (QA windows are offline only)" % kind)


func _validate_against_data(data: GameData, out: PackedStringArray) -> void:
	var fdef: FloorDef = data.floor_def(floor_index) if floor_index >= 1 else null
	if fdef == null:
		out.append("floor %d does not exist in the game data" % floor_index)
		return
	if kind == "offline" and rules.has("floor_timer_sec") and _is_int(rules["floor_timer_sec"]) \
			and int(rules["floor_timer_sec"]) != fdef.timer_seconds:
		out.append("rules.floor_timer_sec %d != floor %d timer_seconds %d (offline runs use the FloorDef timer)"
			% [int(rules["floor_timer_sec"]), floor_index, fdef.timer_seconds])


func _get_str(d: Dictionary, key: String, default: String) -> String:
	if not d.has(key):
		return default
	if d[key] is String or d[key] is StringName:
		return str(d[key])
	_parse_errors.append("%s must be a String" % key)
	return default


func _get_dict(d: Dictionary, key: String) -> Dictionary:
	var v: Variant = d.get(key, {})
	if v is Dictionary:
		return CanonicalJson.normalize(v)
	_parse_errors.append("%s must be a Dictionary" % key)
	return {}


## Days since 1970-01-01 of a proleptic Gregorian date (H. Hinnant's days_from_civil, integers only).
static func _days_from_civil(y: int, m: int, d: int) -> int:
	var yy: int = y - (1 if m <= 2 else 0)
	var era: int = (yy if yy >= 0 else yy - 399) / 400
	var yoe: int = yy - era * 400
	var mp: int = m - 3 if m > 2 else m + 9
	var doy: int = (153 * mp + 2) / 5 + d - 1
	var doe: int = yoe * 365 + yoe / 4 - yoe / 100 + doy
	return era * 146097 + doe - 719468


static func _days_in_month(y: int, m: int) -> int:
	if m == 2:
		var leap: bool = (y % 4 == 0 and y % 100 != 0) or y % 400 == 0
		return 29 if leap else 28
	return 30 if m in [4, 6, 9, 11] else 31


static func _is_int(v: Variant) -> bool:
	if typeof(v) == TYPE_INT:
		return true
	return typeof(v) == TYPE_FLOAT and is_finite(float(v)) and float(v) == floorf(float(v))
