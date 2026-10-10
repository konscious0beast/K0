extends TestCase
## M7 balance (02_TECH §11.5, 01_GDD §13): every regular Floor-1 encounter is won by the auto-battling party (AutoPolicy
## vs EnemyAI, 50 seeds) in >= 80 % of the fights at the level and with the gear the GDD progression expects at that
## point: zone A L2 (tutorial L1), zone B L3 (start party, Lv 1–3), zone C L4, Hausmeister L5, zone D L6,
## Rattenkönigin L7. The bosses are meant to be lost now and then (GDD §13: ~20 % / ~35 % on the first try): their loss
## rates WITH the sponsor gifts as they occur are pinned by test_m7_show_balance; here, without any gift, they must stay
## winnable (>= BOSS_MIN_WIN_NO_GIFTS) within their party-turn bands.
## Party turns per won fight are checked against GDD §13 (regular 4–6, median 4.5; Hausmeister 16–22; Königin 20–26):
## the MEDIAN over all regular encounters must lie in 4–6 (REGULAR_TURNS_MEDIAN), while each single encounter's average
## may span 3–7 (REGULAR_TURNS) — GDD §13 gives the 4–6 band for the floor as a whole, single encounters (one-enemy
## rare fight vs. a 3-enemy pack) legitimately sit a turn beyond it, as in the GDD sim (3.2 for the lightest).
## Boss turn counts hinge on how the AutoPolicy spends MP: formulas (GDD §3/§4), party growth, gear and boss data match
## the GDD; the former 02_TECH §5.8 rule "MP >= 50 % → strongest skill, else ATTACK" gave 34.5 / 42.0 turns (Mopsula
## hits for 2–3 below 50 % MP), the MP-efficient rule of §5.8 as amended by CR M7-B1 gives ≈ 19.5 / 24
## (GDD sim 18 / 23).
## Levels/gear per zone follow the GDD §5.4/§13 progression (C L4 + mid gear, D L6 + late gear); 02_TECH §11.5 was
## amended accordingly in the integration phase (it used to say "Startparty (Lv 1–3)" for every encounter).

const SEEDS: int = 50
const MIN_WIN_RATE: float = 0.80
const BOSS_MIN_WIN_NO_GIFTS: float = 0.50
const MAX_SUBMITS: int = 800
## GDD §13 party turns per won fight: regular fights per encounter (tutorial excluded, Sim 3.2) and their median.
const REGULAR_TURNS: Vector2 = Vector2(3.0, 7.0)
const REGULAR_TURNS_MEDIAN: Vector2 = Vector2(4.0, 6.0)
const BOSS_TURNS: Dictionary = {
	"enc_f1_boss_hausmeister": Vector2(16.0, 22.0),
	"enc_f1_boss_rattenkoenigin": Vector2(20.0, 26.0),
}

## Gear the party can have at each point of floor 1 (GDD §2.5, §6.5): start kit; SR1 purchases + metal chests A/B;
## after the Hausmeister: fire axe (locked chest C), key ring (boss drop), signet collar (locked chest D),
## gas mask (metal chest C).
const GEAR: Dictionary = {
	"start": {"kai": ["itm_wpn_mop", "itm_arm_hoodie", ""],
		"mopsula": ["itm_wpn_collar_leather", "itm_arm_pug_sweater", ""]},
	"mid": {"kai": ["itm_wpn_pipe_wrench", "itm_arm_safety_vest", ""],
		"mopsula": ["itm_wpn_collar_studded", "itm_arm_velvet_cape", ""]},
	"late": {"kai": ["itm_wpn_fire_axe", "itm_arm_safety_vest", "itm_acc_key_ring"],
		"mopsula": ["itm_wpn_collar_signet", "itm_arm_velvet_cape", "itm_acc_gas_mask"]},
}
## Battle inventories: the start inventory (party.json → start) and a boss kit (start + metal chest B salts + burgers).
const ITEMS: Dictionary = {
	"start": {"itm_bandage": 3, "itm_antidote": 1},
	"boss": {"itm_bandage": 3, "itm_brutzel_burger": 2, "itm_smelling_salts": 2, "itm_antidote": 1},
}
## encounter → [party level, gear, items]
const PLAN: Dictionary = {
	"enc_f1_a1_tutorial": [1, "start", "start"],
	"enc_f1_a2": [2, "start", "start"], "enc_f1_a3": [2, "start", "start"], "enc_f1_a4": [2, "start", "start"],
	"enc_f1_a_rare": [2, "start", "start"], "enc_f1_evt_pigeons": [2, "start", "start"],
	"enc_f1_b1": [3, "start", "start"], "enc_f1_b2": [3, "start", "start"], "enc_f1_b3": [3, "start", "start"],
	"enc_f1_b4": [3, "start", "start"], "enc_f1_evt_slime": [3, "start", "start"],
	"enc_f1_c1": [4, "mid", "start"], "enc_f1_c2": [4, "mid", "start"], "enc_f1_c3": [4, "mid", "start"],
	"enc_f1_boss_hausmeister": [5, "mid", "boss"],
	"enc_f1_d1": [6, "late", "start"], "enc_f1_d2": [6, "late", "start"], "enc_f1_d3": [6, "late", "start"],
	"enc_f1_boss_rattenkoenigin": [7, "late", "boss"],
}


