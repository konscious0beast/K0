class_name RoomSpec extends RefCounted
## Input M3 → M4 for one room (02_TECH §8.5).

enum Kind { START, NORMAL, SAFE, QUARTER_BOSS, FLOOR_BOSS, STAIRS, GATE }   # same order as RoomCell.Kind

## Staffeln (09 §3.1, ST1-C; 03_ART CR-28): the boss-room look of a Kulisse floor — the room's own palette and
## dressing with a stage disc instead of the floor-1 sets (Hausmeister-Büro, Gleis 9).
const STAGE_PLAIN: StringName = &"plain"

var theme_id: String = "metro"
var kind: RoomSpec.Kind = Kind.NORMAL
var doors: int = 0              # RoomCell.DOOR_* bitmask
var variant: int = 0            # 0..3
var seed: int = 0
var palette: Dictionary = {}    # zone palette merged over FloorDef.palette (hex strings), FloorLayout.zone_palette()
var with_light: bool = true
var quality: StringName = &"high"
# --- Staffeln (ST1-C): both "" on floor 1 (its rooms are built as before) ---
var style: StringName = &""     # dressing of a quarter (platform | sewer | cellar | track9 | mall); "" = by palette
var stage: StringName = &""     # boss rooms: "" = the floor-1 sets by kind, STAGE_PLAIN = the Kulisse stage
