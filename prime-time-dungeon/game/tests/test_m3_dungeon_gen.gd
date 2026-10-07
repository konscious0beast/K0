extends TestCase
## M3 dungeon core (02_TECH §7.1/§7.2, §11.5): floor_1 layout valid + deterministic; procedural generator over 200 seeds
## (invariants, determinism, average run time < 20 ms); FloorLayout graph helpers and validate() negative cases;
## ExploreEvent serialization.

const SEEDS: int = 200
const MAX_AVG_MS: float = 20.0


# --- helpers ----------------------------------------------------------------------------------------------------------

func _encounters() -> Array:
	return [
		{"id": "enc_t_near", "enemies": ["enm_t_rat", "enm_t_rat"], "weight": 10, "min_depth": 0.0, "max_depth": 0.6},
		{"id": "enc_t_far", "enemies": ["enm_t_pigeon"], "weight": 5, "min_depth": 0.4, "max_depth": 1.0},
		{"id": "enc_t_qb", "enemies": ["enm_t_boss"], "weight": 0, "boss": true},
		{"id": "enc_t_fb", "enemies": ["enm_t_queen"], "weight": 0, "boss": true},
	]


## Procedural fixture floor (no layout).
func _proc_def(opts: Dictionary = {}) -> FloorDef:
	var d: Dictionary = {
		"id": "floor_2", "index": 2, "name": "Testetage", "theme": "mall", "timer_seconds": 900,
		"grid": {"w": 8, "h": 8}, "rooms": {"min": 12, "max": 18}, "safe_rooms": 2,
		"chests": {"min": 3, "max": 6}, "enemy_groups": {"min": 4, "max": 7},
		"chest_table": [{"kind": "credits", "id": "", "weight": 3, "min": 10, "max": 30},
			{"kind": "item", "id": "itm_bandage", "weight": 1, "min": 1, "max": 2}],
		"shop": ["itm_bandage"], "quarter_boss": "enc_t_qb", "floor_boss": "enc_t_fb",
		"encounters": _encounters(),
	}
	for k: Variant in opts.keys():
		d[k] = opts[k]
	return FloorDef.from_dict(d)


## Handbuilt fixture floor: 3×3 with a gate, a safe room, bosses and every placement type.
##   y=0  [B]-[T]-[ . ]
##              |    |
##   y=1  [H]-[ . ]-[Q ]        gate between (1,1) and (1,0) (requires itm_key_master)
##              |
##   y=2       [S ]
func _layout_def() -> FloorDef:
	var layout: Dictionary = {
		"zones": [{"id": "zone_a", "name": "A", "palette": {"floor": "#112233"}},
			{"id": "zone_b", "name": "B", "palette": {}}],
		"cells": [
			{"x": 0, "y": 0, "zone": "zone_b", "kind": "floor_boss", "doors": "E"},
			{"x": 1, "y": 0, "zone": "zone_b", "kind": "stairs", "doors": "WES"},
			{"x": 2, "y": 0, "zone": "zone_b", "kind": "normal", "doors": "WS"},
			{"x": 0, "y": 1, "zone": "zone_a", "kind": "safe", "doors": "E"},
			{"x": 1, "y": 1, "zone": "zone_a", "kind": "normal", "doors": "NESW"},
			{"x": 2, "y": 1, "zone": "zone_a", "kind": "quarter_boss", "doors": "NW"},
			{"x": 1, "y": 2, "zone": "zone_a", "kind": "start", "doors": "N"},
		],
		"gates": [{"cell": [1, 1], "dir": "N", "requires": "itm_key_master"}],
		"encounters_placed": [
			{"group_id": "f1_g0", "enc_id": "enc_t_near", "cell": [1, 1], "offset": [0.0, -2.5], "state": "IDLE",
				"turn": false, "waypoints": []},
			{"group_id": "f1_g1", "enc_id": "enc_t_far", "cell": [2, 0], "offset": [0.0, 0.0], "state": "PATROL",
				"turn": true, "waypoints": [[-4.0, -4.0], [4.0, -4.0], [4.0, 4.0]]},
			{"group_id": "f1_qb", "enc_id": "enc_t_qb", "cell": [2, 1], "offset": [0.0, 0.0], "state": "IDLE",
				"turn": true, "waypoints": []},
			{"group_id": "f1_fb", "enc_id": "enc_t_fb", "cell": [0, 0], "offset": [0.0, 0.0], "state": "IDLE",
				"turn": true, "waypoints": []},
		],
		"chests": [{"id": "f1_c0", "cell": [1, 1], "offset": [3.5, 2.0], "type": "wood", "contents": []},
			{"id": "f1_c1", "cell": [2, 0], "offset": [-3.5, -3.5], "type": "locked",
				"contents": [{"kind": "item", "id": "itm_wpn_fire_axe", "amount": 1}]}],
		"events": [{"id": "fev_t_drone", "type": "photo_drone", "cell": [2, 0], "offset": [2.0, 0.0],
			"params": {"pose_hype": 15, "pose_followers": 20, "smash_credits": 30, "smash_hype": -5}}],
		"spawners": [{"zone": "zone_a", "pool": ["enc_t_near"], "interval_sec": 90}],
		"safe_rooms": [{"id": "sr_t_kiosk", "cell": [0, 1], "name": "Kiosk", "theme": "kiosk",
			"shop": ["itm_bandage"]}],
		"stairs": {"cell": [1, 0]},
	}
	return FloorDef.from_dict({"id": "floor_1", "index": 1, "name": "Fixture", "theme": "metro", "timer_seconds": 600,
		"grid": {"w": 3, "h": 3}, "quarter_boss": "enc_t_qb", "floor_boss": "enc_t_fb", "encounters": _encounters(),
		"layout": layout, "palette": {"floor": "#3a3f4b", "wall": "#5b6270", "accent": "#ff2e88"}})


