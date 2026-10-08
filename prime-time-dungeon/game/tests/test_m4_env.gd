extends TestCase
## M4 environment (02_TECH §8.5, §11.5, §12.1; 03_ART §4/§6): build_room for all 16 door masks × kinds × zone styles
## (children, budgets, open doors, closed walls, clear radius, determinism, build time), kind set pieces and anchors,
## arena, the three safe-room themes, Environment/sun, every PropKit prop and the chest.

const RB := preload("res://art/kit/room_builder.gd")
const ZONES: PackedStringArray = ["platform", "sewer", "cellar", "track9", "safe", "boss_office", "throne", "mall"]
const KINDS: Array[RoomSpec.Kind] = [RoomSpec.Kind.START, RoomSpec.Kind.NORMAL, RoomSpec.Kind.SAFE,
	RoomSpec.Kind.QUARTER_BOSS, RoomSpec.Kind.FLOOR_BOSS, RoomSpec.Kind.STAIRS, RoomSpec.Kind.GATE]
## Interactive set pieces a room may add next to Geometry + Props (02_TECH §12.1 "2 + Interaktives").
const SET_PIECE_NAMES: PackedStringArray = ["Stairs", "SafeDoor"]


# --- helpers ---------------------------------------------------------------------------------------------------------

func _spec(mask: int, kind: RoomSpec.Kind, zone: String, variant: int = 0, seed: int = 1,
		quality: StringName = &"high") -> RoomSpec:
	var s := RoomSpec.new()
	s.doors = mask
	s.kind = kind
	s.variant = variant
	s.seed = seed
	s.quality = quality
	s.theme_id = "mall" if zone == "mall" else "metro"
	var p: Dictionary = {}
	for k: String in Palette.PALETTE_KEYS:
		p[k] = Palette.ZONE_PRESETS[zone][k]
	s.palette = p
	return s


## World-space AABBs of the room's collision boxes (room at the origin, outside the tree).
func _boxes(room: Node3D) -> Array[AABB]:
	var out: Array[AABB] = []
	var body: StaticBody3D = room.get_node_or_null("Collision") as StaticBody3D
	if body == null:
		return out
	for c: Node in body.get_children():
		var cs: CollisionShape3D = c as CollisionShape3D
		if cs == null or not (cs.shape is BoxShape3D):
			continue
		var size: Vector3 = (cs.shape as BoxShape3D).size
		out.append((body.transform * cs.transform) * AABB(-size * 0.5, size))
	return out


func _door_volume(side: int) -> AABB:
	var a: Vector3 = RB.edge_xf(side, -1.9, 0.1, -0.6).origin
	var b: Vector3 = RB.edge_xf(side, 1.9, 2.4, 0.6).origin
	return AABB(a, Vector3.ZERO).expand(b)


## 4 m wide × 3 m deep × 2.2 m high free corridor in front of a door (edge frame, slightly inset from the jambs).
func _corridor_volume(side: int) -> AABB:
	var a: Vector3 = RB.edge_xf(side, -1.95, 0.05, 0.05).origin
	var b: Vector3 = RB.edge_xf(side, 1.95, 2.2, 3.0).origin
	return AABB(a, Vector3.ZERO).expand(b)


func _count(root: Node, cls: String) -> int:
	var n: int = 1 if root.is_class(cls) else 0
	for c: Node in root.get_children():
		n += _count(c, cls)
	return n


func _materials(n: Node, acc: Dictionary) -> void:
	var g: GeometryInstance3D = n as GeometryInstance3D
	if g != null and not (n is Label3D):
		var m: Material = g.material_override
		if m == null and n is MeshInstance3D and (n as MeshInstance3D).mesh != null \
				and (n as MeshInstance3D).mesh.get_surface_count() > 0:
			m = (n as MeshInstance3D).mesh.surface_get_material(0)
		if m != null:
			acc[m.get_instance_id()] = true
			if m.next_pass != null:
				acc[m.next_pass.get_instance_id()] = true
	for c: Node in n.get_children():
		_materials(c, acc)


func _labels(n: Node, out: Array[Label3D]) -> void:
	if n is Label3D:
		out.append(n as Label3D)
	for c: Node in n.get_children():
		_labels(c, out)


func _glyphs_ok(text: String) -> bool:
	var font: Font = ThemeDB.fallback_font
	for i in text.length():
		var ch: int = text.unicode_at(i)
		if ch == 32 or ch == 10:
			continue
		if not font.has_char(ch):
			return false
	return true


# --- rooms ------------------------------------------------------------------------------------------------------------

