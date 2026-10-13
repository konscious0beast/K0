class_name SleepResolver extends RefCounted
## The sleeper (09 §5; ST1-G). The logout leaves the figure where it stands: SeasonRules records the command "sleep"
## (tactic, room) and calls on_sleep here — the night keeps its cell, its start, the cast's newest event and the
## Sendepause taken during it (on_pause). The login after the absence is the one recorded command "away" {"sec"} (09
## §5.5): apply() walks the absence in time order — the clock (SeasonRules.advance: collapses, rescues, air times and
## the daily programme) and the cast (CastSim.advance), the encounters of a sleeper in a corridor (a roll per started
## four hours, the first after 30 min, at most three: patrols and AI candidates; the fights in RtSim headless with both
## figures on autopilot and the tactic of the logout, the emergency retreat — SleepFight), then the regeneration, the
## "Ausgeruht" of a safe room, last the Regie-Crashkurs (LevelBand) — and the figure wakes up. Am Stück the world waits
## (no clock, no encounter, no rest). The same call in the live game and RunSim.apply (RunRules.apply_season);
## deterministic: integer math, randomness only from the night's stream SeedUtil.derive(seed, "sleep", start of the
## night), no wall clock (the absence is the recorded seconds). Static and pure (core): no autoloads, no SceneTree.
## The texts of the login summary and the notifications: report() / notice_plan() (SleepText).
##
## Events (ExploreEvent.Type.SEASON, tick 0 — RunSim stamps its tick), data {"kind", …}; every event of the night also
## carries "t" (season time) and "day" (air times passed − 1: the season day, −1 = Vorprogramm):
##   away {sec, from, to, at, quiet, refund, tactic, room, cell, place (safe | boss | stairs | corridor), zone,
##   zone_name, room_name, danger, floor, seq} · meet {n, what: patrol | watch | unlucky | note | offer | pass, who,
##   label, danger, enc, angry, outcome: won | lost | retreat | moved_on | fled | none, watched (the label of the
##   Helfer:in who kept watch), exp {member: EXP}, levels {member: [from, to]}, learned {member: [skill ids]}, credits,
##   items, overtime, note, item} · rested {hours, members {id: [before, after, cap]}} · wake {floor, location}
## — between them the events of SeasonRules (collapse, opened, rescue, death, out, end, daily, crash) and CastSim.

const SleepFight := preload("res://core/season/sleep_fight.gd")
const SleepText := preload("res://core/season/sleep_text.gd")
const FixedMath := preload("res://core/stats/fixed_math.gd")

## Kept from ST0 (09 §11.4: the public API stays) — no command is refused with it since ST1-G.
const UNAVAILABLE: String = "season_unavailable"
## Refusal reasons: "away" — awake (no night to end), season_over, clock_jump (longer than seven days plus the rest of a
## running Sendepause: the client records the rest as a pause "clamp" first, V-17); "sleep" — bad_cell (the cell of
## the night is no room of the floor).
const REASONS: PackedStringArray = ["awake", "season_over", "clock_jump", "bad_cell"]
const BLOCK_VERSION: int = 1
const PM: int = 1000
const HOUR: int = 3600
const NO_CELL: Vector2i = Vector2i(-999, -999)
const START: StringName = &"start"          # == RunRules.LOCATION_START

# --- 09 §5.3: encounters in a corridor (start values; test_09_sleep holds the death rates in their bands) ----------
## The danger of a quarter (Viertel): ruhig, unruhig, gefährlich (09 §3.6 Nr. 4).
const DANGERS: PackedStringArray = ["calm", "restless", "dangerous"]
const NO_ENCOUNTERS: int = -1               # a safe room, a boss room, the stairs (09 §5.3)
const CHANCE_PM: PackedInt32Array = [150, 350, 600]
const FIRST_ROLL_SEC: int = 1800            # the first roll 30 min into the night …
const ROLL_EVERY_SEC: int = 14400           # … then one per started four hours
const MAX_ENCOUNTERS: int = 3
const PATROL_PM: int = 700                  # 70 % a patrol, 30 % an AI candidate on the floor (V-10)
## The share of aufgebrachte Streifen by danger (09 ST1-G, G-4: the "Gruppenwahl" of 09 §5.3): they hit hard enough to
## bring a band-typical party under the 25 % of the retreat (SleepFight.ANGRY_DMG_PM) — the rest of the patrols are the
## quarter's groups as they are. With the chances and the retreat they set the death rates per night (test_09_sleep).
const ANGRY_PM: PackedInt32Array = [0, 120, 170]
## What an AI candidate of a profile does at a sleeper (09 §5.3): keeps watch, drags a patrol past, leaves a note,
## leaves a sample (until ST1-E brings goods), walks by.
const PROFILE_WHAT: Dictionary = {"helper": "watch", "unlucky": "unlucky", "rival": "note", "trader": "offer",
	"extra": "pass"}
