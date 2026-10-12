extends Control
## Unit frames of the real-time HUD (07 §8.1, §8.3, §8.4), laid out in the safe frame (1280 × 720 reference minus the
## 24 px edge): controlled party frame (24, 96) 240 × 56 with the pill "DU" (06 A; it moves with a control switch),
## partner frame (24, 184) 220 × 48, their status rows (20 px symbols with a radial sweep of the remaining time; the
## seconds only on mouse hover / long press), the Partner-Spezial button right of the partner frame (PC 48 px centred at
## (268, 208), touch 64 / 88 px at (300, 192)), the Taktik-Chip from level 3 (24, 266) 168 × 28 (touch 168 × 36 / 88),
## the target frame top centre (y 24; y 84 in a boss fight when the target is not the boss) 300 × 56 with HP, cast bar,
## sword switch (auto attack) and status row, and the boss frame top centre 520 × 36 with phase diamonds, HP %, enrage
## countdown in the last minute and its 520 × 10 cast bar. Party HP has a trailing red damage piece (0.4 s) and a green
## heal flash. Aggro counter "×2" and nothing else of the threat model before the player's first own taunt (07 §8.1).
## A level is the bare number in the round level plaque (09 §1.2 Nr. 1, CR-32 i; scenes/ui/level_badge.gd drawn into
## the frame like the pull target frame does): top right of the bars, in the target frame left of the sword; on the
## mouse the plaque says "Stufe N".
## Draw calls (07 §8.10 "Rahmen ≈ 10"): every bar, frame, symbol and status sweep = ONE triangle array; the partner
## sweep shares the bar's sweep material; labels without outline. Private R3 script.

signal friendly_target_requested(unit_id: String)
signal partner_special_pressed()
signal tactic_pressed()
signal auto_attack_pressed()

const CombatStyle := preload("res://scenes/combat/ui/combat_style.gd")
const CombatIcons := preload("res://scenes/combat/ui/combat_icons.gd")
const CombatView := preload("res://scenes/combat/ui/combat_view.gd")
const ActionBar := preload("res://scenes/combat/ui/action_bar.gd")
const IconMesh := preload("res://scenes/ui/icon_mesh.gd")
const LevelBadge := preload("res://scenes/ui/level_badge.gd")   # 09 §1.2 (CR-32 i): the level plaque, never "Lv"

const EDGE: float = 24.0                             # safe frame edge: absolute (x, y) of 07 §8.1 minus this
const CTL_RECT: Rect2 = Rect2(0, 72, 240, 56)        # abs (24, 96)
const CTL_STATUS: Vector2 = Vector2(0, 132)          # abs (24, 156)
const PARTNER_RECT: Rect2 = Rect2(0, 160, 220, 48)   # abs (24, 184)
const PARTNER_STATUS: Vector2 = Vector2(0, 212)      # abs (24, 236)
const SPECIAL_PC: Rect2 = Rect2(220, 160, 48, 48)    # centre abs (268, 208)
const SPECIAL_TOUCH_CENTER: Vector2 = Vector2(276, 168)   # abs (300, 192)
const SPECIAL_TOUCH_VIS: float = 64.0
const CHIP_PC: Rect2 = Rect2(0, 242, 168, 28)        # abs (24, 266)
## abs (108, 276), 168 × 34 visible: 8 px below 07 §7.3's (108, 268) so the 88 px hit area (y 232–320) ends at the
## stick zone and starts below the partner frame (y 184–232) instead of overlapping it by 8 px, and the visible chip
## (y 259–293) clears the partner's status row (y 236–258).
const CHIP_TOUCH_CENTER: Vector2 = Vector2(84, 252)
const CHIP_TOUCH: Vector2 = Vector2(168, 34)
const TOUCH_HIT: float = 88.0
const TARGET_W: float = 300.0
const TARGET_H: float = 56.0
const BOSS_W: float = 520.0
const BOSS_MIN_W: float = 400.0                 # R5b: the touch layout's boss frame next to the hype meter …
const BOSS_LEFT_MIN: float = 320.0              # … right of the LIVE / viewers block …
const RESERVE_GAP: float = 38.0                 # … and this far from the meter (room for the target sword)
const BOSS_H: float = 36.0
const STATUS_SIZE: float = 20.0
const STATUS_STEP: float = 22.0
const STATUS_MAX: int = 6
const TRAIL_SEC: float = 0.4
const HEAL_FLASH_SEC: float = 0.35
const LONG_PRESS_SEC: float = 0.45
const PCT_POP_SEC: float = 1.2
## Level plaques (09 §1.2 Nr. 1, CR-32 i): sized for two digits of the 12 px number (LevelBadge.FRAME_RADIUS; the
## smaller partner frame 0.5 px less), flush with the frame's top (the target's: below its colour strip). The bars
## start below them (were 22 / 20 / 24 with "Lv" as text).
const LEVEL_R_CTL: float = LevelBadge.FRAME_RADIUS
const LEVEL_R_PARTNER: float = LevelBadge.FRAME_RADIUS - 0.5
const LEVEL_R_TARGET: float = LevelBadge.FRAME_RADIUS
const CTL_BARS_Y: float = 23.0
const PARTNER_BARS_Y: float = 22.0
const TARGET_BARS_Y: float = 25.0
const TARGET_LEVEL_END: float = 264.0          # right edge of the target's plaque in the frame (the sword from 272)
const PRESETS: Dictionary = {"attack": "Angriff", "support": "Unterstützen", "careful": "Vorsichtig"}

var sim: RtSim = null
## Touch layout (bigger partner button / chip, no key caps).
var touch: bool = false
## Threat display unlocked (first own taunt, 07 §8.1).
var threat_revealed: bool = false
## Key texts of the partner button / chip ("R" / "Links" …, "" = none).
var special_key: String = ""
var chip_key: String = ""
## Status seconds visible for this unit id (long press / hover), "" none.
var seconds_for: String = ""

var _labels: Dictionary = {}                # name → Label
var _hits: Dictionary = {}                  # name → Control (hit boxes)
var _special_sweep: ColorRect
var _trail: Dictionary = {}                 # unit id → {"hp": shown trail hp, "t": seconds since the last drop}
var _heal_flash: Dictionary = {}            # unit id → seconds left
var _last_hp: Dictionary = {}               # unit id → hp last frame
var _pct_pop: Dictionary = {}               # unit id → {"text", "t"}
var _special_shake: float = 0.0
var _press_t: Dictionary = {}               # hit name → seconds held (long press)
var _hover_status: Dictionary = {}          # {"unit", "index"} under the mouse
var _t: float = 0.0
var _model: Dictionary = {}                 # last computed frame model (tests)
## R5b: local x of the hype meter's left edge in the touch layout (combat HUD; ≤ 0 = none) — boss_rect avoids it.
var reserve_right: float = -1.0
var _looks: Dictionary = {}                 # def id → face of the frame symbol (look_of, per combat)
var _looks_sim: RtSim = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_special_sweep = ColorRect.new()
	_special_sweep.name = "SpecialSweep"
	_special_sweep.material = ActionBar.sweep_material()
	_special_sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_special_sweep.visible = false
	add_child(_special_sweep)
	# labels grouped by size / font (one glyph texture per group → few batches)
	for n: String in ["ctl_name", "partner_name", "target_name", "boss_name"]:
		_add_label(n, 15, CombatStyle.C_TEXT, true)
	_add_label("chip_text", 13, CombatStyle.C_TEXT, false)
	for n: String in ["ctl_level", "partner_level", "target_level", "ctl_hp", "partner_hp", "target_pct", "boss_pct",
			"pill_ctl", "pill_partner", "aggro_ctl", "aggro_partner", "special_key", "chip_key", "ctl_ko", "partner_ko",
			"target_cast", "boss_cast", "boss_enrage", "pct_ctl", "pct_partner", "status_more_ctl",
			"status_more_partner"]:
		_add_label(n, 12, CombatStyle.C_TEXT, true)
	for i in STATUS_MAX * 3:
		_add_label("sec%d" % i, 12, CombatStyle.C_PAPER, true)
	for n: String in ["ctl_frame", "partner_frame", "special", "chip", "sword", "target_frame"]:
		var h: Control = RoundHit.new() if n == "special" else FrameHit.new()
		h.name = "Hit_" + n
		h.mouse_filter = Control.MOUSE_FILTER_STOP
		h.visible = false
		h.gui_input.connect(_on_hit_input.bind(n))
		h.mouse_exited.connect(func() -> void: _hover_status = {})
		add_child(h)
		_hits[n] = h