func test_build_room_all_masks_kinds_and_zones() -> void:
	var t0: int = Time.get_ticks_usec()
	var built: int = 0
	for zone: String in ZONES:
		for mask in 16:
			for kind: RoomSpec.Kind in KINDS:
				var spec: RoomSpec = _spec(mask, kind, zone, (mask + int(kind)) % 4, mask * 7 + int(kind))
				var room: Node3D = EnvKit.build_room(spec)
				built += 1
				var ctx: String = "%s mask %d kind %s" % [zone, mask, RoomSpec.Kind.keys()[kind]]
				var geo: MeshInstance3D = room.get_node_or_null("Geometry") as MeshInstance3D
				var props: MeshInstance3D = room.get_node_or_null("Props") as MeshInstance3D
				var body: StaticBody3D = room.get_node_or_null("Collision") as StaticBody3D
				assert_not_null(geo, ctx + ": Geometry")
				assert_not_null(props, ctx + ": Props")
				assert_not_null(body, ctx + ": Collision")
				if geo == null or props == null or body == null:
					room.free()
					continue
				assert_eq(geo.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, ctx)
				var gt: int = MeshUtil.tri_count(geo.mesh)
				var pt: int = MeshUtil.tri_count(props.mesh)
				assert_true(gt <= 1500, "%s: geometry %d tris > 1500" % [ctx, gt])
				assert_true(pt <= 2500, "%s: props %d tris > 2500" % [ctx, pt])
				assert_eq(body.collision_layer, 1, ctx)
				assert_eq(_count(room, "StaticBody3D"), 1, ctx + ": one static body (set pieces merged)")
				for c: Node in room.get_children():
					if c is MeshInstance3D:
						assert_true(c == geo or c == props, "%s: extra MeshInstance %s" % [ctx, c.name])
					elif c is Node3D and not (c is Light3D) and not (c is Label3D) and c != body:
						assert_has(SET_PIECE_NAMES, String(c.name), ctx + ": only interactive set pieces")
				for cs: Node in body.get_children():
					assert_true((cs as CollisionShape3D).shape is BoxShape3D, ctx + ": box shapes only")
				var boxes: Array[AABB] = _boxes(room)
				# floor box first, spans the room
				assert_gt(boxes.size(), 4, ctx)
				for side: int in RB.SIDES:
					var door: AABB = _door_volume(side)
					var blocked: bool = false
					for b: AABB in boxes:
						if b.intersects(door):
							blocked = true
					if (mask & side) != 0:
						assert_false(blocked, "%s: door %d is open" % [ctx, side])
					else:
						assert_true(blocked, "%s: wall %d is closed" % [ctx, side])
				if kind != RoomSpec.Kind.STAIRS:
					for i in range(1, boxes.size()):
						var b: AABB = boxes[i]
						if b.end.y < 0.05 or b.position.y > 2.2:
							continue
						var closest := Vector2(clampf(0.0, b.position.x, b.end.x), clampf(0.0, b.position.z, b.end.z))
						assert_true(closest.length() >= EnvKit.CLEAR_RADIUS - 0.001,
							"%s: collision %s inside the clear radius" % [ctx, b])
				var light: OmniLight3D = room.get_node_or_null("Light") as OmniLight3D
				assert_not_null(light, ctx + ": Light")
				var omni: int = _count(room, "OmniLight3D")
				if kind == RoomSpec.Kind.STAIRS or kind == RoomSpec.Kind.SAFE:
					assert_true(omni <= 2, ctx + ": Light + at most one short-range Neon")
					var neon: OmniLight3D = room.get_node_or_null("Neon") as OmniLight3D
					if neon != null:
						assert_true(neon.distance_fade_begin + neon.distance_fade_length <= 16.0, ctx + ": neon fades by 16 m")
				else:
					assert_eq(omni, 1, ctx + ": exactly one OmniLight3D (02_TECH §8.5/§12.1)")
				# 3 m deep corridor in front of every open door is collision-free (02_TECH §7.3), all kinds
				for side: int in RB.SIDES:
					if (mask & side) == 0:
						continue
					var corridor: AABB = _corridor_volume(side)
					for i in range(1, boxes.size()):
						assert_false(boxes[i].intersects(corridor), "%s: collision %s in the corridor of door %d"
							% [ctx, boxes[i], side])
				room.free()
	var avg_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0 / float(built)
	assert_lt(avg_ms, 30.0, "average room build time %.1f ms (floor budget 500 ms)" % avg_ms)


