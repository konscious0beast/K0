class_name BattleRewards extends RefCounted
## Rewards applied after a battle (02_TECH §6.1): filled by BattleBridge.apply_result (followers and achievements
## by the battle controller from Show.end_battle / Show.unlocked_this_battle), shown by the results screen.

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
# --- Staffeln (09 §8.2, ST1-D): only filled in a season (LevelBand.combat_exp) ---
var exp_by_member: Dictionary = {}     # member id → EXP taken (colour, catch-up / rested, cap; the rest is overtime)
var overtime: int = 0                  # "Überstunden": credits from EXP over the cap of the floor
