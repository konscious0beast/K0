class_name DungeonGenerator extends RefCounted
## Floor layout from data (handbuilt) or procedural generation (02_TECH §7.2).
## Deterministic: the only randomness is a RandomNumberGenerator derived from `floor_seed` (procedural attempt k uses
## SeedUtil.derive(floor_seed, "retry", k)); no global randi()/randf(), no Array.shuffle()/pick_random().

const MAX_ATTEMPTS: int = 20
const GROW_FAIL_LIMIT: int = 400              # failed growth tries before an attempt is abandoned
const GROW_DRAWS: int = 3                     # growth picks the newest of 3 random existing cells (skew, see _attempt)
const STAIRS_MIN_DEPTH_FRAC: float = 0.35     # depth(stairs) >= ceili(target × 0.35)
const QB_PATH_FRAC: float = 0.6               # quarter boss at path[roundi((size − 1) × 0.6)]
const SAFE_DEPTH_FRAC: float = 0.6            # first safe room: depth closest to 0.6 × depth(quarter boss)
const CHEST_OFFSET_RANGE: float = 4.0         # offset = randf_range(−4, 4) per axis
const CHEST_MIN_RADIUS: float = 2.0           # chests keep the room centre (group spawn) free
const CHEST_MIN_SPACING: float = 1.5          # two chests in one room
const SECOND_GROUP_OFFSET: Vector2 = Vector2(3.0, -3.0)   # second group in the same room (only when rooms run out)
const SAFE_THEMES: PackedStringArray = ["kiosk", "pumphouse", "signalbox"]
const SAFE_NAMES: Dictionary = {"kiosk": "Kiosk 24/7", "pumphouse": "Pumpenhaus", "signalbox": "Stellwerk"}


## def.layout not empty → from_layout(), else procedural.
static func generate(def: FloorDef, floor_seed: int) -> FloorLayout:
	if def == null:
		push_error("DungeonGenerator.generate: FloorDef is null (res://data/floors.json)")
		return null
	if def.has_layout():
		return from_layout(def, floor_seed)
	return _procedural(def, floor_seed)


