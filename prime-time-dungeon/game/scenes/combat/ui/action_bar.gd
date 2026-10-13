extends Control
## Real-time action bar, PC / gamepad layout (07 §4.1, §8.1, §8.2): the visible slots (the bar grows with the level —
## tutorial: 1 + SHOW only) 64 px with 8 px gaps and 12 px more before the potion slot, centred at the bottom of the
## safe frame. Draw calls (07 §8.2, §8.10): frames + symbols + state tints of every slot = ONE triangle array; the
## cooldown / GCD sweeps = 6 ColorRects with ONE shared ShaderMaterial (ui_cooldown_sweep.gdshader, instance uniforms)
## = one call; a second triangle array above the sweeps (key-cap plates, queue frame, assist ring, ready flash — never
## darkened by a running cooldown); outline-free labels (key caps, MP / count, seconds) batch per font size. States from
## CombatView.slots (pure RtSim queries) every frame. Mouse: left click = press, right click on the potion slot = item
## wheel. Private R3 script.

signal slot_pressed(slot: int)
signal slot_alt_pressed(slot: int)

const CombatStyle := preload("res://scenes/combat/ui/combat_style.gd")
const CombatIcons := preload("res://scenes/combat/ui/combat_icons.gd")
const CombatView := preload("res://scenes/combat/ui/combat_view.gd")
const IconMesh := preload("res://scenes/ui/icon_mesh.gd")
const SWEEP_SHADER: String = "res://art/shaders/ui_cooldown_sweep.gdshader"

const SLOT: float = 64.0
const GAP: float = 8.0
const POTION_GAP: float = 12.0
const ICON: float = 44.0
const FLASH_SEC: float = 0.15
const SHAKE_SEC: float = 0.2
const REFUSE_SEC: float = 1.1
const ASSIST_HZ: float = 1.2
const KEY_FONT: int = 12
const SMALL_FONT: int = 12
const SECS_FONT: int = 20

static var _sweep_mat: ShaderMaterial = null

## Slot display states (CombatView.slots), set every frame by the HUD.
var states: Array[Dictionary] = []
## Slot → key cap text ("1", "A", …); empty = no cap (touch).
var key_texts: Dictionary = {}
## Hype for the FINALE spark crown (≥ 85, presentation only).
var hype: float = 0.0

var _rects: Dictionary = {}                 # slot → Rect2 (local)
var _sweeps: Dictionary = {}                # slot → ColorRect
var _keys: Dictionary = {}                  # slot → Label
var _smalls: Dictionary = {}                # slot → Label (MP cost / potion count)
var _secs: Dictionary = {}                  # slot → Label
var _finale: Label
var _refusal: Label
var _flash: Dictionary = {}                 # slot → seconds left
var _shake: Dictionary = {}                 # slot → seconds left
var _had_cd: Dictionary = {}                # slot → bool (cooldown running last frame)
var _refuse_t: float = 0.0
var _t: float = 0.0
var _layout_key: String = ""
var _over: Control                          # draws above the sweeps (key caps, queue, assist, flash)


## The one ShaderMaterial of every sweep (bar slots, partner button, touch slots).
static func sweep_material() -> ShaderMaterial:
	if _sweep_mat == null:
		_sweep_mat = ShaderMaterial.new()
		_sweep_mat.shader = load(SWEEP_SHADER) as Shader
	return _sweep_mat


