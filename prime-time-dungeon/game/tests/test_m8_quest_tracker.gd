extends TestCase
## QuestTracker (05 §1.3, §11.4): every S0 quest type with fixed synthetic event sequences (complete / not complete /
## progress); hype_peak only via the deterministic metrics; pacifist fails at the 4th battle; all_of = mean;
## to_dict/from_dict round trip.

const GLEIS9: Dictionary = {"type": "all_of", "label_key": "quest_gleis9_clearance", "params": {"quests": [
	{"type": "defeat_boss", "params": {"boss_id": "enm_boss_rattenkoenigin"}},
	{"type": "achievement_hunt", "params": {"ids": ["ach_overkill", "ach_combo_first", "ach_close_call"], "min": 2}}]}}


func _q(def: Dictionary) -> QuestTracker:
	var q: QuestTracker = QuestTracker.from_def(def)
	assert_not_null(q, str(def))
	return q


func test_types_match_the_validator_vocabulary() -> void:
	assert_eq(QuestTracker.TYPES, DataValidator.QUEST_TYPES, "S0 quest types (DataValidator.QUEST_TYPES)")


func test_reach_stairs() -> void:
	var q: QuestTracker = _q({"type": "reach_stairs", "params": {"floor": 1}})
	assert_false(q.on_event({"type": "floor_completed", "floor": 2}), "other floor")
	assert_true(q.on_event({"type": "zones", "explored": 2, "total": 4}), "detail event: explored zones × 0.9")
	assert_almost(q.progress(), 0.45)
	assert_false(q.on_event({"type": "zones", "explored": 1, "total": 4}), "progress never drops")
	assert_true(q.on_event({"type": "floor_completed", "floor": 1}))
	assert_true(q.is_complete())
	assert_eq(q.progress(), 1.0)


func test_defeat_boss() -> void:
	var q: QuestTracker = _q({"type": "defeat_boss", "params": {"boss_id": "enm_boss_hausmeister"}})
	assert_eq(q.progress(), 0.0, "0 when never met")
	assert_false(q.on_event({"type": "boss_defeated", "boss_id": "enm_boss_rattenkoenigin"}), "other boss")
	assert_true(q.on_event({"type": "boss_hp", "boss_id": "enm_boss_hausmeister", "hp": 300, "max_hp": 1000}))
	assert_almost(q.progress(), 0.7)
	q.on_event({"type": "boss_hp", "boss_id": "enm_boss_hausmeister", "hp": 600, "max_hp": 1000})
	assert_almost(q.progress(), 0.7, 0.0001, "best attempt counts")
	assert_true(q.on_event({"type": "boss_defeated", "boss_id": "enm_boss_hausmeister"}))
	assert_true(q.is_complete())


func test_bounty() -> void:
	var q: QuestTracker = _q({"type": "bounty", "params": {"enemy_id": "enm_kanalratte", "count": 3}})
	assert_false(q.on_event({"type": "enemy_killed", "enemy_id": "enm_taube"}))
	assert_true(q.on_event({"type": "enemy_killed", "enemy_id": "enm_kanalratte"}))
	q.on_event({"type": "enemy_killed", "enemy_id": "enm_kanalratte"})
	assert_eq(q.progress_ppm(), 666666, "2 / 3 exactly in ppm")
	assert_false(q.is_complete())
	q.on_event({"type": "enemy_killed", "enemy_id": "enm_kanalratte"})
	assert_true(q.is_complete())
	assert_false(q.on_event({"type": "enemy_killed", "enemy_id": "enm_kanalratte"}), "complete stays complete")


func test_hype_peak_uses_only_deterministic_metrics() -> void:
	var q: QuestTracker = _q({"type": "hype_peak", "params": {"metric": "viewers_target_peak", "target": 6000}})
	assert_false(q.on_event({"type": "viewers", "value": 9999}), "noisy display viewers are no quest event")
	assert_false(q.on_event({"type": "metric", "name": "followers_gained_run", "value": 9999}), "other metric")
	assert_true(q.on_event({"type": "metric", "name": "viewers_target_peak", "value": 2900}))
	assert_eq(q.progress_ppm(), 483333)
	q.on_event({"type": "metric", "name": "viewers_target_peak", "value": 6000})
	assert_true(q.is_complete())
	var h: QuestTracker = _q({"type": "hype_peak", "params": {"metric": "hype_100_count", "target": 2}})
	h.on_event({"type": "metric", "name": "hype_100_count", "value": 1})
	assert_almost(h.progress(), 0.5)
	h.on_event({"type": "metric", "name": "hype_100_count", "value": 2})
	assert_true(h.is_complete())


func test_pacifist() -> void:
	var def: Dictionary = {"type": "pacifist", "params": {"max_battles": 3, "then": {"type": "reach_stairs",
		"params": {"floor": 1}}}}
	var ok: QuestTracker = _q(def)
	for i in 3:
		ok.on_event({"type": "battle_started"})
	assert_false(ok.failed(), "3 battles are allowed (bosses count)")
	ok.on_event({"type": "floor_completed", "floor": 1})
	assert_true(ok.is_complete(), "stairs with 3 battles")
	var bad: QuestTracker = _q(def)
	bad.on_event({"type": "zones", "explored": 2, "total": 4})
	assert_almost(bad.progress(), 0.45, 0.0001, "progress of the sub quest")
	for i in 3:
		bad.on_event({"type": "battle_started"})
	assert_true(bad.on_event({"type": "battle_started"}), "the 4th battle changes the progress")
	assert_true(bad.failed(), "fails at the 4th battle")
	assert_eq(bad.progress(), 0.0, "0 once the limit is exceeded")
	bad.on_event({"type": "floor_completed", "floor": 1})
	assert_false(bad.is_complete(), "stairs do not help any more")


