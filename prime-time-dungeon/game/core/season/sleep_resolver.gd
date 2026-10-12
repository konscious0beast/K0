# STUB(ST0) — owned by 09-ST1-G. Replace completely, keep the public API.
class_name SleepResolver extends RefCounted
## The sleeper (09 §5.5): the command "away" (login after an absence) resolves the time slept in the order of 09 §5.5
## — encounters (patrols and AI candidates) through RtSim headless on autopilot, emergency retreat, rested — the same
## way in the live game and RunSim.apply. Static and pure (core): no autoloads, integer math, randomness only from
## SeedUtil streams.
## ST0 (contract pass): RunRules.season_refusal asks refusal() only with a season (state.season != null) — every
## command is refused with UNAVAILABLE; apply() changes nothing.

const UNAVAILABLE: String = "season_unavailable"


## "" or why the command `c` ("away") is refused now. ST0: always UNAVAILABLE.
static func refusal(_state: GameState, _data: GameData, _c: Dictionary) -> String:
	return UNAVAILABLE


## Applies an accepted command (refusal == ""); the explore events it causes. ST0: nothing.
static func apply(_state: GameState, _data: GameData, _c: Dictionary) -> Array[ExploreEvent]:
	var out: Array[ExploreEvent] = []
	return out
