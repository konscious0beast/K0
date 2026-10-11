extends Control
## Touch buttons of the real-time combat (07 §7.3): the right thumb group replaces the action bar — Slot 1 (96 visible /
## 104 hit) on the exploration's action button spot (1147, 587), Slots 2–4 on an arc of 136 px around it, SHOW (80 / 96,
## gold; FINALE magenta ↔ gold) at 140 px, the potion (64 / 88) at (907, 638) with "2/3", the target switch (64 / 88)
## at (1227, 360) — centres of the 1280 × 720 reference, anchored to the bottom-right corner and shifted by the
## display insets (notch). Every hit area ≥ 88 px, no two overlap (07 §7.3 table). Tap = press on release; a long press
## shows the tooltip (name, cost, cooldown, short text) and triggers nothing; holding the potion opens the item wheel,
## holding the target switch picks the previous target. The partner button and the tactic chip live at the party frames
## (unit_frames.gd, touch layout); the stick zone, tap-vs-drag and the hidden map / action buttons are the combat
## mode of TouchControls. Visuals = one triangle array (round buttons, icons, pie sweeps); labels without outline.
## Private R3 script.

signal slot_pressed(slot: int)
signal wheel_requested()
signal target_cycle(forward: bool)


## Round hit area: a circle with the hit size as diameter (07 §7.3 checks centre distances ≥ the sum of the half hit
## sizes — circles; square boxes would overlap in their corners).
class RoundButton extends Button:
	func _has_point(point: Vector2) -> bool:
		return point.distance_to(size * 0.5) <= minf(size.x, size.y) * 0.5

const CombatStyle := preload("res://scenes/combat/ui/combat_style.gd")
const CombatIcons := preload("res://scenes/combat/ui/combat_icons.gd")
const CombatView := preload("res://scenes/combat/ui/combat_view.gd")
const IconMesh := preload("res://scenes/ui/icon_mesh.gd")

const REF: Vector2 = Vector2(1280, 720)
## name → [centre (reference px), visible diameter, hit size]
const BUTTONS: Dictionary = {
	"slot1": [Vector2(1147, 587), 96.0, 104.0], "slot2": [Vector2(1019, 634), 72.0, 88.0],
	"slot3": [Vector2(1024, 530), 72.0, 88.0], "slot4": [Vector2(1100, 459), 72.0, 88.0],
	"slot5": [Vector2(1206, 460), 80.0, 96.0], "slot6": [Vector2(907, 638), 64.0, 88.0],
	"target": [Vector2(1227, 360), 64.0, 88.0],
}
## DEVIATION from 07 §7.3 (potion at (907, 650)): 12 px higher, so the 64 px disc ends above the chat ticker (y 674–696
## of the reference); its count "2/3" sits inside the disc. Slot 2 ↔ potion stays 112 px apart (≥ 88).
const LONG_PRESS_SEC: float = 0.45
const WHEEL_HOLD_SEC: float = 0.4
const SHAKE_SEC: float = 0.2

var states: Array[Dictionary] = []          # CombatView.slots, set every frame by the HUD
var hype: float = 0.0
var focus_slot: int = 0                     # pulsing gold ring (hint card / assist)
var buttons: Dictionary = {}                # name → Button (hit areas)

var _held: Dictionary = {}                  # name → seconds held
var _consumed: Dictionary = {}              # name → the long press already did its thing
var _shake: Dictionary = {}
var _tooltip: PanelContainer
var _tooltip_label: Label
var _secs: Dictionary = {}                  # slot → Label
var _caps: Dictionary = {}                  # slot → Label (SHOW / FINALE / 2/3)
var _insets: Dictionary = {"left": 0, "top": 0, "right": 0, "bottom": 0}
var _t: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for n: String in BUTTONS.keys():
		var spec: Array = BUTTONS[n]
		var b: Button = RoundButton.new()
		b.name = "Hit_" + n
		b.focus_mode = Control.FOCUS_NONE
		b.flat = true
		for st: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		var hit: float = float(spec[2])
		b.custom_minimum_size = Vector2(hit, hit)
		b.size = b.custom_minimum_size
		b.button_down.connect(_on_down.bind(n))
		b.button_up.connect(_on_up.bind(n))
		add_child(b)
		buttons[n] = b
	for slot in range(1, 7):
		var s: Label = CombatStyle.label("", 22, CombatStyle.C_PAPER, true)
		s.name = "Secs%d" % slot
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		s.visible = false
		add_child(s)
		_secs[slot] = s
		var c: Label = CombatStyle.label("", 12, CombatStyle.C_GOLD, true)
		c.name = "Cap%d" % slot
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.visible = false
		add_child(c)
		_caps[slot] = c
	_tooltip = PanelContainer.new()
	_tooltip.name = "Tooltip"
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = CombatStyle.panel_box(CombatStyle.C_PANEL_SOLID, CombatStyle.C_CYAN, 2)
	sb.set_content_margin_all(10.0)
	_tooltip.add_theme_stylebox_override("panel", sb)
	_tooltip.visible = false
	_tooltip_label = CombatStyle.label("", 16, CombatStyle.C_TEXT, false)
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_label.custom_minimum_size = Vector2(300, 0)
	_tooltip.add_child(_tooltip_label)
	add_child(_tooltip)


