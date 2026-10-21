extends TestCase
## M1: complete battles (victory/defeat/flight), event order invariants (02_TECH §5.3), results, combo, overkill,
## items, gifts (05 CR-2), determinism (same seed + same commands → identical to_dict lists, replay of recorded
## commands), 100 seeds auto-vs-auto < 200 turns, ActionEvent/BattleCommand to_dict ↔ from_dict.

const Fx := preload("res://tests/test_m1_fixture.gd")

const ENCOUNTERS: Array = [["enm_rat", "enm_rat"], ["enm_rat", "enm_pigeon", "enm_rat"], ["enm_slime", "enm_shaman"],
	["enm_mimic"], ["enm_pigeon", "enm_pigeon", "enm_shaman", "enm_rat"], ["enm_boss_janitor"], ["enm_boss_queen"]]

var data: GameData


func before_each() -> void:
	data = fixture_data(Fx.tables())


func _opts(seed: int, enemies: Array) -> Dictionary:
	var boss: bool = enemies.has("enm_boss_janitor") or enemies.has("enm_boss_queen")
	return {"seed": seed, "is_boss": boss, "items": {"itm_bandage": 2, "itm_ice_spray": 1, "itm_smelling_salts": 1},
		"kai": {"skills": PackedStringArray(["skl_kai_heavy_swing", "skl_kai_sweep", "skl_kai_first_aid", "skl_kai_double"]),
			"stats": {"hp": 140, "str": 26, "def": 20, "spd": 15, "mp": 30} if boss else {}},
		"mop": {"skills": PackedStringArray(["skl_mop_noble_flame", "skl_mop_holy_lick", "skl_mop_revive",
			"skl_mop_frost_sneeze"]),
			"stats": {"hp": 100, "mag": 30, "def": 14, "res": 22, "spd": 18, "mp": 70} if boss else {}}}


## Checks the ordering guarantees of 02_TECH §5.3 on a complete event list; returns the number of violations.
func _check_invariants(events: Array[ActionEvent], s: BattleState, label: String) -> void:
	assert_eq(events[0].type, ActionEvent.Type.BATTLE_START, label + ": first event")
	assert_eq(events[-1].type, ActionEvent.Type.BATTLE_END, label + ": BATTLE_END last")
	assert_eq(Fx.of_type(events, ActionEvent.Type.BATTLE_END).size(), 1, label + ": one BATTLE_END")
	var open: String = ""
	var acted: bool = false
	var last_dmg_beat: int = -1
	var hp_seen: Dictionary = {}
	for i in events.size():
		var e: ActionEvent = events[i]
		var prev: ActionEvent = events[i - 1] if i > 0 else null
		if e.target_id != "":
			assert_ne(e.def_id, "", "%s: def_id on %s (#%d)" % [label, ActionEvent.type_name(e.type), i])
		match e.type:
			ActionEvent.Type.TURN_START:
				assert_eq(open, "", "%s: TURN_START inside another turn (#%d)" % [label, i])
				open = e.actor_id
				acted = false
				var j: int = i - 1
				while j > 0 and events[j].type == ActionEvent.Type.MOD_LINE:
					j -= 1
				assert_eq(events[j].type, ActionEvent.Type.CTB_ORDER, "%s: CTB_ORDER before TURN_START (#%d)" % [label, i])
			ActionEvent.Type.TURN_END:
				assert_eq(e.actor_id, open, "%s: TURN_END matches TURN_START (#%d)" % [label, i])
				open = ""
			ActionEvent.Type.ACTION_START:
				assert_eq(e.actor_id, open, "%s: ACTION_START by the turn's actor (#%d)" % [label, i])
				assert_false(acted, "%s: one ACTION_START per turn (#%d)" % [label, i])
				acted = true
				last_dmg_beat = -1
				if not e.actor_id.begins_with("u"):
					assert_ne(e.command, -1, label + ": ACTION_START.command")
			ActionEvent.Type.COMBO:
				assert_eq(prev.type, ActionEvent.Type.ACTION_START, "%s: COMBO right after ACTION_START (#%d)" % [label, i])
			ActionEvent.Type.STUNT_RESULT:
				assert_true(prev.type == ActionEvent.Type.ACTION_START or prev.type == ActionEvent.Type.COMBO,
						"%s: STUNT_RESULT after ACTION_START/COMBO (#%d)" % [label, i])
			ActionEvent.Type.KO:
				assert_eq(prev.type, ActionEvent.Type.DAMAGE, "%s: KO directly after the lethal DAMAGE (#%d)" % [label, i])
				assert_eq(prev.target_id, e.target_id)
				assert_eq(prev.hp_after, 0)
				assert_eq(e.item_id != "", e.command == BattleCommand.Kind.ITEM,
						"%s: KO.item_id iff item kill (#%d)" % [label, i])
				if e.target_id == open and not acted:
					open = ""                     # died at TURN_START (poison): no TURN_END
			ActionEvent.Type.DAMAGE:
				if e.status_id == "" and acted and open != "":
					assert_true(e.beat >= last_dmg_beat, "%s: ascending beats (#%d)" % [label, i])
					last_dmg_beat = e.beat
				assert_true(e.amount > 0 or e.immune, "%s: DAMAGE 0 only if immune (#%d)" % [label, i])
			ActionEvent.Type.HEAL:
				assert_gt(e.amount, 0, label + ": HEAL amount > 0")
			ActionEvent.Type.CTB_ORDER:
				assert_eq(e.order.size(), CTBQueue.PREVIEW_LENGTH, label + ": CTB_ORDER has 12 entries")
		if e.type == ActionEvent.Type.DAMAGE or e.type == ActionEvent.Type.HEAL or e.type == ActionEvent.Type.REVIVE:
			hp_seen[e.target_id] = e.hp_after
	assert_eq(open, "", label + ": no open turn at the end")
	for id: String in hp_seen.keys():
		assert_eq(hp_seen[id], maxi(0, s.get_combatant(id).hp), "%s: last hp_after == final hp (%s)" % [label, id])