func test_floor_box_and_light_params() -> void:
	var room: Node3D = EnvKit.build_room(_spec(5, RoomSpec.Kind.NORMAL, "platform"))
	var boxes: Array[AABB] = _boxes(room)
	assert_almost(boxes[0].size.x, EnvKit.ROOM_SIZE, 0.01, "floor box covers the room")
	assert_almost(boxes[0].end.y, 0.0, 0.001, "floor top at y 0")
	var light: OmniLight3D = room.get_node("Light") as OmniLight3D
	assert_almost(light.position.y, 3.0)
	assert_almost(light.omni_range, 9.0)
	assert_almost(light.light_energy, 1.2)
	assert_false(light.shadow_enabled)
	assert_true(light.distance_fade_enabled)
	assert_almost(light.distance_fade_begin, 24.0)
	assert_almost(light.distance_fade_length, 6.0)
	var lights: int = _count(room, "OmniLight3D")
	assert_eq(lights, 1, "one omni light in a NORMAL room (budget 4 in 24 m)")
	room.free()
	var no_light := _spec(5, RoomSpec.Kind.NORMAL, "platform")
	no_light.with_light = false
	var dark: Node3D = EnvKit.build_room(no_light)
	assert_eq(_count(dark, "Light3D"), 0, "with_light = false")
	dark.free()
	var low: Node3D = EnvKit.build_room(_spec(5, RoomSpec.Kind.START, "platform", 1, 1, &"low"))
	assert_eq(_count(low, "OmniLight3D"), 1, "quality low: only the main light")
	low.free()
	var empty: Node3D = EnvKit.build_room(null)
	assert_eq(empty.get_child_count(), 0, "null spec → empty node")
	empty.free()


func test_rooms_are_deterministic() -> void:
	for kind: RoomSpec.Kind in KINDS:
		var a: Node3D = EnvKit.build_room(_spec(11, kind, "sewer", 2, 42))
		var b: Node3D = EnvKit.build_room(_spec(11, kind, "sewer", 2, 42))
		var ga: ArrayMesh = (a.get_node("Geometry") as MeshInstance3D).mesh as ArrayMesh
		var gb: ArrayMesh = (b.get_node("Geometry") as MeshInstance3D).mesh as ArrayMesh
		assert_eq(MeshUtil.tri_count(ga), MeshUtil.tri_count(gb))
		assert_eq((ga.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array),
			(gb.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array), "identical vertices")
		var pa: ArrayMesh = (a.get_node("Props") as MeshInstance3D).mesh as ArrayMesh
		var pb: ArrayMesh = (b.get_node("Props") as MeshInstance3D).mesh as ArrayMesh
		assert_eq(MeshUtil.tri_count(pa), MeshUtil.tri_count(pb))
		if pa.get_surface_count() > 0:
			assert_true(pa.get_aabb().is_equal_approx(pb.get_aabb()), "identical props")
		assert_eq(_boxes(a), _boxes(b), "identical collision")
		a.free()
		b.free()
	var v: Array[int] = []
	for seed: int in [1, 2, 3, 4, 5, 6]:
		var r: Node3D = EnvKit.build_room(_spec(0, RoomSpec.Kind.NORMAL, "cellar", 0, seed))
		v.append(MeshUtil.tri_count((r.get_node("Props") as MeshInstance3D).mesh))
		r.free()
	var distinct: Dictionary = {}
	for n: int in v:
		distinct[n] = true
	assert_gt(distinct.size(), 1, "seed varies the dressing")


func test_zone_styles_differ() -> void:
	var mats: Dictionary = {}
	for zone: String in ZONES:
		var r: Node3D = EnvKit.build_room(_spec(5, RoomSpec.Kind.NORMAL, zone))
		var m: ShaderMaterial = (r.get_node("Geometry") as MeshInstance3D).material_override as ShaderMaterial
		assert_eq(m.shader.resource_path, "res://art/shaders/env_tiles.gdshader", zone)
		assert_null(m.next_pass, zone + ": no outline on the environment")
		mats[zone] = m
		var acc: Dictionary = {}
		_materials(r, acc)
		assert_true(acc.size() <= 12, "%s: %d materials in one room" % [zone, acc.size()])
		r.free()
	assert_true(mats["platform"] != mats["sewer"], "zone shade/grout → own material")
	var plat: Color = (mats["platform"] as ShaderMaterial).get_shader_parameter(&"shade_color")
	assert_eq(plat.to_html(false), "4a3e78", "platform shade")


# --- kind set pieces + anchors --------------------------------------------------------------------------------------

