extends RefCounted
## FloorBuilder (02_TECH §7.3, M3-private): FloorLayout → room nodes via EnvKit/PropKit. One RoomSpec per cell
## (palette = layout.zone_palette(cell, def.palette)), EnvKit.build_room(spec) placed under World/Rooms at
## layout.cell_to_world(c) as "Room_<x>_<y>". Closed gates get PropKit gate + blocking body + gate_interactable (built
## by the scene). Anchors come from EnvKit.anchor_for (spec semantics as fallback while the art kit is a stub).
## Every M4 builder that returns an empty node is completed by fallback_art.gd (stub phase only).

const FB := preload("res://scenes/exploration/fallback_art.gd")

const LINTEL_Y: float = 3.0              # door lintel underside (03_ART §6.1 "Sturz auf 3.0 m")
const LINTEL_TOP: float = 3.5            # wall height
## Room checkerboard render layers (02_TECH §7.3, §12.1 "Lichter pro Mesh"): door-linked cells always differ in the
## parity of x + y, so a room light that culls the other parity never reaches the neighbour's floor/wall/prop meshes
## (measured before: own light + up to 3 neighbour lights on a room mesh). Actors, interactables and VFX stay on layer 1
## and are lit by every light in range as before; the sun and the camera see every layer.
const ROOM_LAYER_EVEN: int = 1 << 10     # render layer 11
const ROOM_LAYER_ODD: int = 1 << 11      # render layer 12

var layout: FloorLayout
var def: FloorDef
var quality: StringName = &"high"
var specs: Dictionary = {}           # Vector2i → RoomSpec
var rooms: Dictionary = {}           # Vector2i → Node3D
var fallback_rooms: int = 0          # number of rooms completed by the fallback art
## "FloorCollision": the boxes of every room "Collision" body and of the door lintels in ONE StaticBody3D (layer 1;
## 02_TECH §12.1 Physik: one static body per floor instead of one per room). Created by build_rooms().
var collision: StaticBody3D = null


func _init(p_layout: FloorLayout, p_def: FloorDef, p_quality: StringName = &"high") -> void:
	layout = p_layout
	def = p_def
	quality = p_quality


func theme_id() -> String:
	return def.theme if def != null else "metro"


func floor_palette() -> Dictionary:
	return def.palette if def != null else {}


func palette_at(c: Vector2i) -> Dictionary:
	return layout.zone_palette(c, floor_palette())


func spec_for(c: Vector2i) -> RoomSpec:
	if specs.has(c):
		return specs[c]
	var rc: RoomCell = layout.cell_at(c)
	var spec: RoomSpec = RoomSpec.new()
	spec.theme_id = theme_id()
	if rc != null:
		spec.kind = int(rc.kind) as RoomSpec.Kind
		spec.doors = rc.doors
		spec.variant = rc.variant
	spec.seed = SeedUtil.derive(layout.seed, "room", c.y * 64 + c.x)
	spec.palette = palette_at(c)
	spec.with_light = true
	spec.quality = quality
	specs[c] = spec
	return spec


## Builds every room under `parent` (World/Rooms; only rooms there): room checkerboard layers, room collision moved
## into the one "FloorCollision" body under `collision_parent` (null → `parent`).
func build_rooms(parent: Node3D, collision_parent: Node3D = null) -> void:
	collision = StaticBody3D.new()
	collision.name = "FloorCollision"
	collision.collision_layer = 1
	collision.collision_mask = 0
	for c: Vector2i in layout.sorted_cells():
		var spec: RoomSpec = spec_for(c)
		var room: Node3D = EnvKit.build_room(spec)
		if room == null:
			room = Node3D.new()
		if FB.is_empty(room):
			FB.build_room(spec, room)
			fallback_rooms += 1
		room.name = "Room_%d_%d" % [c.x, c.y]
		room.position = layout.cell_to_world(c)
		isolate_room_lights(room, c)
		_take_collision(room)
		parent.add_child(room)
		rooms[c] = room
	(collision_parent if collision_parent != null else parent).add_child(collision)


static func room_layer(c: Vector2i) -> int:
	return ROOM_LAYER_EVEN if posmod(c.x + c.y, 2) == 0 else ROOM_LAYER_ODD


## Room meshes go to the cell's checkerboard layer; the room's own lights ignore the other parity.
static func isolate_room_lights(room: Node3D, c: Vector2i) -> void:
	var own: int = room_layer(c)
	var other: int = ROOM_LAYER_ODD if own == ROOM_LAYER_EVEN else ROOM_LAYER_EVEN
	var stack: Array[Node] = [room]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for ch: Node in n.get_children():
			stack.append(ch)
		if n is Light3D and not n is DirectionalLight3D:
			(n as Light3D).light_cull_mask &= ~other
		elif n is GeometryInstance3D:
			(n as GeometryInstance3D).layers = own


