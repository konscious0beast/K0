class_name SaveCodec extends RefCounted
## Save dict ↔ GameState, versioning, migration (02_TECH §6.1/§6.4).
##
## File layout (version 2): {"format": "ptd_save", "version": 2, "game_version", "saved_at_unix", "summary", "state"}.
## encode() leaves saved_at_unix at 0 (core has no clock, 05 §3.3 Nr. 6); Save stamps it before writing.
## decode() = migrate → validate (fatal errors → null) → GameState.from_dict → sanitize against GameData
## (unknown item/skill/box/enemy ids are dropped, values clamped; listed as "warning: …" in last_errors()).
##
## Version history:
## - v0 (pre-release prototype, no "format"/"version" or version 0): floor timer in float seconds
##   (`floor_run.time_left`, `floor_run.stats.time_used`), no `loot_seed`, no `summary`.
## - v1: timer in whole ticks (05 CR-3), `floor_run.loot_seed` (05 CR-11; derived from the run seed if missing).
## - v2 (R5b part 2b, 07 §12.6 step 2, 02_TECH §6.4): the data carry the real-time HP (party HP × 4 baked in); a state
##   fights in real time without a `combat_mode` key, members have no `hp_scale_pm` (_migrate_v1_to_v2).
##   Season block (09 §9.1, ST0 — additive, no version bump): `state.season` (an object or absent; absent / null = no
##   season, every campaign save), the members' `rested`, `professions`, `prof_head`, `talent_rows` and the floor
##   run's `gather_nodes`, `respawn`, `daily` — all optional and written only when set, so a v2 file without them loads
##   and hashes exactly as before. The command journal next to the slot is Save's (journal_append / journal_replay);
##   since ST1-B a season slot file also carries the top-level key "journal" (the id of its journal, written by Save —
##   validate ignores it) and the summary a "season" block.

const FORMAT: String = "ptd_save"
const VERSION: int = 2
## v1 → v2: a CTB save's party HP in the units of the baked data (07 §3.9.4: the HP scale of the real-time combat).
const V1_CTB_HP_FACTOR: int = 4
const TICKS_PER_SEC: int = 30
const MSG_NEWER: String = "Spielstand stammt aus neuerer Version"
## Renamed ids (no version bump): an older save keeps the skill / class under its new id instead of dropping it.
## Polish pass 2026-10-10 (IP distance, no royalty or diva-pet motif for Graf Mopsula): "Königlicher Erlass" →
## "Gräfliches Gutachten", class "Diva" → "Zeremonienmeister".
const RENAMED_SKILLS: Dictionary = {"skl_mop_royal_decree": "skl_mop_expert_opinion"}
const RENAMED_CLASSES: Dictionary = {"cls_mop_diva": "cls_mop_zeremonienmeister"}
const PROF_VALUE_MAX: int = 300              # Staffeln (09 §8.5): profession values 1–300

static var _errors: PackedStringArray = []


static func encode(state: GameState, game_version: String) -> Dictionary:
	if state == null:
		return {}
	return {
		"format": FORMAT,
		"version": VERSION,
		"game_version": game_version,
		"saved_at_unix": 0,
		"summary": summary(state),
		"state": state.to_dict(),
	}


## null on fatal error; errors via last_errors().
static func decode(d: Dictionary, data: GameData) -> GameState:
	_errors = PackedStringArray()
	if d.is_empty():
		_errors.append("empty save")
		return null
	var version: int = _version_of(d)
	if version > VERSION:
		_errors.append("%s (v%d > v%d)" % [MSG_NEWER, version, VERSION])
		return null
	var m: Dictionary = migrate(d)
	if m.is_empty():
		_errors.append("unsupported save version")
		return null
	var errs: PackedStringArray = validate(m, data)
	if not errs.is_empty():
		_errors = errs
		return null
	var st: GameState = GameState.from_dict(m["state"])
	_sanitize(st, data)
	# 05 CR-11: a missing loot_seed (v0) is derived from the corrected floor index — GameState.from_dict used the raw
	# index from the file, which _sanitize may just have fixed.
	if st.floor_run != null and _loot_seed_missing(m["state"]):
		st.floor_run.loot_seed = SeedUtil.derive(st.seed, "loot", st.floor_run.index)
	return st


## Stepwise v(n) → v(n+1); unknown higher version → {}.
static func migrate(d: Dictionary) -> Dictionary:
	var version: int = _version_of(d)
	if version < 0 or version > VERSION:
		return {}
	var out: Dictionary = d.duplicate(true)
	while version < VERSION:
		match version:
			0:
				out = _migrate_v0_to_v1(out)
			1:
				out = _migrate_v1_to_v2(out)
		version += 1
	out["format"] = FORMAT
	out["version"] = VERSION
	return out


