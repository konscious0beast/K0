extends Control
## The Wartenummern-Anzeige (10 §4.3): the next calls of the duel (SdDuel.order, 12 computed; desktop shows up to 10,
## touch 8 — as many as fit), each ticket as shape + word, never colour alone: SIE in the blue circle, the opponent's
## short name in the red diamond, DURCHSAGE in the grey box with the speaker. Only the ticket now called carries a
## number ("JETZT 007"); the part behind the opponent's next number is a forecast (10 §1.2) and drawn lighter under the
## caption "Prognose". A marked card shows its preview (SdDuel.preview → order): the player's and the opponent's next
## tickets become ghost tickets (dashed frame ≥ 3 : 1, half fill). Runs of three or more calls of one side get a
## bracket ("3 × SIE"), the Durchsage blinks (1 Hz ≤ 2 Hz) at the second place, from number 60 the note "Dienstschluss
## bei Nummer 80" shows. Tickets glide to new places in 0.2 s (Tween, no _process). Q / E reading mode: a cursor walks
## the tickets (describe()). Everything is one IconMesh plus the texts of one canvas item.

const SdStyle := preload("res://scenes/stempel/sd_style.gd")
const SdIcons := preload("res://scenes/stempel/sd_icons.gd")
const IconMesh := preload("res://scenes/ui/icon_mesh.gd")

const GLIDE_SEC: float = 0.2
const GAP: float = 8.0
const CHAIN_MIN: int = 3

var touch: bool = false
var text_size: int = 100
## Symbols beside the words instead of above them: lower tickets (sd_layout.gd, large text).
var compact: bool = false:
	set(v):
		compact = v
		_rebuild(false)
		queue_redraw()
var opp_short: String = "GEGNER"
var durchsage_short: String = "DURCHSAGE"
var player_id: String = "p0"
var ticket: int = 1
var order: PackedStringArray = []                   # the duel's order (index 0 = the number now called)
var ghost_order: PackedStringArray = []             # preview order of a marked card ([] = none)
var near_end: bool = false
var dienstschluss: int = 80
var cursor: int = -1:                               # reading mode (Q / E): highlighted ticket, -1 = off
	set(v):
		cursor = v
		queue_redraw()
var speed: float = 1.0                              # animation speed (Tempo × 2 → 2.0)
var reduce_motion: bool = false
var blink: float = 0.0:
	set(v):
		blink = v
		queue_redraw()
var glide: float = 1.0:
	set(v):
		glide = v
		queue_redraw()

var _slots: Array[Dictionary] = []                  # drawn tickets: {"id", "k", "x", "w", "from", "ghost", "forecast"}
var _glide_tween: Tween = null
var _blink_tween: Tween = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(func() -> void:
		_rebuild(false)
		queue_redraw())


## Height of the board for a scheme and text size (the table layout): tickets + the caption strip below them.
static func board_height(p_touch: bool, p_text_size: int, p_compact: bool = false) -> float:
	var mt: Dictionary = metrics(p_touch, p_text_size, p_compact)
	return ceilf(float(mt["top"]) + float(mt["th"]) + 3.0 + float(mt["strip"]) + 3.0)


## {"top", "icon", "word" (px), "cap" (px, ≥ the scheme minimum), "th" (ticket height), "strip"} of the board.
static func metrics(p_touch: bool, p_text_size: int, p_compact: bool = false) -> Dictionary:
	var word: int = SdStyle.fs(20 if p_touch else 18, p_text_size)
	var cap: int = maxi(SdStyle.min_text(p_touch), roundi(word * 0.8))
	var icon: float = 22.0 if p_touch else 18.0
	var th: float = maxf(icon, word * 1.25) + 10.0 if p_compact else icon + word * 1.25 + 12.0
	return {"top": 5.0, "icon": icon, "word": word, "cap": cap, "th": th, "strip": float(cap) + 6.0}


## Shows the duel's state (after its events have been played).
func show_state(p_ticket: int, p_order: PackedStringArray, p_near_end: bool) -> void:
	ticket = p_ticket
	order = p_order
	near_end = p_near_end
	_rebuild(true)


## Preview of a marked move ([] ends it).
func show_preview(p_order: PackedStringArray) -> void:
	if p_order == ghost_order:
		return
	ghost_order = p_order
	_rebuild(true)


func max_tickets() -> int:
	return 8 if touch else 10


