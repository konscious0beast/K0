# STUB(ST0) — owned by 09-ST1-E. Replace completely, keep the public API.
class_name Professions extends RefCounted
## The professions (09 §8.5, §8.6): learning (two main professions), ranks, colours and chances, gathering,
## salvaging, crafting in a safe room, the Vorleben head start (+50, persona v2) — the commands "prof", "gather",
## "craft". Static and pure (core): no autoloads, integer math, randomness only from the SeedUtil stream "prof".
## ST0 (contract pass): RunRules.season_refusal asks refusal() only with a season (state.season != null) — every
## command is refused with UNAVAILABLE; apply() changes nothing.

const UNAVAILABLE: String = "season_unavailable"


## "" or why the command `c` ("prof", "gather", "craft") is refused now. ST0: always UNAVAILABLE.
static func refusal(_state: GameState, _data: GameData, _c: Dictionary) -> String:
	return UNAVAILABLE


## Applies an accepted command (refusal == ""); the explore events it causes. ST0: nothing.
static func apply(_state: GameState, _data: GameData, _c: Dictionary) -> Array[ExploreEvent]:
	var out: Array[ExploreEvent] = []
	return out