func _add_label(n: String, size_px: int, col: Color, bold: bool) -> void:
	var l: Label = CombatStyle.label("", size_px, col, bold)
	l.name = "L_" + n
	l.visible = false
	add_child(l)
	_labels[n] = l


## Screen rect (canvas) of a hit box: "ctl_frame", "partner_frame", "special", "chip", "sword", "target_frame".
func hit_rect(n: String) -> Rect2:
	var h: Control = _hits.get(n, null) as Control
	return h.get_global_rect() if h != null and h.visible else Rect2()


## The hit area of `n` contains `canvas_pos` (the Partner-Spezial button is round: a circle of the hit size).
func hit_contains(n: String, canvas_pos: Vector2) -> bool:
	var r: Rect2 = hit_rect(n)
	if r.size.x <= 0.0:
		return false
	if n == "special":
		return canvas_pos.distance_to(r.get_center()) <= minf(r.size.x, r.size.y) * 0.5
	return r.has_point(canvas_pos)


## Local rect of the Partner-Spezial visible button (layout of the current input scheme).
func special_rect() -> Rect2:
	if touch:
		return Rect2(SPECIAL_TOUCH_CENTER - Vector2.ONE * SPECIAL_TOUCH_VIS * 0.5, Vector2.ONE * SPECIAL_TOUCH_VIS)
	return SPECIAL_PC


func chip_rect() -> Rect2:
	if touch:
		return Rect2(CHIP_TOUCH_CENTER - CHIP_TOUCH * 0.5, CHIP_TOUCH)
	return CHIP_PC


func target_rect() -> Rect2:
	var y: float = 0.0
	var b: RtUnit = CombatView.boss(sim)
	if b != null and b.hp > 0:
		y = 60.0                                       # abs y 84: below the boss frame
	return Rect2(Vector2((size.x - TARGET_W) * 0.5, y), Vector2(TARGET_W, TARGET_H))


## Local rect of the level plaque in "ctl_frame", "partner_frame" or "target_frame" (09 §1.2 Nr. 1): top right of the
## bars where "Lv" stood (symbol 48 / 40 + 10, bars 176 / 156 wide), in the target frame left of the sword.
func level_rect(n: String) -> Rect2:
	var c: Vector2
	var rad: float = LEVEL_R_TARGET
	match n:
		"ctl_frame":
			rad = LEVEL_R_CTL
			c = CTL_RECT.position + Vector2(48.0 + 10.0 + 176.0 - rad, rad)
		"partner_frame":
			rad = LEVEL_R_PARTNER
			c = PARTNER_RECT.position + Vector2(40.0 + 10.0 + 156.0 - rad, rad)
		_:
			c = target_rect().position + Vector2(TARGET_LEVEL_END - rad, 2.0 + rad)
	return Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2.0)


## Local rect of the aggro counter "×2" of a party frame: on the frame's top edge, left of the level plaque.
func aggro_rect(big: bool) -> Rect2:
	var r: Rect2 = CTL_RECT if big else PARTNER_RECT
	return Rect2(Vector2(level_rect("ctl_frame" if big else "partner_frame").position.x - 28.0, r.position.y - 13.0),
		Vector2(24.0, 16.0))


## The boss frame: BOSS_W centred at the top — R5b: with `reserve_right` (the touch layout's hype meter, local x of
## its left edge) it ends RESERVE_GAP before it, narrower down to BOSS_MIN_W and never left of BOSS_LEFT_MIN (the
## LIVE / viewers block of the ShowOverlay).
func boss_rect() -> Rect2:
	var x: float = (size.x - BOSS_W) * 0.5
	var w: float = BOSS_W
	if reserve_right > 0.0 and x + w > reserve_right - RESERVE_GAP:
		var end: float = reserve_right - RESERVE_GAP
		x = maxf(BOSS_LEFT_MIN, end - BOSS_W)
		w = maxf(BOSS_MIN_W, end - x)
	return Rect2(Vector2(x, 0.0), Vector2(w, BOSS_H))


## Local bottom of everything at the top centre (boss frame + cast bar + name row, target frame + cast name + status
## row): banners start below it (07 §8.1 "Banner unter dem Ziel-/Bossrahmen").
func top_block_bottom() -> float:
	if _model.is_empty():
		return 0.0
	var bottom: float = 0.0
	if _model["boss"] != null:
		bottom = BOSS_H + 10.0 + 14.0                   # 07 §8.3: cast bar 520 × 10 + name 14 px
	var tgt: RtUnit = _model["target"]
	if tgt != null:
		var r: Rect2 = target_rect()
		var casting: bool = not CombatView.cast(sim, tgt).is_empty()
		bottom = maxf(bottom, r.end.y + (16.0 if casting else 3.0) + (18.0 if not tgt.statuses.is_empty() else 0.0))
	return bottom


## Partner button shake (ACTION_REFUSED of the Partner-Spezial).
func refuse_special() -> void:
	_special_shake = 0.2


## Percent hit "−25 %" at a party frame (07 §8.6).
func pop_percent(unit_id: String, pct: int) -> void:
	_pct_pop[unit_id] = {"text": "-%d %%" % pct, "t": PCT_POP_SEC}


## The last frame model (tests): {"ctl", "partner", "target", "boss", "special", "chip", "aggro"} etc.
func model() -> Dictionary:
	return _model


func _process(delta: float) -> void:
	_t += delta
	_special_shake = maxf(0.0, _special_shake - delta)
	for k: Variant in _heal_flash.keys():
		_heal_flash[k] = float(_heal_flash[k]) - delta
		if float(_heal_flash[k]) <= 0.0:
			_heal_flash.erase(k)
	for k: Variant in _pct_pop.keys():
		var d: Dictionary = _pct_pop[k]
		d["t"] = float(d["t"]) - delta
		if float(d["t"]) <= 0.0:
			_pct_pop.erase(k)
	for k: Variant in _trail.keys():
		var tr_d: Dictionary = _trail[k]
		tr_d["t"] = float(tr_d["t"]) + delta
	for n: Variant in _press_t.keys():
		_press_t[n] = float(_press_t[n]) + delta
		if float(_press_t[n]) >= LONG_PRESS_SEC:
			if str(n) == "ctl_frame" or str(n) == "partner_frame" or str(n) == "target_frame":
				seconds_for = _unit_of_hit(str(n))


