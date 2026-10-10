extends TestCase
## Integration round 3 — package C (Marotten, Unterhosen-Liga) × A (controlled hero) × B (talents):
## - the Liga tier refers to the CONTROLLED hero (GameState.hero) for both hero choices: tier 1 = the hero without
##   armor and accessory, tier 2 = both, the partner alone never counts; Show freezes it at battle start;
## - B's Liga talents (tal_kai_liga_routine, tal_mop_liga_gelassen) follow that tier as the single source of truth
##   (MarottenRules.in_liga → BattleBridge / Progression.total_stats / UiUtil.member_stats; integer per mille), never in
##   the tutorial or with rules.liga.enabled false;
## - B's "Kamera 3 kennt mich" (marotte_heart) fills one extra heart for the first heart of every floor, for either
##   hero, capped at the goal, counted in event runs too, with a toast;
## - a run segment in the Liga with these talents replays bit for bit (Game.replay_log from a save anchor).

const SHOW_SCENE: String = "res://scenes/ui/talent_show.tscn"
const UiUtil := preload("res://scenes/ui/ui_util.gd")
const SEED: int = 4242

var _prev_data: GameData = null
var _toasts: Array[String] = []


func before_each() -> void:
	_prev_data = DB.data
	DB.data = real_data()
	_toasts.clear()
	Events.toast_requested.connect(_on_toast)


func after_each() -> void:
	Events.toast_requested.disconnect(_on_toast)
	if Game.state != null:
		Show.end_battle(null)
	Game.auto_battle = false
	Game.in_battle = false
	Game.timer_running = false
	Game.replaying = false
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.mode = &"campaign"
	Game.clear_blocking_dialogs()
	Router.adopt(null)
	Sfx.stop_all()
	if _prev_data != null:
		DB.data = _prev_data
	_prev_data = null


func _on_toast(text: String, _icon: StringName) -> void:
	_toasts.append(text)


## A floor-1 state with `hero` in control, both members at `level`, the floor's preferences `active`.
func _state(hero: String, level: int = 5, active: PackedStringArray = PackedStringArray()) -> GameState:
	var d: GameData = real_data()
	var st: GameState = GameState.create_new(d, 0, "Kai", SEED)
	st.hero = hero
	RunRules.start_floor(st, d, 1)
	MarottenRules.on_floor(st, d, 1, {})
	st.show.marotten["active"] = Array(active)
	for m: PartyMember in st.party:
		m.level = level
	Progression.full_heal(st, d)
	return st


static func _strip(st: GameState, member_id: String) -> void:
	var m: PartyMember = st.member(member_id)
	m.equipment["armor"] = ""
	m.equipment["accessory"] = ""


static func _won() -> BattleResult:
	var r: BattleResult = BattleResult.new()
	r.outcome = BattleResult.Outcome.VICTORY
	r.encounter_id = "enc_f1_a2"
	r.party_turns = 4
	r.min_party_hp_pct = 0.8
	return r


static func _tally() -> Dictionary:
	return {"distinct_actions": 2, "defends": 0, "flee_attempts": 0, "stunts_success": 0, "last_kill_member": "kai",
		"gifts": 0, "liga_tier": 0, "tutorial": false}


## DEF / RES of the members' combatants in a fresh battle setup of `enc` (BattleBridge, the live and verifier path).
func _battle_stats(st: GameState, enc: String = "enc_f1_a2", rules: Dictionary = {}) -> Dictionary:
	var s: BattleSetup = BattleBridge.make_setup(st, real_data(), enc, BattleSetup.Advantage.NORMAL, "", 7, rules)
	var out: Dictionary = {}
	for c: Combatant in s.party:
		out[c.def_id] = [c.stat(StatBlock.Stat.DEF), c.stat(StatBlock.Stat.RES)]
	return out


# --- the Liga tier follows the controlled hero ------------------------------------------------------------------------

func test_liga_tier_with_kai_in_control() -> void:
	var st: GameState = _state("kai")
	assert_eq(MarottenRules.hero_of(st), "kai")
	assert_eq(MarottenRules.liga_tier(st), 0, "start kit")
	_strip(st, "mopsula")
	assert_eq(MarottenRules.liga_tier(st), 0, "only the partner bare: no Liga")
	assert_false(MarottenRules.in_liga(st, "mopsula", MarottenRules.liga_tier(st)))
	_strip(st, "kai")
	assert_eq(MarottenRules.liga_tier(st), 2, "both bare: Duo-Liga")
	st.member("mopsula").equipment["armor"] = "itm_arm_pug_sweater"
	assert_eq(MarottenRules.liga_tier(st), 1, "Kai bare: Unterhosen-Liga")
	assert_true(MarottenRules.liga_member(st, "kai"))
	assert_false(MarottenRules.liga_member(st, "mopsula"), "tier 1: the partner is not in the Liga")


