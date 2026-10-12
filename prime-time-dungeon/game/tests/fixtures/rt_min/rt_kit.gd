class_name RtKit extends RefCounted
## Test kit of the real real-time sim (R1b): the rt_min fixture data, a real-time GameState on floor 1 of the fixture
## (cell (3, 6): NORMAL, doors N E S W), recorded encounter commands, setups through BattleBridge.make_rt_setup and
## stepping helpers, and the canned combat of the golden / purity tests. R2 / R3 / R4 may use it for "the real sim from
## I1 on" (07 §12.2). Pure helpers, no autoloads.

const CELL: Array = [3, 6]                  # fixture floor 1: NORMAL room with doors N, E, S, W
const SEED: int = 77

static var _data: GameData = null


## The rt_min fixture data (loaded once).
static func data() -> GameData:
	if _data == null:
		_data = FakeRtSim.load_data()
	return _data


## A real-time GameState on fixture floor 1: hero, level of both members (stats, full HP / MP — real-time HP from the
## data, baked in R5b part 2b), the start inventory plus `items`.
static func state(level: int = 1, hero: String = "kai", items: Dictionary = {}) -> GameState:
	var d: GameData = data()
	var st: GameState = GameState.create_new(d, 0, "Testperson", 4242)
	st.hero = hero
	st.floor_run = FloorRun.create(d.floor_def(1), 4242, &"prime")
	for m: PartyMember in st.party:
		m.level = level
		var sb: StatBlock = Progression.total_stats(m, d)
		m.hp = sb.values[StatBlock.Stat.HP]
		m.mp = sb.values[StatBlock.Stat.MP]
	for k: Variant in items.keys():
		st.inventory.add(str(k), int(items[k]), 9)
	return st


## The encounter command of 07 §10.1. groups: [[group id, encounter id, [x, z, yaw]], …]; party poses p0 / p1;
## opts: "adv", "ctl", "open", "auto", "retarget", "diff", "presets", "opener".
static func encounter(enc: String, groups: Array = [], opts: Dictionary = {}) -> Dictionary:
	var gs: Array = []
	for g: Variant in groups:
		var ga: Array = g
		gs.append({"group": str(ga[0]), "enc": str(ga[1]), "lead": ga[2], "state": "PATROL"})
	var rt: Dictionary = {"v": 1, "cell": CELL.duplicate(), "ctl": str(opts.get("ctl", "p0")),
		"party": opts.get("party", [{"u": "p0", "p": [0, 200, 0]}, {"u": "p1", "p": [-150, 300, 0]}]),
		"groups": gs, "presets": opts.get("presets", {}), "auto": bool(opts.get("auto", true)),
		"retarget": bool(opts.get("retarget", true)), "open": opts.get("open", {}),
		"diff": str(opts.get("diff", "prime"))}
	var cmd: Dictionary = {"t": "encounter", "enc": enc, "adv": int(opts.get("adv", 0)),
		"group": str((groups[0] as Array)[0]) if not groups.is_empty() else "", "rt": rt}
	if opts.has("opener"):
		cmd["opener"] = str(opts["opener"])
	return cmd


## One stationary dummy (enc_rt_dummy, 2000 HP) at (0, −50) facing the party — in Kai's melee reach from his pose
## (0, 200): the standard target of the mechanics tests.
static func dummy_cmd(opts: Dictionary = {}) -> Dictionary:
	return encounter("enc_rt_dummy", [["g_dummy", "enc_rt_dummy", [0, -50, 128]]], opts)


static func setup(st: GameState, cmd: Dictionary, seed: int = SEED) -> RtSetup:
	return BattleBridge.make_rt_setup(st, data(), cmd, seed)


## A started sim (prelude played) of `cmd` with a fresh state of `level` / `hero` unless `st` is given.
static func sim(cmd: Dictionary, level: int = 1, hero: String = "kai", st: GameState = null) -> RtSim:
	var s: RtSetup = setup(st if st != null else state(level, hero), cmd)
	if s == null:
		return null
	var r: RtSim = RtSim.new(s, data())
	r.start()
	return r


## sim() with every unit's rules cleared (no_ai): the mechanics tests watch one mechanic, the AI partner (and an
## autopilot) and the enemies only target, move and auto-attack (07 §5.3 Nr. 6).
static func sim_no_ai(cmd: Dictionary, level: int = 1, hero: String = "kai", st: GameState = null) -> RtSim:
	var s: RtSim = sim(cmd, level, hero, st)
	return no_ai(s) if s != null else null


## Clears the rules of every unit of `s` (no rule AI; target, movement and auto-attacks stay; a boss gets the rules of
## a later phase again when it enters it). Returns `s`.
static func no_ai(s: RtSim) -> RtSim:
	for u: RtUnit in s.units_ref():
		u.rules = []
	return s


## Steps n ticks; returns every event.
static func steps(s: RtSim, n: int) -> Array[ActionEvent]:
	var out: Array[ActionEvent] = []
	for _i in n:
		if s.is_finished():
			break
		out.append_array(s.step())
	return out


## Submits `cmd` at the current tick (ct = tick()) and steps once; returns [submit answer, events of the tick].
static func act(s: RtSim, cmd: Dictionary) -> Array:
	var c: Dictionary = cmd.duplicate(true)
	c["ct"] = s.tick()
	var answer: String = s.submit(c)
	return [answer, s.step()]


## The events of `type` in `events`.
static func of(events: Array[ActionEvent], type: ActionEvent.Type) -> Array[ActionEvent]:
	var out: Array[ActionEvent] = []
	for e: ActionEvent in events:
		if e.type == type:
			out.append(e)
	return out


