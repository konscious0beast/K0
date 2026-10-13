class_name ZoneGenerator extends RefCounted
## Generator v2 (09 §3.6; ST1-C): the floors of the seasons with quarters (Viertel, FloorDef.zones) — DungeonGenerator
## hands every FloorDef with `zones` to generate(). The result is the same FloorLayout as every other floor (building,
## scene, saving stay identical); the rooms come from the art kit's modules like before (EnvKit per RoomSpec: kind,
## doors, decoration variant, the quarter's palette and its dressing style).
##
## One attempt (09 §3.6 Nr. 1–4):
##   1. Quarter after quarter (each in up to QUARTER_TRIES tries, a failed try rolled back): quarter 1 grows from the
##      start (bottom middle), quarter k from the exit of quarter k − 1 (its deepest room with room for the later
##      quarters) with today's tree method; the room counts drawn so that their sum stays inside the floor's `rooms`.
##      Its first loop comes while it grows (09 §3.6 Nr. 2: a door between two rooms ≥ 4 cell changes apart, else its
##      last room bridges two such rooms), a second one when the generator wants two; it keeps its programme rooms —
##      dead ends off its way entry → exit — and the last quarter's exit is the stairs (its deepest dead end).
##   2. The floor's key gate on the stairs' door (the key — itm_key_f<i> — drops from the Revier-Boss), the Revier-Boss
##      on the path in the last quarter (60 % of its path segment), the Etagenboss as a new dead end next to the stairs
##      (behind the gate, optional), the programme doors (gate "daily:<n>", up to five, 09 §3.3) on the kept dead ends,
##      one safe room per quarter near its entrance.
##   3. Groups per quarter (its pool, else the floor's pool by depth) with a level from the floor's band (09 §3.4:
##      the Pflichtweg at the band's middle, side ways up to band end + 1 towards the last quarter, the show boss's
##      elite group band end + 2, Revier-Boss band end, Etagenboss band end + 1), the show boss in a side quarter,
##      chests, the quarters' events, an event in every programme room, 4–6 gather nodes per quarter (positions for
##      ST1-E).
##   4. Danger per quarter (sleepers, 09 §5.3): the first calm, the last dangerous, the others restless.
## Then FloorLayout.validate() and check() (09 §3.6 Nr. 5) must be empty, else the next attempt. Not yet (ST1-C2):
## the Kulissenwände of 09 §3.6 Nr. 3 (Secrets reads hand-built FloorDef.layout.secrets only).
##
## Deterministic: the only randomness is attempt k's generator SeedUtil.derive(floor_seed, "zone_gen_f<index>", k) —
## a purpose per floor — and the chest tables' SeedUtil.derive(floor_seed, "chest_table", k) as in DungeonGenerator;
## integer math (offsets are drawn in whole centimetres); no global randi()/randf(), no Array.shuffle()/pick_random().
## Pure (core): no autoloads, no scene tree. Besides generate(): the levels of the groups (EnemyLevels scales the
## enemies of a season with them, 07 CR-32 d) and the programme doors (SeasonRules opens them with the daily
## programme).

const MAX_ATTEMPTS: int = 40
const QUARTER_TRIES: int = 8                  # tries per quarter in one attempt (rolled back, the generator runs on)
const GROW_FAIL_LIMIT: int = 600              # failed growth tries before a quarter try is abandoned
const GROW_DRAWS: int = 1                     # growth picks any room (DungeonGenerator: the newest of 3, corridors)
const STAIRS_MIN_DEPTH_PM: int = 300          # depth(stairs) × 1000 >= rooms × 300
const QB_SEGMENT_PM: int = 600                # Revier-Boss at 60 % of the last quarter's path segment
const LOOP_MIN_TREE_DIST: int = 4             # 09 §3.6 Nr. 2: loops shorten a way of at least 4 cell changes
const LOOPS_MIN: int = 1                      # loops per quarter (09 §3.6 Nr. 2)
const LOOPS_MAX: int = 2
const SPOTS_MAX: int = 5                      # programme doors per floor (09 §3.3: at most five points)
const NODES_DEFAULT: Vector2i = Vector2i(4, 6)   # gather nodes per quarter (09 §3.2)
const DAILY_PREFIX: String = "daily:"         # gate requirement of a programme door: "daily:<n>"
const KEY_PREFIX: String = "itm_key_f"        # the floor's key item: itm_key_f<index>
const DANGERS: PackedStringArray = ["calm", "restless", "dangerous"]   # 09 §5.3 (ruhig / unruhig / gefährlich)
const SAFE_THEMES: PackedStringArray = ["kiosk", "pumphouse", "signalbox"]
const SAFE_NAMES: Dictionary = {"kiosk": "Kiosk 24/7", "pumphouse": "Pumpenhaus", "signalbox": "Stellwerk"}
const CHEST_OFFSET_CM: int = 400              # offsets per axis ±4 m, whole centimetres (05 CR-12)
const CHEST_MIN_RADIUS: float = 2.5           # chests / events keep the room centre (group spawn) free
const PROP_MIN_SPACING: float = 1.6           # two props (chest, event) of one room
const DOOR_LANE_HALF: float = 2.6             # props keep the door lanes free: half width (the door is 4 m) …
const DOOR_LANE_DEPTH: float = 1.5            # … from this far off the room centre towards the door
const NODE_RADIUS_CM: Vector2i = Vector2i(300, 430)   # gather nodes in the border band of the room
const SECOND_GROUP_OFFSET: Vector2 = Vector2(3.0, -3.0)   # a second group in a room (only when rooms run out)
const ELITE_LEVELS: int = 2                   # 09 §3.4: elite = band end + 2
const SIDE_LEVELS: int = 1                    # 09 §3.4: side ways up to band end + 1
const EVENT_TYPES: PackedStringArray = ["photo_drone", "lost_candidate", "wheel", "broken_vending"]   # no lever


## The procedural layout of a FloorDef with quarters (DungeonGenerator.generate's switch). An attempt that breaks a
## rule is repeated with the next generator; after MAX_ATTEMPTS the last layout comes back with push_error.
static func generate(def: FloorDef, floor_seed: int) -> FloorLayout:
	if def == null:
		push_error("ZoneGenerator.generate: FloorDef is null (res://data/floors.json)")
		return null
	var last: FloorLayout = null
	var last_errs: PackedStringArray = []
	var purpose: String = "zone_gen_f%d" % def.index
	for k in MAX_ATTEMPTS:
		var rng: RandomNumberGenerator = SeedUtil.make_rng(SeedUtil.derive(floor_seed, purpose, k))
		var res: Dictionary = _attempt(def, floor_seed, rng)
		last = res["layout"]
		var err: String = str(res["error"])
		if err != "":
			last_errs = PackedStringArray([err])
			continue
		last_errs = last.validate()
		last_errs.append_array(check(last, def))
		if last_errs.is_empty():
			return last
	push_error("ZoneGenerator: floor_%d seed %d failed after %d attempts: %s (res://data/floors.json)"
		% [def.index, floor_seed, MAX_ATTEMPTS, "; ".join(last_errs)])
	return last


## The floor's key item (the Revier-Boss drops it; the gate in front of the stairs asks for it): itm_key_f<index>.
static func key_item(def: FloorDef) -> String:
	return KEY_PREFIX + str(def.index if def != null else 0)