func test_full_battles_keep_event_invariants() -> void:
	var outcomes: Dictionary = {}
	for k in ENCOUNTERS.size():
		for seed in range(1, 6):
			var enemies: Array = ENCOUNTERS[k]
			var s: BattleState = Fx.make_state(data, PackedStringArray(enemies), _opts(seed * 31 + k, enemies))
			var ev: Array[ActionEvent] = Fx.run_auto(s, 400)
			assert_true(s.is_finished(), "enc %d seed %d finished" % [k, seed])
			if not s.is_finished():
				continue
			_check_invariants(ev, s, "enc %d seed %d" % [k, seed])
			assert_eq(Fx.dicts(ev), Fx.dicts(s.history), "history == all returned events")
			assert_eq(s.result.turns, Fx.of_type(ev, ActionEvent.Type.TURN_START).size(), "turns = TURN_STARTs")
			var pt: int = 0
			for e: ActionEvent in Fx.of_type(ev, ActionEvent.Type.TURN_START):
				pt += 1 if e.actor_id.begins_with("p") else 0
			assert_eq(s.result.party_turns, pt)
			assert_eq(ev[-1].value, int(s.result.outcome))
			outcomes[s.result.outcome] = true
	assert_true(outcomes.has(BattleResult.Outcome.VICTORY), "some battles are won")


func test_victory_result_fields() -> void:
	var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_rat", "enm_rat"]), {"seed": 11, "exp_mult": 1.2,
		"kai": {"stats": {"str": 40, "lck": 300}}, "mop": {"stats": {"lck": 300}}})
	var ev: Array[ActionEvent] = Fx.run_auto(s)
	var r: BattleResult = s.result
	assert_eq(r.outcome, BattleResult.Outcome.VICTORY)
	assert_eq(r.kills, 2)
	assert_eq(r.defeated_ids, PackedStringArray(["enm_rat", "enm_rat"]))
	assert_eq(r.exp, 28, "24 × 1.2 = 28.8 → floor 28 (GDD: abgerundet)")
	var base_credits: int = 12
	assert_eq(r.credits, base_credits + r.overkill_credits)
	var overkills: int = 0
	for e: ActionEvent in Fx.of_type(ev, ActionEvent.Type.KO):
		overkills += e.value
	assert_eq(r.overkill_credits, overkills * 2, "6 × 1.25 = 7.5 → 8: +2 per overkill")
	# Ø LCK 300 → drop chance × 4: bandage 0.25 → 1.0 (always), antidote 0.1 → 0.4.
	var bandages: int = 0
	for d: String in r.drops:
		bandages += 1 if d == "itm_bandage" else 0
	assert_eq(bandages, 2, "drop chance × (1 + Ø LCK / 100)")
	assert_eq(r.party_hp.keys().size(), 2)
	assert_eq(int(r.party_hp["kai"]), s.get_combatant("p0").hp)
	var taken: int = 0
	for e: ActionEvent in Fx.of_type(ev, ActionEvent.Type.DAMAGE):
		if e.target_id.begins_with("p"):
			taken += e.amount
	assert_eq(r.damage_taken, taken)
	var low: int = mini(s.get_combatant("p0").hp, s.get_combatant("p1").hp)
	assert_eq(r.min_party_hp, low)
	assert_eq(r.encounter_id, "enc_test")
	assert_eq(r.group_id, "f1_g1")
	assert_eq(r.boss_id, "")
	assert_false(r.is_boss)


func test_overkill_flag_and_bonus() -> void:
	var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_rat", "enm_dummy"]), {"kai": {"stats": {"str": 300}}})
	s.start()
	_until(s, s.get_combatant("p0"))
	var ev: Array[ActionEvent] = s.submit(BattleCommand.attack("p0", "e0"))
	var ko: ActionEvent = Fx.of_type(ev, ActionEvent.Type.KO)[0]
	assert_eq(ko.value, 1, "damage >= hp_before + max_hp × 0.5")
	assert_eq(ko.actor_id, "p0")
	assert_eq(ko.skill_id, "skl_attack_kai")
	assert_eq(ko.command, BattleCommand.Kind.ATTACK)
	assert_eq(ko.max_hp, 24)
	assert_eq(ko.def_id, "enm_rat")
	s.get_combatant("e1").hp = 1
	_until(s, s.get_combatant("p0"))
	s.submit(BattleCommand.attack("p0", "e1"))
	assert_true(s.is_finished())
	assert_eq(s.result.overkill_credits, 2 + 0, "rat: 8 − 6; dummy: roundi(1 × 1.25) − 1 = 0")
	assert_eq(s.result.credits, 9)


func test_defeat() -> void:
	var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_boss_janitor"]), {"is_boss": true,
		"kai": {"hp": 1}, "mop": {"hp": 1}, "seed": 3})
	var ev: Array[ActionEvent] = Fx.run_auto(s)
	assert_true(s.is_finished())
	assert_eq(s.result.outcome, BattleResult.Outcome.DEFEAT)
	assert_eq(s.result.exp, 0)
	assert_eq(s.result.party_kos, 2)
	assert_eq(int(s.result.party_hp["kai"]), 0)
	assert_eq(s.result.min_party_hp, 0)
	assert_eq(s.result.boss_id, "enm_boss_janitor")
	assert_true(s.result.is_boss)
	assert_len(s.result.boss_rewards, 0, "no boss rewards without victory")
	_check_invariants(ev, s, "defeat")


