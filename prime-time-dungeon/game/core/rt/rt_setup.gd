# STUB(R1a) — owned by R1b. Replace completely, keep the public API.
class_name RtSetup extends BattleSetup
## Start data of one real-time combat (07 §3.4). Built by BattleBridge.make_rt_setup (R1b) from the recorded encounter
## command. Inherited and still used: encounter_id, group_id (first group), enemy_ids (first group), party (Combatant
## snapshots), items, credits_available, advantage, seed, is_boss, can_flee, tutorial, enemy_dmg_mult, exp_mult,
## show_mods, theme_id, palette, floor_index. Not used: auto_battle (→ presets/autopilot).
## Contract note (R1a): 07 §3.4 names the opening action `opener`, but BattleSetup already has `opener: String`
## ("" | "bark", 06 A × C, recorded with the encounter) and GDScript forbids redefining a parent member — the real-time
## opening action is therefore `rt_opener` (the encounter command's rt block calls it "open"). BattleSetup.opener keeps
## its meaning ("bark" opened a PREEMPTIVE combat).

var cell: Vector2i = Vector2i.ZERO          # Set cell
var room_kind: int = 0                      # RoomCell.Kind
## RtGeo: {"r": int cm, "doors": int (N 1, E 2, S 4, W 8), "closed": bool, "blockers": [[x0, z0, x1, z1], …]}
var geo: Dictionary = {}
var units: Array[RtUnit] = []               # party (slot order), then enemies (group order, formation order)
## [{"group_id", "encounter_id", "enemy_ids": PackedStringArray, "lead": [x, z, yaw], "state": String, "entry": [x, z]}]
var groups: Array[Dictionary] = []
var controlled_id: String = "p0"            # unit id of GameState.hero (§5.1)
## unit id → {"preset": "attack"|"support"|"careful", "tog": {"interrupt": bool, "show": bool, "potions": bool}}
var presets: Dictionary = {}
var auto_attack: bool = true                # initial auto-attack switch of the controlled unit
var auto_retarget: bool = true              # pick the next target when the current one falls
## {} | {"kind": "strike", "target": "e0"} | {"kind": "skill", "u": "p0", "skill": id, "target": "e0"} |
## {"kind": "item", "u", "item", "target"} — 07 §3.4 "opener" (renamed, see header)
var rt_opener: Dictionary = {}
var mods: Array[Dictionary] = []            # RtMods entries (§9.5), canonical, static for the whole combat
var rules: Dictionary = {}                  # combat-relevant run rules (§10.7), canonical
var difficulty: StringName = &"prime"       # &"vorabend": telegraph warn times × EASY_WARN_PM (§3.16)
var tutorial_steps: PackedStringArray = []  # §2.13; presentation only (the sim never reads it), part of to_dict()
var balance: RtBalance = null               # data/rt_balance.json (§3.16); pinned by the data hash, not serialized


## Canonical: BattleSetup.to_dict() + the fields above (units as RtUnit.snapshot(), Vector2i as [x, y]).
func to_dict() -> Dictionary:
	var d: Dictionary = super()
	var us: Array = []
	for u: RtUnit in units:
		us.append(u.snapshot())
	var gs: Array = []
	for g: Dictionary in groups:
		gs.append(RtUnit._canon(g))
	var ms: Array = []
	for m: Dictionary in mods:
		ms.append(RtUnit._canon(m))
	d.merge({
		"cell": [cell.x, cell.y], "room_kind": room_kind, "geo": RtUnit._canon(geo), "units": us, "groups": gs,
		"controlled_id": controlled_id, "presets": RtUnit._canon(presets), "auto_attack": auto_attack,
		"auto_retarget": auto_retarget, "rt_opener": RtUnit._canon(rt_opener), "mods": ms,
		"rules": RtUnit._canon(rules), "difficulty": String(difficulty), "tutorial_steps": Array(tutorial_steps),
	}, true)
	return d
