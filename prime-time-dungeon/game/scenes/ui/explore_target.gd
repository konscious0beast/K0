extends Control
## Target of a pull in the exploration (07 §2.2, §7.1–§7.4, E34) in the visual language of the combat HUD: a cyan ring
## around the targeted lead's feet and a bobbing chevron above its head (projected like the combat's name plates; gold
## while a pull is a first strike), and the target frame at the top centre below the floor timer — 300 wide like the
## combat's (07 §8.4): the lead's symbol, name with the group size, level, one chip per bar slot 1–5 of the figure with
## its key and range feedback in the tints of the action bar (07 §8.2: ready = cyan frame, out of range = red, not
## enough MP = blue, no opener or a slot the pad cannot pull with = dimmed), the distance, and what the group does and
## whether a pull now is a first strike ("verdutzt · Erstschlag!" in gold). Under the frame the pull hint (E37: the
## gold pill "1 · Angriff eröffnen" in the interaction prompt's style while slot 1 pulls and the person has not pulled
## yet; hidden on touch, where the action button carries slot 1) and the short text of a refused key (its chip shakes).
## The frame never hides its lead: a far lead appears high on the screen, and when its marker (ring to chevron) would
## sit behind the frame or the hint, the frame slides beside the marker within the HUD's free band (between the party
## column and the minimap) and back to the centre once there is room.
## Frames, chips, symbols and the marker = ONE triangle array (IconMesh + CombatIcons), labels without outline. The
## model comes from ExplorationScene.pull_frame_model through ExplorationHud.set_pull_target. Private helper (no
## class_name). 09 ST1-A: the level is the bare number in the round level plaque (level_badge.gd), never "Lv".

const CombatStyle := preload("res://scenes/combat/ui/combat_style.gd")
const CombatIcons := preload("res://scenes/combat/ui/combat_icons.gd")
const CombatView := preload("res://scenes/combat/ui/combat_view.gd")
const IconMesh := preload("res://scenes/ui/icon_mesh.gd")
const InputGlyph := preload("res://scenes/ui/input_glyph.gd")
const UiUtilRef := preload("res://scenes/ui/ui_util.gd")
const LevelBadge := preload("res://scenes/ui/level_badge.gd")   # 09 ST1-A

const FRAME: Vector2 = Vector2(300, 68)
const LEVEL_R: float = 11.0                # radius of the level plaque, top right in the frame (09 §1.2 Nr. 1)
const CHIP: float = 26.0
const CHIP_STEP: float = 30.0
const RING_M: float = 0.6                  # radius of the ring around the lead's feet
const RING_POINTS: int = 20
const CHEVRON_LIFT_M: float = 0.5          # above the head (the group pips) …
const CHEVRON_BUBBLE_M: float = 1.2        # … or above the "!" / "?!" bubble of an alert, chasing or dazed group
const REFUSE_SEC: float = 1.1
const SHAKE_SEC: float = 0.2
const PAD_SLOTS: int = 3                   # the pad pulls with A / X / Y = slots 1–3 (07 §7.2)
const SLOTS: int = 5                       # bar slots 1–4 + SHOW (the potion never pulls)
const HINT_TEXT: String = "Angriff eröffnen"
const HINT_BLOCK: float = 44.0             # height of the pull hint under the frame, gap included
const MARKER_PAD: float = 16.0             # room kept around the lead's marker
const BACK_ROOM: float = 28.0              # back to the centre only with this much room to spare (no flicker)
const SLIDE_PX_S: float = 1400.0           # the frame slides aside / back at this speed

## Frame top in local px (ExplorationHud: below the floor name / timer / quest column).
var top: float = 90.0
## Free band for the frame in local px (x: left limit, y: right limit) — ExplorationHud: from the party column to the
## minimap.
var band: Vector2 = Vector2(0.0, INF)
## The scene's model ({} = no target): see ExplorationScene.pull_frame_model.
var model: Dictionary = {}