## Owner word and shape of a combatant id.
func word_of(id: String) -> String:
	if id == player_id:
		return "SIE"
	if id.begins_with("u"):
		return durchsage_short
	return opp_short


func shape_of(id: String) -> StringName:
	if id == player_id:
		return &"circle"
	if id.begins_with("u"):
		return &"speaker"
	return &"diamond"


func color_of(id: String) -> Color:
	if id == player_id:
		return SdStyle.PARTY
	if id.begins_with("u"):
		return SdStyle.GREY
	return SdStyle.ENEMY


## The tickets drawn now: [{"id", "x", "w", "ghost": bool, "forecast": bool, "now": bool}] (tests, reading mode).
func tickets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Dictionary in _slots:
		out.append({"id": s["id"], "x": s["x"], "w": s["w"], "ghost": s["ghost"], "forecast": s["forecast"],
			"now": s["now"]})
	return out


## Reading-mode text of ticket `i` ("Nummer 007 — jetzt: SIE", "3. Platz: FERDI · Prognose").
func describe(i: int) -> String:
	if i < 0 or i >= _slots.size():
		return ""
	var s: Dictionary = _slots[i]
	var who: String = "Sie" if str(s["id"]) == player_id else word_of(str(s["id"]))
	if bool(s["now"]):
		return "Nummer %03d — jetzt dran: %s" % [ticket, who]
	return "%d. Platz: %s%s" % [i, who, " · Prognose" if bool(s["forecast"]) else ""]


## Number of runs of ≥ 3 calls of one side in view and the longest (tests).
func chains() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var i: int = 0
	while i < _slots.size():
		var j: int = i
		while j + 1 < _slots.size() and str(_slots[j + 1]["id"]) == str(_slots[i]["id"]):
			j += 1
		if j - i + 1 >= CHAIN_MIN and not str(_slots[i]["id"]).begins_with("u"):
			out.append({"from": i, "to": j, "id": _slots[i]["id"], "n": j - i + 1})
		i = j + 1
	return out


func _word_size() -> int:
	return SdStyle.fs(20 if touch else 18, text_size)


func _now_w() -> float:
	var num: float = SdStyle.mono().get_string_size("000", HORIZONTAL_ALIGNMENT_LEFT, -1, _num_size()).x
	var word: float = 0.0
	for w: String in ["SIE", opp_short, durchsage_short]:
		word = maxf(word, SdStyle.bold().get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1, _word_size()).x)
	return ceilf(16.0 + num + 14.0 + maxf(word, 30.0) + 14.0)


func _num_size() -> int:
	return SdStyle.fs(30 if touch else 28, text_size)


func _ticket_w(id: String) -> float:
	var base: float = 104.0 if touch else 84.0
	var word: float = SdStyle.bold().get_string_size(word_of(id), HORIZONTAL_ALIGNMENT_LEFT, -1, _word_size()).x
	if compact:
		return maxf(base, ceilf(8.0 + (22.0 if touch else 18.0) + 6.0 + word + 10.0))
	return maxf(base, ceilf(word + 16.0))


## Places the tickets (as many as fit) and starts the glide from the old places.
func _rebuild(animate: bool) -> void:
	var src: PackedStringArray = ghost_order if not ghost_order.is_empty() else order
	var old: Dictionary = {}
	for s: Dictionary in _slots:
		old["%s#%d" % [s["id"], s["k"]]] = float(s["x"])
	_slots.clear()
	if src.is_empty() or size.x <= 0.0:
		queue_redraw()
		return
	var seen: Dictionary = {}
	var x: float = 0.0
	var forecast_from: int = _forecast_index(src)
	var first_ghost: Dictionary = {}
	for i in mini(src.size(), max_tickets()):
		var id: String = src[i]
		var w: float = _now_w() if i == 0 else _ticket_w(id)
		if x + w > size.x - 2.0:
			break
		var k: int = int(seen.get(id, 0))
		seen[id] = k + 1
		var ghost: bool = false
		if not ghost_order.is_empty() and i > 0 and not first_ghost.has(id) and not id.begins_with("u"):
			first_ghost[id] = true
			ghost = true
		var key: String = "%s#%d" % [id, k]
		_slots.append({"id": id, "k": k, "x": x, "w": w, "from": float(old.get(key, x + 40.0)) if animate else x,
			"ghost": ghost, "forecast": i >= forecast_from and i > 0, "now": i == 0})
		x += w + GAP
	_start_glide(animate)
	_update_blink()