## The requirement of programme door `n` (1–5): "daily:<n>".
static func programme_requirement(n: int) -> String:
	return DAILY_PREFIX + str(n)


## Programme door number of a gate requirement ("daily:3" → 3; 0 for any other requirement).
static func programme_number(requires: String) -> int:
	if not requires.begins_with(DAILY_PREFIX):
		return 0
	var tail: String = requires.trim_prefix(DAILY_PREFIX)
	return tail.to_int() if tail.is_valid_int() else 0


## Danger of the quarter of cell `c` for sleepers (09 §5.3): "calm" | "restless" | "dangerous"; "" outside quarters.
static func danger_at(l: FloorLayout, c: Vector2i) -> String:
	var rc: RoomCell = l.cell_at(c) if l != null else null
	if rc == null or not l.zones.has(rc.zone):
		return ""
	return str((l.zones[rc.zone] as Dictionary).get("danger", ""))


# ======================================================================================================================
# Check rules (09 §3.6 Nr. 5)
# ======================================================================================================================

## The rules of 09 §3.6 Nr. 5 on top of FloorLayout.validate() — [] = valid: every quarter reachable (every cell that no
## gate guards, all gates closed), every gather node reachable, the Pflichtweg start → Revier-Boss (gates closed) →
## stairs (only the key gate open) without the Etagenboss, the stairs not reachable without the key, a safe room in
## every quarter (one at most), stairs and bosses in the last quarter, the programme doors (≤ 5, numbered 1…n, dead
## ends with their event, off the path), groups never in the stairs or a programme room and their levels in the band,
## the show boss's group, 1–2 loops per quarter, every cell in a quarter of the floor with its danger.
static func check(l: FloorLayout, def: FloorDef) -> PackedStringArray:
	var errs: PackedStringArray = []
	if l == null or def == null or not def.has_zones():
		errs.append("check needs a layout of a floor with quarters")
		return errs
	var zone_ids: PackedStringArray = []
	for z: Dictionary in def.zones:
		zone_ids.append(str(z.get("id", "")))
	var last_zone: String = zone_ids[zone_ids.size() - 1]
	var spot_cells: Array[Vector2i] = []
	for p: Dictionary in l.programme:
		spot_cells.append(p["cell"] as Vector2i)
	var guarded: Array[Vector2i] = spot_cells.duplicate()
	if l.cells.has(l.stairs) and def.quarter_boss != "":
		guarded.append(l.stairs)
		if l.floor_boss != Vector2i(-1, -1) and l.linked(l.floor_boss).has(l.stairs):
			guarded.append(l.floor_boss)
	# Quarters and their danger.
	for c: Vector2i in l.sorted_cells():
		var rc: RoomCell = l.cells[c]
		if not zone_ids.has(rc.zone):
			errs.append("cell %s is in no quarter of the floor ('%s')" % [_p(c), rc.zone])
	for zid: String in zone_ids:
		var info: Dictionary = l.zones.get(zid, {})
		if not DANGERS.has(str(info.get("danger", ""))):
			errs.append("quarter %s has no danger" % zid)
	# Every quarter reachable; every cell no gate guards reachable with all gates closed.
	var open_reach: Dictionary = l.distances(l.start)
	var seen_zones: Dictionary = {}
	for c: Vector2i in l.sorted_cells():
		var rc: RoomCell = l.cells[c]
		if open_reach.has(c):
			seen_zones[rc.zone] = true
		elif not guarded.has(c):
			errs.append("cell %s (%s) is not reachable with the gates closed" % [_p(c), rc.zone])
	for zid: String in zone_ids:
		if not seen_zones.has(zid):
			errs.append("quarter %s is not reachable" % zid)
	for n: Dictionary in l.nodes:
		if not open_reach.has(n["cell"] as Vector2i):
			errs.append("gather node %s is not reachable" % str(n.get("id", "")))
	# The Pflichtweg: start → Revier-Boss → stairs, never through the Etagenboss.
	var no_fb: Array[Vector2i] = []
	if l.floor_boss != Vector2i(-1, -1):
		no_fb.append(l.floor_boss)
	if def.quarter_boss != "":
		if l.quarter_boss == Vector2i(-1, -1):
			errs.append("no Revier-Boss")
		else:
			if not l.distances(l.start, PackedStringArray(), false, no_fb).has(l.quarter_boss):
				errs.append("the Revier-Boss is not reachable without the key")
			var key_gate: Dictionary = _key_gate(l, def)
			if key_gate.is_empty():
				errs.append("no key gate (%s) in front of the stairs" % key_item(def))
			else:
				var with_key: PackedStringArray = [str(key_gate["key"])]
				if not l.distances(l.quarter_boss, with_key, false, no_fb).has(l.stairs):
					errs.append("the stairs are not reachable from the Revier-Boss with the key")
				if open_reach.has(l.stairs):
					errs.append("the stairs are reachable without the key")
			if (l.cells[l.quarter_boss] as RoomCell).zone != last_zone:
				errs.append("the Revier-Boss is not in the last quarter")
	if l.cells.has(l.stairs) and (l.cells[l.stairs] as RoomCell).zone != last_zone:
		errs.append("the stairs are not in the last quarter")
	if l.floor_boss != Vector2i(-1, -1):
		var fbc: RoomCell = l.cells.get(l.floor_boss, null) as RoomCell
		if fbc != null and (fbc.zone != last_zone or fbc.on_path):
			errs.append("the Etagenboss is not off the path in the last quarter")
	# Safe rooms: one per quarter (09 §3.2), at most one.
	var per_zone: Dictionary = {}
	for c: Vector2i in l.safe_rooms:
		var zid: String = (l.cells[c] as RoomCell).zone if l.cells.has(c) else ""
		per_zone[zid] = int(per_zone.get(zid, 0)) + 1
	for zid: String in zone_ids:
		var n_safe: int = int(per_zone.get(zid, 0))
		if n_safe > 1 or (def.safe_rooms >= zone_ids.size() and n_safe != 1):
			errs.append("quarter %s has %d safe rooms (one per quarter)" % [zid, n_safe])
	# Programme doors (09 §3.3).
	if l.programme.size() > SPOTS_MAX:
		errs.append("%d programme doors (at most %d)" % [l.programme.size(), SPOTS_MAX])
	for i in l.programme.size():
		var p: Dictionary = l.programme[i]
		var c: Vector2i = p["cell"]
		var rc: RoomCell = l.cell_at(c)
		if int(p.get("n", 0)) != i + 1:
			errs.append("programme door %d is numbered %d" % [i + 1, int(p.get("n", 0))])
		if rc == null or rc.door_count() != 1 or rc.on_path or rc.kind != RoomCell.Kind.NORMAL:
			errs.append("programme room %s is no dead end off the path" % _p(c))
			continue
		var g: Dictionary = l.gate_by_key(str(p.get("key", "")))
		if g.is_empty() or str(g["requires"]) != programme_requirement(i + 1) or l.gate_at(c, rc.doors).is_empty():
			errs.append("programme room %s has no door 'daily:%d'" % [_p(c), i + 1])
		var ev: EventSpawn = l.event_by_id(str(p.get("event", "")))
		if ev == null or ev.cell != c:
			errs.append("programme room %s has no event" % _p(c))
	# Groups.
	var band: PackedInt32Array = def.level_band
	var has_show: bool = _show_boss_encounter(def) != null
	var show_found: bool = false
	for e: EnemySpawn in l.enemies:
		var rc: RoomCell = l.cell_at(e.cell)
		if rc != null and not e.is_boss and (rc.kind == RoomCell.Kind.STAIRS or spot_cells.has(e.cell)):
			errs.append("group %s stands in the stairs or a programme room" % e.id)
		if def.has_band():
			if e.level < band[0] or e.level > band[1] + ELITE_LEVELS:
				errs.append("group %s level %d outside the band %d–%d (+%d)" % [e.id, e.level, band[0], band[1],
					ELITE_LEVELS])
		elif e.level != 0:
			errs.append("group %s has level %d on a floor without a band" % [e.id, e.level])
		var enc: EncounterDef = def.encounter(e.encounter_id)
		if enc != null and not enc.show_boss.is_empty():
			show_found = true
	if has_show and not show_found:
		errs.append("the show boss has no group")
	# Loops: 1–2 per quarter (edges beyond the tree inside one quarter).
	var edges: Dictionary = {}
	var cross: int = 0
	var total_edges: int = 0
	for c: Vector2i in l.sorted_cells():
		var rc: RoomCell = l.cells[c]
		for b: int in [RoomCell.DOOR_E, RoomCell.DOOR_S]:
			if not rc.has_door(b):
				continue
			total_edges += 1
			var nc: RoomCell = l.cell_at(c + RoomCell.dir_offset(b))
			if nc != null and nc.zone == rc.zone:
				edges[rc.zone] = int(edges.get(rc.zone, 0)) + 1
			else:
				cross += 1
	var loops_total: int = total_edges - (l.cells.size() - 1)
	for zid: String in zone_ids:
		var n_cells: int = 0
		for c: Vector2i in l.sorted_cells():
			if (l.cells[c] as RoomCell).zone == zid:
				n_cells += 1
		var loops: int = int(edges.get(zid, 0)) - (n_cells - 1)
		if loops < LOOPS_MIN or loops > LOOPS_MAX:
			errs.append("quarter %s has %d loops (%d–%d)" % [zid, loops, LOOPS_MIN, LOOPS_MAX])
	if cross != zone_ids.size() - 1 or loops_total < LOOPS_MIN * zone_ids.size():
		errs.append("the quarters are not a chain (%d doors between quarters, %d loops)" % [cross, loops_total])
	return errs


