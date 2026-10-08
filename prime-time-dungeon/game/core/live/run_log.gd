class_name RunLog extends RefCounted
## Seed + commands + ticks of one run (Brief §6b.3, 05 §10.6). Recorded by Game.record (live) or RunSim (headless),
## replayed by Game.replay_log / RunSim.replay.
##
## {"header": {...}, "frames": [], "pos": [[tick, x_dm, y_dm, z_dm], …], "cmds": [{"k", "id", "c"}, …],
##  "checkpoints": [{"k", "h"}, …], "result": {"cause", "score", "final_hash"}}
## - k = sim tick (explore ticks in timer_mode explore_only; battle commands carry the k of their encounter).
## - Commands stay in tick order: a command with a smaller k than the previous one is rejected.
## - id = cmd_id: 0 for external inputs (Command.is_external: gift, twist) and only for them, else strictly increasing
##   from 1; a repeated or decreasing id (duplicate) or a player command with id 0 is rejected. Rejections are counted
##   in `rejected` and warned, never applied (RunSim.replay reports them as errors).
## - Checkpoint k = state hash after all commands with k' <= k (one per tick; a later hash for the same k replaces it).
## - Everything is stored normalized (integral floats → int, StringName → String), so to_dict()/from_dict() and a JSON
##   round trip keep digest() stable.

const SCHEMA: int = 1
const POS_MIN_INTERVAL: int = 15     # 2 Hz position samples at 30 ticks/s (grade A)

var header: Dictionary = {}
var frames: Array = []               # grade B input frames (05 §3.3); empty in the slice
var result: Dictionary = {}          # {"cause", "score", "final_hash"} when the run is over
var rejected: int = 0                # add_cmd / add_checkpoint calls that were refused

var _cmds: Array[Dictionary] = []
var _pos: Array = []
var _checkpoints: Array[Dictionary] = []
var _last_id: int = 0


func add_cmd(tick: int, cmd: Dictionary, cmd_id: int = 0) -> void:
	if tick < 0 or (not _cmds.is_empty() and tick < int(_cmds.back()["k"])):
		_reject("command '%s' at tick %d is out of tick order" % [str(cmd.get("t", "")), tick])
		return
	if cmd_id < 0 or (cmd_id > 0 and cmd_id <= _last_id):
		_reject("cmd_id %d is not strictly increasing (last %d)" % [cmd_id, _last_id])
		return
	var id_err: String = _id_rule(cmd, cmd_id)
	if id_err != "":
		_reject(id_err)
		return
	_cmds.append({"k": tick, "id": cmd_id, "c": CanonicalJson.normalize(cmd)})
	if cmd_id > 0:
		_last_id = cmd_id


## 2 Hz position samples (grade A, display/replay view only): [tick, x, y, z] in decimeters; samples closer than
## POS_MIN_INTERVAL ticks to the previous one are dropped.
func add_pos(tick: int, pos: Vector3) -> void:
	if not _pos.is_empty() and tick - int((_pos.back() as Array)[0]) < POS_MIN_INTERVAL:
		return
	_pos.append([tick, roundi(pos.x * 10.0), roundi(pos.y * 10.0), roundi(pos.z * 10.0)])


func add_checkpoint(tick: int, p_hash: String) -> void:
	if p_hash == "" or tick < 0:
		_reject("invalid checkpoint at tick %d" % tick)
		return
	if not _checkpoints.is_empty():
		var last: Dictionary = _checkpoints.back()
		if tick < int(last["k"]):
			_reject("checkpoint at tick %d is out of tick order" % tick)
			return
		if tick == int(last["k"]):
			last["h"] = p_hash
			return
	_checkpoints.append({"k": tick, "h": p_hash})


func cmds() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in _cmds:
		out.append(e.duplicate(true))
	return out


