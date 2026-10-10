extends Control
## Enemy info plates (GDD §14.5 "Gegner-Info"): name (+ letter of duplicate types), HP bar, HP number only when the
## bestiary lists the type as defeated (GameState.bestiary[def].defeated ≥ 1), status icons and weaknesses after
## discovery (weak_known + weaknesses hit in this battle).
## Full plates (backed: C_PANEL @ 70 %, 2 px enemy-red top edge) show only while the player picks a command (`shown`),
## 6 px above the enemy's head — 40 px for the targeted enemies, room for the target arrow. During playback a hit
## shows only a slim HP bar under the enemy's feet for a moment, so the plate never covers the damage number rising
## from the head (Vfx.damage_number). Plates never overlap each other or the top HUD band (y < TOP_BAND).
## Private M5 helper (no class_name).

const HudStyle := preload("res://scenes/battle/ui/hud_style.gd")
const PLATE_W: float = 136.0
const LINGER_SEC: float = 1.4
const GAP: float = 6.0
const TARGET_GAP: float = 40.0
const TOP_BAND: float = 90.0             # LIVE badge / hype meter / AUTO + speed buttons
const RIGHT_CLEAR: float = 92.0          # CTB bar on the right edge (56 px + safe edge)
const SLIM_W: float = 76.0
const SLIM_H: float = 6.0


## One plate.
class Plate extends PanelContainer:
	var unit_id: String = ""
	var hp: int = 0
	var max_hp: int = 1
	var show_hp: bool = false
	var statuses: PackedStringArray = []
	var weak: PackedStringArray = []
	var gone: bool = false
	var linger: float = 0.0
	var name_label: Label = null
	var bar: HudStyle.Bar = null
	var hp_label: Label = null
	var icons: HBoxContainer = null
	var slim: PanelContainer = null      # slim HP bar under the feet (playback)
	var slim_bar: HudStyle.Bar = null


var stage: Node3D = null
var camera: Camera3D = null
var shown: bool = false            # full plates (command input)
## Enemies under the target cursor (their plates leave room for the arrow).
var targeted: PackedStringArray = []

var _plates: Dictionary = {}       # id → Plate


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func add_plate(id: String, display_name: String, hp: int, max_hp: int, show_hp: bool,
		weak: PackedStringArray) -> void:
	if _plates.has(id):
		var old: Plate = _plates[id]
		if old.slim != null:
			old.slim.queue_free()
		old.queue_free()
	var p: Plate = Plate.new()
	p.unit_id = id
	p.name = "Plate_" + id
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box: StyleBoxFlat = HudStyle.show_box(Color(HudStyle.C_INK, 0.7), HudStyle.C_ENEMY, 0, 0.0,
		Vector4(6, 3, 6, 4))
	box.border_width_top = 2
	box.shadow_size = 0
	p.add_theme_stylebox_override("panel", box)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	p.custom_minimum_size = Vector2(PLATE_W, 0)
	p.max_hp = maxi(1, max_hp)
	p.show_hp = show_hp
	p.weak = weak.duplicate()
	p.name_label = HudStyle.label(display_name, 16, HudStyle.C_PAPER, true, 4)
	p.name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(p.name_label)
	p.bar = HudStyle.Bar.new(HudStyle.C_ENEMY, 6.0)
	p.bar.custom_minimum_size = Vector2(PLATE_W - 24.0, 6.0)
	p.bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(p.bar)
	p.hp_label = HudStyle.mono_label("", 15, Color("#ffd0d6"))
	p.hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(p.hp_label)
	p.icons = HBoxContainer.new()
	p.icons.alignment = BoxContainer.ALIGNMENT_CENTER
	p.icons.add_theme_constant_override("separation", 3)
	p.icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(p.icons)
	add_child(p)
	p.slim = PanelContainer.new()
	p.slim.name = "Slim_" + id
	p.slim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = HudStyle.show_box(Color(HudStyle.C_INK, 0.75), Color(0, 0, 0, 0), 0, 0.0,
		Vector4(2, 2, 2, 2))
	sb.shadow_size = 0
	p.slim.add_theme_stylebox_override("panel", sb)
	p.slim_bar = HudStyle.Bar.new(HudStyle.C_ENEMY, SLIM_H)
	p.slim_bar.custom_minimum_size = Vector2(SLIM_W, SLIM_H)
	p.slim.add_child(p.slim_bar)
	p.slim.visible = false
	add_child(p.slim)
	_plates[id] = p
	set_hp(id, hp, false)
	_rebuild_icons(p)
	p.visible = false


func has_plate(id: String) -> bool:
	return _plates.has(id)


func plate_hp(id: String) -> int:
	var p: Plate = _plates.get(id, null)
	return p.hp if p != null else -1


func plate_max_hp(id: String) -> int:
	var p: Plate = _plates.get(id, null)
	return p.max_hp if p != null else -1


func plate_name(id: String) -> String:
	var p: Plate = _plates.get(id, null)
	return p.name_label.text if p != null else ""


## True while the full plate (name, icons) of `id` is drawn.
func is_full(id: String) -> bool:
	var p: Plate = _plates.get(id, null)
	return p != null and p.visible


func set_display_name(id: String, display_name: String) -> void:
	var p: Plate = _plates.get(id, null)
	if p != null:
		p.name_label.text = display_name


## Max HP from event data (DAMAGE / HEAL / REVIVE carry max_hp).
func set_max_hp(id: String, max_hp: int) -> void:
	var p: Plate = _plates.get(id, null)
	if p == null or max_hp <= 0 or max_hp == p.max_hp:
		return
	p.max_hp = max_hp
	set_hp(id, p.hp, false)