func test_flee_success_failure_and_locks() -> void:
	var fled: bool = false
	var failed: bool = false
	for seed in range(1, 60):
		var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_rat"]), {"seed": seed})
		s.start()
		_until(s, s.get_combatant("p0"))
		var ev: Array[ActionEvent] = s.submit(BattleCommand.flee("p0"))
		var fr: ActionEvent = Fx.of_type(ev, ActionEvent.Type.FLEE_RESULT)[0]
		if fr.success:
			fled = true
			assert_true(s.is_finished())
			assert_eq(s.result.outcome, BattleResult.Outcome.FLED)
			assert_eq(ev[-1].value, BattleResult.Outcome.FLED)
			assert_eq(Fx.types(ev).slice(-2), PackedStringArray(["TURN_END", "BATTLE_END"]))
			assert_eq(s.result.exp, 0)
			assert_len(s.result.drops, 0)
		else:
			failed = true
			assert_false(s.is_finished())
			assert_eq(s.failed_flee_attempts, 1)
	assert_true(fled and failed, "both outcomes occur (chance 0.385)")
	var boss: BattleState = Fx.make_state(data, PackedStringArray(["enm_boss_janitor"]), {"is_boss": true,
		"items": {"itm_smoke": 1}})
	boss.start()
	_until(boss, boss.get_combatant("p0"))
	assert_false(boss.available_commands(boss.current_actor()).has(BattleCommand.Kind.FLEE), "no flight from bosses")
	assert_ne(boss.validate(BattleCommand.flee("p0")), "")
	assert_false(boss.usable_items().has("itm_smoke"), "smoke bomb not usable when fleeing is impossible")
	var tut: BattleState = Fx.make_state(data, PackedStringArray(["enm_rat"]), {"tutorial": true})
	tut.start()
	_until(tut, tut.get_combatant("p0"))
	assert_ne(tut.validate(BattleCommand.flee("p0")), "", "tutorial locks flight")
	var smoke: BattleState = Fx.make_state(data, PackedStringArray(["enm_rat"]), {"items": {"itm_smoke": 1}})
	smoke.start()
	_until(smoke, smoke.get_combatant("p0"))
	var sev: Array[ActionEvent] = smoke.submit(BattleCommand.item("p0", "itm_smoke", PackedStringArray()))
	assert_true(Fx.of_type(sev, ActionEvent.Type.FLEE_RESULT)[0].success, "flee_guaranteed")
	assert_eq(smoke.result.outcome, BattleResult.Outcome.FLED)
	assert_eq(int(smoke.result.item_delta["itm_smoke"]), -1)


func test_tutorial_party_never_below_one_hp() -> void:
	for seed in range(1, 6):
		var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_boss_janitor"]), {"seed": seed, "tutorial": true,
			"enemy_dmg_mult": 0.5, "kai": {"hp": 3}, "mop": {"hp": 2}})
		s.start()
		var n: int = 0
		while not s.is_finished() and n < 60:
			n += 1
			if s.current_actor().is_party():
				s.submit(BattleCommand.defend(s.current_actor().id))
			else:
				s.submit(s.choose_ai_command())
		assert_false(s.is_finished(), "no defeat possible in the tutorial (seed %d)" % seed)
		for e: ActionEvent in s.history:
			if e.type == ActionEvent.Type.KO:
				assert_false(e.target_id.begins_with("p"), "party never KO")
			if e.type == ActionEvent.Type.DAMAGE and e.target_id.begins_with("p"):
				assert_gt(e.hp_after, 0)


func test_combo_second_hit() -> void:
	var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_dummy", "enm_rat"]), {"seed": 8})
	s.start()
	var kai: Combatant = s.get_combatant("p0")
	var mop: Combatant = s.get_combatant("p1")
	_until(s, kai)
	Fx.force_next(s, mop)
	var ev1: Array[ActionEvent] = s.submit(BattleCommand.attack("p0", "e0"))
	assert_len(Fx.of_type(ev1, ActionEvent.Type.COMBO), 0)
	assert_eq(s.current_actor(), mop)
	var snap: Dictionary = s.to_dict()
	var clone: BattleState = BattleState.from_dict(snap, data)
	var expected: HitResult = DamageCalc.compute(clone.get_combatant("p1"), clone.get_combatant("e0"),
			data.skill("skl_attack_mopsula"), "physical", clone.rng, true)
	var ev2: Array[ActionEvent] = s.submit(BattleCommand.attack("p1", "e0"))
	var t: PackedStringArray = Fx.types(ev2)
	assert_eq(t[t.find("ACTION_START") + 1], "COMBO", "other member, same target, no enemy turn between")
	var combo: ActionEvent = Fx.of_type(ev2, ActionEvent.Type.COMBO)[0]
	assert_eq(combo.actor_id, "p1")
	assert_eq(combo.target_id, "e0")
	assert_eq(combo.def_id, "enm_dummy")
	assert_eq(Fx.of_type(ev2, ActionEvent.Type.DAMAGE)[0].amount, expected.amount, "damage × 1.1")
	# Same member twice → no combo; enemy turn in between → no combo; other target → no combo.
	_until(s, kai)
	_hold(s, kai)
	s.submit(BattleCommand.attack("p0", "e0"))
	assert_eq(s.current_actor(), kai)
	assert_len(Fx.of_type(s.submit(BattleCommand.attack("p0", "e0")), ActionEvent.Type.COMBO), 0, "same member")
	_until(s, mop)
	s.last_actor_side = int(Combatant.Side.PARTY)
	s.last_party_actor_id = "p0"
	s.last_party_target_id = "e1"
	assert_len(Fx.of_type(s.submit(BattleCommand.attack("p1", "e0")), ActionEvent.Type.COMBO), 0, "different target")
	_until(s, mop)
	s.last_actor_side = int(Combatant.Side.ENEMY)
	s.last_party_actor_id = "p0"
	s.last_party_target_id = "e0"
	assert_len(Fx.of_type(s.submit(BattleCommand.attack("p1", "e0")), ActionEvent.Type.COMBO), 0, "enemy turn between")


