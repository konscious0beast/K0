class_name CastSim extends RefCounted
## The AI candidates (09 §4; ST1-F): the population model of the free places (abstract — CastModel plays every AI
## place one session a day, a step per season hour; Am Stück the cast follows the candidate: a step per 25 s of
## exploration, nobody more than one floor ahead, the candidate's old floor is played to its end for everyone), its
## events and the breaking news (CastEvent, the ticker), the counter, the ranking, "übernommen", the Safe-Room guests,
## the guest appearance (rules and bookkeeping — the combat unit comes with CR-32 c), the Pechvogel in need and the
## command "cast" (hire, help; trade waits for ST1-E). Static and pure (core): no autoloads, no clock (the cast time is
## the season time without the Sendepause, now()), integer math, randomness only from SeedUtil streams of the season
## seed. Every rule hangs at state.season != null and at an AI cast in the season block (SeasonState.cast; the start
## block {} is a season without one — the ST1-B start, kept valid).
##
## The season block: the start command carries {"v": 1, "places", "humans"} (start_block; both verifiers check it
## against the template, start_refusal → cast_mismatch); on_start draws the roster from the season seed, data/cast.json
## (384 invented, alliterating names; the profiles Statist:in 50 %, Rival:in 15 %, Helfer:in 15 %, Händler:in 10 %,
## Pechvogel 10 % by quota) and the 08 catalog (Vorleben, hobby) and keeps it in the block — a data update never
## renames a running cast. The state of a place is one short text (CastMember), so the state hash stays cheap.
##
## Hooks (the same calls in the live game, RunSim.apply and both verifiers): RunRules.apply_season → on_start (the
## start) and advance (after every season command: clock, away, pause, tempo, leave …); RunRules.start_floor →
## on_floor_start (the candidate's floor: the first ascent; Am Stück the old floor to its end); RunSim's tick → on_tick
## (Am Stück only: the binge clock); the end of a combat (RunSim._book_result, Game.apply_battle_result) →
## on_combat_end (the guest). AI candidates are labelled everywhere: label() is "Name (KI)" (09 S-6, §4.1).
##
## Decisions of ST1-F: 09 Kap. 11.3 "Entscheidungen ST1-F" (F-1 …).

const CastModel := preload("res://core/season/cast_model.gd")

## Kept from ST0 (09 §11.4: the public API stays) — no command is refused with it since ST1-F.
const UNAVAILABLE: String = "season_unavailable"
const BLOCK_VERSION: int = 1
## Refusal reasons (both verifiers report them; Game.cast_action records nothing then).
const REASONS: PackedStringArray = ["cast_mismatch", "no_cast", "unknown_place", "not_in_safe_room", "in_safe_room",
	"not_here", "not_helper", "guest_active", "no_credits", "not_in_need", "trade_unavailable", "not_allowed"]
## The guest appearance (09 §4.3): a Helfer:in for three combats (never a boss fight), paid with a favour or credits.
const HIRE_FIGHTS: int = 3
const HIRE_CREDITS: int = 100
const HIRE_CREDITS_FLOOR: int = 25
## The Pechvogel (09 §4.3): the won combat brings followers and a favour; the Pechvogel gets a quarter of its floor.
const HELP_FOLLOWERS: int = 100
const HELP_FOLLOWERS_FLOOR: int = 25
const HELP_WORK: int = 250
const SAFE_ROOM_SEATS: int = 2         # 09 §4.3: up to two AI candidates of the floor sit in a Safe Room
const AI_TAG: String = "KI"            # 09 S-6: every AI candidate is labelled
const TAKEN_TAG: String = "übernommen"
const LOCATION_START: StringName = &"start"   # == RunRules.LOCATION_START (outside a safe room)
## "No time yet" in the cast's times (cast seconds since day 0 are negative in the Vorprogramm).
const NO_TIME: int = CastMember.NO_TIME


# ======================================================================================================================
# The start (09 §2.2: the season gets its cast for the free places)
# ======================================================================================================================

## The cast block of a season's start command for template `def`: all places of the template, `humans` of them human
## (ST1: private, one).
static func start_block(def: SeasonDef, humans: int = 1) -> Dictionary:
	return {"v": BLOCK_VERSION, "places": def.places if def != null else 0, "humans": humans}


