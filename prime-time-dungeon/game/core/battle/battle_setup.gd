# STUB(M0) — owned by M1. Replace completely, keep the public API.
class_name BattleSetup extends RefCounted
## Input for one battle (02_TECH §5.4).

enum Advantage { NORMAL, PREEMPTIVE, AMBUSH }

var encounter_id: String = ""
var group_id: String = ""                    # exploration group ("" for forced/debug)
var enemy_ids: PackedStringArray = []        # 1..4 EnemyDef ids, slot order
var party: Array[Combatant] = []             # built by BattleBridge, ids p0.., current hp/mp, start statuses applied
var items: Dictionary = {}                   # item_id -> count (battle-usable consumables)
var credits_available: int = 0               # party credits (limit for steal_credits)
var advantage: BattleSetup.Advantage = Advantage.NORMAL
var seed: int = 1
var is_boss: bool = false
var can_flee: bool = true
var tutorial: bool = false                   # enemy damage × 0.5, flee locked, party HP never below 1
var enemy_dmg_mult: float = 1.0              # Vorabendprogramm 0.75 × tutorial 0.5
var exp_mult: float = 1.0                    # Vorabendprogramm 1.2
var show_mods: Dictionary = {"hype_gain_mult": 1.0, "follower_mult": 1.0}   # product over equipped items
var theme_id: String = "metro"
var palette: Dictionary = {}
var floor_index: int = 1
var auto_battle: bool = false
