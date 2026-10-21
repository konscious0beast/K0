class_name SeasonClock extends RefCounted
## The broadcast schedule of a season (09 §2.1, §2.4, §2.6; V-17) — pure arithmetic on unix seconds, no state of its
## own: day 0 (the first air time at or after the start), the collapse dates of every floor in UTC, the floor on air,
## the staircase limit from floor 4, the time until a floor opens, the Am-Stück countdowns per floor. The core knows no
## clock (05 §3.3 Nr. 6): every "now" here is the season clock SeasonState.utc, moved only by the recorded commands
## "clock" / "away" (09 §9.1), or the binge clock of SeasonRules.now (exploration time).
## Static and pure (core): integer math only.

const DAY_SEC: int = 86400
## Days per floor (09 §2.4): 2, 3, 4, then 5 for every further floor → 24 / 54 / 84 days for 6 / 12 / 18 floors.
const FLOOR_DAYS: PackedInt32Array = [2, 3, 4, 5]
## Am Stück (09 §2.1, V-2): minutes of exploration time per floor — 20, 30, 40, then 50 (floor 1 = today's 20:00).
const BINGE_MIN: PackedInt32Array = [20, 30, 40, 50]
const TICKS_PER_MIN: int = 1800            # 30 ticks per second (FloorRun.TICKS_PER_SEC)
## Floors 1–3 are open from the start; from floor 4 the stairs lead at most one floor below the floor on air (09 §2.6).
const OPEN_FROM_START: int = 3
## Am Stück: one season day corresponds to ten minutes of exploration time (09 §2.1, §3.2: "nach einem Staffel-Tag" /
## "nach 10 min Erkundungszeit") — the binge clock runs at 86400 / 600 = 144 season seconds per explored second.
const BINGE_DAY_SEC: int = 600
const BINGE_FACTOR: int = 144
## 09 §2.5 Nr. 2, V-17: a collapse that fell into a combat waits for its end, then two more minutes.
const COMBAT_GRACE_SEC: int = 120
## 09 §5.5, V-17: one recorded clock jump counts at most seven days (the rest becomes a pause "clamp").
const MAX_JUMP_SEC: int = 7 * DAY_SEC
## 09 §2.9, V-9: the private Sendepause, up to 14 days per season.
const PAUSE_MAX_SEC: int = 14 * DAY_SEC
## 09 §2.5, V-9: at most one fee (rescue or medics) per seven season days.
const FEE_GAP_SEC: int = 7 * DAY_SEC
## 09 §3.3: at most five programme points per floor.
const DAILY_MAX: int = 5
## 09 §2.5 Nr. 6: HUD warnings before a collapse (calendar: 1 h, 10 min, 1 min).
const WARN_SEC: PackedInt32Array = [3600, 600, 60]


## Days of floor `floor` (1-based): 2, 3, 4, 5, 5, …
static func floor_days(floor: int) -> int:
	if floor < 1:
		return 0
	return FLOOR_DAYS[mini(floor, FLOOR_DAYS.size()) - 1]


## The season day of the collapse of `floor` (09 §2.4: 2, 5, 9, 14, 19, … — 24 / 54 / 84 for the formats).
static func end_day(floor: int) -> int:
	var d: int = 0
	for f in range(1, floor + 1):
		d += floor_days(f)
	return d


## Calendar days of a format (6 → 24, 12 → 54, 18 → 84).
static func format_days(format: int) -> int:
	return end_day(format)


## Collapse dates of floors 1..format in UTC (V-17: all of them from day 0; a daylight-saving change later moves them by
## an hour in local time — documented, never corrected).
static func schedule(day0_utc: int, format: int) -> Array[int]:
	var out: Array[int] = []
	for f in range(1, format + 1):
		out.append(day0_utc + end_day(f) * DAY_SEC)
	return out


## Local "HH:MM" → seconds after local midnight; -1 for anything else.
static func air_seconds(hhmm: String) -> int:
	var parts: PackedStringArray = hhmm.split(":")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return -1
	var h: int = parts[0].to_int()
	var m: int = parts[1].to_int()
	if h < 0 or h > 23 or m < 0 or m > 59:
		return -1
	return h * 3600 + m * 60


## Day 0 (V-17): the first air time at or after `start_utc` — the air time `air_local_sec` (seconds after local
## midnight) in the time zone `tz_offset_sec` (local = UTC + offset, the offset of the start). Floor 1 is already open
## before it (the "Vorprogramm"), so it always has two full days.
static func day0(start_utc: int, air_local_sec: int, tz_offset_sec: int) -> int:
	var air_utc_sod: int = posmod(air_local_sec - tz_offset_sec, DAY_SEC)
	var midnight: int = start_utc - posmod(start_utc, DAY_SEC)
	var t: int = midnight + air_utc_sod
	while t < start_utc:
		t += DAY_SEC
	return t


## The countdown of `floor` Am Stück in ticks (09 §2.1: 20 / 30 / 40 / 50 min × 1 800; 09 §7.4: × 1.5 Vorabend).
static func binge_ticks(floor: int, vorabend: bool = false) -> int:
	var minutes: int = BINGE_MIN[clampi(floor, 1, BINGE_MIN.size()) - 1]
	var ticks: int = minutes * TICKS_PER_MIN
	return ticks * 3 / 2 if vorabend else ticks


## The highest floor open now (09 §2.6): floors 1–3 from the start; floor M ≥ 4 once floor M − 1 is on air, i.e. once
## floor M − 2 collapsed (`collapsed` floors so far) — capped at the format. Am Stück there is no limit.
static func open_floor_max(collapsed: int, format: int, binge: bool) -> int:
	if binge:
		return format
	return mini(format, maxi(OPEN_FROM_START, collapsed + 2))


## The collapse index that opens `floor` (≥ 4): its floor M − 2 (array index M − 3); -1 for floors open from the start.
static func opener_index(floor: int) -> int:
	return floor - 3 if floor > OPEN_FROM_START else -1