## "" or why the start command's cast block does not fit (cast_mismatch): {} (a season without AI candidates) or
## exactly start_block of the template with its humans (private: one) — a forged cast is refused like a forged schedule
## (V-17). RunRules.season_refusal asks after SeasonRules accepted the start. Read-only.
static func start_refusal(_state: GameState, data: GameData, c: Dictionary) -> String:
	var raw: Variant = c.get("cast", {})
	if not (raw is Dictionary):
		return "cast_mismatch"
	var b: Dictionary = raw
	if b.is_empty():
		return ""
	var def_id: String = str(c.get("def", ""))
	var def: SeasonDef = data.season_def(def_id) if data != null and data.has_id("seasons", def_id) else null
	if def == null or b.size() != 3:
		return "cast_mismatch"
	for k: String in ["v", "places", "humans"]:
		if not JsonUtil.is_integral(b.get(k, null)):
			return "cast_mismatch"
	if JsonUtil.to_int(b["v"]) != BLOCK_VERSION or JsonUtil.to_int(b["places"]) != def.places \
			or JsonUtil.to_int(b["humans"]) != def.min_humans:
		return "cast_mismatch"
	return ""


## After the start command (SeasonRules made the season block): the cast of a non-empty block — the roster, everybody
## on floor 1 at the start.
static func on_start(state: GameState, data: GameData) -> void:
	var s: SeasonState = state.season if state != null else null
	if s == null or s.cast.is_empty() or s.cast.has("roster"):
		return
	var m: CastModel = CastModel.new()
	m.create(state, data, now(state))
	m.write(state)


# ======================================================================================================================
# The command "cast" (09 §9.1: hire | trade | help)
# ======================================================================================================================

## "" or why the command `c` ("cast") is refused now (RunRules.season_refusal asks with a season; read-only):
## - no AI cast in the season → no_cast; `who` not an AI place → unknown_place
## - hire (a Helfer:in for three combats, 09 §4.3): outside a safe room → not_in_safe_room; not one of the visit's
##   guests (safe_room_guests) → not_here; another profile → not_helper; a guest already along → guest_active; no
##   favour and fewer credits than hire_cost → no_credits
## - help (the Pechvogel's combat): in a safe room → in_safe_room; a guest along → guest_active; not the Pechvogel in
##   need on this floor (in_need) → not_in_need
## - trade → trade_unavailable (the trader's goods are the materials, recipes and crafted items of ST1-E)
static func refusal(state: GameState, data: GameData, c: Dictionary) -> String:
	var m: CastModel = _load(state, data)
	if m == null:
		return "no_cast"
	var who: int = JsonUtil.to_int(c.get("who", -1), -1)
	if who < m.humans or who >= m.places:
		return "unknown_place"
	match str(c.get("op", "")):
		"trade":
			return "trade_unavailable"
		"hire":
			if not _in_safe_room(state):
				return "not_in_safe_room"
			if not _room_guests(state, m).has(who):
				return "not_here"
			if m.members[who].profile != "helper":
				return "not_helper"
			if m.guest_who >= 0:
				return "guest_active"
			if m.favors <= 0 and (state.inventory == null or state.inventory.credits < hire_cost(state)):
				return "no_credits"
			return ""
		"help":
			if _in_safe_room(state):
				return "in_safe_room"
			if m.guest_who >= 0:
				return "guest_active"
			return "" if who == _in_need(state, m) else "not_in_need"
	return "not_allowed"


## Applies an accepted command (refusal == ""): hire — a favour pays first, else hire_cost credits; the Helfer:in comes
## along for HIRE_FIGHTS combats. help — the Pechvogel joins the next combat; won, it pays (on_combat_end).
static func apply(state: GameState, data: GameData, c: Dictionary) -> Array[ExploreEvent]:
	var out: Array[ExploreEvent] = []
	var m: CastModel = _load(state, data)
	if m == null:
		return out
	var who: int = JsonUtil.to_int(c.get("who", -1), -1)
	var t: int = now(state)
	var e: CastEvent = null
	match str(c.get("op", "")):
		"hire":
			if m.favors > 0:
				m.favors -= 1
			elif state.inventory != null:
				state.inventory.spend_credits(hire_cost(state))
			m.guest_who = who
			m.guest_left = HIRE_FIGHTS
			m.guest_kind = "hire"
			e = CastEvent.make(t, "hired", who, _floor(state), HIRE_FIGHTS)
		"help":
			m.guest_who = who
			m.guest_left = 1
			m.guest_kind = "help"
			e = CastEvent.make(t, "help", who, _floor(state))
	if e != null:
		m.note(e)
		out.append(e.to_explore())
	m.write(state)
	return out


