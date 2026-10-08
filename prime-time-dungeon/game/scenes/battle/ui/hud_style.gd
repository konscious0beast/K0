extends RefCounted
## Battle HUD look (03_ART §9: TV broadcast, 12° skewed panels, magenta / gold / cyan on ink) — shared by the M5 UI
## scripts. Private M5 helper (no class_name). Symbols are drawn polygons, never text glyphs (03_ART F8).

const C_INK: Color = Color("#140d1c")
const C_PAPER: Color = Color("#f5f0e6")
const C_PARTY: Color = Color("#4aa8ff")       # ui_party (turn order frame)
const C_ENEMY: Color = Color("#e8455a")       # ui_enemy
const C_PSEUDO: Color = Color("#8a8494")      # "Zug grau"
const C_HP: Color = Color("#4ade80")
const C_HP_LOW: Color = Color("#ff4d4d")
const C_MP: Color = Color("#60a5fa")
const C_TRAIL: Color = Color("#ff4d4d")
const C_PANEL: Color = Color(0.0784, 0.051, 0.1098, 0.86)
const C_PANEL_HI: Color = Color(0.16, 0.08, 0.22, 0.94)
const ELEMENT_COLORS: Dictionary = {"physical": "#f2ebdd", "fire": "#ff6a2b", "ice": "#7fd8ff", "shock": "#f5e642",
	"poison": "#7cc242", "none": "#6bffb0"}
const STATUS_COLORS: Dictionary = {"sts_poison": "#7cc242", "sts_stun": "#f5d90a", "sts_slow": "#5b8def",
	"sts_haste": "#ff7a1a", "sts_guard": "#9aa7b8", "sts_taunt": "#e8455a"}