## Map part of to_debug_string(): the grid lines between the header line (it names the seed) and the variants.
static func _map_part(s: String) -> String:
	var idx: int = s.find("\nvariants ")
	var head: int = s.find("\n")
	return s.substr(head + 1, idx - head - 1) if idx > head and head >= 0 else s


func _edge_count(l: FloorLayout) -> int:
	var n: int = 0
	for c: Vector2i in l.sorted_cells():
		n += (l.cells[c] as RoomCell).door_count()
	return n / 2


## Independent re-check of the §7.2 procedural rules (on top of validate()).
func _check_procedural(l: FloorLayout, def: FloorDef, tag: String) -> void:
	var w: int = int(def.grid["w"])
	var h: int = int(def.grid["h"])
	assert_eq(l.start, Vector2i(w / 2, h - 1), tag + " start")
	assert_eq(_edge_count(l), l.cells.size() - 1, tag + " tree (no loops)")
	var fb_extra: int = 0
	if def.floor_boss != "":
		var fbc: RoomCell = l.cell_at(l.floor_boss)
		assert_not_null(fbc, tag + " floor boss cell")
		if fbc != null:
			assert_true(fbc.is_leaf(), tag + " floor boss is a dead end")
			assert_false(fbc.on_path, tag + " floor boss off the path")
			if l.linked(l.floor_boss).has(l.stairs) and fbc.depth == l.cell_at(l.stairs).depth + 1:
				fb_extra = 1
	var target: int = l.cells.size() - fb_extra
	assert_between(target, int(def.rooms["min"]), int(def.rooms["max"]), tag + " room count")
	var stairs_depth: int = l.cell_at(l.stairs).depth
	assert_true(stairs_depth >= ceili(target * DungeonGenerator.STAIRS_MIN_DEPTH_FRAC), tag + " stairs depth")
	for c: Vector2i in l.sorted_cells():
		var rc: RoomCell = l.cells[c]
		if rc.kind != RoomCell.Kind.FLOOR_BOSS:
			assert_true(rc.depth <= stairs_depth, tag + " stairs is the deepest cell")
	if def.quarter_boss != "":
		var qi: int = l.path.find(l.quarter_boss)
		assert_true(qi >= 2, tag + " quarter boss on the path, index >= 2")
		assert_ne(l.quarter_boss, l.stairs, tag + " quarter boss != stairs")
		assert_eq(qi, roundi((l.path.size() - 1) * DungeonGenerator.QB_PATH_FRAC), tag + " quarter boss index")
	assert_len(l.safe_rooms, clampi(def.safe_rooms, 0, 3), tag + " safe rooms")
	if not l.safe_rooms.is_empty():
		var ref: int = stairs_depth
		if l.quarter_boss != Vector2i(-1, -1):
			ref = l.cell_at(l.quarter_boss).depth
		assert_lt(l.cell_at(l.safe_rooms[0]).depth, ref, tag + " first safe room before the quarter boss")
		assert_eq(l.safe_room_ids[l.safe_rooms[0]], "sr_f%d_0" % def.index, tag + " safe room id")
	var regular: int = 0
	for e: EnemySpawn in l.enemies:
		if e.is_boss:
			continue
		regular += 1
		assert_true(l.cell_at(e.cell).depth >= 2, tag + " group depth >= 2")
		assert_eq(e.start_state, &"PATROL", tag + " group state")
		assert_false(def.encounter(e.encounter_id) == null, tag + " group encounter exists")
		assert_false(def.encounter(e.encounter_id).boss, tag + " group encounter is not a boss")
	assert_between(regular, int(def.enemy_groups["min"]), int(def.enemy_groups["max"]), tag + " group count")
	assert_between(l.chests.size(), int(def.chests["min"]), int(def.chests["max"]), tag + " chest count")
	for i in l.chests.size():
		var ch: ChestSpawn = l.chests[i]
		assert_eq(ch.id, "f%d_c%d" % [def.index, i], tag + " chest id")
		assert_eq(ch.type, "wood", tag + " chest type")
		assert_eq(l.cell_at(ch.cell).kind, RoomCell.Kind.NORMAL, tag + " chest in a NORMAL cell")
		assert_true(ch.offset.length() >= DungeonGenerator.CHEST_MIN_RADIUS - 0.001, tag + " chest off the centre")
	assert_eq(_group_chest_clashes(l), 0, tag + " no group within CHEST_MIN_SPACING of a chest of its room")


