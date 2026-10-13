extends Control
## Backdrop of the Stempelduell table (10 §4.1): the studio in the style of broadcast_bg.gd — ink, light cones in
## magenta and cyan — with the counter edge ("Schalterkante") behind the hand and a desk mat in the equipped cosmetic
## colour. Static: drawn once per resize, no _process (10 §6.10 "kein _process im Leerlauf").

const MATS: Dictionary = {"": Color("#1d1430"), "sdk_mat_umlaufmappe": Color("#3a2a14"),
	"sdk_mat_gummibaum": Color("#14301f")}

var mat: String = "":
	set(v):
		mat = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 2.0 or h < 2.0:
		return
	draw_rect(Rect2(0, 0, w, h), Color("#140d1c"), true)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.6), Vector2(0, h * 0.6)]),
		PackedColorArray([Color("#2a1840"), Color("#22163a"), Color("#140d1c"), Color("#140d1c")]))
	for i in 4:
		var fx: float = w * (0.12 + 0.25 * i)
		var col: Color = Color("#ff2e88") if i % 2 == 0 else Color("#22d3ee")
		draw_polygon(PackedVector2Array([Vector2(fx - 6, -10), Vector2(fx + 6, -10), Vector2(fx + 150, h * 0.7),
			Vector2(fx - 150, h * 0.7)]), PackedColorArray([Color(col, 0.12), Color(col, 0.12), Color(col, 0.0),
			Color(col, 0.0)]))
	var desk_y: float = h * 0.56
	var mat_col: Color = MATS.get(mat, MATS[""]) as Color
	draw_rect(Rect2(0, desk_y, w, h - desk_y), mat_col, true)
	draw_rect(Rect2(0, desk_y - 6.0, w, 6.0), Color("#3a3248"), true)
	draw_rect(Rect2(0, desk_y - 8.0, w, 2.0), Color("#ffc93c", 0.35), true)
