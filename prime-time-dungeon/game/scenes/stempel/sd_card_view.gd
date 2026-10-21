extends Control
## One card of the Stempelduell (10 §2.2) as a single canvas item: paper body, frame and band in the colour of its
## Formular-Art (show cards: gold), drawn symbols (art, Werktage hourglass, paw of the Graf's tip) — all of it ONE
## IconMesh triangle array — and the texts drawn with draw_string (fitted, hyphenated, never below the scheme's
## minimum: 16 px, touch 20 px). Desktop cards show name, Werktage, Formular-Art, main effect, quip and origin; touch
## cards and every card at a text size above 100 % show only name, Werktage and the main effect (10 §2.2, §4.8); the big
## view (2 ×) shows everything. A marked card shows the real number against the opponent ("14 · statt 9 · WUNDER
## PUNKT", 10 §1.5) from `preview`. Display only: input is the hand's business (sd_hand.gd).

const SdStyle := preload("res://scenes/stempel/sd_style.gd")
const SdIcons := preload("res://scenes/stempel/sd_icons.gd")
const IconMesh := preload("res://scenes/ui/icon_mesh.gd")

const CHAMFER: float = 7.0
const PAD: float = 8.0
const BACKS: Dictionary = {"": [Color("#2a1840"), Color("#ff2e88")], "sdk_back_durchschlag": [Color("#dfe6f2"),
	Color("#4f8dff")], "sdk_back_monokel": [Color("#2b2140"), Color("#ffc93c")], "sdk_back_wartemarke": [Color("#f5d90a"),
	Color("#140d1c")], "sdk_back_rohrpost": [Color("#14364a"), Color("#f5d90a")], "sdk_back_durchsage": [Color("#3a3248"),
	Color("#b8b2c4")], "sdk_back_goldschnitt": [Color("#3a2a10"), Color("#ffc93c")]}

var card: SdCardDef = null
var touch: bool = false
var text_size: int = 100
var big: bool = false
var face_down: bool = false
var back_id: String = ""
## Visual states (the hand sets them; each redraws).
var marked: bool = false:
	set(v):
		marked = v
		queue_redraw()
var recommended: bool = false:
	set(v):
		recommended = v
		_dirty = true
		queue_redraw()
var highlight: float = 0.0:                         # 0..1 pulse of the Lernduell's forced card (gold glow)
	set(v):
		highlight = v
		queue_redraw()
var dim: bool = false:
	set(v):
		dim = v
		queue_redraw()
## {"main": String, "sub": String, "tone": "weak" | "resist" | "blocked" | "heal" | "win" | ""} — the marked card's real
## effect against the opponent ({} = the printed one).
var preview: Dictionary = {}:
	set(v):
		preview = v
		_dirty = true
		queue_redraw()

var _dirty: bool = true
var _blocks: Array[Dictionary] = []                 # laid-out texts: {"text", "pos", "size", "font", "color", "w"}
var _band_h: float = 30.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(func() -> void:
		_dirty = true
		queue_redraw())


## Card, scheme, text size (100 / 125 / 150) and big view; sets the size.
func setup(p_card: SdCardDef, p_touch: bool, p_text_size: int = 100, p_big: bool = false) -> void:
	card = p_card
	touch = p_touch
	text_size = p_text_size
	big = p_big
	var base: Vector2 = SdStyle.card_size(touch)
	custom_minimum_size = base * (2.0 if big else 1.0)
	size = custom_minimum_size
	_dirty = true
	accessibility_name = describe(card) if card != null else "Verdeckte Karte"
	queue_redraw()


## True when the card shows only name, Werktage and the main effect (touch, text size > 100 %).
func is_compact() -> bool:
	return not big and (touch or text_size > 100)


## "Formular 27b, Stempel, 3 Werktage, 9 Ärger" (screen readers, 10 §4.8).
static func describe(c: SdCardDef) -> String:
	var e: Array = effect_of(c)
	return "%s, %s, %d %s, %s" % [c.name, SdStyle.art_name(c.art), c.rank(), "Werktag" if c.rank() == 1
		else "Werktage", (str(e[0]) + (" " + str(e[1]) if str(e[1]) != "" else "")).strip_edges()]