const ENEMY_TAGS_NEVER: PackedStringArray = ["boss", "elite", "rare", "tutorial"]   # "nie Boss, nie Elite"
# --- 09 §5.2: Ausgeruht ------------------------------------------------------------------------------------------
const RESTED_HOUR_PM: int = 50              # per full hour in a safe room 5 % of the level's EXP …
const RESTED_CAP_PM: int = 1500             # … up to 150 % (1.5 levels, full after 30 h)

static var _memo_key: String = ""          # layout_of: the last layout and its key
static var _memo_layout: FloorLayout = null


# ======================================================================================================================
# Commands
# ======================================================================================================================

## "" or why "away" is refused now (RunRules.season_refusal asks with a season; read-only): the figure is awake →
## awake; the candidate's season is over → season_over; more than seven days plus the rest of a running Sendepause at
## once → clock_jump (Am Stück the clock stands: any length only wakes the figure).
static func refusal(state: GameState, _data: GameData, c: Dictionary) -> String:
	var s: SeasonState = state.season if state != null else null
	if s == null:
		return SeasonRules.NO_SEASON
	if not s.asleep:
		return "awake"
	if s.result != "":
		return "season_over"
	if s.tempo != "binge" and JsonUtil.to_int(c.get("sec", 0)) > max_away(state):
		return "clock_jump"
	return ""


## Applies an accepted "away" (refusal == ""): the night is resolved and the figure wakes up. Returns its events.
static func apply(state: GameState, data: GameData, c: Dictionary) -> Array[ExploreEvent]:
	return _resolve(state, data, maxi(0, JsonUtil.to_int(c.get("sec", 0))))


## The longest "away" accepted now: seven days (V-17) plus the rest of a Sendepause taken during this night.
static func max_away(state: GameState) -> int:
	return SeasonClock.MAX_JUMP_SEC + quiet_left(state)


## Seconds of the night's Sendepause still ahead (the clock stands until then); 0 without one.
static func quiet_left(state: GameState) -> int:
	var s: SeasonState = state.season if state != null else null
	if s == null or s.sleeper.is_empty():
		return 0
	var sl: Dictionary = s.sleeper
	return maxi(0, int(sl.get("at", s.utc)) + int(sl.get("quiet", 0)) - s.utc)


# ======================================================================================================================
# Hooks of SeasonRules
# ======================================================================================================================

## SeasonRules.refusal for "sleep" (after its own checks): the optional "cell" [x, y] — where the figure lies — must be
## a room of the current floor (bad_cell). Without it the night takes the safe room or the last room (on_sleep).
static func sleep_refusal(state: GameState, data: GameData, c: Dictionary) -> String:
	if not c.has("cell"):
		return ""
	var v: Variant = c["cell"]
	if not (v is Array) or (v as Array).size() != 2 or not JsonUtil.is_integral((v as Array)[0]) \
			or not JsonUtil.is_integral((v as Array)[1]):
		return "bad_cell"
	var layout: FloorLayout = _layout(state, data)
	var cell: Vector2i = Vector2i(JsonUtil.to_int((v as Array)[0]), JsonUtil.to_int((v as Array)[1]))
	return "" if layout != null and layout.cell_at(cell) != null else "bad_cell"


## SeasonRules.apply for "sleep" (after asleep, tactic and room are set): the night begins — its start (season time),
## the cell, the floor, the cast's newest event (the login summary's news follow it), no Sendepause yet.
static func on_sleep(state: GameState, data: GameData, c: Dictionary) -> void:
	var s: SeasonState = state.season if state != null else null
	if s == null:
		return
	var cell: Vector2i = _sleep_cell(state, data, c)
	s.sleeper = {"v": BLOCK_VERSION, "at": SeasonRules.now(state), "cell": [cell.x, cell.y],
		"floor": state.floor_run.index if state.floor_run != null else 0, "seq": CastSim.last_seq(state), "quiet": 0}


## SeasonRules._pause for a Sendepause ("user"): taken while the figure sleeps, it belongs to the night — the clock
## stands for `sec` from the start of the night (no encounter, no rest); a login before its end gives the rest back.
static func on_pause(state: GameState, sec: int) -> void:
	var s: SeasonState = state.season if state != null else null
	if s == null or not s.asleep or s.sleeper.is_empty():
		return
	s.sleeper["quiet"] = int(s.sleeper.get("quiet", 0)) + maxi(0, sec)


# ======================================================================================================================
# Queries (the logout dialog, the login summary, the tests)
# ======================================================================================================================

