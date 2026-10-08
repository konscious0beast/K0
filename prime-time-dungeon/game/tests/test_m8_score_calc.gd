extends TestCase
## ScoreCalc (05 §1.5, §11.4): the 05 §10.4 example (17 340), incomplete quests, caps, scoring overrides, the summary
## keys Game.finish_run delivers, tie-break order.


func test_reference_example() -> void:
	var summary: Dictionary = {"quest_complete": true, "quest_progress": 1.0, "floor_timer_left_sec": 828,
		"followers_gained": 2600, "achievements_in_run": 9, "party_kos": 2}
	var r: Dictionary = ScoreCalc.score(summary, {})
	assert_eq(r["score"], 17340, "05 §10.4")
	assert_eq(r["breakdown"], {"quest": 10000, "time": 4140, "show": 2600, "achievements": 900, "ko": -300})
	var events_scoring: Dictionary = {"complete": 10000, "progress_max": 5000, "per_sec_left": 5, "per_follower": 1,
		"follower_cap": 3000, "per_achievement": 100, "per_ko": -150}
	assert_eq(ScoreCalc.score(summary, events_scoring), r, "events.json scoring == defaults")
	assert_eq(ScoreCalc.score(JSON.parse_string(JSON.stringify(summary)), JSON.parse_string(JSON.stringify(
		events_scoring))), r, "JSON numbers (floats) give the same integers")


func test_incomplete_quest() -> void:
	var half: Dictionary = ScoreCalc.score({"quest_complete": false, "quest_progress": 0.5, "floor_timer_left_sec": 600,
		"followers_gained": 5000, "achievements_in_run": 1}, {})
	assert_eq(half["breakdown"], {"quest": 2500, "time": 0, "show": 3000, "achievements": 100, "ko": 0},
		"floor(5000 × 0.5), no time bonus without completion, followers capped at 3000")
	assert_eq(half["score"], 5600)
	var third: Dictionary = ScoreCalc.score({"quest_complete": false, "quest_progress_ppm": 333333}, {})
	assert_eq(third["breakdown"]["quest"], 1666, "integer floor(5000 × 333333 / 1e6)")
	var q: QuestTracker = QuestTracker.from_def({"type": "bounty", "params": {"enemy_id": "enm_a", "count": 3}})
	q.on_event({"type": "enemy_killed", "enemy_id": "enm_a"})
	assert_eq(ScoreCalc.score({"quest_progress": q.progress()}, {})["breakdown"]["quest"],
		ScoreCalc.score({"quest_progress_ppm": q.progress_ppm()}, {})["breakdown"]["quest"],
		"float progress from QuestTracker maps back to the exact ppm")
	assert_eq(ScoreCalc.score({}, {})["score"], 0, "empty summary")


func test_overrides_and_negative_inputs() -> void:
	var r: Dictionary = ScoreCalc.score({"quest_complete": true, "floor_timer_left_sec": 10, "followers_gained": 50,
		"achievements_in_run": 2, "party_kos": 1}, {"complete": 2000, "per_sec_left": 1, "per_follower": 2,
		"follower_cap": 40, "per_achievement": 10, "per_ko": -500, "unknown_key": 9999})
	assert_eq(r["breakdown"], {"quest": 2000, "time": 10, "show": 80, "achievements": 20, "ko": -500})
	assert_eq(r["score"], 1610, "unknown scoring keys are ignored")
	var neg: Dictionary = ScoreCalc.score({"quest_complete": true, "floor_timer_left_sec": -5, "followers_gained": -9,
		"party_kos": -2}, {})
	assert_eq(neg["breakdown"], {"quest": 10000, "time": 0, "show": 0, "achievements": 0, "ko": 0}, "no negatives")


## Keys of Game.finish_run (floor_run.summary + quest + show): time_left_sec, followers_gained, achievements_total.
func test_game_summary_keys() -> void:
	var summary: Dictionary = {"floor": 1, "time_used_sec": 372, "time_left_sec": 828, "kills": 6, "viewers_peak": 2210,
		"followers_gained": 420, "achievements": 4, "cause": "floor_completed", "event_id": "evt_offline_gleis9",
		"quest_complete": true, "quest_progress": 1.0, "followers": 420, "achievements_total": 5}
	var r: Dictionary = ScoreCalc.score(summary, {})
	assert_eq(r["breakdown"], {"quest": 10000, "time": 4140, "show": 420, "achievements": 500, "ko": 0},
		"achievements_total (whole run) wins over the floor counter")
	summary["followers_gained_run"] = 999
	summary["achievements_in_run"] = 6
	assert_eq(ScoreCalc.score(summary, {})["breakdown"]["show"], 999, "run counter preferred")
	assert_eq(ScoreCalc.score(summary, {})["breakdown"]["achievements"], 600)


func test_tie_break_order() -> void:
	var a: Dictionary = {"score": 100, "run_wall_ms": 50000, "finished_at": "2026-11-07T19:58:31Z"}
	var b: Dictionary = {"score": 100, "run_wall_ms": 60000, "finished_at": "2026-11-07T19:50:00Z"}
	var c: Dictionary = {"score": 100, "run_wall_ms": 60000, "finished_at": "2026-11-07T19:55:00Z"}
	var d: Dictionary = {"score": 101, "run_wall_ms": 99999, "finished_at": "2026-11-07T20:00:00Z"}
	assert_true(Leaderboard.is_better(d, a), "score first")
	assert_true(Leaderboard.is_better(a, b), "then shorter run_wall_ms")
	assert_true(Leaderboard.is_better(b, c), "then earlier finished_at")
	assert_false(Leaderboard.is_better(c, b))
	assert_false(Leaderboard.is_better(a, a), "a full tie is not better")
	var unknown_wall: Dictionary = {"score": 100, "run_wall_ms": 0, "finished_at": "2026-11-07T19:00:00Z"}
	assert_true(Leaderboard.is_better(b, unknown_wall), "a measured time ranks before an unknown one (S0: 0)")