func test_combo_needs_physical_or_magical_damage() -> void:
	# Fixed damage (ice spray) has no combo factor (02_TECH §5.9): it neither finishes nor starts a combo.
	var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_dummy", "enm_rat"]),
			{"seed": 8, "items": {"itm_ice_spray": 2}})
	s.start()
	var kai: Combatant = s.get_combatant("p0")
	var mop: Combatant = s.get_combatant("p1")
	_until(s, kai)
	Fx.force_next(s, mop)
	s.submit(BattleCommand.attack("p0", "e0"))
	assert_eq(s.current_actor(), mop)
	Fx.force_next(s, kai)
	var ev: Array[ActionEvent] = s.submit(BattleCommand.item("p1", "itm_ice_spray", PackedStringArray(["e0"])))
	assert_len(Fx.of_type(ev, ActionEvent.Type.COMBO), 0, "no COMBO for a fixed-damage finisher")
	assert_eq(Fx.of_type(ev, ActionEvent.Type.DAMAGE)[0].amount, 90, "fixed 90, no × 1.1")
	assert_eq(s.current_actor(), kai)
	Fx.force_next(s, mop)
	ev = s.submit(BattleCommand.attack("p0", "e0"))
	assert_len(Fx.of_type(ev, ActionEvent.Type.COMBO), 0, "a fixed-damage action does not start a combo either")
	assert_eq(s.current_actor(), mop)
	ev = s.submit(BattleCommand.attack("p1", "e0"))
	assert_len(Fx.of_type(ev, ActionEvent.Type.COMBO), 1, "control: attack right after the other member's attack")


func test_weapon_element_only_for_party_attacks() -> void:
	var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_slime"]),
			{"seed": 3, "kai": {"element_mods": {"fire": 1.5}}})
	s.start()
	var kai: Combatant = s.get_combatant("p0")
	var slime: Combatant = s.get_combatant("e0")
	kai.attack_element = "fire"
	slime.attack_element = "fire"     # never used for enemies: their attack skill's own element counts
	_until(s, kai)
	var dmg: ActionEvent = Fx.of_type(s.submit(BattleCommand.attack("p0", "e0")), ActionEvent.Type.DAMAGE)[0]
	assert_eq(dmg.element, "fire", "party attack: weapon element")
	assert_true(dmg.weak, "slime fire 1.5")
	_until(s, slime)
	dmg = Fx.of_type(s.submit(BattleCommand.attack("e0", "p0")), ActionEvent.Type.DAMAGE)[0]
	assert_eq(dmg.element, "physical", "enemy attack: skill element")
	assert_false(dmg.weak, "Kai's fire weakness is not hit")


func test_items_heal_revive_damage_and_delta() -> void:
	var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_rat", "enm_rat"]),
			{"items": {"itm_bandage": 2, "itm_smelling_salts": 1, "itm_molotov": 1, "itm_elixir": 1}})
	s.start()
	var kai: Combatant = s.get_combatant("p0")
	var mop: Combatant = s.get_combatant("p1")
	assert_eq(s.usable_items(), PackedStringArray(["itm_bandage", "itm_elixir", "itm_molotov", "itm_smelling_salts"]))
	_until(s, kai)
	kai.hp = 30
	var ev: Array[ActionEvent] = s.submit(BattleCommand.item("p0", "itm_bandage", PackedStringArray(["p0"])))
	var heal: ActionEvent = Fx.of_type(ev, ActionEvent.Type.HEAL)[0]
	assert_eq(heal.amount, 45)
	assert_eq(heal.hp_after, 64, "capped at max HP")
	assert_eq(int(s.items["itm_bandage"]), 1)
	var start: ActionEvent = Fx.of_type(ev, ActionEvent.Type.ACTION_START)[0]
	assert_eq(start.command, BattleCommand.Kind.ITEM)
	assert_eq(start.item_id, "itm_bandage")
	assert_eq(start.skill_id, "skl_item_bandage")
	mop.hp = 0
	_until(s, kai)
	ev = s.submit(BattleCommand.item("p0", "itm_smelling_salts", PackedStringArray(["p1"])))
	var rev: ActionEvent = Fx.of_type(ev, ActionEvent.Type.REVIVE)[0]
	assert_eq(rev.hp_after, 13, "30 % of 42 = 12.6 → 13")
	assert_true(mop.is_alive())
	assert_false(s.usable_items().has("itm_smelling_salts"), "used up")
	_until(s, kai)
	for e: Combatant in s.enemies():
		e.defending = false
	ev = s.submit(BattleCommand.item("p0", "itm_molotov", PackedStringArray()))
	var dmg: Array[ActionEvent] = Fx.of_type(ev, ActionEvent.Type.DAMAGE)
	assert_len(dmg, 2, "all enemies")
	assert_eq(dmg[0].amount, 90, "fixed 60 × fire weakness 1.5")
	var kos: Array[ActionEvent] = Fx.of_type(ev, ActionEvent.Type.KO)
	assert_len(kos, 2)
	for ko: ActionEvent in kos:
		assert_eq(ko.command, BattleCommand.Kind.ITEM, "KO.command of an item kill")
		assert_eq(ko.item_id, "itm_molotov", "KO.item_id names the item")
		assert_eq(ko.skill_id, "skl_item_molotov", "KO.skill_id is the item's use_skill")
	assert_true(s.is_finished(), "both rats (24 HP) are down")
	assert_eq(s.result.item_delta, {"itm_bandage": -1, "itm_smelling_salts": -1, "itm_molotov": -1})
	assert_eq(s.result.items_used, 3)


