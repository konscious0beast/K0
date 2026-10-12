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
	var p: PersonaProfile = load_persona(slot)       # Casting (08 §2.5): the name comes from the persona file
	if p != null:
		out["player_name"] = p.name
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
	var season_why: String = _season_save_refusal(slot)   # Staffeln (09 §9.1, ST1-B): its own slot, never in a combat
	if season_why != "":
		Events.game_saved.emit(slot, false)
		return _fail(ERR_UNAVAILABLE, season_why)
	var d: Dictionary = SaveCodec.encode(Game.state, _game_version())
	d["saved_at_unix"] = int(Time.get_unix_time_from_system())
	(d["state"] as Dictionary)["slot"] = slot
	d["state"] = _slot_state_dict(d["state"])       # Casting (08 §2.7 Nr. 1): the slot without the name (K1)
	(d["summary"] as Dictionary)["player_name"] = GameState.DEFAULT_NAME    # (the name: the persona file's)
	var journal_id: String = ""
	if Game.state.season != null:                   # Staffeln (09 §9.1, ST1-B): the journal this save starts
		journal_id = Crypto.new().generate_random_bytes(8).hex_encode()
		d[JOURNAL_KEY] = journal_id
	var err: Error = _atomic_write(slot_path(slot), d)
	if err == OK:
		Game.state.slot = slot
		err = save_persona(slot, Game.persona)       # Casting (08 §2.5): directly after the slot (K1)
		if journal_id != "":
			_journal_reset(slot, journal_id)
	Events.game_saved.emit(slot, err == OK)
	return err


## read → SaveCodec.decode → Game.adopt_loaded_state(state, run log) (+ grace time_left ≥ 180 s, §6.4; Game resets its
## private run context, new sim/run_log with header like new_game + "from_save": true); emits game_loaded; the log
## header gets its anchor "start_state" (the loaded state) + "start_hash" (replayable, RunSim.anchor_state).
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
	_season_migrate(st)                              # Staffeln (09 §8.7, ST1-B): from the switch to seasons on
	if st.season != null:                            # Staffeln (09 §9.1, ST1-B): no grace; the journal follows the save
		if st.season.result != "":
			return _fail(ERR_UNAVAILABLE, "%s (%s)" % [MSG_SEASON_OVER, st.season.result])
		st = _season_resume(slot, st, str(loaded.get(JOURNAL_KEY, "")))
	elif st.floor_run != null:
		st.floor_run.time_left_ticks = maxi(st.floor_run.time_left_ticks, GRACE_SECONDS * FloorRun.TICKS_PER_SEC)
	# Casting (08 §2.5): the persona file of the slot sets the display fields (K1; old saves with a name: migration)
	var p: PersonaProfile = load_persona(slot)
	if p != null:
		PersonaPrivacy.restore_display(st, p)
	# Game resets its private run context (event def, finished flag, layout cache, command ids, …) and takes over the
	# state with a new run log; the live RunSim records its checkpoints into that log.
	Game.adopt_loaded_state(st, _make_run_log(st))
	Game.persona = p
	Events.game_loaded.emit(slot)
	Show.sync_from_state()
	# The anchor of the new log (05 §11.4): Game.replay_log / RunSim.replay replay a "from_save" log from this state
	# (RunSim.anchor_state checks it against start_hash) — the segment after a load is verifiable like a new game.
	# Casting (08 §2.7 Nr. 3): without the display name (StateHash leaves it out, so start_hash stays valid).
	if Game.run_log != null:
		Game.run_log.header["start_state"] = PersonaPrivacy.scrub_state_dict(st.to_dict())
		Game.run_log.header["start_hash"] = StateHash.of(st)
	if st.season != null:                            # Staffeln (09 §9.1, ST1-B): the login, then a fresh journal
		_season_loaded(slot, str(loaded.get(JOURNAL_KEY, "")))
	return OK


