extends Node3D
## Environment gallery (02_TECH §1.5, CI screenshot target §12.4): rooms for all 16 door masks (zones A–D, all 4 wall
## variants), the kind set pieces (start, stairs, safe door, both boss rooms), the battle arena and the three safe-room
## themes. `page` (set in the .tscn variants): "overview" (default) | "room" (one room at gameplay camera) | "arena" |
## "safe" | "kinds" | "props".

const Stage := preload("res://art/gallery/gallery_stage.gd")
const Cast := preload("res://art/gallery/cast.gd")
const SetBuilder := preload("res://art/kit/set_builder.gd")

@export var page: String = "overview"
@export var room_mask: int = 5
@export var room_zone: String = "platform"
@export var room_variant: int = 1
@export var room_kind: int = 1
@export var safe_theme: String = "kiosk"

var built: Array[Node3D] = []
var _params: Dictionary = {}


func setup(params: Dictionary) -> void:
	_params = params


func _ready() -> void:
	match page:
		"room":
			_page_room()
		"arena":
			_page_arena()
		"safe":
			_page_safe()
		"kinds":
			_page_kinds()
		"props":
			_page_props()
		_:
			_page_overview()


func _zone_palette(zone: String) -> Dictionary:
	var src: Dictionary = Palette.ZONE_PRESETS.get(zone, Palette.ZONE_PRESETS["platform"])
	var out: Dictionary = {}
	for k: String in Palette.PALETTE_KEYS:
		out[k] = src[k]
	return out


func _room(mask: int, zone: String, variant: int, kind: RoomSpec.Kind, pos: Vector3, seed: int,
		theme: String = "metro") -> Node3D:
	var spec := RoomSpec.new()
	spec.theme_id = theme
	spec.kind = kind
	spec.doors = mask
	spec.variant = variant
	spec.seed = seed
	spec.palette = _zone_palette(zone)
	var room: Node3D = EnvKit.build_room(spec)
	room.name = "Room_%d_%s" % [mask, zone]
	room.position = pos
	add_child(room)
	built.append(room)
	return room


func _page_overview() -> void:
	Stage.add_world(self, "metro", {}, &"explore", &"high", 0.08)
	var zones: Array[String] = ["platform", "sewer", "cellar", "track9"]
	for mask in 16:
		var col: int = mask % 4
		var row: int = mask / 4
		var pos := Vector3(-27.0 + 18.0 * float(col), 0, -27.0 + 18.0 * float(row))
		_room(mask, zones[row], (mask + row) % 4, RoomSpec.Kind.NORMAL, pos, 100 + mask)
		var lbl: Label3D = Stage.label(self, "Tür %d" % mask, pos + Vector3(0, 4.5, 0), 96, Palette.HYPE_GOLD)
		lbl.pixel_size = 0.02
	var arena: Node3D = EnvKit.build_battle_arena("metro", {}, false, 7)
	arena.position = Vector3(56, 0, -18)
	arena.scale = Vector3(0.75, 0.75, 0.75)
	add_child(arena)
	Stage.label(self, "Arena", Vector3(56, 2, -31), 110, Palette.HYPE_GOLD).pixel_size = 0.03
	var themes: Array[StringName] = [&"kiosk", &"pumphouse", &"signalbox"]
	for i in 3:
		var sr: Node3D = SetBuilder.build_safe(i, &"high", themes[i], true)   # cutaway: interior visible from above
		sr.position = Vector3(44 + 13.0 * float(i), 0, 14)
		add_child(sr)
	Stage.label(self, "Safe Rooms", Vector3(57, 0.5, 22.5), 110, Palette.HYPE_GOLD).pixel_size = 0.03
	Stage.add_camera(self, Vector3(14, 92, 64), Vector3(14, 0, -4), 46.0)


func _page_room() -> void:
	var pal: Dictionary = _zone_palette(room_zone)
	Stage.add_world(self, "metro", pal, &"explore")
	_room(room_mask, room_zone, room_variant, room_kind as RoomSpec.Kind, Vector3.ZERO, 3)
	# neighbours so door openings read as passages
	for side: int in [1, 2, 4, 8]:
		if (room_mask & side) == 0:
			continue
		var off: Vector3 = {1: Vector3(0, 0, -16), 2: Vector3(16, 0, 0), 4: Vector3(0, 0, 16), 8: Vector3(-16, 0, 0)}[side]
		var back: int = {1: 4, 2: 8, 4: 1, 8: 2}[side]
		_room(back | (5 if side == 2 or side == 8 else 10), room_zone, 0, RoomSpec.Kind.NORMAL, off, 9 + side)
	var kai: CharacterRig = CharacterBuilder.build(Cast.model("kai"))
	add_child(kai)
	kai.position = Vector3(0.5, 0, 2.0)
	kai.rotation.y = deg_to_rad(200.0)
	var mop: CharacterRig = CharacterBuilder.build(Cast.model("mopsula"))
	add_child(mop)
	mop.position = Vector3(1.6, 0, 3.4)
	mop.rotation.y = deg_to_rad(210.0)
	var rat: CharacterRig = CharacterBuilder.build(Cast.model("enm_kanalratte"))
	add_child(rat)
	rat.position = Vector3(-2.0, 0, -2.5)
	rat.rotation.y = deg_to_rad(20.0)
	var chest: Node3D = PropKit.build(&"chest")
	add_child(chest)
	chest.position = Vector3(3.5, 0, -3.5)
	chest.rotation.y = deg_to_rad(-30.0)
	# gameplay camera: 7 m arm, pitch −38°, FOV 60 (02_TECH §7.3)
	var pivot := Vector3(0.5, 1.4, 2.0)
	var dir := Vector3(0, sin(deg_to_rad(38.0)), cos(deg_to_rad(38.0))).rotated(Vector3.UP, deg_to_rad(20.0))
	Stage.add_camera(self, pivot + dir * 7.0, pivot, 60.0)


