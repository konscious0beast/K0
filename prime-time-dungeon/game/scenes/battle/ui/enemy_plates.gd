extends Control
## Enemy info plates above the enemies (GDD §14.5 "Gegner-Info"): name (+ letter of duplicate types), HP bar, HP
## number only when the bestiary lists the type as defeated (GameState.bestiary[def].defeated ≥ 1), status icons and
## weaknesses after discovery (weak_known + weaknesses hit in this battle). Plates show while the player picks a
## command and for a moment after an enemy is hit; otherwise they stay out of the cinematic shots.
## Private M5 helper (no class_name).

const HudStyle := preload("res://scenes/battle/ui/hud_style.gd")
const PLATE_W: float = 132.0
const LINGER_SEC: float = 1.4


## One plate.
class Plate extends VBoxContainer:
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


var stage: Node3D = null
var camera: Camera3D = null
var shown: bool = false            # global visibility (command input)

var _plates: Dictionary = {}       # id → Plate


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func add_plate(id: String, display_name: String, hp: int, max_hp: int, show_hp: bool,
		weak: PackedStringArray) -> void:
	if _plates.has(id):
		var old: Plate = _plates[id]
		old.queue_free()
	var p: Plate = Plate.new()
	p.unit_id = id
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_constant_override("separation", 1)
	p.custom_minimum_size = Vector2(PLATE_W, 0)
	p.max_hp = maxi(1, max_hp)
	p.show_hp = show_hp
	p.weak = weak.duplicate()
	p.name_label = HudStyle.label(display_name, 15, HudStyle.C_PAPER, true, 4)
	p.name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(p.name_label)
	p.bar = HudStyle.Bar.new(HudStyle.C_ENEMY, 6.0)
	p.bar.custom_minimum_size = Vector2(PLATE_W - 20.0, 6.0)
	p.bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.add_child(p.bar)
	p.hp_label = HudStyle.mono_label("", 13, Color("#ffd0d6"))
	p.hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(p.hp_label)
	p.icons = HBoxContainer.new()
	p.icons.alignment = BoxContainer.ALIGNMENT_CENTER
	p.icons.add_theme_constant_override("separation", 2)
	p.icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(p.icons)
	add_child(p)
	_plates[id] = p
	set_hp(id, hp, false)
	_rebuild_icons(p)
	p.visible = false


func has_plate(id: String) -> bool:
	return _plates.has(id)


func plate_hp(id: String) -> int:
	var p: Plate = _plates.get(id, null)
	return p.hp if p != null else -1


func set_hp(id: String, hp: int, animate: bool = true) -> void:
	var p: Plate = _plates.get(id, null)
	if p == null:
		return
	p.hp = clampi(hp, 0, p.max_hp)
	p.bar.set_ratio(float(p.hp) / float(p.max_hp), animate)
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


func _rebuild_icons(p: Plate) -> void:
	for c: Node in p.icons.get_children():
		c.queue_free()
	for sid: String in p.statuses:
		p.icons.add_child(HudStyle.Icon.new(HudStyle.status_icon(sid), HudStyle.status_color(sid), 14))
	for el: String in p.weak:
		var ic: HudStyle.Icon = HudStyle.Icon.new("element_" + el, HudStyle.element_color(el), 14)
		p.icons.add_child(ic)
	p.icons.visible = p.icons.get_child_count() > 0 or not p.statuses.is_empty() or not p.weak.is_empty()


func _process(delta: float) -> void:
	if stage == null or camera == null:
		return
	for k: Variant in _plates.keys():
		var p: Plate = _plates[k]
		if p.gone:
			continue
		p.linger = maxf(0.0, p.linger - delta)
		var want: bool = shown or p.linger > 0.0
		var top: Vector3 = stage.call("anchor_pos", str(k), &"overhead")
		if not want or camera.is_position_behind(top):
			p.visible = false
			continue
		p.visible = true
		var sp: Vector2 = camera.unproject_position(top)
		var sz: Vector2 = p.get_combined_minimum_size()
		p.size = sz
		p.position = sp - Vector2(sz.x * 0.5, sz.y + 40.0)   # room for the target arrow below
