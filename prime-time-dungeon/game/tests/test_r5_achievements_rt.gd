extends TestCase
## 07 §9.4 (R5a): the real-time achievements and their inputs — interrupts / dodges of the controlled unit as StatIds
## (raised by the ShowRules profile rt during the combat), train kills and perfect phases in the battle_won payload,
## the four new achievements in the data (tiers, conditions, M.O.D. lines) and their unlock through Show.

const RtLive := preload("res://tests/fixtures/rt_live/rt_live.gd")

var _won: Array = []
var _events: Array = []


func before_each() -> void:
	_won = []
	_events = []
	Events.battle_won.connect(_on_won)
	Events.combat_event.connect(_on_event)


func after_each() -> void:
	Events.battle_won.disconnect(_on_won)
	Events.combat_event.disconnect(_on_event)
	if Game.combat != null:
		Game.end_combat()
	Show.abort_battle()
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.in_battle = false
	RtLive.restore_data()


func _on_won(payload: Dictionary) -> void:
	_won.append(payload.duplicate(true))


func _on_event(e: RefCounted) -> void:
	_events.append(e as ActionEvent)


func test_the_new_achievements_in_the_data() -> void:
	var d: GameData = real_data()
	var want: Dictionary = {"ach_interrupt_10": ["box_bronze", "s.interrupts_total >= 10"],
		"ach_dodge_25": ["box_bronze", "s.dodges_total >= 25"], "ach_train_adds": ["box_silver", "e.train_kills >= 3"],
		"ach_perfect_phase": ["box_silver", "e.perfect_phases >= 1"]}
	for id: String in want.keys():
		assert_true(d.has_id("achievements", id), id)
		var a: AchievementDef = d.achievement(id)
		assert_eq([a.trigger, a.box, a.condition, a.hidden], ["battle_won", want[id][0], want[id][1], false], id)
		assert_gt(d.mod_lines("achievement:" + id).size(), 0, id + " has its M.O.D. line")
	assert_true(d.achievement("ach_interrupt_10").expr.eval({}, {"interrupts_total": 10}, {}))
	assert_false(d.achievement("ach_interrupt_10").expr.eval({}, {"interrupts_total": 9}, {}))
	assert_true(d.achievement("ach_dodge_25").expr.eval({}, {"dodges_total": 25}, {}))
	assert_true(d.achievement("ach_train_adds").expr.eval({"train_kills": 3}, {}, {}))
	assert_false(d.achievement("ach_train_adds").expr.eval({"train_kills": 2}, {}, {}))
	assert_true(d.achievement("ach_perfect_phase").expr.eval({"perfect_phases": 1}, {}, {}))


## Through Show with the real data: the counters the profile raises and the battle_won payload unlock them.
func test_show_unlocks_them() -> void:
	Game.new_game(0, "Kai", 77)
	Show.set_stat("interrupts_total", 10)
	Show.set_stat("dodges_total", 25)
	Show.trigger("battle_won", {"train_kills": 3, "perfect_phases": 1, "duration_sec": 40, "interrupts": 1,
		"dodges": 2, "telegraph_hits": 0})
	for id: String in ["ach_interrupt_10", "ach_dodge_25", "ach_train_adds", "ach_perfect_phase"]:
		assert_true(Show.is_unlocked(id), id)


## A live real-time fight against the test caster: the hero interrupts its marked hex with the leash (the input at the
## tick after the cast starts) — interrupts_total counts the controlled unit's own interrupts only; the battle_won
## payload carries the real-time keys of 07 §9.4.
func test_interrupts_of_the_controlled_unit_raise_the_counter() -> void:
	RtLive.swap_data()
	RtLive.adopt(RtLive.state(6, 20.0))
	var cmds: Array = [RtCommand.target(0, "p0", "e1")]
	var answered: Dictionary = {}
	var on_tick: Callable = func(c: int) -> void:
		for e: ActionEvent in _events:
			if e.type == ActionEvent.Type.CAST_START and e.actor_id.begins_with("e") and int(e.rt.get("worthy", 0)) == 1 \
					and not answered.has(e.tick):
				answered[e.tick] = true
				cmds.append(RtCommand.ability(c + 1, "p0", "skl_kai_leash_trip", e.actor_id))
	var r: Dictionary = RtLive.fight(RtKit.encounter("enc_f1_a2", [["g_c", "enc_f1_a2", [0, -150, 128]]]), cmds, 6000,
		on_tick)
	var result: BattleResult = r["result"]
	var own: int = 0
	var ai: int = 0
	for e: ActionEvent in _events:
		if e.type == ActionEvent.Type.CAST_INTERRUPTED:
			if e.actor_id == "p0" and not e.by_ai:
				own += 1
			else:
				ai += 1
	assert_gt(own, 0, "the hero cut a hex short")
	assert_eq(int(Game.state.show.stats.get("interrupts_total", 0)), own, "only the controlled unit's own (AI: %d)" % ai)
	assert_eq(result.interrupts, own, "BattleResult.interrupts: the same rule")
	assert_eq(int(result.outcome), BattleResult.Outcome.VICTORY)
	assert_eq(_won.size(), 1)
	var p: Dictionary = _won[0]
	for key: String in ["duration_sec", "interrupts", "dodges", "telegraph_hits", "train_kills", "perfect_phases"]:
		assert_true(p.has(key), "battle_won." + key)
	assert_eq([p["interrupts"], p["duration_sec"]], [own, result.duration_ticks / 30])
	assert_eq(Game.replay_log(Game.run_log)["errors"], PackedStringArray(), "and the run replays")
