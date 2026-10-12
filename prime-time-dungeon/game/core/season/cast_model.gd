extends RefCounted
## Private helper of CastSim (02_TECH §0.3: no class_name, preloaded as CastSim.CastModel): the population model of the
## AI cast (09 §4.2) — the places with their roster and state (CastMember), the collapse times and the candidate's
## arrivals per floor, the first ascents, the ticker, the guest — read from the season block, played on and written
## back by CastSim. Integer math only; every roll comes from SeedUtil: the roster from the streams "cast_roster",
## "cast_names" and "cast_profiles" of the season seed, the play from the stream "cast" (per place and hour: every place
## plays each of its hours once — its own cursor `CastMember.t` — so a floor played to its end out of turn never
## reuses a roll). No clock of its own: CastSim hands in the cast time.
##
## The model (09 §4.2; decisions F-3 … F-8 in 09 Kap. 11.3): every AI place plays one session a day — `pace` tenths of
## an hour from `sess` hours after the air time, one step per hour (the calendar's season hour; Am Stück one step per
## 25 s of exploration, the binge clock). A step plays the minutes of that hour: a death roll (by floor, skill and
## mode), else work at a rate by skill (rivals: a rubber band to the candidate's floor) — the floor needs its
## Pflichtweg (20 / 30 / 45 / 60 min at skill 55). Done: the optional Etagenboss, then the stairs when they are open
## (calendar: the staircase rule of 09 §2.6; Am Stück: at most one floor below the candidate's) — or, on the last
## floor of the format, the finale. Collapses hit like for humans: floor 1 the dress rehearsal, Mit Netz the rescue
## with the crash course, Ohne Netz out, the last floor the end of the season.

const VERSION: int = 1
const HOUR: int = 3600
const DAY: int = 86400
## Pflichtweg per floor in minutes (09 §3.3): 20, 30, 45, then 60.
const WORK_MIN: PackedInt32Array = [20, 30, 45, 60]
## Floors with an Etagenboss besides the finale (09 §3.2: floors 1, 2, 3 and the last floor of each Kulisse).
const FBOSS_FLOORS: PackedInt32Array = [1, 2, 3, 6, 9, 12, 15]
## Death chance per played hour at skill 55, per 100 000, by floor 1..18 (09 §4.2 "Todeswurf je Schritt nach Können
## und Etage"; the early floors are the deadly ones — new candidates learn, later floors get harder slowly). Start
## values, calibrated by test_09_cast_sim against the bands of 09 §4.2.
const DEATH: PackedInt32Array = [30000, 12100, 9900, 9100, 9100, 9100, 8200, 8200, 8200, 3200, 3200, 3200, 3200,
	3200, 3200, 3000, 3000, 3000]
## The risk of a skill: ((100 − skill) / 45)² — skill 55 = 1000 ‰, skilled candidates rarely die, weak ones often.
const RISK_MIN: int = 50
const RISK_MAX: int = 3200
const DEATH_NO_NET: int = 380      # ‰: Ohne Netz plays carefully on its first floors (≤ NO_NET_CAREFUL) …
const NO_NET_CAREFUL: int = 3      # … deeper down the floors are as deadly as Mit Netz
const DEATH_SETBACK: int = 250     # ‰ of the floor's work lost by a death (the medics' safe room)
## Work per played minute in ‰ of a minute of the Pflichtweg: 1000 + (skill − 55) × EFF_SKILL − (floor − 1) × EFF_FLOOR.
const EFF_SKILL: int = 12
const EFF_FLOOR: int = 5
const EFF_MIN: int = 450
const EFF_MAX: int = 1600
const EFF_NO_NET: int = 900        # ‰: careful is slower
const RIVAL_AHEAD: int = 700       # ‰ of a rival's rate when ahead of the candidate (09 §4.4: knapp vor oder hinter)
const RIVAL_BEHIND: int = 1300
## The optional Etagenboss: ‰ = (skill − FBOSS_SKILL0) × FBOSS_SLOPE, 0–900.
const FBOSS_SKILL0: int = 25
const FBOSS_SLOPE: int = 12
## The finale: ‰ = (skill − FINALE_SKILL0) × FINALE_SLOPE, 0–950 — a steep gate (09 §4.2: Mit Netz 35–45 % win it,
## with every retry; the weiße Weste needs the first attempt); a lost finale is a death that costs FINALE_SETBACK ‰ of
## the floor's work.
const FINALE_SKILL0: int = 58
const FINALE_SLOPE: int = 80
const FINALE_SETBACK: int = 500
## Ranking estimates of an AI place (the Quote needs achievements and followers, 09 §2.7): per floor by the stairs.
const AI_ACH_BASE: int = 20
const AI_ACH_DIV: int = 25
const AI_ACH_MAX: int = 39         # the achievements of the game (data/achievements.json)
const AI_FOLLOWERS_BASE: int = 600
const AI_FOLLOWERS_SKILL: int = 12
## Ticker entries kept in the season block (09 §4.6: "Ticker der letzten 24 h").
const TICKER_MAX: int = 40
const NEVER: int = 1 << 40
const NO_TIME: int = CastMember.NO_TIME
const HOUR_SALT: int = 4096        # keeps the per-hour salt positive in the Vorprogramm (hours ≥ −24)