func delete_slot(slot: int) -> Error:
	_last_error = ""
	if not _valid_slot(slot):
		return _fail(ERR_INVALID_PARAMETER, "invalid slot %d" % slot)
	if read_only:
		return OK
	var path: String = slot_path(slot)
	if _journal_slot == slot:                        # Staffeln (09 §9.1, ST1-B): the journal goes with the slot
		_journal_close()
	for p: String in [path, path + ".bak", path + ".tmp", journal_path(slot)]:
		if FileAccess.file_exists(p):
			var err: Error = DirAccess.remove_absolute(p)
			if err != OK:
				return _fail(err, "cannot delete %s" % p)
	return delete_persona(slot)                      # Casting (08 §2.5): the persona file goes with the slot (K1)


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
## 06-C (06 §6 decision 3): a lost boss attempt of the dying run (SponsorWindows comeback mark) is carried into the
## slot's state when it is on the same floor — the comeback window opens on the next entry of that boss room.
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
	if Game.state != null:
		SponsorWindows.merge_comeback(st, SponsorWindows.comeback_record(Game.state))   # 06-C
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


## <data root>/replays/<run_id>.json, max. 20 files (the oldest are removed). R5b (07 §10.3): the file holds the
## compacted form (RunLog.compact: runs of move samples as move_batch; a CTB log stays as it is) — the verifiers replay
## it expanded, the leaderboard's run_log_hash is RunLog.canonical_digest() (the expanded form). `p_log` is not changed.
func save_replay(p_log: RunLog) -> Error:
	_last_error = ""
	if read_only:
		return OK
	if p_log == null:
		return _fail(ERR_INVALID_PARAMETER, "no run log")
	var run_id: String = _sanitize_name(str(p_log.header.get("run_id", "")))
	var dir: String = _data_root().path_join(REPLAY_DIR)
	var path: String = dir.path_join(run_id + ".json")
	var stored: RunLog = RunLog.from_dict(p_log.to_dict())
	stored.compact()
	var err: Error = _atomic_write(path, stored.to_dict())
	if err == OK:
		_prune_replays(dir, path)
	return err


func last_error() -> String:
	return _last_error


# --- Staffeln (09 §9.1, ST0 → ST1-B): the persistent save of a season and its command journal -----------------------
# A season saves at fixed moments (Game: after a combat, at a safe-room visit, at a floor change, at logout, at the
# latest every 60 s) and only into its own slot — there is no reloading of an older state ("Dauerspeicherstand"; no
# save during a combat). In between an append-only journal per slot holds every recorded command — one line, written and
# flushed BEFORE the command acts (Game.record → journal_append; CommandJournal is the line format). Every season save
# writes a new journal id into the slot file and starts the journal with it (header line, the sim tick of the save);
# loading replays a journal that continues the loaded save (same id; a torn last line is dropped, a combat it ends in
# goes to the autopilot from its start — GameReplay.resume), saves the result at once and starts a fresh journal. A run
# without a season never touches a journal. The loaded season gets no grace (09 §9.1: TIMER_GRACE_ON_LOAD is the
# campaign's); a finished season does not load (it is in the hall of fame, ST1-H). The career file keeps what stays
# across seasons (09 §2.8): the Ohne-Netz unlock and the season counter.

const JOURNAL_EXT: String = "journal"
const JOURNAL_KEY: String = "journal"               # the journal id in the slot file (top level, seasons only)
const CAREER_FILE: String = "career.json"
const MSG_SEASON_OVER: String = "Staffel beendet"

var _journal: FileAccess = null                      # the open journal (append) of _journal_slot
var _journal_slot: int = 0
var _journal_k0: int = 0                             # Game.sim.tick() of the save the journal continues
var _journal_resumed: bool = false                   # load_slot replayed a journal: it saves at once


## save_dir + "/slot_%d.journal" % slot (09 §9.1: user://saves/slot_N.journal).
func journal_path(slot: int) -> String:
	return save_dir + "/slot_%d.%s" % [slot, JOURNAL_EXT]


## Appends `cmd` as one line (CommandJournal.line: the ticks since the save, the command) to the open journal of `slot`
## and flushes it — Game.record calls it with a season before the command acts. OK without writing while the slot has
## no journal yet (no season save in this session), for slot 0 and read_only.
func journal_append(slot: int, cmd: Dictionary) -> Error:
	if read_only or not _valid_slot(slot) or _journal == null or _journal_slot != slot:
		return OK
	var k: int = Game.sim.tick() - _journal_k0 if Game.sim != null else 0
	_journal.store_line(CommandJournal.line(k, cmd))
	_journal.flush()
	return _journal.get_error()


