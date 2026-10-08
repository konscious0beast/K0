extends TestCase
## EventDef / EventCatalog (05 §1.2, §10.1, §11.4): window_state with fixed unix times (before / between / after
## windows, last_entry, closing, always), can_start, ISO-8601 parsing without a clock, validation errors (overlapping
## windows, fixed without seed, unknown quest type, …), the real data/events.json.

const EU_OPEN: int = 1794078000      # 2026-11-07T19:00:00Z
const EU_CLOSE: int = 1794083400     # 2026-11-07T20:30:00Z
const AM_OPEN: int = 1794099600      # 2026-11-08T01:00:00Z
const APAC_CLOSE: int = 1794137400   # 2026-11-08T11:30:00Z


## 05 §10.1 live show example.
func _live() -> Dictionary:
	return {"id": "evt_2026w45_sat", "kind": "live_show", "name_key": "evt_saturday_show_name", "floor": 1,
		"windows": [
			{"id": "eu", "open_at": "2026-11-07T19:00:00Z", "close_at": "2026-11-07T20:30:00Z", "region": "eu"},
			{"id": "am", "open_at": "2026-11-08T01:00:00Z", "close_at": "2026-11-08T02:30:00Z", "region": "us_east"},
			{"id": "apac", "open_at": "2026-11-08T10:00:00Z", "close_at": "2026-11-08T11:30:00Z", "region": "ap_tokyo"}],
		"late_entry": "until_last_entry",
		"seed_policy": {"type": "commit_reveal", "commit_version": 2,
			"commits": {"eu": "3613e6c5…d64a", "am": "…", "apac": "…"}, "tables_hash": "5e2d…07", "rules_hash": "9c41…e2"},
		"quest": {"type": "reach_stairs", "label_key": "quest_reach_stairs", "params": {"floor": 1}},
		"rules": {"mode": "coop", "team_size": [1, 4], "leagues": ["show", "pur"], "timer_mode": "realtime",
			"floor_timer_sec": 2100, "turn_timeout_sec": 20, "coop_join_radius_m": 15, "max_run_wall_sec": 2700,
			"party_preset": "preset_f1_l3", "attempts": {"ranked": 1, "practice": false}, "spectate": {"delay_sec": 30},
			"gifts": {"enabled": true, "sources": ["fan", "bits", "shop"], "load_cap_half": 48, "max_external": 16,
				"max_chests": 8, "max_gold_chests": 2, "min_interval_sec": 45, "sale_close_buffer_sec": 120,
				"max_per_battle": 1, "per_buyer_per_target": 5, "load_weights_half": {"cheer": 0, "gold_per_100": 1,
				"fan_pack": 2, "sponsor_buff": 2, "bronze": 2, "silver": 4, "gold": 8}, "effect_k_pm": 75,
				"chest_min_effect_pm": 500, "ask_timeout_sec": 10, "table_id": "gift_f1"}},
		"votes": {"enabled": true, "interval_sec": 240, "duration_sec": 45, "options": 3, "pool": ["tw_lights_out"]},
		"scoring": {"complete": 10000, "progress_max": 5000, "per_sec_left": 5, "per_follower": 1, "follower_cap": 3000,
			"per_achievement": 100, "per_ko": -150},
		"rewards": {"participation": "badge_sat_show", "quest": "cos_mop_bowtie_prime", "percentile_titles": [1, 10, 50],
			"live_follower_cap": 2000, "sponsored_runs": "participation_only"}}


## First event of data/events.json (evt_offline_gleis9), freshly parsed.
func _offline() -> Dictionary:
	var raw: Variant = JsonUtil.read_file("res://data/events.json")
	return ((raw as Dictionary)["events"] as Array)[0]


func test_live_example_validates() -> void:
	var def: EventDef = EventDef.from_dict(_live())
	assert_eq(def.validate(), PackedStringArray(), "05 §10.1 example")
	assert_eq(def.floor_index, 1, "JSON key floor → floor_index")
	assert_eq(def.windows.size(), 3)
	assert_eq(def.run_seed(), 0, "commit_reveal: the seed comes from the server")
	assert_eq(def.leagues(), PackedStringArray(["show", "pur"]))
	assert_eq(def.rules_hash().length(), 64)
	assert_eq(def.rules_hash(), EventDef.from_dict(JSON.parse_string(JSON.stringify(_live()))).rules_hash(),
		"rules_hash survives a JSON round trip (commit input)")