## The credits a Helfer:in costs on the candidate's floor (09 §4.3: "ein Gefallen … oder Credits").
static func hire_cost(state: GameState) -> int:
	return HIRE_CREDITS + HIRE_CREDITS_FLOOR * maxi(1, _floor(state))


# ======================================================================================================================
# Hooks
# ======================================================================================================================

## After every season command (RunRules.apply_season): the cast plays on to the cast time now — the collapses of the
## schedule (Am Stück the ends of the candidate's countdowns), the candidate's floor after a rescue, a tempo switch (the
## floors below the candidate are played to their end), "übernommen" when the candidate left, the end Am Stück.
## Returns the newsworthy events as SEASON {"kind": "cast", …}.
static func advance(state: GameState, data: GameData) -> Array[ExploreEvent]:
	var out: Array[ExploreEvent] = []
	var m: CastModel = _load(state, data)
	if m == null:
		return out
	var t: int = now(state)
	_sync(state, m, t)
	m.catch_up(CastModel.hour_of(t), t)
	if m.binge and state.season.result != "":
		m.end_all(t)
	for e: CastEvent in m.flush(t):
		out.append(e.to_explore())
	m.write(state)
	return out


## RunSim's tick (Am Stück only — the calendar moves with "clock" / "away"): the binge clock passed an hour of the cast,
## the candidate's countdown ended (a collapse) or the candidate's floor changed → advance. A cheap check otherwise.
static func on_tick(state: GameState, data: GameData) -> Array[ExploreEvent]:
	var none: Array[ExploreEvent] = []
	var s: SeasonState = state.season if state != null else null
	if s == null or s.tempo != "binge" or not s.cast.has("roster"):
		return none
	var c: Dictionary = s.cast
	var idx: int = state.floor_run.index if state.floor_run != null else 0
	if CastModel.hour_of(now(state)) <= JsonUtil.to_int(c.get("h", 0)) \
			and s.collapsed <= JsonUtil.to_int(c.get("col", 0)) and idx <= JsonUtil.to_int(c.get("hf", 1), 1):
		return none
	return advance(state, data)


## RunRules.start_floor (the "floor" command: the candidate came down the stairs; a new season's floor 1): the cast
## plays the running hour to its end, then the candidate's arrival counts (a first ascent when no AI was faster). Am
## Stück the old floor ends for everyone — the rest of its countdown, played to its end now (09 §4.2, V-2). The guest
## stays behind. The events go into the ticker (the news read them there).
static func on_floor_start(state: GameState, data: GameData, prev: FloorRun) -> void:
	var m: CastModel = _load(state, data)
	if m == null or state.floor_run == null:
		return
	var t: int = now(state)
	var idx: int = state.floor_run.index
	_sync_clock(state, m, t)
	m.catch_up(CastModel.hour_of(t) + 1, t)
	m.flush(t)                                      # the AI arrivals of the running hour count first
	for f in range(m.hf + 1, idx + 1):
		m.human_arrives(f, t, prev != null)
	if idx > m.hf:
		m.hf = idx
		_guest_leaves(m, t)
	if m.binge and prev != null and prev.index < idx and prev.index >= 1 and prev.index <= m.format:
		if m.ct[prev.index - 1] == NO_TIME:
			m.ct[prev.index - 1] = t + maxi(0, prev.time_left_ticks) * SeasonClock.BINGE_FACTOR \
				/ FloorRun.TICKS_PER_SEC
		m.finish_floors(prev.index)
	m.flush(t)
	m.write(state)


