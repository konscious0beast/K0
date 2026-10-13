extends RefCounted
## Look of the Stempelduell (10 §4, 03_ART §9 TV look): colours per Formular-Art, sizes per input scheme and text size
## (100 / 125 / 150 %, 10 §4.8), plain labels without outline (07 §8.2: an outlined label costs two canvas draw calls,
## the duel draws on dark or paper ground only), text fitting with German hyphenation points and the WCAG contrast
## check the tests use. Private helper (no class_name, 02_TECH §0.3):
## `const SdStyle := preload("res://scenes/stempel/sd_style.gd")`.

const UiUtilRef := preload("res://scenes/ui/ui_util.gd")
const INK: Color = Color("#140d1c")
const PAPER: Color = Color("#f5f0e6")
const TEXT: Color = Color("#f5f0ff")
const TEXT_DIM: Color = Color("#b3a7c9")
const PANEL: Color = Color(0.0784, 0.051, 0.1098, 0.92)
const PANEL_LINE: Color = Color(0.70, 0.66, 0.79, 0.35)
const MAGENTA: Color = Color("#ff2e88")
const CYAN: Color = Color("#22d3ee")
const GOLD: Color = Color("#ffc93c")
const PARTY: Color = Color("#4aa8ff")
const ENEMY: Color = Color("#e8455a")
const OK: Color = Color("#4ade80")
const DANGER: Color = Color("#ff4d4d")
const GREY: Color = Color("#8a8494")
const PAPER_DIM: Color = Color("#5a4e6c")          # quips, form numbers on paper (contrast 6.7 : 1)
const HEAL_ON_PAPER: Color = Color("#17703c")      # "+8 GEDULD" on paper (5.4 : 1)
const SEAL_RED: Color = Color("#c8102e")           # the BEWILLIGT stamp (10 §4.2)

## Formular-Art (10 §1.5): name, band colour (ink text on it, ≥ 4.5 : 1), drawn symbol. Colour is never the only
## carrier: every card shows the symbol and the word (10 §4.8).
const ARTS: Dictionary = {
	"stempel": {"name": "Stempel", "band": Color("#b8b2c4"), "icon": &"stamp"},
	"eilt": {"name": "Eilt", "band": Color("#ff7a6b"), "icon": &"flame"},
	"eiskalt": {"name": "Eiskalt", "band": Color("#7fc4ff"), "icon": &"snow"},
	"rohrpost": {"name": "Rohrpost", "band": Color("#f5d90a"), "icon": &"capsule"},
	"papierkram": {"name": "Papierkram", "band": Color("#6fdc8c"), "icon": &"magnifier"},
	"verwaltung": {"name": "Verwaltung", "band": Color("#e9e4f5"), "icon": &"folder"},
}
## Engine element → Formular-Art (Zuständigkeiten on plates and in files).
const ELEMENT_ARTS: Dictionary = {"physical": "stempel", "fire": "eilt", "ice": "eiskalt", "shock": "rohrpost",
	"poison": "papierkram", "none": "verwaltung"}
const ORIGINS: Dictionary = {"amt": "Amt", "kandidat": "Kandidat:in", "graf": "Graf", "gegenstand": "Gegenstand",
	"talent": "Talent", "trophaee": "Trophäe"}
const STATUS_ICONS: Dictionary = {"clock_arrow": &"clock_arrow", "snail": &"snail",
	"seal_exclamation": &"seal_exclamation", "magnifier": &"magnifier"}
const OPPONENT_ICONS: Dictionary = {"golem_paper": &"golem_paper", "pug": &"pug", "cabinet": &"cabinet",
	"stamp_carousel": &"stamp_carousel"}

