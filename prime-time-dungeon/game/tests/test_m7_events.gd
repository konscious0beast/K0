extends TestCase
## M7 content of data/events.json (05_LIVE_MODUS §10.1, §11.1; Brief §6b.5): S0 offline event runs only.
## The schema/loader belongs to M8 (EventCatalog); this test checks the content against the documented schema and the
## game data it references, and — once EventCatalog is no longer the M0 stub — that the catalog accepts the file.

const PATH: String = "res://data/events.json"
const EVENT_KEYS: PackedStringArray = ["id", "kind", "name_key", "floor", "windows", "late_entry", "seed_policy",
	"quest", "rules", "votes", "scoring", "rewards"]
const SCORING_KEYS: PackedStringArray = ["complete", "progress_max", "per_sec_left", "per_follower", "follower_cap",
	"per_achievement", "per_ko"]
const S0_QUESTS: PackedStringArray = ["reach_stairs", "defeat_boss", "bounty", "hype_peak", "pacifist",
	"achievement_hunt", "all_of"]


func _events() -> Array:
	var raw: Variant = JsonUtil.read_file(PATH)
	if not raw is Dictionary:
		fail("events.json does not parse")
		return []
	var d: Dictionary = raw
	assert_eq(d.keys().size(), 2, "top level is {schema, events}")
	assert_eq(int(d.get("schema", 0)), 1)
	return d.get("events", [])


func test_offline_events() -> void:
	var events: Array = _events()
	assert_between(events.size(), 1, 2, "05 §11.1: 1–2 offline events")
	var ids: Dictionary = {}
	for e: Dictionary in events:
		var id: String = str(e.get("id", ""))
		assert_true(RegEx.create_from_string("^evt_[a-z0-9_]+$").search(id) != null, "id " + id)
		assert_false(ids.has(id), "unique " + id)
		ids[id] = true
		for k: Variant in e.keys():
			assert_has(EVENT_KEYS, str(k), id + " key")
		assert_eq(e["kind"], "offline", id)
		assert_eq(int(e["floor"]), 1, id)
		assert_len(e["windows"], 0, id + ": offline = always open")
		var sp: Dictionary = e["seed_policy"]
		assert_eq(sp["type"], "fixed", id)
		assert_true(JsonUtil.is_integral(sp["run_seed"]) and int(sp["run_seed"]) > 0, id + " run_seed")
		var rules: Dictionary = e["rules"]
		assert_eq(rules["mode"], "solo", id)
		assert_eq(rules["leagues"], ["pur"], id + ": offline runs are Pur-Liga only")
		assert_eq(rules["timer_mode"], "explore_only", id)
		assert_eq(rules["party_preset"], "new_game", id + ": S0 supports only new_game")
		assert_false(bool((rules["gifts"] as Dictionary)["enabled"]), id + ": no gifts in S0")
		assert_eq(int(rules["floor_timer_sec"]), real_data().floor_def(1).timer_seconds, id)
		var scoring: Dictionary = e["scoring"]
		for k: String in SCORING_KEYS:
			assert_true(scoring.has(k) and JsonUtil.is_integral(scoring[k]), id + " scoring." + k + " integer")
		var rewards: Dictionary = e["rewards"]
		assert_true(rewards.has("participation") and rewards.has("quest"), id + " rewards")
		assert_false(bool((e["votes"] as Dictionary)["enabled"]), id)
		_check_quest(id, e["quest"], true)
	assert_true(ids.has("evt_offline_gleis9"), "05 §10.1 reference event")


func test_gleis9_quest_targets_the_queen() -> void:
	for e: Dictionary in _events():
		if str(e["id"]) != "evt_offline_gleis9":
			continue
		var q: Dictionary = e["quest"]
		assert_eq(q["type"], "all_of")
		var subs: Array = (q["params"] as Dictionary)["quests"]
		assert_eq(subs[0], {"type": "defeat_boss", "params": {"boss_id": "enm_boss_rattenkoenigin"}})
		assert_eq(int(e["seed_policy"]["run_seed"]), 424242)


func test_event_catalog_accepts_the_file() -> void:
	var cat: EventCatalog = EventCatalog.new()
	assert_true(cat.load_file(PATH), "EventCatalog errors: " + "; ".join(cat.errors))
	for e: Dictionary in _events():
		var def: EventDef = cat.get_event(str(e["id"]))
		assert_not_null(def, str(e["id"]))
		if def != null:
			assert_len(def.validate(), 0, str(e["id"]))
			assert_eq(def.run_seed(), int(e["seed_policy"]["run_seed"]))


func _check_quest(ctx: String, q: Dictionary, top: bool) -> void:
	var t: String = str(q.get("type", ""))
	assert_has(S0_QUESTS, t, ctx + " quest type")
	assert_has(DataValidator.QUEST_TYPES, t, ctx)
	if top:
		assert_ne(str(q.get("label_key", "")), "", ctx + " label_key")
	var p: Dictionary = q.get("params", {})
	var d: GameData = real_data()
	match t:
		"reach_stairs":
			assert_not_null(d.floor_def(int(p["floor"])), ctx)
		"defeat_boss":
			var boss: String = str(p["boss_id"])
			assert_true(d.has_id("enemies", boss) and d.enemy(boss).boss, ctx + " boss " + boss)
		"bounty":
			assert_true(d.has_id("enemies", str(p["enemy_id"])), ctx)
			assert_gt(int(p["count"]), 0, ctx)
		"hype_peak":
			assert_has(["viewers_target_peak", "followers_gained_run", "hype_100_count"], str(p["metric"]), ctx)
		"pacifist":
			assert_gt(int(p["max_battles"]), 0, ctx)
			_check_quest(ctx + ".then", p["then"], false)
		"achievement_hunt":
			var ach_ids: Array = p["ids"]
			for a: Variant in ach_ids:
				assert_true(d.has_id("achievements", str(a)), ctx + " achievement " + str(a))
			assert_between(int(p["min"]), 1, ach_ids.size(), ctx)
		"all_of":
			for sub: Dictionary in p["quests"]:
				_check_quest(ctx + ".all_of", sub, false)
