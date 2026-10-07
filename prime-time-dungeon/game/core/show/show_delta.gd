class_name ShowDelta extends RefCounted
## Show effect of one ActionEvent / battle phase (02_TECH §6.1). Produced by ShowRules, applied by the Show autoload:
## stats first (counters before the trigger of the same event, GDD §8), then hype, then triggers, then M.O.D. lines.

var hype: float = 0.0                        # raw (before hype_gain_mult)
var stats: Dictionary = {}                   # StatIds → increment
var reasons: Array[StringName] = []          # &"crit", &"weakness", &"overkill", &"kill_streak", … → M.O.D./chat tags
var triggers: Array[Dictionary] = []         # [{"trigger": "enemy_killed", "payload": {...}}, …] (§6.3)