var _labels: Dictionary = {}               # name → Label
var _caps: Array[Label] = []
var _refuse_text: String = ""
var _refuse_t: float = 0.0
var _shake: Dictionary = {}                # slot → seconds left
var _t: float = 0.0
var _hint: PanelContainer                  # the pull hint (E37)
var _x: float = NAN                        # left edge of the frame now (NAN: centre) …
var _goal_x: float = NAN                   # … and where it slides to
var _aside: bool = false                   # the frame stepped aside for its lead's marker


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for spec: Array in [["name", 15, CombatStyle.C_TEXT, true], ["level", 12, CombatStyle.C_GOLD, true],
			["dist", 12, CombatStyle.C_TEXT_DIM, false], ["state", 14, CombatStyle.C_TEXT_DIM, true],
			["refuse", 15, CombatStyle.C_DANGER, true]]:
		var l: Label = CombatStyle.label("", int(spec[1]), spec[2] as Color, bool(spec[3]))
		l.name = "L_" + str(spec[0])
		l.visible = false
		add_child(l)
		_labels[str(spec[0])] = l
	for i in SLOTS:
		var c: Label = CombatStyle.label("", 11, CombatStyle.C_INK, true)
		c.name = "Cap%d" % (i + 1)
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.visible = false
		add_child(c)
		_caps.append(c)
	_hint = PanelContainer.new()
	_hint.name = "Hint"
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.visible = false
	_hint.add_theme_stylebox_override("panel", UiUtilRef.box_style(Color(UiTheme.C_PANEL, 0.9), UiTheme.C_GOLD, 2, 0.21,
		16, 4))
	add_child(_hint)
	var row: HBoxContainer = UiUtilRef.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_child(row)
	row.add_child(InputGlyph.make(&"bar_1", "", 18))
	row.add_child(UiUtilRef.label(HINT_TEXT, &"", 19))


## New model (every physics frame while a lead is targeted; {} hides the frame and the marker).
func set_model(p_model: Dictionary) -> void:
	var fresh: bool = model.is_empty()
	model = p_model
	_goal_x = _place_x()
	if fresh or is_nan(_x) or model.is_empty():
		_x = _goal_x if not model.is_empty() else NAN
	_layout_labels()
	queue_redraw()


func is_shown() -> bool:
	return not model.is_empty()


## The frame rect (local).
func frame_rect() -> Rect2:
	return Rect2(Vector2(roundf(_x if not is_nan(_x) else _centre_x()), top), FRAME)


## The rect of the frame and the pull hint under it (local).
func block_rect() -> Rect2:
	var r: Rect2 = frame_rect()
	return Rect2(r.position, Vector2(FRAME.x, FRAME.y + (HINT_BLOCK if _hint_on() else 0.0)))


## Local screen box of the lead's marker, from the ring around its feet up to the chevron (Rect2() = not on screen).
func marker_rect() -> Rect2:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null or not model.has("foot") or not model.has("head"):
		return Rect2()
	var to_local: Transform2D = get_global_transform_with_canvas().affine_inverse()
	var foot: Vector3 = model["foot"]
	var r: Rect2 = Rect2()
	var pts: Array[Vector3] = [_chevron_at(), foot + Vector3(RING_M, 0.0, 0.0), foot - Vector3(RING_M, 0.0, 0.0),
		foot + Vector3(0.0, 0.0, RING_M), foot - Vector3(0.0, 0.0, RING_M)]
	for i in pts.size():
		if cam.is_position_behind(pts[i]):
			return Rect2()
		var s: Vector2 = to_local * cam.unproject_position(pts[i])
		r = Rect2(s, Vector2.ZERO) if i == 0 else r.expand(s)
	return r.grow(MARKER_PAD)


func _centre_x() -> float:
	return roundf((size.x - FRAME.x) * 0.5)


func _hint_on() -> bool:
	return bool(model.get("hint", false)) and _scheme() != Game.InputScheme.TOUCH


## The chevron's world point: above the head, or above the "!" / "?!" bubble.
func _chevron_at() -> Vector3:
	return (model["head"] as Vector3) + Vector3(0.0, CHEVRON_BUBBLE_M if bool(model.get("bubble", false))
		else CHEVRON_LIFT_M, 0.0)


