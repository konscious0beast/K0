extends TestCase
## 10 §6.2 (SD1 row 5) / §6.9 test_sd_engine_golden: the CTB engine of the Stempelduell — moved unchanged from the
## campaign to core/stempel/ctb in R5b part 2b — is frozen by golden values. Two fixed fights on the test_m1 mini data
## set (independent of res://data): a regular one (three enemies, items, stunts, statuses, heals) and a boss one (the
## queen's phases: summons, the pseudo-unit train, fixed self damage, haste). The party plays a script, one command per
## own turn (a scripted command the engine refuses falls back to AutoPolicy, which is frozen with it), the enemies play
## EnemyAI. Each fight ends with a fixed StateHash.of_battle, event count, digest of the event stream, outcome and
## number of party commands; two runs are identical, the commands replay through a JSON round trip. Plus the CTB part
## of the former test_m8_state_hash: snapshot → from_dict → the same hash, and the restored battle continues
## identically.
##
## A change of a shared class (Combatant, DamageCalc, ActionEvent, StatusEffect, BattleResult …) that moves the CTB
## behaviour makes this test fail: the Stempelduell then needs a change request and an SD_VERSION step (10 §6.6).
## Updating the golden values — deliberately, never to turn a red test green by accident: run
## `tools/check.sh --tests-only --filter=sd_engine_golden`; the failure prints the current values ("golden now: …");
## paste them into GOLDEN and give the reason in the commit message.

const Fx := preload("res://tests/test_m1_fixture.gd")
const MAX_STEPS: int = 800

## SD1 (R5b part 2b): the regular fight is lost after 35 party commands (the mimic steals and escapes, the shaman
## heals, a revive, stunts and defends); the boss fight is won after 32 (two phase changes, three summons, the train
## comes and goes).
const GOLDEN: Dictionary = {
	"regular": {"hash": "cf4ddad12a0e8da4db3e453c931f04552e3c2d8eebba3df7476c3f4eeeb4028c", "events": 444,
		"stream": "821c0fb76144619dc05186ebe4167539d33572fc134c86d3f3eedc6debb96ea7", "outcome": 1, "commands": 35},
	"boss": {"hash": "1fa2ac7064bbebe45d57ee0f843936fa0070e58abd4363d90ed92e76e3fd46b7", "events": 300,
		"stream": "56e7bc33b4d204344ab0aee6930a88732e9937cda0c02e9d0053134d8e1e8c95", "outcome": 0, "commands": 32},
}

## Per party unit, cycled over its own turns: "attack", "defend", "skill:<id>", "stunt:<id>", "item:<id>".
const SCRIPTS: Dictionary = {
	"p0": ["skill:skl_kai_heavy_swing", "stunt:skl_stunt_kai_suplex", "item:itm_ice_spray", "attack",
		"skill:skl_kai_cable_whip", "defend", "item:itm_bandage", "skill:skl_kai_sweep", "skill:skl_kai_first_aid"],
	"p1": ["skill:skl_mop_frost_sneeze", "skill:skl_mop_expert_opinion", "skill:skl_mop_noble_flame",
		"item:itm_molotov", "skill:skl_mop_holy_lick", "stunt:skl_stunt_mop_entrance", "attack",
		"skill:skl_mop_mass_lick", "skill:skl_mop_revive"],
}
const KAI_SKILLS: PackedStringArray = ["skl_kai_heavy_swing", "skl_kai_cable_whip", "skl_kai_sweep",
	"skl_kai_first_aid"]
const MOP_SKILLS: PackedStringArray = ["skl_mop_noble_flame", "skl_mop_frost_sneeze", "skl_mop_expert_opinion",
	"skl_mop_holy_lick", "skl_mop_mass_lick", "skl_mop_revive"]