func set_hp(id: String, hp: int, animate: bool = true) -> void:
	var p: Plate = _plates.get(id, null)
	if p == null:
		return
	p.hp = clampi(hp, 0, p.max_hp)
	var r: float = float(p.hp) / float(p.max_hp)
	p.bar.set_ratio(r, animate)
	p.slim_bar.set_ratio(r, animate)
	p.hp_label.text = "%d/%d" % [p.hp, p.max_hp] if p.show_hp else ""
	p.hp_label.visible = p.show_hp
	if animate:
		p.linger = LINGER_SEC


func set_status(id: String, status_id: String, on: bool) -> void:
	var p: Plate = _plates.get(id, null)
	if p == null or on == p.statuses.has(status_id):
		return
	if on:
		p.statuses.append(status_id)
	else:
		p.statuses.remove_at(p.statuses.find(status_id))
	_rebuild_icons(p)


func add_weakness(id: String, element: String) -> void:
	var p: Plate = _plates.get(id, null)
	if p == null or element == "" or p.weak.has(element):
		return
	p.weak.append(element)
	_rebuild_icons(p)


## KO / escape: the plate disappears for good.
func remove_plate(id: String) -> void:
	var p: Plate = _plates.get(id, null)
	if p == null:
		return
	p.gone = true
	p.statuses.clear()
	p.visible = false
	p.slim.visible = false


func _rebuild_icons(p: Plate) -> void:
	for c: Node in p.icons.get_children():
		c.queue_free()
	for sid: String in p.statuses:
		p.icons.add_child(HudStyle.Icon.new(HudStyle.status_icon(sid), HudStyle.status_color(sid), 15))
	for el: String in p.weak:
		var ic: HudStyle.Icon = HudStyle.Icon.new("element_" + el, HudStyle.element_color(el), 15)
		p.icons.add_child(ic)
	p.icons.visible = not p.statuses.is_empty() or not p.weak.is_empty()


## Final rect of a full plate (`placed` = the plates already placed, nearest first): pushed up above every plate it
## would overlap; if that would reach into the top HUD band it stays at TOP_BAND and slides sideways next to the
## plates it touches (nearest free x), else below them — it is never clamped back down onto a placed plate.
static func place_rect(want: Rect2, placed: Array[Rect2], max_right: float) -> Rect2:
	var r: Rect2 = want
	r.position.x = clampf(r.position.x, 4.0, max_right - r.size.x)
	var guard: int = 0
	var moved: bool = true
	while moved and guard < 8:
		moved = false
		guard += 1
		for o: Rect2 in placed:
			if r.grow(1.0).intersects(o):
				r.position.y = o.position.y - r.size.y - 3.0
				moved = true
	if r.position.y >= TOP_BAND and not _hits(r, placed):
		return r
	r.position.y = maxf(r.position.y, TOP_BAND)
	if not _hits(r, placed):
		return r
	var best: Rect2 = r
	var best_d: float = INF
	for o: Rect2 in placed:
		for x: float in [o.end.x + 3.0, o.position.x - r.size.x - 3.0]:
			if x < 4.0 or x > max_right - r.size.x:
				continue
			var c: Rect2 = Rect2(Vector2(x, r.position.y), r.size)
			if not _hits(c, placed) and absf(x - want.position.x) < best_d:
				best_d = absf(x - want.position.x)
				best = c
	if best_d < INF:
		return best
	guard = 0
	while _hits(best, placed) and guard < placed.size() + 1:
		guard += 1
		for o: Rect2 in placed:
			if best.grow(1.0).intersects(o):
				best.position.y = maxf(best.position.y, o.end.y + 3.0)
	return best


static func _hits(r: Rect2, placed: Array[Rect2]) -> bool:
	for o: Rect2 in placed:
		if r.grow(1.0).intersects(o):
			return true
	return false


func _process(delta: float) -> void:
	if stage == null or camera == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	var placed: Array[Rect2] = []
	var full: Array[Plate] = []
	for k: Variant in _plates.keys():
		var p: Plate = _plates[k]
		if p.gone:
			continue
		p.linger = maxf(0.0, p.linger - delta)
		var top: Vector3 = stage.call("anchor_pos", str(k), &"overhead")
		var feet: Vector3 = stage.call("anchor_pos", str(k), &"feet")
		var behind: bool = camera.is_position_behind(top)
		p.visible = shown and not behind
		p.slim.visible = not shown and p.linger > 0.0 and not camera.is_position_behind(feet)
		if p.slim.visible:
			var fp: Vector2 = camera.unproject_position(feet)
			var ssz: Vector2 = p.slim.get_combined_minimum_size()
			p.slim.size = ssz
			p.slim.position = Vector2(clampf(fp.x - ssz.x * 0.5, 4.0, vp.x - ssz.x - 4.0),
				clampf(fp.y + 8.0, TOP_BAND, vp.y - ssz.y - 4.0))
		if p.visible:
			full.append(p)
	# full plates: lowest (nearest) first, each pushed up above the plates it would overlap
	var want: Dictionary = {}
	for p2: Plate in full:
		var sp: Vector2 = camera.unproject_position(stage.call("anchor_pos", p2.unit_id, &"overhead"))
		var sz: Vector2 = p2.get_combined_minimum_size()
		var gap: float = TARGET_GAP if targeted.has(p2.unit_id) else GAP
		want[p2] = Rect2(Vector2(sp.x - sz.x * 0.5, sp.y - sz.y - gap), sz)
	full.sort_custom(func(a: Plate, b: Plate) -> bool:
		return (want[a] as Rect2).position.y > (want[b] as Rect2).position.y)
	for p3: Plate in full:
		var r: Rect2 = place_rect(want[p3], placed, vp.x - RIGHT_CLEAR)
		placed.append(r)
		p3.size = r.size
		p3.position = r.position