func test_liga_tier_with_mopsula_in_control() -> void:
	var st: GameState = _state("mopsula")
	assert_eq(MarottenRules.hero_of(st), "mopsula")
	_strip(st, "kai")
	assert_eq(MarottenRules.liga_tier(st), 0, "Kai bare is not enough when the Count leads")
	_strip(st, "mopsula")
	assert_eq(MarottenRules.liga_tier(st), 2)
	st.member("kai").equipment["armor"] = "itm_arm_hoodie"
	assert_eq(MarottenRules.liga_tier(st), 1, "the Count bare: Unterhosen-Liga although Kai wears his hoodie")
	assert_true(MarottenRules.liga_member(st, "mopsula"))
	assert_false(MarottenRules.liga_member(st, "kai"))
	# the live path: Show freezes this tier at battle start and scales the battle's hype gains (×1.2 at tier 1)
	Game.new_game(0, "Kai", SEED, &"prime", "mopsula")
	_strip(Game.state, "mopsula")
	var tiers: Array[int] = []
	var cb: Callable = func(t: int) -> void: tiers.append(t)
	Events.liga_changed.connect(cb)
	var setup: BattleSetup = Game.make_battle_setup("enc_f1_a2", BattleSetup.Advantage.NORMAL, "")
	Show.begin_battle(setup)
	Events.liga_changed.disconnect(cb)
	assert_eq(tiers, [1], "Show: tier 1 with the bare Count in control")
	Show.end_battle(null)
	Game.in_battle = false


# --- B's Liga talents follow the tier ---------------------------------------------------------------------------------

## [with talents, without talents] battle stats of `st` (the talents are restored).
func _with_and_without(st: GameState, rules: Dictionary = {}, enc: String = "enc_f1_a2") -> Array:
	var with_t: Dictionary = _battle_stats(st, enc, rules)
	var saved: Dictionary = {}
	for m: PartyMember in st.party:
		saved[m.id] = m.talents
		m.talents = {}
	var without_t: Dictionary = _battle_stats(st, enc, rules)
	for m: PartyMember in st.party:
		m.talents = saved[m.id]
	return [with_t, without_t]


static func _pm(v: Variant) -> int:
	return (int(v) * 1050 + 500) / 1000


func test_liga_talents_follow_the_tier_for_both_heroes() -> void:
	for hero: String in ["kai", "mopsula"]:
		var partner: String = "mopsula" if hero == "kai" else "kai"
		var st: GameState = _state(hero)
		st.member("kai").talents = {"tal_kai_liga_routine": 1}         # DEF +5 % in the Liga
		st.member("mopsula").talents = {"tal_mop_liga_gelassen": 1}    # RES +5 % in the Liga
		var r: Array = _with_and_without(st)
		assert_eq(r[0], r[1], "%s leads, both dressed: the Liga talents rest" % hero)
		_strip(st, partner)
		assert_eq(MarottenRules.liga_tier(st), 0)
		r = _with_and_without(st)
		assert_eq(r[0], r[1], "%s leads dressed, the partner bare: tier 0 — the partner alone never counts" % hero)
		_strip(st, hero)
		st.member(partner).equipment["armor"] = "itm_arm_hoodie" if partner == "kai" else "itm_arm_pug_sweater"
		assert_eq(MarottenRules.liga_tier(st), 1)
		r = _with_and_without(st)
		var w: Dictionary = r[0]
		var wo: Dictionary = r[1]
		var hi: int = 0 if hero == "kai" else 1                      # Kai's talent → DEF, the Count's → RES
		assert_eq(int((w[hero] as Array)[hi]), _pm((wo[hero] as Array)[hi]),
			"tier 1: %s's Liga talent, per mille half up" % hero)
		assert_eq(w[partner], wo[partner], "tier 1: the partner's Liga talent rests (%s leads)" % hero)
		_strip(st, partner)
		assert_eq(MarottenRules.liga_tier(st), 2)
		r = _with_and_without(st)
		w = r[0]
		wo = r[1]
		assert_eq(int((w[hero] as Array)[hi]), _pm((wo[hero] as Array)[hi]), "Duo-Liga: the hero's talent")
		assert_eq(int((w[partner] as Array)[1 - hi]), _pm((wo[partner] as Array)[1 - hi]),
			"Duo-Liga: the partner's talent counts too (%s leads)" % hero)


