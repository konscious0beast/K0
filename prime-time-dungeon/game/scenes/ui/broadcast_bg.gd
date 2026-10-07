extends Control
## Private M6 backdrop for 2D screens (§0.3): ink background, studio light beams in NOVA magenta / cyan, perspective
## floor grid and a slow light sweep (03_ART §9: TV broadcast look). Pure _draw → identical in both renderers.

@export var accent: Color = Color("#ff2e88")
@export var accent_2: Color = Color("#22d3ee")
@export var animate: bool = true
@export var grid: bool = true

var _t: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	if not animate:
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 2.0 or h < 2.0:
		return                     # not laid out yet (first frame inside a container)
	draw_rect(Rect2(0, 0, w, h), Color("#140d1c"), true)
	# Soft vertical gradient (top lighter violet).
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.65), Vector2(0, h * 0.65)]),
		PackedColorArray([Color("#2a1840"), Color("#22163a"), Color("#140d1c"), Color("#140d1c")]))
	# Light beams from the top.
	for i in 5:
		var fx: float = w * (0.08 + 0.21 * i) + sin(_t * 0.25 + i * 1.7) * 40.0
		var col: Color = accent if i % 2 == 0 else accent_2
		var spread: float = 140.0 + 40.0 * (i % 3)
		draw_polygon(PackedVector2Array([Vector2(fx - 8, -10), Vector2(fx + 8, -10), Vector2(fx + spread, h * 0.8),
			Vector2(fx - spread, h * 0.8)]), PackedColorArray([Color(col, 0.16), Color(col, 0.16), Color(col, 0.0),
			Color(col, 0.0)]))
	if grid:
		var horizon: float = h * 0.62
		var vp: Vector2 = Vector2(w * 0.5, horizon - h * 0.25)
		for i in range(-12, 13):
			var x: float = w * 0.5 + i * w * 0.09
			var a: Vector2 = vp.lerp(Vector2(x, h), (horizon - vp.y) / (h - vp.y))
			draw_line(a, Vector2(x, h), Color(accent_2, 0.10), 1.0, true)
		var scroll: float = fmod(_t * 0.15, 1.0)
		for j in 9:
			var f: float = pow((float(j) + scroll) / 9.0, 2.0)
			var y: float = lerpf(horizon, h, f)
			draw_line(Vector2(0, y), Vector2(w, y), Color(accent_2, 0.04 + 0.10 * f), 1.0)
		draw_line(Vector2(0, horizon), Vector2(w, horizon), Color(accent, 0.35), 2.0)
	# Sweep.
	var sx: float = fmod(_t * 120.0, w + 600.0) - 300.0
	draw_polygon(PackedVector2Array([Vector2(sx, 0), Vector2(sx + 120, 0), Vector2(sx - 80, h), Vector2(sx - 200, h)]),
		PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.035), Color(1, 1, 1, 0.035), Color(1, 1, 1, 0.0)]))