## [main, sub] of the printed effect (10 §2.3) — the big number line and a short addition.
static func effect_of(c: SdCardDef) -> Array:
	if c == null:
		return ["", ""]
	var sts: PackedStringArray = c.status_ids()
	var sub: String = ""
	if c.show:
		return ["%d ÄRGER" % c.damage(), "%d %% Erfolg · sonst Patzer" % roundi(c.chance_pm() / 10.0)]
	if c.hand == "refresh":
		return ["NEUE HAND", "%d Karten" % 5]
	if sts.has("sts_sd_vorschrift"):
		sub = "+ Dienst nach Vorschrift"
	elif sts.has("sts_sd_wiedervorlage") and c.damage() > 0:
		sub = "+ Wiedervorlage"
	elif sts.has("sts_sd_kleingedrucktes"):
		sub = "+ 3 × 2 Ärger"
	elif sts.has("sts_sd_eilvermerk") and c.heal() > 0:
		sub = "+ Eilvermerk"
	elif not c.cleanses().is_empty():
		sub = "entfernt Kleingedrucktes"
	if c.damage() > 0:
		var main: String = "%d × %d ÄRGER" % [c.hits(), c.power()] if c.hits() > 1 else "%d ÄRGER" % c.damage()
		return [main, sub]
	if c.heal() > 0:
		return ["+%d GEDULD" % c.heal(), sub]
	if sts.has("sts_sd_wiedervorlage"):
		return ["+3 WT", "fürs Gegenüber"]
	if sts.has("sts_sd_eilvermerk"):
		var n: int = maxi(0, c.status_turns("sts_sd_eilvermerk") - 1)
		return ["EILVERMERK", "diese + %d %s" % [n, "Karte" if n == 1 else "Karten"]]
	return ["", ""]


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 8.0 or h < 8.0:
		return
	var m: IconMesh = IconMesh.new()
	var body: PackedVector2Array = _chamfer(Rect2(Vector2.ZERO, size), CHAMFER * (2.0 if big else 1.0))
	if highlight > 0.0:
		m.polyline(_chamfer(Rect2(Vector2.ZERO, size).grow(5.0), CHAMFER + 4.0), Color(SdStyle.GOLD, 0.35
			+ 0.65 * highlight), 5.0, true)
	if marked:
		m.polyline(_chamfer(Rect2(Vector2.ZERO, size).grow(4.0), CHAMFER + 3.0), SdStyle.CYAN, 3.0, true)
	if face_down or card == null:
		_draw_back(m, body)
		m.commit(self)
		return
	if _dirty:
		_layout()
	var frame: Color = SdStyle.frame_color(card.art, card.show)
	var band: Color = SdStyle.art_band(card.art)
	m.poly(body, frame)
	var inset: float = 5.0 if card.show else 4.0
	m.poly(_chamfer(Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0), CHAMFER - 2.0), SdStyle.PAPER)
	m.rect(Rect2(inset, inset, w - inset * 2.0, _band_h), band)
	if card.art == "verwaltung":
		m.rect(Rect2(inset, inset + _band_h - 2.0, w - inset * 2.0, 2.0), SdStyle.GREY)
	var icon_s: float = _band_h - 8.0
	SdIcons.add(m, SdStyle.art_icon(card.art), Rect2(inset + 6.0, inset + 4.0, icon_s, icon_s), SdStyle.INK, band)
	var badge: Rect2 = _wt_rect()
	m.rect(badge, SdStyle.INK)
	SdIcons.add(m, &"hourglass", Rect2(badge.position + Vector2(4, 4), Vector2(badge.size.y - 8.0, badge.size.y - 8.0)),
		SdStyle.PAPER)
	if card.show:
		m.rect_outline(Rect2(Vector2(inset + 3.0, inset + 3.0), size - Vector2(inset + 3.0, inset + 3.0) * 2.0),
			Color(SdStyle.GOLD, 0.8), 1.5)
	var tone: String = str(preview.get("tone", ""))
	if tone == "weak" or tone == "resist" or tone == "win":
		for b: Dictionary in _blocks:
			if str(b.get("role", "")) == "sub":
				var col: Color = SdStyle.GOLD if tone != "resist" else SdStyle.TEXT_DIM
				m.rect(Rect2(PAD, (b["pos"] as Vector2).y - float(b["size"]) - 2.0, w - PAD * 2.0,
					float(b["size"]) + 9.0), col)
	if recommended:
		var pr: float = 13.0 * (2.0 if big else 1.0)
		m.circle(Vector2(pr + 1.0, h - pr - 1.0), pr + 2.0, SdStyle.INK, true)
		SdIcons.add(m, &"paw", Rect2(Vector2(5.0, h - pr * 2.0 + 3.0), Vector2(pr * 2.0 - 8.0, pr * 2.0 - 8.0)),
			SdStyle.GOLD)
	m.commit(self)
	for b: Dictionary in _blocks:
		var f: Font = b["font"] as Font
		draw_string(f, b["pos"] as Vector2, str(b["text"]), HORIZONTAL_ALIGNMENT_CENTER if bool(b.get("center", false))
			else HORIZONTAL_ALIGNMENT_LEFT, float(b["w"]), int(b["size"]), b["color"] as Color)
	if dim:
		draw_rect(Rect2(Vector2.ZERO, size), Color(SdStyle.INK, 0.5), true)