func test_no_liga_talent_in_the_tutorial_or_with_the_liga_switched_off() -> void:
	var st: GameState = _state("kai")
	st.member("kai").talents = {"tal_kai_liga_routine": 1}
	_strip(st, "kai")
	var in_liga: int = int((_battle_stats(st)["kai"] as Array)[0])
	st.member("kai").talents = {}
	var plain: int = int((_battle_stats(st)["kai"] as Array)[0])
	st.member("kai").talents = {"tal_kai_liga_routine": 1}
	assert_eq(in_liga, (plain * 1050 + 500) / 1000)
	assert_eq(int((_battle_stats(st, "enc_f1_a1_tutorial")["kai"] as Array)[0]), plain,
		"the tutorial battle has no Liga (Show: tier 0) — no Liga talent")
	assert_eq(int((_battle_stats(st, "enc_f1_a2", {"liga": {"enabled": false}})["kai"] as Array)[0]), plain,
		"rules.liga.enabled false (event run): no Liga, no Liga talent")


func test_stat_lines_and_preview_follow_the_tier() -> void:
	Game.new_game(0, "Kai", SEED, &"prime", "kai")
	for m: PartyMember in Game.state.party:
		m.level = 5
	Game.state.member("kai").talents = {"tal_kai_liga_routine": 1}
	Game.state.member("mopsula").talents = {"tal_mop_liga_gelassen": 1}
	var kai: PartyMember = Game.state.member("kai")
	var mop: PartyMember = Game.state.member("mopsula")
	var def0: int = int(UiUtil.member_stats(kai)["def"])
	_strip(Game.state, "kai")
	var raw: int = Progression.total_stats(kai, DB.data).values[StatBlock.Stat.DEF]
	assert_eq(int(UiUtil.member_stats(kai)["def"]), (raw * 1050 + 500) / 1000, "stat line: in the Liga")
	assert_ne(int(UiUtil.member_stats(kai)["def"]), def0)
	Game.state.floor_run.location = &"sr_kiosk"
	var ts: Node = (load(SHOW_SCENE) as PackedScene).instantiate()
	add_to_tree(ts)
	await wait_frames(2)
	assert_eq(str(ts.call("_preview", mop, DB.talent("tal_mop_liga_gelassen"))),
		"Wirkt in der Duo-Liga: beide ohne Rüstung & ohne Accessoire.", "the partner's Liga talent names the Duo-Liga")
	_strip(Game.state, "mopsula")
	var res_now: int = int(UiUtil.member_stats(mop)["res"])
	mop.talents = {}
	var res_plain: int = int(UiUtil.member_stats(mop)["res"])
	assert_eq(res_now, (res_plain * 1050 + 500) / 1000, "Duo-Liga: the Count's stat line counts his talent")
	if is_instance_valid(ts):
		ts.call("close")


# --- "Kamera 3 kennt mich": one extra heart per floor -----------------------------------------------------------------

func test_bonus_heart_once_per_floor_for_either_hero() -> void:
	for hero: String in ["kai", "mopsula"]:
		var d: GameData = real_data()
		var st: GameState = _state(hero, 5, ["mar_mop_only", "mar_sneaky"])
		var r0: Dictionary = MarottenRules.on_battle_end(st, d, _won(), _tally(), {})
		assert_eq(st.show.marotten["hits"], {"mar_mop_only": 1}, "without the talent: one heart (%s)" % hero)
		assert_false(r0.has("bonus"))
		st = _state(hero, 5, ["mar_mop_only", "mar_sneaky"])
		st.member("kai").talents = {"tal_kai_kamera3": 1}
		assert_eq(Talents.marotte_bonus_hearts(st, d), 1)
		var r1: Dictionary = MarottenRules.on_battle_end(st, d, _won(), _tally(), {})
		assert_eq(st.show.marotten["hits"], {"mar_mop_only": 2}, "the first heart of the floor counts twice (%s)" % hero)
		assert_eq(str(r1.get("bonus", "")), "mar_mop_only")
		var won: BattleResult = _won()
		won.advantage = BattleSetup.Advantage.PREEMPTIVE
		var r2: Dictionary = MarottenRules.on_battle_end(st, d, won, _tally(), {})
		assert_eq(st.show.marotten["hits"], {"mar_mop_only": 3, "mar_sneaky": 1}, "once per floor only")
		assert_eq(r2["won"], ["mar_mop_only"], "1 + 1 bonus + 1: the bet is won after two battles")
		assert_false(r2.has("bonus"))
		# the next floor: the bonus is back
		MarottenRules.on_floor(st, d, 2, {})
		st.show.marotten["active"] = ["mar_sneaky"]
		MarottenRules.on_battle_end(st, d, won, _tally(), {})
		assert_eq(st.show.marotten["hits"], {"mar_sneaky": 2}, "a new floor, a new extra heart")