func test_mp_cost_defend_restore_and_elixir() -> void:
	var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_dummy"]), {"items": {"itm_elixir": 1},
		"kai": {"skills": PackedStringArray(["skl_kai_heavy_swing"])}})
	s.start()
	var kai: Combatant = s.get_combatant("p0")
	_until(s, kai)
	var ev: Array[ActionEvent] = s.submit(BattleCommand.skill("p0", "skl_kai_heavy_swing", PackedStringArray(["e0"])))
	var mp: ActionEvent = Fx.of_type(ev, ActionEvent.Type.MP_CHANGE)[0]
	assert_eq(mp.amount, -3)
	assert_eq(mp.mp_after, 9)
	_until(s, kai)
	ev = s.submit(BattleCommand.defend("p0"))
	assert_true(kai.defending)
	assert_eq(Fx.types(ev).slice(0, 3), PackedStringArray(["ACTION_START", "DEFEND", "MP_CHANGE"]))
	assert_eq(Fx.of_type(ev, ActionEvent.Type.MP_CHANGE)[0].amount, 2, "maxi(2, ceili(12 × 5 %))")
	_until(s, kai)
	assert_false(kai.defending, "defending ends at the next own TURN_START")
	kai.hp = 10
	kai.mp = 0
	ev = s.submit(BattleCommand.item("p0", "itm_elixir", PackedStringArray(["p0"])))
	assert_eq(Fx.of_type(ev, ActionEvent.Type.HEAL)[0].hp_after, 64)
	assert_eq(Fx.of_type(ev, ActionEvent.Type.MP_CHANGE)[0].mp_after, 12)


func test_validate_and_invalid_submits() -> void:
	var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_rat"]),
			{"kai": {"skills": PackedStringArray(["skl_kai_heavy_swing"])}})
	assert_eq(s.validate(BattleCommand.defend("p0")), "battle is not awaiting a command")
	assert_len(s.submit(BattleCommand.defend("p0")), 0, "submit before start → []")
	s.start()
	_until(s, s.get_combatant("p0"))
	assert_ne(s.validate(BattleCommand.defend("p1")), "", "not the current actor")
	assert_ne(s.validate(BattleCommand.attack("p0", "p1")), "", "attack an ally")
	assert_ne(s.validate(BattleCommand.attack("p0", "e7")), "", "unknown target")
	assert_ne(s.validate(BattleCommand.attack("p0", "")), "", "missing target")
	assert_ne(s.validate(BattleCommand.skill("p0", "skl_mop_noble_flame", PackedStringArray(["e0"]))), "",
			"skill not known")
	assert_ne(s.validate(BattleCommand.item("p0", "itm_bandage", PackedStringArray(["p0"]))), "", "no items")
	assert_ne(s.validate(null), "")
	s.get_combatant("p0").mp = 1
	assert_ne(s.validate(BattleCommand.skill("p0", "skl_kai_heavy_swing", PackedStringArray(["e0"]))), "", "MP")
	var before: int = s.history.size()
	assert_len(s.submit(BattleCommand.attack("p0", "p1")), 0, "invalid → [] (push_error)")
	assert_eq(s.history.size(), before, "nothing happened")
	assert_eq(s.validate(BattleCommand.attack("p0", "e0")), "")
	assert_eq(s.available_commands(s.get_combatant("p0")), [BattleCommand.Kind.ATTACK, BattleCommand.Kind.SKILL,
		BattleCommand.Kind.STUNT, BattleCommand.Kind.DEFEND, BattleCommand.Kind.FLEE], "menu order")
	assert_eq(s.default_target(s.get_combatant("p0"), ""), "e0")


func test_default_targets_and_valid_targets() -> void:
	var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_rat", "enm_pigeon", "enm_slime"]),
			{"mop": {"skills": PackedStringArray(["skl_mop_holy_lick", "skl_mop_revive"])}})
	s.start()
	var mop: Combatant = s.get_combatant("p1")
	s.get_combatant("e1").hp = 5
	assert_eq(s.valid_targets(mop, ""), PackedStringArray(["e0", "e1", "e2"]))
	assert_eq(s.default_target(mop, ""), "e1", "enemy: lowest hp")
	s.get_combatant("p0").hp = 20
	assert_eq(s.default_target(mop, "skl_mop_holy_lick"), "p0", "ally heal: lowest ratio")
	assert_eq(s.valid_targets(mop, "skl_mop_revive"), PackedStringArray(), "no KO'd ally")
	s.get_combatant("p0").hp = 0
	assert_eq(s.valid_targets(mop, "skl_mop_revive"), PackedStringArray(["p0"]))
	assert_eq(s.valid_targets(mop, "skl_mop_holy_lick"), PackedStringArray(["p1"]), "living allies only")


