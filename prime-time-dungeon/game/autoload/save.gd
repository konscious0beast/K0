extends Node
## Autoload `Save` (02_TECH §3.6/§6.4): slots, file I/O, autosave, local leaderboards and replays (05 CR-8).
##
## Writes are atomic: <file>.tmp is written first, an existing <file> is moved to <file>.bak, then the tmp file is
## renamed to <file>. Loading falls back to <file>.bak when <file> is missing, unparsable or structurally invalid
## (never for a save of a newer version — that one is refused). Leaderboards / replays live next to the save
## directory: <parent of save_dir>/leaderboards/<event_id>.json and <parent of save_dir>/replays/<run_id>.json
## (default user://leaderboards, user://replays; tests redirect everything by pointing save_dir into a sub folder).
## Navigation after load_slot (credits / exploration, §6.4) is the caller's job (title / slot selection).

const SLOT_COUNT: int = 3                    # slots 1..3; slot 0 = "no slot" (debug/autoplay, never written)
const GRACE_SECONDS: int = 180               # GDD §2.9 TIMER_GRACE_ON_LOAD
const MAX_REPLAYS: int = 20
const LEADERBOARD_DIR: String = "leaderboards"
const REPLAY_DIR: String = "replays"

var save_dir: String = "user://saves"        # tests may redirect, e.g. "user://test_saves"
var read_only: bool = false                  # Autoplay: true → save calls return OK without writing

var _last_error: String = ""
var _name_re: RegEx = RegEx.create_from_string("^[A-Za-z0-9_\\-]+$")


## save_dir + "/slot_%d.json" % slot
func slot_path(slot: int) -> String:
	return save_dir + "/slot_%d.json" % slot


## A slot file (or its backup) exists. Slot 0 never has a save.
func has_save(slot: int) -> bool:
	if not _valid_slot(slot):
		return false
	var path: String = slot_path(slot)
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")


## {} empty; {"corrupt": true, "error": String} unreadable; else SaveCodec summary keys + "saved_at_unix", "slot".
func slot_summary(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}
	var loaded: Dictionary = _load_state(slot)
	if loaded.is_empty():
		return {"corrupt": true, "error": _last_error}
	var out: Dictionary = SaveCodec.summary(loaded["state"])
	out["saved_at_unix"] = int(loaded["saved_at_unix"])
	out["slot"] = slot
	return out


## Game.state → SaveCodec.encode → atomic write; emits game_saved. Slot 0 and read_only → OK without writing.
## After a successful write the target becomes the active slot (Game.state.slot, like load_slot), so autosave and
## record_game_over follow the player's last save (GDD §10.1, §2.8). `slot` is run meta data, not game logic: M8's
## StateHash has to leave it out like play_time_sec. Event runs (Game.mode != campaign, 05: slot 0) are never
## written into campaign slots → ERR_UNAVAILABLE.
func save_slot(slot: int) -> Error:
	_last_error = ""
	if slot == 0:
		return OK
	if not _valid_slot(slot):
		return _fail(ERR_INVALID_PARAMETER, "invalid slot %d" % slot)
	if not _campaign():
		Events.game_saved.emit(slot, false)
		return _fail(ERR_UNAVAILABLE, "event runs are not saved into campaign slots")
	if read_only:
		Events.game_saved.emit(slot, true)
		return OK
	if Game.state == null:
		Events.game_saved.emit(slot, false)
		return _fail(ERR_UNCONFIGURED, "no game state")
	var d: Dictionary = SaveCodec.encode(Game.state, _game_version())
	d["saved_at_unix"] = int(Time.get_unix_time_from_system())
	(d["state"] as Dictionary)["slot"] = slot
	var err: Error = _atomic_write(slot_path(slot), d)
	if err == OK:
		Game.state.slot = slot
	Events.game_saved.emit(slot, err == OK)
	return err


## read → SaveCodec.decode → Game.adopt_loaded_state(state, run log) (+ grace time_left ≥ 180 s, §6.4; Game resets its
## private run context, new sim/run_log with header like new_game + "from_save": true); emits game_loaded.
func load_slot(slot: int) -> Error:
	_last_error = ""
	if not _valid_slot(slot):
		return _fail(ERR_INVALID_PARAMETER, "invalid slot %d" % slot)
	if not has_save(slot):
		return _fail(ERR_FILE_NOT_FOUND, "no save in slot %d" % slot)
	var loaded: Dictionary = _load_state(slot)
	if loaded.is_empty():
		push_warning("[Save] load_slot(%d) failed: %s" % [slot, _last_error])
		return ERR_FILE_CORRUPT if not _last_error.begins_with(SaveCodec.MSG_NEWER) else ERR_FILE_UNRECOGNIZED
	var st: GameState = loaded["state"]
	var warnings: PackedStringArray = loaded["warnings"]
	if not warnings.is_empty():
		push_warning("[Save] slot %d loaded with corrections: %s" % [slot, "; ".join(warnings)])
	st.slot = slot
	if st.floor_run != null:
		st.floor_run.time_left_ticks = maxi(st.floor_run.time_left_ticks, GRACE_SECONDS * FloorRun.TICKS_PER_SEC)
	# Game resets its private run context (event def, finished flag, layout cache, command ids, …) and takes over the
	# state with a new run log; the live RunSim records its checkpoints into that log.
	Game.adopt_loaded_state(st, _make_run_log(st))
	Events.game_loaded.emit(slot)
	Show.sync_from_state()
	return OK


