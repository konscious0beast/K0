class_name FakeRtSim extends RtSim
## Test double of RtSim (07 §12.2, R1a; R1b extends): plays a canned stream through the public RtSim API so that R2
## (world), R3 (HUD) and R5a (show / replay) can build against the contract before the real sim exists. It accepts
## commands like the stub (schema, finished, past tick, unknown unit, grade_b) and logs every one in `submitted`, but
## the stream decides what happens — commands never change it.
##
## Stream file (tests/fixtures/rt_min/streams/<name>.json, written by stream_builder.gd):
##   {"name", "notes", "setup": RtSetup.to_dict(), "ticks": [[ct, [ActionEvent.to_dict(), …], {unit_id: overlay}], …],
##    "result": BattleResult.to_dict()}
## - ct -1 is the start() prelude; every other entry is returned by step() when tick() == ct (ticks without an entry
##   return []). Ticks are strictly increasing.
## - {unit_id: overlay}: the changed keys of RtUnit.snapshot(), merged into the unit before the tick's events are
##   returned (a new unit id — a summon — brings its full snapshot).
## - Events with rt.boundary == 1 belong to the tick boundary: apply_gift(g) at that tick returns them (gifts.json);
##   step() returns the others.
## - The tick whose events contain BATTLE_END finishes the combat: result = BattleResult.from_dict(stream.result).

const STREAM_DIR: String = "res://tests/fixtures/rt_min/streams"
const DATA_DIR: String = "res://tests/fixtures/rt_min"
const STREAMS: PackedStringArray = ["regular_win", "boss_phases", "flee", "ko_control_defeat", "gifts"]
const RtNormRef := preload("res://core/data/defs/rt_norm.gd")

var stream_name: String = ""
var submitted: Array[Dictionary] = []          # {"tick", "cmd", "answer"} in call order
var gifts_applied: Array[Dictionary] = []      # {"tick", "gift"}

var _entries: Dictionary = {}                  # ct → {"events": Array (dicts), "overlays": Dictionary}
var _result: Dictionary = {}
var _snaps: Dictionary = {}                    # unit id → current snapshot (Dictionary)
var _units: Array[RtUnit] = []                 # current units, stable order (party by slot, then enemies by number)
var _controlled: String = "p0"


## The stream `name` of STREAM_DIR (null + error if it cannot be read).
static func load_stream(name: String, data: GameData) -> FakeRtSim:
	var raw: Variant = JsonUtil.read_file(STREAM_DIR.path_join(name + ".json"))
	if not (raw is Dictionary):
		push_error("FakeRtSim: cannot read stream '%s' (%s)" % [name, JsonUtil.last_error()])
		return null
	var f: FakeRtSim = FakeRtSim.new(raw, data)
	f.stream_name = name
	return f


## The fixture data (copy of data_min with rt blocks, two test enemies, a test boss, rt_balance.json).
static func load_data() -> GameData:
	var d: GameData = GameData.new()
	d.load_dir(DATA_DIR)
	return d