## Where a figure would sleep at `cell` on the current floor (NO_CELL or no room: the entrance; in a safe room always
## that room): {"cell", "room" (safe room id or ""), "room_name", "kind": safe | boss | stairs | corridor, "zone" (key),
## "zone_name", "danger" (0–2 or NO_ENCOUNTERS), "chance_pm", "next_safe" {"id", "name", "rooms"} (the nearest safe
## room through the doors; {} without one)}.
static func place_of(state: GameState, data: GameData, cell: Vector2i = NO_CELL) -> Dictionary:
	var out: Dictionary = {"cell": [0, 0], "room": "", "room_name": "", "kind": "corridor", "zone": "",
		"zone_name": "", "danger": 0, "chance_pm": CHANCE_PM[0], "next_safe": {}}
	var layout: FloorLayout = _layout(state, data)
	var fr: FloorRun = state.floor_run if state != null else null
	if layout == null or fr == null:
		return out
	var at: Vector2i = cell
	if fr.location != START:
		at = _room_cell(layout, String(fr.location))
	elif at == NO_CELL or layout.cell_at(at) == null:
		at = layout.start
	out["cell"] = [at.x, at.y]
	var rc: RoomCell = layout.cell_at(at)
	if fr.location != START:
		out["room"] = String(fr.location)
		out["room_name"] = str((layout.safe_room_info.get(String(fr.location), {}) as Dictionary).get("name", ""))
		out["kind"] = "safe"
	elif rc != null:
		match rc.kind:
			RoomCell.Kind.SAFE:
				out["kind"] = "safe"
			RoomCell.Kind.QUARTER_BOSS, RoomCell.Kind.FLOOR_BOSS:
				out["kind"] = "boss"
			RoomCell.Kind.STAIRS:
				out["kind"] = "stairs"
	var def: FloorDef = data.floor_def(fr.index) if data != null else null
	var key: String = zone_key(layout, at)
	out["zone"] = key
	out["zone_name"] = zone_name(layout, def, key)
	var d: int = danger_of(def, layout, at) if fr.location == START else NO_ENCOUNTERS
	out["danger"] = d
	out["chance_pm"] = CHANCE_PM[d] if d >= 0 else 0
	out["next_safe"] = nearest_safe_room(layout, fr, at)
	return out


## The danger of the quarter of `cell` (09 §3.6 Nr. 4): NO_ENCOUNTERS in a safe room, a boss room and on the stairs
## (09 §5.3); the quarter's danger of the generator v2 (FloorLayout.zones[…].danger: the first quarter calm, the last —
## stairs and bosses — dangerous, the others restless; ZoneGenerator.danger_at), else a "danger" of the quarter in
## floors.json (optional), else the quarter of the entrance is calm, the quarter of the stairs and of the Etagenboss
## dangerous, the others restless (floor 1's handmade quarters, G-3); floors without quarters by depth (thirds).
static func danger_of(def: FloorDef, layout: FloorLayout, cell: Vector2i) -> int:
	var rc: RoomCell = layout.cell_at(cell) if layout != null else null
	if rc == null:
		return 0
	match rc.kind:
		RoomCell.Kind.SAFE, RoomCell.Kind.QUARTER_BOSS, RoomCell.Kind.FLOOR_BOSS, RoomCell.Kind.STAIRS:
			return NO_ENCOUNTERS
	return zone_danger(def, layout, zone_key(layout, cell))


## The danger of quarter `key` (zone_key) — see danger_of.
static func zone_danger(def: FloorDef, layout: FloorLayout, key: String) -> int:
	if key.begins_with("depth"):
		return clampi(key.substr(5).to_int(), 0, DANGERS.size() - 1)
	if layout != null and layout.zones.has(key) and DANGERS.has(str((layout.zones[key] as Dictionary).get("danger", ""))):
		return DANGERS.find(str((layout.zones[key] as Dictionary)["danger"]))
	if def != null:
		for z: Dictionary in def.zones:
			if str(z.get("id", "")) == key and DANGERS.has(str(z.get("danger", ""))):
				return DANGERS.find(str(z.get("danger", "")))
	var start: RoomCell = layout.cell_at(layout.start)
	if start != null and start.zone == key:
		return 0
	for c: Vector2i in [layout.stairs, layout.floor_boss]:
		var rc: RoomCell = layout.cell_at(c)
		if rc != null and rc.zone == key:
			return DANGERS.size() - 1
	return 1


## The quarter of `cell`: its zone id, or "depth0" … "depth2" (thirds of the deepest room) on floors without zones.
static func zone_key(layout: FloorLayout, cell: Vector2i) -> String:
	var rc: RoomCell = layout.cell_at(cell) if layout != null else null
	if rc == null:
		return ""
	if rc.zone != "":
		return rc.zone
	var deepest: int = 0
	for c: Vector2i in layout.sorted_cells():
		deepest = maxi(deepest, layout.cell_at(c).depth)
	return "depth%d" % clampi(rc.depth * DANGERS.size() / maxi(1, deepest + 1), 0, DANGERS.size() - 1)


