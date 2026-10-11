extends TestCase
## 06-C (06 §4): M.O.D.'s preferences ("Marotten", show bets) — data and validator, the seeded rotation per floor,
## every condition with a context that hits and one that misses, at most one heart per preference and battle, the
## won bet (Fanpost-Paket, followers, hype, bets_won, show_bet), tutorial / defeat / event runs, the pacifist counter
## (new rooms only, latch, safe rooms and the stopped countdown never count, save/load mid-period), the battle tally
## (MarottenTracker), the Show flow (announcement after "floor_start", hearts, toasts, lines) and replay equality of a
## live run with won bets (Game.replay_log reproduces the state hash).

const MarottenCheck := preload("res://core/data/validators/marotten.gd")
const STARTERS: PackedStringArray = ["mar_graf_finale", "mar_mop_only", "mar_sneaky", "mar_variety"]

var _prev_data: GameData = null


func before_each() -> void:
	_prev_data = DB.data
	DB.data = real_data()


func after_each() -> void:
	if Game.state != null:
		Show.end_battle(null)
	Game.in_battle = false
	Game.timer_running = false
	Game.replaying = false
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.mode = &"campaign"
	Game.clear_blocking_dialogs()
	if _prev_data != null:
		DB.data = _prev_data
	_prev_data = null


# --- helpers ----------------------------------------------------------------------------------------------------------

## A fresh run on floor 1 with `active` as the floor's preferences (unit tests set them directly).
func _state(active: PackedStringArray = PackedStringArray(), seed: int = 7) -> GameState:
	var st: GameState = GameState.create_new(real_data(), 0, "Kai", seed)
	RunRules.start_floor(st, real_data(), 1)
	MarottenRules.on_floor(st, real_data(), 1, {})
	if not active.is_empty():
		st.show.marotten["active"] = Array(active)
	return st


func _won(adv: int = BattleSetup.Advantage.NORMAL, party_turns: int = 4) -> BattleResult:
	var r: BattleResult = BattleResult.new()
	r.outcome = BattleResult.Outcome.VICTORY
	r.encounter_id = "enc_f1_a2"
	r.advantage = adv
	r.party_turns = party_turns
	r.min_party_hp_pct = 0.8
	return r


func _tally(extra: Dictionary = {}) -> Dictionary:
	var t: Dictionary = {"distinct_actions": 2, "defends": 0, "flee_attempts": 0, "stunts_success": 0,
		"last_kill_member": "kai", "gifts": 0, "liga_tier": 0, "tutorial": false}
	t.merge(extra, true)
	return t


## The first seed whose floor-1 preference is `id`.
func _seed_for(id: String) -> int:
	for seed in range(1, 400):
		var st: GameState = GameState.create_new(real_data(), 0, "Kai", seed)
		if MarottenRules.announce(st, real_data(), 1) == PackedStringArray([id]):
			return seed
	fail("no seed announces " + id)
	return 1


# --- data -------------------------------------------------------------------------------------------------------------

func test_data_and_vocabulary() -> void:
	var d: GameData = real_data()
	var all: Array[MarotteDef] = d.all_marotten()
	assert_len(all, 12, "11 rotating preferences + the Unterhosen-Liga (06 §4.4)")
	var starters: PackedStringArray = []
	var ligas: int = 0
	for def: MarotteDef in all:
		assert_true(def.name.length() <= MarottenCheck.MAX_NAME, def.id + " fits the HUD chip")
		assert_eq(MarottenCheck.foot_word(def.name + " " + def.desc), "", def.id + ": no foot words (06 §0.3)")
		assert_not_null(def.expr, def.id)
		assert_eq(def.expr.error, "", def.id + " condition parses")
		if def.kind == "liga":
			ligas += 1
			continue
		if def.starter:
			starters.append(def.id)
		assert_gt(d.mod_lines("marotte_announce:" + def.id).size(), 0, def.id + " announce line")
		assert_gt(d.mod_lines("marotte_hit:" + def.id).size(), 0, def.id + " hit line")
		assert_eq(str(def.reward.get("won_box", "")), "box_fan", def.id + ": the Fanpost-Paket")
	starters.sort()
	assert_eq(starters, STARTERS, "floor 1 starters: mop, Graf, style, sneaking (readable on the learning floor)")
	assert_eq(ligas, 1)
	assert_eq(MarottenRules.BATTLE_KEYS, MarottenCheck.BATTLE_KEYS, "rules and validator share the context keys")
	assert_eq(MarottenRules.ZONE_KEYS, MarottenCheck.ZONE_KEYS)
	for tag: String in ["marotte_won", "marotte_missed", "liga_hint", "liga_enter:1", "liga_enter:2",
			"liga_enter:1:mopsula", "liga_leave", "liga_floor", "liga_win"]:
		assert_gt(d.mod_lines(tag).size(), 0, "line for " + tag)
	for l: ModLineDef in d.mod_lines("liga_enter:1") + d.mod_lines("liga_enter:2") + d.mod_lines("liga_hint"):
		assert_eq(MarottenCheck.foot_word(l.text), "", l.id + ": no foot words")


