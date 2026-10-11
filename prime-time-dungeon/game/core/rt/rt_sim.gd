# STUB(R1a) — owned by R1b. Replace completely, keep the public API.
class_name RtSim extends RefCounted
## One real-time combat (07 §3). Deterministic: same RtSetup + same submitted commands (with ct) → same events, same
## snapshot hashes. No autoloads, no SceneTree, no clock: the caller decides when a tick passes (07 §3.3: tick
## boundary → submit → step). The stub (R1a) only counts ticks: it accepts schema-valid commands for a known unit and a
## tick that has not passed, produces no events, never finishes on its own (run_to_end stops at max_ticks) and answers
## every pure query neutrally. tests/fixtures/rt_min/fake_rt_sim.gd (FakeRtSim) plays recorded streams through this
## API for R2/R3/R5a until R1b lands.

const TICKS_PER_SEC: int = 30

var setup: RtSetup = null
var result: BattleResult = null             # set when finished

var _data: GameData = null
var _tick: int = 0
var _submitted: Array[Dictionary] = []      # accepted commands, submit order (R1b: queue per ct, applied in step 1b)


func _init(p_setup: RtSetup, p_data: GameData) -> void:
	setup = p_setup
	_data = p_data


## ct 0 prelude: BATTLE_START, ANNOUNCE, STATUS_ADDED (dazed), PHASE_CHANGE (bosses), opener queued. Stub: [].
func start() -> Array[ActionEvent]:
	var out: Array[ActionEvent] = []
	return out


## Schema + static checks (RtCommand.validate, unit exists / controllable, ct >= tick(), skill on the unit's bar /
## unlocked); "" = queued for cmd.ct, else one of RtCommand.REASONS. Stub: schema, finished, past tick, unknown unit.
func submit(cmd: Dictionary) -> String:
	if is_finished():
		return "finished"
	if RtCommand.validate(cmd) != "":
		return "schema"
	if cmd.has("ct") and int(cmd["ct"]) < _tick:
		return "past_tick"
	if cmd.has("u") and unit(str(cmd["u"])) == null:
		return "unknown_unit"
	if str(cmd.get("t", "")) == "move_input":
		return "grade_b"
	_submitted.append(cmd.duplicate(true))
	return ""


## Processes tick() and returns its events (07 §3.3). Stub: the tick passes without events.
func step() -> Array[ActionEvent]:
	var out: Array[ActionEvent] = []
	if not is_finished():
		_tick += 1
	return out


## Index of the next tick to process (= processed ticks).
func tick() -> int:
	return _tick


func is_finished() -> bool:
	return result != null


## Controlled unit id (may change on KO, CONTROL_CHANGED). Stub: the setup's.
func controlled_id() -> String:
	return setup.controlled_id if setup != null else ""


## null if unknown.
func unit(id: String) -> RtUnit:
	if setup == null:
		return null
	for u: RtUnit in setup.units:
		if u.id == id:
			return u
	return null


## Stable order (§3.3); read-only for callers.
func units() -> Array[RtUnit]:
	var out: Array[RtUnit] = []
	if setup != null:
		out.assign(setup.units)
	return out


## Active telegraphs and zones, creation order; read-only. Stub: [].
func telegraphs() -> Array[RtTelegraph]:
	var out: Array[RtTelegraph] = []
	return out


## A gift at a tick boundary (before step), 07 §9.2. Stub: [].
func apply_gift(_g: Dictionary) -> Array[ActionEvent]:
	var out: Array[ActionEvent] = []
	return out


## Headless: step until finished or max_ticks (RunSim, harness).
func run_to_end(max_ticks: int) -> Array[ActionEvent]:
	var out: Array[ActionEvent] = []
	var n: int = 0
	while not is_finished() and n < max_ticks:
		out.append_array(step())
		n += 1
	return out


## Canonical, complete (StateHash.of_rt, 07 §10.4). Stub: tick, controlled unit, units, result.
func snapshot() -> Dictionary:
	var us: Array = []
	for u: RtUnit in units():
		us.append(u.snapshot())
	return {"ct": _tick, "controlled_id": controlled_id(), "units": us, "telegraphs": [],
		"finished": is_finished(), "result": result.to_dict() if result != null else {}}


# --- pure queries: no RNG draw, no state change, no events (test_r1_rt_pure) -----------------------------------------

## "" or a refusal reason (HUD states). Stub: "not_available".
func can_use(_unit_id: String, _skill_id: String, _target_id: String) -> String:
	return "not_available"


func can_use_item(_unit_id: String, _item_id: String, _target_id: String) -> String:
	return "not_available"


## Assist (§5.6): skill id of the next suggested ability or "". Stub: "".
func suggest(_unit_id: String) -> String:
	return ""


## Slot (1..6) → skill/item id shown right now (FINALE, context variants, potion pick). Stub: {}.
func bar(_unit_id: String) -> Dictionary:
	return {}


## Skill the Partner-Spezial would order now ("" = none). Stub: "".
func partner_special_skill(_unit_id: String) -> String:
	return ""


## Ticks (SHOW/FINALE: party-shared "show" cooldown). Stub: 0.
func cooldown_left(_unit_id: String, _skill_id: String) -> int:
	return 0


## Length of the running cooldown in ticks (0 = none). Stub: 0.
func cooldown_total(_unit_id: String, _skill_id: String) -> int:
	return 0


func gcd_left(_unit_id: String) -> int:
	return 0


func gcd_total(_unit_id: String) -> int:
	return 0


## (elapsed, total) ticks; (0, 0) = no cast.
func cast_progress(_unit_id: String) -> Vector2i:
	return Vector2i.ZERO


## Party-shared consumable cooldown (§3.11).
func item_cd_left() -> int:
	return 0


func item_cd_total() -> int:
	return 0


## Consumables still allowed in this combat (0..3). Stub: 0.
func items_left() -> int:
	return 0