func test_same_seed_same_events_and_replay() -> void:
	for k: int in [0, 2, 5, 6]:
		var enemies: Array = ENCOUNTERS[k]
		var a: BattleState = Fx.make_state(data, PackedStringArray(enemies), _opts(4242, enemies))
		var b: BattleState = Fx.make_state(data, PackedStringArray(enemies), _opts(4242, enemies))
		var cmds: Array = []
		var ea: Array[ActionEvent] = a.start()
		while not a.is_finished() and cmds.size() < 400:
			var c: BattleCommand = a.choose_ai_command()
			cmds.append(JSON.parse_string(JSON.stringify(c.to_dict())))
			ea.append_array(a.submit(c))
		var eb: Array[ActionEvent] = Fx.run_auto(b, 400)
		assert_eq(Fx.dicts(eb), Fx.dicts(ea), "enc %d: same seed + same commands → identical events" % k)
		# Replay of the recorded commands (AI not recomputed) gives the same events and result.
		var r: BattleState = Fx.make_state(data, PackedStringArray(enemies), _opts(4242, enemies))
		var er: Array[ActionEvent] = r.start()
		for cd: Variant in cmds:
			er.append_array(r.submit(BattleCommand.from_dict(cd)))
		assert_eq(Fx.dicts(er), Fx.dicts(ea), "enc %d: replay ≡ live" % k)
		assert_eq(r.result.to_dict(), a.result.to_dict())
	var x: BattleState = Fx.make_state(data, PackedStringArray(ENCOUNTERS[1]), _opts(1, ENCOUNTERS[1]))
	var y: BattleState = Fx.make_state(data, PackedStringArray(ENCOUNTERS[1]), _opts(2, ENCOUNTERS[1]))
	assert_ne(Fx.dicts(Fx.run_auto(x)), Fx.dicts(Fx.run_auto(y)), "different seeds → different battles")


func test_hundred_seeds_auto_vs_auto_terminate() -> void:
	var max_turns: int = 0
	for seed in range(1, 101):
		var enemies: Array = ENCOUNTERS[seed % 5]
		var s: BattleState = Fx.make_state(data, PackedStringArray(enemies), _opts(seed, enemies))
		Fx.run_auto(s, 400)
		assert_true(s.is_finished(), "seed %d finished" % seed)
		assert_lt(s.turn_count, 200, "seed %d: < 200 turns" % seed)
		max_turns = maxi(max_turns, s.turn_count)
	assert_gt(max_turns, 0)


func test_action_event_roundtrip() -> void:
	var s: BattleState = Fx.make_state(data, PackedStringArray(ENCOUNTERS[6]), _opts(77, ENCOUNTERS[6]))
	var ev: Array[ActionEvent] = Fx.run_auto(s, 400)
	var seen: Dictionary = {}
	for e: ActionEvent in ev:
		var d: Dictionary = e.to_dict()
		assert_eq(ActionEvent.from_dict(d).to_dict(), d)
		var json: Variant = JSON.parse_string(JSON.stringify(d))
		assert_eq(ActionEvent.from_dict(json).to_dict(), d, "also after JSON (ints as floats)")
		seen[d["type"]] = true
	assert_true(seen.size() >= 12, "many event types covered (%d)" % seen.size())
	var full: ActionEvent = ActionEvent.make(ActionEvent.Type.DAMAGE)
	full.actor_id = "p0"
	full.target_id = "e1"
	full.target_ids = PackedStringArray(["e1", "e2"])
	full.skill_id = "skl_x"
	full.item_id = "itm_y"
	full.status_id = "sts_z"
	full.sponsor_id = "spn_w"
	full.def_id = "enm_rat"
	full.command = 1
	full.amount = 12
	full.max_hp = 24
	full.hp_after = 3
	full.mp_after = 4
	full.element = "fire"
	full.beat = 2
	full.crit = true
	full.weak = true
	full.resist = true
	full.immune = true
	full.success = true
	full.value = 7
	full.order = PackedStringArray(["p0", "e1"])
	full.text = "Hallo"
	var fd: Dictionary = full.to_dict()
	assert_eq(fd.size(), 24, "every field serialized when set")
	assert_eq(ActionEvent.from_dict(fd).to_dict(), fd)
	assert_eq(ActionEvent.make(ActionEvent.Type.TURN_END).to_dict(), {"type": "TURN_END"}, "only non-default fields")
	assert_null(ActionEvent.from_dict({"type": "NOPE"}), "unknown type → null (push_error)")


func test_battle_command_roundtrip() -> void:
	var cmds: Array[BattleCommand] = [BattleCommand.attack("p0", "e1"),
		BattleCommand.skill("p1", "skl_mop_noble_flame", PackedStringArray(["e0"])),
		BattleCommand.stunt("p0", "skl_stunt_kai_suplex", PackedStringArray(["e2"])),
		BattleCommand.item("p0", "itm_bandage", PackedStringArray(["p1"])), BattleCommand.defend("p1"),
		BattleCommand.flee("p0")]
	for c: BattleCommand in cmds:
		var d: Dictionary = c.to_dict()
		assert_eq(BattleCommand.from_dict(d).to_dict(), d)
		assert_eq(BattleCommand.from_dict(JSON.parse_string(JSON.stringify(d))).to_dict(), d)
	assert_eq(cmds[1].to_dict(), {"kind": "skill", "actor": "p1", "skill": "skl_mop_noble_flame", "item": "",
		"targets": ["e0"]}, "Brief §6b.2 format")
	assert_null(BattleCommand.from_dict({"kind": "dance", "actor": "p0"}), "unknown kind")
	assert_null(BattleCommand.from_dict({"kind": "attack"}), "missing actor")
	assert_eq(BattleCommand.KIND_NAMES.size(), BattleCommand.Kind.size())