## Type names of `events` (debugging).
static func names(events: Array[ActionEvent]) -> PackedStringArray:
	var out: PackedStringArray = []
	for e: ActionEvent in events:
		out.append("%d:%s" % [e.tick, ActionEvent.type_name(e.type)])
	return out


# --- the canned combat of test_r1_rt_golden / test_r1_rt_pure (07 §12.5) --------------------------------------------

## Kai level 6 with extra items.
static func canned_state() -> GameState:
	return state(6, "kai", {"itm_brutzel_burger": 2, "itm_energy_krawumm": 1, "itm_molotov": 1})


## Two groups: two rats, and a rat with the test caster (4 enemies).
static func canned_encounter() -> Dictionary:
	return encounter("enc_rt_rats", [["g1", "enc_rt_rats", [-100, -300, 128]], ["g2", "enc_f1_a2", [250, -250, 160]]])


## A started sim of the canned combat.
static func canned_sim() -> RtSim:
	return sim(canned_encounter(), 6, "kai", canned_state())


## ~200 commands by tick (a pure function of the tick, no state): honest move samples with cut-backs at every wrap of
## the path, target changes, every bar ability incl. SHOW / FINALE, items, presets, Partner-Spezial orders, the
## auto-attack and autopilot switches, a combat hint. Refused or late commands are part of the stream.
static func canned_commands() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t in range(0, 241, 3):
		out.append(RtCommand.move(t, "p0", -120 + (t * 6) % 240, 150, 60, 0, 192))
	for t in range(410, 601, 10):
		out.append(RtCommand.move(t, "p0", ((t / 10) % 7 - 3) * 40, 120 - (t / 10) % 5 * 30, 0, 0, 0))
	var targets: Array = ["e0", "e1", "e2", "e3", ""]
	for k in 30:
		out.append(RtCommand.target(k * 30, "p0", str(targets[k % 5])))
	for k in 18:
		out.append(RtCommand.ability(10 + 50 * k, "p0", "skl_kai_heavy_swing", ""))
	for k in 6:
		out.append(RtCommand.ability(25 + 150 * k, "p0", "skl_kai_leash_trip", "e%d" % (k % 4)))
	for k in 5:
		out.append(RtCommand.ability(100 + 200 * k, "p0", "skl_kai_taunt", ""))
	for k in 7:
		out.append(RtCommand.ability(60 + 120 * k, "p0", "skl_kai_sweep", ""))
	for k in 3:
		out.append(RtCommand.ability(200 + 300 * k, "p0", "skl_stunt_kai_suplex", "e1"))
	out.append(RtCommand.ability(700, "p0", "skl_kai_prime_finisher", "e2"))
	out.append(RtCommand.item(300, "p0", "itm_brutzel_burger", ""))
	out.append(RtCommand.item(330, "p0", "itm_energy_krawumm", ""))
	out.append(RtCommand.item(500, "p0", "itm_bandage", "p1"))
	out.append(RtCommand.item(800, "p0", "itm_molotov", "e2"))
	out.append(RtCommand.preset(50, "p1", "support", {"interrupt": true, "show": false, "potions": true}))
	out.append(RtCommand.preset(400, "p1", "careful", {}))
	out.append(RtCommand.preset(600, "p1", "attack", {"potions": false}))
	for t: int in [120, 125, 480, 700]:
		out.append(RtCommand.partner_special(t, "p1"))
	out.append(RtCommand.auto_attack(150, "p0", false))
	out.append(RtCommand.auto_attack(210, "p0", true))
	out.append(RtCommand.autopilot(250, "p0", true))
	out.append(RtCommand.autopilot(400, "p0", false))
	out.append(RtCommand.hint(5, "bar1"))
	var order: Array = []
	for k in out.size():
		order.append([int(out[k]["ct"]), k])
	order.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var sorted: Array[Dictionary] = []
	for p: Array in order:
		sorted.append(out[int(p[1])])
	return sorted


## Plays `cmds` (each submitted right before its tick, in list order) until tick `max_ticks`; `per_tick` (optional)
## runs after every step; once the combat is over, the rest is submitted too (answer "finished"). Returns {"events":
## Array[ActionEvent], "accepted": [cmd, …], "answers": {reason: count}}.
static func play(s: RtSim, cmds: Array, max_ticks: int, per_tick: Callable = Callable()) -> Dictionary:
	var events: Array[ActionEvent] = []
	var accepted: Array = []
	var answers: Dictionary = {}
	var i: int = 0
	while not s.is_finished() and s.tick() < max_ticks:
		while i < cmds.size() and int((cmds[i] as Dictionary)["ct"]) <= s.tick():
			var a: String = s.submit(cmds[i])
			answers[a] = int(answers.get(a, 0)) + 1
			if a == "":
				accepted.append((cmds[i] as Dictionary).duplicate(true))
			i += 1
		events.append_array(s.step())
		if per_tick.is_valid():
			per_tick.call(s)
	while s.is_finished() and i < cmds.size():
		var a2: String = s.submit(cmds[i])
		answers[a2] = int(answers.get(a2, 0)) + 1
		i += 1
	return {"events": events, "accepted": accepted, "answers": answers}


## The commands of `cmds` from tick `from_ct` on.
static func from_tick(cmds: Array, from_ct: int) -> Array:
	return cmds.filter(func(c: Dictionary) -> bool: return int(c["ct"]) >= from_ct)
