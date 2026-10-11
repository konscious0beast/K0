class_name FloorLayout extends RefCounted
## Result of layout loading / generation (02_TECH §7.1). Handbuilt (DungeonGenerator.from_layout) and procedural
## floors produce the same structure; everything after it (building, scene, saving) is identical.
## Pure data + graph helpers, no autoloads, no SceneTree.

const ROOM_SIZE: float = 16.0        # == EnvKit.ROOM_SIZE (test asserts)
const MAX_OFFSET: float = 4.5        # room-local offsets / waypoints (§7.3 clear zone)

var floor_index: int = 1
var seed: int = 0
var width: int = 0
var height: int = 0
var cells: Dictionary = {}           # Vector2i → RoomCell
var start: Vector2i = Vector2i.ZERO
var stairs: Vector2i = Vector2i.ZERO
var quarter_boss: Vector2i = Vector2i(-1, -1)   # (-1,-1) if floor has no quarter boss
var floor_boss: Vector2i = Vector2i(-1, -1)
var safe_rooms: Array[Vector2i] = []
var safe_room_ids: Dictionary = {}   # Vector2i → safe room id ("sr_…"; procedural: "sr_f<i>_<k>")
var safe_room_info: Dictionary = {}  # safe room id → {"cell", "name", "theme", "shop"}
var zones: Dictionary = {}           # zone id → {"name", "palette"} ({} procedural)
var gates: Array[Dictionary] = []    # [{"cell": Vector2i, "dir": int (DOOR_*), "requires": String, "key": "x,y,D"}]
var path: Array[Vector2i] = []       # start … stairs
var chests: Array[ChestSpawn] = []
var enemies: Array[EnemySpawn] = []
var events: Array[EventSpawn] = []
var spawners: Array[Dictionary] = [] # [{"zone", "pool": PackedStringArray, "interval_sec": int}]
## Procedural floors only: count limits of the FloorDef checked by validate()
## {"rooms": [min, max], "chests": [min, max], "enemy_groups": [min, max], "safe_rooms": int}; {} = handbuilt.
var bounds: Dictionary = {}


func cell_at(c: Vector2i) -> RoomCell:
	return cells.get(c, null) as RoomCell


## Vector3(c.x * 16.0, 0, c.y * 16.0) = room center.
func cell_to_world(c: Vector2i) -> Vector3:
	return Vector3(c.x * ROOM_SIZE, 0.0, c.y * ROOM_SIZE)


## roundi(p.x / 16.0), roundi(p.z / 16.0)
func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x / ROOM_SIZE), roundi(p.z / ROOM_SIZE))


## World position of a room-local XZ offset in cell `c` (y = 0).
func local_to_world(c: Vector2i, local: Vector2) -> Vector3:
	return cell_to_world(c) + Vector3(local.x, 0.0, local.y)


## Via doors in N, E, S, W order; closed gates block (a gate is open when its key is in `opened_gates`).
func neighbors(c: Vector2i, opened_gates: PackedStringArray = []) -> Array[Vector2i]:
	return _neighbors(c, opened_gates, false)


## Via doors in N, E, S, W order with every gate counted as open (depth, validation).
func linked(c: Vector2i) -> Array[Vector2i]:
	return _neighbors(c, PackedStringArray(), true)


## {} if none. Finds the gate from either side of the door.
func gate_at(c: Vector2i, dir: int) -> Dictionary:
	var other: Vector2i = c + RoomCell.dir_offset(dir)
	var back: int = RoomCell.opposite(dir)
	for g: Dictionary in gates:
		var gc: Vector2i = g["cell"]
		var gd: int = int(g["dir"])
		if (gc == c and gd == dir) or (gc == other and gd == back):
			return g
	return {}


## Gate by its runtime key "x,y,D" (the side the gate is defined on); {} if none.
func gate_by_key(key: String) -> Dictionary:
	for g: Dictionary in gates:
		if str(g["key"]) == key:
			return g
	return {}


## Runtime key "x,y,D" of a gate side.
static func gate_key(c: Vector2i, dir: int) -> String:
	return "%d,%d,%s" % [c.x, c.y, RoomCell.dir_letter(dir)]


