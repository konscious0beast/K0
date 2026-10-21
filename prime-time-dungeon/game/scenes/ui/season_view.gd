extends RefCounted
## Private helper of the season UI (09 ST1-H; 02_TECH §0.3: no class_name) — the words and rows every season screen
## shows: local dates and durations, the broadcast schedule with its collapse dates, the collapse display of the HUD,
## the counter, the ranking (the AI labelled), the ticker, the programme of the floor with the Pechvogel and the guest,
## the safe-room guests, the choices of a new season (owned formats, tempo, mode, air time) with their one-sentence
## explanations (09 §0.5), the season summary, the hall-of-fame entry of a finished season and the .ics file of the
## schedule. Read-only views of GameState / GameData / SeasonRules / CastSim: the UI never changes recorded state
## except through Game's commands (a projection runs on a copy). Local time: `tz` = local − UTC in seconds, the offset
## of the device now (tz_offset) — Godot knows no time-zone rules, so a date beyond a daylight-saving change shows the
## hour of today's offset until the change (the .ics file carries UTC: the calendar of the device shows it right).

const UiUtil := preload("res://scenes/ui/ui_util.gd")

const DAY: int = 86400
const HOUR: int = 3600
const WEEKDAYS: PackedStringArray = ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]
## H-2 (09 §2.1, V-14): the format follows the owned content. Until a purchase exists every installation owns the
## base game (Akt 1 = the Basis season, 6 floors); Akt 2 and 3 never show (no upsell, no "18 Etagen", CR-29).
const OWNED_FORMATS: PackedInt32Array = [6]
const FORMAT_NAMES: Dictionary = {6: "Basis", 12: "Akt 2", 18: "Akt 3"}
const TEMPO_NAMES: Dictionary = {"calendar": "Kalender", "binge": "Am Stück"}
const MODE_NAMES: Dictionary = {"net": "Mit Netz", "no_net": "Ohne Netz"}
const PROFILE_NAMES: Dictionary = {"extra": "Statist:in", "rival": "Rival:in", "helper": "Helfer:in",
	"trader": "Händler:in", "unlucky": "Pechvogel"}
## H-4: the air time of a new private season — 08:00 … 21:30 in half hours (09 §2.4: collapses in the evening, never
## at night; the notices keep their quiet hours 22–8 anyway).
const AIR_MIN_SEC: int = 8 * HOUR
const AIR_MAX_SEC: int = 21 * HOUR + 30 * 60
const AIR_STEP_SEC: int = 30 * 60
const AIR_DEFAULT: String = "20:00"
## HUD warnings before a collapse (09 §2.5 Nr. 6, calendar): 1 h, 10 min, 1 min — the level of the display.
const WARN_SEC: PackedInt32Array = [3600, 600, 60]
## The one-sentence explanations (09 §0.5, 06 L-1) — what M.O.D. says about a choice, short.
const EXPLAIN: Dictionary = {
	"season": "Jede Etage stürzt pünktlich ein. Pünktlicher als jeder Zug.",
	"rehearsal": "Etage 1 ist die Generalprobe: Hier dürfen Sie noch scheitern. Ab Etage 2 läuft die Kamera wirklich.",
	"format": "%s: %d Etagen in %d Tagen — die erste stürzt nach 2 Tagen ein, die zweite nach 3, die dritte nach 4, " +
		"danach je 5.",
	"calendar": "Kalender: Jede Etage stürzt zu ihrem Termin zur Sendezeit ein. Die Uhr läuft auch, wenn Sie nicht " +
		"spielen.",
	"binge": "Am Stück: Jede Etage hat einen eigenen Countdown, der nur beim Erkunden läuft. Niemand wartet.",
	"net": "Mit Netz: Wer beim Einsturz noch oben steht, wird gerettet — eine Gebühr höchstens einmal pro Woche.",
	"no_net": "Ohne Netz: Ein Leben, keine Rettung. Ab Etage 2 ist man raus und schaut als Studiogast zu.",
	"no_net_locked": "Ohne Netz wird frei nach der ersten Klassenwahl oder einer beendeten Staffel.",
	"air": "Sendezeit %s: Alle Einstürze kommen um diese Uhrzeit, nie mitten in der Nacht.",
	"logout": "Ausloggen geht jederzeit: Im Safe Room schläft Ihre Figur sicher.",
	"nothing_for_sale": "In einer Staffel ist nichts käuflich: keine Rettung, kein Leben, keine Zeit.",
	"cast": "Die freien Plätze spielt die KI — gekennzeichnet mit „KI“.",
}
## The refusal of a "cast" command in words (CastSim.REASONS).
const CAST_REASONS: Dictionary = {"no_cast": "In dieser Staffel gibt es keine KI-Kandidat:innen.",
	"unknown_place": "Diese Kandidat:in gibt es hier nicht.", "not_in_safe_room": "Anheuern geht nur im Safe Room.",
	"in_safe_room": "Helfen geht nur draußen in der Etage.", "not_here": "Sie ist gerade nicht hier.",
	"not_helper": "Nur Helfer:innen begleiten Sie.", "guest_active": "Sie haben schon Begleitung.",
	"no_credits": "Dafür fehlen Credits.", "not_in_need": "Hier braucht gerade niemand Hilfe.",
	"trade_unavailable": "Heute ohne Ware.", "not_allowed": "Das geht gerade nicht."}
