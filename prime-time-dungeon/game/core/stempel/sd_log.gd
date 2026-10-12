class_name SdLog extends RefCounted
## Duel log of a Stempelduell (10 §6.6): the setup and only the player's moves — the opponent's moves are recomputed
## on replay (EnemyAI on its hand with the engine's "ai" stream, like the CTB replays, 05 CR-2) — plus the result and
## the final state_hash. Namen, Persona und Kosmetik stehen nie im Log.
##   {"v": 1, "sd_version": 1, "rh": "<rules_hash>", "seed": "1234567", "opp": "sdo_ulla", "tut": false,
##    "deck": ["sdc_…", …], "moves": [{"op": "play", "slot": 2}, {"op": "file", "slot": 4},
##    {"op": "play", "slot": 0, "a": true}], "res": "won", "h": "<state_hash at the end>"}
## `a: true` marks auto moves (statistics only). "h" is an addition to the format of 10 §6.6: with it, replay() also
## catches a forged move that keeps the result.
## Versions: a log of another SD_VERSION (or log format) or other rules is not replayed — version_status() names it
## (old_version / new_version / other_rules), like RunSim.version_status for the campaign.

const LOG_VERSION: int = 1
const OK: String = "ok"
const OLD_VERSION: String = "old_version"
const NEW_VERSION: String = "new_version"
const OTHER_RULES: String = "other_rules"
const MAX_STEPS: int = 4000                 # safety net; a duel ends by number 80 anyway

var setup: SdSetup = null
var moves: Array[Dictionary] = []
var result: String = ""                     # SdDuel.RESULT_NAMES entry ("" while the duel runs)
var final_hash: String = ""
var sd_version: int = SdDuel.SD_VERSION
var log_version: int = LOG_VERSION


static func begin(p_setup: SdSetup) -> SdLog:
	var l: SdLog = SdLog.new()
	l.setup = p_setup
	return l


## Records a submitted player move: {"op", "slot"} (+ "a": true for an auto move; the hint and other extras are
## dropped). Opponent moves are never recorded.
func add(move: Dictionary, auto: bool = false) -> void:
	var m: Dictionary = {"op": str(move.get("op", ""))}
	if move.has("slot"):
		m["slot"] = JsonUtil.to_int(move["slot"])
	if auto or bool(move.get("a", false)):
		m["a"] = true
	moves.append(m)


## Closes the log with the duel's result and final hash.
func finish(duel: SdDuel) -> void:
	result = SdDuel.RESULT_NAMES[int(duel.result)]
	final_hash = duel.state_hash()


func to_dict() -> Dictionary:
	var d: Dictionary = {"v": log_version, "sd_version": sd_version, "rh": setup.rules_hash, "seed": str(setup.seed),
		"opp": setup.opponent_id, "tut": setup.tutorial, "deck": Array(setup.player_deck), "moves": moves.duplicate(true),
		"res": result}
	if final_hash != "":
		d["h"] = final_hash
	return d


## Inverse of to_dict (also after a JSON round trip); a malformed dictionary gives an empty log (replay then fails).
static func from_dict(d: Dictionary) -> SdLog:
	var l: SdLog = SdLog.new()
	l.log_version = JsonUtil.to_int(d.get("v", 0))
	l.sd_version = JsonUtil.to_int(d.get("sd_version", 0))
	l.setup = SdSetup.from_dict({"seed": d.get("seed", "1"), "opp": d.get("opp", ""), "deck": d.get("deck", []),
		"tut": d.get("tut", false), "rh": d.get("rh", "")})
	var ms: Variant = d.get("moves", [])
	for m: Variant in (ms as Array if ms is Array else []):
		if m is Dictionary:
			l.moves.append((m as Dictionary).duplicate(true))
		else:
			l.moves.append({})
	l.result = str(d.get("res", ""))
	l.final_hash = str(d.get("h", ""))
	return l


## ok | old_version | new_version | other_rules for a log dictionary and the current rulebook.
static func version_status(d: Dictionary, book: SdRulebook) -> String:
	var lv: int = JsonUtil.to_int(d.get("v", 0))
	var sv: int = JsonUtil.to_int(d.get("sd_version", 0))
	if lv < LOG_VERSION or sv < SdDuel.SD_VERSION:
		return OLD_VERSION
	if lv > LOG_VERSION or sv > SdDuel.SD_VERSION:
		return NEW_VERSION
	if book == null or str(d.get("rh", "")) != book.rules_hash:
		return OTHER_RULES
	return OK


## Replays the log bit-exactly: {"ok": bool, "version": version_status, "result": String, "hash": String,
## "error": String ("" if ok), "mismatch_at": index of the first bad move (-1: none)}. A move the duel refuses, moves
## after the end, a log that ends before the duel, another result than "res" or another final hash than "h" are
## errors; a log of another version or rules is not replayed at all.
func replay(book: SdRulebook) -> Dictionary:
	var out: Dictionary = {"ok": false, "version": version_status(to_dict(), book), "result": "", "hash": "",
		"error": "", "mismatch_at": -1}
	if str(out["version"]) != OK:
		out["error"] = "not replayed: %s" % str(out["version"])
		return out
	var problem: String = setup.problem(book)
	if problem != "":
		out["error"] = "bad setup: " + problem
		return out
	var duel: SdDuel = SdDuel.new(setup, book)
	duel.start()
	var i: int = 0
	var steps: int = 0
	while not duel.is_finished() and steps < MAX_STEPS:
		steps += 1
		var side: int = duel.side_to_move()
		if side == SdDuel.Side.OPPONENT:
			duel.submit(duel.opponent_move())
			continue
		if i >= moves.size():
			out["error"] = "the log ends before the duel (number %d)" % duel.ticket()
			out["mismatch_at"] = i
			return _close(out, duel)
		var reason: String = duel.validate(moves[i])
		if reason != "":
			out["error"] = "move %d refused: %s" % [i, reason]
			out["mismatch_at"] = i
			return _close(out, duel)
		duel.submit(moves[i])
		i += 1
	if i < moves.size():
		out["error"] = "%d moves after the end of the duel" % (moves.size() - i)
		out["mismatch_at"] = i
		return _close(out, duel)
	_close(out, duel)
	if str(out["result"]) != result:
		out["error"] = "result mismatch: the log says '%s', the replay gives '%s'" % [result, str(out["result"])]
		return out
	if final_hash != "" and str(out["hash"]) != final_hash:
		out["error"] = "hash mismatch at the end of the duel"
		return out
	out["ok"] = true
	return out


static func _close(out: Dictionary, duel: SdDuel) -> Dictionary:
	out["result"] = SdDuel.RESULT_NAMES[int(duel.result)]
	out["hash"] = duel.state_hash()
	return out
