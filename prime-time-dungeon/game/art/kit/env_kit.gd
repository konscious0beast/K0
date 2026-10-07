# STUB(M0) — owned by M4. Replace completely, keep the public API.
class_name EnvKit extends RefCounted
## Rooms, arena, safe room, environment, light (02_TECH §8.5). Stub builders return empty nodes.

const ROOM_SIZE: float = 16.0
const WALL_HEIGHT: float = 3.5
const DOOR_WIDTH: float = 4.0
const WALL_THICKNESS: float = 0.5
const CLEAR_RADIUS: float = 5.0


static func build_room(spec: RoomSpec) -> Node3D:
	return Node3D.new()


## Room-local: &"player_spawn", &"stairs", &"boss_spot", &"safe_door" (see 02_TECH §8.5).
static func anchor_for(spec: RoomSpec, anchor: StringName) -> Transform3D:
	return Transform3D.IDENTITY


static func build_battle_arena(theme_id: String, palette: Dictionary, is_boss: bool, seed: int,
		quality: StringName = &"high") -> Node3D:
	return Node3D.new()


static func build_safe_room(seed: int, quality: StringName = &"high", theme: StringName = &"kiosk") -> Node3D:
	return Node3D.new()


## Local transforms inside build_safe_room(): &"vending", &"terminal", &"couch", &"mopsula_spot", &"player_spot", &"door", &"camera"
static func safe_room_anchor(anchor: StringName) -> Transform3D:
	return Transform3D.IDENTITY


## mode &"explore" | &"battle" | &"safe"
static func make_environment(theme_id: String, palette: Dictionary, mode: StringName,
		quality: StringName = &"high") -> Environment:
	return Environment.new()


static func make_sun(theme_id: String, mode: StringName, quality: StringName = &"high") -> DirectionalLight3D:
	return DirectionalLight3D.new()
