# STUB(M0) — owned by M4. Replace completely, keep the public API.
class_name RoomSpec extends RefCounted
## Input M3 → M4 for one room (02_TECH §8.5).

enum Kind { START, NORMAL, SAFE, QUARTER_BOSS, FLOOR_BOSS, STAIRS, GATE }   # same order as RoomCell.Kind

var theme_id: String = "metro"
var kind: RoomSpec.Kind = Kind.NORMAL
var doors: int = 0              # RoomCell.DOOR_* bitmask
var variant: int = 0            # 0..3
var seed: int = 0
var palette: Dictionary = {}    # zone palette merged over FloorDef.palette (hex strings), FloorLayout.zone_palette()
var with_light: bool = true
var quality: StringName = &"high"