const ICS_EVENT_MIN: int = 15                 # minutes an .ics entry lasts (a collapse is a moment)
const ICS_LINE_OCTETS: int = 75               # RFC 5545 §3.1: fold longer content lines
const ICS_DIR: String = "user://exports"


# ======================================================================================================================
# Time
# ======================================================================================================================

## The local offset of the device now (seconds east of UTC).
static func tz_offset() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60


## "Do 20:00" (local time).
static func clock_text(utc: int, tz: int) -> String:
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(utc + tz)
	return "%s %02d:%02d" % [WEEKDAYS[int(d["weekday"])], int(d["hour"]), int(d["minute"])]


## "Do 15.10." (local date).
static func date_text(utc: int, tz: int) -> String:
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(utc + tz)
	return "%s %d.%d." % [WEEKDAYS[int(d["weekday"])], int(d["day"]), int(d["month"])]


## "Do 15.10. 20:00" (local).
static func when_text(utc: int, tz: int) -> String:
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(utc + tz)
	return "%s %d.%d. %02d:%02d" % [WEEKDAYS[int(d["weekday"])], int(d["day"]), int(d["month"]), int(d["hour"]),
		int(d["minute"])]


## "15.10." (local, without the weekday).
static func day_month(utc: int, tz: int) -> String:
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(utc + tz)
	return "%d.%d." % [int(d["day"]), int(d["month"])]


## "1 T 4 Std.", "4 Std. 10 Min.", "12 Min.", "45 Sek." (as the login summary writes it).
static func short(sec: int) -> String:
	var t: int = maxi(0, sec)
	if t >= DAY:
		return "%d T %d Std." % [t / DAY, (t % DAY) / HOUR]
	if t >= HOUR:
		return "%d Std. %d Min." % [t / HOUR, (t % HOUR) / 60]
	if t >= 60:
		return "%d Min." % (t / 60)
	return "%d Sek." % t


## Seconds after midnight → "20:00".
static func hhmm(sec_of_day: int) -> String:
	var s: int = posmod(sec_of_day, DAY)
	return "%02d:%02d" % [s / HOUR, (s % HOUR) / 60]


## The air time `hhmm_text` moved by `steps` half hours, clamped to 08:00 … 21:30 (H-4).
static func air_step(hhmm_text: String, steps: int) -> String:
	var sec: int = SeasonClock.air_seconds(hhmm_text)
	if sec < 0:
		sec = SeasonClock.air_seconds(AIR_DEFAULT)
	return hhmm(clampi(sec + steps * AIR_STEP_SEC, AIR_MIN_SEC, AIR_MAX_SEC))


# ======================================================================================================================
# A new season (09 §2.2: "Sendung starten", "Neue Staffel")
# ======================================================================================================================

## The private templates of the owned formats (H-2), smallest first.
static func owned_defs(data: GameData) -> Array[SeasonDef]:
	var out: Array[SeasonDef] = []
	if data == null:
		return out
	for d: SeasonDef in data.all_seasons():
		if d.is_private() and OWNED_FORMATS.has(d.format):
			out.append(d)
	out.sort_custom(func(a: SeasonDef, b: SeasonDef) -> bool: return a.format < b.format)
	return out