## Width of a bar with `slots` (sorted slot numbers).
static func width_for(slots: Array) -> float:
	if slots.is_empty():
		return 0.0
	var w: float = 0.0
	for i in slots.size():
		if i > 0:
			w += GAP + (POTION_GAP if int(slots[i]) == CombatView.SLOT_POTION else 0.0)
		w += SLOT
	return w


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, SLOT)
	for slot in range(1, 7):
		var sw: ColorRect = ColorRect.new()
		sw.name = "Sweep%d" % slot
		sw.material = sweep_material()
		sw.color = Color.WHITE
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sw.visible = false
		add_child(sw)
		_sweeps[slot] = sw
	_over = Control.new()
	_over.name = "Over"
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.draw.connect(_draw_over)
	add_child(_over)
	# labels grouped by font size (each size is its own glyph texture → one batch per group)
	for slot in range(1, 7):
		var k: Label = CombatStyle.label("", KEY_FONT, CombatStyle.C_INK, true)
		k.name = "Key%d" % slot
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		k.visible = false
		add_child(k)
		_keys[slot] = k
	for slot in range(1, 7):
		var s: Label = CombatStyle.label("", SMALL_FONT, CombatStyle.C_TEXT, true)
		s.name = "Small%d" % slot
		s.visible = false
		add_child(s)
		_smalls[slot] = s
	_finale = CombatStyle.label("FINALE", SMALL_FONT, CombatStyle.C_GOLD, true)
	_finale.name = "Finale"
	_finale.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_finale.visible = false
	add_child(_finale)
	for slot in range(1, 7):
		var c: Label = CombatStyle.label("", SECS_FONT, CombatStyle.C_PAPER, true)
		c.name = "Secs%d" % slot
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		c.visible = false
		add_child(c)
		_secs[slot] = c
	_refusal = CombatStyle.label("", 16, CombatStyle.C_DANGER, true)
	_refusal.name = "Refusal"
	_refusal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_refusal.visible = false
	add_child(_refusal)


## New states (every frame). Rebuilds the layout only when the set of slots changes.
func set_states(p_states: Array[Dictionary]) -> void:
	states = p_states
	var slots: Array = []
	for s: Dictionary in states:
		slots.append(int(s["slot"]))
	var key: String = str(slots)
	if key != _layout_key:
		_layout_key = key
		_layout(slots)
	_update_labels_and_sweeps()
	queue_redraw()
	_over.queue_redraw()


## Local rect of `slot` (Rect2() when hidden).
func slot_rect(slot: int) -> Rect2:
	return _rects.get(slot, Rect2()) as Rect2


## Visible slots in order.
func visible_slots() -> Array[int]:
	var out: Array[int] = []
	for s: Dictionary in states:
		out.append(int(s["slot"]))
	return out


func state_of(slot: int) -> Dictionary:
	for s: Dictionary in states:
		if int(s["slot"]) == slot:
			return s
	return {}


## Refusal feedback (07 §8.2): the slot shakes 0.2 s, the short text appears above the bar.
func refuse(slot: int, reason: String) -> void:
	if _rects.has(slot):
		_shake[slot] = SHAKE_SEC
	_refusal.text = CombatStyle.refusal_text(reason)
	_refusal.visible = true
	_refuse_t = REFUSE_SEC
	_refusal.size = Vector2(maxf(size.x, 260.0), 22)
	_refusal.position = Vector2((size.x - _refusal.size.x) * 0.5, -30.0)


func refusal_text() -> String:
	return _refusal.text if _refusal.visible else ""


func _process(delta: float) -> void:
	_t += delta
	for d: Dictionary in [_flash, _shake]:
		for k: Variant in d.keys():
			d[k] = float(d[k]) - delta
			if float(d[k]) <= 0.0:
				d.erase(k)
	if _refuse_t > 0.0:
		_refuse_t -= delta
		_refusal.modulate.a = clampf(_refuse_t / 0.3, 0.0, 1.0)
		if _refuse_t <= 0.0:
			_refusal.visible = false
	if not states.is_empty():
		queue_redraw()
		_over.queue_redraw()