## Group/chest pairs of one cell closer than CHEST_MIN_SPACING (a group would spawn inside the chest's blocker).
static func _group_chest_clashes(l: FloorLayout) -> int:
	var n: int = 0
	for e: EnemySpawn in l.enemies:
		for ch: ChestSpawn in l.chests:
			if ch.cell == e.cell and ch.offset.distance_to(e.offset) < DungeonGenerator.CHEST_MIN_SPACING - 0.001:
				n += 1
	return n


# --- tests ------------------------------------------------------------------------------------------------------------

func test_room_size_matches_env_kit() -> void:
	assert_almost(FloorLayout.ROOM_SIZE, EnvKit.ROOM_SIZE)


func test_room_cell_direction_helpers() -> void:
	assert_eq(RoomCell.dir_bit("N"), RoomCell.DOOR_N)
	assert_eq(RoomCell.dir_bit("E"), RoomCell.DOOR_E)
	assert_eq(RoomCell.dir_bit("S"), RoomCell.DOOR_S)
	assert_eq(RoomCell.dir_bit("W"), RoomCell.DOOR_W)
	assert_eq(RoomCell.dir_bit("X"), 0)
	assert_eq(RoomCell.dir_offset(RoomCell.DOOR_N), Vector2i(0, -1), "north is −Z (y − 1)")
	assert_eq(RoomCell.dir_offset(RoomCell.DOOR_E), Vector2i(1, 0))
	for b: int in RoomCell.DIR_BITS:
		assert_eq(RoomCell.opposite(RoomCell.opposite(b)), b)
		assert_eq(RoomCell.dir_offset(b) + RoomCell.dir_offset(RoomCell.opposite(b)), Vector2i.ZERO)
		assert_eq(RoomCell.dir_bit(RoomCell.dir_letter(b)), b)
	assert_eq(RoomCell.doors_to_string(RoomCell.doors_from_string("WSN")), "NSW")
	assert_eq(RoomCell.kind_from_string("quarter_boss"), RoomCell.Kind.QUARTER_BOSS)
	assert_eq(RoomCell.kind_from_string("bogus"), RoomCell.Kind.NORMAL)
	assert_eq(RoomCell.KIND_NAMES.size(), RoomCell.Kind.size())
	assert_eq(RoomCell.KIND_NAMES, DataValidator.CELL_KINDS, "kind names == data vocabulary")
	assert_eq(int(RoomSpec.Kind.FLOOR_BOSS), int(RoomCell.Kind.FLOOR_BOSS), "RoomSpec.Kind has the same order")