## Fatal problems of a (migrated) save dict; [] = loadable.
static func validate(d: Dictionary, data: GameData) -> PackedStringArray:
	var errs: PackedStringArray = []
	if str(d.get("format", "")) != FORMAT:
		errs.append("format: expected '%s'" % FORMAT)
	var version: Variant = d.get("version", null)
	if not JsonUtil.is_integral(version):
		errs.append("version: missing or not an integer")
	elif int(version) > VERSION:
		errs.append("%s (v%d > v%d)" % [MSG_NEWER, int(version), VERSION])
	elif int(version) < VERSION:
		errs.append("version: v%d not migrated" % int(version))
	var raw_state: Variant = d.get("state", null)
	if not (raw_state is Dictionary):
		errs.append("state: missing")
		return errs
	var st: Dictionary = raw_state
	if not JsonUtil.is_integral(st.get("seed", null)):
		errs.append("state.seed: missing or not an integer")
	var raw_party: Variant = st.get("party", null)
	var known_members: int = 0
	if raw_party is Array:
		for e: Variant in raw_party:
			if e is Dictionary and data != null and data.has_id("party", str((e as Dictionary).get("id", ""))):
				known_members += 1
	if known_members == 0:
		errs.append("state.party: no known party member")
	for key: String in ["inventory", "show", "flags", "bestiary"]:
		if st.has(key) and not (st[key] is Dictionary):
			errs.append("state.%s: not an object" % key)
	if st.get("season", null) != null and not (st["season"] is Dictionary):   # Staffeln (09, ST0): optional block
		errs.append("state.season: not an object")
	var raw_fr: Variant = st.get("floor_run", null)
	if raw_fr != null:
		if not (raw_fr is Dictionary):
			errs.append("state.floor_run: not an object")
		else:
			var fid: String = str((raw_fr as Dictionary).get("floor_id", ""))
			if fid == "" or data == null or not data.has_id("floors", fid):
				errs.append("state.floor_run.floor_id: unknown floor '%s'" % fid)
	return errs


## {"player_name", "floor_index", "level" (Kai), "play_time_sec" (int), "followers", "location"} for slot lists.
## Staffeln (09, ST1-B): with a season also "season": {"def", "number", "format", "tempo", "mode", "on_air",
## "result"} (the slot list of ST1-H).
static func summary(state: GameState) -> Dictionary:
	if state == null:
		return {}
	var kai: PartyMember = state.member("kai")
	if kai == null and not state.party.is_empty():
		kai = state.party[0]
	var out: Dictionary = {
		"player_name": state.player_name,
		"floor_index": state.floor_run.index if state.floor_run != null else 1,
		"level": kai.level if kai != null else 1,
		"play_time_sec": floori(state.play_time_sec),
		"followers": state.show.followers if state.show != null else 0,
		"location": String(state.floor_run.location) if state.floor_run != null else "start",
	}
	if state.season != null:
		var s: SeasonState = state.season
		out["season"] = {"def": s.def_id, "number": s.number, "format": s.format, "tempo": s.tempo, "mode": s.mode,
			"on_air": s.on_air(), "result": s.result}
	return out


static func last_errors() -> PackedStringArray:
	return _errors.duplicate()


# --- helpers ----------------------------------------------------------------------------------------------------------

## 0 for pre-release saves without version (or with an integral "version": 0), -1 if unreadable.
static func _version_of(d: Dictionary) -> int:
	if not d.has("version"):
		return 0 if d.get("state", null) is Dictionary else -1
	var v: Variant = d["version"]
	if not JsonUtil.is_integral(v):
		return -1
	return int(v)


## v0 → v1: float-second timer → whole ticks; loot_seed is derived in decode (after the floor index is sanitized);
## summary added.
static func _migrate_v0_to_v1(d: Dictionary) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	var raw_state: Variant = out.get("state", {})
	var st: Dictionary = raw_state if raw_state is Dictionary else {}
	var raw_fr: Variant = st.get("floor_run", null)
	if raw_fr is Dictionary:
		var fr: Dictionary = raw_fr
		if fr.has("time_left") and not fr.has("time_left_ticks"):
			fr["time_left_ticks"] = maxi(0, roundi(JsonUtil.to_float(fr["time_left"]) * TICKS_PER_SEC))
			fr.erase("time_left")
		var raw_stats: Variant = fr.get("stats", {})
		if raw_stats is Dictionary:
			var stats: Dictionary = raw_stats
			if stats.has("time_used") and not stats.has("time_used_ticks"):
				stats["time_used_ticks"] = maxi(0, roundi(JsonUtil.to_float(stats["time_used"]) * TICKS_PER_SEC))
				stats.erase("time_used")
		st["floor_run"] = fr
	out["state"] = st
	if not out.has("summary"):
		out["summary"] = {}
	if not out.has("game_version"):
		out["game_version"] = ""
	if not out.has("saved_at_unix"):
		out["saved_at_unix"] = 0
	return out