func test_kind_set_pieces() -> void:
	var stairs: Node3D = EnvKit.build_room(_spec(5, RoomSpec.Kind.STAIRS, "platform"))
	var s: Node3D = stairs.get_node_or_null("Stairs") as Node3D
	assert_not_null(s, "STAIRS → stairs_down")
	if s != null:
		var at: Transform3D = EnvKit.anchor_for(_spec(5, RoomSpec.Kind.STAIRS, "platform"), &"stairs")
		assert_true(s.transform.is_equal_approx(at), "stairs at anchor stairs")
		assert_eq(_count(s, "StaticBody3D"), 0, "stairs collision merged into the room body")
		var labels: Array[Label3D] = []
		_labels(s, labels)
		assert_gt(labels.size(), 0, "stairs label")
	stairs.free()
	for mask: int in [0, 1, 5, 7, 14]:
		var spec: RoomSpec = _spec(mask, RoomSpec.Kind.SAFE, "platform")
		var room: Node3D = EnvKit.build_room(spec)
		var door: Node3D = room.get_node_or_null("SafeDoor") as Node3D
		assert_not_null(door, "SAFE → safe_door (mask %d)" % mask)
		if door != null:
			var at2: Transform3D = EnvKit.anchor_for(spec, &"safe_door")
			assert_true(door.transform.origin.is_equal_approx(at2.origin + at2.basis * Vector3(0, 0, 0)),
				"safe door origin at anchor (mask %d)" % mask)
		room.free()
	var start: Node3D = EnvKit.build_room(_spec(5, RoomSpec.Kind.START, "platform"))
	var live: Label3D = start.get_node_or_null("LiveLabel") as Label3D
	assert_not_null(live, "START → LIVE label")
	if live != null:
		assert_eq(live.text, "LIVE")
	start.free()
	var office: Node3D = EnvKit.build_room(_spec(0, RoomSpec.Kind.QUARTER_BOSS, "boss_office"))
	assert_not_null(office.get_node_or_null("HausordnungLabel"), "QUARTER_BOSS → notice board")
	office.free()


func test_anchor_for() -> void:
	var spec: RoomSpec = _spec(0, RoomSpec.Kind.NORMAL, "platform")
	for a: StringName in [&"player_spawn", &"stairs", &"boss_spot"]:
		assert_eq(EnvKit.anchor_for(spec, a), Transform3D.IDENTITY, String(a))
	for mask in 15:
		spec.doors = mask
		var t: Transform3D = EnvKit.anchor_for(spec, &"safe_door")
		var first_free: int = 0
		for side: int in RB.SIDES:
			if (mask & side) == 0:
				first_free = side
				break
		var expected: Vector3 = RB.edge_xf(first_free, 0.0, 0.0, 0.6).origin
		assert_true(t.origin.is_equal_approx(expected), "mask %d: door on the first wall without door" % mask)
		assert_almost(t.origin.length(), EnvKit.WALL_INNER - 0.6, 0.001, "0.6 m in front of the wall")
		var facing: Vector3 = -t.basis.z
		assert_true(facing.is_equal_approx(-t.origin.normalized()), "mask %d: faces the room center" % mask)
	# stairs: center; the well (local −Z) descends toward the first wall without door (02_TECH §7.3 corridors)
	for mask in 16:
		spec.doors = mask
		var st: Transform3D = EnvKit.anchor_for(spec, &"stairs")
		assert_true(st.origin.is_equal_approx(Vector3.ZERO), "mask %d: stairs at the center" % mask)
		var well_dir: Vector3 = -st.basis.z
		var target: Vector3 = Vector3(0, 0, -1)
		for side: int in RB.SIDES:
			if (mask & side) == 0:
				target = RB.edge_origin(side).normalized()
				break
		assert_true(well_dir.is_equal_approx(target), "mask %d: well toward %s, got %s" % [mask, target, well_dir])
	spec.doors = 15
	var c: Transform3D = EnvKit.anchor_for(spec, &"safe_door")
	assert_true(c.origin.is_equal_approx(Vector3.ZERO))
	assert_true((-c.basis.z).is_equal_approx(Vector3(0, 0, 1)), "4 doors → center, facing +Z")
	assert_eq(EnvKit.anchor_for(spec, &"nowhere"), Transform3D.IDENTITY)


# --- arena + safe room -----------------------------------------------------------------------------------------------

