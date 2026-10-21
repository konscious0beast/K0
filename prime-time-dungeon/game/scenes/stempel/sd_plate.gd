extends Control
## A plate of the Stempelduell (10 §4.2): the opponent ("[Golem] FERDI DURCHSCHLAG · Sachbearbeitung", Geduld bar,
## statuses, Zuständigkeiten, hand / pile / discard counts; with "Gegnerhand offen" a row of the hand's cards) or the
## player's seat ("KAI & DER GRAF", one Geduld for the duo, statuses). Statuses are symbol + count chips (never colour
## alone); Zuständigkeiten read "WUNDER PUNKT: Eilt" / "NICHT ZUSTÄNDIG: Eiskalt" with the art symbol. A marked card
## shows its effect on the bar as a pale segment (show_preview). The bar runs to a new value in 0.5 s (Tween). One
## IconMesh + texts in one canvas item. The opponent's plate is a ≥ 88 px touch target (the Akte); the table owns the
## input.

const SdStyle := preload("res://scenes/stempel/sd_style.gd")
const SdIcons := preload("res://scenes/stempel/sd_icons.gd")
const IconMesh := preload("res://scenes/ui/icon_mesh.gd")

const BAR_SEC: float = 0.5
const PAD: float = 8.0

var touch: bool = false
var text_size: int = 100
var is_player: bool = false
var symbol: StringName = &"person"
var title: String = ""                              # "FERDI DURCHSCHLAG" / "KAI & DER GRAF"
var role: String = ""                               # "Sachbearbeitung in Ausbildung · Schalter 3" / a cosmetic title
var max_geduld: int = 1
var geduld: int = 1
var shown_geduld: float = 1.0:
	set(v):
		shown_geduld = v
		queue_redraw()
var preview_geduld: int = -1                        # after a marked card (-1 = none)
## [{"icon": StringName, "color": Color, "count": int (-1 = none), "name": String}]
var statuses: Array[Dictionary] = []
## [{"weak": bool, "art": String, "label": String}] + immunities as {"immune": "Wiedervorlage"}
var duties: Array[Dictionary] = []
var piles: Array[int] = [5, 0, 0]                   # hand, stack, discard
## "Gegnerhand offen" (10 §1.11): the opponent's hand as [{"name", "art"}] in a row of its own (sd_layout.gd _open_row).
var open_cards: Array[Dictionary] = []
var phase: String = ""                              # the Stempelmeister's phase ("Phase 2 · Durchsagen")
var defending: bool = false                         # filed: half Ärger until the own next number
var flash: float = 0.0:                             # hit flash 0..1
	set(v):
		flash = v
		queue_redraw()

## The opponent's name and Geduld bar in one row, without the role (sd_layout.gd, large text / many rows).
var compact: bool = false

var _bar_tween: Tween = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Font sizes of the plate.
func name_size() -> int:
	return SdStyle.fs(22 if touch else 20, text_size)


func small_size() -> int:
	return SdStyle.fs(20 if touch else 16, text_size)


## Height the plate needs (opponent ≥ 88 px: a touch target); `extra_rows`: the second Zuständigkeiten row
## (duty_rows); `p_compact`: name and Geduld in one row (opponent only).
static func plate_height(p_touch: bool, p_text_size: int, player: bool, extra_rows: int = 0,
		p_compact: bool = false) -> float:
	var n: float = SdStyle.fs(22 if p_touch else 20, p_text_size)
	var s: float = SdStyle.fs(20 if p_touch else 16, p_text_size)
	var row2: float = maxf(s * 1.2, 18.0)
	var rows: float = PAD + n * 1.2 + 4.0 + row2 + (0.0 if player else 4.0 + s * 1.2) + PAD
	if p_compact and not player:
		rows = PAD + maxf(n * 1.2, row2) + 4.0 + s * 1.2 + PAD
	rows += float(extra_rows) * (s * 1.2 + 4.0)
	return ceilf(maxf(rows, 64.0 if player else 88.0))


