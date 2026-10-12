# STUB(ST0) — owned by 09-ST1-B. Replace completely, keep the public API.
class_name SeasonRules extends RefCounted
## The season rules (09 §2, §7, §9.1): the "season" command (start, tempo, pause, leave), the clock ("clock") and the
## logout ("sleep" with its tactic) — staircase rule from floor 4, collapses, rescue, dress rehearsal, death, Ohne-Netz
## unlock, daily programme, titles. Static and pure (core): no autoloads, integer math, randomness only from SeedUtil
## streams; the live game (Game's season facades through RunRules.apply_season) and RunSim.apply call the same
## functions.
## ST0 (contract pass): RunRules.season_refusal asks refusal() for the start of a season (no season yet) and, with
## a season (state.season != null), for its other commands — every command is refused with UNAVAILABLE (no season can
## start before ST1-B); apply() changes nothing.

const UNAVAILABLE: String = "season_unavailable"


## "" or why the command `c` ("season" (incl. its start), "clock", "sleep") is refused now. ST0: always UNAVAILABLE.
static func refusal(_state: GameState, _data: GameData, _c: Dictionary) -> String:
	return UNAVAILABLE


## Applies an accepted command (refusal == ""); the explore events it causes. ST0: nothing.
static func apply(_state: GameState, _data: GameData, _c: Dictionary) -> Array[ExploreEvent]:
	var out: Array[ExploreEvent] = []
	return out