## The end of every combat in a season (after SeasonRules.on_combat_end): the guest. A boss fight never counts — the
## guest is never part of one (09 §4.3, §4.5 Nr. 3). A hired Helfer:in counts the combat down; the Pechvogel's combat
## won pays followers and a favour, and the Pechvogel remembers (and gets on with its floor).
static func on_combat_end(state: GameState, data: GameData, result: BattleResult) -> Array[ExploreEvent]:
	var out: Array[ExploreEvent] = []
	var s: SeasonState = state.season if state != null else null
	if s == null or result == null or not s.cast.has("roster") or str(s.cast.get("guest", "")) == "" \
			or result.is_boss:
		return out
	var m: CastModel = _load(state, data)
	if m == null or m.guest_who < 0:
		return out
	var t: int = now(state)
	var who: int = m.guest_who
	if m.guest_kind == "help":
		if result.outcome == BattleResult.Outcome.VICTORY:
			var f: int = _floor(state)
			var followers: int = HELP_FOLLOWERS + HELP_FOLLOWERS_FLOOR * f
			if state.show != null:
				state.show.followers += followers
			m.favors += 1
			m.helped_mask |= 1 << f
			var mb: CastMember = m.members[who]
			mb.fx |= CastMember.F_HELPED
			if mb.in_play() and mb.fl == f:
				mb.wk = mini(CastModel.work(f), mb.wk + CastModel.work(f) * HELP_WORK / 1000)
			var e: CastEvent = CastEvent.make(t, "helped", who, f, followers)
			m.note(e)
			out.append(e.to_explore())
		_guest_end(m, t, out)
	else:
		m.guest_left -= 1
		if m.guest_left <= 0:
			_guest_end(m, t, out)
	m.write(state)
	return out


# ======================================================================================================================
# Queries (the season UI of ST1-H, the sleeper of ST1-G, the harness of ST1-I)
# ======================================================================================================================

## The season has AI candidates.
static func has_cast(state: GameState) -> bool:
	return state != null and state.season != null and state.season.cast.has("roster")


## The cast time: seconds since day 0 of the season without the Sendepause (a pause or a "clamp" moves every open date —
## the cast stands meanwhile, 09 §2.9); Am Stück the binge clock. 0 without a season.
static func now(state: GameState) -> int:
	var s: SeasonState = state.season if state != null else null
	if s == null:
		return 0
	return SeasonRules.now(state) - pause_total(s) - s.day0_utc


## The Sendepause so far (user and clamp): every pause moved the next air time by its length.
static func pause_total(s: SeasonState) -> int:
	return s.next_air_utc - s.day0_utc - s.airs * SeasonClock.DAY_SEC


## The label of place `p` (09 S-6: every AI candidate is labelled): "Name (KI)", a human place taken over "Name (KI,
## übernommen)" (the candidate's display name), a human "Name".
static func label(state: GameState, data: GameData, p: int) -> String:
	var m: CastModel = _load(state, data)
	if m == null or p < 0 or p >= m.places:
		return ""
	return _label(state, m.members[p])


## One place for the UI: {"place", "name", "label", "ai", "taken", "profile", "profile_name", "skill", "pace",
## "floor", "level", "vest", "out", "result" ("" | finalist | end | fallen | buried | left), "org", "job" (the Vorleben
## in the word form of the name), "hobby", "species", "class", "rescues", "deaths", "stairs", "quote"}; {} for an
## unknown place.
static func member_view(state: GameState, data: GameData, p: int) -> Dictionary:
	var m: CastModel = _load(state, data)
	if m == null or p < 0 or p >= m.places:
		return {}
	return _view(state, data, m.members[p])


## The Kandidatenzähler (09 §2.3): Mit Netz "Weiße Weste: n/places", Ohne Netz "Noch dabei: n/places" — every place,
## the candidate's from the season block. {"kind": "vest" | "in", "label", "n", "of"}; without a cast the candidate
## alone.
static func counter(state: GameState, data: GameData) -> Dictionary:
	var s: SeasonState = state.season if state != null else null
	if s == null:
		return {}
	var no_net: bool = s.mode == "no_net"
	var out: Dictionary = {"kind": "in" if no_net else "vest", "label": "Noch dabei" if no_net else "Weiße Weste",
		"n": 0, "of": 1}
	var human_ok: bool = (s.result != "fallen" and s.result != "buried" and s.result != "left") if no_net else s.vest
	var m: CastModel = _load(state, data)
	if m == null:
		out["n"] = 1 if human_ok else 0
		return out
	var n: int = 0
	for mb: CastMember in m.members:
		if mb.has(CastMember.F_HUMAN):
			n += 1 if human_ok and mb.place == 0 else 0
		elif no_net:
			n += 0 if mb.is_out() else 1
		else:
			n += 1 if mb.has(CastMember.F_VEST) else 0
	out["n"] = n
	out["of"] = m.places
	return out