func test_window_state() -> void:
	var def: EventDef = EventDef.from_dict(_live())
	var cases: Array = [
		[EU_OPEN - 1, &"scheduled"], [EU_OPEN, &"open"], [EU_CLOSE - 2701, &"open"],
		[EU_CLOSE - 2700, &"last_entry"], [EU_CLOSE - 301, &"last_entry"], [EU_CLOSE - 300, &"closing"],
		[EU_CLOSE - 1, &"closing"], [EU_CLOSE, &"scheduled"], [AM_OPEN - 1, &"scheduled"], [AM_OPEN, &"open"],
		[APAC_CLOSE - 1, &"closing"], [APAC_CLOSE, &"closed"], [APAC_CLOSE + 86400, &"closed"],
	]
	for c: Array in cases:
		assert_eq(def.window_state(c[0]), c[1], "t = %d" % c[0])
	assert_eq(EventDef.from_dict(_offline()).window_state(EU_OPEN), &"always", "offline: no windows")


func test_late_entry_variants() -> void:
	var d: Dictionary = _live()
	d["late_entry"] = "first_10_min"
	var def: EventDef = EventDef.from_dict(d)
	assert_eq(def.window_state(EU_OPEN + 599), &"open")
	assert_eq(def.window_state(EU_OPEN + 600), &"last_entry", "entry only in the first 10 min")
	d["late_entry"] = "until_last_entry"
	(d["rules"] as Dictionary)["max_run_wall_sec"] = 0
	assert_eq(EventDef.from_dict(d).window_state(EU_CLOSE - 301), &"open", "no wall limit → no last_entry phase")


## 05 §1.2: the standard is last_entry_at = close_at − max_run_wall_sec; "none" / "first_10_min" are opt-ins. A
## weekly event without late_entry must stay open for days, not 10 minutes.
func test_late_entry_defaults_to_until_last_entry() -> void:
	var d: Dictionary = _live()
	d.erase("late_entry")
	d["kind"] = "weekly"
	d["windows"] = [{"id": "w45", "open_at": "2026-11-02T00:00:00Z", "close_at": "2026-11-08T23:59:00Z"}]
	d["seed_policy"]["commits"] = {"w45": "3613e6c5…d64a"}
	var def: EventDef = EventDef.from_dict(d)
	assert_eq(def.validate(), PackedStringArray())
	assert_eq(def.late_entry, "until_last_entry")
	assert_eq(EventDef.new().late_entry, "until_last_entry", "the field default too")
	var open_at: int = int(EventDef.parse_iso_utc("2026-11-02T00:00:00Z")[1])
	var close_at: int = int(EventDef.parse_iso_utc("2026-11-08T23:59:00Z")[1])
	assert_eq(def.window_state(open_at + 3600), &"open", "open + 1 h")
	assert_true(def.can_start(open_at + 3600))
	assert_eq(def.window_state(close_at - 2700), &"last_entry", "close − max_run_wall_sec (2 700 s)")
	d["late_entry"] = "none"
	assert_eq(EventDef.from_dict(d).window_state(open_at + 3600), &"last_entry", "opt-in: first 10 min only")


func test_can_start() -> void:
	var def: EventDef = EventDef.from_dict(_live())
	assert_true(def.can_start(EU_OPEN + 60))
	assert_false(def.can_start(EU_CLOSE - 2000), "last_entry")
	assert_false(def.can_start(EU_CLOSE - 10), "closing")
	assert_false(def.can_start(EU_OPEN - 10), "scheduled")
	assert_false(def.can_start(APAC_CLOSE + 1), "closed")
	assert_true(EventDef.from_dict(_offline()).can_start(0), "offline: always")
	var bad: Dictionary = _offline()
	bad["kind"] = "lottery"
	assert_false(EventDef.from_dict(bad).can_start(0), "invalid events never start")