func test_battle_arena() -> void:
	for is_boss: bool in [false, true]:
		var t0: int = Time.get_ticks_usec()
		var arena: Node3D = EnvKit.build_battle_arena("metro", {}, is_boss, 3)
		var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
		assert_lt(ms, 300.0, "arena build time %.1f ms" % ms)
		add_to_tree(arena)
		var tris: int = MeshUtil.tri_count_tree(arena)
		assert_true(tris <= 8000, "arena %d tris > 8000" % tris)
		assert_eq(_count(arena, "DirectionalLight3D"), 0, "no sun in the arena (make_sun)")
		assert_true(_count(arena, "OmniLight3D") <= 2, "≤ 2 omni lights in battle")
		var acc: Dictionary = {}
		_materials(arena, acc)
		assert_true(acc.size() <= 24, "arena materials %d > 24" % acc.size())
		var labels: Array[Label3D] = []
		_labels(arena, labels)
		var texts: PackedStringArray = []
		for l: Label3D in labels:
			texts.append(l.text)
			assert_true(_glyphs_ok(l.text), "fallback font has all glyphs of '%s'" % l.text)
		assert_has(texts, "BOSSKAMPF" if is_boss else "DUNGEON PRIME TIME")
		assert_true(_count(arena, "Label3D") <= 12, "Label3D budget")
	var low: Node3D = EnvKit.build_battle_arena("metro", {}, false, 3, &"low")
	assert_eq(_count(low, "SpotLight3D"), 0, "quality low: no spot lights")
	low.free()
	var mall: Node3D = EnvKit.build_battle_arena("mall", {}, false, 3)
	assert_gt(MeshUtil.tri_count_tree(mall), 0, "mall arena")
	mall.free()


func test_safe_room_all_themes() -> void:
	for theme: StringName in [&"kiosk", &"pumphouse", &"signalbox"]:
		var t0: int = Time.get_ticks_usec()
		var room: Node3D = EnvKit.build_safe_room(4, &"high", theme)
		var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
		assert_lt(ms, 300.0, "%s build time %.1f ms" % [theme, ms])
		add_to_tree(room)
		for pair: Array in [["vending_machine", &"vending"], ["save_terminal", &"terminal"], ["couch", &"couch"],
				["safe_door", &"door"]]:
			var n: Node3D = room.get_node_or_null(str(pair[0])) as Node3D
			assert_not_null(n, "%s: %s" % [theme, pair[0]])
			if n != null:
				var at: Transform3D = EnvKit.safe_room_anchor(pair[1] as StringName)
				assert_true(n.transform.origin.is_equal_approx(at.origin), "%s: %s at its anchor" % [theme, pair[0]])
		assert_true(_count(room, "OmniLight3D") <= 3, "≤ 3 omni lights in the safe room")
		assert_eq(_count(room, "DirectionalLight3D"), 0)
		var acc: Dictionary = {}
		_materials(room, acc)
		assert_true(acc.size() <= 16, "%s: %d materials > 16" % [theme, acc.size()])
		assert_true(MeshUtil.tri_count_tree(room) <= 6000, "%s safe room tris" % theme)
		var labels: Array[Label3D] = []
		_labels(room, labels)
		for l: Label3D in labels:
			assert_true(_glyphs_ok(l.text), "%s: glyphs of '%s'" % [theme, l.text])
	var low: Node3D = EnvKit.build_safe_room(4, &"low", &"kiosk")
	assert_true(_count(low, "OmniLight3D") <= 2, "quality low: ≤ 2 lights")
	low.free()
	var anchors_seen: Dictionary = {}
	for a: StringName in [&"vending", &"terminal", &"couch", &"mopsula_spot", &"player_spot", &"door"]:
		var t: Transform3D = EnvKit.safe_room_anchor(a)
		assert_true(absf(t.origin.x) < 6.0 and absf(t.origin.z) < 5.0, "%s inside the 12 × 10 m room" % a)
		anchors_seen[t.origin] = true
	assert_eq(anchors_seen.size(), 6, "distinct anchors")
	var cam: Transform3D = EnvKit.safe_room_anchor(&"camera")
	var look: Vector3 = -cam.basis.z
	assert_gt(cam.origin.z, 3.0, "camera in front of the room")
	assert_lt(look.z, -0.5, "camera looks into the room")
	var to_couch: Vector3 = (EnvKit.safe_room_anchor(&"couch").origin - cam.origin).normalized()
	assert_gt(look.dot(to_couch), 0.8, "couch in view")
	# the exit door (only interaction target to leave) is in frame at 4:3, 16:9 and 20:9 with FOV 50 (03_ART §8.1)
	var door_pt: Vector3 = EnvKit.safe_room_anchor(&"door").origin + Vector3(0, 1.4, 0)
	for size: Vector2i in [Vector2i(1024, 768), Vector2i(1280, 720), Vector2i(1600, 720)]:
		var vp := SubViewport.new()
		vp.size = size
		vp.own_world_3d = true
		add_to_tree(vp)
		var c3 := Camera3D.new()
		c3.fov = 50.0
		vp.add_child(c3)
		c3.transform = cam
		c3.current = true
		assert_true(c3.is_position_in_frustum(door_pt), "door in frame at %s" % size)
		for a: StringName in [&"vending", &"terminal", &"couch"]:
			assert_true(c3.is_position_in_frustum(EnvKit.safe_room_anchor(a).origin + Vector3(0, 1.0, 0)),
				"%s in frame at %s" % [a, size])
	assert_eq(EnvKit.safe_room_anchor(&"nowhere"), Transform3D.IDENTITY)


