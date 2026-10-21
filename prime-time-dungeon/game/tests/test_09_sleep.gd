extends TestCase
## 09 §11.6 test_09_sleep (ST1-G): the sleeper. "sleep" starts the night where the figure lies; "away" is
## deterministic (the same state and duration → the same events and hash); encounters of a sleeper in a corridor —
## patrols fought in RtSim headless on autopilot with the tactic of "sleep", the emergency retreat, the aufgebrachte
## Streife, and every profile of the AI cast (watch, the Pechvogel's patrol, the note, the offer, passing by); none in a
## safe room, a boss room or on the stairs, none Am Stück; "Ausgeruht" in a safe room (5 % of a level per full hour,
## at most 150 %, not during a Sendepause); the Sendepause of a night and its refund; the clock jump; a collapse and a
## death while asleep by mode; the login summary, the daily summary and the notification plan; and the death rates Ohne
## Netz per night in the bands of 09 §5.3 (calm < 0.5 %, restless 1–2 %, dangerous 3–6 %) — PTD_SLEEP_NIGHTS nights per
## danger (default 100, a smoke with the binomial tolerance; 1000 = the measurement of 09 §5.3 with the bands as they
## are: `PTD_SLEEP_NIGHTS=1000 tools/check.sh --tests-only --filter=test_09_sleep`, G-9).
##
## The night's draws come from SleepResolver's stream SeedUtil.derive(seed, "sleep", start of the night) with the
## purposes roll, kind, cand, pool, angry, retreat, battle, note (k = the roll); _draws mirrors them to find a seed with
## a wanted first encounter.

const Kit := preload("res://tests/fixtures/season_core/season_core.gd")
const SleepFight := preload("res://core/season/sleep_fight.gd")
const SleepText := preload("res://core/season/sleep_text.gd")
const Terms := preload("res://tests/test_09_terms.gd")
const UiUtil := preload("res://scenes/ui/ui_util.gd")
const HOUR: int = 3600
const NIGHT: int = 8 * 3600
const PM: int = 1000
## The band-typical gear per floor (the vending machine's and the boxes' common / rare pieces of the floors so far).
const GEAR: Dictionary = {
	1: {"kai": ["itm_wpn_pipe_wrench", "itm_arm_safety_vest", ""],
		"mopsula": ["itm_wpn_collar_studded", "itm_arm_velvet_cape", ""]},
	3: {"kai": ["itm_wpn_price_lance", "itm_arm_sale_vest", ""],
		"mopsula": ["itm_wpn_collar_glitter", "itm_arm_velvet_cape", ""]},
}
const BAG: Dictionary = {"itm_bandage": 3, "itm_antidote": 1, "itm_brutzel_burger": 2}
## 09 §5.3: the death rate per night Ohne Netz, in ‰ [lo, hi] by danger.
const BANDS: Array = [[0, 5], [10, 20], [30, 60]]
const NIGHTS_DEFAULT: int = 100
const NIGHTS_ENV: String = "PTD_SLEEP_NIGHTS"
const BAND_FLOOR: int = 3                  # Der Fundus: three quarters (calm, restless, dangerous), Ohne Netz deaths


# --- the kit ------------------------------------------------------------------------------------------------------

## A season on the real data with the AI cast (09 §2.3), the run on floor 1 — RunSim recording like Kit.sim.
static func _sim(d: GameData, mode: String = "net", tempo: String = "calendar", seed: int = Kit.SEED,
		cast: bool = true) -> RunSim:
	var st: GameState = GameState.create_new(d, 0, GameState.DEFAULT_NAME, seed, &"prime")
	RunRules.rt_start(st, d)
	var s: RunSim = RunSim.new(d, st, {}, {})
	var rl: RunLog = RunLog.new()
	rl.header = {"schema": 1, "seed": seed, "slot": 0, "mode": "campaign", "difficulty": "prime",
		"sim_version": RunSim.SIM_VERSION, "event_id": "", "run_id": "run_st1g_test", "player_id": "local",
		"window_id": "", "league": "", "combat_mode": "realtime", "rt_version": RunRules.RT_VERSION}
	s.run_log = rl
	var c: Dictionary = Kit.start_cmd(d, "ssn_basis", tempo, mode)
	if cast:
		c["cast"] = CastSim.start_block(d.season_def("ssn_basis"), 1)
	s.apply(c)
	s.apply({"t": "floor", "floor": 1})
	s.apply({"t": "hero", "id": "kai"})
	return s


## The party band-typical for its floor (09 §5.3): the band's middle (floor 1: 4), the floor's gear, a few potions.
static func _ready(st: GameState, d: GameData, level: int = -1) -> void:
	var f: int = st.floor_run.index
	var def: FloorDef = d.floor_def(f)
	var lv: int = level if level > 0 else (ZoneGenerator.band_middle(def) if def.has_band() else 4)
	var gear: Dictionary = GEAR.get(f, GEAR[3]) if f > 1 else GEAR[1]
	for m: PartyMember in st.party:
		m.level = lv
		var eq: Array = gear[m.id]
		m.equipment = {"weapon": eq[0], "armor": eq[1], "accessory": eq[2]}
	st.inventory.counts = BAG.duplicate()
	Progression.full_heal(st, d)


## The first cell of `danger` (0–2; SleepResolver.NO_ENCOUNTERS: a safe room, boss room or the stairs) in layout order.
static func _cell(st: GameState, d: GameData, danger: int) -> Vector2i:
	var layout: FloorLayout = SleepResolver.layout_of(st, d)
	var def: FloorDef = d.floor_def(st.floor_run.index)
	for c: Vector2i in layout.sorted_cells():
		if SleepResolver.danger_of(def, layout, c) == danger:
			return c
	return SleepResolver.NO_CELL


## The cell of a room of `kind` (RoomCell.Kind) on the current floor.
static func _kind_cell(st: GameState, d: GameData, kind: RoomCell.Kind) -> Vector2i:
	var layout: FloorLayout = SleepResolver.layout_of(st, d)
	for c: Vector2i in layout.sorted_cells():
		if layout.cell_at(c).kind == kind:
			return c
	return SleepResolver.NO_CELL


static func _sleep(s: RunSim, cell: Vector2i, tactic: String = "careful") -> Array[ExploreEvent]:
	return s.apply({"t": "sleep", "tactic": tactic, "cell": [cell.x, cell.y]})


## Logout without a cell (a safe room: the room is the night's place).
static func _sleep_here(s: RunSim) -> Array[ExploreEvent]:
	return s.apply({"t": "sleep", "tactic": "careful"})


