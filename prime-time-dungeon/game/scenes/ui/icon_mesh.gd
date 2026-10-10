extends RefCounted
## One-draw-call vector icons (02_TECH §12.1, 03_ART §9.2), private helper of UiIcon (M6) and HudStyle.Icon (M5).
## Measured 4.7.2 (Compatibility and Mobile alike): every CanvasItem.draw_colored_polygon / draw_circle / draw_polyline
## and every wide draw_line is its own canvas draw call — polygons never batch — so a 4–8 primitive icon cost 4–11 draw
## calls. IconMesh collects the primitives of one icon in drawing order and submits them as ONE triangle array
## (RenderingServer.canvas_item_add_triangle_array): same shapes, colours and order. Filled polygons and rects stay
## unantialiased like draw_colored_polygon / draw_rect; antialiased circles, lines and outlines get a 1 px alpha feather
## like Godot's antialiased variants.

const FEATHER: float = 1.0               # local units of the alpha falloff on antialiased edges
const CIRCLE_SEGMENTS: int = 32          # icons are ≤ 64 px: 32 segments are visually round

var points: PackedVector2Array = PackedVector2Array()
var colors: PackedColorArray = PackedColorArray()
var indices: PackedInt32Array = PackedInt32Array()


func is_empty() -> bool:
	return indices.is_empty()


## Filled polygon without antialiasing (draw_colored_polygon). Invalid / degenerate polygons draw nothing.
func poly(pts: PackedVector2Array, col: Color) -> void:
	if pts.size() < 3 or col.a <= 0.0:
		return
	var tri: PackedInt32Array = Geometry2D.triangulate_polygon(pts)
	if tri.is_empty():
		return
	var base: int = points.size()
	for p: Vector2 in pts:
		points.append(p)
		colors.append(col)
	for t: int in tri:
		indices.append(base + t)


## Filled polygon with one colour per vertex (draw_polygon(pts, cols)), no antialiasing.
func poly_colors(pts: PackedVector2Array, cols: PackedColorArray) -> void:
	if pts.size() < 3 or cols.size() != pts.size():
		return
	var tri: PackedInt32Array = Geometry2D.triangulate_polygon(pts)
	if tri.is_empty():
		return
	var base: int = points.size()
	points.append_array(pts)
	colors.append_array(cols)
	for t: int in tri:
		indices.append(base + t)


## Filled rect (draw_rect(r, col, true)).
func rect(r: Rect2, col: Color) -> void:
	poly(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), col)


## Rect outline (draw_rect(r, col, false, width)): a band of `width` centred on the edges, square corners.
func rect_outline(r: Rect2, col: Color, width: float = 1.0) -> void:
	var h: float = maxf(width, 1.0) * 0.5
	var p0: Vector2 = r.position
	var p1: Vector2 = r.end
	rect(Rect2(Vector2(p0.x - h, p0.y - h), Vector2(r.size.x + 2.0 * h, 2.0 * h)), col)
	rect(Rect2(Vector2(p0.x - h, p1.y - h), Vector2(r.size.x + 2.0 * h, 2.0 * h)), col)
	rect(Rect2(Vector2(p0.x - h, p0.y + h), Vector2(2.0 * h, r.size.y - 2.0 * h)), col)
	rect(Rect2(Vector2(p1.x - h, p0.y + h), Vector2(2.0 * h, r.size.y - 2.0 * h)), col)


## Filled circle (draw_circle); aa adds the outer feather ring.
func circle(center: Vector2, radius: float, col: Color, aa: bool = false) -> void:
	if radius <= 0.0 or col.a <= 0.0:
		return
	var ring: PackedVector2Array = PackedVector2Array()
	for i in CIRCLE_SEGMENTS:
		var a: float = TAU * float(i) / float(CIRCLE_SEGMENTS)
		ring.append(center + Vector2(cos(a), sin(a)) * radius)
	var base: int = points.size()
	points.append(center)
	colors.append(col)
	for p: Vector2 in ring:
		points.append(p)
		colors.append(col)
	for i in CIRCLE_SEGMENTS:
		indices.append(base)
		indices.append(base + 1 + i)
		indices.append(base + 1 + (i + 1) % CIRCLE_SEGMENTS)
	if aa:
		_feather(ring, col)


## Circle outline (draw_circle(c, r, col, false, width, aa)): band of `width` centred on the radius.
func ring(center: Vector2, radius: float, col: Color, width: float, aa: bool = false) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in CIRCLE_SEGMENTS:
		var a: float = TAU * float(i) / float(CIRCLE_SEGMENTS)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	polyline(pts, col, width, aa)