func test_plan_covers_every_floor_1_encounter() -> void:
	# Runs always (pure data): the balance plan must not silently miss an encounter.
	var f1: FloorDef = real_data().floor_def(1)
	var ids: Array = []
	for enc: EncounterDef in f1.encounters:
		ids.append(enc.id)
		assert_true(PLAN.has(enc.id), "balance plan covers " + enc.id)
	for id: String in PLAN:
		assert_has(ids, id)
	for id: String in PLAN:
		var p: Array = PLAN[id]
		for slot: String in ["kai", "mopsula"]:
			var gear: Array = (GEAR[p[1]] as Dictionary)[slot]
			for item_id: Variant in gear:
				if str(item_id) != "":
					var it: ItemDef = real_data().item(str(item_id))
					assert_true(it.equip_by.is_empty() or it.equip_by.has(slot), "%s equippable by %s" % [item_id, slot])


func test_regular_encounters_win_rate() -> void:
	var turns: Array = []
	for id: String in PLAN:
		var enc: EncounterDef = real_data().encounter(id)
		if enc.boss:
			continue
		var avg: float = _assert_win_rate(id)
		if enc.tutorial:
			continue
		assert_between(avg, REGULAR_TURNS.x, REGULAR_TURNS.y, "%s: avg party turns (GDD §13)" % id)
		turns.append(avg)
	turns.sort()
	var median: float = (float(turns[(turns.size() - 1) >> 1]) + float(turns[turns.size() >> 1])) / 2.0
	assert_between(median, REGULAR_TURNS_MEDIAN.x, REGULAR_TURNS_MEDIAN.y, "median party turns of regular fights")


func test_hausmeister_at_level_5() -> void:
	var avg: float = _assert_win_rate("enc_f1_boss_hausmeister", BOSS_MIN_WIN_NO_GIFTS)
	var band: Vector2 = BOSS_TURNS["enc_f1_boss_hausmeister"]
	assert_between(avg, band.x, band.y, "enc_f1_boss_hausmeister: avg party turns (GDD §13)")


func test_rattenkoenigin_at_level_7() -> void:
	var avg: float = _assert_win_rate("enc_f1_boss_rattenkoenigin", BOSS_MIN_WIN_NO_GIFTS)
	var band: Vector2 = BOSS_TURNS["enc_f1_boss_rattenkoenigin"]
	assert_between(avg, band.x, band.y, "enc_f1_boss_rattenkoenigin: avg party turns (GDD §13)")


func test_tutorial_cannot_be_lost() -> void:
	var stats: Dictionary = _run_series("enc_f1_a1_tutorial", 1, "start", "start", 20)
	assert_eq(int(stats["wins"]), 20, "tutorial (enemy damage × 0.5, HP never below 1) is always won")


func test_battles_are_deterministic() -> void:
	var a: Dictionary = _run_battle("enc_f1_b4", 3, "start", "start", 4242)
	var b: Dictionary = _run_battle("enc_f1_b4", 3, "start", "start", 4242)
	assert_eq(a, b, "same seed + same data = same battle")


# --- helpers -------------------------------------------------------------------------------------------------------

## Asserts the win rate (>= min_rate) of `enc_id` at its PLAN level/gear and returns the average party turns of the
## won fights.
func _assert_win_rate(enc_id: String, min_rate: float = MIN_WIN_RATE) -> float:
	var p: Array = PLAN[enc_id]
	var stats: Dictionary = _run_series(enc_id, int(p[0]), str(p[1]), str(p[2]), SEEDS)
	var rate: float = float(stats["wins"]) / float(SEEDS)
	assert_true(rate >= min_rate, "%s at L%d (%s gear): win rate %.0f %% < %.0f %% (avg party turns %.1f)" % [
		enc_id, int(p[0]), str(p[1]), rate * 100.0, min_rate * 100.0, float(stats["avg_party_turns"])])
	assert_eq(int(stats["stuck"]), 0, enc_id + ": every battle terminates")
	return float(stats["avg_party_turns"])