## v1 → v2 (02_TECH §6.4; R5b part 2b): the data carry the real-time HP since the bake (07 §4.11). A CTB save (no
## state "combat_mode") counts its party HP in CTB units: × V1_CTB_HP_FACTOR (a K.O. stays 0; _sanitize caps at the new
## max HP). A real-time save ("combat_mode": "realtime", members with hp_scale_pm) already counts real-time HP. Both
## lose "combat_mode" (a v2 state fights in real time) and every member's "hp_scale_pm"; MP and everything else (06 / 08
## fields, rt_loadout / rt_preset / rt_toggles, flags, inventory, bestiary, floor run) stay as they are.
static func _migrate_v1_to_v2(d: Dictionary) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	var raw_state: Variant = out.get("state", {})
	var st: Dictionary = raw_state if raw_state is Dictionary else {}
	var realtime: bool = str(st.get("combat_mode", "")) == "realtime"
	st.erase("combat_mode")
	var raw_party: Variant = st.get("party", [])
	if raw_party is Array:
		for e: Variant in raw_party:
			if not (e is Dictionary):
				continue
			var m: Dictionary = e
			if not realtime and m.has("hp"):
				m["hp"] = maxi(0, JsonUtil.to_int(m["hp"])) * V1_CTB_HP_FACTOR
			m.erase("hp_scale_pm")
	out["state"] = st
	return out


## The save's floor_run has no usable loot_seed (missing or negative, as FloorRun.from_dict reads it).
static func _loot_seed_missing(raw_state: Dictionary) -> bool:
	var raw_fr: Variant = raw_state.get("floor_run", null)
	return raw_fr is Dictionary and JsonUtil.to_int((raw_fr as Dictionary).get("loot_seed", -1), -1) < 0


## Drops unknown ids and clamps values against the data; every change is recorded as a warning.
static func _sanitize(st: GameState, data: GameData) -> void:
	if data == null:
		return
	# party: known members only, battle_slot order, valid level/skills/equipment/class, vitals clamped
	var kept: Array[PartyMember] = []
	for m: PartyMember in st.party:
		if not data.has_id("party", m.id):
			_warn("party member '%s' dropped (unknown)" % m.id)
			continue
		kept.append(m)
	var slot_of: Dictionary = {}
	for m: PartyMember in kept:
		slot_of[m.id] = data.party_member(m.id).battle_slot
	kept.sort_custom(func(a: PartyMember, b: PartyMember) -> bool: return int(slot_of[a.id]) < int(slot_of[b.id]))
	st.party = kept
	for m: PartyMember in st.party:
		m.level = clampi(m.level, 1, Balance.LEVEL_CAP)
		if m.level >= Balance.LEVEL_CAP:
			m.exp = 0
		var skills: PackedStringArray = []
		for s: String in m.skills:
			var sid: String = str(RENAMED_SKILLS.get(s, s))
			if data.has_id("skills", sid):
				if not skills.has(sid):
					skills.append(sid)
			else:
				_warn("skill '%s' of %s dropped (unknown)" % [s, m.id])
		m.skills = skills
		for slot: String in ["weapon", "armor", "accessory"]:
			var item_id: String = str(m.equipment.get(slot, ""))
			if item_id != "" and (not data.has_id("items", item_id) or data.item(item_id).type != slot):
				_warn("equipment '%s' of %s dropped (unknown or wrong slot)" % [item_id, m.id])
				m.equipment[slot] = ""
		m.class_id = str(RENAMED_CLASSES.get(m.class_id, m.class_id))
		if m.class_id != "" and not data.has_id("classes", m.class_id):
			_warn("class '%s' of %s dropped (unknown)" % [m.class_id, m.id])
			m.class_id = ""
		_sanitize_b(m, data)                       # 06 package B: talents, species
		_sanitize_season_member(m, data)           # Staffeln (09, ST0): professions, talent rows
		var sb: StatBlock = Progression.total_stats(m, data)
		m.hp = clampi(m.hp, 0, sb.values[StatBlock.Stat.HP])
		m.mp = clampi(m.mp, 0, sb.values[StatBlock.Stat.MP])
	# inventory
	for item_id: Variant in st.inventory.counts.keys():
		var iid: String = str(item_id)
		if not data.has_id("items", iid):
			_warn("item '%s' dropped (unknown)" % iid)
			st.inventory.counts.erase(item_id)
		elif st.inventory.count(iid) > data.item(iid).max_stack:
			st.inventory.counts[item_id] = data.item(iid).max_stack
	# boxes, bestiary
	var boxes: PackedStringArray = []
	for b: String in st.pending_lootboxes:
		if data.has_id("lootboxes", b):
			boxes.append(b)
		else:
			_warn("lootbox '%s' dropped (unknown)" % b)
	st.pending_lootboxes = boxes
	for enemy_id: Variant in st.bestiary.keys():
		if not data.has_id("enemies", str(enemy_id)):
			_warn("bestiary entry '%s' dropped (unknown)" % str(enemy_id))
			st.bestiary.erase(enemy_id)
	# show
	var achievements: PackedStringArray = []
	for a: String in st.show.achievements:
		if data.has_id("achievements", a):
			achievements.append(a)
		else:
			_warn("achievement '%s' dropped (unknown)" % a)
	st.show.achievements = achievements
	var milestones: PackedStringArray = []
	for ms: String in st.show.milestones:
		if data.has_id("milestones", ms):
			milestones.append(ms)
		else:
			_warn("milestone '%s' dropped (unknown)" % ms)
	st.show.milestones = milestones
	for stat_id: Variant in st.show.stats.keys():
		if not StatIds.ALL.has(str(stat_id)):
			_warn("stat '%s' dropped (unknown)" % str(stat_id))
			st.show.stats.erase(stat_id)
	_sanitize_season(st, data)                     # Staffeln (09, ST0): the season block
	# floor run: index follows the floor id
	if st.floor_run != null and data.has_id("floors", st.floor_run.floor_id):
		var idx: int = data.floor_by_id(st.floor_run.floor_id).index
		if idx != st.floor_run.index:
			_warn("floor index %d corrected to %d" % [st.floor_run.index, idx])
			st.floor_run.index = idx


