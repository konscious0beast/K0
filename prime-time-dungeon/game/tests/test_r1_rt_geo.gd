extends TestCase
## 07 §2.1–2.4, §3.5.4, §3.5.5 (R1b-I1): the set geometry — radius by room kind, door lanes, closed sets, blockers,
## clamping (project_walkable), line of sight, formation, the entry anchor of group-less combats — and how
## BattleBridge.make_rt_setup builds the set of the recorded cell (keep_cm ≤ 700 included).

var _bal: RtBalance = RtBalance.new()


func _geo(doors: int = 15, closed: bool = false) -> Dictionary:
	return RtGeo.make_geo(RoomCell.Kind.NORMAL, doors, closed, _bal)


func test_set_radius_by_room_kind() -> void:
	for k: int in [RoomCell.Kind.NORMAL, RoomCell.Kind.START, RoomCell.Kind.GATE, RoomCell.Kind.SAFE]:
		assert_eq(RtGeo.set_radius(k, _bal), 480, "regular kind %d" % k)
	for k: int in [RoomCell.Kind.QUARTER_BOSS, RoomCell.Kind.FLOOR_BOSS]:
		assert_eq(RtGeo.set_radius(k, _bal), 600, "boss kind %d" % k)
	assert_eq(RtGeo.set_radius(RoomCell.Kind.STAIRS, _bal), 0, "the stairs room has no set")
	assert_eq(RtGeo.set_radius(RoomCell.Kind.NORMAL, null), 480, "no balance → defaults")
	var tuned: RtBalance = RtBalance.from_values({"SET_R_CM": {"regular": 450, "boss": 620}})
	assert_eq([RtGeo.set_radius(RoomCell.Kind.NORMAL, tuned), RtGeo.set_radius(RoomCell.Kind.FLOOR_BOSS, tuned)],
		[450, 620], "the values come from rt_balance.json (R4)")
	var g: Dictionary = RtGeo.make_geo(RoomCell.Kind.FLOOR_BOSS, 5, true, _bal)
	assert_eq(g, {"r": 600, "doors": 5, "closed": true, "blockers": [], "door_half": 200, "cell_half": 800,
		"room_inner": 750})


func test_in_set_and_walkable_ring() -> void:
	var g: Dictionary = _geo()
	assert_true(RtGeo.in_set(g, 0, 480), "the ring itself")
	assert_false(RtGeo.in_set(g, 0, 481))
	assert_true(RtGeo.walkable(g, 0, 440, 40, false), "|p| = r − r_u")
	assert_false(RtGeo.walkable(g, 300, 330, 40, false), "|p| ≈ 446 > 440")
	assert_true(RtGeo.walkable(g, 0, 0, 40, false), "centre")
	assert_false(RtGeo.walkable({}, 0, 0, 40, true), "no set")


func test_door_lanes_are_party_only_and_open_only() -> void:
	var g: Dictionary = _geo(RoomCell.DOOR_N | RoomCell.DOOR_E)
	assert_true(RtGeo.walkable(g, 0, -600, 40, true), "north lane, party")
	assert_false(RtGeo.walkable(g, 0, -600, 40, false), "enemies never enter a lane")
	assert_true(RtGeo.walkable(g, 600, 0, 40, true), "east lane")
	assert_false(RtGeo.walkable(g, 0, 600, 40, true), "no south door")
	assert_false(RtGeo.walkable(g, -600, 0, 40, true), "no west door")
	assert_true(RtGeo.walkable(g, 160, -700, 40, true), "lane half width 200 − r_u")
	assert_false(RtGeo.walkable(g, 161, -700, 40, true))
	assert_true(RtGeo.walkable(g, 0, -800, 40, true), "up to the cell edge")
	assert_false(RtGeo.walkable(g, 0, -801, 40, true))
	# the lane mouth: off the centre line the circle ends before längs reaches r − r_u — no notch (contract note)
	assert_true(RtGeo.walkable(g, 150, -430, 40, true), "between circle and lane edge: walkable for the party")
	assert_true(RtGeo.in_gap(g, 150, -430, 40))
	var closed: Dictionary = _geo(RoomCell.DOOR_N | RoomCell.DOOR_E, true)
	assert_false(RtGeo.walkable(closed, 0, -600, 40, true), "a closed set has no lanes")
	assert_false(RtGeo.in_gap(closed, 0, -600, 0))