## Handbuilt floor: cells, zones, gates, chests, groups, events, spawners, safe rooms and stairs 1:1 from def.layout;
## BFS depth from start (gates open), shortest path start → stairs (ties N, E, S, W), variant per cell in (y, x)
## order from `floor_seed`. An invalid layout is a data error (push_error, no retry).
static func from_layout(def: FloorDef, floor_seed: int) -> FloorLayout:
	var l: FloorLayout = FloorLayout.new()
	if def == null:
		push_error("DungeonGenerator.from_layout: FloorDef is null (res://data/floors.json)")
		return l
	var lay: Dictionary = def.layout
	l.floor_index = def.index
	l.seed = floor_seed
	l.width = int(def.grid.get("w", 8))
	l.height = int(def.grid.get("h", 8))
	for zv: Variant in lay.get("zones", []):
		var z: Dictionary = zv
		l.zones[str(z.get("id", ""))] = {"name": str(z.get("name", "")),
			"palette": (z.get("palette", {}) as Dictionary).duplicate(true)}
	for cv: Variant in lay.get("cells", []):
		var cd: Dictionary = cv
		var c: Vector2i = Vector2i(int(cd.get("x", 0)), int(cd.get("y", 0)))
		var rc: RoomCell = RoomCell.make(c, RoomCell.kind_from_string(str(cd.get("kind", "normal"))),
			str(cd.get("zone", "")), RoomCell.doors_from_string(str(cd.get("doors", ""))))
		l.cells[c] = rc
		match rc.kind:
			RoomCell.Kind.START:
				l.start = c
			RoomCell.Kind.STAIRS:
				l.stairs = c
			RoomCell.Kind.QUARTER_BOSS:
				l.quarter_boss = c
			RoomCell.Kind.FLOOR_BOSS:
				l.floor_boss = c
	var st: Dictionary = lay.get("stairs", {})
	if st.has("cell"):
		l.stairs = JsonUtil.arr_to_vec2i(st["cell"], l.stairs)
	for gv: Variant in lay.get("gates", []):
		var g: Dictionary = gv
		var gc: Vector2i = JsonUtil.arr_to_vec2i(g.get("cell", []), Vector2i(-999, -999))
		var gd: int = RoomCell.dir_bit(str(g.get("dir", "")))
		l.gates.append({"cell": gc, "dir": gd, "requires": str(g.get("requires", "")),
			"key": FloorLayout.gate_key(gc, gd)})
	_finish_graph(l)
	var vrng: RandomNumberGenerator = SeedUtil.make_rng(floor_seed)
	for c: Vector2i in l.sorted_cells():
		var vc: RoomCell = l.cells[c]
		vc.variant = vrng.randi_range(0, 3)
	for sv: Variant in lay.get("safe_rooms", []):
		var s: Dictionary = sv
		var sc: Vector2i = JsonUtil.arr_to_vec2i(s.get("cell", []), Vector2i(-999, -999))
		var sid: String = str(s.get("id", ""))
		l.safe_rooms.append(sc)
		l.safe_room_ids[sc] = sid
		l.safe_room_info[sid] = {"cell": sc, "name": str(s.get("name", "")), "theme": str(s.get("theme", "kiosk")),
			"shop": JsonUtil.to_str_array(s.get("shop", []))}
	for chv: Variant in lay.get("chests", []):
		var chd: Dictionary = chv
		var ch: ChestSpawn = ChestSpawn.new()
		ch.id = str(chd.get("id", ""))
		ch.cell = JsonUtil.arr_to_vec2i(chd.get("cell", []), Vector2i(-999, -999))
		ch.offset = JsonUtil.arr_to_vec2(chd.get("offset", []))
		ch.type = str(chd.get("type", "wood"))
		for item: Variant in chd.get("contents", []):
			ch.contents.append((item as Dictionary).duplicate(true))
		l.chests.append(ch)
	var boss_groups: Dictionary = {}
	for pv: Variant in lay.get("encounters_placed", []):
		var p: Dictionary = pv
		var gid: String = str(p.get("group_id", ""))
		var enc_id: String = str(p.get("enc_id", ""))
		var spawn: EnemySpawn = EnemySpawn.make(gid, JsonUtil.arr_to_vec2i(p.get("cell", []), Vector2i(-999, -999)),
			def.encounter(enc_id), JsonUtil.arr_to_vec2(p.get("offset", [])), StringName(str(p.get("state", "PATROL"))))
		spawn.encounter_id = enc_id
		spawn.can_turn = bool(p.get("turn", true))
		var suffix: String = gid.get_slice("_", 1)
		if suffix == "qb" or suffix == "fb":
			spawn.is_boss = true
			boss_groups[suffix] = true
		for wv: Variant in p.get("waypoints", []):
			spawn.waypoints.append(JsonUtil.arr_to_vec2(wv))
		l.enemies.append(spawn)
	# Bosses stand in their boss cells as f<i>_qb / f<i>_fb (§4.4.7, rule 8); data without the placement still works.
	if l.quarter_boss != Vector2i(-1, -1) and def.quarter_boss != "" and not boss_groups.has("qb"):
		l.enemies.append(_boss_spawn(def, "qb", def.quarter_boss, l.quarter_boss))
	if l.floor_boss != Vector2i(-1, -1) and def.floor_boss != "" and not boss_groups.has("fb"):
		l.enemies.append(_boss_spawn(def, "fb", def.floor_boss, l.floor_boss))
	for ev_v: Variant in lay.get("events", []):
		var ed: Dictionary = ev_v
		var ev: EventSpawn = EventSpawn.new()
		ev.id = str(ed.get("id", ""))
		ev.type = str(ed.get("type", ""))
		ev.cell = JsonUtil.arr_to_vec2i(ed.get("cell", []), Vector2i(-999, -999))
		ev.offset = JsonUtil.arr_to_vec2(ed.get("offset", []))
		ev.params = (ed.get("params", {}) as Dictionary).duplicate(true)
		l.events.append(ev)
	for spv: Variant in lay.get("spawners", []):
		var sp: Dictionary = spv
		l.spawners.append({"zone": str(sp.get("zone", "")), "pool": JsonUtil.to_str_array(sp.get("pool", [])),
			"interval_sec": int(sp.get("interval_sec", 90))})
	var errs: PackedStringArray = l.validate()
	if not errs.is_empty():
		push_error("DungeonGenerator: floor_%d layout invalid: %s (res://data/floors.json)" % [def.index,
			"; ".join(errs)])
	return l


