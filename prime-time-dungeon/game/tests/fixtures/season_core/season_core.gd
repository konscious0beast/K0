extends RefCounted
## Test kit of 09 ST1-B (the season core): the real data with placeholder floors — floors 2..N built from floor 2's
## regular encounters (a classic procedural layout without Kulisse, quarters or level band, encounter ids renamed,
## floor-1 enemies with their rt blocks, a Revier- and an Etagenboss each) — so a season runs through every floor of a
## format in the core, independent of the season content (ST1-C1: the real floors 2–6 are generator-v2 floors with
## keys, levels and programme doors; test_09_zone_generator plays them); the start command of a season at a fixed
## day 0; season runs (RunSim, recording into a run log) and synthetic combat results. Private test helper (no
## class_name): preload it.

const DAY: int = 86400
const DAY0: int = 1791921600               # day 0 of the test seasons (the first air time, a whole UTC hour)
const START: int = DAY0 - 3600             # the start: one hour of Vorprogramm before day 0
const SEED: int = 4242
const PLACEHOLDER_ENEMY: String = "enm_kanalratte"   # a floor-1 enemy with its rt block

static var _cache: Dictionary = {}         # floor count → GameData


## The real data with placeholder floors 2..`floors` in place of the real floors 2.. — cached per floor count.
static func data(floors: int = 6) -> GameData:
	if _cache.has(floors):
		return _cache[floors]
	var raw: Dictionary = {}
	for t: String in GameData.TABLES:
		raw[t] = JsonUtil.read_file("res://data/%s.json" % t)
	if FileAccess.file_exists("res://data/" + GameData.RT_BALANCE_FILE):
		raw["rt_balance"] = JsonUtil.read_file("res://data/" + GameData.RT_BALANCE_FILE)
	var entries: Array = (raw["floors"] as Dictionary)["entries"]
	var stub: Dictionary = {}
	var first: Array = []
	for e: Variant in entries:
		if int((e as Dictionary)["index"]) == 2:
			stub = (e as Dictionary).duplicate(true)
		elif int((e as Dictionary)["index"]) == 1:
			first.append(e)
	entries.assign(first)                                        # floor 1 as it is, the placeholders after it
	for key: String in ["zones", "level_band", "variant"]:      # a classic procedural floor (no generator v2)
		stub.erase(key)
	stub["theme"] = "mall"
	stub["playable"] = true                                      # playable: its enemies need rt blocks (V10)
	var regular: Array = []
	for enc: Variant in (stub["encounters"] as Array):          # the rollable ones; bosses below, no show boss
		if not bool((enc as Dictionary).get("boss", false)) and int((enc as Dictionary).get("weight", 0)) > 0:
			(enc as Dictionary)["enemies"] = [PLACEHOLDER_ENEMY]
			regular.append(enc)
	stub["encounters"] = regular
	for n in range(2, floors + 1):
		var f: Dictionary = stub.duplicate(true)
		f["id"] = "floor_%d" % n
		f["index"] = n
		if n > 2:
			f["name"] = "Etage %d – Platzhalter" % n
		for enc: Variant in (f["encounters"] as Array):
			(enc as Dictionary)["id"] = str((enc as Dictionary)["id"]).replace("enc_f2_", "enc_f%d_" % n)
		for key: String in ["quarter_boss", "floor_boss"]:           # placeholder bosses (the Quote, the finale)
			var boss_id: String = "enc_f%d_%s" % [n, "qb" if key == "quarter_boss" else "fb"]
			(f["encounters"] as Array).append({"id": boss_id, "enemies": [PLACEHOLDER_ENEMY], "weight": 0,
				"boss": true})
			f[key] = boss_id
		entries.append(f)
	var d: GameData = GameData.new()
	if not d.load_from_tables(raw, "season_core_%d" % floors):
		push_error("[season_core] the placeholder data are invalid: " + "; ".join(d.errors))
	_cache[floors] = d
	return d


## The start command of a season of template `def_id` (its format from the data), day 0 = DAY0, started at `start`.
static func start_cmd(d: GameData, def_id: String = "ssn_basis", tempo: String = "calendar", mode: String = "net",
		start: int = START) -> Dictionary:
	var format: int = d.season_def(def_id).format
	return {"t": "season", "v": 1, "op": "start", "def": def_id, "format": format, "tempo": tempo, "mode": mode,
		"number": 1, "day0_utc": DAY0, "collapse_utc": SeasonClock.schedule(DAY0, format), "cast": {}, "utc": start}


## A RunSim season run recording into a run log: the start, floor 1, the hero — like Game.start_season.
static func sim(d: GameData, def_id: String = "ssn_basis", tempo: String = "calendar", mode: String = "net",
		seed: int = SEED, hero: String = "kai") -> RunSim:
	var st: GameState = GameState.create_new(d, 0, GameState.DEFAULT_NAME, seed, &"prime")
	RunRules.rt_start(st, d)
	var s: RunSim = RunSim.new(d, st, {}, {})
	var rl: RunLog = RunLog.new()
	rl.header = {"schema": 1, "seed": seed, "slot": 0, "mode": "campaign", "difficulty": "prime",
		"sim_version": RunSim.SIM_VERSION, "event_id": "", "run_id": "run_st1b_test", "player_id": "local",
		"window_id": "", "league": "", "combat_mode": "realtime", "rt_version": RunRules.RT_VERSION}
	s.run_log = rl
	s.apply(start_cmd(d, def_id, tempo, mode))
	s.apply({"t": "floor", "floor": 1})
	s.apply({"t": "hero", "id": hero})
	return s


## Puts the run of `s` on floor `n` directly (RunRules.start_floor; tests of a floor's rules, no stairs).
static func put_on_floor(s: RunSim, n: int) -> void:
	RunRules.start_floor(s.state, s.data, n)


## A synthetic combat result (SeasonRules.on_combat_end): `outcome`, the encounter, everyone alive or KO.
static func result(outcome: BattleResult.Outcome, encounter_id: String = "") -> BattleResult:
	var r: BattleResult = BattleResult.new()
	r.outcome = outcome
	r.encounter_id = encounter_id
	return r


## The SEASON events of `events` as their kinds, in order.
static func kinds(events: Array) -> Array:
	var out: Array = []
	for e: Variant in events:
		if e is ExploreEvent and (e as ExploreEvent).type == ExploreEvent.Type.SEASON:
			out.append(str((e as ExploreEvent).data.get("kind", "")))
	return out


## The first SEASON event of kind `kind` in `events` (its data), {} if none.
static func event(events: Array, kind: String) -> Dictionary:
	for e: Variant in events:
		if e is ExploreEvent and (e as ExploreEvent).type == ExploreEvent.Type.SEASON \
				and str((e as ExploreEvent).data.get("kind", "")) == kind:
			return (e as ExploreEvent).data
	return {}


## The season clock of `s` to season time `t` with clock commands of at most seven days (the events of all).
static func clock_to(s: RunSim, t: int) -> Array:
	var out: Array = []
	while s.state.season.utc < t:
		out.append_array(s.apply({"t": "clock", "sec": mini(t - s.state.season.utc, SeasonClock.MAX_JUMP_SEC)}))
	return out