## Recomputes the frame model from the sim (every frame, called by the HUD) and repositions labels / hit boxes.
func refresh() -> void:
	if sim == null:
		visible = false
		return
	visible = true
	_model = _build_model()
	_layout_labels()
	_layout_hits()
	queue_redraw()


## Frames stay where they are for the whole combat: the big top frame is the hero's unit (RtSetup.controlled_id,
## GameState.hero), the smaller one the partner; after a control switch (07 §2.6) only the pill "DU" moves.
func _build_model() -> Dictionary:
	var ctl: RtUnit = sim.unit(sim.setup.controlled_id) if sim.setup != null else null
	if ctl == null:
		ctl = CombatView.controlled(sim)
	var p: RtUnit = null
	for u: RtUnit in CombatView.party(sim):
		if ctl == null or u.id != ctl.id:
			p = u
			break
	var m: Dictionary = {"ctl": ctl, "partner": p, "special": CombatView.partner_special(sim),
		"chip": CombatView.tactic_visible(sim), "preset": CombatView.partner_preset(sim)}
	var tgt: RtUnit = sim.unit(ctl.target_id) if ctl != null and ctl.target_id != "" else null
	var b: RtUnit = CombatView.boss(sim)
	m["boss"] = b if b != null and b.hp > 0 else null
	m["target"] = tgt if tgt != null and (m["boss"] == null or tgt != m["boss"]) else null
	m["aggro_ctl"] = CombatView.attackers(sim, ctl.id) if ctl != null and threat_revealed else 0
	m["aggro_partner"] = CombatView.attackers(sim, p.id) if p != null and threat_revealed else 0
	for u: RtUnit in [ctl, p]:
		if u == null:
			continue
		var last: int = int(_last_hp.get(u.id, u.hp))
		if u.hp < last:
			var tr_d: Dictionary = _trail.get(u.id, {"hp": last, "t": 0.0})
			if float(tr_d["t"]) >= TRAIL_SEC:
				tr_d["hp"] = last
			tr_d["t"] = 0.0
			_trail[u.id] = tr_d
		elif u.hp > last:
			_heal_flash[u.id] = HEAL_FLASH_SEC
		_last_hp[u.id] = u.hp
	return m


# --- labels / hit boxes ------------------------------------------------------------------------------------------

func _label(n: String) -> Label:
	return _labels[n] as Label


