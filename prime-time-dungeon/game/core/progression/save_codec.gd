class_name SaveCodec extends RefCounted
## Save dict ↔ GameState, versioning, migration (02_TECH §6.1/§6.4).
##
## File layout (version 1): {"format": "ptd_save", "version": 1, "game_version", "saved_at_unix", "summary", "state"}.
## encode() leaves saved_at_unix at 0 (core has no clock, 05 §3.3 Nr. 6); Save stamps it before writing.
## decode() = migrate → validate (fatal errors → null) → GameState.from_dict → sanitize against GameData
## (unknown item/skill/box/enemy ids are dropped, values clamped; listed as "warning: …" in last_errors()).
##
## Version history:
## - v0 (pre-release prototype, no "format"/"version" or version 0): floor timer in float seconds
##   (`floor_run.time_left`, `floor_run.stats.time_used`), no `loot_seed`, no `summary`.
## - v1: timer in whole ticks (05 CR-3), `floor_run.loot_seed` (05 CR-11; derived from the run seed if missing).

const FORMAT: String = "ptd_save"
const VERSION: int = 1
const TICKS_PER_SEC: int = 30
const MSG_NEWER: String = "Spielstand stammt aus neuerer Version"

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
static func summary(state: GameState) -> Dictionary:
	if state == null:
		return {}
	var kai: PartyMember = state.member("kai")
	if kai == null and not state.party.is_empty():
		kai = state.party[0]
	return {
		"player_name": state.player_name,
		"floor_index": state.floor_run.index if state.floor_run != null else 1,
		"level": kai.level if kai != null else 1,
		"play_time_sec": floori(state.play_time_sec),
		"followers": state.show.followers if state.show != null else 0,
		"location": String(state.floor_run.location) if state.floor_run != null else "start",
	}


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
			if data.has_id("skills", s):
				skills.append(s)
			else:
				_warn("skill '%s' of %s dropped (unknown)" % [s, m.id])
		m.skills = skills
		for slot: String in ["weapon", "armor", "accessory"]:
			var item_id: String = str(m.equipment.get(slot, ""))
			if item_id != "" and (not data.has_id("items", item_id) or data.item(item_id).type != slot):
				_warn("equipment '%s' of %s dropped (unknown or wrong slot)" % [item_id, m.id])
				m.equipment[slot] = ""
		if m.class_id != "" and not data.has_id("classes", m.class_id):
			_warn("class '%s' of %s dropped (unknown)" % [m.class_id, m.id])
			m.class_id = ""
		_sanitize_b(m, data)                       # 06 package B: talents, species
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
