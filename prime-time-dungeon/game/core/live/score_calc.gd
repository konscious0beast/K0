class_name ScoreCalc extends RefCounted
## Score of an event run (05 §1.5), integers only:
##   quest_pts = completed ? complete : floor(progress_max × progress)
##   time_pts  = completed ? floor_timer_left_sec × per_sec_left : 0
##   show_pts  = min(followers_gained, follower_cap) × per_follower
##   ach_pts   = achievements_in_run × per_achievement
##   ko_pen    = party_kos × per_ko                                  (per_ko is negative)
##   score     = quest_pts + time_pts + show_pts + ach_pts + ko_pen
## `scoring` (events.json → scoring) overrides the defaults key by key. Summary keys (first present wins):
##   quest_complete: bool · quest_progress_ppm: int | quest_progress: float 0..1 ·
##   floor_timer_left_sec | time_left_sec · followers_gained_run | followers_gained ·
##   achievements_in_run | achievements_total | achievements · party_kos.
## Tie-break of equal scores: Leaderboard.is_better (run_wall_ms ascending, then finished_at ascending).

const DEFAULT_SCORING: Dictionary = {"complete": 10000, "progress_max": 5000, "per_sec_left": 5, "per_follower": 1,
	"follower_cap": 3000, "per_achievement": 100, "per_ko": -150}
const PPM: int = 1000000


## → {"score": int, "breakdown": {"quest", "time", "show", "achievements", "ko"}}
static func score(summary: Dictionary, scoring: Dictionary) -> Dictionary:
	var sc: Dictionary = DEFAULT_SCORING.duplicate()
	for k: Variant in scoring.keys():
		if DEFAULT_SCORING.has(str(k)):
			sc[str(k)] = _int(scoring[k])
	var completed: bool = bool(summary.get("quest_complete", false))
	var quest_pts: int = 0
	if completed:
		quest_pts = int(sc["complete"])
	else:
		quest_pts = int(sc["progress_max"]) * progress_ppm(summary) / PPM
	var time_pts: int = 0
	if completed:
		time_pts = maxi(0, _first_int(summary, ["floor_timer_left_sec", "time_left_sec"])) * int(sc["per_sec_left"])
	var followers: int = maxi(0, _first_int(summary, ["followers_gained_run", "followers_gained"]))
	var show_pts: int = mini(followers, maxi(0, int(sc["follower_cap"]))) * int(sc["per_follower"])
	var achievements: int = maxi(0, _first_int(summary, ["achievements_in_run", "achievements_total", "achievements"]))
	var ach_pts: int = achievements * int(sc["per_achievement"])
	var ko_pen: int = maxi(0, _first_int(summary, ["party_kos"])) * int(sc["per_ko"])
	var breakdown: Dictionary = {"quest": quest_pts, "time": time_pts, "show": show_pts, "achievements": ach_pts,
		"ko": ko_pen}
	return {"score": quest_pts + time_pts + show_pts + ach_pts + ko_pen, "breakdown": breakdown}


## Quest progress of a summary in parts per million (exact for QuestTracker values: progress = ppm / 1e6).
static func progress_ppm(summary: Dictionary) -> int:
	if summary.has("quest_progress_ppm"):
		return clampi(_int(summary["quest_progress_ppm"]), 0, PPM)
	var p: Variant = summary.get("quest_progress", 0.0)
	if typeof(p) != TYPE_FLOAT and typeof(p) != TYPE_INT:
		return 0
	return clampi(roundi(float(p) * PPM), 0, PPM)


static func _first_int(summary: Dictionary, keys: Array) -> int:
	for k: Variant in keys:
		if summary.has(k):
			return _int(summary[k])
	return 0


static func _int(v: Variant) -> int:
	if typeof(v) == TYPE_INT:
		return v
	if typeof(v) == TYPE_FLOAT and is_finite(float(v)):
		return int(v)
	return 0