func test_world_cell_conversion() -> void:
	var l: FloorLayout = FloorLayout.new()
	assert_eq(l.cell_to_world(Vector2i(3, 2)), Vector3(48.0, 0.0, 32.0))
	assert_eq(l.world_to_cell(Vector3(48.0, 0.0, 32.0)), Vector2i(3, 2))
	assert_eq(l.world_to_cell(Vector3(55.9, 1.0, 24.1)), Vector2i(3, 2), "inside the room")
	assert_eq(l.world_to_cell(Vector3(56.1, 0.0, 32.0)), Vector2i(4, 2), "past the east wall")


func test_floor1_layout_valid_and_deterministic() -> void:
	var data: GameData = real_data()
	var def: FloorDef = data.floor_def(1)
	assert_not_null(def, "floor_1 exists")
	if def == null:
		return
	assert_true(def.has_layout(), "floor_1 is handbuilt (GDD §1.3)")
	var fseed: int = SeedUtil.derive(4242, "floor", 1)
	var a: FloorLayout = DungeonGenerator.generate(def, fseed)
	assert_not_null(a)
	if a == null:
		return
	assert_eq(a.validate(), PackedStringArray(), "floor_1 layout validates")
	var b: FloorLayout = DungeonGenerator.generate(def, fseed)
	assert_eq(b.to_debug_string(), a.to_debug_string(), "same seed → identical layout")
	var other: FloorLayout = DungeonGenerator.generate(def, SeedUtil.derive(7, "floor", 1))
	assert_eq(_map_part(other.to_debug_string()), _map_part(a.to_debug_string()),
		"handbuilt map does not depend on the seed (only decoration variants do)")
	assert_eq(a.floor_index, 1)
	assert_eq(a.width, int(def.grid["w"]))
	assert_eq(a.height, int(def.grid["h"]))
	assert_eq(a.cell_at(a.start).kind, RoomCell.Kind.START)
	assert_eq(a.cell_at(a.stairs).kind, RoomCell.Kind.STAIRS)
	assert_eq(a.path[0], a.start)
	assert_eq(a.path[a.path.size() - 1], a.stairs)
	assert_eq(a.cell_at(a.start).depth, 0)


func test_floor1_layout_matches_data() -> void:
	var def: FloorDef = real_data().floor_def(1)
	if def == null:
		fail("floor_1 missing")
		return
	var lay: Dictionary = def.layout
	var l: FloorLayout = DungeonGenerator.generate(def, 99)
	assert_eq(l.cells.size(), (lay["cells"] as Array).size(), "one RoomCell per data cell")
	for cv: Variant in lay["cells"]:
		var cd: Dictionary = cv
		var c: Vector2i = Vector2i(int(cd["x"]), int(cd["y"]))
		var rc: RoomCell = l.cell_at(c)
		assert_not_null(rc, "cell %s" % str(c))
		if rc != null:
			assert_eq(RoomCell.kind_to_string(rc.kind), str(cd["kind"]), "kind of %s" % str(c))
			assert_eq(rc.zone, str(cd["zone"]))
			assert_eq(rc.doors, RoomCell.doors_from_string(str(cd["doors"])), "doors of %s" % str(c))
			assert_between(rc.variant, 0, 3)
	assert_eq(l.chests.size(), (lay["chests"] as Array).size())
	for chv: Variant in lay["chests"]:
		var chd: Dictionary = chv
		var ch: ChestSpawn = l.chest_by_id(str(chd["id"]))
		assert_not_null(ch, "chest %s" % str(chd["id"]))
		if ch != null:
			assert_eq(ch.type, str(chd["type"]))
			assert_eq(ch.cell, JsonUtil.arr_to_vec2i(chd["cell"]))
			assert_almost(ch.offset.x, float((chd["offset"] as Array)[0]))
			assert_eq(ch.contents.size(), (chd["contents"] as Array).size())
	for pv: Variant in lay["encounters_placed"]:
		var p: Dictionary = pv
		var e: EnemySpawn = l.enemy_by_id(str(p["group_id"]))
		assert_not_null(e, "group %s" % str(p["group_id"]))
		if e != null:
			assert_eq(e.encounter_id, str(p["enc_id"]))
			assert_eq(e.start_state, StringName(str(p["state"])))
			assert_eq(e.can_turn, bool(p["turn"]))
			assert_eq(e.waypoints.size(), (p["waypoints"] as Array).size())
			if def.encounter(e.encounter_id) != null:
				assert_eq(e.lead_enemy_id, def.encounter(e.encounter_id).enemies[0], "lead = first enemy")
	assert_eq(l.events.size(), (lay["events"] as Array).size())
	assert_eq(l.spawners.size(), (lay["spawners"] as Array).size())
	assert_eq(l.safe_rooms.size(), (lay["safe_rooms"] as Array).size())
	for sv: Variant in lay["safe_rooms"]:
		var s: Dictionary = sv
		var sc: Vector2i = JsonUtil.arr_to_vec2i(s["cell"])
		assert_eq(l.safe_room_at(sc), str(s["id"]))
		assert_eq((l.safe_room_info[str(s["id"])] as Dictionary)["theme"], str(s["theme"]))
	assert_eq(l.gates.size(), (lay["gates"] as Array).size())
	for g: Dictionary in l.gates:
		assert_eq(str(g["key"]), FloorLayout.gate_key(g["cell"], int(g["dir"])))


