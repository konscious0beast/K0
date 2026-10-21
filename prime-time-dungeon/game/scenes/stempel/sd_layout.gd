extends RefCounted
## The table layout of the Stempelduell (10 §4.2) as a pure function of the safe frame: rects in frame coordinates for
## every element, so tests can check every resolution, scheme, text size and inset without a scene. Rows top-down:
##   top bar  — the overlay's LIVE badge + channel corner (left, ShowOverlay), the chips (Tempo × 2, AUTO) and the
##              88 px Pfote / Menü buttons (right)
##   board    — the Wartenummern-Anzeige, left of the buttons
##   row A    — the opponent's plate (left column) | the M.O.D. box slot (right column: ModDialog's subtitle box)
##   row B    — the player's plate (left) | the counter "SCHALTER" (right)
##   hand     — ABLAGE · five cards · STEMPELN (mirrored for left-handers, 10 §4.2), above the overlay's chat ticker
## When the rows do not fit (large text, touch, a long list of Zuständigkeiten) the layout steps down, one step after
## the other, until it fits: the gaps 12 → 8 px, the M.O.D. font towards its 100 % size, the counter without its
## title, the touch fan flat, the opponent's plate with name and Geduld in one row, the board's symbols beside the
## words, at last the open hand row (Gegnerhand offen: then in the Akte only) — never a text below the scheme minimum,
## never an overlap.

const SdStyle := preload("res://scenes/stempel/sd_style.gd")
const SdBoard := preload("res://scenes/stempel/sd_board.gd")
const SdPlate := preload("res://scenes/stempel/sd_plate.gd")
const SdCounter := preload("res://scenes/stempel/sd_counter.gd")
const SdHand := preload("res://scenes/stempel/sd_hand.gd")

const TOP: float = 36.0                             # below the overlay's LIVE badge (30 px)
const BOTTOM: float = 30.0                          # the chat ticker (22) + gap
const BUTTON: float = 88.0                          # hit area of Pfote / Menü (64 px visible)
const TAB_H: float = 26.0                           # ModDialog's speaker tab above its box
const MOD_PAD: float = 46.0                         # ModDialog subtitle: margins 2 × 16 + separation 14
const SAMPLE: Dictionary = {"opp": "Der Stempelmeister", "ticket": "007", "card": "Gräfliches Gutachten",
	"count": "25", "name": "Kandidat:in"}
static var _mod_cache: Dictionary = {}

## The steps of the layout, each on top of the ones before.
const STEPS: Array[Dictionary] = [
	{},
	{"gap": 8.0},
	{"gap": 8.0, "counter_compact": true},
	{"gap": 8.0, "counter_compact": true, "fan": false},
	{"gap": 8.0, "counter_compact": true, "fan": false, "plate_compact": true},
	{"gap": 8.0, "counter_compact": true, "fan": false, "plate_compact": true, "board_compact": true},
	{"gap": 8.0, "counter_compact": true, "fan": false, "plate_compact": true, "board_compact": true,
		"open_row": false},
]


## Rects for frame `fw` × `fh`: {"board", "paw", "menu", "chips", "opp", "mod", "player", "counter", "hand", "ablage",
## "stempeln"} + "mod_font" (px), "gap", "fan", "counter_compact", "plate_compact", "board_compact", "open_row"
## (bools), "duty_rows", "step" (index into STEPS), "fits".
static func compute(fw: float, fh: float, touch: bool, text_size: int, left_handed: bool, open_hand: bool,
		book: SdRulebook, duties: Array[Dictionary] = []) -> Dictionary:
	var base_mod: int = SdStyle.fs(20 if touch else 18, 100)
	var want_mod: int = SdStyle.fs(20 if touch else 18, text_size)
	var out: Dictionary = {}
	for i in STEPS.size():
		var o: Dictionary = {"gap": 12.0, "fan": touch, "counter_compact": false, "plate_compact": false,
			"board_compact": false, "open_row": open_hand}
		o.merge(STEPS[i], true)
		o["fan"] = bool(o["fan"]) and touch
		o["open_row"] = bool(o["open_row"]) and open_hand
		var f: int = want_mod
		while f >= base_mod:
			o["mod_font"] = f
			out = _try(fw, fh, touch, text_size, left_handed, book, o, duties)
			out["step"] = i
			if bool(out["fits"]):
				return out
			f -= 1
	return out


