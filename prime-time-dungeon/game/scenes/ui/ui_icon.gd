extends Control
## Private M6 vector icon (03_ART §9.2, F8): symbols are drawn shapes, never font glyphs.
## `kind` selects the shape; drawn into the control rect (keeps aspect, centered). Works in both renderers.
## All primitives of one icon go out as ONE triangle array (icon_mesh.gd, 02_TECH §12.1: one canvas draw call per
## icon instead of one per shape).

const IconMesh := preload("res://scenes/ui/icon_mesh.gd")

const KINDS: Array[StringName] = [&"dot", &"eye", &"heart", &"menu", &"hand", &"fist", &"map", &"gear", &"box",
	&"star", &"coin", &"clock", &"skull", &"crown", &"check", &"cross", &"arrow_left", &"arrow_right", &"arrow_up",
	&"arrow_down", &"diamond", &"key", &"floppy", &"door", &"paw", &"person", &"chat", &"bolt", &"flame", &"snow",
	&"bubble", &"trophy", &"gift", &"play", &"pause", &"stairs", &"vending", &"sword", &"shield", &"ring", &"potion",
	&"camera", &"mic", &"tv", &"drone", &"bark", &"swap"]

@export var kind: StringName = &"dot":
	set(v):
		kind = v
		queue_redraw()
@export var color: Color = Color.WHITE:
	set(v):
		color = v
		queue_redraw()
@export var color_2: Color = Color(0, 0, 0, 0):   # secondary (details); alpha 0 → derived
	set(v):
		color_2 = v
		queue_redraw()


static func make(p_kind: StringName, p_color: Color, p_size: float) -> Control:
	var icon: Control = (load("res://scenes/ui/ui_icon.gd") as GDScript).new()
	icon.set("kind", p_kind)
	icon.set("color", p_color)
	icon.custom_minimum_size = Vector2(p_size, p_size)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


var _m: IconMesh = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var m: IconMesh = build_mesh()
	if m != null:
		m.commit(self)