## The template "Sendung starten" uses: the largest owned format (09 §2.2: "größtes eigenes Format").
static func default_def(data: GameData) -> String:
	var defs: Array[SeasonDef] = owned_defs(data)
	return defs[defs.size() - 1].id if not defs.is_empty() else ""


## "Basis · 6 Etagen · 24 Tage".
static func format_text(def: SeasonDef) -> String:
	if def == null:
		return ""
	return "%s · %d Etagen · %d Tage" % [str(FORMAT_NAMES.get(def.format, def.name)), def.format,
		SeasonClock.format_days(def.format)]


## The explanation of a format (09 §2.4).
static func format_explain(def: SeasonDef) -> String:
	if def == null:
		return ""
	return str(EXPLAIN["format"]) % [str(FORMAT_NAMES.get(def.format, def.name)), def.format,
		SeasonClock.format_days(def.format)]


## Day 0 and the collapse of floor 1 of a season started now with `air` (the preview of the setup screen).
static func preview_dates(def: SeasonDef, air: String, now_utc: int, tz: int) -> Dictionary:
	if def == null:
		return {}
	var sec: int = SeasonClock.air_seconds(air)
	var day0: int = SeasonClock.day0(now_utc, sec if sec >= 0 else SeasonClock.air_seconds(AIR_DEFAULT), tz)
	var plan: Array[int] = SeasonClock.schedule(day0, def.format)
	return {"day0": day0, "first": plan[0], "last": plan[plan.size() - 1]}


# ======================================================================================================================
# The running season: status, schedule, collapse display, counter
# ======================================================================================================================

## The season day (0 = day 0; negative in the Vorprogramm before it).
static func season_day(state: GameState) -> int:
	var s: SeasonState = state.season if state != null else null
	if s == null:
		return 0
	return floori(float(SeasonRules.now(state) - s.day0_utc) / float(DAY))


## "Staffel 3 · Basis · Kalender · Mit Netz".
static func head_text(state: GameState) -> String:
	var s: SeasonState = state.season if state != null else null
	if s == null:
		return ""
	return "Staffel %d · %s · %s · %s" % [s.number, str(FORMAT_NAMES.get(s.format, "%d Etagen" % s.format)),
		str(TEMPO_NAMES.get(s.tempo, s.tempo)), str(MODE_NAMES.get(s.mode, s.mode))]


## "Tag 4 von 24 · Etage 2 auf Sendung" (Vorprogramm: "Vorprogramm · Tag 0 beginnt Mo 20:00"; Am Stück: the floor and
## its countdown).
static func status_text(state: GameState, tz: int) -> String:
	var s: SeasonState = state.season if state != null else null
	if s == null:
		return ""
	if s.tempo == "binge":
		var fr: FloorRun = state.floor_run
		return "Am Stück · Etage %d · Countdown %s" % [fr.index if fr != null else 1, UiUtil.fmt_time(fr.time_left_ticks
			/ FloorRun.TICKS_PER_SEC if fr != null else 0)]
	var day: int = season_day(state)
	if day < 0:
		return "Vorprogramm · Tag 0 beginnt %s" % clock_text(s.day0_utc, tz)
	if s.collapsed >= s.format:
		return "Staffel zu Ende · Tag %d" % SeasonClock.format_days(s.format)
	return "Tag %d von %d · Etage %d auf Sendung" % [day, SeasonClock.format_days(s.format), s.on_air()]


## The name of floor `n` without "Etage n – " ("Passage Ewiger Rabatt"); a floor without data: "Kulissen im Aufbau".
static func floor_name(data: GameData, n: int) -> String:
	var def: FloorDef = data.floor_def(n) if data != null else null
	if def == null:
		return "Kulissen im Aufbau"
	var full: String = UiUtil.tr_text(def.name)
	return full.get_slice(" – ", 1) if full.contains(" – ") else full


## The collapse date of floor `n` now (a waiting collapse after a combat: its hold).
static func collapse_at(s: SeasonState, n: int) -> int:
	if n < 1 or n > s.collapse_utc.size():
		return -1
	if n == s.on_air() and s.hold_utc > 0:
		return s.hold_utc
	return s.collapse_utc[n - 1]


