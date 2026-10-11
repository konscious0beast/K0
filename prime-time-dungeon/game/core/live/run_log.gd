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
## - Echtzeitkampf (07 §10.2, R1a): a combat checkpoint {"k", "ct", "h"} (h = StateHash.of_rt) carries the combat tick
##   of the encounter at k; several share that k (every CHECKPOINT_TICKS combat ticks and the end), in ct order; a
##   state checkpoint after the combat keeps the same k. validate() also checks that the combat commands between an
##   encounter with "rt" and the next other command have non-decreasing "ct" and the k of their encounter (R5a: the
##   clock stands). walk() leaves the combat checkpoints to the combat replays of the verifiers (combat_checkpoints(),
##   RunSim.check_combat).
## - Echtzeitkampf (07 §10.3, R5a): compact() merges runs of move samples of one unit into move_batch entries for
##   storage; expand() / expanded() restore them bit for bit — the verifiers replay the expanded form.
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


## A run id unique per attempt (05 §10.4/§10.6): "run_local_<seed>_<8 hex>" — the hex part is CSPRNG metadata, never
## game logic (two attempts of the same fixed-seed event no longer share one replay file or board run_id).
static func local_run_id(run_seed: int) -> String:
	return "run_local_%d_%s" % [run_seed, Crypto.new().generate_random_bytes(4).hex_encode()]


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
		_last_id = cmd_id + _id_span(cmd) - 1           # a move_batch holds the ids id0 … id0 + n − 1 (07 §10.3)


## 2 Hz position samples (grade A, display/replay view only): [tick, x, y, z] in decimeters; samples closer than
## POS_MIN_INTERVAL ticks to the previous one are dropped.
func add_pos(tick: int, pos: Vector3) -> void:
	if not _pos.is_empty() and tick - int((_pos.back() as Array)[0]) < POS_MIN_INTERVAL:
		return
	_pos.append([tick, roundi(pos.x * 10.0), roundi(pos.y * 10.0), roundi(pos.z * 10.0)])


## ct >= 0: a combat checkpoint (Echtzeitkampf, 07 §10.2, R1a): same k as its encounter, appended after the previous
## checkpoint of that k — always (R5b: two combats at the same k may end at the same ct; the writers keep one per combat
## and ct); ct = -1: a state checkpoint (replaces a state checkpoint of the same k, follows the combat checkpoints of
## that k).
func add_checkpoint(tick: int, p_hash: String, ct: int = -1) -> void:
	if p_hash == "" or tick < 0:
		_reject("invalid checkpoint at tick %d" % tick)
		return
	if not _checkpoints.is_empty():
		var last: Dictionary = _checkpoints.back()
		if tick < int(last["k"]):
			_reject("checkpoint at tick %d is out of tick order" % tick)
			return
		# a state checkpoint again at the same tick replaces the last one; a combat checkpoint never does — two combats
		# at the same tick (the clock stands) may end at the same ct (R5b; the caller writes one per combat and ct)
		if tick == int(last["k"]) and ct < 0 and not last.has("ct"):
			last["h"] = p_hash
			return
	if ct >= 0:
		_checkpoints.append({"k": tick, "ct": ct, "h": p_hash})
	else:
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
			rl.add_checkpoint(_int((c as Dictionary).get("k", -1)), str((c as Dictionary).get("h", "")),
				_int((c as Dictionary).get("ct", -1)))
	return rl


## SHA-256 over the canonical JSON of to_dict() (05 §3.3 Nr. 9); "" if not serializable. Differs between the
## compacted and the expanded form of the same log (07 §10.3) — leaderboards bind canonical_digest().
func digest() -> String:
	return CanonicalJson.sha256_hex(to_dict())


## run_log_hash of a leaderboard entry (R5b, 07 §10.3): digest() of the EXPANDED form — the same for the live log, the
## compacted replay file (Save.save_replay) and its expansion, so the entry names the run, not its storage form.
func canonical_digest() -> String:
	return expanded().digest() if has_batches() else digest()


# --- additions ----------------------------------------------------------------------------------------------------

