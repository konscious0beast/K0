extends RefCounted
## Vector symbols of the real-time combat (07 §4.6 "icon", §8.2, §8.4): every id of RtVocab.ICON_IDS ("R3 zeichnet
## jede Id"), drawn as primitives into an IconMesh (scenes/ui/icon_mesh.gd) so a caller collects the frames AND the
## symbols of several slots into ONE triangle array = one canvas draw call (07 §8.2, §8.10). Symbols follow the
## "Symbol-Idee" of 07 §4.2/§4.3 (no crown motif for Graf Mopsula, 06 §3.2) and 03_ART F8 (drawn, never font
## glyphs). Private R3 helper.

const IconMesh := preload("res://scenes/ui/icon_mesh.gd")

const C_INK: Color = Color("#140d1c")
const C_PAPER: Color = Color("#f5f0e6")
const C_WOOD: Color = Color("#b9824a")
const C_MOP: Color = Color("#e9e3d3")
const C_RED: Color = Color("#e8455a")
const C_GOLD: Color = Color("#ffc93c")
const C_CYAN: Color = Color("#22d3ee")
const C_PINK: Color = Color("#ff7fb0")
const C_PURPLE: Color = Color("#9b5cff")
const C_GREEN: Color = Color("#7cc242")
const C_BLUE: Color = Color("#5b8def")
const C_ICE: Color = Color("#9fe3ff")
const C_FIRE: Color = Color("#ff7a1a")
const C_FIRE_HI: Color = Color("#ffd166")
const C_GREY: Color = Color("#9aa7b8")
const C_DARK: Color = Color("#3a3248")


## A pen over the unit square of `r` (x right, y down, 0..1).
class Pen:
	var m: IconMesh
	var o: Vector2
	var s: float

	func _init(p_m: IconMesh, r: Rect2) -> void:
		m = p_m
		s = minf(r.size.x, r.size.y)
		o = r.position + (r.size - Vector2(s, s)) * 0.5

	func p(x: float, y: float) -> Vector2:
		return o + Vector2(x, y) * s

	func circle(x: float, y: float, r: float, col: Color) -> void:
		m.circle(p(x, y), r * s, col, true)

	func ring(x: float, y: float, r: float, w: float, col: Color) -> void:
		m.ring(p(x, y), r * s, col, maxf(w * s, 1.0), true)

	func rect(x: float, y: float, w: float, h: float, col: Color) -> void:
		m.rect(Rect2(p(x, y), Vector2(w, h) * s), col)

	func poly(pts: Array, col: Color) -> void:
		var out: PackedVector2Array = PackedVector2Array()
		for v: Variant in pts:
			var u: Vector2 = v
			out.append(p(u.x, u.y))
		m.poly(out, col)

	func line(ax: float, ay: float, bx: float, by: float, w: float, col: Color) -> void:
		m.line(p(ax, ay), p(bx, by), col, maxf(w * s, 1.0), true)

	## Arc polyline from angle a0 to a1 (radians, 0 = right, clockwise on screen).
	func arc(x: float, y: float, r: float, a0: float, a1: float, w: float, col: Color, seg: int = 10) -> void:
		for i in seg:
			var t0: float = lerpf(a0, a1, float(i) / float(seg))
			var t1: float = lerpf(a0, a1, float(i + 1) / float(seg))
			line(x + cos(t0) * r, y + sin(t0) * r, x + cos(t1) * r, y + sin(t1) * r, w, col)

	func star(x: float, y: float, r_out: float, r_in: float, n: int, col: Color, rot: float = -PI * 0.5) -> void:
		var pts: Array = []
		for i in n * 2:
			var a: float = rot + PI * float(i) / float(n)
			var rr: float = r_out if i % 2 == 0 else r_in
			pts.append(Vector2(x + cos(a) * rr, y + sin(a) * rr))
		poly(pts, col)

	func flame(x: float, y: float, w: float, h: float, col: Color, hi: Color) -> void:
		poly([Vector2(x, y - h), Vector2(x + w * 0.42, y - h * 0.35), Vector2(x + w * 0.5, y + h * 0.05),
			Vector2(x + w * 0.3, y + h * 0.32), Vector2(x, y + h * 0.4), Vector2(x - w * 0.3, y + h * 0.32),
			Vector2(x - w * 0.5, y + h * 0.05), Vector2(x - w * 0.36, y - h * 0.42), Vector2(x - w * 0.12, y - h * 0.2)],
			col)
		poly([Vector2(x + w * 0.02, y - h * 0.35), Vector2(x + w * 0.24, y + h * 0.05), Vector2(x, y + h * 0.3),
			Vector2(x - w * 0.24, y + h * 0.05)], hi)

	func drop(x: float, y: float, r: float, col: Color) -> void:
		circle(x, y + r * 0.35, r, col)
		poly([Vector2(x, y - r * 1.45), Vector2(x + r * 0.86, y - r * 0.05), Vector2(x - r * 0.86, y - r * 0.05)], col)

	func snowflake(x: float, y: float, r: float, w: float, col: Color) -> void:
		for i in 3:
			var a: float = PI * float(i) / 3.0 + PI * 0.5
			line(x - cos(a) * r, y - sin(a) * r, x + cos(a) * r, y + sin(a) * r, w, col)
		circle(x, y, w * 0.9, col)