var places: int = 0
var humans: int = 0
var format: int = 6
var no_net: bool = false
var binge: bool = false
var seed: int = 0
var members: Array[CastMember] = []
var h: int = 0                     # every place was played up to this hour (exclusive): the last catch-up's target
var hf: int = 1                    # the candidate's floor (place 0) the model knows
var col: int = 0                   # Am Stück: the collapsed floors the model knows (SeasonState.collapsed)
var ct: PackedInt32Array = []      # collapse time per floor (index floor − 1; NO_TIME = not known yet)
var ha: PackedInt32Array = []      # the candidate's arrival per floor (NO_TIME = not yet)
var first_who: PackedInt32Array = []   # the first candidate up the stairs per floor (-1 = nobody yet)
var first_t: PackedInt32Array = []    # … and its time (NO_TIME)
var ai_first: PackedInt32Array = []    # the first AI arrival per floor by the stairs (NO_TIME) — calibration
var ticker: Array[CastEvent] = []
var seq: int = 0
var lead: int = -1                 # the leader of the AI cast (record)
var favors: int = 0                # Gefallen: a helped Pechvogel owes one (09 §4.3)
var guest_who: int = -1
var guest_left: int = 0
var guest_kind: String = ""        # "hire" (a helper, 3 combats) | "help" (the Pechvogel's combat)
var helped_mask: int = 0           # floors where the candidate helped a Pechvogel (bit = floor)
var fboss_mask: int = 0            # floors whose first Etagenboss of the cast was news
var finalists: int = 0
var classes: PackedStringArray = []    # the Recall: Kai's classes and species (a human, no Graf — 09 §4.2)
var species: PackedStringArray = []
var species_rec: Array[PackedStringArray] = []   # per species: its recommended classes
var org_hint: Dictionary = {}      # origin → its spec_hint (a class, 08 §4.8)
# The running catch-up (flush hands it out): the newsworthy events and the places a collapse caught (never stored);
# the earliest AI arrival by the stairs per floor not decided yet (the first ascent: time NO_TIME = none, the place) —
# an arrival later than "now" waits in the season block until its time has come (an hour is played at once, the
# candidate's arrival in the same hour may still come first).
var pending: Array[CastEvent] = []
var batch_t: PackedInt32Array = []
var batch_who: PackedInt32Array = []
var batch_caught: Dictionary = {}  # Vector2i(floor, time) of a collapse → Vector2i(rescued, out)
var open_h: PackedInt64Array = []  # calendar: the first hour the stairs onto floor f are open (index f − 1)


# ======================================================================================================================
# Season block
# ======================================================================================================================

## Reads the cast of the season block `c` (CastSim checks first that it has one: the key "roster").
func read(c: Dictionary, s: SeasonState, p_seed: int, data: GameData) -> void:
	seed = p_seed
	places = JsonUtil.to_int(c.get("places", 0))
	humans = JsonUtil.to_int(c.get("humans", 0))
	format = s.format
	no_net = s.mode == "no_net"
	binge = JsonUtil.to_int(c.get("bg", 0)) == 1
	var roster: PackedStringArray = str(c.get("roster", "")).split(";")
	var state_rows: PackedStringArray = str(c.get("state", "")).split(";")
	for p in places:
		var mb: CastMember = CastMember.from_texts(p, roster[p] if p < roster.size() else "",
			state_rows[p] if p < state_rows.size() else "")
		derive(mb)
		members.append(mb)
	h = JsonUtil.to_int(c.get("h", 0))
	hf = JsonUtil.to_int(c.get("hf", 1), 1)
	col = JsonUtil.to_int(c.get("col", 0))
	seq = JsonUtil.to_int(c.get("seq", 0))
	lead = JsonUtil.to_int(c.get("lead", -1), -1)
	favors = JsonUtil.to_int(c.get("favors", 0))
	helped_mask = JsonUtil.to_int(c.get("helped", 0))
	fboss_mask = JsonUtil.to_int(c.get("fbm", 0))
	finalists = JsonUtil.to_int(c.get("fin", 0))
	ct = _ints(str(c.get("ct", "")), format, NO_TIME)
	ha = _ints(str(c.get("ha", "")), format, NO_TIME)
	first_who = _ints(str(c.get("fw", "")), format, -1)
	first_t = _ints(str(c.get("ft", "")), format, NO_TIME)
	ai_first = _ints(str(c.get("aif", "")), format, NO_TIME)
	for row: String in str(c.get("tick", "")).split(";", false):
		var e: CastEvent = CastEvent.from_text(row)
		if e != null:
			ticker.append(e)
	var g: PackedStringArray = str(c.get("guest", "")).split(",")
	if g.size() == 3:
		guest_who = g[0].to_int()
		guest_left = g[1].to_int()
		guest_kind = g[2]
	batch_t = _ints(str(c.get("bt", "")), format, NO_TIME)
	batch_who = _ints(str(c.get("bw", "")), format, -1)
	_calendar_opens()
	_read_recall(data)


