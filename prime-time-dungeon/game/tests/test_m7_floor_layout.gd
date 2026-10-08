extends TestCase
## M7 Floor-1 hand-built layout (01_GDD §1.3, §2.5–2.8, §10.1; 02_TECH §4.4.7): cells, zones, door rule, gates,
## chests f1_c0..15, groups f1_g0..14 + bosses, events, strays, safe rooms, stairs, and the routes they imply
## (key gate locks Gleis 9, the lever shortcut saves 4 cell changes per direction).

const DIRS: Dictionary = {"N": Vector2i(0, -1), "E": Vector2i(1, 0), "S": Vector2i(0, 1), "W": Vector2i(-1, 0)}
const OPPOSITE: Dictionary = {"N": "S", "E": "W", "S": "N", "W": "E"}

## GDD §1.3 cell table: cell → [zone letter, kind].
const CELLS: Dictionary = {
	Vector2i(1, 7): ["A", "start"], Vector2i(1, 6): ["A", "normal"], Vector2i(1, 5): ["A", "normal"],
	Vector2i(0, 5): ["A", "normal"], Vector2i(2, 5): ["A", "safe"], Vector2i(1, 4): ["A", "normal"],
	Vector2i(2, 4): ["A", "normal"], Vector2i(1, 3): ["A", "normal"],
	Vector2i(3, 4): ["B", "normal"], Vector2i(4, 4): ["B", "normal"], Vector2i(5, 4): ["B", "normal"],
	Vector2i(3, 5): ["B", "normal"], Vector2i(4, 5): ["B", "normal"], Vector2i(3, 3): ["B", "normal"],
	Vector2i(4, 3): ["B", "normal"], Vector2i(5, 3): ["B", "normal"], Vector2i(6, 3): ["B", "safe"],
	Vector2i(6, 2): ["C", "normal"], Vector2i(5, 2): ["C", "normal"], Vector2i(4, 2): ["C", "normal"],
	Vector2i(6, 1): ["C", "normal"], Vector2i(6, 0): ["C", "normal"], Vector2i(4, 1): ["C", "normal"],
	Vector2i(4, 0): ["C", "normal"], Vector2i(5, 0): ["C", "quarter_boss"],
	Vector2i(1, 2): ["D", "normal"], Vector2i(1, 1): ["D", "normal"], Vector2i(2, 1): ["D", "safe"],
	Vector2i(2, 0): ["D", "normal"], Vector2i(1, 0): ["D", "stairs"], Vector2i(0, 0): ["D", "floor_boss"],
}
## Zone letter → zone id; boss rooms use their own palette zones inside C / D (03_ART §2.2).
const ZONE_IDS: Dictionary = {"A": ["zone_platform"], "B": ["zone_sewer"], "C": ["zone_cellar", "zone_office"],
	"D": ["zone_track9", "zone_throne"]}

## GDD §1.3: group → [encounter, cell, state].
const GROUPS: Dictionary = {
	"f1_g0": ["enc_f1_a1_tutorial", Vector2i(1, 6), "IDLE"], "f1_g1": ["enc_f1_a2", Vector2i(1, 4), "PATROL"],
	"f1_g2": ["enc_f1_a3", Vector2i(2, 4), "IDLE"], "f1_g3": ["enc_f1_a4", Vector2i(1, 3), "PATROL"],
	"f1_g4": ["enc_f1_a_rare", Vector2i(0, 5), "IDLE"], "f1_g5": ["enc_f1_b1", Vector2i(4, 4), "PATROL"],
	"f1_g6": ["enc_f1_b2", Vector2i(3, 3), "PATROL"], "f1_g7": ["enc_f1_b3", Vector2i(5, 3), "PATROL"],
	"f1_g8": ["enc_f1_b4", Vector2i(4, 5), "IDLE"], "f1_g9": ["enc_f1_c1", Vector2i(5, 2), "PATROL"],
	"f1_g10": ["enc_f1_c2", Vector2i(6, 0), "IDLE"], "f1_g11": ["enc_f1_c3", Vector2i(4, 1), "PATROL"],
	"f1_g12": ["enc_f1_d1", Vector2i(1, 2), "IDLE"], "f1_g13": ["enc_f1_d2", Vector2i(1, 1), "PATROL"],
	"f1_g14": ["enc_f1_d3", Vector2i(2, 0), "IDLE"],
	"f1_qb": ["enc_f1_boss_hausmeister", Vector2i(5, 0), "IDLE"],
	"f1_fb": ["enc_f1_boss_rattenkoenigin", Vector2i(0, 0), "IDLE"],
}