## The ranking of every place (09 §2.7, V-11: privately all places, the AI included): sorted by the Quote, then the
## earlier finale, then the earlier last descent; each {"rank", "place", "label", "ai", "taken", "quote", "floor",
## "level", "result"}. The candidate's Quote is SeasonRules.quote (its show part included); AI places estimate
## achievements and followers from their floors (CastModel.ai_quote).
static func ranking(state: GameState, data: GameData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var m: CastModel = _load(state, data)
	if m == null:
		return out
	var rows: Array[Array] = []
	for mb: CastMember in m.members:
		var key: Array[int] = _human_key(state, mb.place) if mb.has(CastMember.F_HUMAN) else CastModel.ai_key(mb)
		rows.append([key, mb.place])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return CastModel.less(a[0], b[0]))
	for i in rows.size():
		var v: Dictionary = _view(state, data, m.members[int(rows[i][1])])
		out.append({"rank": i + 1, "place": v["place"], "label": v["label"], "ai": v["ai"], "taken": v["taken"],
			"quote": v["quote"], "floor": v["floor"], "level": v["level"], "result": v["result"]})
	return out


## The rank of place `p` (1 = first; 0 without a cast): "Platz 12 von 100".
static func rank_of(state: GameState, data: GameData, p: int = 0) -> int:
	for row: Dictionary in ranking(state, data):
		if int(row["place"]) == p:
			return int(row["rank"])
	return 0


## The ticker (09 §4.6: the last 24 h — `hours`): the newsworthy events, oldest first, as news views (news()).
static func ticker(state: GameState, data: GameData, hours: int = 24) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var m: CastModel = _load(state, data)
	if m == null:
		return out
	var from: int = now(state) - hours * CastModel.HOUR
	for e: CastEvent in m.ticker:
		if e.t >= from:
			out.append(_news_view(state, m, e))
	return out


## The breaking news after `after_seq` (09 §4.6: "wichtige zuerst"): the newsworthy events of the ticker, the most
## important first (then the newest); each {"seq", "t", "kind", "who", "label", "floor", "n", "m", "importance", "tag",
## "ctx"} — `tag` the M.O.D. tag (cast_<kind>; cast_first_you when the candidate was first, cast_collapse_out Ohne
## Netz), `ctx` its placeholders ({cand} the label, {floor}, {count}).
static func news(state: GameState, data: GameData, after_seq: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var m: CastModel = _load(state, data)
	if m == null:
		return out
	for e: CastEvent in m.ticker:
		if e.seq > after_seq and e.importance() >= CastEvent.TICKER_MIN:
			out.append(_news_view(state, m, e))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["importance"]) > int(b["importance"]) or (int(a["importance"]) == int(b["importance"])
			and int(a["seq"]) > int(b["seq"])))
	return out


## The number of the newest event (0 without a cast): the news shown up to here.
static func last_seq(state: GameState) -> int:
	return JsonUtil.to_int(state.season.cast.get("seq", 0)) if has_cast(state) else 0


## Up to two AI candidates of the candidate's floor in the Safe Room of the current visit (09 §4.3; deterministic per
## visit: floor, safe room and FloorRun.safe_room_visits; Helfer:innen and Händler:innen weigh twice); [] outside one.
static func safe_room_guests(state: GameState, data: GameData) -> Array[int]:
	var m: CastModel = _load(state, data)
	if m == null:
		var none: Array[int] = []
		return none
	return _room_guests(state, m)


## The Pechvogel in need on the candidate's floor (09 §4.3: the event candidate_in_need) — one AI place of profile
## "unlucky" on that floor (by the season seed and the floor); -1 when there is none or the candidate helped there.
static func in_need(state: GameState, data: GameData) -> int:
	var m: CastModel = _load(state, data)
	return _in_need(state, m) if m != null else -1


## The rival before the Revier-Boss's door (09 §4.3): a Rival:in of the model on the candidate's floor (by the season
## seed), else the nearest one (by floor, then place); -1 without one.
static func rival_near(state: GameState, data: GameData) -> int:
	var m: CastModel = _load(state, data)
	if m == null:
		return -1
	var f: int = _floor(state)
	var best: int = -1
	var best_d: int = 1 << 30
	var same: Array[int] = []
	for mb: CastMember in m.members:
		if not mb.is_ai() or mb.profile != "rival" or mb.is_out():
			continue
		var d: int = absi(mb.fl - f)
		if d == 0:
			same.append(mb.place)
		if d < best_d:
			best_d = d
			best = mb.place
	if not same.is_empty():
		return same[SeedUtil.derive(state.seed, "cast_rival", f) % same.size()]
	return best