## The entries of journal_path(slot) in order ({"k": ticks since the save, "c": the command}; a torn last line dropped,
## a broken line ends it). [] without a journal.
func journal_replay(slot: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(journal_read(slot)["entries"])
	return out


## CommandJournal.parse of the slot's journal ({"header", "entries", "torn", "bad"}; empty without a file).
func journal_read(slot: int) -> Dictionary:
	var path: String = journal_path(slot)
	var text: String = FileAccess.get_file_as_string(path) if _valid_slot(slot) and FileAccess.file_exists(path) else ""
	return CommandJournal.parse(text)


## The file of what stays across seasons on this device (09 §2.8): <parent of save_dir>/career.json.
func career_path() -> String:
	return _data_root().path_join(CAREER_FILE)


## {"v": 1, "no_net": bool (the Ohne-Netz unlock, 09 §2.2), "seasons": int (the last season number)}; {} without
## a file. ST1-H adds the titles and the hall of fame.
func career() -> Dictionary:
	var path: String = career_path()
	for p: String in [path, path + ".bak"]:
		if FileAccess.file_exists(p):
			var raw: Variant = JsonUtil.read_file(p)
			if raw is Dictionary:
				return raw
	return {}


## Sets one career value (atomic like the slots). read_only → OK without writing.
func career_set(key: String, value: Variant) -> Error:
	if read_only:
		return OK
	var d: Dictionary = career()
	if d.get(key, null) == value:
		return OK
	d["v"] = 1
	d[key] = value
	return _atomic_write(career_path(), d)


## "" or why Game.state may not be saved into `slot` now: a season saves only into its own slot and never during a
## combat (a save there would drop the combat from the journal).
func _season_save_refusal(slot: int) -> String:
	var st: GameState = Game.state
	if st == null or st.season == null:
		return ""
	if Game.combat != null or Game.in_battle:
		return "a season never saves during a combat (09 §9.1)"
	if st.slot > 0 and slot != st.slot:
		return "a season saves only into its own slot (09 §9.1: no reloading)"
	return ""


## Starts the journal of `slot` anew: the header with the save's journal id and the current sim tick (the entries count
## their ticks from it). The handle stays open for journal_append.
func _journal_reset(slot: int, id: String) -> void:
	_journal_close()
	if read_only or not _valid_slot(slot):
		return
	var f: FileAccess = FileAccess.open(journal_path(slot), FileAccess.WRITE)
	if f == null:
		push_warning("[Save] cannot write the journal of slot %d (%s)" % [slot, error_string(FileAccess.get_open_error())])
		return
	_journal_k0 = Game.sim.tick() if Game.sim != null else 0
	f.store_line(CommandJournal.header_line(id, _journal_k0))
	f.flush()
	_journal = f
	_journal_slot = slot


func _journal_close() -> void:
	if _journal != null:
		_journal.close()
	_journal = null
	_journal_slot = 0
	_journal_k0 = 0


## The journal of `slot` replayed from the loaded save `st` when it continues this save (the same journal id — a stale
## journal, whose save was written after it, is ignored); the result of GameReplay.resume is the state to adopt. A
## journal that does not replay cleanly is ignored (warning): the save stays the state.
func _season_resume(slot: int, st: GameState, save_journal_id: String) -> GameState:
	_journal_close()
	_journal_resumed = false
	var j: Dictionary = journal_read(slot)
	var entries: Array = j["entries"]
	if save_journal_id == "" or str((j["header"] as Dictionary).get("id", "")) != save_journal_id or entries.is_empty():
		return st
	if bool(j["torn"]) or int(j["bad"]) > 0:
		push_warning("[Save] slot %d: dropped %d journal line(s) at its end" % [slot, int(j["bad"]) + int(j["torn"])])
	var res: Dictionary = Game.season_resume(st, entries)
	var errors: PackedStringArray = res["errors"]
	if res["state"] == null or not errors.is_empty():
		push_warning("[Save] slot %d: the journal was not replayed (%s)" % [slot, "; ".join(errors)])
		return st
	var out: GameState = res["state"]
	out.slot = slot
	_journal_resumed = true
	return out


## After a season slot was adopted: a fresh journal — a save at once when the journal was replayed or the slot has no
## journal id yet (the slot holds that state from now on), else the journal of this save starts anew from the new
## session's tick 0 — then the login (Game.season_login: "away", ST1-G), so it lands in the journal.
func _season_loaded(slot: int, save_journal_id: String) -> void:
	if not read_only:
		if _journal_resumed or save_journal_id == "":
			save_slot(slot)
		else:
			_journal_reset(slot, save_journal_id)
	_journal_resumed = false
	Game.season_login()


## 09 §8.7, §11.1: from the switch to seasons on (RunSim.SIM_VERSION ≥ SeasonRules.CAMPAIGN_SEASON_SIM_VERSION) a
## campaign save becomes a private season Am Stück (SeasonRules.migrate_campaign: the default template, the floor's
## time left as its countdown — no grace —, a new anchor). Until then a campaign save stays a campaign.
func _season_migrate(st: GameState) -> void:
	if st.season != null or RunSim.SIM_VERSION < SeasonRules.CAMPAIGN_SEASON_SIM_VERSION:
		return
	var tz: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	SeasonRules.migrate_campaign(st, DB.data, SeasonRules.default_def(DB.data), int(Time.get_unix_time_from_system()),
		tz)


# --- Stempelduell (10, SD2) -----------------------------------------------------------------------------------------
# The account collection of the mini-game (10 §6.7): <data root>/stempel/collection.json (default
# user://stempel/collection.json), atomic like the slots (.tmp → .bak). Catalog ids and numbers only — no names, no
# persona (08 P-1), so "Kandidat:in löschen" leaves it alone. The file is read as JSON and handed to
# SdCollection.from_dict by the caller (scenes/stempel/sd_session.gd): this autoload never compiles the duel core at
# boot (cf. GlobalUi.initial_mode); the account seed is rolled there too, outside core/.

const SD_DIR: String = "stempel"
const SD_FILE: String = "collection.json"


## <data root>/stempel/collection.json.
func sd_collection_path() -> String:
	return _data_root().path_join(SD_DIR).path_join(SD_FILE)


## The parsed collection file: {"found": false} without a file; {"found": true, "data": <parsed JSON or null>} — the
## backup when the file itself is unreadable, null when neither parses (SdCollection.from_dict then starts an empty
## collection with was_reset: the toast "Stempelakte neu angelegt", 10 §6.7).
func load_sd_collection() -> Dictionary:
	var path: String = sd_collection_path()
	var found: bool = false
	for p: String in [path, path + ".bak"]:
		if not FileAccess.file_exists(p):
			continue
		found = true
		var raw: Variant = JsonUtil.read_file(p)
		if raw is Dictionary:
			return {"found": true, "data": raw}
	return {"found": found, "data": null}


## Writes SdCollection.to_dict() atomically; read_only (autoplay) → OK without writing.
func save_sd_collection(d: Dictionary) -> Error:
	_last_error = ""
	if read_only:
		return OK
	return _atomic_write(sd_collection_path(), d)


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
			return {"state": st, "warnings": warnings, "saved_at_unix": saved_at,
				JOURNAL_KEY: str((raw as Dictionary).get(JOURNAL_KEY, ""))}   # Staffeln (09, ST1-B)
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
		"mode": "campaign",                          # no name (08 §2.7 Nr. 2)
		"difficulty": String(st.difficulty),
		"game_version": _game_version(),
		"sim_hz": Game.TICKS_PER_SEC,
		"sim_version": RunSim.SIM_VERSION,             # like Game._make_run_log (05 §10.6; old_version check)
		"event_id": "",
		"run_id": RunLog.local_run_id(st.seed),
		"player_id": "local",
		"from_save": true,
		"combat_mode": String(RunRules.REALTIME),      # Echtzeitkampf (07 §10.2): like Game.new_game's header
		"rt_version": RunRules.RT_VERSION,
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


# ======================================================================================================================
# Casting (08, K1): the persona file next to each slot (08 §2.2, §2.5, §2.7 Nr. 1)
# ======================================================================================================================
# The slot file never carries the name (PersonaPrivacy.scrub_state_dict: "Kai"); the persona file holds it, written
# directly after the slot (atomic like the slot), read after it (load_slot → PersonaPrivacy.restore_display), removed
# with the slot. A slot of a game without a casting but with another display name gets a persona file with that name
# and canon values (the name never goes back into the slot); old slots that still carry a name (before K1) get theirs
# when they are loaded (migration, 08 §2.5). "Kandidat:in löschen" (delete_candidate) removes every persona file and
# cleans the leftovers with names (08 D-7). user://persona/ is never part of a cloud save or backup (R12).

const PERSONA_DIR: String = "persona"
const CANDIDATE_LOCAL: String = "local"       # the local leaderboard entry (05 §10.4)


## <parent of save_dir>/persona/slot_N.json (default user://persona/slot_N.json): next to the saves, never part of a
## cloud save or backup (08 §2.5, R12).
func persona_path(slot: int) -> String:
	return _data_root().path_join(PERSONA_DIR).path_join("slot_%d.json" % slot)


## Writes p.to_dict() atomically to persona_path(slot). p == null: the game has no persona — a display name other than
## "Kai" still gets a file (name + canon values), else the slot's old persona file is removed. Slot 0 / read_only → OK.
func save_persona(slot: int, p: PersonaProfile) -> Error:
	if slot == 0 or read_only:
		return OK
	if not _valid_slot(slot):
		return _fail(ERR_INVALID_PARAMETER, "invalid slot %d" % slot)
	var prof: PersonaProfile = p
	if prof == null and Game.state != null and Game.state.player_name != GameState.DEFAULT_NAME:
		prof = _name_only_persona(Game.state.player_name)
	if prof == null:
		return delete_persona(slot)
	return _atomic_write(persona_path(slot), prof.to_dict())


## The persona file of the slot (PersonaProfile.from_dict: catalog and filters checked again; another format or a newer
## "v" → null with a warning). No file, but the slot still carries a display name other than "Kai" (a save from before
## K1) → a persona file with that name and canon values is written (migration, 08 §2.5) and returned, and the slot
## file and its backup lose the name. null = none.
func load_persona(slot: int) -> PersonaProfile:
	if not _valid_slot(slot):
		return null
	var path: String = persona_path(slot)
	for f: String in [path, path + ".bak"]:
		if not FileAccess.file_exists(f):
			continue
		var raw: Variant = JsonUtil.read_file(f)
		if raw is Dictionary and str((raw as Dictionary).get("format", "")) == PersonaProfile.FORMAT:
			if JsonUtil.to_int((raw as Dictionary).get("v", 0)) > PersonaProfile.VERSION:
				push_warning("[Save] persona file of slot %d has a newer version — shown as canon" % slot)
				return null
			return PersonaProfile.from_dict(raw, DB.data)
	var name: String = _slot_display_name(slot)
	if name == "" or name == GameState.DEFAULT_NAME:
		return null
	var p: PersonaProfile = _name_only_persona(name)
	if not read_only and _atomic_write(path, p.to_dict()) == OK:
		for f: String in [slot_path(slot), slot_path(slot) + ".bak"]:   # the name moved: the slot files lose it
			_scrub_slot_file(f)
	return p


## Removes the persona file of the slot (+ .bak, .tmp) — with Save.delete_slot and "Kandidat:in löschen".
func delete_persona(slot: int) -> Error:
	if read_only:
		return OK
	var path: String = persona_path(slot)
	for f: String in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(f):
			var err: Error = DirAccess.remove_absolute(f)
			if err != OK:
				return _fail(err, "cannot delete %s" % f)
	return OK


## "Kandidat:in löschen" (08 D-7, Optionen): every persona file goes; leftovers with names are cleaned — slot files
## (and their backups) are rewritten with "Kai", replays whose header still names the player are deleted, local
## leaderboard entries lose their name. The running game keeps playing as the canon candidate (its recorded ids stay:
## they are game mechanics, not personal data). Returns the first error (everything else is still tried).
func delete_candidate() -> Error:
	_last_error = ""
	if read_only:
		return OK
	var first: Error = OK
	var dir: String = _data_root().path_join(PERSONA_DIR)
	if DirAccess.dir_exists_absolute(dir):
		for f: String in DirAccess.get_files_at(dir):
			var err: Error = DirAccess.remove_absolute(dir.path_join(f))
			if err != OK and first == OK:
				first = _fail(err, "cannot delete %s" % f)
	for slot in range(1, SLOT_COUNT + 1):
		for f: String in [slot_path(slot), slot_path(slot) + ".bak"]:
			var err: Error = _scrub_slot_file(f)
			if err != OK and first == OK:
				first = err
	var rdir: String = _data_root().path_join(REPLAY_DIR)
	if DirAccess.dir_exists_absolute(rdir):
		for f: String in DirAccess.get_files_at(rdir):
			var raw: Variant = JsonUtil.read_file(rdir.path_join(f))
			if raw is Dictionary and _names_someone((raw as Dictionary).get("header", {})):
				DirAccess.remove_absolute(rdir.path_join(f))
	var ldir: String = _data_root().path_join(LEADERBOARD_DIR)
	if DirAccess.dir_exists_absolute(ldir):
		for f: String in DirAccess.get_files_at(ldir):       # boards and their .bak / .tmp copies
			var err: Error = _scrub_board_file(ldir.path_join(f))
			if err != OK and first == OK:
				first = err
	Game.persona = PersonaProfile.canon(DB.data) if Game.persona != null else null
	if Game.state != null:
		PersonaPrivacy.restore_display(Game.state, PersonaProfile.canon(DB.data))
	return first


## The state dictionary as the slot file stores it: without the display name (08 §2.7 Nr. 1).
func _slot_state_dict(d: Dictionary) -> Dictionary:
	return PersonaPrivacy.scrub_state_dict(d)


func _name_only_persona(name: String) -> PersonaProfile:
	var p: PersonaProfile = PersonaProfile.canon(DB.data)
	p.name = name
	if p.validate(DB.data).size() > 0:
		p.sanitize(DB.data)
	return p


## The display name a slot file still carries (saves from before K1); "" if none / unreadable.
func _slot_display_name(slot: int) -> String:
	for f: String in [slot_path(slot), slot_path(slot) + ".bak"]:
		if not FileAccess.file_exists(f):
			continue
		var raw: Variant = JsonUtil.read_file(f)
		if raw is Dictionary and (raw as Dictionary).get("state", null) is Dictionary:
			return str(((raw as Dictionary)["state"] as Dictionary).get("player_name", ""))
	return ""


## Rewrites a slot file (or backup) whose state still names the player (in place, keeping its saved_at_unix).
func _scrub_slot_file(path: String) -> Error:
	if not FileAccess.file_exists(path):
		return OK
	var raw: Variant = JsonUtil.read_file(path)
	if not (raw is Dictionary) or not ((raw as Dictionary).get("state", null) is Dictionary):
		return OK
	var st: Dictionary = (raw as Dictionary)["state"]
	var clean: Dictionary = PersonaPrivacy.scrub_state_dict(st)
	var summary: Variant = (raw as Dictionary).get("summary", null)
	var named: bool = summary is Dictionary and (summary as Dictionary).has("player_name") \
		and str((summary as Dictionary)["player_name"]) != GameState.DEFAULT_NAME
	if clean == st and not named:
		return OK
	(raw as Dictionary)["state"] = clean
	if named:
		(summary as Dictionary)["player_name"] = GameState.DEFAULT_NAME
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return _fail(FileAccess.get_open_error(), "cannot write %s" % path)
	f.store_string(JSON.stringify(raw, "\t"))
	f.close()
	return OK


## A run-log header from before K0 that still names the player (player_name, or a start_state with a name).
static func _names_someone(h: Variant) -> bool:
	if not (h is Dictionary):
		return false
	var d: Dictionary = h
	if str(d.get("player_name", GameState.DEFAULT_NAME)) != GameState.DEFAULT_NAME:
		return true
	var st: Variant = d.get("start_state", null)
	return st is Dictionary and PersonaPrivacy.scrub_state_dict(st) != st


## Local leaderboard entries (player_id "local") keep no display name (08 §2.7 Nr. 4). Rewritten in place — an atomic
## write would keep the named version as its .bak.
func _scrub_board_file(path: String) -> Error:
	var raw: Variant = JsonUtil.read_file(path)
	if not (raw is Dictionary):
		return OK
	var changed: bool = false
	for e: Variant in ((raw as Dictionary).get("entries", []) as Array):
		if not (e is Dictionary):
			continue
		for pl: Variant in ((e as Dictionary).get("players", []) as Array):
			if pl is Dictionary and str((pl as Dictionary).get("player_id", "")) == CANDIDATE_LOCAL \
					and str((pl as Dictionary).get("display_name", "")) != "":
				(pl as Dictionary)["display_name"] = ""
				changed = true
	if not changed:
		return OK
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return _fail(FileAccess.get_open_error(), "cannot write %s" % path)
	f.store_string(JSON.stringify(raw, "\t"))
	f.close()
	return OK