## Zone palette merged over floor palette.
func zone_palette(c: Vector2i, floor_palette: Dictionary) -> Dictionary:
	var merged: Dictionary = floor_palette.duplicate(true)
	var rc: RoomCell = cell_at(c)
	if rc == null or not zones.has(rc.zone):
		return merged
	var zp: Dictionary = (zones[rc.zone] as Dictionary).get("palette", {})
	for k: Variant in zp.keys():
		merged[k] = zp[k]
	return merged


## BFS distances (in cell changes) from `from`: Vector2i → int. Closed gates block unless `gates_open`;
## `blocked` cells are never entered (e.g. the quarter boss for "reachable without it").
func distances(from: Vector2i, opened_gates: PackedStringArray = [], gates_open: bool = false,
		blocked: Array[Vector2i] = []) -> Dictionary:
	var dist: Dictionary = {}
	if not cells.has(from):
		return dist
	dist[from] = 0
	var queue: Array[Vector2i] = [from]
	var head: int = 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		for n: Vector2i in _neighbors(cur, opened_gates, gates_open):
			if dist.has(n) or blocked.has(n):
				continue
			dist[n] = int(dist[cur]) + 1
			queue.append(n)
	return dist


## Shortest path a → b (both included; BFS parent chain, ties by neighbour order N, E, S, W; gates open);
## [] if unreachable.
func shortest_path(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not cells.has(a) or not cells.has(b):
		return out
	var parent: Dictionary = {a: a}
	var queue: Array[Vector2i] = [a]
	var head: int = 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		if cur == b:
			break
		for n: Vector2i in linked(cur):
			if parent.has(n):
				continue
			parent[n] = cur
			queue.append(n)
	if not parent.has(b):
		return out
	var c: Vector2i = b
	while c != a:
		out.push_front(c)
		c = parent[c]
	out.push_front(a)
	return out


## Cells sorted by (y, x) — the canonical iteration order (variants, debug output).
func sorted_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for k: Variant in cells.keys():
		var kc: Vector2i = k
		out.append(kc)
	out.sort_custom(func(p: Vector2i, q: Vector2i) -> bool: return p.y < q.y or (p.y == q.y and p.x < q.x))
	return out


func enemy_by_id(group_id: String) -> EnemySpawn:
	for e: EnemySpawn in enemies:
		if e.id == group_id:
			return e
	return null


func chest_by_id(chest_id: String) -> ChestSpawn:
	for c: ChestSpawn in chests:
		if c.id == chest_id:
			return c
	return null


func event_by_id(event_id: String) -> EventSpawn:
	for e: EventSpawn in events:
		if e.id == event_id:
			return e
	return null


## Safe room id whose cell is `c` ("" if none).
func safe_room_at(c: Vector2i) -> String:
	return str(safe_room_ids.get(c, ""))


## Cells of a zone sorted by (y, x).
func zone_cells(zone_id: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Vector2i in sorted_cells():
		if (cells[c] as RoomCell).zone == zone_id:
			out.append(c)
	return out


## Invariants (§7.2): connectivity (gates open), symmetric doors, exactly one START/STAIRS, safe room(s) before the
## quarter boss reachable without it, no chest/group/event in START/SAFE/boss rooms, unique ids, offsets <= 4.5,
## consistent depth/path/boss/safe-room bookkeeping; procedural floors additionally the count limits in `bounds`.
func validate() -> PackedStringArray:
	var errs: PackedStringArray = []
	if cells.is_empty():
		errs.append("layout has no cells")
		return errs
	if width <= 0 or height <= 0:
		errs.append("invalid grid size %dx%d" % [width, height])
	var starts: Array[Vector2i] = []
	var stairs_cells: Array[Vector2i] = []
	var qb_cells: Array[Vector2i] = []
	var fb_cells: Array[Vector2i] = []
	var safe_cells: Array[Vector2i] = []
	for c: Vector2i in sorted_cells():
		var rc: RoomCell = cells[c]
		if rc == null:
			errs.append("cell %s is null" % _p(c))
			continue
		if rc.coord != c:
			errs.append("cell %s stores coord %s" % [_p(c), _p(rc.coord)])
		if c.x < 0 or c.y < 0 or c.x >= width or c.y >= height:
			errs.append("cell %s outside grid %dx%d" % [_p(c), width, height])
		if rc.variant < 0 or rc.variant > 3:
			errs.append("cell %s variant %d outside 0..3" % [_p(c), rc.variant])
		for b: int in RoomCell.DIR_BITS:
			if not rc.has_door(b):
				continue
			var n: Vector2i = c + RoomCell.dir_offset(b)
			var nc: RoomCell = cell_at(n)
			if nc == null:
				errs.append("cell %s has door %s into empty cell %s" % [_p(c), RoomCell.dir_letter(b), _p(n)])
			elif not nc.has_door(RoomCell.opposite(b)):
				errs.append("door %s of cell %s is not mirrored by %s" % [RoomCell.dir_letter(b), _p(c), _p(n)])
		match rc.kind:
			RoomCell.Kind.START:
				starts.append(c)
			RoomCell.Kind.STAIRS:
				stairs_cells.append(c)
			RoomCell.Kind.QUARTER_BOSS:
				qb_cells.append(c)
			RoomCell.Kind.FLOOR_BOSS:
				fb_cells.append(c)
			RoomCell.Kind.SAFE:
				safe_cells.append(c)
	if starts.size() != 1:
		errs.append("needs exactly 1 START cell (got %d)" % starts.size())
	elif starts[0] != start:
		errs.append("start %s is not the START cell %s" % [_p(start), _p(starts[0])])
	if stairs_cells.size() != 1:
		errs.append("needs exactly 1 STAIRS cell (got %d)" % stairs_cells.size())
	elif stairs_cells[0] != stairs:
		errs.append("stairs %s is not the STAIRS cell %s" % [_p(stairs), _p(stairs_cells[0])])
	_check_boss_cell(errs, "quarter boss", quarter_boss, qb_cells)
	_check_boss_cell(errs, "floor boss", floor_boss, fb_cells)
	_check_gates(errs)
	# Connectivity + depth (gates open).
	var dist: Dictionary = distances(start, PackedStringArray(), true)
	for c: Vector2i in sorted_cells():
		if not dist.has(c):
			errs.append("cell %s is not reachable from start" % _p(c))
		elif (cells[c] as RoomCell).depth != int(dist[c]):
			errs.append("cell %s depth %d != BFS distance %d" % [_p(c), (cells[c] as RoomCell).depth, int(dist[c])])
	_check_path(errs)
	_check_safe_rooms(errs, safe_cells)
	_check_placements(errs)
	for i in spawners.size():
		var sp: Dictionary = spawners[i]
		if str(sp.get("zone", "")) == "" or (sp.get("pool", PackedStringArray()) as PackedStringArray).is_empty():
			errs.append("spawner %d needs a zone and a non-empty pool" % i)
		elif zone_cells(str(sp["zone"])).is_empty():
			errs.append("spawner %d zone '%s' has no cells" % [i, str(sp["zone"])])
	if not bounds.is_empty():
		_check_bounds(errs)
	return errs


## ASCII map: S start, T stairs, Q quarter boss, B floor boss, H safe, G gate, . normal; doors "-"/"|", gated doors
## "="/"#". Followed by every spawn and the decoration variants, so equal strings mean equal layouts.
func to_debug_string() -> String:
	var lines: PackedStringArray = []
	lines.append("floor %d seed %d grid %dx%d start %s stairs %s qb %s fb %s" % [floor_index, seed, width, height,
		_p(start), _p(stairs), _p(quarter_boss), _p(floor_boss)])
	for y in height:
		var row: String = ""
		var below: String = ""
		for x in width:
			var c: Vector2i = Vector2i(x, y)
			var rc: RoomCell = cell_at(c)
			row += _cell_char(rc)
			if x < width - 1:
				row += _connector(c, RoomCell.DOOR_E, "-", "=")
			below += _connector(c, RoomCell.DOOR_S, "|", "#")
			if x < width - 1:
				below += " "
		lines.append(row.rstrip(" "))
		if y < height - 1:
			lines.append(below.rstrip(" "))
	var variants: PackedStringArray = []
	var depths: PackedStringArray = []
	for c: Vector2i in sorted_cells():
		var rc: RoomCell = cells[c]
		variants.append("%s:%d" % [_p(c), rc.variant])
		depths.append("%s:%d%s" % [_p(c), rc.depth, "*" if rc.on_path else ""])
	lines.append("variants " + " ".join(variants))
	lines.append("depth " + " ".join(depths))
	var path_s: PackedStringArray = []
	for c: Vector2i in path:
		path_s.append(_p(c))
	lines.append("path " + " ".join(path_s))
	for c: Vector2i in safe_rooms:
		var sid: String = safe_room_at(c)
		var info: Dictionary = safe_room_info.get(sid, {})
		lines.append("safe %s %s %s %s shop=%s" % [sid, _p(c), str(info.get("theme", "")), str(info.get("name", "")),
			",".join(info.get("shop", PackedStringArray()) as PackedStringArray)])
	for g: Dictionary in gates:
		lines.append("gate %s requires %s" % [str(g["key"]), str(g["requires"])])
	for ch: ChestSpawn in chests:
		var cont: PackedStringArray = []
		for d: Dictionary in ch.contents:
			cont.append("%s:%s:%d" % [str(d.get("kind", "")), str(d.get("id", "")), int(d.get("amount", 0))])
		lines.append("chest %s %s %s (%.3f,%.3f) [%s]" % [ch.id, _p(ch.cell), ch.type, ch.offset.x, ch.offset.y,
			",".join(cont)])
	for e: EnemySpawn in enemies:
		var wps: PackedStringArray = []
		for w: Vector2 in e.waypoints:
			wps.append("(%.2f,%.2f)" % [w.x, w.y])
		lines.append("group %s %s %s lead=%s boss=%s %s turn=%s (%.3f,%.3f) wp=[%s]" % [e.id, _p(e.cell),
			e.encounter_id, e.lead_enemy_id, str(e.is_boss), String(e.start_state), str(e.can_turn), e.offset.x,
			e.offset.y, ",".join(wps)])
	for ev: EventSpawn in events:
		lines.append("event %s %s %s (%.3f,%.3f)" % [ev.id, ev.type, _p(ev.cell), ev.offset.x, ev.offset.y])
	for sp: Dictionary in spawners:
		lines.append("spawner %s %s %ds" % [str(sp.get("zone", "")),
			",".join(sp.get("pool", PackedStringArray()) as PackedStringArray), int(sp.get("interval_sec", 0))])
	return "\n".join(lines)


# ======================================================================================================================
# Private
# ======================================================================================================================

func _neighbors(c: Vector2i, opened_gates: PackedStringArray, gates_open: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var rc: RoomCell = cell_at(c)
	if rc == null:
		return out
	for b: int in RoomCell.DIR_BITS:
		if not rc.has_door(b):
			continue
		var n: Vector2i = c + RoomCell.dir_offset(b)
		if not cells.has(n):
			continue
		if not gates_open:
			var g: Dictionary = gate_at(c, b)
			if not g.is_empty() and not opened_gates.has(str(g["key"])):
				continue
		out.append(n)
	return out


static func _p(c: Vector2i) -> String:
	return "(%d,%d)" % [c.x, c.y]


func _cell_char(rc: RoomCell) -> String:
	if rc == null:
		return " "
	match rc.kind:
		RoomCell.Kind.START:
			return "S"
		RoomCell.Kind.STAIRS:
			return "T"
		RoomCell.Kind.QUARTER_BOSS:
			return "Q"
		RoomCell.Kind.FLOOR_BOSS:
			return "B"
		RoomCell.Kind.SAFE:
			return "H"
		RoomCell.Kind.GATE:
			return "G"
	return "."


func _connector(c: Vector2i, dir: int, open_ch: String, gate_ch: String) -> String:
	var rc: RoomCell = cell_at(c)
	if rc == null or not rc.has_door(dir):
		return " "
	return gate_ch if not gate_at(c, dir).is_empty() else open_ch


func _check_boss_cell(errs: PackedStringArray, label: String, pos: Vector2i, kind_cells: Array[Vector2i]) -> void:
	if kind_cells.size() > 1:
		errs.append("more than one %s cell (%d)" % [label, kind_cells.size()])
	if pos == Vector2i(-1, -1):
		if not kind_cells.is_empty():
			errs.append("%s cell %s exists but the layout has no %s" % [label, _p(kind_cells[0]), label])
		return
	if not kind_cells.has(pos):
		errs.append("%s %s is not a %s cell" % [label, _p(pos), label])
	var found: bool = false
	for e: EnemySpawn in enemies:
		if e.is_boss and e.cell == pos:
			found = true
	if not found:
		errs.append("%s cell %s has no boss group" % [label, _p(pos)])


func _check_gates(errs: PackedStringArray) -> void:
	var seen: Dictionary = {}
	for g: Dictionary in gates:
		var gc: Vector2i = g.get("cell", Vector2i(-999, -999))
		var gd: int = int(g.get("dir", 0))
		var rc: RoomCell = cell_at(gc)
		if rc == null:
			errs.append("gate %s: no cell %s" % [str(g.get("key", "")), _p(gc)])
			continue
		if not rc.has_door(gd):
			errs.append("gate %s: cell %s has no door %s" % [str(g.get("key", "")), _p(gc), RoomCell.dir_letter(gd)])
		if str(g.get("key", "")) != gate_key(gc, gd):
			errs.append("gate key '%s' != '%s'" % [str(g.get("key", "")), gate_key(gc, gd)])
		if str(g.get("requires", "")) == "":
			errs.append("gate %s has no requirement" % gate_key(gc, gd))
		# Both sides of one door are the same door.
		var other: Vector2i = gc + RoomCell.dir_offset(gd)
		var canon: String = gate_key(gc, gd)
		if other.y < gc.y or (other.y == gc.y and other.x < gc.x):
			canon = gate_key(other, RoomCell.opposite(gd))
		if seen.has(canon):
			errs.append("two gates on the same door %s" % canon)
		seen[canon] = true


func _check_path(errs: PackedStringArray) -> void:
	if path.is_empty():
		errs.append("path is empty")
		return
	if path[0] != start:
		errs.append("path does not begin at start")
	if path[path.size() - 1] != stairs:
		errs.append("path does not end at the stairs")
	for i in range(1, path.size()):
		if not linked(path[i - 1]).has(path[i]):
			errs.append("path step %s → %s is not a door" % [_p(path[i - 1]), _p(path[i])])
	for c: Vector2i in sorted_cells():
		var rc: RoomCell = cells[c]
		if rc.on_path != path.has(c):
			errs.append("cell %s on_path flag does not match the path" % _p(c))


func _check_safe_rooms(errs: PackedStringArray, safe_cells: Array[Vector2i]) -> void:
	var ids_seen: Dictionary = {}
	for c: Vector2i in safe_rooms:
		var rc: RoomCell = cell_at(c)
		if rc == null or rc.kind != RoomCell.Kind.SAFE:
			errs.append("safe room %s is not a SAFE cell" % _p(c))
		var sid: String = safe_room_at(c)
		if sid == "":
			errs.append("safe room %s has no id" % _p(c))
			continue
		if ids_seen.has(sid):
			errs.append("duplicate safe room id '%s'" % sid)
		ids_seen[sid] = true
		var info: Dictionary = safe_room_info.get(sid, {})
		var info_cell: Vector2i = info.get("cell", Vector2i(-1, -1))
		if info.is_empty() or info_cell != c:
			errs.append("safe room '%s' info missing or with another cell" % sid)
	for c: Vector2i in safe_cells:
		if not safe_rooms.has(c):
			errs.append("SAFE cell %s is not listed as safe room" % _p(c))
	if quarter_boss == Vector2i(-1, -1) or safe_rooms.is_empty() or not cells.has(quarter_boss):
		return
	var blocked: Array[Vector2i] = [quarter_boss]
	var reach: Dictionary = distances(start, PackedStringArray(), true, blocked)
	var qb_depth: int = (cells[quarter_boss] as RoomCell).depth
	var any: bool = false
	for c: Vector2i in safe_rooms:
		if reach.has(c):
			any = true
		elif cells.has(c) and (cells[c] as RoomCell).depth < qb_depth:
			errs.append("safe room %s (before the quarter boss) is only reachable through it" % _p(c))
	if not any:
		errs.append("no safe room is reachable before the quarter boss")


func _check_placements(errs: PackedStringArray) -> void:
	var ids: Dictionary = {}
	for ch: ChestSpawn in chests:
		_check_id(errs, ids, ch.id, "chest")
		_check_spot(errs, "chest " + ch.id, ch.cell, ch.offset)
		if not ChestSpawn.TYPES.has(ch.type):
			errs.append("chest %s has unknown type '%s'" % [ch.id, ch.type])
		if ch.index() < 0 or not ch.id.begins_with("f%d_c" % floor_index):
			errs.append("chest id '%s' is not f%d_c<k>" % [ch.id, floor_index])
		_check_not_reserved(errs, "chest " + ch.id, ch.cell)
	for e: EnemySpawn in enemies:
		_check_id(errs, ids, e.id, "group")
		_check_spot(errs, "group " + e.id, e.cell, e.offset)
		if e.encounter_id == "":
			errs.append("group %s has no encounter" % e.id)
		if e.start_state != &"IDLE" and e.start_state != &"PATROL":
			errs.append("group %s has start state %s" % [e.id, String(e.start_state)])
		for w: Vector2 in e.waypoints:
			if absf(w.x) > MAX_OFFSET or absf(w.y) > MAX_OFFSET:
				errs.append("group %s waypoint (%.2f,%.2f) outside ±%.1f" % [e.id, w.x, w.y, MAX_OFFSET])
		var suffix: String = e.id.get_slice("_", 1)
		if suffix == "qb" or suffix == "fb":
			var want: Vector2i = quarter_boss if suffix == "qb" else floor_boss
			if e.cell != want:
				errs.append("boss group %s must stand in %s" % [e.id, _p(want)])
			if not e.is_boss:
				errs.append("boss group %s is not marked as boss" % e.id)
		else:
			_check_not_reserved(errs, "group " + e.id, e.cell)
	for ev: EventSpawn in events:
		_check_id(errs, ids, ev.id, "event")
		_check_spot(errs, "event " + ev.id, ev.cell, ev.offset)
		_check_not_reserved(errs, "event " + ev.id, ev.cell)


func _check_id(errs: PackedStringArray, ids: Dictionary, id: String, what: String) -> void:
	if id == "":
		errs.append("%s without id" % what)
	elif ids.has(id):
		errs.append("duplicate id '%s'" % id)
	ids[id] = true


func _check_spot(errs: PackedStringArray, what: String, c: Vector2i, off: Vector2) -> void:
	if not cells.has(c):
		errs.append("%s stands in empty cell %s" % [what, _p(c)])
	if absf(off.x) > MAX_OFFSET or absf(off.y) > MAX_OFFSET:
		errs.append("%s offset (%.2f,%.2f) outside ±%.1f" % [what, off.x, off.y, MAX_OFFSET])


func _check_not_reserved(errs: PackedStringArray, what: String, c: Vector2i) -> void:
	var rc: RoomCell = cell_at(c)
	if rc != null and rc.is_reserved():
		errs.append("%s stands in a %s cell %s" % [what, RoomCell.kind_to_string(rc.kind), _p(c)])


func _check_bounds(errs: PackedStringArray) -> void:
	var checks: Array = [["rooms", cells.size()], ["chests", chests.size()], ["enemy_groups", _placed_groups()]]
	for item: Array in checks:
		var key: String = item[0]
		var n: int = item[1]
		if not bounds.has(key):
			continue
		var mm: Array = bounds[key]
		if n < int(mm[0]) or n > int(mm[1]):
			errs.append("%s count %d outside %d..%d" % [key, n, int(mm[0]), int(mm[1])])
	if bounds.has("safe_rooms") and safe_rooms.size() != int(bounds["safe_rooms"]):
		errs.append("safe room count %d != %d" % [safe_rooms.size(), int(bounds["safe_rooms"])])


## Regular (non-boss, non-stray) groups.
func _placed_groups() -> int:
	var n: int = 0
	for e: EnemySpawn in enemies:
		if not e.is_boss and not e.is_stray():
			n += 1
	return n