func _put(n: String, text: String, pos: Vector2, w: float = 0.0, col: Color = Color(0, 0, 0, 0),
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var l: Label = _label(n)
	l.visible = text != ""
	l.text = UiUtilRef.glyph_safe(text)
	l.horizontal_alignment = align
	if col.a > 0.0:
		l.add_theme_color_override("font_color", col)
	l.position = pos
	if w > 0.0:
		l.size = Vector2(w, 18)
	else:
		l.size = Vector2.ZERO


## The bare number of a level plaque, centred in the plaque's rect `pr` (the plaque itself is drawn in _draw).
func _put_level(n: String, level: int, pr: Rect2, col: Color) -> void:
	_put(n, str(level), Vector2(pr.position.x, pr.get_center().y - 9.0), pr.size.x, col, HORIZONTAL_ALIGNMENT_CENTER)


## The plaque in gold, grey while its unit is K.O. (like the name).
static func _level_color(u: RtUnit) -> Color:
	return CombatStyle.C_GOLD if u.hp > 0 else CombatStyle.C_GREY


func _layout_labels() -> void:
	for l: Variant in _labels.values():
		(l as Label).visible = false
	var ctl: RtUnit = _model["ctl"]
	var p: RtUnit = _model["partner"]
	if ctl != null:
		_party_labels(ctl, "ctl", CTL_RECT, 176.0, true)
	if p != null:
		_party_labels(p, "partner", PARTNER_RECT, 156.0, false)
	var sp: Dictionary = _model["special"]
	if not sp.is_empty():
		var r: Rect2 = special_rect()
		if special_key != "" and not touch:
			_put("special_key", special_key, r.position + Vector2(2, 1), 0.0, CombatStyle.C_INK)
	if bool(_model["chip"]):
		var cr: Rect2 = chip_rect()
		var preset: String = str((_model["preset"] as Dictionary).get("preset", "support"))
		_put("chip_text", "Taktik: %s" % str(PRESETS.get(preset, preset)), cr.position + Vector2(10, (cr.size.y - 20) * 0.5),
			0.0, CombatStyle.C_TEXT)
		if chip_key != "" and not touch:
			_put("chip_key", chip_key, Vector2(cr.end.x - 24, cr.position.y + (cr.size.y - 16) * 0.5), 0.0,
				CombatStyle.C_INK)
	var tgt: RtUnit = _model["target"]
	if tgt != null:
		_target_labels(tgt)
	var b: RtUnit = _model["boss"]
	if b != null:
		_boss_labels(b)
	_status_seconds()


func _party_labels(u: RtUnit, key: String, r: Rect2, bar_w: float, big: bool) -> void:
	var sym: float = 48.0 if big else 40.0
	var x: float = r.position.x + sym + 10.0
	var name_x: float = x
	if u.id == sim.controlled_id():
		_put("pill_" + key, "DU", Vector2(x + 3.0, r.position.y + 3.0), 0.0, CombatStyle.C_INK)
		name_x += 30.0
	_put(key + "_name", CombatStyle.unit_name(u), Vector2(name_x, r.position.y + 1.0), 0.0,
		CombatStyle.C_TEXT if u.hp > 0 else CombatStyle.C_GREY)
	_put_level(key + "_level", u.level, level_rect(key + "_frame"), _level_color(u))
	var hp_y: float = r.position.y + (CTL_BARS_Y if big else PARTNER_BARS_Y)
	if u.hp > 0:
		_put(key + "_hp", "%d/%d" % [u.hp, u.max_hp()], Vector2(x, hp_y - (1.0 if big else 2.0)), bar_w - 4.0,
			CombatStyle.C_PAPER, HORIZONTAL_ALIGNMENT_RIGHT)
	else:
		_put(key + "_ko", "K.O.", Vector2(x + 4.0, hp_y - 2.0), 0.0, CombatStyle.C_DANGER)
	var aggro: int = int(_model["aggro_" + key])
	if aggro > 0:
		_put("aggro_" + key, "×%d" % aggro, aggro_rect(big).position, 24.0, CombatStyle.C_PAPER,
			HORIZONTAL_ALIGNMENT_CENTER)
	if _pct_pop.has(u.id):
		var d: Dictionary = _pct_pop[u.id]
		var l: String = "pct_" + key
		_put(l, str(d["text"]), Vector2(r.end.x + (56.0 if not big else 6.0), r.position.y + 18.0), 0.0,
			CombatStyle.C_DANGER)
		_label(l).modulate.a = clampf(float(d["t"]) / 0.3, 0.0, 1.0)
	var sts: Array[Dictionary] = CombatView.statuses(sim, u)
	if sts.size() > STATUS_MAX:
		var row: Vector2 = CTL_STATUS if key == "ctl" else PARTNER_STATUS
		_put("status_more_" + key, "+%d" % (sts.size() - STATUS_MAX), row + Vector2(STATUS_STEP * STATUS_MAX, 3.0))


func _target_labels(t: RtUnit) -> void:
	var r: Rect2 = target_rect()
	var col: Color = CombatStyle.C_TEXT if t.side == Combatant.Side.ENEMY else CombatStyle.C_PARTY.lightened(0.3)
	var nx: float = r.position.x + 52.0 + (14.0 if _is_marked(t) else 0.0)
	_put("target_name", CombatStyle.unit_name(t, sim.units()), Vector2(nx, r.position.y + 2.0), 0.0, col)
	_put_level("target_level", t.level, level_rect("target_frame"), _level_color(t))
	_put("target_pct", "%d %%" % _pct(t), r.position + Vector2(52.0, TARGET_BARS_Y - 3.0), 236.0, CombatStyle.C_PAPER,
		HORIZONTAL_ALIGNMENT_RIGHT)
	var c: Dictionary = CombatView.cast(sim, t)
	if not c.is_empty():
		_put("target_cast", "%s  %s s" % [str(c["name"]), CombatStyle.secs(int(c["left"]))],
			Vector2(r.position.x + 52.0, r.end.y + 1.0), 0.0, _cast_text_color(c))


func _boss_labels(b: RtUnit) -> void:
	var r: Rect2 = boss_rect()
	_put("boss_name", CombatStyle.unit_name(b), r.position + Vector2(8.0, 0.0), 0.0, CombatStyle.C_TEXT)
	_put("boss_pct", "%d %%" % _pct(b), r.position + Vector2(0.0, 1.0), r.size.x - 8.0, CombatStyle.C_PAPER,
		HORIZONTAL_ALIGNMENT_RIGHT)
	var left: int = CombatView.enrage_left(sim, b)
	if left > 0 and left <= 60 * 30:
		_put("boss_enrage", "%s in %s" % [_enrage_word(b), CombatStyle.clock(left)],
			r.position + Vector2(0.0, BOSS_H + 9.0), r.size.x - 4.0, CombatStyle.C_DANGER, HORIZONTAL_ALIGNMENT_RIGHT)
	var c: Dictionary = CombatView.cast(sim, b)
	if not c.is_empty():
		_put("boss_cast", "%s  %s s" % [str(c["name"]), CombatStyle.secs(int(c["left"]))],
			r.position + Vector2(4.0, BOSS_H + 9.0), 0.0, _cast_text_color(c))


static func _enrage_word(b: RtUnit) -> String:
	match b.def_id:
		"enm_boss_hausmeister":
			return "Feierabend"
		"enm_boss_rattenkoenigin":
			return "Betriebsschluss"
	return "Schluss mit lustig"


static func _cast_text_color(c: Dictionary) -> Color:
	match c["tier"] as StringName:
		&"worthy":
			return CombatStyle.C_GOLD
		&"locked":
			return CombatStyle.C_TEXT_DIM
	return CombatStyle.C_PAPER


static func _pct(u: RtUnit) -> int:
	var mx: int = maxi(1, u.max_hp())
	return clampi(ceili(100.0 * float(u.hp) / float(mx)), 0, 100) if u.hp > 0 else 0


static func _is_marked(u: RtUnit) -> bool:
	if u.is_boss:
		return true
	return CombatStyle.gd().has_id("enemies", u.def_id) and CombatStyle.gd().enemy(u.def_id).tags.has("elite")


func _status_seconds() -> void:
	var idx: int = 0
	for spec: Array in [["ctl", CTL_STATUS], ["partner", PARTNER_STATUS]]:
		var u: RtUnit = _model[str(spec[0])]
		if u == null:
			continue
		var show_all: bool = seconds_for == u.id
		var hov: int = int(_hover_status.get("index", -1)) if str(_hover_status.get("unit", "")) == u.id else -1
		var sts: Array[Dictionary] = CombatView.statuses(sim, u)
		for i in mini(sts.size(), STATUS_MAX):
			if not show_all and i != hov:
				continue
			var left: int = int(sts[i]["left"])
			if left < 0 or idx >= STATUS_MAX * 3:
				continue
			var pos: Vector2 = (spec[1] as Vector2) + Vector2(STATUS_STEP * i, STATUS_SIZE + 1.0)
			_put("sec%d" % idx, CombatStyle.secs(left), pos, STATUS_SIZE, CombatStyle.C_PAPER, HORIZONTAL_ALIGNMENT_CENTER)
			idx += 1


func _layout_hits() -> void:
	var ctl: RtUnit = _model["ctl"]
	var p: RtUnit = _model["partner"]
	_place_hit("ctl_frame", CTL_RECT, ctl != null)
	_place_hit("partner_frame", PARTNER_RECT, p != null)
	var sp: Dictionary = _model["special"]
	var sr: Rect2 = special_rect()
	if touch:
		sr = Rect2(sr.get_center() - Vector2.ONE * TOUCH_HIT * 0.5, Vector2.ONE * TOUCH_HIT)
	_place_hit("special", sr, not sp.is_empty())
	var cr: Rect2 = chip_rect()
	if touch:
		cr = Rect2(Vector2(cr.position.x, cr.get_center().y - TOUCH_HIT * 0.5), Vector2(cr.size.x, TOUCH_HIT))
	_place_hit("chip", cr, bool(_model["chip"]))
	var tgt: RtUnit = _model["target"]
	var b: RtUnit = _model["boss"]
	var tr_r: Rect2 = target_rect()
	_place_hit("target_frame", tr_r, tgt != null)
	for spec: Array in [["ctl_frame", ctl], ["partner_frame", p], ["target_frame", tgt]]:
		var u: RtUnit = spec[1] as RtUnit
		var fh: FrameHit = _hits[str(spec[0])] as FrameHit
		var pr: Rect2 = level_rect(str(spec[0]))
		fh.tip = LevelBadge.tooltip(u.level) if u != null else ""
		fh.tip_rect = Rect2(pr.position - fh.position, pr.size)
	var sword: Rect2 = Rect2(tr_r.end.x - 28.0, tr_r.position.y + 2.0, 24.0, 20.0).grow(4.0)
	_place_hit("sword", sword, tgt != null and tgt.side == Combatant.Side.ENEMY or (tgt == null and b != null))
	if tgt == null and b != null:
		var br: Rect2 = boss_rect()
		_place_hit("sword", Rect2(br.end.x + 6.0, br.position.y + 6.0, 24.0, 24.0).grow(4.0), true)
	_special_sweep.visible = not sp.is_empty()
	if not sp.is_empty():
		var vr: Rect2 = special_rect()
		_special_sweep.position = vr.position
		_special_sweep.size = vr.size
		_special_sweep.set_instance_shader_parameter(&"cd_left", CombatView.ratio(int(sp["cd_left"]),
			int(sp["cd_total"])))
		_special_sweep.set_instance_shader_parameter(&"gcd_left", 0.0)


func _place_hit(n: String, r: Rect2, on: bool) -> void:
	var h: Control = _hits[n]
	h.visible = on
	h.position = r.position
	h.size = r.size


func _unit_of_hit(n: String) -> String:
	match n:
		"ctl_frame":
			var c: RtUnit = _model.get("ctl", null) as RtUnit
			return c.id if c != null else ""
		"partner_frame":
			var p: RtUnit = _model.get("partner", null) as RtUnit
			return p.id if p != null else ""
		"target_frame":
			var t: RtUnit = _model.get("target", null) as RtUnit
			return t.id if t != null else ""
	return ""


func _on_hit_input(event: InputEvent, n: String) -> void:
	if event is InputEventMouseMotion:
		_hover_status = _status_under(n, (event as InputEventMouseMotion).position + (_hits[n] as Control).position)
		return
	var pressed: bool = false
	var released: bool = false
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		pressed = mb.pressed
		released = not mb.pressed
	elif event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
		released = not pressed
	else:
		return
	accept_event()
	if pressed:
		_press_t[n] = 0.0
		return
	if not released:
		return
	var held: float = float(_press_t.get(n, 0.0))
	_press_t.erase(n)
	if seconds_for != "" and held >= LONG_PRESS_SEC:
		seconds_for = ""                                 # a long press only shows the seconds (07 §7.3)
		return
	match n:
		"ctl_frame", "partner_frame":
			var uid: String = _unit_of_hit(n)
			if uid != "":
				friendly_target_requested.emit(uid)
		"special":
			partner_special_pressed.emit()
		"chip":
			tactic_pressed.emit()
		"sword":
			auto_attack_pressed.emit()


## Status index under a local point of the frames ({} if none).
func _status_under(_n: String, local: Vector2) -> Dictionary:
	for spec: Array in [["ctl", CTL_STATUS], ["partner", PARTNER_STATUS]]:
		var u: RtUnit = _model.get(str(spec[0]), null) as RtUnit
		if u == null:
			continue
		var row: Vector2 = spec[1]
		var n: int = mini(CombatView.statuses(sim, u).size(), STATUS_MAX)
		for i in n:
			if Rect2(row + Vector2(STATUS_STEP * i, 0), Vector2.ONE * STATUS_SIZE).grow(2.0).has_point(local):
				return {"unit": u.id, "index": i}
	return {}


# --- drawing -------------------------------------------------------------------------------------------------------

func _draw() -> void:
	if sim == null or _model.is_empty():
		return
	var m: IconMesh = IconMesh.new()
	var ctl: RtUnit = _model["ctl"]
	var p: RtUnit = _model["partner"]
	if ctl != null:
		_draw_party(m, ctl, CTL_RECT, 176.0, 14.0, 8.0, true)
		_draw_status_row(m, ctl, CTL_STATUS)
	if p != null:
		_draw_party(m, p, PARTNER_RECT, 156.0, 12.0, 6.0, false)
		_draw_status_row(m, p, PARTNER_STATUS)
	var sp: Dictionary = _model["special"]
	if not sp.is_empty():
		_draw_special(m, sp)
	if bool(_model["chip"]):
		_draw_chip(m)
	var b: RtUnit = _model["boss"]
	if b != null:
		_draw_boss(m, b)
	var tgt: RtUnit = _model["target"]
	if tgt != null:
		_draw_target(m, tgt)
	m.commit(self)


func _draw_party(m: IconMesh, u: RtUnit, r: Rect2, bar_w: float, hp_h: float, mp_h: float, big: bool) -> void:
	var ko: bool = u.hp <= 0
	var col: Color = CombatStyle.member_color(u.def_id)
	m.rect(r, CombatStyle.C_PANEL)
	m.rect(Rect2(r.position, Vector2(4.0, r.size.y)), col if not ko else CombatStyle.C_GREY)
	var controlled: bool = u.id == sim.controlled_id()
	if controlled:
		m.rect_outline(r, Color(CombatStyle.C_GOLD, 0.8), 2.0)
	var sym: float = 48.0 if big else 40.0
	var sr: Rect2 = Rect2(r.position + Vector2(6.0, (r.size.y - sym) * 0.5), Vector2(sym, sym))
	_member_symbol(m, u.def_id, sr, ko)
	var x: float = r.position.x + sym + 10.0
	if controlled:                                     # pill "DU" (06 A), moves with a control switch
		m.rect(Rect2(Vector2(x, r.position.y + 4.0), Vector2(26.0, 15.0)), CombatStyle.C_GOLD)
	var lr: Rect2 = level_rect("ctl_frame" if big else "partner_frame")
	LevelBadge.draw(m, lr.get_center(), lr.size.x * 0.5, _level_color(u))
	var hp_y: float = r.position.y + (CTL_BARS_Y if big else PARTNER_BARS_Y)
	var hp_r: Rect2 = Rect2(Vector2(x, hp_y), Vector2(bar_w, hp_h))
	var ratio: float = clampf(float(u.hp) / float(maxi(1, u.max_hp())), 0.0, 1.0)
	m.rect(hp_r, Color(0, 0, 0, 0.55))
	var tr_d: Dictionary = _trail.get(u.id, {})
	if not tr_d.is_empty() and float(tr_d["t"]) < TRAIL_SEC:
		var tr_ratio: float = clampf(float(tr_d["hp"]) / float(maxi(1, u.max_hp())), 0.0, 1.0)
		var shrink: float = lerpf(tr_ratio, ratio, clampf(float(tr_d["t"]) / TRAIL_SEC, 0.0, 1.0))
		m.rect(Rect2(hp_r.position, Vector2(bar_w * shrink, hp_h)), CombatStyle.C_TRAIL)
	var hp_col: Color = CombatStyle.C_PARTY if ratio >= 0.25 else CombatStyle.C_HP_LOW
	if _heal_flash.has(u.id):
		hp_col = hp_col.lerp(CombatStyle.C_HEAL, float(_heal_flash[u.id]) / HEAL_FLASH_SEC)
	if ko:
		hp_col = CombatStyle.C_GREY
	m.rect(Rect2(hp_r.position, Vector2(bar_w * ratio, hp_h)), hp_col)
	var mp_r: Rect2 = Rect2(Vector2(x, hp_r.end.y + 3.0), Vector2(bar_w, mp_h))
	m.rect(mp_r, Color(0, 0, 0, 0.55))
	var mp_ratio: float = clampf(float(u.mp) / float(maxi(1, u.max_mp())), 0.0, 1.0)
	m.rect(Rect2(mp_r.position, Vector2(bar_w * mp_ratio, mp_h)), CombatStyle.C_MANA if not ko else CombatStyle.C_GREY)
	var key: String = "ctl" if big else "partner"
	if int(_model.get("aggro_" + key, 0)) > 0:
		m.rect(aggro_rect(big), CombatStyle.C_DANGER)


## Static member symbols (no SubViewport portraits in the combat HUD, 07 §8.4): Kai's head drawn from the running
## persona's look (R5b, 08 §6: skin, hair colour and style, beard, glasses — DB.party_model, the canon look without a
## persona), Graf Mopsula's pug face with monocle (no crown motif, 06 §3.2).
func _member_symbol(m: IconMesh, def_id: String, r: Rect2, ko: bool) -> void:
	var c: Vector2 = r.get_center()
	var s: float = r.size.x
	var from: int = m.colors.size()
	m.circle(c, s * 0.48, Color(CombatStyle.member_color(def_id), 0.35), true)
	if def_id == DB.LOOK_MEMBER:
		face_symbol(m, r, look_of(def_id))
	elif def_id == "mopsula":
		m.circle(c + Vector2(0, s * 0.04), s * 0.34, Color("#d9b48a"), true)
		m.circle(c + Vector2(-s * 0.3, -s * 0.18), s * 0.12, Color("#3a2a20"), true)
		m.circle(c + Vector2(s * 0.3, -s * 0.18), s * 0.12, Color("#3a2a20"), true)
		m.circle(c + Vector2(0, s * 0.16), s * 0.17, Color("#3a2a20"), true)
		m.circle(c + Vector2(-s * 0.12, -s * 0.02), s * 0.05, CombatStyle.C_INK, true)
		m.circle(c + Vector2(s * 0.12, -s * 0.02), s * 0.05, CombatStyle.C_INK, true)
		m.ring(c + Vector2(s * 0.12, -s * 0.02), s * 0.09, CombatStyle.C_GOLD, maxf(1.5, s * 0.03), true)
	else:
		m.circle(c + Vector2(0, s * 0.06), s * 0.3, Color("#f2c9a0"), true)
		var hair: PackedVector2Array = PackedVector2Array()
		for i in 7:
			var a: float = PI + PI * float(i) / 6.0
			var rr: float = s * (0.42 if i % 2 == 0 else 0.3)
			hair.append(c + Vector2(cos(a) * rr, sin(a) * rr * 0.9 - s * 0.02))
		hair.append(c + Vector2(s * 0.3, s * 0.0))
		hair.append(c + Vector2(-s * 0.3, s * 0.0))
		m.poly(hair, Color("#6b3b22"))
		m.circle(c + Vector2(-s * 0.1, s * 0.06), s * 0.04, CombatStyle.C_INK, true)
		m.circle(c + Vector2(s * 0.1, s * 0.06), s * 0.04, CombatStyle.C_INK, true)
	if ko:
		CombatIcons.recolor(m, from, 1.0, Color(0, 0, 0, 0), 0.55)


## The face of `def_id`'s model for the frame symbol (R5b): {"skin", "hair", "style", "beard", "glasses"} from
## DB.party_model (the persona's look on Kai; party.json without one). Cached per combat (the look never changes in
## a combat).
func look_of(def_id: String) -> Dictionary:
	if _looks_sim != sim:
		_looks.clear()
		_looks_sim = sim
	if _looks.has(def_id):
		return _looks[def_id]
	var model: Dictionary = DB.party_model(def_id)
	var colors: Dictionary = model.get("colors", {}) if model.get("colors", {}) is Dictionary else {}
	var style: Dictionary = model.get("style", {}) if model.get("style", {}) is Dictionary else {}
	var props: Array = Array(model.get("props", []))
	var out: Dictionary = {"skin": CombatStyle.hex(str(colors.get("skin", "")), Color("#f2c9a0")),
		"hair": CombatStyle.hex(str(colors.get("accent", "")), Color("#6b3b22")),
		"style": str(style.get("hair", PersonaLook.DEFAULT_HAIR)), "beard": str(style.get("beard",
		PersonaLook.DEFAULT_BEARD)), "glasses": props.has(PersonaLook.GLASSES_PROP)}
	_looks[def_id] = out
	return out


## A head of `look` in `r` (frame symbols): face in the skin tone, the hair style in the hair colour (short spiky,
## buzz, long, bun, curls, ponytail, braids, headscarf), stubble / moustache / full beard, round glasses.
static func face_symbol(m: IconMesh, r: Rect2, look: Dictionary) -> void:
	var c: Vector2 = r.get_center()
	var s: float = r.size.x
	var skin: Color = look.get("skin", Color("#f2c9a0"))
	var hair: Color = look.get("hair", Color("#6b3b22"))
	var hs: String = str(look.get("style", "short"))
	if hs == "long" or hs == "braids":                       # behind the face
		m.rect(Rect2(c + Vector2(-s * 0.36, -s * 0.12), Vector2(s * 0.72, s * (0.44 if hs == "long" else 0.1))), hair)
	if hs == "ponytail":
		m.poly(PackedVector2Array([c + Vector2(s * 0.22, -s * 0.2), c + Vector2(s * 0.46, -s * 0.06),
			c + Vector2(s * 0.42, s * 0.3), c + Vector2(s * 0.3, s * 0.08)]), hair)
	if hs == "bun":
		m.circle(c + Vector2(0, -s * 0.38), s * 0.13, hair, true)
	m.circle(c + Vector2(0, s * 0.06), s * 0.3, skin, true)
	match hs:
		"buzz":
			m.poly(_cap(c, s, 0.31, 0.0), Color(hair, 0.85))
		"curls":
			for i in 7:
				var a: float = PI + PI * float(i) / 6.0
				m.circle(c + Vector2(cos(a) * s * 0.3, sin(a) * s * 0.27 - s * 0.02), s * 0.1, hair, true)
		"headscarf":
			m.poly(_cap(c, s, 0.37, 0.1), hair)
			m.circle(c + Vector2(s * 0.3, s * 0.12), s * 0.07, hair, true)
		"braids":
			m.poly(_cap(c, s, 0.33, 0.02), hair)
			for side: float in [-1.0, 1.0]:
				for k in 3:
					m.circle(c + Vector2(side * s * 0.33, s * (0.0 + 0.12 * k)), s * 0.06, hair, true)
		"short":
			var spikes: PackedVector2Array = PackedVector2Array()
			for i in 7:
				var a2: float = PI + PI * float(i) / 6.0
				var rr: float = s * (0.42 if i % 2 == 0 else 0.3)
				spikes.append(c + Vector2(cos(a2) * rr, sin(a2) * rr * 0.9 - s * 0.02))
			spikes.append(c + Vector2(s * 0.3, s * 0.0))
			spikes.append(c + Vector2(-s * 0.3, s * 0.0))
			m.poly(spikes, hair)
		_:                                                  # long, bun, ponytail: a smooth cap
			m.poly(_cap(c, s, 0.33, 0.02), hair)
	match str(look.get("beard", "none")):
		"stubble":
			m.poly(_chin(c, s), Color(hair, 0.35))
		"moustache":
			m.rect(Rect2(c + Vector2(-s * 0.12, s * 0.16), Vector2(s * 0.24, s * 0.05)), hair)
		"full":
			m.poly(_chin(c, s), hair)
	m.circle(c + Vector2(-s * 0.1, s * 0.06), s * 0.04, CombatStyle.C_INK, true)
	m.circle(c + Vector2(s * 0.1, s * 0.06), s * 0.04, CombatStyle.C_INK, true)
	if bool(look.get("glasses", false)):
		m.ring(c + Vector2(-s * 0.1, s * 0.06), s * 0.08, CombatStyle.C_INK, maxf(1.2, s * 0.025), true)
		m.ring(c + Vector2(s * 0.1, s * 0.06), s * 0.08, CombatStyle.C_INK, maxf(1.2, s * 0.025), true)
		m.line(c + Vector2(-s * 0.02, s * 0.06), c + Vector2(s * 0.02, s * 0.06), CombatStyle.C_INK, maxf(1.2, s * 0.025))


## The top half-ellipse of a hair cap: radius `rk` × size, its lower edge `drop` × size below the centre line.
static func _cap(c: Vector2, s: float, rk: float, drop: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i in 9:
		var a: float = PI + PI * float(i) / 8.0
		out.append(c + Vector2(cos(a) * s * rk, sin(a) * s * rk * 0.95 + s * drop))
	return out


## The lower face (beard): from cheek to cheek under the mouth line.
static func _chin(c: Vector2, s: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i in 9:
		var a: float = PI * float(i) / 8.0
		out.append(c + Vector2(cos(a) * s * 0.29, s * 0.12 + sin(a) * s * 0.24))
	return out


func _draw_status_row(m: IconMesh, u: RtUnit, row: Vector2) -> void:
	var sts: Array[Dictionary] = CombatView.statuses(sim, u)
	for i in mini(sts.size(), STATUS_MAX):
		var st: Dictionary = sts[i]
		var r: Rect2 = Rect2(row + Vector2(STATUS_STEP * i, 0.0), Vector2.ONE * STATUS_SIZE)
		m.rect(r.grow(1.0), Color(CombatStyle.C_INK, 0.85))
		CombatIcons.draw(m, str(st["icon"]), r.grow(-2.0), st["color"] as Color)
		var left: int = int(st["left"])
		var total: int = int(st["total"])
		if left >= 0 and total > 0:
			_pie(m, r.get_center(), STATUS_SIZE * 0.62, 1.0 - clampf(float(left) / float(total), 0.0, 1.0),
				Color(0.03, 0.02, 0.05, 0.6))
		if int(st["stacks"]) > 1:
			for k in mini(int(st["stacks"]), 5):
				m.rect(Rect2(r.end + Vector2(-3.0 - 3.5 * k, -3.0), Vector2(2.5, 2.5)), CombatStyle.C_PAPER)
		if bool(st["buff"]):
			m.rect(Rect2(Vector2(r.position.x, r.end.y + 1.0), Vector2(r.size.x, 1.5)), Color(CombatStyle.C_HEAL, 0.8))
		else:
			m.rect(Rect2(Vector2(r.position.x, r.end.y + 1.0), Vector2(r.size.x, 1.5)), Color(CombatStyle.C_DANGER, 0.8))


## Elapsed part of a radial sweep: clockwise from 12 o'clock over `frac` of the circle.
static func _pie(m: IconMesh, c: Vector2, r: float, frac: float, col: Color) -> void:
	if frac <= 0.001:
		return
	var pts: PackedVector2Array = PackedVector2Array([c])
	var steps: int = maxi(2, int(ceil(24.0 * frac)))
	for i in steps + 1:
		var a: float = -PI * 0.5 + TAU * frac * float(i) / float(steps)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	m.poly(pts, col)


func _draw_special(m: IconMesh, sp: Dictionary) -> void:
	var r: Rect2 = special_rect()
	if _special_shake > 0.0:
		r.position.x += sin(_t * 70.0) * 4.0 * (_special_shake / 0.2)
	var ko: bool = bool(sp.get("ko", false))
	var ready: bool = int(sp["cd_left"]) <= 0 and str(sp["reason"]) == ""
	if touch:
		m.circle(r.get_center(), r.size.x * 0.5, Color(CombatStyle.C_PANEL_SOLID, 0.92), true)
		m.ring(r.get_center(), r.size.x * 0.5 - 1.5, CombatStyle.C_CYAN if ready else Color(CombatStyle.C_CYAN, 0.4), 3.0,
			true)
	else:
		m.rect(r, CombatStyle.C_SLOT)
		m.rect_outline(r.grow(-1.0), CombatStyle.C_CYAN if ready else Color(CombatStyle.C_CYAN, 0.4), 2.0)
	var isz: float = r.size.x * 0.66
	var from: int = m.colors.size()
	CombatIcons.draw(m, str(sp["icon"]), Rect2(r.get_center() - Vector2.ONE * isz * 0.5, Vector2.ONE * isz))
	if ko or str(sp["reason"]) == "mp":
		CombatIcons.recolor(m, from, 0.85, Color(CombatStyle.C_MANA, 0.4) if not ko else Color(0, 0, 0, 0),
			0.5 if ko else 1.0)
	if special_key != "" and not touch:
		m.rect(Rect2(r.position + Vector2(2, 2), Vector2(maxf(14.0, 8.0 + 7.0 * special_key.length()), 14.0)),
			Color(CombatStyle.C_PAPER, 0.92))


func _draw_chip(m: IconMesh) -> void:
	var r: Rect2 = chip_rect()
	var pts: PackedVector2Array = PackedVector2Array([r.position + Vector2(6, 0), Vector2(r.end.x, r.position.y),
		r.end - Vector2(6, 0), Vector2(r.position.x, r.end.y)])
	m.poly(pts, CombatStyle.C_PANEL_SOLID)
	m.rect(Rect2(r.position + Vector2(6, 0), Vector2(r.size.x - 6, 2)), CombatStyle.C_CYAN)
	if chip_key != "" and not touch:
		m.rect(Rect2(Vector2(r.end.x - 26.0, r.position.y + (r.size.y - 16.0) * 0.5), Vector2(16, 16)),
			Color(CombatStyle.C_PAPER, 0.92))


func _draw_target(m: IconMesh, t: RtUnit) -> void:
	var r: Rect2 = target_rect()
	var enemy: bool = t.side == Combatant.Side.ENEMY
	m.rect(r, CombatStyle.C_PANEL)
	m.rect(Rect2(r.position, Vector2(r.size.x, 2.0)), CombatStyle.C_ENEMY if enemy else CombatStyle.C_PARTY)
	var sr: Rect2 = Rect2(r.position + Vector2(6.0, 8.0), Vector2(40.0, 40.0))
	if enemy:
		_enemy_symbol(m, t, sr)
	else:
		_member_symbol(m, t.def_id, sr, t.hp <= 0)
	if _is_marked(t):
		_diamond(m, Vector2(r.position.x + 58.0, r.position.y + 11.0), 6.0, CombatStyle.C_GOLD)
	var lr: Rect2 = level_rect("target_frame")
	LevelBadge.draw(m, lr.get_center(), lr.size.x * 0.5, _level_color(t))
	var hp_r: Rect2 = Rect2(r.position + Vector2(52.0, TARGET_BARS_Y), Vector2(240.0, 12.0))
	m.rect(hp_r, Color(0, 0, 0, 0.55))
	var ratio: float = clampf(float(t.hp) / float(maxi(1, t.max_hp())), 0.0, 1.0)
	m.rect(Rect2(hp_r.position, Vector2(hp_r.size.x * ratio, 12.0)), CombatStyle.C_ENEMY if enemy else CombatStyle.C_PARTY)
	var c: Dictionary = CombatView.cast(sim, t)
	_cast_bar(m, Rect2(r.position + Vector2(52.0, TARGET_BARS_Y + 18.0), Vector2(240.0, 8.0)), c)
	if enemy:
		_sword(m, Rect2(r.end.x - 28.0, r.position.y + 2.0, 24.0, 20.0))
	var sts: Array[Dictionary] = CombatView.statuses(sim, t)
	var row_y: float = r.end.y + (16.0 if not c.is_empty() else 3.0)
	for i in mini(sts.size(), STATUS_MAX):
		var st: Dictionary = sts[i]
		var sr2: Rect2 = Rect2(Vector2(r.position.x + 52.0 + 20.0 * i, row_y), Vector2(18.0, 18.0))
		m.rect(sr2.grow(1.0), Color(CombatStyle.C_INK, 0.85))
		CombatIcons.draw(m, str(st["icon"]), sr2.grow(-2.0), st["color"] as Color)
		if int(st["left"]) >= 0 and int(st["total"]) > 0:
			_pie(m, sr2.get_center(), 11.0, 1.0 - clampf(float(st["left"]) / float(st["total"]), 0.0, 1.0),
				Color(0.03, 0.02, 0.05, 0.6))


## Auto-attack switch: a sword, grey and crossed out while auto attack is off (07 §7.1).
func _sword(m: IconMesh, r: Rect2) -> void:
	var ctl: RtUnit = _model["ctl"]
	var on: bool = ctl == null or ctl.auto_on
	var col: Color = CombatStyle.C_PAPER if on else CombatStyle.C_GREY
	var a: Vector2 = r.position + Vector2(4, r.size.y - 3)
	var b: Vector2 = r.position + Vector2(r.size.x - 3, 3)
	m.line(a, b, col, 3.0, true)
	var mid: Vector2 = a.lerp(b, 0.28)
	var n: Vector2 = (b - a).normalized().orthogonal() * 6.0
	m.line(mid + n, mid - n, col, 3.0, true)
	if not on:
		m.line(r.position + Vector2(2, 2), r.end - Vector2(2, 2), CombatStyle.C_DANGER, 2.5, true)


func _enemy_symbol(m: IconMesh, t: RtUnit, r: Rect2) -> void:
	var c: Vector2 = r.get_center()
	var s: float = r.size.x
	m.circle(c, s * 0.48, Color(CombatStyle.C_ENEMY, 0.3), true)
	m.circle(c + Vector2(0, s * 0.04), s * 0.32, Color("#3a2a3a"), true)
	m.circle(c + Vector2(-s * 0.26, -s * 0.24), s * 0.12, Color("#3a2a3a"), true)
	m.circle(c + Vector2(s * 0.26, -s * 0.24), s * 0.12, Color("#3a2a3a"), true)
	m.circle(c + Vector2(-s * 0.11, 0.0), s * 0.06, CombatStyle.C_ENEMY, true)
	m.circle(c + Vector2(s * 0.11, 0.0), s * 0.06, CombatStyle.C_ENEMY, true)
	if t.is_boss:
		m.ring(c, s * 0.46, CombatStyle.C_GOLD, 2.0, true)


func _draw_boss(m: IconMesh, b: RtUnit) -> void:
	var r: Rect2 = boss_rect()
	m.rect(r.grow_individual(0, 0, 0, 0), CombatStyle.C_PANEL)
	m.rect(Rect2(r.position, Vector2(r.size.x, 2.0)), CombatStyle.C_GOLD)
	var ph: Vector2i = CombatView.boss_phases(b)
	var name_w: float = float(CombatStyle.unit_name(b).length()) * 8.5 + 22.0
	for i in ph.y:
		_diamond(m, r.position + Vector2(name_w + 14.0 * i, 9.0), 5.0,
			CombatStyle.C_GOLD if i < ph.x else Color(CombatStyle.C_GOLD, 0.25))
	var hp_r: Rect2 = Rect2(r.position + Vector2(6.0, 18.0), Vector2(r.size.x - 12.0, 14.0))
	m.rect(hp_r, Color(0, 0, 0, 0.55))
	var ratio: float = clampf(float(b.hp) / float(maxi(1, b.max_hp())), 0.0, 1.0)
	m.rect(Rect2(hp_r.position, Vector2(hp_r.size.x * ratio, hp_r.size.y)), CombatStyle.C_ENEMY)
	# phase thresholds as ticks on the bar
	if CombatStyle.gd().has_id("enemies", b.def_id):
		var phases: Variant = CombatStyle.gd().enemy(b.def_id).rt.get("phases", [])
		if phases is Array:
			for pd: Variant in (phases as Array):
				if pd is Dictionary:
					var pm: int = int((pd as Dictionary).get("hp_above_pm", 0))
					if pm > 0 and pm < 1000:
						var x: float = hp_r.position.x + hp_r.size.x * float(pm) / 1000.0
						m.rect(Rect2(Vector2(x - 1.0, hp_r.position.y - 2.0), Vector2(2.0, hp_r.size.y + 4.0)),
							CombatStyle.C_PAPER)
	var c: Dictionary = CombatView.cast(sim, b)
	_cast_bar(m, Rect2(r.position + Vector2(0.0, BOSS_H), Vector2(r.size.x, 10.0)), c)
	var tgt_is_boss: bool = (_model["ctl"] as RtUnit) != null and (_model["ctl"] as RtUnit).target_id == b.id
	if tgt_is_boss:
		m.rect_outline(r.grow(1.0), CombatStyle.C_CYAN, 2.0)
		_sword(m, Rect2(r.end.x + 6.0, r.position.y + 8.0, 24.0, 20.0))


## Cast bar in its tier (07 §6.2, §8.3): worthy = gold border + sparkle, interruptible = white, locked = grey + lock.
func _cast_bar(m: IconMesh, r: Rect2, c: Dictionary) -> void:
	if c.is_empty():
		return
	var tier: StringName = c["tier"]
	var border: Color = CombatStyle.C_PAPER
	var fill: Color = CombatStyle.C_GOLD.lerp(CombatStyle.C_PAPER, 0.15)
	match tier:
		&"worthy":
			border = CombatStyle.C_GOLD
			fill = CombatStyle.C_GOLD
		&"locked":
			border = CombatStyle.C_GREY
			fill = Color("#b9b0c8")
		&"party":
			border = CombatStyle.C_MANA
			fill = CombatStyle.C_MANA
	m.rect(r, Color(0, 0, 0, 0.6))
	var ratio: float = float(c["ratio"])
	if bool(c["channel"]):
		ratio = 1.0 - ratio
	m.rect(Rect2(r.position, Vector2(r.size.x * ratio, r.size.y)), fill)
	m.rect_outline(r.grow(1.0), border, 2.0 if tier == &"worthy" else 1.0)
	if tier == &"worthy":
		var sx: float = r.position.x + r.size.x * ratio
		var tw: float = 0.5 + 0.5 * sin(_t * 18.0)
		m.circle(Vector2(sx, r.get_center().y), 3.0 + 2.0 * tw, Color(1, 1, 1, 0.9), true)
	elif tier == &"locked":
		_lock(m, Vector2(r.end.x + 8.0, r.get_center().y), r.size.y + 4.0)


func _lock(m: IconMesh, c: Vector2, h: float) -> void:
	m.ring(c + Vector2(0, -h * 0.2), h * 0.28, CombatStyle.C_GREY, maxf(1.5, h * 0.12), true)
	m.rect(Rect2(c + Vector2(-h * 0.36, -h * 0.1), Vector2(h * 0.72, h * 0.6)), CombatStyle.C_GREY)


static func _diamond(m: IconMesh, c: Vector2, r: float, col: Color) -> void:
	m.poly(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), col)


const UiUtilRef := preload("res://scenes/ui/ui_util.gd")


## Round hit box (the Partner-Spezial button): a circle with the box size as diameter.
class RoundHit extends Control:
	func _has_point(point: Vector2) -> bool:
		return point.distance_to(size * 0.5) <= minf(size.x, size.y) * 0.5


## Hit box of a frame, the chip or the sword: over a frame's level plaque the mouse gets the tooltip "Stufe N".
class FrameHit extends Control:
	var tip: String = ""
	var tip_rect: Rect2 = Rect2()                       # the plaque, local to this hit box

	func _get_tooltip(at_position: Vector2) -> String:
		return tip if tip_rect.grow(2.0).has_point(at_position) else ""