## The broadcast schedule (09 §2.4) — one row per floor of the format: {"floor", "name", "kind" (calendar: gone | air
## | open | closed; Am Stück: done | now | next), "line" (the collapse date in local time, Am Stück the countdown),
## "sub" (the status in words: "auf Sendung · in 1 T 4 Std. · Programm 2/5", "öffnet Mo 20:00" …), "here" (the
## candidate stands on it), "finale", "points" (programme points so far)}.
static func schedule(state: GameState, data: GameData, tz: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var s: SeasonState = state.season if state != null else null
	if s == null:
		return out
	var here: int = state.floor_run.index if state.floor_run != null else 0
	var now: int = SeasonRules.now(state)
	var top: int = SeasonRules.open_floor_max(state)
	for n in range(1, s.format + 1):
		var row: Dictionary = {"floor": n, "name": floor_name(data, n), "here": n == here, "finale": n == s.format,
			"points": s.points(n), "kind": "", "line": "", "sub": ""}
		if s.tempo == "binge":
			if n < here:
				row["kind"] = "done"
				row["sub"] = "hinter Ihnen"
			elif n == here:
				row["kind"] = "now"
				row["line"] = UiUtil.fmt_time(state.floor_run.time_left_ticks / FloorRun.TICKS_PER_SEC)
				row["sub"] = "Countdown läuft nur beim Erkunden"
			else:
				row["kind"] = "next"
				row["line"] = "%d:00" % (SeasonClock.binge_ticks(n, state.difficulty == &"vorabend")
					/ SeasonClock.TICKS_PER_MIN)
				row["sub"] = "Countdown startet beim Betreten"
			out.append(row)
			continue
		var at: int = collapse_at(s, n)
		row["line"] = when_text(at, tz)
		if n <= s.collapsed:
			row["kind"] = "gone"
			row["sub"] = "eingestürzt"
		elif n == s.on_air():
			row["kind"] = "air"
			row["sub"] = "auf Sendung · in %s" % short(at - now)
		elif n <= top:
			row["kind"] = "open"
			row["sub"] = "offen"
		else:
			row["kind"] = "closed"
			var idx: int = SeasonClock.opener_index(n)
			var opens: int = collapse_at(s, idx + 1) if idx >= 0 else now
			row["sub"] = "Kulissen im Aufbau · öffnet %s" % clock_text(opens, tz)
		if row["kind"] != "gone" and s.points(n) > 0:
			row["sub"] = str(row["sub"]) + " · Programm %d/%d" % [s.points(n), SeasonClock.DAILY_MAX]
		out.append(row)
	return out


## The stairs of a season that do not lead down now (09 §2.6; SeasonRules.gate for "descend"): {} when they are open,
## else {"why" (floor_closed | no_stairs | …), "text" ("Etage 4: Kulissen im Aufbau — öffnet in 1 T 6 Std." …),
## "binge" (the tempo offer fits: a private calendar season — "Am Stück" has no such limit)}.
static func stairs_view(state: GameState, data: GameData) -> Dictionary:
	var s: SeasonState = state.season if state != null else null
	if s == null or state.floor_run == null:
		return {}
	var why: String = SeasonRules.gate(state, data, {"t": "descend"}, false)
	if why == "":
		return {}
	var next: int = state.floor_run.index + 1
	var text: String = "Die Treppe ist gerade gesperrt."
	var binge: bool = false
	match why:
		"floor_closed":
			var wait: String = short(SeasonRules.opens_in(state, next))      # "1 T 6 Std." ends with its own period
			text = "Etage %d: Kulissen im Aufbau — öffnet in %s" % [next, wait] + (" " if wait.ends_with(".") else
				". ") + "Eine Etage dürfen Sie vorgehen, weiter baut die Regie noch nicht."
			binge = SeasonRules.refusal(state, data, {"t": "season", "v": Command.SEASON_VERSION, "op": "tempo"}) == ""
			if binge:
				text += " Oder Sie spielen ab jetzt Am Stück: ohne Termine, ohne Warten."
		"no_stairs":
			text = "Hier geht es nicht tiefer: Auf der letzten Etage öffnet der Schlüssel des Revier-Bosses das " + \
				"Finalstudio."
	return {"why": why, "text": text, "binge": binge}


## The collapse display of the HUD (09 §2.5 Nr. 6; calendar only): the collapse of the floor the candidate stands on.
## `extra` = season seconds since the last clock command (the wall clock ran on: the display stays smooth between the
## recorded 60-s steps). {} without a calendar season or a date; else {"floor", "at", "left" (seconds), "level" (0
## calm, 1 ≤ 1 h, 2 ≤ 10 min, 3 ≤ 1 min), "ahead" (the candidate is on a floor below the one on air), "text", "sub"}.
static func collapse_view(state: GameState, extra: int, tz: int) -> Dictionary:
	var s: SeasonState = state.season if state != null else null
	if s == null or s.tempo != "calendar" or state.floor_run == null or s.result != "":
		return {}
	var n: int = state.floor_run.index
	var at: int = collapse_at(s, n)
	if at < 0 or n <= s.collapsed:
		return {}
	var left: int = maxi(0, at - s.utc - maxi(0, extra))
	var level: int = 0
	for i in WARN_SEC.size():
		if left <= WARN_SEC[i]:
			level = i + 1
	var ahead: bool = n > s.on_air()
	var text: String = ("Etage %d · " % n if ahead else "") + "Einsturz %s" % clock_text(at, tz)
	if left < DAY and not ahead:
		text = "Einsturz um %s" % hhmm(at + tz)
	return {"floor": n, "at": at, "left": left, "level": level, "ahead": ahead, "text": text,
		"sub": "in %s" % short(left) if left > 0 else "jetzt"}


## The counter (09 §2.3): {"kind", "label", "n", "of", "text": "Weiße Weste 41/100"}; {} without a season.
static func counter(state: GameState, data: GameData) -> Dictionary:
	var c: Dictionary = CastSim.counter(state, data)
	if c.is_empty():
		return c
	c["text"] = "%s %d/%d" % [str(c["label"]), int(c["n"]), int(c["of"])]
	return c


## "Platz 12 von 100" (the candidate's place; "" without a cast).
static func rank_text(state: GameState, data: GameData) -> String:
	var r: int = CastSim.rank_of(state, data, 0)
	if r <= 0:
		return ""
	return "Platz %d von %d" % [r, int(CastSim.counter(state, data).get("of", 0))]


# ======================================================================================================================
# Ranking, ticker, the floor
# ======================================================================================================================

## The ranking around the candidate (09 §2.7, V-11: privately every place, the AI labelled): the first `top` places,
## then the candidate's place with `around` places on each side; a {"gap": true} row marks skipped places between them
## (the places after the last row need none: "Platz 12 von 100" says how many there are). Each row
## {"rank", "label", "ai", "me", "quote", "floor", "result"}.
static func ranking_rows(state: GameState, data: GameData, top: int = 3, around: int = 1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var all: Array[Dictionary] = CastSim.ranking(state, data)
	var mine: int = 0
	for r: Dictionary in all:
		if int(r["place"]) == 0:
			mine = int(r["rank"])
	var last: int = 0
	for r: Dictionary in all:
		var rank: int = int(r["rank"])
		var keep: bool = rank <= top or (mine > 0 and absi(rank - mine) <= around)
		if not keep:
			continue
		if last > 0 and rank > last + 1:
			out.append({"gap": true})
		out.append({"rank": rank, "label": str(r["label"]), "ai": bool(r["ai"]), "me": int(r["place"]) == 0,
			"quote": int(r["quote"]), "floor": int(r["floor"]), "result": str(r["result"])})
		last = rank
	return out


## The ticker of the last `hours` (09 §4.6), newest first, at most `limit`: {"ago": "vor 3 Std.", "text"} — the
## M.O.D. wording of the breaking news (its line chosen by the event number).
static func ticker_rows(state: GameState, data: GameData, hours: int = 24, limit: int = 8) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var items: Array[Dictionary] = CastSim.ticker(state, data, hours)
	var now: int = CastSim.now(state)
	for i in range(items.size() - 1, -1, -1):
		var it: Dictionary = items[i]
		var text: String = UiUtil.mod_line(str(it["tag"]), it["ctx"] as Dictionary, int(it["seq"]))
		if text == "":
			continue
		var ago: int = now - int(it["t"])
		out.append({"ago": "gerade eben" if ago < 60 else "vor %s" % short(ago), "text": text})
		if out.size() >= limit:
			break
	return out


## The floor the candidate stands on (09 §3.3, §4.3): its programme points {"n", "name", "new"} (a point whose room
## was not entered yet is NEU), the next air time, the Pechvogel in need {"place", "label"} and the guest along.
static func floor_view(state: GameState, data: GameData, tz: int) -> Dictionary:
	var out: Dictionary = {"points": [], "next": "", "need": {}, "guest": {}, "favors": 0}
	var s: SeasonState = state.season if state != null else null
	var fr: FloorRun = state.floor_run if state != null else null
	if s == null or fr == null:
		return out
	var def: FloorDef = data.floor_def(fr.index) if data != null else null
	var th: ThemeDef = data.theme(def.kulisse()) if def != null and def.kulisse() != "" \
		and data.has_id("themes", def.kulisse()) else null
	var layout: FloorLayout = SleepResolver.layout_of(state, data)
	var points: Array[Dictionary] = []
	for i in fr.daily.size():
		var id: String = fr.daily[i]
		var nm: String = th.point_name(id) if th != null else ""
		var cell: Vector2i = Vector2i(-1, -1)
		if layout != null:
			for p: Dictionary in layout.programme:
				if int(p.get("n", 0)) == i + 1:
					cell = p["cell"] as Vector2i
		points.append({"n": i + 1, "name": nm if nm != "" else "Programmpunkt %d" % (i + 1),
			"new": cell != Vector2i(-1, -1) and not fr.visited.has(cell)})
	out["points"] = points
	if s.tempo == "calendar" and s.points(fr.index) < SeasonClock.DAILY_MAX and fr.index > s.collapsed:
		out["next"] = clock_text(s.next_air_utc, tz)
	var need: int = CastSim.in_need(state, data)
	if need >= 0:
		out["need"] = {"place": need, "label": CastSim.label(state, data, need)}
	out["guest"] = CastSim.guest(state, data)
	out["favors"] = CastSim.favors(state, data)
	return out


## The AI candidates in this safe room (09 §4.3, F-14; all of them on the candidate's floor): {"place", "label",
## "profile", "profile_name", "line" (place and level), "rank", and for a Helfer:in "hire_refusal" ("" = can be hired)
## and "hire_cost" (a favour or the credits)}.
static func guest_rows(state: GameState, data: GameData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: int in CastSim.safe_room_guests(state, data):
		var v: Dictionary = CastSim.member_view(state, data, p)
		if v.is_empty():
			continue
		var row: Dictionary = {"place": p, "label": str(v["label"]), "profile": str(v["profile"]),
			"profile_name": str(PROFILE_NAMES.get(str(v["profile"]), v["profile_name"])),
			"line": "Platz %d · Stufe %d" % [CastSim.rank_of(state, data, p), int(v["level"])],
			"rank": CastSim.rank_of(state, data, p)}
		if str(v["profile"]) == "helper":
			var why: String = CastSim.refusal(state, data, {"t": "cast", "op": "hire", "who": p})
			row["hire_refusal"] = why
			row["hire_cost"] = hire_cost_text(state, data)
		out.append(row)
	return out


## "1 Gefallen" while the candidate holds one (a favour pays first), else "150 Credits" (CastSim.hire_cost).
static func hire_cost_text(state: GameState, data: GameData) -> String:
	if CastSim.favors(state, data) > 0:
		return "1 Gefallen"
	return "%s Credits" % UiUtil.fmt_int(CastSim.hire_cost(state))


static func cast_reason(reason: String) -> String:
	return str(CAST_REASONS.get(reason, CAST_REASONS["not_allowed"]))


# ======================================================================================================================
# The end of a season: summary, hall of fame
# ======================================================================================================================

## The headline of a result ("Bis zum Ende dabei", "Verschüttet auf Etage 4" …).
static func result_title(result: String, result_floor: int) -> String:
	match result:
		"finalist":
			return "Großes Finale gewonnen"
		"end":
			return "Bis zum Ende dabei"
		"buried":
			return "Verschüttet auf Etage %d" % result_floor
		"fallen":
			return "Gefallen auf Etage %d" % result_floor
		"left":
			return "Ausgestiegen auf Etage %d" % result_floor
	return "Die Staffel läuft"


## The M.O.D. tag of a result (the summary's quote).
static func result_tag(result: String) -> String:
	match result:
		"finalist":
			return "season_finale"
		"end":
			return "season_end"
		"buried", "fallen":
			return "season_out"
		"left":
			return "season_left"
	return ""


## The key of a season in the hall of fame (template, number, day 0 — unique per device).
static func hall_key(state: GameState) -> String:
	var s: SeasonState = state.season if state != null else null
	if s == null:
		return ""
	return "%s#%d#%d" % [s.def_id, s.number, s.day0_utc]


## The hall-of-fame entry of a finished season (09 §2.7, §2.8): the result, the titles, the Quote and the place, the
## floors, the figures (hero, classes, levels) — no name (08 P-1: the name lives in the persona file only), ids and
## numbers. `ended` = the wall clock of the end (unix). {} while the season runs.
static func hall_entry(state: GameState, data: GameData, ended: int) -> Dictionary:
	var s: SeasonState = state.season if state != null else null
	if s == null or s.result == "":
		return {}
	var kai: PartyMember = state.member("kai")
	var mop: PartyMember = state.member("mopsula")
	var c: Dictionary = CastSim.counter(state, data)
	return {"v": 1, "key": hall_key(state), "def": s.def_id, "number": s.number, "format": s.format,
		"tempo": s.tempo, "mode": s.mode, "result": s.result, "floor": s.result_floor,
		"titles": Array(SeasonRules.titles(state, data)), "quote": SeasonRules.quote(state),
		"rank": CastSim.rank_of(state, data, 0), "places": int(c.get("of", 0)) if CastSim.has_cast(state) else 0,
		"stairs": s.stairs, "qbosses": s.qbosses, "fbosses": s.fbosses, "rescues": s.rescues, "deaths": s.deaths,
		"vest": s.vest, "hero": state.hero, "level": kai.level if kai != null else 1,
		"level_mop": mop.level if mop != null else 1, "class": kai.class_id if kai != null else "",
		"class_mop": mop.class_id if mop != null else "", "followers": state.show.followers if state.show != null else 0,
		"play_sec": floori(state.play_time_sec), "day0": s.day0_utc, "ended": ended}


## The stats of the summary / a hall card: [[label, value], …].
static func stat_pairs(e: Dictionary) -> Array[Array]:
	var out: Array[Array] = []
	out.append(["Quote", UiUtil.fmt_int(int(e.get("quote", 0)))])
	if int(e.get("rank", 0)) > 0:
		out.append(["Platz", "%d von %d" % [int(e["rank"]), int(e.get("places", 0))]])
	out.append(["Etagen per Treppe", str(int(e.get("stairs", 0)))])
	out.append(["Revier-Bosse", str(int(e.get("qbosses", 0)))])
	out.append(["Etagenbosse", str(int(e.get("fbosses", 0)))])
	out.append(["Rettungen", str(int(e.get("rescues", 0)))])
	out.append(["Tode", str(int(e.get("deaths", 0)))])
	out.append(["Stufe", "%d · Graf %d" % [int(e.get("level", 1)), int(e.get("level_mop", 1))]])
	out.append(["Spielzeit", short(int(e.get("play_sec", 0)))])
	out.append(["Follower", UiUtil.fmt_int(int(e.get("followers", 0)))])
	return out


## "Kandidat:in · Abrissbirne" / "Graf Mopsula · Medicus honoris causa" (the classes of an entry; no name, H-7).
static func figures_text(data: GameData, e: Dictionary) -> String:
	var parts: PackedStringArray = []
	for pair: Array in [["Kandidat:in", str(e.get("class", ""))], ["Graf Mopsula", str(e.get("class_mop", ""))]]:
		var cid: String = str(pair[1])
		var cname: String = data.class_def(cid).name if data != null and cid != "" and data.has_id("classes", cid) \
			else ""
		parts.append(str(pair[0]) + (" (%s)" % UiUtil.tr_text(cname) if cname != "" else ""))
	return " · ".join(parts)


## The final ranking of the season as it will be (a studio guest's "Zeitraffer bis zum Finale", 09 §7.2): a copy of
## the state runs the clock to the last collapse — the candidate's result stays, the AI cast plays on; the recorded
## state is never touched. Rows like ranking_rows.
static func projection(state: GameState, data: GameData, top: int = 5, around: int = 1) -> Array[Dictionary]:
	var s: SeasonState = state.season if state != null else null
	if s == null or not CastSim.has_cast(state):
		var none: Array[Dictionary] = []
		return none
	var copy: GameState = GameState.from_dict(state.to_dict())
	var cs: SeasonState = copy.season
	if cs.tempo == "calendar" and cs.collapsed < cs.format and not cs.collapse_utc.is_empty():
		var last: int = cs.collapse_utc[cs.collapse_utc.size() - 1]
		SeasonRules.advance(copy, data, maxi(1, last - cs.utc + 1), false)
	CastSim.advance(copy, data)
	return ranking_rows(copy, data, top, around)


# ======================================================================================================================
# The calendar file (09 §2.4, V-9: local, the collapse and opening dates, no personal data)
# ======================================================================================================================

## "staffel_3_sendeplan.ics".
static func ics_name(state: GameState) -> String:
	var n: int = state.season.number if state != null and state.season != null else 0
	return "staffel_%d_sendeplan.ics" % n


## The schedule as an iCalendar text (RFC 5545, UTC times, CRLF, folded lines): one event per collapse still to come,
## the opening of the floor two below in its description. No name, no persona — the season number, floors, dates.
## `stamp` = the wall clock of the export (DTSTAMP). "" without an open date (or Am Stück: no dates).
static func ics_text(state: GameState, data: GameData, stamp: int) -> String:
	var s: SeasonState = state.season if state != null else null
	if s == null or s.tempo != "calendar" or s.collapsed >= s.format:
		return ""
	var lines: PackedStringArray = ["BEGIN:VCALENDAR", "VERSION:2.0",
		"PRODID:-//NOVA SYNDIKAT//PRIME TIME DUNGEON Sendeplan//DE", "CALSCALE:GREGORIAN", "METHOD:PUBLISH",
		"X-WR-CALNAME:" + _ics_escape("PRIME TIME DUNGEON · Staffel %d" % s.number)]
	for n in range(s.collapsed + 1, s.format + 1):
		var at: int = collapse_at(s, n)
		var desc: String = "PRIME TIME DUNGEON, Staffel %d: Etage %d „%s“ stürzt ein." % [s.number, n,
			floor_name(data, n)]
		if n + 2 <= s.format and n + 2 > SeasonClock.OPEN_FROM_START:
			desc += " Etage %d öffnet." % (n + 2)
		if n == s.format:
			desc += " Das ist das Ende der Staffel."
		lines.append("BEGIN:VEVENT")
		lines.append("UID:ptd-s%d-%d-e%d@prime-time-dungeon.invalid" % [s.number, s.day0_utc, n])
		lines.append("DTSTAMP:" + _ics_time(stamp))
		lines.append("DTSTART:" + _ics_time(at))
		lines.append("DURATION:PT%dM" % ICS_EVENT_MIN)
		lines.append("SUMMARY:" + _ics_escape("Etage %d stürzt ein (Staffel %d)" % [n, s.number]))
		lines.append("DESCRIPTION:" + _ics_escape(desc))
		lines.append("TRANSP:TRANSPARENT")
		lines.append("END:VEVENT")
	lines.append("END:VCALENDAR")
	var out: String = ""
	for l: String in lines:
		out += _ics_fold(l) + "\r\n"
	return out


## Writes the .ics file into `dir` (default user://exports); the absolute path, or "" when there is nothing to export
## or the write failed.
static func export_ics(state: GameState, data: GameData, stamp: int, dir: String = ICS_DIR) -> String:
	var text: String = ics_text(state, data, stamp)
	if text == "":
		return ""
	if not DirAccess.dir_exists_absolute(dir) and DirAccess.make_dir_recursive_absolute(dir) != OK:
		return ""
	var path: String = dir.path_join(ics_name(state))
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(text)
	f.close()
	return ProjectSettings.globalize_path(path)


static func _ics_time(utc: int) -> String:
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(utc)
	return "%04d%02d%02dT%02d%02d%02dZ" % [int(d["year"]), int(d["month"]), int(d["day"]), int(d["hour"]),
		int(d["minute"]), int(d["second"])]


static func _ics_escape(text: String) -> String:
	return text.replace("\\", "\\\\").replace(";", "\\;").replace(",", "\\,").replace("\n", "\\n")


## RFC 5545 §3.1: content lines longer than 75 octets continue on the next line after CRLF + one space (never inside a
## UTF-8 character).
static func _ics_fold(line: String) -> String:
	var out: String = ""
	var octets: int = 0
	for i in line.length():
		var ch: String = line[i]
		var size: int = ch.to_utf8_buffer().size()
		if octets + size > ICS_LINE_OCTETS:
			out += "\r\n "
			octets = 1
		out += ch
		octets += size
	return out
