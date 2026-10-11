extends RtSim
## Controllable RtSim double of the R3 HUD tests and captures (07 §12.5 R3). Private fixture (no class_name): load it
## with preload. Units are RtUnit objects built through the public API (RtUnit.from_snapshot); every pure query of
## 07 §3.4 answers from the tables below (default: ready, no cooldown, no cast), so a test sets exactly the state it
## checks and the HUD reads it the way it reads the real sim. submit() keeps the contract's checks (schema, finished,
## past tick, unknown unit) and logs every command; nothing a command does changes the state — tests do that.
## Against the real sim (R1b-I1) the same HUD code reads RtSim; see the R3 report for what still needs it.

const TPS: int = 30

var reasons: Dictionary = {}               # "unit|skill" (or "unit|item") → can_use / can_use_item answer
var bars: Dictionary = {}                  # unit id → {slot: id}; missing → the unit's RtUnit.bar
var cds: Dictionary = {}                   # "unit|skill" → Vector2i(left, total) in ticks
var gcds: Dictionary = {}                  # unit id → Vector2i(left, total)
var suggestions: Dictionary = {}           # unit id → skill id (assist)
var specials: Dictionary = {}              # partner unit id → Partner-Spezial skill id
var item_cd: Vector2i = Vector2i.ZERO
var items_count: int = 3                   # items_left() (the parent's `items` is the battle inventory)
var commands: Array[Dictionary] = []       # every submit: {"tick", "cmd", "answer"}

var _units: Array[RtUnit] = []
var _now: int = 0                          # tick(); the controlled id is the parent's _ctl


func _init(p_setup: RtSetup, p_data: GameData) -> void:
	super(p_setup, p_data)
	_units.assign(p_setup.units)
	_ctl = p_setup.controlled_id


# --- state ------------------------------------------------------------------------------------------------------

func set_tick(t: int) -> void:
	_now = t


func set_controlled(id: String) -> void:
	_ctl = id


func add_unit(u: RtUnit) -> void:
	_units.append(u)


func finish(outcome: BattleResult.Outcome) -> void:
	result = BattleResult.new()
	result.outcome = outcome


func set_cd(unit_id: String, skill_id: String, left: int, total: int) -> void:
	cds[unit_id + "|" + skill_id] = Vector2i(left, total)


func set_reason(unit_id: String, id: String, reason: String) -> void:
	reasons[unit_id + "|" + id] = reason


## Starts a cast of `skill_id` on unit `id` that began `elapsed` ticks ago and lasts `total` ticks.
func set_cast(id: String, skill_id: String, elapsed: int, total: int, worthy: bool = false,
		interruptible: bool = true, target: String = "") -> void:
	var u: RtUnit = unit(id)
	if u == null:
		return
	u.cast = {"skill": skill_id, "target": target, "start": _now - elapsed, "end": _now - elapsed + total,
		"interruptible": interruptible, "worthy": worthy, "channel": false, "kind": "ability"}


# --- RtSim API ----------------------------------------------------------------------------------------------------

func tick() -> int:
	return _now


func step() -> Array[ActionEvent]:
	var out: Array[ActionEvent] = []
	if not is_finished():
		_now += 1
	return out


func submit(cmd: Dictionary) -> String:
	var answer: String = ""
	if is_finished():
		answer = "finished"
	elif RtCommand.validate(cmd) != "":
		answer = "schema"
	elif cmd.has("ct") and int(cmd["ct"]) < _now:
		answer = "past_tick"
	elif cmd.has("u") and unit(str(cmd["u"])) == null:
		answer = "unknown_unit"
	commands.append({"tick": _now, "cmd": cmd.duplicate(true), "answer": answer})
	return answer


func controlled_id() -> String:
	return _ctl


func unit(id: String) -> RtUnit:
	for u: RtUnit in _units:
		if u.id == id:
			return u
	return null


func units() -> Array[RtUnit]:
	return _units.duplicate()


func can_use(unit_id: String, skill_id: String, _target_id: String) -> String:
	var u: RtUnit = unit(unit_id)
	if u == null:
		return "unknown_unit"
	if u.hp <= 0:
		return "dead"
	return str(reasons.get(unit_id + "|" + skill_id, ""))


func can_use_item(unit_id: String, item_id: String, target_id: String) -> String:
	return can_use(unit_id, item_id, target_id)


func suggest(unit_id: String) -> String:
	return str(suggestions.get(unit_id, ""))


func bar(unit_id: String) -> Dictionary:
	if bars.has(unit_id):
		return (bars[unit_id] as Dictionary).duplicate()
	var u: RtUnit = unit(unit_id)
	return u.bar.duplicate() if u != null else {}


func partner_special_skill(unit_id: String) -> String:
	return str(specials.get(unit_id, ""))


func cooldown_left(unit_id: String, skill_id: String) -> int:
	return (cds.get(unit_id + "|" + skill_id, Vector2i.ZERO) as Vector2i).x


func cooldown_total(unit_id: String, skill_id: String) -> int:
	return (cds.get(unit_id + "|" + skill_id, Vector2i.ZERO) as Vector2i).y


func gcd_left(unit_id: String) -> int:
	return (gcds.get(unit_id, Vector2i.ZERO) as Vector2i).x


func gcd_total(unit_id: String) -> int:
	return (gcds.get(unit_id, Vector2i.ZERO) as Vector2i).y


func cast_progress(unit_id: String) -> Vector2i:
	var u: RtUnit = unit(unit_id)
	if u == null or u.cast.is_empty():
		return Vector2i.ZERO
	var s: int = int(u.cast.get("start", 0))
	var e: int = int(u.cast.get("end", 0))
	return Vector2i(clampi(_now - s, 0, maxi(0, e - s)), maxi(0, e - s))


func item_cd_left() -> int:
	return item_cd.x


func item_cd_total() -> int:
	return item_cd.y


func items_left() -> int:
	return items_count


func snapshot() -> Dictionary:
	var us: Array = []
	for u: RtUnit in _units:
		us.append(u.snapshot())
	return {"ct": _now, "controlled_id": _ctl, "units": us, "telegraphs": [], "finished": is_finished(),
		"result": result.to_dict() if result != null else {}}