# ======================================================================================================================
# Levels (09 §3.4)
# ======================================================================================================================

## The middle of the floor's band (the Pflichtweg's level, 09 §3.4); 0 without a band.
static func band_middle(def: FloorDef) -> int:
	return (def.level_band[0] + def.level_band[1]) / 2 if def != null and def.has_band() else 0


# ======================================================================================================================
# Programme doors (09 §3.3)
# ======================================================================================================================

## SeasonRules._sync_daily's hook: the doors of the floor's programme points that are on air open (their gate keys join
## floor_run.opened_gates, in door order) — the exploration lifts a gate once its key is there (GateInteractable).
## Nothing on floors without quarters or without points.
static func open_programme_doors(state: GameState, data: GameData) -> void:
	var fr: FloorRun = state.floor_run if state != null else null
	if fr == null or state.season == null or fr.daily.is_empty() or data == null:
		return
	var def: FloorDef = data.floor_def(fr.index)
	if def == null or not def.has_zones():
		return
	for p: Dictionary in generate(def, fr.seed).programme:
		var key: String = str(p["key"])
		if int(p["n"]) <= fr.daily.size() and not fr.opened_gates.has(key):
			fr.opened_gates.append(key)


# ======================================================================================================================
# One attempt
# ======================================================================================================================