func test_blockers() -> void:
	var g: Dictionary = RtGeo.make_geo(RoomCell.Kind.FLOOR_BOSS, 0, true, _bal)
	g["blockers"] = [[-160, -80, 160, 80]]
	assert_false(RtGeo.walkable(g, 0, 0, 40, true), "inside the waggon")
	assert_false(RtGeo.walkable(g, 0, 100, 40, true), "grown by the unit radius")
	assert_true(RtGeo.walkable(g, 0, 120, 40, true), "the grown edge is walkable")
	assert_eq(RtGeo.project_walkable(g, 10, 70, 40, false), Vector2i(10, 120), "pushed out the nearest side")
	assert_eq(RtGeo.project_walkable(g, -150, 0, 40, false), Vector2i(-200, 0))
	assert_true(RtGeo.los(g, -300, 0, 300, 0), "blockers are low: no line of sight blocked")


func test_project_walkable() -> void:
	var g: Dictionary = _geo(RoomCell.DOOR_N)
	assert_eq(RtGeo.project_walkable(g, 100, 100, 40, false), Vector2i(100, 100), "walkable stays")
	var p: Vector2i = RtGeo.project_walkable(g, 0, 700, 40, false)
	assert_eq(p, Vector2i(0, 440), "onto the circle r − r_u")
	var q: Vector2i = RtGeo.project_walkable(g, 600, 600, 40, false)
	assert_true(RtGeo.walkable(g, q.x, q.y, 40, false), "a diagonal projection stays inside")
	assert_between(q.x * q.x + q.y * q.y, 438 * 438, 440 * 440)
	assert_eq(RtGeo.project_walkable(g, 300, -600, 40, true), Vector2i(160, -600), "the party clamps into the lane")
	var e: Vector2i = RtGeo.project_walkable(g, 300, -600, 40, false)
	assert_eq(e, Vector2i(197, -393), "enemies onto the circle (rounded inwards until inside)")
	assert_true(RtGeo.walkable(g, e.x, e.y, 40, false))
	assert_eq(RtGeo.project_walkable(g, 0, -900, 40, true), Vector2i(0, -800), "lane end")
	assert_eq(RtGeo.project_walkable({"r": 0}, 50, 50, 40, true), Vector2i.ZERO, "no set: the centre")


func test_line_of_sight() -> void:
	var g: Dictionary = _geo(RoomCell.DOOR_N)
	assert_true(RtGeo.los(g, -400, 0, 400, 0), "the set has no props")
	assert_true(RtGeo.los(g, 0, -700, 0, 300), "from a door lane")
	assert_false(RtGeo.los(g, 0, -900, 0, 300), "beyond the cell (a fled unit)")
	assert_false(RtGeo.los(g, 700, 700, 0, 0), "a room corner outside ring and lanes")


func test_formation_slots() -> void:
	assert_eq(RtGeo.formation(0, 100, 100, 0), Vector2i(100, 100))
	assert_eq(RtGeo.formation(1, 0, 0, 0), Vector2i(-130, 90), "yaw 0 (facing −Z): behind = +z")
	assert_eq(RtGeo.formation(2, 0, 0, 0), Vector2i(130, 90))
	assert_eq(RtGeo.formation(3, 0, 0, 0), Vector2i(0, 180))
	assert_eq(RtGeo.formation(3, 0, 0, 128), Vector2i(0, -180), "facing +Z: behind = −z")
	assert_eq(RtGeo.formation(1, 0, 0, 128), Vector2i(130, -90))
	assert_eq(RtGeo.formation(3, 50, 0, 192), Vector2i(-130, 0), "facing +X: behind = −x")
	assert_eq(RtGeo.formation(4, 0, 0, 0), Vector2i(0, 270), "further slots continue behind")


