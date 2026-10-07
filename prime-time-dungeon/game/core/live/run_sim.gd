# STUB(M0) — owned by M8. Replace completely, keep the public API.
class_name RunSim extends RefCounted
## Deterministic exploration clock in ticks (02_TECH §7.1; thin variant 05 CR-6). No autoloads, no SceneTree.
## Phase B requirement: the timer logic of step() (without it no countdown runs).


func _init(p_data: GameData, p_state: GameState, p_rules: Dictionary) -> void:
	pass


## n ticks; per tick: 1 timer (TIMER_SECOND/TIMER_WARNING/TIMER_EXPIRED), 2 every 30 ticks EXPLORE_TICK,
## 3 hype decay (HYPE), 4 stray spawners (STRAY_DUE). See 02_TECH §7.1.
func step(n: int) -> Array[ExploreEvent]:
	return []


## M8 replay of recorded explore commands.
func apply(cmd: Dictionary) -> Array[ExploreEvent]:
	return []


## Ticks since run start.
func tick() -> int:
	return 0