## Writes the model back into the season block (the start block — v, places, humans — stays as it is).
func write(state: GameState) -> void:
	var c: Dictionary = state.season.cast
	var roster: PackedStringArray = []
	var rows: PackedStringArray = []
	for mb: CastMember in members:
		roster.append(mb.roster_text())
		rows.append(mb.state_text())
	c["roster"] = ";".join(roster)
	c["state"] = ";".join(rows)
	c["h"] = h
	c["hf"] = hf
	c["col"] = col
	c["seq"] = seq
	c["lead"] = lead
	c["favors"] = favors
	c["helped"] = helped_mask
	c["fbm"] = fboss_mask
	c["fin"] = finalists
	c["bg"] = 1 if binge else 0
	c["ct"] = _text(ct)
	c["ha"] = _text(ha)
	c["fw"] = _text(first_who)
	c["ft"] = _text(first_t)
	c["aif"] = _text(ai_first)
	c["bt"] = _text(batch_t)
	c["bw"] = _text(batch_who)
	var tick: PackedStringArray = []
	for e: CastEvent in ticker:
		tick.append(e.to_text())
	c["tick"] = ";".join(tick)
	c["guest"] = "%d,%d,%s" % [guest_who, guest_left, guest_kind] if guest_who >= 0 else ""


## A new cast for the season block of `state` (the start command's block: places, humans): the roster from the name
## catalog and the profiles of data/cast.json, the 08 catalog (Vorleben, hobby) and the season seed; everybody on
## floor 1 from `t_start` (cast seconds). Calendar: the collapse dates of the schedule; Am Stück: none yet.
func create(state: GameState, data: GameData, t_start: int) -> void:
	var s: SeasonState = state.season
	seed = state.seed
	places = JsonUtil.to_int(s.cast.get("places", 0))
	humans = JsonUtil.to_int(s.cast.get("humans", 0))
	format = s.format
	no_net = s.mode == "no_net"
	binge = s.tempo == "binge"
	ct = _ints("", format, NO_TIME)
	ha = _ints("", format, NO_TIME)
	first_who = _ints("", format, -1)
	first_t = _ints("", format, NO_TIME)
	ai_first = _ints("", format, NO_TIME)
	batch_t = _ints("", format, NO_TIME)
	batch_who = _ints("", format, -1)
	if not binge:
		for f in range(1, format + 1):
			ct[f - 1] = SeasonClock.end_day(f) * DAY
	_calendar_opens()
	ha[0] = t_start
	var hour0: int = ceil_hour(t_start)            # the AI plays from the first full hour of the season
	h = hour0
	_read_recall(data)
	var names: Array[Dictionary] = data.cast_names() if data != null else ([] as Array[Dictionary])
	var name_order: PackedInt32Array = _shuffled(names.size(), SeedUtil.derive(seed, "cast_names", 0))
	var profiles: PackedStringArray = _profile_quota(data, places - humans,
		SeedUtil.derive(seed, "cast_profiles", 0))
	var origins: Array[Dictionary] = data.all_origins() if data != null else ([] as Array[Dictionary])
	var hobbies: Array[Dictionary] = data.persona_list("hobbies") if data != null else ([] as Array[Dictionary])
	for p in places:
		var mb: CastMember = CastMember.new()
		mb.place = p
		mb.base = SeedUtil.derive(seed, "cast", p)
		mb.t = hour0
		mb.ar = t_start
		if p < humans:
			mb.fx = CastMember.F_HUMAN | CastMember.F_VEST
			derive(mb)
			members.append(mb)
			continue
		var i: int = p - humans
		var r: int = SeedUtil.derive(seed, "cast_roster", p)
		if not names.is_empty():
			var e: Dictionary = names[name_order[i % names.size()]]
			mb.name = str(e.get("name", ""))
			mb.form = str(e.get("form", "n"))
		mb.profile = profiles[i] if i < profiles.size() else "extra"
		mb.skill = _triangular(SeedUtil.mix(r, 1) % 1000, 20, 55, 95)
		mb.pace = _triangular(SeedUtil.mix(r, 2) % 1000, 3, 8, 30)
		mb.org = str(origins[SeedUtil.mix(r, 3) % origins.size()].get("id", "")) if not origins.is_empty() else ""
		mb.hob = str(hobbies[SeedUtil.mix(r, 4) % hobbies.size()].get("id", "")) if not hobbies.is_empty() else ""
		mb.sess = _session_hour(SeedUtil.mix(r, 5))
		derive(mb)
		members.append(mb)


# ======================================================================================================================
# Playing on
# ======================================================================================================================

## Plays every AI place up to the start of hour `until_h` (exclusive) and applies the collapses due by `now_t`.
func catch_up(until_h: int, now_t: int) -> void:
	for mb: CastMember in members:
		if mb.in_play():
			run(mb, until_h, now_t, -1)
	h = maxi(h, until_h)


