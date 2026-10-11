extends Control
## Item wheel of the real-time combat (07 §3.11, §7.1–§7.3): right click on the potion slot (PC), hold LB 0.4 s
## (gamepad: right stick picks, releasing LB uses), hold the potion button (touch: tap an entry). Lists the combat items
## of the party (RtSetup.items minus what was used in this combat) in items.json rt.wheel order on a ring: 64 px
## visible / 88 px hit per entry, the count under each. The sim decides as always (party item cooldown, 3 per combat):
## the wheel only sends combat_item. Never pauses the combat. Private R3 script.

signal item_chosen(item_id: String)
signal closed()

const CombatStyle := preload("res://scenes/combat/ui/combat_style.gd")
const CombatIcons := preload("res://scenes/combat/ui/combat_icons.gd")
const IconMesh := preload("res://scenes/ui/icon_mesh.gd")

const RING_R: float = 118.0
const ENTRY_VIS: float = 64.0
const ENTRY_HIT: float = 88.0
const STICK_DEAD: float = 0.45

## [{"id", "count", "icon", "name"}] in wheel order.
var entries: Array[Dictionary] = []
var selected: int = -1
var center: Vector2 = Vector2.ZERO

var _labels: Array[Label] = []
var _name: Label
var _hits: Array[Button] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_name = CombatStyle.label("", 18, CombatStyle.C_TEXT, true)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_name)


## Entries of the wheel from the combat setup: battle items with a count left, sorted by rt.wheel then data order.
static func entries_from(setup_items: Dictionary, used: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ids: Array = setup_items.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		var wa: int = _wheel_rank(str(a))
		var wb: int = _wheel_rank(str(b))
		return wa < wb if wa != wb else str(a) < str(b))
	for id: Variant in ids:
		var n: int = int(setup_items[id]) - int(used.get(str(id), 0))
		if n <= 0:
			continue
		var name: String = str(id)
		if CombatStyle.gd().has_id("items", str(id)):
			name = TranslationServer.translate(CombatStyle.gd().item(str(id)).name)
		out.append({"id": str(id), "count": n, "icon": CombatStyle.item_icon(str(id)), "name": name})
	return out


static func _wheel_rank(id: String) -> int:
	if CombatStyle.gd().has_id("items", id):
		var rt: Dictionary = CombatStyle.gd().item(id).rt
		if rt.has("wheel"):
			return int(rt["wheel"])
	return 100


func open(p_entries: Array[Dictionary], p_center: Vector2) -> void:
	entries = p_entries
	center = p_center
	selected = -1
	for b: Button in _hits:
		b.queue_free()
	_hits.clear()
	for l: Label in _labels:
		l.queue_free()
	_labels.clear()
	var vp: Vector2 = get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	center = Vector2(clampf(center.x, RING_R + 60.0, vp.x - RING_R - 60.0), clampf(center.y, RING_R + 60.0,
		vp.y - RING_R - 60.0))
	for i in entries.size():
		var p: Vector2 = entry_center(i)
		var b: Button = Button.new()
		b.name = "Entry%d" % i
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		for st: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		b.position = p - Vector2.ONE * ENTRY_HIT * 0.5
		b.size = Vector2.ONE * ENTRY_HIT
		b.mouse_entered.connect(func() -> void: _select(i))
		b.pressed.connect(func() -> void: choose(i))
		add_child(b)
		_hits.append(b)
		var l: Label = CombatStyle.label("×%d" % int(entries[i]["count"]), 14, CombatStyle.C_PAPER, true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.position = p + Vector2(-30.0, ENTRY_VIS * 0.5 - 4.0)
		l.size = Vector2(60, 16)
		add_child(l)
		_labels.append(l)
	_name.position = center + Vector2(-120.0, -12.0)
	_name.size = Vector2(240, 22)
	_name.text = "Gegenstand wählen" if not entries.is_empty() else "Keine Gegenstände dabei"
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP           # a click beside the entries closes the wheel
	queue_redraw()


func is_open() -> bool:
	return visible


func entry_center(i: int) -> Vector2:
	var n: int = maxi(entries.size(), 1)
	var a: float = -PI * 0.5 + TAU * float(i) / float(n)
	return center + Vector2(cos(a), sin(a)) * RING_R


func close() -> void:
	if not visible:
		return
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	closed.emit()


func choose(i: int) -> void:
	if i < 0 or i >= entries.size():
		close()
		return
	var id: String = str(entries[i]["id"])
	close()
	item_chosen.emit(id)


## Gamepad: the right stick picks the entry in its direction (the release of LB then uses it).
func stick(v: Vector2) -> void:
	if v.length() < STICK_DEAD or entries.is_empty():
		return
	var best: int = -1
	var best_dot: float = -2.0
	for i in entries.size():
		var d: Vector2 = (entry_center(i) - center).normalized()
		var dot: float = d.dot(v.normalized())
		if dot > best_dot:
			best_dot = dot
			best = i
	_select(best)


func confirm() -> void:
	if selected >= 0:
		choose(selected)
	else:
		close()


func _select(i: int) -> void:
	selected = i
	if i >= 0 and i < entries.size():
		_name.text = UiUtilRef.glyph_safe(str(entries[i]["name"]))
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		close()
		accept_event()


func _draw() -> void:
	if not visible:
		return
	var m: IconMesh = IconMesh.new()
	m.circle(center, RING_R + ENTRY_VIS * 0.5 + 14.0, Color(CombatStyle.C_INK, 0.72), true)
	m.ring(center, RING_R + ENTRY_VIS * 0.5 + 14.0, Color(CombatStyle.C_CYAN, 0.6), 2.0, true)
	for i in entries.size():
		var p: Vector2 = entry_center(i)
		var sel: bool = i == selected
		m.circle(p, ENTRY_VIS * 0.5, CombatStyle.C_SLOT if not sel else Color("#2a1f3d"), true)
		m.ring(p, ENTRY_VIS * 0.5 - 1.5, CombatStyle.C_GOLD if sel else Color(CombatStyle.C_PAPER, 0.5),
			3.0 if sel else 2.0, true)
		var isz: float = 40.0
		CombatIcons.draw(m, str(entries[i]["icon"]), Rect2(p - Vector2.ONE * isz * 0.5, Vector2.ONE * isz))
	m.commit(self)


const UiUtilRef := preload("res://scenes/ui/ui_util.gd")