## GDD §1.3 / §2.5: chest → [cell, type, contents].
const CHESTS: Dictionary = {
	"f1_c0": [Vector2i(1, 5), "wood", []], "f1_c1": [Vector2i(0, 5), "metal", [["itm_arm_safety_vest", 1]]],
	"f1_c2": [Vector2i(1, 4), "wood", []], "f1_c3": [Vector2i(1, 3), "wood", []],
	"f1_c4": [Vector2i(3, 4), "wood", []], "f1_c5": [Vector2i(5, 4), "metal", [["itm_wpn_collar_studded", 1]]],
	"f1_c6": [Vector2i(3, 5), "wood", []], "f1_c7": [Vector2i(4, 5), "metal", [["itm_smelling_salts", 2]]],
	"f1_c8": [Vector2i(5, 3), "wood", []], "f1_c9": [Vector2i(6, 2), "wood", []],
	"f1_c10": [Vector2i(4, 2), "wood", []], "f1_c11": [Vector2i(6, 0), "metal", [["itm_acc_gas_mask", 1]]],
	"f1_c12": [Vector2i(4, 1), "locked", [["itm_wpn_fire_axe", 1]]], "f1_c13": [Vector2i(1, 2), "wood", []],
	"f1_c14": [Vector2i(2, 0), "locked", [["itm_wpn_collar_signet", 1]]], "f1_c15": [Vector2i(2, 0), "wood", []],
}

const EVENTS: Dictionary = {
	"fev_photo_drone": ["photo_drone", Vector2i(1, 5)], "fev_lost_candidate": ["lost_candidate", Vector2i(2, 4)],
	"fev_wheel": ["wheel", Vector2i(3, 5)], "fev_lever": ["lever", Vector2i(4, 3)],
	"fev_broken_vending": ["broken_vending", Vector2i(6, 1)],
}


func _layout() -> Dictionary:
	return real_data().floor_def(1).layout


func _cells() -> Dictionary:
	var out: Dictionary = {}
	for c: Dictionary in _layout()["cells"]:
		out[Vector2i(int(c["x"]), int(c["y"]))] = c
	return out


static func _v(a: Variant) -> Vector2i:
	return JsonUtil.arr_to_vec2i(a, Vector2i(-1, -1))


## BFS over doors; `closed` = door keys (DataValidator.door_key) that block. Returns cell → distance.
func _bfs(start: Vector2i, closed: PackedStringArray) -> Dictionary:
	var cells: Dictionary = _cells()
	var dist: Dictionary = {start: 0}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for ch: String in str(cells[cur]["doors"]):
			if closed.has(DataValidator.door_key(cur, ch)):
				continue
			var n: Vector2i = cur + (DIRS[ch] as Vector2i)
			if cells.has(n) and not dist.has(n):
				dist[n] = int(dist[cur]) + 1
				queue.append(n)
	return dist


func _gate_keys() -> Dictionary:
	var out: Dictionary = {}   # requires → door key
	for g: Dictionary in _layout()["gates"]:
		out[str(g["requires"])] = DataValidator.door_key(_v(g["cell"]), str(g["dir"]))
	return out


# --- cells, zones, doors -----------------------------------------------------------------------------------------