## THE replay iteration of both verifiers (Game.replay_log, RunSim.replay): the commands in k order; before a command
## with tick k every state checkpoint with a smaller tick goes to on_checkpoint.call(index, k_cp, hash) (the caller
## steps its clock to k_cp and compares its state hash), then advance.call(k) and apply.call(i, cmd) → the index of the
## next command to apply (i + 1, or further when a battle replay consumed follow-up commands); the remaining state
## checkpoints at the end. Combat checkpoints (07 §10.2, "ct") are skipped here — the combat replays compare them
## (combat_checkpoints(), RunSim.check_combat); `index` stays the position in checkpoints().
func walk(advance: Callable, apply: Callable, on_checkpoint: Callable) -> void:
	var cps: Array[Dictionary] = checkpoints()
	var cp: int = 0
	var i: int = 0
	while i < _cmds.size():
		var k: int = int(_cmds[i]["k"])
		while cp < cps.size() and int(cps[cp]["k"]) < k:
			if not cps[cp].has("ct"):
				on_checkpoint.call(cp, int(cps[cp]["k"]), str(cps[cp]["h"]))
			cp += 1
		advance.call(k)
		i = maxi(i + 1, int(apply.call(i, (_cmds[i]["c"] as Dictionary).duplicate(true))))
	while cp < cps.size():
		if not cps[cp].has("ct"):
			on_checkpoint.call(cp, int(cps[cp]["k"]), str(cps[cp]["h"]))
		cp += 1


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
## the id rule (id 0 exactly for external inputs, player ids strictly increasing, 05 §10.6); Echtzeitkampf (07 §10.2):
## combat commands only inside a real-time combat, at the k of its encounter, with non-decreasing ct (a gift's ct an
## integer >= 0; a move_batch with its sample cts and the id0 of its entry).
func validate() -> PackedStringArray:
	var out: PackedStringArray = []
	var last: int = 0
	var in_rt: bool = false                     # Echtzeitkampf (07 §10.2, R1a): inside a real-time combat
	var last_ct: int = -1
	var rt_k: int = -1                          # R5a: the k of the running combat's encounter (the clock stands)
	for i in _cmds.size():
		var c: Dictionary = _cmds[i]["c"]
		var id: int = int(_cmds[i]["id"])
		var err: String = Command.validate(c)
		if err == "":
			err = _id_rule(c, id)
		if err == "" and id > 0 and id <= last:
			err = "cmd_id %d is not strictly increasing (last %d)" % [id, last]
		if id > 0:
			last = id + _id_span(c) - 1
		var t: String = str(c.get("t", ""))
		if t == "encounter":
			in_rt = c.has("rt")
			last_ct = -1
			rt_k = int(_cmds[i]["k"])
		elif RtCommand.is_combat_cmd(c):
			var cts: Array[int] = _cts_of(c)
			if err == "" and not in_rt:
				err = "real-time combat command outside a real-time combat"
			elif err == "" and int(_cmds[i]["k"]) != rt_k:
				err = "combat command at k %d — its combat runs at k %d (the clock stands)" % [int(_cmds[i]["k"]), rt_k]
			elif err == "" and cts.is_empty():
				err = "ct must be an integer >= 0"
			elif err == "" and t == "move_batch" and int(c["id0"]) != id:
				err = "move_batch id0 %d must be the entry's id %d" % [int(c["id0"]), id]
			elif err == "" and cts[0] < last_ct:
				err = "ct %d is out of order (last %d)" % [cts[0], last_ct]
			for ct: int in cts:
				last_ct = maxi(last_ct, ct)
		elif t != "combat_speed":
			in_rt = false
		if err != "":
			out.append("cmd %d (k %d): %s" % [i, int(_cmds[i]["k"]), err])
	return out


# --- Echtzeitkampf (07 §10.3, R5a) ------------------------------------------------------------------------------------

## Merges every run of at least two consecutive move_sample entries of one unit — nothing else in between, the same k,
## the ids id, id + 1, …, ct not falling, exactly the recorded shape {t, ct, u, p} (RtCommand.move) — into one entry
## with the id id0 of its first sample: {"t": "move_batch", "u", "id0", "s": [[ct, x, z, vx, vz, yaw], [dct, …], …]}
## (the first row carries the ct of the first sample, every further row the difference to the previous one). For
## stored logs only (07 §10.3: ≈ 60–70 % of the combat entries are samples); live streams and the verifiers use the
## expanded form. digest() differs, the hashes of the run do not.
func compact() -> void:
	var out: Array[Dictionary] = []
	var i: int = 0
	while i < _cmds.size():
		var j: int = i + 1
		if _batchable(_cmds[i]):
			while j < _cmds.size() and _continues(_cmds[j - 1], _cmds[j]):
				j += 1
		if j - i >= 2:
			out.append(_batch(i, j))
		else:
			out.append(_cmds[i])
		i = j
	_cmds = out