## The name of quarter `key` (the layout's zones, then floors.json zones); "" without one.
static func zone_name(layout: FloorLayout, def: FloorDef, key: String) -> String:
	if layout != null and layout.zones.has(key):
		return str((layout.zones[key] as Dictionary).get("name", ""))
	if def != null:
		for z: Dictionary in def.zones:
			if str(z.get("id", "")) == key:
				return str(z.get("name", ""))
	return ""


## The safe room nearest to `cell` through the doors (opened gates count; ties in layout order): {"id", "name",
## "rooms" (doors to pass)}; {} without one.
static func nearest_safe_room(layout: FloorLayout, fr: FloorRun, cell: Vector2i) -> Dictionary:
	if layout == null or layout.safe_rooms.is_empty():
		return {}
	var dist: Dictionary = layout.distances(cell, fr.opened_gates if fr != null else PackedStringArray())
	var best: Vector2i = NO_CELL
	var best_d: int = 1 << 30
	for c: Vector2i in layout.safe_rooms:
		var d: int = int(dist.get(c, 1 << 29))
		if d < best_d:
			best_d = d
			best = c
	if best == NO_CELL or best_d >= 1 << 29:
		return {}
	var id: String = str(layout.safe_room_ids.get(best, ""))
	return {"id": id, "name": str((layout.safe_room_info.get(id, {}) as Dictionary).get("name", "")), "rooms": best_d}


## The patrols of the quarter of `cell` at danger `tier` (09 §5.3: "eine reguläre Gruppe aus dem Pool des Viertels …
## nie Boss, nie Elite"): the quarter's pool in floors.json (ST1-C), its stray spawners and the groups placed in it — a
## higher tier than the quarter's own (the Pechvogel's patrol) takes the quarters of that tier; without any the
## floor's regular groups. Sorted encounter ids.
static func patrol_pool(state: GameState, data: GameData, layout: FloorLayout, cell: Vector2i,
		tier: int) -> PackedStringArray:
	var out: PackedStringArray = []
	var fr: FloorRun = state.floor_run if state != null else null
	var def: FloorDef = data.floor_def(fr.index) if data != null and fr != null else null
	if layout == null or def == null:
		return out
	var own: String = zone_key(layout, cell)
	var keys: PackedStringArray = []
	if zone_danger(def, layout, own) >= tier:
		keys.append(own)
	else:
		for c: Vector2i in layout.sorted_cells():
			var k: String = zone_key(layout, c)
			if not keys.has(k) and danger_of(def, layout, c) == tier:
				keys.append(k)
		if keys.is_empty():
			keys.append(own)
	for k: String in keys:
		for z: Dictionary in def.zones:
			if str(z.get("id", "")) == k:
				for e: Variant in (z.get("pool", []) as Array):
					_add_patrol(data, out, str(e))
		for sp: Dictionary in layout.spawners:
			if str(sp.get("zone", "")) == k:
				for e: Variant in (sp.get("pool", []) as Array):
					_add_patrol(data, out, str(e))
		for es: EnemySpawn in layout.enemies:
			if not es.is_boss and zone_key(layout, es.cell) == k:
				_add_patrol(data, out, es.encounter_id)
	if out.is_empty():
		for es: EnemySpawn in layout.enemies:
			_add_patrol(data, out, es.encounter_id)
		for enc: EncounterDef in def.encounters:
			if enc.weight > 0:
				_add_patrol(data, out, enc.id)
	out.sort()
	return out


## A regular group (patrol): a known encounter, no boss, no tutorial, no show boss, one can flee from, and no enemy
## tagged boss, elite, rare or tutorial.
static func is_patrol(data: GameData, enc_id: String) -> bool:
	if data == null or not data.has_id("encounters", enc_id):
		return false
	var enc: EncounterDef = data.encounter(enc_id)
	if enc.boss or enc.tutorial or not enc.show_boss.is_empty() or not enc.can_flee or enc.enemies.is_empty():
		return false
	for id: String in enc.enemies:
		if not data.has_id("enemies", id):
			return false
		for t: String in ENEMY_TAGS_NEVER:
			if data.enemy(id).tags.has(t):
				return false
	return true


## The layout of the current floor (null without one). A night asks for it many times: the last one is kept (keyed by
## the data, the floor and its seed — a layout is generated data, read only here).
static func layout_of(state: GameState, data: GameData) -> FloorLayout:
	var fr: FloorRun = state.floor_run if state != null else null
	var def: FloorDef = data.floor_def(fr.index) if data != null and fr != null else null
	if def == null:
		return null
	var key: String = "%d|%s|%d" % [data.get_instance_id(), def.id, fr.seed]
	if key != _memo_key or _memo_layout == null:
		_memo_layout = DungeonGenerator.generate(def, fr.seed)
		_memo_key = key
	return _memo_layout


