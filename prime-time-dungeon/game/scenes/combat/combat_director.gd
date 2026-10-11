# STUB(R1a) — owned by R2. Replace completely, keep the public API.
class_name CombatDirector extends Node
## Real-time combat in the world (07 §2, §9.2, §10.6): owns the tick loop of a running Game.combat — per tick c
## (1) Game.combat_boundary(), (2) the MoveSampler sample and every input with ct == c via Game.combat_submit(cmd),
## (3) Game.combat_step() — plus puppets, set ring, telegraph layer, boss intro, flight, doors, camera, control switch.
## No signals of its own: start, events and end go through Events.combat_started / combat_event / combat_finished.
## Stub: no combat runs, every call is a no-op.


## An input of the controlled player for the current tick (ct = Game.combat.tick()); the director hands it to
## Game.combat_submit in step (2) of that tick. Stub: ignored.
func submit(_cmd: Dictionary) -> void:
	pass


## Shows hint card `id` (07 §2.13): records it via Game.combat_hint and stops the ticks until resume(). Stub: nothing.
func pause_for_hint(_id: String) -> void:
	pass


## Continues the ticks after a hint card. Stub: nothing.
func resume() -> void:
	pass


## World position of the body or puppet of `unit_id` (interpolated, for plates and combat text). Stub: Vector3.ZERO.
func unit_position(_unit_id: String) -> Vector3:
	return Vector3.ZERO
