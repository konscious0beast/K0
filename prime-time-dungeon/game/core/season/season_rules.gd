class_name SeasonRules extends RefCounted
## The season rules (09 §2, §3.3, §7, §9.1; ST1-B): the commands "season" (start, tempo, pause, leave), "clock" and
## "sleep" (the logout with its tactic), the gate every command passes in a season (RunRules.command_refusal), the
## hooks of the run (floor start, safe room, stairs, combat end, the Am-Stück countdown) and the queries of the UI —
## staircase rule from floor 4, collapses (logged in, as a sleeper, after a combat with two minutes of grace), rescue
## with the fee at most once per seven days and the free carry of sleepers in a safe room, the dress rehearsal on floor
## 1, death Mit Netz / Ohne Netz, the Ohne-Netz unlock, the daily programme, the Quote and the titles, the migration of
## a campaign save. Static and pure (core): no autoloads, no clock (the season clock moves only through "clock" /
## "away"), integer math, randomness only from SeedUtil streams of the run seed; the live game (Game's season facades
## through RunRules.apply_season, Game.apply_battle_result, Game._dispatch) and RunSim (apply, _book_result, the tick)
## call the same functions. Layer (02_TECH §0.8): uses core/data, core/dungeon, core/progression; core/live uses it.
## The floor change of a rescue happens here (FloorRun.create + on_floor_start); the callers finish it on the event
## "rescue" (RunRules.season_moved: the twists of the old floor end; hype, Sponsor-Fenster, their own floor context).
##
## Events (ExploreEvent.Type.SEASON, tick 0 — RunSim stamps its tick), data {"kind", …}:
##   start {number, format, tempo, mode, day0_utc} · collapse {floor} (every floor, wherever the candidate is) ·
##   opened {floor} (the stairs limit moved, 09 §2.6) · hold {floor, until} (the collapse waits after a combat) ·
##   rescue {from, floor, location, credits, followers, waived: "" | rehearsal | sleeper | week} ·
##   death {floor, location, credits, waived} · out {why: fallen | buried, floor} · finale {floor} ·
##   end {why: last | content, floor} · left {floor} · daily {floor, n, id} (a programme point on the candidate's
##   floor) · pause {sec, why} · tempo {tempo} · sleep {tactic, room}

## Kept from ST0 (09 §11.4: the public API stays) — no command is refused with it since ST1-B.
const UNAVAILABLE: String = "season_unavailable"
const NO_SEASON: String = "no_season"                # == RunRules.NO_SEASON (core/live decides it first)
## Refusal reasons (both verifiers report them; Game's facades record nothing then).
const REASONS: PackedStringArray = ["season_started", "season_late", "unknown_season", "not_private",
	"format_mismatch", "bad_start", "schedule_mismatch", "binge", "asleep", "season_over", "clock_jump", "tempo",
	"pause_budget", "no_stairs", "floor_closed", "event_run", "not_allowed"]
## 09 §2.5 Nr. 3: the rescue fee −30 % credits, −10 % followers; 09 §7.1: the medics −10 % credits.
const RESCUE_CREDITS_PCT: int = 30
const RESCUE_FOLLOWERS_PCT: int = 10
const DEATH_CREDITS_PCT: int = 10
## The Quote (09 §2.7, start values).
const QUOTE_STAIRS: int = 1000
const QUOTE_QBOSS: int = 200
const QUOTE_FBOSS: int = 500
const QUOTE_FINALE: int = 3000
const QUOTE_ACHIEVEMENT: int = 50
const QUOTE_FOLLOWERS_CAP: int = 20000
const QUOTE_FOLLOWERS_DIV: int = 10
const QUOTE_RESCUE: int = 500
const QUOTE_DEATH: int = 200
## 09 §8.7, §11.1: a campaign save becomes a private season (Am Stück) from the SIM_VERSION bump on, when
## "Sendung starten" replaces the campaign (the ST1 gate); RunSim.SIM_VERSION is 4 until then — Save asks.
const CAMPAIGN_SEASON_SIM_VERSION: int = 5
const MIGRATION_TEMPO: String = "binge"
const START: StringName = &"start"                   # == RunRules.LOCATION_START (FloorRun.location outside a room)


# ======================================================================================================================
# Commands
# ======================================================================================================================