## Where the frame's left edge belongs: the centre below the timer, unless the lead's marker would sit behind the
## frame or the hint — then beside the marker within `band` (the side it already stands on, else the one nearer the
## centre); back to the centre only with BACK_ROOM to spare.
func _place_x() -> float:
	var centre: float = _centre_x()
	var mr: Rect2 = marker_rect() if not model.is_empty() else Rect2()
	var h: float = FRAME.y + (HINT_BLOCK if _hint_on() else 0.0)
	if not mr.has_area() or not Rect2(Vector2(centre, top), Vector2(FRAME.x, h)).grow(BACK_ROOM if _aside else 0.0) \
			.intersects(mr):
		_aside = false
		return centre
	var lo: float = band.x
	var hi: float = maxf(lo, minf(band.y, size.x) - FRAME.x)
	var sides: Array[float] = [clampf(floorf(mr.position.x - FRAME.x), lo, hi), clampf(ceilf(mr.end.x), lo, hi)]
	if _aside and not is_nan(_x) and _x > centre:
		sides.reverse()                    # keep the side the frame already stands on
	elif not _aside and absf(sides[1] - centre) < absf(sides[0] - centre):
		sides.reverse()
	for x: float in sides:
		if not Rect2(Vector2(x, top), Vector2(FRAME.x, h)).intersects(mr):
			_aside = true
			return x
	_aside = false
	return centre


## Local rect of the chip of `slot` (Rect2() when the slot is not shown).
func chip_rect(slot: int) -> Rect2:
	var i: int = 0
	for s: Variant in model.get("slots", []) as Array:
		if int((s as Dictionary)["slot"]) == slot:
			var r: Rect2 = frame_rect()
			return Rect2(r.position + Vector2(52.0 + CHIP_STEP * i, 22.0), Vector2(CHIP, CHIP))
		i += 1
	return Rect2()


## A key that cannot pull (07 §2.2): its chip shakes, the short text shows under the frame for REFUSE_SEC.
func refuse(slot: int, text: String) -> void:
	_shake[slot] = SHAKE_SEC
	_refuse_text = text
	_refuse_t = REFUSE_SEC
	_layout_labels()


func refusal_text() -> String:
	return _refuse_text if _refuse_t > 0.0 else ""


func state_text() -> String:
	return (_labels["state"] as Label).text if (_labels["state"] as Label).visible else ""


## The pull hint shows (tests, captures).
func hint_shown() -> bool:
	return _hint.visible


func _process(delta: float) -> void:
	_t += delta
	for k: Variant in _shake.keys():
		_shake[k] = float(_shake[k]) - delta
		if float(_shake[k]) <= 0.0:
			_shake.erase(k)
	if _refuse_t > 0.0:
		_refuse_t -= delta
		var l: Label = _labels["refuse"]
		l.modulate.a = clampf(_refuse_t / 0.3, 0.0, 1.0)
		if _refuse_t <= 0.0:
			l.visible = false
	if not model.is_empty() and not is_nan(_x) and not is_nan(_goal_x) and _x != _goal_x:
		_x = move_toward(_x, _goal_x, SLIDE_PX_S * delta)
		_layout_labels()
	if not model.is_empty() or not _shake.is_empty():
		queue_redraw()


static func _scheme() -> int:
	return Game.input_scheme


## Key cap of `slot` in the current scheme ("" = none: touch, or a slot the pad cannot pull with).
static func key_of(slot: int) -> String:
	var scheme: int = _scheme()
	if scheme == Game.InputScheme.TOUCH or (scheme == Game.InputScheme.GAMEPAD and slot > PAD_SLOTS):
		return ""
	return InputGlyph.binding_text(StringName("bar_%d" % slot), scheme)