## {"layout": FloorLayout, "error": String ("" = complete, still to be validated)}.
static func _attempt(def: FloorDef, floor_seed: int, rng: RandomNumberGenerator) -> Dictionary:
	var w: int = maxi(3, int(def.grid.get("w", 10)))
	var h: int = maxi(3, int(def.grid.get("h", 10)))
	var l: FloorLayout = FloorLayout.new()
	l.floor_index = def.index
	l.seed = floor_seed
	l.width = w
	l.height = h
	var nq: int = def.zones.size()
	var zone_ids: PackedStringArray = []
	for q in nq:
		var z: Dictionary = def.zones[q]
		var zid: String = str(z.get("id", ""))
		zone_ids.append(zid)
		l.zones[zid] = {"name": str(z.get("name", "")), "palette": (z.get("palette", {}) as Dictionary).duplicate(true),
			"order": q, "danger": DANGERS[0] if q == 0 else (DANGERS[2] if q == nq - 1 else DANGERS[1]),
			"style": str(z.get("style", ""))}
	# 1. Sizes, the start, the quarters one after the other (each with room for its programme doors).
	var spots_want: PackedInt32Array = _spots_per_quarter(def)
	var targets: PackedInt32Array = _targets(def, rng)
	if targets.is_empty():
		return _fail(l, "the quarters' rooms miss the floor's rooms %d..%d" % [int(def.rooms.get("min", 0)),
			int(def.rooms.get("max", 0))])
	var total: int = 0
	for t: int in targets:
		total += t
	var fb_extra: int = 1 if def.floor_boss != "" else 0
	l.start = Vector2i(w / 2, h - 1)
	l.cells[l.start] = RoomCell.make(l.start, RoomCell.Kind.START, zone_ids[0])
	var members: Array = []                   # quarter → Array[Vector2i] in growth order
	var entries: Array[Vector2i] = []
	var reserved: Array = []                  # quarter → its programme rooms (Array[Vector2i])
	var exit: Vector2i = l.start
	for q in nq:
		var later: int = fb_extra
		for r in range(q + 1, nq):
			later += targets[r] + spots_want[r]
		var res: Dictionary = _quarter(l, q, zone_ids[q], exit, targets[q] + spots_want[q], later, spots_want[q],
			q == nq - 1, total, fb_extra > 0, rng)
		if res.has("error"):
			return _fail(l, str(res["error"]))
		members.append(res["own"])
		entries.append(res["entry"] as Vector2i)
		reserved.append(res["spots"])
		exit = res["exit"]
	# 2. Stairs: the last quarter's exit — its deepest dead end (with a free neighbour for the Etagenboss).
	var last_zone: String = zone_ids[nq - 1]
	l.stairs = exit
	_set_depths(l)
	(l.cells[l.stairs] as RoomCell).kind = RoomCell.Kind.STAIRS
	_set_path(l)
	# The Revier-Boss on the last quarter's path segment, the key gate on the stairs' door.
	if def.quarter_boss != "":
		var seg: Array[Vector2i] = []
		for i in range(l.path.size() - 1):
			if (l.cells[l.path[i]] as RoomCell).zone == last_zone:
				seg.append(l.path[i])
		if seg.is_empty():
			return _fail(l, "the path has no room in the last quarter before the stairs")
		var qb: Vector2i = seg[((seg.size() - 1) * QB_SEGMENT_PM + 500) / 1000]
		if l.path.find(qb) < 2:
			return _fail(l, "the Revier-Boss would stand next to the start")
		l.quarter_boss = qb
		(l.cells[qb] as RoomCell).kind = RoomCell.Kind.QUARTER_BOSS
		var before: Vector2i = l.path[l.path.size() - 2]
		var dir: int = _dir_between(before, l.stairs)
		l.gates.append({"cell": before, "dir": dir, "requires": key_item(def), "key": FloorLayout.gate_key(before, dir)})
	# The Etagenboss: a new dead end next to the stairs (behind the key gate).
	if fb_extra > 0:
		var fb: Vector2i = _attach(l, l.stairs, last_zone, RoomCell.Kind.FLOOR_BOSS, rng)
		if fb == Vector2i(-1, -1):
			return _fail(l, "no free cell next to the stairs for the Etagenboss")
		l.floor_boss = fb
	# Programme doors (09 §3.3): the dead ends each quarter kept off its way, the door to them gets gate "daily:<n>".
	var spots: Array[Vector2i] = []
	for q in nq:
		for spot: Vector2i in (reserved[q] as Array[Vector2i]):
			var base: Vector2i = l.linked(spot)[0]
			var n: int = spots.size() + 1
			var dir: int = _dir_between(base, spot)
			var key: String = FloorLayout.gate_key(base, dir)
			l.gates.append({"cell": base, "dir": dir, "requires": programme_requirement(n), "key": key})
			l.programme.append({"n": n, "cell": spot, "key": key, "event": "fev_f%d_p%d" % [def.index, n],
				"zone": zone_ids[q], "q": q})
			spots.append(spot)
	# Safe rooms: one per quarter (the first def.safe_rooms quarters) near its entrance.
	for q in mini(clampi(def.safe_rooms, 0, nq), nq):
		var c: Vector2i = _safe_cell(l, members[q] as Array[Vector2i], entries[q], spots)
		if c == Vector2i(-1, -1):
			return _fail(l, "no cell for the safe room of %s" % zone_ids[q])
		(l.cells[c] as RoomCell).kind = RoomCell.Kind.SAFE
		var sdata: Dictionary = def.zones[q].get("safe", {})
		var theme: String = str(sdata.get("theme", SAFE_THEMES[q % SAFE_THEMES.size()]))
		var sid: String = "sr_f%d_%d" % [def.index, q]
		l.safe_rooms.append(c)
		l.safe_room_ids[c] = sid
		l.safe_room_info[sid] = {"cell": c, "name": str(sdata.get("name", SAFE_NAMES.get(theme, theme))),
			"theme": theme, "shop": def.shop.duplicate()}
	# Decoration variants for all cells.
	for c: Vector2i in l.sorted_cells():
		(l.cells[c] as RoomCell).variant = rng.randi_range(0, 3)
	# 3. Content: bosses, the show boss, groups, chests, events, gather nodes.
	if def.quarter_boss != "":
		l.enemies.append(_boss_spawn(def, "qb", def.quarter_boss, l.quarter_boss, _boss_level(def, 0)))
	if def.floor_boss != "":
		l.enemies.append(_boss_spawn(def, "fb", def.floor_boss, l.floor_boss, _boss_level(def, 1)))
	var taken: Dictionary = {}                # cell → groups standing there
	var group_err: String = _place_groups(l, def, members, spots, taken, rng)
	if group_err != "":
		return _fail(l, group_err)
	_place_chests(l, def, floor_seed, spots, rng)
	var ev_err: String = _place_events(l, def, members, spots, taken, rng)
	if ev_err != "":
		return _fail(l, ev_err)
	_place_nodes(l, def, members, spots, rng)
	var show: int = 1 if _show_boss_encounter(def) != null else 0
	l.bounds = {"rooms": [int(def.rooms.get("min", 0)) + fb_extra + spots.size(),
			int(def.rooms.get("max", 0)) + fb_extra + spots.size()],
		"chests": [int(def.chests.get("min", 0)), int(def.chests.get("max", 0))],
		"enemy_groups": [int(def.enemy_groups.get("min", 0)), int(def.enemy_groups.get("max", 0)) + show],
		"safe_rooms": mini(clampi(def.safe_rooms, 0, nq), nq)}
	return {"layout": l, "error": ""}


static func _fail(l: FloorLayout, why: String) -> Dictionary:
	return {"layout": l, "error": why}


## Grows `own` (cells of `zone`, the first one placed) as a tree to `target` cells: a random cell of the quarter, skewed
## towards the newest (largest of GROW_DRAWS draws), its first free grid neighbour in a random direction order.
static func _grow(l: FloorLayout, own: Array[Vector2i], target: int, zone: String, rng: RandomNumberGenerator) -> bool:
	var fails: int = 0
	while own.size() < target:
		var pick: int = rng.randi_range(0, own.size() - 1)
		for _d in GROW_DRAWS - 1:
			pick = maxi(pick, rng.randi_range(0, own.size() - 1))
		var base: Vector2i = own[pick]
		var grown: bool = false
		for b: int in _shuffled_dirs(rng):
			var n: Vector2i = base + RoomCell.dir_offset(b)
			if not _free(l, n):
				continue
			l.cells[n] = RoomCell.make(n, RoomCell.Kind.NORMAL, zone, RoomCell.opposite(b))
			(l.cells[base] as RoomCell).doors |= b
			own.append(n)
			grown = true
			break
		if not grown:
			fails += 1
			if fails >= GROW_FAIL_LIMIT:
				return false
	return true


## Quarter `q` (09 §3.6 Nr. 1–2) in up to QUARTER_TRIES tries — a failed try is rolled back (its rooms and doors), the
## generator runs on: see _quarter_try. {"own", "entry", "exit", "spots"} or {"error"}.
static func _quarter(l: FloorLayout, q: int, zone: String, from: Vector2i, size: int, later: int, spots: int,
		last: bool, total: int, fb: bool, rng: RandomNumberGenerator) -> Dictionary:
	var res: Dictionary = {}
	for _t in QUARTER_TRIES:
		var doors: Dictionary = {}
		for c: Vector2i in l.cells:
			doors[c] = (l.cells[c] as RoomCell).doors
		res = _quarter_try(l, q, zone, from, size, later, spots, last, total, fb, rng)
		if not res.has("error"):
			return res
		for c: Vector2i in l.cells.keys():
			if not doors.has(c):
				l.cells.erase(c)
		for c: Vector2i in doors:
			(l.cells[c] as RoomCell).doors = int(doors[c])
	return res