func test_validator_rejects_bad_marotten() -> void:
	var cases: Array = [
		[{"condition": "e.no_such_key >= 1"}, "unknown key e.no_such_key"],
		[{"name": "Ein viel zu langer Name für den Chip"}, "longer than 28"],
		[{"name": "Barfuß-Bonus"}, "'barfuß' is not allowed"],
		[{"desc": "Kämpfe in Socken."}, "'socke' is not allowed"],
		[{"kind": "explore"}, "kind explore needs trigger explore_zone"],
		[{"goal": 0}, "goal: out of range 1..9"],
		[{"reward": {"hit_hype": 99}}, "hit_hype: out of range 0..50"],
		[{"reward": {"won_box": "box_nope"}}, "unknown lootbox 'box_nope'"],
		[{"reward": {"jackpot": 1}}, "unknown key"],
	]
	for c: Array in cases:
		var raw: Dictionary = _raw_tables()
		var entry: Dictionary = (raw["marotten"]["entries"] as Array)[0]
		entry.merge(c[0] as Dictionary, true)
		_expect(raw, str(c[1]))
	var raw2: Dictionary = _raw_tables()
	var liga2: Dictionary = ((raw2["marotten"]["entries"] as Array)[11] as Dictionary).duplicate(true)
	liga2["id"] = "mar_unterhose_2"
	(raw2["marotten"]["entries"] as Array).append(liga2)
	_expect(raw2, "at most one entry of kind liga")
	var raw3: Dictionary = _raw_tables()
	for l: Dictionary in raw3["mod_lines"]["entries"]:
		if str(l["tag"]) == "liga_enter:2":
			l["text"] = "Beide barfuß! Die Quote jubelt."
	_expect(raw3, "is not allowed in liga_enter lines")
	var raw4: Dictionary = _raw_tables()
	(raw4["mod_lines"]["entries"] as Array).append({"id": "mod_marotte_hit_mar_nope_01", "tag": "marotte_hit:mar_nope",
		"voice": "mod", "text": "x", "weight": 1})
	_expect(raw4, "unknown marotte 'mar_nope'")


func _raw_tables() -> Dictionary:
	var raw: Dictionary = {}
	for t: String in GameData.TABLES:
		raw[t] = JsonUtil.read_file("res://data/%s.json" % t)
	return raw


func _expect(raw: Dictionary, needle: String) -> void:
	var d: GameData = GameData.new()
	d.load_from_tables(raw)
	for e: String in d.errors:
		if e.contains(needle):
			return
	fail("expected an error containing '%s', got [%s]" % [needle, "; ".join(d.errors)])


# --- rotation ---------------------------------------------------------------------------------------------------------