## "" or why the command `c` ("season" incl. its start, "clock", "sleep") is refused now. Read-only.
## - start: a season already runs → season_started; a floor started already → season_late (09 §9.1: the start comes
##   before floor / hero / persona); unknown template → unknown_season; not private → not_private (ST1: private only);
##   another format than the template's → format_mismatch; the start time "utc" (optional, default day0_utc) not in
##   (day0_utc − 1 day, day0_utc] → bad_start; collapse_utc ≠ SeasonClock.schedule(day0_utc, format) →
##   schedule_mismatch (a forged schedule, V-17)
## - tempo (calendar → Am Stück, private only): already binge → tempo; asleep / over
## - pause: Am Stück → binge; "user" beyond 14 days per season → pause_budget; the season over → season_over
## - leave: asleep → asleep; the candidate's season already over → season_over
## - clock: Am Stück → binge (no calendar); asleep → asleep (the absence is "away"); every floor collapsed →
##   season_over; more than seven days at once → clock_jump (V-17: longer jumps are a pause "clamp" + "away")
## - sleep: asleep already → asleep; the candidate's season over → season_over; no floor → not_allowed
static func refusal(state: GameState, data: GameData, c: Dictionary) -> String:
	var t: String = str(c.get("t", ""))
	if t == "season" and str(c.get("op", "")) == "start":
		return _start_refusal(state, data, c)
	var s: SeasonState = state.season if state != null else null
	if s == null:
		return NO_SEASON
	match t:
		"season":
			return _op_refusal(state, data, c)
		"clock":
			if s.tempo == "binge":
				return "binge"
			if s.asleep:
				return "asleep"
			if season_over(state):
				return "season_over"
			if JsonUtil.to_int(c.get("sec", 0)) > SeasonClock.MAX_JUMP_SEC:
				return "clock_jump"
			return ""
		"sleep":
			if s.asleep:
				return "asleep"
			if s.result != "":
				return "season_over"
			return "" if state.floor_run != null else "not_allowed"
	return "not_allowed"


## Applies an accepted command (refusal == ""); the explore events it causes.
static func apply(state: GameState, data: GameData, c: Dictionary) -> Array[ExploreEvent]:
	var out: Array[ExploreEvent] = []
	match str(c.get("t", "")):
		"season":
			match str(c.get("op", "")):
				"start":
					return _start(state, c)
				"tempo":
					return _tempo(state)
				"pause":
					return _pause(state, JsonUtil.to_int(c.get("sec", 0)), str(c.get("why", "user")))
				"leave":
					var s: SeasonState = state.season
					s.result = "left"
					s.result_floor = state.floor_run.index if state.floor_run != null else 0
					out.append(_ev("left", {"floor": s.result_floor}))
		"clock":
			return advance(state, data, JsonUtil.to_int(c.get("sec", 0)))
		"sleep":
			var sl: SeasonState = state.season
			sl.asleep = true
			sl.sleep_tactic = str(c.get("tactic", "careful"))
			var fr: FloorRun = state.floor_run
			sl.sleep_room = String(fr.location) if fr != null and fr.location != START else ""
			out.append(_ev("sleep", {"tactic": sl.sleep_tactic, "room": sl.sleep_room}))
	return out


## The gate of every command in a season (RunRules.command_refusal, before its own checks; read-only). Without a
## season only the start of one in an event run is refused (event_run) — every run of today passes unchanged. With a
## season: its own commands (season, clock, away, sleep) decide themselves; while the figure sleeps everything else →
## asleep (the next session begins with "away", 09 §9.1); once the candidate's season is over (studio guest,
## finalist, left) → season_over; the first floor of a season is floor 1; "descend" follows the staircase rule
## (stairs_refusal).
static func gate(state: GameState, data: GameData, c: Dictionary, event_run: bool) -> String:
	if state == null:
		return ""
	var t: String = str(c.get("t", ""))
	var s: SeasonState = state.season
	if s == null:
		return "event_run" if event_run and t == "season" and str(c.get("op", "")) == "start" else ""
	if t == "season" or t == "clock" or t == "away" or t == "sleep":
		return ""
	if s.asleep:
		return "asleep"
	if s.result != "":
		return "season_over"
	match t:
		"floor":
			if state.floor_run == null and JsonUtil.to_int(c.get("floor", 0)) != 1:
				return "not_allowed"
		"descend":
			return stairs_refusal(state, data)
	return ""


# ======================================================================================================================
# The clock (09 §2.4, §2.5, §3.3; V-17)
# ======================================================================================================================

## Moves the season clock by `sec` (calendar; "clock" here, "away" through the SleepResolver of ST1-G) and plays every
## date it passes in order — a collapse before an air time at the same second: the collapse of the floor on air (the
## candidate on it is rescued, out or at the end of the season; a sleeper in a safe room is carried for free), then
## the air time (a programme point for every open floor that has fewer than five). `combat_grace`: when a combat ended
## since the last clock command (SeasonState.after_combat — this command brings its time), a collapse that falls into
## it waits until two minutes after its end (hold, 09 §2.5 Nr. 2).
static func advance(state: GameState, data: GameData, sec: int, combat_grace: bool = true) -> Array[ExploreEvent]:
	var out: Array[ExploreEvent] = []
	var s: SeasonState = state.season if state != null else null
	if s == null or sec <= 0 or s.tempo == "binge":
		return out
	var target: int = s.utc + sec
	var grace: bool = combat_grace and s.after_combat
	s.after_combat = false
	var guard: int = 4 * (s.format + SeasonClock.end_day(s.format) + 8)
	while guard > 0:
		guard -= 1
		var tc: int = _next_collapse_utc(s)
		var ta: int = s.next_air_utc if s.collapsed < s.format else -1
		if tc >= 0 and (ta < 0 or tc <= ta):
			if tc > target:
				break
			if grace:                              # V-17: the collapse waits for the combat's end + 2 min
				grace = false
				s.hold_utc = target + SeasonClock.COMBAT_GRACE_SEC
				out.append(_ev("hold", {"floor": s.on_air(), "until": s.hold_utc}))
				continue
			s.utc = maxi(s.utc, tc)
			out.append_array(_collapse(state, data))
		elif ta >= 0:
			if ta > target:
				break
			s.utc = maxi(s.utc, ta)
			out.append_array(_air(state, data))
		else:
			break
	s.utc = maxi(s.utc, target)
	return out