## Plays `mb` from its next hour up to `until_h` (exclusive); collapses apply once they are due by `now_t`. With
## `stop_floor` ≥ 1 it stops as soon as `mb` is not on that floor any more (a floor played to its end out of turn).
## The hot loop of the model: the session check is inlined (minutes()); the hours outside the session and the hours
## waiting at closed stairs (two thirds of the played hours) are jumped — no roll is lost, a roll belongs to its hour.
func run(mb: CastMember, until_h: int, now_t: int, stop_floor: int) -> void:
	var guard: int = 4 * (until_h - mb.t) + 64
	while mb.fx & CastMember.F_DONE == 0 and guard > 0:
		guard -= 1
		if stop_floor >= 1 and mb.fl != stop_floor:
			return
		var hr: int = mb.t
		var c: int = ct[mb.fl - 1] if mb.fl <= format else NO_TIME
		if c != NO_TIME and c <= hr * HOUR and c <= now_t:
			collapse_hit(mb, c)
			continue
		if hr >= until_h:
			return
		var rel: int = posmod(hr - mb.sess, 24)
		var nxt: int = hr + 24 - rel                  # the next session
		if rel * 60 < mb.per_day:
			var opens: int = hr
			if mb.fl < format and mb.wk >= WORK_MIN[mini(mb.fl, 4) - 1] * 1000:
				opens = open_hour(mb.fl + 1, hr)      # waiting at the stairs: on to the hour they open
			if opens > hr:
				nxt = opens
			else:
				_play(mb, hr, mini(60, mb.per_day - 60 * rel), now_t)
				hr += 1
				if (rel + 1) * 60 < mb.per_day or mb.fx & CastMember.F_DONE != 0:
					mb.t = hr
					continue
				c = ct[mb.fl - 1] if mb.fl <= format else NO_TIME   # the session is over (maybe on a new floor)
		if c != NO_TIME and c > hr * HOUR:
			nxt = mini(nxt, ceil_hour(c))
		mb.t = mini(nxt, until_h)


## Minutes `mb` plays in hour `hr` (its daily session: pace tenths of an hour from `sess` hours after the air time).
static func minutes(mb: CastMember, hr: int) -> int:
	var rel: int = posmod(hr - mb.sess, 24)
	if rel * 60 >= mb.per_day:
		return 0
	return mini(60, mb.per_day - 60 * rel)


## The derived values of a place (never stored): its roll stream, minutes a day, risk and rate by skill, the rival flag.
func derive(mb: CastMember) -> void:
	mb.base = SeedUtil.derive(seed, "cast", mb.place)
	mb.per_day = mb.pace * 6
	mb.risk = clampi((100 - mb.skill) * (100 - mb.skill) * 1000 / 2025, RISK_MIN, RISK_MAX)
	mb.eff = 1000 + (mb.skill - 55) * EFF_SKILL
	mb.rival = mb.profile == "rival"


## One played hour (`mins` minutes) of `mb` on its floor: waiting at open stairs → down; else the death roll, else the
## work (done → _floor_done). A collapse inside the hour cuts it short.
func _play(mb: CastMember, hr: int, mins: int, now_t: int) -> void:
	var t0: int = hr * HOUR
	var f: int = mb.fl
	var c: int = ct[f - 1]
	var cut: int = mins
	var inside: bool = c != NO_TIME and c > t0 and c < t0 + HOUR
	if inside:
		cut = mini(mins, (c - t0) / 60)
	if cut <= 0:
		if inside and c <= now_t:
			collapse_hit(mb, c)
		return
	var r: int = SeedUtil.mix(mb.base, hr + HOUR_SALT)
	var need: int = WORK_MIN[mini(f, 4) - 1] * 1000
	if mb.wk >= need:
		if f < format and open_for(f + 1, hr):        # waiting at the stairs: down as soon as they are open
			_descend(mb, t0 + SeedUtil.mix(r, 1) % cut * 60)
	else:
		var p: int = DEATH[mini(f, DEATH.size()) - 1] * mb.risk / 1000 * cut / 60
		if no_net and f <= NO_NET_CAREFUL:
			p = p * DEATH_NO_NET / 1000
		if r % 100000 < p:
			_death(mb, t0 + SeedUtil.mix(r, 1) % cut * 60)
		else:
			var rate: int = rate_of(mb, f, hr)
			var mins_needed: int = (need - mb.wk + rate - 1) / rate
			if mins_needed <= cut:
				mb.wk = need
				_floor_done(mb, t0 + mins_needed * 60, hr, r)
			else:
				mb.wk += rate * cut
	if inside and mb.fx & CastMember.F_DONE == 0 and mb.fl == f and c <= now_t:
		collapse_hit(mb, c)


## The work of floor `f` in ‰-minutes (its Pflichtweg at skill 55).
static func work(f: int) -> int:
	return WORK_MIN[clampi(f, 1, WORK_MIN.size()) - 1] * 1000


## Work per played minute of `mb` on floor `f` (‰ of a minute of the Pflichtweg): by skill and floor; Ohne Netz
## careful; a rival keeps close to the candidate (slower ahead, faster behind).
func rate_of(mb: CastMember, f: int, hr: int) -> int:
	var e: int = clampi(mb.eff - (f - 1) * EFF_FLOOR, EFF_MIN, EFF_MAX)
	if no_net:
		e = e * EFF_NO_NET / 1000
	if mb.rival:
		var d: int = f - human_floor(hr)
		if d > 0:
			e = e * RIVAL_AHEAD / 1000
		elif d < 0:
			e = e * RIVAL_BEHIND / 1000
	return maxi(1, e)


## The death chance of `mins` played minutes on floor `f` (per 100 000; _play inlines it).
func death_chance(mb: CastMember, f: int, mins: int) -> int:
	var p: int = DEATH[clampi(f, 1, DEATH.size()) - 1] * mb.risk / 1000 * mins / 60
	return p * DEATH_NO_NET / 1000 if no_net and f <= NO_NET_CAREFUL else p


