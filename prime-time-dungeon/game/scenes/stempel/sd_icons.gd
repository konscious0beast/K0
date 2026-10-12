extends RefCounted
## Drawn symbols of the Stempelduell (10 §4.1, 03_ART F8: never font glyphs): Formular-Arten, Werktage, the four
## statuses, the Durchsage, the ticket shapes, the opponents and the menu symbols. Every symbol goes into an IconMesh
## (icon_mesh.gd: one canvas draw call per mesh, 02_TECH §12.1), so a card or a ticket strip draws its frame and all its
## symbols as ONE triangle array. Private helper (no class_name):
##   SdIcons.add(mesh, &"stamp", rect, colour[, detail colour])   — into a mesh the caller commits
##   SdIcons.icon(&"stamp", colour, 24)                            — a standalone Control (menus, hints)

const IconMesh := preload("res://scenes/ui/icon_mesh.gd")

const KINDS: Array[StringName] = [&"stamp", &"flame", &"snow", &"capsule", &"magnifier", &"folder", &"hourglass",
	&"clock_arrow", &"snail", &"seal_exclamation", &"speaker", &"ticket", &"paw", &"person", &"pug", &"golem_paper",
	&"cabinet", &"stamp_carousel", &"menu", &"cross", &"check", &"arrow_left", &"arrow_right", &"arrow_up", &"lock",
	&"pile", &"tray", &"cards", &"star", &"trophy", &"book", &"drawer", &"page", &"refresh", &"shield", &"dot",
	&"diamond", &"circle", &"play", &"eye", &"bolt", &"hand_point"]


## A standalone symbol (menus, hint cards): one draw call.
class Icon extends Control:
	const IconsRef := preload("res://scenes/stempel/sd_icons.gd")
	var kind: StringName = &"dot":
		set(v):
			kind = v
			queue_redraw()
	var color: Color = Color.WHITE:
		set(v):
			color = v
			queue_redraw()
	var color_2: Color = Color(0, 0, 0, 0):
		set(v):
			color_2 = v
			queue_redraw()

	func _draw() -> void:
		var s: float = minf(size.x, size.y)
		if s <= 0.0:
			return
		var m: IconMesh = IconMesh.new()
		IconsRef.add(m, kind, Rect2((size - Vector2(s, s)) * 0.5, Vector2(s, s)), color, color_2)
		m.commit(self)


## A standalone symbol Control of `p_size` px (menus, hint cards): one draw call.
static func icon(p_kind: StringName, p_color: Color, p_size: float) -> Control:
	var i: Icon = Icon.new()
	i.kind = p_kind
	i.color = p_color
	i.custom_minimum_size = Vector2(p_size, p_size)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i