func test_announce_is_seeded_and_rotates() -> void:
	var d: GameData = real_data()
	var seen: Dictionary = {}
	for seed in range(1, 41):
		var st: GameState = GameState.create_new(d, 0, "Kai", seed)
		var f1: PackedStringArray = MarottenRules.announce(st, d, 1)
		assert_len(f1, 1, "floor 1: exactly one preference")
		assert_has(STARTERS, f1[0], "floor 1 announces a starter")
		assert_eq(MarottenRules.announce(st, d, 1), f1, "same seed and floor → same preference (reload-proof)")
		seen[f1[0]] = true
		var f2: PackedStringArray = MarottenRules.announce(st, d, 2, f1)
		assert_len(f2, 2, "from floor 2 on: two preferences")
		assert_ne(f2[0], f2[1], "two different ones")
		assert_false(f2.has(f1[0]), "no repeat of the previous floor's preference")
		for id: String in f2:
			assert_true(d.marotte(id).min_floor <= 2, id + " allowed on floor 2")
	assert_gt(seen.size(), 2, "the starter varies with the seed: %s" % str(seen.keys()))


func test_on_floor_resets_and_remembers_the_previous_floor() -> void:
	var st: GameState = _state(["mar_mop_only"])
	st.show.marotten["hits"] = {"mar_mop_only": 2}
	st.show.marotten["zones"] = 2
	var res: Dictionary = MarottenRules.on_floor(st, real_data(), 2, {})
	assert_len(res["announce"], 2)
	assert_eq(st.show.marotten["prev"], ["mar_mop_only"])
	assert_eq(st.show.marotten["hits"], {})
	assert_eq(st.show.marotten["zones"], 0)
	assert_eq(st.show.marotten["liga"], {"battles": 0, "t1": 0, "t2": 0})
	assert_eq(st.show.marotten["floor"], 2)
	assert_eq(MarottenRules.on_floor(st, real_data(), 3, {"marotten": {"enabled": false}})["announce"],
		PackedStringArray(), "rules.marotten.enabled false: no preferences")


# --- conditions -------------------------------------------------------------------------------------------------------

## Every rotating preference: one context that hits, one that misses (synthetic battle / zone contexts).
func test_every_condition_hits_and_misses() -> void:
	var d: GameData = real_data()
	var base: Dictionary = MarottenRules.battle_context(_state(), d, _won(), _tally())
	var cases: Dictionary = {
		"mar_mop_only": [{"kai_weapon": "itm_wpn_mop"}, {"kai_weapon": "itm_wpn_pipe_wrench"}],
		"mar_graf_finale": [{"last_kill_member": "mopsula"}, {"last_kill_member": "kai"}],
		"mar_variety": [{"distinct_actions": 4}, {"distinct_actions": 3}],
		"mar_sneaky": [{"encounter_type": "preemptive"}, {"encounter_type": "normal"}],
		"mar_secondhand": [{"equip_all_common": true}, {"equip_all_common": false}],
		"mar_speed": [{"party_turns": 3, "is_boss": false}, {"party_turns": 4, "is_boss": false}],
		"mar_stunt": [{"stunts_success": 1}, {"stunts_success": 0}],
		"mar_bio": [{"items_used": 0, "gifts": 0}, {"items_used": 0, "gifts": 1}],
		"mar_brave": [{"defends": 0, "flee_attempts": 0}, {"defends": 1, "flee_attempts": 0}],
		"mar_gourmet": [{"weakness_hits": 3}, {"weakness_hits": 2}],
	}
	for id: String in cases:
		var hit: Dictionary = base.duplicate()
		hit.merge(cases[id][0] as Dictionary, true)
		var miss: Dictionary = base.duplicate()
		miss.merge(cases[id][1] as Dictionary, true)
		assert_true(d.marotte(id).expr.eval(hit, {}, {}), id + " hits")
		assert_false(d.marotte(id).expr.eval(miss, {}, {}), id + " misses")
	assert_false(d.marotte("mar_speed").expr.eval(_with(base, {"party_turns": 2, "is_boss": true}), {}, {}),
		"Schnellschnitt: bosses do not count")
	var pac: MarotteDef = d.marotte("mar_pacifist")
	assert_true(pac.expr.eval({"zones_since_battle": 3, "zone": "zone_a", "floor": 2}, {}, {}))
	assert_false(pac.expr.eval({"zones_since_battle": 2, "zone": "zone_a", "floor": 2}, {}, {}))
	assert_eq(cases.size() + 1, d.all_marotten().size() - 1, "all 11 rotating preferences covered")