func _setup(data: GameData, fight: String) -> BattleSetup:
	var boss: bool = fight == "boss"
	var kai: Dictionary = {"skills": KAI_SKILLS}
	var mop: Dictionary = {"skills": MOP_SKILLS}
	if boss:                                         # level-1 stats would not last a phase of the queen
		kai["stats"] = {"hp": 300, "mp": 60, "str": 34, "def": 20, "res": 12, "spd": 12}
		mop["stats"] = {"hp": 220, "mp": 120, "mag": 36, "def": 12, "res": 20}
	else:                                            # a long regular fight: poison ticks, the shaman's heals, a theft
		kai["stats"] = {"str": 7}
		mop["stats"] = {"mag": 7}
	var ids: PackedStringArray = PackedStringArray(["enm_boss_queen"] if boss else ["enm_rat", "enm_shaman",
		"enm_mimic", "enm_rat"])
	var items: Dictionary = {"itm_bandage": 3, "itm_antidote": 1, "itm_smelling_salts": 1}
	if boss:                                         # the fixed-damage items would end the regular fight at once
		items.merge({"itm_ice_spray": 2, "itm_molotov": 2})
	return Fx.make_setup(data, ids, {"seed": 4321 if boss else 1234, "is_boss": boss, "kai": kai, "mop": mop,
		"items": items, "encounter_id": "enc_sd_golden_" + fight})


## The targets of a scripted command: every valid one for an all_* skill, else the engine's default target.
static func _targets(s: BattleState, actor: Combatant, skill_id: String) -> PackedStringArray:
	var sk: SkillDef = s.skill_def(skill_id if skill_id != "" else actor.attack_skill)
	if sk != null and sk.target.begins_with("all_"):
		return s.valid_targets(actor, skill_id)
	var t: String = s.default_target(actor, skill_id)
	return PackedStringArray([t]) if t != "" else PackedStringArray()


static func _scripted(s: BattleState, actor: Combatant, n: int) -> BattleCommand:
	var script: Array = SCRIPTS.get(actor.id, ["attack"])
	var entry: String = str(script[n % script.size()])
	var id: String = entry.get_slice(":", 1) if entry.contains(":") else ""
	var cmd: BattleCommand = null
	match entry.get_slice(":", 0):
		"attack":
			cmd = BattleCommand.attack(actor.id, s.default_target(actor, ""))
		"defend":
			cmd = BattleCommand.defend(actor.id)
		"skill":
			cmd = BattleCommand.skill(actor.id, id, _targets(s, actor, id))
		"stunt":
			cmd = BattleCommand.stunt(actor.id, id, _targets(s, actor, id))
		"item":
			var it: ItemDef = s.item_def(id)
			cmd = BattleCommand.item(actor.id, id, _targets(s, actor, it.use_skill if it != null else ""))
	if cmd == null or s.validate(cmd) != "":
		cmd = s.choose_ai_command()                  # AutoPolicy: the engine's own choice
	return cmd


## {"state", "events", "cmds" (the party commands as dicts)}; `given` replays party commands instead of the script.
func _fight(fight: String, given: Array = []) -> Dictionary:
	var data: GameData = fixture_data(Fx.tables())
	var s: BattleState = BattleState.new(_setup(data, fight), data)
	var events: Array[ActionEvent] = s.start()
	var cmds: Array = []
	var turns: Dictionary = {}
	var steps: int = 0
	while not s.is_finished() and steps < MAX_STEPS:
		steps += 1
		var actor: Combatant = s.current_actor()
		if actor == null:
			fail("%s: no current actor at step %d" % [fight, steps])
			break
		var cmd: BattleCommand = null
		if actor.is_party():
			if given.is_empty():
				cmd = _scripted(s, actor, int(turns.get(actor.id, 0)))
				turns[actor.id] = int(turns.get(actor.id, 0)) + 1
			elif cmds.size() < given.size():
				cmd = BattleCommand.from_dict(given[cmds.size()] as Dictionary)
			else:
				fail("%s: the replay ran out of commands" % fight)
				break
			cmds.append(cmd.to_dict())
		else:
			cmd = s.choose_ai_command()
		events.append_array(s.submit(cmd))
	return {"state": s, "events": events, "cmds": cmds}