## Index of the first forecast ticket: everything behind the opponent's next number (10 §1.2).
func _forecast_index(src: PackedStringArray) -> int:
	for i in range(1, src.size()):
		if not src[i].begins_with("u") and src[i] != player_id:
			return i + 1
	return src.size()


func _start_glide(animate: bool) -> void:
	if _glide_tween != null and _glide_tween.is_valid():
		_glide_tween.kill()
	if not animate or reduce_motion or not is_inside_tree():
		glide = 1.0
		return
	glide = 0.0
	_glide_tween = create_tween()
	_glide_tween.tween_property(self, "glide", 1.0, GLIDE_SEC / maxf(speed, 0.1))


## The Durchsage at the second place blinks (1 Hz: 0.5 s on, 0.5 s off — under the 2 Hz limit, 10 §4.8).
func _update_blink() -> void:
	var warn: bool = _slots.size() > 1 and str(_slots[1]["id"]).begins_with("u")
	if warn and (_blink_tween == null or not _blink_tween.is_valid()) and is_inside_tree():
		_blink_tween = create_tween().set_loops()
		_blink_tween.tween_property(self, "blink", 1.0, 0.5)
		_blink_tween.tween_property(self, "blink", 0.0, 0.5)
	elif not warn and _blink_tween != null and _blink_tween.is_valid():
		_blink_tween.kill()
		blink = 0.0


func is_blinking() -> bool:
	return _blink_tween != null and _blink_tween.is_valid()


func _exit_tree() -> void:
	if _blink_tween != null and _blink_tween.is_valid():
		_blink_tween.kill()


