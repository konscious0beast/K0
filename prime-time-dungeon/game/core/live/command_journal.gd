class_name CommandJournal extends RefCounted
## The command journal of a season slot (09 §9.1, V-3; ST1-B) — the line format and its reading, no file I/O (Save
## writes and reads user://saves/slot_N.journal). A season saves at fixed moments; in between the journal holds every
## recorded command, one line each, written and flushed BEFORE the command acts (Game.record → Save.journal_append), so
## a crash or a closed app loses nothing. The next save starts a new journal.
##
## Line 1 is the header {"journal": VERSION, "id": the journal id of the save it continues (Save writes the same id into
## the slot file), "k0": the sim tick of that save}; every further line {"k": ticks since the save, "c": the command}
## (canonical JSON, no line breaks inside). Reading drops a torn last line (no line end, or not parsable — the app died
## while writing it); a broken line before the end stops the journal there ("bad"). The journal is replayed from the
## loaded save through Game.replay_log's engine (GameReplay.resume): to_run_log builds that log; a combat the journal
## ends in (open_combat) is decided from its start by the autopilot — the inputs made so far do not count (09 §9.1:
## whoever closes the app in a combat gains nothing and loses nothing but their own control).

const VERSION: int = 1


## The header line of a journal that continues the save with journal id `id`, written at sim tick `k0`.
static func header_line(id: String, k0: int) -> String:
	return CanonicalJson.stringify({"journal": VERSION, "id": id, "k0": maxi(0, k0)})


## One entry line: command `cmd` at `k` ticks after the save.
static func line(k: int, cmd: Dictionary) -> String:
	return CanonicalJson.stringify({"k": maxi(0, k), "c": CanonicalJson.normalize(cmd)})


## {"header": Dictionary ({} without a valid one), "entries": Array[Dictionary] ({"k": int, "c": Dictionary} in file
## order), "torn": bool (a torn last line was dropped), "bad": int (the lines dropped from a broken line on)}.
static func parse(text: String) -> Dictionary:
	var entries: Array[Dictionary] = []
	var out: Dictionary = {"header": {}, "entries": entries, "torn": false, "bad": 0}
	if text == "":
		return out
	var lines: PackedStringArray = text.split("\n")
	var complete: bool = text.ends_with("\n")
	if complete:
		lines.remove_at(lines.size() - 1)            # the empty piece after the last line end
	var json: JSON = JSON.new()
	for i in lines.size():
		var last: bool = i == lines.size() - 1
		var v: Variant = json.data if lines[i] != "" and json.parse(lines[i]) == OK else null
		var ok: bool = v is Dictionary and (not last or complete)
		if ok and i == 0:
			ok = _is_header(v)
			if ok:
				out["header"] = CanonicalJson.normalize(v)
				continue
		elif ok:
			ok = (v as Dictionary).get("c", null) is Dictionary and JsonUtil.is_integral((v as Dictionary).get("k"))
		if not ok:
			if last:
				out["torn"] = true
			else:
				out["bad"] = lines.size() - i
			break
		entries.append({"k": maxi(0, JsonUtil.to_int((v as Dictionary)["k"])),
			"c": CanonicalJson.normalize((v as Dictionary)["c"])})
	return out


## The index of the encounter whose combat the journal ends in (an "encounter" followed only by combat entries,
## RtCommand.is_combat_cmd); -1 when the journal does not end inside a combat. The save after every combat (Game) starts
## a new journal, so such a combat was still running when the app went away.
static func open_combat(entries: Array) -> int:
	for i in range(entries.size() - 1, -1, -1):
		var c: Dictionary = (entries[i] as Dictionary).get("c", {})
		if str(c.get("t", "")) == "encounter":
			return i if c.get("rt", null) is Dictionary else -1
		if not RtCommand.is_combat_cmd(c):
			return -1
	return -1


## The run log the journal replays as (Game.replay_log engine, GameReplay.resume): `header` (an anchored "from_save"
## header of the loaded save), the entries in order with fresh command ids (0 for external inputs), without the combat
## entries of the open combat at `open_at` (its encounter stays; the autopilot plays it).
static func to_run_log(header: Dictionary, entries: Array, open_at: int = -1) -> RunLog:
	var rl: RunLog = RunLog.new()
	rl.header = header.duplicate(true)
	var next_id: int = 0
	for i in entries.size():
		if open_at >= 0 and i > open_at:
			break
		var e: Dictionary = entries[i]
		var c: Dictionary = e.get("c", {})
		var id: int = 0
		if not Command.is_external(c):
			next_id += 1
			id = next_id
		rl.add_cmd(JsonUtil.to_int(e.get("k", 0)), c, id)
	return rl


static func _is_header(v: Variant) -> bool:
	if not (v is Dictionary):
		return false
	var d: Dictionary = v
	return JsonUtil.is_integral(d.get("journal")) and int(d["journal"]) == VERSION and d.get("id", null) is String \
		and JsonUtil.is_integral(d.get("k0"))