## Appends the symbol `kind` inside `r` (square part, centred) to `m`; `c2` = detail colour (alpha 0: ink).
static func add(m: IconMesh, kind: StringName, r: Rect2, c: Color, c2: Color = Color(0, 0, 0, 0)) -> void:
	var s: float = minf(r.size.x, r.size.y)
	if s <= 0.0:
		return
	var o: Vector2 = r.position + (r.size - Vector2(s, s)) * 0.5
	var d: Color = c2 if c2.a > 0.0 else Color("#140d1c")
	var g: _G = _G.new(m, o, s)
	match kind:
		&"stamp":
			g.circle(Vector2(0.5, 0.17), 0.13, c)
			g.rect(0.42, 0.24, 0.16, 0.28, c)
			g.poly([Vector2(0.24, 0.52), Vector2(0.76, 0.52), Vector2(0.84, 0.66), Vector2(0.16, 0.66)], c)
			g.rect(0.12, 0.7, 0.76, 0.14, c)
			g.rect(0.2, 0.75, 0.6, 0.04, d)
		&"flame":
			var pts: PackedVector2Array = []
			for i in 25:
				var t: float = float(i) / 24.0 * TAU
				var x: float = 0.5 + cos(t) * 0.34
				var y: float = 0.62 + sin(t) * 0.34
				if sin(t) < 0.0:
					y = 0.62 + sin(t) * 0.34 * 1.7
					x = 0.5 + cos(t) * 0.34 * (1.0 + sin(t) * 0.45)
				pts.append(g.p(Vector2(x, y)))
			m.poly(pts, c)
			g.circle(Vector2(0.5, 0.7), 0.13, c.lightened(0.45))
		&"snow":
			for i in 3:
				var a: float = float(i) / 3.0 * PI + PI / 6.0
				var dv: Vector2 = Vector2(cos(a), sin(a)) * 0.44
				g.line(Vector2(0.5, 0.5) - dv, Vector2(0.5, 0.5) + dv, c, 0.09)
			g.circle(Vector2(0.5, 0.5), 0.11, c)
		&"capsule":
			g.rect(0.26, 0.32, 0.48, 0.36, c)
			g.circle(Vector2(0.26, 0.5), 0.18, c)
			g.circle(Vector2(0.74, 0.5), 0.18, c)
			g.poly([Vector2(0.54, 0.34), Vector2(0.4, 0.52), Vector2(0.5, 0.52), Vector2(0.44, 0.67),
				Vector2(0.6, 0.47), Vector2(0.5, 0.47)], d)
		&"magnifier":
			g.ring(Vector2(0.42, 0.42), 0.26, c, 0.1)
			g.line(Vector2(0.6, 0.6), Vector2(0.88, 0.88), c, 0.14)
		&"folder":
			g.poly([Vector2(0.08, 0.22), Vector2(0.38, 0.22), Vector2(0.46, 0.32), Vector2(0.92, 0.32),
				Vector2(0.92, 0.84), Vector2(0.08, 0.84)], c)
			g.rect(0.08, 0.4, 0.84, 0.05, d)
		&"hourglass":
			g.rect(0.18, 0.08, 0.64, 0.08, c)
			g.rect(0.18, 0.84, 0.64, 0.08, c)
			g.poly([Vector2(0.24, 0.16), Vector2(0.76, 0.16), Vector2(0.54, 0.5), Vector2(0.46, 0.5)], c)
			g.poly([Vector2(0.46, 0.5), Vector2(0.54, 0.5), Vector2(0.76, 0.84), Vector2(0.24, 0.84)], c)
		&"clock_arrow":
			g.ring(Vector2(0.42, 0.44), 0.32, c, 0.1)
			g.line(Vector2(0.42, 0.44), Vector2(0.42, 0.24), c, 0.08)
			g.line(Vector2(0.42, 0.44), Vector2(0.56, 0.5), c, 0.08)
			g.line(Vector2(0.52, 0.86), Vector2(0.84, 0.86), c, 0.09)
			g.poly([Vector2(0.8, 0.74), Vector2(0.96, 0.86), Vector2(0.8, 0.98)], c)
		&"snail":
			g.circle(Vector2(0.56, 0.46), 0.3, c)
			g.ring(Vector2(0.56, 0.46), 0.15, d, 0.06)
			g.poly([Vector2(0.06, 0.82), Vector2(0.9, 0.82), Vector2(0.9, 0.72), Vector2(0.2, 0.68)], c)
			g.line(Vector2(0.16, 0.7), Vector2(0.1, 0.42), c, 0.05)
			g.circle(Vector2(0.1, 0.4), 0.05, c)
		&"seal_exclamation":
			var star: PackedVector2Array = []
			for i in 24:
				var a: float = float(i) / 24.0 * TAU
				var rad: float = 0.46 if i % 2 == 0 else 0.38
				star.append(g.p(Vector2(0.5 + cos(a) * rad, 0.5 + sin(a) * rad)))
			m.poly(star, c)
			g.rect(0.44, 0.24, 0.12, 0.32, d)
			g.circle(Vector2(0.5, 0.7), 0.07, d)
		&"speaker":
			g.rect(0.08, 0.38, 0.18, 0.24, c)
			g.poly([Vector2(0.26, 0.38), Vector2(0.5, 0.18), Vector2(0.5, 0.82), Vector2(0.26, 0.62)], c)
			for k in 2:
				var rr: float = 0.16 + 0.16 * k
				for j in 4:
					var a0: float = -0.8 + 1.6 * float(j) / 4.0
					var a1: float = -0.8 + 1.6 * float(j + 1) / 4.0
					g.line(Vector2(0.52 + cos(a0) * rr, 0.5 + sin(a0) * rr),
						Vector2(0.52 + cos(a1) * rr, 0.5 + sin(a1) * rr), c, 0.07)
		&"ticket":
			g.poly([Vector2(0.1, 0.2), Vector2(0.9, 0.2), Vector2(0.9, 0.4), Vector2(0.84, 0.5), Vector2(0.9, 0.6),
				Vector2(0.9, 0.8), Vector2(0.1, 0.8), Vector2(0.1, 0.6), Vector2(0.16, 0.5), Vector2(0.1, 0.4)], c)
			g.rect(0.28, 0.34, 0.44, 0.08, d)
			g.rect(0.28, 0.5, 0.3, 0.08, d)
		&"paw":
			g.circle(Vector2(0.5, 0.64), 0.22, c)
			for pt: Vector2 in [Vector2(0.22, 0.42), Vector2(0.4, 0.24), Vector2(0.6, 0.24), Vector2(0.78, 0.42)]:
				g.circle(pt, 0.1, c)
		&"person":
			g.circle(Vector2(0.5, 0.3), 0.2, c)
			g.poly([Vector2(0.15, 0.95), Vector2(0.22, 0.6), Vector2(0.5, 0.52), Vector2(0.78, 0.6),
				Vector2(0.85, 0.95)], c)
		&"pug":
			g.poly([Vector2(0.12, 0.2), Vector2(0.34, 0.26), Vector2(0.22, 0.5)], c.darkened(0.35))
			g.poly([Vector2(0.88, 0.2), Vector2(0.66, 0.26), Vector2(0.78, 0.5)], c.darkened(0.35))
			g.circle(Vector2(0.5, 0.54), 0.36, c)
			g.circle(Vector2(0.36, 0.48), 0.07, d)
			g.circle(Vector2(0.64, 0.48), 0.07, d)
			g.circle(Vector2(0.5, 0.7), 0.15, c.darkened(0.35))
			g.circle(Vector2(0.5, 0.64), 0.06, d)
		&"golem_paper":
			g.rect(0.26, 0.12, 0.56, 0.74, c.darkened(0.25))
			g.rect(0.18, 0.18, 0.56, 0.74, c)
			g.circle(Vector2(0.36, 0.42), 0.06, d)
			g.circle(Vector2(0.58, 0.42), 0.06, d)
			g.rect(0.34, 0.6, 0.26, 0.05, d)
			g.ring(Vector2(0.74, 0.16), 0.08, d, 0.04)
		&"cabinet":
			g.rect(0.18, 0.2, 0.64, 0.74, c)
			for i in 3:
				g.rect(0.24, 0.27 + i * 0.235, 0.52, 0.04, d)
				g.rect(0.42, 0.35 + i * 0.235, 0.16, 0.05, d)
			# the reading glasses rest on top, in the symbol's own colour (readable on light and dark ground)
			g.ring(Vector2(0.38, 0.12), 0.075, c, 0.035)
			g.ring(Vector2(0.62, 0.12), 0.075, c, 0.035)
			g.line(Vector2(0.455, 0.12), Vector2(0.545, 0.12), c, 0.03)
		&"stamp_carousel":
			g.ring(Vector2(0.5, 0.5), 0.3, c, 0.06)
			for i in 6:
				var a: float = float(i) / 6.0 * TAU - PI * 0.5
				var pc: Vector2 = Vector2(0.5 + cos(a) * 0.36, 0.5 + sin(a) * 0.36)
				g.rect(pc.x - 0.07, pc.y - 0.07, 0.14, 0.14, c)
			g.circle(Vector2(0.5, 0.5), 0.12, c)
			g.circle(Vector2(0.5, 0.5), 0.05, d)
		&"menu":
			for i in 3:
				g.rect(0.14, 0.22 + i * 0.24, 0.72, 0.11, c)
		&"cross":
			g.line(Vector2(0.2, 0.2), Vector2(0.8, 0.8), c, 0.13)
			g.line(Vector2(0.8, 0.2), Vector2(0.2, 0.8), c, 0.13)
		&"check":
			g.line(Vector2(0.15, 0.52), Vector2(0.4, 0.78), c, 0.13)
			g.line(Vector2(0.4, 0.78), Vector2(0.87, 0.22), c, 0.13)
		&"arrow_left":
			g.poly([Vector2(0.75, 0.12), Vector2(0.25, 0.5), Vector2(0.75, 0.88)], c)
		&"arrow_right", &"play":
			g.poly([Vector2(0.25, 0.12), Vector2(0.78, 0.5), Vector2(0.25, 0.88)], c)
		&"arrow_up":
			g.poly([Vector2(0.12, 0.75), Vector2(0.5, 0.22), Vector2(0.88, 0.75)], c)
		&"lock":
			g.ring(Vector2(0.5, 0.36), 0.2, c, 0.08)
			g.rect(0.22, 0.42, 0.56, 0.46, c)
			g.circle(Vector2(0.5, 0.6), 0.07, d)
			g.rect(0.47, 0.6, 0.06, 0.16, d)
		&"pile":
			for i in 3:
				g.rect(0.18 + i * 0.05, 0.16 + i * 0.06, 0.56, 0.7, c.darkened(0.3 - i * 0.12))
		&"tray":
			g.poly([Vector2(0.06, 0.5), Vector2(0.24, 0.5), Vector2(0.3, 0.62), Vector2(0.7, 0.62), Vector2(0.76, 0.5),
				Vector2(0.94, 0.5), Vector2(0.94, 0.86), Vector2(0.06, 0.86)], c)
			g.rect(0.24, 0.16, 0.5, 0.38, c.darkened(0.25))
		&"cards":
			g.poly(_rot_rect(Vector2(0.38, 0.52), Vector2(0.36, 0.52), -0.3), c.darkened(0.3))
			g.poly(_rot_rect(Vector2(0.62, 0.52), Vector2(0.36, 0.52), 0.3), c.darkened(0.15))
			g.rect(0.32, 0.22, 0.36, 0.56, c)
		&"star":
			var pts2: PackedVector2Array = []
			for i in 10:
				var a: float = -PI * 0.5 + float(i) / 10.0 * TAU
				var rad: float = 0.48 if i % 2 == 0 else 0.2
				pts2.append(g.p(Vector2(0.5 + cos(a) * rad, 0.53 + sin(a) * rad)))
			m.poly(pts2, c)
		&"trophy":
			g.poly([Vector2(0.2, 0.1), Vector2(0.8, 0.1), Vector2(0.72, 0.45), Vector2(0.5, 0.58),
				Vector2(0.28, 0.45)], c)
			g.rect(0.44, 0.55, 0.12, 0.2, c)
			g.rect(0.28, 0.75, 0.44, 0.14, c)
		&"book":
			g.poly([Vector2(0.06, 0.2), Vector2(0.46, 0.26), Vector2(0.46, 0.86), Vector2(0.06, 0.8)], c)
			g.poly([Vector2(0.54, 0.26), Vector2(0.94, 0.2), Vector2(0.94, 0.8), Vector2(0.54, 0.86)], c)
			g.rect(0.12, 0.38, 0.28, 0.04, d)
			g.rect(0.6, 0.38, 0.28, 0.04, d)
		&"drawer":
			g.rect(0.12, 0.1, 0.76, 0.8, c)
			g.rect(0.2, 0.18, 0.6, 0.28, d)
			g.rect(0.2, 0.54, 0.6, 0.28, d)
			g.rect(0.42, 0.28, 0.16, 0.06, c)
			g.rect(0.42, 0.64, 0.16, 0.06, c)
		&"page":
			g.poly([Vector2(0.2, 0.06), Vector2(0.66, 0.06), Vector2(0.82, 0.22), Vector2(0.82, 0.94),
				Vector2(0.2, 0.94)], c)
			for i in 4:
				g.rect(0.3, 0.32 + i * 0.14, 0.42, 0.05, d)
		&"refresh":
			g.ring(Vector2(0.5, 0.5), 0.3, c, 0.1)
			g.poly([Vector2(0.62, 0.06), Vector2(0.86, 0.2), Vector2(0.62, 0.34)], c)
			g.poly([Vector2(0.38, 0.66), Vector2(0.14, 0.8), Vector2(0.38, 0.94)], c)
		&"shield":
			g.poly([Vector2(0.5, 0.06), Vector2(0.88, 0.2), Vector2(0.82, 0.62), Vector2(0.5, 0.94),
				Vector2(0.18, 0.62), Vector2(0.12, 0.2)], c)
		&"diamond":
			g.poly([Vector2(0.5, 0.04), Vector2(0.96, 0.5), Vector2(0.5, 0.96), Vector2(0.04, 0.5)], c)
		&"circle", &"dot":
			g.circle(Vector2(0.5, 0.5), 0.46, c)
		&"eye":
			g.ring(Vector2(0.5, 0.5), 0.34, c, 0.08)
			g.circle(Vector2(0.5, 0.5), 0.14, c)
		&"bolt":
			g.poly([Vector2(0.58, 0.04), Vector2(0.2, 0.56), Vector2(0.46, 0.56), Vector2(0.36, 0.96),
				Vector2(0.8, 0.4), Vector2(0.54, 0.4)], c)
		&"hand_point":
			g.poly([Vector2(0.5, 0.96), Vector2(0.22, 0.6), Vector2(0.4, 0.6), Vector2(0.4, 0.06), Vector2(0.6, 0.06),
				Vector2(0.6, 0.6), Vector2(0.78, 0.6)], c)
		_:
			g.circle(Vector2(0.5, 0.5), 0.4, c)