func test_battle_context_reads_equipment_and_result() -> void:
	var st: GameState = _state()
	var ctx: Dictionary = MarottenRules.battle_context(st, real_data(), _won(BattleSetup.Advantage.PREEMPTIVE, 3),
		_tally({"last_kill_member": "mopsula", "liga_tier": 1}))
	for key: String in MarottenRules.BATTLE_KEYS:
		assert_true(ctx.has(key), "context key " + key)
	assert_eq(ctx["kai_weapon"], "itm_wpn_mop", "the start weapon")
	assert_true(ctx["equip_all_common"], "the start kit is all common")
	assert_false(ctx["hero_armor_empty"], "Kai wears the hoodie")
	assert_eq(ctx["encounter_type"], "preemptive")
	assert_eq(ctx["hero"], "kai")
	assert_eq(ctx["liga_tier"], 1)
	st.inventory.add("itm_arm_safety_vest", 1, 9)
	Progression.equip(st.member("kai"), st.inventory, real_data(), "armor", "itm_arm_safety_vest")
	assert_false(MarottenRules.battle_context(st, real_data(), _won(), _tally())["equip_all_common"],
		"a rare vest breaks Second-Hand-Schick")


# --- hearts and bets --------------------------------------------------------------------------------------------------

func test_one_heart_per_battle_three_win_the_bet() -> void:
	var st: GameState = _state(["mar_mop_only"])
	var d: GameData = real_data()
	var r1: Dictionary = MarottenRules.on_battle_end(st, d, _won(), _tally(), {})
	assert_eq(r1["hits"], ["mar_mop_only"])
	assert_eq(r1["hype"], 6, "hit hype")
	assert_eq(r1["follower_pm"], 1150, "this battle's followers ×1.15")
	assert_eq(r1["won"], [])
	assert_eq(st.show.marotten["hits"], {"mar_mop_only": 1})
	MarottenRules.on_battle_end(st, d, _won(), _tally(), {})
	var r3: Dictionary = MarottenRules.on_battle_end(st, d, _won(), _tally(), {})
	assert_eq(r3["won"], ["mar_mop_only"], "third heart wins the bet")
	assert_eq(r3["boxes"], ["box_fan"], "the Fanpost-Paket")
	assert_eq(r3["followers"], 30)
	assert_eq(r3["won_hype"], 5)
	assert_eq(int(st.show.stats.get("bets_won", 0)), 1)
	assert_len(r3["show_bet"], 1)
	var p: Dictionary = (r3["show_bet"] as Array)[0]
	assert_eq([p["kind"], p["event"], p["id"]], ["marotte", "won", "mar_mop_only"])
	for k: String in DataValidator.payload_keys("show_bet"):
		assert_true(p.has(k), "show_bet payload key " + k)
	var r4: Dictionary = MarottenRules.on_battle_end(st, d, _won(), _tally(), {})
	assert_eq(r4["hits"], [], "a won bet takes no more hearts")
	assert_eq(int(st.show.stats.get("bets_won", 0)), 1)


func test_two_preferences_in_one_battle_multiply() -> void:
	var st: GameState = _state(["mar_mop_only", "mar_sneaky"])
	var r: Dictionary = MarottenRules.on_battle_end(st, real_data(), _won(BattleSetup.Advantage.PREEMPTIVE), _tally(),
		{})
	assert_eq(r["hits"], ["mar_mop_only", "mar_sneaky"])
	assert_eq(r["hype"], 12)
	assert_eq(r["follower_pm"], 1323, "1150 × 1150 per mille, half up")


func test_tutorial_defeat_and_flight_never_count() -> void:
	var st: GameState = _state(["mar_mop_only"])
	var d: GameData = real_data()
	assert_eq(MarottenRules.on_battle_end(st, d, _won(), _tally({"tutorial": true}), {})["hits"], [], "tutorial")
	var lost: BattleResult = _won()
	lost.outcome = BattleResult.Outcome.DEFEAT
	assert_eq(MarottenRules.on_battle_end(st, d, lost, _tally(), {})["hits"], [], "defeat")
	lost.outcome = BattleResult.Outcome.FLED
	assert_eq(MarottenRules.on_battle_end(st, d, lost, _tally(), {})["hits"], [], "flight")
	assert_eq(st.show.marotten["liga"], {"battles": 0, "t1": 0, "t2": 0}, "no Liga battle counted either")


