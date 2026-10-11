class_name ShowDelta extends RefCounted
## Show effect of one ActionEvent / battle phase (02_TECH §6.1). Produced by ShowRules, applied by the Show autoload:
## stats first (counters before the trigger of the same event, GDD §8), then hype, then triggers, then M.O.D. lines.
##
## `hype` is the net raw sum (02_TECH §6.1). `hype_gain` / `hype_loss` keep its positive and negative parts apart
## (hype == hype_gain + hype_loss), because only the positive events are multiplied by hype_gain_mult (GDD §7.3):
## a mixed action (variety +3 and drag −3) must not cancel out before the multiplier is applied.

var hype: float = 0.0                        # raw net (before hype_gain_mult)
var hype_gain: float = 0.0                   # sum of the positive parts (raw, ≥ 0)
var hype_loss: float = 0.0                   # sum of the negative parts (≤ 0, never multiplied)
var stats: Dictionary = {}                   # StatIds → increment
var reasons: Array[StringName] = []          # &"crit", &"weakness", &"overkill", &"kill_streak", … → M.O.D./chat tags
var triggers: Array[Dictionary] = []         # [{"trigger": "enemy_killed", "payload": {...}}, …] (§6.3)
