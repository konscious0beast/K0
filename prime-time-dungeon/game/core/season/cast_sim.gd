# STUB(ST0) — owned by 09-ST1-F. Replace completely, keep the public API.
class_name CastSim extends RefCounted
## The AI candidates (09 §4): the population model (calendar or "follows you"), events, ranking, the command "cast"
## (hire, trade, help). Static and pure (core): no autoloads, integer math, randomness only from the SeedUtil stream
## "cast" of the season seed (per place and hour).
## ST0 (contract pass): RunRules.season_refusal asks refusal() only with a season (state.season != null) — every
## command is refused with UNAVAILABLE; apply() changes nothing.

const UNAVAILABLE: String = "season_unavailable"


## "" or why the command `c` ("cast") is refused now. ST0: always UNAVAILABLE.
static func refusal(_state: GameState, _data: GameData, _c: Dictionary) -> String:
	return UNAVAILABLE


## Applies an accepted command (refusal == ""); the explore events it causes. ST0: nothing.
static func apply(_state: GameState, _data: GameData, _c: Dictionary) -> Array[ExploreEvent]:
	var out: Array[ExploreEvent] = []
	return out