## Icon control: draws `kind` (element_<e>, status icon id, cmd_<kind>, rank_<n>, train, star, coin, heart, box).
class Icon extends Control:
	var kind: String = ""
	var color: Color = Color.WHITE

	func _init(p_kind: String = "", p_color: Color = Color.WHITE, p_size: float = 18.0) -> void:
		kind = p_kind
		color = p_color
		custom_minimum_size = Vector2(p_size, p_size)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_icon(p_kind: String, p_color: Color) -> void:
		kind = p_kind
		color = p_color
		queue_redraw()

	func _draw() -> void:
		draw_icon(self, kind, Rect2(Vector2.ZERO, size), color)


	static func draw_icon(ci: CanvasItem, kind: String, r: Rect2, col: Color) -> void:
		var c: Vector2 = r.get_center()
		var s: float = minf(r.size.x, r.size.y) * 0.5
		var ink: Color = C_INK
		match kind:
			"element_fire", "fire":
				_poly(ci, [c + Vector2(0, -s), c + Vector2(s * 0.62, s * 0.1), c + Vector2(s * 0.45, s * 0.7),
					c + Vector2(0, s * 0.95), c + Vector2(-s * 0.45, s * 0.7), c + Vector2(-s * 0.62, s * 0.1)], col, ink)
				_poly(ci, [c + Vector2(0, -s * 0.15), c + Vector2(s * 0.25, s * 0.45), c + Vector2(0, s * 0.7),
					c + Vector2(-s * 0.25, s * 0.45)], Color("#ffe08a"), Color(0, 0, 0, 0))
			"element_ice", "ice":
				var pts: Array = []
				for i in 12:
					var a: float = TAU * float(i) / 12.0 - PI * 0.5
					var rr: float = s * (0.95 if i % 2 == 0 else 0.42)
					pts.append(c + Vector2(cos(a), sin(a)) * rr)
				_poly(ci, pts, col, ink)
			"element_shock", "shock":
				_poly(ci, [c + Vector2(s * 0.2, -s), c + Vector2(s * 0.55, -s), c + Vector2(s * 0.1, -s * 0.05),
					c + Vector2(s * 0.5, -s * 0.05), c + Vector2(-s * 0.35, s), c + Vector2(-s * 0.05, s * 0.15),
					c + Vector2(-s * 0.45, s * 0.15)], col, ink)
			"element_poison", "poison":
				ci.draw_circle(c + Vector2(-s * 0.2, s * 0.2), s * 0.62, ink)
				ci.draw_circle(c + Vector2(-s * 0.2, s * 0.2), s * 0.5, col)
				ci.draw_circle(c + Vector2(s * 0.45, -s * 0.45), s * 0.36, ink)
				ci.draw_circle(c + Vector2(s * 0.45, -s * 0.45), s * 0.26, col)
				ci.draw_circle(c + Vector2(-s * 0.38, 0.0), s * 0.13, Color(1, 1, 1, 0.6))
			"element_physical", "physical", "cmd_attack":
				# sword: blade + guard + grip
				var d: Vector2 = Vector2(1, -1).normalized()
				var n: Vector2 = Vector2(d.y, -d.x)
				var tip: Vector2 = c + d * s * 0.95
				var base: Vector2 = c - d * s * 0.35
				_poly(ci, [tip, base + n * s * 0.2, base - n * s * 0.2], col, ink)
				ci.draw_line(base + n * s * 0.45, base - n * s * 0.45, ink, maxf(3.0, s * 0.3))
				ci.draw_line(base + n * s * 0.4, base - n * s * 0.4, col, maxf(1.5, s * 0.16))
				ci.draw_line(base, c - d * s * 0.9, ink, maxf(3.0, s * 0.3))
				ci.draw_line(base, c - d * s * 0.85, Color("#c9a227"), maxf(1.5, s * 0.15))
			"element_none", "heal", "none":
				var w: float = s * 0.36
				_poly(ci, [c + Vector2(-w, -s), c + Vector2(w, -s), c + Vector2(w, -w), c + Vector2(s, -w),
					c + Vector2(s, w), c + Vector2(w, w), c + Vector2(w, s), c + Vector2(-w, s), c + Vector2(-w, w),
					c + Vector2(-s, w), c + Vector2(-s, -w), c + Vector2(-w, -w)], col, ink)
			"stun", "star", "cmd_stunt":
				var sp: Array = []
				for i in 10:
					var a2: float = TAU * float(i) / 10.0 - PI * 0.5
					var r2: float = s * (0.98 if i % 2 == 0 else 0.42)
					sp.append(c + Vector2(cos(a2), sin(a2)) * r2)
				_poly(ci, sp, col, ink)
			"cmd_skill", "sparkle":
				var kp: Array = []
				for i in 8:
					var a3: float = TAU * float(i) / 8.0 - PI * 0.5
					var r3: float = s * (0.98 if i % 2 == 0 else 0.25)
					kp.append(c + Vector2(cos(a3), sin(a3)) * r3)
				_poly(ci, kp, col, ink)
				ci.draw_circle(c + Vector2(s * 0.62, -s * 0.62), s * 0.16, col)
			"slow":
				for k in 2:
					var y: float = -s * 0.45 + s * 0.6 * float(k)
					_poly(ci, [c + Vector2(-s * 0.85, y), c + Vector2(0, y + s * 0.55), c + Vector2(s * 0.85, y),
						c + Vector2(s * 0.85, y + s * 0.3), c + Vector2(0, y + s * 0.85), c + Vector2(-s * 0.85, y + s * 0.3)],
						col, ink)
			"haste":
				for k in 2:
					var y2: float = s * 0.45 - s * 0.6 * float(k)
					_poly(ci, [c + Vector2(-s * 0.85, y2), c + Vector2(0, y2 - s * 0.55), c + Vector2(s * 0.85, y2),
						c + Vector2(s * 0.85, y2 - s * 0.3), c + Vector2(0, y2 - s * 0.85), c + Vector2(-s * 0.85, y2 - s * 0.3)],
						col, ink)
			"guard", "cmd_defend", "shield":
				_poly(ci, [c + Vector2(0, -s), c + Vector2(s * 0.85, -s * 0.6), c + Vector2(s * 0.7, s * 0.35),
					c + Vector2(0, s), c + Vector2(-s * 0.7, s * 0.35), c + Vector2(-s * 0.85, -s * 0.6)], col, ink)
				ci.draw_line(c + Vector2(0, -s * 0.7), c + Vector2(0, s * 0.7), Color(1, 1, 1, 0.45), maxf(1.0, s * 0.14))
			"taunt":
				ci.draw_circle(c, s * 0.95, ink)
				ci.draw_circle(c, s * 0.82, col)
				ci.draw_circle(c, s * 0.5, ink)
				ci.draw_circle(c, s * 0.36, col)
				ci.draw_circle(c, s * 0.13, ink)
			"cmd_item", "box", "bag":
				_poly(ci, [c + Vector2(-s * 0.8, -s * 0.25), c + Vector2(s * 0.8, -s * 0.25), c + Vector2(s * 0.7, s * 0.9),
					c + Vector2(-s * 0.7, s * 0.9)], col, ink)
				_poly(ci, [c + Vector2(-s * 0.4, -s * 0.25), c + Vector2(-s * 0.3, -s * 0.8), c + Vector2(s * 0.3, -s * 0.8),
					c + Vector2(s * 0.4, -s * 0.25), c + Vector2(s * 0.22, -s * 0.25), c + Vector2(s * 0.15, -s * 0.6),
					c + Vector2(-s * 0.15, -s * 0.6), c + Vector2(-s * 0.22, -s * 0.25)], col, ink)
				ci.draw_line(c + Vector2(-s * 0.75, s * 0.15), c + Vector2(s * 0.75, s * 0.15), ink, maxf(1.5, s * 0.14))
			"cmd_flee":
				_poly(ci, [c + Vector2(s, 0), c + Vector2(s * 0.1, -s * 0.85), c + Vector2(s * 0.1, -s * 0.35),
					c + Vector2(-s * 0.9, -s * 0.35), c + Vector2(-s * 0.9, s * 0.35), c + Vector2(s * 0.1, s * 0.35),
					c + Vector2(s * 0.1, s * 0.85)], col, ink)
			"train":
				_poly(ci, [c + Vector2(-s * 0.75, -s * 0.85), c + Vector2(s * 0.75, -s * 0.85), c + Vector2(s * 0.85, s * 0.55),
					c + Vector2(-s * 0.85, s * 0.55)], col, ink)
				ci.draw_rect(Rect2(c + Vector2(-s * 0.55, -s * 0.6), Vector2(s * 1.1, s * 0.5)), Color("#ffd27a"), true)
				ci.draw_circle(c + Vector2(-s * 0.45, s * 0.25), s * 0.14, Color("#fff2c8"))
				ci.draw_circle(c + Vector2(s * 0.45, s * 0.25), s * 0.14, Color("#fff2c8"))
				ci.draw_line(c + Vector2(-s * 0.6, s * 0.95), c + Vector2(-s * 0.35, s * 0.55), ink, maxf(2.0, s * 0.15))
				ci.draw_line(c + Vector2(s * 0.6, s * 0.95), c + Vector2(s * 0.35, s * 0.55), ink, maxf(2.0, s * 0.15))
			"coin":
				ci.draw_circle(c, s * 0.95, ink)
				ci.draw_circle(c, s * 0.8, Color("#ffc93c"))
				ci.draw_circle(c, s * 0.5, Color("#e0a020"))
			"heart":
				ci.draw_circle(c + Vector2(-s * 0.42, -s * 0.25), s * 0.48, col)
				ci.draw_circle(c + Vector2(s * 0.42, -s * 0.25), s * 0.48, col)
				_poly(ci, [c + Vector2(-s * 0.88, -s * 0.12), c + Vector2(s * 0.88, -s * 0.12), c + Vector2(0, s * 0.92)],
					col, Color(0, 0, 0, 0))
			"chevron":
				_poly(ci, [c + Vector2(-s * 0.5, -s * 0.9), c + Vector2(s * 0.6, 0), c + Vector2(-s * 0.5, s * 0.9),
					c + Vector2(-s * 0.15, 0)], col, Color(0, 0, 0, 0))
			"arrow_down":
				_poly(ci, [c + Vector2(-s, -s * 0.6), c + Vector2(s, -s * 0.6), c + Vector2(0, s * 0.8)], col, ink)
			_:
				if kind.begins_with("rank_"):
					var n2: int = clampi(kind.trim_prefix("rank_").to_int(), 1, 3)
					for i in n2:
						var cc: Vector2 = Vector2(r.position.x + s * 0.9 + float(i) * s * 1.9, c.y)
						ci.draw_circle(cc, s * 0.85, ink)
						ci.draw_circle(cc, s * 0.68, col)
						ci.draw_line(cc, cc + Vector2(0, -s * 0.5), ink, maxf(1.2, s * 0.18))
						ci.draw_line(cc, cc + Vector2(s * 0.38, 0), ink, maxf(1.2, s * 0.18))
				else:
					ci.draw_circle(c, s * 0.8, ink)
					ci.draw_circle(c, s * 0.62, col)


	static func _poly(ci: CanvasItem, pts: Array, fill: Color, outline: Color) -> void:
		var p: PackedVector2Array = PackedVector2Array()
		for v: Variant in pts:
			p.append(v as Vector2)
		if outline.a > 0.0:
			var loop: PackedVector2Array = p.duplicate()
			loop.append(p[0])
			ci.draw_polyline(loop, outline, 3.0, true)
		ci.draw_colored_polygon(p, fill)


