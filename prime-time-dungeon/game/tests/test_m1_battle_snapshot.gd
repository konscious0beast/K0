extends TestCase
## M1: BattleState snapshot (05 CR-14): to_dict → (JSON) → from_dict gives the same to_dict (hash-stable, float-free,
## canonical-JSON compatible) and the restored battle continues exactly like the original (resync/reconnect).

const Fx := preload("res://tests/test_m1_fixture.gd")

var data: GameData


func before_each() -> void:
	data = fixture_data(Fx.tables())


func _opts(seed: int) -> Dictionary:
	return {"seed": seed, "is_boss": true, "items": {"itm_bandage": 2, "itm_smelling_salts": 1},
		"kai": {"skills": PackedStringArray(["skl_kai_heavy_swing", "skl_kai_taunt", "skl_kai_first_aid"]),
			"stats": {"hp": 150, "str": 30, "def": 22, "spd": 15, "mp": 30}, "crit_bonus": 0.05,
			"element_mods": {"poison": 0.5}},
		"mop": {"skills": PackedStringArray(["skl_mop_noble_flame", "skl_mop_holy_lick", "skl_mop_frost_sneeze",
			"skl_mop_royal_decree", "skl_mop_revive"]), "stats": {"hp": 100, "mag": 32, "res": 25, "spd": 19, "mp": 70}},
		"enemy_dmg_mult": 0.75, "exp_mult": 1.2, "credits": 77}


static func _json(d: Dictionary) -> Dictionary:
	var v: Variant = JSON.parse_string(JSON.stringify(d))
	return v if v is Dictionary else {}


static func _canonical_safe(v: Variant) -> bool:
	match typeof(v):
		TYPE_FLOAT:
			return fmod(float(v), 1.0) == 0.0 and absf(float(v)) < 9007199254740992.0
		TYPE_INT:
			return absi(int(v)) < 9007199254740992
		TYPE_DICTIONARY:
			for k: Variant in (v as Dictionary).keys():
				if typeof(k) != TYPE_STRING or not _canonical_safe((v as Dictionary)[k]):
					return false
		TYPE_ARRAY:
			for e: Variant in (v as Array):
				if not _canonical_safe(e):
					return false
		TYPE_STRING, TYPE_BOOL, TYPE_NIL:
			return true
		_:
			return false
	return true


## Advances the queen battle into phase 2 (train) with statuses, summons and items in play.
func _midgame(seed: int, steps: int) -> BattleState:
	var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_boss_queen"]), _opts(seed))
	s.start()
	var queen: Combatant = s.get_combatant("e0")
	var out: Array[ActionEvent] = []
	var dmg: ActionEvent = ActionEvent.make(ActionEvent.Type.DAMAGE)
	dmg.target_id = "e0"
	ActionResolver.deal_damage(s, queen, 300, dmg, out)     # phase 2: train joins
	s.apply_gift({"kind": "sponsor_buff", "sponsor_id": "spn_krawumm"})
	for i in steps:
		if s.is_finished():
			break
		Fx.auto_step(s)
	return s


func test_snapshot_roundtrip_is_stable_and_canonical() -> void:
	for steps: int in [0, 3, 9]:
		var s: BattleState = _midgame(5, steps)
		var d: Dictionary = s.to_dict()
		assert_true(_canonical_safe(d), "snapshot: only ints (< 2^53), strings, bools, arrays, string-keyed objects")
		assert_eq(int(d["version"]), 1)
		assert_true(d.has("rng_state") and d.has("action_n") and d.has("items") and d.has("queue"))
		var restored: BattleState = BattleState.from_dict(_json(d), data)
		assert_eq(restored.to_dict(), d, "from_dict(to_dict()).to_dict() == to_dict() (steps %d)" % steps)
		assert_eq(BattleState.from_dict(d, data).to_dict(), d, "also without JSON")
		assert_eq(restored.rng.state, s.rng.state)
		assert_eq(restored.current_actor().id if restored.current_actor() != null else "",
				s.current_actor().id if s.current_actor() != null else "")


func test_restored_battle_continues_identically() -> void:
	var compared: int = 0
	for seed: int in [1, 2, 3]:
		var s: BattleState = _midgame(seed, 4)
		if s.is_finished():
			continue
		compared += 1
		var snap: Dictionary = _json(s.to_dict())
		var cmds: Array[BattleCommand] = []
		var live: Array[ActionEvent] = []
		var gift_done: bool = false
		while not s.is_finished() and cmds.size() < 300:
			var c: BattleCommand = s.choose_ai_command()
			cmds.append(c)
			live.append_array(s.submit(c))
			if not gift_done and not s.is_finished():
				live.append_array(s.apply_gift({"kind": "sponsor_buff", "sponsor_id": "spn_gluck"}))
				gift_done = true
		var r: BattleState = BattleState.from_dict(snap, data)
		var replay: Array[ActionEvent] = []
		var gift_again: bool = false
		for c: BattleCommand in cmds:
			replay.append_array(r.submit(BattleCommand.from_dict(c.to_dict())))
			if not gift_again and not r.is_finished():
				replay.append_array(r.apply_gift({"kind": "sponsor_buff", "sponsor_id": "spn_gluck"}))
				gift_again = true
		assert_eq(Fx.dicts(replay), Fx.dicts(live), "seed %d: identical events after restore" % seed)
		assert_true(r.is_finished())
		assert_eq(r.to_dict(), s.to_dict(), "seed %d: identical final snapshot" % seed)
		assert_eq(r.result.to_dict(), s.result.to_dict())
		assert_gt(cmds.size(), 0)
	assert_gt(compared, 0, "at least one mid-game snapshot was continued")


func test_snapshot_before_start_and_after_finish() -> void:
	var fresh: BattleState = Fx.make_state(data, PackedStringArray(["enm_rat", "enm_pigeon"]), _opts(9))
	var snap: Dictionary = _json(fresh.to_dict())
	assert_eq(int(snap["phase"]), BattleState.Phase.SETUP)
	var a: Array[ActionEvent] = fresh.start()
	var b: Array[ActionEvent] = BattleState.from_dict(snap, data).start()
	assert_eq(Fx.dicts(b), Fx.dicts(a), "a restored SETUP snapshot starts identically")
	var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_rat"]), {"seed": 4, "kai": {"stats": {"str": 60}}})
	Fx.run_auto(s)
	assert_true(s.is_finished())
	var done: Dictionary = s.to_dict()
	assert_true(_canonical_safe(done), "finished snapshot incl. result is canonical-JSON safe")
	var back: BattleState = BattleState.from_dict(_json(done), data)
	assert_true(back.is_finished())
	assert_eq(back.result.to_dict(), s.result.to_dict(), "result restored (min_party_hp_pct via ppm)")
	assert_eq(back.to_dict(), done)
	assert_null(back.current_actor())