## 06 §4.8 Nr. 4 (option a): event runs show and count, but pay nothing — the score stays independent of the bets.
func test_event_runs_count_but_pay_nothing() -> void:
	var st: GameState = _state(["mar_mop_only"])
	var rules: Dictionary = {"leagues": ["pur"], "mode": "solo"}
	for i in 3:
		var r: Dictionary = MarottenRules.on_battle_end(st, real_data(), _won(), _tally({"liga_tier": 1}), rules)
		assert_eq(r["hits"], ["mar_mop_only"], "the heart still fills")
		assert_eq([r["hype"], r["follower_pm"], r["followers"], r["won_hype"]], [0, 1000, 0, 0], "no rewards")
		assert_eq(r["boxes"], [])
		assert_eq(r["show_bet"], [], "no show_bet achievements in event runs")
	assert_eq(st.show.marotten["won"], ["mar_mop_only"], "won for the record")
	assert_false(MarottenRules.rewards_on(rules))
	assert_true(MarottenRules.rewards_on({}))


# --- pacifist ---------------------------------------------------------------------------------------------------------

func test_pacifist_counts_new_rooms_latches_and_survives_a_save() -> void:
	var st: GameState = _state(["mar_pacifist"])
	var d: GameData = real_data()
	assert_eq(MarottenRules.on_zone(st, d, "zone_a", {})["hits"], [])
	assert_eq(MarottenRules.on_zone(st, d, "zone_a", {})["hits"], [])
	assert_eq(st.show.marotten["zones"], 2)
	# save / load mid-period (JSON round trip like SaveCodec)
	var raw: Variant = JSON.parse_string(JSON.stringify(st.to_dict()))
	var back: GameState = GameState.from_dict(raw as Dictionary)
	assert_eq(back.show.marotten["zones"], 2, "the counter survives the save")
	var r: Dictionary = MarottenRules.on_zone(back, d, "zone_b", {})
	assert_eq(r["hits"], ["mar_pacifist"], "third new room in a row")
	assert_eq(back.show.marotten["zones"], 0, "latch: the next heart needs three more rooms")
	MarottenRules.on_zone(back, d, "zone_b", {})
	MarottenRules.on_battle_start(back)
	assert_eq(back.show.marotten["zones"], 0, "a battle resets the counter")


## Game.visit_room → Show.on_room_visited: only first visits while the countdown runs, never safe room cells.
func test_pacifist_needs_the_countdown_and_no_safe_rooms() -> void:
	Game.new_game(0, "Kai", 5151)
	var st: GameState = Game.state
	st.show.marotten["active"] = ["mar_pacifist"]
	Show.on_room_visited(RoomCell.Kind.NORMAL, "zone_a")
	assert_eq(st.show.marotten["zones"], 0, "floor 1 before the tutorial: the countdown does not run")
	st.floor_run.timer_started = true
	Show.on_room_visited(RoomCell.Kind.SAFE, "zone_a")
	assert_eq(st.show.marotten["zones"], 0, "safe rooms never count")
	Show.on_room_visited(RoomCell.Kind.NORMAL, "zone_a")
	assert_eq(st.show.marotten["zones"], 1)


# --- tracker ----------------------------------------------------------------------------------------------------------