## Am Stück (09 §2.1, V-2): the countdown of the candidate's floor reached 0:00 (RunSim step 1, TIMER_EXPIRED) — that
## floor collapses (rescue, out or the end like in the calendar).
static func on_countdown_end(state: GameState, data: GameData) -> Array[ExploreEvent]:
	var out: Array[ExploreEvent] = []
	var s: SeasonState = state.season if state != null else null
	var fr: FloorRun = state.floor_run if state != null else null
	if s == null or fr == null or s.result != "":
		return out
	s.collapsed = maxi(s.collapsed, mini(fr.index, s.format))
	out.append(_ev("collapse", {"floor": fr.index}))
	out.append_array(_collapse_hits(state, data, fr.index))
	return out


## True while the floor countdown stands (RunSim step 1 counts only the floor's time): in the calendar tempo the floor
## ends with its collapse date, not with a countdown (09 §2.1).
static func floor_timer_frozen(state: GameState) -> bool:
	return state != null and state.season != null and state.season.tempo != "binge"


## The season time "now" (SeasonState class doc): calendar = the season clock, Am Stück = the binge clock.
static func now(state: GameState) -> int:
	var s: SeasonState = state.season if state != null else null
	if s == null:
		return 0
	if s.tempo != "binge":
		return s.utc
	return s.binge_utc0 + SeasonClock.BINGE_FACTOR * (s.binge_sec + _used_sec(state.floor_run) - s.binge_mark)


# ======================================================================================================================
# Hooks of the run
# ======================================================================================================================

## RunRules.start_floor (the "floor" command and a rescue): the new floor of a season — Am Stück its countdown (20 /
## 30 / 40 / 50 min, × 1.5 Vorabend; no grace) and its programme point on entering, the binge clock counts the floor
## left (`prev`), the medics' safe room resets, reached, the floor's programme ids (FloorRun.daily).
static func on_floor_start(state: GameState, data: GameData, prev: FloorRun) -> void:
	var s: SeasonState = state.season if state != null else null
	var fr: FloorRun = state.floor_run if state != null else null
	if s == null or fr == null:
		return
	if s.tempo == "binge":
		if prev != null:
			s.binge_sec += _used_sec(prev) - s.binge_mark
		fr.time_left_ticks = SeasonClock.binge_ticks(fr.index, state.difficulty == &"vorabend")
	s.binge_mark = 0
	s.last_safe_room = ""
	if fr.index >= 1 and fr.index <= s.format:
		if s.reached_at(fr.index) < 0:
			s.set_reached(fr.index, now(state))
		if s.tempo == "binge" and s.points(fr.index) == 0:
			s.set_points(fr.index, 1)
	_sync_daily(state, data)


## RunRules.enter_safe_room: the medics bring a fallen party to the safe room entered last on this floor (09 §7.1).
static func on_safe_room(state: GameState, safe_room_id: String) -> void:
	if state != null and state.season != null:
		state.season.last_safe_room = safe_room_id


## The stairs were taken ("descend"; RunSim.apply, Game.complete_floor, GameReplay): the Quote counts the floor, the
## tie-break its time (09 §2.7). Stairs below the last floor with playable content (last_floor; floors 2–18 come with
## ST1-C) lead to the end of the content: the candidate's season ends there ("end", why "content" — ST1-B decision).
static func on_descend(state: GameState, data: GameData) -> Array[ExploreEvent]:
	var out: Array[ExploreEvent] = []
	var s: SeasonState = state.season if state != null else null
	var fr: FloorRun = state.floor_run if state != null else null
	if s == null or fr == null:
		return out
	s.stairs += 1
	s.descent_at = now(state)
	if s.result == "" and fr.index >= last_floor(state, data):
		out.append_array(_finish(state, "content", fr.index))
	return out


## The end of every combat in a season (RunSim._book_result, Game.apply_battle_result; after BattleBridge.apply_result):
## its time comes with the next clock command (after_combat, V-17); a victory counts Revier- and Etagenbosse and wins
## the finale on the last floor of the format (09 §2.7); a defeat is the death rule (09 §7: dress rehearsal on floor 1,
## Mit Netz the medics, Ohne Netz out from floor 2).
static func on_combat_end(state: GameState, data: GameData, result: BattleResult) -> Array[ExploreEvent]:
	var out: Array[ExploreEvent] = []
	var s: SeasonState = state.season if state != null else null
	var fr: FloorRun = state.floor_run if state != null else null
	if s == null or result == null or fr == null:
		return out
	s.after_combat = true
	if s.result != "":
		return out
	if result.outcome == BattleResult.Outcome.VICTORY:
		var def: FloorDef = data.floor_def(fr.index) if data != null else null
		if def != null and result.encounter_id != "":
			if result.encounter_id == def.quarter_boss:
				s.qbosses += 1
			if result.encounter_id == def.floor_boss:
				s.fbosses += 1
				if fr.index >= s.format:
					s.result = "finalist"
					s.result_floor = fr.index
					s.finale_at = now(state)
					out.append(_ev("finale", {"floor": fr.index}))
	elif result.outcome == BattleResult.Outcome.DEFEAT:
		out.append_array(_death(state, data))
	return out