## The stairs onto `next_floor` are open at hour `hr`: calendar the staircase rule (floors 1–3 from the start, then one
## floor below the floor on air, 09 §2.6); Am Stück at most one floor below the candidate's (09 §4.2, V-2).
func open_for(next_floor: int, hr: int) -> bool:
	return open_hour(next_floor, hr) <= hr


## The first hour from `hr` on at which the stairs onto `next_floor` are open; NEVER while the model cannot know it
## (Am Stück: the candidate is not there yet). Calendar: floor F ≥ 4 opens with the collapse of floor F − 2
## (SeasonClock.open_floor_max, opener_index — the collapse dates rise floor by floor); Am Stück with the candidate's
## arrival on floor F − 1 or deeper (human_floor).
func open_hour(next_floor: int, hr: int) -> int:
	if next_floor > format:
		return NEVER
	if binge:
		if next_floor <= 2:
			return hr
		var at: int = NEVER
		for f in range(next_floor - 1, mini(hf, format) + 1):
			if ha[f - 1] != NO_TIME:
				at = mini(at, hour_of(ha[f - 1]))
		return maxi(hr, at)
	return maxi(hr, open_h[next_floor - 1])


## The calendar's opening hours of the stairs (open_h) from the collapse dates: floor F ≥ 4 opens with the collapse of
## floor F − 2 (SeasonClock.opener_index); the dates are fixed from day 0 (Am Stück the model asks the arrivals).
func _calendar_opens() -> void:
	open_h.clear()
	for f in range(1, format + 1):
		var i: int = SeasonClock.opener_index(f)
		open_h.append(-NEVER if i < 0 else (ceil_hour(ct[i]) if ct[i] != NO_TIME else NEVER))


## The candidate's floor at hour `hr` (from the arrivals the model knows; 1 before any).
func human_floor(hr: int) -> int:
	var f: int = mini(hf, format)
	while f > 1:
		if ha[f - 1] != NO_TIME and ha[f - 1] < (hr + 1) * HOUR:
			return f
		f -= 1
	return 1


## The work of the floor is done at `t`: the optional Etagenboss, then the finale (the last floor) or the stairs when
## they are open (else `mb` waits at them).
func _floor_done(mb: CastMember, t: int, hr: int, r: int) -> void:
	var f: int = mb.fl
	if f < format and FBOSS_FLOORS.has(f) and SeedUtil.mix(r, 2) % 1000 < clampi((mb.skill - FBOSS_SKILL0) \
			* FBOSS_SLOPE, 0, 900):
		mb.fb += 1
		if fboss_mask & (1 << f) == 0:            # the first Etagenboss of the floor is news, the later ones not
			fboss_mask |= 1 << f
			emit(t, "fboss", mb.place, f, 1)
	if f >= format:
		if not mb.has(CastMember.F_QBOSS):
			mb.qb += 1
			mb.fx |= CastMember.F_QBOSS
		_finale(mb, t, r)
	elif open_for(f + 1, hr):
		_descend(mb, t)


## The Große Finale (the last floor's Etagenboss): won → finalist; lost → a death (Ohne Netz: out).
func _finale(mb: CastMember, t: int, r: int) -> void:
	var chance: int = clampi((mb.skill - FINALE_SKILL0) * FINALE_SLOPE, 0, 950)
	if SeedUtil.mix(r, 3) % 1000 < chance:
		mb.fx |= CastMember.F_FINAL
		mb.fa = t
		mb.rf = mb.fl
		mb.fb += 1
		finalists += 1
		emit(t, "finale", mb.place, mb.fl, finalists)
		return
	_death(mb, t)
	if mb.in_play():
		mb.wk = work(mb.fl) * (1000 - FINALE_SETBACK) / 1000


## A death (09 §7): floor 1 the dress rehearsal (only time and work lost); Ohne Netz out ("gefallen"); Mit Netz the
## medics — the vest goes, the work of the floor suffers (routine: never news).
func _death(mb: CastMember, t: int) -> void:
	var f: int = mb.fl
	if f >= 2 and no_net:
		_out(mb, t, CastEvent.OUT_FALLEN)
		return
	mb.wk = mb.wk * (1000 - DEATH_SETBACK) / 1000
	if f >= 2:
		mb.dt += 1
		mb.fx &= ~CastMember.F_VEST


## The floor of `mb` collapses at `c` (09 §2.5, §7.3): the last floor of the format ends the season ("Bis zum Ende
## dabei"); floor 1 is the dress rehearsal (a free rescue); Ohne Netz out ("verschüttet"); Mit Netz the rescue onto
## the next floor with the crash course — the vest goes. The rescues count in the collapse's summary (_caught).
func collapse_hit(mb: CastMember, c: int) -> void:
	var f: int = mb.fl
	if f >= format:
		mb.fx |= CastMember.F_ENDED
		mb.rf = f
		return
	if f == 1:
		_move(mb, 2, c)
		_caught(1, c, Vector2i(1, 0))
		return
	if no_net:
		_out(mb, c, CastEvent.OUT_BURIED)
		return
	mb.rs += 1
	mb.fx &= ~CastMember.F_VEST
	_move(mb, f + 1, c)
	_caught(f, c, Vector2i(1, 0))