static func _try(fw: float, fh: float, touch: bool, ts: int, left_handed: bool, book: SdRulebook, o: Dictionary,
		duties: Array[Dictionary] = []) -> Dictionary:
	var r: Dictionary = o.duplicate()
	var gap: float = float(o["gap"])
	var fan: bool = bool(o["fan"])
	# top bar: buttons at the right, chips left of them
	r["menu"] = Rect2(fw - BUTTON, 0, BUTTON, BUTTON)
	r["paw"] = Rect2(fw - BUTTON * 2.0 - 12.0, 0, BUTTON, BUTTON)
	var chips_w: float = 150.0 if not touch else 170.0
	r["chips"] = Rect2(fw - BUTTON * 2.0 - 24.0 - chips_w, 0, chips_w, 30.0)
	var board_h: float = SdBoard.board_height(touch, ts, bool(o["board_compact"]))
	r["board"] = Rect2(0, TOP, fw - BUTTON * 2.0 - 24.0, board_h)
	# columns: plates left, M.O.D. box / counter right
	var left_w: float = clampf(roundf(fw * 0.56), 560.0, 820.0)
	var right_x: float = left_w + 16.0
	var right_w: float = fw - right_x
	var duty_rows: int = SdPlate.duty_rows(duties, left_w, touch, ts)
	r["duty_rows"] = duty_rows
	var opp_h: float = SdPlate.plate_height(touch, ts, false, duty_rows - 1, bool(o["plate_compact"])) \
		+ (_open_row(touch, ts) if bool(o["open_row"]) else 0.0)
	var mod_h: float = mod_need(book, right_w, int(o["mod_font"]))
	var row_a: float = maxf(opp_h, mod_h)
	var pl_h: float = SdPlate.plate_height(touch, ts, true)
	var counter_h: float = SdCounter.height(touch, ts, bool(o["counter_compact"]))
	var row_b: float = maxf(pl_h, counter_h)
	var cs: Vector2 = SdStyle.card_size(touch)
	var hand_h: float = cs.y + SdStyle.LIFT + (14.0 if fan else 0.0)
	var y: float = TOP + board_h + gap
	var need: float = y + row_a + gap + row_b + gap + hand_h + BOTTOM
	var slack: float = fh - need
	r["fits"] = slack >= 0.0
	var extra: float = maxf(0.0, slack) / 4.0
	y += extra
	r["opp"] = Rect2(0, y, left_w, opp_h)
	r["mod"] = Rect2(right_x, y, right_w, row_a)
	y += row_a + gap + extra
	r["player"] = Rect2(0, y, left_w, pl_h)
	r["counter"] = Rect2(right_x, y, right_w, row_b)
	y += row_b + gap + extra
	var hand_bottom: float = fh - BOTTOM
	# hand row: ABLAGE · cards · STEMPELN (mirrored for left-handers); on touch the two buttons sit at the frame's
	# edges, near the thumbs (10 §4.2), else right beside the cards
	var abl_w: float = maxf(128.0 if touch else 120.0, side_label_w(touch, ["ABLAGE", "ZURÜCK"]) + 24.0)
	var stp: float = maxf(124.0 if touch else 96.0, side_label_w(touch, ["STEMPELN", "ABHEFTEN"]) + 20.0)
	var side_gap: float = 24.0
	# narrow screens (a 16:9 phone with a notch): the touch cards first lose their extra gap, then up to 20 px width
	var card_w: float = cs.x
	var card_gap: float = SdHand.default_gap(touch)
	for attempt: Vector2 in [Vector2(cs.x, card_gap), Vector2(cs.x, SdStyle.GAP), Vector2(cs.x - 10.0, SdStyle.GAP),
			Vector2(cs.x - 20.0, SdStyle.GAP)]:
		card_w = attempt.x
		card_gap = attempt.y
		if abl_w + stp + SdHand.needed_width(touch, 5, card_w, card_gap) + SdStyle.GAP * 2.0 <= fw:
			break
	r["card_w"] = card_w
	r["card_gap"] = card_gap
	var cards_w: float = SdHand.needed_width(touch, 5, card_w, card_gap)
	if abl_w + stp + cards_w + side_gap * 2.0 > fw:
		side_gap = SdStyle.GAP
	var hand_top: float = hand_bottom - hand_h
	var abl_h: float = roundf(cs.y * 0.62)
	var stp_y: float = hand_bottom - stp - (cs.y - stp) * 0.5
	var first_w: float = stp if left_handed else abl_w
	var last_w: float = abl_w if left_handed else stp
	var cards_x: float = 0.0
	var first_x: float = 0.0
	var last_x: float = 0.0
	var edge_cards: float = clampf((fw - cards_w) * 0.5, first_w + SdStyle.GAP, fw - last_w - SdStyle.GAP - cards_w)
	if touch and edge_cards >= first_w + SdStyle.GAP - 0.01 and edge_cards + cards_w <= fw - last_w - SdStyle.GAP + 0.01:
		cards_x = edge_cards
		first_x = 0.0
		last_x = fw - last_w
	else:
		var total: float = first_w + side_gap + cards_w + side_gap + last_w
		first_x = maxf(0.0, (fw - total) * 0.5)
		cards_x = first_x + first_w + side_gap
		last_x = cards_x + cards_w + side_gap
	var abl_x: float = last_x if left_handed else first_x
	var stp_x: float = first_x if left_handed else last_x
	r["ablage"] = Rect2(abl_x, hand_bottom - abl_h, abl_w, abl_h)
	r["stempeln"] = Rect2(stp_x, stp_y, stp, stp)
	r["hand"] = Rect2(cards_x, hand_top, cards_w, hand_h)
	return r