# ======================================================================================================================
# Procedural (§7.2)
# ======================================================================================================================

static func _procedural(def: FloorDef, floor_seed: int) -> FloorLayout:
	var last: FloorLayout = null
	var last_errs: PackedStringArray = []
	for k in MAX_ATTEMPTS + 1:
		# Attempts 0..MAX_ATTEMPTS-1 apply every rule; one last relaxed attempt (k == MAX_ATTEMPTS) drops only the
		# stairs depth rule so a playable floor exists even for a FloorDef whose limits make that rule unlikely.
		var strict: bool = k < MAX_ATTEMPTS
		var rng: RandomNumberGenerator = SeedUtil.make_rng(SeedUtil.derive(floor_seed, "retry", k))
		var res: Dictionary = _attempt(def, floor_seed, rng, strict)
		last = res["layout"]
		var err: String = str(res["error"])
		if err != "":
			last_errs = PackedStringArray([err])
			continue
		last_errs = last.validate()
		if last_errs.is_empty():
			if not strict:
				push_warning("DungeonGenerator: floor_%d seed %d needed the relaxed attempt (stairs depth rule)"
					% [def.index, floor_seed])
			return last
	push_error("DungeonGenerator: floor_%d procedural generation failed after %d attempts: %s (res://data/floors.json)"
		% [def.index, MAX_ATTEMPTS, "; ".join(last_errs)])
	return last