# ======================================================================================================================
# Queries
# ======================================================================================================================

## The highest floor open now (09 §2.6; Am Stück: the format).
static func open_floor_max(state: GameState) -> int:
	var s: SeasonState = state.season if state != null else null
	if s == null:
		return 0
	return SeasonClock.open_floor_max(s.collapsed, s.format, s.tempo == "binge")


## "" or why the stairs of the current floor do not lead down now (read-only): the last floor of the format has the
## finale instead → no_stairs; the next floor is more than one floor below the floor on air (calendar, from floor 4) →
## floor_closed ("Kulissen im Aufbau", 09 §2.6). Stairs below the last floor with playable content are open: they end
## the candidate's season (on_descend).
static func stairs_refusal(state: GameState, _data: GameData) -> String:
	var s: SeasonState = state.season if state != null else null
	var fr: FloorRun = state.floor_run if state != null else null
	if s == null or fr == null:
		return ""
	if fr.index >= s.format:
		return "no_stairs"
	if fr.index + 1 > open_floor_max(state):
		return "floor_closed"
	return ""


## Season seconds until `floor` opens (0 = open; calendar: the collapse of floor − 2, a hold included).
static func opens_in(state: GameState, floor: int) -> int:
	var s: SeasonState = state.season if state != null else null
	if s == null or floor <= open_floor_max(state):
		return 0
	var idx: int = SeasonClock.opener_index(floor)
	if idx < 0 or idx >= s.collapse_utc.size():
		return 0
	var at: int = s.hold_utc if idx == s.collapsed and s.hold_utc > 0 else s.collapse_utc[idx]
	return maxi(0, at - s.utc)


## Seconds until the candidate's floor collapses: calendar the season seconds until the floor on air collapses (a hold
## included; -1 when every floor collapsed), Am Stück the explored seconds left on the countdown.
static func collapse_in(state: GameState) -> int:
	var s: SeasonState = state.season if state != null else null
	if s == null:
		return -1
	if s.tempo == "binge":
		return state.floor_run.time_left_ticks / FloorRun.TICKS_PER_SEC if state.floor_run != null else -1
	var tc: int = _next_collapse_utc(s)
	return maxi(0, tc - s.utc) if tc >= 0 else -1


## The last floor this season can reach: the format, or less while the playable floors end earlier (FloorDef.playable;
## floors 2–18 come with ST1-C). 09 ST1-B decision: the season ends there for the candidate — its collapse or its
## stairs — like at the last collapse ("Bis zum Ende dabei"); a rescue never goes to a floor without content.
static func last_floor(state: GameState, data: GameData) -> int:
	var s: SeasonState = state.season if state != null else null
	if s == null or data == null:
		return 0
	var n: int = 0
	while n < s.format and data.floor_def(n + 1) != null and data.floor_def(n + 1).playable:
		n += 1
	return n


## True when every floor of the season collapsed (calendar) or the candidate's Am-Stück season ended — the clock has
## nothing more to move.
static func season_over(state: GameState) -> bool:
	var s: SeasonState = state.season if state != null else null
	if s == null:
		return false
	return s.collapsed >= s.format or (s.tempo == "binge" and s.result != "")


## The candidate watches as a studio guest (09 §7.2) or finished (finalist, end, left).
static func is_spectator(state: GameState) -> bool:
	return state != null and state.season != null and state.season.result != ""


## The medics' destination now (09 §7.1, V-16): the safe room entered last on this floor, else the floor entrance.
static func respawn_point(state: GameState) -> String:
	var s: SeasonState = state.season if state != null else null
	return s.last_safe_room if s != null and s.last_safe_room != "" else String(START)


## "Ohne Netz" is unlocked by the first class choice (the Recall, 06 §3) or a season played to its end (09 §2.2, V-7).
## The account keeps the unlock (Save's career file); the core only says when it happens.
static func unlocks_no_net(state: GameState) -> bool:
	if state == null:
		return false
	for m: PartyMember in state.party:
		if m != null and m.class_id != "":
			return true
	return state.season != null and (state.season.result == "finalist" or state.season.result == "end")


## The Staffel-Quote (09 §2.7, integers): stairs × 1 000 + Revier-Bosse × 200 + Etagenbosse × 500 + finale 3 000 +
## achievements × 50 + ⌊min(followers, 20 000) / 10⌋ − rescues × 500 − deaths × 200 (floor 1 counts neither).
static func quote(state: GameState) -> int:
	var s: SeasonState = state.season if state != null else null
	if s == null:
		return 0
	var achievements: int = state.show.achievements.size() if state.show != null else 0
	var followers: int = state.show.followers if state.show != null else 0
	return s.stairs * QUOTE_STAIRS + s.qbosses * QUOTE_QBOSS + s.fbosses * QUOTE_FBOSS \
		+ (QUOTE_FINALE if s.result == "finalist" else 0) + achievements * QUOTE_ACHIEVEMENT \
		+ mini(maxi(0, followers), QUOTE_FOLLOWERS_CAP) / QUOTE_FOLLOWERS_DIV - s.rescues * QUOTE_RESCUE \
		- s.deaths * QUOTE_DEATH