func delete_slot(slot: int) -> Error:
	_last_error = ""
	if not _valid_slot(slot):
		return _fail(ERR_INVALID_PARAMETER, "invalid slot %d" % slot)
	if read_only:
		return OK
	var path: String = slot_path(slot)
	for p: String in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(p):
			var err: Error = DirAccess.remove_absolute(p)
			if err != OK:
				return _fail(err, "cannot delete %s" % p)
	return OK


## save_slot(Game.state.slot) — the active slot (last loaded or saved); slot 0 or an event run → OK, no write.
func autosave() -> Error:
	if Game.state == null or Game.state.slot == 0 or not _campaign():
		return OK
	return save_slot(Game.state.slot)


## Slot with the latest saved_at_unix, 0 if none (Title "Fortsetzen"); ties → lower slot.
func newest_slot() -> int:
	var best: int = 0
	var best_t: int = -1
	for slot in range(1, SLOT_COUNT + 1):
		var s: Dictionary = slot_summary(slot)
		if s.is_empty() or bool(s.get("corrupt", false)):
			continue
		var t: int = int(s.get("saved_at_unix", 0))
		if t > best_t:
			best_t = t
			best = slot
	return best


## Read-modify-write: state.show.stats.game_overs += 1 in the slot file; slot 0 or an event run → OK, no write.
func record_game_over(slot: int) -> Error:
	_last_error = ""
	if slot == 0 or read_only or not _campaign():
		return OK
	if not _valid_slot(slot):
		return _fail(ERR_INVALID_PARAMETER, "invalid slot %d" % slot)
	var path: String = slot_path(slot)
	if not FileAccess.file_exists(path):
		return OK
	var raw: Variant = JsonUtil.read_file(path)
	if not (raw is Dictionary):
		return _fail(ERR_FILE_CORRUPT, "slot %d unreadable: %s" % [slot, JsonUtil.last_error()])
	var d: Dictionary = SaveCodec.migrate(raw)
	if d.is_empty() or not (d.get("state", null) is Dictionary):
		return _fail(ERR_FILE_UNRECOGNIZED, "slot %d: unsupported save" % slot)
	var st: Dictionary = d["state"]
	if not (st.get("show", null) is Dictionary):
		st["show"] = {}
	var show: Dictionary = st["show"]
	if not (show.get("stats", null) is Dictionary):
		show["stats"] = {}
	var stats: Dictionary = show["stats"]
	stats["game_overs"] = JsonUtil.to_int(stats.get("game_overs", 0)) + 1
	return _atomic_write(path, d)


## M8 (05 CR-8): <data root>/leaderboards/<event_id>.json; {} if missing or unreadable.
func load_leaderboard(event_id: String) -> Dictionary:
	if not _safe_name(event_id):
		return {}
	var path: String = _leaderboard_path(event_id)
	for p: String in [path, path + ".bak"]:
		if FileAccess.file_exists(p):
			var raw: Variant = JsonUtil.read_file(p)
			if raw is Dictionary:
				return raw
	return {}


## Atomic like slots.
func save_leaderboard(event_id: String, d: Dictionary) -> Error:
	_last_error = ""
	if read_only:
		return OK
	if not _safe_name(event_id):
		return _fail(ERR_INVALID_PARAMETER, "invalid event id '%s'" % event_id)
	return _atomic_write(_leaderboard_path(event_id), d)


## <data root>/replays/<run_id>.json, max. 20 files (the oldest are removed).
func save_replay(p_log: RunLog) -> Error:
	_last_error = ""
	if read_only:
		return OK
	if p_log == null:
		return _fail(ERR_INVALID_PARAMETER, "no run log")
	var run_id: String = _sanitize_name(str(p_log.header.get("run_id", "")))
	var dir: String = _data_root().path_join(REPLAY_DIR)
	var path: String = dir.path_join(run_id + ".json")
	var err: Error = _atomic_write(path, p_log.to_dict())
	if err == OK:
		_prune_replays(dir, path)
	return err


func last_error() -> String:
	return _last_error


# --- internals --------------------------------------------------------------------------------------------------------

func _valid_slot(slot: int) -> bool:
	return slot >= 1 and slot <= SLOT_COUNT