func test_parse_iso_utc() -> void:
	var cases: Array = [["2026-11-07T19:00:00Z", 1794078000], ["2024-02-29T23:59:59Z", 1709251199],
		["1970-01-01T00:00:00Z", 0], ["2000-03-01T12:34:56+00:00", 951914096], ["1969-12-31T23:59:59Z", -1],
		["2026-11-07T19:00:00.250Z", 1794078000]]
	for c: Array in cases:
		assert_eq(EventDef.parse_iso_utc(c[0]), [true, c[1]], c[0])
	for bad: String in ["2023-02-29T00:00:00Z", "2026-13-01T00:00:00Z", "2026-11-07T24:00:00Z", "2026-11-07T19:00:00",
			"2026-11-07T19:00:00+01:00", "2026-11-07 19:00:00Z", "", "morgen"]:
		assert_false(bool(EventDef.parse_iso_utc(bad)[0]), "rejected: '%s'" % bad)


func test_validation_errors() -> void:
	var cases: Array = [
		["overlap", func(d: Dictionary) -> void: d["windows"][1]["open_at"] = "2026-11-07T20:00:00Z", "overlap"],
		["close before open", func(d: Dictionary) -> void: d["windows"][0]["close_at"] = "2026-11-07T18:00:00Z",
			"close_at must be after open_at"],
		["bad time", func(d: Dictionary) -> void: d["windows"][0]["open_at"] = "Samstag", "ISO-8601"],
		["duplicate window", func(d: Dictionary) -> void: d["windows"][1]["id"] = "eu", "unique"],
		["no windows", func(d: Dictionary) -> void: d["windows"] = [], "at least one window"],
		["missing commit", func(d: Dictionary) -> void: d["seed_policy"]["commits"].erase("am"), "no commit for window 'am'"],
		["fixed live", func(d: Dictionary) -> void: d["seed_policy"] = {"type": "fixed", "run_seed": 1}, "only allowed"],
		["unknown quest", func(d: Dictionary) -> void: d["quest"] = {"type": "sequence", "params": {"steps": []}},
			"unknown quest type 'sequence'"],
		["bad id", func(d: Dictionary) -> void: d["id"] = "Samstag", "must match evt_"],
		["kind", func(d: Dictionary) -> void: d["kind"] = "weekly_special", "unknown kind"],
		["float scoring", func(d: Dictionary) -> void: d["scoring"]["per_ko"] = -150.5, "scoring.per_ko"],
		["unknown scoring", func(d: Dictionary) -> void: d["scoring"]["bonus"] = 1, "unknown scoring key"],
		["float rules", func(d: Dictionary) -> void: d["rules"]["gifts"]["effect_k_pm"] = 0.15, "rules.gifts.effect_k_pm"],
		["league", func(d: Dictionary) -> void: d["rules"]["leagues"] = ["vip"], "unknown league"],
		["timer mode", func(d: Dictionary) -> void: d["rules"]["timer_mode"] = "turbo", "timer_mode"],
		["sponsored", func(d: Dictionary) -> void: d["rewards"]["sponsored_runs"] = "full", "participation_only"],
		["late entry", func(d: Dictionary) -> void: d["late_entry"] = "always", "late_entry"],
		["unknown key", func(d: Dictionary) -> void: d["prize_money"] = 100, "unknown key 'prize_money'"],
		["floor type", func(d: Dictionary) -> void: d["floor"] = "eins", "floor must be"],
	]
	for c: Array in cases:
		var d: Dictionary = _live()
		(c[1] as Callable).call(d)
		var errs: PackedStringArray = EventDef.from_dict(d).validate()
		assert_gt(errs.size(), 0, str(c[0]))
		assert_has("; ".join(errs), str(c[2]), str(c[0]))


