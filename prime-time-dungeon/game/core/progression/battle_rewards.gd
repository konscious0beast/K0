# STUB(M0) — owned by M2. Replace completely, keep the public API.
class_name BattleRewards extends RefCounted
## Rewards applied after a battle (02_TECH §6.1).

var exp: int = 0
var credits: int = 0                   # incl. overkill bonus
var overkill_credits: int = 0
var credits_refunded: int = 0          # stolen credits returned on victory
var credits_lost: int = 0              # stolen credits kept by the enemy (fled/defeat)
var items: PackedStringArray = []
var boxes: PackedStringArray = []      # boss boxes → pending_lootboxes
var level_ups: Array[LevelUpInfo] = []
var mp_regen: Dictionary = {}          # member id → MP restored by the "Werbepause"
var followers: int = 0
var revived: PackedStringArray = []
var achievements: PackedStringArray = []