## One attempt: {"layout": FloorLayout, "error": String ("" = complete, still to be validated)}.
static func _attempt(def: FloorDef, floor_seed: int, rng: RandomNumberGenerator, strict: bool = true) -> Dictionary:
	var w: int = maxi(1, int(def.grid.get("w", 8)))
	var h: int = maxi(1, int(def.grid.get("h", 8)))
	var l: FloorLayout = FloorLayout.new()
	l.floor_index = def.index
	l.seed = floor_seed
	l.width = w
	l.height = h
	var rmin: int = int(def.rooms.get("min", 6))
	var rmax: int = int(def.rooms.get("max", rmin))
	# 1. Target size and start.
	var target: int = clampi(rng.randi_range(rmin, maxi(rmin, rmax)), 2, w * h)
	l.start = Vector2i(w / 2, h - 1)
	l.cells[l.start] = RoomCell.make(l.start, RoomCell.Kind.START)
	# 2. Grow a tree (no loops).
	var order: Array[Vector2i] = [l.start]
	var fails: int = 0
	while l.cells.size() < target:
		# Random existing cell, skewed towards recently added ones (largest of GROW_DRAWS uniform draws): longer
		# corridors, so the stairs depth rule holds for ~97 % of the attempts on 8×8/9×9 floors (uniform: ~30 %);
		# still a branching tree.
		var pick: int = rng.randi_range(0, order.size() - 1)
		for _d in GROW_DRAWS - 1:
			pick = maxi(pick, rng.randi_range(0, order.size() - 1))
		var base: Vector2i = order[pick]
		var grown: bool = false
		for b: int in _shuffled_dirs(rng):
			var n: Vector2i = base + RoomCell.dir_offset(b)
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h or l.cells.has(n):
				continue
			var nc: RoomCell = RoomCell.make(n, RoomCell.Kind.NORMAL)
			nc.doors = RoomCell.opposite(b)
			var bc: RoomCell = l.cells[base]
			bc.doors |= b
			l.cells[n] = nc
			order.append(n)
			grown = true
			break
		if not grown:
			fails += 1
			if fails >= GROW_FAIL_LIMIT:
				return {"layout": l, "error": "tree growth failed (%d/%d rooms)" % [l.cells.size(), target]}
	# 3. Depth + stairs (deepest cell; ties: smallest y, then x).
	_set_depths(l)
	var stairs: Vector2i = l.start
	var best: int = -1
	for c: Vector2i in l.sorted_cells():
		var d: int = (l.cells[c] as RoomCell).depth
		if d > best:
			best = d
			stairs = c
	if stairs == l.start or (strict and best < ceili(target * STAIRS_MIN_DEPTH_FRAC)):
		return {"layout": l, "error": "stairs too shallow (depth %d, target %d)" % [best, target]}
	l.stairs = stairs
	var sc: RoomCell = l.cells[stairs]
	sc.kind = RoomCell.Kind.STAIRS
	# 4. Path (unique in a tree).
	_set_path(l)
	# 5. Quarter boss on the path.
	if def.quarter_boss != "":
		var qi: int = roundi((l.path.size() - 1) * QB_PATH_FRAC)
		if qi < 2 or qi >= l.path.size() or l.path[qi] == stairs:
			return {"layout": l, "error": "path too short for the quarter boss (%d cells)" % l.path.size()}
		l.quarter_boss = l.path[qi]
		var qc: RoomCell = l.cells[l.quarter_boss]
		qc.kind = RoomCell.Kind.QUARTER_BOSS
	# 6. Floor boss: new dead end next to the stairs, else deepest leaf off the path.
	if def.floor_boss != "":
		var fb: Vector2i = _place_floor_boss(l)
		if fb == Vector2i(-1, -1):
			return {"layout": l, "error": "no cell for the floor boss"}
		l.floor_boss = fb
	# 7. Safe rooms.
	var n_safe: int = clampi(def.safe_rooms, 0, 3)
	var safe_err: String = _place_safe_rooms(l, def, n_safe)
	if safe_err != "":
		return {"layout": l, "error": safe_err}
	# 8. Decoration variants for all cells.
	for c: Vector2i in l.sorted_cells():
		var vc: RoomCell = l.cells[c]
		vc.variant = rng.randi_range(0, 3)
	# 9. Chests (wood, contents from the chest table).
	var chest_err: String = _place_chests(l, def, floor_seed, rng)
	if chest_err != "":
		return {"layout": l, "error": chest_err}
	# 10. Enemy groups.
	var group_err: String = _place_groups(l, def, rng)
	if group_err != "":
		return {"layout": l, "error": group_err}
	if def.quarter_boss != "":
		l.enemies.append(_boss_spawn(def, "qb", def.quarter_boss, l.quarter_boss))
	if def.floor_boss != "":
		l.enemies.append(_boss_spawn(def, "fb", def.floor_boss, l.floor_boss))
	l.bounds = {"rooms": [rmin, rmax + (1 if def.floor_boss != "" else 0)],
		"chests": [int(def.chests.get("min", 0)), int(def.chests.get("max", 0))],
		"enemy_groups": [int(def.enemy_groups.get("min", 0)), int(def.enemy_groups.get("max", 0))],
		"safe_rooms": n_safe}
	return {"layout": l, "error": ""}


static func _place_floor_boss(l: FloorLayout) -> Vector2i:
	var st: RoomCell = l.cells[l.stairs]
	for b: int in RoomCell.DIR_BITS:
		var n: Vector2i = l.stairs + RoomCell.dir_offset(b)
		if n.x < 0 or n.y < 0 or n.x >= l.width or n.y >= l.height or l.cells.has(n):
			continue
		var fc: RoomCell = RoomCell.make(n, RoomCell.Kind.FLOOR_BOSS, "", RoomCell.opposite(b))
		fc.depth = st.depth + 1
		st.doors |= b
		l.cells[n] = fc
		return n
	var best: Vector2i = Vector2i(-1, -1)
	var best_depth: int = -1
	for c: Vector2i in l.sorted_cells():
		var rc: RoomCell = l.cells[c]
		if rc.kind != RoomCell.Kind.NORMAL or rc.on_path or not rc.is_leaf():
			continue
		if rc.depth > best_depth:
			best_depth = rc.depth
			best = c
	if best != Vector2i(-1, -1):
		var bc: RoomCell = l.cells[best]
		bc.kind = RoomCell.Kind.FLOOR_BOSS
	return best