## Onto floor `to` without the stairs (a rescue): the crash course lifts to the band start − 2 (09 §8.2, V-8).
func _move(mb: CastMember, to: int, t: int) -> void:
	mb.lv = maxi(level_of(mb), band_lo(to) - 2)
	mb.fl = to
	mb.wk = 0
	mb.ar = t
	if to >= 3 and mb.cl == "":
		_recall(mb)


## Down the stairs: the Revier-Boss was beaten (its key), the floor counts (the Quote, the tie-break).
func _descend(mb: CastMember, t: int) -> void:
	var f: int = mb.fl
	mb.lv = maxi(mb.lv, band_lo(f + 1))            # the end of the old band (level_of never passes it)
	mb.qb += 1
	mb.st += 1
	mb.ds = t
	mb.fl = f + 1
	mb.wk = 0
	mb.ar = t
	if f + 1 >= 3 and mb.cl == "":
		_recall(mb)
	_arrived(t, mb.place, f + 1)


func _out(mb: CastMember, t: int, why: int) -> void:
	mb.fx |= CastMember.F_OUT
	if why == CastEvent.OUT_BURIED:
		mb.fx |= CastMember.F_BURIED
		_caught(mb.fl, t, Vector2i(0, 1))
	mb.rf = mb.fl
	emit(t, "out", mb.place, mb.fl, why)


## The level of `mb` now: it follows the band of its floor with the work done (09 §2.4: Stufen-Band; never above the
## band's end) — `lv` keeps the level of the floor's start (set at every floor change; the play never writes it).
static func level_of(mb: CastMember) -> int:
	var lo: int = band_lo(mb.fl)
	var hi: int = band_hi(mb.fl)
	return mini(maxi(mb.lv, lo + (hi - lo) * mb.wk / work(mb.fl)), maxi(hi, mb.lv))


## The Stufen-Band of floor `f` (09 §2.4): 1–7, 7–10, 10–13, then 3 levels a floor up to 50.
static func band_lo(f: int) -> int:
	return 1 if f <= 1 else mini(50, 3 * f + 1)


static func band_hi(f: int) -> int:
	return mini(50, 3 * maxi(f, 1) + 4)


## The Recall on floor 3 (09 §4.2): a class of Kai's (the Vorleben's hint weighs 3) and a species (one that
## recommends the class, or the original packaging, weighs 2) — an AI candidate is a human without a talking pug.
func _recall(mb: CastMember) -> void:
	var r: int = SeedUtil.mix(mb.base, 77)
	if not classes.is_empty():
		var hint: String = str(org_hint.get(mb.org, ""))
		var w: PackedInt32Array = []
		for c: String in classes:
			w.append(3 if c == hint else 1)
		mb.cl = classes[weighted(w, r % 1000)]
	if not species.is_empty():
		var ws: PackedInt32Array = []
		for i in species.size():
			ws.append(2 if species_rec[i].has(mb.cl) or species[i] == "spc_original" else 1)
		mb.sp = species[weighted(ws, SeedUtil.mix(r, 1) % 1000)]


func _read_recall(data: GameData) -> void:
	if data == null:
		return
	for c: ClassDef in data.all_classes():
		if c.for_members.is_empty() or c.for_members.has("kai"):
			classes.append(c.id)
	for sp: SpeciesDef in data.all_species():
		if sp.for_members.is_empty() or sp.for_members.has("kai"):
			species.append(sp.id)
			species_rec.append(sp.recommended_classes)
	for o: Dictionary in data.all_origins():
		org_hint[str(o.get("id", ""))] = str(o.get("spec_hint", ""))


# ======================================================================================================================
# The candidate, Am Stück, übernommen
# ======================================================================================================================

## The candidate (place 0) stands on floor `f` from `t` on. By the stairs (`stairs`) it can be the first ascent of the
## floor — when no AI got there before, decided or still waiting in the batch (09 §4.6: Erstbesteigung, also a
## human's). Its arrival also keeps a later AI from the first ascent (flush).
func human_arrives(f: int, t: int, stairs: bool) -> void:
	if f < 1 or f > format:
		return
	if ha[f - 1] == NO_TIME:
		ha[f - 1] = t
	if stairs and f >= 2 and first_who[f - 1] < 0 and (batch_t[f - 1] == NO_TIME or t < batch_t[f - 1]):
		emit(t, "first", 0, f)
		first_who[f - 1] = 0
		first_t[f - 1] = t


## Am Stück (09 §4.2, V-2: "wenn Sie absteigen, rechnet das Modell Ihre bisherige Etage für alle zu Ende"): every
## place still on a floor ≤ `upto` plays it to its end now — until it leaves the floor or its collapse (the caller set
## the collapse times of those floors) hits it. Its cursor runs ahead; the events keep their own times.
func finish_floors(upto: int) -> void:
	for mb: CastMember in members:
		var guard: int = 2 * format + 4
		while mb.in_play() and mb.fl <= upto and guard > 0:
			guard -= 1
			var c: int = ct[mb.fl - 1]
			if c == NO_TIME:
				break
			run(mb, ceil_hour(c) + 1, c, mb.fl)


