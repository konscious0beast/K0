extends Control
## The counter "SCHALTER" of the table (10 §4.2, §4.4): where played cards land — a small copy of the card (frame and
## band of its Formular-Art), its name and what it did ("−14 Geduld · WUNDER PUNKT", "Wiedervorlage: FERDI +3 WT",
## "abgeheftet: halber Ärger"), stamped in with a thump (1.3 → 1.0 in 0.12 s, the ink of the equipped stamp colour).
## Between plays it calls the number ("Nummer 007 — Sie sind dran."), shows "Ferdi überlegt …", the filing question or
## the Lernduell's task. One IconMesh + texts.

const SdStyle := preload("res://scenes/stempel/sd_style.gd")
const SdIcons := preload("res://scenes/stempel/sd_icons.gd")
const IconMesh := preload("res://scenes/ui/icon_mesh.gd")

var touch: bool = false
var text_size: int = 100
var compact: bool = false                           # without the title row (sd_layout.gd, large text)
var title: String = "SCHALTER"
var line1: String = ""
var line2: String = ""
var line2_color: Color = SdStyle.TEXT_DIM
var card: SdCardDef = null                          # the card on the counter (null: a call / message)
var by_player: bool = true
var filed: bool = false                             # the card was filed (grey "ABGEHEFTET" stamp)
var ink: Color = SdStyle.SEAL_RED
var thump: float = 0.0:                             # 0..1 stamp impact (scale 1.3 → 1.0)
	set(v):
		thump = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Height of the counter: the title (not in `compact`), the call / card line and the result line.
static func height(p_touch: bool, p_text_size: int, p_compact: bool) -> float:
	var m: Dictionary = _metrics(p_touch, p_text_size, p_compact)
	return ceilf(maxf(float(m["line2_bottom"]) + float(m["pad"]), 64.0))


## {"pad", "ts", "ns", "title_y", "line1_y", "line2_y" (baselines), "line2_bottom"}.
static func _metrics(p_touch: bool, p_text_size: int, p_compact: bool) -> Dictionary:
	var ts: int = SdStyle.fs(20 if p_touch else 16, p_text_size)
	var ns: int = SdStyle.fs(22 if p_touch else 20, p_text_size)
	var pad: float = 6.0 if p_compact else 8.0
	var top: float = pad
	var title_y: float = top + ts * 0.95
	if not p_compact:
		top += ts * 1.2 + 4.0
	var line1_y: float = top + ns * 0.95
	top += ns * 1.25 + 2.0
	var line2_y: float = top + ts * 0.95
	return {"pad": pad, "ts": ts, "ns": ns, "title_y": title_y, "line1_y": line1_y, "line2_y": line2_y,
		"line2_bottom": top + ts * 1.25}


func show_message(p_line1: String, p_line2: String = "", col: Color = SdStyle.TEXT_DIM) -> void:
	card = null
	line1 = p_line1
	line2 = p_line2
	line2_color = col
	queue_redraw()


func show_card(c: SdCardDef, player: bool, result: String, col: Color, was_filed: bool = false) -> void:
	card = c
	by_player = player
	line1 = c.name if c != null else ""
	line2 = result
	line2_color = col
	filed = was_filed
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 10.0 or h < 10.0:
		return
	var m: IconMesh = IconMesh.new()
	m.rect(Rect2(Vector2.ZERO, size), SdStyle.PANEL)
	m.rect_outline(Rect2(Vector2.ZERO, size), Color(SdStyle.GOLD, 0.45), 1.0)
	var mt: Dictionary = _metrics(touch, text_size, compact)
	var ts: int = int(mt["ts"])
	var ns: int = int(mt["ns"])
	var texts: Array[Dictionary] = []
	if not compact:
		texts.append({"t": title, "x": 10.0, "y": float(mt["title_y"]), "s": ts, "f": SdStyle.bold(),
			"c": SdStyle.GOLD})
	var x: float = 10.0
	if card != null:
		var ch: float = h - 16.0
		var cw: float = roundf(ch * 0.7)
		var sc: float = 1.0 + 0.3 * thump
		var cc: Vector2 = Vector2(w - 12.0 - cw * 0.5, h * 0.5)
		var cr: Rect2 = Rect2(cc - Vector2(cw, ch) * 0.5 * sc, Vector2(cw, ch) * sc)
		m.rect(cr, SdStyle.frame_color(card.art, card.show))
		m.rect(cr.grow(-3.0), SdStyle.PAPER)
		m.rect(Rect2(cr.position + Vector2(3, 3), Vector2(cr.size.x - 6.0, cr.size.y * 0.22)), SdStyle.art_band(card.art))
		var isz: float = cr.size.y * 0.18
		SdIcons.add(m, SdStyle.art_icon(card.art), Rect2(cr.position + Vector2(5, 4), Vector2(isz, isz)), SdStyle.INK)
		var stamp_col: Color = Color(SdStyle.GREY, 0.85) if filed else Color(ink, 0.85)
		var sr: Rect2 = Rect2(cr.position + Vector2(cr.size.x * 0.12, cr.size.y * 0.42), Vector2(cr.size.x * 0.76,
			cr.size.y * 0.3))
		m.rect_outline(sr, stamp_col, 3.0)
		m.rect(sr.grow(-6.0), Color(stamp_col, 0.25))
		texts.append({"t": card.name, "x": x, "y": float(mt["line1_y"]), "s": ns, "f": SdStyle.bold(),
			"c": SdStyle.TEXT, "w": cr.position.x - x - 8.0})
		texts.append({"t": line2, "x": x, "y": float(mt["line2_y"]), "s": ts, "f": SdStyle.font(), "c": line2_color,
			"w": cr.position.x - x - 8.0})
	else:
		texts.append({"t": line1, "x": x, "y": float(mt["line1_y"]), "s": ns, "f": SdStyle.bold(), "c": SdStyle.TEXT,
			"w": w - 20.0})
		if line2 != "":
			texts.append({"t": line2, "x": x, "y": float(mt["line2_y"]), "s": ts, "f": SdStyle.font(),
				"c": line2_color, "w": w - 20.0})
	m.commit(self)
	for t: Dictionary in texts:
		var tw: float = float(t.get("w", -1.0))
		var txt: String = str(t["t"])
		if tw > 0.0:
			txt = _elide(txt, t["f"] as Font, int(t["s"]), tw)
		draw_string(t["f"] as Font, Vector2(float(t["x"]), float(t["y"])), txt, HORIZONTAL_ALIGNMENT_LEFT, tw,
			int(t["s"]), t["c"] as Color)


static func _elide(text: String, f: Font, s: int, max_w: float) -> String:
	if f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x <= max_w:
		return text
	var t: String = text
	while t.length() > 1 and f.get_string_size(t + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > max_w:
		t = t.substr(0, t.length() - 1)
	return t.strip_edges() + "…"