## First safe room before the quarter boss (depth < depth(QB), leaves first, depth closest to 0.6 × depth(QB));
## further ones behind it (depth > depth(QB)), relaxed to any free normal cell if the tree has none there.
## Without a quarter boss depth(stairs) is the reference. Ids sr_f<i>_<k>, themes in turn kiosk/pumphouse/signalbox.
static func _place_safe_rooms(l: FloorLayout, def: FloorDef, n_safe: int) -> String:
	if n_safe <= 0:
		return ""
	var stairs_depth: int = (l.cells[l.stairs] as RoomCell).depth
	var ref: int = stairs_depth
	if l.quarter_boss != Vector2i(-1, -1):
		ref = (l.cells[l.quarter_boss] as RoomCell).depth
	for k in n_safe:
		var cand: Array[Vector2i] = []
		var goal: float = ref * SAFE_DEPTH_FRAC if k == 0 else (ref + stairs_depth) * 0.5
		for c: Vector2i in l.sorted_cells():
			var rc: RoomCell = l.cells[c]
			if rc.kind != RoomCell.Kind.NORMAL:
				continue
			if k == 0 and rc.depth >= ref:
				continue
			if k > 0 and rc.depth <= ref:
				continue
			cand.append(c)
		if cand.is_empty() and k > 0:
			for c: Vector2i in l.sorted_cells():
				if (l.cells[c] as RoomCell).kind == RoomCell.Kind.NORMAL:
					cand.append(c)
		if cand.is_empty():
			return "no cell for safe room %d" % k
		cand.sort_custom(func(p: Vector2i, q: Vector2i) -> bool: return _safe_key_less(l, p, q, goal))
		var c0: Vector2i = cand[0]
		var c0_cell: RoomCell = l.cells[c0]
		c0_cell.kind = RoomCell.Kind.SAFE
		var theme: String = SAFE_THEMES[k % SAFE_THEMES.size()]
		var sid: String = "sr_f%d_%d" % [def.index, k]
		l.safe_rooms.append(c0)
		l.safe_room_ids[c0] = sid
		l.safe_room_info[sid] = {"cell": c0, "name": str(SAFE_NAMES.get(theme, theme)), "theme": theme,
			"shop": def.shop.duplicate()}
	return ""


## Sort key: leaves first, then |depth − goal|, then y, then x.
static func _safe_key_less(l: FloorLayout, p: Vector2i, q: Vector2i, goal: float) -> bool:
	var a: RoomCell = l.cells[p]
	var b: RoomCell = l.cells[q]
	var la: int = 0 if a.is_leaf() else 1
	var lb: int = 0 if b.is_leaf() else 1
	if la != lb:
		return la < lb
	var da: float = absf(a.depth - goal)
	var db: float = absf(b.depth - goal)
	if da != db:
		return da < db
	if p.y != q.y:
		return p.y < q.y
	return p.x < q.x


