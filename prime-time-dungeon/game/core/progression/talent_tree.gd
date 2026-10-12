# STUB(ST0) — owned by 09-ST1-D. Replace completely, keep the public API.
class_name TalentTree extends RefCounted
## The talent tree (09 §8.4): in a season it replaces the offer of talents.gd — rows on levels 3/5/7/9 (1 of 3),
## re-picking free in a safe room; the command "talent" v2 {"v": 2, "member", "row", "id"}. Static and pure (core).
## ST0 (contract pass): RunRules.season_refusal asks refusal() only with a season (state.season != null) — every
## command is refused with UNAVAILABLE; apply() changes nothing.

const UNAVAILABLE: String = "season_unavailable"


## "" or why the command `c` ("talent" v2) is refused now. ST0: always UNAVAILABLE.
static func refusal(_state: GameState, _data: GameData, _c: Dictionary) -> String:
	return UNAVAILABLE


## Applies an accepted command (refusal == ""); the explore events it causes. ST0: nothing.
static func apply(_state: GameState, _data: GameData, _c: Dictionary) -> Array[ExploreEvent]:
	var out: Array[ExploreEvent] = []
	return out