## The guest along now: {"who", "label", "kind" (hire | help), "left" (combats)}; {} without one.
static func guest(state: GameState, data: GameData) -> Dictionary:
	var m: CastModel = _load(state, data)
	if m == null or m.guest_who < 0:
		return {}
	return {"who": m.guest_who, "label": _label(state, m.members[m.guest_who]), "kind": m.guest_kind,
		"left": m.guest_left}


## The guest unit of the next combat — the hook for 07 CR-32 c (Klassenvorlage × Stufe, the partner AI with the
## tactic "support", never in a boss fight): {"who", "label", "class", "species", "level", "tactic", "kind", "left"};
## {} without a guest and always for a boss fight (`boss`).
static func guest_for_combat(state: GameState, data: GameData, boss: bool) -> Dictionary:
	if boss:
		return {}
	var m: CastModel = _load(state, data)
	if m == null or m.guest_who < 0:
		return {}
	var mb: CastMember = m.members[m.guest_who]
	return {"who": mb.place, "label": _label(state, mb), "class": mb.cl, "species": mb.sp,
		"level": CastModel.level_of(mb), "tactic": "support", "kind": m.guest_kind, "left": m.guest_left}


## Favours the candidate holds (a helped Pechvogel owes one; a hire spends it first).
static func favors(state: GameState, data: GameData) -> int:
	var m: CastModel = _load(state, data)
	return m.favors if m != null else 0


## The census of the cast for the harness and the tests: {"places", "humans", "ai", "vest" (AI places with the vest),
## "in" (AI places not out), "out", "finalists", "final_vest" (finalists with the vest: the title "Weiße Weste"),
## "ended", "taken", "on_floor" (per floor the AI places playing there),
## "first_who" / "first_t" (the first ascent per floor: place -1 / NO_TIME for nobody yet), "ai_first" (the first AI
## arrival per floor), "human" (the candidate's arrival per floor), "collapse" (the collapse time per floor) — times in
## cast seconds, NO_TIME unknown}; {} without a cast.
static func census(state: GameState, data: GameData) -> Dictionary:
	var m: CastModel = _load(state, data)
	if m == null:
		return {}
	var on_floor: PackedInt32Array = []
	on_floor.resize(m.format)
	var ai: int = 0
	var vest: int = 0
	var out: int = 0
	var finals: int = 0
	var final_vest: int = 0
	var ended: int = 0
	var taken: int = 0
	for mb: CastMember in m.members:
		if not mb.is_ai():
			continue
		ai += 1
		vest += 1 if mb.has(CastMember.F_VEST) else 0
		out += 1 if mb.is_out() else 0
		finals += 1 if mb.has(CastMember.F_FINAL) else 0
		final_vest += 1 if mb.has(CastMember.F_FINAL) and mb.has(CastMember.F_VEST) else 0
		ended += 1 if mb.has(CastMember.F_ENDED) else 0
		taken += 1 if mb.has(CastMember.F_TAKEN) else 0
		if mb.in_play():
			on_floor[mb.fl - 1] += 1
	return {"places": m.places, "humans": m.humans, "ai": ai, "vest": vest, "in": ai - out, "out": out,
		"finalists": finals, "final_vest": final_vest, "ended": ended, "taken": taken, "on_floor": on_floor,
		"first_who": m.first_who, "first_t": m.first_t, "ai_first": m.ai_first, "human": m.ha, "collapse": m.ct}


# --- Staffeln (09, ST1-G) ---