# --- environment + sun ------------------------------------------------------------------------------------------------

func test_make_environment() -> void:
	var ex: Environment = EnvKit.make_environment("metro", {}, &"explore")
	assert_eq(ex.background_mode, Environment.BG_COLOR)
	assert_eq(ex.tonemap_mode, Environment.TONE_MAPPER_AGX)
	assert_eq(ex.ambient_light_source, Environment.AMBIENT_SOURCE_COLOR)
	assert_almost(ex.ambient_light_energy, 0.8)
	assert_true(ex.fog_enabled)
	assert_almost(ex.fog_density, 0.03)
	assert_true(ex.glow_enabled, "glow on high")
	assert_eq(ex.background_color.to_html(false), Palette.mul(Color("#1a1430"), 0.6).to_html(false), "bg = fog × 0.6")
	for e: Environment in [ex, EnvKit.make_environment("metro", {}, &"battle", &"low"),
			EnvKit.make_environment("mall", {}, &"safe")]:
		assert_false(e.ssao_enabled or e.ssil_enabled or e.ssr_enabled or e.sdfgi_enabled or e.volumetric_fog_enabled,
			"forbidden effects off (02_TECH §12.1)")
	var battle: Environment = EnvKit.make_environment("metro", {}, &"battle", &"low")
	assert_almost(battle.ambient_light_energy, 0.9)
	assert_almost(battle.fog_density, 0.02)
	assert_false(battle.glow_enabled, "no glow on low")
	var safe: Environment = EnvKit.make_environment("metro", {}, &"safe")
	assert_false(safe.fog_enabled)
	assert_almost(safe.ambient_light_energy, 1.1)
	var sewer_pal: Dictionary = {}
	for k: String in Palette.PALETTE_KEYS:
		sewer_pal[k] = Palette.ZONE_PRESETS["sewer"][k]
	var sewer: Environment = EnvKit.make_environment("metro", sewer_pal, &"explore")
	assert_almost(sewer.fog_density, 0.05, 0.0001, "sewer: denser fog")
	assert_gt(sewer.fog_height_density, 0.0, "sewer: height fog")
	assert_eq(sewer.ambient_light_color.to_html(false), "1e3530")


func test_make_sun() -> void:
	var ex: DirectionalLight3D = EnvKit.make_sun("metro", &"explore")
	assert_true(ex.shadow_enabled)
	assert_almost(ex.directional_shadow_max_distance, 30.0)
	assert_almost(ex.light_energy, 1.1)
	assert_true(ex.rotation_degrees.is_equal_approx(EnvKit.EXPLORE_SUN_ROTATION))
	# side/back key: ≥ 50° away from the follow camera's view direction (pitch −38°, yaw 0 → looking −Z)
	var light_dir: Vector3 = -ex.basis.z.normalized()
	var view_dir: Vector3 = Basis.from_euler(Vector3(deg_to_rad(-38.0), 0, 0)) * Vector3(0, 0, -1)
	assert_lt(light_dir.dot(view_dir), cos(deg_to_rad(50.0)), "explore key does not shine along the camera view")
	var sewer_pal: Dictionary = {}
	var cellar_pal: Dictionary = {}
	for k: String in Palette.PALETTE_KEYS:
		sewer_pal[k] = Palette.ZONE_PRESETS["sewer"][k]
		cellar_pal[k] = Palette.ZONE_PRESETS["cellar"][k]
	var sewer_sun: DirectionalLight3D = EnvKit.make_zone_sun("metro", sewer_pal, &"explore")
	assert_almost(sewer_sun.light_energy, 0.7, 0.001, "sewer key energy (03_ART §4.3)")
	assert_eq(sewer_sun.light_color.to_html(false), "9fe0c0", "sewer key color")
	var cellar_sun: DirectionalLight3D = EnvKit.make_zone_sun("metro", cellar_pal, &"explore")
	assert_almost(cellar_sun.light_energy, 0.9, 0.001, "cellar key energy")
	assert_eq(cellar_sun.light_color.to_html(false), "ffc98a")
	sewer_sun.free()
	cellar_sun.free()
	var b: DirectionalLight3D = EnvKit.make_sun("metro", &"battle")
	assert_almost(b.directional_shadow_max_distance, 20.0)
	assert_almost(b.light_energy, 1.25)
	var s: DirectionalLight3D = EnvKit.make_sun("metro", &"safe")
	assert_almost(s.directional_shadow_max_distance, 15.0)
	assert_eq(s.light_color.to_html(false), "ffe2b8")
	var low: DirectionalLight3D = EnvKit.make_sun("metro", &"explore", &"low")
	assert_false(low.shadow_enabled, "shadows only on high")
	for l: DirectionalLight3D in [ex, b, s, low]:
		l.free()