## Moves the shapes of the room's "Collision" body (room-local) into `collision` (floor space) and frees the body.
func _take_collision(room: Node3D) -> void:
	var body: StaticBody3D = room.get_node_or_null("Collision") as StaticBody3D
	if body == null or collision == null:
		return
	var to_floor: Transform3D = room.transform * body.transform
	for ch: Node in body.get_children():
		var cs: CollisionShape3D = ch as CollisionShape3D
		if cs == null:
			continue
		body.remove_child(cs)
		cs.transform = to_floor * cs.transform
		collision.add_child(cs)
	room.remove_child(body)
	body.free()


## Collision boxes for the door lintels (layer 1, y 3.0–3.5 m over every door, through both walls): the art kit's
## walls only collide beside the openings, but the camera treats the wall above a door as wall (camera_rig.gd).
## Kai (1.7 m) and the groups never reach that height → no gameplay change. One box per door, added to the
## "FloorCollision" body when build_rooms() ran (else to an own "DoorLintels" body under `parent`).
func build_door_lintels(parent: Node3D) -> StaticBody3D:
	var body: StaticBody3D = collision
	if body == null:
		body = StaticBody3D.new()
		body.name = "DoorLintels"
		body.collision_layer = 1
		body.collision_mask = 0
		parent.add_child(body)
	for c: Vector2i in layout.sorted_cells():
		var rc: RoomCell = layout.cell_at(c)
		for b: int in RoomCell.DIR_BITS:
			var off: Vector2i = RoomCell.dir_offset(b)
			if not rc.has_door(b) or off.x < 0 or off.y < 0:
				continue                      # each door once (from its west / north cell)
			var t: Transform3D = door_transform(c, b)
			var cs: CollisionShape3D = CollisionShape3D.new()
			var box: BoxShape3D = BoxShape3D.new()
			box.size = Vector3(EnvKit.DOOR_WIDTH + 1.0, LINTEL_TOP - LINTEL_Y, EnvKit.WALL_THICKNESS * 2.0)
			cs.shape = box
			cs.transform = Transform3D(t.basis, t.origin + Vector3(0.0, (LINTEL_Y + LINTEL_TOP) * 0.5, 0.0))
			body.add_child(cs)
	return body


## Room-local anchor; the art kit decides (EnvKit.anchor_for). While EnvKit is a stub it returns IDENTITY for every
## anchor, so the safe-door anchor then follows the 02_TECH §8.5 rule via fallback_art.
func local_anchor(c: Vector2i, anchor_name: StringName) -> Transform3D:
	var spec: RoomSpec = spec_for(c)
	var t: Transform3D = EnvKit.anchor_for(spec, anchor_name)
	if anchor_name == &"safe_door" and t == Transform3D.IDENTITY:
		t = FB.anchor_for(spec, anchor_name)
	return t


## World transform of an anchor of cell `c`.
func anchor(c: Vector2i, anchor_name: StringName) -> Transform3D:
	var t: Transform3D = local_anchor(c, anchor_name)
	return Transform3D(t.basis, t.origin + layout.cell_to_world(c))


## World transform of a door opening (gates): centred on the shared edge, local X along the door width.
func door_transform(c: Vector2i, dir: int) -> Transform3D:
	var off: Vector2i = RoomCell.dir_offset(dir)
	var pos: Vector3 = layout.cell_to_world(c) + Vector3(off.x, 0.0, off.y) * (FloorLayout.ROOM_SIZE * 0.5)
	var yaw: float = 0.0 if off.y != 0 else PI * 0.5
	return Transform3D(Basis(Vector3.UP, yaw), pos)


func make_environment() -> Environment:
	var pal: Dictionary = palette_at(layout.start)
	var env: Environment = EnvKit.make_environment(theme_id(), pal, &"explore", quality)
	if env == null or env.background_mode != Environment.BG_COLOR:
		env = FB.environment(pal, quality)
	return env


func make_sun() -> DirectionalLight3D:
	var sun: DirectionalLight3D = EnvKit.make_sun(theme_id(), &"explore", quality)
	if sun == null or sun.transform == Transform3D.IDENTITY:
		if sun != null:
			sun.free()
		sun = FB.sun(palette_at(layout.start), quality)
	return sun


## Yaw that makes a boss / prop at the centre of `c` face the entrance (the neighbour with the smallest depth).
func entrance_yaw(c: Vector2i) -> float:
	var rc: RoomCell = layout.cell_at(c)
	if rc == null:
		return 0.0
	var best: Vector2i = Vector2i(-999, -999)
	var best_depth: int = 1 << 30
	for n: Vector2i in layout.linked(c):
		var d: int = layout.cell_at(n).depth
		if d < best_depth:
			best_depth = d
			best = n
	if best == Vector2i(-999, -999):
		return 0.0
	var dir: Vector2i = best - c
	return atan2(-float(dir.x), -float(dir.y))