## All drawable ids (RtVocab.ICON_IDS + the CTB status id "taunt").
static func kinds() -> PackedStringArray:
	var out: PackedStringArray = RtVocab.ICON_IDS.duplicate()
	out.append("taunt")
	return out


static func is_known(kind: String) -> bool:
	return kind == "taunt" or RtVocab.ICON_IDS.has(kind)


## Draws `kind` into `r` of `m` (unknown ids → "generic"). `tint` (alpha > 0) recolours the main shape (status rows use
## the status colour); details keep their own colours.
static func draw(m: IconMesh, kind: String, r: Rect2, tint: Color = Color(0, 0, 0, 0)) -> void:
	var g: Pen = Pen.new(m, r)
	var t: bool = tint.a > 0.0
	match kind:
		# --- Kai (07 §4.2) -------------------------------------------------------------------------------------------
		"mop_swing":
			g.line(0.86, 0.1, 0.4, 0.62, 0.09, C_WOOD)
			g.poly([Vector2(0.18, 0.62), Vector2(0.46, 0.5), Vector2(0.58, 0.66), Vector2(0.36, 0.92), Vector2(0.1, 0.86)],
				tint if t else C_MOP)
			for i in 3:
				g.line(0.18 + i * 0.1, 0.72 + i * 0.03, 0.12 + i * 0.1, 0.94, 0.04, C_DARK)
			for i in 3:
				g.arc(0.42, 0.52, 0.36 + i * 0.1, -1.25, -0.55, 0.04, C_CYAN, 6)
		"mop_circle":
			g.line(0.5, 0.18, 0.5, 0.62, 0.08, C_WOOD)
			g.poly([Vector2(0.32, 0.6), Vector2(0.68, 0.6), Vector2(0.62, 0.8), Vector2(0.38, 0.8)], tint if t else C_MOP)
			g.arc(0.5, 0.52, 0.42, -2.6, 2.1, 0.07, C_CYAN, 18)
			g.poly([Vector2(0.84, 0.92), Vector2(0.98, 0.74), Vector2(0.74, 0.74)], C_CYAN)
		"megaphone_notes":
			g.poly([Vector2(0.08, 0.42), Vector2(0.2, 0.42), Vector2(0.56, 0.18), Vector2(0.56, 0.82), Vector2(0.2, 0.58),
				Vector2(0.08, 0.58)], tint if t else C_RED)
			g.rect(0.14, 0.58, 0.08, 0.2, C_GREY)
			for n: Vector2 in [Vector2(0.72, 0.3), Vector2(0.86, 0.62)]:
				g.circle(n.x, n.y, 0.07, C_GOLD)
				g.line(n.x + 0.06, n.y, n.x + 0.06, n.y - 0.24, 0.04, C_GOLD)
				g.line(n.x + 0.06, n.y - 0.24, n.x + 0.14, n.y - 0.18, 0.04, C_GOLD)
		"paw_plaster":
			g.poly([Vector2(0.18, 0.62), Vector2(0.62, 0.18), Vector2(0.82, 0.38), Vector2(0.38, 0.82)],
				tint if t else Color("#f3c99a"))
			g.poly([Vector2(0.38, 0.5), Vector2(0.5, 0.38), Vector2(0.62, 0.5), Vector2(0.5, 0.62)], Color("#ffe8d0"))
			g.circle(0.5, 0.53, 0.06, C_RED)
			for v: Vector2 in [Vector2(0.43, 0.43), Vector2(0.52, 0.41), Vector2(0.59, 0.47)]:
				g.circle(v.x, v.y, 0.025, C_RED)
		"leash_lasso":
			# a flat swinging loop (an ellipse, never a lens) + the wavy leash down to Kai's hand
			var rope: Color = tint if t else C_PINK
			for i in 14:
				var a0: float = TAU * float(i) / 14.0
				var a1: float = TAU * float(i + 1) / 14.0
				g.line(0.6 + cos(a0) * 0.3, 0.3 + sin(a0) * 0.15, 0.6 + cos(a1) * 0.3, 0.3 + sin(a1) * 0.15, 0.07, rope)
			var wave: Array = [Vector2(0.38, 0.42), Vector2(0.28, 0.56), Vector2(0.4, 0.68), Vector2(0.26, 0.82),
				Vector2(0.12, 0.88)]
			for i in wave.size() - 1:
				var u: Vector2 = wave[i]
				var v: Vector2 = wave[i + 1]
				g.line(u.x, u.y, v.x, v.y, 0.06, rope)
			g.circle(0.38, 0.42, 0.07, C_GOLD)
			g.arc(0.6, 0.3, 0.42, -0.5, 0.7, 0.035, C_CYAN, 6)
		"cable_sparks":
			g.arc(0.3, 0.58, 0.24, -1.6, 1.4, 0.08, tint if t else C_DARK, 10)
			g.line(0.32, 0.82, 0.86, 0.82, 0.08, tint if t else C_DARK)
			g.rect(0.22, 0.28, 0.14, 0.12, C_GREY)
			g.star(0.62, 0.3, 0.2, 0.08, 4, C_GOLD)
			g.star(0.84, 0.56, 0.11, 0.04, 4, C_FIRE_HI)
		"spray_flame":
			g.rect(0.1, 0.42, 0.24, 0.48, tint if t else C_CYAN)
			g.rect(0.14, 0.32, 0.16, 0.1, C_GREY)
			g.poly([Vector2(0.34, 0.46), Vector2(0.94, 0.22), Vector2(0.94, 0.7)], C_FIRE)
			g.poly([Vector2(0.38, 0.46), Vector2(0.8, 0.34), Vector2(0.8, 0.58)], C_FIRE_HI)
		"wrestler_stars":
			g.circle(0.5, 0.36, 0.14, tint if t else C_GOLD)
			g.poly([Vector2(0.24, 0.92), Vector2(0.28, 0.6), Vector2(0.5, 0.52), Vector2(0.72, 0.6), Vector2(0.76, 0.92)],
				tint if t else C_GOLD)
			g.rect(0.4, 0.66, 0.2, 0.08, C_RED)
			g.star(0.18, 0.2, 0.11, 0.045, 5, C_PAPER)
			g.star(0.84, 0.16, 0.09, 0.037, 5, C_PAPER)
			g.star(0.86, 0.46, 0.07, 0.03, 5, C_PAPER)
		"studio_camera":
			g.rect(0.14, 0.34, 0.54, 0.4, tint if t else C_DARK)
			g.rect(0.18, 0.38, 0.46, 0.32, C_GREY)
			g.poly([Vector2(0.68, 0.42), Vector2(0.92, 0.3), Vector2(0.92, 0.8), Vector2(0.68, 0.66)], C_DARK)
			g.circle(0.41, 0.54, 0.11, C_INK)
			g.circle(0.41, 0.54, 0.06, C_CYAN)
			g.poly([Vector2(0.62, 0.02), Vector2(0.42, 0.26), Vector2(0.54, 0.26), Vector2(0.46, 0.4), Vector2(0.7, 0.16),
				Vector2(0.58, 0.16)], C_GOLD)
		# --- Graf Mopsula (07 §4.3; Monokel, Siegel-Plakette, Umhang, Zunge) ------------------------------------------
		"monocle_beam":
			g.ring(0.3, 0.4, 0.17, 0.06, tint if t else C_GOLD)
			g.circle(0.3, 0.4, 0.12, Color(C_ICE, 0.55))
			g.line(0.3, 0.58, 0.2, 0.9, 0.03, C_GOLD)
			g.poly([Vector2(0.44, 0.34), Vector2(0.96, 0.18), Vector2(0.96, 0.4), Vector2(0.44, 0.46)], Color(C_PAPER, 0.85))
		"seal_flame":
			g.circle(0.5, 0.7, 0.22, tint if t else C_GOLD)
			g.circle(0.5, 0.7, 0.14, Color("#c9962a"))
			g.star(0.5, 0.7, 0.1, 0.05, 5, C_GOLD)
			g.flame(0.5, 0.36, 0.42, 0.34, C_FIRE, C_FIRE_HI)
		"tongue_glitter":
			g.poly([Vector2(0.3, 0.16), Vector2(0.7, 0.16), Vector2(0.72, 0.62), Vector2(0.5, 0.86), Vector2(0.28, 0.62)],
				tint if t else C_PINK)
			g.line(0.5, 0.24, 0.5, 0.6, 0.04, Color("#d4507f"))
			g.star(0.84, 0.24, 0.12, 0.04, 4, C_PAPER)
			g.star(0.14, 0.5, 0.08, 0.03, 4, C_PAPER)
			g.star(0.82, 0.7, 0.07, 0.025, 4, C_GOLD)
		"two_tongues":
			for dx: float in [0.0, 0.34]:
				g.poly([Vector2(0.12 + dx, 0.26), Vector2(0.44 + dx, 0.26), Vector2(0.46 + dx, 0.62),
					Vector2(0.28 + dx, 0.84), Vector2(0.1 + dx, 0.62)], tint if t else C_PINK)
				g.line(0.28 + dx, 0.32, 0.28 + dx, 0.6, 0.035, Color("#d4507f"))
			g.star(0.5, 0.12, 0.09, 0.03, 4, C_PAPER)
		"drool_halo":
			g.drop(0.5, 0.6, 0.22, tint if t else C_ICE)
			g.circle(0.44, 0.62, 0.05, C_PAPER)
			g.ring(0.5, 0.14, 0.22, 0.05, C_GOLD)
		"pug_nose_ice":
			g.circle(0.42, 0.56, 0.3, tint if t else Color("#c79b6d"))
			g.circle(0.42, 0.5, 0.17, C_INK)
			g.circle(0.35, 0.52, 0.05, Color("#5a4636"))
			g.circle(0.49, 0.52, 0.05, Color("#5a4636"))
			g.snowflake(0.8, 0.24, 0.16, 0.05, C_ICE)
		"scroll_seal":
			g.rect(0.18, 0.2, 0.64, 0.6, tint if t else Color("#f3e3b8"))
			g.rect(0.12, 0.14, 0.76, 0.1, Color("#d9c18b"))
			g.rect(0.12, 0.76, 0.76, 0.1, Color("#d9c18b"))
			for i in 3:
				g.line(0.28, 0.34 + i * 0.1, 0.72, 0.34 + i * 0.1, 0.03, C_DARK)
			g.circle(0.66, 0.66, 0.11, C_RED)
		"bark_bolt":
			for i in 3:
				g.arc(0.2, 0.5, 0.2 + 0.15 * i, -0.8, 0.8, 0.06, tint if t else C_PURPLE, 8)
			g.poly([Vector2(0.66, 0.04), Vector2(0.46, 0.5), Vector2(0.6, 0.5), Vector2(0.5, 0.96), Vector2(0.86, 0.38),
				Vector2(0.7, 0.38)], C_GOLD)
		"cape_spotlight":
			g.poly([Vector2(0.4, 0.0), Vector2(0.6, 0.0), Vector2(0.96, 0.96), Vector2(0.04, 0.96)], Color(C_FIRE_HI, 0.35))
			g.poly([Vector2(0.5, 0.36), Vector2(0.78, 0.92), Vector2(0.22, 0.92)], tint if t else C_PURPLE)
			g.circle(0.5, 0.36, 0.13, Color("#c79b6d"))
			g.circle(0.55, 0.34, 0.045, C_GOLD)
		"monocle_flames":
			g.ring(0.5, 0.5, 0.36, 0.08, tint if t else C_GOLD)
			g.flame(0.5, 0.56, 0.42, 0.42, C_FIRE, C_FIRE_HI)
			g.line(0.5, 0.86, 0.38, 0.98, 0.04, C_GOLD)
		# --- potion key + consumables (07 §4.5) ----------------------------------------------------------------------
		"potion":
			g.rect(0.42, 0.06, 0.16, 0.16, Color("#b9824a"))
			g.rect(0.38, 0.2, 0.24, 0.14, C_GREY)
			g.circle(0.5, 0.62, 0.3, tint if t else C_RED)
			g.circle(0.4, 0.54, 0.07, Color(C_PAPER, 0.7))
		"bandage":
			g.poly([Vector2(0.12, 0.58), Vector2(0.58, 0.12), Vector2(0.88, 0.42), Vector2(0.42, 0.88)],
				tint if t else Color("#f3c99a"))
			g.poly([Vector2(0.36, 0.5), Vector2(0.5, 0.36), Vector2(0.64, 0.5), Vector2(0.5, 0.64)], Color("#ffe8d0"))
			g.rect(0.47, 0.42, 0.06, 0.16, C_RED)
			g.rect(0.42, 0.47, 0.16, 0.06, C_RED)
		"burger":
			g.poly([Vector2(0.12, 0.44), Vector2(0.2, 0.2), Vector2(0.5, 0.12), Vector2(0.8, 0.2), Vector2(0.88, 0.44)],
				tint if t else Color("#e3a04f"))
			g.rect(0.1, 0.44, 0.8, 0.07, C_GREEN)
			g.rect(0.12, 0.5, 0.76, 0.14, Color("#6b3b22"))
			g.rect(0.12, 0.64, 0.76, 0.06, C_GOLD)
			g.rect(0.14, 0.7, 0.72, 0.14, Color("#e3a04f"))
		"antidote":
			g.rect(0.4, 0.08, 0.2, 0.18, C_GREY)
			g.rect(0.26, 0.26, 0.48, 0.64, tint if t else C_GREEN)
			g.rect(0.45, 0.42, 0.1, 0.32, C_PAPER)
			g.rect(0.34, 0.53, 0.32, 0.1, C_PAPER)
		"can":
			g.rect(0.28, 0.1, 0.44, 0.82, tint if t else C_GOLD)
			for i in 3:
				g.rect(0.28, 0.24 + i * 0.22, 0.44, 0.07, C_INK)
			g.rect(0.32, 0.06, 0.36, 0.06, C_GREY)
		"salts":
			g.rect(0.3, 0.46, 0.4, 0.46, tint if t else Color("#d9f2ff"))
			g.rect(0.34, 0.38, 0.32, 0.1, C_PURPLE)
			for i in 3:
				g.arc(0.3 + i * 0.2, 0.22, 0.1, PI, TAU, 0.04, C_CYAN, 5)
		"molotov":
			g.rect(0.3, 0.38, 0.4, 0.54, tint if t else Color("#4f8a3a"))
			g.rect(0.42, 0.22, 0.16, 0.18, Color("#4f8a3a"))
			g.rect(0.44, 0.14, 0.12, 0.1, C_PAPER)
			g.flame(0.5, 0.12, 0.3, 0.26, C_FIRE, C_FIRE_HI)
		"ice_spray":
			g.rect(0.14, 0.4, 0.26, 0.52, tint if t else C_BLUE)
			g.rect(0.18, 0.3, 0.18, 0.1, C_GREY)
			g.snowflake(0.7, 0.36, 0.2, 0.055, C_ICE)
			g.circle(0.52, 0.42, 0.04, C_ICE)
		"smoke":
			for v: Vector3 in [Vector3(0.32, 0.6, 0.2), Vector3(0.56, 0.5, 0.25), Vector3(0.72, 0.66, 0.18),
					Vector3(0.48, 0.72, 0.2)]:
				g.circle(v.x, v.y, v.z, tint if t else C_GREY)
			g.circle(0.5, 0.48, 0.12, Color("#c9d1dc"))
		"megaphone":
			g.poly([Vector2(0.1, 0.4), Vector2(0.24, 0.4), Vector2(0.78, 0.14), Vector2(0.78, 0.86), Vector2(0.24, 0.6),
				Vector2(0.1, 0.6)], tint if t else C_GOLD)
			g.rect(0.18, 0.6, 0.1, 0.22, C_DARK)
			g.arc(0.78, 0.5, 0.16, -1.0, 1.0, 0.04, C_PAPER, 6)
		"elixir":
			g.rect(0.42, 0.06, 0.16, 0.14, C_GOLD)
			g.poly([Vector2(0.38, 0.2), Vector2(0.62, 0.2), Vector2(0.84, 0.6), Vector2(0.5, 0.94), Vector2(0.16, 0.6)],
				tint if t else C_PURPLE)
			g.star(0.5, 0.58, 0.16, 0.07, 5, C_GOLD)
		# --- status symbols (07 §8.4) ---------------------------------------------------------------------------------
		"poison", "toxic":
			g.drop(0.5, 0.5, 0.3, tint if t else C_GREEN)
			g.circle(0.4, 0.58, 0.07, Color(C_PAPER, 0.75))
			g.circle(0.78, 0.2, 0.08, tint if t else C_GREEN)
		"stun":
			g.star(0.5, 0.52, 0.46, 0.2, 5, tint if t else Color("#f5d90a"))
			g.circle(0.5, 0.55, 0.08, C_INK)
		"slow":
			g.poly([Vector2(0.2, 0.08), Vector2(0.8, 0.08), Vector2(0.56, 0.5), Vector2(0.8, 0.92), Vector2(0.2, 0.92),
				Vector2(0.44, 0.5)], tint if t else C_BLUE)
			g.poly([Vector2(0.36, 0.82), Vector2(0.64, 0.82), Vector2(0.5, 0.62)], C_PAPER)
		"haste":
			for dx: float in [0.0, 0.34]:
				g.poly([Vector2(0.1 + dx, 0.14), Vector2(0.34 + dx, 0.14), Vector2(0.62 + dx, 0.5), Vector2(0.34 + dx, 0.86),
					Vector2(0.1 + dx, 0.86), Vector2(0.38 + dx, 0.5)], tint if t else C_FIRE)
		"guard":
			g.poly([Vector2(0.5, 0.06), Vector2(0.88, 0.2), Vector2(0.82, 0.62), Vector2(0.5, 0.94), Vector2(0.18, 0.62),
				Vector2(0.12, 0.2)], tint if t else C_GREY)
			g.poly([Vector2(0.5, 0.18), Vector2(0.76, 0.28), Vector2(0.72, 0.58), Vector2(0.5, 0.8)],
				Color(C_PAPER, 0.45))
		"taunted", "taunt":
			g.ring(0.5, 0.5, 0.34, 0.09, tint if t else C_RED)
			g.line(0.5, 0.02, 0.5, 0.3, 0.08, tint if t else C_RED)
			g.line(0.5, 0.7, 0.5, 0.98, 0.08, tint if t else C_RED)
			g.line(0.02, 0.5, 0.3, 0.5, 0.08, tint if t else C_RED)
			g.line(0.7, 0.5, 0.98, 0.5, 0.08, tint if t else C_RED)
			g.circle(0.5, 0.5, 0.08, tint if t else C_RED)
		"light_feet":                      # R5b (E31): Leichtfüßig — a feather with two speed lines
			var fc: Color = tint if t else Color("#7fe3d0")
			g.poly([Vector2(0.86, 0.1), Vector2(0.62, 0.2), Vector2(0.4, 0.42), Vector2(0.3, 0.66), Vector2(0.38, 0.7),
				Vector2(0.56, 0.6), Vector2(0.78, 0.38)], fc)
			g.line(0.86, 0.1, 0.22, 0.86, 0.05, C_PAPER)
			g.line(0.08, 0.6, 0.26, 0.6, 0.05, Color(fc, 0.8))
			g.line(0.14, 0.76, 0.3, 0.76, 0.05, Color(fc, 0.8))
		"dazed":
			g.ring(0.5, 0.56, 0.3, 0.05, Color(tint if t else Color("#c9b8ff"), 0.6))
			for i in 3:
				var a: float = TAU * float(i) / 3.0 - 0.6
				g.star(0.5 + cos(a) * 0.3, 0.56 + sin(a) * 0.3 * 0.55, 0.14, 0.06, 5, tint if t else Color("#c9b8ff"))
		"regen":
			g.arc(0.5, 0.5, 0.38, -2.4, 2.0, 0.08, tint if t else C_GREEN, 14)
			g.poly([Vector2(0.18, 0.04), Vector2(0.36, 0.24), Vector2(0.1, 0.3)], tint if t else C_GREEN)
			g.rect(0.44, 0.3, 0.12, 0.4, C_PAPER)
			g.rect(0.3, 0.44, 0.4, 0.12, C_PAPER)
		"burn", "fire":
			g.flame(0.5, 0.56, 0.72, 0.84, tint if t else C_FIRE, C_FIRE_HI)
		"admonished":
			g.rect(0.18, 0.08, 0.6, 0.84, tint if t else C_PAPER)
			for i in 4:
				g.line(0.28, 0.24 + i * 0.12, 0.66, 0.24 + i * 0.12, 0.035, C_DARK)
			g.ring(0.68, 0.72, 0.18, 0.06, C_RED)
			g.line(0.56, 0.84, 0.8, 0.6, 0.06, C_RED)
		"dizzy":
			var col_d: Color = tint if t else Color("#c084fc")
			for i in 4:
				g.arc(0.5, 0.5, 0.1 + 0.1 * i, float(i) * 1.6, float(i) * 1.6 + 4.2, 0.07, col_d, 8)
		"enrage":
			var col_e: Color = tint if t else C_RED
			for i in 4:
				var a2: float = PI * 0.5 * float(i) + PI * 0.25
				g.arc(0.5 + cos(a2) * 0.3, 0.5 + sin(a2) * 0.3, 0.2, a2 + PI * 0.55, a2 + PI * 1.45, 0.1, col_e, 6)
		# --- enemies / generic ---------------------------------------------------------------------------------------
		"claw":
			for i in 3:
				g.line(0.22 + i * 0.2, 0.1, 0.06 + i * 0.22, 0.9, 0.08, tint if t else C_PAPER)
		"bite":
			g.arc(0.5, 0.3, 0.38, 0.35, PI - 0.35, 0.09, tint if t else C_PAPER, 10)
			g.arc(0.5, 0.74, 0.38, PI + 0.35, TAU - 0.35, 0.09, tint if t else C_PAPER, 10)
			for i in 4:
				g.poly([Vector2(0.24 + i * 0.16, 0.48), Vector2(0.32 + i * 0.16, 0.48), Vector2(0.28 + i * 0.16, 0.6)],
					C_PAPER)
		"bolt":
			g.poly([Vector2(0.6, 0.02), Vector2(0.2, 0.56), Vector2(0.46, 0.56), Vector2(0.34, 0.98), Vector2(0.82, 0.4),
				Vector2(0.56, 0.4)], tint if t else Color("#f5e642"))
		"ice":
			g.snowflake(0.5, 0.5, 0.42, 0.09, tint if t else C_ICE)
		"train":
			g.rect(0.16, 0.12, 0.68, 0.72, tint if t else C_RED)
			g.rect(0.24, 0.2, 0.52, 0.26, Color("#cfe9ff"))
			g.circle(0.3, 0.68, 0.07, C_GOLD)
			g.circle(0.7, 0.68, 0.07, C_GOLD)
			g.rect(0.22, 0.84, 0.12, 0.1, C_DARK)
			g.rect(0.66, 0.84, 0.12, 0.1, C_DARK)
		"whistle":
			g.circle(0.38, 0.6, 0.26, tint if t else C_GREY)
			g.rect(0.38, 0.34, 0.54, 0.22, tint if t else C_GREY)
			g.circle(0.36, 0.6, 0.09, C_INK)
			g.ring(0.2, 0.26, 0.1, 0.04, C_GOLD)
		"ticket":
			g.poly([Vector2(0.06, 0.28), Vector2(0.94, 0.28), Vector2(0.94, 0.44), Vector2(0.88, 0.5), Vector2(0.94, 0.56),
				Vector2(0.94, 0.72), Vector2(0.06, 0.72), Vector2(0.06, 0.56), Vector2(0.12, 0.5), Vector2(0.06, 0.44)],
				tint if t else C_GOLD)
			for i in 3:
				g.line(0.24, 0.4 + i * 0.1, 0.64, 0.4 + i * 0.1, 0.03, C_DARK)
		_:
			g.circle(0.5, 0.5, 0.4, tint if t else C_GREY)
			g.star(0.5, 0.52, 0.26, 0.11, 5, C_PAPER)


## Builds one icon alone (galleries, tests).
static func mesh_of(kind: String, r: Rect2, tint: Color = Color(0, 0, 0, 0)) -> IconMesh:
	var m: IconMesh = IconMesh.new()
	draw(m, kind, r, tint)
	return m


## Desaturates and tints the vertex colours from index `from` on (07 §8.2 "zu wenig MP": entsättigt + Blau-Tönung;
## "kein gültiges Ziel": gedimmt). amount 0..1 desaturation, `tint` mixed in by its alpha, `dim` multiplies alpha.
static func recolor(m: IconMesh, from: int, amount: float, tint: Color = Color(0, 0, 0, 0), dim: float = 1.0) -> void:
	var cols: PackedColorArray = m.colors
	for i in range(from, cols.size()):
		var c: Color = cols[i]
		var lum: float = c.get_luminance()
		var g: Color = Color(lum, lum, lum, c.a)
		var out: Color = c.lerp(g, amount)
		if tint.a > 0.0:
			out = Color(out.lerp(tint, tint.a), c.a)
		out.a = c.a * dim
		cols[i] = out
	m.colors = cols