func test_achievement_hunt() -> void:
	var q: QuestTracker = _q({"type": "achievement_hunt", "params": {"ids": ["ach_overkill", "ach_combo_first",
		"ach_close_call", "ach_stunt_first"], "min": 3}})
	assert_true(q.on_event({"type": "achievement", "id": "ach_overkill"}))
	assert_false(q.on_event({"type": "achievement", "id": "ach_overkill"}), "duplicates count once")
	assert_false(q.on_event({"type": "achievement", "id": "ach_first_blood"}), "not listed")
	q.on_event({"type": "achievement", "id": "ach_combo_first"})
	assert_eq(q.progress_ppm(), 666666)
	q.on_event({"type": "achievement", "id": "ach_stunt_first"})
	assert_true(q.is_complete())


func test_all_of_is_the_mean() -> void:
	var q: QuestTracker = _q(GLEIS9)
	assert_eq(q.label_key, "quest_gleis9_clearance")
	q.on_event({"type": "achievement", "id": "ach_overkill"})
	assert_almost(q.progress(), 0.25, 0.0001, "(0 + 0.5) / 2")
	q.on_event({"type": "boss_defeated", "boss_id": "enm_boss_rattenkoenigin"})
	assert_almost(q.progress(), 0.75, 0.0001, "(1 + 0.5) / 2")
	assert_false(q.is_complete())
	assert_true(q.on_event({"type": "achievement", "id": "ach_close_call"}))
	assert_true(q.is_complete())
	assert_eq(q.progress(), 1.0)


func test_round_trip_continues_identically() -> void:
	var q: QuestTracker = _q(GLEIS9)
	q.on_event({"type": "achievement", "id": "ach_overkill"})
	q.on_event({"type": "boss_hp", "boss_id": "enm_boss_rattenkoenigin", "hp": 500, "max_hp": 2000})
	var d: Dictionary = q.to_dict()
	var back: QuestTracker = QuestTracker.from_dict(JSON.parse_string(JSON.stringify(d)))
	assert_not_null(back)
	if back == null:
		return
	assert_eq(back.to_dict(), d, "lossless (also after JSON)")
	assert_eq(back.progress_ppm(), q.progress_ppm())
	for ev: Dictionary in [{"type": "achievement", "id": "ach_overkill"}, {"type": "achievement", "id": "ach_combo_first"},
			{"type": "boss_defeated", "boss_id": "enm_boss_rattenkoenigin"}]:
		assert_eq(back.on_event(ev), q.on_event(ev), str(ev))
		assert_eq(back.progress_ppm(), q.progress_ppm())
	assert_true(back.is_complete())
	var p: QuestTracker = _q({"type": "pacifist", "params": {"max_battles": 1, "then": {"type": "bounty",
		"params": {"enemy_id": "enm_a", "count": 2}}}})
	p.on_event({"type": "battle_started"})
	p.on_event({"type": "enemy_killed", "enemy_id": "enm_a"})
	var pb: QuestTracker = QuestTracker.from_dict(p.to_dict())
	pb.on_event({"type": "battle_started"})
	assert_true(pb.failed(), "battle counter restored")
	assert_null(QuestTracker.from_dict({"type": "nope"}), "invalid → null")


func test_definition_errors() -> void:
	var cases: Array = [
		[{"type": "sequence", "params": {"steps": []}}, "unknown quest type 'sequence'"],
		[{"type": "reach_stairs"}, "params"],
		[{"type": "reach_stairs", "params": {"floor": 0}}, "floor"],
		[{"type": "bounty", "params": {"enemy_id": "enm_a", "count": 0}}, "count"],
		[{"type": "hype_peak", "params": {"metric": "display_viewers", "target": 5}}, "metric"],
		[{"type": "hype_peak", "params": {"metric": "hype_100_count", "target": 1.5}}, "target"],
		[{"type": "achievement_hunt", "params": {"ids": ["ach_a"], "min": 2}}, "min"],
		[{"type": "achievement_hunt", "params": {"ids": [], "min": 1}}, "ids"],
		[{"type": "pacifist", "params": {"max_battles": 1, "then": {"type": "x"}}}, "quest.then: unknown"],
		[{"type": "all_of", "params": {"quests": []}}, "quests"],
		[{"type": "all_of", "params": {"quests": [{"type": "bounty", "params": {}}]}}, "quest.quests[0].params"],
	]
	for c: Array in cases:
		var errs: PackedStringArray = QuestTracker.validate_def(c[0])
		assert_gt(errs.size(), 0, str(c[0]))
		assert_has("; ".join(errs), str(c[1]), str(c[0]))
		assert_null(QuestTracker.from_def(c[0]), "invalid → null")
	assert_eq(QuestTracker.validate_def(GLEIS9), PackedStringArray())


func test_event_quests_of_the_data() -> void:
	var cat: EventCatalog = EventCatalog.new()
	cat.load_file("res://data/events.json")
	for def: EventDef in cat.all():
		var q: QuestTracker = QuestTracker.from_def(def.quest)
		assert_not_null(q, def.id)
		if q != null:
			assert_eq(q.progress(), 0.0, def.id)
			assert_false(q.is_complete(), def.id)