func test_from_layout_fixture() -> void:
	var def: FloorDef = _layout_def()
	var l: FloorLayout = DungeonGenerator.from_layout(def, 1234)
	assert_eq(l.validate(), PackedStringArray())
	assert_eq(l.start, Vector2i(1, 2))
	assert_eq(l.stairs, Vector2i(1, 0))
	assert_eq(l.quarter_boss, Vector2i(2, 1))
	assert_eq(l.floor_boss, Vector2i(0, 0))
	# Shortest path ties resolve in N, E, S, W order: (1,1) → N (1,0) directly (gate counted as open).
	assert_eq(l.path, [Vector2i(1, 2), Vector2i(1, 1), Vector2i(1, 0)])
	assert_eq(l.cell_at(Vector2i(2, 0)).depth, 3, "via the stairs (gates open)")
	assert_eq(l.cell_at(Vector2i(1, 1)).depth, 1)
	assert_true(l.cell_at(Vector2i(1, 1)).on_path)
	assert_false(l.cell_at(Vector2i(0, 1)).on_path)
	assert_len(l.gates, 1)
	assert_eq(str(l.gates[0]["key"]), "1,1,N")
	assert_eq(l.gate_at(Vector2i(1, 1), RoomCell.DOOR_N), l.gates[0], "gate from its own side")
	assert_eq(l.gate_at(Vector2i(1, 0), RoomCell.DOOR_S), l.gates[0], "gate from the other side")
	assert_true(l.gate_at(Vector2i(1, 1), RoomCell.DOOR_E).is_empty())
	assert_eq(l.gate_by_key("1,1,N"), l.gates[0])
	# Closed gate blocks, opened gate passes.
	assert_eq(l.neighbors(Vector2i(1, 1)), [Vector2i(2, 1), Vector2i(1, 2), Vector2i(0, 1)])
	assert_eq(l.neighbors(Vector2i(1, 1), PackedStringArray(["1,1,N"])),
		[Vector2i(1, 0), Vector2i(2, 1), Vector2i(1, 2), Vector2i(0, 1)])
	assert_eq(l.linked(Vector2i(1, 0)), [Vector2i(2, 0), Vector2i(1, 1), Vector2i(0, 0)])
	var closed: Dictionary = l.distances(l.start)
	assert_eq(int(closed[Vector2i(1, 0)]), 4, "closed gate: stairs only around via the boss office")
	assert_eq(int(l.distances(l.start, PackedStringArray(["1,1,N"]))[Vector2i(1, 0)]), 2, "opened gate: short way")
	var no_qb: Array[Vector2i] = [Vector2i(2, 1)]
	assert_false(l.distances(l.start, PackedStringArray(), false, no_qb).has(Vector2i(1, 0)),
		"blocked cells are never entered")
	assert_eq(l.shortest_path(Vector2i(0, 1), Vector2i(2, 0)), [Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 0),
		Vector2i(2, 0)], "shortest path prefers N over E on ties")
	# Placements.
	var tut: EnemySpawn = l.enemy_by_id("f1_g0")
	assert_eq(tut.start_state, &"IDLE")
	assert_false(tut.can_turn)
	assert_eq(tut.lead_enemy_id, "enm_t_rat")
	assert_almost(tut.offset.y, -2.5)
	var pat: EnemySpawn = l.enemy_by_id("f1_g1")
	assert_eq(pat.waypoints.size(), 3)
	assert_true(l.enemy_by_id("f1_qb").is_boss)
	assert_true(l.enemy_by_id("f1_fb").is_boss)
	assert_eq(l.chest_by_id("f1_c1").contents.size(), 1)
	assert_eq(l.chest_by_id("f1_c1").index(), 1)
	assert_eq(l.event_by_id("fev_t_drone").type, "photo_drone")
	assert_eq(l.safe_room_at(Vector2i(0, 1)), "sr_t_kiosk")
	assert_eq(l.zone_cells("zone_a"), [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)])
	# Zone palette over floor palette.
	var pal: Dictionary = l.zone_palette(Vector2i(1, 1), def.palette)
	assert_eq(pal["floor"], "#112233", "zone overrides floor")
	assert_eq(pal["wall"], "#5b6270", "floor key kept")
	assert_eq(l.zone_palette(Vector2i(2, 0), def.palette)["floor"], "#3a3f4b", "empty zone palette")
	# Variants come from the seed in (y, x) order.
	var rng: RandomNumberGenerator = SeedUtil.make_rng(1234)
	for c: Vector2i in l.sorted_cells():
		assert_eq(l.cell_at(c).variant, rng.randi_range(0, 3), "variant of %s" % str(c))
	var dbg: String = l.to_debug_string()
	assert_has(dbg, "B-T-.", "map row 0")
	assert_has(dbg, "H-.-Q", "map row 1")
	assert_has(dbg, "  #", "gated door drawn as #")