func _wt_rect() -> Rect2:
	var bh: float = _band_h - 4.0
	var num_w: float = SdStyle.bold().get_string_size(str(card.rank()), HORIZONTAL_ALIGNMENT_LEFT, -1, _wt_font()).x
	var bw: float = bh + num_w + 6.0
	var inset: float = 5.0 if card.show else 4.0
	return Rect2(size.x - inset - bw - 2.0, inset + 2.0, bw, bh)


func _wt_font() -> int:
	return SdStyle.fs(26 if touch else 22, text_size) if not big else SdStyle.fs(36, text_size)


## Lays the texts out top-down (band, name, effect, sub, quip, footer) and drops what does not fit.
func _layout() -> void:
	_dirty = false
	_blocks.clear()
	var k: float = 1.6 if big else 1.0
	var w: float = size.x
	var inner: float = w - PAD * 2.0
	var compact: bool = is_compact()
	var min_t: int = SdStyle.min_text(touch)
	_band_h = roundf((34.0 if touch else 30.0) * k * (1.0 + (text_size - 100) / 250.0))
	var band_y: float = 4.0
	var y: float = band_y + _band_h + 6.0
	# the Werktage number in the badge
	var badge: Rect2 = _wt_rect()
	_blocks.append({"text": str(card.rank()), "pos": Vector2(badge.position.x + badge.size.y - 4.0,
		badge.position.y + badge.size.y * 0.5 + _wt_font() * 0.36), "size": _wt_font(), "font": SdStyle.bold(),
		"color": SdStyle.PAPER, "w": badge.size.x - badge.size.y + 4.0})
	# the Formular-Art word in the band (desktop, 100 %)
	if not compact:
		var art_size: int = SdStyle.fs(16, text_size) if not big else 24
		var art_x: float = 4.0 + 6.0 + _band_h - 8.0 + 6.0
		var art_w: float = badge.position.x - art_x - 4.0
		var art_text: String = SdStyle.art_name(card.art).to_upper()
		if SdStyle.bold().get_string_size(art_text, HORIZONTAL_ALIGNMENT_LEFT, -1, art_size).x <= art_w:
			_blocks.append({"text": art_text, "pos": Vector2(art_x, band_y + _band_h * 0.5 + art_size * 0.36),
				"size": art_size, "font": SdStyle.bold(), "color": SdStyle.INK, "w": art_w})
	# name: up to 2 lines (3 in the big view)
	var name_size: int = roundi(SdStyle.fs(20 if touch else 18, text_size) * k)
	var fitted: Array = SdStyle.fit(card.name, SdStyle.bold(), name_size, mini(name_size, roundi(min_t * k)), inner,
		3 if big else 2)
	for line: String in fitted[1] as PackedStringArray:
		y += float(fitted[0]) * 1.05
		_blocks.append({"text": line, "pos": Vector2(PAD, y), "size": int(fitted[0]), "font": SdStyle.bold(),
			"color": SdStyle.INK, "w": inner})
	y += float(fitted[0]) * 0.35
	# main effect + addition (the preview of a marked card replaces the printed effect)
	var eff: Array = effect_of(card)
	var main_text: String = str(preview.get("main", eff[0]))
	var sub_text: String = str(preview.get("sub", eff[1]))
	var tone: String = str(preview.get("tone", ""))
	var main_col: Color = SdStyle.HEAL_ON_PAPER if (card.heal() > 0 and card.damage() == 0) else SdStyle.INK
	if tone == "blocked":
		main_col = SdStyle.PAPER_DIM
	var eff_size: int = roundi(SdStyle.fs(34 if touch else 30, text_size) * k)
	var ef: Array = SdStyle.fit(main_text, SdStyle.bold(), eff_size, mini(eff_size, roundi(min_t * k)), inner, 1)
	y += float(ef[0]) * 1.0 + 4.0
	_blocks.append({"text": (ef[1] as PackedStringArray)[0], "pos": Vector2(PAD, y), "size": int(ef[0]),
		"font": SdStyle.bold(), "color": main_col, "w": inner, "center": true})
	if sub_text != "":
		var sub_size: int = roundi(SdStyle.fs(20 if touch else 16, text_size) * k)
		var sf: Array = SdStyle.fit(sub_text, SdStyle.font(), sub_size, mini(sub_size, roundi(min_t * k)), inner,
			2 if not compact else 1)
		y += 4.0
		for line2: String in sf[1] as PackedStringArray:
			y += float(sf[0]) * 1.1
			_blocks.append({"text": line2, "pos": Vector2(PAD, y), "size": int(sf[0]), "font": SdStyle.font(),
				"color": SdStyle.INK, "w": inner, "center": true, "role": "sub"})
	if compact:
		return
	# footer: origin (right of the Graf's paw badge) + form number ("Nr. " is dropped, then the origin elided, when
	# both do not fit)
	var foot_size: int = roundi(SdStyle.fs(16, text_size) * k)
	var foot_y: float = size.y - PAD - 2.0
	var origin: String = str(SdStyle.ORIGINS.get(card.origin, card.origin))
	if card.show:
		origin += " · SHOW"
	var paw_w: float = 13.0 * k * 2.0 + 6.0 if recommended else 0.0
	var form_text: String = ("Nr. " + card.form) if card.form != "" else ""
	var form_w: float = SdStyle.mono().get_string_size(form_text, HORIZONTAL_ALIGNMENT_LEFT, -1, foot_size).x
	var origin_w: float = SdStyle.font().get_string_size(origin, HORIZONTAL_ALIGNMENT_LEFT, -1, foot_size).x
	if form_text != "" and paw_w + origin_w + 8.0 + form_w > inner:
		form_text = card.form
		form_w = SdStyle.mono().get_string_size(form_text, HORIZONTAL_ALIGNMENT_LEFT, -1, foot_size).x
	var origin_room: float = inner - paw_w - (form_w + 8.0 if form_text != "" else 0.0)
	_blocks.append({"text": _elide(origin, SdStyle.font(), foot_size, origin_room), "pos": Vector2(PAD + paw_w,
		foot_y), "size": foot_size, "font": SdStyle.font(), "color": SdStyle.PAPER_DIM, "w": origin_room})
	if form_text != "":
		_blocks.append({"text": form_text, "pos": Vector2(w - PAD - form_w, foot_y), "size": foot_size,
			"font": SdStyle.mono(), "color": SdStyle.PAPER_DIM, "w": form_w + 1.0})
	# quip in the room that is left (whole lines only)
	var quip_size: int = roundi(SdStyle.fs(16, text_size) * k)
	var room_lines: int = floori((foot_y - foot_size * 1.4 - (y + 6.0)) / (quip_size * 1.2))
	if room_lines >= 1 and card.quip != "":
		var qf: Array = SdStyle.fit("„%s“" % card.quip, SdStyle.font(), quip_size, quip_size, inner, room_lines)
		y += 6.0
		for line3: String in qf[1] as PackedStringArray:
			y += quip_size * 1.2
			_blocks.append({"text": line3, "pos": Vector2(PAD, y), "size": quip_size, "font": SdStyle.font(),
				"color": SdStyle.PAPER_DIM, "w": inner})