func test_cells_and_zones_match_the_map() -> void:
	var f1: FloorDef = real_data().floor_def(1)
	assert_eq(f1.grid, {"w": 8, "h": 8})
	var cells: Dictionary = _cells()
	assert_eq(cells.size(), 31, "31 occupied cells")
	var per_letter: Dictionary = {"A": 0, "B": 0, "C": 0, "D": 0}
	for pos: Vector2i in CELLS:
		assert_true(cells.has(pos), "cell %s" % str(pos))
		if not cells.has(pos):
			continue
		var want: Array = CELLS[pos]
		var c: Dictionary = cells[pos]
		assert_eq(c["kind"], want[1], "kind of %s" % str(pos))
		assert_has(ZONE_IDS[want[0]], c["zone"], "zone of %s" % str(pos))
		per_letter[want[0]] = int(per_letter[want[0]]) + 1
	assert_eq(per_letter, {"A": 8, "B": 9, "C": 8, "D": 6}, "GDD §1.3 zone sizes")
	assert_eq(cells[Vector2i(5, 0)]["zone"], "zone_office", "boss room palette")
	assert_eq(cells[Vector2i(0, 0)]["zone"], "zone_throne", "boss room palette")
	var zone_names: Dictionary = {}
	for z: Dictionary in _layout()["zones"]:
		zone_names[str(z["id"])] = str(z["name"])
		for k: String in DataValidator.PALETTE_KEYS:
			assert_true((z["palette"] as Dictionary).has(k), "%s palette.%s" % [str(z["id"]), k])
	assert_eq(zone_names["zone_platform"], "Bahnsteig Nord")
	assert_eq(zone_names["zone_sewer"], "Kanalisation")
	assert_eq(zone_names["zone_cellar"], "Kellergewölbe")
	assert_eq(zone_names["zone_track9"], "Gleis 9")


func test_door_rule() -> void:
	# Same-zone neighbours are connected except (5,0)↔(6,0); zone changes only at the four GDD transitions.
	var cells: Dictionary = _cells()
	var transitions: Array = [[Vector2i(2, 4), Vector2i(3, 4)], [Vector2i(6, 3), Vector2i(6, 2)],
		[Vector2i(1, 3), Vector2i(1, 2)], [Vector2i(4, 3), Vector2i(4, 2)]]
	for pos: Vector2i in cells:
		var doors: String = str(cells[pos]["doors"])
		for ch: String in DIRS:
			var n: Vector2i = pos + (DIRS[ch] as Vector2i)
			var has_door: bool = doors.contains(ch)
			if not cells.has(n):
				assert_false(has_door, "door %s of %s leads nowhere" % [ch, str(pos)])
				continue
			assert_eq(str(cells[n]["doors"]).contains(str(OPPOSITE[ch])), has_door, "symmetric %s %s" % [str(pos), ch])
			var same: bool = CELLS[pos][0] == CELLS[n][0]
			var is_transition: bool = false
			for t: Array in transitions:
				if (t[0] == pos and t[1] == n) or (t[1] == pos and t[0] == n):
					is_transition = true
			var excluded: bool = (pos == Vector2i(5, 0) and n == Vector2i(6, 0)) \
				or (pos == Vector2i(6, 0) and n == Vector2i(5, 0))
			var want: bool = (same and not excluded) or is_transition
			assert_eq(has_door, want, "door %s of %s" % [ch, str(pos)])


func test_gates() -> void:
	var gates: Array = _layout()["gates"]
	assert_len(gates, 2)
	var keys: Dictionary = _gate_keys()
	assert_eq(keys.get("itm_key_master", ""), DataValidator.door_key(Vector2i(1, 3), "N"), "gate_track9 A→D")
	assert_eq(keys.get("event:fev_lever", ""), DataValidator.door_key(Vector2i(4, 3), "N"), "gate_lever B→C")
	var lever: Dictionary = {}
	for ev: Dictionary in _layout()["events"]:
		if str(ev["id"]) == "fev_lever":
			lever = ev
	assert_eq(lever["params"]["gate"], "4,3,N", "runtime key = side the gate is defined on")