func test_validate_detects_broken_layouts() -> void:
	var def: FloorDef = _layout_def()
	var base: FloorLayout = DungeonGenerator.from_layout(def, 1)
	assert_eq(base.validate(), PackedStringArray())
	# Asymmetric door.
	var l1: FloorLayout = DungeonGenerator.from_layout(def, 1)
	l1.cell_at(Vector2i(2, 0)).doors &= ~RoomCell.DOOR_W
	assert_false(l1.validate().is_empty(), "asymmetric door")
	# Chest in the start room.
	var l2: FloorLayout = DungeonGenerator.from_layout(def, 1)
	l2.chests[0].cell = l2.start
	assert_false(l2.validate().is_empty(), "chest in START")
	# Group in a safe room.
	var l3: FloorLayout = DungeonGenerator.from_layout(def, 1)
	l3.enemy_by_id("f1_g1").cell = Vector2i(0, 1)
	assert_false(l3.validate().is_empty(), "group in SAFE")
	# Offset outside the clear zone.
	var l4: FloorLayout = DungeonGenerator.from_layout(def, 1)
	l4.events[0].offset = Vector2(5.0, 0.0)
	assert_false(l4.validate().is_empty(), "offset > 4.5")
	# Duplicate id across lists.
	var l5: FloorLayout = DungeonGenerator.from_layout(def, 1)
	l5.events[0].id = "f1_g1"
	assert_false(l5.validate().is_empty(), "duplicate id")
	# Two START cells.
	var l6: FloorLayout = DungeonGenerator.from_layout(def, 1)
	l6.cell_at(Vector2i(2, 0)).kind = RoomCell.Kind.START
	assert_false(l6.validate().is_empty(), "two START cells")
	# Disconnected cell.
	var l7: FloorLayout = DungeonGenerator.from_layout(def, 1)
	l7.cells[Vector2i(2, 2)] = RoomCell.make(Vector2i(2, 2))
	assert_false(l7.validate().is_empty(), "unreachable cell")
	# Safe room only reachable through the quarter boss.
	var l8: FloorLayout = DungeonGenerator.from_layout(def, 1)
	l8.safe_rooms = [Vector2i(2, 0)]
	l8.safe_room_ids = {Vector2i(2, 0): "sr_t_kiosk"}
	l8.safe_room_info = {"sr_t_kiosk": {"cell": Vector2i(2, 0), "name": "x", "theme": "kiosk", "shop": []}}
	l8.cell_at(Vector2i(2, 0)).kind = RoomCell.Kind.SAFE
	l8.cell_at(Vector2i(0, 1)).kind = RoomCell.Kind.NORMAL
	l8.cell_at(Vector2i(1, 0)).doors &= ~RoomCell.DOOR_E
	l8.cell_at(Vector2i(2, 0)).doors &= ~RoomCell.DOOR_W
	l8.cell_at(Vector2i(2, 0)).doors |= RoomCell.DOOR_S
	l8.cell_at(Vector2i(2, 1)).doors |= RoomCell.DOOR_N
	var errs: PackedStringArray = l8.validate()
	var found: bool = false
	for e: String in errs:
		if e.contains("quarter boss"):
			found = true
	assert_true(found, "safe room behind the quarter boss is reported: %s" % "; ".join(errs))
	# Procedural count limits.
	var l9: FloorLayout = DungeonGenerator.from_layout(def, 1)
	l9.bounds = {"rooms": [10, 20]}
	assert_false(l9.validate().is_empty(), "room count below bounds")