## The rested pool of `member` in per mille of its level's EXP (09 §5.2: the bar's blue part, "Ausgeruht 40 %").
static func rested_pm(state: GameState, data: GameData, member: PartyMember) -> int:
	if member == null:
		return 0
	var need: int = LevelBand.exp_to_next(state, data, member.level)
	if need <= 0:
		return 0
	return RESTED_CAP_PM if member.rested >= need * RESTED_CAP_PM / PM else member.rested * PM / need


## What the logout dialog says for a figure lying at `cell` (09 §5.1 Nr. 5): see SleepText.logout_info.
static func logout_info(state: GameState, data: GameData, cell: Vector2i, tz_sec: int) -> Dictionary:
	return SleepText.logout_info(state, data, place_of(state, data, cell), tz_sec)


## The login summary of the night whose events are `events` (the events of "away", in order): see SleepText.report.
static func report(state: GameState, data: GameData, events: Array, tz_sec: int, auto: bool = false) -> Dictionary:
	return SleepText.report(state, data, events, tz_sec, auto)


## The notifications of a sleeper from `now_utc` on (09 §2.9; opt-in): see SleepText.notice_plan.
static func notice_plan(state: GameState, data: GameData, now_utc: int, prefs: Dictionary,
		tz_sec: int) -> Array[Dictionary]:
	return SleepText.notice_plan(state, data, now_utc, prefs, tz_sec)


## "3 Tage 4 Stunden" (SleepText.duration) — the dialogs' words for a span of season time.
static func duration_text(sec: int) -> String:
	return SleepText.duration(sec)


## "Vorsichtig" (SleepText.tactic_name).
static func tactic_name(tactic: String) -> String:
	return SleepText.tactic_name(tactic)


# ======================================================================================================================
# The night
# ======================================================================================================================

## The context of one resolution.
class _Night extends RefCounted:
	var sb: int = 0                         # the night's stream: SeedUtil.derive(seed, "sleep", at)
	var at: int = 0                         # season time of the logout
	var t0: int = 0                         # the clock at the login (before this absence)
	var end: int = 0                        # the clock after it
	var calm_from: int = 0                  # the Sendepause of the night ends here (the clock stands before)
	var refund: int = 0                     # Sendepause given back (a login before its end)
	var tactic: String = "careful"
	var cell: Vector2i = Vector2i.ZERO
	var layout: FloorLayout = null
	var floor_index: int = 0
	var k: int = 0                          # the next roll
	var meets: int = 0                      # encounters so far
	var watch: int = -1                     # the Helfer:in keeping watch (place), -1 none
	var watch_label: String = ""
	var rest_from: int = 0                  # the last fight (or the start): regeneration since then
	var bal: RtBalance = null               # the rt balance of the data (regeneration)
	var room_since: int = -1                # season time from which the figure lies in a safe room
	var out: Array[ExploreEvent] = []


static func _resolve(state: GameState, data: GameData, sec: int) -> Array[ExploreEvent]:
	var s: SeasonState = state.season
	var n: _Night = _Night.new()
	var sl: Dictionary = s.sleeper
	n.t0 = s.utc
	n.at = int(sl.get("at", s.utc))
	n.end = s.utc + sec
	n.sb = SeedUtil.derive(state.seed, "sleep", n.at)
	n.tactic = s.sleep_tactic if RtVocab.RT_PRESETS.has(s.sleep_tactic) else "careful"
	n.calm_from = n.at + int(sl.get("quiet", 0))
	var binge: bool = s.tempo == "binge"
	if not binge and n.end < n.calm_from:
		n.refund = n.calm_from - n.end
		_unpause(s, n.refund)
		n.calm_from = n.end
	_locate(state, data, n, _sleep_cell(state, data, sl))
	n.rest_from = n.at
	n.room_since = n.at if s.sleep_room != "" else -1
	while _roll_time(n) < s.utc:
		n.k += 1
	var place: Dictionary = place_of(state, data, n.cell)
	n.out.append(_ev(s, "away", {"sec": sec, "from": n.t0, "to": n.end, "at": n.at, "quiet": int(sl.get("quiet", 0)),
		"refund": n.refund, "tactic": n.tactic, "room": s.sleep_room, "cell": [n.cell.x, n.cell.y],
		"place": place["kind"], "zone": place["zone"], "zone_name": place["zone_name"],
		"room_name": place["room_name"], "danger": place["danger"], "floor": n.floor_index,
		"seq": int(sl.get("seq", 0))}))
	if not binge:
		_walk(state, data, n)
		if s.result == "":
			_regen(state, data, n, n.end - n.rest_from)
			_rest(state, data, n)
			for e: ExploreEvent in LevelBand.crash_course(state, data):   # 09 §5.5: last the Regie-Crashkurs
				n.out.append(_stamp(e, s))
	s.asleep = false
	s.sleep_room = ""
	s.sleeper = {}
	var fr: FloorRun = state.floor_run
	n.out.append(_ev(s, "wake", {"floor": fr.index if fr != null else 0,
		"location": String(fr.location) if fr != null else String(START)}))
	return n.out