func test_tracker_tally_from_action_events() -> void:
	var setup: BattleSetup = BattleSetup.new()
	var kai: Combatant = Combatant.new()
	kai.id = "p0"
	kai.def_id = "kai"
	var mop: Combatant = Combatant.new()
	mop.id = "p1"
	mop.def_id = "mopsula"
	var party: Array[Combatant] = [kai, mop]
	setup.party = party
	var t: MarottenTracker = MarottenTracker.new()
	t.begin(setup, 2)
	var evs: Array[ActionEvent] = [
		_ev(ActionEvent.Type.ACTION_START, "p0", BattleCommand.Kind.ATTACK),
		_ev(ActionEvent.Type.ACTION_START, "p1", BattleCommand.Kind.SKILL, "skl_mop_flame"),
		_ev(ActionEvent.Type.ACTION_START, "p0", BattleCommand.Kind.ATTACK),
		_ev(ActionEvent.Type.ACTION_START, "p0", BattleCommand.Kind.DEFEND),
		_ev(ActionEvent.Type.ACTION_START, "e0", BattleCommand.Kind.ATTACK),
		_ev(ActionEvent.Type.FLEE_RESULT, "p1", -1),
	]
	var stunt: ActionEvent = _ev(ActionEvent.Type.STUNT_RESULT, "p0", -1)
	stunt.success = true
	evs.append(stunt)
	var ko: ActionEvent = _ev(ActionEvent.Type.KO, "p1", -1)
	ko.target_id = "e0"
	evs.append(ko)
	for e: ActionEvent in evs:
		t.on_battle_event(e)
	var tally: Dictionary = t.tally()
	assert_eq(tally["distinct_actions"], 3, "attack, skill, defend (enemy actions do not count)")
	assert_eq(tally["defends"], 1)
	assert_eq(tally["flee_attempts"], 1)
	assert_eq(tally["stunts_success"], 1)
	assert_eq(tally["last_kill_member"], "mopsula")
	assert_eq(tally["liga_tier"], 2)
	var tick: ActionEvent = _ev(ActionEvent.Type.KO, "", -1)
	tick.target_id = "e1"
	t.on_battle_event(tick)
	assert_eq(t.tally()["last_kill_member"], "", "a status tick takes the last word from everyone")


func _ev(type: ActionEvent.Type, actor: String, command: int, skill: String = "") -> ActionEvent:
	var e: ActionEvent = ActionEvent.make(type)
	e.actor_id = actor
	e.command = command
	e.skill_id = skill
	return e


static func _with(base: Dictionary, changes: Dictionary) -> Dictionary:
	var d: Dictionary = base.duplicate()
	d.merge(changes, true)
	return d


# --- Show flow --------------------------------------------------------------------------------------------------------

## The countdown starts → "floor_start", then M.O.D. announces the preference (one per explore tick, queued).
func test_announcement_follows_floor_start() -> void:
	var seed: int = _seed_for("mar_sneaky")
	var tags: Array = []
	var cb: Callable = func(_t: String, _v: StringName, tag: String, _b: bool) -> void: tags.append(tag)
	Events.mod_said.connect(cb)
	Game.new_game(0, "Kai", seed)
	assert_eq(Game.state.show.marotten["active"], ["mar_sneaky"])
	Events.explore_tick.emit({"seconds_since_battle": 1})
	assert_false(tags.has("marotte_announce:mar_sneaky"), "not before the countdown runs")
	Game.state.floor_run.timer_started = true
	Events.floor_timer_started.emit()
	for i in 4:
		Events.explore_tick.emit({"seconds_since_battle": i + 2})
	Events.mod_said.disconnect(cb)
	var a: int = tags.find("floor_start")
	var b: int = tags.find("marotte_announce:mar_sneaky")
	assert_true(a >= 0 and b > a, "floor_start, then the announcement: %s" % str(tags))
	assert_eq(tags.count("marotte_announce:mar_sneaky"), 1, "announced once")