## A human place is taken over by the AI (09 §2.2, V-18: "übernommen"; §4.2: played on with skill 55): its state from
## the season block of the candidate (`fl` floor, `lv` level, the counters), a session at the air time.
func take_over(p: int, s: SeasonState, fl: int, lv: int, t: int) -> void:
	var mb: CastMember = members[p]
	if not mb.has(CastMember.F_HUMAN):
		return
	mb.skill = 55
	mb.pace = 10
	mb.sess = 0
	mb.profile = "extra"
	derive(mb)
	mb.fl = clampi(fl, 1, format)
	mb.lv = maxi(1, lv)
	mb.wk = 0
	mb.fx = CastMember.F_TAKEN | (CastMember.F_VEST if s.vest else 0)
	mb.rs = s.rescues
	mb.dt = s.deaths
	mb.st = s.stairs
	mb.qb = s.qbosses
	mb.fb = s.fbosses
	mb.t = hour_of(t) + 1
	mb.ar = t
	mb.ds = NO_TIME
	emit(t, "leave", p, mb.fl)


## Am Stück the season ends with the candidate's (the binge clock stands from then on): every place still playing is
## "Bis zum Ende dabei" where it stands.
func end_all(_t: int) -> void:
	for mb: CastMember in members:
		if mb.in_play():
			mb.fx |= CastMember.F_ENDED
			mb.rf = mb.fl


# ======================================================================================================================
# Events
# ======================================================================================================================

## A newsworthy event of the play at cast second `t` into the batch. The routine ones never become objects (a season
## has thousands of them): a descent counts for the first ascent of its floor and the calibration (_arrived), a rescue
## or a burial for its collapse's summary (_caught); a death, an end or a later Etagenboss are never news.
func emit(t: int, kind: String, who: int, at: int, n: int = 0, m: int = 0) -> void:
	pending.append(CastEvent.make(t, kind, who, at, n, m))


## Place `who` came down the stairs onto floor `f` at `t`: the earliest AI arrival of the batch per floor (ties: the
## lower place) and of the season (ai_first).
func _arrived(t: int, who: int, f: int) -> void:
	if ai_first[f - 1] == NO_TIME or t < ai_first[f - 1]:
		ai_first[f - 1] = t
	var bt: int = batch_t[f - 1]
	if bt == NO_TIME or t < bt or (t == bt and who < batch_who[f - 1]):
		batch_t[f - 1] = t
		batch_who[f - 1] = who


## The collapse of floor `f` at `t` caught a place: `add` (rescued, out).
func _caught(f: int, t: int, add: Vector2i) -> void:
	var key: Vector2i = Vector2i(f, t)
	batch_caught[key] = (batch_caught.get(key, Vector2i.ZERO) as Vector2i) + add


## The events of the running catch-up: first ascents (by the stairs — the earliest AI arrival per floor up to `now_t`,
## unless the candidate or another place got there first; a later one waits), the collapse summaries, a new leader of
## the AI cast (stamped `now_t`) and the other newsworthy events; in time order they get their number, go into the
## ticker and are returned.
func flush(now_t: int) -> Array[CastEvent]:
	var out: Array[CastEvent] = []
	for e: CastEvent in pending:
		if e.importance() >= CastEvent.TICKER_MIN:
			out.append(e)
	pending.clear()
	for f in range(2, format + 1):
		var bt: int = batch_t[f - 1]
		if bt == NO_TIME or bt > now_t:
			continue
		batch_t[f - 1] = NO_TIME
		if (ha[f - 1] == NO_TIME or ha[f - 1] > bt) and first_who[f - 1] < 0:
			first_who[f - 1] = batch_who[f - 1]
			first_t[f - 1] = bt
			out.append(CastEvent.make(bt, "first", batch_who[f - 1], f))
	for key: Vector2i in batch_caught.keys():
		var v: Vector2i = batch_caught[key]
		out.append(CastEvent.make(key.y, "collapse", -1, key.x, v.x, v.y))
	batch_caught.clear()
	var leader: int = ai_leader()
	if leader >= 0 and leader != lead:
		lead = leader
		out.append(CastEvent.make(now_t, "record", leader, members[leader].fl))
	out.sort_custom(CastEvent.before)
	for e3: CastEvent in out:
		seq += 1
		e3.seq = seq
		ticker.append(e3)
	while ticker.size() > TICKER_MAX:
		ticker.pop_front()
	return out


## Adds an event of the commands (hire, help, …) now: numbered, into the ticker when newsworthy.
func note(e: CastEvent) -> void:
	seq += 1
	e.seq = seq
	if e.importance() >= CastEvent.TICKER_MIN:
		ticker.append(e)
		while ticker.size() > TICKER_MAX:
			ticker.pop_front()


# ======================================================================================================================
# Ranking (09 §2.7: the Quote; AI places with estimated achievements and followers)
# ======================================================================================================================

## The Quote of an AI place.
static func ai_quote(mb: CastMember) -> int:
	var ach: int = mini(AI_ACH_MAX, mb.st * (AI_ACH_BASE + mb.skill) / AI_ACH_DIV)
	var followers: int = mb.st * (AI_FOLLOWERS_BASE + AI_FOLLOWERS_SKILL * mb.skill)
	return mb.st * SeasonRules.QUOTE_STAIRS + mb.qb * SeasonRules.QUOTE_QBOSS + mb.fb * SeasonRules.QUOTE_FBOSS \
		+ (SeasonRules.QUOTE_FINALE if mb.has(CastMember.F_FINAL) else 0) + ach * SeasonRules.QUOTE_ACHIEVEMENT \
		+ mini(followers, SeasonRules.QUOTE_FOLLOWERS_CAP) / SeasonRules.QUOTE_FOLLOWERS_DIV \
		- mb.rs * SeasonRules.QUOTE_RESCUE - mb.dt * SeasonRules.QUOTE_DEATH