func _layout_labels() -> void:
	for l: Variant in _labels.values():
		(l as Label).visible = false
	for c: Label in _caps:
		c.visible = false
	_hint.visible = false
	var r: Rect2 = frame_rect()
	var below: float = r.end.y + 4.0
	if not model.is_empty():
		var lead: String = str(model.get("lead", ""))
		var def: EnemyDef = DB.enemy(lead) if DB.has_id("enemies", lead) else null
		var nm: String = TranslationServer.translate(def.name) if def != null else lead
		var count: int = int(model.get("count", 1))
		_put("name", nm + (" ×%d" % count if count > 1 else ""), r.position + Vector2(52.0, 2.0), 0.0)
		var lc: Vector2 = level_center(r)
		_put("level", str(def.level if def != null else 1), lc - Vector2(LEVEL_R, 9.0), LEVEL_R * 2.0,
			HORIZONTAL_ALIGNMENT_CENTER)
		_put("dist", ("%.1f m" % float(model.get("dist_m", 0.0))).replace(".", ","), r.position + Vector2(52.0, 28.0),
			236.0, HORIZONTAL_ALIGNMENT_RIGHT)
		var first: bool = bool(model.get("first", false))
		var st: String = str(model.get("state", ""))
		var line: String = st + (" · " if st != "" else "") + ("Erstschlag!" if first else "kein Erstschlag")
		_put("state", line, r.position + Vector2(52.0, 48.0), 240.0)
		(_labels["state"] as Label).add_theme_color_override("font_color", CombatStyle.C_GOLD if first
			else CombatStyle.C_TEXT_DIM)
		var i: int = 0
		for s: Variant in model.get("slots", []) as Array:
			var slot: int = int((s as Dictionary)["slot"])
			var k: String = key_of(slot)
			var cap: Label = _caps[i]
			i += 1
			if k == "":
				continue
			var cr: Rect2 = chip_rect(slot)
			cap.text = k
			cap.size = Vector2(maxf(12.0, 5.0 + 7.0 * k.length()), 13.0)
			cap.position = cr.position + Vector2(1.0, 0.0)
			cap.visible = true
		if _hint_on():
			_hint.visible = true
			_hint.reset_size()
			var hs: Vector2 = _hint.get_combined_minimum_size()
			_hint.position = Vector2(roundf(r.get_center().x - hs.x * 0.5), below + 4.0)
			_hint.size = hs
			below += hs.y + 8.0
	if _refuse_t > 0.0:
		_put("refuse", _refuse_text, Vector2(r.position.x - 60.0, below), FRAME.x + 120.0, HORIZONTAL_ALIGNMENT_CENTER)
		(_labels["refuse"] as Label).modulate.a = clampf(_refuse_t / 0.3, 0.0, 1.0)


func _put(n: String, text: String, pos: Vector2, w: float, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) \
		-> void:
	var l: Label = _labels[n]
	l.text = UiUtilRef.glyph_safe(text)
	l.visible = text != ""
	l.horizontal_alignment = align
	l.position = pos
	l.size = Vector2(w, 18.0) if w > 0.0 else Vector2.ZERO


## Centre of the level plaque in the frame `r` (top right, where the level stood before 09 ST1-A).
static func level_center(r: Rect2) -> Vector2:
	return r.position + Vector2(FRAME.x - 12.0 - LEVEL_R, 3.0 + LEVEL_R)


# --- drawing ----------------------------------------------------------------------------------------------------------

func _draw() -> void:
	if model.is_empty():
		return
	var m: IconMesh = IconMesh.new()
	_draw_marker(m)
	_draw_frame(m)
	m.commit(self)


## The ring around the feet (a projected circle) and the chevron above the head.
func _draw_marker(m: IconMesh) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null or not model.has("foot"):
		return
	var to_local: Transform2D = get_global_transform_with_canvas().affine_inverse()
	var foot: Vector3 = model["foot"]
	var pts: PackedVector2Array = PackedVector2Array()
	for i in RING_POINTS:
		var a: float = TAU * float(i) / float(RING_POINTS)
		var p: Vector3 = foot + Vector3(cos(a) * RING_M, 0.04, sin(a) * RING_M)
		if cam.is_position_behind(p):
			pts = PackedVector2Array()
			break
		pts.append(to_local * cam.unproject_position(p))
	if pts.size() == RING_POINTS:
		m.poly(pts, Color(CombatStyle.C_CYAN, 0.14))
		m.polyline(pts, Color(CombatStyle.C_CYAN, 0.95), 2.5, true)          # a closed loop
	var head: Vector3 = _chevron_at()
	if cam.is_position_behind(head):
		return
	var c: Vector2 = to_local * cam.unproject_position(head)
	var bob: float = 3.0 * sin(_t * 5.0)
	var col: Color = CombatStyle.C_GOLD if bool(model.get("first", false)) else CombatStyle.C_CYAN
	m.poly(PackedVector2Array([c + Vector2(-9, -6 + bob), c + Vector2(9, -6 + bob), c + Vector2(0, 5 + bob)]),
		CombatStyle.C_INK)
	m.poly(PackedVector2Array([c + Vector2(-7, -5 + bob), c + Vector2(7, -5 + bob), c + Vector2(0, 3 + bob)]), col)