## The sort key of the ranking (09 §2.7): higher Quote first; ties: the earlier finale, then the earlier last descent
## (never = last). Compare element by element, smaller first.
static func rank_key(state: GameState) -> Array[int]:
	var s: SeasonState = state.season if state != null else null
	var never: int = 1 << 62
	if s == null:
		return [0, never, never]
	return [-quote(state), s.finale_at if s.finale_at >= 0 else never, s.descent_at if s.descent_at >= 0 else never]


## The cosmetic titles the candidate earned (09 §2.7; humans only, private and among friends with "(privat)"): only once
## the candidate's season is over. Ranking titles (Erstbesteiger:in, Quotenkönig:in …) exist only in verified public
## seasons with ≥ 10 humans (ST2, V-11).
static func titles(state: GameState, data: GameData) -> PackedStringArray:
	var out: PackedStringArray = []
	var s: SeasonState = state.season if state != null else null
	if s == null or s.result == "":
		return out
	var def: SeasonDef = data.season_def(s.def_id) if data != null else null
	var tag: String = "" if def != null and def.kind == "public" else " (privat)"
	match s.result:
		"finalist":
			out.append("Finalist:in der Staffel %d%s" % [s.number, tag])
			if s.mode == "net" and s.vest:
				out.append("Weiße Weste" + tag)
			if s.mode == "no_net":
				out.append("Überlebende:r — Ohne Netz" + tag)
		"buried":
			out.append("Studiogast, verschüttet auf Etage %d%s" % [s.result_floor, tag])
		"fallen":
			out.append("Studiogast, gefallen auf Etage %d%s" % [s.result_floor, tag])
	var kai: PartyMember = state.member("kai")
	if kai != null and data != null:
		var ids: Array = kai.professions.keys()
		ids.sort()
		for pid: Variant in ids:
			var pdef: ProfessionDef = data.profession(str(pid)) if data.has_id("professions", str(pid)) else null
			if pdef != null and int(kai.professions[pid]) >= 300:
				out.append("Legende: %s%s" % [pdef.name, tag])
	return out


## The id of the n-th programme point of `floor` (09 §3.3): drawn without repetition from the pool of the floor's
## Kulisse (themes.json "program", ST1-C; order SeedUtil.derive(seed, "daily", floor)); without a pool the placeholder
## "daily_f<floor>_<n>".
static func daily_id(state: GameState, data: GameData, floor: int, n: int) -> String:
	var pool: PackedStringArray = _programme_pool(data, floor)
	if pool.is_empty() or n < 1:
		return "daily_f%d_%d" % [floor, maxi(1, n)]
	var order: PackedInt32Array = _shuffled(pool.size(), SeedUtil.derive(state.seed, "daily", floor))
	return pool[order[(n - 1) % pool.size()]]


## The default template of a new private season (09 §2.2: "größtes eigenes Format" — the private template with the most
## floors, ties in file order; offline every format counts as owned until the purchase exists, V-14); "" without one.
static func default_def(data: GameData) -> String:
	var best: SeasonDef = null
	if data != null:
		for d: SeasonDef in data.all_seasons():
			if d.is_private() and (best == null or d.format > best.format):
				best = d
	return best.id if best != null else ""


# ======================================================================================================================
# The migration of a campaign save (09 §8.7, §11.1)
# ======================================================================================================================

## A campaign state becomes a private season Am Stück (09 §8.7): template `def_id` (Mit Netz, number 1), day 0 and the
## schedule from the wall clock of the load `now_utc` (+ `tz_offset_sec`, the air time of the template), the floor's
## countdown = its time left (no grace; a new anchor), the floors before counted as stairs and reached. Only from
## CAMPAIGN_SEASON_SIM_VERSION on (Save decides); false without a change (a season already, no template, no data).
static func migrate_campaign(state: GameState, data: GameData, def_id: String, now_utc: int,
		tz_offset_sec: int) -> bool:
	if state == null or state.season != null or data == null:
		return false
	var def: SeasonDef = data.season_def(def_id) if data.has_id("seasons", def_id) else null
	if def == null:
		return false
	var s: SeasonState = SeasonState.new()
	s.def_id = def.id
	s.format = def.format
	s.tempo = MIGRATION_TEMPO
	s.mode = "net"
	s.number = 1
	s.day0_utc = SeasonClock.day0(now_utc, maxi(0, SeasonClock.air_seconds(def.air_time)), tz_offset_sec)
	s.collapse_utc = SeasonClock.schedule(s.day0_utc, s.format)
	s.utc = now_utc
	s.next_air_utc = s.day0_utc
	s.binge_utc0 = now_utc
	s.programme = SeasonState._sized([], s.format, 0)
	s.reached = SeasonState._sized([], s.format, -1)
	var fr: FloorRun = state.floor_run
	if fr != null:
		s.binge_mark = _used_sec(fr)
		for f in range(1, mini(fr.index, s.format) + 1):
			s.set_reached(f, now_utc)
		s.stairs = maxi(0, fr.index - 1)
		if fr.index <= s.format:
			s.set_points(fr.index, 1)
	state.season = s
	_sync_daily(state, data)
	return true