func test_routes_and_progression_locks() -> void:
	var keys: Dictionary = _gate_keys()
	var both_closed: PackedStringArray = PackedStringArray([str(keys["itm_key_master"]), str(keys["event:fev_lever"])])
	var start: Vector2i = Vector2i(1, 7)
	var d0: Dictionary = _bfs(start, both_closed)
	assert_false(d0.has(Vector2i(1, 0)), "stairs need the Generalschlüssel")
	assert_false(d0.has(Vector2i(0, 0)), "throne room is behind the gate")
	assert_true(d0.has(Vector2i(5, 0)), "the Hausmeister is reachable without any gate")
	assert_true(d0.has(Vector2i(2, 5)) and d0.has(Vector2i(6, 3)), "SR1/SR2 reachable before the quarter boss")
	for pos: Vector2i in CELLS:
		var letter: String = CELLS[pos][0]
		assert_eq(d0.has(pos), letter != "D", "only zone D is locked: %s" % str(pos))
	assert_eq(int(d0[Vector2i(5, 0)]), 15, "start → Hausmeister-Büro without the lever")
	var key_open: PackedStringArray = PackedStringArray([str(keys["event:fev_lever"])])
	var from_qb: Dictionary = _bfs(Vector2i(5, 0), key_open)
	assert_eq(int(from_qb[Vector2i(1, 0)]), 16, "Hausmeister → stairs through gate_track9")
	var with_lever: Dictionary = _bfs(start, PackedStringArray([str(keys["itm_key_master"])]))
	assert_eq(int(d0[Vector2i(5, 0)]) - int(with_lever[Vector2i(5, 0)]), 4, "lever shortcut saves 4 cell changes")
	var all_open: Dictionary = _bfs(Vector2i(5, 0), PackedStringArray())
	assert_eq(int(from_qb[Vector2i(1, 0)]) - int(all_open[Vector2i(1, 0)]), 4, "…in both directions")
	assert_eq(int(all_open[Vector2i(0, 0)]), int(all_open[Vector2i(1, 0)]) + 1, "throne room next to the stairs")
	# GDD §1.3: main path start → office → stairs ≈ 25 cell changes (lever open).
	assert_between(int(with_lever[Vector2i(5, 0)]) + int(all_open[Vector2i(1, 0)]), 22, 28)
	assert_eq(_layout()["stairs"]["cell"], [1, 0])


# --- placements ----------------------------------------------------------------------------------------------------

func test_groups_and_bosses() -> void:
	var placed: Array = _layout()["encounters_placed"]
	assert_len(placed, 17, "f1_g0..14 + f1_qb + f1_fb")
	var seen: Dictionary = {}
	for p: Dictionary in placed:
		var gid: String = str(p["group_id"])
		assert_true(GROUPS.has(gid), "known group " + gid)
		if not GROUPS.has(gid):
			continue
		seen[gid] = true
		var want: Array = GROUPS[gid]
		assert_eq([p["enc_id"], _v(p["cell"]), p["state"]], want, gid)
		var wps: Array = p["waypoints"]
		if str(p["state"]) == "PATROL":
			assert_eq(wps, [[-4.0, -4.0], [4.0, -4.0], [4.0, 4.0], [-4.0, 4.0]], gid + ": ±4 m square clockwise")
		else:
			assert_len(wps, 0, gid)
	assert_eq(seen.size(), GROUPS.size())
	var tut: Dictionary = placed[0]
	assert_eq(tut["group_id"], "f1_g0")
	assert_false(tut["turn"], "tutorial rats never turn around")
	assert_lt(float(tut["offset"][1]), 0.0, "tutorial rats stand north, Kai approaches from behind")


func test_chests() -> void:
	var chests: Array = _layout()["chests"]
	assert_len(chests, 16)
	var types: Dictionary = {"wood": 0, "metal": 0, "locked": 0}
	var by_cell: Dictionary = {}
	for c: Dictionary in chests:
		var id: String = str(c["id"])
		assert_true(CHESTS.has(id), id)
		if not CHESTS.has(id):
			continue
		var want: Array = CHESTS[id]
		var contents: Array = []
		for it: Dictionary in c["contents"]:
			contents.append([it["id"], it["amount"]])
		assert_eq([_v(c["cell"]), c["type"], contents], want, id)
		types[c["type"]] = int(types[c["type"]]) + 1
		var pos: Vector2i = _v(c["cell"])
		by_cell[pos] = int(by_cell.get(pos, 0)) + 1
		var kind: String = str(CELLS[pos][1])
		assert_eq(kind, "normal", id + " stands in a normal room")
	assert_eq(types, {"wood": 10, "metal": 4, "locked": 2})
	# Second chest of one cell uses the mirrored corner (GDD §1.3).
	for c: Dictionary in chests:
		if str(c["id"]) == "f1_c15":
			assert_eq(c["offset"], [3.5, -3.5])
		elif str(c["id"]) == "f1_c14":
			assert_eq(c["offset"], [-3.5, -3.5])
	assert_eq(by_cell[Vector2i(2, 0)], 2)