func _ready() -> void:
	get_viewport().size_changed.connect(_apply_insets)
	_apply_insets()


func _apply_insets() -> void:
	_insets = SafeAreaContainer.device_insets(get_viewport())
	for n: String in buttons.keys():
		var b: Button = buttons[n]
		var c: Vector2 = center_ref(n)
		var hit: float = b.custom_minimum_size.x
		b.anchor_left = 1.0
		b.anchor_right = 1.0
		b.anchor_top = 1.0
		b.anchor_bottom = 1.0
		var from_right: float = REF.x - c.x + float(_insets["right"])
		var from_bottom: float = REF.y - c.y + float(_insets["bottom"])
		b.offset_left = -from_right - hit * 0.5
		b.offset_right = -from_right + hit * 0.5
		b.offset_top = -from_bottom - hit * 0.5
		b.offset_bottom = -from_bottom + hit * 0.5
	queue_redraw()


static func center_ref(n: String) -> Vector2:
	return (BUTTONS[n] as Array)[0] as Vector2


## Screen centre of a button now (anchors + insets).
func center_of(n: String) -> Vector2:
	var b: Button = buttons[n]
	return b.position + b.size * 0.5


func visible_size(n: String) -> float:
	return float((BUTTONS[n] as Array)[1])


## Hit rect (canvas) of a shown button, Rect2() when hidden.
func hit_rect(n: String) -> Rect2:
	var b: Button = buttons.get(n, null) as Button
	return b.get_global_rect() if b != null and b.visible and is_visible_in_tree() else Rect2()


## True when `canvas_pos` is on one of the shown buttons (TouchControls: no camera tap / drag there).
func blocks(canvas_pos: Vector2) -> bool:
	if not is_visible_in_tree():
		return false
	for n: String in buttons.keys():
		if hit_contains(n, canvas_pos):
			return true
	return false


## The round hit area of a shown button contains `canvas_pos`.
func hit_contains(n: String, canvas_pos: Vector2) -> bool:
	var r: Rect2 = hit_rect(n)
	return r.size.x > 0.0 and canvas_pos.distance_to(r.get_center()) <= minf(r.size.x, r.size.y) * 0.5


func set_states(p_states: Array[Dictionary]) -> void:
	states = p_states
	var shown: Dictionary = {}
	for s: Dictionary in states:
		shown["slot%d" % int(s["slot"])] = true
	for n: String in buttons.keys():
		(buttons[n] as Button).visible = n == "target" or shown.has(n)
	_update_labels()
	queue_redraw()


func refuse(slot: int) -> void:
	_shake["slot%d" % slot] = SHAKE_SEC


func state_of(slot: int) -> Dictionary:
	for s: Dictionary in states:
		if int(s["slot"]) == slot:
			return s
	return {}


func _process(delta: float) -> void:
	_t += delta
	for k: Variant in _shake.keys():
		_shake[k] = float(_shake[k]) - delta
		if float(_shake[k]) <= 0.0:
			_shake.erase(k)
	for n: Variant in _held.keys():
		_held[n] = float(_held[n]) + delta
		var held: float = float(_held[n])
		if _consumed.has(n):
			continue
		if str(n) == "slot6" and held >= WHEEL_HOLD_SEC:
			_consumed[n] = true
			wheel_requested.emit()
		elif str(n) == "target" and held >= LONG_PRESS_SEC:
			_consumed[n] = true
			target_cycle.emit(false)
		elif str(n).begins_with("slot") and str(n) != "slot6" and held >= LONG_PRESS_SEC:
			_consumed[n] = true
			_show_tooltip(str(n))
	queue_redraw()


func _on_down(n: String) -> void:
	_held[n] = 0.0
	_consumed.erase(n)


