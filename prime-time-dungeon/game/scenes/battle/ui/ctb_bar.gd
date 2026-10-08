extends Control
## CTB turn-order bar on the right edge (02_TECH §1.6, GDD §3.4/§14.5, 03_ART §9.2): 12 entries (scheme TOUCH 10)
## of CTB_ORDER / preview_order, entry 1 = current/next actor (64 px), entries 2.. 42 px; portrait icons framed blue
## (party #4AA8FF), red (enemy #E8455A) or grey (pseudo unit, train icon); ghost preview entries at 50 % alpha.
## Entries are keyed per occurrence and slide to their new slots (0.2 s). Private M5 helper (no class_name).

const HudStyle := preload("res://scenes/battle/ui/hud_style.gd")
## 03_ART §9.2 asks for 64 / 42 px; 56 / 36 px keep all 12 entries above the party panels in the bottom-right corner
## (which sit right of the M.O.D. text box) at 720 px height.
const FIRST: float = 56.0
const ENTRY: float = 36.0
const GAP: float = 2.0
const WIDTH: float = 56.0
const HEADER: float = 18.0
const SLIDE_SEC: float = 0.2


## One icon of the bar.
class Entry extends Control:
	var unit_id: String = ""
	var kind: String = "enemy"          # "party" | "enemy" | "pseudo"
	var ghost: bool = false
	var first: bool = false
	var letter: String = ""
	var portrait: TextureRect = null
	var icon: Control = null
	var badge: Label = null

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		var col: Color = HudStyle.C_PARTY
		if kind == "enemy":
			col = HudStyle.C_ENEMY
		elif kind == "pseudo":
			col = HudStyle.C_PSEUDO
		draw_rect(r.grow(2.0), Color(0, 0, 0, 0.55), true)
		draw_rect(r, Color(col, 0.28), true)
		if first:
			draw_rect(r.grow(4.0), Color("#ff2e88"), false, 3.0)
			var cy: float = size.y * 0.5
			draw_colored_polygon(PackedVector2Array([Vector2(-16, cy - 9), Vector2(-5, cy), Vector2(-16, cy + 9)]),
				Color("#ff2e88"))
		draw_rect(r, col, false, 3.0 if first else 2.0)
		if ghost:
			draw_dashed_line(Vector2(0, size.y + 3), Vector2(size.x, size.y + 3), Color("#ffc93c"), 2.0, 4.0)


var count: int = 12
var order: PackedStringArray = []
var ghosts: PackedStringArray = []
## Provider (BattleHud): ctb_portrait(id) -> Texture2D, ctb_kind(id) -> String, ctb_letter(id) -> String.
var provider: Object = null

var _entries: Dictionary = {}       # key "id#k" → Entry
var _header: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, HEADER + FIRST + (ENTRY + GAP) * 11.0)
	_header = HudStyle.label("ZUGFOLGE", 12, Color("#b3a7c9"), true, 3)
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header.position = Vector2(-22, -5)
	_header.size = Vector2(WIDTH + 44, 16)
	add_child(_header)


## Shows `p_order` (first `count` entries); ids in `ghost_ids` are drawn as ghosts (hypothetical position).
func set_order(p_order: PackedStringArray, ghost_ids: PackedStringArray = PackedStringArray(),
		animate: bool = true) -> void:
	order = p_order.slice(0, mini(count, p_order.size()))
	ghosts = ghost_ids.duplicate()
	var seen: Dictionary = {}
	var keep: Dictionary = {}
	for i in order.size():
		var id: String = order[i]
		var k: int = int(seen.get(id, 0))
		seen[id] = k + 1
		var key: String = "%s#%d" % [id, k]
		keep[key] = true
		var e: Entry = _entries.get(key, null)
		var target: Rect2 = slot_rect(i)
		var fresh: bool = e == null
		if fresh:
			e = _make_entry(id)
			_entries[key] = e
			add_child(e)
			e.position = target.position + Vector2(0, 18)
			e.size = target.size
			e.modulate.a = 0.0
		e.first = i == 0
		e.ghost = ghosts.has(id)
		e.z_index = 1 if i == 0 else 0
		var alpha: float = 0.5 if e.ghost else 1.0
		if animate and is_inside_tree():
			var tw: Tween = e.create_tween().set_parallel(true)
			tw.tween_property(e, "position", target.position, SLIDE_SEC).set_trans(Tween.TRANS_CUBIC) \
				.set_ease(Tween.EASE_OUT)
			tw.tween_property(e, "size", target.size, SLIDE_SEC)
			tw.tween_property(e, "modulate:a", alpha, SLIDE_SEC)
		else:
			e.position = target.position
			e.size = target.size
			e.modulate.a = alpha
		_layout_entry(e)
		e.queue_redraw()
	for key2: Variant in _entries.keys():
		if keep.has(key2):
			continue
		var old: Entry = _entries[key2]
		_entries.erase(key2)
		if animate and is_inside_tree() and is_instance_valid(old):
			var tw2: Tween = old.create_tween()
			tw2.tween_property(old, "modulate:a", 0.0, SLIDE_SEC * 0.8)
			tw2.tween_callback(old.queue_free)
		elif is_instance_valid(old):
			old.queue_free()


## Rect of entry slot i (0 = current actor).
func slot_rect(i: int) -> Rect2:
	if i == 0:
		return Rect2(Vector2(0, HEADER), Vector2(FIRST, FIRST))
	var y: float = HEADER + FIRST + GAP + 4.0 + float(i - 1) * (ENTRY + GAP)
	return Rect2(Vector2((WIDTH - ENTRY) * 0.5, y), Vector2(ENTRY, ENTRY))


## Number of entries currently shown (≤ count).
func entry_count() -> int:
	return order.size()


func shown_ids() -> PackedStringArray:
	return order.duplicate()


func is_ghost(id: String) -> bool:
	return ghosts.has(id)


func _make_entry(id: String) -> Entry:
	var e: Entry = Entry.new()
	e.unit_id = id
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	e.kind = str(provider.call("ctb_kind", id)) if provider != null else ("party" if id.begins_with("p") else "enemy")
	e.letter = str(provider.call("ctb_letter", id)) if provider != null else ""
	e.clip_contents = false
	if e.kind == "pseudo":
		var ic: HudStyle.Icon = HudStyle.Icon.new("train", Color("#c9c4d2"), 30)
		e.icon = ic
		e.add_child(ic)
	else:
		var tr2: TextureRect = TextureRect.new()
		tr2.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr2.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if provider != null:
			tr2.texture = provider.call("ctb_portrait", id) as Texture2D
		e.portrait = tr2
		e.add_child(tr2)
	if e.letter != "":
		var b: Label = HudStyle.label(e.letter, 13, HudStyle.C_PAPER, true, 3)
		e.badge = b
		e.add_child(b)
	return e


func _layout_entry(e: Entry) -> void:
	var s: Vector2 = slot_rect(0).size if e.first else Vector2(ENTRY, ENTRY)
	if e.portrait != null:
		e.portrait.position = Vector2(2, 2)
		e.portrait.size = s - Vector2(4, 4)
	if e.icon != null:
		e.icon.position = Vector2(4, 4)
		e.icon.size = s - Vector2(8, 8)
	if e.badge != null:
		e.badge.position = Vector2(s.x - 13, s.y - 19)
		e.badge.size = Vector2(12, 18)