## The icon's primitives as one IconMesh in drawing order (null without a size). Headless tests use it directly.
func build_mesh() -> IconMesh:
	var s: float = minf(size.x, size.y)
	if s <= 0.0:
		return null
	_m = IconMesh.new()
	var o: Vector2 = (size - Vector2(s, s)) * 0.5
	var c2: Color = color_2 if color_2.a > 0.0 else Color("#140d1c")
	match kind:
		&"dot":
			_circle(o, s, Vector2(0.5, 0.5), 0.5, color)
		&"eye":
			var pts: PackedVector2Array = []
			for i in 17:
				var t: float = float(i) / 16.0 * PI
				pts.append(_p(o, s, Vector2(0.5 - 0.48 * cos(t), 0.5 - 0.3 * sin(t))))
			for i in range(1, 16):
				var t: float = float(i) / 16.0 * PI
				pts.append(_p(o, s, Vector2(0.5 + 0.48 * cos(t), 0.5 + 0.3 * sin(t))))
			_m.poly(pts, color)
			_circle(o, s, Vector2(0.5, 0.5), 0.17, c2)
			_circle(o, s, Vector2(0.56, 0.44), 0.05, color)
		&"heart":
			var pts: PackedVector2Array = []
			for i in 33:
				var t: float = float(i) / 32.0 * TAU
				var x: float = 16.0 * pow(sin(t), 3)
				var y: float = 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
				pts.append(_p(o, s, Vector2(0.5 + x / 36.0, 0.48 - y / 36.0)))
			_m.poly(pts, color)
		&"menu":
			for i in 3:
				_rect(o, s, Rect2(0.1, 0.2 + i * 0.25, 0.8, 0.13), color)
		&"hand":
			_rect(o, s, Rect2(0.25, 0.45, 0.55, 0.45), color)
			for i in 4:
				_rect(o, s, Rect2(0.25 + i * 0.14, 0.12 + absf(i - 1.5) * 0.06, 0.11, 0.4), color)
			_poly(o, s, [Vector2(0.06, 0.5), Vector2(0.16, 0.42), Vector2(0.3, 0.6), Vector2(0.25, 0.72)], color)
		&"fist":
			_rect(o, s, Rect2(0.18, 0.3, 0.64, 0.5), color)
			for i in 4:
				_circle(o, s, Vector2(0.26 + i * 0.16, 0.3), 0.08, color)
			_rect(o, s, Rect2(0.3, 0.8, 0.4, 0.12), color)
			for i in 3:
				_rect(o, s, Rect2(0.33 + i * 0.16, 0.32, 0.03, 0.2), c2)
		&"map":
			_poly(o, s, [Vector2(0.08, 0.2), Vector2(0.36, 0.1), Vector2(0.64, 0.2), Vector2(0.92, 0.1),
				Vector2(0.92, 0.8), Vector2(0.64, 0.9), Vector2(0.36, 0.8), Vector2(0.08, 0.9)], color)
			_line(o, s, Vector2(0.36, 0.1), Vector2(0.36, 0.8), c2, 0.05)
			_line(o, s, Vector2(0.64, 0.2), Vector2(0.64, 0.9), c2, 0.05)
		&"gear":
			for i in 8:
				var a: float = float(i) / 8.0 * TAU
				_poly(o, s, _rot_rect(Vector2(0.5, 0.5), Vector2(0.14, 0.9), a), color)
			_circle(o, s, Vector2(0.5, 0.5), 0.32, color)
			_circle(o, s, Vector2(0.5, 0.5), 0.13, c2)
		&"box":
			_poly(o, s, [Vector2(0.1, 0.32), Vector2(0.5, 0.15), Vector2(0.9, 0.32), Vector2(0.5, 0.48)],
				color.lightened(0.25))
			_poly(o, s, [Vector2(0.1, 0.32), Vector2(0.5, 0.48), Vector2(0.5, 0.92), Vector2(0.1, 0.75)], color)
			_poly(o, s, [Vector2(0.5, 0.48), Vector2(0.9, 0.32), Vector2(0.9, 0.75), Vector2(0.5, 0.92)],
				color.darkened(0.25))
			_line(o, s, Vector2(0.3, 0.24), Vector2(0.7, 0.4), c2, 0.04)
		&"gift":
			_rect(o, s, Rect2(0.12, 0.38, 0.76, 0.52), color)
			_rect(o, s, Rect2(0.08, 0.28, 0.84, 0.14), color.lightened(0.2))
			_rect(o, s, Rect2(0.45, 0.28, 0.1, 0.62), c2)
			_circle(o, s, Vector2(0.38, 0.2), 0.1, c2)
			_circle(o, s, Vector2(0.62, 0.2), 0.1, c2)
		&"star":
			var pts: PackedVector2Array = []
			for i in 10:
				var a: float = -PI * 0.5 + float(i) / 10.0 * TAU
				var r: float = 0.48 if i % 2 == 0 else 0.2
				pts.append(_p(o, s, Vector2(0.5 + cos(a) * r, 0.53 + sin(a) * r)))
			_m.poly(pts, color)
		&"coin":
			_circle(o, s, Vector2(0.5, 0.5), 0.45, color)
			_circle(o, s, Vector2(0.5, 0.5), 0.33, color.darkened(0.2))
			_rect(o, s, Rect2(0.44, 0.3, 0.12, 0.4), color.lightened(0.3))
		&"clock":
			_circle(o, s, Vector2(0.5, 0.5), 0.46, color)
			_circle(o, s, Vector2(0.5, 0.5), 0.36, c2)
			_line(o, s, Vector2(0.5, 0.5), Vector2(0.5, 0.24), color, 0.07)
			_line(o, s, Vector2(0.5, 0.5), Vector2(0.68, 0.58), color, 0.07)
		&"skull":
			_circle(o, s, Vector2(0.5, 0.42), 0.36, color)
			_rect(o, s, Rect2(0.3, 0.6, 0.4, 0.28), color)
			_circle(o, s, Vector2(0.37, 0.45), 0.1, c2)
			_circle(o, s, Vector2(0.63, 0.45), 0.1, c2)
			_rect(o, s, Rect2(0.42, 0.74, 0.04, 0.14), c2)
			_rect(o, s, Rect2(0.54, 0.74, 0.04, 0.14), c2)
		&"crown":
			_poly(o, s, [Vector2(0.1, 0.8), Vector2(0.1, 0.3), Vector2(0.3, 0.55), Vector2(0.5, 0.2), Vector2(0.7, 0.55),
				Vector2(0.9, 0.3), Vector2(0.9, 0.8)], color)
		&"check":
			_line(o, s, Vector2(0.15, 0.52), Vector2(0.4, 0.78), color, 0.13)
			_line(o, s, Vector2(0.4, 0.78), Vector2(0.87, 0.22), color, 0.13)
		&"cross":
			_line(o, s, Vector2(0.18, 0.18), Vector2(0.82, 0.82), color, 0.13)
			_line(o, s, Vector2(0.82, 0.18), Vector2(0.18, 0.82), color, 0.13)
		&"arrow_left":
			_poly(o, s, [Vector2(0.75, 0.12), Vector2(0.25, 0.5), Vector2(0.75, 0.88)], color)
		&"arrow_right", &"play":
			_poly(o, s, [Vector2(0.25, 0.12), Vector2(0.78, 0.5), Vector2(0.25, 0.88)], color)
		&"arrow_up":
			_poly(o, s, [Vector2(0.12, 0.75), Vector2(0.5, 0.22), Vector2(0.88, 0.75)], color)
		&"arrow_down":
			_poly(o, s, [Vector2(0.12, 0.25), Vector2(0.5, 0.78), Vector2(0.88, 0.25)], color)
		&"pause":
			_rect(o, s, Rect2(0.22, 0.15, 0.2, 0.7), color)
			_rect(o, s, Rect2(0.58, 0.15, 0.2, 0.7), color)
		&"diamond":
			_poly(o, s, [Vector2(0.5, 0.0), Vector2(1.0, 0.5), Vector2(0.5, 1.0), Vector2(0.0, 0.5)], color)
		&"key":
			_circle(o, s, Vector2(0.3, 0.5), 0.22, color)
			_circle(o, s, Vector2(0.3, 0.5), 0.09, c2)
			_rect(o, s, Rect2(0.45, 0.44, 0.47, 0.12), color)
			_rect(o, s, Rect2(0.74, 0.56, 0.08, 0.16), color)
			_rect(o, s, Rect2(0.86, 0.56, 0.06, 0.12), color)
		&"floppy":
			_poly(o, s, [Vector2(0.12, 0.1), Vector2(0.75, 0.1), Vector2(0.9, 0.25), Vector2(0.9, 0.9),
				Vector2(0.12, 0.9)], color)
			_rect(o, s, Rect2(0.28, 0.1, 0.4, 0.26), c2)
			_rect(o, s, Rect2(0.25, 0.55, 0.5, 0.35), color.lightened(0.5))
		&"door":
			_rect(o, s, Rect2(0.22, 0.08, 0.56, 0.86), color)
			_rect(o, s, Rect2(0.3, 0.16, 0.4, 0.78), c2)
			_circle(o, s, Vector2(0.62, 0.55), 0.05, color)
		&"paw":
			_circle(o, s, Vector2(0.5, 0.64), 0.22, color)
			_circle(o, s, Vector2(0.22, 0.42), 0.1, color)
			_circle(o, s, Vector2(0.4, 0.24), 0.1, color)
			_circle(o, s, Vector2(0.6, 0.24), 0.1, color)
			_circle(o, s, Vector2(0.78, 0.42), 0.1, color)
		&"person":
			_circle(o, s, Vector2(0.5, 0.3), 0.2, color)
			_poly(o, s, [Vector2(0.15, 0.95), Vector2(0.22, 0.6), Vector2(0.5, 0.52), Vector2(0.78, 0.6),
				Vector2(0.85, 0.95)], color)
		&"chat":
			_rect(o, s, Rect2(0.08, 0.15, 0.84, 0.55), color)
			_poly(o, s, [Vector2(0.25, 0.68), Vector2(0.45, 0.68), Vector2(0.2, 0.9)], color)
			for i in 3:
				_circle(o, s, Vector2(0.3 + i * 0.2, 0.42), 0.06, c2)
		&"bolt":
			_poly(o, s, [Vector2(0.58, 0.04), Vector2(0.2, 0.56), Vector2(0.46, 0.56), Vector2(0.36, 0.96),
				Vector2(0.8, 0.4), Vector2(0.54, 0.4)], color)
		&"flame":
			var pts: PackedVector2Array = []
			for i in 25:
				var t: float = float(i) / 24.0 * TAU
				var r: float = 0.34 * (1.0 + 0.0 * sin(t))
				var y: float = 0.62 + sin(t) * r
				var x: float = 0.5 + cos(t) * r
				if sin(t) < 0.0:
					y = 0.62 + sin(t) * r * 1.8
					x = 0.5 + cos(t) * r * (1.0 + sin(t) * 0.4)
				pts.append(_p(o, s, Vector2(x, y)))
			_m.poly(pts, color)
			_circle(o, s, Vector2(0.5, 0.68), 0.14, color.lightened(0.5))
		&"snow":
			for i in 3:
				var a: float = float(i) / 3.0 * PI
				var d: Vector2 = Vector2(cos(a), sin(a)) * 0.44
				_line(o, s, Vector2(0.5, 0.5) - d, Vector2(0.5, 0.5) + d, color, 0.08)
			_circle(o, s, Vector2(0.5, 0.5), 0.1, color)
		&"bubble":
			_circle(o, s, Vector2(0.38, 0.6), 0.28, color)
			_circle(o, s, Vector2(0.7, 0.32), 0.16, color)
			_circle(o, s, Vector2(0.32, 0.52), 0.08, color.lightened(0.5))
		&"trophy":
			_poly(o, s, [Vector2(0.2, 0.1), Vector2(0.8, 0.1), Vector2(0.72, 0.45), Vector2(0.5, 0.58),
				Vector2(0.28, 0.45)], color)
			_rect(o, s, Rect2(0.44, 0.55, 0.12, 0.2), color)
			_rect(o, s, Rect2(0.28, 0.75, 0.44, 0.14), color)
		&"stairs":
			for i in 4:
				_rect(o, s, Rect2(0.1 + i * 0.2, 0.18 + i * 0.18, 0.8 - i * 0.2, 0.18), color.darkened(i * 0.12))
		&"vending":
			_rect(o, s, Rect2(0.2, 0.05, 0.6, 0.9), color)
			_rect(o, s, Rect2(0.27, 0.12, 0.3, 0.6), c2)
			for i in 3:
				_rect(o, s, Rect2(0.62, 0.15 + i * 0.12, 0.12, 0.07), c2)
			_rect(o, s, Rect2(0.27, 0.78, 0.46, 0.08), c2)
		&"sword":
			_poly(o, s, [Vector2(0.82, 0.08), Vector2(0.92, 0.18), Vector2(0.38, 0.7), Vector2(0.28, 0.6)], color)
			_line(o, s, Vector2(0.18, 0.5), Vector2(0.5, 0.82), color, 0.08)
			_line(o, s, Vector2(0.3, 0.68), Vector2(0.1, 0.9), color, 0.1)
		&"shield":
			_poly(o, s, [Vector2(0.5, 0.06), Vector2(0.88, 0.2), Vector2(0.82, 0.62), Vector2(0.5, 0.94),
				Vector2(0.18, 0.62), Vector2(0.12, 0.2)], color)
			_poly(o, s, [Vector2(0.5, 0.18), Vector2(0.76, 0.28), Vector2(0.72, 0.58), Vector2(0.5, 0.8)],
				color.lightened(0.25))
		&"ring":
			_circle(o, s, Vector2(0.5, 0.58), 0.34, color)
			_circle(o, s, Vector2(0.5, 0.58), 0.22, c2)
			_poly(o, s, [Vector2(0.5, 0.06), Vector2(0.64, 0.2), Vector2(0.5, 0.32), Vector2(0.36, 0.2)],
				color.lightened(0.4))
		&"potion":
			_rect(o, s, Rect2(0.42, 0.06, 0.16, 0.22), color.lightened(0.3))
			_circle(o, s, Vector2(0.5, 0.62), 0.33, color)
			_circle(o, s, Vector2(0.4, 0.55), 0.08, color.lightened(0.5))
		&"camera":
			_rect(o, s, Rect2(0.08, 0.3, 0.6, 0.45), color)
			_poly(o, s, [Vector2(0.68, 0.42), Vector2(0.94, 0.28), Vector2(0.94, 0.78), Vector2(0.68, 0.64)], color)
			_circle(o, s, Vector2(0.2, 0.2), 0.1, color)
			_circle(o, s, Vector2(0.45, 0.2), 0.1, color)
		&"mic":
			_rect(o, s, Rect2(0.36, 0.06, 0.28, 0.5), color)
			_circle(o, s, Vector2(0.5, 0.08), 0.14, color)
			_line(o, s, Vector2(0.24, 0.46), Vector2(0.5, 0.7), color, 0.06)
			_line(o, s, Vector2(0.76, 0.46), Vector2(0.5, 0.7), color, 0.06)
			_rect(o, s, Rect2(0.46, 0.68, 0.08, 0.2), color)
			_rect(o, s, Rect2(0.3, 0.86, 0.4, 0.08), color)
		&"tv":
			_rect(o, s, Rect2(0.06, 0.2, 0.88, 0.62), color)
			_rect(o, s, Rect2(0.14, 0.28, 0.72, 0.46), c2)
			_line(o, s, Vector2(0.35, 0.04), Vector2(0.5, 0.2), color, 0.05)
			_line(o, s, Vector2(0.65, 0.04), Vector2(0.5, 0.2), color, 0.05)
			_rect(o, s, Rect2(0.3, 0.82, 0.4, 0.08), color)
		&"drone":
			var pts: PackedVector2Array = []
			for i in 6:
				var a: float = float(i) / 6.0 * TAU + PI / 6.0
				pts.append(_p(o, s, Vector2(0.5 + cos(a) * 0.36, 0.5 + sin(a) * 0.36)))
			_m.poly(pts, color)
			_circle(o, s, Vector2(0.5, 0.5), 0.12, c2)
			_circle(o, s, Vector2(0.5, 0.5), 0.06, Color("#ff2e88"))
		&"bark":                               # 06 package A: Graf Mopsula's bark — a snout and sound waves
			_circle(o, s, Vector2(0.2, 0.5), 0.14, color)
			_poly(o, s, [Vector2(0.24, 0.38), Vector2(0.42, 0.44), Vector2(0.42, 0.56), Vector2(0.24, 0.62)], color)
			for i in 3:
				var r: float = 0.2 + 0.15 * i
				for k in 5:
					var a0: float = -0.75 + 1.5 * float(k) / 5.0
					var a1: float = -0.75 + 1.5 * float(k + 1) / 5.0
					_line(o, s, Vector2(0.3 + cos(a0) * r, 0.5 + sin(a0) * r),
						Vector2(0.3 + cos(a1) * r, 0.5 + sin(a1) * r), color, 0.07)
		&"swap":                               # 06 package A: "Figur wechseln" — two opposed arrows
			_rect(o, s, Rect2(0.12, 0.26, 0.56, 0.12), color)
			_poly(o, s, [Vector2(0.62, 0.12), Vector2(0.9, 0.32), Vector2(0.62, 0.52)], color)
			_rect(o, s, Rect2(0.32, 0.62, 0.56, 0.12), color)
			_poly(o, s, [Vector2(0.38, 0.48), Vector2(0.1, 0.68), Vector2(0.38, 0.88)], color)
		_:
			_circle(o, s, Vector2(0.5, 0.5), 0.4, color)
	return _m


# --- primitives in unit space ----------------------------------------------------------------------------------------

func _p(o: Vector2, s: float, u: Vector2) -> Vector2:
	return o + u * s


func _circle(o: Vector2, s: float, c: Vector2, r: float, col: Color) -> void:
	_m.circle(_p(o, s, c), r * s, col, true)


func _rect(o: Vector2, s: float, r: Rect2, col: Color) -> void:
	_m.rect(Rect2(_p(o, s, r.position), r.size * s), col)


func _poly(o: Vector2, s: float, pts: Array[Vector2], col: Color) -> void:
	var out: PackedVector2Array = []
	for v: Vector2 in pts:
		out.append(_p(o, s, v))
	_m.poly(out, col)


func _line(o: Vector2, s: float, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	_m.line(_p(o, s, a), _p(o, s, b), col, maxf(w * s, 1.0), true)


func _rot_rect(c: Vector2, sz: Vector2, a: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for corner: Vector2 in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]:
		out.append(c + (corner * sz).rotated(a))
	return out