## Card sizes (10 §2.2): desktop / gamepad 150 × 210, touch 170 × 236; the big view doubles them.
const CARD_DESKTOP: Vector2 = Vector2(150, 210)
const CARD_TOUCH: Vector2 = Vector2(170, 236)
const LIFT: float = 24.0                          # a marked card rises 24 px (10 §4.4)
const GAP: float = 12.0                           # between hit areas (02_TECH §10.2 rule 5)
const TEXT_SIZES: PackedInt32Array = [100, 125, 150]
## German break points for words that do not fit a card or ticket line ("|" = may break, a hyphen is added).
const HYPHENS: Dictionary = {"Ablehnungsbescheid": "Ablehnungs|bescheid", "Automatenkaffee": "Automaten|kaffee",
	"Kleingedrucktes": "Klein|gedrucktes", "Werbepflaster": "Werbe|pflaster", "Umlaufmappe": "Umlauf|mappe",
	"Doppelstempel": "Doppel|stempel", "Wiedervorlage": "Wieder|vorlage", "Kabelpeitsche": "Kabel|peitsche",
	"Mitternacht": "Mitter|nacht", "Amtsstempel": "Amts|stempel", "Schlabbern": "Schlab|bern",
	"Gutachten": "Gut|achten", "DURCHSAGE": "DURCH|SAGE", "Wuchtschlag": "Wucht|schlag", "Frostniesen": "Frost|niesen",
	"Adelsflamme": "Adels|flamme", "Kältespray": "Kälte|spray", "Stempelmeister": "Stempel|meister",
	"Bahnsteig-Suplex": "Bahnsteig-|Suplex", "Gegengift-Gurgler": "Gegengift-|Gurgler",
	"Leinen-Fallstrick": "Leinen-|Fallstrick", "Durchschlag": "Durch|schlag", "Stempelduell": "Stempel|duell",
	"Gräfliches": "Gräf|liches", "Verwaltung": "Verwal|tung", "Papierkram": "Papier|kram",
	"WIEDERVORLAGE": "WIEDER|VORLAGE", "EILVERMERK": "EIL|VERMERK", "Eilvermerk": "Eil|vermerk"}

static var _bold: FontVariation = null


# --- fonts and sizes ------------------------------------------------------------------------------------------------

static func font() -> Font:
	return ThemeDB.fallback_font


## Bold variant of the default font (names, numbers, buttons).
static func bold() -> Font:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = ThemeDB.fallback_font
		_bold.variation_embolden = 0.5
	return _bold


static func mono() -> Font:
	return UiTheme.font_mono()


## `base` px scaled by the text size option (100 / 125 / 150 %).
static func fs(base: int, text_size: int) -> int:
	return roundi(float(base) * float(clampi(text_size, 100, 150)) / 100.0)


static func card_size(touch: bool) -> Vector2:
	return CARD_TOUCH if touch else CARD_DESKTOP


## Body text minimum of the scheme (10 §4.8: 16 px, touch 20 px).
static func min_text(touch: bool) -> int:
	return 20 if touch else 16


# --- labels ---------------------------------------------------------------------------------------------------------

## Label without outline (07 §8.2), mouse ignored, glyph-safe text (03_ART F8).
static func label(text: String, size: int, color: Color = TEXT, is_bold: bool = false) -> Label:
	var l: Label = Label.new()
	l.text = UiUtilRef.glyph_safe(text)
	l.add_theme_font_size_override("font_size", maxi(size, 15))
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 0)
	if is_bold:
		l.add_theme_font_override("font", bold())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func set_label(l: Label, text: String, size: int, color: Color) -> void:
	l.text = UiUtilRef.glyph_safe(text)
	l.add_theme_font_size_override("font_size", maxi(size, 15))
	l.add_theme_color_override("font_color", color)


## Flat panel box (ink, thin line) like the combat HUD panels.
static func panel_box(bg: Color = PANEL, border: Color = PANEL_LINE, width: int = 1,
		margin: float = 10.0) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_content_margin_all(margin)
	return sb


# --- text fitting ---------------------------------------------------------------------------------------------------