func _on_up(n: String) -> void:
	var was_long: bool = _consumed.has(n)
	_held.erase(n)
	_consumed.erase(n)
	_tooltip.visible = false
	if was_long:
		return
	if n == "target":
		target_cycle.emit(true)
	elif n.begins_with("slot"):
		slot_pressed.emit(n.substr(4).to_int())


func _show_tooltip(n: String) -> void:
	var s: Dictionary = state_of(n.substr(4).to_int())
	if s.is_empty():
		return
	_tooltip_label.text = UiUtilRef.glyph_safe(tooltip_text(s))
	_tooltip.visible = true
	_tooltip.reset_size()
	var c: Vector2 = center_of(n)
	var sz: Vector2 = _tooltip.get_combined_minimum_size()
	_tooltip.size = sz
	_tooltip.position = Vector2(clampf(c.x - sz.x * 0.5, 8.0, size.x - sz.x - 8.0),
		c.y - visible_size(n) * 0.5 - sz.y - 12.0)


## "Wuchtschlag · 2 MP · Abklingzeit 12 s\n<desc>" (07 §7.3 long press).
static func tooltip_text(s: Dictionary) -> String:
	var parts: PackedStringArray = [str(s["name"])]
	if int(s["mp"]) > 0:
		parts.append("%d MP" % int(s["mp"]))
	var def: SkillDef = CombatView.skill_of(str(s["id"]))
	if def != null and not def.rt.is_empty() and int(def.rt.get("cooldown_ms", 0)) > 0:
		parts.append("Abklingzeit %d s" % (int(def.rt["cooldown_ms"]) / 1000))
	if bool(s["show"]):
		parts.append("Abklingzeit 30 s (ganze Party)")
	var desc: String = ""
	if def != null and def.desc != "":
		desc = "\n" + TranslationServer.translate(def.desc)
	elif bool(s["is_item"]) and CombatStyle.gd().has_id("items", str(s["id"])):
		desc = "\n" + TranslationServer.translate(CombatStyle.gd().item(str(s["id"])).desc)
	return " · ".join(parts) + desc


func tooltip_shown() -> String:
	return _tooltip_label.text if _tooltip.visible else ""


func _update_labels() -> void:
	for slot in range(1, 7):
		(_secs[slot] as Label).visible = false
		(_caps[slot] as Label).visible = false
	for s: Dictionary in states:
		var slot: int = int(s["slot"])
		var n: String = "slot%d" % slot
		var c: Vector2 = center_of(n)
		var vis: float = visible_size(n)
		var secs: Label = _secs[slot]
		secs.visible = int(s["cd_left"]) > 0
		secs.text = CombatStyle.secs(int(s["cd_left"]))
		secs.size = Vector2(vis, vis)
		secs.position = c - Vector2(vis, vis) * 0.5
		var cap: Label = _caps[slot]
		var txt: String = ""
		if bool(s["finale"]):
			txt = "FINALE"
		elif bool(s["show"]):
			txt = "SHOW"
		elif int(s["count"]) >= 0:
			txt = "%d/%d" % [int(s["count"]), int(s["max_count"])]
		cap.visible = txt != ""
		cap.text = txt
		cap.add_theme_color_override("font_color", CombatStyle.C_GOLD if bool(s["show"]) else CombatStyle.C_PAPER)
		cap.size = Vector2(vis + 30.0, 15.0)
		cap.position = c + Vector2(-(vis + 30.0) * 0.5, vis * 0.5 + 3.0)        # SHOW / FINALE under the disc
		if int(s["count"]) >= 0:
			cap.position.y = c.y + vis * 0.5 - 19.0          # the count inside the disc (the ticker is below)


func _draw() -> void:
	var m: IconMesh = IconMesh.new()
	for s: Dictionary in states:
		_draw_slot(m, s)
	if (buttons["target"] as Button).visible:
		var c: Vector2 = center_of("target")
		var r: float = visible_size("target") * 0.5
		m.circle(c, r, Color(CombatStyle.C_PANEL_SOLID, 0.85), true)
		m.ring(c, r - 1.5, Color(CombatStyle.C_PAPER, 0.5), 2.0, true)
		m.ring(c, r * 0.42, CombatStyle.C_CYAN, 3.0, true)
		for k in 4:
			var a: float = PI * 0.5 * float(k)
			var d: Vector2 = Vector2(cos(a), sin(a))
			m.line(c + d * r * 0.25, c + d * r * 0.62, CombatStyle.C_CYAN, 3.0, true)
		m.poly(PackedVector2Array([c + Vector2(r * 0.55, -r * 0.62), c + Vector2(r * 0.9, -r * 0.42),
			c + Vector2(r * 0.55, -r * 0.22)]), CombatStyle.C_PAPER)
	m.commit(self)