static func _elide(text: String, f: Font, s: int, max_w: float) -> String:
	if f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x <= max_w:
		return text
	var t: String = text
	while t.length() > 1 and f.get_string_size(t + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > max_w:
		t = t.substr(0, t.length() - 1)
	return t.strip_edges() + "…"


## The laid-out text blocks (tests: sizes and widths).
func text_blocks() -> Array[Dictionary]:
	if _dirty and card != null:
		_layout()
	return _blocks


func _draw_back(m: IconMesh, body: PackedVector2Array) -> void:
	var cols: Array = BACKS.get(back_id, BACKS[""]) as Array
	var bg: Color = cols[0]
	var fg: Color = cols[1]
	m.poly(body, fg)
	m.poly(_chamfer(Rect2(Vector2(4, 4), size - Vector2(8, 8)), CHAMFER - 2.0), bg)
	var step: float = maxf(8.0, size.y / 9.0)
	var y: float = 10.0
	while y < size.y - 10.0:
		m.rect(Rect2(10.0, y, size.x - 20.0, 2.0), Color(fg, 0.22))
		y += step
	var s: float = minf(size.x, size.y) * 0.42
	m.circle(size * 0.5, s * 0.62, bg, true)
	SdIcons.add(m, &"stamp", Rect2((size - Vector2(s, s)) * 0.5, Vector2(s, s)), fg, bg)


static func _chamfer(r: Rect2, c: float) -> PackedVector2Array:
	var p: Vector2 = r.position
	var e: Vector2 = r.end
	return PackedVector2Array([Vector2(p.x + c, p.y), Vector2(e.x - c, p.y), Vector2(e.x, p.y + c),
		Vector2(e.x, e.y - c), Vector2(e.x - c, e.y), Vector2(p.x + c, e.y), Vector2(p.x, e.y - c),
		Vector2(p.x, p.y + c)])