## One try of quarter `q`: its entry (the start, else a free neighbour of the previous quarter's exit `from` with room
## for this quarter and the `later` ones), its `size` rooms (the first loop while it grows, a second one when the
## generator wants two), its exit (the last quarter: the stairs, its deepest dead end, deep enough for `total` rooms;
## else the next quarter's connection, its deepest room with room enough for the later quarters) and `spots` programme
## rooms: dead ends off its way entry → exit (the way of the Pflichtweg through this quarter — nothing later changes
## the doors inside it).
static func _quarter_try(l: FloorLayout, q: int, zone: String, from: Vector2i, size: int, later: int, spots: int,
		last: bool, total: int, fb: bool, rng: RandomNumberGenerator) -> Dictionary:
	var own: Array[Vector2i] = []
	var entry: Vector2i = l.start
	if q > 0:
		entry = _attach_wide(l, from, zone, size + later, rng)
		if entry == Vector2i(-1, -1):
			return {"error": "quarter %s has no connection cell" % zone}
	own.append(entry)
	if not _grow(l, own, size - 1, zone, rng):
		return {"error": "quarter %s stopped at %d of %d rooms" % [zone, own.size(), size]}
	if not _first_loop(l, own, zone, rng):
		return {"error": "quarter %s has no room for a loop" % zone}
	if rng.randi_range(LOOPS_MIN, LOOPS_MAX) > LOOPS_MIN:
		_add_loop(l, own, rng)
	_set_depths(l)
	var exit: Vector2i = _pick_stairs(l, zone, fb) if last else _pick_exit(l, own, later)
	if exit == Vector2i(-1, -1) or exit == entry:
		return {"error": "quarter %s has no exit" % zone}
	if last and (l.cells[exit] as RoomCell).depth * 1000 < total * STAIRS_MIN_DEPTH_PM:
		return {"error": "stairs too shallow (depth %d, %d rooms)" % [(l.cells[exit] as RoomCell).depth, total]}
	var way: Array[Vector2i] = l.shortest_path(entry, exit)
	var cand: Array[Vector2i] = []
	for c: Vector2i in own:
		var rc: RoomCell = l.cells[c]
		if rc.kind != RoomCell.Kind.NORMAL or rc.door_count() != 1 or rc.depth < 2 or way.has(c) or c == exit:
			continue
		if (l.cells[l.linked(c)[0]] as RoomCell).kind != RoomCell.Kind.NORMAL:
			continue
		cand.append(c)
	if cand.size() < spots:
		return {"error": "no dead end for programme door in %s (%d of %d)" % [zone, cand.size(), spots]}
	_shuffle(cand, rng)
	return {"own": own, "entry": entry, "exit": exit, "spots": cand.slice(0, spots)}


## A new NORMAL cell of `zone` on the free neighbour of `base` with the widest free area (counted up to `need`; ties:
## random order), joined by a door. (-1, -1) if `base` has no free neighbour.
static func _attach_wide(l: FloorLayout, base: Vector2i, zone: String, need: int,
		rng: RandomNumberGenerator) -> Vector2i:
	var pick: int = 0
	var pick_room: int = 0
	for b: int in _shuffled_dirs(rng):
		var n: Vector2i = base + RoomCell.dir_offset(b)
		if _free(l, n):
			var room: int = _flood(l, n, need)
			if room > pick_room:
				pick_room = room
				pick = b
	if pick == 0:
		return Vector2i(-1, -1)
	var e: Vector2i = base + RoomCell.dir_offset(pick)
	var ec: RoomCell = RoomCell.make(e, RoomCell.Kind.NORMAL, zone, RoomCell.opposite(pick))
	ec.depth = (l.cells[base] as RoomCell).depth + 1
	l.cells[e] = ec
	(l.cells[base] as RoomCell).doors |= pick
	return e


## The exit of a quarter towards the next one: its deepest room (ties: the order of growth, newest first; never the
## start) whose free neighbour opens a free area of at least `need` cells (the later quarters), else the one with the
## widest free area. (-1, -1) if no room of `own` has a free neighbour.
static func _pick_exit(l: FloorLayout, own: Array[Vector2i], need: int) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_depth: int = -1
	var widest: Vector2i = Vector2i(-1, -1)
	var widest_room: int = 0
	for i in range(own.size() - 1, -1, -1):
		var c: Vector2i = own[i]
		if (l.cells[c] as RoomCell).kind != RoomCell.Kind.NORMAL:
			continue
		var room: int = _free_room(l, c, need)
		if room <= 0:
			continue
		var d: int = (l.cells[c] as RoomCell).depth
		if room >= need and d > best_depth:
			best_depth = d
			best = c
		if room > widest_room:
			widest_room = room
			widest = c
	return best if best != Vector2i(-1, -1) else widest


## The largest free area (grid cells without a room, 4-connected) next to `c`, counted up to `cap`.
static func _free_room(l: FloorLayout, c: Vector2i, cap: int) -> int:
	var best: int = 0
	for b: int in RoomCell.DIR_BITS:
		var n: Vector2i = c + RoomCell.dir_offset(b)
		if _free(l, n):
			best = maxi(best, _flood(l, n, cap))
	return best


## The size of the free area around the free cell `from` (flood fill), counted up to `cap`.
static func _flood(l: FloorLayout, from: Vector2i, cap: int) -> int:
	var seen: Dictionary = {from: true}
	var queue: Array[Vector2i] = [from]
	var head: int = 0
	while head < queue.size() and seen.size() < cap:
		var c: Vector2i = queue[head]
		head += 1
		for b: int in RoomCell.DIR_BITS:
			var n: Vector2i = c + RoomCell.dir_offset(b)
			if not seen.has(n) and _free(l, n):
				seen[n] = true
				queue.append(n)
	return mini(seen.size(), cap)


## The stairs: the deepest dead end (one door, so the key gate closes it) of quarter `zone` (ties: smallest y, then x)
## — with a free grid neighbour when the Etagenboss hangs next to it (`free_needed`). (-1, -1) if none.
static func _pick_stairs(l: FloorLayout, zone: String, free_needed: bool) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_depth: int = -1
	for c: Vector2i in l.sorted_cells():
		var rc: RoomCell = l.cells[c]
		if rc.zone == zone and rc.kind == RoomCell.Kind.NORMAL and rc.door_count() == 1 and rc.depth > best_depth \
				and (not free_needed or _has_free_neighbour(l, c)):
			best_depth = rc.depth
			best = c
	return best


## Regular rooms per quarter (its programme rooms come on top): each between the quarter's min and max, their sum inside
## the floor's `rooms` — the sum drawn first, then shared out room by room to random quarters below their max. [] if
## the ranges miss each other (the validator refuses that data).
static func _targets(def: FloorDef, rng: RandomNumberGenerator) -> PackedInt32Array:
	var mins: PackedInt32Array = []
	var maxs: PackedInt32Array = []
	var lo: int = 0
	var hi: int = 0
	for z: Dictionary in def.zones:
		var rr: Dictionary = z.get("rooms", {"min": 10, "max": 14})
		var mn: int = int(rr.get("min", 10))
		var mx: int = maxi(mn, int(rr.get("max", 14)))
		mins.append(mn)
		maxs.append(mx)
		lo += mn
		hi += mx
	var t_lo: int = maxi(lo, int(def.rooms.get("min", 0)))
	var t_hi: int = mini(hi, int(def.rooms.get("max", hi)))
	if t_lo > t_hi:
		return PackedInt32Array()
	var rest: int = rng.randi_range(t_lo, t_hi) - lo
	var out: PackedInt32Array = mins.duplicate()
	while rest > 0:
		var open: PackedInt32Array = []
		for q in out.size():
			if out[q] < maxs[q]:
				open.append(q)
		var q: int = open[rng.randi_range(0, open.size() - 1)]
		out[q] += 1
		rest -= 1
	return out


## The programme doors per quarter (its `spots`), at most SPOTS_MAX on the floor (the first quarters first).
static func _spots_per_quarter(def: FloorDef) -> PackedInt32Array:
	var out: PackedInt32Array = []
	var left: int = SPOTS_MAX
	for z: Dictionary in def.zones:
		var n: int = clampi(int(z.get("spots", 0)), 0, left)
		out.append(n)
		left -= n
	return out