## Horizontal bar with a trailing (damage) segment that catches up after 0.5 s (03_ART §9.2).
class Bar extends Control:
	var value: float = 1.0             # 0..1
	var trail: float = 1.0
	var fill: Color = Color("#4ade80")
	var _hold: float = 0.0

	func _init(p_fill: Color = Color("#4ade80"), p_height: float = 8.0) -> void:
		fill = p_fill
		custom_minimum_size = Vector2(40, p_height)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_ratio(r: float, animate: bool = true) -> void:
		var v: float = clampf(r, 0.0, 1.0)
		if not animate or v > trail:
			trail = v
		if animate and v < value:
			_hold = 0.5
		value = v
		queue_redraw()

	func _process(delta: float) -> void:
		if trail > value:
			if _hold > 0.0:
				_hold -= delta
			else:
				trail = maxf(value, trail - delta * 1.2)
			queue_redraw()

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.02, 0.01, 0.04, 0.85), true)
		if trail > value:
			draw_rect(Rect2(Vector2(size.x * value, 0), Vector2(size.x * (trail - value), size.y)),
				Color("#ff4d4d"), true)
		if value > 0.0:
			draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * value, size.y)), fill, true)
			draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * value, maxf(1.0, size.y * 0.35))),
				Color(1, 1, 1, 0.22), true)
		draw_rect(r, Color(1, 1, 1, 0.18), false, 1.0)