## A live run (Show + Game, real battles): preemptive wins fill the hearts of mar_sneaky and win the bet; the
## replay of the run log reproduces the state hash (06 §4: reactions, never recorded commands).
func test_live_bets_replay_bit_for_bit() -> void:
	var seed: int = _seed_for("mar_sneaky")
	Game.auto_battle = true
	Game.new_game(0, "Kai", seed)
	var toasts: Array = []
	var cb_t: Callable = func(text: String, icon: StringName) -> void: toasts.append([String(icon), text])
	Events.toast_requested.connect(cb_t)
	var progress: Array = []
	var cb_p: Callable = func(id: String, hits: int, goal: int) -> void: progress.append([id, hits, goal])
	Events.marotte_progress.connect(cb_p)
	_fight(DB.floor_def(1).timer_start_after, BattleSetup.Advantage.PREEMPTIVE)   # tutorial: never counts
	assert_eq(Game.state.show.marotten["hits"], {}, "the tutorial battle does not count")
	var boxes_before: int = Game.state.pending_lootboxes.size()
	var won: int = 0
	for i in 3:
		won += 1 if _fight("enc_f1_a_rare", BattleSetup.Advantage.PREEMPTIVE) else 0
	Events.toast_requested.disconnect(cb_t)
	Events.marotte_progress.disconnect(cb_p)
	Game.auto_battle = false
	assert_eq(won, 3, "three preemptive wins (seed %d)" % seed)
	assert_eq(Game.state.show.marotten["won"], ["mar_sneaky"])
	assert_eq(int(Game.state.show.stats.get("bets_won", 0)), 1)
	assert_true(Game.state.pending_lootboxes.has("box_fan"), "the Fanpost-Paket")
	assert_gt(Game.state.pending_lootboxes.size(), boxes_before)
	assert_eq(progress, [["mar_sneaky", 1, 3], ["mar_sneaky", 2, 3], ["mar_sneaky", 3, 3]])
	var marotte_toasts: Array = toasts.filter(func(t: Array) -> bool: return t[0] == "marotte")
	assert_eq(marotte_toasts.size(), 3, "a toast per heart (the third one is the won bet)")
	assert_has(str(marotte_toasts[2][1]), "Wette gewonnen")
	var live_hash: String = StateHash.of(Game.state)
	var res: Dictionary = Game.replay_log(Game.run_log)
	assert_eq(res["errors"], PackedStringArray())
	assert_eq(res["mismatch_at"], -1)
	assert_eq(res["final_hash"], live_hash, "replay ≡ live with hearts, won bet and box")


## §5.7 battle loop without scenes (auto battle); true = victory.
func _fight(enc_id: String, adv: int) -> bool:
	var setup: BattleSetup = Game.make_battle_setup(enc_id, adv, "")
	if setup == null:
		return false
	var battle: BattleState = BattleState.new(setup, DB.data)
	Show.begin_battle(setup)
	Events.battle_started.emit(setup.encounter_id, setup.is_boss)
	_play(battle, battle.start())
	var guard: int = 0
	while not battle.is_finished() and guard < 400:
		guard += 1
		var cmd: BattleCommand = battle.choose_ai_command()
		Game.record({"t": "battle", "cmd": cmd.to_dict(), "auto": true})
		_play(battle, battle.submit(cmd))
	Events.battle_ended.emit(battle.result.outcome, battle.result.encounter_id)
	Game.apply_battle_result(battle.result)
	Show.end_battle(battle.result)
	Game.rest_full_heal()
	return battle.result.outcome == BattleResult.Outcome.VICTORY


## §5.7 _play without presentation (the replay engine delivers pending sponsor gifts at the same boundaries).
func _play(battle: BattleState, events: Array[ActionEvent]) -> void:
	for e: ActionEvent in events:
		Show.on_battle_event(e)
	if battle.is_finished():
		return
	var g: Dictionary = Show.take_pending_gift(battle)
	if not g.is_empty():
		var gift_events: Array[ActionEvent] = battle.apply_gift(g)
		Show.note_battle_gift(g, gift_events)
		for e: ActionEvent in gift_events:
			Show.on_battle_event(e)


## Floor end: an unmet preference → one sulk; floor 1 without any Liga battle → the Liga hint (06 §4.3).
func test_floor_end_lines() -> void:
	Game.new_game(0, "Kai", 5252)
	for a: AchievementDef in DB.data.all_achievements():
		Game.state.show.achievements.append(a.id)          # no achievement lines in the way
	var tags: Array = []
	var cb: Callable = func(_t: String, _v: StringName, tag: String, _b: bool) -> void: tags.append(tag)
	Events.mod_said.connect(cb)
	Events.floor_completed.emit(1)
	Events.mod_said.disconnect(cb)
	assert_has(tags, "marotte_missed")
	assert_has(tags, "liga_hint")