static func _warn(msg: String) -> void:
	_errors.append("warning: " + msg)


## 06 package B: talents unknown / not for the member are dropped (their choices become open again), ranks clamped to
## 1..max_rank; an unknown species or one not for the member falls back to "" (not cast).
static func _sanitize_b(m: PartyMember, data: GameData) -> void:
	for tid: Variant in m.talents.keys():
		var id: String = str(tid)
		if not data.has_id("talents", id) or not data.talent(id).is_for(m.id):
			_warn("talent '%s' of %s dropped (unknown)" % [id, m.id])
			m.talents.erase(tid)
		else:
			m.talents[tid] = clampi(int(m.talents[tid]), 1, data.talent(id).max_rank)
	if m.species_id != "" and (not data.has_id("species", m.species_id)
			or not data.species_def(m.species_id).is_for(m.id)):
		_warn("species '%s' of %s dropped (unknown)" % [m.species_id, m.id])
		m.species_id = ""


# --- Staffeln (09, ST0) -----------------------------------------------------------------------------------------------

## Unknown professions are dropped and values clamped to 1..PROF_VALUE_MAX; an unknown head-start profession becomes
## ""; talent rows naming an unknown talent are dropped (the row is open again); rested never below 0.
static func _sanitize_season_member(m: PartyMember, data: GameData) -> void:
	m.rested = maxi(0, m.rested)
	for pid: Variant in m.professions.keys():
		if not data.has_id("professions", str(pid)):
			_warn("profession '%s' of %s dropped (unknown)" % [str(pid), m.id])
			m.professions.erase(pid)
		else:
			m.professions[pid] = clampi(int(m.professions[pid]), 1, PROF_VALUE_MAX)
	if m.prof_head != "" and not data.has_id("professions", m.prof_head):
		_warn("head-start profession '%s' of %s dropped (unknown)" % [m.prof_head, m.id])
		m.prof_head = ""
	for row: Variant in m.talent_rows.keys():
		if not data.has_id("talents", str(m.talent_rows[row])):
			_warn("talent row %s of %s dropped (unknown talent '%s')" % [str(row), m.id, str(m.talent_rows[row])])
			m.talent_rows.erase(row)


## A season whose template is unknown keeps its block (a season never turns into a campaign by loading); warning.
## ST1-B: a tempo, mode or result outside SeasonState's lists falls back to calendar / net / "" (warning); a schedule
## that does not fit the format is only reported (SeasonRules stops at its end).
static func _sanitize_season(st: GameState, data: GameData) -> void:
	if st.season == null:
		return
	var s: SeasonState = st.season
	if not data.has_id("seasons", s.def_id):
		_warn("season template '%s' unknown (the season block is kept)" % s.def_id)
	if not SeasonState.TEMPOS.has(s.tempo):
		_warn("season tempo '%s' unknown → calendar" % s.tempo)
		s.tempo = "calendar"
	if not SeasonState.MODES.has(s.mode):
		_warn("season mode '%s' unknown → net" % s.mode)
		s.mode = "net"
	if not SeasonState.RESULTS.has(s.result):
		_warn("season result '%s' unknown → \"\"" % s.result)
		s.result = ""
	if s.collapse_utc.size() != s.format:
		_warn("season schedule has %d dates for %d floors" % [s.collapse_utc.size(), s.format])
