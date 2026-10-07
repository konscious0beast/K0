# STUB(M0) — owned by M2. Replace completely, keep the public API.
class_name ShowDelta extends RefCounted
## Show effect of one ActionEvent / battle phase (02_TECH §6.1).

var hype: float = 0.0                        # raw (before hype_gain_mult)
var stats: Dictionary = {}                   # StatIds → increment
var reasons: Array[StringName] = []          # &"crit", &"weakness", &"overkill", &"kill_streak", &"low_hp", … → M.O.D./chat tags
var triggers: Array[Dictionary] = []         # [{"trigger": "enemy_killed", "payload": {...}}, …] (§6.3)