## Only campaign runs touch the campaign slots (05: event runs use slot 0, never saved).
func _campaign() -> bool:
	return Game.mode == &"campaign"


func _fail(err: Error, msg: String) -> Error:
	_last_error = msg
	return err


func _game_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))


## {"state": GameState, "warnings": PackedStringArray, "saved_at_unix": int} from the slot file or its backup;
## {} with _last_error set if neither is loadable. A save of a newer version is refused without fallback.
func _load_state(slot: int) -> Dictionary:
	var path: String = slot_path(slot)
	var problems: PackedStringArray = []
	for p: String in [path, path + ".bak"]:
		if not FileAccess.file_exists(p):
			continue
		var raw: Variant = JsonUtil.read_file(p)
		if not (raw is Dictionary):
			var why: String = JsonUtil.last_error() if JsonUtil.last_error() != "" else "not an object"
			problems.append("%s: %s" % [p.get_file(), why])
			continue
		var st: GameState = SaveCodec.decode(raw, DB.data)
		var errs: PackedStringArray = SaveCodec.last_errors()
		if st != null:
			var warnings: PackedStringArray = []
			for e: String in errs:
				warnings.append(e.trim_prefix("warning: "))
			var saved_at: int = JsonUtil.to_int((raw as Dictionary).get("saved_at_unix", 0))
			return {"state": st, "warnings": warnings, "saved_at_unix": saved_at}
		var msg: String = "; ".join(errs)
		if msg.begins_with(SaveCodec.MSG_NEWER):
			_last_error = msg
			return {}
		problems.append("%s: %s" % [p.get_file(), msg])
	_last_error = " | ".join(problems) if not problems.is_empty() else "no save file"
	return {}


func _make_run_log(st: GameState) -> RunLog:
	var rl: RunLog = RunLog.new()
	rl.header = {
		"schema": 1,
		"seed": st.seed,
		"slot": st.slot,
		"player_name": st.player_name,
		"mode": "campaign",
		"difficulty": String(st.difficulty),
		"game_version": _game_version(),
		"sim_hz": Game.TICKS_PER_SEC,
		"event_id": "",
		"run_id": RunLog.local_run_id(st.seed),
		"player_id": "local",
		"from_save": true,
	}
	return rl


## tmp → (existing → .bak) → final. Creates the directory.
func _atomic_write(path: String, d: Dictionary) -> Error:
	var dir: String = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		var mk: Error = DirAccess.make_dir_recursive_absolute(dir)
		if mk != OK:
			return _fail(mk, "cannot create %s" % dir)
	var tmp: String = path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return _fail(FileAccess.get_open_error(), "cannot write %s" % tmp)
	f.store_string(JSON.stringify(d, "\t"))
	var werr: Error = f.get_error()
	f.close()
	if werr != OK:
		return _fail(werr, "write error %s" % tmp)
	if FileAccess.file_exists(path):
		var bak: String = path + ".bak"
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		var berr: Error = DirAccess.rename_absolute(path, bak)
		if berr != OK:
			return _fail(berr, "cannot move %s to backup" % path)
	var rerr: Error = DirAccess.rename_absolute(tmp, path)
	if rerr != OK:
		return _fail(rerr, "cannot rename %s" % tmp)
	return OK


func _data_root() -> String:
	return save_dir.get_base_dir()


func _leaderboard_path(event_id: String) -> String:
	return _data_root().path_join(LEADERBOARD_DIR).path_join(event_id + ".json")


func _safe_name(s: String) -> bool:
	return s != "" and _name_re.search(s) != null


func _sanitize_name(s: String) -> String:
	var out: String = ""
	for ch: String in s:
		out += ch if _name_re.search(ch) != null else "_"
	return out if out != "" else "run_unknown"


## Keeps the MAX_REPLAYS newest replay files (modified time, then name); never removes `keep`.
func _prune_replays(dir: String, keep: String) -> void:
	var files: Array[Dictionary] = []
	for fname: String in DirAccess.get_files_at(dir):
		if not fname.ends_with(".json"):
			continue
		var p: String = dir.path_join(fname)
		files.append({"path": p, "t": FileAccess.get_modified_time(p), "name": fname})
	if files.size() <= MAX_REPLAYS:
		return
	files.sort_custom(_older_first)
	var excess: int = files.size() - MAX_REPLAYS
	for f: Dictionary in files:
		if excess <= 0:
			break
		if str(f["path"]) == keep:
			continue
		DirAccess.remove_absolute(str(f["path"]))
		var bak: String = str(f["path"]) + ".bak"
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		excess -= 1


static func _older_first(a: Dictionary, b: Dictionary) -> bool:
	if int(a["t"]) != int(b["t"]):
		return int(a["t"]) < int(b["t"])
	return str(a["name"]) < str(b["name"])
