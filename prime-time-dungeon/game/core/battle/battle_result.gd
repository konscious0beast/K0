# STUB(M0) — owned by M1. Replace completely, keep the public API.
class_name BattleResult extends RefCounted
## Battle outcome (02_TECH §5.4).

enum Outcome { VICTORY, DEFEAT, FLED }

var outcome: BattleResult.Outcome = Outcome.VICTORY
var encounter_id: String = ""
var group_id: String = ""
var is_boss: bool = false
var boss_id: String = ""               # EnemyDef id of the boss ("" otherwise)
var advantage: int = 0                 # BattleSetup.Advantage
var turns: int = 0                     # number of TURN_START events (all units)
var party_turns: int = 0               # TURN_START of party members
var exp: int = 0                       # sum of exp_reward of defeated non-summoned enemies × exp_mult (VICTORY only)
var credits: int = 0                   # sum of credit_reward (incl. overkill bonus)
var overkill_credits: int = 0          # part of credits that came from overkill × 1.25
var credits_stolen: int = 0            # steal_credits total (VICTORY + refund_on_win → refunded)
var credits_delta: int = 0             # gift credits (05 CR-2)
var drops: PackedStringArray = []      # item ids rolled with battle rng at victory
var boss_rewards: Array[Dictionary] = []   # EnemyDef.boss_drops of defeated bosses ({kind, id, amount})
var party_hp: Dictionary = {}          # member def id -> int (final, KO = 0)
var party_mp: Dictionary = {}
var item_delta: Dictionary = {}        # item id -> int (negative used, positive gifts)
var kills: int = 0
var defeated_ids: PackedStringArray = []   # EnemyDef ids of defeated enemies (bestiary)
var weak_found: Dictionary = {}        # EnemyDef id -> PackedStringArray of elements that hit "weak"
var escaped: PackedStringArray = []    # EnemyDef ids that used escape
var damage_taken: int = 0              # total damage to party
var min_party_hp: int = 0              # at battle end: lowest hp among living party members
var min_party_hp_pct: float = 1.0      # at battle end: lowest hp ratio among living party members
var crits: int = 0                     # party crits
var weakness_hits: int = 0             # party hits on weak
var items_used: int = 0
var party_kos: int = 0


func to_dict() -> Dictionary:
	return {}