## The absence in time order (09 §5.5): the clock to the next roll or collapse — whichever comes first — then the roll
## of a sleeper still lying in a corridor (a collapse in the same second comes first: a rescue ends the rolls).
static func _walk(state: GameState, data: GameData, n: _Night) -> void:
	var s: SeasonState = state.season
	var guard: int = 4096
	while guard > 0:
		guard -= 1
		var meet: bool = _can_meet(state, data, n)
		var t_roll: int = _roll_time(n)
		var t: int = n.end
		if meet and t_roll <= t:
			t = t_roll
		var tc: int = _next_collapse(s)
		if tc > s.utc and tc < t:
			t = tc
		if t > s.utc:
			_clock_to(state, data, n, t)
		if s.result != "":                          # out, the end, the finale: the clock runs on for the guest
			if s.utc < n.end:
				_clock_to(state, data, n, n.end)
			return
		if meet and s.utc == t_roll:
			if _can_meet(state, data, n):
				_roll(state, data, n)
			else:
				n.k += 1
			continue
		if s.utc >= n.end:
			return


## Moves the season clock to `t` (SeasonRules.advance without the combat grace — a sleeper's fight waits for nobody); a
## rescue puts the figure into a safe room of the next floor. The cast follows where the night needs it (the AI on the
## floor at a roll, a floor change) — CastSim.advance does not depend on the slices, and RunRules.apply_season brings
## it to the end of the night after "away".
static func _clock_to(state: GameState, data: GameData, n: _Night, t: int) -> void:
	var s: SeasonState = state.season
	var floor_before: int = state.floor_run.index if state.floor_run != null else 0
	var evs: Array[ExploreEvent] = SeasonRules.advance(state, data, t - s.utc, false)
	var moved: bool = state.floor_run != null and state.floor_run.index != floor_before
	if moved:
		evs.append_array(CastSim.advance(state, data))
	for e: ExploreEvent in evs:
		n.out.append(_stamp(e, s))
	if moved:
		_locate(state, data, n, NO_CELL)
	if s.sleep_room != "" and n.room_since < 0:
		n.room_since = s.utc


## One roll of the night (09 §5.3): the chance of the quarter's danger; an encounter is a patrol (70 %) or an AI
## candidate on the floor (30 %, by profile; none on the floor → a patrol).
static func _roll(state: GameState, data: GameData, n: _Night) -> void:
	var s: SeasonState = state.season
	var k: int = n.k
	n.k += 1
	var d: int = danger_of(data.floor_def(n.floor_index), n.layout, n.cell)
	if d < 0 or SeedUtil.derive(n.sb, "roll", k) % PM >= CHANCE_PM[d]:
		return
	n.meets += 1
	var ev: Dictionary = {"n": n.meets, "what": "patrol", "who": -1, "label": "", "danger": d, "enc": "",
		"angry": false, "outcome": "", "watched": "", "exp": {}, "levels": {}, "learned": {}, "credits": 0,
		"items": [], "overtime": 0}
	if SeedUtil.derive(n.sb, "kind", k) % PM >= PATROL_PM:
		for e: ExploreEvent in CastSim.advance(state, data):   # the cast as it is now
			n.out.append(_stamp(e, s))
		var ai: Array[Dictionary] = CastSim.floor_ai(state, data, n.floor_index)
		if not ai.is_empty():
			var p: Dictionary = ai[SeedUtil.derive(n.sb, "cand", k) % ai.size()]
			ev["what"] = str(PROFILE_WHAT.get(str(p["profile"]), "pass"))
			ev["who"] = int(p["place"])
			ev["label"] = str(p["label"])
	var tail: Array[ExploreEvent] = []
	match str(ev["what"]):
		"patrol":
			ev["watched"] = n.watch_label
			tail = _fight(state, data, n, ev, d, n.watch >= 0, k)
			n.watch = -1
			n.watch_label = ""
		"unlucky":                                  # "die Gruppe eine Stufe höher": a patrol of the next danger (G-5)
			tail = _fight(state, data, n, ev, mini(DANGERS.size() - 1, d + 1), false, k)
		"watch":
			n.watch = int(ev["who"])
			n.watch_label = str(ev["label"])
		"note":
			ev["note"] = SeedUtil.derive(n.sb, "note", k)
		"offer":                                    # ST1-E brings the goods; until then a sample of the cheapest potion
			var item: String = LevelBand.catch_up_potion(data)
			if item != "" and state.inventory != null:
				state.inventory.add_item_or_credits(data, item, 1)
				ev["item"] = item
	n.out.append(_ev(s, "meet", ev))
	n.out.append_array(tail)