func test_offline_rules() -> void:
	var cases: Array = [
		["fixed without seed", func(d: Dictionary) -> void: d["seed_policy"].erase("run_seed"), "run_seed"],
		["windows", func(d: Dictionary) -> void: d["windows"] = [{"id": "eu", "open_at": "2026-11-07T19:00:00Z",
			"close_at": "2026-11-07T20:30:00Z"}], "offline events have no windows"],
		["show league", func(d: Dictionary) -> void: d["rules"]["leagues"] = ["show"], "Pur-Liga only"],
		["gifts", func(d: Dictionary) -> void: d["rules"]["gifts"]["enabled"] = true, "no gifts (S0)"],
		["preset", func(d: Dictionary) -> void: d["rules"]["party_preset"] = "preset_f1_l3", "S0 supports only"],
		["realtime", func(d: Dictionary) -> void: d["rules"]["timer_mode"] = "realtime", "run explore_only"],
	]
	for c: Array in cases:
		var d: Dictionary = _offline()
		(c[1] as Callable).call(d)
		assert_has("; ".join(EventDef.from_dict(d).validate()), str(c[2]), str(c[0]))


## With the game data: the floor exists and an offline event's floor_timer_sec is the FloorDef timer RunSim/Game use
## (the lobby shows rules.floor_timer_sec).
func test_offline_rules_against_the_data() -> void:
	var data: GameData = real_data()
	var ok: EventDef = EventDef.from_dict(_offline())
	assert_eq(ok.validate(data), PackedStringArray(), "events.json matches floors.json")
	var d: Dictionary = _offline()
	var t: int = data.floor_def(1).timer_seconds
	d["rules"]["floor_timer_sec"] = t + 300
	assert_eq(EventDef.from_dict(d).validate(), PackedStringArray(), "without data: not checkable")
	assert_has("; ".join(EventDef.from_dict(d).validate(data)),
		"rules.floor_timer_sec %d != floor 1 timer_seconds %d" % [t + 300, t])
	d["rules"].erase("floor_timer_sec")
	assert_eq(EventDef.from_dict(d).validate(data), PackedStringArray(), "optional: the FloorDef timer applies")
	d["floor"] = 99
	assert_has("; ".join(EventDef.from_dict(d).validate(data)), "floor 99 does not exist")
	var cat: EventCatalog = EventCatalog.new()
	cat.data = data
	assert_true(cat.load_file("res://data/events.json"), "; ".join(cat.errors))
	var bad: Dictionary = _offline()
	bad["rules"]["floor_timer_sec"] = 900
	assert_false(cat.load_dict({"schema": 1, "events": [bad]}), "the catalog checks against its data")
	assert_has("; ".join(cat.errors), "floor_timer_sec 900")


func test_real_catalog() -> void:
	var cat: EventCatalog = EventCatalog.new()
	assert_true(cat.load_file("res://data/events.json"), "; ".join(cat.errors))
	assert_eq(cat.errors, PackedStringArray())
	assert_gt(cat.all().size(), 0)
	var g9: EventDef = cat.get_event("evt_offline_gleis9")
	assert_not_null(g9)
	if g9 == null:
		return
	assert_eq(g9.run_seed(), 424242, "seed_policy fixed (05 §10.1)")
	assert_eq(g9.leagues(), PackedStringArray(["pur"]))
	assert_eq(g9.window_state(1794078000), &"always")
	assert_not_null(QuestTracker.from_def(g9.quest), "the quest builds")
	assert_null(cat.get_event("evt_missing"))


func test_catalog_errors() -> void:
	var cat: EventCatalog = EventCatalog.new()
	assert_false(cat.load_file("res://tests/fixtures/live/does_not_exist.json"))
	assert_has(cat.errors[0], "file not found")
	assert_false(cat.load_file("res://tests/fixtures/live/gift_tables.json"), "wrong file layout")
	assert_has("; ".join(cat.errors), "unknown top-level key")
	var dup: Dictionary = {"schema": 1, "events": [_offline(), _offline(), _live(), "x"]}
	(dup["events"][2] as Dictionary)["kind"] = "nope"
	assert_false(cat.load_dict(dup))
	var joined: String = "; ".join(cat.errors)
	assert_has(joined, "duplicate event id")
	assert_has(joined, "unknown kind")
	assert_has(joined, "events[3] must be an object")
	assert_eq(cat.all().size(), 1, "the valid event stays available")
	assert_false(cat.load_dict({"schema": 2, "events": []}), "schema mismatch")
	assert_true(cat.load_dict({"schema": 1, "events": [_live()]}), "; ".join(cat.errors))
	assert_eq(cat.all().size(), 1, "reloading clears the previous content")