func test_procedural_200_seeds_invariants_determinism_runtime() -> void:
	var def: FloorDef = _proc_def()
	var total_us: int = 0
	var distinct: Dictionary = {}
	for i in SEEDS:
		var fseed: int = SeedUtil.derive(i + 1, "floor", 2)
		var t0: int = Time.get_ticks_usec()
		var l: FloorLayout = DungeonGenerator.generate(def, fseed)
		total_us += Time.get_ticks_usec() - t0
		if l == null:
			fail("seed %d: null layout" % fseed)
			continue
		var errs: PackedStringArray = l.validate()
		if not errs.is_empty():
			fail("seed %d invalid: %s" % [fseed, "; ".join(errs)])
			continue
		_check_procedural(l, def, "seed %d:" % fseed)
		var again: FloorLayout = DungeonGenerator.generate(def, fseed)
		if again.to_debug_string() != l.to_debug_string():
			fail("seed %d not deterministic" % fseed)
		distinct[_map_part(l.to_debug_string())] = true
	var avg_ms: float = total_us / 1000.0 / SEEDS
	print("[test_m3_dungeon_gen] procedural avg %.2f ms over %d seeds, %d distinct maps" % [avg_ms, SEEDS,
		distinct.size()])
	assert_lt(avg_ms, MAX_AVG_MS, "average generation time")
	assert_gt(distinct.size(), SEEDS / 2, "seeds produce varied maps")


func test_procedural_configurations() -> void:
	var configs: Array[Dictionary] = [
		{"quarter_boss": "", "floor_boss": "", "safe_rooms": 1},
		{"quarter_boss": "enc_t_qb", "floor_boss": "", "safe_rooms": 0, "chests": {"min": 0, "max": 0}},
		{"safe_rooms": 3, "rooms": {"min": 20, "max": 30}, "enemy_groups": {"min": 8, "max": 12}},
		{"grid": {"w": 6, "h": 6}, "rooms": {"min": 8, "max": 12}, "safe_rooms": 1,
			"enemy_groups": {"min": 1, "max": 3}, "chests": {"min": 1, "max": 3}},
		{"grid": {"w": 12, "h": 6}, "rooms": {"min": 30, "max": 40}, "safe_rooms": 2},
	]
	for ci in configs.size():
		var def: FloorDef = _proc_def(configs[ci])
		for i in 25:
			var fseed: int = SeedUtil.derive(1000 + i, "floor", 2)
			var l: FloorLayout = DungeonGenerator.generate(def, fseed)
			var errs: PackedStringArray = l.validate()
			if not errs.is_empty():
				fail("config %d seed %d invalid: %s" % [ci, fseed, "; ".join(errs)])
				continue
			_check_procedural(l, def, "config %d seed %d:" % [ci, fseed])
			if def.quarter_boss == "":
				assert_eq(l.quarter_boss, Vector2i(-1, -1))
			if def.floor_boss == "":
				assert_eq(l.floor_boss, Vector2i(-1, -1))


## Few rooms, many groups and chests: second groups (SECOND_GROUP_OFFSET, turned away from chests) really occur.
func test_second_groups_keep_clear_of_chests() -> void:
	var def: FloorDef = _proc_def({"rooms": {"min": 12, "max": 14}, "enemy_groups": {"min": 7, "max": 9},
		"chests": {"min": 5, "max": 8}, "safe_rooms": 1})
	var second: int = 0
	for i in 40:
		var fseed: int = SeedUtil.derive(5000 + i, "floor", 2)
		var l: FloorLayout = DungeonGenerator.generate(def, fseed)
		var errs: PackedStringArray = l.validate()
		if not errs.is_empty():
			fail("seed %d invalid: %s" % [fseed, "; ".join(errs)])
			continue
		_check_procedural(l, def, "seed %d:" % fseed)
		for e: EnemySpawn in l.enemies:
			if not e.is_boss and e.offset != Vector2.ZERO:
				second += 1
				assert_almost(e.offset.length(), DungeonGenerator.SECOND_GROUP_OFFSET.length(), 0.001,
					"second group offset is a turned SECOND_GROUP_OFFSET")
	assert_gt(second, 0, "the configuration produces second groups in a room")