static func _place_chests(l: FloorLayout, def: FloorDef, floor_seed: int, rng: RandomNumberGenerator) -> String:
	var n: int = rng.randi_range(int(def.chests.get("min", 0)), maxi(int(def.chests.get("min", 0)),
		int(def.chests.get("max", 0))))
	if n <= 0:
		return ""
	var cand: Array[Vector2i] = []
	for c: Vector2i in l.sorted_cells():
		if (l.cells[c] as RoomCell).kind == RoomCell.Kind.NORMAL:
			cand.append(c)
	if cand.is_empty():
		return "no cell for chests"
	_shuffle(cand, rng)
	# Leaves first (stable partition keeps the shuffled order inside both groups).
	var ordered: Array[Vector2i] = []
	for c: Vector2i in cand:
		if (l.cells[c] as RoomCell).is_leaf():
			ordered.append(c)
	for c: Vector2i in cand:
		if not (l.cells[c] as RoomCell).is_leaf():
			ordered.append(c)
	for k in n:
		var ch: ChestSpawn = ChestSpawn.new()
		ch.id = "f%d_c%d" % [def.index, k]
		ch.cell = ordered[k % ordered.size()]
		ch.type = "wood"
		var off: Vector2 = Vector2(rng.randf_range(-CHEST_OFFSET_RANGE, CHEST_OFFSET_RANGE),
			rng.randf_range(-CHEST_OFFSET_RANGE, CHEST_OFFSET_RANGE))
		ch.offset = _chest_offset(l, ch.cell, off)
		var crng: RandomNumberGenerator = SeedUtil.make_rng(SeedUtil.derive(floor_seed, "chest_table", k))
		var rolled: Array[LootReward] = LootRoller.roll_chest_table(def, crng)
		if rolled != null:
			for r: LootReward in rolled:
				if r != null:
					ch.contents.append({"kind": r.kind, "id": r.id, "amount": r.amount})
		l.chests.append(ch)
	return ""


## Keeps the room centre (group spawn) free and two chests of one room apart; no extra rng draws.
## Deviation from §7.2 step 9 (plain randf_range(−4, 4) per axis): an offset shorter than CHEST_MIN_RADIUS is pushed out
## to 2.5 m (a group stands at the room centre), a clash with another chest of the room (< CHEST_MIN_SPACING) is turned
## by 90° steps. Same two rng draws per chest as the spec, so the rng stream of later steps is unchanged.
static func _chest_offset(l: FloorLayout, cell: Vector2i, off: Vector2) -> Vector2:
	var o: Vector2 = off
	if o.length() < CHEST_MIN_RADIUS:
		o = Vector2(CHEST_MIN_RADIUS + 0.5, 0.0) if o.length() < 0.001 else o.normalized() * (CHEST_MIN_RADIUS + 0.5)
	for _t in 4:
		var clash: bool = false
		for other: ChestSpawn in l.chests:
			if other.cell == cell and other.offset.distance_to(o) < CHEST_MIN_SPACING:
				clash = true
				break
		if not clash:
			break
		o = Vector2(-o.y, o.x)
	return Vector2(clampf(o.x, -CHEST_OFFSET_RANGE, CHEST_OFFSET_RANGE),
		clampf(o.y, -CHEST_OFFSET_RANGE, CHEST_OFFSET_RANGE))


## n groups in NORMAL cells with depth >= 2, max. one per room (two when rooms run out); encounter weighted from the
## non-boss encounters whose [min_depth, max_depth] contains the relative depth of the room.
static func _place_groups(l: FloorLayout, def: FloorDef, rng: RandomNumberGenerator) -> String:
	var gmin: int = int(def.enemy_groups.get("min", 0))
	var n: int = rng.randi_range(gmin, maxi(gmin, int(def.enemy_groups.get("max", 0))))
	if n <= 0:
		return ""
	var cand: Array[Vector2i] = []
	for c: Vector2i in l.sorted_cells():
		var rc: RoomCell = l.cells[c]
		if rc.kind == RoomCell.Kind.NORMAL and rc.depth >= 2:
			cand.append(c)
	if cand.is_empty() or n > cand.size() * 2:
		return "not enough rooms for %d groups (%d)" % [n, cand.size()]
	_shuffle(cand, rng)
	var max_depth: int = 1
	for c: Vector2i in l.sorted_cells():
		max_depth = maxi(max_depth, (l.cells[c] as RoomCell).depth)
	for k in n:
		var cell: Vector2i = cand[k % cand.size()]
		var rel: float = (l.cells[cell] as RoomCell).depth / float(max_depth)
		var enc: EncounterDef = _pick_encounter(def, rel, rng)
		if enc == null:
			return "no non-boss encounter on floor_%d" % def.index
		var off: Vector2 = Vector2.ZERO if k < cand.size() else _second_group_offset(l, cell)
		l.enemies.append(EnemySpawn.make("f%d_g%d" % [def.index, k], cell, enc, off, &"PATROL"))
	return ""