# ======================================================================================================================
# Private
# ======================================================================================================================

static func _start_refusal(state: GameState, data: GameData, c: Dictionary) -> String:
	if state == null:
		return "not_allowed"
	if state.season != null:
		return "season_started"
	if state.floor_run != null:
		return "season_late"
	var def_id: String = str(c.get("def", ""))
	var def: SeasonDef = data.season_def(def_id) if data != null and data.has_id("seasons", def_id) else null
	if def == null:
		return "unknown_season"
	if not def.is_private():
		return "not_private"
	if JsonUtil.to_int(c.get("format", 0)) != def.format:
		return "format_mismatch"
	var day0: int = JsonUtil.to_int(c.get("day0_utc", 0))
	if c.has("utc") and not JsonUtil.is_integral(c["utc"]):
		return "bad_start"
	var start: int = JsonUtil.to_int(c.get("utc", day0))
	if start > day0 or start <= day0 - SeasonClock.DAY_SEC:
		return "bad_start"
	var want: Array[int] = SeasonClock.schedule(day0, def.format)
	var have: Variant = c.get("collapse_utc", [])
	if not (have is Array) or (have as Array).size() != want.size():
		return "schedule_mismatch"
	for i in want.size():
		if JsonUtil.to_int((have as Array)[i]) != want[i]:
			return "schedule_mismatch"
	return ""


static func _op_refusal(state: GameState, data: GameData, c: Dictionary) -> String:
	var s: SeasonState = state.season
	var def: SeasonDef = data.season_def(s.def_id) if data != null and data.has_id("seasons", s.def_id) else null
	var private: bool = def == null or def.is_private()
	match str(c.get("op", "")):
		"tempo":
			if s.tempo == "binge":
				return "tempo"
			if not private:
				return "not_private"
			if s.asleep:
				return "asleep"
			return "season_over" if s.result != "" else ""
		"pause":
			if s.tempo == "binge":
				return "binge"
			if not private:
				return "not_private"
			if season_over(state):
				return "season_over"
			if str(c.get("why", "")) == "user" and s.pause_sec + JsonUtil.to_int(c.get("sec", 0)) \
					> SeasonClock.PAUSE_MAX_SEC:
				return "pause_budget"
			return ""
		"leave":
			if s.asleep:
				return "asleep"
			return "season_over" if s.result != "" else ""
	return "not_allowed"


## The start (refusal == ""): the season block from the command; the clock at its start time ("utc", else day 0).
static func _start(state: GameState, c: Dictionary) -> Array[ExploreEvent]:
	var s: SeasonState = SeasonState.new()
	s.def_id = str(c.get("def", ""))
	s.format = JsonUtil.to_int(c.get("format", 6), 6)
	s.tempo = str(c.get("tempo", "calendar"))
	s.mode = str(c.get("mode", "net"))
	s.number = JsonUtil.to_int(c.get("number", 1), 1)
	s.day0_utc = JsonUtil.to_int(c.get("day0_utc", 0))
	s.collapse_utc = SeasonState._ints(c.get("collapse_utc", []))
	var raw_cast: Variant = c.get("cast", {})
	s.cast = (raw_cast as Dictionary).duplicate(true) if raw_cast is Dictionary else {}   # (normalized by the callers)
	s.utc = JsonUtil.to_int(c.get("utc", s.day0_utc), s.day0_utc)
	s.next_air_utc = s.day0_utc
	s.binge_utc0 = s.utc
	s.programme = SeasonState._sized([], s.format, 0)
	s.reached = SeasonState._sized([], s.format, -1)
	state.season = s
	var out: Array[ExploreEvent] = [_ev("start", {"number": s.number, "format": s.format, "tempo": s.tempo,
		"mode": s.mode, "day0_utc": s.day0_utc})]
	return out


## Kalender → Am Stück (09 §2.1, V-6): the countdown of the current floor starts anew; the binge clock continues from
## the season clock.
static func _tempo(state: GameState) -> Array[ExploreEvent]:
	var s: SeasonState = state.season
	s.tempo = "binge"
	s.binge_utc0 = s.utc
	s.binge_sec = 0
	var fr: FloorRun = state.floor_run
	s.binge_mark = _used_sec(fr)
	if fr != null:
		fr.time_left_ticks = SeasonClock.binge_ticks(fr.index, state.difficulty == &"vorabend")
		fr.warned = PackedInt32Array()
	var out: Array[ExploreEvent] = [_ev("tempo", {"tempo": s.tempo})]
	return out


## A pause (09 §2.9, V-9; "clamp" after a clock jump over seven days, §5.5): every open date moves by `sec`.
static func _pause(state: GameState, sec: int, why: String) -> Array[ExploreEvent]:
	var s: SeasonState = state.season
	for i in range(s.collapsed, s.collapse_utc.size()):
		s.collapse_utc[i] += sec
	if s.hold_utc > 0:
		s.hold_utc += sec
	s.next_air_utc += sec
	if why == "user":
		s.pause_sec += sec
	var out: Array[ExploreEvent] = [_ev("pause", {"sec": sec, "why": why})]
	return out