func _layout(slots: Array) -> void:
	_rects.clear()
	var x: float = 0.0
	for i in slots.size():
		var slot: int = int(slots[i])
		if i > 0:
			x += GAP + (POTION_GAP if slot == CombatView.SLOT_POTION else 0.0)
		_rects[slot] = Rect2(Vector2(x, 0.0), Vector2(SLOT, SLOT))
		x += SLOT
	custom_minimum_size = Vector2(x, SLOT)
	size = custom_minimum_size
	_over.position = Vector2.ZERO
	_over.size = size
	for slot in range(1, 7):
		var shown: bool = _rects.has(slot)
		var r: Rect2 = slot_rect(slot)
		var sw: ColorRect = _sweeps[slot]
		sw.visible = shown
		sw.position = r.position
		sw.size = r.size
		(_keys[slot] as Label).visible = shown
		(_smalls[slot] as Label).visible = false
		(_secs[slot] as Label).visible = false


func _update_labels_and_sweeps() -> void:
	_finale.visible = false
	for s: Dictionary in states:
		var slot: int = int(s["slot"])
		var r: Rect2 = slot_rect(slot)
		var key: Label = _keys[slot]
		var kt: String = str(key_texts.get(slot, ""))
		key.visible = kt != ""
		key.text = kt
		key.size = Vector2(maxf(18.0, 8.0 + 7.0 * kt.length()), 16)
		key.position = r.position + Vector2(3, 2)
		var cd_l: int = int(s["cd_left"])
		var cd_t: int = int(s["cd_total"])
		var sw: ColorRect = _sweeps[slot]
		sw.set_instance_shader_parameter(&"cd_left", CombatView.ratio(cd_l, cd_t))
		sw.set_instance_shader_parameter(&"gcd_left", CombatView.ratio(int(s["gcd_left"]), int(s["gcd_total"])))
		var running: bool = cd_l > 0
		if bool(_had_cd.get(slot, false)) and not running:
			_flash[slot] = FLASH_SEC                       # "wieder bereit": white flash 0.15 s
		_had_cd[slot] = running
		var secs: Label = _secs[slot]
		secs.visible = running
		secs.text = CombatStyle.secs(cd_l)
		secs.position = r.position
		secs.size = r.size
		var small: Label = _smalls[slot]
		var small_text: String = ""
		var small_col: Color = CombatStyle.C_TEXT
		if int(s["count"]) >= 0:
			small_text = "%d/%d" % [int(s["count"]), int(s["max_count"])]
		elif bool(s["no_mp"]) and int(s["mp"]) > 0:
			small_text = "%d MP" % int(s["mp"])
			small_col = CombatStyle.C_MANA.lightened(0.4)      # readable over the dark cooldown shade
		small.visible = small_text != ""
		small.text = small_text
		small.add_theme_color_override("font_color", small_col)
		small.size = Vector2(SLOT - 6.0, 15)
		small.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if int(s["count"]) >= 0 else HORIZONTAL_ALIGNMENT_LEFT
		small.position = r.position + Vector2(3, SLOT - 17.0)
		if bool(s["finale"]):
			_finale.visible = true
			_finale.size = Vector2(SLOT + 20.0, 15)
			_finale.position = r.position + Vector2(-10.0, -17.0)


func _draw() -> void:
	if states.is_empty():
		return
	var m: IconMesh = IconMesh.new()
	for s: Dictionary in states:
		_draw_slot(m, s)
	m.commit(self)


