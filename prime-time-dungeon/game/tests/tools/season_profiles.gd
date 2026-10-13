extends RefCounted
## The play profiles of the Staffel-Harness (09 §11.6, ST1-I): when a person plays a calendar season — the sessions of
## a profile as [{"day", "start", "sec", "first"}] ("start" in cast seconds since day 0, negative in the Vorprogramm;
## "sec" the play seconds of the session; "first" the evening the season starts), deterministic per seed
## (SeedUtil.derive(seed, "harness_sessions", <profile>)). Shared by the headless harness
## (tests/tools/season_harness.gd) and the full-run bot (scenes/boot/fullrun.gd, calendar seasons); private test helper
## (no class_name, load() it).
##
## Profiles (09 §11.6; the day numbers of format 18 scaled to the format, 09 Kap. 11.3 decision I-3):
##   typical  the reference human of 09 F-18: the season starts at a random minute of the day before day 0 with an
##            evening of 60–90 min, then one session of 45–60 min a day, starting between an hour before and an hour
##            after the air time
##   20min    one session of 20 min a day (the first evening too), the start times of typical
##   weekend  Saturday and Sunday 90 min each: the season starts on a weekend day; sessions from two hours before to
##            an hour after the air time
##   away2w   typical, without the 14 days from AWAY_FROM[format] on (format 18: days 30–44 as in 09 §11.6;
##            format 6: days 7–20, the week of floors 3/4). The login after them answers the clock jump with "Ja"
##            (09 V-17): seven days count, the rest becomes a Sendepause and moves the season's end — so the
##            sessions go on AWAY_DAYS days past the format (those after the season's end are never played)

const DAY: int = 86400
const MIN: int = 60
const PROFILES: PackedStringArray = ["typical", "20min", "weekend", "away2w"]
## Weekday of a day as 0 = Monday … 6 = Sunday; the weekend days.
const SATURDAY: int = 5
const SUNDAY: int = 6
## away2w: the first day without a session per format, and how many days the person is away.
const AWAY_FROM: Dictionary = {6: 7, 12: 19, 18: 30}
const AWAY_DAYS: int = 14
## Two sessions are at least this far apart (minutes): a shorter break is no logout (09 §5.1 Nr. 2: 10 min).
const GAP_MIN: int = 30


## The sessions of `profile` for a season of `format` floors and run seed `seed` (unknown profile → []).
static func sessions(profile: String, seed: int, format: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not PROFILES.has(profile):
		return out
	var rng: RandomNumberGenerator = SeedUtil.make_rng(SeedUtil.derive(seed, "harness_sessions", PROFILES.find(profile)))
	var days: int = SeasonClock.format_days(format)
	var dow0: int = day0_weekday(profile, seed)
	if profile == "weekend":
		out.append({"day": -1, "start": -rng.randi_range(2 * 60, 4 * 60) * MIN, "sec": 90 * MIN, "first": true})
		for d in days:
			var wd: int = posmod(dow0 + d, 7)
			if wd == SATURDAY or wd == SUNDAY:
				out.append({"day": d, "start": d * DAY + rng.randi_range(-120, 60) * MIN, "sec": 90 * MIN,
					"first": false})
		return out
	var first_min: int = 20 if profile == "20min" else rng.randi_range(60, 90)
	out.append({"day": -1, "start": -rng.randi_range(1, 23 * 60 + 59 - first_min) * MIN, "sec": first_min * MIN,
		"first": true})
	var away_from: int = int(AWAY_FROM.get(format, days)) if profile == "away2w" else days
	for d in (days + AWAY_DAYS if profile == "away2w" else days):
		var start: int = d * DAY + rng.randi_range(-60, 60) * MIN
		var length: int = 20 if profile == "20min" else rng.randi_range(45, 60)
		if d >= away_from and d < away_from + AWAY_DAYS:
			continue
		var prev: Dictionary = out[out.size() - 1]
		start = maxi(start, int(prev["start"]) + int(prev["sec"]) + GAP_MIN * MIN)   # never two sessions at once
		out.append({"day": d, "start": start, "sec": length * MIN, "first": false})
	return out


## The weekday of day 0 (0 = Monday): drawn per seed; the weekend profile starts its season on a Saturday or a Sunday
## (its day −1), so its day 0 is a Sunday or a Monday.
static func day0_weekday(profile: String, seed: int) -> int:
	var rng: RandomNumberGenerator = SeedUtil.make_rng(SeedUtil.derive(seed, "harness_weekday", 0))
	if profile == "weekend":
		return SUNDAY if rng.randi_range(0, 1) == 0 else 0
	return rng.randi_range(0, 6)


## Play minutes of `profile` over a season of `format` floors (the planned budget; tests and the report).
static func planned_minutes(profile: String, seed: int, format: int) -> int:
	var sum: int = 0
	for s: Dictionary in sessions(profile, seed, format):
		sum += int(s["sec"]) / MIN
	return sum


## The days without any session (away2w: the absence; weekend: the weekdays) up to the end of the season.
static func idle_days(profile: String, seed: int, format: int) -> PackedInt32Array:
	var played: Dictionary = {}
	for s: Dictionary in sessions(profile, seed, format):
		played[int(s["day"])] = true
	var out: PackedInt32Array = []
	for d in SeasonClock.format_days(format):
		if not played.has(d):
			out.append(d)
	return out