## Plain (untyped) arrays and dictionaries, JSON-ready.
func to_dict() -> Dictionary:
	var c: Array = []
	c.assign(cmds())
	var cp: Array = []
	cp.assign(checkpoints())
	return {
		"header": CanonicalJson.normalize(header),
		"frames": CanonicalJson.normalize(frames),
		"pos": _pos.duplicate(true),
		"cmds": c,
		"checkpoints": cp,
		"result": CanonicalJson.normalize(result),
	}


## Tolerant: missing parts → empty; malformed entries are skipped, out-of-order / duplicate ones are rejected like
## add_cmd (so a manipulated log cannot smuggle in a second command with the same id).
static func from_dict(d: Dictionary) -> RunLog:
	var rl: RunLog = RunLog.new()
	if d.get("header", null) is Dictionary:
		rl.header = CanonicalJson.normalize(d["header"])
	if d.get("frames", null) is Array:
		rl.frames = CanonicalJson.normalize(d["frames"])
	if d.get("result", null) is Dictionary:
		rl.result = CanonicalJson.normalize(d["result"])
	for e: Variant in _array(d.get("cmds", [])):
		if e is Dictionary and (e as Dictionary).get("c", null) is Dictionary:
			var ed: Dictionary = e
			rl.add_cmd(_int(ed.get("k", 0)), ed["c"], _int(ed.get("id", 0)))
		else:
			rl._reject("malformed command entry")
	for p: Variant in _array(d.get("pos", [])):
		if p is Array and (p as Array).size() == 4:
			var pa: Array = p
			rl._pos.append([_int(pa[0]), _int(pa[1]), _int(pa[2]), _int(pa[3])])
	for c: Variant in _array(d.get("checkpoints", [])):
		if c is Dictionary:
			rl.add_checkpoint(_int((c as Dictionary).get("k", -1)), str((c as Dictionary).get("h", "")))
	return rl


## SHA-256 over the canonical JSON of to_dict() (run_log_hash, 05 §3.3 Nr. 9); "" if not serializable.
func digest() -> String:
	return CanonicalJson.sha256_hex(to_dict())


# --- additions ----------------------------------------------------------------------------------------------------

func checkpoints() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Dictionary in _checkpoints:
		out.append(c.duplicate())
	return out


func size() -> int:
	return _cmds.size()


func last_cmd_id() -> int:
	return _last_id


## Problems of the recorded commands, "cmd <index> (k <tick>): <problem>"; [] = valid: schema (Command.validate) and
## the id rule (id 0 exactly for external inputs, player ids strictly increasing, 05 §10.6).
func validate() -> PackedStringArray:
	var out: PackedStringArray = []
	var last: int = 0
	for i in _cmds.size():
		var c: Dictionary = _cmds[i]["c"]
		var id: int = int(_cmds[i]["id"])
		var err: String = Command.validate(c)
		if err == "":
			err = _id_rule(c, id)
		if err == "" and id > 0 and id <= last:
			err = "cmd_id %d is not strictly increasing (last %d)" % [id, last]
		if id > 0:
			last = id
		if err != "":
			out.append("cmd %d (k %d): %s" % [i, int(_cmds[i]["k"]), err])
	return out


## "" or the violation of "id 0 ⇔ external input" (05 §10.6).
static func _id_rule(cmd: Dictionary, cmd_id: int) -> String:
	var external: bool = Command.is_external(cmd)
	if external and cmd_id != 0:
		return "external input '%s' must carry cmd_id 0 (got %d)" % [str(cmd.get("t", "")), cmd_id]
	if not external and cmd_id == 0:
		return "player command '%s' needs a cmd_id >= 1 (id 0 is for external inputs)" % str(cmd.get("t", ""))
	return ""


func _reject(msg: String) -> void:
	rejected += 1
	push_warning("[RunLog] rejected: " + msg)


static func _array(v: Variant) -> Array:
	return v if v is Array else []


static func _int(v: Variant) -> int:
	if typeof(v) == TYPE_INT:
		return v
	if typeof(v) == TYPE_FLOAT and is_finite(float(v)):
		return int(v)
	return -1