## Closed polyline of `width` centred on the loop `pts` (draw_polyline(loop, col, width, aa)); joints follow the
## averaged vertex normals like Godot's polyline; aa adds feathers on both sides.
func polyline(pts: PackedVector2Array, col: Color, width: float, aa: bool = false) -> void:
	if pts.size() < 2 or col.a <= 0.0:
		return
	var nrm: PackedVector2Array = _vertex_normals(pts)
	var h: float = maxf(width, 1.0) * 0.5
	var n: int = pts.size()
	var c0: Color = Color(col, 0.0)
	for i in n:
		var j: int = (i + 1) % n
		var oi: Vector2 = pts[i] + nrm[i] * h
		var oj: Vector2 = pts[j] + nrm[j] * h
		var ii: Vector2 = pts[i] - nrm[i] * h
		var ij: Vector2 = pts[j] - nrm[j] * h
		_quad(ii, ij, oj, oi, col, col, col, col)
		if aa:
			_quad(oi, oj, oj + nrm[j] * FEATHER, oi + nrm[i] * FEATHER, col, col, c0, c0)
			_quad(ij, ii, ii - nrm[i] * FEATHER, ij - nrm[j] * FEATHER, col, col, c0, c0)


## Appends all primitives of `other` (kept in order after the ones already collected).
func append(other: Object) -> void:
	var o_pts: PackedVector2Array = other.get("points")
	var o_cols: PackedColorArray = other.get("colors")
	var o_idx: PackedInt32Array = other.get("indices")
	var base: int = points.size()
	points.append_array(o_pts)
	colors.append_array(o_cols)
	for t: int in o_idx:
		indices.append(base + t)


## Line of `width` (draw_line); aa adds a feather along both long sides.
func line(a: Vector2, b: Vector2, col: Color, width: float, aa: bool = false) -> void:
	var d: Vector2 = b - a
	if d.length_squared() < 0.000001 or col.a <= 0.0:
		return
	var n: Vector2 = Vector2(-d.y, d.x).normalized() * maxf(width, 1.0) * 0.5
	var quad: PackedVector2Array = PackedVector2Array([a + n, b + n, b - n, a - n])
	poly(quad, col)
	if aa:
		var c0: Color = Color(col, 0.0)
		var f: Vector2 = n.normalized() * FEATHER
		_quad(a + n, b + n, b + n + f, a + n + f, col, col, c0, c0)
		_quad(b - n, a - n, a - n - f, b - n - f, col, col, c0, c0)


## Outer half of a closed antialiased polyline around `pts` (draw_polyline(loop, col, width, true) drawn BEFORE an
## opaque fill of the same polygon, which covers the inner half): band from the polygon out to width / 2 along the
## averaged vertex normals (the joint geometry of Godot's polyline) + the feather.
func outline(pts: PackedVector2Array, col: Color, width: float) -> void:
	if pts.size() < 3 or col.a <= 0.0:
		return
	var normals: PackedVector2Array = _vertex_normals(pts)
	var outer: PackedVector2Array = PackedVector2Array()
	for i in pts.size():
		outer.append(pts[i] + normals[i] * width * 0.5)
	var n: int = pts.size()
	for i in n:
		var j: int = (i + 1) % n
		_quad(pts[i], pts[j], outer[j], outer[i], col, col, col, col)
	_feather(outer, col, normals)


## Submits everything as one triangle array to `ci` (call inside its _draw) and clears the buffers.
func commit(ci: CanvasItem) -> void:
	if indices.is_empty() or ci == null:
		return
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), indices, points, colors)
	points = PackedVector2Array()
	colors = PackedColorArray()
	indices = PackedInt32Array()


# --- internals -----------------------------------------------------------------------------------------------------

func _quad(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, c0: Color, c1: Color, c2: Color, c3: Color) -> void:
	var base: int = points.size()
	points.append_array(PackedVector2Array([p0, p1, p2, p3]))
	colors.append_array(PackedColorArray([c0, c1, c2, c3]))
	indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))


## Alpha falloff band outside the closed loop `ring` (col → transparent over FEATHER).
func _feather(ring: PackedVector2Array, col: Color, normals: PackedVector2Array = PackedVector2Array()) -> void:
	var nrm: PackedVector2Array = normals if normals.size() == ring.size() else _vertex_normals(ring)
	var c0: Color = Color(col, 0.0)
	var n: int = ring.size()
	for i in n:
		var j: int = (i + 1) % n
		_quad(ring[i], ring[j], ring[j] + nrm[j] * FEATHER, ring[i] + nrm[i] * FEATHER, col, col, c0, c0)


## Outward unit normals per vertex (average of the two adjacent edge normals), any winding.
static func _vertex_normals(pts: PackedVector2Array) -> PackedVector2Array:
	var n: int = pts.size()
	var area2: float = 0.0
	for i in n:
		var j: int = (i + 1) % n
		area2 += pts[i].x * pts[j].y - pts[j].x * pts[i].y
	var sgn: float = 1.0 if area2 >= 0.0 else -1.0
	var edge_n: PackedVector2Array = PackedVector2Array()
	for i in n:
		var e: Vector2 = pts[(i + 1) % n] - pts[i]
		var en: Vector2 = Vector2(e.y, -e.x) * sgn
		edge_n.append(en.normalized() if en.length_squared() > 0.0 else Vector2.ZERO)
	var out: PackedVector2Array = PackedVector2Array()
	for i in n:
		var v: Vector2 = edge_n[(i - 1 + n) % n] + edge_n[i]
		out.append(v.normalized() if v.length_squared() > 0.000001 else edge_n[i])
	return out