## Restores every well-formed move_batch (schema, id0 = the entry's id) to its move_sample entries bit for bit
## (ids id0, id0 + 1, …; ct summed up); a malformed one stays and validate() reports it.
func expand() -> void:
	var out: Array[Dictionary] = []
	for e: Dictionary in _cmds:
		var c: Dictionary = e["c"]
		if str(c.get("t", "")) != "move_batch" or RtCommand.validate(c) != "" or int(c["id0"]) != int(e["id"]):
			out.append(e)
			continue
		var ct: int = 0
		var id: int = int(e["id"])
		for row: Variant in (c["s"] as Array):
			var r: Array = row
			ct += int(r[0])
			out.append({"k": int(e["k"]), "id": id, "c": {"t": "move_sample", "ct": ct, "u": str(c["u"]),
				"p": [int(r[1]), int(r[2]), int(r[3]), int(r[4]), int(r[5])]}})
			id += 1
	_cmds = out


## A copy with every move_batch expanded (the verifiers replay this form; the stored log stays as it is). `rejected`
## carries over.
func expanded() -> RunLog:
	var rl: RunLog = RunLog.from_dict(to_dict())
	rl.rejected += rejected
	rl.expand()
	return rl


## True when the log holds move_batch entries (compact() was applied).
func has_batches() -> bool:
	for e: Dictionary in _cmds:
		if str((e["c"] as Dictionary).get("t", "")) == "move_batch":
			return true
	return false


## The combat checkpoints {"i" (index in checkpoints()), "k", "ct", "h"} in log order (07 §10.2) — compared by the
## combat replays of both verifiers (RunSim.expect_combat_checkpoints / check_combat), never by walk().
func combat_checkpoints() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in _checkpoints.size():
		var cp: Dictionary = _checkpoints[i]
		if cp.has("ct"):
			out.append({"i": i, "k": int(cp["k"]), "ct": int(cp["ct"]), "h": str(cp["h"])})
	return out


## Ids an entry holds: n for a move_batch of n samples, else 1.
static func _id_span(c: Dictionary) -> int:
	if str(c.get("t", "")) == "move_batch" and c.get("s", null) is Array:
		return maxi(1, (c["s"] as Array).size())
	return 1


## The combat ticks of a combat entry: [ct] (types with ct, a gift with an integral ct >= 0), the sample cts of a
## well-formed move_batch; [] when it has none.
static func _cts_of(c: Dictionary) -> Array[int]:
	var out: Array[int] = []
	if str(c.get("t", "")) == "move_batch":
		if RtCommand.validate(c) == "":
			var ct: int = 0
			for row: Variant in (c["s"] as Array):
				ct += int((row as Array)[0])
				out.append(ct)
		return out
	var v: Variant = c.get("ct", null)
	if JsonUtil.is_integral(v) and int(v) >= 0:
		out.append(int(v))
	return out


## A move_sample entry of exactly the recorded shape (RtCommand.move) with a player id.
static func _batchable(e: Dictionary) -> bool:
	var c: Dictionary = e["c"]
	if int(e["id"]) <= 0 or str(c.get("t", "")) != "move_sample" or c.size() != 4:
		return false
	for key: String in ["t", "ct", "u", "p"]:
		if not c.has(key):
			return false
	return RtCommand.validate(c) == ""


## `b` continues the sample run ending with `a`: same k and unit, the next id, ct not falling.
static func _continues(a: Dictionary, b: Dictionary) -> bool:
	if not _batchable(b) or int(b["k"]) != int(a["k"]) or int(b["id"]) != int(a["id"]) + 1:
		return false
	var ca: Dictionary = a["c"]
	var cb: Dictionary = b["c"]
	return str(cb["u"]) == str(ca["u"]) and int(cb["ct"]) >= int(ca["ct"])


## The move_batch entry of the samples [i, j).
func _batch(i: int, j: int) -> Dictionary:
	var first: Dictionary = _cmds[i]
	var rows: Array = []
	var prev: int = 0
	for n in range(i, j):
		var c: Dictionary = _cmds[n]["c"]
		var p: Array = c["p"]
		rows.append([int(c["ct"]) - prev, int(p[0]), int(p[1]), int(p[2]), int(p[3]), int(p[4])])
		prev = int(c["ct"])
	return {"k": int(first["k"]), "id": int(first["id"]), "c": {"t": "move_batch",
		"u": str((first["c"] as Dictionary)["u"]), "id0": int(first["id"]), "s": rows}}


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
