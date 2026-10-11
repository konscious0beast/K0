# STUB(R1a) — owned by R1b. Replace completely, keep the public API.
class_name RtMods extends RefCounted
## Static modifiers of a real-time combat (07 §9.5): one closed list in RtSetup.mods, collected by
## BattleBridge.make_rt_setup in a fixed order (equipment → species → spec → show boss → twists), canonical, never
## changed during the combat. Vocabularies: RtVocab.MOD_OPS / MOD_UNITS / MOD_EVENTS / … The stub validates nothing and
## produces no modifiers.


## Problems of a mod list (integers only, vocabularies from RtVocab); [] = valid. Stub: [].
static func validate(_mods: Array) -> PackedStringArray:
	return PackedStringArray()


## Applies every op except "on" in list order while the setup is built. Stub: nothing.
static func apply_static(_setup: RtSetup, _data: GameData) -> void:
	pass


## Reactions ("on" ops) to an event of the combat. Stub: [].
static func on_event(_sim: RtSim, _e: ActionEvent) -> Array[ActionEvent]:
	var out: Array[ActionEvent] = []
	return out


## Mods of the active battle twists (GameState.flags.live.twist.active with battles_left > 0, in stored order; 07 §9.5
## table). Stub: [].
static func from_twists(_twists: Array, _data: GameData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	return out


## Mods of a show-boss encounter (EncounterDef.show_boss → stat_pm max_hp/str + shared add_rule, 07 §9.6). Stub: [].
static func from_show_boss(_enc: EncounterDef) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	return out