static func _dicts(events: Array) -> Array:
	var out: Array = []
	for e: ActionEvent in events:
		out.append(e.to_dict())
	return out


static func _values(run: Dictionary) -> Dictionary:
	var s: BattleState = run["state"]
	var events: Array = run["events"]
	return {"hash": StateHash.of_battle(s), "events": events.size(), "stream": CanonicalJson.sha256_hex(_dicts(events)),
		"outcome": int(s.result.outcome) if s.result != null else -1, "commands": (run["cmds"] as Array).size()}


func test_golden_values() -> void:
	for fight: String in ["regular", "boss"]:
		var run: Dictionary = _fight(fight)
		var s: BattleState = run["state"]
		assert_true(s.is_finished(), fight + ": the fight ends")
		var got: Dictionary = _values(run)
		assert_eq(got, GOLDEN[fight], "%s golden now: %s" % [fight, JSON.stringify(got)])


func test_two_runs_are_identical() -> void:
	for fight: String in ["regular", "boss"]:
		var a: Dictionary = _fight(fight)
		var b: Dictionary = _fight(fight)
		assert_eq(_values(a), _values(b), fight)
		assert_eq(_dicts(a["events"]), _dicts(b["events"]), fight)
		assert_eq((a["state"] as BattleState).to_dict(), (b["state"] as BattleState).to_dict(), fight)


func test_the_commands_replay_through_json() -> void:
	for fight: String in ["regular", "boss"]:
		var a: Dictionary = _fight(fight)
		var parsed: Variant = JSON.parse_string(JSON.stringify(a["cmds"]))
		assert_true(parsed is Array and not (parsed as Array).is_empty(), fight + ": a parsed command list")
		var b: Dictionary = _fight(fight, parsed as Array)
		assert_eq(_values(b), _values(a), fight + ": the JSON round trip changes nothing")


## The CTB part of the former test_m8_state_hash (05 §3.4 resync): a snapshot restores to the same hash, an action
## changes it, the restored battle continues identically — also from the middle of a fight to its end.
func test_battle_hash_snapshot_round_trip() -> void:
	var data: GameData = fixture_data(Fx.tables())
	var battle: BattleState = BattleState.new(_setup(data, "regular"), data)
	battle.start()
	var hex: RegEx = RegEx.create_from_string("^[0-9a-f]{64}$")
	var h0: String = StateHash.of_battle(battle)
	assert_true(hex.search(h0) != null, "battle hash: " + h0)
	var copy: BattleState = BattleState.from_dict(JSON.parse_string(JSON.stringify(battle.to_dict())), data)
	assert_eq(StateHash.of_battle(copy), h0, "snapshot → from_dict → same hash")
	var cmd: BattleCommand = battle.choose_ai_command()
	battle.submit(cmd)
	copy.submit(BattleCommand.from_dict(cmd.to_dict()))
	assert_ne(StateHash.of_battle(battle), h0, "an action changes the hash")
	assert_eq(StateHash.of_battle(copy), StateHash.of_battle(battle), "restored battle continues identically")
	for i in 12:
		if battle.is_finished():
			break
		battle.submit(battle.choose_ai_command())
	var mid: BattleState = BattleState.from_dict(JSON.parse_string(JSON.stringify(battle.to_dict())), data)
	assert_eq(StateHash.of_battle(mid), StateHash.of_battle(battle), "a snapshot from the middle of the fight")
	var steps: int = 0
	while not battle.is_finished() and steps < MAX_STEPS:
		steps += 1
		var c: BattleCommand = battle.choose_ai_command()
		battle.submit(c)
		mid.submit(BattleCommand.from_dict(c.to_dict()))
	assert_true(battle.is_finished() and mid.is_finished(), "both end")
	assert_eq(StateHash.of_battle(mid), StateHash.of_battle(battle), "… to the same end")
	assert_eq(StateHash.of_battle(null), "")