func _draw() -> void:
	var m: IconMesh = IconMesh.new()
	var h: float = size.y
	m.rect(Rect2(Vector2.ZERO, size), SdStyle.PANEL)
	m.rect_outline(Rect2(Vector2.ZERO, size), SdStyle.PANEL_LINE, 1.0)
	var mt: Dictionary = metrics(touch, text_size, compact)
	var word_size: int = int(mt["word"])
	var cap_size: int = int(mt["cap"])
	var top: float = float(mt["top"])
	var th: float = float(mt["th"])
	var isz: float = float(mt["icon"])
	var strip_y: float = top + th + 3.0
	var cap_y: float = strip_y + float(mt["strip"]) - 5.0
	var texts: Array[Dictionary] = []
	for i in _slots.size():
		var s: Dictionary = _slots[i]
		var id: String = str(s["id"])
		var x: float = lerpf(float(s["from"]), float(s["x"]), glide) + 4.0
		var w: float = float(s["w"])
		var col: Color = color_of(id)
		if bool(s["now"]):
			# the called ticket: full height (no caption under it), JETZT on top, the number big at the bottom
			var nr: Rect2 = Rect2(x, top, w, h - top - 4.0)
			m.rect(nr, SdStyle.INK)
			m.rect_outline(nr, SdStyle.GOLD, 3.0)
			texts.append({"t": "JETZT", "x": x + 10.0, "y": top + cap_size + 4.0, "s": cap_size, "f": SdStyle.bold(),
				"c": SdStyle.GOLD})
			texts.append({"t": "%03d" % ticket, "x": x + 10.0, "y": nr.end.y - 10.0, "s": _num_size(),
				"f": SdStyle.mono(), "c": SdStyle.PAPER})
			var num_w: float = SdStyle.mono().get_string_size("000", HORIZONTAL_ALIGNMENT_LEFT, -1, _num_size()).x
			var wx: float = x + 10.0 + num_w + 14.0
			SdIcons.add(m, shape_of(id), Rect2(wx, top + 8.0, isz, isz), col, SdStyle.INK)
			texts.append({"t": word_of(id), "x": wx, "y": nr.end.y - 10.0, "s": word_size, "f": SdStyle.bold(),
				"c": SdStyle.PAPER})
			continue
		var r: Rect2 = Rect2(x, top, w, th)
		var alpha: float = 0.72 if bool(s["forecast"]) else 1.0
		if i == 1 and id.begins_with("u") and blink > 0.0:
			m.rect(r.grow(3.0), Color(SdStyle.GOLD, 0.85 * blink))
		if bool(s["ghost"]):
			m.rect(r, Color(SdStyle.PAPER, 0.5))
			_dashed(m, r, SdStyle.CYAN, 2.0)
		else:
			m.rect(r, Color(SdStyle.PAPER, alpha))
		if i == cursor:
			m.rect_outline(r.grow(3.0), SdStyle.CYAN, 3.0)
		if compact:
			# symbol left of the word, both centred in the low ticket
			var ww: float = SdStyle.bold().get_string_size(word_of(id), HORIZONTAL_ALIGNMENT_LEFT, -1, word_size).x
			var x1: float = x + (w - (isz + 6.0 + ww)) * 0.5
			SdIcons.add(m, shape_of(id), Rect2(x1, top + (th - isz) * 0.5, isz, isz), col, SdStyle.PAPER)
			texts.append({"t": word_of(id), "x": x1 + isz + 6.0, "y": top + th * 0.5 + word_size * 0.36,
				"s": word_size, "f": SdStyle.bold(), "c": SdStyle.INK})
		else:
			SdIcons.add(m, shape_of(id), Rect2(x + (w - isz) * 0.5, top + 5.0, isz, isz), col, SdStyle.PAPER)
			texts.append({"t": word_of(id), "x": x, "y": top + th - 8.0, "s": word_size, "f": SdStyle.bold(),
				"c": SdStyle.INK, "w": w, "center": true})
	# forecast caption and chain brackets in the strip below the tickets (never under the JETZT ticket)
	var fi: int = -1
	for i2 in _slots.size():
		if bool(_slots[i2]["forecast"]):
			fi = i2
			break
	var chain_x: Array[Vector2] = []
	for c: Dictionary in chains():
		var a: Dictionary = _slots[maxi(1, int(c["from"]))]
		var b: Dictionary = _slots[int(c["to"])]
		var x0: float = float(a["x"]) + 4.0
		var x1: float = float(b["x"]) + float(b["w"]) + 4.0
		m.rect(Rect2(x0, strip_y, x1 - x0, 3.0), SdStyle.GOLD)
		var label: String = "%d × %s" % [int(c["n"]), word_of(str(c["id"]))]
		var lw: float = SdStyle.bold().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, cap_size).x
		var lx: float = maxf(x0, (x0 + x1 - lw) * 0.5)
		m.rect(Rect2(lx - 6.0, strip_y, lw + 12.0, h - strip_y - 2.0), SdStyle.GOLD)
		texts.append({"t": label, "x": lx, "y": cap_y, "s": cap_size, "f": SdStyle.bold(), "c": SdStyle.INK})
		chain_x.append(Vector2(lx - 6.0, lx + lw + 6.0))
	var note_x: float = size.x
	if near_end:
		var note: String = "Dienstschluss bei Nummer %d" % dienstschluss
		var nw: float = SdStyle.bold().get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, cap_size).x
		note_x = size.x - nw - 8.0
		texts.append({"t": note, "x": note_x, "y": cap_y, "s": cap_size, "f": SdStyle.bold(), "c": SdStyle.GOLD})
	if fi > 0:
		var fx: float = float(_slots[fi]["x"]) + 4.0
		var cap: String = "Prognose"
		var cw: float = SdStyle.font().get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, cap_size).x
		var free: bool = fx + cw < note_x - 8.0
		for span: Vector2 in chain_x:
			if fx < span.y and fx + cw > span.x:
				free = false
		if free:
			texts.append({"t": cap, "x": fx, "y": cap_y, "s": cap_size, "f": SdStyle.font(), "c": SdStyle.TEXT_DIM})
	m.commit(self)
	for t: Dictionary in texts:
		var tw: float = float(t.get("w", -1.0))
		draw_string(t["f"] as Font, Vector2(float(t["x"]), float(t["y"])), str(t["t"]), HORIZONTAL_ALIGNMENT_CENTER
			if bool(t.get("center", false)) else HORIZONTAL_ALIGNMENT_LEFT, tw, int(t["s"]), t["c"] as Color)


## Dashed frame (ghost tickets).
static func _dashed(m: IconMesh, r: Rect2, col: Color, w: float) -> void:
	var dash: float = 7.0
	var gap: float = 5.0
	for edge: Array in [[r.position, Vector2(r.end.x, r.position.y)], [Vector2(r.end.x, r.position.y), r.end],
			[r.end, Vector2(r.position.x, r.end.y)], [Vector2(r.position.x, r.end.y), r.position]]:
		var a: Vector2 = edge[0]
		var b: Vector2 = edge[1]
		var len: float = a.distance_to(b)
		var dir: Vector2 = (b - a) / maxf(len, 0.001)
		var t: float = 0.0
		while t < len:
			var e: float = minf(t + dash, len)
			m.line(a + dir * t, a + dir * e, col, w)
			t = e + gap