func test_group_anchor() -> void:
	var g: Dictionary = _geo(RoomCell.DOOR_N | RoomCell.DOOR_S)
	assert_eq(RtGeo.group_anchor(g, 0, -300), Vector2i(0, 750), "the door farthest from the figure (south)")
	assert_eq(RtGeo.group_anchor(g, 0, 300), Vector2i(0, -750))
	assert_eq(RtGeo.group_anchor(g, 0, 0), Vector2i(0, -750), "tie: N before S")
	var none: Dictionary = _geo(0)
	assert_eq(RtGeo.group_anchor(none, 300, 400), Vector2i(-288, -384), "no door: the ring point opposite")
	assert_eq(RtGeo.group_anchor(none, 0, 0), Vector2i(0, -480), "on the centre: north")
	var closed: Dictionary = _geo(RoomCell.DOOR_N, true)
	assert_eq(RtGeo.group_anchor(closed, 0, 480), Vector2i(0, -480), "closed set: doors do not count")


func test_make_rt_setup_builds_the_set_of_the_cell() -> void:
	var st: GameState = RtKit.state(3)
	var s: RtSetup = RtKit.setup(st, RtKit.dummy_cmd())
	assert_not_null(s)
	if s == null:
		return
	assert_eq(s.cell, Vector2i(3, 6))
	assert_eq(s.room_kind, RoomCell.Kind.NORMAL)
	assert_eq([s.geo["r"], s.geo["doors"], s.geo["closed"]], [480, 15, false], "fixture cell (3, 6): N E S W")
	var cmd: Dictionary = RtKit.dummy_cmd()
	cmd["rt"]["cell"] = [2, 6]
	var safe: RtSetup = RtKit.setup(st, cmd)
	assert_eq([safe.room_kind, safe.geo["doors"]], [RoomCell.Kind.SAFE, RoomCell.DOOR_E])
	var stairs: Dictionary = RtKit.dummy_cmd()
	stairs["rt"]["cell"] = [3, 5]
	assert_null(RtKit.setup(st, stairs), "no combat in the stairs room")
	var boss: RtSetup = RtKit.setup(st, RtKit.encounter("enc_rt_test_boss", [["g_b", "enc_rt_test_boss",
		[0, -200, 128]]]))
	assert_true(bool(boss.geo["closed"]), "boss: closed set")
	assert_eq(boss.advantage, BattleSetup.Advantage.NORMAL)
	var tut: RtSetup = RtKit.setup(st, RtKit.encounter("enc_f1_a1_tutorial", [["g_t", "enc_f1_a1_tutorial",
		[0, -200, 128]]]))
	assert_true(bool(tut.geo["closed"]), "tutorial: closed set")
	var nofloor: GameState = RtKit.state(3)
	nofloor.floor_run = null
	var plain: RtSetup = RtKit.setup(nofloor, RtKit.dummy_cmd())
	assert_eq([plain.room_kind, plain.geo["doors"], plain.geo["r"]], [RoomCell.Kind.NORMAL, 0, 480],
		"without a floor run: a regular set without doors")


func test_keep_distance_is_capped_at_700() -> void:
	var st: GameState = RtKit.state(3, "kai")
	for preset: String in ["attack", "support", "careful"]:
		st.member("mopsula").rt_preset = preset
		var s: RtSetup = RtKit.setup(st, RtKit.dummy_cmd({"presets": {}}))
		var mop: RtUnit = null
		for u: RtUnit in s.units:
			if u.def_id == "mopsula":
				mop = u
		assert_eq(mop.keep_cm, {"attack": 450, "support": 600, "careful": 700}[preset], preset)
		assert_true(mop.keep_cm <= 700)
	for u: RtUnit in RtKit.setup(st, RtKit.encounter("enc_f1_a2", [["g", "enc_f1_a2", [0, -300, 128]]])).units:
		assert_true(u.keep_cm <= 700, u.id)