## SECOND_GROUP_OFFSET turned in 90° steps until no chest of the cell is closer than CHEST_MIN_SPACING (a group must
## not spawn inside a chest's blocking body); none free → the rotation with the largest clearance. No rng draws.
static func _second_group_offset(l: FloorLayout, cell: Vector2i) -> Vector2:
	var best: Vector2 = SECOND_GROUP_OFFSET
	var best_clear: float = -1.0
	var o: Vector2 = SECOND_GROUP_OFFSET
	for _t in 4:
		var clear: float = INF
		for ch: ChestSpawn in l.chests:
			if ch.cell == cell:
				clear = minf(clear, ch.offset.distance_to(o))
		if clear >= CHEST_MIN_SPACING:
			return o
		if clear > best_clear:
			best_clear = clear
			best = o
		o = Vector2(-o.y, o.x)
	return best


static func _pick_encounter(def: FloorDef, rel: float, rng: RandomNumberGenerator) -> EncounterDef:
	var pool: Array[EncounterDef] = []
	for e: EncounterDef in def.encounters:
		if not e.boss and e.weight > 0 and rel >= e.min_depth - 0.0001 and rel <= e.max_depth + 0.0001:
			pool.append(e)
	if pool.is_empty():
		for e: EncounterDef in def.encounters:
			if not e.boss and e.weight > 0:
				pool.append(e)
	var flat: bool = false
	if pool.is_empty():
		flat = true
		for e: EncounterDef in def.encounters:
			if not e.boss:
				pool.append(e)
	if pool.is_empty():
		return null
	var total: int = 0
	for e: EncounterDef in pool:
		total += 1 if flat else e.weight
	var r: int = rng.randi_range(0, total - 1)
	for e: EncounterDef in pool:
		r -= 1 if flat else e.weight
		if r < 0:
			return e
	return pool[pool.size() - 1]


# ======================================================================================================================
# Shared helpers
# ======================================================================================================================

static func _boss_spawn(def: FloorDef, suffix: String, enc_id: String, cell: Vector2i) -> EnemySpawn:
	var s: EnemySpawn = EnemySpawn.make("f%d_%s" % [def.index, suffix], cell, def.encounter(enc_id), Vector2.ZERO,
		&"IDLE")
	s.encounter_id = enc_id
	s.is_boss = true
	s.can_turn = false
	return s


## Depth (gates open) + path + on_path.
static func _finish_graph(l: FloorLayout) -> void:
	_set_depths(l)
	_set_path(l)


static func _set_depths(l: FloorLayout) -> void:
	var dist: Dictionary = l.distances(l.start, PackedStringArray(), true)
	for c: Vector2i in l.sorted_cells():
		var rc: RoomCell = l.cells[c]
		rc.depth = int(dist.get(c, -1))


static func _set_path(l: FloorLayout) -> void:
	l.path = l.shortest_path(l.start, l.stairs)
	for c: Vector2i in l.sorted_cells():
		var rc: RoomCell = l.cells[c]
		rc.on_path = l.path.has(c)


static func _shuffled_dirs(rng: RandomNumberGenerator) -> PackedInt32Array:
	var dirs: PackedInt32Array = RoomCell.DIR_BITS.duplicate()
	for i in range(dirs.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t: int = dirs[i]
		dirs[i] = dirs[j]
		dirs[j] = t
	return dirs


## Fisher–Yates with the given rng (never Array.shuffle(): global RNG).
static func _shuffle(arr: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t: Vector2i = arr[i]
		arr[i] = arr[j]
		arr[j] = t