func test_events_match_gdd() -> void:
	var events: Array = _layout()["events"]
	assert_len(events, 5)
	var params: Dictionary = {}
	for ev: Dictionary in events:
		var id: String = str(ev["id"])
		assert_true(EVENTS.has(id), id)
		if not EVENTS.has(id):
			continue
		assert_eq([ev["type"], _v(ev["cell"])], EVENTS[id], id)
		params[id] = ev["params"]
	assert_eq(params["fev_photo_drone"], {"pose_hype": 15, "pose_followers": 20, "smash_credits": 30, "smash_hype": -5})
	assert_eq(params["fev_lost_candidate"], {"tag": "heal", "reward_item": "itm_acc_lucky_ticket", "followers": 40})
	assert_eq(params["fev_lever"], {"success": 0.60, "gate": "4,3,N", "flood_pct": 15, "encounter": "enc_f1_evt_slime"})
	assert_eq(params["fev_broken_vending"], {"base": 0.50, "per_lck": 0.01, "reward_item": "itm_energy_krawumm",
		"reward_amount": 2, "fail_pct": 10, "fail_hype": 4})
	var wheel: Dictionary = params["fev_wheel"]
	assert_eq([wheel["cost"], wheel["max_spins"]], [20, 3])
	assert_eq(wheel["table"], [
		{"weight": 35, "kind": "item", "id": "itm_bandage", "amount": 2},
		{"weight": 25, "kind": "credits", "id": "", "amount": 50},
		{"weight": 15, "kind": "box", "id": "box_bronze", "amount": 1},
		{"weight": 15, "kind": "nothing", "id": "", "amount": 0},   # GDD §2.6 table (M3 CR 5: amount 0 now valid)
		{"weight": 10, "kind": "encounter", "id": "enc_f1_evt_pigeons", "amount": 1}])
	# Event props must not share the spot of a group (centre) or a chest (north corners) in the same room.
	var spots: Dictionary = {}
	for p: Dictionary in _layout()["encounters_placed"]:
		spots["%s|%s" % [str(_v(p["cell"])), str(p["offset"])]] = str(p["group_id"])
	for c: Dictionary in _layout()["chests"]:
		spots["%s|%s" % [str(_v(c["cell"])), str(c["offset"])]] = str(c["id"])
	for ev: Dictionary in events:
		var key: String = "%s|%s" % [str(_v(ev["cell"])), str(ev["offset"])]
		assert_false(spots.has(key), "%s overlaps %s" % [str(ev["id"]), str(spots.get(key, ""))])


func test_safe_rooms_and_spawners() -> void:
	var srs: Array = _layout()["safe_rooms"]
	var got: Array = []
	for sr: Dictionary in srs:
		got.append([sr["id"], _v(sr["cell"]), sr["name"], sr["theme"]])
	assert_eq(got, [["sr_kiosk", Vector2i(2, 5), "Kiosk 24/7", "kiosk"],
		["sr_pumphouse", Vector2i(6, 3), "Pumpenhaus", "pumphouse"],
		["sr_signalbox", Vector2i(2, 1), "Stellwerk", "signalbox"]])
	var spawners: Array = _layout()["spawners"]
	assert_len(spawners, 2)
	var by_zone: Dictionary = {}
	for s: Dictionary in spawners:
		by_zone[str(s["zone"])] = [Array(s["pool"] as PackedStringArray), int(s["interval_sec"])]
	assert_eq(by_zone, {"zone_platform": [["enc_f1_a2", "enc_f1_a4"], 90],
		"zone_sewer": [["enc_f1_b1", "enc_f1_b2"], 90]})


func test_layout_is_stable_input_for_the_generator() -> void:
	# Ids are unique and in runtime format; placements stay inside the free zone of a room (|offset| <= 4.5).
	var ids: Dictionary = {}
	for key: String in ["encounters_placed", "chests", "events"]:
		for p: Dictionary in _layout()[key]:
			var id: String = str(p.get("group_id", p.get("id", "")))
			assert_false(ids.has(id), "unique " + id)
			ids[id] = true
			var off: Array = p["offset"]
			assert_true(absf(float(off[0])) <= 4.5 and absf(float(off[1])) <= 4.5, id + " offset")
			var pos: Vector2i = _v(p["cell"])
			assert_true(CELLS.has(pos), id + " cell exists")
			if key != "encounters_placed" and CELLS.has(pos):
				var kind: String = str(CELLS[pos][1])
				assert_true(kind == "normal", "%s in a %s room" % [id, kind])