## RtSetup from RtSetup.to_dict() (fixture helper; the contract has no RtSetup.from_dict).
static func setup_from_dict(d: Dictionary, data: GameData) -> RtSetup:
	var s: RtSetup = RtSetup.new()
	var base: BattleSetup = BattleSetup.from_dict(d, data)
	for prop: Dictionary in base.get_property_list():
		if (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
			s.set(str(prop["name"]), base.get(str(prop["name"])))
	s.cell = JsonUtil.arr_to_vec2i(d.get("cell", [0, 0]))
	s.room_kind = JsonUtil.to_int(d.get("room_kind", 0))
	s.geo = _dict(d.get("geo", {}))
	for v: Variant in (d.get("units", []) as Array):
		if v is Dictionary:
			var u: RtUnit = RtUnit.from_snapshot(v, data)
			if u != null:
				s.units.append(u)
	for g: Variant in (d.get("groups", []) as Array):
		if g is Dictionary:
			s.groups.append(_dict(g))
	s.controlled_id = str(d.get("controlled_id", "p0"))
	s.presets = _dict(d.get("presets", {}))
	s.auto_attack = bool(d.get("auto_attack", true))
	s.auto_retarget = bool(d.get("auto_retarget", true))
	s.rt_opener = _dict(d.get("rt_opener", {}))
	for m: Variant in (d.get("mods", []) as Array):
		if m is Dictionary:
			s.mods.append(_dict(m))
	s.rules = _dict(d.get("rules", {}))
	s.difficulty = &"vorabend" if str(d.get("difficulty", "prime")) == "vorabend" else &"prime"
	s.tutorial_steps = JsonUtil.to_str_array(d.get("tutorial_steps", []))
	s.balance = RtBalance.from_data(data)
	return s


func _init(p_stream: Dictionary, p_data: GameData) -> void:
	super(setup_from_dict(p_stream.get("setup", {}) if p_stream.get("setup", null) is Dictionary else {}, p_data),
		p_data)
	stream_name = str(p_stream.get("name", ""))
	_result = _dict(p_stream.get("result", {}))
	_controlled = setup.controlled_id
	for u: RtUnit in setup.units:
		_snaps[u.id] = u.snapshot()
	for e: Variant in (p_stream.get("ticks", []) as Array):
		if e is Array and (e as Array).size() >= 2:
			var row: Array = e
			var ev: Array = row[1] if row[1] is Array else []
			var ov: Dictionary = row[2] if row.size() > 2 and row[2] is Dictionary else {}
			_entries[JsonUtil.to_int(row[0], -2)] = {"events": ev, "overlays": ov}
	_rebuild_units()


## The ct -1 prelude (BATTLE_START, ANNOUNCE, …).
func start() -> Array[ActionEvent]:
	return _play(-1, false)


func submit(cmd: Dictionary) -> String:
	var answer: String = super(cmd)
	submitted.append({"tick": tick(), "cmd": cmd.duplicate(true), "answer": answer})
	return answer


func step() -> Array[ActionEvent]:
	var out: Array[ActionEvent] = []
	if is_finished():
		return out
	var c: int = _tick
	out = _play(c, false)
	_tick = c + 1
	for e: ActionEvent in out:
		if e.type == ActionEvent.Type.BATTLE_END:
			result = BattleResult.from_dict(_result)
	return out


## The boundary events of the current tick (rt.boundary == 1) — the stream decides what a gift does.
func apply_gift(g: Dictionary) -> Array[ActionEvent]:
	gifts_applied.append({"tick": tick(), "gift": g.duplicate(true)})
	return _play(tick(), true)


func controlled_id() -> String:
	return _controlled


func unit(id: String) -> RtUnit:
	for u: RtUnit in _units:
		if u.id == id:
			return u
	return null


func units() -> Array[RtUnit]:
	return _units.duplicate()


func snapshot() -> Dictionary:
	var us: Array = []
	for u: RtUnit in _units:
		us.append(u.snapshot())
	return {"ct": _tick, "controlled_id": _controlled, "units": us, "telegraphs": [], "finished": is_finished(),
		"result": result.to_dict() if result != null else {}}


# --- pure queries from the current unit snapshots ------------------------------------------------------------------

func can_use(unit_id: String, _skill_id: String, _target_id: String) -> String:
	var u: RtUnit = unit(unit_id)
	if u == null:
		return "unknown_unit"
	return "dead" if u.hp <= 0 else ""


func can_use_item(unit_id: String, item_id: String, target_id: String) -> String:
	return can_use(unit_id, item_id, target_id)


func bar(unit_id: String) -> Dictionary:
	var u: RtUnit = unit(unit_id)
	return u.bar.duplicate() if u != null else {}


func cooldown_left(unit_id: String, skill_id: String) -> int:
	var u: RtUnit = unit(unit_id)
	if u == null or not u.cooldowns.has(skill_id):
		return 0
	return maxi(0, int((u.cooldowns[skill_id] as Array)[0]) - _tick)


func cooldown_total(unit_id: String, skill_id: String) -> int:
	var u: RtUnit = unit(unit_id)
	if u == null or not u.cooldowns.has(skill_id):
		return 0
	return int((u.cooldowns[skill_id] as Array)[1])


func gcd_left(unit_id: String) -> int:
	var u: RtUnit = unit(unit_id)
	return maxi(0, u.gcd_until - _tick) if u != null else 0


func gcd_total(unit_id: String) -> int:
	var u: RtUnit = unit(unit_id)
	return u.gcd_len if u != null else 0


func cast_progress(unit_id: String) -> Vector2i:
	var u: RtUnit = unit(unit_id)
	if u == null or u.cast.is_empty():
		return Vector2i.ZERO
	var s: int = int(u.cast.get("start", 0))
	var e: int = int(u.cast.get("end", 0))
	return Vector2i(clampi(_tick - s, 0, maxi(0, e - s)), maxi(0, e - s))


func items_left() -> int:
	return 3


# --- private --------------------------------------------------------------------------------------------------------

## Events of entry `c` (boundary ones or the others) after applying its overlays once (the step pass applies them).
func _play(c: int, boundary: bool) -> Array[ActionEvent]:
	var out: Array[ActionEvent] = []
	if not _entries.has(c):
		return out
	var entry: Dictionary = _entries[c]
	if not boundary:
		var ov: Dictionary = entry["overlays"]
		var ids: Array = ov.keys()
		ids.sort()
		for id: Variant in ids:
			var cur: Dictionary = _snaps.get(str(id), {})
			cur.merge(_dict(ov[id]), true)
			_snaps[str(id)] = cur
		if not ids.is_empty():
			_rebuild_units()
	for d: Variant in (entry["events"] as Array):
		if not (d is Dictionary):
			continue
		var is_boundary: bool = int(((d as Dictionary).get("rt", {}) as Dictionary).get("boundary", 0)) == 1
		if is_boundary != boundary:
			continue
		var e: ActionEvent = ActionEvent.from_dict(d)
		if e == null:
			continue
		if e.type == ActionEvent.Type.CONTROL_CHANGED:
			_controlled = e.target_id
		out.append(e)
	return out


func _rebuild_units() -> void:
	var ids: Array = _snaps.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return _order(str(a)) < _order(str(b)))
	var out: Array[RtUnit] = []
	for id: Variant in ids:
		var u: RtUnit = RtUnit.from_snapshot(_snaps[id], _data)
		if u != null:
			out.append(u)
	_units = out


## Party first (p0 < p1 …), then enemies by number (e0 < e1 < … e10).
static func _order(id: String) -> int:
	var n: int = id.substr(1).to_int()
	return n if id.begins_with("p") else 1000 + n


static func _dict(v: Variant) -> Dictionary:
	return RtNormRef.ints((v as Dictionary).duplicate(true)) if v is Dictionary else {}
