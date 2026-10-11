extends Node
## CombatDirector double for the R3 HUD tests and captures (07 §12.2: submit / pause_for_hint / resume /
## unit_position). Private fixture (no class_name). submit() hands the command to the sim with the ct the HUD gave
## it; pause_for_hint holds advance() until resume() — the R2 director does the same with real ticks (hint card =
## no tick, 07 §2.13) and records Game.combat_hint at the held ct.

var sim: RtSim = null
var submitted: Array[Dictionary] = []      # commands in submit order
var answers: PackedStringArray = []        # sim answers, same order
var hints: Array[Dictionary] = []          # {"id", "ct"} of every pause_for_hint
var paused: bool = false
var resumes: int = 0
var positions: Dictionary = {}             # unit id → world position (Vector3); missing → origin + sim cm / 100
var origin: Vector3 = Vector3.ZERO
var heights: Dictionary = {}               # unit id → head height in m (captures: the rig's height)
## The HUD (on_event) that advance() feeds with the events of every tick.
var hud: Node = null
## Every event advance() produced (the real sim's stream; the HudSim double produces none).
var events: Array[ActionEvent] = []


func submit(cmd: Dictionary) -> void:
	submitted.append(cmd.duplicate(true))
	answers.append(sim.submit(cmd) if sim != null else "")


func pause_for_hint(id: String) -> void:
	paused = true
	hints.append({"id": id, "ct": sim.tick() if sim != null else 0})


func resume() -> void:
	paused = false
	resumes += 1


func unit_position(unit_id: String) -> Vector3:
	if positions.has(unit_id):
		return positions[unit_id] as Vector3
	var u: RtUnit = sim.unit(unit_id) if sim != null else null
	return origin + (Vector3(float(u.x) / 100.0, 0.0, float(u.z) / 100.0) if u != null else Vector3.ZERO)


## Head height for plates and combat text (the R2 director may offer the same from its puppets).
func unit_height(unit_id: String) -> float:
	if heights.has(unit_id):
		return float(heights[unit_id])
	var u: RtUnit = sim.unit(unit_id) if sim != null else null
	return clampf(float(u.radius) * 0.032, 0.8, 3.4) if u != null else 1.4


## `n` ticks — none while a hint card holds the combat. Returns how many passed.
func advance(n: int) -> int:
	var done: int = 0
	for i in n:
		if paused or sim == null or sim.is_finished():
			break
		var evs: Array[ActionEvent] = sim.step()
		done += 1
		events.append_array(evs)
		if hud != null:
			for e: ActionEvent in evs:
				hud.call("on_event", e)
	return done