## Rows the Zuständigkeiten take on a plate `width` px wide: 1, or 2 when they and the pile counts do not fit one row
## (then the first row holds as many entries as fit, the second the rest and the piles).
static func duty_rows(p_duties: Array[Dictionary], width: float, p_touch: bool, p_text_size: int) -> int:
	var ss: int = SdStyle.fs(20 if p_touch else 16, p_text_size)
	var avail: float = _text_room(width)
	var need: float = 0.0
	for d: Dictionary in p_duties:
		need += duty_width(d, ss)
	return 1 if need + 12.0 + _pile_width(ss) <= avail else 2


## Width of one Zuständigkeit entry at `ss` px (label, symbol, art name, 16 px gap).
static func duty_width(d: Dictionary, ss: int) -> float:
	if d.has("immune"):
		return SdStyle.bold().get_string_size("IMMUN: " + str(d["immune"]), HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x + 16.0
	var lab: String = str(d.get("label", "")).to_upper() + ":"
	return SdStyle.bold().get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x + 6.0 + ss + 4.0 \
		+ SdStyle.font().get_string_size(SdStyle.art_name(str(d.get("art", ""))), HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x \
		+ 16.0


## Text room right of the symbol (the symbol is at most 64 px).
static func _text_room(width: float) -> float:
	return width - (5.0 + PAD + 64.0 + 12.0) - PAD


## Widest pile line of the opponent ("Hand 5 · Stapel 15 · Ablage 15").
static func _pile_width(ss: int) -> float:
	return SdStyle.font().get_string_size("Hand 5 · Stapel 20 · Ablage 20", HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x


func set_geduld(value: int, animate: bool, speed: float = 1.0) -> void:
	geduld = value
	if _bar_tween != null and _bar_tween.is_valid():
		_bar_tween.kill()
	if not animate or not is_inside_tree():
		shown_geduld = float(value)
		return
	_bar_tween = create_tween()
	_bar_tween.tween_property(self, "shown_geduld", float(value), BAR_SEC / maxf(speed, 0.1))


func show_preview(value: int) -> void:
	preview_geduld = value
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 10.0 or h < 10.0:
		return
	var m: IconMesh = IconMesh.new()
	var side_col: Color = SdStyle.PARTY if is_player else SdStyle.ENEMY
	m.rect(Rect2(Vector2.ZERO, size), SdStyle.PANEL)
	if flash > 0.0:
		m.rect(Rect2(Vector2.ZERO, size), Color(SdStyle.DANGER, 0.35 * flash))
	m.rect(Rect2(0, 0, 5, h), side_col)
	m.rect_outline(Rect2(Vector2.ZERO, size), SdStyle.PANEL_LINE, 1.0)
	var texts: Array[Dictionary] = []
	var sym: float = minf(h - PAD * 2.0, 64.0)
	var sx: float = 5.0 + PAD
	m.circle(Vector2(sx + sym * 0.5, h * 0.5), sym * 0.5, Color(side_col, 0.22), true)
	if is_player:
		SdIcons.add(m, &"person", Rect2(sx + sym * 0.08, h * 0.5 - sym * 0.3, sym * 0.5, sym * 0.5), SdStyle.PAPER)
		SdIcons.add(m, &"paw", Rect2(sx + sym * 0.46, h * 0.5 - sym * 0.02, sym * 0.42, sym * 0.42), SdStyle.GOLD)
	else:
		SdIcons.add(m, symbol, Rect2(sx + sym * 0.15, h * 0.5 - sym * 0.35, sym * 0.7, sym * 0.7), SdStyle.PAPER,
			SdStyle.INK)
	var x0: float = sx + sym + 12.0
	var right: float = w - PAD
	var ns: int = name_size()
	var ss: int = small_size()
	var y: float = PAD + ns
	var one_row: bool = compact and not is_player
	# row 1: name + role (elided), the phase on the right
	var name_w: float = SdStyle.bold().get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, ns).x
	texts.append({"t": title, "x": x0, "y": y, "s": ns, "f": SdStyle.bold(), "c": SdStyle.TEXT, "w": right - x0})
	var phase_w: float = 0.0
	if phase != "":
		phase_w = SdStyle.bold().get_string_size(phase, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x + 16.0
		m.rect(Rect2(right - phase_w, y - ss - 2.0, phase_w, ss + 8.0), SdStyle.GOLD)
		texts.append({"t": phase, "x": right - phase_w + 8.0, "y": y + 1.0, "s": ss, "f": SdStyle.bold(),
			"c": SdStyle.INK})
	if role != "" and not one_row:
		var rx: float = x0 + name_w + 12.0
		var rw: float = right - phase_w - 8.0 - rx
		if rw > 60.0:
			texts.append({"t": _elide(role, SdStyle.font(), ss, rw), "x": rx, "y": y, "s": ss, "f": SdStyle.font(),
				"c": SdStyle.TEXT_DIM, "w": rw})
	# row 2 (compact: the rest of row 1): Geduld bar + numbers + statuses (+ filed shield)
	var row_h: float = maxf(ss * 1.2, 18.0)
	var top2: float = y + 4.0
	var bar_x: float = 0.0
	var num_w: float = SdStyle.mono().get_string_size("00 / 00", HORIZONTAL_ALIGNMENT_LEFT, -1, ss + 2).x
	var bar_w: float = 0.0
	if one_row:
		top2 = PAD + (maxf(ns * 1.2, row_h) - row_h) * 0.5
		bar_x = x0 + name_w + 14.0
		bar_w = clampf((right - phase_w - 8.0 - bar_x - num_w - 8.0) * 0.6, 90.0, 220.0)
	else:
		var label: String = "Geduld"
		var lw: float = SdStyle.font().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x
		texts.append({"t": label, "x": x0, "y": top2 + row_h * 0.8, "s": ss, "f": SdStyle.font(),
			"c": SdStyle.TEXT_DIM})
		bar_x = x0 + lw + 8.0
		bar_w = clampf((right - bar_x) * 0.42, 120.0, 260.0)
	var num: String = "%d / %d" % [geduld, max_geduld]
	var bar: Rect2 = Rect2(bar_x, top2 + row_h * 0.25, bar_w, row_h * 0.6)
	m.rect(bar, Color(SdStyle.INK, 0.9))
	var frac: float = clampf(shown_geduld / float(maxi(1, max_geduld)), 0.0, 1.0)
	var bar_col: Color = SdStyle.OK if frac > 0.5 else (SdStyle.GOLD if frac > 0.25 else SdStyle.DANGER)
	m.rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), bar_col)
	if preview_geduld >= 0 and preview_geduld != geduld:
		var pf: float = clampf(float(preview_geduld) / float(maxi(1, max_geduld)), 0.0, 1.0)
		var a: float = minf(pf, frac)
		var b: float = maxf(pf, frac)
		m.rect(Rect2(bar.position.x + bar.size.x * a, bar.position.y, bar.size.x * (b - a), bar.size.y),
			Color(SdStyle.PAPER, 0.55))
	m.rect_outline(bar, Color(SdStyle.TEXT_DIM, 0.6), 1.0)
	texts.append({"t": num, "x": bar.end.x + 8.0, "y": top2 + row_h * 0.8, "s": ss + 2, "f": SdStyle.mono(),
		"c": SdStyle.TEXT})
	var cx: float = bar.end.x + 8.0 + num_w + 12.0
	# the chips: after the numbers; in the compact row only as far as the phase, the rest goes below
	var chips: Array[Array] = []
	if defending:
		chips.append([&"shield", SdStyle.CYAN, "abgeheftet"])
	for st: Dictionary in statuses:
		chips.append([st["icon"], st["color"], str(st["count"]) if int(st.get("count", -1)) > 0 else ""])
	var chip_limit: float = (right - phase_w - 8.0) if one_row else right
	var later: Array[Array] = []
	for ch: Array in chips:
		var cw0: float = _chip_width(row_h, str(ch[2]), ss)
		if cx + cw0 > chip_limit:
			later.append(ch)
			continue
		cx += _chip(m, texts, cx, top2, row_h, ch[0] as StringName, ch[1] as Color, str(ch[2]), ss) + 6.0
	# piles (row 1 right for the player, the last Zuständigkeiten row right for the opponent)
	var pile_text: String = ("Hand %d · " % piles[0] if not is_player else "") + "Stapel %d · Ablage %d" % [piles[1],
		piles[2]]
	var pw: float = SdStyle.font().get_string_size(pile_text, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x
	if is_player:
		texts.append({"t": pile_text, "x": right - pw, "y": PAD + ns, "s": ss, "f": SdStyle.font(),
			"c": SdStyle.TEXT_DIM})
		_trim_overlap(texts, right - pw - 12.0)
	else:
		y = (PAD + maxf(ns * 1.2, row_h) if one_row else top2 + row_h) + 4.0
		var two: bool = duty_rows(duties, size.x, touch, text_size) == 2
		var split: int = duties.size()
		if two:
			# the first row takes the entries that fit (at least one), the second the rest and the piles
			split = 0
			var used: float = 0.0
			while split < duties.size() and used + duty_width(duties[split], ss) <= right - x0:
				used += duty_width(duties[split], ss)
				split += 1
			split = clampi(split, mini(1, duties.size()), duties.size())
		var dx: float = _duty_row(m, texts, duties.slice(0, split), x0, y, ss)
		if two:
			y += ss * 1.2 + 4.0
			dx = _duty_row(m, texts, duties.slice(split), x0, y, ss)
		for ch2: Array in later:
			dx += _chip(m, texts, dx, y, row_h, ch2[0] as StringName, ch2[1] as Color, str(ch2[2]), ss) + 6.0
		if dx + 12.0 < right - pw:
			texts.append({"t": pile_text, "x": right - pw, "y": y + ss * 0.95, "s": ss, "f": SdStyle.font(),
				"c": SdStyle.TEXT_DIM})
		if not open_cards.is_empty():
			_open_row(m, texts, x0, right, ss)
	m.commit(self)
	for t2: Dictionary in texts:
		draw_string(t2["f"] as Font, Vector2(float(t2["x"]), float(t2["y"])), str(t2["t"]),
			HORIZONTAL_ALIGNMENT_LEFT, float(t2.get("w", -1.0)), int(t2["s"]), t2["c"] as Color)


## One row of Zuständigkeiten at y ("WUNDER PUNKT: [flame] Eilt", "IMMUN: Wiedervorlage"); returns the end x.
func _duty_row(m: IconMesh, texts: Array[Dictionary], list: Array, x: float, y: float, ss: int) -> float:
	var dx: float = x
	for dv: Variant in list:
		var d: Dictionary = dv
		if d.has("immune"):
			var t: String = "IMMUN: " + str(d["immune"])
			texts.append({"t": t, "x": dx, "y": y + ss * 0.95, "s": ss, "f": SdStyle.bold(), "c": SdStyle.GOLD})
			dx += SdStyle.bold().get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x + 16.0
			continue
		var lab: String = str(d["label"]).to_upper() + ":"
		var col: Color = SdStyle.GOLD if bool(d["weak"]) else SdStyle.TEXT_DIM
		var lw2: float = SdStyle.bold().get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x
		texts.append({"t": lab, "x": dx, "y": y + ss * 0.95, "s": ss, "f": SdStyle.bold(), "c": col})
		dx += lw2 + 6.0
		SdIcons.add(m, SdStyle.art_icon(str(d["art"])), Rect2(dx, y + 1.0, ss, ss), SdStyle.art_band(str(d["art"])),
			SdStyle.INK)
		dx += ss + 4.0
		var an: String = SdStyle.art_name(str(d["art"]))
		texts.append({"t": an, "x": dx, "y": y + ss * 0.95, "s": ss, "f": SdStyle.font(), "c": SdStyle.TEXT})
		dx += SdStyle.font().get_string_size(an, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x + 16.0
	return dx


## The open hand at the bottom of the opponent's plate: "HAND" + one slot per card (art symbol + name, elided).
func _open_row(m: IconMesh, texts: Array[Dictionary], x0: float, right: float, ss: int) -> void:
	var rh: float = ss * 1.3
	var y: float = size.y - PAD - rh
	var lab: String = "HAND"
	var lw: float = SdStyle.bold().get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x
	texts.append({"t": lab, "x": x0, "y": y + rh * 0.78, "s": ss, "f": SdStyle.bold(), "c": SdStyle.TEXT_DIM})
	var x: float = x0 + lw + 10.0
	var n: int = open_cards.size()
	var slot_w: float = (right - x - 6.0 * float(n - 1)) / float(n)
	for oc: Dictionary in open_cards:
		var art: String = str(oc.get("art", ""))
		m.rect(Rect2(x, y, slot_w, rh), Color(SdStyle.PAPER, 0.08))
		m.rect(Rect2(x, y, 4.0, rh), SdStyle.art_band(art))
		SdIcons.add(m, SdStyle.art_icon(art), Rect2(x + 7.0, y + (rh - ss) * 0.5, ss, ss), SdStyle.art_band(art),
			SdStyle.INK)
		var tw: float = slot_w - ss - 14.0
		if tw > 24.0:
			texts.append({"t": _elide(str(oc.get("name", "")), SdStyle.font(), ss, tw), "x": x + ss + 11.0,
				"y": y + rh * 0.78, "s": ss, "f": SdStyle.font(), "c": SdStyle.TEXT})
		x += slot_w + 6.0


static func _chip_width(h: float, count: String, ss: int) -> float:
	var cw: float = h + 6.0
	if count != "":
		cw += SdStyle.bold().get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x + 4.0
	return cw


## A status chip (symbol + count) at x; returns its width.
func _chip(m: IconMesh, texts: Array[Dictionary], x: float, y: float, h: float, icon: StringName, col: Color,
		count: String, ss: int) -> float:
	var cw: float = h + 6.0
	if count != "":
		cw += SdStyle.bold().get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x + 4.0
	m.rect(Rect2(x, y, cw, h), Color(col, 0.25))
	m.rect_outline(Rect2(x, y, cw, h), col, 1.5)
	SdIcons.add(m, icon, Rect2(x + 3.0, y + 2.0, h - 4.0, h - 4.0), col, SdStyle.INK)
	if count != "":
		texts.append({"t": count, "x": x + h + 2.0, "y": y + h * 0.8, "s": ss, "f": SdStyle.bold(), "c": SdStyle.TEXT})
	return cw


## The player's row 1: the name gives way to the piles on the right.
func _trim_overlap(texts: Array[Dictionary], limit: float) -> void:
	for t: Dictionary in texts:
		if float(t["y"]) == PAD + name_size() and float(t["x"]) < limit and t.has("w"):
			t["w"] = minf(float(t["w"]), limit - float(t["x"]))
			t["t"] = _elide(str(t["t"]), t["f"] as Font, int(t["s"]), float(t["w"]))


static func _elide(text: String, f: Font, s: int, max_w: float) -> String:
	if f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x <= max_w:
		return text
	var t: String = text
	while t.length() > 1 and f.get_string_size(t + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > max_w:
		t = t.substr(0, t.length() - 1)
	return t.strip_edges() + "…"
