# STUB(M0) — owned by M1. Replace completely, keep the public API.
class_name Combatant extends RefCounted
## Battle participant (02_TECH §5.4).

enum Side { PARTY, ENEMY }

var id: String = ""                          # "p0".."p3" / "e0".. / "u0".. (summons continue numbering, never reused)
var def_id: String = ""                      # "kai" / "enm_kanalratte" / "pu_train_gleis9"
var side: Combatant.Side = Side.PARTY
var is_pseudo: bool = false                  # not targetable, no HP, acts via PseudoUnitDef.action, shown in CTB preview
var slot: int = 0                            # stage slot 0..3 (pseudo: -1)
var display_name: String = ""
var level: int = 1
var stats: StatBlock = null                  # incl. equipment/class (computed outside); max_hp = stats HP
var hp: int = 0
var mp: int = 0
var statuses: Array[StatusEffect] = []
var ctb_counter: int = 0
var defending: bool = false
var attack_skill: String = ""
var skills: PackedStringArray = []
var stunts: PackedStringArray = []
var stunt_cooldown: int = 0                  # own turns until STUNT is available again
var element_mods: Dictionary = {}
var status_immune: PackedStringArray = []
var status_resist: Dictionary = {}           # status id → 0..1
var attack_element: String = "physical"
var crit_bonus: float = 0.0                  # from equipment
var ai: Dictionary = {}                      # EnemyDef.ai (normalized)
var phases: Array[Dictionary] = []           # EnemyDef.phases
var phase: int = 0                           # current phase index (0-based; -1 = not yet entered)
var used_once: PackedStringArray = []        # AI actions with cond.once already used ("<phase>:<index>")
var own_turns: int = 0                       # completed own turns (turn_mod, first own turn = 0)
var is_boss: bool = false
var is_summon: bool = false                  # summoned units give no EXP/credits/drops
var exp_reward: int = 0
var credit_reward: int = 0
var drops: Array[Dictionary] = []
var boss_drops: Array[Dictionary] = []
var model: Dictionary = {}                   # ModelSpec passthrough for presentation
var last_action_key: String = ""             # "attack" / skill id / item id / "stunt" / "defend" (show variety)


static func create_enemy(def: EnemyDef, id: String, slot: int) -> Combatant:
	return null


static func create_pseudo(def: PseudoUnitDef, id: String) -> Combatant:
	return null


static func create_party(def: PartyMemberDef, id: String, slot: int, display_name: String, level: int,
		stats: StatBlock, hp: int, mp: int, skills: PackedStringArray, stunts: PackedStringArray, attack_skill: String,
		element_mods: Dictionary, status_immune: PackedStringArray, attack_element: String, crit_bonus: float) -> Combatant:
	return null


## Pseudo: true while in the order.
func is_alive() -> bool:
	return false


func is_party() -> bool:
	return false


func max_hp() -> int:
	return 0


func max_mp() -> int:
	return 0


## Effective: base × product(status stat_mult), roundi, min 1 (HP/MP unmodified).
func stat(s: StatBlock.Stat) -> int:
	return 0


func has_status(status_id: String) -> bool:
	return false


## Any active status has flag.
func has_flag(flag: String) -> bool:
	return false


func hp_ratio() -> float:
	return 0.0


## Product of tick_speed_mult of active statuses (haste 0.6 / slow 1.5).
func speed_mult() -> float:
	return 1.0


func to_dict() -> Dictionary:
	return {}


static func from_dict(d: Dictionary, data: GameData) -> Combatant:
	return null