## The date of the next collapse (a hold first); -1 when every floor collapsed.
static func _next_collapse_utc(s: SeasonState) -> int:
	if s.collapsed >= s.format or s.collapsed >= s.collapse_utc.size():
		return -1
	return s.hold_utc if s.hold_utc > 0 else s.collapse_utc[s.collapsed]


## The floor on air collapses (calendar): the floor two below opens; the candidate standing on it is hit.
static func _collapse(state: GameState, data: GameData) -> Array[ExploreEvent]:
	var s: SeasonState = state.season
	var n: int = s.collapsed + 1
	s.collapsed = n
	s.hold_utc = 0
	var out: Array[ExploreEvent] = [_ev("collapse", {"floor": n})]
	if n + 2 > SeasonClock.OPEN_FROM_START and n + 2 <= s.format:
		out.append(_ev("opened", {"floor": n + 2}))
	var fr: FloorRun = state.floor_run
	if s.result == "" and fr != null and fr.index == n:
		out.append_array(_collapse_hits(state, data, n))
	elif s.result == "" and n >= s.format:
		out.append_array(_finish(state, "last", n))
	return out


## The candidate stands on collapsing floor `n` (09 §2.5, §7.3): the last floor of the format ends the season ("Bis zum
## Ende dabei"); the last floor with playable content too (ST1-B decision); floor 1 is the dress rehearsal (a free
## rescue, the vest stays, also Ohne Netz); Ohne Netz → out ("verschüttet"); Mit Netz → the rescue with its fee.
static func _collapse_hits(state: GameState, data: GameData, n: int) -> Array[ExploreEvent]:
	var s: SeasonState = state.season
	if n >= s.format:
		return _finish(state, "last", n)
	if n >= last_floor(state, data):
		return _finish(state, "content", n)
	if n == 1:
		return _rescue(state, data, true)
	if s.mode == "no_net":
		return _out(state, "buried", n)
	return _rescue(state, data, false)


## The rescue (09 §2.5 Nr. 3, V-9): the fee (−30 % credits, −10 % followers) unless it is the dress rehearsal, the
## figure sleeps in a safe room (carried for free) or a fee was charged in the last seven days; from floor 2 the vest
## goes and the Quote counts the rescue; the figure stands (or sleeps on) in the first safe room of the next floor.
static func _rescue(state: GameState, data: GameData, rehearsal: bool) -> Array[ExploreEvent]:
	var s: SeasonState = state.season
	var from: int = state.floor_run.index
	var t: int = now(state)
	var credits: int = 0
	var followers: int = 0
	var waived: String = ""
	if rehearsal:
		waived = "rehearsal"
	elif s.asleep and s.sleep_room != "":
		waived = "sleeper"
	elif not _fee_due(s, t):
		waived = "week"
	else:
		if state.inventory != null:
			credits = state.inventory.credits * RESCUE_CREDITS_PCT / 100
			state.inventory.spend_credits(credits)
		if state.show != null:
			followers = maxi(0, state.show.followers) * RESCUE_FOLLOWERS_PCT / 100
			state.show.followers -= followers
		s.fee_at = t
	if not rehearsal:
		s.vest = false
		s.rescues += 1
	var loc: String = _move(state, data, from + 1)
	var out: Array[ExploreEvent] = [_ev("rescue", {"from": from, "floor": from + 1, "location": loc,
		"credits": credits, "followers": followers, "waived": waived})]
	return out


## The death rule (09 §7.1–§7.3): Ohne Netz from floor 2 → out ("gefallen"); else the medics bring the party to the
## safe room entered last on this floor (else the entrance), full heal; Mit Netz from floor 2 the fee −10 % credits
## (the same seven-day rule as the rescue), the vest goes, the Quote counts the death; floor 1 costs nothing.
static func _death(state: GameState, data: GameData) -> Array[ExploreEvent]:
	var s: SeasonState = state.season
	var fr: FloorRun = state.floor_run
	if fr.index >= 2 and s.mode == "no_net":
		return _out(state, "fallen", fr.index)
	var rehearsal: bool = fr.index == 1
	var t: int = now(state)
	var credits: int = 0
	var waived: String = ""
	if rehearsal:
		waived = "rehearsal"
	elif not _fee_due(s, t):
		waived = "week"
	else:
		if state.inventory != null:
			credits = state.inventory.credits * DEATH_CREDITS_PCT / 100
			state.inventory.spend_credits(credits)
		s.fee_at = t
	if not rehearsal:
		s.vest = false
		s.deaths += 1
	var loc: String = respawn_point(state)
	fr.location = StringName(loc)
	Progression.full_heal(state, data)
	if s.asleep:
		s.sleep_room = loc if loc != String(START) else ""
	var out: Array[ExploreEvent] = [_ev("death", {"floor": fr.index, "location": loc, "credits": credits,
		"waived": waived})]
	return out