func test_procedural_bosses_and_safe_rooms() -> void:
	var def: FloorDef = _proc_def()
	var l: FloorLayout = DungeonGenerator.generate(def, 77)
	var qb: EnemySpawn = l.enemy_by_id("f2_qb")
	var fb: EnemySpawn = l.enemy_by_id("f2_fb")
	assert_not_null(qb)
	assert_not_null(fb)
	if qb != null and fb != null:
		assert_eq(qb.cell, l.quarter_boss)
		assert_eq(qb.encounter_id, "enc_t_qb")
		assert_eq(qb.lead_enemy_id, "enm_t_boss")
		assert_true(qb.is_boss)
		assert_eq(fb.cell, l.floor_boss)
		assert_eq(fb.encounter_id, "enc_t_fb")
	assert_eq(l.cell_at(l.quarter_boss).kind, RoomCell.Kind.QUARTER_BOSS)
	assert_eq(l.cell_at(l.floor_boss).kind, RoomCell.Kind.FLOOR_BOSS)
	var themes: PackedStringArray = []
	for c: Vector2i in l.safe_rooms:
		var info: Dictionary = l.safe_room_info[l.safe_room_at(c)]
		themes.append(str(info["theme"]))
		assert_eq(info["shop"], PackedStringArray(["itm_bandage"]), "procedural shop = def.shop")
	assert_eq(themes, PackedStringArray(["kiosk", "pumphouse"]), "themes in turn")
	assert_true(l.events.is_empty() and l.gates.is_empty() and l.spawners.is_empty(), "procedural: no data extras")
	assert_true(l.zones.is_empty())


func test_procedural_seed_changes_layout() -> void:
	var def: FloorDef = _proc_def()
	var a: String = DungeonGenerator.generate(def, 1).to_debug_string()
	var b: String = DungeonGenerator.generate(def, 2).to_debug_string()
	assert_ne(a, b)


func test_explore_event_roundtrip() -> void:
	var e: ExploreEvent = ExploreEvent.make(ExploreEvent.Type.STRAY_DUE, 450,
		{"zone": "zone_sewer", "group_id": "f1_s0", "encounter_id": "enc_f1_b1"})
	assert_eq(e.type, ExploreEvent.Type.STRAY_DUE)
	assert_eq(e.tick, 450)
	var d: Dictionary = e.to_dict()
	assert_eq(d["type"], "stray_due")
	var back: ExploreEvent = ExploreEvent.from_dict(d)
	assert_not_null(back)
	assert_eq(back.to_dict(), d, "to_dict ↔ from_dict")
	# Survives JSON (numbers become floats).
	var parsed: Variant = JSON.parse_string(JSON.stringify(d))
	var j: ExploreEvent = ExploreEvent.from_dict(parsed)
	assert_not_null(j)
	assert_eq(j.type, ExploreEvent.Type.STRAY_DUE)
	assert_eq(j.tick, 450)
	assert_eq(j.data["group_id"], "f1_s0")
	# Numeric type, every type name, bad input.
	assert_eq(ExploreEvent.from_dict({"type": 9, "tick": 3, "data": {"seconds": 300}}).type,
		ExploreEvent.Type.TIMER_WARNING)
	assert_eq(ExploreEvent.TYPE_NAMES.size(), ExploreEvent.Type.size())
	for i in ExploreEvent.Type.size():
		var ev: ExploreEvent = ExploreEvent.make(i as ExploreEvent.Type, i, {})
		assert_eq(ExploreEvent.from_dict(ev.to_dict()).type, i as ExploreEvent.Type)
	assert_null(ExploreEvent.from_dict({"type": "bogus"}))
	assert_null(ExploreEvent.from_dict({"tick": 1}))
	assert_null(ExploreEvent.from_dict({"type": 99}))
	# make() copies its data.
	var src: Dictionary = {"k": [1]}
	var m: ExploreEvent = ExploreEvent.make(ExploreEvent.Type.HYPE, 0, src)
	(src["k"] as Array).append(2)
	assert_eq(m.data["k"], [1])