func _draw_slot(m: IconMesh, s: Dictionary) -> void:
	var slot: int = int(s["slot"])
	var n: String = "slot%d" % slot
	var c: Vector2 = center_of(n)
	if _shake.has(n):
		c.x += sin(_t * 70.0) * 5.0 * float(_shake[n]) / SHAKE_SEC
	var r: float = visible_size(n) * 0.5
	var show: bool = bool(s["show"])
	var finale: bool = bool(s["finale"])
	var pressed: bool = _held.has(n)
	m.circle(c, r, Color(CombatStyle.C_PANEL_SOLID, 0.9 if not pressed else 1.0), true)
	if slot == 1:
		m.circle(c, r - 4.0, Color(CombatStyle.C_MAGENTA, 0.55), true)
	var border: Color = Color(CombatStyle.C_PAPER, 0.55)
	var bw: float = 2.5
	if finale:
		border = CombatStyle.C_MAGENTA.lerp(CombatStyle.C_GOLD, 0.5 + 0.5 * sin(_t * TAU * 1.5))
		bw = 4.0
	elif show:
		border = CombatStyle.C_GOLD
		bw = 4.0
	m.ring(c, r - bw * 0.5, border, bw, true)
	var isz: float = r * 1.15
	var ic: Vector2 = c
	if int(s["count"]) >= 0:                           # potion: icon up, room for the count inside
		isz = r * 0.95
		ic = c + Vector2(0.0, -6.0)
	var from: int = m.colors.size()
	CombatIcons.draw(m, str(s["icon"]), Rect2(ic - Vector2(isz, isz) * 0.5, Vector2(isz, isz)))
	if bool(s["no_mp"]):
		CombatIcons.recolor(m, from, 0.85, Color(CombatStyle.C_MANA, 0.5))
	elif bool(s["out_of_range"]):
		CombatIcons.recolor(m, from, 0.4, Color(CombatStyle.C_DANGER, 0.6))
	elif bool(s["no_target"]):
		CombatIcons.recolor(m, from, 0.0, Color(0, 0, 0, 0), 0.4)
	var cd: float = CombatView.ratio(int(s["cd_left"]), int(s["cd_total"]))
	if cd > 0.0:
		_pie(m, c, r - 1.0, cd, Color(0.05, 0.03, 0.08, 0.65))
	var gcd: float = CombatView.ratio(int(s["gcd_left"]), int(s["gcd_total"]))
	if gcd > 0.0:
		_arc(m, c, r + 3.0, gcd, Color(1, 1, 1, 0.8), 3.0)
	if bool(s["queued"]):
		m.ring(c, r + 1.5, CombatStyle.C_GOLD, 3.0, true)
	if bool(s["assist"]) or focus_slot == slot:
		var a: float = 0.45 + 0.55 * (0.5 + 0.5 * sin(_t * TAU * 1.2))
		m.ring(c, r + 7.0, Color(CombatStyle.C_GOLD, a), 3.0, true)
	if finale and hype >= 85.0:
		for i in 8:
			var ang: float = _t * 1.8 + TAU * float(i) / 8.0
			m.circle(c + Vector2(cos(ang), sin(ang)) * (r + 10.0), 2.5, CombatStyle.C_GOLD, true)


## Remaining part of a cooldown as a dark pie, clockwise from 12 o'clock (like the PC sweep shader: the last part).
static func _pie(m: IconMesh, c: Vector2, r: float, frac: float, col: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array([c])
	var steps: int = maxi(2, int(ceil(32.0 * frac)))
	var a0: float = -PI * 0.5 + TAU * (1.0 - frac)
	for i in steps + 1:
		var a: float = a0 + TAU * frac * float(i) / float(steps)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	m.poly(pts, col)


static func _arc(m: IconMesh, c: Vector2, r: float, frac: float, col: Color, w: float) -> void:
	var steps: int = maxi(2, int(ceil(32.0 * frac)))
	var a0: float = -PI * 0.5 + TAU * (1.0 - frac)
	for i in steps:
		var a: float = a0 + TAU * frac * float(i) / float(steps)
		var b: float = a0 + TAU * frac * float(i + 1) / float(steps)
		m.line(c + Vector2(cos(a), sin(a)) * r, c + Vector2(cos(b), sin(b)) * r, col, w, true)


const UiUtilRef := preload("res://scenes/ui/ui_util.gd")