# --- props ------------------------------------------------------------------------------------------------------------

func test_every_prop_builds() -> void:
	for id: String in PropKit.IDS:
		var p: Node3D = PropKit.build(StringName(id), 3)
		add_to_tree(p)
		assert_eq(String(p.name), id)
		var tris: int = MeshUtil.tri_count_tree(p)
		assert_gt(tris, 0, id + " has geometry")
		assert_true(tris <= 2500, "%s: %d tris" % [id, tris])
		var main: MeshInstance3D = p.find_child("Mesh", true, false) as MeshInstance3D   # main or first pivot mesh
		if id == "chest":
			main = p.get_node_or_null("Body") as MeshInstance3D
		assert_not_null(main, id + " main mesh")
		if main != null:
			var mat: ShaderMaterial = main.material_override as ShaderMaterial
			if PropKit.is_interactive(StringName(id)):
				assert_eq(mat.shader.resource_path, "res://art/shaders/toon.gdshader", id + ": interactive → toon")
				assert_not_null(mat.next_pass, id + ": outline")
				if mat.next_pass != null:
					assert_almost(float((mat.next_pass as ShaderMaterial).get_shader_parameter(&"outline_width")), 0.02)
			else:
				assert_eq(mat.shader.resource_path, "res://art/shaders/env_tiles.gdshader", id + ": dressing → env")
				assert_null(mat.next_pass, id + ": no outline")
		var labels: Array[Label3D] = []
		_labels(p, labels)
		for l: Label3D in labels:
			assert_true(_glyphs_ok(l.text), "%s: glyphs of '%s'" % [id, l.text])
		var body: StaticBody3D = p.get_node_or_null("Collision") as StaticBody3D
		if body != null:
			assert_eq(body.collision_layer, 1, id)
			for cs: Node in body.get_children():
				assert_true((cs as CollisionShape3D).shape is BoxShape3D, id + ": box shapes only")
	var chest: Node3D = PropKit.build(&"chest")
	assert_true(chest is ChestProp)
	chest.free()
	assert_true(PropKit.is_interactive(&"stairs_down"))
	assert_false(PropKit.is_interactive(&"crate"))


func test_props_deterministic_and_unknown() -> void:
	for id: String in PropKit.IDS:
		var a: Node3D = PropKit.build(StringName(id), 9)
		var b: Node3D = PropKit.build(StringName(id), 9)
		assert_eq(MeshUtil.tri_count_tree(a), MeshUtil.tri_count_tree(b), id)
		a.free()
		b.free()
	var unknown: Node3D = PropKit.build(&"flux_capacitor")
	assert_eq(unknown.get_child_count(), 0, "unknown prop → empty node")
	unknown.free()
	assert_eq(PropKit.recipe("flux_capacitor", 0, {}), {})
	var labelled: Node3D = PropKit.build(&"stairs_down", 1, {"label": "ETAGE 3"})
	var labels: Array[Label3D] = []
	_labels(labelled, labels)
	var found: bool = false
	for l: Label3D in labels:
		if l.text == "ETAGE 3":
			found = true
	assert_true(found, "palette 'label' sets the stairs text")
	labelled.free()


func test_prop_actions() -> void:
	var lever: Node3D = PropKit.build(&"lever", 1)
	add_to_tree(lever)
	var arm: Node3D = lever.find_child("Arm", true, false) as Node3D
	assert_not_null(arm, "lever arm pivot")
	if arm != null:
		var rest: Basis = arm.transform.basis
		lever.call("play_action")
		await wait_frames(3)
		lever.call("_process", 0.2)
		assert_false(arm.transform.basis.is_equal_approx(rest), "lever pulled")
		for i in 40:
			lever.call("_process", 0.05)
		assert_true(arm.transform.basis.is_equal_approx(rest), "lever returns")
	var door: Node3D = PropKit.build(&"safe_door", 1)
	add_to_tree(door)
	assert_false(bool(door.call("is_open")))
	door.call("play_action")
	assert_true(bool(door.call("is_open")))
	var left: Node3D = door.find_child("Left", true, false) as Node3D
	assert_not_null(left)
	if left != null:
		var x0: float = left.position.x
		door.set_process(false)
		for i in 20:
			door.call("_process", 0.05)
		assert_lt(left.position.x, x0 - 1.5, "left panel slid open")