## The draws of roll `k` of a night that starts now (SleepResolver._roll's streams).
static func _draws(st: GameState, k: int) -> Dictionary:
	var sb: int = SeedUtil.derive(st.seed, "sleep", SeasonRules.now(st))
	return {"roll": SeedUtil.derive(sb, "roll", k) % PM, "kind": SeedUtil.derive(sb, "kind", k) % PM,
		"cand": SeedUtil.derive(sb, "cand", k), "angry": SeedUtil.derive(sb, "angry", k) % PM,
		"retreat": SeedUtil.derive(sb, "retreat", k) % PM}


## Roll `k` of the night meets something at danger `danger`; a patrol (`patrol`) or an AI candidate.
static func _meets(dr: Dictionary, danger: int, patrol: bool) -> bool:
	return int(dr["roll"]) < SleepResolver.CHANCE_PM[danger] \
		and (int(dr["kind"]) < SleepResolver.PATROL_PM) == patrol


## The run seed (≥ `from`) whose night satisfies `cond` (Callable(st) -> bool, called with the seed set); -1 if none
## within `tries`.
static func _seed_where(st: GameState, cond: Callable, from: int = 1, tries: int = 4000) -> int:
	var keep: int = st.seed
	for i in range(from, from + tries):
		st.seed = i
		if bool(cond.call(st)):
			st.seed = keep
			return i
	st.seed = keep
	return -1


## The kind of the last event of the night itself (SleepResolver's; CastSim's catch-up follows "away").
static func _last_of_night(events: Array) -> String:
	var last: String = ""
	for k: Variant in Kit.kinds(events):
		if str(k) != "cast":
			last = str(k)
	return last