## Label size of ABLAGE / STEMPELN (fixed: the text size option scales cards, tickets, plates and the box only).
static func side_label_px(touch: bool) -> int:
	return 20 if touch else 18


static func side_label_w(touch: bool, words: Array) -> float:
	var w: float = 0.0
	for t: Variant in words:
		w = maxf(w, SdStyle.bold().get_string_size(str(t), HORIZONTAL_ALIGNMENT_LEFT, -1, side_label_px(touch)).x)
	return ceilf(w)


## Extra height of the open-hand row on the opponent's plate (Gegnerhand offen).
static func _open_row(touch: bool, ts: int) -> float:
	return SdStyle.fs(20 if touch else 16, ts) * 1.3 + 6.0


## Height the M.O.D. box slot needs for the longest line of the rulebook at `font` px in `width` (subtitle box, no
## drone: 2 × 16 px margins + 14 px separation) plus the speaker tab.
static func mod_need(book: SdRulebook, width: float, font: int) -> float:
	var text_w: float = width - MOD_PAD
	var lines: int = mod_lines(book, text_w, font)
	var lh: float = SdStyle.font().get_height(font)
	return ceilf(maxf(lines * lh + 16.0, 56.0) + TAB_H)


## Lines the longest announcer line needs at `font` px in `text_w` (placeholders filled with long samples); cached
## per rulebook, width and size (the layout tries several sizes on every resize).
static func mod_lines(book: SdRulebook, text_w: float, font: int) -> int:
	var worst: int = 2
	if book == null:
		return worst
	var key: String = "%d|%d|%d" % [book.get_instance_id(), roundi(text_w), font]
	if _mod_cache.has(key):
		return int(_mod_cache[key])
	for tag: Variant in book.lines.keys():
		for l: Variant in book.lines[tag]:
			var d: Dictionary = l
			if str(d.get("voice", "")) == "chat":
				continue
			var t: String = str(d.get("text", "")).format(SAMPLE)
			if t.length() < 70:
				continue
			worst = maxi(worst, SdStyle.wrap_lines(t, SdStyle.font(), font, text_w).size())
	_mod_cache[key] = worst
	return worst


## Every element rect of a layout (tests: overlaps, inside the frame).
static func element_rects(r: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: String in ["board", "paw", "menu", "chips", "opp", "mod", "player", "counter", "ablage", "stempeln", "hand"]:
		if r.has(k):
			out[k] = r[k]
	return out