## The fight of an encounter (09 §5.3): regeneration since the last fight, a patrol of the quarter's pool at danger
## `tier` (aufgebracht by the roll ANGRY_PM[tier], never while watched), the fight (SleepFight), its booking — EXP
## without "Ausgeruht" (the pool is put aside meanwhile), loot, and on a defeat the death rule
## (SeasonRules.on_combat_end: dress rehearsal, the medics, Ohne Netz out). Fills `ev`; returns the events of the death
## rule.
static func _fight(state: GameState, data: GameData, n: _Night, ev: Dictionary, tier: int, watched: bool,
		k: int) -> Array[ExploreEvent]:
	var out: Array[ExploreEvent] = []
	var s: SeasonState = state.season
	_regen(state, data, n, s.utc - n.rest_from)
	var pool: PackedStringArray = patrol_pool(state, data, n.layout, n.cell, tier)
	if pool.is_empty():
		ev["outcome"] = "none"
		return out
	var enc: String = pool[SeedUtil.derive(n.sb, "pool", k) % pool.size()]
	var angry: bool = not watched and SeedUtil.derive(n.sb, "angry", k) % PM < ANGRY_PM[clampi(tier, 0, 2)]
	ev["enc"] = enc
	ev["angry"] = angry
	var r: Dictionary = SleepFight.run(state, data, {"enc": enc, "cell": n.cell, "tactic": n.tactic, "angry": angry,
		"watched": watched, "seed": SeedUtil.derive(n.sb, "battle", k),
		"retreat": SeedUtil.derive(n.sb, "retreat", k) % PM})
	var result: BattleResult = r.get("result", null)
	ev["outcome"] = str(r.get("end", "none"))
	if result == null:
		return out
	var pools: Dictionary = {}
	var levels: Dictionary = {}
	for m: PartyMember in state.party:
		if m != null:
			pools[m.id] = m.rested
			levels[m.id] = m.level
			m.rested = 0
	var rw: BattleRewards = BattleBridge.apply_result(state, data, result)
	for m: PartyMember in state.party:
		if m != null:
			m.rested = int(pools.get(m.id, 0))
			if m.level != int(levels.get(m.id, m.level)):
				(ev["levels"] as Dictionary)[m.id] = [int(levels[m.id]), m.level]
	for info: LevelUpInfo in rw.level_ups:
		if info != null and not info.learned.is_empty():
			(ev["learned"] as Dictionary)[info.member_id] = Array(info.learned)
	ev["exp"] = rw.exp_by_member.duplicate()
	ev["credits"] = rw.credits
	ev["items"] = Array(rw.items)
	ev["overtime"] = rw.overtime
	for e: ExploreEvent in SeasonRules.on_combat_end(state, data, result):
		out.append(_stamp(e, s))
	s.after_combat = false
	n.rest_from = s.utc
	if result.outcome == BattleResult.Outcome.DEFEAT:      # the medics: a safe room (rested from now) or the entrance
		_locate(state, data, n, NO_CELL)
		if s.sleep_room != "" and n.room_since < 0:
			n.room_since = s.utc
	return out


## Ausgeruht (09 §5.2): per full hour in a safe room (after the Sendepause) 5 % of the level's EXP, at most 150 %.
static func _rest(state: GameState, data: GameData, n: _Night) -> void:
	var s: SeasonState = state.season
	if n.room_since < 0:
		return
	var hours: int = maxi(0, n.end - maxi(n.room_since, n.calm_from)) / HOUR
	if hours <= 0:
		return
	var members: Dictionary = {}
	for m: PartyMember in state.party:
		if m == null:
			continue
		var need: int = LevelBand.exp_to_next(state, data, m.level)
		var cap: int = need * RESTED_CAP_PM / PM
		var before: int = m.rested
		if before < cap:
			m.rested = mini(cap, before + FixedMath.div_round(need * RESTED_HOUR_PM * hours, PM))
		members[m.id] = [before, m.rested, cap]
	n.out.append(_ev(s, "rested", {"hours": hours, "members": members}))


## Regeneration out of combat over `sec` seconds (07 §2.7, the rule of RunSim's step 7 on the elapsed time): every
## REGEN_PERIOD_TICKS 2 % MP, HP 0.5 % once REGEN_HP_DELAY_TICKS passed; members at 0 HP do not regenerate.
static func _regen(state: GameState, data: GameData, n: _Night, sec: int) -> void:
	if sec <= 0 or data == null:
		return
	if n.bal == null:
		n.bal = RtBalance.from_data(data)
	var bal: RtBalance = n.bal
	var period: int = maxi(1, bal.i("REGEN_PERIOD_TICKS"))
	var mp_n: int = sec * FloorRun.TICKS_PER_SEC / period
	var hp_n: int = maxi(0, mp_n - (bal.i("REGEN_HP_DELAY_TICKS") + period - 1) / period + 1)
	for m: PartyMember in state.party:
		if m == null or m.hp <= 0:
			continue
		var sb: StatBlock = Progression.total_stats(m, data)
		var max_hp: int = sb.values[StatBlock.Stat.HP]
		var max_mp: int = sb.values[StatBlock.Stat.MP]
		var mp_step: int = maxi(1, FixedMath.div_round(max_mp * bal.i("REGEN_MP_PM"), PM))
		var hp_step: int = maxi(1, FixedMath.div_round(max_hp * bal.i("REGEN_HP_PM"), PM))
		m.mp = mini(max_mp, m.mp + mini(max_mp, mp_n * mp_step))
		m.hp = mini(max_hp, m.hp + mini(max_hp, hp_n * hp_step))