## A new cell of `kind` in `zone` on a free grid neighbour of `base` (random direction order), joined by a door;
## (-1, -1) if `base` has no free neighbour.
static func _attach(l: FloorLayout, base: Vector2i, zone: String, kind: RoomCell.Kind,
		rng: RandomNumberGenerator) -> Vector2i:
	for b: int in _shuffled_dirs(rng):
		var n: Vector2i = base + RoomCell.dir_offset(b)
		if not _free(l, n):
			continue
		var nc: RoomCell = RoomCell.make(n, kind, zone, RoomCell.opposite(b))
		nc.depth = (l.cells[base] as RoomCell).depth + 1
		l.cells[n] = nc
		(l.cells[base] as RoomCell).doors |= b
		return n
	return Vector2i(-1, -1)


## The safe room of a quarter: a NORMAL cell of `own` (neither a programme room nor the room in front of one, at most
## three doors — the safe door needs a wall), off the path first, then the closest to the quarter's entrance (2 doors
## away is best), leaves first.
static func _safe_cell(l: FloorLayout, own: Array[Vector2i], entrance: Vector2i, spots: Array[Vector2i]) -> Vector2i:
	var dist: Dictionary = l.distances(entrance, PackedStringArray(), true)
	var in_front: Array[Vector2i] = []
	for sp: Vector2i in spots:
		in_front.append_array(l.linked(sp))
	var best: Vector2i = Vector2i(-1, -1)
	var best_key: Array = []
	for c: Vector2i in own:
		var rc: RoomCell = l.cells[c]
		if rc.kind != RoomCell.Kind.NORMAL or spots.has(c) or in_front.has(c) or rc.door_count() > 3 \
				or not dist.has(c):
			continue
		var key: Array = [1 if rc.on_path else 0, absi(int(dist[c]) - 2), 0 if rc.is_leaf() else 1, c.y, c.x]
		if best_key.is_empty() or _less(key, best_key):
			best_key = key
			best = c
	return best


## The first loop of a quarter that still has one room to grow (09 §3.6 Nr. 2): a door between two of its rooms that
## lie LOOP_MIN_TREE_DIST or more cell changes apart (then the last room grows as usual), else a bridge — the last room
## on a free cell next to two rooms A and B of the quarter that lie LOOP_MIN_TREE_DIST or more apart: it hangs on A,
## the loop door joins it to B. false if neither is possible.
static func _first_loop(l: FloorLayout, own: Array[Vector2i], zone: String, rng: RandomNumberGenerator) -> bool:
	if _add_loop(l, own, rng):
		return _grow(l, own, own.size() + 1, zone, rng)
	var cand: Array = []                         # [a, bit a → f, b, bit f → b]
	for a: Vector2i in own:
		if not _loopable(l, a):
			continue
		var dist: Dictionary = {}
		for ba: int in RoomCell.DIR_BITS:
			var f: Vector2i = a + RoomCell.dir_offset(ba)
			if not _free(l, f):
				continue
			for bb: int in RoomCell.DIR_BITS:
				var b: Vector2i = f + RoomCell.dir_offset(bb)
				if b == a or not own.has(b) or not _loopable(l, b):
					continue
				if dist.is_empty():
					dist = l.distances(a, PackedStringArray(), true)
				if int(dist.get(b, 0)) >= LOOP_MIN_TREE_DIST:
					cand.append([a, ba, b, bb])
	if cand.is_empty():
		return false
	var pick: Array = cand[rng.randi_range(0, cand.size() - 1)]
	var pa: Vector2i = pick[0]
	var bit_a: int = int(pick[1])
	var pb: Vector2i = pick[2]
	var bit_b: int = int(pick[3])
	var fc: Vector2i = pa + RoomCell.dir_offset(bit_a)
	l.cells[fc] = RoomCell.make(fc, RoomCell.Kind.NORMAL, zone, RoomCell.opposite(bit_a) | bit_b)
	(l.cells[pa] as RoomCell).doors |= bit_a
	(l.cells[pb] as RoomCell).doors |= RoomCell.opposite(bit_b)
	own.append(fc)
	return true


## One loop in a quarter: a door between grid neighbours of `own` that are not joined yet and lie at least
## LOOP_MIN_TREE_DIST cell changes apart (both NORMAL — never the start or a boss room —, never a programme room,
## never a fourth door). false if the quarter has no such pair.
static func _add_loop(l: FloorLayout, own: Array[Vector2i], rng: RandomNumberGenerator) -> bool:
	var ok: Array = []
	for c: Vector2i in own:
		if not _loopable(l, c):
			continue
		var dist: Dictionary = {}
		for b: int in [RoomCell.DOOR_E, RoomCell.DOOR_S]:
			var n: Vector2i = c + RoomCell.dir_offset(b)
			if not own.has(n) or not _loopable(l, n) or (l.cells[c] as RoomCell).has_door(b):
				continue
			if dist.is_empty():
				dist = l.distances(c, PackedStringArray(), true)
			if int(dist.get(n, 0)) >= LOOP_MIN_TREE_DIST:
				ok.append([c, b, n])
	if ok.is_empty():
		return false
	var pick: Array = ok[rng.randi_range(0, ok.size() - 1)]
	var a: Vector2i = pick[0]
	var bit: int = int(pick[1])
	(l.cells[a] as RoomCell).doors |= bit
	(l.cells[pick[2] as Vector2i] as RoomCell).doors |= RoomCell.opposite(bit)
	return true


static func _loopable(l: FloorLayout, c: Vector2i) -> bool:
	var rc: RoomCell = l.cells.get(c, null) as RoomCell
	return rc != null and rc.kind == RoomCell.Kind.NORMAL and rc.door_count() < 3 and not _is_programme_room(l, c)


static func _is_programme_room(l: FloorLayout, c: Vector2i) -> bool:
	for p: Dictionary in l.programme:
		if (p["cell"] as Vector2i) == c:
			return true
	return false


# ======================================================================================================================
# Content
# ======================================================================================================================

## Revier-Boss band end, Etagenboss band end + 1 (09 §3.4); 0 without a band.
static func _boss_level(def: FloorDef, extra: int) -> int:
	return def.level_band[1] + extra if def.has_band() else 0


## The level of a regular group (09 §3.4): on the Pflichtweg the band's middle, off it from the middle (first quarter)
## up to band end + 1 (last quarter); the elite group of the show boss band end + 2. 0 without a band.
static func _group_level(def: FloorDef, q: int, nq: int, on_path: bool, elite: bool) -> int:
	if not def.has_band():
		return 0
	var mid: int = band_middle(def)
	if elite:
		return def.level_band[1] + ELITE_LEVELS
	if on_path or nq <= 1:
		return mid
	var top: int = def.level_band[1] + SIDE_LEVELS
	return mid + ((top - mid) * q + nq - 2) / (nq - 1)


static func _show_boss_encounter(def: FloorDef) -> EncounterDef:
	for e: EncounterDef in def.encounters:
		if not e.boss and not e.show_boss.is_empty():
			return e
	return null


