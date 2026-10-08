extends TestCase
## Visual pass (art kit findings of the screenshot matrix): a door carries only a short accent lamp flush on its lintel
## face (no emissive strip across the opening); the arena's show screen stays low (below the command shots' top HUD
## band), litter keeps clear of it and audience stands close the party side (+Z); the safe-room name sign is a named
## node screens can hide; group pips are depth-tested; the cast sheet's screen-space name tags never overlap and stay in
## the frame.

const RoomBuilder := preload("res://art/kit/room_builder.gd")
const SetBuilder := preload("res://art/kit/set_builder.gd")
const FB := preload("res://scenes/exploration/fallback_art.gd")
const GALLERY: String = "res://art/gallery/character_gallery.tscn"

var _saved_size: Vector2i = Vector2i.ZERO


## Headless the root is 64 × 64 (visible rect 1280 × 1280): frame checks run in the 16:9 reference frame.
func before_each() -> void:
	_saved_size = tree.root.size
	tree.root.size = Vector2i(1280, 720)


func after_each() -> void:
	tree.root.size = _saved_size


func test_door_accent_is_a_short_lamp_on_the_lintel_face() -> void:
	for side: int in RoomBuilder.SIDES:
		var spec: RoomSpec = RoomSpec.new()
		spec.doors = side
		spec.palette = {}
		var rb: RefCounted = RoomBuilder.new(spec)
		rb.call("_build_wall", side)
		var lamps: int = 0
		for p: Dictionary in (rb.get("geo") as Array):
			if float(p.get("emission", 0.0)) <= 0.0:
				continue
			var xf: Transform3D = p["xform"]
			if xf.origin.y < 2.5:
				continue
			lamps += 1
			assert_true(xf.basis.x.length() <= 1.5, "side %d: accent over the door is a short lamp (%.2f m), no strip "
				% [side, xf.basis.x.length()] + "across the opening")
			var local: Vector3 = RoomBuilder.toward_wall_basis(side).inverse() * xf.origin
			assert_true(-local.z < RoomBuilder.IN, "side %d: lamp on the room's own (inner) side of the lintel" % side)
		assert_eq(lamps, 1, "side %d: one door lamp" % side)


func test_arena_show_screen_stays_low_and_stands_close_the_party_side() -> void:
	var arena: Node3D = EnvKit.build_battle_arena("metro", {}, false, 3)
	add_to_tree(arena)
	var screen: MeshInstance3D = arena.get_node("ShowScreen") as MeshInstance3D
	var top: float = screen.position.y + (screen.mesh as QuadMesh).size.y * 0.5
	assert_true(top <= 2.65, "show screen top %.2f m: below the command shots' top HUD band" % top)
	for l: Node in arena.find_children("*", "Label3D", true, false):
		var lb: Label3D = l as Label3D
		if lb.position.z < -13.0:
			assert_true(lb.position.y <= 2.6, "screen text '%s' on the low screen" % lb.text)
	var geo: MeshInstance3D = arena.get_node("Geometry") as MeshInstance3D
	var box: AABB = geo.get_aabb()
	assert_true(box.end.z >= SetBuilder.STANDS_R + 2.0, "audience stands behind the party (+Z) (%s)" % str(box))
	assert_true(SetBuilder.STANDS_ARC_DEG.x < 180.0 and SetBuilder.STANDS_ARC_DEG.y > 180.0, "arc centred on +Z")


func test_safe_room_name_sign_is_a_named_node() -> void:
	var room: Node3D = EnvKit.build_safe_room(1)
	add_to_tree(room)
	var sign: Label3D = room.find_child(EnvKit.SAFE_TITLE_SIGN, true, false) as Label3D
	assert_not_null(sign, "EnvKit.SAFE_TITLE_SIGN")
	if sign != null:
		assert_eq(sign.text, "KIOSK 24/7")


func test_group_pips_are_depth_tested() -> void:
	assert_false(FB.PIPS_SHADER.contains("depth_test_disabled"), "pips hide behind walls")


func test_cast_name_tags_never_overlap_and_stay_in_frame() -> void:
	var g: Node3D = (load(GALLERY) as PackedScene).instantiate() as Node3D
	add_to_tree(g)
	await wait_frames(4)
	var tags: CanvasLayer = g.get("tags") as CanvasLayer
	assert_not_null(tags)
	tags.call("layout")
	var rects: Array[Rect2] = []
	var view: Rect2 = tree.root.get_visible_rect()
	for l: Node in tags.find_children("*", "Label", true, false):
		var lb: Label = l as Label
		if not lb.visible:
			continue
		var r: Rect2 = Rect2(lb.position, lb.size)
		assert_true(view.encloses(r), "tag '%s' inside the frame (%s)" % [lb.text, str(r)])
		for q: Rect2 in rects:
			assert_false(q.intersects(r), "tag '%s' overlaps another tag (%s / %s)" % [lb.text, str(r), str(q)])
		rects.append(r)
	assert_true(rects.size() >= 15, "every cast member tagged (%d)" % rects.size())