func _draw_frame(m: IconMesh) -> void:
	var r: Rect2 = frame_rect()
	var first: bool = bool(model.get("first", false))
	m.rect(r, CombatStyle.C_PANEL)
	m.rect(Rect2(r.position, Vector2(r.size.x, 2.0)), CombatStyle.C_GOLD if first else CombatStyle.C_ENEMY)
	_lead_symbol(m, Rect2(r.position + Vector2(6.0, 8.0), Vector2(40.0, 40.0)))
	LevelBadge.draw(m, level_center(r), LEVEL_R, CombatStyle.C_GOLD)
	var pad: bool = _scheme() == Game.InputScheme.GAMEPAD
	for s: Variant in model.get("slots", []) as Array:
		var d: Dictionary = s
		var slot: int = int(d["slot"])
		var cr: Rect2 = chip_rect(slot)
		if _shake.has(slot):
			cr.position.x += sin(_t * 70.0) * 4.0 * float(_shake[slot]) / SHAKE_SEC
		var reason: String = str(d.get("reason", ""))
		var dim: bool = reason == "no_opener" or (pad and slot > PAD_SLOTS)
		m.rect(cr, CombatStyle.C_SLOT)
		var border: Color = Color(CombatStyle.C_CYAN, 0.75)
		if dim:
			border = Color(CombatStyle.C_GREY, 0.4)
		elif reason == "range":
			border = CombatStyle.C_DANGER
		elif reason == "mp":
			border = CombatStyle.C_MANA
		elif slot == SLOTS:
			border = CombatStyle.C_GOLD                     # SHOW keeps its gold frame (07 §8.2)
		m.rect_outline(cr.grow(-1.0), border, 2.0)
		var from: int = m.colors.size()
		CombatIcons.draw(m, CombatStyle.skill_icon(CombatView.skill_of(str(d["id"]))), cr.grow(-3.0))
		if dim:
			CombatIcons.recolor(m, from, 0.0, Color(0, 0, 0, 0), 0.4)
		elif reason == "mp":
			CombatIcons.recolor(m, from, 0.85, Color(CombatStyle.C_MANA, 0.5))
		elif reason == "range":
			CombatIcons.recolor(m, from, 0.4, Color(CombatStyle.C_DANGER, 0.6))
		if key_of(slot) != "":
			m.rect(Rect2(cr.position + Vector2(1.0, 1.0), Vector2(maxf(12.0, 5.0 + 7.0 * key_of(slot).length()), 12.0)),
				Color(CombatStyle.C_PAPER, 0.92))


## The lead's symbol: the combat's enemy face (unit_frames.gd), with a gold ring while a pull is a first strike.
func _lead_symbol(m: IconMesh, r: Rect2) -> void:
	var c: Vector2 = r.get_center()
	var s: float = r.size.x
	m.circle(c, s * 0.48, Color(CombatStyle.C_ENEMY, 0.3), true)
	m.circle(c + Vector2(0, s * 0.04), s * 0.32, Color("#3a2a3a"), true)
	m.circle(c + Vector2(-s * 0.26, -s * 0.24), s * 0.12, Color("#3a2a3a"), true)
	m.circle(c + Vector2(s * 0.26, -s * 0.24), s * 0.12, Color("#3a2a3a"), true)
	m.circle(c + Vector2(-s * 0.11, 0.0), s * 0.06, CombatStyle.C_ENEMY, true)
	m.circle(c + Vector2(s * 0.11, 0.0), s * 0.06, CombatStyle.C_ENEMY, true)
	if bool(model.get("first", false)):
		m.ring(c, s * 0.46, CombatStyle.C_GOLD, 2.0, true)
