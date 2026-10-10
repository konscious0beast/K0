class_name Secrets extends RefCounted
## E1 secrets (06 §2.7, package A): "Kulissenwände" (cracked scenery walls in a door opening — the field strike or the
## bark knocks them over, the door behind becomes a shortcut) and "Regie-Notizen" (hidden notes with M.O.D.'s
## backstage jokes, +15 followers each). Data: FloorDef.layout.secrets = [{"id": "sec_e<floor>_…", "kind": "wall" |
## "note", "cell": [x, y], "dir": "N|E|S|W" (wall: the door it closes), "offset": [x, z] (note), "n": int (note
## number), "behind": "<wall id>" (note: only reachable once that wall is down)}].
## A wall is a gate with requires "secret:<id>" in the FloorLayout (closed doors block BFS, minimap hides it); opening
## it puts its gate key into floor_run.opened_gates. Every opened secret id goes into GameState.flags["secrets"]
## (hash, save). Pure rules, no autoloads: Game.open_secret records {"t": "secret", "id"} and applies open(); RunSim
## and both replays apply the same check_open() / open().

const KINDS: PackedStringArray = ["wall", "note"]
const FLAG: String = "secrets"
const REQUIRES_PREFIX: String = "secret:"
const NOTE_FOLLOWERS: int = 15
const WALL_TAG: String = "secret_wall"     # M.O.D. line when a wall falls
const NOTE_TAG: String = "secret_note:"     # + n


## The secret entries of a floor (copies); [] for floors without layout.secrets.
static func list(def: FloorDef) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if def == null or def.layout.is_empty():
		return out
	for v: Variant in def.layout.get("secrets", []):
		if v is Dictionary:
			out.append((v as Dictionary).duplicate(true))
	return out


## Secret entry by id ({} if the floor has none with that id).
static func find(def: FloorDef, secret_id: String) -> Dictionary:
	for s: Dictionary in list(def):
		if str(s.get("id", "")) == secret_id:
			return s
	return {}


## Opened secret ids of the run (flags["secrets"], in opening order).
static func opened(state: GameState) -> PackedStringArray:
	var out: PackedStringArray = []
	if state == null:
		return out
	var raw: Variant = state.flags.get(FLAG, [])
	if raw is Array or raw is PackedStringArray:
		for v: Variant in raw:
			out.append(str(v))
	return out


static func is_open(state: GameState, secret_id: String) -> bool:
	return opened(state).has(secret_id)


## Gate key "x,y,D" of a wall entry ("" for notes / broken entries) — the same key FloorLayout.gate_key builds.
static func gate_key_of(secret: Dictionary) -> String:
	if str(secret.get("kind", "")) != "wall":
		return ""
	var c: Variant = secret.get("cell", [])
	if not (c is Array) or (c as Array).size() != 2:
		return ""
	return "%d,%d,%s" % [int((c as Array)[0]), int((c as Array)[1]), str(secret.get("dir", "N"))]


## "secret:<id>" → "<id>"; "" for any other gate requirement.
static func id_of_requirement(requires: String) -> String:
	return requires.trim_prefix(REQUIRES_PREFIX) if requires.begins_with(REQUIRES_PREFIX) else ""


static func is_secret_requirement(requires: String) -> bool:
	return requires.begins_with(REQUIRES_PREFIX)


## Can `secret_id` be opened now? "" | "no_floor" | "unknown_secret" | "already_open" | "locked" (a note behind a wall
## that is still standing). Range / line of sight are scene rules (grade A) — the result is what gets recorded.
static func check_open(state: GameState, def: FloorDef, secret_id: String) -> String:
	if state == null or state.floor_run == null or def == null:
		return "no_floor"
	var s: Dictionary = find(def, secret_id)
	if s.is_empty():
		return "unknown_secret"
	if is_open(state, secret_id):
		return "already_open"
	var behind: String = str(s.get("behind", ""))
	if behind != "" and not is_open(state, behind):
		return "locked"
	return ""


## Applies an opening that passed check_open(); {} (nothing changes) otherwise. Wall: its gate key joins
## floor_run.opened_gates. Returns {"id", "kind", "n", "gate_key", "followers", "mod_tag"} — followers / mod_tag are the
## show part (Game passes them to Show like the floor events; RunSim leaves them out like there).
static func open(state: GameState, def: FloorDef, secret_id: String) -> Dictionary:
	if check_open(state, def, secret_id) != "":
		return {}
	var s: Dictionary = find(def, secret_id)
	var ids: Array = []
	for v: String in opened(state):
		ids.append(v)
	ids.append(secret_id)
	state.flags[FLAG] = ids
	var kind: String = str(s.get("kind", ""))
	var out: Dictionary = {"id": secret_id, "kind": kind, "n": int(s.get("n", 0)), "gate_key": "", "followers": 0,
		"mod_tag": ""}
	if kind == "wall":
		var key: String = gate_key_of(s)
		if key != "" and not state.floor_run.opened_gates.has(key):
			state.floor_run.opened_gates.append(key)
		out["gate_key"] = key
		out["mod_tag"] = WALL_TAG
	elif kind == "note":
		out["followers"] = NOTE_FOLLOWERS
		out["mod_tag"] = NOTE_TAG + str(int(s.get("n", 0)))
	return out


## Notes of the floor: Vector2i(found, total) — "Regie-Notizen 1/3" in the floor summary.
static func notes_found(state: GameState, def: FloorDef) -> Vector2i:
	var found: int = 0
	var total: int = 0
	for s: Dictionary in list(def):
		if str(s.get("kind", "")) != "note":
			continue
		total += 1
		if is_open(state, str(s.get("id", ""))):
			found += 1
	return Vector2i(found, total)