func test_apply_gift_sponsor_effects() -> void:
	var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_rat", "enm_boss_janitor"]), {"is_boss": true})
	s.start()
	var kai: Combatant = s.get_combatant("p0")
	var mop: Combatant = s.get_combatant("p1")
	var actor: Combatant = s.current_actor()
	var n0: int = s.action_n
	var t0: int = s.turn_count
	kai.hp = 20
	var ev: Array[ActionEvent] = s.apply_gift({"kind": "sponsor_buff", "sponsor_id": "spn_gluck", "effect_pm": 1000})
	assert_eq(ev[0].type, ActionEvent.Type.SPONSOR_GIFT)
	assert_eq(ev[0].sponsor_id, "spn_gluck")
	assert_eq(ev[0].text, "Glückwasser")
	var heals: Array[ActionEvent] = Fx.of_type(ev, ActionEvent.Type.HEAL)
	assert_eq(heals[0].amount, 22, "35 % of 64 = 22.4 → 22")
	assert_eq(heals[0].hp_after, 42)
	assert_eq(heals[1].hp_after, 42, "Mopsula capped at max")
	assert_eq(s.current_actor(), actor, "a gift does not consume a turn")
	assert_eq(s.action_n, n0)
	assert_eq(s.turn_count, t0)
	ev = s.apply_gift({"kind": "sponsor_buff", "sponsor_id": "spn_krawumm"})
	assert_len(Fx.of_type(ev, ActionEvent.Type.STATUS_ADDED), 2)
	assert_true(kai.has_status("sts_haste") and mop.has_status("sts_haste"))
	assert_eq(ev[-1].type, ActionEvent.Type.CTB_ORDER, "changed order → CTB_ORDER")
	ev = s.apply_gift({"kind": "sponsor_buff", "sponsor_id": "spn_doom"})
	var slowed: int = 0
	for e: ActionEvent in Fx.of_type(ev, ActionEvent.Type.STATUS_ADDED):
		slowed += 1 if e.status_id == "sts_slow" else 0
	assert_eq(slowed, 2, "ignore_resist: the boss (slow resist 0.5) is slowed too")
	ev = s.apply_gift({"kind": "sponsor_buff", "sponsor_id": "spn_brutzel"})
	assert_eq(Fx.of_type(ev, ActionEvent.Type.ITEM_GAINED)[0].item_id, "itm_brutzel_burger")
	assert_eq(int(s.items["itm_brutzel_burger"]), 1)
	assert_has(s.usable_items(), "itm_brutzel_burger")
	mop.hp = 0
	ev = s.apply_gift({"kind": "sponsor_buff", "sponsor_id": "spn_sorgenfrei"})
	var rev: ActionEvent = Fx.of_type(ev, ActionEvent.Type.REVIVE)[0]
	assert_eq(rev.target_id, "p1")
	assert_eq(rev.hp_after, 21, "50 % of 42")
	assert_eq(mop.ctb_counter, CTBQueue.base_delay(14), "revived: counter base_delay")
	kai.mp = 0
	ev = s.apply_gift({"kind": "sponsor_buff", "sponsor_id": "spn_novanet", "effect_pm": 500})
	assert_eq(Fx.of_type(ev, ActionEvent.Type.MP_CHANGE)[0].amount, 2, "40 % × 0.5 = 20 % of 12 = 2.4 → 2")
	ev = s.apply_gift({"kind": "gold", "amount": 100, "effect_pm": 769})
	assert_eq(Fx.of_type(ev, ActionEvent.Type.CREDITS_GAINED)[0].value, 77, "(100 × 769 + 500) // 1000")
	ev = s.apply_gift({"kind": "chest", "tier": "gold", "contents": [
		{"rarity": "rare", "item_id": "itm_bandage", "qty": 2},
		{"rarity": "common", "credits": 40}]})
	assert_eq(Fx.types(ev), PackedStringArray(["ITEM_GAINED", "CREDITS_GAINED"]))
	assert_eq(ev[0].value, 2)
	ev = s.apply_gift({"kind": "cheer"})
	assert_len(ev, 0, "cosmetic gifts have no battle effect")
	assert_eq(s.current_actor(), actor)
	# Finish the battle and check the deltas.
	var guard: int = 0
	while not s.is_finished() and guard < 400:
		guard += 1
		var cur: Combatant = s.current_actor()
		if cur.is_party():
			s.submit(BattleCommand.flee(cur.id) if s.flee_allowed() else BattleCommand.defend(cur.id))
		else:
			for p: Combatant in s.party():
				p.hp = 0
			s.submit(BattleCommand.defend(cur.id))
	assert_true(s.is_finished())
	assert_eq(s.result.credits_delta, 117)
	assert_eq(int(s.result.item_delta["itm_brutzel_burger"]), 1)
	assert_eq(int(s.result.item_delta["itm_bandage"]), 2)
	assert_len(s.apply_gift({"kind": "gold", "amount": 100}), 0, "finished battle → no gift (push_warning)")


func test_apply_gift_rolled_chest_is_deterministic() -> void:
	var lists: Array = []
	for i in 2:
		var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_rat"]), {"seed": 99})
		s.start()
		lists.append(Fx.dicts(s.apply_gift({"kind": "chest", "tier": "gold", "contents": []})))
	assert_eq(lists[0], lists[1], "same seed + same gift index → same roll")
	var d: Array = lists[0]
	assert_eq(d.size(), 4, "gold box: 4 rolls")
	var has_epic: bool = false
	for e: Variant in d:
		if str((e as Dictionary).get("item_id", "")) == "itm_wpn_axe":
			has_epic = true
	assert_true(has_epic, "guarantee epic on the last roll")


## Rarity of one rolled chest entry in the fixture pool f1 (common: credits/bandage, rare: salts, epic: axe).
## Rarity of the pool entry behind a gift event; duplicate equipment arrives as CREDITS_GAINED with item_id = the
## piece it replaces (live-integrity-15), so it still counts as that piece's roll.
func _pool_rarity(e: ActionEvent) -> int:
	if e.item_id == "" or e.item_id == "itm_bandage":
		return 0
	return 1 if e.item_id == "itm_smelling_salts" else 2