func _page_arena() -> void:
	Stage.add_world(self, "metro", {}, &"battle")
	var arena: Node3D = EnvKit.build_battle_arena("metro", {}, room_kind == 1, 11)
	add_child(arena)
	var party: Array = [["kai", Vector3(-1.3, 0, 3.0)], ["mopsula", Vector3(1.3, 0, 3.2)]]
	var foes: Array = [["enm_kanalratte", Vector3(-2.4, 0, -2.6)], ["enm_taubenschwarm", Vector3(0, 0, -3.4)],
		["enm_kanalratte", Vector3(2.4, 0, -2.6)]]
	if room_kind == 1:
		foes = [["enm_boss_hausmeister", Vector3(0, 0, -4.5)]]
	for entry: Array in party:
		var rig: CharacterRig = CharacterBuilder.build(Cast.model(str(entry[0])))
		add_child(rig)
		rig.position = entry[1]
		rig.battle_stance = true
	for entry: Array in foes:
		var rig2: CharacterRig = CharacterBuilder.build(Cast.model(str(entry[0])), 3)
		add_child(rig2)
		rig2.position = entry[1]
		rig2.rotation.y = PI
	# establishing shot end position (03_ART §8.3)
	Stage.add_camera(self, Vector3(4.5, 3.4, 8.0), Vector3(0, 0.9, -0.5), 50.0)


func _page_safe() -> void:
	Stage.add_world(self, "metro", {}, &"safe")
	var theme := StringName(safe_theme)
	var room: Node3D = EnvKit.build_safe_room(5, &"high", theme)
	add_child(room)
	var kai: CharacterRig = CharacterBuilder.build(Cast.model("kai"))
	add_child(kai)
	kai.transform = EnvKit.safe_room_anchor(&"player_spot")
	var mop: CharacterRig = CharacterBuilder.build(Cast.model("mopsula"))
	add_child(mop)
	mop.transform = EnvKit.safe_room_anchor(&"mopsula_spot")
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.fov = 50.0
	add_child(cam)
	cam.transform = EnvKit.safe_room_anchor(&"camera")
	cam.current = true


func _page_kinds() -> void:
	Stage.add_world(self, "metro", {}, &"explore", &"high", 0.15)
	var kinds: Array = [[RoomSpec.Kind.START, 1, "platform"], [RoomSpec.Kind.STAIRS, 2, "track9"],
		[RoomSpec.Kind.SAFE, 1, "platform"], [RoomSpec.Kind.QUARTER_BOSS, 8, "cellar"], [RoomSpec.Kind.FLOOR_BOSS, 2,
			"track9"],
		[RoomSpec.Kind.NORMAL, 10, "sewer"]]
	for i in kinds.size():
		var k: Array = kinds[i]
		var pos := Vector3(-18.0 + 18.0 * float(i % 3), 0, -9.0 + 18.0 * float(i / 3))
		_room(int(k[1]), str(k[2]), i % 4, k[0] as RoomSpec.Kind, pos, 40 + i)
	Stage.add_camera(self, Vector3(0, 46, 40), Vector3(0, 0, 0), 50.0)


## Props by height (review M4: tall props in the back so no label or small prop hides behind a billboard or gate).
const PROP_ROWS: Array = [
	["safe_door", "billboard", "gate", "vending_machine", "broken_vending", "phone_booth"],
	["fortune_wheel", "pillar", "lamp", "turnstile", "couch", "save_terminal"],
	["poster", "camera_drone", "rail", "pipe", "bench", "trash_bin"],
	["chest", "crate", "barrel", "lever"],
]


func _page_props() -> void:
	Stage.add_world(self, "metro", {}, &"battle")
	Stage.add_floor(self, 14.0, {})
	for row in PROP_ROWS.size():
		var ids: Array = PROP_ROWS[row]
		for col in ids.size():
			var id: String = str(ids[col])
			var n: Node3D = PropKit.build(StringName(id), 3)
			var x: float = (float(col) - float(ids.size() - 1) * 0.5) * 3.3
			n.position = Vector3(x, 0.0 if id != "camera_drone" else 1.5, -6.6 + 3.7 * float(row))
			n.rotation.y = PI
			add_child(n)
			Stage.label(self, id, Vector3(n.position.x, 0.0, n.position.z + 1.2), 52)
	Stage.add_camera(self, Vector3(0, 9.5, 13.5), Vector3(0, 0.5, -1.2), 50.0)