## The figure lies at `cell` on the current floor (NO_CELL: the safe room it is in, else the entrance).
static func _locate(state: GameState, data: GameData, n: _Night, cell: Vector2i) -> void:
	n.layout = _layout(state, data)
	n.floor_index = state.floor_run.index if state.floor_run != null else 0
	n.cell = Vector2i.ZERO
	if n.layout == null:
		return
	var fr: FloorRun = state.floor_run
	if fr.location != START:
		n.cell = _room_cell(n.layout, String(fr.location))
	elif cell != NO_CELL and n.layout.cell_at(cell) != null:
		n.cell = cell
	else:
		n.cell = n.layout.start


## Rolls happen while the figure lies in a corridor of a calendar season (09 §5.1 Nr. 4: Am Stück none), outside a
## boss room and the stairs, fewer than three times per absence.
static func _can_meet(state: GameState, data: GameData, n: _Night) -> bool:
	var s: SeasonState = state.season
	if s.tempo == "binge" or s.result != "" or s.sleep_room != "" or n.meets >= MAX_ENCOUNTERS or n.layout == null:
		return false
	return danger_of(data.floor_def(n.floor_index), n.layout, n.cell) >= 0


## The season time of roll n.k: 30 min after the Sendepause, then every four hours.
static func _roll_time(n: _Night) -> int:
	return n.calm_from + FIRST_ROLL_SEC + n.k * ROLL_EVERY_SEC


## The date of the next collapse (a hold first); -1 when every floor collapsed.
static func _next_collapse(s: SeasonState) -> int:
	if s.collapsed >= s.format or s.collapsed >= s.collapse_utc.size():
		return -1
	return s.hold_utc if s.hold_utc > 0 else s.collapse_utc[s.collapsed]


## A login before the end of the night's Sendepause gives the rest back (09 §2.9: the budget of 14 days counts only the
## pause taken): every open date moves back by `sec`.
static func _unpause(s: SeasonState, sec: int) -> void:
	for i in range(s.collapsed, s.collapse_utc.size()):
		s.collapse_utc[i] -= sec
	if s.hold_utc > 0:
		s.hold_utc -= sec
	s.next_air_utc -= sec
	s.pause_sec = maxi(0, s.pause_sec - sec)


## The cell of the night: the command's / block's "cell", else the safe room the figure stands in, else the last room
## entered, else the entrance.
static func _sleep_cell(state: GameState, data: GameData, c: Dictionary) -> Vector2i:
	var layout: FloorLayout = _layout(state, data)
	var fr: FloorRun = state.floor_run if state != null else null
	if layout == null or fr == null:
		return Vector2i.ZERO
	if fr.location != START:
		return _room_cell(layout, String(fr.location))
	var v: Variant = c.get("cell", null)
	if v is Array and (v as Array).size() == 2:
		var cell: Vector2i = Vector2i(JsonUtil.to_int((v as Array)[0]), JsonUtil.to_int((v as Array)[1]))
		if layout.cell_at(cell) != null:
			return cell
	return fr.visited.back() if not fr.visited.is_empty() else layout.start


static func _room_cell(layout: FloorLayout, room_id: String) -> Vector2i:
	for c: Vector2i in layout.safe_rooms:
		if str(layout.safe_room_ids.get(c, "")) == room_id:
			return c
	return layout.start


static func _layout(state: GameState, data: GameData) -> FloorLayout:
	return layout_of(state, data)


static func _add_patrol(data: GameData, out: PackedStringArray, enc_id: String) -> void:
	if not out.has(enc_id) and is_patrol(data, enc_id):
		out.append(enc_id)


## Every event of the night carries its season time and day.
static func _stamp(e: ExploreEvent, s: SeasonState) -> ExploreEvent:
	if not e.data.has("t"):
		e.data["t"] = s.utc
		e.data["day"] = s.airs - 1
	return e


static func _ev(s: SeasonState, kind: String, data: Dictionary) -> ExploreEvent:
	var d: Dictionary = {"kind": kind, "t": s.utc, "day": s.airs - 1}
	d.merge(data)
	return ExploreEvent.make(ExploreEvent.Type.SEASON, 0, d)