## Groups (09 §3.2, §3.4): the show boss in a side quarter (middle quarters; on two-quarter floors the first), then n
## regular groups shared out by the quarters' sizes, in NORMAL cells with depth >= 2 (never a programme room), one per
## room (two when a quarter runs out of rooms). Encounters from the quarter's pool, else the floor's by relative depth.
static func _place_groups(l: FloorLayout, def: FloorDef, members: Array, spots: Array[Vector2i], taken: Dictionary,
		rng: RandomNumberGenerator) -> String:
	var nq: int = members.size()
	var k: int = 0
	var show: EncounterDef = _show_boss_encounter(def)
	if show != null:
		var cand: Array[Vector2i] = []
		for q in _side_quarters(nq):
			for c: Vector2i in (members[q] as Array[Vector2i]):
				var rc: RoomCell = l.cells[c]
				if rc.kind == RoomCell.Kind.NORMAL and not rc.on_path and rc.depth >= 2 and not spots.has(c):
					cand.append(c)
		if cand.is_empty():
			return "no side room for the show boss"
		_shuffle(cand, rng)
		var cell: Vector2i = cand[0]
		var sb: EnemySpawn = EnemySpawn.make("f%d_g%d" % [def.index, k], cell, show, Vector2.ZERO, &"PATROL")
		sb.level = _group_level(def, 0, nq, false, true)
		l.enemies.append(sb)
		taken[cell] = 1
		k += 1
	var gmin: int = int(def.enemy_groups.get("min", 0))
	var n: int = rng.randi_range(gmin, maxi(gmin, int(def.enemy_groups.get("max", 0))))
	var sizes: PackedInt32Array = []
	var total: int = 0
	for q in nq:
		sizes.append((members[q] as Array).size())
		total += sizes[q]
	var share: PackedInt32Array = []
	var given: int = 0
	for q in nq:
		var s: int = n * sizes[q] / maxi(1, total)
		share.append(s)
		given += s
	var qi: int = nq - 1
	while given < n:                          # the remainder from the last quarter backwards
		share[qi] += 1
		given += 1
		qi = qi - 1 if qi > 0 else nq - 1
	var max_depth: int = 1
	for c: Vector2i in l.sorted_cells():
		max_depth = maxi(max_depth, (l.cells[c] as RoomCell).depth)
	for q in nq:
		var cand: Array[Vector2i] = []
		for c: Vector2i in (members[q] as Array[Vector2i]):
			var rc: RoomCell = l.cells[c]
			if rc.kind == RoomCell.Kind.NORMAL and rc.depth >= 2 and not spots.has(c) and not taken.has(c):
				cand.append(c)
		if share[q] > 0 and (cand.is_empty() or share[q] > cand.size() * 2):
			return "not enough rooms for %d groups in %s (%d)" % [share[q], str(def.zones[q].get("id", "")),
				cand.size()]
		_shuffle(cand, rng)
		var pool: PackedStringArray = JsonUtil.to_str_array(def.zones[q].get("pool", []))
		for i in share[q]:
			var cell: Vector2i = cand[i % cand.size()]
			var rc: RoomCell = l.cells[cell]
			var enc: EncounterDef = _pick_encounter(def, pool, rc.depth * 1000 / max_depth, rng)
			if enc == null:
				return "no regular encounter on floor_%d" % def.index
			var off: Vector2 = Vector2.ZERO if i < cand.size() else SECOND_GROUP_OFFSET
			var g: EnemySpawn = EnemySpawn.make("f%d_g%d" % [def.index, k], cell, enc, off, &"PATROL")
			g.level = _group_level(def, q, nq, rc.on_path, false)
			l.enemies.append(g)
			taken[cell] = int(taken.get(cell, 0)) + 1
			k += 1
	return ""


## The side quarters (09 §3.6 Nr. 3: show boss, programme rooms): the middle ones; with two quarters the first.
static func _side_quarters(nq: int) -> PackedInt32Array:
	var out: PackedInt32Array = []
	for q in range(1, nq - 1):
		out.append(q)
	if out.is_empty():
		out.append(0)
	return out


## Weighted from the quarter's pool (weight > 0), else from the floor's regular encounters whose depth band holds the
## relative depth `rel_pm` (‰), else any regular one; never a boss, a show boss or a weight-0 encounter while others
## exist.
static func _pick_encounter(def: FloorDef, pool_ids: PackedStringArray, rel_pm: int,
		rng: RandomNumberGenerator) -> EncounterDef:
	var pool: Array[EncounterDef] = []
	for id: String in pool_ids:
		var e: EncounterDef = def.encounter(id)
		if e != null and _regular(e):
			pool.append(e)
	if pool.is_empty():
		for e: EncounterDef in def.encounters:
			var lo: int = roundi(e.min_depth * 1000.0)
			var hi: int = roundi(e.max_depth * 1000.0)
			if _regular(e) and rel_pm >= lo and rel_pm <= hi:
				pool.append(e)
	if pool.is_empty():
		for e: EncounterDef in def.encounters:
			if _regular(e):
				pool.append(e)
	if pool.is_empty():
		return null
	var total: int = 0
	for e: EncounterDef in pool:
		total += e.weight
	var r: int = rng.randi_range(0, total - 1)
	for e: EncounterDef in pool:
		r -= e.weight
		if r < 0:
			return e
	return pool[pool.size() - 1]


static func _regular(e: EncounterDef) -> bool:
	return not e.boss and e.show_boss.is_empty() and e.weight > 0


## Chests (wood, contents from the floor's chest table as in DungeonGenerator) in NORMAL cells, never a programme room;
## dead ends first, offsets off the room centre.
static func _place_chests(l: FloorLayout, def: FloorDef, floor_seed: int, spots: Array[Vector2i],
		rng: RandomNumberGenerator) -> void:
	var cmin: int = int(def.chests.get("min", 0))
	var n: int = rng.randi_range(cmin, maxi(cmin, int(def.chests.get("max", 0))))
	var cand: Array[Vector2i] = []
	for c: Vector2i in l.sorted_cells():
		if (l.cells[c] as RoomCell).kind == RoomCell.Kind.NORMAL and not spots.has(c):
			cand.append(c)
	if n <= 0 or cand.is_empty():
		return
	_shuffle(cand, rng)
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
		ch.offset = _prop_offset(l, ch.cell, rng)
		var crng: RandomNumberGenerator = SeedUtil.make_rng(SeedUtil.derive(floor_seed, "chest_table", k))
		for r: LootReward in LootRoller.roll_chest_table(def, crng):
			if r != null:
				ch.contents.append({"kind": r.kind, "id": r.id, "amount": r.amount})
		l.chests.append(ch)


## The events of every quarter (each template once, in a NORMAL room of its quarter without a group if possible) and
## one in every programme room (a template of its quarter, else of any quarter). Ids fev_f<i>_e<k> / fev_f<i>_p<n>.
static func _place_events(l: FloorLayout, def: FloorDef, members: Array, spots: Array[Vector2i], taken: Dictionary,
		rng: RandomNumberGenerator) -> String:
	var all_templates: Array[Dictionary] = []
	for z: Dictionary in def.zones:
		for t: Variant in (z.get("events", []) as Array):
			all_templates.append(t as Dictionary)
	var k: int = 0
	for q in members.size():
		var free: Array[Vector2i] = []
		var busy: Array[Vector2i] = []
		for c: Vector2i in (members[q] as Array[Vector2i]):
			var rc: RoomCell = l.cells[c]
			if rc.kind != RoomCell.Kind.NORMAL or spots.has(c) or c == l.start:
				continue
			if taken.has(c):
				busy.append(c)
			else:
				free.append(c)
		_shuffle(free, rng)
		_shuffle(busy, rng)
		var rooms: Array[Vector2i] = []
		rooms.append_array(free)
		rooms.append_array(busy)
		var templates: Array = def.zones[q].get("events", []) as Array
		for i in templates.size():
			if rooms.is_empty():
				return "no room for the events of %s" % str(def.zones[q].get("id", ""))
			var cell: Vector2i = rooms[i % rooms.size()]
			l.events.append(_event("fev_f%d_e%d" % [def.index, k], templates[i] as Dictionary, cell,
				_prop_offset(l, cell, rng)))
			k += 1
	for p: Dictionary in l.programme:
		var own: Array = def.zones[int(p["q"])].get("events", []) as Array
		var from: Array = own if not own.is_empty() else all_templates
		if from.is_empty():
			return "no event template for programme door %d" % int(p["n"])
		var t: Dictionary = from[rng.randi_range(0, from.size() - 1)]
		l.events.append(_event(str(p["event"]), t, p["cell"] as Vector2i, Vector2(0.0, 1.5)))
	return ""