## The SEASON events of kind `kind` (their data).
static func _all(events: Array, kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Variant in events:
		if e is ExploreEvent and str((e as ExploreEvent).data.get("kind", "")) == kind:
			out.append((e as ExploreEvent).data)
	return out


# --- the night ----------------------------------------------------------------------------------------------------

func test_sleep_starts_the_night_where_the_figure_lies() -> void:
	var d: GameData = real_data()
	var s: RunSim = _sim(d)
	var st: GameState = s.state
	var cell: Vector2i = _cell(st, d, 1)
	assert_eq(RunRules.season_refusal(st, d, {"t": "sleep", "tactic": "careful", "cell": [99, 99]}), "bad_cell")
	assert_eq(RunRules.season_refusal(st, d, {"t": "sleep", "tactic": "careful", "cell": "a"}), "bad_cell")
	assert_eq(Kit.kinds(_sleep(s, cell, "attack"))[0], "sleep")
	var sl: SeasonState = st.season
	assert_true(sl.asleep)
	assert_eq([sl.sleep_tactic, sl.sleep_room], ["attack", ""])
	assert_eq(sl.sleeper, {"v": 1, "at": sl.utc, "cell": [cell.x, cell.y], "floor": 1, "seq": CastSim.last_seq(st),
		"quiet": 0}, "the night's block: its start, cell, floor, the cast's newest event, no Sendepause yet")
	assert_eq(SeasonState.from_dict(sl.to_dict()).sleeper, sl.sleeper, "the block round-trips")
	assert_eq(RunRules.season_refusal(st, d, {"t": "clock", "sec": 60}), "asleep", "asleep: the absence is away")
	assert_eq(RunRules.command_refusal(st, d, {}, {"t": "room", "cell": [0, 0]}, false, {}), "asleep")
	# a safe room: the room is the cell of the night, whatever the command says
	var s2: RunSim = _sim(d)
	var room: String = str(SleepResolver.layout_of(s2.state, d).safe_room_ids.values()[0])
	RunRules.enter_safe_room(s2.state, d, room)
	_sleep(s2, cell)
	assert_eq(s2.state.season.sleep_room, room)
	var rc: Vector2i = SleepResolver.layout_of(s2.state, d).safe_rooms[0]
	assert_eq(s2.state.season.sleeper["cell"], [rc.x, rc.y])
	var place: Dictionary = SleepResolver.place_of(s2.state, d)
	assert_eq([place["kind"], place["room"], place["danger"]], ["safe", room, SleepResolver.NO_ENCOUNTERS])


func test_away_is_deterministic() -> void:
	var d: GameData = real_data()
	var s: RunSim = _sim(d, "no_net")
	Kit.put_on_floor(s, BAND_FLOOR)
	_ready(s.state, d)
	_sleep(s, _cell(s.state, d, 2))
	var base: Dictionary = s.state.to_dict()
	var runs: Array = []
	for i in 2:
		var st: GameState = GameState.from_dict(base)
		var evs: Array[ExploreEvent] = RunRules.apply_season(st, d, {"t": "away", "sec": 26 * HOUR})
		var datas: Array = []
		for e: ExploreEvent in evs:
			datas.append(e.data)
		runs.append([StateHash.of(st), datas])
	assert_eq(runs[0], runs[1], "09 §11.6: the same state and duration → the same events and hash")
	assert_gt((runs[0][1] as Array).size(), 2, "the night happened (away … wake)")
	var other: GameState = GameState.from_dict(base)
	RunRules.apply_season(other, d, {"t": "away", "sec": 26 * HOUR + 1})
	assert_ne(StateHash.of(other), runs[0][0], "another duration is another night")
	s.apply({"t": "away", "sec": 26 * HOUR})                # the recorded command (RunSim): the same hash
	assert_eq(StateHash.of(s.state), runs[0][0])
	assert_eq(s.run_log.cmds().back()["c"], {"t": "away", "sec": 26 * HOUR}, "recorded")


func test_patrols_fight_in_rtsim() -> void:
	var d: GameData = real_data()
	var s: RunSim = _sim(d, "net")
	Kit.put_on_floor(s, BAND_FLOOR)
	_ready(s.state, d)
	var st: GameState = s.state
	var cell: Vector2i = _cell(st, d, 1)
	st.seed = _seed_where(st, func(x: GameState) -> bool: return _meets(_draws(x, 0), 1, true))
	assert_gt(st.seed, 0, "a night whose first roll is a patrol")
	_sleep(s, cell)
	var evs: Array[ExploreEvent] = s.apply({"t": "away", "sec": 2 * HOUR})
	var meets: Array[Dictionary] = _all(evs, "meet")
	assert_len(meets, 1, "one roll in two hours (30 min in)")
	var m: Dictionary = meets[0]
	assert_eq([m["what"], m["danger"], m["n"], int(m["t"])], ["patrol", 1, 1,
		int(st.season.utc) - 2 * HOUR + SleepResolver.FIRST_ROLL_SEC])
	var layout: FloorLayout = SleepResolver.layout_of(st, d)
	assert_has(SleepResolver.patrol_pool(st, d, layout, cell, 1), str(m["enc"]), "a group of the quarter's pool")
	assert_true(SleepResolver.is_patrol(d, str(m["enc"])), "never a boss, an elite, a rare or a tutorial group")
	assert_has(SleepFight.ENDS, str(m["outcome"]))
	if str(m["outcome"]) == "won":
		assert_gt(int((m["exp"] as Dictionary).get("kai", 0)), 0, "a victory books its EXP (without Ausgeruht)")
	assert_false(st.season.asleep, "the figure wakes up")
	assert_eq(st.season.sleeper, {}, "the night's block is gone")
	assert_eq(_last_of_night(evs), "wake", "the figure wakes last (the cast's catch-up may follow)")
	# the pool: a quarter's groups without boss, elite, rare and tutorial
	for id: String in SleepResolver.patrol_pool(st, d, layout, _cell(st, d, 2), 2):
		var enc: EncounterDef = d.encounter(id)
		assert_false(enc.boss or enc.tutorial or not enc.show_boss.is_empty(), id)
		for e: String in enc.enemies:
			for t: String in SleepResolver.ENEMY_TAGS_NEVER:
				assert_false(d.enemy(e).tags.has(t), "%s: %s" % [id, t])


func test_every_ai_profile() -> void:
	var d: GameData = real_data()
	var s: RunSim = _sim(d, "net")
	_ready(s.state, d)
	var st: GameState = s.state
	var cell: Vector2i = _cell(st, d, 2)                   # floor 1, the dangerous quarter: every AI is on floor 1
	var base: Dictionary = st.to_dict()
	var seen: Dictionary = {}
	for profile: String in ["helper", "unlucky", "rival", "trader", "extra"]:
		var cond: Callable = func(x: GameState) -> bool:
			var dr: Dictionary = _draws(x, 0)
			if not _meets(dr, 2, false):
				return false
			if profile == "helper" and not _meets(_draws(x, 1), 2, true):
				return false                               # the watch needs a patrol after it
			return _profile_at(x, d, cell, dr) == profile
		var probe: GameState = GameState.from_dict(base)
		var seed: int = _seed_where(probe, cond, 1, 600)
		assert_gt(seed, 0, "a night with an AI %s first" % profile)
		if seed < 0:
			continue
		var s2: RunSim = RunSim.new(d, GameState.from_dict(base), {}, {})
		s2.state.seed = seed
		_sleep(s2, cell)
		var items_before: Dictionary = s2.state.inventory.counts.duplicate()
		var evs: Array[ExploreEvent] = s2.apply({"t": "away", "sec": NIGHT if profile == "helper" else HOUR})
		var meets: Array[Dictionary] = _all(evs, "meet")
		var first: Dictionary = meets[0]
		assert_eq(str(first["what"]), str(SleepResolver.PROFILE_WHAT[profile]), profile)
		assert_true(str(first["label"]).ends_with("(KI)"), "09 S-6: an AI candidate is labelled: " + str(first["label"]))
		seen[profile] = first
		match profile:
			"helper":
				assert_gt(meets.size(), 1)
				assert_eq([meets[1]["what"], meets[1]["watched"], meets[1]["angry"]], ["patrol", first["label"],
					false], "the next patrol fights against both — never aufgebracht")
			"unlucky":
				var layout: FloorLayout = SleepResolver.layout_of(s2.state, d)
				assert_has(SleepResolver.patrol_pool(s2.state, d, layout, cell, 2), str(first["enc"]),
					"a patrol one danger higher (capped at dangerous)")
				assert_has(SleepFight.ENDS, str(first["outcome"]))
			"rival":
				var rep: Dictionary = SleepResolver.report(s2.state, d, evs, 0)
				assert_true("\n".join(rep["lines"]).contains("Zettel von " + str(first["label"])), "the note line")
			"trader":
				var item: String = str(first.get("item", ""))
				assert_ne(item, "", "an offer lies there")
				assert_eq(int(s2.state.inventory.counts.get(item, 0)), int(items_before.get(item, 0)) + 1)
			"extra":
				assert_eq(str(first["enc"]), "", "passes by: no fight")
	assert_eq(seen.size(), 5, "every profile of 09 §5.3")


## The profile of the AI candidate roll `dr` brings (the cast at the roll's time on the floor of `x`).
static func _profile_at(x: GameState, d: GameData, cell: Vector2i, dr: Dictionary) -> String:
	var copy: GameState = GameState.from_dict(x.to_dict())
	RunRules.apply_season(copy, d, {"t": "sleep", "tactic": "careful", "cell": [cell.x, cell.y]})
	SeasonRules.advance(copy, d, SleepResolver.FIRST_ROLL_SEC, false)
	CastSim.advance(copy, d)
	var ai: Array[Dictionary] = CastSim.floor_ai(copy, d, copy.floor_run.index)
	if ai.is_empty():
		return ""
	return str(ai[int(dr["cand"]) % ai.size()]["profile"])


func test_tactic_comes_from_sleep() -> void:
	var d: GameData = real_data()
	var s: RunSim = _sim(d)
	_ready(s.state, d)
	var st: GameState = s.state
	for tactic: String in ["careful", "support", "attack"]:
		var cmd: Dictionary = SleepFight.command(st, d, {"enc": "enc_f1_b1", "cell": _cell(st, d, 1), "tactic": tactic})
		var presets: Dictionary = (cmd["rt"] as Dictionary)["presets"]
		for uid: Variant in presets.keys():
			assert_eq(str((presets[uid] as Dictionary)["preset"]), tactic, "both figures sleep %s" % tactic)
		assert_eq(cmd["adv"], BattleSetup.Advantage.AMBUSH, "Hinterhalt: the patrol strikes first")
		assert_eq((cmd["rt"] as Dictionary)["ctl"], "p%d" % d.party_member(st.hero).battle_slot)
		assert_eq(RtCommand.validate(cmd), "", "a valid encounter command")
	assert_eq(SleepFight.RETREAT_PM, {"careful": 800, "support": 600, "attack": 600}, "09 §5.3: 80 % careful, else 60 %")
	_sleep(s, _cell(st, d, 1), "support")
	var away: Dictionary = Kit.event(s.apply({"t": "away", "sec": HOUR}), "away")
	assert_eq(away["tactic"], "support", "the night keeps the tactic of the logout")


func test_emergency_retreat() -> void:
	var d: GameData = real_data()
	var s: RunSim = _sim(d, "no_net")
	Kit.put_on_floor(s, BAND_FLOOR)
	_ready(s.state, d)
	var st: GameState = s.state
	var cell: Vector2i = _cell(st, d, 2)
	var enc: String = SleepResolver.patrol_pool(st, d, SleepResolver.layout_of(st, d), cell, 2)[0]
	var o: Dictionary = {"enc": enc, "cell": cell, "tactic": "careful", "angry": true, "watched": false, "seed": 11}
	var ok: Dictionary = SleepFight.run(st, d, o.merged({"retreat": 0}, true))
	assert_true(bool(ok["rolled"]), "an aufgebrachte Streife brings the party under 25 %")
	assert_eq(ok["end"], "retreat", "the roll succeeds: the fight ends")
	var r: BattleResult = ok["result"]
	assert_eq(r.outcome, BattleResult.Outcome.FLED, "booked as a flight: no loot")
	var hp: int = 0
	for v: Variant in r.party_hp.values():
		hp += int(v)
	assert_gt(hp, 0, "somebody stands")
	var fail: Dictionary = SleepFight.run(st, d, o.merged({"retreat": 999}, true))
	assert_true(bool(fail["rolled"]))
	assert_has(["won", "lost"], str(fail["end"]), "the roll fails: the fight runs to its end")
	assert_gt(int(fail["ticks"]), int(ok["ticks"]))
	# a normal patrol of the quarter: no retreat roll, it wins or moves on after MAX_TICKS
	var calm: Dictionary = SleepFight.run(st, d, o.merged({"angry": false, "retreat": 999}, true))
	assert_false(bool(calm["rolled"]), "a normal patrol does not bring a band-typical party under 25 %")
	assert_has(["won", "moved_on"], str(calm["end"]))
	assert_true(int(calm["ticks"]) <= SleepFight.MAX_TICKS + 1, "30 s at most")
	assert_eq(SleepFight.damage_pm({"angry": true, "watched": true}), SleepFight.WATCH_DMG_PM, "a watch: never angry")


func test_no_encounters_in_safe_rooms_boss_rooms_and_on_the_stairs() -> void:
	var d: GameData = real_data()
	var s: RunSim = _sim(d, "no_net")
	Kit.put_on_floor(s, BAND_FLOOR)
	var st: GameState = s.state
	var layout: FloorLayout = SleepResolver.layout_of(st, d)
	var def: FloorDef = d.floor_def(BAND_FLOOR)
	for kind: RoomCell.Kind in [RoomCell.Kind.SAFE, RoomCell.Kind.QUARTER_BOSS, RoomCell.Kind.FLOOR_BOSS,
			RoomCell.Kind.STAIRS]:
		var c: Vector2i = _kind_cell(st, d, kind)
		assert_ne(c, SleepResolver.NO_CELL, "floor 3 has a room of kind %d" % kind)
		assert_eq(SleepResolver.danger_of(def, layout, c), SleepResolver.NO_ENCOUNTERS, "kind %d" % kind)
	for kind: RoomCell.Kind in [RoomCell.Kind.FLOOR_BOSS, RoomCell.Kind.STAIRS]:
		var s2: RunSim = RunSim.new(d, GameState.from_dict(st.to_dict()), {}, {})
		_sleep(s2, _kind_cell(s2.state, d, kind))
		var evs: Array[ExploreEvent] = s2.apply({"t": "away", "sec": 3 * 86400})
		assert_eq(_all(evs, "meet").size(), 0, "no encounter in kind %d" % kind)
		assert_eq(_all(evs, "rested").size(), 0, "Ausgeruht only in a safe room")
	var room: String = str(layout.safe_room_ids.values()[0])
	RunRules.enter_safe_room(st, d, room)
	_sleep(s, _cell(st, d, 2))                             # the command's cell does not count in a safe room
	var evs2: Array[ExploreEvent] = s.apply({"t": "away", "sec": 3 * 86400})
	assert_eq(_all(evs2, "meet").size(), 0, "a safe room: nothing attacks")
	assert_eq(_all(evs2, "rested").size(), 1)
	assert_eq(Kit.event(evs2, "away")["place"], "safe")


func test_binge_sleeps_without_encounters() -> void:
	var d: GameData = real_data()
	var s: RunSim = _sim(d, "no_net", "binge")
	Kit.put_on_floor(s, BAND_FLOOR)
	var st: GameState = s.state
	var t0: int = SeasonRules.now(st)
	_sleep(s, _cell(st, d, 2))
	assert_eq(SleepResolver.refusal(st, d, {"t": "away", "sec": 90 * 86400}), "", "Am Stück: any length")
	var evs: Array[ExploreEvent] = s.apply({"t": "away", "sec": 90 * 86400})
	assert_eq(Kit.kinds(evs).slice(0, 2), ["away", "wake"], "09 §5.1 Nr. 4: no encounter, no Ausgeruht")
	assert_eq(SeasonRules.now(st), t0, "the clock stands")
	assert_false(st.season.asleep)


func test_rested_builds_up_in_a_safe_room() -> void:
	var d: GameData = real_data()
	var s: RunSim = _sim(d)
	var st: GameState = s.state
	_ready(st, d, 3)
	var room: String = str(SleepResolver.layout_of(st, d).safe_room_ids.values()[0])
	RunRules.enter_safe_room(st, d, room)
	var base: Dictionary = st.to_dict()
	var kai: PartyMember = st.member("kai")
	var need: int = LevelBand.exp_to_next(st, d, kai.level)
	for case: Array in [[7 * HOUR + 59 * 60, 7], [HOUR - 1, 0], [40 * HOUR, 30]]:
		var x: GameState = GameState.from_dict(base)
		RunRules.apply_season(x, d, {"t": "sleep", "tactic": "careful"})
		var evs: Array[ExploreEvent] = RunRules.apply_season(x, d, {"t": "away", "sec": int(case[0])})
		var want: int = mini(need * SleepResolver.RESTED_CAP_PM / PM, (need * SleepResolver.RESTED_HOUR_PM *
			int(case[1]) + PM / 2) / PM)
		assert_eq(x.member("kai").rested, want, "%d s: per full hour 5 %% of the level, at most 150 %%" % case[0])
		if int(case[1]) > 0:
			var r: Dictionary = Kit.event(evs, "rested")
			assert_eq(int(r["hours"]), int(case[0]) / HOUR)
			assert_eq(r["members"]["kai"], [0, want, need * SleepResolver.RESTED_CAP_PM / PM])
		else:
			assert_eq(_all(evs, "rested").size(), 0, "no full hour, no line")
	var full: GameState = GameState.from_dict(base)
	RunRules.apply_season(full, d, {"t": "sleep", "tactic": "careful"})
	RunRules.apply_season(full, d, {"t": "away", "sec": 40 * HOUR})
	assert_eq(SleepResolver.rested_pm(full, d, full.member("kai")), SleepResolver.RESTED_CAP_PM, "voll nach 30 h")


func test_sendepause_of_the_night() -> void:
	var d: GameData = real_data()
	var s: RunSim = _sim(d)
	var st: GameState = s.state
	_ready(st, d, 3)
	var room: String = str(SleepResolver.layout_of(st, d).safe_room_ids.values()[0])
	RunRules.enter_safe_room(st, d, room)
	_sleep_here(s)
	var sl: SeasonState = st.season
	var collapse0: int = sl.collapse_utc[0]
	assert_eq(Kit.kinds(s.apply({"t": "season", "v": 1, "op": "pause", "sec": 2 * 86400, "why": "user"}))[0], "pause")
	assert_eq(sl.sleeper["quiet"], 2 * 86400, "a Sendepause taken asleep belongs to the night")
	assert_eq([sl.pause_sec, sl.collapse_utc[0]], [2 * 86400, collapse0 + 2 * 86400])
	assert_eq(SleepResolver.max_away(st), SeasonClock.MAX_JUMP_SEC + 2 * 86400)
	var t0: int = sl.utc
	var evs: Array[ExploreEvent] = s.apply({"t": "away", "sec": 86400 + 10 * HOUR})
	var away: Dictionary = Kit.event(evs, "away")
	assert_eq([away["quiet"], away["refund"]], [2 * 86400, 86400 - 10 * HOUR], "back early: the rest goes back")
	assert_eq(sl.pause_sec, 86400 + 10 * HOUR, "the budget counts only the pause taken")
	assert_eq(sl.collapse_utc[0], collapse0 + 86400 + 10 * HOUR)
	assert_eq(sl.utc, t0 + 86400 + 10 * HOUR)
	assert_eq(_all(evs, "rested").size(), 0, "the clock stood: no hour of Ausgeruht")


func test_clock_jump_is_refused() -> void:
	var d: GameData = real_data()
	var s: RunSim = _sim(d)
	var st: GameState = s.state
	assert_eq(SleepResolver.refusal(st, d, {"t": "away", "sec": 60}), "awake")
	_sleep(s, _cell(st, d, 0))
	assert_eq(SleepResolver.refusal(st, d, {"t": "away", "sec": SeasonClock.MAX_JUMP_SEC}), "")
	assert_eq(SleepResolver.refusal(st, d, {"t": "away", "sec": SeasonClock.MAX_JUMP_SEC + 1}), "clock_jump",
		"V-17: over seven days the client records the rest as a pause clamp first")
	assert_eq(Kit.kinds(s.apply({"t": "season", "v": 1, "op": "pause", "sec": 9 * 86400, "why": "clamp"}))[0],
		"pause")
	assert_eq(st.season.sleeper["quiet"], 0, "a clamp is no Sendepause of the night (B-16)")
	assert_eq(st.season.pause_sec, 0)
	assert_eq(_last_of_night(s.apply({"t": "away", "sec": SeasonClock.MAX_JUMP_SEC})), "wake")


func test_collapse_while_asleep() -> void:
	var d: GameData = real_data()
	# Mit Netz in a corridor of floor 2: the rescue (with its fee), then the new floor's first safe room — rested from
	# there on, and no encounter any more
	var s: RunSim = _sim(d)
	Kit.put_on_floor(s, 2)
	var st: GameState = s.state
	_ready(st, d)
	Kit.clock_to(s, st.season.collapse_utc[0] + HOUR)      # floor 1 collapsed: floor 2 is on air
	st.inventory.credits = 1000
	_sleep(s, _cell(st, d, 0))
	var sec: int = st.season.collapse_utc[1] - st.season.utc + 30 * HOUR
	var evs: Array[ExploreEvent] = s.apply({"t": "away", "sec": sec})
	var rescue: Dictionary = Kit.event(evs, "rescue")
	assert_eq([rescue["from"], rescue["floor"], rescue["waived"]], [2, 3, ""], "Mit Netz in a corridor: the fee")
	assert_eq(st.floor_run.index, 3)
	assert_ne(str(st.floor_run.location), "start", "asleep in the first safe room of the new floor")
	for m: Dictionary in _all(evs, "meet"):
		assert_true(int(m["t"]) < int(rescue["t"]), "no encounter after the rescue")
	assert_eq(int(Kit.event(evs, "rested")["hours"]), 30, "rested from the rescue on (the full hours after it)")
	var rep: Dictionary = SleepResolver.report(st, d, evs, 0)
	assert_true(str(rep["lines"][0]).begins_with("Etage 2 ist eingestürzt"), "the rescue first: " + str(rep["lines"]))
	# a safe room: carried for free
	var s2: RunSim = _sim(d)
	Kit.put_on_floor(s2, 2)
	Kit.clock_to(s2, s2.state.season.collapse_utc[0] + HOUR)
	RunRules.enter_safe_room(s2.state, d, str(SleepResolver.layout_of(s2.state, d).safe_room_ids.values()[0]))
	_sleep_here(s2)
	var ev2: Dictionary = Kit.event(s2.apply({"t": "away", "sec": s2.state.season.collapse_utc[1] -
		s2.state.season.utc + HOUR}), "rescue")
	assert_eq(ev2["waived"], "sleeper", "09 §5.2: asleep in a safe room the Regie carries you for free")
	# Ohne Netz in a corridor: buried
	var s3: RunSim = _sim(d, "no_net")
	Kit.put_on_floor(s3, 2)
	Kit.clock_to(s3, s3.state.season.collapse_utc[0] + HOUR)
	_sleep(s3, _cell(s3.state, d, 0))
	var ev3: Array[ExploreEvent] = s3.apply({"t": "away", "sec": s3.state.season.collapse_utc[1] -
		s3.state.season.utc + HOUR})
	var out: Dictionary = Kit.event(ev3, "out")
	assert_eq([out["why"], out["floor"], out["t"]], ["buried", 2, s3.state.season.collapse_utc[1]])
	assert_eq(s3.state.season.result, "buried")
	assert_eq(_last_of_night(ev3), "wake")


func test_death_as_sleeper_by_mode() -> void:
	var d: GameData = real_data()
	for mode: String in ["no_net", "net", "rehearsal"]:
		var s: RunSim = _sim(d, "net" if mode == "net" else "no_net")
		if mode != "rehearsal":
			Kit.put_on_floor(s, BAND_FLOOR)
		var st: GameState = s.state
		_ready(st, d, 1)                                   # far too weak: an aufgebrachte Streife wins
		for m: PartyMember in st.party:
			m.equipment = {"weapon": "", "armor": "", "accessory": ""}
		st.inventory.counts = {}
		Progression.full_heal(st, d)
		st.inventory.credits = 500
		var cell: Vector2i = _cell(st, d, 2)
		st.seed = _seed_where(st, func(x: GameState) -> bool:
			var dr: Dictionary = _draws(x, 0)
			return _meets(dr, 2, true) and int(dr["angry"]) < SleepResolver.ANGRY_PM[2] and int(dr["retreat"]) >= 800)
		assert_gt(st.seed, 0, mode + ": a night with an aufgebrachte Streife and a failed retreat")
		_sleep(s, cell)
		var evs: Array[ExploreEvent] = s.apply({"t": "away", "sec": 9 * HOUR})
		assert_eq(str(_all(evs, "meet")[0]["outcome"]), "lost", mode)
		match mode:
			"no_net":
				assert_eq(Kit.event(evs, "out")["why"], "fallen", "Ohne Netz from floor 2: out")
				assert_eq(st.season.result, "fallen")
				assert_eq(_all(evs, "meet").size(), 1, "the season is over: no more rolls")
			"net":
				var death: Dictionary = Kit.event(evs, "death")
				assert_eq([death["floor"], death["waived"]], [BAND_FLOOR, ""], "Mit Netz: the medics, −10 %")
				assert_eq(death["credits"], 50)
				assert_false(st.season.vest)
			"rehearsal":
				assert_eq(Kit.event(evs, "death")["waived"], "rehearsal", "floor 1: the dress rehearsal")
				assert_eq(st.season.result, "")
		assert_false(st.season.asleep, mode + ": the figure wakes up")


# --- the texts ----------------------------------------------------------------------------------------------------

func test_login_summary() -> void:
	var d: GameData = real_data()
	var s: RunSim = _sim(d, "net")
	Kit.put_on_floor(s, 2)
	var st: GameState = s.state
	_ready(st, d)
	Kit.clock_to(s, st.season.collapse_utc[0] + HOUR)
	st.inventory.credits = 1000
	_sleep(s, _cell(st, d, 0), "support")
	var evs: Array[ExploreEvent] = s.apply({"t": "away", "sec": st.season.collapse_utc[1] - st.season.utc + 6 * HOUR})
	var rep: Dictionary = SleepResolver.report(st, d, evs, 7200)
	assert_eq(rep["title"], "WÄHREND SIE SCHLIEFEN …")
	assert_true(str(rep["sub"]).contains("Taktik „Unterstützen“"), str(rep["sub"]))
	assert_true(str(rep["sub"]).contains("Gang „Eingangshalle“, ruhig"), str(rep["sub"]))
	var lines: PackedStringArray = rep["lines"]
	assert_true(lines.size() <= SleepText.MAX_LINES, "09 §5.4: at most seven lines with the title")
	assert_eq(rep["kinds"][0], "rescue", "a collapse during the absence comes first")
	assert_true(lines[0].contains("−30 % Credits"), lines[0])
	assert_true(lines[0].contains("nächste Gebühr frühestens"), lines[0])
	assert_has(rep["kinds"], "status")
	var terms: RegEx = RegEx.create_from_string(Terms.PATTERN)
	for l: String in lines:
		assert_null(terms.search(l), "09 §1.2: " + l)
	assert_gt((rep["days"] as Array).size(), 0, "the daily summary has its days")
	for day: Dictionary in rep["days"]:
		assert_true((day["lines"] as PackedStringArray).size() <= SleepText.DAY_LINES)
	# Ohne Netz: the Sendeschluss stands first, in plain words
	var out: Dictionary = SleepResolver.report(st, d, [ExploreEvent.make(ExploreEvent.Type.SEASON, 0,
		{"kind": "away", "sec": 9 * HOUR, "place": "corridor", "danger": 2, "tactic": "careful", "zone_name": "X"}),
		ExploreEvent.make(ExploreEvent.Type.SEASON, 0, {"kind": "meet", "what": "patrol", "enc": "enc_f2_wagen",
		"outcome": "lost", "angry": true}), ExploreEvent.make(ExploreEvent.Type.SEASON, 0, {"kind": "out",
		"why": "fallen", "floor": 2})], 0)
	assert_eq(out["kinds"][0], "out")
	assert_true(str(out["lines"][0]).contains("Ohne Netz heißt das: Sendeschluss"), str(out["lines"][0]))
	assert_eq(SleepText.duration(3 * 86400 + 4 * HOUR), "3 Tage 4 Stunden")
	assert_eq(SleepText.duration(HOUR + 300), "1 Stunde 5 Minuten")
	assert_eq(SleepText.duration(59), "1 Minute")
	assert_eq(SleepText.clock_label(Kit.DAY0, 7200), "Di 22:00", "day 0 of the tests: Tue 13 Oct 2026, 20:00 UTC")
	assert_eq(SleepText.date_label(Kit.DAY0, 0), "Di 13.10.")
	assert_eq(SleepText.num(1840), "1.840")


func test_logout_dialog_words() -> void:
	var d: GameData = real_data()
	var s: RunSim = _sim(d, "no_net")
	Kit.put_on_floor(s, BAND_FLOOR)
	var st: GameState = s.state
	var info: Dictionary = SleepResolver.logout_info(st, d, _cell(st, d, 1), 0)
	assert_eq([info["kind"], info["tactics"]], ["corridor", true])
	assert_true(str(info["head"]).begins_with("Gang „"), str(info["head"]))
	assert_true(str(info["head"]).contains("(unruhig): bis zu 3 Begegnungen"), str(info["head"]))
	assert_eq(info["risk"], "Hier können Sie sterben.", "Ohne Netz from floor 2")
	assert_true("\n".join(info["lines"]).contains("Nächster Safe Room"), str(info["lines"]))
	RunRules.enter_safe_room(st, d, str(SleepResolver.layout_of(st, d).safe_room_ids.values()[0]))
	var safe: Dictionary = SleepResolver.logout_info(st, d, Vector2i.ZERO, 0)
	assert_eq([safe["kind"], safe["tactics"], safe["risk"]], ["safe", false, ""])
	assert_true(str(safe["head"]).ends_with(": sicher, Sie werden ausgeruht."), str(safe["head"]))
	var binge: RunSim = _sim(d, "no_net", "binge")
	assert_eq(SleepResolver.logout_info(binge.state, d, Vector2i.ZERO, 0)["kind"], "binge")
	var net: RunSim = _sim(d, "net")
	assert_eq(SleepResolver.logout_info(net.state, d, _cell(net.state, d, 2), 0)["risk"], "", "Mit Netz")


func test_notification_plan() -> void:
	var d: GameData = real_data()
	var s: RunSim = _sim(d, "no_net")
	var st: GameState = s.state
	var tc: int = st.season.collapse_utc[0]                # floor 1 collapses at an air time (20:00 local)
	var tz: int = 0
	assert_eq(SleepResolver.notice_plan(st, d, st.season.utc, {}, tz), [] as Array[Dictionary], "opt-in: off")
	var plan: Array[Dictionary] = SleepResolver.notice_plan(st, d, st.season.utc, {"collapse": true}, tz)
	var ats: Array = []
	for n: Dictionary in plan:
		ats.append(int(n["at"]))
		assert_eq(n["kind"], "collapse")
		assert_true(str(n["text"]).begins_with("Etage 1 stürzt "), str(n["text"]))
		var sod: int = posmod(int(n["at"]) + tz, 86400)
		assert_true(sod >= 8 * HOUR and sod <= 21 * HOUR + 59 * 60, "quiet hours 22–8: %s" % str(n))
	assert_eq(ats, [tc - 86400, tc - 3 * HOUR, tc - 1800], "Ohne Netz: 24 h, 3 h, 30 min before")
	assert_true(str(plan[0]["text"]).contains("morgen um 20:00"), str(plan[0]["text"]))
	# a warning in the quiet hours comes at 21:59 before them; at most three a day
	var at_2159: int = Kit.DAY0 + HOUR + 59 * 60          # day 0 is 20:00 UTC
	assert_eq(SleepText._before_quiet(Kit.DAY0 + 4 * HOUR, 0), at_2159, "00:00 → 21:59 the evening before")
	assert_eq(SleepText._before_quiet(Kit.DAY0 + 3 * HOUR, 0), at_2159, "23:00 → 21:59")
	assert_eq(SleepText._before_quiet(Kit.DAY0 + 23 * HOUR, 0), Kit.DAY0 + 23 * HOUR, "19:00 stays")
	assert_eq(SleepText._after_quiet(Kit.DAY0 + 3 * HOUR, 0), Kit.DAY0 + 12 * HOUR, "an opening waits for 8:00")


# --- the death rates (09 §5.3, V-10) --------------------------------------------------------------------------------

## PTD_SLEEP_NIGHTS nights per danger (default NIGHTS_DEFAULT): a band-typical party (the band's middle, the floor's
## gear, a few potions, Vorsichtig) asleep Ohne Netz in each quarter of floor 3 with the AI cast, one night of 8 h per
## seed; with 1000 nights the rates must lie in the bands of 09 §5.3, with fewer in the bands widened by two binomial
## standard errors (the smoke of the default suite, G-9).
func test_death_rates_in_the_bands() -> void:
	var nights: int = maxi(20, OS.get_environment(NIGHTS_ENV).to_int()) if OS.has_environment(NIGHTS_ENV) \
		else NIGHTS_DEFAULT
	var d: GameData = real_data()
	var s: RunSim = _sim(d, "no_net")
	Kit.put_on_floor(s, BAND_FLOOR)
	_ready(s.state, d)
	var base: Dictionary = s.state.to_dict()
	var report: PackedStringArray = []
	for danger in 3:
		var cell: Vector2i = _cell(s.state, d, danger)
		var deaths: int = 0
		var fights: int = 0
		var angry: int = 0
		var t0: int = Time.get_ticks_msec()
		for i in nights:
			var st: GameState = GameState.from_dict(base)
			st.seed = SeedUtil.derive(Kit.SEED, "night", i)
			RunRules.apply_season(st, d, {"t": "sleep", "tactic": "careful", "cell": [cell.x, cell.y]})
			for e: ExploreEvent in RunRules.apply_season(st, d, {"t": "away", "sec": NIGHT}):
				if str(e.data.get("kind", "")) == "meet" and str(e.data.get("enc", "")) != "":
					fights += 1
					angry += 1 if bool(e.data.get("angry", false)) else 0
			deaths += 1 if st.season.result == "fallen" else 0
		var band: Array = BANDS[danger]
		var lo: int = int(band[0])
		var hi: int = int(band[1])
		var tol: int = 0
		if nights < 1000:                                  # two standard errors of the band's middle, in ‰
			var mid: float = float(lo + hi) / 2000.0
			tol = int(ceil(2000.0 * sqrt(mid * (1.0 - mid) / float(nights))))
		var rate: int = deaths * PM / nights
		var line: String = "%s: %d/%d nights died (%d ‰; band %d–%d ‰ ± %d), %d fights, %d aufgebracht, %d ms" % [
			SleepResolver.DANGERS[danger], deaths, nights, rate, lo, hi, tol, fights, angry,
			Time.get_ticks_msec() - t0]
		report.append(line)
		print("SLEEP-BAND: " + line)
		assert_true(deaths * PM >= (lo - tol) * nights and deaths * PM <= (hi + tol) * nights, line)
	assert_eq(report.size(), 3)


# --- the live game: Game's facades, the login, the scenes ---------------------------------------------------------

const LOGOUT_DIALOG: String = "res://scenes/ui/logout_dialog.tscn"
const WAKE_SUMMARY: String = "res://scenes/ui/wake_summary.tscn"
const PAUSE_MENU: String = "res://scenes/ui/pause_menu.tscn"

var _read_only: bool = false


func before_each() -> void:
	_read_only = Save.read_only
	Save.read_only = true                         # (no slot, journal or career file of these tests stays behind)


func after_each() -> void:
	Save.read_only = _read_only
	Game.season_live_clock = false
	Game.season_speed = 1
	Game.season_wake = {}
	Game.season_notices.clear()
	Game.season_note_cell(SleepResolver.NO_CELL)
	if Game.combat != null:
		Game.end_combat()
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.persona = null
	Game.mode = &"campaign"
	Game.timer_running = false
	Game.in_battle = false
	tree.paused = false


## A live season (Game.start_season, slot 0: never saved) on floor 1 at Kit.START.
func _live(mode: String = "net") -> GameState:
	assert_true(Game.start_season(0, "ssn_basis", {"now": Kit.START, "tz_sec": 0, "seed": 7, "mode": mode,
		"unlock": true}))
	return Game.state


## The logout dialog (capture: "Hier schlafen" changes nothing) in the tree.
func _dialog(context: String) -> Node:
	var d: Node = (load(LOGOUT_DIALOG) as PackedScene).instantiate()
	d.call("setup", {"context": context, "capture": true})
	add_to_tree(d)
	return d


func test_logout_through_game() -> void:
	var st: GameState = _live()
	var cell: Vector2i = _cell(st, DB.data, 1)
	Game.season_note_cell(cell)
	assert_eq(Game.season_cell(), cell, "the exploration tells the room")
	assert_true(Game.season_can_logout())
	assert_eq(Game.season_pause_days_left(), 14, "09 §2.9: 14 days per season")
	assert_true(Game.season_logout("support", cell, 2 * 86400))
	var cmds: Array[Dictionary] = Game.run_log.cmds()
	var sleep_at: int = -1
	for i in cmds.size():
		if str(cmds[i]["c"]["t"]) == "sleep":
			sleep_at = i
	assert_eq(cmds[sleep_at]["c"], {"t": "sleep", "tactic": "support", "cell": [cell.x, cell.y]}, "recorded")
	assert_eq(cmds[sleep_at + 1]["c"], {"t": "season", "v": 1, "op": "pause", "sec": 2 * 86400, "why": "user"})
	assert_eq(st.season.sleeper["quiet"], 2 * 86400, "the Sendepause belongs to the night")
	assert_false(Game.season_can_logout(), "asleep")
	assert_false(Game.logout("careful"), "no second logout")
	assert_eq(Game.season_pause_days_left(), 12)


func test_login_wakes_the_sleeper() -> void:
	var st: GameState = _live()
	assert_true(Game.season_logout("careful", _cell(st, DB.data, 0)))
	Game.season_live_clock = true
	var wall: int = int(Time.get_unix_time_from_system())
	st.season.seen_unix = wall - 5 * HOUR
	Game.season_login()
	assert_false(st.season.asleep, "awake again")
	var away: Dictionary = {}
	for e: Dictionary in Game.run_log.cmds():
		if str(e["c"]["t"]) == "away":
			away = e["c"]
	assert_between(int(away.get("sec", 0)), 5 * HOUR, 5 * HOUR + 10, "away: the absence")
	assert_eq(Game.season_wake["title"], "WÄHREND SIE SCHLIEFEN …")
	assert_false(bool(Game.season_wake["auto"]))
	assert_true(str(Game.season_wake["sub"]).begins_with("5 Stunden"), str(Game.season_wake["sub"]))
	assert_true(st.season.seen_unix >= wall, "the wall clock is seen")


func test_an_absence_over_ten_minutes_is_a_logout() -> void:
	var st: GameState = _live()
	var cell: Vector2i = _cell(st, DB.data, 0)
	Game.season_note_cell(cell)
	Game.season_live_clock = true
	var wall: int = int(Time.get_unix_time_from_system())
	st.season.seen_unix = wall - 2 * HOUR
	Game.season_login()
	var kinds: Array = []
	for e: Dictionary in Game.run_log.cmds():
		kinds.append(str(e["c"]["t"]))
	assert_eq(kinds.slice(kinds.size() - 2), ["sleep", "away"], "09 §5.1 Nr. 2: closed or crashed = a logout")
	assert_true(bool(Game.season_wake["auto"]))
	assert_true(str(Game.season_wake["sub"]).contains("automatisch ausgeloggt"), str(Game.season_wake["sub"]))
	Game.season_wake = {}
	st.season.seen_unix = int(Time.get_unix_time_from_system()) - 300
	Game.season_login()
	assert_eq(str(Game.run_log.cmds().back()["c"]["t"]), "clock", "five minutes: the clock, no night")
	assert_eq(Game.season_wake, {})


func test_a_clock_jump_asks_first() -> void:
	for confirmed: bool in [true, false]:
		var st: GameState = _live()
		assert_true(Game.season_logout("careful", _cell(st, DB.data, 0)))
		Game.season_live_clock = true
		var t0: int = st.season.utc
		st.season.seen_unix = int(Time.get_unix_time_from_system()) - 20 * 86400
		Game.season_login()
		assert_true(Game.season_wake.has("question"), "V-17: over seven days the login asks")
		assert_true(st.season.asleep, "nothing booked before the answer")
		var wake: Node = (load(WAKE_SUMMARY) as PackedScene).instantiate()
		add_to_tree(wake)
		await wait_frames(2)
		assert_not_null(wake.find_child("Yes", true, false), "the question page")
		wake.call("answer", confirmed)
		await wait_frames(2)
		assert_false(st.season.asleep)
		if confirmed:
			assert_eq(st.season.utc, t0 + SeasonClock.MAX_JUMP_SEC, "seven days count")
			var lines: String = "\n".join(Game.season_wake["lines"])
			assert_true(lines.contains("Sie waren 20 Tage weg"), lines)
			assert_has(Game.season_wake["kinds"], "clamp", "the clock jump among the first lines")
		else:
			assert_eq(st.season.utc, t0 + 1, "denied: nothing counts")
		assert_not_null(wake.find_child("Continue", true, false), "then the summary")
		wake.queue_free()
		await wait_frames(1)
		after_each()
		before_each()


func test_the_scenes() -> void:
	var st: GameState = _live("no_net")
	Game.season_note_cell(_cell(st, DB.data, 1))
	var d: Node = _dialog("explore")
	await wait_frames(2)
	assert_eq(str(d.get("tactic")), "careful", "09 §5.1 Nr. 5: Vorsichtig is the default")
	assert_not_null(d.find_child("Tactic_attack", true, false), "a corridor: the tactic")
	(d.find_child("Tactic_attack", true, false) as Button).pressed.emit()
	assert_eq(str(d.get("tactic")), "attack")
	assert_eq((d.call("sleep_button") as Button).text, "Hier schlafen")
	assert_eq((d.call("back_button") as Button).text, "Zurück")
	assert_not_null(d.find_child("Notify", true, false), "the first logout asks for the notices (off)")
	assert_false((d.find_child("Notify", true, false) as CheckButton).button_pressed)
	d.call("cancel")
	await wait_frames(1)
	Game.enter_safe_room(str(SleepResolver.layout_of(st, DB.data).safe_room_ids.values()[0]))
	var safe: Node = _dialog("safe_room")
	await wait_frames(2)
	assert_null(safe.find_child("Tactic_careful", true, false), "a safe room: no tactic")
	safe.call("cancel")
	await wait_frames(1)
	# the pause menu of a season says "Ausloggen"
	var pm: Node = (load(PAUSE_MENU) as PackedScene).instantiate()
	add_to_tree(pm)
	await wait_frames(2)
	var tab: Button = (pm.get("_tab_buttons") as Dictionary)["title"]
	assert_eq((tab.find_child("Text", true, false) as Label).text, "Ausloggen")
	var opened: Node = pm.call("ask_to_title")
	assert_not_null(opened.find_child("Sleep", true, false), "the logout dialog, not the confirm")
	opened.call("cancel")
	pm.call("close")
	await wait_frames(1)
	# the summary of a real night: the title, at most six lines with icons, "Weiter"
	Game.leave_safe_room()
	assert_true(Game.season_logout("careful", _cell(st, DB.data, 2)))
	Game.season_live_clock = true
	st.season.seen_unix = int(Time.get_unix_time_from_system()) - 30 * HOUR
	Game.season_login()
	var wake: Node = (load(WAKE_SUMMARY) as PackedScene).instantiate()
	add_to_tree(wake)
	await wait_frames(2)
	var rows: Node = wake.find_child("Lines", true, false)
	assert_eq(rows.get_child_count(), (Game.season_wake["lines"] as PackedStringArray).size())
	assert_true(rows.get_child_count() <= SleepText.MAX_LINES)
	var words: PackedStringArray = [str(Game.season_wake["title"]), str(Game.season_wake["sub"])]
	words.append_array(Game.season_wake["lines"])
	var info: Dictionary = SleepResolver.logout_info(st, DB.data, _cell(st, DB.data, 1), 0)
	words.append(str(info["head"]))
	words.append_array(info["lines"])
	for w: String in words:
		assert_eq(UiUtil.missing_glyphs(w), "", "the font has every glyph (03_ART F8): " + w)
	assert_not_null(wake.find_child("Continue", true, false))
	wake.queue_free()
	await wait_frames(1)