func test_bonus_heart_is_capped_and_counts_in_event_runs() -> void:
	var d: GameData = real_data()
	var st: GameState = _state("kai", 5, ["mar_mop_only"])
	st.member("kai").talents = {"tal_kai_kamera3": 1}
	st.show.marotten["hits"] = {"mar_mop_only": 2}
	st.show.marotten["bonus"] = "x"                       # spent on this floor already…
	MarottenRules.on_battle_end(st, d, _won(), _tally(), {})
	assert_eq(st.show.marotten["hits"], {"mar_mop_only": 3}, "… so this heart is a plain one")
	var ev: GameState = _state("kai", 5, ["mar_mop_only"])
	ev.member("kai").talents = {"tal_kai_kamera3": 1}
	ev.show.marotten["hits"] = {"mar_mop_only": 2}
	var r: Dictionary = MarottenRules.on_battle_end(ev, d, _won(), _tally(), {"leagues": ["pur"], "mode": "solo"})
	assert_eq(ev.show.marotten["hits"], {"mar_mop_only": 3}, "capped at the goal (2 + 1 + 1 → 3)")
	assert_eq(r["won"], ["mar_mop_only"], "event runs count the hearts (no rewards)")
	assert_eq([r["hype"], r["followers"]], [0, 0])


func test_show_toasts_the_bonus_heart() -> void:
	Game.new_game(0, "Kai", SEED, &"prime", "mopsula")
	var st: GameState = Game.state
	st.member("kai").talents = {"tal_kai_kamera3": 1}
	st.show.marotten["active"] = ["mar_mop_only"]
	var setup: BattleSetup = Game.make_battle_setup("enc_f1_a2", BattleSetup.Advantage.NORMAL, "")
	Show.begin_battle(setup)
	Game.in_battle = false
	Show.end_battle(_won())
	assert_eq(st.show.marotten["hits"], {"mar_mop_only": 2})
	assert_has(_toasts, "Talent: Extra-Herz für M.O.D.s Vorliebe!")
	assert_has(_toasts, "M.O.D. mag das: Nur der Mopp (2/3)")


# --- replay -----------------------------------------------------------------------------------------------------------

## A run segment in the Liga with Liga talents and the extra heart: Game.replay_log from the save anchor ≡ live.
func test_liga_talents_and_bonus_heart_replay_for_both_heroes() -> void:
	for hero: String in ["kai", "mopsula"]:
		Game.auto_battle = true
		Game.new_game(1, "Kai", SEED, &"prime", hero)
		var st: GameState = Game.state
		for m: PartyMember in st.party:
			m.level = 5
		st.member("kai").talents = {"tal_kai_liga_routine": 1, "tal_kai_kamera3": 1}
		st.member("mopsula").talents = {"tal_mop_liga_gelassen": 1}
		_strip(st, hero)
		st.show.marotten["active"] = ["mar_mop_only"]
		Progression.full_heal(st, DB.data)
		var sr: String = str((DB.floor_def(1).layout.get("safe_rooms", [{}]) as Array)[0].get("id", ""))
		Game.enter_safe_room(sr)
		assert_eq(Save.save_slot(1), OK, Save.last_error())
		assert_eq(Save.load_slot(1), OK, Save.last_error())
		Game.enter_safe_room(sr)
		Game.leave_safe_room()
		assert_eq(MarottenRules.liga_tier(Game.state), 1, "%s leads bare" % hero)
		_game_battle("enc_f1_a2")
		assert_eq(Game.state.show.marotten["hits"], {"mar_mop_only": 2}, "the extra heart (%s)" % hero)
		assert_eq(int(Game.state.show.stats.get("liga_battles", 0)), 1)
		var live: String = StateHash.of(Game.state)
		var rep: Dictionary = Game.replay_log(Game.run_log, Game.sim.tick())
		assert_eq(rep["errors"], PackedStringArray(), "verifies (%s)" % hero)
		assert_eq(rep["final_hash"], live, "Game.replay_log ≡ live with Liga talents + bonus heart (%s)" % hero)
		Game.auto_battle = false


## One battle like the full auto battle through the Game facade (as test_06b_talents / test_06ab_hero_talents).
func _game_battle(enc: String) -> void:
	var setup: BattleSetup = Game.make_battle_setup(enc, BattleSetup.Advantage.PREEMPTIVE, "")
	var battle: BattleState = BattleState.new(setup, DB.data)
	Show.begin_battle(setup)
	Events.battle_started.emit(setup.encounter_id, setup.is_boss)
	_play(battle, battle.start())
	var guard: int = 0
	while not battle.is_finished() and guard < 600:
		guard += 1
		var cmd: BattleCommand = battle.choose_ai_command()
		Game.record({"t": "battle", "cmd": cmd.to_dict(), "auto": true})
		_play(battle, battle.submit(cmd))
	Events.battle_ended.emit(battle.result.outcome, battle.result.encounter_id)
	Game.apply_battle_result(battle.result)
	Show.end_battle(battle.result)


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