## Skewed show panel (12° = skew 0.21) with an accent edge.
static func show_box(bg: Color = C_PANEL, border: Color = Color("#ff2e88"), border_w: int = 2,
		skew: float = 0.0, margin: Vector4 = Vector4(12, 8, 12, 8)) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(0)
	sb.skew = Vector2(skew, 0.0)
	sb.content_margin_left = margin.x
	sb.content_margin_top = margin.y
	sb.content_margin_right = margin.z
	sb.content_margin_bottom = margin.w
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 4
	sb.anti_aliasing = true
	return sb


static func label(text: String, size: int = 18, color: Color = C_PAPER, bold: bool = false,
		outline: int = 2) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", C_INK)
	l.add_theme_constant_override("outline_size", outline)
	if bold:
		l.add_theme_font_override("font", UiTheme.font_bold())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func mono_label(text: String, size: int = 18, color: Color = C_PAPER) -> Label:
	var l: Label = label(text, size, color)
	l.add_theme_font_override("font", UiTheme.font_mono())
	return l


static func element_color(element: String) -> Color:
	return Color(str(ELEMENT_COLORS.get(element, "#f2ebdd")))


static func status_color(status_id: String) -> Color:
	if STATUS_COLORS.has(status_id):
		return Color(str(STATUS_COLORS[status_id]))
	if DB.has_id("statuses", status_id):
		return Color(DB.status(status_id).color)
	return C_PAPER


## Icon id of a status ("poison", "stun", …; StatusDef.icon, fallback from the id).
static func status_icon(status_id: String) -> String:
	if DB.has_id("statuses", status_id) and DB.status(status_id).icon != "":
		return DB.status(status_id).icon
	return status_id.trim_prefix("sts_")


## Number with thousands dots (German).
static func fmt_int(n: int) -> String:
	var s: String = str(absi(n))
	var out: String = ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## Draws icon `kind` into rect `r` of canvas item `ci` (see Icon).
static func draw_icon(ci: CanvasItem, kind: String, r: Rect2, col: Color) -> void:
	Icon.draw_icon(ci, kind, r, col)