func _draw_slot(m: IconMesh, s: Dictionary) -> void:
	var slot: int = int(s["slot"])
	var r: Rect2 = slot_rect(slot)
	if r.size.x <= 0.0:
		return
	if _shake.has(slot):
		var k: float = float(_shake[slot]) / SHAKE_SEC
		r.position.x += sin(_t * 70.0) * 5.0 * k
	var show: bool = bool(s["show"])
	var finale: bool = bool(s["finale"])
	m.rect(r, CombatStyle.C_SLOT)
	# frame: SHOW gold with a slow shimmer, FINALE magenta ↔ gold, else cyan 60 %
	var border: Color = Color(CombatStyle.C_CYAN, 0.6)
	var bw: float = 2.0
	if finale:
		border = CombatStyle.C_MAGENTA.lerp(CombatStyle.C_GOLD, 0.5 + 0.5 * sin(_t * TAU * 1.5))
		bw = 3.0
	elif show:
		var ready: bool = int(s["cd_left"]) <= 0 and str(s["reason"]) == ""
		border = CombatStyle.C_GOLD.lerp(CombatStyle.C_PAPER, (0.25 + 0.25 * sin(_t * TAU * 0.5)) if ready else 0.0)
		bw = 3.0
	m.rect_outline(r.grow(-bw * 0.5), border, bw)
	if finale and hype >= 85.0:
		_spark_crown(m, r)
	var icon_r: Rect2 = Rect2(r.get_center() - Vector2(ICON, ICON) * 0.5, Vector2(ICON, ICON))
	var from: int = m.colors.size()
	CombatIcons.draw(m, str(s["icon"]), icon_r)
	if bool(s["no_mp"]):                               # desaturated + blue tint (MANA 50 %)
		CombatIcons.recolor(m, from, 0.85, Color(CombatStyle.C_MANA, 0.5))
	elif bool(s["out_of_range"]):                      # red tint (DANGER 60 %)
		CombatIcons.recolor(m, from, 0.4, Color(CombatStyle.C_DANGER, 0.6))
	elif bool(s["no_target"]):                         # dimmed to 40 %
		CombatIcons.recolor(m, from, 0.0, Color(0, 0, 0, 0), 0.4)


## Above the sweeps: queue frame, assist ring, ready flash and the key-cap plates (a cooldown never darkens them).
func _draw_over() -> void:
	if states.is_empty():
		return
	var m: IconMesh = IconMesh.new()
	for s: Dictionary in states:
		var slot: int = int(s["slot"])
		var r: Rect2 = slot_rect(slot)
		if r.size.x <= 0.0:
			continue
		if _shake.has(slot):
			r.position.x += sin(_t * 70.0) * 5.0 * float(_shake[slot]) / SHAKE_SEC
		if bool(s["queued"]):
			m.rect_outline(r.grow(-1.5), CombatStyle.C_GOLD, 3.0)
		if bool(s["assist"]):
			var a: float = 0.45 + 0.55 * (0.5 + 0.5 * sin(_t * TAU * ASSIST_HZ))
			m.ring(r.get_center(), SLOT * 0.5 + 3.0, Color(CombatStyle.C_GOLD, a), 3.0, true)
		if _flash.has(slot):
			m.rect(r, Color(1, 1, 1, 0.75 * float(_flash[slot]) / FLASH_SEC))
		var kt: String = str(key_texts.get(slot, ""))
		if kt != "":
			var kw: float = maxf(18.0, 8.0 + 7.0 * kt.length())
			m.rect(Rect2(r.position + Vector2(3, 3), Vector2(kw, 14)), Color(CombatStyle.C_PAPER, 0.92))
	m.commit(_over)


## Bei Hype ≥ 85: a crown of small sparks around the FINALE slot (presentation only, 07 §4.1).
func _spark_crown(m: IconMesh, r: Rect2) -> void:
	var c: Vector2 = r.get_center()
	for i in 8:
		var a: float = _t * 1.8 + TAU * float(i) / 8.0
		var p: Vector2 = c + Vector2(cos(a), sin(a)) * (SLOT * 0.62)
		var tw: float = 0.5 + 0.5 * sin(_t * 9.0 + float(i))
		m.circle(p, 2.0 + 1.5 * tw, Color(CombatStyle.C_GOLD, 0.6 + 0.4 * tw), true)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if not mb.pressed or mb.device == InputEvent.DEVICE_ID_EMULATION:
		return
	for slot: Variant in _rects.keys():
		if (_rects[slot] as Rect2).has_point(mb.position):
			if mb.button_index == MOUSE_BUTTON_LEFT:
				slot_pressed.emit(int(slot))
				accept_event()
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				slot_alt_pressed.emit(int(slot))
				accept_event()
			return
