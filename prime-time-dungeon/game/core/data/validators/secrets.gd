extends RefCounted
## 06 §2.7 (package A): rules for FloorDef.layout.secrets — Kulissenwände ("wall": closes an existing door until the
## strike / bark knocks it over) and Regie-Notizen ("note": interactable at a room-local offset). DataValidator
## normalizes each entry with SPEC (in _n_layout) and appends the errors of check() (in _check_layout). Static helper,
## no class_name (preloaded by data_validator.gd).

const SPEC: Array = [["id", "s"], ["kind", "s"], ["cell", "c2"], ["dir", "s", ""], ["offset", "v2", [0.0, 0.0]],
	["n", "i", 0], ["behind", "s", ""]]
const KINDS: PackedStringArray = ["wall", "note"]
const DIR_OFFSETS: Dictionary = {"N": Vector2i(0, -1), "E": Vector2i(1, 0), "S": Vector2i(0, 1), "W": Vector2i(-1, 0)}
const DIR_OPPOSITE: Dictionary = {"N": "S", "E": "W", "S": "N", "W": "E"}


## Errors as "<ctx>: <message>". `secrets` = normalized entries, `cells` = Vector2i → normalized cell dict, `gates` =
## the layout's data gates (a wall must not sit on a gated door), `max_offset` = room-local offset limit.
static func check(ctx: String, floor_index: int, secrets: Array, cells: Dictionary, gates: Array,
		max_offset: float) -> PackedStringArray:
	var errs: PackedStringArray = []
	var id_re: RegEx = RegEx.create_from_string("^sec_e%d_[a-z0-9_]+$" % floor_index)
	var ids: Dictionary = {}
	var walls: Dictionary = {}           # wall id → door key
	var gated: Dictionary = {}
	for g: Variant in gates:
		if g is Dictionary:
			gated[door_key(_cell(g["cell"]), str(g["dir"]))] = true
	var wall_doors: Dictionary = {}
	for i in secrets.size():
		var s: Dictionary = secrets[i]
		var sctx: String = "%s.secrets[%d]" % [ctx, i]
		var sid: String = str(s.get("id", ""))
		if id_re.search(sid) == null:
			errs.append("%s.id: must match sec_e%d_<name> (got '%s')" % [sctx, floor_index, sid])
		if ids.has(sid):
			errs.append("%s.id: duplicate secret id '%s'" % [sctx, sid])
		ids[sid] = str(s.get("kind", ""))
		var kind: String = str(s.get("kind", ""))
		if not KINDS.has(kind):
			errs.append("%s.kind: '%s' not in [%s]" % [sctx, kind, ", ".join(KINDS)])
			continue
		var pos: Vector2i = _cell(s.get("cell", []))
		if not cells.has(pos):
			errs.append("%s.cell: no cell at %s" % [sctx, str(pos)])
			continue
		if kind == "wall":
			var dir: String = str(s.get("dir", ""))
			if not DIR_OFFSETS.has(dir):
				errs.append("%s.dir: wall needs a door direction N/E/S/W (got '%s')" % [sctx, dir])
				continue
			if not str((cells[pos] as Dictionary).get("doors", "")).contains(dir):
				errs.append("%s.dir: cell %s has no door %s (a wall closes an existing door)" % [sctx, str(pos), dir])
				continue
			var dk: String = door_key(pos, dir)
			if gated.has(dk):
				errs.append("%s: door %s already has a gate" % [sctx, dk])
			if wall_doors.has(dk):
				errs.append("%s: door %s already has a wall" % [sctx, dk])
			wall_doors[dk] = true
			walls[sid] = dk
			if str(s.get("behind", "")) != "":
				errs.append("%s.behind: only notes can be behind a wall" % sctx)
		else:
			var off: Array = s.get("offset", [0.0, 0.0])
			if absf(float(off[0])) > max_offset or absf(float(off[1])) > max_offset:
				errs.append("%s.offset: |x|, |z| must be <= %.1f (room-local, got %s)" % [sctx, max_offset, str(off)])
			if int(s.get("n", 0)) < 1:
				errs.append("%s.n: note number must be >= 1" % sctx)
	var numbers: Dictionary = {}
	for i in secrets.size():
		var s2: Dictionary = secrets[i]
		if str(s2.get("kind", "")) != "note":
			continue
		var sctx2: String = "%s.secrets[%d]" % [ctx, i]
		var n: int = int(s2.get("n", 0))
		if n >= 1 and numbers.has(n):
			errs.append("%s.n: duplicate note number %d" % [sctx2, n])
		numbers[n] = true
		var behind: String = str(s2.get("behind", ""))
		if behind != "" and not walls.has(behind):
			errs.append("%s.behind: '%s' is not a wall of this floor" % [sctx2, behind])
	errs.append_array(_check_optional(ctx, cells, wall_doors))
	return errs


## Secrets are optional: every cell stays reachable from the start with all walls standing (gates count as open).
static func _check_optional(ctx: String, cells: Dictionary, wall_doors: Dictionary) -> PackedStringArray:
	var errs: PackedStringArray = []
	if wall_doors.is_empty():
		return errs
	var start: Vector2i = Vector2i(-999, -999)
	for pos: Variant in cells.keys():
		if str((cells[pos] as Dictionary).get("kind", "")) == "start":
			start = pos
	if start == Vector2i(-999, -999):
		return errs
	var reached: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for ch: String in str((cells[cur] as Dictionary).get("doors", "")):
			if not DIR_OFFSETS.has(ch) or wall_doors.has(door_key(cur, ch)):
				continue
			var nb: Vector2i = cur + (DIR_OFFSETS[ch] as Vector2i)
			if cells.has(nb) and not reached.has(nb):
				reached[nb] = true
				queue.append(nb)
	var missing: Array = []
	for pos2: Variant in cells.keys():
		if not reached.has(pos2):
			missing.append(str(pos2))
	if not missing.is_empty():
		missing.sort()
		errs.append("%s.secrets: cells %s are only reachable through a secret wall (secrets must stay optional)"
			% [ctx, ", ".join(missing)])
	return errs


## Same canonical door key as DataValidator.door_key (both sides of a door → one key).
static func door_key(cell: Vector2i, dir: String) -> String:
	if not DIR_OFFSETS.has(dir):
		return "%d,%d,%s" % [cell.x, cell.y, dir]
	var n: Vector2i = cell + (DIR_OFFSETS[dir] as Vector2i)
	if n.y < cell.y or (n.y == cell.y and n.x < cell.x):
		return "%d,%d,%s" % [n.x, n.y, str(DIR_OPPOSITE[dir])]
	return "%d,%d,%s" % [cell.x, cell.y, dir]


static func _cell(v: Variant) -> Vector2i:
	if v is Array and (v as Array).size() == 2:
		return Vector2i(int((v as Array)[0]), int((v as Array)[1]))
	if v is Vector2i:
		return v
	return Vector2i(-999, -999)