static func _rot_rect(cen: Vector2, sz: Vector2, a: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for corner: Vector2 in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]:
		out.append(cen + (corner * sz).rotated(a))
	return out


## Unit-space drawing into an IconMesh (origin `o`, side `s`).
class _G:
	const IconMeshG := preload("res://scenes/ui/icon_mesh.gd")
	var m: IconMeshG
	var o: Vector2
	var s: float

	func _init(p_m: IconMeshG, p_o: Vector2, p_s: float) -> void:
		m = p_m
		o = p_o
		s = p_s

	func p(u: Vector2) -> Vector2:
		return o + u * s

	func circle(c: Vector2, r: float, col: Color) -> void:
		m.circle(p(c), r * s, col, true)

	func ring(c: Vector2, r: float, col: Color, w: float) -> void:
		m.ring(p(c), r * s, col, maxf(w * s, 1.0), true)

	func rect(x: float, y: float, w: float, h: float, col: Color) -> void:
		m.rect(Rect2(p(Vector2(x, y)), Vector2(w, h) * s), col)

	func poly(pts: Array[Vector2], col: Color) -> void:
		var out: PackedVector2Array = []
		for v: Vector2 in pts:
			out.append(p(v))
		m.poly(out, col)

	func line(a: Vector2, b: Vector2, col: Color, w: float) -> void:
		m.line(p(a), p(b), col, maxf(w * s, 1.0), true)