static func _out(state: GameState, why: String, floor: int) -> Array[ExploreEvent]:
	var s: SeasonState = state.season
	s.result = why
	s.result_floor = floor
	var out: Array[ExploreEvent] = [_ev("out", {"why": why, "floor": floor})]
	return out


## The candidate's season ends without the finale ("Bis zum Ende dabei", 09 §2.7): the last collapse ("last") or the
## end of the playable floors ("content", last_floor).
static func _finish(state: GameState, why: String, floor: int) -> Array[ExploreEvent]:
	var out: Array[ExploreEvent] = []
	var s: SeasonState = state.season
	if s.result != "":
		return out
	s.result = "end"
	s.result_floor = floor
	out.append(_ev("end", {"why": why, "floor": floor}))
	return out


static func _fee_due(s: SeasonState, t: int) -> bool:
	return s.fee_at < 0 or t - s.fee_at >= SeasonClock.FEE_GAP_SEC


## The season moves the candidate to floor `n` (a rescue): the new FloorRun (like RunRules.start_floor — the twists of
## the old floor end with the event, RunRules.season_moved), on_floor_start, the first safe room (nearest to the
## entrance) as the location. Returns the location.
static func _move(state: GameState, data: GameData, n: int) -> String:
	var def: FloorDef = data.floor_def(n) if data != null else null
	if def == null:
		return String(START)
	var prev: FloorRun = state.floor_run
	state.floor_run = FloorRun.create(def, state.seed, state.difficulty)
	on_floor_start(state, data, prev)
	var loc: String = _first_safe_room(state, data)
	state.floor_run.location = StringName(loc)
	if state.season.asleep:
		state.season.sleep_room = loc if loc != String(START) else ""
	return loc


## The safe room nearest to the entrance of the current floor (BFS through closed gates, ties in layout order; the
## unreachable ones last); START without a safe room.
static func _first_safe_room(state: GameState, data: GameData) -> String:
	var fr: FloorRun = state.floor_run
	var def: FloorDef = data.floor_def(fr.index) if data != null else null
	var layout: FloorLayout = DungeonGenerator.generate(def, fr.seed) if def != null else null
	if layout == null or layout.safe_rooms.is_empty():
		return String(START)
	var dist: Dictionary = layout.distances(layout.start)
	var best: String = ""
	var best_d: int = 1 << 30
	for c: Vector2i in layout.safe_rooms:
		var d: int = int(dist.get(c, 1 << 29))
		if d < best_d:
			best_d = d
			best = str(layout.safe_room_ids.get(c, ""))
	return best if best != "" else String(START)


## An air time passes (09 §3.3): every open floor not yet collapsed gets a programme point (at most five); the
## candidate's floor shows it (FloorRun.daily, event "daily").
static func _air(state: GameState, data: GameData) -> Array[ExploreEvent]:
	var out: Array[ExploreEvent] = []
	var s: SeasonState = state.season
	s.airs += 1
	s.next_air_utc += SeasonClock.DAY_SEC
	var top: int = SeasonClock.open_floor_max(s.collapsed, s.format, false)
	for f in range(s.collapsed + 1, top + 1):
		if s.points(f) >= SeasonClock.DAILY_MAX:
			continue
		s.set_points(f, s.points(f) + 1)
		var fr: FloorRun = state.floor_run
		if s.result == "" and fr != null and fr.index == f:
			_sync_daily(state, data)
			out.append(_ev("daily", {"floor": f, "n": s.points(f), "id": fr.daily[fr.daily.size() - 1]}))
	return out


## FloorRun.daily follows the programme count of its floor (ids in order, daily_id).
static func _sync_daily(state: GameState, data: GameData) -> void:
	var s: SeasonState = state.season
	var fr: FloorRun = state.floor_run
	if s == null or fr == null or fr.index < 1 or fr.index > s.format:
		return
	var want: int = s.points(fr.index)
	while fr.daily.size() < want:
		fr.daily.append(daily_id(state, data, fr.index, fr.daily.size() + 1))


static func _programme_pool(data: GameData, floor: int) -> PackedStringArray:
	var out: PackedStringArray = []
	if data == null:
		return out
	for t: ThemeDef in data.all_themes():
		if not t.floors.has(floor):
			continue
		for e: Variant in t.program:
			var id: String = str((e as Dictionary).get("id", "")) if e is Dictionary else str(e)
			if id != "" and not out.has(id):
				out.append(id)
	return out


## 0 … n − 1 in the deterministic order of `seed` (Fisher–Yates on a SeedUtil generator).
static func _shuffled(n: int, seed: int) -> PackedInt32Array:
	var out: PackedInt32Array = []
	for i in n:
		out.append(i)
	var rng: RandomNumberGenerator = SeedUtil.make_rng(seed)
	for i in range(n - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


## Explored seconds of a floor run (its time_used_ticks: the exploration ticks, in both tempos).
static func _used_sec(fr: FloorRun) -> int:
	return int(fr.stats.get("time_used_ticks", 0)) / FloorRun.TICKS_PER_SEC if fr != null else 0


static func _ev(kind: String, data: Dictionary) -> ExploreEvent:
	var d: Dictionary = {"kind": kind}
	d.merge(data)
	return ExploreEvent.make(ExploreEvent.Type.SEASON, 0, d)