## The AI candidates playing on `floor` now (the sleeper's visitors, 09 §5.3 "die laut Modell gerade auf der Etage
## ist"), in place order: [{"place", "profile", "label"}]; [] without a cast. One read of the block (cheaper than a
## member_view per place).
static func floor_ai(state: GameState, data: GameData, floor: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var m: CastModel = _load(state, data)
	if m == null:
		return out
	for mb: CastMember in m.members:
		if mb.is_ai() and mb.in_play() and mb.fl == floor:
			out.append({"place": mb.place, "profile": mb.profile, "label": _label(state, mb)})
	return out


# ======================================================================================================================
# Private
# ======================================================================================================================

static func _load(state: GameState, data: GameData) -> CastModel:
	var s: SeasonState = state.season if state != null else null
	if s == null or not s.cast.has("roster"):
		return null
	var m: CastModel = CastModel.new()
	m.read(s.cast, s, state.seed, data)
	return m


## Before a catch-up: the cast's clock (the tempo switch, the collapses Am Stück), the candidate's floor after a move
## the cast did not see (a rescue — no first ascent), "übernommen" when the candidate left.
static func _sync(state: GameState, m: CastModel, t: int) -> void:
	_sync_clock(state, m, t)
	var s: SeasonState = state.season
	var idx: int = state.floor_run.index if state.floor_run != null else m.hf
	if idx > m.hf:
		for f in range(m.hf + 1, idx + 1):
			var at: int = t
			if not m.binge and f >= 2 and m.ct[f - 2] != NO_TIME and m.ct[f - 2] <= t:
				at = m.ct[f - 2]
			m.human_arrives(f, at, false)
		m.hf = idx
		_guest_leaves(m, t)
	if s.result == "left" and m.places > 0 and m.members[0].has(CastMember.F_HUMAN):
		var kai: PartyMember = state.member("kai")
		m.catch_up(CastModel.hour_of(t), t)
		m.take_over(0, s, idx, kai.level if kai != null else 1, t)


## The cast's clock against the season: Kalender → Am Stück (09 §2.1: the floors below the candidate end on their
## calendar dates — played to their end now —, the others wait for the countdowns) and Am Stück the collapses of the
## candidate's countdowns (SeasonState.collapsed: a floor whose collapse the cast has not seen yet gets it now).
static func _sync_clock(state: GameState, m: CastModel, t: int) -> void:
	var s: SeasonState = state.season
	if not m.binge and s.tempo == "binge":
		m.catch_up(CastModel.hour_of(t), t)
		var idx: int = state.floor_run.index if state.floor_run != null else m.hf
		m.finish_floors(idx - 1)
		for f in range(maxi(1, idx), m.format + 1):
			if m.ct[f - 1] > t:
				m.ct[f - 1] = NO_TIME
		m.binge = true
		m.col = s.collapsed
	if m.binge and s.collapsed > m.col:
		for f in range(m.col + 1, mini(s.collapsed, m.format) + 1):
			if m.ct[f - 1] == NO_TIME:
				m.ct[f - 1] = t
		m.col = s.collapsed
	elif not m.binge:
		m.col = s.collapsed


## The guest stays behind on its floor (a floor change of the candidate).
static func _guest_leaves(m: CastModel, t: int) -> void:
	if m.guest_who >= 0:
		var out: Array[ExploreEvent] = []
		_guest_end(m, t, out)


static func _guest_end(m: CastModel, t: int, out: Array[ExploreEvent]) -> void:
	var e: CastEvent = CastEvent.make(t, "guest_end", m.guest_who, m.hf)
	m.note(e)
	out.append(e.to_explore())
	m.guest_who = -1
	m.guest_left = 0
	m.guest_kind = ""


static func _floor(state: GameState) -> int:
	return state.floor_run.index if state != null and state.floor_run != null else 1


static func _in_safe_room(state: GameState) -> bool:
	return state.floor_run != null and state.floor_run.location != LOCATION_START


static func _room_guests(state: GameState, m: CastModel) -> Array[int]:
	var out: Array[int] = []
	var fr: FloorRun = state.floor_run
	if fr == null or fr.location == LOCATION_START:
		return out
	var places: Array[int] = []
	var weights: PackedInt32Array = []
	for mb: CastMember in m.members:
		if mb.is_ai() and mb.in_play() and mb.fl == fr.index:
			places.append(mb.place)
			weights.append(2 if mb.profile == "helper" or mb.profile == "trader" else 1)
	var r: int = SeedUtil.derive(SeedUtil.derive(state.seed, "cast_room", fr.index), String(fr.location),
		fr.safe_room_visits)
	while out.size() < SAFE_ROOM_SEATS and not places.is_empty():
		var i: int = CastModel.weighted(weights, SeedUtil.mix(r, out.size()) % 1000)
		out.append(places[i])
		places.remove_at(i)
		weights.remove_at(i)
	return out


static func _in_need(state: GameState, m: CastModel) -> int:
	var f: int = _floor(state)
	if state.floor_run == null or m.helped_mask & (1 << f) != 0:
		return -1
	var cands: Array[int] = []
	for mb: CastMember in m.members:
		if mb.is_ai() and mb.in_play() and mb.profile == "unlucky" and mb.fl == f:
			cands.append(mb.place)
	if cands.is_empty():
		return -1
	return cands[SeedUtil.derive(state.seed, "cast_need", f) % cands.size()]


static func _label(state: GameState, mb: CastMember) -> String:
	if mb.has(CastMember.F_HUMAN):
		return state.player_name if mb.place == 0 else "Kandidat:in %d" % mb.place
	if mb.has(CastMember.F_TAKEN):
		var who: String = state.player_name if mb.place == 0 and mb.name == "" else mb.name
		return "%s (%s, %s)" % [who, AI_TAG, TAKEN_TAG]
	return "%s (%s)" % [mb.name, AI_TAG]


static func _view(state: GameState, data: GameData, mb: CastMember) -> Dictionary:
	var human: bool = mb.has(CastMember.F_HUMAN)
	var s: SeasonState = state.season
	var kai: PartyMember = state.member("kai")
	var result: String = ""
	if human:
		result = s.result if mb.place == 0 else ""
	elif mb.has(CastMember.F_FINAL):
		result = "finalist"
	elif mb.is_out():
		result = "buried" if mb.has(CastMember.F_BURIED) else "fallen"
	elif mb.has(CastMember.F_ENDED):
		result = "end"
	var job: String = ""
	var org: Dictionary = data.origin(mb.org) if data != null and mb.org != "" else {}
	if not org.is_empty():
		var role: Variant = org.get("role", {})
		job = str((role as Dictionary).get(mb.form, org.get("name", ""))) if role is Dictionary \
			else str(org.get("name", ""))
	var hobby: Dictionary = data.hobby(mb.hob) if data != null and mb.hob != "" else {}
	var profile: Dictionary = data.cast_profile(mb.profile) if data != null and not human else {}
	var quote: int = 0
	if not human:
		quote = CastModel.ai_quote(mb)
	elif mb.place == 0:
		quote = SeasonRules.quote(state)
	return {"place": mb.place, "name": state.player_name if human and mb.place == 0 else mb.name,
		"label": _label(state, mb), "ai": not human, "taken": mb.has(CastMember.F_TAKEN),
		"profile": "" if human else mb.profile, "profile_name": str(profile.get("name", "")),
		"skill": 0 if human else mb.skill, "pace": 0 if human else mb.pace,
		"floor": _floor(state) if human else mb.fl,
		"level": (kai.level if kai != null else 1) if human else CastModel.level_of(mb),
		"vest": s.vest if human else mb.has(CastMember.F_VEST), "out": result == "fallen" or result == "buried",
		"result": result, "org": mb.org, "job": job, "hobby": str(hobby.get("name", "")), "species": mb.sp,
		"class": mb.cl, "rescues": s.rescues if human else mb.rs, "deaths": s.deaths if human else mb.dt,
		"stairs": s.stairs if human else mb.st, "quote": quote}


## The sort key of a human place (09 §2.7; the candidate's times moved into cast time — the pause left out).
static func _human_key(state: GameState, p: int) -> Array[int]:
	if p != 0:
		return [0, CastModel.NEVER, CastModel.NEVER, p]
	var k: Array[int] = SeasonRules.rank_key(state)
	var shift: int = pause_total(state.season) + state.season.day0_utc
	var fin: int = k[1] - shift if k[1] < (1 << 62) else CastModel.NEVER
	var desc: int = k[2] - shift if k[2] < (1 << 62) else CastModel.NEVER
	return [k[0], fin, desc, p]


static func _news_view(state: GameState, m: CastModel, e: CastEvent) -> Dictionary:
	var lbl: String = _label(state, m.members[e.who]) if e.who >= 0 and e.who < m.places else ""
	var cand: String = lbl
	var tag: String = "cast_" + e.kind
	var count: int = e.n
	if e.kind == "first" and e.who >= 0 and e.who < m.humans:
		tag = "cast_first_you"
	elif e.kind == "collapse" and e.n == 0 and e.m > 0:
		tag = "cast_collapse_out"
		count = e.m
	elif e.kind == "leave" and e.who >= 0 and e.who < m.humans:
		cand = state.player_name if e.who == 0 else "Kandidat:in %d" % e.who   # the human who left, not the AI
	return {"seq": e.seq, "t": e.t, "kind": e.kind, "who": e.who, "label": lbl, "floor": e.at, "n": e.n, "m": e.m,
		"importance": e.importance(), "tag": tag, "ctx": {"cand": cand, "floor": e.at, "count": count}}