func test_rolled_chest_guarantee_roll_uses_restricted_weights() -> void:
	# 05 §7.4: the guarantee roll draws from weights[tier] with every rarity below the guarantee set to 0
	# (silver [55, 38, 7] → [0, 38, 7]: epic 7/45 ≈ 15.6 %, not 7 %).
	var t: Dictionary = Fx.tables()
	(t["lootboxes"] as Array).append({"id": "box_silver", "name": "Silber", "tier": 2, "color": "#c0c0c0", "rolls": 1,
		"rarity_weights": {"common": 55, "rare": 38, "epic": 7}, "guarantee": "rare"})
	(t["lootboxes"] as Array).append({"id": "box_plat", "name": "Silber 3", "tier": 4, "color": "#e5e4e2", "rolls": 3,
		"rarity_weights": {"common": 55, "rare": 38, "epic": 7}, "guarantee": "rare"})
	var d: GameData = fixture_data(t)
	var s: BattleState = Fx.make_state(d, PackedStringArray(["enm_rat"]), {"seed": 5})
	s.start()
	var counts: Array[int] = [0, 0, 0]
	var n: int = 2000
	for _i in n:
		for e: ActionEvent in s.apply_gift({"kind": "chest", "tier": "silver", "contents": []}):
			if e.type == ActionEvent.Type.ITEM_GAINED or e.type == ActionEvent.Type.CREDITS_GAINED:
				counts[_pool_rarity(e)] += 1
	assert_eq(counts[0], 0, "the guarantee roll never draws below rare")
	assert_eq(counts[1] + counts[2], n, "one entry per chest")
	assert_between(counts[2], 250, 375, "epic ≈ 7/45 of the guarantee rolls (%d)" % counts[2])
	# Three rolls: the last one is restricted only if no earlier roll reached rare.
	var last_common: int = 0
	for _i in 600:
		var r: Array[int] = []
		for e: ActionEvent in s.apply_gift({"kind": "chest", "tier": "plat", "contents": []}):
			if e.type == ActionEvent.Type.ITEM_GAINED or e.type == ActionEvent.Type.CREDITS_GAINED:
				r.append(_pool_rarity(e))
		assert_len(r, 3)
		if r.size() != 3:
			continue
		assert_true(r.max() >= 1, "every chest has a rare+ entry")
		if r[2] == 0:
			last_common += 1
			assert_true(maxi(r[0], r[1]) >= 1, "last roll common only after an earlier rare+")
	assert_gt(last_common, 0, "the last roll uses the full weights when the guarantee is already met")


func test_ghost_overrides_for_stun_preview() -> void:
	var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_rat", "enm_boss_janitor"]),
			{"kai": {"skills": PackedStringArray(["skl_kai_cable_whip"])}})
	s.start()
	_until(s, s.get_combatant("p0"))
	var kai: Combatant = s.get_combatant("p0")
	var rat: Combatant = s.get_combatant("e0")
	var boss: Combatant = s.get_combatant("e1")
	var g: Dictionary = s.ghost_overrides(kai, "skl_kai_cable_whip", PackedStringArray(["e0"]))
	assert_eq(g, {"e0": rat.ctb_counter + 43}, "stun: counter + base_delay")
	g = s.ghost_overrides(kai, "skl_kai_cable_whip", PackedStringArray(["e1"]))
	assert_eq(g, {"e1": boss.ctb_counter + 23}, "boss: + roundi(45 × 0.5)")
	assert_eq(s.ghost_overrides(kai, "skl_kai_heavy_swing", PackedStringArray(["e0"])), {}, "no stun → no ghost")
	var plain: PackedStringArray = s.preview_order(12, 3)
	var g2: Dictionary = s.ghost_overrides(kai, "skl_kai_cable_whip", PackedStringArray(["e0"]))
	var ghost: PackedStringArray = s.preview_order(12, 3, g2)
	assert_gt(ghost.find("e0"), plain.find("e0"), "the stunned target moves back in the preview")


func test_real_data_encounters_integration() -> void:
	var rd: GameData = real_data()
	if not rd.is_valid():
		return      # real_data() has already failed this test with the loader errors; no battles on broken data
	var battles: int = 0
	for f: FloorDef in rd.all_floors():
		for enc: EncounterDef in f.encounters:
			for seed: int in [1, 2]:
				var setup: BattleSetup = BattleSetup.new()
				setup.encounter_id = enc.id
				setup.enemy_ids = enc.enemies
				setup.seed = seed
				setup.is_boss = enc.boss
				setup.can_flee = enc.can_flee
				setup.tutorial = enc.tutorial
				setup.enemy_dmg_mult = Balance.TUTORIAL_ENEMY_DMG if enc.tutorial else 1.0
				setup.floor_index = f.index
				for def: PartyMemberDef in rd.all_party():
					var skills: PackedStringArray = []
					for ls: Dictionary in def.learnset:
						skills.append(str(ls["skill"]))
					setup.party.append(Fx.member(rd, def.id, "p%d" % setup.party.size(), def.battle_slot, {"skills": skills}))
				var inv: Dictionary = rd.party_start().get("inventory", {})
				for k: Variant in inv.keys():
					setup.items[str(k)] = int(inv[k])
				var s: BattleState = BattleState.new(setup, rd)
				var ev: Array[ActionEvent] = Fx.run_auto(s, 3000)
				assert_true(s.is_finished(), "%s seed %d finished" % [enc.id, seed])
				if s.is_finished():
					_check_invariants(ev, s, "%s seed %d" % [enc.id, seed])
				battles += 1
	assert_gt(battles, 0, "real data has encounters")


func _hold(s: BattleState, c: Combatant) -> void:
	for o: Combatant in s.combatants:
		if o != c:
			o.ctb_counter = 100000


func _until(s: BattleState, c: Combatant) -> void:
	for _i in 30:
		if s.is_finished() or s.current_actor() == c:
			return
		Fx.force_next(s, c)
		s.submit(BattleCommand.defend(s.current_actor().id))