static func _event(id: String, template: Dictionary, cell: Vector2i, offset: Vector2) -> EventSpawn:
	var ev: EventSpawn = EventSpawn.new()
	ev.id = id
	ev.type = str(template.get("type", ""))
	ev.cell = cell
	ev.offset = offset
	ev.params = (template.get("params", {}) as Dictionary).duplicate(true)
	return ev


## Gather nodes (09 §3.2; positions only — ST1-E brings their interaction): NODES_DEFAULT per quarter that names node
## kinds (`nodes`), in its NORMAL rooms (never a programme room), in the border band. Ids f<i>_n<k>.
static func _place_nodes(l: FloorLayout, def: FloorDef, members: Array, spots: Array[Vector2i],
		rng: RandomNumberGenerator) -> void:
	var k: int = 0
	for q in members.size():
		var kinds: PackedStringArray = JsonUtil.to_str_array(def.zones[q].get("nodes", []))
		if kinds.is_empty():
			continue
		var rooms: Array[Vector2i] = []
		for c: Vector2i in (members[q] as Array[Vector2i]):
			if (l.cells[c] as RoomCell).kind == RoomCell.Kind.NORMAL and not spots.has(c) and c != l.start:
				rooms.append(c)
		if rooms.is_empty():
			continue
		_shuffle(rooms, rng)
		var n: int = rng.randi_range(NODES_DEFAULT.x, NODES_DEFAULT.y)
		for i in n:
			var cell: Vector2i = rooms[i % rooms.size()]
			var side: int = RoomCell.DIR_BITS[rng.randi_range(0, 3)]
			var depth: int = rng.randi_range(NODE_RADIUS_CM.x, NODE_RADIUS_CM.y)
			var along: int = rng.randi_range(-NODE_RADIUS_CM.y, NODE_RADIUS_CM.y)
			var out: Vector2i = RoomCell.dir_offset(side)
			var cm: Vector2i = out * depth + Vector2i(-out.y, out.x) * along
			l.nodes.append({"id": "f%d_n%d" % [def.index, k], "node": kinds[rng.randi_range(0, kinds.size() - 1)],
				"cell": cell, "offset": Vector2(cm) / 100.0})
			k += 1


## A prop offset (chest, event) off the room centre: ±4 m per axis in whole centimetres, pushed out to CHEST_MIN_RADIUS
## and turned by 90° steps away from the other props of the room and out of its door lanes (no extra draws).
static func _prop_offset(l: FloorLayout, cell: Vector2i, rng: RandomNumberGenerator) -> Vector2:
	var o: Vector2 = Vector2(rng.randi_range(-CHEST_OFFSET_CM, CHEST_OFFSET_CM),
		rng.randi_range(-CHEST_OFFSET_CM, CHEST_OFFSET_CM)) / 100.0
	if o.length() < CHEST_MIN_RADIUS:
		o = Vector2(CHEST_MIN_RADIUS, 0.0) if o.length() < 0.001 else o.normalized() * CHEST_MIN_RADIUS
	var doors: int = (l.cells[cell] as RoomCell).doors
	for _t in 4:
		var clash: bool = _in_door_lane(doors, o)
		for ch: ChestSpawn in l.chests:
			if ch.cell == cell and ch.offset.distance_to(o) < PROP_MIN_SPACING:
				clash = true
		for ev: EventSpawn in l.events:
			if ev.cell == cell and ev.offset.distance_to(o) < PROP_MIN_SPACING:
				clash = true
		if not clash:
			break
		o = Vector2(-o.y, o.x)
	if _in_door_lane(doors, o):                  # every turn in a lane (a room with four doors): into a corner
		o = Vector2(3.2 if o.x >= 0.0 else -3.2, 3.2 if o.y >= 0.0 else -3.2)
	return Vector2(snappedf(clampf(o.x, -4.0, 4.0), 0.01), snappedf(clampf(o.y, -4.0, 4.0), 0.01))


## Whether room-local offset `o` (metres; y = grid y) stands in the lane of one of the `doors` (DOOR_* bits).
static func _in_door_lane(doors: int, o: Vector2) -> bool:
	for b: int in RoomCell.DIR_BITS:
		if doors & b == 0:
			continue
		var d: Vector2 = Vector2(RoomCell.dir_offset(b))
		if o.dot(d) > DOOR_LANE_DEPTH and absf(o.x * d.y - o.y * d.x) < DOOR_LANE_HALF:
			return true
	return false


static func _boss_spawn(def: FloorDef, suffix: String, enc_id: String, cell: Vector2i, level: int) -> EnemySpawn:
	var s: EnemySpawn = EnemySpawn.make("f%d_%s" % [def.index, suffix], cell, def.encounter(enc_id), Vector2.ZERO,
		&"IDLE")
	s.encounter_id = enc_id
	s.is_boss = true
	s.can_turn = false
	s.level = level
	return s


## The gate of the floor's key (the one in front of the stairs); {} if none.
static func _key_gate(l: FloorLayout, def: FloorDef) -> Dictionary:
	for g: Dictionary in l.gates:
		if str(g["requires"]) == key_item(def):
			return g
	return {}


# ======================================================================================================================
# Helpers
# ======================================================================================================================

static func _free(l: FloorLayout, c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < l.width and c.y < l.height and not l.cells.has(c)


static func _has_free_neighbour(l: FloorLayout, c: Vector2i) -> bool:
	for b: int in RoomCell.DIR_BITS:
		if _free(l, c + RoomCell.dir_offset(b)):
			return true
	return false


static func _dir_between(a: Vector2i, b: Vector2i) -> int:
	for bit: int in RoomCell.DIR_BITS:
		if a + RoomCell.dir_offset(bit) == b:
			return bit
	return 0


static func _set_depths(l: FloorLayout) -> void:
	var dist: Dictionary = l.distances(l.start, PackedStringArray(), true)
	for c: Vector2i in l.sorted_cells():
		(l.cells[c] as RoomCell).depth = int(dist.get(c, -1))


static func _set_path(l: FloorLayout) -> void:
	l.path = l.shortest_path(l.start, l.stairs)
	for c: Vector2i in l.sorted_cells():
		(l.cells[c] as RoomCell).on_path = l.path.has(c)


## Lexicographic a < b of two integer arrays of the same length.
static func _less(a: Array, b: Array) -> bool:
	for i in a.size():
		if int(a[i]) != int(b[i]):
			return int(a[i]) < int(b[i])
	return false


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


static func _p(c: Vector2i) -> String:
	return "(%d,%d)" % [c.x, c.y]