func _run_series(enc_id: String, level: int, gear: String, items: String, n: int) -> Dictionary:
	var wins: int = 0
	var stuck: int = 0
	var party_turns: int = 0
	for i in n:
		var r: Dictionary = _run_battle(enc_id, level, gear, items, SeedUtil.derive(7331, "m7_balance", i))
		if bool(r["stuck"]):
			stuck += 1
		elif int(r["outcome"]) == BattleResult.Outcome.VICTORY:
			wins += 1
			party_turns += int(r["party_turns"])
	return {"wins": wins, "stuck": stuck, "avg_party_turns": float(party_turns) / float(maxi(1, wins))}


## One auto battle (AutoPolicy for the party, EnemyAI for enemies) → {"outcome", "party_turns", "stuck", "hp"}.
func _run_battle(enc_id: String, level: int, gear: String, items: String, seed: int) -> Dictionary:
	var d: GameData = real_data()
	var enc: EncounterDef = d.encounter(enc_id)
	var setup: BattleSetup = BattleSetup.new()
	setup.encounter_id = enc_id
	setup.enemy_ids = enc.enemies.duplicate()
	setup.seed = seed
	setup.is_boss = enc.boss
	setup.can_flee = enc.can_flee and not enc.tutorial
	setup.tutorial = enc.tutorial
	setup.enemy_dmg_mult = Balance.TUTORIAL_ENEMY_DMG if enc.tutorial else 1.0
	setup.items = (ITEMS[items] as Dictionary).duplicate()
	setup.credits_available = 200
	setup.auto_battle = true
	setup.floor_index = 1
	var party: Array[Combatant] = []
	var slot: int = 0
	for def: PartyMemberDef in d.all_party():
		party.append(_make_member(d, def, slot, level, (GEAR[gear] as Dictionary)[def.id]))
		slot += 1
	setup.party = party
	var state: BattleState = BattleState.new(setup, d)
	state.start()
	var submits: int = 0
	while not state.is_finished() and submits < MAX_SUBMITS:
		var cmd: BattleCommand = state.choose_ai_command()
		if cmd == null or state.submit(cmd).is_empty():
			break
		submits += 1
	if not state.is_finished() or state.result == null:
		return {"outcome": -1, "party_turns": 0, "stuck": true, "hp": []}
	var hp: Array = []
	for c: Combatant in state.party():
		hp.append(c.hp)
	return {"outcome": int(state.result.outcome), "party_turns": state.result.party_turns, "stuck": false, "hp": hp}


## Party combatant at `level` with `equipment` (GDD §4.1: stat(L) = floori(base + growth × (L − 1)) + equipment),
## learned skills = learnset up to level. Self-contained so that only the M1 core is under test.
func _make_member(d: GameData, def: PartyMemberDef, slot: int, level: int, equipment: Array) -> Combatant:
	var values: Dictionary = {}
	for k: String in StatBlock.KEYS:
		values[k] = floori(float(def.base_stats[k]) + float(def.growth[k]) * float(level - 1))
	var crit: float = 0.0
	var element_mods: Dictionary = def.element_mods.duplicate()
	var immune: PackedStringArray = def.status_immune.duplicate()
	var attack_element: String = "physical"
	for item_id: Variant in equipment:
		if str(item_id) == "":
			continue
		var it: ItemDef = d.item(str(item_id))
		for k: Variant in it.stats:
			values[str(k)] = int(values[str(k)]) + int(it.stats[k])
		crit += it.crit_bonus
		for el: Variant in it.element_mods:
			element_mods[el] = float(element_mods.get(el, 1.0)) * float(it.element_mods[el])
		for s: String in it.status_immune:
			if not immune.has(s):
				immune.append(s)
		if it.type == "weapon":
			attack_element = it.attack_element
	var skills: PackedStringArray = []
	for l: Dictionary in def.learnset:
		if int(l["level"]) <= level:
			skills.append(str(l["skill"]))
	var stats: StatBlock = StatBlock.from_dict(values)
	return Combatant.create_party(def, "p%d" % slot, slot, def.name, level, stats, int(values["hp"]), int(values["mp"]),
		skills, def.stunts, def.attack_skill, element_mods, immune, attack_element, crit)