## The sort key of an AI place (09 §2.7): the higher Quote, the earlier finale, the earlier last descent, the place.
static func ai_key(mb: CastMember) -> Array[int]:
	return [-ai_quote(mb), mb.fa if mb.fa != NO_TIME else NEVER, mb.ds if mb.ds != NO_TIME else NEVER, mb.place]


## The leader of the AI places (-1 when none has a Quote above 0).
func ai_leader() -> int:
	var best: Array[int] = []
	var who: int = -1
	for mb: CastMember in members:
		if not mb.is_ai() or ai_quote(mb) <= 0:
			continue
		var k: Array[int] = ai_key(mb)
		if who < 0 or less(k, best):
			best = k
			who = mb.place
	return who


static func less(a: Array[int], b: Array[int]) -> bool:
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			return a[i] < b[i]
	return a.size() < b.size()


# ======================================================================================================================
# Helpers
# ======================================================================================================================

## The hour that contains cast second `t` (floor division; negative in the Vorprogramm).
static func hour_of(t: int) -> int:
	return (t - posmod(t, HOUR)) / HOUR


## The first hour that starts at or after `t`.
static func ceil_hour(t: int) -> int:
	return hour_of(t) + (1 if posmod(t, HOUR) != 0 else 0)


## A triangular value lo..hi with its mode at `mode` from `u` in 0..999 (integer square root, no floats).
static func _triangular(u: int, lo: int, mode: int, hi: int) -> int:
	var span: int = hi - lo
	var cut: int = (mode - lo) * 1000 / span
	if u < cut:
		return lo + _isqrt(u * span * (mode - lo) / 1000)
	return hi - _isqrt((1000 - u) * span * (hi - mode) / 1000)


static func _isqrt(n: int) -> int:
	if n <= 0:
		return 0
	var x: int = n
	var y: int = (x + 1) / 2
	while y < x:
		x = y
		y = (x + n / x) / 2
	return x


## The session start (hours after the air time): 55 % in the evening around the air time (3 h before to 2 h after),
## the rest anywhere in the day.
static func _session_hour(r: int) -> int:
	if r % 100 < 55:
		return posmod(SeedUtil.mix(r, 1) % 6 - 3, 24)
	return SeedUtil.mix(r, 2) % 24


## The profiles of `n` AI places by the weights of data/cast.json (largest remainder, then shuffled with `p_seed`).
static func _profile_quota(data: GameData, n: int, p_seed: int) -> PackedStringArray:
	var ids: PackedStringArray = []
	var weights: PackedInt32Array = []
	var total: int = 0
	if data != null:
		for d: Dictionary in data.all_cast_profiles():
			ids.append(str(d.get("id", "")))
			weights.append(maxi(0, JsonUtil.to_int(d.get("weight", 0))))
			total += maxi(0, JsonUtil.to_int(d.get("weight", 0)))
	var out: PackedStringArray = []
	if total <= 0 or n <= 0:
		for i in maxi(0, n):
			out.append("extra")
		return out
	var counts: PackedInt32Array = []
	var rest: Array[Array] = []
	var given: int = 0
	for i in ids.size():
		counts.append(n * weights[i] / total)
		given += counts[i]
		rest.append([-(n * weights[i] % total), i])
	rest.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	for k in n - given:
		counts[int(rest[k % rest.size()][1])] += 1
	for i in ids.size():
		for k in counts[i]:
			out.append(ids[i])
	var order: PackedInt32Array = _shuffled(out.size(), p_seed)
	var shuffled: PackedStringArray = []
	for i in order:
		shuffled.append(out[i])
	return shuffled


## 0 … n − 1 in the order of `p_seed` (Fisher–Yates on a SeedUtil generator, like SeasonRules' programme).
static func _shuffled(n: int, p_seed: int) -> PackedInt32Array:
	var out: PackedInt32Array = []
	for i in n:
		out.append(i)
	var rng: RandomNumberGenerator = SeedUtil.make_rng(p_seed)
	for i in range(n - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


## The index drawn from weights `w` with `u` in 0..999.
static func weighted(w: PackedInt32Array, u: int) -> int:
	var total: int = 0
	for x in w:
		total += x
	if total <= 0:
		return 0
	var pick: int = u * total / 1000
	for i in w.size():
		if pick < w[i]:
			return i
		pick -= w[i]
	return w.size() - 1


static func _ints(text: String, n: int, fill: int) -> PackedInt32Array:
	var out: PackedInt32Array = []
	var parts: PackedStringArray = text.split(",", false)
	for i in n:
		out.append(parts[i].to_int() if i < parts.size() and parts[i].is_valid_int() else fill)
	return out


static func _text(a: PackedInt32Array) -> String:
	var parts: PackedStringArray = []
	for v in a:
		parts.append(str(v))
	return ",".join(parts)