## The lines of `text` at `size` px inside `max_w` (word wrap; a word that does not fit alone breaks at its HYPHENS
## point, else at the last fitting character). Explicit "\n" are kept.
static func wrap_lines(text: String, f: Font, size: int, max_w: float) -> PackedStringArray:
	var out: PackedStringArray = []
	for para: String in text.split("\n"):
		var line: String = ""
		for word: String in para.split(" ", false):
			var cand: String = word if line == "" else line + " " + word
			if _w(f, cand, size) <= max_w:
				line = cand
				continue
			if line != "":
				out.append(line)
				line = ""
			var rest: String = word
			while _w(f, rest, size) > max_w:
				var cut: Array = _split_word(rest, f, size, max_w)
				out.append(str(cut[0]))
				rest = str(cut[1])
				if rest == "":
					break
			line = rest
		out.append(line)
	return out


## [font size, lines]: the largest size from `size` down to `min_size` at which `text` fits in `max_lines` lines of
## `max_w`; at `min_size` the lines are cut to `max_lines` (the last one shortened with "…").
static func fit(text: String, f: Font, size: int, min_size: int, max_w: float, max_lines: int) -> Array:
	var s: int = size
	while s > min_size:
		var lines: PackedStringArray = wrap_lines(text, f, s, max_w)
		if lines.size() <= max_lines:
			return [s, lines]
		s -= 1
	var at_min: PackedStringArray = wrap_lines(text, f, min_size, max_w)
	if at_min.size() > max_lines:
		at_min = at_min.slice(0, max_lines)
		var last: String = at_min[max_lines - 1]
		while last.length() > 1 and _w(f, last + "…", min_size) > max_w:
			last = last.substr(0, last.length() - 1)
		at_min[max_lines - 1] = last.strip_edges() + "…"
	return [min_size, at_min]


static func _w(f: Font, text: String, size: int) -> float:
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## [head (with hyphen), rest] of a word too wide for one line: the HYPHENS point if the head fits, else the most
## characters that fit with a hyphen.
static func _split_word(word: String, f: Font, size: int, max_w: float) -> Array:
	var core: String = word.rstrip(".,:;!?")
	var tail: String = word.substr(core.length())
	if HYPHENS.has(core):
		var parts: PackedStringArray = str(HYPHENS[core]).split("|")
		var head: String = parts[0] if parts[0].ends_with("-") else parts[0] + "-"
		if _w(f, head, size) <= max_w:
			return [head, parts[1] + tail]
	var n: int = word.length() - 1
	while n > 1 and _w(f, word.substr(0, n) + "-", size) > max_w:
		n -= 1
	return [word.substr(0, n) + "-", word.substr(n)]


# --- colours --------------------------------------------------------------------------------------------------------

## WCAG 2.1 contrast ratio of two opaque colours (1 … 21).
static func contrast(a: Color, b: Color) -> float:
	var la: float = _lum(a)
	var lb: float = _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _lum(c: Color) -> float:
	var ch: Array[float] = [c.r, c.g, c.b]
	var lin: Array[float] = []
	for v: float in ch:
		lin.append(v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4))
	return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]


static func art(art_id: String) -> Dictionary:
	return ARTS.get(art_id, ARTS["verwaltung"]) as Dictionary


static func art_name(art_id: String) -> String:
	return str(art(art_id)["name"])


static func art_band(art_id: String) -> Color:
	return art(art_id)["band"] as Color


static func art_icon(art_id: String) -> StringName:
	return art(art_id)["icon"] as StringName


## Frame colour of a card on the dark table: the band colour (show cards: gold).
static func frame_color(art_id: String, show: bool) -> Color:
	return GOLD if show else art_band(art_id)


## "Wunder Punkt: Eilt" / "Nicht zuständig: Eiskalt" lines of an opponent (element_mods), Wunder Punkt first.
static func duties(mods: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for weak: bool in [true, false]:
		for el: String in ["physical", "fire", "ice", "shock", "poison", "none"]:
			if not mods.has(el):
				continue
			var m: float = float(mods[el])
			if (weak and m > 1.0) or (not weak and m < 1.0):
				out.append({"weak": weak, "art": str(ELEMENT_ARTS[el]), "label": "Wunder Punkt" if weak
					else "Nicht zuständig", "mult": m})
	return out