func test_chest_open_in_tree() -> void:
	var host := Node3D.new()
	add_to_tree(host)
	var chest: ChestProp = PropKit.build(&"chest", 2) as ChestProp
	host.add_child(chest)
	assert_false(chest.is_open)
	var lid: Node3D = chest.get_node("Lid") as Node3D
	var glow: Node3D = chest.get_node("Glow") as Node3D
	assert_false(glow.visible)
	var fired: Array[int] = [0]
	chest.opened.connect(func() -> void: fired[0] += 1)
	chest.open()
	assert_true(chest.is_open, "is_open set at once")
	assert_eq(fired[0], 0, "opened waits for the lid tween")
	var ok: bool = await wait_until(func() -> bool: return fired[0] == 1, 3000)
	assert_true(ok, "opened emitted")
	assert_almost(rad_to_deg(lid.rotation.x), ChestProp.LID_OPEN_DEG, 0.5, "lid at 110°")
	assert_true(glow.visible)
	assert_true(host.has_meta(Vfx.POOL_META), "chest_open effect spawned into the parent")
	chest.open()
	assert_eq(fired[0], 2, "open() on an open chest re-emits opened")
	chest.set_style("metal")
	assert_eq(chest.chest_type, "metal")
	assert_true(chest.is_open, "style change keeps the open state")
	await wait_frames(1)
	assert_almost(rad_to_deg((chest.get_node("Lid") as Node3D).rotation.x), ChestProp.LID_OPEN_DEG, 0.5)


func test_chest_interrupted_open_still_emits_once() -> void:
	for how: String in ["set_open_instant", "set_style"]:
		var host := Node3D.new()
		add_to_tree(host)
		var chest: ChestProp = PropKit.build(&"chest", 2) as ChestProp
		host.add_child(chest)
		var fired: Array[int] = [0]
		chest.opened.connect(func() -> void: fired[0] += 1)
		chest.open(true)
		await wait_frames(2)
		assert_eq(fired[0], 0, how + ": tween still running")
		if how == "set_open_instant":
			chest.set_open_instant()
		else:
			chest.set_style("metal")
		assert_eq(fired[0], 1, how + " during the lid tween emits the owed opened")
		await wait_frames(60)
		assert_eq(fired[0], 1, how + ": exactly once")
		assert_true(chest.is_open)
		chest.set_open_instant()
		assert_eq(fired[0], 1, "set_open_instant on an idle chest emits nothing")


## M4 verify: a second open() while the lid tween runs must not emit `opened` early (a caller awaiting the first
## open() would return before the lid is open); the single emission comes when the lid is fully open.
func test_chest_second_open_during_tween_waits_for_the_lid() -> void:
	var host := Node3D.new()
	add_to_tree(host)
	var chest: ChestProp = PropKit.build(&"chest", 2) as ChestProp
	host.add_child(chest)
	var fired: Array[int] = [0]
	chest.opened.connect(func() -> void: fired[0] += 1)
	chest.open()
	await wait_frames(2)
	chest.open()
	assert_eq(fired[0], 0, "no early opened while the lid moves")
	var ok: bool = await wait_until(func() -> bool: return fired[0] == 1, 3000)
	assert_true(ok, "opened once the lid is open")
	assert_almost(rad_to_deg((chest.get_node("Lid") as Node3D).rotation.x), ChestProp.LID_OPEN_DEG, 0.5)
	await wait_frames(10)
	assert_eq(fired[0], 1, "exactly one emission for both calls")


func test_chest_open_outside_tree() -> void:
	var chest: ChestProp = PropKit.build(&"chest", 2) as ChestProp
	var fired: Array[int] = [0]
	chest.opened.connect(func() -> void: fired[0] += 1)
	chest.open()
	assert_eq(fired[0], 1, "outside the tree: opened at once")
	assert_true(chest.is_open)
	assert_almost(rad_to_deg((chest.get_node("Lid") as Node3D).rotation.x), ChestProp.LID_OPEN_DEG, 0.01)
	chest.free()
	var closed: ChestProp = PropKit.build(&"chest", 2) as ChestProp
	closed.set_style("locked")
	assert_false(closed.is_open)
	assert_eq(closed.chest_type, "locked")
	closed.set_open_instant()
	assert_true(closed.is_open)
	closed.free()
